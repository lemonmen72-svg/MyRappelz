extends "res://tests/test_base.gd"
## Аккаунты и слоты персонажей (Accounts, LoginScreen, CharacterSelect, CharacterCreate, main.back_to_menu).
## Хранилище: создание аккаунта (правила логина, занятый логин), вход в несуществующий аккаунт, 4 слота и отказ
## в 5-м, уникальность ника на устройстве (без учёта регистра), сохранение и загрузка слота, удаление, перенос
## старого save.json в слот 1 (и .bak), последний логин. Админ-панель — только у Dedok_max (кнопки в настройках
## нет, множитель опыта из сохранения ×1 у других). Сценарий: герой-человек стартует в деревне людей, «Сменить
## персонажа» → выбор персонажа → создание в пустом слоте (раса → профессии → пол → ник: короткий и занятый ник
## не проходят) → светлый эльф в деревне светлых эльфов → снова выбор → «Играть» первым героем → удаление
## с подтверждением ником → «Сменить аккаунт» → экран входа (последний логин подставлен). Точки старта и
## возрождения всех рас — в деревнях своих рас.

const OTHER := "Tester_2"
const OLD := "Old_hero"

var _cc: CharacterCreate = null


func race_class() -> Array:
	return ["human", "wanderer"]


func run_step() -> void:
	match step:
		0:
			_check_spawn("начало")
			_check_storage()
			_check_admin()
			check(Accounts.current == "Dedok_max", "снова вошёл Dedok_max")
			step = 1
		1:
			SettingsMenu.open(main.hud)
			check(SettingsMenu.buttons.has("account"), "в настройках — «Сменить персонажа / выйти из аккаунта»")
			main.hud.close_window()
			var fresh: Node = main.back_to_menu()
			check(not game.has_character and game.slot == -1 and game.save_path == "", "герой сохранён и забыт")
			check(Accounts.load_slot(0).get("name", "") == "Тест", "герой сохранён в слоте 1")
			main = fresh
			wait = 3
			step = 2
		2:
			var cs := main.screen as CharacterSelect
			check(cs != null, "после смены персонажа — экран выбора персонажа")
			check(cs.slots.size() == Accounts.SLOTS and String((cs.slots[0] as Dictionary).get("name", "")) == "Тест"
				and (cs.slots[1] as Dictionary).is_empty(), "слот 1 — «Тест», слот 2 пуст")
			check(cs.selected == 0 and not (cs.buttons["play"] as Button).disabled, "выбран первый персонаж, «Играть» доступна")
			check(cs.buttons.has("create_1"), "у пустого слота — «Создать»")
			check(cs.portrait_of(0) != null and cs.portrait_of(1) == null, "портрет у героя (арт Dark Pact), у пустого слота — нет")
			(cs.buttons["create_1"] as Button).pressed.emit()
			wait = 2
			step = 3
		3:
			_cc = main.screen as CharacterCreate
			check(_cc != null and _cc.step == 0, "создание: шаг «Раса»")
			check(_cc._race_cards.size() == 3, "три расы")
			check(_cc.backdrop() != null, "шаг «Раса»: арт расы на фоне")
			_cc._select_race("light_elf")
			check(_cc.go_next() and _cc.step == 1 and _cc._job_cards.size() == 3, "шаг «Профессии»: три карточки")
			check(_cc.go_next() and _cc.step == 2, "шаг «Пол»")
			_cc._select_gender("m")
			_cc.go_back()
			check(_cc.step == 1 and _cc._race == "light_elf" and _cc._gender == "m", "«Назад» не теряет выбор")
			_cc.go_next()
			_cc.go_next()
			check(_cc.step == 3 and _cc._next_btn.text == "Войти в игру", "шаг «Ник»")
			_cc._name_edit.text = "Лу"
			check(not _cc.go_next() and _cc._error.text != "", "короткий ник не проходит: %s" % _cc._error.text)
			_cc._name_edit.text = "тЕСТ"
			check(not _cc.go_next() and _cc._error.text.contains("занят"), "занятый ник не проходит: %s" % _cc._error.text)
			_cc._name_edit.text = "Лучезар"
			check(_cc.go_next(), "«Войти в игру»")
			wait = 5
			step = 4
		4:
			check(game.has_character and game.char_name == "Лучезар" and game.race_id == "light_elf" and game.gender == "m"
				and game.class_id == "wanderer" and game.slot == 1, "новый герой — светлый эльф-Бродяга в слоте 2")
			check(main.screen == null and main.player != null, "мир построен")
			_check_spawn("новый герой")
			check(FileAccess.file_exists(Accounts.slot_path(1)) and game.save_path == Accounts.slot_path(1),
				"сохранение — файл слота 2")
			main = main.back_to_menu()
			wait = 3
			step = 5
		5:
			var cs := main.screen as CharacterSelect
			check(cs != null and String((cs.slots[1] as Dictionary).get("name", "")) == "Лучезар"
				and String((cs.slots[1] as Dictionary).get("race", "")) == "light_elf", "в слоте 2 — Лучезар")
			cs.select(0)
			(cs.buttons["play"] as Button).pressed.emit()
			wait = 5
			step = 6
		6:
			check(game.char_name == "Тест" and game.race_id == "human" and game.slot == 0, "«Играть»: загружен первый герой")
			_check_spawn("загруженный герой")
			main = main.back_to_menu()
			wait = 3
			step = 7
		7:
			var cs := main.screen as CharacterSelect
			cs.select(1)
			(cs.buttons["delete"] as Button).pressed.emit()
			check(cs.buttons.has("delete_yes"), "удаление спрашивает ник")
			check(not cs.confirm_delete("Чужой") and Accounts.load_slot(1).size() > 0, "чужой ник — не удалён")
			check(cs.confirm_delete("лучезар") and Accounts.load_slot(1).is_empty() and (cs.slots[1] as Dictionary).is_empty(),
				"ник совпал — удалён, слот пуст")
			check(cs.selected == 0, "выбран оставшийся персонаж")
			(cs.buttons["switch"] as Button).pressed.emit()
			check(not Accounts.is_logged_in(), "«Сменить аккаунт» — выход")
			wait = 2
			step = 8
		8:
			var ls := main.screen as LoginScreen
			check(ls != null, "экран входа")
			check(ls.login_edit.text == "Dedok_max", "последний логин подставлен: %s" % ls.login_edit.text)
			check(ls.try_login("Нет_такого") != "" and not Accounts.is_logged_in(), "вход в несуществующий аккаунт — отказ")
			check(ls.try_create("DEDOK_MAX") != "" and not Accounts.is_logged_in(), "создать занятый логин — отказ")
			check(ls.try_create("a b") != "" and not Accounts.is_logged_in(), "логин с пробелом — отказ")
			check(ls.try_login("dedok_max") == "" and Accounts.current == "Dedok_max", "вход без учёта регистра")
			wait = 2
			step = 9
		9:
			check(main.screen is CharacterSelect, "после входа — выбор персонажа")
			ok_done()


