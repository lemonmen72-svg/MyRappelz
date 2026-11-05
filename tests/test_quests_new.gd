extends "res://tests/test_base.gd"
## Новые виды целей и цепочки жителей: equip (броня, кольцо «ring1|ring2», вторая рука), upgrade (закалка оружия,
## оружие и броня до +3), pet_skill (изучено после взятия), pet_gear (карта снаряжения выдаётся при взятии),
## gather (находки QuestFind в зоне: появляются, срываются при подходе, исчезают, когда цель выполнена), quest
## (задание охотницы засчитано и раньше), buy с fits, kill с targets / min_level / max_level, суточные (cooldown:
## «снова через …», «прошли сутки» — снова доступно, время сдачи в сохранении), заказ писаря (цели и награда при
## взятии, обе разновидности, сохранение), повтор вожаков (награда повтора), заготовки наград (@body, @weapon),
## offhand_only, цепочки кузнеца, бронницы, ювелира, оружейника, Кирка, рыбака, ветерана, травницы, Корвена;
## значки «!» над новыми жителями и доска объявлений у писаря.

var _finds_n := 0


func race_class() -> Array:
	return ["dark_elf", "assassin"]


func hero_level() -> int:
	return 25


func before_start() -> void:
	AdminPanel.god = true


func run_step() -> void:
	var q: Quests = main.quests
	match step:
		0:
			_unit()
			_npcs_world()
			_equip_upgrade()
			_trade_and_offhand()
			_pets()
			_hunts()
			_daily_and_bosses()
			_contract()
			_herbs_start()
			wait = 3
			step = 1
		1:
			# Находки появились (опрос Quests раз в POLL с)
			q.poll(1.0)
			var f := q.finds()
			check(f.size() == Quests.FIND_COUNT, "находок в роще: %d" % f.size())
			for n in f:
				var p: Vector3 = (n as Node3D).global_position
				check(Vector2(p.x, p.z).distance_to(Vector2(-50, -54)) <= 20.0, "находка в Светлой роще: %s" % p)
			_finds_n = game.inventory.count("herb_silverleaf")
			if not f.is_empty():
				var fp: Vector3 = (f[0] as Node3D).global_position
				main.player.global_position = fp + Vector3(0.8, 0.2, 0.0)
			wait = 3
			step = 2
		2:
			check(game.inventory.count("herb_silverleaf") == _finds_n + 1, "подошёл — трава сорвана (%d)"
				% game.inventory.count("herb_silverleaf"))
			check(q.finds().size() == Quests.FIND_COUNT - 1, "сорванная исчезла: %d" % q.finds().size())
			q.poll(1.0)
			check(q.finds().size() == Quests.FIND_COUNT - 1, "новая вырастет не сразу")
			q.poll(Quests.FIND_RESPAWN + 1.0)
			check(q.finds().size() == Quests.FIND_COUNT, "через паузу — снова %d" % q.finds().size())
			game.inventory.add("herb_silverleaf", 5)
			q.poll(1.0)
			wait = 2
			step = 3
		3:
			check(q.is_ready("herb_gather") and q.finds().is_empty(), "собрано шесть — находки убраны (%d)" % q.finds().size())
			var n0: int = game.inventory.count("herb_silverleaf")
			check(q.complete("herb_gather") and game.inventory.count("herb_silverleaf") == n0 - 6, "травы отданы Мирте")
			check(q.state("herb_bottles") == "available" and q.state("herb_daily") == "available", "дальше — флаконы и суточные травы")
			main.player.global_position = Vector3(0, 0.5, 6)
			ok_done()


# ---------- Данные ----------

