# Настройка компьютера для GOBLIT (Windows)

Как подготовить компьютер, чтобы Claude работал прямо рядом с Roblox Studio: запускал игру, читал Output и делал скриншоты.

Облачная сессия Claude не может достучаться до компьютера, поэтому работа со Studio идёт в сессии Claude Code, запущенной на этом компьютере в папке проекта. Код по-прежнему хранится в Git: его меняют в файлах, а в Studio переносит Rojo.

Команды проверены по официальной документации 20.10.2026.

## Что уже сделано (20.10.2026)

| Шаг | Команда | Результат |
|---|---|---|
| Git | `winget install --id Git.Git -e --source winget` | git 2.55.0 |
| Claude Code | `irm https://claude.ai/install.ps1 \| iex` | 2.1.304 |
| Путь к Claude Code | см. ниже | `claude --version` работает |
| Проект | `git clone https://github.com/9lobal13t/GOBLIT.git` | `C:\Users\User\GOBLIT` |
| Плагин в Studio | `Chrrxs/robloxstudio-mcp` 3.3.0 | был установлен раньше |

Установщик Claude Code сам не добавляет программу в PATH. Это делается один раз:

```powershell
$currentPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
[Environment]::SetEnvironmentVariable('PATH', "$currentPath;$env:USERPROFILE\.local\bin", 'User')
```

После этого откройте PowerShell заново. Обновить путь в уже открытом окне можно так:

```powershell
$env:PATH = [Environment]::GetEnvironmentVariable('PATH','Machine') + ';' + [Environment]::GetEnvironmentVariable('PATH','User')
```

PowerShell запускайте обычный, **не от администратора**. Строка должна начинаться с `PS C:\Users\User>`.

## Подключение Studio к Claude Code

Используется плагин [Chrrxs/robloxstudio-mcp](https://github.com/Chrrxs/robloxstudio-mcp): он умеет запускать игру (соло и на нескольких игроков), читать Output, делать скриншоты, в том числе сразу на нескольких эмулированных устройствах.

1. Нужен Node.js 22 или новее. Проверка: `node --version`. Установка: `winget install OpenJS.NodeJS.LTS`.
2. В папке проекта выполните:
   ```powershell
   claude mcp add robloxstudio -- npx -y @chrrxs/robloxstudio-mcp@3.3.0 --auto-install-plugin
   ```
   Версия закреплена (`@3.3.0`, а не `@latest`), чтобы сервер и плагин в Studio не разъезжались после каждого обновления. Чтобы обновиться, удалите сервер (`claude mcp remove robloxstudio`), добавьте его с новой версией и полностью перезапустите Studio.
3. Полностью закройте и снова откройте Studio. Плагин должен показать **Connected**.
4. Закройте другие программы, которые подключались к этому плагину (Claude Desktop, Cursor и т. п.), чтобы они не спорили за одно подключение.
5. Запустите `claude` в папке проекта и проверьте связь командой `/mcp`.

## Правило: Studio — только для проверки

Файл `.claude/settings.json` в репозитории **запрещает** инструменты, которые меняют скрипты прямо в Studio, а также монетизацию и загрузку ассетов:
`set_script_source`, `edit_script_lines`, `insert_script_lines`, `delete_script_lines`, `find_and_replace_in_scripts`, `manage_monetization`, `upload_asset`.

Причина: правки, сделанные в Studio, не попадают в Git, и Rojo их перезапишет. Код меняется в файлах → коммит → Rojo переносит его в Studio.

Ключ Open Cloud и cookie `.ROBLOSECURITY` никогда не передаются ИИ.

## Rojo (следующий шаг)

1. Rokit:
   ```powershell
   Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression
   ```
2. В папке проекта: `rokit install` (поставит Rojo и инструменты из `rokit.toml`).
3. `rojo plugin install` — плагин Rojo для Studio.
4. Открыть место в Studio. Удобнее всего собрать его командой `rojo build -o GOBLIT.rbxlx` и открыть файл. Затем выполнить `rojo serve` и нажать в Studio **Rojo → Connect**.

## Управление с телефона (по желанию)

В папке проекта выполните `claude remote-control --name "GOBLIT"`. Сессия появится в приложении Claude (раздел Code). Компьютер при этом должен быть включён, а окно терминала — открыто.
