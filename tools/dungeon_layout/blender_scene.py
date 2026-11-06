"""Сцена подземелья в Blender — правда о расстановке (0.35.4, решение Максима: «сделай полноценную сцену в блендере
и только потом расставь в игре»).

Сцена собирается из того же, что видит игра: рельеф — сетка мира (dump_grid.gd → --grid: высоты, пол, вода,
палубы, проходимость), вода, модели объектов assets/props/dg_*.glb с атласами, раскладка world/dungeon.json
"props" (её задумывает tools/dungeon_layout/plan.py). Затем объекты «усаживаются» по настоящей геометрии:
  * на пол — по следу основания модели (без щелей снизу), из стены и (кроме водных) из воды — выталкиваются;
  * на стену (факелы, фонари, сети, водоросли-гирлянды) — лучом к ближайшей стене: тыльная сторона модели
    (крепление) прижата к скале, высота крепления своя (WALL);
  * на палубу корабля — по поверхности палубы, снятой лучами с моделей корабля (её же получает игра: decks "ship"
    "surface" — по ней ходит герой, а не по ровной полосе: у носа палуба поднимается, герой проваливался);
  * причалы — верх настила вровень с площадкой.
Твёрдым объектам — форма коллизии по самой модели (призма по выпуклому следу ниже роста героя, "prop_shapes"),
пересекающиеся объекты расталкиваются, проходы между залами проверяются поиском пути. Мосты — свои модели
(dg_bridges.glb: доски поперёк, продольные балки, сваи до дна, перила и верёвка; текстура — доски атласа dg_b с
модели верёвочного моста Максима): прежняя модель моста — наклонный трап, на ровном пролёте конец висел в воздухе.
Итог: --write — world/dungeon.json (props, prop_shapes, поверхность палубы), assets/props/dg_bridges.glb и запись
в props.json; --renders — кадры Eevee (ракурсы VIEWS), --save — сцена .blend.

Запуск (Blender 4.2, рендеру нужен libEGL — под xvfb):
  blender -b --factory-startup --python tools/dungeon_layout/blender_scene.py -- --grid <grid.json> [--write]
    [--renders <папка> [--views имя,имя]] [--save <файл.blend>] [--report <файл>]
"""
import bpy, bmesh, json, math, os, sys, random, struct
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []


def arg(name, default=None):
	return ARGS[ARGS.index(name) + 1] if name in ARGS else default


CFG = json.load(open(ROOT + '/world/dungeon.json'))
PJ = json.load(open(ROOT + '/assets/props/props.json'))
P = PJ['props']
G = json.load(open(arg('--grid', '/tmp/dungeon_grid.json')))
NX, NZ, OX, OZ, STEP = G['nx'], G['nz'], G['ox'], G['oz'], G['step']
H = np.array(G['h'], dtype=np.float64)
FS = np.array(G['fs'], dtype=np.float64)
WS = np.array(G['ws'], dtype=np.float64)
DK = np.array(G['dk'], dtype=np.int64)
WALK = np.array(G['walk'], dtype=np.int64)
WATER_Y = float(CFG.get('water_level', -0.45))
BED = float(CFG.get('water_bed', -1.9))
VOID_Y = float(CFG.get('void_y', -14.0))
rng = random.Random(11)
REPORT = []


def note(*a):
	s = ' '.join(str(x) for x in a)
	REPORT.append(s)
	print('СЦЕНА', s)


# ---------- Сетка мира ----------

def node(x, z):
	i = min(max(int(round((x - OX) / STEP)), 0), NX - 1)
	j = min(max(int(round((z - OZ) / STEP)), 0), NZ - 1)
	return j * NX + i


def gh(x, z, arr=None):
	"""Высота рельефа как IslandWorld.height_at (билинейно по узлам)."""
	a = H if arr is None else arr
	u = (x - OX) / STEP
	v = (z - OZ) / STEP
	i0 = min(max(int(math.floor(u)), 0), NX - 1)
	j0 = min(max(int(math.floor(v)), 0), NZ - 1)
	i1 = min(i0 + 1, NX - 1)
	j1 = min(j0 + 1, NZ - 1)
	fu = min(max(u - i0, 0.0), 1.0)
	fv = min(max(v - j0, 0.0), 1.0)
	p = a[j0 * NX + i0] * (1 - fu) + a[j0 * NX + i1] * fu
	q = a[j1 * NX + i0] * (1 - fu) + a[j1 * NX + i1] * fu
	return p * (1 - fv) + q * fv


def kind(x, z):
	"""Что под точкой: floor (проходимо: пол, берег, палуба), water, wall."""
	k = node(x, z)
	if WALK[k] == 1 or DK[k] >= 0:
		return 'floor'
	if WS[k] <= 0.0:
		return 'water'
	return 'wall'


def to_bl(x, y, z):
	"""Godot (x, y вверх, z) → Blender (x, −z, y)."""
	return (x, -z, y)


# ---------- Модели ----------

def hull2(pts):
	"""Выпуклая оболочка точек [(x, z)] (монотонная цепь), против часовой."""
	pts = sorted(set((round(float(a), 3), round(float(b), 3)) for a, b in pts))
	if len(pts) <= 2:
		return pts

	def cross(o, a, b):
		return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
	lo, up = [], []
	for p in pts:
		while len(lo) >= 2 and cross(lo[-2], lo[-1], p) <= 0:
			lo.pop()
		lo.append(p)
	for p in reversed(pts):
		while len(up) >= 2 and cross(up[-2], up[-1], p) <= 0:
			up.pop()
		up.append(p)
	return lo[:-1] + up[:-1]


def simplify_hull(h, n=16):
	"""Не больше n вершин: выкидываем вершину с наименьшим вкладом в площадь (оболочка остаётся снаружи почти)."""
	h = list(h)
	while len(h) > n:
		best, bi = 1e9, 0
		for i in range(len(h)):
			a, b, c = h[i - 1], h[i], h[(i + 1) % len(h)]
			ar = abs((b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]))
			if ar < best:
				best, bi = ar, i
		h.pop(bi)
	return h


MATS = {}


def page_mat(page):
	if page in MATS:
		return MATS[page]
	m = bpy.data.materials.new('page_' + page)
	m.use_nodes = True
	nt = m.node_tree
	bsdf = nt.nodes['Principled BSDF']
	t = nt.nodes.new('ShaderNodeTexImage')
	t.image = bpy.data.images.load(ROOT + '/assets/props/props_%s.png' % page)
	nt.links.new(t.outputs[0], bsdf.inputs['Base Color'])
	bsdf.inputs['Roughness'].default_value = 0.85
	# свечение — альфа цвета вершин (как prop.gdshader): цвет текстуры × альфа
	attr = nt.nodes.new('ShaderNodeVertexColor')
	mul = nt.nodes.new('ShaderNodeMixRGB')
	mul.blend_type = 'MULTIPLY'
	mul.inputs[0].default_value = 1.0
	nt.links.new(t.outputs[0], mul.inputs[1])
	nt.links.new(attr.outputs['Alpha'], mul.inputs[2])
	nt.links.new(mul.outputs[0], bsdf.inputs['Emission Color'])
	bsdf.inputs['Emission Strength'].default_value = 1.6
	MATS[page] = m
	return m


LIB = {}


def lib(id_):
	"""Меш модели (Blender), её вершины и треугольники в осях Godot, габариты."""
	if id_ in LIB:
		return LIB[id_]
	before = set(bpy.data.objects)
	bpy.ops.import_scene.gltf(filepath=ROOT + '/assets/props/%s.glb' % id_)
	new = [o for o in bpy.data.objects if o not in before]
	ob = [o for o in new if o.type == 'MESH'][0]
	me = ob.data
	me.name = id_
	me.materials.clear()
	me.materials.append(page_mat(P[id_]['page']))
	for o in new:
		bpy.data.objects.remove(o)
	v = np.array([(p.co.x, p.co.z, -p.co.y) for p in me.vertices])
	me.calc_loop_triangles()
	t = np.array([tuple(lt.vertices) for lt in me.loop_triangles], dtype=np.int64)
	e = {'mesh': me, 'v': v, 't': t, 'ymin': float(v[:, 1].min()), 'ymax': float(v[:, 1].max())}
	LIB[id_] = e
	return e


def box_hits(c, nrm, boxes):
	"""Треугольники (центры c, нормали nrm) в коробках prop_cuts (7-е поле — ось: только грани вдоль неё)."""
	hit = np.zeros(len(c), dtype=bool)
	for b in boxes:
		inside = (c[:, 0] >= b[0]) & (c[:, 1] >= b[1]) & (c[:, 2] >= b[2]) & (c[:, 0] <= b[3]) & (c[:, 1] <= b[4]) & (c[:, 2] <= b[5])
		if len(b) > 6 and int(b[6]) > 0:
			inside &= np.abs(nrm[:, int(b[6]) - 1]) > 0.7
		hit |= inside
	return hit


