class_name HUD
extends CanvasLayer
## Интерфейс: плавающий джойстик (левая половина экрана), кнопки справа,
## полосы здоровья и опыта. На ПК: WASD/стрелки, Пробел = атака, T = приручить.

signal tame_pressed

const JOY_RADIUS := 110.0
const ATTACK_R := 85.0
const TAME_R := 62.0

var move_vec := Vector2.ZERO
var attack_held := false

var _joy_idx := -1
var _joy_center := Vector2.ZERO
var _attack_idx := -1
var _view := Vector2(1280, 720)
var _attack_c := Vector2.ZERO
var _tame_c := Vector2.ZERO

var _joy_base: Panel
var _joy_knob: Panel
var _attack_btn: Panel
var _tame_btn: Panel
var _hp_bar: ProgressBar
var _xp_bar: ProgressBar
var _stats_label: Label
var _pet_label: Label
var _msg_label: Label
var _msg_time := 0.0


func _ready() -> void:
	_joy_base = _circle(JOY_RADIUS, Color(1, 1, 1, 0.12), "", 24)
	_joy_knob = _circle(45.0, Color(1, 1, 1, 0.35), "", 24)
	_attack_btn = _circle(ATTACK_R, Color(0.9, 0.2, 0.2, 0.45), "Атака", 26)
	_tame_btn = _circle(TAME_R, Color(0.2, 0.7, 0.3, 0.45), "Приручить", 18)

	_hp_bar = _bar(Vector2(20, 20), Vector2(340, 28), Color(0.85, 0.2, 0.2))
	_xp_bar = _bar(Vector2(20, 52), Vector2(340, 14), Color(0.9, 0.8, 0.2))
	_stats_label = _label(Vector2(20, 72), 24)
	_pet_label = _label(Vector2(20, 106), 22)
	_msg_label = _label(Vector2(0, 150), 30)
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_label.add_theme_color_override("font_color", Color(1, 0.95, 0.5))

	get_viewport().size_changed.connect(_layout)
	_layout()


func _circle(radius: float, fill: Color, text: String, font_size: int) -> Panel:
	var p := Panel.new()
	p.size = Vector2(radius * 2.0, radius * 2.0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(radius))
	sb.border_color = Color(1, 1, 1, 0.5)
	sb.set_border_width_all(3)
	p.add_theme_stylebox_override("panel", sb)
	if text != "":
		var l := Label.new()
		l.text = text
		l.size = p.size
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", font_size)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(l)
	add_child(p)
	return p


func _bar(pos: Vector2, sz: Vector2, col: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.position = pos
	b.size = sz
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	b.add_theme_stylebox_override("fill", fill)
	b.add_theme_stylebox_override("background", bg)
	add_child(b)
	return b


func _label(pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _layout() -> void:
	_view = get_viewport().get_visible_rect().size
	_attack_c = Vector2(_view.x - 170.0, _view.y - 180.0)
	_tame_c = Vector2(_view.x - 340.0, _view.y - 110.0)
	_attack_btn.position = _attack_c - _attack_btn.size / 2.0
	_tame_btn.position = _tame_c - _tame_btn.size / 2.0
	_msg_label.position = Vector2(0, 150)
	_msg_label.size = Vector2(_view.x, 40)
	if _joy_idx == -1:
		_reset_joy()


func _reset_joy() -> void:
	_joy_idx = -1
	_joy_center = Vector2(210.0, _view.y - 190.0)
	_joy_base.position = _joy_center - _joy_base.size / 2.0
	_joy_knob.position = _joy_center - _joy_knob.size / 2.0
	move_vec = Vector2.ZERO


func _input(event: InputEvent) -> void:
	var te := event as InputEventScreenTouch
	if te != null:
		if te.pressed:
			var p := te.position
			if p.distance_to(_attack_c) <= ATTACK_R * 1.2:
				_attack_idx = te.index
			elif p.distance_to(_tame_c) <= TAME_R * 1.2:
				tame_pressed.emit()
			elif _joy_idx == -1 and p.x < _view.x * 0.5:
				_joy_idx = te.index
				_joy_center = p
				_joy_base.position = p - _joy_base.size / 2.0
				_joy_knob.position = p - _joy_knob.size / 2.0
		else:
			if te.index == _joy_idx:
				_reset_joy()
			if te.index == _attack_idx:
				_attack_idx = -1
		return

	var de := event as InputEventScreenDrag
	if de != null and de.index == _joy_idx:
		var d := de.position - _joy_center
		var dist := minf(d.length(), JOY_RADIUS)
		var dir := Vector2.ZERO
		if d.length() > 0.001:
			dir = d.normalized()
		move_vec = dir * (dist / JOY_RADIUS)
		_joy_knob.position = _joy_center + dir * dist - _joy_knob.size / 2.0
		return

	var ke := event as InputEventKey
	if ke != null and ke.pressed and not ke.echo and ke.keycode == KEY_T:
		tame_pressed.emit()


func _process(delta: float) -> void:
	attack_held = _attack_idx != -1 or Input.is_key_pressed(KEY_SPACE)

	if _joy_idx == -1:
		var v := Vector2.ZERO
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			v.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			v.y += 1.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			v.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			v.x += 1.0
		move_vec = v.normalized()

	if _msg_time > 0.0:
		_msg_time -= delta
	_msg_label.modulate.a = clampf(_msg_time, 0.0, 1.0)


func update_player(p: Player) -> void:
	_hp_bar.max_value = p.max_hp
	_hp_bar.value = p.hp
	_xp_bar.max_value = p.xp_next
	_xp_bar.value = p.xp
	_stats_label.text = "Ур. %d   HP %d/%d   Золото: %d" % [p.level, p.hp, p.max_hp, p.gold]


func update_pet(pet: Pet) -> void:
	if pet == null:
		_pet_label.text = "Питомца нет: ослабьте зверя (HP ниже 50%) и нажмите «Приручить»"
		return
	var state := ""
	if pet.is_down:
		state = "  (отдыхает)"
	_pet_label.text = "Питомец: %s  Ур.%d  HP %d/%d  Опыт %d/%d%s" % [
		pet.pet_name, pet.level, pet.hp, pet.max_hp, pet.xp, pet.xp_next, state]


func show_message(t: String) -> void:
	_msg_label.text = t
	_msg_time = 3.0
