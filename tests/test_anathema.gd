extends "res://tests/test_base.gd"
## Анатемы — человекоподобные ящеры с костяными клинками (существа Максима): три вида растущей силы (анатема,
## анатема-рубака, вожак анатем), звери мира, не питомцы и не приручаются (карт нет, «Приручить» отказывает);
## модели из файлов со всеми 7 клипами (двуногие, клипы Quaternius UAL): в Idle голова на высоте роста, после клипа
## Death тело лежит на земле; запасная модель из примитивов собирается; физический ближний бой — частые удары
## и низкая защита: урон по анатеме больше, чем по пантере того же уровня; вожак анатем — в пещере (10 ур.);
## спауны анатем — на суше, вне безопасных зон и вне зон летающих рыб.
## На острове только существа Максима: кабанов и каменных стражей в зонах нет, овец в загоне нет; питомцы-кабаны
## и стражи из старого сохранения становятся волками и черепахами (уровень, опыт; JP за недоступные умения — назад).

const KINDS := ["anathema", "anathema_blade", "anathema_chief"]
## Голова в покое выше этого (м над землёй), после смерти — ниже DOWN_Y.
const HEAD_MIN := 1.2
const DOWN_Y := 0.75

var holders: Array[Node3D] = []
var death_wait := 0


func race_class() -> Array:
	return ["dark_elf", "assassin"]


func run_step() -> void:
	var player: Player = main.player
	var hud: HUD = main.hud
	var tm: Taming = main.taming
	match step:
		0:
			_unit_data()
			_unit_world()
			_unit_defense()
			_unit_fallback()
			_build_models()
			wait = 30
			step = 1
		1:
			# Модели из файла: играет Idle (боевая стойка), голова — на высоте роста
			for h in holders:
				var ca := CreatureModels.asset_of(h)
				var id := String(h.get_meta("species"))
				check(ca.anim != null and ca.anim.is_playing() and ca.anim.current_animation == String(ca.clips["idle"]),
					"%s: играет Idle (%s)" % [id, ca.anim.current_animation if ca.anim != null else "нет"])
				var hy := _head_y(h)
				check(hy > HEAD_MIN and hy < 2.4, "%s стоит: голова на высоте %.2f м" % [id, hy])
				death_wait = maxi(death_wait, int(ceil(ca.play_death() * 60.0)) + 20)
			wait = death_wait
			step = 2
		2:
			# После клипа Death анатема лежит на земле
			for h in holders:
				var hy := _head_y(h)
				check(hy < DOWN_Y and hy > -0.05, "%s после смерти лежит: голова на высоте %.2f м" % [h.get_meta("species"), hy])
				h.queue_free()
			holders.clear()
			# Анатема в мире: приручить нельзя, бьёт часто, защита низкая
			var mob := find_mob("anathema")
			check(mob != null, "анатема есть в мире")
			if mob == null:
				return
			check(mob.attack_every < 1.3 and mob.damage_taken > 1.0, "анатема: удар раз в %.1f с, получает урон ×%.2f"
				% [mob.attack_every, mob.damage_taken])
			stand_near(mob, 4.0)
			player._set_target(mob)
			check(hud.target_tame_state == Taming.BADGE_NO and hud.target_card_tier == "",
				"значок анатемы: нельзя приручить (%s)" % hud.target_tame_state)
			tm.cooldown = 0.0
			main._on_action("tame")
			check(tm.marked == null and not mob.tame_marked, "метка на анатему не ставится")
			check(hud._msg_label.text.contains("Этого зверя нельзя приручить"), "сообщение: " + hud._msg_label.text)
			mob.take_damage(mob.hp + 5, player)
			check(mob.is_dead, "анатема побеждена")
			player._set_target(null)
			player.global_position = Vector3(0, 0.1, 2)
			player.hp = player.max_hp
			_unit_old_save()
			ok_done()


