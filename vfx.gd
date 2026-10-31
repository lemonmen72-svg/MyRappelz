class_name Vfx
extends RefCounted
## Эффекты в аниме-стиле: звёздочки-вспышки, кольца, искры, облачка, сердечки, столбы света.
## Только примитивы, свои текстуры (рисуются кодом) и CPUParticles3D (рендерер GL Compatibility).
## Каждый эффект — узел Node3D в группе "vfx", он сам удаляется через 1–2 с.
## Все функции безопасны: если parent не в дереве сцены, ничего не делают и возвращают null.

const GOLD := Color(1.0, 0.84, 0.35)
const HEAL := Color(0.45, 1.0, 0.55)
const TAME := Color(0.35, 1.0, 0.85)
const PINK := Color(1.0, 0.5, 0.72)

static var _textures := {}
static var _meshes := {}
static var _curves := {}


# ---------- Эффекты ----------

## Искра попадания: звёздочка-вспышка, кольцо и разлетающиеся искры.
static func hit_spark(parent: Node, pos: Vector3, color: Color = Color(1.0, 0.9, 0.5), size: float = 1.0) -> Node3D:
	var root := _root(parent, pos, 0.7)
	if root == null:
		return null
	_sprite(root, "star", Color(1, 1, 1, 0.95), 1.1 * size, 0.22)
	_sprite(root, "star", Color(color, 0.85), 1.7 * size, 0.3)
	_sprite(root, "ring", Color(color, 0.8), 1.3 * size, 0.28)
	_particles(root, 8, 0.38, color, 0.22 * size, 5.5 * size,
		{"damping": 7.0, "gravity": Vector3(0, -5, 0)})
	return root


## Дуга удара (аниме-«взмах»): яркий серп проносится через pos по направлению dir.
static func slash_arc(parent: Node, pos: Vector3, dir: Vector3, color: Color = Color.WHITE, size: float = 1.0) -> Node3D:
	var root := _root(parent, pos, 0.6)
	if root == null:
		return null
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length() < 0.01:
		d = Vector3.FORWARD
	d = d.normalized()
	var r := 0.95 * size
	var yaw := atan2(-d.x, -d.z)
	var pivot := Node3D.new()
	root.add_child(pivot)
	pivot.position = -d * r * 0.85
	pivot.rotation = Vector3(0.0, yaw + 0.75, randf_range(-0.45, 0.45))
	var mats: Array[StandardMaterial3D] = []
	for i in 2:
		var mi := MeshInstance3D.new()
		mi.set_meta("no_outline", true)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.mesh = _arc_mesh()
		var c := color.lightened(0.55) if i == 0 else Color(color, 0.75)
		var m := fx_mat(c, null, true)
		m.vertex_color_use_as_albedo = true
		mi.material_override = m
		pivot.add_child(mi)
		mi.scale = Vector3.ONE * r * (1.0 if i == 0 else 1.18)
		mats.append(m)
	var t := pivot.create_tween()
	t.tween_property(pivot, "rotation:y", yaw - 0.75, 0.17).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for m in mats:
		t.parallel().tween_property(m, "albedo_color:a", 0.0, 0.2).set_delay(0.12)
	_sprite(root, "star", Color(1, 1, 1, 0.9), 0.9 * size, 0.2)
	_particles(root, 6, 0.3, color, 0.18 * size, 4.0 * size,
		{"dir": d, "spread": 50.0, "damping": 6.0})
	return root


## Лечение: зелёные звёздочки и крестики поднимаются вверх, кольцо на земле. pos — у ног.
static func heal_sparkles(parent: Node, pos: Vector3, size: float = 1.0) -> Node3D:
	var root := _root(parent, pos, 1.7)
	if root == null:
		return null
	_ground_ring(root, Color(HEAL, 0.8), 1.3 * size, 0.6)
	_sprite(root, "dot", Color(HEAL, 0.55), 1.8 * size, 0.55, true, Vector3(0, 1.0 * size, 0))
	var opts := {"shape": "ring", "radius": 0.55 * size, "dir": Vector3.UP, "spread": 12.0,
		"gravity": Vector3(0, 1.2, 0), "explosive": 0.4, "damping": 0.5, "curve": "twinkle"}
	_particles(root, 12, 1.0, Color(0.8, 1.0, 0.8), 0.2 * size, 2.0 * size, opts)
	opts["tex"] = "plus"
	opts["add"] = false
	_particles(root, 6, 1.1, HEAL, 0.26 * size, 1.6 * size, opts)
	return root


