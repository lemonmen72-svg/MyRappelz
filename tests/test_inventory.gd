extends "res://tests/test_base.gd"
## Сумка как в MMORPG (Inventory + InventoryWindow): стопки, вместимость и переполнение, перемещение и сортировка,
## сохранение раскладки и загрузка старого формата, окно сумки (ячейки, экипировка, карточка, «Использовать»,
## «Надеть», «Переместить», перетаскивание, «Выбросить»), продажа у торговца, окно торговца, «Сумка полна»
## для покупки и добычи. Заточенные («<id>+N») и сломанные («<id>!broken») вещи в сумке: стопки, порядок, раскладка
## в сохранении (подробно чарование — tests/test_enchant.gd).

var drop: LootDrop = null


func race_class() -> Array:
	return ["dark_elf", "assassin"]


func run_step() -> void:
	var player: Player = main.player
	var eco: Economy = main.economy
	var win: InventoryWindow = eco.window
	var inv: Inventory = game.inventory
	match step:
		0:
			_unit_stacks()
			_unit_move_sort()
			_unit_layout()
			_unit_enchanted()
			step = 1
		1:
			# Новый Наёмник: два надетых кинжала (основная и вторая рука) в ячейках не лежат
			check(game.weapon == "weapon_dagger_r1" and game.offhand == "weapon_dagger_r1", "в руках два кинжала")
			check(inv.equipped == game.weapon and inv.equipped_off == game.offhand, "сумка знает оружие обеих рук")
			check(inv.find_cell(game.weapon) == -1, "надетые кинжалы не занимают ячеек")
			check(inv.count(game.weapon) == 2, "но числятся в сумке (count)")
			check(inv.used_cells() == 3, "занято ячеек: %d (арбалет, зелья, свиток; карт в подарок нет)" % inv.used_cells())
			check(ItemData.is_weapon(String(inv.cell(0).get("id", ""))), "новая сумка разложена по порядку: оружие первым")
			player.global_position = Vector3(0, 0.1, 7.0)
			wait = 3
			step = 2
		2:
			main._on_action("bag_window")
			check(eco.is_bag_open() and main.hud.is_window_open(), "окно сумки открыто")
			check(win.buttons.has("cell_0") and win.buttons.has("cell_%d" % (Inventory.CAPACITY - 1)),
				"видны все %d ячеек" % Inventory.CAPACITY)
			check(not win.buttons.has("cell_%d" % Inventory.CAPACITY), "лишних ячеек нет")
			for e in InventoryWindow.EQUIP_SLOTS:
				check(win.buttons.has("equip_" + String(e[0])), "слот экипировки «%s»" % String(e[1]))
			var used := main.hud._window.find_child("used_label", true, false) as Label
			check(used != null and used.text == "Занято: 3/%d" % Inventory.CAPACITY, "занятость: %s" % (used.text if used else "?"))
			# Карточка надетого оружия — касание слота «Оружие»
			_press("equip_weapon")
			check(win.sel_kind == "equip" and win.sel_index == 0, "выбран слот «Оружие»")
			check(_card_title() == ItemData.item_name(game.weapon), "карточка надетого: %s" % _card_title())
			# Зелье: «Использовать»
			var pc := inv.find_cell("potion_hp_r1")
			_press("cell_%d" % pc)
			check(win.sel_kind == "cell" and win.sel_id == "potion_hp_r1", "выбрано зелье")
			check(_card_title() == ItemData.item_name("potion_hp_r1"), "карточка зелья")
			check(win.buttons.has("act_use") and win.buttons.has("act_move") and win.buttons.has("act_drop"),
				"кнопки зелья: использовать, переместить, выбросить")
			check(not win.buttons.has("act_sell"), "вдали от торговца продать нельзя")
			check(not win.buttons.has("act_equip"), "зелье не надеть")
			player.hp = 10
			var potions: int = inv.count("potion_hp_r1")
			_press("act_use")
			check(player.hp > 10 and inv.count("potion_hp_r1") == potions - 1, "зелье из карточки лечит")
			check(eco.is_bag_open(), "сумка открыта после использования")
			check(String(inv.cell(pc).get("id", "")) == "potion_hp_r1" and int(inv.cell(pc).get("n", 0)) == potions - 1,
				"в ячейке зелий стало меньше")
			# Свиток без погибших питомцев
			_press("cell_%d" % inv.find_cell("revive_scroll"))
			_press("act_use")
			check(inv.count("revive_scroll") == 1, "свиток не тратится без погибших питомцев")
			step = 3
		3:
			# Надеть меч из карточки: кинжал из основной руки ложится в ту же ячейку, второй — из второй руки в сумку
			inv.add("weapon_sword_1h_r1")
			var dc := inv.find_cell("weapon_sword_1h_r1")
			check(dc >= 0, "меч в ячейке %d" % dc)
			_press("cell_%d" % dc)
			check(win.buttons.has("act_equip") and not (win.buttons["act_equip"] as Button).disabled, "кнопка «Надеть»")
			check(not win.buttons.has("act_equip_off"), "к кинжалу меч во вторую руку не взять")
			var lines := _card_texts()
			check(lines.find("Физ. атака") >= 0 and lines.find("Скорость атаки") >= 0, "у оружия бонусы вида")
			check(_has_text_containing("разница с надетым"), "сравнение с надетым")
			check(_has_text_containing("можно два"), "хват: можно два меча")
			_press("act_equip")
			check(game.weapon == "weapon_sword_1h_r1", "надет меч")
			check(player.weapon_kind == "sword_1h" and game.offhand == "", "один меч: вторая рука свободна")
			check(String(inv.cell(dc).get("id", "")) == "weapon_dagger_r1", "кинжал лёг в ту же ячейку")
			check(inv.count("weapon_dagger_r1") == 2 and inv.find_cell("weapon_sword_1h_r1") == -1, "меч ушёл из сумки в слот")
			check(win.sel_kind == "equip", "после «Надеть» выбран слот оружия")
			check(inv.used_cells() == 5, "занято ячеек: %d (два кинжала вернулись в сумку)" % inv.used_cells())
			# Второй меч — кнопкой «Во 2-ю руку»
			inv.add("weapon_sword_1h_r1")
			_press("cell_%d" % inv.find_cell("weapon_sword_1h_r1"))
			check(win.buttons.has("act_equip_off") and not (win.buttons["act_equip_off"] as Button).disabled, "кнопка «Во 2-ю руку»")
			_press("act_equip_off")
			check(game.offhand == "weapon_sword_1h_r1" and player.weapon_kind == "dual_swords", "второй меч — два меча")
			check(win.sel_kind == "equip" and win.sel_index == 1, "выбран слот «2-я рука»")
			var off_slot: Button = win.buttons["equip_offhand"]
			check(not off_slot.call("_can_drop_data", Vector2.ZERO, {"inv_cell": inv.find_cell("weapon_dagger_r1")}),
				"кинжал к мечу во вторую руку не бросить")
			# Перетаскивание арбалета в слот «Оружие»
			var cc := inv.find_cell("crossbow_starter")
			var slot: Button = win.buttons["equip_weapon"]
			check(slot.call("_can_drop_data", Vector2.ZERO, {"inv_cell": cc}), "арбалет можно бросить в слот оружия")
			var pc := inv.find_cell("potion_hp_r1")
			check(not slot.call("_can_drop_data", Vector2.ZERO, {"inv_cell": pc}), "зелье в слот оружия не бросить")
			slot.call("_drop_data", Vector2.ZERO, {"inv_cell": cc})
			check(game.weapon == "crossbow_starter" and String(inv.cell(cc).get("id", "")) == "weapon_sword_1h_r1",
				"арбалет надет перетаскиванием, меч на его месте")
			check(game.offhand == "" and inv.count("weapon_sword_1h_r1") == 2, "арбалет двуручный: второй меч снят")
			step = 4
		4:
			# «Переместить»: касание предмета → «Переместить» → касание пустой ячейки
			var sc := inv.find_cell("revive_scroll")
			_press("cell_%d" % sc)
			_press("act_move")
			check(win.moving, "режим перемещения")
			check(win.buttons.has("act_move_cancel"), "кнопка «Отмена»")
			_press("cell_30")
			check(not win.moving, "перемещение завершено")
			check(String(inv.cell(30).get("id", "")) == "revive_scroll" and inv.cell(sc).is_empty(), "свиток в ячейке 30")
			check(win.sel_kind == "cell" and win.sel_index == 30, "выделение переехало со свитком")
			# Перетаскивание: свиток на ячейку 31, затем на ячейку с зельями (меняются местами)
			var cell31: Button = win.buttons["cell_31"]
			check(cell31.call("_can_drop_data", Vector2.ZERO, {"inv_cell": 30}), "в пустую ячейку бросить можно")
			cell31.call("_drop_data", Vector2.ZERO, {"inv_cell": 30})
			check(String(inv.cell(31).get("id", "")) == "revive_scroll" and inv.cell(30).is_empty(), "свиток перетащен")
			var pc := inv.find_cell("potion_hp_r1")
			(win.buttons["cell_%d" % pc] as Button).call("_drop_data", Vector2.ZERO, {"inv_cell": 31})
			check(String(inv.cell(pc).get("id", "")) == "revive_scroll" and String(inv.cell(31).get("id", "")) == "potion_hp_r1",
				"разные предметы меняются местами")
			var drag: Variant = (win.buttons["cell_31"] as Button).call("_get_drag_data", Vector2(10, 10))
			check(drag is Dictionary and int((drag as Dictionary).get("inv_cell", -1)) == 31, "из ячейки можно тащить значок")
			check((win.buttons["cell_39"] as Button).call("_get_drag_data", Vector2(10, 10)) == null, "пустую ячейку не тащат")
			# «Выбросить» с подтверждением и количеством
			inv.add("boar_tusk", 5)
			win.refresh()
			var tc := inv.find_cell("boar_tusk")
			_press("cell_%d" % tc)
			_press("act_drop")
			check(win.drop_confirm and win.buttons.has("act_drop_yes") and win.buttons.has("act_drop_no"), "подтверждение")
			check(inv.count("boar_tusk") == 5, "до подтверждения ничего не выброшено")
			_press("act_drop_plus")
			_press("act_drop_plus")
			check(win.drop_count == 3, "выбросить 3 (%d)" % win.drop_count)
			_press("act_drop_yes")
			check(inv.count("boar_tusk") == 2 and int(inv.cell(tc).get("n", 0)) == 2, "выброшено 3 клыка")
			_press("act_drop")
			_press("act_drop_no")
			check(not win.drop_confirm and inv.count("boar_tusk") == 2, "отмена — ничего не выброшено")
			_press("act_drop")
			_press("act_drop_all")
			_press("act_drop_yes")
			check(inv.count("boar_tusk") == 0 and inv.find_cell("boar_tusk") == -1, "выброшена вся стопка")
			check(win.sel_kind == "", "выделение снято")
			# Сортировка
			_press("sort")
			var used: int = inv.used_cells()
			var ok := true
			for i in used:
				if inv.cell(i).is_empty():
					ok = false
			check(ok, "после сортировки предметы в первых %d ячейках" % used)
			check(ItemData.is_weapon(String(inv.cell(0).get("id", ""))), "оружие первым")
			# Все предметы: карточка строится для каждого
			for key in ItemData.ITEMS:
				inv.add(String(key), 1)
			win.refresh()
			for key in ItemData.ITEMS:
				var id := String(key)
				var c := inv.find_cell(id)
				if id == game.weapon:
					continue
				check(c >= 0, "%s в ячейке" % id)
				_press("cell_%d" % c)
				check(_card_title() == ItemData.item_name(id), "карточка «%s»" % ItemData.item_name(id))
			# Закрыть повторным действием
			main._on_action("bag_window")
			check(not main.hud.is_window_open() and not eco.is_bag_open(), "сумка закрывается повторным действием")
			# К торговцу
			player.global_position = Vector3(0, 0.1, -1.5)
			wait = 3
			step = 5
		5:
			# Продажа из сумки рядом с торговцем
			inv.add("wolf_pelt", 4)
			main._on_action("bag_window")
			var wc := inv.find_cell("wolf_pelt")
			_press("cell_%d" % wc)
			check(win.buttons.has("act_sell") and win.buttons.has("act_sell_all"), "рядом с торговцем можно продать")
			var gold: int = game.gold
			var have: int = inv.count("wolf_pelt")
			var price: int = int(ItemData.get_item("wolf_pelt")["sell"])
			_press("act_sell")
			check(game.gold == gold + price and inv.count("wolf_pelt") == have - 1, "продана шкура")
			_press("act_sell_all")
			check(game.gold == gold + price * have and inv.count("wolf_pelt") == 0, "проданы все шкуры")
			# Выше в сумку добавлялось по одному каждому предмету — запасной экземпляр надетого оружия лежит в
			# ячейке, а сам надетый ячейку не занимает
			var in_cells := 0
			for cd: Dictionary in inv.cells():
				if not cd.is_empty() and String(cd["id"]) == game.weapon:
					in_cells += int(cd["n"])
			check(in_cells == inv.count(game.weapon) - 1, "надетое оружие в ячейках не лежит (продать нельзя): %d из %d"
				% [in_cells, inv.count(game.weapon)])
			# Окно торговца: товары, сумка и карточка
			main._on_action("shop")
			check(eco.is_shop_open(), "окно торговца открыто")
			check(win.seller == "merchant" and win.buttons.has("good_potion_hp_r1") and win.buttons.has("good_revive_scroll"),
				"товары торговца: зелье, свиток воскрешения")
			# Карты существ продаёт Учитель Кирк, у торговца их нет
			for id in ["card_panther", "card_turtle", "card_pheasant", "mirror_card", "card_wolf", "card_wolf_soul",
					"card_boar", "card_golem"]:
				check(not win.buttons.has("good_" + String(id)), "у торговца не продаётся: %s" % id)
			var kirk_goods := InventoryWindow.goods(game.class_id, "kirk")
			check(kirk_goods.has("card_panther") and kirk_goods.has("mirror_card") and not kirk_goods.has("card_wolf"),
				"карты существ — у Учителя Кирка: %s" % [kirk_goods])
			# Оружия у торговца нет — оно у Оружейника Бранда
			check(not win.buttons.has("good_dagger_steel") and not win.buttons.has("good_crossbow_starter"),
				"у торговца оружия нет")
			check(not win.buttons.has("good_boar_tusk"), "трофеи не продаются")
			check(win.buttons.has("cell_0"), "сумка в окне торговца")
			_press("good_potion_hp_r1")
			check(win.sel_kind == "good" and win.buttons.has("act_buy") and win.buttons.has("act_buy5"), "карточка товара")
			game.gold = 100
			var potions: int = inv.count("potion_hp_r1")
			_press("act_buy5")
			check(game.gold == 50 and inv.count("potion_hp_r1") == potions + 5, "куплено 5 зелий")
			# Продажа в окне торговца — из ячейки сумки
			var sc := inv.find_cell("shell_plate")
			_press("cell_%d" % sc)
			check(win.buttons.has("act_sell"), "продажа из сумки в окне торговца")
			gold = game.gold
			_press("act_sell")
			check(game.gold == gold + int(ItemData.get_item("shell_plate")["sell"]), "продана пластина")
			check(eco.is_shop_open(), "окно торговца открыто после сделок")
			main.hud.close_window()
			# К Оружейнику Бранду
			var ws: Npc = main.npcs.npc("weaponsmith")
			var fwd := Vector3(-sin(ws.face_yaw), 0, -cos(ws.face_yaw))
			var to := ws.global_position + fwd * 1.8
			if IslandWorld.current != null:
				to.y = IslandWorld.current.height_at(to.x, to.z) + 0.1
			player.global_position = to
			wait = 4
			step = 50
		50:
			# Лавка оружейника: «Торговля» в диалоге
			main.npcs.talk_to("weaponsmith")
			var tb: Button = main.npcs.buttons.get("opt_trade")
			check(tb != null, "у оружейника — «Торговля»")
			if tb != null:
				tb.pressed.emit()
			check(eco.is_shop_open() and win.seller == "weaponsmith", "окно оружейника открыто")
			# Наёмнику — его оружие (кинжалы, мечи, арбалет), лука у него нет
			check(win.buttons.has("good_dagger_steel") and win.buttons.has("good_crossbow_starter") and not win.buttons.has("good_weapon_bow_r1"), "оружие Наёмника в товарах, лука нет")
			check(not win.buttons.has("good_potion_hp_r1"), "зелий у оружейника нет")
			_press("good_dagger_steel")
			check(not win.buttons.has("act_buy5"), "оружие — по одному")
			check(_has_text_containing("разница с надетым"), "оружие сравнивается с надетым")
			game.gold = 10
			_press("act_buy")
			check(not inv.has("dagger_steel", 2) and game.gold == 10, "без золота не купить")
			game.gold = 500
			# Выше в сумку клали по одному каждому предмету игры (их стало больше 40 ячеек) — освободим место:
			# уберём оружие 1-го и 2-го ранга (не надетое), зелья всех рангов, броню и украшения (ничего не надето)
			for key in ItemData.ITEMS:
				var wid := String(key)
				if wid.begins_with("weapon_") and wid != game.weapon and wid != game.offhand:
					inv.remove(wid, inv.count(wid))
				elif ItemData.is_potion(wid) or ItemData.is_gear(wid) or ItemData.is_cube(wid):
					inv.remove(wid, inv.count(wid))
			var steel: int = inv.count("dagger_steel")
			var free_slots: int = inv.room_for("dagger_steel")
			_press("act_buy")
			check(inv.count("dagger_steel") == steel + 1 and game.gold == 500 - int(ItemData.get_item("dagger_steel")["buy"]),
				"куплен стальной кинжал (было %d, стало %d, золото %d, место %d, в продаже %s, сообщение «%s»)" % [steel,
				inv.count("dagger_steel"), game.gold, free_slots, InventoryWindow.goods(game.class_id, "weaponsmith").has("dagger_steel"),
				main.hud._msg_label.text])
			# Сумка полна: покупка не проходит (клыков в сумке нет — для проверки добычи ниже)
			inv.remove("boar_tusk", inv.count("boar_tusk"))
			var room := Inventory.CAPACITY - inv.used_cells()
			inv.add("sword_steel", room)
			check(inv.is_full(), "сумка заполнена (%d/%d)" % [inv.used_cells(), Inventory.CAPACITY])
			win.refresh()
			_press("good_crossbow_heavy")
			var gold: int = game.gold
			# Тяжёлый арбалет мог остаться в сумке с проверки карточек выше — сравниваем количество
			var heavy := inv.count("crossbow_heavy")
			_press("act_buy")
			check(game.gold == gold and inv.count("crossbow_heavy") == heavy, "в полную сумку не купить")
			check(last_hud_text() == "Сумка полна", "сообщение «Сумка полна»: %s" % last_hud_text())
			main.hud.close_window()
			# Добыча при полной сумке остаётся лежать
			check(inv.room_for("boar_tusk") == 0, "клыкам нет места")
			drop = eco.spawn_drop(player.global_position + Vector3(0.8, 0, 0), {"boar_tusk": 2})
			wait = 40
			step = 6
		6:
			check(is_instance_valid(drop) and not drop.is_queued_for_deletion(), "мешочек лежит: сумка полна")
			check(not inv.has("boar_tusk"), "клыки не взяты")
			check(last_hud_text() == "Сумка полна", "сообщение «Сумка полна» при добыче")
			# Освобождаем ячейку — мешочек подбирается при следующей попытке
			inv.remove_at(inv.find_cell("sword_steel"))
			wait = int(LootDrop.RETRY_TIME * 60.0) + 20
			step = 7
		7:
			check(not is_instance_valid(drop), "мешочек подобран, когда появилось место")
			check(inv.count("boar_tusk") == 2, "клыки в сумке")
			_save_load()
			ok_done()


