local Test = require("./lib/Test")
local AttackClock = require("../src/shared/Logic/AttackClock")
local Config = require("../src/shared/Config")
local Remotes = require("../src/shared/Net/Remotes")

local expect = Test.expect

local INTERVAL = 0.42
local TOLERANCE = 0.2

-- Сколько ударов примет сервер, если клиент шлёт запросы каждые `step` секунд
-- в течение `duration`. Возвращает число принятых ударов и минимальный промежуток между ними.
local function simulate(duration: number, step: number, interval: number, tolerance: number): (number, number)
	local readyAt = 0
	local accepted = 0
	local lastAccepted: number? = nil
	local minGap = math.huge
	local now = 0
	while now <= duration + 1e-9 do
		local decision = AttackClock.decide(readyAt, now, interval, tolerance)
		readyAt = decision.readyAt
		if decision.accepted then
			accepted += 1
			if lastAccepted then
				minGap = math.min(minGap, now - lastAccepted)
			end
			lastAccepted = now
		end
		now += step
	end
	return accepted, minGap
end

Test.describe("AttackClock.decide", function(it)
	it("первый удар принимается сразу", function()
		local decision = AttackClock.decide(0, 100, INTERVAL, TOLERANCE)
		expect(decision.accepted).toBeTruthy()
		expect(decision.readyAt).toBeCloseTo(100.42)
	end)

	it("сразу после удара удар не принимается", function()
		local first = AttackClock.decide(0, 100, INTERVAL, TOLERANCE)
		local second = AttackClock.decide(first.readyAt, 100, INTERVAL, TOLERANCE)
		expect(second.accepted).toBeFalsy()
		-- При отказе расписание не сдвигается: иначе отказы продлевали бы перезарядку.
		expect(second.readyAt).toBe(first.readyAt)
	end)

	it(
		"удар, пришедший в пределах запаса раньше срока, принимается",
		function()
			-- Срок 100,42; запас 0,2 — значит с 100,22 удар уже принимается.
			expect(AttackClock.decide(100.42, 100.23, INTERVAL, TOLERANCE).accepted).toBeTruthy()
			expect(AttackClock.decide(100.42, 100.21, INTERVAL, TOLERANCE).accepted).toBeFalsy()
		end
	)

	it("запас не сдвигает расписание: опережение не копится", function()
		-- Удар принят на 0,2 с раньше срока 100,42, но следующий срок считается от 100,42.
		local decision = AttackClock.decide(100.42, 100.22, INTERVAL, TOLERANCE)
		expect(decision.accepted).toBeTruthy()
		expect(decision.readyAt).toBeCloseTo(100.84)
	end)

	it("непрерывный спам не даёт темпа выше перезарядки", function()
		-- Это и есть находка C3/C11: раньше тут выходило 1/(0,42 − 0,2) = 4,5 удара/с.
		local accepted = simulate(60, 0.05, INTERVAL, TOLERANCE)
		local honest = 60 / INTERVAL
		-- Допуск в несколько ударов — на разовый выигрыш в начале серии и шаг опроса.
		-- Прежнее поведение давало здесь 60 / 0,22 ≈ 272 удара, так что запас ничего не скрывает.
		expect(accepted).toBeLessThanOrEqual(math.ceil(honest) + 3)
		expect(accepted).toBeGreaterThanOrEqual(math.floor(honest))
	end)

	it(
		"минимальный промежуток между принятыми ударами не меньше перезарядки минус запас",
		function()
			local _, minGap = simulate(10, 0.05, INTERVAL, TOLERANCE)
			expect(minGap).toBeGreaterThanOrEqual(INTERVAL - TOLERANCE - 1e-9)
		end
	)

	it(
		"честный клиент с ритмом перезарядки не теряет ни одного удара",
		function()
			local accepted = simulate(10, INTERVAL, INTERVAL, TOLERANCE)
			expect(accepted).toBe(math.floor(10 / INTERVAL) + 1)
		end
	)

	it("опоздание не превращается в долг", function()
		-- Пакет пришёл на 0,3 с позже срока: следующий срок считается от «сейчас»,
		-- иначе игрок с плохой связью отрабатывал бы опоздание ускоренными ударами.
		local decision = AttackClock.decide(100.42, 100.72, INTERVAL, TOLERANCE)
		expect(decision.accepted).toBeTruthy()
		expect(decision.readyAt).toBeCloseTo(101.14)
	end)

	it("простой не запасается впрок", function()
		-- Игрок не бил 60 с: это даёт один удар, а не серию.
		local first = AttackClock.decide(100.42, 160, INTERVAL, TOLERANCE)
		expect(first.accepted).toBeTruthy()
		expect(first.readyAt).toBeCloseTo(160.42)
		expect(AttackClock.decide(first.readyAt, 160, INTERVAL, TOLERANCE).accepted).toBeFalsy()
	end)

	it("без запаса удар принимается точно по сроку", function()
		expect(AttackClock.decide(100.42, 100.41, INTERVAL, 0).accepted).toBeFalsy()
		expect(AttackClock.decide(100.42, 100.42, INTERVAL, 0).accepted).toBeTruthy()
	end)

	it("неправильный запас считается нулевым", function()
		for _, bad in { -1, 0 / 0, math.huge, -math.huge } do
			expect(AttackClock.decide(100.42, 100.41, INTERVAL, bad).accepted).toBeFalsy()
		end
	end)

	it(
		"запас больше перезарядки обрезается и не ускоряет темп",
		function()
			local accepted = simulate(60, 0.05, INTERVAL, 10)
			expect(accepted).toBeLessThanOrEqual(math.ceil(60 / INTERVAL) + 3)
		end
	)

	it("испорченный срок не лишает игрока удара навсегда", function()
		for _, broken in { 0 / 0, math.huge } do
			local decision = AttackClock.decide(broken, 100, INTERVAL, TOLERANCE)
			expect(decision.accepted).toBeTruthy()
			expect(decision.readyAt).toBeCloseTo(100.42)
		end
		-- Минус бесконечность — это «ещё ни разу не бил», тоже удар сразу.
		expect(AttackClock.decide(-math.huge, 100, INTERVAL, TOLERANCE).readyAt).toBeCloseTo(100.42)
	end)

	it(
		"неправильные перезарядка и время — ошибка, а не молчаливый пропуск",
		function()
			expect(function()
				AttackClock.decide(0, 100, 0, TOLERANCE)
			end).toThrow("interval")
			expect(function()
				AttackClock.decide(0, 100, -1, TOLERANCE)
			end).toThrow("interval")
			expect(function()
				AttackClock.decide(0, 100, 0 / 0, TOLERANCE)
			end).toThrow("interval")
			expect(function()
				AttackClock.decide(0, 0 / 0, INTERVAL, TOLERANCE)
			end).toThrow("now")
		end
	)

	it("на числах игры запас остаётся меньше перезарядки", function()
		-- Иначе один спам-залп давал бы сразу несколько ударов.
		expect(Config.Weapon.TimingTolerance).toBeLessThan(Config.Weapon.AttackInterval)
		expect(Config.Weapon.TimingTolerance).toBeGreaterThanOrEqual(0)
	end)
end)

