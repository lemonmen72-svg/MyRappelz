extends "res://tests/test_base.gd"
## Кардинал, фаза 1 (bot/bot_scenario_cardinal.gd, bot/cardinal_run.gd): режим «Кардинал: первый срез» в списке
## тест-бота; прогон целиком с коротким игровым временем — тестовый герой фармит зверей у деревни людей с картинкой и
## ускоренно (×4): оба прогона дошли до конца, есть убийства, опыт за каждое убийство = формула игры, ускоренный
## быстрее по настоящему времени; cardinal.json с двумя прогонами и сравнением, раздел отчёта; время, шаги физики,
## предел кадров и 3D — как были; игрок снова в своём аккаунте и мире, герой не тронут. Фаза 2: отдых героя в мире
## совпадает с расчётом CardinalRun.rest_predict и без ускорения, и при ускорении игры ×32 (основа перемотки отдыха).

const BOT_REPORTS := "user://test_cardinal_reports/"

var _bot: TestBot = null
var _result: Dictionary = {}


func before_start() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	BotScenarioCardinal.game_limit = 50.0


func run_step() -> void:
	if TestBot.is_running():
		frame = mini(frame, 1000)
	match step:
		0:
			if not main._started:
				return
			var sc := BotScenario.create("cardinal")
			check(sc != null and sc.id() == "cardinal", "режим «Кардинал: первый срез» готов")
			var err := TestBot.start(main, "cardinal", {"report_dir": BOT_REPORTS, "poll": 0.5,
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
			check(Engine.time_scale == 1.0 and not get_tree().root.disable_3d, "время и 3D — как были")
			check(Accounts.current == "Dedok_max" and game.char_name == "Тест", "игрок снова в своём аккаунте: %s, %s" % [
				Accounts.current, game.char_name])
			# Фаза 2: эквивалентность отдыха — настоящий отдых героя в мире против расчёта (rest_predict), без перемотки
			# и с ускорением игры (как буст отдыха, Engine.time_scale): игровое время по Util.game_time
			_rest_case(1.0)
			step = 3
		3:
			if _rest_tick():
				_rest_case(32.0)
				step = 4
		4:
			if _rest_tick():
				ok_done()


var _rest_run: CardinalRun = null
var _rest_t0 := 0.0
var _rest_scale := 1.0


func _rest_case(scale: float) -> void:
	var p: Player = main.player
	_rest_run = CardinalRun.new()
	_rest_scale = scale
	for n in get_tree().get_nodes_in_group("mobs"):
		(n as Node).set_process(false)
	p.hp = roundi(float(p.max_hp) * 0.3)
	p.regen_delay = Player.REST_DELAY
	_rest_run.profile = CardinalRun.PROFILE_REGULAR
	_rest_run.set_meta("pred", _rest_run.rest_predict(p))
	_rest_t0 = Util.game_time()
	Engine.time_scale = scale


## Отдых идёт; true — закончен и проверен.
func _rest_tick() -> bool:
	var p: Player = main.player
	if float(p.hp) < float(p.max_hp) * float(CardinalRun.PROFILE_REGULAR["rest_until"]):
		if Util.game_time() - _rest_t0 > 200.0:
			Engine.time_scale = 1.0
			fail("отдых не закончился за 200 игровых секунд")
		return false
	Engine.time_scale = 1.0
	var actual := Util.game_time() - _rest_t0
	var pred := float(_rest_run.get_meta("pred"))
	check(pred > 2.0 and absf(actual - pred) / pred <= CardinalRun.REST_TOL,
		"отдых ×%.0f: факт %.1f с, расчёт %.1f с (допуск %.0f %%)" % [_rest_scale, actual, pred, CardinalRun.REST_TOL * 100.0])
	return true


func _check_result() -> void:
	var bad := PackedStringArray()
	for c in _bot.checks:
		var cd: Dictionary = c
		if not bool(cd["ok"]):
			bad.append(String(cd["text"]))
	check(String(_result["kind"]) == "done", "итог — готово (%s: %s)" % [String(_result["kind"]), String(_result.get("reason", ""))])
	check(bad.is_empty(), "проверки Кардинала без ошибок: %s" % "; ".join(bad))
	var sc := _bot.scenario as BotScenarioCardinal
	check(sc != null and sc.runs.size() == 2, "два прогона")
	if sc != null:
		for r in sc.runs:
			var d := r.result()
			print("  КАРДИНАЛ %s: игровое %.1f с, настоящее %.1f с (×%.2f), убийств %d, опыт %d (%.1f/мин), TTK %.2f с, урон %d, смертей %d" % [
				d["title"], float(d["game_sec"]), float(d["wall_sec"]), float(d["speedup"]), int(d["kills"]), int(d["xp"]),
				float(d["xp_per_min"]), float(d["ttk_avg"]), int(d["damage_taken"]), int(d["deaths"])])
	var json_path := _bot.run_dir.path_join("cardinal.json") if _bot.run_dir != "" else BOT_REPORTS.path_join("cardinal.json")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	check(data is Dictionary and ((data as Dictionary).get("runs", []) as Array).size() == 2
		and ((data as Dictionary).get("compare", []) as Array).size() == 6, "cardinal.json: 2 прогона и сравнение (%s)" % json_path)
	var text := FileAccess.get_file_as_string(String(_result.get("txt", "")))
	for part in ["Кардинал — первый срез", "Сравнение «ускоренный / с картинкой»", "Воспроизвести:"]:
		check(text.contains(part), "отчёт содержит «%s»" % part)
