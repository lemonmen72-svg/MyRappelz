class_name HazeFx
extends Node3D
## Дымка и туман над водой (0.46): слои atmo/haze.gdshader и частицы над ними. Виды PRESETS:
##   "mist"    — туман острова после дождя и в туман: белёсый, сила — atmo_fog (погода), над рекой, прудом, у моря;
##   "emerald" — дымка над зелёными озёрами подземелья: изумрудные прожилки и светящиеся пылинки, всегда;
##   "abyss"   — чёрная магическая дымка над озером босса: тёмная, клубится вихрем (swirl), фиолетово-изумрудные
##               прожилки, из неё поднимаются чёрные клубы и искры.
## add(вид, центр, размер) — слой (два-три листа на разной высоте); частицы — у ближних к камере (PARTICLE_DIST).

const PRESETS := {
	"mist": {"color": Color(0.84, 0.89, 0.95, 0.9), "glow_color": Color(0.8, 0.9, 1.0), "density": 0.85, "use_fog": true,
		"swirl": 0.0, "glow": 0.0, "scale": 0.06, "drift": Vector2(0.025, 0.01), "heights": [0.4, 1.4],
		"motes": "", "range": 70.0, "night_dim": 0.4},
	"emerald": {"color": Color(0.32, 0.78, 0.55, 0.55), "glow_color": Color(0.3, 1.0, 0.55), "density": 0.6,
		"use_fog": false, "swirl": 0.0, "glow": 0.7, "scale": 0.11, "drift": Vector2(0.02, 0.015),
		"heights": [0.25, 0.9], "motes": "emerald", "range": 60.0},
	"abyss": {"color": Color(0.04, 0.02, 0.07, 0.92), "glow_color": Color(0.55, 0.25, 1.0), "density": 0.85,
		"use_fog": false, "swirl": 1.0, "glow": 0.55, "scale": 0.1, "drift": Vector2(0.01, 0.01),
		"heights": [0.35, 1.3], "motes": "abyss", "range": 0.0},
}
const PARTICLE_DIST := 45.0

## Слои: {kind, center, size, nodes: [MeshInstance3D], motes: CPUParticles3D}.
var layers: Array[Dictionary] = []
var camera_override: Node3D = null
var _t := 0.0

static var current: HazeFx = null


func _ready() -> void:
	name = "HazeFx"
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


## Слой вида kind (PRESETS) с центром center (y — уровень воды) и размером size (м по X и Z).
func add(kind: String, center: Vector3, size: Vector2) -> void:
	var p: Dictionary = PRESETS.get(kind, PRESETS["mist"])
	var nodes: Array = []
	var hs: Array = p["heights"]
	# «Качество эффектов» низкое (и авто-снижение) — один слой
	var n := hs.size() if Quality.effective("effects") > 0 else 1
	for i in n:
		var plane := PlaneMesh.new()
		plane.size = size
		var m := ShaderMaterial.new()
		m.shader = load("res://atmo/haze.gdshader")
		m.set_shader_parameter("haze_color", p["color"])
		m.set_shader_parameter("glow_color", p["glow_color"])
		m.set_shader_parameter("density", float(p["density"]) * (1.0 - 0.18 * float(i)))
		m.set_shader_parameter("use_fog", bool(p["use_fog"]))
		m.set_shader_parameter("swirl", float(p["swirl"]) * (1.0 if i % 2 == 0 else -0.7))
		m.set_shader_parameter("glow", float(p["glow"]))
		m.set_shader_parameter("night_dim", float(p.get("night_dim", 0.55)))
		m.set_shader_parameter("scale", float(p["scale"]) * (1.0 + 0.3 * float(i)))
		m.set_shader_parameter("drift", (p["drift"] as Vector2) * (1.0 + 0.4 * float(i)))
		var mi := MeshInstance3D.new()
		mi.name = "Haze_%s_%d" % [kind, i]
		mi.mesh = plane
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = center + Vector3(0.0, float(hs[i]), 0.0)
		if float(p.get("range", 0.0)) > 0.0:
			mi.visibility_range_end = float(p["range"]) + maxf(size.x, size.y) * 0.5
			mi.visibility_range_end_margin = 10.0
		add_child(mi)
		nodes.append(mi)
	var motes: CPUParticles3D = null
	if String(p["motes"]) != "":
		motes = _motes(String(p["motes"]), size)
		motes.position = center + Vector3(0.0, 0.4, 0.0)
		add_child(motes)
	layers.append({"kind": kind, "center": center, "size": size, "nodes": nodes, "motes": motes})


func _motes(kind: String, size: Vector2) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Motes_" + kind
	var abyss := kind == "abyss"
	p.amount = Quality.particles(26 if abyss else 30)
	p.lifetime = 5.0 if abyss else 6.0
	p.emitting = false
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(size.x * 0.4, 0.2, size.y * 0.4)
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.15 if not abyss else 0.3
	p.initial_velocity_max = 0.45 if not abyss else 0.8
	p.gravity = Vector3(0.0, 0.05, 0.0)
	p.scale_amount_min = 0.05 if not abyss else 0.5
	p.scale_amount_max = 0.12 if not abyss else 1.4
	var g := Gradient.new()
	if abyss:
		g.set_color(0, Color(0.05, 0.02, 0.08, 0.0))
		g.add_point(0.25, Color(0.06, 0.02, 0.1, 0.55))
		g.set_color(g.get_point_count() - 1, Color(0.2, 0.05, 0.3, 0.0))
	else:
		g.set_color(0, Color(0.4, 1.0, 0.6, 0.0))
		g.add_point(0.3, Color(0.4, 1.0, 0.6, 0.9))
		g.set_color(g.get_point_count() - 1, Color(0.3, 1.0, 0.5, 0.0))
	p.color_ramp = g
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX if abyss else BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = VfxKit.tex("smoke" if abyss else "glow")
	q.material = m
	p.mesh = q
	return p


func _process(delta: float) -> void:
	tick(delta)


## Частицы — только у ближних слоёв; туман острова без погоды (atmo_fog ≈ 0) — слои скрыты.
func tick(dt: float) -> void:
	_t -= dt
	if _t > 0.0:
		return
	_t = 0.5
	var cp := _camera_pos()
	var fog := Atmosphere.fog()
	for l in layers:
		var near := cp.distance_to(l["center"]) < PARTICLE_DIST + maxf((l["size"] as Vector2).x, (l["size"] as Vector2).y) * 0.5
		var vis := true
		if String(l["kind"]) == "mist":
			vis = fog > 0.03
		for n in l["nodes"]:
			(n as Node3D).visible = vis
		if l["motes"] != null:
			(l["motes"] as CPUParticles3D).emitting = near and vis


func _camera_pos() -> Vector3:
	if camera_override != null and is_instance_valid(camera_override):
		return camera_override.global_position
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp != null else null
	return cam.global_position if cam != null else Vector3.ZERO


## Сколько слоёв вида kind (тесты).
func count_of(kind: String) -> int:
	var n := 0
	for l in layers:
		if String(l["kind"]) == kind:
			n += 1
	return n
