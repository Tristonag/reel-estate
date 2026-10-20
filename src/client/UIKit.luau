-- Small UI helper library so every screen looks consistent.
local TweenService = game:GetService("TweenService")

local UIKit = {}
UIKit.Font = Enum.Font.FredokaOne
UIKit.Dark = Color3.fromRGB(25, 20, 40)

function UIKit.Corner(p, r)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 12); c.Parent = p; return c
end

function UIKit.Stroke(p, thickness, color, border)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 3
	s.Color = color or UIKit.Dark
	if border then s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border end
	s.Parent = p
	return s
end

function UIKit.Gradient(p, top, bottom)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top, bottom)
	g.Rotation = 90
	g.Parent = p
	return g
end

function UIKit.Frame(props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in pairs(props) do f[k] = v end
	return f
end

function UIKit.Label(props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = UIKit.Font
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	for k, v in pairs(props) do
		if k ~= "StrokeThickness" then l[k] = v end
	end
	UIKit.Stroke(l, props.StrokeThickness or 2)
	return l
end

-- Chunky game button with gradient, outline and a press bounce.
function UIKit.Button(props, onClick)
	local top = props.Top or Color3.fromRGB(120, 230, 120)
	local bottom = props.Bottom or Color3.fromRGB(50, 170, 70)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.Text = ""
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.Size = props.Size or UDim2.new(0, 160, 0, 50)
	b.Position = props.Position or UDim2.new()
	b.AnchorPoint = props.AnchorPoint or Vector2.zero
	b.Name = props.Name or "Button"
	UIKit.Corner(b, props.Radius or 12)
	UIKit.Stroke(b, 3, UIKit.Dark, true)
	UIKit.Gradient(b, top, bottom)
	local scale = Instance.new("UIScale"); scale.Parent = b
	local label = UIKit.Label({
		Name = "Label",
		Text = props.Text or "",
		Size = UDim2.new(0.86, 0, 0.62, 0),
		Position = UDim2.new(0.07, 0, 0.19, 0),
		StrokeThickness = 2.5,
	})
	label.Parent = b
	b.MouseEnter:Connect(function() TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1.05 }):Play() end)
	b.MouseLeave:Connect(function() TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play() end)
	b.MouseButton1Down:Connect(function() TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.93 }):Play() end)
	b.MouseButton1Up:Connect(function() TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play() end)
	b.Activated:Connect(function()
		local ok, sc = pcall(require, script.Parent.SoundController)
		if ok then sc.Play("Click", 1 + (math.random() - 0.5) * 0.1) end
	end)
	if onClick then b.Activated:Connect(onClick) end
	if props.Parent then b.Parent = props.Parent end
	return b, label
end

-- Pop-in animation for panels.
function UIKit.Pop(gui: GuiObject)
	local s = gui:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", gui)
	local target = gui:GetAttribute("BaseScale") or 1
	s.Scale = target * 0.6
	TweenService:Create(s, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = target }):Play()
end

-- ViewportFrame showing a model, auto-framed. Returns viewport, model, camera.
function UIKit.Viewport(parent: GuiObject, model: Model, props)
	props = props or {}
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Size = props.Size or UDim2.fromScale(1, 1)
	vp.Position = props.Position or UDim2.new()
	vp.Ambient = Color3.fromRGB(200, 200, 200)
	vp.LightColor = Color3.new(1, 1, 1)
	vp.LightDirection = Vector3.new(-1, -2, -1)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.Parent = vp
	vp.CurrentCamera = cam
	model.Parent = vp
	local cf, size = model:GetBoundingBox()
	local radius = size.Magnitude / 2
	local dist = radius / math.tan(math.rad(cam.FieldOfView / 2)) * (props.Zoom or 1.1)
	cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(dist * 0.55, dist * 0.35, -dist * 0.75).Unit * dist, cf.Position)
	vp.Parent = parent
	return vp, model, cam
end

return UIKit
