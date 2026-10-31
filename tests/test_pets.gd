extends "res://tests/test_base.gd"
## Питомцы: приручение волка картой существа (метка → победить → карта с душой → «Сформировать»), кабана
## и уникального стража приручить нельзя, призыв/отзыв
## через окно, помощь в бою и опыт, эволюция, смерть, воскрешение свитком, отпускание, сохранение
## коллекции, перевод старых видов и предметов (медведь, искрожук, фея) в новые при загрузке.

const MAX_TRIES := 15

var mob: Mob = null
var tries := 0
var timer := 0
var xp_before := 0
var lvl_before := 0
var hp_saved := 0


func before_start() -> void:
	game.inventory.add("card_wolf", 17)
	game.inventory.add("revive_scroll", 1)


func run_step() -> void:
	var player: Player = main.player
	var pm: PetManager = main.pets
	var tm: Taming = main.taming
	match step:
		0:
			check(pm != null and tm != null, "модули питомцев и приручения созданы")
			check(game.pets.is_empty() and pm.active_pet == null, "питомцев пока нет")
			for id in MobData.TYPES:
				# Летающие рыбы и анатемы — только звери мира, питомцами не бывают; у кабана и стража вид питомца
				# остался (старые питомцы, хотя теперь их нельзя приручить)
				var pet_kind: bool = MobData.tameable(id) or ["boar", "golem"].has(id)
				check(PetData.SPECIES.has(id) == pet_kind, "вид питомца для зверя %s: %s" % [id, "есть" if pet_kind else "нет"])
			check(PetData.role("turtle") == "tank" and PetData.role("golem") == "tank", "черепаха и страж — танки")
			check(PetData.role("pheasant") == "healer" and PetData.role("panther") == "mage", "фазан — лекарь, пантера — маг")
			for id in ["bear", "sparkbug", "fairy"]:
				check(not MobData.TYPES.has(id) and not PetData.SPECIES.has(id), "старого вида %s больше нет" % id)
				check(MobData.TYPES.has(MobData.migrate_id(id)), "старый вид %s → %s" % [id, MobData.migrate_id(id)])
			for id in ["panther", "turtle", "pheasant"]:
				check(String(MobData.get_type(id)["rarity"]) == "common", "%s — базовой редкости" % id)
				check(MobData.rarity_name(id) == "Базовый", "редкость %s видна как «Базовый»" % id)
				check(ItemData.card_tier("card_" + id) == "basic", "%s ловится базовой (коричневой) картой" % id)
				check(int(ItemData.get_item("card_" + id)["buy"]) > 0, "карта %s продаётся (у Учителя Кирка)" % id)
				var names: Array = PetData.get_species(id)["stages"]
				check(names.size() == 3, "у вида %s три стадии: %s" % [id, str(names)])
				for e in MobData.get_type(id)["loot"]:
					var it := String(e[0])
					check(not ItemData.get_item(it).is_empty(), "добыча %s есть в предметах: %s" % [id, it])
			for id in ["boar", "golem"]:
				check(not MobData.tameable(id) and ItemData.card_for(id) == "" and ItemData.soul_card_for(id) == "",
					"%s не приручается, карт нет" % id)
				check(PetData.SPECIES.has(id), "вид питомца %s остался (для уже прирученных)" % id)
			check(MobData.tameable("wolf") and ItemData.card_tier("card_wolf") == "rare", "волк приручается синей картой")
			check(String(MobData.get_type("wolf")["rarity"]) == "uncommon" and MobData.rarity_name("wolf") == "Обычный",
				"волк — «Обычный»")
			check(MobData.rarity_label("unique") == "Уникальный", "редкость стража — «Уникальный»")
			check(PetData.role("boar") == "fighter" and PetData.role("wolf") == "fighter", "кабан и волк — бойцы")
			check(PetData.stage_for(1) == 0 and PetData.stage_for(14) == 0, "стадия 1 до 15 уровня")
			check(PetData.stage_for(15) == 1 and PetData.stage_for(30) == 2, "стадии 2 и 3 с 15 и 30 уровня")
			var s1 := PetData.stats_for("boar", 1)
			var s15 := PetData.stats_for("boar", 15)
			check(int(s15["max_hp"]) > int(s1["max_hp"]) and int(s15["atk"]) > int(s1["atk"]), "характеристики растут с уровнем")
			check(PetData.stage_scale("boar", 30) > PetData.stage_scale("boar", 1), "старшая стадия крупнее")
			step = 1
		1:
			# Вожака анатем (и любую анатему) приручить нельзя
			mob = find_mob("anathema_chief")
			check(mob != null, "найден вожак анатем")
			stand_near(mob, 3.0)
			player.current_target = mob
			main._on_action("tame")
			check(tm.marked == null and not mob.tame_marked, "на вожака анатем метка не ставится")
			var msg: String = main.hud._msg_label.text
			check(msg.contains("Этого зверя нельзя приручить"), "сообщение: " + msg)
			player.current_target = null
			player.global_position = Vector3(0, 0.1, 2)
			mob.target = null
			mob.returning = true
			step = 2
		2:
			# Приручение волка: метка → победить → повторять до успеха (шанс настоящий), затем «Сформировать»
			if game.inventory.has("card_wolf_soul"):
				check(tm.attempts == tries, "каждая попытка засчитана: %d" % tries)
				check(game.pets.is_empty(), "до формирования питомца в коллекции нет")
				check(tm.form("card_wolf_soul"), "существо сформировано из карты с душой")
				check(not game.inventory.has("card_wolf_soul"), "карта с душой израсходована")
				check(String(game.pets[0]["species"]) == "wolf", "приручен волк за %d попыток" % tries)
				check(String(game.pets[0]["name"]) == PetData.stage_name("wolf", 1), "имя питомца = название стадии 1")
				step = 3
				return
			if tries >= MAX_TRIES:
				fail("волк не приручен за %d попыток" % tries)
				return
			mob = find_mob("wolf")
			if mob == null:
				return
			stand_near(mob)
			player.current_target = mob
			tm.cooldown = 0.0
			main._on_action("tame")
			check(tm.marked == mob and mob.tame_marked, "метка приручения на волке")
			var used: int = tm.attempts
			mob.take_damage(mob.hp + 5, player)
			tries += 1
			check(tm.attempts == used + 1, "попытка засчитана (%d)" % tries)
			check(tm.marked == null and not mob.tame_marked, "метка снята после смерти зверя")
		3:
			check(pm.active_pet != null and game.active_pet == 0, "первый питомец сразу призван")
			check(main.hud._pet_box.visible, "панель питомца видна")
			main._on_action("pets_window")
			check(main.hud.is_window_open(), "окно питомцев открыто")
			check(_window_text(pm).contains("Обычный"), "в окне питомцев видна редкость волка «Обычный»")
			press(pm, "recall_0")
			check(pm.active_pet == null and game.active_pet == -1, "питомец отозван")
			check(not main.hud._pet_box.visible, "панель питомца скрыта после отзыва")
			press(pm, "summon_0")
			check(pm.active_pet != null and game.active_pet == 0, "питомец призван снова")
			main.hud.close_window()
			step = 4
		4:
			# Питомец помогает убить зверя и получает опыт
			mob = find_mob("pheasant")
			if mob == null:
				return
			var pet: Pet = pm.active_pet
			xp_before = pet.xp
			lvl_before = pet.level
			stand_near(mob, 2.0)
			pet.global_position = mob.global_position + Vector3(1.5, 0.2, 0)
			player.last_target = mob
			player.current_target = null
			timer = 0
			step = 5
		5:
			timer += 1
			if timer > 60 * 60:
				fail("питомец не добил зверя за 60 с")
				return
			if mob.is_dead:
				var pet: Pet = pm.active_pet
				check(pet != null and (pet.xp > xp_before or pet.level > lvl_before), "питомец получил опыт: %d" % pet.xp)
				check(int(game.pets[0]["xp"]) == pet.xp, "опыт записан в коллекцию")
				step = 6
				return
			stand_near(mob, 2.0)
			if mob.hp < mob.max_hp and timer % 60 == 0:
				print("  фазан: %d/%d" % [mob.hp, mob.max_hp])
		6:
			# Эволюция на 15 уровне
			var pet: Pet = pm.active_pet
			var old_max: int = pet.max_hp
			pet.level = 14
			pet.xp = PetData.xp_to_next(14) - 1
			pet.gain_xp(5)
			check(pet.level == 15, "питомец достиг 15 уровня")
			check(pet.stage == 1 and pet.pet_name == PetData.stage_name("wolf", 15), "эволюция: %s" % pet.pet_name)
			check(pet.max_hp > old_max, "характеристики выросли: %d > %d" % [pet.max_hp, old_max])
			check(int(game.pets[0]["level"]) == 15 and String(game.pets[0]["name"]) == pet.pet_name, "уровень и имя записаны в коллекцию")
			check(main.hud._pet_label.text.contains(pet.pet_name), "панель питомца обновлена")
			wait = 2
			step = 7
		7:
			# Смерть питомца
			var pet: Pet = pm.active_pet
			pet.take_damage(99999, null)
			check(bool(game.pets[0]["dead"]), "погибший питомец помечен dead")
			check(pm.active_pet == null and game.active_pet == -1, "погибший питомец исчез")
			check(not main.hud._pet_box.visible, "панель питомца скрыта после гибели")
			main._on_action("pet_attack")
			wait = 2
			step = 8
		8:
			# Воскрешение свитком из окна
			var scrolls: int = game.inventory.count("revive_scroll")
			check(scrolls >= 1, "есть свитки воскрешения: %d" % scrolls)
			game.inventory.remove("revive_scroll", scrolls)
			main._on_action("pets_window")
			press(pm, "revive_0")
			check(bool(game.pets[0]["dead"]), "без свитка воскресить нельзя")
			game.inventory.add("revive_scroll", scrolls)
			press(pm, "revive_0")
			check(not bool(game.pets[0]["dead"]), "питомец воскрешён свитком")
			check(game.inventory.count("revive_scroll") == scrolls - 1, "свиток потрачен")
			press(pm, "summon_0")
			check(pm.active_pet != null and game.active_pet == 0, "воскрешённый питомец призван")
			check(pm.active_pet.hp < pm.active_pet.max_hp, "воскрешён с половиной здоровья")
			step = 9
		9:
			# Отпускание с подтверждением
			var idx: int = game.add_pet("wolf", PetData.stage_name("wolf", 1), 1)
			check(idx == 1, "второй питомец в коллекции")
			main._on_action("pets_window")
			press(pm, "release_1")
			check(game.pets.size() == 2, "первое нажатие «Отпустить» только спрашивает")
			press(pm, "release_1")
			check(game.pets.size() == 1, "питомец отпущен после подтверждения")
			check(pm.active_pet != null and game.active_pet == 0, "призванный питомец остался")
			main.hud.close_window()
			step = 10
		10:
			# Сохранение и загрузка коллекции
			var pet: Pet = pm.active_pet
			pet.hp = pet.max_hp
			pet.take_damage(10, null)
			hp_saved = pet.hp
			check(int(game.pets[0]["hp"]) == hp_saved, "HP питомца записан в коллекцию")
			check(game.save_game(), "игра сохранена")
			game.pets[0]["level"] = 99
			check(game.load_game(), "игра загружена")
			check(game.pets.size() == 1, "в коллекции 1 питомец")
			var r: Dictionary = game.pets[0]
			check(String(r["species"]) == "wolf" and int(r["level"]) == 15, "вид и уровень восстановлены")
			check(String(r["name"]) == PetData.stage_name("wolf", 15), "имя восстановлено")
			check(int(r["hp"]) == hp_saved and not bool(r["dead"]), "HP восстановлен")
			check(game.active_pet == 0, "призванный питомец восстановлен")
			_check_old_save()
			check(game.load_game(), "игра загружена снова")
			check(game.pets.size() == 1 and game.active_pet == 0, "коллекция после проверки старого сохранения")
			wait = 2
			step = 11
		11:
			check(pm.active_pet != null and is_same(pm.active_pet.record, game.pets[0]), "питомец привязан к загруженной записи")
			check(pm.active_pet.hp == hp_saved and pm.active_pet.level == 15, "питомец в мире с сохранёнными HP и уровнем")
			ok_done()


