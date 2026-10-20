--!strict
-- Всплывающие уведомления: с сервера (событие Notify) и от других контроллеров (push).
-- Новые вытесняют старые, а сколько их помещается, зависит от высоты экрана: стопка
-- начинается под названием зоны (TOP_OFFSET) и не заходит в нижнюю зону HUD (BOTTOM_RESERVED).
-- На iPhone 7 это 2 уведомления, на ПК — до MAX_VISIBLE.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local NetClient = require(ReplicatedStorage.Shared.Net.NetClient)
local Theme = require(script.Parent.Parent.UI.Theme)
local Ui = require(script.Parent.Parent.UI.Ui)
local Scale = require(script.Parent.Parent.UI.Scale)

local MAX_VISIBLE = 4
local TOP_OFFSET = 88 -- под названием зоны и плашкой сохранения HudController (12 + 28 + 6 + 30 + отступ)
local BOTTOM_RESERVED = 100 -- полоса здоровья и выносливости внизу
local TOAST_SLOT = 64 -- высота уведомления в две строки с промежутком
local MAX_TEXT_LENGTH = 240
local FADE_SECONDS = 0.25

local KIND_COLORS: { [Remotes.NotifyKind]: Color3 } = {
	info = Theme.Colors.Info,
	success = Theme.Colors.Success,
	warning = Theme.Colors.Warning,
	error = Theme.Colors.Error,
}

local NotificationController = {}

local container: Frame? = nil
local screen: ScreenGui? = nil
local visible: { CanvasGroup } = {}
local nextOrder = 0

local function maxVisible(): number
	local gui = screen
	if not gui then
		return 1
	end
	local free = Scale.virtualSize(gui).Y - TOP_OFFSET - BOTTOM_RESERVED
	return math.clamp(math.floor(free / TOAST_SLOT), 1, MAX_VISIBLE)
end

local function lifetimeFor(text: string): number
	return math.clamp(3 + #text / 40, 3, 7)
end

local function dismiss(toast: CanvasGroup)
	local index = table.find(visible, toast)
	if not index then
		return
	end
	table.remove(visible, index)
	Ui.tween(toast, FADE_SECONDS, { GroupTransparency = 1 }).Completed:Once(function()
		toast:Destroy()
	end)
end

function NotificationController.push(text: string, kind: Remotes.NotifyKind)
	local parent = container
	if not parent then
		return
	end
	local message = if #text > MAX_TEXT_LENGTH then string.sub(text, 1, MAX_TEXT_LENGTH) .. "…" else text

	while #visible >= maxVisible() do
		dismiss(visible[1])
	end

	nextOrder += 1
	local toast = Ui.new("CanvasGroup", {
		Name = "Toast",
		LayoutOrder = nextOrder,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = Theme.PanelTransparency,
		GroupTransparency = 1,
		Parent = parent,
	}, {
		Ui.corner(),
		Ui.stroke(Theme.Colors.Border, 1, 0.3),
		Ui.padding(10, 14),
		Ui.new("Frame", {
			Name = "Accent",
			Size = UDim2.new(0, 3, 1, 0),
			Position = UDim2.new(0, -8, 0, 0),
			BackgroundColor3 = KIND_COLORS[kind] or Theme.Colors.Info,
			BorderSizePixel = 0,
		}),
		Ui.label({
			Name = "Text",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = message,
			TextWrapped = true,
		}),
	}) :: CanvasGroup

	table.insert(visible, toast)
	Ui.tween(toast, FADE_SECONDS, { GroupTransparency = 0 })
	task.delay(lifetimeFor(message), dismiss, toast)
end

local function onServerNotify(payload: unknown)
	if type(payload) ~= "table" then
		return
	end
	local data = payload :: { [string]: unknown }
	local text = data.text
	local kind = data.kind
	if type(text) ~= "string" then
		return
	end
	local validKind: Remotes.NotifyKind = if kind == "success" or kind == "warning" or kind == "error"
		then kind
		else "info"
	NotificationController.push(text, validKind)
end

function NotificationController.init()
	local gui = Ui.new("ScreenGui", {
		Name = "GoblitNotifications",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	}) :: ScreenGui
	Scale.attach(gui)
	screen = gui

	container = Ui.new("Frame", {
		Name = "Stack",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, TOP_OFFSET),
		Size = UDim2.new(0, 380, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Ui.list(Enum.FillDirection.Vertical, 6, { HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	}) :: Frame
end

function NotificationController.start()
	NetClient.on(Remotes.Notify, onServerNotify)
end

return NotificationController
