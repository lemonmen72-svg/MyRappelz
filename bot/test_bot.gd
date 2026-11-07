class_name TestBot
extends Node
## Тест-бот на устройстве (задача Максима, этап 3 — каркас и режим «Производительность»; этап 4 — игровые сценарии).
## Запуск — админ-панель (только аккаунт Dedok_max) → вкладка «Тест-бот» → режим → «Начать» (TestBot.start).
##
## Как бот не трогает сохранения игрока: герой игрока сохраняется (Game.save_game) и забывается (Game.leave_slot),
## хранилище аккаунтов переключается на отдельную папку STORAGE (Accounts.use_storage, стирается — как у автотестов),
## там создаётся аккаунт BOT_LOGIN (администратор — для админ-функций) и тестовый герой сценария в слоте 1
## (BotScenario.hero), главная сцена запускается заново (main.restart_scene) — мир тестового героя. Графика
## меняется без записи в settings.cfg (Quality.set_level/set_option с save = false), в конце — Quality.reread().
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
## Разделы (этап 4, игровые сценарии — BotSection): шаг section(id, название) открывает раздел — прежний закрывается
## (время), состояние между разделами возвращается (_reset_between_sections: окна закрыты, звери бота убраны, цель,
## джойстик, каст, бессмертие, HP/MP, камера), в лог Godot — строка-метка «===== Раздел «…» — начало» (ошибки лога
## в отчёте разносятся по разделам), проверки и снимки считаются по разделу (sections). Остановка посреди раздела —
## раздел «прерван», следующие — «не начат».
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
##
## Сценарий без мира (BotScenario.needs_world false — «Автотесты на телефоне»): главная сцена убирается до build,
## сценарий сам ставит сцены (owns_scene), в конце бот создаёт главную сцену заново. on_finish сценария — уборка при
## любом конце. Настройки игрока (settings.cfg) такой сценарий может убрать на время (backup_settings — копия в папке
## отчётов, путь — в метке RUNNING); игра упала посреди — recover_after_crash при следующем запуске (main._ready).
##
## Фон Android (фаза 5 Кардинала): свёрнутой игра на Android не работает — главный цикл Godot стоит, пока активность
## на паузе; фоновой службы нет (честно, без обхода правил Android). Свернули (NOTIFICATION_APPLICATION_PAUSED) — тест
## стоит; вернулись — время в фоне (away_time; за весь запуск — away_total_us, его вычитают часы Кардинала) в лимиты
## не входит, кадр после возвращения (его delta — всё время в фоне) не считается, замер идёт заново; запись в журнал
## сворачиваний (interruptions: когда, сколько, на каком шаге) и раздел отчёта «Сворачивания и фон» (питание,
## экономия энергии, оптимизация батареи, ограничение фона, группа ожидания — плагин powerInfo). Кадр длиннее
## SUSPEND_GAP без уведомлений — тоже простой. Пока игра свёрнута, плагин показывает уведомление «тест на паузе» с
## кнопкой «Остановить тест» (botState — идёт ли бот и что делает; botStopRequested — нажали ли «Остановить»: тест
## останавливается при возвращении, с отчётом и возвратом героя игрока). Долгие режимы (BotScenario.resumable:
## «Кардинал: профили игроков», «Автотесты») пишут контрольную точку после каждого прогона или теста (save_checkpoint:
## CHECKPOINT в папке отчётов — атомарно, версия схемы, sha256 данных); систему выгрузили или бот остановлен перегревом
## или лимитом — во вкладке «Тест-бот» «Продолжить» (start с opts.resume: BotScenario.resume — готовое не повторяется)
## или «Забыть». Закончен, остановлен вручную или из уведомления, ошибка — точка удаляется.

signal main_changed(new_main: Node)
signal finished(result: Dictionary)

