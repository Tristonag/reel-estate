--[[
	SettingsUI
	Gear button in the side menu -> panel with Music and Sound Effects switches.
	Choices are saved with the player's data (Remotes.SaveSettings) and applied on join.
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ClientData = require(script.Parent.ClientData)
local UIKit = require(script.Parent.UIKit)
local Icons = require(script.Parent.Icons)
local HUDController = require(script.Parent.HUDController)
local SoundController = require(script.Parent.SoundController)
local Remotes = game.ReplicatedStorage.Shared.Remotes

local player = Players.LocalPlayer
local SettingsUI = {}

local panel: Frame
local state = { Music = true, Sfx = true }
local switches = {}

local ON_TOP, ON_BOTTOM = Color3.fromRGB(120, 235, 130), Color3.fromRGB(45, 170, 70)
local OFF_TOP, OFF_BOTTOM = Color3.fromRGB(190, 190, 205), Color3.fromRGB(120, 120, 140)

local function apply(key)
	if key == "Music" then SoundController.SetMusic(state.Music) else SoundController.SetSfx(state.Sfx) end
end

local function paint(key, instant)
	local sw = switches[key]
	if not sw then return end
	local on = state[key]
	sw.Track.UIGradient.Color = on and ColorSequence.new(ON_TOP, ON_BOTTOM) or ColorSequence.new(OFF_TOP, OFF_BOTTOM)
	sw.Text.Text = on and "ON" or "OFF"
	sw.Text.Position = on and UDim2.new(0, 10, 0, 0) or UDim2.new(0.45, 0, 0, 0)
	local target = on and UDim2.new(1, -42, 0.5, -19) or UDim2.new(0, 4, 0.5, -19)
	if instant then sw.Knob.Position = target
	else TweenService:Create(sw.Knob, TweenInfo.new(0.15, Enum.EasingStyle.Quad), { Position = target }):Play() end
end

local function row(y, key, title, iconName)
	local r = UIKit.Frame({ Name = key, Size = UDim2.new(1, -40, 0, 70), Position = UDim2.new(0, 20, 0, y),
		BackgroundColor3 = Color3.fromRGB(25, 30, 60), BackgroundTransparency = 0.35 })
	UIKit.Corner(r, 14)
	r.Parent = panel
	local l = UIKit.Label({ Text = title, Size = UDim2.new(0.5, 0, 0, 30), Position = UDim2.new(0, 18, 0.5, -15), TextXAlignment = Enum.TextXAlignment.Left })
	l.Parent = r

	local track = Instance.new("TextButton")
	track.Name = "Switch"
	track.Text = ""
	track.AutoButtonColor = false
	track.Size = UDim2.new(0, 104, 0, 46)
	track.Position = UDim2.new(1, -116, 0.5, -23)
	track.BackgroundColor3 = Color3.new(1, 1, 1)
	UIKit.Corner(track, 23)
	UIKit.Stroke(track, 3, UIKit.Dark, true)
	UIKit.Gradient(track, ON_TOP, ON_BOTTOM)
	track.Parent = r
	local text = UIKit.Label({ Text = "ON", Size = UDim2.new(0.55, 0, 1, 0), StrokeThickness = 2.5 })
	text.Parent = track
	local knob = UIKit.Frame({ Name = "Knob", Size = UDim2.new(0, 38, 0, 38), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 2 })
	UIKit.Corner(knob, 19)
	UIKit.Stroke(knob, 3, UIKit.Dark, true)
	knob.Parent = track
	switches[key] = { Track = track, Knob = knob, Text = text }

	track.Activated:Connect(function()
		state[key] = not state[key]
		apply(key)
		paint(key)
		SoundController.Play("Click")
		Remotes.SaveSettings:FireServer(key, state[key])
	end)
end

function SettingsUI.Start()
	local gui = player.PlayerGui:WaitForChild("HUD")
	panel = UIKit.Frame({ Name = "SettingsPanel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 400, 0, 250), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false })
	UIKit.Corner(panel, 20)
	UIKit.Stroke(panel, 5, Color3.fromRGB(20, 10, 40), true)
	UIKit.Gradient(panel, Color3.fromRGB(95, 110, 190), Color3.fromRGB(45, 50, 110))
	panel.Parent = gui

	local header = UIKit.Button({ Name = "Header", Text = "SETTINGS", Size = UDim2.new(0, 220, 0, 50), Position = UDim2.new(0.5, -110, 0, -26),
		Top = Color3.fromRGB(200, 210, 240), Bottom = Color3.fromRGB(120, 130, 180) })
	header.Active = false
	header.Parent = panel
	Icons.Gear(header, { Size = UDim2.new(0, 56, 0, 56), Position = UDim2.new(0, -32, 0.5, -29), ZIndex = 3 })
	local close = UIKit.Button({ Name = "Close", Text = "X", Size = UDim2.new(0, 46, 0, 46), Position = UDim2.new(1, -30, 0, -16),
		Top = Color3.fromRGB(255, 110, 110), Bottom = Color3.fromRGB(210, 40, 40) }, function() panel.Visible = false end)
	close.Parent = panel

	row(48, "Music", "Music", "Reel")
	row(132, "Sfx", "Sound Effects", "Lightning")
	local hint = UIKit.Label({ Text = "Saved to your account", Size = UDim2.new(1, -40, 0, 18), Position = UDim2.new(0, 20, 1, -30),
		TextColor3 = Color3.fromRGB(200, 205, 240) })
	hint.Parent = panel

	HUDController.AddSideButton("Settings", "SETTINGS", Color3.fromRGB(190, 200, 235), Color3.fromRGB(105, 115, 170), function()
		panel.Visible = not panel.Visible
		if panel.Visible then UIKit.Pop(panel) end
	end, "Gear").LayoutOrder = 99

	-- load saved choices
	local saved = ClientData.Get().Settings or {}
	for _, key in ipairs({ "Music", "Sfx" }) do
		if saved[key] ~= nil then state[key] = saved[key] end
		apply(key)
		paint(key, true)
	end
end

return SettingsUI
