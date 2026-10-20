--[[
	RevealController
	The "open the crate" moment. Shake -> flash -> rays -> item pops out -> Keep / Sell.

	RevealController.Show(result)   -- result from ReelFinish (queued if one is already showing)
	RevealController.IsOpen() -> bool

	Manual fishing: the reveal plays in full and waits for KEEP or SELL (buttons
	appear only after the item has popped out). No skipping.
	Auto-Reel: same animation, but auto-keeps after a few seconds so AFK fishing never stalls.
	"SkipReveal" player attribute (future game pass): no animation, just a quick toast.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Format = require(game.ReplicatedStorage.Shared.Format)
local ItemVisuals = require(game.ReplicatedStorage.Shared.ItemVisuals)
local ContainerVisuals = require(game.ReplicatedStorage.Shared.ContainerVisuals)
local UIKit = require(script.Parent.UIKit)
local Remotes = game.ReplicatedStorage.Shared.Remotes

local player = Players.LocalPlayer
local RevealController = {}

local gui: ScreenGui
local refs: any = {}
local queue = {}
local showing = false
local AUTO_CLOSE_AUTOREEL = 4   -- only when Auto-Reel is on
local BUTTON_DELAY = 0.9        -- item must be on screen this long before choices appear

local DRAMA = { Common = 0.7, Uncommon = 0.8, Rare = 1.0, Epic = 1.3, Legendary = 1.6, Mythic = 2.0 }

local function tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "RevealUI"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 1
	backdrop.Parent = gui

	local stage = UIKit.Frame({ Name = "Stage", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.42, 0), Size = UDim2.new(0, 300, 0, 300) })
	stage.Parent = gui

	-- sunburst rays (rotating frames)
	local rays = UIKit.Frame({ Name = "Rays", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 520, 0, 520) })
	rays.Parent = stage
	for i = 1, 10 do
		local ray = UIKit.Frame({ Name = "Ray", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 34, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Rotation = i * 18 })
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.35, 0.55),
			NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(0.65, 0.55), NumberSequenceKeypoint.new(1, 1) })
		g.Rotation = 90
		g.Parent = ray
		ray.Parent = rays
	end

	local glow = UIKit.Frame({ Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 240, 0, 240), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1 })
	UIKit.Corner(glow, 120)
	glow.Parent = stage

	local holder = UIKit.Frame({ Name = "Holder", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	holder.Parent = stage

	local flash = UIKit.Frame({ Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ZIndex = 20 })
	flash.Parent = gui

	-- item card
	local card = UIKit.Frame({ Name = "Card", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.42, 150),
		Size = UDim2.new(0, 420, 0, 190), BackgroundTransparency = 1, Visible = false })
	card.Parent = gui
	local newBadge = UIKit.Label({ Name = "New", Text = "NEW!", Size = UDim2.new(0, 110, 0, 34), Position = UDim2.new(0.5, -55, 0, -6),
		TextColor3 = Color3.fromRGB(255, 240, 90), Rotation = -6, StrokeThickness = 3 })
	newBadge.Parent = card
	local rarity = UIKit.Label({ Name = "Rarity", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0, 26), StrokeThickness = 3 })
	rarity.Parent = card
	local name = UIKit.Label({ Name = "ItemName", Size = UDim2.new(1, 0, 0, 48), Position = UDim2.new(0, 0, 0, 56), StrokeThickness = 3.5 })
	name.Parent = card
	local info = UIKit.Label({ Name = "Info", Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0, 104), TextColor3 = Color3.fromRGB(220, 220, 235) })
	info.Parent = card

	local keep = UIKit.Button({ Name = "Keep", Text = "KEEP", Size = UDim2.new(0, 170, 0, 52), Position = UDim2.new(0.5, -180, 0, 136),
		Top = Color3.fromRGB(120, 235, 130), Bottom = Color3.fromRGB(45, 170, 70) })
	keep.Parent = card
	local sell, sellLabel = UIKit.Button({ Name = "Sell", Text = "SELL", Size = UDim2.new(0, 170, 0, 52), Position = UDim2.new(0.5, 10, 0, 136),
		Top = Color3.fromRGB(255, 200, 90), Bottom = Color3.fromRGB(235, 130, 30) })
	sell.Parent = card
	local ok = UIKit.Button({ Name = "Ok", Text = "OK", Size = UDim2.new(0, 170, 0, 52), Position = UDim2.new(0.5, -85, 0, 136),
		Top = Color3.fromRGB(120, 200, 255), Bottom = Color3.fromRGB(50, 120, 230) })
	ok.Parent = card

	refs = { Backdrop = backdrop, Stage = stage, Rays = rays, Glow = glow, Holder = holder, Flash = flash, Card = card,
		New = newBadge, Rarity = rarity, Name = name, Info = info, Keep = keep, Sell = sell, SellLabel = sellLabel, Ok = ok }
