--!strict
-- Постоянный профиль игрока в DataStore (ТЗ 24).
--
-- Надёжность:
--   • только UpdateAsync, с блокировкой сессии (Logic/SessionLock): профиль одновременно
--     изменяет одна сессия одного сервера, и записывать может только она;
--   • если блокировку держит другой живой сервер, ждём; устаревшую (LockTtlSeconds) забираем
--     сразу, свежую — только через ForceLockAfterSeconds, когда чужая финальная запись
--     гарантированно закончилась; каждый такой захват пишется в лог;
--   • сессия, потерявшая блокировку, прекращает сохранять этот профиль;
--   • повторные попытки с паузами, автосохранение, сохранение при выходе и в BindToClose;
--   • записи одного профиля не перекрываются (флаг saving);
--   • всё прочитанное и записанное проходит через ProfileSchema (миграция и проверка типов);
--   • данные от более новой версии игры только читаются, но не перезаписываются.
--
-- Если DataStore недоступен (например, в Studio без доступа к API), игрок получает
-- профиль по умолчанию, сохранение для него отключается и он видит предупреждение.
--
-- В Studio используется отдельное хранилище (имя + Config.Data.StudioStoreSuffix): с доступом
-- к API Studio работает с теми же хранилищами, что и живая игра, а тесты не должны трогать
-- настоящие профили и отбирать их у живых серверов.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)
local ProfileSchema = require(ReplicatedStorage.Shared.Logic.ProfileSchema)
local DataStoreErrors = require(ReplicatedStorage.Shared.Logic.DataStoreErrors)
local SessionLock = require(ReplicatedStorage.Shared.Logic.SessionLock)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local ErrorReporter = require(ReplicatedStorage.Shared.Util.ErrorReporter)
local NetServer = require(script.Parent.Parent.Net.NetServer)

type Profile = ProfileSchema.Profile

type Session = {
	id: string,
	player: Player,
	profile: Profile,
	canSave: boolean,
	saving: boolean,
	released: boolean,
}

type StoredRecord = {
	Data: unknown,
	Lock: SessionLock.Lock?,
}

type LoadResult = {
	profile: Profile,
	canSave: boolean,
	problem: string?,
}

local BIND_TO_CLOSE_BUDGET = 25
local Attr = Constants.PlayerAttr

local PlayerDataService = {}

-- (player, profile) — профиль загружен (или выдан профиль по умолчанию без сохранения).
PlayerDataService.ProfileLoaded = Signal.new("ProfileLoaded") :: Signal.Signal<Player, Profile>
-- (player, profile) — профиль изменён через update().
PlayerDataService.ProfileChanged = Signal.new("ProfileChanged") :: Signal.Signal<Player, Profile>

local store: DataStore? = nil
local sessions: { [Player]: Session } = {}
local releaseHooks: { (Player, Profile) -> () } = {}
-- UserId, чья финальная запись ещё идёт: при быстром перезаходе на тот же сервер
-- новая загрузка ждёт её, иначе прочитала бы профиль без последних изменений.
local releasingUserIds: { [number]: boolean } = {}
local loadingPlayers: { [Player]: boolean } = {}
local inFlight = 0

local function profileKey(userId: number): string
	return "profile_" .. tostring(userId)
end

-- В Studio JobId пустой; отдельное имя не даёт пустой строке совпасть с чем-то случайным.
local function currentJobId(): string
	return if game.JobId == "" then "studio" else game.JobId
end

local function readRecord(old: unknown): StoredRecord
	if type(old) ~= "table" then
		return { Data = nil, Lock = nil }
	end
	local raw = old :: { [string]: any }
	return { Data = raw.Data, Lock = SessionLock.parse(raw.Lock) }
end

local function newLock(sessionId: string): SessionLock.Lock
	return { JobId = currentJobId(), Session = sessionId, Time = os.time() }
end

local function disableStore(reason: string)
	if store then
		store = nil
		ErrorReporter.report("PlayerData", `DataStore отключён до перезапуска сервера: {reason}`)
	end
end

local function replicate(session: Session)
	local player = session.player
	local profile = session.profile
	player:SetAttribute(Attr.Gold, profile.Gold)
	player:SetAttribute(Attr.RelicShards, profile.RelicShards)
	player:SetAttribute(Attr.Knowledge, profile.Knowledge)
	player:SetAttribute(Attr.SaveDisabled, not session.canSave)
	player:SetAttribute(Attr.DataReady, true)
