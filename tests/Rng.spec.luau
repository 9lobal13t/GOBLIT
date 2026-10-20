local Test = require("./lib/Test")
local Rng = require("../src/shared/Logic/Rng")

local expect = Test.expect

local function sequence(rng: any, count: number): { number }
	local values = {}
	for i = 1, count do
		values[i] = rng:nextNumber()
	end
	return values
end

Test.describe("Rng", function(it)
	it("совпадает с эталонной реализацией Mulberry32 (JavaScript)", function()
		-- Значения получены из канонической JS-версии mulberry32 (см. docs/TESTING.md).
		local reference = {
			[42] = { 0.601103751920164, 0.448290558997542, 0.852465793490410 },
			[0] = { 0.266429208684713, 0.000329745700583, 0.223272027447820 },
			[123456789] = { 0.257790743838996, 0.970772111555561, 0.785328014288098 },
			[4294967295] = { 0.896422614110634, 0.189478256739676, 0.715652678161860 },
		}
		for seed, expected in reference do
			local rng = Rng.new(seed)
			for _, value in expected do
				expect(rng:nextNumber()).toBeCloseTo(value, 1e-12)
			end
		end
	end)

	it("один seed даёт одну и ту же последовательность", function()
		expect(sequence(Rng.new(777), 500)).toEqual(sequence(Rng.new(777), 500))
	end)

	it("разные seed дают разные последовательности", function()
		local a, b = sequence(Rng.new(1), 20), sequence(Rng.new(2), 20)
		local same = 0
		for i = 1, 20 do
			if a[i] == b[i] then
				same += 1
			end
		end
		expect(same).toBeLessThan(2)
	end)

	it("nextNumber всегда в [0, 1)", function()
		local rng = Rng.new(99)
		for _ = 1, 20000 do
			local value = rng:nextNumber()
			expect(value).toBeGreaterThanOrEqual(0)
			expect(value).toBeLessThan(1)
		end
	end)

	it("nextInt включает обе границы и не выходит за них", function()
		local rng = Rng.new(5)
		local seen = {}
		for _ = 1, 5000 do
			local value = rng:nextInt(-2, 3)
			expect(value).toBeGreaterThanOrEqual(-2)
			expect(value).toBeLessThanOrEqual(3)
			expect(value % 1).toBe(0)
			seen[value] = true
		end
		for value = -2, 3 do
			expect(seen[value]).toBe(true)
		end
		expect(rng:nextInt(4, 4)).toBe(4)
	end)

	it("nextInt с min > max — ошибка", function()
		expect(function()
			Rng.new(1):nextInt(5, 1)
		end).toThrow("min > max")
	end)

	it("некорректный seed — ошибка, а не тихий мусор", function()
		expect(function()
			Rng.new(0 / 0)
		end).toThrow("finite")
		expect(function()
			Rng.new(math.huge)
		end).toThrow("finite")
	end)

	it("seed нормализуется: модуль и отбрасывание дробной части", function()
		expect(sequence(Rng.new(-5.7), 5)).toEqual(sequence(Rng.new(5), 5))
		expect(sequence(Rng.new(2 ^ 32 + 7), 5)).toEqual(sequence(Rng.new(7), 5))
	end)

	it(
		"fork детерминирован и не зависит от того, сколько чисел уже взято у родителя",
		function()
			local parent = Rng.new(2024)
			local early = sequence(parent:fork("dungeon"), 10)
			sequence(parent, 100)
			local late = sequence(parent:fork("dungeon"), 10)
			expect(late).toEqual(early)
			expect(sequence(Rng.new(2024):fork("dungeon"), 10)).toEqual(early)
		end
	)

	it("fork с разными метками даёт независимые потоки", function()
		local parent = Rng.new(2024)
		expect(parent:fork("loot"):nextNumber() ~= parent:fork("dungeon"):nextNumber()).toBe(true)
	end)

	it(
		"weightedIndex никогда не выбирает нулевые и отрицательные веса",
		function()
			local rng = Rng.new(7)
			for _ = 1, 5000 do
				local index = rng:weightedIndex({ 0, 3, -1, 1 })
				expect(index == 2 or index == 4).toBe(true)
			end
		end
	)

	it("weightedIndex без положительных весов возвращает nil", function()
		expect(Rng.new(1):weightedIndex({})).toBeNil()
		expect(Rng.new(1):weightedIndex({ 0, 0, -5 })).toBeNil()
	end)

	it("weightedIndex распределяет пропорционально весам", function()
		local rng = Rng.new(11)
		local counts = { 0, 0, 0 }
		local total = 30000
		for _ = 1, total do
			local index = rng:weightedIndex({ 1, 2, 7 }) :: number
			counts[index] += 1
		end
		expect(counts[1] / total).toBeCloseTo(0.1, 0.01)
		expect(counts[2] / total).toBeCloseTo(0.2, 0.01)
		expect(counts[3] / total).toBeCloseTo(0.7, 0.01)
	end)

	it("shuffle сохраняет элементы и детерминирован", function()
		local function shuffled(seed: number): { number }
			local list = { 1, 2, 3, 4, 5, 6, 7, 8 }
			return Rng.new(seed):shuffle(list)
		end
		local result = shuffled(3)
		local sorted = table.clone(result)
		table.sort(sorted)
		expect(sorted).toEqual({ 1, 2, 3, 4, 5, 6, 7, 8 })
		expect(shuffled(3)).toEqual(result)
	end)

	it("pick на пустом списке возвращает nil", function()
		expect(Rng.new(1):pick({})).toBeNil()
		expect(Rng.new(1):pick({ "a" })).toBe("a")
	end)

	it("hashString — FNV-1a 32 bit", function()
		-- Эталонные значения FNV-1a: "" → 2166136261, "a" → 3826002220.
		expect(Rng.hashString("")).toBe(2166136261)
		expect(Rng.hashString("a")).toBe(3826002220)
	end)
end)

return nil
