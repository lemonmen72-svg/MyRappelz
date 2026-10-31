class_name Player
extends CharacterBody3D
## Персонаж игрока. Уровень, опыт и золото хранятся в Game. Характеристики — из 7 статов профессии (HeroStats: HP,
## MP, атака, маг. атака, защита, точность, уклонение, крит, скорость атаки, восстановление HP); поверх — надетое
## оружие и щит (Game.weapon, Game.shield, ItemData) и умения героя (Game.hero, HeroSkills: пассивные, включённые
## переключаемые и усиления на время). Обычная атака может промахнуться (точность против уровня зверя,
## Stats.hit_chance), умения бьют без промаха.
## Атака по виду оружия: ближний бой (melee), лук или арбалет (ranged), посох — магия (magic: сгусток Projectile,
## сила — маг. атака).
## Умения на кнопках "skill1"…"skill4" (Game.hero.slots): умения Наёмника — _cast_hero, умения с полем fx — движок
## HeroSkillFx; требуют MP, подходящее оружие и перезарядку. У Бродяги умений нет (кнопки скрыты).
## Временные усиления. Внешний вид — CharacterModel (раса, пол, профессия, оружие).

signal stats_changed
signal message(text: String)
## Сменилась цель (Mob или null) — для панели цели в HUD.
signal target_changed(target: Node3D)

const CRIT_MULT := 1.8
## Умения ближнего боя достают чуть дальше обычной атаки.
const MELEE_SKILL_REACH := 0.6
## Кнопки умений HUD.
const SLOT_IDS := ["skill1", "skill2", "skill3", "skill4"]
## Восстановление MP в секунду (доля запаса): в бою и вне боя (нет ударов и умений MP_COMBAT_TIME с).
const MP_REGEN_COMBAT := 0.012
const MP_REGEN_REST := 0.04
const MP_COMBAT_TIME := 4.0
## Анимация умений героя ближнего боя (по умолчанию — обычный удар).
const SKILL_ANIM := {"backstab": "bash", "charge_stab": "dash", "dark_strike": "bash", "head_breaker": "spin",
	"bloody_blade": "attack", "sleeping_dust": "cast"}
## Пауза между ударами многоударных умений и вторым ударом обычной атаки, с.
const HIT_GAP := 0.14

var max_hp := 100
var hp := 100
## MP: у классов с запасом MP (ClassData mp); 0 — умения без MP.
var max_mp := 0
var mp := 0
## Шанс уклониться от удара зверя (0..1, без «Танца теней»: cur_eva()).
var eva := 0.0
## Точность (шанс попасть обычной атакой — Stats.hit_chance); -1 — без промахов (классы без статов).
var accuracy := -1
## Восстановление HP в секунду (и в бою) от статов.
var hp_regen := 0.0
## Характеристики героя из статов (HeroStats.derived: stats, max_hp, patk, ratk, matk, def, mdef, acc, eva, crit,
## aspd, hp_regen — без оружия и умений) для окна героя; пусто у классов без статов.
var hero_stats: Dictionary = {}
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
## Вид надетого оружия (ItemData.WEAPON_KINDS; "" — без оружия) и щит во второй руке.
var weapon_kind := ""
var has_shield := false
## Магическая атака (сила заклинаний и магической обычной атаки) и магическая защита.
var matk := 10
var mdef := 0
## Шанс блока (щит: удар зверя без урона), снижение получаемого урона от умений (доля), сокращение перезарядки.
var block := 0.0
var skill_guard := 0.0
var cdr := 0.0
## Усиления на время от умений движка (HeroSkillFx "buff"): id умения → {"left": с, "bonus": {ключ: число}}.
var timed_bonus: Dictionary = {}
## Лечение со временем (HeroSkillFx "hot"): [{"id", "node", "per_sec", "left", "acc"}].
var hots: Array = []
## Скорость атаки (1.0 = 100%: от Ловкости и умений), множитель урона обычной атаки, шанс второго удара (выстрела),
## доля урона выстрела в MP, незаметность (звери замечают ближе, удары реже отвлекают зверя от питомца).
var aspd := 1.0
var basic_mult := 1.0
var double_chance := 0.0
var mp_drain := 0.0
var stealth := 0.0
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
## «Танец теней»: оставшееся время и прибавки к уклонению, атаке (доля) и шансу крита.
var shade_time := 0.0
var shade_eva := 0.0
var shade_atk := 0.0
var shade_crit := 0.0
## Бонусы от переключаемых умений призванного питомца («Узы …»): доля атаки, защита, HP в секунду.
## Ставит и снимает питомец (set_pet_aura / clear_pet_aura).
var aura_atk := 0.0
var aura_def := 0
var aura_regen := 0.0
## Кто поставил бонусы: id объекта питомца (0 — никто).
var _aura_src := 0
## Действующие эффекты для HUD (значки у полоски HP): усиления выше (atk, speed, guard, shade — сверяются
## с таймерами каждый кадр), включённые переключаемые героя ("toggle:<id>") и «Узы» питомца ("pet:<id>").
var effects := StatusEffects.new()
var _aura_acc := 0.0

