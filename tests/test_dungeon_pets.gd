extends "res://tests/test_base.gd"
## Питомцы подземелья (этап 3, 0.37): Скелет (боец с мечом) и Спрут (маг поддержки). Данные: формы 1:1 с базой
## (StatResource 2401–2403 / 3501–3503), 18 умений древа + умения базы, значки всех своих умений, карты (синие, только
## добыча), дикие — в склепе и сокровищнице. Модели трёх стадий из файлов (спрут — свой стиль «octopus»), меч в руке
## скелета по стадии. Умения в бою: «Гнилой раскол» — зверь бьёт реже, «Ядовитая кровь» — яд и плата HP, «Вой пучины» —
## страх, «Кровавая жажда» — вампиризм хозяину, «Зов прилива» — маг. атака хозяину, «Омут порчи» — урон и лечение,
## «Клинок латника» — по площади; «Узы клинка» — скорость атаки хозяину, «Узы глубин» — MP хозяину, «Чернильная
## завеса» — зверь, бьющий хозяина, не переключается на спрута.

const SPECIES := ["skeleton", "octopus"]
var pm: PetManager = null


func race_class() -> Array:
	return ["human", "warrior"]


func hero_level() -> int:
	return 40


func before_start() -> void:
	AdminPanel.god = true
	Game.add_pet("skeleton", PetData.stage_name("skeleton", 2), 150)
	Game.add_pet("octopus", PetData.stage_name("octopus", 2), 150)
	for i in 2:
		Game.pets[i]["stage"] = 2
		Game.pets[i]["jp"] = 2000


func run_step() -> void:
	match step:
		0:
			if not bool(main.get("_started")):
				return
			pm = main.pets
			_data()
			_models()
			_learn_all()
			pm.summon(0)
			wait = 20
			step = 1
		1:
			_skeleton_fight()
			pm.summon(1)
			wait = 20
			step = 2
		2:
			_octopus_fight()
			wait = 20
			step = 3
		3:
			_octopus_pool()
			ok_done()


func _data() -> void:
	# Формы 1:1 с базой: ур. 1 = база + прирост
	var s1 := PetStats.base_stats("skeleton", 1, 0)
	check(int(s1["str"]) == 19 and int(s1["vit"]) == 14, "скелет 1 ур.: Сила %d, Вын %d (база 19+0.45, 14+0.317)" % [s1["str"], s1["vit"]])
	var o1 := PetStats.base_stats("octopus", 1, 0)
	check(int(o1["int"]) == 16 and int(o1["str"]) == 13, "спрут 1 ур.: Инт %d, Сила %d (база 16+0.417, 13+0.217)" % [o1["int"], o1["str"]])
	check(PetData.role("skeleton") == "fighter" and PetData.role("octopus") == "mage", "роли: скелет боец, спрут маг")
	check(PetStats.is_magic("octopus") and not PetStats.is_magic("skeleton"), "спрут бьёт магией, скелет — нет")
	for sp in SPECIES:
		var ids: Array = PetSkills.list_for(sp)
		check(ids.size() == 18 + 14, "%s: 18 умений древа и 14 из базы (%d)" % [sp, ids.size()])
		var no_icon: Array = []
		for id in ids:
			var sid := String(id)
			check(not PetSkills.get_skill(sid).is_empty(), "%s: умение «%s» описано" % [sp, sid])
			if not sid.begins_with("bless_") and not Assets.exists("res://assets/icons/pets/%s/%s.png" % [sp, sid]):
				no_icon.append(sid)
		check(no_icon.is_empty(), "%s: у всех своих умений есть значок (нет: %s)" % [sp, no_icon])
		var card := ItemData.card_for(sp)
		check(card == "card_" + sp and ItemData.card_tier(card) == "rare", "%s: синяя карта %s (%s)" % [sp, card, ItemData.card_tier(card)])
		check(MobData.tameable(sp) and MobData.is_dungeon(sp), "%s: дикий в подземелье приручается" % sp)
		check(Taming.habitat_text(sp).contains("подземелье"), "%s: на карте — где водится: %s" % [sp, Taming.habitat_text(sp)])
		check(not Taming.lives_in_world(sp, true), "%s: на острове не водится" % sp)
		check(ItemData.CREATURE_POTIONS.has(sp), "%s: зелье вида есть" % sp)
	check(PetSkills.list_for("skeleton").has("grave_thirst_skeleton") and PetSkills.list_for("octopus").has("wound_lick_octopus"),
		"«Могильная жажда» скелета и «Зализать раны» спрута")
	check(String(PetSkills.get_skill("fighter_unit_octopus")["name"]).begins_with("Чародей"), "у спрута «Чародей: булава и посох»")


