--!strict
-- Панель настроек (ТЗ 31). Строится по ProfileSchema.SettingsSpec, поэтому новая
-- настройка добавляется в одном месте — в схеме профиля.
--
-- Показывается только значение, подтверждённое сервером (атрибут Setting_<ключ>).
-- После нажатия вариант помечается «ожидает»; если сервер не ответил за PENDING_TIMEOUT,
-- отметка снимается и снова видно настоящее значение.
--
-- Раскладка рассчитана на телефоны (docs/reports/phase1-studio-check.md, проблемы 3 и 4):
-- все кнопки не ниже Theme.TouchTarget, список настроек прокручивается, если не помещается
-- по высоте, а цвет вариантов задаётся только кодом (AutoButtonColor выключен, иначе
-- встроенная подсветка Roblox спорит с нашей раскраской).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local ProfileSchema = require(ReplicatedStorage.Shared.Logic.ProfileSchema)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local NetClient = require(ReplicatedStorage.Shared.Net.NetClient)
local Theme = require(script.Parent.Parent.UI.Theme)
local Ui = require(script.Parent.Parent.UI.Ui)
local Scale = require(script.Parent.Parent.UI.Scale)

type SettingValue = ProfileSchema.SettingValue
type SettingSpec = ProfileSchema.SettingSpec

local PENDING_TIMEOUT = 3
-- Не чаще, чем позволяет серверный лимит UpdateSetting (2 в секунду).
local MIN_SEND_INTERVAL = 0.5

local PANEL_WIDTH = 440
local PANEL_PADDING = 16
local PANEL_SPACING = 12
local SCREEN_MARGIN = 12
local MIN_BODY_HEIGHT = 120

local SettingsController = {}

local player = Players.LocalPlayer
local panel: Frame? = nil
local firstControl: GuiObject? = nil
local pending: { [string]: { value: SettingValue, token: number } } = {}
local renderers: { [string]: () -> () } = {}
local lastSendAt = -math.huge
local pendingToken = 0

local function attrName(key: string): string
	return Constants.SettingAttrPrefix .. key
end

local function confirmedValue(spec: SettingSpec): SettingValue
	local value = player:GetAttribute(attrName(spec.key))
	if type(value) == "boolean" or type(value) == "number" then
		return value
	end
	return spec.default
end

local function isReady(): boolean
	return player:GetAttribute(Constants.PlayerAttr.DataReady) == true
end

local function requestChange(spec: SettingSpec, value: SettingValue)
	if not isReady() then
		return
	end
	if confirmedValue(spec) == value and not pending[spec.key] then
		return
	end
	local now = os.clock()
	if now - lastSendAt < MIN_SEND_INTERVAL then
		return
	end
	lastSendAt = now

	pendingToken += 1
	local token = pendingToken
	pending[spec.key] = { value = value, token = token }
	renderers[spec.key]()
	NetClient.send(Remotes.UpdateSetting, spec.key, value)

	task.delay(PENDING_TIMEOUT, function()
		local entry = pending[spec.key]
		if entry and entry.token == token then
			pending[spec.key] = nil
			renderers[spec.key]()
		end
	end)
end

local function styleOption(button: TextButton, selected: boolean, waiting: boolean)
	button.BackgroundColor3 = if selected then Theme.Colors.AccentDim else Theme.Colors.Control
	button.TextColor3 = if selected then Theme.Colors.Text else Theme.Colors.TextDim
	button.TextTransparency = if waiting then 0.5 else 0
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = if selected then Theme.Colors.Accent else Theme.Colors.Border
	end
end

local function optionButton(text: string, order: number, onActivated: () -> ()): TextButton
	local button = Ui.button({
		Name = "Option",
		LayoutOrder = order,
		Size = UDim2.fromOffset(0, Theme.TouchTarget),
		AutomaticSize = Enum.AutomaticSize.X,
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Colors.Control,
		Text = text,
		TextSize = Theme.TextSize.Small,
	})
	Ui.padding(0, 14).Parent = button
	Ui.stroke(Theme.Colors.Border, 1, 0).Parent = button
	button.Activated:Connect(onActivated)
	if not firstControl then
		firstControl = button
	end
	return button
end

local function buildRow(parent: Instance, spec: SettingSpec, order: number)
	local row = Ui.new("Frame", {
		Name = spec.key,
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = parent,
	}, {
		Ui.list(Enum.FillDirection.Vertical, 4),
		Ui.label({
			Name = "Title",
			LayoutOrder = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			FontFace = Theme.Fonts.Bold,
			TextWrapped = true,
			Text = spec.label,
		}),
		Ui.label({
			Name = "Description",
			LayoutOrder = 2,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Colors.TextDim,
			TextWrapped = true,
			Text = spec.description,
		}),
	}) :: Frame

	local controls = Ui.new("Frame", {
		Name = "Controls",
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, Theme.TouchTarget),
		BackgroundTransparency = 1,
		Parent = row,
	}, { Ui.list(Enum.FillDirection.Horizontal, 8) }) :: Frame

	local choices: { { button: TextButton, value: SettingValue } } = {}
	if spec.kind == "boolean" then
		table.insert(choices, {
			value = true,
			button = optionButton("Вкл", 1, function()
				requestChange(spec, true)
			end),
		})
		table.insert(choices, {
			value = false,
			button = optionButton("Выкл", 2, function()
				requestChange(spec, false)
			end),
		})
	else
		for index, option in spec.options do
			table.insert(choices, {
				value = option,
				button = optionButton(spec.optionLabels[index] or tostring(option), index, function()
					requestChange(spec, option)
				end),
			})
		end
	end
	for _, choice in choices do
		choice.button.Parent = controls
	end

	local function render()
		local entry = pending[spec.key]
		local shown = if entry then entry.value else confirmedValue(spec)
		for _, choice in choices do
			styleOption(choice.button, choice.value == shown, entry ~= nil)
		end
	end
	renderers[spec.key] = render

	player:GetAttributeChangedSignal(attrName(spec.key)):Connect(function()
		pending[spec.key] = nil
		render()
	end)
	render()
