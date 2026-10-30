class_name HUD
extends CanvasLayer
## Интерфейс: плавающий джойстик (левая нижняя часть экрана), круглые кнопки действий справа,
## панели игрока (HP, MP, опыт), питомца и цели, окна (герой, питомцы, сумка, торговец).
## На ПК: WASD/стрелки, Пробел = атака, 1–4 = умения, T = приручить, Q = зелье, K = окно героя,
## P = питомцы, C = окно существа, I = сумка, E = торговец, F = питомец атакует, G = питомец за мной, O = настройки.

## Нажатие кнопки действия (касание, клавиша или кнопка меню).
signal action(id: String)

const JOY_RADIUS := 110.0
## Джойстик не начинается выше этой линии: там панели и кнопки меню.
const JOY_TOP := 230.0
## Вращение камеры не начинается выше этой линии (кнопки меню справа вверху).
const CAM_TOP := 90.0
const KEYS := {
	KEY_SPACE: "attack", KEY_1: "skill1", KEY_2: "skill2", KEY_3: "skill3", KEY_4: "skill4", KEY_T: "tame",
	KEY_Q: "potion", KEY_K: "hero_window",
	KEY_P: "pets_window", KEY_I: "bag_window", KEY_E: "shop", KEY_F: "pet_attack", KEY_G: "pet_follow", KEY_O: "settings_window",
	KEY_C: "creature_window",
}

var move_vec := Vector2.ZERO

## id -> {"panel": Panel, "label": Label, "offset": Vector2, "r": float, "hold": bool, "touch": int,
## "color": Color (заливка), "blocked": bool (не подходит оружие — затемнена)}
var _buttons := {}
var _joy_idx := -1
## Касания камеры (индекс → последняя позиция): один палец в правой половине экрана вне кнопок
## вращает камеру, два пальца щипком приближают и отдаляют. Накопленные сдвиг и множитель дальности.
var _cam_touches := {}
var _cam_drag := Vector2.ZERO
var _cam_zoom := 1.0
var _joy_center := Vector2.ZERO
var _view := Vector2(1280, 720)
var _window: Control = null
var _target: Node3D = null

var _joy_base: Panel
var _joy_knob: Panel
var _hp_bar: ProgressBar
var _mp_bar: ProgressBar
var _xp_bar: ProgressBar
var _stats_label: Label
var _pet_box: Control
var _pet_label: Label
var _pet_bar: ProgressBar
var _pet_mp_bar: ProgressBar
var _target_box: Control
var _target_label: Label
var _target_bar: ProgressBar
var _msg_label: Label
var _msg_time := 0.0
var _menu: HBoxContainer


func _ready() -> void:
	_joy_base = _circle(JOY_RADIUS, Color(1, 1, 1, 0.12))
	_joy_knob = _circle(45.0, Color(1, 1, 1, 0.35))

	_hp_bar = _bar(self, Vector2(20, 20), Vector2(340, 26), Color(0.85, 0.2, 0.2))
	_mp_bar = _bar(self, Vector2(20, 49), Vector2(340, 11), Color(0.35, 0.5, 1.0))
	_xp_bar = _bar(self, Vector2(20, 63), Vector2(340, 7), Color(0.9, 0.8, 0.2))
	_stats_label = _label(self, Vector2(20, 72), 22)

	_pet_box = Control.new()
	_pet_box.position = Vector2(20, 108)
	_pet_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pet_box)
	_pet_label = _label(_pet_box, Vector2(0, 0), 20)
	_pet_bar = _bar(_pet_box, Vector2(0, 30), Vector2(240, 14), Color(0.3, 0.75, 1.0))
	_pet_mp_bar = _bar(_pet_box, Vector2(0, 47), Vector2(240, 9), Color(0.55, 0.45, 1.0))
	var pet_btns := HBoxContainer.new()
	pet_btns.position = Vector2(0, 62)
	pet_btns.add_theme_constant_override("separation", 8)
	_pet_box.add_child(pet_btns)
	pet_btns.add_child(_menu_button("Атакуй", "pet_attack"))
	pet_btns.add_child(_menu_button("За мной", "pet_follow"))
	pet_btns.add_child(_menu_button("Существо", "creature_window"))

	_target_box = Control.new()
	_target_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_target_box)
	_target_label = _label(_target_box, Vector2(-80, 0), 22)
	_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_label.size = Vector2(480, 30)
	_target_bar = _bar(_target_box, Vector2(0, 32), Vector2(320, 16), Color(0.9, 0.35, 0.2))
	_target_box.visible = false

	_msg_label = _label(self, Vector2(0, 190), 28)
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_label.add_theme_color_override("font_color", Color(1, 0.95, 0.5))

	_menu = HBoxContainer.new()
	_menu.add_theme_constant_override("separation", 10)
	add_child(_menu)
	_menu.add_child(_menu_button("Герой", "hero_window"))
	_menu.add_child(_menu_button("Питомцы", "pets_window"))
	_menu.add_child(_menu_button("Сумка", "bag_window"))
	_menu.add_child(_menu_button("Настройки", "settings_window"))

	update_pet(null)
	get_viewport().size_changed.connect(_layout)
	_layout()


