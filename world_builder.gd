class_name WorldBuilder
extends RefCounted
## Строит мир в аниме-стиле («пасторальное фэнтези»): небо и свет, земля с тропинками и каменной
## площадкой, трава и цветы (MultiMesh по участкам), деревья трёх видов, кусты, камни,
## декор площадки (фонари, флажки) и кольцо холмов и гор на горизонте.
## Звери, игрок и безопасная зона создаются в других модулях; центр (MobData.SAFE_RADIUS + 2) свободен.
## Всё содержимое собирается в коде из своих мешей и шейдеров, внешних ассетов нет.

## Половина размера карты: игрок ограничен ±70 м, земля с коллизией 200×200 м.
const MAP_HALF := 100.0
## Граница, за которую игрок не выходит.
const PLAY_HALF := 70.0
## Тропинки: углы выхода из центра (радианы, atan2(z, x)), извилистость, ширина (м).
## Те же числа передаются в шейдеры (world_common.gdshaderinc).
const PATH_ANGLES := [0.25, 1.75, 3.35, 4.75]
const PATH_WOBBLE := 0.18
const PATH_WIDTH := 1.9
## Трава: до какой координаты, шаг сетки (м), размер участка MultiMesh (м).
const GRASS_HALF := 88.0
const GRASS_STEP := 0.8
const CHUNK := 16.0
const WIND_DIR := Vector2(0.86, 0.5)

const KIND_ROUND := 0
const KIND_PINE := 1
const KIND_BLOSSOM := 2
const TREE_VARIANTS := 3


## Накопитель вершин для сборки своих мешей.
class MeshAcc:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	func add(p: Vector3, n: Vector3, c: Color, uv: Vector2) -> int:
		verts.append(p)
		normals.append(n)
		colors.append(c)
		uvs.append(uv)
		return verts.size() - 1

	func tri(a: int, b: int, c: int) -> void:
		indices.append(a)
		indices.append(b)
		indices.append(c)

	func to_mesh() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = indices
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return m


## Строит мир внутри root (узел main). rng — общий генератор с фиксированным зерном.
static func build(root: Node3D, rng: RandomNumberGenerator) -> void:
	_build_environment(root)
	_build_ground(root)
	var taken: Array[Vector3] = []
	_build_trees(root, rng, taken)
	_build_bushes_and_rocks(root, rng, taken)
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi() % 100000
	noise.frequency = 0.08
	_build_grass(root, rng, noise)
	_build_flowers(root, rng)
	_build_plaza_decor(root)
	_build_horizon(root, rng)


## Расстояние (м) от точки до ближайшей тропинки. Совпадает с wc_path_dist() в шейдере.
static func path_distance(x: float, z: float) -> float:
	var r := sqrt(x * x + z * z)
	var a := atan2(z, x)
	var best := INF
	for i in PATH_ANGLES.size():
		var base: float = PATH_ANGLES[i]
		var t := base + PATH_WOBBLE * sin(r * 0.06 + float(i) * 1.7)
		best = minf(best, absf(fposmod(a - t + PI, TAU) - PI) * r)
	return best


# --- Небо, свет, земля ---

static func _build_environment(root: Node3D) -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://sky.gdshader")
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Светлые голубоватые тени («аниме»), освещённые места остаются сочными
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.84, 1.0)
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	# Лёгкая дымка к горизонту
	env.fog_enabled = true
	env.fog_light_color = Color(0.74, 0.86, 1.0)
	env.fog_light_energy = 1.0
	env.fog_density = 0.0045
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_color = Color(1.0, 0.95, 0.84)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 55.0
	root.add_child(sun)


