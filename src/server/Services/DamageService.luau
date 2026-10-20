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
	}
	NetServer.fireClient(Remotes.Hit, player, payload)
	return result.amount, result.crit
end

function DamageService.init() end

function DamageService.start() end

return DamageService
