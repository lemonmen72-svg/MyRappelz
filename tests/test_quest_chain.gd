extends "res://tests/test_base.gd"
## Цепочка заданий острова для каждой расы (новый Бродяга): староста своей деревни (фазаны → волки и шкуры
## с квестовой добычей → зелье, выданное при взятии → 5 ур. → к мудрецу; чужие старосты заданий не дают) →
## мудрец, четыре задания сразу («Взять все»: 10 ур., склад, лавка Гордея — покупки и продажи считаются только
## у него, Учитель Кирк) → «К охотнице» только после склада, лавки и учителя → охотница: 20 волков 6+ ур. →
## семь вожаков и «Доклад мудрецу» («Взять все»; вожаки — убийством, один — настоящим) → «Победа над вожаками»
## (засчитывается в разговоре) → «Вести для мудреца» → профессия у мудреца (10 ур., окно выбора) →
## «Первое умение» (стартовые умения не в счёт) → «Глава наёмников» → «Закрытая пещера» у Корвена.
## Склад: положить / забрать (часть и всю стопку), стопки, надетое оружие не в ячейках, полная сумка и полный склад,
## окно (ячейки, карточка, перетаскивание), закрытие вдали от кладовщика, сохранение и загрузка. Перенос старых
## сохранений: Бродяга 5+ ур. — без старосты, ветеран с профессией — всё до профессии сдано, «Знакомство с городом»
## отброшено, сохранение без склада.

const RACES := ["human", "light_elf", "dark_elf"]
const QID := QuestData.JOB_QUEST
const SAGE4 := ["sage_path", "sage_storage", "sage_shop", "sage_teacher"]

var _ri := 0


func race_class() -> Array:
	return ["human", "wanderer"]


func before_start() -> void:
	# Звери сильнее героя-новичка: тест не про бой
	AdminPanel.god = true


func run_step() -> void:
	var player: Player = main.player
	var eco: Economy = main.economy
	match step:
		0:
			_unit()
			_ri = 0
			step = 1
		1:
			var race := String(RACES[_ri])
			print("— раса: %s" % race)
			game.new_character("Цепочка", race, ClassData.WANDERER, "f" if _ri % 2 == 0 else "m")
			player.apply_class()
			main.quests._changed()
			_elder_start(race)
			step = 2
		2:
			_elder_chain(String(RACES[_ri]))
			step = 3
		3:
			_sage_quests(_ri == 0)
			if _ri == 0:
				# Склад закрывается, если отойти от кладовщика
				_stand_by("storekeeper", 1.8)
				eco.open_storage()
				check(eco.is_storage_open(), "склад открыт рядом с кладовщиком")
				player.global_position = Vector3(6.0, 0.1, -12.0)
				if IslandWorld.current != null:
					player.global_position.y = IslandWorld.current.height_at(6.0, -12.0) + 0.1
				wait = 3
			step = 4
		4:
			if _ri == 0:
				check(not eco.is_storage_open() and not main.hud.is_window_open(), "отошёл — склад закрылся")
			_hunter(_ri == 0)
			step = 5
		5:
			_profession(String(RACES[_ri]))
			step = 6
		6:
			_after_job()
			_ri += 1
			step = 1 if _ri < RACES.size() else 7
		7:
			_check_migration()
			ok_done()


# ---------- Данные ----------

