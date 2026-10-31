extends "res://tests/test_base.gd"
## Масштаб интерфейса (UiScale, «Размер интерфейса» в настройках): при каждом размере — «Мелкий», «Средний»,
## «Крупный» — круглые кнопки HUD не перекрываются, помещаются на экран, не мельче 56 px и не на панелях,
## меню и панель цели на месте, трекер не на кнопках, касание по кнопке работает; все окна (герой, древо,
## существо, питомцы, сумка, лавка, журнал, диалог, настройки) и экран создания персонажа помещаются в экран,
## заголовки и обрезаемые подписи не обрезаны. Кнопки «Размер интерфейса» в настройках применяют размер сразу
## и сохраняют его; надписи над головами — компактнее прежних.

## UiScale.SMALL, MEDIUM, LARGE.
const LEVELS := [0, 1, 2]
## Окна для проверки: [что, метод, который его открывает].
const WINDOWS := [
	["окно героя", "_w_hero"], ["древо «Мечи и кинжалы»", "_w_blades"], ["древо «Арбалет»", "_w_crossbow"],
	["окно существа", "_w_creature"], ["умения существа", "_w_creature_skills"], ["питомцы", "_w_pets"],
	["сумка с картой", "_w_bag"], ["лавка Кирка", "_w_shop"], ["журнал заданий", "_w_journal"],
	["диалог", "_w_dialog"], ["задание в диалоге", "_w_dialog_quest"], ["настройки", "_w_settings"],
]
## Наименьший зазор между круглыми кнопками, px.
const MIN_GAP := 4.0

var _li := 0
var _wi := 0
var _create: CharacterCreate = null
## Содержимое user://settings.cfg до теста ("" — файла не было).
var _cfg_backup := ""
var _had_cfg := false


func race_class() -> Array:
	return ["dark_elf", "assassin"]


func before_start() -> void:
	_had_cfg = FileAccess.file_exists(UiScale.PATH)
	if _had_cfg:
		_cfg_backup = FileAccess.get_file_as_string(UiScale.PATH)
	UiScale.set_level(UiScale.MEDIUM, false)
	game.add_pet("panther", "Тень", 20)
	game.active_pet = 0
	game.inventory.add("card_panther_soul", 1)
	game.inventory.add("card_wolf", 3)
	game.inventory.add("boar_tusk", 12)


func run_step() -> void:
	var hud: HUD = main.hud
	match step:
		0:
			check(UiScale.level() == UiScale.MEDIUM and is_equal_approx(UiScale.k(), 1.0), "по умолчанию — «Средний»")
			check(Util.ui_theme().default_font_size == UiScale.FONT and UiScale.FONT <= 18,
				"шрифт темы компактный: %d (было 24)" % Util.ui_theme().default_font_size)
			_check_world_labels()
			# Рядом с Учителем Кирком: его лавка и диалог не закрываются из-за расстояния
			var kp: Vector3 = main.npcs.kirk.global_position
			var to_c := Vector3(-kp.x, 0, -kp.z).normalized()
			var pos := kp + to_c * 3.0
			if IslandWorld.current != null:
				pos.y = IslandWorld.current.height_at(pos.x, pos.z) + 0.1
			main.player.global_position = pos
			main.quests.accept("kirk_first_card")
			wait = 5
			step = 1
		1:
			# Новый размер интерфейса
			var lvl := int(LEVELS[_li])
			UiScale.set_level(lvl, false)
			hud.apply_ui_scale()
			wait = 3
			step = 2
		2:
			print("— размер интерфейса: %s (×%.2f)" % [UiScale.level_name(), UiScale.k()])
			_check_hud()
			_wi = 0
			_open_window()
			step = 3
		3:
			_check_window(String(WINDOWS[_wi][0]))
			hud.close_window()
			_wi += 1
			if _wi < WINDOWS.size():
				_open_window()
				return
			_create = CharacterCreate.new()
			get_tree().root.add_child(_create)
			wait = 4
			step = 4
		4:
			_check_create()
			_create.queue_free()
			_create = null
			_li += 1
			step = 1 if _li < LEVELS.size() else 5
			wait = 2
		5:
			_check_settings_buttons()
			wait = 3
			step = 6
		6:
			check(is_equal_approx(float(hud._buttons["attack"]["r"]), UiScale.px(60.0)) and UiScale.level() == UiScale.LARGE,
				"«Крупный» из настроек: кнопка атаки r %.0f" % float(hud._buttons["attack"]["r"]))
			UiScale.reload()
			check(UiScale.level() == UiScale.LARGE, "размер интерфейса сохранён в settings.cfg и прочитан")
			_check_window("настройки после смены размера")
			hud.close_window()
			_restore_cfg()
			hud.apply_ui_scale()
			check(UiScale.level() == UiScale.MEDIUM, "размер вернулся к «Среднему»")
			ok_done()


