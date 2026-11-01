extends "res://tests/test_base.gd"
## Чарование кубами и закалка у кузнеца (этап 3, Enchant; ItemData — раздел «Чарование, закалка, кубы»):
## представление «<id>+N» и «<id>!broken», прибавки заточки, шансы по уровню (статистика с фиксированным rng),
## расход куба в любом случае, поломка при неудаче, пределы (оружие 1-го ранга +10, 2-го +20, броня и щит +10, ранг
## куба не ниже ранга вещи, вид куба), закалка (цены по рангам, 100 %, до +10, нет золота — отказ), надетая вещь
## остаётся надетой (характеристики героя растут), сломанная снимается и не надевается, сохранение и загрузка
## заточенных и сломанных (сумка, надетое, склад), продажа лома, кубы в добыче (вес 10 / 25 / 35, доля за убийство)
## и в наградах заданий. Окна: панель «Крафт» в сумке (ячейки, перетаскивание, «В крафт», подтверждение, итог),
## кузница («Закалка» в диалоге кузнеца, «Закалить», серая кнопка без золота, окно закрывается, если отойти).

## Попыток чарования на каждую полосу шансов.
const STAT_TRIES := 1000
## Убийств на статистику кубов в добыче.
const LOOT_KILLS := 2000

var _band := 0
var _rng := RandomNumberGenerator.new()


func race_class() -> Array:
	return ["light_elf", "swordsman"]


func hero_level() -> int:
	return 25


func run_step() -> void:
	var p: Player = main.player
	match step:
		0:
			_rng.seed = 20261101
			_unit_ids()
			_unit_values()
			_unit_limits()
			_unit_temper_prices()
			_unit_loot()
			_band = 0
			step = 1
		1:
			# Шансы по полосам: по одной полосе за кадр (каждая попытка меняет сумку)
			var bands: Array = [[1, 0.5], [5, 0.25], [11, 0.125], [16, 0.0625]]
			if _band >= bands.size():
				step = 2
				return
			var b: Array = bands[_band]
			_stat_band(int(b[0]), float(b[1]))
			_band += 1
		2:
			_check_equipped(p)
			_check_admin()
			_check_temper(p)
			_check_save_load()
			step = 3
		3:
			_check_break_equipped(p)
			step = 4
		4:
			# Панель «Крафт» в сумке
			_check_craft_ui(p)
			wait = 3
			step = 5
		5:
			# Кузница: к кузнецу, «Закалка» в диалоге
			main.hud.close_window()
			_stand_by(Enchant.SMITH_NPC, 1.8)
			wait = 4
			step = 6
		6:
			_check_forge_ui()
			# Отойти — окно закрывается
			p.global_position += Vector3(14.0, 0.0, 0.0)
			if IslandWorld.current != null:
				p.global_position.y = IslandWorld.current.height_at(p.global_position.x, p.global_position.z) + 0.1
			wait = 4
			step = 7
		7:
			check(not main.economy.is_forge_open(), "отошли от кузнеца — окно кузницы закрыто")
			# Продажа лома у торговца
			p.global_position = Vector3(0, 0.1, -1.5)
			if IslandWorld.current != null:
				p.global_position.y = IslandWorld.current.height_at(0.0, -1.5) + 0.1
			wait = 3
			step = 8
		8:
			_check_sell_broken()
			ok_done()


# ---------- Представление ----------

