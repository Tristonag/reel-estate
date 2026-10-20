--[[
	HUDController
	Shells counter (top), side menu buttons (left), backpack panel.
	HUDController.AddSideButton(name, text, top, bottom, onClick) lets later phases add buttons.
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Format = require(game.ReplicatedStorage.Shared.Format)
local ItemVisuals = require(game.ReplicatedStorage.Shared.ItemVisuals)
local ClientData = require(script.Parent.ClientData)
local UIKit = require(script.Parent.UIKit)
local Icons = require(script.Parent.Icons)

local SIDE_ICONS = { Store = "GoldenChest", Bag = "Crates", Island = "Palm", Book = "Book", Home = "Hut", Hub = "Stand" }
local PlacementController = require(script.Parent.PlacementController)
local Remotes = game.ReplicatedStorage.Shared.Remotes

local player = Players.LocalPlayer
local HUDController = {}

local gui: ScreenGui
local side: Frame
local shellsLabel: TextLabel
local bagBadge: TextLabel
local panel: Frame
local grid: ScrollingFrame
local detail: any = {}
local selectedUid: string? = nil
local toggleBackpack
local displayedShells = 0

local VALUE_MULT = { [""] = 1 }
for _, v in ipairs(Config.Variants) do VALUE_MULT[v.Id] = v.Multiplier end
local function itemValue(entry)
	local item = Config.Items[entry.Id]
	return item and math.floor(item.Value * (VALUE_MULT[entry.Variant] or 1)) or 0
end

local function backpackCount(bp)
	local n = 0
	for _ in pairs(bp) do n += 1 end
	return n
end

------------------------------------------------------------------
-- Shells counter
------------------------------------------------------------------
local function floatText(text: string, color: Color3)
	local l = UIKit.Label({ Text = text, TextColor3 = color, Size = UDim2.new(0, 160, 0, 30),
		Position = UDim2.new(0.5, -20, 0, 70), StrokeThickness = 2.5 })
	l.Parent = gui
	TweenService:Create(l, TweenInfo.new(1.2), { Position = UDim2.new(0.5, -20, 0, 40), TextTransparency = 1 }):Play()
	TweenService:Create(l:FindFirstChildOfClass("UIStroke"), TweenInfo.new(1.2), { Transparency = 1 }):Play()
	game:GetService("Debris"):AddItem(l, 1.3)
end

local countTween = nil
local function setShells(value: number)
	local diff = value - displayedShells
	if diff > 0 and displayedShells > 0 then
		floatText("+" .. Format.Short(diff), Color3.fromRGB(150, 255, 170))
		local idleTick = (player:GetAttribute("IdleRate") or 0) * Config.Economy.IdleTickSeconds
		if diff > idleTick * 1.5 + 1 then
			local ok, sc = pcall(require, script.Parent.SoundController)
			if ok then sc.Play("Coin") end
		end
	end
	local start, target = displayedShells, value
	local nv = Instance.new("NumberValue")
	nv.Value = start
	nv.Changed:Connect(function(v) shellsLabel.Text = Format.Comma(v) end)
	if countTween then countTween:Cancel() end
	countTween = TweenService:Create(nv, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Value = target })
	countTween.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then shellsLabel.Text = Format.Comma(target) end
		nv:Destroy()
	end)
	countTween:Play()
	displayedShells = value
end

------------------------------------------------------------------
-- Side buttons
------------------------------------------------------------------
function HUDController.AddSideButton(name: string, text: string, top: Color3, bottom: Color3, onClick, iconName: string?)
	local b, label = UIKit.Button({ Name = name, Text = text, Top = top, Bottom = bottom, Radius = 16 }, onClick)
	-- icon on top, small label underneath
	label.Size = UDim2.new(0.92, 0, 0.26, 0)
	label.Position = UDim2.new(0.04, 0, 0.72, 0)
	Icons.Viewport(b, iconName or SIDE_ICONS[name] or "Gift", { Size = UDim2.new(0.86, 0, 0.66, 0), Position = UDim2.new(0.07, 0, 0.04, 0), Zoom = 0.95 })
	b.Parent = side
	return b
end