local CATCH_UP = 0.05

-- Детерминированный «шум»: ожидание кадра на клиенте (0–33 мс) и разброс задержки сети.
local function frameDelay(k: number): number
	return (k * 13 % 7) / 6 * 0.033
end
local function networkJitter(k: number): number
	return (k * 37 % 11) / 10 * 0.09
end

-- Честный клиент держит кнопку: шлёт запрос, как только наступил его срок (плюс ожидание
-- кадра). Пакет идёт до сервера latency + разброс, сервер решает по своему расписанию.
-- Возвращает число отправленных запросов, принятых сервером и время от первого до последнего.
local function holdButton(count: number, latency: number): (number, number, number)
	local clientReady = 0
	local serverReady = 0
	local sendAt = 0
	local firstSend = 0
	local accepted = 0
	for k = 1, count do
		if k == 1 then
			firstSend = sendAt
		end
		clientReady = AttackClock.nextRequest(clientReady, sendAt, INTERVAL, CATCH_UP)
		local arrival = sendAt + latency + networkJitter(k)
		local decision = AttackClock.decide(serverReady, arrival, INTERVAL, TOLERANCE)
		serverReady = decision.readyAt
		if decision.accepted then
			accepted += 1
		end
		if k < count then
			sendAt = clientReady + frameDelay(k)
		end
	end
	return count, accepted, sendAt - firstSend
