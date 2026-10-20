--[[
	TutorialController
	First-time guide, shown once (saved as Flags.TutorialDone):
		1 equip the rod        2 cast at a crate      3 reel it in
		4 open the bag         5 place it on your island
		6 your island earns Shells, visit the shops
	A banner explains each step and a bouncing arrow + glow points at the button to press.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ClientData = require(script.Parent.ClientData)
local UIKit = require(script.Parent.UIKit)
local Remotes = game.ReplicatedStorage.Shared.Remotes

local player = Players.LocalPlayer
local TutorialController = {}

local gui: ScreenGui
local banner: Frame
local stepLabel: TextLabel
local textLabel: TextLabel
local arrow: Frame
local target: GuiObject? = nil
local glow: UIStroke? = nil
local finished = false

local function count(t)
	local n = 0
	for _ in pairs(t) do n += 1 end
	return n
end

local function setTarget(obj: GuiObject?)
	if glow then glow:Destroy(); glow = nil end
	target = obj
	if obj then
		glow = Instance.new("UIStroke")
		glow.Name = "TutorialGlow"
		glow.Thickness = 5
		glow.Color = Color3.fromRGB(255, 240, 90)
		glow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		glow.Parent = obj
	end
	arrow.Visible = obj ~= nil
end

local function show(step: number, total: number, text: string, obj: GuiObject?)
	stepLabel.Text = ("STEP %d / %d"):format(step, total)
	textLabel.Text = text
	banner.Visible = true
	UIKit.Pop(banner)
	setTarget(obj)
end

local function finish()
	if finished then return end
	finished = true
	setTarget(nil)
	TweenService:Create(banner, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
	task.delay(0.1, function() gui:Destroy() end)
	Remotes.TutorialDone:FireServer()
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "TutorialUI"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Parent = player.PlayerGui

	banner = UIKit.Frame({ Name = "Banner", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 130),
		Size = UDim2.new(0, 520, 0, 78), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false })
	UIKit.Corner(banner, 18)
	UIKit.Stroke(banner, 4, UIKit.Dark, true)
	UIKit.Gradient(banner, Color3.fromRGB(255, 205, 90), Color3.fromRGB(235, 130, 35))
	banner.Parent = gui
	stepLabel = UIKit.Label({ Size = UDim2.new(0, 120, 0, 18), Position = UDim2.new(0, 14, 0, 6), TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 250, 220) })
	stepLabel.Parent = banner
	textLabel = UIKit.Label({ Size = UDim2.new(1, -110, 0, 44), Position = UDim2.new(0, 14, 0, 26), TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true, StrokeThickness = 2.5 })
	textLabel.Parent = banner
	local skip = UIKit.Button({ Name = "Skip", Text = "SKIP", Size = UDim2.new(0, 76, 0, 36), Position = UDim2.new(1, -88, 0.5, -18),
		Top = Color3.fromRGB(200, 200, 215), Bottom = Color3.fromRGB(130, 130, 150) }, finish)
	skip.Parent = banner

	-- arrow: a diamond tip on a stem, bouncing above the target
	arrow = UIKit.Frame({ Name = "Arrow", Size = UDim2.new(0, 40, 0, 56), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 5 })
	local stem = UIKit.Frame({ Size = UDim2.new(0, 16, 0, 30), Position = UDim2.new(0.5, -8, 0, 0), BackgroundColor3 = Color3.fromRGB(255, 240, 90), ZIndex = 5 })
	UIKit.Corner(stem, 6); UIKit.Stroke(stem, 3, UIKit.Dark, true)
	stem.Parent = arrow
	local tip = UIKit.Frame({ Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(0.5, -15, 0, 20), Rotation = 45, BackgroundColor3 = Color3.fromRGB(255, 240, 90), ZIndex = 5 })
	UIKit.Corner(tip, 4); UIKit.Stroke(tip, 3, UIKit.Dark, true)
	tip.Parent = arrow
	arrow.Parent = gui

	RunService.RenderStepped:Connect(function()
		if not target or not target.Parent or not arrow.Parent then return end
		local pos, size = target.AbsolutePosition, target.AbsoluteSize
		local bounce = math.abs(math.sin(os.clock() * 4)) * 10
		arrow.Position = UDim2.fromOffset(pos.X + size.X / 2, pos.Y - 6 - bounce + game:GetService("GuiService"):GetGuiInset().Y)
		if glow then glow.Transparency = 0.2 + math.abs(math.sin(os.clock() * 3)) * 0.5 end
	end)
end

local function waitFor(check: () -> boolean)
	while not finished and not check() do task.wait(0.2) end
	return not finished
end

function TutorialController.Start()
	local data = ClientData.Get()
	if data.Flags.TutorialDone then return end
	build()
	local pg = player.PlayerGui
	local bar = pg:WaitForChild("FishingUI"):WaitForChild("ActionBar")
	local hud = pg:WaitForChild("HUD")
	local TOTAL = 6

	task.spawn(function()
		-- 1 equip
		show(1, TOTAL, "Welcome to Reel Estate! Tap EQUIP ROD to grab your fishing rod.", bar:WaitForChild("Center"))
		if not waitFor(function() return player.Character and player.Character:FindFirstChild("Rod") ~= nil end) then return end

		-- 2 cast
		show(2, TOTAL, "Aim at a floating crate, HOLD to charge and RELEASE to cast. The ring turns green on a crate!", nil)
		if not waitFor(function() return pg.FishingUI.Reel.Visible end) then return end

		-- 3 reel
		local catches = ClientData.Get().Stats.Catches
		show(3, TOTAL, "Hold to push the white marker right, let go to drop it. Keep it in the rainbow zone!", nil)
		if not waitFor(function() return ClientData.Get().Stats.Catches > catches end) then return end
		waitFor(function() return not pg.RevealUI.Enabled end)

		-- 4 bag
		show(4, TOTAL, "Nice catch! Open your BAG to see it.", hud.Side:WaitForChild("Bag"))
		if not waitFor(function() return hud.Backpack.Visible end) then return end

		-- 5 place
		local placed = count(ClientData.Get().Island.Placed)
		show(5, TOTAL, "Tap your item, press PLACE, then click a tile on your island!", nil)
		if not waitFor(function() return count(ClientData.Get().Island.Placed) > placed end) then return end

		-- 6 shops
		show(6, TOTAL, "Your island now earns Shells, even while you're away! Visit the SHOPS for better rods.", hud.Side:WaitForChild("Hub"))
		local t0 = os.clock()
		waitFor(function() return os.clock() - t0 > 9 end)
		finish()
	end)
end

return TutorialController
