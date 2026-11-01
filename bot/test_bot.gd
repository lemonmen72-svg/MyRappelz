class_name TestBot
extends Node
## Тест-бот на устройстве (задача Максима, этап 3 — каркас и режим «Производительность»; этап 4 — игровые сценарии).
## Запуск — админ-панель (только аккаунт Dedok_max) → вкладка «Тест-бот» → режим → «Начать» (TestBot.start).
##
## Как бот не трогает сохранения игрока: герой игрока сохраняется (Game.save_game) и забывается (Game.leave_slot),
## хранилище аккаунтов переключается на отдельную папку STORAGE (Accounts.use_storage, стирается — как у автотестов),
## там создаётся аккаунт BOT_LOGIN (администратор — для админ-функций) и тестовый герой сценария в слоте 1
## (BotScenario.hero), главная сцена запускается заново (main.restart_scene) — мир тестового героя. Графика
## меняется без записи в settings.cfg (Quality.set_level/set_option с save = false), в конце — Quality.reload().
## По окончании (готово, стоп, перегрев, лимит): отчёт (BotReport), тестовое хранилище стирается, хранилище и
## аккаунт игрока возвращаются, герой его слота загружается (Game.load_slot), сцена — заново: игрок снова в своём мире
## (героя нет — выбор персонажа). Бот — узел у корня дерева (переживает перезапуск сцены). Игру закрыли или она
## упала посреди теста — при следующем запуске всё как обычно (папка хранилища статическая и стоит по умолчанию,
## сохранение игрока записано до переключения); метка RUNNING в папке отчётов — запись в журнал следующего отчёта.
##
## Сценарий (BotScenario) ставит шаги в очередь (do / wait / wait_until / measure / tick — шапка bot_scenario.gd),
## шаги идут по порядку со своим временем (время игры, паузы не в счёт); «measure» — прогрев warmup с, затем замер
## (BotMetrics: к/с, кадр, процентили, вызовы, треугольники, память; температура до и после; снимок экрана JPG).
## Проверки check(cond, текст) и журнал note(текст) — в отчёт.
##
## Перегрев (условие Максима «бот не должен перегреть телефон»): авто-снижение ThermalGuard на время теста
## выключено (ThermalGuard.suspended — иначе оно испортит замер), бот сам раз в poll с читает статус температуры
## Android (плагин MyRappelzDownload: thermalStatus, thermalHeadroom; батарея — batteryTemp):
## - статус ≥ STATUS_STOP (SEVERE) — остановка: «Тест остановлен: телефон перегрелся», отчёт;
## - статус ≥ STATUS_HOT (MODERATE) или запас ≥ HEADROOM_HOT ‰ — пауза «остывание»: дерево на паузе, 3D-мир не
##   рисуется (Viewport.disable_3d), предел COOL_FPS кадров/с, тёмный экран BotOverlay; ждёт статус ≤ LIGHT и запас
##   ≤ HEADROOM_COOL (не меньше cool_min с, не больше cool_max с); замер, прерванный паузой, — заново (один раз);
##   все паузы дольше cool_total с — остановка;
## - нет данных о температуре (ПК, Android < 10, нет плагина) — по времени кадра: среднее дольше FRAME_HOT с
##   FRAME_HOT_TIME с подряд — пауза FRAME_COOL с;
## - лимит активного времени режима (BotScenario.limit, «Производительность» — 12 мин) и общий (+ HARD_EXTRA).
##
## Отчёт — BotReport: DarkPact_test_<версия>_<ГГГГ-ММ-ДД_ЧЧ-ММ>.txt и .zip (отчёт + снимки) в REPORT_DIR, на Android —
## копия в «Загрузки/DarkPact_test» (MediaStore через плагин), «Открыть отчёт» и «Поделиться» (плагин), на ПК —
## папка user://bot_reports. Итог последнего запуска — last (и LAST_FILE): вкладка «Тест-бот».

signal main_changed(new_main: Node)
signal finished(result: Dictionary)

