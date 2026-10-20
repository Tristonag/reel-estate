--[[
	MonetizationService
	Game passes and developer products.

	Game passes -> player attribute "Pass_<Key>" = true (checked on join, and set instantly on purchase).
	PerkService turns those attributes into gameplay effects.

	Developer products -> ProcessReceipt, done the safe way:
		1. data not loaded yet            -> NotProcessedYet (Roblox retries later)
		2. receipt already in data        -> PurchaseGranted (never grant twice)
		3. grant, record receipt, SAVE    -> PurchaseGranted only if the save worked
		   (if the save fails we return NotProcessedYet; the retry sees the receipt if this server
		    is still up, or a fresh server re-grants from the last saved state, so nothing is lost or doubled)
]]
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local LootService = require(script.Parent.LootService)
local InventoryService = require(script.Parent.InventoryService)
local ShipwreckService = require(script.Parent.ShipwreckService)
local BookService = require(script.Parent.BookService)
local PerkService = require(script.Parent.PerkService)
local Remotes = game.ReplicatedStorage.Shared.Remotes

local M = Config.Monetization
local MonetizationService = {}

local passByKey = M.GamePasses
local passKeyById: { [number]: string } = {}
for key, p in pairs(passByKey) do if p.Id ~= 0 then passKeyById[p.Id] = key end end
local productKeyById: { [number]: string } = {}
for key, p in pairs(M.Products) do if p.Id ~= 0 then productKeyById[p.Id] = key end end

------------------------------------------------------------------
-- Game passes
------------------------------------------------------------------
local function addVipTag(player: Player)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not head or head:FindFirstChild("VIPTag") then return end
	local bb = Instance.new("BillboardGui")
	bb.Name = "VIPTag"
	bb.Size = UDim2.new(0, 80, 0, 26)
	bb.StudsOffset = Vector3.new(0, 2.6, 0)
	bb.MaxDistance = 80
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.Text = "VIP"
	l.TextColor3 = Color3.fromRGB(255, 210, 60)
	local st = Instance.new("UIStroke"); st.Thickness = 2.5; st.Color = Color3.fromRGB(60, 35, 5); st.Parent = l
	l.Parent = bb
	bb.Parent = head
end

function MonetizationService.GrantPass(player: Player, key: string)
	if not passByKey[key] then return end
	player:SetAttribute("Pass_" .. key, true)
	if key == "VIP" then addVipTag(player) end
end

local function checkPasses(player: Player)
	for key, p in pairs(passByKey) do
		if p.Id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, p.Id)
			if ok and owns then MonetizationService.GrantPass(player, key) end
		end
	end
end

------------------------------------------------------------------
-- Product grants (each returns true when the reward was applied)
------------------------------------------------------------------
local function addBait(player: Player, data, id: string, uses: number)
	data.Baits[id] = (data.Baits[id] or 0) + uses
	data.EquippedBait = id
	DataService.MarkChanged(player, "Baits")
	DataService.MarkChanged(player, "EquippedBait")
end

local GRANTS = {}

GRANTS.StarterPack = function(player: Player, data)
	DataService.AddShells(player, 5000)
	if not data.Flags.StarterPack then
		data.Flags.StarterPack = true
		DataService.MarkChanged(player, "Flags")
		if data.RodTier < 3 then
			data.RodTier = 3
			data.EquippedRod = 3
			DataService.MarkChanged(player, "RodTier")
			DataService.MarkChanged(player, "EquippedRod")
		end
		addBait(player, data, "Glowbug", 10)
	end
	return true
end

GRANTS.GoldenChest = function(player: Player, data)
	local rod = Config.Rods[data.EquippedRod] or Config.Rods[1]
	local luck = rod.Luck * BookService.LuckMultiplier(data) * PerkService.LuckMult(player)
	local itemId, variant, rarity = LootService.Roll("GoldenChest", luck)
	local result = InventoryService.GiveItem(player, itemId, variant, rarity)
	if not result then return false end
	result.Container = "GoldenChest"
	task.defer(function() if player.Parent then Remotes.ShowReveal:FireClient(player, result) end end)
	return true
end

GRANTS.LuckyBait = function(player: Player, data)
	addBait(player, data, "Glowbug", 30)
	return true
end

GRANTS.SummonShipwreck = function(player: Player, data)
	ShipwreckService.Summon(player)
	return true
end

local function shellBundle(player: Player, cfg)
	local rate = player:GetAttribute("IdleRate") or 0
	DataService.AddShells(player, math.max(cfg.Min, math.floor(rate * 60 * cfg.Minutes)))
	return true
end
GRANTS.ShellsSmall = function(player: Player) return shellBundle(player, M.ShellsSmall) end
GRANTS.ShellsLarge = function(player: Player) return shellBundle(player, M.ShellsLarge) end

-- Shared by ProcessReceipt and the Studio dev command.
function MonetizationService.GrantProduct(player: Player, key: string, purchaseId: string?): boolean
	local data = DataService.Get(player)
	local grant = GRANTS[key]
	if not data or not grant then return false end
	if purchaseId then
		for _, id in ipairs(data.Receipts) do
			if id == purchaseId then return true end -- already granted
		end
	end
	local ok, granted = pcall(grant, player, data)
	if not ok or not granted then
		warn("[Monetization] Grant failed for " .. key .. ": " .. tostring(granted))
		return false
	end
	if purchaseId then table.insert(data.Receipts, purchaseId) end
	return true
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local data = DataService.Get(player)
	if not data then return Enum.ProductPurchaseDecision.NotProcessedYet end

	local purchaseId = tostring(receipt.PurchaseId)
	for _, id in ipairs(data.Receipts) do
		if id == purchaseId then return Enum.ProductPurchaseDecision.PurchaseGranted end
	end

	local key = productKeyById[receipt.ProductId]
	if not key then
		warn("[Monetization] Unknown product id " .. tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not MonetizationService.GrantProduct(player, key, purchaseId) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not DataService.SaveNow(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

------------------------------------------------------------------
function MonetizationService.Start()
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		local key = passKeyById[passId]
		if purchased and key then MonetizationService.GrantPass(player, key) end
	end)

	DataService.Loaded.Event:Connect(function(player: Player)
		task.spawn(checkPasses, player)
	end)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			if PerkService.Has(player, "VIP") then addVipTag(player) end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in ipairs(Players:GetPlayers()) do watch(p) end
end

return MonetizationService
