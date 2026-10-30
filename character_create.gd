class_name CharacterCreate
extends CanvasLayer
## Экран создания персонажа: слева имя, раса, класс; в центре — 3D-превью персонажа
## (SubViewport, медленно вращается, можно крутить пальцем, касание — показать атаку);
## справа — карточка класса: описание, характеристики 1-го уровня и два умения.
## Рассчитан на 1280×720 и касания пальцем.

signal created(char_name: String, race_id: String, class_id: String)

## [ключ ClassData.stats_for(), подпись]
const STAT_ROWS := [
	["max_hp", "Здоровье"], ["atk", "Атака"], ["def", "Защита"],
	["range", "Дальность"], ["speed", "Скорость"],
]
const GOLD := Color(0.95, 0.8, 0.4)
const MUTED := Color(0.7, 0.72, 0.78)

var _race := "human"
var _class := "warrior"
var _name_edit: LineEdit
var _race_btns: Dictionary = {}
var _class_box: HBoxContainer
var _race_desc: Label
var _class_stripe: ColorRect
var _class_title: Label
var _class_sub: Label
var _class_desc: Label
var _stat_bars: Dictionary = {}
var _stat_vals: Dictionary = {}
var _stat_max: Dictionary = {}
var _skills_box: VBoxContainer
var _preview_pivot: Node3D
var _preview_model: CharacterModel
var _preview_caption: Label
var _drag_pause := 0.0


func _ready() -> void:
	_calc_stat_max()

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var band := ColorRect.new()
	band.color = Color(0.1, 0.12, 0.17)
	band.set_anchors_preset(Control.PRESET_TOP_WIDE)
	band.custom_minimum_size = Vector2(0, 90)
	add_child(band)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.theme = Util.ui_theme()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + String(side), 22)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var title := _label("Создание персонажа", 34, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 18)
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
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	v.add_child(_label("Имя", 20, MUTED))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Имя персонажа"
	_name_edit.text = "Герой"
	_name_edit.max_length = 16
	_name_edit.custom_minimum_size = Vector2(0, 54)
	v.add_child(_name_edit)

	v.add_child(_label("Раса", 20, MUTED))
	var race_box := VBoxContainer.new()
	race_box.add_theme_constant_override("separation", 6)
	v.add_child(race_box)
	for rid in ClassData.RACES:
		var b := _choice_button(String(ClassData.race(rid)["name"]), 50)
		b.pressed.connect(_select_race.bind(String(rid)))
		race_box.add_child(b)
		_race_btns[rid] = b
	_race_desc = _label("", 18, Color(0.88, 0.88, 0.9))
	_race_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_race_desc.custom_minimum_size = Vector2(0, 50)
	v.add_child(_race_desc)

	v.add_child(_label("Класс", 20, MUTED))
	_class_box = HBoxContainer.new()
	_class_box.add_theme_constant_override("separation", 8)
	v.add_child(_class_box)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)

	var start := Button.new()
	start.text = "Начать игру"
	start.custom_minimum_size = Vector2(0, 64)
	start.add_theme_font_size_override("font_size", 30)
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.2, 0.5, 0.25) if state != "pressed" else Color(0.3, 0.65, 0.3)
		if state == "hover":
			sb.bg_color = Color(0.24, 0.56, 0.3)
		sb.border_color = GOLD
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(10)
		sb.set_content_margin_all(12)
		start.add_theme_stylebox_override(state, sb)
	start.pressed.connect(_on_start)
	v.add_child(start)
	return panel


## Центральная колонка: 3D-превью в отдельном мире (свой свет и фон, не зависит от игрового мира).
func _build_preview() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 0.9
	panel.custom_minimum_size = Vector2(240, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
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

	_preview_caption = _label("", 18, MUTED)
	_preview_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_preview_caption)
	return panel


