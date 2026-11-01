extends "res://tests/test_base.gd"
## Задания и Учитель Кирк: данные заданий и NPC, где стоит Кирк (центральная деревня, проходимая земля,
## не на дороге и не в постройке, рядом с торговцем), его модель и имя, кнопка «Говорить» рядом, диалог
## (реплика, «Задания», «Торговля», «До встречи»), торговля у Кирка (карты существ) и у торговца (карт нет),
## вся цепочка Кирка от взятия до сдачи (покупка карты → душа в карте → формирование и призыв → победы
## с питомцем), прогресс и сообщения, награды (опыт и уровень, золото, предметы, JP), сумка полна при сдаче,
## значки «!» / «?» над NPC (и над торговцем), журнал (вкладки, цели, награды со значками, отслеживание,
## отказ), трекер на экране (не перекрывает кнопки и меню, касание — журнал), меню HUD с «Заданиями»,
## другие виды целей (kill, collect с take, level, talk, form с counts_existing; повторяемое задание),
## сохранение и загрузка заданий, старое сохранение без заданий.

const CHAIN := ["kirk_first_card", "kirk_soul", "kirk_new_friend", "kirk_bond_trial"]

var mob: Mob = null
var kills := 0


func race_class() -> Array:
	return ["dark_elf", "assassin"]


