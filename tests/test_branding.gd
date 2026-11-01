extends "res://tests/test_base.gd"
## Название Dark Pact и арты (tools/prepare_branding.py, MenuKit «Арты»): имя проекта и приложения на телефоне,
## пакет Android прежний (com.lemonmen.myrappelz — APK встаёт поверх старого), папка данных user:// прежняя
## (…/godot/app_userdata/MyRappelz — сохранения игроков на ПК и снимки CI на месте), иконка проекта и иконки
## Android (основная 192, адаптивная: фон 432 и прозрачный передний план), заставка — логотип, уведомление фоновой
## загрузки. Файлы: логотип (фон прозрачный) и главный арт — в APK, арты рас и профессий и все 24 портрета — в части
## пакета «art». Экраны подхватывают арт: загрузка ресурсов и вход — главный арт и логотип (помещаются в 720 px при
## любом размере интерфейса), выбор персонажа — портреты по профессии и полу (Бродяга — по расе и полу), у пустого
## слота нет; создание — арт расы на фоне (меняется с расой), карточки профессий с артом; окно мудреца — тоже.
## Без пакета (Assets.simulate_missing) — те же экраны без артов пакета, логотип и главный арт остаются.

const SIZES := [0, 1, 2]

var _screen: CanvasLayer = null
var _li := 0


func race_class() -> Array:
	return ["light_elf", "wizard"]


func run_step() -> void:
	match step:
		0:
			_check_project()
			_check_presets()
			_check_files()
			_screen = LoginScreen.new()
			get_tree().root.add_child(_screen)
			wait = 3
			step = 1
		1:
			check(_backdrop(_screen) != null and _backdrop(_screen).resource_path == MenuKit.KEY_ART,
				"вход: главный арт на фоне")
			check(_screen.find_child("Logo", true, false) != null, "вход: логотип")
			var band := _screen.get_node_or_null("Band") as Control
			check(band != null and not band.visible, "вход: полоса прежнего фона скрыта")
			_screen.queue_free()
			Accounts.save_slot(1, {"name": "Гром_топор", "race": "human", "class": "warrior", "level": 31, "gender": "m"})
			Accounts.save_slot(2, {"name": "Новичок", "race": "dark_elf", "class": "wanderer", "level": 3, "gender": "f"})
			_screen = CharacterSelect.new()
			get_tree().root.add_child(_screen)
			wait = 3
			step = 2
		2:
			var cs := _screen as CharacterSelect
			check(_backdrop(cs) != null, "выбор персонажа: главный арт на фоне")
			_check_portrait(cs, 0, MenuKit.portrait_path("wizard", "light_elf", "f"), "Волшебница")
			_check_portrait(cs, 1, MenuKit.portrait_path("warrior", "human", "m"), "Воин")
			_check_portrait(cs, 2, "res://assets/art/pack/portraits/wanderer_dark_elf_f.png", "Бродяга — по расе и полу")
			check(cs.portrait_of(3) == null, "пустой слот — без портрета")
			_screen.queue_free()
			_screen = CharacterCreate.new()
			get_tree().root.add_child(_screen)
			wait = 3
			step = 3
		3:
			var cc := _screen as CharacterCreate
			check(cc.step == 0 and cc.backdrop() != null
				and cc.backdrop().resource_path == MenuKit.race_art_path(cc._race), "шаг «Раса»: арт расы на фоне")
			check(cc._race_info != null and cc._race_info.get_child_count() >= 5, "шаг «Раса»: описание расы слева")
			cc._select_race("human")
			check(cc.step == 0 and cc.backdrop() != null and cc.backdrop().resource_path == MenuKit.race_art_path("human")
				and cc._race_cards.size() == 3, "другая раса — её арт, карточки рас на месте")
			check(cc.go_next() and cc._job_cards.size() == 3, "шаг «Профессии»")
			var jobs := ClassData.jobs_of("human")
			for i in cc._job_cards.size():
				var head := cc._job_cards[i].find_child("JobArt", true, false)
				check(head != null, "карточка «%s»: арт профессии" % ClassData.job_name(String(jobs[i])))
				if head != null:
					var t := head.find_child("ArtTitle", true, false) as Label
					check(t != null and t.text == ClassData.job_name(String(jobs[i])), "имя профессии внизу арта")
					var pic := head.find_child("Art", true, false) as TextureRect
					var at: AtlasTexture = null
					if pic != null:
						at = pic.texture as AtlasTexture
					check(at != null and at.atlas.resource_path == MenuKit.job_art_path(String(jobs[i])),
						"арт своей профессии")
			_screen.queue_free()
			_screen = null
			main.job_window.open("")
			wait = 3
			step = 4
		4:
			var arts: Array = main.hud._window.find_children("JobArt", "", true, false)
			check(arts.size() == 3, "окно мудреца: арты трёх профессий (%d)" % arts.size())
			main.hud.close_window()
			# Без пакета ресурсов: арты пакета пропадают, логотип и главный арт — нет (они в APK)
			Assets.simulate_missing(true)
			check(MenuKit.art(MenuKit.race_art_path("human")) == null and MenuKit.art(MenuKit.KEY_ART) != null
				and MenuKit.art(MenuKit.LOGO) != null, "без пакета: арта расы нет, главный арт и логотип есть")
			_screen = CharacterSelect.new()
			get_tree().root.add_child(_screen)
			wait = 3
			step = 5
		5:
			var cs := _screen as CharacterSelect
			check(cs.portrait_of(0) == null and cs.portrait_of(1) == null and cs.cards.size() == Accounts.SLOTS,
				"без пакета: карточки без портретов")
			check(_backdrop(cs) != null, "без пакета: главный арт на фоне выбора остаётся")
			_screen.queue_free()
			_screen = CharacterCreate.new()
			get_tree().root.add_child(_screen)
			wait = 3
			step = 6
		6:
			var cc := _screen as CharacterCreate
			var band := cc.get_node_or_null("Band") as Control
			check(cc.backdrop() == null and band != null and band.visible, "без пакета: шаг «Раса» — прежний фон")
			check(cc._race_info != null and cc._race_info.get_child_count() >= 5, "без пакета: описание расы есть")
			cc.go_next()
			check(cc._job_cards.size() == 3 and cc._job_cards[0].find_child("JobArt", true, false) == null,
				"без пакета: карточки профессий без арта")
			_screen.queue_free()
			_screen = null
			main.job_window.open("")
			check(main.hud._window.find_children("JobArt", "", true, false).is_empty(), "без пакета: окно мудреца без артов")
			main.hud.close_window()
			Assets.simulate_missing(false)
			Accounts.delete_slot(1)
			Accounts.delete_slot(2)
			_li = 0
			_open_loader()
			step = 7
		7:
			_check_loader()
			_screen.queue_free()
			_screen = null
			_li += 1
			if _li < SIZES.size():
				_open_loader()
				return
			UiScale.set_level(UiScale.MEDIUM, false)
			ok_done()


