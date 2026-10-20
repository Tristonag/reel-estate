--[[
	IslandService
	Builds each player's island from save data and handles every change to it.

	Plot model layout (workspace.Plots.Plot_<n>):
		Tiles  (Folder)  one Part per unlocked cell, attribute Cell = "i_j"
		Items  (Folder)  one Model per placed item, attributes Cell, Uid, ItemId
		Sign   (Part)    billboard with owner name + Island Score
	Model attributes: Owner (UserId), Plot (index), Stage

	Remotes (all validated here, the client only asks):
		PlaceItem(uid, cellKey, rot 0-3) -> { Ok, Reason? }
		PickUpItem(cellKey)              -> { Ok, Reason? }
		RotateItem(cellKey)              -> { Ok }
		ExpandIsland()                   -> { Ok, Stage?, Reason? }
]]
local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local IslandGrid = require(game.ReplicatedStorage.Shared.IslandGrid)
local ItemVisuals = require(game.ReplicatedStorage.Shared.ItemVisuals)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local FloaterService = require(script.Parent.FloaterService)
local RateLimit = require(script.Parent.RateLimit)
local IslandDecor = require(script.Parent.IslandDecor)
local PerkService = require(script.Parent.PerkService)

local Remotes = game.ReplicatedStorage.Shared.Remotes
local CELL = Config.Plots.CellSize

local IslandService = {}
local models: { [number]: Model } = {}

local VARIANT_MULT = { [""] = 1 }
for _, v in ipairs(Config.Variants) do VARIANT_MULT[v.Id] = v.Multiplier end

------------------------------------------------------------------
-- Score
------------------------------------------------------------------
function IslandService.GetScore(data): number
	local total = 0
	for _, entry in pairs(data.Island.Placed) do
		local item = Config.Items[entry.Id]
		if item then total += math.floor(item.Score * (VARIANT_MULT[entry.Variant] or 1)) end
	end
	return total
end

local function refreshScore(player: Player)
	local data = DataService.Get(player)
	local plot = PlotService.GetPlot(player)
	if not data then return end
	local score = IslandService.GetScore(data)
	player:SetAttribute("IslandScore", score)
	local ls = player:FindFirstChild("leaderstats")
	local v = ls and ls:FindFirstChild("Island")
	if v then v.Value = score end
	local model = plot and models[plot]
	local sign = model and model:FindFirstChild("Sign")
	local gui = sign and sign:FindFirstChild("Board")
	if gui then
		local stage = Config.IslandStages[data.Island.Stage]
		gui.Frame.Owner.Text = player.DisplayName .. "'s " .. stage.Name
		gui.Frame.Score.Text = "Island Score: " .. score
	end
end

------------------------------------------------------------------
-- Building
------------------------------------------------------------------
local function tileColor(stage, i, j)
	local c = stage.Color
	local base = Color3.fromRGB(c[1], c[2], c[3])
	-- gentle checker so the grid is readable without lines
	return ((i + j) % 2 == 0) and base or base:Lerp(Color3.new(0, 0, 0), 0.06)
end

local function buildTiles(model: Model, plot: number, stageIndex: number)
	local tiles = model:FindFirstChild("Tiles")
	if tiles then tiles:Destroy() end
	tiles = Instance.new("Folder")
	tiles.Name = "Tiles"
	local stage = Config.IslandStages[stageIndex]
	local material = Enum.Material[stage.Material] or Enum.Material.WoodPlanks
	for _, key in ipairs(IslandGrid.CellsForStage(stageIndex)) do
		local i, j = IslandGrid.Parse(key)
		local p = Instance.new("Part")
		p.Name = key
		p.Anchored = true
		p.Size = Vector3.new(CELL, 2, CELL)
		p.CFrame = IslandGrid.CellCFrame(plot, key) * CFrame.new(0, -1, 0)
		p.Material = material
		p.Color = tileColor(stage, i, j)
		p.TopSurface = Enum.SurfaceType.Smooth
		p:SetAttribute("Cell", key)
		p.Parent = tiles
	end
	tiles.Parent = model
	model:SetAttribute("Stage", stageIndex)
end

local function spawnItem(model: Model, plot: number, key: string, entry)
	local items = model:FindFirstChild("Items")
	local old = items:FindFirstChild(key)
	if old then old:Destroy() end
	local m = ItemVisuals.Build(entry.Id, entry.Variant)
	m.Name = key
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = true
			d.CanTouch = false
		end
	end
	m:SetAttribute("Cell", key)
	m:SetAttribute("Uid", entry.Uid)
	m:SetAttribute("ItemId", entry.Id)
	m:SetAttribute("Variant", entry.Variant or "")
	m:PivotTo(IslandGrid.CellCFrame(plot, key) * CFrame.Angles(0, (entry.Rot or 0) * math.pi / 2, 0))
	m.Parent = items
	return m