static func _shader_mat(path: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	var a0: float = PATH_ANGLES[0]
	var a1: float = PATH_ANGLES[1]
	var a2: float = PATH_ANGLES[2]
	var a3: float = PATH_ANGLES[3]
	m.set_shader_parameter("path_angles", Vector4(a0, a1, a2, a3))
	m.set_shader_parameter("path_wobble", PATH_WOBBLE)
	m.set_shader_parameter("path_width", PATH_WIDTH)
	m.set_shader_parameter("plaza_radius", MobData.SAFE_RADIUS)
	return m


static func _build_ground(root: Node3D) -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	var gcol := CollisionShape3D.new()
	var gshape := BoxShape3D.new()
	gshape.size = Vector3(MAP_HALF * 2.0, 1, MAP_HALF * 2.0)
	gcol.shape = gshape
	gcol.position.y = -0.5
	ground.add_child(gcol)
	# Видимая земля шире карты: под холмами горизонта
	var gm := MeshInstance3D.new()
	gm.set_meta("no_outline", true)
	var plane := PlaneMesh.new()
	plane.size = Vector2(420, 420)
	gm.mesh = plane
	gm.material_override = _shader_mat("res://terrain.gdshader")
	gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground.add_child(gm)
	root.add_child(ground)


# --- Сборка мешей ---

static func _grad(y: float, y0: float, y1: float, bottom: Color, top: Color) -> Color:
	return bottom.lerp(top, clampf((y - y0) / (y1 - y0), 0.0, 1.0))


static func _shade(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k)


## Сфера (или верхняя полусфера) с плавными нормалями и градиентом цвета по высоте.
static func _sphere(acc: MeshAcc, xf: Transform3D, seg: int, rings: int, bottom: Color, top: Color,
		y0: float, y1: float, hemi: bool = false) -> void:
	var nb := xf.basis.inverse().transposed()
	var base := acc.verts.size()
	var phi_max := PI * 0.5 if hemi else PI
	for j in rings + 1:
		var phi := phi_max * float(j) / float(rings)
		for i in seg + 1:
			var th := TAU * float(i) / float(seg)
			var n := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			var p := xf * n
			acc.add(p, (nb * n).normalized(), _grad(p.y, y0, y1, bottom, top),
				Vector2(float(i) / float(seg), float(j) / float(rings)))
	for j in rings:
		for i in seg:
			var a := base + j * (seg + 1) + i
			var b := a + seg + 1
			acc.tri(a, b, a + 1)
			acc.tri(a + 1, b, b + 1)


## Усечённый конус от y=0 до y=h (rt=0 — острый конус), по желанию с нижней крышкой.
static func _cone(acc: MeshAcc, xf: Transform3D, seg: int, rb: float, rt: float, h: float,
		bottom: Color, top: Color, y0: float, y1: float, cap: bool = false) -> void:
	var nb := xf.basis.inverse().transposed()
	var base := acc.verts.size()
	var slope := (rb - rt) / h
	for j in 2:
		var r := rb if j == 0 else rt
		for i in seg + 1:
			var th := TAU * float(i) / float(seg)
			var n := Vector3(cos(th), slope, sin(th)).normalized()
			var p := xf * Vector3(r * cos(th), h * float(j), r * sin(th))
			acc.add(p, (nb * n).normalized(), _grad(p.y, y0, y1, bottom, top), Vector2(float(i) / float(seg), float(j)))
	for i in seg:
		var t := base + seg + 1 + i
		var b := base + i
		acc.tri(t, b, t + 1)
		acc.tri(t + 1, b, b + 1)
	if cap:
		var down := (nb * Vector3.DOWN).normalized()
		var c0 := xf * Vector3.ZERO
		var center := acc.add(c0, down, bottom, Vector2(0.5, 0.5))
		var ring := acc.verts.size()
		for i in seg:
			var th := TAU * float(i) / float(seg)
			acc.add(xf * Vector3(rb * cos(th), 0.0, rb * sin(th)), down, bottom, Vector2.ZERO)
		for i in seg:
			acc.tri(center, ring + (i + 1) % seg, ring + i)


## Треугольник с плоской нормалью (низкополигональный вид). Порядок вершин — как у _sphere.
static func _flat_tri(acc: MeshAcc, p0: Vector3, p1: Vector3, p2: Vector3, c: Color) -> void:
	var n := (p2 - p0).cross(p1 - p0).normalized()
	var i := acc.add(p0, n, c, Vector2.ZERO)
	acc.add(p1, n, c, Vector2.ZERO)
	acc.add(p2, n, c, Vector2.ZERO)
	acc.tri(i, i + 1, i + 2)


## Материал с цветом из вершин (sRGB), toon-светом и контуром цвета outline_base.
static func _vc_mat(tint: Color, outline_base: Color, outline: bool = true) -> StandardMaterial3D:
	var m := Util.mat(tint)
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	if outline:
		m.next_pass = Util.outline_mat(outline_base)
	return m


static func _mesh_node(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


# --- Деревья ---

## Пышное круглое (или цветущее) дерево: [ствол, крона, высота центра кроны].
static func _make_round_tree(rng: RandomNumberGenerator, blossom: bool) -> Array:
	var th := rng.randf_range(1.6, 2.0) if blossom else rng.randf_range(2.0, 2.5)
	var bark_top := Color(0.50, 0.34, 0.30) if blossom else Color(0.56, 0.39, 0.25)
	var bark_bot := Color(0.32, 0.20, 0.20) if blossom else Color(0.36, 0.24, 0.16)
	var trunk := MeshAcc.new()
	_cone(trunk, Transform3D.IDENTITY, 8, 0.42, 0.27, 0.35, bark_bot, bark_top, 0.0, th)
	_cone(trunk, Transform3D(Basis.IDENTITY, Vector3(0, 0.3, 0)), 8, 0.27, 0.15, th + 0.5, bark_bot, bark_top, 0.0, th)
	for b in 2:
		var bb := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3(0, 0, 1), deg_to_rad(rng.randf_range(35.0, 50.0)))
		_cone(trunk, Transform3D(bb, Vector3(0, th * rng.randf_range(0.6, 0.8), 0)), 6, 0.1, 0.04, 1.0,
			bark_top, bark_top, 0.0, 1.0)

	var big_r := rng.randf_range(1.2, 1.4) if blossom else rng.randf_range(1.35, 1.6)
	var top := Color(0.92, 0.66, 0.76) if blossom else Color(0.52, 0.78, 0.30)
	var bot := Color(0.72, 0.38, 0.55) if blossom else Color(0.18, 0.46, 0.30)
	var white_top := Color(0.96, 0.88, 0.90)
	var white_bot := Color(0.80, 0.62, 0.72)
	var crown := MeshAcc.new()
	var blobs: Array = [[Vector3.ZERO, big_r]]
	var n := 5 if blossom else 4
	var a0 := rng.randf() * TAU
	for k in n:
		var a := a0 + float(k) * TAU / float(n) + rng.randf_range(-0.3, 0.3)
		var c := Vector3(cos(a) * big_r * 0.78, rng.randf_range(-0.4, 0.2) * big_r, sin(a) * big_r * 0.78)
		blobs.append([c, big_r * rng.randf_range(0.58, 0.74)])
	blobs.append([Vector3(rng.randf_range(-0.2, 0.2) * big_r, big_r * 0.72, rng.randf_range(-0.2, 0.2) * big_r),
		big_r * 0.66])
	for idx in blobs.size():
		var blob: Array = blobs[idx]
		var c: Vector3 = blob[0]
		var rad: float = blob[1]
		var k := rng.randf_range(0.92, 1.0)
		var t := top
		var bt := bot
		if blossom and idx > 0 and rng.randf() < 0.35:
			t = white_top
			bt = white_bot
		var xf := Transform3D(Basis.from_scale(Vector3(rad, rad * 0.88, rad)), c)
		_sphere(crown, xf, 10, 6, _shade(bt, k), _shade(t, k), -big_r * 0.95, big_r * 1.2)
	return [trunk.to_mesh(), crown.to_mesh(), th + big_r * 0.75]


## Хвойное дерево: ярусы конусов.
static func _make_pine(rng: RandomNumberGenerator) -> Array:
	var th := rng.randf_range(1.1, 1.5)
	var bark_top := Color(0.50, 0.34, 0.24)
	var bark_bot := Color(0.32, 0.21, 0.15)
	var trunk := MeshAcc.new()
	_cone(trunk, Transform3D.IDENTITY, 7, 0.36, 0.24, 0.3, bark_bot, bark_top, 0.0, th)
	_cone(trunk, Transform3D(Basis.IDENTITY, Vector3(0, 0.25, 0)), 7, 0.24, 0.08, th + 2.6, bark_bot, bark_top, 0.0, th)

	var top := Color(0.38, 0.68, 0.46)
	var bot := Color(0.10, 0.34, 0.30)
	var tiers := rng.randi_range(3, 4)
	var h := 1.75
	var step := 1.05
	var total := float(tiers - 1) * step + h
	var mid := total * 0.5
	var crown := MeshAcc.new()
	var r0 := rng.randf_range(1.6, 1.85)
	for k in tiers:
		var rb := r0 * (1.0 - float(k) * 0.2) * rng.randf_range(0.95, 1.05)
		var y := float(k) * step - mid
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(0, y, 0))
		_cone(crown, xf, 9, rb, 0.0, h, bot, top, y, y + h * 0.85, true)
	return [trunk.to_mesh(), crown.to_mesh(), th - 0.3 + mid]


