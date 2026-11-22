--!strict
-- Small pure-Luau signal for client-side state changes.

export type Connection = { Disconnect: () -> (), Connected: boolean }

local Signal = {}
Signal.__index = Signal

export type Signal = typeof(setmetatable({} :: { _handlers: { (...any) -> () } }, Signal))

function Signal.new(): Signal
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal.Connect(self: Signal, handler: (...any) -> ()): Connection
	table.insert(self._handlers, handler)
	local connection = { Connected = true } :: any
	connection.Disconnect = function()
		if not connection.Connected then
			return
		end
		connection.Connected = false
		local index = table.find(self._handlers, handler)
		if index then
			table.remove(self._handlers, index)
		end
	end
	return connection
end

function Signal.Fire(self: Signal, ...: any)
	for _, handler in table.clone(self._handlers) do
		task.spawn(handler, ...)
	end
end

return Signal
