#!/usr/bin/env bash
# Импорт проекта и автотест tests/smoke_test.gd. Падает при любой ошибке скриптов.
set -uo pipefail

# Шум фейкового рендера в headless-режиме, к игре отношения не имеет
NOISE='mesh_get_surface_count|servers/rendering/dummy|Parameter "m" is null'

timeout 300 godot --headless --path . --import > import.log 2>&1
echo "import: код $?"
timeout 600 godot --headless --fixed-fps 60 --path . -s tests/smoke_test.gd > smoke.log 2>&1
status=$?

grep -vE "$NOISE" import.log | tail -n 60
echo "===== автотест ====="
grep -vE "$NOISE" smoke.log | tail -n 150

if grep -nE "SCRIPT ERROR|Parse Error|Compile Error|Failed to load script|Invalid call|Invalid access|Invalid assignment" import.log smoke.log; then
	echo "::error::Найдены ошибки GDScript"
	exit 1
fi
if [ "$status" -ne 0 ] || ! grep -q "SMOKE TEST OK" smoke.log; then
	echo "::error::Автотест не прошёл (код $status)"
	exit 1
fi
