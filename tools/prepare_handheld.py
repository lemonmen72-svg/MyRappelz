#!/usr/bin/env python3
"""Оружие и предметы в руках из Meshy AI → игровые модели assets/handheld/ (оружие героев, предметы жителей).

Вход — GLB из Meshy (статичный меш с текстурой, без скелета; имя папки «Meshy_AI_<Название>_<дата>_texture_<хэш>»
или файла с тем же названием). Какой файл какой предмет — таблица ITEMS (src — часть пути к файлу). Конвейер — как у
tools/prepare_props.py (его функции: упрощение по форме с защитой тонких частей, разворот изнанки наружу, своя
развёртка xatlas, запекание цвета исходника), только масштаб — по длине предмета, а начало координат — точка хвата.
Для каждого предмета пишет в assets/handheld/:
  <id>.glb  (+ .import) — упрощённый меш (бюджет tris), реальный размер, оси по контракту (ниже), нормали плавные на
                          скруглённом и резкие на рёбрах; без картинок и материала (материал задаёт игра: Handheld).
  <id>.png  (+ .import) — запечённая текстура своей развёртки (tex×tex, VRAM-сжатие, мипмапы).
handheld.json — для игры и тестов: на каждый id вид (kind: вид оружия ItemData.WEAPON_KINDS или "npc"), рамка осей
(frame), длина, размеры, min/max, точки (grip — всегда [0, 0, 0], grip2 — вторая рука у двуручного, tip — верхний
конец, butt — нижний), треугольники, текстура, источник.

КОНТРАКТ ОСЕЙ (метры, начало координат — точка хвата: центр рукояти там, где ладонь; у двуручного — ведущая,
правая рука, у гарды или выше по древку, вторая рука — grip2 ниже):
  frame "blade"    — всё длинное (мечи, кинжал, топоры, булавы, посохи, копьё, трость, жезл, молот, ключи, свиток,
                     колчан): ось предмета (рукоять → остриё / навершие) — +Y; плоскость клинка, лезвия топора,
                     наконечника копья — XY (тонко по Z); лезвие топора и боёк молота — в сторону +X. Так же, как
                     процедурные _sword_mesh / _axe_mesh в character_model.gd под _grip_xf: +X — к костяшкам кулака.
  frame "bow"      — лук: плечи вдоль ±Y, рукоять в нуле, тетива — к +Z (как _bow_mesh, лук в левой кисти).
  frame "crossbow" — арбалет: ложе вдоль −Z (вперёд, дуги впереди), +Y — верх (сторона болта), дуги вдоль ±X;
                     начало — под ложем у обмотанной шейки приклада, ложе на 6 см выше (как _crossbow_mesh, поворот
                     crossbow_rot героя ставит его на изготовку).
  frame "shield"   — щит: лицевая сторона к +Z, верх — +Y; начало — за щитом напротив умбона (ручка, кулак).
  frame "book"     — книги: обложка к +Z, верх книги +Y, корешок — к −X; начало — у корешка посередине высоты.
Размеры — как в промтах оружия 1-го ранга (tools/Промты_оружие_ранги_1_2_и_значки.docx): одноручный меч 0.95 м,
кинжал 0.38, одноручная булава 0.75, одноручный топор 0.7, одноручный посох 0.8, двуручный меч 1.45, двуручный
посох 1.7, двуручная булава 1.4, двуручный топор 1.4, копьё 2.0, лук 1.4, арбалет 0.85 (длина), щит 0.75 (высота);
предметы жителей — по смыслу.

Новый предмет (например, оружие 2-го ранга «weapon_sword_1h_r2»): GLB из Meshy в папку исходников, строка в ITEMS
(src, kind, frame, length, tris, tex, grip — доля длины от нижнего конца, grip2, rot — поворот вокруг Y, чтобы лезвие
смотрело в +X / тетива в +Z), запуск (пересобирает только --only, если задано), посмотреть --preview, затем в игре —
поле "model" у предмета ItemData (или Handheld.KIND_MODELS для модели вида по умолчанию).

Зависимости: numpy, Pillow, scipy, meshoptimizer, xatlas (как у tools/prepare_props.py). Запуск из корня репозитория
(входные файлы — чужие данные, Python с -I):
  python3 -I tools/prepare_handheld.py --src <папка с GLB Meshy> [--src <ещё папка>]     # собрать всё
  python3 -I tools/prepare_handheld.py --src <папка> --only weapon_dagger_r1,npc_cane    # только эти
  python3 -I tools/prepare_handheld.py --check                                          # проверить готовые
  python3 -I tools/prepare_handheld.py --check --preview /tmp/hh                        # плюс картинки (4 стороны
                                                     # и сверху; изнанка — пурпурная; хват — красный, grip2 — синий)
"""
import argparse
import glob
import importlib.util
import json
import os
import sys