const STORAGE := "user://bot_accounts/"
const REPORT_DIR := "user://bot_reports/"
const PUBLIC_DIR := "Download/DarkPact_test/"
const BOT_LOGIN := "Dedok_max"
const BOT_NICK := "ТестБот"
const RUNNING := "running.json"
const LAST_FILE := "last.json"
## Статусы PowerManager.THERMAL_STATUS_* (как ThermalGuard).
const STATUS_COOL := 1
const STATUS_HOT := 2
const STATUS_STOP := 3
const STATUS_NAMES := ["нет нагрева", "лёгкий", "умеренный", "сильный", "критический", "аварийный", "отключение"]
## Прогноз запаса до троттлинга, ‰: горячо / остыл.
const HEADROOM_HOT := 950
const HEADROOM_COOL := 800
const POLL := 2.0
const WARMUP := 3.0
const COOL_MIN := 20.0
const COOL_MAX := 180.0
const COOL_TOTAL := 480.0
const COOL_FPS := 10
## Без данных о температуре: среднее время кадра (EMA за FRAME_TAU с) дольше FRAME_HOT с FRAME_HOT_TIME с подряд.
const FRAME_HOT := 0.2
const FRAME_HOT_TIME := 10.0
const FRAME_TAU := 2.0
const FRAME_COOL := 60.0
## Общий лимит = активный + HARD_EXTRA (паузы, загрузка мира).
const HARD_EXTRA := 600.0
## Мир тестового героя: ждать не дольше, с; после готовности — ещё SETTLE с.
const WORLD_TIMEOUT := 180.0
const SETTLE := 1.0
## Снимок: ширина, качество JPG.
const SHOT_W := 960
const SHOT_QUALITY := 0.7

## Идущий бот (null — нет).
static var current: TestBot = null
## Итог последнего запуска: {kind, text, time, txt, zip, public, uri, message}; {} — не читали (last_result()).
static var last: Dictionary = {}

var mode := ""
var scenario: BotScenario
## Главная сцена (меняется при перезапуске — сигнал main_changed).
var main: Node
## "prepare" (мир тестового героя грузится), "running", "cooling", "home" (вернули игрока, ждём его мир), "done".
var state := "idle"
## Итог: "done", "limit", "stopped" (игрок), "hot" (перегрев), "error"; текст — stop_reason.
var result_kind := ""
var stop_reason := ""
var storage := STORAGE
var report_dir := REPORT_DIR
var warmup := WARMUP
var poll := POLL
var cool_min := COOL_MIN
var cool_max := COOL_MAX
var cool_total := COOL_TOTAL
var limit := 720.0
## Источники температуры (тест): статус, запас ‰, батарея °C. Пусто — плагин.
var status_source: Callable
var headroom_source: Callable
var battery_source: Callable
## Пауза по времени кадра без данных о температуре (выкл в headless).
var frame_guard := true
## Нет картинки кадра (headless) — снимок-заглушка (тест: zip со снимками).
var placeholder_shots := false

## Отчёт: строки замеров, журнал, проверки, паузы, снимки, устройство, температура в начале и в конце.
var rows: Array[Dictionary] = []
var journal: PackedStringArray = PackedStringArray()
var checks: Array[Dictionary] = []
var pauses: Array[Dictionary] = []
var shots: PackedStringArray = PackedStringArray()
var device: Dictionary = {}
var temp_start: Dictionary = {}
var temp_end: Dictionary = {}
## Графика игрока до теста (пресет, кадры/с) и прошлый незаконченный запуск (RUNNING) — для отчёта.
var player_quality := ""
var interrupted_before: Dictionary = {}
var base_name := ""
var run_dir := ""
var started_text := ""
## Время: всё (с паузами) и активное (сценарий), с.
var total_time := 0.0
var active_time := 0.0
var cool_time := 0.0
var steps_total := 0
var measures_total := 0
## Отметка в логе Godot (хвост лога в отчёте — с неё).
var log_mark := ""

var overlay: BotOverlay
var _home: Dictionary = {}
var _steps: Array[Dictionary] = []
var _si := 0
var _t := 0.0
var _phase := 0
var _tick_fn: Callable
var _metrics := BotMetrics.new()
var _before: Dictionary = {}
var _spawned: Array = []
var _status := -1
var _headroom := -1
var _poll_t := 0.0
var _poll_at := -1.0e9
var _cool_t := 0.0
var _cool_reason := ""
var _frame_avg := 0.0
var _frame_slow := 0.0
var _last_us := 0
var _wait_t := 0.0
var _retries: Dictionary = {}
var _no_plugin: Dictionary = {}
var _headless := false
var _app_away := false


func _init() -> void:
	name = "TestBot"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_headless = DisplayServer.get_name() == "headless"
	placeholder_shots = _headless
	frame_guard = not _headless


# ---------- Запуск и состояние (вкладка «Тест-бот») ----------

