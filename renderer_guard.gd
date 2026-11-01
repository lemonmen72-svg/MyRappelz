class_name RendererGuard
extends Node
## Рендерер игры (решение Максима: S24 Ultra грелся на «Максимальном» в Compatibility): на телефонах с нормальным
## Vulkan — Mobile (Vulkan), на остальных и при сбое — запасной Compatibility (OpenGL ES 3). Подробно — CLAUDE.md,
## раздел «Рендерер».
##
## Почему так (исходники Godot 4.3-stable): автоматического отката на OpenGL при отсутствии Vulkan в 4.3 нет
## (настройки rendering/rendering_device/fallback_to_opengl3 ещё нет — в main.cpp только fallback_to_vulkan /
## fallback_to_d3d12 для Windows). На Android Godot.kt (onInitRenderView → usesVulkan) по настройке
## rendering/renderer/rendering_method создаёт Vulkan-вид, а у телефона без Vulkan 1.0.3 (meetsVulkanRequirements)
## бросает IllegalStateException — окно «нет Vulkan» и выход; если Vulkan есть, но драйвер не поднялся
## (DisplayServerAndroid → ERR_UNAVAILABLE), Main::setup2 не проверяют — вылет. Скрипты в таком запуске не
## работают вовсе, а параметр командной строки --rendering-method на Android не помогает (Java читает настройку
## проекта, не командную строку). Поэтому:
## - в project.godot рендерер по умолчанию — Compatibility везде (и на Android: rendering_method.mobile) — первый
##   запуск идёт на любом телефоне;
## - application/config/project_settings_override = OVERRIDE_PATH: Godot читает этот файл при каждом запуске
##   (ProjectSettings::setup, после project.godot, до создания окна; редактор и экспорт его не читают). В нём —
##   рендерер следующего запуска; пишет его только эта игра и только на Android;
## - «Авто» (по умолчанию): видеочип из списка надёжных (gpu_supports_vulkan; плагин MyRappelzDownload, если у него
##   есть vulkanSupported(), может только запретить) и Vulkan у него ещё не падал — со следующего запуска Mobile;
## - страховка от вылета: пока Vulkan на этом телефоне не подтверждён, в начале запуска на Vulkan файл заранее
##   переписывается на Compatibility («взведено», armed). Мир отрисован CONFIRM_WORLD_SEC секунд — Vulkan
##   подтверждён, файл снова на Mobile. Ушли в фон или вышли кнопкой — тоже снова Mobile (вылета не было), вернулись —
##   снова взведено. Вылетела игра во время проверки — следующий запуск на Compatibility, а «Авто» больше Vulkan не
##   включает (failed > 0; выбрать Vulkan можно вручную);
## - выбор в «Настройки → Графика → Рендерер»: Авто / Vulkan / Совместимость, меняется после перезапуска игры.
## Чего не ловит без плагина: вылет до запуска скриптов (окно «нет Vulkan» или сбой драйвера при создании окна) —
## поэтому «Авто» и «Vulkan» только у видеочипов из списка (Adreno 6xx+, Mali-G кроме G71/G72, Immortalis,
## Xclipse) и не при ответе плагина «нет Vulkan».
## С плагином MyRappelzDownload (RendererPreflight.java) до движка: armed — смотрит, как закончился прошлый запуск
## (Android 11+, ApplicationExitInfo): не сбой (смахнули, система выгрузила, перезапуск) — снова Vulkan, сбоем не
## считается; сбой или MAX_TRIES запусков без подтверждения — Compatibility, игра засчитывает сбой. Файл не совпал с
## want (рендерер, который игра хочет; пишется в состояние при каждом сохранении) — плагин его исправляет. После
## чтения настроек (onMainCreate) — что движок взял на самом деле (GodotLib.getGlobal, как usesVulkan() Godot.kt);
## страховка взводится, только если движок взял Vulkan. Всё — в журнал LOG_PATH (и плагин, и игра; в отчёте
## тест-бота — diagnostics()). «Перезапустить игру» — плагин restartApp (ProcessPhoenix, как сам Godot 4.3).
##
## Тесты: override_path / state_path / log_path — свои файлы, platform_override (1 — как Android), method_override,
## gpu_override, plugin_override; reset_session() — заново, как новый запуск.

