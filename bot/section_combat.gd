extends BotSection
## Раздел «Бой и умения»: для каждой профессии (быстрый проход — QUICK_JOBS: искры Воина, тела зверей Неофита,
## воскрешение и жертва питомца Зверолова; полный — все 9) — профессия как в админ-панели (стартовое оружие надето),
## 40 ур., все доступные умения, питомец-волк, четыре атакующих умения — на кнопках; на поле — зверь с огромным
## запасом HP (не умирает за проверку): обычные атаки (урон есть), переключаемые — включить и выключить, каждое
## активное умение — с нужным оружием (надевается само), с подготовкой особых механик (искры, тело зверя, погибший
## питомец), каст — настоящий (ждём конца), затем — эффект: урон, статус зверя, лечение, усиление, зона, рывок,
## питомец. Не применилось — ошибка с причиной из сообщения игры.

const QUICK_JOBS := ["warrior", "neophyte", "beastmaster"]
const ALL_JOBS := ["warrior", "shaman", "conjurer", "swordsman", "wizard", "beastmaster", "assassin", "adept", "neophyte"]
const LEVEL := 40
const MOB := "wolf"
const MOB_LEVEL := 38
const BIG_HP := 3000000
const PET := "wolf"
const PET_LEVEL := 30
## Зверь в стольких м перед героем.
const MOB_DIST := 2.6
## Ждать эффекта умения не дольше, с.
const EFFECT_WAIT := 2.5
## Наборы оружия [основная рука, вторая рука]: первый, что подходит умению и профессии, надевается.
const LOADOUTS := [
	["weapon_dagger_r1", "weapon_dagger_r1"], ["weapon_dagger_r1", ""], ["weapon_sword_1h_r1", "weapon_shield_r1"],
	["weapon_sword_1h_r1", "weapon_sword_1h_r1"], ["weapon_sword_1h_r1", ""], ["crossbow_starter", ""],
	["weapon_bow_r1", ""], ["weapon_axe_1h_r1", "weapon_axe_1h_r1"], ["weapon_axe_1h_r1", ""], ["weapon_axe_2h_r1", ""],
	["weapon_mace_1h_r1", "weapon_shield_r1"], ["weapon_mace_1h_r1", ""], ["weapon_mace_2h_r1", ""],
	["weapon_staff_1h_r1", "weapon_shield_r1"], ["weapon_staff_1h_r1", ""], ["weapon_staff_2h_r1", ""],
	["weapon_dagger_r1", "weapon_shield_r1"], ["weapon_sword_2h_r1", ""], ["weapon_spear_r1", ""],
]
const MOB_TIMERS := ["stun_time", "sleep_time", "fear_time", "slow_time", "blind_time", "miss_time", "vuln_time",
	"weak_time", "taunt_time"]

var mob: Mob = null
var _anchor := Vector3.ZERO
var _ok := false
var _sid := ""
var _hp0 := 0
var _tver := 0
var _php := 0
var _pver := 0
var _pbonus := 0
var _ppos := Vector3.ZERO
var _pet_alive := false
var _pet_hp := 0
var _pet_ver := 0
var _mp_floor := 0
var _applied := 0
var _tried := 0
var _failed: PackedStringArray = PackedStringArray()


func id() -> String:
	return "combat"


func _build() -> void:
	var jobs: Array = QUICK_JOBS if quick else ALL_JOBS
	for j in jobs:
		var job := String(j)
		var jn := ClassData.job_name(job)
		do("%s: профессия, 40 ур., умения" % jn, _start_job.bind(job))
		wait(0.5)
		do("%s: обычные атаки" % jn, _basic_start)
		wait(1.6)
		do("%s: урон обычными атаками" % jn, _basic_check.bind(job))
		do("%s: переключаемые" % jn, _toggles)
		for s in _actives(job):
			var sid := String(s)
			var nm := String(HeroSkills.get_skill(sid, job).get("name", sid))
			do("%s: «%s»" % [jn, nm], _cast.bind(sid))
			until("каст «%s»" % nm, _cast_done, 6.0)
			do("%s: «%s» — итог каста" % [jn, nm], _after_cast)
			until("эффект «%s»" % nm, _effect_seen, EFFECT_WAIT)
		do("%s: итог" % jn, _job_done.bind(job))


