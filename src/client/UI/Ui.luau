--!strict
-- Небольшая фабрика интерфейса: создание экземпляров из таблицы свойств и частые детали.
-- Детали оформления (corner, stroke, padding, list) возвращают Instance: они нужны только
-- как дочерние элементы, а массив дочерних элементов должен иметь тип { Instance }.
-- Parent назначается последним — так экземпляр не реплицируется и не перерисовывается
-- на каждом промежуточном свойстве.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

export type Props = { [string]: any }

local Ui = {}

function Ui.new(className: string, props: Props?, children: { Instance }?): Instance
	local instance = Instance.new(className :: any)
	local parent: Instance? = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Ui.corner(radius: number?): Instance
	return Ui.new("UICorner", { CornerRadius = UDim.new(0, radius or Theme.CornerRadius) })
end

function Ui.stroke(color: Color3, thickness: number?, transparency: number?): Instance
	return Ui.new("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Ui.padding(vertical: number, horizontal: number?): Instance
	local h = UDim.new(0, horizontal or vertical)
	local v = UDim.new(0, vertical)
	return Ui.new("UIPadding", { PaddingTop = v, PaddingBottom = v, PaddingLeft = h, PaddingRight = h })
end

function Ui.list(direction: Enum.FillDirection, spacing: number, props: Props?): Instance
	local layoutProps: Props = {
		FillDirection = direction,
		Padding = UDim.new(0, spacing),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}
	if props then
		for key, value in props do
			layoutProps[key] = value
		end
	end
	return Ui.new("UIListLayout", layoutProps)
end

-- Текстовая метка с настройками темы по умолчанию.
function Ui.label(props: Props): TextLabel
	local merged: Props = {
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Medium,
		TextSize = Theme.TextSize.Body,
		TextColor3 = Theme.Colors.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for key, value in props do
		merged[key] = value
	end
	return Ui.new("TextLabel", merged) :: TextLabel
end

function Ui.button(props: Props): TextButton
	local merged: Props = {
		AutoButtonColor = true,
		BackgroundColor3 = Theme.Colors.PanelRaised,
		FontFace = Theme.Fonts.Bold,
		TextSize = Theme.TextSize.Body,
		TextColor3 = Theme.Colors.Text,
	}
	for key, value in props do
		merged[key] = value
	end
	local button = Ui.new("TextButton", merged) :: TextButton
	Ui.corner().Parent = button
	return button
end

function Ui.tween(instance: Instance, seconds: number, goal: Props, style: Enum.EasingStyle?): Tween
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goal
	)
	tween:Play()
	return tween
end

-- 1234567 → «1 234 567»: так большие числа читаются быстрее.
function Ui.formatInt(value: number): string
	local text = tostring(math.floor(math.abs(value)))
	local grouped = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1 ")))
	grouped = string.gsub(grouped, "^ ", "")
	return if value < 0 then "−" .. grouped else grouped
end

return table.freeze(Ui)
