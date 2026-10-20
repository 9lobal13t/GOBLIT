local Test = require("./lib/Test")
local Damage = require("../src/shared/Logic/Damage")
local Config = require("../src/shared/Config")

local expect = Test.expect

local SETTINGS = { ArmorScale = 5, MaxDamage = 1000000 }

local function input(overrides: { [string]: number }): any
	local base = {
		attackPower = 10,
		abilityMultiplier = 1,
		critChance = 0,
		critDamage = 1.5,
		armor = 0,
		roll = 0.5,
	}
	for key, value in overrides do
		base[key] = value
	end
	return base
end

Test.describe("Damage.armorMultiplier", function(it)
	it("без брони урон не снижается", function()
		expect(Damage.armorMultiplier(0, 5)).toBe(1)
	end)

	it(
		"броня снижает урон по формуле 100 / (100 + броня × множитель)",
		function()
			expect(Damage.armorMultiplier(20, 5)).toBeCloseTo(0.5) -- 100 / 200
			expect(Damage.armorMultiplier(10, 5)).toBeCloseTo(100 / 150)
		end
	)

	it("снижение никогда не доходит до нуля", function()
		expect(Damage.armorMultiplier(Config.Hero.StatCaps.Armor.Max, 5)).toBeGreaterThan(0)
	end)

	it("отрицательная броня и мусор не усиливают урон", function()
		expect(Damage.armorMultiplier(-50, 5)).toBe(1)
		expect(Damage.armorMultiplier(0 / 0, 5)).toBe(1)
	end)
end)

Test.describe("Damage.compute", function(it)
	it("простой удар без крита и брони", function()
		local result = Damage.compute(input({}), SETTINGS)
		expect(result.amount).toBe(10)
		expect(result.crit).toBe(false)
	end)

	it("множитель приёма умножает урон", function()
		expect(Damage.compute(input({ abilityMultiplier = 1.6 }), SETTINGS).amount).toBe(16)
	end)

	it("бросок меньше шанса крита даёт крит", function()
		local result = Damage.compute(input({ critChance = 0.3, roll = 0.29, critDamage = 2 }), SETTINGS)
		expect(result.crit).toBe(true)
		expect(result.amount).toBe(20)
	end)

	it("бросок, равный шансу крита, критом не считается", function()
		expect(Damage.compute(input({ critChance = 0.3, roll = 0.3 }), SETTINGS).crit).toBe(false)
	end)

	it(
		"при нулевом шансе крита крита не бывает даже при нулевом броске",
		function()
			expect(Damage.compute(input({ critChance = 0, roll = 0 }), SETTINGS).crit).toBe(false)
		end
	)

	it("крит не может уменьшить урон", function()
		-- Испорченные данные: критический множитель меньше единицы.
		local result = Damage.compute(input({ critChance = 1, roll = 0, critDamage = 0.5 }), SETTINGS)
		expect(result.amount).toBe(10)
	end)

	it("броня уменьшает урон", function()
		expect(Damage.compute(input({ attackPower = 100, armor = 20 }), SETTINGS).amount).toBe(50)
	end)

	it("урон всегда целый и не меньше 1", function()
		local result = Damage.compute(input({ attackPower = 0.1 }), SETTINGS)
		expect(result.amount).toBe(1)
		expect(result.amount % 1).toBe(0)
		expect(Damage.compute(input({ attackPower = 1000, armor = 1000 }), SETTINGS).amount).toBeGreaterThanOrEqual(1)
	end)

	it("урон не превышает предел", function()
		expect(Damage.compute(input({ attackPower = 1e12 }), SETTINGS).amount).toBe(SETTINGS.MaxDamage)
	end)

	it("нулевая и отрицательная сила атаки не наносят урона", function()
		expect(Damage.compute(input({ attackPower = 0 }), SETTINGS).amount).toBe(0)
		expect(Damage.compute(input({ attackPower = -50 }), SETTINGS).amount).toBe(0)
		expect(Damage.compute(input({ abilityMultiplier = -1 }), SETTINGS).amount).toBe(0)
	end)

	it("NaN и бесконечность не ломают расчёт и не лечат цель", function()
		expect(Damage.compute(input({ attackPower = 0 / 0 }), SETTINGS).amount).toBe(0)
		expect(Damage.compute(input({ critDamage = math.huge }), SETTINGS).amount).toBe(0)
		expect(Damage.compute(input({ roll = 0 / 0 }), SETTINGS).amount).toBe(0)
	end)

	it(
		"удар героя по умолчанию убивает Шелуху не дольше, чем за десяток ударов",
		function()
			-- Проверка баланса, а не формулы: новичок должен справляться с первым врагом.
			local Enemies = require("../src/shared/Definitions/Enemies")
			local husk = Enemies.ById.husk
			local hit = Damage.compute({
				attackPower = Config.Hero.BaseStats.AttackPower,
				abilityMultiplier = Config.Weapon.ComboMultipliers[1],
				critChance = 0,
				critDamage = Config.Hero.BaseStats.CritDamage,
				armor = husk.armor,
				roll = 1,
			}, Config.Damage)
			local hits = math.ceil(husk.health / hit.amount)
			expect(hits).toBeGreaterThanOrEqual(2)
			expect(hits).toBeLessThanOrEqual(10)
		end
	)
end)

return nil
