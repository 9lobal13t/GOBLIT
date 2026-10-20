local Test = require("./lib/Test")
local Config = require("../src/shared/Config")
local Rarity = require("../src/shared/Definitions/Rarity")
local Perks = require("../src/shared/Definitions/Perks")
local Enemies = require("../src/shared/Definitions/Enemies")
local Rooms = require("../src/shared/Definitions/Rooms")

local expect = Test.expect

local function isDeepFrozen(value: any): boolean
	if type(value) ~= "table" then
		return true
	end
	if not table.isfrozen(value) then
		return false
	end
	for _, child in value do
		if not isDeepFrozen(child) then
			return false
		end
	end
	return true
end

Test.describe("Config", function(it)
	it("полностью заморожен — случайно изменить баланс во время игры нельзя", function()
		expect(isDeepFrozen(Config)).toBe(true)
	end)

	it("у каждого предела Min ≤ Max, и базовые характеристики укладываются в пределы", function()
		for stat, cap in Config.Hero.StatCaps do
			expect(cap.Min <= cap.Max).toBe(true)
			local base = (Config.Hero.BaseStats :: any)[stat]
			expect(base ~= nil).toBe(true)
			expect(base >= cap.Min and base <= cap.Max).toBe(true)
		end
		for stat in Config.Hero.BaseStats do
			expect((Config.Hero.StatCaps :: any)[stat] ~= nil).toBe(true)
		end
	end)

	it("автосохранение продлевает блокировку профиля раньше, чем она устареет", function()
		expect(Config.Data.AutosaveSeconds * 2 < Config.Data.LockTtlSeconds).toBe(true)
	end)

	it("свежую чужую блокировку забираем только после худшего времени финальной записи", function()
		-- Финальная запись может ждать идущее автосохранение и сама делает до SaveAttempts попыток
		-- с паузами 2, 4, … с. Берём оба ожидания и запас 10 с на сами запросы.
		local backoff = 0
		for attempt = 1, Config.Data.SaveAttempts - 1 do
			backoff += 2 ^ attempt
		end
		expect(Config.Data.ForceLockAfterSeconds >= backoff * 2 + 10).toBe(true)
		expect(Config.Data.ForceLockAfterSeconds < Config.Data.LockTtlSeconds).toBe(true)
	end)

	it("в стартовом лагере хватает точек появления на полную группу", function()
		local start = Rooms.ById.start_camp
		expect(#start.playerSpawns >= Config.Lobby.MaxPartySize).toBe(true)
	end)
end)

Test.describe("Perks", function(it)
	it("редкость и категория каждого перка существуют", function()
		for _, perk in Perks.List do
			expect(Rarity.ById[perk.rarity] ~= nil).toBe(true)
			expect(Perks.Categories[perk.category] ~= nil).toBe(true)
		end
	end)

	it("модификаторы ссылаются только на существующие характеристики", function()
		for _, perk in Perks.List do
			for _, modifier in perk.modifiers do
				local known = (Config.Hero.BaseStats :: any)[modifier.stat] ~= nil
				if not known then
					error(`перк {perk.id}: неизвестная характеристика {modifier.stat}`)
				end
				expect(Perks.StatLabels[modifier.stat] ~= nil).toBe(true)
				expect(modifier.op == "add" or modifier.op == "mul").toBe(true)
				if modifier.op == "mul" then
					expect(modifier.value).toBeGreaterThan(0)
				end
			end
		end
	end)

	it("у каждого перка есть эффект, название и описание", function()
		for _, perk in Perks.List do
			expect(#perk.name > 0 and #perk.description > 0).toBe(true)
			expect(perk.maxStacks).toBeGreaterThanOrEqual(1)
			expect(#perk.modifiers > 0 or perk.hook).toBe(true)
		end
	end)

	it("исключения ссылаются на существующие перки", function()
		for _, perk in Perks.List do
			for _, other in perk.excludes do
				expect(Perks.ById[other] ~= nil).toBe(true)
			end
		end
	end)
end)

Test.describe("Enemies", function(it)
	it("числовые параметры врагов корректны", function()
		for _, enemy in Enemies.List do
			expect(enemy.health).toBeGreaterThan(0)
			expect(enemy.gold.Min <= enemy.gold.Max).toBe(true)
			if enemy.behavior ~= "dummy" then
				expect(enemy.damage).toBeGreaterThan(0)
				expect(enemy.speed).toBeGreaterThan(0)
				expect(enemy.attackRange).toBeGreaterThan(0)
				expect(enemy.windup).toBeGreaterThan(0)
				expect(enemy.cost).toBeGreaterThan(0)
			end
			local elite = enemy.elite
			if elite then
				expect(elite.healthMult).toBeGreaterThanOrEqual(1)
				expect(elite.damageMult).toBeGreaterThanOrEqual(1)
				if elite.attack == "slam" then
					expect(elite.slamRadius).toBeGreaterThan(0)
				end
			end
		end
	end)

	it("элита в правилах встреч ссылается на врага с элитной версией", function()
		for _, category in Rooms.Categories do
			local rule = category.encounter
			if rule and rule.eliteEnemyId then
				local enemy = Enemies.ById[rule.eliteEnemyId]
				expect(enemy ~= nil and enemy.elite ~= nil).toBe(true)
			end
		end
	end)
end)

Test.describe("Rooms", function(it)
	local size = Config.Dungeon.RoomSize
	local half = size / 2
	local interior = half - Config.Dungeon.WallThickness
	local doorHalf = Config.Dungeon.DoorWidth / 2

	type Box = { minX: number, maxX: number, minZ: number, maxZ: number }

	local function boxOf(obstacle: any): Box
		return {
			minX = obstacle.pos.x - obstacle.size.x / 2,
			maxX = obstacle.pos.x + obstacle.size.x / 2,
			minZ = obstacle.pos.z - obstacle.size.z / 2,
			maxZ = obstacle.pos.z + obstacle.size.z / 2,
		}
	end

	local function overlaps(a: Box, b: Box): boolean
		return a.minX < b.maxX and a.maxX > b.minX and a.minZ < b.maxZ and a.maxZ > b.minZ
	end

	local function inside(box: Box, margin: number, x: number, z: number): boolean
		return x > box.minX - margin and x < box.maxX + margin and z > box.minZ - margin and z < box.maxZ + margin
	end

	-- Свободная зона перед проёмом двери: проход шириной двери (+1 с каждой стороны) на 10 стадов вглубь.
	local DOOR_ZONES: { [string]: Box } = {
		N = { minX = -doorHalf - 1, maxX = doorHalf + 1, minZ = half - 10, maxZ = half },
		S = { minX = -doorHalf - 1, maxX = doorHalf + 1, minZ = -half, maxZ = -half + 10 },
		E = { minX = half - 10, maxX = half, minZ = -doorHalf - 1, maxZ = doorHalf + 1 },
		W = { minX = -half, maxX = -half + 10, minZ = -doorHalf - 1, maxZ = doorHalf + 1 },
	}

	it("у каждой категории есть шаблон со всеми четырьмя входами (запасной вариант генератора)", function()
		for categoryId in Rooms.Categories do
			local hasFull = false
			for _, template in Rooms.ByCategory[categoryId] or {} do
				if #template.sockets == 4 then
					hasFull = true
				end
			end
			if not hasFull then
				error(`категория {categoryId}: нет шаблона с 4 входами`)
			end
		end
	end)

	it("входы шаблонов — только N/E/S/W без повторов", function()
		for _, template in Rooms.Templates do
			local seen = {}
			for _, side in template.sockets do
				expect(DOOR_ZONES[side] ~= nil).toBe(true)
				expect(seen[side]).toBeNil()
				seen[side] = true
			end
		end
	end)

	it("препятствия внутри комнаты и не перекрывают проходы к дверям", function()
		for _, template in Rooms.Templates do
			for _, obstacle in template.obstacles do
				local box = boxOf(obstacle)
				if box.minX < -interior or box.maxX > interior or box.minZ < -interior or box.maxZ > interior then
					error(`{template.id}: препятствие {obstacle.kind} выходит за стены`)
				end
				for _, side in template.sockets do
					if overlaps(box, DOOR_ZONES[side]) then
						error(`{template.id}: препятствие {obstacle.kind} перекрывает проход {side}`)
					end
				end
			end
		end
	end)

	it("точки появления и объекты внутри комнаты и не внутри препятствий", function()
		for _, template in Rooms.Templates do
			local points = {}
			for _, p in template.spawnPoints do
				table.insert(points, { kind = "spawnPoint", x = p.x, z = p.z })
			end
			for _, p in template.playerSpawns do
				table.insert(points, { kind = "playerSpawn", x = p.x, z = p.z })
			end
			for _, f in template.features do
				table.insert(points, { kind = f.kind, x = f.pos.x, z = f.pos.z })
			end
			for _, point in points do
				if math.abs(point.x) > interior - 1 or math.abs(point.z) > interior - 1 then
					error(`{template.id}: {point.kind} ({point.x}, {point.z}) у самой стены или за ней`)
				end
				for _, obstacle in template.obstacles do
					if inside(boxOf(obstacle), 1, point.x, point.z) then
						error(`{template.id}: {point.kind} ({point.x}, {point.z}) внутри препятствия {obstacle.kind}`)
					end
				end
			end
		end
	end)

	it("в комнатах со встречами есть точки появления врагов", function()
		for _, template in Rooms.Templates do
			local category = Rooms.Categories[template.category]
			if category.encounter then
				expect(#template.spawnPoints).toBeGreaterThanOrEqual(4)
			end
		end
	end)
end)

return nil
