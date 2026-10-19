--!strict
-- Минимальный тестовый фреймворк для Lune: describe / it / expect.
-- Без внешних зависимостей, чтобы тесты запускались одной командой `lune run tests/run`.

export type Expectation = {
	toBe: (expected: any) -> (),
	toEqual: (expected: any) -> (),
	toBeCloseTo: (expected: number, epsilon: number?) -> (),
	toBeTruthy: () -> (),
	toBeFalsy: () -> (),
	toBeNil: () -> (),
	toBeGreaterThan: (bound: number) -> (),
	toBeGreaterThanOrEqual: (bound: number) -> (),
	toBeLessThan: (bound: number) -> (),
	toBeLessThanOrEqual: (bound: number) -> (),
	toThrow: (pattern: string?) -> (),
}

type Case = { name: string, fn: () -> () }
type Suite = { name: string, cases: { Case } }

local suites: { Suite } = {}

local Test = {}

local function show(value: any): string
	if type(value) == "string" then
		return string.format("%q", value)
	end
	if type(value) == "table" then
		local parts = {}
		for key, item in value do
			table.insert(parts, `{tostring(key)}={show(item)}`)
		end
		table.sort(parts)
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(value)
end

local function deepEqual(a: any, b: any): boolean
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for key, value in a do
		if not deepEqual(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

local function fail(message: string): never
	error(message, 3)
end

function Test.describe(name: string, define: (it: (string, () -> ()) -> ()) -> ())
	local suite: Suite = { name = name, cases = {} }
	define(function(caseName: string, fn: () -> ())
		table.insert(suite.cases, { name = caseName, fn = fn })
	end)
	table.insert(suites, suite)
end

function Test.expect(actual: any): Expectation
	return {
		toBe = function(expected: any)
			if actual ~= expected then
				fail(`ожидалось {show(expected)}, получено {show(actual)}`)
			end
		end,
		toEqual = function(expected: any)
			if not deepEqual(actual, expected) then
				fail(`ожидалось {show(expected)}, получено {show(actual)}`)
			end
		end,
		toBeCloseTo = function(expected: number, epsilon: number?)
			if type(actual) ~= "number" or math.abs(actual - expected) > (epsilon or 1e-9) then
				fail(`ожидалось ≈{expected}, получено {show(actual)}`)
			end
		end,
		toBeTruthy = function()
			if not actual then
				fail(`ожидалось истинное значение, получено {show(actual)}`)
			end
		end,
		toBeFalsy = function()
			if actual then
				fail(`ожидалось ложное значение, получено {show(actual)}`)
			end
		end,
		toBeNil = function()
			if actual ~= nil then
				fail(`ожидалось nil, получено {show(actual)}`)
			end
		end,
		toBeGreaterThan = function(bound: number)
			if not (actual > bound) then
				fail(`ожидалось > {bound}, получено {show(actual)}`)
			end
		end,
		toBeGreaterThanOrEqual = function(bound: number)
			if not (actual >= bound) then
				fail(`ожидалось ≥ {bound}, получено {show(actual)}`)
			end
		end,
		toBeLessThan = function(bound: number)
			if not (actual < bound) then
				fail(`ожидалось < {bound}, получено {show(actual)}`)
			end
		end,
		toBeLessThanOrEqual = function(bound: number)
			if not (actual <= bound) then
				fail(`ожидалось ≤ {bound}, получено {show(actual)}`)
			end
		end,
		toThrow = function(pattern: string?)
			local ok, err = pcall(actual)
			if ok then
				fail("ожидалась ошибка, но вызов прошёл успешно")
			end
			if pattern and not string.find(tostring(err), pattern, 1, true) then
				fail(`ошибка {show(tostring(err))} не содержит {show(pattern)}`)
			end
		end,
	}
end

-- Запускает все зарегистрированные тесты. Возвращает (пройдено, провалено).
function Test.run(): (number, number)
	local passed, failed = 0, 0
	for _, suite in suites do
		print(suite.name)
		for _, case in suite.cases do
			local ok, err = pcall(case.fn)
			if ok then
				passed += 1
				print(`  ✓ {case.name}`)
			else
				failed += 1
				print(`  ✗ {case.name}\n      {tostring(err)}`)
			end
		end
	end
	print(`\nИтого: {passed} пройдено, {failed} провалено`)
	return passed, failed
end

return Test