import numpy as np

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("prepare_props", os.path.join(_HERE, "prepare_props.py"))
pp = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(pp)
pc = pp.pc

ROOT = os.path.dirname(_HERE)
OUT = os.path.join(ROOT, "assets", "handheld")

# src — часть пути к исходнику (у двух «Mooncleaver» — хэш папки), kind — вид (ItemData.WEAPON_KINDS) или "npc",
# frame — рамка осей (см. шапку), length — длина по оси Y (у щита и книг — высота, у арбалета — длина ложа),
# tris — бюджет треугольников, tex — размер текстуры, grip / grip2 — доля длины от нижнего конца (рукоять),
# rot — поворот вокруг Y до всего остального (градусы, как Basis(UP, a) в Godot).
ITEMS = {
	# Оружие 1-го ранга (модели Максима по промтам оружия 1-го ранга)
	"weapon_sword_1h_r1": dict(src="Knight_s_Oath", kind="sword_1h", frame="blade", length=0.95, tris=3000,
		tex=512, grip=0.17),
	"weapon_sword_2h_r1": dict(src="Gilded_Oathblade", kind="sword_2h", frame="blade", length=1.45, tris=3200,
		tex=512, grip=0.27, grip2=0.13),
	"weapon_dagger_r1": dict(src="Emberfang", kind="dagger", frame="blade", length=0.38, tris=2600, tex=512,
		grip=0.23),
	"weapon_mace_1h_r1": dict(src="Ironbound_Scepter", kind="mace_1h", frame="blade", length=0.75, tris=3500,
		tex=512, grip=0.19),
	"weapon_mace_2h_r1": dict(src="Ironbound_Warhammer", kind="mace_2h", frame="blade", length=1.4, tris=4000,
		tex=512, grip=0.55, grip2=0.2),
	"weapon_axe_1h_r1": dict(src="Mooncleaver_20261101_texture_c2e20c45", kind="axe_1h", frame="blade",
		length=0.7, tris=3500, tex=512, grip=0.2, rot=180),
	"weapon_axe_2h_r1": dict(src="Mooncleaver_20261101_texture_e850e3a2", kind="axe_2h", frame="blade",
		length=1.4, tris=3500, tex=512, grip=0.55, grip2=0.2, rot=180),
	"weapon_staff_1h_r1": dict(src="Crystalwood_Scepter", kind="staff_1h", frame="blade", length=0.8, tris=3500,
		tex=512, grip=0.17),
	"weapon_staff_2h_r1": dict(src="Emberwood_Staff", kind="staff_2h", frame="blade", length=1.7, tris=3500,
		tex=512, grip=0.35, grip2=0.18),
	"weapon_spear_r1": dict(src="Emberlance", kind="spear", frame="blade", length=2.0, tris=3000, tex=512,
		grip=0.33, grip2=0.1),
	"weapon_crossbow_r1": dict(src="Ornate_Crossbow", kind="crossbow", frame="crossbow", length=0.85, tris=6000,
		tex=1024, grip=0.3),
	"weapon_shield_r1": dict(src="Sunward_Aegis", kind="shield", frame="shield", length=0.75, tris=4000, tex=1024,
		grip=0.58),
	# Предметы жителей (id — договорённость с моделями жителей; лук — и у героев: Handheld.KIND_MODELS["bow"])
	"npc_longbow": dict(src="Emberwood_Longbow", kind="npc", frame="bow", length=1.4, tris=4000, tex=512,
		grip=0.5, rot=-90, thin=True),
	"npc_grimoire": dict(src="Astral_Grimoire", kind="npc", frame="book", length=0.3, tris=3000, tex=512,
		grip=0.5),
	"npc_tome": dict(src="Leatherbound_Tome", kind="npc", frame="book", length=0.3, tris=3000, tex=512, grip=0.5),
	"npc_cane": dict(src="Carved_Wooden_Cane", kind="npc", frame="blade", length=0.95, tris=2000, tex=512,
		grip=0.88),
	"npc_wand": dict(src="Crystalvine_Wand", kind="npc", frame="blade", length=0.45, tris=2500, tex=512, grip=0.25),
	"npc_hammer": dict(src="Ironbound_Hammer", kind="npc", frame="blade", length=0.6, tris=2500, tex=512, grip=0.3),
	"npc_antlerstaff": dict(src="Verdant_Antlerstaff", kind="npc", frame="blade", length=1.7, tris=4500, tex=512,
		grip=0.5, grip2=0.32),
	"npc_quiver": dict(src="Quiver_of_Arrows", kind="npc", frame="blade", length=0.7, tris=4500, tex=512, grip=0.45),
	"npc_keys": dict(src="Ring_of_Forgotten_Keys", kind="npc", frame="blade", length=0.2, tris=4000, tex=512,
		grip=0.9),
	"npc_scroll": dict(src="Sealed_Shadow_Scroll", kind="npc", frame="blade", length=0.3, tris=2500, tex=512,
		grip=0.5),
}

