-- Запуск всех тестов: `lune run tests/run`
-- Тестируется чистая логика и данные (src/shared/Logic, src/shared/Definitions, Config):
-- они не используют Roblox API. Код, работающий с экземплярами Roblox, проверяется
-- анализатором типов и вручную в Studio (см. docs/TESTING.md).

local process = require("@lune/process")
local Test = require("./lib/Test")

require("./Rng.spec")
require("./ProfileSchema.spec")
require("./DataStoreErrors.spec")
require("./SessionLock.spec")
require("./Stats.spec")
require("./Damage.spec")
require("./Definitions.spec")
require("./AttackClock.spec")
require("./EnemyBrain.spec")
require("./Leveling.spec")

local _, failed = Test.run()
process.exit(if failed > 0 then 1 else 0)