func _unit_ids() -> void:
	var s := "weapon_sword_1h_r1"
	var e3 := ItemData.enchanted_id(s, 3)
	var br := ItemData.broken_id(e3)
	check(e3 == "weapon_sword_1h_r1+3" and ItemData.base_id(e3) == s and ItemData.enchant_level(e3) == 3, "id заточки: %s" % e3)
	check(br == "weapon_sword_1h_r1!broken" and ItemData.base_id(br) == s and ItemData.enchant_level(br) == 0
		and ItemData.is_broken(br), "сломанная — без заточки: %s" % br)
	check(ItemData.enchanted_id(e3, 0) == s and ItemData.enchant_level(s) == 0, "заточка 0 — базовый id (старые сохранения)")
	check(ItemData.item_name(e3) == "Учебный меч +3" and ItemData.is_weapon(e3) and ItemData.rank(e3) == 1
		and ItemData.weapon_kind(e3) == "sword_1h", "запись заточенной вещи: «%s»" % ItemData.item_name(e3))
	check(ItemData.icon_path(e3).ends_with("weapon_sword_1h_r1.png"), "значок — базовой вещи: %s" % ItemData.icon_path(e3))
	check(ItemData.icon_path(br).ends_with("broken_weapon.png") and ItemData.icon_path(ItemData.broken_id("armor_helmet_r1")).ends_with("broken_armor.png")
		and ItemData.icon_path(ItemData.broken_id("weapon_shield_r1")).ends_with("broken_armor.png"), "значки лома: оружие / броня и щит")
	check(ItemData.item_type(br) == "broken" and not ItemData.is_weapon(br) and not ItemData.is_equipment(br),
		"сломанная — лом, не снаряжение")
	for bad in ["weapon_sword_1h_r1+0", "ring_hp_r1+2", "nope+3", "potion_hp_r1+1", "ring_hp_r1!broken", "weapon_sword_1h_r1+x"]:
		check(ItemData.get_item(String(bad)).is_empty(), "нет такой вещи: %s" % bad)
	check(ItemData.get_item("weapon_sword_1h_r1+21").is_empty(), "заточки больше +20 нет")
	# Кубы
	for k in ["attack", "defense"]:
		for r in [1, 2]:
			var cid := ItemData.cube_id(String(k), int(r))
			check(ItemData.is_cube(cid) and ItemData.cube_kind(cid) == String(k) and ItemData.rank(cid) == int(r)
				and ItemData.icon_path(cid).ends_with(cid + ".png") and ItemData.stack_size(cid) == 99,
				"куб %s: «%s»" % [cid, ItemData.item_name(cid)])
	check(ItemData.cube_rank_for_level(1) == 1 and ItemData.cube_rank_for_level(20) == 1 and ItemData.cube_rank_for_level(21) == 2
		and ItemData.cube_rank_for_level(80) == 2, "ранг куба по уровню: 1–20 — 1-й, 21+ — 2-й")
	check(ItemData.enchant_kind("weapon_sword_1h_r1") == "attack" and ItemData.enchant_kind("weapon_shield_r1") == "defense"
		and ItemData.enchant_kind("armor_body_warrior_r1") == "defense" and ItemData.enchant_kind("ring_hp_r1") == ""
		and ItemData.enchant_kind(br) == "", "чем точится: оружие — атака, броня и щит — защита, украшения — нет")


func _unit_values() -> void:
	check(ItemData.ENCHANT_PCT.size() == ItemData.ENCHANT_MAX + 1, "таблица прибавок до +20")
	check(roundi(ItemData.enchant_pct(10) * 100.0) == 100 and roundi(ItemData.enchant_pct(15) * 100.0) == 175
		and roundi(ItemData.enchant_pct(20) * 100.0) == 275, "+10 — +100 %, +15 — +175 %, +20 — +275 %")
	for n in range(1, ItemData.ENCHANT_MAX + 1):
		check(ItemData.ENCHANT_PCT[n] > ItemData.ENCHANT_PCT[n - 1], "прибавка растёт: +%d" % n)
	check(ItemData.enchant_value(4, 10) == 8 and ItemData.enchant_value(3, 1) == 4 and ItemData.enchant_value(16, 10) == 32
		and ItemData.enchant_value(13, 20) == 49 and ItemData.enchant_value(0, 5) == 0, "числа заточки")
	var wb0 := ItemData.weapon_bonus("weapon_sword_1h_r2")
	var wb := ItemData.weapon_bonus("weapon_sword_1h_r2+20")
	check(int(wb["atk"]) == ItemData.enchant_value(int(wb0["atk"]), 20) and int(wb["aspd"]) == int(wb0["aspd"]),
		"оружие +20: атака %d → %d, скорость та же" % [int(wb0["atk"]), int(wb["atk"])])
	var gb0 := ItemData.gear_bonus("armor_body_mage_r1")
	var gb := ItemData.gear_bonus("armor_body_mage_r1+10")
	check(roundi(float(gb["mdef"])) == ItemData.enchant_value(roundi(float(gb0["mdef"])), 10)
		and roundi(float(gb["def"])) == ItemData.enchant_value(roundi(float(gb0["def"])), 10), "доспех мага +10: защиты вдвое")
	check(ItemData.gear_slots_for("armor_helmet_r1+4") == ["head"] and ItemData.armor_fits("armor_body_mage_r1+3", "wizard")
		and not ItemData.armor_fits("armor_body_mage_r1+3", "swordsman"), "заточенная броня — та же ячейка и кому подходит")
	check(int(ItemData.get_item("weapon_sword_1h_r1+5")["sell"]) > int(ItemData.get_item("weapon_sword_1h_r1")["sell"])
		and int(ItemData.get_item("weapon_sword_1h_r1+5")["sell"]) < Enchant.temper_price_at(1, 1),
		"заточенное продаётся дороже, но много дешевле закалки")
	check(ItemData.enchant_text("weapon_sword_1h_r1+10").contains("4 → 8"), "строка заточки: %s" % ItemData.enchant_text("weapon_sword_1h_r1+10"))
	var lines: PackedStringArray = []
	for n in [1, 5, 10, 15, 20]:
		lines.append("+%d: меч 2-го ранга %d → %d, доспех воина 1-го ранга %d → %d" % [int(n), 13,
			ItemData.enchant_value(13, int(n)), 16, ItemData.enchant_value(16, mini(int(n), 10))])
	print("  ПРИБАВКА заточки: %s" % "; ".join(lines))


