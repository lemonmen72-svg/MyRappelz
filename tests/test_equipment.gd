extends "res://tests/test_base.gd"
## Экипировка (этап 2, задача Максима 14–24): броня (шлем, доспех, перчатки, ботинки) и украшения (2 кольца, серьги,
## кулон, пояс) — ItemData «Броня и украшения», Game.equip, Player.recalc_stats.
## Проверяется: предметы рангов 1–2 всех вариантов (id = имя значка), стопки по одному, кому подходит доспех (воин /
## маг / призыватель, Бродяге — любой); надеть и снять каждую ячейку, два одинаковых кольца, ограничения ячейки,
## уровня (ранг) и профессии, надетое не занимает ячеек сумки; показатели героя растут (защиты, HP, MP, крит, сила
## крита, скорости, уклонение, бег); прибавка комплекта против зверя своего уровня (печатает «ПРИБАВКА …»);
## смена профессии снимает чужой доспех; сохранение и загрузка, старое сохранение без "equip"; добыча (броня — как
## оружие, украшения — только боссы; статистика по 2000 убийствам), награды заданий (доспех по профессии, украшения
## 7.5 %); окно сумки (ячейки экипировки, «Надеть», «Во 2-е кольцо», перетаскивание, сравнение, «Снять»), окно героя
## (ячейки экипировки, строка «От экипировки»), склад, мешочек с бронёй, админ-панель (группы «Броня», «Украшения»).

const STAT_KILLS := 2000
const SHARE_TOL := 0.03

var drop: LootDrop = null
## Сколько перчаток и колец маны было до мешочка.
var _had_gloves := 0
var _had_ring := 0


func race_class() -> Array:
	return ["human", "warrior"]


func hero_level() -> int:
	return 15


func run_step() -> void:
	var player: Player = main.player
	var eco: Economy = main.economy
	var inv: Inventory = game.inventory
	match step:
		0:
			_unit_items()
			_unit_fits()
			_unit_balance()
			_unit_loot()
			_unit_quest_rewards()
			var types: Array = []
			for g in AdminPanel.item_groups():
				types.append(String((g as Array)[0]))
			check(types.has("armor") and types.has("jewelry"), "админ-панель: группы «Броня» и «Украшения»: %s" % [types])
			step = 1
		1:
			_equip_each_slot()
			_equip_rules()
			_stats_grow()
			step = 2
		2:
			_save_load()
			_job_change()
			step = 3
		3:
			_bag_window()
			wait = 3
			step = 4
		4:
			_hero_window()
			wait = 3
			step = 5
		5:
			main.hud.close_window()
			_storage()
			# Мешочек с бронёй и украшением у ног героя
			var pos := player.global_position + Vector3(1.0, 0.0, 0.0)
			_had_gloves = inv.count("armor_gloves_r1")
			_had_ring = inv.count("ring_mp_r1")
			drop = eco.spawn_drop(pos, {"armor_gloves_r1": 1, "ring_mp_r1": 1}, 5)
			wait = 40
			step = 6
		6:
			check(not is_instance_valid(drop) or drop.is_queued_for_deletion(), "мешочек с бронёй подобран")
			check(inv.count("armor_gloves_r1") == _had_gloves + 1 and inv.count("ring_mp_r1") == _had_ring + 1,
				"перчатки и кольцо из мешочка — в сумке (%d, %d)" % [inv.count("armor_gloves_r1"), inv.count("ring_mp_r1")])
			ok_done()


# ---------- Предметы ----------

