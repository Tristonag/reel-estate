--[[
	ShipwreckService
	Idle -> Warning (60s) -> Active (90s) -> Idle, every Config.Shipwreck.IntervalSeconds.

	State is published on workspace attributes so late joiners see it instantly:
		ShipwreckState    "Idle" | "Warning" | "Active"
		ShipwreckStartsAt server time (workspace:GetServerTimeNow()) the wreck surfaces
		ShipwreckEndsAt   server time it sinks
		ShipwreckPosition Vector3

	ShipwreckService.TriggerNow(warnSeconds?)  -- used by the dev command and the future "Summon Shipwreck" product
	ShipwreckService.NoteCatch(player)         -- called by FishingService for event catches
]]
local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local FloaterService = require(script.Parent.FloaterService)
local DataService = require(script.Parent.DataService)

local S = Config.Shipwreck
local ShipwreckService = {}

local rng = Random.new()
local nextStart = 0            -- server time the next wreck surfaces
local eventId = 0
local joined: { [Player]: number } = {}
local wreckModel: Model? = nil
local forced = false

local lootTotal = 0
for _, w in pairs(S.Loot) do lootTotal += w end
local function pickLoot(): string
	local roll = rng:NextNumber() * lootTotal
	for id, w in pairs(S.Loot) do
		roll -= w
		if roll <= 0 then return id end
	end
	return "Chest"
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function setState(state: string)
	workspace:SetAttribute("ShipwreckState", state)
end

