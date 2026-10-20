--[[
	FishingController (client)
	Idle -> Charging -> Casting -> (Biting -> Reeling) -> Idle

	UI: an action bar at the bottom  [QUICK FISH] [status / equip] [AUTO FISH],
	a power bar while charging and a reel panel while reeling.
	Auto Fish: aims at the best crate in reach, casts, reels, repeats (needs the group or Turbo Reel).
	Visuals and input only. Every real decision (hook, loot, timing) is made by FishingService.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local MarketplaceService = game:GetService("MarketplaceService")
local GroupService = game:GetService("GroupService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local ClientData = require(script.Parent.ClientData)
local FloaterBob = require(script.Parent.FloaterBob)
local RevealController = require(script.Parent.RevealController)
local FishSettings = require(script.Parent.FishSettings)
local UIKit = require(script.Parent.UIKit)
local Icons = require(script.Parent.Icons)
local SoundController = require(script.Parent.SoundController)
local Remotes = game.ReplicatedStorage.Shared.Remotes

local player = Players.LocalPlayer
local F = Config.Fishing
local WATER_Y = Config.World.WaterLevel

local FishingController = {}

local state = "Idle"
local chargeStart = 0
local currentCharge = 0
local tool: Tool? = nil
local ui: any = {}
local ring: Part
local bobber: Part
local bobberAtt: Attachment
local line: Beam
local holding = false
local activeTouches = 0
local cancelRequested = false
local devDirection: Vector3? = nil -- aim override (Studio test hook + Auto Fish)
local catchPending = false -- true from a successful reel until its reveal has opened

-- container -> rarity color used for the reel panel
local CONTAINER_RARITY = { Crate = "Common", Barrel = "Uncommon", Bottle = "Rare", Chest = "Epic", GoldenChest = "Legendary", Relic = "Mythic" }
local CONTAINER_ICON = { Crate = "Crate", Barrel = "Barrel", Bottle = "Bottle", Chest = "Chest", GoldenChest = "GoldenChest", Relic = "Relic" }
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 170, 60)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 240, 80)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(90, 230, 120)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(80, 170, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 100, 255)),
})

------------------------------------------------------------------
-- UI
------------------------------------------------------------------
local function panelGradient(frame, top, bottom)
	UIKit.Corner(frame, 14)
	UIKit.Stroke(frame, 3.5, UIKit.Dark, true)
	UIKit.Gradient(frame, top, bottom)
end