## Новый уровень: золотой столб света, два кольца, спираль звёздочек, большая звезда над головой.
static func level_up(parent: Node, pos: Vector3, size: float = 1.0) -> Node3D:
	var root := _root(parent, pos, 2.1)
	if root == null:
		return null
	_pillar(root, Color(GOLD, 0.45), 0.6 * size, 3.2 * size, 1.0)
	_ground_ring(root, Color(GOLD, 0.9), 2.0 * size, 0.7)
	_ground_ring(root, Color(1, 1, 1, 0.8), 1.4 * size, 0.6, 0.2)
	_spiral(root, 22, GOLD, 0.7 * size, 3.0 * size, 1.3)
	_sprite(root, "star", Color(1.0, 0.95, 0.7, 1.0), 2.0 * size, 0.6, true, Vector3(0, 2.3 * size, 0), 0.25, 0.25)
	return root


## Успешное приручение: сердечки, бирюзовая спираль, кольцо и вспышка.
static func tame_success(parent: Node, pos: Vector3, size: float = 1.0) -> Node3D:
	var root := _root(parent, pos, 2.1)
	if root == null:
		return null
	_ground_ring(root, Color(TAME, 0.9), 2.2 * size, 0.8)
	_spiral(root, 16, TAME, 0.8 * size, 2.6 * size, 1.2)
	_sprite(root, "star", Color(1, 1, 1, 1), 2.2 * size, 0.45, true, Vector3(0, 1.2 * size, 0))
	_particles(root, 9, 1.3, PINK, 0.38 * size, 2.6 * size,
		{"tex": "heart", "add": false, "dir": Vector3.UP, "spread": 55.0, "gravity": Vector3(0, 0.6, 0),
		"damping": 1.5, "radius": 0.4 * size, "curve": "pop"}, Vector3(0, 1.0 * size, 0))
	_sprite(root, "heart", Color(PINK, 0.95), 1.3 * size, 0.9, false, Vector3(0, 2.0 * size, 0), 0.4, 0.3)
	return root


## Эволюция питомца: столб света, вспышка-сфера, радужные кольца и взрыв звёздочек.
static func evolution(parent: Node, pos: Vector3, size: float = 1.0) -> Node3D:
	var root := _root(parent, pos, 2.4)
	if root == null:
		return null
	_pillar(root, Color(1.0, 0.95, 0.75, 0.5), 0.9 * size, 4.0 * size, 1.2)
	_ground_ring(root, Color(GOLD, 0.9), 2.6 * size, 0.8)
	_spiral(root, 26, Color(1.0, 0.9, 0.6), 1.0 * size, 3.5 * size, 1.5)
	_glow_sphere(root, Color(1, 1, 1, 0.55), 1.5 * size, 0.5, Vector3(0, 0.8 * size, 0))
	_ground_ring(root, Color(0.75, 0.55, 1.0, 0.85), 1.9 * size, 0.7, 0.25)
	# Второй такт через 0.45 с: кольцо, большая звезда и разноцветные искры
	_ground_ring(root, Color(0.45, 0.9, 1.0, 0.85), 1.4 * size, 0.6, 0.45)
	_sprite(root, "star", Color(1, 1, 1, 1), 2.8 * size, 0.6, true, Vector3(0, 1.1 * size, 0), 0.25, 0.45)
	var opts := {"damping": 4.0, "gravity": Vector3(0, -2, 0), "curve": "twinkle"}
	var colors: Array[Color] = [GOLD, Color(1.0, 0.55, 0.8), Color(0.5, 0.9, 1.0)]
	for c in colors:
		_particles(root, 7, 0.8, c, 0.3 * size, 5.0 * size, opts, Vector3(0, 1.0 * size, 0), 0.45)
	return root


