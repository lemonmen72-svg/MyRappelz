class_name VfxKit
extends RefCounted
## Слои генератора эффектов (docs/vfx/VFX_ARCHITECTURE.md): текстуры, рисуемые кодом, меши и строительные блоки,
## из которых VfxArchetypes собирают эффекты. Всё — штатный Godot 4.3, одинаково в Mobile (Vulkan) и Compatibility:
## CPUParticles3D, MeshInstance3D с материалом без освещения (Vfx.fx_mat), твины. Эффект — узел Node3D в группе "vfx"
## (Vfx._root), он удаляет себя сам. Число частиц — уже с учётом качества (передаёт сборщик).

static var _tex := {}
static var _mesh := {}
static var _pmat := {}
## Сколько кратких огней (OmniLight3D) эффектов сейчас горит — не больше MAX_LIGHTS.
static var lights_alive := 0
const MAX_LIGHTS := 3


# ---------- Текстуры ----------

## Текстура слоя: "soft" (мягкое пятно), "flame" (язык пламени), "smoke" (клуб дыма), "sigil" (знак секты: глаз и
## щупальца-спирали), "rune" (магический круг каста), "claw" (три следа когтей), "streak" (полоса-росчерк),
## "drop" (капля), "snow" (снежинка), "crack" (трещины в земле), "wave" (широкое мягкое кольцо),
## "shard" (осколок-ромб), "swirl" (вихрь-спираль). Остальные — Vfx.tex (star, dot, ring, plus, puff, heart).
static func tex(kind: String) -> Texture2D:
	if _tex.has(kind):
		return _tex[kind]
	var n := 128 if kind in ["sigil", "rune", "crack", "swirl", "claw"] else 64
	if not kind in ["soft", "flame", "smoke", "sigil", "rune", "claw", "streak", "drop", "snow", "crack", "wave",
			"shard", "swirl"]:
		return Vfx.tex(kind)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (float(x) + 0.5) / float(n) * 2.0 - 1.0
			var v := (float(y) + 0.5) / float(n) * 2.0 - 1.0
			img.set_pixel(x, y, Color(1, 1, 1, clampf(_alpha(kind, u, v), 0.0, 1.0)))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex[kind] = t
	return t


