--!strict
-- Серверная сторона сетевого слоя (ТЗ 23.3, 25).
-- Создаёт события по реестру Remotes, ограничивает частоту запросов каждого игрока
-- (token bucket), изолирует ошибки обработчиков и ведёт учёт отклонённых запросов.
-- Наказаний автоматически не выдаёт: подозрительные запросы отклоняются и пишутся в лог.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local ErrorReporter = require(ReplicatedStorage.Shared.Util.ErrorReporter)

type RemoteDef = Remotes.RemoteDef

type Bucket = {
	tokens: number,
	updatedAt: number,
}

type ViolationEntry = {
	count: number,
	lastLoggedAt: number,
}

local VIOLATION_LOG_INTERVAL = 30

local NetServer = {}

local reliable: { [string]: RemoteEvent } = {}
local unreliable: { [string]: UnreliableRemoteEvent } = {}
local buckets: { [Player]: { [string]: Bucket } } = {}
local violations: { [Player]: ViolationEntry } = {}
local initialized = false

local function consumeToken(player: Player, def: RemoteDef): boolean
	local limit = def.rateLimit
	if not limit then
		return true
	end

	local perPlayer = buckets[player]
	if not perPlayer then
		perPlayer = {}
		buckets[player] = perPlayer
	end

	local now = os.clock()
	local bucket = perPlayer[def.name]
	if not bucket then
		bucket = { tokens = limit.burst, updatedAt = now }
		perPlayer[def.name] = bucket
	end

	bucket.tokens = math.min(limit.burst, bucket.tokens + (now - bucket.updatedAt) * limit.perSecond)
	bucket.updatedAt = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

function NetServer.init()
	assert(not initialized, "NetServer.init вызван повторно")

	local folder = Instance.new("Folder")
	folder.Name = Constants.Folders.Net
	for _, def in Remotes.All do
		if def.unreliable then
			local remote = Instance.new("UnreliableRemoteEvent")
			remote.Name = def.name
			remote.Parent = folder
			unreliable[def.name] = remote
		else
			local remote = Instance.new("RemoteEvent")
			remote.Name = def.name
			remote.Parent = folder
			reliable[def.name] = remote
		end
	end
	folder.Parent = ReplicatedStorage

	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
		violations[player] = nil
	end)

	initialized = true
end

-- Учитывает отклонённый запрос. Лог пишется не чаще раза в VIOLATION_LOG_INTERVAL секунд
-- на игрока, чтобы задержки сети и случайные двойные нажатия не засоряли его.
function NetServer.reject(player: Player, remoteName: string, reason: string)
	local now = os.clock()
	local entry = violations[player]
	if not entry then
		entry = { count = 0, lastLoggedAt = -math.huge }
		violations[player] = entry
	end
	entry.count += 1
	if now - entry.lastLoggedAt >= VIOLATION_LOG_INTERVAL then
		entry.lastLoggedAt = now
		warn(
			`[GOBLIT][Net] отклонён {remoteName} от UserId {player.UserId}: {reason} (всего за сессию: {entry.count})`
		)
	end
end

-- Подключает обработчик запроса клиента. Аргументы приходят как unknown:
-- обработчик обязан проверить каждый из них сам (см. Guard).
function NetServer.onServerEvent(def: RemoteDef, handler: (Player, ...unknown) -> ())
	assert(initialized, "NetServer не инициализирован")
	assert(def.direction == "ToServer", `{def.name} не является запросом клиента`)
	local remote = reliable[def.name]
	assert(remote, `событие {def.name} не создано`)

	local context = "Net." .. def.name
	remote.OnServerEvent:Connect(function(player: Player, ...: unknown)
		if not consumeToken(player, def) then
			NetServer.reject(player, def.name, "превышена частота запросов")
			return
		end
		ErrorReporter.try(context, handler, player, ...)
	end)
end

function NetServer.fireClient(def: RemoteDef, player: Player, payload: unknown)
	assert(def.direction == "ToClient", `{def.name} нельзя отправить клиенту`)
	if def.unreliable then
		unreliable[def.name]:FireClient(player, payload)
	else
		reliable[def.name]:FireClient(player, payload)
	end
end

function NetServer.fireClients(def: RemoteDef, players: { Player }, payload: unknown)
	for _, player in players do
		NetServer.fireClient(def, player, payload)
	end
end

function NetServer.fireAllClients(def: RemoteDef, payload: unknown)
	assert(def.direction == "ToClient", `{def.name} нельзя отправить клиенту`)
	if def.unreliable then
		unreliable[def.name]:FireAllClients(payload)
	else
		reliable[def.name]:FireAllClients(payload)
	end
end

function NetServer.notify(player: Player, text: string, kind: Remotes.NotifyKind)
	local payload: Remotes.NotifyPayload = { text = text, kind = kind }
	NetServer.fireClient(Remotes.Notify, player, payload)
end

return table.freeze(NetServer)
