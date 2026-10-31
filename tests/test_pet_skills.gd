extends "res://tests/test_base.gd"
## Характеристики и умения питомцев (PetStats, PetSkills) и окно существа (CreatureWindow):
## статы по уровням и стадиям (рост, скачок на эволюции, обмен статов под роль), баланс против прежних формул,
## данные умений и бюджет JP, изучение (уровень, стадия, пререквизит, JP), пассивки меняют характеристики,
## JP за опыт, активные умения в бою (MP, перезарядка, урон, оглушение, замедление, морок), переключаемые
## (MP при включении и поддержка, бонус хозяину, выключение без MP), окно существа (обе вкладки, древо умений
## SkillTree: ярусы, пререквизиты, значки, карточка с кнопками), сохранение и загрузка умений, старые сохранения.

## Прежние формулы PetData (до системы статов): [HP, HP за ур., атака, атака за ур.] и множители стадий.
const OLD := {
	"boar": [60, 11.0, 8, 2.0], "wolf": [55, 10.0, 9, 2.2], "panther": [52, 9.0, 9, 2.3],
	"pheasant": [45, 8.0, 4, 1.0], "turtle": [115, 21.0, 5, 1.2], "golem": [150, 26.0, 9, 1.8],
}
const OLD_BONUS := [1.0, 1.15, 1.35]
const BASIC := ["panther", "turtle", "pheasant"]

var mob: Mob = null
var timer := 0
var mp_before := 0
var uses_before := 0
var jp_saved := 0
var skills_saved: Dictionary = {}


func before_start() -> void:
	game.add_pet("panther", PetData.stage_name("panther", 1), 1)
	game.add_pet("turtle", PetData.stage_name("turtle", 20), 20)
	game.add_pet("pheasant", PetData.stage_name("pheasant", 10), 10)
	game.add_pet("boar", PetData.stage_name("boar", 5), 5)
	game.active_pet = 0


