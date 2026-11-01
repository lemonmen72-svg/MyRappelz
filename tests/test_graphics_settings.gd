extends "res://tests/test_base.gd"
## Настройки графики (Quality, вкладка «Графика» окна настроек): пресеты «Низкое / Среднее / Высокое /
## Максимальное», ручное изменение → «Свои» (и обратно, если совпало с пресетом), сохранение в user://settings.cfg
## и загрузка (в том числе старого файла только с quality), применение к окну (MSAA, масштаб 3D), солнцу (тени,
## каскады, дальность), постобработке (FXAA, цвет, свечение), растительности и мелочам построек (дальность), контурам
## и теням на моделях персонажей; каждая настройка меняет то, что должна. Окно настроек: вкладки, кнопки всех
## настроек, нажатие применяет сразу. Лимит сэмплеров toon.gdshader (8) не превышен.
## Бережение телефона: предел кадров пресета, порог LOD, тени 2 каскада в атласе 2048, контур дальних моделей
## (ModelLod) и участков растительности (двойники без контура), предел кадров окна, экрана до мира и фона,
## авто-снижение ThermalGuard по подставному статусу температуры и по времени кадра (шаги, потолки поверх выбранного,
## восстановление, гистерезис, повторный нагрев), выключатель «Беречь от перегрева».
## Без мигания (жалоба Максима 0.24: «лесенка» уменьшенных копий кадра и мигание при открытой сумке, выборе зелья,
## смене оружия): открытие окна, выбор предмета, смена оружия не меняют параметров окна (MSAA, масштаб 3D) и теней,
## Quality.apply не вызывается; атлас теней один; под окном ThermalGuard графику не переключает и предел окна
## (30 к/с) за «медленные кадры» не считает; MSAA при уменьшенном 3D-кадре на Android заменяется FXAA; PostFx —
## без mip-уровней экранной текстуры.

