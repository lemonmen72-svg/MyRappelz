extends "res://tests/test_base.gd"
## Ближний бой: Мечник (светлые эльфы, учебный меч и щит во второй руке: защита щита, «Стена щита» — блок,
## «Карающий удар», «Сковывающий удар» — замедление, «Вызов» — зверь бьёт героя; щит снимается при двуручном
## оружии), затем смена профессии на Наёмника (парные мечи, «Удар в спину» с критом, «Шаг тени»).

var mob: Mob = null
var t0 := 0
var hp_before := 0


func race_class() -> Array:
	return ["light_elf", "swordsman"]


func hero_level() -> int:
	return 25


func run_step() -> void:
	var player: Player = main.player
	match step:
		0:
			check(player.attack_kind == "melee", "Мечник бьёт в ближнем бою")
			check(game.weapon == "weapon_sword_1h_r1" and game.shield == "weapon_shield_r1" and player.has_shield,
				"у Мечника учебный меч и деревянный щит")
			check(game.inventory.find_cell("weapon_shield_r1") < 0 and game.inventory.find_cell("weapon_sword_1h_r1") < 0,
				"надетые меч и щит не занимают ячеек")
			var d0 := player.defense
			game.unequip_shield()
			player.refresh_skills()
			check(player.defense < d0, "щит даёт защиту: %d → %d" % [player.defense, d0])
			check(player.equip("weapon_shield_r1") == "" and player.has_shield, "щит снова во второй руке")
			mob = find_mob("pheasant")
			check(mob != null, "найден фазан")
			player.select_target(mob)
			t0 = frame
			step = 1
		1:
			if not mob_ok(mob):
				check(true, "Мечник убил фазана")
				step = 2
				return
			if frame - t0 > 60 * 30:
				fail("Мечник не убил фазана за 30 с")
				return
			stand_near(mob)
			player.try_attack()
		2:
			learn_skills(["shield_wall", "challenge", "holy_strike", "binding_strike"])
			check(player.block > 0.0, "«Стена щита»: блок %.0f%%" % (player.block * 100.0))
			var blocked := 0
			var m := find_mob("pheasant")
			player.block = 0.5
			for i in 60:
				player.hp = player.max_hp
				player.take_damage(5, m)
				if player.hp == player.max_hp:
					blocked += 1
			player.refresh_skills()
			check(blocked > 0, "удары зверя приходятся в щит: %d из 60" % blocked)
			for i in 3:
				player.assign_slot(String(["holy_strike", "binding_strike", "challenge"][i]), i)
			mob = find_mob("wolf")
			if mob == null:
				mob = find_mob("pheasant")
			stand_near(mob)
			player.select_target(mob)
			player.mp = player.max_mp
			hp_before = mob.hp
			check(player.use_skill("skill1"), "«Карающий удар» применён")
			check(not mob_ok(mob) or mob.hp < hp_before, "«Карающий удар» нанёс урон")
			check(player.cooldown_frac("skill1") > 0.9 and not player.use_skill("skill1"), "«Карающий удар» на перезарядке")
			step = 3
		3:
			mob = find_mob("wolf")
			if mob == null:
				mob = find_mob("pheasant")
			stand_near(mob)
			player.select_target(mob)
			check(player.use_skill("skill2"), "«Сковывающий удар» применён")
			check(not mob_ok(mob) or (mob.slow_time > 0.0 and mob.effects.has("slow")), "зверь замедлен, значок у цели")
			mob = find_mob("pheasant")
			stand_near(mob)
			player.select_target(mob)
			check(player.use_skill("skill3"), "«Вызов» применён")
			check(mob.returning or (mob.target == player and mob.taunt_time > 0.0), "зверь бьёт героя (провокация)")
			# Двуручное оружие снимает щит
			game.inventory.add("weapon_sword_2h_r1")
			check(player.equip("weapon_sword_2h_r1") == "" and not player.has_shield and game.shield == "",
				"двуручный меч — щит снят")
			check(player.equip("weapon_shield_r1") != "", "к двуручному щит не надеть")
			step = 4
		4:
			game.race_id = "dark_elf"
			become_job("assassin")
			check(player.attack_kind == "melee" and player._weapon_kind == "daggers", "Наёмник: два кинжала")
			check(game.weapon == "weapon_dagger_r1" and game.offhand == "weapon_dagger_r1" and game.inventory.has("crossbow_starter"),
				"при смене профессии на Наёмника выдан стартовый набор оружия")
			check(player.skill_id("skill1") == "backstab" and player.skill_id("skill2") == "shadow_step",
				"стартовые умения Наёмника на кнопках")
			mob = find_mob("pheasant")
			check(mob != null, "найден фазан для «Удара в спину»")
			stand_near(mob)
			player.select_target(mob)
			player.mp = player.max_mp
			hp_before = mob.hp
			check(player.use_skill("skill1"), "«Удар в спину» применён")
			check(player._last_crit, "«Удар в спину» — гарантированный крит")
			check(not mob_ok(mob) or hp_before - mob.hp >= 12, "«Удар в спину» нанёс урон")
			check(player.cooldown_frac("skill1") > 0.9, "«Удар в спину» на перезарядке")
			check(not player.use_skill("skill1"), "повтор «Удара в спину» не срабатывает")
			step = 5
		5:
			mob = find_mob("wolf")
			if mob == null:
				mob = find_mob("pheasant")
			check(mob != null, "найден зверь для «Шага тени»")
			place_far(mob, 8.0)
			player.select_target(mob)
			var before := player.global_position.distance_to(mob.global_position)
			check(player.use_skill("skill2"), "«Шаг тени» применён")
			var after := player.global_position.distance_to(mob.global_position)
			check(after < 2.0 and after > 1.0, "рывок к цели: %.1f м → %.1f м" % [before, after])
			check(player.current_target == mob, "цель сохранена после рывка")
			check(player.cooldown_frac("skill2") > 0.9, "«Шаг тени» на перезарядке")
			check(not player.use_skill("skill2"), "повтор «Шага тени» не срабатывает")
			ok_done()


## Ставит игрока на dist м от зверя, дальше от центра карты (вне безопасной зоны).
func place_far(m: Mob, dist: float) -> void:
	var p: Player = main.player
	var dir := Vector3(m.global_position.x, 0.0, m.global_position.z)
	if dir.length() < 0.1:
		dir = Vector3(0, 0, 1)
	p.global_position = m.global_position + dir.normalized() * dist
	p.hp = p.max_hp
