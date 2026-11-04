#!/usr/bin/env bash
# Ставит Godot (headless) в CI. С аргументом "android" ещё и шаблоны экспорта Android.
set -euo pipefail

VER="${GODOT_VERSION:-4.3}"
DL="$HOME/godot-dl"
mkdir -p "$DL"
cd "$DL"

BIN="Godot_v${VER}-stable_linux.x86_64"
if [ ! -f "$BIN" ]; then
	curl -fsSL -o godot.zip "https://github.com/godotengine/godot/releases/download/${VER}-stable/${BIN}.zip"
	unzip -q -o godot.zip
	rm godot.zip
fi
# godot — в своей папке bin и в PATH следующих шагов (GITHUB_PATH): без sudo, чтобы работало и на ноутбуке
# (self-hosted исполнитель, tools/laptop/), где sudo спросил бы пароль
mkdir -p "$DL/bin"
ln -sf "$DL/$BIN" "$DL/bin/godot"
export PATH="$DL/bin:$PATH"
if [ -n "${GITHUB_PATH:-}" ]; then
	echo "$DL/bin" >> "$GITHUB_PATH"
fi
godot --version

if [ "${1:-}" = "android" ]; then
	if [ ! -f templates.tpz ]; then
		curl -fsSL -o templates.tpz "https://github.com/godotengine/godot/releases/download/${VER}-stable/Godot_v${VER}-stable_export_templates.tpz"
	fi
	TPL="$HOME/.local/share/godot/export_templates/${VER}.stable"
	mkdir -p "$TPL"
	unzip -q -o -j templates.tpz 'templates/android_*' 'templates/version.txt' -d "$TPL"
	ls -la "$TPL"
fi
