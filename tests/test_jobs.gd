extends "res://tests/test_base.gd"
## Профессии (этап 1): данные 9 профессий и их древ (формула требований 10 + JLv × 0.75, пререквизиты, вкладки,
## оружие), сверх-эволюция (+5 JP за уровень выше 10, потолок 50), новый герой любой расы и пола — Бродяга без умений
## (кнопки HUD скрыты, в окне героя — подсказка), модель по расе и полу; задание «Доклад мудрецу» (sage_first_job:
## выдаёт охотница после «Волчьей стаи», сдать — мудрецу; ниже 10 ур. ждёт уровня, вся цепочка до него —
## tests/test_quest_chain.gd), сдача — окно выбора из трёх профессий расы (по прогону на каждую расу: на 10, 15
## и 20 ур.), повторно сменить нельзя, после профессии у мудреца — «Первое умение»; оружие профессий (стартовое, ранги,
## щит); старое сохранение Наёмника остаётся Наёмником с умениями; движок умений (образцы); админ-панель
## (раса и пол на лету, профессия сразу, уровень, JP, «изучить всё», сброс в Бродягу); сохранение пола и профессии.

const QID := "sage_first_job"

var _over_expected := 0


func race_class() -> Array:
	return ["human", "wanderer"]


func run_step() -> void:
	var player: Player = main.player
	match step:
		0:
			_check_data()
			_check_weapons_data()
			_check_new_heroes()
			# Герой теста: человек-мужчина, Бродяга
			game.new_character("Тест", "human", ClassData.WANDERER, "m")
			player.apply_class()
			step = 1
		1:
			_check_wanderer(player)
			step = 2
		2:
			_check_quest_gate()
			step = 3
		3:
			# Прогон 1: люди, 10 ур. — Воин (без сверх-эволюции)
			_run_job("human", 10, "warrior", 0)
			step = 4
		4:
			check(Game.change_job("shaman") == -1 and game.job_change_block("shaman") != "", "повторно сменить профессию нельзя")
			check(main.quests.state(QID) == "done" and main.quests.accept_block(QID) != "", "задание на профессию сдано")
			main.npcs.refresh_marks()
			check(main.npcs.npc("sage").mark_text() == "!" and main.quests.state("sage_first_skill") == "available",
			"после профессии у мудреца — «Первое умение»")
			# Прогон 2: светлые эльфы, 15 ур. — Волшебник, +25 JP
			_run_job("light_elf", 15, "wizard", 25)
			step = 5
		5:
			# Прогон 3: тёмные эльфы, 20 ур. — Адепт, +50 JP
			_run_job("dark_elf", 20, "adept", 50)
			step = 6
		6:
			_check_weapons(player)
			step = 7
		7:
			_check_engine(player)
			step = 8
		8:
			_check_old_save(player)
			step = 9
		9:
			_check_admin(player)
			wait = 3
			step = 10
		10:
			_check_save(player)
			ok_done()


# ---------- Данные ----------

