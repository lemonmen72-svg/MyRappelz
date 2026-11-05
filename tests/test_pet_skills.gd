extends "res://tests/test_base.gd"
## Характеристики и умения питомцев (PetStats, PetSkills) и окно существа (CreatureWindow):
## статы по уровням и стадиям (рост, скачок на эволюции, обмен статов под роль), сила против зверей мира своего уровня,
## данные умений и бюджет JP, изучение (уровень, стадия, пререквизит, JP), пассивки меняют характеристики,
## JP за опыт, активные умения в бою (MP, перезарядка, урон, оглушение, замедление, морок), переключаемые
## (MP при включении и поддержка, бонус хозяину, выключение без MP), умения «по формам» из базы (3 уровня — по одному
## на форму: «Знаток снаряжения», «Живучесть», «Боец», «Способности карты»; числа, требования, перенос старых записей),
## окно существа (вкладки «Существо», «Активные», «Ауры и бафы», «Пассивные», «Оружие и доспехи»; крупное древо
## SkillTree: ярусы, пререквизиты, значки, карточка с кнопками, ячейки «Авто» и «Ауры»; ряд питомцев; снаряжение
## питомца из сумки), сохранение и загрузка умений, старые сохранения. Подробно ячейки и команды питомца — tests/test_pet_commands.gd.

const BASIC := ["panther", "turtle", "pheasant"]
## Виды, которых можно приручить (у них проверяется сила против зверей мира).
const TAMEABLE := ["wolf", "centaur", "panther", "turtle", "pheasant"]

var mob: Mob = null
var timer := 0
var mp_before := 0
var uses_before := 0
var jp_saved := 0
var skills_saved: Dictionary = {}


func before_start() -> void:
	game.add_pet("panther", PetData.stage_name("panther", 0), 1)
	game.add_pet("turtle", PetData.stage_name("turtle", 0), 20)
	game.add_pet("pheasant", PetData.stage_name("pheasant", 0), 10)
	game.add_pet("boar", PetData.stage_name("boar", 0), 5)
	game.active_pet = 0