const STORAGE := "user://bot_accounts/"
const REPORT_DIR := "user://bot_reports/"
const PUBLIC_DIR := "Download/DarkPact_test/"
const BOT_LOGIN := "Dedok_max"
const BOT_NICK := "ТестБот"
const RUNNING := "running.json"
## Копия user://settings.cfg игрока на время сценария (backup_settings / restore_settings).
const SETTINGS_BACKUP := "settings_backup.cfg"
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
## Контрольная точка долгого режима (save_checkpoint): файл в папке отчётов и версия его схемы.
const CHECKPOINT := "checkpoint.json"
const CHECKPOINT_SCHEMA := 1
## Кадр длиннее (с) без уведомления о паузе — игра стояла (экран погас и т. п.): в лимиты не входит, в журнал.
const SUSPEND_GAP := 20.0
## Без фокуса дольше (с) — строка журнала (шторка уведомлений, системный диалог; игра при этом работала).
const FOCUS_NOTE := 2.0
## Как часто сообщать плагину, что делает бот (текст уведомления «на паузе»), с.
const STATE_EVERY := 3.0
## Заголовок уведомления «на паузе».
const NOTICE_TITLE := "Dark Pact — тест-бот"

## Идущий бот (null — нет).
static var current: TestBot = null
## Итог последнего запуска: {kind, text, time, txt, zip, public, uri, message}; {} — не читали (last_result()).
static var last: Dictionary = {}
## Сколько бот стоял свёрнутым за этот запуск, мкс (часы Кардинала вычитают: CardinalStory.wall_sec, CardinalRun).
static var away_total_us := 0
## Разрешение на уведомления спрошено (раз за запуск игры).
static var _asked_notify := false

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
## Множитель пауз wait() (тест: короче), 1 — как в сценарии.
var time_scale := 1.0

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
## Щадящий режим (0.40.1): пауза кончилась, а телефон не остыл (статус MODERATE держится и в простое — телефон
## нагрет ещё до теста) — дальше не ждать снова, а снизить нагрузку (BotScenario.on_hot: Кардинал — ускорение
## ×GENTLE_ACCEL) и продолжать; новая пауза — только если запас дошёл до HEADROOM_HOT (или статус ≥ STOP — остановка).
var gentle := false
var steps_total := 0
var measures_total := 0
## Отметка в логе Godot (хвост лога в отчёте — с неё).
var log_mark := ""
## Разделы: {id, title, start (активное время), sec, checks, errors, shots, state "идёт" / "готово" / "прерван" /
## "не начат"}; cur_section — индекс открытого (−1 — нет).
var sections: Array[Dictionary] = []
var cur_section := -1
## Фон Android: сворачивания и потери фокуса {kind "свёрнута" / "без фокуса" / "стояла", sec, at, step, state, power},
## всего в фоне, с (в лимиты не входит); питание в начале и в конце (плагин powerInfo; {} — нет плагина); остановлен
## кнопкой «Остановить тест» уведомления.
var interruptions: Array[Dictionary] = []
var away_time := 0.0
var power_start: Dictionary = {}
var power_end: Dictionary = {}
var stop_from_notice := false
## Контрольные точки: продолжение запуска origin (base_name первого; у нового — свой), с какой точки (resume_cp —
## TestBot.read_checkpoint), сколько записано за этот запуск и последняя (прогресс).
var resume_cp: Dictionary = {}
var origin := ""
var checkpoints := 0
var checkpoint_last := ""

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
var _away_start_us := 0
var _away_paused := false
var _skip_dt := false
var _state_t := 0.0
## Доп. поля метки RUNNING (mark): шаг сценария, копия настроек.
var _marker_extra: Dictionary = {}
## Главная сцена была текущей (до того, как сценарий без мира её убрал).
var _main_was_current := true


func _init() -> void:
	name = "TestBot"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_headless = DisplayServer.get_name() == "headless"
	placeholder_shots = _headless
	frame_guard = not _headless


# ---------- Запуск и состояние (вкладка «Тест-бот») ----------

