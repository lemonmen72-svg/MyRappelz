class_name Pet
extends CharacterBody3D
## Призванный питомец. Строится из записи коллекции Game.pets: record — тот же словарь,
## поэтому HP, MP, уровень, опыт, JP, умения и имя сразу попадают в коллекцию и сохраняются.
## Характеристики — PetStats (7 статов по уровню и стадии, производные значения, бонусы умений);
## стадии эволюции на 1 / 15 / 30 ур. Изучаемые умения — PetSkills (окно существа, CreatureWindow).
## Поведение по роли: танк провоцирует зверей, напавших на хозяина; боец делает рывок;
## маг стреляет снарядами и бьёт по площади; лекарь лечит хозяина и слабо стреляет.
## Поверх роли — изученные умения: активные применяет ИИ (вместо обычной атаки, когда перезарядка готова
## и хватает MP; сильные первыми), переключаемые тратят MP каждые 10 с, пассивные — в характеристиках.
## Режимы: "assist" (бьёт цель хозяина и защищает), "follow" (только идёт следом),
## "attack" (атакует заданную цель, после её смерти — снова "assist").
## Контракт (HUD, модуль боя): pet_name, level, hp, max_hp, mp, max_mp, is_down, heal(amount), stats_changed.
## Модель из файла (CreatureAsset: пантера, черепаха, фазан): клипы по скорости, Attack — удар в момент
## удара клипа, Cast — умение, Hit — урон.

signal stats_changed
## Питомец погиб: запись уже помечена dead = true.
signal died

## Дальше этого от хозяина питомец бросает цель (режим "assist").
const LEASH := 14.0
## Радиус защиты хозяина.
const DEFEND_RANGE := 10.0
## Отстал дальше — переносится к хозяину.
const TELEPORT_DIST := 30.0
## Размер подписи над питомцем относительно подписи зверя (Mob: pixel_size UiScale.world_px(0.01)).
const LABEL_PX := 0.62
## Застрял (хочет идти, а за это время сдвинулся меньше STUCK_MOVE м) — переносится к хозяину.
const STUCK_TIME := 1.8
const STUCK_MOVE := 0.6
const FOLLOW_DIST := 3.0
## Лекарь лечит хозяина не дальше этого.
const HEAL_RANGE := 15.0
## Рывок умения-тарана: цель дальше MIN и ближе MAX, м.
const CHARGE_MIN := 3.0
const CHARGE_MAX := 10.0
## Длительность ослаблений зверя от умений (замедление, уязвимость, сбитый прицел), с.
const DEBUFF_TIME := 10.0
## «Песнь рассвета» и т. п. лечат, когда у хозяина или питомца меньше этой доли HP.
const HEAL_SKILL_THRESHOLD := 0.7

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
var max_mp := 30
var mp := 30
## Главная атака роли (маг и лекарь — магическая, танк и боец — физическая), с бонусами умений.
var atk := 6
var defense := 0
## Сила лечения (от Мудрости): прибавка к лечению хозяина.
var heal_power := 1
## Точность (шанс попасть — PetStats.hit_chance), уклонение и крит — в процентах.
var accuracy := 10
var evasion := 0.0
var crit := 3.0
## Восстановление HP (всегда, и в бою) и MP в секунду.
var hp_regen := 0.0
var mp_regen := 1.0
## Шанс, что удар питомца переключит зверя на него («Дерзкий вызов»).
var threat := 0.0
var speed := 6.0
var attack_range := 1.9
var attack_time := 1.0
## Все характеристики (PetStats.derived): 7 статов, маг. атака, защита и т. д. — для окна существа.
var stats: Dictionary = {}
## Изученные умения {id: уровень} и включённые переключаемые {id: true} — словари из записи.
var skills: Dictionary = {}
var toggles: Dictionary = {}
## Действующие эффекты для HUD (значки у полоски HP питомца): включённые переключаемые ("toggle:<id>").
var effects := StatusEffects.new()
## Перезарядки изученных активных умений {id: осталось, с}.
var skill_cds: Dictionary = {}
## Сколько раз применены изученные активные умения.
var learned_uses := 0
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
## Какая модель построена: вид или своя модель стадии эволюции («panther_2», CreatureAsset.model_for).
var model_id := ""
## Модель из файла (или null — модель из примитивов).
var _asset: CreatureAsset = null
## Атака ждёт момента удара в клипе модели из файла.
var _pending: Mob = null
var _pending_left := 0.0
## Каст изученного умения: id, цель (или null у усилений хозяина), сколько осталось, с.
var _cast_id := ""
var _cast_target: Mob = null
var _cast_left := 0.0
## Активные умения по убыванию приоритета (prio).
var _actives: Array[String] = []
var _col: CollisionShape3D = null
var _mat: Material = null
var _label: Label3D = null
var _color := Color.WHITE
var _scale := 1.0
var _height := 1.4
var _anim_t := 0.0
var _dash_time := 0.0
## Рывок изученного умения (id, например «Таран»); "" — рывок роли бойца.
var _dash_skill := ""
var _calm := 0.0
var _regen_acc := 0.0
var _hp_acc := 0.0
var _mp_acc := 0.0
var _upkeep_t := 0.0
var _last_crit := false
## Путь в обход реки через мосты (IslandWorld.bridge_waypoint).
var _route := IslandWorld.Route.new()
## Проверка «застрял»: сколько секунд хочет идти и откуда начал отсчёт.
var _stuck_t := 0.0
var _stuck_from := Vector3.ZERO
## Сколько раз перенесён к хозяину, потому что застрял (для тестов).
var stuck_teleports := 0


