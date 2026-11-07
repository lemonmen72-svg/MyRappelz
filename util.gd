class_name Util
extends RefCounted


## Игровые часы, с: сумма delta физики главной сцены (main._physics_process — уже со шкалой Engine.time_scale:
## в Godot 4 ускорение увеличивает шаг тика, а не число тиков; пауза дерева — стоят). Для правил игры (тела зверей,
## порядок гибели питомцев) вместо Time.get_ticks_msec — Кардинал ускоряет игру, и правила идут вместе с ней.
static var clock := 0.0


static func game_time() -> float:
	return clock
## Общие вспомогательные функции.

static var _theme: Theme


## Общая тема окон и кнопок. Размеры (шрифт, поля, скругления) — из UiScale, после смены размера
## интерфейса их обновляет refresh_theme() в том же объекте темы (открытые окна и кнопки меню меняются сразу).
static func ui_theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	# Аниме-фэнтези: полупрозрачный тёмно-синий фон, светлая золотистая окантовка, мягкая тень
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.1, 0.12, 0.24, 0.9)
	panel.border_color = Color(0.98, 0.88, 0.6)
	panel.shadow_color = Color(0, 0, 0, 0.35)
	_theme.set_stylebox("panel", "PanelContainer", panel)
	_theme.set_stylebox("panel", "Panel", panel)
	_theme.set_color("font_color", "Label", Color(0.98, 0.96, 0.9))
	# Кнопки (0.41, просьба Максима «свой дизайн»): тёмно-синий лак, золотая рамка, светлый текст; главные
	# (BtnPrimary — «Надеть», «Купить», «Крафт») — золотые, опасные (BtnDanger — «Выбросить», «Отказаться») — алые.
	# Есть картинки рамок assets/icons/ui_skin/<btn_skin_*>.png — кнопки из них (9-slice), иначе рисованные.
	_button_styles("Button", "btn_skin", BTN_NAVY)
	_button_styles("BtnPrimary", "btn_skin_primary", BTN_GOLD)
	_button_styles("BtnDanger", "btn_skin_danger", BTN_RED)
	_theme.set_type_variation("BtnPrimary", "Button")
	_theme.set_type_variation("BtnDanger", "Button")
	# Узкие кнопки: у рамки-картинки торцы со звёздами по 32 px — в кнопку уже SKIN_MIN_W они не помещаются
	# (сжимаются и закрывают надпись). Ячейки «На кнопку» в окне героя — прежний вид до 0.41 (просьба Максима):
	# светлая кнопка с золотой рамкой, назначенная — золотая (BtnSlot); прочие узкие — рисованные (BtnSmall).
	_slot_styles()
	_button_styles("BtnSmall", "", BTN_NAVY)
	_theme.set_type_variation("BtnSlot", "Button")
	_theme.set_type_variation("BtnSmall", "Button")
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_hover_pressed_color"]:
		_theme.set_color(c, "Button", Color(0.97, 0.94, 0.84))
		_theme.set_color(c, "BtnDanger", Color(1.0, 0.95, 0.9))
		_theme.set_color(c, "BtnPrimary", Color(0.24, 0.13, 0.02))
	_theme.set_color("font_pressed_color", "Button", Color(1.0, 0.84, 0.42))
	_theme.set_color("font_pressed_color", "BtnPrimary", Color(0.2, 0.1, 0.0))
	_theme.set_color("font_pressed_color", "BtnDanger", Color(1.0, 0.9, 0.8))
	_theme.set_color("font_pressed_color", "BtnSmall", Color(1.0, 0.84, 0.42))
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_hover_pressed_color"]:
		_theme.set_color(c, "BtnSmall", Color(0.97, 0.94, 0.84))
	for t in ["Button", "BtnPrimary", "BtnDanger", "BtnSmall"]:
		_theme.set_color("font_disabled_color", t, Color(0.6, 0.62, 0.7))
		_theme.set_color("icon_normal_color", t, Color.WHITE)
		_theme.set_color("icon_disabled_color", t, Color(1, 1, 1, 0.45))
	refresh_theme()
	return _theme


## Рамке-картинке нужна кнопка не уже этого (px «Среднего»): торцы 2 × 32 px + место под надпись.
const SKIN_MIN_W := 84.0