var _model: CharacterModel
var _weapon_kind := ""
var _guard_fx: MeshInstance3D
var _regen_acc := 0.0
var _last_crit := false
var _mp_acc := 0.0
var _mp_delay := 0.0
var _upkeep_acc := 0.0
var _fx: HeroSkillFx


func _ready() -> void:
	add_to_group("player")
	_fx = HeroSkillFx.new(self)
	collision_layer = 2
	collision_mask = 1
	Game.ensure_hero()
	recalc_stats()
	hp = max_hp
	mp = max_mp

	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	col.shape = shape
	col.position.y = 0.9
	add_child(col)

	_build_model()


## Пересчитать характеристики: профессия и уровень (Game.class_id, Game.level) через 7 статов (HeroStats),
## оружие и щит (Game.weapon, Game.shield), пассивные и включённые переключаемые умения героя (HeroSkills.bonuses —
## только подходящие оружию) и усиления на время (timed_bonus).
func recalc_stats() -> void:
	var s := ClassData.stats_for(Game.class_id, Game.level)
	max_hp = s["max_hp"]
	max_mp = s["max_mp"]
	atk = s["atk"]
	matk = atk
	defense = s["def"]
	mdef = defense
	speed = s["speed"]
	attack_range = s["range"]
	attack_time = s["cd"]
	crit = s["crit"]
	eva = s["eva"]
	attack_kind = s["attack"]
	accuracy = -1
	hp_regen = 0.0
	hero_stats = {}
	weapon_kind = Game.weapon_kind()
	has_shield = Game.has_shield()
	var b := HeroSkills.bonuses(Game.hero, Game.class_id, weapon_kind, has_shield)
	for id in timed_bonus:
		var tb: Dictionary = timed_bonus[id]["bonus"]
		for k in tb:
			b[k] = float(b.get(k, 0.0)) + float(tb[k])
	var extra: Dictionary = {}
	for k in Stats.STATS:
		if b.has(k):
			extra[k] = b[k]
	var stat_aspd := 1.0
	if HeroStats.has_stats(Game.class_id):
		var h := HeroStats.derived(Game.class_id, Game.level, extra)
		hero_stats = h
		max_hp = int(h["max_hp"])
		max_mp = int(h["max_mp"])
		atk = int(h["patk"])
		matk = int(h["matk"])
		defense = int(h["def"])
		mdef = int(h["mdef"])
		crit = float(h["crit"]) / 100.0
		eva = float(h["eva"]) / 100.0
		accuracy = int(h["acc"])
		hp_regen = float(h["hp_regen"])
		stat_aspd = float(h["aspd"]) / 100.0
	if weapon_kind != "":
		var w := ItemData.get_item(Game.weapon)
		attack_kind = ItemData.weapon_attack(weapon_kind)
		# Стрельба — атака дальнего боя (от Меткости и Ловкости), посох — маг. атака, остальное — от Силы
		if attack_kind == "ranged" and not hero_stats.is_empty():
			atk = int(hero_stats["ratk"])
		elif attack_kind == "magic":
			atk = matk
		atk += int(w.get("atk", 0))
		if attack_kind == "magic":
			matk = atk
		attack_time = float(w.get("cd", attack_time))
		attack_range = float(w.get("range", attack_range))
		crit += float(w.get("crit", 0.0))
	if has_shield:
		defense += int(ItemData.get_item(Game.shield).get("def", 0))
	atk = roundi(float(atk) * (1.0 + _bv(b, "atk_pct") + (_bv(b, "matk_pct") if attack_kind == "magic" else 0.0))) + roundi(_bv(b, "atk_flat"))
	matk = roundi(float(matk) * (1.0 + _bv(b, "matk_pct")))
	defense = roundi(float(defense + roundi(_bv(b, "def_flat"))) * (1.0 + _bv(b, "def_pct")))
	mdef += roundi(_bv(b, "mdef_flat"))
	eva = clampf(eva + _bv(b, "eva"), 0.0, 0.6)
	crit += _bv(b, "crit")
	speed *= 1.0 + _bv(b, "speed_pct")
	# Как в Rappelz: прибавки скорости атаки от умений складываются со скоростью от Ловкости
	aspd = stat_aspd + _bv(b, "aspd")
	attack_time /= aspd
	basic_mult = 1.0 + _bv(b, "basic_pct")
	double_chance = _bv(b, "double")
	mp_drain = _bv(b, "mp_drain")
	stealth = _bv(b, "stealth")
	block = clampf(_bv(b, "block"), 0.0, 0.75)
	skill_guard = clampf(_bv(b, "guard"), 0.0, 0.9)
	cdr = clampf(_bv(b, "cdr"), 0.0, 0.5)
	hp_regen += _bv(b, "regen")
	max_hp = roundi(float(max_hp) * (1.0 + _bv(b, "hp_pct") + _bv(b, "hp_from_eva") * eva)) + roundi(_bv(b, "hp_flat"))
	max_mp = roundi(float(max_mp) * (1.0 + _bv(b, "mp_from_eva") * eva + _bv(b, "mp_pct")))
	hp = mini(hp, max_hp)
	mp = mini(mp, max_mp)
	_sync_toggle_effects()