## Вызывать до добавления в сцену. rec — запись из Game.pets (не копия).
func setup(owner_p: Player, rec: Dictionary) -> void:
	owner_node = owner_p
	record = rec
	PetSkills.ensure_record(rec)
	species = String(rec.get("species", "boar"))
	if not PetData.SPECIES.has(species):
		species = "boar"
	role = PetData.role(species)
	level = clampi(int(rec.get("level", 1)), 1, PetData.MAX_LEVEL)
	xp = maxi(0, int(rec.get("xp", 0)))
	skills = rec["skills"]
	toggles = rec["toggles"]
	_apply_stats()
	var saved := int(rec.get("hp", -1))
	hp = max_hp if saved < 0 else clampi(saved, 1, max_hp)
	var saved_mp := int(rec.get("mp", -1))
	mp = max_mp if saved_mp < 0 else clampi(saved_mp, 0, max_mp)
	pet_name = PetData.stage_name(species, level)
	_write_record()


func _ready() -> void:
	add_to_group("pets")
	collision_layer = 2
	collision_mask = 1
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	# Питомец всегда рядом с камерой (в 2–3 м от героя), поэтому подпись мельче, чем у зверей
	# (LABEL_PX от их размера): на экране она не крупнее подписей зверей поблизости и имён жителей
	_label.pixel_size = UiScale.world_px(0.01 * LABEL_PX)
	_label.font_size = 40
	_label.outline_size = 10
	_label.modulate = Color(0.6, 0.9, 1.0)
	add_child(_label)
	_build_model()
	_update_label()
	_update_aura()


func _exit_tree() -> void:
	if is_instance_valid(owner_node):
		owner_node.clear_pet_aura(self)


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
		_dash_skill = ""


func _process(delta: float) -> void:
	if is_down or _model == null:
		return
	_anim_t += delta
	var hv := Vector2(velocity.x, velocity.z).length()
	if _asset != null:
		_asset.update(delta, hv)
	else:
		CreatureModels.animate(_model, species, _anim_t, clampf(hv / maxf(speed, 0.1), 0.0, 1.0))


func _physics_process(delta: float) -> void:
	if is_down or not is_instance_valid(owner_node):
		return
	attack_cd = maxf(0.0, attack_cd - delta)
	skill_cd = maxf(0.0, skill_cd - delta)
	_calm += delta
	_tick_skills(delta)
	if is_down:
		return
	if _pending != null:
		_pending_left -= delta
		if _pending_left <= 0.0:
			_land_attack()

	var to_o := owner_node.global_position - global_position
	to_o.y = 0.0
	if to_o.length() > TELEPORT_DIST:
		_teleport_to_owner()
		return

	var dir := Vector3.ZERO
	var face := Vector3.ZERO
	var spd := speed

	if _cast_left > 0.0:
		# Каст умения: стоит на месте лицом к цели
		_cast_left -= delta
		if is_instance_valid(_cast_target):
			face = _cast_target.global_position - global_position
			face.y = 0.0
		if _cast_left <= 0.0:
			_finish_cast()
	else:
		_pick_target()
		_role_support()
		if _dash_time <= 0.0:
			_support_skills()

		if target != null and _cast_left <= 0.0:
			var to := target.global_position - global_position
			to.y = 0.0
			face = to
			var dist := to.length()
			var reach := attack_range + 0.35 * target.body_scale
			if _dash_time <= 0.0:
				var charge := _pick_charge(dist, reach)
				if charge != "":
					_start_skill_dash(charge)
				elif _can_dash(dist, reach):
					_start_dash()
			if _dash_time > 0.0:
				_dash_time -= delta
				if dist <= reach:
					_dash_time = 0.0
					_dash_hit(target)
				elif _dash_time <= 0.0:
					_dash_skill = ""
				else:
					dir = to.normalized()
					spd = speed * 3.5
			elif dist > reach:
				dir = _route.dir_to(global_position, target.global_position, delta)
			elif attack_cd <= 0.0:
				attack_cd = attack_time
				var sid := _pick_active(target)
				if sid != "":
					_begin_skill(sid, target)
				else:
					_attack(target)
		elif target == null:
			_dash_time = 0.0
			_dash_skill = ""
			var d := to_o.length()
			if d > FOLLOW_DIST:
				dir = _route.dir_to(global_position, owner_node.global_position, delta)
				face = dir
				if d > 8.0:
					spd = speed * 1.5
			_regen(delta)

	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= 25.0 * delta
	var prev := global_position
	move_and_slide()
	IslandWorld.constrain(self, prev)
	if _check_stuck(delta, dir):
		return

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


# ---------- Атака и умения роли ----------

## Атака по цели: у модели из файла — клип Attack (Cast для умения мага), урон в момент удара клипа.
func _attack(t: Mob) -> void:
	if _asset != null:
		var cast := role == "mage" and skill_cd <= 0.0
		var delay := _asset.play_cast(attack_time) if cast else _asset.play_attack(attack_time)
		if delay > 0.0:
			_pending = t
			_pending_left = delay
			return
	_do_attack(t)


## Отложенная атака: цель ещё жива — бьём.
func _land_attack() -> void:
	if not is_instance_valid(_pending):
		_pending = null
		return
	var t := _pending
	_pending = null
	if not t.is_dead:
		_do_attack(t)