static func _alpha(kind: String, u: float, v: float) -> float:
	var d := sqrt(u * u + v * v)
	var ang := atan2(v, u)
	match kind:
		"soft":
			var k := clampf(1.0 - d, 0.0, 1.0)
			return k * k * (3.0 - 2.0 * k)
		"flame":
			# Капля острием вверх (v < 0 — верх картинки): широкое основание, острый язык
			var yy := (v + 1.0) * 0.5
			var w := 0.15 + 0.75 * pow(yy, 0.8)
			var side := clampf(1.0 - absf(u) / maxf(w, 0.05), 0.0, 1.0)
			var bottom := clampf((1.0 - v) * 2.5, 0.0, 1.0)
			return pow(side, 1.4) * bottom * (0.55 + 0.45 * yy)
		"smoke":
			var nn := _noise(u * 2.6, v * 2.6, 7) * 0.5 + _noise(u * 5.2, v * 5.2, 13) * 0.25
			var k2 := clampf(1.0 - d * (1.0 + nn * 0.6), 0.0, 1.0)
			return k2 * k2 * 0.9
		"sigil":
			# Внешнее кольцо, внутреннее кольцо, глаз в центре, шесть щупалец-спиралей между кольцами
			var a := 0.0
			a = maxf(a, _band(d, 0.92, 0.035))
			a = maxf(a, _band(d, 0.62, 0.02) * 0.8)
			var lid := _eye(u, v)
			a = maxf(a, lid)
			for i in 6:
				var base := TAU * float(i) / 6.0
				# Спираль: радиус растёт с углом от 0.32 до 0.88
				for s in 9:
					var t := float(s) / 8.0
					var r := 0.34 + 0.52 * t
					var aa := base + t * 1.6
					var px := cos(aa) * r
					var py := sin(aa) * r
					var dd := sqrt((u - px) * (u - px) + (v - py) * (v - py))
					a = maxf(a, clampf(1.0 - dd / (0.05 - 0.025 * t), 0.0, 1.0))
			return a
		"rune":
			var a2 := maxf(_band(d, 0.9, 0.03), _band(d, 0.72, 0.018) * 0.9)
			a2 = maxf(a2, _band(d, 0.3, 0.02) * 0.7)
			# Насечки между кольцами и треугольник-звезда внутри
			var tick := clampf(1.0 - absf(fposmod(ang * 12.0 / TAU, 1.0) - 0.5) * 9.0, 0.0, 1.0)
			if d > 0.73 and d < 0.89:
				a2 = maxf(a2, tick * 0.8)
			for i in 3:
				var a0 := TAU * float(i) / 3.0 - PI / 2.0
				var a1 := a0 + TAU / 3.0
				var p0 := Vector2(cos(a0), sin(a0)) * 0.7
				var p1 := Vector2(cos(a1), sin(a1)) * 0.7
				a2 = maxf(a2, _seg(Vector2(u, v), p0, p1, 0.022) * 0.85)
				var q0 := Vector2(cos(a0 + PI), sin(a0 + PI)) * 0.7
				var q1 := Vector2(cos(a1 + PI), sin(a1 + PI)) * 0.7
				a2 = maxf(a2, _seg(Vector2(u, v), q0, q1, 0.022) * 0.85)
			return a2
		"claw":
			var a3 := 0.0
			for i in 3:
				var off := (float(i) - 1.0) * 0.38
				var p0 := Vector2(-0.75 + off * 0.4, -0.8 + off)
				var p1 := Vector2(0.75 + off * 0.4, 0.8 + off)
				var t2 := clampf((Vector2(u, v) - p0).dot(p1 - p0) / (p1 - p0).length_squared(), 0.0, 1.0)
				var w := 0.07 * sin(PI * t2)
				a3 = maxf(a3, _seg(Vector2(u, v), p0, p1, maxf(w, 0.008)))
			return a3
		"streak":
			var k3 := clampf(1.0 - absf(v) / 0.22, 0.0, 1.0)
			var e := clampf(1.0 - absf(u), 0.0, 1.0)
			return pow(k3, 1.5) * pow(e, 0.6)
		"drop":
			var yy2 := (v + 1.0) * 0.5
			var w2 := 0.08 + 0.5 * sin(PI * clampf(yy2 * 1.05, 0.0, 1.0)) * yy2
			var k4 := clampf(1.0 - absf(u) / maxf(w2, 0.03), 0.0, 1.0)
			return pow(k4, 0.8) * clampf((0.95 - v) * 6.0, 0.0, 1.0) * clampf((v + 0.95) * 4.0, 0.0, 1.0)
		"snow":
			var arm := clampf(1.0 - absf(sin(ang * 3.0)) * d * 5.0, 0.0, 1.0) * clampf(1.0 - d, 0.0, 1.0)
			return maxf(arm, clampf(1.0 - d * 4.0, 0.0, 1.0))
		"crack":
			var a4 := 0.0
			for i in 7:
				var aa2 := TAU * float(i) / 7.0 + _noise(float(i), 0.5, 3) * 0.6
				var bend := _noise(float(i) * 3.1, d * 3.0, 5) * 0.35
				var da := absf(wrapf(ang - aa2 - bend * d, -PI, PI))
				var w3 := 0.06 * (1.0 - d) + 0.01
				a4 = maxf(a4, clampf(1.0 - da * d / w3, 0.0, 1.0) * clampf((0.95 - d) * 5.0, 0.0, 1.0)
					* clampf(d * 8.0, 0.0, 1.0))
			return a4
		"wave":
			var k5 := clampf(1.0 - absf(d - 0.7) / 0.3, 0.0, 1.0)
			return k5 * k5 * (3.0 - 2.0 * k5) * clampf((1.0 - d) * 6.0, 0.0, 1.0)
		"shard":
			var dd2 := absf(u) / 0.45 + absf(v)
			return clampf((1.0 - dd2) * 5.0, 0.0, 1.0) * (0.7 + 0.3 * clampf(-v, 0.0, 1.0))
		"swirl":
			var arms := 0.0
			for i in 3:
				var target := fposmod(log(maxf(d, 0.01)) * 2.2 + float(i) * TAU / 3.0, TAU)
				var da2 := absf(wrapf(ang - target, -PI, PI))
				arms = maxf(arms, clampf(1.0 - da2 / 0.45, 0.0, 1.0))
			return arms * clampf((1.0 - d) * 3.0, 0.0, 1.0) * clampf(d * 4.0, 0.0, 1.0)
	return 0.0


