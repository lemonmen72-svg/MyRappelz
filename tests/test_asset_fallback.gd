extends "res://tests/test_base.gd"
## Игра без пакета ресурсов (APK без единой подключённой части): Assets.simulate_missing(true) и «Играть без загрузки»
## ещё до запуска мира. Мир строится на запасном: постройки, деревья, кусты и камни — процедурные (PoiModels,
## IslandVegetation), текстуры окружения выключены (флаг textures у материалов земли и построек), овец нет, звери и
## питомец — из примитивов (CreatureModels, без CreatureAsset), герой — запасная модель-человек из APK, оружие в руках
## — процедурные меши (нет узлов Handheld), жители — модели из примитивов, значки — процедурные (UiIcons, ItemIcon,
## SkillTree). Открываются окна героя (обе вкладки), сумки, питомцев, существа (обе вкладки), заданий, настроек.
## Под конец — ни один файл частей пакета (Assets.PACKS) не загружен: ResourceLoader.has_cached ложно у каждого.

var packed: Array = []


func race_class() -> Array:
	return ["dark_elf", "assassin"]


func before_start() -> void:
	# Как в APK без пакета: части не подключены, игрок выбрал «Играть без загрузки» — экрана загрузки нет
	Assets.simulate_missing(true)
	Assets.skipped = true
	game.add_pet("panther", "Тень", 5)
	game.active_pet = 0


func run_step() -> void:
	match step:
		0:
			wait = 10
			step = 1
		1:
			packed = _packed_files()
			check(packed.size() > 300, "файлов в частях пакета: %d" % packed.size())
			for part in ["world", "creatures_base", "handheld", "icons"]:
				var n := 0
				for p in packed:
					if Assets.part_of(String(p)) == part:
						n += 1
				check(n > 0, "часть %s: %d файлов" % [part, n])
			check(not Assets.available() and Assets.ready_count() == 0, "пакета нет: частей готово %d" % Assets.ready_count())
			var loaders := 0
			for c in main.get_children():
				if c is AssetLoader:
					loaders += 1
			check(loaders == 0, "экрана загрузки нет (выбрано «Играть без загрузки»)")
			check(main.world != null and main.player != null and main.hud != null, "мир запущен на запасном")
			_check_world()
			_check_models()
			_check_icons()
			main._on_action("hero_window")
			wait = 3
			step = 2
		2:
			check(main.hero_window.is_open(), "окно героя открыто")
			var skills_tab := ""
			for k in main.hero_window.buttons:
				var key := String(k)
				if key.begins_with("tab_") and key != "tab_hero":
					skills_tab = key.trim_prefix("tab_")
			check(skills_tab != "", "у Наёмника есть вкладка древа")
			if skills_tab != "":
				main.hero_window.open(skills_tab)
			wait = 3
			step = 3
		3:
			check(main.hero_window.tree != null, "древо умений построено (значки — кружки с буквой)")
			main.hud.close_window()
			main._on_action("bag_window")
			wait = 3
			step = 4
		4:
			check(main.hud.is_window_open(), "сумка открыта (значки предметов — процедурные)")
			main.hud.close_window()
			main._on_action("pets_window")
			wait = 3
			step = 5
		5:
			check(main.hud.is_window_open(), "окно «Питомцы» открыто")
			main.hud.close_window()
			check(main.pets.creature.open(0, "stats"), "окно существа открыто")
			wait = 3
			step = 6
		6:
			check(main.pets.creature.open(0, "skills"), "вкладка умений существа")
			wait = 3
			step = 7
		7:
			check(main.pets.creature.tree != null, "древо умений питомца построено")
			main.hud.close_window()
			main._on_action("quest_window")
			wait = 3
			step = 8
		8:
			main.hud.close_window()
			SettingsMenu.open(main.hud, "other")
			wait = 3
			step = 9
		9:
			main.hud.close_window()
			_check_models()
			_check_not_loaded()
			Assets.simulate_missing(false)
			Assets.skipped = false
			ok_done()


## Все файлы частей пакета (res://…): обход assets/ по PACKS.
func _packed_files() -> Array:
	var out: Array = []
	_walk("res://assets/", out)
	return out