func _do_attack(t: Mob) -> void:
	var fx := PetData.fx_color(species, Color(1.0, 0.72, 0.28))
	if role == "mage" and skill_cd <= 0.0:
		var sk := PetData.skill(species)
		skill_cd = float(sk["cd"])
		skill_uses += 1
		_say_skill(String(sk["name"]))
		_blast(t.global_position, float(sk["radius"]), maxi(1, roundi(atk * float(sk["power"]))), fx)
		return
	# Обычная атака: точность против уровня зверя, крит
	if randf() > PetStats.hit_chance(accuracy, t.level):
		_miss_text(t)
		_bump()
		return
	var dmg := _roll(1.0)
	match role:
		"mage":
			_shoot(t, dmg, fx)
		"healer":
			_shoot(t, dmg, PetData.fx_color(species, Color(0.6, 1.0, 0.7)))
		_:
			t.take_damage(dmg, self, _last_crit)
			_threat_hit(t)
			_slash(t, 0.8)
			_bump()


## Урон от главной атаки × mult с разбросом и критом (результат крита — в _last_crit).
func _roll(mult: float) -> int:
	var base := float(atk) * mult + float(randi_range(-1, 2))
	_last_crit = randf() * 100.0 < crit
	if _last_crit:
		base *= PetStats.CRIT_MULT
	return maxi(1, roundi(base))


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
	_dash_skill = ""
	_say_skill(String(sk["name"]))
	if is_inside_tree():
		Vfx.death_puff(get_parent(), global_position + Vector3(0, 0.2, 0), 0.5 * _scale)


func _dash_hit(t: Mob) -> void:
	attack_cd = attack_time
	if _dash_skill != "":
		var sid := _dash_skill
		_dash_skill = ""
		_apply_skill(sid, t)
		_bump()
		return
	var sk := PetData.skill(species)
	t.take_damage(maxi(1, roundi(atk * float(sk["power"]))), self)
	CreatureModels.spawn_ring(get_parent(), t.global_position, 1.2, Color(1.0, 0.9, 0.5), 0.3)
	_slash(t, 1.3)
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
				m.taunt(self, float(sk["duration"]), StatusEffects.source_role_skill(species))
				if first == null:
					first = m
			if first != null:
				skill_cd = float(sk["cd"])
				skill_uses += 1
				_say_skill(String(sk["name"]))
				if _asset != null:
					_asset.play_cast()
				Vfx.magic_burst(get_parent(), global_position + Vector3(0, _height * 0.5, 0),
					CreatureModels.role_color(role), 1.4 * maxf(_scale, 0.8), 0.35)
				for n in get_tree().get_nodes_in_group("mobs"):
					var tm := n as Mob
					if tm != null and tm.target == self and not tm.is_dead:
						Vfx.hit_spark(get_parent(), tm.global_position + Vector3(0, tm._height + 0.4, 0),
							Color(1.0, 0.35, 0.3), 0.7)
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
			if _asset != null:
				_asset.play_cast()
			owner_node.heal(maxi(1, roundi(float(owner_node.max_hp) * float(sk["power"])) + heal_power))
			Vfx.heal_sparkles(get_parent(), owner_node.global_position)
			Vfx.hit_spark(get_parent(), global_position + Vector3(0, _height * 0.6, 0), Vfx.HEAL, 0.6)


func _shoot(t: Mob, dmg: int, c: Color) -> void:
	var b := Bolt.new()
	b.target = t
	b.source = self
	b.damage = dmg
	b.crit = _last_crit
	b.color = c
	get_parent().add_child(b)
	b.global_position = global_position + Vector3(0, maxf(0.6, _height * 0.7), 0)
	_threat_hit(t)
	_bump()


## Удар по площади вокруг center (вспышка цвета c; у пантеры — тёмно-фиолетовая, теневая).
func _blast(center: Vector3, radius: float, dmg: int, c: Color) -> void:
	Vfx.magic_burst(get_parent(), center + Vector3(0, 0.5, 0), c, radius, 0.4)
	# Тёмная сердцевина вспышки
	Vfx.magic_burst(get_parent(), center + Vector3(0, 0.3, 0), c.darkened(0.55), radius * 0.55, 0.3)
	for m in _mobs_near(center, radius):
		m.take_damage(dmg, self)


func _mobs_near(center: Vector3, radius: float) -> Array[Mob]:
	var res: Array[Mob] = []
	for n in get_tree().get_nodes_in_group("mobs"):
		var m := n as Mob
		if m != null and not m.is_dead and m.global_position.distance_to(center) <= radius:
			res.append(m)
	return res


## «Дерзкий вызов»: удар с шансом threat переключает зверя, бьющего хозяина, на питомца.
func _threat_hit(m: Mob) -> void:
	if threat <= 0.0 or not is_instance_valid(m) or m.is_dead or m.target != owner_node:
		return
	if randf() < threat:
		m.taunt(self, 3.0, StatusEffects.source_pet_skill(species, "provoke"))


func _miss_text(t: Mob) -> void:
	if is_inside_tree() and is_instance_valid(t):
		Util.float_text(get_parent(), t.global_position + Vector3(0, t._height + 0.6, 0), "Промах", Color(0.8, 0.85, 1.0))


# ---------- Изученные умения (PetSkills) ----------

