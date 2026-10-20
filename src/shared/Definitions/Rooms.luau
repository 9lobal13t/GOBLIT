--!strict
-- Категории и шаблоны комнат. Только данные.
-- Координаты — в локальной системе комнаты: X и Z в диапазоне [-RoomSize/2, RoomSize/2],
-- центр пола — (0, 0). Проёмы дверей находятся в центрах сторон, поэтому препятствия
-- не ставятся ближе ~8 стадов к центру любой стороны.

export type Side = "N" | "E" | "S" | "W"
export type Vec2 = { x: number, z: number }

export type Obstacle = {
	kind: "pillar" | "lowwall" | "rubble",
	pos: Vec2,
	size: { x: number, y: number, z: number },
}

export type FeatureKind = "chest" | "altar" | "fountain" | "portal" | "campfire"

export type Feature = {
	kind: FeatureKind,
	pos: Vec2,
}

export type RoomTemplate = {
	id: string,
	category: string,
	displayName: string,
	sockets: { Side },
	weight: number,
	obstacles: { Obstacle },
	features: { Feature },
	braziers: { Vec2 },
	spawnPoints: { Vec2 },
	playerSpawns: { Vec2 },
}

export type EncounterRule = {
	chance: number,
	baseBudget: number,
	budgetPerDepth: number,
	elite: boolean,
	eliteEnemyId: string?,
}

export type Category = {
	id: string,
	displayName: string,
	accent: string,
	encounter: EncounterRule?,
}

local function v(x: number, z: number): Vec2
	return { x = x, z = z }
end

local function pillar(x: number, z: number, w: number, h: number): Obstacle
	return { kind = "pillar", pos = v(x, z), size = { x = w, y = h, z = w } }
end

local function lowwall(x: number, z: number, sx: number, sz: number): Obstacle
	return { kind = "lowwall", pos = v(x, z), size = { x = sx, y = 4, z = sz } }
end

local function feature(kind: FeatureKind, x: number, z: number): Feature
	return { kind = kind, pos = v(x, z) }
end

local function rubble(x: number, z: number, s: number, h: number): Obstacle
	return { kind = "rubble", pos = v(x, z), size = { x = s, y = h, z = s } }
end

local ALL_SIDES: { Side } = { "N", "E", "S", "W" }
local NORTH_SOUTH: { Side } = { "N", "S" }
local EAST_WEST: { Side } = { "E", "W" }
local CORNER_BRAZIERS = { v(-26, -26), v(26, -26), v(-26, 26), v(26, 26) }
local RING_SPAWNS = {
	v(0, 0),
	v(-18, -8),
	v(18, 8),
	v(-8, 18),
	v(8, -18),
	v(-20, 20),
	v(20, -20),
	v(20, 20),
	v(-20, -20),
}

local Categories: { [string]: Category } = {
	Start = { id = "Start", displayName = "Лагерь у входа", accent = "#ffb36b", encounter = nil },
	Combat = {
		id = "Combat",
		displayName = "Зал",
		accent = "#ff8a3d",
		encounter = { chance = 1, baseBudget = 3, budgetPerDepth = 0.9, elite = false },
	},
	Elite = {
		id = "Elite",
		displayName = "Логово элиты",
		accent = "#c34dff",
		encounter = { chance = 1, baseBudget = 1.5, budgetPerDepth = 0.6, elite = true },
	},
	Treasure = {
		id = "Treasure",
		displayName = "Сокровищница",
		accent = "#ffd34d",
		encounter = { chance = 0.5, baseBudget = 2, budgetPerDepth = 0.4, elite = false },
	},
	Altar = { id = "Altar", displayName = "Кровавый алтарь", accent = "#ff3355", encounter = nil },
	Rest = { id = "Rest", displayName = "Тихий источник", accent = "#4dd8ff", encounter = nil },
	Exit = {
		id = "Exit",
		displayName = "Зал эвакуации",
		accent = "#9b6bff",
		encounter = { chance = 1, baseBudget = 2, budgetPerDepth = 0.5, elite = true, eliteEnemyId = "husk" },
	},
	Secret = { id = "Secret", displayName = "Тайник", accent = "#6bff9b", encounter = nil },
}

type TemplateInput = {
	id: string,
	category: string,
	displayName: string,
	sockets: { Side }?,
	weight: number?,
	obstacles: { Obstacle }?,
	features: { Feature }?,
	braziers: { Vec2 }?,
	spawnPoints: { Vec2 }?,
	playerSpawns: { Vec2 }?,
}

local function template(input: TemplateInput): RoomTemplate
	return {
		id = input.id,
		category = input.category,
		displayName = input.displayName,
		sockets = input.sockets or ALL_SIDES,
		weight = input.weight or 1,
		obstacles = input.obstacles or {},
		features = input.features or {},
		braziers = input.braziers or CORNER_BRAZIERS,
		spawnPoints = input.spawnPoints or RING_SPAWNS,
		playerSpawns = input.playerSpawns or {},
	}
end

