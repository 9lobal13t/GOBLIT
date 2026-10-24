--!strict
-- Единственное место, где считается и применяется урон (ТЗ 7.4, CLAUDE.md).
-- Формулы живут в Logic/Damage, здесь — источник случайности, применение и оповещение.
--
-- Никто, кроме этого сервиса, не вызывает EnemyService.applyDamage напрямую: так
-- любое изменение правил урона (крит, броня, сопротивления, перки) делается в одном месте.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Damage = require(ReplicatedStorage.Shared.Logic.Damage)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local NetServer = require(script.Parent.Parent.Net.NetServer)
local EnemyService = require(script.Parent.EnemyService)
local HeroService = require(script.Parent.HeroService)

export type HeroStats = {
	AttackPower: number,
	CritChance: number,
	CritDamage: number,
}

local DamageService = {}

-- Случайность урона — на сервере. Поток отдельный, чтобы критические удары не сдвигали
-- генерацию подземелья и наоборот.
local rng = Random.new()

-- Урон игрока по врагу. abilityMultiplier — множитель приёма (комбо, способность).
-- Возвращает, сколько здоровья снято, и был ли крит.
function DamageService.heroHitsEnemy(
	player: Player,
	stats: HeroStats,
	enemy: EnemyService.Enemy,
	abilityMultiplier: number
): (number, boolean)
	local result = Damage.compute({
		attackPower = stats.AttackPower,
		abilityMultiplier = abilityMultiplier,
		critChance = stats.CritChance,
		critDamage = stats.CritDamage,
		armor = enemy.def.armor,
		roll = rng:NextNumber(),
	}, Config.Damage)

	if result.amount <= 0 then
		return 0, false
	end

	EnemyService.applyDamage(enemy, result.amount, player)

	local payload: Remotes.HitPayload = {
		position = enemy.root.Position,
		amount = result.amount,
		crit = result.crit,
		taken = false,
	}
	NetServer.fireClient(Remotes.Hit, player, payload)
	return result.amount, result.crit
end

-- Урон врага по герою. Враги не критуют; броня героя — из его характеристик (перки).
-- Возвращает, сколько здоровья снято.
function DamageService.enemyHitsHero(enemy: EnemyService.Enemy, player: Player): number
	local hero = HeroService.get(player)
	local root = HeroService.getRootPart(player)
	if not hero or not root then
		return 0
	end
	local eliteDef = enemy.def.elite
	local result = Damage.compute({
		attackPower = enemy.def.damage * (if enemy.elite and eliteDef then eliteDef.damageMult else 1),
		abilityMultiplier = 1,
		critChance = 0,
		critDamage = 1,
		armor = hero.stats.Armor,
		roll = rng:NextNumber(),
	}, Config.Damage)

	local dealt = HeroService.applyDamage(player, result.amount)
	if dealt <= 0 then
		return 0
	end
	local payload: Remotes.HitPayload = {
		position = root.Position,
		amount = dealt,
		crit = false,
		taken = true,
	}
	NetServer.fireClient(Remotes.Hit, player, payload)
	return dealt
end

function DamageService.init() end

function DamageService.start() end

return DamageService
