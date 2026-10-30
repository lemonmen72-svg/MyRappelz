class_name Player
extends CharacterBody3D
## Персонаж игрока. Уровень, опыт и золото хранятся в Game, характеристики считаются из ClassData.
## Атака по типу класса: ближний бой (melee), лук (ranged) и магия (magic) — снаряд Projectile.
## Умения класса (кнопки "skill1"/"skill2"), временные усиления. Внешний вид — CharacterModel.

signal stats_changed
signal message(text: String)
## Сменилась цель (Mob или null) — для панели цели в HUD.
signal target_changed(target: Node3D)

const CRIT_MULT := 1.8
## Умения ближнего боя достают чуть дальше обычной атаки.
const MELEE_SKILL_REACH := 0.6

var max_hp := 100
var hp := 100
## Базовая атака без усилений (текущая: cur_atk()).
var atk := 10
var defense := 0
## Базовая скорость без усилений (текущая: cur_speed()).
var speed := 6.5
var attack_range := 2.8
var attack_time := 0.8
var crit := 0.05
## "melee" | "ranged" | "magic"
var attack_kind := "melee"
var attack_cd := 0.0
var regen_delay := 0.0
var move_input := Vector2.ZERO
## Последняя атакованная цель: питомец помогает её бить.
var last_target: Node3D = null
## Текущая цель (для панели цели).
var current_target: Mob = null

## Оставшаяся перезарядка умений: id умения → секунды.
var skill_cd: Dictionary = {}
## Временные усиления: оставшееся время (с) и сила (доля).
var atk_buff_time := 0.0
var atk_buff := 0.0
var speed_buff_time := 0.0
var speed_buff := 0.0
var guard_time := 0.0
var guard := 0.0

var _model: CharacterModel
var _weapon_kind := ""
var _guard_fx: MeshInstance3D
var _regen_acc := 0.0
var _last_crit := false


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

	_build_model()


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
	attack_kind = s["attack"]
	hp = mini(hp, max_hp)


## Применить сменившиеся Game.class_id / Game.race_id: характеристики, умения, внешний вид.
func apply_class() -> void:
	recalc_stats()
	hp = max_hp
	skill_cd.clear()
	clear_buffs()
	_build_model()
	stats_changed.emit()


func cur_atk() -> int:
	return roundi(float(atk) * (1.0 + atk_buff))


func cur_speed() -> float:
	return speed * (1.0 + speed_buff)


func _physics_process(delta: float) -> void:
	attack_cd = maxf(0.0, attack_cd - delta)
	regen_delay = maxf(0.0, regen_delay - delta)
	_tick_skills(delta)

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
	var spd := cur_speed()
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= 25.0 * delta
	var prev := global_position
	move_and_slide()
	# Остров: в воду и на крутые склоны не заходим, сквозь землю не проваливаемся
	IslandWorld.constrain(self, prev)

	if dir.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 12.0 * delta)
	if _has_model():
		_model.set_move_speed(Vector2(velocity.x, velocity.z).length())


func _tick_skills(delta: float) -> void:
	for k in skill_cd.keys():
		skill_cd[k] = maxf(0.0, float(skill_cd[k]) - delta)
	if atk_buff_time > 0.0:
		atk_buff_time -= delta
		if atk_buff_time <= 0.0:
			atk_buff_time = 0.0
			atk_buff = 0.0
			stats_changed.emit()
	if speed_buff_time > 0.0:
		speed_buff_time -= delta
		if speed_buff_time <= 0.0:
			speed_buff_time = 0.0
			speed_buff = 0.0
			stats_changed.emit()
	if guard_time > 0.0:
		guard_time -= delta
		if guard_time <= 0.0:
			guard_time = 0.0
			guard = 0.0
			_update_guard_fx()
			stats_changed.emit()


func clear_buffs() -> void:
	atk_buff_time = 0.0
	atk_buff = 0.0
	speed_buff_time = 0.0
	speed_buff = 0.0
	guard_time = 0.0
	guard = 0.0
	_update_guard_fx()