# ---------- Без окна: Inventory ----------

func _unit_stacks() -> void:
	var inv := Inventory.new()
	inv.add("boar_tusk", 150)
	check(inv.used_cells() == 2 and int(inv.cell(0).get("n", 0)) == 99 and int(inv.cell(1).get("n", 0)) == 51,
		"150 клыков — стопки 99 + 51")
	check(inv.room_for("boar_tusk") == (Inventory.CAPACITY - 2) * 99 + 48, "место для клыков: %d" % inv.room_for("boar_tusk"))
	check(ItemData.stack_size("dagger_steel") == 1 and ItemData.stack_size("potion_hp_r1") == ItemData.STACK
		and ItemData.stack_size("armor_helmet_r1") == 1 and ItemData.stack_size("ring_hp_r1") == 1, "размер стопок (броня и украшения по 1)")
	inv.add("dagger_steel", 3)
	check(inv.used_cells() == 5, "оружие — по одному в ячейке")
	inv.add("sword_steel", Inventory.CAPACITY - 5)
	check(inv.is_full() and inv.used_cells() == Inventory.CAPACITY, "сумка полна")
	check(inv.room_for("potion_hp_r1") == 0 and inv.try_add("potion_hp_r1", 3) == 0 and not inv.has("potion_hp_r1"),
		"в полную сумку новый предмет не кладётся")
	check(inv.try_add("boar_tusk", 100) == 48 and inv.count("boar_tusk") == 198, "неполная стопка добирается до 99")
	inv.add("wolf_pelt", 1)
	check(inv.cell_count() == Inventory.CAPACITY + 1 and inv.count("wolf_pelt") == 1,
		"принудительный add сверх вместимости не теряет предмет")
	check(inv.remove_at(Inventory.CAPACITY) == 1 and inv.cell_count() == Inventory.CAPACITY, "лишняя ячейка исчезла")
	check(inv.remove("boar_tusk", 100) and int(inv.cell(1).get("n", 0)) == 0 and int(inv.cell(0).get("n", 0)) == 98,
		"remove снимает с последних стопок")
	# Надетое оружие ячейку не занимает
	var inv2 := Inventory.new()
	inv2.add("weapon_dagger_r1", 1)
	inv2.add("crossbow_starter", 1)
	inv2.equipped = "weapon_dagger_r1"
	check(inv2.used_cells() == 1 and inv2.find_cell("weapon_dagger_r1") == -1, "надетое оружие — не в ячейке")
	inv2.equipped = "crossbow_starter"
	check(inv2.find_cell("weapon_dagger_r1") >= 0 and inv2.find_cell("crossbow_starter") == -1, "смена надетого")