func _unit_items() -> void:
	var n := 0
	for base in ItemData.ARMOR_DEFS.keys() + ItemData.JEWELRY_DEFS.keys():
		for r in [1, 2]:
			var id := ItemData.gear_id(String(base), int(r))
			var it := ItemData.get_item(id)
			check(not it.is_empty(), "предмет %s есть" % id)
			if it.is_empty():
				continue
			n += 1
			check(ItemData.is_gear(id) and ItemData.is_equipment(id) and ItemData.rank(id) == int(r),
				"%s: снаряжение %d-го ранга" % [id, int(r)])
			check(ItemData.required_level(id) == (1 if int(r) == 1 else 21), "%s: надеть с %d ур." % [id, ItemData.required_level(id)])
			check(ItemData.stack_size(id) == 1, "%s: по одному в ячейке" % id)
			check(ItemData.icon_path(id) == ItemData.ICON_DIR + id + ".png", "%s: значок — %s" % [id, ItemData.icon_path(id)])
			check(not ItemData.gear_slots_for(id).is_empty(), "%s: есть ячейка экипировки" % id)
			check(not ItemData.gear_bonus(id).is_empty(), "%s: бонус %s" % [id, ItemData.gear_bonus_text(ItemData.gear_bonus(id))])
			check(int(it.get("sell", 0)) > 0 and (int(it.get("buy", 0)) > 0) == (int(r) == 1),
				"%s: продаётся торговцу, купить можно только 1-й ранг" % id)
	check(n == (ItemData.ARMOR_DEFS.size() + ItemData.JEWELRY_DEFS.size()) * 2, "вещей рангов 1–2: %d" % n)
	# Контракт id со значками и торговцами
	for id in ["armor_body_warrior_r1", "armor_body_mage_r2", "armor_body_summoner_r1", "armor_helmet_r2", "armor_gloves_r1",
			"armor_boots_r2", "ring_hp_r1", "ring_mp_r2", "ring_crit_r1", "ring_critdmg_r2", "ring_aspd_r1", "ring_cast_r2",
			"earring_crit_r1", "earring_critdmg_r1", "earring_aspd_r2", "earring_cast_r1", "pendant_hp_r1", "pendant_mp_r2",
			"pendant_pdef_r1", "pendant_mdef_r2", "belt_pdef_r1", "belt_mdef_r2", "belt_eva_r1", "belt_speed_r2"]:
		check(ItemData.is_gear(String(id)), "id из контракта: %s" % id)
	# Ячейки: 9, кольцо — в обе ячейки колец
	check(ItemData.GEAR_SLOTS.size() == 9, "ячеек брони и украшений — 9")
	check(ItemData.gear_slots_for("ring_hp_r1") == ["ring1", "ring2"], "кольцо — в «Кольцо 1» и «Кольцо 2»")
	check(ItemData.gear_slots_for("armor_body_mage_r1") == ["body"] and ItemData.gear_slots_for("belt_eva_r1") == ["belt"],
		"доспех — «Тело», пояс — «Пояс»")
	# Варианты доспеха: воин — физ. выше маг., маг — наоборот, призыватель — между
	for r in [1, 2]:
		var w := ItemData.gear_bonus(ItemData.gear_id("armor_body_warrior", int(r)))
		var m := ItemData.gear_bonus(ItemData.gear_id("armor_body_mage", int(r)))
		var s := ItemData.gear_bonus(ItemData.gear_id("armor_body_summoner", int(r)))
		check(float(w["def"]) > float(s["def"]) and float(s["def"]) > float(m["def"]) and float(m["mdef"]) > float(s["mdef"])
			and float(s["mdef"]) > float(w["mdef"]), "%d-й ранг: воин / призыватель / маг — физ. %d/%d/%d, маг. %d/%d/%d" % [int(r),
			int(w["def"]), int(s["def"]), int(m["def"]), int(w["mdef"]), int(s["mdef"]), int(m["mdef"])])
	for base in ["armor_helmet", "armor_gloves", "armor_boots"]:
		var b := ItemData.gear_bonus(ItemData.gear_id(String(base), 1))
		check(b.size() == 1 and b.has("def"), "%s: только физ. защита" % base)
	check(ItemData.item_type("ring_hp_r1") == "jewelry" and ItemData.type_name("ring_hp_r1") == "Украшение"
		and ItemData.type_name("armor_helmet_r1") == "Броня", "типы: «Броня», «Украшение»")
	check(ItemData.sort_before("weapon_sword_1h_r1", "armor_helmet_r1") and ItemData.sort_before("armor_helmet_r1", "ring_hp_r1")
		and ItemData.sort_before("ring_hp_r1", "potion_hp_r1"), "сортировка: оружие, броня, украшения, расходники")


func _unit_fits() -> void:
	var want := {
		"assassin": "warrior", "warrior": "warrior", "swordsman": "warrior",
		"neophyte": "mage", "wizard": "mage", "shaman": "mage",
		"adept": "summoner", "beastmaster": "summoner", "conjurer": "summoner",
	}
	for job in want:
		check(ItemData.body_armor_for(String(job)) == String(want[job]), "%s носит %s" % [job, String(want[job])])
		for v in ItemData.BODY_ARMOR:
			var id := ItemData.gear_id("armor_body_" + String(v), 1)
			check(ItemData.armor_fits(id, String(job)) == (String(v) == String(want[job])),
				"%s: %s %s" % [job, id, "подходит" if String(v) == String(want[job]) else "не подходит"])
		check(ItemData.armor_fits("armor_helmet_r2", String(job)) and ItemData.armor_fits("ring_cast_r1", String(job)),
			"%s: шлем и кольцо — всем" % job)
	for v in ItemData.BODY_ARMOR:
		check(ItemData.armor_fits(ItemData.gear_id("armor_body_" + String(v), 2), ClassData.WANDERER), "Бродяге — любой доспех: %s" % v)
	check(not ItemData.armor_fits("weapon_sword_1h_r1", "warrior") and ItemData.equip_fits("weapon_axe_2h_r1", "warrior"),
		"оружие — по своим правилам")


