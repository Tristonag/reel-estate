--[[
	ContainerVisuals.Build(containerId) -> Model (PrimaryPart = "Body")

	If ReplicatedStorage.Assets.Containers.<containerId> exists (a Model with a
	PrimaryPart), that is cloned. Otherwise a placeholder is built from parts.
	So Phase 5 just drops real meshes into that folder, no code changes.
]]
local Assets = game.ReplicatedStorage:WaitForChild("Assets")

local ContainerVisuals = {}

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	return p
end

local function glow(body: BasePart, color: Color3, range: number, sparkle: boolean)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = 1.5
	light.Parent = body
	if sparkle then
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Color = ColorSequence.new(color)
		pe.Rate = 6
		pe.Lifetime = NumberRange.new(0.8, 1.4)
		pe.Speed = NumberRange.new(1, 2)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		pe.LightEmission = 1
		pe.Parent = body
	end
end

local builders = {}

builders.Crate = function(m)
	local body = part({ Name = "Body", Size = Vector3.new(3, 3, 3), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(150, 105, 60) })
	body.Parent = m
	local band = part({ Name = "Band", Size = Vector3.new(3.1, 0.4, 3.1), Material = Enum.Material.Wood, Color = Color3.fromRGB(95, 65, 35) })
	band.Parent = m
	return body, { band = CFrame.new(0, 0, 0) }
end

builders.Barrel = function(m)
	local body = part({ Name = "Body", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.4, 2.8, 2.8), Material = Enum.Material.Wood, Color = Color3.fromRGB(140, 90, 50) })
	body.Parent = m
	local r1 = part({ Name = "Ring1", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2.95, 2.95), Material = Enum.Material.Metal, Color = Color3.fromRGB(80, 80, 85) })
	local r2 = r1:Clone(); r2.Name = "Ring2"
	r1.Parent = m; r2.Parent = m
	-- barrel lies on its side, floating
	return body, { Ring1 = CFrame.new(1, 0, 0), Ring2 = CFrame.new(-1, 0, 0) }
end

builders.Bottle = function(m)
	local body = part({ Name = "Body", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 1.2, 1.2), Material = Enum.Material.Glass, Color = Color3.fromRGB(120, 220, 170), Transparency = 0.35 })
	body.Parent = m
	local neck = part({ Name = "Neck", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 0.55, 0.55), Material = Enum.Material.Glass, Color = Color3.fromRGB(120, 220, 170), Transparency = 0.35 })
	local cork = part({ Name = "Cork", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, 0.5, 0.5), Material = Enum.Material.Wood, Color = Color3.fromRGB(190, 150, 100) })
	local note = part({ Name = "Note", Size = Vector3.new(1.4, 0.6, 0.1), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(245, 230, 190) })
	neck.Parent = m; cork.Parent = m; note.Parent = m
	glow(body, Color3.fromRGB(140, 255, 200), 8, false)
	return body, { Neck = CFrame.new(1.5, 0, 0), Cork = CFrame.new(2.05, 0, 0), Note = CFrame.new(0, 0, 0) }
end

local function chest(m, woodColor, trimColor, trimMat)
	local body = part({ Name = "Body", Size = Vector3.new(3.6, 2.2, 2.4), Material = Enum.Material.WoodPlanks, Color = woodColor })
	body.Parent = m
	local lid = part({ Name = "Lid", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.6, 2.4, 2.4), Material = Enum.Material.WoodPlanks, Color = woodColor })
	local t1 = part({ Name = "Trim1", Size = Vector3.new(0.35, 2.3, 2.5), Material = trimMat, Color = trimColor })
	local t2 = t1:Clone(); t2.Name = "Trim2"
	local lock = part({ Name = "Lock", Size = Vector3.new(0.6, 0.7, 0.2), Material = trimMat, Color = trimColor })
	lid.Parent = m; t1.Parent = m; t2.Parent = m; lock.Parent = m
	return body, { Lid = CFrame.new(0, 1.1, 0), Trim1 = CFrame.new(1.2, 0.2, 0), Trim2 = CFrame.new(-1.2, 0.2, 0), Lock = CFrame.new(0, 0.6, -1.25) }
end

builders.Chest = function(m)
	local body, offs = chest(m, Color3.fromRGB(120, 75, 40), Color3.fromRGB(210, 170, 60), Enum.Material.Metal)
	glow(body, Color3.fromRGB(255, 210, 120), 10, false)
	return body, offs
end

builders.GoldenChest = function(m)
	local body, offs = chest(m, Color3.fromRGB(240, 190, 50), Color3.fromRGB(255, 245, 200), Enum.Material.Neon)
	body.Material = Enum.Material.Metal
	m.Lid.Material = Enum.Material.Metal
	m.Lid.Color = Color3.fromRGB(240, 190, 50)
	glow(body, Color3.fromRGB(255, 210, 80), 16, true)
	return body, offs
end

builders.Relic = function(m)
	local body = part({ Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 2.4, 2.4), Material = Enum.Material.Neon, Color = Color3.fromRGB(200, 90, 255) })
	body.Parent = m
	local ring = part({ Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 4, 4), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 120, 200), Transparency = 0.3 })
	ring.Parent = m
	glow(body, Color3.fromRGB(220, 100, 255), 20, true)
	return body, { Ring = CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(math.rad(20), 0, 0) }
end

function ContainerVisuals.Build(containerId: string): Model
	local custom = Assets.Containers:FindFirstChild(containerId)
	if custom and custom:IsA("Model") and custom.PrimaryPart then
		local m = custom:Clone()
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false; d.CanTouch = false end
		end
		return m
	end

	local m = Instance.new("Model")
	m.Name = containerId
	local builder = builders[containerId] or builders.Crate
	local body, offsets = builder(m)
	m.PrimaryPart = body
	-- lay out child parts relative to Body at the origin
	body.CFrame = CFrame.new()
	for name, off in pairs(offsets) do
		local p = m:FindFirstChild(name)
		if p then
			p.CFrame = off
		end
	end
	return m
end

return ContainerVisuals