var _had_cfg := false
var _cfg_backup := ""
## Подставной статус температуры Android для ThermalGuard (−1 — неизвестно).
var _fake_status := -1


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
			_stability_begin()
			wait = 3
			step = 5
		5:
			_stability_end()
			_check_msaa_scaled()
			_check_postfx_no_mips()
			_check_model_lod()
			_check_fps_caps()
			_check_thermal()
			_check_thermal_window()
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
		check(fx != null and fx.visible == (Quality.postfx_fxaa() or Quality.postfx()), "«%s»: постобработка" % Quality.level_name(l))
		check(is_equal_approx(win.mesh_lod_threshold, Quality.lod_threshold()), "«%s»: порог LOD %.2f"
			% [Quality.level_name(l), win.mesh_lod_threshold])
		check(Quality.fps_limit() == int(Quality.PRESET_FPS[l]), "«%s»: предел кадров пресета %d"
			% [Quality.level_name(l), Quality.fps_limit()])
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
	# Бережение телефона: «Высокое» и «Максимальное» — не родное разрешение и не больше 45 кадров/с; тени — не больше
	# 2 каскадов в атласе 2048; дальше — меньше подробностей (порог LOD не ниже)
	for l in [Quality.HIGH, Quality.ULTRA]:
		var pr: Dictionary = Quality.PRESETS[l]
		check(Quality.RENDER_HEIGHTS[int(pr["render"])] > 0, "пресет %d: не родное разрешение (нагрев)" % l)
		check(int(Quality.PRESET_FPS[l]) <= 45, "пресет %d: не больше 45 кадров/с" % l)
	for lvl in Quality.SHADOW_LEVELS:
		var sl: Dictionary = lvl
		if not sl.is_empty():
			check(int(sl["atlas"]) <= 2048 and int(sl["splits"]) == 2, "тени: атлас %d, каскадов %d" % [sl["atlas"],
				sl["splits"]])
	for i in range(1, Quality.VIEW_LEVELS.size()):
		var a: Dictionary = Quality.VIEW_LEVELS[i - 1]
		var b: Dictionary = Quality.VIEW_LEVELS[i]
		check(float(b["lod"]) <= float(a["lod"]) and float(b["outline"]) >= float(a["outline"]),
			"дальность %d: порог LOD и дальность контура" % i)


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
		if int(lvl["splits"]) >= 4:  # сейчас у всех уровней 2 каскада
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
			var d := IslandVegetation.range_end_of(trees[0] as GeometryInstance3D)
			check(d > prev, "дальность «%s»: деревья до %.0f м" % [Quality.option_label("view", v), d])
			prev = d
		check(is_equal_approx(win.mesh_lod_threshold, Quality.lod_threshold()), "дальность «%s»: порог LOD %.2f"
			% [Quality.option_label("view", v), win.mesh_lod_threshold])
		for n in tree.get_nodes_in_group("poi_props"):
			check(is_equal_approx((n as GeometryInstance3D).visibility_range_end, Quality.props_distance()),
				"дальность «%s»: мелочи построек до %.0f м" % [Quality.option_label("view", v), Quality.props_distance()])
			break
	check(not tree.get_nodes_in_group("poi_props").is_empty(), "мелочи построек в группе poi_props")
	_check_veg_twins()

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
		if m.next_pass != null:
			# Разбор: отслеживается ли материал героя (Quality._model_mats / _outline_mats)
			var in_model := false
			for wr in Quality._model_mats:
				if wr.get_ref() == m:
					in_model = true
			var in_ol := false
			for wr in Quality._outline_mats:
				if wr.get_ref() == m:
					in_ol = true
			print("  контур героя: в _model_mats %s, в _outline_mats %s (%d / %d), meta outline %s, next_pass %s, материалов %d"
				% [in_model, in_ol, Quality._model_mats.size(), Quality._outline_mats.size(), m.has_meta("outline"),
				m.next_pass, mats.size()])
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
	var samplers := toon.code.count("uniform sampler2D")
	check(samplers <= 8, "toon.gdshader: сэмплеров %d (предел 8)" % samplers)
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
	for t in ["guard_0", "guard_1"]:
		check(SettingsMenu.buttons.has(t), "в настройках кнопка %s" % t)
	check((SettingsMenu.buttons["guard_1"] as Button).button_pressed, "«Беречь от перегрева» — по умолчанию вкл")
	(SettingsMenu.buttons["shadows_3"] as Button).pressed.emit()
	check(Quality.option("shadows") == 3 and Quality.level() == Quality.CUSTOM, "кнопка «Тени: Высокие» — «Свои»")
	var sun := _sun()
	check(sun != null and is_equal_approx(sun.directional_shadow_max_distance, float(Quality.SHADOW_LEVELS[3]["distance"])),
		"тени применены сразу")
	(SettingsMenu.buttons["guard_0"] as Button).pressed.emit()
	check(not Quality.guard_enabled(), "кнопка «Беречь от перегрева: Выкл»")
	(SettingsMenu.buttons["guard_1"] as Button).pressed.emit()
	check(Quality.guard_enabled(), "кнопка «Беречь от перегрева: Вкл»")
	check(SettingsMenu.tab == "graphics" and (SettingsMenu.buttons["shadows_3"] as Button).button_pressed,
		"окно открыто заново на вкладке «Графика»")
	(SettingsMenu.buttons["tab_other"] as Button).pressed.emit()
	check(SettingsMenu.tab == "other", "вкладка «Прочее»")
	(SettingsMenu.buttons["tab_ui"] as Button).pressed.emit()
	check(SettingsMenu.tab == "ui", "вкладка «Интерфейс»")
	(SettingsMenu.buttons["quality_1"] as Button).pressed.emit()
	check(Quality.level() == Quality.MEDIUM and SettingsMenu.tab == "graphics", "пресет «Среднее» кнопкой")


