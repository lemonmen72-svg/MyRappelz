extends "res://tests/test_base.gd"
## Звери мира и бой по базе и формулам сервера оригинала (MobStats, Combat; tools/rappelz_db_reference.md): числа
## зверей базы, Бродяга и профессии без умений побеждают зверя своего уровня; зверь 30 ур. убивает героя 10 ур. за
## несколько ударов; попадание и урон по формулам сервера; опыт по разнице уровней (−6 ур. — 50 %, +6 — +25 %), кривая
## и опыт зверей базы × рейт; множитель Game.xp_mult; боссы — по одному на существо (модель
## 3-й эволюции или старшая, статы выше, один на один почти непобедимы, не приручаются, логово на суше вне безопасных
## зон); уровни зон острова 1–30; main.spawn_mob; зверь не лечится в бою, вне боя — лечится.

const COMMON := ["pheasant", "turtle", "panther"]
const JOBS := ["swordsman", "wizard", "beastmaster", "assassin", "neophyte", "adept", "warrior", "shaman", "conjurer"]
## Семейства существ острова → вид, чью модель берёт босс.
const FAMILIES := {
	"panther": "panther", "turtle": "turtle", "pheasant": "pheasant", "wolf": "wolf", "centaur": "centaur",
	"flyfish_drake": "flyfish", "anathema_chief": "anathema",
}
## Бой без умений один на один: какую долю HP герой может потерять (> 1 — проигрыш). Бойцы побеждают; маги в
## оригинале сильны заклинаниями (обычная атака посохом), Зверолов — питомцем.
const SOLO_LIMIT := {"neophyte": 2.0, "wizard": 2.0, "shaman": 2.0, "adept": 2.0, "beastmaster": 3.0}
## Зверь для проверки лечения в бою и вне боя.
var regen_mob: Mob = null
var regen_hp := 0
var timer := 0


func race_class() -> Array:
	return ["human", "wanderer"]


func run_step() -> void:
	match step:
		0:
			_unit_stats()
			_unit_equal_level()
			_unit_jobs()
			_unit_level_gap()
			_unit_xp()
			_unit_bosses()
			_unit_zones()
			step = 1
		1:
			_world_xp()
			_world_bosses()
			_regen_start()
			wait = 2
			step = 2
		2:
			# Зверь в бою (цель — герой): HP ×3 не лечатся, пока герой рядом
			regen_mob.take_damage(regen_mob.max_hp / 2, main.player)
			regen_hp = regen_mob.hp
			timer = 0
			step = 3
		3:
			timer += 1
			stand_near(regen_mob, 1.5)
			if timer < 90:
				return
			check(regen_mob.target == main.player and regen_mob.hp <= regen_hp,
				"в бою зверь не лечится: %d/%d за 1.5 с" % [regen_mob.hp, regen_mob.max_hp])
			# Герой ушёл (дальше, чем зверь замечает): зверь лечится — доля HP в секунду, как прежде
			var p: Player = main.player
			var far: Vector3 = regen_mob.global_position + Vector3(20.0, 0.0, 0.0)
			far.y = IslandWorld.current.height_at(far.x, far.z) + 0.1
			p.global_position = far
			p.hp = p.max_hp
			regen_mob.target = null
			regen_mob.returning = false
			regen_hp = regen_mob.hp
			timer = 0
			step = 4
		4:
			timer += 1
			main.player.hp = main.player.max_hp
			if timer < 60:
				return
			var healed := regen_mob.hp - regen_hp
			check(regen_mob.target == null and healed >= roundi(float(regen_mob.max_hp) * 0.05),
				"вне боя зверь лечится: +%d HP за 1 с (из %d)" % [healed, regen_mob.max_hp])
			regen_mob.consume()
			game.level = 1
			main.player.recalc_stats()
			ok_done()


## Средняя сила зверей COMMON уровня lvl относительно героя (текущего Player) того же уровня.
func _ratio(lvl: int) -> float:
	var p: Player = main.player
	game.level = lvl
	p.recalc_stats()
	var hp := Combat.profile_of(p)
	var sum := 0.0
	for id in COMMON:
		var m := Mob.new()
		m.setup(String(id), -1, Vector3.ZERO, lvl)
		sum += Combat.power_ratio(hp, Combat.profile_of(m))
		m.free()
	return sum / float(COMMON.size())


