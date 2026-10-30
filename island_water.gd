class_name IslandWater
extends RefCounted
## Вода острова в аниме-стиле: море, река и пруд — один меш с одним материалом (water.gdshader),
## поэтому нет перекрытий прозрачных слоёв и шва в устье реки (уровень и цвет реки плавно
## переходят в море). Плюс скалистый берег (IslandShore).
##
## Меш: сетка с шагом STEP узлов сетки острова только там, где есть вода (море у берега и дальше,
## русло реки, пруд), и «юбка» до горизонта. В вершинах:
##   UV — течение реки (s вдоль русла, t поперёк, м; у пруда — мировые x, z);
##   UV2 — (доля «реки/пруда» 0..1, сила морских волн 0..1); COLOR.r — скорость течения (0 — стоячая вода).
## Текстура данных (по узлу на метр): R — расстояние до берега со знаком, G — глубина под уровнем
## ближайшей воды, B — пена вокруг камней в воде. Из неё шейдер считает градиент глубины и пену
## у берега без текстуры глубины экрана (её нет в GL Compatibility).

## Шаг сетки воды в узлах сетки острова.
const STEP := 2
## Диапазоны кодирования в текстуре данных, м.
const CD_RANGE := 24.0
const DEPTH_RANGE := 8.0
## Вода реки и пруда до такого расстояния от оси / края, м (дальше её закрывают берега).
const RIVER_REACH := 7.5
## Море до такого расстояния вглубь суши, м (дальше берег выше воды).
const SEA_REACH := 3.5
## «Юбка» моря за краем карты, м.
const SKIRT := 900.0
## Ширина пены вокруг камня в воде, м.
const ROCK_FOAM := 2.4
## Концы реки у моря продлеваются в море на столько, м.
const MOUTH_EXTEND := 10.0

## Материал воды (Quality переключает облегчённый режим шейдера).
static var material: ShaderMaterial = null


static func build(world: IslandWorld) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var water_rocks := IslandShore.build(world, rng)
	var cd := _coast_grid(world)
	var tex := _data_texture(world, cd, water_rocks)
	var flow := _river_flow(world)

	var mat := ShaderMaterial.new()
	mat.shader = load("res://water.gdshader")
	mat.set_shader_parameter("data_tex", tex)
	mat.set_shader_parameter("data_origin", Vector2(world.origin.x - 0.5 * world.step, world.origin.y - 0.5 * world.step))
	mat.set_shader_parameter("data_size", Vector2(float(world.nx) * world.step, float(world.nz) * world.step))
	mat.set_shader_parameter("cd_range", CD_RANGE)
	mat.set_shader_parameter("depth_range", DEPTH_RANGE)
	mat.set_shader_parameter("sun_dir", _sun_dir(world))
	mat.set_shader_parameter("rich", Quality.rich_shaders())
	material = mat

	var mi := MeshInstance3D.new()
	mi.name = "Water"
	mi.mesh = _water_mesh(world, cd, flow)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("no_outline", true)
	world.add_child(mi)


## Направление на солнце (для бликов): ось +Z первого DirectionalLight3D в мире.
static func _sun_dir(world: IslandWorld) -> Vector3:
	for c in world.get_children():
		var sun := c as DirectionalLight3D
		if sun != null:
			return sun.transform.basis.z.normalized()
	return Vector3(0.4, 0.8, 0.45).normalized()


## Расстояние до берега во всех узлах сетки острова.
static func _coast_grid(world: IslandWorld) -> PackedFloat32Array:
	var cd := PackedFloat32Array()
	cd.resize(world.nx * world.nz)
	for j in world.nz:
		var z := world.origin.y + float(j) * world.step
		for i in world.nx:
			cd[j * world.nx + i] = world.coast_distance(world.origin.x + float(i) * world.step, z)
	return cd


