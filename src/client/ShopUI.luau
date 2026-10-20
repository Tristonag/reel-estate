--[[
	ShopUI
	Rod Shop and Bait Shop panels. Opened by the hub stall prompts (attribute Shop = "Rods" | "Bait").
	The server validates every purchase; this only displays and asks.
]]
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Format = require(game.ReplicatedStorage.Shared.Format)
local ClientData = require(script.Parent.ClientData)
local UIKit = require(script.Parent.UIKit)
local Icons = require(script.Parent.Icons)
local HUDController = require(script.Parent.HUDController)
local StoreUI = require(script.Parent.StoreUI)
local Remotes = game.ReplicatedStorage.Shared.Remotes

local player = Players.LocalPlayer
local ShopUI = {}

local gui: ScreenGui
local panel: Frame
local header: TextLabel
local greeting: TextLabel
local list: ScrollingFrame
local current = nil -- "Rods" | "Bait"

local GREEN = { Color3.fromRGB(120, 235, 130), Color3.fromRGB(45, 170, 70) }
local GREY = { Color3.fromRGB(170, 170, 185), Color3.fromRGB(110, 110, 125) }
local BLUE = { Color3.fromRGB(120, 200, 255), Color3.fromRGB(50, 120, 230) }
local GOLD = { Color3.fromRGB(255, 215, 100), Color3.fromRGB(230, 150, 30) }

local function setButton(btn, label, text, colors)
	label.Text = text
	btn.UIGradient.Color = ColorSequence.new(colors[1], colors[2])
end

local function clear()
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
end

local function row(order: number, title: string, sub: string, color: Color3, iconName: string?, badge: string?)
	local r = UIKit.Frame({ Name = "Row" .. order, LayoutOrder = order, Size = UDim2.new(1, -12, 0, 86),
		BackgroundColor3 = Color3.new(1, 1, 1) })
	UIKit.Corner(r, 16)
	UIKit.Stroke(r, 3, UIKit.Dark, true)
	UIKit.Gradient(r, Color3.fromRGB(60, 42, 105), Color3.fromRGB(32, 20, 60))
	-- icon tile tinted with the item's color
	local tile = UIKit.Frame({ Size = UDim2.new(0, 70, 0, 70), Position = UDim2.new(0, 8, 0.5, -35), BackgroundColor3 = Color3.new(1, 1, 1) })
	UIKit.Corner(tile, 14)
	UIKit.Stroke(tile, 2.5, UIKit.Dark, true)
	UIKit.Gradient(tile, color:Lerp(Color3.new(1, 1, 1), 0.35), color:Lerp(Color3.new(0, 0, 0), 0.35))
	tile.Parent = r
	if iconName then Icons.Viewport(tile, iconName, { Size = UDim2.new(1.1, 0, 1.1, 0), Position = UDim2.new(-0.05, 0, -0.05, 0), Zoom = 0.7, ZIndex = 2 }) end
	local t = UIKit.Label({ Text = title, Size = UDim2.new(0.5, 0, 0, 30), Position = UDim2.new(0, 90, 0, 12), TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 2.5 })
	t.Parent = r
	if badge then
		local b = UIKit.Frame({ Size = UDim2.new(0, 70, 0, 20), Position = UDim2.new(0, 90, 0, -8), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3 })
		UIKit.Corner(b, 10)
		UIKit.Stroke(b, 2, UIKit.Dark, true)
		UIKit.Gradient(b, color:Lerp(Color3.new(1, 1, 1), 0.2), color:Lerp(Color3.new(0, 0, 0), 0.25))
		local bl = UIKit.Label({ Text = badge, Size = UDim2.new(0.9, 0, 0.8, 0), Position = UDim2.new(0.05, 0, 0.1, 0), ZIndex = 4, StrokeThickness = 1.5 })
		bl.Parent = b
		b.Parent = r
	end
	local s = UIKit.Label({ Text = sub, Size = UDim2.new(0.55, 0, 0, 20), Position = UDim2.new(0, 90, 0, 48), TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(200, 200, 225) })
	s.Parent = r
	local btn, lbl = UIKit.Button({ Name = "Action", Text = "", Size = UDim2.new(0, 150, 0, 50), Position = UDim2.new(1, -164, 0.5, -25) })
	btn.Parent = r
	r.Parent = list
	return r, btn, lbl