func _check_data() -> void:
	check(HeroSkills.req_level(1) == 11 and HeroSkills.req_level(5) == 14 and HeroSkills.req_level(10) == 18
		and HeroSkills.req_level(20) == 25 and HeroSkills.req_level(30) == 33 and HeroSkills.req_level(40) == 40,
		"требуемый уровень = 10 + JLv × 0.75: 1→11, 5→14, 10→18, 20→25, 30→33, 40→40")
	check(ClassData.over_jp(9) == 0 and ClassData.over_jp(10) == 0 and ClassData.over_jp(15) == 25
		and ClassData.over_jp(20) == 50 and ClassData.over_jp(25) == 50, "сверх-эволюция на 10/15/20/25 ур.: 0/25/50/50")
	var want := {"swordsman": 25, "wizard": 27, "beastmaster": 30, "assassin": 27, "neophyte": 29, "adept": 30,
		"warrior": 24, "shaman": 28, "conjurer": 28}
	var unique: Dictionary = {}
	for rid in ClassData.RACES:
		var jobs := ClassData.jobs_of(String(rid))
		check(jobs.size() == 3, "%s: три профессии" % rid)
		for j in jobs:
			check(ClassData.job_race(String(j)) == String(rid), "%s — профессия расы %s" % [j, rid])
	check(ClassData.is_wanderer("wanderer") and not ClassData.is_job("wanderer") and ClassData.job_race("wanderer") == "",
		"Бродяга — у всех рас")
	for jid in want:
		var job := String(jid)
		var c := ClassData.cls(job)
		check(String(c["desc"]) != "" and String(c["role"]) != "" and String(c["weapon_text"]) != "", "%s: тексты для выбора" % job)
		check((c["key_skills"] as Array).size() >= 3, "%s: ключевые умения" % job)
		for k in c["key_skills"]:
			check(HeroSkills.has_skill(job, String(k)), "%s: ключевое умение %s в древе" % [job, k])
		var ids := HeroSkills.list_for(job)
		check(ids.size() == int(want[job]), "%s: умений %d (по справочнику %d)" % [job, ids.size(), int(want[job])])
		var tabs: Array = []
		for t in HeroSkills.tabs_for(job):
			tabs.append(String(t[0]))
		check(tabs.size() == 3, "%s: три вкладки" % job)
		var bad := ""
		for id in ids:
			var sid := String(id)
			unique[sid] = true
			var sk := HeroSkills.get_skill(sid, job)
			if sk.is_empty() or String(sk.get("name", "")) == "" or String(sk.get("desc", "")) == "":
				bad += " %s: нет данных" % sid
				continue
			if not ["active", "passive", "toggle"].has(String(sk["kind"])):
				bad += " %s: вид" % sid
			if not tabs.has(String(sk["tab"])):
				bad += " %s: вкладка" % sid
			var mx := HeroSkills.max_level(sid, job)
			if mx <= 0 or (sk["jp"] as Array).size() != mx:
				bad += " %s: уровни/JP" % sid
			var prev := 0
			for n in range(1, mx + 1):
				var need := HeroSkills.level_needed(sid, n, job)
				if need < prev or need < 10 or need > 40:
					bad += " %s: ур. %d" % [sid, need]
				prev = need
				if HeroSkills.jp_cost(sid, n, job) <= 0 and not bool(sk.get("start", false)):
					bad += " %s: JP" % sid
			for g in HeroSkills.weapon_need(sid, job):
				if not HeroSkills.WEAPON_GROUPS.has(String(g)):
					bad += " %s: оружие %s" % [sid, g]
			if sk.has("pre"):
				var pre := String((sk["pre"] as Array)[0])
				if not ids.has(pre) or HeroSkills.level_needed(pre, 1, job) > HeroSkills.level_needed(sid, 1, job):
					bad += " %s: пререквизит %s" % [sid, pre]
			HeroSkills.job = job
			if HeroSkills.effect_text(sid, 1) == "" or HeroSkills.requirement_text(sid, 1) == "":
				bad += " %s: тексты" % sid
		check(bad == "", "%s: данные древа в порядке%s" % [job, bad])
		check(HeroSkills.total_cost(job) > 100, "%s: древо стоит %d JP" % [job, HeroSkills.total_cost(job)])
	HeroSkills.job = game.class_id
	check(unique.size() >= 150, "уникальных умений профессий: %d" % unique.size())
	# Общие умения: один id — у разных профессий свой уровень и вкладка
	check(HeroSkills.level_needed("first_aid", 1, "wizard") == 11 and HeroSkills.level_needed("first_aid", 1, "swordsman") == 29,
		"«Свет в ладонях»: Волшебнику с 11 ур., Мечнику с 29 ур.")
	check(HeroSkills.weapon_need("charge_stab", "adept") == ["dagger"] and HeroSkills.weapon_need("charge_stab", "assassin") == ["blades"],
		"«Пронзающий выпад»: у Адепта — кинжал, у Наёмника — клинки")
	# Наёмник: требования пересчитаны, стартовые — с 10 ур.
	check(HeroSkills.level_needed("shadow_step", 1, "assassin") == 10 and HeroSkills.level_needed("backstab", 1, "assassin") == 10
		and HeroSkills.level_needed("blade_mastery", 1, "assassin") == 11 and HeroSkills.level_needed("drain_arrow", 1, "assassin") == 40,
		"Наёмник: стартовые с 10 ур., «Школа клинка» — 11, «Иссушающие болты» — 40")


