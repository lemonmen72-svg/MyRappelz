extends "res://tests/test_base.gd"
## Общий автотест: мир, сенсорный HUD, бой, опыт и золото, зелье, смерть, сохранение, респавн.

const MainScript := preload("res://main.gd")

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
			check(player.global_position.distance_to(player.respawn_point()) < 1.5, "игрок возродился в деревне расы")
			step = 5
		5:
			check(game.save_game(), "игра сохранена")
			var lvl: int = game.level
			var gold: int = game.gold
			var potions: int = game.inventory.count("hp_potion")
			var scrolls: int = game.inventory.count("revive_scroll")
			game.level = 99
			game.gold = 0
			game.inventory.from_dict({})
			check(game.load_game(), "игра загружена")
			check(game.level == lvl and game.gold == gold, "уровень и золото восстановлены")
			check(potions >= 1 and scrolls >= 1 and game.inventory.count("hp_potion") == potions
				and game.inventory.count("revive_scroll") == scrolls, "сумка восстановлена (зелий: %d)" % potions)
			check(game.char_name == "Тест", "персонаж восстановлен")
			# Герой игрока — всегда Наёмник: сохранённый воин (класс автотеста) переведён при загрузке
			check(game.race_id == "dark_elf" and game.class_id == "assassin" and game.load_note != "",
				"воин из сохранения стал Наёмником: %s" % game.load_note)
			check(game.weapon == "dual_swords_starter", "переведённому герою надеты парные мечи")
			player.apply_class()
			check(player.max_mp > 0 and not player.hero_stats.is_empty(), "у переведённого героя MP и 7 статов")
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
	_test_camera_zoom(hud, view)


## Щипок двумя пальцами в правой половине: развели — камера ближе, свели — дальше.
func _test_camera_zoom(hud: HUD, view: Vector2) -> void:
	var a := Vector2(view.x * 0.62, view.y * 0.45)
	var b := Vector2(view.x * 0.72, view.y * 0.45)
	touch(true, 0, a)
	touch(true, 1, b)
	var d := InputEventScreenDrag.new()
	d.index = 1
	d.position = b + Vector2(120, 0)
	hud._input(d)
	var z := hud.take_camera_zoom()
	check(z < 0.6, "щипок «развести» приближает камеру: ×%.2f" % z)
	check(hud.take_camera_drag() == Vector2.ZERO, "щипок не вращает камеру")
	d = InputEventScreenDrag.new()
	d.index = 1
	d.position = b
	hud._input(d)
	z = hud.take_camera_zoom()
	check(z > 1.5, "щипок «свести» отдаляет камеру: ×%.2f" % z)
	touch(false, 1, b)
	touch(false, 0, a)
	check(hud._cam_touches.is_empty(), "касания камеры отпущены")
	var before: float = main.cam_dist
	hud._cam_zoom = 0.01
	main._process(0.016)
	check(is_equal_approx(main.cam_dist, MainScript.CAM_DIST_MIN), "камера не ближе %.1f м" % MainScript.CAM_DIST_MIN)
	hud._cam_zoom = 1000.0
	main._process(0.016)
	check(is_equal_approx(main.cam_dist, MainScript.CAM_DIST_MAX), "камера не дальше %.1f м" % MainScript.CAM_DIST_MAX)
	main.cam_dist = before
