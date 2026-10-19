--!strict
-- Настройки игрока (ТЗ 31). Хранятся в профиле и меняются только запросом UpdateSetting,
-- который проверяется по ProfileSchema.SettingsSpec. Текущие значения реплицируются
-- игроку атрибутами "<SettingAttrPrefix><ключ>"; клиент показывает только их,
-- то есть то, что сервер действительно принял.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local ProfileSchema = require(ReplicatedStorage.Shared.Logic.ProfileSchema)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local NetServer = require(script.Parent.Parent.Net.NetServer)
local Guard = require(script.Parent.Parent.Net.Guard)
local PlayerDataService = require(script.Parent.PlayerDataService)

local MAX_KEY_LENGTH = 32

local SettingsService = {}

local function replicateAll(player: Player, profile: ProfileSchema.Profile)
	for _, spec in ProfileSchema.SettingsSpec do
		local value = profile.Settings[spec.key]
		player:SetAttribute(Constants.SettingAttrPrefix .. spec.key, if value ~= nil then value else spec.default)
	end
end

local function onUpdateSetting(player: Player, rawKey: unknown, rawValue: unknown)
	local key = Guard.shortString(rawKey, MAX_KEY_LENGTH)
	if not key then
		NetServer.reject(player, Remotes.UpdateSetting.name, "некорректный ключ")
		return
	end
	local value = ProfileSchema.validateSetting(key, rawValue)
	if value == nil then
		NetServer.reject(player, Remotes.UpdateSetting.name, `недопустимое значение для {key}`)
		return
	end
	if not PlayerDataService.isReady(player) then
		return -- профиль ещё грузится; клиент блокирует панель до DataReady
	end

	local applied = PlayerDataService.update(player, function(profile)
		profile.Settings[key] = value
	end)
	if applied then
		player:SetAttribute(Constants.SettingAttrPrefix .. key, value)
	end
end

function SettingsService.init()
	PlayerDataService.ProfileLoaded:Connect(replicateAll)
	NetServer.onServerEvent(Remotes.UpdateSetting, onUpdateSetting)
end

function SettingsService.start() end

return SettingsService
