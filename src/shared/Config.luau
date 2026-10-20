--!strict
-- Reel Estate: single source of truth for every tunable number and item.
-- Change balance here only. Server reads it for rules, client reads it for display.

local Config = {}

Config.Version = 1

------------------------------------------------------------------
-- Rarities (order matters: index = tier)
------------------------------------------------------------------
Config.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

Config.Rarities = {
	Common    = { Tier = 1, Color = Color3.fromRGB(190, 190, 190) },
	Uncommon  = { Tier = 2, Color = Color3.fromRGB(110, 220, 110) },
	Rare      = { Tier = 3, Color = Color3.fromRGB(80, 160, 255) },
	Epic      = { Tier = 4, Color = Color3.fromRGB(180, 90, 255) },
	Legendary = { Tier = 5, Color = Color3.fromRGB(255, 190, 40) },
	Mythic    = { Tier = 6, Color = Color3.fromRGB(255, 70, 120) },
}

-- Idle income uses gentler variant multipliers than sell value, so one lucky variant
-- can't skip the whole progression. (Sell value and Island Score use the full Multiplier.)
Config.VariantIdleMultiplier = { [""] = 1, Shiny = 1.5, Golden = 2.5, Rainbow = 4 }

-- Variants roll on top of any item. Chance is per catch (0-1). Multiplier applies to sell value and score.
Config.Variants = {
	{ Id = "Rainbow", Chance = 0.002, Multiplier = 10 },
	{ Id = "Golden",  Chance = 0.01,  Multiplier = 5 },
	{ Id = "Shiny",   Chance = 0.05,  Multiplier = 2 },
}

------------------------------------------------------------------
-- Containers (what floats on the water). Weights pick the item rarity inside.
-- MinRod = rod tier needed to reach them. SpawnWeight = how often they appear.
------------------------------------------------------------------
Config.ContainerOrder = { "Crate", "Barrel", "Bottle", "Chest", "GoldenChest", "Relic" }

Config.Containers = {
	Crate       = { Name = "Driftwood Crate", MinRod = 1, SpawnWeight = 50, ReelDifficulty = 1.0,
		Loot = { Common = 70, Uncommon = 25, Rare = 5 } },
	Barrel      = { Name = "Barrel", MinRod = 2, SpawnWeight = 25, ReelDifficulty = 1.2,
		Loot = { Common = 35, Uncommon = 40, Rare = 20, Epic = 5 } },
	Bottle      = { Name = "Message Bottle", MinRod = 3, SpawnWeight = 12, ReelDifficulty = 1.4,
		Loot = { Uncommon = 30, Rare = 45, Epic = 20, Legendary = 5 } },
	Chest       = { Name = "Treasure Chest", MinRod = 4, SpawnWeight = 8, ReelDifficulty = 1.7,
		Loot = { Rare = 40, Epic = 40, Legendary = 18, Mythic = 2 } },
	GoldenChest = { Name = "Golden Chest", MinRod = 6, SpawnWeight = 4, ReelDifficulty = 2.0,
		Loot = { Epic = 50, Legendary = 42, Mythic = 8 } },
	Relic       = { Name = "Mythic Relic", MinRod = 8, SpawnWeight = 1, ReelDifficulty = 2.5,
		Loot = { Legendary = 70, Mythic = 30 } },
}