## Прибавка комплекта 1-го и 2-го ранга против зверя своего уровня (формулы Combat, герой без оружия и умений).
func _unit_balance() -> void:
	var sets := {
		"warrior": ["warrior", "wolf", false], "mage": ["wizard", "panther", true], "summoner": ["adept", "wolf", false],
	}
	for v in sets:
		var e: Array = sets[v]
		var job := String(e[0])
		var mob := String(e[1])
		var magic := bool(e[2])
		var parts: PackedStringArray = []
		for lvl in [5, 10, 15, 20, 21, 35, 50]:
			var r := ItemData.equip_rank_for_level(int(lvl))
			var ids: Array = [ItemData.gear_id("armor_body_" + String(v), r), ItemData.gear_id("armor_helmet", r),
				ItemData.gear_id("armor_gloves", r), ItemData.gear_id("armor_boots", r)]
			var gb := ItemData.gear_bonus_total(ids)
			var h := HeroStats.derived(job, int(lvl))
			var md := MobStats.derived(mob, int(lvl))
			var a := float(md["atk"])
			var armor := float(h["mdef"] if magic else h["def"])
			var add := float(gb["mdef"] if magic else gb["def"])
			var f0 := Combat.damage_factor(a, armor, int(lvl), int(lvl))
			var f1 := Combat.damage_factor(a, armor + add, int(lvl), int(lvl))
			var cut := 1.0 - f1 / f0
			parts.append("%d ур. −%d%%" % [int(lvl), roundi(cut * 100.0)])
			if int(lvl) == 10 or int(lvl) == 15 or int(lvl) == 35:
				check(cut >= 0.12 and cut <= 0.35, "%s (%s): урон %s от %s %d ур. меньше на %.0f%% (12–35 %%)"
					% [v, job, "магии" if magic else "ударов", mob, int(lvl), cut * 100.0])
			if int(lvl) == 20 or int(lvl) == 50:
				check(cut >= 0.08 and cut <= 0.25, "%s: в конце ранга (%d ур.) −%.0f%% (8–25 %%)" % [v, int(lvl), cut * 100.0])
		print("  ПРИБАВКА комплект %s (%s, %s): %s" % [v, job, "маг. защита" if magic else "физ. защита", ", ".join(parts)])


# ---------- Добыча и награды ----------

