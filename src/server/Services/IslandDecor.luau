--[[
	IslandDecor.Build(plotModel, plotIndex, stage)
	Visual dressing around an island, different for every stage so each upgrade feels big:
		1 Raft      log edges, barrels, a little mast with a sail
		2 Sandbar   beach ring, shells, rocks, driftwood
		3 Islet     beach ring, corner palms, rocks, a fishing dock
		4 Island    + flowers, fence, lanterns
		5 Paradise  + glowing torches, entrance arch, waterfall rocks, rope dock
		6 Royal     + royal banners, golden statues at the gate, gold lanterns
		7 Atoll     + lighthouse, a ring of little rock islets, golden sparkles
	Everything is decoration only (CanCollide off) except the beach ring and the dock, which you can walk on.
]]
local Config = require(game.ReplicatedStorage.Shared.Config)
local IslandGrid = require(game.ReplicatedStorage.Shared.IslandGrid)

local IslandDecor = {}
local Items = game.ReplicatedStorage.Assets.Items
local Containers = game.ReplicatedStorage.Assets.Containers
local TOP = IslandGrid.TopY - Config.World.WaterLevel -- 1
local BEACH = 4
local rng = Random.new()

local WOOD = Color3.fromRGB(150, 100, 58)
local DARK = Color3.fromRGB(95, 62, 35)
local SAND = Color3.fromRGB(214, 184, 128) -- wet sand, darker than the dry island top

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = true
	for k, v in pairs(props) do p[k] = v end
	p.Parent = parent
	return p
end

-- local frame helper: ox = right, oz = outward (towards open sea), y = height above water
local function at(plotCF: CFrame, ox: number, y: number, oz: number): CFrame
	return plotCF * CFrame.new(ox, y, -oz)
end

local function place(parent, src: Instance?, cf: CFrame, scale: number?)
	if not src then return nil end
	local m = src:Clone()
	if scale and scale ~= 1 then m:ScaleTo(m:GetScale() * scale) end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false; d.CanTouch = false; d.CanQuery = false end
	end
	m:PivotTo(cf)
	m.Parent = parent
	return m
end

local function beachRing(folder, plotCF, mn, mx)
	-- four strips around the tiles, top a little below the island so it reads as a shore
	local w = mx - mn
	local y = TOP - 0.9
	local h = 3
	part(folder, { Name = "Beach", Size = Vector3.new(w + BEACH * 2, h, BEACH), CFrame = at(plotCF, (mn + mx) / 2, y - h / 2, mx + BEACH / 2), Material = Enum.Material.Sand, Color = SAND })
	part(folder, { Name = "Beach", Size = Vector3.new(w + BEACH * 2, h, BEACH), CFrame = at(plotCF, (mn + mx) / 2, y - h / 2, mn - BEACH / 2), Material = Enum.Material.Sand, Color = SAND })
	part(folder, { Name = "Beach", Size = Vector3.new(BEACH, h, w), CFrame = at(plotCF, mx + BEACH / 2, y - h / 2, (mn + mx) / 2), Material = Enum.Material.Sand, Color = SAND })
	part(folder, { Name = "Beach", Size = Vector3.new(BEACH, h, w), CFrame = at(plotCF, mn - BEACH / 2, y - h / 2, (mn + mx) / 2), Material = Enum.Material.Sand, Color = SAND })
end

local function dock(folder, plotCF, mn, mx, fancy: boolean)
	local len, width = 12, 5
	local startZ = mx + (fancy ~= nil and BEACH or 0)
	local cx = (mn + mx) / 2
	part(folder, { Name = "Dock", Size = Vector3.new(width, 0.5, len), CFrame = at(plotCF, cx, TOP - 0.4, startZ + len / 2),
		Material = Enum.Material.WoodPlanks, Color = WOOD })
	for _, sx in ipairs({ -1, 1 }) do
		for i = 0, 2 do
			part(folder, { Name = "DockPost", Size = Vector3.new(0.6, 5, 0.6), CFrame = at(plotCF, cx + sx * (width / 2 - 0.3), TOP - 2.4 + (fancy and 1.2 or 0), startZ + 2 + i * 4.5),
				Material = Enum.Material.Wood, Color = DARK, CanCollide = false })
		end
		if fancy then
			part(folder, { Name = "Rope", Size = Vector3.new(0.18, 0.18, len - 2), CFrame = at(plotCF, cx + sx * (width / 2 - 0.3), TOP + 1.3, startZ + len / 2 + 0.5),
				Material = Enum.Material.Fabric, Color = Color3.fromRGB(215, 190, 140), CanCollide = false })
		end
	end
end