## Запустить режим mode_id (BotScenario.MODES) из мира main_node. "" — запущен, иначе причина.
## opts (тесты): scenario (свой BotScenario), storage, report_dir, warmup, poll, cool_min, cool_max, cool_total, limit,
## status_source, headroom_source, battery_source, frame_guard, time_scale.
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
	# Продолжение с контрольной точки (read_checkpoint): сценарий узнаёт, что готово, до limit() и build
	var cp: Dictionary = opts.get("resume", {})
	if not cp.is_empty():
		if not sc.resumable():
			return "режим «%s» не продолжается с контрольной точки" % BotScenario.mode_name(mode_id)
		var rerr := sc.resume(cp.get("data", {}) as Dictionary)
		if rerr != "":
			return "Продолжить нельзя: " + rerr
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
	bot.time_scale = float(opts.get("time_scale", 1.0))
	if not cp.is_empty():
		bot.resume_cp = cp
		bot.origin = String(cp.get("origin", ""))
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
	AnimResolver.reset_stats()
	var now := Time.get_datetime_dict_from_system()
	started_text = "%04d-%02d-%02d %02d:%02d" % [int(now["year"]), int(now["month"]), int(now["day"]), int(now["hour"]),
		int(now["minute"])]
	base_name = BotReport.file_base(now)
	if origin == "":
		origin = base_name
	away_total_us = 0
	run_dir = report_dir + base_name + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(run_dir + "shots"))
	_read_marker()
	log_mark = "TestBot: старт %s %s" % [base_name, mode]
	print(log_mark)
	note("Старт: режим «%s» (%s), лимит %s" % [scenario.title(), BotScenario.mode_name(mode), clock(limit)])
	if not interrupted_before.is_empty():
		note("Прошлый запуск бота (%s) не завершился — игру закрыли или она упала; сохранения игрока не тронуты"
			% String(interrupted_before.get("time", "?")))
	if not resume_cp.is_empty():
		note("Продолжение запуска %s с контрольной точки: %s (записана %s) — готовое не повторяется" % [origin,
			String(resume_cp.get("progress", "")), String(resume_cp.get("saved", ""))])
	device = BotReport.device_info()
	power_start = BotReport.power_info()
	_ask_notifications()
	temp_start = read_temps(true)
	player_quality = "%s, %d к/с" % [Quality.level_name(), Quality.fps_limit()]
	# Дом игрока: хранилище, аккаунт, слот
	_home = {"dir": Accounts.dir, "login": Accounts.current, "slot": Game.slot, "nick": Game.char_name}
	_write_marker()
	_plugin_state(true)
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
	if scenario.needs_world():
		_swap_scene()
	else:
		_drop_scene()


## Главная сцена заново (с тем, что сейчас в Game и Accounts); её нет (сценарий без мира убрал) — новая.
func _swap_scene() -> void:
	var fresh: Node
	if main != null and is_instance_valid(main) and not main.is_queued_for_deletion() and main.is_inside_tree():
		fresh = main.call("restart_scene")
	else:
		fresh = load("res://main.tscn").instantiate()
		var tree := get_tree()
		tree.root.add_child.call_deferred(fresh)
		if _main_was_current:
			var set_current := func() -> void:
				if is_instance_valid(fresh) and fresh.is_inside_tree():
					tree.current_scene = fresh
			set_current.call_deferred()
	main = fresh
	main_changed.emit(fresh)


## Убрать главную сцену (сценарий без мира сам ставит свои сцены).
func _drop_scene() -> void:
	if main != null and is_instance_valid(main):
		_main_was_current = get_tree().current_scene == main
		main.process_mode = Node.PROCESS_MODE_DISABLED
		var hud: Variant = main.get("hud")
		if is_instance_valid(hud) and hud is CanvasLayer:
			(hud as CanvasLayer).visible = false
		main.queue_free()
	main = null
	main_changed.emit(null)


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
	Quality.reread()
	UiScale.reread()
	Quality.set_throttle(0)
	# Размер интерфейса — как у игрока (раздел «Интерфейс» меняет его без записи)
	UiScale.reread()
	UiScale.set_level(UiScale.level(), false)
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
	# Кадр после возвращения свёрнутой игры: его delta — всё время в фоне (в лимиты и шаги не идёт)
	if _skip_dt:
		_skip_dt = false
		delta = 0.0
		fdt = 0.0
	elif delta > SUSPEND_GAP and (state == "running" or state == "cooling" or state == "prepare"):
		# Игра стояла без уведомлений о паузе (экран погас, система заморозила процесс)
		away_time += delta
		away_total_us += int(delta * 1.0e6)
		_add_interruption("стояла", delta)
		delta = 0.0
		fdt = 0.0
	_state_t += delta / maxf(Engine.time_scale, 0.001)
	if _state_t >= STATE_EVERY:
		_state_t = 0.0
		_plugin_state(state != "home" and state != "done")
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
	if scenario.needs_world() and not _world_ready():
		return
	if _wait_t < SETTLE:
		return
	_wait_t = 0.0
	# Не первый кадр готовности: SETTLE с после постройки мира
	state = "running"
	if scenario.needs_world():
		note("Мир тестового героя готов (%s)" % clock(total_time))
	scenario.build(self)
	steps_total = _steps.size()
	_plugin_state(true)
	for s in _steps:
		if String(s["kind"]) == "measure":
			measures_total += 1


