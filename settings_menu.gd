class_name SettingsMenu
extends RefCounted
## Окно настроек (через HUD.create_window) с вкладками над прокруткой:
## - «Графика»: общий пресет «Низкое / Среднее / Высокое / Максимальное» («Свои» — если настройку меняли вручную)
##   и отдельные настройки Quality.OPTIONS (разрешение 3D, тени, сглаживание, дальность, трава, текстуры, контуры,
##   постобработка, эффекты, тени на персонажах), предел кадров 30 / 45 / 60. Всё применяется сразу
##   (Quality.apply), густота травы и цветов — при следующем запуске игры;
## - «Интерфейс»: размер интерфейса «Мелкий / Средний / Крупный» (UiScale): тема, HUD (кнопки, джойстик, панели,
##   меню, трекер) — сразу, окно настроек открывается заново уже в новом размере; другие окна — при следующем
##   открытии, надписи в мире — у новых;
## - «Прочее»: версия игры и пакет ресурсов, админ-панель (AdminPanel.ADMIN_TOOLS = false — убрать).
## Все вкладки строятся сразу (неоткрытые скрыты), поэтому кнопки всех вкладок есть в buttons.
## Вкладки — значками UiIcons (tab_graphics, tab_interface, tab_other; подсказка — название), название открытой
## вкладки — заголовком её страницы.
## Открытие: SettingsMenu.open(hud) (действие HUD "settings_window"), SettingsMenu.open(hud, "ui") — на вкладке.
## Кнопки открытого окна для тестов (buttons): вкладки "tab_<graphics|ui|other>", "ui_<0..2>", "quality_<0..3>"
## (пресеты), "<настройка>_<вариант>" (например "shadows_2", "aa_1" — Quality.OPTIONS), "fps_<30|45|60>",
## "admin" (AdminPanel,
## только у аккаунта Dedok_max), "account" (сменить персонажа / выйти из аккаунта — main.back_to_menu).

## Размер окна для «Среднего» размера интерфейса.
const WINDOW_SIZE := Vector2(720, 600)
const NOTE_COLOR := Color(1.0, 0.86, 0.55)
const TEXT_COLOR := Color(0.98, 0.96, 0.9)
const HINT_COLOR := Color(0.78, 0.8, 0.86)
## Ширина подписи настройки слева от кнопок, px («Средний»).
const LABEL_W := 180.0
## Вкладки: [id, название, значок UiIcons]. Кнопки вкладок — значками (подсказка — название), название вкладки —
## заголовком в начале её страницы.
const TABS := [["graphics", "Графика", "tab_graphics"], ["ui", "Интерфейс", "tab_interface"], ["other", "Прочее", "tab_other"]]
## Высота значка на кнопке вкладки («Средний»).
const TAB_ICON := 30.0

static var buttons: Dictionary = {}
## Открытая (последняя) вкладка.
static var tab := "graphics"
static var _pages: Dictionary = {}
static var _scroll: ScrollContainer = null


static func open(hud: HUD, which: String = "", keep_scroll: bool = false) -> void:
	if hud == null or not is_instance_valid(hud):
		return
	var keep := 0
	if keep_scroll and is_instance_valid(_scroll) and not _scroll.is_queued_for_deletion():
		keep = _scroll.scroll_vertical
	if which != "":
		tab = which
	buttons.clear()
	_pages.clear()
	var body := hud.create_window("Настройки", WINDOW_SIZE)
	_scroll = body.get_parent() as ScrollContainer
	_add_tabs(hud, body)
	_build_graphics(hud, _page(body, "graphics"))
	_build_ui(hud, _page(body, "ui"))
	_build_other(hud, _page(body, "other"))
	show_tab(tab)
	if keep > 0 and _scroll != null:
		# Прокрутку можно вернуть, когда содержимое разложено (в начале следующего кадра)
		var sc := _scroll
		var restore := func() -> void:
			if is_instance_valid(sc):
				sc.scroll_vertical = keep
		sc.get_tree().process_frame.connect(restore, CONNECT_ONE_SHOT)