func run_step() -> void:
	var player: Player = main.player
	var pm: PetManager = main.pets
	match step:
		0:
			_check_tables()
			_check_balance()
			_check_skill_data()
			_check_wolf()
			step = 1
		1:
			# Изучение умений: уровень, JP, пререквизит, стадия
			var pet: Pet = pm.active_pet
			check(pet != null and pet.species == "panther", "призвана пантера")
			check(pet.max_mp > 0 and pet.mp == pet.max_mp, "у питомца есть MP: %d" % pet.max_mp)
			check(main.hud._pet_mp_bar.visible, "полоска MP питомца в HUD")
			var rec: Dictionary = game.pets[0]
			check(int(rec["jp"]) == PetSkills.JP_START, "у нового питомца %d JP" % PetSkills.JP_START)
			check(PetSkills.learn_block(rec, "shadow_rend").contains("ур. 10"), "«Двойной росчерк» — с 10 уровня (1:1 с оригиналом): "
				+ PetSkills.learn_block(rec, "shadow_rend"))
			check(PetSkills.learn(rec, "inner_fire"), "изучен «Внутренний огонь» (ур. 1)")
			check(int(rec["jp"]) == PetSkills.JP_START - 1, "списан 1 JP")
			pet.level = 30
			pet.refresh_skills()
			check(int(rec["level"]) == 30 and pet.stage == 0, "пантера 30 уровня, 1-я стадия")
			rec["jp"] = 0
			check(PetSkills.learn_block(rec, "shadow_rend").contains("JP"), "без JP не изучить")
			check(not PetSkills.learn(rec, "shadow_rend"), "без JP умение не изучено")
			rec["jp"] = 60
			var pre_name := String(PetSkills.get_skill("shadow_rend")["name"])
			check(PetSkills.learn_block(rec, "dusk_rupture").contains(pre_name), "«Сумрачный разрыв» требует «%s»" % pre_name)
			for i in 5:
				check(PetSkills.learn(rec, "shadow_rend"), "«Двойной росчерк» ур. %d" % (i + 1))
			check(PetSkills.learn_block(rec, "shadow_rend").contains("стадия 2"), "6-й уровень — со 2-й стадии: "
				+ PetSkills.learn_block(rec, "shadow_rend"))
			check(PetSkills.cap_for("shadow_rend", 30) == 5 and PetSkills.cap_for("shadow_rend", 60, 0) == 5
				and PetSkills.cap_for("shadow_rend", 60, 1) == 10, "на 1-й форме — до 5 ур., на 2-й (с 60 ур.) — до 10")
			check(PetSkills.learn(rec, "dusk_rupture"), "после «Двойного росчерка» изучен «Сумрачный разрыв»")
			check(PetSkills.learn(rec, "shadow_fang") and PetSkills.learn(rec, "daze"), "изучены «Клык полуночи» и «Морок»")
			check(int(rec["jp"]) == 60 - 5 - 1 - 2 - 2, "JP списаны верно: %d" % int(rec["jp"]))
			check(rec["slots"] == ["shadow_rend", "dusk_rupture", "shadow_fang"] and not (rec["slots"] as Array).has("daze"),
				"новые активные умения сами встали в ячейки «Авто» (мест 3 — «Морок» без ячейки): %s" % [rec["slots"]])
			var bond_lvl := PetSkills.level_needed("shadow_bond", 1)
			check(PetSkills.learn_block(rec, "shadow_bond").contains("ур. %d" % bond_lvl), "«Узы тени» — с %d уровня" % bond_lvl)
			# Пассивки меняют характеристики
			var atk0 := pet.atk
			var hp0 := pet.max_hp
			for i in 4:
				PetSkills.learn(rec, "inner_fire")
			for i in 5:
				PetSkills.learn(rec, "vitality")
			pet.refresh_skills()
			check(PetSkills.skill_level(rec, "inner_fire") == 5 and PetSkills.skill_level(rec, "vitality") == 5,
				"пассивки изучены до 5 ур.")
			check(pet.atk > atk0, "«Внутренний огонь» усилил атаку: %d → %d" % [atk0, pet.atk])
			check(pet.max_hp > hp0, "«Живучесть» прибавила HP: %d → %d" % [hp0, pet.max_hp])
			check(is_same(pet.skills, rec["skills"]), "умения питомца — словарь из записи коллекции")
			step = 2
		2:
			# JP за опыт: уровень опыта — JP_PER_LEVEL очков
			var pet: Pet = pm.active_pet
			var rec: Dictionary = game.pets[0]
			var jp0 := int(rec["jp"])
			pet.gain_xp(PetData.xp_to_next(pet.level))
			check(pet.level == 31, "питомец получил уровень")
			check(int(rec["jp"]) == jp0 + PetSkills.JP_PER_LEVEL, "за уровень опыта +%d JP: %d → %d"
				% [PetSkills.JP_PER_LEVEL, jp0, int(rec["jp"])])
			var jp1 := int(rec["jp"])
			pet.gain_xp(maxi(1, int(float(PetData.xp_to_next(pet.level)) / 3.0)))
			check(int(rec["jp"]) + float(rec["jp_part"]) > float(jp1) + 0.9, "JP копятся и по долям за каждое убийство")
			step = 3
		3:
			# Эффекты умений напрямую: урон, оглушение и угроза, замедление, морок
			var pet: Pet = pm.active_pet
			# Зверь уровня питомца (по зверю намного выше уровнем умения мажут — Combat.skill_hit_chance); вожак анатем
			# («Редкий», HP ×1.3) переживает все три умения подряд даже с критами
			var gp: Vector3 = player.global_position + Vector3(4.0, 0.0, 0.0)
			var g: Mob = main.spawn_mob("anathema_chief", pet.level, IslandWorld.current.ground(gp.x, gp.z))
			check(g != null and g.level == pet.level and g.slot == -1, "поставлен вожак анатем %d ур. (main.spawn_mob)" % pet.level)
			var hp_g := g.hp
			pet._apply_skill("shadow_fang", g)
			check(g.hp < hp_g, "«Клык полуночи» ранил: %d → %d" % [hp_g, g.hp])
			check(g.stun_time > 0.0, "«Клык полуночи» оглушил")
			check(g.target == pet, "зверь переключился на питомца (угроза)")
			pet._apply_skill("dusk_rupture", g)
			check(g.slow_time > 0.0 and g.slow_frac > 0.0, "«Сумрачный разрыв» замедлил на %d%%" % roundi(g.slow_frac * 100.0))
			pet._apply_skill("daze", g)
			check(g.blind_time > 0.0, "«Морок» ослепил на %.1f с" % g.blind_time)
			check(g._missed(player), "под мороком зверь бьёт мимо")
			g.target = null
			g.taunt_time = 0.0
			g.stun_time = 0.0
			g.blind_time = 0.0
			g.consume()
			# Бой: ИИ сам применяет умения
			mob = find_mob("wolf")
			check(mob != null, "найден волк")
			stand_near(mob, 2.0)
			pet.global_position = mob.global_position + Vector3(5.0, 0.2, 0)
			player.last_target = mob
			pet.skill_cds.clear()
			pet.mp = pet.max_mp
			mp_before = pet.mp
			uses_before = pet.learned_uses
			timer = 0
			step = 4
		4:
			var pet: Pet = pm.active_pet
			timer += 1
			if pet.learned_uses > uses_before:
				check(pet.mp < mp_before, "умение потратило MP: %d → %d" % [mp_before, pet.mp])
				var on_cd := false
				for k in pet.skill_cds:
					if float(pet.skill_cds[k]) > 0.0:
						on_cd = true
				check(on_cd, "умение ушло на перезарядку: %s" % [pet.skill_cds])
				if is_instance_valid(mob) and not mob.is_dead:
					mob.take_damage(mob.hp + 5, player)
				player.global_position = Vector3(0, 0.1, 2)
				step = 5
				return
			if not mob_ok(mob):
				fail("волк погиб раньше, чем питомец применил умение")
				return
			stand_near(mob, 2.0)
			player.last_target = mob
			if timer > 60 * 20:
				fail("питомец не применяет изученные умения")
		5:
			# Переключаемые: MP при включении, бонус хозяину, поддержка, выключение без MP
			var pet: Pet = pm.active_pet
			var rec: Dictionary = game.pets[0]
			pet.level = 45
			pet.refresh_skills()
			check(PetSkills.learn(rec, "shadow_bond"), "изучены «Узы тени»")
			check(PetSkills.learn(rec, "provoke"), "изучен «Дерзкий вызов»")
			pet.refresh_skills()
			pet.mp = pet.max_mp
			var atk0 := pet.atk
			var cost := PetSkills.mp_cost("shadow_bond", 1)
			check(pet.set_toggle("shadow_bond", true) == "", "«Узы тени» включены")
			check(pet.mp == pet.max_mp - cost, "включение стоит %d MP" % cost)
			check(PetSkills.toggle_on(rec, "shadow_bond"), "включение записано в коллекцию")
			check(player.aura_atk > 0.0, "хозяин получил бонус атаки: +%d%%" % roundi(player.aura_atk * 100.0))
			check(pet.atk > atk0, "атака пантеры выросла: %d → %d" % [atk0, pet.atk])
			check(pet.set_toggle("provoke", true) == "" and pet.threat > 0.0, "«Дерзкий вызов»: шанс отвлечь %d%%"
				% roundi(pet.threat * 100.0))
			var m0 := pet.mp
			var up := pet.toggle_upkeep()
			check(up > 0, "поддержка переключаемых: %d MP / 10 с" % up)
			pet._pay_upkeep()
			check(pet.mp == m0 - up, "поддержка списана: %d → %d" % [m0, pet.mp])
			pet.mp = 0
			pet._pay_upkeep()
			check(not PetSkills.toggle_on(rec, "shadow_bond") and not PetSkills.toggle_on(rec, "provoke"),
				"без MP переключаемые выключились")
			check(is_zero_approx(player.aura_atk) and is_zero_approx(pet.threat), "бонусы сняты")
			check(pet.set_toggle("shadow_bond", true) != "", "без MP «Узы тени» не включить")
			pet.mp = pet.max_mp
			check(pet.set_toggle("shadow_bond", true) == "", "«Узы тени» снова включены")
			step = 6
		6:
			# Окно существа: вкладка «Существо»
			main._on_action("creature_window")
			var cw: CreatureWindow = pm.creature
			check(main.hud.is_window_open() and cw.is_open(), "окно существа открыто")
			check(cw.index == 0 and cw.tab == "stats", "окно призванного питомца, вкладка «Существо»")
			var t := _window_text()
			for w in ["Сила", "Выносливость", "Интеллект", "Мудрость", "Удача", "Макс. MP", "Маг. атака",
					"Уклонение", "Очки умений", "Базовый", "Маг", "Форма 1 из 3", "Эволюция у Кирка"]:
				check(t.contains(w), "во вкладке «Существо» есть «%s»" % w)
			for k in ["tab_stats", "tab_active", "tab_aura", "tab_passive", "tab_gear", "tab_skills", "back"]:
				check(cw.buttons.has(k), "кнопка вкладки %s" % k)
			check(cw.buttons.has("pet_0") and cw.buttons.has("pet_3") and not cw.buttons.has("pet_4"),
				"ряд значков всех питомцев героя (4)")
			press_cw("tab_skills")
			check(cw.tab == "active" and cw.is_open(), "прежняя «Умения» — вкладка «Активные»")
			_check_tree(cw)
			t = _window_text()
			check(t.contains("JP"), "во вкладке умений есть очки умений")
			press_cw("skill_dusk_rupture")
			t = _window_text()
			for w in ["Сумрачный разрыв", "активное", "Двойной росчерк"]:
				check(t.contains(w), "карточка «Сумрачного разрыва»: есть «%s»" % w)
			check(not cw.buttons.has("skill_shadow_bond") and not cw.buttons.has("skill_inner_fire"),
				"на вкладке «Активные» нет переключаемых и пассивных")
			press_cw("tab_aura")
			check(cw.tab == "aura" and cw.buttons.has("skill_shadow_bond") and cw.buttons.has("skill_hunter_call")
				and cw.buttons.has("skill_provoke") and not cw.buttons.has("skill_shadow_rend"),
				"вкладка «Ауры и бафы»: узы, вызов, «Зов охотницы»")
			press_cw("skill_shadow_bond")
			check(_window_text().contains("переключаемое"), "карточка «Уз тени»: переключаемое")
			press_cw("tab_passive")
			check(cw.tab == "passive" and cw.buttons.has("skill_inner_fire") and cw.buttons.has("skill_item_expert_panther")
				and cw.buttons.has("skill_bless_str") and not cw.buttons.has("slot_auto_0"),
				"вкладка «Пассивные»: «Знаток снаряжения», «Благословения», без ячеек")
			press_cw("skill_inner_fire")
			check(_window_text().contains("пассивное"), "карточка «Внутреннего огня»: пассивное")
			cw.show_skill("shadow_squall")
			check(cw.tab == "active" and cw.selected == "shadow_squall", "show_skill — вкладка умения и его карточка")
			check(_window_text().contains("стадия 2"), "«Теневой шквал» — со 2-й стадии")
			var locked: Button = cw.buttons.get("learn_shadow_squall")
			check(locked != null and locked.disabled, "умение 2-й стадии недоступно (кнопка «+» выключена)")
			press_cw("skill_shadow_rend")
			var full: Button = cw.buttons.get("learn_shadow_rend")
			check(full != null and full.disabled, "«Двойной росчерк» на пределе стадии")
			var rec: Dictionary = game.pets[0]
			var jp0 := int(rec["jp"])
			press_cw("tab_passive")
			press_cw("skill_calm_mind")
			check(cw.selected == "calm_mind", "касание значка выбрало «Тихий разум»")
			press_cw("learn_calm_mind")
			check(PetSkills.skill_level(rec, "calm_mind") == 1 and int(rec["jp"]) == jp0 - 1, "«+» изучил «Тихий разум»")
			check(cw.is_open() and cw.tab == "passive" and cw.selected == "calm_mind", "окно перестроено на той же вкладке")
			cw.show_skill("shadow_bond")
			check(cw.buttons.has("slot_auto_2") and cw.buttons.has("slot_aura_1"), "в окне 5 ячеек: 3 «Авто» и 2 ауры")
			press_cw("unslot_shadow_bond")
			check(not PetSkills.toggle_on(rec, "shadow_bond") and PetSkills.slot_of(rec, "shadow_bond") < 0,
				"«Убрать» выключил «Узы тени» и освободил ячейку")
			pm.active_pet.mp = pm.active_pet.max_mp
			press_cw("toslot_shadow_bond_0")
			check(PetSkills.toggle_on(rec, "shadow_bond") and PetSkills.slot_of(rec, "shadow_bond") == 0,
				"«В ячейку ауры 1» включил «Узы тени»")
			press_cw("back")
			check(pm.window_buttons.has("info_1"), "из окна существа — назад к питомцам")
			var b: Button = pm.window_buttons["info_1"]
			b.pressed.emit()
			check(cw.is_open() and cw.index == 1, "«Подробнее» открыл окно черепахи (не призвана)")
			check(_window_text().contains("отдыхает"), "черепаха отдыхает")
			press_cw("tab_aura")
			var rt: Dictionary = game.pets[1]
			press_cw("skill_provoke")
			press_cw("learn_provoke")
			check(PetSkills.skill_level(rt, "provoke") == 1, "черепаха выучила «Дерзкий вызов» в окне")
			press_cw("toslot_provoke_1")
			check(PetSkills.toggle_on(rt, "provoke") and PetSkills.slot_of(rt, "provoke") == 1,
				"у не призванного питомца аура в ячейке отмечена включённой")
			press_cw("tab_active")
			check(cw.buttons.has("skill_ram") and not cw.buttons.has("skill_shadow_rend"), "у черепахи свои умения: «Таран»")
			# Ряд питомцев: касание значка — окно переключается на этого питомца, вкладка та же
			press_cw("pet_2")
			check(cw.is_open() and cw.index == 2 and cw.tab == "active" and cw.buttons.has("skill_spark_peck"),
				"значок фазана в ряду — окно фазана на той же вкладке")
			for i in [2, 3]:
				for tb in ["stats", "skills", "aura", "passive", "gear"]:
					check(pm.open_creature(i, tb) and cw.is_open(), "окно существа: питомец %d, вкладка %s" % [i, tb])
			pm.open_creature(3, "active")
			check(cw.buttons.has("skill_fierce_rush") and cw.tree.icons.size() == PetSkills.list_tab("boar", "active").size(),
				"у кабана — «Свирепый натиск» на вкладке «Активные»")
			_check_gear_tab(pm)
			main.hud.close_window()
			wait = 2
			step = 7
		7:
			# Сохранение и загрузка
			check(game.save_game(), "игра сохранена")
			skills_saved = (game.pets[0]["skills"] as Dictionary).duplicate()
			jp_saved = int(game.pets[0]["jp"])
			game.pets[0]["jp"] = 0
			check(game.load_game(), "игра загружена")
			var r: Dictionary = game.pets[0]
			check(int(r["jp"]) == jp_saved, "JP восстановлены: %d" % jp_saved)
			var ok := (r["skills"] as Dictionary).size() == skills_saved.size()
			for k in skills_saved:
				ok = ok and int((r["skills"] as Dictionary).get(k, 0)) == int(skills_saved[k])
			check(ok, "умения восстановлены: %s" % [r["skills"]])
			check(PetSkills.toggle_on(r, "shadow_bond"), "включённые «Узы тени» восстановлены")
			check(PetSkills.toggle_on(game.pets[1], "provoke"), "переключаемое черепахи восстановлено")
			# Старое сохранение без умений и JP
			game.from_dict({
				"name": "Старый", "race": "human", "class": "warrior", "level": 5,
				"pets": [{"species": "panther", "name": "Тень", "level": 20}, {"species": "bear", "level": 3}],
				"active_pet": -1,
			})
			var o: Dictionary = game.pets[0]
			check(int(o["jp"]) == PetStats.default_jp(20), "старому питомцу 20 ур. — %d JP по умолчанию" % int(o["jp"]))
			check((o["skills"] as Dictionary).is_empty() and (o["toggles"] as Dictionary).is_empty(), "умений нет")
			check(String(game.pets[1]["species"]) == "panther", "старый вид переведён")
			check(game.load_game(), "игра загружена снова")
			wait = 3
			step = 8
		8:
			var pet: Pet = pm.active_pet
			check(pet != null and is_same(pet.record, game.pets[0]), "питомец привязан к загруженной записи")
			check(int(pet.skills.get("inner_fire", 0)) == 5, "у призванного питомца загруженные умения")
			check(player.aura_atk > 0.0, "«Узы тени» после загрузки снова дают бонус хозяину")
			check(pet.max_mp > 0 and pet.mp > 0, "MP после загрузки: %d/%d" % [pet.mp, pet.max_mp])
			ok_done()


