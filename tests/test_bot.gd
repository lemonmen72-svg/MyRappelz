extends "res://tests/test_base.gd"
## Тест-бот (TestBot, папка bot/): каркас на коротком подставном сценарии (ShortScenario — три замера по 1 с,
## зверь, ожидание условия), без устройства:
## - вкладка «Тест-бот» админ-панели — только у Dedok_max (у другого логина нет ни панели, ни запуска);
## - имя отчёта (версия, дата), транслитерация снимков, BotMetrics (к/с, процентили, заминки);
## - запуск 1: бот переключается на своё хранилище и тестового героя (сохранение игрока не меняется), замеры
##   собираются, подставной статус температуры 2 — пауза «остывание» (дерево на паузе, 3D не рисуется, экран
##   остывания), статус 0 — продолжение; итог «готово»: отчёт .txt (формат, разделы, устройство из плагина),
##   .zip с отчётом и снимками, копии в «Загрузки/DarkPact_test» через подставной плагин; тестовое хранилище
##   стёрто, игрок снова в своём аккаунте и слоте, в своём мире; settings.cfg не тронут, авто-снижение снова работает;
##   «Открыть отчёт» и «Поделиться» вкладки — через плагин;
## - запуск 2: статус 3 — «Тест остановлен: телефон перегрелся», отчёт, возврат игрока; перед ним — метка RUNNING
##   «прошлого незаконченного запуска» (шаг test_combat): отчёт начинается с предупреждения и причины конца процесса
##   по данным Android (подставной exitHistory: crash_native со следом), раздел «Прошлые завершения игры»;
## - запуск 3: режим «Автотесты на телефоне» (bot_scenario_autotests.gd) на своём списке — настоящий test_combat
##   (прошёл), test_bot (пропущен — только CI), подставные тесты: не прошёл (fail), завис (таймаут), не наследует
##   test_base (ошибка); главная сцена убрана на время тестов, настройки игрока убраны и возвращены, аккаунты тестов
##   стёрты, игрок снова в своём мире; раздел «Автотесты» отчёта; список тестов и «быстрые»; recover_after_crash.

const BOT_REPORTS := "user://test_bot_reports/"
const AutoScenario := preload("res://bot/bot_scenario_autotests.gd")
const RECOVER_DIR := "user://test_bot_recover/"
## Подставные тесты раннера автотестов.
const FAKE_FAIL := """extends "res://tests/test_base.gd"
func run_step() -> void:
	if main._started:
		fail("нарочно не прошёл (проверка раннера автотестов), settings.cfg есть: %s" % FileAccess.file_exists("user://settings.cfg"))
"""
const FAKE_HANG := """extends "res://tests/test_base.gd"
func run_step() -> void:
	pass
"""
const FAKE_PLAIN := """extends Node
"""


## Короткий сценарий: город, три замера по 1 с (пресет, база, настройка), зверь, ожидание условия.
class ShortScenario extends BotScenario:
	func id() -> String:
		return "test"

	func title() -> String:
		return "Проверка каркаса"

	func hero() -> Dictionary:
		return {"race": "light_elf", "job": "wizard", "gender": "m", "level": 20}

	func limit() -> float:
		return 300.0

	func build(b: TestBot) -> void:
		b.do("Город", func() -> void: b.teleport(Vector2(0, 5), "Город"))
		b.measure("Город", "Низкое", 1.0, {"preset": Quality.LOW, "kind": "preset"})
		b.measure("Город", "Среднее (база)", 1.0, {"preset": Quality.MEDIUM, "kind": "setting", "base": true})
		b.measure("Город", "Тени: Выкл", 1.0, {"preset": Quality.MEDIUM, "option": ["shadows", 0], "kind": "setting"})
		b.do("Зверь", func() -> void: b.check(b.spawn("wolf", 3, b.ahead(5.0)) != null, "зверь поставлен"))
		b.wait_until("зверь жив", func() -> bool: return b.spawned_alive().size() == 1, 2.0)
		b.wait(0.3)

	func report_lines(_b: TestBot) -> PackedStringArray:
		return PackedStringArray(["Раздел сценария: проверка каркаса"])