# ---------- Атака ----------

## Обычная атака по цели. true, если удар/выстрел состоялся.
func try_attack() -> bool:
	if attack_cd > 0.0:
		return false
	var target := _find_target(attack_range)
	if target == null:
		return false
	attack_cd = attack_time
	_engage(target)
	var dmg := _roll(1.0, false)
	_anim_attack()
	if attack_kind == "melee":
		_deal(target, dmg)
		Vfx.slash_arc(get_parent(), target.global_position + Vector3(0, 0.75 * target.body_scale, 0),
			target.global_position - global_position, _class_color())
	else:
		_shoot(target, dmg, 1.0, Callable())
	return true


## Выбрать цель вручную (касание по зверю и т. п.).
func select_target(t: Mob) -> void:
	_set_target(t)


## Цель: текущая, если жива и в радиусе r, иначе ближайший зверь в радиусе r.
func _find_target(r: float) -> Mob:
	if current_target != null and is_instance_valid(current_target) and not current_target.is_dead:
		if global_position.distance_to(current_target.global_position) <= r:
			return current_target
	return Util.nearest(self, "mobs", r) as Mob


func _engage(t: Mob) -> void:
	last_target = t
	_set_target(t)
	_face(t.global_position)


func _face(pos: Vector3) -> void:
	var to := pos - global_position
	if Vector2(to.x, to.z).length() > 0.01:
		rotation.y = atan2(-to.x, -to.z)


func _forward() -> Vector3:
	return -global_transform.basis.z


## Урон с разбросом и критом. mult: множитель атаки. Результат крита — в _last_crit.
func _roll(mult: float, force_crit: bool) -> int:
	var base := float(cur_atk()) * mult + float(randi_range(-2, 3))
	_last_crit = force_crit or randf() < crit
	if _last_crit:
		base *= CRIT_MULT
	return maxi(1, int(base))


func _deal(t: Mob, dmg: int) -> void:
	var crit_hit := _last_crit
	t.take_damage(dmg, self, crit_hit)
	if crit_hit:
		Util.float_text(get_parent(), t.global_position + Vector3(0, 2.6 * t.body_scale + 0.4, 0),
			"Крит!", Color(1, 0.85, 0.2), 1.4)


## Выпустить снаряд (стрела у лучника, шар у мага). on_hit: func(target: Mob, damage: int).
func _shoot(t: Mob, dmg: int, size: float, on_hit: Callable) -> void:
	var p := Projectile.new()
	var k := "arrow" if attack_kind == "ranged" else "orb"
	p.setup(t, self, dmg, _last_crit, k, _class_color(), size)
	p.on_hit = on_hit
	get_parent().add_child(p)
	p.global_position = global_position + Vector3(0, 1.25, 0) + _forward() * 0.6
	var aim := t.global_position + Vector3(0, 0.75 * t.body_scale, 0)
	if k == "arrow" and Vector2(aim.x - p.global_position.x, aim.z - p.global_position.z).length() > 0.05:
		p.look_at(aim, Vector3.UP)


func _class_color() -> Color:
	var c: Color = ClassData.cls(Game.class_id)["color"]
	return c


# ---------- Умения ----------

## id умения по кнопке "skill1"/"skill2" (или сам id умения).
func skill_id(slot: String) -> String:
	var skills: Array = ClassData.cls(Game.class_id)["skills"]
	if slot == "skill1" and skills.size() > 0:
		return String(skills[0])
	if slot == "skill2" and skills.size() > 1:
		return String(skills[1])
	return slot


## Умение по кнопке "skill1"/"skill2" (или по id). true, если применено.
func use_skill(slot: String) -> bool:
	var sid := skill_id(slot)
	var sk := ClassData.skill(sid)
	if sk.is_empty():
		return false
	var left: float = skill_cd.get(sid, 0.0)
	if left > 0.0:
		message.emit("«%s» перезаряжается: %.1f с" % [String(sk["name"]), left])
		return false
	if not _cast(sid, sk):
		return false
	skill_cd[sid] = float(sk["cd"])
	stats_changed.emit()
	return true


