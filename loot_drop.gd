class_name LootDrop
extends Node3D
## Мешочек с добычей на земле: подпрыгивает и вращается, игрок подбирает его, подойдя ближе
## PICKUP_RANGE. Через LIFETIME секунд исчезает (последние секунды мигает).

## Мешочек подобран: items = {id предмета: количество}.
signal picked_up(items: Dictionary)

const PICKUP_RANGE := 2.5
## Небольшая пауза, чтобы мешочек было видно, даже если игрок стоит рядом.
const PICKUP_DELAY := 0.4
const LIFETIME := 60.0
const BLINK_TIME := 5.0

## id предмета -> количество.
var items: Dictionary = {}
var age := 0.0

var _taken := false
var _model: Node3D


## Текст вида «Клык кабана, Зелье здоровья ×2».
static func describe(list: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in list:
		var id: String = key
		var n: int = int(list[key])
		if n > 1:
			parts.append("%s ×%d" % [ItemData.item_name(id), n])
		else:
			parts.append(ItemData.item_name(id))
	return ", ".join(parts)


func _ready() -> void:
	add_to_group("loot_drops")
	_model = Node3D.new()
	_model.position.y = 0.35
	add_child(_model)

	var sack := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.28
	sm.height = 0.46
	sack.mesh = sm
	sack.material_override = Util.mat(Color(0.62, 0.45, 0.25))
	_model.add_child(sack)

	var neck := MeshInstance3D.new()
	var nm := CylinderMesh.new()
	nm.top_radius = 0.12
	nm.bottom_radius = 0.07
	nm.height = 0.16
	neck.mesh = nm
	neck.position.y = 0.27
	neck.material_override = Util.mat(Color(0.55, 0.4, 0.22))
	_model.add_child(neck)

	var tie := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.06
	tm.outer_radius = 0.1
	tie.mesh = tm
	tie.position.y = 0.21
	tie.material_override = Util.mat(Color(1.0, 0.8, 0.25))
	_model.add_child(tie)

	# Светлый круг на земле, чтобы мешочек было легко заметить
	var glow := MeshInstance3D.new()
	var gm := CylinderMesh.new()
	gm.top_radius = 0.6
	gm.bottom_radius = 0.6
	gm.height = 0.01
	glow.mesh = gm
	glow.position.y = 0.02
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(1.0, 0.85, 0.3, 0.35)
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.material_override = glow_mat
	add_child(glow)

	# Появление: мешочек «выпрыгивает»
	_model.scale = Vector3.ONE * 0.2
	var t := create_tween()
	t.tween_property(_model, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _taken:
		return
	age += delta
	if age >= LIFETIME:
		queue_free()
		return
	_model.position.y = 0.35 + sin(age * 3.0) * 0.1
	_model.rotate_y(delta * 1.8)
	if age > LIFETIME - BLINK_TIME:
		_model.visible = int(age * 6.0) % 2 == 0
	if age < PICKUP_DELAY:
		return
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	var d := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z)
	if d.length() < PICKUP_RANGE:
		pick_up()


## Кладёт содержимое в сумку и убирает мешочек.
func pick_up() -> void:
	if _taken:
		return
	_taken = true
	for key in items:
		var id: String = key
		var n: int = int(items[key])
		Game.inventory.add(id, n)
	Util.float_text(get_parent(), global_position + Vector3(0, 1.6, 0), describe(items), Color(1, 0.9, 0.5))
	picked_up.emit(items)
	queue_free()