## Активные умения профессии, готовые к применению, — по нужному оружию (меньше переодеваний).
static func _actives(job: String) -> Array:
	var res: Array = []
	for id_v in HeroSkills.list_for(job):
		var sid := String(id_v)
		if HeroSkills.kind(sid) != "active" or not HeroSkills.is_ready(sid):
			continue
		res.append(sid)
	res.sort_custom(func(a: String, b: String) -> bool:
		var wa := str(HeroSkills.weapon_need(a, job))
		var wb := str(HeroSkills.weapon_need(b, job))
		return wa < wb if wa != wb else a < b)
	return res


static func _handlers(sid: String) -> PackedStringArray:
	var res := PackedStringArray()
	for item in HeroSkills.get_skill(sid).get("fx", []):
		var e: Dictionary = item
		if String(e.get("do", "")) == "special":
			res.append(String(e.get("handler", "")))
	return res


func _nm(sid: String) -> String:
	return String(HeroSkills.get_skill(sid).get("name", sid))


# ---------- Профессия ----------

func _start_job(job: String) -> void:
	bot.clear_spawned()
	mob = null
	_applied = 0
	_tried = 0
	_failed = PackedStringArray()
	JobFxNeophyte.corpses.clear()
	_zones_clear()
	fresh_bag(1000)
	hero(job, LEVEL)
	bot.learn_all()
	check(Game.class_id == job, "профессия «%s»" % ClassData.job_name(job))
	var p := player()
	if p == null:
		return
	# Питомец — волк (умения профессий через питомца)
	if Game.pets.is_empty():
		bot.add_pet(PET, PET_LEVEL)
	_anchor = to_arena()
	_ensure_pet()
	# Четыре атакующих умения — на кнопки (как играл бы игрок)
	var picked := 0
	for k in HeroSkills.SLOTS:
		p.assign_slot("", k)
	for s in _actives(job):
		var sid := String(s)
		var use := String(HeroSkills.get_skill(sid).get("use", ""))
		if use == "self" or use == "pet" or HeroSkills.weapon_block(sid, p.weapon_kind, p.has_shield) != "":
			continue
		if p.assign_slot(sid, picked):
			picked += 1
		if picked >= HeroSkills.SLOTS:
			break
	p.refresh_skills()
	check(picked >= 1, "%s: атакующих умений на кнопках — %d" % [ClassData.job_name(job), picked])
	_arrange()


## Питомец жив, призван, рядом, «За мной» (не бьёт зверя сам — урон зверя от героя), HP полное.
func _ensure_pet() -> void:
	if Game.pets.is_empty():
		bot.add_pet(PET, PET_LEVEL)
	var i := maxi(Game.active_pet, 0)
	if i >= Game.pets.size():
		i = 0
	var rec: Dictionary = Game.pets[i]
	if bool(rec.get("dead", false)):
		rec["dead"] = false
		rec["hp"] = -1
		rec["mp"] = -1
	if pet() == null:
		pets().summon(i)
	var pt := pet()
	if pt == null:
		return
	pt.set_mode("follow")
	pt.hp = pt.max_hp
	pt.mp = pt.max_mp
	var p := player()
	if p != null:
		pt.global_position = ground(p.global_position.x + 1.4, p.global_position.z + 0.8)
		pt.velocity = Vector3.ZERO


## Зверь перед героем: огромный запас HP, без статусов, целится в героя; герой — у anchor, HP и MP полные.
func _arrange() -> void:
	var p := player()
	if p == null:
		return
	var tpos := ground(_anchor.x, _anchor.z - MOB_DIST)
	if not alive(mob):
		mob = bot.spawn(MOB, MOB_LEVEL, tpos)
	if mob == null:
		return
	JobFxNeophyte.clear_mods(mob)
	for f in MOB_TIMERS:
		mob.set(String(f), 0.0)
	mob.dots.clear()
	mob.effects.clear()
	mob.max_hp = BIG_HP
	mob.hp = BIG_HP
	mob.global_position = tpos
	mob.home = tpos
	mob.velocity = Vector3.ZERO
	mob.target = p
	mob.returning = false
	_zones_clear()
	p.global_position = ground(_anchor.x, _anchor.z)
	p.velocity = Vector3.ZERO
	p.hp = p.max_hp
	p.mp = p.max_mp
	p.attack_cd = 0.0
	p.select_target(mob)


func _zones_clear() -> void:
	if bot.main == null:
		return
	for z in bot.get_tree().get_nodes_in_group("skill_zones"):
		(z as Node).queue_free()