def cut_mesh(id_, boxes):
	"""Копия меша без треугольников с центром в коробках prop_cuts (как DungeonProps.cut_mesh)."""
	e = lib(id_)
	key = id_ + '_cut'
	if key in LIB:
		return LIB[key]
	v, t = e['v'], e['t']
	p = v[t]
	c = p.mean(axis=1)
	nrm = np.cross(p[:, 1] - p[:, 0], p[:, 2] - p[:, 0])
	nrm /= np.linalg.norm(nrm, axis=1)[:, None] + 1e-12
	keep = ~box_hits(c, nrm, boxes)
	me = e['mesh'].copy()
	me.name = key
	me.calc_loop_triangles()
	# грани Blender → треугольники в том же порядке, что и loop_triangles: удаляем грани, у которых все
	# треугольники вырезаны
	dead_poly = {}
	for i, lt in enumerate(me.loop_triangles):
		dead_poly.setdefault(lt.polygon_index, []).append(not keep[i])
	bm = bmesh.new()
	bm.from_mesh(me)
	bm.faces.ensure_lookup_table()
	dead = [bm.faces[pi] for pi, fl in dead_poly.items() if all(fl)]
	bmesh.ops.delete(bm, geom=dead, context='FACES')
	bm.to_mesh(me)
	bm.free()
	LIB[key] = {'mesh': me, 'v': v, 't': t[keep], 'ymin': e['ymin'], 'ymax': e['ymax']}
	return LIB[key]


def model_of(id_):
	cuts = CFG.get('prop_cuts', {})
	return cut_mesh(id_, cuts[id_]) if id_ in cuts else lib(id_)


# ---------- Экземпляр ----------

class Item:
	def __init__(self, a, order):
		self.id = a[0]
		self.x, self.z = float(a[1]), float(a[2])
		self.yaw = float(a[3]) if len(a) > 3 else 0.0
		self.s = float(a[4]) if len(a) > 4 else 1.0
		dy = float(a[5]) if len(a) > 5 else 0.0
		self.sy = float(a[6]) if len(a) > 6 else 1.0
		self.abs = len(a) > 7 and int(a[7]) == 1
		self.rx = float(a[8]) if len(a) > 8 else 0.0
		self.rz = float(a[9]) if len(a) > 9 else 0.0
		self.y = dy if self.abs else gh(self.x, self.z) - 0.04 + dy
		self.order = order
		self.mount = ''
		self.flags = []
		self.drop = ''
		self.wall_n = None
		self.gaps = []

	def basis(self):
		"""Как в игре: Basis(UP, yaw) · Rx(rx) · Rz(rz) · масштаб (s, s·sy, s)."""
		r = math.radians(self.yaw)
		c, sn = math.cos(r), math.sin(r)
		ry = np.array([[c, 0, sn], [0, 1, 0], [-sn, 0, c]])
		a = math.radians(self.rx)
		rx = np.array([[1, 0, 0], [0, math.cos(a), -math.sin(a)], [0, math.sin(a), math.cos(a)]])
		b = math.radians(self.rz)
		rz = np.array([[math.cos(b), -math.sin(b), 0], [math.sin(b), math.cos(b), 0], [0, 0, 1]])
		return ry @ rx @ rz @ np.diag([self.s, self.s * self.sy, self.s])

	def matrix_bl(self):
		"""Матрица объекта Blender (оси Godot → Blender: (x, y, z) → (x, −z, y))."""
		C = np.array([[1, 0, 0], [0, 0, -1], [0, 1, 0]], dtype=float)
		m = C @ self.basis() @ C.T
		M = Matrix(((m[0, 0], m[0, 1], m[0, 2], 0), (m[1, 0], m[1, 1], m[1, 2], 0), (m[2, 0], m[2, 1], m[2, 2], 0), (0, 0, 0, 1)))
		M.translation = Vector(to_bl(self.x, self.y, self.z))
		return M

	def world(self, v):
		return v @ self.basis().T + np.array([self.x, self.y, self.z])

	def foot(self, top=1.8):
		"""Выпуклый след модели (мир, x/z) по вершинам ниже top м над основанием."""
		e = model_of(self.id)
		v = e['v']
		lim = e['ymin'] + top / (self.s * self.sy)
		sel = v[v[:, 1] <= lim]
		if len(sel) < 3:
			sel = v
		w = self.world(sel)
		return hull2(w[:, [0, 2]])

	def contact(self):
		"""След касания пола (вершины в нижних 15 см модели)."""
		e = model_of(self.id)
		v = e['v']
		lim = e['ymin'] + 0.15 / (self.s * self.sy)
		sel = v[v[:, 1] <= lim]
		if len(sel) < 3:
			sel = v[v[:, 1] <= e['ymin'] + 0.3 * (e['ymax'] - e['ymin'])]
		w = self.world(sel)
		return hull2(w[:, [0, 2]])

	def height(self):
		e = model_of(self.id)
		return (e['ymax'] - e['ymin']) * self.s * self.sy

	def entry(self):
		dy = round(self.y - gh(self.x, self.z) + 0.04, 3)
		out = [self.id, round(self.x, 2), round(self.z, 2), round(self.yaw % 360, 1), round(self.s, 3)]
		if abs(self.rx) > 0.05 or abs(self.rz) > 0.05:
			return out + [round(self.y, 3) if self.abs else dy, round(self.sy, 3), 1 if self.abs else 0,
				round(self.rx, 1), round(self.rz, 1)]
		if self.abs:
			out += [round(self.y, 3), round(self.sy, 3), 1]
		elif abs(self.sy - 1.0) > 1e-4:
			out += [dy, round(self.sy, 3)]
		elif abs(dy) > 0.005:
			out.append(dy)
		return out


def poly_samples(poly, center, step=0.35):
	"""Точки по контуру и внутри многоугольника."""
	pts = [center]
	n = len(poly)
	for i in range(n):
		a, b = poly[i], poly[(i + 1) % n]
		L = math.hypot(b[0] - a[0], b[1] - a[1])
		k = max(1, int(L / step))
		for j in range(k):
			t = j / k
			pts.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
	for p in list(pts[1:]):
		pts.append(((p[0] + center[0]) * 0.5, (p[1] + center[1]) * 0.5))
	return pts


# ---------- Что как крепится ----------

## На стене: id → [ось тыльной стороны модели (Godot), высота основания над полом, м]
WALL = {
	'dg_torch': [(1.0, 0.0, 0.0), 1.05],
	'dg_lantern': [(0.0, 0.0, -1.0), 1.6],
	'dg_net': [(0.0, 0.0, -1.0), 0.45],
	'dg_banner': [(0.0, 0.0, -1.0), 1.3],
}
## Корабль и его детали — без усадки на пол (свои правила): корпус, фигура на носу
SHIP_HULL = {'dg_ship_deck', 'dg_ship_bow', 'dg_wreck'}
## Можно стоять в воде (на дне)
WATER_OK = {'dg_kelp', 'dg_coral', 'dg_crystal_purple', 'dg_crystal_blue', 'dg_dripstone', 'dg_leviathan', 'dg_anchor',
	'dg_mast_relic', 'dg_siren', 'dg_tidepool'}
## Держатся на воде (осадка, м)
FLOAT = {'dg_rowboat': 0.35, 'dg_raft': 0.22}
## Плоское — можно класть на/под другое, без коллизии
FLAT = {'dg_prayer_rug', 'dg_bearskin', 'dg_bedroll', 'dg_gold', 'dg_remains', 'dg_mariner', 'dg_mossy_remains',
	'dg_stone_ring', 'dg_nest', 'dg_spiral_flat'}
## Без коллизии, хотя не плоское (сквозь него ходят: водоросли, сети, мачты — у мачт свой столб)
NO_SOLID = {'dg_kelp', 'dg_banner', 'dg_net', 'dg_torch', 'dg_lantern', 'dg_coral'} | FLAT
## Мачты: коллизия — столб у основания (радиус, м, при масштабе 1)
POLES = {'dg_mast': 0.16, 'dg_crows_nest': 0.14}


## Стоят как задуманы (встроены в рельеф): лестница к порталу над пандусом, завал шахты в стене
FIXED = {'dg_ascent', 'dg_mine'}


def mount_of(it, surface):
	if it.id in SHIP_HULL:
		return 'hull'
	if it.id in FIXED:
		return 'fixed'
	if it.id == 'dg_pier':
		return 'pier'
	if it.id in WALL:
		return 'wall'
	if it.id in FLOAT:
		return 'float'
	if surface is not None and surface.inside(it.x, it.z):
		return 'deck'
	return 'floor'


# ---------- Рельеф и вода в сцене ----------

