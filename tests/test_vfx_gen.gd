extends "res://tests/test_base.gd"
## Генератор эффектов (docs/vfx/VFX_ARCHITECTURE.md): таблица vfx/skill_vfx.json совпадает с правилами (VfxRules),
## у каждого активного умения героя и питомца есть эффект, каждый архетип строится на трёх качествах (на низком
## частиц меньше) и сам удаляется, в бою — каст, выпуск, снаряд стихии, попадание, усиление героя, умение питомца,
## проклятие и удар капитана; выключатель SkillVfx.enabled — прежние эффекты; лимит одновременных эффектов.

var counts := [0, 0, 0]
var mob: Mob = null
var cast_fx: Node3D = null
var built0 := {}


func race_class() -> Array:
	return ["light_elf", "wizard"]


func hero_level() -> int:
	return 40


func run_step() -> void:
	match step:
		0:
			if not bool(main.get("_started")):
				return
			SkillVfx.reread()
			_table()
			_archetypes()
			wait = 3
			step = 1
		1:
			check(counts[0] < counts[2] and counts[1] <= counts[2],
				"частиц на качествах 0/1/2: %d / %d / %d" % counts)
			_combat()
			wait = 90
			step = 2
		2:
			_after_flight()
			_pet_and_boss()
			_switch_and_limit()
			wait = 60 * 14
			step = 3
		3:
			var left := main.get_tree().get_nodes_in_group("vfx").size()
			check(left == 0, "все эффекты удалились сами (осталось %d)" % left)
			check(main.get_tree().get_nodes_in_group("vfx_loop").size() == 0, "постоянных частиц не осталось")
			check(VfxKit.lights_alive == 0, "краткие огни погасли (%d)" % VfxKit.lights_alive)
			ok_done()


func _table() -> void:
	var gen := VfxGenerate.build_table()
	var file: Variant = JSON.parse_string(FileAccess.get_file_as_string(SkillVfx.PATH))
	check(file is Dictionary, "vfx/skill_vfx.json читается")
	if file is Dictionary:
		var same := JSON.stringify(gen, "", true) == JSON.stringify(file, "", true)
		check(same, "vfx/skill_vfx.json совпадает с правилами (запустить res://tools/vfx_generate.tscn)")
	var t := SkillVfx.table()
	var hero: Dictionary = t.get("hero", {})
	var missing: Array = []
	for id in JobSkills.SKILLS.keys() + HeroSkills.SKILLS.keys():
		var sk := HeroSkills.get_skill(String(id))
		if String(sk.get("kind", "")) == "active" and not hero.has(String(id)):
			missing.append(id)
	check(missing.is_empty(), "у всех активных умений героя есть эффект (нет у %s)" % [missing])
	var pets: Dictionary = t.get("pet", {})
	var pm: Array = []
	for sp in PetData.SPECIES:
		for sid in PetSkills.list_for(String(sp)):
			if String(PetSkills.get_skill(String(sid)).get("kind", "")) == "active" and not pets.has("%s:%s" % [sp, sid]):
				pm.append("%s:%s" % [sp, sid])
	check(pm.is_empty(), "у всех активных умений питомцев есть эффект (нет у %s)" % [pm])
	check((t.get("mob", {}) as Dictionary).has("dg_captain:slam") and (t["mob"] as Dictionary).has("dg_captain:curse:stun"),
		"у капитана — удар и проклятия")
	# Ручная правка поверх сгенерированного
	check(String(SkillVfx.entry("pet", "wolf:chilling_howl").get("el", "")) == "ice", "правка: «Леденящий вой» — лёд")
	# Разнообразие: архетипов в таблице много, стихии разные
	var used := {}
	var els := {}
	for g in ["hero", "pet", "mob"]:
		for k in (t[g] as Dictionary):
			var e: Dictionary = t[g][k]
			els[String(e.get("el", ""))] = true
			for ph in e:
				if e[ph] is Dictionary and (e[ph] as Dictionary).has("arch"):
					used[String(e[ph]["arch"])] = true
	print("VFX: архетипов в таблице %d из %d, стихий %d" % [used.size(), VfxArchetypes.LIST.size(), els.size()])
	check(used.size() >= 30 and els.size() >= 12, "эффекты разнообразны: архетипов %d, стихий %d" % [used.size(), els.size()])
	# Правила: стихия по названию
	check(VfxRules.element_of({"name": "Огненная искра"}) == "fire", "«Огненная искра» — огонь")
	check(VfxRules.element_of({"name": "Костяная ярость", "desc": "Два яростных удара клинком подряд."}) != "poison",
		"«подряд» — не яд")


func _archetypes() -> void:
	var p: Player = main.player
	var at := p.global_position + Vector3(0, 1.0, 6.0)
	var o := {"ground": p.global_position + Vector3(0, 0, 6.0), "from": p.global_position + Vector3(0, 1.2, 0),
		"dir": Vector3.FORWARD, "height": 1.7}
	for q in 3:
		for a in VfxArchetypes.LIST:
			if a == "orb":
				continue
			o["q"] = q
			var r := VfxArchetypes.build({"arch": a, "el": "fire", "dur": 0.6, "seed": 7}, main, at, o)
			check(r != null, "архетип %s строится (качество %d)" % [a, q])
			if r == null:
				continue
			for n in r.find_children("*", "CPUParticles3D", true, false):
				counts[q] += (n as CPUParticles3D).amount
			if q == 2:
				var layers := r.find_children("*", "CPUParticles3D", true, false).size() \
					+ r.find_children("*", "MeshInstance3D", true, false).size()
				check(layers >= 3, "архетип %s многослойный (%d слоёв)" % [a, layers])
			# Убрать сразу: иначе лимит одновременных эффектов не даст построить эффекты боя
			r.remove_from_group("vfx")
			r.queue_free()
	# Каждая стихия снаряда одевается
	for el in VfxArchetypes.PALETTES:
		var n3 := Node3D.new()
		main.add_child(n3)
		VfxArchetypes.dress_projectile(n3, String(el), 1.0, 1)
		check(n3.get_child_count() >= 2, "снаряд стихии %s собран" % el)
		n3.queue_free()