## Усиление на время от умения sid (HeroSkillFx "buff"): bonus — {ключ HeroSkills.BONUS_NAMES: число} на sec секунд,
## значок у полоски HP ("buff:<id>"). Повтор продлевает.
func add_timed_bonus(sid: String, sec: float, bonus: Dictionary) -> void:
	if sec <= 0.0:
		return
	timed_bonus[sid] = {"left": sec, "bonus": bonus}
	effects.add("buff:" + sid, sec, StatusEffects.effect_info("buff", StatusEffects.source_hero_skill(sid)))
	recalc_stats()
	stats_changed.emit()


## Лечение со временем от умения sid: всего total HP цели node (герой или питомец) за sec секунд.
func add_hot(sid: String, node: Node3D, total: float, sec: float) -> void:
	if node == null or sec <= 0.0 or total <= 0.0:
		return
	hots.append({"id": sid, "node": node, "per_sec": total / sec, "left": sec, "acc": 0.0})
	if node == self:
		effects.add("hot:" + sid, sec, StatusEffects.effect_info("hot", StatusEffects.source_hero_skill(sid)))


func _tick_timed(delta: float) -> void:
	if not timed_bonus.is_empty():
		var expired := false
		for id in timed_bonus.keys():
			var e: Dictionary = timed_bonus[id]
			e["left"] = float(e["left"]) - delta
			effects.sync("buff:" + String(id), float(e["left"]))
			if float(e["left"]) <= 0.0:
				timed_bonus.erase(id)
				expired = true
		if expired:
			recalc_stats()
			stats_changed.emit()
	var i := hots.size() - 1
	while i >= 0:
		var h: Dictionary = hots[i]
		h["left"] = float(h["left"]) - delta
		h["acc"] = float(h["acc"]) + float(h["per_sec"]) * delta
		var node: Variant = h["node"]
		var whole := int(float(h["acc"]))
		var valid := is_instance_valid(node)
		var mine := valid and (node as Object) == self
		if whole >= 1 and valid:
			h["acc"] = float(h["acc"]) - float(whole)
			if mine:
				hp = mini(max_hp, hp + whole)
				stats_changed.emit()
			elif (node as Node).has_method("heal"):
				(node as Node).call("heal", whole)
		if mine:
			effects.sync("hot:" + String(h["id"]), float(h["left"]))
		if float(h["left"]) <= 0.0 or not valid:
			hots.remove_at(i)
		i -= 1


## Значки включённых переключаемых умений героя (без таймера) — после любого пересчёта (вкл./выкл.,
## смена оружия, нехватка MP).
func _sync_toggle_effects() -> void:
	var on := {}
	var tg: Dictionary = Game.hero.get("toggles", {})
	for id in tg:
		if bool(tg[id]):
			on["toggle:" + String(id)] = StatusEffects.toggle_info(StatusEffects.source_hero_skill(String(id)))
	effects.sync_toggles("toggle:", on)


## Усиление kind (StatusEffects.KINDS) на sec секунд от источника src — значок у полоски HP.
func add_effect(kind: String, sec: float, src: Dictionary) -> void:
	effects.add(kind, sec, StatusEffects.effect_info(kind, src))


static func _bv(b: Dictionary, key: String) -> float:
	return float(b.get(key, 0.0))


## Применить сменившиеся Game.class_id / Game.race_id / Game.gender: умения героя и оружие (Game.ensure_hero),
## характеристики, внешний вид.
func apply_class() -> void:
	Game.ensure_hero()
	timed_bonus.clear()
	hots.clear()
	recalc_stats()
	hp = max_hp
	mp = max_mp
	skill_cd.clear()
	clear_buffs()
	_build_model()
	stats_changed.emit()


## После изучения умения или переключения (окно героя): пересчитать характеристики.
func refresh_skills() -> void:
	recalc_stats()
	stats_changed.emit()


## Надеть оружие id из сумки (щит — во вторую руку). "" — получилось, иначе причина. Модель меняет оружие в руках,
## переключаемые умения, которым оружие не подходит, выключаются.
func equip(id: String) -> String:
	if id == Game.weapon:
		return ""
	var err := Game.equip_weapon(id)
	if err != "":
		return err
	recalc_stats()
	attack_cd = 0.0
	_build_model()
	var off: PackedStringArray = []
	for t in Game.last_dropped_toggles:
		off.append(String(HeroSkills.get_skill(String(t)).get("name", t)))
	var text := ("Во второй руке: %s" if ItemData.is_shield(id) else "В руках: %s") % ItemData.item_name(id)
	if not off.is_empty():
		text += ". Выключено: %s" % ", ".join(off)
	message.emit(text)
	stats_changed.emit()
	return ""


func cur_atk() -> int:
	return roundi(float(atk) * (1.0 + atk_buff + aura_atk + shade_atk))


