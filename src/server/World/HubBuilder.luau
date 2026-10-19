--!strict
-- Постройка Заставы — безопасного хаба (ТЗ 3.3) — из примитивов.
-- Фаза 1: площадка со стенами и башнями, точка появления, арка-ориентир и маяк
-- (тестовый интерактивный объект). Торговцы, врата экспедиции и тренировочная зона
-- появятся в своих фазах; место под них оставлено свободным (см. docs/ROADMAP.md).
--
-- Система координат: верх пола на высоте FLOOR_TOP, точка появления на +Z,
-- арка на −Z. Пол приподнят на 1 стад, чтобы не мерцать со стандартным Baseplate.

local Geometry = require(script.Parent.Geometry)

export type BeaconRefs = {
	crystal: Part,
	light: PointLight,
	particles: ParticleEmitter,
	prompt: ProximityPrompt,
}

export type HubRefs = {
	spawn: SpawnLocation,
	beacon: BeaconRefs,
}

local FLOOR_TOP = 1
local HALF_SIZE = 75
local WALL_HEIGHT = 8
local WALL_THICKNESS = 3
local BARRIER_HEIGHT = 40

local Palette = {
	Foundation = Color3.fromHex("#3b3742"),
	Plaza = Color3.fromHex("#4a4452"),
	Path = Color3.fromHex("#514a5a"),
	Wall = Color3.fromHex("#5a5366"),
	Tower = Color3.fromHex("#4d4659"),
	Spawn = Color3.fromHex("#6d5f86"),
	Pedestal = Color3.fromHex("#5b5566"),
	Crate = Color3.fromHex("#6b4e35"),
	Ember = Color3.fromHex("#ff9a4d"),
	Sign = Color3.fromHex("#2b2731"),
	SignText = Color3.fromHex("#f4cf72"),
}

local function y(height: number): number
	return FLOOR_TOP + height
end

local function buildGround(parent: Folder)
	Geometry.part({
		name = "Foundation",
		size = Vector3.new(HALF_SIZE * 2, 6, HALF_SIZE * 2),
		cframe = CFrame.new(0, FLOOR_TOP - 3, 0),
		color = Palette.Foundation,
		material = Enum.Material.Slate,
		parent = parent,
	})

	local plaza = Geometry.disc("Plaza", Vector3.new(0, y(0.1), 0), 46, 0.4, parent)
	plaza.Color = Palette.Plaza
	plaza.Material = Enum.Material.Cobblestone

	Geometry.part({
		name = "Path",
		size = Vector3.new(10, 0.3, 32),
		cframe = CFrame.new(0, y(0.05), 38),
		color = Palette.Path,
		material = Enum.Material.Cobblestone,
		parent = parent,
	})
end

local function buildWalls(parent: Folder)
	local offset = HALF_SIZE - WALL_THICKNESS / 2
	local length = HALF_SIZE * 2
	local sides = {
		{ name = "WallNorth", pos = Vector3.new(0, 0, -offset), size = Vector3.new(length, 0, WALL_THICKNESS) },
		{ name = "WallSouth", pos = Vector3.new(0, 0, offset), size = Vector3.new(length, 0, WALL_THICKNESS) },
		{ name = "WallWest", pos = Vector3.new(-offset, 0, 0), size = Vector3.new(WALL_THICKNESS, 0, length) },
		{ name = "WallEast", pos = Vector3.new(offset, 0, 0), size = Vector3.new(WALL_THICKNESS, 0, length) },
	}
	for _, side in sides do
		Geometry.part({
			name = side.name,
			size = side.size + Vector3.new(0, WALL_HEIGHT, 0),
			cframe = CFrame.new(side.pos + Vector3.new(0, y(WALL_HEIGHT / 2), 0)),
			color = Palette.Wall,
			material = Enum.Material.Slate,
			parent = parent,
		})
		-- Невидимый барьер над стеной: со Заставы нельзя случайно выпасть.
		Geometry.part({
			name = side.name .. "Barrier",
			size = side.size + Vector3.new(0, BARRIER_HEIGHT, 0),
			cframe = CFrame.new(side.pos + Vector3.new(0, y(WALL_HEIGHT + BARRIER_HEIGHT / 2), 0)),
			transparency = 1,
			castShadow = false,
			parent = parent,
		})
	end
end

local function buildBrazier(parent: Instance, name: string, top: Vector3)
	local bowl = Geometry.part({
		name = name .. "Bowl",
		size = Vector3.new(4, 1, 4),
		cframe = CFrame.new(top + Vector3.new(0, 0.5, 0)),
		color = Palette.Tower,
		material = Enum.Material.CorrodedMetal,
		parent = parent,
	})
	local ember = Geometry.part({
		name = name .. "Ember",
		size = Vector3.new(2.6, 0.6, 2.6),
		cframe = CFrame.new(top + Vector3.new(0, 1.2, 0)),
		color = Palette.Ember,
		material = Enum.Material.Neon,
		canCollide = false,
		castShadow = false,
		parent = bowl,
	})
	Geometry.pointLight(ember, Palette.Ember, 24, 1.6)
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 6
	fire.Color = Palette.Ember
	fire.SecondaryColor = Color3.fromHex("#ffd27a")
	fire.Parent = ember
