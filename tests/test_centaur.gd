extends "res://tests/test_base.gd"
## Кентавр — «Редкий» копейщик (модели Максима, 3 стадии): вид и редкость, фиолетовая карта (35%), карта только
## выпадает из кентавра (Кирк её не продаёт), трофеи; модели 1/2/3 стадии из файлов с 7 клипами и костями копья
## и торса; статы питомца по таблице вики (Kentauros) и сила редкости, умения кентавра (18, тексты, ослабление
## зверя); дикий кентавр сильнее волка того же уровня; спауны на суше вне безопасных зон и чужих зон; приручение
## картой кентавра → карта с душой → формирование и призыв; эволюция меняет модель на centaur_2 и centaur_3.

const MODELS := ["centaur", "centaur_2", "centaur_3"]

var mob: Mob = null


func race_class() -> Array:
	return ["dark_elf", "assassin"]


func run_step() -> void:
	var player: Player = main.player
	var tm: Taming = main.taming
	var inv: Inventory = game.inventory
	var hud: HUD = main.hud
	var pm: PetManager = main.pets
	match step:
		0:
			_unit_kind()
			_unit_models()
			_unit_pet_data()
			_unit_skills()
			_unit_wild()
			_unit_world()
			step = 1
		1:
			# Приручение картой кентавра: зелёный значок, фиолетовый тир, шанс 35%, победа — карта с душой
			mob = find_mob("centaur")
			check(mob != null, "кентавр есть в мире")
			if mob == null:
				return
			var want := CreatureAsset.model_for("centaur", MobStats.stage_for("centaur", mob.level))
			check(mob._asset != null and mob._asset.species == want, "дикий кентавр %d ур. — модель %s" % [mob.level, want])
			check(mob.rarity == "rare" and mob.level >= 13 and mob.level <= 27, "дикий кентавр «Редкий», ур. %d" % mob.level)
			# Дикий кентавр (13+ ур.) убивает героя 1-го ур. за пару ударов — на время приручения «бессмертие»
			AdminPanel.god = true
			stand_near(mob, 3.0)
			player._set_target(mob)
			check(hud.target_tame_state == Taming.BADGE_NEED_CARD and hud.target_card_tier == "special",
				"значок кентавра: нужна карта, фиолетовый тир (%s, %s)" % [hud.target_tame_state, hud.target_card_tier])
			tm.cooldown = 0.0
			main._on_action("tame")
			check(tm.marked == null, "без карты кентавра метка не ставится")
			var msg: String = hud._msg_label.text
			check(msg.contains("Кентавр") and msg.contains("выпадает из кентавра"), "подсказка, где взять карту: " + msg)
			inv.add("card_centaur", 1)
			# Значок цели HUD обновляет в своём кадре — проверяем на следующем шаге
			wait = 2
			step = 10
		10:
			if not mob_ok(mob):
				fail("кентавр пропал до приручения")
				return
			stand_near(mob, 3.0)
			check(hud.target_tame_state == Taming.BADGE_READY, "значок кентавра зелёный: карта в сумке")
			tm.cooldown = 0.0
			main._on_action("tame")
			check(tm.marked == mob and mob.tame_marked, "метка на кентавре")
			check(hud._msg_label.text.contains("шанс 35%"), "шанс фиолетовой карты: " + hud._msg_label.text)
			tm.force_roll = 0.0
			mob.take_damage(mob.hp + 5, player)
			tm.force_roll = -1.0
			AdminPanel.god = false
			check(not inv.has("card_centaur") and inv.count("card_centaur_soul") == 1, "карта кентавра стала картой с душой")
			player.global_position = Vector3(0, 0.1, 2)
			wait = 2
			step = 2
		2:
			# Формирование: кентавр 1-го уровня в коллекции и сразу призван
			check(tm.form("card_centaur_soul"), "кентавр сформирован")
			check(game.pets.size() == 1 and String(game.pets[0]["species"]) == "centaur", "в коллекции кентавр")
			check(String(game.pets[0]["name"]) == PetData.stage_name("centaur", 1), "имя — 1-я стадия: %s" % game.pets[0]["name"])
			check(game.active_pet == 0, "кентавр призван")
			wait = 5
			step = 3
		3:
			var pet: Pet = pm.active_pet
			check(pet != null and pet.species == "centaur" and pet.stage == 0, "призван кентавр 1-й стадии")
			if pet == null:
				return
			check(pet.model_id == "centaur" and pet._asset != null and pet._asset.species == "centaur",
				"1-я стадия: модель centaur (%s)" % pet.model_id)
			check(pet.max_hp > 0 and pet.atk > 0, "у питомца-кентавра есть HP и атака (%d, %d)" % [pet.max_hp, pet.atk])
			# Изучение умения за JP (уровень 3 нужен «Двойному выпаду»)
			while pet.level < 3:
				pet.gain_xp(PetData.xp_to_next(pet.level) - pet.xp)
			var rec: Dictionary = game.pets[0]
			check(PetSkills.learn(rec, "spear_flurry"), "«Двойной выпад» изучен: %s" % PetSkills.learn_block(rec, "spear_flurry"))
			check(PetSkills.learn_block(rec, "piercing_strike") != "", "«Пронзающий удар» ещё закрыт (ур. 6)")
			# Эволюция: 15 ур. — centaur_2, 30 ур. — centaur_3
			while pet.level < 15:
				pet.gain_xp(PetData.xp_to_next(pet.level) - pet.xp)
			check(pet.stage == 1 and pet.model_id == "centaur_2" and pet._asset != null and pet._asset.species == "centaur_2",
				"2-я стадия: модель centaur_2 (%s)" % pet.model_id)
			wait = 3
			step = 4
		4:
			var pet: Pet = pm.active_pet
			while pet.level < 30:
				pet.gain_xp(PetData.xp_to_next(pet.level) - pet.xp)
			check(pet.stage == 2 and pet.model_id == "centaur_3" and pet._asset != null and pet._asset.species == "centaur_3",
				"3-я стадия: модель centaur_3 (%s)" % pet.model_id)
			# Старые модели освобождаются отложенно (queue_free) — считаем через несколько кадров
			wait = 5
			step = 5
		5:
			var pet: Pet = pm.active_pet
			var models := 0
			for c in pet.get_children():
				if c is Node3D and CreatureModels.asset_of(c as Node3D) != null:
					models += 1
			check(models == 1, "после эволюций у питомца одна модель: %d" % models)
			# Окно существа: превью — модель 3-й стадии, редкость «Редкий»
			main._on_action("creature_window")
			var cw: CreatureWindow = pm.creature
			check(cw.is_open(), "окно существа кентавра открыто")
			var ca := CreatureModels.asset_of(cw._holder)
			check(ca != null and ca.species == "centaur_3", "превью — centaur_3 (%s)" % (ca.species if ca != null else "нет"))
			check(_window_text().contains("Редкий"), "в окне существа редкость «Редкий»")
			main.hud.close_window()
			ok_done()


