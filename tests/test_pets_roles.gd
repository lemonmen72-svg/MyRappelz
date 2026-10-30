extends "res://tests/test_base.gd"
## Роли питомцев: танк провоцирует, лекарь лечит, маг бьёт снарядами и по площади, боец делает рывок.
## Новые виды: черепаха — танк, фазан — лекарь, пантера — маг (модели из файлов или запасные).
## Удар по площади каменного стража, выбор кристалла, старший кристалл для базового зверя,
## полная коллекция, снятие метки со зверя, ушедшего домой.

const SPECIES := ["turtle", "pheasant", "panther", "wolf", "golem"]

var mob: Mob = null
var timer := 0
var hp_low := 0


func before_start() -> void:
	for sp in SPECIES:
		game.add_pet(sp, PetData.stage_name(sp, 1), 1)
	game.active_pet = 0
	game.inventory.add("crystal_rare", 1)


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
			mob = find_mob("boar")
			check(mob != null, "найден кабан")
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
				fail("кабан погиб раньше провокации")
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
			mob = find_mob("boar")
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
			mob = find_mob("boar")
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
			mob = find_mob("golem")
			check(mob != null, "найден дикий каменный страж")
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
			# Выбор кристалла: самый дешёвый подходящий
			check(tm.pick_crystal("boar") == "crystal_common", "для кабана — базовый кристалл")
			check(tm.pick_crystal("pheasant") == "crystal_common", "для фазана — базовый кристалл")
			check(tm.pick_crystal("golem") == "", "для стража кристалла нет")
			check(tm.needed_crystal("golem") == "crystal_unique", "для стража нужен древний кристалл")
			# Полная коллекция
			game.add_pet("boar", PetData.stage_name("boar", 1), 1)
			check(game.pets.size() == Game.MAX_PETS, "коллекция полна")
			mob = find_mob("boar")
			check(mob != null, "найден кабан")
			stand_near(mob)
			player.current_target = mob
			tm.cooldown = 0.0
			main._on_action("tame")
			check(tm.marked == null and not mob.tame_marked, "при полной коллекции метка не ставится")
			game.remove_pet(game.pets.size() - 1)
			# Метка снимается, когда зверь уходит домой
			main._on_action("tame")
			check(tm.marked == mob and mob.tame_marked, "метка поставлена")
			check(mob.get("_mark") != null, "метка видна на звере")
			mob.global_position = mob.home + Vector3(8, 0, 0)
			mob.target = null
			mob.returning = true
			player.global_position = Vector3(0, 0.1, 2)
			wait = 2
			step = 12
		12:
			check(tm.marked == null and not mob.tame_marked, "метка снята со зверя, ушедшего домой")
			# Базовый зверь без базовых кристаллов: подходит старший (редкий)
			game.inventory.remove("crystal_common", game.inventory.count("crystal_common"))
			check(tm.pick_crystal("pheasant") == "crystal_rare", "без базового кристалла для фазана — редкий")
			mob = find_mob("pheasant")
			check(mob != null, "найден фазан")
			stand_near(mob, 3.0)
			player.current_target = mob
			tm.cooldown = 0.0
			main._on_action("tame")
			check(tm.marked == mob and mob.tame_marked, "фазан помечен (редким кристаллом)")
			var used: int = tm.crystals_used
			var pets_before: int = game.pets.size()
			mob.take_damage(mob.hp + 5, player)
			check(tm.crystals_used == used + 1, "редкий кристалл потрачен")
			check(not game.inventory.has("crystal_rare"), "редкого кристалла больше нет")
			if game.pets.size() > pets_before:
				check(String(game.pets[pets_before]["species"]) == "pheasant", "приручен фазан")
			ok_done()


## Бой призванного питомца роли role с кабаном mob (питомец начинает в 6 м). true, когда кабан убит.
func _fight(role: String) -> bool:
	var player: Player = main.player
	var pet: Pet = main.pets.active_pet
	timer += 1
	if pet == null:
		fail("питомец не призван")
		return false
	if timer == 1:
		check(pet.role == role, "роль питомца: %s" % role)
		stand_near(mob, 2.0)
		pet.global_position = mob.global_position + Vector3(6.0, 0.2, 0)
		player.last_target = mob
		return false
	if mob.is_dead:
		check(pet.skill_uses > 0, "%s применил умение роли (%d)" % [role, pet.skill_uses])
		return true
	stand_near(mob, 2.0)
	player.last_target = mob
	if timer > 60 * 40:
		fail("%s не убил кабана" % role)
	return false