func _models() -> void:
	for sp in SPECIES:
		for st in 3:
			var mid := CreatureAsset.model_for(sp, st)
			check(CreatureAsset.has_asset(mid) and mid == sp + String(CreatureAsset.STAGE_SUFFIX[st]),
				"%s: модель стадии %d — %s" % [sp, st + 1, mid])
	var bones: Dictionary = CreatureAsset.info_for("octopus")["bones"]
	check((bones.get("tentacles", []) as Array).size() >= 6, "у спрута щупальца-цепочки костей (%d)" % (bones.get("tentacles", []) as Array).size())
	for st in 3:
		check(PetData.weapon_of("skeleton", st).begins_with("mw_") and Handheld.exists(PetData.weapon_of("skeleton", st)),
			"скелет %d-й стадии с мечом %s" % [st + 1, PetData.weapon_of("skeleton", st)])
	check(PetData.weapon_of("octopus", 0) == "", "спрут без оружия")


func _learn_all() -> void:
	for i in 2:
		var rec: Dictionary = Game.pets[i]
		for _k in 20:
			for id in PetSkills.list_for(String(rec["species"])):
				PetSkills.learn(rec, String(id))


func _mob(type_id: String, lvl: int) -> Mob:
	var p: Vector3 = main.player.global_position + Vector3(3.5, 0.0, 0.0)
	var m: Mob = main.spawn_mob(type_id, lvl, IslandWorld.current.ground(p.x, p.z))
	m.max_hp = 10000000
	m.hp = m.max_hp
	return m


func _skeleton_fight() -> void:
	var pet: Pet = pm.active_pet
	check(pet != null and pet.species == "skeleton", "скелет призван")
	if pet == null:
		return
	check(pet._asset != null and pet._asset.weapon_node != null, "у призванного скелета меч в руке")
	var m := _mob("wolf", 40)
	var hp0 := m.hp
	pet._apply_skill("rot_cleave", m)
	check(m.hp < hp0, "«Гнилой раскол» ранил")
	check(m.get_node_or_null("Mod_aslow") != null, "«Гнилой раскол»: зверь бьёт реже")
	hp0 = m.hp
	pet._apply_skill("knight_blade", m)
	check(m.hp < hp0, "«Клинок латника» ранил")
	var p: Player = main.player
	var asp0 := p.attack_time
	check(pet.set_toggle("blade_bond", true) == "", "«Узы клинка» включены")
	check(p.aura_aspd > 0.0 and p.attack_time < asp0, "«Узы клинка»: хозяин бьёт чаще (%.3f → %.3f с)" % [asp0, p.attack_time])
	pet.set_toggle("blade_bond", false)
	m.consume()


func _octopus_fight() -> void:
	var pet: Pet = pm.active_pet
	check(pet != null and pet.species == "octopus", "спрут призван")
	if pet == null:
		return
	var p: Player = main.player
	var m := _mob("wolf", 40)
	var hp_pet := pet.hp
	pet._apply_skill("venom_blood", m)
	check(pet.hp < hp_pet, "«Ядовитая кровь»: спрут заплатил HP (%d → %d)" % [hp_pet, pet.hp])
	check(m.dots.has("pet_venom_blood"), "«Ядовитая кровь»: на звере яд")
	m.target = pet
	pet._apply_skill("abyss_wail", m)
	check(m.fear_time > 0.0, "«Вой пучины»: зверь в страхе (%.1f с)" % m.fear_time)
	pet._apply_skill("blood_thirst", null)
	check(p.timed_bonus.has("blood_thirst") and float(p.skill_bonus.get("leech_chance", 0.0)) > 0.3,
		"«Кровавая жажда» — на хозяине (шанс %.2f)" % float(p.skill_bonus.get("leech_chance", 0.0)))
	var matk0 := p.matk
	pet._apply_skill("tide_call", null)
	check(p.matk > matk0, "«Зов прилива»: маг. атака хозяина %d → %d" % [matk0, p.matk])
	check(pet.set_toggle("deep_bond", true) == "" and p.aura_mp > 0.0, "«Узы глубин»: MP хозяину %.1f/с" % p.aura_mp)
	pet.set_toggle("deep_bond", false)
	check(pet.set_toggle("ink_veil", true) == "" and pet.veil >= 0.3, "«Чернильная завеса»: шанс %d%%" % roundi(pet.veil * 100.0))
	# Зверь бьёт хозяина; удары спрута при завесе 100 % его не переключают
	pet.veil = 1.0
	m.fear_time = 0.0
	m.target = p
	m.take_damage(5, pet)
	check(m.target == p, "под «Чернильной завесой» зверь держит хозяина")
	pet.set_toggle("ink_veil", false)
	m.consume()


func _octopus_pool() -> void:
	var pet: Pet = pm.active_pet
	if pet == null:
		return
	var m := _mob("wolf", 40)
	m.global_position = pet.global_position + Vector3(1.5, 0.0, 0.0)
	var hp0 := m.hp
	pet.hp = maxi(1, pet.max_hp / 2)
	var php := pet.hp
	pet._apply_skill("corruption_pool", m)
	check(pet._pool_left > 9.0, "«Омут порчи» вокруг спрута на 10 с")
	pet._tick_pool(0.1)
	check(m.hp < hp0, "«Омут порчи» ранил зверя рядом")
	check(pet.hp > php, "«Омут порчи» лечит спрута (%d → %d)" % [php, pet.hp])
	m.consume()
