-- HOME / HUB side buttons (the server does the actual teleport).
local HUDController = require(script.Parent.HUDController)
local Remotes = game.ReplicatedStorage.Shared.Remotes

local TravelButtons = {}

function TravelButtons.Start()
	HUDController.AddSideButton("Home", "HOME", Color3.fromRGB(255, 150, 190), Color3.fromRGB(215, 70, 130), function()
		Remotes.Travel:FireServer("Home")
	end)
	HUDController.AddSideButton("Hub", "SHOPS", Color3.fromRGB(190, 140, 255), Color3.fromRGB(120, 70, 220), function()
		Remotes.Travel:FireServer("Hub")
	end)
end

return TravelButtons
