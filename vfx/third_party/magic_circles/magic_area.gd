@tool
class_name MagicArea
extends Node3D
## A spell area on the ground: a magic circle, ripple, pillar, mist, vortex, dome, aura, portal,
## ring of runes or strike warning, in one of eight elements. Shaders, meshes and particles made in code: no textures.
##
##     MagicArea.add(self, "fire_circle")
##     var ward := MagicArea.add(self, "holy_dome", {position = Vector3(2, 0, 0), radius = 2.0})
##     MagicArea.add(self, "frost_pillar", {one_shot = true})   # forms, holds, fades, frees itself
##     ward.stop(1.0)                                           # fades out, then frees itself
##
## Options set a property of the node or else a uniform of its shaders (shaders/area.gdshaderinc).

signal finished

const SHADERS := "res://vfx/third_party/magic_circles/shaders/%s.gdshader"
## A kind's parts, the first on the ground: its shader (the kind's own one names the kind), mesh
## (a disc, a tube, a funnel widening to the top, a dome, or a gate standing on the ground), size
## as fractions of the node's radius and height (a dome's and gate's height are of the radius),
## lift (its foot as a fraction of the height), and uniforms.
const KINDS := {
	"circle": [{shader = "circle", mesh = "disc"}],
	"ripple": [{shader = "ripple", mesh = "disc"}],
	"pillar": [{shader = "glow", mesh = "disc"},
		{shader = "pillar", mesh = "tube", size = Vector2(0.55, 1.0)},
		{shader = "pillar", mesh = "tube", size = Vector2(0.22, 0.9), params = {core = 1.0}}],
	"mist": [{shader = "mist", mesh = "disc"},
		{shader = "mist", mesh = "tube", size = Vector2(0.85, 0.3), params = {part = 1.0}}],
	"vortex": [{shader = "glow", mesh = "disc"},
		{shader = "vortex", mesh = "funnel", size = Vector2(0.85, 1.0)},
		{shader = "vortex", mesh = "funnel", size = Vector2(0.55, 0.75), params = {spin = -1.4}}],
	"dome": [{shader = "glow", mesh = "disc"},
		{shader = "dome", mesh = "dome", size = Vector2(0.92, 0.92)}],
	"aura": [{shader = "glow", mesh = "disc", size = Vector2(1.3, 1.0)},
		{shader = "aura", mesh = "tube", size = Vector2(1.0, 0.8)}],
	"portal": [{shader = "glow", mesh = "disc", size = Vector2(0.7, 1.0)},
		{shader = "portal", mesh = "gate"}],
	"runes": [{shader = "glow", mesh = "disc", size = Vector2(0.85, 1.0)},
		{shader = "runes", mesh = "tube", size = Vector2(0.8, 0.14), lift = 0.22},
		{shader = "runes", mesh = "tube", size = Vector2(0.6, 0.1), lift = 0.5, params = {spin = -1.3}}],
	"telegraph": [{shader = "telegraph", mesh = "disc"}],
}
## The particles: how many, from a ring (or a disc with ring 0) as a fraction of the radius, and
## how fast they rise, times the element's.
const SPARKS := {
	"circle": {amount = 24, ring = 0.83, rise = 1.0},
	"ripple": {amount = 14, ring = 0.0, rise = 0.6},
	"pillar": {amount = 48, ring = 0.0, spread = 0.5, rise = 2.4},
	"mist": {amount = 14, ring = 0.0, spread = 0.8, rise = 0.4},
	"vortex": {amount = 40, ring = 0.7, rise = 1.6, pull = 1.0},
	"dome": {amount = 20, ring = 0.85, rise = 0.8},
	"aura": {amount = 30, ring = 0.95, rise = 1.4},
	"portal": {amount = 16, ring = 0.0, spread = 0.6, rise = 0.8},
	"runes": {amount = 18, ring = 0.8, rise = 0.7},
	"telegraph": {amount = 10, ring = 0.95, rise = 0.4},
}
## Colours, the circle's star (sides), how much it writhes (turbulence), and the particles: their
## shape (spark.gdshader's), size in metres, speed up and pull (gravity, up when above 0).
const ELEMENTS := {
	"fire": {color = Color(1.0, 0.72, 0.28), edge_color = Color(1.0, 0.22, 0.03), sides = 3.0,
		turbulence = 0.8, spark = 4, spark_size = 0.07, rise = 1.3, lift = 1.2, flicker = 0.35},
	"frost": {color = Color(0.82, 0.97, 1.0), edge_color = Color(0.22, 0.52, 1.0), sides = 6.0,
		turbulence = 0.1, spark = 2, spark_size = 0.12, rise = 0.6, lift = -0.35, flicker = 0.04},
	"poison": {color = Color(0.78, 1.0, 0.32), edge_color = Color(0.22, 0.62, 0.06), sides = 4.0,
		turbulence = 0.5, spark = 3, spark_size = 0.11, rise = 0.55, lift = 0.1, flicker = 0.12},
	"holy": {color = Color(1.0, 0.97, 0.82), edge_color = Color(1.0, 0.72, 0.26), sides = 8.0,
		turbulence = 0.05, spark = 1, spark_size = 0.16, rise = 0.8, lift = 0.2, flicker = 0.03},
	"shadow": {color = Color(0.07, 0.0, 0.11), edge_color = Color(0.58, 0.14, 0.98), sides = 5.0,
		turbulence = 0.6, spark = 5, spark_size = 0.45, rise = 0.45, lift = 0.1, flicker = 0.2},
	"arcane": {color = Color(0.86, 0.78, 1.0), edge_color = Color(0.42, 0.3, 1.0), sides = 7.0,
		turbulence = 0.2, spark = 0, spark_size = 0.1, rise = 0.75, lift = 0.15, flicker = 0.08},
	"nature": {color = Color(0.74, 1.0, 0.68), edge_color = Color(0.06, 0.7, 0.38), sides = 6.0,
		turbulence = 0.3, spark = 6, spark_size = 0.13, rise = 0.6, lift = -0.12, flicker = 0.06},
	"blood": {color = Color(1.0, 0.36, 0.3), edge_color = Color(0.62, 0.0, 0.06), sides = 5.0,
		turbulence = 0.45, spark = 7, spark_size = 0.09, rise = 1.0, lift = -0.6, flicker = 0.15},
}