# Арбалет: ложе на столько выше точки хвата (кулак под ложем, как у процедурного _crossbow_mesh)
CROSSBOW_STOCK_UP = 0.06
# Щит: ручка за щитом — на столько позади задней стороны
SHIELD_HANDLE_BACK = 0.035
# Тонкие отдельные части (thin): доля площади, ниже которой часть упрощается отдельно, и допустимая ошибка
# (доля габарита предмета)
THIN_SHARE = 0.1
THIN_ERROR = 0.0004

GLB_IMPORT = pp.GLB_IMPORT.replace("assets/props/", "assets/handheld/")
PNG_IMPORT = pp.PNG_IMPORT.replace("assets/props/", "assets/handheld/")


def view_dirs() -> np.ndarray:
	"""Предмет в руке видно со всех сторон, в том числе снизу: круг на 5 высотах, сверху и снизу."""
	out = [(0.0, 1.0, 0.0), (0.0, -1.0, 0.0)]
	for el in (-50.0, -20.0, 5.0, 30.0, 60.0):
		e = np.radians(el)
		for k in range(10):
			a = np.radians(k * 36.0 + (18.0 if el in (-20.0, 30.0) else 0.0))
			out.append((np.sin(a) * np.cos(e), np.sin(e), np.cos(a) * np.cos(e)))
	return np.array(out)


# orient_faces prepare_props смотрит на постройку только сбоку и сверху — предмет в руке смотрим отовсюду
pp.view_dirs = view_dirs


def find_src(dirs: list, key: str) -> str:
	files = []
	for d in dirs:
		files += [f for f in glob.glob(os.path.join(d, "**", "*.glb"), recursive=True) if key in f]
	files = sorted(set(files))
	if len(files) != 1:
		raise SystemExit("исходник %r: найдено %d файлов" % (key, len(files)))
	return files[0]


def _rot_y(deg: float) -> np.ndarray:
	a = np.radians(deg)
	# Как Basis(UP, a) в Godot (и place() в prepare_props): x' = x cos a + z sin a, z' = −x sin a + z cos a
	return np.array([[np.cos(a), 0.0, np.sin(a)], [0.0, 1.0, 0.0], [-np.sin(a), 0.0, np.cos(a)]])