func run_step() -> void:
	var player: Player = main.player
	var hud: HUD = main.hud
	var q: Quests = main.quests
	var npcs: Npcs = main.npcs
	var eco: Economy = main.economy
	var inv: Inventory = game.inventory
	var kirk: Npc = npcs.kirk
	match step:
		0:
			_unit_data()
			_check_kirk_place()
			_check_hud_layout()
			check(kirk.mark_text() == "!" and kirk.mark_kind == "offer", "над Кирком золотой «!»: «%s»" % kirk.mark_text())
			check(eco.merchant.mark_text() == "", "над торговцем значка нет")
			check(not hud.is_button_visible("talk"), "кнопка «Говорить» скрыта вдали от Кирка")
			check(q.tracker != null and not q.tracker.visible, "трекер скрыт: заданий нет")
			# Журнал без заданий
			main._on_action("quest_window")
			check(q.window.is_open() and q.window.buttons.has("tab_active") and q.window.buttons.has("tab_done"),
				"журнал открыт: вкладки «Активные / Выполненные»")
			check(_has_text("Активных заданий нет"), "пустой журнал: подсказка, к кому идти")
			main._on_action("quest_window")
			check(not hud.is_window_open(), "журнал закрывается повторным действием (J)")
			main._on_action("talk")
			check(not npcs.is_dialog_open(), "вдали «Говорить» диалог не открывает")
			_go_to_kirk(2.0)
			wait = 3
			step = 1
		1:
			check(hud.is_button_visible("talk") and hud.button_text("talk") == "Говорить", "рядом с Кирком — кнопка «Говорить»")
			main._on_action("talk")
			check(npcs.is_dialog_open() and npcs.dialog_npc == "kirk", "диалог с Учителем Кирком открыт")
			check(npcs.reply == NpcData.greet("kirk", "offer"), "реплика — приглашение к заданию: " + npcs.reply)
			check(_has_text("Наставник укротителей"), "под именем — титул")
			for b in ["opt_quests", "opt_trade", "opt_bye"]:
				check(npcs.buttons.has(b), "вариант диалога: %s" % b)
			check((npcs.buttons["opt_quests"] as Button).text.contains("(!)"), "у «Задания» отметка нового")
			# «Задания» → список → первое задание
			_press_dialog("opt_quests")
			check(npcs.page == "quests" and npcs.buttons.has("dq_kirk_first_card"), "в списке — «Первая карта»")
			check(not npcs.buttons.has("dq_kirk_soul"), "следующее задание цепочки ещё не видно")
			_press_dialog("dq_kirk_first_card")
			check(npcs.page == "quest" and npcs.buttons.has("accept"), "страница задания: «Взять задание»")
			check(npcs.reply == String(QuestData.get_quest("kirk_first_card")["offer"]), "реплика при выдаче")
			check(_has_text("Купить карту существа у Учителя Кирка") and _has_text("0/1"), "цель с прогрессом")
			check(_find_live(hud._window, "reward_mirror_card") == null and _has_text("Опыт: 35"), "награда показана")
			_press_dialog("accept")
			check(q.state("kirk_first_card") == "active" and game.quests_active.has("kirk_first_card"), "задание взято")
			check(game.quest_tracked == "kirk_first_card", "взятое задание отслеживается")
			check(npcs.reply == String(QuestData.get_quest("kirk_first_card")["progress"]), "реплика — напоминание")
			check(kirk.mark_kind == "active" and kirk.mark_text() == "?", "над Кирком «?» (взято)")
			check(q.tracker.visible and _tracker_has("Первая карта") and _tracker_has("0/1"), "трекер: %s" % [q.tracker_lines()])
			check(not q.accept("kirk_first_card"), "дважды не взять")
			# «Назад» → «Торговля»: окно лавки Кирка с картами существ
			_press_dialog("back")
			_press_dialog("back")
			check(npcs.page == "main", "назад — главная страница диалога")
			_press_dialog("opt_trade")
			check(eco.is_shop_open() and eco.window.seller == "kirk", "открыта лавка Учителя Кирка")
			check(not npcs.is_dialog_open(), "диалог закрыт, открыта торговля")
			var win: InventoryWindow = eco.window
			for id in ["card_panther", "card_pheasant", "card_turtle", "mirror_card"]:
				check(win.buttons.has("good_" + id), "Кирк продаёт: %s" % id)
			for id in ["potion_hp_r1", "revive_scroll", "dagger_steel"]:
				check(not win.buttons.has("good_" + id), "Кирк не продаёт: %s" % id)
			check(_has_text("Лавка Учителя Кирка"), "заголовок окна торговли")
			# Продажа из сумки — и у Кирка
			inv.add("boar_tusk", 2)
			win.refresh()
			var gold0: int = game.gold
			win.select_cell(inv.find_cell("boar_tusk"))
			check(win.buttons.has("act_sell"), "у Кирка можно продать из сумки")
			_press_shop("act_sell")
			check(game.gold == gold0 + int(ItemData.get_item("boar_tusk")["sell"]), "клык продан Кирку")
			# Покупка карты фазана — цель задания
			game.gold = 100
			_press_shop("good_card_pheasant")
			_press_shop("act_buy")
			check(inv.count("card_pheasant") == 1 and game.gold == 75, "куплена карта фазана")
			check(q.is_ready("kirk_first_card") and q.goal_progress("kirk_first_card", 0) == 1, "цель выполнена 1/1")
			check(last_hud_text().contains("вернитесь к Учителю Кирку"), "сообщение: " + last_hud_text())
			check(kirk.mark_kind == "ready" and kirk.mark_text() == "=", "над Кирком «=» (можно сдать)")
			check(_tracker_has("Сдать: Учитель Кирк"), "трекер: сдать Кирку %s" % [q.tracker_lines()])
			# Торговец карт не продаёт
			check(not InventoryWindow.goods(game.class_id, "merchant").has("card_pheasant"), "у торговца карт нет")
			hud.close_window()
			# Сдача в диалоге: «Задания» → «?» → «Сдать задание»
			main._on_action("talk")
			check(npcs.reply == NpcData.greet("kirk", "ready"), "реплика — есть что сдать")
			check((npcs.buttons["opt_quests"] as Button).text.contains("(=)"), "у «Задания» отметка сдачи «=»")
			_press_dialog("opt_quests")
			check(npcs.buttons.has("dq_kirk_first_card"), "задание в списке на сдачу")
			_press_dialog("dq_kirk_first_card")
			check(npcs.buttons.has("complete") and not npcs.buttons.has("accept"), "кнопка «Сдать задание»")
			var xp0 := _total_xp()
			var g0: int = game.gold
			_press_dialog("complete")
			check(q.state("kirk_first_card") == "done" and q.times_done("kirk_first_card") == 1, "задание сдано")
			check(_total_xp() == xp0 + 35 and game.gold == g0 + 10, "награда: 35 оп., 10 зол. (опыт %d → %d)"
				% [xp0, _total_xp()])
			check(npcs.reply == String(QuestData.get_quest("kirk_first_card")["done"]), "слова Кирка при сдаче")
			check(last_hud_text().contains("«Первая карта» выполнено"), "сообщение о сдаче: " + last_hud_text())
			check(not q.tracker.visible, "трекер скрыт: активных заданий нет")
			# Следующее закрыто уровнем: серая строка «с 2 уровня», значка нет
			check(game.level == 1 and q.level_locked("kirk_soul"), "«Душа в карте» — со 2 уровня")
			check(npcs.buttons.has("dq_kirk_soul") and (npcs.buttons["dq_kirk_soul"] as Button).disabled,
				"в списке — недоступное по уровню задание")
			check(kirk.mark_text() == "", "над Кирком нет значка, пока уровень мал")
			check(not q.accept("kirk_soul"), "по уровню не взять")
			_press_dialog("back")
			check(npcs.reply == NpcData.greet("kirk", "wait"), "реплика — подрасти: " + npcs.reply)
			_press_dialog("opt_bye")
			check(not hud.is_window_open() and not npcs.is_dialog_open(), "«До встречи» закрывает диалог")
			# Уровень 2: «!» над Кирком
			player.gain_xp(game.xp_to_next(game.level) - game.xp)
			check(game.level == 2 and kirk.mark_kind == "offer", "2 уровень — над Кирком снова «!»")
			check(q.accept("kirk_soul"), "взято «Душа в карте»")
			check(q.goal_progress("kirk_soul", 0) == 0, "пустая карта — ещё не душа")
			step = 2
		2:
			# Душа фазана: «Приручить», победа, успех
			mob = find_mob("pheasant")
			check(mob != null, "найден фазан")
			stand_near(mob, 3.0)
			player._set_target(mob)
			var tm: Taming = main.taming
			tm.cooldown = 0.0
			main._on_action("tame")
			check(tm.marked == mob, "метка приручения на фазане")
			tm.force_roll = 0.0
			mob.take_damage(mob.hp + 5, player)
			tm.force_roll = -1.0
			check(inv.count("card_pheasant_soul") == 1, "душа фазана в карте")
			check(q.is_ready("kirk_soul"), "«Душа в карте» выполнено")
			check(last_hud_text().contains("«Душа в карте» выполнено — вернитесь к Учителю Кирку"), "сообщение: "
				+ last_hud_text())
			check(kirk.mark_kind == "ready", "над Кирком золотой «?»")
			# Сдача (рядом с Кирком), награда — зеркальная карта и золото
			player._set_target(null)
			_go_to_kirk(2.0)
			var mirrors := inv.count("mirror_card")
			var g0: int = game.gold
			check(q.complete("kirk_soul"), "«Душа в карте» сдано")
			check(inv.count("mirror_card") == mirrors + 1 + _bonus("mirror_card") and game.gold == g0 + 20,
				"награда: зеркальная карта и 20 зол.")
			_check_bonus("kirk_soul")
			# «Новый друг»: формирование и призыв
			check(q.accept("kirk_new_friend"), "взято «Новый друг»")
			check(q.goal_progress("kirk_new_friend", 0) == 0 and q.goal_progress("kirk_new_friend", 1) == 0,
				"питомцев ещё нет — цели 0/1")
			check(not q.complete("kirk_new_friend"), "невыполненное не сдать")
			check(main.taming.form("card_pheasant_soul"), "существо сформировано")
			check(game.active_pet == 0 and q.goal_done("kirk_new_friend", 0) and q.goal_done("kirk_new_friend", 1),
				"сформировано и призвано: обе цели")
			check(q.is_ready("kirk_new_friend"), "«Новый друг» выполнено")
			var jp0 := int(game.hero["jp"])
			var potions := inv.count("potion_hp_r1")
			var xp0 := _total_xp()
			check(q.complete("kirk_new_friend"), "«Новый друг» сдано")
			check(int(game.hero["jp"]) >= jp0 + 5, "JP героя +5: %d → %d" % [jp0, int(game.hero["jp"])])
			check(inv.count("potion_hp_r1") == potions + 3 + _bonus("potion_hp_r1") and _total_xp() == xp0 + 70,
				"награда: 3 зелья и 70 оп. (+ случайная %s)" % [q.last_bonus])
			_check_bonus("kirk_new_friend")
			# «Испытание связи» — с 3 уровня (за фазана и награды герой мог уже подрасти)
			if game.level < 3:
				check(kirk.mark_text() == "" and q.level_locked("kirk_bond_trial"), "«Испытание связи» — с 3 уровня")
			while game.level < 3:
				player.gain_xp(game.xp_to_next(game.level) - game.xp)
			check(kirk.mark_kind == "offer", "3 уровень — над Кирком «!»")
			check(q.accept("kirk_bond_trial"), "взято «Испытание связи»")
			check(game.quest_tracked == "kirk_bond_trial" and _tracker_has("0/5"), "трекер: 0/5 %s" % [q.tracker_lines()])
			# Без питомца победа не считается
			main.pets.recall()
			mob = find_mob("pheasant")
			check(mob != null, "найден фазан")
			stand_near(mob, 3.0)
			mob.take_damage(mob.hp + 5, player)
			check(q.goal_progress("kirk_bond_trial", 0) == 0, "без питомца победа не в счёт")
			check(main.pets.summon(0), "фазан снова призван")
			kills = 0
			step = 3
		3:
			# Пять побед с призванным питомцем
			mob = find_mob("pheasant")
			check(mob != null, "найден фазан для испытания")
			stand_near(mob, 3.0)
			mob.take_damage(mob.hp + 5, player)
			kills += 1
			# (питомец мог и сам добить зверя между кадрами — поэтому «не меньше»)
			check(q.goal_progress("kirk_bond_trial", 0) >= kills, "победа с питомцем %d/5" % kills)
			if kills == 2:
				# Сохранение и загрузка посреди задания
				check(game.save_game(), "игра сохранена")
				game.quests_active = {}
				game.quests_done = {}
				game.quest_tracked = ""
				check(game.load_game(), "игра загружена")
				check(game.quests_active.has("kirk_bond_trial") and q.goal_progress("kirk_bond_trial", 0) >= 2,
					"после загрузки — «Испытание связи» 2/5")
				for id in ["kirk_first_card", "kirk_soul", "kirk_new_friend"]:
					check(q.times_done(id) == 1, "после загрузки сдано: %s" % id)
				check(game.quest_tracked == "kirk_bond_trial", "отслеживаемое задание восстановлено")
				q.refresh_tracker()
				check(_tracker_has("/5"), "трекер после загрузки: %s" % [q.tracker_lines()])
				wait = 3
			if q.is_ready("kirk_bond_trial"):
				step = 4
			check(kills <= 5, "пяти побед хватило")
		4:
			check(q.is_ready("kirk_bond_trial"), "«Испытание связи» выполнено")
			# Журнал: вкладки, цели с галочками, награды со значками, касание трекера
			check(q.tracker.visible and _tracker_has("5/5") and _tracker_has("Сдать: Учитель Кирк"),
				"трекер: %s" % [q.tracker_lines()])
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			q._on_tracker_input(ev)
			var w: QuestWindow = q.window
			check(w.is_open() and w.selected == "kirk_bond_trial" and w.tab == "active", "касание трекера — журнал")
			check(w.buttons.has("q_kirk_bond_trial") and w.buttons.has("track") and w.buttons.has("abandon"),
				"в журнале: задание, «Отслеживать», «Отказаться»")
			check(_has_text("Победить зверей вместе с питомцем") and _has_text("5/5"), "цель с прогрессом")
			check(_has_text("Все цели выполнены — вернитесь к Учителю Кирку"), "подсказка, кому сдавать")
			check(_find_live(hud._window, "reward_revive_scroll") != null, "награда-предмет со значком")
			check(_has_text("Золото: 40") and _has_text("Опыт: 100"), "награда: опыт и золото")
			check(_find_live(hud._window, "reward_random") != null and _has_text("Случайная награда: 1–2 предмета"),
				"в журнале — «Случайная награда: 1–2 предмета»")
			_press_journal("tab_done")
			check(w.tab == "done" and w.buttons.has("q_kirk_first_card") and w.buttons.has("q_kirk_new_friend"),
				"вкладка «Выполненные»")
			_press_journal("q_kirk_new_friend")
			check(_has_text("Получено") and _has_text("Очки умений: 5 JP"), "выполненное: полученная награда с JP")
			check(_find_live(hud._window, "reward_potion_hp_r1") != null, "значок зелья в награде")
			_press_journal("tab_active")
			# Отслеживание
			_press_journal("track")
			check(game.quest_tracked == "" and not q.tracker.visible, "«Не отслеживать» — трекер скрыт")
			_press_journal("track")
			check(game.quest_tracked == "kirk_bond_trial" and q.tracker.visible, "«Отслеживать» — трекер виден")
			hud.close_window()
			# Сумка полна — награду не выдать
			inv.remove("revive_scroll", inv.count("revive_scroll"))
			inv.add("sword_steel", Inventory.CAPACITY - inv.used_cells())
			check(inv.is_full(), "сумка полна")
			var g0: int = game.gold
			check(not q.complete("kirk_bond_trial"), "в полную сумку награду не выдать")
			check(last_hud_text().contains("Освободите место в сумке") and q.is_active("kirk_bond_trial")
				and game.gold == g0, "сообщение, задание осталось взятым")
			inv.remove("sword_steel", inv.count("sword_steel"))
			check(q.complete("kirk_bond_trial"), "«Испытание связи» сдано")
			check(inv.count("revive_scroll") == 1 + _bonus("revive_scroll") and game.gold == g0 + 40, "награда: свиток и 40 зол.")
			_check_bonus("kirk_bond_trial")
			for id in CHAIN:
				check(q.state(String(id)) == "done", "цепочка: %s сдано" % id)
			check(kirk.mark_text() == "", "все задания сданы — значка нет")
			check(npcs.greeting("kirk") == NpcData.greet("kirk", "idle"), "приветствие без заданий")
			# Отказ от задания: взять, отказаться в журнале, взять снова
			_unit_other_goals()
			wait = 3
			step = 5
		5:
			_check_tracker_place()
			game.quests_active.erase("kirk_bond_trial")
			game.quest_tracked = ""
			q.refresh_tracker()
			check(not q.tracker.visible, "трекер скрыт без отслеживаемого задания")
			# Диалог закрывается, если отойти
			_go_to_kirk(2.0)
			npcs.talk_to("kirk")
			check(npcs.is_dialog_open(), "диалог открыт")
			player.global_position = Vector3(0, 0.1, 7.0)
			wait = 3
			step = 6
		6:
			check(not npcs.is_dialog_open() and not hud.is_window_open(), "отошёл — диалог закрылся")
			check(not hud.is_button_visible("talk"), "вдали кнопки «Говорить» нет")
			# Старое сохранение без заданий
			game.from_dict({"name": "Старый", "race": "dark_elf", "class": "assassin", "level": 4, "gold": 30})
			check(game.quests_active.is_empty() and game.quest_tracked == "", "старое сохранение: взятых заданий нет")
			# Наёмник старой версии: всё до профессии считается сделанным (староста, мудрец, охотница, доклад)
			for id in QuestData.PRE_JOB:
				check(q.is_done(String(id)), "старое сохранение с профессией: «%s» сдано" % QuestData.quest_name(String(id)))
			check(q.is_done(QuestData.JOB_QUEST) and not q.is_done("kirk_first_card"), "профессия — задание на неё сдано, Кирк — нет")
			npcs.refresh_marks()
			check(kirk.mark_text() == "!", "старое сохранение: над Кирком «!»")
			# Сохранение с неизвестным заданием и кривым прогрессом
			game.from_dict({"version": 2, "name": "Х", "race": "dark_elf", "class": "assassin", "level": 2,
				"quests": {"active": {"no_such_quest": {"progress": [1]}, "kirk_soul": {"progress": [5.0, 3]}},
					"done": {"kirk_first_card": 1.0, "nope": 2, "sage_town_tour": 1}, "tracked": "no_such_quest",
					"chain": QuestData.CHAIN_VERSION}})
			check(game.quests_active.size() == 1 and q.goal_progress("kirk_soul", 0) == 1 and
				(game.quests_active["kirk_soul"]["progress"] as Array).size() == 1, "неизвестное задание отброшено")
			check(game.quests_done.size() == 1 and q.times_done("kirk_first_card") == 1, "сданные: только известные")
			check(game.quest_tracked == "", "отслеживается только взятое")
			game.load_note = ""
			ok_done()


