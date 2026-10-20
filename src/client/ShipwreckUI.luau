--[[
	ShipwreckUI
	Reads the workspace attributes ShipwreckService publishes (so it's right even if you join mid-event):
	- Warning: pill under the Shells counter "SHIPWRECK IN 0:42"
	- Active: big announcement + pill "SHIPWRECK! 1:12 left" + an arrow pointing at the wreck
	- End: "The wreck sank!"
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer
local ShipwreckUI = {}

local function fmt(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

function ShipwreckUI.Start()
	local gui = player.PlayerGui:WaitForChild("HUD")

	local pill = UIKit.Frame({ Name = "Shipwreck", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 96),
		Size = UDim2.new(0, 300, 0, 40), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false })
	UIKit.Corner(pill, 20)
	UIKit.Stroke(pill, 3, Color3.fromRGB(40, 20, 10), true)
	local grad = UIKit.Gradient(pill, Color3.fromRGB(255, 200, 90), Color3.fromRGB(220, 110, 30))
	pill.Parent = gui
	local label = UIKit.Label({ Size = UDim2.new(1, -20, 0.72, 0), Position = UDim2.new(0, 10, 0.14, 0), StrokeThickness = 2.5 })
	label.Parent = pill

	local banner = UIKit.Label({ Name = "WreckBanner", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.new(0, 700, 0, 70), TextColor3 = Color3.fromRGB(255, 215, 90), StrokeThickness = 4, Visible = false })
	banner.Parent = gui
	local sub = UIKit.Label({ Name = "WreckSub", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.new(0, 600, 0, 28), TextColor3 = Color3.new(1, 1, 1), Visible = false })
	sub.Parent = gui

	-- arrow that points at the wreck while it's up (screen edge indicator)
	local arrow = UIKit.Label({ Name = "WreckArrow", Text = "^", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 60, 0, 60),
		TextColor3 = Color3.fromRGB(255, 215, 90), StrokeThickness = 3, Visible = false })
	arrow.Parent = gui
	local arrowDist = UIKit.Label({ Name = "WreckDist", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0, 90, 0, 20), Visible = false })
	arrowDist.Parent = gui

	local function announce(title: string, subtitle: string, color: Color3)
		banner.Text = title
		banner.TextColor3 = color
		sub.Text = subtitle
		banner.Position = UDim2.fromScale(0.5, 0.2)
		sub.Position = UDim2.new(0.5, 0, 0.2, 46)
		banner.ZIndex = 50
		sub.ZIndex = 50
		banner.TextTransparency = 0; sub.TextTransparency = 0
		banner:FindFirstChildOfClass("UIStroke").Transparency = 0
		sub:FindFirstChildOfClass("UIStroke").Transparency = 0
		banner.Visible = true; sub.Visible = true
		UIKit.Pop(banner)
		task.delay(3.5, function()
			for _, l in ipairs({ banner, sub }) do
				TweenService:Create(l, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
				TweenService:Create(l:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.6), { Transparency = 1 }):Play()
			end
		end)
	end

	local lastState = workspace:GetAttribute("ShipwreckState")
	local function onState()
		local state = workspace:GetAttribute("ShipwreckState")
		if state == lastState then return end
		local ok, sc = pcall(require, script.Parent.SoundController)
		if ok and (state == "Warning" or state == "Active") then sc.Play("Horn", state == "Active" and 0.9 or 1) end
		if state == "Warning" then
			announce("A SHIPWRECK IS COMING!", "Head towards the hub, it surfaces between the boardwalks", Color3.fromRGB(255, 215, 90))
		elseif state == "Active" then
			announce("SHIPWRECK SURFACED!", "Fish out its treasure before it sinks!", Color3.fromRGB(255, 180, 60))
		elseif state == "Idle" and lastState == "Active" then
			announce("The wreck sank...", "Next one in about 15 minutes", Color3.fromRGB(180, 210, 255))
		end
		lastState = state
	end
	workspace:GetAttributeChangedSignal("ShipwreckState"):Connect(onState)

	RunService.RenderStepped:Connect(function()
		local state = workspace:GetAttribute("ShipwreckState")
		local t = workspace:GetServerTimeNow()
		if state == "Warning" then
			pill.Visible = true
			label.Text = "SHIPWRECK IN " .. fmt((workspace:GetAttribute("ShipwreckStartsAt") or t) - t)
			grad.Color = ColorSequence.new(Color3.fromRGB(120, 200, 255), Color3.fromRGB(40, 110, 200))
		elseif state == "Active" then
			pill.Visible = true
			label.Text = "SHIPWRECK! " .. fmt((workspace:GetAttribute("ShipwreckEndsAt") or t) - t) .. " left"
			grad.Color = ColorSequence.new(Color3.fromRGB(255, 200, 90), Color3.fromRGB(220, 110, 30))
		else
			pill.Visible = false
		end

		-- edge arrow toward the wreck
		local pos = workspace:GetAttribute("ShipwreckPosition")
		local cam = workspace.CurrentCamera
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if state == "Active" and typeof(pos) == "Vector3" and cam and hrp then
			local dist = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(hrp.Position.X, 0, hrp.Position.Z)).Magnitude
			local screen, onScreen = cam:WorldToViewportPoint(pos + Vector3.new(0, 10, 0))
			local vp = cam.ViewportSize
			if onScreen and dist > 30 then
				arrow.Visible = true
				arrow.Rotation = 180
				arrow.Position = UDim2.fromOffset(screen.X, screen.Y - 40)
			elseif not onScreen then
				-- clamp to screen edge in the wreck's direction
				local center = vp / 2
				local dir = Vector2.new(screen.X, screen.Y) - center
				if screen.Z < 0 then dir = -dir end
				if dir.Magnitude < 1 then dir = Vector2.new(0, -1) end
				dir = dir.Unit
				local edge = center + dir * (math.min(vp.X, vp.Y) / 2 - 60)
				arrow.Visible = true
				arrow.Position = UDim2.fromOffset(edge.X, edge.Y)
				arrow.Rotation = math.deg(math.atan2(dir.Y, dir.X)) + 90
			else
				arrow.Visible = false
			end
			arrowDist.Visible = arrow.Visible
			arrowDist.Text = math.floor(dist) .. "m"
			arrowDist.Position = UDim2.new(arrow.Position.X.Scale, arrow.Position.X.Offset, arrow.Position.Y.Scale, arrow.Position.Y.Offset + 28)
		else
			arrow.Visible = false
			arrowDist.Visible = false
		end
	end)
end

return ShipwreckUI
