class_name Projectile
extends Node3D
## Снаряд игрока: стрела ("arrow") или светящийся шар ("orb"). Летит к цели с наведением
## и наносит урон при попадании. Если цель погибла или пропала по пути, снаряд исчезает.

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

var _life := 0.0


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
	if kind == "arrow" and Vector2(to.x, to.z).length() > 0.05:
		look_at(aim, Vector3.UP)


func _aim_point() -> Vector3:
	return target.global_position + Vector3(0, 0.75 * target.body_scale, 0)


func _hit() -> void:
	var t := target
	var by: Node3D = shooter if is_instance_valid(shooter) else null
	t.take_damage(damage, by)
	if is_crit:
		Util.float_text(get_parent(), t.global_position + Vector3(0, 2.6 * t.body_scale + 0.4, 0),
			"Крит!", Color(1, 0.85, 0.2))
	if on_hit.is_valid():
		on_hit.call(t, damage)
	if kind != "arrow":
		_spark(t.global_position + Vector3(0, 0.75 * t.body_scale, 0))
	queue_free()


func _build_arrow() -> void:
	var shaft := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.05, 0.05, 0.8) * size
	shaft.mesh = sm
	shaft.material_override = Util.mat(Color(0.55, 0.38, 0.2))
	add_child(shaft)
	var tip := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.1, 0.1, 0.16) * size
	tip.mesh = tm
	tip.position = Vector3(0, 0, -0.45 * size)
	tip.material_override = Util.mat(Color(0.8, 0.8, 0.85))
	add_child(tip)
	var fl := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.16, 0.02, 0.18) * size
	fl.mesh = fm
	fl.position = Vector3(0, 0, 0.35 * size)
	fl.material_override = Util.mat(color.lightened(0.3))
	add_child(fl)


func _build_orb() -> void:
	var core := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 0.16 * size
	cm.height = 0.32 * size
	core.mesh = cm
	core.material_override = glow_mat(color.lightened(0.4), 1.0)
	add_child(core)
	var halo := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.3 * size
	hm.height = 0.6 * size
	halo.mesh = hm
	halo.material_override = glow_mat(color, 0.45)
	add_child(halo)
	var t := halo.create_tween().set_loops()
	t.tween_property(halo, "scale", Vector3.ONE * 1.25, 0.15)
	t.tween_property(halo, "scale", Vector3.ONE, 0.15)


## Вспышка при попадании магического снаряда.
func _spark(pos: Vector3) -> void:
	var p := get_parent()
	if p == null:
		return
	burst(p, pos, color, 0.9, 0.25)


## Светящийся материал без освещения (alpha < 1: полупрозрачный).
static func glow_mat(c: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


## Расширяющаяся и тающая сфера (вспышка, взрыв, волна умения).
static func burst(parent: Node, pos: Vector3, c: Color, radius: float, time: float) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 24
	sm.rings = 12
	mi.mesh = sm
	var m := glow_mat(c, 0.6)
	mi.material_override = m
	parent.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * 0.2
	var t := mi.create_tween()
	t.set_parallel(true)
	t.tween_property(mi, "scale", Vector3.ONE * radius, time)
	t.tween_property(m, "albedo_color:a", 0.0, time)
	t.chain().tween_callback(mi.queue_free)