const OVERRIDE_PATH := "user://renderer_override.cfg"
const STATE_PATH := "user://renderer.cfg"
## Журнал запусков рендерера (пишут плагин и игра, последние LOG_MAX строк).
const LOG_PATH := "user://renderer_log.txt"
const LOG_MAX := 80
const SECTION := "renderer"
const MOBILE := "mobile"
const COMPAT := "gl_compatibility"
## Выбор игрока (ключ choice) и подписи кнопок.
const CHOICES := ["auto", "vulkan", "compat"]
const CHOICE_NAMES := {"auto": "Авто", "vulkan": "Vulkan", "compat": "Совместимость"}
const METHOD_NAMES := {MOBILE: "Vulkan (Mobile)", COMPAT: "Совместимость (OpenGL ES 3)"}
## Vulkan подтверждён: столько секунд мира и столько кадров без вылета.
const CONFIRM_WORLD_SEC := 8.0
const CONFIRM_FRAMES := 120
## Adreno — с этой серии (5xx: драйверы Vulkan 1.0 с известными сбоями Godot 4.x).
const ADRENO_MIN := 600
## Mali-G с ранними драйверами Vulkan (сбои Godot 4.x) — «Авто» их не включает.
const MALI_BAD := [71, 72]
const PLUGIN := "MyRappelzDownload"

static var override_path := OVERRIDE_PATH
static var state_path := STATE_PATH
static var log_path := LOG_PATH
## Тесты: 1 — вести себя как на Android, 0 — как на ПК, −1 — как есть.
static var platform_override := -1
## Тесты: текущий рендерер ("mobile" / "gl_compatibility"; "" — как есть).
static var method_override := ""
## Тесты: имя видеочипа ("" — RenderingServer.get_video_adapter_name()).
static var gpu_override := ""
## Тесты: ответ плагина о Vulkan (−1 — спросить плагин, 0 / 1 — подставить).
static var plugin_override := -1
## Сообщение игроку при входе в мир (откат после вылета, Vulkan со следующего запуска); пусто — нет.
static var note := ""

static var _booted := false
## Vulkan проверяется (файл переписан на Compatibility на случай вылета).
static var _armed := false
## Взведённое снято на время фона — вернуть при возвращении.
static var _paused_disarm := false
static var _world_ms := -1
static var _world_frames := 0
static var _plugin_answer := -2


func _init() -> void:
	name = "RendererGuard"


func _ready() -> void:
	startup()
	# Проверка Vulkan нужна, пока он не подтверждён (страховку снимает фон и возвращает возвращение — следим всё время)
	set_process(is_android() and is_vulkan() and not bool(_load()["confirmed"]))


func _process(_delta: float) -> void:
	if not _armed or _world_ms < 0 or Quality.in_background():
		return
	var sec := float(Time.get_ticks_msec() - _world_ms) / 1000.0
	if sec >= CONFIRM_WORLD_SEC and Engine.get_frames_drawn() - _world_frames >= CONFIRM_FRAMES:
		confirm()
		set_process(false)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST:
			# Ушли в фон или выходим сами — вылета не было: следующий запуск снова на Vulkan
			if _armed:
				disarm()
				_paused_disarm = true
		NOTIFICATION_APPLICATION_RESUMED:
			if _paused_disarm:
				_paused_disarm = false
				rearm()


# ---------- Где и на чём идёт игра ----------

static func is_android() -> bool:
	if platform_override >= 0:
		return platform_override == 1
	return OS.has_feature("android")


## Текущий рендерер: "mobile" — RenderingDevice (Vulkan), иначе "gl_compatibility" (и headless без рендера).
static func current_method() -> String:
	if method_override != "":
		return method_override
	return MOBILE if RenderingServer.get_rendering_device() != null else COMPAT


static func is_vulkan() -> bool:
	return current_method() == MOBILE


## Рендерер в настройках проекта этого запуска (project.godot + файл рендерера, как их прочитал Godot в
## ProjectSettings::setup; то же значение Godot.kt usesVulkan() брал через GodotLib.getGlobal).
static func engine_method() -> String:
	return String(ProjectSettings.get_setting_with_override("rendering/renderer/rendering_method"))


static func method_name(m: String = "") -> String:
	return String(METHOD_NAMES.get(current_method() if m == "" else m, m))


