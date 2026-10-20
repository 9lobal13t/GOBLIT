local Test = require("./lib/Test")
local ProfileSchema = require("../src/shared/Logic/ProfileSchema")

local expect = Test.expect
local NOW = 1760000000

Test.describe("ProfileSchema", function(it)
	it("профиль по умолчанию корректен", function()
		local profile = ProfileSchema.default(NOW)
		expect(profile.Version).toBe(ProfileSchema.CurrentVersion)
		expect(profile.CreatedAt).toBe(NOW)
		expect(profile.Gold).toBe(0)
		expect(profile.Settings.UiScale).toBe(1)
		expect(profile.Settings.ShowTips).toBe(true)
		expect(profile.Stats.Expeditions).toBe(0)
	end)

	it(
		"отсутствующие данные — новый игрок без пометки об исправлении",
		function()
			local profile, info = ProfileSchema.migrate(nil, NOW)
			expect(info.isNew).toBe(true)
			expect(info.repaired).toBe(false)
			expect(info.newerVersion).toBe(false)
			expect(profile).toEqual(ProfileSchema.default(NOW))
		end
	)

	it(
		"мусор вместо таблицы заменяется профилем по умолчанию с пометкой repaired",
		function()
			local profile, info = ProfileSchema.migrate("сломанные данные", NOW)
			expect(info.isNew).toBe(false)
			expect(info.repaired).toBe(true)
			expect(profile).toEqual(ProfileSchema.default(NOW))
		end
	)

	it("миграция v0 → v1 переносит Coins в Gold", function()
		local profile, info = ProfileSchema.migrate({ Coins = 50 }, NOW)
		expect(info.fromVersion).toBe(0)
		expect(profile.Version).toBe(1)
		expect(profile.Gold).toBe(50)
		expect((profile :: any).Coins).toBeNil()
	end)

	it(
		"валюта: отрицательная, NaN, дробная и огромная исправляются",
		function()
			local profile, info = ProfileSchema.migrate({
				Version = 1,
				Gold = -10,
				RelicShards = 0 / 0,
				Knowledge = 12.9,
			}, NOW)
			expect(profile.Gold).toBe(0)
			expect(profile.RelicShards).toBe(0)
			expect(profile.Knowledge).toBe(12)
			expect(info.repaired).toBe(true)

			local huge = ProfileSchema.migrate({ Version = 1, Gold = 1e30 }, NOW)
			expect(huge.Gold).toBe(1000000000)
		end
	)

	it("строка вместо числа отбрасывается", function()
		local profile = ProfileSchema.migrate({ Version = 1, Gold = "999999" }, NOW)
		expect(profile.Gold).toBe(0)
	end)

	it(
		"неизвестные и испорченные настройки отбрасываются, корректные сохраняются",
		function()
			local profile, info = ProfileSchema.migrate({
				Version = 1,
				Settings = { UiScale = 1.15, ShowTips = "да", HackMode = true, [5] = true },
			}, NOW)
			expect(profile.Settings.UiScale).toBe(1.15)
			expect(profile.Settings.ShowTips).toBe(true) -- значение по умолчанию
			expect(profile.Settings.HackMode).toBeNil()
			expect(info.repaired).toBe(true)
		end
	)

	it("статистика очищается от неверных значений", function()
		local profile = ProfileSchema.migrate({ Version = 1, Stats = { Kills = 7, Extractions = -3, Foo = 1 } }, NOW)
		expect(profile.Stats.Kills).toBe(7)
		expect(profile.Stats.Extractions).toBe(0)
		expect((profile.Stats :: any).Foo).toBeNil()
	end)

	it(
		"данные новой версии помечаются newerVersion (их нельзя перезаписывать)",
		function()
			local _, info = ProfileSchema.migrate({ Version = ProfileSchema.CurrentVersion + 1, Gold = 5 }, NOW)
			expect(info.newerVersion).toBe(true)
		end
	)

	it("CreatedAt из данных сохраняется", function()
		local profile = ProfileSchema.migrate({ Version = 1, CreatedAt = 1700000000 }, NOW)
		expect(profile.CreatedAt).toBe(1700000000)
	end)

	it("миграция идемпотентна", function()
		local once = ProfileSchema.migrate({ Coins = 3, Settings = { UiScale = 0.85 } }, NOW)
		local twice = ProfileSchema.migrate(once, NOW)
		expect(twice).toEqual(once)
	end)

	it("результат миграции не ссылается на исходные таблицы", function()
		local raw = { Version = 1, Settings = { UiScale = 0.85 }, Stats = { Kills = 1 } }
		local profile = ProfileSchema.migrate(raw, NOW)
		profile.Settings.UiScale = 1
		profile.Stats.Kills = 99
		expect(raw.Settings.UiScale).toBe(0.85)
		expect(raw.Stats.Kills).toBe(1)
	end)

	it("clone создаёт независимую копию вложенных таблиц", function()
		local original = ProfileSchema.default(NOW)
		local copy = ProfileSchema.clone(original)
		copy.Settings.ShowTips = false
		copy.Stats.Kills = 10
		copy.Gold = 5
		expect(original.Settings.ShowTips).toBe(true)
		expect(original.Stats.Kills).toBe(0)
		expect(original.Gold).toBe(0)
	end)

	it("validateSetting проверяет ключ, тип и допустимые варианты", function()
		expect(ProfileSchema.validateSetting("Unknown", true)).toBeNil()
		expect(ProfileSchema.validateSetting("ShowTips", 1)).toBeNil()
		expect(ProfileSchema.validateSetting("ShowTips", false)).toBe(false)
		expect(ProfileSchema.validateSetting("UiScale", 2)).toBeNil()
		expect(ProfileSchema.validateSetting("UiScale", 0 / 0)).toBeNil()
		expect(ProfileSchema.validateSetting("UiScale", true)).toBeNil()
		expect(ProfileSchema.validateSetting("UiScale", 1.1500000001)).toBe(1.15)
	end)

	it(
		"у каждой настройки корректное описание и значение по умолчанию проходит проверку",
		function()
			for _, spec in ProfileSchema.SettingsSpec do
				expect(#spec.label > 0).toBe(true)
				expect(ProfileSchema.validateSetting(spec.key, spec.default)).toBe(spec.default)
				if spec.kind == "choice" then
					expect(#spec.options).toBe(#spec.optionLabels)
					expect(#spec.options > 1).toBe(true)
				end
			end
		end
	)
end)

return nil
