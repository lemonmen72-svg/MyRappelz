extends "res://tests/test_base.gd"
## Умения и оружие героя (Наёмник): данные древа (HeroSkills) и темп JP, стартовый набор оружия,
## смена оружия (ближняя атака / выстрел болтом, дальность, скорость, модель: клинки в обеих руках / арбалет),
## строгая привязка умений к оружию (кнопки HUD затемнены, use_skill отказывает, переключаемые выключаются
## при смене оружия, пассивки владения — только со своим оружием), изучение за JP (уровень, пререквизит, JP),
## пассивки меняют показатели, активные тратят MP и уходят на перезарядку, назначение на кнопки 1–4,
## переключаемые (MP, поддержка, выключение без MP), сон / страх / отбрасывание / урон со временем у зверей,
## JP за опыт, окно героя (вкладка «Герой»: 7 характеристик и боевые показатели, выбор оружия; древо по вкладкам,
## карточка, «+ JP», «На кнопку»), 7 статов героя и производные (HeroStats: калибровка 1-го уровня, рост, точность
## и промахи, атака арбалета от Меткости), сохранение и загрузка, старые сохранения (воин → Наёмник),
## Бродяга без умений. Требования умений — 10 + JLv вики × 0.75 (профессия с 10 ур.); герой теста — Наёмник,
## уже сменивший профессию (race_class), уровень для изучения поднимается до 40.

const MainScript := preload("res://main.gd")

var mob: Mob = null
var timer := 0
var hp_before := 0
var mp_before := 0
var dist_before := 0.0


func race_class() -> Array:
	return ["dark_elf", "assassin"]


