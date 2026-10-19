--!strict
-- Реестр всех удалённых событий (ТЗ 23.3). Единственный источник имён: сервер создаёт
-- события по этому списку, клиент находит их по нему же.
--
-- Для каждого события ниже указан формат аргументов. Проверка аргументов выполняется
-- в серверном обработчике; лимит частоты применяет NetServer до вызова обработчика.
-- Универсального события «выполни команду» нет и не будет.

export type Direction = "ToServer" | "ToClient"

export type RateLimit = {
	burst: number, -- сколько запросов подряд можно отправить
	perSecond: number, -- скорость восстановления запросов
}

export type RemoteDef = {
	name: string,
	direction: Direction,
	unreliable: boolean,
	rateLimit: RateLimit?,
}

export type NotifyKind = "info" | "success" | "warning" | "error"

export type NotifyPayload = {
	text: string,
	kind: NotifyKind,
}

local function toServer(name: string, burst: number, perSecond: number): RemoteDef
	return table.freeze({
		name = name,
		direction = "ToServer" :: Direction,
		unreliable = false,
		rateLimit = table.freeze({ burst = burst, perSecond = perSecond }),
	})
end

local function toClient(name: string, unreliable: boolean): RemoteDef
	return table.freeze({
		name = name,
		direction = "ToClient" :: Direction,
		unreliable = unreliable,
		rateLimit = nil,
	})
end

-- Клиент → сервер -------------------------------------------------------------------------

-- UpdateSetting(key: string (≤ 32 символов), value: boolean | number)
-- Изменение настройки профиля. Ключ и значение проверяются по ProfileSchema.SettingsSpec.
local UpdateSetting = toServer("UpdateSetting", 5, 2)

-- Сервер → клиент -------------------------------------------------------------------------

-- Notify(payload: NotifyPayload) — всплывающее уведомление.
local Notify = toClient("Notify", false)

return table.freeze({
	UpdateSetting = UpdateSetting,
	Notify = Notify,

	All = table.freeze({ UpdateSetting, Notify }),
})