func _unit_loot() -> void:
	var cats := LootTable.categories_for("wolf", 10)
	check(is_equal_approx(float(cats.get("armor", 0.0)), 0.25) and not cats.has("jewelry"), "волк: броня 25, украшений нет")
	var bc := LootTable.categories_for("boss_panther", 24)
	check(is_equal_approx(float(bc.get("armor", 0.0)), 0.25) and is_equal_approx(float(bc.get("jewelry", 0.0)), 0.15),
		"босс: броня 25, украшения 15")
	for e in [["centaur", 15], ["anathema_chief", 25], ["flyfish_drake", 16]]:
		check(not LootTable.categories_for(String(e[0]), int(e[1])).has("jewelry"), "%s (минибосс): украшений нет" % e[0])
	# Ранг по уровню зверя
	for e in [[5, 1], [20, 1], [21, 2], [35, 2], [60, 2]]:
		for p in LootTable.pool("armor", "wolf", int(e[0])):
			check(ItemData.rank(String((p as Array)[0])) == int(e[1]), "%d ур.: броня %d-го ранга (%s)" % [int(e[0]), int(e[1]), (p as Array)[0]])
	# Вид вещи — поровну, вариант доспеха — поровну
	var w: Dictionary = {}
	for p in LootTable.pool("armor", "wolf", 10):
		var kind := ItemData.gear_kind(String((p as Array)[0]))
		w[kind] = float(w.get(kind, 0.0)) + float((p as Array)[1])
	check(w.size() == 4 and is_equal_approx(float(w["body"]), 1.0) and is_equal_approx(float(w["head"]), 1.0),
		"броня: шлем, доспех, перчатки, ботинки — поровну: %s" % [w])
	# Статистика: босс 24 ур. — доли категорий как веса, броня 2-го ранга, все варианты доспеха
	var rng := RandomNumberGenerator.new()
	rng.seed = 314
	var total_w := 0.0
	for k in bc:
		total_w += float(bc[k])
	var got: Dictionary = {}
	var variants: Dictionary = {}
	var kinds: Dictionary = {}
	var total := 0
	for i in STAT_KILLS:
		var loot := LootTable.roll("boss_panther", 24, false, rng)
		for k in loot:
			var id := String(k)
			var c := LootTable.category_of(id, "boss_panther")
			got[c] = int(got.get(c, 0)) + int(loot[k])
			total += int(loot[k])
			if c == "armor" or c == "jewelry":
				check(ItemData.rank(id) == 2, "босс 24 ур.: %s 2-го ранга" % id)
				kinds[ItemData.gear_kind(id)] = int(kinds.get(ItemData.gear_kind(id), 0)) + 1
			if ItemData.armor_variant(id) != "":
				variants[ItemData.armor_variant(id)] = true
	for k in ["armor", "jewelry"]:
		var share := float(got.get(k, 0)) / float(maxi(1, total))
		var want := float(bc[k]) / total_w
		check(absf(share - want) < SHARE_TOL, "босс: доля «%s» %.3f ≈ %.3f" % [k, share, want])
	check(variants.size() == 3, "из босса — все три варианта доспеха: %s" % [variants.keys()])
	for k in ["head", "body", "hands", "feet", "ring", "earring", "pendant", "belt"]:
		check(int(kinds.get(k, 0)) > 20, "выпадает %s: %d" % [k, int(kinds.get(k, 0))])
	print("  ДОБЫЧА босс 24 ур.: броня %d, украшения %d из %d предметов; виды %s" % [int(got.get("armor", 0)),
		int(got.get("jewelry", 0)), total, kinds])
	# Обычный зверь — украшений нет никогда
	var wolf_jewelry := 0
	var wolf_armor := 0
	for i in STAT_KILLS:
		var loot := LootTable.roll("wolf", 12, false, rng)
		for k in loot:
			if ItemData.is_jewelry(String(k)):
				wolf_jewelry += 1
			if ItemData.is_armor(String(k)):
				wolf_armor += 1
				check(ItemData.rank(String(k)) == 1, "волк 12 ур.: броня 1-го ранга")
	check(wolf_jewelry == 0 and wolf_armor > 300, "волк: брони %d, украшений %d" % [wolf_armor, wolf_jewelry])


func _unit_quest_rewards() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var ch := LootTable.quest_chances(12, "wizard", rng)
	check(is_equal_approx(float((ch["armor"] as Array)[0]), 0.125), "награда: броня 12.5 % (вдвое ниже добычи)")
	check(is_equal_approx(float((ch["jewelry"] as Array)[0]), 0.075), "награда: украшения 7.5 % (половина шанса босса)")
	for p in ((ch["armor"] as Array)[1] as Array):
		var id := String((p as Array)[0])
		check(ItemData.armor_fits(id, "wizard") and ItemData.rank(id) == 1, "Волшебнику 12 ур.: %s — подходит, 1-й ранг" % id)
	var got: Dictionary = {}
	var any_variant: Dictionary = {}
	for i in 1500:
		var r := LootTable.quest_reward(25, "warrior", rng)
		for k in r:
			var id := String(k)
			got[LootTable.category_of(id)] = int(got.get(LootTable.category_of(id), 0)) + 1
			if ItemData.is_gear(id):
				check(ItemData.rank(id) == 2, "25 ур.: награда %s 2-го ранга" % id)
			if ItemData.armor_variant(id) != "":
				check(ItemData.armor_variant(id) == "warrior", "Воину — доспех воина: %s" % id)
		var r2 := LootTable.quest_reward(8, ClassData.WANDERER, rng)
		for k in r2:
			if ItemData.armor_variant(String(k)) != "":
				any_variant[ItemData.armor_variant(String(k))] = true
	check(int(got.get("armor", 0)) > 50 and int(got.get("jewelry", 0)) > 20, "в наградах есть броня и украшения: %s" % [got])
	check(any_variant.size() == 3, "Бродяге — доспехи всех вариантов: %s" % [any_variant.keys()])
	print("  НАГРАДЫ Воин 25 ур. (1500 заданий): %s" % [got])


# ---------- Надеть и снять ----------