## Плагин MyRappelzDownload понарошку: «Загрузки» — папка user://test_downloads, устройство и батарея.
class FakePlugin extends RefCounted:
	var saved: Array = []
	var shared: Array = []
	var opened: Array = []

	func saveToDownloads(src: String, rel: String, file_name: String, mime: String) -> String:
		saved.append([src, rel, file_name, mime])
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://test_downloads"))
		DirAccess.copy_absolute(src, ProjectSettings.globalize_path("user://test_downloads/" + file_name))
		return "content://media/external/downloads/%d" % saved.size()

	func share(path: String, mime: String, t: String) -> bool:
		shared.append([path, mime, t])
		return true

	func openFile(path: String, mime: String) -> bool:
		opened.append([path, mime])
		return true

	func deviceInfo() -> Dictionary:
		return {"manufacturer": "Test", "model": "Phone X", "release": "14", "sdk": 34, "soc": "Fake SoC 9",
			"hardware": "fakehw", "abi": "arm64-v8a", "ram_total_mb": 11878, "ram_avail_mb": 4198, "ram_low": false,
			"last_exit": "user_requested, статус 0, 2026-11-01 18:40:12"}

	func batteryTemp() -> int:
		return 312

	func lastError() -> String:
		return ""

	## Прошлые завершения (свежие первыми): выход игрока, сбой движка со следом (после метки прошлого запуска), ANR.
	func exitHistory(max_count: int, trace_lines: int) -> String:
		var exits := [
			{"reason": "user_requested", "code": 10, "status": 0, "description": "remove task", "time": "2026-11-01 18:30:00",
				"importance": "в фоне", "process": "com.lemonmen.myrappelz", "pid": 300, "pss_mb": 400, "rss_mb": 500, "trace": []},
			{"reason": "crash_native", "code": 5, "status": 6, "description": "crash", "time": "2026-11-01 18:05:00",
				"importance": "на экране", "process": "com.lemonmen.myrappelz", "pid": 200, "pss_mb": 812, "rss_mb": 900,
				"trace": ["Abort message: 'test abort'", "libgodot_android.so (Node::_propagate+40)"]},
			{"reason": "anr", "code": 6, "status": 0, "description": "Input dispatching timed out", "time": "2026-11-01 17:00:00",
				"importance": "на экране", "process": "com.lemonmen.myrappelz", "pid": 100, "pss_mb": 700, "rss_mb": 800,
				"trace": ["----- pid 100 at 2026-11-01 17:00:00 -----", "\"main\" prio=5 tid=1 Native"]},
		]
		return JSON.stringify({"sdk": 34, "exits": exits.slice(0, max_count), "error": "", "lines": trace_lines})


var _fake := FakePlugin.new()
var _status := 0
var _headroom := 400
var _bot: TestBot = null
var _result: Dictionary = {}
var _run := 0
var _settings_before := ""
var _home_slot := ""
var _auto: AutoScenario = null
## settings.cfg до теста (вернуть в конце: user:// общий у тестов одной задачи CI).
var _had_settings := false
var _settings_orig := ""


func before_start() -> void:
	# Пауза на остывание ставит дерево на паузу — тест должен идти и тогда
	process_mode = Node.PROCESS_MODE_ALWAYS