# ---------- Проверки ----------

func _unit_data() -> void:
	var race0: String = game.race_id
	for k in QuestData.QUESTS:
		var id := String(k)
		check(NpcData.has_npc(QuestData.giver(id)) and NpcData.has_npc(QuestData.turn_in(id)), "%s: NPC есть" % id)
		# Тексты — у каждой расы (у старост свои)
		for r in ClassData.RACES:
			game.race_id = String(r)
			for f in QuestData.TEXT_FIELDS:
				check(QuestData.text(id, String(f)) != "", "%s (%s): текст %s" % [id, r, f])
		game.race_id = race0
		for prev in QuestData.prereqs(id):
			check(QuestData.has_quest(String(prev)), "%s: предыдущее задание %s есть" % [id, prev])
		check(not QuestData.goals(id).is_empty(), "%s: есть цели" % id)
		for g in QuestData.goals(id):
			var gd: Dictionary = g
			check(QuestData.GOAL_TYPES.has(String(gd.get("type", ""))), "%s: вид цели" % id)
			var tg := String(gd.get("target", ""))
			check(tg == "" or MobData.TYPES.has(tg), "%s: зверь цели %s" % [id, tg])
			for it in gd.get("items", []):
				var fam: bool = String(it).begins_with("potion_") and ItemData.POTION_KINDS.has(String(it).substr(7))
				check(fam or not ItemData.get_item(String(it)).is_empty(), "%s: предмет цели %s" % [id, it])
		for it in QuestData.reward_items(id):
			check(not ItemData.get_item(String(it)).is_empty(), "%s: предмет награды %s" % [id, it])
		# Опыт награды: заметно (30–70 % уровня, под который подобрана награда), но не ломает баланс
		var xp := int(QuestData.rewards(id).get("xp", 0))
		var need: int = game.xp_to_next(QuestData.xp_level(id))
		check(xp >= need * 0.3 and xp <= need * 0.7, "%s: опыт %d — %d%% уровня" % [id, xp, roundi(100.0 * xp / need)])
	var last := 0
	for id in CHAIN:
		var xp := int(QuestData.rewards(String(id))["xp"])
		check(xp > last, "награды цепочки растут: %s — %d оп." % [id, xp])
		last = xp
	check(int(QuestData.get_quest("kirk_first_card")["level"]) == 1 and QuestData.get_quest("kirk_first_card")["prev"] == "",
		"первое задание — с 1 уровня")
	for i in range(1, CHAIN.size()):
		check(String(QuestData.get_quest(String(CHAIN[i]))["prev"]) == String(CHAIN[i - 1]), "цепочка: %s после %s"
			% [CHAIN[i], CHAIN[i - 1]])
	check(QuestData.reward_text("kirk_soul").contains("Зеркальная карта ×1"), "награда строкой: " + QuestData.reward_text("kirk_soul"))
	check(QuestData.goal_text({"type": "kill", "target": "wolf", "n": 3}) == "Победить зверей: Волк", "подпись цели kill")
	check(QuestData.goal_text({"type": "level", "n": 5}) == "Достичь 5 уровня", "подпись цели level")
	check(QuestData.goal_text({"type": "sell", "items": [], "npc": "merchant", "n": 3}) == "Продать вещи торговцу Гордею",
		"подпись цели sell: " + QuestData.goal_text({"type": "sell", "items": [], "npc": "merchant", "n": 3}))
	check(QuestData.goal_text({"type": "use", "items": ["potion_hp"], "n": 1}) == "Использовать: Зелье здоровья", "подпись цели use")
	check(QuestData.goal_text({"type": "store", "n": 1}) == "Положить вещь на склад", "подпись цели store")
	check(QuestData.prereqs("sage_to_hunter").size() == 3 and QuestData.prereqs("kirk_first_card").is_empty(),
		"предыдущие задания: строка или список")
	# Торговля: у Кирка карты существ, у торговца — нет
	var kg := InventoryWindow.goods("assassin", "kirk")
	check(kg == ["card_panther", "card_pheasant", "card_turtle", "mirror_card"], "товары Кирка: %s" % [kg])
	var mg := InventoryWindow.goods("assassin", "merchant")
	for id in mg:
		check(ItemData.item_type(String(id)) != "card", "у торговца нет карт: %s" % id)
	check(mg.has("potion_hp_r1") and mg.has("revive_scroll") and mg.has("dagger_steel"), "у торговца зелья, свиток, оружие")
	check(NpcData.sellers_of("card_turtle") == ["kirk"], "карту черепахи продаёт только Кирк")
	check(Taming.where_to_get("card_turtle") == "продаётся у Учителя Кирка в центре города", "где взять: "
		+ Taming.where_to_get("card_turtle"))
	# Место в сумке для нескольких наград сразу
	var a := Inventory.new()
	a.add("sword_steel", Inventory.CAPACITY - 1)
	check(a.room_for_all({"potion_hp_r1": 3}) and not a.room_for_all({"potion_hp_r1": 3, "mirror_card": 1}),
		"одна свободная ячейка — одна стопка награды")
	a.add("potion_hp_r1", 1)
	check(a.room_for_all({"potion_hp_r1": 98}) and not a.room_for_all({"potion_hp_r1": 99}), "неполная стопка принимает награду")