## Участки деревьев, кустов и камней: контур — только вблизи, дальше — двойник того же меша без контура.
func _check_veg_twins() -> void:
	var tree := get_tree()
	Quality.set_level(Quality.ULTRA, false)
	Quality.apply(tree)
	var twins := 0
	for n in tree.get_nodes_in_group("veg_trees") + tree.get_nodes_in_group("veg_small"):
		var gi := n as GeometryInstance3D
		var twin := gi.get_meta("far_twin", null) as MeshInstance3D
		if twin == null:
			continue
		twins += 1
		var mi := gi as MeshInstance3D
		check(twin.mesh == mi.mesh, "двойник участка — тот же меш")
		check(twin.material_override != null and twin.material_override.next_pass == null
			and not twin.material_override.has_meta("outline"), "двойник участка без контура")
		check(mi.material_override.next_pass != null, "участок вблизи — с контуром")
		check(twin.visible and is_equal_approx(gi.visibility_range_end, Quality.veg_outline_far())
			and is_equal_approx(twin.visibility_range_begin, Quality.veg_outline_far())
			and twin.visibility_range_end > twin.visibility_range_begin, "контур участка до %.0f м, дальше — двойник до %.0f м"
			% [gi.visibility_range_end, twin.visibility_range_end])
		check(twin.cast_shadow == gi.cast_shadow, "у двойника те же тени")
		break
	check(twins > 0, "у участков растительности с контуром есть двойники")
	Quality.set_option("outlines", 0, false)
	Quality.apply(tree)
	for n in tree.get_nodes_in_group("veg_trees"):
		var gi := n as GeometryInstance3D
		var twin := gi.get_meta("far_twin", null) as MeshInstance3D
		if twin != null:
			check(not twin.visible and gi.visibility_range_end > Quality.veg_outline_far() + 1.0,
				"контуры «Выкл»: двойник скрыт, участок до %.0f м" % gi.visibility_range_end)
			break
	Quality.set_level(Quality.MEDIUM, false)
	Quality.apply(tree)


## Контур дальних моделей (ModelLod): камера далеко — у героя контур снят, Quality.apply его не возвращает; ближе —
## снова есть. Жители за кадром: pause_offscreen (в headless сигналов видимости нет — житель анимируется).
func _check_model_lod() -> void:
	var tree := get_tree()
	Quality.set_level(Quality.MEDIUM, false)
	Quality.apply(tree)
	check(ModelLod.count() > 0, "модели под наблюдением ModelLod: %d" % ModelLod.count())
	var mats: Array[StandardMaterial3D] = main.player._model._flash_mats
	if mats.is_empty():
		return
	var m: StandardMaterial3D = mats[0]
	var cam: Camera3D = main.cam
	var keep := cam.global_position
	ModelLod.update_all()
	check(m.next_pass != null and not ModelLod.is_far(m), "герой рядом с камерой — с контуром")
	cam.global_position = main.player.global_position + Vector3(0, Quality.outline_far() + 30.0, 0)
	ModelLod.update_all()
	check(m.next_pass == null and ModelLod.is_far(m), "камера в %.0f м — контур героя снят" % (Quality.outline_far() + 30.0))
	Quality.apply(tree)
	check(m.next_pass == null, "Quality.apply не возвращает контур дальней модели")
	cam.global_position = main.player.global_position + Vector3(0, Quality.outline_far() + ModelLod.HYST * 0.5, 0)
	ModelLod.update_all()
	check(m.next_pass == null, "у границы (запас %.0f м) контур не мигает" % ModelLod.HYST)
	cam.global_position = keep
	ModelLod.update_all()
	check(m.next_pass != null and not ModelLod.is_far(m), "камера снова рядом — контур есть")
	var npcs := tree.get_nodes_in_group("npc")
	check(not npcs.is_empty(), "жители есть")
	for n in npcs:
		var cm := n.get_node_or_null("Model") as CharacterModel
		if cm != null and cm._anim != null:
			check(cm.has_node("OnScreen"), "у жителя проверка видимости (за кадром не анимируется)")
			check(not cm.is_offscreen(), "без отрисовки житель анимируется")
			break