## Виды, защита и темп ударов, предметы, приручение, клипы в creatures.json.
func _unit_data() -> void:
	for id in KINDS:
		var d := MobData.get_type(id)
		check(MobData.TYPES.has(id) and not MobData.flying(id), "%s — зверь мира, ходит по земле" % id)
		check(not MobData.tameable(id) and Taming.badge_state(id) == Taming.BADGE_NO, "%s нельзя приручить" % id)
		check(ItemData.card_for(id) == "" and ItemData.soul_card_for(id) == "", "у %s нет карт" % id)
		check(not PetData.SPECIES.has(id), "%s не бывает питомцем" % id)
		check(MobData.defense(id) < 1.0 and MobData.damage_taken(id) > 1.0, "%s: низкая защита (%.2f)" % [id, MobData.defense(id)])
		check(MobData.attack_cd(id) < 1.3, "%s бьёт чаще обычного зверя: раз в %.1f с" % [id, MobData.attack_cd(id)])
		for e in d["loot"]:
			check(not ItemData.get_item(String(e[0])).is_empty(), "добыча %s есть в предметах: %s" % [id, e[0]])
		check(CreatureAsset.has_asset(id), "модель %s из файла есть" % id)
		var inf := CreatureAsset.info_for(id)
		check(float(inf["height"]) > 1.8 and float(inf["height"]) < 2.4 and float(inf["hover"]) == 0.0,
			"%s: рост %.2f м, ходит по земле" % [id, inf["height"]])
		check(float(inf["walk_speed"]) > 0.3 and float(inf["run_speed"]) > float(inf["walk_speed"]),
			"%s: скорости шага %.2f и бега %.2f м/с" % [id, inf["walk_speed"], inf["run_speed"]])
		var clips: Dictionary = inf["clips"]
		for k in ["Idle", "Walk", "Run", "Attack", "Hit", "Death", "Cast"]:
			check(clips.has(k), "у %s в creatures.json есть клип %s" % [id, k])
		check(float(inf["attack_hit_time"]) > 0.0 and float(inf["attack_hit_time"]) < float((clips["Attack"] as Dictionary)["length"]),
			"%s: момент удара %.2f с внутри клипа Attack" % [id, inf["attack_hit_time"]])
	# Растущая сила: уровень и HP; вожак — «Редкий», крепче всех, роняет зеркальную карту
	var a := MobData.get_type("anathema")
	var b := MobData.get_type("anathema_blade")
	var c := MobData.get_type("anathema_chief")
	check(int(a["level"]) < int(b["level"]) and int(b["level"]) < int(c["level"]), "уровни анатем растут")
	check(int(a["hp"]) < int(b["hp"]) and int(b["hp"]) < int(c["hp"]), "HP анатем растёт")
	check(String(c["rarity"]) == "rare" and MobData.rarity_name("anathema_chief") == "Редкий", "вожак — «Редкий»")
	var mirror := false
	for e in c["loot"]:
		mirror = mirror or String(e[0]) == ItemData.MIRROR_CARD
	check(mirror, "вожак роняет зеркальную карту")
	check(Taming.where_to_get(ItemData.MIRROR_CARD).contains("продаётся"), "зеркальная карта продаётся у Кирка")
	for id in ["lizard_scale", "bone_blade", "chief_spike"]:
		check(ItemData.item_type(id) == "trophy", "трофей %s" % id)
		var ic := ItemIcon.make(id, 64.0)
		check(ic.item_id == id, "значок %s создаётся" % id)
		ic.free()
	# Описания карт: кабана и стража среди источников больше нет (их нет на острове)
	var src := Taming.where_to_get("card_wolf")
	check(src == "выпадает из волка", "карта волка — из волка: " + src)
	check(not Taming.lives_in_world("golem") and not Taming.lives_in_world("boar"), "кабан и страж на острове не водятся")
	check(Taming.lives_in_world("anathema_chief"), "вожак анатем водится на острове")


