-- Number formatting for UI.
local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

-- 1234 -> "1.23K", 1500000 -> "1.5M"
function Format.Short(n: number): string
	n = math.floor(n)
	if math.abs(n) < 1000 then return tostring(n) end
	local i = 1
	local v = n
	while math.abs(v) >= 1000 and i < #SUFFIXES do
		v /= 1000
		i += 1
	end
	local s = v >= 100 and string.format("%.0f", v) or v >= 10 and string.format("%.1f", v) or string.format("%.2f", v)
	if s:find(".", 1, true) then s = s:gsub("0+$", ""):gsub("%.$", "") end
	return s .. SUFFIXES[i]
end

-- 1234567 -> "1,234,567"
function Format.Comma(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""):gsub("^%-,", "-"))
end

return Format
