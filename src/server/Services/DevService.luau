--[[
	DevService (Studio only, never runs in live servers)
	Exposes ServerStorage.DevCommand (BindableFunction) for testing:
		DevCommand:Invoke("get", playerName)            -> copy of data
		DevCommand:Invoke("addShells", playerName, n)
		DevCommand:Invoke("spendShells", playerName, n) -> bool
		DevCommand:Invoke("give", playerName, itemId, variant?)
]]
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local DataService = require(script.Parent.DataService)

local DevService = {}

function DevService.Start()
	if not RunService:IsStudio() then return end

	local fn = Instance.new("BindableFunction")
	fn.Name = "DevCommand"
	fn.Parent = game.ServerStorage

	fn.OnInvoke = function(cmd, playerName, a, b)
		local player = playerName and Players:FindFirstChild(playerName) or Players:GetPlayers()[1]
		if not player then return "no player" end
		local d = DataService.Get(player)
		if not d then return "not loaded" end

		if cmd == "get" then
			return HttpService:JSONDecode(HttpService:JSONEncode(d))
		elseif cmd == "addShells" then
			DataService.AddShells(player, a); return d.Shells
		elseif cmd == "spendShells" then
			return DataService.SpendShells(player, a)
		elseif cmd == "give" then
			local uid = tostring(d.NextUid); d.NextUid += 1
			d.Backpack[uid] = { Id = a, Variant = b or "" }
			DataService.MarkChanged(player, "Backpack"); DataService.MarkChanged(player, "NextUid")
			return uid
		elseif cmd == "shipwreck" then
			return require(script.Parent.ShipwreckService).TriggerNow(a or 5)
		elseif cmd == "pass" then
			require(script.Parent.MonetizationService).GrantPass(player, a); return true
		elseif cmd == "product" then
			return require(script.Parent.MonetizationService).GrantProduct(player, a, b)
		elseif cmd == "stage" then
			d.Island.Stage = a
			DataService.MarkChanged(player, "Island")
			require(script.Parent.IslandService).Rebuild(player); return true
		elseif cmd == "fill" then
			-- fill every empty cell with item a (quick way to test score + idle)
			local IslandGrid = require(game.ReplicatedStorage.Shared.IslandGrid)
			for _, key in ipairs(IslandGrid.CellsForStage(d.Island.Stage)) do
				if not d.Island.Placed[key] then
					local uid = tostring(d.NextUid); d.NextUid += 1
					d.Island.Placed[key] = { Uid = uid, Id = a, Variant = "", Rot = 0 }
				end
			end
			DataService.MarkChanged(player, "Island")
			require(script.Parent.IslandService).Rebuild(player); return true
		elseif cmd == "setAttr" then
			player:SetAttribute(a, b); return true
		end
		return "unknown command"
	end
end

return DevService