## Глаз секты: веки-дуги и зрачок.
static func _eye(u: float, v: float) -> float:
	var lid_top := absf(v + 0.0 - (0.0 - 0.22 * (1.0 - u * u / 0.09))) if absf(u) < 0.3 else 9.0
	var lid_bot := absf(v - (0.22 * (1.0 - u * u / 0.09))) if absf(u) < 0.3 else 9.0
	var a := clampf(1.0 - minf(lid_top, lid_bot) / 0.025, 0.0, 1.0)
	var pupil := clampf(1.0 - sqrt(u * u + v * v) / 0.09, 0.0, 1.0)
	return maxf(a, clampf(pupil * 2.0, 0.0, 1.0))


static func _band(d: float, r: float, w: float) -> float:
	return clampf(1.0 - absf(d - r) / w, 0.0, 1.0)


static func _seg(p: Vector2, a: Vector2, b: Vector2, w: float) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	var dd := (p - (a + ab * t)).length()
	return clampf(1.0 - dd / w, 0.0, 1.0)


## Гладкий шум 2D по сетке (детерминированный, без FastNoiseLite): −1…1.
static func _noise(x: float, y: float, seed_v: int) -> float:
	var xi := floori(x)
	var yi := floori(y)
	var fx := x - float(xi)
	var fy := y - float(yi)
	var sx := fx * fx * (3.0 - 2.0 * fx)
	var sy := fy * fy * (3.0 - 2.0 * fy)
	var a := _hash(xi, yi, seed_v)
	var b := _hash(xi + 1, yi, seed_v)
	var c := _hash(xi, yi + 1, seed_v)
	var d := _hash(xi + 1, yi + 1, seed_v)
	return lerpf(lerpf(a, b, sx), lerpf(c, d, sx), sy)


static func _hash(x: int, y: int, s: int) -> float:
	var h := (x * 374761393 + y * 668265263 + s * 1442695041) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h % 2001) / 1000.0 - 1.0


# ---------- Меши ----------

## Осколок: вытянутая четырёхгранная призма (лёд, камень, кость), единичного размера.
static func shard_mesh() -> Mesh:
	if _mesh.has("shard"):
		return _mesh["shard"]
	var p := PrismMesh.new()
	p.size = Vector3(0.35, 1.0, 0.25)
	_mesh["shard"] = p
	return p


## Шип из земли: конус высотой 1, основание на y = 0.
static func spike_mesh() -> Mesh:
	if _mesh.has("spike"):
		return _mesh["spike"]
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = 0.5
	c.height = 1.0
	c.radial_segments = 6
	c.rings = 1
	_mesh["spike"] = c
	return c


## Камешек: низкополигональная сфера.
static func rock_mesh() -> Mesh:
	if _mesh.has("rock"):
		return _mesh["rock"]
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 0.8
	s.radial_segments = 5
	s.rings = 3
	_mesh["rock"] = s
	return s


## Тор (кольцо-волна в пространстве): внутренний радиус 0.8, внешний 1.
static func torus_mesh() -> Mesh:
	if _mesh.has("torus"):
		return _mesh["torus"]
	var t := TorusMesh.new()
	t.inner_radius = 0.82
	t.outer_radius = 1.0
	t.rings = 24
	t.ring_segments = 6
	_mesh["torus"] = t
	return t


## Материал частиц: текстура kind, сложение цветов add, мешом-квадратом к камере (billboard) или объёмным (меш).
static func particle_mat(kind: String, add: bool, billboard: bool = true) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [kind, add, billboard]
	if _pmat.has(key):
		return _pmat[key]
	var m := Vfx.fx_mat(Color.WHITE, tex(kind) if kind != "" else null, add,
		BaseMaterial3D.BILLBOARD_PARTICLES if billboard else BaseMaterial3D.BILLBOARD_DISABLED)
	m.vertex_color_use_as_albedo = true
	_pmat[key] = m
	return m