## Магическая атака с усилениями (умения-заклинания, power "matk").
func cur_matk() -> int:
	return roundi(float(matk) * (1.0 + atk_buff + aura_atk + shade_atk))


## Шанс крита с «Танцем теней».
func cur_crit() -> float:
	return crit + shade_crit


## Шанс уклониться с «Танцем теней» (не больше 60%).
func cur_eva() -> float:
	return clampf(eva + shade_eva, 0.0, 0.6)


## Скорость бега с усилением; ×2 / ×3 — тест из админ-панели (AdminPanel.speed_mult).
func cur_speed() -> float:
	return speed * (1.0 + speed_buff) * float(AdminPanel.speed_mult)


## Восстановление MP в секунду: в бою (in_combat) или на отдыхе.
func mp_regen_rate(in_combat: bool) -> float:
	return float(max_mp) * (MP_REGEN_COMBAT if in_combat else MP_REGEN_REST)


## Шанс попасть обычной атакой по зверю t (1.0 — без промахов).
func hit_chance(t: Mob) -> float:
	if accuracy < 0 or t == null:
		return 1.0
	return Stats.hit_chance(accuracy, t.level)


## Попала ли обычная атака по зверю t (бросок по hit_chance).
func _basic_hits(t: Mob) -> bool:
	var c := hit_chance(t)
	return c >= 1.0 or randf() < c


func _miss_text(t: Mob) -> void:
	if is_inside_tree() and is_instance_valid(t):
		Util.float_text(get_parent(), t.global_position + Vector3(0, 2.6 * t.body_scale + 0.4, 0), "Промах",
			Color(0.8, 0.85, 1.0))


func _physics_process(delta: float) -> void:
	attack_cd = maxf(0.0, attack_cd - delta)
	regen_delay = maxf(0.0, regen_delay - delta)
	_mp_delay = maxf(0.0, _mp_delay - delta)
	_tick_skills(delta)
	_tick_timed(delta)
	_tick_mp(delta)

	if current_target != null and (not is_instance_valid(current_target) or current_target.is_dead):
		_set_target(null)

	# Восстановление от статов и от питомца («Узы зари»), и в бою
	var regen := aura_regen + hp_regen
	if regen > 0.0 and hp < max_hp:
		_aura_acc += delta * regen
		if _aura_acc >= 1.0:
			var ah := int(_aura_acc)
			hp = mini(max_hp, hp + ah)
			_aura_acc -= ah
			stats_changed.emit()

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
	if shade_time > 0.0:
		shade_time -= delta
		if shade_time <= 0.0:
			shade_time = 0.0
			shade_eva = 0.0
			shade_atk = 0.0
			shade_crit = 0.0
			stats_changed.emit()
	if not effects.is_empty():
		effects.sync("atk", atk_buff_time)
		effects.sync("speed", speed_buff_time)
		effects.sync("guard", guard_time)
		effects.sync("shade", shade_time)


## Восстановление MP и поддержка переключаемых умений (раз в HeroSkills.UPKEEP_PERIOD с).
func _tick_mp(delta: float) -> void:
	if max_mp <= 0:
		return
	if mp < max_mp:
		var rate := MP_REGEN_COMBAT if _mp_delay > 0.0 or regen_delay > 0.0 else MP_REGEN_REST
		_mp_acc += delta * float(max_mp) * rate
		if _mp_acc >= 1.0:
			var m := int(_mp_acc)
			mp = mini(max_mp, mp + m)
			_mp_acc -= m
			stats_changed.emit()
	if toggle_upkeep() <= 0:
		_upkeep_acc = 0.0
		return
	_upkeep_acc += delta
	if _upkeep_acc >= HeroSkills.UPKEEP_PERIOD:
		_upkeep_acc -= HeroSkills.UPKEEP_PERIOD
		pay_upkeep()


## Сумма поддержки включённых переключаемых умений, MP за 10 с.
func toggle_upkeep() -> int:
	var cost := 0
	var tg: Dictionary = Game.hero.get("toggles", {})
	for id in tg:
		cost += HeroSkills.upkeep(String(id), HeroSkills.skill_level(Game.hero, String(id)))
	return cost


## Списать поддержку переключаемых умений; не хватает MP — все выключаются.
func pay_upkeep() -> void:
	var cost := toggle_upkeep()
	if cost <= 0:
		return
	if mp >= cost:
		mp -= cost
		stats_changed.emit()
		return
	var tg: Dictionary = Game.hero.get("toggles", {})
	tg.clear()
	message.emit("Не хватает MP — переключаемые умения выключены")
	refresh_skills()
	Game.changed.emit()


