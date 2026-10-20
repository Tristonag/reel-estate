--[[
	InventoryService
	SellItems:InvokeServer({ uid, uid, ... }) -> { Ok, Sold = count, Earned = shells }
	Only items actually in the caller's backpack are sold; everything else is ignored.
]]
local Config = require(game.ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local LootService = require(script.Parent.LootService)
local RateLimit = require(script.Parent.RateLimit)
local PerkService = require(script.Parent.PerkService)

local Remotes = game.ReplicatedStorage.Shared.Remotes

local InventoryService = {}
local MAX_PER_CALL = 100

local function sell(player: Player, uids: any)
	if type(uids) ~= "table" then return { Ok = false } end
	if not RateLimit.Check(player, "Sell", 0.25) then return { Ok = false, Reason = "TooFast" } end
	local data = DataService.Get(player)
	if not data then return { Ok = false } end

	local earned, count = 0, 0
	local seen = {}
	for i, uid in ipairs(uids) do
		if i > MAX_PER_CALL then break end
		if type(uid) == "string" and not seen[uid] then
			seen[uid] = true
			local entry = data.Backpack[uid]
			if entry then
				earned += math.floor(LootService.ItemValue(entry.Id, entry.Variant) * PerkService.SellMult(player))
				data.Backpack[uid] = nil
				count += 1
			end
		end
	end
	if count > 0 then
		DataService.MarkChanged(player, "Backpack")
		DataService.AddShells(player, earned)
	end
	return { Ok = true, Sold = count, Earned = earned }
end

local function backpackCount(data): number
	local n = 0
	for _ in pairs(data.Backpack) do n += 1 end
	return n
end

-- Gives an item: records it in the Collection Book, then puts it in the backpack
-- (or auto-sells it if the backpack is full). Returns the result table the reveal UI uses.
function InventoryService.GiveItem(player: Player, itemId: string, variant: string, rarity: string?)
	local data = DataService.Get(player)
	local item = Config.Items[itemId]
	if not data or not item then return nil end
	local value = LootService.ItemValue(itemId, variant)

	local isNew = not data.Collection[itemId]
	data.Collection[itemId] = true
	if variant ~= "" then data.Collection[itemId .. ":" .. variant] = true end
	DataService.MarkChanged(player, "Collection")

	local uid, sold = nil, false
	if backpackCount(data) >= PerkService.BackpackSize(player) and Config.Fishing.InventoryFullAutoSell then
		value = math.floor(value * PerkService.SellMult(player))
		DataService.AddShells(player, value)
		sold = true
	else
		uid = tostring(data.NextUid)
		data.NextUid += 1
		data.Backpack[uid] = { Id = itemId, Variant = variant }
		DataService.MarkChanged(player, "Backpack")
		DataService.MarkChanged(player, "NextUid")
	end
	return {
		Ok = true, Caught = true, ItemId = itemId, Variant = variant, Rarity = rarity or item.Rarity,
		Uid = uid, Sold = sold, Value = value, IsNew = isNew,
	}
end

function InventoryService.Start()
	Remotes.SellItems.OnServerInvoke = sell
end

return InventoryService