func run_step() -> void:
	match step:
		0:
			if not main._started:
				return
			_check_admin_only()
			_check_units()
			_settings_before = FileAccess.get_file_as_string(Quality.PATH) if FileAccess.file_exists(Quality.PATH) else ""
			_had_settings = FileAccess.file_exists(Quality.PATH)
			_settings_orig = _settings_before
			_home_slot = FileAccess.get_file_as_string(Accounts.slot_path(0))
			check(_slot_key(_home_slot).begins_with("Тест|"), "слот 1 игрока — «Тест»")
			Assets.plugin_override = _fake
			_start_run()
			step = 1
		1:
			# Первый замер готов — «телефон нагрелся»
			if _bot.rows.size() >= 1 and _bot.state == "running":
				_status = 2
				step = 2
		2:
			if _bot.state == "cooling":
				check(get_tree().paused, "остывание: дерево на паузе")
				check(get_tree().root.disable_3d, "остывание: 3D-мир не рисуется")
				check(_bot.overlay.cooling_visible(), "остывание: экран «Остывание телефона…»")
				check(_bot.pauses.size() == 1, "пауза записана")
				_status = 0
				step = 3
		3:
			if _bot.state == "running":
				check(not get_tree().paused and not get_tree().root.disable_3d, "остыл — игра снова идёт")
				check(_bot.pauses.size() == 1 and float(_bot.pauses[0]["sec"]) >= 0.5, "пауза не короче cool_min: %.2f с"
					% float(_bot.pauses[0]["sec"]))
				step = 4
		4:
			if _result.is_empty():
				return
			_check_report_done()
			step = 5
		5:
			if not _home_ready():
				return
			_check_home("запуск 1")
			_check_tab_buttons()
			_check_recover()
			_status = 0
			# «Прошлый запуск не закончился»: метка RUNNING автотестов на шаге test_combat
			var f := FileAccess.open(BOT_REPORTS + TestBot.RUNNING, FileAccess.WRITE)
			f.store_string(JSON.stringify({"time": "2026-11-01 18:00", "mode": "autotests", "step": "test_combat"}))
			f.close()
			_start_run()
			step = 6
		6:
			if _bot.rows.size() >= 1 and _bot.state == "running":
				_status = 3
				step = 7
		7:
			if _result.is_empty():
				return
			check(String(_result["kind"]) == "hot", "статус 3 — остановка «перегрелся»: %s" % String(_result["kind"]))
			var text := FileAccess.get_file_as_string(String(_result["txt"]))
			check(text.contains("Тест остановлен: телефон перегрелся"), "отчёт: «Тест остановлен: телефон перегрелся»")
			check(text.contains("Итог: остановлен: телефон перегрелся"), "отчёт: итог — перегрев")
			check(text.contains("повторите на остывшем телефоне"), "рекомендация после перегрева")
			_check_interrupted(text)
			step = 8
		8:
			if not _home_ready():
				return
			_check_home("запуск 2")
			_start_autotests()
			step = 9
		9:
			if _result.is_empty():
				return
			_check_autotests_report()
			step = 10
		10:
			if not _home_ready():
				return
			_check_home("запуск 3 (автотесты)")
			check(not FileAccess.file_exists(BOT_REPORTS + TestBot.SETTINGS_BACKUP), "копия настроек убрана")
			check(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(AutoScenario.ACCOUNTS + "accounts"))
				and not FileAccess.file_exists(AutoScenario.ACCOUNTS + "accounts.json"), "аккаунты автотестов стёрты")
			check(not Handheld.force_missing and CreatureAsset.use_assets and not Assets.force_missing,
				"подмены тестов сняты")
			Assets.plugin_override = null
			_restore_settings_file()
			ok_done()


func _on_main_changed(n: Node) -> void:
	main = n


func _on_finished(r: Dictionary) -> void:
	_result = r


func _start_run() -> void:
	_run += 1
	_result = {}
	var err := TestBot.start(main, "test", {"scenario": ShortScenario.new(), "report_dir": BOT_REPORTS, "warmup": 0.3,
		"poll": 0.25, "cool_min": 0.5, "cool_max": 30.0, "status_source": func() -> int: return _status,
		"headroom_source": func() -> int: return _headroom})
	check(err == "", "запуск %d: бот запущен %s" % [_run, err])
	_bot = TestBot.current
	check(_bot != null and TestBot.is_running(), "запуск %d: TestBot.current" % _run)
	main = _bot.main
	_bot.main_changed.connect(_on_main_changed)
	_bot.finished.connect(_on_finished)
	# Переключение: своё хранилище, тестовый герой, сохранение игрока не тронуто
	check(Accounts.dir == TestBot.STORAGE and Accounts.current == TestBot.BOT_LOGIN, "запуск %d: хранилище бота %s, %s"
		% [_run, Accounts.dir, Accounts.current])
	check(game.char_name == TestBot.BOT_NICK and game.class_id == "wizard" and game.level == 20 and game.slot == 0,
		"запуск %d: тестовый герой — Волшебник 20 ур. (%s, %s, %d)" % [_run, game.char_name, game.class_id, game.level])
	check(ThermalGuard.suspended, "запуск %d: авто-снижение на время теста выключено" % _run)
	check(_slot_key(FileAccess.get_file_as_string(TEST_ACCOUNTS + "accounts/dedok_max/slot1.json")) == _slot_key(_home_slot),
		"запуск %d: сохранение игрока не изменилось" % _run)
	check(FileAccess.file_exists(BOT_REPORTS + TestBot.RUNNING), "запуск %d: метка «идёт тест»" % _run)
	check(TestBot.start(main, "test", {"scenario": ShortScenario.new()}) != "", "второй бот не запускается")


