--[[
	ClientData
	Read-only mirror of the local player's save data. The server is the only
	one that changes data; this just listens and exposes it to UI.

	ClientData.Get() -> data (waits for first snapshot)
	ClientData.OnChanged(key, callback(value))  -- also fires once immediately with current value
	ClientData.Changed (BindableEvent) Fired(key, value)
]]
local Remotes = game.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")

local ClientData = {}
ClientData.Changed = Instance.new("BindableEvent")

local data = nil
local ready = Instance.new("BindableEvent")

function ClientData.Get()
	if not data then ready.Event:Wait() end
	return data
end

function ClientData.OnChanged(key: string, callback: (any) -> ())
	task.spawn(function()
		callback(ClientData.Get()[key])
	end)
	return ClientData.Changed.Event:Connect(function(k, v)
		if k == key then callback(v) end
	end)
end

Remotes.DataUpdated.OnClientEvent:Connect(function(key, value)
	if not data then return end -- snapshot below will contain it
	data[key] = value
	ClientData.Changed:Fire(key, value)
end)

task.spawn(function()
	local snapshot
	repeat
		local ok, result = pcall(function() return Remotes.GetData:InvokeServer() end)
		if ok then snapshot = result else task.wait(1) end
	until snapshot
	data = snapshot
	ready:Fire()
end)

return ClientData
