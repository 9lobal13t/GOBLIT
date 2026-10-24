--!strict
-- ИИ подвижных врагов на сервере: кого преследовать, куда идти, когда бить.
--
-- Решение о состоянии принимает чистый Logic/EnemyBrain (покрыт тестами), здесь — только
-- то, что требует мира Roblox: найти цель, передвинуть Humanoid, проверить попадание
-- и передать урон в DamageService.
--
-- ИИ тикает раз в Config.Enemies.AiTickSeconds, а не каждый кадр: при десятках врагов
-- и шести игроках это заметно дешевле, а Humanoid сам доводит движение между тиками.
--
-- Каждый враг живёт в своей зоне: у него есть дом и поводок. За целью, которая стоит
-- за поводком, враг не бежит, а уведённый слишком далеко — возвращается домой и лечится.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)
local EnemyBrain = require(ReplicatedStorage.Shared.Logic.EnemyBrain)
local ErrorReporter = require(ReplicatedStorage.Shared.Util.ErrorReporter)
local EnemyService = require(script.Parent.EnemyService)
local HeroService = require(script.Parent.HeroService)
local DamageService = require(script.Parent.DamageService)

-- Половина ширины героя: удар по краю персонажа тоже попадает.
local HERO_RADIUS = 1

type Brain = {
	enemy: EnemyService.Enemy,
	humanoid: Humanoid,
	home: Vector3,
	profile: EnemyBrain.Profile,
	state: EnemyBrain.State,
	stateSince: number,
	target: Player?,
	targetPickedAt: number,
	-- Куда направлен замах. Фиксируется в начале телеграфа: игрок видит, куда придётся удар,
	-- и может уйти из-под него.
	strikeDirection: Vector3,
}

local EnemyAiService = {}

local brains: { [EnemyService.Enemy]: Brain } = {}

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

-- Корень героя, если он жив и его можно бить.
local function aliveRoot(player: Player): BasePart?
	local hero = HeroService.get(player)
	if not hero or hero.state ~= Constants.HeroState.Alive then
		return nil
	end
	return HeroService.getRootPart(player)
end

-- Цель — ближайший живой герой в радиусе агрессии и внутри зоны врага: игрок за поводком
-- не должен заслонять того, кто стоит в зоне дальше. Выбранная цель держится
-- TargetRefreshSeconds, чтобы враг не метался между двумя игроками на каждом тике.
local function pickTarget(brain: Brain, now: number): (Player?, BasePart?)
	local current = brain.target
	if current and now - brain.targetPickedAt < Config.Enemies.TargetRefreshSeconds then
		local root = aliveRoot(current)
		if root then
			return current, root
		end
	end

	local origin = flat(brain.enemy.root.Position)
	local home = flat(brain.home)
	local bestPlayer: Player? = nil
	local bestRoot: BasePart? = nil
	local bestDistance = brain.profile.aggroRange
	for _, player in Players:GetPlayers() do
		local root = aliveRoot(player)
		if root and (flat(root.Position) - home).Magnitude <= brain.profile.leashRadius then
			local distance = (flat(root.Position) - origin).Magnitude
			if distance <= bestDistance then
				bestPlayer, bestRoot, bestDistance = player, root, distance
			end
		end
	end
	brain.target = bestPlayer
	brain.targetPickedAt = now
	return bestPlayer, bestRoot
end

local function setState(brain: Brain, state: EnemyBrain.State, now: number)
	if brain.state == state then
		return
	end
	brain.state = state
	brain.stateSince = now
	brain.enemy.model:SetAttribute(Constants.EnemyAttr.State, Constants.EnemyState[state])
end

-- Удар в конце замаха: попадает по каждому живому герою в секторе перед врагом.
local function strike(brain: Brain)
	local def = brain.enemy.def
	local origin = brain.enemy.root.Position
	for _, player in Players:GetPlayers() do
		local root = aliveRoot(player)
		if not root then
			continue
		end
		local offset = root.Position - origin
		if math.abs(offset.Y) > def.attackRange then
			continue
		end
		local horizontal = flat(offset)
		local distance = horizontal.Magnitude
		local cosToTarget = if distance > 0.01 then horizontal.Unit:Dot(brain.strikeDirection) else 1
		if EnemyBrain.strikeHits(distance, cosToTarget, def.attackRange, def.attackArcDegrees, HERO_RADIUS) then
			DamageService.enemyHitsHero(brain.enemy, player)
		end
	end
end

local function standStill(brain: Brain)
	brain.humanoid:MoveTo(brain.enemy.root.Position)
end

