#!/usr/bin/env python3
# Раскадровки эффектов (flipbook, 0.46.1) для генератора VFX: листы Максима из ChatGPT — одна анимация эффекта сеткой
# 4×4 (или 3×3) кадров, белым по чёрному (промты — tools/Промты_раскадровки_эффектов.docx, какой файл каким эффектом
# стал — tools/flipbook_sources.txt) → vfx/flip/fx_<id>[_N].png и vfx/flip/flipbooks.json.
# Лист в игре: та же сетка кадров по CELL px, яркость — оттенки серого (PNG L8; чёрное — пусто). Импорт Godot «Image»:
# в пакете ресурсов лежит сам PNG, игра раскодирует его в фоне (VfxFlip) — в видеопамяти 1 байт на пиксель.
# Яркость листа растягивается на весь диапазон (самое яркое — 1), край кадра гаснет (EDGE — на мипмапах не видно
# соседних кадров), шум фона — в ноль (FLOOR).
# flipbooks.json: {format, cell, sheets: {id: {title, order, kind (once/loop), view, files: [{file, src, view, grid,
# frames, pivot [x, y], hot [x, y], peak, loop [a, b], energy [по кадрам]}]}}}. Опора pivot (доли кадра от левого
# верхнего угла): «сбоку» — середина низа эффекта (там земля), остальные виды — центр кадра; hot — самое яркое место
# пиковых кадров (вспышка укола, точка, откуда идёт рёв). Петля «loop» — самые яркие кадры подряд (ChatGPT рисует
# «петлю» как рост, пик и угасание: начало и конец листа — вступление и затухание).
# Запуск из корня: python3 -I tools/prepare_flipbook.py --src <папка с листами> [--only id,…] [--preview <папка>]
#   --check — проверить готовые vfx/flip (файлы, размеры, метаданные), ничего не писать.
import argparse
import ast
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "vfx", "flip")
META = os.path.join(OUT, "flipbooks.json")
DOC = os.path.join(ROOT, "tools", "make_vfx_flipbook_doc.py")
SOURCES = os.path.join(ROOT, "tools", "flipbook_sources.txt")
CELL = 256
EDGE = 0.02
FLOOR = 0.015
WHITE_PCT = 99.9
LOOP_KEEP = 0.72
GROUND_FROM = 0.6
GROUND_LIT = 0.06
GROUND_WIDE = 0.9
VIEWS = ("front", "right", "left", "top", "side", "head")

IMPORT = """[remap]

importer="image"
type="Image"

[deps]

source_file="res://%s"

[params]

"""


def rel(path):
	return os.path.relpath(path, ROOT).replace(os.sep, "/")


def doc_specs():
	"""Промты документа: id → {title, prio, view, kind, order} (GROUPS из make_vfx_flipbook_doc.py без python-docx)."""
	tree = ast.parse(open(DOC, encoding="utf-8").read())
	for node in tree.body:
		if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == "GROUPS" for t in node.targets):
			out = {}
			order = 0
			for _gname, _gnote, items in ast.literal_eval(node.value):
				for e in items:
					order += 1
					out[e[0]] = {"title": e[1], "prio": e[2], "view": e[3], "kind": e[4], "order": order}
			return out
	sys.exit("в %s нет GROUPS" % DOC)


def read_sources():
	"""Строки tools/flipbook_sources.txt: [(имя файла, ключ id[_N], вид или "", земля или None)]. После id —
	вид (front, side, …) и/или высота земли у вида «сбоку» (доля кадра сверху, например 0.78), если её не угадать."""
	out = []
	with open(SOURCES, encoding="utf-8") as f:
		for line in f:
			line = line.split("#", 1)[0].strip()
			if not line:
				continue
			p = line.split()
			if len(p) < 2:
				sys.exit("%s: строка без id: %s" % (SOURCES, line))
			view = ""
			ground = None
			for t in p[2:]:
				if t in VIEWS:
					view = t
				else:
					try:
						ground = float(t)
					except ValueError:
						sys.exit("%s: «%s» — не вид (%s) и не высота земли" % (SOURCES, t, ", ".join(VIEWS)))
			out.append((p[0], p[1], view, ground))
	return out