## Предел кадров: окно и экран до мира — не больше MENU_FPS, фон — BACKGROUND_FPS, авто-снижение — потолок шага.
func _check_fps_caps() -> void:
	Quality.set_level(Quality.ULTRA, false)
	check(Quality.current_fps_cap() == 45, "«Максимальное»: 45 кадров/с")
	Quality.set_menu_open(true)
	check(Quality.current_fps_cap() == Quality.MENU_FPS, "окно открыто — %d кадров/с" % Quality.MENU_FPS)
	Quality.set_menu_open(false)
	Quality.set_screen_idle(true)
	check(Quality.current_fps_cap() == Quality.MENU_FPS and Quality.menu_open(), "экран до мира — %d кадров/с" % Quality.MENU_FPS)
	Quality.set_screen_idle(false)
	Quality.set_background(true)
	check(Quality.current_fps_cap() == Quality.BACKGROUND_FPS, "игра без фокуса — %d кадров/с" % Quality.BACKGROUND_FPS)
	Quality.set_background(false)
	check(Quality.current_fps_cap() == 45 and not Quality.menu_open(), "снова 45 кадров/с")
	Quality.set_fps_limit(60, false)
	Quality.set_throttle(1)
	check(Quality.current_fps_cap() == 30 and Quality.fps_limit() == 60, "шаг 1 авто-снижения — 30 кадров/с, выбор игрока тот же")
	Quality.set_throttle(0)


