--[[
	IncomeLabels
	- A floating "+X/s" pill above every earning item on YOUR island (fades out with distance).
	- Hover any item on any island (mouse) for a card: name, rarity, variant, income.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Format = require(game.ReplicatedStorage.Shared.Format)
local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer
local IncomeLabels = {}

local VARIANT_MULT = { [""] = 1 }
for _, v in ipairs(Config.Variants) do VARIANT_MULT[v.Id] = v.Multiplier end

local function incomeOf(itemModel: Model): number
	local item = Config.Items[itemModel:GetAttribute("ItemId") or ""]
	if not item then return 0 end
	return item.Idle * (Config.VariantIdleMultiplier[itemModel:GetAttribute("Variant") or ""] or 1)
end

local function rateText(rate: number): string
	return "+" .. (rate >= 10 and Format.Short(rate) or (rate % 1 == 0 and tostring(rate) or string.format("%.1f", rate))) .. "/s"
end

local function label(itemModel: Model)
	if itemModel:FindFirstChild("IncomeTag") then return end
	local rate = incomeOf(itemModel)
	if rate <= 0 or not itemModel.PrimaryPart then return end
	local _, size = itemModel:GetBoundingBox()
	local bb = Instance.new("BillboardGui")
	bb.Name = "IncomeTag"
	bb.Adornee = itemModel.PrimaryPart
	bb.Size = UDim2.new(0, 70, 0, 24)
	bb.StudsOffsetWorldSpace = Vector3.new(0, size.Y + 1.2, 0)
	bb.MaxDistance = 70
	bb.LightInfluence = 0
	local pill = UIKit.Frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1) })
	UIKit.Corner(pill, 12)
	UIKit.Stroke(pill, 2, Color3.fromRGB(20, 60, 30), true)
	UIKit.Gradient(pill, Color3.fromRGB(140, 245, 150), Color3.fromRGB(50, 180, 80))
	pill.Parent = bb
	local l = UIKit.Label({ Text = rateText(rate), Size = UDim2.new(1, -8, 0.8, 0), Position = UDim2.new(0, 4, 0.1, 0), StrokeThickness = 1.5 })
	l.Parent = pill
	-- the label lives on the client only, parented to the model so it goes away with it
	bb.Parent = itemModel
end

local function watchPlot(plot: Model)
	local items = plot:WaitForChild("Items", 10)
	if not items then return end
	for _, m in ipairs(items:GetChildren()) do task.defer(label, m) end
	items.ChildAdded:Connect(function(m) task.defer(label, m) end)
end

local function isMine(plot: Instance): boolean
	return plot:GetAttribute("Owner") == player.UserId
end

-- hover card
local card, cardName, cardRarity, cardIncome
local function buildCard(gui: ScreenGui)
	card = UIKit.Frame({ Name = "HoverCard", Size = UDim2.new(0, 190, 0, 70), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, ZIndex = 30 })
	UIKit.Corner(card, 12)
	UIKit.Stroke(card, 3, UIKit.Dark, true)
	UIKit.Gradient(card, Color3.fromRGB(70, 50, 120), Color3.fromRGB(35, 22, 65))
	card.Parent = gui
	cardName = UIKit.Label({ Size = UDim2.new(1, -16, 0, 24), Position = UDim2.new(0, 8, 0, 6), ZIndex = 31 })
	cardRarity = UIKit.Label({ Size = UDim2.new(1, -16, 0, 16), Position = UDim2.new(0, 8, 0, 30), ZIndex = 31 })
	cardIncome = UIKit.Label({ Size = UDim2.new(1, -16, 0, 16), Position = UDim2.new(0, 8, 0, 48), ZIndex = 31, TextColor3 = Color3.fromRGB(150, 255, 170) })
	cardName.Parent = card; cardRarity.Parent = card; cardIncome.Parent = card
end

function IncomeLabels.Start()
	local gui = player.PlayerGui:WaitForChild("HUD")
	buildCard(gui)

	local plots = workspace:WaitForChild("Plots")
	local function consider(p)
		if p:IsA("Model") and isMine(p) then task.spawn(watchPlot, p) end
	end
	for _, p in ipairs(plots:GetChildren()) do consider(p) end
	plots.ChildAdded:Connect(function(p)
		task.wait(0.2)
		consider(p)
	end)

	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then return end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local lastUpdate = 0
	RunService.RenderStepped:Connect(function()
		if os.clock() - lastUpdate < 0.05 then return end
		lastUpdate = os.clock()
		local filter = {}
		for _, p in ipairs(plots:GetChildren()) do
			local items = p:FindFirstChild("Items")
			if items then table.insert(filter, items) end
		end
		params.FilterDescendantsInstances = filter
		local m = UserInputService:GetMouseLocation()
		-- pointing at a menu or button? then we're not hovering the world
		local inset = game:GetService("GuiService"):GetGuiInset()
		for _, g in ipairs(player.PlayerGui:GetGuiObjectsAtPosition(m.X - inset.X, m.Y - inset.Y)) do
			if g ~= card and not g:IsDescendantOf(card) and g.Visible and (g.BackgroundTransparency < 1 or g:IsA("GuiButton") or g:IsA("ViewportFrame")) then
				card.Visible = false
				return
			end
		end
		local ray = workspace.CurrentCamera:ViewportPointToRay(m.X, m.Y)
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 150, params)
		local model = hit and hit.Instance
		while model and not (model:IsA("Model") and model:GetAttribute("ItemId")) do model = model.Parent end
		if not model then card.Visible = false return end
		local item = Config.Items[model:GetAttribute("ItemId")]
		local variant = model:GetAttribute("Variant") or ""
		if not item then card.Visible = false return end
		cardName.Text = (variant ~= "" and (variant .. " ") or "") .. item.Name
		cardRarity.Text = item.Rarity .. "  |  " .. item.Set
		cardRarity.TextColor3 = Config.Rarities[item.Rarity].Color
		local rate = incomeOf(model)
		cardIncome.Text = rate > 0 and (rateText(rate) .. " Shells") or ("Island Score +" .. math.floor(item.Score * (VARIANT_MULT[variant] or 1)))
		local inset = game:GetService("GuiService"):GetGuiInset()
		card.Position = UDim2.fromOffset(m.X + 18, m.Y - inset.Y + 10)
		card.Visible = true
	end)
end

return IncomeLabels