end

local function buildSign(model: Model, plot: number, stageIndex: number)
	local old = model:FindFirstChild("Sign")
	if old then old:Destroy() end
	local sign = Instance.new("Part")
	sign.Name = "Sign"
	sign.Anchored = true
	sign.CanCollide = false
	sign.CanQuery = false
	sign.Transparency = 1
	sign.Size = Vector3.new(1, 1, 1)
	-- behind the island (towards the hub), up high
	sign.CFrame = IslandGrid.PlotCFrame(plot) * CFrame.new(0, 14, IslandGrid.Radius(stageIndex) + 2)
	local board = Instance.new("BillboardGui")
	board.Name = "Board"
	board.Size = UDim2.new(0, 260, 0, 70)
	board.MaxDistance = 130
	board.AlwaysOnTop = false
	local frame = Instance.new("Frame")
	frame.Name = "Frame"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Parent = board
	local function lbl(name, y, h, color)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, h, 0)
		l.Position = UDim2.new(0, 0, y, 0)
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.TextColor3 = color
		local st = Instance.new("UIStroke"); st.Thickness = 2.5; st.Color = Color3.fromRGB(25, 20, 40); st.Parent = l
		l.Parent = frame
	end
	lbl("Owner", 0, 0.55, Color3.new(1, 1, 1))
	lbl("Score", 0.55, 0.45, Color3.fromRGB(255, 220, 90))
	board.Parent = sign
	sign.Parent = model
end

local function buildIsland(player: Player, plot: number)
	local data = DataService.Get(player)
	if not data then return end
	if models[plot] then models[plot]:Destroy() end

	local model = Instance.new("Model")
	model.Name = "Plot_" .. plot
	model:SetAttribute("Owner", player.UserId)
	model:SetAttribute("Plot", plot)
	local items = Instance.new("Folder"); items.Name = "Items"; items.Parent = model

	-- saves made before the grid grew: shift every cell key so items stay where they were
	local oldMax = data.Island.GridMax or 6
	if oldMax ~= IslandGrid.Max then
		local shift = math.floor((IslandGrid.Max - oldMax) / 2)
		local moved = {}
		for key, entry in pairs(data.Island.Placed) do
			local i, j = IslandGrid.Parse(key)
			if i then moved[IslandGrid.Key(i + shift, j + shift)] = entry end
		end
		data.Island.Placed = moved
	end
	data.Island.GridMax = IslandGrid.Max

	-- clean out anything invalid (e.g. bad data) before building
	for key, entry in pairs(data.Island.Placed) do
		if not IslandGrid.IsCellInStage(key, data.Island.Stage) or not Config.Items[entry.Id] then
			data.Island.Placed[key] = nil
		end
	end

	buildTiles(model, plot, data.Island.Stage)
	for key, entry in pairs(data.Island.Placed) do
		spawnItem(model, plot, key, entry)
	end
	buildSign(model, plot, data.Island.Stage)
	IslandDecor.Build(model, plot, data.Island.Stage)
	model.Parent = PlotService.Folder
	models[plot] = model
	refreshScore(player)
end

------------------------------------------------------------------
-- Remote handlers
------------------------------------------------------------------
local function backpackCount(data)
	local n = 0
	for _ in pairs(data.Backpack) do n += 1 end
	return n
end

local function context(player: Player)
	local data = DataService.Get(player)
	local plot = PlotService.GetPlot(player)
	local model = plot and models[plot]
	if not data or not model then return nil end
	return data, plot, model
end

local function onPlace(player: Player, uid: any, key: any, rot: any)
	if type(uid) ~= "string" or type(key) ~= "string" then return { Ok = false, Reason = "Bad" } end
	if not RateLimit.Check(player, "Island", 0.15) then return { Ok = false, Reason = "TooFast" } end
	rot = (type(rot) == "number" and rot == rot) and (math.floor(rot) % 4) or 0
	local data, plot, model = context(player)
	if not data then return { Ok = false, Reason = "NotReady" } end
	local entry = data.Backpack[uid]
	if not entry then return { Ok = false, Reason = "NoItem" } end
	if not IslandGrid.IsCellInStage(key, data.Island.Stage) then return { Ok = false, Reason = "OutOfBounds" } end
	if data.Island.Placed[key] then return { Ok = false, Reason = "Occupied" } end

	data.Backpack[uid] = nil
	local placed = { Uid = uid, Id = entry.Id, Variant = entry.Variant, Rot = rot }
	data.Island.Placed[key] = placed
	DataService.MarkChanged(player, "Backpack")
	DataService.MarkChanged(player, "Island")
	spawnItem(model, plot, key, placed)
	refreshScore(player)
	return { Ok = true }