## Пересобрать модель превью под выбранные расу и класс и показать атаку.
func _update_preview() -> void:
	if _preview_pivot == null:
		return
	if _preview_model != null and is_instance_valid(_preview_model):
		_preview_model.queue_free()
	_preview_model = CharacterModel.new()
	_preview_model.setup(CharacterModel.spec_for(_race, _class))
	_preview_pivot.add_child(_preview_model)
	if _preview_model.is_inside_tree():
		_preview_model.play_attack()
	_preview_caption.text = "%s · %s" % [String(ClassData.race(_race)["name"]), String(ClassData.cls(_class)["name"])]


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
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	_class_stripe = ColorRect.new()
	_class_stripe.custom_minimum_size = Vector2(12, 0)
	head.add_child(_class_stripe)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	head.add_child(hv)
	_class_title = _label("", 30, Color.WHITE)
	hv.add_child(_class_title)
	_class_sub = _label("", 18, MUTED)
	hv.add_child(_class_sub)

	_class_desc = _label("", 20, Color(0.9, 0.9, 0.92))
	_class_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_class_desc)

	v.add_child(HSeparator.new())
	v.add_child(_label("Характеристики (1-й уровень)", 20, GOLD))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)
	for row in STAT_ROWS:
		var key: String = row[0]
		var name_l := _label(String(row[1]), 18, Color(0.9, 0.9, 0.92))
		name_l.custom_minimum_size = Vector2(110, 0)
		grid.add_child(name_l)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.min_value = 0.0
		bar.max_value = 1.0
		bar.custom_minimum_size = Vector2(90, 16)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var back := StyleBoxFlat.new()
		back.bg_color = Color(0.18, 0.19, 0.24)
		back.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("background", back)
		grid.add_child(bar)
		_stat_bars[key] = bar
		var val := _label("", 18, Color.WHITE)
		val.custom_minimum_size = Vector2(140, 0)
		grid.add_child(val)
		_stat_vals[key] = val

	v.add_child(HSeparator.new())
	v.add_child(_label("Умения", 20, GOLD))
	_skills_box = VBoxContainer.new()
	_skills_box.add_theme_constant_override("separation", 6)
	v.add_child(_skills_box)
	return panel


func _label(text: String, font_size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	return l


func _choice_button(text: String, height: float = 54.0) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(0, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 20)
	return b


## Максимум каждой характеристики среди классов на 1 уровне (для длины полос).
func _calc_stat_max() -> void:
	for cid in ClassData.CLASSES:
		var s := ClassData.stats_for(String(cid), 1)
		for row in STAT_ROWS:
			var key: String = row[0]
			var val: float = float(s[key])
			var cur: float = _stat_max.get(key, 0.0)
			_stat_max[key] = maxf(cur, val)


func _select_race(rid: String) -> void:
	_race = rid
	var r := ClassData.race(rid)
	for k in _race_btns:
		var b: Button = _race_btns[k]
		b.set_pressed_no_signal(k == rid)
	_race_desc.text = String(r["desc"])
	var classes: Array = r["classes"]
	if not classes.has(_class):
		_class = String(classes[0])

	for c in _class_box.get_children():
		c.queue_free()
	for cid in classes:
		var b := _choice_button(String(ClassData.cls(cid)["name"]))
		b.set_pressed_no_signal(cid == _class)
		b.pressed.connect(_select_class.bind(String(cid)))
		_class_box.add_child(b)
	_select_class(_class)


func _select_class(cid: String) -> void:
	_class = cid
	for b in _class_box.get_children():
		var btn := b as Button
		if btn != null and not btn.is_queued_for_deletion():
			btn.set_pressed_no_signal(btn.text == String(ClassData.cls(cid)["name"]))

	var c := ClassData.cls(cid)
	var col: Color = c["color"]
	var kind: String = c["attack"]
	_class_stripe.color = col
	_class_title.text = String(c["name"])
	_class_title.add_theme_color_override("font_color", col.lightened(0.25))
	_class_sub.text = "%s · %s" % [String(ClassData.race(_race)["name"]), ClassData.attack_name(kind)]
	_class_desc.text = String(c["desc"])

	var s := ClassData.stats_for(cid, 1)
	for row in STAT_ROWS:
		var key: String = row[0]
		var v: float = float(s[key])
		var bar: ProgressBar = _stat_bars[key]
		var mx: float = _stat_max.get(key, 1.0)
		bar.value = v / mx if mx > 0.0 else 0.0
		var fill := StyleBoxFlat.new()
		fill.bg_color = col.lightened(0.15)
		fill.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("fill", fill)
		var lbl: Label = _stat_vals[key]
		match key:
			"range":
				lbl.text = "%s м (%s)" % [_num(v), ClassData.attack_name(kind)]
			"speed":
				lbl.text = "%s м/с" % _num(v)
			_:
				lbl.text = _num(v)

	for ch in _skills_box.get_children():
		ch.queue_free()
	for sid in c["skills"]:
		var sk := ClassData.skill(String(sid))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 10)
		top.add_child(_label(String(sk.get("name", sid)), 22, Color(1, 0.85, 0.5)))
		top.add_child(_label("перезарядка %s с" % _num(float(sk.get("cd", 0.0))), 17, MUTED))
		box.add_child(top)
		var d := _label(String(sk.get("desc", "")), 17, Color(0.85, 0.86, 0.9))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(d)
		_skills_box.add_child(box)

	_update_preview()


func _num(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(roundi(v))
	return "%.1f" % v


func _on_start() -> void:
	var n := _name_edit.text.strip_edges()
	if n == "":
		n = "Герой"
	created.emit(n, _race, _class)
