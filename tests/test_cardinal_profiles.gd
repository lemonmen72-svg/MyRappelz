extends "res://tests/test_base.gd"
## Кардинал, фаза 4 — режим «Кардинал: профили игроков» (bot/bot_scenario_cardinal_profiles.gd, bot/cardinal_profiles.gd):
## режим в списке тест-бота и его настройки во вкладке «Тест-бот» (профили, отрезок, прогоны, раса и профессия,
## ускорение, оценка времени и причина, если начать нельзя); правки профилей из файла — с проверкой (вне пределов —
## на край, чужой ключ и тип — не берутся, неизвестный профиль — пропущен); серия прогонов всех пяти профилей на
## коротком отрезке (честно: опыт ×1) — у каждого метрики (уровни по времени, золото, бои, урон, зелья), у Новичка —
## паузы и не самые выгодные дела, у Экспериментатора — пробы с проверкой инвариантов, у Фармера — фарм и доход
## против заданий; распределения, подозрения с доказательствами и шагами повтора, раздел отчёта, JSON; движок и
## игрок — как были. Отрезок и профили — CARDINAL_PROFILES_SEG (elder / job / post), CARDINAL_PROFILES_LIST
## (через запятую), CARDINAL_PROFILES_SEEDS, CARDINAL_PROFILES_ACCEL.

const BOT_REPORTS := "user://test_cardinal_profiles_reports/"
const OVERRIDE := "user://test_cardinal_profiles.json"

var _bot: TestBot = null
var _result: Dictionary = {}


func before_start() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func run_step() -> void:
	if TestBot.is_running():
		frame = mini(frame, 1000)
	match step:
		0:
			if not main._started:
				return
			max_frames = 60 * 60 * 30
			var sc := BotScenario.create("cardinal_profiles")
			check(sc != null and sc.id() == "cardinal_profiles", "режим «Кардинал: профили игроков» готов")
			_check_ui()
			_check_overrides()
			_setup_run()
			main.hud.close_window()
			var err := TestBot.start(main, "cardinal_profiles", {"report_dir": BOT_REPORTS, "poll": 0.5,
				"status_source": func() -> int: return 0, "headroom_source": func() -> int: return 300})
			check(err == "", "Кардинал, профили запущен %s" % err)
			_bot = TestBot.current
			if _bot == null:
				fail("бот не запустился")
				return
			_bot.main_changed.connect(func(n: Node) -> void: main = n)
			_bot.finished.connect(func(r: Dictionary) -> void: _result = r)
			step = 1
		1:
			if _result.is_empty():
				return
			_check_result()
			step = 2
		2:
			if not (main != null and is_instance_valid(main) and main.is_inside_tree() and main._started
					and TestBot.current == null):
				return
			check(Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60 and not get_tree().root.disable_3d,
				"время, тики физики и 3D — как были")
			check(Mob.sleep_dist == Mob.SLEEP_DIST and not AdminPanel.god and Game.xp_mult >= 1,
				"дальность сна зверей и бессмертие — как были")
			check(Accounts.current == "Dedok_max" and game.char_name == "Тест", "игрок снова в своём аккаунте: %s, %s" % [
				Accounts.current, game.char_name])
			CardinalProfiles.use_file(CardinalProfiles.OVERRIDE_PATH)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(OVERRIDE))
			ok_done()


