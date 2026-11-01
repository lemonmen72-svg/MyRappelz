extends "res://tests/test_base.gd"
## Админ-панель (AdminPanel, «Настройки» → «Админ-панель»): каждая кнопка нажимается программно и проверяется
## результат. «Герой»: раса и пол (модель сменилась), профессия (class_id, древо, оружие), уровень точно (−10/−1/+1/+10,
## 1…40, пределы), опыт до следующего уровня, JP и золото, полное HP/MP, бессмертие (урон не проходит / проходит),
## изучить и забыть умения (JP сходятся), сброс в Бродягу (задание мудреца снова доступно). «Питомцы»: питомец
## каждого вида 1/15/30 ур. (стадия, имя, модель стадии), уровень призванного ±, полное HP, воскресить, коллекция
## полна, отпустить всех с подтверждением. «Опыт»: множитель ×1…×50, убийство зверя даёт герою и питомцу ×N опыта
## (сравнение с ×1). «Предметы»: каждый предмет +1/+10, очистка сумки с подтверждением. «Мир»: перенос во все точки
## (герой у места, на проходимой земле), зверь любого вида нужного уровня рядом, убить цель, убить всех вокруг,
## возродить всех (слот не задваивается), скорость бега ×1/×2/×3. Изменения — в сохранении (уровень, золото,
## предметы, множитель опыта после загрузки). Окно с каждой вкладкой помещается в 1280×720 при всех размерах
## интерфейса.

const TABS := ["hero", "xp", "items", "pets", "world", "bot"]
## UiScale.SMALL, MEDIUM, LARGE.
const LEVELS := [0, 1, 2]
## Допуск переноса: свободная точка ищется до AdminPanel.TP_SEARCH м от места.
const TP_TOLERANCE := 42.0

var _li := 0
var _ti := 0


func race_class() -> Array:
	return ["dark_elf", "assassin"]


func hero_level() -> int:
	return 30


func before_start() -> void:
	UiScale.set_level(UiScale.MEDIUM, false)


func run_step() -> void:
	match step:
		0:
			_check_open()
			_check_look()
			wait = 2
			step = 1
		1:
			_check_job()
			wait = 2
			step = 2
		2:
			_check_level()
			_check_jp_gold()
			_check_god()
			wait = 2
			step = 3
		3:
			_check_skills()
			wait = 2
			step = 4
		4:
			_check_pets()
			wait = 2
			step = 5
		5:
			_check_pets_more()
			wait = 2
			step = 6
		6:
			_check_xp()
			wait = 2
			step = 7
		7:
			_check_items()
			wait = 2
			step = 8
		8:
			_check_world()
			wait = 2
			step = 9
		9:
			_check_mobs()
			wait = 2
			step = 10
		10:
			_check_save()
			_li = 0
			_ti = 0
			step = 11
		11:
			# Окно с каждой вкладкой при каждом размере интерфейса
			UiScale.set_level(int(LEVELS[_li]), false)
			main.hud.apply_ui_scale()
			AdminPanel.open(main, String(TABS[_ti]))
			wait = 3
			step = 12
		12:
			_check_window("админ-панель «%s», размер «%s»" % [String(TABS[_ti]), UiScale.level_name()])
			_ti += 1
			if _ti >= TABS.size():
				_ti = 0
				_li += 1
			if _li < LEVELS.size():
				step = 11
				return
			main.hud.close_window()
			check(not main.hud.is_window_open(), "панель закрывается")
			UiScale.set_level(UiScale.MEDIUM, false)
			main.hud.apply_ui_scale()
			ok_done()


# ---------- Помощники ----------

## Нажать кнопку открытой панели.
func _press(key: String) -> void:
	if not AdminPanel.buttons.has(key):
		fail("нет кнопки «%s» на вкладке «%s»" % [key, AdminPanel.tab])
		return
	var b: Button = AdminPanel.buttons[key]
	b.pressed.emit()


func _open(tab: String) -> void:
	AdminPanel.open(main, tab)
	check(AdminPanel.tab == tab and AdminPanel.buttons.has("tab_" + tab) and main.hud.is_window_open(),
		"вкладка «%s» открыта" % tab)