## Вид, редкость, карта, добыча.
func _unit_kind() -> void:
	check(MobData.TYPES.has("centaur") and PetData.SPECIES.has("centaur"), "кентавр — зверь мира и вид питомца")
	check(String(MobData.get_type("centaur")["rarity"]) == "rare" and MobData.rarity_name("centaur") == "Редкий",
		"кентавр — «Редкий»")
	check(MobData.rarity_tier("centaur") > MobData.rarity_tier("wolf") and MobData.rarity_tier("wolf") > MobData.rarity_tier("panther"),
		"ранг: кентавр > волк > пантера")
	check(is_equal_approx(MobData.power("centaur"), 1.3), "сила редкости кентавра ×1.3")
	check(MobData.tameable("centaur"), "кентавра можно приручить")
	check(MobData.card_tier("centaur") == "special" and ItemData.card_tier("card_centaur") == "special",
		"карта кентавра — фиолетовая (редкая)")
	check(is_equal_approx(Taming.CHANCE["special"], 0.35), "шанс фиолетовой карты 35%")
	check(ItemData.grade_name("card_centaur").begins_with("Фиолетовая"), "подпись карты: " + ItemData.grade_name("card_centaur"))
	check(ItemData.card_for("centaur") == "card_centaur" and ItemData.soul_card_for("centaur") == "card_centaur_soul",
		"карты вида: card_centaur и card_centaur_soul")
	check(ItemData.is_soul_card("card_centaur_soul") and ItemData.card_species("card_centaur_soul") == "centaur",
		"карта с душой — кентавра")
	check(int(ItemData.get_item("card_centaur")["buy"]) == 0, "карта кентавра не продаётся")
	for s in ["kirk", "merchant"]:
		check(not (NpcData.npc(s).get("shop", []) as Array).has("card_centaur"), "%s не продаёт карту кентавра" % s)
	var drop := 0.0
	for e in MobData.get_type("centaur")["loot"]:
		var entry: Array = e
		check(not ItemData.get_item(String(entry[0])).is_empty(), "добыча кентавра есть в предметах: %s" % entry[0])
		if String(entry[0]) == "card_centaur":
			drop = float(entry[1])
	check(drop > 0.0 and drop <= 0.05, "карта кентавра выпадает из него (%.0f%%)" % (drop * 100.0))
	for it in ["spear_tip", "horse_hair"]:
		check(ItemData.item_type(it) == "trophy" and int(ItemData.get_item(it)["sell"]) > 0, "трофей %s" % it)
	var ic := ItemIcon.make("card_centaur_soul", 64.0)
	check(ic.item_id == "card_centaur_soul", "значок карты кентавра создаётся")
	ic.free()
	var t := "\n".join(PackedStringArray(Taming.card_lines("card_centaur")))
	check(t.contains("Кентавр") and t.contains("Боец"), "в описании карты — вид и роль: " + t)
	check(t.contains("Восточные равнины (ур. 13–16)"), "где водится кентавр: " + t)
	check(t.contains("фиолетовая") and t.contains("35%"), "тир и шанс: " + t)
	check(t.contains("выпадает из кентавра"), "где взять карту: " + t)