func _unit_move_sort() -> void:
	var inv := Inventory.new()
	inv.add("potion_hp_r1", 10)
	inv.add("boar_tusk", 3)
	check(String(inv.cell(0).get("id", "")) == "potion_hp_r1" and String(inv.cell(1).get("id", "")) == "boar_tusk",
		"раскладка по порядку: расходники, затем трофеи")
	check(inv.move(0, 5) and inv.cell(0).is_empty() and String(inv.cell(5).get("id", "")) == "potion_hp_r1", "в пустую ячейку")
	check(inv.move(1, 5) and String(inv.cell(5).get("id", "")) == "boar_tusk" and String(inv.cell(1).get("id", "")) == "potion_hp_r1",
		"разные предметы меняются местами")
	check(not inv.move(0, 3), "пустую ячейку не переложить")
	inv.add("potion_hp_r1", 95)
	check(int(inv.cell(1).get("n", 0)) == 99 and String(inv.cell(0).get("id", "")) == "potion_hp_r1" and int(inv.cell(0).get("n", 0)) == 6,
		"новое докладывается в неполную стопку, остаток — в первую пустую ячейку")
	inv.remove_at(1, 10)
	check(inv.move(0, 1) and int(inv.cell(1).get("n", 0)) == 95 and inv.cell(0).is_empty(), "стопки складываются")
	inv.add("potion_hp_r1", 10)
	check(int(inv.cell(1).get("n", 0)) == 99 and int(inv.cell(0).get("n", 0)) == 6, "стопка 99 и 6")
	inv.move(0, 12)
	inv.remove_at(1, 3)
	check(inv.move(12, 1) and int(inv.cell(1).get("n", 0)) == 99 and int(inv.cell(12).get("n", 0)) == 3,
		"что не влезло в стопку, остаётся на месте")
	inv.add("dagger_steel", 1)
	inv.add("mirror_card", 1)
	inv.add("card_panther", 2)
	inv.add("card_wolf_soul", 1)
	inv.move(inv.find_cell("dagger_steel"), 20)
	inv.sort()
	var order: Array = []
	for c in inv.cells():
		var d: Dictionary = c
		if not d.is_empty():
			order.append(String(d["id"]))
	check(order == ["dagger_steel", "potion_hp_r1", "potion_hp_r1", "card_wolf_soul", "card_panther", "mirror_card", "boar_tusk"],
		"сортировка: оружие, расходники, карты (с душой раньше пустых, зеркальная в конце), трофеи: %s" % [order])
	check(int(inv.cell(1).get("n", 0)) == 99 and int(inv.cell(2).get("n", 0)) == 3, "стопки собраны при сортировке")


