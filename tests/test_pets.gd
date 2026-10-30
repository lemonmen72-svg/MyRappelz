extends "res://tests/test_base.gd"
## Питомцы: приручение кабана (метка → добить), редкий зверь без кристалла, призыв/отзыв через окно,
## помощь в бою и опыт, эволюция, смерть, воскрешение свитком, отпускание, сохранение коллекции.

const MAX_TRIES := 15

var mob: Mob = null
var tries := 0
var timer := 0
var xp_before := 0
var lvl_before := 0
var hp_saved := 0


func before_start() -> void:
	game.inventory.add("crystal_common", 20)
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
				check(PetData.SPECIES.has(id), "есть вид питомца для зверя %s" % id)
			check(PetData.role("bear") == "tank" and PetData.role("golem") == "tank", "медведь и страж — танки")
			check(PetData.role("fairy") == "healer" and PetData.role("sparkbug") == "mage", "фея — лекарь, искрожук — маг")
			check(PetData.role("boar") == "fighter" and PetData.role("wolf") == "fighter", "кабан и волк — бойцы")
			check(PetData.stage_for(1) == 0 and PetData.stage_for(14) == 0, "стадия 1 до 15 уровня")
			check(PetData.stage_for(15) == 1 and PetData.stage_for(30) == 2, "стадии 2 и 3 с 15 и 30 уровня")
			var s1 := PetData.stats_for("boar", 1)
			var s15 := PetData.stats_for("boar", 15)
			check(int(s15["max_hp"]) > int(s1["max_hp"]) and int(s15["atk"]) > int(s1["atk"]), "характеристики растут с уровнем")
			check(PetData.stage_scale("boar", 30) > PetData.stage_scale("boar", 1), "старшая стадия крупнее")
			step = 1
		1:
			# Редкого зверя без редкого кристалла не приручить
			mob = find_mob("fairy")
			check(mob != null, "найдена фея")
			stand_near(mob, 3.0)
			player.current_target = mob
			main._on_action("tame")
			check(tm.marked == null and not mob.tame_marked, "без редкого кристалла метка не ставится")
			var msg: String = main.hud._msg_label.text
			check(msg.contains(ItemData.item_name("crystal_rare")), "сообщение о нужном кристалле: " + msg)
			player.current_target = null
			player.global_position = Vector3(0, 0.1, 2)
			mob.target = null
			mob.returning = true
			step = 2
		2:
			# Приручение кабана: метка → добить → повторять до успеха
			if game.pets.size() > 0:
				check(String(game.pets[0]["species"]) == "boar", "приручен кабан за %d попыток" % tries)
				check(String(game.pets[0]["name"]) == PetData.stage_name("boar", 1), "имя питомца = название стадии 1")
				check(tm.crystals_used == tries, "на каждую попытку потрачен кристалл")
				step = 3
				return
			if tries >= MAX_TRIES:
				fail("кабан не приручен за %d попыток" % tries)
				return
			mob = find_mob("boar")
			if mob == null:
				return
			stand_near(mob)
			player.current_target = mob
			tm.cooldown = 0.0
			main._on_action("tame")
			check(tm.marked == mob and mob.tame_marked, "метка приручения на кабане")
			var used: int = tm.crystals_used
			mob.take_damage(mob.hp + 5, player)
			tries += 1
			check(tm.crystals_used == used + 1, "кристалл потрачен (попытка %d)" % tries)
			check(tm.marked == null and not mob.tame_marked, "метка снята после смерти зверя")
		3:
			check(pm.active_pet != null and game.active_pet == 0, "первый питомец сразу призван")
			check(main.hud._pet_box.visible, "панель питомца видна")
			main._on_action("pets_window")
			check(main.hud.is_window_open(), "окно питомцев открыто")
			press(pm, "recall_0")
			check(pm.active_pet == null and game.active_pet == -1, "питомец отозван")
			check(not main.hud._pet_box.visible, "панель питомца скрыта после отзыва")
			press(pm, "summon_0")
			check(pm.active_pet != null and game.active_pet == 0, "питомец призван снова")
			main.hud.close_window()
			step = 4
		4:
			# Питомец помогает убить зверя и получает опыт
			mob = find_mob("boar")
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
			if timer > 60 * 30:
				fail("питомец не добил зверя за 30 с")
				return
			if mob.is_dead:
				var pet: Pet = pm.active_pet
				check(pet != null and (pet.xp > xp_before or pet.level > lvl_before), "питомец получил опыт: %d" % pet.xp)
				check(int(game.pets[0]["xp"]) == pet.xp, "опыт записан в коллекцию")
				step = 6
				return
			stand_near(mob, 2.0)
			if mob.hp < mob.max_hp and timer % 60 == 0:
				print("  кабан: %d/%d" % [mob.hp, mob.max_hp])
		6:
			# Эволюция на 15 уровне
			var pet: Pet = pm.active_pet
			var old_max: int = pet.max_hp
			pet.level = 14
			pet.xp = PetData.xp_to_next(14) - 1
			pet.gain_xp(5)
			check(pet.level == 15, "питомец достиг 15 уровня")
			check(pet.stage == 1 and pet.pet_name == PetData.stage_name("boar", 15), "эволюция: %s" % pet.pet_name)
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
			check(String(r["species"]) == "boar" and int(r["level"]) == 15, "вид и уровень восстановлены")
			check(String(r["name"]) == PetData.stage_name("boar", 15), "имя восстановлено")
			check(int(r["hp"]) == hp_saved and not bool(r["dead"]), "HP восстановлен")
			check(game.active_pet == 0, "призванный питомец восстановлен")
			wait = 2
			step = 11
		11:
			check(pm.active_pet != null and is_same(pm.active_pet.record, game.pets[0]), "питомец привязан к загруженной записи")
			check(pm.active_pet.hp == hp_saved and pm.active_pet.level == 15, "питомец в мире с сохранёнными HP и уровнем")
			ok_done()


## Нажимает кнопку открытого окна питомцев.
func press(pm: PetManager, key: String) -> void:
	var b: Button = pm.window_buttons.get(key)
	check(b != null and is_instance_valid(b), "кнопка «%s» в окне питомцев" % key)
	if b != null:
		b.pressed.emit()