## Уровень воды в узле: река у устья плавно опускается к уровню моря, пруд — свой уровень.
static func _level(world: IslandWorld, k: int, cdv: float) -> float:
	var wl := world.water_level[k]
	if world.water_d[k] < IslandWorld.FAR and absf(wl - world.river_level) < 0.001:
		return lerpf(world.sea_level, world.river_level, smoothstep(1.5, 12.0, cdv))
	return maxf(wl, world.sea_level)


static func _is_pond(world: IslandWorld, k: int) -> bool:
	var wl := world.water_level[k]
	return world.water_d[k] < RIVER_REACH and absf(wl - world.river_level) > 0.001 \
		and absf(wl - world.sea_level) > 0.001


# ---------- Текстура данных ----------

static func _data_texture(world: IslandWorld, cd: PackedFloat32Array, rocks: Array) -> ImageTexture:
	var n := world.nx * world.nz
	var bytes := PackedByteArray()
	bytes.resize(n * 4)
	for k in n:
		var cdv := cd[k]
		var depth := _level(world, k, cdv) - world.heights[k]
		bytes[k * 4] = clampi(int(roundf((clampf(cdv / CD_RANGE, -1.0, 1.0) * 0.5 + 0.5) * 255.0)), 0, 255)
		bytes[k * 4 + 1] = clampi(int(roundf(depth / DEPTH_RANGE * 255.0)), 0, 255)
		bytes[k * 4 + 2] = 0
		bytes[k * 4 + 3] = 255
	# Пена вокруг камней: 1 у камня → 0 на расстоянии радиус + ROCK_FOAM
	for wr in rocks:
		var c: Vector2 = wr[0]
		var r: float = wr[1]
		var reach := r + ROCK_FOAM
		var i0 := clampi(int((c.x - reach - world.origin.x) / world.step), 0, world.nx - 1)
		var i1 := clampi(int((c.x + reach - world.origin.x) / world.step) + 1, 0, world.nx - 1)
		var j0 := clampi(int((c.y - reach - world.origin.y) / world.step), 0, world.nz - 1)
		var j1 := clampi(int((c.y + reach - world.origin.y) / world.step) + 1, 0, world.nz - 1)
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var p := Vector2(world.origin.x + float(i) * world.step, world.origin.y + float(j) * world.step)
				var v := 1.0 - smoothstep(r * 0.5, reach, p.distance_to(c))
				var b := clampi(int(roundf(v * 255.0)), 0, 255)
				var k := (j * world.nx + i) * 4 + 2
				if b > bytes[k]:
					bytes[k] = b
	var img := Image.create_from_data(world.nx, world.nz, false, Image.FORMAT_RGBA8, bytes)
	return ImageTexture.create_from_image(img)


# ---------- Течение реки ----------

## Сглаженная линия ветки (Catmull-Rom, точка на ~1 м); концы у моря продлены в море.
static func _smooth_branch(world: IslandWorld, pts: Array) -> PackedVector2Array:
	var ctrl := PackedVector2Array()
	for p in pts:
		ctrl.append(IslandWorld.v2(p))
	if ctrl.size() < 2:
		return ctrl
	var a := ctrl[0]
	if world.coast_distance(a.x, a.y) < 12.0:
		ctrl.insert(0, a + (a - ctrl[1]).normalized() * MOUTH_EXTEND)
	var e := ctrl[ctrl.size() - 1]
	if world.coast_distance(e.x, e.y) < 12.0:
		ctrl.append(e + (e - ctrl[ctrl.size() - 2]).normalized() * MOUTH_EXTEND)
	var res := PackedVector2Array()
	var last := ctrl.size() - 1
	for s in last:
		var p0 := ctrl[maxi(s - 1, 0)]
		var p1 := ctrl[s]
		var p2 := ctrl[s + 1]
		var p3 := ctrl[mini(s + 2, last)]
		var steps := maxi(1, int(ceilf(p1.distance_to(p2))))
		for q in steps:
			var t := float(q) / float(steps)
			var t2 := t * t
			var t3 := t2 * t
			res.append(0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
				+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3))
	res.append(ctrl[last])
	return res