## Запустить режим mode_id (BotScenario.MODES) из мира main_node. "" — запущен, иначе причина.
## opts (тесты): scenario (свой BotScenario), storage, report_dir, warmup, poll, cool_min, cool_max, cool_total, limit,
## status_source, headroom_source, battery_source, frame_guard.
static func start(main_node: Node, mode_id: String, opts: Dictionary = {}) -> String:
	if not AdminPanel.enabled():
		return "Тест-бот доступен только администратору"
	if is_running():
		return "Тест-бот уже идёт"
	if main_node == null or not is_instance_valid(main_node) or not main_node.has_method("restart_scene") \
			or main_node.get("player") == null or not main_node.is_inside_tree():
		return "Тест-бот запускается из мира"
	if not Game.has_character or not Accounts.is_logged_in():
		return "Сначала войдите в мир своим героем"
	var sc: BotScenario = opts.get("scenario", null) as BotScenario
	if sc == null:
		sc = BotScenario.create(mode_id)
	if sc == null:
		return "Режим «%s» пока недоступен" % BotScenario.mode_name(mode_id)
	var st := String(opts.get("storage", STORAGE))
	if not st.ends_with("/"):
		st += "/"
	if st == Accounts.dir or st == Accounts.DEFAULT_DIR:
		return "Хранилище бота совпадает с хранилищем игрока"
	var bot := TestBot.new()
	bot.mode = mode_id
	bot.scenario = sc
	bot.storage = st
	bot.report_dir = String(opts.get("report_dir", REPORT_DIR))
	if not bot.report_dir.ends_with("/"):
		bot.report_dir += "/"
	bot.warmup = float(opts.get("warmup", WARMUP))
	bot.poll = float(opts.get("poll", POLL))
	bot.cool_min = float(opts.get("cool_min", COOL_MIN))
	bot.cool_max = float(opts.get("cool_max", COOL_MAX))
	bot.cool_total = float(opts.get("cool_total", COOL_TOTAL))
	bot.limit = float(opts.get("limit", sc.limit()))
	bot.status_source = opts.get("status_source", Callable())
	bot.headroom_source = opts.get("headroom_source", Callable())
	bot.battery_source = opts.get("battery_source", Callable())
	if opts.has("frame_guard"):
		bot.frame_guard = bool(opts["frame_guard"])
	bot.main = main_node
	main_node.get_tree().root.add_child(bot)
	bot._begin()
	return ""


static func is_running() -> bool:
	return current != null and is_instance_valid(current) and current.state != "done"


## Остановить идущий тест (кнопка «Стоп»): отчёт пишется, игрок возвращается.
static func stop_current(reason: String = "Остановлен вручную") -> void:
	if is_running():
		current.stop(reason, "stopped")


## Итог последнего запуска (из памяти или LAST_FILE).
static func last_result() -> Dictionary:
	if last.is_empty():
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(REPORT_DIR + LAST_FILE)) \
			if FileAccess.file_exists(REPORT_DIR + LAST_FILE) else null
		if v is Dictionary:
			last = v
	return last


## Строка состояния для вкладки «Тест-бот».
static func status_text() -> String:
	if is_running():
		var b := current
		match b.state:
			"prepare":
				return "идёт: загрузка мира тестового героя"
			"cooling":
				return "пауза на остывание телефона (%s)" % clock(b._cool_t)
			"home":
				return "готово, возвращаю вашего героя"
		return "идёт: %s (шаг %d из %d, %s)" % [b.step_name(), b._si + 1, b._steps.size(), clock(b.active_time)]
	var r := last_result()
	if r.is_empty():
		return "не запускался"
	return "%s — %s" % [String(r.get("time", "")), String(r.get("text", ""))]


static func clock(sec: float) -> String:
	var s := maxi(0, int(sec))
	return "%d:%02d" % [s / 60, s % 60]


# ---------- Переключение на тестового героя и обратно ----------

