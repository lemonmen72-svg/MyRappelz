extends "res://tests/test_base.gd"
## Умения Воина и Шамана (этап 2): каждое умение древа готово (HeroSkills.is_ready), активные применяются —
## тратят MP, уходят на перезарядку и дают свой эффект (урон, площадь, статус зверя, кровотечение и яд, лечение,
## усиление на время), пассивные и переключаемые меняют показатель героя. Особые механики: искры духа Воина
## (копятся ударами и «Разжечь искру», тратятся «Вдохом силы», «Искрой крепости», «Ударной искрой», «Стрелой
## стужи»; без искры умение не применяется; значок с числом у полоски HP), «Ядовитый наконечник» (выстрел травит),
## «Ярость дикаря» (двойной удар), лезвия Шамана (одно за раз, урон стихией к обычной атаке, оглушение / яд / MP),
## «Огненная кожа» (ответ огнём), неистовства (горение шамана, цена HP). Оценка темпа боя: герой 30 ур. против зверя
## своего уровня обычными атаками и с умениями (печать и грубые рамки). Герой — человек 40 ур. под «бессмертием»,
## звери — волки 30 ур. с огромным запасом HP (не умирают за проверку).

const BIG_HP := 400000

var plan: Array[Callable] = []
var anchor := Vector3.ZERO
var m1: Mob = null
var m2: Mob = null
var hp1 := 0
var hp2 := 0
var val := 0.0
var cur := ""
var shots0 := 0


func race_class() -> Array:
	return ["human", "warrior"]


func hero_level() -> int:
	return 40


func before_start() -> void:
	AdminPanel.god = true


func run_step() -> void:
	if plan.is_empty():
		_build_plan()
	if step >= plan.size():
		AdminPanel.god = false
		ok_done()
		return
	var c: Callable = plan[step]
	step += 1
	wait = int(c.call())


func _build_plan() -> void:
	plan = [
		_start, _w_passives, _w_toggles, _w_sparks_hits, _w_kindle, _w_power_breath, _w_spark_vigor,
		_w_axe_melee, _w_armor_split_check, _w_wind_slash_check, _w_stonebreaker, _w_axe_storm, _w_common,
		_w_bow_cast.bind("sticky_arrow"), _w_bow_check.bind("slow"),
		_w_bow_cast.bind("pin_down"), _w_bow_check.bind("stun"),
		_w_bow_cast.bind("burning_arrow"), _w_bow_check.bind("dot"),
		_w_bow_cast.bind("spark_shot"), _w_bow_check.bind("stun"),
		_w_bow_cast.bind("frost_arrow"), _w_bow_check.bind("stun"),
		_w_venom, _w_venom_check, _w_balance,
		_s_start, _s_passives, _s_toggles, _s_edge_attack, _s_edge_check, _s_edge_procs, _s_edge_procs_check,
		_s_fire_skin, _s_spells_instant, _s_proj_cast.bind("wind_sickle"), _s_proj_check.bind("wind_sickle"),
		_s_proj_cast.bind("ice_orbs"), _s_proj_check.bind("ice_orbs"), _s_support, _s_frenzies, _s_burn_check,
		_s_axe, _s_balance,
	]


# ---------- Помощники ----------

func _ground(pos: Vector3) -> Vector3:
	if IslandWorld.current != null:
		pos.y = IslandWorld.current.height_at(pos.x, pos.z) + 0.1
	return pos


func _spawn(off: Vector3) -> Mob:
	var m: Mob = main.spawn_mob("wolf", 30, _ground(anchor + off))
	m.max_hp = BIG_HP
	m.hp = BIG_HP
	return m


## Герой в точке anchor + off, звери — у anchor (m2 рядом с m1), целятся в героя, HP — полные.
func _arrange(off: Vector3) -> void:
	var p: Player = main.player
	p.global_position = _ground(anchor + off)
	p.hp = p.max_hp
	p.mp = p.max_mp
	p.regen_delay = 0.0
	for pair in [[m1, Vector3.ZERO], [m2, Vector3(1.0, 0, -0.6)]]:
		var m := pair[0] as Mob
		m.global_position = _ground(anchor + (pair[1] as Vector3))
		m.velocity = Vector3.ZERO
		m.hp = m.max_hp
		m.target = p
		m.returning = false
		m.stun_time = 0.0
		m.sleep_time = 0.0
		m.slow_time = 0.0
		m.vuln_time = 0.0
		m.weak_time = 0.0
		m.dots.clear()
		m.effects.clear()
	hp1 = m1.hp
	hp2 = m2.hp
	p.select_target(m1)


