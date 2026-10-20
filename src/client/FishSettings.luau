-- Client-side fishing toggles shared by the fishing bar and the reveal.
local FishSettings = {
	QuickFish = false,   -- skip the crate reveal (needs the Skip Reveal pass)
	AutoFish = false,    -- auto-aim, cast and reel (free with the group or Turbo Reel)
	Changed = Instance.new("BindableEvent"),
}

function FishSettings.Set(key: string, value: boolean)
	FishSettings[key] = value
	FishSettings.Changed:Fire(key, value)
end

return FishSettings
