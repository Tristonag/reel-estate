--[[
	NPCService
	Brings the hub shopkeepers (workspace.Map.NPCs) to life:
	- default Roblox idle animation, plus an occasional wave
	- a speech bubble that cycles through each keeper's lines (attribute "Lines", separated by |)
]]
local TweenService = game:GetService("TweenService")

local NPCService = {}

local IDLE = "rbxassetid://507766666"   -- Roblox default R15 idle
local WAVE = "rbxassetid://507770239"   -- Roblox default R15 wave

local function bubble(npcModel: Model)
	local head = npcModel:FindFirstChild("Head")
	if not head then return nil end
	local bb = Instance.new("BillboardGui")
	bb.Name = "Bubble"
	bb.Size = UDim2.new(0, 230, 0, 54)
	bb.StudsOffset = Vector3.new(0, 2.6, 0)
	bb.MaxDistance = 45
	bb.AlwaysOnTop = true -- the stall canopy would hide it otherwise
	bb.LightInfluence = 0
	local frame = Instance.new("Frame")
	frame.Name = "Frame"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 14); c.Parent = frame
	local s = Instance.new("UIStroke"); s.Thickness = 2.5; s.Color = Color3.fromRGB(40, 30, 60); s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = frame
	local scale = Instance.new("UIScale"); scale.Parent = frame
	frame.Parent = bb
	local name = Instance.new("TextLabel")
	name.Name = "NameTag"
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, -14, 0.36, 0)
	name.Position = UDim2.new(0, 7, 0.06, 0)
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextColor3 = Color3.fromRGB(230, 120, 40)
	name.Text = npcModel.Name
	name.Parent = frame
	local text = Instance.new("TextLabel")
	text.Name = "Line"
	text.BackgroundTransparency = 1
	text.Size = UDim2.new(1, -14, 0.5, 0)
	text.Position = UDim2.new(0, 7, 0.44, 0)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextColor3 = Color3.fromRGB(40, 30, 60)
	text.Parent = frame
	bb.Parent = head
	return bb
end

local function animate(npcModel: Model)
	local hum = npcModel:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local idleAnim = Instance.new("Animation"); idleAnim.AnimationId = IDLE
	local waveAnim = Instance.new("Animation"); waveAnim.AnimationId = WAVE
	local ok, idle = pcall(function() return animator:LoadAnimation(idleAnim) end)
	if ok and idle then idle.Looped = true; idle:Play() end
	local ok2, wave = pcall(function() return animator:LoadAnimation(waveAnim) end)

	local lines = string.split(npcModel:GetAttribute("Lines") or "", "|")
	local bb = bubble(npcModel)
	if not bb then return end
	local frame = bb.Frame
	local i = math.random(1, math.max(1, #lines))
	task.spawn(function()
		task.wait(math.random() * 4)
		while npcModel.Parent do
			frame.Line.Text = lines[i] or ""
			bb.Enabled = true
			frame.UIScale.Scale = 0.5
			TweenService:Create(frame.UIScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			if ok2 and wave and math.random() < 0.35 then wave:Play() end
			task.wait(5)
			bb.Enabled = false
			task.wait(2 + math.random() * 3)
			i = (i % #lines) + 1
		end
	end)
end

function NPCService.Start()
	local map = workspace:WaitForChild("Map", 10)
	local folder = map and map:FindFirstChild("NPCs")
	if not folder then return end
	for _, m in ipairs(folder:GetChildren()) do task.spawn(animate, m) end
end

return NPCService