end

local function clearHolder()
	for _, c in ipairs(refs.Holder:GetChildren()) do c:Destroy() end
end

local function setRays(color: Color3, transparency: number, t: number)
	for _, r in ipairs(refs.Rays:GetChildren()) do
		r.BackgroundColor3 = color
		tween(r, t, { BackgroundTransparency = transparency })
	end
end

local function play(result)
	showing = true
	gui.Enabled = true
	clearHolder()
	refs.Card.Visible = false
	refs.Rays.Rotation = 0
	setRays(Color3.new(1, 1, 1), 1, 0)
	refs.Glow.BackgroundTransparency = 1

	local item = Config.Items[result.ItemId]
	local rarityInfo = Config.Rarities[result.Rarity]
	local color = rarityInfo and rarityInfo.Color or Color3.new(1, 1, 1)
	local drama = DRAMA[result.Rarity] or 1

	tween(refs.Backdrop, 0.25, { BackgroundTransparency = 0.45 })

	-- 1) container shakes harder and harder
	local containerModel = ContainerVisuals.Build(result.Container)
	local vp, model, cam = UIKit.Viewport(refs.Holder, containerModel, { Zoom = 1.3 })
	local base = model:GetPivot()
	UIKit.Pop(vp)
	local shakeTime = 0.9 * drama
	local t0 = os.clock()
	while os.clock() - t0 < shakeTime do
		local a = (os.clock() - t0) / shakeTime
		local amp = 0.05 + a * a * 0.5
		model:PivotTo(base * CFrame.new((math.random() - 0.5) * amp, (math.random() - 0.5) * amp, 0)
			* CFrame.Angles(0, 0, (math.random() - 0.5) * amp * 0.6))
		refs.Glow.BackgroundColor3 = color
		refs.Glow.BackgroundTransparency = 1 - a * 0.5
		RunService.RenderStepped:Wait()
	end

	-- 2) flash + burst (+ sound by rarity)
	do
		local ok, sc = pcall(require, script.Parent.SoundController)
		if ok then
			sc.Play("Crate", 1.1)
			local tier = rarityInfo and rarityInfo.Tier or 1
			if tier >= 5 then sc.Play("Fanfare")
			elseif tier >= 4 then sc.Play("Sting", 1.1)
			else sc.Play("Bling", 0.9 + tier * 0.1) end
		end
	end
	refs.Flash.BackgroundTransparency = (result.Rarity == "Legendary" or result.Rarity == "Mythic") and 0 or 0.35
	tween(refs.Flash, 0.5, { BackgroundTransparency = 1 })
	vp:Destroy()

	-- 3) item pops out with rays
	setRays(color, 0, 0.3)
	tween(refs.Glow, 0.3, { BackgroundTransparency = 0.55 })
	local itemModel = ItemVisuals.Build(result.ItemId, result.Variant)
	local ivp, imodel, icam = UIKit.Viewport(refs.Holder, itemModel, { Zoom = 1.25 })
	UIKit.Pop(ivp)
	local ibase = imodel:GetPivot()

	refs.New.Visible = result.IsNew == true
	refs.Rarity.Text = string.upper(result.Rarity)
	refs.Rarity.TextColor3 = color
	local prefix = result.Variant ~= "" and (result.Variant .. " ") or ""
	refs.Name.Text = prefix .. (item and item.Name or result.ItemId)
	refs.Name.TextColor3 = result.Variant == "Golden" and Color3.fromRGB(255, 215, 80) or Color3.new(1, 1, 1)

	local sold = result.Sold == true
	refs.Keep.Visible = false
	refs.Sell.Visible = false
	refs.Ok.Visible = false
	if sold then
		refs.Info.Text = ("Backpack full! Auto-sold for %s Shells"):format(Format.Comma(result.Value))
	else
		local set = item and item.Set or ""
		refs.Info.Text = ("%s set  |  Worth %s Shells"):format(set, Format.Comma(result.Value))
		refs.SellLabel.Text = "SELL +" .. Format.Short(result.Value)
	end
	refs.Card.Visible = true
	UIKit.Pop(refs.Card)

	-- 4) wait for a choice (or auto-keep)
	local choice = nil
	local conns = {}
	local function choose(c) if not choice then choice = c end end
	table.insert(conns, refs.Keep.Activated:Connect(function() choose("keep") end))
	table.insert(conns, refs.Ok.Activated:Connect(function() choose("keep") end))
	table.insert(conns, refs.Sell.Activated:Connect(function() choose("sell") end))
	local autoReel = player:GetAttribute("AutoReel") == true
	local start = os.clock()
	local buttonsShown = false
	while not choice do
		local t = os.clock() - start
		refs.Rays.Rotation = t * 25
		imodel:PivotTo(ibase * CFrame.Angles(0, t * 1.2, 0))
		if not buttonsShown and t >= BUTTON_DELAY then
			buttonsShown = true
			refs.Keep.Visible = not sold
			refs.Sell.Visible = not sold
			refs.Ok.Visible = sold
			if sold then UIKit.Pop(refs.Ok) else UIKit.Pop(refs.Keep); UIKit.Pop(refs.Sell) end
		end
		if autoReel and t > AUTO_CLOSE_AUTOREEL then choice = "keep" end
		RunService.RenderStepped:Wait()
	end
	for _, c in ipairs(conns) do c:Disconnect() end

	if choice == "sell" and result.Uid then
		task.spawn(function()
			pcall(function() Remotes.SellItems:InvokeServer({ result.Uid }) end)
		end)
	end

	-- 5) close
	refs.Card.Visible = false
	setRays(color, 1, 0.2)
	tween(refs.Glow, 0.2, { BackgroundTransparency = 1 })
	tween(refs.Backdrop, 0.2, { BackgroundTransparency = 1 })
	clearHolder()
	task.wait(0.2)
	gui.Enabled = false
	showing = false
