extends "res://tests/test_base.gd"
## Тест-бот, фаза 5 Кардинала — фон Android и контрольные точки (без устройства: события Android и плагин подставные):
## - запуск 1 (сценарий LifeScenario из 4 частей, режим «life» через BotScenario.test_modes): свернули (FOCUS_OUT →
##   PAUSED) на 90 с и вернулись (RESUMED → FOCUS_IN) — тест стоял: журнал сворачиваний, away_time и away_total_us,
##   кадр после возвращения (delta 90 с) не идёт в активное время; кадр 25 с без уведомлений — «стояла»; шторка 3 с
##   (только FOCUS_OUT) — «без фокуса», тест шёл; часы Кардинала (CardinalStory.wall_sec) вычитают время в фоне;
##   плагин botState — бот идёт (режим и шаг в тексте), разрешение на уведомления спрошено (долгий режим, запрещены);
##   перегрев на 2-й части — точка «частей 2 из 4» остаётся (без .tmp), отчёт: «Сворачивания и фон», питание;
## - вкладка «Тест-бот»: «Прерванный запуск», «Продолжить» (настоящий путь AdminPanel.bot_resume) — готовые 2 части не
##   повторяются, тот же origin, в конце точка удалена, отчёт: «Продолжение запуска …»;
## - запуск 3: «Остановить тест» в уведомлении (botStopRequested) — остановка при возвращении, флаг снят, точка удалена;
## - recover_after_crash: метка RUNNING + «Остановить тест», пока игра была выгружена — точка удалена, stopped_by_notice,
##   уведомление снято; без флага точка цела;
## - порча контрольной точки (не JSON, sha256, схема, версия игры, режим нет / не продолжается) — причина, «Продолжить»
##   недоступна, «Забыть» удаляет; write_atomic не оставляет .tmp;
## - «Кардинал: профили игроков» и «Автотесты»: resume — выбор и готовые части из точки, build ставит только оставшиеся,
##   разбор профилей на результатах после JSON — те же подозрения, таблицы отчёта со звёздочкой «до перерыва».

const DIR := TestBot.REPORT_DIR
const AutoScenario := preload("res://bot/bot_scenario_autotests.gd")


## Четыре части по 0.4 с, после каждой — контрольная точка; resume — сколько готово.
class LifeScenario extends BotScenario:
	var parts := 4
	var done_parts := 0
	var built := 0
	var bot_ref: TestBot

	func id() -> String:
		return "life"

	func title() -> String:
		return "Проверка фона"

	func hero() -> Dictionary:
		return {"race": "human", "job": "warrior", "gender": "m", "level": 5}

	## 15 мин — долгий режим: бот спрашивает разрешение на уведомления.
	func limit() -> float:
		return 900.0

	func resumable() -> bool:
		return true

	func resume(data: Dictionary) -> String:
		if not data.has("done"):
			return "нет готовых частей"
		done_parts = int(data["done"])
		return ""

	func build(b: TestBot) -> void:
		bot_ref = b
		for i in range(done_parts, parts):
			built += 1
			b.wait(0.4)
			b.do("Часть %d" % (i + 1), _part.bind(i + 1))

	func _part(k: int) -> void:
		bot_ref.save_checkpoint({"done": k}, "частей %d из %d" % [k, parts])


## Плагин MyRappelzDownload понарошку: состояние бота, флаг «Остановить тест», питание, уведомления.
class LifePlugin extends RefCounted:
	var stop := false
	var states: Array = []
	var cleared := 0
	var asked := 0
	var allowed := false

	func botState(running: bool, t: String, text: String) -> bool:
		states.append([running, t, text])
		return true

	func botStopRequested() -> bool:
		return stop

	func botClearStop() -> void:
		stop = false
		cleared += 1

	func powerInfo() -> Dictionary:
		return {"power_save": false, "interactive": true, "ignoring_opt": false, "idle": false, "bg_restricted": false,
			"bucket": 10, "battery": 77, "plugged": 2, "charging": true, "notifications": allowed}

	func notificationsAllowed() -> bool:
		return allowed

	func requestNotifications() -> void:
		asked += 1

	func deviceInfo() -> Dictionary:
		return {"manufacturer": "Test", "model": "Life", "release": "14", "sdk": 34}

	func batteryTemp() -> int:
		return 300

	func lastError() -> String:
		return ""

	func exitHistory(_max_count: int, _trace_lines: int) -> String:
		return JSON.stringify({"sdk": 34, "exits": [], "error": ""})

	func saveToDownloads(_src: String, _rel: String, file_name: String, _mime: String) -> String:
		return "content://media/external/downloads/" + file_name

	func last_running() -> bool:
		return not states.is_empty() and bool((states[states.size() - 1] as Array)[0])