def build_terrain():
	"""Меш рельефа (как DungeonWorld._dungeon_chunk: пустота и доски палуб не рисуются) и вода."""
	verts, faces, mats = [], [], []
	for j in range(NZ):
		for i in range(NX):
			k = j * NX + i
			verts.append(to_bl(OX + i * STEP, H[k], OZ + j * STEP))
	gverts = []
	gfaces = []
	for j in range(NX * 0, NZ):
		for i in range(NX):
			k = j * NX + i
			gverts.append((OX + i * STEP, H[k], OZ + j * STEP))
	for j in range(NZ - 1):
		for i in range(NX - 1):
			a = j * NX + i
			b = a + NX
			q = [a, a + 1, b + 1, b]
			if max(H[c] for c in q) <= VOID_Y + 0.5:
				continue
			gfaces.append((a, b, a + 1))
			gfaces.append((a + 1, b, b + 1))
			if any(DK[c] >= 0 and not CFG['decks'][DK[c]].get('kind') == 'stone' for c in q):
				continue
			faces.append(q)
			hs = [H[c] for c in q]
			if all(WS[c] <= 0.0 for c in q):
				mats.append(2)
			elif max(hs) - min(hs) > 0.9 or all(WALK[c] == 0 and WS[c] > 0.4 for c in q):
				mats.append(1)
			else:
				mats.append(0)
	me = bpy.data.meshes.new('terrain')
	me.from_pydata(verts, [], faces)
	for nm, col in [('floor', (0.1, 0.095, 0.13)), ('wall', (0.075, 0.07, 0.1)), ('bed', (0.03, 0.06, 0.06))]:
		m = bpy.data.materials.new('t_' + nm)
		m.use_nodes = True
		b = m.node_tree.nodes['Principled BSDF']
		b.inputs['Base Color'].default_value = col + (1.0,)
		b.inputs['Roughness'].default_value = 0.95
		me.materials.append(m)
	for f, m in zip(me.polygons, mats):
		f.material_index = m
		f.use_smooth = True
	ob = bpy.data.objects.new('Terrain', me)
	bpy.context.scene.collection.objects.link(ob)
	# вода: квадраты, где хоть один угол — вода (как DungeonWater, + под досками палуб)
	wv, wf, idx = [], [], {}
	for j in range(NZ - 1):
		for i in range(NX - 1):
			q = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
			if not any(WS[b * NX + a] < 1.5 for a, b in q):
				continue
			ids = []
			for a, b in q:
				if (a, b) not in idx:
					idx[(a, b)] = len(wv)
					wv.append(to_bl(OX + a * STEP, WATER_Y, OZ + b * STEP))
				ids.append(idx[(a, b)])
			wf.append(ids)
	wm = bpy.data.meshes.new('water')
	wm.from_pydata(wv, [], wf)
	m = bpy.data.materials.new('water')
	m.use_nodes = True
	b = m.node_tree.nodes['Principled BSDF']
	b.inputs['Base Color'].default_value = (0.05, 0.35, 0.33, 1)
	b.inputs['Emission Color'].default_value = (0.05, 0.5, 0.4, 1)
	b.inputs['Emission Strength'].default_value = 0.35
	b.inputs['Roughness'].default_value = 0.15
	b.inputs['Alpha'].default_value = 0.85
	wm.materials.append(m)
	wo = bpy.data.objects.new('Water', wm)
	bpy.context.scene.collection.objects.link(wo)
	return BVHTree.FromPolygons(gverts, gfaces)


# ---------- Палуба корабля ----------

class Surface:
	"""Поверхность палубы (Godot): сетка step, h — высота или None."""

	def __init__(self, ox, oz, step, nx, nz, h):
		self.ox, self.oz, self.step, self.nx, self.nz, self.h = ox, oz, step, nx, nz, h

	def at(self, x, z):
		i = int(round((x - self.ox) / self.step))
		j = int(round((z - self.oz) / self.step))
		if i < 0 or j < 0 or i >= self.nx or j >= self.nz:
			return None
		return self.h[j * self.nx + i]

	def inside(self, x, z):
		return self.at(x, z) is not None

	def to_cfg(self):
		return {'ox': self.ox, 'oz': self.oz, 'step': self.step, 'nx': self.nx, 'nz': self.nz,
			'h': [(-99 if v is None else round(v, 2)) for v in self.h]}