func _unit() -> void:
	for npc in QuestData.NPC_CHAINS:
		var list: Array = QuestData.NPC_CHAINS[npc]
		for i in list.size():
			var id := String(list[i])
			check(QuestData.has_quest(id) and QuestData.giver(id) == String(npc), "%s: у %s" % [id, npc])
			if i > 0:
				check(QuestData.prereqs(id) == [String(list[i - 1])], "%s после %s" % [id, list[i - 1]])
	for id in QuestData.all_ids():
		for g in QuestData.goals(String(id)):
			var gd: Dictionary = g
			for sp in QuestData.goal_species(gd):
				check(MobData.TYPES.has(String(sp)), "%s: зверь %s" % [id, sp])
			if String(gd["type"]) == "gather":
				var z := String(gd.get("zone", ""))
				check(IslandWorld.current == null or _zone(z) != {}, "%s: зона находок %s" % [id, z])
				check(ItemData.ITEMS.has(String((gd["items"] as Array)[0])), "%s: предмет находки" % id)
			if String(gd["type"]) == "quest":
				check(QuestData.has_quest(String(gd["id"])), "%s: задание цели %s" % [id, gd["id"]])
	check(ItemData.item_type("herb_silverleaf") == "trophy", "серебролист — трофей")
	# Заготовки наград по герою
	var c0: String = game.class_id
	game.class_id = "warrior"
	check(QuestData.resolve_item("@body_r1") == "armor_body_warrior_r1", "доспех воина")
	game.class_id = "wanderer"
	check(QuestData.resolve_item("@body_r2") == "armor_body_hunter_r2", "Бродяге — охотничий")
	game.class_id = "neophyte"
	var w := QuestData.resolve_item("@weapon_r2")
	check(ItemData.rank(w) == 2 and ItemData.weapon_fits(w, "neophyte"), "оружие 2-го ранга Неофиту: %s" % w)
	game.class_id = c0
	game.weapon = "weapon_dagger_r1"
	game.inventory.add("weapon_dagger_r1", 2)
	check(ItemData.weapon_kind(QuestData.resolve_item("@weapon_r2")) == "dagger", "вид — как у надетого")
	for id in ["merc_approach", "merc_guardian", "armorer_material"]:
		for it in QuestData.reward_items(id):
			check(ItemData.ITEMS.has(String(it)) or not ItemData.get_item(String(it)).is_empty(), "%s: награда %s" % [id, it])
	check(QuestData.goal_text({"type": "upgrade", "slots": ["weapon"], "plus": 2}) == "Заточить до +2: оружие",
		"подпись upgrade: " + QuestData.goal_text({"type": "upgrade", "slots": ["weapon"], "plus": 2}))
	check(QuestData.goal_text({"type": "quest", "id": "hunter_hunt"}).contains("Волчья стая"), "подпись quest")


func _zone(id: String) -> Dictionary:
	for z in IslandWorld.current.cfg.get("mob_zones", []):
		if String((z as Dictionary).get("id", "")) == id:
			return z
	return {}


## Новые жители стоят, у писаря — доска объявлений, значки «!».
func _npcs_world() -> void:
	var npcs: Npcs = main.npcs
	for id in ["fisher", "veteran", "herbalist", "scribe"]:
		check(npcs.npc(id) != null, "%s в мире" % id)
		check(Npcs.gives_quests(id), "%s: есть задания" % id)
	var b := npcs.board
	var s: Npc = npcs.npc("scribe")
	check(b != null and b.is_in_group("notice_board") and s != null, "доска объявлений есть")
	if b != null and s != null:
		var d := Vector2(b.global_position.x - s.global_position.x, b.global_position.z - s.global_position.z).length()
		check(d > 1.0 and d < 3.0, "доска рядом с писарем: %.1f м" % d)
		var w := IslandWorld.current
		check(w.road_distance(b.global_position.x, b.global_position.z) >= 2.0, "доска не на дороге")
	npcs.refresh_marks()
	for id in ["fisher", "veteran", "herbalist", "scribe"]:
		check(npcs.npc(id).mark_text() == "!", "над %s «!» (%s)" % [id, npcs.npc(id).mark_text()])
	check(npcs.greeting("fisher") == NpcData.greet("fisher", "offer"), "рыбак зовёт к делу")


# ---------- Снаряжение ----------