var _fake := LifePlugin.new()
var _status := 0
var _bot: TestBot = null
var _result: Dictionary = {}
var _origin := ""
var _had_dir := false


func before_start() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_had_dir = DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(DIR))
	TestBot.drop_checkpoint(DIR)
	if FileAccess.file_exists(DIR + TestBot.RUNNING):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + TestBot.RUNNING))


func run_step() -> void:
	match step:
		0:
			if not main._started:
				return
			BotScenario.test_modes["life"] = func() -> BotScenario: return LifeScenario.new()
			Assets.plugin_override = _fake
			_check_corrupt()
			_check_resume_scenarios()
			_start("запуск 1")
			step = 1
		1:
			# Часть 1 готова — свернули на 90 с, кадр 25 с без уведомлений, шторка 3 с
			if _bot.state == "running" and _bot.checkpoints >= 1:
				_check_away()
				step = 2
		2:
			if _bot.checkpoints >= 2 and _bot.state == "running":
				_status = 3
				step = 3
		3:
			if _result.is_empty():
				return
			_check_hot_report()
			step = 4
		4:
			if not _home_ready():
				return
			_check_tab_and_resume()
			step = 5
		5:
			if _result.is_empty():
				return
			_check_resumed_report()
			step = 6
		6:
			if not _home_ready():
				return
			_start("запуск 3")
			step = 7
		7:
			if _bot.state == "running" and _bot.checkpoints >= 1:
				# «Остановить тест» нажата, пока игра была свёрнута
				_fake.stop = true
				_bot.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
				_bot.notification(NOTIFICATION_APPLICATION_PAUSED)
				_bot.notification(NOTIFICATION_APPLICATION_RESUMED)
				_bot.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
				step = 8
		8:
			if _result.is_empty():
				return
			check(String(_result["kind"]) == "stopped" and _bot.stop_from_notice, "«Остановить тест» в уведомлении — остановка (%s)"
				% String(_result["kind"]))
			check(not _fake.stop and _fake.cleared >= 1, "флаг «Остановить тест» снят")
			check(not FileAccess.file_exists(DIR + TestBot.CHECKPOINT), "остановлен из уведомления — контрольная точка удалена")
			var text := FileAccess.get_file_as_string(String(_result["txt"]))
			check(text.contains("Остановлен кнопкой «Остановить тест» в уведомлении"), "отчёт: остановлен из уведомления")
			step = 9
		9:
			if not _home_ready():
				return
			_check_recover()
			_cleanup()
			ok_done()


func _on_main_changed(n: Node) -> void:
	main = n


func _on_finished(r: Dictionary) -> void:
	_result = r


func _home_ready() -> bool:
	return main != null and is_instance_valid(main) and main.is_inside_tree() and main._started and TestBot.current == null


func _start(what: String) -> void:
	_result = {}
	_status = 0
	var err := TestBot.start(main, "life", {"report_dir": DIR, "warmup": 0.2, "poll": 0.25,
		"status_source": func() -> int: return _status, "headroom_source": func() -> int: return 400})
	check(err == "", "%s: бот запущен %s" % [what, err])
	_bind_bot()


func _bind_bot() -> void:
	_bot = TestBot.current
	check(_bot != null and TestBot.is_running(), "TestBot.current")
	main = _bot.main
	_bot.main_changed.connect(_on_main_changed)
	_bot.finished.connect(_on_finished)