## Бой один на один героя (текущая профессия, стартовое оружие, без умений) со зверем id уровня lvl: доля HP героя,
## которую он потеряет, пока убивает зверя (> 1 — проигрыш), и время боя, с.
func _duel(id: String, lvl: int) -> Array:
	var p: Player = main.player
	game.level = lvl
	p.recalc_stats()
	var h := Combat.profile_of(p)
	var m := Mob.new()
	m.setup(id, -1, Vector3.ZERO, lvl)
	var mp := Combat.profile_of(m)
	m.free()
	var t := float(mp["max_hp"]) / maxf(0.01, Combat.expected_dps(h, mp))
	return [t * Combat.expected_dps(mp, h) / float(h["max_hp"]), t]


func _unit_stats() -> void:
	for k in MobData.TYPES:
		var id := String(k)
		for lvl in [1, 15, 30]:
			var d := MobStats.derived(id, lvl)
			var st: Dictionary = d["stats"]
			check(st.size() == 7 and int(d["max_hp"]) > 0 and int(d["atk"]) > 0 and int(d["acc"]) > 0 and int(d["avoid"]) > 0
				and float(d["attack_cd"]) > 0.3, "%s ур.%d: 7 статов и производные (HP %d, атака %d, защита %d/%d)"
				% [id, lvl, int(d["max_hp"]), int(d["atk"]), int(d["def"]), int(d["mdef"])])
	check(MobStats.is_magic("panther") and MobStats.is_magic("pheasant") and not MobStats.is_magic("turtle"),
		"пантера и фазан бьют магией")
	# Числа базы + формулы сервера: черепаха 1 ур. — HP 105 + 30·1 + 20 = 155, атака 20 + 2·1 + 1 = 23; 20 ур. —
	# HP 1381 + 30·8 + 400 = 2021, атака 84 + 2·6 + 20 = 116, защита 54 + 2·8 + 20 = 90
	var t1 := MobStats.derived("turtle", 1)
	var t20 := MobStats.derived("turtle", 20)
	check(int(t1["max_hp"]) == 155 and int(t1["atk"]) == 23 and int(t20["max_hp"]) == 2021 and int(t20["atk"]) == 116
		and int(t20["def"]) == 90, "черепаха 1 / 20 ур. — числа базы оригинала: HP %d / %d, атака %d / %d, защита %d"
		% [int(t1["max_hp"]), int(t20["max_hp"]), int(t1["atk"]), int(t20["atk"]), int(t20["def"])])
	var grows := true
	for l in range(1, 60):
		var a := MobStats.derived("turtle", l)
		var b := MobStats.derived("turtle", l + 1)
		grows = grows and int(b["max_hp"]) > int(a["max_hp"]) and int(b["atk"]) >= int(a["atk"]) and int(b["xp"]) >= int(a["xp"])
	check(grows, "звери растут с уровнем 1–60")


## Равный уровень (формулы оригинала, без «HP ×3»): Бродяга и профессии со стартовым оружием без умений, питомца
## и зелий побеждают зверя своего уровня, теряя заметную долю HP; мини-босс и босс — намного сильнее.
func _unit_equal_level() -> void:
	var rows := ""
	for lvl in [1, 3, 5, 7, 9]:
		var d := _duel("turtle", lvl)
		rows += " %d:%.0f%%/%.0fс" % [lvl, float(d[0]) * 100.0, float(d[1])]
		check(float(d[0]) < 0.7, "Бродяга %d ур. побеждает черепаху своего уровня: теряет %.0f%% HP за %.0f с"
			% [lvl, float(d[0]) * 100.0, float(d[1])])
	print("  Бродяга против черепахи своего уровня (HP потеряно / время):" + rows)
	var c := MobStats.derived("centaur", 15)
	var w := MobStats.derived("wolf", 15)
	check(int(c["max_hp"]) > int(w["max_hp"]) * 4 and int(c["atk"]) > int(w["atk"]),
		"кентавр (мини-босс, элитный) 15 ур.: HP %d против волка %d" % [int(c["max_hp"]), int(w["max_hp"])])