local function buildUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "FishingUI"
	gui.DisplayOrder = 11 -- above the reveal, so Quick/Auto Fish can be toggled mid-reveal
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	-- ACTION BAR
	local bar = UIKit.Frame({ Name = "ActionBar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.new(0, 600, 0, 58), BackgroundTransparency = 1 })
	bar.Parent = gui
	local quick, quickLabel = UIKit.Button({ Name = "Quick", Text = "QUICK FISH", Size = UDim2.new(0, 180, 0, 52), Position = UDim2.new(0, 0, 0.5, -26) })
	quick.Parent = bar
	local center, centerLabel = UIKit.Button({ Name = "Center", Text = "EQUIP ROD", Size = UDim2.new(0, 210, 0, 58), Position = UDim2.new(0.5, -105, 0, 0) })
	center.Parent = bar
	local auto, autoLabel = UIKit.Button({ Name = "Auto", Text = "AUTO FISH", Size = UDim2.new(0, 180, 0, 52), Position = UDim2.new(1, -180, 0.5, -26) })
	auto.Parent = bar

	-- POWER BAR
	local power = UIKit.Frame({ Name = "Power", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -100),
		Size = UDim2.new(0, 380, 0, 30), BackgroundColor3 = Color3.fromRGB(25, 20, 45), Visible = false })
	UIKit.Corner(power, 15); UIKit.Stroke(power, 3.5, UIKit.Dark, true)
	power.Parent = gui
	local fill = UIKit.Frame({ Name = "Fill", Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1) })
	UIKit.Corner(fill, 15)
	local fg = Instance.new("UIGradient")
	fg.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(110, 235, 120)), ColorSequenceKeypoint.new(0.6, Color3.fromRGB(255, 225, 80)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 90, 70)) })
	fg.Parent = fill
	fill.Parent = power
	for i = 1, 3 do
		local tick = UIKit.Frame({ Size = UDim2.new(0, 2, 0.6, 0), Position = UDim2.new(i * 0.25, -1, 0.2, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.5, ZIndex = 2 })
		tick.Parent = power
	end
	local powerLabel = UIKit.Label({ Text = "CAST POWER", Size = UDim2.new(0, 200, 0, 24), Position = UDim2.new(0.5, -100, 0, -28), StrokeThickness = 2.5 })
	powerLabel.Parent = power

	-- REEL PANEL
	local reel = UIKit.Frame({ Name = "Reel", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -96),
		Size = UDim2.new(0, 540, 0, 118), BackgroundTransparency = 1, Visible = false })
	reel.Parent = gui
	local iconHolder = UIKit.Frame({ Name = "IconHolder", Size = UDim2.new(0, 52, 0, 52), Position = UDim2.new(0, -6, 0, -4), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3 })
	panelGradient(iconHolder, Color3.fromRGB(90, 70, 150), Color3.fromRGB(45, 30, 85))
	UIKit.Corner(iconHolder, 26)
	iconHolder.Parent = reel
	local reelTitle = UIKit.Label({ Name = "Title", Text = "HOLD TO REEL!", Size = UDim2.new(1, -70, 0, 26), Position = UDim2.new(0, 56, 0, 2),
		TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 3 })
	reelTitle.Parent = reel
	local reelSub = UIKit.Label({ Name = "Sub", Text = "", Size = UDim2.new(1, -70, 0, 18), Position = UDim2.new(0, 56, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 2 })
	reelSub.Parent = reel

	local track = UIKit.Frame({ Name = "Track", Position = UDim2.new(0, 0, 0, 52), Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Color3.fromRGB(20, 30, 60) })
	UIKit.Corner(track, 12)
	local trackStroke = UIKit.Stroke(track, 4, Color3.new(1, 1, 1), true)
	local strokeGrad = Instance.new("UIGradient"); strokeGrad.Color = RAINBOW; strokeGrad.Parent = trackStroke
	local trackGrad = Instance.new("UIGradient")
	trackGrad.Color = ColorSequence.new(Color3.fromRGB(40, 70, 120), Color3.fromRGB(20, 35, 75)); trackGrad.Rotation = 90; trackGrad.Parent = track
	track.Parent = reel
	for i = 1, 9 do
		local t = UIKit.Frame({ Size = UDim2.new(0, 2, 0.35, 0), Position = UDim2.new(i / 10, -1, 0.65, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.7 })
		t.Parent = track
	end
	local zone = UIKit.Frame({ Name = "Zone", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0.25, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 2 })
	UIKit.Corner(zone, 10)
	local zoneGrad = Instance.new("UIGradient"); zoneGrad.Color = RAINBOW; zoneGrad.Parent = zone
	local shine = UIKit.Frame({ Size = UDim2.new(1, -8, 0.3, 0), Position = UDim2.new(0, 4, 0, 3), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.6, ZIndex = 3 })
	UIKit.Corner(shine, 6)
	shine.Parent = zone
	zone.Parent = track
	local marker = UIKit.Frame({ Name = "Marker", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 8, 1, 14),
		BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 4 })
	UIKit.Corner(marker, 4); UIKit.Stroke(marker, 2.5, UIKit.Dark, true)
	marker.Parent = track
	local bob = UIKit.Frame({ Name = "Bob", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -2), Size = UDim2.new(0, 18, 0, 18),
		BackgroundColor3 = Color3.fromRGB(235, 55, 55), ZIndex = 5 })
	UIKit.Corner(bob, 9); UIKit.Stroke(bob, 2.5, UIKit.Dark, true)
	local bobTop = UIKit.Frame({ Size = UDim2.new(1, 0, 0.45, 0), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 6 })
	UIKit.Corner(bobTop, 9)
	bobTop.Parent = bob
	bob.Parent = marker

	local progBg = UIKit.Frame({ Name = "ProgressBg", Position = UDim2.new(0, 0, 0, 100), Size = UDim2.new(1, 0, 0, 16), BackgroundColor3 = Color3.fromRGB(25, 20, 45) })
	UIKit.Corner(progBg, 8); UIKit.Stroke(progBg, 3, UIKit.Dark, true)
	progBg.Parent = reel
	local prog = UIKit.Frame({ Name = "Progress", Size = UDim2.new(0.25, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1) })
	UIKit.Corner(prog, 8)
	UIKit.Gradient(prog, Color3.fromRGB(255, 235, 110), Color3.fromRGB(240, 160, 30))
	prog.Parent = progBg

	-- HINT + TOAST
	local hint = UIKit.Label({ Text = "", AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.new(0, 520, 0, 26), Position = UDim2.new(0.5, 0, 1, -228), TextTransparency = 1 })
	hint.Parent = gui
	local hintStroke = hint:FindFirstChildOfClass("UIStroke"); hintStroke.Transparency = 1
	local toast = UIKit.Label({ Text = "", Size = UDim2.new(0, 560, 0, 46), Position = UDim2.new(0.5, -280, 0, 130), TextTransparency = 1, StrokeThickness = 3 })
	toast.Parent = gui
	local toastStroke = toast:FindFirstChildOfClass("UIStroke"); toastStroke.Transparency = 1

	ui = {
		Gui = gui, Bar = bar, Quick = quick, QuickLabel = quickLabel, Center = center, CenterLabel = centerLabel, Auto = auto, AutoLabel = autoLabel,
		Power = power, PowerFill = fill,
		Reel = reel, IconHolder = iconHolder, ReelTitle = reelTitle, ReelSub = reelSub, StrokeGrad = strokeGrad,
		Zone = zone, Marker = marker, Progress = prog,
		Hint = hint, HintStroke = hintStroke, Toast = toast, ToastStroke = toastStroke,
	}
