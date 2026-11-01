extends "res://tests/test_base.gd"
## Добыча по правилам Максима (LootTable): число предметов по типу зверя (обычный 2, минибосс 3, босс 4, в подземелье
## +1), золото всегда и около цены материала, ранг зелья и оружия по уровню зверя (1 / 12 / 25 / 35 ур.), карты —
## только приручаемых (и зеркальная), особые материалы — только с боссов, броня — у всех (как оружие), украшения —
## только у боссов, кубы чарования — у всех (вес 10 / 25 / 35, ранг по уровню зверя), статистика по 2000 убийствам (доли категорий — как веса), мешочек в мире (золото
## и предметы, крупный у босса). Случайные награды заданий (1–2 предмета, шансы вдвое ниже, ранг по уровню героя;
## броня — подходящая профессии, украшения — 7.5 %). Подробно броня и украшения — tests/test_equipment.gd.
## Золото на складе (Game.storage_gold, окно склада, сохранение).

## Допуск доли категории в статистике (4000–8000 бросков: стандартная ошибка ≈ 0.8 %).
const SHARE_TOL := 0.03
const STAT_KILLS := 2000

var drops_before: Array = []
var killed: Array = []


func race_class() -> Array:
	return ["light_elf", "wanderer"]


func run_step() -> void:
	var player: Player = main.player
	match step:
		0:
			_unit_counts()
			_unit_gold()
			_unit_ranks()
			_unit_cards_special()
			_unit_stats("wolf", 5)
			_unit_stats("boss_panther", 24)
			_unit_stats("centaur", 15)
			_unit_quest_rewards()
			step = 1
		1:
			# В мире: обычный зверь, минибосс и босс в 12 м от героя — мешочки с золотом и 2 / 3 / 4 предметами
			for e in [["pheasant", 2], ["centaur", 14], ["boss_wolf", 18]]:
				var off := Vector3(12.0 + 3.0 * float(killed.size()), 0.0, 6.0)
				var pos: Vector3 = player.global_position + off
				if IslandWorld.current != null:
					pos.y = IslandWorld.current.height_at(pos.x, pos.z)
				var m: Mob = main.spawn_mob(String(e[0]), int(e[1]), pos)
				killed.append([String(e[0]), pos])
				m.take_damage(m.hp + 5, player)
				check(m.is_dead, "%s убит" % String(e[0]))
			wait = 2
			step = 2
		2:
			for e in killed:
				var tid := String((e as Array)[0])
				var pos: Vector3 = (e as Array)[1]
				var d := _drop_near(pos)
				check(d != null, "мешочек с %s" % tid)
				if d == null:
					continue
				var n := 0
				for k in d.items:
					n += int(d.items[k])
				check(n == LootTable.item_count(tid), "%s: %d предмета (%s)" % [tid, n, LootDrop.describe(d.items, d.gold)])
				var gr: Array = MobData.gold_range(tid, int(MobData.get_type(tid)["level"]))
				check(d.gold > 0 and d.gold >= int(gr[0]) and d.gold <= int(gr[1]),
					"%s: золото есть всегда, ± цена материала: %d (%d–%d)" % [tid, d.gold, int(gr[0]), int(gr[1])])
				# Подбор: золото — в кошелёк, предметы — в сумку
				var g0: int = game.gold
				var got_gold := d.gold
				check(d.pick_up(), "мешочек %s подобран" % tid)
				check(game.gold == g0 + got_gold, "золото из мешочка %s: %d → %d" % [tid, g0, game.gold])
			_check_storage_gold()
			wait = 3
			step = 3
		3:
			ok_done()


# ---------- Число предметов ----------