func _unit_layout() -> void:
	var inv := Inventory.new()
	inv.add("potion_hp_r1", 3)
	inv.add("wolf_pelt", 2)
	inv.add("crossbow_starter", 1)
	inv.move(inv.find_cell("wolf_pelt"), 17)
	inv.move(inv.find_cell("crossbow_starter"), 39)
	var arr: Array = JSON.parse_string(JSON.stringify(inv.layout_to_array()))
	var inv2 := Inventory.new()
	inv2.from_dict(JSON.parse_string(JSON.stringify(inv.to_dict())))
	inv2.load_layout(arr)
	check(String(inv2.cell(17).get("id", "")) == "wolf_pelt" and int(inv2.cell(17).get("n", 0)) == 2, "раскладка: шкуры в 17")
	check(String(inv2.cell(39).get("id", "")) == "crossbow_starter", "раскладка: арбалет в 39")
	check(inv2.count("potion_hp_r1") == 3, "количества восстановлены")
	# Старый формат: раскладки нет — по порядку сортировки
	var old := Inventory.new()
	old.from_dict({"boar_tusk": 2, "potion_hp_r1": 3, "sword_steel": 1})
	old.load_layout([])
	check(String(old.cell(0).get("id", "")) == "sword_steel" and String(old.cell(1).get("id", "")) == "potion_hp_r1"
		and String(old.cell(2).get("id", "")) == "boar_tusk", "старое сохранение разложено по порядку")
	# Раскладка расходится с количествами: верят количествам
	var bad := Inventory.new()
	bad.from_dict({"potion_hp_r1": 2})
	bad.load_layout([{"id": "potion_hp_r1", "n": 5}, {"id": "no_such_item", "n": 1}, {}, "мусор"])
	check(bad.count("potion_hp_r1") == 2 and int(bad.cell(0).get("n", 0)) == 2 and bad.used_cells() == 1,
		"лишнее из раскладки отброшено")