## Сколько штук id выпало случайной наградой последней сдачи (Quests.last_bonus).
func _bonus(id: String) -> int:
	var q: Quests = main.quests
	return int(q.last_bonus.get(id, 0))


## Случайная награда сдачи: 1–2 предмета (зелья, оружие, карты существ) ранга по уровню героя, есть в сумке
## и в сообщении о сдаче.
func _check_bonus(id: String) -> void:
	var q: Quests = main.quests
	var n := 0
	for k in q.last_bonus:
		var it := String(k)
		n += int(q.last_bonus[k])
		check(ItemData.is_potion(it) or ItemData.is_weapon(it) or ItemData.is_card(it), "%s: случайная награда — %s" % [id, it])
		if ItemData.is_potion(it):
			check(ItemData.rank(it) == ItemData.potion_rank_for_level(game.level), "зелье награды по уровню героя: %s" % it)
		if ItemData.is_weapon(it):
			check(ItemData.rank(it) == ItemData.equip_rank_for_level(game.level), "оружие награды по уровню героя: %s" % it)
		check(game.inventory.has(it), "случайная награда в сумке: %s" % it)
	check(n >= LootTable.QUEST_MIN and n <= LootTable.QUEST_MAX, "%s: случайных предметов %d (1–2)" % [id, n])
	check(last_hud_text().contains("случайная награда"), "сообщение о случайной награде: " + last_hud_text())