func _pressed(key: String) -> bool:
	return AdminPanel.buttons.has(key) and (AdminPanel.buttons[key] as Button).button_pressed


func _jp() -> int:
	return int(game.hero.get("jp", 0))


func _skills() -> int:
	return (game.hero.get("skills", {}) as Dictionary).size()


## Живые звери, поставленные панелью (slot −1), вида type_id.
func _admin_mobs(type_id: String = "") -> Array:
	var res: Array = []
	for n in get_tree().get_nodes_in_group("mobs"):
		var m := n as Mob
		if m != null and not m.is_dead and m.slot < 0 and (type_id == "" or m.type_id == type_id):
			res.append(m)
	return res


func _alive_near(r: float) -> int:
	var p: Player = main.player
	var n := 0
	for o in get_tree().get_nodes_in_group("mobs"):
		var m := o as Mob
		if m != null and not m.is_dead and Vector2(m.global_position.x - p.global_position.x,
				m.global_position.z - p.global_position.z).length() <= AdminPanel.KILL_RADIUS:
			n += 1
	return n


func _pet() -> Pet:
	var v: Variant = main.pets.active_pet
	if not is_instance_valid(v):
		return null
	var pet := v as Pet
	return null if pet == null or pet.is_down else pet


# ---------- Открытие, «Герой» ----------

func _check_open() -> void:
	SettingsMenu.open(main.hud)
	check(AdminPanel.enabled() and Accounts.is_admin(), "тестовый аккаунт %s — администратор" % Accounts.current)
	check(SettingsMenu.buttons.has("admin") == AdminPanel.ADMIN_TOOLS, "в настройках — кнопка «Админ-панель»")
	check(SettingsMenu.buttons.has("account"), "в настройках — «Сменить персонажа / выйти из аккаунта»")
	SettingsMenu.buttons["admin"].pressed.emit()
	check(main.hud.is_window_open() and AdminPanel.is_open(main), "админ-панель открыта из настроек")
	for t in TABS:
		check(AdminPanel.buttons.has("tab_" + String(t)), "вкладка %s" % t)
	_press("tab_world")
	check(AdminPanel.tab == "world" and AdminPanel.buttons.has("kill_target"), "кнопка вкладки «Мир» переключает вкладку")
	_press("tab_hero")
	check(AdminPanel.tab == "hero" and AdminPanel.buttons.has("job_neophyte"), "вкладка «Герой»")
	SettingsMenu.open(main.hud)
	SettingsMenu.buttons["admin"].pressed.emit()
	check(AdminPanel.tab == "hero", "панель открывается на последней вкладке")


func _check_look() -> void:
	var player: Player = main.player
	_press("race_light_elf")
	_press("gender_m")
	check(game.race_id == "light_elf" and game.gender == "m", "раса и пол сменены: %s, %s" % [game.race_id, game.gender])
	check(player._model.spec.get("gender", "") == "m", "модель пересобрана (мужской пол)")
	if player._model.spec.has("asset"):
		check(String(player._model.spec["asset"]) == CharacterModel.hero_asset("light_elf", "m", game.class_id),
			"модель: %s" % String(player._model.spec["asset"]).get_file())
	check(_pressed("race_light_elf") and _pressed("gender_m"), "выбранные раса и пол отмечены")
	_press("race_human")
	check(game.race_id == "human", "раса: люди")
	_press("race_dark_elf")
	_press("gender_f")
	check(game.race_id == "dark_elf" and game.gender == "f" and player._model.spec.get("gender", "") == "f",
		"вернулись к тёмной эльфийке")