func run_step() -> void:
	var player: Player = main.player
	var pm: PetManager = main.pets
	match step:
		0:
			_check_tables()
			_check_balance()
			_check_skill_data()
			step = 1
		1:
			# Изучение умений: уровень, JP, пререквизит, стадия
			var pet: Pet = pm.active_pet
			check(pet != null and pet.species == "panther", "призвана пантера")
			check(pet.max_mp > 0 and pet.mp == pet.max_mp, "у питомца есть MP: %d" % pet.max_mp)
			check(main.hud._pet_mp_bar.visible, "полоска MP питомца в HUD")
			var rec: Dictionary = game.pets[0]
			check(int(rec["jp"]) == PetSkills.JP_START, "у нового питомца %d JP" % PetSkills.JP_START)
			check(PetSkills.learn_block(rec, "shadow_rend").contains("ур. 3"), "«Двойной росчерк» — с 3 уровня: "
				+ PetSkills.learn_block(rec, "shadow_rend"))
			check(PetSkills.learn(rec, "inner_fire"), "изучен «Внутренний огонь» (ур. 1)")
			check(int(rec["jp"]) == PetSkills.JP_START - 1, "списан 1 JP")
			pet.level = 12
			pet.refresh_skills()
			check(int(rec["level"]) == 12 and pet.stage == 0, "пантера 12 уровня, 1-я стадия")
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
			check(PetSkills.cap_for("shadow_rend", 12) == 5 and PetSkills.cap_for("shadow_rend", 18) == 10,
				"на 1-й стадии — до 5 ур., на 2-й (с 18 ур.) — до 10")
			check(PetSkills.learn(rec, "dusk_rupture"), "после «Двойного росчерка» изучен «Сумрачный разрыв»")
			check(PetSkills.learn(rec, "shadow_fang") and PetSkills.learn(rec, "daze"), "изучены «Клык полуночи» и «Морок»")
			check(int(rec["jp"]) == 60 - 5 - 1 - 2 - 2, "JP списаны верно: %d" % int(rec["jp"]))
			check(PetSkills.learn_block(rec, "shadow_bond").contains("ур. 14"), "«Узы тени» — с 14 уровня")
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
			check(pet.level == 13, "питомец получил уровень")
			check(int(rec["jp"]) == jp0 + PetSkills.JP_PER_LEVEL, "за уровень опыта +%d JP: %d → %d"
				% [PetSkills.JP_PER_LEVEL, jp0, int(rec["jp"])])
			var jp1 := int(rec["jp"])
			pet.gain_xp(maxi(1, int(float(PetData.xp_to_next(pet.level)) / 3.0)))
			check(int(rec["jp"]) + float(rec["jp_part"]) > float(jp1) + 0.9, "JP копятся и по долям за каждое убийство")
			step = 3
		3:
			# Эффекты умений напрямую: урон, оглушение и угроза, замедление, морок
			var pet: Pet = pm.active_pet
			# Зверь уровня питомца (по зверю намного выше уровнем умения мажут — Combat.skill_hit_chance)
			var gp: Vector3 = player.global_position + Vector3(4.0, 0.0, 0.0)
			var g: Mob = main.spawn_mob("anathema", pet.level, IslandWorld.current.ground(gp.x, gp.z))
			check(g != null and g.level == pet.level and g.slot == -1, "поставлена анатема %d ур. (main.spawn_mob)" % pet.level)
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
			pet.level = 14
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
					"Уклонение", "Очки умений", "Базовый", "Маг", "Стадия эволюции"]:
				check(t.contains(w), "во вкладке «Существо» есть «%s»" % w)
			check(cw.buttons.has("tab_stats") and cw.buttons.has("tab_skills") and cw.buttons.has("back"), "кнопки вкладок")
			press_cw("tab_skills")
			check(cw.tab == "skills" and cw.is_open(), "вкладка «Умения»")
			_check_tree(cw)
			t = _window_text()
			check(t.contains("JP"), "во вкладке «Умения» есть очки умений")
			press_cw("skill_dusk_rupture")
			t = _window_text()
			for w in ["Сумрачный разрыв", "активное", "Двойной росчерк"]:
				check(t.contains(w), "карточка «Сумрачного разрыва»: есть «%s»" % w)
			press_cw("skill_shadow_bond")
			check(_window_text().contains("переключаемое"), "карточка «Уз тени»: переключаемое")
			press_cw("skill_inner_fire")
			check(_window_text().contains("пассивное"), "карточка «Внутреннего огня»: пассивное")
			press_cw("skill_shadow_squall")
			check(_window_text().contains("стадия 2"), "«Теневой шквал» — со 2-й стадии")
			var locked: Button = cw.buttons.get("learn_shadow_squall")
			check(locked != null and locked.disabled, "умение 2-й стадии недоступно (кнопка «+» выключена)")
			press_cw("skill_shadow_rend")
			var full: Button = cw.buttons.get("learn_shadow_rend")
			check(full != null and full.disabled, "«Двойной росчерк» на пределе стадии")
			var rec: Dictionary = game.pets[0]
			var jp0 := int(rec["jp"])
			press_cw("skill_calm_mind")
			check(cw.selected == "calm_mind", "касание значка выбрало «Тихий разум»")
			press_cw("learn_calm_mind")
			check(PetSkills.skill_level(rec, "calm_mind") == 1 and int(rec["jp"]) == jp0 - 1, "«+» изучил «Тихий разум»")
			check(cw.is_open() and cw.tab == "skills" and cw.selected == "calm_mind", "окно перестроено на той же вкладке")
			press_cw("skill_shadow_bond")
			press_cw("toggle_shadow_bond")
			check(not PetSkills.toggle_on(rec, "shadow_bond"), "кнопка «Выкл» выключила «Узы тени»")
			press_cw("toggle_shadow_bond")
			check(PetSkills.toggle_on(rec, "shadow_bond"), "кнопка «Вкл» включила «Узы тени»")
			press_cw("back")
			check(pm.window_buttons.has("info_1"), "из окна существа — назад к питомцам")
			var b: Button = pm.window_buttons["info_1"]
			b.pressed.emit()
			check(cw.is_open() and cw.index == 1, "«Подробнее» открыл окно черепахи (не призвана)")
			check(_window_text().contains("отдыхает"), "черепаха отдыхает")
			press_cw("tab_skills")
			var rt: Dictionary = game.pets[1]
			press_cw("skill_provoke")
			press_cw("learn_provoke")
			check(PetSkills.skill_level(rt, "provoke") == 1, "черепаха выучила «Дерзкий вызов» в окне")
			press_cw("toggle_provoke")
			check(PetSkills.toggle_on(rt, "provoke"), "у не призванного питомца переключаемое отмечено включённым")
			check(cw.buttons.has("skill_ram") and not cw.buttons.has("skill_shadow_rend"), "у черепахи свои умения: «Таран»")
			for i in [2, 3]:
				check(pm.open_creature(i, "stats") and cw.is_open(), "окно существа: питомец %d, «Существо»" % i)
				check(pm.open_creature(i, "skills") and cw.is_open(), "окно существа: питомец %d, «Умения»" % i)
			check(cw.buttons.has("skill_fierce_rush") and cw.tree.icons.size() == 4, "у кабана — 4 умения, есть «Свирепый натиск»")
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
		var sp_d := PetData.get_species(id)
		var d1 := PetStats.derived(id, 1)
		# У базовых сила редкости 1.0 — числа как прежде; у «Обычного» волка — ×MobData.power
		var pw := MobData.power(id)
		check(int(d1["max_hp"]) == roundi(float(sp_d["hp"]) * pw) and int(d1["atk"]) == roundi(float(sp_d["atk"]) * pw)
			and int(d1["def"]) == roundi(float(sp_d["def"]) * pw), "%s: на 1 ур. HP/атака/защита как прежде ×%.2f (%d/%d/%d)"
			% [id, pw, int(d1["max_hp"]), int(d1["atk"]), int(d1["def"])])
		for lvl in [14, 29]:
			var a := _stat_sum(id, lvl)
			var b := _stat_sum(id, lvl + 1)
			check(float(b) > float(a) * 1.1, "%s: эволюция на %d ур. — скачок статов %d → %d" % [id, lvl + 1, a, b])
	check(bad == "", "статы и производные не убывают с уровнем" + bad)
	var p1 := PetStats.base_stats("panther", 1)
	check(int(p1["int"]) > int(p1["str"]),
		"пантера-маг: Интеллект (%d) — главный, вместо Силы (%d)" % [int(p1["int"]), int(p1["str"])])
	var f1 := PetStats.base_stats("pheasant", 1)
	check(int(f1["wis"]) > int(f1["dex"]), "фазан-лекарь: Мудрость (%d) вместо Меткости (%d)" % [int(f1["wis"]), int(f1["dex"])])
	var t1 := PetStats.base_stats("turtle", 1)
	check(int(t1["vit"]) > int(t1["str"]), "черепаха-танк: Выносливость (%d) главная" % int(t1["vit"]))
	# Таблица вики: пантера Evo 3, уровень вики 150 = наш 45 — Сила вики 119 (у нас — Интеллект)
	check(int(PetStats.base_stats("panther", 45)["int"]) == 119, "пантера ур. 45 (вики 150): Интеллект 119")
	check(int(PetStats.base_stats("turtle", 45)["vit"]) == 119, "черепаха ур. 45 (вики 150): Выносливость 119")
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


