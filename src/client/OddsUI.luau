--[[
	OddsUI
	Exact odds popup (Roblox Paid Random Items policy): every outcome with its numeric chance,
	computed by the server for this player's current luck, so it updates when boosts are active.

	OddsUI.Show({ Container = "Chest", Context = "Fish"|"Product", PreviewMult = 2?, PreviewLabel = "With 2x Luck"?,
	              Lock = true? (no container tabs), Title = "..."? })
]]
local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local UIKit = require(script.Parent.UIKit)
local Icons = require(script.Parent.Icons)
local Remotes = game.ReplicatedStorage.Shared.Remotes

local player = Players.LocalPlayer
local OddsUI = {}

local gui: ScreenGui
local panel: Frame
local refs: any = {}
local current: any = {}
local ORDER = { "Crate", "Barrel", "Bottle", "Chest", "GoldenChest", "Relic" }
local SHORT = { Crate = "Crate", Barrel = "Barrel", Bottle = "Bottle", Chest = "Chest", GoldenChest = "Golden", Relic = "Relic" }

local function pct(p: number): string
	local s = string.format("%.4f", p)
	s = s:gsub("0+$", ""):gsub("%.$", "")
	return s .. "%"
end

local function itemsByRarity()
	local by = {}
	for id, item in pairs(Config.Items) do
		by[item.Rarity] = by[item.Rarity] or {}
		table.insert(by[item.Rarity], item.Name)
	end
	for _, list in pairs(by) do table.sort(list) end
	return by
end
local BY_RARITY = itemsByRarity()

