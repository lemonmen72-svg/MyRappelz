class_name Mob
extends CharacterBody3D
## Дикий зверь: бродит около дома, нападает на игрока рядом, уходит домой с лечением.
## Модели видов строит CreatureModels. Метка приручения (Taming) видна кольцом и кристаллом над головой.
## Уникальный каменный страж раз в несколько секунд бьёт по площади (с замахом).

## killed = true: зверя убили, false: его забрали из мира (consume)
signal gone(mob: Mob, killed: bool)

## Удар по площади каменного стража: перезарядка, замах, радиус, множитель атаки.
## Дальше этого расстояния от игрока зверь «спит»: не думает, не анимируется и не рисуется.
const SLEEP_DIST := 55.0
const SLAM_CD := 8.0
const SLAM_WINDUP := 0.9
const SLAM_RADIUS := 4.5
const SLAM_POWER := 1.3

var slot := -1
var type_id := "boar"
var rarity := "common"
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
## Оглушение: зверь не двигается и не атакует, пока > 0.
var stun_time := 0.0
## Провокация: пока > 0, зверь не меняет цель (танк-питомец, умения).
var taunt_time := 0.0
var returning := false
var target: Node3D = null
## На звере метка приручения (ставит и снимает Taming).
var tame_marked := false
## Сколько раз зверь применил своё умение (удар по площади стража).
var skill_uses := 0

var _wander_to := Vector3.ZERO
var _wander_wait := 0.0
var _regen_acc := 0.0
var _mat: Material
var _label: Label3D
var _model: Node3D
var _height := 1.4
var _anim_t := 0.0
var _mark: Node3D = null
var _mark_gem: Node3D = null
var _slam_cd := 4.0
var _slam_windup := 0.0
var _asleep := false
var _sleep_check := 0.0


## lvl > 0: уровень из зоны острова (характеристики и опыт масштабируются от базового уровня вида).
func setup(id: String, spawn_slot: int, pos: Vector3, lvl: int = -1) -> void:
	var d := MobData.get_type(id)
	type_id = id if MobData.TYPES.has(id) else "boar"
	rarity = d["rarity"]
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
	if lvl > 0 and lvl != level:
		var f := maxf(0.5, 1.0 + 0.25 * float(lvl - level))
		max_hp = maxi(1, roundi(float(max_hp) * f))
		hp = max_hp
		atk = maxi(1, roundi(float(atk) * f))
		xp_reward = maxi(1, roundi(float(xp_reward) * f))
		level = lvl
	home = pos
	position = pos


func _ready() -> void:
	add_to_group("mobs")
	collision_layer = 2
	collision_mask = 1
	_model = Node3D.new()
	add_child(_model)
	_mat = CreatureModels.build(_model, type_id, color, body_scale)
	CreatureModels.add_collision(self, type_id, body_scale)
	_height = CreatureModels.height(type_id, body_scale)
	_anim_t = randf() * 10.0

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.pixel_size = 0.01
	_label.font_size = 40
	_label.outline_size = 10
	_label.position = Vector3(0, _height + 0.35, 0)
	match rarity:
		"rare":
			_label.modulate = Color(0.6, 0.85, 1.0)
		"unique":
			_label.modulate = Color(1.0, 0.8, 0.3)
	add_child(_label)
	_wander_to = home
	_update_label()


func _target_gone() -> bool:
	if not is_instance_valid(target):
		return true
	if target.get("is_down") == true:
		return true
	return false


## Раз в 0.5 с: далеко ли игрок. Зверь в погоне или по пути домой не засыпает.
func _update_sleep(delta: float) -> void:
	_sleep_check -= delta
	if _sleep_check > 0.0:
		return
	_sleep_check = 0.5
	var far := false
	if target == null and not returning and not tame_marked:
		var p := get_tree().get_first_node_in_group("player") as Node3D
		if p != null:
			far = global_position.distance_squared_to(p.global_position) > SLEEP_DIST * SLEEP_DIST
	if far != _asleep:
		_asleep = far
		visible = not far


func _process(delta: float) -> void:
	if is_dead:
		return
	_update_sleep(delta)
	if _asleep:
		return
	_anim_t += delta
	var hv := Vector2(velocity.x, velocity.z).length()
	CreatureModels.animate(_model, type_id, _anim_t, clampf(hv / maxf(speed, 0.1), 0.0, 1.0))
	if _mark != null and _mark.visible:
		_mark.rotation.y += delta * 1.5
		_mark_gem.position.y = _height + 0.9 + sin(_anim_t * 3.0) * 0.12
		_mark_gem.rotation.y += delta * 2.5