end

local hintToken = 0
local function showHint(text: string, seconds: number?)
	hintToken += 1
	local my = hintToken
	ui.Hint.Text = text
	ui.Hint.TextTransparency = 0
	ui.HintStroke.Transparency = 0
	task.delay(seconds or 2.5, function()
		if my ~= hintToken then return end
		TweenService:Create(ui.Hint, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		TweenService:Create(ui.HintStroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
	end)
end

local toastToken = 0
local function showToast(text: string, color: Color3)
	toastToken += 1
	local my = toastToken
	ui.Toast.Text = text
	ui.Toast.TextColor3 = color
	ui.Toast.TextTransparency = 0
	ui.ToastStroke.Transparency = 0
	task.delay(2.5, function()
		if my ~= toastToken then return end
		TweenService:Create(ui.Toast, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		TweenService:Create(ui.ToastStroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
	end)
end

------------------------------------------------------------------
-- Action bar state
------------------------------------------------------------------
local ON = { Color3.fromRGB(120, 235, 130), Color3.fromRGB(45, 170, 70) }
local OFF = { Color3.fromRGB(170, 170, 190), Color3.fromRGB(105, 105, 125) }
local BLUE = { Color3.fromRGB(120, 200, 255), Color3.fromRGB(50, 120, 230) }
local GOLD = { Color3.fromRGB(255, 215, 100), Color3.fromRGB(230, 150, 30) }

local function paint(btn, colors)
	btn.UIGradient.Color = ColorSequence.new(colors[1], colors[2])
end

local function refreshBar()
	local equipped = tool ~= nil and tool.Parent == player.Character
	local text
	if state == "Charging" then text = "RELEASE!"
	elseif state == "Casting" then text = "CASTING..."
	elseif state == "Biting" then text = "SOMETHING'S BITING!"
	elseif state == "Reeling" then text = "REELING..."
	elseif FishSettings.AutoFish and equipped then text = "AUTO FISHING..."
	elseif equipped then text = "PUT AWAY ROD"
	else text = "EQUIP ROD" end
	ui.CenterLabel.Text = text
	paint(ui.Center, (state ~= "Idle" or (FishSettings.AutoFish and equipped)) and GOLD or (equipped and OFF or BLUE))

	ui.QuickLabel.Text = FishSettings.QuickFish and "QUICK FISH: ON" or "QUICK FISH"
	paint(ui.Quick, FishSettings.QuickFish and ON or OFF)
	ui.AutoLabel.Text = FishSettings.AutoFish and "AUTO FISH: ON" or "AUTO FISH"
	paint(ui.Auto, FishSettings.AutoFish and ON or OFF)
end

local function setState(s: string)
	state = s
	refreshBar()
end

local function equipRod(on: boolean)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	if on then
		local t = player.Backpack:FindFirstChild("Rod") or char:FindFirstChild("Rod")
		if t and t.Parent ~= char then hum:EquipTool(t) end
	else
		hum:UnequipTools()
	end
end

------------------------------------------------------------------
-- World visuals (client only)
------------------------------------------------------------------
local function buildWorldVisuals()
	ring = Instance.new("Part")
	ring.Name = "CastRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.15, F.HookRadius * 2, F.HookRadius * 2)
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Transparency = 1
	ring.Parent = workspace.CurrentCamera

	bobber = Instance.new("Part")
	bobber.Name = "Bobber"
	bobber.Shape = Enum.PartType.Ball
	bobber.Size = Vector3.new(0.7, 0.7, 0.7)
	bobber.Anchored = true
	bobber.CanCollide = false
	bobber.CanQuery = false
	bobber.CanTouch = false
	bobber.Color = Color3.fromRGB(230, 50, 50)
	bobber.Material = Enum.Material.SmoothPlastic
	bobber.Transparency = 1
	bobber.Parent = workspace.CurrentCamera
	bobberAtt = Instance.new("Attachment")
	bobberAtt.Parent = bobber

	line = Instance.new("Beam")
	line.Name = "FishingLine"
	line.Width0 = 0.05
	line.Width1 = 0.05
	line.FaceCamera = true
	line.Segments = 12
	line.CurveSize0 = -1.5
	line.Color = ColorSequence.new(Color3.fromRGB(240, 240, 240))
	line.Transparency = NumberSequence.new(0.1)
	line.Attachment1 = bobberAtt
	line.Enabled = false
	line.Parent = bobber
end

local function getRod()
	local d = ClientData.Get()
	return Config.Rods[d.EquippedRod] or Config.Rods[1]
end

local function getHRP(): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function castDirection(): Vector3
	if devDirection then return devDirection end
	local look = workspace.CurrentCamera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then
		local hrp = getHRP()
		return hrp and hrp.CFrame.LookVector or Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

local function landingFor(charge: number): Vector3?
	local hrp = getHRP()
	if not hrp then return nil end
	local p = hrp.Position + castDirection() * (charge * getRod().MaxDistance)
	return Vector3.new(p.X, WATER_Y, p.Z)
end

-- mirror of the server's hook check, used to color the aim ring
local function previewTarget(landing: Vector3): (Model?, string?)
	local folder = workspace:FindFirstChild("Floaters")
	if not folder then return nil end
	local best, bestD = nil, F.HookRadius
	for _, m in ipairs(folder:GetChildren()) do
		if m:IsA("Model") and not m:GetAttribute("ClaimedBy") and not m:GetAttribute("Sinking") then
			local base = FloaterBob.GetBase(m) or m:GetPivot()
			local d = (Vector3.new(base.X, 0, base.Z) - Vector3.new(landing.X, 0, landing.Z)).Magnitude
			if d <= bestD then best, bestD = m, d end
		end
	end
	if not best then return nil end
	local c = Config.Containers[best:GetAttribute("Container")]
	if c and ClientData.Get().EquippedRod < c.MinRod and not best:GetAttribute("Event") then return best, "weak" end
	return best, "ok"
end

local function tipAttachment(): Attachment?
	local h = tool and tool:FindFirstChild("Handle")
	return h and h:FindFirstChild("Tip")
end

local function hideBobber()
	bobber.Transparency = 1
	line.Enabled = false
end

local function flyBobber(to: Vector3, duration: number)
	local tip = tipAttachment()
	if not tip then return end
	line.Attachment0 = tip
	line.Enabled = true
	bobber.Transparency = 0
	local from = tip.WorldPosition
	local height = math.max(6, (to - from).Magnitude * 0.25)
	local t0 = os.clock()
	while true do
		local a = math.clamp((os.clock() - t0) / duration, 0, 1)
		bobber.CFrame = CFrame.new(from:Lerp(to, a) + Vector3.new(0, math.sin(a * math.pi) * height, 0))
		if a >= 1 then break end
		RunService.RenderStepped:Wait()
	end
end

local function splash(pos: Vector3, big: boolean?)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
	p.Transparency = 1; p.Size = Vector3.new(0.2, 0.2, 0.2); p.CFrame = CFrame.new(pos)
	p.Parent = workspace.CurrentCamera
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(220, 245, 255))
	e.Speed = NumberRange.new(6, big and 16 or 10)
	e.SpreadAngle = Vector2.new(35, 35)
	e.Acceleration = Vector3.new(0, -40, 0)
	e.Lifetime = NumberRange.new(0.4, 0.7)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0.1) })
	e.EmissionDirection = Enum.NormalId.Top
	e.Enabled = false
	e.Parent = p
	e:Emit(big and 40 or 18)
	game:GetService("Debris"):AddItem(p, 1.5)