## Доля оставшейся перезарядки умения "skill1"/"skill2": 0 = готово, 1 = только что использовано.
func cooldown_frac(slot: String) -> float:
	var sid := skill_id(slot)
	var sk := ClassData.skill(sid)
	if sk.is_empty():
		return 0.0
	var total: float = sk["cd"]
	var left: float = skill_cd.get(sid, 0.0)
	if total <= 0.0:
		return 0.0
	return clampf(left / total, 0.0, 1.0)


func _cast(sid: String, sk: Dictionary) -> bool:
	var sname: String = sk["name"]
	var mult: float = sk.get("mult", 1.0)
	var radius: float = sk.get("radius", 0.0)
	var time: float = sk.get("time", 0.0)
	var value: float = sk.get("value", 0.0)
	var fx_parent := get_parent()
	match sid:
		"cleave":
			var hits := _mobs_around(global_position, radius)
			if hits.is_empty():
				return _no_target()
			var main_t := _find_target(radius)
			if main_t == null:
				main_t = hits[0]
			_engage(main_t)
			_anim_spin()
			for m in hits:
				_deal(m, _roll(mult, false))
			Vfx.slash_arc(fx_parent, global_position + Vector3(0, 0.9, 0) + _forward() * radius * 0.5,
				_forward(), Color(1, 0.6, 0.3), radius * 0.8)
			Projectile.burst(fx_parent, global_position + Vector3(0, 0.5, 0), Color(1, 0.55, 0.25), radius, 0.3)
			_announce(sname, "урон по %d врагам" % hits.size())
		"war_cry":
			atk_buff = value
			atk_buff_time = time
			_anim_buff()
			Projectile.burst(fx_parent, global_position + Vector3(0, 1.0, 0), Color(1, 0.3, 0.2), 2.5, 0.4)
			_announce(sname, "атака +%d%% на %d с" % [roundi(value * 100.0), roundi(time)])
		"power_shot":
			var t := _find_target(attack_range)
			if t == null:
				return _no_target()
			_engage(t)
			_anim_attack()
			_shoot(t, _roll(mult, false), 1.6, Callable())
			_announce(sname, "")
		"quick_step":
			speed_buff = value
			speed_buff_time = time
			_anim_buff()
			Projectile.burst(fx_parent, global_position + Vector3(0, 0.3, 0), Color(0.5, 1, 0.6), 1.8, 0.3)
			_announce(sname, "скорость +%d%% на %d с" % [roundi(value * 100.0), roundi(time)])
		"shield_bash":
			var t := _find_target(attack_range + MELEE_SKILL_REACH)
			if t == null:
				return _no_target()
			_engage(t)
			_anim_bash()
			_deal(t, _roll(mult, false))
			Vfx.hit_spark(fx_parent, t.global_position + Vector3(0, 0.75 * t.body_scale, 0), Color(1, 1, 0.5), 1.5)
			if not t.is_dead:
				t.stun(time)
				Util.float_text(fx_parent, t.global_position + Vector3(0, 2.4 * t.body_scale + 0.8, 0),
					"Оглушён!", Color(1, 1, 0.5))
			_announce(sname, "")
		"holy_guard":
			guard = value
			guard_time = time
			_update_guard_fx()
			_anim_buff()
			_announce(sname, "урон −%d%% на %d с" % [roundi(value * 100.0), roundi(time)])
		"holy_bolt":
			var t := _find_target(attack_range)
			if t == null:
				return _no_target()
			_engage(t)
			_anim_attack()
			_shoot(t, _roll(mult, false), 1.6, Callable())
			_announce(sname, "")
		"heal":
			heal(maxi(1, int(float(max_hp) * value)))
			var pet := _active_pet()
			var extra := ""
			if pet != null and pet.has_method("heal"):
				var pmax: int = int(pet.get("max_hp"))
				pet.call("heal", maxi(1, int(float(pmax) * value)))
				Projectile.burst(fx_parent, pet.global_position + Vector3(0, 0.8, 0), Color(0.5, 1, 0.5), 1.4, 0.4)
				extra = "вы и питомец"
			_anim_attack()
			Projectile.burst(fx_parent, global_position + Vector3(0, 1.0, 0), Color(0.5, 1, 0.5), 1.6, 0.4)
			_announce(sname, extra)
		"backstab":
			var t := _find_target(attack_range + MELEE_SKILL_REACH)
			if t == null:
				return _no_target()
			_engage(t)
			_anim_bash()
			_deal(t, _roll(mult, true))
			Vfx.slash_arc(fx_parent, t.global_position + Vector3(0, 0.75 * t.body_scale, 0),
				t.global_position - global_position, Color(0.75, 0.4, 1.0), 1.2)
			_announce(sname, "")
		"shadow_step":
			var t := _find_target(radius)
			if t == null:
				return _no_target()
			var away := global_position - t.global_position
			away.y = 0.0
			if away.length() < 0.01:
				away = Vector3(0, 0, 1)
			var dest := t.global_position + away.normalized() * 1.5
			dest.y = global_position.y
			Projectile.burst(fx_parent, global_position + Vector3(0, 1.0, 0), Color(0.3, 0.1, 0.4), 1.2, 0.3)
			global_position = dest
			velocity = Vector3.ZERO
			_engage(t)
			_anim_buff()
			Projectile.burst(fx_parent, global_position + Vector3(0, 1.0, 0), Color(0.5, 0.2, 0.7), 1.2, 0.3)
			_announce(sname, "")
		"dark_burst":
			var t := _find_target(attack_range)
			if t == null:
				return _no_target()
			_engage(t)
			_anim_attack()
			var cb := func(hit: Mob, _dealt: int) -> void:
				_explode(hit, radius, mult)
			_shoot(t, _roll(mult, false), 1.9, cb)
			_announce(sname, "")
		"drain":
			var t := _find_target(attack_range)
			if t == null:
				return _no_target()
			_engage(t)
			_anim_attack()
			var cb := func(_hit: Mob, dealt: int) -> void:
				heal(maxi(1, int(float(dealt) * value)))
			_shoot(t, _roll(mult, false), 1.4, cb)
			_announce(sname, "")
		_:
			return false
	return true


