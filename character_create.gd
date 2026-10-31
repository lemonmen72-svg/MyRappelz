class_name CharacterCreate
extends CanvasLayer
## Экран создания персонажа: слева имя, раса и пол; в центре — 3D-превью героя (модель расы и пола —
## CharacterModel.hero_asset, SubViewport, медленно вращается, можно крутить пальцем, касание — показать атаку);
## справа — карточка: все начинают Бродягой (описание, 7 статов 1-го уровня) и три профессии расы, одну из которых
## мудрец Альдерик предложит выбрать с 10 уровня. Класс на этом экране не выбирается.
## Рассчитан на 1280×720 и касания пальцем; размеры шрифтов и кнопок — UiScale (настройка «Размер интерфейса»).

signal created(char_name: String, race_id: String, gender: String)

const GOLD := Color(0.95, 0.8, 0.4)
const MUTED := Color(0.7, 0.72, 0.78)

var _race := "dark_elf"
var _gender := "f"
var _name_edit: LineEdit
var _race_btns: Dictionary = {}
var _gender_btns: Dictionary = {}
var _race_desc: Label
var _class_stripe: ColorRect
var _class_title: Label
var _class_sub: Label
var _class_desc: Label
## 7 статов Бродяги 1-го уровня.
var _stats7: Label
## Три профессии расы (подписи).
var _jobs_box: VBoxContainer
var _preview_pivot: Node3D
var _preview_model: CharacterModel
var _preview_caption: Label
var _drag_pause := 0.0


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var band := ColorRect.new()
	band.color = Color(0.1, 0.12, 0.17)
	band.set_anchors_preset(Control.PRESET_TOP_WIDE)
	band.custom_minimum_size = Vector2(0, UiScale.px(64))
	add_child(band)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.theme = Util.ui_theme()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + String(side), int(UiScale.px(16)))
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", int(UiScale.px(10)))
	margin.add_child(root)

	var title := _label("Создание персонажа", UiScale.FONT_TITLE + 4, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", int(UiScale.px(14)))
	root.add_child(cols)

	cols.add_child(_build_left())
	cols.add_child(_build_preview())
	cols.add_child(_build_right())

	_select_race(_race)


func _build_left() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(UiScale.px(6)))
	panel.add_child(v)

	v.add_child(_label("Имя", UiScale.FONT_TEXT, MUTED))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Имя персонажа"
	_name_edit.text = "Герой"
	_name_edit.max_length = 16
	_name_edit.custom_minimum_size = Vector2(0, UiScale.button_h())
	v.add_child(_name_edit)

	v.add_child(_label("Раса", UiScale.FONT_TEXT, MUTED))
	var race_box := VBoxContainer.new()
	race_box.add_theme_constant_override("separation", int(UiScale.px(5)))
	v.add_child(race_box)
	for rid in ClassData.RACES:
		var b := _choice_button(String(ClassData.race(rid)["name"]), UiScale.BUTTON_H - 4)
		b.pressed.connect(_select_race.bind(String(rid)))
		race_box.add_child(b)
		_race_btns[rid] = b
	_race_desc = _label("", UiScale.FONT_BODY, Color(0.88, 0.88, 0.9))
	_race_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_race_desc.custom_minimum_size = Vector2(0, UiScale.px(40))
	v.add_child(_race_desc)

	v.add_child(_label("Пол", UiScale.FONT_TEXT, MUTED))
	var gbox := HBoxContainer.new()
	gbox.add_theme_constant_override("separation", int(UiScale.px(6)))
	v.add_child(gbox)
	for e in ClassData.GENDERS:
		var g := String(e[0])
		var gb := _choice_button(String(e[1]), UiScale.BUTTON_H - 4)
		gb.pressed.connect(_select_gender.bind(g))
		gbox.add_child(gb)
		_gender_btns[g] = gb

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)

	var start := Button.new()
	start.text = "Начать игру"
	start.custom_minimum_size = Vector2(0, UiScale.px(UiScale.BUTTON_H + 8))
	start.add_theme_font_size_override("font_size", UiScale.fs(UiScale.FONT_TITLE))
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.2, 0.5, 0.25) if state != "pressed" else Color(0.3, 0.65, 0.3)
		if state == "hover":
			sb.bg_color = Color(0.24, 0.56, 0.3)
		sb.border_color = GOLD
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(int(UiScale.px(UiScale.BTN_RADIUS)))
		sb.set_content_margin_all(UiScale.px(8))
		start.add_theme_stylebox_override(state, sb)
	start.pressed.connect(_on_start)
	v.add_child(start)
	return panel