func _tick_running(dt: float, fdt: float) -> void:
	# Лимиты — по настоящему времени: delta умножен на Engine.time_scale, и ускоренный прогон Кардинала (×4, отдых ×32)
	# съедал лимит режима вчетверо быстрее (0.29.0: «Кардинал: детерминизм» остановлен на 2-м прогоне из 2)
	var real := dt / maxf(Engine.time_scale, 0.001)
	total_time += real
	active_time += real
	if not scenario.owns_scene() and not _world_ready():
		stop("Главная сцена пропала", "error")
		return
	_watch(dt, fdt)
	if state != "running":
		return
	if active_time >= limit:
		stop("Лимит времени режима (%s): %s" % [clock(limit), progress_text()], "limit")
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
			# Android: свернули — сначала FOCUS_OUT, затем PAUSED (главный цикл встаёт); шторка, диалог — только FOCUS_OUT
			if _away_start_us == 0:
				_away_start_us = Time.get_ticks_usec()
				# Текст уведомления «на паузе» — свежий шаг (плагин обновит уже показанное)
				if state != "home" and state != "done" and state != "idle":
					_plugin_state(true)
			if what == NOTIFICATION_APPLICATION_PAUSED:
				_away_paused = true
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			if _app_away and state == "running" and _measuring():
				note("Игра была свёрнута — замер «%s» заново" % step_name())
				_restart_step()
			_app_away = false
			_last_us = 0
			_back_from_away()


## Вернулись (RESUMED, затем FOCUS_IN — второй вызов ничего не делает): сколько не было, журнал; свёрнутая —
## следующий кадр не считается (_skip_dt); нажали «Остановить тест» в уведомлении — остановка.
func _back_from_away() -> void:
	if _away_start_us == 0:
		return
	var sec := float(Time.get_ticks_usec() - _away_start_us) / 1.0e6
	var paused := _away_paused
	_away_start_us = 0
	_away_paused = false
	if paused:
		_skip_dt = true
		away_time += sec
		away_total_us += int(sec * 1.0e6)
	if paused or sec >= FOCUS_NOTE:
		_add_interruption("свёрнута" if paused else "без фокуса", sec)
	# Остановка (отчёт, сцена заново) — не посреди уведомления движка, а в конце кадра
	_check_stop_request.call_deferred()


## Запись журнала сворачиваний: когда, сколько, на каком шаге, питание в этот момент.
func _add_interruption(kind: String, sec: float) -> void:
	if state == "done" or state == "idle":
		return
	var now := Time.get_datetime_dict_from_system()
	var e := {"kind": kind, "sec": sec, "at": "%02d:%02d:%02d" % [int(now["hour"]), int(now["minute"]), int(now["second"])],
		"step": step_name() if state == "running" or state == "cooling" else state, "state": state,
		"power": BotReport.power_info()}
	interruptions.append(e)
	match kind:
		"свёрнута":
			note("Игра была свёрнута %s (шаг «%s») — тест стоял, время в фоне в лимиты не вошло" % [clock(sec),
				String(e["step"])])
		"стояла":
			note("Игра стояла %s без уведомления о паузе (шаг «%s») — в лимиты не вошло" % [clock(sec), String(e["step"])])
		_:
			note("Игра без фокуса %s (шторка, диалог; шаг «%s») — тест шёл" % [clock(sec), String(e["step"])])


## Нажали «Остановить тест» в уведомлении (флаг плагина) — остановка с отчётом. Нет плагина или старый — ничего.
func _check_stop_request() -> void:
	if result_kind != "" or state == "home" or state == "done" or _no_plugin.has("botStopRequested"):
		return
	var v: Variant = BotReport.plugin_call("botStopRequested", [])
	if typeof(v) != TYPE_BOOL:
		_no_plugin["botStopRequested"] = true
		return
	if bool(v):
		BotReport.plugin_call("botClearStop", [])
		stop_from_notice = true
		stop("Остановлен кнопкой «Остановить тест» в уведомлении", "stopped")


