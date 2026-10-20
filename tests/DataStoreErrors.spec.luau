local Test = require("./lib/Test")
local DataStoreErrors = require("../src/shared/Logic/DataStoreErrors")

local expect = Test.expect

Test.describe("DataStoreErrors", function(it)
	it("распознаёт настоящую ошибку из pcall в Studio без доступа к API", function()
		-- Текст из docs/reports/phase1-studio-check.md (проверка в Studio 20.10.2026).
		expect(DataStoreErrors.isPermanent("403: Cannot write to DataStore from studio if API access is not enabled."))
			.toBe(true)
	end)

	it("распознаёт вариант сообщения из Output", function()
		expect(
			DataStoreErrors.isPermanent(
				"DataStoreService: StudioAccessToApisNotAllowed: Cannot write to DataStore from studio if API access is not enabled. API: UpdateAsync, Data Store: GOBLIT_Profiles_v1"
			)
		).toBe(true)
	end)

	it("распознаёт неопубликованное место", function()
		expect(DataStoreErrors.isPermanent("You must publish this place to the web to access DataStore.")).toBe(true)
	end)

	it("временные ошибки не считаются постоянными — их нужно повторять", function()
		expect(DataStoreErrors.isPermanent("502: API Services rejected request with error. HTTP 500 (Internal Server Error)"))
			.toBe(false)
		expect(DataStoreErrors.isPermanent("Request was throttled. Try sending fewer requests.")).toBe(false)
		expect(DataStoreErrors.isPermanent("")).toBe(false)
	end)

	it("403 засчитывается только как код ошибки в начале, а не как число в тексте", function()
		expect(DataStoreErrors.isPermanent("UserId 403 timed out")).toBe(false)
	end)
end)

return nil
