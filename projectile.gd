class_name Projectile
extends Node3D
## Снаряд игрока: стрела ("arrow"), болт арбалета ("bolt") или светящийся шар ("orb"). Летит к цели с наведением
## и наносит урон при попадании (промах — miss: долетает и показывает «Промах» без урона). Если цель погибла
## или пропала по пути, снаряд исчезает.

const SPEED := 20.0
const MAX_LIFE := 3.0

var target: Mob = null
var shooter: Node3D = null
var damage := 1
var is_crit := false
var kind := "arrow"
var color := Color.WHITE
var size := 1.0
## Вызывается после урона: on_hit.call(target: Mob, damage: int).
var on_hit: Callable = Callable()
## Промах: урона и on_hit нет.
var miss := false

var _life := 0.0
var _spin: Node3D = null


func setup(t: Mob, by: Node3D, dmg: int, crit_hit: bool, k: String, c: Color, s: float = 1.0) -> void:
	target = t
	shooter = by
	damage = dmg
	is_crit = crit_hit
	kind = k
	color = c
	size = s


func _ready() -> void:
	add_to_group("projectiles")
	if kind == "arrow":
		_build_arrow()
	elif kind == "bolt":
		_build_bolt()
	else:
		_build_orb()


func _physics_process(delta: float) -> void:
	_life += delta
	if _life > MAX_LIFE or not is_instance_valid(target) or target.is_dead:
		queue_free()
		return
	var aim := _aim_point()
	var to := aim - global_position
	var step := SPEED * delta
	var hit_r := 0.35 + 0.45 * target.body_scale
	if to.length() <= maxf(step, hit_r):
		_hit()
		return
	global_position += to.normalized() * step
	if is_shaft() and Vector2(to.x, to.z).length() > 0.05:
		look_at(aim, Vector3.UP)
	if _spin != null:
		_spin.rotation.z += delta * 14.0


func _aim_point() -> Vector3:
	return target.aim_point()


func _hit() -> void:
	var t := target
	var by: Node3D = shooter if is_instance_valid(shooter) else null
	var hit_pos := t.aim_point()
	if miss:
		Util.float_text(get_parent(), t.global_position + Vector3(0, 2.6 * t.body_scale + 0.4, 0), "Промах",
			Color(0.8, 0.85, 1.0))
		queue_free()
		return
	t.take_damage(damage, by, is_crit)
	if is_crit:
		Util.float_text(get_parent(), t.global_position + Vector3(0, 2.6 * t.body_scale + 0.4, 0),
			"Крит!", Color(1, 0.85, 0.2), 1.4)
	if on_hit.is_valid():
		on_hit.call(t, damage)
	if is_shaft():
		Vfx.hit_spark(get_parent(), hit_pos, color.lightened(0.3), 0.9 * size)
	else:
		_spark(hit_pos)
	queue_free()


## Стрела или болт (летит наконечником вперёд, поворачивается к цели).
func is_shaft() -> bool:
	return kind == "arrow" or kind == "bolt"


## Болт арбалета: короткое толстое древко, тяжёлый стальной наконечник, два коротких пера и шлейф.
func _build_bolt() -> void:
	var shaft := _part(_cyl_mesh(0.032, 0.032, 0.46), Util.mat(Color(0.32, 0.22, 0.16)), Vector3.ZERO, false)
	shaft.rotation.x = PI / 2.0
	var tip := _part(_cyl_mesh(0.0, 0.07, 0.14), Util.mat(Color(0.72, 0.75, 0.82)), Vector3(0, 0, -0.3), false)
	tip.rotation.x = -PI / 2.0
	var fm := Util.mat(color.lightened(0.2))
	for i in 2:
		var fb := BoxMesh.new()
		fb.size = Vector3(0.14, 0.012, 0.1) if i == 0 else Vector3(0.012, 0.14, 0.1)
		_part(fb, fm, Vector3(0, 0, 0.18), false)
	var trail := _part(_cyl_mesh(0.0, 0.06, 0.8), Vfx.fx_mat(Color(color.lightened(0.3), 0.4)), Vector3(0, 0, 0.62), true)
	trail.rotation.x = PI / 2.0
	_trail_particles(Color(color.lightened(0.4), 0.9), 0.08)


