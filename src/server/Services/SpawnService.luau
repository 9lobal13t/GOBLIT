--!strict
-- Появление персонажей.
--
-- Автозагрузка персонажей Roblox выключена: иначе персонаж может появиться раньше, чем
-- построена Застава с точкой появления, и оказаться в случайном месте. Это проверено в Studio
-- (docs/reports/phase1-studio-check.md, проблема 2). Здесь персонаж создаётся только после
-- постройки мира (все init() выполняются раньше любого start()) и пересоздаётся после смерти.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ErrorReporter = require(ReplicatedStorage.Shared.Util.ErrorReporter)
local HubService = require(script.Parent.HubService)

local HUMANOID_WAIT_SECONDS = 10

local SpawnService = {}

local loading: { [Player]: boolean } = {}

local function spawnCharacter(player: Player)
	if loading[player] or player.Parent == nil then
		return
	end
	loading[player] = true
	local ok, problem = pcall(player.LoadCharacterAsync, player)
	loading[player] = nil
	if not ok then
		ErrorReporter.report("Spawn", `UserId {player.UserId}: {problem}`)
	end
end

local function respawnAfterDeath(player: Player, character: Model)
	local found = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", HUMANOID_WAIT_SECONDS)
	if not found or not found:IsA("Humanoid") then
		return
	end
	found.Died:Once(function()
		task.delay(Players.RespawnTime, function()
			-- Если персонажа уже пересоздали другим способом, второй раз не создаём.
			if player.Parent ~= nil and player.Character == character then
				spawnCharacter(player)
			end
		end)
	end)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		task.spawn(respawnAfterDeath, player, character)
	end)
	-- Персонаж, загруженный до запуска серверных скриптов (так бывает в Studio), тоже
	-- пересоздаётся: только так он гарантированно окажется на точке появления Заставы.
	task.spawn(spawnCharacter, player)
end

function SpawnService.init()
	Players.CharacterAutoLoads = false
end

function SpawnService.start()
	if not HubService.isBuilt() then
		ErrorReporter.report("Spawn", "Застава не построена: персонажи появятся без точки появления")
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		loading[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return SpawnService
