local Test = require("./lib/Test")
local Leveling = require("../src/shared/Logic/Leveling")
local Config = require("../src/shared/Config")
local Enemies = require("../src/shared/Definitions/Enemies")

local expect = Test.expect

local PROGRESSION: Leveling.Progression = {
	MaxLevel = 5,
	XpCurve = { Base = 20, Exponent = 1.5 },
	PerLevel = { MaxHealth = 6, AttackPower = 0.5 },
}

Test.describe("Leveling.xpToNext", function(it)
	it("растёт с уровнем по кривой", function()
		expect(Leveling.xpToNext(1, PROGRESSION)).toBe(20)
		expect(Leveling.xpToNext(2, PROGRESSION)).toBe(56) -- 20 × 2^1,5 = 56,57
		expect(Leveling.xpToNext(3, PROGRESSION)).toBe(103)
	end)

	it("на максимальном уровне — 0", function()
		expect(Leveling.xpToNext(5, PROGRESSION)).toBe(0)
		expect(Leveling.xpToNext(9, PROGRESSION)).toBe(0)
	end)
end)

Test.describe("Leveling.addXp", function(it)
	it("копит опыт до порога", function()
		local result = Leveling.addXp(1, 5, 8, PROGRESSION)
		expect(result.level).toBe(1)
		expect(result.xp).toBe(13)
		expect(result.gained).toBe(0)
	end)

	it("ровно на пороге — новый уровень, остаток ноль", function()
		local result = Leveling.addXp(1, 12, 8, PROGRESSION)
		expect(result.level).toBe(2)
		expect(result.xp).toBe(0)
		expect(result.gained).toBe(1)
	end)

	it(
		"лишний опыт переходит на следующий уровень, можно взять несколько сразу",
		function()
			-- 20 до второго + 56 до третьего = 76; ещё 4 остаются
			local result = Leveling.addXp(1, 0, 80, PROGRESSION)
			expect(result.level).toBe(3)
			expect(result.xp).toBe(4)
			expect(result.gained).toBe(2)
		end
	)

	it("не поднимается выше максимума и не копит опыт на нём", function()
		local result = Leveling.addXp(4, 0, 1000000, PROGRESSION)
		expect(result.level).toBe(5)
		expect(result.xp).toBe(0)
		expect(result.gained).toBe(1)
		local again = Leveling.addXp(5, 0, 50, PROGRESSION)
		expect(again.level).toBe(5)
		expect(again.xp).toBe(0)
		expect(again.gained).toBe(0)
	end)

	it("испорченное начисление ничего не меняет", function()
		for _, amount in { -10, 0, 0 / 0, math.huge, -math.huge } do
			local result = Leveling.addXp(2, 7, amount, PROGRESSION)
			expect(result.level).toBe(2)
			expect(result.xp).toBe(7)
			expect(result.gained).toBe(0)
		end
	end)

	it("испорченные уровень и опыт приводятся в пределы", function()
		local result = Leveling.addXp(0, -5, 3, PROGRESSION)
		expect(result.level).toBe(1)
		expect(result.xp).toBe(3)
		expect(Leveling.addXp(1, 0 / 0, 3, PROGRESSION).xp).toBe(3)
	end)
end)

Test.describe("Leveling.modifiers", function(it)
	it("на первом уровне прибавок нет", function()
		expect(#Leveling.modifiers(1, PROGRESSION)).toBe(0)
	end)

	it("прибавки растут с каждым уровнем после первого", function()
		local list = Leveling.modifiers(3, PROGRESSION)
		expect(list).toEqual({
			{ stat = "AttackPower", op = "add", value = 1 },
			{ stat = "MaxHealth", op = "add", value = 12 },
		})
	end)

	it("уровень выше максимума считается максимумом", function()
		local list = Leveling.modifiers(99, PROGRESSION)
		expect(list[2].value).toBe(24) -- 4 шага × 6
	end)
end)

Test.describe("Leveling на числах игры", function(it)
	it(
		"первый уровень берётся за несколько Шелух, а не за одну",
		function()
			local husk = Enemies.ById.husk.xp
			local need = Leveling.xpToNext(1, Config.Progression)
			expect(need).toBeGreaterThan(husk)
			expect(need).toBeLessThanOrEqual(husk * 4)
		end
	)

	it(
		"прибавки за уровень относятся к настоящим характеристикам",
		function()
			for stat in Config.Progression.PerLevel do
				expect(Config.Hero.BaseStats[stat] ~= nil).toBeTruthy()
			end
		end
	)
end)

return nil
