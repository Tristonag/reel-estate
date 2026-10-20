--[[
	IdleService
	Placed items with Idle > 0 earn Shells over time (variants multiply it).
	- Online: paid every Config.Economy.IdleTickSeconds. Player attribute "IdleRate" = Shells/sec for the HUD.
	- Offline: on join, pays (time away, capped) * rate * OfflineEarningsRate and tells the client.
]]
local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local PerkService = require(script.Parent.PerkService)
local Remotes = game.ReplicatedStorage.Shared.Remotes

local IdleService = {}
local E = Config.Economy

local VARIANT_MULT = { [""] = 1 }
for _, v in ipairs(Config.Variants) do VARIANT_MULT[v.Id] = v.Multiplier end

function IdleService.GetRate(data): number
	local rate = 0
	for _, entry in pairs(data.Island.Placed) do
		local item = Config.Items[entry.Id]
		if item and item.Idle > 0 then rate += item.Idle * (Config.VariantIdleMultiplier[entry.Variant] or 1) end
	end
	return rate
end

local function refreshRate(player: Player)
	local data = DataService.Get(player)
	if data then player:SetAttribute("IdleRate", IdleService.GetRate(data) * PerkService.IdleMult(player)) end
end

function IdleService.Start()
	DataService.Loaded.Event:Connect(function(player: Player, data)
		refreshRate(player)
		-- offline earnings (LastOnline is stamped on every save)
		local away = (data.LastOnline > 0) and (os.time() - data.LastOnline) or 0
		local rate = IdleService.GetRate(data) * PerkService.IdleMult(player)
		if away >= E.OfflineMinSeconds and rate > 0 then
			local seconds = math.min(away, E.OfflineEarningsCapHours * 3600)
			local earned = math.floor(seconds * rate * E.OfflineEarningsRate)
			if earned > 0 then
				DataService.AddShells(player, earned)
				-- the client shows this whenever its UI is ready (an attribute can't be missed like an event can)
				player:SetAttribute("OfflineEarned", ("%d|%d|%s"):format(earned, seconds, tostring(away > seconds)))
			end
		end
	end)

	DataService.Changed.Event:Connect(function(player: Player, key: string)
		if key == "Island" then refreshRate(player) end
	end)
	-- VIP bought mid-session
	local function watch(p: Player)
		p:GetAttributeChangedSignal("Pass_VIP"):Connect(function() refreshRate(p) end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in ipairs(Players:GetPlayers()) do watch(p) end

	-- online ticks; fractional Shells carry over so small rates still pay out
	local carry: { [Player]: number } = {}
	Players.PlayerRemoving:Connect(function(p) carry[p] = nil end)
	task.spawn(function()
		while true do
			task.wait(E.IdleTickSeconds)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = DataService.Get(player)
				if data then
					local amount = IdleService.GetRate(data) * PerkService.IdleMult(player) * E.IdleTickSeconds + (carry[player] or 0)
					local whole = math.floor(amount)
					carry[player] = amount - whole
					if whole > 0 then DataService.AddShells(player, whole) end
				end
			end
		end
	end)
end

return IdleService
