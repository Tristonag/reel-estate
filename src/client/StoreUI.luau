--[[
	StoreUI ("STORE" button, the Boosts stall)
	Card grid: big spinning 3D art, name, short description, bold price pill, ribbons
	(POPULAR / BEST VALUE / ONE TIME). Prices come live from Roblox (regional prices included).
	Items with Id = 0 in Config.Monetization show "SOON".

	Paid Random Items policy:
	- anything random or luck-changing has an ODDS / DETAILS button with exact numeric odds (OddsUI)
	- players where PolicyService says paid random items are restricted (attribute PaidRandomRestricted)
	  don't see those items, or the Shell bundles that could buy luck, at all
]]
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local ClientData = require(script.Parent.ClientData)
local UIKit = require(script.Parent.UIKit)
local Icons = require(script.Parent.Icons)
local HUDController = require(script.Parent.HUDController)
local OddsUI = require(script.Parent.OddsUI)

-- hidden for players in regions that restrict paid random items
local RESTRICTED = { DoubleLuck = true, GoldenChest = true, LuckyBait = true, SummonShipwreck = true,
	ShellsSmall = true, ShellsLarge = true, StarterPack = true }

local function wreckMix(): string
	local loot = Config.Shipwreck.Loot
	local total = 0
	for _, w in pairs(loot) do total += w end
	local parts = {}
	for _, id in ipairs({ "Crate", "Barrel", "Bottle", "Chest", "GoldenChest", "Relic" }) do
		if loot[id] then table.insert(parts, ("%s %s%%"):format(Config.Containers[id].Name, tostring(math.floor(loot[id] / total * 10000 + 0.5) / 100))) end
	end
	return "A Shipwreck spawns: " .. table.concat(parts, ", ") .. ". Pick a container for its exact odds."
end

-- odds / details popup for each random or luck-changing purchase
local DETAILS = {
	GoldenChest = { Text = "ODDS", Open = function()
		OddsUI.Show({ Container = "GoldenChest", Context = "Product", Lock = true, Title = "Golden Chest from the Store" })
	end },
	DoubleLuck = { Text = "DETAILS", Open = function()
		local owned = player:GetAttribute("Pass_DoubleLuck")
		OddsUI.Show({ Container = "Chest", Context = "Fish", PreviewMult = (not owned) and 2 or nil, PreviewLabel = "With 2x Luck",
			Extra = owned and "You own 2x Luck, it's already in your odds." or "2x Luck doubles your luck. Each rarer tier's weight is multiplied by your luck once per tier step." })
	end },
	LuckyBait = { Text = "DETAILS", Open = function()
		OddsUI.Show({ Container = "Chest", Context = "Fish", PreviewMult = Config.Baits.Glowbug.Luck, PreviewLabel = "With Glowbug",
			Extra = "Glowbug bait = x" .. Config.Baits.Glowbug.Luck .. " luck for 30 catches (it doesn't stack with other bait)." })
	end },
	StarterPack = { Text = "DETAILS", Open = function()
		OddsUI.Show({ Container = "Chest", Context = "Fish", PreviewMult = Config.Baits.Glowbug.Luck, PreviewLabel = "With Glowbug",
			Extra = "Starter Pack: 5,000 Shells + Fiberglass Rod (Luck x" .. Config.Rods[3].Luck .. ") + 10 Glowbug bait (Luck x" .. Config.Baits.Glowbug.Luck .. " each catch)." })
	end },
	SummonShipwreck = { Text = "DETAILS", Open = function()
		OddsUI.Show({ Container = "Chest", Context = "Wreck", Containers = { "Barrel", "Bottle", "Chest", "GoldenChest", "Relic" },
			Title = "Shipwreck containers", Extra = wreckMix() })
	end },
}

local player = Players.LocalPlayer
local M = Config.Monetization
local StoreUI = {}

local panel: Frame
local grid: ScrollingFrame
local tab = "Passes"
local tabButtons = {}
local priceCache: { [string]: string } = {}

local GOLD = { Color3.fromRGB(255, 215, 100), Color3.fromRGB(230, 150, 30) }
local GREEN = { Color3.fromRGB(120, 235, 130), Color3.fromRGB(45, 170, 70) }
local GREY = { Color3.fromRGB(170, 170, 185), Color3.fromRGB(110, 110, 125) }