end

local function reelBobberBack()
	local tip = tipAttachment()
	if not tip or bobber.Transparency >= 1 then hideBobber(); return end
	local from = bobber.Position
	local t0 = os.clock()
	while os.clock() - t0 < 0.35 do
		bobber.CFrame = CFrame.new(from:Lerp(tip.WorldPosition, (os.clock() - t0) / 0.35))
		RunService.RenderStepped:Wait()
	end
	hideBobber()
end

------------------------------------------------------------------
-- Movement lock while reeling
------------------------------------------------------------------
local savedWalk, savedJump = nil, nil
local function lockMovement(on: boolean)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	if on then
		savedWalk, savedJump = hum.WalkSpeed, hum.JumpHeight
		hum.WalkSpeed = 0
		hum.JumpHeight = 0
	elseif savedWalk then
		hum.WalkSpeed = savedWalk
		hum.JumpHeight = savedJump
		savedWalk, savedJump = nil, nil
	end
end

------------------------------------------------------------------
-- Reel minigame. Returns true on success.
------------------------------------------------------------------
local function runReel(info, targetModel: Model?): boolean
	local auto = player:GetAttribute("AutoReel") == true
	local turbo = player:GetAttribute("Pass_TurboReel") == true
	local difficulty = math.max(info.Difficulty or 1, 0.5)
	local zoneWidth = math.clamp(F.ZoneWidthBase / difficulty, F.ZoneWidthMin, F.ZoneWidthMax)
	local zoneSpeed = F.ZoneSpeedBase + F.ZoneSpeedPerDifficulty * difficulty
	local zone, zoneTarget, pauseUntil = 0.5, math.random(), 0
	local marker, vel = 0.5, 0
	local progress = info.StartProgress
	local fillRate = info.FillRate * ((auto and not turbo) and F.AutoReelSpeed or 1)
	local start = os.clock()
	local playerSide = Vector3.zero

	-- header: what we're reeling
	local containerId = info.Container
	local cfgC = Config.Containers[containerId]
	local rarity = CONTAINER_RARITY[containerId] or "Common"
	local rColor = Config.Rarities[rarity].Color
	for _, c in ipairs(ui.IconHolder:GetChildren()) do if c:IsA("ViewportFrame") then c:Destroy() end end
	Icons.Viewport(ui.IconHolder, CONTAINER_ICON[containerId] or "Crate", { Size = UDim2.new(1.3, 0, 1.3, 0), Position = UDim2.new(-0.15, 0, -0.2, 0), ZIndex = 4, SpinSpeed = 2 })
	ui.ReelTitle.Text = auto and "AUTO REELING..." or "HOLD TO REEL!"
	ui.ReelSub.Text = "Reeling in a " .. (cfgC and cfgC.Name or "crate") .. "!"
	ui.ReelSub.TextColor3 = rColor
	ui.Reel.Visible = true
	ui.Zone.Size = UDim2.new(zoneWidth, 0, 1, 0)

	local hrp = getHRP()
	if targetModel and hrp then
		local base = FloaterBob.GetBase(targetModel) or targetModel:GetPivot()
		playerSide = Vector3.new(hrp.Position.X, WATER_Y, hrp.Position.Z) - base.Position
	end

	local result: boolean? = nil
	local last = os.clock()
	while result == nil do
		RunService.RenderStepped:Wait()
		local now = os.clock()
		local dt = math.min(now - last, 0.1)
		last = now
		if cancelRequested then result = false; break end

		ui.StrokeGrad.Rotation = (now * 120) % 360

		if now >= pauseUntil then
			local dir = zoneTarget - zone
			local stepSize = zoneSpeed * dt
			if math.abs(dir) <= stepSize then
				zone = zoneTarget
				zoneTarget = math.clamp(math.random(), zoneWidth / 2, 1 - zoneWidth / 2)
				pauseUntil = now + math.random() * F.ZonePauseMax
			else
				zone += math.sign(dir) * stepSize
			end
		end

		local inZone
		if auto then
			marker += (zone - marker) * math.min(1, dt * 8)
			inZone = true
		else
			local accel = (holding or activeTouches > 0) and F.MarkerAccel or -F.MarkerAccel
			vel = math.clamp(vel + accel * dt, -F.MarkerMaxSpeed, F.MarkerMaxSpeed)
			marker += vel * dt
			if marker < 0 then marker = 0; vel = -vel * 0.3 end
			if marker > 1 then marker = 1; vel = -vel * 0.3 end
			inZone = math.abs(marker - zone) <= zoneWidth / 2
		end

		progress += inZone and (fillRate * dt) or (-info.DrainRate * dt)

		ui.Zone.Position = UDim2.new(zone, 0, 0, 0)
		ui.Marker.Position = UDim2.new(marker, 0, 0.5, 0)
		ui.Progress.Size = UDim2.new(math.clamp(progress, 0, 1), 0, 1, 0)
		ui.Zone.BackgroundTransparency = inZone and 0 or 0.35

		if targetModel and targetModel.Parent then
			FloaterBob.SetOffset(targetModel, playerSide * math.clamp(progress, 0, 1) * 0.35)
			bobber.CFrame = CFrame.new(targetModel:GetPivot().Position + Vector3.new(0, 1.5 + math.sin(now * 20) * 0.1, 0))
		end

		if progress >= 1 then result = true
		elseif progress <= 0 then result = false
		elseif now - start > F.ReelTimeout - 3 then result = false end
	end

	ui.Reel.Visible = false
	return result == true
