class_name CardinalNav
extends RefCounted
## Путь Кардинала по острову (как игрок, который видит, где ограда, дом и дерево): сетка проходимости
## IslandWorld.walk (суша, мосты; вода и кручи — нет) + следы коллизий мира — ограды, стены построек, столбы деревьев,
## камни, жители (StaticBody3D слоя 1: коробки, капсулы, цилиндры, шары; рельеф и настил мостов — нет) с запасом
## на ширину героя; поиск — AStarGrid2D (8 направлений, без срезания углов). Сетка строится один раз на мир (кэш по
## IslandWorld). path(from, to) — точки пути по земле ([] — пути нет: идём по прямой с обходом).

## Запас вокруг препятствия (радиус капсулы героя + зазор), м.
const INFLATE := 0.55
## Препятствие ниже этого над землёй не мешает (ступенька), выше этого основанием — над головой (арка ворот), м.
const LOW := 0.35
const HIGH := 2.1
## Мост: полоса у перил, закрытая для пути (сверх INFLATE), и сколько метров за концом моста середина ещё открыта, м.
const BRIDGE_RAIL := 0.4
const BRIDGE_END := 1.0

static var _world_id := 0
static var _astar: AStarGrid2D = null
static var _w: IslandWorld = null
## Сколько клеток закрыто следами коллизий (для отчёта).
static var blocked_cells := 0


## Сетка для мира w (построить, если мир новый). tree — дерево сцены (поиск тел коллизии).
static func ensure(w: IslandWorld, tree: SceneTree) -> void:
	if w == null or not is_instance_valid(w):
		return
	if _astar != null and _world_id == w.get_instance_id():
		return
	_w = w
	_world_id = w.get_instance_id()
	var a := AStarGrid2D.new()
	a.region = Rect2i(0, 0, w.nx, w.nz)
	a.cell_size = Vector2(w.step, w.step)
	a.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	a.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	a.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	a.jumping_enabled = true
	a.update()
	var walk := w.walk
	for j in w.nz:
		for i in w.nx:
			if walk[j * w.nx + i] == 0:
				a.set_point_solid(Vector2i(i, j), true)
	blocked_cells = 0
	for n in tree.root.find_children("*", "CollisionShape3D", true, false):
		var cs := n as CollisionShape3D
		if cs == null or cs.disabled or cs.shape == null:
			continue
		var body := cs.get_parent() as StaticBody3D
		if body == null or (body.collision_layer & 1) == 0:
			continue
		_stamp(a, w, cs)
	for br in w.bridges:
		_bridge_lane(a, w, br)
	for pt in tree.get_nodes_in_group("portals"):
		_portal_keep(a, w, pt as Node3D)
	_astar = a


## Портал (у пещеры острова — рядом логово анатем): путь обходит круг PORTAL_KEEP м у его входа, иначе герой по
## пути к анатемам заходил в портал и уходил в подземелье (прогон Кардинала 0.35: два десятка переходов по кругу).
## К самому порталу _go доходит: конец пути — ближайшая свободная клетка, дальше по прямой.
const PORTAL_KEEP := 3.0


static func _portal_keep(a: AStarGrid2D, w: IslandWorld, pt: Node3D) -> void:
	if pt == null or not pt.has_method("front_point"):
		return
	var f: Vector3 = pt.call("front_point")
	var r := ceili(PORTAL_KEEP / w.step)
	var c0 := Vector2i(roundi((f.x - w.origin.x) / w.step), roundi((f.z - w.origin.y) / w.step))
	for j in range(c0.y - r, c0.y + r + 1):
		for i in range(c0.x - r, c0.x + r + 1):
			var c := Vector2i(i, j)
			if not a.is_in_boundsv(c):
				continue
			var x := w.origin.x + float(i) * w.step
			var z := w.origin.y + float(j) * w.step
			if Vector2(x - f.x, z - f.z).length() <= PORTAL_KEEP:
				a.set_point_solid(c, true)


