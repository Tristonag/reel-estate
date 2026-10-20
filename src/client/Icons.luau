--[[
	Icons
	3D icons for buttons and cards. Built from our own assets (or small part models),
	rendered in ViewportFrames and spun slowly by one shared loop.

	Icons.Build(name) -> Model
	Icons.Viewport(parent, name, props?) -> GuiObject   props: Size, Position, Zoom, Spin (default true), Angle, Force3D
	Icons.Image(parent, name, props?) -> ImageLabel     flat 2D icon from the sprite sheet

	Menus use the flat 2D sprite sheet (crisp, reads well at small sizes). Viewport() returns a
	2D icon whenever the name has a sprite, and only falls back to a spinning 3D model otherwise.
	Real items (backpack, reveal, book, placement) still use 3D models through UIKit.Viewport.
]]
local RunService = game:GetService("RunService")

local ItemVisuals = require(game.ReplicatedStorage.Shared.ItemVisuals)
local ContainerVisuals = require(game.ReplicatedStorage.Shared.ContainerVisuals)

local Icons = {}

local function part(m, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	p.Parent = m
	return p
end

local BUILDERS = {}

BUILDERS.Clover = function()
	local m = Instance.new("Model")
	local green = Color3.fromRGB(90, 220, 90)
	for i = 0, 3 do
		local a = i * math.pi / 2
		part(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(1.3, 1.3, 0.5), CFrame = CFrame.new(math.cos(a) * 0.65, math.sin(a) * 0.65, 0), Material = Enum.Material.SmoothPlastic, Color = green })
	end
	part(m, { Size = Vector3.new(0.25, 1.4, 0.25), CFrame = CFrame.new(0.25, -1.1, 0) * CFrame.Angles(0, 0, math.rad(-20)), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(60, 160, 60) })
	part(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.55), Material = Enum.Material.Neon, Color = Color3.fromRGB(200, 255, 170) })
	return m
end

BUILDERS.Crown = function()
	local m = Instance.new("Model")
	local gold = Color3.fromRGB(255, 205, 60)
	part(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 2.4, 2.4), CFrame = CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Metal, Color = gold })
	for i = 0, 4 do
		local a = i * (math.pi * 2 / 5)
		part(m, { Shape = Enum.PartType.Wedge, Size = Vector3.new(0.3, 0.9, 0.6), CFrame = CFrame.new(math.cos(a) * 1.05, 0.8, math.sin(a) * 1.05) * CFrame.Angles(0, -a + math.pi / 2, 0), Material = Enum.Material.Metal, Color = gold })
		part(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.3, 0.3, 0.3), CFrame = CFrame.new(math.cos(a) * 1.05, 1.3, math.sin(a) * 1.05), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 240, 180) })
	end
	part(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.6, 0.6), CFrame = CFrame.new(0, 0, -1.2), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 60, 120) })
	return m
end

BUILDERS.Reel = function()
	local m = Instance.new("Model")
	part(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 2.4, 2.4), Material = Enum.Material.Metal, Color = Color3.fromRGB(90, 200, 255) })
	part(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 1.4, 1.4), Material = Enum.Material.Neon, Color = Color3.fromRGB(200, 240, 255) })
	part(m, { Size = Vector3.new(0.3, 0.3, 1.6), CFrame = CFrame.new(0.6, 0, 0.9), Material = Enum.Material.Metal, Color = Color3.fromRGB(60, 60, 70) })
	part(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5), CFrame = CFrame.new(0.6, 0, 1.7), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(255, 90, 90) })
	for i = -1, 1 do
		part(m, { Size = Vector3.new(0.12, 0.12, 1.2), CFrame = CFrame.new(-0.9, i * 0.5, -1.4), Material = Enum.Material.Neon, Color = Color3.new(1, 1, 1) })
	end
	return m
end

BUILDERS.FastForward = function()
	local m = Instance.new("Model")
	for i = 0, 1 do
		part(m, { Shape = Enum.PartType.Wedge, Size = Vector3.new(0.4, 1.6, 1.4), CFrame = CFrame.new(0, 0, i * 1.1 - 0.5) * CFrame.Angles(0, math.rad(90), math.rad(90)), Material = Enum.Material.Neon, Color = Color3.fromRGB(120, 230, 255) })
	end
	return m
end

BUILDERS.Book = function()
	local m = Instance.new("Model")
	part(m, { Size = Vector3.new(2.2, 0.5, 2.8), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(170, 90, 50) })
	part(m, { Size = Vector3.new(2, 0.4, 2.6), CFrame = CFrame.new(0.12, 0.05, 0), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(250, 240, 215) })
	part(m, { Size = Vector3.new(2.2, 0.1, 2.8), CFrame = CFrame.new(0, 0.28, 0), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(190, 105, 60) })
	part(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.2, 0.7), CFrame = CFrame.new(0, 0.36, 0), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 215, 90) })
	return m
