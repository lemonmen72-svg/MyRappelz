extends "res://tests/test_base.gd"
## Предметы и торговля: добыча мешочком и подбор, торговец и безопасная зона, покупка и продажа,
## окна торговца и сумки (InventoryWindow: сетка, карточка, кнопки действий), зелье с перезарядкой и счётчиком
## на кнопке. Подробно сумка — tests/test_inventory.gd.

## Сколько фазанов можно убить в поисках добычи (шанс пера 0.6, пустой мешок ~35%).
const MAX_KILLS := 12

var mob: Mob = null
var kills := 0
var drop: LootDrop = null
var drop_items: Dictionary = {}
var counts_before: Dictionary = {}
var old_drop: LootDrop = null


func run_step() -> void:
	var player: Player = main.player
	var hud: HUD = main.hud
	var eco: Economy = main.economy
	match step:
		0:
			check(eco.merchant != null and eco.merchant.is_inside_tree(), "торговец в мире")
			var mp := eco.merchant.global_position
			check(Vector2(mp.x, mp.z).length() < MobData.SAFE_RADIUS, "торговец в безопасной зоне")
			check(main.find_child("SafeZone", false, false) != null, "круг безопасной зоны на земле")
			check(_button_label("potion") == "Зелье\n3", "на кнопке зелья количество: %s" % _button_label("potion"))
			check(not _shop_visible(), "кнопка «Торговец» скрыта на старте (игрок далеко)")
			step = 1
		1:
			mob = find_mob("pheasant")
			check(mob != null, "найден фазан")
			step = 2
		2:
			if mob_ok(mob):
				stand_near(mob)
				player.try_attack()
				if mob_ok(mob):
					return
			kills += 1
			var found := _fresh_drop()
			if found == null:
				print("  убит фазан %d: без добычи" % kills)
				check(kills < MAX_KILLS, "добыча выпала хотя бы за %d фазанов" % MAX_KILLS)
				step = 1
				return
			drop = found
			drop_items = drop.items.duplicate()
			check(not drop_items.is_empty(), "мешочек с добычей: %s (фазан %d)" % [LootDrop.describe(drop_items), kills])
			counts_before = {}
			for key in drop_items:
				var id: String = key
				counts_before[id] = game.inventory.count(id)
			# Отходим, чтобы проверить, что издалека мешочек не подбирается
			player.global_position = drop.global_position + Vector3(6, 0.1, 0)
			wait = 45
			step = 3
		3:
			player.hp = player.max_hp
			check(is_instance_valid(drop) and not drop.is_queued_for_deletion(), "мешочек лежит, пока игрок далеко")
			for key in drop_items:
				var id: String = key
				var before: int = counts_before[id]
				check(game.inventory.count(id) == before, "издалека %s не подобран" % id)
			player.global_position = drop.global_position + Vector3(1.0, 0.1, 0)
			wait = 10
			step = 4
		4:
			player.hp = player.max_hp
			check(not is_instance_valid(drop), "мешочек подобран и исчез")
			for key in drop_items:
				var id: String = key
				var n: int = drop_items[key]
				var before: int = counts_before[id]
				check(game.inventory.count(id) == before + n, "в сумке %s: %d -> %d" % [id, before, game.inventory.count(id)])
			check(_button_label("potion") == "Зелье\n%d" % game.inventory.count("hp_potion"),
				"счётчик зелий на кнопке обновился")
			# Мешочек исчезает со временем
			old_drop = eco.spawn_drop(player.global_position + Vector3(15, 0, 0), {"boar_tusk": 1})
			check(old_drop.is_in_group("loot_drops"), "мешочек создан вручную")
			old_drop.age = LootDrop.LIFETIME - 0.05
			wait = 10
			step = 5
		5:
			check(not is_instance_valid(old_drop), "мешочек исчез через %d с" % int(LootDrop.LIFETIME))
			player.global_position = Vector3(0, 0.1, -1.5)
			wait = 3
			step = 6
		6:
			check(_shop_visible(), "кнопка «Торговец» видна рядом с торговцем")
			player.global_position = Vector3(0, 0.1, 7.0)
			wait = 3
			step = 7
		7:
			check(not _shop_visible(), "кнопка «Торговец» скрыта вдали")
			main._on_action("shop")
			check(not hud.is_window_open(), "магазин не открывается вдали от торговца")
			player.global_position = Vector3(0, 0.1, -1.5)
			wait = 3
			step = 8
		8:
			check(_shop_visible(), "кнопка «Торговец» снова видна")
			main._on_action("shop")
			check(hud.is_window_open() and eco.is_shop_open(), "окно магазина открыто")
			check(_find_button("good_boar_tusk") == null, "трофеи не продаются торговцем")
			check(_find_button("good_card_panther") == null and _find_button("good_mirror_card") == null,
				"карты существ продаёт не торговец, а Учитель Кирк")
			check(not eco.buy("card_panther", 1, "merchant"), "у торговца карту не купить")
			# Покупка свитка: касание товара → «Купить»
			game.gold = 100
			var scrolls: int = game.inventory.count("revive_scroll")
			_press("good_revive_scroll")
			_press("act_buy")
			check(game.gold == 70 and game.inventory.count("revive_scroll") == scrolls + 1,
				"куплен свиток: золото %d, свитков %d" % [game.gold, game.inventory.count("revive_scroll")])
			# Покупка ×5
			game.gold = 100
			var potions: int = game.inventory.count("hp_potion")
			_press("good_hp_potion")
			_press("act_buy5")
			check(game.gold == 50 and game.inventory.count("hp_potion") == potions + 5, "куплено 5 зелий")
			# Не хватает золота
			game.gold = 10
			scrolls = game.inventory.count("revive_scroll")
			_press("good_revive_scroll")
			_press("act_buy")
			check(game.gold == 10 and game.inventory.count("revive_scroll") == scrolls, "без золота покупка не проходит")
			check(hud.is_window_open() and eco.is_shop_open(), "окно магазина открыто после покупок")
			# Трофеи для продажи: окно перестроится само в следующем кадре
			game.inventory.add("boar_tusk", 3)
			wait = 2
			step = 9
		9:
			var tusks: int = game.inventory.count("boar_tusk")
			var gold: int = game.gold
			var price: int = ItemData.get_item("boar_tusk")["sell"]
			# Продажа — из ячейки сумки в окне торговца
			_press("cell_%d" % game.inventory.find_cell("boar_tusk"))
			_press("act_sell")
			check(game.gold == gold + price and game.inventory.count("boar_tusk") == tusks - 1, "продан 1 клык")
			_press("act_sell_all")
			check(game.gold == gold + price * tusks and game.inventory.count("boar_tusk") == 0, "проданы все клыки")
			check(game.inventory.find_cell("boar_tusk") == -1 and _find_button("act_sell") == null,
				"проданный трофей пропал из сумки")
			player.global_position = Vector3(0, 0.1, 7.0)
			wait = 3
			step = 10
		10:
			check(not hud.is_window_open() and not eco.is_shop_open(), "магазин закрылся, когда игрок отошёл")
			main._on_action("bag_window")
			check(hud.is_window_open() and eco.is_bag_open(), "окно сумки открыто")
			check(hud._window.find_child("CloseButton", true, false) != null, "в окне есть кнопка «Закрыть» (значок)")
			# Зелье из сумки
			check(eco.potion_cooldown_frac() == 0.0, "зелье готово")
			player.hp = 10
			var potions: int = game.inventory.count("hp_potion")
			_press("cell_%d" % game.inventory.find_cell("hp_potion"))
			_press("act_use")
			check(player.hp > 10 and game.inventory.count("hp_potion") == potions - 1, "зелье из сумки лечит")
			check(hud.is_window_open() and eco.is_bag_open(), "сумка открыта после использования")
			check(_button_label("potion") == "Зелье\n%d" % (potions - 1), "счётчик зелий на кнопке")
			# Перезарядка
			player.hp = 10
			main._on_action("potion")
			check(player.hp == 10 and game.inventory.count("hp_potion") == potions - 1, "зелье на перезарядке")
			check(eco.potion_cooldown_frac() > 0.5, "доля перезарядки %.2f" % eco.potion_cooldown_frac())
			# Закрытие кнопкой окна
			var close := hud._window.find_child("CloseButton", true, false) as Button
			if close != null:
				close.pressed.emit()
			check(not hud.is_window_open() and not eco.is_bag_open(), "сумка закрыта кнопкой «Закрыть»")
			wait = 2
			step = 11
		11:
			var panel: Panel = hud._buttons["potion"]["panel"]
			check(panel.modulate.a < 1.0, "кнопка зелья затемнена на перезарядке")
			# Пустая сумка
			var saved: Dictionary = game.inventory.to_dict()
			game.inventory.from_dict({})
			main._on_action("bag_window")
			var used := hud._window.find_child("used_label", true, false) as Label
			check(hud.is_window_open() and used != null and used.text == "Занято: 0/%d" % Inventory.CAPACITY,
				"пустая сумка: %s" % (used.text if used else "?"))
			check(_find_button("cell_0") != null, "пустые ячейки видны")
			check(_button_label("potion") == "Зелье\n0", "на кнопке 0 зелий")
			check(hud.button_icon("potion") != null and hud.button_icon("potion").count() == 0, "на значке зелья число 0")
			main._on_action("bag_window")
			check(not hud.is_window_open(), "сумка закрывается повторным действием")
			game.inventory.from_dict(saved)
			wait = 60 * 5 + 10
			step = 12
		12:
			check(eco.potion_cooldown_frac() == 0.0, "перезарядка зелья прошла")
			var panel: Panel = hud._buttons["potion"]["panel"]
			check(panel.modulate.a == 1.0, "кнопка зелья снова яркая")
			player.hp = 10
			main._on_action("potion")
			check(player.hp > 10, "после перезарядки зелье снова работает")
			ok_done()


