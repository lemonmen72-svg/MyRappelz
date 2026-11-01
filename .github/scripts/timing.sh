#!/usr/bin/env bash
# Время этапов CI (подключать: . .github/scripts/timing.sh). t0=$(date +%s) … t_done "этап" "$t0" печатает
# «ВРЕМЯ этап: N с» и дописывает строку в $CI_TIMES (по умолчанию $RUNNER_TEMP/ci_times.txt) — шаг «Время этапов»
# в конце задачи печатает всё вместе.
CI_TIMES="${CI_TIMES:-${RUNNER_TEMP:-/tmp}/ci_times.txt}"

t_done() {
	local dt=$(( $(date +%s) - $2 ))
	echo "ВРЕМЯ $1: ${dt} с"
	echo "$(printf '%5d' "$dt") с  $1" >> "$CI_TIMES"
}
