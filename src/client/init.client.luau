--!strict
-- Точка входа клиента GOBLIT.
-- Порядок как на сервере: init() всех контроллеров (создание интерфейса, подписки),
-- затем start(). Ошибка одного контроллера не мешает работе остальных.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ErrorReporter = require(ReplicatedStorage.Shared.Util.ErrorReporter)

type Controller = {
	init: () -> (),
	start: () -> (),
}

local Controllers = script.Controllers

local controllers: { { name: string, module: Controller } } = {
	{ name = "NotificationController", module = require(Controllers.NotificationController) :: any },
	{ name = "HudController", module = require(Controllers.HudController) :: any },
	{ name = "SettingsController", module = require(Controllers.SettingsController) :: any },
	{ name = "TipsController", module = require(Controllers.TipsController) :: any },
}

for _, entry in controllers do
	ErrorReporter.try(`Client.init.{entry.name}`, entry.module.init)
end
for _, entry in controllers do
	ErrorReporter.try(`Client.start.{entry.name}`, entry.module.start)
end