## Применить умение sid с кнопки 1: применилось, MP списано ровно по цене (mp_exact), перезарядка пошла,
## повтор не срабатывает.
func _cast(sid: String, mp_exact: bool = true) -> bool:
	var p: Player = main.player
	var nm := String(HeroSkills.get_skill(sid).get("name", sid))
	check(HeroSkills.is_ready(sid), "«%s» готово (этап 2)" % nm)
	check(p.assign_slot(sid, 0), "«%s» на кнопке 1" % nm)
	p.skill_cd.erase(sid)
	p.attack_cd = 0.0
	p.mp = p.max_mp
	var mp0 := p.mp
	var cost := HeroSkills.mp_cost(sid, HeroSkills.skill_level(game.hero, sid))
	var ok := p.use_skill("skill1")
	check(ok, "«%s» применено (%s)" % [nm, main.hud._msg_label.text])
	if not ok:
		return false
	if mp_exact:
		check(p.mp == mp0 - cost and cost > 0, "«%s»: MP %d → %d (цена %d)" % [nm, mp0, p.mp, cost])
	check(float(p.skill_cd.get(sid, 0.0)) > 0.5, "«%s» на перезарядке %.1f с" % [nm, float(p.skill_cd.get(sid, 0.0))])
	check(not p.use_skill("skill1"), "«%s»: повтор сразу не срабатывает" % nm)
	return true


func _sparks() -> int:
	return JobFxWarrior.sparks(main.player._fx)


func _learn_job(job: String) -> void:
	game.level = 40
	game.hero["jp"] = 5000
	var ids := HeroSkills.list_for(job)
	var bad := ""
	for id in ids:
		var sid := String(id)
		if not HeroSkills.is_ready(sid):
			bad += " " + sid
		if HeroSkills.effect_text(sid, 1).contains("следующем обновлении"):
			bad += " (текст) " + sid
	check(bad == "", "%s: все %d умений готовы%s" % [ClassData.job_name(job), ids.size(), bad])


func _equip(id: String, second: bool = false) -> void:
	var p: Player = main.player
	if game.inventory.count(id) < (2 if second else 1):
		game.inventory.add(id, 1)
	check(p.equip(id, second) == "", "надето: %s" % ItemData.item_name(id))


func _has_dot(m: Mob, sid: String) -> bool:
	return m.dots.has(sid)


# ---------- Воин ----------

func _start() -> int:
	var p: Player = main.player
	check(game.class_id == "warrior" and game.level == 40, "герой — Воин 40 ур.")
	_learn_job("warrior")
	var w := find_mob("wolf")
	check(w != null, "волк для точки проверки")
	anchor = w.home
	if IslandWorld.current != null:
		anchor = AdminPanel.free_spot(IslandWorld.current, Vector2(w.home.x, w.home.z))
	m1 = _spawn(Vector3.ZERO)
	m2 = _spawn(Vector3(1.0, 0, -0.6))
	_arrange(Vector3(0, 0, 1.6))
	check(p.weapon_kind == "axe_2h", "Воин с двуручным топором")
	return 2


## Пассивки по одной: показатель растёт.
func _w_passives() -> int:
	var p: Player = main.player
	var d0 := p.defense
	learn_skills(["defense_drill"])
	check(p.defense > d0, "«Крепкая выучка»: защита %d → %d" % [d0, p.defense])
	var a0 := p.atk
	learn_skills(["combat_drill"])
	check(p.atk > a0, "«Боевая выучка» (топор): атака %d → %d" % [a0, p.atk])
	learn_skills(["spark_reserve"])
	check(JobFxWarrior.max_sparks(p._fx) == 1, "«Запас искр»: можно держать 1 искру")
	learn_skills(["challenge", "focus_moment", "kindle_spark", "power_breath", "spark_vigor", "spin_strike", "armor_split",
		"wind_slash"])
	var s0 := p.aspd
	learn_skills(["greataxe_drill"])
	check(p.aspd > s0, "«Тяжёлая рука» (двуручный топор): скорость атаки %.2f → %.2f" % [s0, p.aspd])
	_equip("weapon_axe_1h_r1")
	_equip("weapon_axe_1h_r1", true)
	check(p.weapon_kind == "dual_axes", "два топора в руках")
	var b0 := p.basic_mult
	learn_skills(["dual_axes"])
	check(p.basic_mult > b0, "«Два топора»: урон обычных атак ×%.2f → ×%.2f" % [b0, p.basic_mult])
	learn_skills(["stonebreaker", "axe_storm", "savage_fury"])
	_equip("weapon_bow_r1")
	check(p.weapon_kind == "bow" and p.attack_kind == "ranged", "лук в руках")
	var ba := p.atk
	learn_skills(["bow_mastery"])
	check(p.atk > ba, "«Школа лука»: атака %d → %d" % [ba, p.atk])
	var bs := p.aspd
	learn_skills(["sticky_arrow", "pin_down", "burning_arrow", "swift_string"])
	check(p.aspd > bs, "«Лёгкая тетива»: скорость атаки %.2f → %.2f" % [bs, p.aspd])
	learn_skills(["spark_shot", "frost_arrow", "venom_tip"])
	for id in HeroSkills.list_for("warrior"):
		check(HeroSkills.skill_level(game.hero, String(id)) >= 1, "изучено «%s»" % String(HeroSkills.get_skill(String(id))["name"]))
	_equip("weapon_axe_2h_r1")
	return 2