end

local function renderRods()
	clear()
	header.Text = "ROD SHOP"
	local data = ClientData.Get()
	for tier, rod in ipairs(Config.Rods) do
		local sub = ("Reach %d  |  Reel x%.2f  |  Luck x%.2f"):format(rod.MaxDistance, rod.ReelPower, rod.Luck)
		local _, btn, lbl = row(tier, rod.Name, sub, Color3.fromRGB(rod.Color[1], rod.Color[2], rod.Color[3]), "Rod:" .. tier, "TIER " .. tier)
		if tier == data.EquippedRod then
			setButton(btn, lbl, "EQUIPPED", BLUE)
		elseif tier <= data.RodTier then
			setButton(btn, lbl, "EQUIP", GREEN)
			btn.Activated:Connect(function()
				pcall(function() Remotes.EquipRod:InvokeServer(tier) end)
			end)
		elseif tier == data.RodTier + 1 then
			local afford = data.Shells >= rod.Price
			setButton(btn, lbl, Format.Short(rod.Price), afford and GOLD or GREY)
			btn.Activated:Connect(function()
				local ok, r = pcall(function() return Remotes.BuyRod:InvokeServer(tier) end)
				if ok and r and not r.Ok and r.Reason == "NotEnough" then setButton(btn, lbl, "NEED MORE", GREY) end
			end)
		else
			setButton(btn, lbl, "LOCKED", GREY)
		end
	end
end

local function renderBait()
	clear()
	header.Text = "BAIT SHOP"
	local data = ClientData.Get()
	local order = 0
	-- sorted by price
	local ids = {}
	for id in pairs(Config.Baits) do table.insert(ids, id) end
	table.sort(ids, function(a, b) return Config.Baits[a].Price < Config.Baits[b].Price end)
	for _, id in ipairs(ids) do
		local bait = Config.Baits[id]
		order += 1
		local owned = data.Baits[id] or 0
		local sub = ("%d uses per pack"):format(bait.Uses) -- luck is on the badge
		local title = owned > 0 and ("%s  (x%d)"):format(bait.Name, owned) or bait.Name
		local BAIT_ICONS = { Worm = "Worm", Shrimp = "Shrimp", Glowbug = "Glowbug" }
		local BAIT_COLORS = { Worm = Color3.fromRGB(255, 150, 170), Shrimp = Color3.fromRGB(255, 160, 90), Glowbug = Color3.fromRGB(170, 240, 90) }
		local r, btn, lbl = row(order, title, sub, BAIT_COLORS[id] or Color3.fromRGB(255, 170, 90), BAIT_ICONS[id], "LUCK x" .. bait.Luck)
		setButton(btn, lbl, "BUY " .. Format.Short(bait.Price), data.Shells >= bait.Price and GOLD or GREY)
		btn.Activated:Connect(function()
			local ok, res = pcall(function() return Remotes.BuyBait:InvokeServer(id) end)
			if ok and res and not res.Ok and res.Reason == "NotEnough" then setButton(btn, lbl, "NEED MORE", GREY) end
		end)
		if owned > 0 then
			local equipped = data.EquippedBait == id
			local eb, el = UIKit.Button({ Name = "Equip", Text = equipped and "USING" or "USE", Size = UDim2.new(0, 90, 0, 40),
				Position = UDim2.new(1, -262, 0.5, -20), Top = equipped and BLUE[1] or GREEN[1], Bottom = equipped and BLUE[2] or GREEN[2] })
			eb.Parent = r
			eb.Activated:Connect(function()
				pcall(function() Remotes.EquipBait:InvokeServer(equipped and "" or id) end)
			end)
		end
	end