## Включить или выключить переключаемое умение героя id. Включение тратит MP и требует подходящее оружие.
## "" — получилось, иначе причина.
func set_toggle(id: String, on: bool) -> String:
	var n := HeroSkills.skill_level(Game.hero, id)
	if HeroSkills.kind(id) != "toggle" or n <= 0:
		return "Умение не изучено"
	var tg: Dictionary = Game.hero["toggles"]
	if on == bool(tg.get(id, false)):
		return ""
	var sk := HeroSkills.get_skill(id)
	if on:
		var wb := HeroSkills.weapon_block(id, weapon_kind, has_shield)
		if wb != "":
			return wb
		var cost := HeroSkills.mp_cost(id, n)
		if mp < cost:
			return "Не хватает MP (нужно %d)" % cost
		mp -= cost
		# Одно умение группы за раз («одно лезвие / одна подпитка / одно созвучие»)
		var grp := String(sk.get("group", ""))
		if grp != "":
			for other in tg.keys():
				if String(HeroSkills.get_skill(String(other)).get("group", "")) == grp:
					tg.erase(other)
		tg[id] = true
		_mp_delay = MP_COMBAT_TIME
		_announce(String(sk["name"]), "включено")
		if is_inside_tree():
			Projectile.burst(get_parent(), global_position + Vector3(0, 1.0, 0), sk["color"], 1.4, 0.3)
	else:
		tg.erase(id)
		message.emit("«%s» выключено" % String(sk["name"]))
	refresh_skills()
	Game.changed.emit()
	return ""


## Бонусы хозяину от включённых умений питомца src (атака — доля, защита, HP в секунду).
func set_pet_aura(src: Object, atk_pct: float, def_bonus: int, regen: float) -> void:
	_aura_src = src.get_instance_id() if src != null else 0
	aura_atk = atk_pct
	aura_def = def_bonus
	aura_regen = regen
	stats_changed.emit()


## Снять бонусы питомца src (если их ставил он: новый питомец мог уже поставить свои).
func clear_pet_aura(src: Object) -> void:
	if src != null and _aura_src == src.get_instance_id():
		set_pet_aura(null, 0.0, 0, 0.0)
		effects.sync_toggles("pet:", {})


func clear_buffs() -> void:
	atk_buff_time = 0.0
	atk_buff = 0.0
	speed_buff_time = 0.0
	speed_buff = 0.0
	guard_time = 0.0
	guard = 0.0
	shade_time = 0.0
	shade_eva = 0.0
	shade_atk = 0.0
	shade_crit = 0.0
	for k in ["atk", "speed", "guard", "shade"]:
		effects.remove(String(k))
	for id in timed_bonus:
		effects.remove("buff:" + String(id))
	timed_bonus.clear()
	for h in hots:
		effects.remove("hot:" + String((h as Dictionary)["id"]))
	hots.clear()
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
	_mp_delay = MP_COMBAT_TIME
	var dmg := _roll(basic_mult, false)
	_anim_attack()
	var hit := _basic_hits(target)
	var twice := double_chance > 0.0 and randf() < double_chance
	if attack_kind == "melee":
		if hit:
			_deal(target, dmg)
		else:
			_miss_text(target)
		Vfx.slash_arc(get_parent(), target.aim_point(),
			target.global_position - global_position, _class_color())
		if twice:
			get_tree().create_timer(HIT_GAP).timeout.connect(_late_hit.bind(target, basic_mult, 0.0, false, true))
	else:
		var cb := Callable()
		if mp_drain > 0.0:
			cb = func(_hit: Mob, dealt: int) -> void:
				_gain_mp(float(dealt) * mp_drain)
		_shoot(target, dmg, 1.0, cb, not hit)
		if twice:
			get_tree().create_timer(HIT_GAP).timeout.connect(_late_shot.bind(target, basic_mult, 0.0, false, cb, true))
	return true


## Второй удар (многоударное умение, «Вихрь клинков»): по цели, если она ещё жива.
## say_double — второй удар обычной атаки: может промахнуться, как и первый.
func _late_hit(t: Variant, mult: float, flat: float, force_crit: bool, say_double: bool) -> void:
	if not is_instance_valid(t) or not is_inside_tree():
		return
	var m := t as Mob
	if m == null or m.is_dead:
		return
	if say_double and not _basic_hits(m):
		_miss_text(m)
		return
	_deal(m, _roll(mult, force_crit, flat))
	Vfx.slash_arc(get_parent(), m.aim_point(),
		m.global_position - global_position, _class_color().lightened(0.25))
	if say_double:
		Util.float_text(get_parent(), global_position + Vector3(0, 2.6, 0), "Двойной удар!", Color(1, 0.75, 0.4))


## Второй болт (многоударное умение, «Беглый огонь»).
func _late_shot(t: Variant, mult: float, flat: float, force_crit: bool, on_hit: Callable, say_double: bool) -> void:
	if not is_instance_valid(t) or not is_inside_tree():
		return
	var m := t as Mob
	if m == null or m.is_dead:
		return
	var dmg := _roll(mult, force_crit, flat)
	_shoot(m, dmg, 1.0, on_hit, say_double and not _basic_hits(m))
	if say_double:
		Util.float_text(get_parent(), global_position + Vector3(0, 2.6, 0), "Второй болт!", Color(1, 0.75, 0.4))