# ---------- Проверки данных ----------

## Статы растут с уровнем, на эволюции — скачок; обмен статов под роль; калибровка 1 уровня.
func _check_tables() -> void:
	var bad := ""
	for sp in PetData.SPECIES:
		var id := String(sp)
		var prev := PetStats.base_stats(id, 1)
		var prev_d := PetStats.derived(id, 1)
		for lvl in range(2, PetData.MAX_LEVEL + 1):
			var s := PetStats.base_stats(id, lvl)
			var d := PetStats.derived(id, lvl)
			for k in PetStats.STATS:
				if int(s[k]) < int(prev[k]):
					bad += " %s ур.%d %s" % [id, lvl, k]
			if int(d["max_hp"]) <= int(prev_d["max_hp"]) or int(d["atk"]) < int(prev_d["atk"]):
				bad += " %s ур.%d HP/атака" % [id, lvl]
			prev = s
			prev_d = d
		var d1 := PetStats.derived(id, 1)
		check(int(d1["max_hp"]) > 0 and int(d1["atk"]) > 0, "%s: на 1 ур. HP %d, атака %d, защита %d (база оригинала)"
			% [id, int(d1["max_hp"]), int(d1["atk"]), int(d1["def"])])
		for st in [1, 2]:
			var a := _stat_sum(id, 100, st - 1)
			var b := _stat_sum(id, 100, st)
			check(float(b) > float(a) * 1.1, "%s: эволюция в %d-ю форму — скачок статов %d → %d" % [id, st + 1, a, b])
	check(bad == "", "статы и производные не убывают с уровнем" + bad)
	var p1 := PetStats.base_stats("panther", 1)
	check(int(p1["int"]) > int(p1["str"]),
		"пантера-маг: Интеллект (%d) — главный, вместо Силы (%d)" % [int(p1["int"]), int(p1["str"])])
	var f1 := PetStats.base_stats("pheasant", 1)
	check(int(f1["wis"]) > int(f1["dex"]), "фазан-лекарь: Мудрость (%d) вместо Меткости (%d)" % [int(f1["wis"]), int(f1["dex"])])
	var t1 := PetStats.base_stats("turtle", 1)
	check(int(t1["vit"]) > int(t1["str"]), "черепаха-танк: Выносливость (%d) главная" % int(t1["vit"]))
	# База оригинала: 2-я форма пантеры (Pantera Hunter) Сила 69 + 0.334 × ур. (у нас — Интеллект)
	check(int(PetStats.base_stats("panther", 50, 1)["int"]) == 69 + 16, "пантера 2-й формы, ур. 50: Интеллект 85")
	check(int(PetStats.base_stats("turtle", 50, 1)["vit"]) == 69 + 16, "черепаха 2-й формы, ур. 50: Выносливость 85")
	var d := PetStats.derived("panther", 20)
	check(int(d["matk"]) > int(d["patk"]), "у пантеры маг. атака (%d) больше физ. (%d)" % [int(d["matk"]), int(d["patk"])])
	check(int(d["atk"]) == int(d["matk"]), "главная атака пантеры — магическая")
	check(int(PetStats.derived("turtle", 20)["atk"]) == int(PetStats.derived("turtle", 20)["patk"]), "у черепахи — физическая")
	var h := PetStats.derived("pheasant", 20)
	check(int(h["heal"]) > int(h["matk"]), "у фазана сила лечения (%d) от Мудрости" % int(h["heal"]))
	for sp in PetData.SPECIES:
		for lvl in [1, 15, 30, 50]:
			var x := PetStats.derived(String(sp), lvl)
			var ok := float(x["crit"]) >= 2.0 and float(x["crit"]) <= 15.0 and float(x["eva"]) >= 0.0 \
				and float(x["eva"]) <= 20.0 and int(x["aspd"]) >= 100 and int(x["aspd"]) <= 130 \
				and int(x["max_mp"]) > 0 and float(x["hp_regen"]) > 0.0 and float(x["mp_regen"]) > 0.0 \
				and int(x["acc"]) > 0 and float(x["cd"]) > 0.5
			check(ok, "%s ур.%d: показатели в разумных пределах (крит %.1f%%, уклон %.1f%%, скорость %d%%, MP %d)"
				% [sp, lvl, float(x["crit"]), float(x["eva"]), int(x["aspd"]), int(x["max_mp"])])
	check(is_equal_approx(Combat.hit_chance(10.0, 10.0, 1, 1), 0.95), "точность: 95% по зверю своего уровня")
	check(Combat.hit_chance(5.0, 40.0, 1, 10) < 0.4 and Combat.hit_chance(200.0, 1.0, 10, 1) <= Combat.HIT_MAX,
		"шанс попасть: по зверю выше — редко, не больше 99%")
	var pd := PetStats.derived("wolf", 10)
	check(int(pd["avoid"]) > 0 and int(pd["acc"]) > 0, "у питомца точность и избегание (%d / %d)" % [int(pd["acc"]), int(pd["avoid"])])


