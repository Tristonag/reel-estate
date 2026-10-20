-- Server entry point. Starts every service in order.
-- Listeners start BEFORE DataService so no Loaded event is ever missed.
local Services = script.Parent.Services

local order = {
	"PlayerService",
	"PlotService",
	"IslandService",
	"FloaterService",
	"FishingService",
	"InventoryService",
	"ShopService",
	"IdleService",
	"ShipwreckService",
	"MonetizationService",
	"RebirthService",
	"OddsService",
	"NPCService",
	"DayNightService",
	"DataService",
	"DevService",
}

for _, name in ipairs(order) do
	local mod = require(Services[name])
	if mod.Start then mod.Start() end
end

print("[Reel Estate] Server started")