func run_step() -> void:
	var player: Player = main.player
	match step:
		0:
			_check_data()
			_check_start(player)
			_check_stats(player)
			step = 1
		1:
			# Оружие: два кинжала → один меч → два меча → арбалет
			check(player.weapon_kind == "daggers" and player.attack_kind == "melee", "в руках два кинжала, ближний бой")
			check(is_equal_approx(player.attack_range, 2.2), "дальность кинжалов 2.2 м")
			_check_model(player, ["DaggerR", "DaggerL"], "кинжалы в обеих руках")
			var cd_daggers := player.attack_time
			game.inventory.add("weapon_sword_1h_r1", 2)
			check(player.equip("weapon_sword_1h_r1") == "" and player.weapon_kind == "sword_1h" and game.offhand == "",
				"один меч: кинжал из второй руки снят")
			check(player.slot_block("skill1") == "", "«Удар в спину» и с одним мечом")
			check(_swords(player), "второй меч во вторую руку — два меча")
			check(player.attack_time > cd_daggers, "мечи бьют реже кинжалов: %.2f > %.2f с" % [player.attack_time, cd_daggers])
			_check_model(player, ["Sword", "SwordL"], "два меча в обеих руках")
			check(player.equip("crossbow_starter") == "", "надет лёгкий арбалет")
			check(player.attack_kind == "ranged" and player.attack_range > 10.0, "арбалет стреляет издалека: %.1f м"
				% player.attack_range)
			_check_model(player, ["Crossbow"], "арбалет в руках")
			check(player._model.find_child("SwordL", true, false) == null, "с арбалетом клинков в руках нет")
			check(player.equip("hp_potion") != "", "зелье не надеть как оружие")
			check(player.equip("dagger_steel") != "", "оружие не из сумки не надеть")
			mob = find_mob("pheasant")
			check(mob != null, "найден фазан")
			place_far(mob, 8.0)
			player.select_target(mob)
			hp_before = mob.hp
			check(player.try_attack(), "выстрел из арбалета")
			var bolts := 0
			for n in get_tree().get_nodes_in_group("projectiles"):
				if (n as Projectile).kind == "bolt":
					bolts += 1
			check(bolts > 0, "летит болт (%d)" % bolts)
			check(mob.hp == hp_before, "урон — при попадании болта")
			if player._model._asset != null:
				check(player._model._anim.current_animation == player._model._clip("crossbow_shoot"),
					"арбалет: клип выстрела (%s)" % player._model._anim.current_animation)
			timer = 0
			wait = 2
			step = 2
		2:
			timer += 1
			if not mob_ok(mob) or mob.hp < hp_before:
				check(true, "болт попал: %d → %d" % [hp_before, mob.hp if mob_ok(mob) else 0])
				step = 3
				return
			if timer > 120:
				fail("болт не долетел за 2 с")
		3:
			# Привязка умений к оружию: «Удар в спину» (клинки) с арбалетом нельзя, «Шаг тени» (общее) можно
			check(player.slot_block("skill1") == "Нужны клинки", "кнопка 1 с арбалетом: «%s»" % player.slot_block("skill1"))
			check(main.hud.is_blocked("skill1") and main.hud.button_text("skill1").contains("нужны клинки"),
				"кнопка «Удар в спину» затемнена с подсказкой: %s" % main.hud.button_text("skill1").replace("\n", " "))
			check(player.slot_block("skill2") == "" and not main.hud.is_blocked("skill2"), "«Шаг тени» — с любым оружием")
			mob = find_mob("pheasant")
			stand_near(mob)
			player.select_target(mob)
			check(not player.use_skill("skill1"), "с арбалетом «Удар в спину» не применить")
			check(main.hud._msg_label.text.contains("Нужны клинки"), "сообщение: %s" % main.hud._msg_label.text)
			check(_swords(player), "снова два меча")
			check(player.slot_block("skill1") == "" and not main.hud.is_blocked("skill1"), "с мечами кнопка 1 доступна")
			step = 4
		4:
			_check_learning(player)
			step = 5
		5:
			# Активное: назначить на кнопку 3, применить — MP, перезарядка, урон
			var rec: Dictionary = game.hero
			check(HeroSkills.learn(rec, "assassin", game.level, "charge_stab"), "изучен «Пронзающий выпад»")
			player.refresh_skills()
			check(player.assign_slot("charge_stab", 2), "«Пронзающий выпад» — на кнопку 3")
			check(player.skill_id("skill3") == "charge_stab", "кнопка 3 — «Пронзающий выпад»")
			check(main.hud.is_button_visible("skill3") and main.hud.button_text("skill3") == "Пронзающий выпад",
				"кнопка 3 в HUD: «%s»" % main.hud.button_text("skill3"))
			check(not player.assign_slot("blade_mastery", 3), "пассивное на кнопку не назначить")
			mob = find_mob("wolf")
			if mob == null:
				mob = find_mob("pheasant")
			stand_near(mob)
			player.select_target(mob)
			player.mp = player.max_mp
			mp_before = player.mp
			hp_before = mob.hp
			check(player.use_skill("skill3"), "«Пронзающий выпад» применён")
			check(player.mp == mp_before - HeroSkills.mp_cost("charge_stab", 1), "потрачено MP: %d → %d" % [mp_before, player.mp])
			check(not mob_ok(mob) or mob.hp < hp_before, "«Пронзающий выпад» нанёс урон")
			check(player.cooldown_frac("skill3") > 0.9, "«Пронзающий выпад» на перезарядке")
			check(not player.use_skill("skill3"), "повтор на перезарядке не срабатывает")
			player.mp = 0
			player.skill_cd.clear()
			check(not player.use_skill("skill3"), "без MP не применить")
			check(main.hud._msg_label.text.contains("MP"), "сообщение о MP: %s" % main.hud._msg_label.text)
			player.mp = player.max_mp
			# Арбалетное активное: с мечами — нельзя, с арбалетом — болты
			check(HeroSkills.learn(rec, "assassin", game.level, "crossbow_mastery"), "изучена «Твёрдая рука»")
			check(HeroSkills.learn(rec, "assassin", game.level, "dual_shot"), "изучен «Сдвоенный болт»")
			check(player.assign_slot("dual_shot", 3), "«Сдвоенный болт» — на кнопку 4")
			main.refresh_skill_buttons()
			check(main.hud.is_blocked("skill4") and main.hud.button_text("skill4").contains("нужен арбалет"),
				"с мечами кнопка «Сдвоенного болта» затемнена")
			check(not player.use_skill("skill4"), "с мечами «Сдвоенный болт» не применить")
			check(main.hud._msg_label.text.contains("Нужен арбалет"), "сообщение: %s" % main.hud._msg_label.text)
			check(player.equip("crossbow_starter") == "", "надет арбалет")
			check(not main.hud.is_blocked("skill4") and main.hud.is_blocked("skill3"), "с арбалетом: кнопка 4 доступна, 3 — нет")
			mob = find_mob("pheasant")
			place_far(mob, 8.0)
			player.select_target(mob)
			mp_before = player.mp
			var before := get_tree().get_nodes_in_group("projectiles").size()
			check(player.use_skill("skill4"), "«Сдвоенный болт» применён")
			check(get_tree().get_nodes_in_group("projectiles").size() > before, "болт летит")
			check(player.mp == mp_before - HeroSkills.mp_cost("dual_shot", 1), "«Сдвоенный болт» потратил MP")
			check(player.cooldown_frac("skill4") > 0.9, "«Сдвоенный болт» на перезарядке")
			step = 6
		6:
			_check_toggles(player)
			wait = 2
			step = 7
		7:
			# Сон, страх, отбрасывание, урон со временем (умения героя и сами механизмы зверя)
			var rec: Dictionary = game.hero
			check(_swords(player), "снова мечи")
			check(HeroSkills.learn(rec, "assassin", game.level, "sleeping_dust"), "изучена «Сонная пыльца»")
			mob = find_mob("pheasant")
			stand_near(mob)
			player.select_target(mob)
			player.mp = player.max_mp
			check(player.use_skill("sleeping_dust"), "«Сонная пыльца» применена")
			check(mob.sleep_time >= 7.9, "фазан спит %.1f с" % mob.sleep_time)
			mob.take_damage(1, player)
			check(mob.sleep_time == 0.0, "удар будит")
			mob.knock_back(player.global_position, 5.0)
			check(mob.global_position.distance_to(player.global_position) > 2.0, "отбрасывание: %.1f м"
				% mob.global_position.distance_to(player.global_position))
			mob.add_dot("test", 6.0, 2.0, player, true)
			check(mob.no_regen_time > 0.0, "под кровотечением зверь не лечится")
			hp_before = mob.hp
			mob.frighten(2.0, player.global_position)
			dist_before = mob.global_position.distance_to(player.global_position)
			timer = 0
			step = 8
		8:
			timer += 1
			player.hp = player.max_hp
			if timer < 70:
				return
			if mob_ok(mob):
				check(mob.hp < hp_before, "урон со временем: %d → %d" % [hp_before, mob.hp])
				check(mob.global_position.distance_to(player.global_position) > dist_before,
					"страх: зверь убегает (%.1f → %.1f м)" % [dist_before, mob.global_position.distance_to(player.global_position)])
			step = 9
		9:
			# JP за опыт: уровень опыта — 10 JP
			var rec: Dictionary = game.hero
			rec["jp_part"] = 0.0
			game.xp = 0
			var jp0 := int(rec["jp"])
			var lvl: int = game.level
			player.gain_xp(game.xp_to_next(game.level))
			check(game.level == lvl + 1, "герой получил уровень")
			check(int(rec["jp"]) == jp0 + HeroSkills.JP_PER_LEVEL, "за уровень опыта +%d JP: %d → %d"
				% [HeroSkills.JP_PER_LEVEL, jp0, int(rec["jp"])])
			var jp1 := int(rec["jp"]) + float(rec["jp_part"])
			player.gain_xp(maxi(1, game.xp_to_next(game.level) / 4))
			check(int(rec["jp"]) + float(rec["jp_part"]) > jp1 + 2.0, "JP копятся по долям за каждое убийство")
			step = 10
		10:
			_check_window(player)
			wait = 3
			step = 11
		11:
			_check_save(player)
			wait = 3
			step = 12
		12:
			# Бродяга: умений нет — кнопки скрыты, в окне героя одна вкладка «Умения» с подсказкой
			game.race_id = "human"
			game.class_id = "wanderer"
			player.apply_class()
			check(game.weapon == "weapon_sword_1h_r1" and player.weapon_kind == "sword_1h", "у Бродяги учебный меч")
			check((game.hero["skills"] as Dictionary).is_empty(), "у Бродяги нет умений")
			for i in 4:
				check(not main.hud.is_button_visible("skill%d" % (i + 1)), "кнопка умения %d скрыта" % (i + 1))
			check(not player.use_skill("skill1") and main.hud._msg_label.text.contains("10 уровне"),
				"кнопка пуста: %s" % main.hud._msg_label.text)
			var hw: CharacterWindow = main.hero_window
			hw.open("hero")
			check(hw.is_open() and hw.buttons.has("tab_wanderer") and not hw.buttons.has("tab_blades"), "одна вкладка «Умения»")
			hw.buttons["tab_wanderer"].pressed.emit()
			check(_window_text().contains("Умения появятся после выбора профессии на 10 уровне"), "подсказка у Бродяги")
			main.hud.close_window()
			ok_done()


