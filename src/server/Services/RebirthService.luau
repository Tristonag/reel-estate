--[[
	RebirthService
	Rebirth() -> { Ok, Rebirths?, Reason? }
	Needs Config.Rebirth.StageRequired island stage and BaseCost * (rebirths + 1) Shells.
	Resets: Shells, rods, bait, backpack, island (stage + placed items).
	Keeps: Collection Book, passes, stats, flags, receipts (Starter Pack keeps its rod).
	Each rebirth: +ShellBonus Shells (sell + idle) and +LuckBonus luck, via PerkService.
]]
local Config = require(game.ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local IslandService = require(script.Parent.IslandService)
local RateLimit = require(script.Parent.RateLimit)
local Remotes = game.ReplicatedStorage.Shared.Remotes
local R = Config.Rebirth

local RebirthService = {}

function RebirthService.Cost(rebirths: number): number
	return R.BaseCost * (rebirths + 1)
end

local function onRebirth(player: Player)
	if not RateLimit.Check(player, "Rebirth", 3) then return { Ok = false, Reason = "TooFast" } end
	local data = DataService.Get(player)
	if not data then return { Ok = false, Reason = "NotReady" } end
	if data.Island.Stage < R.StageRequired then return { Ok = false, Reason = "Stage" } end
	local cost = RebirthService.Cost(data.Rebirths or 0)
	if data.Shells < cost then return { Ok = false, Reason = "NotEnough" } end

	data.Rebirths = (data.Rebirths or 0) + 1
	data.Shells = Config.Economy.StartingShells
	local keepRod = data.Flags.StarterPack and 3 or 1
	data.RodTier = keepRod
	data.EquippedRod = keepRod
	data.Baits = {}
	data.EquippedBait = ""
	data.Backpack = {}
	data.Island = { Stage = 1, Placed = {} }

	for _, key in ipairs({ "Rebirths", "Shells", "RodTier", "EquippedRod", "Baits", "EquippedBait", "Backpack", "Island" }) do
		DataService.MarkChanged(player, key)
	end
	IslandService.Rebuild(player)
	task.spawn(DataService.SaveNow, player)
	return { Ok = true, Rebirths = data.Rebirths }
end

function RebirthService.Start()
	Remotes.Rebirth.OnServerInvoke = onRebirth
end

return RebirthService
