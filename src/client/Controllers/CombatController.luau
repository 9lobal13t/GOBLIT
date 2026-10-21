--!strict
-- Ввод боя: клик мыши или экранная кнопка на телефоне — запрос на удар.
--
-- Клиент присылает серверу только направление. Куда пришёлся удар, по кому и сколько
-- урона — решает сервер (CLAUDE.md: «клиент просит — сервер решает»).
--
-- Перезарядку клиент тоже считает у себя, но лишь затем, чтобы не слать лишние запросы.
-- Настоящая перезарядка — на сервере, он присылает остаток в AttackPerformed.
--
-- Удар можно держать: пока кнопка или клавиша нажата, запросы идут с частотой перезарядки
-- и не чаще (ждём ровно до следующего разрешённого удара).
--
-- Кнопку для сенсорного экрана рисуем сами, а не через ContextActionService: его кнопка
-- встаёт в правый нижний угол ровно под штатную кнопку прыжка и полностью ею перекрывается,
-- так что на телефоне ударить было нельзя (проверка C9 от 21.10.2026).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local NetClient = require(ReplicatedStorage.Shared.Net.NetClient)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Theme = require(script.Parent.Parent.UI.Theme)
local Ui = require(script.Parent.Parent.UI.Ui)
local Scale = require(script.Parent.Parent.UI.Scale)

local ACTION_NAME = "GoblitAttack"
local FALLBACK_INTERVAL = 0.5
-- Как часто проверять, не прошла ли перезарядка, пока кнопка нажата. Обычно ждём ровно
-- остаток перезарядки; этот предел снизу нужен, чтобы цикл не крутился впустую.
local HOLD_POLL_SECONDS = 0.05

-- Кнопка удара на сенсорном экране. 72 точки — заметно больше пальцевого минимума
-- Theme.TouchTarget (44): кнопка нажимается в бою, не глядя.
local BUTTON_SIZE = 72
local BUTTON_RIGHT_INSET = 22
local BUTTON_GAP = 14
-- Запасное расстояние от нижнего края экрана до верха кнопки прыжка, если саму кнопку
-- найти не удалось. Измерено в Studio на iPhone 7 (667×375): штатная кнопка прыжка
-- занимает квадрат 70×70 в 79 точках от низа (проверка C9).
local JUMP_RESERVE_FALLBACK = 79 + 70

local CombatController = {}

-- Срабатывает, когда игрок отправил удар: HudController по этому показывает отклик.
CombatController.Swung = Signal.new("Swung") :: Signal.Signal<>

local player = Players.LocalPlayer
local nextAttackAt = 0
local holding = false

local function attackInterval(): number
	local value = player:GetAttribute(Constants.PlayerAttr.AttackInterval)
	return if type(value) == "number" and value > 0 then value else FALLBACK_INTERVAL
end

-- Куда бьём: по направлению взгляда камеры, спроецированному на землю.
-- Так удар идёт туда, куда смотрит игрок, а не туда, куда довернулся персонаж.
local function aimDirection(): Vector3?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then
		return nil
	end
	return flat.Unit
end

local function requestAttack()
	local now = os.clock()
	if now < nextAttackAt then
		return
	end
	if player:GetAttribute(Constants.PlayerAttr.HeroState) ~= Constants.HeroState.Alive then
		return
	end
	local direction = aimDirection()
	if not direction then
		return
	end

	-- Предполагаемая перезарядка, чтобы не слать запросы впустую. Точную пришлёт сервер.
	nextAttackAt = now + attackInterval()
	NetClient.send(Remotes.Attack, direction)
	CombatController.Swung:Fire()
end

-- Сколько секунд осталось до следующего удара (0, если можно бить).
function CombatController.cooldownLeft(): number
	return math.max(0, nextAttackAt - os.clock())
end

local function stopHolding()
	holding = false
end

local function startHolding()
	if holding then
		return
	end
	holding = true
	task.spawn(function()
		while holding do
			requestAttack()
			task.wait(math.max(CombatController.cooldownLeft(), HOLD_POLL_SECONDS))
		end
	end)