def split_key(key, specs):
	"""fx-ключ «blessing_2» → ("blessing", 2); «blessing» → ("blessing", 1)."""
	if key in specs:
		return key, 1
	base, _, n = key.rpartition("_")
	if base in specs and n.isdigit():
		return base, int(n)
	sys.exit("неизвестный эффект «%s»: нет такого промта в %s" % (key, rel(DOC)))


def load_lum(path):
	a = np.asarray(Image.open(path).convert("RGB")).astype(np.float32) / 255.0
	return a.max(axis=2)


def grid_of(L):
	"""4×4 или 3×3: у верной сетки линии между кадрами — тёмные промежутки."""
	H, W = L.shape
	best = None
	for k in (4, 3):
		band = max(2, int(W * 0.01))
		s = 0.0
		for i in range(1, k):
			x = int(round(W * i / k))
			y = int(round(H * i / k))
			s += L[:, x - band:x + band].mean() + L[y - band:y + band, :].mean()
		s /= 2 * (k - 1)
		if best is None or s < best[1]:
			best = (k, s)
	return best[0]


def edge_window(n):
	w = np.ones(n, np.float32)
	e = max(2, int(round(n * EDGE)))
	t = np.linspace(0.0, 1.0, e, dtype=np.float32)
	ramp = t * t * (3.0 - 2.0 * t)
	w[:e] = ramp
	w[-e:] = ramp[::-1]
	return w


def cut(path):
	"""Лист → (сетка k, кадры [CELL×CELL float 0…1])."""
	L = load_lum(path)
	H, W = L.shape
	k = grid_of(L)
	bg = float(np.percentile(L, 5))
	lit = L[L > bg + 0.02]
	white = float(np.percentile(lit, WHITE_PCT)) if lit.size else 1.0
	N = np.clip((L - bg) / max(white - bg, 1e-3), 0.0, 1.0)
	frames = []
	for r in range(k):
		for c in range(k):
			y0, y1 = int(round(H * r / k)), int(round(H * (r + 1) / k))
			x0, x1 = int(round(W * c / k)), int(round(W * (c + 1) / k))
			crop = N[y0:y1, x0:x1]
			crop = crop * edge_window(crop.shape[0])[:, None] * edge_window(crop.shape[1])[None, :]
			img = Image.fromarray(np.ascontiguousarray(crop, dtype=np.float32), mode="F").resize((CELL, CELL), Image.LANCZOS)
			v = np.clip((np.asarray(img, dtype=np.float32) - FLOOR) / (1.0 - FLOOR), 0.0, 1.0)
			frames.append(v)
	return k, frames


def analyze(frames, view, kind):
	"""Яркость кадров, пик, петля, опора и самая яркая точка."""
	en = np.array([float(f.sum()) for f in frames])
	en = en / max(en.max(), 1e-6)
	peak = int(np.argmax(en))
	n = len(frames)
	loop = [0, n - 1]
	if kind == "loop":
		ok = en >= LOOP_KEEP
		best = (0, 0)
		i = 0
		while i < n:
			if ok[i]:
				j = i
				while j + 1 < n and ok[j + 1]:
					j += 1
				if j - i > best[1] - best[0]:
					best = (i, j)
				i = j + 1
			else:
				i += 1
		loop = [best[0], best[1]]
	pivot = [0.5, 0.5]
	if view == "side":
		# Земля — самая широкая строка нижних 40 % кадра (кольцо у основания, низ пламени, вспышка удара молнии):
		# ширина — сколько столбцов светится в среднем по кадрам; из почти самых широких — нижняя
		mean = np.stack(frames).mean(axis=0)
		width = (mean > GROUND_LIT).sum(axis=1).astype(np.float32)
		lo = int(CELL * GROUND_FROM)
		wide = np.nonzero(width[lo:] >= GROUND_WIDE * width[lo:].max())[0]
		pivot = [0.5, round(float(lo + int(wide.max()) + 0.5) / CELL, 4) if wide.size else 0.85]
	pk = np.stack(frames[max(0, peak - 1):peak + 2]).mean(axis=0)
	w = pk ** 4
	yy, xx = np.mgrid[0:CELL, 0:CELL]
	sw = float(w.sum())
	hot = [round(float((w * xx).sum() / sw + 0.5) / CELL, 4), round(float((w * yy).sum() / sw + 0.5) / CELL, 4)] \
		if sw > 0 else [0.5, 0.5]
	return {"energy": [round(float(x), 3) for x in en], "peak": peak, "loop": loop, "pivot": pivot, "hot": hot}