# ---------- Шансы ----------

## Полоса шансов: STAT_TRIES попыток с +(target − 1) на +target кубом атаки 2-го ранга по мечу 2-го ранга (предел +20).
func _stat_band(target: int, want: float) -> void:
	var inv: Inventory = game.inventory
	var base := "weapon_sword_1h_r2"
	var cube := ItemData.cube_id("attack", 2)
	var start := ItemData.enchanted_id(base, target - 1)
	check(is_equal_approx(Enchant.chance_for(target), want), "шанс +%d — %.2f%%" % [target, want * 100.0])
	var ok := 0
	var cubes_ok := true
	var broke_ok := true
	for i in STAT_TRIES:
		inv.add(start)
		inv.add(cube)
		var c0 := inv.count(cube)
		var r := Enchant.use_cube(start, cube, "", _rng)
		if String(r["error"]) != "":
			check(false, "попытка не прошла: %s" % r["error"])
			return
		if inv.count(cube) != c0 - 1:
			cubes_ok = false
		var res := String(r["item"])
		if bool(r["ok"]):
			ok += 1
			if res != ItemData.enchanted_id(base, target) or not inv.has(res):
				broke_ok = false
		elif not (bool(r["broke"]) and ItemData.is_broken(res) and inv.has(res) and ItemData.base_id(res) == base):
			broke_ok = false
		if inv.has(start):
			broke_ok = false
		inv.remove(res, inv.count(res))
		inv.remove(cube, inv.count(cube))
	var share := float(ok) / float(STAT_TRIES)
	var tol := maxf(0.02, 4.0 * sqrt(want * (1.0 - want) / float(STAT_TRIES)))
	check(cubes_ok, "+%d: куб тратится при любом исходе" % target)
	check(broke_ok, "+%d: удача — вещь +%d, неудача — лом (заточка потеряна), прежней вещи нет" % [target, target])
	check(absf(share - want) <= tol, "+%d: удалось %.1f%% (ждали %.2f%% ± %.1f%%)" % [target, share * 100.0, want * 100.0, tol * 100.0])
	print("  ШАНС +%d: %d из %d (%.1f%%, по таблице %.2f%%)" % [target, ok, STAT_TRIES, share * 100.0, want * 100.0])


# ---------- Пределы ----------

func _unit_limits() -> void:
	check(Enchant.cube_cap("weapon_sword_1h_r1") == 10 and Enchant.cube_cap("weapon_sword_1h_r2") == 20
		and Enchant.cube_cap("armor_body_warrior_r1") == 10 and Enchant.cube_cap("armor_body_warrior_r2") == 10
		and Enchant.cube_cap("weapon_shield_r2") == 10 and Enchant.cube_cap("ring_hp_r1") == 0,
		"пределы кубами: оружие 1-го ранга +10, 2-го +20, броня и щит +10, украшения — нет")
	var inv: Inventory = game.inventory
	for c in ["cube_attack_r1", "cube_attack_r2", "cube_defense_r1", "cube_defense_r2"]:
		inv.add(String(c), 1)
	check(Enchant.cube_block("weapon_sword_1h_r1", "cube_attack_r1") == "", "меч 1-го ранга + куб атаки I — можно")
	check(Enchant.cube_block("weapon_sword_1h_r1", "cube_attack_r2") == "", "куб старшего ранга чарует младшую вещь")
	check(Enchant.cube_block("weapon_sword_1h_r2", "cube_attack_r1").contains("2-го ранга"), "младший куб старшую вещь — нет: %s"
		% Enchant.cube_block("weapon_sword_1h_r2", "cube_attack_r1"))
	check(Enchant.cube_block("weapon_sword_1h_r1", "cube_defense_r1").contains("куб атаки"), "оружию — только куб атаки")
	check(Enchant.cube_block("armor_helmet_r1", "cube_attack_r1").contains("куб защиты"), "броне — только куб защиты")
	check(Enchant.cube_block("weapon_shield_r1", "cube_defense_r1") == "", "щит — кубом защиты")
	check(Enchant.cube_block("weapon_sword_1h_r1+10", "cube_attack_r2") != "", "меч 1-го ранга +10 — предел")
	check(Enchant.cube_block("weapon_sword_1h_r2+10", "cube_attack_r2") == "" and Enchant.cube_block("weapon_sword_1h_r2+19", "cube_attack_r2") == "",
		"меч 2-го ранга точится дальше +10 (до +20)")
	check(Enchant.cube_block("weapon_sword_1h_r2+20", "cube_attack_r2") != "", "+20 — предел оружия 2-го ранга")
	check(Enchant.cube_block("armor_body_warrior_r2+10", "cube_defense_r2").contains("предел брони"), "броня 2-го ранга — не больше +10")
	check(Enchant.cube_block("ring_hp_r1", "cube_defense_r1") != "" and Enchant.cube_block(ItemData.broken_id("weapon_sword_1h_r1"),
		"cube_attack_r1") != "", "украшения и лом не чаруются")
	var none := Enchant.use_cube("weapon_sword_1h_r1+10", "cube_attack_r2")
	check(String(none["error"]) != "" and inv.has("cube_attack_r2"), "отказ — куб цел: %s" % none["error"])
	for c in ["cube_attack_r1", "cube_attack_r2", "cube_defense_r1", "cube_defense_r2"]:
		inv.remove(String(c), inv.count(String(c)))


