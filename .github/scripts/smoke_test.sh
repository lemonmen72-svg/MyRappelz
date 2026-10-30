#!/usr/bin/env bash
# Импорт проекта и все автотесты: tests/smoke_test.gd и tests/test_*.gd.
# Падает при любой ошибке скриптов или если тест не вывел «TEST OK».
set -uo pipefail

# Шум фейкового рендера в headless-режиме, к игре отношения не имеет
NOISE='mesh_get_surface_count|servers/rendering/dummy|Parameter "m" is null'

timeout 300 godot --headless --path . --import > import.log 2>&1
echo "import: код $?"
grep -vE "$NOISE" import.log | tail -n 40

fail=0
for t in tests/smoke_test.gd tests/test_*.gd; do
	[ -f "$t" ] || continue
	[ "$(basename "$t")" = "test_base.gd" ] && continue
	log="$(basename "$t" .gd).log"
	timeout 600 godot --headless --fixed-fps 60 --path . -s "$t" > "$log" 2>&1
	status=$?
	echo "===== $t (код $status) ====="
	grep -vE "$NOISE" "$log" | tail -n 150
	if grep -nE "SCRIPT ERROR|Parse Error|Compile Error|Failed to load script|Invalid call|Invalid access|Invalid assignment" "$log"; then
		echo "::error::$t: ошибки GDScript"
		fail=1
	elif [ "$status" -ne 0 ] || ! grep -q "TEST OK" "$log"; then
		echo "::error::$t: тест не прошёл"
		fail=1
	fi
done
if grep -nE "SCRIPT ERROR|Parse Error|Compile Error" import.log; then
	echo "::error::ошибки GDScript при импорте"
	fail=1
fi
exit $fail
