--!strict
-- Решения ИИ врага ближнего боя: в каком состоянии он сейчас и когда бьёт.
-- Чистый модуль без Roblox API: всё, что враг «видит», приходит параметрами,
-- тесты — tests/EnemyBrain.spec.luau. Движение и проверку попадания делает
-- server/Services/EnemyAiService по решению отсюда.
--
-- Состояния (ТЗ: Idle / Chase / Telegraph / Recover):
--   Idle      — стоит дома, ждёт цель в радиусе агрессии;
--   Chase     — бежит к цели;
--   Telegraph — остановился и замахивается: игрок видит удар заранее и успевает уйти.
--               Замах не прерывается: начатый удар случится, даже если цель ушла (тогда мимо);
--   Recover   — пауза после удара, окно для ответа игрока;
--   Return    — цель потеряна или ушла за пределы зоны (поводок): враг идёт домой и по пути
--               не отвлекается, иначе игрок держал бы его на краю зоны бесконечно.

local EnemyBrain = {}

export type State = "Idle" | "Chase" | "Telegraph" | "Recover" | "Return"

-- Что враг знает о мире в момент решения. Расстояния — по горизонтали, в стадах.
export type Senses = {
	now: number,
	stateSince: number, -- когда враг вошёл в текущее состояние
	hasTarget: boolean,
	targetDistance: number, -- до цели; без цели не важно
	targetFromHome: number, -- от дома до цели; без цели не важно
	homeDistance: number, -- от дома до врага
}

-- Числа врага (из Definitions/Enemies и зоны, где он живёт).
export type Profile = {
	aggroRange: number,
	attackRange: number,
	windup: number,
	recover: number,
	leashRadius: number, -- дальше этого от дома враг не преследует
	homeTolerance: number, -- на таком расстоянии от дома враг считается дома
}

export type Decision = {
	state: State,
	-- true ровно в тот момент, когда замах закончился: пора проверить попадание.
	strike: boolean,
}

local function decision(state: State, strike: boolean?): Decision
	return { state = state, strike = strike == true }
end

-- Цель, за которой стоит гнаться: видна и стоит внутри зоны врага.
local function canChase(senses: Senses, profile: Profile): boolean
	return senses.hasTarget
		and senses.targetDistance <= profile.aggroRange
		and senses.targetFromHome <= profile.leashRadius
end

function EnemyBrain.decide(state: State, senses: Senses, profile: Profile): Decision
	local elapsed = senses.now - senses.stateSince

	if state == "Idle" then
		return decision(if canChase(senses, profile) then "Chase" else "Idle")
	elseif state == "Chase" then
		-- Враг вытолкнули или увели за поводок — домой, даже если цель рядом.
		if senses.homeDistance > profile.leashRadius or not canChase(senses, profile) then
			return decision("Return")
		end
		if senses.targetDistance <= profile.attackRange then
			return decision("Telegraph")
		end
		return decision("Chase")
	elseif state == "Telegraph" then
		if elapsed >= profile.windup then
			return decision("Recover", true)
		end
		return decision("Telegraph")
	elseif state == "Recover" then
		if elapsed < profile.recover then
			return decision("Recover")
		end
		return decision(if canChase(senses, profile) then "Chase" else "Return")
	else
		if senses.homeDistance <= profile.homeTolerance then
			return decision("Idle")
		end
		return decision("Return")
	end
end

-- Попал ли удар. Проверяется в момент удара, а не в начале замаха: игрок, который
-- отошёл или обежал врага за время телеграфа, увернулся.
-- cosToTarget — косинус угла между направлением замаха и направлением на цель.
-- targetRadius — половина ширины цели: по краю тоже попадает.
function EnemyBrain.strikeHits(
	distance: number,
	cosToTarget: number,
	attackRange: number,
	arcDegrees: number,
	targetRadius: number
): boolean
	if distance ~= distance or cosToTarget ~= cosToTarget then
		return false
	end
	if distance > attackRange + math.max(targetRadius, 0) then
		return false
	end
	-- Цель вплотную: направление на неё не определено, считаем попаданием.
	if distance < 0.01 then
		return true
	end
	return cosToTarget >= math.cos(math.rad(arcDegrees / 2))
end

return table.freeze(EnemyBrain)