## Кирк в центральной деревне: проходимая ровная земля, не на дороге, не в постройке, рядом с торговцем.
func _check_kirk_place() -> void:
	var kirk: Npc = main.npcs.kirk
	check(kirk != null and kirk.is_inside_tree() and kirk.is_in_group("npc") and kirk.is_in_group("trader"),
		"Учитель Кирк в мире (NPC, торгует)")
	var w := IslandWorld.current
	var p := Vector2(kirk.global_position.x, kirk.global_position.z)
	var town: Dictionary = w.poi("town")
	var c := IslandWorld.v2(town["center"])
	check(p.distance_to(c) < float(town.get("radius", 22.0)) - 4.0 and w.in_safe_zone(kirk.global_position),
		"Кирк в городе (центральная деревня): %s" % p)
	check(w.is_walkable(p.x, p.y), "Кирк на проходимой земле")
	check(w.road_distance(p.x, p.y) >= Npcs.ROAD_CLEAR, "Кирк не на дороге: %.1f м до оси" % w.road_distance(p.x, p.y))
	check(absf(kirk.global_position.y - w.height_at(p.x, p.y)) < 0.05, "Кирк стоит на земле")
	var gap := INF
	for f in w.get_meta("poi_footprints", []):
		var fd: Dictionary = f
		var fc: Vector2 = fd["c"]
		gap = minf(gap, p.distance_to(fc) - float(fd["r"]))
	check(gap >= 0.5, "Кирк не в постройке: до ближайшего следа постройки %.1f м" % gap)
	var mp: Vector3 = main.economy.merchant.global_position
	var dm := p.distance_to(Vector2(mp.x, mp.z))
	check(dm >= Npcs.KEEP_AWAY and dm < 9.0, "Кирк рядом с торговцем: %.1f м" % dm)
	check(Npcs.spot_ok(w, p, []), "место Кирка проходит проверку")
	check(not Npcs.spot_ok(w, Vector2(19.0, 4.0), []), "на дороге NPC не ставится")
	var lbl := kirk.get_node_or_null("NameLabel") as Label3D
	check(lbl != null and lbl.text == "Учитель Кирк", "имя над головой: «Учитель Кирк»")
	var m: CharacterModel = kirk._model
	if m != null and m.spec.has("asset"):
		# Модель из файла npc_kirk.glb, посох — предмет NpcProps (подробно — tests/test_npc_models.gd)
		check(m._asset != null and String(m.spec["asset"]) == CharacterModel.npc_asset("kirk"), "модель Кирка из файла")
		check(m.mesh_count() <= 4, "модель Кирка лёгкая: мешей %d" % m.mesh_count())
		return
	check(m != null and m.weapon_kind == "staff" and String(m.spec.get("outfit", "")) == "mentor", "модель Кирка: посох, мантия")
	check(bool(m.spec.get("long_beard", false)) and m.spec != CharacterModel.merchant_spec(), "своя внешность (борода)")
	check(m.mesh_count() <= 4 and m.surface_count() <= 5, "модель Кирка лёгкая: мешей %d, поверхностей %d"
		% [m.mesh_count(), m.surface_count()])