# ---------- Закалка ----------

func _unit_temper_prices() -> void:
	var want := {1: [300, 10000], 2: [20000, 100000], 3: [100000, 1000000]}
	for r in want:
		var rank_n := int(r)
		check(Enchant.temper_price_at(rank_n, 1) == int(want[r][0]) and Enchant.temper_price_at(rank_n, 10) == int(want[r][1]),
			"закалка %d-го ранга: +1 — %d, +10 — %d" % [rank_n, Enchant.temper_price_at(rank_n, 1), Enchant.temper_price_at(rank_n, 10)])
		var row: PackedStringArray = []
		var prev := 0
		var total := 0
		for t in range(1, Enchant.SMITH_MAX + 1):
			var pr := Enchant.temper_price_at(rank_n, t)
			check(pr > prev, "цена растёт: %d-й ранг +%d — %d" % [rank_n, t, pr])
			prev = pr
			total += pr
			row.append(str(pr))
		print("  ЗАКАЛКА %d-й ранг: %s (всего %d)" % [rank_n, ", ".join(row), total])
	check(Enchant.temper_price("weapon_sword_1h_r1+4") == Enchant.temper_price_at(1, 5), "цена — по следующему уровню")
	check(Enchant.temper_block("weapon_sword_1h_r2+10") != "" and Enchant.temper_block("weapon_sword_1h_r2+9") == ""
		and Enchant.temper_block("ring_hp_r1") != "", "кузнец — до +10, украшения не закаляет")


## Закалка вещи из сумки: 10 раз по 100 %, золото по ценам; дальше +10 — нельзя; без золота — отказ.
func _check_temper(p: Player) -> void:
	var inv: Inventory = game.inventory
	var item := "armor_helmet_r1"
	inv.add(item)
	game.gold = 100000
	var spent := 0
	for i in Enchant.SMITH_MAX:
		var price := Enchant.temper_price(item)
		var r := Enchant.temper(item, "", p)
		check(bool(r["ok"]) and int(r["price"]) == price, "закалка +%d за %d (всегда удачно)" % [i + 1, price])
		spent += price
		item = String(r["item"])
	check(item == "armor_helmet_r1+10" and inv.has(item) and not inv.has("armor_helmet_r1"), "шлем +10 в сумке")
	check(game.gold == 100000 - spent, "золото: потрачено %d" % spent)
	var more := Enchant.temper(item, "", p)
	check(not bool(more["ok"]) and String(more["error"]).contains("+10"), "дальше +10 кузнец не берётся: %s" % more["error"])
	inv.add("armor_boots_r1")
	game.gold = 10
	var poor := Enchant.temper("armor_boots_r1", "", p)
	check(not bool(poor["ok"]) and String(poor["error"]).contains("золота") and game.gold == 10 and inv.has("armor_boots_r1"),
		"без золота — отказ, ничего не изменилось")
	inv.remove(item)
	inv.remove("armor_boots_r1")


# ---------- Надетое ----------

