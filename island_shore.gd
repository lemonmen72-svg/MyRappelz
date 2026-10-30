class_name IslandShore
extends RefCounted
## Скалистый берег острова: ряд низкополигональных скал-«столбов» вдоль береговой линии
## (обрывы как на референсе: серый камень, мох на макушке, тёмная мокрая полоса у воды),
## отдельные скалы в море и камни в русле реки. Без коллизии (там всё равно непроходимо).
## Все камни запекаются в несколько ArrayMesh по участкам CHUNK×CHUNK м (мало вызовов отрисовки,
## дальние участки отсекаются камерой). Порт, причал, корабль и устья реки остаются свободными.
##
## build() возвращает камни у воды и в воде: [[Vector2 центр, float радиус], ...] — IslandWater
## рисует вокруг них пену (на суше она не видна).

## Шаг сетки кандидатов вдоль берега, м.
const CELL := 1.6
## Наименьшее расстояние между скалами вдоль берега, м.
const SPACING := 2.3
## Размер участка меша, м.
const CHUNK := 64.0
## Вариантов формы скалы.
const PROTOS := 6

const STONE := Color(0.62, 0.60, 0.57)
const STONE_DARK := Color(0.48, 0.47, 0.50)
const MOSS := Color(0.44, 0.62, 0.30)
const WET := Color(0.24, 0.30, 0.34)


static func build(world: IslandWorld, rng: RandomNumberGenerator) -> Array:
	var protos: Array = []
	for n in PROTOS:
		protos.append(_proto(rng, 6 if n % 2 == 0 else 7))
	var small_proto: PackedVector3Array = _proto(rng, 5)
	var chunks := {}
	var water_rocks: Array = []
	var blocked := _blocked_areas(world)
	_place_cliffs(world, rng, protos, small_proto, chunks, blocked, water_rocks)
	_place_sea_rocks(world, rng, protos, chunks, blocked, water_rocks)
	_place_river_rocks(world, rng, small_proto, chunks, water_rocks)

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	Util.toon(mat)
	mat.rim_enabled = false
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.set_meta("toon_done", true)
	var holder := Node3D.new()
	holder.name = "Shore"
	world.add_child(holder)
	for key in chunks:
		var acc: Dictionary = chunks[key]
		var verts: PackedVector3Array = acc["v"]
		if verts.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = acc["n"]
		arrays[Mesh.ARRAY_COLOR] = acc["c"]
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mi := MeshInstance3D.new()
		mi.name = "Rocks"
		mi.mesh = m
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("no_outline", true)
		holder.add_child(mi)
	return water_rocks


# ---------- Форма скалы ----------

## Заготовка скалы: список треугольников (по 3 точки) в единичном объёме: основание радиуса ~1
## на y = −0.1, верх на y ≈ 1. Гранёный столб: нижнее кольцо, среднее кольцо, сужение к макушке
## и неровная плоская макушка (на ней растёт мох).
static func _proto(rng: RandomNumberGenerator, seg: int) -> PackedVector3Array:
	var rings: Array = []
	var ys := [-0.1, rng.randf_range(0.45, 0.62), rng.randf_range(0.86, 0.95)]
	var rs := [1.0, rng.randf_range(0.86, 0.98), rng.randf_range(0.55, 0.72)]
	var twist := rng.randf_range(-0.2, 0.2)
	var lean := Vector2(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.12, 0.12))
	for r in 3:
		var row := PackedVector3Array()
		for i in seg:
			var a := TAU * float(i) / float(seg) + twist * float(r)
			var k: float = float(rs[r]) * rng.randf_range(0.84, 1.12)
			var y: float = float(ys[r]) + (rng.randf_range(-0.06, 0.06) if r > 0 else 0.0)
			var off := lean * y
			row.append(Vector3(cos(a) * k + off.x, y, sin(a) * k + off.y))
		rings.append(row)
	var top := Vector3(lean.x, rng.randf_range(0.98, 1.06), lean.y)
	var tris := PackedVector3Array()
	for r in 2:
		var ra: PackedVector3Array = rings[r]
		var rb: PackedVector3Array = rings[r + 1]
		for i in seg:
			var i2 := (i + 1) % seg
			tris.append_array([ra[i], ra[i2], rb[i]])
			tris.append_array([ra[i2], rb[i2], rb[i]])
	var rt: PackedVector3Array = rings[2]
	for i in seg:
		tris.append_array([rt[i], rt[(i + 1) % seg], top])
	return tris