end

------------------------------------------------------------------
-- Catch animation: clone flies from the water to the player, then pops
------------------------------------------------------------------
local function playCatchAnimation(clone: Model?)
	if not clone then return end
	local hrp = getHRP()
	if not hrp then clone:Destroy(); return end
	local from = clone:GetPivot()
	local t0 = os.clock()
	while os.clock() - t0 < 0.7 do
		local a = (os.clock() - t0) / 0.7
		local target = hrp.Position + Vector3.new(0, 4, 0)
		clone:PivotTo(CFrame.new(from.Position:Lerp(target, a) + Vector3.new(0, math.sin(a * math.pi) * 10, 0)) * CFrame.Angles(a * 6, a * 9, 0))
		RunService.RenderStepped:Wait()
	end
	splash(clone:GetPivot().Position, true)
	SoundController.Play("Splash", 0.9)
	clone:Destroy()
end

------------------------------------------------------------------
-- Main flow
------------------------------------------------------------------
local function doCast(charge: number)
	setState("Casting")
	cancelRequested = false
	ui.Power.Visible = false
	ring.Transparency = 1

	local hrp = getHRP()
	if not hrp then setState("Idle"); return end
	local dir = castDirection()
	hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + dir)

	local predicted = landingFor(charge) or hrp.Position
	local result
	task.spawn(function()
		local ok, r = pcall(function() return Remotes.Cast:InvokeServer(dir, charge) end)
		result = ok and r or { Ok = false, Reason = "Error" }
	end)
	flyBobber(predicted + Vector3.new(0, 0.2, 0), 0.55)
	splash(predicted)
	SoundController.Play("Plop", 1.1)
	local waitStart = os.clock()
	while not result and os.clock() - waitStart < 5 do RunService.RenderStepped:Wait() end
	result = result or { Ok = false, Reason = "Timeout" }

	if not result.Ok then
		if result.Reason ~= "TooFast" and result.Reason ~= "Busy" then showHint("Couldn't cast, try again.") end
		reelBobberBack()
		setState("Idle")
		return
	end

	if not result.Hooked then
		if result.Reason == "RodTooWeak" then
			local rod = Config.Rods[result.NeedRod]
			local c = Config.Containers[result.Container]
			showHint(("You need the %s to reel in a %s!"):format(rod and rod.Name or "better rod", c and c.Name or "that"), 3)
		elseif not FishSettings.AutoFish then
			showHint("Missed! Land the ring on a floating crate.", 2)
		end
		task.wait(0.5)
		reelBobberBack()
		setState("Idle")
		return
	end

	setState("Biting")
	local target = workspace:FindFirstChild("Floaters") and workspace.Floaters:FindFirstChild("Floater_" .. result.FloaterId)
	local anchor = target and target:GetPivot().Position or result.Position
	bobber.CFrame = CFrame.new(anchor + Vector3.new(0, 1.5, 0))
	lockMovement(true)

	local biteAt = os.clock() + 0.6 + math.random() * 0.7
	while os.clock() < biteAt and not cancelRequested do
		local p = target and target.Parent and target:GetPivot().Position or anchor
		bobber.CFrame = CFrame.new(p + Vector3.new(0, 1.5 + math.sin(os.clock() * 6) * 0.15, 0))
		RunService.RenderStepped:Wait()
	end
	if not cancelRequested then
		splash(bobber.Position)
		SoundController.Play("Splash", 1.2)
	end

	setState("Reeling")
	SoundController.Loop("Reel", true)
	local success = (not cancelRequested) and runReel(result, target) or false
	SoundController.Loop("Reel", false)

	local clone = nil
	if success and target and target.Parent then
		clone = target:Clone()
		clone.Parent = workspace.CurrentCamera
		for _, d in ipairs(target:GetDescendants()) do
			if d:IsA("BasePart") then d.LocalTransparencyModifier = 1 end
		end
	end
	if target and target.Parent then FloaterBob.SetOffset(target, Vector3.zero) end

	local ok, r = pcall(function() return Remotes.ReelFinish:InvokeServer(success) end)
	local finish = ok and r or { Ok = false }

	lockMovement(false)
	hideBobber()

	if finish.Ok and finish.Caught then
		catchPending = true
		task.spawn(function()
			playCatchAnimation(clone)
			RevealController.Show(finish)
			task.wait(0.1)
			catchPending = false
		end)
	else
		if clone then clone:Destroy() end
		if target and target.Parent then
			for _, d in ipairs(target:GetDescendants()) do
				if d:IsA("BasePart") then d.LocalTransparencyModifier = 0 end
			end
		end
		if not cancelRequested then showToast("It got away...", Color3.fromRGB(200, 200, 210)) end
	end

	setState("Idle")
	cancelRequested = false
