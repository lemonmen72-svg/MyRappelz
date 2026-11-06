extends "res://tests/test_base.gd"
## Торбы (0.32, задача Максима): семь рангов `bag_r1…bag_r7` (ItemData BAG_*), ячейка «Торба» (GEAR_SLOTS "bag"),
## надетая торба добавляет ячеек сумке (Inventory.capacity), без ограничения по уровню; у Гордея — 1–3-й ранг;
## снять или сменить на меньшую — только если вещи поместятся (Game.bag_block), лишние ячейки при снятии
## переезжают внутрь вместимости; сетка сумки с торбой прокручивается; сохранение и загрузка.
## Пояс в сумке: ячейки карт питомцев под экипировкой (InventoryWindow._build_belt): пустая — карты питомцев,
## касание карты — в пояс; занятая — «Из пояса»; закрытая — расширитель.

func race_class() -> Array:
	return ["human", ClassData.WANDERER]


func hero_level() -> int:
	return 3


func run_step() -> void:
	match step:
		0:
			_unit_items()
			step = 1
		1:
			_buy_and_equip()
			step = 2
		2:
			_bag_rules()
			_save_load()
			step = 3
		3:
			_window()
			wait = 2
			step = 4
		4:
			_belt_in_bag()
			ok_done()


func _unit_items() -> void:
	for r in range(1, ItemData.BAG_RANKS + 1):
		var id := ItemData.bag_id(r)
		check(ItemData.is_bag(id) and ItemData.is_gear(id), "%s — торба" % id)
		check(ItemData.bag_slots(id) == 24 * r, "%s: +%d ячеек" % [id, ItemData.bag_slots(id)])
		check(ItemData.level_block(id, 1) == "", "%s — без ограничения по уровню" % id)
		check(ItemData.gear_slots_for(id) == ["bag"], "%s надевается в «Торбу»" % id)
		check(ItemData.stack_size(id) == 1 and not ItemData.is_enchantable(id), "%s по одной, не точится" % id)
		check((int(ItemData.get_item(id)["buy"]) > 0) == (r <= ItemData.BAG_SOLD), "%s: цена покупки только у 1–3-го" % id)
	var shop: Array = NpcData.shop("merchant")
	check(shop.has("bag_r1") and shop.has("bag_r2") and shop.has("bag_r3") and not shop.has("bag_r4"),
		"у Гордея торбы 1–3-го ранга")
	var types: Array = []
	for g in AdminPanel.item_groups():
		types.append(String((g as Array)[0]))
	check(types.has("bag"), "админ-панель: группа «Торбы»")


func _buy_and_equip() -> void:
	var inv: Inventory = game.inventory
	game.gold = 100000
	check(inv.capacity == Inventory.CAPACITY, "без торбы — %d ячеек" % inv.capacity)
	var eco: Economy = main.economy
	check(eco.buy("bag_r3", 1, "merchant"), "торба 3-го ранга куплена у Гордея")
	check(inv.has("bag_r3"), "торба в сумке")
	var err: String = main.player.equip_gear("bag_r3")
	check(err == "", "торба надета на 3 ур. героя: %s" % err)
	check(game.gear_in("bag") == "bag_r3" and inv.capacity == Inventory.CAPACITY + 72, "вместимость %d" % inv.capacity)
	check(inv.find_cell("bag_r3") == -1, "надетая торба ячейку не занимает")
	check(inv.cell_count() == Inventory.CAPACITY + 72, "ячеек показано %d" % inv.cell_count())


func _bag_rules() -> void:
	var inv: Inventory = game.inventory
	# Заполнить больше 40 ячеек — снять торбу нельзя
	var free := inv.capacity - inv.used_cells()
	inv.add("sword_steel", free - 2)
	check(inv.used_cells() > Inventory.CAPACITY, "занято %d из %d" % [inv.used_cells(), inv.capacity])
	check(game.bag_block("") != "", "снять торбу нельзя: %s" % game.bag_block(""))
	check(not game.unequip_gear("bag") and game.gear_in("bag") == "bag_r3", "торба осталась надетой")
	inv.add("bag_r1")
	check(game.gear_block("bag_r1", "bag") != "", "сменить на меньшую нельзя: %s" % game.gear_block("bag_r1", "bag"))
	inv.add("bag_r7")
	check(game.equip_gear("bag_r7") == "" and inv.capacity == Inventory.CAPACITY + 168, "на большую — можно: %d" % inv.capacity)
	check(inv.has("bag_r3") and inv.find_cell("bag_r3") >= 0, "прежняя торба — в ячейке сумки")
	# Освободить и снять: вещи из дальних ячеек переезжают внутрь 40
	inv.remove("sword_steel", inv.count("sword_steel"))
	inv.add("wolf_pelt", 1)
	var far := inv.find_cell("wolf_pelt")
	if far < Inventory.CAPACITY:
		inv.move(far, Inventory.CAPACITY + 10)
	check(inv.find_cell("wolf_pelt") >= Inventory.CAPACITY, "шкура в дальней ячейке %d" % inv.find_cell("wolf_pelt"))
	check(game.unequip_gear("bag") and inv.capacity == Inventory.CAPACITY, "торба снята, вместимость %d" % inv.capacity)
	check(inv.find_cell("wolf_pelt") >= 0 and inv.find_cell("wolf_pelt") < Inventory.CAPACITY and inv.cell_count() == Inventory.CAPACITY,
		"шкура переехала внутрь вместимости (ячейка %d, ячеек %d)" % [inv.find_cell("wolf_pelt"), inv.cell_count()])
	check(game.equip_gear("bag_r3") == "", "снова надета торба 3-го ранга")