## Взрыв тьмы: урон всем зверям вокруг center_mob, кроме него самого (он уже получил урон снарядом).
func _explode(center_mob: Mob, radius: float, mult: float) -> void:
	var center := center_mob.global_position
	Projectile.burst(get_parent(), center + Vector3(0, 0.6, 0), _class_color(), radius, 0.4)
	for m in _mobs_around(center, radius):
		if m == center_mob:
			continue
		_deal(m, _roll(mult, false))


func _mobs_around(center: Vector3, r: float) -> Array[Mob]:
	var res: Array[Mob] = []
	for n in get_tree().get_nodes_in_group("mobs"):
		var m := n as Mob
		if m != null and not m.is_dead and m.global_position.distance_to(center) <= r:
			res.append(m)
	return res


func _no_target() -> bool:
	message.emit("Нет цели рядом")
	return false


func _announce(sname: String, extra: String) -> void:
	message.emit(sname if extra == "" else "%s: %s" % [sname, extra])
	Util.float_text(get_parent(), global_position + Vector3(0, 2.9, 0), sname, Color(1, 0.85, 0.4))


## Призванный питомец (узел с полями hp, max_hp, is_down и методом heal) или null.
func _active_pet() -> Node3D:
	var parent := get_parent()
	if parent == null:
		return null
	var mgr: Variant = parent.get("pets")
	if not is_instance_valid(mgr):
		return null
	var p: Variant = (mgr as Object).get("active_pet")
	if not is_instance_valid(p):
		return null
	var node := p as Node3D
	if node == null or node.get("is_down") == true:
		return null
	return node


# ---------- Здоровье и опыт ----------

