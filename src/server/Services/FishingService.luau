--[[
	FishingService
	Server side of cast -> reel -> catch. The client never decides what it catches,
	whether it hooked something, or how fast a reel can finish.

	Remotes
		Cast:InvokeServer(direction: Vector3, charge: number) -> result table
		ReelFinish:InvokeServer(success: boolean) -> result table
]]
local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local FloaterService = require(script.Parent.FloaterService)
local LootService = require(script.Parent.LootService)
local RateLimit = require(script.Parent.RateLimit)
local BookService = require(script.Parent.BookService)
local ShipwreckService = require(script.Parent.ShipwreckService)
local InventoryService = require(script.Parent.InventoryService)
local PerkService = require(script.Parent.PerkService)

local Remotes = game.ReplicatedStorage.Shared.Remotes
local F = Config.Fishing

local FishingService = {}

type Session = { FloaterId: string, Container: string, Start: number, MinTime: number, Event: boolean? }
local sessions: { [Player]: Session } = {}

local function isFiniteNumber(n)
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function endSession(player: Player, keepFloater: boolean?)
	local s = sessions[player]
	sessions[player] = nil
	if s and not keepFloater then FloaterService.Release(s.FloaterId) end
	return s
end

local function getLuck(data, player: Player?): number
	local rod = Config.Rods[data.EquippedRod] or Config.Rods[1]
	local luck = rod.Luck * BookService.LuckMultiplier(data) * (player and PerkService.LuckMult(player) or 1)
	local bait = data.EquippedBait ~= "" and Config.Baits[data.EquippedBait]
	if bait and (data.Baits[data.EquippedBait] or 0) > 0 then
		luck *= bait.Luck
	end
	return luck
end

local function consumeBait(player: Player, data)
	local id = data.EquippedBait
	if id == "" then return end
	local left = (data.Baits[id] or 0) - 1
	if left <= 0 then
		data.Baits[id] = nil
		data.EquippedBait = ""
		DataService.MarkChanged(player, "EquippedBait")
	else
		data.Baits[id] = left
	end
	DataService.MarkChanged(player, "Baits")
end

local function countBackpack(data): number
	local n = 0
	for _ in pairs(data.Backpack) do n += 1 end
	return n
end

local function onCast(player: Player, direction: any, charge: any)
	if typeof(direction) ~= "Vector3" or not isFiniteNumber(charge) then return { Ok = false, Reason = "Bad" } end
	if not RateLimit.Check(player, "Cast", 0.6) then return { Ok = false, Reason = "TooFast" } end
	if sessions[player] then return { Ok = false, Reason = "Busy" } end

	local data = DataService.Get(player)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not data or not hrp or not humanoid or humanoid.Health <= 0 then return { Ok = false, Reason = "NotReady" } end

	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.01 or flat.Magnitude ~= flat.Magnitude then return { Ok = false, Reason = "Bad" } end
	flat = flat.Unit
	charge = math.clamp(charge, F.MinCharge, 1)

	local rod = Config.Rods[data.EquippedRod] or Config.Rods[1]
	local origin = hrp.Position
	local landing = origin + flat * (charge * rod.MaxDistance)
	landing = Vector3.new(landing.X, Config.World.WaterLevel, landing.Z)

	local floater = FloaterService.FindHookable(landing, F.HookRadius)
	if not floater then
		return { Ok = true, Hooked = false, Landing = landing }
	end

	local reach = (Vector3.new(floater.Position.X, 0, floater.Position.Z) - Vector3.new(origin.X, 0, origin.Z)).Magnitude
	if reach > rod.MaxDistance + F.HookRadius then
		return { Ok = true, Hooked = false, Landing = landing }
	end

	local container = Config.Containers[floater.Container]
	if data.EquippedRod < container.MinRod and not floater.Event then
		return { Ok = true, Hooked = false, Landing = landing, Reason = "RodTooWeak", NeedRod = container.MinRod, Container = floater.Container }
	end

	if not FloaterService.Claim(floater.Id, player) then
		return { Ok = true, Hooked = false, Landing = landing }
	end

	local fillRate = F.BaseFillRate * rod.ReelPower / container.ReelDifficulty
	local fastest = (1 - F.StartProgress) / fillRate
	sessions[player] = {
		FloaterId = floater.Id,
		Container = floater.Container,
		Start = os.clock(),
		MinTime = F.MinBiteSeconds + fastest * F.ReelTimeTolerance,
		Event = floater.Event == true,
	}

	return {
		Ok = true,
		Hooked = true,
		Landing = landing,
		FloaterId = floater.Id,
		Container = floater.Container,
		Position = floater.Position,
		FillRate = fillRate,
		StartProgress = F.StartProgress,
		DrainRate = F.DrainRate,
		Difficulty = container.ReelDifficulty / rod.ReelPower,
	}
end

local function onReelFinish(player: Player, success: any)
	local s = sessions[player]
	if not s then return { Ok = false, Reason = "NoSession" } end

	local elapsed = os.clock() - s.Start
	if success ~= true then
		endSession(player)
		return { Ok = true, Caught = false }
	end
	if elapsed < s.MinTime then
		warn(("[FishingService] %s finished a reel too fast (%.2fs < %.2fs), rejected"):format(player.Name, elapsed, s.MinTime))
		endSession(player)
		return { Ok = true, Caught = false, Reason = "TooFast" }
	end

	local floater = FloaterService.Get(s.FloaterId)
	if not floater or floater.ClaimedBy ~= player then
		endSession(player)
		return { Ok = true, Caught = false }
	end

	local data = DataService.Get(player)
	if not data then
		endSession(player)
		return { Ok = false, Reason = "NotReady" }
	end

	endSession(player, true)
	FloaterService.Remove(s.FloaterId)

	local luck = getLuck(data, player)
	if s.Event then
		luck *= Config.Shipwreck.LuckBonus
		ShipwreckService.NoteCatch(player)
	end
	consumeBait(player, data)
	local itemId, variant, rarity = LootService.Roll(s.Container, luck)
	
	-- stats
	data.Stats.Catches += 1
	data.Stats.ContainersOpened[s.Container] = (data.Stats.ContainersOpened[s.Container] or 0) + 1
	DataService.MarkChanged(player, "Stats")

	local result = InventoryService.GiveItem(player, itemId, variant, rarity)
	if not result then return { Ok = false } end
	result.Container = s.Container
	result.Event = s.Event
	return result
end

function FishingService.Start()
	Remotes.Cast.OnServerInvoke = onCast
	Remotes.ReelFinish.OnServerInvoke = onReelFinish

	Players.PlayerRemoving:Connect(function(player) endSession(player) end)

	-- reels that never finish (disconnect, exploit, bug) release their floater
	task.spawn(function()
		while true do
			task.wait(2)
			local now = os.clock()
			for player, s in pairs(sessions) do
				if now - s.Start > F.ReelTimeout then endSession(player) end
			end
		end
	end)
end

return FishingService
