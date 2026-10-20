--!strict
-- Масштаб интерфейса (ТЗ 31) = автоматическая подстройка под экран × выбор игрока (UiScale).
-- Макеты рассчитаны на 1280×720.
--
-- Ограничения выведены из проверки на iPhone 7 (docs/reports/phase1-studio-check.md):
--   • при сенсорном вводе интерфейс не уменьшается ниже макета — на телефоне и так мало места,
--     а уменьшение до 0,7 давало текст в 9 точек;
--   • итоговый множитель не ниже MIN_FACTOR: мелкий текст темы (14) не меньше ~11 точек.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local DESIGN_SIZE = Vector2.new(1280, 720)
local MIN_AUTO_TOUCH = 1
local MIN_AUTO_POINTER = 0.85
local MAX_AUTO = 1.25
local MIN_FACTOR = 0.8
local SETTING_ATTR = Constants.SettingAttrPrefix .. "UiScale"

local Scale = {}

-- (factor) — масштаб изменился (экран, способ ввода или настройка игрока).
Scale.Changed = Signal.new("ScaleChanged") :: Signal.Signal<number>

local scales: { UIScale } = {}
local cameraConnection: RBXScriptConnection? = nil
local started = false
local current = 1

local function computeFactor(): number
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else DESIGN_SIZE
	local touch = UserInputService.PreferredInput == Enum.PreferredInput.Touch
	local minAuto = if touch then MIN_AUTO_TOUCH else MIN_AUTO_POINTER
	local auto = math.clamp(math.min(viewport.X / DESIGN_SIZE.X, viewport.Y / DESIGN_SIZE.Y), minAuto, MAX_AUTO)
	local userScale = Players.LocalPlayer:GetAttribute(SETTING_ATTR)
	local factor = auto * (if type(userScale) == "number" then userScale else 1)
	return math.max(factor, MIN_FACTOR)
end

local function refresh()
	local factor = computeFactor()
	if factor == current then
		return
	end
	current = factor
	for _, uiScale in scales do
		uiScale.Scale = factor
	end
	Scale.Changed:Fire(factor)
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
	current = computeFactor()
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(refresh)
	Players.LocalPlayer:GetAttributeChangedSignal(SETTING_ATTR):Connect(refresh)
	watchCamera()
end

-- Добавляет ScreenGui общий масштаб, который обновляется при изменении экрана, ввода или настройки.
function Scale.attach(gui: ScreenGui)
	ensureStarted()
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = current
	uiScale.Parent = gui
	table.insert(scales, uiScale)
end

function Scale.factor(): number
	ensureStarted()
	return current
end

-- Размер области ScreenGui в единицах макета (до масштабирования).
-- AbsoluteSize самого ScreenGui масштаб не учитывает, поэтому делим на множитель.
function Scale.virtualSize(gui: ScreenGui): Vector2
	return gui.AbsoluteSize / Scale.factor()
end

return table.freeze(Scale)