## Прежний вид кнопок (до 0.41) — ячейки «На кнопку» окна героя: светлая, золотая рамка, тёмный текст;
## нажатая (назначенная) — золотая.
static func _slot_styles() -> void:
	var colors := {
		"normal": Color(0.95, 0.93, 0.86), "hover": Color(1.0, 0.98, 0.92),
		"pressed": Color(1.0, 0.82, 0.45), "disabled": Color(0.45, 0.46, 0.52),
	}
	for state in colors:
		var sb := StyleBoxFlat.new()
		sb.bg_color = colors[state]
		sb.border_color = Color(0.85, 0.68, 0.32)
		sb.set_border_width_all(2)
		sb.anti_aliasing = true
		_theme.set_stylebox(state, "BtnSlot", sb)
	_theme.set_stylebox("focus", "BtnSlot", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_hover_pressed_color"]:
		_theme.set_color(c, "BtnSlot", Color(0.18, 0.16, 0.28))
	_theme.set_color("font_pressed_color", "BtnSlot", Color(0.3, 0.18, 0.05))
	_theme.set_color("font_disabled_color", "BtnSlot", Color(0.8, 0.8, 0.85))


## Квадратная рамка кнопки-значка (вкладки, меню, «Закрыть»): картинка tab_skin_on / tab_skin_off или рисованная.
static func square_skin(on: bool) -> StyleBox:
	var path := SKIN_DIR + ("tab_skin_on" if on else "tab_skin_off") + ".png"
	if Assets.exists(path):
		var tx := StyleBoxTexture.new()
		tx.texture = load(path)
		var w := tx.texture.get_width()
		for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			tx.set_texture_margin(side, w * 0.22)
			tx.set_content_margin(side, w * 0.08)
		return tx
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.22, 0.42) if on else Color(0.12, 0.14, 0.3)
	sb.border_color = Color(1.0, 0.85, 0.4) if on else Color(0.72, 0.58, 0.28)
	sb.set_border_width_all(3 if on else 2)
	sb.set_corner_radius_all(8)
	sb.anti_aliasing = true
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		sb.set_content_margin(side, 4)
	return sb


## Рамки кнопок заново (подключилась часть icons пакета ресурсов — картинки btn_skin_* появились).
static func refresh_skins() -> void:
	if _theme == null:
		return
	_button_styles("Button", "btn_skin", BTN_NAVY)
	_button_styles("BtnPrimary", "btn_skin_primary", BTN_GOLD)
	_button_styles("BtnDanger", "btn_skin_danger", BTN_RED)
	refresh_theme()


## Цвета рисованных кнопок: фон, рамка, нижняя кромка (объём).
const BTN_NAVY := {"bg": Color(0.13, 0.16, 0.34), "border": Color(0.86, 0.68, 0.3), "edge": Color(0.05, 0.06, 0.15)}
const BTN_GOLD := {"bg": Color(0.98, 0.76, 0.32), "border": Color(1.0, 0.93, 0.66), "edge": Color(0.55, 0.33, 0.08)}
const BTN_RED := {"bg": Color(0.62, 0.13, 0.16), "border": Color(0.95, 0.66, 0.36), "edge": Color(0.25, 0.03, 0.05)}
const SKIN_DIR := "res://assets/icons/ui_skin/"


## Стили кнопок типа t: из картинок skin_<состояние> (если есть файл) или рисованные по цветам pal.
## skin "" — только рисованные (узкие кнопки BtnSmall).
static func _button_styles(t: String, skin: String, pal: Dictionary) -> void:
	var states := {"normal": skin if skin != "btn_skin" else "btn_skin_normal", "hover": "",
		"pressed": "btn_skin_pressed" if t == "Button" else "", "disabled": "btn_skin_disabled", "focus": ""}
	if skin == "":
		states = {"normal": "", "hover": "", "pressed": "", "disabled": "", "focus": ""}
	for st in states:
		if st == "focus":
			var f := StyleBoxEmpty.new()
			_theme.set_stylebox("focus", t, f)
			continue
		var file := String(states[st])
		if file == "" and st == "hover":
			file = String(states["normal"])
		var path := SKIN_DIR + file + ".png"
		if file != "" and Assets.exists(path):
			var tx := StyleBoxTexture.new()
			tx.texture = load(path)
			var w := tx.texture.get_width()
			var h := tx.texture.get_height()
			tx.texture_margin_left = w * 0.1
			tx.texture_margin_right = w * 0.1
			tx.texture_margin_top = h * 0.22
			tx.texture_margin_bottom = h * 0.22
			tx.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
			if st == "hover":
				tx.modulate_color = Color(1.12, 1.12, 1.12)
			_theme.set_stylebox(st, t, tx)
			continue
		var sb := StyleBoxFlat.new()
		var bg: Color = pal["bg"]
		match st:
			"hover":
				bg = bg.lightened(0.1)
			"pressed":
				bg = bg.darkened(0.25)
			"disabled":
				bg = Color(0.22, 0.24, 0.32)
		sb.bg_color = bg
		sb.border_color = Color(0.45, 0.47, 0.55) if st == "disabled" else (pal["border"] as Color).lightened(
			0.2 if st == "pressed" else 0.0)
		sb.set_border_width_all(2)
		sb.border_width_bottom = 2 if st == "pressed" else 4
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 0 if st == "pressed" else 2
		sb.shadow_offset = Vector2(0, 2)
		sb.anti_aliasing = true
		sb.set_meta("edge", pal["edge"])
		_theme.set_stylebox(st, t, sb)