## Надетые меч, щит и доспех точатся на месте: остаются надетыми, характеристики героя растут.
func _check_equipped(p: Player) -> void:
	check(game.weapon == "weapon_sword_1h_r1" and game.offhand == "weapon_shield_r1", "Мечник: меч и щит в руках")
	game.inventory.add("armor_body_warrior_r1")
	check(p.equip_gear("armor_body_warrior_r1") == "", "доспех воина надет")
	var atk0 := p.atk
	var def0 := p.defense
	var w := Enchant.admin_set("weapon", 10, p)
	check(w == "weapon_sword_1h_r1+10" and game.weapon == w and game.inventory.count(w) == 1
		and not game.inventory.has("weapon_sword_1h_r1"), "меч +10 — в руке: %s" % game.weapon)
	check(p.atk > atk0, "атака героя выросла: %d → %d" % [atk0, p.atk])
	var o := Enchant.admin_set("offhand", 5, p)
	check(game.offhand == o and o == "weapon_shield_r1+5" and p.defense > def0, "щит +5 — во второй руке, защита %d → %d" % [def0, p.defense])
	var def1 := p.defense
	game.gold = 100000
	var t := Enchant.temper("armor_body_warrior_r1", "body", p)
	check(bool(t["ok"]) and game.gear_in("body") == "armor_body_warrior_r1+1" and p.defense > def1,
		"доспех закалён надетым: %s, защита %d → %d" % [game.gear_in("body"), def1, p.defense])
	check(game.inventory.find_cell("armor_body_warrior_r1+1") == -1 and game.inventory.find_cell(game.weapon) == -1,
		"надетое заточенное ячеек не занимает")
	check(Enchant.cube_cap(game.weapon) == 10 and Enchant.admin_set("weapon", 99, p) == "weapon_sword_1h_r1+10",
		"админ «до предела» — +10 у оружия 1-го ранга")
	check(Enchant.admin_set("weapon", 3, p) == "weapon_sword_1h_r1+3", "админ −: +3")


## Админ-панель, «Предметы»: группа «Кубы» (+1 куб), заточка надетого −1 / +1 / до предела / 0.
func _check_admin() -> void:
	AdminPanel.open(main, "items")
	check(AdminPanel.buttons.has("item_cube_attack_r1_1") and AdminPanel.buttons.has("item_cube_defense_r2_10"), "админ: кнопки кубов")
	var groups: Array = []
	for g in AdminPanel.item_groups():
		groups.append(String((g as Array)[0]))
	check(groups.has("cube"), "админ: группа «Кубы»")
	var c0: int = game.inventory.count("cube_attack_r1")
	_apress("item_cube_attack_r1_1")
	check(game.inventory.count("cube_attack_r1") == c0 + 1, "админ: +1 куб атаки")
	game.inventory.remove("cube_attack_r1", game.inventory.count("cube_attack_r1"))
	var lvl := ItemData.enchant_level(game.weapon)
	for k in ["ench_weapon_minus", "ench_weapon_plus", "ench_weapon_max", "ench_weapon_zero", "ench_body_plus", "ench_head_max"]:
		check(AdminPanel.buttons.has(String(k)), "админ: кнопка %s" % k)
	_apress("ench_weapon_plus")
	check(ItemData.enchant_level(game.weapon) == lvl + 1, "админ +1: %s" % game.weapon)
	_apress("ench_weapon_minus")
	check(ItemData.enchant_level(game.weapon) == lvl, "админ −1: %s" % game.weapon)
	_apress("ench_weapon_max")
	check(ItemData.enchant_level(game.weapon) == 10, "админ «до предела»: %s (+10 у 1-го ранга)" % game.weapon)
	_apress("ench_weapon_zero")
	check(ItemData.enchant_level(game.weapon) == 0, "админ «0»: %s" % game.weapon)
	Enchant.admin_set("weapon", lvl, main.player)
	main.hud.close_window()


func _apress(key: String) -> void:
	check(AdminPanel.buttons.has(key), "админ: кнопка %s" % key)
	if AdminPanel.buttons.has(key):
		(AdminPanel.buttons[key] as Button).pressed.emit()


## Сохранение и загрузка: заточенное надетое, лом в сумке, заточенное на складе; старое сохранение — без заточки.
func _check_save_load() -> void:
	game.inventory.add(ItemData.broken_id("weapon_dagger_r1"), 2)
	game.storage.add("weapon_sword_2h_r1+7", 1)
	var w: String = game.weapon
	var body: String = game.gear_in("body")
	var d: Dictionary = game.to_dict()
	game.from_dict(JSON.parse_string(JSON.stringify(d)))
	check(game.weapon == w and ItemData.enchant_level(game.weapon) == 3, "после загрузки в руке %s" % game.weapon)
	check(game.offhand == "weapon_shield_r1+5" and game.gear_in("body") == body, "щит и доспех с заточкой: %s, %s"
		% [game.offhand, game.gear_in("body")])
	check(game.inventory.count(ItemData.broken_id("weapon_dagger_r1")) == 2, "лом в сумке после загрузки")
	check(game.storage.count("weapon_sword_2h_r1+7") == 1, "заточенное на складе после загрузки")
	main.player.apply_class()
	game.inventory.remove(ItemData.broken_id("weapon_dagger_r1"), 2)
	# Старое сохранение — вещи без «+», заточка 0
	var old := {"version": 2, "name": "Старый", "race": "light_elf", "class": "swordsman", "level": 25,
		"inventory": {"weapon_sword_1h_r1": 1, "weapon_shield_r1": 1}, "weapon": "weapon_sword_1h_r1",
		"offhand": "weapon_shield_r1"}
	var cur: Dictionary = game.to_dict()
	game.from_dict(old)
	check(game.weapon == "weapon_sword_1h_r1" and ItemData.enchant_level(game.weapon) == 0, "старое сохранение — заточка 0")
	game.from_dict(JSON.parse_string(JSON.stringify(cur)))
	main.player.apply_class()