## Сообщить плагину, идёт ли бот и что делает (текст уведомления «на паузе», пока игра свёрнута).
func _plugin_state(running: bool) -> void:
	if _no_plugin.has("botState"):
		return
	var text := ""
	if running and scenario != null:
		text = "Режим «%s» — %s" % [scenario.title(), _notice_text()]
	var v: Variant = BotReport.plugin_call("botState", [running, NOTICE_TITLE, text])
	if typeof(v) != TYPE_BOOL:
		_no_plugin["botState"] = true


## Что делает бот — строка уведомления «на паузе».
func _notice_text() -> String:
	match state:
		"idle", "prepare":
			return "загрузка мира тестового героя"
		"cooling":
			return "пауза на остывание телефона"
		"home":
			return "возвращаю вашего героя"
	return "шаг %d из %d: %s (%s)" % [mini(_si + 1, _steps.size()), _steps.size(), step_name(), clock(active_time)]


## Android 13+: долгий режим — спросить разрешение на уведомления (иначе «на паузе» не покажется), раз за запуск игры.
func _ask_notifications() -> void:
	if _asked_notify or limit < 900.0:
		return
	var v: Variant = BotReport.plugin_call("notificationsAllowed", [])
	if typeof(v) == TYPE_BOOL and not bool(v):
		_asked_notify = true
		BotReport.plugin_call("requestNotifications", [])
		note("Спрошено разрешение на уведомления (Android 13+): без него уведомление «тест на паузе» не покажется")


## Сейчас идёт шаг замера.
func _measuring() -> bool:
	return _si < _steps.size() and String(_steps[_si]["kind"]) == "measure"


func step_name() -> String:
	if _si >= _steps.size():
		return "конец"
	return String(_steps[_si].get("name", ""))


func _run_step(dt: float, fdt: float) -> void:
	if _si >= _steps.size():
		# Последний раздел закрыт до итога — иначе в строке «Конец» он ещё не в счёте («разделов 8 из 9»)
		_close_section("готово")
		var sm := scenario.summary(self)
		_finish("done", "готово: " + (sm if sm != "" else progress_text()))
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
		"section":
			_open_section(String(s["id"]), String(s["name"]))
			_next()


## Что сделано: замеры (режим «Производительность») или разделы и проверки (игровые сценарии).
func progress_text() -> String:
	if measures_total > 0:
		return "замеров %d из %d" % [rows.size(), measures_total]
	if sections.is_empty():
		return "шагов %d из %d" % [_si, _steps.size()]
	var done := 0
	for sd in sections:
		if String(sd["state"]) == "готово":
			done += 1
	var errs := 0
	for c in checks:
		if not bool(c["ok"]):
			errs += 1
	return "разделов %d из %d, проверок %d, ошибок %d" % [done, sections.size(), checks.size(), errs]


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
		_check_stop_request()
		if result_kind != "":
			return
	if _status >= STATUS_STOP:
		stop("Тест остановлен: телефон перегрелся (статус температуры %d — %s)" % [_status, status_name(_status)], "hot")
		return
	if _status >= STATUS_HOT or _headroom >= HEADROOM_HOT:
		if gentle and _headroom >= 0 and _headroom < HEADROOM_HOT:
			return
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
			if not gentle:
				gentle = true
				var how := scenario.on_hot(self) if scenario != null else ""
				note("Щадящий режим: паузы — только при запасе от %s%s" % [BotReport.headroom_text(HEADROOM_HOT),
					(", " + how) if how != "" else ""])
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
	_close_section("готово" if kind == "done" else "прерван")
	clear_spawned()
	scenario.on_finish(self)
	temp_end = read_temps(true)
	power_end = BotReport.power_info()
	# Контрольная точка этого запуска: перегрев и лимит — остаётся («Продолжить» во вкладке), иначе удаляется
	var cp := read_checkpoint(report_dir, false)
	if bool(cp.get("exists", false)) and String(cp.get("origin", "")) == origin:
		if kind == "hot" or kind == "limit":
			note("Контрольная точка сохранена (%s) — продолжить: вкладка «Тест-бот» → «Продолжить»" % String(
				cp.get("progress", "")))
		else:
			drop_checkpoint(report_dir)
	_plugin_state(false)
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
	_steps.append({"kind": "wait", "name": "пауза %.1f с" % sec, "sec": sec * time_scale})


