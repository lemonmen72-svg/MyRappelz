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
	_astar = a


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