## Спауны: анатемы на суше, вне безопасных зон и зон летающих рыб; вожак — в логове у пещеры; кабанов и стражей
## нет; овец нет; новички (луга 1–2 ур.) — существа Максима и не сильнее прежних кабанов.
func _unit_world() -> void:
	var w := IslandWorld.current
	var fish_zones: Array = []
	var bad_zone: Array = []
	for z in w.cfg.get("mob_zones", []):
		var zone: Dictionary = z
		if String(zone.get("id", "")).begins_with("fish_"):
			fish_zones.append(zone)
		for m in zone.get("mobs", []):
			var mid := String((m as Array)[0])
			if mid == "boar" or mid == "golem" or not CreatureAsset.has_asset(mid):
				bad_zone.append("%s: %s" % [zone.get("id", ""), mid])
	check(bad_zone.is_empty(), "в зонах острова только существа Максима (модели из файлов), лишние: %s" % [bad_zone])
	var counts := {}
	var bad: Array = []
	for s in main._slots:
		var sl: Dictionary = s
		var id := String(sl["type"])
		if id == "boar" or id == "golem":
			bad.append(id)
		if not KINDS.has(id):
			continue
		counts[id] = int(counts.get(id, 0)) + 1
		var p: Vector3 = sl["pos"]
		if w.in_safe_zone(p) or not w.is_walkable(p.x, p.z):
			bad.append("%s в безопасной зоне или в воде: %s" % [id, p])
		for fz in fish_zones:
			var zd: Dictionary = fz
			if Vector2(p.x, p.z).distance_to(IslandWorld.v2(zd["center"])) <= float(zd.get("radius", 10.0)):
				bad.append("%s в зоне рыб %s" % [id, zd.get("id", "")])
		if id == "anathema_chief":
			var cave := IslandWorld.v2(w.poi("cave")["center"])
			check(Vector2(p.x, p.z).distance_to(cave) < 14.0, "вожак анатем — в логове у пещеры: %s" % p)
			check(int(sl["level"]) == 10, "вожак анатем 10 ур.")
	check(bad.is_empty(), "спауны: кабанов и стражей нет, анатемы на суше, вне безопасных зон и зон рыб (%s)" % [bad])
	check(int(counts.get("anathema", 0)) >= 4 and int(counts.get("anathema_blade", 0)) >= 3
		and int(counts.get("anathema_chief", 0)) == 1, "анатем на острове: %s" % [counts])
	var chief := find_mob("anathema_chief")
	check(chief != null and chief.level == 10 and chief.rarity == "rare", "вожак анатем в мире, 10 ур.")
	check(find_mob("boar") == null and find_mob("golem") == null, "кабанов и стражей в мире нет")
	check(Taming.habitat_text("anathema").contains("Западные скалы"), "где водится анатема: " + Taming.habitat_text("anathema"))
	var pois := w.get_node("Pois")
	# Овцы из примитивов не ставятся (в загоне — только овцы-модели Максима из файла, PenSheep)
	var sheep := pois.find_child("Sheep", true, false)
	check(pois.find_child("Bodies", true, false) == null and (sheep == null or sheep is PenSheep), "овец из примитивов нет")
	# Новички: на лугах 1–2 ур. — фазаны и волки, не сильнее прежних кабанов (кабан 2-го ур.: 38 HP, атака 6)
	for id in ["pheasant", "wolf"]:
		var m := Mob.new()
		m.setup(id, -1, Vector3.ZERO, 2)
		check(m.max_hp <= 45 and m.atk <= 7, "%s 2-го ур. по силам новичку: HP %d, атака %d" % [id, m.max_hp, m.atk])
		m.free()


## Низкая защита: одинаковый удар по анатеме проходит сильнее, чем по пантере того же уровня.
func _unit_defense() -> void:
	var base: Vector3 = main.player.global_position + Vector3(0, 0, -30)
	var an := Mob.new()
	an.setup("anathema", -1, base, 6)
	var pa := Mob.new()
	pa.setup("panther", -1, base + Vector3(4, 0, 0), 6)
	main.add_child(an)
	main.add_child(pa)
	var hp_a := an.hp
	var hp_p := pa.hp
	an.take_damage(20, null)
	pa.take_damage(20, null)
	var da := hp_a - an.hp
	var dp := hp_p - pa.hp
	check(dp == 20 and da > dp, "удар 20: по анатеме %d, по пантере %d" % [da, dp])
	check(an.attack_every < pa.attack_every, "анатема бьёт чаще пантеры: %.1f < %.1f с" % [an.attack_every, pa.attack_every])
	an.consume()
	pa.consume()


## Запасная модель из примитивов (файлы выключены) собирается, рост — по размерам вида.
func _unit_fallback() -> void:
	CreatureAsset.use_assets = false
	for id in KINDS:
		var n := Node3D.new()
		main.add_child(n)
		var d := MobData.get_type(id)
		var m := CreatureModels.build(n, id, d["color"], 1.0)
		check(m != null and CreatureModels.asset_of(n) == null, "запасная модель %s собрана" % id)
		check(absf(CreatureModels.height(id, 1.0) - float(CreatureAsset.info_for(id)["height"])) < 0.01,
			"рост запасной %s по размерам вида" % id)
		CreatureModels.animate(n, id, 0.5, 1.0)
		n.free()
	CreatureAsset.use_assets = true


