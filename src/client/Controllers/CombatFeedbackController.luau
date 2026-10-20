--!strict
-- Что игрок видит в бою: цифры урона и полоски здоровья врагов (ТЗ 20.2).
--
-- Полоски берут здоровье из атрибутов модели врага, которые выставляет сервер, поэтому
-- показать больше, чем есть на сервере, клиент не может. Полоска появляется у врага,
-- которому нанесли урон, и прячется, когда он снова цел.
--
-- Цифры урона и полоски считаются «украшением»: их количество ограничено, чтобы в бою
-- с шестью игроками экран не превратился в кашу, а слабые устройства не просели.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local NetClient = require(ReplicatedStorage.Shared.Net.NetClient)
local Theme = require(script.Parent.Parent.UI.Theme)
local Ui = require(script.Parent.Parent.UI.Ui)

local Attr = Constants.EnemyAttr

local MAX_NUMBERS = 14
local NUMBER_SECONDS = 0.8
local NUMBER_RISE = 4
local BAR_WIDTH = 120
local BAR_HEIGHT = 10
local BAR_RANGE = 90
local BAR_HIDE_DELAY = 5

local CombatFeedbackController = {}

local numbersFolder: Folder? = nil
local activeNumbers = 0

-- Цифры урона ------------------------------------------------------------------------

local function spawnNumber(position: Vector3, amount: number, crit: boolean)
	local parent = numbersFolder
	if not parent or activeNumbers >= MAX_NUMBERS then
		return
	end
	activeNumbers += 1

	-- Небольшой разброс: два удара подряд не рисуют цифры друг на друге.
	local anchor = Instance.new("Part")
	anchor.Name = "DamageNumber"
	anchor.Size = Vector3.one
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Anchored = true
	anchor.CastShadow = false
	anchor.Position = position + Vector3.new(math.random(-15, 15) / 10, 2, math.random(-15, 15) / 10)

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 40)
	gui.AlwaysOnTop = true
	gui.MaxDistance = BAR_RANGE
	gui.Parent = anchor

	local label = Ui.label({
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.Fonts.Heavy,
		TextSize = if crit then Theme.TextSize.Big else Theme.TextSize.Title,
		TextColor3 = if crit then Theme.Colors.Gold else Theme.Colors.Text,
		TextStrokeTransparency = 0.4,
		Text = if crit then `{Ui.formatInt(amount)}!` else Ui.formatInt(amount),
		Parent = gui,
	})

	anchor.Parent = parent
	TweenService:Create(anchor, TweenInfo.new(NUMBER_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = anchor.Position + Vector3.new(0, NUMBER_RISE, 0),
	}):Play()
	local fade = TweenService:Create(label, TweenInfo.new(NUMBER_SECONDS), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	fade:Play()
	fade.Completed:Once(function()
		activeNumbers -= 1
		anchor:Destroy()
	end)
end

local function onHit(payload: unknown)
	if type(payload) ~= "table" then
		return
	end
	local data = payload :: { [string]: unknown }
	if typeof(data.position) ~= "Vector3" or type(data.amount) ~= "number" then
		return
	end
	spawnNumber(data.position :: Vector3, data.amount :: number, data.crit == true)
end

-- Полоски здоровья врагов -------------------------------------------------------------

local function attachHealthBar(model: Model)
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not root then
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "GoblitHealth"
	gui.Size = UDim2.fromOffset(BAR_WIDTH, BAR_HEIGHT + 20)
	gui.StudsOffsetWorldSpace = Vector3.new(0, root.Size.Y / 2 + 2.2, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = BAR_RANGE
	gui.Enabled = false
	gui.Adornee = root

	local name = Ui.label({
		Name = "Name",
		Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.Fonts.Bold,
		TextSize = Theme.TextSize.Small,
		TextStrokeTransparency = 0.4,
		Text = tostring(model:GetAttribute(Attr.DisplayName) or ""),
		Parent = gui,
	})
	if model:GetAttribute(Attr.Elite) == true then
		name.TextColor3 = Theme.Colors.Shards
	end

	local back = Ui.new("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(BAR_WIDTH, BAR_HEIGHT),
		BackgroundColor3 = Theme.Colors.HealthBack,
		BorderSizePixel = 0,
		Parent = gui,
	}, { Ui.corner(BAR_HEIGHT // 2), Ui.stroke(Theme.Colors.Border, 1, 0.4) }) :: Frame

	local fill = Ui.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Health,
		BorderSizePixel = 0,
		Parent = back,
	}, { Ui.corner(BAR_HEIGHT // 2) }) :: Frame

	gui.Parent = root

	local hideToken = 0
	local function refresh()
		local health = model:GetAttribute(Attr.Health)
		local maxHealth = model:GetAttribute(Attr.MaxHealth)
		if type(health) ~= "number" or type(maxHealth) ~= "number" or maxHealth <= 0 then
			return
		end
		local ratio = math.clamp(health / maxHealth, 0, 1)
		fill.Size = UDim2.fromScale(ratio, 1)

		-- Полоска показывается, пока враг ранен, и прячется, если он долго цел.
		if ratio < 1 then
			gui.Enabled = true
			hideToken += 1
			local token = hideToken
			task.delay(BAR_HIDE_DELAY, function()
				if token == hideToken and gui.Parent then
					local current = model:GetAttribute(Attr.Health)
					local max = model:GetAttribute(Attr.MaxHealth)
					if type(current) == "number" and type(max) == "number" and current >= max then
						gui.Enabled = false
					end
				end
			end)
		end
	end

	model:GetAttributeChangedSignal(Attr.Health):Connect(refresh)
	refresh()
end

function CombatFeedbackController.init()
	local folder = Workspace:FindFirstChild(Constants.Folders.Effects)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = Constants.Folders.Effects
		folder.Parent = Workspace
	end
	numbersFolder = folder :: Folder
end

function CombatFeedbackController.start()
	NetClient.on(Remotes.Hit, onHit)

	for _, model in CollectionService:GetTagged(Constants.Tags.Enemy) do
		if model:IsA("Model") then
			attachHealthBar(model)
		end
	end
	CollectionService:GetInstanceAddedSignal(Constants.Tags.Enemy):Connect(function(instance)
		if instance:IsA("Model") then
			attachHealthBar(instance)
		end
	end)
end

return CombatFeedbackController