func _check_weapons_data() -> void:
	for id in ["weapon_sword_1h_r1", "weapon_sword_2h_r1", "weapon_dagger_r1", "weapon_mace_1h_r1", "weapon_mace_2h_r1",
			"weapon_axe_2h_r1", "weapon_axe_1h_r1", "weapon_staff_1h_r1", "weapon_staff_2h_r1", "weapon_shield_r1"]:
		check(ItemData.is_weapon(id) and ItemData.rank(id) == 1, "%s: оружие 1-го ранга" % id)
		check(ResourceLoader.exists(ItemData.icon_path(id)), "%s: значок есть" % id)
		check(ItemData.weapon_fits(id, ClassData.WANDERER), "%s: подходит Бродяге" % id)
		check(NpcData.shop("merchant").has(id), "%s: продаёт торговец" % id)
	check(ItemData.weapon_attack("staff_2h") == "magic" and ItemData.weapon_attack("axe_2h") == "melee"
		and ItemData.weapon_attack("crossbow") == "ranged", "посох — магия, топор — ближний бой, арбалет — стрельба")
	check(ItemData.weapon_fits("crossbow_starter", ClassData.WANDERER) and ItemData.weapon_fits("weapon_bow_r1", ClassData.WANDERER)
		and ItemData.weapon_fits("dagger_steel", ClassData.WANDERER), "Бродяге — любое оружие (и лук, и арбалет)")
	check(ItemData.is_weapon("weapon_bow_r1") and NpcData.shop("merchant").has("weapon_bow_r1"), "лук новичка у торговца")
	for jid in ClassData.CLASSES:
		var job := String(jid)
		var st := ItemData.starter_weapons(job)
		check(not st.is_empty(), "%s: стартовое оружие" % job)
		for w in st:
			check(ItemData.weapon_fits(String(w), job), "%s: стартовое %s подходит" % [job, w])


## Новый герой каждой расы и пола — Бродяга без умений, учебный меч в руках.
func _check_new_heroes() -> void:
	for rid in ClassData.RACES:
		for g in ["f", "m"]:
			game.new_character("Проба", String(rid), ClassData.WANDERER, String(g))
			var who := "%s/%s" % [rid, g]
			check(game.class_id == "wanderer" and game.race_id == String(rid) and game.gender == String(g), "%s: Бродяга" % who)
			check(not game.job_changed and game.job_level_at_change == 0, "%s: профессии нет" % who)
			check((game.hero["skills"] as Dictionary).is_empty() and String((game.hero["slots"] as Array)[0]) == "",
				"%s: умений нет, кнопки пусты" % who)
			check(int(game.hero["jp"]) == HeroSkills.JP_START, "%s: JP копятся (%d)" % [who, int(game.hero["jp"])])
			check(game.weapon == "weapon_sword_1h_r1", "%s: учебный меч" % who)
			var spec := CharacterModel.spec_for(game.race_id, game.class_id, game.weapon_kind(), game.gender)
			check(String(spec.get("asset", CharacterModel.hero_asset(String(rid), String(g), "wanderer")))
				== CharacterModel.hero_asset(String(rid), String(g), "wanderer"), "%s: модель %s" % [who,
				CharacterModel.hero_asset(String(rid), String(g), "wanderer").get_file()])
	# Профессию сразу (автотесты, админ) — как будто уже получена
	game.new_character("Проба", "dark_elf", "assassin")
	check(game.job_changed and HeroSkills.skill_level(game.hero, "backstab") == 1, "Наёмник сразу: стартовые умения")


