class_name FireFx
extends Node3D
## Огни мира (0.46, задача Максима: «на всевозможных факелах и кострах эффекты огня соответствующего цвета, а в
## тёмное время суток — свечение от них»). Все огни — один MultiMesh с шейдером пламени atmo/flame.gdshader (квад к
## камере, цвет и фаза — INSTANCE_CUSTOM), у ближайших к камере — искры (SPARKS) и дым у костров (SMOKE): пул
## CPUParticles3D, переставляется раз в REASSIGN с. Свет от огня — NightLights (ночью ярче). Огни ставит мир:
## остров — точки огней построек (IslandPois.fires), подземелье — жаровни, котлы, факелы (DungeonProps).
## Цвета: COLORS (тёплый — факелы и костры, изумрудный — секта, фиолетовый — тёмные эльфы, голубой — эльфы).

const COLORS := {
	"warm": Color(1.0, 0.52, 0.16), "camp": Color(1.0, 0.45, 0.12), "emerald": Color(0.3, 1.0, 0.5),
	"violet": Color(0.72, 0.38, 1.0), "azure": Color(0.4, 0.75, 1.0), "gold": Color(1.0, 0.75, 0.3),
}
const REASSIGN := 0.5
## Искры и дым — у стольких ближайших огней (по «Качеству эффектов»).
const SPARKS := [1, 3, 5]
const SPARK_DIST := 22.0

## Огни: {pos, size, color, kind ("torch" / "camp" / "brazier"), smoke}.
var fires: Array[Dictionary] = []
var mmi: MultiMeshInstance3D = null
var _emitters: Array[Dictionary] = []
var _t := 0.0
var camera_override: Node3D = null

static var current: FireFx = null
static var _mat: ShaderMaterial = null


func _ready() -> void:
	name = "FireFx"
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


static func color_of(kind: String) -> Color:
	return COLORS.get(kind, COLORS["warm"])


## Огонь в точке pos (основание пламени), высотой size м, цвет color; kind "camp" — костёр (дым), иначе нет.
func add(pos: Vector3, size: float, color: Color, kind: String = "torch") -> void:
	fires.append({"pos": pos, "size": size, "color": color, "kind": kind, "smoke": kind == "camp"})


## Собрать MultiMesh (после всех add).
func build() -> void:
	if mmi != null:
		mmi.queue_free()
		mmi = null
	if fires.is_empty():
		return
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://atmo/flame.gdshader")
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = fires.size()
	for i in fires.size():
		var f: Dictionary = fires[i]
		var s := float(f["size"])
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(s * 0.55, s, s * 0.55)), f["pos"]))
		var c: Color = f["color"]
		mm.set_instance_custom_data(i, Color(c.r, c.g, c.b, fposmod(float(i) * 0.618, 1.0)))
	mmi = MultiMeshInstance3D.new()
	mmi.name = "Fires"
	mmi.multimesh = mm
	mmi.material_override = _mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 4.0
	add_child(mmi)
	_build_emitters(int(SPARKS[clampi(Quality.effective("effects"), 0, SPARKS.size() - 1)]))


func _build_emitters(n: int) -> void:
	for e in _emitters:
		(e["sparks"] as Node).queue_free()
		if e["smoke"] != null:
			(e["smoke"] as Node).queue_free()
	_emitters.clear()
	for i in n:
		var sp := _sparks()
		add_child(sp)
		var sm := _smoke()
		add_child(sm)
		_emitters.append({"sparks": sp, "smoke": sm, "fire": -1})


func _sparks() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Sparks"
	p.amount = Quality.particles(14)
	p.lifetime = 1.4
	p.emitting = false
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 22.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.9
	p.gravity = Vector3(0.0, 0.35, 0.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.12
	p.scale_amount_min = 0.03
	p.scale_amount_max = 0.07
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.4, 1.0))
	g.set_color(1, Color(1.0, 0.3, 0.05, 0.0))
	p.color_ramp = g
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = VfxKit.tex("star")
	q.material = m
	p.mesh = q
	return p


func _smoke() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Smoke"
	p.amount = Quality.particles(10)
	p.lifetime = 4.0
	p.emitting = false
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 0.9
	p.gravity = Vector3(0.25, 0.15, 0.0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.4))
	sc.add_point(Vector2(1.0, 1.6))
	p.scale_amount_curve = sc
	var g := Gradient.new()
	g.set_color(0, Color(0.35, 0.33, 0.32, 0.0))
	g.add_point(0.2, Color(0.35, 0.33, 0.32, 0.32))
	g.set_color(g.get_point_count() - 1, Color(0.45, 0.45, 0.48, 0.0))
	p.color_ramp = g
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = VfxKit.tex("smoke")
	q.material = m
	p.mesh = q
	return p


func _process(delta: float) -> void:
	tick(delta)


func tick(dt: float) -> void:
	_t -= dt
	if _t > 0.0:
		return
	_t = REASSIGN
	if fires.is_empty() or _emitters.is_empty():
		return
	var cp := _camera_pos()
	var near: Array = []
	for i in fires.size():
		var d := cp.distance_to(fires[i]["pos"])
		if d < SPARK_DIST:
			near.append([d, i])
	near.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for k in _emitters.size():
		var e: Dictionary = _emitters[k]
		var sp: CPUParticles3D = e["sparks"]
		var sm: CPUParticles3D = e["smoke"]
		if k >= near.size():
			sp.emitting = false
			sm.emitting = false
			e["fire"] = -1
			continue
		var fi := int(near[k][1])
		if int(e["fire"]) == fi:
			continue
		e["fire"] = fi
		var f: Dictionary = fires[fi]
		var top := (f["pos"] as Vector3) + Vector3(0.0, float(f["size"]) * 0.45, 0.0)
		sp.global_position = top
		sp.emitting = true
		sp.color_ramp.set_color(0, (f["color"] as Color).lightened(0.4))
		sm.global_position = top + Vector3(0.0, float(f["size"]) * 0.4, 0.0)
		sm.emitting = bool(f["smoke"])


func _camera_pos() -> Vector3:
	if camera_override != null and is_instance_valid(camera_override):
		return camera_override.global_position
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp != null else null
	return cam.global_position if cam != null else Vector3.ZERO


## Сколько искр сейчас горит (тесты).
func active_emitters() -> int:
	var n := 0
	for e in _emitters:
		if (e["sparks"] as CPUParticles3D).emitting:
			n += 1
	return n
