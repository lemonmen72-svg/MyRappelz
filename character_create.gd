class_name CharacterCreate
extends CanvasLayer
## Экран создания персонажа: имя, раса, класс.
## Каркас: рабочий, модуль «Персонаж и бой» может улучшить вид.

signal created(char_name: String, race_id: String, class_id: String)

var _race := "human"
var _class := "warrior"
var _name_edit: LineEdit
var _race_box: HBoxContainer
var _class_box: HBoxContainer
var _desc: Label


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.08, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.theme = Util.ui_theme()
	add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(900, 0)
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)

	var title := Label.new()
	title.text = "Создание персонажа"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Имя персонажа"
	_name_edit.text = "Герой"
	_name_edit.max_length = 16
	v.add_child(_name_edit)

	_race_box = HBoxContainer.new()
	_race_box.add_theme_constant_override("separation", 10)
	v.add_child(_race_box)
	_class_box = HBoxContainer.new()
	_class_box.add_theme_constant_override("separation", 10)
	v.add_child(_class_box)

	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(0, 90)
	v.add_child(_desc)

	var start := Button.new()
	start.text = "Начать игру"
	start.pressed.connect(_on_start)
	v.add_child(start)

	_rebuild()


func _rebuild() -> void:
	for c in _race_box.get_children():
		c.queue_free()
	for c in _class_box.get_children():
		c.queue_free()
	for rid in ClassData.RACES:
		var b := Button.new()
		b.text = ClassData.race(rid)["name"]
		b.toggle_mode = true
		b.button_pressed = rid == _race
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_select_race.bind(rid))
		_race_box.add_child(b)
	for cid in ClassData.race(_race)["classes"]:
		var b := Button.new()
		b.text = ClassData.cls(cid)["name"]
		b.toggle_mode = true
		b.button_pressed = cid == _class
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_select_class.bind(cid))
		_class_box.add_child(b)
	_desc.text = "%s: %s\n%s: %s" % [
		ClassData.race(_race)["name"], ClassData.race(_race)["desc"],
		ClassData.cls(_class)["name"], ClassData.cls(_class)["desc"]]


func _select_race(rid: String) -> void:
	_race = rid
	_class = ClassData.race(rid)["classes"][0]
	_rebuild()


func _select_class(cid: String) -> void:
	_class = cid
	_rebuild()


func _on_start() -> void:
	var n := _name_edit.text.strip_edges()
	if n == "":
		n = "Герой"
	created.emit(n, _race, _class)