## Профессии без умений, со стартовым оружием: зверь своего уровня по силам (без питомца и зелий).
func _unit_jobs() -> void:
	for lvl in [15, 25, 35]:
		var row := ""
		for j in JOBS:
			become_job(String(j))
			var d := _duel("turtle", lvl)
			row += " %s %.0f%%/%.0fс" % [j, float(d[0]) * 100.0, float(d[1])]
			# Зверолов в оригинале растит Интеллект и Мудрость (сила — через питомца): один без умений проигрывает,
			# но не всухую
			var lim := float(SOLO_LIMIT.get(String(j), 1.0))
			check(float(d[0]) < lim and float(d[1]) < 60.0, "%s %d ур. против зверя своего уровня без умений: %.0f%% HP за %.0f с"
				% [j, lvl, float(d[0]) * 100.0, float(d[1])])
		print("  ур.%d (HP потеряно / время):%s" % [lvl, row])
	become_job("wanderer")


## Разница уровней: попадания и урон по формулам сервера.
func _unit_level_gap() -> void:
	var p: Player = main.player
	game.level = 10
	p.recalc_stats()
	var hp := Combat.profile_of(p)
	for id in COMMON:
		var m := Mob.new()
		m.setup(String(id), -1, Vector3.ZERO, 30)
		var dmg := Combat.damage(float(m.atk), float(m.atk), Combat.defense_of(p, m.magic), 30, 10)
		var hits := ceili(float(p.max_hp) / float(dmg))
		check(hits <= 5, "%s 30 ур. убивает героя 10 ур. (HP %d) за %d ударов (урон %d)" % [id, p.max_hp, hits, dmg])
		var mh := Combat.hit_chance(float(m.acc), float(p.avoid), 30, 10)
		check(mh > 0.95, "%s 30 ур. по герою 10 ур.: попадание %.0f%%" % [id, mh * 100.0])
		check(p.hit_chance(m) < 0.75, "герой 10 ур. по %s 30 ур.: попадание %.0f%%" % [id, p.hit_chance(m) * 100.0])
		m.free()
		var e := Mob.new()
		e.setup(String(id), -1, Vector3.ZERO, 10)
		check(p.hit_chance(e) >= 0.8 and Combat.hit_chance(float(e.acc), float(p.avoid), 10, 10) >= 0.8,
			"равный уровень (%s): герой %.0f%%, зверь %.0f%%" % [id, p.hit_chance(e) * 100.0,
			Combat.hit_chance(float(e.acc), float(p.avoid), 10, 10) * 100.0])
		e.free()
	# Попадание сервера: равные — 95 %, +10 ур. — 75 %, +39 — 17 %
	check(is_equal_approx(Combat.level_hit(0), 0.95) and is_equal_approx(Combat.level_hit(10), 0.75)
		and is_equal_approx(Combat.level_hit(39), 0.17) and Combat.level_hit(-10) >= 1.0,
		"попадание по уровням: %.2f / %.2f / %.2f" % [Combat.level_hit(0), Combat.level_hit(10), Combat.level_hit(39)])
	check(Combat.skill_hit_chance(10, 12) == 1.0 and Combat.skill_hit_chance(10, 30) < 0.7, "умения: до +2 ур. без промаха")
	# Зверь выше — сильнее, ниже — слабее
	var r0 := Combat.power_ratio(hp, Combat.profile_of(_mob_at("turtle", 10)))
	var r4 := Combat.power_ratio(hp, Combat.profile_of(_mob_at("turtle", 14)))
	var rl := Combat.power_ratio(hp, Combat.profile_of(_mob_at("turtle", 5)))
	check(r4 > r0 * 1.5 and rl < r0 * 0.6, "зверь +4 ур. — %.2f, свой — %.2f, −5 ур. — %.2f силы героя" % [r4, r0, rl])
	# Урон сервера: A·max(0.05, 1 − 0.5·D/A) + 1.7·L·max(0.3, 1 − 0.4·D/A)
	check(Combat.damage(100.0, 100.0, 50.0, 10, 10) == 89 and Combat.damage(100.0, 100.0, 100.0, 1, 1) == 51
		and Combat.damage(100.0, 100.0, 10000.0, 1, 1) >= 5, "урон сервера: защита вычитается наполовину, не в ноль")
	game.level = 1
	p.recalc_stats()


var _mobs_tmp: Array = []


func _mob_at(id: String, lvl: int) -> Mob:
	var m := Mob.new()
	m.setup(id, -1, Vector3.ZERO, lvl)
	_mobs_tmp.append(m)
	return m


