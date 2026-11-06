"""Общая часть планировщика расстановки объектов подземелья (tools/dungeon_layout/plan.py): сетка пола из игры
(dump_grid.gd → DG_DUMP), помощники «у стены» (wall, side, near, face), проверка (в стене, в воде, свисает с палубы,
на мосту, пересечения твёрдых по габаритам × COLLIDE_K), проходы (clearance, route) и схема сверху (draw)."""
import json, math, os, random, sys
from collections import deque

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.environ.get('DG_OUT', '/tmp')
D = json.load(open(os.environ.get('DG_DUMP', '/tmp/dungeon_grid.json')))
NX, NZ, OX, OZ = D['nx'], D['nz'], D['ox'], D['oz']
P = json.load(open(ROOT + '/assets/props/props.json'))['props']
CFG = json.load(open(ROOT + '/world/dungeon.json'))
ROOMS = {r['id']: r for r in CFG['rooms']}
rng = random.Random(7)

SOLID = set("""dg_spire dg_crag dg_moss_stones dg_amethyst_spires dg_crystal_purple dg_crystal_blue dg_tent dg_cauldron
dg_chest dg_chest_open dg_crates dg_barrel dg_bell dg_palisade dg_barricade dg_spikes dg_barricade_moss dg_totem dg_table
dg_prison dg_armory dg_obelisk dg_monolith dg_crypt_altar dg_witch_brazier dg_throne dg_oracle dg_coral_altar dg_mine
dg_cannon dg_relics dg_hoard dg_brazier dg_siren dg_helm dg_leviathan dg_cavern dg_cliffs
dg_dripstone""".split())
LIGHTS = {'dg_brazier', 'dg_cauldron', 'dg_coral_altar', 'dg_witch_brazier', 'dg_spiral', 'dg_chest_open',
	'dg_harbor_post', 'dg_rune_arch'}
WALL_OK = set("""dg_cliffs dg_cavern dg_mine dg_ladder dg_spire dg_crag dg_moss_stones dg_dripstone dg_amethyst_spires
dg_ascent dg_crystal_purple dg_crystal_blue dg_glowcaps dg_banner dg_net dg_kelp dg_coral""".split())
WATER_OK = set("""dg_kelp dg_coral dg_rowboat dg_raft dg_wreck dg_dripstone dg_mast dg_crows_nest dg_mast_relic dg_leviathan
dg_ship_deck dg_ship_bow dg_siren dg_anchor dg_tidepool dg_pier dg_dock dg_wharf dg_net dg_crystal_purple dg_crystal_blue
dg_cannon dg_barrel""".split())
# Плоское и мелкое: можно класть на/под другие (ковры, шкуры, кости, золото)
FLAT = set("""dg_prayer_rug dg_bearskin dg_bedroll dg_gold dg_spiral dg_rune_arch dg_remains dg_mariner dg_tidepool
dg_stone_ring dg_nest""".split())


def at(k, x, z):
	i = int(round(z - OZ)); j = int(round(x - OX))
	if i < 0 or j < 0 or i >= NZ or j >= NX:
		return 99.0 if k in ('fs', 'ws') else 0
	return D[k][i * NX + j]


def dirv(a):
	r = math.radians(a)
	return math.sin(r), -math.cos(r)


def face(x, z, tx, tz):
	"""Поворот, при котором фасад (+Z модели) смотрит на точку t."""
	return math.degrees(math.atan2(tx - x, tz - z)) % 360


def wall(room, a, depth, off=0.0):
	"""Точка у стены зала room по направлению a (0 — север, 90 — восток) в depth м от стены, сдвиг вдоль стены off;
	фасад — к центру зала."""
	r = ROOMS[room]
	cx, cz = r['center']
	dx, dz = dirv(a)
	t = 0.0
	last = (cx, cz)
	while t < 60:
		x, z = cx + dx * t, cz + dz * t
		if at('fs', x, z) > -depth or (at('ws', x, z) < 0.6 and at('dk', x, z) < 0):
			break
		last = (x, z)
		t += 0.1
	x, z = last
	# сдвиг вдоль стены: off > 0 — по часовой стрелке (если смотреть сверху, север вверху)
	x += -dz * off
	z += dx * off
	return x, z, face(x, z, cx, cz)


PLACED = []  # [id, x, z, yaw, s, dy, zone]
ZONE = ['']


def put(id_, x, z, yaw=0.0, s=1.0, dy=0.0, jit=0.0, sy=1.0, absy=False):
	"""Объект: [id, x, z, поворот, масштаб, сдвиг высоты, зона, вертикальный масштаб sy, точная высота absy —
	сдвиг тогда — высота основания в мире]."""
	if jit:
		yaw += rng.uniform(-jit, jit)
	PLACED.append([id_, round(x, 2), round(z, 2), round(yaw % 360, 1), round(s, 3), round(dy, 3), ZONE[0], sy, absy])


