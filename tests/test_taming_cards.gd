extends "res://tests/test_base.gd"
## Приручение картами существ: предметы-карты (пустые, с душой, зеркальная), тиры и цвета, описание карты,
## покупка карты у Учителя Кирка (у торговца карт нет), «Приручить» без карты — отказ с подсказкой, где взять; с картой — метка, победа,
## успех (карта с душой), «Сформировать» из карточки в сумке и из окна «Питомцы»; неудача без зеркальной карты —
## карта ломается, с зеркальной — ломается зеркальная; значок приручения на панели цели; карта с душой при полной
## сумке; кабана и каменного стража приручить нельзя (карт нет, фиолетовый значок, «Приручить» отказывает);
## перевод кристаллов души и убранных карт кабана и стража из старого сохранения.

const SPECIES := ["panther", "turtle", "pheasant", "wolf"]
## Звери, которых нельзя приручить (решение Максима).
const NO_TAME := ["boar", "golem"]

var mob: Mob = null


func race_class() -> Array:
	return ["dark_elf", "assassin"]


func run_step() -> void:
	var player: Player = main.player
	var tm: Taming = main.taming
	var inv: Inventory = game.inventory
	var hud: HUD = main.hud
	match step:
		0:
			_unit_items()
			_unit_lines()
			_unit_full_bag()
			for sp in SPECIES:
				check(not inv.has("card_" + String(sp)), "карт существ у нового героя нет: %s" % sp)
			check(not inv.has("crystal_common"), "кристаллов души у нового героя нет")
			check(game.gold >= int(ItemData.get_item("card_panther")["buy"]), "стартового золота хватает на карту: %d"
				% game.gold)
			# Рядом с Учителем Кирком (он продаёт карты существ)
			var kp: Vector3 = main.npcs.kirk.global_position
			var to_c := Vector3(-kp.x, 0, -kp.z).normalized()
			player.global_position = kp + to_c * 2.0 + Vector3(0, 0.1, 0)
			wait = 3
			step = 1
		1:
			# Покупка карты фазана у Учителя Кирка
			var eco: Economy = main.economy
			eco.open_shop("kirk")
			check(eco.is_shop_open() and eco.window.seller == "kirk", "окно торговли Учителя Кирка открыто")
			var win: InventoryWindow = eco.window
			for id in ["card_panther", "card_turtle", "card_pheasant", "mirror_card"]:
				check(win.buttons.has("good_" + id), "Учитель Кирк продаёт: %s" % ItemData.item_name(id))
			for id in ["card_panther", "mirror_card"]:
				check(not InventoryWindow.goods(game.class_id, "merchant").has(id), "у торговца нет: %s" % id)
			for id in ["card_wolf", "card_panther_soul", "card_boar", "card_golem"]:
				check(not win.buttons.has("good_" + id), "не продаётся: %s" % id)
			game.gold = 100
			_press("good_card_pheasant")
			_press("act_buy")
			check(inv.count("card_pheasant") == 1 and game.gold == 100 - int(ItemData.get_item("card_pheasant")["buy"]),
				"куплена карта фазана, золото %d" % game.gold)
			main.hud.close_window()
			step = 2
		2:
			# Без карты вида: отказ и подсказка, где взять; значок «нужна карта»
			mob = find_mob("wolf")
			check(mob != null, "найден волк")
			stand_near(mob, 3.0)
			player._set_target(mob)
			check(hud.target_tame_state == Taming.BADGE_NEED_CARD and hud.target_card_tier == "basic",
				"значок волка: нужна карта, коричневый тир (%s, %s)" % [hud.target_tame_state, hud.target_card_tier])
			check(hud._tame_badge.visible and hud._tame_tier.visible, "значок и квадратик тира видны")
			tm.cooldown = 0.0
			main._on_action("tame")
			check(tm.marked == null and not mob.tame_marked, "без карты волка метка не ставится")
			var msg: String = hud._msg_label.text
			check(msg.contains("Нужна карта существа: Волк") and msg.contains("выпадает из волка"), "сообщение: " + msg)
			player._set_target(null)
			check(hud.target_tame_state == "" and not hud._tame_badge.visible, "без цели значок скрыт")
			player.global_position = Vector3(0, 0.1, 2)
			mob.target = null
			mob.returning = true
			step = 3
		3:
			# С картой фазана: зелёный значок, метка, победа, успех — карта с душой
			mob = find_mob("pheasant")
			check(mob != null, "найден фазан")
			stand_near(mob, 3.0)
			player._set_target(mob)
			check(hud.target_tame_state == Taming.BADGE_READY, "значок фазана зелёный: карта в сумке")
			tm.cooldown = 0.0
			main._on_action("tame")
			check(tm.marked == mob and mob.tame_marked, "метка на фазане")
			check(hud._msg_label.text.contains("шанс 70%"), "в сообщении шанс базовой карты: " + hud._msg_label.text)
			tm.force_roll = 0.0
			mob.take_damage(mob.hp + 5, player)
			tm.force_roll = -1.0
			check(tm.marked == null and not mob.tame_marked, "метка снята после победы")
			check(not inv.has("card_pheasant") and inv.count("card_pheasant_soul") == 1, "карта фазана стала картой с душой")
			check(hud._msg_label.text.contains("Душа фазана поймана в карту"), "сообщение: " + hud._msg_label.text)
			check(game.pets.is_empty(), "питомец появится только после формирования")
			player.global_position = Vector3(0, 0.1, 2)
			wait = 2
			step = 4
		4:
			# «Сформировать» из карточки карты в сумке
			var eco: Economy = main.economy
			var win: InventoryWindow = eco.window
			eco.open_bag()
			win.select_cell(inv.find_cell("card_pheasant_soul"))
			check(win.sel_id == "card_pheasant_soul", "выбрана карта с душой")
			check(win.buttons.has("act_form") and not win.buttons.has("act_use"), "кнопка «Сформировать»")
			check(_has_text("Сформируйте существо"), "в описании — что делать с картой")
			_press("act_form")
			check(game.pets.size() == 1 and String(game.pets[0]["species"]) == "pheasant", "в коллекции фазан")
			check(String(game.pets[0]["name"]) == PetData.stage_name("pheasant", 1) and int(game.pets[0]["level"]) == 1,
				"имя — 1-я стадия, ур. 1")
			check(not inv.has("card_pheasant_soul"), "карта с душой израсходована")
			check(game.active_pet == 0, "новое существо сразу призвано")
			main.hud.close_window()
			# Окно «Питомцы»: блок «Формирование» со списком карт с душой
			inv.add("card_wolf_soul", 1)
			main._on_action("pets_window")
			var pm: PetManager = main.pets
			check(pm.window_buttons.has("form_card_wolf_soul"), "в окне питомцев — «Сформировать» для карты волка")
			(pm.window_buttons["form_card_wolf_soul"] as Button).pressed.emit()
			check(game.pets.size() == 2 and String(game.pets[1]["species"]) == "wolf", "волк сформирован из окна питомцев")
			check(not inv.has("card_wolf_soul"), "карта волка с душой израсходована")
			check(not pm.window_buttons.has("form_card_wolf_soul"), "окно обновилось: карт с душой нет")
			main.hud.close_window()
			step = 5
		5:
			# Неудача без зеркальной карты: карта существа ломается
			# Зеркальная карта могла выпасть из фазана — убираем
			inv.remove(ItemData.MIRROR_CARD, inv.count(ItemData.MIRROR_CARD))
			check(not inv.has(ItemData.MIRROR_CARD), "зеркальных карт нет")
			inv.add("card_wolf", 2)
			var cards := inv.count("card_wolf")
			mob = find_mob("wolf")
			check(mob != null, "найден волк")
			stand_near(mob, 3.0)
			player._set_target(mob)
			tm.cooldown = 0.0
			main._on_action("tame")
			check(tm.marked == mob, "метка на волке")
			tm.force_roll = 0.99
			mob.take_damage(mob.hp + 5, player)
			check(inv.count("card_wolf") == cards - 1 and not inv.has("card_wolf_soul"), "карта волка сломалась")
			check(hud._msg_label.text.contains("Карта существа сломалась"), "сообщение: " + hud._msg_label.text)
			# Неудача с зеркальной картой: ломается она, карта существа цела
			inv.add(ItemData.MIRROR_CARD, 2)
			cards = inv.count("card_wolf")
			mob = find_mob("wolf")
			check(mob != null, "найден второй волк")
			stand_near(mob, 3.0)
			player._set_target(mob)
			tm.cooldown = 0.0
			main._on_action("tame")
			check(tm.marked == mob, "метка на втором волке")
			mob.take_damage(mob.hp + 5, player)
			tm.force_roll = -1.0
			check(inv.count(ItemData.MIRROR_CARD) == 1 and inv.count("card_wolf") == cards, "сломалась зеркальная карта")
			check(hud._msg_label.text.contains("Зеркальная карта сломалась, карта существа цела"),
				"сообщение: " + hud._msg_label.text)
			check(game.pets.size() == 2, "неудачи не добавляют питомцев")
			player.global_position = Vector3(0, 0.1, 2)
			step = 6
		6:
			# Кабана и стража приручить нельзя: фиолетовый значок, «Приручить» отказывает
			check(Taming.badge_state("no_such_beast") == Taming.BADGE_NO, "неизвестного зверя приручить нельзя")
			for sp in NO_TAME:
				mob = find_mob(String(sp))
				check(mob != null, "найден зверь %s" % sp)
				if mob == null:
					continue
				stand_near(mob, 3.0)
				player._set_target(mob)
				check(hud.target_tame_state == Taming.BADGE_NO and hud.target_card_tier == "",
					"значок %s: нельзя приручить (%s)" % [sp, hud.target_tame_state])
				check(hud._tame_badge.visible and not hud._tame_tier.visible, "значок виден, квадратика тира нет: %s" % sp)
				tm.cooldown = 0.0
				var used: int = tm.attempts
				check(not tm.try_tame(), "«Приручить» на %s отказывает" % sp)
				main._on_action("tame")
				check(tm.marked == null and not mob.tame_marked, "метка на %s не ставится" % sp)
				check(hud._msg_label.text.contains("Этого зверя нельзя приручить"), "сообщение: " + hud._msg_label.text)
				mob.take_damage(mob.hp + 5, player)
				check(tm.attempts == used, "победа над %s — не попытка приручения" % sp)
				player._set_target(null)
			player.global_position = Vector3(0, 0.1, 2)
			# Перевод старого сохранения: кристаллы души → зеркальные карты (+ золото за редкий и древний)
			game.from_dict({
				"name": "Старый", "race": "dark_elf", "class": "assassin", "level": 3, "gold": 10,
				"inventory": {"crystal_common": 2, "crystal_rare": 1, "crystal_unique": 1, "hp_potion": 1},
				"bag": [{"id": "crystal_common", "n": 2}, {"id": "hp_potion", "n": 1}, {}, {"id": "crystal_unique", "n": 1}],
				"pets": [{"species": "boar", "name": "Хрюня", "level": 4}, {"species": "golem", "name": "Глыба", "level": 12}],
			})
			check(inv.count("mirror_card") == 4 and inv.count("hp_potion") == 1, "кристаллы стали зеркальными картами: %s"
				% [inv.to_dict()])
			check(not inv.has("crystal_common") and not inv.has("crystal_rare") and not inv.has("crystal_unique"),
				"кристаллов не осталось")
			check(not inv.has("card_golem") and not inv.has("card_boar"), "карт стража и кабана нет")
			check(game.gold == 140, "за редкий кристалл +30 зол., за древний +100 зол.: %d" % game.gold)
			check(String(inv.cell(0).get("id", "")) == "mirror_card" and String(inv.cell(3).get("id", "")) == "mirror_card",
				"раскладка сумки сохранена с новыми id")
			check(game.load_note.contains("Кристаллы души заменены картами"), "сообщение игроку: " + game.load_note)
			check(game.pets.size() == 2 and String(game.pets[0]["name"]) == "Хрюня" and String(game.pets[0]["species"]) == "boar"
				and String(game.pets[1]["species"]) == "golem", "прирученные кабан и страж не тронуты")
			# Карты кабана и стража из сохранения прошлой версии → зеркальные карты
			game.from_dict({
				"name": "Старый", "race": "dark_elf", "class": "assassin", "level": 3, "gold": 10,
				"inventory": {"card_boar": 2, "card_boar_soul": 1, "card_golem": 1, "card_golem_soul": 1, "card_wolf": 1},
				"bag": [{"id": "card_boar", "n": 2}, {"id": "card_wolf", "n": 1}, {"id": "card_golem_soul", "n": 1}],
			})
			check(inv.count("mirror_card") == 5 and inv.count("card_wolf") == 1, "карты кабана и стража стали зеркальными: %s"
				% [inv.to_dict()])
			for id in ["card_boar", "card_boar_soul", "card_golem", "card_golem_soul"]:
				check(not inv.has(id), "в сумке нет %s" % id)
			check(String(inv.cell(0).get("id", "")) == "mirror_card" and String(inv.cell(1).get("id", "")) == "card_wolf",
				"раскладка сумки с новыми id")
			check(game.gold == 10, "за карты золото не доплачивается: %d" % game.gold)
			check(game.load_note.contains("Кабана и каменного стража больше нельзя приручить")
				and not game.load_note.contains("Кристаллы"), "сообщение игроку: " + game.load_note)
			game.load_note = ""
			ok_done()