## Стрела: древко, наконечник-конус, оперение цвета класса и светящийся шлейф.
func _build_arrow() -> void:
	var wood := Util.mat(Color(0.6, 0.42, 0.24))
	var shaft := _part(_cyl_mesh(0.025, 0.025, 0.72), wood, Vector3.ZERO, false)
	shaft.rotation.x = PI / 2.0
	var tip := _part(_cyl_mesh(0.0, 0.065, 0.18), Util.mat(Color(0.85, 0.88, 0.95)), Vector3(0, 0, -0.44), false)
	tip.rotation.x = -PI / 2.0
	var fm := Util.mat(color.lightened(0.35))
	for i in 2:
		var fb := BoxMesh.new()
		fb.size = Vector3(0.17, 0.015, 0.16) if i == 0 else Vector3(0.015, 0.17, 0.16)
		_part(fb, fm, Vector3(0, 0, 0.3), false)
	# Шлейф: вытянутый светящийся конус позади и искорки
	var trail := _part(_cyl_mesh(0.0, 0.07, 1.0), Vfx.fx_mat(Color(color.lightened(0.3), 0.45)), Vector3(0, 0, 0.85), true)
	trail.rotation.x = PI / 2.0
	_trail_particles(Color(color.lightened(0.4), 0.9), 0.1)


## Магический шар: яркое ядро, ореол-звезда, кружащие искры и шлейф.
func _build_orb() -> void:
	var cm := SphereMesh.new()
	cm.radius = 0.15 * size
	cm.height = 0.3 * size
	cm.radial_segments = 14
	cm.rings = 7
	_part(cm, glow_mat(color.lightened(0.55), 1.0), Vector3.ZERO, true, false)
	var hm := SphereMesh.new()
	hm.radius = 0.27 * size
	hm.height = 0.54 * size
	hm.radial_segments = 14
	hm.rings = 7
	var halo := _part(hm, glow_mat(color, 0.4), Vector3.ZERO, true, false)
	var t := halo.create_tween().set_loops()
	t.tween_property(halo, "scale", Vector3.ONE * 1.25, 0.15)
	t.tween_property(halo, "scale", Vector3.ONE, 0.15)
	var star := _part(Vfx._quad(), Vfx.fx_mat(Color(color.lightened(0.3), 0.85), Vfx.tex("star"), true,
		BaseMaterial3D.BILLBOARD_ENABLED), Vector3.ZERO, true, false)
	star.scale = Vector3.ONE * 0.9 * size
	# Две искры на орбите вокруг шара
	_spin = Node3D.new()
	add_child(_spin)
	var dot_m := Vfx.fx_mat(Color(color.lightened(0.5), 0.95), Vfx.tex("star"), true, BaseMaterial3D.BILLBOARD_ENABLED)
	for i in 2:
		var d := MeshInstance3D.new()
		d.set_meta("no_outline", true)
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		d.mesh = Vfx._quad()
		d.material_override = dot_m
		d.position = Vector3(0.32 if i == 0 else -0.32, 0, 0) * size
		d.scale = Vector3.ONE * 0.3 * size
		_spin.add_child(d)
	_trail_particles(color, 0.14)


## Вспышка при попадании магического снаряда.
func _spark(pos: Vector3) -> void:
	var p := get_parent()
	if p == null:
		return
	Vfx.magic_burst(p, pos, color, 0.9 * size, 0.25)


func _trail_particles(c: Color, radius: float) -> void:
	var tr := Vfx.ambient_sparkles(self, c, radius * size, 14)
	tr.lifetime = 0.35
	tr.initial_velocity_min = 0.0
	tr.initial_velocity_max = 0.3
	tr.gravity = Vector3.ZERO
	tr.scale_amount_min = 0.12 * size
	tr.scale_amount_max = 0.24 * size


## Деталь снаряда. Размер меша умножается на size (масштаб узла), кроме уже учтённого (scaled = false).
func _part(mesh: Mesh, m: Material, pos: Vector3, no_outline: bool, scaled: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if no_outline:
		mi.set_meta("no_outline", true)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos * size
	if scaled:
		mi.scale = Vector3.ONE * size
	add_child(mi)
	return mi


static func _cyl_mesh(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 8
	c.rings = 1
	return c


## Светящийся материал без освещения (alpha < 1: полупрозрачный).
static func glow_mat(c: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


## Вспышка умения (взрыв, волна, лечение): светящаяся сфера, кольцо на земле, искры. См. Vfx.magic_burst.
static func burst(parent: Node, pos: Vector3, c: Color, radius: float, time: float) -> void:
	Vfx.magic_burst(parent, pos, c, radius, time)
