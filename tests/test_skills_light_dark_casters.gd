extends "res://tests/test_base.gd"
## Умения Мечника, Волшебника и Неофита (этап 2): каждое умение древа готово (HeroSkills.is_ready, в карточке нет
## «в разработке»), пассивные и переключаемые меняют свой показатель (атака, защита, HP, блок, получаемый урон,
## статы, урон умений, незаметность, скорость атаки…), каждое активное применяется с кнопки — тратит MP, уходит на
## перезарядку и даёт свой эффект: урон по зверю, лечение, статус на звере (оглушение, сон, замедление, провокация,
## ослабление, промахи, защита / маг. защита ниже, удары реже, обездвиживание), урон со временем, усиление героя.
## Особые механики: зоны на земле («Пылающая земля», «Грозовой круг», «Топь» — видимый круг бьёт зверей раз
## в секунду), серия снарядов («Град тьмы», «Шквал света»), тело убитого зверя («Последний вздох», «Остаток силы»;
## без тела — не применяется), «Кровный дар» (HP героя → питомцу), «Возвращение души» (воскрешение питомца; без
## погибшего — не применяется), «Живительный свет» (лечение сразу и со временем), «Натиск щита» (рывок), «Разбитая
## воля» (MP из урона), «Колючий щит» (ответный урон), «Сияющее лезвие» / «Теневая печать» (урон стихией обычной
## атаки), «Благословенный клинок» и «Огненное сердце» (урон умений выше), ослабления зверя снимаются по времени.
## Герой 40 ур. под «бессмертием», звери — волки 30 ур. с огромным запасом HP (не умирают за проверку).

const BIG_HP := 400000
const JOBS := ["swordsman", "wizard", "neophyte"]
## Сколько кадров ждать эффекта (снаряд, тик зоны).
const POLL_MAX := 150

var plan: Array[Callable] = []
var anchor := Vector3.ZERO
var m1: Mob = null
var hp1 := 0
var pdef1 := 0
var mdef1 := 0
var every1 := 0.0
var php0 := 0
var pmp0 := 0
var pet_hp0 := 0
var pos0 := Vector3.ZERO
var polls := 0
var cur := ""
var actives: Array[String] = []


func race_class() -> Array:
	return ["light_elf", "swordsman"]


func hero_level() -> int:
	return 40


func before_start() -> void:
	AdminPanel.god = true
	game.add_pet("wolf", PetData.stage_name("wolf", 30), 30)
	game.active_pet = 0


## Шаг плана возвращает, сколько кадров подождать; −1 — повторить этот шаг в следующем кадре (ждём эффекта).
func run_step() -> void:
	if plan.is_empty():
		_build_plan()
	if step >= plan.size():
		AdminPanel.god = false
		ok_done()
		return
	var c: Callable = plan[step]
	var w := int(c.call())
	if w < 0:
		return
	step += 1
	wait = w


func _build_plan() -> void:
	plan = [_start]
	for job in JOBS:
		plan.append(_start_job.bind(job))
		plan.append(_passives)
		plan.append(_toggles)
		for sid in _active_ids(job):
			plan.append(_cast_step.bind(sid))
			plan.append(_poll_step.bind(sid))
		if job == "wizard":
			plan.append(_edge_attack.bind("radiant_edge"))
			plan.append(_edge_check.bind("light_hits"))
		if job == "neophyte":
			plan.append(_edge_attack.bind("shadow_seal"))
			plan.append(_edge_check.bind("dark_hits"))
			plan.append(_mod_expiry)
			plan.append(_mod_expiry_check)
			plan.append(_balance)


## Активные умения профессии (по древу).
func _active_ids(job: String) -> Array[String]:
	var res: Array[String] = []
	for id in HeroSkills.list_for(job):
		if HeroSkills.kind(String(id)) == "active":
			res.append(String(id))
	return res


# ---------- Помощники ----------

func _ground(pos: Vector3) -> Vector3:
	if IslandWorld.current != null:
		pos.y = IslandWorld.current.height_at(pos.x, pos.z) + 0.1
	return pos