end

BUILDERS.Gift = function()
	local m = Instance.new("Model")
	part(m, { Size = Vector3.new(2, 1.6, 2), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(90, 200, 255) })
	part(m, { Size = Vector3.new(2.2, 0.5, 2.2), CFrame = CFrame.new(0, 0.95, 0), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(120, 215, 255) })
	part(m, { Size = Vector3.new(0.4, 1.9, 2.25), CFrame = CFrame.new(0, 0.15, 0), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(255, 90, 140) })
	part(m, { Size = Vector3.new(2.25, 1.9, 0.4), CFrame = CFrame.new(0, 0.15, 0), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(255, 90, 140) })
	part(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.5, 0.7), CFrame = CFrame.new(-0.35, 1.4, 0), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(255, 90, 140) })
	part(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.5, 0.7), CFrame = CFrame.new(0.35, 1.4, 0), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(255, 90, 140) })
	return m
end

BUILDERS.Glowbug = function()
	local m = Instance.new("Model")
	part(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), Material = Enum.Material.Neon, Color = Color3.fromRGB(190, 255, 110) })
	part(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9), CFrame = CFrame.new(0, 0.3, -0.8), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(60, 60, 70) })
	for _, s in ipairs({ -1, 1 }) do
		part(m, { Size = Vector3.new(1.4, 0.08, 0.8), CFrame = CFrame.new(s * 0.9, 0.7, 0) * CFrame.Angles(0, 0, math.rad(s * 25)), Material = Enum.Material.Glass, Color = Color3.fromRGB(220, 240, 255), Transparency = 0.3 })
	end
	return m
end

BUILDERS.Worm = function()
	local m = Instance.new("Model")
	for i = 0, 5 do
		local a = i * 0.55
		part(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.75, 0.75, 0.75) * (1 - i * 0.06), CFrame = CFrame.new(math.sin(a) * 0.9, i * 0.45 - 1, math.cos(a) * 0.4),
			Material = Enum.Material.SmoothPlastic, Color = (i % 2 == 0) and Color3.fromRGB(255, 140, 160) or Color3.fromRGB(240, 115, 140) })
	end
	part(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.18, 0.18, 0.18), CFrame = CFrame.new(math.sin(2.75) * 0.9 - 0.15, 1.35, math.cos(2.75) * 0.4 - 0.25), Material = Enum.Material.SmoothPlastic, Color = Color3.new(0, 0, 0) })
	part(m, { Size = Vector3.new(0.12, 1.8, 0.12), CFrame = CFrame.new(0.2, 0.2, 0.6), Material = Enum.Material.Metal, Color = Color3.fromRGB(190, 195, 205) })
	return m
end

BUILDERS.Shrimp = function()
	local m = Instance.new("Model")
	for i = 0, 6 do
		local a = i * 0.45
		part(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9) * (1 - i * 0.08), CFrame = CFrame.new(math.cos(a) * 1.1, math.sin(a) * 1.1, 0),
			Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(255, 150 - i * 6, 90) })
	end
	part(m, { Shape = Enum.PartType.Wedge, Size = Vector3.new(0.2, 0.8, 0.8), CFrame = CFrame.new(math.cos(3.1) * 1.1, math.sin(3.1) * 1.1 - 0.3, 0), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(255, 120, 80) })
	part(m, { Size = Vector3.new(0.06, 0.06, 1.6), CFrame = CFrame.new(1.2, 0.5, 0) * CFrame.Angles(math.rad(20), math.rad(60), 0), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(255, 170, 120) })
	return m
end

BUILDERS.Shell = function()
	local m = Instance.new("Model")
	for i = -3, 3 do
		part(m, { Shape = Enum.PartType.Wedge, Size = Vector3.new(0.35, 1.9 - math.abs(i) * 0.15, 0.7),
			CFrame = CFrame.new(0, -0.6, 0) * CFrame.Angles(0, 0, math.rad(i * 17)) * CFrame.new(0, 0.95, 0) * CFrame.Angles(0, math.rad(90), 0),
			Material = Enum.Material.SmoothPlastic, Color = (i % 2 == 0) and Color3.fromRGB(255, 190, 200) or Color3.fromRGB(255, 225, 225) })
	end
	part(m, { Size = Vector3.new(0.8, 0.4, 0.5), CFrame = CFrame.new(0, -0.75, 0), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(245, 165, 175) })
	return m
end