def ship_surface(items):
	"""Палуба: лучи сверху вниз по моделям корпуса — первая обращённая вверх грань в полосе высот палубы; выступы
	(кабестаны, комингсы) выше соседей — препятствия; от края (фальшборт) — отступ."""
	verts, tris = [], []
	for it in items:
		if it.id not in SHIP_HULL:
			continue
		e = model_of(it.id)
		w = it.world(e['v'])
		base = len(verts)
		verts += [tuple(p) for p in w]
		tris += [tuple(int(c) + base for c in t) for t in e['t']]
	bvh = BVHTree.FromPolygons(verts, tris)
	ox, oz, step = 25.0, 13.2, 0.5
	nx, nz = int((39.0 - ox) / step) + 1, int((60.0 - oz) / step) + 1
	raw = [None] * (nx * nz)
	for j in range(nz):
		for i in range(nx):
			x, z = ox + i * step, oz + j * step
			o = Vector((x, 9.5, z))
			d = Vector((0, -1, 0))
			first = None
			for _ in range(12):
				hit = bvh.ray_cast(o, d, 12.0)
				if hit[0] is None:
					break
				p, n = hit[0], hit[1]
				if first is None:
					first = p.y
				if p.y < 0.2:
					break
				if n.y > 0.75 and p.y < 2.6:
					# под крышей или навесом (внутри рубки, под фальшбортом) — не палуба
					if first < p.y + 2.2 and first > p.y + 0.05 or first >= p.y + 2.2 and first < p.y + 6.0:
						break
					raw[j * nx + i] = p.y
					break
				o = p + d * 0.02
	h = list(raw)
	# выступы над соседями (кабестаны, комингсы) — препятствия
	for _pass in range(2):
		nh = list(h)
		for j in range(nz):
			for i in range(nx):
				k = j * nx + i
				if h[k] is None:
					continue
				nb = [h[b * nx + a] for a in range(i - 2, i + 3) for b in range(j - 2, j + 3)
					if 0 <= a < nx and 0 <= b < nz and (a, b) != (i, j) and h[b * nx + a] is not None]
				if len(nb) >= 6 and h[k] - sorted(nb)[len(nb) // 2] > 0.3:
					nh[k] = None
		h = nh
	# щели между досками решётки (одна точка, вокруг палуба) — заполнить; пробоина шире — остаётся дырой
	nh = list(h)
	for j in range(1, nz - 1):
		for i in range(1, nx - 1):
			if h[j * nx + i] is not None:
				continue
			nb = [h[b * nx + a] for a in range(i - 1, i + 2) for b in range(j - 1, j + 2) if h[b * nx + a] is not None]
			if len(nb) >= 6:
				nh[j * nx + i] = sorted(nb)[len(nb) // 2]
	h = nh
	# связная часть с точкой у двери рубки и отступ от края 0.6 м
	start = (int(round((32.0 - ox) / step)), int(round((20.0 - oz) / step)))
	seen = set()
	stack = [start] if h[start[1] * nx + start[0]] is not None else []
	while stack:
		i, j = stack.pop()
		if (i, j) in seen:
			continue
		seen.add((i, j))
		for a, b in ((i + 1, j), (i - 1, j), (i, j + 1), (i, j - 1)):
			if 0 <= a < nx and 0 <= b < nz and (a, b) not in seen:
				k, k0 = b * nx + a, j * nx + i
				if h[k] is not None and abs(h[k] - h[k0]) < 0.25:
					stack.append((a, b))
	out = [None] * (nx * nz)
	edge = 1
	for (i, j) in seen:
		ok = all((a, b) in seen for a in range(i - edge, i + edge + 1) for b in range(j - edge, j + edge + 1))
		if ok:
			out[j * nx + i] = h[j * nx + i]
	# сглаживание (доски не ступеньками)
	sm = list(out)
	for j in range(nz):
		for i in range(nx):
			k = j * nx + i
			if out[k] is None:
				continue
			nb = [out[b * nx + a] for a in range(i - 1, i + 2) for b in range(j - 1, j + 2)
				if 0 <= a < nx and 0 <= b < nz and out[b * nx + a] is not None]
			sm[k] = sum(nb) / len(nb)
	s = Surface(ox, oz, step, nx, nz, sm)
	cnt = sum(1 for v in sm if v is not None)
	hs = [v for v in sm if v is not None]
	note('палуба: %d точек по 0.5 м, высота %.2f…%.2f' % (cnt, min(hs), max(hs)))
	return s


# ---------- Усадка ----------

def floor_ok(it, allow):
	poly = it.contact()
	cx = sum(p[0] for p in poly) / len(poly)
	cz = sum(p[1] for p in poly) / len(poly)
	return [p for p in poly_samples(poly, (cx, cz), 0.3) if kind(p[0], p[1]) not in allow], poly, (cx, cz)


def settle_floor(it, allow, quiet=False):
	"""На пол: выталкивание из стены (и воды) — сначала по сумме направлений от плохих точек (до 3 м), не вышло —
	ближайшее свободное место по спирали (до 7 м); основание — по самой низкой точке следа касания."""
	x0, z0 = it.x, it.z
	ok = True
	for _ in range(20):
		bad, poly, (cx, cz) = floor_ok(it, allow)
		if not bad:
			break
		dx = sum(cx - p[0] for p in bad)
		dz = sum(cz - p[1] for p in bad)
		L = math.hypot(dx, dz)
		if L < 1e-6:
			break
		it.x += dx / L * 0.15
		it.z += dz / L * 0.15
	else:
		ok = False
	if not ok or floor_ok(it, allow)[0]:
		it.x, it.z = x0, z0
		found = None
		for r10 in range(2, 71, 2):
			r = r10 / 10.0
			for a in range(0, 360, 15):
				it.x = x0 + r * math.cos(math.radians(a))
				it.z = z0 + r * math.sin(math.radians(a))
				if not floor_ok(it, allow)[0]:
					found = (it.x, it.z)
					break
			if found:
				break
		if found:
			it.x, it.z = found
		else:
			it.x, it.z = x0, z0
			it.drop = 'нет места на полу'
	moved = math.hypot(it.x - x0, it.z - z0)
	if moved > 0.05 and not quiet:
		it.flags.append('от стены на %.1f м' % moved)
	poly = it.contact()
	cx = sum(p[0] for p in poly) / len(poly)
	cz = sum(p[1] for p in poly) / len(poly)
	hs = [gh(p[0], p[1]) for p in poly_samples(poly, (cx, cz), 0.3)]
	e = model_of(it.id)
	it.y = min(hs) - 0.03 - e['ymin'] * it.s * it.sy


## Высоты крепления на стене, которые пробуются (основание над полом, м): выбирается та, где тыльная сторона ближе
## всего к скале по всей своей высоте (скала у подножия наклонная и гранёная — сетка рельефа 1 м)
WALL_TRY = {'dg_torch': (0.9, 2.6), 'dg_lantern': (1.3, 2.6), 'dg_net': (0.2, 1.2), 'dg_banner': (0.8, 2.2)}


def settle_wall(it, bvh):
	"""На стену: тыльная сторона (крепление) к ближайшей скале, высота — по наименьшему зазору."""
	axis, h0 = WALL[it.id]
	it.rx = it.rz = 0.0
	if kind(it.x, it.z) != 'floor':
		settle_floor(it, {'floor'})
	f = gh(it.x, it.z)
	best = None
	for hh in (1.6, 1.0, 2.4):
		for a in range(0, 360, 4):
			d = Vector((math.cos(math.radians(a)), 0, math.sin(math.radians(a))))
			hit = bvh.ray_cast(Vector((it.x, f + hh, it.z)), d, 7.0)
			if hit[0] is None:
				continue
			n = Vector((hit[1].x, 0, hit[1].z))
			if n.length < 0.3:
				continue
			if best is None or hit[3] < best[2]:
				best = (hit[0], n.normalized(), hit[3])
		if best is not None:
			break
	if best is None:
		it.flags.append('стены рядом нет — на полу')
		settle_floor(it, {'floor'})
		return
	n = best[1]
	it.wall_n = (n.x, n.z)
	if axis[0] > 0.5:
		it.yaw = math.degrees(math.atan2(n.z, -n.x))
	else:
		it.yaw = math.degrees(math.atan2(n.x, n.z))
	e = model_of(it.id)
	v = e['v']
	bl = np.array(axis, dtype=float)
	back = v @ bl
	sel = v[back > back.max() - 0.12 * np.ptp(back)]
	if len(sel) > 80:
		sel = sel[np.linspace(0, len(sel) - 1, 80).astype(int)]
	wd = Vector((-n.x, 0, -n.z))
	tg = Vector((-n.z, 0, n.x))
	lo, hi = WALL_TRY[it.id]
	cand = []
	spots = []
	for sh in (0.0, 0.6, -0.6, 1.2, -1.2):
		o = best[0] + n * 1.0 + tg * sh
		fo = gh(o.x, o.z)
		hit = bvh.ray_cast(Vector((o.x, fo + 1.6, o.z)), wd, 3.0)
		if hit[0] is not None and kind(o.x, o.z) == 'floor':
			spots.append((sh, hit[0], fo))
	if not spots:
		spots = [(0.0, best[0], f)]
	for sh, H0, fs in spots:
		for hh in np.arange(lo, hi + 1e-6, 0.1):
			it.y = fs + hh - e['ymin'] * it.s * it.sy
			ext = float(back.max()) * it.s
			it.x = H0.x + n.x * (ext + 0.5)
			it.z = H0.z + n.z * (ext + 0.5)
			gaps = None
			for _ in range(3):
				w = it.world(sel)
				gaps = []
				for q in w:
					o = Vector((q[0] - wd.x * 0.6, q[1], q[2] - wd.z * 0.6))
					hit = bvh.ray_cast(o, wd, 3.0)
					gaps.append((hit[3] - 0.6) if hit[0] is not None else 2.4)
				mv = min(gaps) - 0.03
				if abs(mv) < 0.01:
					break
				it.x += wd.x * mv
				it.z += wd.z * mv
			w = it.world(sel)
			gaps = []
			for q in w:
				o = Vector((q[0] - wd.x * 0.6, q[1], q[2] - wd.z * 0.6))
				hit = bvh.ray_cast(o, wd, 3.0)
				gaps.append((hit[3] - 0.6) if hit[0] is not None else 2.4)
			cand.append((max(gaps) + 0.05 * abs(hh - h0) + 0.05 * abs(sh), hh, it.x, it.z, it.y, min(gaps), max(gaps)))
	cand.sort()
	_, hh, it.x, it.z, it.y, gmin, gmax = cand[0]
	# наклон вместе со скалой: ось наклона — горизонтальная вдоль стены (у факела тыльная ось X — наклон вокруг Z,
	# у остальных тыльная −Z — вокруг X); знак и угол — по наименьшему зазору (до 25°)
	base = (it.x, it.z, it.y)

	def gaps_now():
		for _ in range(3):
			w = it.world(sel)
			g = []
			for q in w:
				o = Vector((q[0] - wd.x * 0.6, q[1], q[2] - wd.z * 0.6))
				hit = bvh.ray_cast(o, wd, 3.0)
				g.append((hit[3] - 0.6) if hit[0] is not None else 2.4)
			mv = min(g) - 0.03
			if abs(mv) < 0.01:
				return g
			it.x += wd.x * mv
			it.z += wd.z * mv
		return g
	best_t = (gmax, 0.0, base)
	for ang in range(-25, 26, 2):
		it.x, it.z, it.y = base
		if axis[0] > 0.5:
			it.rx, it.rz = 0.0, float(ang)
		else:
			it.rx, it.rz = float(ang), 0.0
		g = gaps_now()
		score = max(g) + 0.004 * abs(ang)
		if score < best_t[0] + 0.004 * abs(best_t[1]):
			best_t = (max(g), float(ang), (it.x, it.z, it.y), min(g))
	ang = best_t[1]
	if axis[0] > 0.5:
		it.rx, it.rz = 0.0, ang
	else:
		it.rx, it.rz = ang, 0.0
	it.x, it.z, it.y = best_t[2]
	gmax = best_t[0]
	it.gaps = [gmin, gmax]
	B = it.basis()
	o3 = np.array([it.x, it.y, it.z]) + B @ np.array([0, 0.3, 0])
	dx = B @ np.array([1.0, 0, 0])
	dx /= np.linalg.norm(dx)
	th = bvh.ray_cast(Vector(o3), Vector(dx), 2.0)
	note('%s (%.1f, %.1f) на стене: высота %.1f м, наклон %.0f°, зазор тыльной стороны до %.2f м, луч теста %.2f' % (it.id,
		it.x, it.z, hh, it.rx + it.rz, gmax, th[3] if th[0] is not None else -1))


def settle_deck(it, surf):
	poly = it.contact()
	cx = sum(p[0] for p in poly) / len(poly)
	cz = sum(p[1] for p in poly) / len(poly)
	hs = [surf.at(*p) for p in poly_samples(poly, (cx, cz), 0.3)]
	hs = [v for v in hs if v is not None]
	if it.id in POLES:
		# мачта: основание столба
		bx, bz = pole_base(it)
		v = surf.at(bx, bz)
		hs = [v] if v is not None else hs
	e = model_of(it.id)
	if not hs:
		it.flags.append('не на палубе')
		return
	it.y = min(hs) - 0.03 - e['ymin'] * it.s * it.sy
	it.abs = True


def pole_base(it):
	e = model_of(it.id)
	v = e['v']
	low = v[v[:, 1] <= e['ymin'] + 0.12 * (e['ymax'] - e['ymin'])]
	c = it.world(low).mean(axis=0)
	return float(c[0]), float(c[2])


def settle_pier(it, deck_h):
	e = model_of(it.id)
	tri = BVHTree.FromPolygons([tuple(p) for p in e['v']], [tuple(t) for t in e['t']])
	hit = tri.ray_cast(Vector((0.0, e['ymax'] + 1, 0.0)), Vector((0, -1, 0)), 20)
	top = hit[0].y if hit[0] is not None else e['ymax'] * 0.7
	it.y = deck_h - top * it.s
	it.abs = True


# ---------- Пересечения ----------

def sat(a, b):
	"""Пересечение выпуклых многоугольников: (глубина, ось) минимального выталкивания b из a или None."""
	best = None
	for poly in (a, b):
		n = len(poly)
		for i in range(n):
			p, q = poly[i], poly[(i + 1) % n]
			ax = (q[1] - p[1], -(q[0] - p[0]))
			L = math.hypot(*ax)
			if L < 1e-9:
				continue
			ax = (ax[0] / L, ax[1] / L)
			pa = [x * ax[0] + y * ax[1] for x, y in a]
			pb = [x * ax[0] + y * ax[1] for x, y in b]
			o = min(max(pa), max(pb)) - max(min(pa), min(pb))
			if o <= 0:
				return None
			if best is None or o < best[0]:
				best = (o, ax)
	return best


def area(poly):
	return abs(sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1]
		for i in range(len(poly)))) * 0.5