end

local pumping = false
local function pump()
	if pumping then return end
	pumping = true
	while #queue > 0 do
		play(table.remove(queue, 1))
	end
	pumping = false
end

-- quick toast used when the player owns Skip Reveal
local function quickToast(result)
	local item = Config.Items[result.ItemId]
	local color = Config.Rarities[result.Rarity] and Config.Rarities[result.Rarity].Color or Color3.new(1, 1, 1)
	local prefix = result.Variant ~= "" and (result.Variant .. " ") or ""
	local text = (result.IsNew and "NEW! " or "") .. prefix .. (item and item.Name or result.ItemId)
	if result.Sold then text ..= "  (auto-sold)" end
	local l = UIKit.Label({ Text = text, TextColor3 = color, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 120), Size = UDim2.new(0, 480, 0, 40), StrokeThickness = 3 })
	l.Parent = player.PlayerGui:FindFirstChild("HUD") or gui
	UIKit.Pop(l)
	task.delay(2, function()
		TweenService:Create(l, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		TweenService:Create(l:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.4), { Transparency = 1 }):Play()
		task.wait(0.45)
		l:Destroy()
	end)
end

function RevealController.Show(result)
	-- Quick Fish: skip the animation when the toggle is on and the Skip Reveal pass is owned
	local FishSettings = require(script.Parent.FishSettings)
	if FishSettings.QuickFish and player:GetAttribute("Pass_SkipReveal") == true then
		quickToast(result)
		return
	end
	table.insert(queue, result)
	task.spawn(pump)
end

function RevealController.IsOpen(): boolean
	return showing
end

function RevealController.Start()
	build()
	game.ReplicatedStorage.Shared.Remotes.ShowReveal.OnClientEvent:Connect(function(result)
		RevealController.Show(result)
	end)
end

return RevealController