## Показать вкладку (без перестройки окна).
static func show_tab(id: String) -> void:
	if not _pages.has(id):
		id = "graphics"
	tab = id
	for k in _pages:
		var page := _pages[k] as Control
		if is_instance_valid(page):
			page.visible = String(k) == id
	for t in TABS:
		var tid := String(t[0])
		var b := buttons.get("tab_" + tid) as Button
		if b != null and is_instance_valid(b):
			b.set_pressed_no_signal(tid == id)
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = 0


## Вкладки — над прокруткой (как в окне героя и админ-панели).
static func _add_tabs(_hud: HUD, body: VBoxContainer) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", int(UiScale.px(UiScale.GAP)))
	var root: Node = null
	if body.get_parent() != null:
		root = body.get_parent().get_parent()
	if root is VBoxContainer:
		root.add_child(bar)
		root.move_child(bar, 1)
	else:
		body.add_child(bar)
	for t in TABS:
		var id := String(t[0])
		var b := UiIcons.icon_button(String(t[2]), TAB_ICON)
		b.tooltip_text = String(t[1])
		b.toggle_mode = true
		b.button_pressed = id == tab
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(UiScale.px(110), UiScale.px(UiScale.TAB_H))
		b.pressed.connect(func() -> void: SettingsMenu.show_tab(id))
		bar.add_child(b)
		buttons["tab_" + id] = b