## Меню HUD помещается на экран вместе с «Заданиями» и не налезает на панель цели; трекер не на кнопках.
func _check_hud_layout() -> void:
	var hud: HUD = main.hud
	var mb := hud.menu_buttons()
	for id in ["hero_window", "pets_window", "bag_window", "quest_window", "settings_window"]:
		check(mb.has(id), "кнопка меню: %s" % id)
	check((mb["quest_window"] as Button).tooltip_text == "Задания" and (mb["quest_window"] as Button).icon != null,
		"кнопка «Задания» в меню — значок с подсказкой")
	var view: Vector2 = hud._view
	var mr := hud.menu_rect()
	check(mr.position.x >= 0.0 and mr.end.x <= view.x, "меню помещается по ширине: %s (экран %s)" % [mr, view])
	var tr := hud.target_rect()
	check(not tr.intersects(mr) and tr.position.x >= hud.player_rect().end.x, "панель цели не под меню и не на панели игрока: %s / %s"
		% [tr, mr])
	print("  меню: %s, панель цели: %s" % [mr, tr])


## Трекер: справа вверху, под меню, не на круглых кнопках.
func _check_tracker_place() -> void:
	var hud: HUD = main.hud
	var r: Rect2 = main.quests.tracker.get_global_rect()
	check(r.end.x <= hud._view.x and r.position.y >= hud.menu_rect().end.y, "трекер под меню: %s" % r)
	for id in hud._buttons:
		if not hud.is_button_visible(String(id)):
			continue
		var b: Dictionary = hud._buttons[id]
		var cc := button_center(String(id))
		var near := Vector2(clampf(cc.x, r.position.x, r.end.x), clampf(cc.y, r.position.y, r.end.y))
		check(near.distance_to(cc) > float(b["r"]), "трекер не на кнопке %s" % id)
	check(hud.over_blocker(r.get_center()), "касание трекера не вращает камеру")