func _equip_upgrade() -> void:
	var q: Quests = main.quests
	var inv: Inventory = game.inventory
	var eco: Economy = main.economy
	game.quests_done["elder_grow"] = 1
	game.quests_done["elder_to_sage"] = 1
	# Кузнец: «Первая закалка» — оружие до +2
	check(q.accept("smith_temper"), "«Первая закалка» взято")
	inv.add("weapon_dagger_r1", 1)
	check(game.equip_weapon("weapon_dagger_r1") == "", "кинжал в руке")
	check(q.goal_progress("smith_temper", 0) == 0, "без закалки — 0")
	game.gold += 100000
	_stand_by("smith")
	for i in 2:
		var r := eco.temper(game.weapon, "weapon")
		check(bool(r["ok"]), "закалка %d: %s" % [i + 1, r["text"]])
	check(ItemData.enchant_level(game.weapon) == 2 and q.is_ready("smith_temper"), "оружие +2 — выполнено")
	check(q.complete("smith_temper") and inv.count("cube_attack_r1") >= 2, "награда — кубы атаки")
	# Бронница: материалы → доспех своего варианта; «Первый доспех» — 4 части
	check(q.accept("armorer_material"), "«Материал для доспеха» взято")
	check(q.quest_loot("wolf").has("wolf_pelt") and q.quest_loot("pheasant").has("pheasant_feather"), "шкуры и перья падают")
	inv.add("wolf_pelt", 6)
	inv.add("pheasant_feather", 6)
	check(q.complete("armorer_material") and inv.has("armor_body_warrior_r1"), "награда — доспех воина (Наёмнику)")
	check(q.accept("armorer_wear"), "«Первый доспех» взято")
	for id in ["armor_helmet_r1", "armor_gloves_r1", "armor_boots_r1"]:
		inv.add(id, 1)
	var parts := 0
	for id in ["armor_helmet_r1", "armor_body_warrior_r1", "armor_gloves_r1", "armor_boots_r1"]:
		check(game.equip_gear(id) == "", "надето: %s" % id)
		parts += 1
		check(q.goal_progress("armorer_wear", 0) == parts, "частей брони: %d" % q.goal_progress("armorer_wear", 0))
	check(q.is_ready("armorer_wear") and q.complete("armorer_wear"), "«Первый доспех» сдано")
	# «Снаряжение к бою»: оружие и 4 части до +3
	check(q.accept("smith_gear"), "«Снаряжение к бою» взято")
	for slot in ["weapon", "head", "body", "hands", "feet"]:
		while ItemData.enchant_level(Enchant.equipped_in(String(slot))) < 3:
			var r := eco.temper(Enchant.equipped_in(String(slot)), String(slot))
			if not bool(r["ok"]):
				check(false, "закалка %s: %s" % [slot, r["text"]])
				break
	check(q.goal_progress("smith_gear", 0) == 5 and q.is_ready("smith_gear"), "всё до +3: %d/5" % q.goal_progress("smith_gear", 0))
	check(q.complete("smith_gear"), "«Снаряжение к бою» сдано")
	# Ювелир: кольцо в любую из ячеек и серьги
	game.quests_done["jeweler_scales"] = 1
	check(q.accept("jeweler_try"), "«Кольцо на пробу» взято")
	inv.add("ring_luck_r1", 1)
	inv.add("earring_atk_r1", 1)
	check(game.equip_gear("ring_luck_r1", "ring2") == "" and q.goal_progress("jeweler_try", 0) == 1, "кольцо во 2-й ячейке — в счёт")
	check(game.equip_gear("earring_atk_r1") == "" and q.is_ready("jeweler_try"), "кольцо и серьги")
	check(q.complete("jeweler_try") and inv.count("cube_acc_r1") >= 2, "награда — кубы украшений")


