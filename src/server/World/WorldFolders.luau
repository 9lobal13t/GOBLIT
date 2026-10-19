--!strict
-- Корневые папки игрового мира в Workspace. Вся геометрия игры живёт в Workspace.World:
-- позже лучи (видимость, удары) будут фильтроваться именно по этой папке.

local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)

local WorldFolders = {}

local function ensureFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing:IsA("Folder"), `{parent:GetFullName()}.{name} должен быть Folder`)
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function WorldFolders.world(): Folder
	return ensureFolder(Workspace, Constants.Folders.World)
end

function WorldFolders.hub(): Folder
	return ensureFolder(WorldFolders.world(), "Hub")
end

return table.freeze(WorldFolders)
