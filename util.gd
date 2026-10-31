class_name Util
extends RefCounted
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
	var colors := {
		"normal": Color(0.95, 0.93, 0.86), "hover": Color(1.0, 0.98, 0.92),
		"pressed": Color(1.0, 0.82, 0.45), "disabled": Color(0.45, 0.46, 0.52),
		"focus": Color(0, 0, 0, 0),
	}
	for state in colors:
		var sb := StyleBoxFlat.new()
		sb.bg_color = colors[state]
		if state == "focus":
			sb.draw_center = false
		else:
			sb.border_color = Color(0.85, 0.68, 0.32)
			sb.set_border_width_all(2)
		_theme.set_stylebox(state, "Button", sb)
	# Тёмный текст на светлых кнопках
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_hover_pressed_color"]:
		_theme.set_color(c, "Button", Color(0.18, 0.16, 0.28))
	_theme.set_color("font_pressed_color", "Button", Color(0.3, 0.18, 0.05))
	_theme.set_color("font_disabled_color", "Button", Color(0.8, 0.8, 0.85))
	refresh_theme()
	return _theme


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
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := _theme.get_stylebox(state, "Button") as StyleBoxFlat
		if sb == null:
			continue
		sb.set_corner_radius_all(int(UiScale.px(UiScale.BTN_RADIUS)))
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
	if solid and Quality.outlines() and not mi.has_meta("no_outline") and m.next_pass == null:
		m.next_pass = outline_mat(m.albedo_color)


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