## Авто-снижение ThermalGuard: подставной статус температуры, затем время кадра. Шаги вниз не чаще STEP_GAP,
## потолки поверх выбранного, восстановление после COOL_TIME прохлады, повторный нагрев — вдвое дольше.
func _check_thermal() -> void:
	var tree := get_tree()
	var g := ThermalGuard.current
	check(g != null, "ThermalGuard в главной сцене")
	if g == null:
		return
	check(not g.active(), "в автотестах авто-снижение выключено (без force)")
	Quality.set_level(Quality.ULTRA, false)
	Quality.set_guard_enabled(true, false)
	Quality.apply(tree)
	g.force = true
	g.status_source = func() -> int: return _fake_status
	g.headroom_source = func() -> int: return -1
	g.reset()
	g._settle = 0.0
	var fast := 1.0 / 45.0
	_fake_status = 0
	_ticks(g, 3, 5.0, fast)
	check(Quality.throttle_level() == 0, "прохладно — графика как выбрана")
	# Нагрелся (MODERATE): шаг 1 — кадры/с
	_fake_status = 2
	_ticks(g, 1, 5.0, fast)
	check(Quality.throttle_level() == 1 and g.reason == "thermal" and Quality.current_fps_cap() == 30,
		"нагрелся — шаг 1: 30 кадров/с (шаг %d)" % Quality.throttle_level())
	_ticks(g, 4, 5.0, fast)
	check(Quality.throttle_level() == 1, "следующий шаг — не раньше %.0f с" % ThermalGuard.STEP_GAP)
	_ticks(g, 2, 5.0, fast)
	check(Quality.throttle_level() == 2, "всё ещё горячо — шаг 2")
	var win := tree.root
	check(Quality.render_height() == 720 and Quality.option("render") == int(Quality.PRESETS[Quality.ULTRA]["render"]),
		"шаг 2: разрешение 720p, выбор игрока не изменился")
	check(is_equal_approx(win.scaling_3d_scale, Quality.render_scale_for(float(win.size.y))), "шаг 2 применён к окну")
	# SEVERE — шаги чаще
	_fake_status = 3
	_ticks(g, 2, 5.0, fast)
	check(Quality.throttle_level() == 3, "сильный нагрев — шаг 3 через %.0f с" % ThermalGuard.STEP_GAP_SEVERE)
	var sun := _sun()
	check(sun != null and is_equal_approx(sun.directional_shadow_max_distance, float(Quality.SHADOW_LEVELS[1]["distance"])),
		"шаг 3: тени «Низкие»")
	check(Quality.option("shadows") == 3, "шаг 3: выбор игрока — «Высокие»")
	# CRITICAL — сразу последний шаг
	_fake_status = 4
	_ticks(g, 2, 5.0, fast)
	check(Quality.throttle_level() == Quality.throttle_max(), "критический нагрев — последний шаг")
	check(sun != null and not sun.shadow_enabled and tree.root.msaa_3d == Viewport.MSAA_DISABLED and not Quality.outlines(),
		"последний шаг: без теней, сглаживания и контуров")
	# Остыл: шаг вверх только после COOL_TIME прохлады (гистерезис)
	_fake_status = 0
	_ticks(g, 6, 5.0, 1.0 / 30.0)
	check(Quality.throttle_level() == Quality.throttle_max(), "остывает — через 30 с ещё снижено")
	_ticks(g, 7, 5.0, 1.0 / 30.0)
	check(Quality.throttle_level() == Quality.throttle_max() - 1, "прохладно %.0f с — шаг вверх (шаг %d)"
		% [ThermalGuard.COOL_TIME, Quality.throttle_level()])
	# Снова нагрелся вскоре — прохлады теперь нужно вдвое дольше
	_fake_status = 2
	_ticks(g, 7, 5.0, 1.0 / 30.0)
	check(Quality.throttle_level() == Quality.throttle_max(), "снова горячо — шаг вниз")
	check(is_equal_approx(g.cool_need(), ThermalGuard.COOL_TIME * 2.0), "повторный нагрев — прохлады нужно %.0f с"
		% g.cool_need())
	# Без данных о температуре — по времени кадра
	_fake_status = -1
	g.reset()
	check(Quality.throttle_level() == 0 and is_equal_approx(g.cool_need(), ThermalGuard.COOL_TIME), "сброс авто-снижения")
	g._settle = 0.0
	_ticks(g, 20, 0.5, 0.06)
	check(Quality.throttle_level() == 0, "долгий кадр меньше %.0f с — не снижаем" % ThermalGuard.SLOW_TIME)
	_ticks(g, 12, 0.5, 0.06)
	check(Quality.throttle_level() == 1 and g.reason == "frames", "кадр стабильно дольше бюджета — шаг 1 (кадр %.1f мс)"
		% (g.frame_avg * 1000.0))
	# кадр короче бюджета и без снижения (на 0-м шаге бюджет — предел кадров пресета, 60 к/с)
	_ticks(g, 30, 5.0, 1.0 / 120.0)
	check(Quality.throttle_level() == 0, "кадры успевают — графика восстановлена")
	# Выключили «Беречь от перегрева» — сразу как выбрано, авто-снижение стоит
	_fake_status = 4
	Quality.set_guard_enabled(false, false)
	g.reset()
	check(not g.active() and Quality.throttle_level() == 0, "«Беречь от перегрева» выкл — графика как выбрана")
	Quality.set_guard_enabled(true, false)
	g.force = false
	g.status_source = Callable()
	g.headroom_source = Callable()
	_fake_status = -1
	Quality.set_throttle(0)
	Quality.set_level(Quality.MEDIUM, false)
	Quality.apply(tree)


## Снимок того, что пересоздаёт буферы кадра или атлас теней при изменении (окно, солнце, счётчики Quality).
var _snap: Dictionary = {}


func _render_state() -> Dictionary:
	var win := get_tree().root
	var sun := _sun()
	return {
		"msaa": win.msaa_3d, "scale": win.scaling_3d_scale, "mode": win.scaling_3d_mode, "ssaa": win.screen_space_aa,
		"size": win.size, "applies": Quality.apply_count, "rs": Quality.shadow_rs_changes,
		"shadow": sun.shadow_enabled if sun != null else false,
		"shadow_mode": sun.directional_shadow_mode if sun != null else -1,
		"shadow_dist": sun.directional_shadow_max_distance if sun != null else 0.0,
		"postfx": _fx().current_shader() if _fx() != null else null,
	}


