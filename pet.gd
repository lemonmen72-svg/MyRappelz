class_name Pet
extends CharacterBody3D
## Призванный питомец. Строится из записи коллекции Game.pets: record — тот же словарь,
## поэтому HP, уровень, опыт и имя сразу попадают в коллекцию и сохраняются.
## Характеристики, вид, цвет, размер и имя — из PetData по виду и уровню (стадии на 1 / 15 / 30 ур.).
## Поведение по роли: танк провоцирует зверей, напавших на хозяина; боец делает рывок;
## маг стреляет снарядами и бьёт по площади; лекарь лечит хозяина и слабо стреляет.
## Режимы: "assist" (бьёт цель хозяина и защищает), "follow" (только идёт следом),
## "attack" (атакует заданную цель, после её смерти — снова "assist").
## Контракт (HUD, модуль боя): pet_name, level, hp, max_hp, is_down, heal(amount), stats_changed.

signal stats_changed
## Питомец погиб: запись уже помечена dead = true.
signal died

## Дальше этого от хозяина питомец бросает цель (режим "assist").
const LEASH := 14.0
## Радиус защиты хозяина.
const DEFEND_RANGE := 10.0
## Отстал дальше — переносится к хозяину.
const TELEPORT_DIST := 30.0
const FOLLOW_DIST := 3.0
## Лекарь лечит хозяина не дальше этого.
const HEAL_RANGE := 15.0

var record: Dictionary = {}
var species := "boar"
var role := "fighter"
var pet_name := "Питомец"
var level := 1
var xp := 0
## Стадия эволюции: 0, 1, 2.
var stage := 0
var max_hp := 50
var hp := 50
var atk := 6
var defense := 0
var speed := 6.0
var attack_range := 1.9
var attack_time := 1.0
## Погиб или отозван (зверям пора искать другую цель).
var is_down := false
var mode := "assist"
var target: Mob = null
var owner_node: Player
var attack_cd := 0.0
var skill_cd := 0.0
## Сколько раз сработало умение роли.
var skill_uses := 0

var _model: Node3D = null
var _col: CollisionShape3D = null
var _mat: StandardMaterial3D = null
var _label: Label3D = null
var _color := Color.WHITE
var _scale := 1.0
var _height := 1.4
var _anim_t := 0.0
var _dash_time := 0.0
var _calm := 0.0
var _regen_acc := 0.0


## Вызывать до добавления в сцену. rec — запись из Game.pets (не копия).
func setup(owner_p: Player, rec: Dictionary) -> void:
	owner_node = owner_p
	record = rec
	species = String(rec.get("species", "boar"))
	if not PetData.SPECIES.has(species):
		species = "boar"
	role = PetData.role(species)
	level = clampi(int(rec.get("level", 1)), 1, PetData.MAX_LEVEL)
	xp = maxi(0, int(rec.get("xp", 0)))
	_apply_stats()
	var saved := int(rec.get("hp", -1))
	hp = max_hp if saved < 0 else clampi(saved, 1, max_hp)
	pet_name = PetData.stage_name(species, level)
	_write_record()


func _ready() -> void:
	add_to_group("pets")
	collision_layer = 2
	collision_mask = 1
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.pixel_size = 0.01
	_label.font_size = 40
	_label.outline_size = 10
	_label.modulate = Color(0.6, 0.9, 1.0)
	add_child(_label)
	_build_model()
	_update_label()


## Атаковать заданного зверя (команда «Атакуй»).
func command_attack(m: Mob) -> void:
	if is_down or not is_instance_valid(m) or m.is_dead:
		return
	mode = "attack"
	target = m


## "assist" | "follow" | "attack".
func set_mode(m: String) -> void:
	mode = m
	if m == "follow":
		target = null
		_dash_time = 0.0


func _process(delta: float) -> void:
	if is_down or _model == null:
		return
	_anim_t += delta
	CreatureModels.animate(_model, species, _anim_t)


