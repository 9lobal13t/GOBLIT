--!strict
-- Определения перков: только данные.
-- Числовые эффекты описываются через modifiers (их применяет Logic/Stats),
-- поведенческие — через hook = true и реализацию в server/Perks/PerkEffects.luau.
-- Параметры хуков лежат рядом с описанием в params: меняя число, обновите и текст.

export type ModifierOp = "add" | "mul"

export type Modifier = {
	stat: string,
	op: ModifierOp,
	value: number,
}

export type PerkDef = {
	id: string,
	name: string,
	description: string,
	drawback: string?,
	rarity: string,
	category: string,
	tags: { string },
	maxStacks: number,
	modifiers: { Modifier },
	hook: boolean,
	params: { [string]: number },
	excludes: { string },
	weight: number,
}

local Categories = {
	Offensive = "Атака",
	Defensive = "Защита",
	Mobility = "Мобильность",
	Critical = "Критические удары",
	Elemental = "Стихии",
	Summoning = "Призыв",
	Support = "Поддержка",
	Economy = "Экономика",
	Exploration = "Исследование",
	Risk = "Риск",
	Chaos = "Хаос",
	Hybrid = "Гибрид",
}

-- Подписи характеристик для интерфейса.
local StatLabels = {
	MaxHealth = "Макс. здоровье",
	MaxStamina = "Макс. выносливость",
	AttackPower = "Сила атаки",
	CritChance = "Шанс крита",
	CritDamage = "Крит. урон",
	AttackSpeed = "Скорость атаки",
	MoveSpeed = "Скорость бега",
	Armor = "Броня",
	DodgeCooldown = "Перезарядка уклонения",
	LifeOnKill = "Лечение за убийство",
	GoldFind = "Получаемое золото",
	ChestAmbushChance = "Шанс засады у сундука",
}

-- Характеристики, где рост значения — это плохо (для цвета в интерфейсе).
local NegativeStats = {
	DodgeCooldown = true,
	ChestAmbushChance = true,
}

type PerkInput = {
	id: string,
	name: string,
	description: string,
	drawback: string?,
	rarity: string,
	category: string,
	tags: { string }?,
	maxStacks: number?,
	modifiers: { Modifier }?,
	hook: boolean?,
	params: { [string]: number }?,
	excludes: { string }?,
	weight: number?,
}

local function perk(input: PerkInput): PerkDef
	return {
		id = input.id,
		name = input.name,
		description = input.description,
		drawback = input.drawback,
		rarity = input.rarity,
		category = input.category,
		tags = input.tags or {},
		maxStacks = input.maxStacks or 1,
		modifiers = input.modifiers or {},
		hook = input.hook == true,
		params = input.params or {},
		excludes = input.excludes or {},
		weight = input.weight or 1,
	}
end