def _slice_center(p: np.ndarray, y: float, L: float) -> np.ndarray:
	"""Центр сечения на высоте y (середина габаритов вершин в слое ±1.5 % длины) — ось рукояти, даже если
	лезвие топора или навершие уводят габариты вбок."""
	h = max(0.015 * L, 0.004)
	s = p[np.abs(p[:, 1] - y) < h]
	if len(s) < 3:
		s = p[np.argsort(np.abs(p[:, 1] - y))[:16]]
	return np.array([(s[:, 0].min() + s[:, 0].max()) * 0.5, y, (s[:, 2].min() + s[:, 2].max()) * 0.5])


def orient(m: dict, cfg: dict) -> tuple:
	"""Поворот, масштаб по длине (ось Y), начало координат — точка хвата, рамка осей вида. Возвращает
	(меш, точки {grip2, tip, butt} в итоговых осях)."""
	R = _rot_y(cfg.get("rot", 0.0))
	p = m["pos"] @ R.T
	n = m["nrm"] @ R.T
	lo, hi = p.min(0), p.max(0)
	s = cfg["length"] / max(hi[1] - lo[1], 1e-9)
	p = (p - np.array([(lo[0] + hi[0]) * 0.5, lo[1], (lo[2] + hi[2]) * 0.5])) * s
	L = cfg["length"]
	frame = cfg["frame"]
	gy = cfg["grip"] * L
	if frame == "shield":
		# За щитом напротив умбона, посередине ширины
		grip = np.array([0.0, gy, p[:, 2].min() - SHIELD_HANDLE_BACK])
	elif frame == "book":
		# Корешок (−X) посередине высоты и толщины
		c = _slice_center(p, gy, L)
		grip = np.array([p[:, 0].min(), gy, c[2]])
	else:
		grip = _slice_center(p, gy, L)
	if frame == "crossbow":
		# У исходника верх арбалета (болт) смотрит в +Z: кулак — ниже ложа
		grip = grip - np.array([0.0, 0.0, CROSSBOW_STOCK_UP])
	pts = {"tip": _slice_center(p, L - 0.002, L), "butt": _slice_center(p, 0.002, L)}
	if "grip2" in cfg:
		pts["grip2"] = _slice_center(p, cfg["grip2"] * L, L)
	p = p - grip
	pts = {k: v - grip for k, v in pts.items()}
	if frame == "crossbow":
		# Исходник стоит «на прикладе» (вперёд +Y, верх +Z) → вперёд −Z, верх +Y: поворот вокруг X на −90°
		Rx = np.array([[1.0, 0.0, 0.0], [0.0, 0.0, 1.0], [0.0, -1.0, 0.0]])
		p = p @ Rx.T
		n = n @ Rx.T
		pts = {k: Rx @ v for k, v in pts.items()}
	out = dict(m)
	out["pos"] = p
	out["nrm"] = n
	return out, pts


def simplify(src: dict, cfg: dict) -> dict:
	"""Упрощение prepare_props (по форме, с защитой тонких панелей). thin — у предмета есть тонкие отдельные части
	(тетива лука): связные части меньше THIN_SHARE площади упрощаются отдельно с малой ошибкой (meshopt по ошибке,
	не по бюджету) — иначе общий бюджет сплющивает тетиву в невидимую ленту."""
	if not cfg.get("thin"):
		return pp.simplify(src, cfg["tris"])
	from scipy.sparse import coo_matrix
	from scipy.sparse.csgraph import connected_components
	q = np.round(src["pos"] / 1e-5).astype(np.int64)
	_, first, inv = np.unique(q, axis=0, return_index=True, return_inverse=True)
	inv = inv.ravel()
	pos = src["pos"][first]
	t = inv[src["tris"]]
	t = t[(t[:, 0] != t[:, 1]) & (t[:, 1] != t[:, 2]) & (t[:, 2] != t[:, 0])]
	e = np.concatenate([t[:, [0, 1]], t[:, [1, 2]], t[:, [2, 0]]])
	nc, vlab = connected_components(coo_matrix((np.ones(len(e)), (e[:, 0], e[:, 1])), shape=(len(pos), len(pos))),
		directed=False)
	flab = vlab[t[:, 0]]
	area = 0.5 * np.linalg.norm(np.cross(pos[t[:, 1]] - pos[t[:, 0]], pos[t[:, 2]] - pos[t[:, 0]]), axis=1)
	share = np.bincount(flab, area, nc) / area.sum()
	small = share[flab] < THIN_SHARE
	thin, _ = pp._meshopt(pos, t[small], 0, THIN_ERROR, 0)
	main = pp.simplify({"pos": pos, "tris": t[~small]}, cfg["tris"] - len(thin))
	out = np.vstack([main["tris"], len(main["pos"]) + thin])
	allpos = np.vstack([main["pos"], pos])
	used, t2 = np.unique(out.ravel(), return_inverse=True)
	print("    тонкие части: %d тр. → %d" % (int(small.sum()), len(thin)))
	return {"pos": allpos[used], "tris": t2.reshape(-1, 3).astype(np.int64), "err": main["err"],
		"panels": main["panels"], "panel_tris": main["panel_tris"] + len(thin)}


