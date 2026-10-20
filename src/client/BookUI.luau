--[[
	BookUI  ("BOOK" side button)
	Every item grouped by set. Discovered items show their model, undiscovered show "???".
	Small dots show which variants you've caught. Completed sets show their permanent luck bonus.
]]
local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local ItemVisuals = require(game.ReplicatedStorage.Shared.ItemVisuals)
local ClientData = require(script.Parent.ClientData)
local UIKit = require(script.Parent.UIKit)
local Icons = require(script.Parent.Icons)
local HUDController = require(script.Parent.HUDController)

local player = Players.LocalPlayer
local BookUI = {}

local panel: Frame
local tabs: Frame
local grid: ScrollingFrame
local progress: TextLabel
local selectedSet = Config.Collection.SetOrder[1]

local itemsBySet = {}
for id, item in pairs(Config.Items) do
	itemsBySet[item.Set] = itemsBySet[item.Set] or {}
	table.insert(itemsBySet[item.Set], id)
end
for _, list in pairs(itemsBySet) do
	table.sort(list, function(a, b)
		local ta, tb = Config.Rarities[Config.Items[a].Rarity].Tier, Config.Rarities[Config.Items[b].Rarity].Tier
		if ta ~= tb then return ta < tb end
		return a < b
	end)
end

local VARIANT_COLORS = { Shiny = Color3.fromRGB(255, 255, 255), Golden = Color3.fromRGB(255, 205, 60), Rainbow = Color3.fromRGB(255, 90, 200) }

local function setComplete(collection, set)
	for _, id in ipairs(itemsBySet[set] or {}) do
		if not collection[id] then return false end
	end
	return true
end