## MP с урона («Иссушающие болты»): дробная часть копится.
func _gain_mp(amount: float) -> void:
	if max_mp <= 0 or amount <= 0.0:
		return
	_mp_acc += amount
	if _mp_acc >= 1.0:
		var m := int(_mp_acc)
		mp = mini(max_mp, mp + m)
		_mp_acc -= m
		stats_changed.emit()


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


## Урон с разбросом и критом. mult: множитель атаки, flat: прибавка. Результат крита — в _last_crit.
func _roll(mult: float, force_crit: bool, flat: float = 0.0) -> int:
	var base := float(cur_atk()) * mult + flat + float(randi_range(-2, 3))
	_last_crit = force_crit or randf() < cur_crit()
	if _last_crit:
		base *= CRIT_MULT
	return maxi(1, int(base))


func _deal(t: Mob, dmg: int) -> void:
	var crit_hit := _last_crit
	t.take_damage(dmg, self, crit_hit)
	if crit_hit:
		Util.float_text(get_parent(), t.global_position + Vector3(0, 2.6 * t.body_scale + 0.4, 0),
			"Крит!", Color(1, 0.85, 0.2), 1.4)


## Выпустить снаряд (стрела у лучника, болт у арбалета, шар у мага). on_hit: func(target: Mob, damage: int).
## miss — промах: снаряд долетает, но урона нет (обычный выстрел героя со статами).
func _shoot(t: Mob, dmg: int, size: float, on_hit: Callable, miss: bool = false) -> void:
	var p := Projectile.new()
	var k := "orb"
	if weapon_kind == "crossbow":
		k = "bolt"
	elif attack_kind == "ranged":
		k = "arrow"
	p.setup(t, self, dmg, _last_crit and not miss, k, _class_color(), size)
	p.on_hit = on_hit
	p.miss = miss
	get_parent().add_child(p)
	p.global_position = global_position + Vector3(0, 1.25, 0) + _forward() * 0.6
	var aim := t.aim_point()
	if p.is_shaft() and Vector2(aim.x - p.global_position.x, aim.z - p.global_position.z).length() > 0.05:
		p.look_at(aim, Vector3.UP)


func _class_color() -> Color:
	var c: Color = ClassData.cls(Game.class_id)["color"]
	return c


# ---------- Умения ----------

## id умения на кнопке "skill1"…"skill4" (Game.hero.slots; "" — пусто) или сам id умения.
func skill_id(slot: String) -> String:
	var i := SLOT_IDS.find(slot)
	if i < 0:
		return slot
	var slots: Array = Game.hero.get("slots", [])
	return String(slots[i]) if i < slots.size() else ""


## Назначить умение id на кнопку i (0..3); id = "" — очистить. Умение с другой кнопки переезжает.
func assign_slot(id: String, i: int) -> bool:
	if i < 0 or i >= HeroSkills.SLOTS:
		return false
	if id != "" and (HeroSkills.skill_level(Game.hero, id) <= 0 or HeroSkills.kind(id) == "passive"):
		return false
	var slots: Array = Game.hero["slots"]
	for k in slots.size():
		if String(slots[k]) == id:
			slots[k] = ""
	slots[i] = id
	Game.changed.emit()
	return true


## Почему умение на кнопке slot сейчас нельзя применить из-за оружия ("" — можно; пусто — тоже "").
func slot_block(slot: String) -> String:
	var sid := skill_id(slot)
	if sid == "" or not HeroSkills.is_skill(sid):
		return ""
	if HeroSkills.kind(sid) == "toggle" and HeroSkills.toggle_on(Game.hero, sid):
		return ""
	return HeroSkills.weapon_block(sid, weapon_kind, has_shield)


## Умение по кнопке "skill1"…"skill4" (или по id). true, если применено (переключаемое — включено/выключено).
func use_skill(slot: String) -> bool:
	var sid := skill_id(slot)
	if sid == "":
		if ClassData.is_wanderer(Game.class_id):
			message.emit(HeroSkills.WANDERER_NOTE)
		else:
			message.emit("Кнопка пуста: назначьте умение в окне героя (K)")
		return false
	if not HeroSkills.is_skill(sid):
		return false
	return _use_hero_skill(sid)