static func _pick_kind(rng: RandomNumberGenerator, r: float) -> int:
	var x := rng.randf()
	if r < 35.0:
		return KIND_ROUND if x < 0.55 else (KIND_BLOSSOM if x < 0.9 else KIND_PINE)
	return KIND_ROUND if x < 0.45 else (KIND_PINE if x < 0.95 else KIND_BLOSSOM)


static func _tree_kits(rng: RandomNumberGenerator) -> Array:
	var kits := []
	var outline := [Color(0.35, 0.62, 0.30), Color(0.20, 0.48, 0.36), Color(0.85, 0.50, 0.62)]
	var tints := [
		[Color(1, 1, 1), Color(0.9, 1.0, 0.92), Color(1.0, 0.95, 0.84)],
		[Color(1, 1, 1), Color(0.9, 0.98, 1.0), Color(0.96, 1.0, 0.88)],
		[Color(1, 1, 1), Color(1.0, 0.92, 0.96), Color(0.96, 0.96, 1.0)],
	]
	for kind in 3:
		var kit := {"trunks": [], "crowns": [], "ys": [], "mats": []}
		for v in TREE_VARIANTS:
			var built: Array
			if kind == KIND_PINE:
				built = _make_pine(rng)
			else:
				built = _make_round_tree(rng, kind == KIND_BLOSSOM)
			(kit["trunks"] as Array).append(built[0])
			(kit["crowns"] as Array).append(built[1])
			(kit["ys"] as Array).append(built[2])
		var kind_tints: Array = tints[kind]
		for t in kind_tints:
			(kit["mats"] as Array).append(_vc_mat(t, outline[kind]))
		kit["trunk_mat"] = _vc_mat(Color.WHITE, Color(0.45, 0.3, 0.2))
		kits.append(kit)
	return kits


## Ставит дерево, если место свободно (не площадка, не тропинка, не вплотную к другому).
static func _try_tree(parent: Node3D, kits: Array, kind: int, p: Vector3, rng: RandomNumberGenerator,
		taken: Array[Vector3], spacing: float) -> bool:
	if Vector2(p.x, p.z).length() < MobData.SAFE_RADIUS + 4.0:
		return false
	if maxf(absf(p.x), absf(p.z)) > 92.0:
		return false
	if path_distance(p.x, p.z) < PATH_WIDTH * 0.5 + 2.0:
		return false
	for q in taken:
		if Vector2(q.x - p.x, q.z - p.z).length() < spacing:
			return false
	taken.append(p)
	var in_play := maxf(absf(p.x), absf(p.z)) <= PLAY_HALF + 2.0
	var holder: Node3D
	var s := rng.randf_range(0.85, 1.2)
	if in_play:
		var body := StaticBody3D.new()
		body.add_child(Util.pillar(0.35 * s, 2.4))
		holder = body
	else:
		holder = Node3D.new()  # опушка за краем карты: туда никто не заходит, коллизия не нужна
	holder.position = p
	holder.rotation.y = rng.randf() * TAU
	var kit: Dictionary = kits[kind]
	var v := rng.randi() % TREE_VARIANTS
	var trunk_mesh: Mesh = (kit["trunks"] as Array)[v]
	var crown_mesh: Mesh = (kit["crowns"] as Array)[v]
	var crown_y: float = (kit["ys"] as Array)[v]
	var mats: Array = kit["mats"]
	var trunk := _mesh_node(holder, trunk_mesh, kit["trunk_mat"], Vector3.ZERO)
	trunk.scale = Vector3.ONE * s
	var crown := _mesh_node(holder, crown_mesh, mats[rng.randi() % mats.size()], Vector3(0, crown_y * s, 0))
	crown.scale = Vector3.ONE * s
	parent.add_child(holder)
	return true