# ---------- Проверки ----------

## Данные древа: поля, уровни, пререквизиты, тексты, темп JP.
func _check_data() -> void:
	var ids := HeroSkills.list_for("assassin")
	check(ids.size() >= 20, "у Наёмника %d умений в древе" % ids.size())
	var bad := ""
	var names: Dictionary = {}
	for id in ids:
		var sid := String(id)
		var sk := HeroSkills.get_skill(sid)
		if sk.is_empty() or String(sk.get("name", "")) == "" or String(sk.get("desc", "")) == "":
			bad += " %s: нет данных" % sid
			continue
		if names.has(sk["name"]):
			bad += " %s: повтор названия" % sid
		names[sk["name"]] = true
		var mx := HeroSkills.max_level(sid)
		if mx <= 0 or (sk["jp"] as Array).size() != mx:
			bad += " %s: уровни/JP" % sid
		var prev := 0
		for n in range(1, mx + 1):
			var need := HeroSkills.level_needed(sid, n)
			if need < prev or need < 10 or need > 40:
				bad += " %s: ур. %d" % [sid, n]
			prev = need
			if HeroSkills.effect_text(sid, n) == "" or HeroSkills.requirement_text(sid, n) == "":
				bad += " %s: тексты" % sid
		if not ["common", "blades", "crossbow"].has(String(sk["tab"])) or not ["", "blades", "crossbow"].has(String(sk["weapon"])):
			bad += " %s: вкладка/оружие" % sid
		var kind := String(sk["kind"])
		if kind == "active" and HeroSkills.cooldown(sid, 1) <= 0.0:
			bad += " %s: перезарядка" % sid
		if kind == "toggle" and (HeroSkills.mp_cost(sid, 1) <= 0 or HeroSkills.upkeep(sid, 1) <= 0 or not sk.has("bonus")):
			bad += " %s: MP переключаемого" % sid
		if kind == "passive" and not sk.has("bonus"):
			bad += " %s: бонус" % sid
		if sk.has("pre"):
			var pre := String((sk["pre"] as Array)[0])
			if not ids.has(pre) or HeroSkills.level_needed(pre, 1) > HeroSkills.level_needed(sid, 1):
				bad += " %s: пререквизит" % sid
	check(bad == "", "данные древа в порядке" + bad)
	for t in HeroSkills.TABS:
		check(HeroSkills.list_tab("assassin", String(t[0])).size() >= 5, "вкладка «%s»: умений %d"
			% [String(t[1]), HeroSkills.list_tab("assassin", String(t[0])).size()])
	check(HeroSkills.level_needed("charge_stab", 1) == 14 and HeroSkills.level_needed("dark_strike", 1) == 18
		and HeroSkills.level_needed("bloody_blade", 1) == 21 and HeroSkills.level_needed("critical_shot", 1) == 36
		and HeroSkills.level_needed("drain_arrow", 1) == 40 and HeroSkills.level_needed("blade_mastery", 1) == 11,
		"ур. = 10 + JLv × 0.75: 1→11, 5→14, 10→18, 15→21, 35→36, 40→40")
	check(HeroSkills.level_needed("shadow_step", 1) == 10 and HeroSkills.level_needed("backstab", 1) == 10,
		"стартовые «Шаг тени» и «Удар в спину» — с получения профессии (10 ур.)")
	var total := HeroSkills.total_cost("assassin")
	var have := HeroSkills.default_jp(15)
	check(float(have) >= float(total) * 0.35 and float(have) <= float(total) * 0.65,
		"к 15 ур. %d JP — примерно половина древа (%d JP)" % [have, total])
	check(HeroSkills.icon_path("charge_stab") == "res://assets/icons/skills/charge_stab.png", "значок: assets/icons/skills/<id>.png")
	check(HeroSkills.list_for("warrior").size() == 24 and HeroSkills.tabs_for("warrior").size() == 3,
		"у Воина своё древо: 24 умения, 3 вкладки")
	check(HeroSkills.list_for("wanderer").is_empty() and HeroSkills.tabs_for("wanderer").is_empty(), "у Бродяги умений нет")
	check(HeroSkills.weapon_block("dual_shot", "dual_swords") == "Нужен арбалет"
		and HeroSkills.weapon_block("charge_stab", "crossbow") == "Нужны клинки"
		and HeroSkills.weapon_block("charge_stab", "daggers") == "" and HeroSkills.weapon_block("oblivion", "crossbow") == "",
		"требования к оружию: арбалетные / клинковые / общие")