## Мелкий декор: если ему не нашлось места (упирается и в стену, и в соседа) — убирается
DECOR = {'dg_glowcaps', 'dg_coral', 'dg_kelp', 'dg_crystal_blue', 'dg_crystal_purple', 'dg_candles', 'dg_remains',
	'dg_mossy_remains', 'dg_moss_stones', 'dg_relics', 'dg_spoils', 'dg_barrel', 'dg_crates', 'dg_lantern'}


def separate(items, surf):
	"""Твёрдые и заметные объекты не пересекаются (кроме плоского): сдвигаются оба по оси выталкивания (меньший —
	сильнее); пара, что не расходится за 30 раундов, — меньший декор убирается."""
	mov = [it for it in items if it.mount in ('floor', 'deck') and it.id not in FLAT and not it.drop]
	stuck = {}
	for rnd in range(80):
		polys = {id(it): it.foot() for it in mov}
		hits = 0
		for i in range(len(mov)):
			for j in range(i + 1, len(mov)):
				a, b = mov[i], mov[j]
				if a.drop or b.drop:
					continue
				pa, pb = polys[id(a)], polys[id(b)]
				if len(pa) < 3 or len(pb) < 3:
					continue
				r = sat(pa, pb)
				if r is None or r[0] < 0.06:
					continue
				hits += 1
				key = (id(a), id(b))
				stuck[key] = stuck.get(key, 0) + 1
				aa, ab = area(pa), area(pb)
				small, big = (a, b) if aa < ab else (b, a)
				if stuck[key] > 30 and small.id in DECOR:
					small.drop = 'нет места рядом с ' + big.id
					continue
				ax = r[1]
				cs = (small.x - big.x) * ax[0] + (small.z - big.z) * ax[1]
				sg = 1.0 if cs >= 0 else -1.0
				d = r[0] + 0.08
				ws = max(aa, ab) / (aa + ab)
				for obj, k in ((small, ws), (big, -(1.0 - ws))):
					if obj.mount == 'deck' or obj.id in BIG_KEEP:
						continue
					obj.x += ax[0] * d * k * sg
					obj.z += ax[1] * d * k * sg
					settle_floor(obj, allow_of(obj), True)
					polys[id(obj)] = obj.foot()
				if small.mount == 'deck':
					small.x += ax[0] * d * sg
					small.z += ax[1] * d * sg
					settle_deck(small, surf)
					if not surf.inside(small.x, small.z):
						small.drop = 'нет места на палубе'
					polys[id(small)] = small.foot()
		if hits == 0:
			note('пересечений нет (раундов %d)' % rnd)
			return
	note('пересечения остались после 80 раундов')


## Главные объекты зон не двигаются при расталкивании (сдвигается сосед)
BIG_KEEP = {'dg_coral_altar', 'dg_throne', 'dg_mine', 'dg_ascent', 'dg_crypt_altar', 'dg_tent', 'dg_cauldron'}


def allow_of(it):
	return {'floor', 'water'} if it.id in WATER_OK else {'floor'}


# ---------- Мосты ----------

# Участки атласа dg_b (пиксели 4096): доски поперёк (волокна вдоль u), брус (волокна вдоль v), верёвка
PLANK_RECT = (3072 + 396, 232, 3072 + 528, 560)
POST_RECT = (3072 + 568, 232, 3072 + 652, 548)
ROPE_RECT = (3072 + 848, 30, 3072 + 878, 690)
OVER_WATER = 0.3


def ground_or_deck(p, surf):
	for d in CFG['decks']:
		if 'surface' in d or d.get('id') == 'ship':
			v = surf.at(p[0], p[1]) if surf else None
			if v is not None:
				return v
			continue
		if shape_sd(d, p) < 0:
			return float(d.get('height', 0.3))
	return gh(*p)


def shape_sd(d, p):
	if d.get('shape', 'path' if 'points' in d else 'ellipse') == 'path':
		pts = d['points']
		half = float(d.get('width', 4.0)) * 0.5
		best = 1e9
		for i in range(len(pts) - 1):
			a, b = pts[i], pts[i + 1]
			ab = (b[0] - a[0], b[1] - a[1])
			L2 = max(ab[0] ** 2 + ab[1] ** 2, 1e-4)
			t = min(max(((p[0] - a[0]) * ab[0] + (p[1] - a[1]) * ab[1]) / L2, 0), 1)
			best = min(best, math.hypot(p[0] - a[0] - ab[0] * t, p[1] - a[1] - ab[1] * t))
		return best - half
	c = d['center']
	r = d.get('radius', [5, 5])
	rot = math.radians(float(d.get('rot', 0.0)))
	qx, qz = p[0] - c[0], p[1] - c[1]
	qx, qz = qx * math.cos(-rot) - qz * math.sin(-rot), qx * math.sin(-rot) + qz * math.cos(-rot)
	k = math.hypot(qx / r[0], qz / r[1])
	return (k - 1.0) * min(r[0], r[1])


def bridge_profile(br, surf, n=16):
	"""Настил как DungeonWorld._find_dungeon_bridges: прямая от конца к концу, над водой не ниже воды + OVER_WATER."""
	a, b = br['a'], br['b']
	ya = ground_or_deck(a, surf) - 0.03
	yb = ground_or_deck(b, surf) - 0.03
	d = [ya + (yb - ya) * i / n for i in range(n + 1)]
	for i in range(1, n):
		d[i] = max(d[i], WATER_Y + OVER_WATER)
	for _ in range(2):
		sm = list(d)
		for i in range(1, n):
			sm[i] = max(d[i - 1] * 0.25 + d[i] * 0.5 + d[i + 1] * 0.25, WATER_Y + OVER_WATER - 0.05)
		d = sm
	return d


class Geo:
	"""Меш мостов: вершины (Godot), нормали, UV (пиксели атласа → 0..1), треугольники."""

	def __init__(self):
		self.p, self.n, self.uv, self.t = [], [], [], []

	def quad(self, a, b, c, d, uva, uvb, uvc, uvd):
		nn = np.cross(np.subtract(b, a), np.subtract(d, a))
		L = np.linalg.norm(nn)
		nn = nn / L if L > 1e-9 else np.array([0, 1, 0])
		k = len(self.p)
		for q, u in ((a, uva), (b, uvb), (c, uvc), (d, uvd)):
			self.p.append(tuple(q))
			self.n.append(tuple(nn))
			self.uv.append((u[0] / 4096.0, u[1] / 4096.0))
		# Godot: лицевая — по часовой при взгляде снаружи; квадрат задан против часовой (a, b, c, d при взгляде
		# снаружи) — треугольники в обратном порядке
		self.t += [(k, k + 2, k + 1), (k, k + 3, k + 2)]

	def box(self, c, ax_u, ax_v, ax_w, su, sv, sw, rect, grain='u', rnd=None):
		"""Брус: центр c, оси (единичные) u — длина, v — вверх, w — ширина; размеры; грани с текстурой rect:
		вдоль волокон — длинная ось u."""
		c = np.array(c, dtype=float)
		u, v, w = (np.array(x, dtype=float) for x in (ax_u, ax_v, ax_w))
		hu, hv, hw = u * su / 2, v * sv / 2, w * sw / 2
		x0, y0, x1, y1 = rect
		r = rnd or rng
		# полоса текстуры: по длине — весь участок, поперёк — случайная полоса шириной ~ пропорционально
		if grain == 'u':
			bh = max(10, min(y1 - y0, int((y1 - y0) * 0.14)))
			by = r.uniform(y0, y1 - bh)
			band = lambda: ((x0, by), (x1, by), (x1, by + bh), (x0, by + bh))
		else:
			bw = max(8, (x1 - x0) * 0.5)
			bx = r.uniform(x0, x1 - bw)
			band = lambda: ((bx, y1), (bx, y0), (bx + bw, y0), (bx + bw, y1))
		uv = band()
		P_ = lambda su_, sv_, sw_: c + hu * su_ + hv * sv_ + hw * sw_
		# верх, низ, бока вдоль длины, торцы
		self.quad(P_(-1, 1, 1), P_(1, 1, 1), P_(1, 1, -1), P_(-1, 1, -1), *uv)
		self.quad(P_(-1, -1, -1), P_(1, -1, -1), P_(1, -1, 1), P_(-1, -1, 1), *uv)
		self.quad(P_(-1, -1, 1), P_(1, -1, 1), P_(1, 1, 1), P_(-1, 1, 1), *uv)
		self.quad(P_(1, -1, -1), P_(-1, -1, -1), P_(-1, 1, -1), P_(1, 1, -1), *uv)
		e = uv[0], uv[0], uv[3], uv[3]
		small = ((uv[0][0], uv[0][1]), (uv[0][0] + 6, uv[0][1]), (uv[0][0] + 6, uv[3][1]), (uv[0][0], uv[3][1]))
		self.quad(P_(1, -1, 1), P_(1, -1, -1), P_(1, 1, -1), P_(1, 1, 1), *small)
		self.quad(P_(-1, -1, -1), P_(-1, -1, 1), P_(-1, 1, 1), P_(-1, 1, -1), *small)

	def tube(self, a, b, r, rect, sides=6):
		a, b = np.array(a, float), np.array(b, float)
		d = b - a
		L = np.linalg.norm(d)
		d = d / L
		up = np.array([0, 1, 0]) if abs(d[1]) < 0.9 else np.array([1, 0, 0])
		e1 = np.cross(d, up)
		e1 /= np.linalg.norm(e1)
		e2 = np.cross(d, e1)
		x0, y0, x1, y1 = rect
		for k in range(sides):
			t0, t1 = 2 * math.pi * k / sides, 2 * math.pi * (k + 1) / sides
			o0 = (math.cos(t0) * e1 + math.sin(t0) * e2) * r
			o1 = (math.cos(t1) * e1 + math.sin(t1) * e2) * r
			ux0 = x0 + (x1 - x0) * k / sides
			ux1 = x0 + (x1 - x0) * (k + 1) / sides
			self.quad(a + o0, a + o1, b + o1, b + o0, (ux0, y1), (ux1, y1), (ux1, y0), (ux0, y0))


