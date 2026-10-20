--[[
	OddsService
	Roblox Paid Random Items policy support.
	- GetOdds(containerId, context, previewMult?) -> exact odds for THIS player right now
	  context "Fish"    = catching it yourself (rod, book, passes, rebirths, equipped bait)
	  context "Product" = buying it from the Store (same but no bait, matches MonetizationService)
	  context "Wreck"   = a Shipwreck container (fish luck x Config.Shipwreck.LuckBonus)
	  previewMult       = show what a luck boost would change (2x Luck pass, Glowbug bait), clamped 1..4
	- PolicyService: sets player attribute PaidRandomRestricted so the Store hides paid random
	  items (and luck boosts / Shell bundles) in regions that require it. If the check fails we
	  assume restricted, to be safe.
]]
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local LootService = require(script.Parent.LootService)
local BookService = require(script.Parent.BookService)
local PerkService = require(script.Parent.PerkService)
local RateLimit = require(script.Parent.RateLimit)
local Remotes = game.ReplicatedStorage.Shared.Remotes

local OddsService = {}

function OddsService.Luck(player: Player, data, context: string)
	local rod = Config.Rods[data.EquippedRod] or Config.Rods[1]
	local book = BookService.LuckMultiplier(data)
	local perk = PerkService.LuckMult(player)
	local luck = rod.Luck * book * perk
	local parts = {
		{ "Rod", rod.Luck },
		{ "Collection Book", book },
		{ "Passes + Rebirths", perk },
	}
	if context == "Fish" or context == "Wreck" then
		local bait = data.EquippedBait ~= "" and Config.Baits[data.EquippedBait]
		if bait and (data.Baits[data.EquippedBait] or 0) > 0 then
			luck *= bait.Luck
			table.insert(parts, { bait.Name .. " bait", bait.Luck })
		end
	end
	if context == "Wreck" then
		luck *= Config.Shipwreck.LuckBonus
		table.insert(parts, { "Shipwreck bonus", Config.Shipwreck.LuckBonus })
	end
	return luck, parts
end

local function onGetOdds(player: Player, containerId: any, context: any, previewMult: any)
	if type(containerId) ~= "string" or not Config.Containers[containerId] then return nil end
	if not RateLimit.Check(player, "Odds", 0.1) then return nil end
	local data = DataService.Get(player)
	if not data then return nil end
	context = (context == "Product" or context == "Wreck") and context or "Fish"
	local luck, parts = OddsService.Luck(player, data, context)
	local mult = (type(previewMult) == "number" and previewMult == previewMult) and math.clamp(previewMult, 1, 4) or 1
	return {
		Luck = luck,
		Parts = parts,
		Rarity = LootService.GetOdds(containerId, luck),
		Variants = LootService.GetVariantOdds(luck),
		Preview = mult > 1 and {
			Luck = luck * mult,
			Rarity = LootService.GetOdds(containerId, luck * mult),
			Variants = LootService.GetVariantOdds(luck * mult),
		} or nil,
		Pools = LootService.PoolSizes(),
	}
end

local function checkPolicy(player: Player)
	local ok, info = pcall(function() return PolicyService:GetPolicyInfoForPlayerAsync(player) end)
	local restricted = true
	if ok and info then restricted = info.ArePaidRandomItemsRestricted == true end
	player:SetAttribute("PaidRandomRestricted", restricted)
end

function OddsService.Start()
	Remotes.GetOdds.OnServerInvoke = onGetOdds
	Players.PlayerAdded:Connect(checkPolicy)
	for _, p in ipairs(Players:GetPlayers()) do task.spawn(checkPolicy, p) end
end

return OddsService