func _unit() -> void:
	check(QuestData.giver("elder_hunt") == "elder_human" and QuestData.turn_in("elder_hunt") == "elder_human",
		"задания старосты — у старосты своей расы")
	for i in range(1, QuestData.ELDER_CHAIN.size()):
		check(QuestData.prereqs(String(QuestData.ELDER_CHAIN[i])) == [String(QuestData.ELDER_CHAIN[i - 1])],
			"цепочка старосты: %s после %s" % [QuestData.ELDER_CHAIN[i], QuestData.ELDER_CHAIN[i - 1]])
	check(QuestData.turn_in("elder_to_sage") == "sage", "«Дорога в город» сдаётся мудрецу")
	for id in SAGE4:
		check(QuestData.giver(String(id)) == "sage" and QuestData.prereqs(String(id)) == ["elder_to_sage"],
			"%s: у мудреца после старосты" % id)
	var to_h := QuestData.prereqs("sage_to_hunter")
	check(to_h.size() == 3 and not to_h.has("sage_path") and QuestData.turn_in("sage_to_hunter") == "hunter",
		"«К охотнице» — после склада, лавки и учителя (10 ур. не ждёт)")
	var jq := QuestData.get_quest(QID)
	check(QuestData.giver(QID) == "hunter" and QuestData.turn_in(QID) == "sage" and bool(jq.get("job_choice", false))
		and bool(jq.get("wanderer_only", false)) and QuestData.prereqs(QID) == ["hunter_hunt"],
		"«Доклад мудрецу»: выдаёт охотница после «Волчьей стаи», сдача — выбор профессии")
	# Вожаки: по заданию на каждого босса острова
	var bosses: Array = []
	for k in MobData.TYPES:
		if MobData.is_boss(String(k)):
			bosses.append(String(k))
	check(bosses.size() == 7 and QuestData.BOSS_QUESTS.size() == 7, "семь вожаков — семь заданий")
	for k in QuestData.BOSS_QUESTS:
		var id := String(k)
		var g: Dictionary = QuestData.goals(id)[0]
		var tg := String(g.get("target", ""))
		check(bosses.has(tg) and String(g["type"]) == "kill" and QuestData.prereqs(id) == ["hunter_hunt"],
			"%s: убить %s" % [id, tg])
		bosses.erase(tg)
	check(bosses.is_empty(), "каждому боссу — своё задание")
	check(QuestData.prereqs("hunter_bosses_done") == QuestData.BOSS_QUESTS, "награда — после всех вожаков")
	check(QuestData.prereqs("sage_first_skill") == [QID] and QuestData.turn_in("sage_to_merc") == "merc_chief"
		and QuestData.giver("merc_closed_cave") == "merc_chief", "после профессии: умение → Корвен → закрытая пещера")
	# Свои тексты у каждого старосты
	var offers: Dictionary = {}
	var race0: String = game.race_id
	for r in RACES:
		game.race_id = String(r)
		offers[QuestData.text("elder_hunt", "offer")] = true
		check(QuestData.giver("elder_trophies") == String(QuestData.ELDERS[String(r)]), "%s: свой староста" % r)
	game.race_id = race0
	check(offers.size() == 3, "у каждого старосты свои слова")
	# Звери старост водятся у деревень на 1–3 ур., волки охотницы — у Западных лагерей на 6+ ур.
	var w := IslandWorld.current
	if w != null:
		for sp in ["pheasant", "wolf"]:
			check(_zone_has(w, String(sp), 3, false), "%s водятся на 1–3 ур." % sp)
		check(_zone_has(w, "wolf", 6, true), "волки 6+ ур. у лагерей")


## Есть зона острова со зверем species: low = false — уровень зоны от не выше lvl, true — до не ниже lvl.
func _zone_has(w: IslandWorld, species: String, lvl: int, high: bool) -> bool:
	for z in w.cfg.get("mob_zones", []):
		var zd: Dictionary = z
		var lv: Array = zd.get("levels", [1, 1])
		var ok := int(lv[1]) >= lvl if high else int(lv[0]) <= lvl
		if not ok:
			continue
		for s in zd.get("mobs", []):
			if String((s as Array)[0]) == species:
				return true
	return false


# ---------- Староста ----------

func _elder_start(race: String) -> void:
	var npcs: Npcs = main.npcs
	npcs.refresh_marks()
	var elder := String(QuestData.ELDERS[race])
	for e in QuestData.ELDERS.values():
		var other := String(e)
		check(Npcs.gives_quests(other) == (other == elder), "%s: задания только у старосты своей расы" % other)
		check(npcs.npc(other).mark_text() == ("!" if other == elder else ""), "%s: значок «%s»" % [other, npcs.npc(other).mark_text()])
	check(npcs.npc("sage").mark_text() == "" and npcs.npc("hunter").mark_text() == "", "мудрец и охотница пока ждут")


