--!strict
-- Подсказки для новых игроков (ТЗ 28: объяснять действие в момент, когда оно нужно).
-- Показываются, только если в настройках включены «Подсказки».
-- Фаза 1: одна приветственная подсказка; полноценное обучение — фаза 11.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local NotificationController = require(script.Parent.NotificationController)

local DATA_WAIT_SECONDS = 30
local WELCOME_DELAY = 1.5

local TipsController = {}

local player = Players.LocalPlayer

local function waitForProfile(): boolean
	local deadline = os.clock() + DATA_WAIT_SECONDS
	while player:GetAttribute(Constants.PlayerAttr.DataReady) ~= true do
		if os.clock() >= deadline then
			return false
		end
		task.wait(0.25)
	end
	return true
end

local function tipsEnabled(): boolean
	return player:GetAttribute(Constants.SettingAttrPrefix .. "ShowTips") ~= false
end

function TipsController.init() end

function TipsController.start()
	task.spawn(function()
		if not waitForProfile() then
			return
		end
		task.wait(WELCOME_DELAY)
		if tipsEnabled() then
			NotificationController.push(
				"Добро пожаловать на Заставу! Подойдите к маяку в центре площади и активируйте его.",
				"info"
			)
		end
	end)
end

return TipsController
