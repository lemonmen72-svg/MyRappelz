class_name Player
extends CharacterBody3D

signal stats_changed
signal message(text: String)

var max_hp := 100
var hp := 100
var atk := 12
var level := 1
var xp := 0
var xp_next := 30
var gold := 0
var speed := 6.5
var attack_range := 2.8
var attack_cd := 0.0
var regen_delay := 0.0
var move_input := Vector2.ZERO
var last_target: Node3D = null

var _weapon: Node3D
var _regen_acc := 0.0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1

	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	col.shape = shape
	col.position.y = 0.9
	add_child(col)

	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.4
	cm.height = 1.8
	mi.mesh = cm
	mi.position.y = 0.9
	mi.material_override = Util.mat(Color(0.2, 0.45, 0.9))
	add_child(mi)

	# "Лицо", чтобы было видно, куда смотрит персонаж
	var face := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.3, 0.15, 0.2)
	face.mesh = fm
	face.position = Vector3(0, 1.45, -0.38)
	face.material_override = Util.mat(Color(0.95, 0.85, 0.7))
	add_child(face)

	# Меч
	_weapon = Node3D.new()
	_weapon.position = Vector3(0.55, 1.0, 0.0)
	_weapon.rotation.x = 1.0
	add_child(_weapon)
	var blade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.08, 0.08, 1.1)
	blade.mesh = bm
	blade.position = Vector3(0, 0, -0.55)
	blade.material_override = Util.mat(Color(0.85, 0.85, 0.9))
	_weapon.add_child(blade)


func _physics_process(delta: float) -> void:
	attack_cd = maxf(0.0, attack_cd - delta)
	regen_delay = maxf(0.0, regen_delay - delta)

	# Регенерация вне боя
	if regen_delay <= 0.0 and hp < max_hp:
		_regen_acc += delta * max_hp * 0.02
		if _regen_acc >= 1.0:
			var h := int(_regen_acc)
			hp = mini(max_hp, hp + h)
			_regen_acc -= h
			stats_changed.emit()

	var dir := Vector3(move_input.x, 0.0, move_input.y)
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= 25.0 * delta
	move_and_slide()

	global_position.x = clampf(global_position.x, -70.0, 70.0)
	global_position.z = clampf(global_position.z, -70.0, 70.0)

	if dir.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 12.0 * delta)


func try_attack() -> void:
	if attack_cd > 0.0:
		return
	var target := Util.nearest(self, "mobs", attack_range) as Mob
	if target == null:
		return
	attack_cd = 0.7
	last_target = target
	var to := target.global_position - global_position
	rotation.y = atan2(-to.x, -to.z)
	_swing()
	target.take_damage(atk + randi_range(-2, 3), self)


func _swing() -> void:
	_weapon.rotation.x = 1.0
	var t := create_tween()
	t.tween_property(_weapon, "rotation:x", -0.7, 0.08)
	t.tween_property(_weapon, "rotation:x", 1.0, 0.18)


func take_damage(amount: int, _attacker: Node3D) -> void:
	hp -= amount
	regen_delay = 6.0
	Util.float_text(get_parent(), global_position + Vector3(0, 2.4, 0), str(amount), Color(1, 0.3, 0.3))
	if hp <= 0:
		hp = max_hp
		gold = int(gold * 0.8)
		global_position = Vector3(0, 0.1, 0)
		last_target = null
		# Звери, гнавшиеся за игроком, теряют его и уходят домой
		for n in get_tree().get_nodes_in_group("mobs"):
			var m := n as Mob
			if m != null and m.target == self:
				m.target = null
				m.returning = true
		message.emit("Вы погибли и возродились в центре. Потеряна часть золота.")
	stats_changed.emit()


func gain_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_next:
		xp -= xp_next
		level += 1
		xp_next = int(xp_next * 1.5)
		max_hp += 20
		hp = max_hp
		atk += 3
		message.emit("Новый уровень: %d!" % level)
	stats_changed.emit()