def side(x, z, a, depth=0.7):
	"""От точки (x, z) по направлению a до стены: точка в depth м от неё (пол, не вода)."""
	dx, dz = dirv(a)
	last = (x, z)
	t = 0.0
	while t < 30:
		px, pz = x + dx * t, z + dz * t
		if not at('walk', px, pz) or at('fs', px, pz) > -depth:
			break
		last = (px, pz)
		t += 0.1
	return last


def near(x, z, dist, a):
	dx, dz = dirv(a)
	return x + dx * dist, z + dz * dist


def keep_structural():
	keep = []
	for p in CFG['props']:
		if p[0] == 'dg_mine':
			p = ['dg_mine', 52.0, -12.6, 180, 1.0, -0.62]
		# Настил площадки мостков (0.9 м от основания модели) — вровень с палубой-островом, где ходит герой.
		# Корабль (нос, средняя палуба, корма с рубкой) собирает plan.lake (SHIP), здесь его частей нет.
		DECK_DY = {'dg_pier': -0.86}
		if p[0] in DECK_DY:
			p = list(p[:5]) + [DECK_DY[p[0]]]
		if p[0] in ('dg_pier', 'dg_ascent', 'dg_mine', 'dg_coral_altar'):
			q = list(p) + [0.0, 1.0, 0.0][max(0, len(p) - 3):]
			q = (q + [0.0] * 6)[:6]
			keep.append(q)
	return keep


# ---------------------------------------------------------------- проверка

def obb(p):
	id_, x, z, yaw, s = p[0], p[1], p[2], p[3], p[4]
	sz = P[id_]['size'] if id_ in P else [1.2, 1.2, 1.2]
	hx, hz = sz[0] * s * 0.5, sz[2] * s * 0.5
	r = math.radians(yaw)
	ux, uz = math.cos(r), -math.sin(r)   # ось X модели
	vx, vz = math.sin(r), math.cos(r)    # ось Z модели
	return (x, z, ux, uz, vx, vz, hx, hz)


def corners(o, k=1.0):
	x, z, ux, uz, vx, vz, hx, hz = o
	return [(x + ux * hx * a * k + vx * hz * b * k, z + uz * hx * a * k + vz * hz * b * k) for a in (-1, 1) for b in (-1, 1)]


def sat(a, b, k=1.0):
	for o in (a, b):
		for ax in ((o[2], o[3]), (o[4], o[5])):
			pa = [c[0] * ax[0] + c[1] * ax[1] for c in corners(a, k)]
			pb = [c[0] * ax[0] + c[1] * ax[1] for c in corners(b, k)]
			if max(pa) < min(pb) or max(pb) < min(pa):
				return False
	return True


def check(items, verbose=True):
	bad = 0
	obbs = [obb(p) for p in items]
	for i, p in enumerate(items):
		id_ = p[0]
		x, z = p[1], p[2]
		probs = []
		if p[6] == 'keep':
			continue
		walk = at('walk', x, z)
		if not walk:
			water = at('ws', x, z) < 1.0
			if water and id_ not in WATER_OK:
				probs.append('в воде')
			elif not water and id_ not in WALL_OK and id_ not in WATER_OK and id_ not in ('dg_ascent', 'dg_mine'):
				probs.append('в стене')
		on_deck = at('dk', x, z) >= 0
		if on_deck:
			if any(at('dk', cx, cz) < 0 for cx, cz in corners(obbs[i], 0.7)):
				probs.append('свисает с палубы')
		elif id_ not in WALL_OK and id_ not in WATER_OK and id_ not in ('dg_mine', 'dg_ascent', 'dg_coral_altar', 'dg_ship_deck', 'dg_ship_bow'):
			worst = max(at('fs', cx, cz) for cx, cz in corners(obbs[i], 0.85))
			if worst > 0.4:
				probs.append('угол в стене %.1f' % worst)
		if id_ in SOLID:
			for br in CFG['bridges']:
				(ax, az), (bx, bz) = br['a'], br['b']
				for k in range(21):
					t = k / 20.0
					qx, qz = ax + (bx - ax) * t, az + (bz - az) * t
					o = obbs[i]
					ddx, ddz = qx - o[0], qz - o[1]
					if abs(ddx * o[2] + ddz * o[3]) < o[6] + br['width'] * 0.5 and abs(ddx * o[4] + ddz * o[5]) < o[7] + 0.3:
						probs.append('на мосту')
						break
				else:
					continue
				break
		for j in range(i):
			q = items[j]
			if q[6] == 'keep' and p[6] == 'keep':
				continue
			BASE = ('dg_ship_deck', 'dg_ship_bow', 'dg_pier', 'dg_wreck')
			if id_ in BASE or q[0] in BASE:
				continue
			if (id_ in SOLID or q[0] in SOLID) and not (id_ in FLAT or q[0] in FLAT):
				if sat(obbs[i], obbs[j], 0.8):
					probs.append('задевает %s' % q[0])
		if probs:
			bad += 1
			if verbose:
				print('  !', p[6], id_, x, z, ', '.join(probs))
	return bad