## Старое сохранение (виды bear/sparkbug/fairy и их трофеи) переводится в новые виды и предметы.
func _check_old_save() -> void:
	game.from_dict({
		"name": "Старый", "race": "human", "class": "warrior", "level": 5, "gold": 10,
		"inventory": {"bear_claw": 2, "fairy_dust": 1, "spark_core": 3, "panther_fang": 1, "hp_potion": 2},
		"pets": [
			{"species": "bear", "name": "Косолапик", "level": 20, "xp": 5, "hp": -1, "dead": false},
			{"species": "sparkbug", "name": "Искорка", "level": 3},
			{"species": "fairy", "name": "Росинка", "level": 31, "dead": true},
			{"species": "wolf", "name": "Серохвост", "level": 2},
		],
		"active_pet": 1,
	})
	var sp: Array = []
	for r in game.pets:
		sp.append(String(r["species"]))
	check(sp == ["panther", "turtle", "pheasant", "wolf"], "старые виды переведены: %s" % [sp])
	check(String(game.pets[0]["name"]) == PetData.stage_name("panther", 20), "имя — стадия нового вида: %s"
		% game.pets[0]["name"])
	check(int(game.pets[0]["level"]) == 20 and bool(game.pets[2]["dead"]), "уровень и гибель сохранены")
	check(String(game.pets[3]["name"]) == "Серохвост", "имя питомца прежнего вида не тронуто")
	check(game.active_pet == 1, "призванный питомец тот же")
	var inv: Inventory = game.inventory
	check(inv.count("panther_fang") == 3 and inv.count("pheasant_feather") == 1 and inv.count("shell_plate") == 3,
		"старые трофеи переведены в новые: %s" % [inv.to_dict()])
	check(not inv.has("bear_claw") and inv.count("hp_potion") == 2, "старых id в сумке нет, прочее на месте")


## Весь текст окна питомцев.
func _window_text(pm: PetManager) -> String:
	var t := ""
	if is_instance_valid(pm._window_body):
		for n in pm._window_body.find_children("*", "Label", true, false):
			t += (n as Label).text + "\n"
	return t


## Нажимает кнопку открытого окна питомцев.
func press(pm: PetManager, key: String) -> void:
	var b: Button = pm.window_buttons.get(key)
	check(b != null and is_instance_valid(b), "кнопка «%s» в окне питомцев" % key)
	if b != null:
		b.pressed.emit()
