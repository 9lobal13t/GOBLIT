--!strict
-- Единый расчёт урона (ТЗ 7.4). Чистый модуль без Roblox API (тестируется в Lune).
--
-- Формула:
--   урон = сила атаки × множитель приёма × множитель крита × снижение бронёй
--   снижение бронёй = 100 / (100 + броня × ArmorScale)
--
-- Бросок кубика передаётся снаружи, а не делается внутри: так расчёт остаётся чистой
-- функцией, и крит можно проверить тестом, а не «поймать» на тысячном запуске.
--
-- Результат — целое число не меньше 1 (если урон вообще наносится) и не больше MaxDamage.
-- Любой неверный ввод (NaN, бесконечность, отрицательные значения) даёт 0, а не мусор:
-- урон не должен лечить цель и не должен обнулять здоровье из-за ошибки в данных.

export type Input = {
	attackPower: number,
	abilityMultiplier: number,
	critChance: number,
	critDamage: number,
	armor: number,
	roll: number, -- 0..1, значение меньше critChance означает критический удар
}

export type Result = {
	amount: number,
	crit: boolean,
}

export type Settings = {
	ArmorScale: number,
	MaxDamage: number,
}

local Damage = {}

local function isFinite(value: number): boolean
	return type(value) == "number" and value == value and math.abs(value) ~= math.huge
end

-- Во сколько раз броня уменьшает урон: 1 при нулевой броне, никогда не ноль и не больше 1.
function Damage.armorMultiplier(armor: number, armorScale: number): number
	if not isFinite(armor) or armor <= 0 then
		return 1
	end
	return 100 / (100 + armor * armorScale)
end

function Damage.compute(input: Input, settings: Settings): Result
	local fields = { input.attackPower, input.abilityMultiplier, input.critChance, input.critDamage, input.roll }
	for _, value in fields do
		if not isFinite(value) then
			return { amount = 0, crit = false }
		end
	end
	if input.attackPower <= 0 or input.abilityMultiplier <= 0 then
		return { amount = 0, crit = false }
	end

	local crit = input.roll < input.critChance
	local critMultiplier = if crit then math.max(input.critDamage, 1) else 1
	local raw = input.attackPower
		* input.abilityMultiplier
		* critMultiplier
		* Damage.armorMultiplier(input.armor, settings.ArmorScale)

	local amount = math.clamp(math.floor(raw + 0.5), 1, settings.MaxDamage)
	return { amount = amount, crit = crit }
end

return table.freeze(Damage)