## Главное в сохранении героя: ник, раса, профессия, уровень, опыт, золото.
func _slot_key(json: String) -> String:
	var v: Variant = JSON.parse_string(json)
	if not (v is Dictionary):
		return "?"
	var d: Dictionary = v
	return "%s|%s|%s|%s|%s|%s" % [d.get("name", ""), d.get("race", ""), d.get("class", ""), d.get("level", ""),
		d.get("xp", ""), d.get("gold", "")]


func _home_ready() -> bool:
	return main != null and is_instance_valid(main) and main.is_inside_tree() and main._started and TestBot.current == null


## Игрок снова в своём аккаунте, слоте и мире; тестовое хранилище стёрто; графика и авто-снижение — как были.
func _check_home(what: String) -> void:
	check(Accounts.dir == TEST_ACCOUNTS and Accounts.current == "Dedok_max", "%s: аккаунт игрока (%s, %s)" % [what,
		Accounts.dir, Accounts.current])
	check(game.slot == 0 and game.char_name == "Тест" and game.class_id == "warrior" and game.level == 1,
		"%s: герой игрока «%s» (%s, %d ур.) в слоте %d" % [what, game.char_name, game.class_id, game.level, game.slot + 1])
	check(main.player != null and is_instance_valid(main.player), "%s: мир игрока" % what)
	check(not FileAccess.file_exists(TestBot.STORAGE + "accounts.json") and not DirAccess.dir_exists_absolute(
		ProjectSettings.globalize_path(TestBot.STORAGE + "accounts")), "%s: тестовое хранилище стёрто" % what)
	check(not ThermalGuard.suspended and Quality.throttle_level() == 0, "%s: авто-снижение снова работает" % what)
	check(not AdminPanel.god, "%s: бессмертие бота снято" % what)
	check(not get_tree().paused and not get_tree().root.disable_3d, "%s: игра не на паузе" % what)
	var settings := FileAccess.get_file_as_string(Quality.PATH) if FileAccess.file_exists(Quality.PATH) else ""
	check(settings == _settings_before, "%s: settings.cfg не тронут" % what)
	check(not FileAccess.file_exists(BOT_REPORTS + TestBot.RUNNING), "%s: метка «идёт тест» убрана" % what)
	check(_slot_key(FileAccess.get_file_as_string(Accounts.slot_path(0))) == _slot_key(_home_slot), "%s: слот 1 — «Тест», как был"
		% what)


