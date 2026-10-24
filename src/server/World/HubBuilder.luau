--!strict
-- Постройка Заставы — безопасного хаба (ТЗ 3.3) — из примитивов.
-- Фаза 1: площадка со стенами и башнями, точка появления, арка-ориентир и маяк
-- (тестовый интерактивный объект). Торговцы, врата экспедиции и тренировочная зона
-- появятся в своих фазах; место под них оставлено свободным (см. docs/ROADMAP.md).
--
-- Система координат: верх пола на высоте FLOOR_TOP, точка появления на +Z,
-- арка на −Z. Пол приподнят на 1 стад, чтобы не мерцать со стандартным Baseplate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Geometry = require(script.Parent.Geometry)

export type BeaconRefs = {
	crystal: Part,
	light: PointLight,
	particles: ParticleEmitter,
	prompt: ProximityPrompt,
}

-- Загон, где можно выпустить Шелуху из клетки.
export type ArenaRefs = {
	center: Vector3, -- центр на уровне пола: дом выпущенных врагов
	release: Vector3, -- где враг появляется, выйдя из клетки
	cage: BasePart, -- крыша клетки: на ней подсказка, от неё сервер меряет расстояние
	prompt: ProximityPrompt,
}

export type HubRefs = {
	spawn: SpawnLocation,
	beacon: BeaconRefs,
	trainingGround: Vector3, -- центр площадки для тренировочного манекена
	arena: ArenaRefs,
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
	for _, corner in
		{
			Vector3.new(-inset, 0, -inset),
			Vector3.new(inset, 0, -inset),
			Vector3.new(-inset, 0, inset),
			Vector3.new(inset, 0, inset),
		}
	do
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
		size = Vector3.new(32, 7, 7),
		cframe = CFrame.new(0, y(25.5), z),
		color = Palette.Tower,
		material = Enum.Material.Slate,
		parent = parent,
	})

	-- Надпись видна через всю площадь, поэтому буквы должны быть крупными: на телефоне
	-- с места появления они занимали около 6 пикселей в высоту (проверка R22).
	local sign = Geometry.part({
		name = "ArchSign",
		size = Vector3.new(28, 5.4, 0.6),
		cframe = CFrame.new(0, y(25.5), z + 3.8),
		color = Palette.Sign,
		material = Enum.Material.WoodPlanks,
		castShadow = false,
		parent = parent,
	})
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Back -- задняя грань детали смотрит на площадь (+Z)
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	-- 20, а не 40. Размер шрифта в Roblox не бывает больше 100, поэтому высота букв в мире
	-- равна 100 / PixelsPerStud стадов: при 40 это потолок в 2,5 стада, и увеличение самой
	-- таблички только добавляло пустое поле вокруг букв (проверка R25). При 20 потолок — 5
	-- стадов, то есть буквы ровно по высоте таблички (5,4), а чёткости 100 пикселей хватает.
	surface.PixelsPerStud = 20
	surface.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "GOBLIT"
	label.TextScaled = true
	label.TextColor3 = Palette.SignText
	-- Та же причина, что и в теме клиента: надпись латиницей, но шрифт держим один на всю игру.
	label.FontFace = Font.new(Font.fromEnum(Enum.Font.Roboto).Family, Enum.FontWeight.Heavy)
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
			cframe = CFrame.new(crate.pos + Vector3.new(0, y(crate.size / 2), 0))
				* CFrame.Angles(0, math.rad(crate.turn), 0),
			color = Palette.Crate,
			material = Enum.Material.WoodPlanks,
			parent = parent,
		})
	end
end

-- Тренировочная площадка (ТЗ 3.3): место, где можно бить манекен, не мешая другим.
-- Стоит сбоку от площади, чтобы бой не загораживал путь к маяку и к вратам.
local TRAINING_CENTER = Vector3.new(38, 0, 18)
local TRAINING_POST_HEIGHT = 5
local TRAINING_POST_OFFSETS = {
	Vector3.new(-11, 0, -11),
	Vector3.new(11, 0, -11),
	Vector3.new(-11, 0, 11),
	Vector3.new(11, 0, 11),
}

local function buildTrainingGround(parent: Folder)
	local floor =
		Geometry.disc("TrainingFloor", Vector3.new(TRAINING_CENTER.X, y(0.1), TRAINING_CENTER.Z), 26, 0.4, parent)
	floor.Color = Palette.Path
	floor.Material = Enum.Material.Ground

	for _, offset in TRAINING_POST_OFFSETS do
		Geometry.part({
			name = "TrainingPost",
			size = Vector3.new(1.2, TRAINING_POST_HEIGHT, 1.2),
			cframe = CFrame.new(TRAINING_CENTER + offset + Vector3.new(0, y(TRAINING_POST_HEIGHT / 2), 0)),
			color = Palette.Crate,
			material = Enum.Material.WoodPlanks,
			parent = parent,
		})
		-- На двух ближних к площади столбах — огонь. Застава освещена как вечер, и с места
		-- появления площадка была неразличимым тёмным силуэтом: новичок, которому сказано
		-- «подойди к манекену», её просто не находил (проверка C1 от 21.10.2026).
		if offset.Z > 0 then
			buildBrazier(
				parent,
				"TrainingBrazier",
				TRAINING_CENTER + offset + Vector3.new(0, y(TRAINING_POST_HEIGHT), 0)
			)
		end
	end
