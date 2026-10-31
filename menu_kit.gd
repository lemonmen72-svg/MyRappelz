class_name MenuKit
extends RefCounted
## Общие детали экранов до мира (вход LoginScreen, выбор персонажа CharacterSelect, создание CharacterCreate):
## фон с полосой, корневой MarginContainer с темой Util.ui_theme(), подписи, кнопки, рамки карточек.
## Размеры — для «Среднего» размера интерфейса, переводятся через UiScale. Экраны — CanvasLayer слоя LAYER
## (поверх HUD); test_ui_scale проверяет, что корневой MarginContainer помещается в 1280×720.

const LAYER := 10
const GOLD := Color(0.95, 0.8, 0.4)
const MUTED := Color(0.7, 0.72, 0.78)
const TEXT := Color(0.9, 0.9, 0.92)
const GOOD := Color(0.55, 1.0, 0.6)
const BAD := Color(1.0, 0.5, 0.45)
const CARD_BG := Color(0.12, 0.14, 0.26, 0.95)


## Фон экрана и корневой отступ; возвращает VBoxContainer для содержимого.
static func build_root(layer: CanvasLayer) -> VBoxContainer:
	layer.layer = LAYER
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var band := ColorRect.new()
	band.color = Color(0.1, 0.12, 0.17)
	band.set_anchors_preset(Control.PRESET_TOP_WIDE)
	band.custom_minimum_size = Vector2(0, UiScale.px(64))
	layer.add_child(band)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.theme = Util.ui_theme()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + String(side), int(UiScale.px(16)))
	layer.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", int(UiScale.px(10)))
	margin.add_child(root)
	return root


## Корневой MarginContainer экрана (для проверки размеров в тестах).
static func margin_of(layer: Node) -> MarginContainer:
	for c in layer.get_children():
		if c is MarginContainer:
			return c as MarginContainer
	return null


## Подпись; font_size — для «Среднего» размера (UiScale.FONT_*); wrap — с переносом по словам.
static func label(text: String, font_size: int, col: Color, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", UiScale.fs(font_size))
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func title(text: String) -> Label:
	var t := label(text, UiScale.FONT_TITLE + 4, GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return t


## Обычная кнопка; height — для «Среднего» размера.
static func button(text: String, height: float = 44.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(UiScale.px(150), UiScale.px(height))
	b.add_theme_font_size_override("font_size", UiScale.fs(UiScale.FONT_TEXT + 1))
	return b


## Главная (зелёная) кнопка действия: «Войти», «Играть», «Далее».
static func main_button(text: String) -> Button:
	var b := button(text, UiScale.BUTTON_H + 4)
	b.add_theme_font_size_override("font_size", UiScale.fs(UiScale.FONT_NAME))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.2, 0.5, 0.25)
		if state == "hover":
			sb.bg_color = Color(0.24, 0.56, 0.3)
		elif state == "pressed":
			sb.bg_color = Color(0.3, 0.65, 0.3)
		elif state == "disabled":
			sb.bg_color = Color(0.25, 0.28, 0.3)
		sb.border_color = GOLD if state != "disabled" else MUTED
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(int(UiScale.px(UiScale.BTN_RADIUS)))
		sb.set_content_margin_all(UiScale.px(8))
		b.add_theme_stylebox_override(state, sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(String(c), Color(1, 0.98, 0.9))
	return b


## Поле ввода высотой с кнопку.
static func line_edit(placeholder: String, text: String = "") -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.text = text
	e.max_length = Accounts.NAME_MAX
	e.custom_minimum_size = Vector2(UiScale.px(260), UiScale.button_h())
	e.add_theme_font_size_override("font_size", UiScale.fs(UiScale.FONT_HEAD + 1))
	return e


## Рамка карточки: выбранная — золотая и толще, иначе цвета col.
static func card_style(col: Color, selected: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD_BG if not selected else Color(0.16, 0.18, 0.32, 0.98)
	sb.border_color = GOLD if selected else col
	sb.set_border_width_all(int(UiScale.px(4 if selected else 2)))
	sb.set_corner_radius_all(int(UiScale.px(UiScale.BTN_RADIUS)))
	sb.set_content_margin_all(UiScale.px(10))
	return sb


## Список пунктов «• …» одной подписью.
static func bullets(items: Array, font_size: int, col: Color) -> Label:
	var lines: PackedStringArray = []
	for it in items:
		lines.append("• " + String(it))
	return label("\n".join(lines), font_size, col, true)


## Названия ключевых умений профессии (ClassData key_skills) через запятую.
static func key_skill_names(job: String) -> String:
	var names: PackedStringArray = []
	for sid in ClassData.cls(job).get("key_skills", []):
		names.append(String(HeroSkills.get_skill(String(sid), job).get("name", sid)))
	return ", ".join(names)