------------------------------------------------------------------
-- Backpack panel
------------------------------------------------------------------
local function showDetail(uid: string?)
	selectedUid = uid
	for _, c in ipairs(detail.View:GetChildren()) do c:Destroy() end
	local bp = ClientData.Get().Backpack
	local entry = uid and bp[uid]
	if not entry then
		detail.Name.Text = "Pick an item"
		detail.Rarity.Text = ""
		detail.Info.Text = ""
		detail.Sell.Visible = false
		detail.Place.Visible = false
		return
	end
	local item = Config.Items[entry.Id]
	local r = Config.Rarities[item.Rarity]
	UIKit.Viewport(detail.View, ItemVisuals.Build(entry.Id, entry.Variant), { Zoom = 1.2 })
	detail.Name.Text = (entry.Variant ~= "" and (entry.Variant .. " ") or "") .. item.Name
	detail.Rarity.Text = string.upper(item.Rarity)
	detail.Rarity.TextColor3 = r.Color
	detail.Info.Text = item.Set .. " set" .. (item.Idle > 0 and ("  |  +" .. item.Idle .. "/s when placed") or "")
	detail.SellLabel.Text = "SELL +" .. Format.Short(itemValue(entry))
	detail.Sell.Visible = true
	detail.Place.Visible = true
end