-- "Rod:<tier>" builds that tier's rod in its color (tiers 6+ get a glowing tip and metal finish)
local function buildRod(tier: number): Model
	local Config = require(game.ReplicatedStorage.Shared.Config)
	local rod = Config.Rods[tier] or Config.Rods[1]
	local color = Color3.fromRGB(rod.Color[1], rod.Color[2], rod.Color[3])
	local m = Instance.new("Model")
	local tilt = CFrame.Angles(0, 0, math.rad(-40))
	part(m, { Size = Vector3.new(0.22, 4.6, 0.22), CFrame = tilt * CFrame.new(0, 0.6, 0), Material = tier >= 6 and Enum.Material.Metal or Enum.Material.Wood, Color = color })
	part(m, { Size = Vector3.new(0.34, 1.2, 0.34), CFrame = tilt * CFrame.new(0, -1.9, 0), Material = Enum.Material.Fabric, Color = Color3.fromRGB(40, 40, 45) })
	part(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 0.8, 0.8), CFrame = tilt * CFrame.new(0.35, -1.1, 0), Material = Enum.Material.Metal, Color = Color3.fromRGB(200, 200, 210) })
	part(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.35, 0.35, 0.35), CFrame = tilt * CFrame.new(0, 2.95, 0),
		Material = tier >= 6 and Enum.Material.Neon or Enum.Material.SmoothPlastic, Color = tier >= 6 and color:Lerp(Color3.new(1, 1, 1), 0.4) or Color3.fromRGB(230, 60, 60) })
	local tipPos = (tilt * CFrame.new(0, 2.95, 0)).Position
	part(m, { Size = Vector3.new(0.04, 1.6, 0.04), CFrame = CFrame.new(tipPos + Vector3.new(0, -0.8, 0)), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(240, 240, 240) })
	part(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.45, 0.45, 0.45), CFrame = CFrame.new(tipPos + Vector3.new(0, -1.7, 0)), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(235, 50, 50) })
	return m
end

local FROM_ITEMS = { Palm = "PalmTree", Hut = "TikiHut", Stand = "CoconutStand", Treasure = "TreasurePile", Ship = "MiniShip", Crates = "CrateStack", Lighthouse = "Lighthouse" }
local FROM_CONTAINERS = { GoldenChest = "GoldenChest", Chest = "Chest", Crate = "Crate", Barrel = "Barrel", Bottle = "Bottle", Relic = "Relic" }

function Icons.Build(name: string): Model
	if BUILDERS[name] then return BUILDERS[name]() end
	local tier = name:match("^Rod:(%d+)$")
	if tier then return buildRod(tonumber(tier)) end
	if FROM_ITEMS[name] then return ItemVisuals.Build(FROM_ITEMS[name], "") end
	if FROM_CONTAINERS[name] then return ContainerVisuals.Build(FROM_CONTAINERS[name]) end
	return BUILDERS.Gift()
end

-- one loop spins every visible icon (cheaper than one loop per icon)
local spinning = {}
local started = false
local function startLoop()
	if started then return end
	started = true
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc < 1 / 30 then return end
		local step = acc
		acc = 0
		for vp, info in pairs(spinning) do
			if not vp.Parent then
				spinning[vp] = nil
			elseif vp.Visible and info.Model.Parent then
				info.Angle += step * info.Speed
				info.Model:PivotTo(info.Base * CFrame.Angles(0, info.Angle, 0))
			end
		end
	end)
end

-- 2D sprite sheet: 6x6 grid of 170px cells, each icon 160px at cell origin + 5
local SHEET = "rbxassetid://138008305464932"
local CELL, PAD, ICON = 170, 5, 160
local GRID = {
	{ "ChestGold", "ChestWood", "ChestShells", "Shell", "ShellBag", "Coin" },
	{ "Backpack", "BackpackPlus", "Island", "Hut", "Stall", "Book" },
	{ "Rebirth", "Clover", "Reel", "Crown", "FastForward", "Gift" },
	{ "Jar", "Glowbug", "Worm", "Shrimp", "Ship", "Lightning" },
	{ "AutoFish", "Trophy", "Lock", "Hook", "Rod1", "Rod2" },
	{ "Rod3", "Rod4", "Rod5", "Rod6", "Rod7", "Rod8" },
}
local SPRITES = {}
for row, names in ipairs(GRID) do
	for col, n in ipairs(names) do
		SPRITES[n] = Vector2.new((col - 1) * CELL + PAD, (row - 1) * CELL + PAD)
	end
end
-- older 3D names -> sprite names
local ALIAS = {
	GoldenChest = "ChestGold", Chest = "ChestShells", Treasure = "ShellBag", Crates = "Backpack",
	Palm = "Island", Stand = "Stall", Money = "Coin",
}

function Icons.SpriteName(name: string): string?
	local tier = name:match("^Rod:(%d+)$")
	if tier then name = "Rod" .. tier end
	name = ALIAS[name] or name
	return SPRITES[name] and name or nil
end