local function clear(f)
	for _, c in ipairs(f:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
end

local function cell(parent, text, x, w, color, align)
	local l = UIKit.Label({ Text = text, Size = UDim2.new(w, -6, 1, -4), Position = UDim2.new(x, 3, 0, 2), TextColor3 = color or Color3.new(1, 1, 1),
		TextXAlignment = align or Enum.TextXAlignment.Center })
	l.Parent = parent
	return l
end

local function row(parent, order, h, dark)
	local r = UIKit.Frame({ LayoutOrder = order, Size = UDim2.new(1, -8, 0, h), BackgroundColor3 = dark and Color3.fromRGB(20, 25, 50) or Color3.fromRGB(40, 45, 85),
		BackgroundTransparency = 0.25 })
	UIKit.Corner(r, 8)
	r.Parent = parent
	return r
end

local function render()
	local body = refs.Body
	clear(body)
	local allowed = {}
	for _, id in ipairs(current.Containers or ORDER) do allowed[id] = true end
	for id, b in pairs(refs.Tabs) do
		b.Visible = not current.Lock and allowed[id] == true
		b.Size = UDim2.new(1 / math.max(1, #(current.Containers or ORDER)), -5, 1, 0)
		b.UIGradient.Color = id == current.Container
			and ColorSequence.new(Color3.fromRGB(255, 215, 100), Color3.fromRGB(230, 150, 30))
			or ColorSequence.new(Color3.fromRGB(150, 140, 190), Color3.fromRGB(90, 80, 140))
	end
	refs.Title.Text = current.Title or (Config.Containers[current.Container].Name .. " odds")
	refs.Luck.Text = "Loading exact odds..."

	local ok, r = pcall(function()
		return Remotes.GetOdds:InvokeServer(current.Container, current.Context, current.PreviewMult)
	end)
	if not panel.Visible then return end
	if not ok or not r then refs.Luck.Text = "Couldn't load odds, try again." return end

	local parts = {}
	for _, p in ipairs(r.Parts) do table.insert(parts, ("%s x%.2f"):format(p[1], p[2])) end
	refs.Luck.Text = ("Your luck: x%.2f  (%s)"):format(r.Luck, table.concat(parts, ", "))

	local preview = r.Preview
	local cols = preview and { 0, 0.4, 0.7 } or { 0, 0.55 }
	local widths = preview and { 0.4, 0.3, 0.3 } or { 0.55, 0.45 }
	local n = 0
	local function add(h, dark)
		n += 1
		return row(body, n, h, dark)
	end

	if current.Extra then
		local ex = add(46, true)
		local l = UIKit.Label({ Text = current.Extra, Size = UDim2.new(1, -12, 1, -6), Position = UDim2.new(0, 6, 0, 3), TextColor3 = Color3.fromRGB(150, 255, 220) })
		l.Parent = ex
	end

	-- rarity table
	local head = add(26, true)
	cell(head, "Rarity", cols[1], widths[1], Color3.fromRGB(255, 225, 120))
	cell(head, "Chance now", cols[2], widths[2], Color3.fromRGB(255, 225, 120))
	if preview then cell(head, current.PreviewLabel or "Boosted", cols[3], widths[3], Color3.fromRGB(150, 255, 170)) end
	for _, rarity in ipairs(Config.RarityOrder) do
		local p = r.Rarity[rarity]
		if p then
			local rr = add(26)
			cell(rr, rarity, cols[1], widths[1], Config.Rarities[rarity].Color)
			cell(rr, pct(p), cols[2], widths[2])
			if preview then cell(rr, pct(preview.Rarity[rarity] or 0), cols[3], widths[3], Color3.fromRGB(150, 255, 170)) end
		end
	end

	-- variants
	local vh = add(26, true)
	cell(vh, "Special version (any item)", cols[1], widths[1], Color3.fromRGB(255, 225, 120))
	cell(vh, "Chance now", cols[2], widths[2], Color3.fromRGB(255, 225, 120))
	if preview then cell(vh, current.PreviewLabel or "Boosted", cols[3], widths[3], Color3.fromRGB(150, 255, 170)) end
	local vorder = { "Normal" }
	for i = #Config.Variants, 1, -1 do table.insert(vorder, Config.Variants[i].Id) end
	for _, v in ipairs(vorder) do
		local vr = add(26)
		cell(vr, v == "Normal" and "Normal" or v, cols[1], widths[1])
		cell(vr, pct(r.Variants[v] or 0), cols[2], widths[2])
		if preview then cell(vr, pct(preview.Variants[v] or 0), cols[3], widths[3], Color3.fromRGB(150, 255, 170)) end
	end

	-- every single item
	local ih = add(26, true)
	cell(ih, "Every item you can get (chance now)", 0, 1, Color3.fromRGB(255, 225, 120))
	for _, rarity in ipairs(Config.RarityOrder) do
		local p = r.Rarity[rarity]
		local list = BY_RARITY[rarity]
		if p and list then
			local each = p / #list
			for _, name in ipairs(list) do
				local ir = add(24)
				cell(ir, name, 0, 0.5, Color3.new(1, 1, 1), Enum.TextXAlignment.Left)
				cell(ir, rarity, 0.5, 0.25, Config.Rarities[rarity].Color)
				cell(ir, pct(each), 0.75, 0.25)
			end
		end
	end
end

function OddsUI.Show(opts)
	opts = opts or {}
	current = {
		Container = opts.Container or "Crate",
		Context = opts.Context or "Fish",
		PreviewMult = opts.PreviewMult,
		PreviewLabel = opts.PreviewLabel,
		Lock = opts.Lock,
		Title = opts.Title,
		Containers = opts.Containers,
		Extra = opts.Extra,
	}
	panel.Visible = true
	UIKit.Pop(panel)
	task.spawn(render)
end

function OddsUI.Start()
	gui = Instance.new("ScreenGui")
	gui.Name = "OddsUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 30
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	panel = UIKit.Frame({ Name = "Odds", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.new(0, 560, 0, 470), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false })
	UIKit.Corner(panel, 20)
	UIKit.Stroke(panel, 5, Color3.fromRGB(20, 10, 40), true)
	UIKit.Gradient(panel, Color3.fromRGB(70, 80, 150), Color3.fromRGB(30, 30, 70))
	panel.Parent = gui

	local header = UIKit.Button({ Name = "Header", Text = "ODDS", Size = UDim2.new(0, 200, 0, 50), Position = UDim2.new(0.5, -100, 0, -26),
		Top = Color3.fromRGB(120, 235, 110), Bottom = Color3.fromRGB(30, 140, 60) })
	header.Active = false
	header.Parent = panel
	Icons.Image(header, "Clover", { Size = UDim2.new(0, 56, 0, 56), Position = UDim2.new(0, -32, 0.5, -29), ZIndex = 3 })
	local close = UIKit.Button({ Name = "Close", Text = "X", Size = UDim2.new(0, 46, 0, 46), Position = UDim2.new(1, -30, 0, -16),
		Top = Color3.fromRGB(255, 110, 110), Bottom = Color3.fromRGB(210, 40, 40) }, function() panel.Visible = false end)
	close.Parent = panel

	refs.Title = UIKit.Label({ Size = UDim2.new(1, -40, 0, 30), Position = UDim2.new(0, 20, 0, 30), StrokeThickness = 3 })
	refs.Title.Parent = panel

	local tabs = UIKit.Frame({ Name = "Tabs", BackgroundTransparency = 1, Size = UDim2.new(1, -32, 0, 34), Position = UDim2.new(0, 16, 0, 64) })
	local tl = Instance.new("UIListLayout"); tl.FillDirection = Enum.FillDirection.Horizontal; tl.Padding = UDim.new(0, 6)
	tl.HorizontalAlignment = Enum.HorizontalAlignment.Center; tl.SortOrder = Enum.SortOrder.LayoutOrder; tl.Parent = tabs
	tabs.Parent = panel
	refs.Tabs = {}
	for i, id in ipairs(ORDER) do
		local b = UIKit.Button({ Name = id, Text = SHORT[id], Size = UDim2.new(1 / #ORDER, -5, 1, 0) }, function()
			current.Container = id
			current.Title = nil
			task.spawn(render)
		end)
		b.LayoutOrder = i
		b.Parent = tabs
		refs.Tabs[id] = b
	end

	refs.Luck = UIKit.Label({ Size = UDim2.new(1, -32, 0, 20), Position = UDim2.new(0, 16, 0, 104), TextColor3 = Color3.fromRGB(210, 220, 255) })
	refs.Luck.Parent = panel

	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.new(0, 16, 0, 130)
	body.Size = UDim2.new(1, -24, 1, -166)
	body.ScrollBarThickness = 6
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.Parent = panel
	local bl = Instance.new("UIListLayout"); bl.Padding = UDim.new(0, 4); bl.SortOrder = Enum.SortOrder.LayoutOrder; bl.Parent = body
	refs.Body = body

	local note = UIKit.Label({ Text = "Exact odds for you right now (boosts included). Rounded to 4 decimals, all add up to 100%.",
		Size = UDim2.new(1, -32, 0, 16), Position = UDim2.new(0, 16, 1, -28), TextColor3 = Color3.fromRGB(190, 200, 235) })
	note.Parent = panel
end

return OddsUI