# ---------- Кнопки действий ----------

## Круглая кнопка. offset: центр, отсчитанный от правого нижнего угла экрана.
## hold = true: кнопку можно держать (is_held), иначе срабатывает action при касании.
func add_button(id: String, text: String, offset: Vector2, radius: float, color: Color, hold := false) -> void:
	var p := _circle(radius, color)
	var l := Label.new()
	l.text = text
	l.size = p.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", int(clampf(radius * 0.36, 15.0, 28.0)))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	_buttons[id] = {"panel": p, "label": l, "offset": offset, "r": radius, "hold": hold, "touch": -1,
		"color": color, "blocked": false}
	_layout()


func set_button_visible(id: String, v: bool) -> void:
	if _buttons.has(id):
		_buttons[id]["panel"].visible = v


func set_button_text(id: String, text: String) -> void:
	if _buttons.has(id):
		_buttons[id]["label"].text = text


## frac > 0: кнопка на перезарядке (затемнена). Кнопка с неподходящим оружием (set_blocked) — темнее всегда.
func set_cooldown(id: String, frac: float) -> void:
	if _buttons.has(id):
		var a := 0.35 if frac > 0.0 else 1.0
		if bool(_buttons[id]["blocked"]):
			a = 0.28
		_buttons[id]["panel"].modulate = Color(1, 1, 1, a)


## Кнопка недоступна (например, умение не подходит к оружию): затемнена, нажатие всё равно шлёт действие
## (модуль объясняет, почему нельзя).
func set_blocked(id: String, blocked: bool) -> void:
	if _buttons.has(id):
		_buttons[id]["blocked"] = blocked


func is_blocked(id: String) -> bool:
	return _buttons.has(id) and bool(_buttons[id]["blocked"])


## Цвет заливки круглой кнопки (включённое переключаемое умение и т. п.); null-цвет не бывает — передайте исходный.
func set_button_color(id: String, c: Color) -> void:
	if not _buttons.has(id):
		return
	var p: Panel = _buttons[id]["panel"]
	var sb := p.get_theme_stylebox("panel") as StyleBoxFlat
	if sb != null:
		sb.bg_color = c


## Исходный цвет кнопки (как при add_button).
func button_color(id: String) -> Color:
	if _buttons.has(id):
		return _buttons[id]["color"]
	return Color.WHITE


func button_text(id: String) -> String:
	if _buttons.has(id):
		return (_buttons[id]["label"] as Label).text
	return ""


func is_button_visible(id: String) -> bool:
	return _buttons.has(id) and (_buttons[id]["panel"] as Panel).visible


func is_held(id: String) -> bool:
	if not _buttons.has(id):
		return false
	if _buttons[id]["touch"] != -1:
		return true
	for k in KEYS:
		if KEYS[k] == id and Input.is_key_pressed(k):
			return true
	return false


## Сдвиг пальца для вращения камеры с прошлого вызова (пиксели); обнуляется.
func take_camera_drag() -> Vector2:
	var d := _cam_drag
	_cam_drag = Vector2.ZERO
	return d


## Множитель дальности камеры с прошлого вызова (щипок, колесо мыши): < 1 — ближе; сбрасывается в 1.
func take_camera_zoom() -> float:
	var z := _cam_zoom
	_cam_zoom = 1.0
	return z


# ---------- Окна ----------

