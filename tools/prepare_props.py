#!/usr/bin/env python3
"""Объекты локации из Meshy AI → игровые модели assets/props/ (постройки, декор, деревья, кусты, камни).

Вход — папка Максима с GLB из Meshy (статичные меши с текстурой, имена «Meshy_AI_<Название>_<номер>_texture.glb»,
по папкам «ГОРОД», «ДЕРЕВНЯ ЛЮДЕЙ», …). Какой файл какой объект — таблица PROPS (поле src — часть имени файла).
Для каждого объекта пишет в assets/props/:
  <id>.glb        — упрощённый по форме меш (meshoptimizer по сваренным позициям — развёртка Meshy из сотен мелких
                    островов держит упрощение и рвёт текстуру), реальный размер (вписан в рамку fit — габариты
                    процедурной модели того же вида в PoiModels), основание на y = 0 (корабль — на sink ниже), центр
                    по X/Z, фасад (дверь) на +Z (поворот rot); своя развёртка (xatlas) прямо в клетку атласа;
                    нормали — плавные на скруглённом и резкие на рёбрах (угол 50°); цвет вершины: rgb = 1,
                    a = свечение (кристаллы, стекло фонарей, огонь — по цвету текстуры glow или область lamp).
                    Без картинок (материал задаёт игра: PropAsset, prop.gdshader).
  <id>.glb.import — встроенные картинки отбрасываются, LOD не генерируются (меши склеиваются по зонам).
Для каждой страницы атласа — props_<страница>.png (+ .png.import: VRAM-сжатие, мипмапы): текстуры объектов
страницы в клетках 1024/512 по сетке степеней двойки (мип-уровни не смешивают соседей). Текстура клетки
запекается: каждый тексель новой развёртки берёт цвет ближайших точек поверхности исходной модели (с нормалью в ту же
сторону — тонкие доски и листья не берут цвет обратной стороны); пустое вокруг развёрток залито цветом ближайшей
развёртки (без тёмных швов на мипах).
props.json — размеры (м), страница, клетка, треугольники, точки (glow — центр светящихся вершин; lamp — фонарь;
front — самая передняя точка, у башни мельницы — ступица крыльев), для игры и тестов.

Зачем атлас: все объекты страницы — один материал, поэтому в игре экземпляры склеиваются в меши зон
(IslandPois) и участков растительности (IslandVegetation) одной поверхностью на страницу — вызовов отрисовки
почти не прибавляется. Страницы — по местам (город, деревня людей, эльфы, порт и лагеря, мелочи, природа).

Как добавить объект: положить GLB из Meshy в папку исходников, добавить строку в PROPS (src — часть имени файла,
fit — рамка, tris, tex 1024/512, rot — поворот, чтобы дверь смотрела на +Z, page — страница, где есть место:
клеток 1024 на странице 2048×2048 — 4, клеток 512 — 16), запустить скрипт (пересобирает всё) и посмотреть
картинки --preview. В игре — запись в PropAsset.KINDS (какую процедурную модель заменяет).

Зависимости: numpy, Pillow, scipy, meshoptimizer (как у tools/prepare_creatures.py) и xatlas (pip install xatlas). Запуск из корня
репозитория (входные файлы — чужие данные, Python с -I):
  python3 -I tools/prepare_props.py --src <папка с GLB Meshy>              # собрать всё
  python3 -I tools/prepare_props.py --src <папка> --only well,barrel       # только эти (их страницы пересобираются целиком)
  python3 -I tools/prepare_props.py --check                               # проверить готовые assets/props
  python3 -I tools/prepare_props.py --check --preview /tmp/props          # плюс картинки (спереди, сбоку, сзади, сверху)
"""
import argparse
import colorsys
import glob
import importlib.util
import io
import json
import os
import struct
import sys

import numpy as np

_spec = importlib.util.spec_from_file_location("prepare_creatures",
	os.path.join(os.path.dirname(os.path.abspath(__file__)), "prepare_creatures.py"))
pc = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(pc)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "props")

# Свечение по цвету текстуры: (оттенок от, оттенок до, насыщенность от, яркость от). Оттенок 0..1 по кругу.
GLOW_BLUE = [(0.47, 0.6, 0.35, 0.55)]
GLOW_GOLD = [(0.07, 0.15, 0.45, 0.72)]
GLOW_PURPLE = [(0.7, 0.88, 0.3, 0.42)]
GLOW_WARM = [(0.08, 0.17, 0.3, 0.86)]

# Страницы атласа: имя → (ширина, высота).
PAGES = {
	"town": (2048, 2048),
	"village": (2048, 2048),
	"elves": (2048, 2048),
	"port": (2048, 2048),
	"small": (2048, 2048),
	"nature": (2048, 1024),
}