func _stat_sum(id: String, lvl: int, stage: int = 0) -> int:
	var s := PetStats.base_stats(id, lvl, stage)
	var t := 0
	for k in PetStats.STATS:
		t += int(s[k])
	return t


## Питомец своего уровня против зверей мира своего уровня (Combat.power_ratio — HP × урон в секунду зверя / то же
## у питомца, без умений): пока только печать — статы питомцев переводятся на базу оригинала отдельным шагом.
func _check_balance() -> void:
	for sp in TAMEABLE:
		var id := String(sp)
		var lo := 99.0
		var hi := 0.0
		var lo_new := 99.0
		var hi_new := 0.0
		var row := ""
		for lvl in range(1, 31):
			var pp := PetStats.combat_profile(id, lvl)
			var sum := 0.0
			for mid in BASIC:
				var m := Mob.new()
				m.setup(String(mid), -1, Vector3.ZERO, lvl)
				sum += Combat.power_ratio(pp, Combat.profile_of(m))
				m.free()
			var r := sum / float(BASIC.size())
			if lvl < 10:
				lo_new = minf(lo_new, r)
				hi_new = maxf(hi_new, r)
			else:
				lo = minf(lo, r)
				hi = maxf(hi, r)
			if [1, 5, 10, 14, 15, 20, 29, 30].has(lvl):
				row += " %d:%.2f" % [lvl, r]
		check(lo > 0.0 and hi < 1000.0 and lo_new > 0.0, "%s: сила зверей своего уровня считается (1–9 ур. %.2f–%.2f, 10–30 ур. %.2f–%.2f)"
			% [id, lo_new, hi_new, lo, hi])
		print("  %s, сила зверя своего уровня:%s" % [id, row])
		var d10 := PetStats.derived(id, 10)
		print("  %s ур.10: HP %d, атака %d, защита %d, MP %d" % [id, int(d10["max_hp"]), int(d10["atk"]),
			int(d10["def"]), int(d10["max_mp"])])