local Templates: { RoomTemplate } = {
	template({
		id = "start_camp",
		category = "Start",
		displayName = "Лагерь у входа",
		features = { feature("campfire", 0, 0) },
		obstacles = { rubble(-20, 18, 4, 3), rubble(19, -20, 5, 2) },
		playerSpawns = { v(8, 0), v(-8, 0), v(0, 8), v(0, -8), v(6, 6), v(-6, -6) },
		spawnPoints = {},
	}),
	template({
		id = "combat_pillars",
		category = "Combat",
		displayName = "Зал колонн",
		weight = 3,
		obstacles = { pillar(-14, -14, 4, 18), pillar(14, -14, 4, 18), pillar(-14, 14, 4, 18), pillar(14, 14, 4, 18) },
	}),
	template({
		id = "combat_open",
		category = "Combat",
		displayName = "Разрушенный зал",
		weight = 2,
		obstacles = { rubble(0, 0, 6, 3), lowwall(-16, 10, 10, 2), lowwall(16, -10, 10, 2) },
		spawnPoints = { v(-20, -16), v(20, 16), v(-6, 20), v(6, -20), v(10, 8), v(-10, -8), v(22, -22), v(-22, 22) },
	}),
	template({
		id = "combat_ring",
		category = "Combat",
		displayName = "Круг колонн",
		weight = 2,
		obstacles = {
			pillar(16.6, 6.9, 2.5, 10),
			pillar(6.9, 16.6, 2.5, 10),
			pillar(-6.9, 16.6, 2.5, 10),
			pillar(-16.6, 6.9, 2.5, 10),
			pillar(-16.6, -6.9, 2.5, 10),
			pillar(-6.9, -16.6, 2.5, 10),
			pillar(6.9, -16.6, 2.5, 10),
			pillar(16.6, -6.9, 2.5, 10),
		},
		-- Кольцо колонн на радиусе 18: точки внутри кольца и в углах за ним.
		spawnPoints = {
			v(0, 0),
			v(10, 0),
			v(-10, 0),
			v(0, 10),
			v(0, -10),
			v(24, 24),
			v(-24, -24),
			v(24, -24),
			v(-24, 24),
		},
	}),
	template({
		id = "combat_split",
		category = "Combat",
		displayName = "Зал укрытий",
		weight = 2,
		obstacles = { lowwall(-12, 0, 2, 22), lowwall(12, 0, 2, 22), rubble(0, 0, 3, 2) },
		spawnPoints = { v(-22, -10), v(22, 10), v(-22, 12), v(22, -12), v(0, 14), v(0, -14), v(-4, 4), v(4, -4) },
	}),
	template({
		id = "hall_ns",
		category = "Combat",
		displayName = "Длинная галерея",
		sockets = NORTH_SOUTH,
		weight = 2,
		obstacles = { lowwall(-16, 0, 2, 40), lowwall(16, 0, 2, 40), pillar(0, 0, 3, 18) },
		spawnPoints = { v(-8, -20), v(8, -10), v(-8, 10), v(8, 20), v(6, 0), v(-6, 0) },
	}),
	template({
		id = "hall_ew",
		category = "Combat",
		displayName = "Поперечная галерея",
		sockets = EAST_WEST,
		weight = 2,
		obstacles = { lowwall(0, -16, 40, 2), lowwall(0, 16, 40, 2), pillar(0, 0, 3, 18) },
		spawnPoints = { v(-20, -8), v(-10, 8), v(10, -8), v(20, 8), v(0, 6), v(0, -6) },
	}),
	template({
		id = "elite_arena",
		category = "Elite",
		displayName = "Логово элиты",
		obstacles = { pillar(-20, -20, 5, 18), pillar(20, -20, 5, 18), pillar(-20, 20, 5, 18), pillar(20, 20, 5, 18) },
		spawnPoints = { v(0, 0), v(-12, 12), v(12, -12), v(12, 12), v(-12, -12), v(0, 18), v(0, -18) },
	}),
	template({
		id = "treasure_vault",
		category = "Treasure",
		displayName = "Сокровищница",
		features = {
			feature("chest", 0, 0),
			feature("chest", -14, -14),
			feature("chest", 14, 14),
		},
		obstacles = { pillar(-14, 14, 3, 12), pillar(14, -14, 3, 12) },
		spawnPoints = { v(-20, 4), v(20, -4), v(4, 20), v(-4, -20) },
	}),
	template({
		id = "altar_shrine",
		category = "Altar",
		displayName = "Кровавый алтарь",
		features = { feature("altar", 0, 0) },
		obstacles = {
			pillar(-12, -12, 2.5, 14),
			pillar(12, -12, 2.5, 14),
			pillar(-12, 12, 2.5, 14),
			pillar(12, 12, 2.5, 14),
		},
		spawnPoints = {},
	}),
	template({
		id = "rest_spring",
		category = "Rest",
		displayName = "Тихий источник",
		features = { feature("fountain", 0, 0) },
		obstacles = { rubble(-18, 18, 4, 2), rubble(18, -18, 4, 2) },
		spawnPoints = {},
	}),
	template({
		id = "exit_portal",
		category = "Exit",
		displayName = "Зал эвакуации",
		features = { feature("portal", 0, 0) },
		obstacles = { pillar(-18, -18, 4, 18), pillar(18, 18, 4, 18) },
		spawnPoints = { v(0, 14), v(-14, 0), v(14, 0), v(0, -14), v(-20, 20), v(20, -20) },
	}),
	template({
		id = "secret_cache",
		category = "Secret",
		displayName = "Тайник",
		features = { feature("chest", 0, 0) },
		obstacles = { rubble(-12, 10, 3, 2), rubble(12, -10, 3, 2) },
		spawnPoints = {},
	}),
}

local byId: { [string]: RoomTemplate } = {}
local byCategory: { [string]: { RoomTemplate } } = {}
for _, t in Templates do
	assert(byId[t.id] == nil, "duplicate room template " .. t.id)
	assert(Categories[t.category] ~= nil, "unknown room category " .. t.category)
	byId[t.id] = t
	local bucket = byCategory[t.category]
	if not bucket then
		bucket = {}
		byCategory[t.category] = bucket
	end
	table.insert(bucket, t)
end

return table.freeze({
	Categories = Categories,
	Templates = Templates,
	ById = byId,
	ByCategory = byCategory,
	AllSides = ALL_SIDES,
})