static func gpu_name() -> String:
	if gpu_override != "":
		return gpu_override
	return RenderingServer.get_video_adapter_name()


## Видеочип из списка надёжных для Vulkan в Godot 4.3 (по имени из GL_RENDERER в Compatibility или имени устройства
## Vulkan): Adreno ADRENO_MIN+, Mali-G (кроме MALI_BAD), Immortalis, Xclipse. Остальное (Adreno 3xx–5xx, Mali-T,
## PowerVR, неизвестные) — нет: вылет до запуска скриптов игра не поймает.
static func gpu_supports_vulkan(gpu: String) -> bool:
	var n := gpu.to_lower()
	if n.contains("immortalis") or n.contains("xclipse"):
		return true
	if n.contains("adreno"):
		var m := RegEx.create_from_string("adreno[^0-9]*([0-9]{3})").search(n)
		return m != null and int(m.get_string(1)) >= ADRENO_MIN
	var mali := RegEx.create_from_string("mali-g([0-9]+)").search(n)
	if mali != null:
		return not MALI_BAD.has(int(mali.get_string(1)))
	return false


## Ответ плагина MyRappelzDownload vulkanSupported() (та же проверка, что у Godot 4.3 перед Vulkan-видом —
## Godot.kt meetsVulkanRequirements: Android 7+ и FEATURE_VULKAN_HARDWARE_VERSION ≥ 1.0.3; уровень
## FEATURE_VULKAN_HARDWARE_LEVEL ≥ 1 Godot только пишет предупреждением): 1 / 0, −1 — нет плагина или метода
## (старый AAR). Плагин — Assets.download_plugin() (тест — Assets.plugin_override).
static func plugin_vulkan() -> int:
	if plugin_override >= 0:
		return plugin_override
	if _plugin_answer > -2:
		return _plugin_answer
	_plugin_answer = -1
	var v: Variant = _plugin_call("vulkanSupported", [])
	if typeof(v) == TYPE_BOOL:
		_plugin_answer = 1 if bool(v) else 0
	return _plugin_answer


## Метод плагина (null — нет плагина или метода; JNISingleton без метода тоже ответит null).
static func _plugin_call(method: String, args: Array) -> Variant:
	var p := Assets.download_plugin()
	if p == null or (not p.has_method(method) and p.get_class() != "JNISingleton"):
		return null
	return p.callv(method, args)


## Пути файлов — плагину: при следующем запуске он до движка проверит их сам (RendererPreflight в плагине:
## конструктор — файл на Vulkan, а прошлая проверка не подтвердилась или Vulkan 1.0.3 нет — файл на Compatibility;
## onMainCreate — неподтверждённый Vulkan взводит страховку до запуска драйвера, который скрипты не застали бы).
static func _remember_files() -> void:
	_plugin_call("rememberRendererFiles", [ProjectSettings.globalize_path(state_path),
		ProjectSettings.globalize_path(override_path)])


## Телефон подходит для Vulkan: видеочип из списка, и плагин (если он отвечает) не сказал «нет Vulkan». На Vulkan
## уже работаем — подходит.
static func device_ok() -> bool:
	if is_vulkan():
		return true
	if plugin_vulkan() == 0:
		return false
	return gpu_supports_vulkan(gpu_name())


# ---------- Состояние (user://renderer.cfg) ----------

## Ключи: choice — выбор игрока; want — рендерер, который игра хочет со следующего запуска (плагин сверяет с ним
## файл); armed — идёт проверка Vulkan; confirmed — Vulkan на этом телефоне подтверждён; failed — сбоев Vulkan;
## tries — запусков на неподтверждённом Vulkan (считает плагин); gpu — видеочип при подтверждении; last_exit — как
## закончился прошлый запуск (пишет плагин, Android 11+).
static func _load() -> Dictionary:
	var st := {"choice": "auto", "want": "", "armed": false, "confirmed": false, "failed": 0, "tries": 0, "gpu": "",
		"last_exit": ""}
	var cf := ConfigFile.new()
	if cf.load(state_path) == OK:
		for k in st:
			st[k] = cf.get_value(SECTION, String(k), st[k])
	if not CHOICES.has(String(st["choice"])):
		st["choice"] = "auto"
	return st