local list: { PerkDef } = {
	perk({
		id = "sharpened_edge",
		name = "Заточенный клинок",
		description = "Простая правка лезвия перед следующей дверью.",
		rarity = "Common",
		category = "Offensive",
		tags = { "melee" },
		maxStacks = 3,
		modifiers = { { stat = "AttackPower", op = "mul", value = 1.12 } },
	}),
	perk({
		id = "toughened_hide",
		name = "Дублёная шкура",
		description = "Шрамы — тоже броня.",
		rarity = "Common",
		category = "Defensive",
		maxStacks = 3,
		modifiers = { { stat = "MaxHealth", op = "add", value = 20 } },
	}),
	perk({
		id = "fleet_foot",
		name = "Лёгкая поступь",
		description = "Бегаете быстрее и чаще уклоняетесь.",
		rarity = "Common",
		category = "Mobility",
		tags = { "dodge" },
		maxStacks = 2,
		modifiers = {
			{ stat = "MoveSpeed", op = "mul", value = 1.08 },
			{ stat = "DodgeCooldown", op = "mul", value = 0.85 },
		},
	}),
	perk({
		id = "keen_eye",
		name = "Намётанный глаз",
		description = "Вы замечаете щели в броне.",
		rarity = "Uncommon",
		category = "Critical",
		tags = { "crit" },
		maxStacks = 3,
		modifiers = { { stat = "CritChance", op = "add", value = 0.08 } },
	}),
	perk({
		id = "brutal_crits",
		name = "Жестокие криты",
		description = "Критические удары бьют заметно сильнее.",
		rarity = "Rare",
		category = "Critical",
		tags = { "crit" },
		maxStacks = 2,
		modifiers = { { stat = "CritDamage", op = "add", value = 0.5 } },
	}),
	perk({
		id = "swift_strikes",
		name = "Быстрые удары",
		description = "Короткий замах, меньше пауза между ударами.",
		rarity = "Uncommon",
		category = "Offensive",
		tags = { "melee", "speed" },
		maxStacks = 3,
		modifiers = { { stat = "AttackSpeed", op = "mul", value = 1.12 } },
	}),
	perk({
		id = "iron_skin",
		name = "Железная кожа",
		description = "Снижает весь входящий урон.",
		rarity = "Uncommon",
		category = "Defensive",
		maxStacks = 3,
		modifiers = { { stat = "Armor", op = "add", value = 4 } },
	}),
	perk({
		id = "bloodthirst",
		name = "Жажда крови",
		description = "Каждое убийство восстанавливает здоровье.",
		rarity = "Uncommon",
		category = "Offensive",
		tags = { "sustain" },
		maxStacks = 2,
		modifiers = { { stat = "LifeOnKill", op = "add", value = 0.04 } },
	}),
	perk({
		id = "glass_cannon",
		name = "Стеклянная пушка",
		description = "Огромный урон ценой живучести.",
		drawback = "Максимальное здоровье −25%",
		rarity = "Rare",
		category = "Risk",
		tags = { "risk" },
		modifiers = {
			{ stat = "AttackPower", op = "mul", value = 1.35 },
			{ stat = "MaxHealth", op = "mul", value = 0.75 },
		},
	}),
	perk({
		id = "last_stand",
		name = "Последний рубеж",
		description = "Когда здоровье падает ниже 25%, вы на 2 с становитесь неуязвимы и восстанавливаете 15% здоровья. Перезарядка 60 с.",
		rarity = "Rare",
		category = "Defensive",
		tags = { "sustain" },
		hook = true,
		params = { Threshold = 0.25, InvulnerableSeconds = 2, HealFraction = 0.15, Cooldown = 60 },
	}),
	perk({
		id = "echo_strike",
		name = "Эхо удара",
		description = "Каждый 3-й удар по одной цели через 0,35 с повторяется с силой 50%.",
		rarity = "Epic",
		category = "Offensive",
		tags = { "melee" },
		hook = true,
		params = { HitsRequired = 3, Delay = 0.35, Multiplier = 0.5 },
	}),
	perk({
		id = "rift_runner",
		name = "Бегущий по разлому",
		description = "После уклонения следующая атака в течение 1,5 с наносит +40% урона.",
		rarity = "Rare",
		category = "Mobility",
		tags = { "dodge" },
		hook = true,
		params = { WindowSeconds = 1.5, DamageBonus = 0.4 },
	}),
	perk({
		id = "greedy_hands",
		name = "Загребущие руки",
		description = "Вы получаете больше золота.",
		drawback = "Открытый вами сундук может привести засаду",
		rarity = "Uncommon",
		category = "Economy",
		tags = { "greed", "risk" },
		modifiers = {
			{ stat = "GoldFind", op = "add", value = 0.35 },
			{ stat = "ChestAmbushChance", op = "add", value = 0.25 },
		},
	}),
}

local byId: { [string]: PerkDef } = {}
for _, def in list do
	assert(byId[def.id] == nil, "duplicate perk id " .. def.id)
	byId[def.id] = def
end

return table.freeze({
	List = list,
	ById = byId,
	Categories = table.freeze(Categories),
	StatLabels = table.freeze(StatLabels),
	NegativeStats = table.freeze(NegativeStats),
})