## Опыт: множитель по разнице уровней, кривая оригинала, рейт ×5, xp_mult.
func _unit_xp() -> void:
	check(is_equal_approx(Combat.xp_factor(0), 1.0) and is_equal_approx(Combat.xp_factor(-6), 0.5),
		"опыт: равный — 100 %, на 6 ниже — 50 %")
	check(Combat.xp_factor(6) >= 1.2 and Combat.xp_factor(6) <= 1.3001, "на 6 выше — +%d%%" % roundi((Combat.xp_factor(6) - 1.0) * 100.0))
	var prev := 0.0
	var mono := true
	for d in range(-15, 16):
		mono = mono and Combat.xp_factor(d) >= prev
		prev = Combat.xp_factor(d)
	check(mono and Combat.xp_factor(20) <= 1.3001, "множитель растёт с уровнем зверя, не больше +30 %")
	game.xp_mult = 5
	check(Combat.xp_for(63, 10, 10) == 5 * 63, "Game.xp_mult ×5: %d" % Combat.xp_for(63, 10, 10))
	game.xp_mult = 1
	check(int(game.xp_to_next(1)) == 15 and int(game.xp_to_next(20)) == 36784 and is_equal_approx(MobStats.base_xp(1), 25.0),
		"кривая и опыт зверя — из базы оригинала (×%.0f): %d, %d, %.0f" % [MobStats.XP_RATE, int(game.xp_to_next(1)),
		int(game.xp_to_next(20)), MobStats.base_xp(1)])
	var grows := true
	for l in range(1, 60):
		grows = grows and int(game.xp_to_next(l + 1)) > int(game.xp_to_next(l))
	check(grows, "кривая опыта растёт до 60 ур.")
	var k1 := 0.0
	var k2 := 0.0
	for l in range(1, 20):
		var per: float = float(game.xp_to_next(l)) / MobStats.base_xp(l)
		if l < 10:
			k1 += per
		else:
			k2 += per
	print("  зверей своего уровня: до 10 ур. %.0f, с 10 до 20 ур. %.0f" % [k1, k2])
	check(k1 >= 20.0 and k1 <= 35.0, "до 10 ур.: %.0f зверей своего уровня" % k1)
	check(k2 >= 150.0 and k2 <= 300.0, "с 10 до 20 ур.: %.0f зверей" % k2)
	for m in _mobs_tmp:
		(m as Mob).free()
	_mobs_tmp.clear()


