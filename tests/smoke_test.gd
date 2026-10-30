extends "res://tests/test_base.gd"
## Общий автотест: мир, сенсорный HUD, бой, опыт и золото, зелье, смерть, сохранение, респавн.

var mob: Mob = null
var gold_before := 0
var potions_before := 0


func run_step() -> void:
	var player: Player = main.player
	match step:
		0:
			check(player != null and main.hud != null, "игрок и HUD созданы")
			check(count_mobs() == main._slots.size(), "звери заспавнены: %d" % count_mobs())
			_test_touch()
			gold_before = game.gold
			step = 1
		1:
			mob = find_mob("boar")
			check(mob != null, "найден кабан")
			step = 2
		2:
			if not mob_ok(mob):
				check(game.xp > 0 or game.level > 1, "игрок получил опыт")
				check(game.gold > gold_before, "игрок получил золото")
				step = 3
				return
			stand_near(mob)
			player.try_attack()
		3:
			player.hp = 10
			potions_before = game.inventory.count("hp_potion")
			main._on_action("potion")
			check(player.hp > 10, "зелье лечит")
			check(game.inventory.count("hp_potion") == potions_before - 1, "зелье потрачено")
			step = 4
		4:
			player.take_damage(99999, null)
			check(player.hp == player.max_hp, "игрок возродился с полным HP")
			check(player.global_position.length() < 1.0, "игрок возродился в центре")
			step = 5
		5:
			check(game.save_game(), "игра сохранена")
			var lvl: int = game.level
			var gold: int = game.gold
			game.level = 99
			game.gold = 0
			game.inventory.from_dict({})
			check(game.load_game(), "игра загружена")
			check(game.level == lvl and game.gold == gold, "уровень и золото восстановлены")
			check(game.inventory.count("crystal_common") == 3, "сумка восстановлена")
			check(game.char_name == "Тест" and game.class_id == "warrior", "персонаж восстановлен")
			wait = 60 * 21
			step = 6
		6:
			check(count_mobs() == main._slots.size(), "звери респавнятся: %d/%d" % [count_mobs(), main._slots.size()])
			ok_done()


func _test_touch() -> void:
	var hud: HUD = main.hud
	var view: Vector2 = hud._view
	if view.x < 400.0:
		print("Пропуск теста касаний: размер окна %s" % view)
		return
	var start := Vector2(view.x * 0.2, view.y * 0.7)
	touch(true, 0, start)
	var d := InputEventScreenDrag.new()
	d.index = 0
	d.position = start + Vector2(80, 0)
	hud._input(d)
	check(hud.move_vec.x > 0.5, "джойстик двигает вправо: %s" % hud.move_vec)
	touch(true, 1, button_center("attack"))
	check(hud.is_held("attack") and hud._joy_idx == 0, "мультитач: джойстик + атака")
	touch(false, 0, start)
	touch(false, 1, button_center("attack"))
	check(hud._joy_idx == -1 and not hud.is_held("attack"), "касания отпущены")
	touch(true, 0, Vector2(view.x * 0.2, 100.0))
	check(hud._joy_idx == -1, "джойстик не начинается в зоне панелей")
	touch(false, 0, Vector2(view.x * 0.2, 100.0))