## Данные умений: у каждого вида есть умения, у активных — MP и перезарядка; уровни вики → наши; бюджет JP.
func _check_skill_data() -> void:
	check(PetSkills.req_level(1) == 1 and PetSkills.req_level(10) == 10 and PetSkills.req_level(50) == 50
		and PetSkills.req_level(150) == 150, "уровни вики → наши 1:1")
	var bad := ""
	for sp in PetData.SPECIES:
		var ids := PetSkills.list_for(String(sp))
		var need := 15 if BASIC.has(sp) else 4
		if ids.size() < need:
			bad += " %s: мало умений" % sp
		var active := false
		for id in ids:
			var sk := PetSkills.get_skill(String(id))
			if sk.is_empty() or String(sk.get("name", "")) == "" or String(sk.get("desc", "")) == "":
				bad += " %s: нет данных" % id
				continue
			if (sk["tiers"] as Array).size() != 3 or PetSkills.max_level(String(id)) <= 0:
				bad += " %s: уровни" % id
			var kind := String(sk["kind"])
			if kind == "active":
				active = true
				if not sk.has("cd") or PetSkills.mp_cost(String(id), 1) <= 0:
					bad += " %s: MP/перезарядка" % id
			elif kind == "toggle":
				if PetSkills.upkeep(String(id), 1) <= 0 or not sk.has("bonus"):
					bad += " %s: поддержка" % id
			elif kind == "manual":
				if not sk.has("creates") or PetSkills.mp_cost(String(id), 1) <= 0:
					bad += " %s: создание" % id
			elif not sk.has("bonus"):
				bad += " %s: бонус" % id
			if PetSkills.effect_text(String(id), 1) == "" or PetSkills.requirement_text(String(id), 1) == "":
				bad += " %s: тексты" % id
		if not active:
			bad += " %s: нет активного" % sp
	check(bad == "", "данные умений в порядке" + bad)
	for sp in BASIC:
		var cost := 0
		# Прежние 18 умений вида (новые из базы — снаряжение, пояс, благословения — сверху, с 40–51 ур.)
		for id in PetSkills.SPECIES_SKILLS[sp]:
			var sk := PetSkills.get_skill(String(id))
			cost += int(sk["tiers"][0][1]) * int(sk["jp"])
		var have := PetStats.default_jp(15)
		check(float(have) >= float(cost) * 0.35 and float(have) <= float(cost) * 0.65,
			"%s: к 15 ур. %d JP — примерно половина умений 1-й стадии (%d JP)" % [sp, have, cost])
	check(PetSkills.effect_text("shadow_rend", 1).contains("2 × 60%"), "«Двойной росчерк»: 2 удара по 60%: "
		+ PetSkills.effect_text("shadow_rend", 1))
	check(PetSkills.effect_text("shadow_rend", 15).contains("200%"), "на 15 ур. — по 200%")
	check(PetSkills.mp_cost("shadow_rend", 1) == 54, "MP 1:1 с вики (запас MP как в оригинале): 54")


## Древо умений пантеры по вкладкам (крупный режим SkillTree): значок на каждое умение вкладки, значки крупные
## (было ≈ 46 px в одном древе на 32 умения), сверху вниз по уровню, пререквизиты выше, значки из
## assets/icons/pets/<вид>/<id>.png или кружок с буквой, подсветка доступных.
func _check_tree(cw: CreatureWindow) -> void:
	var tr := cw.tree
	check(tr != null and is_instance_valid(tr), "древо умений построено")
	if tr == null:
		return
	check(tr.big, "древо — в крупном режиме")
	var ids := PetSkills.list_tab("panther", "active")
	check(tr.icons.size() == ids.size(), "древо «Активные»: значок на каждое умение (%d)" % tr.icons.size())
	check(tr.icon_size >= UiScale.px(70.0), "значки крупные: %.0f px (было ≈ 46)" % tr.icon_size)
	check(tr.row_of("shadow_rend") < tr.row_of("dusk_rupture") and tr.row_of("shadow_squall") < tr.row_of("midnight_vortex"),
		"пререквизит выше умения")
	check(tr.icon_center("dusk_rupture").y > tr.icon_center("shadow_rend").y, "линия пререквизита идёт сверху вниз")
	_check_inside(tr, "«Активные»")
	check(CreatureWindow.icon_path("panther", "inner_fire") == "res://assets/icons/pets/panther/inner_fire.png",
		"значок питомца: assets/icons/pets/<вид>/<id>.png")
	var b0: Button = tr.icons["shadow_rend"]
	var tex := SkillTree.load_icon(CreatureWindow.icon_path("panther", "shadow_rend"))
	if tex != null:
		check(not b0.find_children("*", "TextureRect", false, false).is_empty(), "значок из файла показан")
	else:
		check(not b0.find_children("*", "Label", false, false).is_empty(), "файла значка нет — кружок с буквой")
	# Все вкладки: все умения вида разложены, у каждой — крупные значки внутри древа
	var total := 0
	var rec: Dictionary = game.pets[0]
	var lit := 0
	var dim := 0
	for t in PetSkills.TABS:
		var key := String(t[0])
		cw.open(0, key)
		var tt := cw.tree
		total += tt.icons.size()
		check(tt.icons.size() == PetSkills.list_tab("panther", key).size(), "вкладка %s: %d значков" % [key, tt.icons.size()])
		check(tt.icon_size >= UiScale.px(60.0), "вкладка %s: значки %.0f px (не мельче 60)" % [key, tt.icon_size])
		print("  вкладка %s: %d умений, значки %.0f px, ярусов %d, строк %d" % [key, tt.icons.size(), tt.icon_size,
			tt.rows.size(), tt.lines.size()])
		_check_inside(tt, key)
		var prev_y := -1.0
		var order_ok := true
		for ln in tt.lines:
			var y := tt.icon_center(String((ln["ids"] as Array)[0])).y if not (ln["ids"] as Array).is_empty() else prev_y
			order_ok = order_ok and y >= prev_y
			prev_y = y
		check(order_ok, "вкладка %s: строки сверху вниз" % key)
		# Доступные к изучению подсвечены (тень у рамки), недоступные — затемнены
		for id in tt.icons:
			var b: Button = tt.icons[id]
			var sb := b.get_theme_stylebox("normal") as StyleBoxFlat
			var can := PetSkills.learn_block(rec, String(id)) == ""
			if can and sb != null and sb.shadow_size > 0:
				lit += 1
			if PetSkills.skill_level(rec, String(id)) == 0 and not can and b.modulate.r < 0.9:
				dim += 1
	check(total == PetSkills.list_for("panther").size(), "во вкладках — все %d умений пантеры" % total)
	check(lit > 0, "доступные к изучению подсвечены: %d" % lit)
	check(dim > 0, "недоступные затемнены: %d" % dim)
	cw.open(0, "active")