## Запекает скалу в участок меша. xf — из единичной заготовки в мир; water_y — уровень воды
## у камня (мокрая полоса); moss — зелёная макушка.
static func _bake(chunks: Dictionary, proto: PackedVector3Array, xf: Transform3D, water_y: float,
		moss: bool, rng: RandomNumberGenerator) -> void:
	var key := Vector2i(int(floorf(xf.origin.x / CHUNK)), int(floorf(xf.origin.z / CHUNK)))
	if not chunks.has(key):
		chunks[key] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray()}
	var acc: Dictionary = chunks[key]
	var verts: PackedVector3Array = acc["v"]
	var normals: PackedVector3Array = acc["n"]
	var colors: PackedColorArray = acc["c"]
	var axis := xf * Vector3(0, 0.45, 0)
	var base := STONE.lerp(STONE_DARK, rng.randf()) * rng.randf_range(0.92, 1.06)
	base.a = 1.0
	var t := 0
	while t < proto.size():
		var p0 := xf * proto[t]
		var p1 := xf * proto[t + 1]
		var p2 := xf * proto[t + 2]
		t += 3
		var n := (p2 - p0).cross(p1 - p0)
		if n.length_squared() < 0.000001:
			continue
		n = n.normalized()
		var mid := (p0 + p1 + p2) / 3.0
		# Заготовка уже смотрит наружу (порядок вершин — как у WorldBuilder._flat_tri);
		# на всякий случай: макушка вверх, бока — от оси камня
		var out := mid - axis
		var flip := n.y < 0.0 if absf(n.y) > 0.7 else Vector2(n.x, n.z).dot(Vector2(out.x, out.z)) < 0.0
		if flip:
			var tmp := p1
			p1 = p2
			p2 = tmp
			n = -n
		var c := base
		if n.y > 0.6:
			c = MOSS * rng.randf_range(0.92, 1.06) if moss else base * 1.14
		elif n.y < -0.1:
			c = base * 0.72
		else:
			# Грани чередуются по яркости: «рубленый» камень
			c = base * rng.randf_range(0.86, 1.04)
		c.a = 1.0
		for v in [p0, p1, p2]:
			var vp: Vector3 = v
			var vc := c
			# Мокрая тёмная полоса у воды и ниже
			var wet := 1.0 - smoothstep(water_y + 0.05, water_y + 0.55, vp.y)
			vc = vc.lerp(WET, wet * 0.7)
			vc.a = 1.0
			verts.append(vp)
			normals.append(n)
			colors.append(vc)
	acc["v"] = verts
	acc["n"] = normals
	acc["c"] = colors


static func _xf(pos: Vector3, radius: float, height: float, rng: RandomNumberGenerator) -> Transform3D:
	var b := Basis(Vector3.UP, rng.randf() * TAU)
	b = b * Basis(Vector3.RIGHT, rng.randf_range(-0.08, 0.08)) * Basis(Vector3.FORWARD, rng.randf_range(-0.08, 0.08))
	b = b * Basis.from_scale(Vector3(radius, height, radius * rng.randf_range(0.7, 1.0)))
	return Transform3D(b, pos)


# ---------- Расстановка ----------

## Свободные места: [[Vector2 центр, float радиус], ...] — порт, причал, корабль, переходы.
static func _blocked_areas(world: IslandWorld) -> Array:
	var res: Array = []
	for p in world.cfg.get("pois", []):
		var poi: Dictionary = p
		var t := String(poi.get("type", ""))
		var c := IslandWorld.v2(poi["center"])
		if t == "port":
			res.append([c, float(poi.get("radius", 10.0)) + 9.0])
		elif t == "pier":
			var length := float(poi.get("length", 16.0))
			var dir := Vector2(0, 1).rotated(deg_to_rad(float(poi.get("rotation", 0.0))))
			var k := -0.6
			while k <= 0.6:
				res.append([c + dir * length * k, 9.0])
				k += 0.2
		elif t == "ship":
			res.append([c, 13.0])
	for tr in world.transitions():
		var d: Dictionary = tr
		res.append([IslandWorld.v2(d["center"]), 9.0])
	return res