def build_one(dirs: list, iid: str, meta: dict) -> None:
	cfg = ITEMS[iid]
	path = find_src(dirs, cfg["src"])
	print("%s ← %s" % (iid, os.path.relpath(path, os.path.dirname(os.path.dirname(path)))))
	src, pts = orient(pp.load_source(path), cfg)
	src["tex"] = np.asarray(src["img"])
	# Пороги защиты тонких частей — под размер предмета (у построек — метры и квадратные метры)
	L = cfg["length"]
	pp.HOLE_DIST = max(0.003, 0.012 * L)
	pp.PANEL_LOST = max(0.00005, 0.0006 * L * L)
	pp.PANEL_ERROR = 0.0005
	low = simplify(src, cfg)
	print("    ошибка упрощения %.4f, сохранено частей %d (%d тр.)" % (low["err"], low["panels"], low["panel_tris"]))
	sign = pp.orient_faces(low["pos"], low["tris"])
	low["tris"][sign < 0] = low["tris"][sign < 0][:, ::-1]
	flipped = int((sign < 0).sum())
	size = cfg["tex"]
	m = pp.unwrap(low["pos"], low["tris"], size)
	tile = pp.bake(src, m, size, sign)
	glb = os.path.join(OUT, iid + ".glb")
	png = os.path.join(OUT, iid + ".png")
	uv = np.clip(m["uv"], 0.0, 1.0)
	pp.write_glb(glb, iid, m["pos"], m["nrm"], uv, np.zeros(len(m["pos"])), m["tris"])
	pp.write_import(glb, GLB_IMPORT)
	tile.save(png, optimize=True)
	pp.write_import(png, PNG_IMPORT)
	lo, hi = m["pos"].min(0), m["pos"].max(0)
	r3 = lambda v: [round(float(x), 4) for x in v]
	meta["items"][iid] = {
		"kind": cfg["kind"], "frame": cfg["frame"], "length": cfg["length"],
		"size": r3(hi - lo), "min": r3(lo), "max": r3(hi),
		"grip": [0.0, 0.0, 0.0], "grip2": r3(pts["grip2"]) if "grip2" in pts else None,
		"tip": r3(pts["tip"]), "butt": r3(pts["butt"]),
		"tris": int(len(m["tris"])), "verts": int(len(m["pos"])), "src_tris": int(len(src["tris"])),
		"tex": size, "flipped": flipped, "src": cfg["src"],
	}
	print("    треугольников %d → %d, размер %s м, перевёрнуто граней %d, файлы %.0f + %.0f КБ" % (
		len(src["tris"]), len(m["tris"]), " × ".join("%.3f" % v for v in hi - lo), flipped,
		os.path.getsize(glb) / 1024, os.path.getsize(png) / 1024))