## Материал для меша частиц-осколков (камень, лёд): без освещения, цвет из градиента частиц, непрозрачный край.
static func solid_particle_mat(lit: bool) -> StandardMaterial3D:
	var key := "solid|%s" % lit
	if _pmat.has(key):
		return _pmat[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if lit else BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.disable_receive_shadows = true
	_pmat[key] = m
	return m


# ---------- Строительные блоки ----------

static func _mi(root: Node3D, mesh: Mesh, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.set_meta("no_outline", true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.mesh = mesh
	mi.material_override = m
	root.add_child(mi)
	return mi


## Частицы. o: amount, life, color (Color), color2 (конец, по умолчанию прозрачный color), size, speed, tex,
## add, mesh ("quad" | "shard" | "rock" | "spike"), lit (у меша — с освещением), dir, spread, gravity, damping,
## radius, shape ("sphere" | "ring" | "box" | "point"), box (Vector3), explosive, local, curve, align (по скорости),
## spin (град/с), radial (ускорение к центру < 0 / от центра), orbit (по кругу), hue (разброс оттенка 0…1),
## offset, delay, loop (непрерывно), randomness.
static func particles(root: Node3D, o: Dictionary) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = maxi(1, int(o.get("amount", 8)))
	p.lifetime = maxf(0.05, float(o.get("life", 0.6)))
	var loop := bool(o.get("loop", false))
	p.one_shot = not loop
	p.explosiveness = float(o.get("explosive", 0.0 if loop else 0.95))
	p.randomness = float(o.get("randomness", 0.3))
	p.local_coords = bool(o.get("local", false))
	var mesh_kind := String(o.get("mesh", "quad"))
	match mesh_kind:
		"shard":
			p.mesh = shard_mesh()
		"rock":
			p.mesh = rock_mesh()
		"spike":
			p.mesh = spike_mesh()
		_:
			p.mesh = Vfx._quad()
	if mesh_kind == "quad":
		p.material_override = particle_mat(String(o.get("tex", "star")), bool(o.get("add", true)))
	else:
		p.material_override = solid_particle_mat(bool(o.get("lit", false)))
	p.direction = o.get("dir", Vector3.UP)
	p.spread = float(o.get("spread", 180.0))
	var speed := float(o.get("speed", 2.0))
	p.initial_velocity_min = speed * 0.55
	p.initial_velocity_max = speed
	p.gravity = o.get("gravity", Vector3.ZERO)
	var damp := float(o.get("damping", 0.0))
	p.damping_min = damp * 0.8
	p.damping_max = damp
	p.angle_min = 0.0
	p.angle_max = 360.0
	var spin := float(o.get("spin", 0.0))
	if spin != 0.0:
		p.angular_velocity_min = -spin
		p.angular_velocity_max = spin
	var size := float(o.get("size", 0.3))
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	p.scale_amount_curve = Vfx._curve(String(o.get("curve", "shrink")))
	p.particle_flag_align_y = bool(o.get("align", false))
	var radial := float(o.get("radial", 0.0))
	if radial != 0.0:
		p.radial_accel_min = radial * 0.8
		p.radial_accel_max = radial
	var orbit := float(o.get("orbit", 0.0))
	if orbit != 0.0:
		p.tangential_accel_min = orbit * 0.8
		p.tangential_accel_max = orbit
	var hue := float(o.get("hue", 0.0))
	if hue > 0.0:
		p.hue_variation_min = -hue
		p.hue_variation_max = hue
	var c: Color = o.get("color", Color.WHITE)
	var c2: Color = o.get("color2", Color(c, 0.0))
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	g.colors = PackedColorArray([Color(c.lightened(0.35), c.a), c, c2])
	p.color_ramp = g
	match String(o.get("shape", "sphere")):
		"ring":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			p.emission_ring_axis = Vector3.UP
			p.emission_ring_height = 0.05
			p.emission_ring_radius = float(o.get("radius", 0.5))
			p.emission_ring_inner_radius = float(o.get("radius", 0.5)) * 0.85
		"box":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			p.emission_box_extents = o.get("box", Vector3.ONE * 0.3)
		"point":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINT
		_:
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = float(o.get("radius", 0.15))
	root.add_child(p)
	p.position = o.get("offset", Vector3.ZERO)
	var delay := float(o.get("delay", 0.0))
	if delay > 0.0:
		p.emitting = false
		var t := p.create_tween()
		t.tween_interval(delay)
		t.tween_callback(p.restart)
	else:
		p.emitting = true
	return p


## Вспышка-картинка к камере: выпрыгивает и тает (Vfx._sprite с текстурами набора).
static func flash(root: Node3D, kind: String, c: Color, size: float, time: float, add: bool = true,
		offset: Vector3 = Vector3.ZERO, start: float = 0.25, delay: float = 0.0) -> MeshInstance3D:
	var mi := _mi(root, Vfx._quad(), Vfx.fx_mat(c, tex(kind), add, BaseMaterial3D.BILLBOARD_ENABLED))
	var m: StandardMaterial3D = mi.material_override
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


## Плоская картинка на земле (кольцо, трещины, знак, лужа) в точке ground (мировые координаты): растёт от
## start × radius до radius за grow долю time, держится и тает. spin — оборотов за time.
static func decal(root: Node3D, kind: String, c: Color, ground: Vector3, radius: float, time: float,
		add: bool = false, start: float = 0.15, grow: float = 1.0, spin: float = 0.0, delay: float = 0.0,
		fade_in: float = 0.0) -> MeshInstance3D:
	var mi := _mi(root, Vfx._plane(), Vfx.fx_mat(c, tex(kind), add))
	var m: StandardMaterial3D = mi.material_override
	mi.global_position = ground + Vector3(0, 0.06, 0)
	mi.scale = Vector3.ONE * radius * start * 0.5
	var t := mi.create_tween().set_parallel(true)
	if delay > 0.0:
		mi.visible = false
		t.tween_callback(mi.show).set_delay(delay)
	if fade_in > 0.0:
		var a := c.a
		m.albedo_color.a = 0.0
		t.tween_property(m, "albedo_color:a", a, time * fade_in).set_delay(delay)
	t.tween_property(mi, "scale", Vector3.ONE * radius * 0.5, time * grow).set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT).set_delay(delay)
	if spin != 0.0:
		t.tween_property(mi, "rotation:y", TAU * spin, time).set_delay(delay)
	t.tween_property(m, "albedo_color:a", 0.0, time * 0.45).set_delay(delay + time * 0.55)
	return mi


## Расширяющаяся и тающая сфера (оболочка щита, ядро взрыва).
static func sphere(root: Node3D, c: Color, radius: float, time: float, offset: Vector3 = Vector3.ZERO,
		add: bool = false, start: float = 0.2, hold: float = 0.0) -> MeshInstance3D:
	var mi := _mi(root, Vfx._unit_sphere(), Vfx.fx_mat(c, null, add))
	var m: StandardMaterial3D = mi.material_override
	mi.position = offset
	mi.scale = Vector3.ONE * radius * start
	var t := mi.create_tween().set_parallel(true)
	t.tween_property(mi, "scale", Vector3.ONE * radius, time * (1.0 - hold)).set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)
	t.tween_property(m, "albedo_color:a", 0.0, time * (1.0 - hold)).set_delay(time * hold)
	return mi


## Кольцо-волна в пространстве (тор), лежит горизонтально или повёрнуто tilt; растёт до radius.
static func torus(root: Node3D, c: Color, radius: float, time: float, offset: Vector3 = Vector3.ZERO,
		add: bool = true, tilt: Vector3 = Vector3.ZERO, thick: float = 1.0) -> MeshInstance3D:
	var mi := _mi(root, torus_mesh(), Vfx.fx_mat(c, null, add))
	var m: StandardMaterial3D = mi.material_override
	mi.position = offset
	mi.rotation = tilt
	mi.scale = Vector3(radius * 0.2, thick * radius * 0.2, radius * 0.2)
	var t := mi.create_tween().set_parallel(true)
	t.tween_property(mi, "scale", Vector3(radius, thick * 0.5, radius), time).set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)
	t.tween_property(m, "albedo_color:a", 0.0, time * 0.6).set_delay(time * 0.4)
	return mi