## Имя проекта, папка данных, иконка, заставка, уведомление.
func _check_project() -> void:
	check(String(ProjectSettings.get_setting("application/config/name", "")) == "Dark Pact", "название проекта — Dark Pact")
	check(bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false))
		and String(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")) == "godot/app_userdata/MyRappelz",
		"папка данных задана прежней")
	var ud := OS.get_user_data_dir().replace("\\", "/")
	check(ud.ends_with("godot/app_userdata/MyRappelz") or OS.get_name() != "Linux",
		"user:// — прежняя папка MyRappelz: %s" % ud)
	var icon := String(ProjectSettings.get_setting("application/config/icon", ""))
	check(icon == "res://assets/branding/icon.png" and FileAccess.file_exists(icon), "иконка проекта: %s" % icon)
	check(String(ProjectSettings.get_setting("application/boot_splash/image", "")) == MenuKit.LOGO,
		"заставка — логотип Dark Pact")
	check(AssetLoader.NOTIFY_TITLE.begins_with("Dark Pact"), "уведомление загрузки: %s" % AssetLoader.NOTIFY_TITLE)


## Пресет «Android»: имя на телефоне, прежний пакет, иконки лаунчера.
func _check_presets() -> void:
	var cfg := ConfigFile.new()
	check(cfg.load("res://export_presets.cfg") == OK, "export_presets.cfg читается")
	var opt := ""
	for sec in cfg.get_sections():
		if sec.begins_with("preset.") and not sec.ends_with(".options") and String(cfg.get_value(sec, "name", "")) == "Android":
			opt = sec + ".options"
	check(opt != "", "пресет «Android»")
	if opt == "":
		return
	check(String(cfg.get_value(opt, "package/name", "")) == "Dark Pact", "имя приложения на телефоне — Dark Pact")
	check(String(cfg.get_value(opt, "package/unique_name", "")) == "com.lemonmen.myrappelz",
		"пакет прежний — APK встаёт поверх старого")
	var want := {"launcher_icons/main_192x192": 192, "launcher_icons/adaptive_foreground_432x432": 432,
		"launcher_icons/adaptive_background_432x432": 432}
	for k in want:
		var path := String(cfg.get_value(opt, String(k), ""))
		var img: Image = null
		if path != "":
			img = Image.load_from_file(ProjectSettings.globalize_path(path))
		check(img != null and img.get_width() == int(want[k]) and img.get_height() == int(want[k]),
			"%s: %s %s" % [k, path, str(img.get_size()) if img != null else "нет"])
		if img != null and String(k).contains("foreground"):
			img.convert(Image.FORMAT_RGBA8)
			var opaque := 0
			for y in range(0, img.get_height(), 16):
				for x in range(0, img.get_width(), 16):
					if img.get_pixel(x, y).a > 0.05:
						opaque += 1
			check(opaque == 0, "передний план адаптивной иконки прозрачный (весь арт — на фоне)")


