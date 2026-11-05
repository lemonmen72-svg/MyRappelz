class_name Portal
extends Node3D
## Портал между островом и подземельем (0.35): у входа в пещеру острова (вплотную к закрытому проёму — IslandPois
## кладёт место в мета "cave_portal" мира) и у входа в подземелье (DungeonWorld.portal()). Только эффекты: каменного
## кольца нет — обод из света (TorusMesh), воронка (portal.gdshader), руны на земле, искры, свет. Лицо — +Z узла.
## Вход: герой ближе ENTER_RANGE к точке перед порталом (front_point) — main.try_portal: проверка доступа
## (Dungeon.enter_block) и переход в локацию to (main.travel). Группа "portals".

const RADIUS := 1.35
## Центр кольца над землёй, м.
const HEIGHT := 1.55
const ENTER_RANGE := 1.7

## Куда ведёт: "dungeon" или "island".
var to := "dungeon"
var _light: OmniLight3D
var _t := 0.0


func _ready() -> void:
	add_to_group("portals")
	name = "Portal_" + to
	# Обод из света
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	var tm := TorusMesh.new()
	tm.inner_radius = RADIUS - 0.09
	tm.outer_radius = RADIUS + 0.09
	tm.rings = 32
	tm.ring_segments = 8
	ring.mesh = tm
	ring.rotation.x = PI * 0.5
	ring.position.y = HEIGHT
	ring.material_override = _glow_mat(Color(0.35, 1.0, 0.6), 3.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.set_meta("no_outline", true)
	add_child(ring)
	# Воронка
	var disk := MeshInstance3D.new()
	disk.name = "Vortex"
	var qm := QuadMesh.new()
	qm.size = Vector2(RADIUS * 2.0, RADIUS * 2.0)
	disk.mesh = qm
	disk.position.y = HEIGHT
	var sm := ShaderMaterial.new()
	sm.shader = load("res://portal.gdshader")
	disk.material_override = sm
	disk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disk.set_meta("no_outline", true)
	add_child(disk)
	# Руны на земле: светящийся круг
	var glyph := MeshInstance3D.new()
	glyph.name = "Glyph"
	var tg := TorusMesh.new()
	tg.inner_radius = 1.55
	tg.outer_radius = 1.7
	tg.rings = 32
	tg.ring_segments = 4
	glyph.mesh = tg
	glyph.scale = Vector3(1.0, 0.08, 1.0)
	glyph.position = Vector3(0, 0.05, 0.6)
	glyph.material_override = _glow_mat(Color(0.55, 0.4, 1.0), 2.0)
	glyph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glyph.set_meta("no_outline", true)
	add_child(glyph)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.4, 1.0, 0.65)
	_light.light_energy = 1.6
	_light.omni_range = 7.0
	_light.position = Vector3(0, HEIGHT, 0.8)
	add_child(_light)
	var sp := Vfx.ambient_sparkles(self, Color(0.5, 1.0, 0.75), RADIUS, 10)
	if sp != null:
		sp.position.y = HEIGHT


func _process(delta: float) -> void:
	_t += delta
	_light.light_energy = 1.4 + 0.3 * sin(_t * 2.3) + 0.15 * sin(_t * 5.1)


## Точка входа: перед порталом на земле (мировые координаты).
func front_point() -> Vector3:
	return global_transform * Vector3(0, 0, 0.9)


## Где встаёт герой, вышедший из этого портала: на 3 м перед ним.
func exit_point() -> Vector3:
	return global_transform * Vector3(0, 0, 3.0)


static func _glow_mat(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m
