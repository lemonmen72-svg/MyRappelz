extends "res://tests/test_base.gd"
## Значки интерфейса (UiIcons): каждый id контракта даёт текстуру — картинку assets/icons/ui/<id>.png или
## процедурный рисунок (непустой, с прозрачными краями) — и подпись; кнопки меню HUD, «Существо», вкладки настроек,
## окна героя и существа и «Закрыть» — значками (подпись — подсказкой); долгое касание по значку меню показывает
## подпись и не нажимает кнопку, короткое — нажимает; джойстик — картинками, если они есть.

var _actions: Array[String] = []
var _menu_btn: Button = null


func race_class() -> Array:
	return ["dark_elf", "assassin"]


func before_start() -> void:
	game.add_pet("panther", "Тень", 5)
	game.active_pet = 0


func run_step() -> void:
	var hud: HUD = main.hud
	match step:
		0:
			wait = 5
			step = 1
		1:
			_check_textures()
			_check_hud(hud)
			_check_windows(hud)
			# Долгое касание по значку «Сумка»: подпись, без действия
			hud.action.connect(func(id: String) -> void: _actions.append(id))
			_menu_btn = hud.menu_buttons()["bag_window"] as Button
			_menu_btn.button_down.emit()
			wait = int(ceil(HUD.HOLD_TIP * 60.0)) + 6
			step = 2
		2:
			check(hud._fx_tip.visible and hud._fx_tip.text == "Сумка", "долгое касание — подпись «%s»" % hud._fx_tip.text)
			_menu_btn.button_up.emit()
			_menu_btn.pressed.emit()
			check(not _actions.has("bag_window") and not hud.is_window_open(), "после подписи кнопка не нажалась")
			# Короткое касание — действие
			_menu_btn.button_down.emit()
			_menu_btn.button_up.emit()
			_menu_btn.pressed.emit()
			check(_actions.has("bag_window") and hud.is_window_open(), "короткое касание открывает сумку")
			hud.close_window()
			ok_done()


func _check_textures() -> void:
	check(UiIcons.IDS.size() == 30, "в контракте 30 значков: %d" % UiIcons.IDS.size())
	var files := 0
	for k in UiIcons.IDS:
		var id := String(k)
		var tex := UiIcons.texture(id)
		check(tex != null and tex.get_width() > 0, "значок %s: %s" % [id, "файл" if UiIcons.has_file(id) else "рисунок"])
		if UiIcons.has_file(id):
			files += 1
		check(UiIcons.NAMES.has(id) and UiIcons.title(id) != id, "подпись значка %s: «%s»" % [id, UiIcons.title(id)])
	# Процедурные рисунки (запасные): непустые, края прозрачные
	UiIcons.force_procedural = true
	var t0 := Time.get_ticks_msec()
	for k in UiIcons.IDS:
		var id := String(k)
		var tex := UiIcons.texture(id)
		check(tex != null and tex.get_width() == UiIcons.SIZE, "рисунок %s %d px" % [id, tex.get_width() if tex != null else 0])
		if tex == null:
			continue
		var img := tex.get_image()
		var solid := 0
		for y in range(0, img.get_height(), 2):
			for x in range(0, img.get_width(), 2):
				if img.get_pixel(x, y).a > 0.5:
					solid += 1
		check(solid >= 8 and img.get_pixel(0, 0).a < 0.05, "рисунок %s не пустой (%d), угол прозрачный" % [id, solid])
	print("  процедурные рисунки: %d мс, файлов-картинок: %d из %d" % [Time.get_ticks_msec() - t0, files, UiIcons.IDS.size()])
	UiIcons.force_procedural = false
	var s := UiIcons.icon_spec("btn_talk", {"shape": "talk"})
	check(String(s.get("shape", "")) == "talk" and s.has("path") == UiIcons.has_file("btn_talk"), "спецификация кнопки: %s" % [s])


func _check_hud(hud: HUD) -> void:
	var mb := hud.menu_buttons()
	var want := {"hero_window": "Герой", "pets_window": "Питомцы", "bag_window": "Сумка", "quest_window": "Задания",
		"settings_window": "Настройки"}
	check(mb.size() == 5, "5 кнопок меню: %s" % [mb.keys()])
	for id in want:
		var b := mb.get(id) as Button
		check(b != null and b.text == "" and b.icon != null and b.tooltip_text == String(want[id]),
			"меню %s — значок, подсказка «%s»" % [id, b.tooltip_text if b != null else ""])
	check(hud.menu_titles().get("quest_window", "") == "Задания", "подписи меню: %s" % [hud.menu_titles()])
	var cr: Button = null
	for c in hud._pet_btns.get_children():
		if c is Button and String((c as Button).get_meta("action", "")) == "creature_window":
			cr = c as Button
	check(cr != null and cr.text == "" and cr.icon != null and cr.tooltip_text == "Существо", "«Существо» у питомца — значок")
	for id in ["pet_auto", "pet_attack", "pet_defend", "pet_follow", "talk", "shop"]:
		var ic := hud.button_icon(String(id))
		check(ic != null, "круглая кнопка %s — значок" % id)
	check(hud.joystick_skinned() == UiIcons.has_file("joystick_base"), "джойстик — картинка, только если она есть")
	check(hud._gold_icon.texture != null and hud._gold_label.text == str(game.gold), "золото со значком: %s" % hud._gold_label.text)


func _check_windows(hud: HUD) -> void:
	SettingsMenu.open(hud, "graphics")
	for e in [["tab_graphics", "Графика"], ["tab_ui", "Интерфейс"], ["tab_other", "Прочее"]]:
		var b := SettingsMenu.buttons.get(String(e[0])) as Button
		check(b != null and b.text == "" and b.icon != null and b.tooltip_text == String(e[1]),
			"вкладка настроек %s — значок «%s»" % [e[0], b.tooltip_text if b != null else ""])
	var page := SettingsMenu._pages.get("ui") as Control
	var title: Label = null
	if page != null:
		title = page.get_node_or_null("TabTitle") as Label
	check(title != null and title.text == "Интерфейс", "название вкладки — заголовок страницы")
	var close := hud._window.find_child("CloseButton", true, false) as Button
	check(close != null and close.text == "" and close.icon != null and close.tooltip_text == "Закрыть", "«Закрыть» — значок ×")
	close.pressed.emit()
	check(not hud.is_window_open(), "значок × закрывает окно")
	main.hero_window.open("hero")
	var hb := main.hero_window.buttons.get("tab_hero") as Button
	check(hb != null and hb.icon != null and hb.text == "Герой", "вкладка «Герой» — значок и подпись")
	hud.close_window()
	main.pets.open_creature(0, "stats")
	var cw: CreatureWindow = main.pets.creature
	for k in ["tab_stats", "tab_skills", "back"]:
		var b := cw.buttons.get(k) as Button
		check(b != null and b.icon != null and b.text != "", "окно существа: %s — значок и подпись «%s»" % [k, b.text if b != null else ""])
	hud.close_window()