## Надетое оружие ломается при неудаче: снимается, лом в сумке, надеть нельзя.
func _check_break_equipped(p: Player) -> void:
	var inv: Inventory = game.inventory
	Enchant.admin_set("weapon", 0, p)
	var broke := false
	for i in 60:
		var cur: String = game.weapon
		if cur == "":
			break
		inv.add("cube_attack_r1")
		var r := Enchant.use_cube(cur, "cube_attack_r1", "weapon", _rng, p)
		if bool(r["broke"]):
			broke = true
			check(game.weapon == "" and inv.has(ItemData.broken_id("weapon_sword_1h_r1")), "сломанный меч снят, лом в сумке")
			break
		Enchant.admin_set("weapon", 0, p)
	check(broke, "за 60 попыток меч хоть раз сломался (шанс неудачи 50 %)")
	var br := ItemData.broken_id("weapon_sword_1h_r1")
	check(game.equip_weapon(br) == Game.BROKEN_EQUIP and p.equip(br) != "", "сломанное не надеть: %s" % game.equip_weapon(br))
	check(game.offhand == "" or game.offhand_block(game.offhand) == "", "вторая рука — по правилам после поломки")
	check(game.gear_block(ItemData.broken_id("armor_helmet_r1"), "head") == Game.BROKEN_EQUIP, "сломанную броню не надеть")
	# Новый меч в руку для окон
	inv.add("weapon_sword_1h_r1")
	check(p.equip("weapon_sword_1h_r1") == "", "новый меч в руке")


# ---------- Окна ----------

func _check_craft_ui(p: Player) -> void:
	var eco: Economy = main.economy
	var win: InventoryWindow = eco.window
	var inv: Inventory = game.inventory
	inv.add("cube_attack_r1", 4)
	inv.add("cube_defense_r1", 2)
	inv.add("armor_gloves_r1")
	eco.open_bag()
	check(win.buttons.has("craft_toggle") and not win.buttons.has("craft_0"), "сумка — с экипировкой, кнопка «Крафт»")
	_wpress("craft_toggle")
	check(win.craft_open and win.buttons.has("craft_0") and win.buttons.has("craft_1"), "панель «Крафт»: ячейки вещи и куба")
	check(win.buttons.has("worn_weapon") and win.buttons.has("worn_body"), "на панели — надетое")
	# Перетаскивание: куб — во вторую ячейку, вещь — в первую; не туда — нельзя
	var gc := inv.find_cell("armor_gloves_r1")
	var cc := inv.find_cell("cube_defense_r1")
	check(win._can_drop("craft", 0, gc) and not win._can_drop("craft", 1, gc) and win._can_drop("craft", 1, cc)
		and not win._can_drop("craft", 0, cc), "перетаскивание: вещь — в «Вещь», куб — в «Куб»")
	win._on_drop("craft", 0, gc)
	check(win.craft_item == "armor_gloves_r1" and win.craft_cube == "cube_defense_r1", "перчатки на панели, куб защиты подставлен сам")
	_wpress("act_craft_clear")
	check(win.craft_item == "" and win.craft_cube == "", "«Очистить»")
	# Телефон: выбрать в сумке, «В крафт»; касание пустой ячейки панели при выбранном кубе
	win.select_cell(inv.find_cell("armor_gloves_r1"))
	_wpress("act_craft_put")
	check(win.craft_item == "armor_gloves_r1", "«В крафт» из карточки")
	win._on_cell("craft", 1)
	check(win.craft_cube == "", "касание занятой ячейки куба — убрать")
	win.select_cell(inv.find_cell("cube_defense_r1"))
	win._on_cell("craft", 1)
	check(win.craft_cube == "cube_defense_r1", "касание пустой ячейки куба — положить выбранный куб")
	check(_has_text("шанс 50%") and _has_text("Предел кубами: +10") and _has_text("сломается"), "шанс, предел и риск на панели")
	# Крафт с подтверждением
	_wpress("act_craft")
	check(win.craft_confirm and win.buttons.has("act_craft_yes") and win.buttons.has("act_craft_no"), "подтверждение при риске")
	_wpress("act_craft_no")
	check(not win.craft_confirm and inv.count("cube_defense_r1") == 2, "«Отмена» — ничего не потрачено")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	eco.craft_rng = rng
	_wpress("act_craft")
	_wpress("act_craft_yes")
	check(inv.count("cube_defense_r1") == 1, "куб потрачен")
	check(win.craft_result != "" and _has_text(win.craft_result.left(16)), "итог на панели: %s" % win.craft_result)
	if win.craft_ok:
		check(win.craft_item == "armor_gloves_r1+1" and inv.has("armor_gloves_r1+1"), "удача — перчатки +1 на панели")
	else:
		check(win.craft_item == "" and inv.has(ItemData.broken_id("armor_gloves_r1")), "неудача — перчатки сломаны, ячейка пуста")
	# Надетый меч — «В крафт» с надетого
	win.select_equip("weapon")
	_wpress("act_craft_put")
	check(win.craft_item == game.weapon and win.craft_where == "weapon" and win.craft_cube == "cube_attack_r1",
		"надетый меч на панели, куб атаки подставлен: %s / %s" % [win.craft_item, win.craft_cube])
	var c0 := inv.count("cube_attack_r1")
	_wpress("act_craft")
	_wpress("act_craft_yes")
	check(inv.count("cube_attack_r1") == c0 - 1, "куб атаки потрачен")
	if win.craft_ok:
		check(game.weapon == "weapon_sword_1h_r1+1", "меч +1 остался в руке")
	else:
		check(game.weapon != "weapon_sword_1h_r1", "меч сломался и снят")
	eco.craft_rng = null
	# Сломанная вещь — не на панель
	var brs := ""
	for k in inv.ids():
		if ItemData.is_broken(String(k)):
			brs = String(k)
	if brs != "":
		check(win.put_craft(brs) != "", "лом на панель не кладётся")
	if game.weapon == "":
		inv.add("weapon_sword_1h_r1")
		p.equip("weapon_sword_1h_r1")
	main.hud.close_window()