# ---------- Обычные атаки ----------

func _basic_start() -> void:
	_arrange()
	_hp0 = mob.hp if alive(mob) else 0
	bot.set_tick(_attack_tick)


func _attack_tick(_dt: float) -> void:
	var p := player()
	if p != null and alive(mob):
		if p.current_target != mob:
			p.select_target(mob)
		p.try_attack()


func _basic_check(job: String) -> void:
	bot.set_tick(Callable())
	var p := player()
	var w := "%s%s" % [ItemData.item_name(Game.weapon), " + " + ItemData.item_name(Game.offhand) if Game.offhand != "" else ""]
	check(alive(mob) and mob.hp < _hp0, "%s: обычные атаки (%s) наносят урон: %d" % [ClassData.job_name(job), w,
		_hp0 - (mob.hp if alive(mob) else _hp0)])
	shot("Бой %s" % ClassData.job_name(job))
	if p != null:
		p.attack_cd = 0.0


# ---------- Переключаемые ----------

func _toggles() -> void:
	var p := player()
	if p == null:
		return
	var n_on := 0
	var n_all := 0
	for id_v in HeroSkills.list_for(Game.class_id):
		var sid := String(id_v)
		if HeroSkills.kind(sid) != "toggle" or HeroSkills.skill_level(Game.hero, sid) <= 0 or not HeroSkills.is_ready(sid):
			continue
		n_all += 1
		if not _equip_for(sid):
			continue
		_ensure_pet()
		p.mp = p.max_mp
		var err := p.set_toggle(sid, true)
		if check(err == "" and HeroSkills.toggle_on(Game.hero, sid), "переключаемое «%s» включается %s" % [_nm(sid), err]):
			n_on += 1
		p.set_toggle(sid, false)
		check(not HeroSkills.toggle_on(Game.hero, sid), "переключаемое «%s» выключается" % _nm(sid))
	_all_toggles_off()
	note("%s: переключаемых включено %d из %d" % [ClassData.job_name(Game.class_id), n_on, n_all])


func _all_toggles_off() -> void:
	var p := player()
	if p == null:
		return
	var tg: Dictionary = Game.hero.get("toggles", {})
	for k in tg.keys():
		p.set_toggle(String(k), false)


# ---------- Оружие ----------

## Надеть оружие, подходящее умению sid и профессии (LOADOUTS). true — подходит.
func _equip_for(sid: String) -> bool:
	var p := player()
	if p == null:
		return false
	if HeroSkills.weapon_ok(sid, p.weapon_kind, p.has_shield):
		return true
	for e in LOADOUTS:
		var lo: Array = e
		var a := String(lo[0])
		var b := String(lo[1])
		if not ItemData.weapon_fits(a, Game.class_id) or (b != "" and not ItemData.weapon_fits(b, Game.class_id)):
			continue
		if not _kind_fits(sid, a, b):
			continue
		var need_a := 2 if a == b else 1
		if Game.inventory.count(a) < need_a:
			Game.inventory.add(a, need_a - Game.inventory.count(a))
		if b != "" and b != a and Game.inventory.count(b) < 1:
			Game.inventory.add(b, 1)
		if Game.offhand != "":
			p.unequip_offhand()
		if p.equip(a) != "":
			continue
		if b != "" and p.equip(b, true) != "":
			continue
		if HeroSkills.weapon_ok(sid, p.weapon_kind, p.has_shield):
			return true
	return check(false, "оружие для «%s» (%s) не нашлось у профессии «%s»" % [_nm(sid), HeroSkills.weapon_name(sid),
		ClassData.job_name(Game.class_id)])


## Подойдёт ли набор (a, b) умению — по виду хвата, без переодевания.
static func _kind_fits(sid: String, a: String, b: String) -> bool:
	var shield := b != "" and ItemData.is_shield(b)
	var grip := ItemData.grip_kind(a, "" if shield else b)
	return HeroSkills.weapon_ok(sid, grip, shield)


# ---------- Активные умения ----------

