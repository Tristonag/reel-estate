--[[
	ShopService
	BuyRod(tier)    -> { Ok, Reason? }   rods are bought in order (next tier only)
	EquipRod(tier)  -> { Ok }            any tier you own
	BuyBait(id)     -> { Ok, Reason? }   adds one pack (Uses) and auto-equips if nothing is equipped
	EquipBait(id|"")-> { Ok }
	Also tints the rod tool to the equipped rod's color.
]]
local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local RateLimit = require(script.Parent.RateLimit)
local Remotes = game.ReplicatedStorage.Shared.Remotes

local ShopService = {}

local function paintRod(player: Player)
	local data = DataService.Get(player)
	if not data then return end
	local rod = Config.Rods[data.EquippedRod] or Config.Rods[1]
	local color = Color3.fromRGB(rod.Color[1], rod.Color[2], rod.Color[3])
	for _, container in ipairs({ player:FindFirstChild("Backpack"), player.Character }) do
		local tool = container and container:FindFirstChild("Rod")
		local handle = tool and tool:FindFirstChild("Handle")
		if handle then
			handle.Color = color
			handle.Material = (data.EquippedRod >= 6) and Enum.Material.Metal or Enum.Material.Wood
			tool.ToolTip = rod.Name
		end
	end
end

local function onBuyRod(player: Player, tier: any)
	if type(tier) ~= "number" or not RateLimit.Check(player, "Shop", 0.3) then return { Ok = false } end
	local data = DataService.Get(player)
	if not data then return { Ok = false } end
	if tier ~= data.RodTier + 1 then return { Ok = false, Reason = "Order" } end
	local rod = Config.Rods[tier]
	if not rod then return { Ok = false, Reason = "Max" } end
	if not DataService.SpendShells(player, rod.Price) then return { Ok = false, Reason = "NotEnough" } end
	data.RodTier = tier
	data.EquippedRod = tier
	DataService.MarkChanged(player, "RodTier")
	DataService.MarkChanged(player, "EquippedRod")
	paintRod(player)
	return { Ok = true }
end

local function onEquipRod(player: Player, tier: any)
	if type(tier) ~= "number" or not RateLimit.Check(player, "Shop", 0.3) then return { Ok = false } end
	local data = DataService.Get(player)
	if not data or tier < 1 or tier > data.RodTier or tier % 1 ~= 0 then return { Ok = false } end
	data.EquippedRod = tier
	DataService.MarkChanged(player, "EquippedRod")
	paintRod(player)
	return { Ok = true }
end

local function onBuyBait(player: Player, id: any)
	if type(id) ~= "string" or not RateLimit.Check(player, "Shop", 0.3) then return { Ok = false } end
	local bait = Config.Baits[id]
	local data = DataService.Get(player)
	if not bait or not data then return { Ok = false } end
	if not DataService.SpendShells(player, bait.Price) then return { Ok = false, Reason = "NotEnough" } end
	data.Baits[id] = (data.Baits[id] or 0) + bait.Uses
	if data.EquippedBait == "" then
		data.EquippedBait = id
		DataService.MarkChanged(player, "EquippedBait")
	end
	DataService.MarkChanged(player, "Baits")
	return { Ok = true }
end

local function onEquipBait(player: Player, id: any)
	if type(id) ~= "string" or not RateLimit.Check(player, "Shop", 0.2) then return { Ok = false } end
	local data = DataService.Get(player)
	if not data then return { Ok = false } end
	if id ~= "" and (not Config.Baits[id] or (data.Baits[id] or 0) <= 0) then return { Ok = false } end
	data.EquippedBait = id
	DataService.MarkChanged(player, "EquippedBait")
	return { Ok = true }
end

function ShopService.Start()
	Remotes.BuyRod.OnServerInvoke = onBuyRod
	Remotes.EquipRod.OnServerInvoke = onEquipRod
	Remotes.BuyBait.OnServerInvoke = onBuyBait
	Remotes.EquipBait.OnServerInvoke = onEquipBait

	-- tint the rod whenever a fresh one is given (respawn) or data loads
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(char)
			task.wait(0.5)
			paintRod(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in ipairs(Players:GetPlayers()) do watch(p) end
	DataService.Loaded.Event:Connect(function(player) task.delay(1, paintRod, player) end)
	DataService.Changed.Event:Connect(function(player, key)
		if key == "EquippedRod" then paintRod(player) end
	end)
end

return ShopService
