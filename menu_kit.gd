class_name MenuKit
extends RefCounted
## Общие детали экранов до мира (вход LoginScreen, выбор персонажа CharacterSelect, создание CharacterCreate):
## фон с полосой (или арт на весь экран), корневой MarginContainer с темой Util.ui_theme(), подписи, кнопки, рамки
## карточек, арты Dark Pact (логотип, главный арт, арты рас и профессий, портреты — раздел «Арты»), карточки
## профессий с артом во весь рост и подробности профессии (раздел «Карточки профессий» — создание и окно мудреца).
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


# ---------- Карточки профессий ----------

## Соотношение сторон артов профессий (ширина / высота; файлы 800×1066, персонаж во весь рост).
const JOB_ART_RATIO := 0.75
## Наименьший размер арта в карточке («Средний»); обычно карточка больше — по свободному месту.
const JOB_ART_MIN := Vector2(168, 224)
## Высота кнопок на карточке профессии («Средний»).
const JOB_BUTTON_H := 38.0


## Вертикальная карточка профессии (шаг «Профессии» создания персонажа, окно мудреца JobWindow), рамка цвета border
## (selected — золотая). С артом (часть «art»): арт целиком — весь рост, без обрезки (TextureRect KEEP_ASPECT_CENTERED
## в AspectRatioContainer 3:4: карточка занимает свободное место по высоте и держит соотношение сторон); поверх
## нижней части на затемнении — имя крупно (ArtTitle), роль и оружие одной строкой с многоточием (ArtRole,
## ArtWeapon), ряд кнопок «JobActions» (кнопки добавляет вызывающий — MenuKit.card_button). Без арта — те же строки
## текстом и описание. Возвращает {"slot": Control (в ряд карточек; растягивается), "card": PanelContainer
## (касание — gui_input), "actions": HBoxContainer}. Подробности — MenuKit.job_details.
static func job_card(job: String, border: Color, selected: bool, title_col: Color) -> Dictionary:
	var c := ClassData.cls(job)
	var tex := art(job_art_path(job))
	var card := PanelContainer.new()
	card.name = "JobCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := card_style(border, selected)
	var actions := HBoxContainer.new()
	actions.name = "JobActions"
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", int(UiScale.px(6)))
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex == null:
		card.add_theme_stylebox_override("panel", sb)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", int(UiScale.px(5)))
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(v)
		v.add_child(label(String(c["name"]), UiScale.FONT_NAME, title_col))
		v.add_child(label(String(c["role"]), UiScale.FONT_BODY, MUTED, true))
		v.add_child(label("Оружие: " + String(c["weapon_text"]), UiScale.FONT_SMALL, TEXT, true))
		v.add_child(label(String(c.get("desc", "")), UiScale.FONT_SMALL, TEXT, true))
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(spacer)
		v.add_child(actions)
		return {"slot": card, "card": card, "actions": actions}
	# Арт почти вплотную к рамке
	sb.set_content_margin_all(float(sb.border_width_left))
	sb.set_corner_radius_all(int(UiScale.px(4)))
	sb.bg_color = Color(0.03, 0.04, 0.07, 1.0)
	card.add_theme_stylebox_override("panel", sb)
	var slot := AspectRatioContainer.new()
	slot.name = "JobSlot"
	slot.ratio = JOB_ART_RATIO
	slot.stretch_mode = AspectRatioContainer.STRETCH_FIT
	slot.alignment_horizontal = AspectRatioContainer.ALIGNMENT_CENTER
	slot.alignment_vertical = AspectRatioContainer.ALIGNMENT_CENTER
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(card)
	var head := Control.new()
	head.name = "JobArt"
	head.custom_minimum_size = UiScale.v2(JOB_ART_MIN.x, JOB_ART_MIN.y)
	head.clip_contents = true
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(head)
	var pic := TextureRect.new()
	pic.name = "Art"
	pic.texture = tex
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	head.add_child(pic)
	# Затемнение снизу — под имя, роль и кнопки (низ арта и так темнее)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.5), Color(0, 0, 0, 0.9)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 4
	gt.height = 64
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var sh := TextureRect.new()
	sh.name = "ArtShade"
	sh.texture = gt
	sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sh.stretch_mode = TextureRect.STRETCH_SCALE
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sh.anchor_left = 0.0
	sh.anchor_right = 1.0
	sh.anchor_top = 0.55
	sh.anchor_bottom = 1.0
	head.add_child(sh)
	# Имя, роль, оружие и кнопки — прижаты к низу, растут вверх
	var info := VBoxContainer.new()
	info.name = "ArtInfo"
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override("separation", int(UiScale.px(2)))
	var pad := UiScale.px(8)
	info.anchor_left = 0.0
	info.anchor_right = 1.0
	info.anchor_top = 1.0
	info.anchor_bottom = 1.0
	info.offset_left = pad
	info.offset_right = -pad
	info.offset_top = -pad
	info.offset_bottom = -pad
	info.grow_vertical = Control.GROW_DIRECTION_BEGIN
	head.add_child(info)
	var t := _art_line(String(c["name"]), UiScale.FONT_NAME + 4, title_col)
	t.name = "ArtTitle"
	info.add_child(t)
	var role := _art_line(String(c["role"]), UiScale.FONT_SMALL, Color(0.86, 0.88, 0.95))
	role.name = "ArtRole"
	info.add_child(role)
	var weapon := _art_line("Оружие: " + String(c["weapon_text"]), UiScale.FONT_SMALL, GOLD.lerp(TEXT, 0.4))
	weapon.name = "ArtWeapon"
	info.add_child(weapon)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, UiScale.px(4))
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(gap)
	info.add_child(actions)
	return {"slot": slot, "card": card, "actions": actions}