------------------------------------------------------------------
-- Items. Value = base sell price in Shells. Score = Island Score when placed.
-- Idle = Shells per second while placed (0 = decor only).
------------------------------------------------------------------
Config.Items = {
	-- Castaway
	PlankFloor = { Name = "Plank Floor", Set = "Castaway", Rarity = "Common", Value = 5, Score = 1, Idle = 0 },
	CrateStack = { Name = "Crate Stack", Set = "Castaway", Rarity = "Common", Value = 6, Score = 1, Idle = 0 },
	Torch = { Name = "Tiki Torch", Set = "Castaway", Rarity = "Common", Value = 8, Score = 2, Idle = 0 },
	Bucket = { Name = "Old Bucket", Set = "Castaway", Rarity = "Common", Value = 4, Score = 1, Idle = 0 },
	FishingNet = { Name = "Fishing Net", Set = "Castaway", Rarity = "Common", Value = 7, Score = 2, Idle = 0.1 },
	Hammock = { Name = "Hammock", Set = "Castaway", Rarity = "Uncommon", Value = 20, Score = 4, Idle = 0.2 },
	Campfire = { Name = "Campfire", Set = "Castaway", Rarity = "Uncommon", Value = 25, Score = 5, Idle = 0.3 },
	Rowboat = { Name = "Rowboat", Set = "Castaway", Rarity = "Uncommon", Value = 32, Score = 6, Idle = 0.4 },
	-- Tropical
	BeachUmbrella = { Name = "Beach Umbrella", Set = "Tropical", Rarity = "Common", Value = 9, Score = 2, Idle = 0.1 },
	PalmTree = { Name = "Palm Tree", Set = "Tropical", Rarity = "Uncommon", Value = 30, Score = 6, Idle = 0.4 },
	Flamingo = { Name = "Flamingo Float", Set = "Tropical", Rarity = "Uncommon", Value = 28, Score = 5, Idle = 0.3 },
	CoconutStand = { Name = "Coconut Stand", Set = "Tropical", Rarity = "Rare", Value = 90, Score = 15, Idle = 1.2 },
	SurfRack = { Name = "Surfboard Rack", Set = "Tropical", Rarity = "Rare", Value = 80, Score = 14, Idle = 1 },
	TikiHut = { Name = "Tiki Hut", Set = "Tropical", Rarity = "Epic", Value = 300, Score = 45, Idle = 3.5 },
	HotTub = { Name = "Hot Tub", Set = "Tropical", Rarity = "Epic", Value = 350, Score = 50, Idle = 3 },
	-- Pirate
	Anchor = { Name = "Anchor", Set = "Pirate", Rarity = "Rare", Value = 85, Score = 14, Idle = 1 },
	PirateFlag = { Name = "Pirate Flag", Set = "Pirate", Rarity = "Rare", Value = 95, Score = 16, Idle = 1 },
	Cannon = { Name = "Cannon", Set = "Pirate", Rarity = "Epic", Value = 320, Score = 48, Idle = 3 },
	ShipWheel = { Name = "Ship Wheel", Set = "Pirate", Rarity = "Epic", Value = 280, Score = 42, Idle = 3 },
	CrowsNest = { Name = "Crow's Nest", Set = "Pirate", Rarity = "Legendary", Value = 1200, Score = 160, Idle = 10 },
	TreasurePile = { Name = "Treasure Pile", Set = "Pirate", Rarity = "Legendary", Value = 1500, Score = 180, Idle = 12 },
	-- Haunted
	PumpkinPatch = { Name = "Pumpkin Patch", Set = "Haunted", Rarity = "Uncommon", Value = 30, Score = 6, Idle = 0.4 },
	Gravestone = { Name = "Gravestone", Set = "Haunted", Rarity = "Uncommon", Value = 26, Score = 5, Idle = 0.3 },
	GhostLantern = { Name = "Ghost Lantern", Set = "Haunted", Rarity = "Rare", Value = 100, Score = 16, Idle = 1.2 },
	DeadTree = { Name = "Spooky Tree", Set = "Haunted", Rarity = "Rare", Value = 90, Score = 15, Idle = 1 },
	Cauldron = { Name = "Bubbling Cauldron", Set = "Haunted", Rarity = "Epic", Value = 340, Score = 48, Idle = 3.5 },
	CrystalBall = { Name = "Crystal Ball", Set = "Haunted", Rarity = "Epic", Value = 380, Score = 52, Idle = 4 },
	WitchHut = { Name = "Witch Hut", Set = "Haunted", Rarity = "Legendary", Value = 1700, Score = 210, Idle = 13 },
	HauntedManor = { Name = "Haunted Manor", Set = "Haunted", Rarity = "Mythic", Value = 11000, Score = 1150, Idle = 45 },
	-- Arctic
	SnowyPine = { Name = "Snowy Pine", Set = "Arctic", Rarity = "Uncommon", Value = 30, Score = 6, Idle = 0.4 },
	Snowman = { Name = "Snowman", Set = "Arctic", Rarity = "Uncommon", Value = 32, Score = 6, Idle = 0.4 },
	Igloo = { Name = "Igloo", Set = "Arctic", Rarity = "Rare", Value = 110, Score = 17, Idle = 1.4 },
	IceCrystal = { Name = "Ice Crystal", Set = "Arctic", Rarity = "Epic", Value = 360, Score = 50, Idle = 3.5 },
	SnowGlobe = { Name = "Snow Globe", Set = "Arctic", Rarity = "Epic", Value = 400, Score = 55, Idle = 4 },
	IceCastle = { Name = "Ice Castle", Set = "Arctic", Rarity = "Mythic", Value = 13000, Score = 1300, Idle = 55 },
	-- Wonders
	Lighthouse = { Name = "Lighthouse", Set = "Wonders", Rarity = "Legendary", Value = 2000, Score = 250, Idle = 15 },
	WaterfallRock = { Name = "Waterfall Rock", Set = "Wonders", Rarity = "Legendary", Value = 1800, Score = 230, Idle = 12 },
	AncientTotem = { Name = "Ancient Totem", Set = "Wonders", Rarity = "Legendary", Value = 1900, Score = 240, Idle = 14 },
	TempleArch = { Name = "Sunken Temple Arch", Set = "Wonders", Rarity = "Mythic", Value = 8000, Score = 900, Idle = 40 },
	GoldenStatue = { Name = "Golden Statue", Set = "Wonders", Rarity = "Mythic", Value = 9000, Score = 1000, Idle = 38 },
	MiniShip = { Name = "Mini Pirate Ship", Set = "Wonders", Rarity = "Mythic", Value = 12000, Score = 1200, Idle = 50 },
	Volcano = { Name = "Tiny Volcano", Set = "Wonders", Rarity = "Mythic", Value = 15000, Score = 1500, Idle = 60 },
	-- Pets
	Crab = { Name = "Crab", Set = "Pets", Rarity = "Rare", Value = 120, Score = 12, Idle = 2 },
	Seagull = { Name = "Seagull", Set = "Pets", Rarity = "Rare", Value = 110, Score = 12, Idle = 2 },
	Penguin = { Name = "Penguin", Set = "Pets", Rarity = "Rare", Value = 130, Score = 13, Idle = 2.2 },
	Turtle = { Name = "Turtle", Set = "Pets", Rarity = "Epic", Value = 400, Score = 40, Idle = 6 },
	Octopus = { Name = "Octopus", Set = "Pets", Rarity = "Epic", Value = 450, Score = 44, Idle = 6.5 },
	Parrot = { Name = "Parrot", Set = "Pets", Rarity = "Legendary", Value = 1400, Score = 140, Idle = 18 },
	Dolphin = { Name = "Dolphin", Set = "Pets", Rarity = "Legendary", Value = 1600, Score = 150, Idle = 20 },
	PolarBear = { Name = "Polar Bear", Set = "Pets", Rarity = "Legendary", Value = 1800, Score = 170, Idle = 22 },
}

