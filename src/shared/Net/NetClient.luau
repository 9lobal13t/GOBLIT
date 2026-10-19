--!strict
-- Доступ клиента к удалённым событиям из реестра Remotes.
-- События создаёт сервер при старте, поэтому клиент дожидается их появления.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(script.Parent.Parent.Constants)
local Remotes = require(script.Parent.Remotes)

assert(RunService:IsClient(), "NetClient доступен только на клиенте")

local WAIT_TIMEOUT = 30

local NetClient = {}

local folder: Folder? = nil

local function getFolder(): Folder
	if folder then
		return folder
	end
	local found = ReplicatedStorage:WaitForChild(Constants.Folders.Net, WAIT_TIMEOUT)
	assert(found and found:IsA("Folder"), "сервер не создал папку сетевых событий")
	folder = found
	return found
end

local function getInstance(def: Remotes.RemoteDef): Instance
	local instance = getFolder():WaitForChild(def.name, WAIT_TIMEOUT)
	assert(instance, `сетевое событие {def.name} не найдено`)
	return instance
end

-- Отправить запрос серверу.
function NetClient.send(def: Remotes.RemoteDef, ...: any)
	assert(def.direction == "ToServer", `{def.name} нельзя отправлять с клиента`)
	local remote = getInstance(def)
	assert(remote:IsA("RemoteEvent"), `{def.name} должен быть RemoteEvent`)
	remote:FireServer(...)
end

-- Подписаться на событие от сервера.
function NetClient.on(def: Remotes.RemoteDef, handler: (...any) -> ()): RBXScriptConnection
	assert(def.direction == "ToClient", `{def.name} не приходит с сервера`)
	local remote = getInstance(def)
	if remote:IsA("UnreliableRemoteEvent") then
		return remote.OnClientEvent:Connect(handler)
	end
	assert(remote:IsA("RemoteEvent"), `{def.name} должен быть RemoteEvent`)
	return remote.OnClientEvent:Connect(handler)
end

return table.freeze(NetClient)