## Размеры темы по текущему UiScale (шрифт по умолчанию, поля и скругления окон и кнопок).
static func refresh_theme() -> void:
	if _theme == null:
		return
	_theme.default_font_size = UiScale.fs(UiScale.FONT)
	var panel := _theme.get_stylebox("panel", "PanelContainer") as StyleBoxFlat
	if panel != null:
		panel.set_border_width_all(maxi(2, roundi(UiScale.px(2.5))))
		panel.set_corner_radius_all(int(UiScale.px(UiScale.RADIUS)))
		panel.set_content_margin_all(UiScale.px(UiScale.PAD))
		panel.shadow_size = int(UiScale.px(6))
	for t in ["Button", "BtnPrimary", "BtnDanger", "BtnSlot", "BtnSmall"]:
		for state in ["normal", "hover", "pressed", "disabled"]:
			var sb := _theme.get_stylebox(state, t)
			if sb == null:
				continue
			if sb is StyleBoxFlat:
				(sb as StyleBoxFlat).set_corner_radius_all(int(UiScale.px(UiScale.BTN_RADIUS)))
			sb.content_margin_left = UiScale.px(UiScale.BTN_PAD_X)
			sb.content_margin_right = UiScale.px(UiScale.BTN_PAD_X)
			sb.content_margin_top = UiScale.px(UiScale.BTN_PAD_Y)
			sb.content_margin_bottom = UiScale.px(UiScale.BTN_PAD_Y)


## Материал в аниме-стиле (cel-shading): ступенчатый свет и блик, подсветка краёв (rim).
## Контур добавляется автоматически (см. toonify), если меш не помечен meta "no_outline".
static func mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	toon(m)
	return m


## Настраивает StandardMaterial3D под cel-shading. Не трогает неосвещаемые и прозрачные.
static func toon(m: StandardMaterial3D) -> void:
	if m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.roughness = 0.55
	m.metallic_specular = 0.25
	m.rim_enabled = true
	m.rim = 0.3
	m.rim_tint = 0.7


static var _outline_shader: Shader
static var _outlines := {}


## Материал контура для базового цвета: тёмный оттенок того же цвета (как в аниме), с кэшем.
static func outline_mat(base: Color, width: float = 0.02) -> ShaderMaterial:
	var key := "%s|%.3f" % [base.to_html(false), width]
	if _outlines.has(key):
		return _outlines[key]
	if _outline_shader == null:
		_outline_shader = load("res://outline.gdshader")
	var om := ShaderMaterial.new()
	om.shader = _outline_shader
	var c := Color.from_hsv(base.h, minf(1.0, base.s * 1.2 + 0.1), base.v * 0.28)
	om.set_shader_parameter("color", c)
	om.set_shader_parameter("width", width)
	_outlines[key] = om
	return om


## Стилизует меш: toon-освещение и контур. Повторный вызов безопасен.
## meta "no_toon" — не трогать; meta "no_outline" — без контура (земля, трава, эффекты).
static func toonify_mesh(mi: MeshInstance3D) -> void:
	if not is_instance_valid(mi) or mi.has_meta("no_toon"):
		return
	var m := mi.material_override as StandardMaterial3D
	if m == null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
		m = mi.get_active_material(0) as StandardMaterial3D
	if m == null or m.has_meta("toon_done"):
		return
	m.set_meta("toon_done", true)
	toon(m)
	var solid := m.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED \
		and m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
	if solid and not mi.has_meta("no_outline") and m.next_pass == null:
		# Контур по настройке «Контуры» (меняется сразу — Quality.apply)
		Quality.track_outline(m, outline_mat(m.albedo_color))


## Стилизует все меши в поддереве.
static func toonify(root: Node) -> void:
	if root is MeshInstance3D:
		toonify_mesh(root)
	for n in root.find_children("*", "MeshInstance3D", true, false):
		toonify_mesh(n)


## Ближайший живой узел из группы в пределах max_dist.
static func nearest(from: Node3D, group: String, max_dist: float) -> Node3D:
	var best: Node3D = null
	var best_d := max_dist
	for n in from.get_tree().get_nodes_in_group(group):
		var node := n as Node3D
		if node == null:
			continue
		if node.get("is_dead") == true:
			continue
		var d := from.global_position.distance_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best


