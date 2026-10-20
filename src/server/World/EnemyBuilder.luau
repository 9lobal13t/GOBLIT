--!strict
-- Сборка модели врага из примитивов по его описанию в Definitions/Enemies.
-- Временная замена до Blender-пайплайна (фаза 8): важны узнаваемый силуэт, размер
-- и точка, по которой считается попадание, — а не детализация.
--
-- Силуэт собирается так, чтобы врага было видно в бою (ТЗ 10.1): корпус, голова и
-- акцентный «глаз» цветом врага. Модель не использует Humanoid: двигать её будет
-- сервер, а стандартные полоски здоровья и имена нам не нужны.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Enemies = require(ReplicatedStorage.Shared.Definitions.Enemies)
local Geometry = require(script.Parent.Geometry)

local Attr = Constants.EnemyAttr

export type EnemyModel = {
	model: Model,
	root: BasePart,
}

local EnemyBuilder = {}

-- Высота корпуса при масштабе 1: примерно по пояс игроку, чтобы врага было легко читать.
local BODY_HEIGHT = 4
local BODY_WIDTH = 2.6
local HEAD_SIZE = 1.6

-- Собирает модель врага и ставит её так, чтобы ноги стояли на уровне footY.
function EnemyBuilder.build(def: Enemies.EnemyDef, elite: boolean, footY: number, position: Vector3): EnemyModel
	local eliteDef = def.elite
	local scale = def.look.scale * (if elite and eliteDef then eliteDef.scale else 1)
	local bodyHeight = BODY_HEIGHT * scale
	local bodyWidth = BODY_WIDTH * scale

	local model = Instance.new("Model")
	model.Name = def.id .. (if elite then "_elite" else "")

	local root = Geometry.part({
		name = "Body",
		size = Vector3.new(bodyWidth, bodyHeight, bodyWidth * 0.8),
		cframe = CFrame.new(position.X, footY + bodyHeight / 2, position.Z),
		color = Color3.fromHex(def.look.body),
		material = Enum.Material.Slate,
		parent = model,
	})

	local head = Geometry.part({
		name = "Head",
		size = Vector3.new(HEAD_SIZE * scale, HEAD_SIZE * scale, HEAD_SIZE * scale),
		cframe = root.CFrame * CFrame.new(0, bodyHeight / 2 + HEAD_SIZE * scale / 2, 0),
		color = Color3.fromHex(def.look.body),
		material = Enum.Material.Slate,
		canCollide = false,
		parent = model,
	})
	Geometry.weld(root, head)

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

	if elite and eliteDef then
		-- Элиту видно издалека по свечению вокруг (ТЗ 10.3).
		Geometry.pointLight(root, Color3.fromHex(def.look.accent), 16, 1.2)
	end

	model.PrimaryPart = root
	model:SetAttribute(Attr.DefId, def.id)
	model:SetAttribute(Attr.DisplayName, if elite and eliteDef then eliteDef.displayName else def.displayName)
	model:SetAttribute(Attr.Elite, elite)
	model:AddTag(Constants.Tags.Enemy)

	return { model = model, root = root }
end

return table.freeze(EnemyBuilder)