static func _random_ring(rng: RandomNumberGenerator, r0: float, r1: float) -> Vector3:
	var a := rng.randf() * TAU
	var r := sqrt(rng.randf_range(r0 * r0, r1 * r1))
	return Vector3(cos(a) * r, 0.0, sin(a) * r)


static func _build_trees(root: Node3D, rng: RandomNumberGenerator, taken: Array[Vector3]) -> void:
	var parent := Node3D.new()
	parent.name = "Trees"
	root.add_child(parent)
	var kits := _tree_kits(rng)
	# Рощи: в каждой преобладает один вид
	for g in 11:
		var center := _random_ring(rng, 18.0, 66.0)
		var kind := _pick_kind(rng, center.length())
		for i in rng.randi_range(4, 7):
			var p := center + Vector3(rng.randf_range(-6.5, 6.5), 0, rng.randf_range(-6.5, 6.5))
			var k := kind if rng.randf() < 0.75 else _pick_kind(rng, p.length())
			_try_tree(parent, kits, k, p, rng, taken, 3.2)
	# Одиночные деревья
	for i in 26:
		var p := _random_ring(rng, 14.0, 68.0)
		_try_tree(parent, kits, _pick_kind(rng, p.length()), p, rng, taken, 4.0)
	# Опушка за краем игровой зоны, чтобы мир не обрывался
	var placed := 0
	for i in 400:
		if placed >= 70:
			break
		var p := Vector3(rng.randf_range(-90, 90), 0, rng.randf_range(-90, 90))
		if maxf(absf(p.x), absf(p.z)) < 74.0:
			continue
		var kind := KIND_PINE if rng.randf() < 0.6 else KIND_ROUND
		if _try_tree(parent, kits, kind, p, rng, taken, 3.4):
			placed += 1


# --- Кусты и камни ---

static func _make_bush(rng: RandomNumberGenerator) -> ArrayMesh:
	var acc := MeshAcc.new()
	var top := Color(0.50, 0.77, 0.32)
	var bot := Color(0.17, 0.43, 0.28)
	var blobs: Array = []
	for k in rng.randi_range(2, 4):
		var r := rng.randf_range(0.42, 0.66)
		var c := Vector3(0, r * 0.6, 0)
		if k > 0:
			c = Vector3(rng.randf_range(-0.45, 0.45), r * 0.55, rng.randf_range(-0.45, 0.45))
		blobs.append([c, r])
		_sphere(acc, Transform3D(Basis.from_scale(Vector3(r, r * 0.8, r)), c), 10, 6, bot, top, 0.0, 1.1)
	if rng.randf() < 0.6:
		var dots := [Color(0.98, 0.97, 0.94), Color(1.0, 0.58, 0.74), Color(1.0, 0.84, 0.3)]
		var fc: Color = dots[rng.randi() % dots.size()]
		for k in rng.randi_range(4, 8):
			var blob: Array = blobs[rng.randi() % blobs.size()]
			var c: Vector3 = blob[0]
			var r: float = blob[1]
			var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.3, 1.0), rng.randf_range(-1, 1)).normalized()
			var p := c + Vector3(dir.x * r, dir.y * r * 0.8, dir.z * r) * 0.97
			_sphere(acc, Transform3D(Basis.from_scale(Vector3.ONE * 0.075), p), 6, 4, fc, fc, 0.0, 1.0)
	return acc.to_mesh()


static func _make_rock(rng: RandomNumberGenerator, mossy: bool) -> ArrayMesh:
	var acc := MeshAcc.new()
	var seg := 7
	var rings := 4
	var sc := Vector3(rng.randf_range(0.9, 1.3), rng.randf_range(0.55, 0.85), rng.randf_range(0.8, 1.1))
	var stone := Color(0.60, 0.61, 0.64)
	var moss := Color(0.44, 0.62, 0.30)
	var rows: Array = []
	for j in rings + 1:
		var phi := PI * float(j) / float(rings)
		var row := PackedVector3Array()
		var pole_k := rng.randf_range(0.85, 1.1)
		for i in seg:
			var th := TAU * float(i) / float(seg) + (0.25 if j % 2 == 1 else 0.0)
			var k := pole_k if (j == 0 or j == rings) else rng.randf_range(0.82, 1.12)
			var p := Vector3(sin(phi) * cos(th) * sc.x * k, cos(phi) * sc.y * k, sin(phi) * sin(th) * sc.z * k)
			p.y = maxf(p.y, -0.15)
			row.append(p)
		rows.append(row)
	for j in rings:
		var ra: PackedVector3Array = rows[j]
		var rb: PackedVector3Array = rows[j + 1]
		for i in seg:
			var i2 := (i + 1) % seg
			var tris: Array = []
			if j > 0:
				tris.append([ra[i], rb[i], ra[i2]])
			if j < rings - 1:
				tris.append([ra[i2], rb[i], rb[i2]])
			for t in tris:
				var p0: Vector3 = t[0]
				var p1: Vector3 = t[1]
				var p2: Vector3 = t[2]
				var n := (p2 - p0).cross(p1 - p0).normalized()
				var c := _shade(stone, rng.randf_range(0.9, 1.05))
				if mossy and n.y > 0.55:
					c = _shade(moss, rng.randf_range(0.92, 1.05))
				elif n.y < -0.2:
					c = _shade(stone, 0.75)
				_flat_tri(acc, p0, p1, p2, c)
	return acc.to_mesh()


