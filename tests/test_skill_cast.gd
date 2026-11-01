extends "res://tests/test_base.gd"
## Время каста умений героя (Player: _begin_cast / _tick_cast / _finish_cast, HeroSkills.cast_time, поле cast):
## данные (правило вики → наше время, строки карточки), каст «Громового удара» Неофита идёт заданное время с учётом
## скорости каста (посох), эффект — только в конце, MP — тоже в конце, перезарядка — после каста; во время каста
## другое умение и обычная атака не идут, повторное нажатие ничего не меняет; полоса каста HUD видна (название,
## время) и исчезает; петля каста модели (Mq_Cast_Hold) играет и снимается; ходьба джойстиком прерывает каст (MP цел,
## перезарядки нет); цель ушла дальше дальности — прерывание; урон каст не сбивает; без MP каст не начинается;
## мгновенное умение («Танец теней») — как раньше; лучник (Воин) — петля прицеливания Mq_Bow_Aim_Hold, стрела
## вылетает в конце каста.

var mob: Mob = null
var t0 := 0
var hp0 := 0
var mp0 := 0
var expect := 0.0
var base := Vector3.ZERO
var val_shots := 0


func race_class() -> Array:
	return ["dark_elf", "neophyte"]


func hero_level() -> int:
	return 40


func run_step() -> void:
	var p: Player = main.player
	var hud: HUD = main.hud
	log_messages()
	if wait > 0:
		wait -= 1
		return
	match step:
		0:
			_check_data()
			learn_skills(["mind_ward", "evasion_expert", "dusk_veil", "deep_evasion", "zap", "thunderclap"])
			check(p.assign_slot("thunderclap", 0) and p.assign_slot("zap", 1) and p.assign_slot("deep_evasion", 2),
				"умения на кнопках")
			check(p.weapon_kind == "staff_2h" and p.cast_speed > 0.0, "двуручный посох: скорость каста +%d%%"
				% roundi(p.cast_speed * 100.0))
			expect = 1.2 / (1.0 + p.cast_speed)
			check(absf(p.skill_cast_time("thunderclap", 1) - expect) < 0.001,
				"«Громовой удар»: каст 1.2 с / (1 + скорость каста) = %.2f с" % p.skill_cast_time("thunderclap", 1))
			var ph := find_mob("pheasant")
			if ph == null:
				fail("нет фазана — места для боя вне деревни")
				return
			base = ph.global_position
			_place_player(base)
			mob = main.spawn_mob("turtle", 40, _ground(base + Vector3(0, 0, -8.0)))
			step = 1
			wait = 2
		1:
			_calm()
			p.select_target(mob)
			p.mp = p.max_mp
			mp0 = p.mp
			hp0 = mob.hp
			check(p.casting == "", "каста нет")
			check(p.use_skill("skill1"), "«Громовой удар»: каст начался")
			check(p.casting == "thunderclap" and p.cast_target == mob, "каст идёт, цель запомнена")
			check(absf(p.cast_total - expect) < 0.001, "длительность каста %.2f с" % p.cast_total)
			check(p.mp == mp0, "MP в начале каста не списан")
			check(mob.hp == hp0, "урона в начале каста нет")
			check(float(p.skill_cd.get("thunderclap", 0.0)) == 0.0, "перезарядки во время каста нет")
			check(p._model.cast_loop_clip().to_lower() == "mq_cast_hold", "петля каста модели: %s" % p._model.cast_loop_clip())
			# Во время каста: другое умение — нельзя, то же — ничего, обычная атака не идёт
			check(not p.use_skill("skill2") and p.casting == "thunderclap" and hud._msg_label.text.contains("Идёт каст"),
				"другое умение во время каста не применяется: %s" % hud._msg_label.text)
			check(not p.use_skill("skill1") and p.casting == "thunderclap", "повторное нажатие — ничего")
			p.attack_cd = 0.0
			check(not p.try_attack(), "обычная атака во время каста не идёт")
			t0 = frame
			step = 2
		2:
			if p.casting != "":
				if frame - t0 == 10:
					check(hud.is_cast_visible() and hud._cast_label.text.contains("Громовой удар"),
						"полоса каста видна: «%s»" % hud._cast_label.text)
					var r := hud.cast_rect()
					check(Rect2(Vector2.ZERO, hud._view).encloses(r), "полоса каста на экране: %s" % r)
					check(hud._cast_bar.value > 0.05 and hud._cast_bar.value < 0.4, "полоса заполняется: %.2f" % hud._cast_bar.value)
					check(mob.hp == hp0 and p.mp == mp0, "на середине каста урона нет, MP цел")
					# Урон каст не сбивает
					p.take_damage(3, null)
					check(p.casting == "thunderclap", "урон каст не сбивает")
				if frame - t0 > 60 * 4:
					fail("каст не закончился за 4 с")
				return
			var sec := float(frame - t0) / 60.0
			check(absf(sec - expect) <= 4.0 / 60.0, "каст длился %.2f с (ожидалось %.2f с)" % [sec, expect])
			check(p.cast_ok, "в конце каста умение сработало")
			check(not mob_ok(mob) or mob.hp < hp0, "урон — в конце каста: %d → %d" % [hp0, mob.hp if mob_ok(mob) else 0])
			check(p.mp == mp0 - HeroSkills.mp_cost("thunderclap", 1), "MP списан в конце: %d → %d" % [mp0, p.mp])
			check(float(p.skill_cd.get("thunderclap", 0.0)) > 0.0, "перезарядка — после каста")
			check(p._model.cast_loop_clip() == "", "петля каста снята")
			step = 3
		3:
			check(not hud.is_cast_visible(), "полоса каста исчезла")
			# Ходьба прерывает каст: MP цел, перезарядки нет
			p.skill_cd.erase("thunderclap")
			_calm()
			p.mp = p.max_mp
			mp0 = p.mp
			check(p.use_skill("skill1") and p.casting == "thunderclap", "каст снова")
			var view: Vector2 = hud._view
			var start := Vector2(view.x * 0.2, view.y * 0.7)
			touch(true, 0, start)
			var d := InputEventScreenDrag.new()
			d.index = 0
			d.position = start + Vector2(80, 0)
			hud._input(d)
			t0 = frame
			step = 4
		4:
			if p.casting != "" and frame - t0 < 20:
				return
			touch(false, 0, Vector2.ZERO)
			check(p.casting == "", "джойстик прервал каст")
			check(hud._msg_label.text.contains("каст прерван"), "сообщение: %s" % hud._msg_label.text)
			check(p.mp == mp0 and float(p.skill_cd.get("thunderclap", 0.0)) == 0.0, "прерван — MP цел, перезарядки нет")
			check(p._model.cast_loop_clip() == "", "петля каста снята после прерывания")
			wait = 10
			step = 5
		5:
			check(not hud.is_cast_visible(), "полоса каста исчезла после прерывания")
			# Цель ушла дальше дальности умения — прерывание
			_place_player(base)
			if not mob_ok(mob):
				mob = main.spawn_mob("turtle", 40, _ground(base + Vector3(0, 0, -8.0)))
			mob.global_position = _ground(base + Vector3(0, 0, -8.0))
			_calm()
			p.select_target(mob)
			p.mp = p.max_mp
			mp0 = p.mp
			check(p.use_skill("skill1") and p.casting == "thunderclap", "каст по цели в 8 м")
			mob.global_position = _ground(base + Vector3(0, 0, -30.0))
			t0 = frame
			step = 6
		6:
			if p.casting != "" and frame - t0 < 10:
				return
			check(p.casting == "" and hud._msg_label.text.contains("далеко"), "цель ушла — каст прерван: %s" % hud._msg_label.text)
			check(p.mp == mp0, "MP цел")
			# Скорость каста сокращает каст: вдвое быстрее — вдвое короче
			mob.global_position = _ground(base + Vector3(0, 0, -8.0))
			_calm()
			p.cast_speed = 1.0
			check(p.use_skill("skill1") and absf(p.cast_total - 0.6) < 0.001, "скорость каста +100%%: каст %.2f с" % p.cast_total)
			p.cancel_cast("")
			p.recalc_stats()
			# Без MP каст не начинается
			p.mp = 0
			check(not p.use_skill("skill1") and p.casting == "", "без MP каст не начинается")
			p.mp = p.max_mp
			# Мгновенное умение — как раньше: сразу действует, каста нет
			check(p.use_skill("skill3") and p.casting == "" and p.shade_time > 0.0, "«Танец теней» — мгновенно")
			check(float(p.skill_cd.get("deep_evasion", 0.0)) > 0.0, "мгновенное — сразу на перезарядке")
			# «Разряд» (0.5 с) — через use_now (каст до конца) бьёт сразу
			p.skill_cd.erase("zap")
			hp0 = mob.hp
			check(use_now(p, "skill2") and (not mob_ok(mob) or mob.hp < hp0), "«Разряд» после каста бьёт")
			step = 7
		7:
			# Лучник: петля прицеливания, стрела — в конце каста
			game.race_id = "human"
			become_job("warrior")
			if game.inventory.count("weapon_bow_r1") < 1:
				game.inventory.add("weapon_bow_r1", 1)
			check(p.equip("weapon_bow_r1") == "" and p.weapon_kind == "bow", "Воин с луком")
			learn_skills(["bow_mastery", "sticky_arrow"])
			p.assign_slot("sticky_arrow", 0)
			_place_player(base)
			if not mob_ok(mob):
				mob = main.spawn_mob("turtle", 40, _ground(base + Vector3(0, 0, -8.0)))
			mob.global_position = _ground(base + Vector3(0, 0, -8.0))
			_calm()
			p.select_target(mob)
			p.mp = p.max_mp
			wait = 2
			step = 8
		8:
			var shots0 := get_tree().get_nodes_in_group("projectiles").size()
			check(p.use_skill("skill1") and p.casting == "sticky_arrow", "«Вязкая стрела»: прицеливание (каст %.2f с)" % p.cast_total)
			check(p._model.cast_loop_clip().to_lower() == "mq_bow_aim_hold", "петля прицеливания из лука: %s"
				% p._model.cast_loop_clip())
			check(get_tree().get_nodes_in_group("projectiles").size() == shots0, "стрела не вылетела в начале каста")
			t0 = frame
			val_shots = shots0
			step = 9
		9:
			if p.casting != "":
				if frame - t0 > 60 * 3:
					fail("прицеливание не закончилось")
				return
			check(p.cast_ok and get_tree().get_nodes_in_group("projectiles").size() > val_shots, "стрела вылетела в конце каста")
			ok_done()