static func _is_blocked(blocked: Array, p: Vector2) -> bool:
	for b in blocked:
		var c: Vector2 = b[0]
		if p.distance_to(c) < float(b[1]):
			return true
	return false


static func _near_taken(taken: Dictionary, p: Vector2, dist: float) -> bool:
	var cell := Vector2i(int(floorf(p.x / 4.0)), int(floorf(p.y / 4.0)))
	for dj in range(-1, 2):
		for di in range(-1, 2):
			var key := cell + Vector2i(di, dj)
			if not taken.has(key):
				continue
			for q in taken[key]:
				if p.distance_to(q) < dist:
					return true
	return false


static func _take(taken: Dictionary, p: Vector2) -> void:
	var key := Vector2i(int(floorf(p.x / 4.0)), int(floorf(p.y / 4.0)))
	if not taken.has(key):
		taken[key] = []
	taken[key].append(p)


## Направление вглубь суши (градиент расстояния до берега).
static func _inland(world: IslandWorld, p: Vector2) -> Vector2:
	var gx := world.coast_distance(p.x + 1.0, p.y) - world.coast_distance(p.x - 1.0, p.y)
	var gz := world.coast_distance(p.x, p.y + 1.0) - world.coast_distance(p.x, p.y - 1.0)
	var g := Vector2(gx, gz)
	if g.length_squared() < 0.0001:
		return Vector2.ZERO
	return g.normalized()


## Скалы вдоль береговой линии: по одной на клетку сетки, где клетка пересекает берег.
static func _place_cliffs(world: IslandWorld, rng: RandomNumberGenerator, protos: Array,
		small_proto: PackedVector3Array, chunks: Dictionary, blocked: Array, water_rocks: Array) -> void:
	var river_half := float(world.cfg.get("river", {}).get("width", 5.0)) * 0.5
	var x0 := world.origin.x
	var z0 := world.origin.y
	var x1 := x0 + float(world.nx - 1) * world.step
	var z1 := z0 + float(world.nz - 1) * world.step
	var sea := world.sea_level
	var taken := {}
	var z := z0
	while z < z1:
		var x := x0
		while x < x1:
			var p := Vector2(x + rng.randf() * CELL, z + rng.randf() * CELL)
			x += CELL
			var cd := world.coast_distance(p.x, p.y)
			if absf(cd) > 2.0:
				continue
			if world.water_distance(p.x, p.y) < river_half + 6.0 or _is_blocked(blocked, p):
				continue
			var g := _inland(world, p)
			if g == Vector2.ZERO:
				continue
			var shore := p - g * cd
			var land_h := world.height_at(shore.x + g.x * 3.0, shore.y + g.y * 3.0)
			var low := land_h < sea + 0.7
			if low and rng.randf() < 0.55:
				continue
			# Ровный шаг вдоль берега: скалы стоят стеной, без пустот и скоплений
			if _near_taken(taken, shore, SPACING):
				continue
			_take(taken, shore)
			var top := land_h + rng.randf_range(-0.5, 0.55)
			if low:
				top = sea + rng.randf_range(0.25, 0.8)
			var bottom := sea - 1.4
			var h := maxf(top - bottom, 1.2)
			var r := clampf(h * 0.42, 1.1, 2.4) * rng.randf_range(0.8, 1.2)
			var c := shore + g * rng.randf_range(-0.6, 0.3) * r
			var proto: PackedVector3Array = protos[rng.randi() % protos.size()]
			_bake(chunks, proto, _xf(Vector3(c.x, bottom, c.y), r, h, rng), sea, not low and rng.randf() < 0.75, rng)
			water_rocks.append([c, r])
			# Иногда — валун у подножия, в воде
			if rng.randf() < 0.3:
				var bp := shore - g * rng.randf_range(1.2, 2.4) * r + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
				if not _is_blocked(blocked, bp):
					var br := rng.randf_range(0.5, 0.95)
					var bh := sea - world.height_at(bp.x, bp.y) + rng.randf_range(0.2, 0.6)
					_bake(chunks, small_proto, _xf(Vector3(bp.x, world.height_at(bp.x, bp.y) - 0.2, bp.y), br,
						maxf(bh, 0.6), rng), sea, false, rng)
					water_rocks.append([bp, br])
		z += CELL


