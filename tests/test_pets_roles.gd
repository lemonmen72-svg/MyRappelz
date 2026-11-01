extends "res://tests/test_base.gd"
## Роли питомцев: танк провоцирует, лекарь лечит, маг бьёт снарядами и по площади, боец делает рывок.
## Новые виды: черепаха — танк, фазан — лекарь, пантера — маг (модели из файлов или запасные).
## Удар по площади каменного стража (в мире его нет — ставится тестом), карта существа своего вида (у кабана и
## стража карт нет — нельзя приручить, но питомцы этих видов, добавленные в коллекцию, призываются), приручение при полной коллекции (карта с душой ждёт в сумке,
## формирование — отказ), снятие метки со зверя, ушедшего домой.

const SPECIES := ["turtle", "pheasant", "panther", "wolf", "golem"]
## Уровни питомцев: маг и боец дерутся с дикими волками лугов (2–3 ур., «Обычные» — сильнее базовых зверей),
## поэтому они старше: бой с более слабым зверем не решает случай.
const LEVELS := {"panther": 5, "wolf": 5}

var mob: Mob = null
var timer := 0
var hp_low := 0


func before_start() -> void:
	for sp in SPECIES:
		game.add_pet(sp, PetData.stage_name(sp, 1), int(LEVELS.get(sp, 1)))
	game.active_pet = 0
	game.inventory.add("card_pheasant", 1)
	game.inventory.add("card_wolf", 1)


func run_step() -> void:
	var player: Player = main.player
	var pm: PetManager = main.pets
	var tm: Taming = main.taming
	match step:
		0:
			check(pm.active_pet != null and pm.active_pet.species == "turtle", "при запуске призван активный питомец")
			check(pm.active_pet.role == "tank", "черепаха — танк")
			var has_file := CreatureAsset.has_asset("turtle")
			check((pm.active_pet._asset != null) == has_file, "черепаха: модель %s" % ("из файла" if has_file else "запасная"))
			mob = find_mob("pheasant")
			check(mob != null, "найден фазан")
			timer = 0
			step = 1
		1:
			# Танк провоцирует зверя, напавшего на хозяина
			timer += 1
			var pet: Pet = pm.active_pet
			if timer == 1:
				stand_near(mob, 1.5)
				pet.global_position = player.global_position + Vector3(1.0, 0.2, 0)
				mob.target = player
				return
			if mob.is_dead:
				fail("фазан погиб раньше провокации")
				return
			stand_near(mob, 1.5)
			if pet.skill_uses > 0 and mob.target == pet:
				check(true, "танк спровоцировал зверя (%d)" % pet.skill_uses)
				mob.take_damage(mob.hp + 5, player)
				player.global_position = Vector3(0, 0.1, 2)
				step = 2
				return
			if timer > 60 * 5:
				fail("танк не провоцирует зверя")
		2:
			check(pm.summon(1), "фазан призван")
			wait = 2
			step = 3
		3:
			var pet: Pet = pm.active_pet
			check(pet != null and pet.role == "healer", "фазан — лекарь")
			pet.global_position = player.global_position + Vector3(1.0, 0.2, 1.0)
			player.hp = int(player.max_hp * 0.3)
			hp_low = player.hp
			timer = 0
			step = 4
		4:
			# Лекарь лечит хозяина
			timer += 1
			var pet: Pet = pm.active_pet
			if pet.skill_uses > 0 and player.hp > hp_low:
				check(true, "лекарь вылечил хозяина: %d -> %d" % [hp_low, player.hp])
				step = 5
				return
			if timer > 60 * 3:
				fail("лекарь не лечит хозяина")
		5:
			mob = find_mob("wolf")
			if mob == null:
				return
			check(pm.summon(2), "пантера призвана")
			timer = 0
			wait = 1
			step = 6
		6:
			# Маг: снаряды и удар по площади
			if _fight("mage"):
				step = 7
		7:
			mob = find_mob("wolf")
			if mob == null:
				return
			check(pm.summon(3), "волк призван")
			timer = 0
			wait = 1
			step = 8
		8:
			# Боец: рывок к цели
			if _fight("fighter"):
				step = 9
		9:
			check(pm.summon(4), "каменный страж-питомец призван")
			# Каменного стража на острове больше нет (там только существа Максима); его удар по площади остался
			# в коде — для проверки страж ставится на лугу вручную
			mob = Mob.new()
			mob.setup("golem", -1, IslandWorld.current.ground(30.0, 34.0), 10)
			main.add_child(mob)
			check(find_mob("golem") == mob, "дикий каменный страж поставлен")
			# Страж не босс и не «Редкий» — нейтрален (MobStats.is_aggressive): сам не нападает, герой бьёт первым
			check(not mob.aggressive, "дикий каменный страж нейтрален")
			mob.take_damage(1, player)
			check(mob.target == player, "после удара героя страж бьёт его")
			timer = 0
			step = 10
		10:
			# Уникальный страж бьёт по площади
			timer += 1
			if mob.is_dead:
				fail("страж погиб раньше удара по площади")
				return
			stand_near(mob, 2.0)
			if mob.skill_uses > 0:
				check(true, "каменный страж ударил по площади")
				pm.recall()
				player.global_position = Vector3(0, 0.1, 2)
				player.hp = player.max_hp
				wait = 2
				step = 11
				return
			if timer > 60 * 20:
				fail("страж не применяет удар по площади")
		11:
			# Карта существа — своя у каждого вида; кабана и стража приручить нельзя
			check(ItemData.card_for("wolf") == "card_wolf" and ItemData.card_for("pheasant") == "card_pheasant", "карты видов")
			check(ItemData.card_for("boar") == "" and ItemData.card_for("golem") == "", "у кабана и стража карт нет")
			check(Taming.badge_state("wolf") == Taming.BADGE_READY, "карта волка в сумке")
			check(Taming.badge_state("panther") == Taming.BADGE_NEED_CARD, "карты пантеры нет")
			check(Taming.badge_state("boar") == Taming.BADGE_NO and Taming.badge_state("golem") == Taming.BADGE_NO,
				"кабан и страж — фиолетовый значок «нельзя приручить»")
			# Полная коллекция (прирученный в старой версии кабан тоже в ней): метка ставится (душа ляжет в карту),
			# а формировать некуда
			game.add_pet("boar", PetData.stage_name("boar", 1), 1)
			check(game.pets.size() == Game.MAX_PETS, "коллекция полна")
			check(pm.summon(game.pets.size() - 1) and pm.active_pet != null and pm.active_pet.species == "boar", "прежний кабан-питомец призывается")
			pm.recall()
			mob = find_mob("wolf")
			check(mob != null, "найден волк")
			stand_near(mob)
			player.current_target = mob
			tm.cooldown = 0.0
			main._on_action("tame")
			check(tm.marked == mob and mob.tame_marked, "при полной коллекции метка ставится (карта с душой подождёт)")
			# Метка снимается, когда зверь уходит домой
			check(mob.get("_mark") != null, "метка видна на звере")
			mob.global_position = mob.home + Vector3(8, 0, 0)
			mob.target = null
			mob.returning = true
			player.global_position = Vector3(0, 0.1, 2)
			wait = 2
			step = 12
		12:
			check(tm.marked == null and not mob.tame_marked, "метка снята со зверя, ушедшего домой")
			# Фазан своей картой при полной коллекции: душа в карте, формирование — «Коллекция полна»
			mob = find_mob("pheasant")
			check(mob != null, "найден фазан")
			stand_near(mob, 3.0)
			player.current_target = mob
			tm.cooldown = 0.0
			main._on_action("tame")
			check(tm.marked == mob and mob.tame_marked, "фазан помечен (карта фазана)")
			var used: int = tm.attempts
			tm.force_roll = 0.0
			mob.take_damage(mob.hp + 5, player)
			tm.force_roll = -1.0
			check(tm.attempts == used + 1, "попытка засчитана")
			check(not game.inventory.has("card_pheasant") and game.inventory.has("card_pheasant_soul"),
				"карта фазана стала картой с душой")
			check(not tm.form("card_pheasant_soul"), "при полной коллекции не сформировать")
			check(main.hud._msg_label.text.contains("Коллекция полна"), "сообщение: " + main.hud._msg_label.text)
			check(game.inventory.has("card_pheasant_soul") and game.pets.size() == Game.MAX_PETS, "карта с душой осталась")
			game.remove_pet(game.pets.size() - 1)
			check(tm.form("card_pheasant_soul"), "место есть — существо сформировано")
			check(String(game.pets[game.pets.size() - 1]["species"]) == "pheasant", "сформирован фазан")
			ok_done()