end

------------------------------------------------------------------
-- Auto Fish: pick the best crate in reach (rarest first, then nearest)
------------------------------------------------------------------
local TIER = {}
for i, id in ipairs(Config.ContainerOrder) do TIER[id] = i end

local function autoTarget()
	local hrp = getHRP()
	local folder = workspace:FindFirstChild("Floaters")
	if not hrp or not folder then return nil end
	local rod = getRod()
	local rodTier = ClientData.Get().EquippedRod
	local best, bestTier, bestDist = nil, -1, math.huge
	for _, m in ipairs(folder:GetChildren()) do
		if m:IsA("Model") and not m:GetAttribute("ClaimedBy") and not m:GetAttribute("Sinking") then
			local id = m:GetAttribute("Container")
			local c = Config.Containers[id]
			if c and (rodTier >= c.MinRod or m:GetAttribute("Event")) then
				local base = FloaterBob.GetBase(m) or m:GetPivot()
				local d = (Vector3.new(base.X, 0, base.Z) - Vector3.new(hrp.Position.X, 0, hrp.Position.Z)).Magnitude
				if d <= rod.MaxDistance - 2 and d > 4 then
					local t = TIER[id] or 0
					if t > bestTier or (t == bestTier and d < bestDist) then best, bestTier, bestDist = m, t, d end
				end
			end
		end
	end
	if not best then return nil end
	local base = FloaterBob.GetBase(best) or best:GetPivot()
	local flat = (Vector3.new(base.X, 0, base.Z) - Vector3.new(hrp.Position.X, 0, hrp.Position.Z))
	return flat.Unit, math.clamp(flat.Magnitude / rod.MaxDistance, F.MinCharge, 1)