func wait_until(step_title: String, cond: Callable, timeout: float) -> void:
	_steps.append({"kind": "until", "name": step_title, "fn": cond, "sec": timeout})


## Сразу (из действия шага, не очередью): вызывать fn(dt) каждый кадр; Callable() — перестать.
func set_tick(fn: Callable) -> void:
	_tick_fn = fn


## Шаг очереди: вызывать fn(dt) каждый кадр (до следующего tick); Callable() — перестать.
func tick(fn: Callable) -> void:
	_steps.append({"kind": "tick", "name": "каждый кадр", "fn": fn})


## Начало раздела sec_id (BotSection): прежний раздел закрывается, состояние между разделами возвращается.
func section(sec_id: String, sec_title: String) -> void:
	_steps.append({"kind": "section", "name": sec_title, "id": sec_id})
	sections.append({"id": sec_id, "title": sec_title, "start": 0.0, "sec": 0.0, "checks": 0, "errors": 0, "shots": 0,
		"state": "не начат"})


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
	var sec := ""
	if cur_section >= 0:
		var sd: Dictionary = sections[cur_section]
		sec = String(sd["title"])
		sd["checks"] = int(sd["checks"]) + 1
		if not ok:
			sd["errors"] = int(sd["errors"]) + 1
	checks.append({"ok": ok, "text": text, "at": active_time, "section": sec})
	if not ok:
		note("ОШИБКА%s: %s" % [" [%s]" % sec if sec != "" else "", text])
	return ok


## Открытый раздел (пусто — нет).
func section_title() -> String:
	return String(sections[cur_section]["title"]) if cur_section >= 0 else ""


## Открыть раздел (шаг section): запись — первая «не начат» с этим id.
func _open_section(sec_id: String, sec_title: String) -> void:
	_close_section("готово")
	var idx := -1
	for i in sections.size():
		if String(sections[i]["id"]) == sec_id and String(sections[i]["state"]) == "не начат":
			idx = i
			break
	if idx < 0:
		sections.append({"id": sec_id, "title": sec_title, "checks": 0, "errors": 0, "shots": 0})
		idx = sections.size() - 1
	var sd: Dictionary = sections[idx]
	sd["start"] = active_time
	sd["sec"] = 0.0
	sd["state"] = "идёт"
	cur_section = idx
	_reset_between_sections()
	print("TestBot: ===== Раздел «%s» — начало (%s) =====" % [sec_title, clock(active_time)])
	note("Раздел «%s»" % sec_title)


## Закрыть открытый раздел: время, состояние ("готово" / "прерван"), метка в лог.
func _close_section(how: String) -> void:
	if cur_section < 0:
		return
	var sd: Dictionary = sections[cur_section]
	sd["sec"] = active_time - float(sd.get("start", 0.0))
	sd["state"] = how
	print("TestBot: ===== Раздел «%s» — конец: %s, %s, проверок %d, ошибок %d =====" % [String(sd["title"]), how,
		clock(float(sd["sec"])), int(sd["checks"]), int(sd["errors"])])
	cur_section = -1


## Между разделами: окна закрыты, звери бота убраны, цель и джойстик сброшены, каст прерван, бессмертие, обычная
## скорость, HP/MP полные, камера по умолчанию, приручение и крафт — без подстановок.
func _reset_between_sections() -> void:
	_tick_fn = Callable()
	clear_spawned()
	AdminPanel.god = true
	AdminPanel.speed_mult = 1
	if main == null or not is_instance_valid(main):
		return
	var hud := main.get("hud") as HUD
	if hud != null:
		hud.close_window()
		hud.move_vec = Vector2.ZERO
	var tm := main.get("taming") as Taming
	if tm != null:
		tm.force_roll = -1.0
	var eco := main.get("economy") as Economy
	if eco != null:
		eco.craft_rng = null
	var p := player()
	if p != null and is_instance_valid(p):
		p.cancel_cast("")
		p.select_target(null)
		p.move_input = Vector2.ZERO
		p.recalc_stats()
		p.hp = p.max_hp
		p.mp = p.max_mp
		p.stats_changed.emit()
	reset_camera()


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
	if cur_section >= 0:
		sections[cur_section]["shots"] = int(sections[cur_section]["shots"]) + 1
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
	var d := {"time": started_text, "mode": mode, "login": String(_home.get("login", "")), "slot": int(_home.get("slot", -1)),
		"origin": origin}
	d.merge(_marker_extra, true)
	# Атомарно: игру выгрузили посреди записи — прежняя метка цела
	write_atomic(report_dir + RUNNING, JSON.stringify(d))