func _stat_sum(id: String, lvl: int) -> int:
	var s := PetStats.base_stats(id, lvl)
	var t := 0
	for k in PetStats.STATS:
		t += int(s[k])
	return t


## HP и атака близки к прежним формулам (без умений).
func _check_balance() -> void:
	for sp in OLD:
		var o: Array = OLD[sp]
		var worst := ""
		for lvl in range(1, PetData.MAX_LEVEL + 1):
			var b := float(OLD_BONUS[PetData.stage_for(lvl)])
			var old_hp := (float(o[0]) + float(o[1]) * float(lvl - 1)) * b
			var old_atk := (float(o[2]) + float(o[3]) * float(lvl - 1)) * b
			var d := PetStats.derived(String(sp), lvl)
			var pw := MobData.power(String(sp))
			var rh := float(d["max_hp"]) / (old_hp * pw)
			var ra := float(d["atk"]) / (old_atk * pw)
			var early := lvl < 15
			var hp_ok := rh >= (0.75 if early else 0.7) and rh <= (1.35 if early else 1.65)
			var atk_ok := ra >= (0.8 if early else 0.75) and ra <= (1.25 if early else 1.4)
			if not (hp_ok and atk_ok):
				worst += " ур.%d HP×%.2f атака×%.2f" % [lvl, rh, ra]
		check(worst == "", "%s: HP и атака близки к прежнему балансу%s" % [sp, worst])
		var d10 := PetStats.derived(String(sp), 10)
		print("  %s ур.10: HP %d, атака %d, защита %d, MP %d" % [sp, int(d10["max_hp"]), int(d10["atk"]),
			int(d10["def"]), int(d10["max_mp"])])