func _equip_each_slot() -> void:
	var inv: Inventory = game.inventory
	var p: Player = main.player
	var list := {
		"head": "armor_helmet_r1", "body": "armor_body_warrior_r1", "hands": "armor_gloves_r1", "feet": "armor_boots_r1",
		"ring1": "ring_hp_r1", "ring2": "ring_crit_r1", "earring": "earring_aspd_r1", "pendant": "pendant_mp_r1",
		"belt": "belt_speed_r1",
	}
	for gs in list:
		var id := String(list[gs])
		inv.add(id)
		var used0 := inv.used_cells()
		var err: String = p.equip_gear(id, String(gs))
		check(err == "", "%s: надето %s %s" % [gs, id, err])
		check(String(game.gear_in(String(gs))) == id, "%s: в ячейке %s" % [gs, id])
		check(inv.find_cell(id) == -1 and inv.count(id) == 1 and inv.used_cells() == used0 - 1,
			"%s: надетое не занимает ячейку сумки, но числится (%d)" % [gs, inv.count(id)])
	for gs in list:
		var id := String(list[gs])
		var used1 := inv.used_cells()
		p.unequip_gear(String(gs))
		check(String(game.gear_in(String(gs))) == "" and inv.find_cell(id) >= 0 and inv.used_cells() == used1 + 1,
			"%s: снято — %s снова в сумке" % [gs, id])
	check(game.equip.is_empty(), "всё снято")


func _equip_rules() -> void:
	var inv: Inventory = game.inventory
	var p: Player = main.player
	# Не та ячейка
	var e1: String = game.equip_gear("armor_helmet_r1", "body")
	check(e1 != "" and game.gear_in("body") == "", "шлем на тело не надеть: %s" % e1)
	check(String(game.equip_gear("potion_hp_r1")) != "", "зелье не надеть")
	# Профессия: Воину — только доспех воина
	inv.add("armor_body_mage_r1")
	var e2: String = game.equip_gear("armor_body_mage_r1")
	check(e2.contains("не для профессии"), "Воину доспех мага не надеть: %s" % e2)
	# Уровень: 2-й ранг — с 21 ур.
	inv.add("armor_helmet_r2")
	var e3: String = game.equip_gear("armor_helmet_r2")
	check(e3.contains("21"), "шлем 2-го ранга на 15 ур.: %s" % e3)
	game.level = 21
	check(String(game.equip_gear("armor_helmet_r2")) == "", "на 21 ур. — надет шлем 2-го ранга")
	game.level = 15
	game.ensure_gear()
	check(game.gear_in("head") == "", "уровень ниже ранга — шлем снят (ensure_gear)")
	# Нет в сумке
	check(not inv.has("belt_eva_r1") and String(game.equip_gear("belt_eva_r1")).contains("нет в сумке"), "чего нет в сумке — не надеть")
	inv.add("ring_mp_r1")
	# Два одинаковых кольца: второе — только если есть вторая штука
	check(String(game.equip_gear("ring_mp_r1", "ring1")) == "", "кольцо маны — в «Кольцо 1»")
	var e4: String = game.equip_gear("ring_mp_r1", "ring2")
	check(e4.contains("Второй"), "одно кольцо в две ячейки не надеть: %s" % e4)
	inv.add("ring_mp_r1")
	check(String(game.equip_gear("ring_mp_r1", "ring2")) == "", "второе такое же кольцо — в «Кольцо 2»")
	check(inv.count("ring_mp_r1") == 2 and inv.find_cell("ring_mp_r1") == -1, "оба кольца надеты, ячеек не занимают")
	# Без ячейки — первая свободная, иначе замена в первой
	game.unequip_gear("ring1")
	check(game.gear_slot_for("ring_hp_r1") == "ring1", "свободное кольцо — «Кольцо 1»")
	check(String(game.equip_gear("ring_hp_r1")) == "" and game.gear_in("ring1") == "ring_hp_r1", "кольцо жизни — в первую свободную")
	check(game.gear_slot_for("ring_crit_r1") == "ring1", "обе заняты — замена в «Кольцо 1»")
	game.unequip_gear("ring1")
	game.unequip_gear("ring2")
	p.recalc_stats()