## Перезарядки, восстановление MP и HP, поддержка переключаемых умений.
func _tick_skills(delta: float) -> void:
	for k in skill_cds.keys():
		skill_cds[k] = maxf(0.0, float(skill_cds[k]) - delta)
	var changed := false
	if mp < max_mp:
		_mp_acc += mp_regen * delta
		if _mp_acc >= 1.0:
			var g := int(_mp_acc)
			_mp_acc -= g
			mp = mini(max_mp, mp + g)
			changed = true
	else:
		_mp_acc = 0.0
	if hp_regen > 0.0 and hp < max_hp:
		_hp_acc += hp_regen * delta
		if _hp_acc >= 1.0:
			var h := int(_hp_acc)
			_hp_acc -= h
			hp = mini(max_hp, hp + h)
			changed = true
	if _any_toggle_on():
		_upkeep_t += delta
		if _upkeep_t >= PetSkills.UPKEEP_PERIOD:
			_upkeep_t -= PetSkills.UPKEEP_PERIOD
			_pay_upkeep()
	else:
		_upkeep_t = 0.0
	if changed:
		_write_record()
		_update_label()
		stats_changed.emit()


func _any_toggle_on() -> bool:
	for id in toggles:
		if bool(toggles[id]):
			return true
	return false


## Поддержка включённых переключаемых умений; не хватает MP — все выключаются.
func _pay_upkeep() -> void:
	var cost := toggle_upkeep()
	if cost <= 0:
		return
	if mp >= cost:
		mp -= cost
		_write_record()
		stats_changed.emit()
		return
	toggles.clear()
	_say("«%s»: не хватает MP — переключаемые умения выключены" % pet_name)
	refresh_skills()


## Сумма поддержки включённых переключаемых умений, MP за 10 с.
func toggle_upkeep() -> int:
	var cost := 0
	for id in toggles:
		if bool(toggles[id]):
			cost += PetSkills.upkeep(String(id), int(skills.get(id, 0)))
	return cost


## Включить или выключить переключаемое умение id. Включение тратит MP. "" — получилось, иначе причина.
func set_toggle(id: String, on: bool) -> String:
	var sk := PetSkills.get_skill(id)
	var n := int(skills.get(id, 0))
	if sk.is_empty() or String(sk.get("kind", "")) != "toggle" or n <= 0:
		return "Умение не изучено"
	if on == bool(toggles.get(id, false)):
		return ""
	if on:
		var cost := PetSkills.mp_cost(id, n)
		if mp < cost:
			return "Не хватает MP (нужно %d)" % cost
		mp -= cost
		toggles[id] = true
		_say_skill(String(sk["name"]))
		if is_inside_tree():
			Vfx.magic_burst(get_parent(), global_position + Vector3(0, _height * 0.5, 0), sk["color"], 1.2 * maxf(_scale, 0.8), 0.35)
	else:
		toggles.erase(id)
	refresh_skills()
	return ""


## Пересчитать характеристики после изучения умения или переключения (окно существа).
func refresh_skills() -> void:
	_apply_stats()
	_update_aura()
	_write_record()
	_update_label()
	stats_changed.emit()


## Бонусы хозяину от включённых «Уз» (атака, защита, восстановление HP).
func _update_aura() -> void:
	if not is_instance_valid(owner_node):
		return
	_sync_toggle_effects()
	if is_down:
		owner_node.clear_pet_aura(self)
		return
	var b := PetSkills.bonuses(species, skills, toggles, true)
	owner_node.set_pet_aura(self, float(b.get("atk_pct", 0.0)), roundi(float(b.get("def_flat", 0.0))),
		float(b.get("hp_regen", 0.0)))
	# Значки «Уз» и у хозяина: те включённые, что дают бонус и ему (поле owner)
	var on := {}
	for id in toggles:
		if bool(toggles[id]) and bool(PetSkills.get_skill(String(id)).get("owner", false)):
			on["pet:" + String(id)] = StatusEffects.toggle_info(StatusEffects.source_pet_skill(species, String(id)), pet_name)
	owner_node.effects.sync_toggles("pet:", on)


## Значки включённых переключаемых умений у полоски HP питомца (у погибшего — нет).
func _sync_toggle_effects() -> void:
	var on := {}
	if not is_down:
		for id in toggles:
			if bool(toggles[id]):
				on["toggle:" + String(id)] = StatusEffects.toggle_info(StatusEffects.source_pet_skill(species, String(id)))
	effects.sync_toggles("toggle:", on)


## Можно ли применить активное умение id сейчас: изучено, перезарядка готова, хватает MP.
func skill_ready(id: String) -> bool:
	var n := int(skills.get(id, 0))
	if n <= 0:
		return false
	if float(skill_cds.get(id, 0.0)) > 0.0:
		return false
	return mp >= PetSkills.mp_cost(id, n)


## Самое сильное готовое умение против цели t (без рывков и усилений хозяина); "" — нет.
func _pick_active(t: Mob) -> String:
	for id in _actives:
		var sk := PetSkills.get_skill(id)
		if sk.has("buff") or bool(sk.get("charge", false)) or not skill_ready(id):
			continue
		# Морок — только на зверя, который бьёт хозяина или питомца и ещё не ослеплён
		if sk.has("blind") and (t.blind_time > 0.0 or (t.target != owner_node and t.target != self)):
			continue
		if sk.has("stun") and not sk.has("dmg") and t.stun_time > 0.0:
			continue
		return id
	return ""