func _walk(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		var path := dir + f
		if not f.ends_with(".import") and Assets.is_packed(path):
			out.append(path)
	for sub in d.get_directories():
		_walk(dir + sub + "/", out)


func _check_world() -> void:
	check(not PropAsset.has("town_hall") and not PropAsset.has("tree_oak") and PropAsset.for_kind("town_house") == "",
		"постройки и деревья из файлов «нет» — процедурные")
	var meshes := 0
	for k in PropAsset._meshes:
		if PropAsset._meshes[k] != null:
			meshes += 1
	check(meshes == 0, "меши построек из файлов не загружены: %d" % meshes)
	check(not WorldTextures.available() and WorldTextures.texture("grass") == null, "текстур окружения нет")
	var mats := 0
	var on := 0
	for list in [WorldTextures._terrain, WorldTextures._toon]:
		for wr in list:
			var m := (wr as WeakRef).get_ref() as ShaderMaterial
			if m == null:
				continue
			mats += 1
			if m.get_shader_parameter("textures") == true:
				on += 1
	check(mats > 0 and on == 0, "текстуры у материалов земли и построек выключены: %d из %d включены" % [on, mats])
	check(not CreatureAsset.has_asset("sheep"), "овцы в загоне — нет модели")


func _check_models() -> void:
	var stats := {"asset": 0, "handheld": 0, "sheep": 0, "npc_asset": 0}
	_scan(get_tree().root, stats)
	check(int(stats["asset"]) == 0, "зверей и питомцев из файлов нет: %d" % int(stats["asset"]))
	check(int(stats["handheld"]) == 0, "оружия и предметов из файлов нет: %d" % int(stats["handheld"]))
	check(int(stats["sheep"]) == 0, "овец нет: %d" % int(stats["sheep"]))
	check(int(stats["npc_asset"]) == 0, "жители — модели из примитивов: из файлов %d" % int(stats["npc_asset"]))
	var mobs := get_tree().get_nodes_in_group("mobs")
	check(mobs.size() > 10, "звери на острове (из примитивов): %d" % mobs.size())
	var asset := String(main.player._model.spec.get("asset", ""))
	check(CharacterModel.FALLBACK_HEROES.values().has(asset), "герой — запасная модель из APK: %s" % asset)
	check(main.player._model._asset != null, "запасная модель героя построена")
	check(Handheld.model_for("", "dagger") == "" and Handheld.model_for("", "crossbow") == "", "оружие из файлов «нет»")
	for k in ["merchant", "kirk", "sage"]:
		check(not CharacterModel.npc_spec(String(k)).has("asset"), "житель %s — из примитивов" % k)


func _scan(n: Node, stats: Dictionary) -> void:
	if n is CreatureAsset:
		stats["asset"] = int(stats["asset"]) + 1
	if n is PenSheep:
		stats["sheep"] = int(stats["sheep"]) + 1
	if n.has_meta("handheld"):
		stats["handheld"] = int(stats["handheld"]) + 1
	if n is Npc:
		var m := (n as Npc)._model
		if m != null and m._asset != null:
			stats["npc_asset"] = int(stats["npc_asset"]) + 1
	for c in n.get_children():
		_scan(c, stats)


func _check_icons() -> void:
	check(not UiIcons.has_file("close") and not UiIcons.has_file("menu_bag"), "значки интерфейса из файлов «нет»")
	check(UiIcons.texture("close") != null and UiIcons.texture("close").get_width() == UiIcons.SIZE,
		"значок «Закрыть» — процедурный рисунок")
	check(ItemIcon.texture("potion_hp_r1") == null and ItemIcon.texture("weapon_dagger_r1") == null,
		"картинок предметов нет — процедурные значки")
	check(SkillTree.load_icon(HeroSkills.icon_path("charge_stab")) == null, "картинок умений нет — кружок с буквой")
	check(SkillTree.load_icon(CreatureWindow.icon_path("panther", "daze")) == null, "картинок умений питомцев нет")


## Ни один файл частей не загружен (ресурсы, на которые ссылается мир, окна и HUD, были бы в кэше загрузчика).
func _check_not_loaded() -> void:
	var loaded: Array = []
	for p in packed:
		if ResourceLoader.has_cached(String(p)):
			loaded.append(String(p).get_file())
	check(loaded.is_empty(), "файлы пакета не загружены (%d): %s" % [loaded.size(), str(loaded.slice(0, 10))])
