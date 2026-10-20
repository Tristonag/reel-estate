--[[
	IslandGrid (shared by server and client)

	Every island lives on a 6x6 grid (MAX). Each stage owns a centered block of it,
	and every stage contains the previous one, so placed items never end up
	outside the island after an expansion.

	Cell keys are strings "i_j" (0-based, i = right, j = forward) so they are
	safe DataStore keys.

	IslandGrid.PlotCFrame(plotIndex) -> CFrame (center on water, LookVector = open sea)
	IslandGrid.StageRange(stage) -> lo, hi
	IslandGrid.IsCellInStage(key, stage) -> bool
	IslandGrid.CellsForStage(stage) -> { key }
	IslandGrid.CellCFrame(plotIndex, key) -> CFrame at the top-center of that cell
	IslandGrid.Radius(stage) -> studs from plot center to the farthest edge
	IslandGrid.TopY -> world Y of the island surface
]]
local Config = require(script.Parent.Config)

local IslandGrid = {}
local MAX = Config.IslandStages[#Config.IslandStages].GridSize
local CELL = Config.Plots.CellSize
local CENTER = (MAX - 1) / 2

IslandGrid.Max = MAX
IslandGrid.TopY = Config.World.WaterLevel + 1

function IslandGrid.PlotCFrame(index: number): CFrame
	local angle = (index - 1) * (2 * math.pi / Config.Plots.Count)
	local r = Config.Plots.RingRadius
	local pos = Vector3.new(math.cos(angle) * r, Config.World.WaterLevel, math.sin(angle) * r)
	local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
	return CFrame.lookAt(pos, pos + outward)
end

function IslandGrid.StageRange(stage: number): (number, number)
	local g = (Config.IslandStages[stage] or Config.IslandStages[1]).GridSize
	local lo = math.floor((MAX - g) / 2)
	return lo, lo + g - 1
end

function IslandGrid.Key(i: number, j: number): string
	return i .. "_" .. j
end

function IslandGrid.Parse(key: string): (number?, number?)
	if type(key) ~= "string" then return nil, nil end
	local i, j = key:match("^(%d+)_(%d+)$")
	return tonumber(i), tonumber(j)
end

function IslandGrid.IsCellInStage(key: string, stage: number): boolean
	local i, j = IslandGrid.Parse(key)
	if not i then return false end
	local lo, hi = IslandGrid.StageRange(stage)
	return i >= lo and i <= hi and j >= lo and j <= hi
end

function IslandGrid.CellsForStage(stage: number): { string }
	local lo, hi = IslandGrid.StageRange(stage)
	local list = {}
	for i = lo, hi do
		for j = lo, hi do
			table.insert(list, IslandGrid.Key(i, j))
		end
	end
	return list
end

-- local offset of a cell center from the plot center (X = right, Z = forward/outward)
function IslandGrid.CellOffset(key: string): Vector3
	local i, j = IslandGrid.Parse(key)
	return Vector3.new((i - CENTER) * CELL, 0, (j - CENTER) * CELL)
end

function IslandGrid.CellCFrame(plotIndex: number, key: string): CFrame
	local off = IslandGrid.CellOffset(key)
	local plot = IslandGrid.PlotCFrame(plotIndex)
	-- CFrame.new(x, y, -z): local -Z is the LookVector (outward)
	return plot * CFrame.new(off.X, IslandGrid.TopY - Config.World.WaterLevel, -off.Z)
end

function IslandGrid.Radius(stage: number): number
	local lo, hi = IslandGrid.StageRange(stage)
	local far = math.max(math.abs(lo - CENTER), math.abs(hi - CENTER))
	return (far + 0.5) * CELL
end

-- Offset-space extents of a stage: minOff, maxOff on each axis (X right, Z outward).
function IslandGrid.Bounds(stage: number): (number, number)
	local lo, hi = IslandGrid.StageRange(stage)
	return (lo - CENTER - 0.5) * CELL, (hi - CENTER + 0.5) * CELL
end

return IslandGrid