## Открыть сумку, выбрать зелье, надеть другое оружие (кнопка «Надеть»), закрыть — на «Максимальном».
func _stability_begin() -> void:
	var tree := get_tree()
	Quality.set_level(Quality.ULTRA, false)
	Quality.apply(tree)
	var inv: Inventory = Game.inventory
	inv.add("potion_hp_r1", 3)
	inv.add("weapon_sword_1h_r1", 1)
	_snap = _render_state()
	var eco: Economy = main.economy
	eco.open_bag()
	check(main.hud.is_window_open() and Quality.menu_open(), "сумка открыта, предел окна")
	var win: InventoryWindow = eco.window
	win.select_cell(inv.find_cell("potion_hp_r1"))
	check(win.sel_id == "potion_hp_r1", "в сумке выбрано зелье")
	var before := Game.weapon
	var wc := inv.find_cell("weapon_sword_1h_r1")
	check(wc >= 0, "запасной меч в сумке")
	if wc >= 0:
		win.select_cell(wc)
		win.call("_on_equip")
	check(Game.weapon == "weapon_sword_1h_r1" and before != Game.weapon, "оружие сменено (%s → %s)" % [before,
		Game.weapon])


func _stability_end() -> void:
	var now := _render_state()
	for k in _snap:
		check(now[k] == _snap[k], "сумка, выбор зелья, смена оружия: «%s» не изменилось (%s → %s)" % [k, str(_snap[k]),
			str(now[k])])
	main.economy.window.close()
	check(not main.hud.is_window_open() and not Quality.menu_open(), "сумка закрыта")
	check(Quality._last_atlas == Quality.SHADOW_ATLAS, "атлас теней задан один раз: %d" % Quality._last_atlas)
	for lvl in Quality.SHADOW_LEVELS:
		var sl: Dictionary = lvl
		if not sl.is_empty():
			check(int(sl["atlas"]) == Quality.SHADOW_ATLAS, "у всех уровней теней один атлас %d" % Quality.SHADOW_ATLAS)
	# Смена уровня теней (пресеты, авто-снижение) атлас не трогает: только фильтр (в GLES3 — поле, без пересоздания)
	var rs := Quality.shadow_rs_changes
	var filters := {}
	for v in Quality.option_count("shadows"):
		Quality.set_option("shadows", v, false)
		Quality.apply(get_tree())
		filters[Quality.shadow_filter()] = true
		check(Quality._last_atlas == Quality.SHADOW_ATLAS, "тени «%s»: атлас тот же" % Quality.option_label("shadows", v))
	check(Quality.shadow_rs_changes - rs <= filters.size(), "смена теней: передач RenderingServer %d — только фильтр"
		% (Quality.shadow_rs_changes - rs))
	Quality.set_level(Quality.MEDIUM, false)
	Quality.apply(get_tree())