func _pet() -> Pet:
	var pm: PetManager = main.pets
	if is_instance_valid(pm.active_pet) and not pm.active_pet.is_down:
		return pm.active_pet
	return null


## Питомец жив и призван (в режиме «За мной» — не бьёт зверя сам), HP — полное.
func _ensure_pet() -> void:
	var rec: Dictionary = game.pets[0]
	if bool(rec.get("dead", false)):
		rec["dead"] = false
		rec["hp"] = -1
	if _pet() == null:
		main.pets.summon(0)
	var pet := _pet()
	if pet != null:
		pet.set_mode("follow")
		pet.hp = pet.max_hp
		pet.global_position = _ground(main.player.global_position + Vector3(1.5, 0, 0))


## Зверь у anchor: полный HP, без статусов и ослаблений, целится в героя; герой — в off от зверя, полные HP и MP.
func _arrange(off: Vector3) -> void:
	var p: Player = main.player
	if not mob_ok(m1):
		m1 = main.spawn_mob("wolf", 30, _ground(anchor))
	m1.max_hp = BIG_HP
	m1.hp = BIG_HP
	JobFxNeophyte.clear_mods(m1)
	m1.global_position = _ground(anchor)
	m1.velocity = Vector3.ZERO
	m1.target = p
	m1.returning = false
	for f in ["stun_time", "sleep_time", "fear_time", "slow_time", "blind_time", "miss_time", "vuln_time", "weak_time",
			"taunt_time"]:
		m1.set(String(f), 0.0)
	m1.dots.clear()
	m1.effects.clear()
	for z in get_tree().get_nodes_in_group("skill_zones"):
		z.queue_free()
	hp1 = m1.hp
	pdef1 = m1.pdef
	mdef1 = m1.mdef
	every1 = m1.attack_every
	p.global_position = _ground(anchor + off)
	p.velocity = Vector3.ZERO
	p.hp = p.max_hp
	p.mp = p.max_mp
	p.regen_delay = 100.0
	p.attack_cd = 0.0
	p.select_target(m1)


## Надеть оружие (выдать, если нет). second — во вторую руку.
func _equip(id: String, second: bool = false) -> bool:
	var p: Player = main.player
	if game.inventory.count(id) < (2 if second else 1):
		game.inventory.add(id, 1)
	return p.equip(id, second) == ""


## Оружие, подходящее умению sid (по первой группе), если надетое не подходит.
func _equip_for(sid: String) -> void:
	var p: Player = main.player
	if HeroSkills.weapon_ok(sid, p.weapon_kind, p.has_shield):
		return
	var need := HeroSkills.weapon_need(sid)
	match String(need[0]):
		"shield":
			_equip("weapon_sword_1h_r1")
			_equip("weapon_shield_r1", true)
		"mace":
			_equip("weapon_mace_1h_r1")
			if game.class_id == "swordsman":
				_equip("weapon_shield_r1", true)
		"sword":
			_equip("weapon_sword_1h_r1")
		"staff":
			_equip("weapon_staff_2h_r1")
		"dual_swords":
			_equip("weapon_sword_1h_r1")
			_equip("weapon_sword_1h_r1", true)
		"sword_2h":
			_equip("weapon_sword_2h_r1")
	check(HeroSkills.weapon_ok(sid, p.weapon_kind, p.has_shield), "оружие для «%s»: %s" % [_nm(sid), p.weapon_kind])


## Оружие профессии по умолчанию: Мечник — булава и щит (все умения щита и булавы), маги — посох.
func _default_weapon() -> void:
	if game.class_id == "swordsman":
		_equip("weapon_mace_1h_r1")
		_equip("weapon_shield_r1", true)
	else:
		_equip("weapon_staff_2h_r1")


func _nm(sid: String) -> String:
	return String(HeroSkills.get_skill(sid).get("name", sid))


