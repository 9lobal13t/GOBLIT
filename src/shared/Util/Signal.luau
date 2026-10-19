--!strict
-- Синхронный сигнал для событий между модулями одной стороны (сервер или клиент).
-- Обработчики вызываются в порядке подключения; ошибка одного не мешает остальным
-- и попадает в ErrorReporter. Обработчик не должен надолго уступать управление:
-- долгую работу запускайте через task.spawn внутри обработчика.

local ErrorReporter = require(script.Parent.ErrorReporter)

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
}

type Slot<T...> = {
	handler: (T...) -> (),
	connection: Connection,
}

local Signal = {}

function Signal.new<T...>(name: string): Signal<T...>
	local slots: { Slot<T...> } = {}
	local context = "Signal." .. name

	local function disconnect(connection: Connection)
		if not connection.Connected then
			return
		end
		connection.Connected = false
		for index, slot in slots do
			if slot.connection == connection then
				table.remove(slots, index)
				return
			end
		end
	end

	local signal = {} :: Signal<T...>

	function signal.Connect(_self: Signal<T...>, handler: (T...) -> ()): Connection
		local connection: Connection = {
			Connected = true,
			Disconnect = disconnect,
		}
		table.insert(slots, { handler = handler, connection = connection })
		return connection
	end

	function signal.Fire(_self: Signal<T...>, ...: T...)
		-- Копия списка: обработчик может отключаться или подключать новые во время рассылки.
		for _, slot in table.clone(slots) do
			if slot.connection.Connected then
				ErrorReporter.try(context, slot.handler, ...)
			end
		end
	end

	function signal.DisconnectAll(_self: Signal<T...>)
		for _, slot in slots do
			slot.connection.Connected = false
		end
		table.clear(slots)
	end

	return signal
end

return table.freeze(Signal)