func _elder_chain(race: String) -> void:
	var q: Quests = main.quests
	var npcs: Npcs = main.npcs
	var eco: Economy = main.economy
	var inv: Inventory = game.inventory
	var player: Player = main.player
	var elder := String(QuestData.ELDERS[race])
	# 1. Фазаны
	_stand_by(elder, 1.8)
	npcs.talk_to(elder)
	check(npcs.reply == NpcData.greet(elder, "offer"), "%s приглашает к делу: %s" % [elder, npcs.reply])
	_press("opt_quests")
	_press("dq_elder_hunt")
	check(npcs.reply == QuestData.text("elder_hunt", "offer") and _has_text(QuestData.quest_name("elder_hunt")),
		"реплика старосты своей расы: %s" % npcs.reply.left(40))
	_press("accept")
	check(q.is_active("elder_hunt") and game.quest_tracked == "elder_hunt", "«%s» взято" % QuestData.quest_name("elder_hunt"))
	npcs.close_dialog()
	var wolf := find_mob("wolf")
	var ph := find_mob("pheasant")
	check(wolf != null and ph != null, "волки и фазаны есть")
	if wolf == null or ph == null:
		return
	q.on_mob_killed(wolf)
	check(q.goal_progress("elder_hunt", 0) == 0, "волк — не фазан")
	for i in 3:
		q.on_mob_killed(ph)
	check(q.is_ready("elder_hunt"), "три фазана")
	_complete_at(elder, "elder_hunt")
	# 2. Волки и шкуры: пока задание взято, шкура падает с каждого волка
	check(q.quest_loot("wolf").is_empty(), "без задания квестовой добычи нет")
	if game.level < 2:
		check(not q.accept("elder_trophies") and q.level_locked("elder_trophies"), "«Шкуры» — со 2 уровня")
	_level_to(2)
	check(q.accept("elder_trophies"), "«Шкуры» взято")
	check(q.quest_loot("wolf") == {"wolf_pelt": 1} and q.quest_loot("pheasant").is_empty(), "квестовая добыча: шкура с волка")
	inv.remove("wolf_pelt", inv.count("wolf_pelt"))
	for i in 3:
		# Шкура бывает и обычной добычей (материал волка) — цель могла выполниться раньше третьего волка: тогда
		# квестовой добычи больше нет, но волков для цели «убить 3» всё равно добиваем
		var need_pelt := not q.goal_done("elder_trophies", 1)
		var m := find_mob("wolf")
		check(m != null, "волк %d" % (i + 1))
		if m == null:
			return
		stand_near(m, 1.5)
		var pos := m.global_position
		var before := _drop_ids()
		m.take_damage(m.hp + 5, player)
		var drop := _drop_near(pos, before)
		if need_pelt:
			check(drop != null and int(drop.items.get("wolf_pelt", 0)) >= 1, "с волка %d упала шкура" % (i + 1))
		if drop != null:
			drop.pick_up()
	check(q.goal_done("elder_trophies", 0) and q.goal_done("elder_trophies", 1), "три волка и три шкуры: %d/3, %d/3"
		% [q.goal_progress("elder_trophies", 0), q.goal_progress("elder_trophies", 1)])
	check(q.quest_loot("wolf").is_empty(), "шкур хватает — квестовой добычи больше нет")
	var pelts := inv.count("wolf_pelt")
	_complete_at(elder, "elder_trophies")
	check(inv.count("wolf_pelt") == pelts - 3, "шкуры отданы старосте (%d → %d)" % [pelts, inv.count("wolf_pelt")])
	# 3. Зелье: выдаётся при взятии, если нет; при полном здоровье не пьётся
	inv.remove("potion_hp_r1", inv.count("potion_hp_r1"))
	check(q.accept("elder_potion") and inv.count("potion_hp_r1") == 1, "зелье выдано при взятии")
	check(last_hud_text().contains("Получено: Зелье здоровья I ×1"), "сообщение: " + last_hud_text())
	player.hp = player.max_hp
	eco._potion_cd = 0.0
	check(not eco.use_potion() and q.goal_progress("elder_potion", 0) == 0, "при полном здоровье зелье не выпить")
	player.hp = maxi(1, int(player.max_hp * 0.5))
	check(eco.use_potion() and q.is_ready("elder_potion"), "выпито зелье — задание выполнено")
	_complete_at(elder, "elder_potion")
	# 4. 5 уровень
	check(q.accept("elder_grow"), "«5 уровень» взято")
	if game.level < 5:
		check(not q.is_ready("elder_grow"), "до 5 ур. не готово")
	_level_to(5)
	check(q.is_ready("elder_grow"), "5 уровень")
	_complete_at(elder, "elder_grow")
	# 5. К мудрецу
	_stand_by(elder, 1.8)
	npcs.talk_to(elder)
	_press("opt_quests")
	_press("dq_elder_to_sage")
	_press("accept")
	check(q.is_active("elder_to_sage") and not q.is_ready("elder_to_sage"), "«К мудрецу» взято")
	npcs.close_dialog()
	npcs.refresh_marks()
	check(npcs.npc(elder).mark_text() == "", "у старосты дел больше нет")
	check(npcs.npc("sage").mark_kind == "active", "над мудрецом серый «?»")
	_stand_by("sage", 1.8)
	npcs.talk_to("sage")
	check(q.is_ready("elder_to_sage") and npcs.reply == NpcData.greet("sage", "ready"), "поговорили с мудрецом")
	npcs.close_dialog()
	_complete_at("sage", "elder_to_sage")


# ---------- Мудрец ----------

