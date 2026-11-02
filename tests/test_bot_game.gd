extends "res://tests/test_base.gd"
## Тест-бот, игровые режимы (этап 4; каркас и «Производительность» — tests/test_bot.gd):
## - каждый раздел BotSection (быстрый и полный проход) ставит шаги в очередь: первый — начало раздела;
## - режимы «Быстрый», «Полный», «По разделам» готовы; выбор разделов на вкладке «Тест-бот» (переключатели
##   bot_sec_<id>) запоминается, без выбора «Начать» недоступна, лимит «По разделам» — по оценке выбранных;
## - «Быстрый» целиком (паузы wait ×0.5): все разделы «готово», ни одной ошибки проверки (иначе — список ошибок
##   с разделами), посреди раздела «Питомцы» (шаг ожидания, не замер) подставной статус температуры 2 — пауза
##   «остывание» (дерево на паузе) и продолжение раздела; отчёт: «Разделов: 9 из 9», блок «Разделы» со всеми разделами, метки разделов
##   в логе; игрок снова в своём аккаунте, слоте и мире, размер интерфейса — как был.

const BOT_REPORTS := "user://test_bot_game_reports/"
const CHOICE := "user://test_bot_sections.cfg"

var _status := 0
var _bot: TestBot = null
var _result: Dictionary = {}
var _paused_at := ""
var _home_slot := ""


func before_start() -> void:
	# Пауза на остывание ставит дерево на паузу — тест должен идти и тогда
	process_mode = Node.PROCESS_MODE_ALWAYS
	BotScenarioGame.choice_path = CHOICE
	if FileAccess.file_exists(CHOICE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CHOICE))


func run_step() -> void:
	# Длинный проход: таймаут теста — по лимиту бота, не по счётчику кадров основы
	if TestBot.is_running():
		frame = mini(frame, 1000)
	match step:
		0:
			if not main._started:
				return
			_home_slot = FileAccess.get_file_as_string(Accounts.slot_path(0))
			_check_build()
			_check_modes()
			_check_tab()
			_start()
			step = 1
		1:
			# Посреди раздела «Питомцы» — «телефон нагрелся» (шаг сценария — не замер)
			if _bot.state == "running" and _bot.cur_section >= 0 and String(_bot.sections[_bot.cur_section]["id"]) == "pets" \
					and _bot._si > 0 and String(_bot._steps[_bot._si]["kind"]) == "until":
				_paused_at = _bot.step_name()
				_status = 2
				step = 2
		2:
			if _bot.state == "cooling":
				check(get_tree().paused and get_tree().root.disable_3d, "остывание в игровом разделе: дерево на паузе, 3D не рисуется")
				check(_bot.section_title() == "Питомцы" and _bot.pauses.size() == 1,
					"пауза — в разделе «Питомцы», шаг «%s»" % String(_bot.pauses[0]["step"]))
				_paused_at = String(_bot.pauses[0]["step"])
				_status = 0
				step = 3
		3:
			if _bot.state == "running":
				check(not get_tree().paused, "остыл — раздел продолжается")
				check(_bot.pauses.size() == 1 and String(_bot.pauses[0]["step"]) == _paused_at, "пауза записана с шагом")
				step = 4
		4:
			if _result.is_empty():
				return
			_check_result()
			step = 5
		5:
			if not (main != null and is_instance_valid(main) and main.is_inside_tree() and main._started
					and TestBot.current == null):
				return
			_check_home()
			ok_done()


func _on_main_changed(n: Node) -> void:
	main = n


func _on_finished(r: Dictionary) -> void:
	_result = r


## Каждый раздел ставит шаги (быстрый и полный проход), первый шаг — начало раздела.
func _check_build() -> void:
	check(BotSection.SECTIONS.size() == 9, "разделов 9: %s" % ", ".join(BotSection.ids()))
	for v in BotSection.ids():
		var sid := String(v)
		for q in [true, false]:
			var tb := TestBot.new()
			tb.main = main
			var sec := BotSection.create(sid)
			if not check(sec != null, "раздел «%s» создаётся" % sid):
				tb.free()
				continue
			sec.build(tb, q)
			var steps: Array[Dictionary] = tb._steps
			check(steps.size() >= 3 and String(steps[0]["kind"]) == "section" and String(steps[0]["id"]) == sid
				and tb.sections.size() == 1, "раздел «%s» (%s): шагов %d" % [sec.title(), "быстрый" if q else "полный",
				steps.size()])
			print("  раздел %s %s: шагов %d" % [sid, "быстрый" if q else "полный", steps.size()])
			tb.free()


func _check_modes() -> void:
	for m in ["quick", "full", "sections"]:
		var sc := BotScenario.create(String(m))
		check(sc != null and sc is BotScenarioGame, "режим «%s» готов" % BotScenario.mode_name(String(m)))
	check(BotScenario.create("quick").limit() == 360.0 and BotScenario.create("full").limit() == 720.0,
		"лимиты: «Быстрый» 6 мин, «Полный» 12 мин")
	check(BotScenarioGame.chosen() == BotSection.ids(), "без выбора «По разделам» — все разделы")
	BotScenarioGame.set_chosen(["world", "trade"])
	check(BotScenarioGame.chosen() == ["trade", "world"], "выбор разделов запоминается по порядку: %s" % [BotScenarioGame.chosen()])
	var sc2 := BotScenario.create("sections")
	check(sc2.limit() == maxf(180.0, BotScenarioGame.estimate(["trade", "world"]) * 1.5 + 60.0),
		"лимит «По разделам» — по оценке выбранных: %.0f с" % sc2.limit())


