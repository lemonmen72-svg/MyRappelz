extends "res://tests/test_base.gd"
## Бой магов и движок умений (HeroSkillFx): Неофит (посох — магический снаряд издалека, сила — маг. атака;
## «Огненная искра» — снаряд, «Разряд» — мгновенно, «Глоток жизни» — лечит на долю урона), затем смена профессии
## на Волшебника («Световой толчок», «Свет в ладонях» — лечение себя, «Целительное касание» — лечение того, кому хуже,
## «Дар силы» — аура: Сила и атака выше, «Сила знаний» — маг. атака выше).

var mob: Mob = null
var t0 := 0
var shots := 0
var min_dist := 999.0
var hp_before := 0
var php_before := 0


func race_class() -> Array:
	return ["dark_elf", "neophyte"]


func hero_level() -> int:
	return 21


func run_step() -> void:
	var player: Player = main.player
	match step:
		0:
			check(player.attack_kind == "magic", "Неофит атакует магией")
			check(player.weapon_kind == "staff_2h" and player._weapon_kind == "staff", "у Неофита посох")
			check(player.matk >= player.hero_stats["matk"], "атака посохом — от маг. атаки: %d" % player.matk)
			mob = find_mob("pheasant")
			check(mob != null, "найден фазан")
			player.select_target(mob)
			t0 = frame
			step = 1
		1:
			if not mob_ok(mob):
				check(shots > 0, "Неофит убил фазана магией (выстрелов: %d)" % shots)
				check(min_dist > 5.0, "атака с расстояния больше 5 м (мин. %.1f м)" % min_dist)
				step = 2
				return
			if frame - t0 > 60 * 30:
				fail("Неофит не убил фазана за 30 с")
				return
			player.hp = player.max_hp
			var d := player.global_position.distance_to(mob.global_position)
			if d < 7.5 or d > 9.5:
				place_far(mob, 8.5)
				d = player.global_position.distance_to(mob.global_position)
			if player.try_attack():
				shots += 1
				min_dist = minf(min_dist, d)
				if shots == 1:
					var pr := first_projectile()
					check(pr != null and pr.kind == "orb", "магический шар летит к цели")
		2:
			learn_skills(["magic_training", "fire_spark", "zap", "life_sip"])
			for i in 3:
				check(player.assign_slot(String(["fire_spark", "zap", "life_sip"][i]), i), "умение на кнопке %d" % (i + 1))
			mob = find_mob("pheasant")
			check(mob != null, "найден фазан для «Огненной искры»")
			place_far(mob, 8.0)
			player.select_target(mob)
			player.mp = player.max_mp
			hp_before = mob.hp
			var before := get_tree().get_nodes_in_group("projectiles").size()
			check(use_now(player, "skill1"), "«Огненная искра» применена")
			check(get_tree().get_nodes_in_group("projectiles").size() > before, "огненный снаряд летит")
			check(mob.hp == hp_before, "урон — при попадании снаряда")
			check(player.cooldown_frac("skill1") > 0.9, "«Огненная искра» на перезарядке")
			check(not use_now(player, "skill1"), "повтор не срабатывает")
			t0 = frame
			step = 3
		3:
			if not mob_ok(mob) or mob.hp < hp_before:
				check(true, "«Огненная искра» попала")
				step = 4
			elif frame - t0 > 120:
				fail("«Огненная искра» не попала")
		4:
			mob = find_mob("pheasant")
			check(mob != null, "найден фазан для «Разряда»")
			place_far(mob, 8.0)
			player.select_target(mob)
			hp_before = mob.hp
			check(use_now(player, "skill2"), "«Разряд» применён")
			check(not mob_ok(mob) or mob.hp < hp_before, "«Разряд» бьёт сразу: %d → %d" % [hp_before, mob.hp if mob_ok(mob) else 0])
			step = 5
		5:
			mob = find_mob("wolf")
			if mob == null:
				mob = find_mob("pheasant")
			place_far(mob, 8.0)
			player.select_target(mob)
			calm_mobs()
			player.hp = player.max_hp / 2
			player.regen_delay = 100.0
			player.hp_regen = 0.0
			php_before = player.hp
			hp_before = mob.hp
			check(use_now(player, "skill3"), "«Глоток жизни» применён")
			t0 = frame
			step = 6
		6:
			if not mob_ok(mob) or mob.hp < hp_before:
				check(player.hp > php_before, "«Глоток жизни» вылечил: %d → %d" % [php_before, player.hp])
				step = 7
			elif frame - t0 > 120:
				fail("«Глоток жизни» не попал")
		7:
			# Смена профессии: Волшебник (светлые эльфы)
			game.race_id = "light_elf"
			become_job("wizard")
			check(game.class_id == "wizard" and player.attack_kind == "magic", "Волшебник: магия")
			check((game.hero["skills"] as Dictionary).is_empty(), "умения Неофита сброшены")
			var matk0 := player.matk
			learn_skills(["magic_training"])
			check(player.matk > matk0, "«Сила знаний»: маг. атака %d → %d" % [matk0, player.matk])
			learn_skills(["first_aid", "healing_touch", "light_pulse", "gift_vitality", "gift_strength"])
			player.assign_slot("light_pulse", 0)
			player.assign_slot("first_aid", 1)
			player.assign_slot("healing_touch", 2)
			player.assign_slot("gift_strength", 3)
			mob = find_mob("pheasant")
			place_far(mob, 8.0)
			player.select_target(mob)
			player.mp = player.max_mp
			hp_before = mob.hp
			check(use_now(player, "skill1"), "«Световой толчок» применён")
			t0 = frame
			step = 8
		8:
			if not mob_ok(mob) or mob.hp < hp_before:
				check(true, "«Световой толчок» попал")
				step = 9
			elif frame - t0 > 120:
				fail("«Световой толчок» не попал")
		9:
			player.hp = 20
			player.regen_delay = 100.0
			player.hp_regen = 0.0
			player.mp = player.max_mp
			check(use_now(player, "skill2"), "«Свет в ладонях» применён")
			check(player.hp >= 20 + int(player.max_hp * 0.15) - 1, "«Свет в ладонях» вылечил: 20 → %d" % player.hp)
			player.hp = 20
			check(not use_now(player, "skill2"), "повтор на перезарядке")
			check(player.hp == 20, "на перезарядке лечения нет")
			check(use_now(player, "skill3"), "«Целительное касание» (питомца нет — герой)")
			check(player.hp > 20, "«Целительное касание» вылечило героя: %d" % player.hp)
			# Аура «Дар силы»: Сила и атака выше
			var str0 := int(player.hero_stats["stats"]["str"])
			var atk0 := player.atk
			check(use_now(player, "skill4") and HeroSkills.toggle_on(game.hero, "gift_strength"), "«Дар силы» включён")
			check(int(player.hero_stats["stats"]["str"]) > str0 and player.atk > atk0,
				"Сила %d → %d, атака %d → %d" % [str0, int(player.hero_stats["stats"]["str"]), atk0, player.atk])
			check(use_now(player, "skill4") and not HeroSkills.toggle_on(game.hero, "gift_strength"), "«Дар силы» выключен")
			ok_done()


## Ставит игрока на dist м от зверя, дальше от центра карты (вне безопасной зоны).
func place_far(m: Mob, dist: float) -> void:
	var p: Player = main.player
	var dir := Vector3(m.global_position.x, 0.0, m.global_position.z)
	if dir.length() < 0.1:
		dir = Vector3(0, 0, 1)
	var pos := m.global_position + dir.normalized() * dist
	if IslandWorld.current != null:
		pos.y = IslandWorld.current.height_at(pos.x, pos.z) + 0.1
	p.global_position = pos
	p.hp = p.max_hp


## Оглушает всех зверей на 2 с, чтобы их удары не мешали проверке лечения.
func calm_mobs() -> void:
	for n in get_tree().get_nodes_in_group("mobs"):
		var m := n as Mob
		if m != null:
			m.stun(2.0)


func first_projectile() -> Projectile:
	for n in get_tree().get_nodes_in_group("projectiles"):
		return n as Projectile
	return null
