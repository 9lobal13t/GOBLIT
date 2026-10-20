--!strict
-- Классификация ошибок DataStore. Чистый модуль без Roblox API (тестируется в Lune).
--
-- «Постоянная» ошибка означает, что повторять запрос бесполезно до перезапуска сервера:
-- в Studio выключен доступ к API или место не опубликовано. Тогда сохранение отключается
-- сразу, а не после нескольких попыток с паузами.
--
-- Признаки сверены с настоящими сообщениями (docs/reports/phase1-studio-check.md):
--   pcall получает:  "403: Cannot write to DataStore from studio if API access is not enabled."
--   Output Roblox:   "DataStoreService: StudioAccessToApisNotAllowed: Cannot write to DataStore ..."
-- Код 403 у DataStore означает именно запрет доступа к API из Studio.

local PERMANENT_MARKERS = {
	"API access is not enabled",
	"StudioAccessToApisNotAllowed",
	"publish this place",
}

local DataStoreErrors = {}

function DataStoreErrors.isPermanent(message: string): boolean
	if string.find(message, "^%s*403:") then
		return true
	end
	for _, marker in PERMANENT_MARKERS do
		if string.find(message, marker, 1, true) then
			return true
		end
	end
	return false
end

return table.freeze(DataStoreErrors)
