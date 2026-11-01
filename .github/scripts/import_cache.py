#!/usr/bin/env python3
"""Кэш импорта Godot в CI (.godot/imported между запусками через actions/cache) — без устаревших результатов.

Как Godot 4.3 решает, импортировать ли файл (editor/editor_file_system.cpp, первый скан при --import):
  * есть запись в .godot/editor/filesystem_cache8 и время изменения исходника и его .import совпадает с записью —
    файл пропускается, если цел .import, есть .md5 и результаты (_test_for_reimport(path, true));
  * иначе — проверка по md5 (_test_for_reimport(path, false)), НО в 4.3 после неё ещё сверяется время .import с
    записью кэша (обход GH-94416): без записи оно 0 — импорт заново. Поэтому после git checkout (новое время файлов)
    Godot импортировал ВСЁ, даже из полного кэша .godot/imported (665 файлов, ≈65 с).
Что делает скрипт:
  restore (до godot --import):
    1. .import из кэша (копии после прошлого импорта): созданные Godot (их нет в git) — туда, где их нет; файлы из git
       — только если в рабочей копии та же версия, из которой Godot сделал копию (тот же исходный .import из git);
    2. у .import, чьё содержимое не совпало с оставленным Godot при сохранении кэша, удаляется .md5 — импорт заново
       (Godot не видит правку параметров .import при том же исходнике);
    3. исходнику и его .import, которые точно не менялись (.import — как оставил Godot, md5 исходника — как в его .md5),
       возвращается время изменения из filesystem_cache8 — Godot пропускает их без импорта. Изменённые (другое
       содержимое) — с временем checkout: Godot проверит их сам и импортирует заново.
  save (после godot --import): содержимое .import (из git — до импорта и после), копии всех .import после импорта,
    удаление результатов исходников, которых больше нет.
Файлы кэша (пути actions/cache): .godot/imported, .godot/editor/filesystem_cache8, .godot/ci_import_state.json,
.godot/ci_import_files. Запуск из корня проекта: python3 -I .github/scripts/import_cache.py restore|save
"""
import hashlib
import json
import os
import re
import shutil
import sys

IMPORTED = os.path.join(".godot", "imported")
FS_CACHE = os.path.join(".godot", "editor", "filesystem_cache8")
STATE = os.path.join(".godot", "ci_import_state.json")
SAVED = os.path.join(".godot", "ci_import_files")
# Не из кэша: .import, которые были в рабочей копии до восстановления (из git), и их содержимое
PRE = os.path.join(".godot", "ci_import_pre.json")
STATE_VERSION = 2
NAME_RE = re.compile(r"^(.+)-([0-9a-f]{32})\.")
MD5_RE = re.compile(r'^source_md5="([0-9a-f]*)"', re.M)


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


def md5_of(path):
	h = hashlib.md5()
	with open(path, "rb") as f:
		for chunk in iter(lambda: f.read(1 << 20), b""):
			h.update(chunk)
	return h.hexdigest()


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


def fs_cache_times():
	"""filesystem_cache8: {относительный путь: (время исходника, время .import)}."""
	out = {}
	try:
		lines = open(FS_CACHE, encoding="utf-8").read().split("\n")
	except OSError:
		return out
	cdir = ""
	for line in lines[1:]:
		line = line.strip()
		if not line:
			continue
		if line.startswith("::"):
			parts = line.split("::")
			if len(parts) == 3:
				cdir = parts[1]
			continue
		parts = line.split("::", 8)
		if len(parts) < 9 or not cdir.startswith("res://"):
			continue
		rel = (cdir[len("res://"):].rstrip("/") + "/" + parts[0]).lstrip("/")
		try:
			out[rel] = (int(parts[3]), int(parts[4]))
		except ValueError:
			pass
	return out


def reset_all(why):
	n = 0
	for f in os.listdir(IMPORTED):
		if f.endswith(".md5"):
			os.remove(os.path.join(IMPORTED, f))
			n += 1
	if os.path.exists(FS_CACHE):
		os.remove(FS_CACHE)
	print("кэш импорта: %s — импорт целиком (сброшено %d)" % (why, n))