## Dither or cutout for every MagicArea whose transparency is "default": set once, before adding
## any, for a PS1-style game (dither) or one with no sorted transparency (cutout).
static var default_transparency := 0

@export_enum("circle", "ripple", "pillar", "mist", "vortex", "dome", "aura", "portal", "runes", "telegraph") var kind := "circle":
	set(v):
		kind = v
		_rebuild()
## Picking one sets the colours, star and turbulence to the element's.
@export_enum("fire", "frost", "poison", "holy", "shadow", "arcane", "nature", "blood") var element := "arcane":
	set(v):
		element = v
		var e: Dictionary = ELEMENTS.get(v, ELEMENTS["arcane"])
		color = e.color
		edge_color = e.edge_color
		_rebuild()
@export var color := Color(0.86, 0.78, 1.0):
	set(v):
		color = v
		set_param(&"color", v)
		_light_color()
@export var edge_color := Color(0.42, 0.3, 1.0):
	set(v):
		edge_color = v
		set_param(&"edge_color", v)
		_light_color()
@export_range(0.1, 10.0, 0.05, "or_greater", "suffix:m") var radius := 1.5:
	set(v):
		radius = v
		_rebuild()
## The top of a pillar, vortex, mist, aura or ring of runes.
@export_range(0.1, 20.0, 0.05, "or_greater", "suffix:m") var height := 3.0:
	set(v):
		height = v
		_rebuild()
@export_range(0.0, 4.0, 0.05) var speed := 1.0
@export_range(0.0, 2.0, 0.05) var intensity := 1.0
@export var particles := true:
	set(v):
		particles = v
		_rebuild()
## An OmniLight3D in the element's colour; shadow's takes light away.
@export var light := true:
	set(v):
		light = v
		_rebuild()
@export_enum("default:-1", "smooth:0", "dither:1", "cutout:2") var transparency := -1:
	set(v):
		transparency = v
		set_param(&"transparency", _transparency())
@export var autoplay := true
## Forms, holds for `duration`, fades and frees itself, instead of looping.
@export var one_shot := false
## Seconds a one-shot holds at full strength.
@export_range(0.0, 30.0, 0.1, "or_greater", "suffix:s") var duration := 1.5
## Seconds to form: circles and runes draw round, pillars, domes and auras rise, ripples spread,
## portals open, a warning fills (its wind-up).
@export_range(0.0, 5.0, 0.05, "suffix:s") var appear := 0.6

enum { IDLE, FORMING, HOLDING, FADING }

var seed := 0.0:
	set(v):
		seed = v
		set_param(&"seed", v)
var _params := {}
var _dirty := true
var _materials: Array[ShaderMaterial] = []
var _parts: Array[Node3D] = []
var _sparks: CPUParticles3D
var _light: OmniLight3D
var _age := 0.0
var _phase := IDLE
var _t := 0.0
var _fade := 0.6
var _grow := 1.0
var _strength := 1.0