## Новый Наёмник: стартовые умения и кнопки, JP, оружие, MP.
func _check_start(player: Player) -> void:
	var rec: Dictionary = game.hero
	check(HeroSkills.skill_level(rec, "backstab") == 1 and HeroSkills.skill_level(rec, "shadow_step") == 1,
		"стартовые умения изучены")
	check(player.skill_id("skill1") == "backstab" and player.skill_id("skill2") == "shadow_step", "стартовые умения на кнопках 1 и 2")
	check(player.skill_id("skill3") == "" and not main.hud.is_button_visible("skill3"), "кнопка 3 пуста и скрыта")
	check(int(rec["jp"]) == HeroSkills.JP_START, "у нового героя %d JP" % HeroSkills.JP_START)
	check(game.weapon == "weapon_dagger_r1" and game.offhand == "weapon_dagger_r1" and player.weapon_kind == "daggers",
		"в руках два кинжала")
	for id in ItemData.STARTER_WEAPONS["assassin"]:
		check(game.inventory.has(String(id)), "в сумке %s" % ItemData.item_name(String(id)))
	check(player.max_mp > 0 and player.mp == player.max_mp, "у Наёмника есть MP: %d" % player.max_mp)
	check(main.hud._mp_bar.visible, "полоска MP в HUD")
	check(player.eva > 0.0, "у Наёмника есть уклонение: %d%%" % roundi(player.eva * 100.0))