## Подбор добычи: золотые звёздочки фонтаном и маленькое кольцо.
static func pickup(parent: Node, pos: Vector3) -> Node3D:
	var root := _root(parent, pos, 1.0)
	if root == null:
		return null
	_sprite(root, "ring", Color(GOLD, 0.9), 1.0, 0.3)
	_sprite(root, "star", Color(1, 1, 0.85, 1), 0.9, 0.25)
	_particles(root, 10, 0.65, GOLD, 0.2, 3.5,
		{"dir": Vector3.UP, "spread": 35.0, "gravity": Vector3(0, -6, 0), "curve": "twinkle"})
	return root


## Магический взрыв радиусом radius: светящаяся сфера, кольцо на земле, искры наружу.
static func magic_burst(parent: Node, pos: Vector3, color: Color, radius: float = 1.5, time: float = 0.4) -> Node3D:
	var root := _root(parent, pos, time + 0.8)
	if root == null:
		return null
	radius = maxf(radius, 0.3)
	_glow_sphere(root, Color(color, 0.45), radius, time)
	_sprite(root, "star", Color(color.lightened(0.6), 0.95), minf(radius * 1.3, 3.0), time * 0.8)
	_ground_ring(root, Color(color, 0.85), radius * 1.1, time + 0.15)
	_particles(root, 12, 0.5, color, 0.25, radius * 4.5,
		{"damping": 5.0, "radius": radius * 0.2, "curve": "twinkle"})
	return root


## Смерть зверя: облачко «пуф» и звёздочки.
static func death_puff(parent: Node, pos: Vector3, size: float = 1.0) -> Node3D:
	var root := _root(parent, pos, 1.3)
	if root == null:
		return null
	_particles(root, 9, 0.75, Color(1, 1, 1, 0.95), 0.75 * size, 1.8 * size,
		{"tex": "puff", "add": false, "curve": "grow", "damping": 3.0, "gravity": Vector3(0, 0.8, 0),
		"radius": 0.35 * size, "explosive": 1.0})
	_particles(root, 6, 0.85, Color(1.0, 0.92, 0.4), 0.32 * size, 3.8 * size,
		{"dir": Vector3.UP, "spread": 60.0, "gravity": Vector3(0, -7, 0), "curve": "twinkle"})
	_sprite(root, "ring", Color(1, 1, 1, 0.8), 2.0 * size, 0.35)
	return root


## Постоянные искорки вокруг узла (питомец старших стадий). Возвращает частицы (не удаляются сами).
static func ambient_sparkles(parent: Node3D, color: Color, radius: float, amount: int = 6) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	# Число частиц — по настройке «Качество эффектов»
	p.amount = Quality.particles(amount)
	p.lifetime = 1.3
	p.explosiveness = 0.0
	p.randomness = 0.5
	p.mesh = _quad()
	p.material_override = _particle_mat("star", true)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.6
	p.gravity = Vector3(0, 0.3, 0)
	p.scale_amount_min = 0.1
	p.scale_amount_max = 0.18
	p.scale_amount_curve = _curve("twinkle")
	p.color_ramp = _ramp(color)
	parent.add_child(p)
	p.emitting = true
	return p


# ---------- Текстуры, меши, материалы (общие и для моделей) ----------

## Своя текстура, нарисованная кодом: "star" (4-лучевая звёздочка), "dot" (мягкое пятно),
## "ring" (кольцо), "heart" (сердечко), "plus" (крестик лечения), "puff" (облачко).
static func tex(kind: String) -> Texture2D:
	if _textures.has(kind):
		return _textures[kind]
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (float(x) + 0.5) / float(n) * 2.0 - 1.0
			var v := (float(y) + 0.5) / float(n) * 2.0 - 1.0
			img.set_pixel(x, y, Color(1, 1, 1, _tex_alpha(kind, u, v)))
	var t := ImageTexture.create_from_image(img)
	_textures[kind] = t
	return t