# ---------- Бродяга ----------

func _check_wanderer(player: Player) -> void:
	check(game.class_id == "wanderer" and player.weapon_kind == "sword_1h" and player.attack_kind == "melee",
		"Бродяга с учебным мечом, ближний бой")
	check(player.hero_stats.size() > 0 and player.max_mp > 0, "у Бродяги 7 статов и MP")
	for i in 4:
		check(not main.hud.is_button_visible("skill%d" % (i + 1)), "кнопка умения %d скрыта" % (i + 1))
	check(not use_now(player, "skill1") and main.hud._msg_label.text.contains("10 уровне"), "умений нет: %s" % main.hud._msg_label.text)
	check(player._model.spec.get("gender", "") == "m", "модель: мужской пол")
	if player._model.spec.has("asset"):
		check(String(player._model.spec["asset"]) == CharacterModel.hero_asset("human", "m", "wanderer"), "модель Бродяги по расе и полу")
	var hw: CharacterWindow = main.hero_window
	hw.open("hero")
	check(hw.buttons.has("tab_wanderer") and hw.buttons.size() > 0 and not hw.buttons.has("tab_common"),
		"окно героя: вкладка «Умения» Бродяги")
	check(_window_text().contains("Бродяга"), "профессия в окне героя")
	hw.buttons["tab_wanderer"].pressed.emit()
	var t := _window_text()
	check(t.contains("Умения появятся после выбора профессии на 10 уровне") and t.contains("Воин") and t.contains("Шаман"),
		"подсказка и профессии расы")
	main.hud.close_window()
	# Бродяга может надеть любое оружие 1-го ранга (посох — магия)
	game.inventory.add("weapon_staff_2h_r1")
	check(player.equip("weapon_staff_2h_r1") == "" and player.attack_kind == "magic", "Бродяга с посохом: магия")
	check(player.equip("weapon_sword_1h_r1") == "", "снова учебный меч")


# ---------- Задание на профессию ----------

func _check_quest_gate() -> void:
	var q: Quests = main.quests
	# Путь до доклада пройден: староста, мудрец, охотница (сама цепочка — tests/test_quest_chain.gd)
	for k in QuestData.PRE_JOB:
		game.quests_done[String(k)] = 1
	game.level = 9
	q._changed()
	main.npcs.refresh_marks()
	check(QuestData.giver(QID) == "hunter" and QuestData.turn_in(QID) == "sage", "«Доклад мудрецу»: выдаёт охотница, сдать мудрецу")
	check(q.state(QID) == "available" and main.npcs.npc("hunter").mark_text() == "!", "у охотницы доклад доступен и на 9 ур.")
	check(q.accept(QID), "доклад взят на 9 ур.")
	check(not q.is_ready(QID) and q.goal_progress(QID, 0) == 9, "на 9 ур. доклад ждёт 10 уровня: %d/10" % q.goal_progress(QID, 0))
	main.npcs.refresh_marks()
	check(main.npcs.npc("sage").mark_kind == "active", "над мудрецом серый «?»")
	check(QuestData.text(QID, "progress").contains("десятого уровня") and QuestData.goal_text(QuestData.goals(QID)[0]).contains("10 уровня"),
		"понятно, чего ждёт доклад: «%s»" % QuestData.goal_text(QuestData.goals(QID)[0]))
	game.level = 10
	main.player.apply_class()
	game.changed.emit()
	check(q.is_ready(QID), "с 10 ур. доклад можно сдать")
	main.npcs.refresh_marks()
	check(main.npcs.npc("sage").mark_text() == "=", "над мудрецом «=»: «%s»" % main.npcs.npc("sage").mark_text())
	check(not bool(NpcData.talk_entry("sage", "profession").get("soon", false)), "пункт «Первая профессия» — рабочий")
	check(q.abandon(QID) and q.state(QID) == "available", "отказ — доклад снова у охотницы")


