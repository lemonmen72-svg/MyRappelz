#!/usr/bin/env bash
# Настоящий рендер (OpenGL через Mesa под xvfb): ловит ошибки шейдеров и снимает скриншоты.
# SHOTS_PART=K SHOTS_PARTS=N — только часть K из N сценария tests/shots.gd (матрица visual в check.yml; деление —
# PART_ENTRIES в shots.gd); по умолчанию вся цепочка. PNG — в user://shots/, лог — shots.log.
# Замер нагрузки (tests/perf.gd) — отдельно, perf.sh.
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/timing.sh"

t0=$(date +%s)
if ! command -v xvfb-run >/dev/null; then
	sudo apt-get update -qq && sudo apt-get install -y -qq xvfb libgl1-mesa-dri >/dev/null
fi
t_done "установка xvfb" "$t0"

"$DIR/import.sh"

PART="${SHOTS_PART:-1}"
PARTS="${SHOTS_PARTS:-1}"
ARGS=()
if [ "$PARTS" -gt 1 ]; then
	ARGS=(--shots-part="$PART" --shots-parts="$PARTS")
fi
t0=$(date +%s)
xvfb-run -a -s "-screen 0 1280x720x24" timeout 4200 godot --rendering-method gl_compatibility --rendering-driver opengl3 --fixed-fps 30 \
	--path . res://tests/runner.tscn -- res://tests/shots.gd "${ARGS[@]}" > shots.log 2>&1
status=$?
t_done "скриншоты, часть $PART/$PARTS" "$t0"
grep -vE 'mesh_get_surface_count|servers/rendering/dummy' shots.log | tail -n 120

OUT="$HOME/.local/share/godot/app_userdata/MyRappelz/shots"
ls -la "$OUT" || true

fail=0
if grep -nE "SHADER ERROR|Shader compilation failed|SCRIPT ERROR|Parse Error|Compile Error|Failed to load" shots.log; then
	echo "::error::ошибки шейдеров или скриптов при настоящем рендере (часть $PART/$PARTS)"
	fail=1
fi
if [ "$status" -ne 0 ] || ! grep -q "TEST OK" shots.log; then
	grep -E "^\[FAIL\]" shots.log | head -n 20
	echo "::error::сценарий скриншотов не прошёл (часть $PART/$PARTS, код $status)"
	fail=1
fi
exit $fail
