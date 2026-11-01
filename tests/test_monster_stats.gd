extends "res://tests/test_base.gd"
## Звери мира со статами и единая модель боя (решения Максима): у зверей те же 7 статов (MobStats), зверь равного
## уровня без прибавки HP равен герою (Combat.power_ratio — «эффективная сила» HP × урон в секунду ≈ 1), затем HP
## зверей ×MobStats.MOB_HP_MULT (3): с 10 ур. один на один без умений зверь своего уровня ≈ втрое сильнее героя, зверь
## на 5 ур. ниже — по силам; вход новичка (MOB_HP_START, MOB_ATK_START): на 1–5 ур. Бродяга побеждает зверя своего
## уровня (сила 0.35–0.75), на 6–9 ур. — плавный переход к ×3; боссов и мини-боссов вход не касается; столкновение
## статов (Combat): герой 10 ур. по зверю 30 ур. почти не попадает, а тот убивает героя за пару ударов; при равном
## уровне попадание ≥ 85 %; опыт по разнице уровней (−6 ур. — 50 %, +6 — +25 %) и множитель Game.xp_mult; кривая опыта; боссы — по одному на существо (модель
## 3-й эволюции или старшая, статы выше, один на один почти непобедимы, не приручаются, логово на суше вне безопасных
## зон); уровни зон острова 1–30; main.spawn_mob; зверь не лечится в бою, вне боя — лечится.

const COMMON := ["pheasant", "turtle", "panther"]
const JOBS := ["swordsman", "wizard", "beastmaster", "assassin", "neophyte", "adept", "warrior", "shaman", "conjurer"]
## Семейства существ острова → вид, чью модель берёт босс.
const FAMILIES := {
	"panther": "panther", "turtle": "turtle", "pheasant": "pheasant", "wolf": "wolf", "centaur": "centaur",
	"flyfish_drake": "flyfish", "anathema_chief": "anathema",
}
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


func _unit_stats() -> void:
	for k in MobData.TYPES:
		var id := String(k)
		for lvl in [1, 15, 30]:
			var d := MobStats.derived(id, lvl)
			var st: Dictionary = d["stats"]
			var ok := st.size() == 7
			for s in Stats.STATS:
				ok = ok and int(st.get(s, 0)) > 0
			check(ok and int(d["max_hp"]) > 0 and int(d["atk"]) > 0 and int(d["acc"]) > 0 and int(d["avoid"]) > 0
				and float(d["attack_cd"]) > 0.3, "%s ур.%d: 7 статов и производные (HP %d, атака %d, защита %d/%d)"
				% [id, lvl, int(d["max_hp"]), int(d["atk"]), int(d["def"]), int(d["mdef"])])
	# Профили: танк — Выносливость, маг — Интеллект, волк — Ловкость, анатема — Сила
	var t := MobStats.stats("turtle", 10)
	var pa := MobStats.stats("panther", 10)
	var w := MobStats.stats("wolf", 10)
	var an := MobStats.stats("anathema", 10)
	check(int(t["vit"]) > int(t["str"]) and int(pa["int"]) > int(pa["str"]) and int(w["agi"]) > int(w["str"])
		and int(an["str"]) > int(an["vit"]), "профили статов видов")
	check(MobStats.is_magic("panther") and MobStats.is_magic("pheasant") and not MobStats.is_magic("turtle"),
		"пантера и фазан бьют магией")
	# Звери растут с уровнем
	var a10 := MobStats.derived("turtle", 10)
	var a20 := MobStats.derived("turtle", 20)
	check(int(a20["max_hp"]) > int(a10["max_hp"]) and int(a20["atk"]) > int(a10["atk"]) and int(a20["def"]) > int(a10["def"]),
		"черепаха 20 ур. сильнее 10-го")