## Хранилище аккаунтов: правила, вход, слоты, ник, перенос старого сохранения.
func _check_storage() -> void:
	check(Accounts.current == "Dedok_max" and Accounts.dir == TEST_ACCOUNTS, "тестовый аккаунт в своём хранилище")
	check(game.slot == 0 and game.save_path == Accounts.slot_path(0)
		and game.save_path.ends_with("accounts/dedok_max/slot1.json"), "герой — в слоте 1: %s" % game.save_path)
	check(Accounts.load_slot(0).get("name", "") == "Тест", "слот 1 сохранён при входе в мир")
	# Правила логина и ника
	check(Accounts.name_error("Ёжик_9") == "" and Accounts.name_error("Dedok_max") == "", "буквы, цифры, _ — можно")
	for bad in ["ab", "Имя с пробелом", "абвгдеёжзийклмноп", "ник!", ""]:
		check(Accounts.name_error(String(bad)) != "", "«%s» — нельзя: %s" % [bad, Accounts.name_error(String(bad))])
	check(Accounts.exists("DEDOK_MAX"), "логин без учёта регистра")
	check(Accounts.create("dedok_Max").contains("занят"), "занятый логин не создаётся")
	check(Accounts.login("Нет_такого") != "" and Accounts.current == "Dedok_max", "вход в несуществующий аккаунт — отказ")
	# Уникальность ника
	check(Accounts.nick_error("тЕСТ").contains("занят"), "ник «Тест» занят (без учёта регистра)")
	check(not Accounts.nick_taken("Тест", "Dedok_max", 0), "свой слот не мешает")
	# Второй аккаунт: 4 слота и отказ в 5-м
	check(Accounts.create(OTHER) == "" and Accounts.current == OTHER, "создан аккаунт %s" % OTHER)
	var empty := true
	for s in Accounts.list_slots():
		empty = empty and (s as Dictionary).is_empty()
	check(empty and Accounts.free_slot() == 0, "у нового аккаунта 4 пустых слота")
	for i in Accounts.SLOTS:
		check(Accounts.save_slot(i, {"name": "Второй_%d" % i, "race": "dark_elf", "class": "adept", "level": 10 + i,
			"gender": "f"}), "персонаж в слоте %d" % (i + 1))
	check(Accounts.free_slot() == -1 and not Accounts.save_slot(Accounts.SLOTS, {"name": "Пятый"}),
		"5-го слота нет")
	var sl: Dictionary = Accounts.list_slots()[3]
	check(String(sl.get("name", "")) == "Второй_3" and int(sl.get("level", 0)) == 13 and String(sl.get("class", "")) == "adept",
		"сводка слота 4")
	check(Accounts.load_slot(2).get("name", "") == "Второй_2", "загрузка слота")
	check(Accounts.delete_slot(2) and Accounts.load_slot(2).is_empty() and Accounts.free_slot() == 2, "удаление слота")
	check(not Accounts.delete_slot(2), "пустой слот не удаляется")
	check(Accounts.nick_error("тест") != "" and Accounts.nick_error("второй_1") != "", "ник уникален на всём устройстве")
	check(Accounts.nick_error("Второй_2") == "", "ник удалённого персонажа свободен")
	# Перенос старого сохранения (user://save.json) в слот 1 аккаунта без персонажей
	var f := FileAccess.open(Accounts.legacy_path(), FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 2, "name": "Старый_герой", "race": "human", "class": "warrior", "level": 7,
		"gender": "m"}))
	f.close()
	check(Accounts.migrate_legacy() == -1 and FileAccess.file_exists(Accounts.legacy_path()),
		"у аккаунта с персонажами старое сохранение не переносится")
	check(Accounts.create(OLD) == "" and Accounts.migrate_legacy() == 0, "новый аккаунт: старое сохранение — в слот 1")
	check(Accounts.load_slot(0).get("name", "") == "Старый_герой" and int(Accounts.load_slot(0).get("level", 0)) == 7,
		"имя и уровень сохранены")
	check(not FileAccess.file_exists(Accounts.legacy_path()) and FileAccess.file_exists(Accounts.legacy_path() + ".bak"),
		"save.json переименован в save.json.bak")
	check(Accounts.migrate_legacy() == -1, "повторно не переносится")
	check(Accounts.last_login() == OLD, "последний логин запомнен")
	check(Accounts.login("Dedok_max") == "" and Accounts.last_login() == "Dedok_max", "вход обратно")


