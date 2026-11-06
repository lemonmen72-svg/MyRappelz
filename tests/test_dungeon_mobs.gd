extends "res://tests/test_base.gd"
## Монстры подземелья (этап 2, 0.36; решения Максима): 14 видов dg_* 20–30 ур. — в MobData, модели из файлов
## (creatures.json: двуногие, хват оружия grips), обычные — сила босса острова того же уровня (HP, атака, защита,
## опыт), мини-боссы (вождь гоблинов, Мёртвый рыцарь, Старший жрец) — HP ×2 к ней, возрождение 20 мин, нападают сами;
## обычные нейтральны и возрождаются как на острове. Оружие в руке (mw_* из assets/handheld) — на кости кисти,
## клинок у кисти. В подземелье монстры стоят по своим залам (не на мостах, палубах, в коридорах, у портала, в
## твёрдых объектах), на острове их нет. Трофеи есть в ItemData. Без пакета — двуногие из примитивов, без оружия.

const ALL := ["dg_goblin", "dg_goblin_chief", "dg_sailor", "dg_graveguard", "dg_wight", "dg_dead_knight",
	"dg_bone_oracle", "dg_grave_oracle", "dg_plague_shaman", "dg_sect_wraith", "dg_elder_priest",
	"dg_coral_corsair", "dg_rot_corsair", "dg_reef_wraith"]
## Собранные модели [id, корень] — хват проверяется через кадры (кость обновляет метку в своём цикле).
var built: Array = []
const MINI := ["dg_goblin_chief", "dg_dead_knight", "dg_elder_priest"]
## Зал каждой зоны (room_at точки монстра).
const ZONE_ROOM := {"dg_goblins": "goblin_camp", "dg_goblin_chief": "goblin_camp", "dg_mine": "mine",
	"dg_crypt": "crypt", "dg_dead_knight": "crypt", "dg_sanctuary": "boss_room", "dg_elder_priest": "boss_room",
	"dg_treasury": "treasury"}


func race_class() -> Array:
	return ["human", "warrior"]


func hero_level() -> int:
	return 25


func before_start() -> void:
	Game.location = "dungeon"


func run_step() -> void:
	match step:
		0:
			if not bool(main.get("_started")):
				return
			_data()
			_strength()
			_models()
			_fallback()
			wait = 30
			step = 1
		1:
			_check_grips()
			_placement()
			ok_done()


func _data() -> void:
	for id in ALL:
		check(MobData.TYPES.has(id), "%s — в MobData" % id)
		var lv := int(MobData.get_type(id)["level"])
		check(lv >= 20 and lv <= 30, "%s: уровень %d в 20–30" % [id, lv])
		check(MobData.is_dungeon(id) and not MobData.tameable(id) and not MobData.is_boss(id),
			"%s: монстр подземелья, не приручается, не босс" % id)
		check(MobData.is_mini_boss(id) == MINI.has(id), "%s: мини-босс — %s" % [id, MINI.has(id)])
		check(MobStats.is_aggressive(id) == MINI.has(id), "%s: нападает сам только мини-босс" % id)
		var rs := MobData.respawn_time(id)
		check(is_equal_approx(rs, 1200.0) if MINI.has(id) else is_equal_approx(rs, MobData.RESPAWN_TIME),
			"%s: возрождение %.0f с" % [id, rs])
		var mats := MobData.materials(id)
		check(mats.size() == (MobData.get_type(id)["loot"] as Array).size() and mats.size() >= 2,
			"%s: трофеи есть в ItemData (%s)" % [id, mats])
		var w := MobData.weapon_of(id)
		if w != "":
			check(Handheld.exists(w), "%s: модель оружия %s есть" % [id, w])
		check(LootTable.item_count(id) == (3 if MINI.has(id) else 2), "%s: предметов в добыче %d" % [id, LootTable.item_count(id)])
	check(MobStats.is_magic("dg_bone_oracle") and not MobStats.is_magic("dg_goblin"), "жрецы бьют магией, гоблины — нет")


## Сила обычного — как у босса острова того же уровня (боссы острова: power 1.5, BOSS_*); мини-босс — HP ×2.
func _strength() -> void:
	for id in ["dg_goblin", "dg_sailor", "dg_wight", "dg_coral_corsair", "dg_goblin_chief", "dg_dead_knight"]:
		var lv := int(MobData.get_type(id)["level"])
		var m := MobStats.derived(id, lv)
		var b := MobStats.derived("boss_wolf", lv)
		var k := 2.0 if MINI.has(id) else 1.0
		var hp_ratio := float(m["max_hp"]) / float(b["max_hp"])
		check(absf(hp_ratio - k) < 0.02, "%s ур. %d: HP %d = босс острова ×%.0f (%d)" % [id, lv, m["max_hp"], k, b["max_hp"]])
		check(absf(float(m["patk"]) / float(b["patk"]) - 1.0) < 0.05, "%s: физ. атака как у босса (%d / %d)" % [id, m["patk"], b["patk"]])
		check(absf(float(m["xp"]) / float(b["xp"]) - 1.0) < 0.05, "%s: опыт как у босса (%d / %d)" % [id, m["xp"], b["xp"]])
		print("ПОДЗЕМЕЛЬЕ %s ур. %d: HP %d, атака %d, маг. %d, защита %d, опыт %d" % [id, lv, m["max_hp"], m["patk"],
			m["matk"], m["def"], m["xp"]])