## Предметы-карты: id, тип, стопки, тиры, цвета, процедурный значок.
func _unit_items() -> void:
	for sp in SPECIES:
		var e := "card_" + String(sp)
		var f := e + "_soul"
		check(ItemData.item_type(e) == "card" and ItemData.item_type(f) == "card", "карты вида %s есть" % sp)
		check(ItemData.card_for(String(sp)) == e and ItemData.soul_card_for(String(sp)) == f, "карты вида %s по id" % sp)
		check(ItemData.is_empty_card(e) and ItemData.is_soul_card(f) and not ItemData.is_soul_card(e), "пустая и с душой: %s" % sp)
		check(ItemData.stack_size(e) == 20 and ItemData.stack_size(f) == 1, "стопки: пустые по 20, с душой по 1")
		check(ItemData.icon_shape(e) == "card" and ItemData.icon_shape(f) == "card", "процедурный значок «карта»")
		check(ItemData.frame_color(e) == ItemData.card_tier_color(ItemData.card_tier(e)), "рамка %s — цвет тира" % e)
	check(ItemData.item_name("card_panther") == "Карта существа: Пантера", "название пустой карты")
	check(ItemData.item_name("card_panther_soul") == "Карта пантеры (с душой)", "название карты с душой")
	for sp in SPECIES:
		check(ItemData.card_tier("card_" + String(sp)) == "basic", "карта %s — коричневая (базовая)" % sp)
	# Кабан и страж не приручаются: их карт нет ни в предметах, ни в добыче, ни у торговца, ни значков
	for sp in NO_TAME:
		var c := "card_" + String(sp)
		check(not MobData.tameable(String(sp)), "%s — нельзя приручить" % sp)
		check(Taming.badge_state(String(sp)) == Taming.BADGE_NO, "значок %s — «нельзя приручить»" % sp)
		check(ItemData.get_item(c).is_empty() and ItemData.get_item(c + "_soul").is_empty(), "предметов %s нет" % c)
		check(ItemData.card_for(String(sp)) == "" and ItemData.soul_card_for(String(sp)) == "", "у %s нет карт" % sp)
		check(not InventoryWindow.goods("assassin").has(c), "%s не продаётся" % c)
		check(not ResourceLoader.exists(ItemData.icon_path(c)) and not ResourceLoader.exists(ItemData.icon_path(c + "_soul")),
			"значков %s нет" % c)
		check(PetData.SPECIES.has(sp), "вид питомца %s остался (для уже прирученных)" % sp)
	for k in MobData.TYPES:
		var id := String(k)
		check(MobData.tameable(id) == (ItemData.card_for(id) != ""), "у приручаемого %s есть карта, у прочих нет" % id)
		for e in MobData.get_type(id)["loot"]:
			var it := String(e[0])
			check(ItemData.card_species(it) == "" or MobData.tameable(ItemData.card_species(it)),
				"из %s не выпадает карта неприручаемого зверя: %s" % [id, it])
	check(ItemData.card_tier_label("unique") == "жёлтая (уникальная)", "подпись тира: " + ItemData.card_tier_label("unique"))
	for t in ["basic", "rare", "special", "unique"]:
		check(ItemData.CARD_TIERS.has(t) and Taming.CHANCE.has(t), "тир %s описан" % t)
	check(ItemData.card_tier_color("rare").b > ItemData.card_tier_color("rare").r, "редкая карта — синяя")
	check(ItemData.card_tier_color("special").b > ItemData.card_tier_color("special").g, "особая карта — фиолетовая")
	check(Taming.CHANCE["basic"] > Taming.CHANCE["unique"], "базовую проще приручить, чем уникальную")
	check(ItemData.item_type(ItemData.MIRROR_CARD) == "card" and ItemData.card_species(ItemData.MIRROR_CARD) == "",
		"зеркальная карта без вида")
	check(ItemData.frame_color(ItemData.MIRROR_CARD) == ItemData.MIRROR_COLOR, "зеркальная — серебряная рамка")
	check(int(ItemData.get_item(ItemData.MIRROR_CARD)["buy"]) > int(ItemData.get_item("card_panther")["buy"]),
		"зеркальная карта дороже базовой")
	for sp in ["wolf"]:
		var c := "card_" + String(sp)
		check(int(ItemData.get_item(c)["buy"]) == 0, "%s не продаётся" % c)
		var dropped := false
		for e in MobData.get_type(sp)["loot"]:
			if String(e[0]) == c:
				dropped = true
		check(dropped, "%s выпадает из своего зверя" % c)
	for k in MobData.TYPES:
		for e in MobData.get_type(String(k))["loot"]:
			check(not ItemData.get_item(String(e[0])).is_empty(), "добыча %s есть в предметах: %s" % [k, e[0]])
	var ic := ItemIcon.make("card_wolf_soul", 64.0)
	check(ic.item_id == "card_wolf_soul", "значок карты создаётся")
	ic.free()


