class_name SettingsMenu
extends RefCounted
## Окно настроек (через HUD.create_window): размер интерфейса «Мелкий / Средний / Крупный» (UiScale),
## три пресета качества графики и описание текущего, предел кадров в секунду (30 / 45 / 60).
## Размер интерфейса применяется сразу: тема, HUD (кнопки, джойстик, панели, меню, трекер), окно настроек
## открывается заново уже в новом размере; другие окна — при следующем открытии, надписи в мире — у новых.
## Тени солнца, постобработка, дальность и контуры растительности применяются сразу
## (Quality.apply), густота травы и цветов — при следующем запуске игры.
## Открытие: SettingsMenu.open(hud) (действие HUD "settings_window").
## Кнопки открытого окна для тестов (buttons): "ui_<0..2>", "quality_<0..2>", "fps_<30|45|60>", "admin" (AdminPanel,
## только у аккаунта Dedok_max), "account" (сменить персонажа / выйти из аккаунта — main.back_to_menu).

## Размер окна для «Среднего» размера интерфейса (было 680×600).
const WINDOW_SIZE := Vector2(620, 590)
const NOTE_COLOR := Color(1.0, 0.86, 0.55)

static var buttons: Dictionary = {}


static func open(hud: HUD) -> void:
	if hud == null or not is_instance_valid(hud):
		return
	buttons.clear()
	var body := hud.create_window("Настройки", WINDOW_SIZE)

	var ui_title := Label.new()
	ui_title.text = "Размер интерфейса: %s" % UiScale.level_name()
	body.add_child(ui_title)
	var ui_row := _row(body)
	for l in 3:
		var lvl := l
		_choice(ui_row, "ui_%d" % l, UiScale.level_name(l), l == UiScale.level(),
			func() -> void: SettingsMenu._select_ui(hud, lvl))
	body.add_child(_wrap_label("Кнопки, окна, надписи и джойстик. «Мелкий» — больше места для обзора, «Крупный» — "
		+ "крупнее текст и кнопки.", UiScale.FONT_BODY, NOTE_COLOR))

	var cur := Quality.level()
	var title := Label.new()
	title.text = "Качество графики: %s" % Quality.level_name(cur)
	body.add_child(title)
	var row := _row(body)
	for l in 3:
		var lvl := l
		_choice(row, "quality_%d" % l, Quality.level_name(l), l == cur, func() -> void: SettingsMenu._select(hud, lvl))
	body.add_child(_wrap_label(Quality.description(cur), UiScale.FONT_TEXT, Color(0.98, 0.96, 0.9)))
	var note := "Тени и постобработка меняются сразу. Густота травы и цветов — при следующем запуске игры."
	var built := IslandVegetation.built_level(hud.get_tree())
	if built >= 0 and built != cur:
		note += "\nСейчас трава построена для качества «%s»." % Quality.level_name(built)
	body.add_child(_wrap_label(note, UiScale.FONT_BODY, NOTE_COLOR))

	var fps_title := Label.new()
	fps_title.text = "Кадров в секунду: не больше %d" % Quality.fps_limit()
	body.add_child(fps_title)
	var fps_row := _row(body)
	for v in Quality.FPS_OPTIONS:
		var fps := int(v)
		_choice(fps_row, "fps_%d" % fps, str(fps), fps == Quality.fps_limit(), func() -> void: SettingsMenu._select_fps(hud, fps))
	body.add_child(_wrap_label("Меньше кадров — телефон меньше греется и дольше держит батарея.", UiScale.FONT_BODY,
		NOTE_COLOR))

	# Админ-панель для тестирования — только у аккаунта Dedok_max (AdminPanel.enabled; ADMIN_TOOLS = false — убрать)
	var main_node := hud.get_parent()
	if AdminPanel.enabled():
		var admin_row := _row(body)
		_choice(admin_row, "admin", "Админ-панель: герой, опыт, предметы, питомцы, мир", false,
			func() -> void: AdminPanel.open(main_node))
	# Сменить персонажа или аккаунт: сохранить и вернуться к экрану выбора персонажа (main.back_to_menu)
	if main_node != null and main_node.has_method("back_to_menu"):
		var acc_row := _row(body)
		_choice(acc_row, "account", "Сменить персонажа / выйти из аккаунта", false,
			func() -> void: main_node.call("back_to_menu"))


static func _row(body: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiScale.px(10)))
	body.add_child(row)
	return row


## Кнопка выбора в ряду (нажатая — текущий вариант).
static func _choice(row: HBoxContainer, key: String, text: String, on: bool, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = on
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, UiScale.button_h())
	b.pressed.connect(cb)
	row.add_child(b)
	buttons[key] = b


## Размер интерфейса: сохранить, применить к теме и HUD, открыть окно заново в новом размере.
static func _select_ui(hud: HUD, l: int) -> void:
	if hud == null or not is_instance_valid(hud):
		return
	UiScale.set_level(l)
	hud.apply_ui_scale()
	open(hud)


static func _select(hud: HUD, l: int) -> void:
	if hud == null or not is_instance_valid(hud):
		return
	Quality.set_level(l)
	Quality.apply(hud.get_tree())
	open(hud)


static func _select_fps(hud: HUD, v: int) -> void:
	if hud == null or not is_instance_valid(hud):
		return
	Quality.set_fps_limit(v)
	open(hud)


## Текст с переносом; font_size — для «Среднего» размера интерфейса (UiScale.FONT_*).
static func _wrap_label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(UiScale.px(WINDOW_SIZE.x - 60.0), 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", UiScale.fs(font_size))
	l.add_theme_color_override("font_color", color)
	return l