------------------------------------------------------------------
-- Rods. Tier index = position. Price in Shells (tier 1 is free).
------------------------------------------------------------------
Config.Rods = {
	{ Id = "Stick", Name = "Stick Rod", Price = 0, MaxDistance = 40, ReelPower = 1.0, Luck = 1.00, Color = { 120, 80, 45 } },
	{ Id = "Bamboo", Name = "Bamboo Rod", Price = 750, MaxDistance = 60, ReelPower = 1.1, Luck = 1.05, Color = { 200, 180, 90 } },
	{ Id = "Fiberglass", Name = "Fiberglass Rod", Price = 8000, MaxDistance = 80, ReelPower = 1.25, Luck = 1.10, Color = { 90, 170, 230 } },
	{ Id = "Steel", Name = "Steel Rod", Price = 70000, MaxDistance = 100, ReelPower = 1.4, Luck = 1.20, Color = { 170, 175, 185 } },
	{ Id = "Coral", Name = "Coral Rod", Price = 500000, MaxDistance = 125, ReelPower = 1.6, Luck = 1.30, Color = { 255, 120, 110 } },
	{ Id = "Captain", Name = "Captain's Rod", Price = 3500000, MaxDistance = 150, ReelPower = 1.8, Luck = 1.45, Color = { 40, 60, 120 } },
	{ Id = "Kraken", Name = "Kraken Rod", Price = 25000000, MaxDistance = 180, ReelPower = 2.1, Luck = 1.65, Color = { 130, 60, 170 } },
	{ Id = "Poseidon", Name = "Poseidon's Rod", Price = 150000000, MaxDistance = 220, ReelPower = 2.5, Luck = 2.00, Color = { 255, 205, 60 } },
}

------------------------------------------------------------------
-- Bait (consumable luck). Luck multiplies odds of higher-rarity results.
------------------------------------------------------------------
Config.Baits = {
	Worm    = { Name = "Worm",        Price = 25,   Luck = 1.2, Uses = 10 },
	Shrimp  = { Name = "Shrimp",      Price = 200,  Luck = 1.5, Uses = 10 },
	Glowbug = { Name = "Glowbug",     Price = 1500, Luck = 2.0, Uses = 10 },
}