## Админ-панель только у Dedok_max: кнопка в настройках, AdminPanel.open, множитель опыта из сохранения.
func _check_admin() -> void:
	check(Accounts.is_admin("DEDOK_MAX") and not Accounts.is_admin("Dedok_max2") and not Accounts.is_admin(OTHER),
		"администратор — только Dedok_max")
	var d: Dictionary = game.to_dict()
	d["xp_mult"] = 5
	check(Accounts.login(OTHER) == "" and not AdminPanel.enabled(), "%s — без админ-панели" % OTHER)
	SettingsMenu.open(main.hud)
	check(not SettingsMenu.buttons.has("admin") and SettingsMenu.buttons.has("account"), "в настройках нет «Админ-панели»")
	main.hud.close_window()
	AdminPanel.open(main)
	check(not AdminPanel.is_open(main), "панель не открывается")
	game.from_dict(d)
	check(game.xp_mult == 1, "множитель опыта из сохранения у других — ×1")
	check(Accounts.login("Dedok_max") == "" and AdminPanel.enabled(), "Dedok_max — с админ-панелью")
	SettingsMenu.open(main.hud)
	check(SettingsMenu.buttons.has("admin"), "в настройках есть «Админ-панель»")
	main.hud.close_window()
	game.from_dict(d)
	check(game.xp_mult == 5, "у администратора множитель из сохранения: ×5")
	game.xp_mult = 1
	main.player.apply_class()


## Герой стоит в деревне своей расы; точки старта и возрождения всех рас — в деревнях своих рас.
func _check_spawn(what: String) -> void:
	var w: IslandWorld = main.world
	var p: Player = main.player
	var race := String(game.race_id)
	var z := _village(w, race)
	var pos := Vector2(p.global_position.x, p.global_position.z)
	check(not z.is_empty() and pos.distance_to(IslandWorld.v2(z["center"])) < float(z["radius"]),
		"%s (%s) — в деревне своей расы: %s" % [what, race, pos])
	for r in ClassData.RACES:
		var rid := String(r)
		var vz := _village(w, rid)
		var sp := w.spawn_point(rid)
		check(Vector2(sp.x, sp.z).distance_to(IslandWorld.v2(vz["center"])) < float(vz["radius"]),
			"старт расы %s — в её деревне" % rid)
		game.race_id = rid
		var rp := p.respawn_point()
		check(Vector2(rp.x, rp.z).distance_to(IslandWorld.v2(vz["center"])) < float(vz["radius"]),
			"возрождение расы %s — в её деревне" % rid)
	game.race_id = race


## Безопасная зона деревни расы ("<раса>_village") из конфига острова.
func _village(w: IslandWorld, race: String) -> Dictionary:
	for e in w.cfg.get("safe_zones", []):
		var zd: Dictionary = e
		if String(zd.get("id", "")) == race + "_village":
			return zd
	return {}
