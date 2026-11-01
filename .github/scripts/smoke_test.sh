#!/usr/bin/env bash
# Автотесты: tests/smoke_test.gd, tests/test_*.gd и замер нагрузки процессора без рендера (tests/perf.gd).
# Падает при любой ошибке скриптов или если тест не вывел «TEST OK». Импорт — import.sh (если ещё не сделан).
#   SMOKE_PART=K SMOKE_PARTS=N — только часть K из N (матрица smoke в check.yml; деление — split_tests.py по
#                                весам smoke_weights.txt); по умолчанию все тесты;
#   SMOKE_JOBS=M               — M тестов одновременно в этой задаче (у каждого потока свои user:// — XDG_*_HOME).
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/timing.sh"

# Шум фейкового рендера в headless-режиме, к игре отношения не имеет
NOISE='mesh_get_surface_count|servers/rendering/dummy|Parameter "m" is null'

"$DIR/import.sh"

PART="${SMOKE_PART:-1}"
PARTS="${SMOKE_PARTS:-1}"
JOBS="${SMOKE_JOBS:-1}"
LOGS="smoke_logs"
rm -rf "$LOGS"
mkdir -p "$LOGS"

# Один тест (имя без tests/ и .gd; perf — замер нагрузки): лог, код выхода и время — в $LOGS
run_one() {
	local name="$1" t0 code
	t0=$(date +%s)
	if [ "$name" = "perf" ]; then
		# Нагрузка скриптов без отрисовки (в headless TIME_PROCESS — только скрипты и движок, без рендера)
		timeout 600 godot --headless --path . res://tests/runner.tscn -- res://tests/perf.gd > "$LOGS/$name.log" 2>&1
	else
		timeout 600 godot --headless --fixed-fps 60 --path . res://tests/runner.tscn -- "res://tests/$name.gd" \
			> "$LOGS/$name.log" 2>&1
	fi
	code=$?
	echo "$code" > "$LOGS/$name.code"
	echo $(( $(date +%s) - t0 )) > "$LOGS/$name.time"
}

t0=$(date +%s)
mapfile -t ALL < <(python3 -I "$DIR/split_tests.py" "$PART" "$PARTS")
echo "часть $PART/$PARTS, потоков $JOBS: ${ALL[*]}"
if [ "$JOBS" -le 1 ]; then
	for name in "${ALL[@]}"; do run_one "$name"; done
else
	for j in $(seq 1 "$JOBS"); do
		(
			X="${RUNNER_TEMP:-/tmp}/smoke-xdg-$PART-$j"
			mkdir -p "$X/data" "$X/config" "$X/cache"
			export XDG_DATA_HOME="$X/data" XDG_CONFIG_HOME="$X/config" XDG_CACHE_HOME="$X/cache"
			while read -r name; do
				[ -n "$name" ] && run_one "$name"
			done < <(python3 -I "$DIR/split_tests.py" "$j" "$JOBS" --of "$PART/$PARTS")
		) &
	done
	wait
fi
t_done "автотесты, часть $PART/$PARTS (${#ALL[@]} шт., потоков $JOBS)" "$t0"

fail=0
for name in "${ALL[@]}"; do
	log="$LOGS/$name.log"
	status=$(cat "$LOGS/$name.code" 2>/dev/null || echo 255)
	secs=$(cat "$LOGS/$name.time" 2>/dev/null || echo 0)
	if [ "$name" = "perf" ]; then
		echo "===== нагрузка процессора (без рендера) ====="
		grep -E "PERF|FAIL" "$log" || tail -n 20 "$log"
		echo "ВРЕМЯ тест perf: $secs с"
		continue
	fi
	t="tests/$name.gd"
	echo "===== $t (код $status) ====="
	grep -vE "$NOISE" "$log" | tail -n 150
	# [FAIL] печатается в stderr сразу, а stdout — при выходе: в хвосте лога его может не оказаться
	grep -E "^\[FAIL\]" "$log" | head -n 20
	echo "ВРЕМЯ тест $name: $secs с"
	if grep -nE "SCRIPT ERROR|Parse Error|Compile Error|Failed to load script|Invalid call|Invalid access|Invalid assignment" "$log"; then
		echo "::error::$t: ошибки GDScript"
		fail=1
	elif [ "$status" -ne 0 ] || ! grep -q "TEST OK" "$log"; then
		echo "::error::$t: тест не прошёл"
		fail=1
	fi
done

if [ -f import.log ] && grep -nE "SCRIPT ERROR|Parse Error|Compile Error" import.log; then
	echo "::error::ошибки GDScript при импорте"
	fail=1
fi
exit $fail