------------------------------------------------------------------
-- Island stages. Slots = number of placement slots. Price to upgrade INTO that stage.
------------------------------------------------------------------
Config.IslandStages = {
	{ Id = "Raft", Name = "Raft", Price = 0, ScoreRequired = 0, GridSize = 2, Slots = 4, Material = "WoodPlanks", Color = { 165, 118, 72 } },
	{ Id = "Sandbar", Name = "Sandbar", Price = 3000, ScoreRequired = 0, GridSize = 3, Slots = 9, Material = "Sand", Color = { 250, 236, 196 } },
	{ Id = "Islet", Name = "Islet", Price = 40000, ScoreRequired = 150, GridSize = 4, Slots = 16, Material = "Sand", Color = { 252, 240, 204 } },
	{ Id = "Island", Name = "Island", Price = 400000, ScoreRequired = 800, GridSize = 5, Slots = 25, Material = "Grass", Color = { 120, 190, 90 } },
	{ Id = "Paradise", Name = "Paradise Isle", Price = 4000000, ScoreRequired = 3500, GridSize = 6, Slots = 36, Material = "Grass", Color = { 110, 200, 95 } },
	{ Id = "Royal", Name = "Royal Isle", Price = 40000000, ScoreRequired = 12000, GridSize = 7, Slots = 49, Material = "Grass", Color = { 105, 205, 110 } },
	{ Id = "Atoll", Name = "Legendary Atoll", Price = 300000000, ScoreRequired = 35000, GridSize = 8, Slots = 64, Material = "Grass", Color = { 95, 210, 120 } },
}

------------------------------------------------------------------
-- Economy and timing
------------------------------------------------------------------
-- Collection Book: set order for display, and the permanent luck each completed set gives
Config.Collection = {
	SetOrder = { "Castaway", "Tropical", "Pirate", "Haunted", "Arctic", "Wonders", "Pets" },
	SetLuckBonus = 0.05,
}

Config.Economy = {
	StartingShells = 50,
	BackpackSize = 30,              -- unplaced items a player can hold
	OfflineEarningsCapHours = 4,
	OfflineEarningsRate = 0.5,      -- offline earns 50% of online idle rate
	IdleTickSeconds = 5,            -- idle income is paid out in chunks this often
	OfflineMinSeconds = 60,         -- shorter absences don't trigger the popup
	FriendLuckBonus = 0.05,         -- per nearby friend
	FriendLuckMax = 0.20,
}

Config.Timing = {
	AutosaveSeconds = 120,
}

------------------------------------------------------------------
-- Shipwreck event: surfaces between the hub and the plots, everyone races for its loot.
------------------------------------------------------------------
Config.Shipwreck = {
	IntervalSeconds = 900,         -- time between wrecks
	WarningSeconds = 60,           -- "Shipwreck in 60s!" heads-up
	DurationSeconds = 90,          -- how long it stays up
	RingRadius = 95,               -- distance from world center (between hub edge and plots)
	Floaters = 16,                 -- containers kept around the wreck while it's up
	FloaterRadius = { 9, 24 },     -- how far from the wreck containers spawn
	RestockSeconds = 2.5,
	-- which containers the wreck spawns (weights). Event containers ignore rod tier requirements.
	Loot = { Barrel = 20, Bottle = 30, Chest = 30, GoldenChest = 15, Relic = 5 },
	LuckBonus = 1.25,              -- extra luck on wreck containers
}

------------------------------------------------------------------
-- Group reward (free Auto-Reel). Set GroupId once the group exists. 0 = disabled.
------------------------------------------------------------------
Config.Group = {
	GroupId = 0,
}

------------------------------------------------------------------
-- World layout. Plots sit on a ring around the hub, ocean outside.
------------------------------------------------------------------
Config.World = {
	WaterLevel = 0,          -- Y of the ocean surface
	OceanHalfSize = 480,     -- terrain water extends this far from center on X and Z
}

Config.Plots = {
	Count = 8,               -- also the max players per server
	RingRadius = 160,        -- distance from world center to each plot center
	CellSize = 8,            -- studs per island grid cell (island stages use GridSize)
}

