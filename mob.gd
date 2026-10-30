class_name Mob
extends CharacterBody3D

## killed = true: зверя убили, false: его приручили
signal gone(mob: Mob, killed: bool)

var slot := -1
var mob_name := "Зверь"
var level := 1
var max_hp := 30
var hp := 30
var atk := 5
var speed := 3.0
var xp_reward := 10
var color := Color(0.5, 0.4, 0.3)
var body_scale := 1.0
var home := Vector3.ZERO
var aggro_range := 7.0
var leash := 22.0
var attack_cd := 0.0
var is_dead := false
var returning := false
var target: Node3D = null

var _wander_to := Vector3.ZERO
var _wander_wait := 0.0
var _regen_acc := 0.0
var _mat: StandardMaterial3D
var _label: Label3D


func setup(d: Dictionary, spawn_slot: int, pos: Vector3) -> void:
	slot = spawn_slot
	mob_name = d["name"]
	level = d["level"]
	max_hp = d["hp"]
	hp = max_hp
	atk = d["atk"]
	speed = d["speed"]
	xp_reward = d["xp"]
	color = d["color"]
	body_scale = d["scale"]
	home = pos
	position = pos


func _ready() -> void:
	add_to_group("mobs")
	collision_layer = 2
	collision_mask = 1
	_mat = Util.creature_body(self, color, body_scale)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.pixel_size = 0.01
	_label.font_size = 40
	_label.outline_size = 10
	_label.position = Vector3(0, 1.9 * body_scale + 0.3, 0)
	add_child(_label)
	_wander_to = home
	_update_label()


func _target_gone() -> bool:
	if not is_instance_valid(target):
		return true
	if target.get("is_down") == true:
		return true
	return false


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	attack_cd = maxf(0.0, attack_cd - delta)

	if target != null and _target_gone():
		target = null

	var dir := Vector3.ZERO
	var face := Vector3.ZERO
	var spd := speed

	if returning:
		# Возвращается домой и лечится
		var to_home := home - global_position
		to_home.y = 0.0
		if to_home.length() < 1.5:
			returning = false
		else:
			dir = to_home.normalized()
			spd = speed * 1.5
		_heal(delta, 0.25)
	elif target != null:
		var to := target.global_position - global_position
		to.y = 0.0
		face = to
		if global_position.distance_to(home) > leash:
			target = null
			returning = true
		elif to.length() > 1.9:
			dir = to.normalized()
		elif attack_cd <= 0.0:
			attack_cd = 1.3
			target.call("take_damage", atk + randi_range(-1, 2), self)
	else:
		# Ищем игрока
		var p := get_tree().get_first_node_in_group("player") as Node3D
		if p != null and global_position.distance_to(p.global_position) < aggro_range:
			target = p
		# Бродим около дома
		var to_w := _wander_to - global_position
		to_w.y = 0.0
		if to_w.length() > 0.6:
			dir = to_w.normalized()
			spd = speed * 0.4
		else:
			_wander_wait -= delta
			if _wander_wait <= 0.0:
				_wander_wait = randf_range(2.0, 5.0)
				var a := randf() * TAU
				_wander_to = home + Vector3(cos(a), 0.0, sin(a)) * randf_range(1.0, 6.0)
		_heal(delta, 0.1)

	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= 25.0 * delta
	move_and_slide()

	if face.length() < 0.01:
		face = dir
	if face.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-face.x, -face.z), 8.0 * delta)


func _heal(delta: float, frac_per_sec: float) -> void:
	if hp >= max_hp:
		return
	_regen_acc += delta * max_hp * frac_per_sec
	if _regen_acc >= 1.0:
		var h := int(_regen_acc)
		hp = mini(max_hp, hp + h)
		_regen_acc -= h
		_update_label()


func take_damage(amount: int, attacker: Node3D) -> void:
	if is_dead:
		return
	hp -= amount
	if not returning:
		target = attacker
	Util.float_text(get_parent(), global_position + Vector3(0, 2.2 * body_scale, 0), str(amount), Color(1, 1, 1))
	_flash()
	_update_label()
	if hp <= 0:
		_die()


func _die() -> void:
	is_dead = true
	remove_from_group("mobs")
	collision_layer = 0
	_label.hide()
	gone.emit(self, true)
	var t := create_tween()
	t.tween_property(self, "scale", Vector3(1, 0.05, 1), 0.4)
	t.tween_callback(queue_free)


## Вызывается, когда зверя приручили.
func consume() -> void:
	is_dead = true
	remove_from_group("mobs")
	gone.emit(self, false)
	queue_free()


func _flash() -> void:
	_mat.albedo_color = Color(1, 1, 1)
	var t := create_tween()
	t.tween_property(_mat, "albedo_color", color, 0.15)


func _update_label() -> void:
	_label.text = "%s  Ур.%d\n%d/%d" % [mob_name, level, hp, max_hp]