end

local function setOpen(open: boolean)
	local frame = panel
	if not frame then
		return
	end
	frame.Visible = open
	if not UserInputService.GamepadEnabled then
		return
	end
	-- С геймпадом фокус переходит в панель и возвращается обратно при закрытии.
	GuiService.SelectedObject = if open then firstControl else nil
end

local function buildPanel(gui: ScreenGui): Frame
	local frame = Ui.new("Frame", {
		Name = "SettingsPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(PANEL_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.04,
		Visible = false,
		Parent = gui,
	}, {
		Ui.corner(12),
		Ui.stroke(Theme.Colors.Border, 1, 0),
		Ui.padding(PANEL_PADDING, 20),
		Ui.list(Enum.FillDirection.Vertical, PANEL_SPACING),
	}) :: Frame

	local header = Ui.new("Frame", {
		Name = "Header",
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, Theme.TouchTarget),
		BackgroundTransparency = 1,
		Parent = frame,
	}) :: Frame
	Ui.label({
		Size = UDim2.new(1, -Theme.TouchTarget - 8, 1, 0),
		FontFace = Theme.Fonts.Heavy,
		TextSize = Theme.TextSize.Title,
		Text = "Настройки",
		Parent = header,
	})
	local close = Ui.button({
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(Theme.TouchTarget, Theme.TouchTarget),
		Text = "×",
		TextSize = Theme.TextSize.Title,
		Parent = header,
	})
	close.Activated:Connect(function()
		setOpen(false)
	end)

	local body = Ui.new("ScrollingFrame", {
		Name = "Body",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, MIN_BODY_HEIGHT),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		-- Область прокрутки задаётся в fitBody: AutomaticCanvasSize ошибается под UIScale.
		AutomaticCanvasSize = Enum.AutomaticSize.None,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Colors.Border,
		Parent = frame,
	}) :: ScrollingFrame
	local bodyLayout = Ui.list(Enum.FillDirection.Vertical, 18) :: UIListLayout
	bodyLayout.Parent = body

	local waiting = Ui.label({
		Name = "Loading",
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 20),
		TextColor3 = Theme.Colors.TextDim,
		TextSize = Theme.TextSize.Small,
		Text = "Загрузка профиля…",
		Parent = body,
	})
	local function refreshReady()
		waiting.Visible = not isReady()
	end
	player:GetAttributeChangedSignal(Constants.PlayerAttr.DataReady):Connect(refreshReady)
	refreshReady()

	for index, spec in ProfileSchema.SettingsSpec do
		buildRow(body, spec, index)
	end

	-- Высота списка = его содержимое, но не больше свободного места на экране.
	-- Всё считается в единицах макета: AbsoluteContentSize уже умножен на масштаб.
	-- Область прокрутки тоже задаётся здесь, а не через AutomaticCanvasSize: под UIScale
	-- он считает её неверно, и нижние кнопки становятся недоступны (docs/PITFALLS.md).
	local function fitBody()
		local factor = Scale.factor()
		local content = bodyLayout.AbsoluteContentSize.Y / factor
		local screen = Scale.virtualSize(gui).Y
		local available = screen - SCREEN_MARGIN * 2 - PANEL_PADDING * 2 - Theme.TouchTarget - PANEL_SPACING
		local height = math.min(content, math.max(available, MIN_BODY_HEIGHT))
		body.Size = UDim2.new(1, 0, 0, math.ceil(height))
		body.CanvasSize = UDim2.fromOffset(0, math.ceil(content))
	end
	bodyLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fitBody)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitBody)
	Scale.Changed:Connect(function()
		fitBody()
	end)
	fitBody()

	return frame
end

function SettingsController.init()
	local gui = Ui.new("ScreenGui", {
		Name = "GoblitSettings",
		ResetOnSpawn = false,
		DisplayOrder = 10,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	}) :: ScreenGui
	Scale.attach(gui)

	local button = Ui.button({
		Name = "OpenSettings",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 12),
		Size = UDim2.fromOffset(0, Theme.TouchTarget),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = Theme.PanelTransparency,
		Text = "Настройки",
		TextSize = Theme.TextSize.Small,
		Parent = gui,
	})
	Ui.padding(0, 14).Parent = button

	panel = buildPanel(gui)
	button.Activated:Connect(function()
		local frame = panel
		setOpen(frame ~= nil and not frame.Visible)
	end)
end

function SettingsController.start() end

return SettingsController
