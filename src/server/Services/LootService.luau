--[[
	LootService (server only, so odds can't be tampered with)

	LootService.Roll(containerId, luck) -> itemId, variant ("" for none), rarity
	LootService.GetOdds(containerId, luck) -> { [rarity] = percent }  (for the odds display)
	LootService.ItemValue(itemId, variant) -> sell value in Shells
]]
local Config = require(game.ReplicatedStorage.Shared.Config)

local LootService = {}
local rng = Random.new()

-- rarity -> list of itemIds (sorted for deterministic order)
local pools: { [string]: { string } } = {}
for id, item in pairs(Config.Items) do
	pools[item.Rarity] = pools[item.Rarity] or {}
	table.insert(pools[item.Rarity], id)
end
for _, list in pairs(pools) do table.sort(list) end

local variantMult: { [string]: number } = { [""] = 1 }
for _, v in ipairs(Config.Variants) do variantMult[v.Id] = v.Multiplier end

-- Luck boosts higher rarities: weight * luck^(steps above the container's lowest rarity)
local function weightedTable(containerId: string, luck: number)
	local loot = Config.Containers[containerId].Loot
	local lowest = math.huge
	for rarity in pairs(loot) do lowest = math.min(lowest, Config.Rarities[rarity].Tier) end
	local entries, total = {}, 0
	for _, rarity in ipairs(Config.RarityOrder) do
		local w = loot[rarity]
		if w and pools[rarity] then
			local adjusted = w * (luck ^ (Config.Rarities[rarity].Tier - lowest))
			table.insert(entries, { Rarity = rarity, Weight = adjusted })
			total += adjusted
		end
	end
	return entries, total
end

function LootService.GetOdds(containerId: string, luck: number)
	local entries, total = weightedTable(containerId, luck)
	local odds = {}
	for _, e in ipairs(entries) do odds[e.Rarity] = e.Weight / total * 100 end
	return odds
end

local function rollVariant(luck: number): string
	-- rarest first so a Rainbow roll isn't hidden behind a Shiny roll
	for _, v in ipairs(Config.Variants) do
		if rng:NextNumber() < math.min(v.Chance * luck, 0.5) then return v.Id end
	end
	return ""
end

function LootService.Roll(containerId: string, luck: number): (string, string, string)
	local entries, total = weightedTable(containerId, luck)
	local roll = rng:NextNumber() * total
	local rarity = entries[#entries].Rarity
	for _, e in ipairs(entries) do
		roll -= e.Weight
		if roll <= 0 then rarity = e.Rarity; break end
	end
	local pool = pools[rarity]
	local itemId = pool[rng:NextInteger(1, #pool)]
	return itemId, rollVariant(luck), rarity
end

-- exact chance of each variant (rolled rarest first, each capped at 50%)
function LootService.GetVariantOdds(luck: number)
	local left = 1
	local odds = {}
	for _, v in ipairs(Config.Variants) do
		local p = math.min(v.Chance * luck, 0.5)
		odds[v.Id] = left * p * 100
		left *= (1 - p)
	end
	odds.Normal = left * 100
	return odds
end

function LootService.PoolSizes()
	local sizes = {}
	for rarity, list in pairs(pools) do sizes[rarity] = #list end
	return sizes
end

function LootService.ItemValue(itemId: string, variant: string): number
	local item = Config.Items[itemId]
	if not item then return 0 end
	return math.floor(item.Value * (variantMult[variant] or 1))
end

return LootService