func _check_job() -> void:
	var player: Player = main.player
	for jid in ClassData.CLASSES:
		check(AdminPanel.buttons.has("job_" + String(jid)), "кнопка профессии %s" % jid)
	_press("job_neophyte")
	check(game.class_id == "neophyte" and game.job_changed, "профессия Неофит")
	check(game.weapon != "" and ItemData.weapon_fits(game.weapon, "neophyte") and player.weapon_kind == game.weapon_kind(),
		"оружие Неофита выдано и надето: %s" % game.weapon)
	if player._model.spec.has("asset"):
		check(String(player._model.spec["asset"]) == CharacterModel.hero_asset("dark_elf", "f", "neophyte"),
			"модель сменилась с профессией: %s" % String(player._model.spec["asset"]).get_file())
	var tabs := HeroSkills.tabs_for("neophyte")
	check(tabs.size() > 0, "древо Неофита: %d вкладки" % tabs.size())
	main.hero_window.open("hero")
	check(main.hero_window.buttons.has("tab_" + String(tabs[0][0])), "окно героя — древо Неофита")
	_open("hero")
	_press("job_warrior")
	check(game.class_id == "warrior" and game.race_id == "dark_elf" and ItemData.weapon_fits(game.weapon, "warrior"),
		"профессия другой расы (Воин) для теста: %s" % game.weapon)
	_press("job_wanderer")
	check(game.class_id == "wanderer" and not game.job_changed, "Бродяга")
	for i in 4:
		check(not main.hud.is_button_visible("skill%d" % (i + 1)), "у Бродяги кнопки умений скрыты (%d)" % (i + 1))
	_press("job_assassin")
	check(game.class_id == "assassin" and ItemData.weapon_fits(game.weapon, "assassin") and _pressed("job_assassin"),
		"снова Наёмник: %s" % game.weapon)


func _check_level() -> void:
	var player: Player = main.player
	for v in AdminPanel.LEVEL_PRESETS:
		check(AdminPanel.buttons.has("lvl_set_%d" % int(v)), "кнопка уровня %d" % int(v))
	game.xp = 7
	_press("lvl_set_20")
	check(game.level == 20 and game.xp == 0 and _pressed("lvl_set_20"), "уровень ровно 20, опыт 0")
	var hp20 := player.max_hp
	_press("lvl_plus")
	check(game.level == 21, "+1 → 21")
	_press("lvl_plus10")
	check(game.level == 31 and player.max_hp > hp20, "+10 → 31, HP выросло: %d → %d" % [hp20, player.max_hp])
	_press("lvl_minus10")
	check(game.level == 21, "−10 → 21")
	_press("lvl_minus")
	check(game.level == 20 and player.max_hp == hp20 and player.hp == player.max_hp, "−1 → 20, HP как на 20 ур., полное")
	_press("lvl_set_40")
	_press("lvl_plus")
	check(game.level == AdminPanel.MAX_LEVEL, "выше 40 нельзя (+1)")
	_press("lvl_plus10")
	check(game.level == AdminPanel.MAX_LEVEL, "выше 40 нельзя (+10)")
	_press("lvl_set_1")
	_press("lvl_minus")
	check(game.level == 1, "ниже 1 нельзя (−1)")
	_press("lvl_minus10")
	check(game.level == 1 and player.max_hp < hp20, "ниже 1 нельзя (−10)")
	_press("lvl_set_10")
	game.xp = 5
	var jp0 := _jp()
	_press("xp_next")
	check(game.level == 11 and game.xp == 0, "«До след. уровня»: 10 → 11, опыт 0 (ур. %d, опыт %d)" % [game.level, game.xp])
	check(_jp() > jp0, "с уровнем копятся JP: %d → %d" % [jp0, _jp()])
	_press("lvl_set_30")
	check(game.level == 30, "уровень 30")


func _check_jp_gold() -> void:
	var jp0 := _jp()
	_press("jp_plus10")
	check(_jp() == jp0 + 10, "+10 JP")
	_press("jp_plus100")
	check(_jp() == jp0 + 110, "+100 JP")
	_press("jp_zero")
	check(_jp() == 0, "JP = 0")
	var g0: int = game.gold
	_press("gold_plus100")
	check(game.gold == g0 + 100, "+100 зол.")
	_press("gold_plus1000")
	check(game.gold == g0 + 1100, "+1000 зол.")
	_press("gold_plus10000")
	check(game.gold == g0 + 11100, "+10000 зол.: %d" % game.gold)
	_press("gold_zero")
	check(game.gold == 0, "золото = 0")