func _stats_grow() -> void:
	var p: Player = main.player
	p.recalc_stats()
	var d0 := p.defense
	var m0 := p.mdef
	var hp0 := p.max_hp
	var mp0 := p.max_mp
	var c0 := p.crit
	var a0 := p.aspd
	var cs0 := p.cast_speed
	var e0 := p.eva
	var s0 := p.speed
	check(is_equal_approx(p.crit_mult, Player.CRIT_MULT), "без украшений сила крита ×%.2f" % p.crit_mult)
	var inv: Inventory = game.inventory
	var worn := ["armor_body_warrior_r1", "armor_helmet_r1", "armor_gloves_r1", "armor_boots_r1", "ring_hp_r1", "ring_critdmg_r1",
		"earring_cast_r1", "pendant_mp_r1", "belt_speed_r1"]
	for id in worn:
		if not inv.has(String(id), 1):
			inv.add(String(id))
		var err: String = p.equip_gear(String(id))
		check(err == "", "надето %s %s" % [id, err])
	var gb: Dictionary = game.gear_bonus()
	check(int(gb["def"]) == 25 and int(gb["mdef"]) == 4, "комплект воина 1-го ранга: физ. +%d, маг. +%d" % [int(gb["def"]), int(gb["mdef"])])
	check(p.defense - d0 >= 25, "физ. защита %d → %d" % [d0, p.defense])
	check(p.mdef - m0 == 4, "маг. защита %d → %d" % [m0, p.mdef])
	check(p.max_hp - hp0 >= 30, "HP %d → %d (кольцо жизни +30)" % [hp0, p.max_hp])
	check(p.max_mp - mp0 >= 20, "MP %d → %d (кулон маны +20)" % [mp0, p.max_mp])
	check(is_equal_approx(p.crit_mult, Player.CRIT_MULT + 0.1), "сила крита ×%.2f (кольцо сокрушения +10%%)" % p.crit_mult)
	check(is_equal_approx(p.cast_speed - cs0, 0.05), "скорость каста +5%%: %.2f → %.2f" % [cs0, p.cast_speed])
	check(p.speed > s0 * 1.03, "скорость бега %.2f → %.2f (пояс +4%%)" % [s0, p.speed])
	check(is_equal_approx(p.aspd, a0) and is_equal_approx(p.crit, c0), "крит и скорость атаки без таких украшений — те же")
	# Шанс крита, скорость атаки, уклонение
	p.unequip_gear("ring1")
	p.unequip_gear("earring")
	p.unequip_gear("belt")
	for id in ["ring_crit_r1", "earring_aspd_r1", "belt_eva_r1"]:
		if not inv.has(String(id), 1):
			inv.add(String(id))
		check(String(p.equip_gear(String(id))) == "", "надето %s" % id)
	check(is_equal_approx(p.crit - c0, 0.02), "шанс крита +2%%: %.3f → %.3f" % [c0, p.crit])
	check(is_equal_approx(p.aspd - a0, 0.04), "скорость атаки +4%%: %.2f → %.2f" % [a0, p.aspd])
	check(is_equal_approx(p.eva - e0, 0.02) or p.eva >= 0.6, "уклонение +2%%: %.3f → %.3f" % [e0, p.eva])
	var prof := Combat.profile_of(p)
	check(is_equal_approx(float(prof["crit_mult"]), p.crit_mult) and int(prof["def"]) >= d0 + 25, "профиль боя видит экипировку")
	print("  ГЕРОЙ 15 ур. Воин: защита %d → %d, маг. %d → %d, HP %d → %d, MP %d → %d" % [d0, p.defense, m0, p.mdef, hp0,
		p.max_hp, mp0, p.max_mp])


# ---------- Сохранение, профессия ----------

func _save_load() -> void:
	var d: Dictionary = game.to_dict()
	check(d.has("equip") and (d["equip"] as Dictionary).size() == 9, "в сохранении — ключ equip: %s" % [d.get("equip")])
	var before: Dictionary = (game.equip as Dictionary).duplicate()
	var used: int = game.inventory.used_cells()
	game.from_dict(JSON.parse_string(JSON.stringify(d)))
	check(game.equip == before, "после загрузки надето то же: %s" % [game.equip])
	check(game.inventory.used_cells() == used and game.inventory.find_cell("armor_body_warrior_r1") == -1,
		"надетое по-прежнему не в ячейках (занято %d)" % game.inventory.used_cells())
	main.player.recalc_stats()
	check(int(game.gear_bonus()["def"]) == 25, "бонусы после загрузки")
	# Испорченная запись: чужая ячейка, вещи нет в сумке, не та ячейка
	var bad := d.duplicate(true)
	bad["equip"] = {"head": "ring_hp_r1", "bogus": "armor_helmet_r1", "belt": "belt_pdef_r2", "body": "armor_body_warrior_r1"}
	game.from_dict(JSON.parse_string(JSON.stringify(bad)))
	check(game.equip == {"body": "armor_body_warrior_r1"}, "лишнее из сохранения снято: %s" % [game.equip])
	# Старое сохранение — без equip
	var old := d.duplicate(true)
	old.erase("equip")
	game.from_dict(JSON.parse_string(JSON.stringify(old)))
	check(game.equip.is_empty() and game.inventory.has("armor_body_warrior_r1"), "старое сохранение: ничего не надето, вещи в сумке")
	game.from_dict({"version": 1, "name": "Ветеран", "race": "dark_elf", "class": "assassin", "level": 5})
	check(game.equip.is_empty() and game.class_id == "assassin", "сохранение версии 1 загружается, экипировки нет")
	# Вернуть героя теста
	game.from_dict(JSON.parse_string(JSON.stringify(d)))
	main.player.apply_class()