func _trade_and_offhand() -> void:
	_tidy()
	var q: Quests = main.quests
	var eco: Economy = main.economy
	var inv: Inventory = game.inventory
	# «Оружие по руке»: не по профессии — не в счёт (Наёмнику посох не подходит)
	check(q.accept("weaponsmith_buy"), "«Оружие по руке» взято")
	_stand_by("weaponsmith")
	q.on_bought("weapon_staff_2h_r1", 1, "weaponsmith")
	check(q.goal_progress("weaponsmith_buy", 0) == 0, "посох Наёмнику не в счёт")
	q.on_bought("weapon_dagger_r1", 1, "merchant")
	check(q.goal_progress("weaponsmith_buy", 0) == 0, "у другого продавца не в счёт")
	game.gold += 10000
	check(eco.buy("weapon_sword_1h_r1", 1, "weaponsmith") and q.is_ready("weaponsmith_buy"), "куплен меч у Бранда")
	check(q.complete("weaponsmith_buy") and inv.has("stab_powder_r1"), "награда — порошок стабильности")
	# «Вторая рука»: Наёмнику — да (пара кинжалов), Неофиту — не предлагается
	game.class_id = "neophyte"
	check(q.state("weaponsmith_offhand") == "locked" and q.accept_block("weaponsmith_offhand").contains("второй"),
		"Неофит: «Вторая рука» не предлагается (%s)" % q.accept_block("weaponsmith_offhand"))
	check(not q.npc_quests("weaponsmith").has("weaponsmith_offhand"), "в списке оружейника его нет")
	game.class_id = "assassin"
	check(q.accept("weaponsmith_offhand"), "«Вторая рука» взято")
	game.offhand = ""
	q._refresh_state_goals(false)
	check(q.goal_progress("weaponsmith_offhand", 0) == 0, "вторая рука пуста")
	inv.add(ItemData.base_id(game.weapon), 1)
	var second := ItemData.base_id(game.weapon)
	var err: String = game.equip_offhand(second) if game.weapon == second else "заточенное оружие"
	if err != "":
		inv.add("weapon_dagger_r1", 2)
		game.equip_weapon("weapon_dagger_r1")
		err = game.equip_offhand("weapon_dagger_r1")
	check(err == "" and q.is_ready("weaponsmith_offhand"), "второй кинжал во второй руке (%s)" % err)
	check(q.complete("weaponsmith_offhand"), "«Вторая рука» сдано")


# ---------- Питомцы ----------

func _pets() -> void:
	_tidy()
	var q: Quests = main.quests
	var inv: Inventory = game.inventory
	game.quests_done["kirk_bond_trial"] = 1
	var i := AdminPanel.add_pet(main, "wolf", 20)
	check(i >= 0, "волк в коллекции")
	var rec: Dictionary = game.pets[i]
	rec["jp"] = 200
	# Изученное до взятия не в счёт
	var sid := ""
	for k in PetSkills.list_for("wolf"):
		if sid == "" and PetSkills.learn_block(rec, String(k)) == "" and not String(k).begins_with("item_expert"):
			sid = String(k)
	check(sid != "" and PetSkills.learn(rec, sid), "умение до задания")
	q.poll()
	check(q.accept("kirk_pet_skills") and q.goal_progress("kirk_pet_skills", 0) == 0, "до взятия — не в счёт")
	check(PetSkills.learn(rec, "item_expert_wolf"), "«Знаток снаряжения»")
	q.poll()
	check(q.goal_progress("kirk_pet_skills", 0) == 1, "одно умение: %d" % q.goal_progress("kirk_pet_skills", 0))
	var sid2 := ""
	for k in PetSkills.list_for("wolf"):
		if sid2 == "" and PetSkills.learn_block(rec, String(k)) == "":
			sid2 = String(k)
	check(sid2 != "" and PetSkills.learn(rec, sid2), "второе умение")
	q.poll()
	check(q.is_ready("kirk_pet_skills"), "два умения питомцу")
	check(q.complete("kirk_pet_skills"), "«Умения питомца» сдано")
	# Снаряжение: карта снаряжения при взятии
	inv.remove("unit_card", inv.count("unit_card"))
	check(q.accept("kirk_pet_gear") and inv.count("unit_card") == 1, "карта снаряжения выдана при взятии")
	inv.add("weapon_sword_1h_r1", 1)
	var e := PetGear.equip(rec, "weapon_sword_1h_r1")
	check(e == "", "меч питомцу: %s" % e)
	q.poll()
	check(q.is_ready("kirk_pet_gear"), "вещь на питомце")
	check(q.complete("kirk_pet_gear") and inv.has("restore_chalk"), "награда — мел")
	# «Зализать раны»: любые три материала
	check(q.accept("kirk_wound_lick"), "«Зализать раны» взято")
	inv.remove("pheasant_feather", inv.count("pheasant_feather"))
	inv.remove("wolf_claw", inv.count("wolf_claw"))
	inv.add("wolf_claw", 2)
	check(q.goal_progress("kirk_wound_lick", 0) == 2, "два когтя")
	inv.add("pheasant_feather", 1)
	check(q.is_ready("kirk_wound_lick") and q.complete("kirk_wound_lick") and inv.has("empty_bottle"),
		"коготь и перо — сдано, флакон")


