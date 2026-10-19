# GOBLIT

Кооперативный dungeon crawler для Roblox: до шести игроков исследуют процедурное подземелье, сражаются, собирают перки и решают, когда уходить с добычей.

Проект разрабатывается по фазам — см. [docs/ROADMAP.md](docs/ROADMAP.md).
**Текущее состояние: фаза 1 — технический фундамент.** Сейчас в игре есть Застава (хаб) с маяком, HUD, настройки и сохранение профиля. Боя и подземелья пока нет.

## Быстрый старт

1. Установите [Rokit](https://github.com/rojo-rbx/rokit) и в папке проекта выполните:
   ```bash
   rokit install
   ```
   Это поставит версии инструментов из `rokit.toml`: Rojo, StyLua, selene, Lune, luau-lsp.
2. Установите плагин Rojo в Roblox Studio: `rojo plugin install`.
3. Соберите место и откройте его в Studio:
   ```bash
   rojo build -o GOBLIT.rbxlx
   ```
   Или работайте с синхронизацией: откройте пустое место, запустите `rojo serve` и нажмите **Rojo → Connect**.
4. Нажмите **Play**.

### Настройки места в Studio

- **Сохранение профиля.** Опубликуйте место, затем включите *Game Settings → Security → Enable Studio Access to API Services*. Без этого игра работает, но сохранение отключено, и HUD показывает это предупреждение.
- **StreamingEnabled = false.** `rojo build` выставляет это сам. При `rojo serve` в существующее место отключите вручную: *Workspace → StreamingEnabled*.
- **Shift lock.** Выключен через `StarterPlayer.EnableMouseLockOption`, потому что Shift будет клавишей уклонения.

## Проверки

```bash
./tools/check.sh
```

| Проверка | Что ловит |
|---|---|
| StyLua | форматирование |
| Lune (`tests/`) | логика и данные: генератор случайных чисел, схема профиля, целостность перков, врагов и комнат |
| luau-lsp | типы (strict) по актуальным определениям Roblox API и предупреждения линтера |
| `tools/check_ui_props.py` | опечатки в именах свойств интерфейса, которые не видит тип-чекер |
| selene | дополнительный линтер; пропускается, если не может скачать API Roblox |

Чего эти проверки **не** покрывают, и как проверять это вручную в Studio, описано в [docs/TESTING.md](docs/TESTING.md).

## Структура

```
src/
├── shared/          → ReplicatedStorage.Shared (код и данные для сервера и клиента)
│   ├── Config.luau        все числа баланса и настройки
│   ├── Constants.luau     имена атрибутов, тегов, состояний
│   ├── Definitions/       данные: перки, враги, комнаты, редкости
│   ├── Logic/             чистая логика без Roblox API (тестируется в Lune)
│   ├── Net/               реестр сетевых событий и клиентский доступ к ним
│   └── Util/              Signal, ErrorReporter
├── server/          → ServerScriptService.Server
│   ├── init.server.luau   запуск сервисов
│   ├── Net/               NetServer (лимиты, изоляция ошибок), Guard (проверка аргументов)
│   ├── Services/          PlayerData, Hero, Settings, Hub
│   └── World/             постройка мира из примитивов
└── client/          → StarterPlayerScripts.Client
    ├── init.client.luau   запуск контроллеров
    ├── Controllers/       HUD, уведомления, настройки, подсказки
    └── UI/                тема, фабрика интерфейса, масштаб
tests/               тесты Lune: lune run tests/run
tools/               check.sh и вспомогательные проверки
docs/                архитектура, тестирование, план
```

## Документация

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — устройство кода и правила
- [docs/TESTING.md](docs/TESTING.md) — автоматические проверки и ручной план для Studio
- [docs/ROADMAP.md](docs/ROADMAP.md) — фазы, статусы, риски