func _physics_process(delta: float) -> void:
	if is_dead or _asleep:
		return
	attack_cd = maxf(0.0, attack_cd - delta)
	taunt_time = maxf(0.0, taunt_time - delta)
	if type_id == "golem":
		_slam_cd = maxf(0.0, _slam_cd - delta)
	if stun_time > 0.0:
		stun_time -= delta
		_slam_windup = 0.0
		return

	if target != null and _target_gone():
		target = null
		_slam_windup = 0.0

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
		if global_position.distance_to(home) > leash or _in_safe_zone(target):
			target = null
			returning = true
			_slam_windup = 0.0
		elif _slam_windup > 0.0:
			# Замах удара по площади: стоит на месте
			_slam_windup -= delta
			if _slam_windup <= 0.0:
				_slam()
		elif type_id == "golem" and _slam_cd <= 0.0 and to.length() < SLAM_RADIUS - 0.5:
			_slam_windup = SLAM_WINDUP
			_slam_cd = SLAM_CD
			CreatureModels.spawn_ring(get_parent(), global_position, SLAM_RADIUS, Color(1.0, 0.45, 0.2), SLAM_WINDUP)
			if _model != null:
				var wt := create_tween()
				wt.tween_property(_model, "scale", Vector3(0.92, 1.12, 0.92), SLAM_WINDUP * 0.8)
				wt.tween_property(_model, "scale", Vector3.ONE, 0.1)
		elif to.length() > _reach():
			dir = to.normalized()
		elif attack_cd <= 0.0:
			attack_cd = 1.3
			target.call("take_damage", atk + randi_range(-1, 2), self)
	else:
		# Ищем игрока
		var p := get_tree().get_first_node_in_group("player") as Node3D
		if p != null and global_position.distance_to(p.global_position) < aggro_range and not _in_safe_zone(p):
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
	var prev := global_position
	move_and_slide()
	IslandWorld.constrain(self, prev)

	if face.length() < 0.01:
		face = dir
	if face.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-face.x, -face.z), 8.0 * delta)


## Дальность ближней атаки: крупные звери достают дальше.
func _reach() -> float:
	return maxf(1.9, 1.0 + 0.7 * body_scale)


## Удар по площади каменного стража: урон игроку и питомцам вокруг.
func _slam() -> void:
	skill_uses += 1
	var dmg := int(atk * SLAM_POWER)
	var parent := get_parent()
	CreatureModels.spawn_ring(parent, global_position, SLAM_RADIUS, Color(0.9, 0.75, 0.5), 0.35)
	Vfx.death_puff(parent, global_position + Vector3(0, 0.3, 0), 1.6)
	Vfx.magic_burst(parent, global_position + Vector3(0, 0.4, 0), Color(1.0, 0.65, 0.3), SLAM_RADIUS * 0.6, 0.35)
	Util.float_text(parent, global_position + Vector3(0, _height + 0.8, 0), "Сотрясение!", Color(1, 0.6, 0.3))
	for g in ["player", "pets"]:
		for n in get_tree().get_nodes_in_group(g):
			var node := n as Node3D
			if node == null or not is_instance_valid(node) or node.get("is_down") == true:
				continue
			if node.global_position.distance_to(global_position) <= SLAM_RADIUS:
				node.call("take_damage", dmg, self)


## Оглушить на sec секунд.
func stun(sec: float) -> void:
	stun_time = maxf(stun_time, sec)


## Заставить атаковать by в течение sec секунд.
func taunt(by: Node3D, sec: float) -> void:
	if is_dead or returning:
		return
	target = by
	taunt_time = sec


## Показать или убрать метку приручения (светящееся кольцо под зверем и кристалл над головой).
func set_tame_mark(on: bool) -> void:
	var was := tame_marked
	tame_marked = on
	if on and _mark == null:
		_build_mark()
	if _mark != null:
		_mark.visible = on
	if on and not was and is_inside_tree():
		Vfx.magic_burst(get_parent(), global_position + Vector3(0, _height * 0.5, 0), Vfx.TAME, 0.9 * maxf(body_scale, 0.8), 0.35)