## Свернули на 90 с, простой 25 с без уведомлений, шторка 3 с; часы Кардинала.
func _check_away() -> void:
	var st_text := String((_fake.states[_fake.states.size() - 1] as Array)[2]) if not _fake.states.is_empty() else ""
	check(_fake.last_running() and st_text.contains("Режим «Проверка фона» — шаг ") and not st_text.contains("из 0"),
		"плагин знает: бот идёт (%s)" % str(_fake.states.back() if not _fake.states.is_empty() else "—"))
	check(_fake.asked == 1, "долгий режим, уведомления запрещены — разрешение спрошено (%d)" % _fake.asked)
	var act0 := _bot.active_time
	_bot.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_bot.notification(NOTIFICATION_APPLICATION_PAUSED)
	_bot._away_start_us -= 90 * 1000000
	_bot.notification(NOTIFICATION_APPLICATION_RESUMED)
	_bot.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	check(_bot.interruptions.size() == 1 and String(_bot.interruptions[0]["kind"]) == "свёрнута"
		and float(_bot.interruptions[0]["sec"]) >= 89.0, "свернули — запись «свёрнута» %.1f с" % (float(
		_bot.interruptions[0]["sec"]) if not _bot.interruptions.is_empty() else -1.0))
	check(_bot.away_time >= 89.0 and TestBot.away_total_us >= 89 * 1000000, "время в фоне: %.1f с (всего %d мкс)" % [
		_bot.away_time, TestBot.away_total_us])
	check(_bot._skip_dt, "кадр после возвращения не считается")
	# Кадр, в котором движок отдал всё время в фоне
	_bot._process(90.0)
	check(_bot.active_time - act0 < 0.5 and not _bot._skip_dt, "90 с в фоне не вошли в активное время (+%.2f с)" % (
		_bot.active_time - act0))
	_bot._process(25.0)
	check(_bot.interruptions.size() == 2 and String(_bot.interruptions[1]["kind"]) == "стояла" and _bot.active_time - act0 < 0.5,
		"кадр 25 с без уведомлений — «стояла», в лимиты не вошло")
	var away0 := _bot.away_time
	_bot.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_bot._away_start_us -= 3 * 1000000
	_bot.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	check(_bot.interruptions.size() == 3 and String(_bot.interruptions[2]["kind"]) == "без фокуса"
		and absf(_bot.away_time - away0) < 0.01 and not _bot._skip_dt, "шторка 3 с — «без фокуса», тест шёл")
	# Часы Кардинала: 10 с прошло, из них 8 с игра была свёрнута — 2 с
	var cs := CardinalStory.new()
	cs._wall0 = Time.get_ticks_usec() - 10 * 1000000
	cs._away0 = TestBot.away_total_us - 8 * 1000000
	check(absf(cs.wall_sec() - 2.0) < 0.6, "часы Кардинала без времени в фоне: %.2f с" % cs.wall_sec())


func _check_hot_report() -> void:
	check(String(_result["kind"]) == "hot", "перегрев на 2-й части: %s" % String(_result["kind"]))
	var cp := TestBot.read_checkpoint(DIR)
	check(bool(cp.get("ok", false)) and String(cp.get("progress", "")) == "частей 2 из 4" and String(cp.get("mode", "")) == "life",
		"контрольная точка цела: %s (%s)" % [String(cp.get("progress", "")), String(cp.get("error", ""))])
	_origin = String(cp.get("origin", ""))
	check(_origin == _bot.origin and _origin == _bot.base_name, "точка — этого запуска (%s)" % _origin)
	check(not FileAccess.file_exists(DIR + TestBot.CHECKPOINT + ".tmp"), "временного файла точки нет")
	check(not _fake.last_running(), "плагин знает: бот закончил (уведомление убрано)")
	var text := FileAccess.get_file_as_string(String(_result["txt"]))
	for s in ["Сворачивания и фон", "Свёрнута: 1, всего 1:30", "в лимиты не вошло", "Стояла без уведомления о паузе: 1",
			"Без фокуса (шторка, диалог — игра работала): 1", "Фоновой работы нет", "Контрольных точек записано: 2",
			"Питание в начале: зарядка: да (77 %)", "экономия энергии: выкл", "оптимизация батареи для игры: вкл",
			"группа ожидания: активная (10)", "уведомления: ЗАПРЕЩЕНЫ", "игра свёрнута 1:55 — не в счёт",
			"Контрольная точка сохранена (частей 2 из 4)"]:
		check(text.contains(s), "отчёт: «%s»" % s)


