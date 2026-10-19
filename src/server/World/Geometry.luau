--!strict
-- Фабрика простых деталей для построек из примитивов.
-- Это временная визуальная основа до Blender-пайплайна (фаза 8): одинаковые настройки
-- по умолчанию (закреплено, гладкие поверхности) задаются здесь, а не в каждой постройке.

local Geometry = {}

export type PartSpec = {
	name: string,
	size: Vector3,
	cframe: CFrame,
	parent: Instance,
	color: Color3?,
	material: Enum.Material?,
	transparency: number?,
	canCollide: boolean?,
	castShadow: boolean?,
	shape: Enum.PartType?,
}

function Geometry.part(spec: PartSpec): Part
	local part = Instance.new("Part")
	part.Name = spec.name
	if spec.shape then
		part.Shape = spec.shape
	end
	part.Size = spec.size
	part.CFrame = spec.cframe
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Color = spec.color or Color3.fromRGB(120, 120, 120)
	part.Material = spec.material or Enum.Material.SmoothPlastic
	part.Transparency = spec.transparency or 0
	part.CanCollide = if spec.canCollide == nil then true else spec.canCollide
	part.CastShadow = if spec.castShadow == nil then true else spec.castShadow
	part.Parent = spec.parent
	return part
end

-- Плоский диск: цилиндр Roblox вытянут вдоль оси X, поэтому поворачиваем его на 90° по Z.
function Geometry.disc(name: string, center: Vector3, diameter: number, thickness: number, parent: Instance): Part
	return Geometry.part({
		name = name,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(thickness, diameter, diameter),
		cframe = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		parent = parent,
	})
end

-- Точечный свет без теней: тени от множества ламп слишком дороги для слабых устройств.
function Geometry.pointLight(parent: BasePart, color: Color3, range: number, brightness: number): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = parent
	return light
end

return table.freeze(Geometry)