## MSAA при уменьшенном 3D-кадре (Android, Compatibility): Godot 4.3 каждый кадр создаёт новый framebuffer
## (утечка, upstream #124258) — вместо MSAA FXAA своим проходом; кадр не меньше экрана — MSAA как было.
func _check_msaa_scaled() -> void:
	var tree := get_tree()
	var win := tree.root
	Quality.renderer_override = 0
	Quality.msaa_scaled_override = 0
	Quality.set_level(Quality.ULTRA, false)
	check(int(Quality.render_params(1080.0)["msaa"]) == Viewport.MSAA_4X, "ПК: MSAA 4× и при 900p на экране 1080")
	Quality.msaa_scaled_override = 1
	var p := Quality.render_params(1080.0)
	check(int(p["msaa"]) == Viewport.MSAA_DISABLED and bool(p["postfx_fxaa"]),
		"Android, 900p на экране 1080: MSAA → FXAA PostFx")
	var p_native := Quality.render_params(900.0)
	check(int(p_native["msaa"]) == Viewport.MSAA_4X and not bool(p_native["postfx_fxaa"]),
		"Android, кадр не меньше экрана: MSAA 4× как выбрано")
	Quality.set_level(Quality.LOW, false)
	check(int(Quality.render_params(1080.0)["msaa"]) == Viewport.MSAA_DISABLED
		and not bool(Quality.render_params(1080.0)["postfx_fxaa"]), "«Низкое» без сглаживания — замены нет")
	# На окне: 540p ниже окна — MSAA выключено, в PostFx — FXAA
	Quality.set_level(Quality.MEDIUM, false)
	Quality.set_option("render", 0, false)
	Quality.apply(tree)
	if Quality.render_scale_for(float(win.size.y)) < 0.9999:
		check(win.msaa_3d == Viewport.MSAA_DISABLED, "Android, 540p: окно без MSAA")
		var fx := _fx()
		var sh: Shader = fx.current_shader() if fx != null else null
		check(sh != null and sh.code.contains("#define USE_FXAA"), "Android, 540p: FXAA в PostFx вместо MSAA")
		check(Quality.option_hint("aa").contains("заменяется на FXAA"), "подсказка о замене MSAA")
	Quality.msaa_scaled_override = -1
	Quality.renderer_override = -1
	Quality.set_level(Quality.MEDIUM, false)
	Quality.apply(tree)
	check(win.msaa_3d == Quality.chosen_msaa(), "ПК: MSAA как выбрано")


## PostFx не читает mip-уровни экранной текстуры (в Compatibility 4.3 их построение — CopyEffects::gaussian_blur
## по уровням того же backbuffer каждый кадр).
func _check_postfx_no_mips() -> void:
	var code := (load(PostFx.SHADER_PATH) as Shader).code
	check(not code.contains("_mipmap"), "postfx.gdshader: экранная текстура без фильтра mipmap")
	check(not code.contains("texture(screen_tex"), "postfx.gdshader: выборки только textureLod")
	check(code.count("textureLod(") == code.count(", 0.0)"), "postfx.gdshader: textureLod только нулевого уровня")


## Под окном (предел 30 к/с при пресете 45) ThermalGuard не снижает графику: кадры 33 мс — не «медленные», нагрев —
## шаг откладывается до закрытия окна.
func _check_thermal_window() -> void:
	var tree := get_tree()
	var g := ThermalGuard.current
	if g == null:
		return
	Quality.set_level(Quality.ULTRA, false)
	Quality.set_guard_enabled(true, false)
	Quality.apply(tree)
	g.force = true
	g.status_source = func() -> int: return _fake_status
	g.headroom_source = func() -> int: return -1
	_fake_status = -1
	g.reset()
	g._settle = 0.0
	var snap := _render_state()
	Quality.set_menu_open(true)
	_ticks(g, 120, 0.5, 1.0 / 30.0)
	check(Quality.throttle_level() == 0, "окно открыто 60 с, кадры 30/с — графика не снижена")
	_fake_status = 2
	var held := g.held_steps
	_ticks(g, 20, 1.0, 1.0 / 30.0)
	check(Quality.throttle_level() == 0 and g.held_steps > held, "нагрелся под окном — шаг отложен")
	var now := _render_state()
	check(now["msaa"] == snap["msaa"] and now["scale"] == snap["scale"] and now["applies"] == snap["applies"],
		"под окном параметры кадра не менялись")
	Quality.set_menu_open(false)
	_ticks(g, 1, 0.5, 1.0 / 45.0)
	check(Quality.throttle_level() == 1, "окно закрыто — отложенный шаг сразу (шаг %d)" % Quality.throttle_level())
	_fake_status = -1
	g.force = false
	g.status_source = Callable()
	g.headroom_source = Callable()
	g.reset()
	Quality.set_level(Quality.MEDIUM, false)
	Quality.apply(tree)


func _ticks(g: ThermalGuard, n: int, dt: float, frame_dt: float) -> void:
	for i in n:
		g.tick(dt, frame_dt)


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