func heal(amount: int) -> void:
	hp = mini(max_hp, hp + amount)
	Util.float_text(get_parent(), global_position + Vector3(0, 2.4, 0), "+%d" % amount, Color(0.4, 1, 0.4))
	Vfx.heal_sparkles(get_parent(), global_position)
	stats_changed.emit()


func _set_target(t: Mob) -> void:
	if t == current_target:
		return
	current_target = t
	target_changed.emit(t)


func take_damage(amount: int, _attacker: Node3D) -> void:
	amount = maxi(1, amount - int(defense * 0.5))
	if guard_time > 0.0:
		amount = maxi(1, roundi(float(amount) * (1.0 - guard)))
	hp -= amount
	regen_delay = 6.0
	if _has_model():
		_model.play_hit()
	Util.float_text(get_parent(), global_position + Vector3(0, 2.4, 0), str(amount), Color(1, 0.3, 0.3))
	Vfx.hit_spark(get_parent(), global_position + Vector3(0, 1.2, 0), Color(1, 0.4, 0.35), 0.8)
	if hp <= 0:
		hp = max_hp
		Game.gold = int(Game.gold * 0.8)
		global_position = respawn_point()
		Vfx.heal_sparkles(get_parent(), global_position, 1.3)
		last_target = null
		_set_target(null)
		clear_buffs()
		# Звери, гнавшиеся за игроком, теряют его и уходят домой
		for n in get_tree().get_nodes_in_group("mobs"):
			var m := n as Mob
			if m != null and m.target == self:
				m.target = null
				m.returning = true
		message.emit("Вы погибли и возродились в центре. Потеряна часть золота.")
		Game.changed.emit()
	stats_changed.emit()


## Где возрождается игрок: точка старта его расы (деревня расы) или центр карты.
func respawn_point() -> Vector3:
	if IslandWorld.current != null:
		return IslandWorld.current.spawn_point(Game.race_id)
	return Vector3(0, 0.1, 0)


func gain_xp(amount: int) -> void:
	Game.xp += amount
	while Game.xp >= Game.xp_to_next(Game.level):
		Game.xp -= Game.xp_to_next(Game.level)
		Game.level += 1
		recalc_stats()
		hp = max_hp
		message.emit("Новый уровень: %d!" % Game.level)
		Vfx.level_up(get_parent(), global_position)
	Game.changed.emit()
	stats_changed.emit()


# ---------- Внешний вид: аниме-модель (CharacterModel) ----------

func _build_model() -> void:
	if _model != null and is_instance_valid(_model):
		_model.queue_free()
	var c := ClassData.cls(Game.class_id)
	_weapon_kind = String(c.get("weapon", "sword"))
	_model = CharacterModel.new()
	_model.name = "Model"
	_model.setup(CharacterModel.spec_for(Game.race_id, Game.class_id))
	add_child(_model)

	# Сияние «Щита света»
	_guard_fx = MeshInstance3D.new()
	var gm := SphereMesh.new()
	gm.radius = 1.05
	gm.height = 2.3
	_guard_fx.mesh = gm
	_guard_fx.position.y = 1.0
	_guard_fx.material_override = Projectile.glow_mat(Color(1, 0.9, 0.45), 0.22)
	_model.add_child(_guard_fx)
	_update_guard_fx()


func _has_model() -> bool:
	return _model != null and is_instance_valid(_model)


## Удар / выстрел / заклинание обычной атаки (вид — по оружию модели).
func _anim_attack() -> void:
	if _has_model():
		_model.play_attack()


## Круговой удар (Рассечение): оборот всей модели.
func _anim_spin() -> void:
	if _has_model():
		_model.play_spin()


## Удар щитом: выпад левой рукой.
func _anim_bash() -> void:
	if _has_model():
		_model.play_bash()


## Усиление на себя: руки вверх.
func _anim_buff() -> void:
	if _has_model():
		_model.play_buff()


func _update_guard_fx() -> void:
	if _guard_fx != null and is_instance_valid(_guard_fx):
		_guard_fx.visible = guard_time > 0.0
