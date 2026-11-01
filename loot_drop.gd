class_name LootDrop
extends Node3D
## Мешочек с добычей на земле: подпрыгивает и вращается, игрок подбирает его, подойдя ближе
## PICKUP_RANGE. Через LIFETIME секунд исчезает (последние секунды мигает). В сумку кладётся то, что помещается
## (Inventory.try_add); если сумка полна, остаток лежит дальше (bag_full), повторная попытка — через RETRY_TIME.
## Золото (gold; со зверя — всегда, Economy.on_mob_killed) берётся сразу при подборе, даже в полную сумку.
## Чем больше предметов, тем крупнее мешочек (босс — 4 предмета).

## Подобрано (может быть и часть содержимого): items = {id предмета: количество}, gold — золото (0 — без него).
signal picked_up(items: Dictionary, gold: int)
## Сумка полна: left — что осталось лежать в мешочке.
signal bag_full(left: Dictionary)

const PICKUP_RANGE := 2.5
## Небольшая пауза, чтобы мешочек было видно, даже если игрок стоит рядом.
const PICKUP_DELAY := 0.4
const LIFETIME := 60.0
const BLINK_TIME := 5.0
## Пауза перед новой попыткой подобрать, если сумка была полна, с.
const RETRY_TIME := 3.0

## id предмета -> количество.
var items: Dictionary = {}
## Золото в мешочке.
var gold := 0
var age := 0.0

var _taken := false
var _retry := 0.0
var _model: Node3D
var _sparkle: MeshInstance3D