## Столб света от земли (ground) вверх.
static func pillar(root: Node3D, c: Color, ground: Vector3, radius: float, height: float, time: float,
		add: bool = true) -> MeshInstance3D:
	var mi := _mi(root, Vfx._tube(), Vfx.fx_mat(c, null, add))
	var m: StandardMaterial3D = mi.material_override
	mi.global_position = ground
	mi.scale = Vector3(radius, 0.01, radius)
	var t := mi.create_tween().set_parallel(true)
	t.tween_property(mi, "scale:y", height, time * 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(mi, "position:y", mi.position.y + height * 0.5, time * 0.3).set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)
	t.tween_property(mi, "scale:x", radius * 0.15, time * 0.6).set_delay(time * 0.4)
	t.tween_property(mi, "scale:z", radius * 0.15, time * 0.6).set_delay(time * 0.4)
	t.tween_property(m, "albedo_color:a", 0.0, time * 0.6).set_delay(time * 0.4)
	return mi


## Дуга удара оружием в точке offset, повёрнута по dir (горизонт), tilt — наклон плоскости (рад), radius;
## проносится на sweep рад справа налево за 45 % time и тает.
static func arc(root: Node3D, c: Color, dir: Vector3, radius: float, time: float, tilt: float = 0.0,
		offset: Vector3 = Vector3.ZERO, sweep: float = 1.2, width: float = 1.0) -> MeshInstance3D:
	var pivot := Node3D.new()
	root.add_child(pivot)
	pivot.position = offset
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() > 0.01:
		pivot.basis = Basis.looking_at(flat.normalized(), Vector3.UP)
	pivot.rotate_object_local(Vector3.FORWARD, tilt)
	var m := Vfx.fx_mat(c, null, true)
	m.vertex_color_use_as_albedo = true
	var mi := _mi(pivot, Vfx._arc_mesh(), m)
	mi.scale = Vector3(radius, radius * width, radius)
	mi.rotation.y = sweep * 0.5
	var t := mi.create_tween().set_parallel(true)
	t.tween_property(mi, "rotation:y", -sweep * 0.5, time * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(m, "albedo_color:a", 0.0, time * 0.55).set_delay(time * 0.45)
	return mi


## Молния: ломаная лента от a до b (мировые), segments изломов, отклонение jitter; два перекрещенных полотна —
## видна с любой стороны. Мерцает и гаснет за time.
static func bolt(root: Node3D, c: Color, a: Vector3, b: Vector3, width: float, time: float, rng: RandomNumberGenerator,
		segments: int = 8, jitter: float = 0.35) -> MeshInstance3D:
	var pts: Array[Vector3] = []
	var axis := b - a
	var side := axis.cross(Vector3.UP)
	if side.length() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()
	var side2 := axis.cross(side).normalized()
	for i in segments + 1:
		var k := float(i) / float(segments)
		var p := a + axis * k
		if i > 0 and i < segments:
			p += side * rng.randf_range(-jitter, jitter) + side2 * rng.randf_range(-jitter, jitter)
		pts.append(p - root.global_position)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for plane in [side, side2]:
		var off: Vector3 = plane * width * 0.5
		for i in pts.size() - 1:
			var w0 := 1.0 - 0.5 * float(i) / float(pts.size())
			var w1 := 1.0 - 0.5 * float(i + 1) / float(pts.size())
			var p0: Vector3 = pts[i]
			var p1: Vector3 = pts[i + 1]
			st.add_vertex(p0 - off * w0)
			st.add_vertex(p1 - off * w1)
			st.add_vertex(p0 + off * w0)
			st.add_vertex(p1 - off * w1)
			st.add_vertex(p1 + off * w1)
			st.add_vertex(p0 + off * w0)
	var mi := _mi(root, st.commit(), Vfx.fx_mat(c, null, true))
	var m: StandardMaterial3D = mi.material_override
	var t := mi.create_tween()
	t.tween_property(m, "albedo_color:a", c.a * 0.35, time * 0.15)
	t.tween_property(m, "albedo_color:a", c.a, time * 0.1)
	t.tween_property(m, "albedo_color:a", 0.0, time * 0.75)
	return mi


## Луч между a и b (мировые): труба, вспыхивает и сужается.
static func beam(root: Node3D, c: Color, a: Vector3, b: Vector3, radius: float, time: float) -> MeshInstance3D:
	var mi := _mi(root, Vfx._tube(), Vfx.fx_mat(c, null, true))
	var m: StandardMaterial3D = mi.material_override
	var len := maxf(a.distance_to(b), 0.05)
	mi.global_position = (a + b) * 0.5
	var up := (b - a).normalized()
	var x := up.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = up.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(up).normalized()
	mi.global_basis = Basis(x * radius, up * len, z * radius)
	var t := mi.create_tween().set_parallel(true)
	t.tween_method(func(k: float) -> void:
		if is_instance_valid(mi):
			mi.global_basis = Basis(x * radius * k, up * len, z * radius * k), 1.0, 0.1, time)
	t.tween_property(m, "albedo_color:a", 0.0, time * 0.5).set_delay(time * 0.5)
	return mi


## Шипы из земли: n конусов по кругу radius вокруг ground, вырастают на height и уходят обратно.
static func spikes(root: Node3D, c: Color, ground: Vector3, n: int, radius: float, height: float, time: float,
		rng: RandomNumberGenerator, lit: bool = true) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if lit else BaseMaterial3D.SHADING_MODE_UNSHADED
	m.disable_receive_shadows = true
	for i in n:
		var ang := TAU * float(i) / float(n) + rng.randf_range(-0.3, 0.3)
		var r := radius * rng.randf_range(0.25, 1.0) if n > 1 else 0.0
		var mi := _mi(root, spike_mesh(), m)
		var h := height * rng.randf_range(0.6, 1.0)
		var w := h * rng.randf_range(0.35, 0.5)
		mi.global_position = ground + Vector3(cos(ang) * r, -h * 0.5, sin(ang) * r)
		mi.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0, TAU), rng.randf_range(-0.3, 0.3))
		mi.scale = Vector3(w, h, w)
		var y := mi.position.y
		var t := mi.create_tween()
		t.tween_property(mi, "position:y", y + h * 0.5, time * 0.18).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT).set_delay(float(i) * time * 0.03)
		t.tween_interval(time * 0.45)
		t.tween_property(mi, "position:y", y - h * 0.1, time * 0.3).set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_IN)