-- Поворачивает врага к цели и запоминает направление замаха.
local function windUp(brain: Brain, targetRoot: BasePart?)
	standStill(brain)
	brain.humanoid.AutoRotate = false
	local root = brain.enemy.root
	local toTarget = if targetRoot then flat(targetRoot.Position - root.Position) else Vector3.zero
	local direction = if toTarget.Magnitude > 0.01 then toTarget.Unit else flat(root.CFrame.LookVector).Unit
	brain.strikeDirection = direction
	root.CFrame = CFrame.lookAt(root.Position, root.Position + direction)
end

local function regenerate(brain: Brain, dt: number)
	local enemy = brain.enemy
	if enemy.health < enemy.maxHealth then
		local amount = math.max(1, math.floor(enemy.maxHealth * Config.Enemies.IdleRegenFraction * dt))
		EnemyService.heal(enemy, amount)
	end
end

local function tick(brain: Brain, now: number, dt: number)
	local enemy = brain.enemy
	local position = flat(enemy.root.Position)
	local targetPlayer, targetRoot = pickTarget(brain, now)
	local targetPosition = if targetRoot then flat(targetRoot.Position) else position

	local senses: EnemyBrain.Senses = {
		now = now,
		stateSince = brain.stateSince,
		hasTarget = targetPlayer ~= nil,
		targetDistance = (targetPosition - position).Magnitude,
		targetFromHome = (targetPosition - flat(brain.home)).Magnitude,
		homeDistance = (position - flat(brain.home)).Magnitude,
	}
	local previous: EnemyBrain.State = brain.state
	local decision = EnemyBrain.decide(previous, senses, brain.profile)
	if decision.strike then
		strike(brain)
	end
	setState(brain, decision.state, now)

	local state = decision.state
	if state == "Chase" and targetRoot then
		brain.humanoid.AutoRotate = true
		brain.humanoid:MoveTo(targetRoot.Position)
	elseif state == "Telegraph" then
		if previous ~= "Telegraph" then
			windUp(brain, targetRoot)
		end
	elseif state == "Recover" then
		standStill(brain)
	elseif state == "Return" then
		brain.humanoid.AutoRotate = true
		brain.humanoid:MoveTo(brain.home)
		regenerate(brain, dt)
	else
		brain.humanoid.AutoRotate = true
		if previous ~= "Idle" then
			standStill(brain)
		end
		regenerate(brain, dt)
	end
end

-- Включает ИИ врагу. home — точка, к которой он привязан; leashRadius — дальше этого
-- от дома он не преследует. Враги без Humanoid (манекен) не двигаются, им ИИ не нужен.
function EnemyAiService.activate(enemy: EnemyService.Enemy, home: Vector3, leashRadius: number)
	local humanoid = enemy.humanoid
	if not humanoid or enemy.dead then
		return
	end
	local def = enemy.def
	local eliteDef = def.elite
	local windup = if enemy.elite and eliteDef then eliteDef.windup else def.windup
	local brain: Brain = {
		enemy = enemy,
		humanoid = humanoid,
		home = home,
		profile = {
			aggroRange = def.aggroRange,
			attackRange = def.attackRange,
			windup = windup,
			recover = def.recover,
			leashRadius = leashRadius,
			homeTolerance = Config.Enemies.HomeTolerance,
		},
		state = "Idle",
		stateSince = os.clock(),
		target = nil,
		targetPickedAt = -math.huge,
		strikeDirection = flat(enemy.root.CFrame.LookVector).Unit,
	}
	brains[enemy] = brain
	enemy.model:SetAttribute(Constants.EnemyAttr.State, Constants.EnemyState.Idle)
end

-- Сколько живых врагов с ИИ привязано к точке home (нужно для лимита врагов в зоне).
function EnemyAiService.countAt(home: Vector3): number
	local count = 0
	for _, brain in brains do
		if brain.home == home and not brain.enemy.dead then
			count += 1
		end
	end
	return count
end

function EnemyAiService.init()
	EnemyService.Died:Connect(function(enemy)
		local brain = brains[enemy]
		if brain then
			brains[enemy] = nil
			brain.humanoid:MoveTo(enemy.root.Position)
		end
	end)
end

function EnemyAiService.start()
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(Config.Enemies.AiTickSeconds)
			local now = os.clock()
			local dt = now - last
			last = now
			for enemy, brain in brains do
				-- Модель могли удалить в обход EnemyService (например, при перезапуске зоны).
				if enemy.dead or enemy.model.Parent == nil then
					brains[enemy] = nil
					continue
				end
				ErrorReporter.try("EnemyAi.tick", tick, brain, now, dt)
			end
		end
	end)
end

return EnemyAiService
