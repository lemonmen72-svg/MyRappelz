extends BotSection
## Раздел «Торба и пояс» (0.32): у Торговца Гордея — торба 1-го ранга (покупка, золото), надеть — сумка шире
## (Inventory.capacity), сетка прокручивается, окно помещается; торба 3-го ранга; сумка забита — снять торбу нельзя;
## пояс в сумке — ячейки карт питомцев: волк 40 ур. со «Способностью карты» — касание ячейки, касание его карты →
## в поясе, герою бонус, «Из пояса».

func id() -> String:
	return "bags"


func _build() -> void:
	do("Торба: герой, сумка", _setup)
	do("Торба: к Торговцу Гордею", _buy)
	wait(0.3)
	do("Торба: надеть, сумка шире", _equip)
	wait(0.3)
	do("Торба: сумка с торбой", _bag_window)
	wait(0.3)
	do("Торба: полная сумка", _full)
	do("Пояс: карта питомца в поясе", _belt)
	wait(0.3)
	do("Пояс: из пояса", _belt_take)


func _setup() -> void:
	Game.unequip_gear("bag")
	hero(ClassData.WANDERER, 25)
	fresh_bag(100000)
	no_pets()


func _buy() -> void:
	if not go_near("merchant"):
		return
	var eco := economy()
	eco.open_shop("merchant")
	check(eco.is_shop_open(), "лавка Гордея открыта")
	window_fits("Лавка Гордея")
	var gold0 := Game.gold
	var price := int(ItemData.get_item("bag_r1").get("buy", 0))
	check(eco.buy("bag_r1", 1, "merchant") and Game.gold == gold0 - price, "куплена «%s» за %d зол. (%s)" % [
		ItemData.item_name("bag_r1"), price, last_msg()])
	check(not InventoryWindow.goods(Game.class_id, "merchant").has("bag_r4"), "торбы 4-го ранга у Гордея нет")
	close_window()


func _equip() -> void:
	var p := player()
	var err := p.equip_gear("bag_r1")
	check(err == "" and Game.inventory.capacity == Inventory.CAPACITY + ItemData.bag_slots("bag_r1"), "торба надета: ячеек %d (%s)" % [
		Game.inventory.capacity, err])
	Game.inventory.add("bag_r3")
	err = p.equip_gear("bag_r3")
	check(err == "" and Game.inventory.capacity == Inventory.CAPACITY + ItemData.bag_slots("bag_r3"), "торба 3-го ранга: ячеек %d" % Game.inventory.capacity)
	economy().open_bag()


func _bag_window() -> void:
	var win: InventoryWindow = economy().window
	check(win.buttons.has("equip_bag") and win.buttons.has("cell_%d" % (Game.inventory.capacity - 1)),
		"в сумке ячейка «Торба» и все %d ячеек" % Game.inventory.capacity)
	check(win.bag_scroll != null, "сетка сумки прокручивается")
	window_fits("Сумка с торбой")
	shot("Sumka torba")


func _full() -> void:
	var inv := Game.inventory
	inv.add("sword_steel", inv.capacity - inv.used_cells())
	check(Game.bag_block("") != "" and not Game.unequip_gear("bag"), "сумка полна — торбу не снять: %s" % Game.bag_block(""))
	inv.remove("sword_steel", inv.count("sword_steel"))
	check(Game.bag_block("") == "", "сумка свободна — снять можно")


func _belt() -> void:
	var inv := Game.inventory
	inv.add("belt_light_r1")
	check(player().equip_gear("belt_light_r1") == "", "пояс надет")
	var i: int = AdminPanel.add_pet(main(), "wolf", 40)
	if not check(i >= 0, "волк 40 ур."):
		return
	var rec: Dictionary = Game.pets[i]
	var sk: Dictionary = rec.get("skills", {})
	sk["card_wolf_1"] = maxi(1, int(sk.get("card_wolf_1", 0)))
	rec["skills"] = sk
	economy().open_bag()
	var win: InventoryWindow = economy().window
	_press(win, "belt_0")
	_press(win, "belt_pet_%d" % i)
	check(PetBelt.pet_in(0) == i, "волк в поясе (касание карты в ячейке 1)")
	check(not PetBelt.hero_bonus(Game.class_id, Game.level).is_empty(), "герою — бонус карты: %s" % PetBelt.bonus_text(
		PetBelt.hero_bonus(Game.class_id, Game.level)))
	window_fits("Сумка: пояс")
	shot("Poyas v sumke")


func _belt_take() -> void:
	var win: InventoryWindow = economy().window
	_press(win, "act_belt_take")
	check(PetBelt.pet_in(0) == -1, "волк вынут из пояса")
	close_window()
	no_pets()


func _press(win: InventoryWindow, key: String) -> void:
	var b: Button = win.buttons.get(key)
	if check(b != null, "кнопка «%s» есть" % key) and not b.disabled:
		b.pressed.emit()