func _check_god() -> void:
	var player: Player = main.player
	player.hp = 1
	player.mp = 0
	_press("full")
	check(player.hp == player.max_hp and player.mp == player.max_mp, "полное HP/MP")
	check(not AdminPanel.god and not _pressed("god"), "бессмертие выключено по умолчанию")
	_press("god")
	check(AdminPanel.god and _pressed("god"), "бессмертие включено")
	var any_mob: Mob = null
	for n in get_tree().get_nodes_in_group("mobs"):
		any_mob = n as Mob
		if any_mob != null:
			break
	player.take_damage(50, null)
	if any_mob != null:
		player.take_damage(50, any_mob)
	check(player.hp == player.max_hp, "с бессмертием урон не проходит: HP %d/%d" % [player.hp, player.max_hp])
	_press("god")
	check(not AdminPanel.god, "бессмертие выключено")
	player.take_damage(20, null)
	check(player.hp < player.max_hp, "без бессмертия урон проходит: HP %d/%d" % [player.hp, player.max_hp])
	_press("full")


func _check_skills() -> void:
	check(game.class_id == "assassin" and game.level == 30, "Наёмник 30 ур.")
	_press("forget_all")
	var base := _skills()
	_press("jp_plus100")
	_press("jp_plus100")
	_press("jp_plus100")
	var jp0 := _jp()
	_press("learn_all")
	var learned := _skills()
	check(learned > base and _jp() < jp0, "изучены все доступные: умений %d → %d, JP %d → %d" % [base, learned, jp0, _jp()])
	_press("forget_all")
	check(_skills() == base and _jp() == jp0, "забыты все умения, JP вернулись: умений %d, JP %d (было %d)"
		% [_skills(), _jp(), jp0])
	_press("learn_all")
	check(_skills() == learned, "снова изучены")
	# Сброс в Бродягу: задание мудреца — заново
	game.quests_done["sage_first_job"] = 1
	_press("reset_job")
	check(game.class_id == "wanderer" and not game.job_changed and main.quests.state("sage_first_job") != "done",
		"сброс в Бродягу: задание мудреца можно пройти заново (%s)" % main.quests.state("sage_first_job"))
	check(int(game.hero["jp"]) >= jp0, "сброс вернул JP изученных умений: %d" % _jp())
	_press("job_assassin")
	check(game.class_id == "assassin", "снова Наёмник")


# ---------- «Питомцы» ----------

func _check_pets() -> void:
	_open("pets")
	for s in AdminPanel.pet_species():
		for v in AdminPanel.PET_LEVELS:
			check(AdminPanel.buttons.has("pet_%s_%d" % [String(s), int(v)]), "кнопка питомца %s %d ур." % [s, int(v)])
	check(not AdminPanel.pet_species().has("boar") and AdminPanel.pet_species().has("centaur"), "виды питомцев острова")
	check(game.pets.is_empty(), "питомцев нет")
	# По питомцу каждой стадии
	var cases := [["panther", 1, 0], ["wolf", 15, 1], ["centaur", 30, 2]]
	for c in cases:
		var sp := String(c[0])
		var lvl := int(c[1])
		_press("pet_%s_%d" % [sp, lvl])
		var rec: Dictionary = game.pets[game.pets.size() - 1]
		check(String(rec["species"]) == sp and int(rec["level"]) == lvl and String(rec["name"]) == PetData.stage_name(sp, lvl),
			"питомец %s %d ур.: «%s»" % [sp, lvl, String(rec["name"])])
		var pc := _pet()
		check(pc != null and pc.species == sp and pc.level == lvl and pc.stage == int(c[2]),
			"призван: стадия %d" % (int(c[2]) + 1))
		if pc != null:
			check(pc.model_id == CreatureAsset.model_for(sp, int(c[2])), "модель стадии: %s" % pc.model_id)
	var pet := _pet()
	check(pet != null, "призван кентавр")
	if pet == null:
		return
	_press("pet_lvl_plus")
	check(pet.level == 31 and int(game.pets[game.active_pet]["level"]) == 31, "питомец +1 → 31")
	_press("pet_lvl_minus5")
	check(pet.level == 26 and pet.stage == 1 and pet.model_id == CreatureAsset.model_for("centaur", 1)
		and pet.pet_name == PetData.stage_name("centaur", 26), "питомец −5 → 26: 2-я стадия, модель и имя стадии")
	_press("pet_lvl_plus5")
	check(pet.level == 31 and pet.stage == 2 and pet.model_id == CreatureAsset.model_for("centaur", 2), "питомец +5 → 31: 3-я стадия")
	_press("pet_lvl_minus")
	check(pet.level == 30 and int(game.pets[game.active_pet]["level"]) == 30, "питомец −1 → 30")
	pet.hp = 1
	_press("pet_full")
	check(pet.hp == pet.max_hp, "полное HP питомца")
	# Погиб — воскресить
	var idx: int = game.active_pet
	pet.take_damage(9999999, null)
	check(bool(game.pets[idx]["dead"]) and game.active_pet == -1, "питомец погиб")


