--[[
	BookService
	Collection Book rules: a set is complete when every item in it has been caught at least once.
	Each completed set gives a permanent luck bonus (Config.Collection.SetLuckBonus).

	BookService.CompletedSets(data) -> { setName }
	BookService.LuckMultiplier(data) -> number (1 + bonus per completed set)
]]
local Config = require(game.ReplicatedStorage.Shared.Config)

local BookService = {}

local itemsBySet: { [string]: { string } } = {}
for id, item in pairs(Config.Items) do
	itemsBySet[item.Set] = itemsBySet[item.Set] or {}
	table.insert(itemsBySet[item.Set], id)
end

function BookService.CompletedSets(data): { string }
	local done = {}
	for _, set in ipairs(Config.Collection.SetOrder) do
		local list = itemsBySet[set]
		if list then
			local complete = true
			for _, id in ipairs(list) do
				if not data.Collection[id] then complete = false; break end
			end
			if complete then table.insert(done, set) end
		end
	end
	return done
end

function BookService.LuckMultiplier(data): number
	return 1 + #BookService.CompletedSets(data) * Config.Collection.SetLuckBonus
end

return BookService
