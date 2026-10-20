--[[
	Ambience (client only, costs nothing on the server)
	- a few seagulls circling lazily over the hub and the ocean
	- fish that occasionally jump out of the water near you
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Ambience = {}

local gulls = {}

local function makeGull(): Model?
	local src = game.ReplicatedStorage.Assets.Items:FindFirstChild("Seagull")
	if not src then return nil end
	local m = src:Clone()
	m:ScaleTo(m:GetScale() * 1.3)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false; d.CanQuery = false; d.CanTouch = false; d.CastShadow = false end
	end
	m.Parent = workspace.CurrentCamera
	return m
end

local function jumpFish()
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local a = math.random() * math.pi * 2
	local r = 20 + math.random() * 35
	local start = Vector3.new(hrp.Position.X + math.cos(a) * r, 0, hrp.Position.Z + math.sin(a) * r)
	local dir = Vector3.new(math.cos(a + 1.3), 0, math.sin(a + 1.3))
	local fish = Instance.new("Part")
	fish.Anchored = true; fish.CanCollide = false; fish.CanQuery = false; fish.CanTouch = false
	fish.Size = Vector3.new(0.6, 0.9, 1.8)
	fish.Material = Enum.Material.SmoothPlastic
	local colors = { Color3.fromRGB(255, 170, 70), Color3.fromRGB(120, 200, 255), Color3.fromRGB(255, 120, 160), Color3.fromRGB(190, 190, 200) }
	fish.Color = colors[math.random(1, #colors)]
	local tail = Instance.new("Part")
	tail.Anchored = true; tail.CanCollide = false; tail.CanQuery = false; tail.CanTouch = false
	tail.Size = Vector3.new(0.15, 0.9, 0.6)
	tail.Color = fish.Color
	fish.Parent = workspace.CurrentCamera
	tail.Parent = workspace.CurrentCamera
	local t0 = os.clock()
	local dur = 0.9
	while os.clock() - t0 < dur do
		local t = (os.clock() - t0) / dur
		local pos = start + dir * (t * 6) + Vector3.new(0, math.sin(t * math.pi) * 4 - 0.3, 0)
		local vel = dir * 6 + Vector3.new(0, math.cos(t * math.pi) * 4 * math.pi, 0)
		local cf = CFrame.lookAt(pos, pos + vel)
		fish.CFrame = cf
		tail.CFrame = cf * CFrame.new(0, 0, 1.1)
		RunService.RenderStepped:Wait()
	end
	fish:Destroy()
	tail:Destroy()
end

function Ambience.Start()
	-- seagulls: each circles its own center at its own height and speed
	local centers = { Vector3.new(0, 38, 0), Vector3.new(0, 45, 0), Vector3.new(120, 42, 90), Vector3.new(-140, 40, -60), Vector3.new(60, 48, -150) }
	for i, c in ipairs(centers) do
		local m = makeGull()
		if m then table.insert(gulls, { Model = m, Center = c, Radius = 30 + i * 8, Speed = 0.25 + i * 0.04, Phase = i * 1.7 }) end
	end
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for _, g in ipairs(gulls) do
			local a = t * g.Speed + g.Phase
			local pos = g.Center + Vector3.new(math.cos(a) * g.Radius, math.sin(t * 0.7 + g.Phase) * 2, math.sin(a) * g.Radius)
			local ahead = g.Center + Vector3.new(math.cos(a + 0.1) * g.Radius, 0, math.sin(a + 0.1) * g.Radius)
			g.Model:PivotTo(CFrame.lookAt(pos, Vector3.new(ahead.X, pos.Y, ahead.Z)) * CFrame.Angles(0, 0, math.rad(-18)))
		end
	end)
	-- fish jumps every few seconds
	task.spawn(function()
		while true do
			task.wait(3 + math.random() * 5)
			task.spawn(jumpFish)
		end
	end)
end

return Ambience