## Описание карты: вид, где водится и уровни, тир, где взять, что делать.
func _unit_lines() -> void:
	var t := "\n".join(PackedStringArray(Taming.card_lines("card_panther")))
	check(t.contains("Пантера") and t.contains("Пещера (ур. 6–8)"), "где водится пантера: " + t)
	check(t.contains("коричневая (базовая)") and t.contains("70%"), "тир и шанс: " + t)
	check(t.contains("продаётся у Учителя Кирка в центре города"), "где взять карту пантеры: " + t)
	check(t.contains("Примените «Приручить» к зверю, затем победите его"), "что делать с картой")
	t = "\n".join(PackedStringArray(Taming.card_lines("card_wolf")))
	check(t.contains("Восточный лагерь") and t.contains("выпадает из волка"), "карта волка: " + t)
	t = "\n".join(PackedStringArray(Taming.card_lines("card_turtle")))
	check(t.contains("Мёртвая роща (ур. 5–6)") and t.contains("коричневая (базовая)"), "карта черепахи: " + t)
	check(Taming.card_lines("card_golem").is_empty() and Taming.card_lines("card_boar").is_empty(), "карт стража и кабана нет")
	t = "\n".join(PackedStringArray(Taming.card_lines("card_wolf_soul")))
	check(t.contains("Сформируйте существо в окне «Питомцы» или кнопкой «Сформировать»"), "карта с душой: " + t)
	t = "\n".join(PackedStringArray(Taming.card_lines(ItemData.MIRROR_CARD)))
	check(t.contains("зеркальная карта") and t.contains("продаётся у Учителя Кирка"), "зеркальная карта: " + t)
	check(Taming.where_to_get("card_wolf") == "выпадает из волка", "карта волка — из волка")