## Равный уровень: с 10 ур. без прибавки HP зверь равен герою-Бродяге (0.9–1.1), с HP ×MOB_HP_MULT — втрое сильнее;
## звери 1–9 ур. — вход новичка (MOB_HP_START, MOB_ATK_START): на 1–5 ур. Бродяга побеждает (сила зверя 0.35–0.75),
## на 6–9 ур. сила растёт к ×3; боссов и мини-боссов вход не касается.
func _unit_equal_level() -> void:
	check(is_equal_approx(MobStats.MOB_HP_MULT, 3.0), "HP зверей ×%.1f" % MobStats.MOB_HP_MULT)
	var n := MobStats.MOB_HP_START.size()
	var grows := MobStats.MOB_ATK_START.size() == n and n >= 5
	for l in range(1, n + 1):
		grows = grows and MobStats.hp_mult(l) < MobStats.hp_mult(l + 1) and MobStats.atk_mult(l) < MobStats.atk_mult(l + 1)
	check(grows and is_equal_approx(MobStats.hp_mult(n + 1), MobStats.MOB_HP_MULT) and is_equal_approx(MobStats.atk_mult(n + 1), 1.0)
		and is_equal_approx(MobStats.hp_mult(30), MobStats.MOB_HP_MULT) and is_equal_approx(MobStats.hp_mult(1, true), MobStats.MOB_HP_MULT)
		and is_equal_approx(MobStats.atk_mult(1, true), 1.0),
		"вход новичка 1–%d ур.: HP ×%.2f…×%.2f, атака ×%.2f…×%.2f, растут к ×%.0f и ×1; боссам и мини-боссам — нет"
		% [n, MobStats.hp_mult(1), MobStats.hp_mult(n), MobStats.atk_mult(1), MobStats.atk_mult(n), MobStats.MOB_HP_MULT])
	var d0 := MobStats.derived("turtle", 10)
	check(int(d0["max_hp"]) > int(MobStats.derived("turtle", 9)["max_hp"]), "HP зверей растёт с уровнем")
	var rows := ""
	var prev := 0.0
	for lvl in [1, 3, 5, 6, 7, 8, 9, 10, 20, 30]:
		var r := _ratio(lvl)
		rows += " %d:%.2f" % [lvl, r]
		if lvl <= 5:
			check(r >= 0.35 and r <= 0.75, "Бродяга %d ур. побеждает зверя своего уровня без питомца: сила зверя %.2f" % [lvl, r])
		elif lvl < 10:
			check(r > prev and r < 3.0, "Бродяга %d ур.: сила зверя своего уровня растёт к ×3 — %.2f" % [lvl, r])
		else:
			var pre := r / MobStats.hp_mult(lvl)
			check(pre >= 0.9 and pre <= 1.1, "Бродяга %d ур.: без прибавки HP зверь своего уровня равен герою — %.2f" % [lvl, pre])
			check(r >= 2.6 and r <= 3.4, "Бродяга %d ур.: зверь своего уровня с HP ×%.0f — %.2f силы героя (один на один без умений — проигрыш)"
				% [lvl, MobStats.MOB_HP_MULT, r])
		prev = r
	print("  Бродяга, сила зверя своего уровня:" + rows)
	# Мини-босс и босс без входа новичка: кентавр 3 ур. — полные HP и атака
	var c3 := MobStats.derived("centaur", 3)
	var w3 := MobStats.derived("wolf", 3)
	check(int(c3["max_hp"]) > int(w3["max_hp"]) * 2 and int(c3["atk"]) > int(w3["atk"]) * 2,
		"кентавр 3 ур. (мини-босс) без входа новичка: HP %d / волк %d, атака %d / %d" % [int(c3["max_hp"]), int(w3["max_hp"]),
		int(c3["atk"]), int(w3["atk"])])


## Профессии без умений, со стартовым оружием: без прибавки HP зверь своего уровня примерно равен герою, с HP ×3 —
## заметно сильнее (без умений, питомца и зелий бой 1×1 проигрышный).
func _unit_jobs() -> void:
	for lvl in [10, 20, 30]:
		var sum := 0.0
		var row := ""
		for j in JOBS:
			become_job(String(j))
			var r := _ratio(lvl)
			var pre := r / MobStats.hp_mult(lvl)
			sum += pre
			row += " %s %.2f" % [j, pre]
			check(pre > 0.55 and pre < 1.35 and r > 1.5, "%s %d ур.: зверь своего уровня — %.2f силы героя (без прибавки HP %.2f)"
				% [j, lvl, r, pre])
		var avg := sum / float(JOBS.size())
		print("  ур.%d, без прибавки HP:%s" % [lvl, row])
		check(avg >= 0.8 and avg <= 1.1, "профессии %d ур.: в среднем зверь без прибавки HP — %.2f силы героя" % [lvl, avg])
	become_job("wanderer")