## Отдельные скалы и группы скал в море недалеко от берега (с пеной вокруг).
static func _place_sea_rocks(world: IslandWorld, rng: RandomNumberGenerator, protos: Array,
		chunks: Dictionary, blocked: Array, water_rocks: Array) -> void:
	var x0 := world.origin.x
	var z0 := world.origin.y
	var w := float(world.nx - 1) * world.step
	var d := float(world.nz - 1) * world.step
	var sea := world.sea_level
	var placed := 0
	var tries := 0
	while placed < 16 and tries < 4000:
		tries += 1
		var p := Vector2(x0 + rng.randf() * w, z0 + rng.randf() * d)
		var cd := world.coast_distance(p.x, p.y)
		if cd > -3.0 or cd < -10.0 or _is_blocked(blocked, p):
			continue
		var far := true
		for wr in water_rocks:
			if p.distance_to(wr[0]) < 14.0:
				far = false
				break
		if not far:
			continue
		placed += 1
		for k in rng.randi_range(1, 3):
			var q := p + Vector2(rng.randf_range(-2.2, 2.2), rng.randf_range(-2.2, 2.2)) * float(k)
			var r := rng.randf_range(0.9, 2.0) / (1.0 + float(k) * 0.35)
			var bottom := world.height_at(q.x, q.y) - 0.3
			var top := sea + rng.randf_range(0.5, 2.4) / (1.0 + float(k) * 0.5)
			var proto: PackedVector3Array = protos[rng.randi() % protos.size()]
			_bake(chunks, proto, _xf(Vector3(q.x, bottom, q.y), r, maxf(top - bottom, 1.0), rng), sea,
				rng.randf() < 0.4, rng)
			water_rocks.append([q, r])


## Камни в русле реки у берегов (вдали от мостов и устьев), вода обтекает их пеной.
static func _place_river_rocks(world: IslandWorld, rng: RandomNumberGenerator,
		proto: PackedVector3Array, chunks: Dictionary, water_rocks: Array) -> void:
	var river: Dictionary = world.cfg.get("river", {})
	var lvl := world.river_level
	for br in river.get("branches", []):
		var pts: Array = br
		for s in range(pts.size() - 1):
			var a := IslandWorld.v2(pts[s])
			var b := IslandWorld.v2(pts[s + 1])
			var dir := (b - a).normalized()
			var side := Vector2(-dir.y, dir.x)
			var t := rng.randf_range(4.0, 9.0)
			while t < a.distance_to(b) - 3.0:
				var c := a + dir * t
				t += rng.randf_range(10.0, 18.0)
				if rng.randf() < 0.45 or world.coast_distance(c.x, c.y) < 8.0:
					continue
				var near_bridge := false
				for bd in world.bridges:
					var ba: Vector3 = bd["a"]
					var bb: Vector3 = bd["b"]
					if c.distance_to(Vector2(ba.x + bb.x, ba.z + bb.z) * 0.5) < 12.0:
						near_bridge = true
						break
				if near_bridge:
					continue
				var q := c + side * rng.randf_range(1.8, 3.0) * (1.0 if rng.randf() < 0.5 else -1.0)
				var r := rng.randf_range(0.45, 0.85)
				var bottom := world.height_at(q.x, q.y) - 0.2
				var top := lvl + rng.randf_range(0.15, 0.45)
				_bake(chunks, proto, _xf(Vector3(q.x, bottom, q.y), r, maxf(top - bottom, 0.5), rng), lvl, false, rng)
				water_rocks.append([q, r])
