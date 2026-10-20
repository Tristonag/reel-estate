--[[
	FloaterService
	Keeps each occupied plot's stretch of sea stocked with floating containers.
	Rarer containers spawn farther out. The server owns the true positions;
	clients only add a visual bob.

	FloaterService.Get(id) -> floater record or nil
	FloaterService.FindHookable(pos, radius) -> nearest unclaimed floater within radius
	FloaterService.Claim(id, player) -> bool
	FloaterService.Release(id)
	FloaterService.Remove(id)
]]
local CollectionService = game:GetService("CollectionService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local ContainerVisuals = require(game.ReplicatedStorage.Shared.ContainerVisuals)
local PlotService = require(script.Parent.PlotService)

local FloaterService = {}

type Floater = {
	Id: string,
	Plot: number,
	Container: string,
	Position: Vector3,
	Model: Model,
	ExpiresAt: number,
	ClaimedBy: Player?,
	Sinking: boolean,
	Event: boolean?,
}

local floaters: { [string]: Floater } = {}
local countByPlot: { [number]: number } = {}
local nextId = 0
local folder: Folder
local rng = Random.new()
local SINK_SECONDS = 4

local totalWeight = 0
for _, id in ipairs(Config.ContainerOrder) do
	totalWeight += Config.Containers[id].SpawnWeight
end

local function pickContainer(): string
	local roll = rng:NextNumber() * totalWeight
	for _, id in ipairs(Config.ContainerOrder) do
		roll -= Config.Containers[id].SpawnWeight
		if roll <= 0 then return id end
	end
	return Config.ContainerOrder[1]
end

local function tooClose(pos: Vector3): boolean
	for _, f in pairs(floaters) do
		if (f.Position - pos).Magnitude < 6 then return true end
	end
	return false
end

local function spawnFor(plot: number)
	local containerId = pickContainer()
	local band = Config.Fishing.SpawnBands[containerId]
	local islandR = PlotService.GetIslandRadius(plot)
	local minD = math.max(band[1], islandR + 18) -- clear of the beach and the fishing dock
	local maxD = math.max(band[2], minD + 5)
	local cf = PlotService.GetPlotCFrame(plot)

	local pos
	for _ = 1, 6 do
		local d = rng:NextNumber(minD, maxD)
		local spread = 20 + d * 0.45
		local lateral = rng:NextNumber(-spread, spread)
		local candidate = cf.Position + cf.LookVector * d + cf.RightVector * lateral
		candidate = Vector3.new(candidate.X, Config.World.WaterLevel + 0.3, candidate.Z)
		if not tooClose(candidate) then pos = candidate; break end
	end
	if not pos then return end

	nextId += 1
	local id = tostring(nextId)
	local model = ContainerVisuals.Build(containerId)
	model.Name = "Floater_" .. id
	model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	model:SetAttribute("FloaterId", id)
	model:SetAttribute("Container", containerId)
	model:SetAttribute("Plot", plot)
	CollectionService:AddTag(model, "Floater")
	model.Parent = folder

	local life = Config.Fishing.FloaterLifetime
	floaters[id] = {
		Id = id,
		Plot = plot,
		Container = containerId,
		Position = pos,
		Model = model,
		ExpiresAt = os.clock() + rng:NextNumber(life[1], life[2]),
		ClaimedBy = nil,
		Sinking = false,
	}
	countByPlot[plot] = (countByPlot[plot] or 0) + 1
end

function FloaterService.Get(id: string): Floater?
	return floaters[id]
end

function FloaterService.FindHookable(pos: Vector3, radius: number): Floater?
	local best, bestDist = nil, radius
	local flat = Vector3.new(pos.X, 0, pos.Z)
	for _, f in pairs(floaters) do
		if not f.ClaimedBy and not f.Sinking then
			local d = (Vector3.new(f.Position.X, 0, f.Position.Z) - flat).Magnitude
			if d <= bestDist then best, bestDist = f, d end
		end
	end
	return best
end

function FloaterService.Claim(id: string, player: Player): boolean
	local f = floaters[id]
	if not f or f.ClaimedBy then return false end
	f.ClaimedBy = player
	f.Model:SetAttribute("ClaimedBy", player.UserId)
	return true
end

function FloaterService.Release(id: string)
	local f = floaters[id]
	if not f then return end
	f.ClaimedBy = nil
	f.Model:SetAttribute("ClaimedBy", nil)
	-- give a released floater a little more life so it doesn't vanish right after a failed reel
	if f.Event then
		if f.ExpiresAt <= os.clock() then FloaterService.Remove(id) end
		return
	end
	f.ExpiresAt = math.max(f.ExpiresAt, os.clock() + 20)
	if f.Sinking then
		f.Sinking = false
		f.Model:SetAttribute("Sinking", nil)
	end
end

function FloaterService.Remove(id: string)
	local f = floaters[id]
	if not f then return end
	floaters[id] = nil
	countByPlot[f.Plot] = math.max(0, (countByPlot[f.Plot] or 1) - 1)
	f.Model:Destroy()
end

-- Event floaters (Shipwreck). Plot 0, never restocked by the normal loop, ignore rod tier requirements.
function FloaterService.SpawnEvent(containerId: string, pos: Vector3, lifetime: number): string?
	pos = Vector3.new(pos.X, Config.World.WaterLevel + 0.3, pos.Z)
	if tooClose(pos) then return nil end
	nextId += 1
	local id = tostring(nextId)
	local model = ContainerVisuals.Build(containerId)
	model.Name = "Floater_" .. id
	model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	model:SetAttribute("FloaterId", id)
	model:SetAttribute("Container", containerId)
	model:SetAttribute("Plot", 0)
	model:SetAttribute("Event", true)
	CollectionService:AddTag(model, "Floater")
	model.Parent = folder
	floaters[id] = {
		Id = id, Plot = 0, Container = containerId, Position = pos, Model = model,
		ExpiresAt = os.clock() + lifetime, ClaimedBy = nil, Sinking = false, Event = true,
	}
	countByPlot[0] = (countByPlot[0] or 0) + 1
	return id
end

function FloaterService.CountEvent(): number
	return countByPlot[0] or 0
end

-- Sinks every unclaimed event floater right away (claimed ones vanish when their reel ends).
function FloaterService.ClearEvent()
	for id, fl in pairs(floaters) do
		if fl.Event then
			if fl.ClaimedBy then
				fl.ExpiresAt = 0
			else
				FloaterService.Remove(id)
			end
		end
	end
end

-- Removes unclaimed floaters of a plot that sit within radius of its center (after an island expands).
function FloaterService.ClearInside(plot: number, radius: number)
	local center = PlotService.GetPlotCFrame(plot).Position
	for id, fl in pairs(floaters) do
		if fl.Plot == plot and not fl.ClaimedBy then
			local d = (Vector3.new(fl.Position.X, 0, fl.Position.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude
			if d < radius then FloaterService.Remove(id) end
		end
	end
end

function FloaterService.Start()
	folder = Instance.new("Folder")
	folder.Name = "Floaters"
	folder.Parent = workspace

	PlotService.Freed.Event:Connect(function(_, plot: number)
		for id, f in pairs(floaters) do
			if f.Plot == plot and not f.ClaimedBy then FloaterService.Remove(id) end
		end
	end)

	-- Stock + expiry loop: tops up each occupied plot a few per tick so it fills fast but not in one spike
	task.spawn(function()
		while true do
			local now = os.clock()
			for id, f in pairs(floaters) do
				if not f.ClaimedBy then
					if now >= f.ExpiresAt then
						FloaterService.Remove(id)
					elseif not f.Sinking and now >= f.ExpiresAt - SINK_SECONDS then
						-- visibly sink before vanishing so nobody casts at a ghost
						f.Sinking = true
						f.Model:SetAttribute("Sinking", true)
					end
				end
			end
			for plot = 1, Config.Plots.Count do
				if PlotService.GetOwner(plot) then
					for _ = 1, 2 do
						if (countByPlot[plot] or 0) < Config.Fishing.FloatersPerPlot then spawnFor(plot) end
					end
				end
			end
			task.wait(0.5)
		end
	end)
end

return FloaterService
