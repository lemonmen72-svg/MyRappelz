extends "res://tests/test_base.gd"
## 0.41: 12 ячеек умений — 3 страницы по 4 кнопки, листаются свайпом по кнопкам умений (HUD.swipe, касание кнопки
## срабатывает, когда палец отпущен без свайпа); быстрые слоты quick1…quick3 (зелья и усилители без захода в сумку,
## назначение из карточки предмета, у зелья — лучшее того же вида, сохранение).


func race_class() -> Array:
	return ["human", "warrior"]


func hero_level() -> int:
	return 30


func run_step() -> void:
	match step:
		0:
			if not bool(main.get("_started")):
				return
			_pages()
			_quick()
			ok_done()


func _pages() -> void:
	var p: Player = main.player
	var hud: HUD = main.hud
	AdminPanel.learn_all(main)
	check((game.hero["slots"] as Array).size() == HeroSkills.TOTAL_SLOTS, "ячеек умений %d" % (game.hero["slots"] as Array).size())
	# Активное умение на 2-ю страницу, кнопка 2
	var act := ""
	for id in (game.hero["skills"] as Dictionary):
		if HeroSkills.kind(String(id)) == "active" and not (game.hero["slots"] as Array).has(String(id)):
			act = String(id)
			break
	check(act != "", "есть свободное активное умение")
	check(p.assign_slot(act, 5), "назначено в ячейку 6 (страница 2, кнопка 2)")
	main.refresh_skill_buttons()
	check(HeroSkills.page == 0 and p.skill_id("skill2") != act, "на 1-й странице кнопка 2 — не оно")
	check(hud._page_label != null and hud._page_label.visible and hud._page_label.text.begins_with("●"),
		"над кнопками — точки страниц: %s" % (hud._page_label.text if hud._page_label != null else "—"))
	# Свайп пальцем влево по кнопкам умений — 2-я страница
	var c := button_center("skill1")
	touch(true, 2, c)
	var dr := InputEventScreenDrag.new()
	dr.index = 2
	dr.position = c - Vector2(UiScale.px(HUD.SWIPE_MIN) + 10.0, 0)
	hud._input(dr)
	touch(false, 2, dr.position)
	check(HeroSkills.page == 1 and p.skill_id("skill2") == act, "свайп влево — страница 2, на кнопке 2 «%s»" % act)
	check(hud._page_label.text.begins_with("○ ●"), "точки: %s" % hud._page_label.text)
	check(last_hud_text().contains("страница 2 из 3"), "сообщение: " + last_hud_text())
	# Пустые кнопки 2-й страницы видны (иначе не пролистать обратно)
	check(hud._buttons["skill1"]["panel"].visible, "пустая кнопка на 2-й странице видна")
	# Касание без свайпа — умение (срабатывает при отпускании)
	var t0: float = p.skill_cd.get(act, 0.0)
	var b2 := button_center("skill2")
	touch(true, 3, b2)
	check(float(p.skill_cd.get(act, 0.0)) == t0, "при касании ещё не применено")
	touch(false, 3, b2)
	var used: bool = float(p.skill_cd.get(act, 0.0)) > t0 or p.casting != "" or last_hud_text() != ""
	check(used, "отпустил — умение нажато («%s»)" % last_hud_text())
	p.cancel_cast("тест")
	# Вправо дважды — по кругу на 3-ю
	main._on_skill_swipe(-1)
	main._on_skill_swipe(-1)
	check(HeroSkills.page == 2, "листание по кругу: страница %d" % (HeroSkills.page + 1))
	main._on_skill_swipe(1)
	check(HeroSkills.page == 0, "снова 1-я страница")
	# Сохранение: 12 ячеек
	var d: Dictionary = game.to_dict()
	check(((d["hero"] as Dictionary)["slots"] as Array).size() == 12 and String(d["hero"]["slots"][5]) == act,
		"ячейки в сохранении")


func _quick() -> void:
	var p: Player = main.player
	var eco: Node = main.economy
	var inv: Inventory = game.inventory
	check(main.hud.has_button("quick1") and main.hud.has_button("quick3"), "три быстрых слота на экране")
	# Пустой слот — открывает сумку на «Зелья и усиления»
	game.quick = ["", "", ""]
	eco.use_quick(0)
	check(eco.window.is_open() and eco.window.bag_tab == "potions", "пустой слот — сумка, раздел зелий")
	main.hud.close_window()
	eco.window.bag_tab = "all"
	inv.add("potion_hp_r1", 2)
	inv.add("potion_hp_r2", 1)
	inv.add("potion_aspd_r1", 1)
	eco.set_quick(0, "potion_hp_r1")
	eco.set_quick(1, "potion_aspd_r1")
	check(Economy.quick_item(0) == "potion_hp_r2" or Economy.quick_item(0) == "potion_hp_r1",
		"в слоте 1 — лучшее зелье здоровья: %s" % Economy.quick_item(0))
	check(Economy.quick_count(0) == Economy.potion_count("hp"), "число в слоте — все зелья вида")
	p.hp = maxi(1, p.max_hp / 3)
	eco._potion_cd = 0.0
	var n0 := Economy.potion_count("hp")
	check(eco.use_quick(0) and Economy.potion_count("hp") == n0 - 1, "быстрый слот 1 — выпито зелье здоровья")
	check(eco.use_quick(1) and inv.count("potion_aspd_r1") == 0, "быстрый слот 2 — ускорение атаки")
	check(not eco.use_quick(1) and last_hud_text().begins_with("Нет:"), "ускорений больше нет: " + last_hud_text())
	# Тот же предмет в другой слот — переезжает
	eco.set_quick(2, "potion_hp_r1")
	check(String(game.quick[0]) == "" and String(game.quick[2]) == "potion_hp_r1", "переехал в слот 3")
	var d: Dictionary = game.to_dict()
	game.from_dict(d)
	check(String(game.quick[2]) == "potion_hp_r1" and String(game.quick[1]) == "potion_aspd_r1", "слоты в сохранении")
	# Карточка зелья в сумке — «В быстрый слот 1–3»
	eco.open_bag()
	eco.window.select_cell(inv.find_cell("potion_hp_r1"))
	check(eco.window.buttons.has("act_quick_1") and eco.window.buttons.has("act_quick_3"), "в карточке — «В быстрый слот»")
	(eco.window.buttons["act_quick_1"] as Button).pressed.emit()
	check(String(game.quick[0]) == "potion_hp_r1", "назначено из карточки")
	main.hud.close_window()


func last_hud_text() -> String:
	return main.hud._msg_label.text