## Модели 1/2/3 стадии из файлов: клипы, размеры, кости торса, рук и копья; смена модели по стадии.
func _unit_models() -> void:
	var box := Node3D.new()
	main.add_child(box)
	for st in 3:
		var want := String(MODELS[st])
		check(ResourceLoader.exists(CreatureAsset.path_for(want)), "файл модели %s есть" % want)
		check(CreatureAsset.model_for("centaur", st) == want, "стадия %d → %s" % [st + 1, CreatureAsset.model_for("centaur", st)])
		check(CreatureAsset.species_of(want) == "centaur" and CreatureAsset.is_asset_species(want), "%s — модель кентавра" % want)
		var lvl := int(PetData.STAGE_LEVELS[st])
		var sc := PetData.stage_scale("centaur", lvl)
		var n := Node3D.new()
		box.add_child(n)
		CreatureModels.build(n, "centaur", PetData.stage_color("centaur", lvl), sc, PetData.asset_tint("centaur", lvl), st)
		var ca := CreatureModels.asset_of(n)
		check(ca != null and ca.species == want, "питомец-кентавр стадии %d — модель %s" % [st + 1, want])
		if ca == null:
			continue
		for k in CreatureAsset.CLIPS:
			check(ca.clips.has(k), "у %s есть клип %s" % [want, k])
		check(ca.skeleton != null and ca.anim != null, "у %s скелет и анимации" % want)
		var inf := CreatureAsset.info_for(want)
		check((inf["clips"] as Dictionary).size() == 7, "7 клипов %s в creatures.json" % want)
		check(float(inf["height"]) >= 2.0 and float(inf["height"]) <= 2.4, "высота %s %.2f м — выше героя" % [want, float(inf["height"])])
		var bones: Dictionary = inf["bones"]
		check((bones.get("legs", {}) as Dictionary).size() == 4, "у %s четыре конские ноги" % want)
		for b in [String(bones.get("spear", "")), String(bones.get("head", ""))]:
			check(b != "" and ca.skeleton.find_bone(b) >= 0, "кость %s есть в скелете %s" % [b, want])
		check((bones.get("torso", []) as Array).size() >= 2 and (bones.get("arms", {}) as Dictionary).size() == 2,
			"у %s торс и две руки" % want)
		check(ca.play_attack(1.4) > 0.0, "у %s удар в клипе атаки" % want)
	# Дикий кентавр — модель 1-й стадии
	var w := Node3D.new()
	box.add_child(w)
	CreatureModels.build(w, "centaur", MobData.get_type("centaur")["color"], 1.0)
	var wa := CreatureModels.asset_of(w)
	check(wa != null and wa.species == "centaur" and not wa.stage_model, "дикий кентавр — модель centaur")
	check(CreatureModels.height("centaur", 1.0) > 1.9, "подпись над диким кентавром выше героя")
	box.queue_free()