local function lantern(folder, cf: CFrame, color: Color3)
	part(folder, { Name = "LanternPost", Size = Vector3.new(0.4, 5, 0.4), CFrame = cf * CFrame.new(0, 2.5, 0), Material = Enum.Material.Wood, Color = DARK, CanCollide = false })
	local lamp = part(folder, { Name = "Lamp", Shape = Enum.PartType.Ball, Size = Vector3.new(1.3, 1.3, 1.3), CFrame = cf * CFrame.new(0, 5.4, 0),
		Material = Enum.Material.Neon, Color = color, CanCollide = false })
	local l = Instance.new("PointLight"); l.Color = color; l.Range = 14; l.Brightness = 1.4; l.Parent = lamp
end

local function scatter(folder, plotCF, mn, mx, count: number, builder)
	for i = 1, count do
		local side = rng:NextInteger(1, 4)
		local t = rng:NextNumber(mn + 2, mx - 2)
		local off = rng:NextNumber(1, BEACH - 1)
		local ox, oz
		if side == 1 then ox, oz = t, mx + off
		elseif side == 2 then ox, oz = t, mn - off
		elseif side == 3 then ox, oz = mx + off, t
		else ox, oz = mn - off, t end
		builder(at(plotCF, ox, TOP - 0.9, oz), i)
	end
end

local function shells(folder, plotCF, mn, mx, n)
	scatter(folder, plotCF, mn, mx, n, function(cf, i)
		local colors = { Color3.fromRGB(255, 190, 200), Color3.fromRGB(255, 240, 220), Color3.fromRGB(255, 170, 120) }
		part(folder, { Name = "Shell", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.5, 0.9), CFrame = cf * CFrame.new(0, 0.15, 0),
			Material = Enum.Material.SmoothPlastic, Color = colors[(i % 3) + 1], CanCollide = false })
	end)
end

local function rocks(folder, plotCF, mn, mx, n)
	scatter(folder, plotCF, mn, mx, n, function(cf)
		local s = rng:NextNumber(1.4, 2.6)
		part(folder, { Name = "Rock", Shape = Enum.PartType.Ball, Size = Vector3.new(s * 1.3, s, s), CFrame = cf * CFrame.new(0, s * 0.25, 0) * CFrame.Angles(0, rng:NextNumber(0, 6), 0),
			Material = Enum.Material.Slate, Color = Color3.fromRGB(130, 128, 125), CanCollide = false })
	end)
end

local function flowers(folder, plotCF, mn, mx, n)
	scatter(folder, plotCF, mn, mx, n, function(cf, i)
		local colors = { Color3.fromRGB(255, 90, 140), Color3.fromRGB(255, 220, 80), Color3.fromRGB(170, 110, 255), Color3.fromRGB(255, 255, 255) }
		part(folder, { Name = "Stem", Size = Vector3.new(0.15, 1.2, 0.15), CFrame = cf * CFrame.new(0, 0.6, 0), Material = Enum.Material.Grass, Color = Color3.fromRGB(80, 160, 60), CanCollide = false })
		part(folder, { Name = "Bloom", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8), CFrame = cf * CFrame.new(0, 1.3, 0),
			Material = Enum.Material.SmoothPlastic, Color = colors[(i % 4) + 1], CanCollide = false })
	end)
end

