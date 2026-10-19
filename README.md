# GOBLIT

Игра для Roblox. Код пишется в обычном редакторе (VS Code) на **Luau** и синхронизируется в Roblox Studio через **[Rojo](https://rojo.space)**.

## Структура

```
src/
├── server/                  → ServerScriptService.Server
│   ├── init.server.luau     точка входа сервера
│   └── Services/
│       ├── DataService.luau сохранение данных игроков (DataStore, ретраи, BindToClose)
│       └── CoinService.luau пример механики: монеты + leaderstats
├── client/                  → StarterPlayerScripts.Client
│   ├── init.client.luau     точка входа клиента
│   └── Controllers/
│       └── HudController.luau  HUD со счётчиком монет
└── shared/                  → ReplicatedStorage.Shared
    ├── Config.luau          игровые константы
    └── Remotes.luau         RemoteEvent'ы
```

Принцип: вся игровая логика и валюта — **на сервере**, клиент только отображает. Клиенту доверять нельзя.

## Быстрый старт

1. Установите [Rokit](https://github.com/rojo-rbx/rokit) и выполните в папке проекта:
   ```bash
   rokit install
   ```
2. Установите плагин Rojo в Roblox Studio (Plugins → Manage Plugins или `rojo plugin install`).
3. Запустите сервер синхронизации:
   ```bash
   rojo serve
   ```
4. В Studio откройте место, нажмите **Rojo → Connect**.
5. Для работы DataStore в Studio: *Game Settings → Security → Enable Studio Access to API Services* (место должно быть опубликовано).

Собрать файл места без Studio: `rojo build -o GOBLIT.rbxl`.

## Качество кода

```bash
selene src        # линтер
stylua src        # форматирование
```