def build_bridges(surf):
	g = Geo()
	r = random.Random(5)
	for bi, b in enumerate(CFG['bridges']):
		br = {'a': b['a'], 'b': b['b'], 'width': float(b.get('width', 3.2))}
		prof = bridge_profile(br, surf)
		n = len(prof) - 1
		a2, b2 = np.array(br['a'], float), np.array(br['b'], float)
		L = float(np.linalg.norm(b2 - a2))
		fwd2 = (b2 - a2) / L
		side2 = np.array([-fwd2[1], fwd2[0]])
		W = br['width']

		def pt(t, off=0.0, dy=0.0):
			f = min(max(t, 0.0), 1.0) * n
			i = min(int(f), n - 1)
			y = prof[i] + (prof[i + 1] - prof[i]) * (f - i)
			q = a2 + (b2 - a2) * t + side2 * off
			return np.array([q[0], y + dy, q[1]])

		def slope_at(t):
			p0, p1 = pt(t - 0.02), pt(t + 0.02)
			d = p1 - p0
			return d / np.linalg.norm(d)

		side3 = np.array([side2[0], 0.0, side2[1]])
		# доски поперёк
		pw, gap = 0.27, 0.035
		k = int(L / (pw + gap))
		for i in range(k):
			t = (i + 0.5) / k
			fw = slope_at(t)
			up = np.cross(side3, fw)
			up /= np.linalg.norm(up)
			if up[1] < 0:
				up = -up
			jit = r.uniform(-0.06, 0.06)
			sk = math.radians(r.uniform(-2.0, 2.0))
			sd = side3 * math.cos(sk) + fw * math.sin(sk)
			c = pt(t, jit, -0.035 + r.uniform(-0.008, 0.008))
			g.box(c, sd, up, fw, W + r.uniform(-0.05, 0.12), 0.07, pw, PLANK_RECT, 'u', r)
		# продольные балки под досками и перила
		segs = max(2, int(L / 1.5))
		for s_ in range(segs):
			t0, t1 = s_ / segs, (s_ + 1) / segs
			for off in (-W / 2 + 0.35, W / 2 - 0.35):
				p0, p1 = pt(t0, off, -0.17), pt(t1, off, -0.17)
				d = p1 - p0
				ln = np.linalg.norm(d)
				fw = d / ln
				up = np.cross(side3, fw)
				up /= np.linalg.norm(up)
				if up[1] < 0:
					up = -up
				g.box((p0 + p1) / 2, fw, up, side3, ln + 0.02, 0.18, 0.16, POST_RECT, 'u', r)
		# сваи парами (в воде — до дна, на полу — в пол), поверху перила, между сваями — верёвка
		npost = max(2, int(round(L / 2.6)) + 1)
		tops = {}
		for pi in range(npost):
			t = pi / (npost - 1)
			for sgn in (-1, 1):
				off = sgn * (W / 2 + 0.06)
				top = pt(t, off, 0.95)
				gx, gz = top[0], top[2]
				bot = min(gh(gx, gz), prof[min(int(t * n), n)] - 0.3) - 0.35
				c = np.array([gx, (top[1] + bot) / 2, gz])
				g.box(c, (0, 1, 0), (1, 0, 0), (0, 0, 1), top[1] - bot, 0.17, 0.17, POST_RECT, 'v', r)
				tops[(pi, sgn)] = top
		for pi in range(npost - 1):
			for sgn in (-1, 1):
				p0, p1 = tops[(pi, sgn)], tops[(pi + 1, sgn)]
				d = p1 - p0
				ln = np.linalg.norm(d)
				fw = d / ln
				up = np.cross(side3, fw)
				up /= np.linalg.norm(up)
				if up[1] < 0:
					up = -up
				g.box((p0 + p1) / 2 + up * 0.04, fw, up, side3, ln + 0.1, 0.09, 0.12, PLANK_RECT, 'u', r)
				# верёвка провисает между сваями ниже перил
				m = 6
				prev = p0 - np.array([0, 0.38, 0])
				for k2 in range(1, m + 1):
					tt = k2 / m
					q = p0 + d * tt - np.array([0, 0.38 + 0.12 * math.sin(math.pi * tt), 0])
					g.tube(prev, q, 0.025, ROPE_RECT)
					prev = q
	return g


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


def write_glb(path, name, pos, nrm, uv, tris):
	"""Как tools/prepare_props.py write_glb (цвет вершин — альфа 0: без свечения)."""
	out = bytearray()
	views, accs = [], []

	def put(arr, target, ctype, typ, minmax=False, norm=False):
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

	col = np.ones((len(pos), 4))
	col[:, 3] = 0.0
	attrs = {
		"POSITION": put(pos.astype(np.float32), 34962, 5126, "VEC3", True),
		"NORMAL": put(nrm.astype(np.float32), 34962, 5126, "VEC3"),
		"TEXCOORD_0": put(uv.astype(np.float32), 34962, 5126, "VEC2"),
		"COLOR_0": put(np.round(col * 255).astype(np.uint8), 34962, 5121, "VEC4", norm=True),
	}
	big = len(pos) >= 65536
	ind = put(tris.astype(np.uint32 if big else np.uint16).ravel(), 34963, 5125 if big else 5123, "SCALAR")
	gltf = {
		"asset": {"version": "2.0", "generator": "MyRappelz tools/dungeon_layout/blender_scene.py"},
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
	imp = path + ".import"
	if not os.path.exists(imp):
		with open(imp, "w") as f:
			f.write(GLB_IMPORT.format(name=os.path.basename(path)))


def geo_object(g, name, page):
	me = bpy.data.meshes.new(name)
	me.from_pydata([to_bl(*p) for p in g.p], [], [t[::-1] for t in g.t])
	uvl = me.uv_layers.new()
	for poly in me.polygons:
		for li, vi in zip(poly.loop_indices, poly.vertices):
			u, v = g.uv[vi]
			uvl.data[li].uv = (u, 1.0 - v)
	me.materials.append(page_mat(page))
	ob = bpy.data.objects.new(name, me)
	bpy.context.scene.collection.objects.link(ob)
	return ob


# ---------- Проходы ----------

def path_check(items, surf):
	"""Сетка 0.5 м: проходимо (пол, палуба, настил мостов) минус твёрдые следы + 0.45 м; путь от портала к залам,
	концам мостов и по палубе."""
	res = 0.5
	x0, z0 = OX, OZ
	nx, nz = int((NX - 1) * STEP / res) + 1, int((NZ - 1) * STEP / res) + 1
	free = np.zeros((nz, nx), dtype=bool)
	for j in range(nz):
		for i in range(nx):
			x, z = x0 + i * res, z0 + j * res
			free[j, i] = WALK[node(x, z)] == 1 and DK[node(x, z)] < 0 or (surf.inside(x, z))
	for d in CFG['decks']:
		if d.get('id') == 'ship':
			continue
		for j in range(nz):
			for i in range(nx):
				if shape_sd(d, (x0 + i * res, z0 + j * res)) < -0.2:
					free[j, i] = True
	for b in CFG['bridges']:
		a2, b2 = np.array(b['a'], float), np.array(b['b'], float)
		L = np.linalg.norm(b2 - a2)
		for k in range(int(L / 0.25) + 1):
			q = a2 + (b2 - a2) * k / max(1, int(L / 0.25))
			sd = np.array([-(b2 - a2)[1], (b2 - a2)[0]]) / L
			for o in np.linspace(-b['width'] / 2 + 0.3, b['width'] / 2 - 0.3, 7):
				p = q + sd * o
				i, j = int(round((p[0] - x0) / res)), int(round((p[1] - z0) / res))
				if 0 <= i < nx and 0 <= j < nz:
					free[j, i] = True
	block = np.zeros_like(free)
	for it in items:
		if not is_solid(it):
			continue
		poly = it.foot() if it.id not in POLES else None
		if it.id in POLES:
			bx, bz = pole_base(it)
			rr = POLES[it.id] * it.s + 0.45
			for j in range(int((bz - rr - z0) / res), int((bz + rr - z0) / res) + 2):
				for i in range(int((bx - rr - x0) / res), int((bx + rr - x0) / res) + 2):
					if 0 <= i < nx and 0 <= j < nz and math.hypot(x0 + i * res - bx, z0 + j * res - bz) < rr:
						block[j, i] = True
			continue
		if len(poly) < 3:
			continue
		xs, zs = [p[0] for p in poly], [p[1] for p in poly]
		for j in range(int((min(zs) - 0.5 - z0) / res), int((max(zs) + 0.5 - z0) / res) + 2):
			for i in range(int((min(xs) - 0.5 - x0) / res), int((max(xs) + 0.5 - x0) / res) + 2):
				if not (0 <= i < nx and 0 <= j < nz):
					continue
				x, z = x0 + i * res, z0 + j * res
				if poly_dist(poly, (x, z)) < 0.45:
					block[j, i] = True
	ok = free & ~block
	if os.environ.get('DG_PATHDBG'):
		for j in range(int((12 - z0) / res), int((26 - z0) / res)):
			print('ПУТЬ %5.1f ' % (z0 + j * res) + ''.join('.' if ok[j, i] else ('X' if block[j, i] else '#')
				for i in range(int((26 - x0) / res), int((38 - x0) / res))))
	sp = CFG['spawn_points']['default']
	start = (int(round((sp[0] - x0) / res)), int(round((sp[1] - z0) / res)))
	seen = np.zeros_like(ok)
	from collections import deque
	q = deque([start])
	seen[start[1], start[0]] = True
	while q:
		i, j = q.popleft()
		for a, b in ((i + 1, j), (i - 1, j), (i, j + 1), (i, j - 1)):
			if 0 <= a < nx and 0 <= b < nz and ok[b, a] and not seen[b, a]:
				seen[b, a] = True
				q.append((a, b))
	targets = [(r['id'], r['center']) for r in CFG['rooms']]
	targets += [('мост %d · a' % i, b['a']) for i, b in enumerate(CFG['bridges'])]
	targets += [('мост %d · b' % i, b['b']) for i, b in enumerate(CFG['bridges'])]
	targets += [('палуба у рубки', (32.0, 17.0)), ('палуба у мачты', (30.0, 33.0)), ('нос', (32.0, 50.0))]
	bad = 0
	for nm, (x, z) in targets:
		i, j = int(round((x - x0) / res)), int(round((z - z0) / res))
		got = False
		for r_ in range(0, 6):
			for a in range(i - r_, i + r_ + 1):
				for b in range(j - r_, j + r_ + 1):
					if 0 <= a < nx and 0 <= b < nz and seen[b, a]:
						got = True
			if got:
				break
		if not got:
			bad += 1
			note('НЕ ДОЙТИ:', nm, (x, z))
	note('проходы: целей %d, недоступно %d' % (len(targets), bad))
	return bad


def poly_dist(poly, p):
	inside = True
	n = len(poly)
	best = 1e9
	for i in range(n):
		a, b = poly[i], poly[(i + 1) % n]
		cr = (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])
		if cr < 0:
			inside = False
		ab = (b[0] - a[0], b[1] - a[1])
		L2 = max(ab[0] ** 2 + ab[1] ** 2, 1e-9)
		t = min(max(((p[0] - a[0]) * ab[0] + (p[1] - a[1]) * ab[1]) / L2, 0), 1)
		best = min(best, math.hypot(p[0] - a[0] - ab[0] * t, p[1] - a[1] - ab[1] * t))
	return 0.0 if inside else best