func _begin() -> void:
	current = self
	var now := Time.get_datetime_dict_from_system()
	started_text = "%04d-%02d-%02d %02d:%02d" % [int(now["year"]), int(now["month"]), int(now["day"]), int(now["hour"]),
		int(now["minute"])]
	base_name = BotReport.file_base(now)
	run_dir = report_dir + base_name + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(run_dir + "shots"))
	_read_marker()
	log_mark = "TestBot: старт %s %s" % [base_name, mode]
	print(log_mark)
	note("Старт: режим «%s» (%s), лимит %s" % [scenario.title(), BotScenario.mode_name(mode), clock(limit)])
	if not interrupted_before.is_empty():
		note("Прошлый запуск бота (%s) не завершился — игру закрыли или она упала; сохранения игрока не тронуты"
			% String(interrupted_before.get("time", "?")))
	device = BotReport.device_info()
	temp_start = read_temps(true)
	player_quality = "%s, %d к/с" % [Quality.level_name(), Quality.fps_limit()]
	# Дом игрока: хранилище, аккаунт, слот
	_home = {"dir": Accounts.dir, "login": Accounts.current, "slot": Game.slot, "nick": Game.char_name}
	_write_marker()
	var hud := main.get("hud") as HUD
	if hud != null:
		hud.close_window()
	Game.save_game()
	note("Герой игрока «%s» сохранён (аккаунт %s, слот %d)" % [Game.char_name, Accounts.current, Game.slot + 1])
	# Авто-снижение графики — выключено на время теста (бот сам следит за температурой)
	ThermalGuard.suspended = true
	if ThermalGuard.current != null and is_instance_valid(ThermalGuard.current):
		ThermalGuard.current.reset()
	Quality.set_throttle(0)
	# Мир бота строится на «Среднем» (густота травы — при постройке мира); без записи в settings.cfg
	Quality.set_level(Quality.MEDIUM, false)
	AdminPanel.reset_session()
	JobFxNeophyte.corpses.clear()
	Game.leave_slot()
	Accounts.use_storage(storage, true)
	var err := Accounts.create(BOT_LOGIN)
	if err != "":
		note("Тестовый аккаунт: " + err)
	var h := scenario.hero()
	Game.new_character(BOT_NICK, String(h.get("race", "human")), String(h.get("job", ClassData.WANDERER)),
		String(h.get("gender", "f")))
	var lvl := int(h.get("level", 1))
	if lvl > 1:
		Game.level = lvl
		Game.hero["jp"] = HeroSkills.default_jp(lvl)
	Game.enter_slot(0)
	Game.save_game()
	AdminPanel.god = true
	note("Тестовый герой: %s, %s, %d ур. (отдельное хранилище %s)" % [ClassData.job_name(Game.class_id),
		String(ClassData.race(Game.race_id).get("name", Game.race_id)), Game.level, storage])
	overlay = BotOverlay.new()
	add_child(overlay)
	overlay.stop_pressed.connect(func() -> void: stop("Остановлен кнопкой «Стоп»", "stopped"))
	state = "prepare"
	_wait_t = 0.0
	_swap_scene()


## Главная сцена заново (с тем, что сейчас в Game и Accounts).
func _swap_scene() -> void:
	var fresh: Node = main.call("restart_scene")
	main = fresh
	main_changed.emit(fresh)


func _world_ready() -> bool:
	return main != null and is_instance_valid(main) and main.is_inside_tree() and bool(main.get("_started"))


## Вернуть игрока: стереть тестовое хранилище, войти в аккаунт игрока, загрузить героя его слота, сцену заново.
func _return_home() -> void:
	clear_spawned()
	_tick_fn = Callable()
	AdminPanel.reset_session()
	JobFxNeophyte.corpses.clear()
	Game.leave_slot()
	Accounts.use_storage(storage, true)
	Accounts.use_storage(String(_home.get("dir", Accounts.DEFAULT_DIR)))
	var login := String(_home.get("login", ""))
	var sl := int(_home.get("slot", -1))
	if login != "" and Accounts.login(login) == "":
		if sl >= 0 and not Game.load_slot(sl):
			note("Не удалось загрузить героя игрока (слот %d) — откроется выбор персонажа" % (sl + 1))
	ThermalGuard.suspended = false
	Quality.reload()
	Quality.set_throttle(0)
	_remove_marker()
	state = "home"
	_wait_t = 0.0
	_swap_scene()


# ---------- Ход теста ----------

func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	var fdt := delta
	if _last_us > 0:
		fdt = float(now - _last_us) / 1000000.0
	_last_us = now
	match state:
		"prepare":
			_tick_prepare(delta)
		"running":
			_tick_running(delta, fdt)
		"cooling":
			_tick_cooling(delta)
		"home":
			_tick_home(delta)
	_update_overlay()


func _tick_prepare(dt: float) -> void:
	total_time += dt
	_wait_t += dt
	if _wait_t > WORLD_TIMEOUT:
		stop("Мир тестового героя не загрузился за %s" % clock(WORLD_TIMEOUT), "error")
		return
	if not _world_ready():
		return
	if _wait_t < SETTLE:
		return
	_wait_t = 0.0
	# Не первый кадр готовности: SETTLE с после постройки мира
	state = "running"
	note("Мир тестового героя готов (%s)" % clock(total_time))
	scenario.build(self)
	steps_total = _steps.size()
	for s in _steps:
		if String(s["kind"]) == "measure":
			measures_total += 1


