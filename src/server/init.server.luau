--!strict
-- Точка входа сервера GOBLIT.
-- Порядок запуска:
--   1. NetServer.init — сетевые события должны существовать раньше всего остального;
--   2. init() всех сервисов по порядку — подготовка и подписки на сигналы друг друга;
--   3. start() всех сервисов — начало работы (игроки, циклы, обработка событий).
-- Ошибка одного сервиса записывается в лог и не мешает запуску остальных.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ErrorReporter = require(ReplicatedStorage.Shared.Util.ErrorReporter)
local NetServer = require(script.Net.NetServer)

type Service = {
	init: () -> (),
	start: () -> (),
}

local services: { { name: string, module: Service } } = {
	{ name = "PlayerDataService", module = require(script.Services.PlayerDataService) :: any },
	{ name = "HeroService", module = require(script.Services.HeroService) :: any },
	{ name = "SettingsService", module = require(script.Services.SettingsService) :: any },
	{ name = "HubService", module = require(script.Services.HubService) :: any },
	-- После HubService: персонажи появляются только когда Застава построена.
	{ name = "SpawnService", module = require(script.Services.SpawnService) :: any },
}

local healthy = ErrorReporter.try("Bootstrap.NetServer", NetServer.init)

for _, entry in services do
	healthy = ErrorReporter.try(`Bootstrap.init.{entry.name}`, entry.module.init) and healthy
end
for _, entry in services do
	healthy = ErrorReporter.try(`Bootstrap.start.{entry.name}`, entry.module.start) and healthy
end

if healthy then
	print(`[GOBLIT] сервер запущен, версия {Config.Version}`)
else
	warn(`[GOBLIT] сервер запущен с ошибками, версия {Config.Version} — см. сообщения выше`)
end