## Рывок-умение (Таран) к цели на расстоянии; "" — нет.
func _pick_charge(dist: float, reach: float) -> String:
	if mode == "follow" or dist <= maxf(reach, CHARGE_MIN) or dist >= CHARGE_MAX:
		return ""
	for id in _actives:
		if bool(PetSkills.get_skill(id).get("charge", false)) and skill_ready(id):
			return id
	return ""


func _start_skill_dash(id: String) -> void:
	_spend(id)
	_dash_time = 0.8
	_dash_skill = id
	if is_inside_tree():
		Vfx.death_puff(get_parent(), global_position + Vector3(0, 0.2, 0), 0.6 * _scale)


## Усиления хозяина и лечение: в бою или когда хозяину (питомцу) тяжело.
func _support_skills() -> void:
	if mode == "follow" or _actives.is_empty():
		return
	var near := global_position.distance_to(owner_node.global_position) <= HEAL_RANGE
	if not near:
		return
	for id in _actives:
		var sk := PetSkills.get_skill(id)
		var buff := String(sk.get("buff", ""))
		if buff == "" or not skill_ready(id):
			continue
		if buff == "heal":
			var low_owner := owner_node.hp > 0 and float(owner_node.hp) < float(owner_node.max_hp) * HEAL_SKILL_THRESHOLD
			var low_self := float(hp) < float(max_hp) * HEAL_SKILL_THRESHOLD
			if not (low_owner or low_self):
				continue
		elif target == null:
			continue
		_begin_skill(id, null)
		return


## MP, перезарядка, счётчик и название над головой.
func _spend(id: String) -> void:
	var sk := PetSkills.get_skill(id)
	var n := int(skills.get(id, 0))
	mp = maxi(0, mp - PetSkills.mp_cost(id, n))
	skill_cds[id] = float(sk.get("cd", 0.0))
	learned_uses += 1
	_say_skill(String(sk["name"]))
	_write_record()
	stats_changed.emit()


## Начать применение умения id по цели t (null — усиление хозяина): каст, затем эффект.
func _begin_skill(id: String, t: Mob) -> void:
	_spend(id)
	var cast := float(PetSkills.get_skill(id).get("cast", 0.0))
	var delay := cast
	if _asset != null:
		delay = maxf(cast, _asset.play_cast(maxf(cast, 0.6)))
	if delay <= 0.0:
		_apply_skill(id, t)
		return
	_cast_id = id
	_cast_target = t
	_cast_left = delay


func _finish_cast() -> void:
	var id := _cast_id
	# Цель могла исчезнуть: удалённый узел нельзя класть в типизированную переменную
	var t: Mob = _cast_target if is_instance_valid(_cast_target) else null
	_cast_id = ""
	_cast_target = null
	_cast_left = 0.0
	if id != "":
		_apply_skill(id, t)


## Эффект умения id по цели t: урон (несколько ударов, по площади), ослабления, угроза; усиления хозяина.
func _apply_skill(id: String, t: Mob) -> void:
	var sk := PetSkills.get_skill(id)
	var n := int(skills.get(id, 0))
	if n <= 0 or sk.is_empty():
		return
	if sk.has("buff"):
		_apply_buff(sk, n, id)
		return
	if not is_instance_valid(t) or t.is_dead:
		return
	var victims: Array[Mob] = [t]
	var fx := _skill_color(sk)
	if sk.has("radius"):
		var r := float(sk["radius"])
		victims = _mobs_near(t.global_position, r)
		_area_fx(t.global_position, r, fx)
	var mult := PetSkills.value(sk["dmg"], n) if sk.has("dmg") else 0.0
	var hits := int(sk.get("hits", 1))
	var src := StatusEffects.source_pet_skill(species, id)
	for m in victims:
		_skill_fx(m, fx, mult > 1.5)
		if mult > 0.0:
			m.take_damage(_roll(mult), self, _last_crit)
			for i in range(1, hits):
				if is_inside_tree():
					get_tree().create_timer(0.22 * float(i)).timeout.connect(_extra_hit.bind(m, mult, fx))
		if m.is_dead:
			continue
		var parent := get_parent()
		var above := m.global_position + Vector3(0, m._height + 0.9, 0)
		if sk.has("slow"):
			m.slow(PetSkills.value(sk["slow"], n), DEBUFF_TIME, src)
			Util.float_text(parent, above, "Замедлен", Color(0.6, 0.8, 1.0))
		if sk.has("vuln"):
			m.expose(PetSkills.value(sk["vuln"], n), DEBUFF_TIME, src)
			Util.float_text(parent, above, "Уязвим", Color(1.0, 0.6, 0.4))
		if sk.has("miss"):
			m.weaken_aim(PetSkills.value(sk["miss"], n), DEBUFF_TIME, src)
			Util.float_text(parent, above, "Сбит прицел", Color(1.0, 0.9, 0.5))
		if sk.has("weaken"):
			m.weaken(PetSkills.value(sk["weaken"], n), DEBUFF_TIME, src)
			Util.float_text(parent, above, "Ослаблен", Color(1.0, 0.7, 0.5))
		if sk.has("stun"):
			m.stun(float(sk["stun"]), src)
			Util.float_text(parent, above, "Оглушён!", Color(1, 1, 0.5))
		if sk.has("blind"):
			m.blind(PetSkills.value(sk["blind"], n), src)
			Util.float_text(parent, above, "Морок!", Color(0.75, 0.65, 1.0))
		if bool(sk.get("threat", false)):
			m.taunt(self, 4.0, src)
		else:
			_threat_hit(m)


