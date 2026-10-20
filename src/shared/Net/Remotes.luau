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

-- Куда и как сильно пришёлся удар. Клиент показывает по этому цифры урона.
export type HitPayload = {
	position: Vector3,
	amount: number,
	crit: boolean,
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

-- Attack(direction: Vector3) — намерение ударить в заданную сторону.
-- Клиент присылает только направление: куда пришёлся удар, по кому и сколько урона,
-- решает сервер. Лимит с запасом над предельной скоростью атаки (2 удара/с при потолке
-- AttackSpeed = 2 и интервале 0,42 с), остальное отсекает проверка перезарядки.
local Attack = toServer("Attack", 6, 4)

-- Сервер → клиент -------------------------------------------------------------------------

-- Notify(payload: NotifyPayload) — всплывающее уведомление.
local Notify = toClient("Notify", false)

-- Hit(payload: HitPayload) — попадание по цели: цифры урона у атаковавшего.
-- Ненадёжное событие: это украшение, и потерянный пакет не должен задерживать остальные.
local Hit = toClient("Hit", true)

-- AttackPerformed(interval: number) — сервер принял удар и начал перезарядку.
-- Клиент по этому проигрывает замах и знает, когда можно бить снова.
local AttackPerformed = toClient("AttackPerformed", false)

return table.freeze({
	UpdateSetting = UpdateSetting,
	Attack = Attack,
	Notify = Notify,
	Hit = Hit,
	AttackPerformed = AttackPerformed,

	All = table.freeze({ UpdateSetting, Attack, Notify, Hit, AttackPerformed }),
})
