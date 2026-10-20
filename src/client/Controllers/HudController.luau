--!strict
-- Основной HUD (ТЗ 20.1). Фаза 1: здоровье, выносливость, уровень, текущая зона,
-- валюты профиля и предупреждение об отключённом сохранении.
-- Все значения берутся из атрибутов игрока, которые выставляет сервер; HUD ничего
-- не считает сам и не может показать то, чего нет на сервере.
--
-- Раскладка обходит стандартные элементы Roblox:
--   • левый верхний угол свободен — там на ПК открывается окно чата;
--   • сверху по центру — название зоны (показывается при входе и исчезает) и плашка
--     сохранения, под ними уведомления;
--   • слева посередине — валюты; справа сверху — кнопка настроек (SettingsController);
--   • внизу по центру — здоровье и выносливость; при сенсорном вводе панель сужается,
--     чтобы не заходить на джойстик и кнопку прыжка.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Theme = require(script.Parent.Parent.UI.Theme)
local Ui = require(script.Parent.Parent.UI.Ui)
local Scale = require(script.Parent.Parent.UI.Scale)

local Attr = Constants.PlayerAttr
local BAR_TWEEN_SECONDS = 0.15
local CORE_GUI_RETRIES = 10

-- Название зоны держится на экране столько и уходит: постоянно висеть ему незачем,
-- а над входом в подземелье оно перекрывало надпись на арке (проверка R22).
local ZONE_HOLD_SECONDS = 4
local ZONE_FADE_SECONDS = 0.6

local VITALS_WIDTH = 420
local VITALS_MIN_WIDTH = 240
local VITALS_HEIGHT = 60
-- Кнопка прыжка на маленьком экране стоит в 95 точках от правого края (PlayerModule,
-- TouchJump: Position (1, -95)), а кольцо джойстика слева уходит внутрь ещё на 8 точек
-- дальше — это измерено в Studio (проверка R10, замечание 3). Берём дальнюю границу и зазор.
local TOUCH_CONTROLS_INSET = 103
local TOUCH_CONTROLS_GAP = 12

local ZONE_NAMES: { [string]: string } = {
	[Constants.HubZone] = "Застава",
}

local HudController = {}

local player = Players.LocalPlayer

local function numberAttr(name: string, fallback: number): number
	local value = player:GetAttribute(name)
	return if type(value) == "number" then value else fallback
end

local function onAttributes(names: { string }, callback: () -> ())
	for _, name in names do
		player:GetAttributeChangedSignal(name):Connect(callback)
	end
	callback()
end

-- Стандартная полоса здоровья Roblox показывает Humanoid.Health, а здоровье героя считает
-- сервер, поэтому её отключаем. CoreGui может быть ещё не готов — повторяем несколько раз.
local function disableCoreHealthBar()
	task.spawn(function()
		for _ = 1, CORE_GUI_RETRIES do
			local ok = pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Health, false)
			if ok then
				return
			end
			task.wait(0.5)
		end
	end)
end

type Bar = {
	frame: Frame,
	fill: Frame,
	label: TextLabel?,
}