## Центральная колонка: 3D-превью в отдельном мире (свой свет и фон, не зависит от игрового мира).
func _build_preview() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 0.9
	panel.custom_minimum_size = Vector2(UiScale.px(220), 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(UiScale.px(4)))
	panel.add_child(v)

	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	svc.gui_input.connect(_on_preview_input)
	v.add_child(svc)

	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.size = Vector2i(240, 400)
	svc.add_child(vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.11, 0.13, 0.19)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.76)
	env.ambient_light_energy = 0.55
	var cam := Camera3D.new()
	cam.environment = env
	cam.fov = 32.0
	cam.transform = Transform3D(Basis.IDENTITY, Vector3(0, 1.1, 3.9)).looking_at(Vector3(0, 0.93, 0), Vector3.UP)
	vp.add_child(cam)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32, -35, 0)
	key.light_energy = 1.15
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 155, 0)
	rim.light_color = Color(0.7, 0.8, 1.0)
	rim.light_energy = 0.6
	vp.add_child(rim)

	# Подиум под ногами
	var podium := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.7
	pm.bottom_radius = 0.78
	pm.height = 0.08
	pm.radial_segments = 32
	podium.mesh = pm
	podium.position.y = -0.04
	podium.set_meta("no_outline", true)
	podium.material_override = Util.mat(Color(0.24, 0.26, 0.34))
	vp.add_child(podium)

	_preview_pivot = Node3D.new()
	# Модель смотрит в -Z, камера стоит на +Z: разворачиваем лицом к камере (и чуть вполоборота)
	_preview_pivot.rotation.y = PI - 0.45
	vp.add_child(_preview_pivot)

	_preview_caption = _label("", UiScale.FONT_BODY, MUTED)
	_preview_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_preview_caption)
	return panel


## Пересобрать модель превью под выбранные расу и пол (Бродяга с учебным мечом) и показать атаку.
func _update_preview() -> void:
	if _preview_pivot == null:
		return
	if _preview_model != null and is_instance_valid(_preview_model):
		_preview_model.queue_free()
	_preview_model = CharacterModel.new()
	_preview_model.setup(CharacterModel.spec_for(_race, ClassData.WANDERER,
		ItemData.weapon_kind(ItemData.default_weapon(ClassData.WANDERER)), _gender))
	_preview_pivot.add_child(_preview_model)
	if _preview_model.is_inside_tree():
		_preview_model.play_attack()
	_preview_caption.text = "%s · %s · Бродяга" % [String(ClassData.race(_race)["name"]),
		ClassData.gender_name(_gender).to_lower()]


## Перетаскивание по превью вращает персонажа, касание — показать атаку.
## Касания приходят как мышь (pointing/emulate_mouse_from_touch в project.godot).
func _on_preview_input(e: InputEvent) -> void:
	if _preview_pivot == null:
		return
	var dx := 0.0
	if e is InputEventMouseMotion:
		var mm := e as InputEventMouseMotion
		if (int(mm.button_mask) & int(MOUSE_BUTTON_MASK_LEFT)) != 0:
			dx = mm.relative.x
	elif e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and is_instance_valid(_preview_model):
			_preview_model.play_attack()
	if dx != 0.0:
		_preview_pivot.rotation.y += dx * 0.012
		_drag_pause = 2.0


func _process(delta: float) -> void:
	if _preview_pivot == null:
		return
	if _drag_pause > 0.0:
		_drag_pause -= delta
	else:
		_preview_pivot.rotation.y += delta * 0.5


