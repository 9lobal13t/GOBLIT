--!strict
-- Все настраиваемые параметры игры в одном месте.
-- Только данные: без Roblox API, поэтому модуль загружается и в игре, и в Lune-тестах.
-- Числа здесь — стартовая гипотеза баланса, см. docs/BALANCE.md.

local function deepFreeze<T>(value: T): T
	if type(value) == "table" and not table.isfrozen(value :: any) then
		for _, child in value :: any do
			deepFreeze(child)
		end
		table.freeze(value :: any)
	end
	return value
end

local Config = {
	Version = "0.1.0",

	Hero = {
		-- Базовые характеристики героя в начале экспедиции.
		BaseStats = {
			MaxHealth = 100,
			MaxStamina = 100,
			AttackPower = 10,
			CritChance = 0.05,
			CritDamage = 1.5,
			AttackSpeed = 1,
			MoveSpeed = 16,
			Armor = 0,
			DodgeCooldown = 0.7,
			LifeOnKill = 0, -- доля MaxHealth, восстанавливаемая за убийство
			GoldFind = 1, -- множитель получаемого золота
			ChestAmbushChance = 0, -- шанс засады при открытии сундука
		},
		-- Жёсткие пределы, чтобы комбинации перков не ломали игру (ТЗ 9.6).
		StatCaps = {
			MaxHealth = { Min = 1, Max = 2000 },
			MaxStamina = { Min = 10, Max = 400 },
			AttackPower = { Min = 1, Max = 5000 },
			CritChance = { Min = 0, Max = 0.75 },
			CritDamage = { Min = 1, Max = 4 },
			AttackSpeed = { Min = 0.5, Max = 2 },
			MoveSpeed = { Min = 8, Max = 28 },
			Armor = { Min = 0, Max = 60 },
			DodgeCooldown = { Min = 0.25, Max = 5 },
			LifeOnKill = { Min = 0, Max = 0.15 },
			GoldFind = { Min = 0, Max = 3 },
			ChestAmbushChance = { Min = 0, Max = 0.6 },
		},
		StaminaRegenPerSecond = 28,
		StaminaRegenDelay = 0.6,
		DodgeStaminaCost = 25,
		DodgeInvulnerability = 0.3,
		DodgeSpeed = 62,
		DodgeDuration = 0.18,
		DefaultJumpHeight = 7.2,

		DownedWalkSpeed = 4,
		BleedOutSeconds = 25,
		ReviveHoldSeconds = 2.5,
		ReviveDistance = 9,
		ReviveHealthFraction = 0.4,
		ReviveInvulnerability = 1.5,
		RespawnDelaySeconds = 6,
		RespawnHealthFraction = 0.5,
		DeathGoldPenalty = 0.25, -- доля незакреплённого золота, теряемая при смерти
		SoloSelfRevives = 1,
		SoloSelfReviveDelay = 4,
	},

	Progression = {
		MaxLevel = 20,
		XpCurve = { Base = 20, Exponent = 1.5 },
		-- Прибавка за каждый уровень после первого. Остальное дают перки.
		PerLevel = { MaxHealth = 6, AttackPower = 0.5 },
		LevelUpHealFraction = 0.2,
	},

	Weapon = {
		-- Одноручный клинок — единственное оружие первой версии.
		AttackInterval = 0.42,
		ComboResetSeconds = 0.9,
		ComboMultipliers = { 1, 1.1, 1.6 },
		Range = 7.5,
		ArcDegrees = 110,
		FinisherArcDegrees = 160,
		MaxTargets = 5,
		VerticalReach = 6,
		-- Насколько раньше расчётного времени сервер принимает удар (сетевой джиттер).
		TimingTolerance = 0.2,
	},

	Damage = {
		ArmorScale = 5, -- множитель брони: 100 / (100 + Armor * ArmorScale)
		MaxDamage = 1000000,
	},

	Perks = {
		OfferSize = 3,
		RarityWeights = {
			Common = 55,
			Uncommon = 28,
			Rare = 12,
			Epic = 4.5,
			Legendary = 0.5,
			Mythic = 0,
		},
		AltarRarityWeights = {
			Common = 10,
			Uncommon = 30,
			Rare = 35,
			Epic = 20,
			Legendary = 5,
			Mythic = 0,
		},
		AltarHealthCost = 0.25,
	},

	Dungeon = {
		CellPitch = 80, -- шаг сетки: комната + коридор
		RoomSize = 64,
		WallHeight = 18,
		WallThickness = 2,
		DoorWidth = 12,
		DoorHeight = 12,

		MinRooms = 12,
		MaxRooms = 20,
		MainPathFraction = 0.55,
		MinExitDepth = 5,
		MaxTreasureRooms = 2,
		LoopEdgeChance = 0.35,
		MaxLoopEdges = 2,
		GenerationAttempts = 24,

		RunSlotSpacing = 4000,
		RunSlotOffsetZ = 4000,
		MaxConcurrentRuns = 8,
		PresenceTickSeconds = 0.25,
		EncounterSpawnDelay = 0.8,
		DoorInteractDistance = 14,
		WipeGraceSeconds = 2,

		DiscoveryXp = 6,

		-- Debug Generation (ТЗ 5.6). Работает только в Studio, в live-сервере игнорируется.
		Debug = {
			ForcedSeed = nil :: number?,
			ForcedRoomCount = nil :: number?,
			ForceCategories = nil :: { string }?,
		},
	},

	Enemies = {
		AiTickSeconds = 0.15,
		MaxPerZone = 32,
		LeashMargin = 4,
		TargetRefreshSeconds = 1,
		IdleRegenFraction = 0.15, -- доля MaxHealth в секунду, пока враг без цели
		CorpseSeconds = 1.2,
		StuckCheckSeconds = 1.5,
		-- Масштабирование под размер группы (ТЗ 4.2: соло — адаптированная сложность).
		PartyHealthScalePerPlayer = 0.4,
		PartyBudgetPerPlayer = 0.6,
		MaxPerRoom = 9,
	},

	Loot = {
		ChestGold = { Min = 14, Max = 26 },
		DepthGoldScale = 0.15,
		ChestShardChance = 0.15,
		SecretGold = { Min = 40, Max = 60 },
		SecretShards = 1,
		EliteChestGold = { Min = 30, Max = 45 },
		ExitClearGold = 25,
		AmbushSize = 2,
	},

	Banking = {
		-- Правила сохранения добычи (ТЗ 17.3). Отображаются в интерфейсе результатов.
		ExtractGoldFraction = 1,
		ExtractShardFraction = 1,
		FailGoldFraction = 0.5,
		FailShardFraction = 0,
		KnowledgePerRoom = 1,
		KnowledgePerElite = 2,
		KnowledgePerSecret = 3,
		KnowledgeForExtraction = 5,
	},

	Lobby = {
		PadSize = { X = 22, Z = 22 },
		CountdownSeconds = 8,
		MinSecondsAfterJoin = 3,
		MaxPartySize = 6,
		TickSeconds = 0.5,
	},

	Data = {
		StoreName = "GOBLIT_Profiles_v1",
		AutosaveSeconds = 60,
		LockTtlSeconds = 180,
		LoadAttempts = 4,
		RetryDelaySeconds = 3,
		SaveAttempts = 3,
	},
}

return deepFreeze(Config)
