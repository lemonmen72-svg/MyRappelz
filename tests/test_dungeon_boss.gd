extends "res://tests/test_base.gd"
## Босс подземелья (этап 4, 0.38; решения Максима): Проклятый капитан dg_captain — модель Emerald Corsair Revenant
## (creatures.json, двуногий, хват), сабля Verdant Oathblade в руке (mw_oathblade), сила подземелья, HP ×4 к ней,
## возрождение 40 мин, босс (подпись «Босс · », 4 предмета добычи + 1 в подземелье, особые трофеи, нападает сам).
## Стоит на палубе корабля в гроте (зона "fixed" в world/dungeon.json), на острове его нет. Удар по площади «Клятва
## бездны» (MobData.slam_of → Mob.start_slam / _slam) и ярость с половины HP — удары чаще (вторая фаза), вылечился —
## ярость проходит. Без пакета — двуногий из примитивов, без оружия.

const ID := "dg_captain"
var cap: Mob = null
var hp0 := 0
var uses0 := 0


func race_class() -> Array:
	return ["human", "warrior"]


func hero_level() -> int:
	return 30


func before_start() -> void:
	Game.location = "dungeon"


func run_step() -> void:
	match step:
		0:
			if not bool(main.get("_started")):
				return
			_data()
			_model()
			_world()
			_slam_start()
			wait = 5
			step = 1
		1:
			# Замах 1.1 с — удар ещё не прошёл
			check(cap == null or cap.skill_uses == uses0, "во время замаха удара ещё нет")
			wait = 90
			step = 2
		2:
			_slam_done()
			_enrage()
			_fallback()
			ok_done()


func _data() -> void:
	check(MobData.TYPES.has(ID) and MobData.is_boss(ID) and MobData.is_dungeon(ID), "капитан — босс подземелья")
	check(not MobData.tameable(ID) and MobStats.is_aggressive(ID) and not MobData.is_mini_boss(ID),
		"не приручается, нападает сам, не мини-босс")
	check(int(MobData.get_type(ID)["level"]) == 30, "капитан 30 ур.")
	check(is_equal_approx(MobData.respawn_time(ID), 2400.0), "возрождение 40 мин (%.0f с)" % MobData.respawn_time(ID))
	# Сила: обычный монстр подземелья = босс острова того же уровня; капитан — HP ×4 к нему, атака та же
	var c := MobStats.derived(ID, 30)
	var g := MobStats.derived("dg_rot_corsair", 30)
	check(absf(float(c["max_hp"]) / float(g["max_hp"]) - 4.0) < 0.05, "HP %d = монстр подземелья ×4 (%d)" % [c["max_hp"], g["max_hp"]])
	check(absf(float(c["patk"]) / float(g["patk"]) - 1.0) < 0.05, "атака как у монстров подземелья (%d)" % c["patk"])
	print("БОСС ПОДЗЕМЕЛЬЯ %s ур. 30: HP %d, атака %d, защита %d, опыт %d" % [ID, c["max_hp"], c["patk"], c["def"], c["xp"]])
	check(LootTable.item_count(ID) == 4 and LootTable.item_count(ID, true) == 5, "добыча: 4 предмета, в подземелье 5")
	var sp := MobData.special_materials(ID)
	check(sp.size() == 2 and MobData.materials(ID).size() == 2, "трофеи %s и особые %s" % [MobData.materials(ID), sp])
	for it in sp:
		check(String(ItemData.get_item(String(it)).get("type", "")) == "trophy", "особый трофей %s есть" % it)
	var sl := MobData.slam_of(ID)
	check(not sl.is_empty() and float(sl["radius"]) >= 4.0 and float(sl["cd"]) > float(sl["windup"]),
		"удар по площади «%s»" % sl.get("text", ""))
	check(float(MobData.enrage_of(ID).get("hp", 0.0)) == 0.5, "ярость с половины HP")
	check(not MobData.slam_of("golem").is_empty() and MobData.slam_of("wolf").is_empty(), "удар по площади — у стража, у волка нет")
	var island := FileAccess.get_file_as_string("res://world/training_island.json")
	check(not island.contains("\"dg_captain\""), "на острове капитана нет")