## Питомец: роль, названия стадий, статы по таблице вики, сила редкости, Сила — главный стат.
func _unit_pet_data() -> void:
	check(PetData.role("centaur") == "fighter", "кентавр — боец")
	var names: Array = PetData.get_species("centaur")["stages"]
	check(names.size() == 3 and String(names[0]) != String(names[1]) and String(names[1]) != String(names[2]),
		"три своих названия стадий: %s" % [names])
	var s1 := PetStats.base_stats("centaur", 1)
	# Наш 1-й ур. = ур. вики 1/0.3 ≈ 3.3: чуть выше опорной точки вики 1-го ур. (Сила 23, Выносливость 17)
	check(int(s1["str"]) >= 23 and int(s1["str"]) <= 25 and int(s1["vit"]) >= 17 and int(s1["vit"]) <= 19,
		"ур. 1 — статы вики (Сила ≈ 23, Выносливость ≈ 17): %s" % [s1])
	check(int(PetStats.base_stats("centaur", 45)["str"]) == 168, "ур. 45 (вики 150): Сила 168")
	for lvl in [1, 15, 30, 50]:
		var st := PetStats.base_stats("centaur", lvl)
		var best := ""
		for k in PetStats.STATS:
			if best == "" or int(st[k]) > int(st[best]):
				best = String(k)
		check(best == "str", "кентавр ур.%d: главный стат — Сила (%s)" % [lvl, best])
	var d := PetStats.derived("centaur", 1)
	var sp := PetData.get_species("centaur")
	check(int(d["max_hp"]) == roundi(float(sp["hp"]) * 1.3) and int(d["atk"]) == roundi(float(sp["atk"]) * 1.3),
		"ур. 1: HP и атака ×1.3 (%d, %d)" % [int(d["max_hp"]), int(d["atk"])])
	check(int(d["atk"]) == int(d["patk"]), "главная атака кентавра — физическая")
	for lvl in [10, 30]:
		var c := PetStats.derived("centaur", lvl)
		var w := PetStats.derived("wolf", lvl)
		check(int(c["max_hp"]) > int(w["max_hp"]) and int(c["atk"]) > int(w["atk"]),
			"питомец-кентавр ур.%d сильнее волка: HP %d/%d, атака %d/%d" % [lvl, int(c["max_hp"]), int(w["max_hp"]),
			int(c["atk"]), int(w["atk"])])
	check(float(sp["range"]) > float(PetData.get_species("wolf")["range"]), "копьё бьёт дальше клыков волка")