func _sage_quests(first: bool) -> void:
	var q: Quests = main.quests
	var npcs: Npcs = main.npcs
	var eco: Economy = main.economy
	var inv: Inventory = game.inventory
	_stand_by("sage", 1.8)
	npcs.talk_to("sage")
	_press("opt_quests")
	check(npcs.buttons.has("accept_all") and (npcs.buttons["accept_all"] as Button).text.contains("(4)"), "«Взять все задания (4)»")
	_press("accept_all")
	for id in SAGE4:
		check(q.is_active(String(id)), "у мудреца взято «%s»" % QuestData.quest_name(String(id)))
	npcs.close_dialog()
	check(game.level >= 10 or not q.is_ready("sage_path"), "«Путь к профессии» ждёт 10 ур.")
	check(q.state("sage_to_hunter") == "locked", "к охотнице — позже")
	# Учитель Кирк: разговор; продажа и покупка у Кирка не в счёт лавки Гордея
	_stand_near(main.npcs.kirk, 2.0)
	npcs.talk_to("kirk")
	npcs.close_dialog()
	check(q.is_ready("sage_teacher"), "познакомились с Учителем Кирком")
	if first:
		inv.add("wolf_pelt", 1)
		check(eco.nearest_trader() == "kirk" and eco.sell_cell(inv.find_cell("wolf_pelt"), 1) == 1, "продано Кирку")
		game.gold += 30
		check(eco.buy("card_pheasant", 1, "kirk"), "куплено у Кирка")
		check(q.goal_progress("sage_shop", 0) == 0 and q.goal_progress("sage_shop", 1) == 0, "у Кирка — не в счёт лавки Гордея")
	# Склад: поговорить, положить вещь
	_stand_by("storekeeper", 1.8)
	npcs.talk_to("storekeeper")
	check(q.goal_done("sage_storage", 0) and not q.is_ready("sage_storage"), "поговорили с кладовщиком")
	_press("opt_storage")
	check(eco.is_storage_open() and not npcs.is_dialog_open(), "«Склад» — окно склада")
	inv.add("pheasant_feather", 5)
	eco.window.refresh()
	eco.window.select_cell(inv.find_cell("pheasant_feather"))
	_press_win("act_store")
	check(game.storage.count("pheasant_feather") == 1 and q.is_ready("sage_storage"), "перо на складе — задание выполнено")
	if first:
		_storage_details()
	main.hud.close_window()
	# Лавка Гордея: купить 3, продать 3
	_stand_near(eco.merchant, 2.0)
	check(eco.nearest_trader() == "merchant", "рядом — торговец Гордей")
	game.gold += 100
	check(eco.buy("potion_hp_r1", 2, "merchant") and q.goal_progress("sage_shop", 0) == 2, "куплено 2 из 3")
	check(eco.buy("revive_scroll", 1, "merchant") and q.goal_done("sage_shop", 0), "куплено 3 из 3")
	inv.add("wolf_pelt", 3)
	for i in 3:
		check(eco.sell_cell(inv.find_cell("wolf_pelt"), 1) == 1, "продана шкура %d" % (i + 1))
	check(q.is_ready("sage_shop"), "лавка: куплено и продано по 3")
	# Сдать: «К охотнице» открывается после склада, лавки и учителя
	_complete_at("sage", "sage_teacher")
	_complete_at("sage", "sage_storage")
	check(q.state("sage_to_hunter") == "locked", "без лавки к охотнице рано")
	_complete_at("sage", "sage_shop")
	check(q.state("sage_to_hunter") == "available", "«К охотнице» доступно (%s)" % q.accept_block("sage_to_hunter"))
	_stand_by("sage", 1.8)
	npcs.talk_to("sage")
	_press("opt_quests")
	_press("dq_sage_to_hunter")
	_press("accept")
	npcs.close_dialog()
	_stand_by("hunter", 1.8)
	npcs.talk_to("hunter")
	npcs.close_dialog()
	check(q.is_ready("sage_to_hunter"), "дошли до охотницы")
	_complete_at("hunter", "sage_to_hunter")