## Вкладка «Тест-бот» — только у администратора.
func _check_admin_only() -> void:
	AdminPanel.open(main, "bot")
	check(main.hud.is_window_open() and AdminPanel.tab == "bot" and AdminPanel.buttons.has("tab_bot"), "вкладка «Тест-бот»")
	for k in ["bot_start", "bot_stop", "bot_open", "bot_share", "bot_mode_perf", "bot_mode_quick", "bot_mode_full",
			"bot_mode_sections"]:
		check(AdminPanel.buttons.has(k), "кнопка %s" % k)
	check(not (AdminPanel.buttons["bot_mode_perf"] as Button).disabled, "режим «Производительность» доступен")
	check(AdminPanel.buttons.has("bot_mode_autotests") and not (AdminPanel.buttons["bot_mode_autotests"] as Button).disabled
		and not (AdminPanel.buttons["bot_mode_autotests_quick"] as Button).disabled, "режимы «Автотесты» доступны")
	check((AdminPanel.buttons["bot_mode_quick"] as Button).disabled and (AdminPanel.buttons["bot_mode_full"] as Button).disabled,
		"«Быстрый» и «Полный» — скоро")
	check((AdminPanel.buttons["bot_stop"] as Button).disabled, "«Стоп» недоступна, пока бот не идёт")
	main.hud.close_window()
	# Другой логин: ни панели, ни запуска
	Accounts.current = "Igrok"
	check(not AdminPanel.enabled(), "у логина Igrok админ-панели нет")
	AdminPanel.open(main, "bot")
	check(not main.hud.is_window_open(), "у логина Igrok вкладка «Тест-бот» не открывается")
	check(TestBot.start(main, "perf") != "" and not TestBot.is_running(), "у логина Igrok бот не запускается")
	Accounts.current = "Dedok_max"
	check(BotScenario.create("perf") != null and BotScenario.create("quick") == null, "сценарии: perf есть, quick — скоро")
	check(BotScenario.create("perf").limit() == 720.0, "лимит «Производительности» — 12 мин")


func _check_units() -> void:
	var ver := BotReport.version()
	check(ver == (Assets.game_version() if Assets.game_version() != "" else "dev"), "версия отчёта: %s" % ver)
	var base := BotReport.file_base({"year": 2026, "month": 11, "day": 1, "hour": 9, "minute": 5})
	check(base == "DarkPact_test_%s_2026-11-01_09-05" % ver, "имя отчёта: %s" % base)
	check(BotReport.slug("Город Тени: Выкл") == "gorod_teni_vykl", "транслитерация снимка: %s" % BotReport.slug("Город Тени: Выкл"))
	var m := BotMetrics.new()
	m.begin(null)
	for i in 90:
		m.frame(0.010)
	for i in 10:
		m.frame(0.150)
	var r := m.finish()
	check(int(r["frames"]) == 100 and int(r["hitches"]) == 10, "метрики: кадров %d, заминок %d" % [int(r["frames"]),
		int(r["hitches"])])
	check(absf(float(r["ms"]) - 24.0) < 0.01 and absf(float(r["fps"]) - 1000.0 / 24.0) < 0.05,
		"метрики: среднее %.2f мс, %.2f к/с" % [float(r["ms"]), float(r["fps"])])
	check(absf(float(r["p50"]) - 10.0) < 0.01 and absf(float(r["p95"]) - 150.0) < 0.01 and absf(float(r["max"]) - 150.0) < 0.01,
		"метрики: p50 %.1f, p95 %.1f, макс %.1f" % [float(r["p50"]), float(r["p95"]), float(r["max"])])
	check(float(r["fps_min"]) < float(r["fps"]), "метрики: худшая секунда %.1f к/с" % float(r["fps_min"]))