## Показатель героя, который меняет бонус key.
func _metric(key: String) -> float:
	var p: Player = main.player
	match key:
		"hp_pct", "hp_flat", "hp_from_eva":
			return float(p.max_hp)
		"mp_pct", "mp_from_eva":
			return float(p.max_mp)
		"def_pct", "def_flat":
			return float(p.defense)
		"mdef_flat":
			return float(p.mdef)
		"atk_pct", "atk_flat":
			return float(p.atk)
		"matk_pct":
			return float(p.matk)
		"eva":
			return p.eva
		"crit":
			return p.crit
		"aspd":
			return p.aspd
		"block":
			return p.block
		"guard":
			return p.skill_guard
		"cdr":
			return p.cdr
		"stealth":
			return p.stealth
		"speed_pct":
			return p.speed
		"basic_pct":
			return p.basic_mult
		"str", "vit", "agi", "int", "wis", "dex", "luck":
			return float(p.hero_stats["stats"][key])
	return p._fx.bonus(key)


## Все показатели бонусов умения sid.
func _metrics(sid: String) -> Dictionary:
	var res := {}
	for key in HeroSkills.get_skill(sid).get("bonus", {}):
		res[key] = _metric(String(key))
	return res


# ---------- Шаги ----------

func _start() -> int:
	var w := find_mob("wolf")
	check(w != null, "волк для точки проверки")
	anchor = w.home
	if IslandWorld.current != null:
		anchor = AdminPanel.free_spot(IslandWorld.current, Vector2(w.home.x, w.home.z))
		check(not IslandWorld.current.in_safe_zone(anchor), "точка проверки вне безопасных зон")
	_arrange(Vector3(0, 0, 2.0))
	return 2


## Профессия job, 40 ур., всё древо изучено полностью; все умения готовы (этап 2), в карточках нет «в разработке».
func _start_job(job: String) -> int:
	var p: Player = main.player
	game.level = 40
	become_job(job)
	game.hero["jp"] = 9000
	HeroSkills.learn_all(game.hero, job, game.level)
	p.refresh_skills()
	var bad := ""
	for id in HeroSkills.list_for(job):
		var sid := String(id)
		if not HeroSkills.is_ready(sid):
			bad += " " + sid
		if HeroSkills.skill_level(game.hero, sid) != HeroSkills.max_level(sid, job):
			bad += " (не изучено) " + sid
		for n in range(1, HeroSkills.max_level(sid, job) + 1):
			var txt := HeroSkills.effect_text(sid, n)
			if txt == "" or txt.contains("следующем обновлении") or txt.contains("{"):
				bad += " (текст %d) %s" % [n, sid]
	check(bad == "", "%s: все %d умений изучены и готовы%s" % [ClassData.job_name(job), HeroSkills.list_for(job).size(), bad])
	_default_weapon()
	_ensure_pet()
	_arrange(Vector3(0, 0, 2.0))
	return 2


## Пассивки: без умения (уровень 0) показатель ниже, чем с ним.
func _passives() -> int:
	var p: Player = main.player
	var skills: Dictionary = game.hero["skills"]
	for id in HeroSkills.list_for(game.class_id):
		var sid := String(id)
		if HeroSkills.kind(sid) != "passive":
			continue
		_equip_for(sid)
		var n := int(skills[sid])
		skills[sid] = 0
		p.refresh_skills()
		var before := _metrics(sid)
		skills[sid] = n
		p.refresh_skills()
		var after := _metrics(sid)
		for key in before:
			check(float(after[key]) > float(before[key]), "«%s»: %s %.3f → %.3f" % [_nm(sid), key, float(before[key]),
				float(after[key])])
	_default_weapon()
	return 1