def build(dirs: list, only: list) -> None:
	os.makedirs(OUT, exist_ok=True)
	meta_path = os.path.join(OUT, "handheld.json")
	meta = {"items": {}}
	if os.path.exists(meta_path):
		with open(meta_path) as f:
			meta = json.load(f)
	for iid in (only or list(ITEMS)):
		build_one(dirs, iid, meta)
	meta["items"] = {k: meta["items"][k] for k in ITEMS if k in meta["items"]}
	meta["about"] = ("tools/prepare_handheld.py: начало координат — точка хвата; frame blade — ось +Y, лезвие к +X, "
		"плоскость клинка XY; bow — плечи ±Y, тетива +Z; crossbow — вперёд −Z, верх +Y; shield — лицо +Z, верх +Y; "
		"book — обложка +Z, верх +Y, корешок −X")
	with open(meta_path, "w") as f:
		json.dump(meta, f, ensure_ascii=False, indent="\t")
		f.write("\n")


# ---------- Проверка и картинки ----------

def check(preview: str) -> bool:
	from PIL import Image
	with open(os.path.join(OUT, "handheld.json")) as f:
		meta = json.load(f)
	ok = True
	total = 0
	for iid, cfg in ITEMS.items():
		info = meta["items"].get(iid)
		glb = os.path.join(OUT, iid + ".glb")
		png = os.path.join(OUT, iid + ".png")
		if info is None or not all(os.path.exists(x) for x in (glb, glb + ".import", png, png + ".import")):
			print("ПЛОХО: %s — нет модели" % iid)
			ok = False
			continue
		total += os.path.getsize(glb) + os.path.getsize(png)
		m = pp.read_built(glb)
		lo, hi = m["pos"].min(0), m["pos"].max(0)
		bad = []
		if m["images"]:
			bad.append("в GLB есть картинки")
		if len(m["tris"]) > cfg["tris"] * 1.6:
			bad.append("треугольников %d > %d" % (len(m["tris"]), cfg["tris"] * 1.6))
		L = cfg["length"]
		axis = 2 if cfg["frame"] == "crossbow" else 1
		if abs((hi - lo)[axis] - L) > 0.03 * L:
			bad.append("длина %.3f вместо %.3f" % ((hi - lo)[axis], L))
		if not (lo[axis] < -0.001 or cfg["grip"] < 0.02) or hi[axis] < 0.001:
			bad.append("хват не внутри длины")
		# Хват — у самого предмета (рукоять, ложе, за щитом), а не в пустоте
		sp, _ = pp.surface_points(m["pos"], m["tris"], 60000)
		near = float(np.min(np.linalg.norm(sp, axis=1)))
		if near > max(0.08, 0.06 * L):
			bad.append("хват в %.3f м от предмета" % near)
		if m["uv"].min() < 0.0 or m["uv"].max() > 1.0:
			bad.append("UV вне [0, 1]")
		img = Image.open(png)
		if img.size != (cfg["tex"], cfg["tex"]):
			bad.append("текстура %s" % (img.size,))
		print("%-20s %-9s %-8s %5d тр. %s м %s" % (iid, cfg["kind"], cfg["frame"], len(m["tris"]),
			" × ".join("%5.3f" % d for d in hi - lo), "ok" if not bad else "ПЛОХО: " + "; ".join(bad)))
		ok = ok and not bad
		if preview:
			os.makedirs(preview, exist_ok=True)
			write_preview(os.path.join(preview, iid + ".png"), m, np.asarray(img.convert("RGB")), info)
	print("Всего в assets/handheld: %.1f МБ" % (total / 1e6))
	return ok


