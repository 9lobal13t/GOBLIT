#!/usr/bin/env bash
# Все автоматические проверки проекта одной командой: ./tools/check.sh
# Нужны инструменты из rokit.toml (rojo, stylua, lune, luau-lsp, selene) и python3.
set -euo pipefail
cd "$(dirname "$0")/.."

DEFS=".cache/roblox.d.luau"
DEFS_URL="https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.None.d.luau"

step() { printf '\n== %s ==\n' "$1"; }

step "Форматирование (StyLua)"
stylua --check src tests
echo "ok"

step "Тесты логики и данных (Lune)"
lune run tests/run

step "Определения Roblox API"
if [ ! -f "$DEFS" ]; then
	mkdir -p .cache
	curl -fsSL "$DEFS_URL" -o "$DEFS"
	echo "загружены в $DEFS"
else
	echo "из кеша $DEFS (удалите файл, чтобы обновить)"
fi

step "Типы и линтер Luau (luau-lsp)"
rojo sourcemap default.project.json -o sourcemap.json > /dev/null
analysis=$(luau-lsp analyze --platform=roblox --definitions=@roblox="$DEFS" --sourcemap=sourcemap.json src 2>&1 \
	| grep -v '^\[INFO\]' | grep -v '^\[WARN\] client does not allow' || true)
if [ -n "$analysis" ]; then
	echo "$analysis"
	exit 1
fi
echo "ошибок и предупреждений нет"

step "Имена свойств интерфейса"
python3 tools/check_ui_props.py "$DEFS" $(grep -rl 'Ui\.\(new\|label\|button\)' src)

step "Линтер (selene)"
if ! selene_output=$(selene src 2>&1); then
	if grep -q "Could not collect standard library" <<< "$selene_output"; then
		echo "ПРОПУЩЕНО: selene не смог загрузить стандартную библиотеку Roblox (нет доступа к сети?)"
	else
		echo "$selene_output"
		exit 1
	fi
else
	echo "$selene_output"
fi

printf '\nВсе проверки пройдены.\n'