# id → src (часть имени файла Meshy), fit — рамка X×Y×Z (м) после поворота (масштаб общий, наибольший, при
# котором модель влезает), tris — треугольников, tex — клетка атласа, rot — поворот вокруг Y (градусы, против
# часовой при взгляде сверху: rot 90 переводит −X в +Z), page, sink — насколько основание ниже y = 0 (м),
# center — центр по всем осям (крылья мельницы: ступица в начале координат), glow — свечение по цвету,
# lamp — фонарь: (центр x, y, z, полуразмер x, y, z) в долях габаритов; вершины в нём светятся, центр — точка «lamp».
PROPS = {
	# Город
	"town_house": dict(src="Hearthwood_Cottage", fit=(5.6, 6.8, 5.0), tris=3500, tex=1024, rot=0, page="town"),
	"town_house_b": dict(src="Amber_Hearth_Cottage", fit=(6.6, 6.8, 5.0), tris=3500, tex=1024, rot=0, page="town"),
	"town_hall": dict(src="Ivybell_Cottage", fit=(8.6, 10.5, 7.2), tris=4500, tex=1024, rot=0, page="town"),
	"well": dict(src="Mossy_Village_Well", fit=(2.4, 3.2, 2.2), tris=1500, tex=512, rot=0, page="town"),
	"notice_board": dict(src="Village_Notice_Board", fit=(2.4, 2.8, 1.0), tris=1000, tex=512, rot=0, page="town"),
	"town_gate": dict(src="Rustic_Garden_Gatehou", fit=(6.2, 6.0, 2.6), tris=1500, tex=512, rot=0, page="town"),
	"merchant_stall": dict(src="Harvest_Market_Stall", fit=(3.0, 2.8, 2.6), tris=1500, tex=512, rot=0, page="town"),
	# Деревня людей
	"human_house_thatch": dict(src="Thatchwood_Cottage", fit=(6.0, 6.6, 5.2), tris=3500, tex=1024, rot=0,
		page="village"),
	"human_house_red": dict(src="Ivy_Hearth_Cottage", fit=(6.0, 6.6, 5.2), tris=3500, tex=1024, rot=0,
		page="village"),
	"windmill_tower": dict(src="Whisperwind_Watchtowe", fit=(5.4, 10.5, 6.0), tris=3500, tex=1024, rot=0,
		page="village"),
	"windmill_sails": dict(src="Tattered_Windmill_Sai", fit=(9.6, 9.6, 1.0), tris=1500, tex=512, rot=0,
		page="village", center=True),
	"scarecrow": dict(src="Patchwork_Scarecrow", fit=(2.2, 2.6, 1.0), tris=800, tex=512, rot=0, page="village"),
	"hay_bale": dict(src="Golden_Hay_Bale", fit=(1.1, 1.1, 1.2), tris=500, tex=512, rot=0, page="village"),
	"trough": dict(src="Mosswood_Trough", fit=(1.7, 0.6, 0.7), tris=500, tex=512, rot=0, page="village"),
	# Светлые и тёмные эльфы
	"light_elf_house": dict(src="Crystalspire_Manor", fit=(6.4, 7.6, 5.4), tris=4500, tex=1024, rot=0, page="elves",
		glow=GLOW_BLUE),
	"light_elf_tower": dict(src="Crystal_Spire_Tower", fit=(5.0, 11.0, 5.0), tris=3500, tex=1024, rot=0,
		page="elves", glow=GLOW_BLUE),
	"dark_elf_house": dict(src="Violet_Gloom_Manor_1031082549", fit=(6.4, 8.2, 5.4), tris=4500, tex=1024, rot=0,
		page="elves", glow=GLOW_PURPLE),
	"dark_elf_tower": dict(src="Amethyst_Spire", fit=(7.0, 16.0, 7.0), tris=3500, tex=1024, rot=0, page="elves",
		glow=GLOW_PURPLE),
	# Порт, лагеря, пещера
	"lighthouse": dict(src="Crimson_Beacon", fit=(5.6, 15.0, 5.6), tris=3500, tex=1024, rot=0, page="port",
		lamp=(0.5, 0.78, 0.5, 0.2, 0.035, 0.2)),
	"ship": dict(src="Sunlit_Voyager", fit=(6.5, 10.5, 9.6), tris=4500, tex=1024, rot=-90, page="port", sink=0.9),
	"cave_entrance": dict(src="Overgrown_Mine_Entran", fit=(9.6, 6.6, 8.0), tris=3500, tex=1024, rot=0, page="port"),
	"tent_bell": dict(src="Desert_Pavilion", fit=(4.4, 3.8, 4.4), tris=1500, tex=512, rot=0, page="port"),
	"tent_ridge": dict(src="Wayfarer_s_Green_Pavi", fit=(3.2, 2.6, 3.6), tris=1500, tex=512, rot=90, page="port"),
	"campfire": dict(src="Stone_Circle_Campfire", fit=(1.7, 0.8, 1.7), tris=800, tex=512, rot=0, page="port"),
	"dock_crates": dict(src="Dockside_Stash", fit=(2.0, 1.6, 1.5), tris=1000, tex=512, rot=0, page="port"),
	# Мелочи (город, деревни, порт, лагеря)
	"lantern_town": dict(src="Rustic_Lantern_Post", fit=(1.4, 3.4, 1.0), tris=600, tex=512, rot=0, page="small",
		lamp=(0.11, 0.745, 0.5, 0.1, 0.05, 0.5)),
	"lantern_elf": dict(src="Moonlit_Arcana_Lanter", fit=(1.8, 3.4, 1.0), tris=800, tex=512, rot=0, page="small",
		glow=GLOW_BLUE, lamp=(0.17, 0.62, 0.5, 0.08, 0.07, 0.5)),
	"weapon_rack": dict(src="Wooden_Weapon_Rack", fit=(1.9, 1.7, 0.9), tris=800, tex=512, rot=0, page="small"),
	"training_dummy": dict(src="Target_Scarecrow", fit=(1.6, 2.2, 0.8), tris=800, tex=512, rot=0, page="small"),
	"bollard": dict(src="Weathered_Mooring_Pos", fit=(0.8, 0.8, 0.8), tris=900, tex=512, rot=0, page="small"),
	"crate": dict(src="Ironbound_Adventurer", fit=(0.85, 0.85, 0.85), tris=400, tex=512, rot=0, page="small"),
	"barrel": dict(src="Weathered_Barrel", fit=(0.85, 1.0, 0.85), tris=500, tex=512, rot=0, page="small"),
	"brazier_dark": dict(src="Violet_Witchflame_Cau", fit=(1.4, 1.3, 1.4), tris=1000, tex=512, rot=0, page="small",
		glow=GLOW_PURPLE),
	"dark_spire": dict(src="Voidspire", fit=(2.6, 6.2, 2.6), tris=1000, tex=512, rot=0, page="small",
		glow=GLOW_PURPLE),
	"crystal_blue": dict(src="Crystal_Moss_Haven", fit=(1.9, 2.0, 1.9), tris=900, tex=512, rot=0, page="small",
		glow=GLOW_BLUE),
	"crystal_gold": dict(src="Golden_Crystal_Grove", fit=(1.7, 1.8, 1.7), tris=900, tex=512, rot=0, page="small",
		glow=GLOW_GOLD),
	"crystal_purple": dict(src="Amethyst_Grove", fit=(2.0, 2.1, 2.0), tris=900, tex=512, rot=0, page="small",
		glow=GLOW_PURPLE),
	# Природа (IslandVegetation: склеиваются по участкам)
	"tree_oak": dict(src="Whispering_Grove", fit=(6.0, 6.0, 6.0), tris=1100, tex=512, rot=0, page="nature"),
	"tree_pine": dict(src="Whispering_Evergreen", fit=(5.0, 7.0, 5.0), tris=800, tex=512, rot=0, page="nature"),
	"tree_elf": dict(src="Blushbloom_Tree", fit=(5.6, 6.0, 5.6), tris=1100, tex=512, rot=0, page="nature"),
	"tree_dead": dict(src="Twisted_Elder", fit=(5.0, 5.2, 5.0), tris=1100, tex=512, rot=0, page="nature"),
	"bush": dict(src="Verdant_Whimsy", fit=(1.8, 1.5, 1.8), tris=450, tex=512, rot=0, page="nature"),
	"rock": dict(src="Mossy_Boulder", fit=(2.0, 1.6, 2.0), tris=400, tex=512, rot=0, page="nature"),
	"rock_dark": dict(src="Shadowcrag_Bloom", fit=(1.7, 1.8, 1.7), tris=450, tex=512, rot=0, page="nature"),
}