end

local function loadProfile(player: Player, sessionId: string): LoadResult
	local key = profileKey(player.UserId)
	local myJobId = currentJobId()
	local startedAt = os.clock()
	local errors = 0

	while true do
		local activeStore = store
		if not activeStore then
			break
		end

		local waited = os.clock() - startedAt
		local decision: SessionLock.AcquireDecision = "wait"
		local lockAge: number? = nil
		local newerVersion = false
		local loaded: Profile? = nil

		local ok, err = pcall(function()
			activeStore:UpdateAsync(key, function(old: unknown)
				local record = readRecord(old)
				local lock = record.Lock
				decision = SessionLock.decideAcquire(
					lock,
					myJobId,
					os.time(),
					waited,
					Config.Data.LockTtlSeconds,
					Config.Data.ForceLockAfterSeconds
				)
				if decision == "wait" then
					loaded = nil
					return nil
				end
				lockAge = if lock then os.time() - lock.Time else nil
				local profile, info = ProfileSchema.migrate(record.Data, os.time())
				loaded = profile
				newerVersion = info.newerVersion
				if newerVersion then
					return nil -- не перезаписываем данные новой версии
				end
				return { Data = profile, Lock = newLock(sessionId) }
			end)
		end)

		if ok and loaded then
			if decision == "stale" or decision == "force" then
				ErrorReporter.report(
					"PlayerData.lock",
					`UserId {player.UserId}: забрана {if decision == "stale" then "устаревшая" else "чужая свежая"} блокировка (возраст {lockAge} с, ожидание {math.floor(waited)} с)`
				)
			end
			if newerVersion then
				return {
					profile = loaded,
					canSave = false,
					problem = "профиль сохранён более новой версией игры",
				}
			end
			return { profile = loaded, canSave = true, problem = nil }
		end

		if not ok then
			errors += 1
			local message = tostring(err)
			ErrorReporter.report("PlayerData.load", `UserId {player.UserId}, ошибка {errors}: {message}`)
			if DataStoreErrors.isPermanent(message) then
				disableStore(message)
				break
			end
			if errors >= Config.Data.LoadAttempts then
				break
			end
		end

		if player.Parent == nil then
			break
		end
		task.wait(Config.Data.RetryDelaySeconds)
	end

	local problem = if store == nil then "хранилище данных недоступно" else "не удалось загрузить профиль"
	return { profile = ProfileSchema.default(os.time()), canSave = false, problem = problem }
end

-- Записывает профиль. release = true снимает блокировку сессии.
local function writeProfile(session: Session, release: boolean): boolean
	while session.saving do
		task.wait()
	end
	if not session.canSave then
		return false
	end

	session.saving = true
	local snapshot = ProfileSchema.clone(session.profile)
	local key = profileKey(session.player.UserId)
	local saved = false

	for attempt = 1, Config.Data.SaveAttempts do
		local activeStore = store
		if not activeStore then
			break
		end

		local lockLost = false
		local ok, err = pcall(function()
			activeStore:UpdateAsync(key, function(old: unknown)
				local record = readRecord(old)
				-- Писать может только сессия, чья блокировка в записи. Пустая блокировка — тоже
				-- потеря: профиль уже отпустили или забрали, старая запись затёрла бы новые данные.
				lockLost = not SessionLock.owns(record.Lock, session.id)
				if lockLost then
					return nil
				end
				local lock: SessionLock.Lock? = if release then nil else newLock(session.id)
				return { Data = snapshot, Lock = lock }
			end)
		end)

		if ok then
			if lockLost then
				session.canSave = false
				session.player:SetAttribute(Attr.SaveDisabled, true)
				ErrorReporter.report(
					"PlayerData.save",
					`профиль UserId {session.player.UserId} забран другой сессией; здесь сохранение прекращено`
				)
			else
				saved = true
			end
			break
		end

		local message = tostring(err)
		ErrorReporter.report("PlayerData.save", `UserId {session.player.UserId}, попытка {attempt}: {message}`)
		if DataStoreErrors.isPermanent(message) then
			disableStore(message)
			break
		end
		if attempt < Config.Data.SaveAttempts then
			task.wait(2 ^ attempt)
		end
	end

	session.saving = false
	return saved
