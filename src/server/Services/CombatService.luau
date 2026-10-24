--!strict
-- Бой: приём запросов на удар и проверка их на сервере (ТЗ 23.2, CLAUDE.md).
--
-- Клиент присылает только направление удара. Сервер сам решает:
--   • прошла ли перезарядка (AttackClock: с запасом на сетевую задержку, но без ускорения);
--   • жив ли герой и есть ли у него персонаж;
--   • кто попал в сектор удара: расстояние, угол и разница по высоте;
--   • сколько урона нанесено (DamageService).
-- Поэтому клиент не может ни ускорить удары, ни ударить через всю карту, ни назначить урон.
--
-- Комбо: удары подряд в пределах ComboResetSeconds усиливаются по ComboMultipliers,
-- а завершающий удар серии бьёт по более широкому сектору.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Stats = require(ReplicatedStorage.Shared.Logic.Stats)
local AttackClock = require(ReplicatedStorage.Shared.Logic.AttackClock)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local NetServer = require(script.Parent.Parent.Net.NetServer)
local HeroService = require(script.Parent.HeroService)
local EnemyService = require(script.Parent.EnemyService)
local DamageService = require(script.Parent.DamageService)

type Swing = {
	readyAt: number, -- срок следующего удара по расписанию сервера (AttackClock)
	lastAt: number, -- время прошлого принятого удара: по нему считается серия комбо
	comboStep: number,
}

local CombatService = {}

local swings: { [Player]: Swing } = {}

local function getSwing(player: Player): Swing
	local swing = swings[player]
	if not swing then
		swing = { readyAt = 0, lastAt = -math.huge, comboStep = 0 }
		swings[player] = swing
	end
	return swing
end

-- Направление удара: от клиента приходит вектор, которому нельзя доверять.
-- Годится только конечный вектор ненулевой длины; высоту отбрасываем — бьём по горизонтали.
local function readDirection(raw: unknown): Vector3?
	if typeof(raw) ~= "Vector3" then
		return nil
	end
	local vector = raw :: Vector3
	local flat = Vector3.new(vector.X, 0, vector.Z)
	local length = flat.Magnitude
	if length ~= length or length < 0.01 or length == math.huge then
		return nil
	end
	return flat / length
end

-- Враги, попавшие в сектор удара перед героем.
local function findTargets(origin: Vector3, direction: Vector3, arcDegrees: number): { EnemyService.Enemy }
	local weapon = Config.Weapon
	local cosLimit = math.cos(math.rad(arcDegrees / 2))
	local hits: { EnemyService.Enemy } = {}

	for _, enemy in EnemyService.getAll() do
		local offset = enemy.root.Position - origin
		if math.abs(offset.Y) > weapon.VerticalReach then
			continue
		end
		local flat = Vector3.new(offset.X, 0, offset.Z)
		local distance = flat.Magnitude
		-- Радиус врага добавляется к дальности: иначе по крупной цели пришлось бы
		-- целиться в её центр, хотя игрок уже стоит вплотную.
		local reach = weapon.Range + enemy.root.Size.X / 2
		if distance > reach then
			continue
		end
		if distance > 0.01 and flat.Unit:Dot(direction) < cosLimit then
			continue
		end
		table.insert(hits, enemy)
	end

	-- Ближние цели получают урон первыми: предел MaxTargets не должен отсекать
	-- того, в кого игрок целился.
	table.sort(hits, function(a, b)
		return (a.root.Position - origin).Magnitude < (b.root.Position - origin).Magnitude
	end)
	while #hits > weapon.MaxTargets do
		table.remove(hits)
	end
	return hits
end

local function onAttack(player: Player, rawDirection: unknown)
	local direction = readDirection(rawDirection)
	if not direction then
		NetServer.reject(player, Remotes.Attack.name, "некорректное направление удара")
		return
	end

	local hero = HeroService.get(player)
	if not hero or hero.state ~= Constants.HeroState.Alive then
		return
	end
	local root = HeroService.getRootPart(player)
	if not root then
		return
	end

	local interval = Stats.attackInterval(Config.Weapon.AttackInterval, hero.stats.AttackSpeed)
	local swing = getSwing(player)
	local now = os.clock()
	-- Расписание ударов ведёт AttackClock: запас на сетевую задержку остаётся, но опережение
	-- не копится, поэтому клиент не может ускорить бой постоянным спамом (находка C3/C11).
	local decision = AttackClock.decide(swing.readyAt, now, interval, Config.Weapon.TimingTolerance)
	if not decision.accepted then
		return -- не нарушение: клиент мог не успеть узнать о перезарядке
	end
	local sinceLast = now - swing.lastAt
	swing.readyAt = decision.readyAt

	local multipliers = Config.Weapon.ComboMultipliers
	local step = if sinceLast <= Config.Weapon.ComboResetSeconds then swing.comboStep % #multipliers + 1 else 1
	swing.comboStep = step
	swing.lastAt = now

	local isFinisher = step == #multipliers
	local arc = if isFinisher then Config.Weapon.FinisherArcDegrees else Config.Weapon.ArcDegrees

	for _, enemy in findTargets(root.Position, direction, arc) do
		DamageService.heroHitsEnemy(player, hero.stats, enemy, multipliers[step])
	end
end

function CombatService.init()
	NetServer.onServerEvent(Remotes.Attack, onAttack)
end

function CombatService.start()
	Players.PlayerRemoving:Connect(function(player)
		swings[player] = nil
	end)
end

return CombatService