## The kinds whose shader is installed.
static func kinds() -> PackedStringArray:
	return PackedStringArray(KINDS.keys().filter(func(k: String) -> bool:
		return ResourceLoader.exists(SHADERS % k)))


## Every installed effect by name, element_kind: "fire_circle", "frost_pillar"...
static func presets() -> PackedStringArray:
	var out := PackedStringArray()
	for k in kinds():
		for e in ELEMENTS:
			out.append("%s_%s" % [e, k])
	return out


## Adds an effect to `parent`, playing, and returns it. `name` is a preset ("fire_circle") or a
## kind ("circle", in arcane). Options as in set_option().
static func add(parent: Node, name: String, options := {}) -> MagicArea:
	var a := MagicArea.new()
	var at := name.find("_")
	if at > 0:
		a.element = name.left(at)
	a.kind = name.substr(at + 1)
	a.seed = randf() * 10.0
	for key in options:
		a.set_option(key, options[key])
	parent.add_child(a)
	return a


func set_option(key: StringName, value: Variant) -> void:
	if key in self:
		set(key, value)
	else:
		set_param(key, value)


## Sets a uniform on all of its shaders, particles' included; it holds through a rebuild.
func set_param(uniform: StringName, value: Variant) -> void:
	_params[uniform] = value
	for m in _materials:
		m.set_shader_parameter(uniform, value)


func get_param(uniform: StringName) -> Variant:
	if uniform in _params:
		return _params[uniform]
	return _materials[0].get_shader_parameter(uniform) if _materials else null


## Starts it again from nothing.
func play() -> void:
	_age = 0.0
	_t = 0.0
	_phase = FORMING if appear > 0.0 else HOLDING
	_grow = 0.0 if appear > 0.0 else 1.0
	if _sparks:
		_sparks.preprocess = 0.0
		_sparks.emitting = particles
		_sparks.restart()
	_update(0.0)


## Fades out over `fade` seconds, then emits finished and frees itself.
func stop(fade := 0.6) -> void:
	_phase = FADING
	_t = 0.0
	_fade = max(fade, 0.001)
	if _sparks:
		_sparks.emitting = false


## How strong it is now, 0 to 1: forming, holding or fading.
func strength() -> float:
	return _strength


func _enter_tree() -> void:
	if _dirty:
		_build()


func _ready() -> void:
	if autoplay or Engine.is_editor_hint():
		play()
		_settle()
	else:
		_phase = IDLE
		_update(0.0)


## Starts a looping effect formed, its particles already flowing: what the scene shows on load.
func _settle() -> void:
	if one_shot and not Engine.is_editor_hint():
		return
	_phase = HOLDING
	_grow = 1.0
	_age = 4.0 + seed
	if _sparks:
		_sparks.preprocess = _sparks.lifetime
		_sparks.restart()
	_update(0.0)


func _process(delta: float) -> void:
	_t += delta
	match _phase:
		FORMING:
			_grow = clampf(_t / appear, 0.0, 1.0)
			if _t >= appear:
				_phase = HOLDING
				_t = 0.0
		HOLDING:
			if one_shot and _t >= duration:
				if Engine.is_editor_hint():
					play()
				else:
					stop()
		FADING:
			if _t >= _fade:
				_phase = IDLE
				finished.emit()
				if not Engine.is_editor_hint():
					queue_free()
	_update(delta)


func _update(delta: float) -> void:
	_age += delta * speed
	var env := 0.0
	match _phase:
		FORMING:
			env = _grow
		HOLDING:
			env = 1.0
		FADING:
			env = 1.0 - clampf(_t / _fade, 0.0, 1.0)
	_strength = env
	set_param(&"age", _age)
	set_param(&"grow", _grow)
	set_param(&"intensity", intensity * env)
	if _light:
		var f: float = ELEMENTS.get(element, ELEMENTS["arcane"]).flicker
		var wave := sin(_age * 13.0) * 0.5 + sin(_age * 7.3 + 1.0) * 0.3 + sin(_age * 23.0) * 0.2
		_light.light_energy = (0.8 if element == "shadow" else 1.4) * intensity * env * (1.0 + f * wave)


func _transparency() -> int:
	return transparency if transparency >= 0 else default_transparency


func _light_color() -> void:
	if _light:
		_light.light_color = (edge_color if element == "shadow" else color.lerp(edge_color, 0.4))


func _rebuild() -> void:
	if is_inside_tree():
		_build()
	else:
		_dirty = true


