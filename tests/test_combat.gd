extends "res://tests/test_base.gd"
## Бой Воина (люди, двуручный топор): ближний бой, движок умений (HeroSkillFx) — «Удар с разворота» (урон оружием,
## MP, перезарядка, «Нет цели рядом»), «Миг сосредоточения» (усиление на время: шанс крита, значок, окончание),
## пассивка владения «Боевая выучка» (только с мечом или топором), «Школа лука» без лука не действует.

var mob: Mob = null
var t0 := 0
var hp_before := 0
var val_before := 0.0


func race_class() -> Array:
	return ["human", "warrior"]


func hero_level() -> int:
	return 14


func run_step() -> void:
	var player: Player = main.player
	match step:
		0:
			check(player.attack_kind == "melee", "воин бьёт в ближнем бою")
			check(game.weapon == "weapon_axe_2h_r1" and player.weapon_kind == "axe_2h", "у Воина двуручный топор")
			check(player._weapon_kind == "axe" and player._model.find_child("Axe", true, false) != null
				or player._model._asset == null, "модель держит топор")
			check(player.skill_id("skill1") == "" and not main.hud.is_button_visible("skill1"), "без изученных умений кнопки скрыты")
			mob = find_mob("pheasant")
			check(mob != null, "найден фазан")
			player.select_target(mob)
			t0 = frame
			step = 1
		1:
			if not mob_ok(mob):
				check(game.xp > 0, "Воин убил фазана, опыт получен")
				step = 2
				return
			if frame - t0 > 60 * 30:
				fail("Воин не убил фазана за 30 с")
				return
			stand_near(mob)
			player.try_attack()
		2:
			# Пассивки: «Боевая выучка» с топором — атака выше; «Школа лука» без лука не действует
			var atk0 := player.atk
			learn_skills(["combat_drill", "bow_mastery", "spin_strike", "focus_moment"])
			check(player.atk > atk0, "«Боевая выучка» с топором: атака %d → %d" % [atk0, player.atk])
			check(not HeroSkills.weapon_ok("bow_mastery", player.weapon_kind) and HeroSkills.weapon_ok("combat_drill", "axe_2h"),
				"«Школа лука» — только с луком, «Боевая выучка» — с топором")
			check(player.assign_slot("spin_strike", 0) and player.assign_slot("focus_moment", 1), "умения на кнопках 1 и 2")
			check(main.hud.is_button_visible("skill1") and main.hud.button_text("skill1") == "Удар с разворота",
				"кнопка 1: «%s»" % main.hud.button_text("skill1"))
			mob = find_mob("wolf")
			if mob == null:
				mob = find_mob("pheasant")
			stand_near(mob)
			player.select_target(mob)
			player.mp = player.max_mp
			var mp0 := player.mp
			hp_before = mob.hp
			check(player.use_skill("skill1"), "«Удар с разворота» применён")
			check(not mob_ok(mob) or mob.hp < hp_before, "«Удар с разворота» нанёс урон")
			check(player.mp == mp0 - HeroSkills.mp_cost("spin_strike", 1), "потрачено MP")
			check(player.cooldown_frac("skill1") > 0.9, "«Удар с разворота» на перезарядке")
			check(not player.use_skill("skill1"), "повтор на перезарядке не срабатывает")
			step = 3
		3:
			val_before = player.cur_crit()
			check(player.use_skill("skill2"), "«Миг сосредоточения» применён")
			check(player.cur_crit() > val_before + 0.1, "шанс крита: %.2f → %.2f" % [val_before, player.cur_crit()])
			check(player.timed_bonus.has("focus_moment") and player.effects.has("buff:focus_moment"),
				"усиление на время и значок у полоски HP")
			check(not player.use_skill("skill2"), "повтор не срабатывает")
			# Короткое усиление движка заканчивается само
			player.add_timed_bonus("test_buff", 0.5, {"crit": 0.5})
			check(player.cur_crit() > val_before + 0.5, "тестовое усиление действует")
			wait = 60
			step = 4
		4:
			check(not player.timed_bonus.has("test_buff") and not player.effects.has("buff:test_buff"),
				"короткое усиление закончилось, значок снят")
			# Цели нет: игрок в углу карты, звери далеко
			player.global_position = Vector3(68, 0.1, 68)
			player.select_target(null)
			player.skill_cd.clear()
			if Util.nearest(player, "mobs", player.attack_range + 1.0) != null:
				print("Пропуск проверки «Нет цели рядом»: рядом зверь")
			else:
				check(not player.use_skill("skill1"), "без цели умение не срабатывает")
				check(main.hud._msg_label.text == "Нет цели рядом", "сообщение «Нет цели рядом»")
				check(player.cooldown_frac("skill1") == 0.0, "перезарядка не потрачена")
				check(not player.try_attack(), "без цели атака не срабатывает")
			ok_done()