## Новый (ещё не подобранный) мешочек на земле.
func _fresh_drop() -> LootDrop:
	for n in get_tree().get_nodes_in_group("loot_drops"):
		var d := n as LootDrop
		if d != null and not d.is_queued_for_deletion():
			return d
	return null


func _shop_visible() -> bool:
	var p: Panel = main.hud._buttons["shop"]["panel"]
	return p.visible


func _button_label(id: String) -> String:
	var l: Label = main.hud._buttons[id]["label"]
	return l.text


## Кнопка открытого окна сумки или торговца (InventoryWindow.buttons: good_<id>, cell_<i>, act_buy, act_sell…).
func _find_button(node_name: String) -> Button:
	var hud: HUD = main.hud
	var win: InventoryWindow = main.economy.window
	if not hud.is_window_open() or not win.is_open():
		return null
	return win.buttons.get(node_name) as Button


func _press(node_name: String) -> void:
	var b := _find_button(node_name)
	check(b != null, "кнопка %s есть в окне" % node_name)
	if b != null:
		b.pressed.emit()


## Кнопка по тексту (рекурсивно).
func _find_text(n: Node, text: String) -> Button:
	var b := n as Button
	if b != null and b.text == text:
		return b
	for c in n.get_children():
		var r := _find_text(c, text)
		if r != null:
			return r
	return null
