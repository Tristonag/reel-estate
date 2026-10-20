--[[
	StatusUI
	- "+X/s" idle income under the Shells counter
	- equipped bait pill with uses left
	- "While you were away" offline earnings popup
]]
local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Format = require(game.ReplicatedStorage.Shared.Format)
local ClientData = require(script.Parent.ClientData)
local UIKit = require(script.Parent.UIKit)
local Remotes = game.ReplicatedStorage.Shared.Remotes

local player = Players.LocalPlayer
local StatusUI = {}

local function formatTime(seconds: number): string
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	if h > 0 then return h .. "h " .. m .. "m" end
	return m .. "m"
end

function StatusUI.Start()
	local gui = player.PlayerGui:WaitForChild("HUD")
	local pill = gui:WaitForChild("Shells")

	local idle = UIKit.Label({ Name = "IdleRate", Text = "", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0, 200, 0, 22),
		Position = UDim2.new(0.5, 0, 0, 70), TextColor3 = Color3.fromRGB(160, 255, 180) })
	idle.Parent = gui
	local function refreshIdle()
		local rate = player:GetAttribute("IdleRate") or 0
		idle.Text = rate > 0 and ("+" .. (rate >= 10 and Format.Short(rate) or string.format("%.1f", rate)) .. " / sec") or ""
	end
	player:GetAttributeChangedSignal("IdleRate"):Connect(refreshIdle)
	refreshIdle()

	-- bait pill (bottom right, above the fishing bars' height)
	local bait = UIKit.Frame({ Name = "Bait", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -96),
		Size = UDim2.new(0, 190, 0, 40), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false })
	UIKit.Corner(bait, 20)
	UIKit.Stroke(bait, 3, UIKit.Dark, true)
	UIKit.Gradient(bait, Color3.fromRGB(255, 190, 120), Color3.fromRGB(220, 120, 50))
	bait.Parent = gui
	local baitLabel = UIKit.Label({ Size = UDim2.new(1, -20, 0.7, 0), Position = UDim2.new(0, 10, 0.15, 0) })
	baitLabel.Parent = bait
	local function refreshBait()
		local d = ClientData.Get()
		local id = d.EquippedBait
		local b = id ~= "" and Config.Baits[id]
		if b and (d.Baits[id] or 0) > 0 then
			bait.Visible = true
			baitLabel.Text = ("%s bait  x%d"):format(b.Name, d.Baits[id])
		else
			bait.Visible = false
		end
	end
	ClientData.OnChanged("EquippedBait", refreshBait)
	ClientData.OnChanged("Baits", refreshBait)

	-- offline earnings popup
	local shownOffline = false
	local function showOffline(amount: number, seconds: number, capped: boolean)
		local pop = UIKit.Frame({ Name = "Offline", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.new(0, 380, 0, 220), BackgroundColor3 = Color3.new(1, 1, 1) })
		UIKit.Corner(pop, 20)
		UIKit.Stroke(pop, 5, Color3.fromRGB(20, 10, 40), true)
		UIKit.Gradient(pop, Color3.fromRGB(80, 190, 230), Color3.fromRGB(30, 110, 170))
		pop.Parent = gui
		local t = UIKit.Label({ Text = "Welcome back!", Size = UDim2.new(1, -30, 0, 38), Position = UDim2.new(0, 15, 0, 16), StrokeThickness = 3 })
		t.Parent = pop
		local s = UIKit.Label({ Text = ("Your island earned while you were away (%s%s)"):format(formatTime(seconds), capped and ", max" or ""),
			Size = UDim2.new(1, -30, 0, 20), Position = UDim2.new(0, 15, 0, 58), TextColor3 = Color3.fromRGB(225, 240, 255) })
		s.Parent = pop
		local a = UIKit.Label({ Text = "+" .. Format.Comma(amount) .. " Shells", Size = UDim2.new(1, -30, 0, 46), Position = UDim2.new(0, 15, 0, 88),
			TextColor3 = Color3.fromRGB(255, 230, 110), StrokeThickness = 3.5 })
		a.Parent = pop
		local ok = UIKit.Button({ Name = "Collect", Text = "COLLECT", Size = UDim2.new(0, 200, 0, 50), Position = UDim2.new(0.5, -100, 1, -66),
			Top = Color3.fromRGB(120, 235, 130), Bottom = Color3.fromRGB(45, 170, 70) }, function() pop:Destroy() end)
		ok.Parent = pop
		UIKit.Pop(pop)
	end
	local function checkOffline()
		local v = player:GetAttribute("OfflineEarned")
		if shownOffline or type(v) ~= "string" then return end
		local amount, seconds, capped = v:match("^(%d+)|(%d+)|(%a+)$")
		if not amount then return end
		shownOffline = true
		showOffline(tonumber(amount), tonumber(seconds), capped == "true")
	end
	player:GetAttributeChangedSignal("OfflineEarned"):Connect(checkOffline)
	checkOffline()
end

return StatusUI