func _model() -> void:
	check(CreatureAsset.has_asset(ID), "модель капитана из файла")
	var inf := CreatureAsset.info_for(ID)
	check((inf.get("grips", {}) as Dictionary).has("R"), "хват правой руки в creatures.json")
	check(MobData.weapon_of(ID) == "mw_oathblade" and Handheld.exists("mw_oathblade"), "сабля Verdant Oathblade")
	check(MobStats.model_id(ID, 30) == ID, "модель — своя (%s)" % MobStats.model_id(ID, 30))


func _world() -> void:
	var w := main.get("world") as DungeonWorld
	check(w != null, "мир — подземелье")
	cap = find_mob(ID)
	check(cap != null, "капитан стоит в подземелье")
	if w == null or cap == null:
		return
	var n := 0
	for m in get_tree().get_nodes_in_group("mobs"):
		if (m as Mob).type_id == ID:
			n += 1
	check(n == 1, "капитан один (%d)" % n)
	check(cap.is_boss and cap._label.text.contains("Босс · "), "подпись «%s»" % cap._label.text)
	var ship: Dictionary = {}
	for d in w.cfg.get("decks", []):
		if String((d as Dictionary).get("id", "")) == "ship":
			ship = d
	var p2 := Vector2(cap.home.x, cap.home.z)
	check(not ship.is_empty() and DungeonWorld.shape_sd(ship, p2) < 0.0, "дом капитана — на палубе корабля (%.1f, %.1f)" % [p2.x, p2.y])
	if not ship.is_empty():
		var dh := DungeonWorld.deck_height(ship, p2)
		check(absf(cap.home.y - dh) < 0.3, "капитан на высоте палубы (%.2f / %.2f)" % [cap.home.y, dh])
		check(absf(cap.global_position.y - dh) < 0.6, "стоит на палубе, не провалился (%.2f)" % cap.global_position.y)
	check(cap.body_scale > 1.3 and cap._height > 2.4, "крупный: рост %.2f м" % cap._height)
	check(cap._asset != null and cap._asset.weapon_node != null, "сабля в руке")


## Удар по площади: герой рядом, капитан замахивается — через замах урон всем в радиусе.
func _slam_start() -> void:
	if cap == null:
		return
	var p: Player = main.player
	AdminPanel.god = false
	p.global_position = cap.global_position + Vector3(0.0, 0.2, 1.6)
	# Запас HP, чтобы удар не уронил героя (иначе возрождение у входа с полным HP)
	p.max_hp = 10000000
	p.hp = p.max_hp
	hp0 = p.hp
	uses0 = cap.skill_uses
	cap.target = p
	cap.start_slam()
	check(cap._slam_windup > 0.9, "замах «Клятвы бездны»")


func _slam_done() -> void:
	if cap == null:
		return
	var p: Player = main.player
	check(cap.skill_uses > uses0, "«Клятва бездны» ударила")
	check(p.hp < hp0, "удар по площади ранил героя (%d → %d)" % [hp0, p.hp])
	AdminPanel.god = true
	p.recalc_stats()
	p.hp = p.max_hp


## Ярость: ниже половины HP удары чаще, вылечился выше — как было.
func _enrage() -> void:
	if cap == null:
		return
	var base := cap.attack_every
	check(not cap.enraged, "сначала без ярости")
	cap.take_damage(cap.hp - int(float(cap.max_hp) * 0.4), null)
	check(cap.enraged and cap.attack_every < base * 0.8, "ярость: удар раз в %.2f с (было %.2f)" % [cap.attack_every, base])
	cap.hp = cap.max_hp - 1
	cap._heal(1.0, 1.0)
	check(not cap.enraged and is_equal_approx(cap.attack_every, base), "вылечился — ярость прошла")


func _fallback() -> void:
	CreatureAsset.use_assets = false
	var root := Node3D.new()
	add_child(root)
	CreatureModels.build(root, ID, Color.WHITE, 1.0)
	check(CreatureModels.asset_of(root) == null and root.get_child_count() > 0, "без файлов — модель из примитивов")
	root.queue_free()
	CreatureAsset.use_assets = true