## Вкладка «Тест-бот»: прерванный запуск, «Продолжить» настоящим путём.
func _check_tab_and_resume() -> void:
	AdminPanel.open(main, "bot")
	check(AdminPanel.buttons.has("bot_resume") and AdminPanel.buttons.has("bot_forget"), "вкладка: «Продолжить» и «Забыть»")
	check(not (AdminPanel.buttons["bot_resume"] as Button).disabled, "«Продолжить» доступна")
	_result = {}
	var err := AdminPanel.bot_resume(main)
	check(err == "", "«Продолжить»: бот запущен %s" % err)
	_bind_bot()
	var sc := _bot.scenario as LifeScenario
	check(sc != null and sc.done_parts == 2, "сценарий знает: готово частей %d" % (sc.done_parts if sc != null else -1))
	check(_bot.origin == _origin and not _bot.resume_cp.is_empty(), "тот же запуск (origin %s)" % _bot.origin)


func _check_resumed_report() -> void:
	check(String(_result["kind"]) == "done", "продолжение — готово: %s" % String(_result["kind"]))
	var sc := _bot.scenario as LifeScenario
	check(sc != null and sc.built == 2, "готовые части не повторялись: поставлено %d из 4" % (sc.built if sc != null else -1))
	check(_bot.checkpoints == 2 and _bot.checkpoint_last == "частей 4 из 4", "продолжение записало точки 3 и 4 (%d, %s)" % [
		_bot.checkpoints, _bot.checkpoint_last])
	check(not FileAccess.file_exists(DIR + TestBot.CHECKPOINT), "запуск закончен — контрольная точка удалена")
	var text := FileAccess.get_file_as_string(String(_result["txt"]))
	check(text.contains("Продолжение запуска %s с контрольной точки «частей 2 из 4»" % _origin), "отчёт: продолжение запуска")
	check(text.contains("Игру не сворачивали."), "отчёт продолжения: игру не сворачивали")


## Порча контрольной точки; «Забыть»; write_atomic.
func _check_corrupt() -> void:
	var path := DIR + TestBot.CHECKPOINT
	check(not bool(TestBot.read_checkpoint(DIR).get("exists", true)), "точки нет")
	check(TestBot.write_atomic(DIR + "atomic.txt", "проба") and FileAccess.get_file_as_string(DIR + "atomic.txt") == "проба"
		and not FileAccess.file_exists(DIR + "atomic.txt.tmp"), "write_atomic: файл записан, .tmp нет")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + "atomic.txt"))
	var good := _cp_text("life", 1, BotReport.version(), {"done": 1})
	_write(path, good)
	var ok := TestBot.read_checkpoint(DIR)
	check(bool(ok.get("ok", false)) and int((ok["data"] as Dictionary)["done"]) == 1, "целая точка читается (%s)" % String(
		ok.get("error", "")))
	var cases := [
		["{не json", "повреждён"],
		[good.replace("\\\"done\\\":1", "\\\"done\\\":3"), "контрольная сумма"],
		[_cp_text("life", 99, BotReport.version(), {"done": 1}), "схемы"],
		[_cp_text("life", 1, "0.0.1", {"done": 1}), "версией игры 0.0.1"],
		[_cp_text("perf", 1, BotReport.version(), {"done": 1}), "не продолжается"],
		[_cp_text("nope", 1, BotReport.version(), {"done": 1}), "режима «nope» нет"],
	]
	for c in cases:
		_write(path, String(c[0]))
		var r := TestBot.read_checkpoint(DIR)
		check(bool(r.get("exists", false)) and not bool(r.get("ok", true)) and String(r.get("error", "")).contains(String(c[1])),
			"порча — «%s»: %s" % [String(c[1]), String(r.get("error", ""))])
	# Вкладка с негодной точкой: «Продолжить» недоступна, «Забыть» удаляет
	AdminPanel.open(main, "bot")
	check(AdminPanel.buttons.has("bot_resume") and (AdminPanel.buttons["bot_resume"] as Button).disabled,
		"негодная точка — «Продолжить» недоступна")
	(AdminPanel.buttons["bot_forget"] as Button).pressed.emit()
	check(not FileAccess.file_exists(path), "«Забыть» удалила точку")
	main.hud.close_window()