## Для узлов сетки воды у реки: расстояние до сглаженной оси и координаты течения (s, t).
## Возвращает {"d": PackedFloat32Array, "s": ..., "t": ...} размером nx*nz (заполнены узлы с шагом STEP).
static func _river_flow(world: IslandWorld) -> Dictionary:
	var n := world.nx * world.nz
	var best := PackedFloat32Array()
	var sa := PackedFloat32Array()
	var ta := PackedFloat32Array()
	best.resize(n)
	sa.resize(n)
	ta.resize(n)
	best.fill(1.0e9)
	sa.fill(0.0)
	ta.fill(0.0)
	var reach := RIVER_REACH + 4.0
	var curves: Array = []
	var lengths: Array = []
	for br in world.cfg.get("river", {}).get("branches", []):
		var curve := _smooth_branch(world, br)
		if curve.size() < 2:
			continue
		# Ветка, отходящая от другой, продолжает её отсчёт s (без скачка узора в развилке)
		var s0 := 0.0
		var bd := 1.0e9
		for ci in curves.size():
			var other: PackedVector2Array = curves[ci]
			var other_ls: PackedFloat32Array = lengths[ci]
			for om in other.size():
				var dd := other[om].distance_to(curve[0])
				if dd < bd:
					bd = dd
					s0 = other_ls[om]
		if bd > 6.0:
			s0 = 0.0
		var ls := PackedFloat32Array()
		ls.resize(curve.size())
		var acc := s0
		for m in curve.size():
			if m > 0:
				acc += curve[m].distance_to(curve[m - 1])
			ls[m] = acc
		curves.append(curve)
		lengths.append(ls)
		for m in curve.size():
			var c := curve[m]
			var dir := (curve[mini(m + 1, curve.size() - 1)] - curve[maxi(m - 1, 0)]).normalized()
			var i0 := clampi(int(ceilf((c.x - reach - world.origin.x) / world.step / STEP)) * STEP, 0, world.nx - 1)
			var i1 := clampi(int((c.x + reach - world.origin.x) / world.step), 0, world.nx - 1)
			var j0 := clampi(int(ceilf((c.y - reach - world.origin.y) / world.step / STEP)) * STEP, 0, world.nz - 1)
			var j1 := clampi(int((c.y + reach - world.origin.y) / world.step), 0, world.nz - 1)
			var j := j0
			while j <= j1:
				var i := i0
				while i <= i1:
					var p := Vector2(world.origin.x + float(i) * world.step, world.origin.y + float(j) * world.step)
					var rel := p - c
					var d := rel.length()
					var k := j * world.nx + i
					if d < best[k]:
						best[k] = d
						sa[k] = ls[m] + rel.dot(dir)
						ta[k] = dir.x * rel.y - dir.y * rel.x
					i += STEP
				j += STEP
	return {"d": best, "s": sa, "t": ta}


# ---------- Меш воды ----------