local function rebuildGrid()
	if not panel.Visible then return end
	for _, c in ipairs(grid:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	local bp = ClientData.Get().Backpack
	local list = {}
	for uid, entry in pairs(bp) do
		local item = Config.Items[entry.Id]
		if item then table.insert(list, { Uid = uid, Entry = entry, Item = item, Tier = Config.Rarities[item.Rarity].Tier, Value = itemValue(entry) }) end
	end
	table.sort(list, function(a, b)
		if a.Tier ~= b.Tier then return a.Tier > b.Tier end
		if a.Value ~= b.Value then return a.Value > b.Value end
		return tonumber(a.Uid) < tonumber(b.Uid)
	end)

	for i, e in ipairs(list) do
		local color = Config.Rarities[e.Item.Rarity].Color
		local card = Instance.new("TextButton")
		card.Name = e.Uid
		card.LayoutOrder = i
		card.Text = ""
		card.AutoButtonColor = false
		card.BackgroundColor3 = Color3.new(1, 1, 1)
		UIKit.Corner(card, 12)
		local st = UIKit.Stroke(card, e.Uid == selectedUid and 4 or 3, e.Uid == selectedUid and Color3.new(1, 1, 1) or UIKit.Dark, true)
		UIKit.Gradient(card, color:Lerp(Color3.new(1, 1, 1), 0.25), color:Lerp(Color3.new(0, 0, 0), 0.35))
		UIKit.Viewport(card, ItemVisuals.Build(e.Entry.Id, e.Entry.Variant), { Size = UDim2.new(1, 0, 0.72, 0), Zoom = 1.15 })
		local nameLabel = UIKit.Label({ Text = e.Item.Name, Size = UDim2.new(0.92, 0, 0.2, 0), Position = UDim2.new(0.04, 0, 0.76, 0) })
		nameLabel.Parent = card
		if e.Entry.Variant ~= "" then
			local tag = UIKit.Label({ Text = e.Entry.Variant, Size = UDim2.new(0.7, 0, 0.16, 0), Position = UDim2.new(0.15, 0, 0.03, 0),
				TextColor3 = Color3.fromRGB(255, 240, 120) })
			tag.Parent = card
		end
		card.Activated:Connect(function()
			showDetail(e.Uid)
			rebuildGrid()
		end)
		card.Parent = grid
	end

	detail.Empty.Visible = #list == 0
	local sellable = 0
	for _, e in ipairs(list) do
		if e.Tier <= 2 and e.Entry.Variant == "" then sellable += e.Value end
	end
	detail.SellAllLabel.Text = sellable > 0 and ("SELL COMMON + UNCOMMON  (+" .. Format.Short(sellable) .. ")") or "NOTHING CHEAP TO SELL"
	detail.SellAll.Visible = true
end

function toggleBackpack(open: boolean?)
	if open == nil then open = not panel.Visible end
	panel.Visible = open
	if open then
		UIKit.Pop(panel)
		showDetail(nil)
		rebuildGrid()
	end
end

local function buildPanel()
	panel = UIKit.Frame({ Name = "Backpack", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.new(0, 680, 0, 440), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false })
	UIKit.Corner(panel, 20)
	UIKit.Stroke(panel, 5, Color3.fromRGB(20, 10, 40), true)
	UIKit.Gradient(panel, Color3.fromRGB(80, 55, 140), Color3.fromRGB(40, 25, 75))
	local sizeLimit = Instance.new("UISizeConstraint"); sizeLimit.MaxSize = Vector2.new(680, 440); sizeLimit.Parent = panel
	panel.Parent = gui

	local header, headerLabel = UIKit.Button({ Name = "Header", Text = "BACKPACK", Size = UDim2.new(0, 240, 0, 50), Position = UDim2.new(0.5, -120, 0, -26),
		Top = Color3.fromRGB(255, 205, 90), Bottom = Color3.fromRGB(240, 135, 30) })
	header.Active = false
	header.Parent = panel
	HUDController.BackpackHeader = headerLabel
	Icons.Viewport(header, "Crates", { Size = UDim2.new(0, 60, 0, 60), Position = UDim2.new(0, -36, 0.5, -31), ZIndex = 3 })


	local close = UIKit.Button({ Name = "Close", Text = "X", Size = UDim2.new(0, 46, 0, 46), Position = UDim2.new(1, -30, 0, -16),
		Top = Color3.fromRGB(255, 110, 110), Bottom = Color3.fromRGB(210, 40, 40) }, function() toggleBackpack(false) end)
	close.Parent = panel

	grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Position = UDim2.new(0, 18, 0, 38)
	grid.Size = UDim2.new(1, -250, 1, -110)
	grid.ScrollBarThickness = 6
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.Parent = panel
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0, 94, 0, 112)
	layout.CellPadding = UDim2.new(0, 10, 0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	local pad = Instance.new("UIPadding"); pad.PaddingTop = UDim.new(0, 6); pad.PaddingLeft = UDim.new(0, 6); pad.Parent = grid

	local empty = UIKit.Label({ Name = "Empty", Text = "Empty! Go fish something up.", Size = UDim2.new(1, -250, 0, 30),
		Position = UDim2.new(0, 18, 0.4, 0), TextColor3 = Color3.fromRGB(200, 200, 220), Visible = false })
	empty.Parent = panel

	local info = UIKit.Frame({ Name = "Detail", Position = UDim2.new(1, -222, 0, 38), Size = UDim2.new(0, 204, 1, -110),
		BackgroundColor3 = Color3.fromRGB(30, 20, 55), BackgroundTransparency = 0.2 })
	UIKit.Corner(info, 14)
	info.Parent = panel
	local view = UIKit.Frame({ Name = "View", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 150) })
	view.Parent = info
	local rarity = UIKit.Label({ Name = "Rarity", Size = UDim2.new(0.9, 0, 0, 22), Position = UDim2.new(0.05, 0, 0, 150) })
	rarity.Parent = info
	local name = UIKit.Label({ Name = "ItemName", Size = UDim2.new(0.9, 0, 0, 30), Position = UDim2.new(0.05, 0, 0, 172) })
	name.Parent = info
	local desc = UIKit.Label({ Name = "Info", Size = UDim2.new(0.9, 0, 0, 18), Position = UDim2.new(0.05, 0, 0, 204), TextColor3 = Color3.fromRGB(200, 200, 220) })
	desc.Parent = info
	local place = UIKit.Button({ Name = "Place", Text = "PLACE", Size = UDim2.new(0.44, 0, 0, 44), Position = UDim2.new(0.04, 0, 1, -54),
		Top = Color3.fromRGB(120, 235, 130), Bottom = Color3.fromRGB(45, 170, 70) }, function()
		if not selectedUid then return end
		local uid = selectedUid
		toggleBackpack(false)
		PlacementController.Begin(uid)
	end)
	place.Parent = info
	local sell, sellLabel = UIKit.Button({ Name = "Sell", Text = "SELL", Size = UDim2.new(0.44, 0, 0, 44), Position = UDim2.new(0.52, 0, 1, -54),
		Top = Color3.fromRGB(255, 200, 90), Bottom = Color3.fromRGB(235, 130, 30) }, function()
		if not selectedUid then return end
		local uid = selectedUid
		selectedUid = nil
		pcall(function() Remotes.SellItems:InvokeServer({ uid }) end)
	end)
	sell.Parent = info

	local sellAll, sellAllLabel = UIKit.Button({ Name = "SellAll", Text = "SELL ALL", Size = UDim2.new(0, 400, 0, 46), Position = UDim2.new(0, 18, 1, -62),
		Top = Color3.fromRGB(255, 150, 120), Bottom = Color3.fromRGB(220, 70, 60) }, function()
		local bp = ClientData.Get().Backpack
		local uids = {}
		for uid, entry in pairs(bp) do
			local item = Config.Items[entry.Id]
			if item and Config.Rarities[item.Rarity].Tier <= 2 and entry.Variant == "" then table.insert(uids, uid) end
		end
		if #uids > 0 then pcall(function() Remotes.SellItems:InvokeServer(uids) end) end
	end)
	sellAll.Parent = panel

	detail = { View = view, Rarity = rarity, Name = name, Info = desc, Sell = sell, SellLabel = sellLabel, Place = place,
		SellAll = sellAll, SellAllLabel = sellAllLabel, Empty = empty }