func _unit_counts() -> void:
	check(LootTable.item_count("wolf") == 2 and LootTable.item_count("pheasant") == 2, "обычный зверь — 2 предмета")
	for id in ["centaur", "anathema_chief", "flyfish_drake"]:
		check(MobData.is_mini_boss(id) and not MobData.is_boss(id), "%s — минибосс («Редкий»)" % id)
		check(LootTable.item_count(id) == 3, "минибосс %s — 3 предмета" % id)
	for id in ["wolf", "panther", "anathema", "flyfish", "boss_wolf"]:
		check(not MobData.is_mini_boss(id), "%s — не минибосс" % id)
	check(MobData.is_boss("boss_panther") and LootTable.item_count("boss_panther") == 4, "босс — 4 предмета")
	check(LootTable.item_count("wolf", true) == 3 and LootTable.item_count("centaur", true) == 4
		and LootTable.item_count("boss_panther", true) == 5, "в подземелье на один больше: 3 / 4 / 5")
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for k in MobData.TYPES:
		var id := String(k)
		var lvl := int(MobData.get_type(id)["level"])
		for dungeon in [false, true]:
			var loot := LootTable.roll(id, lvl, bool(dungeon), rng)
			var n := 0
			for it in loot:
				n += int(loot[it])
				check(not ItemData.get_item(String(it)).is_empty(), "%s: предмет добычи есть: %s" % [id, it])
			check(n == LootTable.item_count(id, bool(dungeon)), "%s%s: выпало %d предметов" % [id, " (подземелье)" if dungeon else "", n])


# ---------- Золото ----------

func _unit_gold() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in MobData.TYPES:
		var id := String(k)
		var lvl := int(MobData.get_type(id)["level"])
		var gr: Array = MobData.gold_range(id, lvl)
		var mats := MobData.special_materials(id) if MobData.is_boss(id) else MobData.materials(id)
		check(not mats.is_empty(), "%s: есть материал" % id)
		var price := 0.0
		for m in mats:
			price += float(ItemData.get_item(String(m))["sell"])
		price /= maxf(1.0, float(mats.size()))
		price *= MobData.GOLD_MULT
		# На базовом уровне вида золото ≈ цене материала: ±20 %
		check(int(gr[0]) >= 1 and float(gr[0]) <= price * 0.8 + 1.0 and float(gr[1]) >= price * 1.2 - 1.0
			and float(gr[1]) <= price * 1.2 + 1.0, "%s: золото %d–%d при цене материала %.0f" % [id, int(gr[0]), int(gr[1]), price])
		for i in 20:
			var g := LootTable.gold(id, lvl, rng)
			check(g >= int(gr[0]) and g <= int(gr[1]), "%s: золото %d в пределах %d–%d" % [id, g, int(gr[0]), int(gr[1])])
	# С уровнем — немного больше, но не больше чем в 1.5 раза
	var lo: Array = MobData.gold_range("wolf", 3)
	var hi: Array = MobData.gold_range("wolf", 30)
	check(int(hi[1]) > int(lo[1]) and float(hi[1]) <= float(lo[1]) * 1.5 + MobData.GOLD_MULT, "золото волка растёт с уровнем мягко: %s → %s" % [lo, hi])


# ---------- Ранги ----------

func _unit_ranks() -> void:
	var want_p := {1: 1, 12: 2, 25: 3, 35: 4}
	var want_w := {1: 1, 12: 1, 25: 2, 35: 2}
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for l in want_p:
		var lvl := int(l)
		check(ItemData.potion_rank_for_level(lvl) == int(want_p[l]), "зелье для %d ур. — %d-го ранга" % [lvl, int(want_p[l])])
		check(ItemData.equip_rank_for_level(lvl) == int(want_w[l]), "оружие для %d ур. — %d-го ранга" % [lvl, int(want_w[l])])
		var potions := 0
		var weapons := 0
		for i in 400:
			var loot := LootTable.roll("wolf", lvl, false, rng)
			for k in loot:
				var it := String(k)
				if ItemData.is_potion(it):
					potions += 1
					check(ItemData.rank(it) == int(want_p[l]), "%d ур.: зелье %s — %d-го ранга" % [lvl, it, int(want_p[l])])
				elif ItemData.is_weapon(it):
					weapons += 1
					check(ItemData.rank(it) == int(want_w[l]), "%d ур.: оружие %s — %d-го ранга" % [lvl, it, int(want_w[l])])
					check(ItemData.rarity(it) == "common", "из зверей — обычное оружие: %s" % it)
		check(potions > 50 and weapons > 20, "%d ур.: зелий %d, оружия %d за 400 зверей" % [lvl, potions, weapons])
	# Все 13 видов оружия 2-го ранга есть; 3-го ранга пока нет — выпадает старший имеющийся (2-й)
	var r2 := LootTable.weapons_of_rank(2)
	check(r2.size() == 13, "оружия 2-го ранга — 13 видов: %d" % r2.size())
	for id in r2:
		check(String(ItemData.get_item(String(id)).get("model", "")) == String(id), "%s: модель weapon_<вид>_r2" % id)
		check(ItemData.required_level(String(id)) == 21, "%s: надеть с 21 ур." % id)
	var r3 := LootTable.weapons_of_rank(3)
	check(not r3.is_empty() and ItemData.rank(String(r3[0])) == 2, "3-го ранга нет — выпадает 2-й")
	check(ItemData.rank_level_range(1) == [1, 20] and ItemData.rank_level_range(2) == [21, 50]
		and ItemData.rank_level_range(3) == [51, 80] and ItemData.rank_level_range(6) == [141, 150], "таблица рангов снаряжения")


