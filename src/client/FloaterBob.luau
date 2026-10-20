-- Visual-only bobbing and slow spin for floating containers near the camera.
-- The server's position is the truth; this just makes them feel alive.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local FloaterBob = {}

local tracked: { [Model]: { Base: CFrame, Phase: number, Spin: number, Offset: Vector3 } } = {}
local MAX_DIST = 320

local function add(model: Instance)
	if not model:IsA("Model") then return end
	-- wait for the primary part to stream in
	task.spawn(function()
		local t = 0
		while not model.PrimaryPart and t < 5 and model.Parent do t += task.wait(0.1) end
		if not model.PrimaryPart or not model.Parent then return end
		tracked[model] = { Base = model:GetPivot(), Phase = math.random() * math.pi * 2, Spin = (math.random() - 0.5) * 0.3, Offset = Vector3.zero }
	end)
end

function FloaterBob.GetBase(model: Model): CFrame?
	local t = tracked[model]
	return t and t.Base or nil
end

-- Push a floater visually (e.g. dragged toward the player while reeling).
function FloaterBob.SetOffset(model: Model, offset: Vector3)
	local t = tracked[model]
	if t then t.Offset = offset end
end

function FloaterBob.Start()
	CollectionService:GetInstanceAddedSignal("Floater"):Connect(add)
	CollectionService:GetInstanceRemovedSignal("Floater"):Connect(function(m) tracked[m] = nil end)
	for _, m in ipairs(CollectionService:GetTagged("Floater")) do add(m) end

	RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if not cam then return end
		local camPos = cam.CFrame.Position
		local t = os.clock()
		for model, info in pairs(tracked) do
			if not model.Parent then
				tracked[model] = nil
			elseif (info.Base.Position - camPos).Magnitude < MAX_DIST then
				local bob = math.sin(t * 1.6 + info.Phase) * 0.35
				if model:GetAttribute("Sinking") then
					info.SinkStart = info.SinkStart or t
					bob -= (t - info.SinkStart) * 1.2
				else
					info.SinkStart = nil
				end
				local tilt = math.sin(t * 1.1 + info.Phase) * math.rad(6)
				model:PivotTo((info.Base + info.Offset) * CFrame.new(0, bob, 0) * CFrame.Angles(tilt, t * info.Spin, tilt * 0.6))
			end
		end
	end)
end

return FloaterBob