## Разница уровней: попадания и урон.
func _unit_level_gap() -> void:
	var p: Player = main.player
	game.level = 10
	p.recalc_stats()
	var hp := Combat.profile_of(p)
	for id in COMMON:
		var m := Mob.new()
		m.setup(String(id), -1, Vector3.ZERO, 30)
		var hc := p.hit_chance(m)
		check(hc < 0.05, "герой 10 ур. по %s 30 ур.: попадание %.1f%%" % [id, hc * 100.0])
		var dmg := Combat.damage(float(m.atk), float(m.atk), Combat.defense_of(p, m.magic), 30, 10)
		var hits := ceili(float(p.max_hp) / float(dmg))
		check(hits <= 3, "%s 30 ур. убивает героя 10 ур. (HP %d) за %d удара (урон %d)" % [id, p.max_hp, hits, dmg])
		var mh := Combat.hit_chance(float(m.acc), float(p.avoid), 30, 10)
		check(mh > 0.95, "%s 30 ур. по герою 10 ур.: попадание %.0f%%" % [id, mh * 100.0])
		m.free()
		# Равный уровень — попадание обеих сторон ≥ 85 %
		var e := Mob.new()
		e.setup(String(id), -1, Vector3.ZERO, 10)
		check(p.hit_chance(e) >= 0.85 and Combat.hit_chance(float(e.acc), float(p.avoid), 10, 10) >= 0.85,
			"равный уровень (%s): герой %.0f%%, зверь %.0f%%" % [id, p.hit_chance(e) * 100.0,
			Combat.hit_chance(float(e.acc), float(p.avoid), 10, 10) * 100.0])
		e.free()
	# Кривая уровней: +5 — заметно ниже, +10 — редкие попадания, +20 — практически 0
	check(Combat.level_hit(5) < 0.75 and Combat.level_hit(5) > 0.5, "+5 ур.: %.0f%%" % (Combat.level_hit(5) * 100.0))
	check(Combat.level_hit(10) < 0.3, "+10 ур.: %.0f%%" % (Combat.level_hit(10) * 100.0))
	check(Combat.level_hit(20) < 0.01, "+20 ур.: %.2f%%" % (Combat.level_hit(20) * 100.0))
	check(Combat.skill_hit_chance(10, 12) == 1.0 and Combat.skill_hit_chance(10, 30) < 0.01, "умения: до +2 ур. без промаха")
	# Зверь на 4 ур. выше — намного сильнее зверя своего уровня; на 5 ур. ниже — по силам герою без умений
	var m5 := Mob.new()
	m5.setup("turtle", -1, Vector3.ZERO, 14)
	var r5 := Combat.power_ratio(hp, Combat.profile_of(m5))
	check(r5 > 4.5, "зверь +4 ур. — %.2f силы героя" % r5)
	m5.free()
	var lo := Mob.new()
	lo.setup("turtle", -1, Vector3.ZERO, 5)
	var rl := Combat.power_ratio(hp, Combat.profile_of(lo))
	check(rl < 1.0, "зверь −5 ур. по силам герою без умений: %.2f" % rl)
	lo.free()
	# Защита снижает урон, но не в ноль; разница уровней усиливает и ослабляет
	check(Combat.damage(100.0, 50.0, 1000.0, 10, 10) >= 1 and Combat.damage(100.0, 50.0, 50.0, 10, 10) == 50,
		"пробивание: защита, равная атаке, — половина урона")
	check(Combat.level_damage(30, 10) > 1.4 and Combat.level_damage(10, 30) < 0.6 and is_equal_approx(Combat.level_damage(5, 5), 1.0),
		"урон по разнице уровней")
	game.level = 1
	p.recalc_stats()


## Опыт: множитель по разнице уровней, кривая, xp_mult.
func _unit_xp() -> void:
	check(is_equal_approx(Combat.xp_factor(0), 1.0) and is_equal_approx(Combat.xp_factor(-6), 0.5),
		"опыт: равный — 100 %, на 6 ниже — 50 %")
	check(Combat.xp_factor(6) >= 1.2 and Combat.xp_factor(6) <= 1.3001, "на 6 выше — +%d%%" % roundi((Combat.xp_factor(6) - 1.0) * 100.0))
	check(Combat.xp_factor(-3) > 0.5 and Combat.xp_factor(-3) < 1.0 and Combat.xp_factor(-10) <= 0.2
		and Combat.xp_factor(-15) >= 0.1, "плавно: −3 → %.2f, −10 → %.2f" % [Combat.xp_factor(-3), Combat.xp_factor(-10)])
	var prev := 0.0
	var mono := true
	for d in range(-15, 16):
		mono = mono and Combat.xp_factor(d) >= prev
		prev = Combat.xp_factor(d)
	check(mono and Combat.xp_factor(20) <= 1.3001, "множитель растёт с уровнем зверя, не больше +30 %")
	game.xp_mult = 5
	check(Combat.xp_for(63, 10, 10) == 5 * 63 and Combat.xp_for(63, 4, 10) == 5 * roundi(63.0 * 0.5),
		"Game.xp_mult ×5: %d" % Combat.xp_for(63, 10, 10))
	game.xp_mult = 1
	# Кривая: до 10 ур. ≈ 90–140 зверей своего уровня, с 10 до 20 — 220–330 (опыт заданий — сверху)
	var k1 := 0.0
	var k2 := 0.0
	var grows := true
	for l in range(1, 40):
		grows = grows and int(game.xp_to_next(l + 1)) > int(game.xp_to_next(l))
	check(grows, "кривая опыта растёт до 40 ур.")
	for l in range(1, 20):
		var per: float = float(game.xp_to_next(l)) / MobStats.base_xp(l)
		if l < 10:
			k1 += per
		else:
			k2 += per
	check(k1 >= 90.0 and k1 <= 140.0, "до 10 ур.: %.0f зверей своего уровня" % k1)
	check(k2 >= 220.0 and k2 <= 330.0, "с 10 до 20 ур.: %.0f зверей" % k2)


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
		var x0: int = game.xp
		m.take_damage(m.hp + 5, p)
		gains.append(game.xp - x0)
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
