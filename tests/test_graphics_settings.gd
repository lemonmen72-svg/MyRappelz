extends "res://tests/test_base.gd"
## Настройки графики (Quality, вкладка «Графика» окна настроек): пресеты «Низкое / Среднее / Высокое /
## Максимальное», ручное изменение → «Свои» (и обратно, если совпало с пресетом), сохранение в user://settings.cfg
## и загрузка (в том числе старого файла только с quality), применение к окну (MSAA, масштаб 3D), солнцу (тени,
## каскады, дальность), постобработке (FXAA, цвет, свечение), растительности и мелочам построек (дальность), контурам
## и теням на моделях персонажей; каждая настройка меняет то, что должна. Окно настроек: вкладки, кнопки всех
## настроек, нажатие применяет сразу. Лимит сэмплеров toon.gdshader (8) не превышен.

var _had_cfg := false
var _cfg_backup := ""


func race_class() -> Array:
	return ["dark_elf", "assassin"]


func before_start() -> void:
	_had_cfg = FileAccess.file_exists(Quality.PATH)
	if _had_cfg:
		_cfg_backup = FileAccess.get_file_as_string(Quality.PATH)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Quality.PATH))
	Quality.reload()


func run_step() -> void:
	match step:
		0:
			check(Quality.level() == Quality.MEDIUM, "без файла настроек — «Среднее»")
			check(Quality.NAMES.size() == 5 and Quality.level_name(Quality.CUSTOM) == "Свои", "пять названий, «Свои»")
			_check_presets()
			wait = 2
			step = 1
		1:
			_check_custom_and_save()
			_check_legacy()
			wait = 2
			step = 2
		2:
			Quality.set_level(Quality.MEDIUM, false)
			Quality.apply(get_tree())
			_check_options()
			_check_shaders()
			wait = 2
			step = 3
		3:
			Quality.set_level(Quality.MEDIUM, false)
			Quality.apply(get_tree())
			_check_menu()
			wait = 3
			step = 4
		4:
			check(main.hud.is_window_open(), "окно настроек открыто после нажатий")
			main.hud.close_window()
			_restore()
			ok_done()


## Каждый пресет: все настройки по таблице, применяется к окну, солнцу и постобработке.
func _check_presets() -> void:
	var win := get_tree().root
	for l in Quality.ULTRA + 1:
		Quality.set_level(l, false)
		Quality.apply(get_tree())
		check(Quality.level() == l, "пресет %s выбран" % Quality.level_name(l))
		var p: Dictionary = Quality.PRESETS[l]
		var same := true
		for k in Quality.OPTIONS:
			if Quality.option(String(k)) != int(p[k]):
				same = false
		check(same, "«%s»: все настройки по пресету" % Quality.level_name(l))
		check(win.msaa_3d == Quality.msaa(), "«%s»: MSAA окна %d" % [Quality.level_name(l), win.msaa_3d])
		check(is_equal_approx(win.scaling_3d_scale, Quality.render_scale_for(float(win.size.y))),
			"«%s»: масштаб 3D %.2f" % [Quality.level_name(l), win.scaling_3d_scale])
		check(win.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS, "интерфейс — в родном разрешении")
		var sun := _sun()
		check(sun != null and sun.shadow_enabled == Quality.shadows(), "«%s»: тени солнца %s" % [Quality.level_name(l),
			Quality.shadows()])
		var fx := _fx()
		check(fx != null and fx.visible == (Quality.fxaa() or Quality.postfx()), "«%s»: постобработка" % Quality.level_name(l))
	# Пресеты растут: выше пресет — не хуже ни одна настройка
	for l in Quality.ULTRA:
		var a: Dictionary = Quality.PRESETS[l]
		var b: Dictionary = Quality.PRESETS[l + 1]
		for k in Quality.OPTIONS:
			if String(k) != "model_shadows":
				check(int(b[k]) >= int(a[k]), "пресет %d → %d: «%s» не хуже" % [l, l + 1, Quality.option_title(String(k))])
	var low: Dictionary = Quality.PRESETS[Quality.LOW]
	check(int(low["shadows"]) == 0 and int(low["aa"]) == 0 and int(low["postfx"]) == 0, "«Низкое»: без теней, сглаживания и постобработки")
	var med: Dictionary = Quality.PRESETS[Quality.MEDIUM]
	check(int(med["shadows"]) > 0 and int(med["aa"]) >= 2 and int(med["postfx"]) == 0,
		"«Среднее»: тени и MSAA, без полноэкранной постобработки")
	for l in Quality.ULTRA + 1:
		var pr: Dictionary = Quality.PRESETS[l]
		check(int(pr["model_shadows"]) == 0, "пресет %d: модели персонажей без самозатенения" % l)


