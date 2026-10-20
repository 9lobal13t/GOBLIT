--!strict
-- Подсчёт характеристик героя: базовые значения плюс модификаторы перков и предметов.
-- Чистый модуль без Roblox API (тестируется в Lune).
--
-- Порядок применения: сначала складываются все прибавки, потом перемножаются все множители,
-- и только затем результат зажимается в пределы. Такой порядок не зависит от того, в каком
-- порядке игрок набрал перки: два одинаковых набора всегда дают одинаковые характеристики.
--
-- Пределы (Config.Hero.StatCaps) — защита от бесконечного роста (ТЗ 9.6): какие бы перки
-- ни сложились, шанс крита не превысит потолок, а перезарядка не уйдёт в ноль.

export type Modifier = {
	stat: string,
	op: string, -- "add" | "mul"
	value: number,
}

export type Cap = { Min: number, Max: number }

local Stats = {}

local function isFinite(value: number): boolean
	return value == value and math.abs(value) ~= math.huge
end

-- Считает итоговые характеристики. Модификаторы на неизвестные характеристики
-- игнорируются: состав модификаторов проверяется тестами данных, а падать во время
-- игры из-за опечатки в перке нельзя.
function Stats.compute(
	base: { [string]: number },
	modifiers: { Modifier },
	caps: { [string]: Cap }
): { [string]: number }
	local added: { [string]: number } = {}
	local multiplied: { [string]: number } = {}

	for _, modifier in modifiers do
		if base[modifier.stat] == nil or not isFinite(modifier.value) then
			continue
		end
		if modifier.op == "add" then
			added[modifier.stat] = (added[modifier.stat] or 0) + modifier.value
		elseif modifier.op == "mul" then
			multiplied[modifier.stat] = (multiplied[modifier.stat] or 1) * modifier.value
		end
	end

	local result: { [string]: number } = {}
	for stat, baseValue in base do
		local value = (baseValue + (added[stat] or 0)) * (multiplied[stat] or 1)
		local cap = caps[stat]
		if cap then
			value = math.clamp(value, cap.Min, cap.Max)
		end
		result[stat] = value
	end
	return result
end

-- Пауза между ударами: базовый интервал оружия, делённый на скорость атаки.
function Stats.attackInterval(weaponInterval: number, attackSpeed: number): number
	assert(weaponInterval > 0, "weaponInterval must be positive")
	assert(attackSpeed > 0, "attackSpeed must be positive")
	return weaponInterval / attackSpeed
end

return table.freeze(Stats)
