--!strict
-- Масштаб интерфейса (ТЗ 31) = автоматическая подстройка под размер экрана × выбор игрока
-- в настройках (UiScale). Макеты рассчитаны на 1280×720.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

local DESIGN_SIZE = Vector2.new(1280, 720)
local MIN_AUTO_SCALE = 0.7
local MAX_AUTO_SCALE = 1.25
local SETTING_ATTR = Constants.SettingAttrPrefix .. "UiScale"

local Scale = {}

local scales: { UIScale } = {}
local cameraConnection: RBXScriptConnection? = nil
local started = false

local function currentFactor(): number
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else DESIGN_SIZE
	local auto = math.clamp(math.min(viewport.X / DESIGN_SIZE.X, viewport.Y / DESIGN_SIZE.Y), MIN_AUTO_SCALE, MAX_AUTO_SCALE)
	local userScale = Players.LocalPlayer:GetAttribute(SETTING_ATTR)
	return auto * (if type(userScale) == "number" then userScale else 1)
end

local function refresh()
	local factor = currentFactor()
	for _, uiScale in scales do
		uiScale.Scale = factor
	end
end

local function watchCamera()
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end
	local camera = Workspace.CurrentCamera
	if camera then
		cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
	end
	refresh()
end

local function ensureStarted()
	if started then
		return
	end
	started = true
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	Players.LocalPlayer:GetAttributeChangedSignal(SETTING_ATTR):Connect(refresh)
	watchCamera()
end

-- Добавляет ScreenGui общий масштаб, который обновляется при изменении экрана или настройки.
function Scale.attach(gui: ScreenGui)
	ensureStarted()
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = currentFactor()
	uiScale.Parent = gui
	table.insert(scales, uiScale)
end

return table.freeze(Scale)