static func _add_decor(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, s: float,
		rng: RandomNumberGenerator) -> void:
	var mi := _mesh_node(parent, mesh, mat, pos)
	mi.rotation.y = rng.randf() * TAU
	mi.scale = Vector3.ONE * s


static func _build_bushes_and_rocks(root: Node3D, rng: RandomNumberGenerator, taken: Array[Vector3]) -> void:
	var parent := Node3D.new()
	parent.name = "Decor"
	root.add_child(parent)
	var bushes: Array[ArrayMesh] = []
	for i in 4:
		bushes.append(_make_bush(rng))
	var bush_mat := _vc_mat(Color.WHITE, Color(0.32, 0.6, 0.3))
	var rocks: Array[ArrayMesh] = []
	for i in 5:
		rocks.append(_make_rock(rng, i >= 2))
	var rock_mat := _vc_mat(Color.WHITE, Color(0.55, 0.56, 0.6))
	var plaza := MobData.SAFE_RADIUS
	var hw := PATH_WIDTH * 0.5

	# Кусты кольцом вокруг площадки (между тропинками)
	for k in 14:
		var ang := TAU * float(k) / 14.0 + rng.randf_range(-0.12, 0.12)
		var p := Vector3(cos(ang), 0, sin(ang)) * rng.randf_range(plaza + 2.8, plaza + 4.2)
		if path_distance(p.x, p.z) < hw + 1.3:
			continue
		_add_decor(parent, bushes[rng.randi() % bushes.size()], bush_mat, p, rng.randf_range(0.8, 1.15), rng)
	# Кусты у деревьев и по полю
	var spots: Array[Vector3] = []
	for t in taken:
		if rng.randf() < 0.3:
			var a := rng.randf() * TAU
			spots.append(t + Vector3(cos(a), 0, sin(a)) * rng.randf_range(1.5, 2.6))
	for k in 36:
		spots.append(_random_ring(rng, plaza + 5.0, 84.0))
	for p in spots:
		if Vector2(p.x, p.z).length() < plaza + 2.5 or path_distance(p.x, p.z) < hw + 1.0:
			continue
		_add_decor(parent, bushes[rng.randi() % bushes.size()], bush_mat, p, rng.randf_range(0.75, 1.3), rng)

	# Камни вдоль тропинок
	for k in 40:
		var i := rng.randi() % PATH_ANGLES.size()
		var r := rng.randf_range(plaza + 3.0, 84.0)
		var base: float = PATH_ANGLES[i]
		var target := base + PATH_WOBBLE * sin(r * 0.06 + float(i) * 1.7)
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var a := target + side * (hw + rng.randf_range(0.6, 1.6)) / r
		var p := Vector3(cos(a) * r, -0.05, sin(a) * r)
		_add_decor(parent, rocks[rng.randi() % rocks.size()], rock_mat, p, rng.randf_range(0.35, 0.7), rng)
		if rng.randf() < 0.4:
			var q := p + Vector3(rng.randf_range(-0.9, 0.9), 0, rng.randf_range(-0.9, 0.9))
			_add_decor(parent, rocks[rng.randi() % rocks.size()], rock_mat, q, rng.randf_range(0.2, 0.35), rng)
	# Камни по полю; крупные валуны — только на опушке за краем карты
	for k in 30:
		var p := _random_ring(rng, plaza + 4.0, 80.0)
		p.y = -0.05
		if path_distance(p.x, p.z) < hw + 0.5:
			continue
		var big := maxf(absf(p.x), absf(p.z)) > PLAY_HALF + 3.0
		var s := rng.randf_range(1.2, 2.0) if big else rng.randf_range(0.35, 0.9)
		_add_decor(parent, rocks[rng.randi() % rocks.size()], rock_mat, p, s, rng)


# --- Трава и цветы (MultiMesh по участкам CHUNK×CHUNK: невидимые участки отсекаются) ---

