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
##
## Тесты: override_path / state_path — свои файлы, platform_override (1 — как Android), method_override,
## gpu_override, plugin_override; reset_session() — заново, как новый запуск.

const OVERRIDE_PATH := "user://renderer_override.cfg"
const STATE_PATH := "user://renderer.cfg"
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

static func _load() -> Dictionary:
	var st := {"choice": "auto", "armed": false, "confirmed": false, "failed": 0, "gpu": ""}
	var cf := ConfigFile.new()
	if cf.load(state_path) == OK:
		for k in st:
			st[k] = cf.get_value(SECTION, String(k), st[k])
	if not CHOICES.has(String(st["choice"])):
		st["choice"] = "auto"
	return st


static func _save(st: Dictionary) -> void:
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
	if bool(st["armed"]):
		st["armed"] = false
		changed = true
		if m != MOBILE:
			st["failed"] = int(st["failed"]) + 1
			note = "Vulkan в прошлый раз не заработал — игра на «Совместимости». Вернуть: Настройки → Графика → Рендерер."
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
		if want == MOBILE and m != MOBILE and note == "":
			note = "Видеочип поддерживает Vulkan: со следующего запуска игра будет рисовать через него (меньше нагрев)."
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
	st["gpu"] = gpu_name()
	_write_override(desired_method(st))
	_save(st)


static func is_armed() -> bool:
	return _armed


static func _arm(st: Dictionary) -> void:
	_armed = true
	st["armed"] = true
	_write_override(COMPAT)


## Снять страховку (фон, выход): вылета не было — файл на выбранный рендерер.
static func disarm() -> void:
	if not _armed:
		return
	var st := _load()
	_armed = false
	st["armed"] = false
	_write_override(desired_method(st))
	_save(st)


## Вернуть страховку после фона, если Vulkan ещё не подтверждён.
static func rearm() -> void:
	if not is_android() or not is_vulkan():
		return
	var st := _load()
	if bool(st["confirmed"]):
		return
	_arm(st)
	_save(st)


## Перезапуск после смены рендерера: сохранить героя, снять страховку и выйти (на Android 4.3 OS.set_restart_on_exit
## не перезапускает приложение — GodotActivity не обрабатывает onNewGodotInstanceRequested; игрок открывает игру сам).
static func quit_for_restart(tree: SceneTree) -> void:
	if Game.has_character and Game.slot >= 0:
		Game.save_game()
	disarm()
	if tree != null:
		tree.quit()


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


## Записать файл (только на Android; тот же текст — не трогать). Сначала во временный, потом переименовать:
## оборванная запись не оставит полфайла.
static func _write_override(method: String) -> void:
	if not is_android():
		return
	var text := override_text(method)
	if FileAccess.file_exists(override_path) and FileAccess.get_file_as_string(override_path) == text:
		return
	var tmp := override_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("RendererGuard: не удалось записать %s" % tmp)
		return
	f.store_string(text)
	f.close()
	var abs_tmp := ProjectSettings.globalize_path(tmp)
	var abs_dst := ProjectSettings.globalize_path(override_path)
	if DirAccess.rename_absolute(abs_tmp, abs_dst) != OK:
		DirAccess.remove_absolute(abs_dst)
		if DirAccess.rename_absolute(abs_tmp, abs_dst) != OK:
			push_warning("RendererGuard: не удалось записать %s" % override_path)


## Тесты: как новый запуск (статические флаги сброшены).
static func reset_session() -> void:
	_booted = false
	_armed = false
	_paused_disarm = false
	_world_ms = -1
	_world_frames = 0
	_plugin_answer = -2
	note = ""