## Арты на месте: логотип и главный арт — в APK, расы, профессии и портреты — в части «art».
func _check_files() -> void:
	for p in [MenuKit.LOGO, MenuKit.KEY_ART]:
		check(ResourceLoader.exists(String(p)) and not Assets.is_packed(String(p)), "%s — в APK" % String(p).get_file())
	check(Assets.PACKS.has("art"), "часть пакета «art»")
	var logo := load(MenuKit.LOGO) as Texture2D
	if logo != null:
		var img := logo.get_image()
		img.convert(Image.FORMAT_RGBA8)
		var clear := 0
		var solid := 0
		var n := 0
		for y in range(0, img.get_height(), 8):
			for x in range(0, img.get_width(), 8):
				var a := img.get_pixel(x, y).a
				n += 1
				if a < 0.1:
					clear += 1
				elif a > 0.9:
					solid += 1
		check(img.get_pixel(0, 0).a < 0.1 and float(clear) > n * 0.2 and float(solid) > n * 0.1,
			"логотип: фон прозрачный (%d из %d), буквы непрозрачны (%d)" % [clear, n, solid])
	var paths: Array = []
	for r in ClassData.RACES:
		paths.append(MenuKit.race_art_path(String(r)))
		for g in ["m", "f"]:
			paths.append(MenuKit.portrait_path(ClassData.WANDERER, String(r), String(g)))
			for j in ClassData.jobs_of(String(r)):
				paths.append(MenuKit.portrait_path(String(j), String(r), String(g)))
		for j in ClassData.jobs_of(String(r)):
			paths.append(MenuKit.job_art_path(String(j)))
	check(paths.size() == 3 + 6 + 18 + 9, "артов пакета: %d" % paths.size())
	for p in paths:
		check(Assets.exists(String(p)) and Assets.part_of(String(p)) == "art", "%s — в части art" % String(p).get_file())


func _check_portrait(cs: CharacterSelect, i: int, path: String, what: String) -> void:
	var pic := cs.portrait_of(i)
	check(pic != null and pic.texture != null and pic.texture.resource_path == path, "портрет: %s (%s)" % [what, path])


func _backdrop(layer: CanvasLayer) -> Texture2D:
	var b := layer.get_node_or_null("Backdrop") as TextureRect
	return b.texture if b != null else null


## Экран загрузки ресурсов при размере интерфейса SIZES[_li] (как без пакета: части «не загружены», без сети).
func _open_loader() -> void:
	UiScale.set_level(int(SIZES[_li]), false)
	Assets.simulate_missing(true)
	var ld := AssetLoader.new()
	ld.offline = true
	ld.preset_manifest = Assets.manifest_from({"format": 2, "version": "0.25.0", "parts": [{"name": "art",
		"hash": "abcdef1234567890", "sha256": "0000000000000000000000000000000000000000000000000000000000000000",
		"size": 4200000, "url": "https://example.invalid/art.pck"}]})
	get_tree().root.add_child(ld)
	_screen = ld
	wait = 3


func _check_loader() -> void:
	var ld := _screen as AssetLoader
	Assets.simulate_missing(false)
	var what := "загрузка ресурсов (%s)" % UiScale.level_name()
	check(ld.state == AssetLoader.State.CONFIRM, "%s: предупреждение о размере" % what)
	check(_backdrop(ld) != null and ld.find_child("Logo", true, false) != null, "%s: главный арт и логотип" % what)
	var center: CenterContainer = null
	for c in ld.get_children():
		if c is CenterContainer:
			center = c as CenterContainer
	var need := Vector2(9999, 9999)
	if center != null and center.get_child_count() > 0:
		need = (center.get_child(0) as Control).get_combined_minimum_size()
	check(need.x <= 1280.0 and need.y <= 720.0 - 2.0 * UiScale.px(16), "%s помещается в 1280×720: %s" % [what, need])