## Пучок из 6 травинок, высота 1 (масштабируется экземпляром). UV.y — высота точки.
static func _grass_mesh(rng: RandomNumberGenerator) -> ArrayMesh:
	var acc := MeshAcc.new()
	var up := Vector3.UP
	var w := Color.WHITE
	for b in 6:
		var ang := TAU * float(b) / 6.0 + rng.randf_range(-0.4, 0.4)
		var out := Vector3(cos(ang), 0, sin(ang))
		var root_p := out * rng.randf_range(0.0, 0.14)
		var face := rng.randf() * TAU
		var side := Vector3(cos(face), 0, sin(face)) * rng.randf_range(0.04, 0.055)
		var h := rng.randf_range(0.6, 1.0)
		var lean := out * rng.randf_range(0.08, 0.28)
		var mid := root_p + lean * 0.35 + Vector3(0, h * 0.5, 0)
		var tip := root_p + lean + Vector3(0, h, 0)
		var i0 := acc.add(root_p - side, up, w, Vector2(0, 0))
		var i1 := acc.add(root_p + side, up, w, Vector2(1, 0))
		var i2 := acc.add(mid - side * 0.7, up, w, Vector2(0, h * 0.5))
		var i3 := acc.add(mid + side * 0.7, up, w, Vector2(1, h * 0.5))
		var i4 := acc.add(tip, up, w, Vector2(0.5, h))
		acc.tri(i0, i2, i1)
		acc.tri(i1, i2, i3)
		acc.tri(i2, i4, i3)
	return acc.to_mesh()


## Цветок высотой 1: стебель и головка из 5 округлых лепестков (UV.x = 1 — цвет экземпляра).
static func _flower_mesh() -> ArrayMesh:
	var acc := MeshAcc.new()
	var up := Vector3.UP
	var stem := Color(0.22, 0.5, 0.2).srgb_to_linear()
	for k in 2:
		var side := Vector3(0.012, 0, 0) if k == 0 else Vector3(0, 0, 0.012)
		var a := acc.add(-side, up, stem, Vector2(0, 0))
		var b := acc.add(side, up, stem, Vector2(0, 0))
		var c := acc.add(Vector3(0, 1.0, 0) - side * 0.6, up, stem, Vector2(0, 1))
		var d := acc.add(Vector3(0, 1.0, 0) + side * 0.6, up, stem, Vector2(0, 1))
		acc.tri(a, c, b)
		acc.tri(b, c, d)
	var center := acc.add(Vector3(0, 0.99, 0), up, Color.WHITE, Vector2(1, 1))
	var ring := acc.verts.size()
	var radii := [0.045, 0.115, 0.135, 0.115]
	for k in 20:
		var ang := TAU * float(k) / 20.0
		var rad: float = radii[k % 4]
		var y := 1.0 + rad * 0.2
		acc.add(Vector3(cos(ang) * rad, y, sin(ang) * rad), up, Color.WHITE, Vector2(1, 1))
	for k in 20:
		acc.tri(center, ring + k, ring + (k + 1) % 20)
	var yc := Color(1.0, 0.78, 0.2).srgb_to_linear()
	var c2 := acc.add(Vector3(0, 1.03, 0), up, yc, Vector2(0, 1))
	var ring2 := acc.verts.size()
	for k in 6:
		var ang := TAU * float(k) / 6.0
		acc.add(Vector3(cos(ang) * 0.035, 1.025, sin(ang) * 0.035), up, yc, Vector2(0, 1))
	for k in 6:
		acc.tri(c2, ring2 + k, ring2 + (k + 1) % 6)
	return acc.to_mesh()


static func _chunk_add(chunks: Dictionary, xf: Transform3D, custom: Color) -> void:
	var key := Vector2i(floori(xf.origin.x / CHUNK), floori(xf.origin.z / CHUNK))
	if not chunks.has(key):
		chunks[key] = [[], []]
	var e: Array = chunks[key]
	(e[0] as Array).append(xf)
	(e[1] as Array).append(custom)


static func _chunks_to_nodes(parent: Node3D, chunks: Dictionary, mesh: Mesh, mat: Material) -> int:
	var total := 0
	for key in chunks:
		var e: Array = chunks[key]
		var xs: Array = e[0]
		var cs: Array = e[1]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = xs.size()
		for i in xs.size():
			mm.set_instance_transform(i, xs[i])
			mm.set_instance_custom_data(i, cs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mmi)
		total += xs.size()
	return total


static func _build_grass(root: Node3D, rng: RandomNumberGenerator, noise: FastNoiseLite) -> void:
	var parent := Node3D.new()
	parent.name = "Grass"
	root.add_child(parent)
	var mat := _shader_mat("res://grass.gdshader")
	mat.set_shader_parameter("wind_dir", WIND_DIR.normalized())
	var chunks := {}
	var n := int(GRASS_HALF * 2.0 / GRASS_STEP)
	var plaza := MobData.SAFE_RADIUS
	var hw := PATH_WIDTH * 0.5
	for iz in n:
		for ix in n:
			var x := -GRASS_HALF + (float(ix) + rng.randf()) * GRASS_STEP
			var z := -GRASS_HALF + (float(iz) + rng.randf()) * GRASS_STEP
			var r := sqrt(x * x + z * z)
			if r < plaza + 0.5:
				continue
			var dens := 0.62 + 0.45 * noise.get_noise_2d(x, z)
			dens *= smoothstep(plaza + 0.5, plaza + 2.5, r)
			var hk := 1.0
			var pd := path_distance(x, z)
			if maxf(absf(x), absf(z)) < 92.0:
				if pd < hw + 0.2:
					dens *= 0.05
					hk = 0.55
				elif pd < hw + 1.3:
					dens *= 0.45
					hk = 0.75
			if rng.randf() > dens:
				continue
			var h := rng.randf_range(0.32, 0.56) * hk * (0.85 + 0.3 * clampf(dens, 0.0, 1.0))
			var w := rng.randf_range(0.85, 1.3)
			var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(w, h, w))
			_chunk_add(chunks, Transform3D(basis, Vector3(x, 0, z)), Color(rng.randf(), rng.randf(), 0, 0))
	_chunks_to_nodes(parent, chunks, _grass_mesh(rng), mat)


