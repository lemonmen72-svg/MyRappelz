#!/usr/bin/env bash
# Замер нагрузки на настоящем рендере (вызовы отрисовки, объекты, треугольники) по пресетам качества — tests/perf.gd
# под xvfb. PERF_LEVELS=0,1 — только эти пресеты (Quality.LOW…ULTRA = 0…3; задачи perf в check.yml делят замер),
# по умолчанию все. Строки PERF — в perf.txt, лог — perf.log.
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/timing.sh"

t0=$(date +%s)
if ! command -v xvfb-run >/dev/null; then
	sudo apt-get update -qq && sudo apt-get install -y -qq xvfb libgl1-mesa-dri >/dev/null
fi
t_done "установка xvfb" "$t0"

"$DIR/import.sh"

ARGS=()
if [ -n "${PERF_LEVELS:-}" ]; then
	ARGS=(--perf-levels="$PERF_LEVELS")
fi
t0=$(date +%s)
xvfb-run -a -s "-screen 0 1280x720x24" timeout 1800 godot --rendering-driver opengl3 \
	--path . res://tests/runner.tscn -- res://tests/perf.gd "${ARGS[@]}" > perf.log 2>&1
status=$?
t_done "замер нагрузки (пресеты ${PERF_LEVELS:-все})" "$t0"
echo "===== нагрузка ====="
grep -E "PERF|FAIL|SCRIPT ERROR" perf.log || tail -n 40 perf.log
grep -E "PERF" perf.log > perf.txt || true

fail=0
if grep -nE "SHADER ERROR|Shader compilation failed|SCRIPT ERROR|Parse Error|Compile Error|Failed to load" perf.log; then
	echo "::error::ошибки шейдеров или скриптов в замере нагрузки"
	fail=1
fi
if [ "$status" -ne 0 ] || ! grep -q "TEST OK" perf.log; then
	echo "::error::замер нагрузки не прошёл (код $status)"
	fail=1
fi
exit $fail