## Переключаемые: включение тратит MP, ставит значок и поднимает показатель; выключение возвращает.
func _toggles() -> int:
	var p: Player = main.player
	for id in HeroSkills.list_for(game.class_id):
		var sid := String(id)
		if HeroSkills.kind(sid) != "toggle":
			continue
		_equip_for(sid)
		p.mp = p.max_mp
		var before := _metrics(sid)
		var mp0 := p.mp
		check(p.set_toggle(sid, true) == "", "«%s» включено" % _nm(sid))
		check(p.mp < mp0 and p.effects.has("toggle:" + sid), "«%s»: MP %d → %d, значок у полоски HP" % [_nm(sid), mp0, p.mp])
		var after := _metrics(sid)
		for key in before:
			check(float(after[key]) > float(before[key]), "«%s»: %s %.3f → %.3f" % [_nm(sid), key, float(before[key]),
				float(after[key])])
		if sid == "blessed_blade":
			check(p._fx.skill_factor("holy_strike") > 1.0 and p._fx.skill_factor("") == 1.0,
				"«Благословенный клинок»: урон умений ×%.2f" % p._fx.skill_factor("holy_strike"))
		if String(HeroSkills.get_skill(sid).get("aura", "")) != "":
			var pa := HeroSkills.pet_aura_bonuses(game.hero, game.class_id, p.weapon_kind, p.has_shield)
			check(not pa.is_empty(), "«%s» — аура и для питомца" % _nm(sid))
		check(p.set_toggle(sid, false) == "" and not p.effects.has("toggle:" + sid), "«%s» выключено" % _nm(sid))
	_default_weapon()
	return 1


## Подготовка и применение активного умения sid с кнопки 1: MP списано по цене (или больше / меньше — у тех, что
## возвращают MP), перезарядка, повтор сразу не срабатывает.
func _cast_step(sid: String) -> int:
	var p: Player = main.player
	cur = sid
	polls = 0
	var hs := _handlers(sid)
	var dist := 2.0
	if hs.has("sw_rush"):
		dist = 8.0
	_equip_for(sid)
	_ensure_pet()
	_arrange(Vector3(0, 0, dist))
	pos0 = p.global_position
	# Подготовка особых механик
	if hs.has("ne_corpse_hp") or hs.has("ne_corpse_mp"):
		# Без тела зверя рядом — не применяется
		JobFxNeophyte.corpses.clear()
		p.assign_slot(sid, 0)
		var mp_a := p.mp
		check(not use_now(p, "skill1") and p.mp == mp_a and float(p.skill_cd.get(sid, 0.0)) == 0.0,
			"«%s» без тела зверя не применяется: %s" % [_nm(sid), main.hud._msg_label.text])
		var weak: Mob = main.spawn_mob("pheasant", 1, _ground(p.global_position + Vector3(2.5, 0, 0)))
		weak.take_damage(weak.hp + 10, p)
		check(JobFxNeophyte.nearest_corpse(p.global_position, JobFxNeophyte.CORPSE_RANGE) >= 0,
			"убитый зверь оставил тело рядом")
		p.hp = p.max_hp / 2
		p.mp = p.max_mp / 2
	if hs.has("revive_pet"):
		p.assign_slot(sid, 0)
		var mp_b := p.mp
		check(not use_now(p, "skill1") and p.mp == mp_b, "«%s» без погибшего питомца не применяется" % _nm(sid))
		_pet().take_damage(999999, null)
		check(bool(game.pets[0].get("dead", false)) and _pet() == null, "питомец погиб")
	if hs.has("ne_blood_gift"):
		_pet().hp = _pet().max_hp / 3
		pet_hp0 = _pet().hp
	if _has_do(sid, "heal") or hs.has("wz_renew"):
		p.hp = p.max_hp / 2
		var pet := _pet()
		if pet != null:
			pet.hp = pet.max_hp
	php0 = p.hp
	pmp0 = p.mp
	var cost := HeroSkills.mp_cost(sid, HeroSkills.skill_level(game.hero, sid))
	check(p.assign_slot(sid, 0), "«%s» на кнопке 1" % _nm(sid))
	p.skill_cd.erase(sid)
	var ok := use_now(p, "skill1")
	check(ok, "«%s» применено (%s)" % [_nm(sid), main.hud._msg_label.text])
	if hs.has("sw_mana") or hs.has("ne_corpse_mp"):
		check(p.mp > pmp0 - cost, "«%s»: MP вернулось (%d → %d, цена %d)" % [_nm(sid), pmp0, p.mp, cost])
	else:
		check(p.mp == pmp0 - cost and cost > 0, "«%s»: MP %d → %d (цена %d)" % [_nm(sid), pmp0, p.mp, cost])
	check(float(p.skill_cd.get(sid, 0.0)) > 0.5 and p.cooldown_frac("skill1") > 0.9,
		"«%s» на перезарядке %.1f с" % [_nm(sid), float(p.skill_cd.get(sid, 0.0))])
	check(not use_now(p, "skill1"), "«%s»: повтор сразу не срабатывает" % _nm(sid))
	# Сразу проверяемое
	if hs.has("sw_rush"):
		check(p.global_position.distance_to(pos0) > 4.0, "«%s»: рывок к зверю (%.1f м)" % [_nm(sid),
			p.global_position.distance_to(pos0)])
	if sid == "thorn_shield":
		_check_reflect()
	if sid == "fire_heart":
		check(p._fx.skill_factor("fire_spark") > 1.0 and is_equal_approx(p._fx.skill_factor("zap"), 1.0),
			"«Огненное сердце»: огненные умения ×%.2f, молния — без прибавки" % p._fx.skill_factor("fire_spark"))
	return 0