end

local ARENA_CENTER = Vector3.new(40, 0, -30)
local ARENA_FENCE_POSTS = 12
local ARENA_FENCE_HEIGHT = 2.5
local CAGE_SIZE = Vector3.new(6, 5, 4)

-- Клетка из прутьев. Она стоит на краю загона дверью к центру.
local function buildCage(parent: Folder, base: Vector3, facing: Vector3): (BasePart, ProximityPrompt)
	local frame = CFrame.lookAt(base, base + facing)
	local roof = Geometry.part({
		name = "CageRoof",
		size = Vector3.new(CAGE_SIZE.X, 0.4, CAGE_SIZE.Z),
		cframe = frame * CFrame.new(0, y(CAGE_SIZE.Y), 0),
		color = Palette.Tower,
		material = Enum.Material.CorrodedMetal,
		parent = parent,
	})
	local barCount = 6
	for side = -1, 1, 2 do
		for i = 0, barCount - 1 do
			local x = -CAGE_SIZE.X / 2 + 0.3 + i * (CAGE_SIZE.X - 0.6) / (barCount - 1)
			Geometry.part({
				name = "CageBar",
				size = Vector3.new(0.25, CAGE_SIZE.Y, 0.25),
				cframe = frame * CFrame.new(x, y(CAGE_SIZE.Y / 2), side * CAGE_SIZE.Z / 2),
				color = Palette.Tower,
				material = Enum.Material.CorrodedMetal,
				parent = parent,
			})
		end
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Клетка с шелухой"
	prompt.ActionText = "Выпустить"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = roof
	return roof, prompt
end

local function buildArena(parent: Folder): ArenaRefs
	local radius = Config.Training.ArenaRadius
	local floor =
		Geometry.disc("ArenaFloor", Vector3.new(ARENA_CENTER.X, y(0.1), ARENA_CENTER.Z), radius * 2, 0.4, parent)
	floor.Color = Palette.Path
	floor.Material = Enum.Material.Ground

	-- Низкие столбы по кругу: граница загона видна, а войти и выйти можно где угодно.
	for i = 0, ARENA_FENCE_POSTS - 1 do
		local angle = i / ARENA_FENCE_POSTS * math.pi * 2
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (radius + 0.6)
		Geometry.part({
			name = "ArenaPost",
			size = Vector3.new(0.9, ARENA_FENCE_HEIGHT, 0.9),
			cframe = CFrame.new(ARENA_CENTER + offset + Vector3.new(0, y(ARENA_FENCE_HEIGHT / 2), 0)),
			color = Palette.Crate,
			material = Enum.Material.WoodPlanks,
			parent = parent,
		})
	end

	-- Клетка у дальнего от площади края, огни — по бокам от неё: загон виден в темноте.
	local cageBase = ARENA_CENTER + Vector3.new(0, 0, -(radius - CAGE_SIZE.Z / 2 - 1))
	local cage, prompt = buildCage(parent, cageBase, Vector3.new(0, 0, 1))
	for _, side in { -1, 1 } do
		local post = cageBase + Vector3.new(side * (CAGE_SIZE.X / 2 + 2), 0, 0)
		Geometry.part({
			name = "ArenaLightPost",
			size = Vector3.new(1.2, TRAINING_POST_HEIGHT, 1.2),
			cframe = CFrame.new(post + Vector3.new(0, y(TRAINING_POST_HEIGHT / 2), 0)),
			color = Palette.Crate,
			material = Enum.Material.WoodPlanks,
			parent = parent,
		})
		buildBrazier(parent, "ArenaBrazier", post + Vector3.new(0, y(TRAINING_POST_HEIGHT), 0))
	end

	return {
		center = Vector3.new(ARENA_CENTER.X, y(0.3), ARENA_CENTER.Z),
		release = cageBase + Vector3.new(0, y(0.3), CAGE_SIZE.Z / 2 + 2.5),
		cage = cage,
		prompt = prompt,
	}
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
	buildTrainingGround(parent)
	local arena = buildArena(parent)
	local spawn = buildSpawn(parent)
	local beacon = buildBeacon(parent)
	return {
		spawn = spawn,
		beacon = beacon,
		trainingGround = Vector3.new(TRAINING_CENTER.X, y(0), TRAINING_CENTER.Z),
		arena = arena,
	}
end

return table.freeze(HubBuilder)