## Карта с душой при полной сумке: заменяет пустую в той же ячейке; если пустых в стопке больше — ничего не теряется.
func _unit_full_bag() -> void:
	var a := Inventory.new()
	a.add("card_wolf", 1)
	a.add("dual_swords_steel", Inventory.CAPACITY - 1)
	a.move(a.find_cell("card_wolf"), 7)
	check(a.is_full() and String(a.cell(7).get("id", "")) == "card_wolf", "сумка полна, карта в ячейке 7")
	check(a.replace_one("card_wolf", "card_wolf_soul"), "карта заменена")
	check(String(a.cell(7).get("id", "")) == "card_wolf_soul" and a.cell_count() == Inventory.CAPACITY,
		"карта с душой легла в ту же ячейку")
	var b := Inventory.new()
	b.add("card_wolf", 2)
	b.add("dual_swords_steel", Inventory.CAPACITY - 1)
	check(b.replace_one("card_wolf", "card_wolf_soul"), "карта из стопки заменена")
	check(b.count("card_wolf") == 1 and b.count("card_wolf_soul") == 1 and b.cell_count() == Inventory.CAPACITY + 1,
		"полная сумка: карта с душой сверх вместимости, ничего не пропало")
	check(not b.replace_one("card_turtle", "card_turtle_soul"), "без пустой карты замены нет")


func _press(node_name: String) -> void:
	var win: InventoryWindow = main.economy.window
	var b: Button = win.buttons.get(node_name)
	check(b != null, "кнопка %s есть в окне" % node_name)
	if b != null:
		b.pressed.emit()


## Есть ли надпись с частью текста в открытом окне.
func _has_text(part: String) -> bool:
	if not main.hud.is_window_open():
		return false
	for n in main.hud._window.find_children("*", "Label", true, false):
		if (n as Label).text.contains(part) and not n.is_queued_for_deletion():
			return true
	return false
