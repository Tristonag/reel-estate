--[[
	PerkService
	One place that turns owned game passes (player attributes "Pass_<Key>", set by MonetizationService)
	and rebirths into gameplay numbers. Everything else asks here instead of checking passes itself.
]]
local Config = require(game.ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local M = Config.Monetization
local R = Config.Rebirth

local PerkService = {}

function PerkService.Has(player: Player, passKey: string): boolean
	return player:GetAttribute("Pass_" .. passKey) == true
end

function PerkService.Rebirths(player: Player): number
	local data = DataService.Get(player)
	return (data and data.Rebirths) or 0
end

function PerkService.LuckMult(player: Player): number
	return (PerkService.Has(player, "DoubleLuck") and 2 or 1) * (1 + R.LuckBonus * PerkService.Rebirths(player))
end

function PerkService.ShellMult(player: Player): number
	return 1 + R.ShellBonus * PerkService.Rebirths(player)
end

function PerkService.SellMult(player: Player): number
	return (PerkService.Has(player, "VIP") and (1 + M.VIPBonus) or 1) * PerkService.ShellMult(player)
end

function PerkService.IdleMult(player: Player): number
	return (PerkService.Has(player, "VIP") and (1 + M.VIPBonus) or 1) * PerkService.ShellMult(player)
end

function PerkService.BackpackSize(player: Player): number
	return Config.Economy.BackpackSize + (PerkService.Has(player, "BiggerBackpack") and M.BackpackBonus or 0)
end

return PerkService