func _check_inside(tr: SkillTree, what: String) -> void:
	var inside := true
	for id in tr.icons:
		var b: Button = tr.icons[id]
		if b.position.x < 0.0 or b.position.y < 0.0 or b.position.x + b.size.x > tr.size.x + 1.0 \
				or b.position.y + b.size.y > tr.size.y + 1.0:
			inside = false
	check(inside, "%s: все значки внутри древа %s" % [what, tr.size])


## Вкладка «Оружие и доспехи» (фазан, не призван): ячейки питомца, в сетке — только оружие (не щит) и доспехи на
## тело, свободные; карточка — что получит питомец и почему нельзя; «Надеть питомцу» тратит карту снаряжения,
## перетаскивание значка на ячейку — тоже надевает; надетая — «Снять» (мел).
func _check_gear_tab(pm: PetManager) -> void:
	var cw: CreatureWindow = pm.creature
	var rec: Dictionary = game.pets[2]
	rec["level"] = 30
	rec["skills"].erase("item_expert_pheasant")
	game.inventory.add("weapon_dagger_r1")
	game.inventory.add("armor_body_hunter_r1")
	game.inventory.add("weapon_shield_r1")
	game.inventory.add("armor_helmet_r1")
	game.inventory.add("potion_hp_r1", 2)
	check(pm.open_creature(2, "gear") and cw.tab == "gear", "вкладка «Оружие и доспехи»")
	check(cw.buttons.has("gear_slot_weapon") and cw.buttons.has("gear_slot_armor"), "ячейки питомца «Оружие» и «Броня»")
	check(cw.buttons.has("gear_item_weapon_dagger_r1") and cw.buttons.has("gear_item_armor_body_hunter_r1"),
		"в сетке — кинжал и охотничий доспех")
	check(not cw.buttons.has("gear_item_weapon_shield_r1") and not cw.buttons.has("gear_item_armor_helmet_r1")
		and not cw.buttons.has("gear_item_potion_hp_r1"), "щита, шлема и зелий в сетке нет")
	if game.weapon != "":
		check(Enchant.free_count(game.weapon) > 0 or not cw.buttons.has("gear_item_" + game.weapon),
			"надетое героем оружие (без свободной штуки) — не в сетке")
	check(_window_text().contains("Карт снаряжения:"), "строка: сколько карт снаряжения и мела")
	press_cw("gear_item_weapon_dagger_r1")
	check(cw.gear_sel == "weapon_dagger_r1" and cw.buttons.has("gear_equip"), "карточка кинжала с «Надеть питомцу»")
	check((cw.buttons["gear_equip"] as Button).disabled and _window_text().contains("Знаток"),
		"без «Знатока снаряжения» надеть нельзя — причина в карточке")
	rec["skills"]["item_expert_pheasant"] = 1
	game.inventory.add(PetGear.UNIT_CARD, 2)
	game.inventory.add(PetGear.CHALK, 1)
	cw.refresh()
	var t := _window_text()
	check(t.contains("Питомцу (80%") and t.contains("физ. атака +"), "карточка: что получит питомец (80 %%)")
	check(t.contains("Боец"), "карточка: «Боец: кинжал» для кинжала")
	var cards0: int = game.inventory.count(PetGear.UNIT_CARD)
	press_cw("gear_equip")
	check(PetGear.gear_in(rec, "weapon") == "weapon_dagger_r1" and game.inventory.count(PetGear.UNIT_CARD) == cards0 - 1,
		"«Надеть питомцу»: кинжал на питомце, карта снаряжения потрачена")
	check(cw.gear_sel == "slot:weapon" and cw.buttons.has("gear_off_weapon"), "после надевания — карточка ячейки со «Снять»")
	# Перетаскивание доспеха в ячейку «Броня»
	var item_cell = cw.buttons["gear_item_armor_body_hunter_r1"]
	var data: Variant = item_cell._get_drag_data(Vector2.ZERO)
	var slot_w = cw.buttons["gear_slot_weapon"]
	var slot_a = cw.buttons["gear_slot_armor"]
	check(data is Dictionary and not slot_w._can_drop_data(Vector2.ZERO, data) and slot_a._can_drop_data(Vector2.ZERO, data),
		"доспех можно бросить только в ячейку «Броня»")
	slot_a._drop_data(Vector2.ZERO, data)
	check(PetGear.gear_in(rec, "armor") == "armor_body_hunter_r1", "перетаскивание надело доспех")
	press_cw("gear_slot_weapon")
	press_cw("gear_off_weapon")
	check(PetGear.gear_in(rec, "weapon") == "" and game.inventory.has("weapon_dagger_r1")
		and game.inventory.count(PetGear.CHALK) == 0, "«Снять (мел)»: кинжал в сумке, мел потрачен")
	press_cw("gear_slot_armor")
	check((cw.buttons["gear_off_armor"] as Button).disabled, "без мела снять нельзя")
	# Окно «Питомцы»: ряд значков, касание — окно существа; блока «Пояс» больше нет (пояс — в сумке)
	main._on_action("pets_window")
	check(pm.window_buttons.has("pet_0") and pm.window_buttons.has("pet_3"), "окно «Питомцы»: ряд значков питомцев")
	check(not pm.window_buttons.has("belt_expand") and not pm.window_buttons.has("belt_0")
		and not _window_text().contains("Пояс: ячеек"), "в окне «Питомцы» нет блока «Пояс»")
	(pm.window_buttons["pet_1"] as Button).pressed.emit()
	check(cw.is_open() and cw.index == 1, "касание значка в окне «Питомцы» открыло окно существа")