func _open_window() -> void:
	call(String(WINDOWS[_wi][1]))
	wait = 3


func _w_hero() -> void:
	main.hero_window.open("hero")


func _w_blades() -> void:
	main.hero_window.open("blades")


func _w_crossbow() -> void:
	main.hero_window.open("crossbow")


func _w_creature() -> void:
	main.pets.open_creature(0, "stats")


func _w_creature_skills() -> void:
	main.pets.open_creature(0, "skills")


func _w_pets() -> void:
	main.pets.open_window()


func _w_bag() -> void:
	main.economy.open_bag()
	main.economy.window.select_cell(game.inventory.find_cell("card_panther_soul"))


func _w_shop() -> void:
	main.economy.open_shop("kirk")
	main.economy.window._on_cell("good", 0)


func _w_journal() -> void:
	main.quests.window.open("kirk_first_card")


func _w_dialog() -> void:
	main.npcs.open_dialog("kirk")


func _w_dialog_quest() -> void:
	main.npcs.open_dialog("kirk", "quest", "kirk_soul")


func _w_settings() -> void:
	SettingsMenu.open(main.hud)


# ---------- HUD ----------

func _check_hud() -> void:
	var hud: HUD = main.hud
	var view: Vector2 = hud._view
	var screen := Rect2(Vector2.ZERO, view)
	var ids: Array = hud._buttons.keys()
	var min_d := INF
	var min_gap := INF
	var inside := true
	for i in ids.size():
		var a: Dictionary = hud._buttons[ids[i]]
		var ca := button_center(String(ids[i]))
		var ra := float(a["r"])
		min_d = minf(min_d, ra * 2.0)
		if ca.x - ra < 0.0 or ca.y - ra < 0.0 or ca.x + ra > view.x or ca.y + ra > view.y:
			inside = false
			print("  кнопка %s за краем экрана: центр %s, r %.0f" % [ids[i], ca, ra])
		for j in range(i + 1, ids.size()):
			var b: Dictionary = hud._buttons[ids[j]]
			var gap := ca.distance_to(button_center(String(ids[j]))) - ra - float(b["r"])
			if gap < min_gap:
				min_gap = gap
			if gap < MIN_GAP:
				print("  кнопки %s и %s: зазор %.1f px" % [ids[i], ids[j], gap])
	check(inside, "все круглые кнопки на экране")
	check(min_gap >= MIN_GAP, "круглые кнопки не перекрываются: наименьший зазор %.1f px" % min_gap)
	check(min_d >= 56.0 - 0.01, "кнопки не мельче 56 px: %.0f" % min_d)
	var attack_r := float(hud._buttons["attack"]["r"])
	check(attack_r < 85.0 * 0.85, "кнопка атаки меньше прежней (r 85): %.0f" % attack_r)
	# Касание по центру каждой видимой кнопки попадает в неё
	for id in ids:
		if hud.is_button_visible(String(id)):
			check(hud._button_at(button_center(String(id))) == String(id), "касание по кнопке %s" % id)
	touch(true, 7, button_center("attack"))
	check(hud.is_held("attack"), "касание «Атаки» держит атаку")
	touch(false, 7, button_center("attack"))

	var mr := hud.menu_rect()
	var pr := hud.player_rect()
	var tr := hud.target_rect()
	check(screen.encloses(mr), "меню на экране: %s" % mr)
	check(not tr.intersects(mr) and tr.position.x >= pr.end.x, "панель цели не на меню и не на панели игрока: %s / %s / %s"
		% [tr, mr, pr])
	var joy_r := hud._joy_r
	var joy_home := Vector2(UiScale.px(HUD.JOY_HOME.x), view.y - UiScale.px(HUD.JOY_HOME.y))
	check(joy_r < 110.0 and joy_home.x - joy_r >= 0.0 and joy_home.y + joy_r <= view.y,
		"джойстик компактный и на экране: r %.0f, центр %s" % [joy_r, joy_home])
	check(hud._pet_box.visible and hud._pet_btns.get_global_rect().end.y <= UiScale.px(HUD.JOY_TOP),
		"кнопки питомца выше зоны джойстика: %s" % hud._pet_btns.get_global_rect())
	var tracker: Control = main.quests.tracker
	check(tracker.visible, "трекер задания виден")
	var trk := tracker.get_global_rect()
	check(screen.encloses(trk) and trk.position.y >= mr.end.y, "трекер под меню и на экране: %s" % trk)
	for id in ids:
		var b: Dictionary = hud._buttons[id]
		var c := button_center(String(id))
		var r := float(b["r"])
		for rect in [mr, pr, tr, trk, hud._pet_btns.get_global_rect()]:
			var rr: Rect2 = rect
			var near := Vector2(clampf(c.x, rr.position.x, rr.end.x), clampf(c.y, rr.position.y, rr.end.y))
			if near.distance_to(c) <= r:
				check(false, "кнопка %s налезает на панель %s" % [id, rr])
		check(c.distance_to(joy_home) > r + joy_r, "кнопка %s не на джойстике" % id)
	print("  кнопки: атака r %.0f, мельчайшая Ø %.0f, зазор ≥ %.1f; меню %s; трекер %s" % [attack_r, min_d, min_gap, mr, trk])