## Данные умений: у каждого вида есть умения, у активных — MP и перезарядка; уровни вики → наши; бюджет JP.
func _check_skill_data() -> void:
	check(PetSkills.req_level(10) == 3 and PetSkills.req_level(15) == 5 and PetSkills.req_level(20) == 6
		and PetSkills.req_level(25) == 8 and PetSkills.req_level(30) == 9 and PetSkills.req_level(45) == 14,
		"уровни вики 10–45 → 3, 5, 6, 8, 9, 14")
	check(PetSkills.req_level(1) == 1 and PetSkills.req_level(50) == 15 and PetSkills.req_level(95) == 29
		and PetSkills.req_level(100) == 30 and PetSkills.req_level(150) == 45, "уровни вики 50–150 → 15–45")
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
			elif not sk.has("bonus"):
				bad += " %s: бонус" % id
			if PetSkills.effect_text(String(id), 1) == "" or PetSkills.requirement_text(String(id), 1) == "":
				bad += " %s: тексты" % id
		if not active:
			bad += " %s: нет активного" % sp
	check(bad == "", "данные умений в порядке" + bad)
	for sp in BASIC:
		var cost := 0
		for id in PetSkills.list_for(sp):
			var sk := PetSkills.get_skill(String(id))
			cost += int(sk["tiers"][0][1]) * int(sk["jp"])
		var have := PetStats.default_jp(15)
		check(float(have) >= float(cost) * 0.35 and float(have) <= float(cost) * 0.65,
			"%s: к 15 ур. %d JP — примерно половина умений 1-й стадии (%d JP)" % [sp, have, cost])
	check(PetSkills.effect_text("shadow_rend", 1).contains("2 × 60%"), "«Двойной росчерк»: 2 удара по 60%: "
		+ PetSkills.effect_text("shadow_rend", 1))
	check(PetSkills.effect_text("shadow_rend", 15).contains("200%"), "на 15 ур. — по 200%")
	check(PetSkills.mp_cost("shadow_rend", 1) == 5, "MP из вики × 0.1: 54 → 5")


## Древо умений пантеры: значок на каждое умение, ярусы помещаются, сверху вниз по уровню, пререквизиты выше,
## значки из assets/icons/pets/<вид>/<id>.png или кружок с буквой, подсветка доступных.
func _check_tree(cw: CreatureWindow) -> void:
	var tr := cw.tree
	check(tr != null and is_instance_valid(tr), "древо умений построено")
	if tr == null:
		return
	var ids := PetSkills.list_for("panther")
	check(tr.icons.size() == ids.size(), "древо: значок на каждое умение (%d)" % tr.icons.size())
	var max_rows := int(floor(tr.custom_minimum_size.y / SkillTree.row_min()))
	check(tr.rows.size() >= 3 and tr.rows.size() <= max_rows, "ярусов %d — помещаются (до %d)" % [tr.rows.size(), max_rows])
	check(tr.icon_size >= SkillTree.icon_min(), "значки не мельче %d px: %.0f" % [int(SkillTree.icon_min()), tr.icon_size])
	check(tr.row_of("inner_fire") == 0 and tr.row_of("inner_fire") < tr.row_of("shadow_bond")
		and tr.row_of("shadow_bond") < tr.row_of("midnight_vortex"), "ярусы сверху вниз по требуемому уровню")
	check(tr.row_of("shadow_rend") < tr.row_of("dusk_rupture") and tr.row_of("shadow_squall") < tr.row_of("midnight_vortex"),
		"пререквизит выше умения")
	check(tr.icon_center("dusk_rupture").y > tr.icon_center("shadow_rend").y, "линия пререквизита идёт сверху вниз")
	var inside := true
	for id in tr.icons:
		var b: Button = tr.icons[id]
		if b.position.x < 0.0 or b.position.y < 0.0 or b.position.x + b.size.x > tr.size.x + 1.0 \
				or b.position.y + b.size.y > tr.size.y + 1.0:
			inside = false
	check(inside, "все значки внутри древа %s" % tr.size)
	check(CreatureWindow.icon_path("panther", "inner_fire") == "res://assets/icons/pets/panther/inner_fire.png",
		"значок питомца: assets/icons/pets/<вид>/<id>.png")
	var b0: Button = tr.icons["inner_fire"]
	var tex := SkillTree.load_icon(CreatureWindow.icon_path("panther", "inner_fire"))
	if tex != null:
		check(not b0.find_children("*", "TextureRect", false, false).is_empty(), "значок из файла показан")
	else:
		check(not b0.find_children("*", "Label", false, false).is_empty(), "файла значка нет — кружок с буквой")
	# Доступные к изучению подсвечены (тень у рамки), недоступные — затемнены
	var rec: Dictionary = game.pets[0]
	var lit := 0
	var dim := 0
	for id in tr.icons:
		var b: Button = tr.icons[id]
		var sb := b.get_theme_stylebox("normal") as StyleBoxFlat
		var can := PetSkills.learn_block(rec, String(id)) == ""
		if can and sb != null and sb.shadow_size > 0:
			lit += 1
		if PetSkills.skill_level(rec, String(id)) == 0 and not can and b.modulate.r < 0.9:
			dim += 1
	check(lit > 0, "доступные к изучению подсвечены: %d" % lit)
	check(dim > 0, "недоступные затемнены: %d" % dim)


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
