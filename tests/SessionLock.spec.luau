local Test = require("./lib/Test")
local SessionLock = require("../src/shared/Logic/SessionLock")

local expect = Test.expect

local NOW = 1760000000
local TTL = 180
local FORCE_AFTER = 30

local function lock(jobId: string, session: string, age: number): any
	return { JobId = jobId, Session = session, Time = NOW - age }
end

Test.describe("SessionLock", function(it)
	it("parse: корректная блокировка читается полностью", function()
		expect(SessionLock.parse({ JobId = "a", Session = "s1", Time = 5 })).toEqual({
			JobId = "a",
			Session = "s1",
			Time = 5,
		})
	end)

	it("parse: мусор считается отсутствием блокировки", function()
		expect(SessionLock.parse(nil)).toBeNil()
		expect(SessionLock.parse("lock")).toBeNil()
		expect(SessionLock.parse({ JobId = 1, Time = 5 })).toBeNil()
		expect(SessionLock.parse({ JobId = "a" })).toBeNil()
		expect(SessionLock.parse({ JobId = "a", Time = 0 / 0 })).toBeNil()
	end)

	it(
		"parse: старый формат без Session получает пустой идентификатор",
		function()
			expect(SessionLock.parse({ JobId = "a", Time = 5 })).toEqual({ JobId = "a", Session = "", Time = 5 })
		end
	)

	it("без блокировки профиль забирается сразу", function()
		expect(SessionLock.decideAcquire(nil, "me", NOW, 0, TTL, FORCE_AFTER)).toBe("acquire")
	end)

	it(
		"блокировка своего же сервера — остаток прошлой сессии, забирается сразу",
		function()
			expect(SessionLock.decideAcquire(lock("me", "old", 5), "me", NOW, 0, TTL, FORCE_AFTER)).toBe("acquire")
		end
	)

	it(
		"свежая чужая блокировка: ждём, пока не пройдёт время принудительного захвата",
		function()
			local other = lock("other", "s", 5)
			expect(SessionLock.decideAcquire(other, "me", NOW, 0, TTL, FORCE_AFTER)).toBe("wait")
			expect(SessionLock.decideAcquire(other, "me", NOW, FORCE_AFTER - 0.1, TTL, FORCE_AFTER)).toBe("wait")
			expect(SessionLock.decideAcquire(other, "me", NOW, FORCE_AFTER, TTL, FORCE_AFTER)).toBe("force")
		end
	)

	it("устаревшая чужая блокировка забирается сразу", function()
		expect(SessionLock.decideAcquire(lock("other", "s", TTL), "me", NOW, 0, TTL, FORCE_AFTER)).toBe("stale")
	end)

	it(
		"owns: писать может только сессия, чья блокировка в записи",
		function()
			expect(SessionLock.owns(lock("me", "s1", 0), "s1")).toBe(true)
			expect(SessionLock.owns(lock("me", "s2", 0), "s1")).toBe(false)
			expect(SessionLock.owns(lock("other", "s2", 0), "s1")).toBe(false)
		end
	)

	it(
		"owns: отсутствие блокировки — потеря, а не разрешение писать",
		function()
			expect(SessionLock.owns(nil, "s1")).toBe(false)
		end
	)

	it(
		"owns: пустой идентификатор (старый формат) никогда не считается своим",
		function()
			expect(SessionLock.owns(lock("me", "", 0), "")).toBe(false)
		end
	)
end)

return nil