## Ждём ожидаемых эффектов умения sid (снаряд, тик зоны) не дольше POLL_MAX кадров.
func _poll_step(sid: String) -> int:
	var miss := _unmet(sid)
	if miss.is_empty():
		check(true, "«%s»: эффекты на месте" % _nm(sid))
		_after(sid)
		return 0
	polls += 1
	if polls > POLL_MAX:
		fail("«%s»: нет эффекта: %s" % [_nm(sid), ", ".join(miss)])
	return -1


## Что ещё не сработало у умения sid (пусто — всё).
func _unmet(sid: String) -> PackedStringArray:
	var p: Player = main.player
	var sk := HeroSkills.get_skill(sid)
	var miss: PackedStringArray = []
	var alive := mob_ok(m1)
	if String(sk.get("target", "")) == "self" and p.shade_time <= 0.0:
		miss.append("усиление «Танец теней»")
	for item in sk.get("fx", []):
		var e: Dictionary = item
		match String(e.get("do", "")):
			"damage":
				if alive and m1.hp >= hp1:
					miss.append("урон")
			"heal":
				if p.hp <= php0:
					miss.append("лечение")
			"status":
				var st := String(e.get("status", ""))
				var ch := HeroSkills.value_at(e.get("chance", 1.0), 5)
				if ch < 1.0 or not alive:
					continue
				var ok := m1.effects.has(st)
				match st:
					"taunt":
						ok = ok and m1.target == p and m1.taunt_time > 0.0
					"armor":
						ok = ok and m1.pdef < pdef1
					"ward":
						ok = ok and m1.mdef < mdef1
					"aslow":
						ok = ok and m1.attack_every > every1
					"snare":
						ok = ok and is_zero_approx(m1.speed)
				if not ok:
					miss.append("статус " + st)
			"dot":
				if alive and not (m1.dots.has(sid) and m1.effects.has("dot:" + sid)):
					miss.append("урон со временем")
			"buff":
				if not (p.timed_bonus.has(sid) and p.effects.has("buff:" + sid)):
					miss.append("усиление")
			"special":
				var h := String(e.get("handler", ""))
				match h:
					"ne_zone":
						var hit := false
						for z in get_tree().get_nodes_in_group("skill_zones"):
							var zn := z as JobFxNeophyte.Zone
							if zn != null and zn.sid == sid and zn.hits > 0:
								hit = true
						if not hit or m1.hp >= hp1:
							miss.append("зона бьёт зверя")
						elif e.has("aslow") and not JobFxNeophyte.has_mod(m1, "aslow"):
							miss.append("зона: удары реже")
						elif e.has("slow") and m1.slow_time <= 0.0:
							miss.append("зона: замедление")
					"ne_volley":
						if m1.hp >= hp1:
							miss.append("снаряды серии")
					"ne_burn_area":
						if not m1.dots.has(sid):
							miss.append("горение вокруг")
					"ne_corpse_hp", "wz_renew":
						if p.hp <= php0:
							miss.append("HP героя")
					"ne_blood_gift":
						var pet := _pet()
						if pet == null or pet.hp <= pet_hp0 or p.hp >= php0:
							miss.append("HP героя → питомцу")
					"revive_pet":
						if bool(game.pets[0].get("dead", false)) or _pet() == null:
							miss.append("питомец воскрешён и призван")
	return miss