## Следующий удар серии (двойной, тройной). target_ref без типа: зверь мог уже исчезнуть.
func _extra_hit(target_ref: Variant, mult: float, fx: Color) -> void:
	if is_down or not is_instance_valid(target_ref):
		return
	var m := target_ref as Mob
	if m == null or m.is_dead:
		return
	_skill_fx(m, fx, false)
	m.take_damage(_roll(mult), self, _last_crit)


## Усиление хозяина: атака, защита (меньше урона) или лечение хозяина и питомца.
func _apply_buff(sk: Dictionary, n: int, id: String = "") -> void:
	var v := PetSkills.value(sk["value"], n)
	var parent := get_parent()
	var c: Color = sk["color"]
	var head := owner_node.global_position + Vector3(0, 2.9, 0)
	match String(sk["buff"]):
		"atk":
			owner_node.atk_buff = maxf(owner_node.atk_buff, v)
			owner_node.atk_buff_time = maxf(owner_node.atk_buff_time, float(sk.get("time", 10.0)))
			owner_node.add_effect("atk", owner_node.atk_buff_time, StatusEffects.source_pet_skill(species, id))
			owner_node.stats_changed.emit()
			Util.float_text(parent, head, "Атака +%d%%" % roundi(v * 100.0), c)
		"guard":
			owner_node.guard = maxf(owner_node.guard, v)
			owner_node.guard_time = maxf(owner_node.guard_time, float(sk.get("time", 10.0)))
			owner_node.add_effect("guard", owner_node.guard_time, StatusEffects.source_pet_skill(species, id))
			owner_node._update_guard_fx()
			owner_node.stats_changed.emit()
			Util.float_text(parent, head, "Защита!", c)
		"heal":
			if owner_node.hp > 0:
				owner_node.heal(maxi(1, roundi(float(owner_node.max_hp) * v)) + heal_power)
			heal(maxi(1, roundi(float(max_hp) * v)))
	if _asset != null:
		_asset.play_cast()
	Vfx.magic_burst(parent, owner_node.global_position + Vector3(0, 1.0, 0), c, 1.6, 0.4)


## Цвет эффектов умения: у мага и лекаря — цвет вида (пантера — тёмная теневая магия), иначе — значка.
func _skill_color(sk: Dictionary) -> Color:
	var c: Color = sk["color"]
	if PetStats.is_magic(species):
		return PetData.fx_color(species, c)
	return c


## Попадание умения по зверю m: у мага и лекаря — вспышка магии на цели, у бойцов и танков — дуга удара.
func _skill_fx(m: Mob, c: Color, big: bool) -> void:
	if not is_inside_tree() or not is_instance_valid(m):
		return
	var pos := m.mid_point()
	if PetStats.is_magic(species):
		Vfx.magic_burst(get_parent(), pos, c, 1.3 if big else 0.9, 0.3)
		Vfx.magic_burst(get_parent(), pos, c.darkened(0.55), 0.7 if big else 0.5, 0.25)
	else:
		_slash(m, 1.3 if big else 1.0)
	Vfx.hit_spark(get_parent(), pos, c.lightened(0.3), 1.2 if big else 0.9)
	_bump()


## Умение по площади: кольцо и вспышка вокруг center.
func _area_fx(center: Vector3, radius: float, c: Color) -> void:
	if not is_inside_tree():
		return
	CreatureModels.spawn_ring(get_parent(), center, radius, c, 0.4)
	Vfx.magic_burst(get_parent(), center + Vector3(0, 0.5, 0), c, radius * 0.8, 0.45)
	if not PetStats.is_magic(species):
		Vfx.death_puff(get_parent(), center + Vector3(0, 0.3, 0), 1.4)


# ---------- Здоровье, опыт ----------

func take_damage(amount: int, attacker: Node3D) -> void:
	if is_down:
		return
	# Уклонение — только от ударов зверей (урон без источника не уклоняется)
	if attacker != null and randf() * 100.0 < evasion:
		if is_inside_tree():
			Util.float_text(get_parent(), global_position + Vector3(0, _height + 0.5, 0), "Уклон", Color(0.8, 0.95, 1.0))
		return
	amount = maxi(1, amount - int(defense * 0.5))
	hp -= amount
	_calm = 0.0
	Util.float_text(get_parent(), global_position + Vector3(0, _height + 0.5, 0), str(amount), Color(1, 0.5, 0.3))
	Vfx.hit_spark(get_parent(), global_position + Vector3(0, _height * 0.55, 0), Color(1.0, 0.55, 0.4), 0.7)
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
		Vfx.heal_sparkles(get_parent(), global_position, 0.6 * maxf(_scale, 0.8))
	_write_record()
	_update_label()
	stats_changed.emit()


## Опыт за убийство. Вместе с опытом копятся очки умений: JP_PER_LEVEL за каждый «уровень» опыта.
func gain_xp(amount: int) -> void:
	if is_down or amount <= 0 or level >= PetData.MAX_LEVEL:
		return
	_add_jp(float(PetSkills.JP_PER_LEVEL) * float(amount) / float(PetData.xp_to_next(level)))
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
		mp = max_mp
		pet_name = PetData.stage_name(species, level)
		if stage != old_stage:
			_evolve_fx()
			_say("Эволюция! «%s» теперь «%s» (ур. %d)" % [old_name, pet_name, level])
		else:
			_say("Питомец «%s» достиг уровня %d!" % [pet_name, level])
			if is_inside_tree():
				Vfx.level_up(get_parent(), global_position, 0.6 * maxf(_scale, 0.8))
	_write_record()
	_update_label()
	stats_changed.emit()


