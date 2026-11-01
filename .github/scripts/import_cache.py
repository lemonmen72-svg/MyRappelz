#!/usr/bin/env python3
"""Кэш импорта Godot в CI (.godot/imported между запусками через actions/cache) — без устаревших результатов.

Как Godot 4.3 решает, импортировать ли файл заново (EditorFileSystem::_test_for_reimport): нет <файл>.import,
нет результата из [remap] path*, нет .godot/imported/<имя>-<md5 пути>.md5, не совпал md5 исходника (source_md5)
или md5 результатов (dest_md5) — импорт заново; иначе файл пропускается. Изменённые исходники Godot находит сам.
Чего он НЕ видит: правку параметров в .import (например animation/fps) при том же исходнике. Поэтому:
  restore (до godot --import): из кэша возвращаются .import, которых нет в git (Godot создаёт их сам — без них
      он импортировал бы такие файлы каждый раз); у каждого .import, чьё содержимое не совпало с записанным при
      сохранении кэша (или кэш без записи), удаляется .md5 — Godot импортирует его заново.
  save (после godot --import): запись содержимого .import (у файлов из git — как до импорта, Godot может их
      переписать), копии созданных Godot .import, удаление результатов исходников, которых больше нет.
Файлы кэша (пути actions/cache): .godot/imported, .godot/ci_import_state.json, .godot/ci_import_files.
Запуск из корня проекта: python3 -I .github/scripts/import_cache.py restore|save
"""
import hashlib
import json
import os
import re
import shutil
import sys

IMPORTED = os.path.join(".godot", "imported")
STATE = os.path.join(".godot", "ci_import_state.json")
SAVED = os.path.join(".godot", "ci_import_files")
# Не из кэша: .import, которые были в рабочей копии до восстановления (из git), и их содержимое
PRE = os.path.join(".godot", "ci_import_pre.json")
STATE_VERSION = 1
NAME_RE = re.compile(r"^(.+)-([0-9a-f]{32})\.")


def walk_imports():
	"""Все <файл>.import проекта (как видит Godot: без папок с точкой и папок с .gdignore) → относительные пути."""
	out = []
	for root, dirs, files in os.walk("."):
		dirs[:] = sorted(d for d in dirs if not d.startswith(".") and not os.path.exists(os.path.join(root, d, ".gdignore")))
		for f in sorted(files):
			if f.endswith(".import"):
				out.append(os.path.relpath(os.path.join(root, f), ".").replace(os.sep, "/"))
	return out


def digest(path):
	with open(path, "rb") as f:
		return hashlib.sha256(f.read()).hexdigest()


def md5_file_of(source_rel):
	"""Файл .md5 импорта исходника (ResourceFormatImporter::get_import_base_path: имя-md5("res://путь"))."""
	h = hashlib.md5(("res://" + source_rel).encode("utf-8")).hexdigest()
	return os.path.join(IMPORTED, os.path.basename(source_rel) + "-" + h + ".md5")


def load_json(path):
	try:
		with open(path, encoding="utf-8") as f:
			return json.load(f)
	except (OSError, ValueError):
		return None


def restore():
	# Созданные Godot .import из кэша — туда, где их нет, а исходник есть (файлы из git не трогаются)
	tracked = walk_imports()
	back = 0
	if os.path.isdir(SAVED):
		for root, _dirs, files in os.walk(SAVED):
			for f in files:
				src = os.path.join(root, f)
				rel = os.path.relpath(src, SAVED)
				if rel.endswith(".import") and not os.path.exists(rel) and os.path.isfile(rel[:-len(".import")]):
					shutil.copy2(src, rel)
					back += 1
	cur = {p: digest(p) for p in walk_imports()}
	os.makedirs(".godot", exist_ok=True)
	with open(PRE, "w", encoding="utf-8") as f:
		json.dump({"tracked": {p: cur[p] for p in tracked}}, f)
	if not os.path.isdir(IMPORTED):
		print("кэш импорта: нет — импорт целиком")
		return
	state = load_json(STATE)
	if not isinstance(state, dict) or state.get("version") != STATE_VERSION or not isinstance(state.get("files"), dict):
		n = 0
		for f in os.listdir(IMPORTED):
			if f.endswith(".md5"):
				os.remove(os.path.join(IMPORTED, f))
				n += 1
		print("кэш импорта: без записи .import — импорт целиком (сброшено %d)" % n)
		return
	files = state["files"]
	reset = 0
	for p, h in cur.items():
		if files.get(p) != h:
			m = md5_file_of(p[:-len(".import")])
			if os.path.exists(m):
				os.remove(m)
			reset += 1
	print("кэш импорта: восстановлено созданных Godot .import — %d, .import изменились (импорт заново) — %d из %d" % (
		back, reset, len(cur)))


def save():
	pre = load_json(PRE) or {}
	tracked = pre.get("tracked", {}) if isinstance(pre, dict) else {}
	if os.path.isdir(SAVED):
		shutil.rmtree(SAVED)
	files = {}
	copied = 0
	for p in walk_imports():
		if p in tracked:
			files[p] = tracked[p]
			continue
		files[p] = digest(p)
		dst = os.path.join(SAVED, p)
		os.makedirs(os.path.dirname(dst) or ".", exist_ok=True)
		shutil.copy2(p, dst)
		copied += 1
	os.makedirs(".godot", exist_ok=True)
	with open(STATE, "w", encoding="utf-8") as f:
		json.dump({"version": STATE_VERSION, "files": files}, f, sort_keys=True)
	# Результаты исходников, которых больше нет (имя-md5 пути не совпадает ни с одним .import), — из кэша вон
	known = set()
	for p in files:
		src = p[:-len(".import")]
		known.add((os.path.basename(src), hashlib.md5(("res://" + src).encode("utf-8")).hexdigest()))
	pruned = 0
	if os.path.isdir(IMPORTED):
		for f in os.listdir(IMPORTED):
			m = NAME_RE.match(f)
			if m and (m.group(1), m.group(2)) not in known:
				os.remove(os.path.join(IMPORTED, f))
				pruned += 1
	size = 0
	if os.path.isdir(IMPORTED):
		for f in os.listdir(IMPORTED):
			size += os.path.getsize(os.path.join(IMPORTED, f))
	print("кэш импорта: записано .import — %d (созданных Godot — %d), удалено лишних результатов — %d, .godot/imported %.0f МБ" % (
		len(files), copied, pruned, size / 1e6))


if __name__ == "__main__":
	cmd = sys.argv[1] if len(sys.argv) > 1 else ""
	if cmd == "restore":
		restore()
	elif cmd == "save":
		save()
	else:
		print(__doc__)
		sys.exit(2)