## Текст вида «12 зол., Клык кабана, Зелье здоровья I ×2».
static func describe(list: Dictionary, gold_n: int = 0) -> String:
	var parts := PackedStringArray()
	if gold_n > 0:
		parts.append("%d зол." % gold_n)
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

	# Пухлый мешочек с оборкой, золотой ленточкой и монеткой
	var sack := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.28
	sm.height = 0.5
	sm.radial_segments = 14
	sm.rings = 7
	sack.mesh = sm
	sack.scale = Vector3(1.05, 0.95, 1.05)
	sack.material_override = Util.mat(Color(0.78, 0.55, 0.32))
	_model.add_child(sack)

	var neck := MeshInstance3D.new()
	var nm := CylinderMesh.new()
	nm.top_radius = 0.16
	nm.bottom_radius = 0.07
	nm.height = 0.16
	nm.radial_segments = 10
	nm.rings = 1
	neck.mesh = nm
	neck.position.y = 0.3
	neck.material_override = Util.mat(Color(0.72, 0.5, 0.28))
	_model.add_child(neck)

	var tie := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.06
	tm.outer_radius = 0.11
	tm.rings = 16
	tm.ring_segments = 6
	tie.mesh = tm
	tie.position.y = 0.24
	tie.material_override = Util.mat(Color(1.0, 0.78, 0.25))
	_model.add_child(tie)

	# Бантик ленточки
	var bow_m := Util.mat(Color(0.95, 0.35, 0.4))
	for i in 2:
		var side := float(i * 2 - 1)
		var loop := MeshInstance3D.new()
		var lm := SphereMesh.new()
		lm.radius = 0.06
		lm.height = 0.12
		lm.radial_segments = 8
		lm.rings = 4
		loop.mesh = lm
		loop.scale = Vector3(1.0, 0.6, 0.45)
		loop.position = Vector3(0.07 * side, 0.25, -0.12)
		loop.rotation.z = -0.4 * side
		loop.material_override = bow_m
		_model.add_child(loop)

	# Монетка, выглядывающая из мешочка
	var coin := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.075
	cm.bottom_radius = 0.075
	cm.height = 0.025
	cm.radial_segments = 12
	cm.rings = 1
	coin.mesh = cm
	coin.position = Vector3(0.05, 0.38, 0.02)
	coin.rotation = Vector3(PI / 2.0, 0.0, 0.3)
	coin.material_override = Util.mat(Color(1.0, 0.85, 0.3))
	_model.add_child(coin)

	# Подмигивающая искорка над мешочком
	_sparkle = MeshInstance3D.new()
	_sparkle.set_meta("no_outline", true)
	_sparkle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sparkle.mesh = Vfx._quad()
	_sparkle.material_override = Vfx.fx_mat(Color(1.0, 0.95, 0.6, 0.95), Vfx.tex("star"), true,
		BaseMaterial3D.BILLBOARD_ENABLED)
	_sparkle.position = Vector3(0.18, 0.52, 0)
	_model.add_child(_sparkle)

	# Светлый круг на земле, чтобы мешочек было легко заметить
	var glow := MeshInstance3D.new()
	glow.set_meta("no_outline", true)
	glow.mesh = Vfx._plane()
	glow.position.y = 0.03
	glow.scale = Vector3.ONE * 0.75
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.material_override = Vfx.fx_mat(Color(1.0, 0.85, 0.35, 0.7), Vfx.tex("ring"), false)
	add_child(glow)
	var spot := MeshInstance3D.new()
	spot.set_meta("no_outline", true)
	spot.mesh = Vfx._plane()
	spot.position.y = 0.025
	spot.scale = Vector3.ONE * 0.55
	spot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spot.material_override = Vfx.fx_mat(Color(1.0, 0.85, 0.35, 0.45), Vfx.tex("dot"), true)
	add_child(spot)

	# Появление: мешочек «выпрыгивает»; крупнее, если предметов больше двух (минибосс, босс)
	var n := 0
	for k in items:
		n += int(items[k])
	var big := 1.0 + 0.12 * float(clampi(n - 2, 0, 4))
	_model.scale = Vector3.ONE * 0.2
	var t := create_tween()
	t.tween_property(_model, "scale", Vector3.ONE * big, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Vfx.pickup(get_parent(), global_position + Vector3(0, 0.4, 0))


func _process(delta: float) -> void:
	if _taken:
		return
	age += delta
	if age >= LIFETIME:
		queue_free()
		return
	_model.position.y = 0.35 + sin(age * 3.0) * 0.1
	_model.rotate_y(delta * 1.8)
	# Искорка вспыхивает раз в ~1.5 с
	var tw := fmod(age, 1.5) / 1.5
	var k := maxf(0.0, sin(tw * PI * 2.0)) if tw < 0.5 else 0.0
	_sparkle.scale = Vector3.ONE * (0.05 + 0.5 * k)
	if age > LIFETIME - BLINK_TIME:
		_model.visible = int(age * 6.0) % 2 == 0
	if age < PICKUP_DELAY:
		return
	if _retry > 0.0:
		_retry -= delta
		return
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	var d := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z)
	if d.length() < PICKUP_RANGE:
		if pick_up() and p.has_method("play_pickup"):
			p.call("play_pickup")


## Кладёт в сумку, что помещается. Всё взято — мешочек исчезает, иначе остаток лежит (bag_full).
## true — что-то подобрано.
func pick_up() -> bool:
	if _taken:
		return false
	var got: Dictionary = {}
	var left: Dictionary = {}
	var g := gold
	if g > 0:
		Game.gold += g
		gold = 0
	for key in items:
		var id: String = key
		var n: int = int(items[key])
		var k: int = Game.inventory.try_add(id, n)
		if k > 0:
			got[id] = k
		if n - k > 0:
			left[id] = n - k
	if not got.is_empty() or g > 0:
		Util.float_text(get_parent(), global_position + Vector3(0, 1.6, 0), describe(got, g), Color(1, 0.9, 0.5))
		Vfx.pickup(get_parent(), global_position + Vector3(0, 0.5, 0))
		picked_up.emit(got, g)
	if left.is_empty():
		_taken = true
		queue_free()
		return true
	items = left
	_retry = RETRY_TIME
	Util.float_text(get_parent(), global_position + Vector3(0, 1.2, 0), "Сумка полна", Color(1, 0.5, 0.4))
	bag_full.emit(left)
	return not got.is_empty() or g > 0
