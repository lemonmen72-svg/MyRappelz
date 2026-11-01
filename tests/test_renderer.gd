extends "res://tests/test_base.gd"
## Рендерер (RendererGuard, ветки Quality по рендереру; CLAUDE.md «Рендерер»):
## - project.godot: по умолчанию Compatibility везде (и rendering_method.mobile — первый запуск на любом телефоне),
##   рендерер следующего запуска — из application/config/project_settings_override = RendererGuard.OVERRIDE_PATH;
## - в CI (headless, Compatibility): Quality как было — билинейное растяжение, FXAA своим проходом PostFx, фильтр
##   теней "filter"; окно после Quality.apply — без встроенного FXAA и FSR;
## - ветка Mobile (Quality.renderer_override = 1, без настоящего Vulkan): FSR 1.0 на 720p/900p ниже экрана,
##   билинейно на 540p и родном, встроенный FXAA вместо прохода PostFx, фильтр теней "filter_mobile";
## - RendererGuard на «подставном Android» (свои файлы в user://test_renderer/): список видеочипов, «Авто» на
##   хорошем и плохом видеочипе, страховка неподтверждённого Vulkan (файл заранее на Compatibility), вылет → откат и
##   «Авто» больше не включает Vulkan, ручной выбор Vulkan, подтверждение в мире, фон снимает и возвращает
##   страховку, выбор «Совместимость», на ПК файл не пишется, текст файла читается как настройки проекта;
## - вкладка «Графика»: кнопки рендерера, «Сохранить и выйти» — только если рендерер сменится после перезапуска;
## - шейдеры игры без возможностей только Forward+ (в Mobile 4.3 их нет);
## - плагин MyRappelzDownload (подставной): vulkanSupported() «нет» — «Авто» не включает Vulkan, «да» — включает;
##   игра передаёт плагину пути своих файлов (rememberRendererFiles); договор с RendererPreflight.java (проверка до
##   движка): текст файла Compatibility и признак Vulkan те же, armed=true, дописанный плагином сразу под [renderer],
##   читается игрой — вылет до скриптов засчитывается при следующем запуске.

const DIR := "user://test_renderer/"
const PREFLIGHT_JAVA := "res://android/plugins/myrappelz_download/src/main/java/com/lemonmen/myrappelz/download/RendererPreflight.java"


## Плагин MyRappelzDownload понарошку: ответ о Vulkan и запомненные пути файлов.
class FakeVulkanPlugin extends RefCounted:
	var answer := true
	var files: Array = []

	func vulkanSupported() -> bool:
		return answer

	func rememberRendererFiles(state_file: String, override_file: String) -> bool:
		files = [state_file, override_file]
		return true

var _saved_level := -1


func race_class() -> Array:
	return ["human", "warrior"]


func run_step() -> void:
	match step:
		0:
			_saved_level = Quality.level()
			_check_project()
			_check_compat_quality()
			wait = 2
			step = 1
		1:
			_check_mobile_quality()
			wait = 2
			step = 2
		2:
			_use_test_files()
			_check_gpu_list()
			_check_guard_flow()
			_check_plugin()
			wait = 2
			step = 3
		3:
			_check_menu()
			wait = 3
			step = 4
		4:
			main.hud.close_window()
			_check_shaders()
			_restore()
			ok_done()


