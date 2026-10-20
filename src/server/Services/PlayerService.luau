--[[
	PlayerService
	- leaderstats
	- replicates data changes to the owning client
	- free Auto-Reel for group members (checked by the server, never trusted from the client)
	- playtime tracking
]]
local Players = game:GetService("Players")
local GroupService = game:GetService("GroupService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local RateLimit = require(script.Parent.RateLimit)

local Remotes = game.ReplicatedStorage.Shared.Remotes

local PlayerService = {}

local function isInGroupFresh(player: Player): boolean
	local groupId = Config.Group.GroupId
	if groupId == 0 then return false end
	-- GetGroupsAsync is not cached per server like IsInGroup, so a player who joins mid-session gets unlocked
	local ok, groups = pcall(GroupService.GetGroupsAsync, GroupService, player.UserId)
	if not ok then return false end
	for _, g in ipairs(groups) do
		if g.Id == groupId then return true end
	end
	return false
end

local function refreshGroupReward(player: Player)
	local inGroup = isInGroupFresh(player)
	player:SetAttribute("InGroup", inGroup)
	-- Auto-Reel is free for group members. Game pass owners will also get it (Phase 9).
	player:SetAttribute("AutoReel", inGroup or player:GetAttribute("Pass_TurboReel") == true)
end

local function setupLeaderstats(player: Player, data)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local shells = Instance.new("IntValue")
	shells.Name = "Shells"
	shells.Value = data.Shells
	shells.Parent = ls
	local rb = Instance.new("IntValue")
	rb.Name = "Rebirths"
	rb.Value = data.Rebirths or 0
	rb.Parent = ls
	ls.Parent = player
	player:SetAttribute("Rebirths", data.Rebirths or 0)
end

function PlayerService.Start()
	DataService.Loaded.Event:Connect(function(player: Player, data)
		setupLeaderstats(player, data)
		task.spawn(refreshGroupReward, player)
		player:GetAttributeChangedSignal("Pass_TurboReel"):Connect(function()
			if player:GetAttribute("Pass_TurboReel") then player:SetAttribute("AutoReel", true) end
		end)
		player:SetAttribute("DataLoaded", true)
	end)

	DataService.Changed.Event:Connect(function(player: Player, key: string, value: any)
		if key == "Shells" then
			local ls = player:FindFirstChild("leaderstats")
			local v = ls and ls:FindFirstChild("Shells")
			if v then v.Value = value end
		end
		if key == "Rebirths" then
			local ls = player:FindFirstChild("leaderstats")
			local v = ls and ls:FindFirstChild("Rebirths")
			if v then v.Value = value end
			player:SetAttribute("Rebirths", value)
		end
		if player.Parent then
			Remotes.DataUpdated:FireClient(player, key, value)
		end
	end)

	Remotes.GetData.OnServerInvoke = function(player: Player)
		return DataService.WaitFor(player, 30)
	end

	Remotes.TutorialDone.OnServerEvent:Connect(function(player: Player)
		local d = DataService.Get(player)
		if d and not d.Flags.TutorialDone then
			d.Flags.TutorialDone = true
			DataService.MarkChanged(player, "Flags")
		end
	end)

	Remotes.SaveSettings.OnServerEvent:Connect(function(player: Player, key: any, value: any)
		if not RateLimit.Check(player, "Settings", 0.2) then return end
		if (key ~= "Music" and key ~= "Sfx") or type(value) ~= "boolean" then return end
		local d = DataService.Get(player)
		if not d then return end
		d.Settings = d.Settings or {}
		d.Settings[key] = value
	end)

	Remotes.RecheckGroup.OnServerEvent:Connect(function(player: Player)
		if not RateLimit.Check(player, "RecheckGroup", 10) then return end
		refreshGroupReward(player)
	end)

	-- Playtime tracker (nested stat, no need to replicate every minute)
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in ipairs(Players:GetPlayers()) do
				local d = DataService.Get(player)
				if d then d.Stats.PlaySeconds += 60 end
			end
		end
	end)
end

return PlayerService