-- art + card colors per item
local THEME = {
	DoubleLuck      = { Icon = "Clover",      Top = Color3.fromRGB(120, 235, 110), Bottom = Color3.fromRGB(30, 140, 60),   Ribbon = "POPULAR" },
	TurboReel       = { Icon = "Reel",        Top = Color3.fromRGB(110, 215, 255), Bottom = Color3.fromRGB(30, 100, 200) },
	BiggerBackpack  = { Icon = "BackpackPlus",      Top = Color3.fromRGB(255, 185, 100), Bottom = Color3.fromRGB(200, 100, 30) },
	VIP             = { Icon = "Crown",       Top = Color3.fromRGB(255, 225, 110), Bottom = Color3.fromRGB(215, 130, 20) },
	SkipReveal      = { Icon = "FastForward", Top = Color3.fromRGB(150, 160, 255), Bottom = Color3.fromRGB(70, 60, 200) },
	StarterPack     = { Icon = "Gift",        Top = Color3.fromRGB(255, 150, 200), Bottom = Color3.fromRGB(210, 60, 130),  Ribbon = "ONE TIME" },
	GoldenChest     = { Icon = "GoldenChest", Top = Color3.fromRGB(255, 225, 110), Bottom = Color3.fromRGB(200, 120, 20) },
	LuckyBait       = { Icon = "Glowbug",     Top = Color3.fromRGB(200, 255, 120), Bottom = Color3.fromRGB(80, 170, 40) },
	SummonShipwreck = { Icon = "Ship",        Top = Color3.fromRGB(110, 225, 220), Bottom = Color3.fromRGB(20, 120, 140) },
	ShellsSmall     = { Icon = "Treasure",    Top = Color3.fromRGB(255, 215, 150), Bottom = Color3.fromRGB(210, 140, 60) },
	ShellsLarge     = { Icon = "Chest",       Top = Color3.fromRGB(210, 150, 255), Bottom = Color3.fromRGB(120, 50, 200),  Ribbon = "BEST VALUE" },
}

local function goldenOdds(): string
	local loot = Config.Containers.GoldenChest.Loot
	local total = 0
	for _, w in pairs(loot) do total += w end
	local parts = {}
	for _, r in ipairs(Config.RarityOrder) do
		if loot[r] then table.insert(parts, ("%s %d%%"):format(r, math.floor(loot[r] / total * 100 + 0.5))) end
	end
	return table.concat(parts, " | ")
end

local function priceText(kind: string, id: number, cb)
	local key = kind .. id
	if priceCache[key] then cb(priceCache[key]) return end
	task.spawn(function()
		local infoType = kind == "Pass" and Enum.InfoType.GamePass or Enum.InfoType.Product
		-- GetProductInfoAsync returns the player's regional price (Managed Pricing)
		local ok, info = pcall(function() return MarketplaceService:GetProductInfoAsync(id, infoType) end)
		if not ok then
			ok, info = pcall(function() return MarketplaceService:GetProductInfo(id, infoType) end)
		end
		local text = (ok and info and info.PriceInRobux) and ("R$ " .. info.PriceInRobux) or "BUY"
		priceCache[key] = text
		cb(text)
	end)
end

local function setBtn(btn, lbl, text, colors)
	lbl.Text = text
	btn.UIGradient.Color = ColorSequence.new(colors[1], colors[2])
end