## 7 статов героя (HeroStats) и производные: калибровка 1-го уровня под прежние числа Наёмника, рост с уровнем
## (близко к прежнему ClassData), точность и промахи, атака арбалета от Меткости, общий код со статами питомцев.
func _check_stats(player: Player) -> void:
	check(HeroStats.has_stats("assassin") and HeroStats.has_stats("warrior") and HeroStats.has_stats("wanderer"),
		"статы — у всех профессий и Бродяги")
	var s1 := HeroStats.base_stats("assassin", 1)
	check(s1 == {"str": 21, "vit": 22, "agi": 25, "int": 18, "wis": 18, "dex": 25, "luck": 12},
		"статы 1-го уровня (асура, Strider ур. проф. 3): %s" % [s1])
	var d1 := HeroStats.derived("assassin", 1)
	var c := ClassData.cls("assassin")
	check(int(d1["max_hp"]) == int(c["hp"]) and int(d1["patk"]) == int(c["atk"]) and int(d1["ratk"]) == int(c["atk"])
		and int(d1["def"]) == int(c["def"]) and int(d1["max_mp"]) == int(c["mp"]),
		"1-й уровень = прежние числа: HP %d, атака %d/%d, защита %d, MP %d" % [int(d1["max_hp"]), int(d1["patk"]),
		int(d1["ratk"]), int(d1["def"]), int(d1["max_mp"])])
	check(absf(float(d1["eva"]) - 100.0 * float(c["eva"])) < 0.01 and absf(float(d1["crit"]) - 100.0 * float(c["crit"])) < 0.01,
		"уклонение %.1f%%, крит %.1f%% на 1-м уровне" % [float(d1["eva"]), float(d1["crit"])])
	# Рост: статы не убывают, HP / атака / защита / MP растут и близки к прежней формуле (±20%)
	var prev := d1
	var bad := ""
	for lv in range(2, 16):
		var d := HeroStats.derived("assassin", lv)
		for k in Stats.STATS:
			if int(d["stats"][k]) < int(prev["stats"][k]):
				bad += " ур.%d %s" % [lv, k]
		for k in ["max_hp", "patk", "max_mp", "acc"]:
			if int(d[k]) <= int(prev[k]):
				bad += " ур.%d %s" % [lv, k]
		var old := ClassData.stats_for("assassin", lv)
		for pair in [["max_hp", "max_hp"], ["patk", "atk"], ["def", "def"], ["max_mp", "max_mp"]]:
			var nv := float(d[pair[0]])
			var ov := float(old[pair[1]])
			if absf(nv - ov) > maxf(2.0, ov * 0.2):
				bad += " ур.%d %s %d/%d" % [lv, pair[0], int(nv), int(ov)]
		prev = d
	check(bad == "", "рост статов и производных по уровням" + bad)
	var d15 := HeroStats.derived("assassin", 15)
	check(float(d15["eva"]) > float(d1["eva"]) and int(d15["aspd"]) > int(d1["aspd"]), "Ловкость растёт: уклонение и скорость атаки выше")
	# Игрок: статы применены, оружие поверх
	check(player.hero_stats.size() > 0 and player.max_hp == int(d1["max_hp"]) and player.max_mp == int(d1["max_mp"]),
		"игрок 1-го ур.: HP %d, MP %d" % [player.max_hp, player.max_mp])
	var dg := ItemData.grip_bonus("weapon_dagger_r1", "weapon_dagger_r1")
	check(player.atk == int(d1["patk"]) + int(dg["atk"]), "атака с двумя кинжалами: %d = %d + %d"
		% [player.atk, int(d1["patk"]), int(dg["atk"])])
	check(player.matk == int(d1["matk"]) + int(dg["matk"]), "кинжалы дают и маг. атаку: %d = %d + %d"
		% [player.matk, int(d1["matk"]), int(dg["matk"])])
	check(is_equal_approx(player.eva, float(d1["eva"]) / 100.0) and is_equal_approx(player.crit, float(d1["crit"]) / 100.0),
		"уклонение %.1f%% и крит %.1f%% героя — из статов" % [player.eva * 100.0, player.crit * 100.0])
	check(is_equal_approx(player.aspd, float(d1["aspd"]) / 100.0 + 0.25), "скорость атаки от Ловкости и кинжала (+25%%): %d%%"
		% roundi(player.aspd * 100.0))
	check(is_equal_approx(player.attack_time, ItemData.base_cd("dagger") / player.aspd), "удар раз в %.2f с" % player.attack_time)
	check(player.accuracy == int(d1["acc"]) and player.hp_regen > 0.0, "точность %d, восстановление HP %.1f/с"
		% [player.accuracy, player.hp_regen])
	check(player.mp_regen_rate(true) > 0.0 and player.mp_regen_rate(false) > player.mp_regen_rate(true), "восстановление MP")
	check(player.equip("crossbow_starter") == "", "арбалет")
	var cb := ItemData.get_item("crossbow_starter")
	check(player.atk == int(d1["ratk"]) + int(cb["atk"]), "атака арбалета от Меткости: %d" % player.atk)
	check(is_equal_approx(player.aspd, float(d1["aspd"]) / 100.0 - 0.2), "арбалет: скорость атаки −20%")
	check(_daggers(player), "снова кинжалы")
	# Точность: по зверям своего уровня без промахов, по сильным — изредка
	var weak := find_mob("pheasant")
	check(weak != null and player.hit_chance(weak) >= 1.0, "по фазану 1-го ур. без промахов")
	var hc10 := Stats.hit_chance(player.accuracy, 10)
	check(hc10 >= 0.75 and hc10 < 1.0, "по зверю 10-го ур. попадание %d%%" % roundi(hc10 * 100.0))
	var acc0 := player.accuracy
	player.accuracy = 0
	var miss := 0
	for i in 200:
		if not player._basic_hits(weak):
			miss += 1
	player.accuracy = acc0
	check(miss > 0 and miss < 100, "при низкой точности промахи: %d из 200" % miss)
	check(PetStats.hit_chance(30, 5) == Stats.hit_chance(30, 5) and PetStats.STATS == Stats.STATS,
		"формулы питомцев и героя общие (Stats)")


## Модель игрока: нужные узлы оружия (модель из файла — ещё метки кистей GripR/GripL).
func _check_model(player: Player, parts: Array, what: String) -> void:
	var ok := true
	for part in parts:
		ok = ok and player._model.find_child(String(part), true, false) != null
	check(ok, "модель: %s %s" % [what, parts])
	check(player._model.weapon_kind == player.weapon_kind, "модель держит %s" % player.weapon_kind)