# ---------- Охота: рыбак, ветеран, Корвен ----------

func _kill(sp: String, lvl: int, n: int) -> void:
	var q: Quests = main.quests
	var m: Mob = main.spawn_mob(sp, lvl, _ground(Vector2(60, 60)))
	for k in n:
		q.on_mob_killed(m)
	m.queue_free()


func _hunts() -> void:
	_tidy()
	var q: Quests = main.quests
	var inv: Inventory = game.inventory
	# Рыбак
	check(q.accept("fisher_biters"), "«Рыба шалит» взято")
	check(q.target_species().has("flyfish"), "зубаны — цель (красный значок)")
	_kill("flyfish", 5, 8)
	check(q.complete("fisher_biters"), "«Рыба шалит» сдано")
	check(q.accept("fisher_sails"), "«Паруса на развилке» взято")
	_kill("flyfish_sail", 9, 5)
	inv.add("sail_fin", 5)
	check(q.complete("fisher_sails"), "«Паруса» сдано")
	check(q.accept("fisher_drake"), "«Змеекрыл» взято")
	_kill("flyfish_drake", 16, 1)
	check(q.complete("fisher_drake"), "«Змеекрыл» сдано")
	game.quests_done["hunter_hunt"] = 1
	check(q.accept("fisher_lord") and not q.is_ready("fisher_lord"), "«Владыка течений» ждёт задания охотницы")
	check(q.accept("hunter_boss_flyfish"), "у охотницы — вожак")
	_kill("boss_flyfish", 22, 1)
	check(q.complete("hunter_boss_flyfish"), "вожак сдан охотнице")
	check(q.is_ready("fisher_lord") and q.complete("fisher_lord"), "рыбак засчитал Владыку")
	# Ветеран: уровни зверей
	check(q.accept("veteran_show"), "«Покажи умение» взято")
	_kill("wolf", 5, 3)
	check(q.goal_progress("veteran_show", 0) == 0, "волк 5 ур. не в счёт")
	_kill("wolf", 10, 3)
	_kill("turtle", 10, 3)
	_kill("panther", 11, 2)
	check(q.complete("veteran_show"), "«Покажи умение» сдано")
	check(q.accept("veteran_hooves"), "«Следы копыт»")
	_kill("centaur", 14, 5)
	inv.add("horse_hair", 5)
	check(q.complete("veteran_hooves"), "«Следы копыт» сдано")
	check(q.accept("veteran_north"), "«Северный берег»")
	_kill("turtle", 19, 8)
	check(q.complete("veteran_north"), "«Северный берег» сдано")
	check(q.accept("veteran_southwest"), "«Юго-западный берег»")
	_kill("panther", 23, 8)
	check(q.complete("veteran_southwest"), "«Юго-западный берег» сдано")
	# Корвен после «Закрытой пещеры»
	for k in ["sage_first_job", "sage_first_skill", "sage_to_merc", "merc_closed_cave"]:
		game.quests_done[String(k)] = 1
	check(q.accept("merc_scout"), "«Разведка скал»")
	_kill("anathema", 10, 8)
	check(q.complete("merc_scout"), "«Разведка скал» сдано")
	check(q.accept("merc_blades") and q.quest_loot("anathema_blade").has("bone_blade") and q.quest_loot("anathema").is_empty(),
		"«Клинки рубак»: клинки — только с рубак")
	inv.add("bone_blade", 5)
	check(q.complete("merc_blades"), "«Клинки рубак» сдано")
	check(q.accept("merc_approach"), "«Подступы»")
	var ts := q.target_species()
	check(ts.has("anathema") and ts.has("anathema_blade") and int(ts["anathema"]) == 20, "цели — оба вида с 20 ур.")
	_kill("anathema", 15, 3)
	check(q.goal_progress("merc_approach", 0) == 0, "анатема 15 ур. не в счёт")
	_kill("anathema", 21, 7)
	_kill("anathema_blade", 22, 8)
	var body := QuestData.resolve_item("@body_r2")
	check(q.is_ready("merc_approach") and q.complete("merc_approach") and inv.has(body), "«Подступы» — доспех %s" % body)
	_tidy()
	check(q.accept("merc_guardian"), "«Страж логова»")
	_kill("anathema_chief", 25, 1)
	var wpn := QuestData.resolve_item("@weapon_r2")
	check(q.complete("merc_guardian") and inv.has(wpn), "«Страж логова» — оружие %s" % wpn)
	_stand_by("merc_chief")
	main.npcs.talk_to("merc_chief")
	_press("opt_quests")
	_press("dq_merc_cave_soon")
	_press("accept")
	check(q.is_ready("merc_cave_soon"), "«Пещера откроется» — выслушали Корвена")
	_press("complete")
	check(q.is_done("merc_cave_soon"), "цепочка Корвена пройдена (%s; ячеек %d из %d)" % [main.hud._msg_label.text,
		game.inventory.used_cells(), game.inventory.capacity])
	main.npcs.close_dialog()


