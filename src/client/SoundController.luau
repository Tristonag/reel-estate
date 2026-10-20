--[[
	SoundController
	All sound effects and the background music. Audio is from Roblox's licensed libraries
	(Pro Sound Effects, APM Music) plus a few free Creator Store clips, all checked to load in-game.

	SoundController.Play(name, pitch?, volume?)
	SoundController.Loop(name, on)     -- looping sounds like the reel whirr
	SoundController.SetMusic(on) / SetSfx(on)  -- player settings (Settings panel)
]]
local SoundService = game:GetService("SoundService")

local SoundController = {}

local SOUNDS = {
	Click   = { Id = 102702078778790, Volume = 0.45 },
	Splash  = { Id = 9125703162,  Volume = 0.55 },
	Plop    = { Id = 9125702439,  Volume = 0.45 },
	Reel    = { Id = 79404754846319, Volume = 0.35 },
	Coin    = { Id = 135483737426662, Volume = 0.45 },
	Crate   = { Id = 9120873789,  Volume = 0.6 },
	Bling   = { Id = 4612374393,  Volume = 0.55 },
	Sting   = { Id = 1844016113,  Volume = 0.5 },
	Fanfare = { Id = 1840076509,  Volume = 0.6 },
	Horn    = { Id = 113335743695644, Volume = 0.5 },
}
-- instrumental only (APM library): Hawaiian Beach, Tropical Breeze, Kona Sunset, Waikiki Beach
local MUSIC = { 1838619632, 9047134387, 9047138975, 1838922470 }
local MUSIC_VOLUME = 0.18

local folder: Folder
local cache: { [string]: Sound } = {}
local loops: { [string]: Sound } = {}
local musicSound: Sound? = nil
local musicOn, sfxOn = true, true

local function make(name: string): Sound?
	local def = SOUNDS[name]
	if not def then return nil end
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = "rbxassetid://" .. def.Id
	s.Volume = def.Volume
	s.Parent = folder
	return s
end

function SoundController.Play(name: string, pitch: number?, volume: number?)
	if not folder or not sfxOn then return end
	local base = cache[name]
	if not base then
		base = make(name)
		if not base then return end
		cache[name] = base
	end
	-- clone so overlapping plays don't cut each other off
	local s = base:Clone()
	s.PlaybackSpeed = pitch or 1
	if volume then s.Volume = volume end
	s.Parent = folder
	s:Play()
	s.Ended:Once(function() s:Destroy() end)
	task.delay(8, function() if s.Parent then s:Destroy() end end)
end

function SoundController.Loop(name: string, on: boolean)
	if not folder then return end
	local s = loops[name]
	if on and sfxOn then
		if not s then
			s = make(name)
			if not s then return end
			s.Looped = true
			loops[name] = s
		end
		if not s.IsPlaying then s:Play() end
	elseif s then
		s:Stop()
	end
end

function SoundController.SetMusic(on: boolean)
	musicOn = on
	if musicSound then
		game:GetService("TweenService"):Create(musicSound, TweenInfo.new(0.4), { Volume = on and MUSIC_VOLUME or 0 }):Play()
	end
end

function SoundController.SetSfx(on: boolean)
	sfxOn = on
	if not on then
		for _, s in pairs(loops) do s:Stop() end
	end
end

function SoundController.IsMusicOn() return musicOn end
function SoundController.IsSfxOn() return sfxOn end

function SoundController.Start()
	folder = Instance.new("Folder")
	folder.Name = "ReelEstateSounds"
	folder.Parent = SoundService
	for name in pairs(SOUNDS) do cache[name] = make(name) end

	-- background music playlist
	task.spawn(function()
		local music = Instance.new("Sound")
		music.Name = "Music"
		music.Volume = musicOn and MUSIC_VOLUME or 0
		music.Parent = folder
		musicSound = music
		local i = math.random(1, #MUSIC)
		while true do
			music.SoundId = "rbxassetid://" .. MUSIC[i]
			music:Play()
			music.Ended:Wait()
			i = (i % #MUSIC) + 1
		end
	end)
end

return SoundController
