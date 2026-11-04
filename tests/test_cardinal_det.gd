extends "res://tests/test_base.gd"
## Кардинал, фаза 2: режим «Кардинал: детерминизм» — два ускоренных прогона (×4) с одним seed. Без экрана и при ровных
## 60 кадрах/с (CI) журналы убийств и итог (уровень, опыт, золото) обязаны совпасть; отчёт и cardinal.json с разделом
## determinism; игрок снова в своём аккаунте, время и 3D — как были.

const BOT_REPORTS := "user://test_cardinal_det_reports/"

var _bot: TestBot = null
var _result: Dictionary = {}


func before_start() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	BotScenarioCardinal.game_limit = 40.0


func run_step() -> void:
	if TestBot.is_running():
		frame = mini(frame, 1000)
	match step:
		0:
			if not main._started:
				return
			var sc := BotScenario.create("cardinal_det")
			check(sc != null and sc.id() == "cardinal_det" and (sc as BotScenarioCardinal).is_det(), "режим «Кардинал: детерминизм» готов")
			var err := TestBot.start(main, "cardinal_det", {"report_dir": BOT_REPORTS, "poll": 0.5,
				"status_source": func() -> int: return 0, "headroom_source": func() -> int: return 300})
			check(err == "", "запущен %s" % err)
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
			var fails: Array = []
			for c in _bot.checks:
				if not bool((c as Dictionary)["ok"]):
					fails.append(String((c as Dictionary)["text"]))
			check(fails.is_empty(), "проверки без ошибок: %s" % "; ".join(PackedStringArray(fails)))
			var txt := FileAccess.get_file_as_string(String(_result.get("txt", "")))
			check(txt.contains("Кардинал — проверка детерминизма") and txt.contains("Детерминизм (одинаковый seed"),
				"раздел отчёта о детерминизме")
			var js := FileAccess.get_file_as_string(String(_bot.run_dir).path_join("cardinal.json"))
			var d: Variant = JSON.parse_string(js)
			check(d is Dictionary and (d as Dictionary).has("determinism") and bool((d as Dictionary)["determinism"]["ok"]),
				"cardinal.json: прогоны совпали — %s" % [(d as Dictionary).get("determinism", {}) if d is Dictionary else js.left(80)])
			step = 2
		2:
			if not (main != null and is_instance_valid(main) and main.is_inside_tree() and main._started
					and TestBot.current == null):
				return
			check(Engine.time_scale == 1.0, "время — как было")
			check(Accounts.current == "Dedok_max" and game.char_name == "Тест", "игрок снова в своём аккаунте")
			ok_done()