## Текст контрольной точки как у TestBot.save_checkpoint.
func _cp_text(mode_id: String, schema: int, ver: String, data: Dictionary) -> String:
	var body := JSON.stringify(data)
	return JSON.stringify({"schema": schema, "game_version": ver, "mode": mode_id, "title": "т", "origin": "o", "run": "o",
		"saved": "2026-11-07 10:00:00", "progress": "частей 1 из 4", "data_json": body, "sha256": body.sha256_text()})


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


## recover_after_crash: «Остановить тест», пока игра была выгружена, — точка удалена; без флага — цела.
func _check_recover() -> void:
	var tb := TestBot.new()
	tb.mode = "life"
	tb.scenario = LifeScenario.new()
	tb.origin = "X"
	tb.base_name = "X"
	tb.report_dir = DIR
	check(tb.save_checkpoint({"done": 1}, "частей 1 из 4"), "точка и метка «идёт тест» прошлого процесса")
	tb.free()
	_fake.stop = true
	TestBot.recover_after_crash(DIR)
	var m: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + TestBot.RUNNING))
	check(not FileAccess.file_exists(DIR + TestBot.CHECKPOINT) and m is Dictionary and bool((m as Dictionary).get(
		"stopped_by_notice", false)), "выгруженная игра, «Остановить тест» — точка удалена, в метке stopped_by_notice")
	check(not _fake.stop and not _fake.last_running(), "флаг снят, уведомление прежнего процесса убрано")
	var tb2 := TestBot.new()
	tb2.mode = "life"
	tb2.scenario = LifeScenario.new()
	tb2.origin = "Y"
	tb2.base_name = "Y"
	tb2.report_dir = DIR
	tb2.save_checkpoint({"done": 1}, "частей 1 из 4")
	tb2.free()
	TestBot.recover_after_crash(DIR)
	check(bool(TestBot.read_checkpoint(DIR).get("ok", false)), "без флага точка цела — «Продолжить» во вкладке")
	TestBot.drop_checkpoint(DIR)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + TestBot.RUNNING))


