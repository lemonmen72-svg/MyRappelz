extends "res://tests/test_base.gd"
## Бой: Следопыт (лук, снаряды, «Меткий выстрел», «Быстрый шаг», «Нет цели рядом»),
## затем смена класса на Воина (ближний бой, «Рассечение», «Боевой клич»).

var mob: Mob = null
var t0 := 0
var shots := 0
var min_dist := 999.0
var hp_before := 0
var val_before := 0.0


func race_class() -> Array:
	return ["human", "ranger"]


func run_step() -> void:
	var player: Player = main.player
	match step:
		0:
			check(player.attack_kind == "ranged", "следопыт стреляет издалека")
			check(player._weapon_kind == "bow", "у следопыта лук")
			check(player.skill_id("skill1") == "power_shot" and player.skill_id("skill2") == "quick_step",
				"умения следопыта на кнопках")
			check(player.cooldown_frac("skill1") == 0.0, "умение готово в начале")
			mob = find_mob("pheasant")
			check(mob != null, "найден фазан")
			player.select_target(mob)
			t0 = frame
			step = 1
		1:
			if not mob_ok(mob):
				check(shots > 0, "следопыт убил фазана стрелами (выстрелов: %d)" % shots)
				check(min_dist > 5.0, "стрельба с расстояния больше 5 м (мин. %.1f м)" % min_dist)
				check(game.xp > 0, "опыт за убийство получен")
				step = 2
				return
			if frame - t0 > 60 * 30:
				fail("следопыт не убил фазана за 30 с")
				return
			player.hp = player.max_hp
			var d := player.global_position.distance_to(mob.global_position)
			if d < 8.0 or d > 11.0:
				place_far(mob, 9.0)
				d = player.global_position.distance_to(mob.global_position)
			if player.try_attack():
				shots += 1
				min_dist = minf(min_dist, d)
				if shots == 1:
					check(count_projectiles() > 0, "стрела летит к цели")
					check(mob.hp == mob.max_hp, "урон наносится при попадании, а не сразу")
		2:
			mob = find_mob("pheasant")
			check(mob != null, "найден фазан для «Меткого выстрела»")
			place_far(mob, 9.0)
			player.select_target(mob)
			hp_before = mob.hp
			check(player.use_skill("skill1"), "«Меткий выстрел» применён")
			check(player.cooldown_frac("skill1") > 0.9, "«Меткий выстрел» на перезарядке")
			check(not player.use_skill("skill1"), "повтор на перезарядке не срабатывает")
			t0 = frame
			step = 3
		3:
			if not mob_ok(mob) or mob.hp < hp_before:
				check(true, "«Меткий выстрел» попал: HP %d → %d" % [hp_before, mob.hp if mob_ok(mob) else 0])
				step = 4
			elif frame - t0 > 120:
				fail("«Меткий выстрел» не попал")
		4:
			val_before = player.cur_speed()
			check(player.use_skill("skill2"), "«Быстрый шаг» применён")
			check(player.cur_speed() > val_before * 1.3, "скорость выросла: %.1f → %.1f" % [val_before, player.cur_speed()])
			check(player.cooldown_frac("skill2") > 0.9, "«Быстрый шаг» на перезарядке")
			check(not player.use_skill("skill2"), "повтор «Быстрого шага» не срабатывает")
			wait = 60 * 5 + 30
			step = 5
		5:
			check(is_equal_approx(player.cur_speed(), player.speed), "ускорение закончилось через 5 с")
			wait = 120
			step = 6
		6:
			# Цели нет: игрок в углу карты, звери далеко
			player.global_position = Vector3(68, 0.1, 68)
			player.select_target(null)
			check(player.cooldown_frac("skill1") == 0.0, "«Меткий выстрел» перезарядился")
			if Util.nearest(player, "mobs", player.attack_range + 1.0) != null:
				print("Пропуск проверки «Нет цели рядом»: рядом зверь")
			else:
				check(not player.use_skill("skill1"), "без цели умение не срабатывает")
				check(main.hud._msg_label.text == "Нет цели рядом", "сообщение «Нет цели рядом»")
				check(player.cooldown_frac("skill1") == 0.0, "перезарядка не потрачена")
				check(not player.try_attack(), "без цели атака не срабатывает")
			step = 7
		7:
			game.class_id = "warrior"
			player.apply_class()
			check(player.attack_kind == "melee" and player._weapon_kind == "axe", "воин: ближний бой, топор")
			check(player.skill_id("skill1") == "cleave", "умения воина на кнопках")
			mob = find_mob("pheasant")
			check(mob != null, "найден фазан для воина")
			player.select_target(mob)
			t0 = frame
			step = 8
		8:
			if not mob_ok(mob):
				check(true, "воин убил фазана в ближнем бою")
				step = 9
				return
			if frame - t0 > 60 * 30:
				fail("воин не убил фазана за 30 с")
				return
			stand_near(mob)
			player.try_attack()
		9:
			mob = find_mob("pheasant")
			check(mob != null, "найден фазан для «Рассечения»")
			stand_near(mob)
			hp_before = mob.hp
			check(player.use_skill("skill1"), "«Рассечение» применено")
			check(not mob_ok(mob) or mob.hp < hp_before, "«Рассечение» нанесло урон")
			check(player.cooldown_frac("skill1") > 0.9, "«Рассечение» на перезарядке")
			check(not player.use_skill("skill1"), "повтор «Рассечения» не срабатывает")
			step = 10
		10:
			val_before = float(player.cur_atk())
			check(player.use_skill("skill2"), "«Боевой клич» применён")
			check(float(player.cur_atk()) > val_before, "атака выросла: %d → %d" % [int(val_before), player.cur_atk()])
			check(player.atk_buff_time > 0.0, "таймер усиления идёт")
			check(not player.use_skill("skill2"), "повтор «Боевого клича» не срабатывает")
			ok_done()


## Ставит игрока на dist м от зверя, дальше от центра карты (вне безопасной зоны).
func place_far(m: Mob, dist: float) -> void:
	var p: Player = main.player
	var dir := Vector3(m.global_position.x, 0.0, m.global_position.z)
	if dir.length() < 0.1:
		dir = Vector3(0, 0, 1)
	p.global_position = m.global_position + dir.normalized() * dist
	p.hp = p.max_hp


func count_projectiles() -> int:
	return get_tree().get_nodes_in_group("projectiles").size()