## Модели из файлов в ряд у игрока (все 7 клипов).
func _build_models() -> void:
	var base: Vector3 = main.player.global_position + Vector3(0, 0, -6)
	var x := -3.0
	for id in KINDS:
		var h := Node3D.new()
		h.set_meta("species", id)
		main.add_child(h)
		h.global_position = Vector3(base.x + x, base.y, base.z)
		x += 3.0
		var d := MobData.get_type(id)
		CreatureModels.build(h, id, d["color"], 1.0)
		var ca := CreatureModels.asset_of(h)
		check(ca != null and ca.skeleton != null, "модель %s из файла со скелетом" % id)
		if ca == null:
			continue
		for k in CreatureAsset.CLIPS:
			check(ca.clips.has(k), "у %s есть клип %s" % [id, k])
		holders.append(h)


## Старое сохранение с питомцами-кабаном и стражем: волк и черепаха, уровень и опыт те же, JP за умения,
## которых у нового вида нет, возвращены; сообщение игроку.
func _unit_old_save() -> void:
	var golem_skills := {"hardening": 1, "ground_roar": 2}
	var refund := 0
	for k in golem_skills:
		if not PetSkills.has_skill("turtle", String(k)):
			refund += int(golem_skills[k]) * int(PetSkills.get_skill(String(k))["jp"])
	check(refund > 0, "у черепахи нет «Гула земли» — JP вернутся: %d" % refund)
	game.from_dict({
		"name": "Старый", "race": "dark_elf", "class": "assassin", "level": 5, "gold": 10,
		"pets": [
			{"species": "boar", "name": PetData.stage_name("boar", 7), "level": 7, "xp": 33, "jp": 4,
				"skills": {"inner_fire": 2, "fierce_rush": 1}},
			{"species": "golem", "name": "Глыба", "level": 12, "xp": 5, "jp": 1, "skills": golem_skills,
				"toggles": {"ground_roar": true}},
		],
		"active_pet": 1,
	})
	check(game.pets.size() == 2, "оба питомца на месте")
	var p0: Dictionary = game.pets[0]
	var p1: Dictionary = game.pets[1]
	check(String(p0["species"]) == "wolf" and int(p0["level"]) == 7 and int(p0["xp"]) == 33,
		"кабан стал волком 7 ур., опыт 33: %s" % [p0])
	check(String(p0["name"]) == PetData.stage_name("wolf", 7), "имя стадии кабана → имя стадии волка: %s" % p0["name"])
	check(int(p0["jp"]) == 4 and PetSkills.skill_level(p0, "fierce_rush") == 1, "умения кабана есть у волка — JP не меняются")
	check(String(p1["species"]) == "turtle" and int(p1["level"]) == 12 and int(p1["xp"]) == 5 and String(p1["name"]) == "Глыба",
		"страж стал черепахой 12 ур., своё имя сохранено: %s" % [p1])
	check(int(p1["jp"]) == 1 + refund, "JP за «Гул земли» возвращены: %d" % int(p1["jp"]))
	check(PetSkills.skill_level(p1, "hardening") == 1 and PetSkills.skill_level(p1, "ground_roar") == 0
		and not PetSkills.toggle_on(p1, "ground_roar"), "общие умения остались, чужих нет")
	check(game.active_pet == 1, "активный питомец сохранён")
	check(game.load_note.contains("питомцы-кабаны стали волками"), "сообщение игроку: " + game.load_note)
	game.load_note = ""


## Высота кости головы модели из файла над узлом h (м).
func _head_y(h: Node3D) -> float:
	var ca := CreatureModels.asset_of(h)
	if ca == null or ca.skeleton == null:
		return -1.0
	var hb := ca.skeleton.find_bone(String((ca.info["bones"] as Dictionary).get("head", "Head")))
	if hb < 0:
		return -1.0
	var p := ca.skeleton.global_transform * ca.skeleton.get_bone_global_pose(hb).origin
	return p.y - h.global_position.y