func _w_toggles() -> int:
	var p: Player = main.player
	var mp0 := p.mp
	check(p.double_chance == 0.0, "без «Ярости дикаря» двойного удара нет")
	check(p.set_toggle("savage_fury", true) == "", "«Ярость дикаря» включена")
	check(p.mp < mp0 and p.double_chance > 0.1, "«Ярость дикаря»: MP %d → %d, шанс двойного удара %.0f%%"
		% [mp0, p.mp, p.double_chance * 100.0])
	check(p.effects.has("toggle:savage_fury"), "значок включённого умения у полоски HP")
	check(p.set_toggle("savage_fury", false) == "" and p.double_chance == 0.0, "«Ярость дикаря» выключена")
	check(p.set_toggle("venom_tip", true) != "", "«Ядовитый наконечник» без лука не включить")
	return 1


## Искры копятся обычными ударами: искра — за каждые SPARK_HITS попавших.
func _w_sparks_hits() -> int:
	var p: Player = main.player
	_arrange(Vector3(0, 0, 1.6))
	check(_sparks() == 0, "искр пока нет")
	var tries := 0
	while _sparks() == 0 and tries < HeroSkills.SPARK_HITS * 4:
		p.attack_cd = 0.0
		p.try_attack()
		tries += 1
	check(_sparks() == 1 and tries >= HeroSkills.SPARK_HITS, "искра духа загорелась от ударов (ударов: %d)" % tries)
	check(m1.hp < hp1, "удары топором ранят зверя")
	check(p.effects.has("spark:charges") and int(p.effects.get_entry("spark:charges")["count"]) == 1,
		"значок «Искры духа» с числом 1 у полоски HP")
	# Запас полон (1 из 1): «Разжечь искру» не применяется
	p.assign_slot("kindle_spark", 0)
	p.skill_cd.erase("kindle_spark")
	var mp0 := p.mp
	check(not p.use_skill("skill1") and p.mp == mp0, "запас полон — «Разжечь искру» не тратит MP: %s" % main.hud._msg_label.text)
	return 1


func _w_kindle() -> int:
	var p: Player = main.player
	JobFxWarrior.add_sparks(p._fx, -9)
	check(_sparks() == 0 and not p.effects.has("spark:charges"), "искры потрачены — значка нет")
	# «Запас искр» до 3-го уровня — запас 3
	game.hero["skills"]["spark_reserve"] = 3
	p.refresh_skills()
	check(JobFxWarrior.max_sparks(p._fx) == 3, "«Запас искр» 3 ур.: до 3 искр")
	_cast("kindle_spark")
	check(_sparks() == 1, "«Разжечь искру»: 1 искра")
	p.skill_cd.erase("kindle_spark")
	p.use_skill("skill1")
	p.skill_cd.erase("kindle_spark")
	p.use_skill("skill1")
	check(_sparks() == 3 and int(p.effects.get_entry("spark:charges")["count"]) == 3, "три искры, на значке 3")
	return 1


func _w_power_breath() -> int:
	var p: Player = main.player
	p.hp = p.max_hp / 3
	p.mp = p.max_mp / 3
	var hp0 := p.hp
	var mp0 := p.mp
	p.assign_slot("power_breath", 0)
	p.skill_cd.erase("power_breath")
	check(p.use_skill("skill1"), "«Вдох силы» применён")
	check(_sparks() == 2, "«Вдох силы» 1 ур. тратит одну искру: осталось %d" % _sparks())
	check(p.hp > hp0, "«Вдох силы»: HP %d → %d" % [hp0, p.hp])
	check(p.mp > mp0 - HeroSkills.mp_cost("power_breath", 1), "«Вдох силы» вернул MP")
	check(float(p.skill_cd.get("power_breath", 0.0)) > 0.0, "«Вдох силы» на перезарядке")
	# Без искр — не применяется, MP не тратится
	JobFxWarrior.add_sparks(p._fx, -9)
	p.skill_cd.erase("power_breath")
	var mp1 := p.mp
	check(not p.use_skill("skill1") and p.mp == mp1 and float(p.skill_cd.get("power_breath", 0.0)) == 0.0,
		"без искр «Вдох силы» не применяется: %s" % main.hud._msg_label.text)
	return 1