## Умения «по формам» (база: Item Expert, Vital Unit, Fighter Unit, Card Ability): ровно 3 уровня, по одному на форму;
## числа по уровням — ранги «<Stage N>» базы от ранга вида; требования; старые записи — не выше формы, JP возвращаются.
func _check_form_levels() -> void:
	var bad := ""
	for sp in PetSkills.DB_EXTRAS:
		for pre in ["item_expert_%s", "vital_unit_%s", "fighter_unit_%s", "card_%s_1", "card_%s_2"]:
			var id := String(pre) % sp
			if PetSkills.max_level(id) != 3 or PetSkills.form_cap(id, 0) != 1 or PetSkills.form_cap(id, 1) != 2 \
					or PetSkills.form_cap(id, 2) != 3 or not bool(PetSkills.get_skill(id).get("per_form", false)):
				bad += " " + id
			for n in [1, 2, 3]:
				if PetSkills.tier_for(id, n) != n - 1 or PetSkills.value(PetSkills.get_skill(id)["value"], n) < \
						PetSkills.value(PetSkills.get_skill(id)["value"], maxi(1, n - 1)):
					bad += " %s ур.%d" % [id, n]
	check(bad == "", "умения «по формам»: 3 уровня, 1-я форма — до 1, 2-я — до 2, 3-я — до 3; сила не убывает" + bad)
	var expect := {
		"item_expert_panther": [0.8, 0.9, 0.95], "item_expert_turtle": [0.8, 0.9, 0.95],
		"item_expert_pheasant": [0.8, 0.9, 0.95], "item_expert_wolf": [0.9, 0.95, 1.0], "item_expert_centaur": [1.0, 1.0, 1.0],
		"vital_unit_panther": [0.05, 0.10, 0.12], "vital_unit_wolf": [0.10, 0.12, 0.14], "vital_unit_centaur": [0.14, 0.16, 0.18],
		"fighter_unit_turtle": [0.05, 0.10, 0.12], "fighter_unit_pheasant": [5.0, 10.0, 12.0],
		"fighter_unit_wolf": [0.10, 0.12, 0.14], "fighter_unit_centaur": [0.14, 0.16, 0.18],
		"card_panther_1": [0.05, 0.10, 0.12], "card_pheasant_2": [0.05, 0.10, 0.12], "card_wolf_1": [0.10, 0.12, 0.14],
		"card_wolf_2": [0.10, 0.12, 0.14], "card_centaur_1": [0.14, 0.16, 0.18], "card_centaur_2": [0.14, 0.16, 0.18],
	}
	for id in expect:
		var got: Array = []
		for n in [1, 2, 3]:
			got.append(snappedf(PetSkills.value(PetSkills.get_skill(String(id))["value"], n), 0.001))
		var want: Array = expect[id]
		var ok := true
		for n in 3:
			ok = ok and is_equal_approx(float(got[n]), float(want[n]))
		check(ok, "%s по уровням: %s (база: %s)" % [id, got, want])
	check(PetSkills.level_needed("item_expert_wolf", 1) == 1 and PetSkills.level_needed("item_expert_wolf", 2) == 50
		and PetSkills.level_needed("item_expert_wolf", 3) == 100, "«Знаток снаряжения»: с 1 ур., 2-й — с 50 (2-я форма), 3-й — со 100")
	check(PetSkills.level_needed("vital_unit_panther", 1) == 40 and PetSkills.level_needed("card_panther_1", 2) == 50,
		"«Живучесть» и 1-я карта: с 40 ур., 2-й уровень — с 50")
	check(PetSkills.level_needed("fighter_unit_panther", 1) == 90 and PetSkills.level_needed("card_panther_2", 2) == 90
		and PetSkills.level_needed("card_panther_2", 3) == 100, "«Боец» и 2-я карта: с 90 ур., 3-й уровень — со 100")
	check(PetSkills.effect_text("item_expert_panther", 3).contains("95%"), "текст 3-го уровня «Знатока»: "
		+ PetSkills.effect_text("item_expert_panther", 3))
	check(PetSkills.effect_text("card_wolf_1", 2).contains("12%"), "текст 2-го уровня карты волка: " + PetSkills.effect_text("card_wolf_1", 2))
	check(PetSkills.effect_text("fighter_unit_pheasant", 3).contains("крит +12"), "«Боец: кинжал» 3-го уровня — крит +12")
	# Изучение: на 1-й форме — только 1-й уровень, на 2-й — 2-й, на 3-й — 3-й
	var r := {"species": "pheasant", "name": "Ф", "level": 100, "skills": {}, "toggles": {}, "stage": 0, "jp": 20}
	PetSkills.ensure_record(r)
	check(PetSkills.learn(r, "item_expert_pheasant"), "1-я форма: «Знаток снаряжения» ур. 1")
	check(PetSkills.learn_block(r, "item_expert_pheasant").contains("стадия 2"), "1-я форма: 2-й уровень — со 2-й формы: "
		+ PetSkills.learn_block(r, "item_expert_pheasant"))
	r["stage"] = 1
	check(PetSkills.learn(r, "item_expert_pheasant") and PetSkills.learn_block(r, "item_expert_pheasant").contains("стадия 3"),
		"2-я форма: ур. 2, 3-й — с 3-й формы")
	r["stage"] = 2
	check(PetSkills.learn(r, "item_expert_pheasant") and PetSkills.learn_block(r, "item_expert_pheasant") == "Изучено полностью",
		"3-я форма: ур. 3 — полностью")
	check(is_equal_approx(PetGear.expert(r), 0.95), "фазан 3-го уровня «Знатока» — 95 %% снаряжения")
	var bw := {"species": "wolf", "level": 100, "stage": 2, "skills": {"card_wolf_1": 2, "card_wolf_2": 3}}
	var ab := PetBelt.abilities(bw)
	check(ab.size() == 2 and is_equal_approx(float(ab[0][1]), 0.12) and is_equal_approx(float(ab[1][1]), 0.14),
		"пояс: карты волка 2-го и 3-го уровня — 12 %% и 14 %% (%s)" % [ab])
	# Перенос: уровень выше формы снимается, JP возвращаются (1 JP за уровень)
	var old := {"species": "panther", "name": "Тень", "level": 120, "stage": 0, "jp": 0,
		"skills": {"item_expert_panther": 3, "card_panther_1": 2, "vital_unit_panther": 1, "inner_fire": 9}, "toggles": {}}
	PetSkills.ensure_record(old)
	check(int(old["skills"]["item_expert_panther"]) == 1 and int(old["skills"]["card_panther_1"]) == 1
		and int(old["skills"]["vital_unit_panther"]) == 1 and int(old["jp"]) == 3,
		"старая запись 1-й формы: «по формам» — до 1 ур., 3 JP возвращены (%s, JP %d)" % [old["skills"], int(old["jp"])])
	check(int(old["skills"]["inner_fire"]) == 9, "прочие умения выше формы не трогаются (возврат в 1-ю форму — как раньше)")
	var keep := {"species": "panther", "level": 120, "stage": 2, "jp": 0, "skills": {"item_expert_panther": 3}, "toggles": {}}
	PetSkills.ensure_record(keep)
	check(int(keep["skills"]["item_expert_panther"]) == 3 and int(keep["jp"]) == 0, "3-я форма: 3-й уровень остаётся")


