class_name MenuKit
extends RefCounted
## Общие детали экранов до мира (вход LoginScreen, выбор персонажа CharacterSelect, создание CharacterCreate):
## фон с полосой (или арт на весь экран), корневой MarginContainer с темой Util.ui_theme(), подписи, кнопки, рамки
## карточек, арты Dark Pact (логотип, главный арт, арты рас и профессий, портреты — раздел «Арты»).
## Размеры — для «Среднего» размера интерфейса, переводятся через UiScale. Экраны — CanvasLayer слоя LAYER
## (поверх HUD); test_ui_scale проверяет, что корневой MarginContainer помещается в 1280×720.

const LAYER := 10
const GOLD := Color(0.95, 0.8, 0.4)
const MUTED := Color(0.7, 0.72, 0.78)
const TEXT := Color(0.9, 0.9, 0.92)
const GOOD := Color(0.55, 1.0, 0.6)
const BAD := Color(1.0, 0.5, 0.45)
const CARD_BG := Color(0.12, 0.14, 0.26, 0.95)
## Фон экрана без арта.
const BG := Color(0.05, 0.07, 0.1)

## Арты Dark Pact (tools/prepare_branding.py). В APK (их видно до загрузки пакета ресурсов): логотип и главный арт.
const LOGO := "res://assets/art/logo_dark_pact.png"
const KEY_ART := "res://assets/art/key_art.jpg"
## В пакете ресурсов, часть «art» (Assets.PACKS): race_<раса>.jpg, job_<профессия>.jpg, portraits/<…>.png.
const PACK_ART := "res://assets/art/pack/"
## Затемнение главного арта под элементами экрана (0…1).
const KEY_SHADE := 0.45


## Фон экрана и корневой отступ; возвращает VBoxContainer для содержимого. art_path — арт на весь экран (нет
## файла — прежний тёмный фон с полосой), shade — его затемнение.
static func build_root(layer: CanvasLayer, art_path: String = "", shade: float = KEY_SHADE) -> VBoxContainer:
	layer.layer = LAYER
	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var band := ColorRect.new()
	band.name = "Band"
	band.color = Color(0.1, 0.12, 0.17)
	band.set_anchors_preset(Control.PRESET_TOP_WIDE)
	band.custom_minimum_size = Vector2(0, UiScale.px(64))
	layer.add_child(band)
	set_backdrop(layer, art(art_path), shade)
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


# ---------- Арты ----------

## Картинка арта (Texture2D) или null: нет файла или его часть пакета ресурсов не загружена (Assets.exists).
static func art(path: String) -> Texture2D:
	if path == "" or not Assets.exists(path):
		return null
	return load(path) as Texture2D


## Арт расы (шаг «Раса» создания персонажа): мужчина и женщина справа, левая треть спокойнее — под текст.
static func race_art_path(race_id: String) -> String:
	return PACK_ART + "race_%s.jpg" % race_id


## Арт профессии (вертикальная карточка): создание персонажа, окно выбора профессии у мудреца.
static func job_art_path(job: String) -> String:
	return PACK_ART + "job_%s.jpg" % job


## Портрет карточки персонажа: по профессии и полу, у Бродяги — по расе и полу.
static func portrait_path(job: String, race_id: String, gender: String) -> String:
	var g := "m" if gender == "m" else "f"
	if job == "" or job == ClassData.WANDERER:
		return PACK_ART + "portraits/wanderer_%s_%s.png" % [race_id, g]
	return PACK_ART + "portraits/%s_%s.png" % [job, g]


