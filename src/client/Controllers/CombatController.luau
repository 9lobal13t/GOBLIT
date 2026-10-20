--!strict
-- Ввод боя: клик мыши или экранная кнопка на телефоне — запрос на удар.
--
-- Клиент присылает серверу только направление. Куда пришёлся удар, по кому и сколько
-- урона — решает сервер (CLAUDE.md: «клиент просит — сервер решает»).
--
-- Перезарядку клиент тоже считает у себя, но лишь затем, чтобы не слать лишние запросы.
-- Настоящая перезарядка — на сервере, он присылает её в AttackPerformed.
--
-- Кнопку для сенсорного экрана делает сам ContextActionService: так она появляется
-- только на устройствах с касаниями и не перехватывает обычные касания по экрану,
-- которыми игрок крутит камеру.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local NetClient = require(ReplicatedStorage.Shared.Net.NetClient)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local ACTION_NAME = "GoblitAttack"
local FALLBACK_INTERVAL = 0.5

local CombatController = {}

-- Срабатывает, когда игрок отправил удар: HudController по этому показывает отклик.
CombatController.Swung = Signal.new("Swung") :: Signal.Signal<>

local player = Players.LocalPlayer
local nextAttackAt = 0

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

local function onAction(_name: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		requestAttack()
	end
	return Enum.ContextActionResult.Pass
end

function CombatController.init()
	-- true: на сенсорном экране ContextActionService сам рисует кнопку удара.
	ContextActionService:BindAction(ACTION_NAME, onAction, true, Enum.UserInputType.MouseButton1)
	ContextActionService:SetTitle(ACTION_NAME, "Удар")
	ContextActionService:SetPosition(ACTION_NAME, UDim2.new(1, -150, 1, -140))
end

function CombatController.start()
	NetClient.on(Remotes.AttackPerformed, function(interval: unknown)
		if type(interval) == "number" and interval > 0 then
			nextAttackAt = os.clock() + interval
		end
	end)
end

-- Сколько секунд осталось до следующего удара (0, если можно бить).
function CombatController.cooldownLeft(): number
	return math.max(0, nextAttackAt - os.clock())
end

return CombatController