func _check_pets_more() -> void:
	_open("pets")
	var idx: int = game.pets.size() - 1
	_press("pet_revive")
	var pet := _pet()
	check(not bool(game.pets[idx]["dead"]) and pet != null and pet.hp == pet.max_hp, "питомец воскрешён и призван, HP полное")
	# Коллекция полна
	for _k in Game.MAX_PETS:
		if game.pets.size() < Game.MAX_PETS:
			_press("pet_turtle_1")
	_press("pet_pheasant_1")
	check(game.pets.size() == Game.MAX_PETS, "коллекция полна: %d" % game.pets.size())
	_press("pets_clear")
	check(AdminPanel.buttons.has("pets_clear_yes") and AdminPanel.buttons.has("pets_clear_no"), "подтверждение «Отпустить всех»")
	_press("pets_clear_no")
	check(game.pets.size() == Game.MAX_PETS and AdminPanel.buttons.has("pets_clear"), "отмена — питомцы на месте")
	_press("pets_clear")
	_press("pets_clear_yes")
	check(game.pets.is_empty() and game.active_pet == -1, "все питомцы отпущены")
	# Питомец для проверки опыта: волк 30 ур.
	_press("pet_wolf_30")
	check(_pet() != null and _pet().level == 30, "волк 30 ур. призван")


# ---------- «Опыт» ----------

func _check_xp() -> void:
	_open("xp")
	for v in AdminPanel.XP_MULTS:
		var n := int(v)
		_press("xp_%d" % n)
		check(game.xp_mult == n and _pressed("xp_%d" % n), "множитель опыта ×%d" % n)
	var r1 := _kill_xp(1)
	var r5 := _kill_xp(5)
	var r50 := _kill_xp(50)
	check(int(r1[0]) > 0 and int(r5[0]) == int(r1[0]) * 5 and int(r50[0]) == int(r1[0]) * 50,
		"опыт героя за зверя: ×1 %d, ×5 %d, ×50 %d" % [int(r1[0]), int(r5[0]), int(r50[0])])
	check(int(r1[1]) > 0 and int(r5[1]) == int(r1[1]) * 5, "опыт питомца за зверя: ×1 %d, ×5 %d" % [int(r1[1]), int(r5[1])])
	_open("xp")
	_press("xp_1")
	check(game.xp_mult == 1, "множитель ×1")
	# Опыт до следующего уровня — питомцу
	var pet := _pet()
	var lvl := pet.level
	_press("pet_xp_next")
	check(pet.level == lvl + 1 and pet.xp == 0, "питомцу — до следующего уровня: %d → %d" % [lvl, pet.level])
	var hl: int = game.level
	_press("xp_next")
	check(game.level == hl + 1, "герою — до следующего уровня (вкладка «Опыт»): %d" % game.level)
	_open("hero")
	_press("lvl_set_30")