func _tick_running(dt: float, fdt: float) -> void:
	total_time += dt
	active_time += dt
	if not _world_ready():
		stop("Главная сцена пропала", "error")
		return
	_watch(dt, fdt)
	if state != "running":
		return
	if active_time >= limit:
		stop("Лимит времени режима (%s): сделано замеров %d из %d" % [clock(limit), rows.size(), measures_total], "limit")
		return
	if total_time >= limit + HARD_EXTRA:
		stop("Общий лимит времени (%s)" % clock(limit + HARD_EXTRA), "limit")
		return
	if _tick_fn.is_valid():
		_tick_fn.call(dt)
	_run_step(dt, fdt)


func _tick_home(dt: float) -> void:
	_wait_t += dt
	var home_ok := main != null and is_instance_valid(main) and main.is_inside_tree() \
		and (bool(main.get("_started")) or main.get("screen") != null)
	if not home_ok and _wait_t < WORLD_TIMEOUT:
		return
	if home_ok:
		var hud := main.get("hud") as HUD
		if hud != null and is_instance_valid(hud):
			hud.show_message("Тест-бот: %s. %s" % [String(last.get("text", "")), String(last.get("message", ""))], 10.0)
	state = "done"
	if current == self:
		current = null
	queue_free()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			_app_away = true
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			if _app_away and state == "running" and _measuring():
				note("Игра была свёрнута — замер «%s» заново" % step_name())
				_restart_step()
			_app_away = false
			_last_us = 0


## Сейчас идёт шаг замера.
func _measuring() -> bool:
	return _si < _steps.size() and String(_steps[_si]["kind"]) == "measure"


func step_name() -> String:
	if _si >= _steps.size():
		return "конец"
	return String(_steps[_si].get("name", ""))


func _run_step(dt: float, fdt: float) -> void:
	if _si >= _steps.size():
		_finish("done", "готово: замеров %d из %d" % [rows.size(), measures_total])
		return
	var s: Dictionary = _steps[_si]
	_t += dt
	match String(s["kind"]):
		"do":
			var fn: Callable = s["fn"]
			if fn.is_valid():
				fn.call()
			_next()
		"wait":
			if _t >= float(s["sec"]):
				_next()
		"until":
			var cond: Callable = s["fn"]
			if cond.is_valid() and bool(cond.call()):
				_next()
			elif _t >= float(s["sec"]):
				check(false, "не дождался: %s (%s)" % [String(s["name"]), clock(float(s["sec"]))])
				_next()
		"tick":
			_tick_fn = s["fn"]
			_next()
		"measure":
			_measure(s, fdt)


func _next() -> void:
	_si += 1
	_t = 0.0
	_phase = 0


## Шаг замера с начала (прерван остыванием или сворачиванием игры).
func _restart_step() -> void:
	_t = 0.0
	_phase = 0


## Замер: фаза 0 — настройки графики, 1 — прогрев warmup с, 2 — замер sec с; затем строка отчёта и снимок.
func _measure(s: Dictionary, fdt: float) -> void:
	var o: Dictionary = s["opts"]
	var tick: Callable = o.get("tick", Callable())
	if tick.is_valid():
		tick.call(get_process_delta_time())
	if _phase == 0:
		if o.has("preset"):
			Quality.set_level(int(o["preset"]), false)
		if o.has("option"):
			var op: Array = o["option"]
			Quality.set_option(String(op[0]), int(op[1]), false)
		if o.has("preset") or o.has("option"):
			Quality.apply(get_tree())
		_phase = 1
		_t = 0.0
		return
	if _phase == 1:
		if _t < warmup:
			return
		_phase = 2
		_t = 0.0
		_before = read_temps()
		_metrics.begin(get_viewport())
		return
	_metrics.frame(fdt)
	if _t < float(s["sec"]):
		return
	var m := _metrics.finish()
	var row := {"scene": String(o.get("scene", "")), "setting": String(o.get("setting", "")),
		"kind": String(o.get("kind", "")), "base": bool(o.get("base", false)), "preset": Quality.level_name(),
		"cap": Quality.current_fps_cap(), "m": m, "t0": _before, "t1": read_temps(), "shot": "",
		"retry": int(_retries.get(_si, 0))}
	if bool(o.get("shot", true)):
		row["shot"] = shot(String(o.get("scene", "")) + " " + String(o.get("setting", "")))
	rows.append(row)
	note("Замер «%s · %s»: %.1f к/с (худшая секунда %.1f), кадр %.1f мс, p95 %.1f мс, вызовов %d" % [
		String(row["scene"]), String(row["setting"]), float(m["fps"]), float(m["fps_min"]), float(m["ms"]),
		float(m["p95"]), int(m["draw"])])
	_next()


# ---------- Температура ----------