## Мост — только по середине настила, как идёт игрок: клетки у краёв настила (перила) и склон берега под концом
## моста закрыты, середина открыта. Без этого путь срезал угол у конца моста по краю настила — герой съезжал
## на склон русла под настил и застревал в клине между склоном и настилом (отчёт 0.34.0: переносы у (−62, 10),
## (−53, 2), (−43, −14), (−30, −28) — все у концов мостов).
static func _bridge_lane(a: AStarGrid2D, w: IslandWorld, br: Dictionary) -> void:
	var p0: Vector3 = br["a"]
	var p1: Vector3 = br["b"]
	var axis := Vector2(p1.x - p0.x, p1.z - p0.z)
	var length := axis.length()
	if length < 0.5:
		return
	var dir := axis / length
	var half := float(br.get("width", 4.0)) * 0.5
	var lane := maxf(0.6, half - INFLATE - BRIDGE_RAIL)
	var side := half + INFLATE
	var ext := length * 0.5 + side
	var mid := Vector2(p0.x + p1.x, p0.z + p1.z) * 0.5
	var i0 := clampi(int(floorf((mid.x - ext - w.origin.x) / w.step)), 0, w.nx - 1)
	var i1 := clampi(int(ceilf((mid.x + ext - w.origin.x) / w.step)), 0, w.nx - 1)
	var j0 := clampi(int(floorf((mid.y - ext - w.origin.y) / w.step)), 0, w.nz - 1)
	var j1 := clampi(int(ceilf((mid.y + ext - w.origin.y) / w.step)), 0, w.nz - 1)
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var q := Vector2(w.origin.x + float(i) * w.step, w.origin.y + float(j) * w.step) - Vector2(p0.x, p0.z)
			var t := q.dot(dir)
			var s := absf(q.x * dir.y - q.y * dir.x)
			if t < -BRIDGE_END or t > length + BRIDGE_END or s > side:
				continue
			var c := Vector2i(i, j)
			if s <= lane:
				a.set_point_solid(c, false)
			elif t > 0.0 and t < length and not a.is_point_solid(c):
				a.set_point_solid(c, true)
				blocked_cells += 1


static func _stamp(a: AStarGrid2D, w: IslandWorld, cs: CollisionShape3D) -> void:
	var sh := cs.shape
	var xf := cs.global_transform
	var c := xf.origin
	var half := Vector3.ZERO
	var round_r := -1.0
	if sh is BoxShape3D:
		half = (sh as BoxShape3D).size * 0.5
	elif sh is CapsuleShape3D:
		round_r = (sh as CapsuleShape3D).radius
		half = Vector3(round_r, (sh as CapsuleShape3D).height * 0.5, round_r)
	elif sh is CylinderShape3D:
		round_r = (sh as CylinderShape3D).radius
		half = Vector3(round_r, (sh as CylinderShape3D).height * 0.5, round_r)
	elif sh is SphereShape3D:
		round_r = (sh as SphereShape3D).radius
		half = Vector3(round_r, round_r, round_r)
	elif sh is ConvexPolygonShape3D:
		# призма по следу модели (объекты подземелья 0.35.4, "prop_shapes"): след в осях формы
		_stamp_convex(a, w, cs, sh as ConvexPolygonShape3D)
		return
	else:
		return
	# По высоте: ниже ступеньки или выше головы — не препятствие
	var sc := xf.basis.get_scale()
	var hy := absf(half.y * sc.y)
	var ground := w.height_at(c.x, c.z)
	if c.y + hy < ground + LOW or c.y - hy > ground + HIGH:
		return
	var ext := Vector3(half.x * sc.x, 0.0, half.z * sc.z).length() + INFLATE
	var i0 := clampi(int(floorf((c.x - ext - w.origin.x) / w.step)), 0, w.nx - 1)
	var i1 := clampi(int(ceilf((c.x + ext - w.origin.x) / w.step)), 0, w.nx - 1)
	var j0 := clampi(int(floorf((c.z - ext - w.origin.y) / w.step)), 0, w.nz - 1)
	var j1 := clampi(int(ceilf((c.z + ext - w.origin.y) / w.step)), 0, w.nz - 1)
	var inv := xf.affine_inverse()
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var p := Vector3(w.origin.x + float(i) * w.step, c.y, w.origin.y + float(j) * w.step)
			var hit := false
			if round_r >= 0.0:
				hit = Vector2(p.x - c.x, p.z - c.z).length() <= round_r * maxf(sc.x, sc.z) + INFLATE
			else:
				var l := inv * p
				hit = absf(l.x) <= half.x + INFLATE / maxf(sc.x, 0.01) and absf(l.z) <= half.z + INFLATE / maxf(sc.z, 0.01)
			if hit and not a.is_point_solid(Vector2i(i, j)):
				a.set_point_solid(Vector2i(i, j), true)
				blocked_cells += 1