## Множитель mult, зверь (волк 30 ур., поставлен панелью) убит «Убить цель»: [опыт героя, опыт питомца].
func _kill_xp(mult: int) -> Array:
	var player: Player = main.player
	_open("xp")
	_press("xp_%d" % mult)
	_open("world")
	AdminPanel.spawn_level = 30
	_press("spawn_wolf")
	var list := _admin_mobs("wolf")
	check(not list.is_empty(), "волк поставлен")
	if list.is_empty():
		return [0, 0]
	var m: Mob = list[list.size() - 1]
	player.select_target(m)
	var pet := _pet()
	# Герой 40 ур. с нулевым опытом: опыт за зверя ×XP_GAIN — ×50 на 30 ур. дал бы новый уровень
	var keep_l: int = game.level
	game.level = 40
	game.xp = 0
	var x0: int = game.xp
	var l0: int = game.level
	var p0 := pet.xp if pet != null else 0
	var pl0 := pet.level if pet != null else 0
	_press("kill_target")
	check(m.is_dead and game.level == l0, "волк убит (×%d), уровень героя тот же" % mult)
	# Опыт питомца с учётом новых уровней (опыт за зверя ×XP_GAIN — питомец может вырасти)
	var pet_gain := 0
	if pet != null:
		pet_gain = pet.xp - p0
		for l in range(pl0, pet.level):
			pet_gain += PetData.xp_to_next(l)
	var res := [game.xp - x0, pet_gain]
	game.level = keep_l
	game.xp = 0
	return res


# ---------- «Предметы» ----------

func _check_items() -> void:
	_open("items")
	var n := 0
	for id in ItemData.ITEMS:
		var iid := String(id)
		check(AdminPanel.buttons.has("item_%s_1" % iid) and AdminPanel.buttons.has("item_%s_10" % iid), "кнопки «%s»" % iid)
		n += 1
	var groups := AdminPanel.item_groups()
	var types: Array = []
	for g in groups:
		types.append(String(g[0]))
	check(types.has("weapon") and types.has("consumable") and types.has("card") and types.has("trophy"),
		"группы предметов: %s" % ", ".join(PackedStringArray(types)))
	var w: String = game.weapon
	check(w != "", "надето оружие: %s" % w)
	_press("clear_bag")
	_press("clear_bag_yes")
	check(game.inventory.ids() == [w] or (game.shield != "" and game.inventory.ids().size() == 2), "сумка пуста, кроме надетого")
	_press("item_potion_hp_r1_1")
	check(game.inventory.count("potion_hp_r1") == 1, "+1 зелье")
	_press("item_potion_hp_r1_10")
	check(game.inventory.count("potion_hp_r1") == 11, "+10 зелий")
	_press("item_card_wolf_10")
	check(game.inventory.count("card_wolf") == 10, "+10 карт волка")
	_press("item_mirror_card_1")
	check(game.inventory.count("mirror_card") == 1, "+1 зеркальная карта")
	for g in groups:
		var grp: Array = g
		var first := String((grp[2] as Array)[0])
		if first == w:
			first = String((grp[2] as Array)[(grp[2] as Array).size() - 1])
		var c0: int = game.inventory.count(first)
		_press("item_%s_1" % first)
		check(game.inventory.count(first) == c0 + 1, "%s: +1 «%s»" % [String(grp[1]), ItemData.item_name(first)])
	# Оружие по одному в ячейке: +10 кладёт, сколько поместится
	var weapon_id := ""
	for id in ItemData.ITEMS:
		if ItemData.is_weapon(String(id)) and String(id) != w and not ItemData.is_shield(String(id)):
			weapon_id = String(id)
			break
	var c1: int = game.inventory.count(weapon_id)
	_press("item_%s_10" % weapon_id)
	check(game.inventory.count(weapon_id) == c1 + 10 and game.inventory.used_cells() <= Inventory.CAPACITY,
		"+10 оружия: %d, занято %d" % [game.inventory.count(weapon_id), game.inventory.used_cells()])
	# Очистка с подтверждением
	var potions_before: int = game.inventory.count("potion_hp_r1")
	_press("clear_bag")
	check(AdminPanel.buttons.has("clear_bag_yes") and AdminPanel.buttons.has("clear_bag_no"), "подтверждение очистки")
	_press("clear_bag_no")
	check(game.inventory.count("potion_hp_r1") == potions_before and potions_before > 0 and AdminPanel.buttons.has("clear_bag"),
		"отмена — сумка цела (зелий %d)" % game.inventory.count("potion_hp_r1"))
	_press("clear_bag")
	_press("clear_bag_yes")
	check(game.inventory.count("potion_hp_r1") == 0 and game.inventory.has(w) and game.weapon == w and game.inventory.used_cells() == 0,
		"сумка очищена, надетое оружие осталось: %s" % ", ".join(PackedStringArray(game.inventory.ids())))
	# Для проверки сохранения
	_press("item_potion_hp_r1_10")
	print("  предметов в панели: %d" % n)


