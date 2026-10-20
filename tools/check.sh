#!/usr/bin/env bash
# Все автоматические проверки проекта одной командой: ./tools/check.sh
# Нужны инструменты из rokit.toml (rojo, stylua, lune, luau-lsp, selene) и python3.
set -euo pipefail
cd "$(dirname "$0")/.."

DEFS=".cache/roblox.d.luau"
DEFS_URL="https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.None.d.luau"

step() { printf '\n== %s ==\n' "$1"; }

step "Форматирование (StyLua)"
# Сначала проверяем саму проверку: StyLua без поддержки Luau молча пропускает файлы .luau
# и отвечает «всё хорошо» (так уже было, см. docs/PITFALLS.md). Заведомо неотформатированный
# фрагмент Luau с шаблонной строкой обязан дать код 1.
canary_status=0
printf 'local   x =`{1}`\n' | stylua --check - > /dev/null 2>&1 || canary_status=$?
if [ "$canary_status" -ne 1 ]; then
	echo "StyLua не проверяет Luau (код $canary_status вместо 1): нужна сборка с поддержкой Luau (rokit install)"
	exit 1
fi
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
# На Windows Python обычно называется python, а python3 бывает заглушкой Microsoft Store,
# которая ничего не запускает. Поэтому берём первую команду, которая реально работает.
PYTHON=""
for candidate in python3 python; do
	if command -v "$candidate" > /dev/null 2>&1 \
		&& "$candidate" -c "import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)" > /dev/null 2>&1; then
		PYTHON="$candidate"
		break
	fi
done
if [ -z "$PYTHON" ]; then
	echo "нужен Python 3 (python3 или python)"
	exit 1
fi
"$PYTHON" tools/check_ui_props.py "$DEFS" $(grep -rl 'Ui\.\(new\|label\|button\)' src)

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