------------------------------------------------------------------
-- Fishing
------------------------------------------------------------------
Config.Fishing = {
	FloatersPerPlot = 12,
	FloaterLifetime = { 150, 240 },   -- seconds before an untouched floater sinks
	HookRadius = 7,                   -- how close the cast must land to a floater
	MinCharge = 0.1,
	ReelTimeout = 35,                 -- seconds before a reel auto-fails
	-- Distance from the plot center where each container can spawn. Farther = rarer.
	SpawnBands = {
		Crate       = { 14, 40 },
		Barrel      = { 30, 60 },
		Bottle      = { 45, 80 },
		Chest       = { 65, 100 },
		GoldenChest = { 100, 150 },
		Relic       = { 150, 215 },
	},
	-- Reel minigame. Fill rate per second = BaseFillRate * rod.ReelPower / container.ReelDifficulty
	BaseFillRate = 0.38,
	StartProgress = 0.3,
	DrainRate = 0.12,
	-- Minigame feel (client). Difficulty = container.ReelDifficulty / rod.ReelPower
	ZoneWidthBase = 0.4,              -- zone width = ZoneWidthBase / difficulty, clamped below
	ZoneWidthMin = 0.2,
	ZoneWidthMax = 0.5,
	ZoneSpeedBase = 0.12,             -- zone speed = base + perDifficulty * difficulty (bar widths per second)
	ZoneSpeedPerDifficulty = 0.1,
	ZonePauseMax = 1.0,               -- zone rests up to this long between moves
	MarkerAccel = 1.8,
	MarkerMaxSpeed = 0.95,
	AutoReelSpeed = 0.75,             -- auto-reel fills at 75% of a perfect manual reel
	MinBiteSeconds = 0.5,
	ReelTimeTolerance = 0.85,         -- server accepts a reel at 85% of the fastest possible time
	InventoryFullAutoSell = true,
}

------------------------------------------------------------------
-- Monetization. Paste the real IDs from the Creator Hub here (0 = not set up yet, shows "Coming soon").
-- Prices are set on the Roblox website; the store reads them live.
------------------------------------------------------------------
Config.Monetization = {
	GamePasses = {
		DoubleLuck     = { Id = 1992110709, Name = "2x Luck",        Order = 1, Desc = "Luck x2 on every catch, forever. Tap DETAILS for exact odds." },
		TurboReel      = { Id = 1995812409, Name = "Turbo Reel",     Order = 2, Desc = "Auto-Reel at full speed, no group needed." },
		BiggerBackpack = { Id = 1994204424, Name = "Bigger Backpack",Order = 3, Desc = "+30 backpack slots." },
		VIP            = { Id = 1996016413, Name = "VIP",            Order = 4, Desc = "+20% Shells from selling and idle income, VIP tag." },
		SkipReveal     = { Id = 1994120476, Name = "Skip Reveal",    Order = 5, Desc = "Skip the crate opening animation." },
	},
	Products = {
		StarterPack     = { Id = 3714532532, Name = "Starter Pack",     Order = 1, Desc = "5,000 Shells, Fiberglass Rod and 10 Glowbug bait. One time only!" },
		GoldenChest     = { Id = 3714532667, Name = "Golden Chest",     Order = 2, Desc = "Opens right now: Epic, Legendary or Mythic. Tap ODDS for every item." },
		LuckyBait       = { Id = 3714532583, Name = "Lucky Bait x30",   Order = 3, Desc = "30 catches with Glowbug bait (Luck x2). Tap DETAILS." },
		SummonShipwreck = { Id = 3714532711, Name = "Summon Shipwreck", Order = 4, Desc = "Raise a Shipwreck for the whole server! Tap DETAILS." },
		ShellsSmall     = { Id = 3714532621, Name = "Bag of Shells",    Order = 5, Desc = "15 minutes of your island's income (min 2,500)." },
		ShellsLarge     = { Id = 3714532731, Name = "Chest of Shells",  Order = 6, Desc = "2 hours of your island's income (min 25,000)." },
	},
	VIPBonus = 0.2,
	BackpackBonus = 30,
	ShellsSmall = { Minutes = 15, Min = 2500 },
	ShellsLarge = { Minutes = 120, Min = 25000 },
}

Config.Rebirth = {
	StageRequired = 5, -- must own Paradise Isle
	BaseCost = 5000000, -- Shells, times (rebirths + 1)
	ShellBonus = 0.5, -- +50% Shells per rebirth
	LuckBonus = 0.1, -- +10% luck per rebirth
}

return Config
