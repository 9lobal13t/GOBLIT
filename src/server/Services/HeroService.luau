--!strict
-- Состояние героя игрока на сервере.
--
-- Зона нахождения, характеристики героя и настройка персонажа.
-- Здоровье и выносливость хранит сервер, а не Humanoid, и реплицирует их атрибутами
-- игрока (их читают HUD и, позже, панель группы).
--
-- Характеристики (hero.stats) считает Logic/Stats из базовых значений и модификаторов.
-- Модификаторов пока нет: перки подключатся в фазе 2б, и тогда пересчёт пойдёт через
-- ту же функцию refreshStats.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Stats = require(ReplicatedStorage.Shared.Logic.Stats)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local ErrorReporter = require(ReplicatedStorage.Shared.Util.ErrorReporter)

export type Hero = {
	player: Player,
	zone: string,
	state: string,
	health: number,
	maxHealth: number,
	stamina: number,
	maxStamina: number,
	level: number,
	modifiers: { Stats.Modifier },
	stats: { [string]: number },
}

local HUMANOID_WAIT_SECONDS = 10
local Attr = Constants.PlayerAttr

local HeroService = {}

-- (hero, character) — персонаж героя появился и настроен.
HeroService.CharacterReady = Signal.new("CharacterReady") :: Signal.Signal<Hero, Model>

local heroes: { [Player]: Hero } = {}

local function replicate(hero: Hero)
	local player = hero.player
	player:SetAttribute(Attr.Zone, hero.zone)
	player:SetAttribute(Attr.HeroState, hero.state)
	player:SetAttribute(Attr.Health, hero.health)
	player:SetAttribute(Attr.MaxHealth, hero.maxHealth)
	player:SetAttribute(Attr.Stamina, hero.stamina)
	player:SetAttribute(Attr.MaxStamina, hero.maxStamina)
	player:SetAttribute(Attr.Level, hero.level)
	player:SetAttribute(Attr.AttackPower, hero.stats.AttackPower)
	player:SetAttribute(Attr.AttackInterval, Stats.attackInterval(Config.Weapon.AttackInterval, hero.stats.AttackSpeed))
	player:SetAttribute(Attr.DodgeCooldown, hero.stats.DodgeCooldown)
end

-- Пересчитывает характеристики по базе и модификаторам. Вызывается при изменении
-- набора перков и предметов. Здоровье и выносливость сохраняют свою долю от максимума,
-- чтобы перк на запас здоровья не лечил и не калечил героя.
local function refreshStats(hero: Hero)
	local healthFraction = if hero.maxHealth > 0 then hero.health / hero.maxHealth else 1
	local staminaFraction = if hero.maxStamina > 0 then hero.stamina / hero.maxStamina else 1

	hero.stats = Stats.compute(Config.Hero.BaseStats, hero.modifiers, Config.Hero.StatCaps)
	hero.maxHealth = hero.stats.MaxHealth
	hero.maxStamina = hero.stats.MaxStamina
	hero.health = math.clamp(math.floor(hero.maxHealth * healthFraction + 0.5), 1, hero.maxHealth)
	hero.stamina = math.clamp(hero.maxStamina * staminaFraction, 0, hero.maxStamina)

	local character = hero.player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = hero.stats.MoveSpeed
	end
	replicate(hero)
end

local function newHero(player: Player): Hero
	local stats = Stats.compute(Config.Hero.BaseStats, {}, Config.Hero.StatCaps)
	return {
		player = player,
		zone = Constants.HubZone,
		state = Constants.HeroState.Alive,
		health = stats.MaxHealth,
		maxHealth = stats.MaxHealth,
		stamina = stats.MaxStamina,
		maxStamina = stats.MaxStamina,
		level = 1,
		modifiers = {},
		stats = stats,
	}
end

local function setupCharacter(hero: Hero, character: Model)
	local found = character:FindFirstChildOfClass("Humanoid")
		or character:WaitForChild("Humanoid", HUMANOID_WAIT_SECONDS)
	if not found or not found:IsA("Humanoid") then
		ErrorReporter.report("Hero", `у персонажа UserId {hero.player.UserId} нет Humanoid`)
		return
	end
	local humanoid = found

	humanoid.WalkSpeed = hero.stats.MoveSpeed
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = Config.Hero.DefaultJumpHeight
	-- Стандартная полоска здоровья Roblox не отражает серверное здоровье героя.
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff

	HeroService.CharacterReady:Fire(hero, character)
end

local function onPlayerAdded(player: Player)
	if heroes[player] then
		return
	end
	local hero = newHero(player)
	heroes[player] = hero
	replicate(hero)

	player.CharacterAdded:Connect(function(character)
		setupCharacter(hero, character)
	end)
	if player.Character then
		task.spawn(setupCharacter, hero, player.Character)
	end
end

function HeroService.get(player: Player): Hero?
	return heroes[player]
end

-- Корневая часть персонажа, если персонаж существует.
function HeroService.getRootPart(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Расстояние от персонажа до точки; math.huge, если персонажа нет.
function HeroService.distanceTo(player: Player, position: Vector3): number
	local root = HeroService.getRootPart(player)
	return if root then (root.Position - position).Magnitude else math.huge
end

-- Добавляет герою модификаторы характеристик (перк, предмет) и пересчитывает их.
function HeroService.addModifiers(player: Player, modifiers: { Stats.Modifier })
	local hero = heroes[player]
	if not hero then
		return
	end
	for _, modifier in modifiers do
		table.insert(hero.modifiers, modifier)
	end
	refreshStats(hero)
end

function HeroService.init() end

function HeroService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		heroes[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return HeroService