## Умение древа героя: изучено, подходит оружию, перезарядка готова, хватает MP.
func _use_hero_skill(sid: String) -> bool:
	var sk := HeroSkills.get_skill(sid)
	var sname := String(sk["name"])
	var n := HeroSkills.skill_level(Game.hero, sid)
	if n <= 0:
		message.emit("«%s» ещё не изучено" % sname)
		return false
	var k := HeroSkills.kind(sid)
	if k == "passive":
		message.emit("«%s» — пассивное умение, действует само" % sname)
		return false
	if not HeroSkills.is_ready(sid):
		message.emit("«%s»: действие умения появится в следующем обновлении" % sname)
		return false
	if k == "toggle":
		var on := not HeroSkills.toggle_on(Game.hero, sid)
		var err := set_toggle(sid, on)
		if err != "":
			message.emit("«%s»: %s" % [sname, err])
			return false
		return true
	var wb := HeroSkills.weapon_block(sid, weapon_kind, has_shield)
	if wb != "":
		message.emit("«%s»: %s" % [sname, wb])
		return false
	var left: float = skill_cd.get(sid, 0.0)
	if left > 0.0:
		message.emit("«%s» перезаряжается: %.1f с" % [sname, left])
		return false
	var cost := HeroSkills.mp_cost(sid, n)
	if mp < cost:
		message.emit("«%s»: не хватает MP (нужно %d)" % [sname, cost])
		return false
	var done := _fx.cast(sid, n, sk) if sk.has("fx") else _cast_hero(sid, n, sk)
	if not done:
		return false
	mp -= cost
	_mp_delay = MP_COMBAT_TIME
	skill_cd[sid] = HeroSkills.cooldown(sid, n) * (1.0 - cdr)
	stats_changed.emit()
	return true


## Перезарядка умения sid в секундах (у умений героя — по изученному уровню).
func skill_total_cd(sid: String) -> float:
	return HeroSkills.cooldown(sid, maxi(1, HeroSkills.skill_level(Game.hero, sid))) * (1.0 - cdr)


## Доля оставшейся перезарядки умения на кнопке "skill1"…"skill4": 0 = готово, 1 = только что использовано.
func cooldown_frac(slot: String) -> float:
	var sid := skill_id(slot)
	if sid == "":
		return 0.0
	var total := skill_total_cd(sid)
	var left: float = skill_cd.get(sid, 0.0)
	if total <= 0.0:
		return 0.0
	return clampf(left / total, 0.0, 1.0)


## Умение древа героя уровня n. false — не применилось (нет цели), MP и перезарядка не тратятся.
func _cast_hero(sid: String, n: int, sk: Dictionary) -> bool:
	var sname := String(sk["name"])
	var col: Color = sk["color"]
	var fx_parent := get_parent()
	match String(sk.get("target", "")):
		"dash":
			var t := _find_target(HeroSkills.field(sid, "dash", n))
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
			_anim_dash()
			Projectile.burst(fx_parent, global_position + Vector3(0, 1.0, 0), Color(0.5, 0.2, 0.7), 1.2, 0.3)
			_announce(sname, "")
		"self":
			shade_time = float(sk.get("buff_time", 10.0))
			shade_eva = HeroSkills.field_buff(sid, "eva", n)
			shade_atk = HeroSkills.field_buff(sid, "atk_pct", n)
			shade_crit = HeroSkills.field_buff(sid, "crit", n)
			add_effect("shade", shade_time, StatusEffects.source_hero_skill(sid))
			_anim_buff()
			Projectile.burst(fx_parent, global_position + Vector3(0, 1.0, 0), col, 2.0, 0.4)
			_announce(sname, "уклонение +%d%% на %d с" % [roundi(shade_eva * 100.0), roundi(shade_time)])
		"near":
			var t := _find_target(float(sk.get("radius", 6.0)))
			if t == null:
				return _no_target()
			_engage(t)
			_anim_cast()
			var sec := HeroSkills.field(sid, "sleep", n)
			t.sleep(sec, StatusEffects.source_hero_skill(sid))
			Projectile.burst(fx_parent, t.aim_point(), col, 1.3, 0.4)
			Util.float_text(fx_parent, t.global_position + Vector3(0, 2.4 * t.body_scale + 0.8, 0), "Сон", col.lightened(0.4))
			_announce(sname, "сон %.1f с" % sec)
		"melee":
			var t := _find_target(attack_range + MELEE_SKILL_REACH)
			if t == null:
				return _no_target()
			_engage(t)
			_anim_skill(sid)
			var mult := HeroSkills.field(sid, "mult", n)
			var flat := HeroSkills.field(sid, "flat", n)
			var force := bool(sk.get("crit", false))
			var dmg := _roll(mult, force, flat)
			_deal(t, dmg)
			Vfx.slash_arc(fx_parent, t.aim_point(),
				t.global_position - global_position, col, 1.2)
			for i in range(1, int(sk.get("hits", 1))):
				get_tree().create_timer(HIT_GAP * float(i)).timeout.connect(_late_hit.bind(t, mult, flat, force, false))
			if sk.has("heal"):
				heal(maxi(1, roundi(float(dmg) * float(sk["heal"]))))
			if sk.has("fear") and not t.is_dead:
				t.frighten(HeroSkills.field(sid, "fear", n), global_position, StatusEffects.source_hero_skill(sid))
				Util.float_text(fx_parent, t.global_position + Vector3(0, 2.4 * t.body_scale + 0.8, 0), "Страх!",
					col.lightened(0.4))
			_announce(sname, "")
		"ranged":
			var t := _find_target(attack_range)
			if t == null:
				return _no_target()
			_engage(t)
			_anim_attack()
			var mult := HeroSkills.field(sid, "mult", n)
			var flat := HeroSkills.field(sid, "flat", n)
			var force := bool(sk.get("crit", false))
			var cb := func(hit: Mob, _dealt: int) -> void:
				_bolt_effects(hit, sid, n)
			_shoot(t, _roll(mult, force, flat), 1.3, cb)
			for i in range(1, int(sk.get("hits", 1))):
				get_tree().create_timer(HIT_GAP * float(i)).timeout.connect(
					_late_shot.bind(t, mult, flat, force, Callable(), false))
			_announce(sname, "")
		_:
			return false
	return true