## Другие виды целей на задании-проверке (QuestData.extra): kill, collect с take, level, talk, form с
## counts_existing; задание от торговца — значок «!» над ним; повторяемое; отказ в журнале.
func _unit_other_goals() -> void:
	var q: Quests = main.quests
	var inv: Inventory = game.inventory
	var player: Player = main.player
	inv.remove("boar_tusk", inv.count("boar_tusk"))
	QuestData.extra["test_all"] = {
		"name": "Проверка целей", "giver": "merchant", "turn_in": "kirk", "level": 1, "prev": "", "repeatable": true,
		"desc": "Проверка всех видов целей.", "offer": "Вот дело.", "progress": "Ну как?", "done": "Готово!",
		"goals": [
			{"type": "kill", "target": "pheasant", "n": 2},
			{"type": "collect", "items": ["boar_tusk"], "n": 3, "take": true},
			{"type": "level", "n": game.level + 1},
			{"type": "talk", "npc": "kirk", "n": 1},
			{"type": "form", "target": "", "n": 1, "counts_existing": true},
		],
		"rewards": {"xp": 5, "gold": 1},
	}
	main.npcs.refresh_marks()
	check(main.economy.merchant.mark_text() == "!", "задание от торговца — над ним «!»")
	check(q.accept("test_all"), "взято задание-проверка")
	check(q.goal_done("test_all", 4), "form с counts_existing: существо уже есть — засчитано сразу")
	check(q.goal_progress("test_all", 2) == game.level, "level: прогресс — текущий уровень")
	check(main.npcs.kirk.mark_kind == "active", "сдавать Кирку — над ним серый «?»")
	# Отказ в журнале и повторное взятие
	q.window.open("test_all")
	_press_journal("abandon")
	check(q.window.buttons.has("abandon_yes"), "отказ — с подтверждением")
	_press_journal("abandon_yes")
	check(not q.is_active("test_all") and q.state("test_all") == "available", "отказались — задание снова доступно")
	main.hud.close_window()
	check(q.accept("test_all"), "задание-проверка взято снова")
	for i in 2:
		mob = find_mob("pheasant")
		check(mob != null, "фазан для цели kill")
		stand_near(mob, 3.0)
		mob.take_damage(mob.hp + 5, player)
	check(q.goal_progress("test_all", 0) == 2, "kill: 2/2")
	inv.add("boar_tusk", 3)
	check(q.goal_done("test_all", 1), "collect: 3 клыка в сумке")
	inv.remove("boar_tusk", 1)
	check(not q.goal_done("test_all", 1) and q.goal_progress("test_all", 1) == 2, "collect пересчитывается: 2/3")
	inv.add("boar_tusk", 2)
	player.gain_xp(game.xp_to_next(game.level) - game.xp)
	check(q.goal_done("test_all", 2), "level: новый уровень")
	check(not q.is_ready("test_all"), "без разговора не готово")
	_go_to_kirk(2.0)
	main.npcs.talk_to("kirk")
	check(q.goal_done("test_all", 3) and q.is_ready("test_all"), "talk: разговор с Кирком — всё готово")
	main.hud.close_window()
	check(main.npcs.kirk.mark_kind == "ready", "над Кирком золотой «?»")
	var tusks := inv.count("boar_tusk")
	check(q.complete("test_all"), "задание-проверка сдано")
	check(inv.count("boar_tusk") == tusks - 3, "collect с take: клыки забраны (%d → %d)" % [tusks, inv.count("boar_tusk")])
	check(q.state("test_all") == "available" and q.times_done("test_all") == 1, "повторяемое — снова доступно")
	QuestData.extra.erase("test_all")
	game.quests_done.erase("test_all")
	main.npcs.refresh_marks()
	check(main.economy.merchant.mark_text() == "", "задание убрано — значка над торговцем нет")
	check(q.accept("kirk_first_card") == false, "сданное не взять повторно")
	# Трекер на экране (место проверяется через пару кадров, когда раскладка уляжется)
	game.quests_active["kirk_bond_trial"] = {"progress": [1]}
	game.quest_tracked = "kirk_bond_trial"
	q.refresh_tracker()


