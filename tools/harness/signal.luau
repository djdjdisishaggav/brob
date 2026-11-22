-- Minimal RBXScriptSignal stand-in for the headless harness.
local task = require("@lune/task")

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ handlers = {}, waiting = {} }, Signal)
end

function Signal:Connect(fn)
	local handlers = self.handlers
	local conn = { Connected = true }
	local entry = { fn = fn, conn = conn }
	table.insert(handlers, entry)
	function conn.Disconnect()
		if not conn.Connected then
			return
		end
		conn.Connected = false
		local index = table.find(handlers, entry)
		if index then
			table.remove(handlers, index)
		end
	end
	return conn
end

function Signal:Once(fn)
	local conn
	conn = self:Connect(function(...)
		conn.Disconnect()
		fn(...)
	end)
	return conn
end

function Signal:ConnectParallel(fn)
	return self:Connect(fn)
end

function Signal:Wait()
	table.insert(self.waiting, coroutine.running())
	return coroutine.yield()
end

function Signal:Fire(...)
	for _, entry in table.clone(self.handlers) do
		if entry.conn.Connected then
			task.spawn(entry.fn, ...)
		end
	end
	local waiting = self.waiting
	self.waiting = {}
	for _, thread in waiting do
		task.spawn(thread, ...)
	end
end

return Signal