# ---------- «Мир» ----------

func _check_world() -> void:
	var player: Player = main.player
	_open("world")
	var tps := AdminPanel.teleports()
	check(tps.size() >= 20, "точек переноса: %d" % tps.size())
	var w := IslandWorld.current
	for e in tps:
		var d: Dictionary = e
		var key := String(d["key"])
		check(AdminPanel.buttons.has(key), "кнопка переноса %s" % key)
		_press(key)
		var c: Vector2 = d["c"]
		var pos := player.global_position
		var dist := Vector2(pos.x, pos.z).distance_to(c)
		check(dist <= TP_TOLERANCE and w.is_walkable(pos.x, pos.z) and absf(pos.y - w.height_at(pos.x, pos.z)) < 1.0,
			"перенос «%s»: %.1f м от места, на земле" % [String(d["name"]).replace("\n", ", "), dist])
	check(AdminPanel.buttons.has("tp_poi_town") and AdminPanel.buttons.has("tp_zone_cave_boss"), "город и логово в списке")
	# Скорость бега
	_press("speed_1")
	var base := player.cur_speed()
	_press("speed_2")
	check(is_equal_approx(player.cur_speed(), base * 2.0) and _pressed("speed_2"), "бег ×2: %.1f → %.1f" % [base, player.cur_speed()])
	_press("speed_3")
	check(is_equal_approx(player.cur_speed(), base * 3.0), "бег ×3: %.1f" % player.cur_speed())
	_press("speed_1")
	check(is_equal_approx(player.cur_speed(), base), "бег ×1")


func _check_mobs() -> void:
	var player: Player = main.player
	_open("world")
	_press("tp_poi_town")
	# Уровень зверя
	AdminPanel.spawn_level = 5
	_open("world")
	_press("mob_lvl_plus5")
	check(AdminPanel.spawn_level == 10, "ур. зверя +5 → 10")
	_press("mob_lvl_plus")
	_press("mob_lvl_plus")
	check(AdminPanel.spawn_level == 12, "ур. зверя +1 +1 → 12")
	_press("mob_lvl_minus")
	_press("mob_lvl_plus")
	_press("mob_lvl_minus5")
	_press("mob_lvl_plus5")
	check(AdminPanel.spawn_level == 12, "ур. зверя −1 +1 −5 +5 → 12")
	_press("mob_lvl_hero")
	check(AdminPanel.spawn_level == game.level, "ур. зверя = ур. героя")
	AdminPanel.spawn_level = 12
	_open("world")
	# Каждый вид — рядом, нужного уровня
	for t in MobData.TYPES:
		var tid := String(t)
		check(AdminPanel.buttons.has("spawn_" + tid), "кнопка зверя %s" % tid)
		_press("spawn_" + tid)
		var list := _admin_mobs(tid)
		var ok := false
		for o in list:
			var m := o as Mob
			if m.level == 12 and Vector2(m.global_position.x - player.global_position.x,
					m.global_position.z - player.global_position.z).length() < AdminPanel.SPAWN_DIST + 1.0:
				ok = true
		check(ok, "зверь «%s» 12 ур. рядом с героем" % String(MobData.get_type(tid)["name"]))
	# Убить цель
	var wolf: Mob = _admin_mobs("wolf")[0]
	player.select_target(wolf)
	_press("kill_target")
	check(wolf.is_dead, "«Убить цель»: волк убит")
	player._set_target(null)
	_press("kill_target")
	check(String(main.hud._msg_label.text).contains("Нет цели"), "«Убить цель» без цели — подсказка")
	# Убить всех вокруг
	var near := _alive_near(AdminPanel.KILL_RADIUS)
	check(near >= MobData.TYPES.size() - 1, "вокруг зверей: %d" % near)
	_press("kill_around")
	check(_alive_near(AdminPanel.KILL_RADIUS) == 0 and _admin_mobs().is_empty(), "«Убить всех вокруг»: никого не осталось")
	# Луга новичков: звери мира (и ещё несколько где угодно) убиты, затем — возродить
	_press("tp_zone_meadows")
	_press("kill_around")
	var slots: Array = main._slots
	var killed := 0
	for n in get_tree().get_nodes_in_group("mobs"):
		var m := n as Mob
		if m != null and m.slot >= 0 and not m.is_dead and killed < 4:
			m.hp = 1
			m.take_damage(999999, player)
			killed += 1
	check(killed > 0 and count_mobs() < slots.size(), "звери мира убиты: живых %d из %d" % [count_mobs(), slots.size()])
	_press("respawn_all")
	var alive: Dictionary = {}
	var twice := 0
	for n in get_tree().get_nodes_in_group("mobs"):
		var m := n as Mob
		if m != null and m.slot >= 0:
			if alive.has(m.slot):
				twice += 1
			alive[m.slot] = true
	check(alive.size() == slots.size() and twice == 0, "«Возродить всех»: зверей во всех слотах %d/%d, по одному (лишних %d)"
		% [alive.size(), slots.size(), twice])
	var before := count_mobs()
	main._spawn_slot(0)
	check(count_mobs() == before, "занятый слот не задваивается (таймер возрождения после «Возродить всех»)")
	_press("tp_poi_town")