local function card(order: number, key: string, name: string, desc: string)
	local theme = THEME[key] or THEME.StarterPack
	local c = UIKit.Frame({ Name = key, LayoutOrder = order, BackgroundColor3 = Color3.new(1, 1, 1) })
	UIKit.Corner(c, 18)
	UIKit.Stroke(c, 4, UIKit.Dark, true)
	UIKit.Gradient(c, theme.Top, theme.Bottom)
	-- soft light burst behind the art
	local glow = UIKit.Frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.3, 0), Size = UDim2.new(0.7, 0, 0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.72 })
	UIKit.Corner(glow, 80)
	glow.Parent = c
	Icons.Viewport(c, theme.Icon, { Size = UDim2.new(0.8, 0, 0.5, 0), Position = UDim2.new(0.1, 0, 0.04, 0), Zoom = 0.9, ZIndex = 2 })
	local title = UIKit.Label({ Text = name, Size = UDim2.new(0.9, 0, 0.12, 0), Position = UDim2.new(0.05, 0, 0.53, 0), StrokeThickness = 3, ZIndex = 3 })
	title.Parent = c
	local d = Instance.new("TextLabel")
	d.BackgroundTransparency = 1
	d.Size = UDim2.new(0.9, 0, 0.14, 0)
	d.Position = UDim2.new(0.05, 0, 0.655, 0)
	d.Font = UIKit.Font
	d.TextScaled = true
	d.TextWrapped = true
	d.TextColor3 = Color3.new(1, 1, 1)
	d.Text = desc
	d.ZIndex = 3
	UIKit.Stroke(d, 1.5)
	d.Parent = c
	local btn, lbl = UIKit.Button({ Name = "Buy", Text = "...", Size = UDim2.new(0.84, 0, 0.15, 0), Position = UDim2.new(0.08, 0, 0.82, 0),
		Top = GOLD[1], Bottom = GOLD[2] })
	btn.ZIndex = 3
	btn.Parent = c
	if theme.Ribbon then
		local ribbon = UIKit.Frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.82, 0, 0.07, 0), Size = UDim2.new(0.58, 0, 0.1, 0),
			Rotation = 18, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 4 })
		UIKit.Corner(ribbon, 8)
		UIKit.Stroke(ribbon, 2.5, UIKit.Dark, true)
		UIKit.Gradient(ribbon, Color3.fromRGB(255, 90, 110), Color3.fromRGB(200, 30, 60))
		local rl = UIKit.Label({ Text = theme.Ribbon, Size = UDim2.new(0.9, 0, 0.8, 0), Position = UDim2.new(0.05, 0, 0.1, 0), ZIndex = 5 })
		rl.Parent = ribbon
		ribbon.Parent = c
	end
	local det = DETAILS[key]
	if det then
		local db = UIKit.Button({ Name = "Details", Text = det.Text, Size = UDim2.new(0.4, 0, 0.1, 0), Position = UDim2.new(0.04, 0, 0.03, 0),
			Top = Color3.fromRGB(110, 215, 255), Bottom = Color3.fromRGB(30, 100, 200) }, det.Open)
		db.ZIndex = 5
		db.Parent = c
	end
	c.Parent = grid
	return btn, lbl
end

local function sorted(tbl)
	local keys = {}
	for k in pairs(tbl) do table.insert(keys, k) end
	table.sort(keys, function(a, b) return tbl[a].Order < tbl[b].Order end)
	return keys
end

local restrictedNote: TextLabel