## Ручное изменение → «Свои»; совпало с пресетом — снова пресет; сохранение и загрузка.
func _check_custom_and_save() -> void:
	Quality.set_level(Quality.MEDIUM)
	Quality.set_option("shadows", 3)
	check(Quality.level() == Quality.CUSTOM and Quality.level_name() == "Свои", "тени вручную — пресет «Свои»")
	var med: Dictionary = Quality.PRESETS[Quality.MEDIUM]
	Quality.set_option("shadows", int(med["shadows"]))
	check(Quality.level() == Quality.MEDIUM, "вернули как в «Среднем» — снова «Среднее»")
	Quality.set_option("aa", 1)
	Quality.set_option("view", 3)
	var cf := ConfigFile.new()
	check(cf.load(Quality.PATH) == OK, "настройки записаны в settings.cfg")
	check(int(cf.get_value("graphics", "aa", -1)) == 1 and int(cf.get_value("graphics", "view", -1)) == 3
		and int(cf.get_value("graphics", "quality", -1)) == Quality.CUSTOM, "в файле — настройки и «Свои»")
	Quality.reload()
	check(Quality.option("aa") == 1 and Quality.option("view") == 3 and Quality.level() == Quality.CUSTOM,
		"настройки прочитаны из файла")
	Quality.set_fps_limit(45)
	Quality.reload()
	check(Quality.fps_limit() == 45 and Quality.option("aa") == 1, "предел кадров сохранён и не сбросил настройки")
	Quality.set_option("render", 99, false)
	check(Quality.option("render") == Quality.option_count("render") - 1, "значение вне вариантов — ближайшее")
	Quality.set_option("nonexistent", 1, false)
	check(not Quality.LABELS.has("nonexistent"), "неизвестная настройка не добавляется")


## Старый файл (только quality 0–2 и fps): настройки — по пресету.
func _check_legacy() -> void:
	var cf := ConfigFile.new()
	cf.set_value("graphics", "quality", Quality.HIGH)
	cf.set_value("graphics", "fps", 30)
	cf.set_value("ui", "scale", 1)
	check(cf.save(Quality.PATH) == OK, "старый файл настроек записан")
	Quality.reload()
	check(Quality.level() == Quality.HIGH, "старый файл: «Высокое»")
	var p: Dictionary = Quality.PRESETS[Quality.HIGH]
	check(Quality.option("shadows") == int(p["shadows"]) and Quality.option("aa") == int(p["aa"]), "старый файл: настройки по пресету")
	check(Quality.fps_limit() == 30, "старый файл: предел кадров прочитан")
	Quality.set_level(Quality.LOW)
	var cf2 := ConfigFile.new()
	check(cf2.load(Quality.PATH) == OK and cf2.has_section_key("ui", "scale"), "другие секции файла сохранились")