func _w_spark_vigor() -> int:
	var p: Player = main.player
	JobFxWarrior.add_sparks(p._fx, 2)
	game.hero["skills"]["spark_vigor"] = 2
	p.refresh_skills()
	var vit0 := int(p.hero_stats["stats"]["vit"])
	var hpm0 := p.max_hp
	_cast("spark_vigor")
	check(_sparks() == 0, "«Искра крепости» 2 ур. потратила обе искры")
	check(int(p.hero_stats["stats"]["vit"]) >= vit0 + 7, "Выносливость %d → %d (+4 за искру)" % [vit0, int(p.hero_stats["stats"]["vit"])])
	check(p.max_hp > hpm0 and p.effects.has("buff:spark_vigor"), "макс. HP выше, значок усиления")
	p.clear_buffs()
	return 1


func _w_axe_melee() -> int:
	var p: Player = main.player
	_arrange(Vector3(0, 0, 1.6))
	_cast("armor_split")
	return 1


func _w_armor_split_check() -> int:
	check(m1.hp < hp1, "«Раскол брони» ранил зверя: %d → %d" % [hp1, m1.hp])
	check(m1.vuln_time > 0.0 and m1.effects.has("vuln"), "«Раскол брони»: зверь уязвим (урон по нему выше)")
	_arrange(Vector3(0, 0, 1.6))
	_cast("wind_slash")
	return 1


func _w_wind_slash_check() -> int:
	check(m1.hp < hp1 and _has_dot(m1, "wind_slash") and m1.effects.has("dot:wind_slash"),
		"«Рассекающий ветер»: удар и кровотечение")
	_arrange(Vector3(0, 0, 1.6))
	_cast("spin_strike")
	check(m1.hp < hp1, "«Удар с разворота» ранил зверя")
	return 1


## «Камнелом»: урон по площади и оглушение цели.
func _w_stonebreaker() -> int:
	_arrange(Vector3(0, 0, 1.6))
	_cast("stonebreaker")
	check(m1.hp < hp1 and m2.hp < hp2, "«Камнелом» ранил обоих зверей: %d, %d" % [hp1 - m1.hp, hp2 - m2.hp])
	check(m1.stun_time > 0.0 and m1.effects.has("stun"), "«Камнелом» оглушил цель")
	return 1


## «Буря топоров»: парные топоры, серия ударов, площадь, оглушение.
func _w_axe_storm() -> int:
	var p: Player = main.player
	_equip("weapon_axe_1h_r1")
	_equip("weapon_axe_1h_r1", true)
	check(p.weapon_kind == "dual_axes", "два топора для «Бури топоров»")
	_arrange(Vector3(0, 0, 1.6))
	var one := 0
	_cast("axe_storm")
	one = hp1 - m1.hp
	check(one > 0 and m2.hp < hp2, "«Буря топоров» ранила обоих зверей: %d, %d" % [one, hp2 - m2.hp])
	check(m1.stun_time > 4.0, "«Буря топоров» оглушила цель на 5 с")
	# С двуручным топором «Буря топоров» не применяется
	_equip("weapon_axe_2h_r1")
	p.skill_cd.erase("axe_storm")
	check(not p.use_skill("skill1") and p.slot_block("skill1") != "", "без двух топоров «Буря топоров» недоступна")
	return 1


func _w_common() -> int:
	var p: Player = main.player
	_arrange(Vector3(0, 0, 1.6))
	m1.target = null
	_cast("challenge")
	check(m1.taunt_time > 0.0 and m1.target == p, "«Вызов»: зверь бьёт героя")
	var c0 := p.cur_crit()
	_cast("focus_moment")
	check(p.cur_crit() > c0, "«Миг сосредоточения»: крит выше")
	p.clear_buffs()
	_equip("weapon_bow_r1")
	return 1