local function render()
	if not panel.Visible then return end
	for _, c in ipairs(grid:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
	local restricted = player:GetAttribute("PaidRandomRestricted") == true
	local hidden = false
	for name, b in pairs(tabButtons) do
		b.UIGradient.Color = name == tab and ColorSequence.new(GOLD[1], GOLD[2]) or ColorSequence.new(Color3.fromRGB(150, 140, 190), Color3.fromRGB(90, 80, 140))
	end

	if tab == "Passes" then
		for i, key in ipairs(sorted(M.GamePasses)) do
			local p = M.GamePasses[key]
			if restricted and RESTRICTED[key] then hidden = true continue end
			local btn, lbl = card(i, key, p.Name, p.Desc)
			if player:GetAttribute("Pass_" .. key) then
				setBtn(btn, lbl, "OWNED", GREEN)
			elseif p.Id == 0 then
				setBtn(btn, lbl, "SOON", GREY)
			else
				priceText("Pass", p.Id, function(t) if lbl.Parent then lbl.Text = t end end)
				btn.Activated:Connect(function() MarketplaceService:PromptGamePassPurchase(player, p.Id) end)
			end
		end
	else
		local flags = ClientData.Get().Flags
		local order = 0
		for _, key in ipairs(sorted(M.Products)) do
			local p = M.Products[key]
			if restricted and RESTRICTED[key] then
				hidden = true
			elseif not (key == "StarterPack" and flags.StarterPack) then
				order += 1
				local desc = p.Desc
				local btn, lbl = card(order, key, p.Name, desc)
				if p.Id == 0 then
					setBtn(btn, lbl, "SOON", GREY)
				else
					priceText("Product", p.Id, function(t) if lbl.Parent then lbl.Text = t end end)
					btn.Activated:Connect(function() MarketplaceService:PromptProductPurchase(player, p.Id) end)
				end
			end
		end
	end
	restrictedNote.Visible = hidden
end

function StoreUI.Open(which: string?)
	if which then tab = which end
	panel.Visible = true
	UIKit.Pop(panel)
	render()
end

function StoreUI.Start()
	local gui = player.PlayerGui:WaitForChild("HUD")
	panel = UIKit.Frame({ Name = "Store", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.new(0, 640, 0, 470), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false })
	UIKit.Corner(panel, 22)
	UIKit.Stroke(panel, 5, Color3.fromRGB(20, 10, 40), true)
	UIKit.Gradient(panel, Color3.fromRGB(95, 60, 160), Color3.fromRGB(40, 22, 80))
	panel.Parent = gui

	local header, hl = UIKit.Button({ Name = "Header", Text = "   STORE", Size = UDim2.new(0, 240, 0, 56), Position = UDim2.new(0.5, -120, 0, -30),
		Top = GOLD[1], Bottom = GOLD[2] })
	header.Active = false
	header.Parent = panel
	Icons.Viewport(header, "GoldenChest", { Size = UDim2.new(0, 64, 0, 64), Position = UDim2.new(0, -38, 0.5, -33), ZIndex = 3 })
	local close = UIKit.Button({ Name = "Close", Text = "X", Size = UDim2.new(0, 48, 0, 48), Position = UDim2.new(1, -32, 0, -18),
		Top = Color3.fromRGB(255, 110, 110), Bottom = Color3.fromRGB(210, 40, 40) }, function() panel.Visible = false end)
	close.Parent = panel

	for i, name in ipairs({ "Passes", "Items" }) do
		local b = UIKit.Button({ Name = name, Text = name == "Passes" and "GAME PASSES" or "ITEMS",
			Size = UDim2.new(0, 210, 0, 42), Position = UDim2.new(0.5, i == 1 and -216 or 6, 0, 36) }, function()
			tab = name
			render()
		end)
		b.Parent = panel
		tabButtons[name] = b
	end

	grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Position = UDim2.new(0, 16, 0, 90)
	grid.Size = UDim2.new(1, -26, 1, -104)
	grid.ScrollBarThickness = 6
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.Parent = panel
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0, 186, 0, 236)
	layout.CellPadding = UDim2.new(0, 12, 0, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = grid
	local pad = Instance.new("UIPadding"); pad.PaddingTop = UDim.new(0, 12); pad.PaddingBottom = UDim.new(0, 8); pad.Parent = grid

	restrictedNote = UIKit.Label({ Name = "RegionNote", Text = "Some items aren't available in your region.", Size = UDim2.new(1, -40, 0, 16),
		Position = UDim2.new(0, 20, 1, -20), TextColor3 = Color3.fromRGB(220, 210, 255), Visible = false })
	restrictedNote.Parent = panel

	-- general odds for fishing (all containers, current luck incl. bait)
	local oddsBtn = UIKit.Button({ Name = "Odds", Text = "ODDS", Size = UDim2.new(0, 82, 0, 38), Position = UDim2.new(0, 12, 0, 38),
		Top = Color3.fromRGB(110, 215, 255), Bottom = Color3.fromRGB(30, 100, 200) }, function()
		OddsUI.Show({ Container = "Crate", Context = "Fish" })
	end)
	oddsBtn.Parent = panel

	local storeBtn = HUDController.AddSideButton("Store", "STORE", GOLD[1], GOLD[2], function()
		if panel.Visible then panel.Visible = false else StoreUI.Open() end
	end)
	storeBtn.LayoutOrder = -1

	for key in pairs(M.GamePasses) do
		player:GetAttributeChangedSignal("Pass_" .. key):Connect(render)
	end
	ClientData.OnChanged("Flags", render)
	player:GetAttributeChangedSignal("PaidRandomRestricted"):Connect(render)
end

return StoreUI
