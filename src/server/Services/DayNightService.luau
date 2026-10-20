--[[
	DayNightService
	A gentle day/night cycle: long sunny days, a short golden sunset, a bright moonlit night
	(so crates stay easy to see) and a sunrise. One full day = Config-free constant below.
	Lanterns, torches and neon already glow, so nights look great without extra work.
]]
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local DayNightService = {}
local DAY_LENGTH = 20 * 60   -- seconds for a full 24h cycle

-- per hour of the clock: brightness, outdoor ambient, atmosphere color
local KEYS = {
	{ 0,  1.2, Color3.fromRGB(95, 110, 160),  Color3.fromRGB(80, 100, 150) },
	{ 5,  1.2, Color3.fromRGB(95, 110, 160),  Color3.fromRGB(80, 100, 150) },
	{ 6.5, 2.2, Color3.fromRGB(160, 140, 150), Color3.fromRGB(255, 190, 160) },
	{ 8,  2.6, Color3.fromRGB(140, 150, 165), Color3.fromRGB(200, 230, 245) },
	{ 17, 2.6, Color3.fromRGB(140, 150, 165), Color3.fromRGB(200, 230, 245) },
	{ 18.5, 2.1, Color3.fromRGB(170, 130, 120), Color3.fromRGB(255, 170, 120) },
	{ 20, 1.2, Color3.fromRGB(95, 110, 160),  Color3.fromRGB(80, 100, 150) },
	{ 24, 1.2, Color3.fromRGB(95, 110, 160),  Color3.fromRGB(80, 100, 150) },
}

local function sample(hour: number)
	for i = 1, #KEYS - 1 do
		local a, b = KEYS[i], KEYS[i + 1]
		if hour >= a[1] and hour <= b[1] then
			local t = (hour - a[1]) / math.max(b[1] - a[1], 0.001)
			return a[2] + (b[2] - a[2]) * t, a[3]:Lerp(b[3], t), a[4]:Lerp(b[4], t)
		end
	end
	return KEYS[1][2], KEYS[1][3], KEYS[1][4]
end

function DayNightService.Start()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	Lighting.ClockTime = 9
	task.spawn(function()
		while true do
			local dt = task.wait(1)
			-- days run at normal pace; nights (20:00 to 05:00) pass twice as fast so they stay short
			local hour = Lighting.ClockTime
			local speed = (hour >= 20 or hour < 5) and 2 or 1
			Lighting.ClockTime = (hour + dt * speed * 24 / DAY_LENGTH) % 24
			local brightness, ambient, haze = sample(Lighting.ClockTime)
			Lighting.Brightness = brightness
			Lighting.OutdoorAmbient = ambient
			if atmosphere then atmosphere.Color = haze end
		end
	end)
end

return DayNightService
