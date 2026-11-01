#!/usr/bin/env bash
# Импорт проекта Godot (godot --headless --import) с кэшем .godot/imported (actions/cache в workflow, ключ —
# версия Godot и хэш исходников и .import; import_cache.py отсекает устаревшее). Лог — import.log в корне проекта.
# Ошибки GDScript при импорте проверяет smoke_test.sh (как раньше — после тестов). Повторный вызов в той же
# задаче ничего не делает (GODOT_IMPORTED=1).
set -uo pipefail
. "$(dirname "$0")/timing.sh"

if [ "${GODOT_IMPORTED:-}" = "1" ]; then
	echo "импорт уже сделан в этой задаче"
	exit 0
fi
NOISE='mesh_get_surface_count|servers/rendering/dummy|Parameter "m" is null'

t0=$(date +%s)
python3 -I .github/scripts/import_cache.py restore
touch "${RUNNER_TEMP:-/tmp}/import_mark"
timeout 900 godot --headless --path . --import > import.log 2>&1
code=$?
echo "import: код $code"
grep -vE "$NOISE" import.log | tail -n 40
n=$(find .godot/imported -name '*.md5' -newer "${RUNNER_TEMP:-/tmp}/import_mark" 2>/dev/null | wc -l)
echo "импортировано заново: $n файлов"
python3 -I .github/scripts/import_cache.py save
t_done "импорт Godot ($n файлов заново)" "$t0"

if [ -n "${GITHUB_ENV:-}" ]; then
	echo "GODOT_IMPORTED=1" >> "$GITHUB_ENV"
fi
exit 0