## Лук: выстрел умением (снаряд), проверка — через 40 кадров.
func _w_bow_cast(sid: String) -> int:
	var p: Player = main.player
	_arrange(Vector3(0, 0, 6.0))
	if sid == "spark_shot" or sid == "frost_arrow":
		# Без искры — не применяется
		JobFxWarrior.add_sparks(p._fx, -9)
		p.assign_slot(sid, 0)
		p.skill_cd.erase(sid)
		var mp0 := p.mp
		check(not p.use_skill("skill1") and p.mp == mp0, "«%s» без искры не применяется" % String(HeroSkills.get_skill(sid)["name"]))
		JobFxWarrior.add_sparks(p._fx, 1)
	cur = sid
	val = m1.global_position.distance_to(p.global_position)
	shots0 = get_tree().get_nodes_in_group("projectiles").size()
	_cast(sid)
	check(get_tree().get_nodes_in_group("projectiles").size() > shots0, "«%s»: стрела летит" % String(HeroSkills.get_skill(sid)["name"]))
	if sid == "spark_shot" or sid == "frost_arrow":
		check(_sparks() == 0, "искра потрачена")
	return 40


func _w_bow_check(what: String) -> int:
	var nm := String(HeroSkills.get_skill(cur)["name"])
	check(m1.hp < hp1, "«%s» попала: %d урона" % [nm, hp1 - m1.hp])
	match what:
		"slow":
			check(m1.slow_time > 0.0 and m1.effects.has("slow"), "«%s»: зверь замедлен" % nm)
		"stun":
			check(m1.stun_time > 0.0 and m1.effects.has("stun"), "«%s»: зверь держится на месте / оглушён" % nm)
		"dot":
			check(_has_dot(m1, cur), "«%s»: горение" % nm)
	if cur == "frost_arrow":
		check(m1.slow_time > 0.0, "«Стрела стужи»: после заморозки — замедление")
	return 1


func _w_venom() -> int:
	var p: Player = main.player
	_arrange(Vector3(0, 0, 6.0))
	check(p.set_toggle("venom_tip", true) == "", "«Ядовитый наконечник» включён (лук)")
	check(float(p.skill_bonus.get("poison", 0.0)) > 0.2, "шанс отравить выстрелом %.0f%%" % (float(p.skill_bonus.get("poison", 0.0)) * 100.0))
	# Для проверки — шанс 100 %
	p.skill_bonus["poison"] = 1.0
	p.accuracy = -1
	p.attack_cd = 0.0
	check(p.try_attack(), "выстрел из лука")
	return 40


func _w_venom_check() -> int:
	var p: Player = main.player
	check(_has_dot(m1, "venom_tip") and m1.effects.has("dot:venom_tip"), "«Ядовитый наконечник»: зверь отравлен")
	p.set_toggle("venom_tip", false)
	_equip("weapon_axe_2h_r1")
	return 1


## Оценка темпа боя: герой level против зверя своего уровня (среднее по пантере, черепахе, фазану), время на
## одного зверя обычными атаками и с умениями (урон умений — по их перезарядке, кровотечение и яд — целиком).
func _ttk(lvl: int, edge: String = "") -> Vector2:
	var p: Player = main.player
	var keep: int = game.level
	game.level = lvl
	p.recalc_stats()
	var basic := 0.0
	var full := 0.0
	for type_id in ["panther", "turtle", "pheasant"]:
		var st := MobStats.derived(String(type_id), lvl)
		var mob := {"level": lvl, "max_hp": int(st["max_hp"]), "def": int(st["def"]), "mdef": int(st["mdef"]),
			"avoid": int(st["avoid"]), "eva": 0.0, "block": 0.0}
		var hero := Combat.profile_of(p)
		var dps := Combat.expected_dps(hero, mob) * p.basic_mult
		var extra := 0.0
		if edge != "":
			var e := float(p.skill_bonus.get("edge", 0.0))
			var mp := float(p.cur_matk())
			extra += mp * e * Combat.damage_factor(mp, float(mob["mdef"]), lvl, lvl) / maxf(0.1, p.attack_time)
		var sk_dps := 0.0
		for id in HeroSkills.list_for(game.class_id):
			var sid := String(id)
			var n := HeroSkills.skill_level(game.hero, sid)
			if n <= 0 or HeroSkills.kind(sid) != "active" or not HeroSkills.weapon_ok(sid, p.weapon_kind, p.has_shield):
				continue
			var sk := HeroSkills.get_skill(sid)
			var per := 0.0
			for fe in sk.get("fx", []):
				var d: Dictionary = fe
				var magic := String(d.get("power", "atk")) == "matk"
				var pw := float(p.cur_matk() if magic else p.cur_atk())
				var df := Combat.damage_factor(pw, float(mob["mdef"] if magic else mob["def"]), lvl, lvl)
				match String(d.get("do", "")):
					"damage":
						per += (pw * HeroSkills.value_at(d.get("mult", 1.0), n) + HeroSkills.value_at(d.get("flat", 0.0), n)) \
							* HeroSkills.value_at(d.get("hits", 1), n) * df * (1.0 + p.cur_crit() * (Player.CRIT_MULT - 1.0))
					"dot":
						per += pw * HeroSkills.value_at(d.get("mult", 0.0), n) * HeroSkills.value_at(d.get("time", 10.0), n) * df
			if per > 0.0:
				sk_dps += per / maxf(1.0, HeroSkills.cooldown(sid, n))
		basic += float(mob["max_hp"]) / maxf(0.01, dps)
		full += float(mob["max_hp"]) / maxf(0.01, dps + extra + sk_dps)
	game.level = keep
	p.recalc_stats()
	return Vector2(basic / 3.0, full / 3.0)