## Постоянная аура вокруг узла (каст, усиление): непрерывные частицы. Не удаляется сама — stop_loop.
static func loop(parent: Node3D, o: Dictionary) -> CPUParticles3D:
	var d := o.duplicate()
	d["loop"] = true
	var p := particles(parent, d)
	p.add_to_group("vfx_loop")
	return p


## Остановить постоянную ауру: новые частицы не появляются, узел удаляется, когда старые догорят.
static func stop_loop(p: Node) -> void:
	if p == null or not is_instance_valid(p):
		return
	if p is CPUParticles3D:
		var cp := p as CPUParticles3D
		cp.emitting = false
		var t := cp.create_tween()
		t.tween_interval(cp.lifetime + 0.1)
		t.tween_callback(cp.queue_free)
	else:
		p.queue_free()


## Краткий огонь (только «Высокое» качество, не больше MAX_LIGHTS сразу): вспышка взрыва, молнии.
static func light(root: Node3D, c: Color, energy: float, rng_m: float, time: float, offset: Vector3 = Vector3.ZERO) -> void:
	if lights_alive >= MAX_LIGHTS:
		return
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = energy
	l.omni_range = rng_m
	l.shadow_enabled = false
	root.add_child(l)
	l.position = offset
	lights_alive += 1
	l.tree_exiting.connect(func() -> void: lights_alive = maxi(0, lights_alive - 1))
	var t := l.create_tween()
	t.tween_property(l, "light_energy", 0.0, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