function IslandDecor.Build(plotModel: Model, plot: number, stage: number)
	local old = plotModel:FindFirstChild("Decor")
	if old then old:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "Decor"
	local plotCF = IslandGrid.PlotCFrame(plot)
	local mn, mx = IslandGrid.Bounds(stage)
	local corners = { { mn - 2, mn - 2 }, { mx + 2, mn - 2 }, { mn - 2, mx + 2 }, { mx + 2, mx + 2 } }

	if stage == 1 then
		-- raft: log edges, barrels, mast + sail
		for _, side in ipairs({ mn - 0.6, mx + 0.6 }) do
			part(folder, { Name = "Log", Shape = Enum.PartType.Cylinder, Size = Vector3.new(mx - mn + 1.6, 1.4, 1.4),
				CFrame = at(plotCF, (mn + mx) / 2, TOP - 0.4, side), Material = Enum.Material.Wood, Color = DARK, CanCollide = false })
			part(folder, { Name = "Log", Shape = Enum.PartType.Cylinder, Size = Vector3.new(mx - mn + 1.6, 1.4, 1.4),
				CFrame = at(plotCF, side, TOP - 0.4, (mn + mx) / 2) * CFrame.Angles(0, math.rad(90), 0), Material = Enum.Material.Wood, Color = DARK, CanCollide = false })
		end
		place(folder, Containers:FindFirstChild("Barrel"), at(plotCF, mn + 1.6, TOP + 1.2, mn + 1.6) * CFrame.Angles(0, 0, math.rad(90)), 0.8)
		place(folder, Containers:FindFirstChild("Crate"), at(plotCF, mx - 1.6, TOP + 1.2, mn + 1.6), 0.8)
		part(folder, { Name = "Mast", Size = Vector3.new(0.4, 9, 0.4), CFrame = at(plotCF, mn + 1, TOP + 4.5, mx - 1), Material = Enum.Material.Wood, Color = DARK, CanCollide = false })
		part(folder, { Name = "Sail", Size = Vector3.new(0.1, 4.5, 4), CFrame = at(plotCF, mn + 1.2, TOP + 5.5, mx - 3), Material = Enum.Material.Fabric, Color = Color3.fromRGB(245, 235, 210), CanCollide = false })
	else
		beachRing(folder, plotCF, mn, mx)
		shells(folder, plotCF, mn, mx, 6 + stage * 2)
		rocks(folder, plotCF, mn, mx, 2 + stage)
	end

	if stage == 2 then
		part(folder, { Name = "Driftwood", Shape = Enum.PartType.Cylinder, Size = Vector3.new(6, 0.9, 0.9),
			CFrame = at(plotCF, mx + 2, TOP - 0.3, (mn + mx) / 2) * CFrame.Angles(0, math.rad(70), 0), Material = Enum.Material.Wood, Color = Color3.fromRGB(170, 150, 120), CanCollide = false })
		place(folder, Items:FindFirstChild("PalmTree"), at(plotCF, mn - 2, TOP - 0.9, mn - 2), 1.1)
	end

	if stage >= 3 then
		for i, c in ipairs(corners) do
			place(folder, Items:FindFirstChild("PalmTree"), at(plotCF, c[1], TOP - 0.9, c[2]) * CFrame.Angles(0, i * 1.3, 0), 1.2 + (i % 2) * 0.25)
		end
		dock(folder, plotCF, mn, mx, stage >= 5)
	end

	if stage >= 4 then
		flowers(folder, plotCF, mn, mx, 14)
		for i, c in ipairs(corners) do
			local inset = 3.2
			local ox = c[1] + (c[1] < 0 and inset or -inset)
			local oz = c[2] + (c[2] < 0 and inset or -inset)
			lantern(folder, at(plotCF, ox, TOP - 0.9, oz), stage >= 6 and Color3.fromRGB(255, 210, 60) or stage >= 5 and Color3.fromRGB(255, 190, 90) or Color3.fromRGB(255, 230, 160))
		end
		-- low fence along the back edge (towards the hub), with a gap for the boardwalk
		local cx = (mn + mx) / 2
		for ox = mn, mx, 2 do
			if math.abs(ox - cx) > 4 then
				part(folder, { Name = "Fence", Size = Vector3.new(0.35, 1.8, 0.35), CFrame = at(plotCF, ox, TOP - 0.1, mn - BEACH + 0.6), Material = Enum.Material.Wood, Color = Color3.fromRGB(235, 225, 205), CanCollide = false })
			end
		end
		part(folder, { Name = "FenceRail", Size = Vector3.new((mx - mn) / 2 - 4, 0.25, 0.25), CFrame = at(plotCF, (mn + cx - 4) / 2, TOP + 0.4, mn - BEACH + 0.6), Material = Enum.Material.Wood, Color = Color3.fromRGB(235, 225, 205), CanCollide = false })
		part(folder, { Name = "FenceRail", Size = Vector3.new((mx - mn) / 2 - 4, 0.25, 0.25), CFrame = at(plotCF, (mx + cx + 4) / 2, TOP + 0.4, mn - BEACH + 0.6), Material = Enum.Material.Wood, Color = Color3.fromRGB(235, 225, 205), CanCollide = false })
	end

	if stage >= 5 then
		-- entrance arch over the boardwalk + torches + waterfall rocks at the outer corners
		local cx = (mn + mx) / 2
		local archZ = mn - BEACH + 0.6
		for _, sx in ipairs({ -1, 1 }) do
			part(folder, { Name = "ArchPost", Size = Vector3.new(1, 11, 1), CFrame = at(plotCF, cx + sx * 4, TOP + 4.6, archZ), Material = Enum.Material.Wood, Color = DARK, CanCollide = false })
			place(folder, Items:FindFirstChild("Torch"), at(plotCF, cx + sx * 6, TOP - 0.9, archZ + 1), 1.3)
		end
		part(folder, { Name = "ArchTop", Size = Vector3.new(11, 1.6, 1.2), CFrame = at(plotCF, cx, TOP + 10.5, archZ), Material = Enum.Material.Wood, Color = WOOD, CanCollide = false })
		place(folder, Items:FindFirstChild("WaterfallRock"), at(plotCF, mn - 1, TOP - 0.9, mx + 1) * CFrame.Angles(0, math.rad(45), 0), 1.2)
		place(folder, Items:FindFirstChild("WaterfallRock"), at(plotCF, mx + 1, TOP - 0.9, mx + 1) * CFrame.Angles(0, math.rad(-45), 0), 1.2)
		local n = math.floor((mx - mn) / 8)
		for i = 1, n do
			local a = (i / n) * (mx - mn)
			place(folder, Items:FindFirstChild("Torch"), at(plotCF, mn + a - (mx - mn) / (2 * n), TOP - 0.9, mx + BEACH - 0.8), 1)
		end
	end

	if stage >= 6 then
		local cx = (mn + mx) / 2
		local archZ = mn - BEACH + 0.6
		local GOLD = Color3.fromRGB(255, 200, 60)
		local ROYAL = Color3.fromRGB(120, 50, 190)
		-- gold crown gem on the arch
		part(folder, { Name = "ArchGem", Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), CFrame = at(plotCF, cx, TOP + 12.2, archZ),
			Material = Enum.Material.Neon, Color = GOLD, CanCollide = false })
		-- golden statues guarding the gate
		for _, sx in ipairs({ -1, 1 }) do
			place(folder, Items:FindFirstChild("GoldenStatue"), at(plotCF, cx + sx * 9, TOP - 0.9, archZ - 0.5) * CFrame.Angles(0, math.pi, 0), 1.1)
		end
		-- banners on the four corners
		for _, c in ipairs(corners) do
			local ox = c[1] + (c[1] < 0 and 1 or -1)
			local oz = c[2] + (c[2] < 0 and 1 or -1)
			local base = at(plotCF, ox, TOP - 0.9, oz)
			part(folder, { Name = "BannerPole", Size = Vector3.new(0.5, 12, 0.5), CFrame = base * CFrame.new(0, 6, 0), Material = Enum.Material.Metal, Color = GOLD, CanCollide = false })
			part(folder, { Name = "Banner", Size = Vector3.new(3.2, 4.5, 0.15), CFrame = base * CFrame.new(1.8, 9, 0), Material = Enum.Material.Fabric, Color = ROYAL, CanCollide = false })
			part(folder, { Name = "BannerTrim", Size = Vector3.new(3.2, 0.5, 0.2), CFrame = base * CFrame.new(1.8, 6.6, 0), Material = Enum.Material.Metal, Color = GOLD, CanCollide = false })
			part(folder, { Name = "BannerTop", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9), CFrame = base * CFrame.new(0, 12.3, 0), Material = Enum.Material.Neon, Color = GOLD, CanCollide = false })
		end
	end

	if stage >= 7 then
		-- lighthouse on its own rock off the outer-left corner
		local lx, lz = mn - 7, mx + 7
		part(folder, { Name = "LighthouseRock", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 9, 9),
			CFrame = at(plotCF, lx, TOP - 2.5, lz) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Slate, Color = Color3.fromRGB(120, 118, 115), CanCollide = false })
		place(folder, Items:FindFirstChild("Lighthouse"), at(plotCF, lx, TOP - 0.5, lz), 1.6)
		-- ring of little rock islets in the lagoon (not on the hub side)
		local r = (mx - mn) / 2 + BEACH + 9
		local cx = (mn + mx) / 2
		for i = 0, 9 do
			local a = math.rad(-20 + i * 22)
			local ox, oz = cx + math.cos(a) * r, (mn + mx) / 2 + math.sin(a) * r
			if oz > mn then
				local s = rng:NextNumber(2.5, 4.5)
				part(folder, { Name = "Islet", Shape = Enum.PartType.Ball, Size = Vector3.new(s * 1.6, s, s * 1.4),
					CFrame = at(plotCF, ox, TOP - 1.8, oz) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Material = Enum.Material.Sand, Color = SAND, CanCollide = false })
				if i % 3 == 0 then
					place(folder, Items:FindFirstChild("PalmTree"), at(plotCF, ox, TOP - 1.4 + s * 0.3, oz) * CFrame.Angles(0, i, 0), 0.9)
				end
			end
		end
		-- golden sparkles over the whole island
		local glow = part(folder, { Name = "Sparkles", Size = Vector3.new(mx - mn, 1, mx - mn), CFrame = at(plotCF, cx, TOP + 6, (mn + mx) / 2),
			Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Color = ColorSequence.new(Color3.fromRGB(255, 225, 120))
		pe.LightEmission = 1
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.6), NumberSequenceKeypoint.new(1, 0) })
		pe.Lifetime = NumberRange.new(2, 3.5)
		pe.Rate = 12
		pe.Speed = NumberRange.new(0.5, 1.5)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Parent = glow
	end

	folder.Parent = plotModel
end

return IslandDecor