## Умения питомца в текущем бою (запоминается — питомец может пасть одновременно со зверем).
var _uses := 0


## Бой призванного питомца роли role со зверем mob (питомец начинает в 6 м). true, когда зверь убит.
func _fight(role: String) -> bool:
	var player: Player = main.player
	var pet: Pet = main.pets.active_pet
	timer += 1
	# Зверь убит — бой выигран, даже если питомец пал в тот же миг от других зверей рядом
	if timer > 1 and mob.is_dead:
		if pet != null:
			_uses = maxi(_uses, pet.skill_uses)
		check(_uses > 0, "%s применил умение роли (%d)" % [role, _uses])
		return true
	if pet == null:
		fail("питомец не призван")
		return false
	_uses = pet.skill_uses
	if timer == 1:
		check(pet.role == role, "роль питомца: %s" % role)
		stand_near(mob, 2.0)
		pet.global_position = mob.global_position + Vector3(6.0, 0.2, 0)
		player.last_target = mob
		# Бой с уже раненым зверем, чтобы тест шёл недолго
		mob.hp = maxi(1, mob.max_hp / 3)
		# Другие звери рядом не мешают: питомец отвлекался на соседнего зверя и погибал раньше, чем добивал цель
		for n in get_tree().get_nodes_in_group("mobs"):
			var other := n as Mob
			if other != null and other != mob and other.global_position.distance_to(mob.global_position) < 30.0:
				other.queue_free()
		return false
	stand_near(mob, 2.0)
	player.last_target = mob
	if timer > 60 * 40:
		fail("%s не убил зверя (%s %d ур.)" % [role, mob.type_id, mob.level])
	return false