end

local lastNoTargetHint = 0
local function autoLoop()
	while FishSettings.AutoFish do
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if state == "Idle" and not catchPending and tool and tool.Parent == player.Character and not RevealController.IsOpen()
			and hum and hum.MoveDirection.Magnitude < 0.1 then
			local dir, charge = autoTarget()
			if dir then
				devDirection = dir
				doCast(charge)
				devDirection = nil
				task.wait(0.4)
			else
				if os.clock() - lastNoTargetHint > 6 then
					lastNoTargetHint = os.clock()
					showHint("No crates in reach. Stand at the edge of your island!", 3)
				end
				task.wait(1)
			end
		else
			task.wait(0.3)
		end
	end
	refreshBar()
end

local function toggleAutoFish()
	if FishSettings.AutoFish then
		FishSettings.Set("AutoFish", false)
		refreshBar()
		return
	end
	if player:GetAttribute("AutoReel") ~= true then
		-- locked: free for group members, or with Turbo Reel
		local groupId = Config.Group.GroupId
		if groupId ~= 0 then
			showHint("Join our group for FREE Auto Fish!", 3)
			pcall(function() GroupService:PromptJoinAsync(groupId) end)
			Remotes.RecheckGroup:FireServer()
		else
			local turbo = Config.Monetization.GamePasses.TurboReel
			showHint("Auto Fish comes with Turbo Reel!", 3)
			if turbo.Id ~= 0 then MarketplaceService:PromptGamePassPurchase(player, turbo.Id) end
		end
		return
	end
	FishSettings.Set("AutoFish", true)
	equipRod(true)
	refreshBar()
	task.spawn(autoLoop)
end