## Дописать в метку RUNNING (шаг сценария: игра упала — следующий отчёт скажет, на чём).
func mark(extra: Dictionary) -> void:
	_marker_extra.merge(extra, true)
	_write_marker()


# ---------- Настройки игрока на время сценария ----------

## Убрать user://settings.cfg игрока на время сценария (автотесты ждут настройки по умолчанию, как в CI): копия —
## в папке отчётов, путь — в метке (игра упала — recover_after_crash). Возвращает false, если копию не записать.
func backup_settings() -> bool:
	var backup := report_dir + SETTINGS_BACKUP
	if FileAccess.file_exists(Quality.PATH):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_dir))
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(Quality.PATH), ProjectSettings.globalize_path(backup)) != OK:
			return false
		mark({"settings_backup": backup})
	else:
		mark({"settings_backup": ""})
	return true


## Вернуть настройки игрока (после backup_settings). Удаляет копию.
func restore_settings() -> void:
	if not _marker_extra.has("settings_backup"):
		return
	_restore_settings_from(String(_marker_extra["settings_backup"]))
	_marker_extra.erase("settings_backup")
	_write_marker()


static func _restore_settings_from(backup: String) -> void:
	if backup == "":
		if FileAccess.file_exists(Quality.PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(Quality.PATH))
	elif FileAccess.file_exists(backup):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(backup), ProjectSettings.globalize_path(Quality.PATH))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))
	Quality.reread()
	UiScale.reread()


## Запуск игры (main._ready): прошлый тест-бот не закончился (метка RUNNING — игру закрыли, она упала или система
## выгрузила свёрнутую): уведомление «тест на паузе» прежнего процесса убирается; нажали в нём «Остановить тест» —
## контрольная точка удаляется (продолжать не просили), в метке — stopped_by_notice; убирал настройки игрока —
## вернуть их. Пока бот идёт — ничего. true — настройки вернули.
static func recover_after_crash(dir: String = REPORT_DIR) -> bool:
	if is_running() or not FileAccess.file_exists(dir + RUNNING):
		return false
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + RUNNING))
	if not (v is Dictionary):
		return false
	var d: Dictionary = v
	BotReport.plugin_call("botState", [false, "", ""])
	var changed := false
	var sv: Variant = BotReport.plugin_call("botStopRequested", [])
	if typeof(sv) == TYPE_BOOL and bool(sv):
		BotReport.plugin_call("botClearStop", [])
		d["stopped_by_notice"] = true
		changed = true
		var cp := read_checkpoint(dir, false)
		if bool(cp.get("exists", false)) and String(cp.get("origin", "")) == String(d.get("origin", "")):
			drop_checkpoint(dir)
			print("TestBot: прошлый запуск остановлен из уведомления — контрольная точка удалена")
	var restored := false
	if d.has("settings_backup"):
		_restore_settings_from(String(d["settings_backup"]))
		d.erase("settings_backup")
		d["settings_recovered"] = true
		changed = true
		restored = true
		print("TestBot: прошлый запуск бота не закончился — настройки игрока возвращены из копии")
	if changed:
		write_atomic(dir + RUNNING, JSON.stringify(d))
	return restored


# ---------- Контрольные точки (долгие режимы: продолжение после выгрузки игры, перегрева, лимита) ----------

