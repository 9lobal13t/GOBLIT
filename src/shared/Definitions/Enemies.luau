--!strict
-- Архетипы противников. Только данные; поведение реализует server/Services/EnemyService.
-- Цвета — hex-строки, модели собираются из примитивов (см. docs/ASSET_PIPELINE.md).

export type AttackKind = "melee" | "slam"

export type EliteDef = {
	displayName: string,
	healthMult: number,
	damageMult: number,
	scale: number,
	attack: AttackKind,
	windup: number,
	slamRadius: number,
	xpMult: number,
	goldMult: number,
}

export type EnemyDef = {
	id: string,
	displayName: string,
	behavior: "melee" | "dummy",
	health: number,
	damage: number,
	armor: number,
	speed: number,
	aggroRange: number,
	attackRange: number,
	attackArcDegrees: number,
	windup: number,
	recover: number,
	flank: boolean,
	xp: number,
	gold: { Min: number, Max: number },
	cost: number,
	minDepth: number,
	weight: number,
	immortal: boolean,
	look: { body: string, accent: string, scale: number },
	elite: EliteDef?,
}

local list: { EnemyDef } = {
	{
		id = "husk",
		displayName = "Шелуха",
		behavior = "melee",
		health = 45,
		damage = 12,
		armor = 0,
		speed = 9,
		aggroRange = 60,
		attackRange = 5.5,
		attackArcDegrees = 100,
		windup = 0.7,
		recover = 0.9,
		flank = false,
		xp = 8,
		gold = { Min = 2, Max = 5 },
		cost = 2,
		minDepth = 0,
		weight = 10,
		immortal = false,
		look = { body = "#6e7a5c", accent = "#ff8a3d", scale = 1 },
		elite = {
			displayName = "Шелуха-громила",
			healthMult = 3,
			damageMult = 1.4,
			scale = 1.35,
			attack = "slam",
			windup = 1.05,
			slamRadius = 9,
			xpMult = 3,
			goldMult = 3,
		},
	},
	{
		id = "skitter",
		displayName = "Стригун",
		behavior = "melee",
		health = 18,
		damage = 6,
		armor = 0,
		speed = 19,
		aggroRange = 70,
		attackRange = 4.5,
		attackArcDegrees = 90,
		windup = 0.35,
		recover = 0.7,
		flank = true,
		xp = 5,
		gold = { Min = 1, Max = 3 },
		cost = 1,
		minDepth = 1,
		weight = 7,
		immortal = false,
		look = { body = "#4b3a66", accent = "#c6ff4d", scale = 0.65 },
		elite = {
			displayName = "Стригун-вожак",
			healthMult = 2.5,
			damageMult = 1.3,
			scale = 0.9,
			attack = "melee",
			windup = 0.3,
			slamRadius = 0,
			xpMult = 3,
			goldMult = 3,
		},
	},
	{
		id = "dummy",
		displayName = "Тренировочный манекен",
		behavior = "dummy",
		health = 500,
		damage = 0,
		armor = 0,
		speed = 0,
		aggroRange = 0,
		attackRange = 0,
		attackArcDegrees = 0,
		windup = 0,
		recover = 0,
		flank = false,
		xp = 0,
		gold = { Min = 0, Max = 0 },
		cost = 0,
		minDepth = math.huge, -- никогда не попадает в подземелье
		weight = 0,
		immortal = true,
		look = { body = "#8a6a45", accent = "#e8d27a", scale = 1 },
		elite = nil,
	},
}

local byId: { [string]: EnemyDef } = {}
for _, def in list do
	assert(byId[def.id] == nil, "duplicate enemy id " .. def.id)
	byId[def.id] = def
end

return table.freeze({
	List = list,
	ById = byId,
})