## Боссы: по одному на существо, модель 3-й стадии (у рыб и анатем — старшая), статы выше, не приручаются.
func _unit_bosses() -> void:
	var per := {}
	for k in MobData.TYPES:
		var id := String(k)
		if not MobData.is_boss(id):
			continue
		var sp := MobData.species_of(id)
		check(FAMILIES.has(sp), "босс %s — существо острова (%s)" % [id, sp])
		per[sp] = int(per.get(sp, 0)) + 1
		var d := MobData.get_type(id)
		check(String(d["rarity"]) == "unique" and not MobData.tameable(id), "%s: «Уникальный», не приручается" % id)
		check(MobData.respawn_time(id) >= 300.0 and MobData.respawn_time(id) <= 600.0, "%s: возрождение %.0f с" % [id, MobData.respawn_time(id)])
		var want := sp + "_3" if PetData.SPECIES.has(sp) else sp
		check(MobStats.model_id(id, int(d["level"])) == want, "%s: модель %s" % [id, MobStats.model_id(id, int(d["level"]))])
		check(CreatureAsset.has_asset(want), "файл модели %s есть" % want)
		var lvl := int(d["level"])
		check(lvl >= 15 and lvl <= 30, "%s: %d ур." % [id, lvl])
		var b := Mob.new()
		b.setup(id, -1, Vector3.ZERO, lvl)
		var n := Mob.new()
		n.setup(sp, -1, Vector3.ZERO, lvl)
		check(b.is_boss and b.max_hp >= roundi(float(n.max_hp) * 1.5) and b.atk >= roundi(float(n.atk) * 1.2)
			and b.pdef > n.pdef and b.xp_reward > n.xp_reward * 3,
			"%s сильнее %s %d ур.: HP %d/%d, атака %d/%d, опыт %d/%d" % [id, sp, lvl, b.max_hp, n.max_hp, b.atk, n.atk,
			b.xp_reward, n.xp_reward])
		check(b.body_scale >= MobStats.body_scale(sp, 30) * 1.3, "%s крупнее зверя 3-й стадии: ×%.2f" % [id, b.body_scale])
		# Один на один без умений, питомца и зелий босс своего уровня почти непобедим
		game.level = lvl
		main.player.recalc_stats()
		var rb := Combat.power_ratio(Combat.profile_of(main.player), Combat.profile_of(b))
		check(rb > 8.0, "%s %d ур. против Бродяги своего уровня: %.1f силы героя" % [id, lvl, rb])
		var rare := false
		for e in MobData.materials(id) + MobData.special_materials(id):
			var it := String(e)
			check(not ItemData.get_item(it).is_empty(), "добыча %s: %s" % [id, it])
		for e in MobData.special_materials(id):
			var it := String(e)
			if ItemData.rarity(it) != "common" and ItemData.item_type(it) == "trophy":
				rare = true
		check(rare, "%s: особый материал — редкий трофей" % id)
		check(LootTable.item_count(id) == 4 and LootTable.categories_for(id, lvl).has("special"),
			"%s: 4 предмета, среди категорий — особый материал" % id)
		var g: Array = MobData.gold_range(id, lvl)
		var ng: Array = MobData.gold_range(sp, lvl)
		check(int(g[0]) > int(ng[1]), "%s: золота больше (%d–%d против %d–%d)" % [id, int(g[0]), int(g[1]), int(ng[0]), int(ng[1])])
		b.free()
		n.free()
	game.level = 1
	main.player.recalc_stats()
	for sp in FAMILIES:
		check(int(per.get(sp, 0)) == 1, "босс %s — ровно один (%d)" % [FAMILIES[sp], int(per.get(sp, 0))])
	check(not MobData.is_boss("anathema_chief") and MobData.rarity_name("anathema_chief") == "Редкий",
		"«Вожак анатем» остаётся «Редким» стражем логова, босс анатем — отдельный")


## Зоны острова: уровни 1–30, луга новичков 1–3, у каждого босса своё логово на суше вне безопасных зон.
func _unit_zones() -> void:
	var w := IslandWorld.current
	var lo := 99
	var hi := 0
	var bosses := {}
	for s in main._slots:
		var sl: Dictionary = s
		var lv := int(sl["level"])
		lo = mini(lo, lv)
		hi = maxi(hi, lv)
		var id := String(sl["type"])
		if String(sl["zone"]) == "meadows":
			check(lv <= 3, "луга новичков: %s %d ур." % [id, lv])
		if MobData.is_boss(id):
			bosses[id] = int(bosses.get(id, 0)) + 1
			var p: Vector3 = sl["pos"]
			check(not w.in_safe_zone(p) and w.is_walkable(p.x, p.z), "логово %s на суше, вне безопасных зон: %s" % [id, p])
			check(lv == int(MobData.get_type(id)["level"]), "%s в мире %d ур." % [id, lv])
			for z in w.cfg.get("safe_zones", []):
				var zd: Dictionary = z
				check(Vector2(p.x, p.z).distance_to(IslandWorld.v2(zd["center"])) > float(zd["radius"]) + 12.0,
					"%s дальше 12 м от безопасной зоны %s" % [id, zd["id"]])
	check(lo <= 2 and hi == 30, "уровни зверей острова: %d–%d" % [lo, hi])
	# Около деревень рас (решение Максима) — только звери 1–5 ур., больше всего 1–2: зоны старше 5 ур. — краем не
	# ближе 30 м от центра деревни, у каждой деревни — свои «Окрестности» с фазанами 1–2 ур.
	for v in w.cfg.get("safe_zones", []):
		var vz: Dictionary = v
		if not String(vz["id"]).ends_with("_village"):
			continue
		var vc := IslandWorld.v2(vz["center"])
		var lo_n := 0
		var all_n := 0
		for z in w.cfg.get("mob_zones", []):
			var zd: Dictionary = z
			var edge := IslandWorld.v2(zd["center"]).distance_to(vc) - float(zd["radius"])
			if int((zd["levels"] as Array)[1]) > 5:
				check(edge >= 30.0, "у %s нет зверей старше 5 ур.: зона %s краем в %.0f м" % [vz["id"], zd["id"], edge])
		for s in main._slots:
			var sl: Dictionary = s
			var p: Vector3 = sl["pos"]
			var dv := Vector2(p.x, p.z).distance_to(vc)
			if dv < 28.0:
				check(int(sl["level"]) <= 5, "у %s: %s %d ур. в %.0f м" % [vz["id"], sl["type"], int(sl["level"]), dv])
			if dv < 45.0 and int(sl["level"]) <= 5:
				all_n += 1
				if int(sl["level"]) <= 2:
					lo_n += 1
		check(all_n >= 6 and float(lo_n) >= 0.4 * float(all_n), "у %s звери 1–2 ур. — больше всего: %d из %d"
			% [vz["id"], lo_n, all_n])
	for k in MobData.TYPES:
		if MobData.is_boss(String(k)):
			check(int(bosses.get(String(k), 0)) == 1, "босс %s на острове — один" % k)