# ---------- Сохранение ----------

func _check_save() -> void:
	_open("hero")
	_press("lvl_set_15")
	_press("gold_zero")
	_press("gold_plus1000")
	_open("xp")
	_press("xp_5")
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
	check(d is Dictionary, "сохранение записано панелью")
	if not (d is Dictionary):
		return
	var sd: Dictionary = d
	check(int(sd["level"]) == 15 and int(sd["gold"]) == 1000 and int(sd["xp_mult"]) == 5
		and int((sd["inventory"] as Dictionary).get("potion_hp_r1", 0)) >= 10 and (sd["pets"] as Array).size() == 1,
		"в сохранении: ур. 15, 1000 зол., ×5, зелья, 1 питомец")
	game.xp_mult = 1
	game.level = 1
	check(game.load_game(), "сохранение загружено")
	main.player.apply_class()
	check(game.xp_mult == 5 and game.level == 15 and game.gold == 1000, "после загрузки: ×5, ур. 15, 1000 зол.")
	_press("xp_1")
	check(game.xp_mult == 1, "множитель ×1")


# ---------- Окно ----------

func _check_window(what: String) -> void:
	var hud: HUD = main.hud
	check(hud.is_window_open(), "%s: окно открыто" % what)
	if not hud.is_window_open():
		return
	var view: Vector2 = hud._view
	var r := hud.window_rect()
	var w: Control = hud._window
	var need := w.get_combined_minimum_size()
	var fits := r.position.x >= -0.5 and r.position.y >= -0.5 and r.end.x <= view.x + 0.5 and r.end.y <= view.y + 0.5
	check(fits and need.x <= view.x and need.y <= view.y, "%s помещается в экран %s: %s (нужно не меньше %s)"
		% [what, view, r, need])
	# Кнопки не вылезают за окно по ширине
	var wide := 0
	for n in w.find_children("*", "Button", true, false):
		var b := n as Button
		if b.is_visible_in_tree() and b.get_global_rect().end.x > r.end.x + 1.0:
			wide += 1
	check(wide == 0, "%s: кнопки в пределах окна по ширине" % what)
	for n in w.find_children("*", "", true, false):
		if n.is_queued_for_deletion():
			continue
		var ctl := n as Control
		if n is Label and (n as Label).clip_text:
			var font := ctl.get_theme_font("font")
			var fsz := ctl.get_theme_font_size("font_size")
			var tw := font.get_string_size((n as Label).text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
			check(tw <= ctl.size.x + 1.0, "%s: «%s» не обрезано" % [what, (n as Label).text])
	print("  %s: %s" % [what, r])