def restore():
	tracked = {p: digest(p) for p in walk_imports()}
	os.makedirs(".godot", exist_ok=True)
	with open(PRE, "w", encoding="utf-8") as f:
		json.dump({"tracked": tracked}, f)
	if not os.path.isdir(IMPORTED):
		print("кэш импорта: нет — импорт целиком")
		return
	state = load_json(STATE)
	if not isinstance(state, dict) or state.get("version") != STATE_VERSION or not isinstance(state.get("files"), dict):
		reset_all("без записи .import этой версии")
		return
	files = state["files"]
	# 1. .import из кэша
	back = 0
	for p, rec in files.items():
		src = os.path.join(SAVED, p)
		if not os.path.isfile(src) or not os.path.isfile(p[:-len(".import")]):
			continue
		if p not in tracked or tracked[p] == rec.get("pre"):
			if not os.path.exists(p) or digest(p) != rec.get("post"):
				shutil.copy2(src, p)
				back += 1
	# 2. изменённые .import — импорт заново; 3. неизменные файлы — время изменения из filesystem_cache8
	times = fs_cache_times()
	reset = 0
	same = 0
	cur = walk_imports()
	for p in cur:
		source = p[:-len(".import")]
		rec = files.get(p) or {}
		m = md5_file_of(source)
		if digest(p) != rec.get("post"):
			if os.path.exists(m):
				os.remove(m)
			reset += 1
			continue
		t = times.get(source)
		if t is None or not os.path.isfile(m) or not os.path.isfile(source):
			continue
		found = MD5_RE.search(open(m, encoding="utf-8", errors="replace").read())
		if found is None or found.group(1) != md5_of(source):
			continue
		os.utime(source, (t[0], t[0]))
		os.utime(p, (t[1], t[1]))
		same += 1
	print("кэш импорта: возвращено .import — %d, изменились (импорт заново) — %d, не менялись (без импорта) — %d из %d" % (
		back, reset, same, len(cur)))


def save():
	pre = load_json(PRE) or {}
	tracked = pre.get("tracked", {}) if isinstance(pre, dict) else {}
	if os.path.isdir(SAVED):
		shutil.rmtree(SAVED)
	files = {}
	for p in walk_imports():
		files[p] = {"pre": tracked.get(p), "post": digest(p)}
		dst = os.path.join(SAVED, p)
		os.makedirs(os.path.dirname(dst) or ".", exist_ok=True)
		shutil.copy2(p, dst)
	os.makedirs(".godot", exist_ok=True)
	with open(STATE, "w", encoding="utf-8") as f:
		json.dump({"version": STATE_VERSION, "files": files}, f, sort_keys=True)
	rewritten = sum(1 for p, r in files.items() if r["pre"] is not None and r["pre"] != r["post"])
	# Результаты исходников, которых больше нет (имя-md5 пути не совпадает ни с одним .import), — из кэша вон
	known = set()
	for p in files:
		src = p[:-len(".import")]
		known.add((os.path.basename(src), hashlib.md5(("res://" + src).encode("utf-8")).hexdigest()))
	pruned = 0
	size = 0
	if os.path.isdir(IMPORTED):
		for f in os.listdir(IMPORTED):
			m = NAME_RE.match(f)
			if m and (m.group(1), m.group(2)) not in known:
				os.remove(os.path.join(IMPORTED, f))
				pruned += 1
			else:
				size += os.path.getsize(os.path.join(IMPORTED, f))
	print("кэш импорта: записано .import — %d (из git — %d, Godot переписал из них — %d), удалено лишних результатов — %d, "
		".godot/imported %.0f МБ, filesystem_cache8 %s" % (len(files), len(tracked), rewritten, pruned, size / 1e6,
		"есть" if os.path.isfile(FS_CACHE) else "нет"))


if __name__ == "__main__":
	cmd = sys.argv[1] if len(sys.argv) > 1 else ""
	if cmd == "restore":
		restore()
	elif cmd == "save":
		save()
	else:
		print(__doc__)
		sys.exit(2)