## Простое тело зверя из коробок (заглушка вместо модели). Возвращает материал.
static func creature_body(parent: Node3D, color: Color, s: float) -> StandardMaterial3D:
	var m := mat(color)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.9, 0.7, 1.4) * s
	body.mesh = bm
	body.position = Vector3(0, 0.75 * s, 0)
	body.material_override = m
	parent.add_child(body)

	var head := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.6, 0.55, 0.6) * s
	head.mesh = hm
	head.position = Vector3(0, 0.95 * s, -0.85 * s)
	head.material_override = m
	parent.add_child(head)

	for x in [-0.3, 0.3]:
		for z in [-0.45, 0.45]:
			var leg := MeshInstance3D.new()
			var lm := BoxMesh.new()
			lm.size = Vector3(0.18, 0.4, 0.18) * s
			leg.mesh = lm
			leg.position = Vector3(x * s, 0.2 * s, z * s)
			leg.material_override = m
			parent.add_child(leg)

	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.9, 1.2, 1.5) * s
	col.shape = sh
	col.position = Vector3(0, 0.6 * s, 0)
	parent.add_child(col)
	return m


static var _float_font: FontVariation


## Всплывающий текст в аниме-стиле (урон, опыт, названия умений): жирный шрифт, цветная тёмная
## обводка, «выпрыгивает» с увеличением и улетает вверх, тая. Числа (урон, лечение) крупнее
## и чуть разбросаны в стороны, чтобы не слипались. size: множитель размера (крит — 1.4–1.6).
## Общий размер — UiScale.world_px (настройка «Размер интерфейса»).
static func float_text(parent: Node, pos: Vector3, text: String, color: Color, size: float = 1.0) -> void:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	if _float_font == null:
		_float_font = FontVariation.new()
		_float_font.base_font = ThemeDB.fallback_font
		_float_font.variation_embolden = 0.9
	var numeric := text.is_valid_int()
	var big := size > 1.2
	var l := Label3D.new()
	l.text = text
	l.font = _float_font
	l.font_size = 60 if numeric else 46
	l.outline_size = 18 if big else 14
	# Заливка — светлый вариант цвета, обводка — тёмный насыщенный оттенок того же цвета
	l.modulate = color.lerp(Color.WHITE, 0.15)
	if color.s < 0.15:
		l.outline_modulate = Color(0.16, 0.12, 0.28)
	else:
		l.outline_modulate = Color.from_hsv(color.h, minf(1.0, color.s * 0.9 + 0.35), color.v * 0.32)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 2
	l.outline_render_priority = 1
	# Размер на экране — прежний × UiScale.WORLD × множитель размера интерфейса (компактно для телефона)
	var px := UiScale.world_px(0.012) * size
	l.pixel_size = px * 0.3
	parent.add_child(l)
	var start := pos
	if numeric:
		start += Vector3(randf_range(-0.35, 0.35), randf_range(-0.1, 0.15), 0.0)
	l.global_position = start
	# «Выпрыгивание»: резкое увеличение с перелётом, потом к обычному размеру
	var pop := l.create_tween()
	pop.tween_property(l, "pixel_size", px * (1.5 if big else 1.3), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(l, "pixel_size", px, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Подъём с замедлением и таяние
	var t := l.create_tween()
	t.set_parallel(true)
	t.tween_property(l, "global_position:y", start.y + (1.1 if numeric else 1.4), 0.95).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.6)
	t.tween_property(l, "outline_modulate:a", 0.0, 0.35).set_delay(0.6)
	t.chain().tween_callback(l.queue_free)


## Коллизия-«столб» круглого предмета (ствол, камень, колодец, башня, житель) радиуса r и высоты h от основания:
## капсула вместо CylinderShape3D — у цилиндра в физике Godot 4.3 известные ошибки контактов (документация советует
## капсулу или коробку): герой у ствола, камня или жителя дрожал и «застревал». Боковая стенка капсулы идёт от
## PILLAR_BELOW м под основанием до max(h, PILLAR_MIN_H): контакт с героем всегда сбоку (стена, а не пол) — низкий
## камень не «подсаживает» героя на край; скругления — под землёй и выше роста героя.
const PILLAR_BELOW := 1.0
const PILLAR_MIN_H := 2.4


static func pillar_shape(r: float, h: float) -> CapsuleShape3D:
	var s := CapsuleShape3D.new()
	s.radius = r
	s.height = maxf(h, PILLAR_MIN_H) + PILLAR_BELOW + 2.0 * r
	return s


## Высота центра капсулы pillar_shape(r, h) над основанием.
static func pillar_y(h: float) -> float:
	return (maxf(h, PILLAR_MIN_H) - PILLAR_BELOW) * 0.5


## Готовый узел коллизии-столба (основание — в начале координат узла-родителя).
static func pillar(r: float, h: float) -> CollisionShape3D:
	var col := CollisionShape3D.new()
	col.shape = pillar_shape(r, h)
	col.position.y = pillar_y(h)
	return col