def is_solid(it):
	if it.id in NO_SOLID or it.mount in ('hull', 'pier', 'wall', 'float', 'fixed'):
		return False
	if it.id in POLES:
		return True
	return it.height() >= 0.5


# ---------- Сцена: объекты, свет, камера ----------

def place_objects(items):
	col = bpy.data.collections.new('Props')
	bpy.context.scene.collection.children.link(col)
	for it in items:
		e = model_of(it.id)
		ob = bpy.data.objects.new(it.id, e['mesh'])
		ob.matrix_world = it.matrix_bl()
		col.objects.link(ob)
		if it.flags:
			ob['flags'] = '; '.join(it.flags)


LIGHT_COL = {'dg_torch': ((1.0, 0.6, 0.3), 120, 0.85), 'dg_brazier': ((1.0, 0.6, 0.3), 250, 0.95),
	'dg_cauldron': ((1.0, 0.55, 0.25), 200, 0.6), 'dg_witch_brazier': ((0.35, 1.0, 0.5), 200, 0.9),
	'dg_coral_altar': ((0.35, 1.0, 0.55), 900, 0.6), 'dg_candles': ((0.4, 1.0, 0.5), 25, 0.9),
	'dg_lantern': ((1.0, 0.75, 0.4), 60, 0.5), 'dg_harbor_post': ((1.0, 0.7, 0.35), 120, 0.85),
	'dg_chest_open': ((1.0, 0.8, 0.35), 120, 0.8), 'dg_spiral': ((0.35, 1.0, 0.55), 150, 1.0)}


def lights(items):
	sc = bpy.context.scene
	for it in items:
		if it.id not in LIGHT_COL:
			continue
		c, pw, hk = LIGHT_COL[it.id]
		ld = bpy.data.lights.new('L_' + it.id, 'POINT')
		ld.color = c
		ld.energy = pw * it.s
		ld.shadow_soft_size = 0.3
		lo = bpy.data.objects.new('L_' + it.id, ld)
		w = it.world(model_of(it.id)['v'])
		top = w[:, 1].min() + (w[:, 1].max() - w[:, 1].min()) * hk + 0.2
		cx, cz = w[:, 0].mean(), w[:, 2].mean()
		lo.location = to_bl(cx, top, cz)
		sc.collection.objects.link(lo)
	sun = bpy.data.lights.new('moon', 'SUN')
	sun.energy = 1.1
	sun.color = (0.75, 0.8, 1.0)
	so = bpy.data.objects.new('moon', sun)
	so.rotation_euler = (math.radians(35), math.radians(-20), math.radians(30))
	sc.collection.objects.link(so)
	w = bpy.data.worlds.new('w')
	sc.world = w
	w.use_nodes = True
	w.node_tree.nodes['Background'].inputs[0].default_value = (0.09, 0.09, 0.14, 1)
	w.node_tree.nodes['Background'].inputs[1].default_value = 1.0


## Ракурсы: имя → [точка взгляда x, z (Godot), поворот°, наклон°, расстояние] — как камера игры (поворот 0 —
## камера к югу от точки и смотрит на север)
VIEWS = {
	'01_vhod': [-72.0, -10.0, 20, 40, 20],
	'02_altar': [-45.5, -40.0, 0, 30, 22],
	'03_altar_blizko': [-45.5, -47.0, 0, 18, 12],
	'04_sklep': [8.0, -36.0, 0, 35, 22],
	'05_sklep_stolby': [5.0, -40.0, 300, 15, 14],
	'06_goblin': [60.0, -40.0, 0, 35, 22],
	'07_goblin_tron': [66.0, -46.0, 20, 22, 11],
	'08_shahta': [48.0, -16.0, 270, 25, 14],
	'09_sokrovish': [-64.0, 20.0, 180, 32, 18],
	'10_kanal_mosty': [-32.0, -6.0, 180, 32, 20],
	'11_prichal_mostki': [-14.0, 30.0, 250, 30, 18],
	'12_most_k_korablyu': [12.0, 33.0, 210, 22, 22],
	'13_korabl_sverhu': [32.0, 34.0, 300, 55, 34],
	'14_korabl_paluba_nos': [32.0, 40.0, 180, 22, 12],
	'15_korabl_paluba_rubka': [32.0, 24.0, 0, 22, 12],
	'16_korabl_bok': [18.0, 32.0, 270, 12, 22],
	'17_fakely_koridor': [-40.0, -19.0, 180, 20, 12],
	'18_paluba_glaza_rubka': [32.0, 21.0, 0, 6, 6],
	'19_paluba_glaza_nos': [32.0, 46.0, 180, 8, 6],
	'20_paluba_glaza_most': [29.5, 31.0, 90, 8, 6],
	'21_paluba_glaza_machta': [31.0, 30.0, 330, 8, 5],
}


def camera_for(v):
	x, z, rot, pitch, dist = v
	f = gh(x, z)
	tgt = Vector(to_bl(x, f + 1.2, z))
	r = math.radians(rot)
	p = math.radians(pitch)
	# камера игры: поворот 0 — сзади (юг, +z), смотрит на север (−z)
	off = (math.sin(r) * math.cos(p) * dist, f + 1.2 + math.sin(p) * dist, math.cos(r) * math.cos(p) * dist)
	pos = Vector(to_bl(x + off[0], off[1], z + off[2]))
	return pos, tgt


def render(views, outdir):
	os.makedirs(outdir, exist_ok=True)
	sc = bpy.context.scene
	if arg('--engine') == 'workbench':
		sc.render.engine = 'BLENDER_WORKBENCH'
		sc.display.shading.light = 'STUDIO'
		sc.display.shading.color_type = 'TEXTURE'
		sc.display.shading.show_shadows = True
	else:
		sc.render.engine = 'BLENDER_EEVEE_NEXT'
		sc.eevee.taa_render_samples = 16
	sc.render.resolution_x = int(arg('--rx', '1280'))
	sc.render.resolution_y = int(arg('--ry', '640'))
	sc.view_settings.view_transform = 'Standard'
	cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
	cam.data.lens = 22
	cam.data.clip_end = 400
	sc.collection.objects.link(cam)
	sc.camera = cam
	hide = arg('--hide')
	if hide:
		for ob in bpy.data.objects:
			if ob.type == 'MESH' and ob.data and ob.data.name.split('_cut')[0] in hide.split(','):
				ob.hide_render = True
	for nm in views:
		pos, tgt = camera_for(VIEWS[nm])
		cam.location = pos
		cam.rotation_euler = (tgt - pos).to_track_quat('-Z', 'Y').to_euler()
		sc.render.filepath = os.path.join(outdir, nm + '.png')
		bpy.ops.render.render(write_still=True)