## Статус температуры (−1 — неизвестно).
func thermal_status() -> int:
	if status_source.is_valid():
		return int(status_source.call())
	return _plugin_int("thermalStatus")


## Прогноз запаса, ‰ (−1 — неизвестно).
func thermal_headroom() -> int:
	if headroom_source.is_valid():
		return int(headroom_source.call())
	return _plugin_int("thermalHeadroom")


## Температура батареи, °C (−1 — неизвестно).
func battery_temp() -> float:
	if battery_source.is_valid():
		return float(battery_source.call())
	var v := _plugin_int("batteryTemp")
	return float(v) / 10.0 if v > 0 else -1.0


## {status, headroom, battery}; fresh — спросить сейчас (иначе запас — из последнего опроса, если он моложе 1.2 с:
## getThermalHeadroom чаще раза в секунду не отвечает).
func read_temps(fresh: bool = false) -> Dictionary:
	var now := float(Time.get_ticks_msec()) / 1000.0
	if fresh or now - _poll_at >= 1.2:
		_status = thermal_status()
		_headroom = thermal_headroom()
		_poll_at = now
	return {"status": _status, "headroom": _headroom, "battery": battery_temp()}


## Целое из метода плагина (нет плагина или метода в старом AAR — −1, больше не спрашиваем).
func _plugin_int(method: String) -> int:
	if _no_plugin.has(method):
		return -1
	var v: Variant = BotReport.plugin_call(method, [])
	if typeof(v) != TYPE_INT:
		_no_plugin[method] = true
		return -1
	return int(v)


## Слежение за нагревом во время сценария.
func _watch(dt: float, fdt: float) -> void:
	_poll_t -= dt
	if _poll_t <= 0.0:
		_poll_t = poll
		read_temps(true)
	if _status >= STATUS_STOP:
		stop("Тест остановлен: телефон перегрелся (статус температуры %d — %s)" % [_status, status_name(_status)], "hot")
		return
	if _status >= STATUS_HOT or _headroom >= HEADROOM_HOT:
		_begin_cooling("thermal")
		return
	# Без данных о температуре — по времени кадра (смены настроек и загрузки — короткие заминки, не в счёт)
	if frame_guard and _status < 0 and _headroom < 0:
		var k := 1.0 - exp(-dt / FRAME_TAU)
		_frame_avg = lerpf(_frame_avg if _frame_avg > 0.0 else fdt, clampf(fdt, 0.0, 1.0), k)
		_frame_slow = _frame_slow + dt if _frame_avg > FRAME_HOT else 0.0
		if _frame_slow >= FRAME_HOT_TIME:
			_begin_cooling("frames")


static func status_name(st: int) -> String:
	if st < 0:
		return "неизвестно"
	return String(STATUS_NAMES[clampi(st, 0, STATUS_NAMES.size() - 1)])


func _begin_cooling(reason: String) -> void:
	state = "cooling"
	_cool_t = 0.0
	_cool_reason = reason
	_frame_slow = 0.0
	_frame_avg = 0.0
	var why := "статус температуры %d (%s), запас %s" % [_status, status_name(_status), BotReport.headroom_text(_headroom)] \
		if reason == "thermal" else "кадр дольше %d мс (данных о температуре нет)" % int(FRAME_HOT * 1000.0)
	pauses.append({"at": active_time, "sec": 0.0, "reason": why, "step": step_name()})
	note("Пауза на остывание: %s (шаг «%s»)" % [why, step_name()])
	# Замер, прерванный паузой, — заново (второй раз прерван — пропускается)
	if _measuring():
		if reason == "thermal" and int(_retries.get(_si, 0)) < 1:
			_retries[_si] = int(_retries.get(_si, 0)) + 1
			_restart_step()
		else:
			note("Замер «%s» пропущен: прерван остыванием" % step_name())
			_next()
	get_tree().paused = true
	get_tree().root.disable_3d = true
	if not _headless:
		Engine.max_fps = COOL_FPS


func _tick_cooling(dt: float) -> void:
	total_time += dt
	cool_time += dt
	_cool_t += dt
	if not pauses.is_empty():
		pauses[pauses.size() - 1]["sec"] = _cool_t
	_poll_t -= dt
	if _poll_t <= 0.0:
		_poll_t = poll
		read_temps(true)
	if _status >= STATUS_STOP:
		stop("Тест остановлен: телефон перегрелся (статус температуры %d — %s)" % [_status, status_name(_status)], "hot")
		return
	if cool_time >= cool_total:
		stop("Тест остановлен: телефон слишком долго остывает (паузы %s)" % clock(cool_time), "hot")
		return
	var cool := _status <= STATUS_COOL and (_headroom < 0 or _headroom <= HEADROOM_COOL)
	if _cool_reason == "frames":
		cool = _cool_t >= FRAME_COOL
	if (cool and _cool_t >= cool_min) or _cool_t >= cool_max:
		if not cool:
			note("За %s не остыл (статус %d) — продолжаю" % [clock(cool_max), _status])
		else:
			note("Остыл за %s (статус %d, запас %s)" % [clock(_cool_t), _status, BotReport.headroom_text(_headroom)])
		_end_cooling()