static func _build_flowers(root: Node3D, rng: RandomNumberGenerator) -> void:
	var parent := Node3D.new()
	parent.name = "Flowers"
	root.add_child(parent)
	var mat := _shader_mat("res://flower.gdshader")
	mat.set_shader_parameter("wind_dir", WIND_DIR.normalized())
	var palette := [Color(0.98, 0.97, 0.94), Color(1.0, 0.84, 0.24), Color(1.0, 0.56, 0.74), Color(0.50, 0.68, 1.0)]
	var plaza := MobData.SAFE_RADIUS
	var hw := PATH_WIDTH * 0.5
	var clumps: Array = []  # [центр, радиус, число цветов]
	# Клумбы вокруг площадки
	for k in 18:
		var ang := rng.randf() * TAU
		var p := Vector3(cos(ang), 0, sin(ang)) * (plaza + rng.randf_range(1.2, 2.6))
		clumps.append([p, rng.randf_range(0.7, 1.2), rng.randi_range(16, 26)])
	# Куртины по полю
	for k in 150:
		var p := Vector3(rng.randf_range(-82, 82), 0, rng.randf_range(-82, 82))
		if p.length() < plaza + 2.5:
			continue
		clumps.append([p, rng.randf_range(0.6, 1.4), rng.randi_range(10, 22)])
	var chunks := {}
	for cl in clumps:
		var center: Vector3 = cl[0]
		var rad: float = cl[1]
		var cnt: int = cl[2]
		var main: Color = palette[rng.randi() % palette.size()]
		for f in cnt:
			var a := rng.randf() * TAU
			var d := sqrt(rng.randf()) * rad
			var p := center + Vector3(cos(a) * d, 0, sin(a) * d)
			if p.length() < plaza + 0.6 or path_distance(p.x, p.z) < hw + 0.3:
				continue
			var c: Color = palette[0] if rng.randf() < 0.2 else main
			c = c.lerp(Color.WHITE, rng.randf_range(0.0, 0.15)).srgb_to_linear()
			var s := rng.randf_range(0.9, 1.3)
			var h := rng.randf_range(0.22, 0.4)
			var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(s, h, s))
			_chunk_add(chunks, Transform3D(basis, p), Color(c.r, c.g, c.b, rng.randf()))
	_chunks_to_nodes(parent, chunks, _flower_mesh(), mat)


# --- Декор площадки ---