## Склад подробно (окно открыто рядом с кладовщиком, на складе одно перо).
func _storage_details() -> void:
	var eco: Economy = main.economy
	var inv: Inventory = game.inventory
	var st: Inventory = game.storage
	var win: InventoryWindow = eco.window
	check(win.buttons.has("store_0") and win.buttons.has("store_%d" % (Inventory.CAPACITY - 1)), "на складе %d ячеек"
		% Inventory.CAPACITY)
	# Стопки: перья складываются в одну стопку
	check(eco.deposit(inv.find_cell("pheasant_feather"), 2) == 2 and st.count("pheasant_feather") == 3
		and st.used_cells() == 1, "перья на складе одной стопкой: %d" % st.count("pheasant_feather"))
	check(eco.deposit(inv.find_cell("pheasant_feather"), -1) == 2 and inv.count("pheasant_feather") == 0, "положена вся стопка")
	check(eco.withdraw(st.find_cell("pheasant_feather"), 1) == 1 and inv.count("pheasant_feather") == 1, "забрано одно перо")
	check(eco.withdraw(st.find_cell("pheasant_feather"), -1) == 4 and st.count("pheasant_feather") == 0
		and inv.count("pheasant_feather") == 5, "забрана вся стопка")
	# Надетое оружие ячейку сумки не занимает — на склад его не положить
	# (в наградах заданий бывает случайное оружие — такое же, как надетое, лежит в своей ячейке: ячеек на одну меньше)
	var in_cells := 0
	for c in inv.cells():
		var cd: Dictionary = c if c is Dictionary else {}
		if String(cd.get("id", "")) == game.weapon:
			in_cells += int(cd.get("n", 1))
	check(game.weapon != "" and in_cells == inv.count(game.weapon) - 1, "надетое оружие не в ячейках сумки (%d из %d)"
		% [in_cells, inv.count(game.weapon)])
	# Сумка полна — со склада не забрать
	st.add("mirror_card", 2)
	inv.add("sword_steel", Inventory.CAPACITY - inv.used_cells())
	check(inv.is_full(), "сумка полна")
	check(eco.withdraw(st.find_cell("mirror_card"), -1) == 0 and last_hud_text().contains("Сумка полна")
		and st.count("mirror_card") == 2, "в полную сумку со склада не забрать")
	inv.remove("sword_steel", inv.count("sword_steel"))
	# Склад полон — не положить
	st.add("sword_steel", Inventory.CAPACITY - st.used_cells())
	check(st.is_full(), "склад полон")
	check(eco.deposit(inv.find_cell("pheasant_feather"), 1) == 0 and last_hud_text().contains("Склад полон"), "на полный склад не положить")
	st.remove("sword_steel", st.count("sword_steel"))
	# Окно: карточки и перетаскивание
	inv.add("shell_plate", 2)
	win.refresh()
	var bc := inv.find_cell("shell_plate")
	win.select_cell(bc)
	check(win.buttons.has("act_store") and win.buttons.has("act_store_all"), "карточка вещи из сумки: «На склад»")
	var sb: Button = win.buttons["store_%d" % (Inventory.CAPACITY - 1)]
	check(sb.call("_can_drop_data", Vector2.ZERO, {"inv_cell": bc}), "из сумки можно перетащить на склад")
	sb.call("_drop_data", Vector2.ZERO, {"inv_cell": bc})
	check(st.count("shell_plate") == 2 and inv.count("shell_plate") == 0, "перетащено на склад")
	win.refresh()
	var sc := st.find_cell("shell_plate")
	var drag: Variant = (win.buttons["store_%d" % sc] as Button).call("_get_drag_data", Vector2(5, 5))
	check(drag is Dictionary and (drag as Dictionary).has("store_cell"), "со склада можно тащить")
	var bag_b: Button = win.buttons["cell_%d" % (Inventory.CAPACITY - 1)]
	check(bag_b.call("_can_drop_data", Vector2.ZERO, drag), "со склада — в сумку")
	bag_b.call("_drop_data", Vector2.ZERO, drag)
	check(inv.count("shell_plate") == 2 and st.count("shell_plate") == 0, "перетащено в сумку")
	win.refresh()
	win.select_store(st.find_cell("mirror_card"))
	check(win.sel_kind == "store" and win.buttons.has("act_take") and win.buttons.has("act_take_all"),
		"карточка вещи со склада: «В сумку»")
	var mc := inv.count("mirror_card")
	_press_win("act_take")
	check(inv.count("mirror_card") == mc + 1 and st.count("mirror_card") == 1, "«В сумку» — одна карта")
	# Сохранение и загрузка
	check(game.save_game(), "сохранено")
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
	check(d is Dictionary and (d as Dictionary).has("storage"), "склад в сохранении")
	st.from_dict({})
	check(game.load_game(), "загружено")
	check(game.storage.count("mirror_card") == 1 and game.storage.used_cells() == 1, "склад после загрузки: %s"
		% [game.storage.items])
	check(main.quests.is_ready("sage_storage") and main.quests.is_ready("sage_teacher"), "задания после загрузки")
	win.refresh()


# ---------- Охотница ----------

