--!strict
-- Перезарядка удара: сервер решает, можно ли принять удар именно сейчас
-- (CLAUDE.md: «клиент просит — сервер решает»).
-- Чистый модуль без Roblox API: время приходит параметром, тесты — tests/AttackClock.spec.luau.
--
-- Зачем нужен запас на задержку (tolerance). Клиент отправляет удар, когда перезарядка
-- прошла у него, но пакет ещё идёт по сети, и на сервер он приходит позже срока. Без запаса
-- игрок с плохой связью бил бы реже остальных, поэтому удар, пришедший немного РАНЬШЕ срока,
-- сервер принимает.
--
-- В чём была ошибка. Раньше проверка выглядела как «с прошлого удара прошло не меньше
-- interval − tolerance», а срок следующего удара отсчитывался от момента удара. Запас при этом
-- доставался каждому удару, а не разовому опозданию: клиент, который шлёт запросы без остановки,
-- получал темп 1/(interval − tolerance) вместо 1/interval. При 0,42 с и запасе 0,2 с это
-- 3,6 удара в секунду против честных 2,38 — примерно в 1,5 раза больше урона в секунду
-- (измерено в Studio, проверка C3/C11 от 21.10.2026).
--
-- Как считается теперь. Хранится не «когда был прошлый удар», а абсолютный срок следующего
-- (readyAt), и новый срок отсчитывается ОТ СРОКА, а не от момента удара:
--
--     принять, если now + tolerance >= readyAt
--     readyAt := max(now, readyAt) + interval
--
-- Опережение тогда не копится: удар, принятый на tolerance раньше срока, сдвигает расписание
-- ровно на interval от прежнего срока, поэтому средний темп при любом спаме остаётся 1/interval.
-- Выигрыш спама — один удар в самом начале серии, и только на величину запаса.
--
-- max(now, readyAt) нужен для обратного случая: простой не запасается впрок. Иначе игрок,
-- который минуту не бил, получил бы право на серию мгновенных ударов.

local AttackClock = {}

export type Decision = {
	accepted: boolean,
	-- Срок следующего удара. Его нужно сохранить и передать в следующий вызов —
	-- в том числе при отказе (тогда он не меняется).
	readyAt: number,
}

local function isFinite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

-- readyAt — срок из прошлого решения (для первого удара подойдёт любое прошедшее время, 0).
-- now — текущее время сервера (os.clock()).
-- interval — полная перезарядка в секундах, строго больше нуля.
-- tolerance — запас на сетевую задержку. Отрицательный, NaN и бесконечность считаются нулём,
-- запас больше интервала обрезается до интервала: иначе один спам-залп давал бы сразу
-- несколько ударов.
function AttackClock.decide(readyAt: number, now: number, interval: number, tolerance: number): Decision
	if not isFinite(now) then
		error("AttackClock.decide: now должно быть конечным числом")
	end
	if not isFinite(interval) or interval <= 0 then
		error(
			"AttackClock.decide: interval должен быть конечным положительным числом"
		)
	end

	-- Испорченный срок (NaN или бесконечность) не должен навсегда лишить игрока удара:
	-- считаем, что расписания ещё нет и бить можно сразу.
	local schedule = if isFinite(readyAt) then readyAt else now
	local slack = if isFinite(tolerance) and tolerance > 0 then math.min(tolerance, interval) else 0

	if now + slack < schedule then
		return { accepted = false, readyAt = schedule }
	end
	return { accepted = true, readyAt = math.max(now, schedule) + interval }
end

-- Расписание на стороне клиента: когда отправить следующий запрос на удар.
--
-- Клиент не ждёт подтверждения сервера, а держит ровный шаг interval сам. Раньше срок
-- следующего удара ставился по приходу ответа сервера, и к каждому удару добавлялось время
-- пути пакета туда и обратно: в Studio 50 мс, на живом сервере 100–250 мс. Честный игрок,
-- держащий кнопку, бил на 10–35 % реже, чем тот, кто шлёт запросы без остановки (проверка
-- C3/C14 от 24.10.2026). Серверу ровный шаг клиента подходит: опоздания пакетов покрывает
-- запас TimingTolerance в decide.
--
-- Шаг отсчитывается от прошлого срока, если запрос ушёл позже него не больше чем на catchUp
-- (ожидание кадра: task.wait просыпается на ближайшем кадре, и иначе опоздания копились бы).
-- Если позже — игрок отпускал кнопку, и простой не запасается впрок: отсчёт от now.
-- catchUp должен быть меньше запаса сервера, иначе догоняющий запрос сервер отбросит.
--
-- readyAt — срок из прошлого вызова (для первого удара — 0), now — время отправки запроса.
-- Вызывается только когда запрос действительно уходит (now >= readyAt).
function AttackClock.nextRequest(readyAt: number, now: number, interval: number, catchUp: number): number
	if not isFinite(now) then
		error("AttackClock.nextRequest: now должно быть конечным числом")
	end
	if not isFinite(interval) or interval <= 0 then
		error(
			"AttackClock.nextRequest: interval должен быть конечным положительным числом"
		)
	end
	local slack = if isFinite(catchUp) and catchUp > 0 then catchUp else 0
	local onSchedule = isFinite(readyAt) and now >= readyAt and now - readyAt <= slack
	return (if onSchedule then readyAt else now) + interval
end

return table.freeze(AttackClock)