static func _tex_alpha(kind: String, u: float, v: float) -> float:
	var d := sqrt(u * u + v * v)
	match kind:
		"star":
			var s := sqrt(absf(u)) + sqrt(absf(v))
			var a := clampf((1.0 - s) * 3.2, 0.0, 1.0)
			var core := clampf(1.0 - d * 2.6, 0.0, 1.0)
			var halo := pow(clampf(1.0 - d, 0.0, 1.0), 3.0) * 0.35
			return maxf(maxf(a, core), halo)
		"dot":
			var k := clampf(1.0 - d, 0.0, 1.0)
			return k * k
		"ring":
			var edge := clampf(1.0 - absf(d - 0.82) / 0.13, 0.0, 1.0)
			var inner := clampf((d - 0.3) / 0.55, 0.0, 1.0) * 0.22 if d < 0.82 else 0.0
			return maxf(edge * edge * (3.0 - 2.0 * edge), inner)
		"heart":
			var x := u * 1.25
			var y := -v * 1.25 + 0.25
			var f := pow(x * x + y * y - 1.0, 3.0) - x * x * y * y * y
			return clampf(-f * 6.0, 0.0, 1.0)
		"plus":
			var w := 0.28
			var bar := maxf(_box_alpha(u, v, w, 0.82), _box_alpha(v, u, w, 0.82))
			return bar
		"puff":
			return clampf((0.92 - d) * 9.0, 0.0, 1.0) * (0.75 + 0.25 * clampf(1.0 - d, 0.0, 1.0))
	return 0.0


## Мягкий прямоугольник |a| < w, |b| < h (для крестика).
static func _box_alpha(a: float, b: float, w: float, h: float) -> float:
	var ka := clampf((w - absf(a)) * 12.0, 0.0, 1.0)
	var kb := clampf((h - absf(b)) * 12.0, 0.0, 1.0)
	return ka * kb


## Материал эффекта: без освещения, прозрачный, без контура. add: сложение цветов (свечение).
static func fx_mat(c: Color, texture: Texture2D = null, add: bool = true,
		billboard: BaseMaterial3D.BillboardMode = BaseMaterial3D.BILLBOARD_DISABLED) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = c
	m.disable_receive_shadows = true
	if texture != null:
		m.albedo_texture = texture
	m.billboard_mode = billboard
	if billboard != BaseMaterial3D.BILLBOARD_DISABLED:
		m.billboard_keep_scale = true
	return m


static func _particle_mat(kind: String, add: bool) -> StandardMaterial3D:
	var key := "pm|%s|%s" % [kind, add]
	if _meshes.has(key):
		return _meshes[key]
	var m := fx_mat(Color.WHITE, tex(kind), add, BaseMaterial3D.BILLBOARD_PARTICLES)
	m.vertex_color_use_as_albedo = true
	_meshes[key] = m
	return m


static func _quad() -> QuadMesh:
	if _meshes.has("quad"):
		return _meshes["quad"]
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	_meshes["quad"] = q
	return q


static func _plane() -> PlaneMesh:
	if _meshes.has("plane"):
		return _meshes["plane"]
	var p := PlaneMesh.new()
	p.size = Vector2(2, 2)
	_meshes["plane"] = p
	return p


static func _unit_sphere() -> SphereMesh:
	if _meshes.has("sphere"):
		return _meshes["sphere"]
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 20
	s.rings = 10
	_meshes["sphere"] = s
	return s


static func _tube() -> CylinderMesh:
	if _meshes.has("tube"):
		return _meshes["tube"]
	var c := CylinderMesh.new()
	c.top_radius = 1.0
	c.bottom_radius = 1.0
	c.height = 1.0
	c.radial_segments = 20
	c.rings = 1
	c.cap_top = false
	c.cap_bottom = false
	_meshes["tube"] = c
	return c


