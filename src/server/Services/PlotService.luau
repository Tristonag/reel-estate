--[[
	PlotService
	Assigns each player one of the plots on the ring and spawns them there.
	IslandService builds and owns the island model for each plot.

	PlotService.GetPlot(player) -> plot index or nil
	PlotService.GetOwner(index) -> player or nil
	PlotService.GetPlotCFrame(index) -> CFrame at plot center on the water, LookVector = outward (towards open sea)
	PlotService.GetIslandRadius(index) -> current island radius in studs (depends on owner's stage)
	PlotService.Assigned / PlotService.Freed (BindableEvent) Fired(player, index)
]]
local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local IslandGrid = require(game.ReplicatedStorage.Shared.IslandGrid)
local DataService = require(script.Parent.DataService)
local RateLimit = require(script.Parent.RateLimit)

local HUB_SPAWN = CFrame.lookAt(Vector3.new(0, 5.5, 16), Vector3.new(0, 5.5, 0))

local PlotService = {}
PlotService.Assigned = Instance.new("BindableEvent")
PlotService.Freed = Instance.new("BindableEvent")

local owners: { [number]: Player } = {}
local byPlayer: { [Player]: number } = {}
local plotsFolder: Folder

function PlotService.GetPlotCFrame(index: number): CFrame
	return IslandGrid.PlotCFrame(index)
end

function PlotService.GetPlot(player: Player): number?
	return byPlayer[player]
end

function PlotService.GetOwner(index: number): Player?
	return owners[index]
end

function PlotService.GetIslandRadius(index: number): number
	local owner = owners[index]
	local data = owner and DataService.Get(owner)
	return IslandGrid.Radius(data and data.Island.Stage or 1)
end

local function spawnAtPlot(player: Player, character: Model)
	local index = byPlayer[player]
	if not index then return end
	local cf = PlotService.GetPlotCFrame(index)
	local hrp = character:WaitForChild("HumanoidRootPart", 5)
	if hrp then
		character:PivotTo(cf * CFrame.new(0, 4, 0))
	end
end

local function assign(player: Player)
	for i = 1, Config.Plots.Count do
		if not owners[i] then
			owners[i] = player
			byPlayer[player] = i
			player:SetAttribute("Plot", i)
			return i
		end
	end
	return nil
end

-- Travel:FireServer("Home" | "Hub")
local function onTravel(player: Player, destination: any)
	if destination ~= "Home" and destination ~= "Hub" then return end
	if not RateLimit.Check(player, "Travel", 2) then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	if destination == "Home" then
		spawnAtPlot(player, character)
	else
		character:PivotTo(HUB_SPAWN)
	end
end

function PlotService.Start()
	game.ReplicatedStorage.Shared.Remotes.Travel.OnServerEvent:Connect(onTravel)
	plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = workspace
	PlotService.Folder = plotsFolder

	DataService.Loaded.Event:Connect(function(player: Player)
		local index = assign(player)
		if not index then
			player:Kick("Server is full, please join another server.")
			return
		end
		PlotService.Assigned:Fire(player, index)
		if player.Character then spawnAtPlot(player, player.Character) end
	end)

	local function hookCharacter(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.defer(spawnAtPlot, player, character)
		end)
	end
	Players.PlayerAdded:Connect(hookCharacter)
	for _, p in ipairs(Players:GetPlayers()) do hookCharacter(p) end

	Players.PlayerRemoving:Connect(function(player)
		local index = byPlayer[player]
		if not index then return end
		byPlayer[player] = nil
		owners[index] = nil
		PlotService.Freed:Fire(player, index)
	end)
end

return PlotService