end

local function onAction(_name: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		startHolding()
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		stopHolding()
	end
	return Enum.ContextActionResult.Pass
end

-- Где стоит штатная кнопка прыжка. Её размер и место зависят от размера экрана
-- (на больших экранах PlayerModule делает её крупнее), поэтому читаем настоящие значения,
-- а на запасной вариант опираемся только пока кнопки нет.
local function findJumpButton(): GuiObject?
	local playerGui = player:FindFirstChild("PlayerGui")
	local touchGui = if playerGui then playerGui:FindFirstChild("TouchGui") else nil
	local jump = if touchGui then touchGui:FindFirstChild("JumpButton", true) else nil
	return if jump and jump:IsA("GuiObject") then jump else nil
end

-- Кнопка удара ставится НАД кнопкой прыжка. При перекрытии касание достаётся прыжку,
-- и ударить на телефоне невозможно, поэтому зазор обязателен.
local function placeButton(button: TextButton, gui: ScreenGui)
	local factor = Scale.factor()
	local reserve = JUMP_RESERVE_FALLBACK
	local jump = findJumpButton()
	if jump and factor > 0 then
		-- AbsolutePosition и AbsoluteSize — в пикселях экрана, а размеры кнопки заданы
		-- в единицах макета, поэтому расстояние переводим делением на масштаб.
		local guiBottom = gui.AbsolutePosition.Y + gui.AbsoluteSize.Y
		local distance = (guiBottom - jump.AbsolutePosition.Y) / factor
		local limit = Scale.virtualSize(gui).Y / 2
		-- Нелепое значение (кнопка ещё не разложена или уехала за экран) не должно
		-- увести кнопку удара в пустоту — тогда остаётся измеренный запас.
		if distance > 0 and distance < limit then
			reserve = distance
		end
	end
	button.Position = UDim2.new(1, -BUTTON_RIGHT_INSET, 1, -math.floor(reserve + BUTTON_GAP))
end

local function buildTouchButton(gui: ScreenGui)
	local button = Ui.button({
		Name = "Attack",
		AnchorPoint = Vector2.new(1, 1),
		Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE),
		BackgroundColor3 = Theme.Colors.AccentDim,
		BackgroundTransparency = 0.15,
		FontFace = Theme.Fonts.Bold,
		TextSize = Theme.TextSize.Body,
		Text = "Удар",
		Visible = false,
		Parent = gui,
	})
	Ui.stroke(Theme.Colors.Accent, 2, 0.2).Parent = button

	local function refresh()
		button.Visible = Scale.isTouch()
		if button.Visible then
			placeButton(button, gui)
		end
	end

	-- Нажатие берём с самой кнопки, а отпускание — ещё и глобально: если палец уехал
	-- с кнопки, InputEnded на ней может не прийти, и удары продолжались бы сами.
	button.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			startHolding()
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			stopHolding()
		end
	end)

	Scale.Changed:Connect(refresh)
	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(refresh)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh)
	-- Штатные кнопки управления создаются после входа в игру, иногда позже нашего интерфейса.
	local playerGui = player:WaitForChild("PlayerGui")
	playerGui.DescendantAdded:Connect(function(descendant: Instance)
		if descendant.Name == "JumpButton" then
			refresh()
		end
	end)
	refresh()
end

function CombatController.init()
	-- false: свою кнопку для касаний рисуем сами (см. заголовок файла).
	ContextActionService:BindAction(ACTION_NAME, onAction, false, Enum.UserInputType.MouseButton1)

	local gui = Ui.new("ScreenGui", {
		Name = "GoblitCombat",
		ResetOnSpawn = false,
		DisplayOrder = 2,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	}) :: ScreenGui
	Scale.attach(gui)
	buildTouchButton(gui)
end

function CombatController.start()
	NetClient.on(Remotes.AttackPerformed, function(cooldown: unknown)
		if type(cooldown) == "number" and cooldown >= 0 then
			nextAttackAt = os.clock() + cooldown
		end
	end)
end

return CombatController
