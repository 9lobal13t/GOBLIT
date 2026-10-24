--!strict
-- Награды опытом за бой.
--
-- Опыт за врага получает каждый герой, который его ранил, — целиком, а не долю и не только
-- тот, кто добил. В кооперативе добивание не должно быть гонкой, а помощь — убытком.
-- Сколько опыта и когда — решает сервер; клиент об этом только узнаёт из атрибутов.

local Players = game:GetService("Players")

local NetServer = require(script.Parent.Parent.Net.NetServer)
local EnemyService = require(script.Parent.EnemyService)
local HeroService = require(script.Parent.HeroService)

local ProgressionService = {}

-- Кто ранил врага: { [враг]: { [игрок]: true } }.
local contributors: { [EnemyService.Enemy]: { [Player]: boolean } } = {}

local function xpFor(enemy: EnemyService.Enemy): number
	local eliteDef = enemy.def.elite
	return math.floor(enemy.def.xp * (if enemy.elite and eliteDef then eliteDef.xpMult else 1))
end

local function onDamaged(enemy: EnemyService.Enemy, _amount: number, attacker: Player?)
	if not attacker or enemy.def.xp <= 0 then
		return
	end
	local set = contributors[enemy]
	if not set then
		set = {}
		contributors[enemy] = set
	end
	set[attacker] = true
end

local function onDied(enemy: EnemyService.Enemy, _killer: Player?)
	local set = contributors[enemy]
	contributors[enemy] = nil
	if not set then
		return
	end
	local amount = xpFor(enemy)
	for player in set do
		if player.Parent == Players then
			HeroService.addXp(player, amount)
		end
	end
end

function ProgressionService.init()
	EnemyService.Damaged:Connect(onDamaged)
	EnemyService.Died:Connect(onDied)
	HeroService.LeveledUp:Connect(function(hero, _gained)
		NetServer.notify(
			hero.player,
			`Новый уровень: {hero.level}. Вы стали сильнее.`,
			"success"
		)
	end)
end

function ProgressionService.start()
	Players.PlayerRemoving:Connect(function(player)
		for _, set in contributors do
			set[player] = nil
		end
	end)
end

return ProgressionService
