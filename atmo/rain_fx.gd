class_name RainFx
extends Node3D
## Дождь у камеры (0.46): два открытых цилиндра со струями (atmo/rain.gdshader — ближний и дальний, параллакс),
## брызги у ног героя (CPUParticles3D, по «Качеству эффектов»), сила — Atmosphere.rain(); при дожде < 0.02 всё
## скрыто. Следует за камерой (цилиндры) и героем (брызги). Мокрая земля и круги на воде — шейдеры (atmo_wet,
## atmo_rain).

const NEAR_R := 7.0
const FAR_R := 16.0
const HEIGHT := 26.0
const SPLASHES := 60

var near_mi: MeshInstance3D
var far_mi: MeshInstance3D
var splashes: CPUParticles3D
var _mats: Array[ShaderMaterial] = []
var follow: Node3D = null
var camera_override: Node3D = null
var amount := 0.0


func _ready() -> void:
	name = "RainFx"
	near_mi = _cylinder(NEAR_R, 260.0, 1.5)
	far_mi = _cylinder(FAR_R, 420.0, 1.1)
	splashes = _splashes()
	add_child(splashes)
	_show(false)


func _cylinder(r: float, cols: float, spd: float) -> MeshInstance3D:
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = HEIGHT
	cyl.cap_top = false
	cyl.cap_bottom = false
	cyl.radial_segments = 24
	cyl.rings = 1
	var m := ShaderMaterial.new()
	m.shader = load("res://atmo/rain.gdshader")
	m.set_shader_parameter("columns", cols)
	m.set_shader_parameter("speed", spd)
	_mats.append(m)
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = HEIGHT
	add_child(mi)
	return mi


func _splashes() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Splashes"
	p.amount = Quality.particles(SPLASHES)
	p.lifetime = 0.4
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(7.0, 0.02, 7.0)
	p.direction = Vector3.UP
	p.spread = 40.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.1
	p.gravity = Vector3(0, -6.0, 0)
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.1
	var g := Gradient.new()
	g.set_color(0, Color(0.85, 0.92, 1.0, 0.55))
	g.set_color(1, Color(0.85, 0.92, 1.0, 0.0))
	p.color_ramp = g
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	# Без keep_scale Godot 4.3 теряет размер частицы (scale_amount) — квад 1 м: белые «шипы» по всей площади
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = VfxKit.tex("soft")
	q.material = m
	p.mesh = q
	return p


func _show(on: bool) -> void:
	near_mi.visible = on
	far_mi.visible = on
	splashes.emitting = on


func _process(_delta: float) -> void:
	tick()


func tick() -> void:
	amount = Atmosphere.rain()
	var on := amount > 0.02
	if on != near_mi.visible:
		_show(on)
	if not on:
		return
	for m in _mats:
		m.set_shader_parameter("rain", amount)
		m.set_shader_parameter("wind", 0.06 + 0.12 * float(Atmosphere.current.w.get("wind", 0.3)) if Atmosphere.current != null else 0.1)
	var cp := _camera_pos()
	near_mi.global_position = cp
	far_mi.global_position = cp
	if follow != null and is_instance_valid(follow):
		splashes.global_position = follow.global_position + Vector3(0, 0.05, 0)


func _camera_pos() -> Vector3:
	if camera_override != null and is_instance_valid(camera_override):
		return camera_override.global_position
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp != null else null
	return cam.global_position if cam != null else global_position
