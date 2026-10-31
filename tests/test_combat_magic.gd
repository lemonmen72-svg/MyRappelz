extends "res://tests/test_base.gd"
## Бой магов: Чернокнижник (магический снаряд, «Взрыв тьмы», «Похищение жизни»),
## затем смена класса на Жреца («Луч света», «Исцеление»).

var mob: Mob = null
var t0 := 0
var shots := 0
var min_dist := 999.0
var hp_before := 0
var php_before := 0


func race_class() -> Array:
	return ["dark_elf", "warlock"]


func run_step() -> void:
	var player: Player = main.player
	match step:
		0:
			check(player.attack_kind == "magic", "чернокнижник атакует магией")
			check(player._weapon_kind == "staff", "у чернокнижника посох")
			check(player.skill_id("skill1") == "dark_burst" and player.skill_id("skill2") == "drain",
				"умения чернокнижника на кнопках")
			mob = find_mob("pheasant")
			check(mob != null, "найден фазан")
			player.select_target(mob)
			t0 = frame
			step = 1
		1:
			if not mob_ok(mob):
				check(shots > 0, "чернокнижник убил фазана магией (выстрелов: %d)" % shots)
				check(min_dist > 5.0, "атака с расстояния больше 5 м (мин. %.1f м)" % min_dist)
				step = 2
				return
			if frame - t0 > 60 * 30:
				fail("чернокнижник не убил фазана за 30 с")
				return
			player.hp = player.max_hp
			var d := player.global_position.distance_to(mob.global_position)
			if d < 7.5 or d > 10.5:
				place_far(mob, 9.0)
				d = player.global_position.distance_to(mob.global_position)
			if player.try_attack():
				shots += 1
				min_dist = minf(min_dist, d)
				if shots == 1:
					var pr := first_projectile()
					check(pr != null and pr.kind == "orb", "магический шар летит к цели")
		2:
			mob = find_mob("pheasant")
			check(mob != null, "найден фазан для «Взрыва тьмы»")
			place_far(mob, 8.0)
			player.select_target(mob)
			hp_before = mob.hp
			check(player.use_skill("skill1"), "«Взрыв тьмы» применён")
			check(player.cooldown_frac("skill1") > 0.9, "«Взрыв тьмы» на перезарядке")
			check(not player.use_skill("skill1"), "повтор «Взрыва тьмы» не срабатывает")
			t0 = frame
			step = 3
		3:
			if not mob_ok(mob) or mob.hp < hp_before:
				check(true, "«Взрыв тьмы» нанёс урон")
				step = 4
			elif frame - t0 > 120:
				fail("«Взрыв тьмы» не попал")
		4:
			mob = find_mob("pheasant")
			check(mob != null, "найден фазан для «Похищения жизни»")
			place_far(mob, 8.0)
			player.select_target(mob)
			calm_mobs()
			player.hp = player.max_hp / 2
			player.regen_delay = 100.0
			php_before = player.hp
			hp_before = mob.hp
			check(player.use_skill("skill2"), "«Похищение жизни» применено")
			check(player.cooldown_frac("skill2") > 0.9, "«Похищение жизни» на перезарядке")
			check(not player.use_skill("skill2"), "повтор «Похищения жизни» не срабатывает")
			t0 = frame
			step = 5
		5:
			if not mob_ok(mob) or mob.hp < hp_before:
				check(true, "«Похищение жизни» нанесло урон")
				check(player.hp > php_before, "«Похищение жизни» вылечило: %d → %d" % [php_before, player.hp])
				step = 6
			elif frame - t0 > 120:
				fail("«Похищение жизни» не попало")
		6:
			game.race_id = "light_elf"
			game.class_id = "cleric"
			player.apply_class()
			check(player.attack_kind == "magic" and player._weapon_kind == "staff", "жрец: магия, посох")
			check(player.skill_id("skill1") == "holy_bolt" and player.skill_id("skill2") == "heal",
				"умения жреца на кнопках")
			mob = find_mob("pheasant")
			check(mob != null, "найден фазан для «Луча света»")
			place_far(mob, 8.0)
			player.select_target(mob)
			hp_before = mob.hp
			check(player.use_skill("skill1"), "«Луч света» применён")
			check(player.cooldown_frac("skill1") > 0.9, "«Луч света» на перезарядке")
			check(not player.use_skill("skill1"), "повтор «Луча света» не срабатывает")
			t0 = frame
			step = 7
		7:
			if not mob_ok(mob) or mob.hp < hp_before:
				check(true, "«Луч света» нанёс урон")
				step = 8
			elif frame - t0 > 120:
				fail("«Луч света» не попал")
		8:
			player.hp = 20
			player.regen_delay = 100.0
			var expect := 20 + int(player.max_hp * 0.35)
			check(player.use_skill("skill2"), "«Исцеление» применено")
			check(player.hp >= mini(expect, player.max_hp), "«Исцеление» вылечило: 20 → %d" % player.hp)
			check(player.cooldown_frac("skill2") > 0.9, "«Исцеление» на перезарядке")
			player.hp = 20
			check(not player.use_skill("skill2"), "повтор «Исцеления» не срабатывает")
			check(player.hp == 20, "на перезарядке лечения нет")
			ok_done()


## Ставит игрока на dist м от зверя, дальше от центра карты (вне безопасной зоны).
func place_far(m: Mob, dist: float) -> void:
	var p: Player = main.player
	var dir := Vector3(m.global_position.x, 0.0, m.global_position.z)
	if dir.length() < 0.1:
		dir = Vector3(0, 0, 1)
	p.global_position = m.global_position + dir.normalized() * dist
	p.hp = p.max_hp


## Оглушает всех зверей на 2 с, чтобы их удары не мешали проверке лечения.
func calm_mobs() -> void:
	for n in get_tree().get_nodes_in_group("mobs"):
		var m := n as Mob
		if m != null:
			m.stun(2.0)


func first_projectile() -> Projectile:
	for n in get_tree().get_nodes_in_group("projectiles"):
		var pr := n as Projectile
		if pr != null:
			return pr
	return null