# ---------- Суточные и повтор вожаков ----------

func _daily_and_bosses() -> void:
	_tidy()
	var q: Quests = main.quests
	var id := "hunter_boss_pheasant"
	check(q.accept(id), "вожак взят")
	_kill("boss_pheasant", 15, 1)
	var first := QuestData.rewards(id)
	check(int(first["xp"]) == int(QuestData.get_quest(id)["rewards"]["xp"]), "первый раз — обычная награда")
	check(q.complete(id), "вожак сдан")
	check(q.state(id) == "locked" and q.cooldown_left(id) > QuestData.DAY - 60.0, "снова — через сутки")
	check(q.accept_block(id).contains("через"), "причина: " + q.accept_block(id))
	check(q.npc_quests("hunter").has(id), "в списке охотницы — «снова через …»")
	check(int(QuestData.rewards(id)["xp"]) == int(QuestData.get_quest(id)["repeat_rewards"]["xp"])
		and QuestData.reward_items(id).has("cube_attack_r1"), "повтор — кубы и зеркальная карта, опыта меньше")
	# Сохранение и загрузка: время сдачи сохраняется
	check(game.save_game() and game.load_game(), "сохранено и загружено")
	check(q.cooldown_left(id) > QuestData.DAY - 120.0, "после загрузки перезарядка та же")
	QuestData.time_shift = QuestData.DAY + 5.0
	check(q.state(id) == "available", "прошли сутки — снова доступно")
	var mirrors: int = game.inventory.count("mirror_card")
	check(q.accept(id), "повтор взят")
	_kill("boss_pheasant", 15, 1)
	check(q.complete(id) and q.times_done(id) == 2, "повтор сдан")
	check(game.inventory.count("mirror_card") >= mirrors + 1, "зеркальная карта за повтор")
	QuestData.time_shift = 0.0