## Серп-дуга в плоскости XZ радиусом 1 вокруг -Z; концы тонкие, хвост прозрачный (цвета вершин).
static func _arc_mesh() -> ArrayMesh:
	if _meshes.has("arc"):
		return _meshes["arc"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 18
	var a_from := -1.25
	var a_to := 1.25
	for i in n:
		var k0 := float(i) / float(n)
		var k1 := float(i + 1) / float(n)
		var a0 := lerpf(a_from, a_to, k0)
		var a1 := lerpf(a_from, a_to, k1)
		var w0 := sin(PI * k0) * 0.32
		var w1 := sin(PI * k1) * 0.32
		var o0 := Vector3(sin(a0), 0.0, -cos(a0))
		var o1 := Vector3(sin(a1), 0.0, -cos(a1))
		# Передний край (k → 0) яркий, хвост (k → 1) тает
		var c0 := Color(1, 1, 1, 1.0 - k0 * 0.85)
		var c1 := Color(1, 1, 1, 1.0 - k1 * 0.85)
		var p0o := o0
		var p0i := o0 * (1.0 - w0)
		var p1o := o1
		var p1i := o1 * (1.0 - w1)
		st.set_color(c0)
		st.add_vertex(p0o)
		st.set_color(c1)
		st.add_vertex(p1o)
		st.set_color(c0)
		st.add_vertex(p0i)
		st.set_color(c1)
		st.add_vertex(p1o)
		st.set_color(c1)
		st.add_vertex(p1i)
		st.set_color(c0)
		st.add_vertex(p0i)
	var mesh := st.commit()
	_meshes["arc"] = mesh
	return mesh


## Кривые масштаба частиц: "shrink" (тают), "grow" (растут), "twinkle" (вспыхивают и гаснут), "pop".
static func _curve(kind: String) -> Curve:
	if _curves.has(kind):
		return _curves[kind]
	var c := Curve.new()
	match kind:
		"grow":
			c.add_point(Vector2(0.0, 0.45))
			c.add_point(Vector2(1.0, 1.0))
		"twinkle":
			c.add_point(Vector2(0.0, 0.2))
			c.add_point(Vector2(0.2, 1.0))
			c.add_point(Vector2(1.0, 0.0))
		"pop":
			c.add_point(Vector2(0.0, 0.0))
			c.add_point(Vector2(0.15, 1.0))
			c.add_point(Vector2(0.8, 0.9))
			c.add_point(Vector2(1.0, 0.0))
		_:
			c.add_point(Vector2(0.0, 1.0))
			c.add_point(Vector2(1.0, 0.0))
	_curves[kind] = c
	return c


static func _ramp(c: Color) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.65, 1.0])
	g.colors = PackedColorArray([Color(c.lightened(0.4), c.a), c, Color(c, 0.0)])
	return g


# ---------- Строительные блоки ----------

## Корневой узел эффекта в точке pos, удаляется через life секунд.
static func _root(parent: Node, pos: Vector3, life: float) -> Node3D:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	var r := Node3D.new()
	r.name = "Vfx"
	r.add_to_group("vfx")
	parent.add_child(r)
	r.global_position = pos
	var t := r.create_tween()
	t.tween_interval(life)
	t.tween_callback(r.queue_free)
	return r