# ---------- Карты и особые материалы ----------

func _unit_cards_special() -> void:
	for k in MobData.TYPES:
		var id := String(k)
		var cats := LootTable.categories_for(id, int(MobData.get_type(id)["level"]))
		for e in LootTable.pool("card", id, 10):
			var it := String((e as Array)[0])
			var sp := ItemData.card_species(it)
			check(sp == "" or MobData.tameable(sp), "%s: карта только приручаемого вида: %s" % [id, it])
			if sp == "":
				check(MobData.drops_mirror(id), "%s: зеркальная карта — у тех, кто её роняет" % id)
		if MobData.tameable(id):
			check(cats.has("card") and is_equal_approx(float(cats["card"]), float(Taming.CHANCE[MobData.card_tier(id)])),
				"%s: шанс карты = шанс приручения (%.0f%%)" % [id, float(cats.get("card", 0.0)) * 100.0])
		elif not MobData.drops_mirror(id):
			check(not cats.has("card"), "%s не приручается — карт нет" % id)
		check(cats.has("special") == MobData.is_boss(id), "%s: особые материалы — только у боссов" % id)
		check(is_equal_approx(float(cats.get("armor", 0.0)), 0.25), "%s: броня — как оружие, 25" % id)
		check(cats.has("jewelry") == MobData.is_boss(id), "%s: украшения — только у боссов" % id)
		var cw := 0.35 if MobData.is_boss(id) else (0.25 if MobData.is_mini_boss(id) else 0.10)
		check(is_equal_approx(float(cats.get("cube", 0.0)), cw), "%s: кубы — вес %.2f" % [id, cw])
		for e in LootTable.pool("cube", id, 10):
			check(ItemData.is_cube(String((e as Array)[0])) and ItemData.rank(String((e as Array)[0])) == 1,
				"%s 10 ур.: куб 1-го ранга (%s)" % [id, (e as Array)[0]])
		for e in LootTable.pool("cube", id, 25):
			check(ItemData.rank(String((e as Array)[0])) == 2, "%s 25 ур.: куб 2-го ранга (%s)" % [id, (e as Array)[0]])
		check(is_equal_approx(float(cats.get("potion", 0.0)), 0.75) and is_equal_approx(float(cats.get("weapon", 0.0)), 0.25)
			and is_equal_approx(float(cats.get("material", 0.0)), 0.25), "%s: зелья 75, оружие 25, материалы 25" % id)
	check(is_equal_approx(LootTable.category_chance("special", "boss_wolf"), 0.10), "особый материал босса — 10")
	check(is_equal_approx(LootTable.category_chance("jewelry", "boss_wolf"), 0.15) and LootTable.category_chance("jewelry", "wolf") == 0.0,
		"украшения — 15, только боссы")
	check(is_equal_approx(LootTable.category_chance("cube", "wolf"), 0.10) and is_equal_approx(LootTable.category_chance("cube", "centaur"), 0.25)
		and is_equal_approx(LootTable.category_chance("cube", "boss_wolf"), 0.35), "кубы: 10 / 25 / 35")
	check(is_equal_approx(LootTable.category_chance("armor", "wolf"), 0.25), "броня — как оружие, 25")


