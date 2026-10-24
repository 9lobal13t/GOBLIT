local Test = require("./lib/Test")
local EnemyBrain = require("../src/shared/Logic/EnemyBrain")
local Enemies = require("../src/shared/Definitions/Enemies")

local expect = Test.expect

local PROFILE: EnemyBrain.Profile = {
	aggroRange = 60,
	attackRange = 5.5,
	windup = 0.7,
	recover = 0.9,
	leashRadius = 18,
	homeTolerance = 2,
}

type SensesInput = {
	now: number?,
	stateSince: number?,
	hasTarget: boolean?,
	targetDistance: number?,
	targetFromHome: number?,
	homeDistance: number?,
}

-- Враг дома, цель в 10 стадах, тоже недалеко от дома.
local function senses(input: SensesInput): EnemyBrain.Senses
	return {
		now = input.now or 10,
		stateSince = input.stateSince or 0,
		hasTarget = if input.hasTarget == nil then true else input.hasTarget,
		targetDistance = input.targetDistance or 10,
		targetFromHome = input.targetFromHome or 10,
		homeDistance = input.homeDistance or 0,
	}
end

local function decide(state: EnemyBrain.State, input: SensesInput): EnemyBrain.Decision
	return EnemyBrain.decide(state, senses(input), PROFILE)
end

Test.describe("EnemyBrain.decide", function(it)
	it("без цели враг стоит дома", function()
		expect(decide("Idle", { hasTarget = false }).state).toBe("Idle")
	end)

	it("замечает цель в радиусе агрессии и бежит к ней", function()
		expect(decide("Idle", {}).state).toBe("Chase")
		expect(decide("Idle", { targetDistance = 61 }).state).toBe("Idle")
	end)

	it("не гонится за целью, которая стоит за поводком", function()
		expect(decide("Idle", { targetFromHome = 19 }).state).toBe("Idle")
		expect(decide("Chase", { targetFromHome = 19 }).state).toBe("Return")
	end)

	it("подбежав на дальность удара, начинает замах", function()
		expect(decide("Chase", { targetDistance = 6 }).state).toBe("Chase")
		expect(decide("Chase", { targetDistance = 5.5 }).state).toBe("Telegraph")
	end)

	it("бьёт ровно по окончании замаха и только один раз", function()
		local early = decide("Telegraph", { now = 0.69, stateSince = 0 })
		expect(early.state).toBe("Telegraph")
		expect(early.strike).toBeFalsy()

		local done = decide("Telegraph", { now = 0.7, stateSince = 0 })
		expect(done.state).toBe("Recover")
		expect(done.strike).toBeTruthy()

		-- В восстановлении удара нет, даже если цель стоит вплотную.
		local after = decide("Recover", { now = 10.75, stateSince = 10.7, targetDistance = 1 })
		expect(after.state).toBe("Recover")
		expect(after.strike).toBeFalsy()
	end)

	it("начатый замах не прерывается, даже если цель ушла", function()
		local decision = decide("Telegraph", { now = 10.3, stateSince = 10, hasTarget = false })
		expect(decision.state).toBe("Telegraph")
	end)

	it("после восстановления снова гонится или уходит домой", function()
		expect(decide("Recover", { now = 10.9, stateSince = 10 }).state).toBe("Chase")
		expect(decide("Recover", { now = 10.9, stateSince = 10, hasTarget = false }).state).toBe("Return")
	end)

	it(
		"вытолкнутый за поводок враг уходит домой, даже если цель рядом",
		function()
			expect(decide("Chase", { homeDistance = 19, targetDistance = 3 }).state).toBe("Return")
		end
	)

	it("по дороге домой не отвлекается на цель", function()
		expect(decide("Return", { homeDistance = 10, targetDistance = 3 }).state).toBe("Return")
		expect(decide("Return", { homeDistance = 2 }).state).toBe("Idle")
	end)

	it("числа Шелухи дают телеграф заметно длиннее пинга", function()
		-- Телеграф должен успеть дойти до игрока и оставить время отойти (ТЗ: риски, бой).
		local husk = Enemies.ById.husk
		expect(husk.windup).toBeGreaterThanOrEqual(0.5)
		expect(husk.attackRange).toBeLessThan(husk.aggroRange)
	end)
end)

Test.describe("EnemyBrain.strikeHits", function(it)
	local cosOf = function(degrees: number): number
		return math.cos(math.rad(degrees))
	end

	it("попадает по цели перед собой в пределах дальности", function()
		expect(EnemyBrain.strikeHits(5, cosOf(0), 5.5, 100, 1)).toBeTruthy()
		-- Край цели в пределах дальности — тоже попадание.
		expect(EnemyBrain.strikeHits(6.4, cosOf(0), 5.5, 100, 1)).toBeTruthy()
	end)

	it("промахивается, если цель отошла", function()
		expect(EnemyBrain.strikeHits(6.6, cosOf(0), 5.5, 100, 1)).toBeFalsy()
	end)

	it("промахивается, если цель обежала врага сбоку", function()
		expect(EnemyBrain.strikeHits(3, cosOf(49), 5.5, 100, 1)).toBeTruthy()
		expect(EnemyBrain.strikeHits(3, cosOf(51), 5.5, 100, 1)).toBeFalsy()
		expect(EnemyBrain.strikeHits(3, cosOf(180), 5.5, 100, 1)).toBeFalsy()
	end)

	it("цель вплотную — попадание", function()
		-- Направление на цель не определено (косинус любой) — всё равно попадание.
		expect(EnemyBrain.strikeHits(0, -1, 5.5, 100, 1)).toBeTruthy()
	end)

	it("испорченные числа — промах, а не ошибка", function()
		expect(EnemyBrain.strikeHits(0 / 0, 1, 5.5, 100, 1)).toBeFalsy()
		expect(EnemyBrain.strikeHits(3, 0 / 0, 5.5, 100, 1)).toBeFalsy()
	end)
end)

return nil
