#!/usr/bin/env bash
# Настоящий рендер (OpenGL через Mesa под xvfb): ловит ошибки шейдеров и снимает скриншоты.
set -uo pipefail

if ! command -v xvfb-run >/dev/null; then
	sudo apt-get update -qq && sudo apt-get install -y -qq xvfb libgl1-mesa-dri >/dev/null
fi

timeout 300 godot --headless --path . --import > import.log 2>&1
xvfb-run -a -s "-screen 0 1280x720x24" timeout 2700 godot --rendering-driver opengl3 --fixed-fps 30 \
	--path . res://tests/runner.tscn -- res://tests/shots.gd > shots.log 2>&1
status=$?
grep -vE 'mesh_get_surface_count|servers/rendering/dummy' shots.log | tail -n 120

# Замер нагрузки (вызовы отрисовки, объекты, треугольники) по пресетам качества
xvfb-run -a -s "-screen 0 1280x720x24" timeout 600 godot --rendering-driver opengl3 \
	--path . res://tests/runner.tscn -- res://tests/perf.gd > perf.log 2>&1
echo "===== нагрузка ====="
grep -E "PERF|FAIL|SCRIPT ERROR" perf.log || tail -n 40 perf.log
grep -E "PERF" perf.log > perf.txt || true

OUT="$HOME/.local/share/godot/app_userdata/MyRappelz/shots"
ls -la "$OUT" || true

fail=0
if grep -nE "SHADER ERROR|Shader compilation failed|SCRIPT ERROR|Parse Error|Compile Error|Failed to load" shots.log; then
	echo "::error::ошибки шейдеров или скриптов при настоящем рендере"
	fail=1
fi
if [ "$status" -ne 0 ] || ! grep -q "TEST OK" shots.log; then
	echo "::error::сценарий скриншотов не прошёл (код $status)"
	fail=1
fi
exit $fail