def atlas(k, frames):
	out = np.zeros((k * CELL, k * CELL), np.uint8)
	for i, f in enumerate(frames):
		r, c = divmod(i, k)
		out[r * CELL:(r + 1) * CELL, c * CELL:(c + 1) * CELL] = np.round(f * 255.0).astype(np.uint8)
	return out


def preview(png, info, path):
	"""Картинка-проверка: лист, опора (крест) и самая яркая точка (кружок) в каждом кадре, петля — рамкой."""
	im = Image.open(png).convert("RGB")
	d = ImageDraw.Draw(im)
	k = info["grid"]
	for i in range(k * k):
		r, c = divmod(i, k)
		x0, y0 = c * CELL, r * CELL
		px, py = x0 + info["pivot"][0] * CELL, y0 + info["pivot"][1] * CELL
		d.line([px - 10, py, px + 10, py], fill=(255, 60, 60), width=2)
		d.line([px, py - 10, px, py + 10], fill=(255, 60, 60), width=2)
		hx, hy = x0 + info["hot"][0] * CELL, y0 + info["hot"][1] * CELL
		d.ellipse([hx - 6, hy - 6, hx + 6, hy + 6], outline=(60, 200, 255), width=2)
		if info["loop"][0] <= i <= info["loop"][1]:
			d.rectangle([x0 + 1, y0 + 1, x0 + CELL - 2, y0 + CELL - 2], outline=(80, 255, 80), width=1)
		d.text((x0 + 4, y0 + 4), "%d %.2f" % (i, info["energy"][i]), fill=(255, 220, 0))
	im.thumbnail((768, 768))
	im.save(path)


def write_meta(meta):
	with open(META, "w", encoding="utf-8") as f:
		json.dump(meta, f, ensure_ascii=False, indent=1, sort_keys=True)
		f.write("\n")