## Пройти задание мудреца героем расы race на уровне lvl и выбрать профессию job; ожидаемый бонус — over.
func _run_job(race: String, lvl: int, job: String, over: int) -> void:
	var player: Player = main.player
	var q: Quests = main.quests
	if not ClassData.is_wanderer(game.class_id):
		AdminPanel.reset_job(main)
	game.race_id = race
	game.level = lvl
	game.xp = 0
	player.apply_class()
	check(game.class_id == "wanderer" and q.state(QID) == "available", "%s %d ур.: Бродяга, задание доступно" % [race, lvl])
	# Взять у охотницы через диалог: на 10+ ур. сразу можно сдавать
	var npcs: Npcs = main.npcs
	npcs.open_dialog("hunter", "quest", QID)
	check(npcs.buttons.has("accept"), "кнопка «Взять задание»")
	npcs.buttons["accept"].pressed.emit()
	check(q.is_active(QID) and q.is_ready(QID), "доклад взят, на %d ур. — можно сдавать" % lvl)
	main.npcs.refresh_marks()
	check(main.npcs.npc("sage").mark_text() == "=", "над мудрецом «=» (можно сдать)")
	# Сдача — окно выбора профессии
	npcs.open_dialog("sage", "quest", QID)
	check(npcs.buttons.has("complete"), "кнопка «Сдать задание»")
	npcs.buttons["complete"].pressed.emit()
	var jw: JobWindow = main.job_window
	check(jw.is_open() and jw.quest_id == QID, "открыт выбор профессии")
	for j in ClassData.jobs_of(race):
		check(jw.buttons.has("pick_" + String(j)), "карточка «%s»" % ClassData.job_name(String(j)))
	check(jw.buttons.size() == 3, "только три профессии своей расы")
	var other := String(ClassData.jobs_of(race)[1]) if String(ClassData.jobs_of(race)[0]) == job else String(ClassData.jobs_of(race)[0])
	jw.buttons["pick_" + other].pressed.emit()
	check(jw.picked == other and jw.buttons.has("confirm") and jw.buttons.has("cancel"), "подтверждение выбора")
	jw.buttons["cancel"].pressed.emit()
	check(jw.picked == "" and game.class_id == "wanderer", "отмена — профессия не сменена")
	jw.buttons["pick_" + job].pressed.emit()
	var t := _window_text()
	if over > 0:
		check(t.contains("Сверх-эволюция: +%d очков умений" % over), "на экране выбора: «Сверх-эволюция: +%d»" % over)
	else:
		check(not t.contains("Сверх-эволюция"), "на 10 ур. сверх-эволюции нет")
	var rec: Dictionary = game.hero
	rec["jp_part"] = 0.0
	var jp0 := int(rec["jp"])
	var xp_jp := int(floor(float(HeroSkills.JP_PER_LEVEL) * float(QuestData.rewards(QID)["xp"]) / float(game.xp_to_next(lvl)) + 0.0001))
	jw.buttons["confirm"].pressed.emit()
	check(game.class_id == job and game.job_changed and game.job_level_at_change == lvl, "%s: профессия %s на %d ур."
		% [race, ClassData.job_name(job), lvl])
	check(q.state(QID) == "done", "задание сдано вместе с выбором")
	check(int(rec["jp"]) == jp0 + over + xp_jp, "JP: %d → %d (сверх-эволюция +%d, за опыт награды +%d)"
		% [jp0, int(rec["jp"]), over, xp_jp])
	if over > 0:
		check(main.hud._msg_label.text.contains("Сверх-эволюция: +%d очков умений" % over), "сообщение: %s" % main.hud._msg_label.text)
	check(main.hud._msg_label.text.contains(ClassData.job_name(job)), "сообщение о новой профессии")
	check(ItemData.weapon_fits(game.weapon, job) and game.weapon == ItemData.default_weapon(job),
		"в руках стартовое оружие профессии: %s" % ItemData.item_name(game.weapon))
	check(player.weapon_kind == game.weapon_kind(), "игрок пересчитан под оружие")
	if player._model.spec.has("asset"):
		check(String(player._model.spec["asset"]) == CharacterModel.hero_asset(race, game.gender, job),
			"модель профессии: %s" % String(player._model.spec["asset"]).get_file())
	# Древо открыто: вкладки профессии, можно изучать умения от 11 ур.
	var hw: CharacterWindow = main.hero_window
	hw.open("hero")
	for tb in HeroSkills.tabs_for(job):
		check(hw.buttons.has("tab_" + String(tb[0])), "вкладка древа «%s»" % String(tb[1]))
	check(not hw.buttons.has("tab_wanderer"), "вкладки Бродяги нет")
	hw.buttons["tab_" + String(HeroSkills.tabs_for(job)[0][0])].pressed.emit()
	check(hw.tree != null and hw.tree.icons.size() == HeroSkills.list_tab(job, String(HeroSkills.tabs_for(job)[0][0])).size(),
		"древо вкладки построено")
	main.hud.close_window()
	var learnable := 0
	for id in HeroSkills.list_for(job):
		if HeroSkills.learn_block(rec, job, game.level, String(id)) == "":
			learnable += 1
	if lvl >= 11:
		check(learnable > 0, "есть умения, которые можно изучить сейчас: %d" % learnable)
	else:
		check(learnable == 0, "на 10 ур. изучить ещё нечего (первые умения — с 11 ур.)")