func _combat() -> void:
	var p: Player = main.player
	AdminPanel.god = true
	built0 = SkillVfx.built.duplicate()
	mob = main.spawn_mob("wolf", 40, p.global_position + Vector3(0, 0, 6))
	mob.max_hp = 10000000
	mob.hp = mob.max_hp
	p.current_target = mob
	AdminPanel.learn_all(main)
	p.mp = p.max_mp
	# Снаряд стихии: «Световой толчок» (каст → выпуск → шар света → попадание)
	var t0: int = SkillVfx.built.get("cast", 0)
	check(p.use_skill("light_pulse"), "«Световой толчок» начат")
	cast_fx = p._cast_fx
	check(cast_fx != null and is_instance_valid(cast_fx), "эффект каста на герое")
	check(int(SkillVfx.built.get("cast", 0)) == t0 + 1, "каст построен")
	p._tick_cast(p.cast_total + 0.01)
	check(p._cast_fx == null, "после каста эффект каста снят")
	var proj: Projectile = null
	for n in main.get_tree().get_nodes_in_group("projectiles"):
		if (n as Projectile).style.get("key", "") == "light_pulse":
			proj = n
	check(proj != null and String(proj.style.get("el", "")) == "light", "снаряд «Светового толчка» — свет")
	check(int(SkillVfx.built.get("release", 0)) > int(built0.get("release", 0)), "выпуск силы на герое")
	# Лечение — эффект на герое
	p.hp = p.max_hp / 2
	var b0: int = SkillVfx.built.get("buff", 0)
	check(use_now(p, "quick_heal"), "«Скорое исцеление»")
	check(int(SkillVfx.built.get("buff", 0)) > b0, "лечение — эффект усиления на герое")
	# Площадь: «Сияющий круг»
	var a0: int = SkillVfx.built.get("area", 0)
	p.skill_cd.clear()
	check(use_now(p, "radiant_circle"), "«Сияющий круг»")
	check(int(SkillVfx.built.get("area", 0)) > a0, "«Сияющий круг» — эффект по площади")


func _after_flight() -> void:
	check(int(SkillVfx.built.get("impact", 0)) > int(built0.get("impact", 0)), "снаряд долетел — эффект попадания")
	check(cast_fx == null or not is_instance_valid(cast_fx) or cast_fx.is_queued_for_deletion() or cast_fx.scale.x < 0.5,
		"эффект каста погас")


func _pet_and_boss() -> void:
	var p: Player = main.player
	var i: int = AdminPanel.add_pet(main, "wolf", 60, 1)
	var pet: Pet = main.pets.active_pet
	check(pet != null, "волк призван")
	if pet != null:
		pet.skills["rending_bite"] = 3
		var i0: int = SkillVfx.built.get("impact", 0)
		pet._apply_skill("rending_bite", mob)
		check(int(SkillVfx.built.get("impact", 0)) > i0, "умение волка — эффект попадания")
	var _u := i
	var cap: Mob = main.spawn_mob("dg_captain", -1, p.global_position + Vector3(4, 0, 0))
	var c0: int = SkillVfx.built.get("buff", 0)
	cap.curse_now(p)
	check(int(SkillVfx.built.get("buff", 0)) > c0, "проклятие капитана — изумрудный эффект на герое")
	var s0: int = SkillVfx.built.get("area", 0)
	cap._slam()
	check(int(SkillVfx.built.get("area", 0)) > s0, "удар капитана — ритуальный круг")
	cap.consume()


func _switch_and_limit() -> void:
	var p: Player = main.player
	# Выключатель: прежние эффекты, новых нет
	SkillVfx.enabled = false
	var b0: int = SkillVfx.built.get("buff", 0)
	check(not SkillVfx.buff("hero", "quick_heal", p), "выключено — нового эффекта нет (место вызова покажет прежний)")
	check(SkillVfx.proj_style("hero", "light_pulse").is_empty(), "выключено — снаряд прежний")
	SkillVfx.enabled = true
	check(int(SkillVfx.built.get("buff", 0)) == b0, "выключено — ничего не построено")
	# Лимит: не больше MAX_ACTIVE × 1.5 эффектов сразу
	var made := 0
	for k in 120:
		if SkillVfx.play("hero", "light_pulse", "impact", main, p.global_position + Vector3(0, 1, 3)) != null:
			made += 1
	var now := main.get_tree().get_nodes_in_group("vfx").size()
	check(now <= int(SkillVfx.MAX_ACTIVE * 1.5) + 2, "эффектов сразу не больше предела (%d, построено %d из 120)" % [now, made])
	check(VfxKit.lights_alive <= VfxKit.MAX_LIGHTS, "кратких огней не больше %d" % VfxKit.MAX_LIGHTS)
	if mob != null and is_instance_valid(mob):
		mob.consume()
