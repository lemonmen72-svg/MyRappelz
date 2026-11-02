extends BotSection
## Раздел «Экипировка» (герой — Бродяга 25 ур.: ему подходит любое оружие и доспех): оружие каждого вида 1-го ранга,
## пары клинков и топоров, щит во второй руке — вид хвата, атака (физ. / маг.), скорость, блок; броня 1-го ранга
## на 4 ячейки и украшения на 5 (два кольца) — защита, HP, крит, бег выросли; окно сумки с экипировкой и окно героя.
## Крафт: кубом атаки чаруется топор из сумки — шанс 50 %: удача — «+1», неудача — лом (оба исхода проверяются,
## до CRAFT_TRIES попыток, пока не будет удачи); панель «Крафт» в сумке. Закалка у Кузнеца Гуннара (пункт «Закалка»
## в диалоге): надетое оружие +1 за золото, всегда успешно, атака выросла.

const LEVEL := 25
## Наборы оружия [основная рука, вторая рука, ожидаемый вид хвата].
const LOADOUTS := [
	["weapon_sword_1h_r1", "", "sword_1h"], ["weapon_sword_1h_r1", "weapon_sword_1h_r1", "dual_swords"],
	["weapon_sword_1h_r1", "weapon_shield_r1", "sword_1h"], ["weapon_sword_2h_r1", "", "sword_2h"],
	["weapon_dagger_r1", "", "dagger"], ["weapon_dagger_r1", "weapon_dagger_r1", "daggers"],
	["weapon_mace_1h_r1", "", "mace_1h"], ["weapon_mace_2h_r1", "", "mace_2h"], ["weapon_axe_1h_r1", "", "axe_1h"],
	["weapon_axe_1h_r1", "weapon_axe_1h_r1", "dual_axes"], ["weapon_axe_2h_r1", "", "axe_2h"],
	["weapon_staff_1h_r1", "", "staff_1h"], ["weapon_staff_2h_r1", "", "staff_2h"], ["weapon_spear_r1", "", "spear"],
	["weapon_bow_r1", "", "bow"], ["crossbow_starter", "", "crossbow"],
]
const QUICK_LOADOUTS := [0, 1, 2, 3, 5, 12, 14, 15]
const GEAR := ["armor_body_warrior_r1", "armor_helmet_r1", "armor_gloves_r1", "armor_boots_r1", "ring_hp_r1", "ring_hp_r1",
	"earring_crit_r1", "pendant_hp_r1", "belt_speed_r1"]
const CRAFT_ITEM := "weapon_axe_1h_r1"
const CRAFT_TRIES := 6

## Показатели при каждом наборе: вид хвата → {atk, matk, aspd, block, def}.
var _stats: Dictionary = {}
var _base: Dictionary = {}


func id() -> String:
	return "equipment"


func _build() -> void:
	do("Экипировка: Бродяга 25 ур., сумка", _setup)
	for i in LOADOUTS.size():
		if quick and not QUICK_LOADOUTS.has(i):
			continue
		var lo: Array = LOADOUTS[i]
		do("Оружие: %s%s" % [ItemData.item_name(String(lo[0])), " + " + ItemData.item_name(String(lo[1]))
			if String(lo[1]) != "" else ""], _wield.bind(lo))
		wait(0.15)
	do("Оружие: показатели по видам", _weapon_stats)
	do("Броня и украшения", _gear)
	do("Сумка с экипировкой", func() -> void: economy().open_bag())
	wait(0.3)
	do("Сумка помещается", _bag_check)
	do("Окно героя", func() -> void: bot.main.get("hero_window").call("open", "hero"))
	wait(0.3)
	do("Окно героя помещается", _hero_check)
	do("Крафт: куб атаки", _craft)
	wait(0.3)
	do("Крафт: панель в сумке", _craft_panel_check)
	do("Закалка: к Кузнецу Гуннару", _forge_open)
	wait(0.3)
	do("Закалка: надетое оружие +1", _temper)


func _setup() -> void:
	hero(ClassData.WANDERER, LEVEL)
	fresh_bag(100000)
	for k in Game.equip.keys():
		player().unequip_gear(String(k))
	_stats.clear()


