extends "res://tests/test_base.gd"
## Кардинал «Прохождение острова» (bot/bot_scenario_cardinal_story.gd, bot/cardinal_story.gd): режим в списке
## тест-бота; детерминизм на коротком отрезке (×8 и ×16 — одинаковые решения и итог); полный прогон расы людей —
## пройдены все задания острова и жителей, награды сходятся, фичи (крафт, закалка, торба, склад, приручение,
## снаряжение питомцу) без ошибок; cardinal_story.json и раздел отчёта; движок, настройки и игрок — как были.

const BOT_REPORTS := "user://test_cardinal_story_reports/"

var _bot: TestBot = null
var _result: Dictionary = {}


func before_start() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var env := OS.get_environment("CARDINAL_STORY_RACES")
	if env == "all":
		BotScenarioCardinalStory.races = [["human", false], ["light_elf", true], ["dark_elf", true]]
	elif env == "none":
		BotScenarioCardinalStory.races = []
	else:
		BotScenarioCardinalStory.races = [["human", false]]
	if OS.get_environment("CARDINAL_STORY_NODET") == "1":
		BotScenarioCardinalStory.det_quests = []
	var acc := OS.get_environment("CARDINAL_STORY_ACCEL")
	if acc != "":
		BotScenarioCardinalStory.accel = float(acc)
	# Быстрый прогон для CI (5–8 мин): опыт ×200 (бои короче), бег ×2 (путь короче), питомцу после заданий — опыт
	# ×50000; всё — помощь в отчёте. Как на телефоне (профиль по умолчанию) — CARDINAL_STORY_FULL=1
	if OS.get_environment("CARDINAL_STORY_FULL") != "1":
		BotScenarioCardinalStory.profile_over = {"xp_mult": 200, "run_speed": 2, "pet_phase_xp": 50000}


func run_step() -> void:
	if TestBot.is_running():
		frame = mini(frame, 1000)
	match step:
		0:
			if not main._started:
				return
			var sc := BotScenario.create("cardinal_story")
			check(sc != null and sc.id() == "cardinal_story", "режим «Кардинал: прохождение острова» готов")
			# Вкладка «Тест-бот»: у режима — выбор ускорения ×8 / ×16 / ×32
			var acc0 := BotScenarioCardinalStory.accel
			AdminPanel.open(main, "bot")
			AdminPanel.set_bot_mode(main, "cardinal_story")
			check(AdminPanel.buttons.has("bot_accel_8") and AdminPanel.buttons.has("bot_accel_16")
				and AdminPanel.buttons.has("bot_accel_32"), "на вкладке — ускорение ×8 / ×16 / ×32")
			(AdminPanel.buttons["bot_accel_32"] as Button).pressed.emit()
			check(BotScenarioCardinalStory.accel == 32.0, "кнопка ×32 ставит ускорение")
			BotScenarioCardinalStory.accel = acc0
			main.hud.close_window()
			var err := TestBot.start(main, "cardinal_story", {"report_dir": BOT_REPORTS, "poll": 0.5,
				"status_source": func() -> int: return 0, "headroom_source": func() -> int: return 300})
			check(err == "", "Кардинал запущен %s" % err)
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
			check(Mob.sleep_dist == Mob.SLEEP_DIST and not AdminPanel.god, "дальность сна зверей и бессмертие — как были")
			check(Accounts.current == "Dedok_max" and game.char_name == "Тест", "игрок снова в своём аккаунте: %s, %s" % [
				Accounts.current, game.char_name])
			ok_done()


func _check_result() -> void:
	var sc := _bot.scenario as BotScenarioCardinalStory
	var text := FileAccess.get_file_as_string(String(_result.get("txt", "")))
	for line in text.split("\n"):
		if line.begins_with("  ") and (line.contains("Кардинал") or line.contains("      ") or line.contains("Пройдено")
				or line.contains("Детерминизм") or line.contains("×")):
			print("  ОТЧЁТ" + line)
	var bad := PackedStringArray()
	for c in _bot.checks:
		var cd: Dictionary = c
		if not bool(cd["ok"]):
			bad.append(String(cd["text"]))
	check(String(_result["kind"]) == "done", "итог — готово (%s: %s)" % [String(_result["kind"]), String(_result.get("reason", ""))])
	check(bad.is_empty(), "проверки Кардинала без ошибок: %s" % "; ".join(bad))
	var json_path := _bot.run_dir.path_join("cardinal_story.json")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not BotScenarioCardinalStory.races.is_empty():
		check(sc != null and not sc.runs.is_empty(), "прогоны есть")
		check(data is Dictionary and not ((data as Dictionary).get("runs", []) as Array).is_empty(), "cardinal_story.json: прогоны (%s)" % json_path)
	for part in ["Кардинал — прохождение острова", "Воспроизвести:"]:
		check(text.contains(part), "отчёт содержит «%s»" % part)
	if not BotScenarioCardinalStory.races.is_empty():
		for part2 in ["Пройдено заданий:", "Помощь (послабления):"]:
			check(text.contains(part2), "отчёт содержит «%s»" % part2)