## Изучение: уровень, пререквизит, JP; пассивки владения — только со своим оружием.
func _check_learning(player: Player) -> void:
	var rec: Dictionary = game.hero
	check(HeroSkills.learn_block(rec, "assassin", 1, "charge_stab").contains("ур. 14"), "«Пронзающий выпад» — с 14 уровня")
	check(HeroSkills.learn_block(rec, "assassin", 1, "critical_shot").contains("ур. 36"), "«Выстрел в сердце» — с 36 уровня")
	game.level = 40
	player.recalc_stats()
	rec["jp"] = 0
	check(HeroSkills.learn_block(rec, "assassin", 40, "blade_mastery").contains("JP"), "без JP не изучить")
	rec["jp"] = 200
	check(HeroSkills.learn_block(rec, "assassin", 40, "dark_strike").contains("Пронзающий выпад"),
		"«Три тени» требует «Пронзающий выпад»")
	# Пассивка владения клинками: с мечами атака выше, с арбалетом — без неё
	var atk0 := player.atk
	check(HeroSkills.learn(rec, "assassin", 40, "blade_mastery"), "изучена «Школа клинка»")
	check(int(rec["jp"]) == 200 - HeroSkills.jp_cost("blade_mastery", 1), "списано %d JP" % HeroSkills.jp_cost("blade_mastery", 1))
	player.refresh_skills()
	check(player.atk > atk0, "«Школа клинка» с мечами: атака %d → %d" % [atk0, player.atk])
	check(player.equip("crossbow_starter") == "", "арбалет")
	var bow_atk := player.atk
	var b := HeroSkills.bonuses(rec, "assassin", "crossbow")
	check(not b.has("atk_pct"), "с арбалетом «Школа клинка» не действует")
	check(HeroSkills.learn(rec, "assassin", 40, "crossbow_mastery"), "изучена «Твёрдая рука»")
	player.refresh_skills()
	check(player.atk > bow_atk, "«Твёрдая рука» с арбалетом: атака %d → %d" % [bow_atk, player.atk])
	check(_swords(player), "мечи")
	check(not HeroSkills.bonuses(rec, "assassin", "dual_swords").has("atk_flat"), "с мечами «Твёрдая рука» не действует")
	# Общие пассивки: уклонение и HP
	var eva0 := player.eva
	var hp0 := player.max_hp
	check(HeroSkills.learn(rec, "assassin", 40, "evasion_expert"), "изучена «Неуловимость»")
	check(HeroSkills.learn(rec, "assassin", 40, "armor_mastery"), "изучена «Стойкость странницы»")
	player.refresh_skills()
	check(player.eva > eva0, "уклонение %d%% → %d%%" % [roundi(eva0 * 100.0), roundi(player.eva * 100.0)])
	check(player.max_hp > hp0, "макс. HP %d → %d" % [hp0, player.max_hp])
	# Уклонение работает от ударов зверей
	var dodged := 0
	var m := find_mob("pheasant")
	for i in 100:
		player.hp = player.max_hp
		player.take_damage(5, m)
		if player.hp == player.max_hp:
			dodged += 1
	player.hp = player.max_hp
	check(dodged > 0 and dodged < 100, "уклонение от ударов зверя: %d из 100" % dodged)


## Переключаемые: MP при включении и поддержка, бонус, выключение без MP; оружейные выключаются при смене оружия.
func _check_toggles(player: Player) -> void:
	var rec: Dictionary = game.hero
	check(_swords(player), "мечи")
	check(HeroSkills.learn(rec, "assassin", game.level, "concentration"), "изучен «Холодный расчёт»")
	player.mp = player.max_mp
	var crit0 := player.crit
	check(player.set_toggle("concentration", true) == "", "«Холодный расчёт» включён")
	check(player.mp == player.max_mp - HeroSkills.mp_cost("concentration", 1), "включение стоит MP")
	check(player.crit > crit0 and HeroSkills.toggle_on(rec, "concentration"), "шанс крита выше: %d%% → %d%%"
		% [roundi(crit0 * 100.0), roundi(player.crit * 100.0)])
	check(player.toggle_upkeep() > 0, "поддержка %d MP / 10 с" % player.toggle_upkeep())
	var m0 := player.mp
	player.pay_upkeep()
	check(player.mp == m0 - player.toggle_upkeep(), "поддержка списана")
	# Кнопкой: назначить на кнопку и нажать — выключить и включить
	check(player.assign_slot("concentration", 2), "«Холодный расчёт» — на кнопку 3")
	check(player.use_skill("skill3") and not HeroSkills.toggle_on(rec, "concentration"), "кнопка выключила")
	check(player.use_skill("skill3") and HeroSkills.toggle_on(rec, "concentration"), "кнопка включила")
	var sb := (main.hud._buttons["skill3"]["panel"] as Panel).get_theme_stylebox("panel") as StyleBoxFlat
	check(sb != null and sb.bg_color == MainScript.TOGGLE_ON_COLOR, "кнопка включённого умения подсвечена")
	player.mp = 0
	player.pay_upkeep()
	check(not HeroSkills.toggle_on(rec, "concentration") and is_equal_approx(player.crit, crit0), "без MP выключилось")
	player.mp = player.max_mp
	# Оружейное переключаемое: «Вихрь клинков» — только с клинками
	for id in ["dark_strike", "bloody_blade", "dual_expert", "twin_fury"]:
		check(HeroSkills.learn(rec, "assassin", game.level, id), "изучено «%s»" % HeroSkills.get_skill(id)["name"])
	player.refresh_skills()
	check(player.set_toggle("twin_fury", true) == "" and player.double_chance > 0.0, "«Вихрь клинков»: шанс второго удара %d%%"
		% roundi(player.double_chance * 100.0))
	check(player.equip("crossbow_starter") == "", "арбалет")
	check(not HeroSkills.toggle_on(rec, "twin_fury") and is_zero_approx(player.double_chance),
		"при смене на арбалет «Вихрь клинков» выключился")
	check(player.set_toggle("twin_fury", true) == "Нужны клинки", "с арбалетом «Вихрь клинков» не включить")
	check(player.equip("weapon_dagger_r1") == "" and player.weapon_kind == "dagger", "один кинжал")
	check(player.set_toggle("twin_fury", true) == "", "«Вихрь клинков» и с одним кинжалом")
	check(_swords(player) and HeroSkills.toggle_on(rec, "twin_fury"), "кинжал → два меча: «Вихрь клинков» остался включён")
	check(player.set_toggle("twin_fury", false) == "" and is_zero_approx(player.double_chance), "«Вихрь клинков» выключен")
	player.mp = player.max_mp