local function toggleQuickFish()
	if player:GetAttribute("Pass_SkipReveal") ~= true then
		local pass = Config.Monetization.GamePasses.SkipReveal
		showHint("Quick Fish skips the crate opening. Get it with Skip Reveal!", 3)
		if pass.Id ~= 0 then MarketplaceService:PromptGamePassPurchase(player, pass.Id) end
		return
	end
	FishSettings.Set("QuickFish", not FishSettings.QuickFish)
	refreshBar()
end

------------------------------------------------------------------
-- Tool binding
------------------------------------------------------------------
local function bindTool(t: Tool)
	if t.Name ~= "Rod" or t == tool then return end
	tool = t
	t.Activated:Connect(function()
		if tool ~= t or state ~= "Idle" or FishSettings.AutoFish then return end
		if catchPending or RevealController.IsOpen() then return end
		setState("Charging")
		chargeStart = os.clock()
		ui.Power.Visible = true
	end)
	t.Deactivated:Connect(function()
		if tool ~= t or state ~= "Charging" then return end
		task.spawn(doCast, currentCharge)
	end)
	t.Equipped:Connect(refreshBar)
	t.Unequipped:Connect(function()
		if state == "Charging" then
			setState("Idle")
			ui.Power.Visible = false
			ring.Transparency = 1
		elseif state ~= "Idle" then
			cancelRequested = true
		end
		refreshBar()
	end)
	refreshBar()
end

local function watchContainer(container: Instance)
	for _, c in ipairs(container:GetChildren()) do
		if c:IsA("Tool") then bindTool(c) end
	end
	container.ChildAdded:Connect(function(c)
		if c:IsA("Tool") then bindTool(c) end
	end)
end

function FishingController.Start()
	buildUI()
	buildWorldVisuals()
	-- our action bar replaces Roblox's tool hotbar
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)

	ui.Center.Activated:Connect(function()
		local equipped = tool ~= nil and tool.Parent == player.Character
		if state ~= "Idle" then return end
		if equipped and FishSettings.AutoFish then
			FishSettings.Set("AutoFish", false)
		end
		equipRod(not equipped)
	end)
	ui.Auto.Activated:Connect(toggleAutoFish)
	ui.Quick.Activated:Connect(toggleQuickFish)
	player:GetAttributeChangedSignal("AutoReel"):Connect(refreshBar)
	player:GetAttributeChangedSignal("Pass_SkipReveal"):Connect(refreshBar)

	-- Studio-only test hook: player.DevCast:Fire(charge, direction) performs a precise cast
	if RunService:IsStudio() then
		local devCast = Instance.new("BindableEvent")
		devCast.Name = "DevCast"
		devCast.Parent = player
		devCast.Event:Connect(function(charge: number, direction: Vector3)
			if state ~= "Idle" or not tool then return end
			devDirection = direction
			task.spawn(function()
				doCast(charge)
				devDirection = nil
			end)
		end)
	end

	watchContainer(player:WaitForChild("Backpack"))
	player.CharacterAdded:Connect(function(char)
		tool = nil
		cancelRequested = true
		lockMovement(false)
		watchContainer(char)
		watchContainer(player:WaitForChild("Backpack"))
		task.defer(refreshBar)
	end)
	if player.Character then watchContainer(player.Character) end

	-- inputs: hold for the reel, "1" toggles the rod (the hotbar is hidden)
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonR2 then
			holding = true
		elseif input.UserInputType == Enum.UserInputType.Touch then
			activeTouches += 1
		elseif input.KeyCode == Enum.KeyCode.One and not processed and state == "Idle" then
			equipRod(not (tool ~= nil and tool.Parent == player.Character))
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonR2 then
			holding = false
		elseif input.UserInputType == Enum.UserInputType.Touch then
			activeTouches = math.max(0, activeTouches - 1)
		end
	end)

	-- charging: ping-pong power + aim ring
	RunService.RenderStepped:Connect(function()
		if state ~= "Charging" then return end
		local t = (os.clock() - chargeStart) % 1.8
		local p = t <= 0.9 and (t / 0.9) or (2 - t / 0.9)
		currentCharge = math.max(F.MinCharge, p)
		ui.PowerFill.Size = UDim2.new(currentCharge, 0, 1, 0)
		local landing = landingFor(currentCharge)
		if landing then
			ring.CFrame = CFrame.new(landing + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
			local _, status = previewTarget(landing)
			ring.Color = status == "ok" and Color3.fromRGB(90, 255, 120)
				or status == "weak" and Color3.fromRGB(255, 190, 60)
				or Color3.fromRGB(240, 240, 255)
			ring.Transparency = status and 0.35 or 0.6
		end
	end)

	refreshBar()
end

return FishingController