## Очки умений: дробная часть копится в записи (jp_part).
func _add_jp(v: float) -> void:
	var part := float(record.get("jp_part", 0.0)) + v
	var whole := int(floor(part))
	record["jp"] = int(record.get("jp", 0)) + whole
	record["jp_part"] = part - float(whole)


func _die() -> void:
	is_down = true
	target = null
	_pending = null
	_dash_time = 0.0
	_dash_skill = ""
	_cast_left = 0.0
	_cast_id = ""
	record["dead"] = true
	record["hp"] = 0
	record["level"] = level
	record["xp"] = xp
	collision_layer = 0
	visible = false
	remove_from_group("pets")
	_update_aura()
	if is_inside_tree():
		Util.float_text(get_parent(), global_position + Vector3(0, _height + 0.5, 0), "Погиб", Color(1, 0.4, 0.4))
		Vfx.death_puff(get_parent(), global_position + Vector3(0, _height * 0.4, 0), maxf(_scale, 0.7))
	_say("Питомец «%s» погиб. Воскресите его свитком в окне «Питомцы»" % pet_name)
	stats_changed.emit()
	died.emit()


## Вне боя: быстрое восстановление (3% HP в секунду через 4 с покоя).
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
	var s := PetData.stats_for(species, level, skills, toggles)
	stats = s
	max_hp = int(s["max_hp"])
	max_mp = int(s["max_mp"])
	atk = int(s["atk"])
	defense = int(s["def"])
	heal_power = int(s["heal"])
	accuracy = int(s["acc"])
	evasion = float(s["eva"])
	crit = float(s["crit"])
	hp_regen = float(s["hp_regen"])
	mp_regen = float(s["mp_regen"])
	threat = float(s["threat"])
	speed = float(s["speed"])
	attack_range = float(s["range"])
	attack_time = float(s["cd"])
	stage = PetData.stage_for(level)
	_color = PetData.stage_color(species, level)
	_scale = PetData.stage_scale(species, level)
	hp = mini(hp, max_hp)
	mp = mini(mp, max_mp)
	# Изученные активные умения по силе (prio): ИИ берёт первое готовое
	_actives.clear()
	for id in PetSkills.list_for(species):
		var sid := String(id)
		if String(PetSkills.get_skill(sid).get("kind", "")) == "active" and int(skills.get(sid, 0)) > 0:
			_actives.append(sid)
	_actives.sort_custom(func(a: String, b: String) -> bool:
		return int(PetSkills.get_skill(a).get("prio", 0)) > int(PetSkills.get_skill(b).get("prio", 0)))


## HP, MP, уровень, опыт и имя — в запись коллекции (она же сохраняется).
func _write_record() -> void:
	record["name"] = pet_name
	record["level"] = level
	record["xp"] = xp
	record["hp"] = -1 if hp >= max_hp else hp
	record["mp"] = -1 if mp >= max_mp else mp


## Хочет идти (dir), а почти не сдвинулся за STUCK_TIME — перенос к хозяину (как в MMO, когда питомец
## застрял у моста или в скалах). true — перенесён.
func _check_stuck(delta: float, dir: Vector3) -> bool:
	var far := Vector2(owner_node.global_position.x - global_position.x,
		owner_node.global_position.z - global_position.z).length() > FOLLOW_DIST + 1.0
	if dir == Vector3.ZERO or _dash_time > 0.0 or not far:
		_stuck_t = 0.0
		_stuck_from = global_position
		return false
	_stuck_t += delta
	if _stuck_t < STUCK_TIME:
		return false
	var moved := Vector2(global_position.x - _stuck_from.x, global_position.z - _stuck_from.z).length()
	_stuck_t = 0.0
	_stuck_from = global_position
	if moved >= STUCK_MOVE:
		return false
	stuck_teleports += 1
	_teleport_to_owner()
	return true


## Перенос к хозяину (отстал или застрял): вспышка там, где был, и там, где появился; место — проходимое
## рядом с хозяином (за спиной или сбоку), на его высоте (на мосту — на настиле).
func _teleport_to_owner() -> void:
	var old := global_position
	var op := owner_node.global_position
	var w := IslandWorld.current
	var spot := op + Vector3(1.5, 0.2, 1.5)
	var back := owner_node.global_transform.basis.z
	back.y = 0.0
	back = back.normalized() if back.length() > 0.01 else Vector3(0, 0, 1)
	for k in 8:
		var off := back.rotated(Vector3.UP, TAU * float(k) / 8.0) * 1.6
		var q := op + off
		if w == null or not is_instance_valid(w) or w.is_walkable(q.x, q.z):
			spot = Vector3(q.x, op.y + 0.2, q.z)
			if w != null and is_instance_valid(w):
				spot.y = maxf(op.y, w.height_at(q.x, q.z)) + 0.2
			break
	global_position = spot
	velocity = Vector3.ZERO
	_route.reset()
	_stuck_t = 0.0
	_stuck_from = spot
	if is_inside_tree() and get_parent() != null:
		Vfx.magic_burst(get_parent(), old + Vector3(0, 0.5, 0), Color(0.45, 0.85, 1.0), 0.8, 0.35)
		Vfx.magic_burst(get_parent(), spot + Vector3(0, 0.5, 0), Color(0.45, 0.85, 1.0), 0.8, 0.35)
	target = null
	_pending = null
	_dash_time = 0.0
	_dash_skill = ""
	_cast_left = 0.0
	_cast_id = ""
	_cast_target = null