static func _small_body(parent: Node3D, pos: Vector3, radius: float, height: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.add_child(Util.pillar(radius, height))
	parent.add_child(body)
	return body


static func _box(x: float, y: float, z: float) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3(x, y, z)
	return m


static func _cyl(top: float, bottom: float, h: float, seg: int) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	return m


static func _ball(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 10
	m.rings = 6
	return m


static func _add_lantern(parent: Node3D, pos: Vector3, mats: Dictionary) -> void:
	var body := _small_body(parent, pos, 0.2, 3.0)
	_mesh_node(body, _box(0.55, 0.3, 0.55), mats["stone"], Vector3(0, 0.15, 0))
	_mesh_node(body, _cyl(0.07, 0.09, 2.4, 8), mats["wood"], Vector3(0, 1.5, 0))
	_mesh_node(body, _box(0.42, 0.06, 0.42), mats["wood"], Vector3(0, 2.7, 0))
	var glow := _mesh_node(body, _box(0.28, 0.36, 0.28), mats["glow"], Vector3(0, 2.91, 0))
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for x in [-0.17, 0.17]:
		for z in [-0.17, 0.17]:
			_mesh_node(body, _box(0.045, 0.4, 0.045), mats["wood"], Vector3(x, 2.91, z))
	var roof := _mesh_node(body, _cyl(0.02, 0.34, 0.26, 4), mats["roof"], Vector3(0, 3.24, 0))
	roof.rotation.y = PI * 0.25
	_mesh_node(body, _ball(0.06), mats["gold"], Vector3(0, 3.42, 0))


## Флажок на шесте. Полотнище вытянуто по ветру (WIND_DIR).
static func _add_flag(parent: Node3D, pos: Vector3, mats: Dictionary, main: Color, stripe: Color, phase: float) -> void:
	var body := _small_body(parent, pos, 0.12, 4.4)
	_mesh_node(body, _box(0.5, 0.25, 0.5), mats["stone"], Vector3(0, 0.125, 0))
	_mesh_node(body, _cyl(0.045, 0.06, 4.4, 8), mats["pole"], Vector3(0, 2.3, 0))
	_mesh_node(body, _ball(0.1), mats["gold"], Vector3(0, 4.56, 0))

	var acc := MeshAcc.new()
	var segs := 10
	for s in segs + 1:
		var u := float(s) / float(segs)
		var x := u * 1.7
		var hh := lerpf(0.42, 0.06, u)
		var cy := -0.42 - u * 0.12
		acc.add(Vector3(x, cy + hh, 0), Vector3.BACK, Color.WHITE, Vector2(u, 0))
		acc.add(Vector3(x, cy - hh, 0), Vector3.BACK, Color.WHITE, Vector2(u, 1))
	for s in segs:
		var t0 := s * 2
		acc.tri(t0, t0 + 2, t0 + 1)
		acc.tri(t0 + 2, t0 + 3, t0 + 1)
	var fm := _shader_mat("res://flag.gdshader")
	fm.set_shader_parameter("main_color", main)
	fm.set_shader_parameter("stripe_color", stripe)
	fm.set_shader_parameter("phase", phase)
	var cloth := _mesh_node(body, acc.to_mesh(), fm, Vector3(0.05, 4.35, 0))
	cloth.set_meta("no_outline", true)
	# Локальная +X смотрит по ветру
	cloth.rotation.y = -atan2(WIND_DIR.y, WIND_DIR.x)


static func _build_plaza_decor(root: Node3D) -> void:
	var parent := Node3D.new()
	parent.name = "PlazaDecor"
	root.add_child(parent)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.86, 0.5)
	var mats := {
		"stone": Util.mat(Color(0.66, 0.66, 0.7)),
		"wood": Util.mat(Color(0.38, 0.25, 0.17)),
		"pole": Util.mat(Color(0.82, 0.74, 0.6)),
		"roof": Util.mat(Color(0.62, 0.24, 0.2)),
		"gold": Util.mat(Color(0.96, 0.78, 0.32)),
		"glow": glow,
	}
	var r := MobData.SAFE_RADIUS
	for k in 4:
		var ang := PI * 0.25 + float(k) * PI * 0.5
		_add_lantern(parent, Vector3(cos(ang), 0, sin(ang)) * (r - 1.6), mats)
	# Флажки по сторонам северной тропинки, за торговцем
	_add_flag(parent, Vector3(-3.0, 0, -7.6), mats, Color(0.16, 0.66, 0.74), Color(1.0, 0.96, 0.86), 0.0)
	_add_flag(parent, Vector3(3.0, 0, -7.6), mats, Color(0.95, 0.42, 0.38), Color(1.0, 0.86, 0.4), 1.7)


# --- Горизонт: холмы и горы за пределами карты (без коллизий, одним мешем каждый слой) ---

static func _build_horizon(root: Node3D, rng: RandomNumberGenerator) -> void:
	var hills := MeshAcc.new()
	var n := 72
	for k in n:
		var ang := TAU * float(k) / float(n) + rng.randf_range(-0.03, 0.03)
		var d := Vector2(cos(ang), sin(ang))
		var s := rng.randf_range(92.0, 112.0) / maxf(absf(d.x), absf(d.y))
		var pos := Vector3(d.x * s, -0.5, d.y * s)
		var rad := rng.randf_range(12.0, 24.0)
		var h := rng.randf_range(5.0, 13.0)
		var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(rad, h, rad * rng.randf_range(0.7, 1.0)))
		var k2 := rng.randf_range(0.92, 1.05)
		_sphere(hills, Transform3D(basis, pos), 12, 5, _shade(Color(0.30, 0.52, 0.32), k2),
			_shade(Color(0.54, 0.74, 0.40), k2), 0.0, h, true)

	var mountains := MeshAcc.new()
	var heights := [1.0, 0.68, 0.38, 0.0]
	var radii := [0.0, 0.36, 0.68, 1.0]
	var seg := 7
	for k in 26:
		var ang := TAU * float(k) / 26.0 + rng.randf_range(-0.08, 0.08)
		var dist := rng.randf_range(145.0, 175.0)
		var pos := Vector3(cos(ang) * dist, -1.0, sin(ang) * dist)
		var rad := rng.randf_range(22.0, 36.0)
		var h := rng.randf_range(32.0, 58.0)
		var rot := rng.randf() * TAU
		var rows: Array = []
		for j in heights.size():
			var row := PackedVector3Array()
			for i in seg:
				var th := rot + TAU * float(i) / float(seg)
				var rr: float = radii[j] * rng.randf_range(0.85, 1.12)
				var hy: float = heights[j]
				if j > 0 and j < heights.size() - 1:
					hy *= rng.randf_range(0.92, 1.08)
				row.append(pos + Vector3(cos(th) * rr * rad, hy * h, sin(th) * rr * rad))
			rows.append(row)
		for j in heights.size() - 1:
			var ra: PackedVector3Array = rows[j]
			var rb: PackedVector3Array = rows[j + 1]
			for i in seg:
				var i2 := (i + 1) % seg
				var tris: Array = [[ra[i2], rb[i], rb[i2]]]
				if j > 0:
					tris.append([ra[i], rb[i], ra[i2]])
				for t in tris:
					var p0: Vector3 = t[0]
					var p1: Vector3 = t[1]
					var p2: Vector3 = t[2]
					var cy := ((p0.y + p1.y + p2.y) / 3.0 - pos.y) / h
					var c := _shade(Color(0.40, 0.55, 0.46), rng.randf_range(0.92, 1.05))
					if cy > 0.6:
						c = Color(0.95, 0.97, 1.0)
					elif cy > 0.3:
						c = _shade(Color(0.56, 0.62, 0.74), rng.randf_range(0.92, 1.05))
					_flat_tri(mountains, p0, p1, p2, c)

	for acc in [hills, mountains]:
		var mi := MeshInstance3D.new()
		mi.mesh = (acc as MeshAcc).to_mesh()
		mi.material_override = _vc_mat(Color.WHITE, Color.WHITE, false)
		mi.set_meta("no_outline", true)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