end

local function render()
	if not panel.Visible then return end
	if current == "Rods" then renderRods() elseif current == "Bait" then renderBait() end
end

function ShopUI.Open(which: string)
	current = which
	panel.Visible = true
	UIKit.Pop(panel)
	render()
end

function ShopUI.Close()
	panel.Visible = false
	current = nil
end

function ShopUI.Start()
	gui = player.PlayerGui:WaitForChild("HUD")
	panel = UIKit.Frame({ Name = "Shop", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.new(0, 600, 0, 430), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false })
	UIKit.Corner(panel, 20)
	UIKit.Stroke(panel, 5, Color3.fromRGB(20, 10, 40), true)
	UIKit.Gradient(panel, Color3.fromRGB(80, 55, 140), Color3.fromRGB(40, 25, 75))
	panel.Parent = gui
	local h, hl = UIKit.Button({ Name = "Header", Text = "SHOP", Size = UDim2.new(0, 240, 0, 50), Position = UDim2.new(0.5, -120, 0, -26),
		Top = GOLD[1], Bottom = GOLD[2] })
	h.Active = false
	h.Parent = panel
	header = hl
	Icons.Viewport(h, "Stand", { Size = UDim2.new(0, 60, 0, 60), Position = UDim2.new(0, -36, 0.5, -31), ZIndex = 3 })

	local close = UIKit.Button({ Name = "Close", Text = "X", Size = UDim2.new(0, 46, 0, 46), Position = UDim2.new(1, -30, 0, -16),
		Top = Color3.fromRGB(255, 110, 110), Bottom = Color3.fromRGB(210, 40, 40) }, ShopUI.Close)
	close.Parent = panel

	list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.new(0, 16, 0, 40)
	list.Size = UDim2.new(1, -24, 1, -56)
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0, 14); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Parent = list
	local listPad = Instance.new("UIPadding"); listPad.PaddingTop = UDim.new(0, 12); listPad.PaddingBottom = UDim.new(0, 6); listPad.Parent = list

	greeting = UIKit.Label({ Name = "Greeting", Text = "", Size = UDim2.new(1, -40, 0, 20), Position = UDim2.new(0, 20, 0, 30),
		TextColor3 = Color3.fromRGB(255, 225, 150) })
	greeting.Parent = panel
	list.Position = UDim2.new(0, 16, 0, 58)
	list.Size = UDim2.new(1, -24, 1, -72)

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local shop = prompt:GetAttribute("Shop")
		if not shop then return end
		if shop == "Sell" then
			HUDController.ToggleBackpack(true)
			return
		elseif shop == "Store" then
			StoreUI.Open()
			return
		end
		-- the keeper greets you with one of their lines
		local npcs = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("NPCs")
		local keeper
		if npcs then
			for _, m in ipairs(npcs:GetChildren()) do
				if m:GetAttribute("Shop") == shop then keeper = m end
			end
		end
		if keeper then
			local lines = string.split(keeper:GetAttribute("Lines") or "", "|")
			greeting.Text = keeper.Name .. ": \"" .. (lines[math.random(1, #lines)] or "") .. "\""
		else
			greeting.Text = ""
		end
		ShopUI.Open(shop)
	end)
	-- close when walking away from the stall
	task.spawn(function()
		while true do
			task.wait(0.5)
			if panel.Visible then
				local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				local shops = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Shops")
				local stall = shops and current and shops:FindFirstChild(current)
				if hrp and stall and (hrp.Position - stall:GetPivot().Position).Magnitude > 22 then ShopUI.Close() end
			end
		end
	end)

	for _, key in ipairs({ "Shells", "RodTier", "EquippedRod", "Baits", "EquippedBait" }) do
		ClientData.Changed.Event:Connect(function(k) if k == key then render() end end)
	end
end

return ShopUI