# ---------- Вид ----------

func _build_model() -> void:
	if _model != null:
		_model.queue_free()
	if _col != null:
		_col.queue_free()
	_model = Node3D.new()
	add_child(_model)
	# На 2-й и 3-й стадии — своя модель стадии, если её файл есть (иначе 1-я стадия с украшениями)
	model_id = CreatureAsset.model_for(species, stage)
	_mat = CreatureModels.build(_model, species, _color, _scale, PetData.asset_tint(species, level), stage)
	_asset = CreatureModels.asset_of(_model)
	CreatureModels.decorate_pet(_model, species, _scale, stage, role)
	_col = CreatureModels.add_collision(self, model_id, _scale)
	_height = CreatureModels.height(model_id, _scale)
	# Голубой круг под ногами: свой питомец, а не дикий зверь
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = CreatureModels.ring_radius(model_id, _scale) + 0.15
	tm.outer_radius = tm.inner_radius + 0.07
	ring.mesh = tm
	ring.position.y = 0.05
	ring.material_override = CreatureModels.flat_mat(Color(0.3, 0.8, 1.0))
	ring.set_meta("no_outline", true)
	_model.add_child(ring)
	if _label != null:
		_label.position = Vector3(0, _height + 0.35, 0)


func _evolve_fx() -> void:
	if not is_inside_tree():
		return
	_build_model()
	Vfx.evolution(get_parent(), global_position, maxf(_scale, 0.8))
	Util.float_text(get_parent(), global_position + Vector3(0, _height + 0.8, 0), "Эволюция!", Color(1.0, 0.9, 0.4), 1.4)
	# Новая модель «выпрыгивает» из вспышки
	_model.scale = Vector3.ONE * 0.3
	var t := create_tween()
	t.tween_interval(0.35)
	t.tween_property(_model, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _say(t: String) -> void:
	if is_instance_valid(owner_node):
		owner_node.message.emit(t)


func _say_skill(skill_name: String) -> void:
	if is_inside_tree():
		Util.float_text(get_parent(), global_position + Vector3(0, _height + 0.8, 0), skill_name + "!", Color(1.0, 0.85, 0.4))


## Дуга удара по цели t в цвет роли.
func _slash(t: Mob, size: float) -> void:
	if not is_inside_tree() or not is_instance_valid(t):
		return
	var dir := t.global_position - global_position
	Vfx.slash_arc(get_parent(), t.mid_point(), dir,
		CreatureModels.role_color(role).lightened(0.3), size * clampf(t.body_scale, 0.8, 1.6))


func _bump() -> void:
	if _model == null:
		return
	var t := create_tween()
	t.tween_property(_model, "scale", Vector3(1.12, 0.9, 1.12), 0.06)
	t.tween_property(_model, "scale", Vector3.ONE, 0.1)


func _flash() -> void:
	if _asset != null:
		_asset.play_hit()
	if _mat == null:
		return
	CreatureModels.flash(self, _mat)


func _update_label() -> void:
	if _label != null:
		_label.text = "%s  Ур.%d\n%d/%d" % [pet_name, level, hp, max_hp]


## Снаряд мага или лекаря: летит в цель и наносит урон при попадании.
class Bolt extends Node3D:
	var target: Node3D = null
	var source: Node3D = null
	var damage := 1
	var crit := false
	var color := Color.WHITE
	var speed := 14.0
	var life := 3.0

	func _ready() -> void:
		# Светящийся шарик с ореолом и шлейфом искорок
		var mi := MeshInstance3D.new()
		mi.set_meta("no_outline", true)
		var sm := SphereMesh.new()
		sm.radius = 0.13
		sm.height = 0.26
		sm.radial_segments = 12
		sm.rings = 6
		mi.mesh = sm
		mi.material_override = CreatureModels.flat_mat(color.lightened(0.5))
		add_child(mi)
		var halo := MeshInstance3D.new()
		halo.set_meta("no_outline", true)
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		halo.mesh = Vfx._quad()
		halo.material_override = Vfx.fx_mat(Color(color, 0.8), Vfx.tex("star"), true, BaseMaterial3D.BILLBOARD_ENABLED)
		halo.scale = Vector3.ONE * (0.95 if crit else 0.75)
		add_child(halo)
		var trail := Vfx.ambient_sparkles(self, color, 0.08, 10)
		trail.lifetime = 0.35
		trail.initial_velocity_max = 0.2

	func _process(delta: float) -> void:
		life -= delta
		if life <= 0.0 or not is_instance_valid(target) or target.get("is_dead") == true:
			queue_free()
			return
		# По зверю — в центр тела (летающая рыба парит высоко), иначе — на 0.8 м над землёй
		var tm := target as Mob
		var aim := tm.aim_point() if tm != null and tm.hover_y > 0.0 else target.global_position + Vector3(0, 0.8, 0)
		var to := aim - global_position
		var step := speed * delta
		if to.length() <= step + 0.25:
			var src: Node3D = source if is_instance_valid(source) else null
			target.call("take_damage", damage, src, crit)
			Vfx.hit_spark(get_parent(), global_position, color, 0.8)
			queue_free()
			return
		global_position += to.normalized() * step
