class_name QuestFind
extends Node3D
## Находка задания (цель gather, Quests): светящийся кустик травы на земле — тонкий стебель, серебристые листья,
## светлый огонёк сверху и искорки (из примитивов, без коллизии). Появляется, только пока цель не выполнена
## (Quests.finds_tick), лежит в зоне зверей цели. Герой подошёл ближе PICK_RANGE — Quests.pick_find: трава
## в сумке, находка исчезает, новая вырастет позже. Группа "quest_finds".

## С какого расстояния по земле срывается, м.
const PICK_RANGE := 2.5
const LEAF := Color(0.62, 0.95, 0.74)
const GLOW := Color(0.85, 1.0, 0.9)

## Ключ цели ("<предмет>@<зона>"), предмет и модуль заданий — задаются до добавления в дерево.
var key := ""
var item := ""
var quests: Quests
## Сумка была полна — подождать с новой попыткой, с.
var full_cd := 0.0

var _glow: MeshInstance3D
var _leaves: Node3D
var _t := 0.0


func _ready() -> void:
	add_to_group("quest_finds")
	name = "QuestFind"
	_t = randf() * TAU
	var stem := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.015
	cm.bottom_radius = 0.03
	cm.height = 0.38
	cm.radial_segments = 6
	stem.mesh = cm
	stem.position.y = 0.19
	stem.material_override = _mat(Color(0.3, 0.6, 0.32), 0.4)
	stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stem)
	_leaves = Node3D.new()
	add_child(_leaves)
	var lm := SphereMesh.new()
	lm.radius = 0.5
	lm.height = 1.0
	lm.radial_segments = 8
	lm.rings = 4
	var leaf_mat := _mat(LEAF, 0.9)
	for i in 5:
		var l := MeshInstance3D.new()
		l.mesh = lm
		l.material_override = leaf_mat
		l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := TAU * float(i) / 5.0
		var h := 0.1 + 0.06 * float(i % 3)
		l.position = Vector3(cos(a) * 0.12, h, sin(a) * 0.12)
		l.scale = Vector3(0.24, 0.04, 0.1)
		l.rotation = Vector3(0.0, -a, 0.35)
		_leaves.add_child(l)
	_glow = MeshInstance3D.new()
	var gm := SphereMesh.new()
	gm.radius = 0.09
	gm.height = 0.18
	gm.radial_segments = 8
	gm.rings = 4
	_glow.mesh = gm
	_glow.position.y = 0.42
	var gmat := _mat(GLOW, 2.2)
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gmat.albedo_color.a = 0.85
	_glow.material_override = gmat
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glow)
	var sp := Vfx.ambient_sparkles(self, GLOW, 0.35, 4)
	if sp != null:
		sp.position.y = 0.35


func _process(delta: float) -> void:
	_t += delta
	_leaves.rotation.y = _t * 0.6
	var k := 1.0 + 0.18 * sin(_t * 3.0)
	_glow.scale = Vector3(k, k, k)
	if full_cd > 0.0:
		full_cd -= delta
		return
	if quests == null or quests.main == null:
		return
	var p: Variant = quests.main.get("player")
	if not (p is Node3D) or not is_instance_valid(p):
		return
	var d: Vector3 = (p as Node3D).global_position - global_position
	if absf(d.y) < 3.0 and Vector2(d.x, d.z).length() <= PICK_RANGE:
		quests.pick_find(self)


static func _mat(c: Color, glow: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = glow
	return m