## Отчёт запуска 1: имя, разделы, zip со снимками, копии в «Загрузки».
func _check_report_done() -> void:
	check(String(_result["kind"]) == "done", "итог запуска 1 — «готово» (%s: %s)" % [String(_result["kind"]),
		String(_result.get("reason", ""))])
	var txt := String(_result["txt"])
	var zip := String(_result["zip"])
	var re := RegEx.create_from_string("^DarkPact_test_[0-9A-Za-z.\\-]+_\\d{4}-\\d{2}-\\d{2}_\\d{2}-\\d{2}\\.txt$")
	check(re.search(txt.get_file()) != null and txt.get_file().begins_with("DarkPact_test_" + BotReport.version() + "_"),
		"имя отчёта: %s" % txt.get_file())
	check(FileAccess.file_exists(txt) and zip == txt.get_basename() + ".zip" and FileAccess.file_exists(zip),
		"отчёт .txt и .zip записаны (%s)" % zip)
	var text := FileAccess.get_file_as_string(txt)
	for part in ["Dark Pact — отчёт тест-бота", "Режим: test", "Итог: готово", "Замеров: 3 из 3", "Версия игры:",
			"Длительность:", "Пауз на остывание: 1", "Устройство", "Test Phone X", "Android 14 (API 34)", "Fake SoC 9",
			"Видеочип:", "Рендерер:", "Рендерер подробно:", "в настройках проекта rendering_method «gl_compatibility»",
			"Файл рендерера user://", "Состояние user://", "Плагин vulkanSupported:", "Журнал рендерера",
			"Процессор: ", "arm64-v8a · чип Fake SoC 9", "Память: ОЗУ 11.6 ГБ, свободно 4.1 ГБ",
			"Прошлый запуск игры закончился: user_requested", "батарея 31.2 °C", "Пресеты (среднее по сценам)", "Замеры (прогрев",
			"Настройки по одной на «Среднем»", "Тени: Выкл", "Рекомендации", "Раздел сценария: проверка каркаса",
			"Журнал", "Пауза на остывание: статус температуры 2", "Остыл за", "Проверки: ", "[OK] зверь поставлен",
			"Лог Godot", "Герой игрока «Тест» сохранён"]:
		check(text.contains(part), "отчёт содержит «%s»" % part)
	check(not text.contains("ОШИБКА"), "в отчёте нет ошибок проверок")
	check(not text.contains("Процессор: ,") and not text.contains("всего -0.0") and not text.contains("статическая 0 МБ"),
		"нет пустого имени процессора и нулевой памяти")
	check(int(_result["rows"]) == 3 and _bot.rows.size() == 3, "три строки замеров")
	var row: Dictionary = _bot.rows[0]
	var m: Dictionary = row["m"]
	check(int(m["frames"]) >= 50 and float(m["fps"]) > 0.0 and String(row["scene"]) == "Город", "замер 1: кадров %d"
		% int(m["frames"]))
	check(int((row["t0"] as Dictionary)["status"]) == 0 and float((row["t0"] as Dictionary)["battery"]) > 31.0,
		"замер 1: температура до — статус 0, батарея из плагина")
	# Архив: отчёт и снимки
	var zr := ZIPReader.new()
	check(zr.open(zip) == OK, "архив открывается")
	var files := zr.get_files()
	var jpgs := 0
	for f in files:
		if String(f).begins_with("shots/") and String(f).ends_with(".jpg"):
			jpgs += 1
	check(files.has(txt.get_file()) and jpgs == 3, "в архиве отчёт и 3 снимка: %s" % ", ".join(files))
	check(zr.read_file(txt.get_file()).get_string_from_utf8() == text, "отчёт в архиве — тот же")
	zr.close()
	# «Загрузки/DarkPact_test» — через плагин
	var names: Array = []
	for s in _fake.saved:
		var a: Array = s
		check(String(a[1]) == TestBot.PUBLIC_DIR, "в общую папку %s" % String(a[1]))
		names.append(String(a[2]))
	check(names.has(zip.get_file()) and names.has(txt.get_file()), "в «Загрузки» — .zip и .txt: %s" % ", ".join(names))
	check(String(_result["public"]) == "Загрузки/DarkPact_test/" + zip.get_file() and String(_result["uri"]).begins_with("content://"),
		"итог: %s" % String(_result["message"]))
	check(FileAccess.file_exists("user://test_downloads/" + zip.get_file()), "копия архива в «Загрузках»")


## «Открыть отчёт» и «Поделиться» на вкладке — через плагин.
func _check_tab_buttons() -> void:
	AdminPanel.open(main, "bot")
	check(not (AdminPanel.buttons["bot_open"] as Button).disabled and not (AdminPanel.buttons["bot_start"] as Button).disabled,
		"после теста: «Открыть отчёт» и «Начать» доступны")
	(AdminPanel.buttons["bot_share"] as Button).pressed.emit()
	check(_fake.shared.size() == 1 and String(_fake.shared[0][0]).ends_with(".zip")
		and String(_fake.shared[0][1]) == "application/zip", "«Поделиться» — архив через плагин")
	(AdminPanel.buttons["bot_open"] as Button).pressed.emit()
	check(_fake.opened.size() == 1 and String(_fake.opened[0][0]).ends_with(".txt"), "«Открыть отчёт» — .txt через плагин")
	main.hud.close_window()