## Создаёт окно по центру экрана и возвращает контейнер для содержимого.
## Пока окно открыто, джойстик и круглые кнопки не работают. Открыто только одно окно.
func create_window(title: String, sz: Vector2) -> VBoxContainer:
	close_window()
	var panel := PanelContainer.new()
	panel.theme = Util.ui_theme()
	panel.size = sz
	panel.position = (_view - sz) / 2.0
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)
	var head := HBoxContainer.new()
	root.add_child(head)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 30)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := Button.new()
	close.text = "Закрыть"
	close.pressed.connect(close_window)
	head.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	add_child(panel)
	_window = panel
	_release_all()
	return body


func close_window() -> void:
	if _window != null and is_instance_valid(_window):
		_window.queue_free()
	_window = null


func is_window_open() -> bool:
	return _window != null and is_instance_valid(_window)


# ---------- Панели ----------

func update_player(p: Player) -> void:
	_hp_bar.max_value = p.max_hp
	_hp_bar.value = p.hp
	_mp_bar.visible = p.max_mp > 0
	if _mp_bar.visible:
		_mp_bar.max_value = p.max_mp
		_mp_bar.value = p.mp
	_xp_bar.max_value = Game.xp_to_next(Game.level)
	_xp_bar.value = Game.xp
	var mp_text := ("   MP %d/%d" % [p.mp, p.max_mp]) if p.max_mp > 0 else ""
	_stats_label.text = "%s  Ур. %d   HP %d/%d%s   Золото: %d" % [
		Game.char_name, Game.level, p.hp, p.max_hp, mp_text, Game.gold]


## pet: узел питомца с полями pet_name, level, hp, max_hp и (необязательно) mp, max_mp, или null.
func update_pet(pet: Node) -> void:
	if pet == null or not is_instance_valid(pet):
		_pet_box.visible = false
		return
	_pet_box.visible = true
	_pet_label.text = "%s  Ур.%d  HP %d/%d" % [pet.pet_name, pet.level, pet.hp, pet.max_hp]
	_pet_bar.max_value = pet.max_hp
	_pet_bar.value = pet.hp
	var mmp = pet.get("max_mp")
	_pet_mp_bar.visible = mmp is int and int(mmp) > 0
	if _pet_mp_bar.visible:
		_pet_mp_bar.max_value = int(mmp)
		_pet_mp_bar.value = int(pet.get("mp"))


## Цель игрока: узел с полями mob_name, level, hp, max_hp, is_dead (или null).
func set_target(t: Node3D) -> void:
	_target = t
	_refresh_target()


## Сообщение внизу экрана на sec секунд.
func show_message(t: String, sec: float = 3.0) -> void:
	_msg_label.text = t
	_msg_time = sec


# ---------- Внутреннее ----------

func _circle(radius: float, fill: Color) -> Panel:
	var p := Panel.new()
	p.size = Vector2(radius * 2.0, radius * 2.0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(radius))
	sb.border_color = Color(1.0, 0.95, 0.82, 0.85)
	sb.set_border_width_all(4)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 6
	sb.anti_aliasing = true
	p.add_theme_stylebox_override("panel", sb)
	add_child(p)
	return p


func _bar(parent: Node, pos: Vector2, sz: Vector2, col: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.position = pos
	b.size = sz
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(int(sz.y / 2.0))
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.1, 0.2, 0.6)
	bg.border_color = Color(1.0, 0.95, 0.82, 0.8)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(int(sz.y / 2.0))
	b.add_theme_stylebox_override("fill", fill)
	b.add_theme_stylebox_override("background", bg)
	parent.add_child(b)
	return b


func _label(parent: Node, pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _menu_button(text: String, id: String) -> Button:
	var b := Button.new()
	b.text = text
	b.theme = Util.ui_theme()
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): action.emit(id))
	return b


func _layout() -> void:
	_view = get_viewport().get_visible_rect().size
	for id in _buttons:
		var b: Dictionary = _buttons[id]
		var p: Panel = b["panel"]
		p.position = _view - b["offset"] - p.size / 2.0
	_msg_label.position = Vector2(0, 190)
	_msg_label.size = Vector2(_view.x, 40)
	# Чуть левее центра: справа вверху кнопки меню
	_target_box.position = Vector2((_view.x - 320.0) / 2.0 - 50.0, 14)
	_menu.position = Vector2(_view.x - _menu.get_combined_minimum_size().x - 20.0, 16)
	if _window != null and is_instance_valid(_window):
		_window.position = (_view - _window.size) / 2.0
	if _joy_idx == -1:
		_reset_joy()