# ---------- Помощники ----------

## Весь текст открытого окна.
func _window_text() -> String:
	var t := ""
	var w: Control = main.hud._window
	if w != null and is_instance_valid(w):
		for n in w.find_children("*", "Label", true, false):
			t += (n as Label).text + "\n"
	return t


## Нажимает кнопку окна существа.
func press_cw(key: String) -> void:
	var cw: CreatureWindow = main.pets.creature
	var b: Button = cw.buttons.get(key)
	check(b != null and is_instance_valid(b), "кнопка «%s» в окне существа" % key)
	if b != null:
		b.pressed.emit()


## Древо волка по базе оригинала (Wolf Pup → Warg → Fenrir): 18 умений, как у других видов; своё — по SkillResource.
## Прежде у волка было 4 умения на всех стадиях (жалоба Максима).
func _check_wolf() -> void:
	var ids: Array = PetSkills.list_for("wolf")
	check(ids.size() == 18 + 14, "у волка 18 умений древа и 14 новых из базы (%d)" % ids.size())
	for id in ids:
		check(not PetSkills.get_skill(String(id)).is_empty(), "умение волка «%s» описано" % id)
	for id in ["rending_bite", "chilling_howl", "lunging_bite", "pack_bond", "alpha_call", "fang_flurry", "moon_frenzy",
			"feather_step"]:
		check(ids.has(id), "у волка есть «%s»" % PetSkills.get_skill(String(id)).get("name", id))
	var by_stage := [0, 0, 0]
	for st in 3:
		for id in ids:
			if PetSkills.cap_for(String(id), 150, st) > 0:
				by_stage[st] += 1
	check(by_stage[0] >= 13 and by_stage[2] == ids.size(), "волк: умений на стадиях %s (на 3-й все)" % str(by_stage))
	_check_db_extras()
	# Страх «Леденящего воя» и уклонение «Уз стаи» хозяину
	var sk := PetSkills.get_skill("chilling_howl")
	check(sk.has("fear") and PetSkills.value(sk["fear"], 15) > 4.9, "«Леденящий вой»: страх до 5 с (%.1f)" % PetSkills.value(sk["fear"], 15))
	var b := PetSkills.bonuses("wolf", {"pack_bond": 5}, {"pack_bond": true}, true)
	check(float(b.get("eva", 0.0)) > 0.0, "«Узы стаи» дают уклонение хозяину (%.1f %%)" % float(b.get("eva", 0.0)))
	var p: Player = main.player
	var e0 := p.cur_eva()
	p.set_pet_aura(null, 0.0, 0, 0.0, 0.04)
	var e1 := p.cur_eva()
	p.set_pet_aura(null, 0.0, 0, 0.0)
	check(e1 > e0, "уклонение героя от уз питомца растёт (%.2f → %.2f)" % [e0, e1])


## Умения существ из базы (0.31): снаряжение (PetGear), пояс (PetBelt), «Зализать раны», «Создание», «Благословения».
func _check_db_extras() -> void:
	for sp in PetSkills.DB_EXTRAS:
		var ids: Array = PetSkills.list_for(String(sp))
		for id in ["item_expert_", "vital_unit_", "fighter_unit_", "card_%s_1", "card_%s_2", "wound_lick_", "creation_",
				"creation_potion_"]:
			var sid := (String(id) % sp) if String(id).contains("%s") else String(id) + String(sp)
			check(ids.has(sid) and not PetSkills.get_skill(sid).is_empty(), "%s: есть «%s»" % [sp, sid])
		for st in PetSkills.BLESS_STATS:
			check(ids.has("bless_" + String(st)), "%s: «Благословение» %s" % [sp, st])
	_check_form_levels()
	# Снаряжение: волк 90 %, кентавр 100 %; «Знаток» не изучен — надеть нельзя
	var rec := {"species": "wolf", "level": 40, "skills": {}, "toggles": {}, "stage": 0}
	PetSkills.ensure_record(rec)
	check(PetGear.equip_block(rec, "weapon_sword_1h_r1") != "", "без «Знатока снаряжения» питомцу не надеть")
	rec["skills"]["item_expert_wolf"] = 1
	check(is_equal_approx(PetGear.expert(rec), 0.9), "волк получает 90 %% характеристик снаряжения")
	var r0 := PetData.stats_of(rec)
	rec["gear"] = {"weapon": "weapon_sword_1h_r1+2", "armor": "armor_body_hunter_r1"}
	var r1 := PetData.stats_of(rec)
	var want := roundi(27.0 * 0.9) + (ItemData.enchant_value(27, 2) - 27)
	check(int(r1["patk"]) - int(r0["patk"]) == want, "меч +2: атака волка +%d (ожидалось %d)" % [int(r1["patk"]) - int(r0["patk"]), want])
	check(int(r1["def"]) > int(r0["def"]) and int(r1["max_hp"]) == int(r0["max_hp"]), "доспех: защита выше, HP без «Живучести» тот же")
	rec["skills"]["vital_unit_wolf"] = 1
	var r2 := PetData.stats_of(rec)
	check(int(r2["max_hp"]) > int(r1["max_hp"]), "«Живучесть: доспех охотника» с охотничьим доспехом — HP выше (%d → %d)" % [int(r1["max_hp"]), int(r2["max_hp"])])
	# Пояс: карта волка — Ловкость героя +10 %
	var saved_pets: Array = Game.pets.duplicate()
	var saved_equip: Dictionary = Game.equip.duplicate()
	var saved_active := Game.active_pet
	Game.pets.clear()
	var wolf := {"species": "wolf", "name": "Тест", "level": 40, "skills": {"card_wolf_1": 1}, "toggles": {}, "stage": 0}
	Game.pets.append(wolf)
	check(PetBelt.put(0, 0) == "", "волк со «Способностью карты» — в пояс")
	check(PetBelt.hero_bonus(Game.class_id, Game.level).is_empty() or PetBelt.belt_worn(), "без пояса бонусов нет")
	Game.inventory.add("belt_light_r1")
	Game.equip["belt"] = "belt_light_r1"
	Game._sync_worn()
	var hb := PetBelt.hero_bonus(Game.class_id, Game.level)
	var agi := float(HeroStats.base_stats(Game.class_id, Game.level).get("agi", 0))
	check(is_equal_approx(float(hb.get("agi", 0.0)), roundf(agi * 0.10)), "карта волка: Ловкость героя +10 %% (%s, база %.0f)" % [hb, agi])
	check(PetBelt.put_block(0, 3).contains("закрыта") or PetBelt.put_block(0, 3).contains("форм"), "ячейка 4 — закрыта или для 3-й формы")
	Game.pets.clear()
	for p in saved_pets:
		Game.pets.append(p)
	Game.equip = saved_equip
	Game.active_pet = saved_active
	Game._sync_worn()