def build(a):
	specs = doc_specs()
	files = {}
	for dp, _dn, fn in os.walk(a.src):
		for n in fn:
			if n.lower().endswith(".png"):
				files.setdefault(n, os.path.join(dp, n))
				# «01_file_….png» (номер по порядку перед именем) — тоже лист
				head, _, tail = n.partition("_")
				if head.isdigit() and tail:
					files.setdefault(tail, os.path.join(dp, n))
	todo = []
	for name, key, view, ground in read_sources():
		if name in files:
			todo.append((files[name], name, key, view, ground))
	for n, p in files.items():
		if n.startswith("fx_") and not any(t[1] == n for t in todo):
			todo.append((p, n, n[3:-4], "", None))
	if a.only:
		want = set(a.only.split(","))
		todo = [t for t in todo if split_key(t[2], specs)[0] in want or t[2] in want]
	if not todo:
		sys.exit("в %s нет листов из %s (и файлов fx_<id>.png)" % (a.src, rel(SOURCES)))
	os.makedirs(OUT, exist_ok=True)
	meta = {"format": 1, "cell": CELL, "sheets": {}}
	if os.path.exists(META):
		with open(META, encoding="utf-8") as f:
			meta = json.load(f)
	sheets = meta.setdefault("sheets", {})
	done = {}
	for path, name, key, view, ground in sorted(todo, key=lambda t: t[2]):
		base, var = split_key(key, specs)
		sp = specs[base]
		v = view or sp["view"]
		k, frames = cut(path)
		info = analyze(frames, v, sp["kind"])
		if ground is not None:
			info["pivot"] = [0.5, ground]
		out_name = "fx_%s.png" % (base if var == 1 else "%s_%d" % (base, var))
		out = os.path.join(OUT, out_name)
		Image.fromarray(atlas(k, frames), mode="L").save(out, optimize=True)
		# .import после импорта Godot (uid, путь) не трогать: новый uid — лишняя правка
		imp = out + ".import"
		if not os.path.exists(imp) or 'importer="image"' not in open(imp, encoding="utf-8").read():
			with open(imp, "w", encoding="utf-8") as f:
				f.write(IMPORT % rel(out))
		rec = {"file": out_name, "src": name, "view": v, "grid": k, "frames": k * k, "variant": var}
		rec.update(info)
		ent = sheets.get(base) if base in done else None
		if ent is None:
			ent = {"title": sp["title"], "order": sp["order"], "kind": sp["kind"], "view": sp["view"], "files": []}
			if base in sheets:
				ent["files"] = [x for x in sheets[base].get("files", []) if x["file"] != out_name]
			sheets[base] = ent
			done[base] = True
		ent["files"] = sorted([x for x in ent["files"] if x["file"] != out_name] + [rec], key=lambda x: x["variant"])
		print("%-22s %s %d×%d %s, вид %-5s опора %.2f %.2f, ярко %.2f %.2f, пик %2d, %s %d–%d, конец %.2f, %4.0f КБ" % (
			out_name, name[:16], k, k, sp["kind"], v, rec["pivot"][0], rec["pivot"][1], rec["hot"][0], rec["hot"][1],
			rec["peak"], "петля" if sp["kind"] == "loop" else "кадры", rec["loop"][0], rec["loop"][1], rec["energy"][-1],
			os.path.getsize(out) / 1024.0))
		if a.preview:
			os.makedirs(a.preview, exist_ok=True)
			preview(out, rec, os.path.join(a.preview, out_name))
	write_meta(meta)
	print("записано: %s (эффектов %d, листов %d)" % (rel(META), len(sheets), sum(len(s["files"]) for s in sheets.values())))


def check(_a):
	if not os.path.exists(META):
		sys.exit("нет %s" % rel(META))
	with open(META, encoding="utf-8") as f:
		meta = json.load(f)
	specs = doc_specs()
	errors = []
	n = 0
	for sid, s in sorted(meta.get("sheets", {}).items()):
		if sid not in specs:
			errors.append("%s: нет такого промта" % sid)
		for r in s.get("files", []):
			n += 1
			p = os.path.join(OUT, r["file"])
			if not os.path.exists(p):
				errors.append("нет файла %s" % rel(p))
				continue
			im = Image.open(p)
			k = int(r["grid"])
			if im.mode != "L" or im.size != (k * CELL, k * CELL):
				errors.append("%s: %s %s вместо L %d×%d" % (r["file"], im.mode, im.size, k * CELL, k * CELL))
			if not os.path.exists(p + ".import") or 'importer="image"' not in open(p + ".import", encoding="utf-8").read():
				errors.append("%s.import: нужен importer=\"image\"" % r["file"])
			if r["view"] not in VIEWS:
				errors.append("%s: вид %s" % (r["file"], r["view"]))
			if len(r["energy"]) != k * k or not (0 <= r["loop"][0] <= r["loop"][1] < k * k):
				errors.append("%s: кадры или петля" % r["file"])
			if s["kind"] == "once" and r["energy"][-1] > 0.5:
				print("предупреждение: %s — разовый, а последний кадр яркий (%.2f)" % (r["file"], r["energy"][-1]))
	if errors:
		sys.exit("\n".join(errors))
	print("раскадровки: эффектов %d, листов %d — файлы, размеры, импорт и метаданные в порядке" % (
		len(meta.get("sheets", {})), n))


def main():
	ap = argparse.ArgumentParser(description=__doc__)
	ap.add_argument("--src", help="папка с листами (ищется и в подпапках)")
	ap.add_argument("--only", help="только эти эффекты (id через запятую)")
	ap.add_argument("--preview", help="папка для картинок-проверок")
	ap.add_argument("--check", action="store_true", help="проверить готовые листы")
	a = ap.parse_args()
	if a.check:
		check(a)
		return
	if not a.src:
		ap.error("нужен --src или --check")
	build(a)


if __name__ == "__main__":
	main()