func _reset_joy() -> void:
	_joy_idx = -1
	_joy_center = Vector2(210.0, _view.y - 190.0)
	_joy_base.position = _joy_center - _joy_base.size / 2.0
	_joy_knob.position = _joy_center - _joy_knob.size / 2.0
	move_vec = Vector2.ZERO


func _release_all() -> void:
	_reset_joy()
	_cam_touches.clear()
	for id in _buttons:
		_buttons[id]["touch"] = -1


func _button_at(p: Vector2) -> String:
	for id in _buttons:
		var b: Dictionary = _buttons[id]
		var panel: Panel = b["panel"]
		if not panel.visible:
			continue
		var c := panel.position + panel.size / 2.0
		if p.distance_to(c) <= b["r"] * 1.15:
			return id
	return ""


func _input(event: InputEvent) -> void:
	var ke := event as InputEventKey
	if ke != null and ke.pressed and not ke.echo and KEYS.has(ke.keycode):
		var kid: String = KEYS[ke.keycode]
		if kid != "attack":
			action.emit(kid)
		return

	if is_window_open():
		return

	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_zoom *= 0.9
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_zoom /= 0.9

	var te := event as InputEventScreenTouch
	if te != null:
		if te.pressed:
			var p := te.position
			var id := _button_at(p)
			if id != "":
				if _buttons[id]["hold"]:
					_buttons[id]["touch"] = te.index
				action.emit(id)
			elif _joy_idx == -1 and p.x < _view.x * 0.5 and p.y > JOY_TOP:
				_joy_idx = te.index
				_joy_center = p
				_joy_base.position = p - _joy_base.size / 2.0
				_joy_knob.position = p - _joy_knob.size / 2.0
			elif p.y > CAM_TOP and _cam_touches.size() < 2 and (p.x >= _view.x * 0.5 or _cam_touches.size() == 1):
				# Второй палец (для щипка) может быть и в левой половине
				_cam_touches[te.index] = p
		else:
			if te.index == _joy_idx:
				_reset_joy()
			_cam_touches.erase(te.index)
			for id in _buttons:
				if _buttons[id]["touch"] == te.index:
					_buttons[id]["touch"] = -1
		return

	var de := event as InputEventScreenDrag
	if de != null and _cam_touches.has(de.index):
		var prev: Vector2 = _cam_touches[de.index]
		if _cam_touches.size() == 1:
			_cam_drag += de.position - prev
		else:
			var other := prev
			for k in _cam_touches:
				if k != de.index:
					other = _cam_touches[k]
			var before := other.distance_to(prev)
			var after := other.distance_to(de.position)
			if before > 10.0 and after > 10.0:
				_cam_zoom *= before / after
		_cam_touches[de.index] = de.position
		return
	if de != null and de.index == _joy_idx:
		var d := de.position - _joy_center
		var dist := minf(d.length(), JOY_RADIUS)
		var dir := Vector2.ZERO
		if d.length() > 0.001:
			dir = d.normalized()
		move_vec = dir * (dist / JOY_RADIUS)
		_joy_knob.position = _joy_center + dir * dist - _joy_knob.size / 2.0


func _process(delta: float) -> void:
	if _joy_idx == -1:
		var v := Vector2.ZERO
		if not is_window_open():
			if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
				v.y -= 1.0
			if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
				v.y += 1.0
			if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
				v.x -= 1.0
			if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
				v.x += 1.0
		move_vec = v.normalized()

	_refresh_target()

	if _msg_time > 0.0:
		_msg_time -= delta
	_msg_label.modulate.a = clampf(_msg_time, 0.0, 1.0)


func _refresh_target() -> void:
	if _target == null or not is_instance_valid(_target) or _target.get("is_dead") == true:
		_target = null
		_target_box.visible = false
		return
	_target_box.visible = true
	var rarity = _target.get("rarity")
	if rarity is String:
		_target_label.text = "%s · %s  Ур.%d" % [_target.get("mob_name"), MobData.rarity_label(rarity), _target.get("level")]
	else:
		_target_label.text = "%s  Ур.%d" % [_target.get("mob_name"), _target.get("level")]
	_target_bar.max_value = _target.get("max_hp")
	_target_bar.value = _target.get("hp")
