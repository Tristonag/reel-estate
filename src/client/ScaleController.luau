--[[
	ScaleController
	Scales every top-level UI element to the screen so it fits phones and looks right on big monitors.
	Design size is a 760px-tall screen. Full-screen overlays (backdrops, flashes) are left alone.
]]
local Players = game:GetService("Players")

local ScaleController = {}
local GUIS = { "HUD", "FishingUI", "RevealUI", "PlacementUI", "OddsUI" }
local current = 1

local function scaleFor(viewport: Vector2): number
	return math.clamp(viewport.Y / 760, 0.6, 1.15)
end

local function apply(obj: Instance)
	if not obj:IsA("GuiObject") then return end
	if obj.Size.X.Scale >= 0.99 and obj.Size.Y.Scale >= 0.99 then return end -- full-screen layers
	local s = obj:FindFirstChildOfClass("UIScale")
	if not s then s = Instance.new("UIScale"); s.Parent = obj end
	obj:SetAttribute("BaseScale", current)
	s.Scale = current
end

local function applyAll()
	local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if not pg then return end
	for _, name in ipairs(GUIS) do
		local gui = pg:FindFirstChild(name)
		if gui then
			for _, child in ipairs(gui:GetChildren()) do apply(child) end
		end
	end
end

function ScaleController.Start()
	local cam = workspace.CurrentCamera
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local function refresh()
		current = scaleFor(cam.ViewportSize)
		applyAll()
	end
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
	refresh()
	for _, name in ipairs(GUIS) do
		local gui = pg:FindFirstChild(name)
		if gui then
			gui.ChildAdded:Connect(function(child) task.defer(apply, child) end)
		end
	end
end

return ScaleController
