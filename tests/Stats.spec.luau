local Test = require("./lib/Test")
local Stats = require("../src/shared/Logic/Stats")
local Config = require("../src/shared/Config")

local expect = Test.expect

local BASE = { AttackPower = 10, CritChance = 0.05, MaxHealth = 100 }
local CAPS = {
	AttackPower = { Min = 1, Max = 5000 },
	CritChance = { Min = 0, Max = 0.75 },
	MaxHealth = { Min = 1, Max = 2000 },
}

local function add(stat: string, value: number): any
	return { stat = stat, op = "add", value = value }
end

local function mul(stat: string, value: number): any
	return { stat = stat, op = "mul", value = value }
end

Test.describe("Stats.compute", function(it)
	it("без модификаторов возвращает базовые значения", function()
		expect(Stats.compute(BASE, {}, CAPS)).toEqual(BASE)
	end)

	it("прибавки складываются, множители перемножаются", function()
		local result = Stats.compute(BASE, { add("AttackPower", 5), add("AttackPower", 5) }, CAPS)
		expect(result.AttackPower).toBe(20)

		result = Stats.compute(BASE, { mul("AttackPower", 2), mul("AttackPower", 1.5) }, CAPS)
		expect(result.AttackPower).toBe(30)
	end)

	it("прибавки применяются до множителей", function()
		-- (10 + 10) × 2 = 40, а не 10 × 2 + 10 = 30.
		expect(Stats.compute(BASE, { add("AttackPower", 10), mul("AttackPower", 2) }, CAPS).AttackPower).toBe(40)
	end)

	it("порядок перков не влияет на результат", function()
		local a = { add("AttackPower", 7), mul("AttackPower", 1.3), add("AttackPower", 3), mul("AttackPower", 0.8) }
		local b = { mul("AttackPower", 0.8), add("AttackPower", 3), mul("AttackPower", 1.3), add("AttackPower", 7) }
		expect(Stats.compute(BASE, a, CAPS).AttackPower).toBeCloseTo(Stats.compute(BASE, b, CAPS).AttackPower, 1e-9)
	end)

	it("пределы не дают характеристике уйти за границы", function()
		expect(Stats.compute(BASE, { add("CritChance", 10) }, CAPS).CritChance).toBe(0.75)
		expect(Stats.compute(BASE, { mul("AttackPower", 0) }, CAPS).AttackPower).toBe(1)
		expect(Stats.compute(BASE, { mul("MaxHealth", 1000) }, CAPS).MaxHealth).toBe(2000)
	end)

	it("характеристика без предела не зажимается", function()
		expect(Stats.compute({ Luck = 1 }, { add("Luck", 999) }, {}).Luck).toBe(1000)
	end)

	it(
		"модификатор на неизвестную характеристику игнорируется",
		function()
			local result = Stats.compute(BASE, { add("Nonexistent", 100), add("AttackPower", 1) }, CAPS)
			expect(result.Nonexistent).toBeNil()
			expect(result.AttackPower).toBe(11)
		end
	)

	it("неизвестная операция игнорируется", function()
		expect(Stats.compute(BASE, { { stat = "AttackPower", op = "divide", value = 2 } }, CAPS).AttackPower).toBe(10)
	end)

	it("NaN и бесконечность в модификаторе отбрасываются", function()
		expect(Stats.compute(BASE, { add("AttackPower", 0 / 0) }, CAPS).AttackPower).toBe(10)
		expect(Stats.compute(BASE, { mul("AttackPower", math.huge) }, CAPS).AttackPower).toBe(10)
	end)

	it("исходные таблицы не изменяются", function()
		local base = { AttackPower = 10 }
		local modifiers = { add("AttackPower", 5) }
		Stats.compute(base, modifiers, CAPS)
		expect(base.AttackPower).toBe(10)
		expect(#modifiers).toBe(1)
	end)

	it(
		"базовые характеристики игры проходят через свои пределы без изменений",
		function()
			local result = Stats.compute(Config.Hero.BaseStats, {}, Config.Hero.StatCaps)
			for stat, value in Config.Hero.BaseStats do
				expect(result[stat]).toBe(value)
			end
		end
	)
end)

Test.describe("Stats.attackInterval", function(it)
	it("скорость атаки сокращает паузу между ударами", function()
		expect(Stats.attackInterval(0.42, 1)).toBeCloseTo(0.42)
		expect(Stats.attackInterval(0.42, 2)).toBeCloseTo(0.21)
		expect(Stats.attackInterval(0.42, 0.5)).toBeCloseTo(0.84)
	end)

	it(
		"нулевая или отрицательная скорость — ошибка, а не деление на ноль",
		function()
			expect(function()
				Stats.attackInterval(0.42, 0)
			end).toThrow("attackSpeed")
		end
	)

	it(
		"предел скорости атаки не даёт паузе стать слишком короткой",
		function()
			local maxSpeed = Config.Hero.StatCaps.AttackSpeed.Max
			expect(Stats.attackInterval(Config.Weapon.AttackInterval, maxSpeed)).toBeGreaterThanOrEqual(0.1)
		end
	)
end)

return nil