func _build_right() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.3
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(UiScale.px(5)))
	panel.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", int(UiScale.px(10)))
	v.add_child(head)
	_class_stripe = ColorRect.new()
	_class_stripe.custom_minimum_size = Vector2(UiScale.px(8), 0)
	head.add_child(_class_stripe)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	head.add_child(hv)
	_class_title = _label("", UiScale.FONT_NAME, Color.WHITE)
	hv.add_child(_class_title)
	_class_sub = _label("", UiScale.FONT_BODY, MUTED)
	hv.add_child(_class_sub)

	_class_desc = _label("", UiScale.FONT_TEXT, Color(0.9, 0.9, 0.92))
	_class_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_class_desc)
	_stats7 = _label("", UiScale.FONT_BODY, Color(0.85, 0.86, 0.9))
	_stats7.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_stats7)

	v.add_child(HSeparator.new())
	v.add_child(_label("Профессии расы — выбор на %d уровне" % ClassData.JOB_LEVEL, UiScale.FONT_TEXT, GOLD))
	_jobs_box = VBoxContainer.new()
	_jobs_box.add_theme_constant_override("separation", int(UiScale.px(5)))
	v.add_child(_jobs_box)
	return panel


## Подпись; font_size — для «Среднего» размера интерфейса (UiScale.FONT_*).
func _label(text: String, font_size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", UiScale.fs(font_size))
	l.add_theme_color_override("font_color", col)
	return l


## Кнопка выбора; height — для «Среднего» размера интерфейса (по умолчанию UiScale.BUTTON_H).
func _choice_button(text: String, height: float = 44.0) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(0, UiScale.px(height))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", UiScale.fs(UiScale.FONT_TEXT + 1))
	return b


func _select_race(rid: String) -> void:
	if not ClassData.RACES.has(rid):
		return
	_race = rid
	var r := ClassData.race(rid)
	for k in _race_btns:
		var b: Button = _race_btns[k]
		b.set_pressed_no_signal(k == rid)
	_race_desc.text = String(r["desc"])
	_refresh_card()


func _select_gender(g: String) -> void:
	if g != "f" and g != "m":
		return
	_gender = g
	_refresh_card()


## Карточка справа: Бродяга (описание, 7 статов) и три профессии выбранной расы; превью.
func _refresh_card() -> void:
	for k in _gender_btns:
		(_gender_btns[k] as Button).set_pressed_no_signal(k == _gender)
	var c := ClassData.cls(ClassData.WANDERER)
	var col: Color = c["color"]
	_class_stripe.color = col.lightened(0.2)
	_class_title.text = "Бродяга"
	_class_title.add_theme_color_override("font_color", col.lightened(0.45))
	_class_sub.text = "%s · начальная профессия всех рас · %s" % [String(ClassData.race(_race)["name"]), String(c["weapon_text"])]
	_class_desc.text = String(c["desc"])
	var st := HeroStats.base_stats(ClassData.WANDERER, 1)
	var parts: PackedStringArray = []
	for k in Stats.STATS:
		parts.append("%s %d" % [String(Stats.STAT_NAMES[k]), int(st[k])])
	_stats7.text = " · ".join(parts)
	for ch in _jobs_box.get_children():
		ch.queue_free()
	for jid in ClassData.jobs_of(_race):
		var j := ClassData.cls(String(jid))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", int(UiScale.px(8)))
		var jc: Color = j["color"]
		top.add_child(_label(String(j["name"]), UiScale.FONT_HEAD, jc.lightened(0.35)))
		top.add_child(_label(String(j["role"]), UiScale.FONT_BODY, MUTED))
		box.add_child(top)
		var d := _label(String(j["desc"]), UiScale.FONT_SMALL, Color(0.85, 0.86, 0.9))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(d)
		_jobs_box.add_child(box)
	_update_preview()


func _on_start() -> void:
	var n := _name_edit.text.strip_edges()
	if n == "":
		n = "Герой"
	created.emit(n, _race, _gender)