## «Кардинал: профили игроков» и «Автотесты»: продолжение без настоящего прогона.
func _check_resume_scenarios() -> void:
	var S := BotScenarioCardinalProfiles
	var saved := [S.chosen.duplicate(), S.segment, S.seeds, S.race, S.job, S.accel, S.seed_base]
	var fake := {"run": "novice_1", "title": "Новичок #1", "profile": "novice", "seed": 5, "stop": "делать больше нечего: оставшиеся цели застряли",
		"game_sec": 600.0, "wall_sec": 60.0, "start": {"level": 1, "cum_xp": 0, "gold": 1000},
		"finish": {"level": 3, "cum_xp": 500, "gold": 900}, "quests_done": 2, "deaths": 4, "kills": 10,
		"help": {"teleport": {"n": 2, "where": ["0:10: застрял у моста"]}},
		"quests": {"elder_hunt": {"name": "Тревога", "status": "stuck", "reason": "нет зверей"}},
		"events": [{"t": 100.0, "kind": "death", "text": "смерть у (1, 2)"}],
		"metrics": {"levels": [{"level": 1, "t": 0.0}, {"level": 2, "t": 60.0}, {"level": 3, "t": 120.0}],
			"grind_t": 400.0, "violations": PackedStringArray(["0:20 [проба]: золото -5"]), "no_gold": 1},
		"profile_full": {"limits": {"deaths": 1, "grind_share": 0.4, "level_k": 3.0, "pause_share": 0.15, "min_level_sec": 120.0}}}
	var settings := {"segment": "elder", "accel": 8.0, "race": "human", "job": "warrior"}
	var direct := _sus_titles(S.analyze([fake], {}, settings))
	var rt: Variant = JSON.parse_string(JSON.stringify(fake))
	check(_sus_titles(S.analyze([rt], {}, settings)) == direct and direct != "", "разбор после JSON — те же подозрения: %s" % direct)
	var ps := S.new()
	var err := ps.resume({"settings": {"profiles": ["novice", "regular"], "segment": "elder", "seeds": 1, "race": "human",
		"job": "", "accel": 8.0, "seed_base": 5}, "results": [rt]})
	check(err == "" and S.chosen == ["novice", "regular"] and S.segment == "elder" and S.seed_base == 5 and ps.prior.has("novice_1"),
		"профили: выбор и готовый прогон из точки (%s)" % err)
	check(ps.resume({"settings": {"profiles": ["nobody"], "segment": "elder"}, "results": []}).contains("неизвестный профиль"),
		"профили: неизвестный профиль — причина")
	ps.resume({"settings": {"profiles": ["novice", "regular"], "segment": "elder", "seeds": 1, "race": "human", "job": "",
		"accel": 8.0, "seed_base": 5}, "results": [rt]})
	var tb := TestBot.new()
	ps.build(tb)
	var sections := 0
	var cps := 0
	for st in tb._steps:
		var sd: Dictionary = st
		if String(sd["kind"]) == "section":
			sections += 1
		if String(sd["name"]) == "Кардинал: контрольная точка":
			cps += 1
	check(sections == 1 and cps == 1 and ps.runs.size() == 1 and ps.runs[0].run_name == "regular_1",
		"профили: поставлен только оставшийся прогон (разделов %d, точек %d)" % [sections, cps])
	check(ps.limit() < 60.0 * 120.0, "профили: лимит — по оставшимся прогонам (%.0f с)" % ps.limit())
	# Прогон этого запуска «закончен» — итог по обоим (из точки и новому)
	ps.runs[0].done = true
	ps.runs[0].stop_reason = "отрезок пройден"
	ps._summary(tb)
	var lines := "\n".join(ps.report_lines(tb))
	check(lines.contains("Новичок #1 *") and lines.contains("(* — прогон до перерыва"), "профили: в таблице — прогон до перерыва")
	tb.free()
	S.chosen = saved[0]
	S.segment = saved[1]
	S.seeds = saved[2]
	S.race = saved[3]
	S.job = saved[4]
	S.accel = saved[5]
	S.seed_base = saved[6]
	# Автотесты: готовый smoke_test из точки, ставится только test_accounts
	var au := AutoScenario.new()
	au.mode_key = "autotests_quick"
	var aerr := au.resume({"results": [{"name": "smoke_test", "status": "ok", "text": "", "sec": 3.0, "frames": 180, "fps": 60.0,
		"errors": ["e1"], "script_errors": 0, "other_errors": 1, "warnings": 0}], "only": ["smoke_test", "test_accounts"]})
	check(aerr == "" and au.results.size() == 1 and au.results[0]["errors"] is PackedStringArray, "автотесты: готовый тест из точки")
	var tb2 := TestBot.new()
	au.build(tb2)
	var tests := PackedStringArray()
	for st in tb2._steps:
		var sd: Dictionary = st
		if String(sd["kind"]) == "until":
			tests.append(String(sd["name"]))
	check(tests.size() == 1 and tests[0].contains("test_accounts"), "автотесты: поставлен только оставшийся (%s)" % ", ".join(tests))
	check("\n".join(tb2.journal).contains("из контрольной точки — готово 1 из 2"), "автотесты: в журнале — из точки")
	check("\n".join(au.report_lines(tb2)).contains("smoke_test *"), "автотесты: в таблице — тест до перерыва")
	tb2.free()


static func _sus_titles(an: Dictionary) -> String:
	var t := PackedStringArray()
	for s in an.get("suspicions", []):
		t.append("%s:%s" % [(s as Dictionary)["severity"], (s as Dictionary)["title"]])
	return ", ".join(t)


func _cleanup() -> void:
	BotScenario.test_modes.erase("life")
	Assets.plugin_override = null
	TestBot.drop_checkpoint(DIR)
	if not _had_dir:
		_rm_tree(ProjectSettings.globalize_path(DIR))


static func _rm_tree(abs_dir: String) -> void:
	var d := DirAccess.open(abs_dir)
	if d == null:
		return
	for f in d.get_files():
		DirAccess.remove_absolute(abs_dir.path_join(f))
	for sub in d.get_directories():
		_rm_tree(abs_dir.path_join(sub))
	DirAccess.remove_absolute(abs_dir)