## Вкладка «Тест-бот»: настройки режима, оценка времени, причина, если начать нельзя.
func _check_ui() -> void:
	var S := BotScenarioCardinalProfiles
	var saved := [S.chosen.duplicate(), S.segment, S.seeds, S.race, S.job, S.accel]
	AdminPanel.open(main, "bot")
	AdminPanel.set_bot_mode(main, "cardinal_profiles")
	var need := ["bot_seg_elder", "bot_seg_job", "bot_seg_post", "bot_seeds_1", "bot_seeds_3", "bot_seeds_5", "bot_race_human",
		"bot_race_light_elf", "bot_race_dark_elf", "bot_paccel_8", "bot_paccel_16", "bot_paccel_32"]
	for pid in CardinalProfiles.IDS:
		need.append("bot_prof_" + String(pid))
	var miss: Array = []
	for k in need:
		if not AdminPanel.buttons.has(k):
			miss.append(k)
	check(miss.is_empty(), "вкладка: профили, отрезки, прогоны, раса, ускорение%s" % ("" if miss.is_empty() else " — нет " + str(miss)))
	(AdminPanel.buttons["bot_race_light_elf"] as Button).pressed.emit()
	check(S.race == "light_elf" and AdminPanel.buttons.has("bot_job_" + String(ClassData.jobs_of("light_elf")[1])),
		"раса — светлые эльфы, кнопки их профессий")
	(AdminPanel.buttons["bot_job_" + String(ClassData.jobs_of("light_elf")[1])] as Button).pressed.emit()
	check(S.job_for_run() == String(ClassData.jobs_of("light_elf")[1]), "профессия отрезка «10 → 15» — %s" % ClassData.job_name(S.job_for_run()))
	(AdminPanel.buttons["bot_seg_post"] as Button).pressed.emit()
	(AdminPanel.buttons["bot_seeds_5"] as Button).pressed.emit()
	(AdminPanel.buttons["bot_paccel_8"] as Button).pressed.emit()
	var why := S.validate()
	check(why.begins_with("Слишком долго") and (AdminPanel.buttons["bot_start"] as Button).disabled,
		"5 профилей × 5 прогонов «10 → 15 ур.» при ×8 — «%s», «Начать» недоступна" % why)
	for pid in CardinalProfiles.IDS:
		if S.chosen.has(pid):
			(AdminPanel.buttons["bot_prof_" + String(pid)] as Button).pressed.emit()
	check(S.chosen.is_empty() and S.validate() == "Выберите хотя бы один профиль.", "без профилей — «%s»" % S.validate())
	(AdminPanel.buttons["bot_prof_veteran"] as Button).pressed.emit()
	(AdminPanel.buttons["bot_prof_novice"] as Button).pressed.emit()
	check(S.chosen == ["novice", "veteran"], "выбор профилей — по порядку списка: %s" % str(S.chosen))
	main.hud.close_window()
	S.chosen = saved[0]
	S.segment = saved[1]
	S.seeds = saved[2]
	S.race = saved[3]
	S.job = saved[4]
	S.accel = saved[5]


## Правки профилей из файла: проверка и отказ с причиной в notes.
func _check_overrides() -> void:
	var f := FileAccess.open(OVERRIDE, FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"novice": {"noise": 2.0, "foo": 1, "pause_chance": 0.2},
		"veteran": {"use_pet": "да", "limits": {"deaths": 2, "bar": 1}},
		"pro": {"noise": 0.1},
		"farmer": {"farm_sec": 90.0},
	}))
	f.close()
	CardinalProfiles.use_file(OVERRIDE)
	var notes := "\n".join(CardinalProfiles.overrides()["notes"] as PackedStringArray)
	var nov := CardinalProfiles.profile("novice")
	var vet := CardinalProfiles.profile("veteran")
	check(float(nov["noise"]) == 1.0 and notes.contains("novice.noise: 2 вне пределов"),
		"вне пределов — на край (noise %.1f)" % float(nov["noise"]))
	check(not nov.has("foo") and notes.contains("novice.foo: неизвестный ключ"), "чужой ключ не взят")
	check(float(nov["pause_chance"]) == 0.2, "правка в пределах взята (pause_chance 0.2)")
	check(bool(vet["use_pet"]) and notes.contains("veteran.use_pet: значение да не того типа"), "не тот тип — не взят")
	check(int((vet["limits"] as Dictionary)["deaths"]) == 2 and notes.contains("veteran.limits.bar: неизвестный ключ"),
		"порог limits.deaths взят, чужой порог — нет")
	check(notes.contains("профиль «pro» неизвестен"), "неизвестный профиль пропущен")
	check(int(nov["xp_mult"]) == 1 and not bool(nov["god_bosses"]) and float(CardinalProfiles.profile("farmer")["farm_sec"]) == 90.0,
		"честный режим: опыт ×1, без бессмертия; фарм Фармера 90 с из правки")
	# Для прогона — без лишних правок, только короткий фарм (CARDINAL_PROFILES_FARM — свой, с)
	var fs := OS.get_environment("CARDINAL_PROFILES_FARM")
	var f2 := FileAccess.open(OVERRIDE, FileAccess.WRITE)
	f2.store_string(JSON.stringify({"farmer": {"farm_sec": float(fs) if fs != "" else 90.0}}))
	f2.close()
	CardinalProfiles.reread()


