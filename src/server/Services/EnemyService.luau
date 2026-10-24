--!strict
-- Враги на сервере: создание, здоровье, смерть.
--
-- Здоровье хранит сервер и реплицирует атрибутами модели (их читает полоска здоровья
-- на клиенте). Клиент не может ни создать врага, ни изменить его здоровье.
--
-- Здесь только тело врага: появление, здоровье, смерть. Поведение подвижных врагов
-- (преследование, замах, удар) ведёт EnemyAiService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Enemies = require(ReplicatedStorage.Shared.Definitions.Enemies)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local ErrorReporter = require(ReplicatedStorage.Shared.Util.ErrorReporter)
local EnemyBuilder = require(script.Parent.Parent.World.EnemyBuilder)

local Attr = Constants.EnemyAttr

export type Enemy = {
	id: number,
	def: Enemies.EnemyDef,
	elite: boolean,
	model: Model,
	root: BasePart,
	humanoid: Humanoid?, -- только у подвижных врагов
	health: number,
	maxHealth: number,
	dead: boolean,
}

local EnemyService = {}

-- (enemy, killer) — враг погиб. killer — кто нанёс последний удар, если это был игрок.
EnemyService.Died = Signal.new("EnemyDied") :: Signal.Signal<Enemy, Player?>
-- (enemy, amount, attacker) — врагу нанесён урон.
EnemyService.Damaged = Signal.new("EnemyDamaged") :: Signal.Signal<Enemy, number, Player?>

local byRoot: { [BasePart]: Enemy } = {}
local all: { [number]: Enemy } = {}
local nextId = 0

local function replicate(enemy: Enemy)
	enemy.model:SetAttribute(Attr.Health, enemy.health)
	enemy.model:SetAttribute(Attr.MaxHealth, enemy.maxHealth)
end

-- Создаёт врага и ставит его ногами на уровень footY.
function EnemyService.spawn(defId: string, elite: boolean, position: Vector3, footY: number, parent: Instance): Enemy?
	local def = Enemies.ById[defId]
	if not def then
		ErrorReporter.report("Enemy", `неизвестный враг {defId}`)
		return nil
	end

	local eliteDef = def.elite
	local isElite = elite and eliteDef ~= nil
	local maxHealth = math.floor(def.health * (if isElite and eliteDef then eliteDef.healthMult else 1))

	local built = EnemyBuilder.build(def, isElite, footY, position)
	nextId += 1
	local enemy: Enemy = {
		id = nextId,
		def = def,
		elite = isElite,
		model = built.model,
		root = built.root,
		humanoid = built.humanoid,
		health = maxHealth,
		maxHealth = maxHealth,
		dead = false,
	}

	byRoot[built.root] = enemy
	all[enemy.id] = enemy
	replicate(enemy)
	built.model.Parent = parent
	if not built.root.Anchored then
		-- Физикой врага управляет только сервер. Иначе Roblox отдал бы её ближайшему игроку,
		-- и его клиент мог бы двигать врага куда угодно.
		built.root:SetNetworkOwner(nil)
	end
	return enemy
end

-- Враг по детали, в которую попали (попадание ищется по корпусу).
function EnemyService.fromPart(part: BasePart): Enemy?
	local direct = byRoot[part]
	if direct then
		return direct
	end
	-- Голова и «глаз» приварены к корпусу: попадание по ним считается попаданием по врагу.
	local model = part:FindFirstAncestorOfClass("Model")
	local primary = model and model.PrimaryPart
	return if primary then byRoot[primary] else nil
end

function EnemyService.getAll(): { Enemy }
	local list: { Enemy } = {}
	for _, enemy in all do
		if not enemy.dead then
			table.insert(list, enemy)
		end
	end
	return list
end

local function removeAfterDelay(enemy: Enemy)
	task.delay(Config.Enemies.CorpseSeconds, function()
		byRoot[enemy.root] = nil
		all[enemy.id] = nil
		enemy.model:Destroy()
	end)
end

-- Наносит врагу урон. Возвращает, сколько здоровья реально снято (0, если враг уже мёртв).
-- Урон считает DamageService; здесь только применение и смерть.
function EnemyService.applyDamage(enemy: Enemy, amount: number, attacker: Player?): number
	if enemy.dead or amount <= 0 then
		return 0
	end

	-- Бессмертная цель (тренировочный манекен) принимает удары, но не умирает:
	-- по нему удобно проверять урон и не нужно ждать возрождения.
	local dealt = if enemy.def.immortal then math.min(amount, enemy.health - 1) else math.min(amount, enemy.health)
	if dealt <= 0 then
		-- Манекен уже на единице здоровья: показываем удар, но здоровье не трогаем.
		EnemyService.Damaged:Fire(enemy, amount, attacker)
		return 0
	end

	enemy.health -= dealt
	replicate(enemy)
	EnemyService.Damaged:Fire(enemy, amount, attacker)

	if enemy.health <= 0 then
		enemy.dead = true
		-- Тело замирает на месте до исчезновения.
		enemy.root.Anchored = true
		enemy.model:SetAttribute(Attr.State, Constants.EnemyState.Dead)
		EnemyService.Died:Fire(enemy, attacker)
		removeAfterDelay(enemy)
	end
	return dealt
end

-- Восстанавливает здоровье цели (используется манекеном между подходами).
function EnemyService.heal(enemy: Enemy, amount: number)
	if enemy.dead or amount <= 0 then
		return
	end
	enemy.health = math.min(enemy.maxHealth, enemy.health + amount)
	replicate(enemy)
end

function EnemyService.init() end

function EnemyService.start() end

return EnemyService