## Картинка-вспышка, всегда повёрнутая к камере: выпрыгивает (масштаб) и тает. delay: появится позже.
static func _sprite(root: Node3D, kind: String, c: Color, size: float, time: float, add: bool = true,
		offset: Vector3 = Vector3.ZERO, start: float = 0.25, delay: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.set_meta("no_outline", true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.mesh = _quad()
	var m := fx_mat(c, tex(kind), add, BaseMaterial3D.BILLBOARD_ENABLED)
	mi.material_override = m
	root.add_child(mi)
	mi.position = offset
	mi.scale = Vector3.ONE * size * start
	var t := mi.create_tween().set_parallel(true)
	if delay > 0.0:
		mi.visible = false
		t.tween_callback(mi.show).set_delay(delay)
	t.tween_property(mi, "scale", Vector3.ONE * size, time * 0.6).set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT).set_delay(delay)
	t.tween_property(m, "albedo_color:a", 0.0, time * 0.6).set_delay(delay + time * 0.4)
	return mi


## Расходящееся кольцо на земле (y = 0) под эффектом. delay: появится позже.
static func _ground_ring(root: Node3D, c: Color, radius: float, time: float, delay: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.set_meta("no_outline", true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.mesh = _plane()
	var m := fx_mat(c, tex("ring"), false)
	mi.material_override = m
	root.add_child(mi)
	var gp := root.global_position
	mi.global_position = Vector3(gp.x, 0.07, gp.z)
	mi.scale = Vector3.ONE * radius * 0.15
	var t := mi.create_tween().set_parallel(true)
	if delay > 0.0:
		mi.visible = false
		t.tween_callback(mi.show).set_delay(delay)
	t.tween_property(mi, "scale", Vector3.ONE * radius, time).set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT).set_delay(delay)
	t.tween_property(m, "albedo_color:a", 0.0, time * 0.55).set_delay(delay + time * 0.45)
	return mi


## Расширяющаяся и тающая сфера.
static func _glow_sphere(root: Node3D, c: Color, radius: float, time: float, offset: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.set_meta("no_outline", true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.mesh = _unit_sphere()
	var m := fx_mat(c, null, false)
	mi.material_override = m
	root.add_child(mi)
	mi.position = offset
	mi.scale = Vector3.ONE * radius * 0.2
	var t := mi.create_tween().set_parallel(true)
	t.tween_property(mi, "scale", Vector3.ONE * radius, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(m, "albedo_color:a", 0.0, time)
	return mi


## Столб света от земли вверх: вырастает, затем сужается и гаснет.
static func _pillar(root: Node3D, c: Color, radius: float, height: float, time: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.set_meta("no_outline", true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.mesh = _tube()
	var m := fx_mat(c, null, true)
	mi.material_override = m
	root.add_child(mi)
	mi.scale = Vector3(radius, 0.01, radius)
	var t := mi.create_tween().set_parallel(true)
	t.tween_property(mi, "scale:y", height, time * 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(mi, "position:y", height * 0.5, time * 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(mi, "scale:x", radius * 0.15, time * 0.6).set_delay(time * 0.4)
	t.tween_property(mi, "scale:z", radius * 0.15, time * 0.6).set_delay(time * 0.4)
	t.tween_property(m, "albedo_color:a", 0.0, time * 0.6).set_delay(time * 0.4)
	return mi


## Звёздочки, поднимающиеся спиралью (вращается узел, частицы в его координатах).
static func _spiral(root: Node3D, amount: int, c: Color, radius: float, height: float, time: float) -> void:
	var pivot := Node3D.new()
	root.add_child(pivot)
	_particles(pivot, amount, time * 0.8, c, 0.24, height / maxf(time * 0.8, 0.1),
		{"shape": "ring", "radius": radius, "dir": Vector3.UP, "spread": 5.0, "explosive": 0.55,
		"local": true, "curve": "twinkle"})
	var t := pivot.create_tween()
	t.tween_property(pivot, "rotation:y", TAU * 1.5, time)


## Вспышка частиц. opts: tex, add, dir, spread, gravity, damping, radius, shape ("sphere"|"ring"),
## explosive, local, curve. delay: вспышка начнётся позже.
static func _particles(root: Node3D, amount: int, life: float, c: Color, size: float, speed: float,
		opts: Dictionary = {}, offset: Vector3 = Vector3.ZERO, delay: float = 0.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	# Число частиц — по настройке «Качество эффектов»
	p.amount = Quality.particles(amount)
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = float(opts.get("explosive", 0.95))
	p.randomness = 0.3
	p.local_coords = bool(opts.get("local", false))
	p.mesh = _quad()
	p.material_override = _particle_mat(String(opts.get("tex", "star")), bool(opts.get("add", true)))
	var dir: Vector3 = opts.get("dir", Vector3.UP)
	p.direction = dir
	p.spread = float(opts.get("spread", 180.0))
	p.initial_velocity_min = speed * 0.55
	p.initial_velocity_max = speed
	var g: Vector3 = opts.get("gravity", Vector3.ZERO)
	p.gravity = g
	var damp := float(opts.get("damping", 0.0))
	p.damping_min = damp * 0.8
	p.damping_max = damp
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.scale_amount_min = size * 0.65
	p.scale_amount_max = size
	p.scale_amount_curve = _curve(String(opts.get("curve", "shrink")))
	p.color_ramp = _ramp(c)
	if String(opts.get("shape", "sphere")) == "ring":
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		p.emission_ring_axis = Vector3.UP
		p.emission_ring_height = 0.05
		p.emission_ring_radius = float(opts.get("radius", 0.5))
		p.emission_ring_inner_radius = float(opts.get("radius", 0.5)) * 0.8
	else:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = float(opts.get("radius", 0.12))
	root.add_child(p)
	p.position = offset
	if delay > 0.0:
		p.emitting = false
		var t := p.create_tween()
		t.tween_interval(delay)
		t.tween_callback(p.restart)
	else:
		p.emitting = true
	return p