end

local function release(player: Player)
	local session = sessions[player]
	if not session or session.released then
		return
	end
	session.released = true
	inFlight += 1
	releasingUserIds[player.UserId] = true

	-- Хуки (например, начисление итогов прерванной экспедиции) видят профиль последними.
	for _, hook in releaseHooks do
		ErrorReporter.try("PlayerData.releaseHook", hook, player, session.profile)
	end
	session.profile = ProfileSchema.migrate(session.profile, os.time())

	writeProfile(session, true)
	sessions[player] = nil
	releasingUserIds[player.UserId] = nil
	inFlight -= 1
end

local function onPlayerAdded(player: Player)
	if sessions[player] or loadingPlayers[player] then
		return
	end
	loadingPlayers[player] = true
	inFlight += 1
	while releasingUserIds[player.UserId] do
		task.wait(0.1)
	end
	local sessionId = HttpService:GenerateGUID(false)
	local result = loadProfile(player, sessionId)

	local session: Session = {
		id = sessionId,
		player = player,
		profile = result.profile,
		canSave = result.canSave,
		saving = false,
		released = false,
	}
	sessions[player] = session
	loadingPlayers[player] = nil

	if player.Parent == nil then
		-- Игрок вышел, пока профиль загружался: сразу снимаем блокировку.
		inFlight -= 1
		release(player)
		return
	end

	replicate(session)
	inFlight -= 1

	if result.problem then
		NetServer.notify(
			player,
			`Сохранение отключено: {result.problem}. Прогресс этой сессии не сохранится.`,
			"warning"
		)
	end
	PlayerDataService.ProfileLoaded:Fire(player, session.profile)
end

-- Профиль для чтения. Не изменяйте возвращённую таблицу напрямую — используйте update().
function PlayerDataService.getProfile(player: Player): Profile?
	local session = sessions[player]
	return if session and not session.released then session.profile else nil
end

function PlayerDataService.isReady(player: Player): boolean
	local session = sessions[player]
	return session ~= nil and not session.released
end

-- Атомарно изменяет профиль: mutator получает черновик; при ошибке изменения отбрасываются.
-- После изменения профиль снова проверяется схемой (например, валюта не уйдёт в минус).
function PlayerDataService.update(player: Player, mutator: (Profile) -> ()): boolean
	local session = sessions[player]
	if not session or session.released then
		return false
	end

	local draft = ProfileSchema.clone(session.profile)
	if not ErrorReporter.try("PlayerData.update", mutator, draft) then
		return false
	end
	session.profile = ProfileSchema.migrate(draft, os.time())
	replicate(session)
	PlayerDataService.ProfileChanged:Fire(player, session.profile)
	return true
end

-- Внеочередное сохранение после важного события (например, итогов экспедиции).
function PlayerDataService.saveSoon(player: Player)
	local session = sessions[player]
	if session and not session.released and session.canSave then
		task.spawn(writeProfile, session, false)
	end
end

-- Хук вызывается при выходе игрока до финальной записи профиля.
function PlayerDataService.registerReleaseHook(hook: (Player, Profile) -> ())
	table.insert(releaseHooks, hook)
end

function PlayerDataService.init()
	local storeName = if RunService:IsStudio()
		then Config.Data.StoreName .. Config.Data.StudioStoreSuffix
		else Config.Data.StoreName
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(storeName)
	end)
	if ok then
		store = result
		print(`[GOBLIT] хранилище профилей: {storeName}`)
	else
		ErrorReporter.report("PlayerData", `DataStore недоступен: {result}`)
	end
end

function PlayerDataService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(release)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	game:BindToClose(function()
		for player in table.clone(sessions) do
			task.spawn(release, player)
		end
		local deadline = os.clock() + BIND_TO_CLOSE_BUDGET
		while inFlight > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)

	-- Автосохранение также продлевает блокировку сессии (LockTtlSeconds > AutosaveSeconds).
	task.spawn(function()
		while true do
			task.wait(Config.Data.AutosaveSeconds)
			for _, session in table.clone(sessions) do
				if not session.released and session.canSave and not session.saving then
					task.spawn(writeProfile, session, false)
				end
			end
		end
	end)
end

return PlayerDataService