func _job_change() -> void:
	var inv: Inventory = game.inventory
	game.admin_set_job(ClassData.WANDERER)
	main.player.apply_class()
	inv.add("armor_body_mage_r1")
	check(String(game.equip_gear("armor_body_mage_r1")) == "", "Бродяге — доспех мага")
	check(game.gear_in("head") == "armor_helmet_r1", "шлем на месте")
	game.admin_set_job("warrior")
	main.player.apply_class()
	check(game.gear_in("body") == "" and inv.has("armor_body_mage_r1") and inv.find_cell("armor_body_mage_r1") >= 0,
		"смена профессии: доспех мага снят, лежит в сумке")
	check(game.gear_in("head") == "armor_helmet_r1" and game.gear_in("ring1") != "", "шлем и кольцо остались")
	check(String(game.equip_gear("armor_body_warrior_r1")) == "", "доспех воина снова надет")
	main.player.recalc_stats()


# ---------- Окна ----------

func _bag_window() -> void:
	var inv: Inventory = game.inventory
	var win: InventoryWindow = main.economy.window
	main.economy.open_bag()
	for e in InventoryWindow.EQUIP_SLOTS:
		check(win.buttons.has("equip_" + String(e[0])), "ячейка экипировки «%s»" % String(e[1]))
	check(InventoryWindow.EQUIP_SLOTS.size() == 11, "в сумке 11 ячеек экипировки (оружие, 2-я рука и 9 брони и украшений)")
	# Надетое — касание ячейки «Тело»: карточка и «Снять»
	_press("equip_body")
	check(win.sel_kind == "equip" and _card_title() == ItemData.item_name("armor_body_warrior_r1"), "карточка надетого доспеха")
	check(win.buttons.has("act_unequip"), "кнопка «Снять»")
	_press("act_unequip")
	check(game.gear_in("body") == "" and inv.find_cell("armor_body_warrior_r1") >= 0, "«Снять»: доспех в сумке")
	# Из сумки: «Надеть»
	_press("cell_%d" % inv.find_cell("armor_body_warrior_r1"))
	check(win.buttons.has("act_equip") and not (win.buttons["act_equip"] as Button).disabled, "«Надеть» у доспеха воина")
	check(_has_text_containing("Физ. защита") and _has_text_containing("Маг. защита"), "в карточке — защиты")
	_press("act_equip")
	check(game.gear_in("body") == "armor_body_warrior_r1" and win.sel_kind == "equip", "надето из карточки, выбран слот")
	# Чужой доспех — «Надеть» выключена, причина в карточке
	_press("cell_%d" % inv.find_cell("armor_body_mage_r1"))
	check((win.buttons["act_equip"] as Button).disabled and _has_text_containing("Не подходит вашей профессии"),
		"доспех мага Воину: «Надеть» выключена, «Не подходит»")
	check(_has_text_containing("разница с надетым"), "сравнение с надетым доспехом")
	# Шлем 2-го ранга: сравнение, на 15 ур. — нельзя
	_press("cell_%d" % inv.find_cell("armor_helmet_r2"))
	check((win.buttons["act_equip"] as Button).disabled and _has_text_containing("надеть можно с 21 уровня"),
		"шлем 2-го ранга: с 21 уровня")
	check(_has_text_containing("разница с надетым"), "шлем сравнивается с надетым")
	# Кольцо: «Во 2-е кольцо» и перетаскивание в ячейку
	game.unequip_gear("ring1")
	game.unequip_gear("ring2")
	main.player.recalc_stats()
	main.economy.open_bag()
	inv.add("ring_aspd_r1")
	_press("cell_%d" % inv.find_cell("ring_aspd_r1"))
	check(win.buttons.has("act_equip_ring2"), "у кольца — «Во 2-е кольцо»")
	_press("act_equip_ring2")
	check(game.gear_in("ring2") == "ring_aspd_r1" and game.gear_in("ring1") == "", "кольцо — во вторую ячейку")
	var rc := inv.find_cell("ring_hp_r1")
	var slot1: Button = win.buttons["equip_ring1"]
	var belt: Button = win.buttons["equip_belt"]
	check(slot1.call("_can_drop_data", Vector2.ZERO, {"inv_cell": rc}), "кольцо можно бросить в «Кольцо 1»")
	check(not belt.call("_can_drop_data", Vector2.ZERO, {"inv_cell": rc}), "кольцо в «Пояс» не бросить")
	check(not (win.buttons["equip_weapon"] as Button).call("_can_drop_data", Vector2.ZERO, {"inv_cell": rc}), "кольцо в «Оружие» не бросить")
	slot1.call("_drop_data", Vector2.ZERO, {"inv_cell": rc})
	check(game.gear_in("ring1") == "ring_hp_r1", "кольцо жизни надето перетаскиванием")
	# Замена перетаскиванием: прежняя вещь — в ту же ячейку сумки
	inv.add("belt_pdef_r1")
	main.economy.open_bag()
	var bc := inv.find_cell("belt_pdef_r1")
	var old_belt: String = game.gear_in("belt")
	(win.buttons["equip_belt"] as Button).call("_drop_data", Vector2.ZERO, {"inv_cell": bc})
	check(game.gear_in("belt") == "belt_pdef_r1" and String(inv.cell(bc).get("id", "")) == old_belt,
		"пояс заменён, прежний (%s) — в той же ячейке" % old_belt)
	# Пустой слот — подсказка
	game.unequip_gear("earring")
	main.economy.open_bag()
	_press("equip_earring")
	check(_has_text_containing("серьги"), "пустая ячейка «Серьги» — подсказка")
	main.player.recalc_stats()


