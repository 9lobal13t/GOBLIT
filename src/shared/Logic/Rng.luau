--!strict
-- Детерминированный генератор случайных чисел (Mulberry32) с поддержкой seed.
-- Собственная реализация вместо Roblox Random: одинаковый результат в игре и в Lune-тестах,
-- а значит любую генерацию можно воспроизвести по seed вне Studio.
--
-- fork(label) создаёт независимый поток: изменения в одной подсистеме (например, в лут-таблицах)
-- не сдвигают последовательность в другой (например, в форме подземелья).

local TWO_32 = 4294967296

local Rng = {}
Rng.__index = Rng

export type Rng = typeof(setmetatable({} :: { seed: number, _state: number }, Rng))

-- 32-битное умножение по модулю 2^32 без потери точности double.
local function imul32(a: number, b: number): number
	local aLo = a % 65536
	local aHi = (a - aLo) / 65536
	local bLo = b % 65536
	local bHi = (b - bLo) / 65536
	local mid = (aHi * bLo + aLo * bHi) % 65536
	return (aLo * bLo + mid * 65536) % TWO_32
end

local function normalizeSeed(seed: number): number
	assert(type(seed) == "number" and seed == seed and math.abs(seed) ~= math.huge, "seed must be a finite number")
	return math.floor(math.abs(seed)) % TWO_32
end

-- FNV-1a 32 bit.
function Rng.hashString(text: string): number
	local hash = 2166136261
	for i = 1, #text do
		hash = bit32.bxor(hash, string.byte(text, i))
		hash = imul32(hash, 16777619)
	end
	return hash
end

function Rng.new(seed: number): Rng
	local normalized = normalizeSeed(seed)
	return setmetatable({ seed = normalized, _state = normalized }, Rng)
end

function Rng.nextUInt32(self: Rng): number
	self._state = (self._state + 0x6D2B79F5) % TWO_32
	local t = self._state
	t = imul32(bit32.bxor(t, bit32.rshift(t, 15)), bit32.bor(t, 1))
	t = bit32.bxor(t, (t + imul32(bit32.bxor(t, bit32.rshift(t, 7)), bit32.bor(t, 61))) % TWO_32)
	return bit32.bxor(t, bit32.rshift(t, 14))
end

-- Число в [0, 1).
function Rng.nextNumber(self: Rng): number
	return self:nextUInt32() / TWO_32
end

-- Целое в [min, max] включительно.
function Rng.nextInt(self: Rng, min: number, max: number): number
	assert(min <= max, "nextInt: min > max")
	local lo = math.floor(min)
	local hi = math.floor(max)
	return lo + math.floor(self:nextNumber() * (hi - lo + 1))
end

function Rng.range(self: Rng, min: number, max: number): number
	return min + (max - min) * self:nextNumber()
end

function Rng.chance(self: Rng, probability: number): boolean
	return self:nextNumber() < probability
end

function Rng.pick<T>(self: Rng, list: { T }): T?
	if #list == 0 then
		return nil
	end
	return list[self:nextInt(1, #list)]
end

-- Индекс по весам; элементы с весом <= 0 никогда не выбираются. nil, если выбрать нечего.
function Rng.weightedIndex(self: Rng, weights: { number }): number?
	local total = 0
	for _, w in weights do
		if w > 0 then
			total += w
		end
	end
	if total <= 0 then
		return nil
	end
	local roll = self:nextNumber() * total
	local lastPositive: number? = nil
	for i, w in weights do
		if w > 0 then
			lastPositive = i
			if roll < w then
				return i
			end
			roll -= w
		end
	end
	return lastPositive -- защита от накопленной ошибки округления
end

function Rng.shuffle<T>(self: Rng, list: { T }): { T }
	for i = #list, 2, -1 do
		local j = self:nextInt(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

function Rng.fork(self: Rng, label: string): Rng
	return Rng.new(Rng.hashString(string.format("%d:%s", self.seed, label)))
end

return Rng