## Метка приручения: светящийся круг с рунным кольцом под зверем и кристалл души над головой.
func _build_mark() -> void:
	var c := Vfx.TAME
	_mark = Node3D.new()
	add_child(_mark)
	var r := 0.85 * maxf(body_scale, 0.8)
	var disk := MeshInstance3D.new()
	disk.set_meta("no_outline", true)
	disk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disk.mesh = Vfx._plane()
	disk.material_override = Vfx.fx_mat(Color(c, 0.85), Vfx.tex("ring"), true)
	disk.scale = Vector3.ONE * r / 0.82
	disk.position.y = 0.06
	_mark.add_child(disk)
	var ring := MeshInstance3D.new()
	ring.set_meta("no_outline", true)
	var tm := TorusMesh.new()
	tm.inner_radius = r * 0.62
	tm.outer_radius = r * 0.62 + 0.05
	tm.rings = 24
	tm.ring_segments = 6
	ring.mesh = tm
	ring.position.y = 0.07
	ring.material_override = Vfx.fx_mat(Color(c, 0.7), null, true)
	_mark.add_child(ring)
	# Кристалл души: два конуса (ромб) и мягкое сияние
	_mark_gem = Node3D.new()
	_mark_gem.position.y = _height + 0.9
	_mark.add_child(_mark_gem)
	var gm := CreatureModels.flat_mat(c.lightened(0.25))
	for i in 2:
		var gem := MeshInstance3D.new()
		gem.set_meta("no_outline", true)
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.16
		cm.height = 0.22 if i == 0 else 0.14
		cm.radial_segments = 6
		cm.rings = 1
		gem.mesh = cm
		gem.position.y = 0.11 if i == 0 else -0.07
		if i == 1:
			gem.rotation.x = PI
		gem.material_override = gm
		_mark_gem.add_child(gem)
	var glow := MeshInstance3D.new()
	glow.set_meta("no_outline", true)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.mesh = Vfx._quad()
	glow.material_override = Vfx.fx_mat(Color(c, 0.55), Vfx.tex("star"), true, BaseMaterial3D.BILLBOARD_ENABLED)
	glow.scale = Vector3.ONE * 0.9
	_mark_gem.add_child(glow)


func _in_safe_zone(n: Node3D) -> bool:
	if IslandWorld.current != null:
		return IslandWorld.current.in_safe_zone(n.global_position)
	return Vector2(n.global_position.x, n.global_position.z).length() < MobData.SAFE_RADIUS


func _heal(delta: float, frac_per_sec: float) -> void:
	if hp >= max_hp:
		return
	_regen_acc += delta * max_hp * frac_per_sec
	if _regen_acc >= 1.0:
		var h := int(_regen_acc)
		hp = mini(max_hp, hp + h)
		_regen_acc -= h
		_update_label()


## crit: критический удар (крупные цифры и яркая вспышка), только для вида.
func take_damage(amount: int, attacker: Node3D, crit: bool = false) -> void:
	if is_dead:
		return
	hp -= amount
	if not returning and attacker != null and taunt_time <= 0.0:
		target = attacker
	var parent := get_parent()
	var num_c := Color(1.0, 0.85, 0.25) if crit else Color(1, 1, 1)
	Util.float_text(parent, global_position + Vector3(0, _height + 0.6, 0), str(amount), num_c, 1.5 if crit else 1.0)
	Vfx.hit_spark(parent, global_position + Vector3(0, _height * 0.55, 0),
		Color(1.0, 0.75, 0.25) if crit else Color(1.0, 0.92, 0.6), (1.4 if crit else 0.9) * clampf(body_scale, 0.7, 1.6))
	_flash()
	_update_label()
	if hp <= 0:
		_die()


func _die() -> void:
	is_dead = true
	remove_from_group("mobs")
	collision_layer = 0
	_label.hide()
	if _mark != null:
		_mark.hide()
	gone.emit(self, true)
	Vfx.death_puff(get_parent(), global_position + Vector3(0, _height * 0.4, 0), clampf(body_scale, 0.7, 2.0))
	var t := create_tween()
	t.tween_property(self, "scale", Vector3(1.2, 0.8, 1.2), 0.08)
	t.tween_property(self, "scale", Vector3(0.2, 1.3, 0.2), 0.12)
	t.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.2)
	t.tween_callback(queue_free)


## Убрать зверя из мира без убийства.
func consume() -> void:
	is_dead = true
	remove_from_group("mobs")
	gone.emit(self, false)
	queue_free()


func _flash() -> void:
	CreatureModels.flash(self, _mat)
	# Модель «сплющивается» от удара и пружинит обратно
	if _model != null:
		var sq := create_tween()
		sq.tween_property(_model, "scale", Vector3(1.12, 0.86, 1.12), 0.05)
		sq.tween_property(_model, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_label() -> void:
	_label.text = "%s  Ур.%d\n%d/%d" % [mob_name, level, hp, max_hp]