# ---------- Оружие профессий ----------

func _check_weapons(player: Player) -> void:
	become_job("swordsman")
	check(game.weapon == "weapon_sword_1h_r1" and game.shield == "weapon_shield_r1", "Мечник: меч и щит")
	check(player.has_shield and player._model.spec.get("shield", false) == true, "щит в модели")
	check(player.equip("crossbow_starter") != "", "Мечнику арбалет не надеть")
	game.inventory.add("weapon_sword_2h_r1")
	check(player.equip("weapon_sword_2h_r1") == "" and game.shield == "", "двуручный меч снимает щит")
	check(player.equip("weapon_shield_r1") != "", "к двуручному щит не надеть")
	become_job("assassin")
	check(game.weapon == "weapon_dagger_r1" and player.weapon_kind == "daggers" and not player.has_shield,
		"Наёмник: два кинжала, щита нет")
	check(player.equip("weapon_shield_r1") != "", "Наёмнику щит не надеть")
	become_job("warrior")
	check(player.weapon_kind == "axe_2h", "Воин: двуручный топор")
	become_job("neophyte")
	check(player.weapon_kind == "staff_2h" and player.attack_kind == "magic", "Неофит: посох, магия")
	game.inventory.add("weapon_dagger_r1")
	check(player.equip("weapon_dagger_r1") != "", "Неофиту кинжал не надеть")
	check(player.equip("weapon_staff_1h_r1") == "" and player.attack_kind == "magic" and player.cast_speed > 0.0,
		"Неофит: одноручный посох — магия, каст быстрее")
	for j in ClassData.CLASSES:
		for k in ClassData.weapons(String(j)):
			check(ItemData.WEAPON_KINDS.has(String(k)), "%s: вид оружия %s известен" % [j, k])


# ---------- Движок умений ----------