static func _page(body: VBoxContainer, id: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = "Page_" + id
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", int(UiScale.px(UiScale.GAP)))
	body.add_child(page)
	_pages[id] = page
	# Название вкладки — заголовком страницы (кнопка вкладки — только значок)
	for t in TABS:
		if String(t[0]) == id:
			var title := Label.new()
			title.name = "TabTitle"
			title.text = String(t[1])
			title.add_theme_font_size_override("font_size", UiScale.fs(UiScale.FONT_NAME))
			title.add_theme_color_override("font_color", NOTE_COLOR)
			page.add_child(title)
	return page


# ---------- Графика ----------

static func _build_graphics(hud: HUD, page: VBoxContainer) -> void:
	var cur := Quality.level()
	page.add_child(_head("Общее качество: %s" % Quality.level_name(cur)))
	var row := _row(page)
	for l in Quality.ULTRA + 1:
		var lvl := l
		_choice(row, "quality_%d" % l, Quality.level_name(l), l == cur, func() -> void: SettingsMenu._select(hud, lvl))
	page.add_child(_wrap_label(Quality.description(cur), UiScale.FONT_TEXT, TEXT_COLOR))

	for k in Quality.OPTIONS:
		var key := String(k)
		_option_row(hud, page, key)
		if key == "render":
			_fps_row(hud, page)

	var note := "Всё, кроме густоты травы, меняется сразу. Густота травы и цветов — при следующем запуске игры."
	var built := IslandVegetation.built_grass(hud.get_tree())
	if built >= 0 and built != Quality.option("grass"):
		note += "\nСейчас трава построена с густотой «%s»." % Quality.option_label("grass", built)
	page.add_child(_wrap_label(note, UiScale.FONT_BODY, NOTE_COLOR))


## Строка настройки: подпись слева, варианты кнопками справа, подсказка ниже.
static func _option_row(hud: HUD, page: VBoxContainer, key: String) -> void:
	var row := _row(page)
	row.add_child(_side_label(Quality.option_title(key)))
	var cur := Quality.option(key)
	for v in Quality.option_count(key):
		var val := v
		_choice(row, "%s_%d" % [key, v], Quality.option_label(key, v), v == cur,
			func() -> void: SettingsMenu._select_option(hud, key, val))
	var hint := Quality.option_hint(key)
	if hint != "":
		page.add_child(_wrap_label(hint, UiScale.FONT_SMALL, HINT_COLOR))


static func _fps_row(hud: HUD, page: VBoxContainer) -> void:
	var row := _row(page)
	row.add_child(_side_label("Кадров в секунду"))
	for v in Quality.FPS_OPTIONS:
		var fps := int(v)
		_choice(row, "fps_%d" % fps, str(fps), fps == Quality.fps_limit(), func() -> void: SettingsMenu._select_fps(hud, fps))
	page.add_child(_wrap_label("Не больше стольких кадров. Меньше — телефон меньше греется и дольше держит батарея.",
		UiScale.FONT_SMALL, HINT_COLOR))


# ---------- Интерфейс ----------

static func _build_ui(hud: HUD, page: VBoxContainer) -> void:
	page.add_child(_head("Размер интерфейса: %s" % UiScale.level_name()))
	var ui_row := _row(page)
	for l in 3:
		var lvl := l
		_choice(ui_row, "ui_%d" % l, UiScale.level_name(l), l == UiScale.level(),
			func() -> void: SettingsMenu._select_ui(hud, lvl))
	page.add_child(_wrap_label("Кнопки, окна, надписи и джойстик. «Мелкий» — больше места для обзора, «Крупный» — "
		+ "крупнее текст и кнопки.", UiScale.FONT_BODY, NOTE_COLOR))


# ---------- Прочее ----------

static func _build_other(hud: HUD, page: VBoxContainer) -> void:
	var ver := Assets.game_version()
	page.add_child(_head("Версия игры: %s" % (ver if ver != "" else "разработка")))
	var pack := "Пакет моделей: загружен."
	if not Assets.available():
		var have := Assets.ready_count()
		pack = ("Пакет моделей загружен частично (частей: %d из %d) — остальные модели запасные." % [have,
			Assets.PACKS.size()]) if have > 0 else "Пакет моделей не загружен — показаны запасные модели героев и зверей."
	page.add_child(_wrap_label(pack, UiScale.FONT_BODY, TEXT_COLOR))
	# Админ-панель для тестирования — только у аккаунта Dedok_max (AdminPanel.enabled; ADMIN_TOOLS = false — убрать)
	var main_node := hud.get_parent()
	if AdminPanel.enabled():
		var admin_row := _row(page)
		_choice(admin_row, "admin", "Админ-панель: герой, опыт, предметы, питомцы, мир", false,
			func() -> void: AdminPanel.open(main_node))
	# Сменить персонажа или аккаунт: сохранить и вернуться к экрану выбора персонажа (main.back_to_menu)
	if main_node != null and main_node.has_method("back_to_menu"):
		var acc_row := _row(page)
		_choice(acc_row, "account", "Сменить персонажа / выйти из аккаунта", false,
			func() -> void: main_node.call("back_to_menu"))


# ---------- Элементы ----------

static func _row(body: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiScale.px(10)))
	body.add_child(row)
	return row


static func _head(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", UiScale.fs(UiScale.FONT_HEAD))
	return l


static func _side_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(UiScale.px(LABEL_W), 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", UiScale.fs(UiScale.FONT_TEXT))
	return l


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
	open(hud, "ui")


## Пресет графики: все настройки по нему, применить сразу.
static func _select(hud: HUD, l: int) -> void:
	if hud == null or not is_instance_valid(hud):
		return
	Quality.set_level(l)
	Quality.apply(hud.get_tree())
	open(hud, "graphics", true)


## Одна настройка графики (пресет станет «Свои», если не совпадёт ни с одним), применить сразу.
static func _select_option(hud: HUD, key: String, v: int) -> void:
	if hud == null or not is_instance_valid(hud):
		return
	Quality.set_option(key, v)
	Quality.apply(hud.get_tree())
	open(hud, "graphics", true)


static func _select_fps(hud: HUD, v: int) -> void:
	if hud == null or not is_instance_valid(hud):
		return
	Quality.set_fps_limit(v)
	open(hud, "graphics", true)


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