## Надеть набор: вторая рука освобождается, основное оружие, вторая рука; вид хвата и показатели.
func _wield(lo: Array) -> void:
	var p := player()
	var a := String(lo[0])
	var b := String(lo[1])
	var kind := String(lo[2])
	var need_a := 2 if a == b else 1
	if Game.inventory.count(a) < need_a:
		Game.inventory.add(a, need_a - Game.inventory.count(a))
	if b != "" and b != a and Game.inventory.count(b) < 1:
		Game.inventory.add(b, 1)
	if Game.offhand != "":
		p.unequip_offhand()
	var err := p.equip(a)
	if b != "" and err == "":
		err = p.equip(b, true)
	var nm := ItemData.item_name(a) + (" + " + ItemData.item_name(b) if b != "" else "")
	if not check(err == "", "надето: %s %s" % [nm, err]):
		return
	check(Game.weapon == a and Game.offhand == b and p.weapon_kind == kind and Game.weapon_kind() == kind,
		"%s: вид хвата %s (%s)" % [nm, kind, p.weapon_kind])
	check(p.attack_kind == ItemData.weapon_attack(ItemData.weapon_kind(a)), "%s: обычная атака «%s»" % [nm, p.attack_kind])
	var shield := b != "" and ItemData.is_shield(b)
	check(p.has_shield == shield, "%s: щит во второй руке — %s" % [nm, "да" if shield else "нет"])
	_stats[kind + ("+shield" if shield else "")] = {"atk": p.atk, "matk": p.matk, "aspd": p.aspd, "block": p.block,
		"def": p.defense}


## Показатели по видам (решения Максима): кинжал быстрее двуручного меча, посох — маг. атака выше меча, щит — блок
## и защита, пара клинков — атака выше одного.
func _weapon_stats() -> void:
	var s := _stats
	if s.has("dagger") and s.has("sword_2h"):
		check(float(s["dagger"]["aspd"]) > float(s["sword_2h"]["aspd"]), "кинжал быстрее двуручного меча: %.2f > %.2f"
			% [float(s["dagger"]["aspd"]), float(s["sword_2h"]["aspd"])])
	if s.has("staff_2h") and s.has("sword_1h"):
		check(int(s["staff_2h"]["matk"]) > int(s["sword_1h"]["matk"]), "посох — маг. атака выше меча: %d > %d"
			% [int(s["staff_2h"]["matk"]), int(s["sword_1h"]["matk"])])
	if s.has("sword_1h+shield") and s.has("sword_1h"):
		check(float(s["sword_1h+shield"]["block"]) > 0.0 and int(s["sword_1h+shield"]["def"]) > int(s["sword_1h"]["def"]),
			"щит: блок %.0f %%, защита %d > %d" % [float(s["sword_1h+shield"]["block"]) * 100.0,
			int(s["sword_1h+shield"]["def"]), int(s["sword_1h"]["def"])])
	if s.has("dual_swords") and s.has("sword_1h"):
		check(int(s["dual_swords"]["atk"]) > int(s["sword_1h"]["atk"]), "два меча — атака выше одного: %d > %d"
			% [int(s["dual_swords"]["atk"]), int(s["sword_1h"]["atk"])])
	note("Оружие: %s" % str(_stats))


## Броня и украшения 1-го ранга во все 9 ячеек: защита, HP, крит, бег выросли.
func _gear() -> void:
	var p := player()
	# Основное оружие — одноручный меч (щит снят: защита — только от брони)
	if Game.offhand != "":
		p.unequip_offhand()
	p.recalc_stats()
	_base = {"def": p.defense, "hp": p.max_hp, "crit": p.crit, "speed": p.cur_speed()}
	for g in GEAR:
		Game.inventory.add(String(g), 1)
	for g in GEAR:
		var gid := String(g)
		var err := p.equip_gear(gid)
		check(err == "", "надето: %s %s" % [ItemData.item_name(gid), err])
	var worn := 0
	for k in Game.equip:
		if String(Game.equip[k]) != "":
			worn += 1
	check(worn == GEAR.size(), "занято ячеек экипировки: %d из %d" % [worn, GEAR.size()])
	check(p.defense > int(_base["def"]), "броня: защита %d → %d" % [int(_base["def"]), p.defense])
	check(p.max_hp > int(_base["hp"]), "кольца и кулон: HP %d → %d" % [int(_base["hp"]), p.max_hp])
	check(p.crit > float(_base["crit"]), "серьги: крит %.3f → %.3f" % [float(_base["crit"]), p.crit])
	check(p.cur_speed() > float(_base["speed"]), "пояс: бег %.2f → %.2f" % [float(_base["speed"]), p.cur_speed()])


