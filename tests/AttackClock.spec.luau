local Test = require("./lib/Test")
local AttackClock = require("../src/shared/Logic/AttackClock")
local Config = require("../src/shared/Config")

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

return nil
