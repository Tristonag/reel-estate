-- Client entry point.
local Players = game:GetService("Players")
local Client = script.Parent

-- Loading screen while save data loads (can take a few seconds if the previous server is still saving)
local player = Players.LocalPlayer
local loading = Instance.new("ScreenGui")
loading.Name = "Loading"
loading.IgnoreGuiInset = true
loading.DisplayOrder = 100
loading.ResetOnSpawn = false
loading.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.fromRGB(30, 120, 170)
bg.Parent = loading
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new(Color3.fromRGB(80, 200, 240), Color3.fromRGB(20, 80, 140))
grad.Rotation = 90
grad.Parent = bg
local text = Instance.new("TextLabel")
text.BackgroundTransparency = 1
text.AnchorPoint = Vector2.new(0.5, 0.5)
text.Position = UDim2.fromScale(0.5, 0.5)
text.Size = UDim2.new(0, 500, 0, 50)
text.Font = Enum.Font.FredokaOne
text.TextScaled = true
text.TextColor3 = Color3.new(1, 1, 1)
text.Text = "Loading your island..."
local stroke = Instance.new("UIStroke"); stroke.Thickness = 3; stroke.Color = Color3.fromRGB(20, 30, 50); stroke.Parent = text
text.Parent = bg
loading.Parent = player:WaitForChild("PlayerGui")

local dots = 0
local animating = true
task.spawn(function()
	while animating do
		dots = (dots % 3) + 1
		text.Text = "Loading your island" .. string.rep(".", dots)
		task.wait(0.4)
	end
end)

local ClientData = require(Client:WaitForChild("ClientData"))
local data = ClientData.Get()
print(("[Reel Estate] Client data ready: %d Shells, rod tier %d, island stage %d"):format(data.Shells, data.RodTier, data.Island.Stage))

require(Client:WaitForChild("SoundController")).Start()
require(Client:WaitForChild("HUDController")).Start()
require(Client:WaitForChild("RevealController")).Start()
require(Client:WaitForChild("FloaterBob")).Start()
require(Client:WaitForChild("FishingController")).Start()
require(Client:WaitForChild("PlacementController")).Start()
require(Client:WaitForChild("IslandPanel")).Start()
require(Client:WaitForChild("TravelButtons")).Start()
require(Client:WaitForChild("BookUI")).Start()
require(Client:WaitForChild("ShopUI")).Start()
require(Client:WaitForChild("StatusUI")).Start()
require(Client:WaitForChild("ShipwreckUI")).Start()
require(Client:WaitForChild("OddsUI")).Start()
require(Client:WaitForChild("StoreUI")).Start()
require(Client:WaitForChild("SettingsUI")).Start()
require(Client:WaitForChild("IncomeLabels")).Start()
require(Client:WaitForChild("ScaleController")).Start()
require(Client:WaitForChild("Ambience")).Start()
require(Client:WaitForChild("TutorialController")).Start()

-- keep the tutorial banner from covering menus: hide it while a centered panel is open
task.spawn(function()
	local pg = player.PlayerGui
	local hud = pg:WaitForChild("HUD")
	while true do
		task.wait(0.2)
		local tut = pg:FindFirstChild("TutorialUI")
		if not tut then continue end
		local open = false
		for _, c in ipairs(hud:GetChildren()) do
			if c:IsA("Frame") and c.Visible and c.AnchorPoint == Vector2.new(0.5, 0.5) and c.AbsoluteSize.X > 250 then
				open = true
				break
			end
		end
		local want = not open
		if tut:GetAttribute("AutoHidden") and want then
			tut.Enabled = true
			tut:SetAttribute("AutoHidden", nil)
		elseif tut.Enabled and not want then
			tut.Enabled = false
			tut:SetAttribute("AutoHidden", true)
		end
	end
end)

animating = false
game:GetService("TweenService"):Create(bg, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
game:GetService("TweenService"):Create(text, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
game:GetService("TweenService"):Create(stroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
task.delay(0.6, function() loading:Destroy() end)
