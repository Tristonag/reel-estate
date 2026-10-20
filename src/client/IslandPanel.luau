--[[
	IslandPanel
	"ISLAND" side button -> your island stage, slots, score, the next expansion
	(price + Island Score requirement) and the Rebirth card with a confirm step.
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Format = require(game.ReplicatedStorage.Shared.Format)
local ClientData = require(script.Parent.ClientData)
local UIKit = require(script.Parent.UIKit)
local Icons = require(script.Parent.Icons)
local HUDController = require(script.Parent.HUDController)
local Remotes = game.ReplicatedStorage.Shared.Remotes

local player = Players.LocalPlayer
local IslandPanel = {}
local R = Config.Rebirth

local panel: Frame
local refs: any = {}

local GREEN = ColorSequence.new(Color3.fromRGB(120, 235, 130), Color3.fromRGB(45, 170, 70))
local GRAY = ColorSequence.new(Color3.fromRGB(170, 170, 185), Color3.fromRGB(110, 110, 125))
local PURPLE = ColorSequence.new(Color3.fromRGB(215, 140, 255), Color3.fromRGB(140, 60, 220))

local function count(t)
	local n = 0
	for _ in pairs(t) do n += 1 end
	return n
end

local function rebirthCost(n) return R.BaseCost * (n + 1) end

local function refresh()
	if not panel then return end
	local data = ClientData.Get()
	if not data or not data.Island then return end
	local stageIndex = data.Island.Stage
	local stage = Config.IslandStages[stageIndex]
	local nextStage = Config.IslandStages[stageIndex + 1]
	local score = player:GetAttribute("IslandScore") or 0
	refs.Current.Text = stage.Name .. ("  (%d/%d)"):format(stageIndex, #Config.IslandStages)
	refs.Slots.Text = ("Slots used: %d / %d"):format(count(data.Island.Placed), stage.Slots)
	refs.Score.Text = "Island Score: " .. Format.Comma(score)
	if nextStage then
		local need = nextStage.ScoreRequired or 0
		local scoreOk = score >= need
		local afford = data.Shells >= nextStage.Price
		refs.Next.Text = ("Next: %s  (%d slots)"):format(nextStage.Name, nextStage.Slots)
		refs.Bar.Visible = need > 0
		refs.Fill.Size = UDim2.fromScale(math.clamp(need > 0 and score / need or 1, 0, 1), 1)
		refs.Fill.BackgroundColor3 = scoreOk and Color3.fromRGB(110, 230, 120) or Color3.fromRGB(255, 200, 70)
		refs.BarText.Text = ("Island Score %s / %s"):format(Format.Comma(score), Format.Comma(need))
		refs.ExpandLabel.Text = "EXPAND  " .. Format.Short(nextStage.Price)
		refs.Expand.Visible = true
		refs.Expand.UIGradient.Color = (afford and scoreOk) and GREEN or GRAY
		if not scoreOk then
			refs.Need.Text = "Place better items to raise your Island Score!"
		elseif not afford then
			refs.Need.Text = ("Need %s more Shells"):format(Format.Comma(nextStage.Price - data.Shells))
		else
			refs.Need.Text = ""
		end
	else
		refs.Next.Text = "Max size reached!"
		refs.Bar.Visible = false
		refs.Expand.Visible = false
		refs.Need.Text = ""
	end

	-- rebirth card
	local rb = data.Rebirths or 0
	refs.RbCount.Text = ("Rebirths: %d   Shells x%.1f   Luck x%.1f"):format(rb, 1 + R.ShellBonus * rb, 1 + R.LuckBonus * rb)
	local cost = rebirthCost(rb)
	local stageOk = stageIndex >= R.StageRequired
	local ready = stageOk and data.Shells >= cost
	refs.RbNeed.Text = ("Needs %s + %s Shells"):format(Config.IslandStages[R.StageRequired].Name, Format.Short(cost))
	refs.RbGain.Text = ("Next: Shells x%.1f  Luck x%.1f  (forever!)"):format(1 + R.ShellBonus * (rb + 1), 1 + R.LuckBonus * (rb + 1))
	refs.Rebirth.UIGradient.Color = ready and PURPLE or GRAY
	refs.RebirthLabel.Text = ready and "REBIRTH!" or (stageOk and "NEED SHELLS" or "LOCKED")
	refs.Ready = ready
end

local function showConfirm(on)
	refs.Confirm.Visible = on
	if on then
		local rb = (ClientData.Get().Rebirths or 0)
		refs.ConfirmText.Text = ("Rebirth #%d?\n\nYou LOSE: Shells, rods, bait, backpack and your island.\nYou KEEP: Collection Book and passes.\nYou GET: Shells x%.1f and Luck x%.1f forever!")
			:format(rb + 1, 1 + R.ShellBonus * (rb + 1), 1 + R.LuckBonus * (rb + 1))
		UIKit.Pop(refs.ConfirmBox)
	end
end

local function build(gui: ScreenGui)
	panel = UIKit.Frame({ Name = "IslandPanel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 420, 0, 480), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false })
	UIKit.Corner(panel, 20)
	UIKit.Stroke(panel, 5, Color3.fromRGB(20, 10, 40), true)
	UIKit.Gradient(panel, Color3.fromRGB(70, 160, 110), Color3.fromRGB(30, 90, 70))
	panel.Parent = gui

	local header = UIKit.Button({ Name = "Header", Text = "MY ISLAND", Size = UDim2.new(0, 220, 0, 50), Position = UDim2.new(0.5, -110, 0, -26),
		Top = Color3.fromRGB(120, 220, 255), Bottom = Color3.fromRGB(40, 140, 220) })
	header.Active = false
	header.Parent = panel
	Icons.Viewport(header, "Palm", { Size = UDim2.new(0, 60, 0, 60), Position = UDim2.new(0, -36, 0.5, -31), ZIndex = 3 })
	refs.Header = header

	local close = UIKit.Button({ Name = "Close", Text = "X", Size = UDim2.new(0, 46, 0, 46), Position = UDim2.new(1, -30, 0, -16),
		Top = Color3.fromRGB(255, 110, 110), Bottom = Color3.fromRGB(210, 40, 40) }, function() panel.Visible = false end)
	close.Parent = panel

	refs.Current = UIKit.Label({ Size = UDim2.new(1, -40, 0, 38), Position = UDim2.new(0, 20, 0, 34), StrokeThickness = 3 })
	refs.Slots = UIKit.Label({ Size = UDim2.new(1, -40, 0, 22), Position = UDim2.new(0, 20, 0, 76) })
	refs.Score = UIKit.Label({ Size = UDim2.new(1, -40, 0, 22), Position = UDim2.new(0, 20, 0, 100), TextColor3 = Color3.fromRGB(255, 225, 100) })
	refs.Next = UIKit.Label({ Size = UDim2.new(1, -40, 0, 22), Position = UDim2.new(0, 20, 0, 134), TextColor3 = Color3.fromRGB(220, 255, 230) })
	refs.Need = UIKit.Label({ Size = UDim2.new(1, -40, 0, 18), Position = UDim2.new(0, 20, 0, 262), TextColor3 = Color3.fromRGB(255, 205, 205) })
	for _, k in ipairs({ "Current", "Slots", "Score", "Next", "Need" }) do refs[k].Parent = panel end

	-- score requirement bar
	local bar = UIKit.Frame({ Name = "ScoreBar", Size = UDim2.new(1, -60, 0, 26), Position = UDim2.new(0, 30, 0, 164),
		BackgroundColor3 = Color3.fromRGB(20, 40, 35) })
	UIKit.Corner(bar, 13); UIKit.Stroke(bar, 3, UIKit.Dark, true)
	local fill = UIKit.Frame({ Name = "Fill", Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = Color3.fromRGB(255, 200, 70) })
	UIKit.Corner(fill, 13); fill.Parent = bar
	local barText = UIKit.Label({ Size = UDim2.new(1, -16, 0.8, 0), Position = UDim2.new(0, 8, 0.1, 0), ZIndex = 2 })
	barText.Parent = bar
	bar.Parent = panel
	refs.Bar, refs.Fill, refs.BarText = bar, fill, barText

	local expand, expandLabel = UIKit.Button({ Name = "Expand", Text = "EXPAND", Size = UDim2.new(0, 260, 0, 52), Position = UDim2.new(0.5, -130, 0, 202),
		Top = Color3.fromRGB(120, 235, 130), Bottom = Color3.fromRGB(45, 170, 70) }, function()
		local ok, r = pcall(function() return Remotes.ExpandIsland:InvokeServer() end)
		refresh()
		if ok and r and r.Ok then
			UIKit.Pop(panel)
		elseif ok and r and r.Reason == "NotEnough" then
			refs.Need.Text = "Not enough Shells yet!"
		elseif ok and r and r.Reason == "Score" then
			refs.Need.Text = "Your Island Score is too low!"
		end
	end)
	expand.Parent = panel
	refs.Expand, refs.ExpandLabel = expand, expandLabel

	-- rebirth card
	local card = UIKit.Frame({ Name = "RebirthCard", Size = UDim2.new(1, -36, 0, 172), Position = UDim2.new(0, 18, 1, -190),
		BackgroundColor3 = Color3.new(1, 1, 1) })
	UIKit.Corner(card, 16); UIKit.Stroke(card, 4, UIKit.Dark, true)
	UIKit.Gradient(card, Color3.fromRGB(120, 70, 190), Color3.fromRGB(60, 30, 110))
	card.Parent = panel
	local title = UIKit.Label({ Text = "REBIRTH", Size = UDim2.new(1, -20, 0, 32), Position = UDim2.new(0, 10, 0, 8), StrokeThickness = 3,
		TextColor3 = Color3.fromRGB(255, 225, 120) })
	title.Parent = card
	Icons.Image(card, "Rebirth", { Size = UDim2.new(0, 54, 0, 54), Position = UDim2.new(0, 10, 0, 2), ZIndex = 2 })
	Icons.Image(card, "Rebirth", { Size = UDim2.new(0, 54, 0, 54), Position = UDim2.new(1, -64, 0, 2), ZIndex = 2 })
	refs.RbCount = UIKit.Label({ Size = UDim2.new(1, -20, 0, 20), Position = UDim2.new(0, 10, 0, 42) })
	refs.RbGain = UIKit.Label({ Size = UDim2.new(1, -20, 0, 18), Position = UDim2.new(0, 10, 0, 64), TextColor3 = Color3.fromRGB(190, 255, 200) })
	refs.RbNeed = UIKit.Label({ Size = UDim2.new(1, -20, 0, 18), Position = UDim2.new(0, 10, 0, 84), TextColor3 = Color3.fromRGB(230, 210, 255) })
	for _, k in ipairs({ "RbCount", "RbGain", "RbNeed" }) do refs[k].Parent = card end
	local rbBtn, rbLabel = UIKit.Button({ Name = "Rebirth", Text = "REBIRTH", Size = UDim2.new(0, 220, 0, 50), Position = UDim2.new(0.5, -110, 1, -62),
		Top = Color3.fromRGB(215, 140, 255), Bottom = Color3.fromRGB(140, 60, 220) }, function()
		if refs.Ready then showConfirm(true) end
	end)
	rbBtn.Parent = card
	refs.Rebirth, refs.RebirthLabel = rbBtn, rbLabel

	-- confirm overlay
	local shade = UIKit.Frame({ Name = "Confirm", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35, Visible = false, ZIndex = 10, Active = true })
	UIKit.Corner(shade, 20)
	shade.Parent = panel
	local box = UIKit.Frame({ Name = "Box", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 360, 0, 270), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 11 })
	UIKit.Corner(box, 18); UIKit.Stroke(box, 4, UIKit.Dark, true)
	UIKit.Gradient(box, Color3.fromRGB(130, 80, 200), Color3.fromRGB(60, 30, 110))
	box.Parent = shade
	local text = UIKit.Label({ Size = UDim2.new(1, -30, 0, 170), Position = UDim2.new(0, 15, 0, 14), TextScaled = true, ZIndex = 12 })
	text.Parent = box
	local yes = UIKit.Button({ Name = "Yes", Text = "REBIRTH", Size = UDim2.new(0, 150, 0, 50), Position = UDim2.new(0.5, 8, 1, -64),
		Top = Color3.fromRGB(120, 235, 130), Bottom = Color3.fromRGB(45, 170, 70) }, function()
		showConfirm(false)
		local ok, r = pcall(function() return Remotes.Rebirth:InvokeServer() end)
		if ok and r and r.Ok then
			UIKit.Pop(panel)
			local sc = require(script.Parent.SoundController)
			pcall(sc.Play, "Fanfare")
		end
		refresh()
	end)
	yes.Parent = box
	local no = UIKit.Button({ Name = "No", Text = "CANCEL", Size = UDim2.new(0, 150, 0, 50), Position = UDim2.new(0.5, -158, 1, -64),
		Top = Color3.fromRGB(255, 110, 110), Bottom = Color3.fromRGB(210, 40, 40) }, function() showConfirm(false) end)
	no.Parent = box
	for _, d in ipairs(box:GetDescendants()) do
		if d:IsA("GuiObject") then d.ZIndex = math.max(d.ZIndex, 12) end
	end
	refs.Confirm, refs.ConfirmBox, refs.ConfirmText = shade, box, text
end

function IslandPanel.Start()
	local gui = player.PlayerGui:WaitForChild("HUD")
	build(gui)
	HUDController.AddSideButton("Island", "ISLAND", Color3.fromRGB(120, 220, 255), Color3.fromRGB(40, 140, 220), function()
		panel.Visible = not panel.Visible
		refs.Confirm.Visible = false
		if panel.Visible then
			UIKit.Pop(panel)
			refresh()
		end
	end)
	ClientData.OnChanged("Island", refresh)
	ClientData.OnChanged("Shells", refresh)
	ClientData.OnChanged("Rebirths", refresh)
	player:GetAttributeChangedSignal("IslandScore"):Connect(refresh)
end

return IslandPanel