func _hunter(first: bool) -> void:
	var q: Quests = main.quests
	var npcs: Npcs = main.npcs
	var player: Player = main.player
	_level_to(6)
	_stand_by("hunter", 1.8)
	npcs.talk_to("hunter")
	check(npcs.reply == NpcData.greet("hunter", "offer"), "охотница зовёт на охоту")
	_press("opt_quests")
	_press("dq_hunter_hunt")
	_press("accept")
	npcs.close_dialog()
	check(q.is_active("hunter_hunt"), "«Волчья стая» взято")
	var far := _ground(Vector2(-116.0, 22.0))
	var strong: Mob = main.spawn_mob("wolf", 7, far)
	var weak: Mob = main.spawn_mob("wolf", 3, far + Vector3(2, 0, 0))
	q.on_mob_killed(weak)
	check(q.goal_progress("hunter_hunt", 0) == 0, "волк 3 ур. не в счёт")
	for i in 20:
		q.on_mob_killed(strong)
	check(q.is_ready("hunter_hunt"), "двадцать волков 6+ ур.")
	strong.queue_free()
	weak.queue_free()
	_complete_at("hunter", "hunter_hunt")
	# Семь вожаков и доклад мудрецу
	_stand_by("hunter", 1.8)
	npcs.talk_to("hunter")
	_press("opt_quests")
	for k in QuestData.BOSS_QUESTS:
		check(npcs.buttons.has("dq_" + String(k)), "у охотницы: «%s»" % QuestData.quest_name(String(k)))
	check(npcs.buttons.has("dq_" + QID), "у охотницы: «Доклад мудрецу»")
	check(npcs.buttons.has("accept_all") and (npcs.buttons["accept_all"] as Button).text.contains("(8)"), "«Взять все задания (8)»")
	_press("accept_all")
	npcs.close_dialog()
	for k in QuestData.BOSS_QUESTS:
		check(q.is_active(String(k)), "взято: %s" % k)
	check(q.is_active(QID), "доклад мудрецу взят")
	if game.level < 10:
		check(not q.is_ready(QID) and q.goal_progress(QID, 0) == game.level, "доклад ждёт 10 ур. (%d)" % game.level)
		npcs.refresh_marks()
		check(npcs.npc("sage").mark_kind != "ready" or q.is_ready("sage_path"), "мудрецу пока нечего сдавать")
	for k in QuestData.BOSS_QUESTS:
		var id := String(k)
		var g: Dictionary = QuestData.goals(id)[0]
		var tg := String(g["target"])
		if first and tg == "boss_wolf":
			# Настоящее убийство: опыт, добыча, задания — как обычно
			var bm: Mob = main.spawn_mob(tg, -1, player.global_position + Vector3(3, 0, 0))
			bm.take_damage(bm.hp + 5, player)
		else:
			var m := find_mob(tg)
			var spawned := false
			if m == null:
				m = main.spawn_mob(tg, -1, far)
				spawned = true
			q.on_mob_killed(m)
			if spawned:
				m.queue_free()
		check(q.is_ready(id), "%s побеждён" % MobData.get_type(tg)["name"])
	# Сдать в обратном порядке: награда за всех — только после последнего
	var order: Array = QuestData.BOSS_QUESTS.duplicate()
	order.reverse()
	for k in order:
		check(q.state("hunter_bosses_done") == "locked", "«Победа над вожаками» ещё закрыта")
		var mirrors: int = game.inventory.count("mirror_card")
		check(q.complete(String(k)), "сдано: %s" % k)
		var items := QuestData.reward_items(String(k))
		check(game.inventory.count("mirror_card") == mirrors + int(items.get("mirror_card", 0)), "зеркальные карты за вожака")
	check(q.state("hunter_bosses_done") == "available", "все вожаки — награда доступна")
	_stand_by("hunter", 1.8)
	npcs.talk_to("hunter")
	_press("opt_quests")
	_press("dq_hunter_bosses_done")
	_press("accept")
	check(q.is_ready("hunter_bosses_done") and npcs.buttons.has("complete"), "разговор с охотницей засчитан сразу")
	var g0: int = game.gold
	_press("complete")
	check(q.is_done("hunter_bosses_done") and game.gold == g0 + 1500, "большая награда: +1500 зол.")
	check(npcs.reply == QuestData.text("hunter_bosses_done", "done"), "охотница отправляет к мудрецу")
	npcs.close_dialog()
	check(q.accept("hunter_to_sage"), "«Вести для мудреца» взято")
	_stand_by("sage", 1.8)
	npcs.talk_to("sage")
	npcs.close_dialog()
	check(q.is_ready("hunter_to_sage"), "доложили мудрецу о вожаках")
	_complete_at("sage", "hunter_to_sage")


# ---------- Профессия и после неё ----------

func _profession(race: String) -> void:
	var q: Quests = main.quests
	var npcs: Npcs = main.npcs
	_level_to(10)
	check(q.is_ready(QID) and q.is_ready("sage_path"), "10 ур.: доклад и «Путь к профессии» готовы")
	_complete_at("sage", "sage_path")
	_stand_by("sage", 1.8)
	npcs.open_dialog("sage", "quest", QID)
	_press("complete")
	var jw: JobWindow = main.job_window
	check(jw.is_open() and jw.quest_id == QID, "сдача доклада — выбор профессии")
	var job := String(ClassData.jobs_of(race)[_ri % 3])
	jw.buttons["pick_" + job].pressed.emit()
	jw.buttons["confirm"].pressed.emit()
	check(game.class_id == job and q.is_done(QID), "%s: профессия «%s»" % [race, ClassData.job_name(job)])
	npcs.refresh_marks()
	check(q.state("sage_first_skill") == "available" and npcs.npc("sage").mark_text() == "!", "мудрец: «Первое умение»")


