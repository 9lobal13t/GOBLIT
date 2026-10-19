--!strict
-- Редкости перков и предметов. Цвета — hex-строки, чтобы модуль не зависел от Roblox API.

export type RarityId = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"

export type Rarity = {
	id: RarityId,
	order: number,
	displayName: string,
	color: string,
}

local list: { Rarity } = {
	{ id = "Common", order = 1, displayName = "Обычный", color = "#b8b8b8" },
	{ id = "Uncommon", order = 2, displayName = "Необычный", color = "#5fd35f" },
	{ id = "Rare", order = 3, displayName = "Редкий", color = "#4aa3ff" },
	{ id = "Epic", order = 4, displayName = "Эпический", color = "#b46bff" },
	{ id = "Legendary", order = 5, displayName = "Легендарный", color = "#ffb340" },
	{ id = "Mythic", order = 6, displayName = "Мифический", color = "#ff4d6d" },
}

local byId: { [string]: Rarity } = {}
for _, rarity in list do
	byId[rarity.id] = table.freeze(rarity)
end

return table.freeze({
	List = table.freeze(list),
	ById = table.freeze(byId),
})