## Прошлый запуск не закончился: предупреждение в начале отчёта, причина по данным Android, раздел завершений.
func _check_interrupted(text: String) -> void:
	var head := text.substr(0, 1200)
	check(head.contains("!!! ВНИМАНИЕ: прошлый запуск тест-бота (2026-11-01 18:00, режим «Автотесты на телефоне (все)»)"),
		"отчёт начинается с предупреждения о незаконченном запуске")
	check(head.contains("!!! Бот был на шаге: test_combat"), "предупреждение: шаг бота")
	check(head.contains("!!! СБОЙ — по данным Android: 2026-11-01 18:05:00 · сбой движка (native) [crash_native], статус 6"),
		"предупреждение: причина — crash_native после начала прошлого запуска")
	check(text.find("!!! ВНИМАНИЕ") < text.find("Режим:"), "предупреждение — до сводки")
	for part in ["Прошлые завершения игры", "1. 2026-11-01 18:30:00 · закрыта игроком или системой [user_requested]",
			"2. СБОЙ · 2026-11-01 18:05:00", "след (первые 2 строк):", "Abort message: 'test abort'",
			"3. СБОЙ · 2026-11-01 17:00:00 · зависание (ANR) [anr]", "\"main\" prio=5 tid=1 Native", "Сбоев среди них: 2"]:
		check(text.contains(part), "раздел завершений: «%s»" % part)
	var ex := BotReport.exit_history()
	check(bool(ex["ok"]) and (ex["exits"] as Array).size() == 3, "exit_history: 3 записи")
	check(String(BotReport.exit_after(ex["exits"], "2026-11-01 18:00").get("reason", "")) == "crash_native"
		and BotReport.exit_after(ex["exits"], "2026-11-02 00:00").is_empty(), "exit_after: первое завершение после метки")


## Игра упала посреди сценария, убравшего настройки: при запуске копия возвращается, метка помнит это.
func _check_recover() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RECOVER_DIR))
	var had := FileAccess.file_exists(Quality.PATH)
	var backup := ""
	if had:
		backup = RECOVER_DIR + TestBot.SETTINGS_BACKUP
		DirAccess.copy_absolute(ProjectSettings.globalize_path(Quality.PATH), ProjectSettings.globalize_path(backup))
	var f := FileAccess.open(RECOVER_DIR + TestBot.RUNNING, FileAccess.WRITE)
	f.store_string(JSON.stringify({"time": "2026-11-01 18:00", "mode": "autotests", "settings_backup": backup}))
	f.close()
	check(TestBot.recover_after_crash(RECOVER_DIR), "recover_after_crash: настройки возвращены из копии")
	check(FileAccess.file_exists(Quality.PATH) == had and (not had or FileAccess.get_file_as_string(Quality.PATH) == _settings_before)
		and not FileAccess.file_exists(RECOVER_DIR + TestBot.SETTINGS_BACKUP), "recover_after_crash: settings.cfg как был")
	var m: Variant = JSON.parse_string(FileAccess.get_file_as_string(RECOVER_DIR + TestBot.RUNNING))
	check(m is Dictionary and bool((m as Dictionary).get("settings_recovered", false))
		and not (m as Dictionary).has("settings_backup"), "метка: настройки возвращены")
	check(not TestBot.recover_after_crash(RECOVER_DIR), "второй раз — нечего возвращать")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RECOVER_DIR + TestBot.RUNNING))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RECOVER_DIR).trim_suffix("/"))


func _script(src: String) -> GDScript:
	var g := GDScript.new()
	g.source_code = src
	g.reload()
	return g