func _check_ttk(label: String, edge: String = "") -> void:
	for lvl in [15, 25, 30]:
		var t := _ttk(lvl, edge)
		print("  ТЕМП: %s %d ур. против зверя своего уровня: обычными атаками %.1f с, с умениями %.1f с" % [label, lvl, t.x, t.y])
		check(t.y < t.x, "%s %d ур.: с умениями быстрее (%.1f < %.1f с)" % [label, lvl, t.y, t.x])
		check(t.y > 0.5 and t.y < 90.0, "%s %d ур.: бой со зверем своего уровня %.1f с (грубые рамки 0.5–90 с)" % [label, lvl, t.y])


func _w_balance() -> int:
	var p: Player = main.player
	# Уровни умений — как у героя этих уровней (по 1-му): оценка снизу
	check(p.weapon_kind == "axe_2h", "оценка темпа — с двуручным топором")
	_check_ttk("Воин (топор)")
	return 1


# ---------- Шаман ----------

func _s_start() -> int:
	var p: Player = main.player
	become_job("shaman")
	check(game.class_id == "shaman" and p.weapon_kind == "staff_2h" and p.attack_kind == "magic", "Шаман с посохом")
	check(_sparks() == 0 and not p.effects.has("spark:charges"), "искры Воина погасли при смене профессии")
	_learn_job("shaman")
	return 1


func _s_passives() -> int:
	var p: Player = main.player
	var m0 := p.matk
	learn_skills(["nature_lore"])
	check(p.matk > m0, "«Дыхание земли»: маг. атака %d → %d" % [m0, p.matk])
	var md := p.mdef
	learn_skills(["mind_ward"])
	check(p.mdef > md, "«Ясный разум»: маг. защита %d → %d" % [md, p.mdef])
	var d0 := p.defense
	learn_skills(["defense_drill"])
	check(p.defense > d0, "«Крепкая выучка»: защита %d → %d" % [d0, p.defense])
	var a0 := p.aspd
	learn_skills(["shaman_drill"])
	check(p.aspd > a0, "«Выучка шамана» (посох): скорость атаки %.2f → %.2f" % [a0, p.aspd])
	learn_skills(["spin_strike", "focus_moment"])
	_equip("weapon_axe_2h_r1")
	var s0 := p.aspd
	learn_skills(["greataxe_drill"])
	check(p.aspd > s0, "«Тяжёлая рука»: скорость атаки %.2f → %.2f" % [s0, p.aspd])
	var rest: Array = []
	for id in HeroSkills.list_for("shaman"):
		if HeroSkills.skill_level(game.hero, String(id)) <= 0:
			rest.append(String(id))
	learn_skills(rest)
	_equip("weapon_staff_2h_r1")
	return 1