## Заказ писаря: обе разновидности, уровни, сохранение, перезарядка.
func _contract() -> void:
	_tidy()
	var q: Quests = main.quests
	var id := "scribe_contract"
	var kinds: Dictionary = {}
	for seed in 40:
		var r := RandomNumberGenerator.new()
		r.seed = seed
		var c := QuestData.contract(game.level, IslandWorld.current.cfg.get("mob_zones", []), r)
		var g: Dictionary = (c["goals"] as Array)[0]
		kinds[String(g["type"])] = g
		check(int(c["rewards"]["gold"]) == QuestData.CONTRACT_GOLD * game.level, "золото по уровню")
	check(kinds.has("kill") and kinds.has("collect"), "заказы: охота и трофеи (%s)" % [kinds.keys()])
	if kinds.has("collect"):
		var cg: Dictionary = kinds["collect"]
		check(not MobData.is_boss(String(cg["drop_from"])) and bool(cg["take"]), "трофеи — с обычного зверя: %s" % cg["drop_from"])
	# Охота: подставить генератор с заказом на зверей
	var seed_kill := 0
	for s in 40:
		var r := RandomNumberGenerator.new()
		r.seed = s
		if String(((QuestData.contract(game.level, IslandWorld.current.cfg.get("mob_zones", []), r)["goals"]) as Array)[0]["type"]) == "kill":
			seed_kill = s
			break
	q.gen_rng = RandomNumberGenerator.new()
	q.gen_rng.seed = seed_kill
	check(q.accept(id), "заказ взят")
	q.gen_rng = null
	var g: Dictionary = QuestData.goals(id)[0]
	check(String(g["type"]) == "kill" and int(g["min_level"]) == game.level - 3 and int(g["max_level"]) == game.level + 3,
		"заказ: звери %d–%d ур." % [int(g.get("min_level", 0)), int(g.get("max_level", 0))])
	_kill("wolf", game.level + 5, 3)
	check(q.goal_progress(id, 0) == 0, "зверь выше разброса не в счёт")
	_kill("wolf", game.level, 4)
	check(q.goal_progress(id, 0) == 4, "свой уровень — в счёт")
	var gold := int(QuestData.rewards(id)["gold"])
	check(game.save_game() and game.load_game(), "заказ сохранён")
	check(q.is_active(id) and q.goal_progress(id, 0) == 4 and int(QuestData.goals(id)[0]["n"]) == QuestData.CONTRACT_KILLS
		and int(QuestData.rewards(id)["gold"]) == gold, "после загрузки — тот же заказ и прогресс")
	_kill("wolf", game.level, QuestData.CONTRACT_KILLS)
	var g0: int = game.gold
	check(q.complete(id) and game.gold == g0 + gold, "заказ сдан: +%d зол." % gold)
	check(q.state(id) == "locked" and q.cooldown_left(id) > 0.0, "новый заказ — завтра")
	# Диалог: «снова через …», недоступно
	_stand_by("scribe")
	main.npcs.talk_to("scribe")
	_press("opt_quests")
	var b: Button = main.npcs.buttons.get("dq_" + id)
	check(b != null and b.disabled and b.text.contains("снова через"), "в диалоге: %s" % (b.text if b != null else "—"))
	main.npcs.close_dialog()


func _herbs_start() -> void:
	var q: Quests = main.quests
	game.inventory.remove("herb_silverleaf", game.inventory.count("herb_silverleaf"))
	check(q.wanted_finds().is_empty() and q.finds().is_empty(), "без задания находок нет")
	check(q.accept("herb_gather"), "«Сбор трав» взято")
	check(q.wanted_finds().has("herb_silverleaf@elf_grove"), "нужны травы Светлой рощи")


# ---------- Помощники ----------

## Сумка без лишнего (надетое остаётся): награды и случайные предметы не упираются в полную сумку.
func _tidy() -> void:
	var inv: Inventory = game.inventory
	for k in inv.ids():
		var id := String(k)
		var keep := 0
		if game.weapon == id:
			keep += 1
		if game.offhand == id:
			keep += 1
		for sl in game.equip:
			if String(game.equip[sl]) == id:
				keep += 1
		if inv.count(id) > keep:
			inv.remove(id, inv.count(id) - keep)

func _ground(p: Vector2) -> Vector3:
	var y := 0.0
	if IslandWorld.current != null:
		y = IslandWorld.current.height_at(p.x, p.y)
	return Vector3(p.x, y + 0.1, p.y)


func _stand_by(id: String) -> void:
	var n: Npc = main.npcs.npc(id)
	if n == null:
		check(false, "житель %s" % id)
		return
	var fwd := Vector3(-sin(n.face_yaw), 0, -cos(n.face_yaw))
	var pos := n.global_position + fwd * 1.8
	if IslandWorld.current != null:
		pos.y = IslandWorld.current.height_at(pos.x, pos.z) + 0.1
	main.player.global_position = pos


func _press(key: String) -> void:
	var b: Button = main.npcs.buttons.get(key)
	check(b != null, "кнопка диалога %s" % key)
	if b != null:
		b.pressed.emit()