end

Test.describe("AttackClock.nextRequest", function(it)
	it("первый удар: следующий запрос через перезарядку", function()
		expect(AttackClock.nextRequest(0, 100, INTERVAL, CATCH_UP)).toBeCloseTo(100.42)
	end)

	it(
		"ожидание кадра не копится: шаг считается от прошлого срока",
		function()
			-- Запрос ушёл на 30 мс позже срока — следующий срок всё равно через 0,42 от прошлого.
			expect(AttackClock.nextRequest(10, 10.03, INTERVAL, CATCH_UP)).toBeCloseTo(10.42)
		end
	)

	it("после паузы простой не запасается впрок", function()
		expect(AttackClock.nextRequest(10, 15, INTERVAL, CATCH_UP)).toBeCloseTo(15.42)
		-- Опоздание чуть больше catchUp — тоже отсчёт от момента отправки.
		expect(AttackClock.nextRequest(10, 10.06, INTERVAL, CATCH_UP)).toBeCloseTo(10.48)
	end)

	it(
		"удержание кнопки держит темп перезарядки, хотя каждый запрос ждёт кадр",
		function()
			local sent, _, span = holdButton(100, 0.05)
			-- 99 промежутков по 0,42 с; ожидание кадра добавляет не больше одного кадра на всю серию.
			expect(span / (sent - 1)).toBeCloseTo(INTERVAL, 0.001)
		end
	)

	it(
		"сервер принимает все запросы честного клиента при любой задержке сети",
		function()
			for _, latency in { 0.02, 0.1, 0.25, 0.5 } do
				local sent, accepted = holdButton(100, latency)
				expect(accepted).toBe(sent)
			end
		end
	)

	it("неправильный срок или запас не ускоряют удары", function()
		expect(AttackClock.nextRequest(0 / 0, 100, INTERVAL, CATCH_UP)).toBeCloseTo(100.42)
		expect(AttackClock.nextRequest(math.huge, 100, INTERVAL, CATCH_UP)).toBeCloseTo(100.42)
		-- Отрицательный запас считается нулём: опоздание на 10 мс уже отсчёт от момента отправки.
		expect(AttackClock.nextRequest(10, 10.01, INTERVAL, -1)).toBeCloseTo(10.43)
		-- Запрос раньше срока (так не должно быть) — отсчёт от момента отправки.
		expect(AttackClock.nextRequest(10, 9.9, INTERVAL, CATCH_UP)).toBeCloseTo(10.32)
	end)

	it("неправильные перезарядка и время — ошибка", function()
		expect(function()
			AttackClock.nextRequest(0, 100, 0, CATCH_UP)
		end).toThrow("interval")
		expect(function()
			AttackClock.nextRequest(0, 0 / 0, INTERVAL, CATCH_UP)
		end).toThrow("now")
	end)

	it("на числах игры клиентский запас меньше серверного", function()
		-- Иначе запрос, догоняющий расписание, приходил бы раньше, чем сервер готов принять.
		expect(Config.Weapon.ClientCatchUp).toBeGreaterThanOrEqual(0)
		expect(Config.Weapon.ClientCatchUp).toBeLessThan(Config.Weapon.TimingTolerance)
	end)
end)

Test.describe("лимит частоты Attack", function(it)
	it("не ниже предельной скорости атаки", function()
		-- Иначе честного игрока с максимальной скоростью атаки отсекал бы антиспам.
		local fastest = Config.Weapon.AttackInterval / Config.Hero.StatCaps.AttackSpeed.Max
		local limit = Remotes.Attack.rateLimit
		assert(limit, "у Attack должен быть лимит частоты")
		expect(limit.perSecond).toBeGreaterThan(1 / fastest)
	end)
end)

return nil