func _after_job() -> void:
	var q: Quests = main.quests
	var npcs: Npcs = main.npcs
	var job: String = game.class_id
	check(q.accept("sage_first_skill"), "«Первое умение» взято")
	check(q.goal_progress("sage_first_skill", 0) == 0, "стартовые умения не в счёт (%d)" % Quests.learned_skills())
	_level_to(11)
	game.hero["jp"] = int(game.hero["jp"]) + 100
	var sid := ""
	for k in HeroSkills.list_for(job):
		if sid == "" and HeroSkills.learn_block(game.hero, job, game.level, String(k)) == "":
			sid = String(k)
	check(sid != "", "есть умение для изучения")
	check(HeroSkills.learn(game.hero, job, game.level, sid), "изучено «%s»" % String(HeroSkills.get_skill(sid, job).get("name", sid)))
	main.player.refresh_skills()
	game.changed.emit()
	check(q.is_ready("sage_first_skill"), "умение изучено — задание выполнено")
	_complete_at("sage", "sage_first_skill")
	check(q.accept("sage_to_merc"), "«Глава наёмников» взято")
	_stand_by("merc_chief", 1.8)
	npcs.talk_to("merc_chief")
	check(q.is_ready("sage_to_merc") and npcs.reply == NpcData.greet("merc_chief", "ready"), "дошли до Корвена")
	_press("opt_quests")
	_press("dq_sage_to_merc")
	_press("complete")
	check(q.is_done("sage_to_merc"), "«Глава наёмников» сдано")
	_press("dq_merc_closed_cave")
	check(npcs.reply == QuestData.text("merc_closed_cave", "offer") and npcs.reply.contains("закрыта"), "Корвен: пещера закрыта")
	_press("accept")
	check(q.is_ready("merc_closed_cave") and npcs.buttons.has("complete"), "выслушали Корвена — сразу можно сдать")
	_press("complete")
	check(q.is_done("merc_closed_cave") and npcs.reply == QuestData.text("merc_closed_cave", "done"), "«Закрытая пещера» сдано")
	check(bool(NpcData.talk_entry("merc_chief", "dungeon").get("soon", false)), "подземелье — «скоро»")
	npcs.close_dialog()
	for k in QuestData.QUESTS:
		var id := String(k)
		if not id.begins_with("kirk_"):
			check(q.is_done(id), "цепочка пройдена: «%s»" % QuestData.quest_name(id))
	npcs.refresh_marks()
	for who in ["sage", "hunter", "merc_chief", String(QuestData.ELDERS[game.race_id])]:
		check(npcs.npc(String(who)).mark_text() == "", "%s: значков нет" % who)


# ---------- Старые сохранения ----------

func _check_migration() -> void:
	var q: Quests = main.quests
	# Бродяга 7 ур. до цепочки: староста не нужен, начинает у мудреца; «Знакомство с городом» отброшено
	game.from_dict({"version": 2, "name": "Старый", "race": "light_elf", "class": "wanderer", "level": 7,
		"quests": {"active": {}, "done": {"sage_town_tour": 1}, "tracked": ""}})
	for k in QuestData.ELDER_CHAIN:
		check(q.is_done(String(k)), "Бродяга 7 ур.: «%s» сдано" % QuestData.quest_name(String(k)))
	check(not game.quests_done.has("sage_town_tour"), "«Знакомство с городом» отброшено")
	check(q.state("sage_storage") == "available" and q.state(QID) == "locked", "начинает у мудреца")
	# Новичок 2 ур. — с начала
	game.from_dict({"version": 2, "name": "Новый", "race": "human", "class": "wanderer", "level": 2})
	check(game.quests_done.is_empty() and q.state("elder_hunt") == "available", "новичок начинает у старосты")
	# Профессия уже выбрана: всё до профессии сдано, вожаки и задания после профессии открыты
	game.from_dict({"version": 2, "name": "Ветеран", "race": "dark_elf", "class": "adept", "level": 14,
		"quests": {"active": {QID: {"progress": [1, 5]}}, "done": {"kirk_first_card": 1}, "tracked": QID}})
	for k in QuestData.PRE_JOB:
		check(q.is_done(String(k)), "ветеран: «%s» сдано" % QuestData.quest_name(String(k)))
	check(q.is_done(QID) and not q.is_active(QID) and game.quest_tracked == "", "ветеран: доклад сдан, не взят")
	check(q.state("sage_first_skill") == "available" and q.state("hunter_boss_pheasant") == "available"
		and q.is_done("kirk_first_card"), "ветерану открыты «Первое умение» и вожаки")
	# Бродяга с прежним заданием на профессию в работе: задание остаётся, цель — 10 ур.
	game.from_dict({"version": 2, "name": "Бродяга", "race": "human", "class": "wanderer", "level": 11,
		"quests": {"active": {QID: {"progress": [1, 3]}}, "done": {}}})
	check(q.is_active(QID) and (game.quests_active[QID]["progress"] as Array).size() == 1, "прежнее задание — с новой целью")
	q._refresh_state_goals(false)
	check(q.is_ready(QID), "11 ур. — доклад можно сдать")
	# Новое сохранение: версия цепочки и склад
	var d: Dictionary = game.to_dict()
	check(int(d["quests"]["chain"]) == QuestData.CHAIN_VERSION and d.has("storage"), "в сохранении — версия цепочки и склад")
	game.storage.add("potion_hp_r1", 3)
	game.from_dict({"version": 2, "name": "Без склада", "race": "human", "class": "wanderer", "level": 3})
	check(game.storage.items.is_empty(), "старое сохранение — склад пуст")
	game.load_note = ""