func _setup_run() -> void:
	var S := BotScenarioCardinalProfiles
	var seg := OS.get_environment("CARDINAL_PROFILES_SEG")
	S.segment = seg if S.SEGMENTS.has(seg) else "elder"
	var lst := OS.get_environment("CARDINAL_PROFILES_LIST")
	S.chosen = Array(lst.split(",")) if lst != "" else CardinalProfiles.IDS.duplicate()
	var sd := OS.get_environment("CARDINAL_PROFILES_SEEDS")
	S.seeds = int(sd) if sd != "" else 1
	var acc := OS.get_environment("CARDINAL_PROFILES_ACCEL")
	S.accel = float(acc) if acc != "" else 16.0
	S.race = "human"
	S.job = ""


func _check_result() -> void:
	var sc := _bot.scenario as BotScenarioCardinalProfiles
	check(sc != null, "сценарий профилей")
	if sc == null:
		return
	var S := BotScenarioCardinalProfiles
	var an := sc.analysis()
	check(not an.is_empty(), "разбор серии есть")
	if an.is_empty():
		return
	var profiles: Dictionary = an["profiles"]
	check(profiles.size() == S.chosen.size() and sc.runs.size() == S.chosen.size() * S.seeds, "прогонов %d, профилей %d" % [
		sc.runs.size(), profiles.size()])
	for r in sc.runs:
		var rd := r.result()
		var mm := BotScenarioCardinalProfiles.run_metrics(rd)
		print("ПРОФИЛЬ %s: %s — игровое %s, настоящее %s, ур. %d→%d, сдано %d, смертей %d, переносов %d, опыт %.0f/мин, золото %d (+%d/−%d), прокачка %d %%, паузы %d %%, боёв %d, TTK %.1f, урон %d, зелья %d/%d, сбился %d, выбор %d, проб %d (нарушений %d)" % [
			String(rd["title"]), String(rd["stop"]), TestBot.clock(float(mm["game"])), TestBot.clock(float(mm["wall"])),
			int(mm["level0"]), int(mm["level"]), int(mm["quests"]), int(mm["deaths"]), int(mm["teleports"]), float(mm["xp_min"]),
			int(mm["gold_end"]), int(mm["gold_in"]), int(mm["gold_out"]), roundi(float(mm["grind_share"]) * 100.0),
			roundi(float(mm["pause_share"]) * 100.0), int(mm["fights"]), float(mm["ttk"]), int(mm["dmg"]), int(mm["potions_used"]),
			int(mm["potions_bought"]), int(mm["lost"]), int(mm["noise"]), int(mm["fuzz"]), int(mm["violations"])])
		check(String(rd["stop"]) == "отрезок пройден", "«%s»: отрезок пройден (%s)" % [rd["title"], rd["stop"]])
		check((mm["level_secs"] as Array).size() >= 1 and int(mm["gold_in"]) > 0 and int(mm["fights"]) > 0,
			"«%s»: метрики — уровней %d, золото +%d, боёв %d" % [rd["title"], (mm["level_secs"] as Array).size(), int(mm["gold_in"]),
			int(mm["fights"])])
		check(int(rd["xp_mult"]) == 1 and int((rd.get("help", {}) as Dictionary).get("god", {}).get("n", 0)) == 0,
			"«%s»: честно — опыт ×1, без бессмертия" % rd["title"])
		match String(rd["profile"]):
			"novice":
				check(int(mm["noise"]) + int((rd["metrics"] as Dictionary)["pauses"]) + int(mm["lost"]) > 0,
					"Новичок: паузы, ошибки маршрута или не самые выгодные дела есть")
			"experimenter":
				check(int(mm["fuzz"]) > 0, "Экспериментатор: проб %d, нарушений инвариантов %d" % [int(mm["fuzz"]), int(mm["violations"])])
			"farmer":
				check(mm.has("farm") and float((mm["farm"] as Dictionary)["sec"]) >= 80.0, "Фармер: фарм после отрезка %s" % (
					TestBot.clock(float((mm["farm"] as Dictionary)["sec"])) if mm.has("farm") else "нет"))
	var sus: Array = an["suspicions"]
	for s in sus:
		var sd: Dictionary = s
		print("ПОДОЗРЕНИЕ [%s] %s — %s: %s" % [sd["severity"], sd["title"], sd["who"], "; ".join(sd["evidence"] as PackedStringArray)])
		check(String(sd["repro"]).contains("seed") or String(sd["repro"]).contains("отрезок"), "у подозрения — как повторить")
	var lines := "\n".join(sc.report_lines(_bot))
	check(lines.contains("Кардинал — профили игроков") and lines.contains("Распределения по профилю") and lines.contains("Подозрения")
		and lines.contains("      время: ") and lines.contains("питомец призван") and lines.contains("Пороги предварительные"),
		"раздел отчёта: прогоны (доли времени, приручения, питомец), распределения, подозрения с оговоркой о порогах")
	for r2 in sc.runs:
		var m2: Dictionary = r2.result()["metrics"]
		check(m2.has("tame_tries") and m2.has("pet_sec") and float(m2["pet_sec"]) <= float(r2.result()["game_sec"]) + 0.5,
			"«%s»: метрики приручения и питомца (питомец призван %.0f с из %.0f)" % [r2.title, float(m2.get("pet_sec", -1.0)),
			float(r2.result()["game_sec"])])
	var dir := String(_result.get("run_dir", ""))
	if dir == "":
		dir = _bot.run_dir
	var jp := dir.path_join("cardinal_profiles.json")
	check(FileAccess.file_exists(jp), "cardinal_profiles.json в папке запуска")
	if FileAccess.file_exists(jp):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(jp))
		check(d is Dictionary and (d as Dictionary).has("analysis") and ((d as Dictionary)["runs"] as Array).size() == sc.runs.size(),
			"в JSON — прогоны и разбор")
	# Разбор на подставных данных: тупик, перенос, смерти, нарушения — подозрения нужной важности
	var fake := {"title": "Подставной", "profile": "regular", "seed": 1, "stop": "делать больше нечего: оставшиеся цели застряли",
		"game_sec": 600.0, "wall_sec": 60.0, "start": {"level": 1, "cum_xp": 0, "gold": 1000},
		"finish": {"level": 3, "cum_xp": 500, "gold": 900}, "quests_done": 2, "deaths": 4, "kills": 10,
		"help": {"teleport": {"n": 2, "where": ["0:10: застрял у моста"]}},
		"quests": {"elder_hunt": {"name": "Тревога", "status": "stuck", "reason": "нет зверей"}},
		"events": [{"t": 100.0, "kind": "death", "text": "смерть у (1, 2)"}],
		"metrics": {"levels": [{"level": 1, "t": 0.0}, {"level": 2, "t": 60.0}, {"level": 3, "t": 120.0}],
			"grind_t": 400.0, "violations": ["0:20 [проба]: золото -5"], "no_gold": 1},
		"profile_full": {"limits": {"deaths": 1, "grind_share": 0.4, "level_k": 3.0, "pause_share": 0.15, "min_level_sec": 120.0}}}
	var fan := BotScenarioCardinalProfiles.analyze([fake], {}, {"segment": "elder", "accel": 8.0, "race": "human", "job": "warrior"})
	var titles := PackedStringArray()
	for s in fan["suspicions"]:
		titles.append("%s:%s" % [(s as Dictionary)["severity"], (s as Dictionary)["title"]])
	var tj := ", ".join(titles)
	check(tj.contains("высокая:Тупик") and tj.contains("средняя:Застревание на пути") and tj.contains("высокая:Много смертей")
		and tj.contains("средняя:Долгий обязательный гринд") and tj.contains("высокая:Нарушение правил") and tj.contains("Не хватило золота"),
		"подставной прогон — подозрения: %s" % tj)
	check(titles.size() > 0 and String(titles[0]).begins_with("высокая"), "подозрения — от высокой важности")