func _check_forge_ui() -> void:
	var eco: Economy = main.economy
	var win: InventoryWindow = eco.window
	var npcs: Npcs = main.npcs
	npcs.talk_to(Enchant.SMITH_NPC)
	check(npcs.is_dialog_open() and npcs.buttons.has("opt_forge"), "у кузнеца пункт «Закалка»")
	var ob: Button = npcs.buttons.get("opt_forge")
	check(ob != null and not ob.text.contains("скоро"), "«Закалка» — без «скоро»")
	if ob != null:
		ob.pressed.emit()
	check(eco.is_forge_open() and not npcs.is_dialog_open(), "окно кузницы открыто")
	game.gold = 50000
	var w: String = game.weapon
	var lvl := ItemData.enchant_level(w)
	win.select_equip("weapon")
	_wpress("act_forge_put")
	check(win.forge_item == w and win.forge_where == "weapon", "надетый меч на наковальне")
	var price := Enchant.temper_price(w)
	check(_has_text("Цена: %d зол." % price) and _has_text("100%"), "цена %d и 100 %% на наковальне" % price)
	_wpress("act_forge")
	check(ItemData.enchant_level(game.weapon) == lvl + 1 and game.gold == 50000 - price and win.forge_item == game.weapon,
		"«Закалить»: %s, золото %d" % [game.weapon, game.gold])
	game.gold = 0
	win.refresh()
	var fb: Button = win.buttons.get("act_forge")
	check(fb != null and fb.disabled and _has_text("Не хватает золота"), "нет золота — кнопка серая, причина видна")
	var r := eco.temper(game.weapon, "weapon")
	check(not bool(r["ok"]) and last_hud_text().contains("золота"), "сообщение без золота: %s" % last_hud_text())
	# Вещь из сумки — «На наковальню»
	game.inventory.add("weapon_shield_r1")
	win.select_cell(game.inventory.find_cell("weapon_shield_r1"))
	_wpress("act_forge_put")
	check(win.forge_item == "weapon_shield_r1" and win.forge_where == "", "щит из сумки на наковальне")


func _check_sell_broken() -> void:
	var eco: Economy = main.economy
	var win: InventoryWindow = eco.window
	var inv: Inventory = game.inventory
	var br := ItemData.broken_id("weapon_sword_1h_r2")
	inv.add(br, 3)
	var price := int(ItemData.get_item(br)["sell"])
	check(price == maxi(1, roundi(float(ItemData.get_item("weapon_sword_1h_r2")["sell"]) * ItemData.BROKEN_SELL)),
		"лом — четверть цены вещи: %d" % price)
	eco.open_bag()
	win.select_cell(inv.find_cell(br))
	check(not win.buttons.has("act_equip") and not win.buttons.has("act_craft_put"), "лом: ни «Надеть», ни «В крафт»")
	check(win.buttons.has("act_sell"), "лом продаётся торговцу")
	var g0: int = game.gold
	_wpress("act_sell_all")
	check(inv.count(br) == 0 and game.gold == g0 + price * 3, "продан лом: +%d зол." % (price * 3))
	main.hud.close_window()


# ---------- Добыча ----------

