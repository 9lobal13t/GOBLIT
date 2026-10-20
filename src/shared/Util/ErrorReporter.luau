--!strict
-- Централизованная обработка ошибок (ТЗ 23.4): единый формат, трассировка стека
-- и защита логов от спама одинаковыми сообщениями. Работает и на сервере, и на клиенте.
-- Персональные данные игроков в сообщения не пишутся — только UserId при необходимости.

local SUPPRESS_SECONDS = 10
local MAX_TRACKED_MESSAGES = 200

type Entry = { reportedAt: number, suppressed: number }

local recent: { [string]: Entry } = {}
local trackedCount = 0

local ErrorReporter = {}

function ErrorReporter.report(context: string, message: unknown, traceback: string?)
	local text = tostring(message)
	local key = context .. "\0" .. text
	local now = os.clock()
	local entry = recent[key]

	if entry and now - entry.reportedAt < SUPPRESS_SECONDS then
		entry.suppressed += 1
		return
	end

	local suffix = if entry and entry.suppressed > 0
		then ` (ещё {entry.suppressed} повторов скрыто)`
		else ""
	if not entry then
		trackedCount += 1
		if trackedCount > MAX_TRACKED_MESSAGES then
			table.clear(recent)
			trackedCount = 1
		end
	end
	recent[key] = { reportedAt = now, suppressed = 0 }

	local body = `[GOBLIT][{context}] {text}{suffix}`
	if traceback and traceback ~= "" then
		body ..= "\n" .. traceback
	end
	warn(body)
end

-- Вызывает fn в защищённом режиме. Возвращает true, если ошибок не было.
-- Ошибка не роняет вызывающий код, а попадает в лог с контекстом и стеком.
function ErrorReporter.try<A...>(context: string, fn: (A...) -> (), ...: A...): boolean
	local caughtProblem: unknown = nil
	local caughtTraceback = ""
	local ok = xpcall(fn, function(problem: unknown)
		caughtProblem = problem
		caughtTraceback = debug.traceback(nil, 2)
	end, ...)
	if not ok then
		ErrorReporter.report(context, caughtProblem, caughtTraceback)
	end
	return ok
end

return table.freeze(ErrorReporter)