## Подготовить и применить умение sid с кнопки 1 (как касание): оружие, питомец, особые механики, зверь перед героем.
func _cast(sid: String) -> void:
	_ok = false
	_sid = sid
	_tried += 1
	var p := player()
	if p == null:
		return
	p.cancel_cast("")
	if not check(HeroSkills.skill_level(Game.hero, sid) > 0, "«%s» изучено" % _nm(sid)):
		_failed.append(_nm(sid))
		return
	if not _equip_for(sid):
		_failed.append(_nm(sid))
		return
	_ensure_pet()
	_arrange()
	var hs := _handlers(sid)
	if Game.class_id == "warrior":
		# Искры духа: «Разжечь искру» — при пустом запасе, остальным — полный запас
		JobFxWarrior.add_sparks(p._fx, -9 if hs.has("spark_gain") else 9)
	if hs.has("ne_corpse_hp") or hs.has("ne_corpse_mp"):
		# Тело зверя рядом: слабый зверь убит героем
		var weak := bot.spawn("pheasant", 1, ground(p.global_position.x + 2.5, p.global_position.z))
		kill(weak)
	if hs.has("revive_pet"):
		# Воскрешение: питомец погиб («Нить жизни» спасает один раз — второй удар)
		for k in 3:
			var pt := pet()
			if pt != null:
				pt.take_damage(99999999, null)
	# Лечение и возврат MP видны: HP героя и питомца, MP героя — не полные
	p.hp = int(float(p.max_hp) * 0.6)
	var pt2 := pet()
	if pt2 != null:
		pt2.hp = maxi(1, int(float(pt2.max_hp) * 0.6))
	if hs.has("ne_corpse_mp") or hs.has("sw_mana"):
		p.mp = int(float(p.max_mp) * 0.5)
	else:
		p.mp = p.max_mp
	_snapshot(sid)
	p.assign_slot(sid, 0)
	p.skill_cd.erase(sid)
	p.attack_cd = 0.0
	_ok = p.use_skill("skill1")
	if not check(_ok, "«%s» применено%s" % [_nm(sid), "" if _ok else " — " + last_msg()]):
		_failed.append(_nm(sid))


## Состояние до умения: зверь, герой, питомец (что изменится — эффект).
func _snapshot(sid: String) -> void:
	var p := player()
	_hp0 = mob.hp if alive(mob) else 0
	_tver = mob.effects.version if alive(mob) else 0
	_php = p.hp
	_pver = p.effects.version
	_pbonus = p.timed_bonus.size()
	_ppos = p.global_position
	var pt := pet()
	_pet_alive = pt != null
	_pet_hp = pt.hp if pt != null else 0
	_pet_ver = pt.effects.version if pt != null else 0
	_mp_floor = p.mp - HeroSkills.mp_cost(sid, HeroSkills.skill_level(Game.hero, sid))


func _cast_done() -> bool:
	var p := player()
	return not _ok or p == null or p.casting == ""


func _after_cast() -> void:
	if not _ok:
		return
	var p := player()
	if p == null:
		return
	if p.casting != "":
		p.cancel_cast("")
		_ok = false
	elif not p.cast_ok and HeroSkills.cast_time(_sid, HeroSkills.skill_level(Game.hero, _sid)) > 0.0:
		_ok = false
	if not check(_ok, "«%s»: каст завершён%s" % [_nm(_sid), "" if _ok else " — " + last_msg()]):
		_failed.append(_nm(_sid))
		return
	_applied += 1


## Эффект умения заметен: урон или статус зверя, лечение или усиление героя, питомец, зона, рывок, MP.
func _effect_seen() -> bool:
	if not _ok:
		return true
	var p := player()
	if p == null:
		return true
	if not alive(mob) or mob.hp < _hp0 or mob.effects.version != _tver:
		return true
	if p.hp > _php or p.effects.version != _pver or p.timed_bonus.size() != _pbonus or p.mp > _mp_floor:
		return true
	if Vector2(p.global_position.x - _ppos.x, p.global_position.z - _ppos.z).length() > 1.2:
		return true
	var pt := pet()
	if (pt != null) != _pet_alive:
		return true
	if pt != null and (pt.hp != _pet_hp or pt.effects.version != _pet_ver):
		return true
	return not bot.get_tree().get_nodes_in_group("skill_zones").is_empty()


func _job_done(job: String) -> void:
	_all_toggles_off()
	var txt := "%s: активных умений сработало %d из %d" % [ClassData.job_name(job), _applied, _tried]
	if not _failed.is_empty():
		txt += "; не сработали: " + ", ".join(_failed)
	note(txt)
	bot.clear_spawned()
	mob = null
	_zones_clear()
	var p := player()
	if p != null:
		p.cancel_cast("")
		p.select_target(null)
