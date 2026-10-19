--!strict
-- Схема постоянного профиля игрока: значения по умолчанию, миграции и проверка данных.
-- Чистый модуль без Roblox API (тестируется в Lune).
-- Сервер прогоняет через него всё, что читает из DataStore и записывает обратно;
-- клиент берёт отсюда описание настроек, чтобы построить панель настроек.

local CURRENT_VERSION = 1
local MAX_CURRENCY = 1000000000
local MAX_STAT = 1000000000

export type SettingValue = boolean | number

export type SettingSpec = {
	key: string,
	label: string,
	description: string,
	kind: "boolean" | "choice",
	default: SettingValue,
	options: { number },
	optionLabels: { string },
}

export type Stats = {
	Expeditions: number,
	Extractions: number,
	Kills: number,
	EliteKills: number,
	SecretsFound: number,
	BestLevel: number,
}

export type Profile = {
	Version: number,
	CreatedAt: number,
	Gold: number,
	RelicShards: number,
	Knowledge: number,
	Stats: Stats,
	Settings: { [string]: SettingValue },
}

export type MigrationInfo = {
	isNew: boolean,
	fromVersion: number,
	newerVersion: boolean,
	repaired: boolean,
}

-- В список попадают только настройки, которые реально на что-то влияют в текущей версии.
local SettingsSpec: { SettingSpec } = {
	{
		key = "UiScale",
		label = "Размер интерфейса",
		description = "Масштаб всех панелей поверх автоматической подстройки под экран.",
		kind = "choice",
		default = 1,
		options = { 0.85, 1, 1.15 },
		optionLabels = { "Мелкий", "Обычный", "Крупный" },
	},
	{
		key = "ShowTips",
		label = "Подсказки",
		description = "Короткие подсказки для новых игроков.",
		kind = "boolean",
		default = true,
		options = {},
		optionLabels = {},
	},
}

local settingsByKey: { [string]: SettingSpec } = {}
for _, spec in SettingsSpec do
	settingsByKey[spec.key] = spec
end

local STAT_KEYS = { "Expeditions", "Extractions", "Kills", "EliteKills", "SecretsFound", "BestLevel" }

local ProfileSchema = {}

ProfileSchema.CurrentVersion = CURRENT_VERSION
ProfileSchema.SettingsSpec = SettingsSpec
ProfileSchema.SettingsByKey = settingsByKey

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and math.abs(value) ~= math.huge
end

-- Целое неотрицательное число в пределах [0, max]; иначе fallback. Второй результат — было ли исправление.
local function sanitizeCount(value: unknown, fallback: number, max: number): (number, boolean)
	if not isFiniteNumber(value) then
		return fallback, value ~= nil
	end
	local number = value :: number
	local clamped = math.clamp(math.floor(number), 0, max)
	return clamped, clamped ~= number
end

local function defaultSettings(): { [string]: SettingValue }
	local settings: { [string]: SettingValue } = {}
	for _, spec in SettingsSpec do
		settings[spec.key] = spec.default
	end
	return settings
end

local function defaultStats(): Stats
	return {
		Expeditions = 0,
		Extractions = 0,
		Kills = 0,
		EliteKills = 0,
		SecretsFound = 0,
		BestLevel = 0,
	}
end

function ProfileSchema.default(now: number): Profile
	return {
		Version = CURRENT_VERSION,
		CreatedAt = math.floor(now),
		Gold = 0,
		RelicShards = 0,
		Knowledge = 0,
		Stats = defaultStats(),
		Settings = defaultSettings(),
	}
end

-- Проверяет значение настройки. Возвращает нормализованное значение или nil.
function ProfileSchema.validateSetting(key: string, value: unknown): SettingValue?
	local spec = settingsByKey[key]
	if not spec then
		return nil
	end
	if spec.kind == "boolean" then
		return if type(value) == "boolean" then value else nil
	end
	if not isFiniteNumber(value) then
		return nil
	end
	for _, option in spec.options do
		if math.abs(option - (value :: number)) < 1e-6 then
			return option
		end
	end
	return nil
end

function ProfileSchema.clone(profile: Profile): Profile
	local stats = table.clone(profile.Stats)
	local settings = table.clone(profile.Settings)
	local copy = table.clone(profile)
	copy.Stats = stats
	copy.Settings = settings
	return copy
end

-- Миграции между версиями схемы. Каждая получает «сырую» таблицу и возвращает таблицу
-- следующей версии. Значения проверяются потом, в sanitize.
local migrations: { [number]: ({ [string]: any }) -> { [string]: any } } = {
	-- v0 — профиль первого прототипа: { Coins = number }.
	[0] = function(raw)
		local nextRaw = table.clone(raw)
		if nextRaw.Gold == nil and nextRaw.Coins ~= nil then
			nextRaw.Gold = nextRaw.Coins
		end
		nextRaw.Coins = nil
		nextRaw.Version = 1
		return nextRaw
	end,
}

-- Приводит таблицу текущей версии к корректному профилю.
local function sanitize(raw: { [string]: any }, now: number): (Profile, boolean)
	local repaired = false
	local function count(value: unknown, fallback: number, max: number): number
		local result, changed = sanitizeCount(value, fallback, max)
		repaired = repaired or changed
		return result
	end

	local profile = ProfileSchema.default(now)
	profile.CreatedAt = count(raw.CreatedAt, profile.CreatedAt, math.huge)
	profile.Gold = count(raw.Gold, 0, MAX_CURRENCY)
	profile.RelicShards = count(raw.RelicShards, 0, MAX_CURRENCY)
	profile.Knowledge = count(raw.Knowledge, 0, MAX_CURRENCY)

	local rawStats = raw.Stats
	if type(rawStats) == "table" then
		local stats = profile.Stats :: { [string]: number }
		for _, key in STAT_KEYS do
			stats[key] = count(rawStats[key], 0, MAX_STAT)
		end
	elseif rawStats ~= nil then
		repaired = true
	end

	local rawSettings = raw.Settings
	if type(rawSettings) == "table" then
		for key, value in rawSettings do
			local valid = if type(key) == "string" then ProfileSchema.validateSetting(key, value) else nil
			if valid ~= nil then
				profile.Settings[key :: string] = valid
			else
				repaired = true -- неизвестная или испорченная настройка отбрасывается
			end
		end
	elseif rawSettings ~= nil then
		repaired = true
	end

	return profile, repaired
end

-- Принимает что угодно из DataStore и возвращает корректный профиль текущей версии.
-- Если данные записаны более новой версией игры (newerVersion), их нельзя перезаписывать:
-- вызывающий код обязан отключить сохранение, чтобы не потерять неизвестные поля.
function ProfileSchema.migrate(raw: unknown, now: number): (Profile, MigrationInfo)
	if type(raw) ~= "table" then
		return ProfileSchema.default(now),
			{ isNew = raw == nil, fromVersion = CURRENT_VERSION, newerVersion = false, repaired = raw ~= nil }
	end

	local data = raw :: { [string]: any }
	local version = if isFiniteNumber(data.Version) then math.floor(data.Version) else 0
	local info: MigrationInfo = {
		isNew = false,
		fromVersion = version,
		newerVersion = version > CURRENT_VERSION,
		repaired = false,
	}

	local current = data
	if version < 0 then
		version = 0
		info.repaired = true
	end
	while version < CURRENT_VERSION do
		local step = migrations[version]
		assert(step, "missing profile migration from version " .. tostring(version))
		current = step(current)
		version += 1
	end

	local profile, repaired = sanitize(current, now)
	info.repaired = info.repaired or repaired
	return profile, info
end

return table.freeze(ProfileSchema)
