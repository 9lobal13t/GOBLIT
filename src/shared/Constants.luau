--!strict
-- Строковые идентификаторы, общие для сервера и клиента.
-- Все имена атрибутов, тегов и состояний берутся отсюда, а не пишутся строками по коду.

local Constants = table.freeze({
	HubZone = "hub",

	-- Настройка профиля реплицируется своему игроку как атрибут "<префикс><ключ>".
	SettingAttrPrefix = "Setting_",

	Folders = table.freeze({
		Net = "GoblitNet",
		World = "World",
		Entities = "Entities",
		Effects = "Effects",
	}),

	Tags = table.freeze({
		Enemy = "GoblitEnemy",
	}),

	HeroState = table.freeze({
		Alive = "Alive",
		Downed = "Downed",
		Dead = "Dead",
	}),

	EnemyState = table.freeze({
		Idle = "Idle",
		Chase = "Chase",
		Telegraph = "Telegraph",
		Recover = "Recover",
		Return = "Return",
		Dead = "Dead",
	}),

	-- Атрибуты на объекте Player (реплицируются всем клиентам: нужны для HUD и панели группы).
	PlayerAttr = table.freeze({
		Health = "Health",
		MaxHealth = "MaxHealth",
		Stamina = "Stamina",
		MaxStamina = "MaxStamina",
		Level = "Level",
		Xp = "Xp",
		XpToNext = "XpToNext",
		HeroState = "HeroState",
		Zone = "Zone",
		DownedUntil = "DownedUntil",
		AttackInterval = "AttackInterval",
		DodgeCooldown = "DodgeCooldown",
		RunGold = "RunGold",
		RunShards = "RunShards",
		Gold = "Gold",
		RelicShards = "RelicShards",
		Knowledge = "Knowledge",
		DataReady = "DataReady",
		SaveDisabled = "SaveDisabled",
	}),

	-- Атрибуты на модели врага.
	EnemyAttr = table.freeze({
		DefId = "EnemyDefId",
		DisplayName = "EnemyName",
		Health = "Health",
		MaxHealth = "MaxHealth",
		State = "EnemyState",
		Elite = "Elite",
	}),
})

return Constants
