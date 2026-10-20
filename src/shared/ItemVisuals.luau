--[[
	ItemVisuals.Build(itemId, variant?) -> Model (PrimaryPart = "Body", anchored, pivot at the bottom center)

	Uses ReplicatedStorage.Assets.Items.<itemId> if present (Phase 5 drops real
	models there). Otherwise builds a placeholder shaped by the item's set and
	colored by rarity. Variants (Shiny/Golden/Rainbow) are applied as effects on
	top of any model, real or placeholder.
]]
local Config = require(script.Parent.Config)
local Assets = game.ReplicatedStorage:WaitForChild("Assets")

local ItemVisuals = {}

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	return p
end

local SET_SHAPES = {
	Castaway = function(m, color)
		local b = part({ Name = "Body", Size = Vector3.new(3, 3, 3), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(160, 115, 70) })
		b.CFrame = CFrame.new(0, 1.5, 0)
		local stripe = part({ Name = "Stripe", Size = Vector3.new(3.1, 0.5, 3.1), Material = Enum.Material.SmoothPlastic, Color = color })
		stripe.CFrame = CFrame.new(0, 1.5, 0)
		b.Parent = m; stripe.Parent = m
		return b
	end,
	Tropical = function(m, color)
		local trunk = part({ Name = "Body", Size = Vector3.new(0.8, 5, 0.8), Material = Enum.Material.Wood, Color = Color3.fromRGB(140, 100, 60) })
		trunk.CFrame = CFrame.new(0, 2.5, 0)
		local top = part({ Name = "Top", Shape = Enum.PartType.Ball, Size = Vector3.new(3.5, 3.5, 3.5), Material = Enum.Material.Grass, Color = color })
		top.CFrame = CFrame.new(0, 5.2, 0)
		trunk.Parent = m; top.Parent = m
		return trunk
	end,
	Pirate = function(m, color)
		local b = part({ Name = "Body", Size = Vector3.new(3.2, 2.4, 2.4), Material = Enum.Material.Wood, Color = Color3.fromRGB(90, 60, 35) })
		b.CFrame = CFrame.new(0, 1.2, 0)
		local flag = part({ Name = "Flag", Size = Vector3.new(0.2, 2.4, 2), Material = Enum.Material.Fabric, Color = color })
		flag.CFrame = CFrame.new(0, 3.6, 0)
		b.Parent = m; flag.Parent = m
		return b
	end,
	Wonders = function(m, color)
		local b = part({ Name = "Body", Size = Vector3.new(2.6, 6, 2.6), Material = Enum.Material.Marble, Color = Color3.fromRGB(235, 230, 220) })
		b.CFrame = CFrame.new(0, 3, 0)
		local cap = part({ Name = "Cap", Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 2.2, 2.2), Material = Enum.Material.Neon, Color = color })
		cap.CFrame = CFrame.new(0, 6.6, 0)
		b.Parent = m; cap.Parent = m
		return b
	end,
	Pets = function(m, color)
		local b = part({ Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(2.6, 2.6, 2.6), Material = Enum.Material.SmoothPlastic, Color = color })
		b.CFrame = CFrame.new(0, 1.3, 0)
		local e1 = part({ Name = "EyeL", Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5), Material = Enum.Material.SmoothPlastic, Color = Color3.new(0.05, 0.05, 0.05) })
		local e2 = e1:Clone(); e2.Name = "EyeR"
		e1.CFrame = CFrame.new(-0.5, 1.7, -1.1); e2.CFrame = CFrame.new(0.5, 1.7, -1.1)
		b.Parent = m; e1.Parent = m; e2.Parent = m
		return b
	end,
}

-- Visual effect layered on any model for variants.
function ItemVisuals.ApplyVariant(model: Model, variant: string)
	if variant == "" or not model.PrimaryPart then return end
	local body = model.PrimaryPart
	if variant == "Golden" then
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("SurfaceAppearance") then
				d:Destroy()
			elseif d:IsA("MeshPart") then
				d.TextureID = "" -- textured meshes ignore Color otherwise
			end
			if d:IsA("BasePart") then d.Color = Color3.fromRGB(255, 205, 60); d.Material = Enum.Material.Metal end
		end
	elseif variant == "Rainbow" then
		local h = Instance.new("Highlight")
		h.FillColor = Color3.fromRGB(255, 80, 200)
		h.FillTransparency = 0.6
		h.OutlineColor = Color3.fromRGB(120, 255, 255)
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = model
		model:SetAttribute("Rainbow", true) -- client can cycle colors
	end
	if variant == "Shiny" or variant == "Golden" or variant == "Rainbow" then
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Color = ColorSequence.new(variant == "Golden" and Color3.fromRGB(255, 220, 120) or Color3.fromRGB(255, 255, 255))
		pe.Rate = 8
		pe.Lifetime = NumberRange.new(0.8, 1.2)
		pe.Speed = NumberRange.new(0.5, 1.5)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.LightEmission = 1
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
		pe.Parent = body
	end
end

function ItemVisuals.Build(itemId: string, variant: string?): Model
	local item = Config.Items[itemId]
	local custom = Assets.Items:FindFirstChild(itemId)
	local m
	if custom and custom:IsA("Model") and custom.PrimaryPart then
		m = custom:Clone()
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then d.Anchored = true end
		end
	else
		m = Instance.new("Model")
		m.Name = itemId
		local color = item and Config.Rarities[item.Rarity].Color or Color3.new(1, 1, 1)
		local builder = item and SET_SHAPES[item.Set] or SET_SHAPES.Castaway
		m.PrimaryPart = builder(m, color)
		-- pivot at bottom center so it sits on the ground when placed
		-- (with a PrimaryPart the pivot comes from PivotOffset; WorldPivot would be ignored)
		m.PrimaryPart.PivotOffset = m.PrimaryPart.CFrame:ToObjectSpace(CFrame.new(0, 0, 0))
	end
	ItemVisuals.ApplyVariant(m, variant or "")
	return m
end

return ItemVisuals