## Запуск 3: «Автотесты на телефоне» на своём списке.
func _start_autotests() -> void:
	_result = {}
	# Список тестов и «быстрые»
	var all := AutoScenario.list_tests()
	check(all.size() >= 50 and all[0] == "smoke_test" and all.has("test_combat") and all.has("test_bot")
		and not all.has("test_base"), "список автотестов: %d, первый %s" % [all.size(), all[0] if all.size() > 0 else "—"])
	var quick := BotScenario.create("autotests_quick")
	check(quick != null and quick.mode_key == "autotests_quick" and quick.limit() == 15.0 * 60.0
		and BotScenario.create("autotests").limit() == 75.0 * 60.0, "режимы автотестов: лимиты 75 и 15 мин")
	var qn := (quick as AutoScenario).test_names()
	check(qn.size() == AutoScenario.QUICK.size() and qn[0] == "smoke_test", "быстрые: все %d есть в tests/" % qn.size())
	# Настройки игрока: есть файл (UiScale «Крупный») — на время тестов его нет, потом он тот же
	UiScale.set_level(UiScale.LARGE)
	_settings_before = FileAccess.get_file_as_string(Quality.PATH)
	_auto = AutoScenario.new()
	_auto.only = PackedStringArray(["test_combat", "test_bot", "fake_fail", "fake_hang", "fake_plain"])
	_auto.scripts = {"fake_fail": _script(FAKE_FAIL), "fake_hang": _script(FAKE_HANG), "fake_plain": _script(FAKE_PLAIN)}
	_auto.timeouts = {"fake_hang": 3.0}
	var err := TestBot.start(main, "autotests", {"scenario": _auto, "report_dir": BOT_REPORTS, "poll": 0.25,
		"status_source": func() -> int: return 0, "headroom_source": func() -> int: return 400})
	check(err == "", "запуск 3: автотесты запущены %s" % err)
	_bot = TestBot.current
	main = _bot.main
	_bot.main_changed.connect(_on_main_changed)
	_bot.finished.connect(_on_finished)
	check(main == null, "главная сцена убрана на время автотестов")


func _check_autotests_report() -> void:
	check(String(_result["kind"]) == "done", "итог автотестов — «готово» (%s: %s)" % [String(_result["kind"]),
		String(_result.get("reason", ""))])
	var res: Array = _auto.results
	var got := PackedStringArray()
	for r in res:
		got.append("%s:%s" % [String(r["name"]), String(r["status"])])
	check(" ".join(got) == "test_combat:ok test_bot:skip fake_fail:fail fake_hang:timeout fake_plain:error",
		"итоги тестов: %s" % " ".join(got))
	var ff: Dictionary = res[2]
	check(String(ff["text"]).contains("нарочно не прошёл") and String(ff["text"]).ends_with("false"),
		"текст неудачи; settings.cfg на время тестов убран: %s" % String(ff["text"]))
	check(float(res[0]["sec"]) > 0.0 and int(res[0]["frames"]) > 10, "время и кадры теста: %.1f с, %d" % [float(res[0]["sec"]),
		int(res[0]["frames"])])
	var text := FileAccess.get_file_as_string(String(_result["txt"]))
	for part in ["Режим: Автотесты на телефоне (все)", "Автотесты: прошло 1, не прошло 3, пропущено 1 — из 5",
			"Проверок бота:", "Прошлые завершения игры", "\nАвтотесты\n", "test_combat", "прошёл", "НЕ ПРОШЁЛ", "ТАЙМАУТ",
			"ОШИБКА", "Автотесты: не прошли — подробно (3)", "fake_fail — НЕ ПРОШЁЛ: нарочно не прошёл",
			"fake_plain — ОШИБКА: тест не наследует tests/test_base.gd", "Автотесты: пропущены (1)",
			"test_bot — только CI: сам запускает тест-бота", "Автотест test_combat — прошёл"]:
		check(text.contains(part), "отчёт автотестов содержит «%s»" % part.strip_edges())
	check(not text.contains("Замеры (прогрев") and not text.contains("Рекомендации"), "без таблиц замеров")
	check(UiScale.level() == UiScale.LARGE, "размер интерфейса игрока вернулся")


## settings.cfg — как до теста (user:// общий у тестов одной задачи CI).
func _restore_settings_file() -> void:
	if _had_settings:
		var f := FileAccess.open(Quality.PATH, FileAccess.WRITE)
		f.store_string(_settings_orig)
		f.close()
	elif FileAccess.file_exists(Quality.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Quality.PATH))
	Quality.reload()
	UiScale.reload()
	Util.refresh_theme()