func _physics_process(delta: float) -> void:
	if is_down or not is_instance_valid(owner_node):
		return
	attack_cd = maxf(0.0, attack_cd - delta)
	skill_cd = maxf(0.0, skill_cd - delta)
	_calm += delta

	var to_o := owner_node.global_position - global_position
	to_o.y = 0.0
	if to_o.length() > TELEPORT_DIST:
		_teleport_to_owner()
		return

	_pick_target()
	_role_support()

	var dir := Vector3.ZERO
	var face := Vector3.ZERO
	var spd := speed

	if target != null:
		var to := target.global_position - global_position
		to.y = 0.0
		face = to
		var dist := to.length()
		var reach := attack_range + 0.35 * target.body_scale
		if _dash_time <= 0.0 and _can_dash(dist, reach):
			_start_dash()
		if _dash_time > 0.0:
			_dash_time -= delta
			if dist <= reach:
				_dash_time = 0.0
				_dash_hit(target)
			else:
				dir = to.normalized()
				spd = speed * 3.5
		elif dist > reach:
			dir = to.normalized()
		elif attack_cd <= 0.0:
			attack_cd = attack_time
			_attack(target)
	else:
		_dash_time = 0.0
		var d := to_o.length()
		if d > FOLLOW_DIST:
			dir = to_o.normalized()
			face = to_o
			if d > 8.0:
				spd = speed * 1.5
		_regen(delta)

	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= 25.0 * delta
	move_and_slide()

	if face.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-face.x, -face.z), 10.0 * delta)


# ---------- Цель ----------

func _pick_target() -> void:
	if not is_instance_valid(target) or target.is_dead or target.returning:
		target = null
		if mode == "attack":
			mode = "assist"
	if mode == "follow":
		target = null
		return
	if target != null and mode == "assist":
		if owner_node.global_position.distance_to(target.global_position) > LEASH:
			target = null
	if target != null:
		return

	# Помогаем бить цель хозяина
	var lt = owner_node.last_target
	if is_instance_valid(lt) and lt is Mob:
		var lm := lt as Mob
		if not lm.is_dead and not lm.returning and owner_node.global_position.distance_to(lm.global_position) < LEASH:
			target = lm
			return

	# Защищаем хозяина и себя
	for n in get_tree().get_nodes_in_group("mobs"):
		var m := n as Mob
		if m == null or m.is_dead:
			continue
		if m.target != owner_node and m.target != self:
			continue
		if owner_node.global_position.distance_to(m.global_position) < DEFEND_RANGE:
			target = m
			return


# ---------- Атака и умения ----------

func _attack(t: Mob) -> void:
	var dmg := maxi(1, atk + randi_range(-1, 2))
	match role:
		"mage":
			if skill_cd <= 0.0:
				var sk := PetData.skill(species)
				skill_cd = float(sk["cd"])
				skill_uses += 1
				_say_skill(String(sk["name"]))
				_blast(t.global_position, float(sk["radius"]), maxi(1, roundi(atk * float(sk["power"]))))
			else:
				_shoot(t, dmg, Color(1.0, 0.75, 0.3))
		"healer":
			_shoot(t, dmg, Color(0.6, 1.0, 0.7))
		_:
			t.take_damage(dmg, self)
			_bump()


func _can_dash(dist: float, reach: float) -> bool:
	if role != "fighter" or skill_cd > 0.0:
		return false
	var sk := PetData.skill(species)
	return dist > maxf(reach, float(sk["min_dist"])) and dist < float(sk["max_dist"])


func _start_dash() -> void:
	var sk := PetData.skill(species)
	skill_cd = float(sk["cd"])
	skill_uses += 1
	_dash_time = 0.8
	_say_skill(String(sk["name"]))


func _dash_hit(t: Mob) -> void:
	var sk := PetData.skill(species)
	attack_cd = attack_time
	t.take_damage(maxi(1, roundi(atk * float(sk["power"]))), self)
	CreatureModels.spawn_ring(get_parent(), t.global_position, 1.2, Color(1.0, 0.9, 0.5), 0.3)
	_bump()


