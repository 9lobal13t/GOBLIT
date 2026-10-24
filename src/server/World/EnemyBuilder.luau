--!strict
-- Сборка модели врага из примитивов по его описанию в Definitions/Enemies.
-- Временная замена до Blender-пайплайна (фаза 8): важны узнаваемый силуэт, размер
-- и точка, по которой считается попадание, — а не детализация.
--
-- Силуэт собирается так, чтобы врага было видно в бою (ТЗ 10.1): корпус, голова и
-- акцентный «глаз» цветом врага.
--
-- Подвижный враг ходит с помощью Humanoid: он сам держит фигуру вертикально, шагает
-- на ступени и не проходит сквозь стены, а клиенты видят движение плавным. Humanoid нужна
-- деталь HumanoidRootPart, которая висит над полом на HipHeight, — иначе нижняя грань
-- корпуса упирается в любой порожек (в Studio враг застревал на бортике площадки в 0,4 стада).
-- Поэтому корень невидимый, а видимый корпус приварен к нему и стоит на полу.
-- Стандартные полоска здоровья и имя Humanoid выключены: здоровье врага хранит сервер
-- в атрибутах, его показывает CombatFeedbackController.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Enemies = require(ReplicatedStorage.Shared.Definitions.Enemies)
local Geometry = require(script.Parent.Geometry)

local Attr = Constants.EnemyAttr

export type EnemyModel = {
	model: Model,
	root: BasePart,
	humanoid: Humanoid?, -- только у подвижных врагов
}

local EnemyBuilder = {}

-- Высота корпуса при масштабе 1: примерно по пояс игроку, чтобы врага было легко читать.
local BODY_HEIGHT = 4
local BODY_WIDTH = 2.6
local HEAD_SIZE = 1.6
-- Высота, на которой Humanoid держит корень над полом: выше любого порожка на уровнях.
local HIP_HEIGHT = 1

-- Невидимый корень подвижного врага: его держит Humanoid на высоте HIP_HEIGHT над полом.
local function buildMobileRoot(model: Model, size: Vector3, bodyCFrame: CFrame): BasePart
	local rootHeight = size.Y - HIP_HEIGHT
	local root = Geometry.part({
		name = "HumanoidRootPart",
		size = Vector3.new(size.X, rootHeight, size.Z),
		cframe = bodyCFrame * CFrame.new(0, size.Y / 2 - rootHeight / 2, 0),
		transparency = 1,
		castShadow = false,
		parent = model,
	})
	root.Anchored = false
	return root
end

local function buildHumanoid(model: Model, def: Enemies.EnemyDef): Humanoid
	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = HIP_HEIGHT
	humanoid.WalkSpeed = def.speed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	-- Смертью врага управляет EnemyService, а не Humanoid. Падать и лазать враг не должен.
	for _, state in
		{
			Enum.HumanoidStateType.Dead,
			Enum.HumanoidStateType.FallingDown,
			Enum.HumanoidStateType.Ragdoll,
			Enum.HumanoidStateType.Climbing,
			Enum.HumanoidStateType.Swimming,
		}
	do
		humanoid:SetStateEnabled(state, false)
	end
	humanoid.Parent = model
	return humanoid
end

-- Собирает модель врага и ставит её так, чтобы ноги стояли на уровне footY.
function EnemyBuilder.build(def: Enemies.EnemyDef, elite: boolean, footY: number, position: Vector3): EnemyModel
	local eliteDef = def.elite
	local scale = def.look.scale * (if elite and eliteDef then eliteDef.scale else 1)
	local bodyHeight = BODY_HEIGHT * scale
	local bodyWidth = BODY_WIDTH * scale
	local mobile = def.behavior ~= "dummy"

	local model = Instance.new("Model")
	model.Name = def.id .. (if elite then "_elite" else "")

	local bodySize = Vector3.new(bodyWidth, bodyHeight, bodyWidth * 0.8)
	local bodyCFrame = CFrame.new(position.X, footY + bodyHeight / 2, position.Z)
	local root = if mobile then buildMobileRoot(model, bodySize, bodyCFrame) else nil

	local body = Geometry.part({
		name = "Body",
		size = bodySize,
		cframe = bodyCFrame,
		color = Color3.fromHex(def.look.body),
		material = Enum.Material.Slate,
		-- У подвижного врага сталкивается невидимый корень, корпус — только картинка.
		canCollide = not mobile,
		parent = model,
	})
	if root then
		Geometry.weld(root, body)
		body.Massless = true
	end

	local head = Geometry.part({
		name = "Head",
		size = Vector3.new(HEAD_SIZE * scale, HEAD_SIZE * scale, HEAD_SIZE * scale),
		cframe = body.CFrame * CFrame.new(0, bodyHeight / 2 + HEAD_SIZE * scale / 2, 0),
		color = Color3.fromHex(def.look.body),
		material = Enum.Material.Slate,
		canCollide = false,
		parent = model,
	})
	Geometry.weld(body, head)
	head.Massless = true

	-- Акцентный «глаз»: по нему врага видно в полумраке и понятно, куда он смотрит.
	local eye = Geometry.part({
		name = "Eye",
		size = Vector3.new(HEAD_SIZE * scale * 0.5, HEAD_SIZE * scale * 0.25, 0.2),
		cframe = head.CFrame * CFrame.new(0, 0, -HEAD_SIZE * scale / 2),
		color = Color3.fromHex(def.look.accent),
		material = Enum.Material.Neon,
		canCollide = false,
		castShadow = false,
		parent = model,
	})
	Geometry.weld(head, eye)
	eye.Massless = true

	if elite and eliteDef then
		-- Элиту видно издалека по свечению вокруг (ТЗ 10.3).
		Geometry.pointLight(body, Color3.fromHex(def.look.accent), 16, 1.2)
	end

	local humanoid = if mobile then buildHumanoid(model, def) else nil

	local primary = root or body
	model.PrimaryPart = primary
	model:SetAttribute(Attr.DefId, def.id)
	model:SetAttribute(Attr.DisplayName, if elite and eliteDef then eliteDef.displayName else def.displayName)
	model:SetAttribute(Attr.Elite, elite)
	model:AddTag(Constants.Tags.Enemy)

	return { model = model, root = primary, humanoid = humanoid }
end

return table.freeze(EnemyBuilder)
