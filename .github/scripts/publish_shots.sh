#!/usr/bin/env bash
# Публикация скриншотов в ветку ci-screenshots (задача shots-publish в check.yml): собирает артефакты частей
# shots-part-K (PNG, shots.log) и замера perf-* (perf.txt) из $1 (по умолчанию $RUNNER_TEMP/art).
# FULL=true — сняты все части: ветка с нуля (как раньше). Иначе (ручной запуск с частью частей) — поверх прежней
# ветки: кадры перезапущенных частей заменяются (список кадров части — parts/part-K.txt), остальные остаются.
# README.md — все кадры по частям, у каждой части — коммит, с которого она снята.
set -euo pipefail
ART="${1:-$RUNNER_TEMP/art}"
OUT="$RUNNER_TEMP/shots-branch"
REMOTE="https://x-access-token:${TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
SHA="${GITHUB_SHA}"
rm -rf "$OUT"

if [ "${FULL:-true}" != "true" ] && git clone -q --depth 1 -b ci-screenshots "$REMOTE" "$OUT" 2>/dev/null; then
	rm -rf "$OUT/.git"
	echo "часть частей: поверх прежней ветки ci-screenshots"
else
	mkdir -p "$OUT"
fi
mkdir -p "$OUT/parts"

shopt -s nullglob
n=0
for d in "$ART"/shots-part-*; do
	[ -d "$d" ] || continue
	k="${d##*shots-part-}"
	man="$OUT/parts/part-$k.txt"
	if [ -f "$man" ]; then
		while read -r f; do
			case "$f" in "#"*|"") ;; *) rm -f "$OUT/$f" ;; esac
		done < "$man"
	fi
	{
		echo "# commit $SHA"
		for f in "$d"/*.png; do basename "$f"; done
	} > "$man"
	for f in "$d"/*.png; do cp "$f" "$OUT/"; n=$((n + 1)); done
	if [ -f "$d/shots.log" ]; then
		cp "$d/shots.log" "$OUT/shots-$k.log"
	fi
done
echo "кадров из этого запуска: $n"

perf=("$ART"/perf-*/perf.txt)
if [ ${#perf[@]} -gt 0 ]; then
	cat "${perf[@]}" > "$OUT/perf.txt"
fi

cd "$OUT"
{
	echo "# Скриншоты CI"
	echo
	echo "Запуск: коммит \`${SHA}\`, ветка \`${GITHUB_REF_NAME}\`."
	listed=" "
	for man in $(ls parts/part-*.txt 2>/dev/null | sort -t- -k2 -n); do
		k="${man##*part-}"
		k="${k%.txt}"
		c=$(sed -n 's/^# commit //p' "$man" | head -n 1)
		echo
		echo "## Часть $k (коммит \`$c\`)"
		echo
		while read -r f; do
			case "$f" in "#"*|"") continue ;; esac
			[ -f "$f" ] || continue
			listed="$listed$f "
			echo "### $f"; echo; echo "![$f]($f)"; echo
		done < "$man"
	done
	rest=""
	for f in *.png; do
		case "$listed" in *" $f "*) ;; *) rest="$rest $f" ;; esac
	done
	if [ -n "$rest" ]; then
		echo
		echo "## Без части (из прежних запусков)"
		echo
		for f in $rest; do echo "### $f"; echo; echo "![$f]($f)"; echo; done
	fi
} > README.md

git init -q -b ci-screenshots
git add -A
git -c user.name="CI" -c user.email="ci@users.noreply.github.com" commit -qm "Скриншоты ${SHA}"
git push -qf "$REMOTE" ci-screenshots