## Данные: правило переноса времени каста вики, поле cast у умений, строки карточки.
func _check_data() -> void:
	check(HeroSkills.cast_from_wiki(0.0) == 0.0 and is_equal_approx(HeroSkills.cast_from_wiki(0.5), 0.5)
		and is_equal_approx(HeroSkills.cast_from_wiki(2.0), 1.2) and is_equal_approx(HeroSkills.cast_from_wiki(4.0), 2.4)
		and is_equal_approx(HeroSkills.cast_from_wiki(9.0), HeroSkills.CAST_MAX),
		"вики → наше: 0 → 0, 0.5 → 0.5, 2 → 1.2, 4 → 2.4, 9 → %.1f" % HeroSkills.CAST_MAX)
	var with_cast := 0
	var bad: PackedStringArray = []
	var ids: Array = HeroSkills.SKILLS.keys() + JobSkills.SKILLS.keys()
	for id in ids:
		var sid := String(id)
		var c := HeroSkills.cast_time(sid, 1)
		if HeroSkills.kind(sid) != "active":
			if c > 0.0:
				bad.append(sid)
			continue
		if c > 0.0:
			with_cast += 1
			if c < HeroSkills.CAST_MIN - 0.001 or c > HeroSkills.CAST_MAX + 0.001:
				bad.append(sid)
	check(bad.is_empty(), "время каста: только у активных, %.1f–%.1f с: %s" % [HeroSkills.CAST_MIN, HeroSkills.CAST_MAX, bad])
	check(with_cast >= 50, "умений с кастом: %d" % with_cast)
	# По смыслу: удары оружием и рывки — мгновенно, заклинания — с кастом, воскрешение — долго
	for sid in ["backstab", "shadow_step", "dark_strike", "spin_strike", "shield_rush", "challenge"]:
		check(HeroSkills.cast_time(sid, 1) == 0.0, "«%s» — мгновенно" % String(HeroSkills.get_skill(sid)["name"]))
	for sid in ["fire_spark", "healing_touch", "fire_tornado", "dual_shot", "sticky_arrow"]:
		check(HeroSkills.cast_time(sid, 1) >= 0.5, "«%s» — с кастом %.1f с" % [String(HeroSkills.get_skill(sid)["name"]),
			HeroSkills.cast_time(sid, 1)])
	check(HeroSkills.cast_time("soul_return", 1) > HeroSkills.cast_time("quick_heal", 1),
		"воскрешение кастуется дольше скорого лечения")
	check(HeroSkills.cast_text("thunderclap", 1) == "Каст: 1.2 с", "карточка: %s" % HeroSkills.cast_text("thunderclap", 1))
	check(HeroSkills.cast_text("thunderclap", 1, 0.2) == "Каст: 1.2 с (сейчас 1 с)", "карточка со скоростью каста: %s"
		% HeroSkills.cast_text("thunderclap", 1, 0.2))
	check(HeroSkills.cast_text("dark_strike", 1) == "Мгновенно" and HeroSkills.cast_text("mind_ward", 1) == "",
		"карточка: мгновенное — «Мгновенно», пассивное — без строки")


func _ground(v: Vector3) -> Vector3:
	if IslandWorld.current != null:
		return Vector3(v.x, IslandWorld.current.height_at(v.x, v.z) + 0.1, v.z)
	return v


func _place_player(at: Vector3) -> void:
	var p: Player = main.player
	p.global_position = _ground(at)
	p.velocity = Vector3.ZERO
	p.hp = p.max_hp


## Звери стоят (оглушены): цель не уходит из дальности сама.
func _calm() -> void:
	for n in get_tree().get_nodes_in_group("mobs"):
		var m := n as Mob
		if m != null and not m.is_dead:
			m.stun(5.0)
