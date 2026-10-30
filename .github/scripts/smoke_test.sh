#!/usr/bin/env bash
# Импорт проекта и автотест tests/smoke_test.gd. Падает при любой ошибке скриптов.
set -uo pipefail

timeout 300 godot --headless --path . --import 2>&1 | tee import.log
timeout 600 godot --headless --fixed-fps 60 --path . -s tests/smoke_test.gd 2>&1 | tee smoke.log
status=${PIPESTATUS[0]}

if grep -nE "SCRIPT ERROR|Parse Error|Compile Error|Failed to load script|Invalid call|Invalid access|Invalid assignment" import.log smoke.log; then
	echo "::error::Найдены ошибки GDScript"
	exit 1
fi
if [ "$status" -ne 0 ] || ! grep -q "SMOKE TEST OK" smoke.log; then
	echo "::error::Автотест не прошёл (код $status)"
	exit 1
fi