## Вкладка «Тест-бот», режим «По разделам»: переключатели разделов, выбор запоминается, без выбора — «Начать» серая.
func _check_tab() -> void:
	AdminPanel.open(main, "bot")
	AdminPanel.set_bot_mode(main, "sections")
	for v in BotSection.ids():
		check(AdminPanel.buttons.has("bot_sec_" + String(v)), "переключатель раздела «%s»" % String(v))
	check((AdminPanel.buttons["bot_sec_trade"] as Button).button_pressed
		and not (AdminPanel.buttons["bot_sec_ui"] as Button).button_pressed, "отмечены выбранные разделы")
	(AdminPanel.buttons["bot_sec_ui"] as Button).pressed.emit()
	check(BotScenarioGame.chosen() == ["trade", "world", "ui"], "раздел «Интерфейс» добавлен: %s" % [BotScenarioGame.chosen()])
	BotScenarioGame.set_chosen([])
	AdminPanel.open(main, "bot")
	check((AdminPanel.buttons["bot_start"] as Button).disabled, "ни одного раздела — «Начать» недоступна")
	BotScenarioGame.set_chosen(BotSection.ids())
	AdminPanel.set_bot_mode(main, "quick")
	check(not (AdminPanel.buttons["bot_start"] as Button).disabled and not AdminPanel.buttons.has("bot_sec_ui"),
		"«Быстрый»: «Начать» доступна, переключателей разделов нет")
	main.hud.close_window()
	AdminPanel.bot_mode = "perf"


func _start() -> void:
	_result = {}
	var err := TestBot.start(main, "quick", {"report_dir": BOT_REPORTS, "poll": 0.25, "cool_min": 0.5, "cool_max": 30.0,
		"time_scale": 0.5, "status_source": func() -> int: return _status, "headroom_source": func() -> int: return 400})
	check(err == "", "«Быстрый» запущен %s" % err)
	_bot = TestBot.current
	main = _bot.main
	_bot.main_changed.connect(_on_main_changed)
	_bot.finished.connect(_on_finished)
	check(_bot.limit == 360.0, "лимит «Быстрого»: %.0f с" % _bot.limit)


func _check_result() -> void:
	var bad := PackedStringArray()
	for c in _bot.checks:
		var cd: Dictionary = c
		if not bool(cd["ok"]):
			bad.append("[%s] %s" % [String(cd.get("section", "")), String(cd["text"])])
	for line in bad:
		printerr("  ошибка бота: " + line)
	check(String(_result["kind"]) == "done", "итог «Быстрого» — готово (%s: %s)" % [String(_result["kind"]),
		String(_result.get("reason", ""))])
	check(bad.is_empty(), "ошибок проверок бота нет (%d): %s" % [bad.size(), "; ".join(bad.slice(0, 12))])
	check(_bot.checks.size() > 100, "проверок бота: %d" % _bot.checks.size())
	for v in _bot.sections:
		var sd: Dictionary = v
		check(String(sd["state"]) == "готово" and float(sd["sec"]) > 0.0 and int(sd["checks"]) > 0,
			"раздел «%s»: %s, %s, проверок %d, снимков %d" % [String(sd["title"]), String(sd["state"]),
			TestBot.clock(float(sd["sec"])), int(sd["checks"]), int(sd["shots"])])
	check(_bot.sections.size() == 9, "разделов в отчёте: %d" % _bot.sections.size())
	print("  время «Быстрого»: активное %s, всего %s" % [TestBot.clock(_bot.active_time), TestBot.clock(_bot.total_time)])
	var text := FileAccess.get_file_as_string(String(_result["txt"]))
	for part in ["Режим: Быстрый (5 мин)", "Итог: готово", "Разделов: 9 из 9", "Разделы", "Пауз на остывание: 1",
			"Рекомендации", "Ошибок проверок нет.", "Журнал", "Проверки: "]:
		check(text.contains(part), "отчёт содержит «%s»" % part)
	for v in BotSection.SECTIONS:
		check(text.contains("  " + String((v as Dictionary)["name"])), "отчёт: раздел «%s»" % String((v as Dictionary)["name"]))
	check(not text.contains("Ошибки по разделам"), "ошибок по разделам нет")


func _check_home() -> void:
	check(Accounts.dir == TEST_ACCOUNTS and Accounts.current == "Dedok_max" and game.char_name == "Тест" and game.slot == 0,
		"игрок снова в своём аккаунте и слоте: %s, %s" % [Accounts.current, game.char_name])
	check(FileAccess.get_file_as_string(Accounts.slot_path(0)) != "" and main.player != null, "мир игрока")
	check(UiScale.level() == UiScale.MEDIUM, "размер интерфейса — как был: %s" % UiScale.level_name())
	check(not AdminPanel.god and not get_tree().paused, "бессмертие снято, игра не на паузе")
	check(Game.pets.is_empty() and game.class_id == "warrior" and game.level == 1, "герой игрока не тронут")
	if FileAccess.file_exists(CHOICE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CHOICE))