local function render()
	if not panel.Visible then return end
	local collection = ClientData.Get().Collection
	-- tabs
	for _, b in ipairs(tabs:GetChildren()) do
		if b:IsA("TextButton") then
			local done = setComplete(collection, b.Name)
			b.Label.Text = (done and "* " or "") .. b.Name
			local active = b.Name == selectedSet
			b.UIGradient.Color = active and ColorSequence.new(Color3.fromRGB(255, 215, 100), Color3.fromRGB(230, 150, 30))
				or ColorSequence.new(Color3.fromRGB(150, 140, 190), Color3.fromRGB(90, 80, 140))
		end
	end
	-- grid
	for _, c in ipairs(grid:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	local list = itemsBySet[selectedSet] or {}
	local found = 0
	for i, id in ipairs(list) do
		local item = Config.Items[id]
		local known = collection[id] == true
		if known then found += 1 end
		local color = Config.Rarities[item.Rarity].Color
		local card = UIKit.Frame({ Name = id, LayoutOrder = i, BackgroundColor3 = Color3.new(1, 1, 1) })
		UIKit.Corner(card, 12)
		UIKit.Stroke(card, 3, UIKit.Dark, true)
		if known then
			UIKit.Gradient(card, color:Lerp(Color3.new(1, 1, 1), 0.25), color:Lerp(Color3.new(0, 0, 0), 0.35))
			UIKit.Viewport(card, ItemVisuals.Build(id, ""), { Size = UDim2.new(1, 0, 0.7, 0), Zoom = 1.15 })
		else
			UIKit.Gradient(card, Color3.fromRGB(70, 65, 90), Color3.fromRGB(40, 35, 55))
			local q = UIKit.Label({ Text = "?", Size = UDim2.new(0.5, 0, 0.5, 0), Position = UDim2.new(0.25, 0, 0.1, 0), TextColor3 = Color3.fromRGB(150, 145, 170) })
			q.Parent = card
		end
		local name = UIKit.Label({ Text = known and item.Name or "???", Size = UDim2.new(0.92, 0, 0.16, 0), Position = UDim2.new(0.04, 0, 0.72, 0) })
		name.Parent = card
		local rarity = UIKit.Label({ Text = item.Rarity, Size = UDim2.new(0.8, 0, 0.1, 0), Position = UDim2.new(0.1, 0, 0.88, 0), TextColor3 = color, StrokeThickness = 1.5 })
		rarity.Parent = card
		-- variant dots
		local x = 0
		for _, v in ipairs({ "Shiny", "Golden", "Rainbow" }) do
			if collection[id .. ":" .. v] then
				local dot = UIKit.Frame({ Size = UDim2.new(0, 12, 0, 12), Position = UDim2.new(0, 6 + x, 0, 6), BackgroundColor3 = VARIANT_COLORS[v] })
				UIKit.Corner(dot, 6)
				UIKit.Stroke(dot, 1.5, UIKit.Dark, true)
				dot.Parent = card
				x += 15
			end
		end
		card.Parent = grid
	end
	local done = found == #list
	progress.Text = ("%s: %d / %d found%s"):format(selectedSet, found, #list,
		done and ("  |  COMPLETE! +" .. math.floor(Config.Collection.SetLuckBonus * 100) .. "% luck forever")
		or ("  |  Complete for +" .. math.floor(Config.Collection.SetLuckBonus * 100) .. "% luck"))
	progress.TextColor3 = done and Color3.fromRGB(255, 225, 100) or Color3.fromRGB(220, 220, 240)
end

function BookUI.Start()
	local gui = player.PlayerGui:WaitForChild("HUD")
	panel = UIKit.Frame({ Name = "Book", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.new(0, 700, 0, 450), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false })
	UIKit.Corner(panel, 20)
	UIKit.Stroke(panel, 5, Color3.fromRGB(20, 10, 40), true)
	UIKit.Gradient(panel, Color3.fromRGB(150, 95, 60), Color3.fromRGB(85, 50, 30))
	panel.Parent = gui
	local h = UIKit.Button({ Name = "Header", Text = "COLLECTION BOOK", Size = UDim2.new(0, 300, 0, 50), Position = UDim2.new(0.5, -150, 0, -26),
		Top = Color3.fromRGB(255, 215, 100), Bottom = Color3.fromRGB(230, 150, 30) })
	h.Active = false
	h.Parent = panel
	Icons.Viewport(h, "Book", { Size = UDim2.new(0, 60, 0, 60), Position = UDim2.new(0, -36, 0.5, -31), ZIndex = 3 })
	local close = UIKit.Button({ Name = "Close", Text = "X", Size = UDim2.new(0, 46, 0, 46), Position = UDim2.new(1, -30, 0, -16),
		Top = Color3.fromRGB(255, 110, 110), Bottom = Color3.fromRGB(210, 40, 40) }, function() panel.Visible = false end)
	close.Parent = panel

	tabs = UIKit.Frame({ Name = "Tabs", BackgroundTransparency = 1, Position = UDim2.new(0, 16, 0, 36), Size = UDim2.new(1, -32, 0, 44) })
	local tl = Instance.new("UIListLayout"); tl.FillDirection = Enum.FillDirection.Horizontal; tl.Padding = UDim.new(0, 6); tl.SortOrder = Enum.SortOrder.LayoutOrder; tl.Parent = tabs
	tabs.Parent = panel
	for i, set in ipairs(Config.Collection.SetOrder) do
		local b = UIKit.Button({ Name = set, Text = set, Size = UDim2.new(1 / #Config.Collection.SetOrder, -6 * (#Config.Collection.SetOrder - 1) / #Config.Collection.SetOrder, 1, 0) }, function()
			selectedSet = set
			render()
		end)
		b.LayoutOrder = i
		b.Parent = tabs
	end

	progress = UIKit.Label({ Name = "Progress", Size = UDim2.new(1, -32, 0, 24), Position = UDim2.new(0, 16, 1, -36) })
	progress.Parent = panel

	grid = Instance.new("ScrollingFrame")
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Position = UDim2.new(0, 16, 0, 90)
	grid.Size = UDim2.new(1, -32, 1, -136)
	grid.ScrollBarThickness = 6
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.Parent = panel
	local gl = Instance.new("UIGridLayout"); gl.CellSize = UDim2.new(0, 108, 0, 132); gl.CellPadding = UDim2.new(0, 10, 0, 10)
	gl.SortOrder = Enum.SortOrder.LayoutOrder; gl.Parent = grid
	local pad = Instance.new("UIPadding"); pad.PaddingTop = UDim.new(0, 4); pad.PaddingLeft = UDim.new(0, 4); pad.Parent = grid

	HUDController.AddSideButton("Book", "BOOK", Color3.fromRGB(230, 170, 110), Color3.fromRGB(160, 95, 50), function()
		panel.Visible = not panel.Visible
		if panel.Visible then UIKit.Pop(panel); render() end
	end)
	ClientData.OnChanged("Collection", render)
end

return BookUI