## Заточенные и сломанные вещи — свои id: оружие +N по одной в ячейке, лом стопкой, сильнее заточенная — раньше
## в сортировке, раскладка и количества переживают сохранение.
func _unit_enchanted() -> void:
	var inv := Inventory.new()
	var e3 := ItemData.enchanted_id("weapon_sword_1h_r1", 3)
	var br := ItemData.broken_id("weapon_sword_1h_r1")
	check(e3 == "weapon_sword_1h_r1+3" and br == "weapon_sword_1h_r1!broken", "id: %s, %s" % [e3, br])
	inv.add("weapon_sword_1h_r1", 1)
	inv.add(e3, 2)
	inv.add(br, 3)
	inv.add("cube_attack_r1", 5)
	check(ItemData.stack_size(e3) == 1 and ItemData.stack_size(br) == ItemData.BROKEN_STACK and ItemData.stack_size("cube_attack_r1") == 99,
		"стопки: заточенное по 1, лом до %d, кубы до 99" % ItemData.BROKEN_STACK)
	check(inv.used_cells() == 5, "занято ячеек: %d (меч, 2 меча +3, лом, кубы)" % inv.used_cells())
	inv.sort()
	check(String(inv.cell(0).get("id", "")) == e3 and String(inv.cell(2).get("id", "")) == "weapon_sword_1h_r1",
		"сортировка: меч +3 раньше простого (%s, %s, %s)" % [inv.cell(0).get("id"), inv.cell(1).get("id"), inv.cell(2).get("id")])
	check(String(inv.cell(inv.used_cells() - 1).get("id", "")) == br, "лом — в конце: %s" % inv.cell(inv.used_cells() - 1).get("id"))
	check(ItemData.type_name(br) == "Лом" and ItemData.type_name("cube_attack_r1") == "Куб чарования", "типы: лом, куб")
	var arr: Array = JSON.parse_string(JSON.stringify(inv.layout_to_array()))
	var inv2 := Inventory.new()
	inv2.from_dict(JSON.parse_string(JSON.stringify(inv.to_dict())))
	inv2.load_layout(arr)
	check(inv2.count(e3) == 2 and inv2.count(br) == 3 and String(inv2.cell(0).get("id", "")) == e3,
		"заточенное и лом — в сохранении раскладки")
	# replace_one: штука уходит, новая ложится в ту же ячейку
	var c := inv2.find_cell("weapon_sword_1h_r1")
	inv2.replace_one("weapon_sword_1h_r1", ItemData.enchanted_id("weapon_sword_1h_r1", 1))
	check(String(inv2.cell(c).get("id", "")) == "weapon_sword_1h_r1+1", "заточка — в той же ячейке")


