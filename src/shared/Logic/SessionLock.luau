--!strict
-- Решения о блокировке сессии профиля. Чистый модуль без Roblox API (тестируется в Lune).
--
-- Блокировка хранится в записи DataStore рядом с профилем: { JobId, Session, Time }.
--   JobId   — сервер, который держит профиль;
--   Session — уникальный идентификатор сессии игрока на этом сервере. По нему запись
--             отличает «свою» блокировку от блокировки новой сессии того же игрока;
--   Time    — когда блокировку последний раз продлевали (os.time()).
--
-- Писать профиль может только сессия, чья блокировка лежит в записи. Отсутствие блокировки —
-- тоже потеря: значит, профиль уже отпустили или забрали, и старая запись затёрла бы новые данные.

export type Lock = {
	JobId: string,
	Session: string,
	Time: number,
}

-- acquire — блокировки нет или она осталась от этого же сервера;
-- stale   — блокировка устарела (сервер-владелец, видимо, упал);
-- force   — ждали достаточно долго, забираем свежую чужую блокировку;
-- wait    — блокировку держит другой живой сервер, нужно подождать.
export type AcquireDecision = "acquire" | "stale" | "force" | "wait"

local SessionLock = {}

-- Разбирает поле Lock из записи. Некорректное значение считается отсутствием блокировки.
-- Записи старого формата без Session получают пустой идентификатор: своими они не считаются.
function SessionLock.parse(raw: unknown): Lock?
	if type(raw) ~= "table" then
		return nil
	end
	local fields = raw :: { [string]: any }
	if type(fields.JobId) ~= "string" or type(fields.Time) ~= "number" or fields.Time ~= fields.Time then
		return nil
	end
	return {
		JobId = fields.JobId,
		Session = if type(fields.Session) == "string" then fields.Session else "",
		Time = fields.Time,
	}
end

-- Может ли загрузка профиля забрать блокировку.
-- Блокировка этого же сервера — остаток прошлой сессии: живая сессия того же игрока на этом
-- сервере невозможна (новая загрузка ждёт, пока прошлая выгрузка закончится).
function SessionLock.decideAcquire(
	lock: Lock?,
	myJobId: string,
	now: number,
	waitedSeconds: number,
	ttlSeconds: number,
	forceAfterSeconds: number
): AcquireDecision
	if lock == nil or lock.JobId == myJobId then
		return "acquire"
	end
	if now - lock.Time >= ttlSeconds then
		return "stale"
	end
	if waitedSeconds >= forceAfterSeconds then
		return "force"
	end
	return "wait"
end

-- Принадлежит ли блокировка этой сессии (можно ли ей записывать профиль).
function SessionLock.owns(lock: Lock?, sessionId: string): boolean
	return lock ~= nil and sessionId ~= "" and lock.Session == sessionId
end

return table.freeze(SessionLock)