func _bag_check() -> void:
	window_fits("Сумка с экипировкой")
	shot("Sumka ekipirovka")
	close_window()


func _hero_check() -> void:
	window_fits("Окно героя")
	shot("Okno geroya")
	close_window()


## Чарование кубом атаки (настоящий бросок): удача — «+1», неудача — лом; повтор с новой вещью до удачи.
func _craft() -> void:
	var eco := economy()
	var cube := ItemData.cube_id("attack", 1)
	var ok_n := 0
	var broke_n := 0
	for t in CRAFT_TRIES:
		Game.inventory.add(CRAFT_ITEM, 1)
		Game.inventory.add(cube, 1)
		var cubes := Game.inventory.count(cube)
		var r := eco.craft(CRAFT_ITEM, cube, "")
		if not check(String(r["error"]) == "", "чарование: %s" % String(r["text"])):
			return
		check(Game.inventory.count(cube) == cubes - 1, "куб потрачен")
		if bool(r["ok"]):
			ok_n += 1
			check(String(r["item"]) == ItemData.enchanted_id(CRAFT_ITEM, 1) and Game.inventory.has(String(r["item"])),
				"удача: «%s» в сумке" % ItemData.item_name(String(r["item"])))
			break
		broke_n += 1
		check(bool(r["broke"]) and Game.inventory.has(ItemData.broken_id(CRAFT_ITEM)), "неудача: вещь — лом «%s»"
			% ItemData.item_name(ItemData.broken_id(CRAFT_ITEM)))
	note("Крафт: удач %d, поломок %d (шанс +1 — %d %%)" % [ok_n, broke_n, roundi(Enchant.chance_for(1) * 100.0)])
	# Панель «Крафт» в сумке: надетое оружие и куб на панели
	Game.inventory.add(cube, 1)
	var win := eco.window
	win.open_craft()
	win.put_craft(Game.weapon, "weapon")
	win.put_craft(cube)


func _craft_panel_check() -> void:
	window_fits("Сумка: панель «Крафт»")
	shot("Kraft")
	close_window()


func _forge_open() -> void:
	close_window()
	# На наковальню — одноручный меч в руке
	if Game.weapon != "weapon_sword_1h_r1":
		if Game.offhand != "":
			player().unequip_offhand()
		if Game.inventory.count("weapon_sword_1h_r1") < 1:
			Game.inventory.add("weapon_sword_1h_r1", 1)
		player().equip("weapon_sword_1h_r1")
	if not go_near(Enchant.SMITH_NPC):
		return
	npcs().talk_to(Enchant.SMITH_NPC)
	press_dialog("opt_forge")


## Закалка надетого оружия: +1, золото по цене, атака выросла.
func _temper() -> void:
	var eco := economy()
	var p := player()
	if not check(eco.is_forge_open(), "окно кузницы открыто (%s)" % last_msg()):
		return
	var item := Game.weapon
	eco.window.put_forge(item, "weapon")
	window_fits("Кузница")
	shot("Kuznica")
	var price := Enchant.temper_price(item)
	var gold0 := Game.gold
	var atk0 := p.atk
	var r := eco.temper(item, "weapon")
	check(bool(r["ok"]) and Game.weapon == ItemData.enchanted_id(item, ItemData.enchant_level(item) + 1),
		"закалка: «%s» (%s)" % [ItemData.item_name(Game.weapon), String(r["text"])])
	check(Game.gold == gold0 - price, "закалка: золото −%d" % price)
	check(p.atk > atk0, "закалка: атака %d → %d" % [atk0, p.atk])
	close_window()