## Опыт за убийство в мире (main._on_mob_gone): разница уровней и Game.xp_mult; main.spawn_mob.
func _world_xp() -> void:
	var p: Player = main.player
	game.level = 10
	game.xp = 0
	p.recalc_stats()
	var pos: Vector3 = IslandWorld.current.ground(p.global_position.x + 30.0, p.global_position.z)
	var gains: Array = []
	for e in [[10, 1], [4, 1], [16, 1], [10, 5]]:
		game.xp_mult = int(e[1])
		var m: Mob = main.spawn_mob("turtle", int(e[0]), pos)
		check(m != null and m.slot == -1 and m.level == int(e[0]), "main.spawn_mob: черепаха %d ур." % int(e[0]))
		game.level = 10
		game.xp = 0
		var x0: int = game.xp
		m.take_damage(m.hp + 5, p)
		gains.append(game.xp - x0 if game.level == 10 else -1)
	game.xp_mult = 1
	var base := int(gains[0])
	check(base == MobStats.derived("turtle", 10)["xp"], "опыт за зверя своего уровня: %d" % base)
	check(int(gains[1]) == maxi(1, roundi(float(MobStats.derived("turtle", 4)["xp"]) * 0.5)), "−6 ур.: половина (%d)" % int(gains[1]))
	check(int(gains[2]) == roundi(float(MobStats.derived("turtle", 16)["xp"]) * Combat.xp_factor(6)), "+6 ур.: +25 %% (%d)" % int(gains[2]))
	check(int(gains[3]) == base * 5, "×5 админ-панели: %d" % int(gains[3]))
	game.level = 1
	game.xp = 0
	p.recalc_stats()


## Зверь для проверки лечения: черепаха 10 ур. у дома черепахи острова (вне безопасных зон), герой 10 ур.
func _regen_start() -> void:
	var p: Player = main.player
	game.level = 10
	p.recalc_stats()
	var t := find_mob("turtle")
	var w := IslandWorld.current
	var base: Vector3 = t.home if t != null else p.global_position + Vector3(30.0, 0.0, 0.0)
	var pos := base
	for off in [Vector3(3, 0, 0), Vector3(-3, 0, 0), Vector3(0, 0, 3), Vector3(0, 0, -3)]:
		var c: Vector3 = base + off
		if w.is_walkable(c.x, c.z) and not w.in_safe_zone(c):
			pos = c
			break
	regen_mob = main.spawn_mob("turtle", 10, w.ground(pos.x, pos.z))
	check(regen_mob != null and not IslandWorld.current.in_safe_zone(regen_mob.global_position), "черепаха для проверки лечения")


## Боссы в мире: крупные, подпись «Босс», не приручаются.
func _world_bosses() -> void:
	for k in MobData.TYPES:
		var id := String(k)
		if not MobData.is_boss(id):
			continue
		var b := find_mob(id)
		check(b != null and b.is_boss and b.rarity == "unique", "босс %s в мире" % id)
		if b == null:
			continue
		check(b._label.text.contains("Босс · ") and b._label.modulate.is_equal_approx(MobData.BOSS_COLOR),
			"%s: подпись «%s» цветом босса" % [id, b._label.text.get_slice("\n", 0)])
		check(Taming.badge_state(id) == Taming.BADGE_NO, "%s нельзя приручить" % id)
		if b._asset != null:
			check(b._asset.species == b.model_id, "%s: модель %s" % [id, b.model_id])
