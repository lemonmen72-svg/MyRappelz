#!/usr/bin/env bash
# Ключ кэша импорта Godot для actions/cache (пишет key и restore в $GITHUB_OUTPUT): версия Godot + хэш исходников
# ресурсов, .import, project.godot и import_cache.py — по blob-хэшам git (мгновенно, файлы не читаются).
# $1 — начало ключа (godot-import; сборка APK — godot-import-apk).
set -euo pipefail
PREFIX="${1:-godot-import}-v1-${GODOT_VERSION:-4.3}"
H=$(git ls-files -s -- project.godot '*.import' '*.png' '*.glb' '*.gltf' '*.svg' '*.jpg' '*.jpeg' '*.webp' \
	'*.wav' '*.ogg' '*.mp3' '*.ttf' '*.otf' '*.bin' '*.exr' '*.hdr' .github/scripts/import_cache.py \
	| sha256sum | cut -c1-40)
echo "ключ кэша импорта: $PREFIX-$H"
{
	echo "key=$PREFIX-$H"
	echo "restore=$PREFIX-"
} >> "${GITHUB_OUTPUT:-/dev/stdout}"