func _save_load() -> void:
	var d: Dictionary = game.to_dict()
	game.from_dict(JSON.parse_string(JSON.stringify(d)))
	check(game.gear_in("bag") == "bag_r3" and game.inventory.capacity == Inventory.CAPACITY + 72,
		"после загрузки торба надета, вместимость %d" % game.inventory.capacity)
	main.player.recalc_stats()


func _window() -> void:
	var inv: Inventory = game.inventory
	var win: InventoryWindow = main.economy.window
	main.economy.open_bag()
	check(win.buttons.has("equip_bag"), "ячейка «Торба» в сумке")
	check(win.buttons.has("cell_%d" % (inv.capacity - 1)) and not win.buttons.has("cell_%d" % inv.capacity),
		"видны все %d ячеек" % inv.capacity)
	check(win.bag_scroll != null and is_instance_valid(win.bag_scroll), "сетка сумки с торбой прокручивается")
	var used := _find_live(main.hud._window, "used_label") as Label
	check(used != null and used.text.ends_with("/%d" % inv.capacity), "занятость: %s" % (used.text if used else "?"))
	_press("equip_bag")
	check(win.sel_kind == "equip" and win.buttons.has("act_unequip"), "карточка надетой торбы, «Снять»")
	for sl in PetBelt.MAX_SLOTS:
		check(win.buttons.has("belt_%d" % sl), "ячейка пояса %d в сумке" % (sl + 1))


func _belt_in_bag() -> void:
	var win: InventoryWindow = main.economy.window
	var inv: Inventory = game.inventory
	inv.add("belt_light_r1")
	check(main.player.equip_gear("belt_light_r1") == "", "пояс надет")
	var i: int = AdminPanel.add_pet(main, "wolf", 40)
	check(i >= 0, "питомец 40 ур.")
	var rec: Dictionary = game.pets[i]
	var sk: Dictionary = rec.get("skills", {})
	sk["card_wolf_1"] = 1
	rec["skills"] = sk
	check(not PetBelt.abilities(rec).is_empty(), "у волка изучена «Способность карты»")
	main.economy.open_bag()
	_press("belt_0")
	check(win.sel_kind == "belt" and win.sel_index == 0, "выбрана ячейка пояса 1")
	check(win.buttons.has("belt_pet_%d" % i), "в карточке — карта волка")
	_press("belt_pet_%d" % i)
	check(PetBelt.pet_in(0) == i and game.active_pet != i, "волк в поясе (отозван)")
	check(not PetBelt.hero_bonus(game.class_id, game.level).is_empty(), "герою — бонус карты")
	check(win.buttons.has("act_belt_take"), "«Из пояса» у занятой ячейки")
	_press("act_belt_take")
	check(PetBelt.pet_in(0) == -1, "волк вынут из пояса")
	_press("belt_%d" % (PetBelt.MAX_SLOTS - 1))
	check(win.buttons.has("act_belt_expand") and (win.buttons["act_belt_expand"] as Button).disabled,
		"закрытая ячейка: «Расширить пояс» без расширителя недоступна")


func _press(node_name: String) -> void:
	var win: InventoryWindow = main.economy.window
	var b: Button = win.buttons.get(node_name)
	check(b != null, "кнопка %s есть в окне" % node_name)
	if b != null:
		b.pressed.emit()


func _find_live(n: Node, nm: String) -> Node:
	if n == null or n.is_queued_for_deletion():
		return null
	if n.name == nm:
		return n
	for c in n.get_children():
		var r := _find_live(c, nm)
		if r != null:
			return r
	return null