## Окно героя: вкладка «Герой» (показатели, выбор оружия), древо по вкладкам, карточка, изучение, кнопки.
func _check_window(player: Player) -> void:
	main._on_action("hero_window")
	var hw: CharacterWindow = main.hero_window
	check(hw.is_open() and hw.tab == "hero", "окно героя открыто на вкладке «Герой»")
	var t := _window_text()
	for w in ["Характеристики", "Боевые показатели", "Макс. HP", "Макс. MP", "Физ. атака", "Маг. атака", "Физ. защита",
			"Маг. защита", "Точность", "Уклонение", "Шанс крита", "Скорость атаки", "Восст. HP", "Восст. MP", "Дальность",
			"Оружие", "JP", "Наёмник", "MP %d / %d" % [player.mp, player.max_mp]]:
		check(t.contains(w), "во вкладке «Герой» есть «%s»" % w)
	for k in Stats.STATS:
		check(t.contains(String(Stats.STAT_NAMES[k])), "во вкладке «Герой» есть стат «%s»" % Stats.STAT_NAMES[k])
	check(t.contains("Ловкость\n%d" % int(player.hero_stats["stats"]["agi"])), "значение Ловкости в окне")
	check(not t.contains("Уклонение\n0.0%"), "уклонение в окне не 0%")
	for id in ItemData.STARTER_WEAPONS["assassin"]:
		check(hw.buttons.has("weapon_" + String(id)), "кнопка оружия %s" % String(id))
	var mv: SubViewportContainer = hw._body.find_children("*", "SubViewportContainer", true, false)[0]
	check(mv != null and not mv.find_children("PreviewModel", "", true, false).is_empty(), "3D-превью героя")
	hw.buttons["weapon_crossbow_starter"].pressed.emit()
	check(game.weapon == "crossbow_starter" and player.weapon_kind == "crossbow", "в окне выбран арбалет")
	check(hw.is_open() and (hw.buttons["weapon_crossbow_starter"] as Button).button_pressed, "окно обновилось")
	for k in ["tab_common", "tab_blades", "tab_crossbow"]:
		check(hw.buttons.has(k), "вкладка %s" % k)
	hw.buttons["tab_blades"].pressed.emit()
	check(hw.tab == "blades" and hw.tree != null, "вкладка «Мечи и кинжалы»: древо")
	var ids := HeroSkills.list_tab("assassin", "blades")
	check(hw.tree.icons.size() == ids.size(), "значков %d (умений %d)" % [hw.tree.icons.size(), ids.size()])
	var max_rows := int(floor(hw.tree.custom_minimum_size.y / SkillTree.row_min()))
	check(hw.tree.rows.size() <= max_rows and hw.tree.icon_size >= SkillTree.icon_min(), "ярусов %d, значки %.0f px — помещаются"
		% [hw.tree.rows.size(), hw.tree.icon_size])
	check(hw.tree.row_of("blade_mastery") < hw.tree.row_of("charge_stab")
		and hw.tree.row_of("charge_stab") < hw.tree.row_of("twin_fury"), "ярусы по требуемому уровню")
	check(bool(hw.tree._item("charge_stab")["unfit"]), "с арбалетом клинковые умения помечены")
	hw.buttons["skill_charge_stab"].pressed.emit()
	t = _window_text()
	check(t.contains("Пронзающий выпад") and t.contains("Не подходит к текущему оружию"), "карточка: не подходит к оружию")
	# Изучение кнопкой
	var rec: Dictionary = game.hero
	hw.buttons["skill_head_breaker"].pressed.emit()
	check(hw.selected == "head_breaker" and hw.buttons.has("learn_head_breaker"), "карточка «Устрашающего удара»")
	var jp0 := int(rec["jp"])
	hw.buttons["learn_head_breaker"].pressed.emit()
	check(HeroSkills.skill_level(rec, "head_breaker") == 1 and int(rec["jp"]) < jp0, "«+ JP» изучил «Устрашающий удар»")
	check(hw.is_open() and hw.tab == "blades" and hw.buttons.has("slot_4"), "окно перестроено, есть «На кнопку»")
	hw.buttons["slot_4"].pressed.emit()
	check(player.skill_id("skill4") == "head_breaker", "«Устрашающий удар» — на кнопке 4")
	hw.buttons["tab_crossbow"].pressed.emit()
	check(hw.tab == "crossbow" and hw.tree.icons.has("dual_shot") and hw.tree.icons.has("drain_arrow"), "вкладка «Арбалет»")
	hw.buttons["tab_common"].pressed.emit()
	check(hw.tree.icons.has("shadow_step") and hw.tree.icons.has("deep_evasion"), "вкладка «Общие»")
	hw.buttons["skill_quick_pace"].pressed.emit()
	if HeroSkills.learn_block(rec, "assassin", game.level, "quick_pace") == "":
		hw.buttons["learn_quick_pace"].pressed.emit()
		check(hw.buttons.has("toggle_quick_pace"), "у переключаемого в карточке — «Вкл»")
		var sp0 := player.speed
		hw.buttons["toggle_quick_pace"].pressed.emit()
		check(player.speed > sp0, "«Попутный ветер»: бег %.1f → %.1f м/с" % [sp0, player.speed])
	main._on_action("hero_window")
	check(not main.hud.is_window_open(), "клавиша K закрывает окно героя")
	check(_swords(player), "мечи")


