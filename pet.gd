class_name Pet
extends CharacterBody3D

signal stats_changed

var pet_name := "Питомец"
var level := 1
var xp := 0
var xp_next := 25
var max_hp := 40
var hp := 40
var atk := 6
var speed := 5.5
var color := Color.WHITE
var body_scale := 1.0
var owner_node: Player
var attack_cd := 0.0
var target: Mob = null
var is_down := false
var down_timer := 0.0

var _model: Node3D
var _label: Label3D


func setup(owner_p: Player, n: String, c: Color, s: float, hp_v: int, atk_v: int, spd: float) -> void:
	owner_node = owner_p
	pet_name = n
	color = c
	body_scale = s
	max_hp = hp_v
	hp = hp_v
	atk = atk_v
	speed = spd


func _ready() -> void:
	add_to_group("pets")
	collision_layer = 2
	collision_mask = 1
	_model = Node3D.new()
	add_child(_model)
	Util.creature_body(_model, color, body_scale)

	# Голубой ошейник, чтобы отличать питомца от диких зверей
	var collar := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.95, 0.15, 0.2) * body_scale
	collar.mesh = cm
	collar.position = Vector3(0, 0.8 * body_scale, -0.5 * body_scale)
	collar.material_override = Util.mat(Color(0.2, 0.8, 1.0))
	_model.add_child(collar)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.pixel_size = 0.01
	_label.font_size = 40
	_label.outline_size = 10
	_label.modulate = Color(0.6, 0.9, 1.0)
	_label.position = Vector3(0, 1.9 * body_scale + 0.3, 0)
	add_child(_label)
	_update_label()


func _physics_process(delta: float) -> void:
	if is_down:
		down_timer -= delta
		if down_timer <= 0.0:
			is_down = false
			hp = int(max_hp * 0.5)
			_model.visible = true
			_label.visible = true
			global_position = owner_node.global_position + Vector3(1.5, 0.2, 1.5)
			_update_label()
			stats_changed.emit()
		return

	attack_cd = maxf(0.0, attack_cd - delta)
	_pick_target()

	var dir := Vector3.ZERO
	var face := Vector3.ZERO
	var spd := speed

	if target != null:
		var to := target.global_position - global_position
		to.y = 0.0
		face = to
		if to.length() > 1.9:
			dir = to.normalized()
		elif attack_cd <= 0.0:
			attack_cd = 1.0
			target.take_damage(atk + randi_range(-1, 2), self)
			_bump()
	else:
		var to_o := owner_node.global_position - global_position
		to_o.y = 0.0
		var d := to_o.length()
		if d > 30.0:
			global_position = owner_node.global_position + Vector3(1.5, 0.2, 1.5)
		elif d > 3.5:
			dir = to_o.normalized()
			face = to_o
			if d > 8.0:
				spd = speed * 1.5

	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= 25.0 * delta
	move_and_slide()

	if face.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-face.x, -face.z), 10.0 * delta)


func _pick_target() -> void:
	if not is_instance_valid(target) or target.is_dead:
		target = null
	if target != null and owner_node.global_position.distance_to(target.global_position) > 14.0:
		target = null
	if target != null:
		return

	# Помогаем бить цель хозяина
	var lt = owner_node.last_target
	if is_instance_valid(lt) and lt.is_dead == false:
		if owner_node.global_position.distance_to(lt.global_position) < 14.0:
			target = lt
			return

	# Защищаем хозяина и себя
	for n in get_tree().get_nodes_in_group("mobs"):
		var m := n as Mob
		if m == null or m.is_dead:
			continue
		if m.target == owner_node or m.target == self:
			if owner_node.global_position.distance_to(m.global_position) < 10.0:
				target = m
				return


func take_damage(amount: int, _attacker: Node3D) -> void:
	if is_down:
		return
	hp -= amount
	Util.float_text(get_parent(), global_position + Vector3(0, 2.2 * body_scale, 0), str(amount), Color(1, 0.5, 0.3))
	if hp <= 0:
		hp = 0
		is_down = true
		down_timer = 10.0
		target = null
		_model.visible = false
		_label.visible = false
		owner_node.message.emit("%s обессилел и вернётся через 10 с" % pet_name)
	_update_label()
	stats_changed.emit()


func gain_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_next:
		xp -= xp_next
		level += 1
		xp_next = int(xp_next * 1.4)
		max_hp += 12
		hp = max_hp
		atk += 2
		owner_node.message.emit("Питомец достиг уровня %d!" % level)
	_update_label()
	stats_changed.emit()


func _bump() -> void:
	var t := create_tween()
	t.tween_property(_model, "scale", Vector3(1.15, 0.9, 1.15), 0.06)
	t.tween_property(_model, "scale", Vector3.ONE, 0.1)


func _update_label() -> void:
	_label.text = "%s  Ур.%d\n%d/%d" % [pet_name, level, hp, max_hp]