func _check_engine(player: Player) -> void:
	game.level = 21
	become_job("wizard")
	var matk0 := player.matk
	learn_skills(["magic_training", "first_aid"])
	check(player.matk > matk0, "пассивка «Сила знаний»: маг. атака %d → %d" % [matk0, player.matk])
	player.assign_slot("first_aid", 0)
	player.hp = 10
	player.mp = player.max_mp
	check(use_now(player, "skill1") and player.hp > 10, "«Свет в ладонях» лечит героя: %d" % player.hp)
	# Группа созвучий: одно за раз
	become_job("conjurer")
	learn_skills(["beast_kinship", "chord_vitality", "chord_strength", "pet_mentor", "pet_vigor", "lullaby"])
	player.mp = player.max_mp
	var vit0 := int(player.hero_stats["stats"]["vit"])
	check(player.set_toggle("chord_vitality", true) == "", "«Созвучие крепости» включено")
	check(int(player.hero_stats["stats"]["vit"]) > vit0, "Выносливость %d → %d" % [vit0, int(player.hero_stats["stats"]["vit"])])
	check(player.set_toggle("chord_strength", true) == "", "«Созвучие силы» включено")
	check(HeroSkills.toggle_on(game.hero, "chord_strength") and not HeroSkills.toggle_on(game.hero, "chord_vitality"),
		"одно созвучие за раз")
	check(HeroSkills.is_ready("lullaby") and not HeroSkills.effect_text("lullaby", 1).contains("следующем обновлении"),
		"«Колыбельная» действует (этап 2)")
	# Не готовое умение (если у Колдуна ещё есть такое) не применяется
	var unready := ""
	for id in HeroSkills.list_for("conjurer"):
		if unready == "" and HeroSkills.kind(String(id)) != "passive" and not HeroSkills.is_ready(String(id)):
			unready = String(id)
	if unready != "":
		(game.hero["skills"] as Dictionary)[unready] = 1
		player.assign_slot(unready, 1)
		check(HeroSkills.effect_text(unready, 1).contains("следующем обновлении"), "в карточке — «в разработке»")
		check(not use_now(player, "skill2") and main.hud._msg_label.text.contains("следующем обновлении"),
			"не готовое умение не применяется")
	check(HeroSkills.pet_aura_bonuses(game.hero, "conjurer", player.weapon_kind).has("str"), "аура созвучия — и питомцу")


# ---------- Сохранения ----------

## Старое сохранение Наёмника (до профессий): остаётся Наёмником, изученные умения не отбираются.
func _check_old_save(player: Player) -> void:
	game.from_dict({"version": 1, "name": "Старая", "race": "dark_elf", "class": "assassin", "level": 8,
		"hero": {"jp": 3, "jp_part": 0.0, "skills": {"backstab": 2, "shadow_step": 1, "blade_mastery": 1, "charge_stab": 1},
			"toggles": {}, "slots": ["backstab", "shadow_step", "charge_stab", ""]}})
	player.apply_class()
	check(game.class_id == "assassin" and game.job_changed and game.job_level_at_change == 0 and game.load_note == "",
		"старый Наёмник остался Наёмником (без сверх-эволюции)")
	check(HeroSkills.skill_level(game.hero, "charge_stab") == 1 and HeroSkills.skill_level(game.hero, "backstab") == 2,
		"изученные умения сохранены (хоть и ниже новых требований)")
	check(HeroSkills.level_needed("charge_stab", 1) > game.level, "«Пронзающий выпад» по новым правилам — с 14 ур.")
	check(HeroSkills.learn_block(game.hero, "assassin", game.level, "charge_stab").contains("Нужен ур."),
		"следующий уровень — с требуемого уровня")
	check(player.skill_id("skill3") == "charge_stab", "кнопка 3 сохранена")
	var hw: CharacterWindow = main.hero_window
	hw.selected = "charge_stab"
	hw.open("blades")
	check(_window_text().contains("Изучено раньше"), "в карточке — пометка «изучено раньше, по новым правилам — ур. N»")
	main.hud.close_window()


