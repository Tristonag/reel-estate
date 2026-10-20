-- Default save data for a brand new player.
-- Only string keys and JSON-safe values (DataStores store JSON).
-- Adding a new field here automatically fills it in for existing players on load.
local Config = require(game.ReplicatedStorage.Shared.Config)

return {
	Version = 1,

	Shells = Config.Economy.StartingShells,
	TotalShellsEarned = 0,

	Rebirths = 0,          -- each one: +Config.Rebirth.ShellBonus Shells, +LuckBonus luck

	-- Rods are linear: you own every tier up to RodTier.
	RodTier = 1,
	EquippedRod = 1,

	Baits = {},            -- [baitId] = usesLeft
	EquippedBait = "",

	NextUid = 1,
	Backpack = {},         -- [uid] = { Id = itemId, Variant = "" }

	Island = {
		Stage = 1,
		Placed = {},       -- [slotIndex as string] = { Uid = "", Id = itemId, Variant = "", Rot = 0 }
	},

	Collection = {},       -- ["ItemId"] = true, ["ItemId:Variant"] = true

	Stats = {
		Catches = 0,
		ContainersOpened = {},  -- [containerId] = count
		ShipwrecksJoined = 0,
		PlaySeconds = 0,
	},

	Settings = {
		Music = true,
		Sfx = true,
	},

	Flags = {
		TutorialDone = false,
		LikeRewardClaimed = false,
		StarterPack = false,
	},

	Receipts = {},         -- processed purchase ids (idempotency), trimmed to last 50

	LastOnline = 0,
}