## Дополнительные проверки после эффектов.
func _after(sid: String) -> void:
	var p: Player = main.player
	var hs := _handlers(sid)
	if hs.has("wz_renew"):
		var hot := p.get_node_or_null("Hot_" + sid) as JobFxWizard.Hot
		check(hot != null and p.effects.has("hot:" + sid), "«%s»: лечение со временем идёт, значок у полоски HP" % _nm(sid))
	if hs.has("ne_corpse_hp") or hs.has("ne_corpse_mp"):
		check(JobFxNeophyte.nearest_corpse(p.global_position, JobFxNeophyte.CORPSE_RANGE) < 0, "тело поглощено")
	if hs.has("revive_pet"):
		var pet := _pet()
		check(pet.hp < pet.max_hp, "питомец встал с частью HP: %d/%d" % [pet.hp, pet.max_hp])
	if hs.has("ne_zone"):
		var zones := get_tree().get_nodes_in_group("skill_zones").size()
		check(zones == 1, "зона на земле видна (%d)" % zones)
	# Ослабления снимаются вместе со зверем в порядок (clear_mods возвращает поля)
	JobFxNeophyte.clear_mods(m1)
	if mob_ok(m1):
		check(m1.pdef == pdef1 and m1.mdef == mdef1 and is_equal_approx(m1.attack_every, every1) and m1.speed > 0.0,
			"поля зверя вернулись после ослаблений")


## «Колючий щит»: удары зверя по герою возвращают ему долю урона.
func _check_reflect() -> void:
	var p: Player = main.player
	AdminPanel.god = false
	var h0 := m1.hp
	var hits0 := int(p._fx.state.get("reflect_hits", 0))
	for i in 40:
		p.hp = p.max_hp
		p.take_damage(40, m1)
		if int(p._fx.state.get("reflect_hits", 0)) > hits0:
			break
	AdminPanel.god = true
	p.hp = p.max_hp
	check(int(p._fx.state.get("reflect_hits", 0)) > hits0 and m1.hp < h0, "«Колючий щит»: зверь получил ответный урон")


## Обычная атака с «Сияющим лезвием» / «Теневой печатью»: включить и бить, пока снаряд не попадёт.
func _edge_attack(sid: String) -> int:
	var p: Player = main.player
	_arrange(Vector3(0, 0, 6.0))
	p.mp = p.max_mp
	check(p.set_toggle(sid, true) == "", "«%s» включено" % _nm(sid))
	polls = 0
	return 0


func _edge_check(key: String) -> int:
	var p: Player = main.player
	if int(p._fx.state.get(key, 0)) > 0:
		check(m1.hp < hp1, "обычная атака + урон стихией (%s): %d → %d" % [key, hp1, m1.hp])
		return 1
	p.attack_cd = 0.0
	p.try_attack()
	polls += 1
	if polls > POLL_MAX * 2:
		fail("обычная атака не добавила урон стихией (%s)" % key)
	return -1


## Ослабление зверя проходит само: поле возвращается по времени, значок пропадает.
func _mod_expiry() -> int:
	_arrange(Vector3(0, 0, 2.0))
	JobFxNeophyte.apply_mod(m1, "armor", 0.5, 0.3, StatusEffects.source_hero_skill("brittle_hide"))
	check(m1.pdef < pdef1 and m1.effects.has("armor"), "«Хрупкая чешуя»: защита %d → %d" % [pdef1, m1.pdef])
	return 40


func _mod_expiry_check() -> int:
	check(m1.pdef == pdef1 and not m1.effects.has("armor"), "ослабление прошло: защита снова %d, значка нет" % m1.pdef)
	return 1