## Сохранение раскладки через save.json и загрузка сохранения без раскладки.
func _save_load() -> void:
	var inv: Inventory = game.inventory
	var c := inv.find_cell("boar_tusk")
	inv.move(c, 33)
	check(game.save_game(), "игра сохранена")
	inv.sort()
	check(game.load_game(), "игра загружена")
	check(String(game.inventory.cell(33).get("id", "")) == "boar_tusk", "клыки снова в ячейке 33")
	var in_cells := 0
	for cd: Dictionary in game.inventory.cells():
		if not cd.is_empty() and String(cd["id"]) == game.weapon:
			in_cells += int(cd["n"])
	# Запасные экземпляры надетого оружия могут лежать в ячейках, сам надетый — нет
	check(in_cells == game.inventory.count(game.weapon) - 1, "надетое оружие после загрузки — в слоте")
	game.from_dict({"name": "Старая", "race": "dark_elf", "class": "assassin", "level": 3,
		"inventory": {"hp_potion": 2, "boar_tusk": 1}})
	var ids: Array = []
	for e in game.inventory.cells():
		var d: Dictionary = e
		if not d.is_empty():
			ids.append(String(d["id"]))
	check(ids.size() == game.inventory.used_cells() and ids.has("potion_hp_r1") and ids.has("boar_tusk"),
		"старое сохранение без раскладки: %s" % [ids])
	check(game.inventory.find_cell(game.weapon) == -1, "старое сохранение: надетое оружие не в ячейке")