# ---------- Помощники ----------

## Игрок в dist м от Кирка, со стороны центра площади.
func _go_to_kirk(dist: float) -> void:
	var kp: Vector3 = main.npcs.kirk.global_position
	var to_c := Vector3(-kp.x, 0, -kp.z).normalized()
	var p: Player = main.player
	p.global_position = kp + to_c * dist + Vector3(0, 0.1, 0)
	p.hp = p.max_hp


## Весь опыт героя с 1 уровня.
func _total_xp() -> int:
	var t: int = game.xp
	for l in range(1, game.level):
		t += game.xp_to_next(l)
	return t


func last_hud_text() -> String:
	return main.hud._msg_label.text


func _tracker_has(part: String) -> bool:
	for t in main.quests.tracker_lines():
		if String(t).contains(part):
			return true
	return false


func _press_dialog(key: String) -> void:
	var b: Button = main.npcs.buttons.get(key)
	check(b != null, "кнопка диалога %s" % key)
	if b != null:
		b.pressed.emit()


func _press_shop(key: String) -> void:
	var b: Button = main.economy.window.buttons.get(key)
	check(b != null, "кнопка торговли %s" % key)
	if b != null:
		b.pressed.emit()


func _press_journal(key: String) -> void:
	var b: Button = main.quests.window.buttons.get(key)
	check(b != null, "кнопка журнала %s" % key)
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


## Узел по имени в окне (не удалённый).
func _find_live(root: Node, node_name: String) -> Node:
	if root == null:
		return null
	for n in root.find_children(node_name, "", true, false):
		if not n.is_queued_for_deletion():
			return n
	return null