static func _save(st: Dictionary) -> void:
	if is_android():
		st["want"] = desired_method(st)
	var cf := ConfigFile.new()
	for k in st:
		cf.set_value(SECTION, String(k), st[k])
	var err := cf.save(state_path)
	if err != OK:
		push_warning("RendererGuard: не удалось сохранить %s (%d)" % [state_path, err])


static func state() -> Dictionary:
	return _load()


## Выбор игрока: "auto" / "vulkan" / "compat".
static func choice() -> String:
	return String(_load()["choice"])


## Можно ли выбрать Vulkan вручную (телефон подходит или Vulkan уже работал).
static func vulkan_allowed() -> bool:
	return device_ok() or bool(_load()["confirmed"])


## Рендерер, который должен быть со следующего запуска (по выбору, телефону и сбоям). Не Android — текущий.
static func desired_method(st: Dictionary = {}) -> String:
	if st.is_empty():
		st = _load()
	if not is_android():
		return current_method()
	match String(st["choice"]):
		"compat":
			return COMPAT
		"vulkan":
			return MOBILE if device_ok() or bool(st["confirmed"]) else COMPAT
	# «Авто»: подходящий телефон, и Vulkan здесь не падал (или уже подтверждён)
	if bool(st["confirmed"]):
		return MOBILE
	return MOBILE if device_ok() and int(st["failed"]) == 0 else COMPAT


## Нужен перезапуск, чтобы рендерер стал как выбран.
static func restart_needed() -> bool:
	return is_android() and desired_method() != current_method()


## Выбрать рендерер (Настройки → Графика); вступает в силу после перезапуска. Явный «Vulkan» сбрасывает счётчик
## сбоев (попробовать снова). Возвращает true, если нужен перезапуск.
static func set_choice(c: String) -> bool:
	if not CHOICES.has(c):
		return false
	var st := _load()
	st["choice"] = c
	if c == "vulkan":
		st["failed"] = 0
		st["tries"] = 0
	log_line("выбор рендерера: %s" % c)
	# Идёт проверка Vulkan — файл остаётся на Compatibility до подтверждения (страховка)
	if not _armed:
		_write_override(desired_method(st))
	_save(st)
	return restart_needed()


# ---------- Запуск, подтверждение, страховка ----------

## В начале каждого запуска (RendererGuard в главной сцене; повторно — ничего): прошлый запуск на Vulkan не дошёл до
## подтверждения и не ушёл в фон — вылет, засчитать сбой; на Android — записать рендерер следующего запуска, а
## неподтверждённый Vulkan — взвести страховку.
static func startup() -> void:
	if _booted:
		return
	_booted = true
	var st := _load()
	var m := current_method()
	var changed := false
	log_line("скрипты: рисует %s, в настройках проекта %s, файл %s, выбор %s, want %s, armed %s, confirmed %s, сбоев %d, попыток %d, видеочип %s"
		% [_file_name(m), engine_method(), _file_name(override_method()), String(st["choice"]), String(st["want"]),
		str(st["armed"]), str(st["confirmed"]), int(st["failed"]), int(st["tries"]), gpu_name()])
	if engine_method() == MOBILE and m != MOBILE:
		log_line("ВНИМАНИЕ: в настройках проекта Mobile, а RenderingDevice нет — Vulkan не поднялся")
	# Состояние версии 0.25.0 (без want): сбой там засчитывался и без вылета (страховка плагина взводилась по файлу,
	# а не по рендереру движка; смахнули игру до подтверждения — тоже «сбой») — один раз дать Vulkan ещё попытку
	var raw := ConfigFile.new()
	if is_android() and raw.load(state_path) == OK and not raw.has_section_key(SECTION, "want") \
			and int(st["failed"]) > 0 and not bool(st["armed"]):
		st["failed"] = 0
		changed = true
		log_line("состояние 0.25.0: счётчик сбоев Vulkan сброшен (новая проверка сбоев)")
	if bool(st["armed"]):
		st["armed"] = false
		changed = true
		if m != MOBILE:
			st["failed"] = int(st["failed"]) + 1
			st["tries"] = 0
			note = "Vulkan в прошлый раз не заработал — игра на «Совместимости». Вернуть: Настройки → Графика → Рендерер."
			var why := String(st["last_exit"])
			log_line("прошлый запуск на Vulkan не подтверждён — сбой засчитан (сбоев %d; прошлый выход: %s)"
				% [int(st["failed"]), why if why != "" else "неизвестно"])
	if not is_android():
		if changed:
			_save(st)
		return
	_remember_files()
	if m == MOBILE and not bool(st["confirmed"]):
		_arm(st)
	else:
		var want := desired_method(st)
		_write_override(want)
		log_line("следующий запуск: %s (файл — %s)" % [_file_name(want), _file_name(override_method())])
		if want == MOBILE and m != MOBILE and note == "":
			note = "Видеочип поддерживает Vulkan: со следующего запуска игра будет рисовать через него (меньше нагрев)."
			if can_restart():
				note += " Сразу: Настройки → Графика → «Перезапустить игру»."
	_save(st)