# ---------- Окна ----------

func _check_window(what: String) -> void:
	var hud: HUD = main.hud
	check(hud.is_window_open(), "%s: окно открыто" % what)
	if not hud.is_window_open():
		return
	var view: Vector2 = hud._view
	var r := hud.window_rect()
	var w: Control = hud._window
	var need := w.get_combined_minimum_size()
	var fits := r.position.x >= -0.5 and r.position.y >= -0.5 and r.end.x <= view.x + 0.5 and r.end.y <= view.y + 0.5
	check(fits and need.x <= view.x and need.y <= view.y, "%s помещается в экран %s: %s (нужно не меньше %s)"
		% [what, view, r, need])
	# Обрезаемые подписи (заголовок окна, список заданий) — текст целиком
	for n in w.find_children("*", "", true, false):
		if n.is_queued_for_deletion():
			continue
		var text := ""
		var avail := 0.0
		var ctl := n as Control
		if n is Label and (n as Label).clip_text:
			text = (n as Label).text
			avail = ctl.size.x
		elif n is Button and (n as Button).clip_text:
			var b := n as Button
			text = b.text
			var sb := b.get_theme_stylebox("normal")
			avail = b.size.x - (sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT) if sb != null else 0.0)
		else:
			continue
		var font := ctl.get_theme_font("font")
		var fsz := ctl.get_theme_font_size("font_size")
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
		check(tw <= avail + 1.0, "%s: «%s» не обрезано (%.0f из %.0f px)" % [what, text, tw, avail])
	print("  %s: %s" % [what, r])


func _check_create() -> void:
	var view: Vector2 = main.hud._view
	var margin: MarginContainer = null
	for c in _create.get_children():
		if c is MarginContainer:
			margin = c as MarginContainer
	check(margin != null, "экран создания персонажа построен")
	if margin == null:
		return
	var need := margin.get_combined_minimum_size()
	check(need.x <= view.x + 0.5 and need.y <= view.y + 0.5, "экран создания помещается в %s: нужно %s" % [view, need])


# ---------- Настройки ----------

## Кнопки «Мелкий / Средний / Крупный» в окне настроек: применяют размер сразу (тема, HUD) и сохраняют его.
func _check_settings_buttons() -> void:
	var hud: HUD = main.hud
	UiScale.set_level(UiScale.MEDIUM, false)
	hud.apply_ui_scale()
	SettingsMenu.open(hud)
	for k in ["ui_0", "ui_1", "ui_2"]:
		check(SettingsMenu.buttons.has(k), "в настройках кнопка %s" % k)
	check((SettingsMenu.buttons["ui_1"] as Button).button_pressed, "в настройках выбран «Средний»")
	(SettingsMenu.buttons["ui_0"] as Button).pressed.emit()
	check(UiScale.level() == UiScale.SMALL and Util.ui_theme().default_font_size == UiScale.fs(UiScale.FONT),
		"«Мелкий»: шрифт темы %d" % Util.ui_theme().default_font_size)
	check(hud.is_window_open() and (SettingsMenu.buttons["ui_0"] as Button).button_pressed, "окно настроек открыто заново")
	(SettingsMenu.buttons["ui_2"] as Button).pressed.emit()


## Вернуть user://settings.cfg как было и «Средний» размер.
func _restore_cfg() -> void:
	if _had_cfg:
		var f := FileAccess.open(UiScale.PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(_cfg_backup)
			f.close()
	elif FileAccess.file_exists(UiScale.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(UiScale.PATH))
	UiScale.reload()
	Quality.reload()
	UiScale.set_level(UiScale.MEDIUM, false)


# ---------- Мир ----------

## Надписи над головами (имя и уровень зверя, имя NPC, значок задания) — компактнее прежних.
func _check_world_labels() -> void:
	var m: Mob = null
	for n in get_tree().get_nodes_in_group("mobs"):
		m = n as Mob
		if m != null:
			break
	check(m != null and m._label.pixel_size < 0.01 * 0.75, "подпись зверя компактнее: %.4f (было 0.01)"
		% (m._label.pixel_size if m != null else 0.0))
	var kirk: Npc = main.npcs.kirk
	var lbl := kirk.get_node_or_null("NameLabel") as Label3D
	var mark := kirk.get_node_or_null("QuestMark") as Label3D
	check(lbl != null and lbl.pixel_size < 0.006 * 0.75 and mark != null and mark.pixel_size < 0.008 * 0.75,
		"имя и значок над NPC компактнее")
