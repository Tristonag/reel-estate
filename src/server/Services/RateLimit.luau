-- Per-player cooldowns for remotes. Stops spam and exploit floods.
-- local ok = RateLimit.Check(player, "Cast", 0.5)
local Players = game:GetService("Players")

local RateLimit = {}
local last: { [Player]: { [string]: number } } = {}

function RateLimit.Check(player: Player, action: string, cooldown: number): boolean
	local now = os.clock()
	local t = last[player]
	if not t then t = {}; last[player] = t end
	if t[action] and now - t[action] < cooldown then return false end
	t[action] = now
	return true
end

Players.PlayerRemoving:Connect(function(p) last[p] = nil end)

return RateLimit