## Мир построен (main._start_world): отсюда считается время до подтверждения Vulkan.
static func world_started() -> void:
	if _world_ms < 0:
		_world_ms = Time.get_ticks_msec()
		_world_frames = Engine.get_frames_drawn()


## Vulkan отработал в мире без вылета — подтверждён на этом телефоне.
static func confirm() -> void:
	var st := _load()
	_armed = false
	_paused_disarm = false
	st["armed"] = false
	st["confirmed"] = true
	st["failed"] = 0
	st["tries"] = 0
	st["gpu"] = gpu_name()
	_write_override(desired_method(st))
	_save(st)
	log_line("Vulkan подтверждён на этом телефоне (%s)" % gpu_name())


static func is_armed() -> bool:
	return _armed


static func _arm(st: Dictionary) -> void:
	_armed = true
	st["armed"] = true
	_write_override(COMPAT)
	log_line("Vulkan ещё не подтверждён: страховка взведена (файл — Совместимость до %d с в мире)" % int(CONFIRM_WORLD_SEC))


## Снять страховку (фон, выход): вылета не было — файл на выбранный рендерер.
static func disarm() -> void:
	if not _armed:
		return
	var st := _load()
	_armed = false
	st["armed"] = false
	_write_override(desired_method(st))
	_save(st)
	log_line("страховка снята (фон или выход), файл — %s" % _file_name(override_method()))


## Вернуть страховку после фона, если Vulkan ещё не подтверждён.
static func rearm() -> void:
	if not is_android() or not is_vulkan():
		return
	var st := _load()
	if bool(st["confirmed"]):
		return
	_arm(st)
	_save(st)


## Перезапуск после смены рендерера: сохранить героя, снять страховку и перезапустить игру через плагин
## (restartApp → ProcessPhoenix.triggerRebirth — так перезапускается сам Godot 4.3 при потере контекста отрисовки;
## OS.set_restart_on_exit на Android 4.3 не работает — GodotActivity не обрабатывает onNewGodotInstanceRequested).
## Без плагина — выход, игрок открывает игру сам.
static func quit_for_restart(tree: SceneTree) -> void:
	if Game.has_character and Game.slot >= 0:
		Game.save_game()
	disarm()
	log_line("перезапуск для смены рендерера: сейчас %s, файл — %s" % [_file_name(current_method()), _file_name(override_method())])
	if can_restart():
		var r: Variant = _plugin_call("restartApp", [])
		if typeof(r) == TYPE_BOOL and bool(r):
			return
	if tree != null:
		tree.quit()


## Игру можно перезапустить кнопкой (Android с плагином); иначе — «Сохранить и выйти».
static func can_restart() -> bool:
	return is_android() and Assets.download_plugin() != null


# ---------- Файл для Godot (application/config/project_settings_override) ----------

## Текст файла: формат project.godot, читает ProjectSettings до создания окна.
static func override_text(method: String) -> String:
	var m := MOBILE if method == MOBILE else COMPAT
	var t := "; Рендерер следующего запуска — пишет игра (RendererGuard), читает Godot (project_settings_override).\n"
	t += "config_version=5\n\n[rendering]\n\n"
	t += "renderer/rendering_method=\"%s\"\n" % m
	t += "renderer/rendering_method.mobile=\"%s\"\n" % m
	if m == MOBILE:
		t += "rendering_device/driver.android=\"vulkan\"\n"
	return t


## Рендерер, записанный в файле ("" — файла нет).
static func override_method() -> String:
	if not FileAccess.file_exists(override_path):
		return ""
	var s := FileAccess.get_file_as_string(override_path)
	return MOBILE if s.contains("rendering_method.mobile=\"mobile\"") else COMPAT