## Переключаемые: лезвия (одно за раз), ауры, «Огненная кожа».
func _s_toggles() -> int:
	var p: Player = main.player
	for id in ["fire_edge", "storm_edge", "stone_edge", "water_edge"]:
		var mp0 := p.mp
		check(p.set_toggle(String(id), true) == "" and p.mp < mp0, "«%s» включено (MP %d → %d)" % [
			String(HeroSkills.get_skill(String(id))["name"]), mp0, p.mp])
		check(float(p.skill_bonus.get("edge", 0.0)) > 0.1, "зачарование: урон стихией %.0f%% маг. атаки"
			% (float(p.skill_bonus.get("edge", 0.0)) * 100.0))
		var on := 0
		for e in ["fire_edge", "storm_edge", "stone_edge", "water_edge"]:
			if HeroSkills.toggle_on(game.hero, String(e)):
				on += 1
		check(on == 1 and JobFxShaman.active_edge() == String(id), "одно лезвие за раз")
	check(float(p.skill_bonus.get("edge_mp", 0.0)) > 0.0 and not p.skill_bonus.has("edge_stun"), "у водного лезвия — шанс MP")
	p.mp = p.max_mp
	var sp := p.speed
	check(p.set_toggle("wind_step", true) == "" and p.speed > sp, "«Шаг ветра»: бег %.2f → %.2f" % [sp, p.speed])
	var a0 := p.atk
	var m0 := p.matk
	check(p.set_toggle("sacred_fire", true) == "" and p.atk > a0 and p.matk > m0, "«Священный огонь»: атака %d → %d, маг. %d → %d"
		% [a0, p.atk, m0, p.matk])
	var d0 := p.defense
	check(p.set_toggle("rock_strength", true) == "" and p.defense > d0, "«Сила скалы»: защита %d → %d" % [d0, p.defense])
	check(HeroSkills.pet_aura_bonuses(game.hero, "shaman", p.weapon_kind).has("speed_pct"), "ауры Шамана — и питомцу")
	check(p.set_toggle("fire_skin", true) == "" and float(p.skill_bonus.get("thorns", 0.0)) > 0.2, "«Огненная кожа» включена")
	for id in ["wind_step", "sacred_fire", "rock_strength", "water_edge"]:
		p.set_toggle(String(id), false)
	return 1


## Обычная атака без лезвия и с огненным лезвием: урон стихией добавляется.
func _s_edge_attack() -> int:
	var p: Player = main.player
	_arrange(Vector3(0, 0, 6.0))
	p.mp = p.max_mp
	check(p.set_toggle("fire_edge", true) == "", "«Огненное лезвие» включено")
	p._fx.state["edge_hits"] = 0
	p.accuracy = -1
	p.attack_cd = 0.0
	check(p.try_attack(), "сгусток посоха с огненным лезвием")
	return 40


func _s_edge_check() -> int:
	var p: Player = main.player
	check(int(p._fx.state.get("edge_hits", 0)) == 1 and m1.hp < hp1, "огненное лезвие добавило урон огнём (урон всего %d)" % (hp1 - m1.hp))
	return 1


## Свойства лезвий (шанс — 100 % для проверки): молния оглушает, земля травит, вода возвращает MP.
func _s_edge_procs() -> int:
	var p: Player = main.player
	_arrange(Vector3(0, 0, 6.0))
	p.mp = p.max_mp / 2
	val = float(p.mp)
	p.skill_bonus["edge_stun"] = 1.0
	p.skill_bonus["edge_poison"] = 1.0
	p.skill_bonus["edge_mp"] = 1.0
	p._fx.state["edge_mp_hits"] = 0
	p.accuracy = -1
	p.attack_cd = 0.0
	check(p.try_attack(), "сгусток посоха со свойствами лезвий")
	return 40


func _s_edge_procs_check() -> int:
	var p: Player = main.player
	check(m1.stun_time > 0.0, "грозовое лезвие оглушило")
	check(_has_dot(m1, "stone_edge"), "каменное лезвие отравило")
	check(int(p._fx.state.get("edge_mp_hits", 0)) == 1 and float(p.mp) > val, "водное лезвие вернуло MP: %d → %d" % [int(val), p.mp])
	p.recalc_stats()
	check(not p.skill_bonus.has("edge_stun"), "свойства — снова по включённому лезвию")
	return 1


## «Огненная кожа»: зверь, ударивший вблизи, получает огнём.
func _s_fire_skin() -> int:
	var p: Player = main.player
	_arrange(Vector3(0, 0, 1.6))
	AdminPanel.god = false
	p._fx.state["thorns_hits"] = 0
	var tries := 0
	while int(p._fx.state.get("thorns_hits", 0)) == 0 and tries < 30:
		p.hp = p.max_hp
		p.take_damage(5, m1)
		tries += 1
	AdminPanel.god = true
	p.hp = p.max_hp
	check(int(p._fx.state.get("thorns_hits", 0)) >= 1 and m1.hp < hp1, "«Огненная кожа»: ответ огнём %d" % (hp1 - m1.hp))
	p.set_toggle("fire_skin", false)
	return 1