function Icons.Image(parent: GuiObject?, name: string, props)
	props = props or {}
	local sprite = Icons.SpriteName(name) or "Gift"
	local img = Instance.new("ImageLabel")
	img.Name = "Icon"
	img.BackgroundTransparency = 1
	img.Image = SHEET
	img.ImageRectOffset = SPRITES[sprite]
	img.ImageRectSize = Vector2.new(ICON, ICON)
	img.ScaleType = Enum.ScaleType.Fit
	img.Size = props.Size or UDim2.fromScale(1, 1)
	img.Position = props.Position or UDim2.new()
	img.AnchorPoint = props.AnchorPoint or Vector2.zero
	img.ZIndex = props.ZIndex or 1
	img:SetAttribute("Sprite", sprite)
	if parent then img.Parent = parent end
	return img
end

-- flat gear drawn with frames (matches the sprite sheet style)
function Icons.Gear(parent: GuiObject?, props)
	props = props or {}
	local root = Instance.new("Frame")
	root.Name = "Icon"
	root.BackgroundTransparency = 1
	root.Size = props.Size or UDim2.fromScale(1, 1)
	root.Position = props.Position or UDim2.new()
	root.AnchorPoint = props.AnchorPoint or Vector2.zero
	root.ZIndex = props.ZIndex or 1
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(0.8, 0.8)
	local ar = Instance.new("UIAspectRatioConstraint"); ar.Parent = holder
	holder.Parent = root
	local function shade(f)
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(Color3.fromRGB(235, 240, 250), Color3.fromRGB(150, 160, 185))
		g.Rotation = 90
		g.Parent = f
		local s = Instance.new("UIStroke"); s.Thickness = 3; s.Color = Color3.fromRGB(35, 30, 55); s.Parent = f
	end
	for i = 0, 3 do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.fromScale(0.24, 1)
		bar.Rotation = i * 45
		bar.BorderSizePixel = 0
		bar.ZIndex = root.ZIndex
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.2, 0); c.Parent = bar
		shade(bar)
		bar.Parent = holder
	end
	local body = Instance.new("Frame")
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromScale(0.5, 0.5)
	body.Size = UDim2.fromScale(0.74, 0.74)
	body.ZIndex = root.ZIndex + 1
	local c1 = Instance.new("UICorner"); c1.CornerRadius = UDim.new(0.5, 0); c1.Parent = body
	shade(body)
	body.Parent = holder
	local hole = Instance.new("Frame")
	hole.AnchorPoint = Vector2.new(0.5, 0.5)
	hole.Position = UDim2.fromScale(0.5, 0.5)
	hole.Size = UDim2.fromScale(0.3, 0.3)
	hole.BackgroundColor3 = Color3.fromRGB(70, 75, 110)
	hole.ZIndex = root.ZIndex + 2
	local c2 = Instance.new("UICorner"); c2.CornerRadius = UDim.new(0.5, 0); c2.Parent = hole
	local s2 = Instance.new("UIStroke"); s2.Thickness = 3; s2.Color = Color3.fromRGB(35, 30, 55); s2.Parent = hole
	hole.Parent = holder
	if parent then root.Parent = parent end
	return root
end

function Icons.Viewport(parent: GuiObject, name: string, props)
	props = props or {}
	if name == "Gear" then return Icons.Gear(parent, props) end
	if not props.Force3D and Icons.SpriteName(name) then
		return Icons.Image(parent, name, props)
	end
	local m = Icons.Build(name)
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Icon"
	vp.BackgroundTransparency = 1
	vp.Size = props.Size or UDim2.fromScale(1, 1)
	vp.Position = props.Position or UDim2.new()
	vp.AnchorPoint = props.AnchorPoint or Vector2.zero
	vp.ZIndex = props.ZIndex or 1
	vp.Ambient = Color3.fromRGB(210, 210, 215)
	vp.LightColor = Color3.new(1, 1, 1)
	vp.LightDirection = Vector3.new(-1, -1.5, -1)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 35
	cam.Parent = vp
	vp.CurrentCamera = cam
	m.Parent = vp
	-- move the model so its bounding box is centered on the origin (spins in place)
	local cf, size = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() - cf.Position)
	local radius = size.Magnitude / 2
	local dist = radius / math.tan(math.rad(cam.FieldOfView / 2)) * (props.Zoom or 1.05)
	local angle = props.Angle or math.rad(20)
	cam.CFrame = CFrame.lookAt(Vector3.new(0, math.sin(angle) * dist, -math.cos(angle) * dist), Vector3.zero)
	vp.Parent = parent
	if props.Spin ~= false then
		spinning[vp] = { Model = m, Base = m:GetPivot(), Speed = props.SpinSpeed or 0.8, Angle = 0 }
		startLoop()
	end
	return vp
end

return Icons