## Сохранение и загрузка: оружие, JP, умения, переключаемые, кнопки; старые сохранения.
func _check_save(player: Player) -> void:
	var rec: Dictionary = game.hero
	check(_daggers(player), "кинжалы перед сохранением")
	check(game.save_game(), "игра сохранена")
	var jp := int(rec["jp"])
	var skills: Dictionary = (rec["skills"] as Dictionary).duplicate()
	var slots: Array = (rec["slots"] as Array).duplicate()
	var toggles: Dictionary = (rec["toggles"] as Dictionary).duplicate()
	game.weapon = "crossbow_starter"
	rec["jp"] = 0
	check(game.load_game(), "игра загружена")
	player.apply_class()
	var r: Dictionary = game.hero
	check(game.weapon == "weapon_dagger_r1" and game.offhand == "weapon_dagger_r1" and player.weapon_kind == "daggers",
		"оружие восстановлено: два кинжала")
	check(int(r["jp"]) == jp, "JP восстановлены: %d" % jp)
	var ok := (r["skills"] as Dictionary).size() == skills.size()
	for k in skills:
		ok = ok and HeroSkills.skill_level(r, String(k)) == int(skills[k])
	check(ok, "умения восстановлены: %s" % [r["skills"]])
	check(r["slots"] == slots, "кнопки восстановлены: %s" % [r["slots"]])
	check((r["toggles"] as Dictionary).keys() == toggles.keys(), "переключаемые восстановлены: %s" % [r["toggles"]])
	# Старое сохранение Наёмника без оружия и умений героя
	game.from_dict({"name": "Старая", "race": "dark_elf", "class": "assassin", "level": 5, "inventory": {"hp_potion": 2}})
	check(game.weapon == "weapon_dagger_r1" and game.offhand == "weapon_dagger_r1", "старое сохранение без оружия: два кинжала")
	for id in ItemData.STARTER_WEAPONS["assassin"]:
		check(game.inventory.has(String(id)), "старое сохранение: в сумке %s" % ItemData.item_name(String(id)))
	check(int(game.hero["jp"]) == HeroSkills.default_jp(5), "старое сохранение 5 ур.: %d JP" % int(game.hero["jp"]))
	check(HeroSkills.skill_level(game.hero, "backstab") == 1 and (game.hero["slots"] as Array)[0] == "backstab",
		"старое сохранение: стартовые умения на кнопках")
	check(game.load_note == "", "старая Наёмник загружена без сообщения о переводе")
	# Старый воин без умений героя: становится Наёмником (как сохранение Максима «Люди · Воин»)
	game.from_dict({"name": "Старый", "race": "human", "class": "warrior", "level": 3, "gold": 77})
	check(game.race_id == "dark_elf" and game.class_id == "assassin", "старый воин стал Наёмником")
	check(game.level == 3 and game.gold == 77, "уровень и золото сохранены")
	check(game.weapon == "weapon_dagger_r1" and game.offhand == "weapon_dagger_r1" and (game.hero["slots"] as Array)[0] == "backstab",
		"старый воин: два кинжала и «Удар в спину» на кнопке 1")
	check(int(game.hero["jp"]) == HeroSkills.default_jp(3), "старый воин 3 ур.: %d JP" % int(game.hero["jp"]))
	check(game.load_note.contains("Наёмник"), "сообщение игроку: %s" % game.load_note)
	check(game.load_game(), "игра загружена снова")
	player.apply_class()


# ---------- Помощники ----------

## Два меча в обеих руках (мечи — в сумку, если их меньше двух). true — надеты.
func _swords(player: Player) -> bool:
	var have := game.inventory.count("weapon_sword_1h_r1")
	if have < 2:
		game.inventory.add("weapon_sword_1h_r1", 2 - have)
	return player.equip("weapon_sword_1h_r1") == "" and player.equip("weapon_sword_1h_r1", true) == "" \
		and player.weapon_kind == "dual_swords"


## Два кинжала в обеих руках (стартовый набор Наёмника). true — надеты.
func _daggers(player: Player) -> bool:
	return player.equip("weapon_dagger_r1") == "" and player.equip("weapon_dagger_r1", true) == "" \
		and player.weapon_kind == "daggers"


## Весь текст открытого окна.
func _window_text() -> String:
	var t := ""
	var w: Control = main.hud._window
	if w != null and is_instance_valid(w):
		for n in w.find_children("*", "Label", true, false):
			t += (n as Label).text + "\n"
		for n in w.find_children("*", "Button", true, false):
			t += (n as Button).text + "\n"
	return t


## Ставит игрока на dist м от зверя, дальше от центра карты (вне безопасной зоны).
func place_far(m: Mob, dist: float) -> void:
	var p: Player = main.player
	var dir := Vector3(m.global_position.x, 0.0, m.global_position.z)
	if dir.length() < 0.1:
		dir = Vector3(0, 0, 1)
	var pos := m.global_position + dir.normalized() * dist
	if IslandWorld.current != null:
		pos.y = IslandWorld.current.height_at(pos.x, pos.z) + 0.1
	p.global_position = pos
	p.hp = p.max_hp