def blocked_grid(items, res=0.5):
	nx, nz = int(NX / res), int(NZ / res)
	g = bytearray(nx * nz)
	for i in range(nz):
		for j in range(nx):
			x, z = OX + j * res, OZ + i * res
			if not at('walk', x, z):
				g[i * nx + j] = 1
	for p in items:
		if p[0] not in SOLID:
			continue
		o = obb(p)
		cs = corners(o, 0.8)
		minx = min(c[0] for c in cs); maxx = max(c[0] for c in cs)
		minz = min(c[1] for c in cs); maxz = max(c[1] for c in cs)
		for i in range(int((minz - OZ) / res), int((maxz - OZ) / res) + 1):
			for j in range(int((minx - OX) / res), int((maxx - OX) / res) + 1):
				x, z = OX + j * res, OZ + i * res
				dx, dz = x - o[0], z - o[1]
				a = dx * o[2] + dz * o[3]; b = dx * o[4] + dz * o[5]
				if abs(a) <= o[6] * 0.8 and abs(b) <= o[7] * 0.8 and 0 <= i < nz and 0 <= j < nx:
					g[i * nx + j] = 1
	return g, nx, nz, res


def clearance(g, nx, nz, res):
	"""Расстояние (м) до ближайшей занятой клетки (BFS по 8 соседям, приближённо)."""
	INF = 1e9
	d = [INF] * (nx * nz)
	q = deque()
	for k in range(nx * nz):
		if g[k]:
			d[k] = 0; q.append(k)
	while q:
		k = q.popleft()
		i, j = divmod(k, nx)
		for di, dj, w in ((1, 0, 1), (-1, 0, 1), (0, 1, 1), (0, -1, 1), (1, 1, 1.414), (1, -1, 1.414), (-1, 1, 1.414), (-1, -1, 1.414)):
			ii, jj = i + di, j + dj
			if 0 <= ii < nz and 0 <= jj < nx:
				kk = ii * nx + jj
				if d[kk] > d[k] + w:
					d[kk] = d[k] + w; q.append(kk)
	return [v * res for v in d]


def route(cl, nx, nz, res, a, b, need):
	"""Путь a→b по клеткам с запасом ≥ need (полуширина прохода); None — нет. Возвращает минимальный запас по пути."""
	def cell(p):
		return int(round((p[1] - OZ) / res)), int(round((p[0] - OX) / res))
	sa, sb = cell(a), cell(b)
	prev = {sa: None}
	q = deque([sa])
	while q:
		c = q.popleft()
		if c == sb:
			break
		i, j = c
		for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
			n = (i + di, j + dj)
			if 0 <= n[0] < nz and 0 <= n[1] < nx and n not in prev and cl[n[0] * nx + n[1]] >= need:
				prev[n] = c; q.append(n)
	if sb not in prev:
		return None
	m = 99.0
	c = sb
	while c:
		m = min(m, cl[c[0] * nx + c[1]]); c = prev[c]
	return m


def draw(items, out, box, scale=8, labels=True):
	"""Схема сверху: пол / вода / стена, контуры объектов (твёрдые — красным), подписи."""
	from PIL import Image, ImageDraw
	x0, z0, x1, z1 = box
	W, H = int((x1 - x0) * scale), int((z1 - z0) * scale)
	im = Image.new('RGB', (W, H), (12, 12, 18))
	px = im.load()
	for yy in range(H):
		for xx in range(W):
			x, z = x0 + xx / scale, z0 + yy / scale
			if at('dk', x, z) >= 0:
				c = (120, 90, 55)
			elif at('ws', x, z) < 0:
				c = (25, 95, 90)
			elif at('walk', x, z):
				h = at('h', x, z)
				v = int(max(0, min(255, 95 + h * 9)))
				c = (v, v, v + 12)
			else:
				c = (40, 34, 52)
			px[xx, yy] = c
	dr = ImageDraw.Draw(im)
	for xx in range(int(x0), int(x1) + 1):
		if xx % 5 == 0:
			dr.line([((xx - x0) * scale, 0), ((xx - x0) * scale, H)], fill=(55, 55, 70) if xx % 10 else (80, 80, 100))
	for zz in range(int(z0), int(z1) + 1):
		if zz % 5 == 0:
			dr.line([(0, (zz - z0) * scale), (W, (zz - z0) * scale)], fill=(55, 55, 70) if zz % 10 else (80, 80, 100))
	for p in items:
		o = obb(p)
		cs = corners(o)
		pts = [((cs[k][0] - x0) * scale, (cs[k][1] - z0) * scale) for k in (0, 1, 3, 2)]
		col = (255, 80, 70) if p[0] in SOLID else (255, 210, 90) if p[0] not in FLAT else (150, 200, 255)
		dr.polygon(pts, outline=col)
		fx, fz = o[0] + o[4] * o[7], o[1] + o[5] * o[7]
		dr.line([((o[0] - x0) * scale, (o[1] - z0) * scale), ((fx - x0) * scale, (fz - z0) * scale)], fill=(90, 255, 120))
		if labels:
			dr.text(((o[0] - x0) * scale + 2, (o[1] - z0) * scale - 5), p[0][3:], fill=(240, 240, 240))
	im.save(out)