GLB_IMPORT = """[remap]

importer="scene"
importer_version=1
type="PackedScene"

[deps]

source_file="res://assets/props/{name}"

[params]

gltf/embedded_image_handling=0
meshes/generate_lods=false
meshes/create_shadow_meshes=false
"""

PNG_IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://assets/props/{name}"

[params]

compress/mode=2
compress/high_quality=false
mipmaps/generate=true
detect_3d/compress_to=0
"""


# ---------- Чтение исходника ----------

def find_src(src_dir: str, key: str) -> str:
	files = [f for f in glob.glob(os.path.join(src_dir, "**", "*.glb"), recursive=True) if key in os.path.basename(f)]
	if len(files) != 1:
		raise SystemExit("исходник %r: найдено %d файлов в %s" % (key, len(files), src_dir))
	return files[0]


def load_source(path: str) -> dict:
	"""Меш (все примитивы с одной текстурой — в один), цветовая текстура (PIL)."""
	from PIL import Image
	gltf, binc = pc.read_glb(path)
	pos_l, nrm_l, uv_l, tri_l = [], [], [], []
	img = None
	base = 0
	for ni, node in enumerate(gltf["nodes"]):
		if "mesh" not in node:
			continue
		m = pc.node_matrix(node)
		for prim in gltf["meshes"][node["mesh"]]["primitives"]:
			at = prim["attributes"]
			p = pc.accessor(gltf, binc, at["POSITION"]).astype(np.float64)
			n = pc.accessor(gltf, binc, at["NORMAL"]).astype(np.float64)
			p = p @ m[:3, :3].T + m[:3, 3]
			n = n @ np.linalg.inv(m[:3, :3])
			n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-9)
			pos_l.append(p)
			nrm_l.append(n)
			uv_l.append(pc.accessor(gltf, binc, at["TEXCOORD_0"]).astype(np.float64))
			tri_l.append(pc.accessor(gltf, binc, prim["indices"]).astype(np.int64).reshape(-1, 3) + base)
			base += len(p)
			if img is None:
				mat = gltf["materials"][prim.get("material", 0)]
				ti = mat["pbrMetallicRoughness"]["baseColorTexture"]["index"]
				img = Image.open(io.BytesIO(pc.image_bytes(gltf, binc, gltf["textures"][ti]["source"]))).convert("RGB")
	return {"pos": np.vstack(pos_l), "nrm": np.vstack(nrm_l), "uv": np.vstack(uv_l), "tris": np.vstack(tri_l),
		"img": img}


# ---------- Геометрия ----------

def place(m: dict, cfg: dict) -> dict:
	"""Поворот, масштаб под рамку fit, основание на y = −sink, центр по X/Z (или по всем осям)."""
	a = np.radians(cfg.get("rot", 0))
	# Поворот вокруг Y как Basis(UP, a) в Godot: x' = x cos a + z sin a, z' = −x sin a + z cos a
	R = np.array([[np.cos(a), 0.0, np.sin(a)], [0.0, 1.0, 0.0], [-np.sin(a), 0.0, np.cos(a)]])
	p = m["pos"] @ R.T
	n = m["nrm"] @ R.T
	lo, hi = p.min(0), p.max(0)
	size = hi - lo
	s = min(f / max(d, 1e-9) for f, d in zip(cfg["fit"], size))
	p = (p - (lo + hi) * 0.5) * s
	if not cfg.get("center"):
		p[:, 1] += size[1] * s * 0.5 - cfg.get("sink", 0.0)
	out = dict(m)
	out["pos"] = p
	out["nrm"] = n
	return out


def simplify(m: dict, target: int) -> dict:
	"""Упрощение по форме (meshoptimizer, сваренные позиции, без оглядки на развёртку Meshy — у неё сотни
	мелких островов, которые держат упрощение и рвут текстуру): вершины не сдвигаются, остаются исходные."""
	import ctypes
	from meshoptimizer._loader import lib
	q = np.round(m["pos"] / 1e-5).astype(np.int64)
	_, first, inv = np.unique(q, axis=0, return_index=True, return_inverse=True)
	inv = inv.ravel()
	pos = m["pos"][first]
	t = inv[m["tris"]]
	t = t[(t[:, 0] != t[:, 1]) & (t[:, 1] != t[:, 2]) & (t[:, 2] != t[:, 0])]
	err = 0.0
	if len(t) > target:
		idx = np.ascontiguousarray(t.astype(np.uint32).ravel())
		vp = np.ascontiguousarray(pos.astype(np.float32))
		P = ctypes.POINTER
		fn = lib.meshopt_simplify
		fn.argtypes = [P(ctypes.c_uint), P(ctypes.c_uint), ctypes.c_size_t, P(ctypes.c_float), ctypes.c_size_t,
			ctypes.c_size_t, ctypes.c_size_t, ctypes.c_float, ctypes.c_uint, P(ctypes.c_float)]
		fn.restype = ctypes.c_size_t
		dest = np.zeros(len(idx), dtype=np.uint32)
		e = ctypes.c_float(0.0)
		n = fn(dest.ctypes.data_as(P(ctypes.c_uint)), idx.ctypes.data_as(P(ctypes.c_uint)), len(idx),
			vp.ctypes.data_as(P(ctypes.c_float)), len(vp), 12, target * 3, 1.0, 0, ctypes.byref(e))
		t = dest[:n].astype(np.int64).reshape(-1, 3)
		err = float(e.value)
	# Без вырожденных треугольников, только нужные вершины
	cr = np.linalg.norm(np.cross(pos[t[:, 1]] - pos[t[:, 0]], pos[t[:, 2]] - pos[t[:, 0]]), axis=1)
	t = t[cr > 1e-12]
	used, t2 = np.unique(t.ravel(), return_inverse=True)
	return {"pos": pos[used], "tris": t2.reshape(-1, 3).astype(np.int64), "err": err}


def corner_normals(pos: np.ndarray, tris: np.ndarray, angle: float = 50.0) -> np.ndarray:
	"""Нормали углов треугольников (F×3×3): среднее нормалей соседних граней в пределах angle° от своей —
	плавно на скруглённом, резко на рёбрах (стены, крыши)."""
	fn = np.cross(pos[tris[:, 1]] - pos[tris[:, 0]], pos[tris[:, 2]] - pos[tris[:, 0]])
	fu = fn / np.maximum(np.linalg.norm(fn, axis=1, keepdims=True), 1e-12)
	order = np.argsort(tris.ravel(), kind="stable")
	vs = tris.ravel()[order]
	starts = np.searchsorted(vs, np.arange(len(pos) + 1))
	faces_of = order // 3
	cos = np.cos(np.radians(angle))
	out = np.zeros((len(tris), 3, 3))
	for f in range(len(tris)):
		for k in range(3):
			v = tris[f, k]
			g = faces_of[starts[v]:starts[v + 1]]
			g = g[fu[g] @ fu[f] > cos]
			n = fn[g].sum(0)
			out[f, k] = n / max(np.linalg.norm(n), 1e-12)
	return out


def unwrap(pos: np.ndarray, tris: np.ndarray, size: int) -> dict:
	"""Своя развёртка (xatlas) под клетку size×size: вершины делятся по швам развёртки и по резким рёбрам."""
	import xatlas
	cn = corner_normals(pos, tris)
	atlas = xatlas.Atlas()
	atlas.add_mesh(pos.astype(np.float32), tris.astype(np.uint32))
	po = xatlas.PackOptions()
	po.resolution = size
	po.padding = max(2, size // 128)
	po.bilinear = True
	po.rotate_charts = True
	atlas.generate(xatlas.ChartOptions(), po)
	if atlas.atlas_count != 1:
		raise SystemExit("развёртка не влезла в одну клетку")
	vmap, ind, uvs = atlas[0]
	ind = ind.astype(np.int64)
	# xatlas хранит порядок граней; нормаль угла — из corner_normals, вершины делятся по (вершина развёртки, нормаль)
	keys = {}
	P, N, U, T = [], [], [], []
	for f in range(len(ind)):
		tri = []
		for k in range(3):
			i = int(ind[f, k])
			n = cn[f, k]
			key = (i, int(round(n[0] * 200)), int(round(n[1] * 200)), int(round(n[2] * 200)))
			j = keys.get(key)
			if j is None:
				j = len(P)
				keys[key] = j
				P.append(pos[vmap[i]])
				N.append(n)
				U.append((uvs[i, 0], uvs[i, 1]))
			tri.append(j)
		T.append(tri)
	return {"pos": np.array(P), "nrm": np.array(N), "uv": np.array(U), "tris": np.array(T, dtype=np.int64)}


def surface_samples(src: dict, n: int) -> tuple:
	"""Точки поверхности исходника (по площади), их нормали граней и цвет текстуры."""
	rng = np.random.default_rng(7)
	p, t, uv = src["pos"], src["tris"], src["uv"]
	a, b, c = p[t[:, 0]], p[t[:, 1]], p[t[:, 2]]
	cr = np.cross(b - a, c - a)
	area = 0.5 * np.linalg.norm(cr, axis=1)
	fn = cr / np.maximum(2.0 * area[:, None], 1e-12)
	sel = rng.choice(len(t), n, p=area / area.sum())
	r1, r2 = rng.random(n), rng.random(n)
	flip = r1 + r2 > 1.0
	r1[flip], r2[flip] = 1.0 - r1[flip], 1.0 - r2[flip]
	pts = a[sel] + r1[:, None] * (b - a)[sel] + r2[:, None] * (c - a)[sel]
	ta, tb, tc = uv[t[sel, 0]], uv[t[sel, 1]], uv[t[sel, 2]]
	tuv = ta + r1[:, None] * (tb - ta) + r2[:, None] * (tc - ta)
	tex = src["tex"]
	h, w = tex.shape[:2]
	col = tex[np.clip((tuv[:, 1] % 1.0) * h, 0, h - 1).astype(int), np.clip((tuv[:, 0] % 1.0) * w, 0, w - 1).astype(int)]
	return pts, fn[sel], col.astype(np.float64), float(area.sum())


def bake(src: dict, m: dict, size: int):
	"""Текстура клетки: каждый тексель развёртки упрощённого меша берёт цвет ближайших точек исходника
	(с нормалью в ту же сторону — тонкие доски и листья не берут цвет обратной стороны). Пустое — заливкой
	от ближайшей развёртки (без тёмных швов на мипах)."""
	from PIL import Image
	from scipy import ndimage
	from scipy.spatial import cKDTree
	pos, tris, uv = m["pos"], m["tris"], m["uv"] * size
	fn = np.cross(pos[tris[:, 1]] - pos[tris[:, 0]], pos[tris[:, 2]] - pos[tris[:, 0]])
	fn /= np.maximum(np.linalg.norm(fn, axis=1, keepdims=True), 1e-12)
	pts, nrm, owner = [], [], []
	for f in range(len(tris)):
		q = uv[tris[f]]
		x0, y0 = np.floor(q.min(0)).astype(int)
		x1, y1 = np.ceil(q.max(0)).astype(int)
		x0, y0 = max(x0, 0), max(y0, 0)
		x1, y1 = min(x1, size - 1), min(y1, size - 1)
		if x1 < x0 or y1 < y0:
			continue
		gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
		gx, gy = gx.ravel(), gy.ravel()
		d = (q[1, 1] - q[2, 1]) * (q[0, 0] - q[2, 0]) + (q[2, 0] - q[1, 0]) * (q[0, 1] - q[2, 1])
		if abs(d) < 1e-12:
			continue
		l0 = ((q[1, 1] - q[2, 1]) * (gx - q[2, 0]) + (q[2, 0] - q[1, 0]) * (gy - q[2, 1])) / d
		l1 = ((q[2, 1] - q[0, 1]) * (gx - q[2, 0]) + (q[0, 0] - q[2, 0]) * (gy - q[2, 1])) / d
		l2 = 1.0 - l0 - l1
		e = -0.02
		ins = (l0 >= e) & (l1 >= e) & (l2 >= e)
		if not ins.any():
			continue
		b = np.stack([l0[ins], l1[ins], l2[ins]], 1)
		pts.append(b @ pos[tris[f]])
		nrm.append(np.repeat(fn[f][None], ins.sum(), 0))
		owner.append(np.stack([gy[ins].astype(int), gx[ins].astype(int)], 1))
	pts, nrm, owner = np.vstack(pts), np.vstack(nrm), np.vstack(owner)
	n_samples = int(np.clip(len(pts) * 3, 300000, 3000000))
	sp, sn, sc, _ = surface_samples(src, n_samples)
	tree = cKDTree(sp)
	k = 8
	dist, idx = tree.query(pts, k=k, workers=-1)
	agree = (np.einsum("ijk,ik->ij", sn[idx], nrm) > 0.2).astype(np.float64)
	wgt = agree / (dist + 1e-4)
	none = wgt.sum(1) < 1e-9
	wgt[none, 0] = 1.0
	col = (sc[idx] * wgt[:, :, None]).sum(1) / wgt.sum(1, keepdims=True)
	img = np.zeros((size, size, 3))
	cnt = np.zeros((size, size))
	np.add.at(img, (owner[:, 0], owner[:, 1]), col)
	np.add.at(cnt, (owner[:, 0], owner[:, 1]), 1.0)
	filled = cnt > 0
	img[filled] /= cnt[filled][:, None]
	_, (iy, ix) = ndimage.distance_transform_edt(~filled, return_indices=True)
	img = img[iy, ix]
	return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))


# ---------- Текстура ----------

def glow_weights(tex: np.ndarray, uv: np.ndarray, spec: list) -> np.ndarray:
	"""Свечение вершины 0..1 по цвету текстуры вокруг её UV (среднее 5×5 точек)."""
	if not spec:
		return np.zeros(len(uv))
	h, w = tex.shape[:2]
	acc = np.zeros((len(uv), 3))
	cnt = 0
	for dy in (-2, -1, 0, 1, 2):
		for dx in (-2, -1, 0, 1, 2):
			x = np.clip((uv[:, 0] * w).astype(int) + dx, 0, w - 1)
			y = np.clip((uv[:, 1] * h).astype(int) + dy, 0, h - 1)
			acc += tex[y, x, :3] / 255.0
			cnt += 1
	rgb = acc / cnt
	hsv = np.array([colorsys.rgb_to_hsv(*c) for c in rgb])
	wgt = np.zeros(len(uv))
	for h0, h1, smin, vmin in spec:
		hue = hsv[:, 0]
		ok = (hue >= h0) & (hue <= h1)
		k = ok * np.clip((hsv[:, 1] - smin) / 0.15, 0, 1) * np.clip((hsv[:, 2] - vmin) / 0.12, 0, 1)
		wgt = np.maximum(wgt, k)
	return wgt


# ---------- Атлас ----------

def pack(page: str, ids: list) -> dict:
	"""Клетки страницы: id → (x, y, размер). Клетки — по сетке своего размера (степени двойки)."""
	pw, ph = PAGES[page]
	free = [(0, 0, pw, ph)]
	slots = {}
	for cid in sorted(ids, key=lambda k: -PROPS[k]["tex"]):
		s = PROPS[cid]["tex"]
		best = None
		for i, (x, y, w, h) in enumerate(free):
			if w >= s and h >= s and (best is None or w * h < free[best][2] * free[best][3]):
				best = i
		if best is None:
			raise SystemExit("страница %s переполнена (%s)" % (page, cid))
		x, y, w, h = free.pop(best)
		slots[cid] = (x, y, s)
		# Остаток: справа (полоса высотой s) и снизу — куски по сетке степеней двойки
		if w > s:
			free.append((x + s, y, w - s, s))
		if h > s:
			free.append((x, y + s, w, h - s))
	return slots


# ---------- Запись ----------

def write_glb(path: str, name: str, pos: np.ndarray, nrm: np.ndarray, uv: np.ndarray, glow: np.ndarray,
		tris: np.ndarray) -> None:
	out = bytearray()
	views, accs = [], []

	def put(arr: np.ndarray, target: int, ctype: int, typ: str, minmax: bool = False, norm: bool = False) -> int:
		data = np.ascontiguousarray(arr).tobytes()
		while len(out) % 4:
			out.append(0)
		views.append({"buffer": 0, "byteOffset": len(out), "byteLength": len(data), "target": target})
		out.extend(data)
		a = {"bufferView": len(views) - 1, "componentType": ctype, "count": int(arr.shape[0]), "type": typ}
		if norm:
			a["normalized"] = True
		if minmax:
			a["min"] = [float(v) for v in arr.min(axis=0)]
			a["max"] = [float(v) for v in arr.max(axis=0)]
		accs.append(a)
		return len(accs) - 1

	col = np.ones((len(pos), 4), dtype=np.float64)
	col[:, 3] = glow
	attrs = {
		"POSITION": put(pos.astype(np.float32), 34962, 5126, "VEC3", True),
		"NORMAL": put(nrm.astype(np.float32), 34962, 5126, "VEC3"),
		"TEXCOORD_0": put(uv.astype(np.float32), 34962, 5126, "VEC2"),
		"COLOR_0": put(np.round(col * 255).astype(np.uint8), 34962, 5121, "VEC4", norm=True),
	}
	big = len(pos) >= 65536
	ind = put(tris.astype(np.uint32 if big else np.uint16).ravel(), 34963, 5125 if big else 5123, "SCALAR")
	gltf = {
		"asset": {"version": "2.0", "generator": "MyRappelz tools/prepare_props.py"},
		"scene": 0, "scenes": [{"nodes": [0]}],
		"nodes": [{"name": name, "mesh": 0}],
		"meshes": [{"name": name, "primitives": [{"attributes": attrs, "indices": ind, "material": 0}]}],
		"materials": [{"name": "prop", "pbrMetallicRoughness": {"metallicFactor": 0.0, "roughnessFactor": 1.0}}],
		"accessors": accs, "bufferViews": views,
	}
	while len(out) % 4:
		out.append(0)
	gltf["buffers"] = [{"byteLength": len(out)}]
	js = json.dumps(gltf, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
	js += b" " * ((4 - len(js) % 4) % 4)
	total = 12 + 8 + len(js) + 8 + len(out)
	data = struct.pack("<III", 0x46546C67, 2, total) + struct.pack("<II", len(js), 0x4E4F534A) + js \
		+ struct.pack("<II", len(out), 0x004E4942) + bytes(out)
	with open(path, "wb") as f:
		f.write(data)


def write_import(path: str, template: str) -> None:
	imp = path + ".import"
	if not os.path.exists(imp):
		with open(imp, "w") as f:
			f.write(template.format(name=os.path.basename(path)))


def markers(pos: np.ndarray, glow: np.ndarray) -> dict:
	mk = {}
	if glow.sum() > 0.5:
		w = glow / glow.sum()
		mk["glow"] = [round(float(v), 3) for v in (pos * w[:, None]).sum(0)]
	# Самая передняя точка (+Z) — ступица крыльев мельницы
	zmax = pos[:, 2].max()
	front = pos[pos[:, 2] > zmax - 0.05 * (pos[:, 2].max() - pos[:, 2].min())]
	mk["front"] = [round(float(v), 3) for v in front.mean(0)]
	return mk


def build(src_dir: str, only: list) -> dict:
	from PIL import Image
	os.makedirs(OUT, exist_ok=True)
	meta_path = os.path.join(OUT, "props.json")
	meta = {"pages": {}, "props": {}}
	if os.path.exists(meta_path):
		with open(meta_path) as f:
			meta = json.load(f)
	pages_todo = sorted({PROPS[c]["page"] for c in (only or PROPS)})
	for page in pages_todo:
		ids = [c for c in PROPS if PROPS[c]["page"] == page]
		slots = pack(page, ids)
		pw, ph = PAGES[page]
		atlas = Image.new("RGB", (pw, ph), (128, 128, 128))
		for cid in ids:
			cfg = PROPS[cid]
			path = find_src(src_dir, cfg["src"])
			print("%s ← %s" % (cid, os.path.relpath(path, src_dir)))
			src = place(load_source(path), cfg)
			src["tex"] = np.asarray(src["img"])
			x0, y0, size = slots[cid]
			low = simplify(src, cfg["tris"])
			print("    ошибка упрощения %.4f" % low["err"])
			m = unwrap(low["pos"], low["tris"], size)
			tile = bake(src, m, size)
			atlas.paste(tile, (x0, y0))
			glow = glow_weights(np.asarray(tile), m["uv"], cfg.get("glow", []))
			lamp = None
			if "lamp" in cfg:
				lo, hi = m["pos"].min(0), m["pos"].max(0)
				c = lo + (hi - lo) * np.array(cfg["lamp"][:3])
				r = (hi - lo) * np.array(cfg["lamp"][3:])
				inside = np.all(np.abs(m["pos"] - c) <= r, axis=1)
				glow[inside] = 1.0
				lamp = c
			# После упрощения габариты чуть меньше: сдвиг на место (основание, центр), масштаб прежний
			lo, hi = m["pos"].min(0), m["pos"].max(0)
			shift = -(lo + hi) * 0.5
			if not cfg.get("center"):
				shift[1] = -cfg.get("sink", 0.0) - lo[1]
			m["pos"] = m["pos"] + shift
			if lamp is not None:
				lamp = lamp + shift
			# UV в клетку атласа (у краёв клетки — отступы развёртки xatlas)
			uv = np.clip(m["uv"], 0.0, 1.0)
			au = (x0 + uv[:, 0] * size) / pw
			av = (y0 + uv[:, 1] * size) / ph
			glb = os.path.join(OUT, cid + ".glb")
			write_glb(glb, cid, m["pos"], m["nrm"], np.stack([au, av], 1), glow, m["tris"])
			write_import(glb, GLB_IMPORT)
			lo, hi = m["pos"].min(0), m["pos"].max(0)
			st = pc.mesh_stats(m["pos"], m["tris"])
			meta["props"][cid] = {
				"page": page, "slot": [x0, y0, size], "src": os.path.basename(path),
				"size": [round(float(v), 3) for v in hi - lo],
				"min": [round(float(v), 3) for v in lo], "max": [round(float(v), 3) for v in hi],
				"tris": int(len(m["tris"])), "verts": int(len(m["pos"])), "src_tris": int(len(src["tris"])),
				"open_edges": st["open_edges"], "glow_verts": int((glow > 0.3).sum()),
				"markers": markers(m["pos"], glow),
			}
			if lamp is not None:
				meta["props"][cid]["markers"]["lamp"] = [round(float(v), 3) for v in lamp]
			print("    треугольников %d → %d, размер %s м, светящихся вершин %d, файл %.0f КБ" % (
				len(src["tris"]), len(m["tris"]), " × ".join("%.2f" % v for v in hi - lo),
				int((glow > 0.3).sum()), os.path.getsize(glb) / 1024))
		png = os.path.join(OUT, "props_%s.png" % page)
		atlas.save(png, optimize=True)
		write_import(png, PNG_IMPORT)
		meta["pages"][page] = {"file": os.path.basename(png), "size": [pw, ph]}
		print("страница %s: %dx%d, %.1f МБ" % (page, pw, ph, os.path.getsize(png) / 1e6))
	order = {k: meta["props"][k] for k in PROPS if k in meta["props"]}
	meta["props"] = order
	meta["pages"] = {k: meta["pages"][k] for k in PAGES if k in meta["pages"]}
	with open(meta_path, "w") as f:
		json.dump(meta, f, ensure_ascii=False, indent="\t")
		f.write("\n")
	return meta


# ---------- Проверка и картинки ----------

def read_built(path: str) -> dict:
	gltf, binc = pc.read_glb(path)
	prim = gltf["meshes"][0]["primitives"][0]
	at = prim["attributes"]
	return {"pos": pc.accessor(gltf, binc, at["POSITION"]).astype(np.float64),
		"uv": pc.accessor(gltf, binc, at["TEXCOORD_0"]).astype(np.float64),
		"col": pc.accessor(gltf, binc, at["COLOR_0"]),
		"tris": pc.accessor(gltf, binc, prim["indices"]).astype(np.int64).reshape(-1, 3),
		"images": len(gltf.get("images", []))}


def check(preview: str) -> bool:
	from PIL import Image
	with open(os.path.join(OUT, "props.json")) as f:
		meta = json.load(f)
	ok = True
	total = 0
	pages = {}
	for page, pm in meta["pages"].items():
		p = os.path.join(OUT, pm["file"])
		if not os.path.exists(p) or not os.path.exists(p + ".import"):
			print("ПЛОХО: нет страницы %s" % pm["file"])
			ok = False
			continue
		total += os.path.getsize(p)
		pages[page] = np.asarray(Image.open(p).convert("RGB"))
	for cid, cfg in PROPS.items():
		info = meta["props"].get(cid)
		path = os.path.join(OUT, cid + ".glb")
		if info is None or not os.path.exists(path) or not os.path.exists(path + ".import"):
			print("ПЛОХО: %s — нет модели" % cid)
			ok = False
			continue
		total += os.path.getsize(path)
		m = read_built(path)
		lo, hi = m["pos"].min(0), m["pos"].max(0)
		bad = []
		if m["images"]:
			bad.append("в GLB есть картинки")
		if len(m["tris"]) > cfg["tris"] * 1.25:
			bad.append("треугольников %d > %d" % (len(m["tris"]), cfg["tris"]))
		if np.any(hi - lo > np.array(cfg["fit"]) + 0.01):
			bad.append("не влезает в рамку %s" % (cfg["fit"],))
		if max((hi - lo)[k] / cfg["fit"][k] for k in range(3)) < 0.9:
			bad.append("меньше рамки")
		base = -cfg.get("sink", 0.0)
		if not cfg.get("center") and abs(lo[1] - base) > 0.01:
			bad.append("основание на y = %.3f, а не %.2f" % (lo[1], base))
		if abs(lo[0] + hi[0]) > 0.02 or abs(lo[2] + hi[2]) > 0.02:
			bad.append("не по центру X/Z")
		pw, ph = PAGES[cfg["page"]]
		x0, y0, s = info["slot"]
		u, v = m["uv"][:, 0] * pw, m["uv"][:, 1] * ph
		if u.min() < x0 or u.max() > x0 + s or v.min() < y0 or v.max() > y0 + s:
			bad.append("UV вне своей клетки атласа")
		print("%-18s %-7s %5d тр. %s м %s" % (cid, cfg["page"], len(m["tris"]),
			" × ".join("%5.2f" % d for d in hi - lo), "ok" if not bad else "ПЛОХО: " + "; ".join(bad)))
		ok = ok and not bad
		if preview and cfg["page"] in pages:
			os.makedirs(preview, exist_ok=True)
			write_preview(os.path.join(preview, cid + ".png"), m, pages[cfg["page"]])
	print("Всего в assets/props: %.1f МБ" % (total / 1e6))
	return ok


def write_preview(path: str, m: dict, tex: np.ndarray) -> None:
	"""Спереди (+Z), справа (+X), сзади, сверху; красные точки — светящиеся вершины."""
	from PIL import Image
	panels = []
	box = (m["pos"].min(0) - 0.0, m["pos"].max(0))
	for ang in (0, -90, 180):
		a = np.radians(ang)
		R = np.array([[np.cos(a), 0, np.sin(a)], [0, 1, 0], [-np.sin(a), 0, np.cos(a)]])
		p = m["pos"] @ R.T
		panels.append(pc.render_mesh(p, m["tris"], m["uv"], tex, views=("front",), size=320, samples=300000))
	panels.append(pc.render_mesh(m["pos"], m["tris"], m["uv"], tex, views=("top",), size=320, samples=300000,
		box=box))
	im = Image.new("RGB", (320 * 4, 320), (255, 255, 255))
	for i, p in enumerate(panels):
		im.paste(p, (i * 320, 0))
	im.save(path)


def main() -> None:
	ap = argparse.ArgumentParser(description="Объекты локации из Meshy: упрощение, масштаб, атлас текстур.")
	ap.add_argument("--src", default="", help="папка с GLB из Meshy (поиск во вложенных папках)")
	ap.add_argument("--only", default="", help="id через запятую (их страницы пересобираются целиком)")
	ap.add_argument("--check", action="store_true", help="только проверить готовые assets/props")
	ap.add_argument("--preview", default="", help="папка для картинок-проверок")
	args = ap.parse_args()
	if not args.check:
		if not args.src:
			ap.error("нужна --src <папка с GLB Meshy> или --check")
		only = [s for s in args.only.split(",") if s]
		for s in only:
			if s not in PROPS:
				ap.error("неизвестный объект %r" % s)
		build(args.src, only)
	ok = check(args.preview)
	print("ИТОГ: %s" % ("всё в порядке" if ok else "есть замечания (см. ПЛОХО выше)"))
	sys.exit(0 if ok else 1)


if __name__ == "__main__":
	main()