## Оценка темпа боя (печать): герой 20 / 30 / 40 ур. каждой профессии против зверя своего уровня — время на одного
## зверя обычными атаками и с умениями (урон умений по их перезарядке, урон со временем и зоны — целиком).
func _balance() -> int:
	var p: Player = main.player
	for job in JOBS:
		become_job(String(job))
		for lvl in [20, 30, 40]:
			game.level = lvl
			game.hero["jp"] = 9000
			HeroSkills.learn_all(game.hero, String(job), lvl)
			_default_weapon()
			p.refresh_skills()
			var t := _ttk(lvl)
			print("  ТЕМП: %s %d ур. против зверя своего уровня: обычными атаками %.1f с, с умениями %.1f с"
				% [ClassData.job_name(String(job)), lvl, t.x, t.y])
			check(t.y < t.x, "%s %d ур.: с умениями быстрее (%.1f < %.1f с)" % [ClassData.job_name(String(job)), lvl, t.y, t.x])
	game.level = 40
	return 1


func _ttk(lvl: int) -> Vector2:
	var p: Player = main.player
	var basic := 0.0
	var full := 0.0
	for type_id in ["panther", "turtle", "pheasant"]:
		var st := MobStats.derived(String(type_id), lvl)
		var mob := {"level": lvl, "max_hp": int(st["max_hp"]), "def": int(st["def"]), "mdef": int(st["mdef"]),
			"avoid": int(st["avoid"]), "eva": 0.0, "block": 0.0}
		var dps := Combat.expected_dps(Combat.profile_of(p), mob) * p.basic_mult
		var sk_dps := 0.0
		for id in HeroSkills.list_for(game.class_id):
			var sid := String(id)
			var n := HeroSkills.skill_level(game.hero, sid)
			if n <= 0 or HeroSkills.kind(sid) != "active" or not HeroSkills.weapon_ok(sid, p.weapon_kind, p.has_shield):
				continue
			var per := 0.0
			for fe in HeroSkills.get_skill(sid).get("fx", []):
				var d: Dictionary = fe
				var magic := String(d.get("power", "atk")) == "matk" or String(d.get("handler", "")).begins_with("ne_")
				var pw := float(p.cur_matk() if magic else p.cur_atk())
				var df := Combat.damage_factor(pw, float(mob["mdef"] if magic else mob["def"]), lvl, lvl)
				match String(d.get("do", "")):
					"damage":
						per += (pw * HeroSkills.value_at(d.get("mult", 1.0), n) + HeroSkills.value_at(d.get("flat", 0.0), n)) \
							* HeroSkills.value_at(d.get("hits", 1), n) * df
					"dot":
						per += pw * HeroSkills.value_at(d.get("mult", 0.0), n) * HeroSkills.value_at(d.get("time", 10.0), n) * df
					"special":
						match String(d.get("handler", "")):
							"ne_volley":
								per += pw * HeroSkills.value_at(d.get("mult", 0.0), n) * HeroSkills.value_at(d.get("hits", 1), n) * df
							"ne_zone", "ne_burn_area":
								per += pw * HeroSkills.value_at(d.get("mult", 0.0), n) * HeroSkills.value_at(d.get("time", 10.0), n) * df
			if per > 0.0:
				# Цикл умения — перезарядка и время каста (пока кастует, герой не бьёт)
				sk_dps += per / maxf(1.0, HeroSkills.cooldown(sid, n) + p.skill_cast_time(sid, n))
		basic += float(mob["max_hp"]) / maxf(0.01, dps)
		full += float(mob["max_hp"]) / maxf(0.01, dps + sk_dps)
	return Vector2(basic / 3.0, full / 3.0)


func _handlers(sid: String) -> PackedStringArray:
	var res: PackedStringArray = []
	for item in HeroSkills.get_skill(sid).get("fx", []):
		var e: Dictionary = item
		if String(e.get("do", "")) == "special":
			res.append(String(e.get("handler", "")))
	return res


func _has_do(sid: String, what: String) -> bool:
	for item in HeroSkills.get_skill(sid).get("fx", []):
		if String((item as Dictionary).get("do", "")) == what:
			return true
	return false