local function createBar(name: string, height: number, fillColor: Color3, backColor: Color3, withLabel: boolean): Bar
	local frame = Ui.new("Frame", {
		Name = name,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = backColor,
		BorderSizePixel = 0,
	}, { Ui.corner(height // 2) }) :: Frame

	local fill = Ui.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = fillColor,
		BorderSizePixel = 0,
		Parent = frame,
	}, { Ui.corner(height // 2) }) :: Frame

	local label: TextLabel? = nil
	if withLabel then
		label = Ui.label({
			Name = "Value",
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			FontFace = Theme.Fonts.Bold,
			TextSize = Theme.TextSize.Small,
			ZIndex = 2,
			Parent = frame,
		})
	end
	return { frame = frame, fill = fill, label = label }
end

local function setBar(bar: Bar, current: number, max: number)
	local ratio = if max > 0 then math.clamp(current / max, 0, 1) else 0
	Ui.tween(bar.fill, BAR_TWEEN_SECONDS, { Size = UDim2.fromScale(ratio, 1) })
	local label = bar.label
	if label then
		label.Text = `{Ui.formatInt(current)} / {Ui.formatInt(max)}`
	end
end

local function buildVitals(gui: ScreenGui)
	local panel = Ui.new("Frame", {
		Name = "Vitals",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(VITALS_WIDTH, VITALS_HEIGHT),
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = Theme.PanelTransparency,
		Parent = gui,
	}, { Ui.corner(), Ui.stroke(Theme.Colors.Border, 1, 0.3), Ui.padding(8, 10) }) :: Frame

	-- При сенсорном вводе панель не шире промежутка между джойстиком и кнопкой прыжка.
	-- Их отступ задан в реальных точках экрана, поэтому переводим его в единицы макета.
	local function fitWidth()
		local width = VITALS_WIDTH
		if Scale.isTouch() then
			local reserve = (TOUCH_CONTROLS_INSET + TOUCH_CONTROLS_GAP) / Scale.factor()
			width = math.clamp(Scale.virtualSize(gui).X - reserve * 2, VITALS_MIN_WIDTH, VITALS_WIDTH)
		end
		panel.Size = UDim2.fromOffset(math.floor(width), VITALS_HEIGHT)
	end
	Scale.Changed:Connect(function()
		fitWidth()
	end)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitWidth)
	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(fitWidth)
	fitWidth()

	local levelBadge = Ui.new("Frame", {
		Name = "Level",
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = Theme.Colors.AccentDim,
		Parent = panel,
	}, { Ui.corner(22), Ui.stroke(Theme.Colors.Accent, 2, 0) }) :: Frame
	local levelLabel = Ui.label({
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.Fonts.Heavy,
		TextSize = Theme.TextSize.Title,
		Parent = levelBadge,
	})

	local bars = Ui.new("Frame", {
		Name = "Bars",
		Position = UDim2.fromOffset(54, 0),
		Size = UDim2.new(1, -54, 1, 0),
		BackgroundTransparency = 1,
		Parent = panel,
	}, {
		Ui.list(Enum.FillDirection.Vertical, 6, { VerticalAlignment = Enum.VerticalAlignment.Center }),
	}) :: Frame

	local health = createBar("Health", 22, Theme.Colors.Health, Theme.Colors.HealthBack, true)
	health.frame.LayoutOrder = 1
	health.frame.Parent = bars
	local stamina = createBar("Stamina", 8, Theme.Colors.Stamina, Theme.Colors.StaminaBack, false)
	stamina.frame.LayoutOrder = 2
	stamina.frame.Parent = bars

	onAttributes({ Attr.Health, Attr.MaxHealth }, function()
		setBar(health, numberAttr(Attr.Health, 0), numberAttr(Attr.MaxHealth, 1))
	end)
	onAttributes({ Attr.Stamina, Attr.MaxStamina }, function()
		setBar(stamina, numberAttr(Attr.Stamina, 0), numberAttr(Attr.MaxStamina, 1))
	end)
	onAttributes({ Attr.Level }, function()
		levelLabel.Text = tostring(numberAttr(Attr.Level, 1))
	end)
end

local function currencyChip(parent: Instance, order: number, color: Color3, attrName: string, tooltip: string)
	local chip = Ui.new("Frame", {
		Name = attrName,
		LayoutOrder = order,
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = Theme.PanelTransparency,
		Parent = parent,
	}, {
		Ui.corner(15),
		Ui.padding(0, 10),
		Ui.list(Enum.FillDirection.Horizontal, 6, { VerticalAlignment = Enum.VerticalAlignment.Center }),
		Ui.new("Frame", {
			Name = "Icon",
			LayoutOrder = 1,
			Size = UDim2.fromOffset(12, 12),
			BackgroundColor3 = color,
			Rotation = 45,
		}, { Ui.corner(3) }),
	}) :: Frame

	local value = Ui.label({
		Name = "Value",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = Theme.Fonts.Bold,
		TextColor3 = color,
		Parent = chip,
	})
	Ui.label({
		Name = "Caption",
		LayoutOrder = 3,
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Colors.TextDim,
		Text = tooltip,
		Parent = chip,
	})

	onAttributes({ attrName }, function()
		value.Text = Ui.formatInt(numberAttr(attrName, 0))
	end)
end

local function buildZone(gui: ScreenGui)
	local zoneLabel = Ui.label({
		Name = "Zone",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.Fonts.Heavy,
		TextSize = Theme.TextSize.Title,
		TextStrokeTransparency = 0.6,
		TextTransparency = 1,
		Parent = gui,
	})

	-- Номер показа: пока ждём, игрок может перейти в другую зону, и прошлый показ
	-- не должен гасить новое название.
	local shownAt = 0
	onAttributes({ Attr.Zone }, function()
		local zone = player:GetAttribute(Attr.Zone)
		local name = if type(zone) == "string" then ZONE_NAMES[zone] or "Подземелье" else ""
		if name == "" then
			zoneLabel.TextTransparency = 1
			return
		end

		shownAt += 1
		local token = shownAt
		zoneLabel.Text = name
		Ui.tween(zoneLabel, ZONE_FADE_SECONDS / 2, { TextTransparency = 0, TextStrokeTransparency = 0.6 })
		task.delay(ZONE_HOLD_SECONDS, function()
			if token == shownAt and zoneLabel.Parent then
				Ui.tween(zoneLabel, ZONE_FADE_SECONDS, { TextTransparency = 1, TextStrokeTransparency = 1 })
			end
		end)
	end)
end

local function buildCurrencies(gui: ScreenGui)
	local column = Ui.new("Frame", {
		Name = "Currencies",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Ui.list(Enum.FillDirection.Vertical, 6) }) :: Frame

	-- На мыши валюты стоят слева посередине: верхний левый угол занимает окно чата.
	-- На сенсорном экране чат свёрнут, зато слева снизу джойстик, и посередине плашки
	-- заходили на его кольцо (проверка R10, замечание 2) — поэтому уводим их вверх.
	local function placeColumn()
		if Scale.isTouch() then
			column.AnchorPoint = Vector2.new(0, 0)
			column.Position = UDim2.fromOffset(16, 12)
		else
			column.AnchorPoint = Vector2.new(0, 0.5)
			column.Position = UDim2.new(0, 16, 0.5, 0)
		end
	end
	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(placeColumn)
	placeColumn()

	currencyChip(column, 1, Theme.Colors.Gold, Attr.Gold, "золото")
	currencyChip(column, 2, Theme.Colors.Shards, Attr.RelicShards, "осколки")
	currencyChip(column, 3, Theme.Colors.Knowledge, Attr.Knowledge, "знания")

	-- Пока профиль не загружен, валюты неизвестны — не показываем нули как настоящие значения.
	onAttributes({ Attr.DataReady }, function()
		column.Visible = player:GetAttribute(Attr.DataReady) == true
	end)
end

local function buildSaveWarning(gui: ScreenGui)
	local pill = Ui.new("Frame", {
		Name = "SaveWarning",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 46), -- под названием зоны (12 + 28 + 6)
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Colors.HealthBack,
		Visible = false,
		Parent = gui,
	}, {
		Ui.corner(15),
		Ui.padding(0, 14),
		Ui.stroke(Theme.Colors.Error, 1, 0.2),
		Ui.label({
			Size = UDim2.fromOffset(0, 30),
			AutomaticSize = Enum.AutomaticSize.X,
			FontFace = Theme.Fonts.Bold,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Colors.Error,
			-- Коротко: длинная строка на телефоне налезала бы на соседние панели.
			-- Подробности игрок получает уведомлением при входе.
			Text = "Сохранение отключено",
		}),
	}) :: Frame

	onAttributes({ Attr.SaveDisabled }, function()
		pill.Visible = player:GetAttribute(Attr.SaveDisabled) == true
	end)
end

function HudController.init()
	disableCoreHealthBar()

	local gui = Ui.new("ScreenGui", {
		Name = "GoblitHud",
		ResetOnSpawn = false,
		DisplayOrder = 1,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	}) :: ScreenGui
	Scale.attach(gui)

	buildVitals(gui)
	buildZone(gui)
	buildCurrencies(gui)
	buildSaveWarning(gui)
end

function HudController.start() end

return HudController