static func _stamp_convex(a: AStarGrid2D, w: IslandWorld, cs: CollisionShape3D, sh: ConvexPolygonShape3D) -> void:
	var xf := cs.global_transform
	var pts := sh.points
	if pts.size() < 3:
		return
	var lo := INF
	var hi := -INF
	var poly := PackedVector2Array()
	for p in pts:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	for p in pts:
		if absf(p.y - lo) < 0.01:
			poly.append(Vector2(p.x, p.z))
	poly = Geometry2D.convex_hull(poly)
	if poly.size() < 3:
		return
	var c := xf.origin
	var ground := w.height_at(c.x, c.z)
	if c.y + hi < ground + LOW or c.y + lo > ground + HIGH:
		return
	var ext := 0.0
	for q in poly:
		ext = maxf(ext, q.length())
	ext += INFLATE
	var i0 := clampi(int(floorf((c.x - ext - w.origin.x) / w.step)), 0, w.nx - 1)
	var i1 := clampi(int(ceilf((c.x + ext - w.origin.x) / w.step)), 0, w.nx - 1)
	var j0 := clampi(int(floorf((c.z - ext - w.origin.y) / w.step)), 0, w.nz - 1)
	var j1 := clampi(int(ceilf((c.z + ext - w.origin.y) / w.step)), 0, w.nz - 1)
	var inv := xf.affine_inverse()
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var l := inv * Vector3(w.origin.x + float(i) * w.step, c.y, w.origin.y + float(j) * w.step)
			var q := Vector2(l.x, l.z)
			var hit := Geometry2D.is_point_in_polygon(q, poly)
			if not hit:
				for k in poly.size():
					var cp := Geometry2D.get_closest_point_to_segment(q, poly[k], poly[(k + 1) % poly.size()])
					if cp.distance_to(q) <= INFLATE:
						hit = true
						break
			if hit and not a.is_point_solid(Vector2i(i, j)):
				a.set_point_solid(Vector2i(i, j), true)
				blocked_cells += 1


static func _cell(p: Vector3) -> Vector2i:
	return Vector2i(clampi(roundi((p.x - _w.origin.x) / _w.step), 0, _w.nx - 1),
		clampi(roundi((p.z - _w.origin.y) / _w.step), 0, _w.nz - 1))


## Ближайшая свободная клетка к c (в радиусе r клеток; c — если свободна или ничего рядом).
static func _free_near(c: Vector2i, r: int) -> Vector2i:
	if not _astar.is_point_solid(c):
		return c
	for d in range(1, r + 1):
		var best := Vector2i(-1, -1)
		var bd := 1 << 30
		for j in range(c.y - d, c.y + d + 1):
			for i in range(c.x - d, c.x + d + 1):
				if absi(i - c.x) != d and absi(j - c.y) != d:
					continue
				var q := Vector2i(i, j)
				if not _astar.is_in_boundsv(q) or _astar.is_point_solid(q):
					continue
				var dd := (q - c).length_squared()
				if dd < bd:
					bd = dd
					best = q
		if best.x >= 0:
			return best
	return c


## Точки пути по земле от from к to (без первой клетки); [] — сетки нет или пути нет.
static func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var res := PackedVector3Array()
	if _astar == null or _w == null or not is_instance_valid(_w):
		return res
	var a := _free_near(_cell(from), 4)
	var b := _free_near(_cell(to), 6)
	if _astar.is_point_solid(a) or _astar.is_point_solid(b):
		return res
	var ids := _astar.get_id_path(a, b)
	for k in range(1, ids.size()):
		var c: Vector2i = ids[k]
		var x := _w.origin.x + float(c.x) * _w.step
		var z := _w.origin.y + float(c.y) * _w.step
		res.append(Vector3(x, 0.0, z))
	return res


## Свободна ли клетка точки p (для обхода).
static func free_at(p: Vector3) -> bool:
	if _astar == null or _w == null or not is_instance_valid(_w):
		return true
	var c := _cell(p)
	return not _astar.is_point_solid(c)