def write_preview(path: str, m: dict, tex: np.ndarray, info: dict) -> None:
	"""Спереди (+Z), справа (+X), сзади, слева и сверху; цвет — текстура в каждом пикселе (по барицентрам),
	изнанка — пурпурная; точка хвата — красный крест, grip2 — синий, ось +X — короткая зелёная черта от хвата."""
	from PIL import Image, ImageDraw
	size = 360
	pos, tris, uv = m["pos"], m["tris"], m["uv"]
	fn = np.cross(pos[tris[:, 1]] - pos[tris[:, 0]], pos[tris[:, 2]] - pos[tris[:, 0]])
	fn /= np.maximum(np.linalg.norm(fn, axis=1, keepdims=True), 1e-12)
	cu = uv[tris].mean(1)
	h, w = tex.shape[:2]
	col = tex[np.clip(cu[:, 1] * h, 0, h - 1).astype(int), np.clip(cu[:, 0] * w, 0, w - 1).astype(int)] / 255.0
	light = np.array([0.4, 0.8, 0.45])
	light /= np.linalg.norm(light)
	c = (pos.min(0) + pos.max(0)) * 0.5
	span = float(np.linalg.norm(pos.max(0) - pos.min(0))) * 1.02
	views = []
	for ang in (0.0, 90.0, 180.0, 270.0):
		a, e = np.radians(ang), np.radians(12.0)
		views.append(np.array([np.sin(a) * np.cos(e), np.sin(e), np.cos(a) * np.cos(e)]))
	views.append(np.array([0.0, 1.0, 0.0]))
	panels = []
	for d in views:
		ids = pp.visible_faces(pos, tris, d, size)
		img = np.full((size * size, 3), 0.93)
		okp = ids >= 0
		f = ids[okp]
		front = fn[f] @ d >= 0
		shade = 0.5 + 0.5 * np.clip(np.abs(fn[f] @ light), 0, 1)
		cc = col[f] * shade[:, None]
		cc[~front] = (0.9, 0.1, 0.9)
		img[okp] = cc
		im = Image.fromarray((img.reshape(size, size, 3) * 255).astype(np.uint8))
		right = np.cross([0.0, 1.0, 0.0], d)
		if np.linalg.norm(right) < 1e-6:
			right = np.array([1.0, 0.0, 0.0])
		right /= np.linalg.norm(right)
		up = np.cross(d, right)

		def proj(v):
			q = np.asarray(v, dtype=np.float64) - c
			return ((q @ right / span + 0.5) * (size - 1), (0.5 - q @ up / span) * (size - 1))

		dr = ImageDraw.Draw(im)
		gx, gy = proj([0.0, 0.0, 0.0])
		ex, ey = proj([0.06, 0.0, 0.0])
		dr.line([(gx, gy), (ex, ey)], fill=(0, 170, 0), width=2)
		dr.line([(gx - 5, gy), (gx + 5, gy)], fill=(230, 0, 0), width=2)
		dr.line([(gx, gy - 5), (gx, gy + 5)], fill=(230, 0, 0), width=2)
		if info.get("grip2"):
			bx, by = proj(info["grip2"])
			dr.line([(bx - 5, by), (bx + 5, by)], fill=(0, 0, 230), width=2)
			dr.line([(bx, by - 5), (bx, by + 5)], fill=(0, 0, 230), width=2)
		panels.append(im)
	out = Image.new("RGB", (size * len(panels), size), (255, 255, 255))
	for i, p in enumerate(panels):
		out.paste(p, (i * size, 0))
	out.save(path)


def main() -> None:
	ap = argparse.ArgumentParser(description="Оружие и предметы в руках из Meshy: упрощение, масштаб, хват, текстура.")
	ap.add_argument("--src", action="append", default=[], help="папка с GLB из Meshy (поиск во вложенных папках)")
	ap.add_argument("--only", default="", help="id через запятую")
	ap.add_argument("--check", action="store_true", help="только проверить готовые assets/handheld")
	ap.add_argument("--preview", default="", help="папка для картинок-проверок")
	args = ap.parse_args()
	if not args.check:
		if not args.src:
			ap.error("нужна --src <папка с GLB Meshy> или --check")
		only = [s for s in args.only.split(",") if s]
		for s in only:
			if s not in ITEMS:
				ap.error("неизвестный предмет %r" % s)
		build(args.src, only)
	ok = check(args.preview)
	print("ИТОГ: %s" % ("всё в порядке" if ok else "есть замечания (см. ПЛОХО выше)"))
	sys.exit(0 if ok else 1)


if __name__ == "__main__":
	main()