## Админ-панель (вкладка «Герой»; всё остальное — tests/test_admin_panel.gd): раса и пол, профессия, уровень, JP,
## «изучить всё», полное HP/MP, сброс в Бродягу.
func _check_admin(player: Player) -> void:
	SettingsMenu.open(main.hud)
	check(SettingsMenu.buttons.has("admin"), "в настройках — кнопка «Админ»")
	SettingsMenu.buttons["admin"].pressed.emit()
	check(AdminPanel.buttons.has("job_neophyte") and AdminPanel.buttons.has("race_light_elf"), "админ-панель открыта")
	AdminPanel.buttons["race_light_elf"].pressed.emit()
	AdminPanel.buttons["gender_m"].pressed.emit()
	check(game.race_id == "light_elf" and game.gender == "m", "раса и пол сменены")
	check(player._model.spec.get("gender", "") == "m", "модель пересобрана (мужской пол)")
	if player._model.spec.has("asset"):
		check(String(player._model.spec["asset"]) == CharacterModel.hero_asset("light_elf", "m", game.class_id),
			"модель: %s" % String(player._model.spec["asset"]).get_file())
	AdminPanel.buttons["job_neophyte"].pressed.emit()
	check(game.class_id == "neophyte" and player.weapon_kind == "staff_2h", "профессия Неофит: посох в руках")
	if player._model.spec.has("asset"):
		check(String(player._model.spec["asset"]) == CharacterModel.hero_asset("light_elf", "m", "neophyte"),
			"модель сменилась с профессией: %s" % String(player._model.spec["asset"]).get_file())
	check((game.hero["skills"] as Dictionary).is_empty(), "умения прежней профессии сброшены")
	var jp0 := int(game.hero["jp"])
	AdminPanel.buttons["jp_plus100"].pressed.emit()
	check(int(game.hero["jp"]) == jp0 + 100, "+100 JP")
	var lv0: int = game.level
	AdminPanel.buttons["lvl_plus10"].pressed.emit()
	check(game.level == mini(lv0 + 10, AdminPanel.MAX_LEVEL), "уровень +10: %d" % game.level)
	AdminPanel.buttons["learn_all"].pressed.emit()
	var learned := (game.hero["skills"] as Dictionary).size()
	check(learned > 0, "изучены все доступные умения: %d" % learned)
	var jp_before := int(game.hero["jp"])
	AdminPanel.buttons["job_swordsman"].pressed.emit()
	check(game.class_id == "swordsman" and int(game.hero["jp"]) > jp_before, "смена профессии вернула JP: %d → %d"
		% [jp_before, int(game.hero["jp"])])
	check(game.shield == "weapon_shield_r1" and player.has_shield, "Мечник: щит выдан и надет")
	var hw: CharacterWindow = main.hero_window
	check(HeroSkills.tabs_for(game.class_id).size() == 3, "древо Мечника")
	player.hp = 1
	AdminPanel.open(main)
	AdminPanel.buttons["full"].pressed.emit()
	check(player.hp == player.max_hp and player.mp == player.max_mp, "полное HP/MP")
	AdminPanel.buttons["reset_job"].pressed.emit()
	check(game.class_id == "wanderer" and not game.job_changed and main.quests.state(QID) != "done",
		"сброс в Бродягу: задание мудреца можно пройти заново")
	for i in 4:
		check(not main.hud.is_button_visible("skill%d" % (i + 1)), "кнопки умений Бродяги скрыты (%d)" % (i + 1))
	hw.open("hero")
	check(hw.buttons.has("tab_wanderer"), "окно героя — вкладка Бродяги")
	main.hud.close_window()


func _check_save(player: Player) -> void:
	game.level = 12
	become_job("shaman")
	game.gender = "f"
	check(game.save_game(), "игра сохранена")
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
	check(d is Dictionary and int((d as Dictionary)["version"]) == 2 and String((d as Dictionary)["gender"]) == "f"
		and bool((d as Dictionary)["job_changed"]), "в сохранении: версия 2, пол, профессия получена")
	game.class_id = "wanderer"
	check(game.load_game(), "игра загружена")
	player.apply_class()
	check(game.class_id == "shaman" and game.race_id == "light_elf" and game.gender == "f" and game.job_changed,
		"после загрузки: Шаман, светлый эльф, женский пол (раса — по админ-панели)")


# ---------- Помощники ----------

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