end

------------------------------------------------------------------
function HUDController.ToggleBackpack(open: boolean?)
	toggleBackpack(open)
end

function HUDController.Start()
	gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Shells pill
	local pill = UIKit.Frame({ Name = "Shells", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.new(0, 230, 0, 52), BackgroundColor3 = Color3.new(1, 1, 1) })
	UIKit.Corner(pill, 26)
	UIKit.Stroke(pill, 4, Color3.fromRGB(20, 40, 60), true)
	UIKit.Gradient(pill, Color3.fromRGB(80, 190, 230), Color3.fromRGB(30, 110, 170))
	pill.Parent = gui
	local icon = UIKit.Frame({ Name = "Icon", Size = UDim2.new(0, 40, 0, 40), Position = UDim2.new(0, 6, 0.5, -20), BackgroundColor3 = Color3.new(1, 1, 1) })
	UIKit.Corner(icon, 20)
	UIKit.Stroke(icon, 3, Color3.fromRGB(120, 60, 60), true)
	UIKit.Gradient(icon, Color3.fromRGB(255, 225, 210), Color3.fromRGB(245, 150, 140))
	icon.Parent = pill
	icon.BackgroundTransparency = 1
	icon:FindFirstChildOfClass("UIStroke"):Destroy()
	Icons.Viewport(icon, "Shell", { Size = UDim2.new(1.5, 0, 1.5, 0), Position = UDim2.new(-0.25, 0, -0.3, 0), Zoom = 0.85, SpinSpeed = 0.5, ZIndex = 3 })
	shellsLabel = UIKit.Label({ Name = "Amount", Text = "0", Size = UDim2.new(1, -64, 0.66, 0), Position = UDim2.new(0, 54, 0.17, 0),
		StrokeThickness = 3, TextXAlignment = Enum.TextXAlignment.Left })
	shellsLabel.Parent = pill

	-- side menu
	side = UIKit.Frame({ Name = "Side", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.new(0, 166, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	local list = Instance.new("UIGridLayout")
	list.CellSize = UDim2.new(0, 78, 0, 78)
	list.CellPadding = UDim2.new(0, 8, 0, 8)
	list.FillDirectionMaxCells = 2
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = side
	side.Parent = gui

	local bag = HUDController.AddSideButton("Bag", "BAG", Color3.fromRGB(255, 190, 70), Color3.fromRGB(230, 120, 20), function() toggleBackpack() end)
	bagBadge = UIKit.Label({ Name = "Count", Text = "0/30", Size = UDim2.new(0, 56, 0, 20), Position = UDim2.new(1, -40, 0, -8), ZIndex = 5,
		TextColor3 = Color3.new(1, 1, 1), StrokeThickness = 2.5 })
	bagBadge.Parent = bag

	buildPanel()

	-- data bindings
	ClientData.OnChanged("Shells", setShells)
	player:GetAttributeChangedSignal("Pass_BiggerBackpack"):Connect(function()
		ClientData.Changed:Fire("Backpack", ClientData.Get().Backpack)
	end)
	ClientData.OnChanged("Backpack", function(bp)
		local n = backpackCount(bp)
		local cap = Config.Economy.BackpackSize + (player:GetAttribute("Pass_BiggerBackpack") and Config.Monetization.BackpackBonus or 0)
		bagBadge.Text = n .. "/" .. cap
		bagBadge.TextColor3 = n >= cap and Color3.fromRGB(255, 90, 90) or Color3.new(1, 1, 1)
		if selectedUid and not bp[selectedUid] then showDetail(nil) end
		rebuildGrid()
	end)
end

return HUDController