## Модели из файлов: двуногие, хват есть; оружие — в кисти, клинок у кисти.
func _models() -> void:
	for id in ALL:
		check(CreatureAsset.has_asset(id), "%s: модель из файла" % id)
		var inf := CreatureAsset.info_for(id)
		check((inf.get("grips", {}) as Dictionary).has("R"), "%s: хват правой руки в creatures.json" % id)
		var root := Node3D.new()
		add_child(root)
		CreatureModels.build(root, id, Color.WHITE, 1.0)
		var ca := CreatureModels.asset_of(root)
		check(ca != null and ca.skeleton != null, "%s: модель со скелетом" % id)
		if ca == null:
			root.queue_free()
			continue
		var h := float(inf["height"])
		check(h > 1.2 and h < 2.5, "%s: рост %.2f м" % [id, h])
		var w := MobData.weapon_of(id)
		if w != "":
			check(ca.hold_weapon(w), "%s: оружие %s в руке" % [id, w])
			built.append([id, root])
			continue
		root.queue_free()


func _check_grips() -> void:
	for b in built:
		var id := String(b[0])
		var root := b[1] as Node3D
		var ca := CreatureModels.asset_of(root)
		var wn := ca.weapon_node if ca != null else null
		if wn != null:
			var inf := CreatureAsset.info_for(id)
			var hb := ca.skeleton.find_bone(String((inf["bones"]["hands"] as Dictionary)["R"]))
			var hand := ca.skeleton.global_transform * ca.skeleton.get_bone_global_pose(hb)
			var d := wn.global_position.distance_to(hand.origin)
			check(d < 0.25, "%s: хват оружия у кисти (%.3f м)" % [id, d])
			# Клинок — поперёк предплечья (как в кулаке), не вдоль руки и не в локоть
			var arm: Array = (inf["bones"]["arms"] as Dictionary)["R"]
			var fa := ca.skeleton.find_bone(String(arm[2]))
			var elbow := (ca.skeleton.global_transform * ca.skeleton.get_bone_global_pose(fa)).origin
			var fore := (hand.origin - elbow).normalized()
			var blade := wn.global_transform.basis.y.normalized()
			var ang := rad_to_deg(acos(clampf(fore.dot(blade), -1.0, 1.0)))
			print("ХВАТ %s: клинок к предплечью %.0f°" % [id, ang])
			check(ang > 40.0 and ang < 140.0, "%s: клинок поперёк предплечья (%.0f°)" % [id, ang])
		root.queue_free()


func _fallback() -> void:
	CreatureAsset.use_assets = false
	var root := Node3D.new()
	add_child(root)
	CreatureModels.build(root, "dg_dead_knight", Color.WHITE, 1.0)
	check(CreatureModels.asset_of(root) == null and root.get_child_count() > 0, "без файлов — модель из примитивов")
	root.queue_free()
	CreatureAsset.use_assets = true


## В подземелье: монстры по своим залам, все зоны заселены.
func _placement() -> void:
	var w := main.get("world") as DungeonWorld
	check(w != null and w.location() == "dungeon", "мир — подземелье")
	if w == null:
		return
	var want := 0
	for z in w.cfg.get("mob_zones", []):
		for m in (z as Dictionary)["mobs"]:
			want += int((m as Array)[1])
	var solids := w._solid_circles()
	var por := IslandWorld.v2((w.cfg["portal"] as Dictionary)["center"])
	var seen := {}
	var bad := 0
	var mobs := get_tree().get_nodes_in_group("mobs")
	for n in mobs:
		var mob := n as Mob
		if mob == null or mob.is_dead:
			continue
		seen[mob.type_id] = int(seen.get(mob.type_id, 0)) + 1
		var slot: Dictionary = (main.get("_slots") as Array)[mob.slot] if mob.slot >= 0 else {}
		var zone := String(slot.get("zone", ""))
		var p: Vector3 = slot.get("pos", mob.global_position)
		# Босс на палубе корабля (зона "fixed") — проверяет test_dungeon_boss
		if bool(_zone_cfg(w, zone).get("fixed", false)):
			continue
		var room := w.room_at(p.x, p.z)
		if not w._mob_spot_ok(p.x, p.z, solids, por) or room != String(ZONE_ROOM.get(zone, "?")):
			bad += 1
			print("  монстр %s зоны %s — место (%.1f, %.1f), зал «%s»" % [mob.type_id, zone, p.x, p.z, room])
	check(mobs.size() == want, "монстров в подземелье %d из %d" % [mobs.size(), want])
	check(bad == 0, "все монстры на полу своего зала, не в объектах (не там: %d)" % bad)
	for id in ALL:
		check(int(seen.get(id, 0)) > 0, "%s стоит в подземелье" % id)
		if MINI.has(id):
			check(int(seen.get(id, 0)) == 1, "%s — один" % id)
	for n in mobs:
		var mob := n as Mob
		if MobData.weapon_of(mob.type_id) != "" and mob._asset != null:
			check(mob._asset.weapon_node != null, "%s: оружие в руке в мире" % mob.type_id)
			break
	var island := FileAccess.get_file_as_string("res://world/training_island.json")
	check(not island.contains("\"dg_"), "на острове монстров подземелья нет")


func _zone_cfg(w: DungeonWorld, id: String) -> Dictionary:
	for z in w.cfg.get("mob_zones", []):
		if String((z as Dictionary).get("id", "")) == id:
			return z
	return {}