func _end_cooling() -> void:
	get_tree().paused = false
	get_tree().root.disable_3d = false
	Quality.apply_fps()
	_last_us = 0
	if state == "cooling":
		state = "running"


## Остановить тест (кнопка, перегрев, лимит, ошибка): отчёт и возврат игрока.
func stop(reason: String, kind: String = "stopped") -> void:
	if state == "home" or state == "done" or result_kind != "":
		return
	note(reason)
	_finish(kind, reason)


func _finish(kind: String, text: String) -> void:
	if result_kind != "":
		return
	result_kind = kind
	stop_reason = text
	if state == "cooling":
		_end_cooling()
	get_tree().paused = false
	get_tree().root.disable_3d = false
	clear_spawned()
	temp_end = read_temps(true)
	var errors := 0
	for c in checks:
		if not bool(c["ok"]):
			errors += 1
	note("Конец: %s; проверок %d, ошибок %d" % [text, checks.size(), errors])
	var res := BotReport.export(self)
	last = res
	_save_last()
	finished.emit(res)
	_return_home()


# ---------- Очередь шагов (для сценариев) ----------

func do(step_title: String, fn: Callable) -> void:
	_steps.append({"kind": "do", "name": step_title, "fn": fn})


func wait(sec: float) -> void:
	_steps.append({"kind": "wait", "name": "пауза %.0f с" % sec, "sec": sec})


func wait_until(step_title: String, cond: Callable, timeout: float) -> void:
	_steps.append({"kind": "until", "name": step_title, "fn": cond, "sec": timeout})


## Вызывать fn(dt) каждый кадр (до следующего tick); Callable() — перестать.
func tick(fn: Callable) -> void:
	_steps.append({"kind": "tick", "name": "каждый кадр", "fn": fn})


## Замер sec с после прогрева warmup. opts: preset (Quality.LOW…ULTRA), option [ключ, значение] — графика перед
## прогревом; kind ("preset" / "setting"), base (база сравнения настроек), shot (снимок, по умолчанию да),
## tick Callable(dt) — каждый кадр шага (бой).
func measure(scene: String, setting: String, sec: float, opts: Dictionary = {}) -> void:
	var o := opts.duplicate()
	o["scene"] = scene
	o["setting"] = setting
	_steps.append({"kind": "measure", "name": "%s · %s" % [scene, setting], "sec": sec, "opts": o})


# ---------- API для сценариев ----------

func player() -> Player:
	if main == null or not is_instance_valid(main):
		return null
	return main.get("player") as Player


func check(ok: bool, text: String) -> bool:
	checks.append({"ok": ok, "text": text, "at": active_time})
	if not ok:
		note("ОШИБКА: " + text)
	return ok


func note(text: String) -> void:
	journal.append("[%s] %s" % [clock(total_time), text])
	print("TestBot: " + text)


## Перенести героя (и питомца) к точке острова c (AdminPanel.teleport — свободное ровное место рядом).
func teleport(c: Vector2, label: String = "") -> Vector3:
	return AdminPanel.teleport(main, c, label)


## Камера: поворот (0 — смотрим на север), наклон над горизонтом, расстояние.
func set_camera(yaw: float, pitch: float, dist: float) -> void:
	main.set("cam_yaw", yaw)
	main.set("cam_pitch", pitch)
	main.set("cam_dist", dist)


func reset_camera() -> void:
	set_camera(0.0, atan2(9.0, 8.5), 12.4)


## Точка на земле в dist м перед камерой (side — вбок, + вправо); непроходимо — ближайшая проходимая по кругу.
func ahead(dist: float, side: float = 0.0) -> Vector3:
	var p := player()
	var yaw := float(main.get("cam_yaw"))
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var base := p.global_position if p != null else Vector3.ZERO
	var q := base + fwd * dist + right * side
	var w := IslandWorld.current
	if w == null:
		return q
	if w.is_walkable(q.x, q.z):
		return w.ground(q.x, q.z)
	for k in 12:
		var r := (fwd * dist + right * side).rotated(Vector3.UP, TAU * float(k) / 12.0)
		var t := base + r
		if w.is_walkable(t.x, t.z):
			return w.ground(t.x, t.z)
	return w.ground(q.x, q.z)


