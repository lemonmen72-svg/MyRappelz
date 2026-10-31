extends "res://tests/test_base.gd"
## Ближний бой: Страж (меч и щит, «Удар щитом» с оглушением, «Щит света»),
## затем смена класса на Наёмника (парные мечи, «Удар в спину» с критом, «Шаг тени»).

var mob: Mob = null
var t0 := 0
var hp_before := 0


func race_class() -> Array:
	return ["light_elf", "guardian"]


func run_step() -> void:
	var player: Player = main.player
	match step:
		0:
			check(player.attack_kind == "melee", "страж бьёт в ближнем бою")
			check(player._weapon_kind == "sword_shield", "у стража меч и щит")
			check(player.skill_id("skill1") == "shield_bash" and player.skill_id("skill2") == "holy_guard",
				"умения стража на кнопках")
			mob = find_mob("pheasant")
			check(mob != null, "найден фазан")
			player.select_target(mob)
			t0 = frame
			step = 1
		1:
			if not mob_ok(mob):
				check(true, "страж убил фазана")
				step = 2
				return
			if frame - t0 > 60 * 30:
				fail("страж не убил фазана за 30 с")
				return
			stand_near(mob)
			player.try_attack()
		2:
			mob = find_mob("pheasant")
			check(mob != null, "найден фазан для «Удара щитом»")
			stand_near(mob)
			player.select_target(mob)
			hp_before = mob.hp
			check(player.use_skill("skill1"), "«Удар щитом» применён")
			check(not mob_ok(mob) or mob.hp < hp_before, "«Удар щитом» нанёс урон")
			check(not mob_ok(mob) or mob.stun_time > 0.0, "зверь оглушён: %.1f с" % (mob.stun_time if mob_ok(mob) else 0.0))
			check(player.cooldown_frac("skill1") > 0.9, "«Удар щитом» на перезарядке")
			check(not player.use_skill("skill1"), "повтор «Удара щитом» не срабатывает")
			step = 3
		3:
			player.hp = player.max_hp
			var h0 := player.hp
			player.take_damage(40, null)
			var d1 := h0 - player.hp
			player.hp = player.max_hp
			check(player.use_skill("skill2"), "«Щит света» применён")
			check(player.guard_time > 0.0 and player._guard_fx.visible, "«Щит света» активен и виден")
			player.take_damage(40, null)
			var d2 := player.max_hp - player.hp
			check(d2 < d1 and d2 <= d1 / 2 + 1, "урон под щитом снижен: %d → %d" % [d1, d2])
			check(player.cooldown_frac("skill2") > 0.9, "«Щит света» на перезарядке")
			check(not player.use_skill("skill2"), "повтор «Щита света» не срабатывает")
			player.hp = player.max_hp
			step = 4
		4:
			game.race_id = "dark_elf"
			game.class_id = "assassin"
			player.apply_class()
			check(player.attack_kind == "melee" and player._weapon_kind == "dual_swords", "наёмник: парные мечи")
			check(game.weapon == "dual_swords_starter" and game.inventory.has("crossbow_starter"),
				"при смене класса на Наёмника выдан стартовый набор оружия")
			check(player.guard_time == 0.0, "усиления сброшены при смене класса")
			check(player.skill_id("skill1") == "backstab" and player.skill_id("skill2") == "shadow_step",
				"умения убийцы на кнопках")
			mob = find_mob("pheasant")
			check(mob != null, "найден фазан для «Удара в спину»")
			stand_near(mob)
			player.select_target(mob)
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