## Кубы в добыче: вес 10 / 25 / 35, доля среди предметов ≈ вес / сумма весов, за убийство — 1 − (1 − доля)^N;
## ранг куба — по уровню зверя; в наградах заданий — 5 %.
func _unit_loot() -> void:
	check(is_equal_approx(LootTable.category_chance("cube", "wolf"), 0.10)
		and is_equal_approx(LootTable.category_chance("cube", "centaur"), 0.25)
		and is_equal_approx(LootTable.category_chance("cube", "boss_panther"), 0.35), "вес кубов: 10 / 25 / 35")
	var per_kill: Array = []
	for e in [["wolf", 8], ["centaur", 15], ["boss_panther", 24], ["anathema_blade", 22]]:
		var tid := String(e[0])
		var lvl := int(e[1])
		var cats := LootTable.categories_for(tid, lvl)
		check(cats.has("cube"), "%s: кубы в добыче" % tid)
		var total_w := 0.0
		for k in cats:
			total_w += float(cats[k])
		var want := float(cats.get("cube", 0.0)) / total_w
		var rng := RandomNumberGenerator.new()
		rng.seed = 77 + lvl
		var cubes := 0
		var items := 0
		var kills_with := 0
		for i in LOOT_KILLS:
			var loot := LootTable.roll(tid, lvl, false, rng)
			var got := false
			for k in loot:
				items += int(loot[k])
				if ItemData.is_cube(String(k)):
					cubes += int(loot[k])
					got = true
					check(ItemData.rank(String(k)) == ItemData.cube_rank_for_level(lvl), "%s %d ур.: куб %s" % [tid, lvl, k])
			if got:
				kills_with += 1
		var share := float(cubes) / float(maxi(1, items))
		var kill_share := float(kills_with) / float(LOOT_KILLS)
		var kill_want := 1.0 - pow(1.0 - want, float(LootTable.item_count(tid)))
		check(absf(share - want) < 0.02, "%s: доля кубов %.1f%% ≈ %.1f%%" % [tid, share * 100.0, want * 100.0])
		check(absf(kill_share - kill_want) < 0.03, "%s: куб за убийство %.1f%% ≈ %.1f%%" % [tid, kill_share * 100.0, kill_want * 100.0])
		per_kill.append(kill_share)
		print("  КУБЫ %s %d ур.: %.1f%% предметов, %.1f%% убийств (вес %.0f)" % [tid, lvl, share * 100.0, kill_share * 100.0,
			float(cats.get("cube", 0.0)) * 100.0])
	check(float(per_kill[0]) < float(per_kill[1]) and float(per_kill[1]) < float(per_kill[2]),
		"куб за убийство: зверь < минибосс < босс")
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 31
	var ch := LootTable.quest_chances(30, "swordsman", rng2)
	check(ch.has("cube") and is_equal_approx(float((ch["cube"] as Array)[0]), 0.05), "награда задания: куб 5 %")
	for e in (ch["cube"] as Array)[1]:
		check(ItemData.rank(String((e as Array)[0])) == 2, "награда 30 ур.: куб 2-го ранга")
	var got_cube := 0
	for i in 2000:
		var r := LootTable.quest_reward(12, "swordsman", rng2)
		for k in r:
			if ItemData.is_cube(String(k)):
				got_cube += 1
	check(got_cube > 20, "кубы бывают в наградах заданий: %d из 2000" % got_cube)


# ---------- Помощники ----------

func _wpress(node_name: String) -> void:
	var win: InventoryWindow = main.economy.window
	var b: Button = win.buttons.get(node_name)
	check(b != null, "кнопка %s есть в окне" % node_name)
	if b != null:
		b.pressed.emit()


func _has_text(part: String) -> bool:
	if not main.hud.is_window_open():
		return false
	for n in main.hud._window.find_children("*", "Label", true, false):
		if (n as Label).text.contains(part) and not n.is_queued_for_deletion():
			return true
	return false


func last_hud_text() -> String:
	return main.hud._msg_label.text


## Игрок в dist м перед жителем (на проходимой земле).
func _stand_by(id: String, dist: float) -> void:
	var n: Npc = main.npcs.npc(id)
	if n == null:
		check(false, "житель %s в мире" % id)
		return
	var w := IslandWorld.current
	var p: Player = main.player
	var c := n.global_position
	var fwd := Vector3(-sin(n.face_yaw), 0, -cos(n.face_yaw))
	var pos := c + fwd * dist
	for k in 8:
		var dir := fwd.rotated(Vector3.UP, TAU * float(k) / 8.0)
		var q := c + dir * dist
		if w == null or w.is_walkable(q.x, q.z):
			pos = q
			break
	if w != null:
		pos.y = w.height_at(pos.x, pos.z) + 0.1
	p.global_position = pos
