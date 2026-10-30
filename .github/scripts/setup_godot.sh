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
sudo ln -sf "$DL/$BIN" /usr/local/bin/godot
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