## Фон экрана — арт tex на весь экран (обрезка по краям) и затемнение: shade везде, плюс left слева (под текстом,
## к середине экрана сходит на нет). Узлы «Backdrop» и «Shade» — сразу над тёмным фоном, под содержимым; полоса
## «Band» видна только без арта. tex = null — арт убирается (прежний фон).
static func set_backdrop(layer: CanvasLayer, tex: Texture2D, shade: float = KEY_SHADE, left: float = 0.0) -> void:
	var back := layer.get_node_or_null("Backdrop") as TextureRect
	var sh := layer.get_node_or_null("Shade") as TextureRect
	var band := layer.get_node_or_null("Band") as Control
	if band != null:
		band.visible = tex == null
	if tex == null:
		if back != null:
			back.queue_free()
			back.name = "Backdrop_old"
		if sh != null:
			sh.queue_free()
			sh.name = "Shade_old"
		return
	if back == null:
		back = TextureRect.new()
		back.name = "Backdrop"
		back.set_anchors_preset(Control.PRESET_FULL_RECT)
		back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(back)
		layer.move_child(back, 1)
	back.texture = tex
	if sh == null:
		sh = TextureRect.new()
		sh.name = "Shade"
		sh.set_anchors_preset(Control.PRESET_FULL_RECT)
		sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sh.stretch_mode = TextureRect.STRETCH_SCALE
		sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(sh)
		layer.move_child(sh, back.get_index() + 1)
	var g := Gradient.new()
	var a0 := clampf(shade + left, 0.0, 1.0)
	var a1 := clampf(shade, 0.0, 1.0)
	g.offsets = PackedFloat32Array([0.0, 0.38, 0.62, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, a0), Color(0, 0, 0, a0), Color(0, 0, 0, a1), Color(0, 0, 0, a1)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 64
	gt.height = 4
	sh.texture = gt


## Логотип Dark Pact высотой height (для «Среднего»), по центру; null — нет файла.
static func logo(height: float) -> TextureRect:
	var tex := art(LOGO)
	if tex == null:
		return null
	var r := TextureRect.new()
	r.name = "Logo"
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var ts := tex.get_size()
	var h := UiScale.px(height)
	r.custom_minimum_size = Vector2(roundf(h * ts.x / maxf(ts.y, 1.0)), h)
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Арт tex в рамке size (база «Среднего», наименьший размер; ширина может вырасти по контейнеру): окно картинки
## с соотношением сторон aspect (0 — как у size; ожидаемая ширина рамки / высота) — по ширине целиком, по высоте —
## от доли focus_y (0 — верх: лица на артах профессий вверху). Уменьшенный — с мипмапами.
static func art_rect(tex: Texture2D, size: Vector2, focus_y: float = 0.0, aspect: float = 0.0) -> TextureRect:
	var box := UiScale.v2(size.x, size.y)
	var ts := tex.get_size()
	var want := aspect if aspect > 0.0 else box.x / maxf(box.y, 1.0)
	var region := Rect2(Vector2.ZERO, ts)
	if ts.x / maxf(ts.y, 1.0) > want:
		var w := ts.y * want
		region = Rect2((ts.x - w) * 0.5, 0.0, w, ts.y)
	else:
		var h := ts.x / want
		region = Rect2(0.0, (ts.y - h) * clampf(focus_y, 0.0, 1.0), ts.x, h)
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = region
	var r := TextureRect.new()
	r.name = "Art"
	r.texture = at
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	r.custom_minimum_size = box
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Шапка вертикальной карточки профессии: арт профессии (окно сверху), внизу на затемнении — название цвета col.
## size — наименьший размер («Средний»), aspect — ожидаемое соотношение сторон по ширине карточки (0 — как у size).
## null — арта нет (часть «art» не загружена).
static func job_art_head(job: String, size: Vector2, title_text: String, col: Color, aspect: float = 0.0) -> Control:
	var tex := art(job_art_path(job))
	if tex == null:
		return null
	var head := Control.new()
	head.name = "JobArt"
	head.custom_minimum_size = UiScale.v2(size.x, size.y)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.clip_contents = true
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := art_rect(tex, size, 0.06, aspect)
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	head.add_child(pic)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0.85)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 4
	gt.height = 64
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var sh := TextureRect.new()
	sh.texture = gt
	sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sh.stretch_mode = TextureRect.STRETCH_SCALE
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sh.anchor_left = 0.0
	sh.anchor_right = 1.0
	sh.anchor_top = 0.6
	sh.anchor_bottom = 1.0
	head.add_child(sh)
	var t := label(title_text, UiScale.FONT_NAME + 2, col)
	t.name = "ArtTitle"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	t.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	t.add_theme_constant_override("outline_size", maxi(2, int(UiScale.px(4))))
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.anchor_left = 0.0
	t.anchor_right = 1.0
	t.anchor_top = 0.0
	t.anchor_bottom = 1.0
	t.offset_bottom = -UiScale.px(6)
	head.add_child(t)
	return head


## Портрет персонажа (квадрат side для «Среднего», скруглённые углы — в самой картинке); null — нет файла.
static func portrait(job: String, race_id: String, gender: String, side: float) -> TextureRect:
	var tex := art(portrait_path(job, race_id, gender))
	if tex == null:
		return null
	var r := TextureRect.new()
	r.name = "Portrait"
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	r.custom_minimum_size = UiScale.v2(side, side)
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