## Танк провоцирует зверей, напавших на хозяина; лекарь лечит хозяина.
func _role_support() -> void:
	if skill_cd > 0.0:
		return
	match role:
		"tank":
			if mode == "follow":
				return
			var sk := PetData.skill(species)
			var radius := float(sk["radius"])
			var first: Mob = null
			for n in get_tree().get_nodes_in_group("mobs"):
				var m := n as Mob
				if m == null or m.is_dead or m.returning or m.target != owner_node:
					continue
				if m.global_position.distance_to(owner_node.global_position) > radius:
					continue
				m.taunt(self, float(sk["duration"]))
				if first == null:
					first = m
			if first != null:
				skill_cd = float(sk["cd"])
				skill_uses += 1
				_say_skill(String(sk["name"]))
				if target == null:
					target = first
		"healer":
			var sk := PetData.skill(species)
			if owner_node.hp <= 0 or float(owner_node.hp) >= float(owner_node.max_hp) * float(sk["threshold"]):
				return
			if global_position.distance_to(owner_node.global_position) > HEAL_RANGE:
				return
			skill_cd = float(sk["cd"])
			skill_uses += 1
			_say_skill(String(sk["name"]))
			owner_node.heal(maxi(1, roundi(float(owner_node.max_hp) * float(sk["power"])) + atk))
			CreatureModels.spawn_ring(get_parent(), owner_node.global_position, 1.3, Color(0.5, 1.0, 0.6), 0.6)


func _shoot(t: Mob, dmg: int, c: Color) -> void:
	var b := Bolt.new()
	b.target = t
	b.source = self
	b.damage = dmg
	b.color = c
	get_parent().add_child(b)
	b.global_position = global_position + Vector3(0, maxf(0.6, _height * 0.7), 0)
	_bump()


## Удар по площади вокруг center.
func _blast(center: Vector3, radius: float, dmg: int) -> void:
	CreatureModels.spawn_ring(get_parent(), center, radius, Color(1.0, 0.6, 0.2), 0.4)
	for n in get_tree().get_nodes_in_group("mobs"):
		var m := n as Mob
		if m == null or m.is_dead:
			continue
		if m.global_position.distance_to(center) <= radius:
			m.take_damage(dmg, self)


# ---------- Здоровье, опыт ----------

func take_damage(amount: int, attacker: Node3D) -> void:
	if is_down:
		return
	amount = maxi(1, amount - int(defense * 0.5))
	hp -= amount
	_calm = 0.0
	Util.float_text(get_parent(), global_position + Vector3(0, _height + 0.5, 0), str(amount), Color(1, 0.5, 0.3))
	if hp <= 0:
		hp = 0
		_die()
		return
	if mode != "follow" and not is_instance_valid(target) and is_instance_valid(attacker) and attacker is Mob:
		target = attacker as Mob
	_flash()
	_write_record()
	_update_label()
	stats_changed.emit()


func heal(amount: int) -> void:
	if is_down or amount <= 0:
		return
	hp = mini(max_hp, hp + amount)
	if is_inside_tree():
		Util.float_text(get_parent(), global_position + Vector3(0, _height + 0.5, 0), "+%d" % amount, Color(0.4, 1, 0.4))
	_write_record()
	_update_label()
	stats_changed.emit()


func gain_xp(amount: int) -> void:
	if is_down or amount <= 0 or level >= PetData.MAX_LEVEL:
		return
	xp += amount
	var old_stage := stage
	var old_name := pet_name
	var leveled := false
	while level < PetData.MAX_LEVEL and xp >= PetData.xp_to_next(level):
		xp -= PetData.xp_to_next(level)
		level += 1
		leveled = true
	if level >= PetData.MAX_LEVEL:
		xp = 0
	if leveled:
		_apply_stats()
		hp = max_hp
		pet_name = PetData.stage_name(species, level)
		if stage != old_stage:
			_evolve_fx()
			_say("Эволюция! «%s» теперь «%s» (ур. %d)" % [old_name, pet_name, level])
		else:
			_say("Питомец «%s» достиг уровня %d!" % [pet_name, level])
	_write_record()
	_update_label()
	stats_changed.emit()


func _die() -> void:
	is_down = true
	target = null
	_dash_time = 0.0
	record["dead"] = true
	record["hp"] = 0
	record["level"] = level
	record["xp"] = xp
	collision_layer = 0
	visible = false
	remove_from_group("pets")
	if is_inside_tree():
		Util.float_text(get_parent(), global_position + Vector3(0, _height + 0.5, 0), "Погиб", Color(1, 0.4, 0.4))
	_say("Питомец «%s» погиб. Воскресите его свитком в окне «Питомцы»" % pet_name)
	stats_changed.emit()
	died.emit()