func _hero_window() -> void:
	main.hud.close_window()
	main.hero_window.open("hero")
	var hw: CharacterWindow = main.hero_window
	for e in ItemData.GEAR_SLOTS:
		check(hw.buttons.has("gear_" + String(e[0])), "окно героя: ячейка «%s»" % String(e[1]))
	var l := _find_live(main.hud._window, "gear_bonus_label") as Label
	check(l != null and l.text.contains("физ. защита +"), "окно героя: «От экипировки» — %s" % (l.text if l else "?"))
	check(_has_text_containing("Сила крита"), "окно героя: сила крита")
	(hw.buttons["gear_body"] as Button).pressed.emit()
	var win: InventoryWindow = main.economy.window
	check(main.economy.is_bag_open() and win.sel_kind == "equip" and String(InventoryWindow.EQUIP_SLOTS[win.sel_index][0]) == "body",
		"касание ячейки «Тело» — сумка с этой ячейкой")


func _storage() -> void:
	var st: Inventory = game.storage
	st.from_dict({})
	st.add("armor_helmet_r1", 2)
	st.add("ring_hp_r1", 1)
	check(st.used_cells() == 3, "на складе броня и украшения — по одному в ячейке (%d)" % st.used_cells())
	var eco: Economy = main.economy
	var inv: Inventory = game.inventory
	inv.add("armor_boots_r2")
	var c := inv.find_cell("armor_boots_r2")
	check(eco.deposit(c) == 1 and st.has("armor_boots_r2") and not inv.has("armor_boots_r2"), "сапоги 2-го ранга — на склад")
	check(inv.find_cell(String(game.gear_in("body"))) == -1, "надетый доспех на склад не положить: его нет в ячейках")
	st.from_dict({})


# ---------- Помощники окна ----------

func _press(node_name: String) -> void:
	var win: InventoryWindow = main.economy.window
	var b: Button = win.buttons.get(node_name)
	check(b != null, "кнопка %s есть в окне" % node_name)
	if b != null:
		b.pressed.emit()


func _card_title() -> String:
	if not main.hud.is_window_open():
		return ""
	var l := _find_live(main.hud._window, "card_title") as Label
	return l.text if l != null else ""


func _has_text_containing(part: String) -> bool:
	var res: Array = []
	if main.hud.is_window_open():
		_collect(main.hud._window, res)
	for t in res:
		if String(t).contains(part):
			return true
	return false


func _collect(n: Node, res: Array) -> void:
	if n.is_queued_for_deletion():
		return
	var l := n as Label
	if l != null:
		res.append(l.text)
	for c in n.get_children():
		_collect(c, res)


func _find_live(n: Node, node_name: String) -> Node:
	if n.name == node_name and not n.is_queued_for_deletion():
		return n
	for c in n.get_children():
		var r := _find_live(c, node_name)
		if r != null:
			return r
	return null
