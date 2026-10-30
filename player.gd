class_name Player
extends CharacterBody3D
## Персонаж игрока. Уровень, опыт и золото хранятся в Game, характеристики считаются из ClassData.
## Каркас: ближняя атака по ближайшему зверю. Модуль «Персонаж и бой» добавляет классы и умения.

signal stats_changed
signal message(text: String)
## Сменилась цель (Mob или null) — для панели цели в HUD.
signal target_changed(target: Node3D)

var max_hp := 100
var hp := 100
var atk := 10
var defense := 0
var speed := 6.5
var attack_range := 2.8
var attack_time := 0.8
var crit := 0.05
var attack_cd := 0.0
var regen_delay := 0.0
var move_input := Vector2.ZERO
## Последняя атакованная цель: питомец помогает её бить.
var last_target: Node3D = null
## Текущая цель (для панели цели).
var current_target: Mob = null

var _weapon: Node3D
var _regen_acc := 0.0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	recalc_stats()
	hp = max_hp

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
	mi.material_override = Util.mat(ClassData.cls(Game.class_id)["color"])
	add_child(mi)

	# Лицо: цвет кожи расы, видно, куда смотрит персонаж
	var face := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.3, 0.2, 0.2)
	face.mesh = fm
	face.position = Vector3(0, 1.45, -0.38)
	face.material_override = Util.mat(ClassData.race(Game.race_id)["skin"])
	add_child(face)

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


## Пересчитать характеристики из класса и уровня (Game.class_id, Game.level).
func recalc_stats() -> void:
	var s := ClassData.stats_for(Game.class_id, Game.level)
	max_hp = s["max_hp"]
	atk = s["atk"]
	defense = s["def"]
	speed = s["speed"]
	attack_range = s["range"]
	attack_time = s["cd"]
	crit = s["crit"]
	hp = mini(hp, max_hp)


func _physics_process(delta: float) -> void:
	attack_cd = maxf(0.0, attack_cd - delta)
	regen_delay = maxf(0.0, regen_delay - delta)

	if current_target != null and (not is_instance_valid(current_target) or current_target.is_dead):
		_set_target(null)

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
	attack_cd = attack_time
	last_target = target
	_set_target(target)
	var to := target.global_position - global_position
	rotation.y = atan2(-to.x, -to.z)
	_swing()
	var dmg := atk + randi_range(-2, 3)
	if randf() < crit:
		dmg = int(dmg * 1.8)
	target.take_damage(maxi(1, dmg), self)


## Умения "skill1" / "skill2" из ClassData.CLASSES[класс]["skills"].
func use_skill(_id: String) -> void:
	message.emit("Умения: в разработке")


## Доля оставшейся перезарядки умения "skill1"/"skill2": 0 = готово, 1 = только что использовано.
func cooldown_frac(_id: String) -> float:
	return 0.0


func heal(amount: int) -> void:
	hp = mini(max_hp, hp + amount)
	Util.float_text(get_parent(), global_position + Vector3(0, 2.4, 0), "+%d" % amount, Color(0.4, 1, 0.4))
	stats_changed.emit()


func _set_target(t: Mob) -> void:
	if t == current_target:
		return
	current_target = t
	target_changed.emit(t)


func _swing() -> void:
	_weapon.rotation.x = 1.0
	var t := create_tween()
	t.tween_property(_weapon, "rotation:x", -0.7, 0.08)
	t.tween_property(_weapon, "rotation:x", 1.0, 0.18)


func take_damage(amount: int, _attacker: Node3D) -> void:
	amount = maxi(1, amount - int(defense * 0.5))
	hp -= amount
	regen_delay = 6.0
	Util.float_text(get_parent(), global_position + Vector3(0, 2.4, 0), str(amount), Color(1, 0.3, 0.3))
	if hp <= 0:
		hp = max_hp
		Game.gold = int(Game.gold * 0.8)
		global_position = Vector3(0, 0.1, 0)
		last_target = null
		_set_target(null)
		# Звери, гнавшиеся за игроком, теряют его и уходят домой
		for n in get_tree().get_nodes_in_group("mobs"):
			var m := n as Mob
			if m != null and m.target == self:
				m.target = null
				m.returning = true
		message.emit("Вы погибли и возродились в центре. Потеряна часть золота.")
		Game.changed.emit()
	stats_changed.emit()


func gain_xp(amount: int) -> void:
	Game.xp += amount
	while Game.xp >= Game.xp_to_next(Game.level):
		Game.xp -= Game.xp_to_next(Game.level)
		Game.level += 1
		recalc_stats()
		hp = max_hp
		message.emit("Новый уровень: %d!" % Game.level)
	Game.changed.emit()
	stats_changed.emit()