# ---------- Помощники ----------

## Сдать задание id у NPC npc_id через диалог: награда (опыт, золото) и слова при сдаче.
func _complete_at(npc_id: String, id: String) -> void:
	var npcs: Npcs = main.npcs
	_stand_by(npc_id, 1.8)
	npcs.talk_to(npc_id)
	check(npcs.reply == NpcData.greet(npc_id, "ready"), "%s: есть что сдать («%s»)" % [npc_id, npcs.reply.left(30)])
	_press("opt_quests")
	_press("dq_" + id)
	check(npcs.buttons.has("complete"), "«%s»: кнопка «Сдать»" % QuestData.quest_name(id))
	var xp0 := _total_xp()
	var g0: int = game.gold
	_press("complete")
	var r := QuestData.rewards(id)
	check(main.quests.is_done(id), "«%s» сдано" % QuestData.quest_name(id))
	check(game.gold == g0 + int(r.get("gold", 0)) and _total_xp() == xp0 + int(r.get("xp", 0)),
		"«%s»: награда %s" % [QuestData.quest_name(id), QuestData.reward_text(id)])
	check(npcs.reply == QuestData.text(id, "done"), "«%s»: слова при сдаче" % QuestData.quest_name(id))
	npcs.close_dialog()


## Поднять героя до уровня lvl обычным опытом.
func _level_to(lvl: int) -> void:
	var p: Player = main.player
	while game.level < lvl:
		p.gain_xp(game.xp_to_next(game.level) - game.xp)


## Мешочек добычи у точки pos ({} — нет).
func _drop_near(pos: Vector3, skip: Dictionary = {}) -> LootDrop:
	# Новый мешочек (не из skip) ближе всех к месту зверя — рядом может лежать мешочек прошлого волка
	var best: LootDrop = null
	var best_d := 3.0
	for n in get_tree().get_nodes_in_group("loot_drops"):
		var d := n as LootDrop
		if d == null or d.is_queued_for_deletion() or skip.has(d.get_instance_id()):
			continue
		var dist := Vector2(d.global_position.x - pos.x, d.global_position.z - pos.z).length()
		if dist < best_d:
			best_d = dist
			best = d
	return best


func _drop_ids() -> Dictionary:
	var ids: Dictionary = {}
	for n in get_tree().get_nodes_in_group("loot_drops"):
		ids[n.get_instance_id()] = true
	return ids


## Точка на земле острова.
func _ground(p: Vector2) -> Vector3:
	var y := 0.0
	if IslandWorld.current != null:
		y = IslandWorld.current.height_at(p.x, p.y)
	return Vector3(p.x, y + 0.1, p.y)


## Игрок в dist м перед жителем (на проходимой земле), HP полное.
func _stand_by(id: String, dist: float) -> void:
	var n: Npc = main.npcs.npc(id)
	check(n != null, "житель %s в мире" % id)
	if n == null:
		return
	var w := IslandWorld.current
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
	var p: Player = main.player
	p.global_position = pos
	p.hp = p.max_hp


## Игрок в dist м от узла (торговец, Кирк), со стороны центра площади.
func _stand_near(n: Node3D, dist: float) -> void:
	var c := n.global_position
	var to_c := Vector3(-c.x, 0, -c.z).normalized()
	var pos := c + to_c * dist
	if IslandWorld.current != null:
		pos.y = IslandWorld.current.height_at(pos.x, pos.z) + 0.1
	main.player.global_position = pos


func _press(key: String) -> void:
	var b: Button = main.npcs.buttons.get(key)
	check(b != null, "кнопка диалога %s" % key)
	if b != null:
		b.pressed.emit()


func _press_win(key: String) -> void:
	var b: Button = main.economy.window.buttons.get(key)
	check(b != null, "кнопка окна %s" % key)
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


## Весь опыт героя с 1 уровня.
func _total_xp() -> int:
	var t: int = game.xp
	for l in range(1, game.level):
		t += game.xp_to_next(l)
	return t