------------------------------------------------------------------
-- Wreck model (scaled-up mini ship, tilted, glowing)
------------------------------------------------------------------
local function buildWreck(pos: Vector3): Model?
	-- the dedicated wreck model; falls back to a scaled-up mini ship
	local src = game.ReplicatedStorage.Assets:FindFirstChild("Shipwreck")
	local m
	if src then
		m = src:Clone()
	else
		src = game.ReplicatedStorage.Assets.Items:FindFirstChild("MiniShip")
		if not src then return nil end
		m = src:Clone()
		m:ScaleTo(m:GetScale() * 3.2)
	end
	m.Name = "Shipwreck"
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	local body = m.PrimaryPart
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 210, 110)
	light.Range = 40
	light.Brightness = 3
	light.Parent = body
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120))
	sparkle.Rate = 25
	sparkle.Lifetime = NumberRange.new(1.5, 2.5)
	sparkle.Speed = NumberRange.new(3, 6)
	sparkle.SpreadAngle = Vector2.new(60, 60)
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
	sparkle.Parent = body
	-- floating marker
	local marker = Instance.new("BillboardGui")
	marker.Name = "Marker"
	marker.Size = UDim2.new(0, 220, 0, 60)
	marker.StudsOffsetWorldSpace = Vector3.new(0, 30, 0)
	marker.AlwaysOnTop = true
	marker.MaxDistance = 2000
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = "SHIPWRECK!"
	t.TextColor3 = Color3.fromRGB(255, 215, 90)
	local st = Instance.new("UIStroke"); st.Thickness = 3; st.Color = Color3.fromRGB(60, 30, 10); st.Parent = t
	t.Parent = marker
	marker.Parent = body

	local yaw = rng:NextNumber(0, math.pi * 2)
	m:SetAttribute("Yaw", yaw)
	m:PivotTo(CFrame.new(pos + Vector3.new(0, -24, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(3), 0, math.rad(-4)))
	m.Parent = workspace
	return m
end

-- slide the wreck vertically over `duration` seconds (anchored parts replicate smoothly enough at this pace)
local function moveWreck(m: Model, fromY: number, toY: number, duration: number)
	local pos = workspace:GetAttribute("ShipwreckPosition")
	local yaw = m:GetAttribute("Yaw") or 0
	local t0 = os.clock()
	while os.clock() - t0 < duration and m.Parent do
		local a = (os.clock() - t0) / duration
		local e = 1 - (1 - a) ^ 3 -- ease out
		m:PivotTo(CFrame.new(pos + Vector3.new(0, fromY + (toY - fromY) * e, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(3), 0, math.rad(-4)))
		task.wait(1 / 20)
	end
end

------------------------------------------------------------------
local function stockFloaters(center: Vector3, lifetime: number)
	local tries = 0
	while FloaterService.CountEvent() < S.Floaters and tries < 40 do
		tries += 1
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(S.FloaterRadius[1], S.FloaterRadius[2])
		FloaterService.SpawnEvent(pickLoot(), center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), lifetime)
	end
end

local function runEvent()
	eventId += 1
	joined = {}
	-- pick one of the 8 gaps between the boardwalks
	local gap = rng:NextInteger(0, Config.Plots.Count - 1)
	local angle = (gap + 0.5) * (2 * math.pi / Config.Plots.Count)
	local pos = Vector3.new(math.cos(angle) * S.RingRadius, Config.World.WaterLevel, math.sin(angle) * S.RingRadius)
	workspace:SetAttribute("ShipwreckPosition", pos)

	local endsAt = now() + S.DurationSeconds
	workspace:SetAttribute("ShipwreckEndsAt", endsAt)
	setState("Active")

	wreckModel = buildWreck(pos)
	if wreckModel then task.spawn(moveWreck, wreckModel, -26, -6, 3) end

	-- keep the wreck stocked until it sinks
	while now() < endsAt do
		stockFloaters(pos, math.max(1, endsAt - now()))
		task.wait(S.RestockSeconds)
	end

	FloaterService.ClearEvent()
	setState("Idle")
	if wreckModel then
		local m = wreckModel
		wreckModel = nil
		task.spawn(function()
			moveWreck(m, -6, -30, 3)
			m:Destroy()
		end)
	end
	-- reward participation stat
	for player in pairs(joined) do
		local d = DataService.Get(player)
		if d then d.Stats.ShipwrecksJoined += 1 end
	end
end

function ShipwreckService.NoteCatch(player: Player)
	joined[player] = eventId
end

function ShipwreckService.IsActive(): boolean
	return workspace:GetAttribute("ShipwreckState") == "Active"
end

-- Starts the countdown now (warnSeconds, default the normal warning) unless one is already coming/active.
function ShipwreckService.TriggerNow(warnSeconds: number?): boolean
	local state = workspace:GetAttribute("ShipwreckState")
	if state == "Active" then return false end
	nextStart = now() + (warnSeconds or S.WarningSeconds)
	forced = true
	return true
end

local pendingSummon = false

-- Paid summon: starts a 30s countdown, or queues one right after the current wreck sinks.
function ShipwreckService.Summon(player: Player)
	workspace:SetAttribute("ShipwreckSummoner", player.DisplayName)
	if workspace:GetAttribute("ShipwreckState") == "Active" then
		pendingSummon = true
	else
		local soon = now() + 30
		if soon < nextStart then nextStart = soon end
		forced = true
	end
end

function ShipwreckService.Start()
	setState("Idle")
	nextStart = now() + S.IntervalSeconds
	Players.PlayerRemoving:Connect(function(p) joined[p] = nil end)

	task.spawn(function()
		while true do
			local t = now()
			workspace:SetAttribute("ShipwreckStartsAt", nextStart)
			if t >= nextStart then
				forced = false
				runEvent()
				if pendingSummon then
					pendingSummon = false
					nextStart = now() + 45
					forced = true
				else
					workspace:SetAttribute("ShipwreckSummoner", nil)
					nextStart = now() + S.IntervalSeconds
				end
			elseif t >= nextStart - S.WarningSeconds or forced then
				if workspace:GetAttribute("ShipwreckState") ~= "Warning" then setState("Warning") end
			end
			task.wait(0.5)
		end
	end)
end

return ShipwreckService