## The parts, particles and light for the kind, element, size and switches.
func _build() -> void:
	_dirty = false
	for n in _parts:
		n.free()
	_parts.clear()
	_materials.clear()
	_sparks = null
	_light = null
	if not kind in KINDS or not ResourceLoader.exists(SHADERS % kind):
		push_error("MagicArea: unknown kind %s, pick one of %s" % [kind, kinds()])
		return
	var e: Dictionary = ELEMENTS.get(element, ELEMENTS["arcane"])
	for part: Dictionary in KINDS[kind]:
		var mi := MeshInstance3D.new()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.mesh = _mesh(part.mesh)
		var size: Vector2 = part.get("size", Vector2.ONE)
		var r := radius * size.x
		match part.mesh:
			"disc":
				mi.scale = Vector3(r, 1.0, r)
				mi.position.y = 0.01
			"dome":
				mi.scale = Vector3(r, radius * size.y, r)
			"gate":
				mi.scale = Vector3(r, r * size.y, 1.0)
				mi.position.y = r * size.y + 0.02
			_:
				mi.scale = Vector3(r, height * size.y, r)
				mi.position.y = height * part.get("lift", 0.0)
		mi.material_override = _material(part.shader, part.get("params", {}), e)
		_attach(mi)
	if particles:
		_sparks = _make_sparks(SPARKS[kind], e)
		_attach(_sparks)
	if light:
		_light = OmniLight3D.new()
		_light.position.y = minf(height * 0.25, 0.8)
		_light.omni_range = radius * 2.6
		_light.light_negative = element == "shadow"
		_attach(_light)
		_light_color()
	_update(0.0)


func _attach(n: Node3D) -> void:
	add_child(n, false, Node.INTERNAL_MODE_BACK)
	_parts.append(n)


func _material(shader: String, params: Dictionary, e: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(SHADERS % shader)
	m.set_shader_parameter(&"color", color)
	m.set_shader_parameter(&"edge_color", edge_color)
	m.set_shader_parameter(&"sides", e.sides)
	m.set_shader_parameter(&"turbulence", e.turbulence)
	m.set_shader_parameter(&"seed", seed)
	m.set_shader_parameter(&"transparency", _transparency())
	for key in params:
		m.set_shader_parameter(key, params[key])
	for key in _params:
		m.set_shader_parameter(key, _params[key])
	_materials.append(m)
	return m


func _make_sparks(spec: Dictionary, e: Dictionary) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = spec.amount
	p.lifetime = 2.0
	p.local_coords = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * e.spark_size * clampf(radius / 1.5, 0.6, 2.0)
	p.mesh = quad
	p.material_override = _material("spark", {shape = float(e.spark)}, e)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_height = 0.05
	var ring: float = spec.ring
	p.emission_ring_radius = radius * (ring if ring > 0.0 else spec.get("spread", 0.9))
	p.emission_ring_inner_radius = radius * ring * 0.92
	var rise: float = spec.rise * e.rise * clampf(height / 3.0, 0.5, 3.0)
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = rise * 0.5
	p.initial_velocity_max = rise
	p.gravity = Vector3(0.0, e.lift, 0.0)
	if spec.has("pull"):
		p.radial_accel_min = -radius * spec.pull
		p.radial_accel_max = -radius * spec.pull * 0.5
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.15, 0.6, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	p.color_ramp = fade
	p.emitting = particles
	return p


func _mesh(shape: String) -> Mesh:
	if shape == "disc" or shape == "gate":
		var plane := PlaneMesh.new()
		plane.size = Vector2(2.0, 2.0)
		if shape == "gate":
			plane.orientation = PlaneMesh.FACE_Z
		return plane
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 40
	var rings := 12 if shape == "dome" else 6
	for j in rings + 1:
		var v := float(j) / rings
		for i in seg + 1:
			var a := TAU * i / seg
			var pos: Vector3
			var normal: Vector3
			if shape == "dome":
				var th := v * PI * 0.5
				pos = Vector3(cos(a) * cos(th), sin(th), sin(a) * cos(th))
				normal = pos
			else:
				var r := lerpf(0.4, 1.0, v) if shape == "funnel" else 1.0
				pos = Vector3(cos(a) * r, v, sin(a) * r)
				normal = Vector3(cos(a), -0.6 if shape == "funnel" else 0.0, sin(a)).normalized()
			st.set_normal(normal)
			st.set_uv(Vector2(float(i) / seg, v))
			st.add_vertex(pos)
	for j in rings:
		for i in seg:
			var k := j * (seg + 1) + i
			for idx in [k, k + 1, k + seg + 1, k + 1, k + seg + 2, k + seg + 1]:
				st.add_index(idx)
	return st.commit()