# ---------- Помощники ----------

func _press(node_name: String) -> void:
	var win: InventoryWindow = main.economy.window
	var b: Button = win.buttons.get(node_name)
	check(b != null, "кнопка %s есть в окне" % node_name)
	if b != null:
		b.pressed.emit()


## Название в карточке предмета.
func _card_title() -> String:
	if not main.hud.is_window_open():
		return ""
	var l := _find_live(main.hud._window, "card_title") as Label
	return l.text if l != null else ""


## Тексты всех надписей открытого окна.
func _card_texts() -> Array:
	var res: Array = []
	if main.hud.is_window_open():
		_collect(main.hud._window, res)
	return res


func _has_text_containing(part: String) -> bool:
	for t in _card_texts():
		if String(t).contains(part):
			return true
	return false


func _collect(n: Node, res: Array) -> void:
	var l := n as Label
	if l != null:
		res.append(l.text)
	for c in n.get_children():
		_collect(c, res)


## Узел по имени, не помеченный на удаление (окно перестраивается целиком).
func _find_live(n: Node, node_name: String) -> Node:
	if n.name == node_name and not n.is_queued_for_deletion():
		return n
	for c in n.get_children():
		var r := _find_live(c, node_name)
		if r != null:
			return r
	return null


func last_hud_text() -> String:
	return main.hud._msg_label.text
