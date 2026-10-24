--!strict
-- Опыт и уровни героя. Чистый модуль без Roblox API: числа приходят параметрами
-- (Config.Progression), тесты — tests/Leveling.spec.luau.
--
-- Сколько опыта нужно до следующего уровня: Base × уровень ^ Exponent (округление вниз).
-- Каждый уровень после первого даёт прибавки из PerLevel — они складываются с перками
-- в Logic/Stats, как любые другие модификаторы.

local Leveling = {}

export type Curve = { Base: number, Exponent: number }

export type Progression = {
	MaxLevel: number,
	XpCurve: Curve,
	PerLevel: { [string]: number },
}

export type Modifier = { stat: string, op: string, value: number }

export type Progress = {
	level: number,
	xp: number, -- накоплено на текущем уровне
	gained: number, -- сколько уровней получено этим начислением
}

local function isFinite(value: number): boolean
	return value == value and math.abs(value) ~= math.huge
end

-- Опыт до следующего уровня. На максимальном уровне — 0: расти больше некуда.
function Leveling.xpToNext(level: number, progression: Progression): number
	if level >= progression.MaxLevel then
		return 0
	end
	local curve = progression.XpCurve
	return math.max(1, math.floor(curve.Base * math.max(level, 1) ^ curve.Exponent))
end

-- Начисляет опыт. Лишний опыт переходит на следующий уровень, за одно начисление можно
-- получить несколько уровней. На максимальном уровне опыт больше не копится.
-- Отрицательное, NaN и бесконечное начисление ничего не меняет: опыт не отнимается.
function Leveling.addXp(level: number, xp: number, amount: number, progression: Progression): Progress
	local current = math.clamp(math.floor(level), 1, progression.MaxLevel)
	local stored = if isFinite(xp) and xp > 0 then math.floor(xp) else 0
	if not isFinite(amount) or amount <= 0 or current >= progression.MaxLevel then
		return { level = current, xp = if current >= progression.MaxLevel then 0 else stored, gained = 0 }
	end

	local total = stored + math.floor(amount)
	local gained = 0
	while current < progression.MaxLevel do
		local need = Leveling.xpToNext(current, progression)
		if total < need then
			break
		end
		total -= need
		current += 1
		gained += 1
	end
	if current >= progression.MaxLevel then
		total = 0
	end
	return { level = current, xp = total, gained = gained }
end

-- Прибавки характеристик за уровень (первый уровень — без прибавок).
function Leveling.modifiers(level: number, progression: Progression): { Modifier }
	local steps = math.clamp(math.floor(level), 1, progression.MaxLevel) - 1
	local list: { Modifier } = {}
	if steps <= 0 then
		return list
	end
	for stat, perLevel in progression.PerLevel do
		table.insert(list, { stat = stat, op = "add", value = perLevel * steps })
	end
	-- Порядок обхода словаря не задан, а одинаковый набор удобнее и в тестах, и в отладке.
	table.sort(list, function(a, b)
		return a.stat < b.stat
	end)
	return list
end

return table.freeze(Leveling)