func _regen(delta: float) -> void:
	if _calm < 4.0 or hp >= max_hp:
		return
	_regen_acc += delta * max_hp * 0.03
	if _regen_acc >= 1.0:
		var h := int(_regen_acc)
		_regen_acc -= h
		hp = mini(max_hp, hp + h)
		_write_record()
		_update_label()
		stats_changed.emit()


func _apply_stats() -> void:
	var s := PetData.stats_for(species, level)
	max_hp = int(s["max_hp"])
	atk = int(s["atk"])
	defense = int(s["def"])
	speed = float(s["speed"])
	attack_range = float(s["range"])
	attack_time = float(s["cd"])
	stage = PetData.stage_for(level)
	_color = PetData.stage_color(species, level)
	_scale = PetData.stage_scale(species, level)
	hp = mini(hp, max_hp)


## HP, уровень, опыт и имя — в запись коллекции (она же сохраняется).
func _write_record() -> void:
	record["name"] = pet_name
	record["level"] = level
	record["xp"] = xp
	record["hp"] = -1 if hp >= max_hp else hp


func _teleport_to_owner() -> void:
	global_position = owner_node.global_position + Vector3(1.5, 0.2, 1.5)
	target = null
	_dash_time = 0.0


# ---------- Вид ----------

func _build_model() -> void:
	if _model != null:
		_model.queue_free()
	if _col != null:
		_col.queue_free()
	_model = Node3D.new()
	add_child(_model)
	_mat = CreatureModels.build(_model, species, _color, _scale)
	_col = CreatureModels.add_collision(self, species, _scale)
	_height = CreatureModels.height(species, _scale)
	# Голубой круг под ногами: свой питомец, а не дикий зверь
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.45 * _scale + 0.15
	tm.outer_radius = tm.inner_radius + 0.07
	ring.mesh = tm
	ring.position.y = 0.05
	ring.material_override = CreatureModels.flat_mat(Color(0.3, 0.8, 1.0))
	_model.add_child(ring)
	if _label != null:
		_label.position = Vector3(0, _height + 0.35, 0)


func _evolve_fx() -> void:
	if not is_inside_tree():
		return
	_build_model()
	CreatureModels.spawn_ring(get_parent(), global_position, 2.5, Color(1.0, 0.9, 0.4), 0.8)
	Util.float_text(get_parent(), global_position + Vector3(0, _height + 0.8, 0), "Эволюция!", Color(1.0, 0.9, 0.4))


func _say(t: String) -> void:
	if is_instance_valid(owner_node):
		owner_node.message.emit(t)


func _say_skill(skill_name: String) -> void:
	if is_inside_tree():
		Util.float_text(get_parent(), global_position + Vector3(0, _height + 0.8, 0), skill_name + "!", Color(1.0, 0.85, 0.4))


func _bump() -> void:
	if _model == null:
		return
	var t := create_tween()
	t.tween_property(_model, "scale", Vector3(1.12, 0.9, 1.12), 0.06)
	t.tween_property(_model, "scale", Vector3.ONE, 0.1)


func _flash() -> void:
	if _mat == null:
		return
	_mat.albedo_color = Color(1, 1, 1)
	var t := create_tween()
	t.tween_property(_mat, "albedo_color", _color, 0.15)


func _update_label() -> void:
	if _label != null:
		_label.text = "%s  Ур.%d\n%d/%d" % [pet_name, level, hp, max_hp]


## Снаряд мага или лекаря: летит в цель и наносит урон при попадании.
class Bolt extends Node3D:
	var target: Node3D = null
	var source: Node3D = null
	var damage := 1
	var color := Color.WHITE
	var speed := 14.0
	var life := 3.0

	func _ready() -> void:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.18
		sm.height = 0.36
		sm.radial_segments = 12
		sm.rings = 6
		mi.mesh = sm
		mi.material_override = CreatureModels.flat_mat(color)
		add_child(mi)

	func _process(delta: float) -> void:
		life -= delta
		if life <= 0.0 or not is_instance_valid(target) or target.get("is_dead") == true:
			queue_free()
			return
		var aim := target.global_position + Vector3(0, 0.8, 0)
		var to := aim - global_position
		var step := speed * delta
		if to.length() <= step + 0.25:
			var src: Node3D = source if is_instance_valid(source) else null
			target.call("take_damage", damage, src)
			queue_free()
			return
		global_position += to.normalized() * step
