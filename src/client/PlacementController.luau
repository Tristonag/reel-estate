--[[
	PlacementController
	- Placing: ghost preview snaps to your island tiles. Click a free tile (or tap it, then PLACE)
	  R = rotate, Q / Esc = cancel.
	- Editing: with no tool equipped, click an item on your island to Rotate or Pick Up.

	PlacementController.Begin(uid)   -- start placing a backpack item
	PlacementController.IsBusy()
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local IslandGrid = require(game.ReplicatedStorage.Shared.IslandGrid)
local ItemVisuals = require(game.ReplicatedStorage.Shared.ItemVisuals)
local ClientData = require(script.Parent.ClientData)
local UIKit = require(script.Parent.UIKit)
local Remotes = game.ReplicatedStorage.Shared.Remotes

local player = Players.LocalPlayer
local PlacementController = {}

local gui: ScreenGui
local bar: Frame
local barTitle: TextLabel
local barHint: TextLabel
local placeBtn: TextButton
local popup: Frame
local popupTitle: TextLabel

local placing = false
local placingUid: string? = nil
local ghost: Model? = nil
local highlight: Highlight
local rot = 0
local selectedCell: string? = nil
local lastPointer: Vector2? = nil
local editingCell: string? = nil

------------------------------------------------------------------
local function myPlotModel(): Model?
	local plot = player:GetAttribute("Plot")
	local plots = workspace:FindFirstChild("Plots")
	return plot and plots and plots:FindFirstChild("Plot_" .. plot) or nil
end

local function isOccupied(key: string): boolean
	local placed = ClientData.Get().Island.Placed
	return placed[key] ~= nil
end

-- raycast from a screen point onto my island; returns cell key and what was hit
local function cellAt(screenPos: Vector2): (string?, Instance?)
	local model = myPlotModel()
	if not model then return nil end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { model:FindFirstChild("Tiles"), model:FindFirstChild("Items") }
	local ray = workspace.CurrentCamera:ViewportPointToRay(screenPos.X, screenPos.Y)
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	if not hit then return nil end
	local inst = hit.Instance
	while inst and inst ~= model do
		local key = inst:GetAttribute("Cell")
		if key then return key, inst end
		inst = inst.Parent
	end
	return nil
end

------------------------------------------------------------------
-- Placing
------------------------------------------------------------------
local function setGhostTransparency(model: Model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Transparency = math.max(d.Transparency, 0.35)
			d.CanQuery = false
			d.CanCollide = false
			d.CanTouch = false
		elseif d:IsA("ParticleEmitter") then
			d.Enabled = false
		end
	end
end

local function stopPlacing()
	placing = false
	placingUid = nil
	selectedCell = nil
	if ghost then ghost:Destroy(); ghost = nil end
	bar.Visible = false
end

local function tryPlace()
	if not placing or not selectedCell or isOccupied(selectedCell) then return end
	local uid, key = placingUid, selectedCell
	local ok, result = pcall(function() return Remotes.PlaceItem:InvokeServer(uid, key, rot) end)
	if ok and result and result.Ok then
		stopPlacing()
	else
		barHint.Text = "Can't place there!"
	end
end

function PlacementController.Begin(uid: string)
	local entry = ClientData.Get().Backpack[uid]
	if not entry then return end
	if placing then stopPlacing() end
	PlacementController.CloseEditor()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then hum:UnequipTools() end

	placing = true
	placingUid = uid
	rot = 0
	selectedCell = nil
	ghost = ItemVisuals.Build(entry.Id, entry.Variant)
	setGhostTransparency(ghost)
	ghost.Parent = workspace.CurrentCamera
	highlight.Adornee = ghost
	-- park it out of view until a tile is under the pointer
	ghost:PivotTo(CFrame.new(0, -500, 0))

	local item = Config.Items[entry.Id]
	barTitle.Text = "Placing: " .. (entry.Variant ~= "" and (entry.Variant .. " ") or "") .. (item and item.Name or entry.Id)
	barHint.Text = UserInputService.TouchEnabled and "Tap a tile on your island" or "Click a tile on your island  |  R rotate  |  Q cancel"
	bar.Visible = true
	UIKit.Pop(bar)
end

function PlacementController.IsBusy(): boolean
	return placing
end

------------------------------------------------------------------
-- Editing placed items
------------------------------------------------------------------
function PlacementController.CloseEditor()
	editingCell = nil
	if popup then popup.Visible = false end
end

local function openEditor(key: string)
	local entry = ClientData.Get().Island.Placed[key]
	if not entry then return end
	editingCell = key
	local item = Config.Items[entry.Id]
	local mult = Config.VariantIdleMultiplier[entry.Variant] or 1
	local rate = item and item.Idle * mult or 0
	popupTitle.Text = (entry.Variant ~= "" and (entry.Variant .. " ") or "") .. (item and item.Name or entry.Id)
		.. (rate > 0 and ("  (+" .. (rate % 1 == 0 and rate or string.format("%.1f", rate)) .. "/s)") or "")
	popupTitle.TextColor3 = item and Config.Rarities[item.Rarity].Color or Color3.new(1, 1, 1)
	popup.Visible = true
	UIKit.Pop(popup)
end

------------------------------------------------------------------
local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "PlacementUI"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	-- placing bar
	bar = UIKit.Frame({ Name = "Bar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -96),
		Size = UDim2.new(0, 520, 0, 120), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false })
	UIKit.Corner(bar, 18)
	UIKit.Stroke(bar, 4, Color3.fromRGB(20, 10, 40), true)
	UIKit.Gradient(bar, Color3.fromRGB(80, 55, 140), Color3.fromRGB(40, 25, 75))
	bar.Parent = gui
	barTitle = UIKit.Label({ Name = "Title", Size = UDim2.new(1, -20, 0, 30), Position = UDim2.new(0, 10, 0, 8), StrokeThickness = 3 })
	barTitle.Parent = bar
	barHint = UIKit.Label({ Name = "Hint", Size = UDim2.new(1, -20, 0, 18), Position = UDim2.new(0, 10, 0, 38), TextColor3 = Color3.fromRGB(210, 210, 230) })
	barHint.Parent = bar
	local rotate = UIKit.Button({ Name = "Rotate", Text = "ROTATE", Size = UDim2.new(0, 150, 0, 46), Position = UDim2.new(0, 16, 1, -58),
		Top = Color3.fromRGB(120, 200, 255), Bottom = Color3.fromRGB(50, 120, 230) }, function() rot = (rot + 1) % 4 end)
	rotate.Parent = bar
	placeBtn = UIKit.Button({ Name = "Place", Text = "PLACE", Size = UDim2.new(0, 170, 0, 46), Position = UDim2.new(0.5, -85, 1, -58),
		Top = Color3.fromRGB(120, 235, 130), Bottom = Color3.fromRGB(45, 170, 70) }, tryPlace)
	placeBtn.Parent = bar
	local cancel = UIKit.Button({ Name = "Cancel", Text = "CANCEL", Size = UDim2.new(0, 150, 0, 46), Position = UDim2.new(1, -166, 1, -58),
		Top = Color3.fromRGB(255, 110, 110), Bottom = Color3.fromRGB(210, 40, 40) }, stopPlacing)
	cancel.Parent = bar

	-- placed item editor popup
	popup = UIKit.Frame({ Name = "Editor", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -96),
		Size = UDim2.new(0, 460, 0, 110), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false })
	UIKit.Corner(popup, 18)
	UIKit.Stroke(popup, 4, Color3.fromRGB(20, 10, 40), true)
	UIKit.Gradient(popup, Color3.fromRGB(80, 55, 140), Color3.fromRGB(40, 25, 75))
	popup.Parent = gui
	popupTitle = UIKit.Label({ Name = "Title", Size = UDim2.new(1, -20, 0, 32), Position = UDim2.new(0, 10, 0, 8), StrokeThickness = 3 })
	popupTitle.Parent = popup
	local eRotate = UIKit.Button({ Name = "Rotate", Text = "ROTATE", Size = UDim2.new(0, 140, 0, 46), Position = UDim2.new(0, 16, 1, -58),
		Top = Color3.fromRGB(120, 200, 255), Bottom = Color3.fromRGB(50, 120, 230) }, function()
		if editingCell then pcall(function() Remotes.RotateItem:InvokeServer(editingCell) end) end
	end)
	eRotate.Parent = popup
	local pick = UIKit.Button({ Name = "PickUp", Text = "PICK UP", Size = UDim2.new(0, 150, 0, 46), Position = UDim2.new(0.5, -75, 1, -58),
		Top = Color3.fromRGB(255, 200, 90), Bottom = Color3.fromRGB(235, 130, 30) }, function()
		if not editingCell then return end
		local key = editingCell
		local ok, r = pcall(function() return Remotes.PickUpItem:InvokeServer(key) end)
		if ok and r and r.Ok then
			PlacementController.CloseEditor()
		elseif ok and r and r.Reason == "BackpackFull" then
			popupTitle.Text = "Backpack is full!"
		end
	end)
	pick.Parent = popup
	local close = UIKit.Button({ Name = "Close", Text = "CLOSE", Size = UDim2.new(0, 130, 0, 46), Position = UDim2.new(1, -146, 1, -58),
		Top = Color3.fromRGB(200, 200, 215), Bottom = Color3.fromRGB(130, 130, 150) }, PlacementController.CloseEditor)
	close.Parent = popup

	highlight = Instance.new("Highlight")
	highlight.FillTransparency = 0.55
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = gui
end

function PlacementController.Start()
	build()

	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			lastPointer = UserInputService:GetMouseLocation()
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.R and placing and not processed then
			rot = (rot + 1) % 4
			return
		end
		if (input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.Escape) and placing then
			stopPlacing()
			return
		end
		if processed then return end
		local isClick = input.UserInputType == Enum.UserInputType.MouseButton1
		local isTap = input.UserInputType == Enum.UserInputType.Touch
		if not (isClick or isTap) then return end
		-- raycasts need viewport coordinates: InputObject.Position excludes the top bar inset
		local pos
		if isClick then
			pos = UserInputService:GetMouseLocation()
		else
			local inset = GuiService:GetGuiInset()
			pos = Vector2.new(input.Position.X, input.Position.Y) + inset
		end
		lastPointer = pos

		if placing then
			local key = cellAt(pos)
			if key then
				selectedCell = key
				if isClick and not isOccupied(key) then tryPlace() end
			end
			return
		end

		-- editing: only with empty hands, so rod clicks never open the editor
		local char = player.Character
		if char and char:FindFirstChildOfClass("Tool") then return end
		local model = myPlotModel()
		local itemsFolder = model and model:FindFirstChild("Items")
		local key, hitInst = cellAt(pos)
		if key and hitInst and itemsFolder and hitInst:IsDescendantOf(itemsFolder) then
			openEditor(key)
		end
	end)

	RunService.RenderStepped:Connect(function()
		if not placing or not ghost then return end
		if lastPointer and not UserInputService.TouchEnabled then
			local key = cellAt(lastPointer)
			if key then selectedCell = key end
		end
		local plot = player:GetAttribute("Plot")
		if selectedCell and plot then
			ghost:PivotTo(IslandGrid.CellCFrame(plot, selectedCell) * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, rot * math.pi / 2, 0))
			local bad = isOccupied(selectedCell)
			highlight.FillColor = bad and Color3.fromRGB(255, 70, 70) or Color3.fromRGB(90, 255, 120)
			highlight.OutlineColor = highlight.FillColor
			placeBtn.Label.Text = bad and "TAKEN" or "PLACE"
		end
	end)

	-- if the item leaves the backpack some other way (sold), stop placing it
	ClientData.OnChanged("Backpack", function(bp)
		if placing and placingUid and not bp[placingUid] then stopPlacing() end
	end)
	ClientData.OnChanged("Island", function(island)
		if editingCell and not island.Placed[editingCell] then PlacementController.CloseEditor() end
	end)
end

return PlacementController