## 2000 убийств зверя type_id уровня lvl: доли категорий — как веса категорий (среди доступных).
func _unit_stats(type_id: String, lvl: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var cats := LootTable.categories_for(type_id, lvl)
	var total_w := 0.0
	for k in cats:
		total_w += float(cats[k])
	var got: Dictionary = {}
	var total := 0
	for i in STAT_KILLS:
		var loot := LootTable.roll(type_id, lvl, false, rng)
		for k in loot:
			var c := LootTable.category_of(String(k), type_id)
			got[c] = int(got.get(c, 0)) + int(loot[k])
			total += int(loot[k])
	check(total == STAT_KILLS * LootTable.item_count(type_id), "%s: %d предметов за %d убийств" % [type_id, total, STAT_KILLS])
	var parts: PackedStringArray = []
	for k in cats:
		var want := float(cats[k]) / total_w
		var share := float(got.get(k, 0)) / float(maxi(1, total))
		parts.append("%s %.1f%% (вес %.1f%%)" % [k, share * 100.0, want * 100.0])
		check(absf(share - want) < SHARE_TOL, "%s: доля «%s» %.3f ≈ %.3f" % [type_id, k, share, want])
	for k in got:
		check(cats.has(k), "%s: выпала только доступная категория (%s)" % [type_id, k])
	print("  ДОБЫЧА %s %d ур.: %s" % [type_id, lvl, ", ".join(parts)])


# ---------- Награды заданий ----------

func _unit_quest_rewards() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for lvl in [1, 12, 25]:
		var ch := LootTable.quest_chances(lvl, "swordsman", rng)
		check(is_equal_approx(float((ch["potion"] as Array)[0]), 0.375) and is_equal_approx(float((ch["weapon"] as Array)[0]), 0.125),
			"награды: шансы вдвое ниже добычи (зелья 37.5 %, оружие 12.5 %)")
		check(ch.has("cube") and is_equal_approx(float((ch["cube"] as Array)[0]), 0.05), "награды: куб 5 % (вдвое ниже 10 %)")
		var card: Array = ch["card"]
		var card_id := String(((card[1] as Array)[0] as Array)[0])
		check(is_equal_approx(float(card[0]), float(Taming.CHANCE[ItemData.card_tier(card_id)]) * 0.5),
			"карта в награде — половина шанса приручения (%s)" % card_id)
		var per_cat: Dictionary = {}
		var n_items := 0
		for i in 600:
			var r := LootTable.quest_reward(lvl, "swordsman", rng)
			var n := 0
			for k in r:
				var it := String(k)
				n += int(r[k])
				var c := LootTable.category_of(it)
				per_cat[c] = int(per_cat.get(c, 0)) + int(r[k])
				check(c == "potion" or c == "weapon" or c == "card" or c == "armor" or c == "jewelry" or c == "cube",
					"награда: зелье, оружие, броня, украшение, карта или куб (%s)" % it)
				if ItemData.is_cube(it):
					check(ItemData.rank(it) == ItemData.cube_rank_for_level(lvl), "%d ур.: куб награды %s" % [lvl, it])
				if ItemData.is_gear(it):
					check(ItemData.rank(it) == ItemData.equip_rank_for_level(lvl) and ItemData.armor_fits(it, "swordsman"),
						"%d ур.: броня или украшение награды по рангу и профессии: %s" % [lvl, it])
				if ItemData.is_potion(it):
					check(ItemData.rank(it) == ItemData.potion_rank_for_level(lvl), "%d ур.: зелье награды %s" % [lvl, it])
				if ItemData.is_weapon(it):
					check(ItemData.rank(it) == ItemData.equip_rank_for_level(lvl) and ItemData.weapon_fits(it, "swordsman"),
						"%d ур.: оружие награды по рангу и профессии: %s" % [lvl, it])
			check(n >= 1 and n <= 2, "%d ур.: случайных предметов %d (1–2)" % [lvl, n])
			n_items += n
		check(int(per_cat.get("potion", 0)) > int(per_cat.get("weapon", 0)), "в наградах зелий больше, чем оружия: %s" % [per_cat])
		print("  НАГРАДЫ %d ур.: %s, в среднем %.2f предмета" % [lvl, per_cat, float(n_items) / 600.0])


# ---------- Склад: золото ----------

func _check_storage_gold() -> void:
	var eco: Economy = main.economy
	var p: Player = main.player
	var n: Npc = main.npcs.npc(Economy.STORAGE_NPC)
	check(n != null, "кладовщик в мире")
	if n == null:
		return
	var pos := n.global_position + Vector3(-sin(n.face_yaw), 0, -cos(n.face_yaw)) * 2.0
	if IslandWorld.current != null:
		pos.y = IslandWorld.current.height_at(pos.x, pos.z) + 0.1
	p.global_position = pos
	game.gold = 2500
	game.storage_gold = 0
	eco.open_storage()
	var win: InventoryWindow = eco.window
	check(eco.is_storage_open(), "окно склада открыто")
	var lab := main.hud._window.find_child("store_gold_label", true, false) as Label
	check(lab != null and lab.text == "На складе: 0 зол.", "на складе 0 зол.: %s" % (lab.text if lab else "?"))
	for b in ["gold_put", "gold_take", "gold_put_100", "gold_put_1000", "gold_put_all", "gold_take_100", "gold_take_1000",
			"gold_take_all"]:
		check(win.buttons.has(b), "кнопка склада золота: %s" % b)
	check(win.gold_edit != null, "поле суммы золота")
	(win.buttons["gold_put_100"] as Button).pressed.emit()
	check(game.gold == 2400 and game.storage_gold == 100, "+100 на склад")
	(win.buttons["gold_put_1000"] as Button).pressed.emit()
	check(game.gold == 1400 and game.storage_gold == 1100, "+1000 на склад")
	win.gold_edit.text = "250"
	(win.buttons["gold_put"] as Button).pressed.emit()
	check(game.gold == 1150 and game.storage_gold == 1350, "сумма из поля — на склад")
	lab = main.hud._window.find_child("store_gold_label", true, false) as Label
	check(lab != null and lab.text == "На складе: 1350 зол.", "надпись обновилась: %s" % (lab.text if lab else "?"))
	win.gold_edit.text = "abc"
	(win.buttons["gold_take"] as Button).pressed.emit()
	check(game.gold == 1150 and game.storage_gold == 1350, "не число — ничего не изменилось")
	win.gold_edit.text = "50"
	(win.buttons["gold_take"] as Button).pressed.emit()
	check(game.gold == 1200 and game.storage_gold == 1300, "забрано 50 из поля")
	(win.buttons["gold_take_1000"] as Button).pressed.emit()
	check(game.gold == 2200 and game.storage_gold == 300, "забрано 1000")
	(win.buttons["gold_put_all"] as Button).pressed.emit()
	check(game.gold == 0 and game.storage_gold == 2500, "всё золото на склад")
	check(eco.deposit_gold(10) == 0 and game.storage_gold == 2500, "без золота класть нечего")
	(win.buttons["gold_take_all"] as Button).pressed.emit()
	check(game.gold == 2500 and game.storage_gold == 0, "всё золото со склада")
	check(eco.withdraw_gold(1) == 0, "пустой склад — забрать нечего")
	check(eco.deposit_gold(5000) == 2500 and game.storage_gold == 2500 and game.gold == 0, "положить больше, чем есть, — сколько есть")
	# Сохранение
	var d: Dictionary = game.to_dict()
	check(int(d.get("storage_gold", -1)) == 2500, "золото склада в сохранении")
	game.storage_gold = 0
	game.from_dict(JSON.parse_string(JSON.stringify(d)))
	check(game.storage_gold == 2500, "после загрузки на складе 2500 зол.")
	game.from_dict({"version": 2, "name": "Старый", "race": "human", "class": "wanderer", "level": 3})
	check(game.storage_gold == 0, "старое сохранение — на складе 0 зол.")
	main.hud.close_window()


## Мешочек добычи ближе 1.5 м к точке pos.
func _drop_near(pos: Vector3) -> LootDrop:
	for nd in get_tree().get_nodes_in_group("loot_drops"):
		var d := nd as LootDrop
		if d == null or d.is_queued_for_deletion():
			continue
		var v := d.global_position - pos
		v.y = 0.0
		if v.length() < 1.5:
			return d
	return null