## Что делает болт умения при попадании: отбрасывание и удержание, урон со временем.
func _bolt_effects(hit: Mob, sid: String, n: int) -> void:
	if hit == null or not is_instance_valid(hit) or hit.is_dead:
		return
	var sk := HeroSkills.get_skill(sid)
	var fx_parent := get_parent()
	if sk.has("knock"):
		hit.knock_back(global_position, float(sk["knock"]))
		hit.stun(float(sk.get("root", 0.0)), StatusEffects.source_hero_skill(sid))
		Util.float_text(fx_parent, hit.global_position + Vector3(0, 2.4 * hit.body_scale + 0.8, 0), "Отброшен!",
			Color(1, 0.85, 0.5))
	if sk.has("dot"):
		var dps := float(cur_atk()) * HeroSkills.field(sid, "dot", n) + HeroSkills.field(sid, "dot_flat", n)
		hit.add_dot(sid, dps, float(sk.get("dot_time", 10.0)), self, bool(sk.get("no_regen", false)),
			StatusEffects.source_hero_skill(sid))


## Анимация умения ближнего боя (SKILL_ANIM).
func _anim_skill(sid: String) -> void:
	match String(SKILL_ANIM.get(sid, "attack")):
		"bash":
			_anim_bash()
		"dash":
			_anim_dash()
		"spin":
			_anim_spin()
		"cast":
			_anim_cast()
		_:
			_anim_attack()


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


func take_damage(amount: int, attacker: Node3D) -> void:
	# «Бессмертие» админ-панели: урон не проходит
	if AdminPanel.god:
		return
	# Уклонение — только от ударов зверей
	if attacker is Mob and cur_eva() > 0.0 and randf() < cur_eva():
		Util.float_text(get_parent(), global_position + Vector3(0, 2.4, 0), "Уклонение", Color(0.7, 0.95, 1.0))
		return
	# Блок щитом: удар зверя приходится в щит
	if attacker is Mob and block > 0.0 and randf() < block:
		Util.float_text(get_parent(), global_position + Vector3(0, 2.4, 0), "Блок", Color(0.75, 0.85, 1.0))
		return
	amount = maxi(1, amount - int((defense + aura_def) * 0.5))
	if guard_time > 0.0:
		amount = maxi(1, roundi(float(amount) * (1.0 - guard)))
	if skill_guard > 0.0:
		amount = maxi(1, roundi(float(amount) * (1.0 - skill_guard)))
	hp -= amount
	regen_delay = 6.0
	if _has_model():
		_model.play_hit()
	Util.float_text(get_parent(), global_position + Vector3(0, 2.4, 0), str(amount), Color(1, 0.3, 0.3))
	Vfx.hit_spark(get_parent(), global_position + Vector3(0, 1.2, 0), Color(1, 0.4, 0.35), 0.8)
	if hp <= 0:
		hp = max_hp
		mp = max_mp
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
	# Очки умений героя копятся вместе с опытом (JP_PER_LEVEL за уровень, по долям за каждое убийство)
	if amount > 0:
		HeroSkills.add_jp(Game.hero, float(HeroSkills.JP_PER_LEVEL) * float(amount) / float(Game.xp_to_next(Game.level)))
	Game.xp += amount
	while Game.xp >= Game.xp_to_next(Game.level):
		Game.xp -= Game.xp_to_next(Game.level)
		Game.level += 1
		recalc_stats()
		hp = max_hp
		mp = max_mp
		message.emit("Новый уровень: %d!" % Game.level)
		Vfx.level_up(get_parent(), global_position)
	Game.changed.emit()
	stats_changed.emit()


# ---------- Внешний вид: аниме-модель (CharacterModel) ----------

func _build_model() -> void:
	if _model != null and is_instance_valid(_model):
		_model.queue_free()
	_model = CharacterModel.new()
	_model.name = "Model"
	_model.setup(CharacterModel.spec_for(Game.race_id, Game.class_id, weapon_kind, Game.gender, has_shield))
	_weapon_kind = _model.weapon_kind
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


## Рывок к цели (Шаг тени).
func _anim_dash() -> void:
	if _has_model():
		_model.play_dash()


## Заклинание (сонная пыльца и т. п.).
func _anim_cast() -> void:
	if _has_model():
		_model.play_cast()


## Подбор добычи: присесть и поднять (модель сама решает, уместно ли сейчас).
func play_pickup() -> void:
	if _has_model():
		_model.play_pickup()


func _update_guard_fx() -> void:
	if _guard_fx != null and is_instance_valid(_guard_fx):
		_guard_fx.visible = guard_time > 0.0