def closeups(items, outdir, which):
	"""Крупные планы (Workbench, быстро): каждый объект из which — сбоку под 25° с расстояния по его размеру, рядом
	стоит «герой» — столбик 1.7 м; затем листы по 12 кадров (closeup_N.jpg)."""
	os.makedirs(outdir, exist_ok=True)
	sc = bpy.context.scene
	sc.render.engine = 'BLENDER_WORKBENCH'
	sc.display.shading.light = 'STUDIO'
	sc.display.shading.color_type = 'TEXTURE'
	sc.display.shading.show_shadows = True
	sc.render.resolution_x = 480
	sc.render.resolution_y = 360
	cam = bpy.data.objects.new('cam_c', bpy.data.cameras.new('cam_c'))
	cam.data.lens = 26
	sc.collection.objects.link(cam)
	sc.camera = cam
	bpy.ops.mesh.primitive_cylinder_add(radius=0.25, depth=1.7)
	hero = bpy.context.active_object
	hero.name = 'hero_marker'
	files = []
	for n, it in enumerate([i for i in items if i.id in which or i.mount in which]):
		w = it.world(model_of(it.id)['v'])
		c = w.mean(axis=0)
		sz = max(np.ptp(w[:, 0]), np.ptp(w[:, 2]), np.ptp(w[:, 1]), 1.0)
		# «герой» рядом — в 1 м перед моделью (по её фасаду или от стены)
		r = math.radians(it.yaw)
		fx, fz = math.sin(r), math.cos(r)
		if it.id == 'dg_torch':
			fx, fz = -math.cos(r), math.sin(r)
		hx, hz = c[0] + fx * (sz * 0.5 + 0.8), c[2] + fz * (sz * 0.5 + 0.8)
		hy = surf_or_ground(hx, hz)
		hero.location = to_bl(hx, hy + 0.85, hz)
		shots = []
		if it.wall_n is not None:
			nx_, nz_ = it.wall_n
			hero.location = to_bl(c[0] + nx_ * 1.2, gh(c[0] + nx_ * 1.2, c[2] + nz_ * 1.2) + 0.85, c[2] + nz_ * 1.2)
			d = sz + 2.2
			# спереди (из зала, чуть сбоку) и вдоль стены (видно зазор)
			shots.append((c[0] + nx_ * d + nz_ * d * 0.3, c[1] + 0.6, c[2] + nz_ * d - nx_ * d * 0.3))
			shots.append((c[0] - nz_ * d + nx_ * 0.8, c[1] + 0.3, c[2] + nx_ * d + nz_ * 0.8))
		else:
			a = r + math.radians(50)
			d = sz * 1.6 + 2.0
			shots.append((c[0] + math.sin(a) * d, c[1] + d * 0.45, c[2] + math.cos(a) * d))
		for si, sp in enumerate(shots):
			pos = Vector(to_bl(*sp))
			tgt = Vector(to_bl(c[0], c[1], c[2]))
			cam.location = pos
			cam.rotation_euler = (tgt - pos).to_track_quat('-Z', 'Y').to_euler()
			f = os.path.join(outdir, 'c%03d_%d.png' % (n, si))
			sc.render.filepath = f
			bpy.ops.render.render(write_still=True)
			files.append((f, '%s (%.1f, %.1f)%s' % (it.id, it.x, it.z, ' вдоль стены' if si else '')))
	from PIL import Image, ImageDraw
	for k in range(0, len(files), 12):
		sheet = Image.new('RGB', (480 * 4, 360 * 3), (20, 20, 25))
		dr = ImageDraw.Draw(sheet)
		for m, (f, label) in enumerate(files[k:k + 12]):
			im = Image.open(f).convert('RGB')
			x, y = (m % 4) * 480, (m // 4) * 360
			sheet.paste(im, (x, y))
			dr.text((x + 6, y + 6), label, fill=(255, 255, 0))
		sheet.save(os.path.join(outdir, 'closeup_%d.jpg' % (k // 12)), quality=82)


SURF = [None]


def surf_or_ground(x, z):
	if SURF[0] is not None and SURF[0].inside(x, z):
		return SURF[0].at(x, z)
	return gh(x, z)


# ---------- Главное ----------

def main():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bvh = build_terrain()
	src = CFG['props']
	items = [Item(a, i) for i, a in enumerate(src)]
	# корабль: поверхность палубы по корпусу
	surf = ship_surface(items)
	SURF[0] = surf
	for it in items:
		it.mount = mount_of(it, surf)
	for it in items:
		if it.mount == 'floor':
			settle_floor(it, allow_of(it))
		elif it.mount == 'wall':
			settle_wall(it, bvh)
		elif it.mount == 'deck':
			settle_deck(it, surf)
		elif it.mount == 'pier':
			settle_pier(it, 0.25)
		elif it.mount == 'float':
			e = model_of(it.id)
			it.y = WATER_Y - FLOAT[it.id] - e['ymin'] * it.s
		elif it.mount == 'hull':
			it.abs = True
	separate(items, surf)
	for it in items:
		if it.drop:
			note('УБРАН %s (%.1f, %.1f): %s' % (it.id, it.x, it.z, it.drop))
		elif it.flags:
			note('%s (%.1f, %.1f): %s' % (it.id, it.x, it.z, '; '.join(it.flags)))
	items = [it for it in items if not it.drop]
	bad = path_check(items, surf)
	g = build_bridges(surf)
	note('мосты: %d вершин, %d треугольников' % (len(g.p), len(g.t)))
	place_objects(items)
	geo_object(g, 'Bridges', 'dg_b')
	if '--write' in ARGS:
		write(items, surf, g)
	if arg('--save'):
		lights(items)
		bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(arg('--save')), relative_remap=False)
	if arg('--renders'):
		if not arg('--save'):
			lights(items)
		vs = arg('--views')
		render(vs.split(',') if vs else list(VIEWS), arg('--renders'))
	if arg('--closeups'):
		closeups(items, arg('--closeups'), set(arg('--which', 'wall').split(',')))
	if arg('--report'):
		open(arg('--report'), 'w').write('\n'.join(REPORT) + '\n')
	print('СЦЕНА готово, недоступно целей:', bad)


def write(items, surf, g):
	# твёрдые: формы по модели
	shapes = {}
	for it in items:
		if not is_solid(it) or it.id in shapes:
			continue
		e = model_of(it.id)
		if it.id in POLES:
			v = e['v']
			low = v[v[:, 1] <= e['ymin'] + 0.12 * (e['ymax'] - e['ymin'])]
			c = low.mean(axis=0)
			shapes[it.id] = {'pole': [round(float(c[0]), 3), round(float(c[2]), 3), POLES[it.id]], 'h': round(e['ymax'] - e['ymin'], 3)}
			continue
		v = e['v']
		# след ниже 1.8 м при самом мелком масштабе этого id
		smin = min(x.s * x.sy for x in items if x.id == it.id)
		sel = v[v[:, 1] <= e['ymin'] + 1.8 / smin]
		hh = simplify_hull(hull2(sel[:, [0, 2]]), 14)
		shapes[it.id] = {'hull': [[round(a, 3), round(b, 3)] for a, b in hh], 'h': round(e['ymax'] - e['ymin'], 3)}
	CFG['prop_shapes'] = dict(sorted(shapes.items()))
	CFG['props'] = [it.entry() for it in items]
	for d in CFG['decks']:
		if d.get('id') == 'ship':
			d.clear()
			d.update({'id': 'ship', 'shape': 'surface', 'surface': surf.to_cfg()})
	CFG['bridge_over_water'] = OVER_WATER
	CFG['bridge_model'] = 'dg_bridges'
	path = ROOT + '/world/dungeon.json'
	json.dump(CFG, open(path, 'w'), ensure_ascii=False)
	import subprocess
	subprocess.run(['python3', '-I', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'fmt_json.py'), path])
	pos = np.array(g.p, dtype=np.float64)
	write_glb(ROOT + '/assets/props/dg_bridges.glb', 'dg_bridges', pos, np.array(g.n), np.array(g.uv),
		np.array(g.t, dtype=np.int64))
	mn, mx = pos.min(axis=0), pos.max(axis=0)
	P['dg_bridges'] = {'page': 'dg_b', 'src': 'blender_scene.py (свои мосты)', 'size': [round(float(a), 3) for a in mx - mn],
		'min': [round(float(a), 3) for a in mn], 'max': [round(float(a), 3) for a in mx], 'tris': len(g.t),
		'verts': len(g.p), 'world': True}
	with open(ROOT + '/assets/props/props.json', 'w') as f:
		json.dump(PJ, f, ensure_ascii=False, indent='\t')
		f.write('\n')
	note('записано: объектов %d, форм %d' % (len(CFG['props']), len(shapes)))


main()
