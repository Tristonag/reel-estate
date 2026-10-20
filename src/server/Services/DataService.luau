--[[
	DataService
	Loads, caches and saves player data with session locking.

	Session locking: each save record stores which server owns it. If a player
	hops servers fast, the new server waits for the old one to finish saving
	instead of loading stale data (the classic item-duplication bug).

	In an unpublished place (or with Studio API access off) it falls back to an
	in-memory store so everything still runs. Nothing saves in that mode.

	API
		DataService.Start()
		DataService.Get(player) -> data table or nil (not loaded yet)
		DataService.WaitFor(player, timeout?) -> data or nil
		DataService.Set(player, key, value)      -- top-level key, replicates
		DataService.Increment(player, key, delta)
		DataService.Update(player, key, fn)      -- fn(currentValue) -> newValue, replicates
		DataService.MarkChanged(player, key)     -- after mutating a nested table in place
		DataService.Loaded   (BindableEvent) Fired(player, data)
		DataService.Changed  (BindableEvent) Fired(player, key, value)
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Template = require(script.Parent.DataTemplate)

local STORE_NAME = "PlayerData_v1"
local LOCK_EXPIRE_SECONDS = 300        -- a lock older than this is considered abandoned (crashed server)
local LOAD_ATTEMPTS = 8
local LOAD_RETRY_WAIT = 4
local SAVE_ATTEMPTS = 3
local MAX_RECEIPTS = 50

local DataService = {}
DataService.Loaded = Instance.new("BindableEvent")
DataService.Changed = Instance.new("BindableEvent")

local profiles: { [Player]: { Data: any, Key: string, Saving: boolean, Released: boolean } } = {}
local pendingSaves = 0
local store = nil
local useMemory = false
local memoryStore = {}
local serverId = game.JobId ~= "" and game.JobId or ("studio-" .. HttpService:GenerateGUID(false))

------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------
local function deepCopy(t)
	if type(t) ~= "table" then return t end
	local c = {}
	for k, v in pairs(t) do c[k] = deepCopy(v) end
	return c
end

-- Fill any fields missing from saved data using the template (for new features).
local function reconcile(data, template)
	for k, v in pairs(template) do
		if data[k] == nil then
			data[k] = deepCopy(v)
		elseif type(v) == "table" and type(data[k]) == "table" and next(v) ~= nil then
			reconcile(data[k], v)
		end
	end
	return data
end

local function keyFor(player: Player)
	return "u_" .. player.UserId
end

-- Wraps UpdateAsync for real store or memory fallback.
local function updateRecord(key, transform)
	if useMemory then
		local newValue = transform(deepCopy(memoryStore[key]))
		if newValue ~= nil then memoryStore[key] = deepCopy(newValue) end
		return true, newValue
	end
	return pcall(function()
		return store:UpdateAsync(key, transform)
	end)
end

------------------------------------------------------------------
-- Setup
------------------------------------------------------------------
local function initStore()
	local ok, result = pcall(function()
		local s = DataStoreService:GetDataStore(STORE_NAME)
		s:GetAsync("__probe") -- throws if API access is off / place unpublished
		return s
	end)
	if ok then
		store = result
	else
		useMemory = true
		if RunService:IsStudio() then
			warn("[DataService] DataStores unavailable (" .. tostring(result) .. "). Using in-memory data. Publish the place and enable 'Studio Access to API Services' to test real saving.")
		else
			warn("[DataService] DataStores unavailable in live server! Data will NOT save: " .. tostring(result))
		end
	end
end

------------------------------------------------------------------
-- Load
------------------------------------------------------------------
local function loadPlayer(player: Player)
	local key = keyFor(player)
	local loadedData = nil

	for attempt = 1, LOAD_ATTEMPTS do
		local lockedByOther = false
		local ok, err = updateRecord(key, function(record)
			record = record or {}
			local lock = record.Lock
			local staleStudioLock = RunService:IsStudio() and lock and type(lock.ServerId) == "string" and lock.ServerId:sub(1, 7) == "studio-"
			if lock and lock.ServerId ~= serverId and not staleStudioLock and (os.time() - (lock.Time or 0)) < LOCK_EXPIRE_SECONDS then
				lockedByOther = true
				return nil -- cancel: another server still owns this data
			end
			record.Data = record.Data or deepCopy(Template)
			record.Lock = { ServerId = serverId, Time = os.time() }
			loadedData = record.Data
			return record
		end)

		if not player.Parent then
			-- left while loading: give the lock back so their next join isn't blocked
			if ok and loadedData then
				updateRecord(key, function(record)
					if record and record.Lock and record.Lock.ServerId == serverId then
						record.Lock = nil
						return record
					end
					return nil
				end)
			end
			return
		end

		if ok and loadedData then
			break
		end
		loadedData = nil
		if not ok then
			warn(("[DataService] Load attempt %d failed for %s: %s"):format(attempt, player.Name, tostring(err)))
		elseif lockedByOther then
			-- previous server is probably still saving; wait and retry
		end
		task.wait(LOAD_RETRY_WAIT)
	end

	if not loadedData then
		player:Kick("Your data couldn't load safely. Please rejoin in a minute. (Your progress is safe.)")
		return
	end

	reconcile(loadedData, Template)

	profiles[player] = { Data = loadedData, Key = key, Saving = false, Released = false }
	DataService.Loaded:Fire(player, loadedData)
end

------------------------------------------------------------------
-- Save
------------------------------------------------------------------
local saveOnce
local function savePlayer(player: Player, release: boolean)
	local profile = profiles[player]
	if not profile or profile.Released then return end
	if release then profile.Released = true end
	pendingSaves += 1
	local ok, result = pcall(saveOnce, player, profile, release)
	pendingSaves -= 1
	if not ok then warn("[DataService] Save error for " .. player.Name .. ": " .. tostring(result)) end
	return ok and result
end

saveOnce = function(player: Player, profile, release: boolean)

	-- trim receipts so the save never grows forever
	local receipts = profile.Data.Receipts
	if #receipts > MAX_RECEIPTS then
		table.move(receipts, #receipts - MAX_RECEIPTS + 1, #receipts, 1, receipts)
		for i = MAX_RECEIPTS + 1, #receipts do receipts[i] = nil end
	end

	profile.Data.LastOnline = os.time()
	local snapshot = deepCopy(profile.Data)

	for attempt = 1, SAVE_ATTEMPTS do
		local lostLock = false
		local ok, err = updateRecord(profile.Key, function(record)
			record = record or {}
			local lock = record.Lock
			if lock and lock.ServerId ~= serverId then
				lostLock = true
				return nil -- someone else owns it now, never overwrite their data
			end
			record.Data = snapshot
			record.Lock = (not release) and { ServerId = serverId, Time = os.time() } or nil
			return record
		end)
		if ok then
			if lostLock then warn("[DataService] Lost session lock for " .. player.Name .. ", skipped save.") end
			return true
		end
		warn(("[DataService] Save attempt %d failed for %s: %s"):format(attempt, player.Name, tostring(err)))
		task.wait(2)
	end
	return false
end

------------------------------------------------------------------
-- Public API
------------------------------------------------------------------
function DataService.Get(player: Player)
	local p = profiles[player]
	return p and p.Data or nil
end

function DataService.WaitFor(player: Player, timeout: number?)
	local deadline = os.clock() + (timeout or 30)
	while player.Parent and os.clock() < deadline do
		local d = DataService.Get(player)
		if d then return d end
		task.wait(0.1)
	end
	return nil
end

function DataService.MarkChanged(player: Player, key: string)
	local d = DataService.Get(player)
	if d then DataService.Changed:Fire(player, key, d[key]) end
end

function DataService.Set(player: Player, key: string, value: any)
	local d = DataService.Get(player)
	if not d then return false end
	d[key] = value
	DataService.Changed:Fire(player, key, value)
	return true
end

function DataService.Update(player: Player, key: string, fn: (any) -> any)
	local d = DataService.Get(player)
	if not d then return nil end
	d[key] = fn(d[key])
	DataService.Changed:Fire(player, key, d[key])
	return d[key]
end

function DataService.Increment(player: Player, key: string, delta: number)
	return DataService.Update(player, key, function(v) return (v or 0) + delta end)
end

-- Adds shells and tracks lifetime total (use this, not Increment, for earnings).
function DataService.AddShells(player: Player, amount: number)
	local d = DataService.Get(player)
	if not d or amount == 0 then return end
	d.Shells += amount
	if amount > 0 then d.TotalShellsEarned += amount end
	DataService.Changed:Fire(player, "Shells", d.Shells)
end

-- Spends shells if affordable. Returns true on success.
function DataService.SpendShells(player: Player, amount: number): boolean
	local d = DataService.Get(player)
	if not d or amount < 0 or d.Shells < amount then return false end
	d.Shells -= amount
	DataService.Changed:Fire(player, "Shells", d.Shells)
	return true
end

-- Saves immediately (keeps the session lock). Returns true on success.
function DataService.SaveNow(player: Player): boolean
	local profile = profiles[player]
	if not profile or profile.Released then return false end
	if useMemory then return true end
	pendingSaves += 1
	local ok, result = pcall(saveOnce, player, profile, false)
	pendingSaves -= 1
	return ok and result == true
end

function DataService.IsMemoryMode()
	return useMemory
end

------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------
function DataService.Start()
	initStore()

	Players.PlayerAdded:Connect(loadPlayer)
	for _, p in ipairs(Players:GetPlayers()) do task.spawn(loadPlayer, p) end

	Players.PlayerRemoving:Connect(function(player)
		savePlayer(player, true)
		profiles[player] = nil
	end)

	-- Autosave (also refreshes the session lock so it never expires while playing)
	task.spawn(function()
		while true do
			task.wait(Config.Timing.AutosaveSeconds)
			for player in pairs(profiles) do
				task.spawn(savePlayer, player, false)
			end
		end
	end)

	game:BindToClose(function()
		if useMemory then return end
		for player in pairs(profiles) do
			task.spawn(savePlayer, player, true)
		end
		task.wait() -- let the saves above start
		local deadline = os.clock() + 25
		while pendingSaves > 0 and os.clock() < deadline do task.wait(0.1) end
	end)
end

return DataService