## Строка поверх арта: по центру, с обводкой, не влезла — многоточие (без clip_text: ширину карточки не держит).
static func _art_line(text: String, font_size: int, col: Color) -> Label:
	var l := label(text, font_size, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", maxi(2, int(UiScale.px(4))))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Кнопка на карточке профессии («Подробнее», «Выбрать»): компактная, делит ряд поровну.
static func card_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, UiScale.px(JOB_BUTTON_H))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", UiScale.fs(UiScale.FONT_TEXT))
	return b


## Подробности профессии (вместо ряда карточек): слева карточка с артом целиком (если есть), справа на затемнении
## с прокруткой — имя, роль, оружие, описание, сильные стороны, особенности, ключевые умения (значок, требуемый
## уровень); снизу ряд кнопок, первая — «Назад» (подключает вызывающий). Возвращает {"view": HBoxContainer,
## "actions": HBoxContainer, "back": Button, "card": PanelContainer или null — без арта}.
static func job_details(job: String, border: Color, title_col: Color) -> Dictionary:
	var c := ClassData.cls(job)
	var view := HBoxContainer.new()
	view.name = "JobDetails"
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.add_theme_constant_override("separation", int(UiScale.px(12)))
	var card: PanelContainer = null
	if art(job_art_path(job)) != null:
		var cd := job_card(job, border, true, title_col)
		(cd["actions"] as Control).visible = false
		var slot := cd["slot"] as Control
		slot.size_flags_stretch_ratio = 1.0
		view.add_child(slot)
		card = cd["card"] as PanelContainer
	var panel := PanelContainer.new()
	panel.name = "JobInfo"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 2.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.1, 0.88)
	sb.border_color = border
	sb.set_border_width_all(int(UiScale.px(2)))
	sb.set_corner_radius_all(int(UiScale.px(UiScale.BTN_RADIUS)))
	sb.set_content_margin_all(UiScale.px(12))
	panel.add_theme_stylebox_override("panel", sb)
	view.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(UiScale.px(8)))
	panel.add_child(col)
	var scroll := ScrollContainer.new()
	scroll.name = "JobText"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", int(UiScale.px(5)))
	scroll.add_child(text)
	text.add_child(label(String(c["name"]), UiScale.FONT_TITLE + 2, title_col))
	text.add_child(label("Роль: " + String(c["role"]), UiScale.FONT_TEXT, MUTED, true))
	text.add_child(label("Оружие: " + String(c["weapon_text"]), UiScale.FONT_BODY, TEXT, true))
	text.add_child(label(String(c.get("desc", "")), UiScale.FONT_BODY, TEXT, true))
	text.add_child(label("Сильные стороны", UiScale.FONT_TEXT, GOOD))
	text.add_child(bullets(c.get("strengths", []), UiScale.FONT_BODY, TEXT))
	text.add_child(label("Особенности", UiScale.FONT_TEXT, Color(1.0, 0.75, 0.45)))
	text.add_child(bullets(c.get("features", []), UiScale.FONT_BODY, TEXT))
	text.add_child(label("Ключевые умения", UiScale.FONT_TEXT, GOLD))
	for sid in c.get("key_skills", []):
		var id := String(sid)
		var sk := HeroSkills.get_skill(id, job)
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", int(UiScale.px(6)))
		var ic := IconView.new()
		ic.custom_minimum_size = UiScale.v2(28, 28)
		ic.set_spec(IconView.hero_skill(id))
		r.add_child(ic)
		var sl := label("%s (ур. %d)" % [String(sk.get("name", id)), HeroSkills.level_needed(id, 1, job)],
			UiScale.FONT_BODY, Color(0.9, 0.9, 0.95), true)
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(sl)
		text.add_child(r)
	var actions := HBoxContainer.new()
	actions.name = "JobActions"
	actions.add_theme_constant_override("separation", int(UiScale.px(12)))
	col.add_child(actions)
	var back := button("Назад")
	back.name = "JobBack"
	actions.add_child(back)
	return {"view": view, "actions": actions, "back": back, "card": card}


# ---------- Портреты ----------

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