## Умения кентавра: 18 штук, свои тексты, ослабление зверя.
func _unit_skills() -> void:
	var ids := PetSkills.list_for("centaur")
	check(ids.size() == 18, "у кентавра 18 умений: %d" % ids.size())
	for id in ["spear_flurry", "piercing_strike", "hoof_quake", "spear_storm", "war_horn", "ruin_storm", "steppe_bond"]:
		check(ids.has(id) and String(PetSkills.get_skill(id).get("desc", "")) != "", "умение кентавра %s" % id)
		check(PetSkills.effect_text(id, 1) != "" and PetSkills.requirement_text(id, 1) != "", "тексты умения %s" % id)
	check(PetSkills.effect_text("spear_flurry", 1).contains("2 × 90%"), "«Двойной выпад»: " + PetSkills.effect_text("spear_flurry", 1))
	check(PetSkills.effect_text("piercing_strike", 1).contains("атака зверя −13%"),
		"«Пронзающий удар» ослабляет: " + PetSkills.effect_text("piercing_strike", 1))
	check(PetSkills.level_needed("piercing_strike", 1) == 6 and PetSkills.level_needed("spear_storm", 1) == 27,
		"уровни вики 20 и 90 → 6 и 27")
	check(PetSkills.first_stage("ruin_storm") == 2, "«Сокрушающий вихрь» — на 3-й стадии")
	# Ослабление: удары зверя слабее на долю, потом проходит
	var m := Mob.new()
	m.setup("wolf", -1, Vector3.ZERO, 3)
	m.weaken(0.3, 10.0)
	check(m._weakened(100) == 70, "ослабленный зверь бьёт на 30% слабее")
	m._tick_debuffs(11.0)
	check(m._weakened(100) == 100, "ослабление проходит")
	m.free()


## Дикий кентавр сильнее волка того же уровня.
func _unit_wild() -> void:
	for lvl in [13, 16, 25]:
		var c := Mob.new()
		c.setup("centaur", -1, Vector3.ZERO, lvl)
		var w := Mob.new()
		w.setup("wolf", -1, Vector3.ZERO, lvl)
		check(c.rarity == "rare" and c.level == lvl, "дикий кентавр ур.%d «Редкий»" % lvl)
		var hprof := Combat.profile_of(main.player)
		var rc := Combat.power_ratio(hprof, Combat.profile_of(c))
		var rw := Combat.power_ratio(hprof, Combat.profile_of(w))
		check(rc > rw and c.max_hp > w.max_hp and c.xp_reward > w.xp_reward,
			"ур.%d: кентавр сильнее волка — сила %.2f / %.2f, HP %d/%d, атака %d/%d, опыт %d/%d" % [lvl, rc, rw, c.max_hp,
			w.max_hp, c.atk, w.atk, c.xp_reward, w.xp_reward])
		c.free()
		w.free()


## Спауны: на суше, вне безопасных зон, не в зонах рыб и анатем.
func _unit_world() -> void:
	var w := IslandWorld.current
	var other: Array = []
	for z in w.cfg.get("mob_zones", []):
		var zone: Dictionary = z
		var has_c := false
		for e in zone.get("mobs", []):
			if String((e as Array)[0]) == "centaur":
				has_c = true
		if not has_c:
			other.append(zone)
	var n := 0
	var bad: Array = []
	for s in main._slots:
		var sl: Dictionary = s
		if String(sl["type"]) != "centaur":
			continue
		n += 1
		var p: Vector3 = sl["pos"]
		if w.in_safe_zone(p) or not w.is_walkable(p.x, p.z):
			bad.append("в безопасной зоне или в воде: %s" % p)
		var lv := int(sl["level"])
		if lv < 13 or lv > 27:
			bad.append("уровень %d" % lv)
		for oz in other:
			var zd: Dictionary = oz
			var id := String(zd.get("id", ""))
			if not (id.begins_with("fish_") or id.begins_with("anathema") or id.begins_with("cave")):
				continue
			if Vector2(p.x, p.z).distance_to(IslandWorld.v2(zd["center"])) <= float(zd.get("radius", 10.0)):
				bad.append("в зоне %s" % id)
	check(n >= 2, "кентавров на острове: %d" % n)
	check(bad.is_empty(), "кентавры на суше, вне безопасных зон и чужих зон (%s)" % [bad])
	check(Taming.lives_in_world("centaur"), "кентавр водится на острове")


func _window_text() -> String:
	var t := ""
	var win: Control = main.hud._window
	if win != null and is_instance_valid(win):
		for c in win.find_children("*", "Label", true, false):
			t += (c as Label).text + "\n"
	return t
