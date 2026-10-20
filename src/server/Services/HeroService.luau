--!strict
-- Состояние героя игрока на сервере.
--
-- Фаза 1: зона нахождения, базовые показатели из Config и настройка персонажа.
-- Здоровье и выносливость хранит сервер, а не Humanoid, и реплицирует их атрибутами
-- игрока (их читают HUD и, позже, панель группы). Урон, перки и уровни подключаются
-- в фазе 2 — см. docs/ROADMAP.md.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)
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
end

local function newHero(player: Player): Hero
	local base = Config.Hero.BaseStats
	return {
		player = player,
		zone = Constants.HubZone,
		state = Constants.HeroState.Alive,
		health = base.MaxHealth,
		maxHealth = base.MaxHealth,
		stamina = base.MaxStamina,
		maxStamina = base.MaxStamina,
		level = 1,
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

	humanoid.WalkSpeed = Config.Hero.BaseStats.MoveSpeed
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