## Записать файл (только на Android; тот же текст — не трогать).
static func _write_override(method: String) -> void:
	if not is_android():
		return
	var text := override_text(method)
	if _read(override_path) == text:
		return
	if not _write_text(override_path, text):
		push_warning("RendererGuard: не удалось записать %s" % override_path)
		log_line("не удалось записать файл рендерера (%s)" % _file_name(method))


static func _read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


## Сначала во временный файл, потом переименовать (оборванная запись не оставит полфайла). Переименование — внутри
## папки user:// (DirAccess.open(папка) — DirAccessUnix, rename(2)), не DirAccess.rename_absolute (на Android —
## через Java: DirAccessJAndroid → FilesystemDirectoryAccess). Не вышло — прямо в файл. Итог проверяется чтением.
static func _write_text(path: String, text: String) -> bool:
	var tmp := path + ".tmp"
	var d := DirAccess.open(path.get_base_dir())
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
		if d != null and d.rename(tmp.get_file(), path.get_file()) == OK and _read(path) == text:
			return true
	f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	if d != null and d.file_exists(tmp.get_file()):
		d.remove(tmp.get_file())
	return _read(path) == text


static func _file_name(m: String) -> String:
	if m == "":
		return "нет"
	return "Vulkan" if m == MOBILE else "Совместимость"


# ---------- Журнал и диагностика (отчёт тест-бота) ----------

## Строка в журнал рендерера (только на Android; последние LOG_MAX строк; тот же файл пишет плагин).
static func log_line(text: String) -> void:
	if not is_android():
		return
	var lines := _read(log_path).split("\n", false)
	lines.append("%s · игра · %s" % [Time.get_datetime_string_from_system(false, true), text])
	var from := maxi(0, lines.size() - LOG_MAX)
	var f := FileAccess.open(log_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string("\n".join(lines.slice(from)) + "\n")
	f.close()


## Последние n строк журнала.
static func log_tail(n: int) -> PackedStringArray:
	var lines := _read(log_path).split("\n", false)
	return lines.slice(maxi(0, lines.size() - n))


## Для отчёта тест-бота: что рисует сейчас, что в настройках проекта, файлы рендерера и состояния, ответ плагина,
## журнал запусков.
static func diagnostics(log_lines: int = 30) -> PackedStringArray:
	var out := PackedStringArray()
	var drv := String(ProjectSettings.get_setting_with_override("rendering/rendering_device/driver"))
	out.append("Сейчас рисует: %s (RenderingDevice %s); в настройках проекта rendering_method «%s», rendering_device/driver «%s»"
		% [method_name(), "есть" if RenderingServer.get_rendering_device() != null else "нет", engine_method(), drv])
	var body := PackedStringArray()
	for l in _read(override_path).split("\n", false):
		var line := String(l).strip_edges()
		if line != "" and not line.begins_with(";"):
			body.append(line)
	out.append("Файл рендерера %s: %s" % [override_path, " · ".join(body) if not body.is_empty() else "нет"])
	var st_body := PackedStringArray()
	for l in _read(state_path).split("\n", false):
		var line := String(l).strip_edges()
		if line != "" and not line.begins_with("["):
			st_body.append(line)
	out.append("Состояние %s: %s" % [state_path, " · ".join(st_body) if not st_body.is_empty() else "нет"])
	var pv := plugin_vulkan()
	out.append("Плагин vulkanSupported: %s · видеочип «%s» в списке надёжных: %s · после перезапуска: %s"
		% ["да" if pv == 1 else ("нет" if pv == 0 else "нет ответа"), gpu_name(),
		"да" if gpu_supports_vulkan(gpu_name()) else "нет", method_name(desired_method()) if is_android() else "—"])
	var tail := log_tail(log_lines)
	if tail.is_empty():
		out.append("Журнал рендерера: пусто")
	else:
		out.append("Журнал рендерера (последние %d):" % tail.size())
		for l in tail:
			out.append("  " + String(l))
	return out


## Тесты: как новый запуск (статические флаги сброшены).
static func reset_session() -> void:
	_booted = false
	_armed = false
	_paused_disarm = false
	_world_ms = -1
	_world_frames = 0
	_plugin_answer = -2
	note = ""