end

local function onPickUp(player: Player, key: any)
	if type(key) ~= "string" then return { Ok = false, Reason = "Bad" } end
	if not RateLimit.Check(player, "Island", 0.15) then return { Ok = false, Reason = "TooFast" } end
	local data, _, model = context(player)
	if not data then return { Ok = false, Reason = "NotReady" } end
	local placed = data.Island.Placed[key]
	if not placed then return { Ok = false, Reason = "Empty" } end
	if backpackCount(data) >= PerkService.BackpackSize(player) then return { Ok = false, Reason = "BackpackFull" } end

	data.Island.Placed[key] = nil
	data.Backpack[placed.Uid] = { Id = placed.Id, Variant = placed.Variant }
	DataService.MarkChanged(player, "Backpack")
	DataService.MarkChanged(player, "Island")
	local m = model.Items:FindFirstChild(key)
	if m then m:Destroy() end
	refreshScore(player)
	return { Ok = true }
end

local function onRotate(player: Player, key: any)
	if type(key) ~= "string" then return { Ok = false } end
	if not RateLimit.Check(player, "Island", 0.1) then return { Ok = false } end
	local data, plot, model = context(player)
	if not data then return { Ok = false } end
	local placed = data.Island.Placed[key]
	if not placed then return { Ok = false } end
	placed.Rot = ((placed.Rot or 0) + 1) % 4
	DataService.MarkChanged(player, "Island")
	local m = model.Items:FindFirstChild(key)
	if m then m:PivotTo(IslandGrid.CellCFrame(plot, key) * CFrame.Angles(0, placed.Rot * math.pi / 2, 0)) end
	return { Ok = true }
end

local function onExpand(player: Player)
	if not RateLimit.Check(player, "Expand", 1) then return { Ok = false, Reason = "TooFast" } end
	local data, plot, model = context(player)
	if not data then return { Ok = false, Reason = "NotReady" } end
	local nextIndex = data.Island.Stage + 1
	local nextStage = Config.IslandStages[nextIndex]
	if not nextStage then return { Ok = false, Reason = "Max" } end
	if IslandService.GetScore(data) < (nextStage.ScoreRequired or 0) then return { Ok = false, Reason = "Score" } end
	if not DataService.SpendShells(player, nextStage.Price) then return { Ok = false, Reason = "NotEnough" } end

	data.Island.Stage = nextIndex
	DataService.MarkChanged(player, "Island")
	buildTiles(model, plot, nextIndex)
	buildSign(model, plot, nextIndex)
	IslandDecor.Build(model, plot, nextIndex)
	refreshScore(player)
	-- containers that are now under the island sink away
	FloaterService.ClearInside(plot, IslandGrid.Radius(nextIndex) * 1.45 + 18)
	return { Ok = true, Stage = nextIndex }
end

------------------------------------------------------------------
-- full rebuild from save data (used by Rebirth)
function IslandService.Rebuild(player: Player)
	local plot = PlotService.GetPlot(player)
	if plot then buildIsland(player, plot) end
end

function IslandService.GetModel(plot: number): Model?
	return models[plot]
end

function IslandService.Start()
	PlotService.Assigned.Event:Connect(function(player: Player, plot: number)
		-- leaderstat for island score
		buildIsland(player, plot)
		task.spawn(function()
			local ls = player:WaitForChild("leaderstats", 10)
			if ls and not ls:FindFirstChild("Island") then
				local v = Instance.new("IntValue"); v.Name = "Island"; v.Parent = ls
				refreshScore(player)
			end
		end)
	end)
	PlotService.Freed.Event:Connect(function(_, plot: number)
		if models[plot] then models[plot]:Destroy(); models[plot] = nil end
	end)

	Remotes.PlaceItem.OnServerInvoke = onPlace
	Remotes.PickUpItem.OnServerInvoke = onPickUp
	Remotes.RotateItem.OnServerInvoke = onRotate
	Remotes.ExpandIsland.OnServerInvoke = onExpand
end

return IslandService