## Записать контрольную точку (сценарий — после каждого законченного прогона или теста): data — только JSON-типы
## (числа после чтения — float), progress — «прогонов 3 из 10». Файл CHECKPOINT в папке отчётов, атомарно; данные —
## строкой JSON с sha256 (сверка байт в байт: число 1 после чтения и записи стало бы «1.0»).
func save_checkpoint(data: Dictionary, progress: String) -> bool:
	var body := JSON.stringify(data)
	var now := Time.get_datetime_dict_from_system()
	var cp := {"schema": CHECKPOINT_SCHEMA, "game_version": BotReport.version(), "mode": mode,
		"title": scenario.title() if scenario != null else mode, "origin": origin, "run": base_name,
		"saved": "%04d-%02d-%02d %02d:%02d:%02d" % [int(now["year"]), int(now["month"]), int(now["day"]), int(now["hour"]),
			int(now["minute"]), int(now["second"])],
		"progress": progress, "data_json": body, "sha256": body.sha256_text()}
	var ok := write_atomic(report_dir + CHECKPOINT, JSON.stringify(cp, "\t"))
	if ok:
		checkpoints += 1
		checkpoint_last = progress
		mark({"checkpoint": progress})
	else:
		note("Контрольная точка не записана (%s)" % progress)
	return ok


## Контрольная точка в папке dir: {exists, ok, error, mode, title, origin, run, saved, progress, data}. ok — можно
## продолжить: файл цел (JSON, версия схемы, sha256 данных), та же версия игры, а при check_mode — режим есть в MODES
## и продолжается (BotScenario.resumable).
static func read_checkpoint(dir: String = REPORT_DIR, check_mode: bool = true) -> Dictionary:
	var path := dir + CHECKPOINT
	if not FileAccess.file_exists(path):
		return {"exists": false, "ok": false, "error": "контрольной точки нет"}
	var res := {"exists": true, "ok": false, "error": ""}
	# JSON.new().parse — без ошибки движка в логе (JSON.parse_string печатает её на испорченном файле)
	var jp := JSON.new()
	if jp.parse(FileAccess.get_file_as_string(path)) != OK or not (jp.data is Dictionary):
		res["error"] = "файл повреждён (не читается)"
		return res
	var cp: Dictionary = jp.data
	for k in ["mode", "title", "origin", "run", "saved", "progress", "game_version"]:
		res[k] = str(cp.get(k, ""))
	if int(cp.get("schema", 0)) != CHECKPOINT_SCHEMA:
		res["error"] = "другая версия схемы файла (%s, нужна %d)" % [str(cp.get("schema", "?")), CHECKPOINT_SCHEMA]
		return res
	var body := str(cp.get("data_json", ""))
	if body == "" or body.sha256_text() != str(cp.get("sha256", "")):
		res["error"] = "контрольная сумма не сошлась — файл повреждён"
		return res
	var jd := JSON.new()
	if jd.parse(body) != OK or not (jd.data is Dictionary):
		res["error"] = "данные повреждены"
		return res
	var dv: Dictionary = jd.data
	if str(res["game_version"]) != BotReport.version():
		res["error"] = "записана версией игры %s, сейчас %s — такой запуск начнётся заново" % [str(res["game_version"]),
			BotReport.version()]
		return res
	if check_mode:
		var sc := BotScenario.create(str(res["mode"]))
		if sc == null:
			res["error"] = "режима «%s» нет" % str(res["mode"])
			return res
		if not sc.resumable():
			res["error"] = "режим «%s» не продолжается с контрольной точки" % BotScenario.mode_name(str(res["mode"]))
			return res
	res["data"] = dv
	res["ok"] = true
	return res


static func drop_checkpoint(dir: String = REPORT_DIR) -> void:
	for f in [CHECKPOINT, CHECKPOINT + ".tmp"]:
		if FileAccess.file_exists(dir + String(f)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + String(f)))


## Записать файл атомарно: во временный рядом, затем переименование (Android, Linux — замена одним шагом: игру
## выгрузили посреди записи — прежний файл цел), проверка чтением. false — не вышло.
static func write_atomic(path: String, text: String) -> bool:
	var base := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base))
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.flush()
	f.close()
	var d := DirAccess.open(base)
	if d == null:
		return false
	if d.rename(tmp.get_file(), path.get_file()) != OK:
		# Где переименование не заменяет файл — прежний удалить и снова
		d.remove(path.get_file())
		if d.rename(tmp.get_file(), path.get_file()) != OK:
			return false
	return FileAccess.get_file_as_string(path) == text


func _remove_marker() -> void:
	if FileAccess.file_exists(report_dir + RUNNING):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(report_dir + RUNNING))


func _save_last() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_dir))
	var f := FileAccess.open(report_dir + LAST_FILE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(last, "\t"))
		f.close()