## Мгновенные заклинания: «Хватка земли», «Палящий жар», «Омут сна», «Обвал»; удар «Удар с разворота».
func _s_spells_instant() -> int:
	_arrange(Vector3(0, 0, 6.0))
	_cast("earth_grip")
	check(m1.hp < hp1 and m1.stun_time > 6.0, "«Хватка земли»: урон и держит на месте 7 с")
	_arrange(Vector3(0, 0, 6.0))
	_cast("scorching_heat")
	check(m1.hp < hp1 and _has_dot(m1, "scorching_heat"), "«Палящий жар»: вспышка и горение")
	_arrange(Vector3(0, 0, 6.0))
	_cast("slumber_pool")
	check(m1.sleep_time > 8.0 and m1.effects.has("sleep"), "«Омут сна»: зверь спит %.1f с" % m1.sleep_time)
	_arrange(Vector3(0, 0, 6.0))
	_cast("rockslide")
	check(m1.hp < hp1 and m2.hp < hp2, "«Обвал» ранил обоих зверей: %d, %d" % [hp1 - m1.hp, hp2 - m2.hp])
	_arrange(Vector3(0, 0, 1.6))
	_cast("spin_strike")
	check(m1.hp < hp1, "«Удар с разворота» (посох)")
	return 1


func _s_proj_cast(sid: String) -> int:
	_arrange(Vector3(0, 0, 6.0))
	cur = sid
	_cast(sid)
	return 40


func _s_proj_check(sid: String) -> int:
	check(m1.hp < hp1, "«%s» попало: %d" % [String(HeroSkills.get_skill(sid)["name"]), hp1 - m1.hp])
	if sid == "wind_sickle":
		check(m1.slow_time > 0.0 and m1.weak_time > 0.0, "«Серп ветра»: зверь медленнее бежит и слабее бьёт")
	return 1


func _s_support() -> int:
	var p: Player = main.player
	p.clear_buffs()
	p.hp = p.max_hp / 2
	_cast("pure_spring")
	check(not p.hots.is_empty() and p.effects.has("hot:pure_spring"), "«Чистый родник»: лечение со временем на герое")
	var a0 := p.aspd
	_cast("gust")
	check(p.aspd > a0 and p.effects.has("buff:gust"), "«Порыв»: скорость атаки %.2f → %.2f" % [a0, p.aspd])
	var c0 := p.cur_crit()
	_cast("focus_moment")
	check(p.cur_crit() > c0, "«Миг сосредоточения»: крит выше")
	p.clear_buffs()
	return 1


func _s_frenzies() -> int:
	var p: Player = main.player
	var a0 := p.atk
	var d0 := p.defense
	_cast("fire_frenzy")
	check(p.atk > a0 and p.defense < d0, "«Неистовство огня»: атака %d → %d, защита %d → %d" % [a0, p.atk, d0, p.defense])
	check(p._fx.state.has("burn") and p.effects.has("burn:fire_frenzy"), "огонь жжёт шамана (значок)")
	p.regen_delay = 100.0
	p.hp_regen = 0.0
	p.hp = p.max_hp
	val = float(p.hp)
	var s0 := p.aspd
	var h0 := p.hp
	_cast("thunder_frenzy")
	check(p.hp < h0 and p.aspd > s0, "«Неистовство грома»: HP %d → %d, скорость атаки %.2f → %.2f" % [h0, p.hp, s0, p.aspd])
	val = float(p.hp)
	_cast("earth_frenzy")
	check(p.skill_guard >= 0.5, "«Неистовство земли»: урон по шаману −%.0f%%" % (p.skill_guard * 100.0))
	var m0 := p.matk
	_cast("water_frenzy")
	check(p.matk > m0, "«Неистовство воды»: маг. атака %d → %d" % [m0, p.matk])
	p.regen_delay = 100.0
	p.hp_regen = 0.0
	return 90


func _s_burn_check() -> int:
	var p: Player = main.player
	check(float(p.hp) < val, "горение «Неистовства огня»: HP %d → %d" % [int(val), p.hp])
	p.clear_buffs()
	check(not p._fx.state.has("burn") and not p.effects.has("burn:fire_frenzy"), "горение снято вместе с усилениями")
	return 1


## Шаман с топором: «Камнелом» (площадь и оглушение).
func _s_axe() -> int:
	var p: Player = main.player
	_equip("weapon_axe_2h_r1")
	check(p.weapon_kind == "axe_2h", "Шаман с двуручным топором")
	_arrange(Vector3(0, 0, 1.6))
	_cast("stonebreaker")
	check(m1.hp < hp1 and m2.hp < hp2 and m1.stun_time > 0.0, "«Камнелом» Шамана: оба зверя ранены, цель оглушена")
	_equip("weapon_staff_2h_r1")
	return 1


func _s_balance() -> int:
	var p: Player = main.player
	p.mp = p.max_mp
	p.set_toggle("fire_edge", true)
	_check_ttk("Шаман (посох, огненное лезвие)", "fire_edge")
	return 1