func set_preset(l: int) -> void:
	Quality.set_level(l, false)
	Quality.apply(get_tree())


func set_option(key: String, value: int) -> void:
	Quality.set_option(key, value, false)
	Quality.apply(get_tree())


## Зверь вида type_id уровня lvl в точке pos (main.spawn_mob, не возрождается); убирается clear_spawned и в конце.
func spawn(type_id: String, lvl: int, pos: Vector3) -> Mob:
	var m := main.call("spawn_mob", type_id, lvl, pos, -1) as Mob
	if m != null:
		_spawned.append(m)
	return m


## Живые звери, поставленные ботом.
func spawned_alive() -> Array:
	var out: Array = []
	for v in _spawned:
		if is_instance_valid(v) and not (v as Mob).is_dead:
			out.append(v)
	return out


func clear_spawned() -> void:
	for v in _spawned:
		if is_instance_valid(v):
			(v as Node).queue_free()
	_spawned.clear()


func set_job(job: String) -> void:
	AdminPanel.set_job(main, job)


func set_level(lvl: int) -> void:
	AdminPanel.set_level(main, lvl)


func set_look(race: String, sex: String) -> void:
	AdminPanel.set_look(main, race, sex)


## Изучить все доступные умения (JP добавляются).
func learn_all() -> void:
	Game.hero["jp"] = int(Game.hero.get("jp", 0)) + 5000
	AdminPanel.learn_all(main)


func add_pet(species: String, lvl: int) -> void:
	AdminPanel.add_pet(main, species, lvl)


## Снимок экрана в папку запуска (JPG, ширина SHOT_W). Имя файла — номер и латиница из label. "" — не получился.
func shot(label: String) -> String:
	var fname := "%02d_%s.jpg" % [shots.size() + 1, BotReport.slug(label)]
	var img: Image = null
	if not _headless:
		var tex := get_viewport().get_texture()
		if tex != null:
			img = tex.get_image()
	if img == null or img.is_empty():
		if not placeholder_shots:
			note("Снимок «%s» не получился (нет картинки кадра)" % label)
			return ""
		img = Image.create(96, 54, false, Image.FORMAT_RGB8)
		img.fill(Color(0.12, 0.14, 0.18))
	else:
		if img.get_width() > SHOT_W:
			img.resize(SHOT_W, maxi(1, roundi(float(img.get_height()) * float(SHOT_W) / float(img.get_width()))),
				Image.INTERPOLATE_BILINEAR)
		if img.get_format() != Image.FORMAT_RGB8:
			img.convert(Image.FORMAT_RGB8)
	var err := img.save_jpg(run_dir + "shots/" + fname, SHOT_QUALITY)
	if err != OK:
		note("Снимок «%s» не записан (ошибка %d)" % [label, err])
		return ""
	shots.append(fname)
	return fname


# ---------- Экран, метка, итог ----------

func _update_overlay() -> void:
	if overlay == null or not is_instance_valid(overlay):
		return
	match state:
		"cooling":
			var p: Dictionary = pauses[pauses.size() - 1] if not pauses.is_empty() else {}
			overlay.show_cooling("Тест-бот на паузе: %s.\nЖду, пока телефон остынет (статус температуры 1 и ниже), "
				% String(p.get("reason", "")) + "не дольше %s. 3D-мир не рисуется, %d кадров/с." % [clock(cool_max), COOL_FPS],
				_cool_t)
		"prepare":
			overlay.show_running("Тест-бот: загрузка мира тестового героя…")
		"running":
			overlay.show_running("Тест-бот · %s · %d/%d · %s / %s" % [step_name(), mini(_si + 1, _steps.size()),
				_steps.size(), clock(active_time), clock(limit)])
		_:
			overlay.show_running("Тест-бот: пишу отчёт, возвращаю вашего героя…")


func _read_marker() -> void:
	var path := report_dir + RUNNING
	if not FileAccess.file_exists(path):
		return
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if v is Dictionary:
		interrupted_before = v


func _write_marker() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_dir))
	var f := FileAccess.open(report_dir + RUNNING, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"time": started_text, "mode": mode, "login": String(_home.get("login", "")),
		"slot": int(_home.get("slot", -1))}))
	f.close()


func _remove_marker() -> void:
	if FileAccess.file_exists(report_dir + RUNNING):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(report_dir + RUNNING))


func _save_last() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_dir))
	var f := FileAccess.open(report_dir + LAST_FILE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(last, "\t"))
		f.close()
