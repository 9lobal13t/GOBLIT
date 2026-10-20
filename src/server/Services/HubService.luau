--!strict
-- Застава: постройка хаба, освещение и тестовый интерактивный объект — маяк.
-- Маяк — общий для сервера объект: его состояние видят все игроки.
-- Взаимодействие идёт через ProximityPrompt; сервер дополнительно проверяет дистанцию
-- и ограничивает частоту, не доверяя одному лишь клиентскому срабатыванию.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local HeroService = require(script.Parent.HeroService)
local NetServer = require(script.Parent.Parent.Net.NetServer)
local HubBuilder = require(script.Parent.Parent.World.HubBuilder)
local WorldFolders = require(script.Parent.Parent.World.WorldFolders)

local BEACON_PLAYER_COOLDOWN = 1.5
local BEACON_GLOBAL_COOLDOWN = 0.5
-- Запас над MaxActivationDistance подсказки: позиция персонажа на сервере отстаёт от клиента.
local BEACON_MAX_DISTANCE = 16

local HubService = {}

local refs: HubBuilder.HubRefs? = nil
local beaconLit = true
local lastGlobalUse = -math.huge
local lastPlayerUse: { [Player]: number } = {}

local function ensureEffect(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	local effect = Instance.new(className :: any)
	effect.Name = name
	effect.Parent = Lighting
	return effect
end

-- Вечерние сумерки: тёплые огни на холодном фоне (ТЗ 3.1 — контрастное освещение).
local function configureLighting()
	Lighting.ClockTime = 18.2
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromHex("#2a2633")
	Lighting.OutdoorAmbient = Color3.fromHex("#5a5068")
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.GlobalShadows = true

	local atmosphere = ensureEffect("Atmosphere", "GoblitAtmosphere") :: Atmosphere
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromHex("#c7b8d6")
	atmosphere.Decay = Color3.fromHex("#5c4a6b")
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.4

	local grading = ensureEffect("ColorCorrectionEffect", "GoblitColorGrading") :: ColorCorrectionEffect
	grading.Contrast = 0.08
	grading.Saturation = -0.05
	grading.TintColor = Color3.fromHex("#fff4ea")

	local bloom = ensureEffect("BloomEffect", "GoblitBloom") :: BloomEffect
	bloom.Intensity = 0.6
	bloom.Size = 24
	bloom.Threshold = 1.2
end

local function applyBeaconState(beacon: HubBuilder.BeaconRefs)
	if beaconLit then
		beacon.crystal.Material = Enum.Material.Neon
		beacon.crystal.Color = Color3.fromHex("#7fe8ff")
		beacon.crystal.Transparency = 0
	else
		beacon.crystal.Material = Enum.Material.Glass
		beacon.crystal.Color = Color3.fromHex("#3d5a66")
		beacon.crystal.Transparency = 0.2
	end
	beacon.light.Enabled = beaconLit
	beacon.particles.Enabled = beaconLit
	beacon.prompt.ActionText = if beaconLit then "Погасить" else "Зажечь"
end

local function onBeaconTriggered(player: Player)
	local hubRefs = refs
	if not hubRefs then
		return
	end
	local beacon = hubRefs.beacon
	local now = os.clock()

	-- Частые нажатия — обычное поведение игрока, а не нарушение: молча игнорируем.
	if now - (lastPlayerUse[player] or -math.huge) < BEACON_PLAYER_COOLDOWN then
		return
	end
	if now - lastGlobalUse < BEACON_GLOBAL_COOLDOWN then
		return
	end
	if HeroService.distanceTo(player, beacon.crystal.Position) > BEACON_MAX_DISTANCE then
		NetServer.reject(player, "BeaconPrompt", "слишком далеко от маяка")
		return
	end

	lastPlayerUse[player] = now
	lastGlobalUse = now
	beaconLit = not beaconLit
	applyBeaconState(beacon)

	NetServer.notify(
		player,
		if beaconLit
			then "Маяк зажжён — Застава снова в свете."
			else "Маяк погас. Темнота подступает к стенам.",
		"info"
	)
end

-- Построена ли Застава (с точкой появления). Используется SpawnService.
function HubService.isBuilt(): boolean
	return refs ~= nil
end

function HubService.init()
	configureLighting()
	local hubRefs = HubBuilder.build(WorldFolders.hub())
	refs = hubRefs
	applyBeaconState(hubRefs.beacon)
end

function HubService.start()
	local hubRefs = refs
	assert(hubRefs, "Застава не построена")
	hubRefs.beacon.prompt.Triggered:Connect(onBeaconTriggered)
	Players.PlayerRemoving:Connect(function(player)
		lastPlayerUse[player] = nil
	end)
end

return HubService