static func _water_mesh(world: IslandWorld, cd: PackedFloat32Array, flow: Dictionary) -> ArrayMesh:
	var best: PackedFloat32Array = flow["d"]
	var sa: PackedFloat32Array = flow["s"]
	var ta: PackedFloat32Array = flow["t"]
	var gw := (world.nx - 1) / STEP + 1
	var gh := (world.nz - 1) / STEP + 1
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var colors := PackedColorArray()
	var idx := PackedInt32Array()
	var vid := PackedInt32Array()
	vid.resize(gw * gh)
	vid.fill(-1)
	var sea := world.sea_level
	for gj in gh:
		for gi in gw:
			var i := gi * STEP
			var j := gj * STEP
			var k := j * world.nx + i
			var p := Vector2(world.origin.x + float(i) * world.step, world.origin.y + float(j) * world.step)
			var cdv := cd[k]
			var on_river := best[k] < RIVER_REACH or (world.water_d[k] < RIVER_REACH \
				and absf(world.water_level[k] - world.river_level) < 0.001)
			var y := sea
			var share := 0.0
			var amp := 1.0
			var uv := Vector2.ZERO
			var speed := 0.0
			if _is_pond(world, k):
				y = world.water_level[k]
				share = 1.0
				amp = 0.0
				uv = p
			elif on_river:
				var axis := minf(best[k], world.water_d[k])
				y = lerpf(sea, world.river_level, smoothstep(1.5, 12.0, cdv))
				share = smoothstep(-6.0, -1.0, cdv) * (1.0 - smoothstep(RIVER_REACH - 3.0, RIVER_REACH, axis))
				amp = 1.0 - share
				if best[k] < 1.0e8:
					uv = Vector2(sa[k], ta[k])
				speed = 1.0
			elif cdv >= SEA_REACH:
				continue
			vid[gj * gw + gi] = verts.size()
			verts.append(Vector3(p.x, y, p.y))
			uvs.append(uv)
			uv2s.append(Vector2(share, amp))
			colors.append(Color(speed, 0.0, 0.0, 1.0))
	for gj in gh - 1:
		for gi in gw - 1:
			var a := vid[gj * gw + gi]
			var b := vid[gj * gw + gi + 1]
			var c := vid[(gj + 1) * gw + gi]
			var d := vid[(gj + 1) * gw + gi + 1]
			if a < 0 or b < 0 or c < 0 or d < 0:
				continue
			idx.append_array([a, b, c, b, d, c])

	# «Юбка» до горизонта: каждая вершина края сетки соединяется с точкой на дальнем прямоугольнике
	var xmin := world.origin.x
	var zmin := world.origin.y
	var xmax := xmin + float((gw - 1) * STEP) * world.step
	var zmax := zmin + float((gh - 1) * STEP) * world.step
	var sides: Array = [
		[_edge(vid, gw, gh, 0), false, true],
		[_edge(vid, gw, gh, 1), false, false],
		[_edge(vid, gw, gh, 2), true, true],
		[_edge(vid, gw, gh, 3), true, false],
	]
	for side in sides:
		var inner: PackedInt32Array = side[0]
		var vertical: bool = side[1]
		var low: bool = side[2]
		var outer := PackedInt32Array()
		for v in inner:
			if v < 0:
				outer.append(-1)
				continue
			var q := verts[v]
			var o := Vector3.ZERO
			if vertical:
				var tz := (q.z - zmin) / (zmax - zmin)
				o = Vector3(xmin - SKIRT if low else xmax + SKIRT, sea, lerpf(zmin - SKIRT, zmax + SKIRT, tz))
			else:
				var tx := (q.x - xmin) / (xmax - xmin)
				o = Vector3(lerpf(xmin - SKIRT, xmax + SKIRT, tx), sea, zmin - SKIRT if low else zmax + SKIRT)
			outer.append(verts.size())
			verts.append(o)
			uvs.append(Vector2.ZERO)
			uv2s.append(Vector2(0.0, 0.0))
			colors.append(Color(0.0, 0.0, 0.0, 1.0))
		for e in inner.size() - 1:
			var a := inner[e]
			var b := inner[e + 1]
			var oa := outer[e]
			var ob := outer[e + 1]
			if a < 0 or b < 0 or oa < 0 or ob < 0:
				continue
			idx.append_array([a, b, oa, b, ob, oa])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Вершины края сетки воды: 0 — север (z мин.), 1 — юг, 2 — запад (x мин.), 3 — восток.
static func _edge(vid: PackedInt32Array, gw: int, gh: int, side: int) -> PackedInt32Array:
	var res := PackedInt32Array()
	if side < 2:
		var gj := 0 if side == 0 else gh - 1
		for gi in gw:
			res.append(vid[gj * gw + gi])
	else:
		var gi := 0 if side == 2 else gw - 1
		for gj in gh:
			res.append(vid[gj * gw + gi])
	return res