end

local function buildTowers(parent: Folder)
	local towerHeight = 16
	local inset = HALF_SIZE - 5
	for _, corner in { Vector3.new(-inset, 0, -inset), Vector3.new(inset, 0, -inset), Vector3.new(-inset, 0, inset), Vector3.new(inset, 0, inset) } do
		local tower = Geometry.part({
			name = "Tower",
			size = Vector3.new(10, towerHeight, 10),
			cframe = CFrame.new(corner + Vector3.new(0, y(towerHeight / 2), 0)),
			color = Palette.Tower,
			material = Enum.Material.Slate,
			parent = parent,
		})
		buildBrazier(tower, "TowerBrazier", corner + Vector3.new(0, y(towerHeight), 0))
	end
end

local function buildArch(parent: Folder)
	local z = -58
	for _, x in { -12, 12 } do
		Geometry.part({
			name = "ArchPillar",
			size = Vector3.new(6, 22, 6),
			cframe = CFrame.new(x, y(11), z),
			color = Palette.Wall,
			material = Enum.Material.Slate,
			parent = parent,
		})
	end
	Geometry.part({
		name = "ArchLintel",
		size = Vector3.new(32, 5, 7),
		cframe = CFrame.new(0, y(24.5), z),
		color = Palette.Tower,
		material = Enum.Material.Slate,
		parent = parent,
	})

	local sign = Geometry.part({
		name = "ArchSign",
		size = Vector3.new(22, 3.6, 0.6),
		cframe = CFrame.new(0, y(24.5), z + 3.8),
		color = Palette.Sign,
		material = Enum.Material.WoodPlanks,
		castShadow = false,
		parent = parent,
	})
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Back -- задняя грань детали смотрит на площадь (+Z)
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "GOBLIT"
	label.TextScaled = true
	label.TextColor3 = Palette.SignText
	label.FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold)
	label.Parent = surface
	surface.Parent = sign
end

local function buildCrates(parent: Folder)
	local crates = {
		{ pos = Vector3.new(-62, 0, 20), size = 4, turn = 12 },
		{ pos = Vector3.new(-62, 0, 25), size = 3, turn = -20 },
		{ pos = Vector3.new(60, 0, -24), size = 4, turn = 35 },
		{ pos = Vector3.new(56, 0, -22), size = 3, turn = 5 },
	}
	for _, crate in crates do
		Geometry.part({
			name = "Crate",
			size = Vector3.new(crate.size, crate.size, crate.size),
			cframe = CFrame.new(crate.pos + Vector3.new(0, y(crate.size / 2), 0)) * CFrame.Angles(0, math.rad(crate.turn), 0),
			color = Palette.Crate,
			material = Enum.Material.WoodPlanks,
			parent = parent,
		})
	end
end

local function buildSpawn(parent: Folder): SpawnLocation
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "OutpostSpawn"
	spawn.Size = Vector3.new(10, 1, 10)
	-- Игрок появляется лицом к площади.
	spawn.CFrame = CFrame.lookAt(Vector3.new(0, y(0.5), 50), Vector3.new(0, y(0.5), 0))
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.AllowTeamChangeOnTouch = false
	spawn.Duration = 0 -- без силового поля: Застава и так безопасна
	spawn.Color = Palette.Spawn
	spawn.Material = Enum.Material.Slate
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	spawn.Parent = parent
	return spawn
end

local function buildBeacon(parent: Folder): BeaconRefs
	local pedestal = Geometry.part({
		name = "BeaconPedestal",
		size = Vector3.new(6, 3, 6),
		cframe = CFrame.new(0, y(1.7), 0),
		color = Palette.Pedestal,
		material = Enum.Material.Marble,
		parent = parent,
	})

	local crystal = Geometry.part({
		name = "BeaconCrystal",
		size = Vector3.new(2.6, 2.6, 2.6),
		cframe = CFrame.new(0, y(6.2), 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		canCollide = false,
		castShadow = false,
		parent = parent,
	})

	local light = Geometry.pointLight(crystal, Color3.fromHex("#7fe8ff"), 28, 2.5)

	local particles = Instance.new("ParticleEmitter")
	particles.Rate = 6
	particles.Lifetime = NumberRange.new(1.5, 2.5)
	particles.Speed = NumberRange.new(1, 2)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.LightEmission = 1
	particles.Size = NumberSequence.new(0.35, 0)
	particles.Color = ColorSequence.new(Color3.fromHex("#9ff3ff"))
	particles.Parent = crystal

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Маяк заставы"
	prompt.ActionText = "Погасить"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = pedestal

	return { crystal = crystal, light = light, particles = particles, prompt = prompt }
end

local HubBuilder = {}

HubBuilder.FloorTop = FLOOR_TOP

-- Строит Заставу в parent. Вызывается один раз при старте сервера.
function HubBuilder.build(parent: Folder): HubRefs
	assert(#parent:GetChildren() == 0, "Застава уже построена")
	buildGround(parent)
	buildWalls(parent)
	buildTowers(parent)
	buildArch(parent)
	buildCrates(parent)
	local spawn = buildSpawn(parent)
	local beacon = buildBeacon(parent)
	return { spawn = spawn, beacon = beacon }
end

return table.freeze(HubBuilder)