## Каждая настройка меняет то, что должна.
func _check_options() -> void:
	var win := get_tree().root
	var tree := get_tree()
	# Разрешение 3D
	for v in Quality.option_count("render"):
		Quality.set_option("render", v, false)
		Quality.apply(tree)
		check(is_equal_approx(win.scaling_3d_scale, Quality.render_scale_for(float(win.size.y))), "разрешение %s применено"
			% Quality.option_label("render", v))
	Quality.set_option("render", 0, false)
	check(is_equal_approx(Quality.render_scale_for(1080.0), 0.5) and is_equal_approx(Quality.render_scale_for(500.0), 1.0),
		"540p: на экране 1080 — половина, на маленьком — родное")
	Quality.set_option("render", 1, false)
	check(is_equal_approx(Quality.render_scale_for(1080.0), 720.0 / 1080.0), "720p на экране 1080")
	Quality.set_option("render", 3, false)
	check(is_equal_approx(Quality.render_scale_for(1440.0), 1.0), "родное разрешение — масштаб 1")

	# Тени
	var sun := _sun()
	Quality.set_option("shadows", 0, false)
	Quality.apply(tree)
	check(sun != null and not sun.shadow_enabled, "тени «Выкл»: солнце без теней")
	var dists: Array[float] = []
	for v in range(1, Quality.option_count("shadows")):
		Quality.set_option("shadows", v, false)
		Quality.apply(tree)
		var lvl: Dictionary = Quality.SHADOW_LEVELS[v]
		check(sun.shadow_enabled and is_equal_approx(sun.directional_shadow_max_distance, float(lvl["distance"])),
			"тени «%s»: дальность %.0f м" % [Quality.option_label("shadows", v), sun.directional_shadow_max_distance])
		var want: DirectionalLight3D.ShadowMode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		if int(lvl["splits"]) >= 4:
			want = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		check(sun.directional_shadow_mode == want, "тени «%s»: каскады" % Quality.option_label("shadows", v))
		check(int(lvl["filter"]) >= int(RenderingServer.SHADOW_QUALITY_SOFT_LOW), "тени «%s»: мягкий фильтр PCF"
			% Quality.option_label("shadows", v))
		check(is_equal_approx(sun.shadow_normal_bias, Quality.SHADOW_NORMAL_BIAS), "сдвиг тени по нормали")
		# Первый каскад — до героя и дальше (камера в main.CAM_DIST м от него)
		var first := sun.directional_shadow_max_distance * sun.directional_shadow_split_1
		check(first >= 5.0, "тени «%s»: первый каскад %.1f м" % [Quality.option_label("shadows", v), first])
		dists.append(sun.directional_shadow_max_distance)
		var small := false
		for n in tree.get_nodes_in_group("veg_small"):
			small = (n as GeometryInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			break
		if not tree.get_nodes_in_group("veg_small").is_empty():
			check(small == Quality.small_shadows(), "тени «%s»: тени кустов и камней — %s" % [Quality.option_label("shadows", v),
				Quality.small_shadows()])
	check(dists.size() == 3 and dists[0] < dists[1] and dists[1] < dists[2], "тени выше — дальше: %s" % [dists])

	# Сглаживание
	var fx := _fx()
	var expect_msaa := [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X]
	Quality.set_option("postfx", 0, false)
	for v in Quality.option_count("aa"):
		Quality.set_option("aa", v, false)
		Quality.apply(tree)
		check(win.msaa_3d == int(expect_msaa[v]), "сглаживание «%s»: MSAA %d" % [Quality.option_label("aa", v), win.msaa_3d])
		var aa_sh: Shader = fx.current_shader() if fx != null else null
		var has_fxaa := aa_sh != null and aa_sh.code.contains("#define USE_FXAA")
		check(has_fxaa == (v == 1), "сглаживание «%s»: FXAA %s" % [Quality.option_label("aa", v), has_fxaa])
		check(fx != null and fx.visible == (v == 1), "сглаживание «%s»: проход постобработки только у FXAA"
			% Quality.option_label("aa", v))

	# Постобработка
	Quality.set_option("aa", 2, false)
	for v in Quality.option_count("postfx"):
		Quality.set_option("postfx", v, false)
		Quality.apply(tree)
		var pf_sh: Shader = fx.current_shader() if fx != null else null
		var grade := pf_sh != null and pf_sh.code.contains("#define USE_GRADE")
		var bloom := pf_sh != null and pf_sh.code.contains("#define USE_BLOOM")
		check(grade == (v >= 1) and bloom == (v >= 2), "постобработка «%s»: цвет %s, свечение %s"
			% [Quality.option_label("postfx", v), grade, bloom])

	# Дальность прорисовки
	var prev := -1.0
	for v in Quality.option_count("view"):
		Quality.set_option("view", v, false)
		Quality.apply(tree)
		var trees := tree.get_nodes_in_group("veg_trees")
		if not trees.is_empty():
			var d := (trees[0] as GeometryInstance3D).visibility_range_end
			check(d > prev, "дальность «%s»: деревья до %.0f м" % [Quality.option_label("view", v), d])
			prev = d
		for n in tree.get_nodes_in_group("poi_props"):
			check(is_equal_approx((n as GeometryInstance3D).visibility_range_end, Quality.props_distance()),
				"дальность «%s»: мелочи построек до %.0f м" % [Quality.option_label("view", v), Quality.props_distance()])
			break
	check(not tree.get_nodes_in_group("poi_props").is_empty(), "мелочи построек в группе poi_props")

	# Густота травы — при следующем построении
	var dens: Array[float] = []
	for v in Quality.option_count("grass"):
		Quality.set_option("grass", v, false)
		dens.append(Quality.grass_density())
	check(dens[0] < dens[1] and dens[1] < dens[2], "густота травы растёт: %s" % [dens])
	check(IslandVegetation.built_grass(tree) >= 0, "известно, с какой густотой построена трава")

	# Текстуры
	for v in Quality.option_count("textures"):
		Quality.set_option("textures", v, false)
		Quality.apply(tree)
		check(Quality.textures() == (v >= 1) and Quality.rich_shaders() == (v >= 2), "текстуры «%s»" % Quality.option_label("textures", v))
		if IslandWorld.current != null and IslandWorld.current.terrain_material != null:
			check(bool(IslandWorld.current.terrain_material.get_shader_parameter("rich")) == (v >= 2),
				"текстуры «%s»: земля" % Quality.option_label("textures", v))

	# Контуры и тени на моделях — у уже созданного героя сразу
	var mats: Array[StandardMaterial3D] = main.player._model._flash_mats
	check(not mats.is_empty(), "у модели героя есть материалы")
	if not mats.is_empty():
		var m: StandardMaterial3D = mats[0]
		Quality.set_option("outlines", 0, false)
		Quality.apply(tree)
		check(m.next_pass == null, "контуры «Выкл»: у героя контура нет")
		Quality.set_option("outlines", 1, false)
		Quality.apply(tree)
		check(m.next_pass != null, "контуры «Вкл»: у героя контур есть")
		Quality.set_option("model_shadows", 0, false)
		Quality.apply(tree)
		check(m.disable_receive_shadows, "тени на персонажах «Выкл»: модель не затеняет сама себя")
		Quality.set_option("model_shadows", 1, false)
		Quality.apply(tree)
		check(not m.disable_receive_shadows, "тени на персонажах «Вкл»: карта теней на модели")
		Quality.set_option("model_shadows", 0, false)
		Quality.apply(tree)

	# Эффекты
	var parts: Array[int] = []
	for v in Quality.option_count("effects"):
		Quality.set_option("effects", v, false)
		parts.append(Quality.particles(8))
	check(parts[0] < parts[1] and parts[1] < parts[2] and parts[2] == 8 and Quality.particles(1) >= 1,
		"частиц эффектов: %s" % [parts])


## Шейдеры: тень карты теней мягко в cel-полосе, лимит сэмплеров toon.gdshader.
func _check_shaders() -> void:
	var toon := load("res://toon.gdshader") as Shader
	var prop := load("res://prop.gdshader") as Shader
	check(toon != null and prop != null, "шейдеры загружены")
	if toon == null or prop == null:
		return
	check(toon.code.count("sampler2D") <= 8, "toon.gdshader: сэмплеров %d (предел 8)" % toon.code.count("sampler2D"))
	for sh in [toon, prop]:
		var code := (sh as Shader).code
		check(code.contains("smoothstep(shadow_lo, shadow_hi, ATTENUATION)") and not code.contains("ATTENUATION * 2.0 - 1.0"),
			"%s: тень — мягкая ступенька, не порог" % (sh as Shader).resource_path)


## Окно настроек: вкладки и кнопки всех настроек, нажатие применяет и открывает окно заново.
func _check_menu() -> void:
	var hud: HUD = main.hud
	SettingsMenu.open(hud)
	for t in ["tab_graphics", "tab_ui", "tab_other", "ui_0", "fps_30", "fps_60"]:
		check(SettingsMenu.buttons.has(t), "в настройках кнопка %s" % t)
	for l in Quality.ULTRA + 1:
		check(SettingsMenu.buttons.has("quality_%d" % l), "кнопка пресета %d" % l)
	for k in Quality.OPTIONS:
		for v in Quality.option_count(String(k)):
			check(SettingsMenu.buttons.has("%s_%d" % [k, v]), "кнопка %s_%d" % [k, v])
	check(SettingsMenu.buttons.has("admin") == AdminPanel.ADMIN_TOOLS, "админ-панель — во вкладке «Прочее»")
	check((SettingsMenu.buttons["quality_1"] as Button).button_pressed, "выбран пресет «Среднее»")
	(SettingsMenu.buttons["shadows_3"] as Button).pressed.emit()
	check(Quality.option("shadows") == 3 and Quality.level() == Quality.CUSTOM, "кнопка «Тени: Высокие» — «Свои»")
	var sun := _sun()
	check(sun != null and sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "тени применены сразу")
	check(SettingsMenu.tab == "graphics" and (SettingsMenu.buttons["shadows_3"] as Button).button_pressed,
		"окно открыто заново на вкладке «Графика»")
	(SettingsMenu.buttons["tab_other"] as Button).pressed.emit()
	check(SettingsMenu.tab == "other", "вкладка «Прочее»")
	(SettingsMenu.buttons["tab_ui"] as Button).pressed.emit()
	check(SettingsMenu.tab == "ui", "вкладка «Интерфейс»")
	(SettingsMenu.buttons["quality_1"] as Button).pressed.emit()
	check(Quality.level() == Quality.MEDIUM and SettingsMenu.tab == "graphics", "пресет «Среднее» кнопкой")


func _restore() -> void:
	if _had_cfg:
		var f := FileAccess.open(Quality.PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(_cfg_backup)
			f.close()
	elif FileAccess.file_exists(Quality.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Quality.PATH))
	Quality.reload()
	UiScale.reload()
	Quality.apply(get_tree())


func _sun() -> DirectionalLight3D:
	for n in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
		return n as DirectionalLight3D
	return null


func _fx() -> PostFx:
	for n in get_tree().get_nodes_in_group("postfx"):
		return n as PostFx
	return null
