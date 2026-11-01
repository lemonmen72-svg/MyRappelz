class_name BotOverlay
extends CanvasLayer
## Экран тест-бота поверх игры (TestBot): узкая полоса сверху — что делает бот (сцена, настройка, шаг N из M,
## время) и «Стоп»; пауза на остывание — тёмный экран на всё окно (3D-мир не рисуется) с причиной, временем и
## «Стоп». Окно игры (HUD.create_window) не открывается: открытое окно ставит предел кадров MENU_FPS и испортило
## бы замер. Работает и на паузе дерева (process_mode ALWAYS у бота).

signal stop_pressed

const LAYER := 90
const BAR := Color(0.06, 0.08, 0.12, 0.78)
const COOL_BG := Color(0.02, 0.03, 0.05, 0.96)
const TEXT := Color(0.95, 0.93, 0.86)
const NOTE := Color(1.0, 0.82, 0.45)

var _bar: PanelContainer
var _info: Label
var _stop: Button
var _cool: Control
var _cool_title: Label
var _cool_text: Label
var _cool_stop: Button


func _init() -> void:
	name = "BotOverlay"
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_build()


func _build() -> void:
	var theme := Util.ui_theme()
	_bar = PanelContainer.new()
	_bar.theme = theme
	var sb := StyleBoxFlat.new()
	sb.bg_color = BAR
	sb.set_corner_radius_all(int(UiScale.px(UiScale.BTN_RADIUS)))
	sb.content_margin_left = UiScale.px(10)
	sb.content_margin_right = UiScale.px(6)
	sb.content_margin_top = UiScale.px(3)
	sb.content_margin_bottom = UiScale.px(3)
	_bar.add_theme_stylebox_override("panel", sb)
	_bar.position.y = UiScale.px(4)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiScale.px(8)))
	_bar.add_child(row)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", UiScale.fs(UiScale.FONT_SMALL))
	_info.add_theme_color_override("font_color", TEXT)
	_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_info)
	_stop = _button("Стоп")
	_stop.custom_minimum_size = UiScale.v2(70, 32)
	row.add_child(_stop)
	add_child(_bar)

	_cool = ColorRect.new()
	(_cool as ColorRect).color = COOL_BG
	_cool.theme = theme
	_cool.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cool.mouse_filter = Control.MOUSE_FILTER_STOP
	_cool.visible = false
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", int(UiScale.px(14)))
	_cool.add_child(box)
	_cool_title = _label("Остывание телефона…", UiScale.FONT_TITLE, NOTE)
	box.add_child(_cool_title)
	_cool_text = _label("", UiScale.FONT_TEXT, TEXT)
	_cool_text.custom_minimum_size.x = UiScale.px(640)
	_cool_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_cool_text)
	_cool_stop = _button("Остановить тест")
	_cool_stop.custom_minimum_size = UiScale.v2(220, UiScale.BUTTON_H)
	_cool_stop.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_cool_stop)
	add_child(_cool)


func _button(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", UiScale.fs(UiScale.FONT_BODY))
	b.pressed.connect(func() -> void: stop_pressed.emit())
	return b


func _label(t: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", UiScale.fs(fs))
	l.add_theme_color_override("font_color", col)
	return l


## Полоса сверху: текст про текущий шаг.
func show_running(text: String) -> void:
	if _info == null:
		return
	_bar.visible = true
	_cool.visible = false
	if _info.text != text:
		_info.text = text
		# Ширина по тексту, по центру экрана
		_bar.reset_size()
		var vw := get_viewport().get_visible_rect().size.x if get_viewport() != null else 1280.0
		_bar.position.x = maxf(0.0, roundf((vw - _bar.size.x) / 2.0))


## Экран остывания: why — причина и что ждём, sec — сколько уже ждём.
func show_cooling(why: String, sec: float) -> void:
	if _cool == null:
		return
	_bar.visible = false
	_cool.visible = true
	_cool_title.text = "Остывание телефона… %s" % TestBot.clock(sec)
	_cool_text.text = why


## Полоса и экран остывания есть (тест, кадры).
func cooling_visible() -> bool:
	return _cool != null and _cool.visible


func bar_text() -> String:
	return _info.text if _info != null else ""


## Кнопка «Стоп» полосы (тест).
func stop_button() -> Button:
	return _stop