func _check_project() -> void:
	check(String(ProjectSettings.get_setting("application/config/project_settings_override", "")) == RendererGuard.OVERRIDE_PATH,
		"рендерер следующего запуска — из %s" % RendererGuard.OVERRIDE_PATH)
	check(String(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")) == RendererGuard.COMPAT,
		"по умолчанию — Compatibility")
	check(String(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", "")) == RendererGuard.COMPAT,
		"на телефоне по умолчанию тоже Compatibility (первый запуск — на любом телефоне, экспорт без required Vulkan)")
	check(not FileAccess.file_exists(RendererGuard.OVERRIDE_PATH), "на ПК файл рендерера не пишется")
	check(RendererGuard.current_method() == RendererGuard.COMPAT and not Quality.mobile_renderer(),
		"автотест — Compatibility (без RenderingDevice)")


## Compatibility (CI): всё как было до Mobile.
func _check_compat_quality() -> void:
	Quality.renderer_override = -1
	var win := get_tree().root
	for l in Quality.ULTRA + 1:
		Quality.set_level(l, false)
		Quality.apply(get_tree())
		var p := Quality.render_params(1080.0)
		check(not bool(p["mobile"]) and int(p["scaling"]) == Viewport.SCALING_3D_MODE_BILINEAR,
			"Compatibility «%s»: билинейное растяжение" % Quality.level_name(l))
		check(int(p["screen_aa"]) == Viewport.SCREEN_SPACE_AA_DISABLED and bool(p["postfx_fxaa"]) == Quality.fxaa(),
			"Compatibility «%s»: FXAA — своим проходом PostFx" % Quality.level_name(l))
		var sh: Dictionary = Quality.SHADOW_LEVELS[Quality.effective("shadows")]
		check(int(p["shadow_filter"]) == (int(sh["filter"]) if not sh.is_empty() else -1),
			"Compatibility «%s»: фильтр теней %d" % [Quality.level_name(l), int(p["shadow_filter"])])
		check(win.scaling_3d_mode == Viewport.SCALING_3D_MODE_BILINEAR and win.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED,
			"Compatibility «%s»: окно без FSR и встроенного FXAA" % Quality.level_name(l))
	Quality.set_level(Quality.MEDIUM, false)
	Quality.set_option("aa", 1, false)
	Quality.apply(get_tree())
	var fx := _fx()
	var sh2: Shader = fx.current_shader() if fx != null else null
	check(sh2 != null and sh2.code.contains("#define USE_FXAA"), "Compatibility: FXAA в шейдере PostFx")


## Ветка Mobile без настоящего Vulkan: параметры, которые Quality отдаст окну и солнцу.
func _check_mobile_quality() -> void:
	Quality.renderer_override = 1
	check(Quality.mobile_renderer(), "подстановка рендерера Mobile")
	Quality.set_level(Quality.MEDIUM, false)
	# Разрешение 3D: FSR на 720p и 900p ниже экрана, 540p и родное — билинейно
	var want_1080 := [Viewport.SCALING_3D_MODE_BILINEAR, Viewport.SCALING_3D_MODE_FSR, Viewport.SCALING_3D_MODE_FSR,
		Viewport.SCALING_3D_MODE_BILINEAR]
	for v in Quality.option_count("render"):
		Quality.set_option("render", v, false)
		var p := Quality.render_params(1080.0)
		check(int(p["scaling"]) == int(want_1080[v]), "Mobile, экран 1080, «%s»: растяжение %d"
			% [Quality.option_label("render", v), int(p["scaling"])])
		check(int(Quality.render_params(720.0)["scaling"]) == Viewport.SCALING_3D_MODE_BILINEAR,
			"Mobile, экран 720, «%s»: кадр не меньше экрана (или 540p) — билинейно" % Quality.option_label("render", v))
	# Авто-снижение до 540p — билинейно (дешевле всего)
	Quality.set_option("render", 2, false)
	Quality.set_throttle(5)
	check(int(Quality.render_params(1080.0)["scaling"]) == Viewport.SCALING_3D_MODE_BILINEAR, "Mobile, шаг 5 снижения: билинейно")
	Quality.set_throttle(0)
	# Сглаживание: FXAA встроенный, MSAA — как было
	for v in Quality.option_count("aa"):
		Quality.set_option("aa", v, false)
		var p2 := Quality.render_params(1080.0)
		check(int(p2["screen_aa"]) == (Viewport.SCREEN_SPACE_AA_FXAA if v == 1 else Viewport.SCREEN_SPACE_AA_DISABLED)
			and not bool(p2["postfx_fxaa"]), "Mobile, «%s»: FXAA встроенный, без прохода PostFx" % Quality.option_label("aa", v))
		check(int(p2["msaa"]) == int(Quality.msaa()), "Mobile, «%s»: MSAA %d" % [Quality.option_label("aa", v), int(p2["msaa"])])
	# Фильтр теней: по числу выборок RD, не выше SOFT_MEDIUM
	for v in Quality.option_count("shadows"):
		Quality.set_option("shadows", v, false)
		var f := Quality.shadow_filter()
		var lvl: Dictionary = Quality.SHADOW_LEVELS[v]
		if lvl.is_empty():
			check(f == -1, "Mobile, тени выкл — фильтра нет")
		else:
			check(f == int(lvl["filter_mobile"]) and f >= int(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
				and f <= int(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM), "Mobile, тени «%s»: фильтр %d"
				% [Quality.option_label("shadows", v), f])
	# Применение к окну и PostFx (в headless — без настоящего рендера)
	Quality.set_level(Quality.MEDIUM, false)
	Quality.set_option("aa", 1, false)
	Quality.set_option("postfx", 1, false)
	Quality.apply(get_tree())
	var win := get_tree().root
	check(win.screen_space_aa == Viewport.SCREEN_SPACE_AA_FXAA, "Mobile: окно с встроенным FXAA")
	check(is_equal_approx(win.fsr_sharpness, Quality.FSR_SHARPNESS), "Mobile: резкость FSR")
	var fx := _fx()
	var sh: Shader = fx.current_shader() if fx != null else null
	check(sh != null and not sh.code.contains("#define USE_FXAA") and sh.code.contains("#define USE_GRADE"),
		"Mobile: PostFx — только цветокоррекция, FXAA не повторяется")
	check(Quality._last_filter == int(Quality.SHADOW_LEVELS[Quality.effective("shadows")]["filter_mobile"]),
		"Mobile: фильтр теней передан RenderingServer")
	# Обратно в Compatibility
	Quality.renderer_override = -1
	Quality.set_level(Quality.MEDIUM, false)
	Quality.apply(get_tree())
	check(win.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED and win.scaling_3d_mode == Viewport.SCALING_3D_MODE_BILINEAR,
		"снова Compatibility: окно как было")
	check(Quality._last_filter == int(Quality.SHADOW_LEVELS[Quality.effective("shadows")]["filter"]),
		"снова Compatibility: фильтр теней PCF")


func _use_test_files() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	RendererGuard.override_path = DIR + "override.cfg"
	RendererGuard.state_path = DIR + "state.cfg"
	_clear_files()


func _clear_files() -> void:
	for f in [RendererGuard.override_path, RendererGuard.state_path, RendererGuard.override_path + ".tmp"]:
		if FileAccess.file_exists(String(f)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(String(f)))


## Новый запуск «телефона»: рендерер m, видеочип gpu.
func _launch(m: String, gpu: String) -> void:
	RendererGuard.reset_session()
	RendererGuard.platform_override = 1
	RendererGuard.method_override = m
	RendererGuard.gpu_override = gpu
	RendererGuard.startup()


func _check_gpu_list() -> void:
	var table := [
		["Adreno (TM) 750", true], ["Adreno (TM) 640", true], ["Adreno (TM) 618", true], ["Adreno (TM) 830", true],
		["Adreno (TM) 530", false], ["Adreno (TM) 306", false], ["Mali-G715", true], ["Mali-G715-Immortalis MC11", true],
		["Immortalis-G720 MC12", true], ["Mali-G52 MC2", true], ["Mali-G57 MC2", true], ["Mali-G72 MP3", false],
		["Mali-G71", false], ["Mali-T880", false], ["Mali-T720", false], ["Samsung Xclipse 940", true],
		["PowerVR Rogue GE8320", false], ["llvmpipe (LLVM 15.0.7, 256 bits)", false], ["", false],
	]
	for e in table:
		check(RendererGuard.gpu_supports_vulkan(String(e[0])) == bool(e[1]), "видеочип «%s»: Vulkan %s" % [e[0], e[1]])


func _check_guard_flow() -> void:
	# Текст файла читается как настройки проекта
	var cf := ConfigFile.new()
	check(cf.parse(RendererGuard.override_text(RendererGuard.MOBILE)) == OK, "файл рендерера разбирается")
	check(String(cf.get_value("rendering", "renderer/rendering_method.mobile", "")) == RendererGuard.MOBILE
		and String(cf.get_value("rendering", "renderer/rendering_method", "")) == RendererGuard.MOBILE
		and int(cf.get_value("", "config_version", 0)) == 5, "файл: Mobile для телефона, config_version 5")
	cf = ConfigFile.new()
	check(cf.parse(RendererGuard.override_text(RendererGuard.COMPAT)) == OK and String(cf.get_value("rendering",
		"renderer/rendering_method.mobile", "")) == RendererGuard.COMPAT, "файл: Compatibility")

	# Первый запуск на хорошем телефоне (Compatibility по умолчанию): «Авто» → Vulkan со следующего запуска
	_launch(RendererGuard.COMPAT, "Adreno (TM) 750")
	check(RendererGuard.choice() == "auto" and RendererGuard.override_method() == RendererGuard.MOBILE, "хороший видеочип: следующий запуск — Vulkan")
	check(RendererGuard.restart_needed() and RendererGuard.note != "" and not RendererGuard.is_armed(), "сообщение «со следующего запуска», страховки нет")
	# Плагин сказал «нет Vulkan» — не включать
	RendererGuard.plugin_override = 0
	check(not RendererGuard.device_ok() and RendererGuard.desired_method() == RendererGuard.COMPAT, "плагин: нет Vulkan — Compatibility")
	RendererGuard.plugin_override = 1
	RendererGuard.gpu_override = "Mali-T720"
	check(not RendererGuard.device_ok(), "плагин только запрещает: Mali-T720 и с ответом «да» — нет")
	RendererGuard.plugin_override = -1
	RendererGuard.gpu_override = "Adreno (TM) 750"

	# Плохой видеочип: файл — Compatibility, Vulkan вручную не выбрать
	_clear_files()
	_launch(RendererGuard.COMPAT, "Mali-T720")
	check(RendererGuard.override_method() == RendererGuard.COMPAT and not RendererGuard.vulkan_allowed() and not RendererGuard.restart_needed() and RendererGuard.note == "",
		"слабый видеочип: Compatibility, Vulkan недоступен")

	# Запуск на Vulkan, ещё не подтверждён: файл заранее на Compatibility (страховка от вылета)
	_clear_files()
	_launch(RendererGuard.COMPAT, "Adreno (TM) 750")
	_launch(RendererGuard.MOBILE, "Adreno (TM) 750")
	check(RendererGuard.is_armed() and RendererGuard.override_method() == RendererGuard.COMPAT and bool(RendererGuard.state()["armed"]),
		"Vulkan не подтверждён: страховка взведена, файл — Compatibility")
	# Вылет: следующий запуск — Compatibility, сбой засчитан, «Авто» больше не включает Vulkan
	_launch(RendererGuard.COMPAT, "Adreno (TM) 750")
	check(int(RendererGuard.state()["failed"]) == 1 and not bool(RendererGuard.state()["armed"]) and RendererGuard.note.contains("не заработал"),
		"после вылета: сбой засчитан, сообщение")
	check(RendererGuard.override_method() == RendererGuard.COMPAT and RendererGuard.desired_method() == RendererGuard.COMPAT and not RendererGuard.restart_needed(),
		"после вылета «Авто» остаётся на Compatibility")
	# Ручной выбор Vulkan — попробовать снова
	check(RendererGuard.set_choice("vulkan") and RendererGuard.override_method() == RendererGuard.MOBILE and int(RendererGuard.state()["failed"]) == 0,
		"выбор «Vulkan»: снова Vulkan со следующего запуска")
	# Запуск на Vulkan, мир 8 с — подтверждён
	_launch(RendererGuard.MOBILE, "Adreno (TM) 750")
	check(RendererGuard.is_armed() and RendererGuard.override_method() == RendererGuard.COMPAT, "снова страховка до подтверждения")
	# Фон снимает страховку (вылета не было), возвращение — снова взводит
	var node := RendererGuard.new()
	node.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(not RendererGuard.is_armed() and RendererGuard.override_method() == RendererGuard.MOBILE, "в фоне: страховка снята, файл — Vulkan")
	node.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(RendererGuard.is_armed() and RendererGuard.override_method() == RendererGuard.COMPAT, "вернулись: страховка снова")
	node.free()
	RendererGuard.world_started()
	RendererGuard.confirm()
	check(not RendererGuard.is_armed() and bool(RendererGuard.state()["confirmed"]) and RendererGuard.override_method() == RendererGuard.MOBILE
		and String(RendererGuard.state()["gpu"]) == "Adreno (TM) 750", "мир без вылета: Vulkan подтверждён")
	# Следующий запуск на подтверждённом Vulkan — без страховки
	_launch(RendererGuard.MOBILE, "Adreno (TM) 750")
	check(not RendererGuard.is_armed() and RendererGuard.override_method() == RendererGuard.MOBILE and not RendererGuard.restart_needed(), "подтверждённый Vulkan — без страховки")
	# Выбор «Совместимость» — после перезапуска
	check(RendererGuard.set_choice("compat") and RendererGuard.override_method() == RendererGuard.COMPAT, "выбор «Совместимость»: файл, нужен перезапуск")
	RendererGuard.set_choice("auto")
	check(RendererGuard.override_method() == RendererGuard.MOBILE and not RendererGuard.restart_needed(), "«Авто» на подтверждённом Vulkan — Vulkan")

	# ПК: файл не пишется, страховки нет
	_clear_files()
	RendererGuard.reset_session()
	RendererGuard.platform_override = 0
	RendererGuard.method_override = RendererGuard.MOBILE
	RendererGuard.startup()
	check(not FileAccess.file_exists(RendererGuard.override_path) and not RendererGuard.is_armed() and not RendererGuard.restart_needed(),
		"на ПК файл рендерера не пишется")
	RendererGuard.set_choice("compat")
	check(not FileAccess.file_exists(RendererGuard.override_path), "на ПК выбор только запоминается")
	# Дальше — снова как настоящий рендерер автотеста (Quality.mobile_renderer() смотрит на RendererGuard)
	RendererGuard.method_override = RendererGuard.COMPAT


## Плагин: ответ vulkanSupported, пути файлов, договор с проверкой до движка (RendererPreflight.java).
func _check_plugin() -> void:
	var fake := FakeVulkanPlugin.new()
	Assets.plugin_override = fake
	RendererGuard.plugin_override = -1
	fake.answer = false
	_clear_files()
	_launch(RendererGuard.COMPAT, "Adreno (TM) 750")
	check(RendererGuard.plugin_vulkan() == 0 and RendererGuard.override_method() == RendererGuard.COMPAT
		and not RendererGuard.restart_needed(), "плагин: vulkanSupported() = false — «Авто» на Compatibility")
	check(fake.files.size() == 2 and String(fake.files[0]) == ProjectSettings.globalize_path(RendererGuard.state_path)
		and String(fake.files[1]) == ProjectSettings.globalize_path(RendererGuard.override_path),
		"плагину переданы пути файлов рендерера: %s" % str(fake.files))
	fake.answer = true
	_clear_files()
	_launch(RendererGuard.COMPAT, "Adreno (TM) 750")
	check(RendererGuard.plugin_vulkan() == 1 and RendererGuard.override_method() == RendererGuard.MOBILE,
		"плагин: vulkanSupported() = true — Vulkan со следующего запуска")
	# Договор с RendererPreflight.java: тот же текст файла Compatibility и признак Vulkan
	var java := FileAccess.get_file_as_string(PREFLIGHT_JAVA)
	check(java != "", "исходник RendererPreflight.java читается")
	for line in RendererGuard.override_text(RendererGuard.COMPAT).split("\n", false):
		check(java.contains(String(line).replace("\"", "\\\"")), "в плагине та же строка файла: %s" % line)
	check(java.contains("MOBILE_MARK = \"rendering_method.mobile=\\\"mobile\\\"\"")
		and RendererGuard.override_text(RendererGuard.MOBILE).contains("rendering_method.mobile=\"mobile\""),
		"признак Vulkan в файле — тот же у плагина и игры")
	# Плагин взвёл страховку до драйвера (armed=true сразу под [renderer]), Vulkan упал до скриптов — следующий
	# запуск на Compatibility засчитывает сбой
	var st := FileAccess.get_file_as_string(RendererGuard.state_path)
	check(st.contains("[renderer]") and st.contains("armed=false"), "состояние — ConfigFile с armed=false")
	var f := FileAccess.open(RendererGuard.state_path, FileAccess.WRITE)
	f.store_string(st.replace("armed=false\n", "").replace("[renderer]\n", "[renderer]\narmed=true\n"))
	f.close()
	f = FileAccess.open(RendererGuard.override_path, FileAccess.WRITE)
	f.store_string(RendererGuard.override_text(RendererGuard.COMPAT))
	f.close()
	check(bool(RendererGuard.state()["armed"]), "armed=true от плагина читается игрой")
	_launch(RendererGuard.COMPAT, "Adreno (TM) 750")
	check(int(RendererGuard.state()["failed"]) == 1 and not bool(RendererGuard.state()["armed"])
		and RendererGuard.note.contains("не заработал") and RendererGuard.desired_method() == RendererGuard.COMPAT,
		"вылет Vulkan до скриптов: сбой засчитан, «Авто» остаётся на Compatibility")
	Assets.plugin_override = null
	RendererGuard.reset_session()


## Вкладка «Графика»: кнопки рендерера; «Сохранить и выйти» — только когда рендерер сменится после перезапуска.
func _check_menu() -> void:
	_clear_files()
	_launch(RendererGuard.COMPAT, "Adreno (TM) 750")
	SettingsMenu.open(main.hud, "graphics")
	for c in RendererGuard.CHOICES:
		check(SettingsMenu.buttons.has("renderer_" + String(c)), "кнопка рендерера %s" % c)
	check((SettingsMenu.buttons["renderer_auto"] as Button).button_pressed, "выбран «Авто»")
	check(SettingsMenu.buttons.has("renderer_restart"), "Vulkan со следующего запуска — кнопка «Сохранить и выйти»")
	check(not (SettingsMenu.buttons["renderer_vulkan"] as Button).disabled, "хороший видеочип: «Vulkan» доступен")
	(SettingsMenu.buttons["renderer_compat"] as Button).pressed.emit()
	check(RendererGuard.choice() == "compat" and RendererGuard.override_method() == RendererGuard.COMPAT, "нажата «Совместимость»: записано")
	check(not SettingsMenu.buttons.has("renderer_restart") and (SettingsMenu.buttons["renderer_compat"] as Button).button_pressed,
		"рендерер не сменится — кнопки перезапуска нет")
	(SettingsMenu.buttons["renderer_auto"] as Button).pressed.emit()
	check(RendererGuard.choice() == "auto" and SettingsMenu.buttons.has("renderer_restart"), "снова «Авто»")
	RendererGuard.gpu_override = "Mali-T720"
	SettingsMenu.open(main.hud, "graphics")
	check((SettingsMenu.buttons["renderer_vulkan"] as Button).disabled, "слабый видеочип: «Vulkan» недоступен")


## Шейдеры: без возможностей только Forward+ (в Mobile 4.3 их нет) — картинка в обоих рендерерах одна.
func _check_shaders() -> void:
	var bad := ["hint_normal_roughness_texture", "vertex_lighting", "SSS_STRENGTH", "SSS_TRANSMITTANCE"]
	var n := 0
	for f in DirAccess.get_files_at("res://"):
		var file := String(f)
		if not file.ends_with(".gdshader") and not file.ends_with(".gdshaderinc"):
			continue
		n += 1
		var code := FileAccess.get_file_as_string("res://" + file)
		for b in bad:
			check(not code.contains(String(b)), "%s: без «%s» (нет в Mobile)" % [file, b])
	check(n >= 15, "проверено шейдеров: %d" % n)


func _restore() -> void:
	_clear_files()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))
	RendererGuard.override_path = RendererGuard.OVERRIDE_PATH
	RendererGuard.state_path = RendererGuard.STATE_PATH
	RendererGuard.platform_override = -1
	RendererGuard.method_override = ""
	RendererGuard.gpu_override = ""
	RendererGuard.plugin_override = -1
	Assets.plugin_override = null
	RendererGuard.reset_session()
	Quality.renderer_override = -1
	if _saved_level >= Quality.LOW and _saved_level <= Quality.ULTRA:
		Quality.set_level(_saved_level, false)
	Quality.apply(get_tree())
	check(not FileAccess.file_exists(RendererGuard.OVERRIDE_PATH), "настоящий файл рендерера не тронут")


func _fx() -> PostFx:
	for n in get_tree().get_nodes_in_group("postfx"):
		return n as PostFx
	return null
