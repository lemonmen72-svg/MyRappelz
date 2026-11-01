class_name CharacterCreate
extends CanvasLayer
## Создание персонажа по шагам (кнопки «Назад» / «Далее»):
##   1. «Раса» — три карточки (Люди, Светлые эльфы, Тёмные эльфы): описание, сильные и слабые стороны
##      (ClassData RACES strengths / weaknesses), профессии расы;
##   2. «Профессии» — три профессии выбранной расы, только знакомство: роль, оружие, сильные стороны, особенности,
##      ключевые умения (ClassData strengths / features / key_skills). Все начинают Бродягой, профессию предложит
##      Мудрец Альдерик с 10 уровня;
##   3. «Пол» — 3D-превью Бродяг-новичков расы обоих полов (CharacterModel, модель hero_<раса>_<пол>_starter
##      с откатом на запасные; медленно вращаются, перетаскивание крутит, касание — выбрать и показать атаку);
##   4. «Ник» — превью выбранного героя, ник (Accounts.nick_error: 3–16 символов, буквы, цифры, _, уникален на
##      устройстве) → «Войти в игру» (сигнал created). «Назад» с первого шага — сигнал cancelled (к выбору персонажа).
## Рассчитан на 1280×720 и касания пальцем; размеры — UiScale, содержимое шага прокручивается, если не влезло.
## Для тестов: step, set_step(i), go_next() / go_back(), _select_race, _select_gender, preview_model(ключ "f" / "m" /
## "name"), _race_cards, _job_cards, _name_edit, _error.

signal created(char_name: String, race_id: String, gender: String)
signal cancelled

const STEPS := ["race", "jobs", "gender", "name"]
const STEP_NAMES := ["Раса", "Профессии", "Пол", "Ник"]
## Превью на шаге «Пол» и «Ник» для «Среднего» размера интерфейса.
const PREVIEW_SIZE := Vector2(250, 360)
const NAME_PREVIEW_SIZE := Vector2(250, 360)

var step := 0
var _race := "dark_elf"
var _gender := "f"
var _step_labels: Array[Label] = []
var _content: VBoxContainer
var _scroll: ScrollContainer
var _error: Label
var _back_btn: Button
var _next_btn: Button
var _race_cards: Dictionary = {}
var _job_cards: Array[PanelContainer] = []
var _gender_cards: Dictionary = {}
var _name_edit: LineEdit
var _nick := ""
## Превью: ключ ("f", "m", "name") → {"pivot": Node3D, "model": CharacterModel}.
var _previews: Dictionary = {}
var _drag_pause := 0.0


func _ready() -> void:
	var root := MenuKit.build_root(self)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", int(UiScale.px(14)))
	root.add_child(head)
	var t := MenuKit.label("Создание персонажа", UiScale.FONT_TITLE + 4, MenuKit.GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	for i in STEP_NAMES.size():
		var l := MenuKit.label("%d. %s" % [i + 1, String(STEP_NAMES[i])], UiScale.FONT_HEAD, MenuKit.MUTED)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(l)
		_step_labels.append(l)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", int(UiScale.px(8)))
	_scroll.add_child(_content)

	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", int(UiScale.px(12)))
	root.add_child(nav)
	_back_btn = MenuKit.button("Назад", UiScale.BUTTON_H + 4)
	_back_btn.pressed.connect(go_back)
	nav.add_child(_back_btn)
	_error = MenuKit.label("", UiScale.FONT_TEXT, MenuKit.BAD, true)
	_error.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nav.add_child(_error)
	_next_btn = MenuKit.main_button("Далее")
	_next_btn.custom_minimum_size.x = UiScale.px(220)
	_next_btn.pressed.connect(func() -> void: go_next())
	nav.add_child(_next_btn)
	set_step(0)


# ---------- Шаги ----------

## Показать шаг i (0 — раса … 3 — ник).
func set_step(i: int) -> void:
	if _name_edit != null and is_instance_valid(_name_edit):
		_nick = _name_edit.text
	step = clampi(i, 0, STEPS.size() - 1)
	for k in _step_labels.size():
		_step_labels[k].add_theme_color_override("font_color", MenuKit.GOLD if k == step else MenuKit.MUTED)
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	_previews.clear()
	_race_cards.clear()
	_job_cards.clear()
	_gender_cards.clear()
	_name_edit = null
	_error.text = ""
	_scroll.scroll_vertical = 0
	match String(STEPS[step]):
		"race":
			_build_race()
		"jobs":
			_build_jobs()
		"gender":
			_build_gender()
		_:
			_build_name()
	_back_btn.text = "К персонажам" if step == 0 else "Назад"
	_next_btn.text = "Войти в игру" if step == STEPS.size() - 1 else "Далее"


## «Далее»: следующий шаг; на последнем — проверка ника и сигнал created. false — ник не подошёл.
func go_next() -> bool:
	if step < STEPS.size() - 1:
		set_step(step + 1)
		return true
	var nick := _name_edit.text.strip_edges() if _name_edit != null else _nick.strip_edges()
	var err := Accounts.nick_error(nick)
	if err != "":
		_error.text = err
		return false
	created.emit(nick, _race, _gender)
	return true


## «Назад»: прошлый шаг; с первого — сигнал cancelled.
func go_back() -> void:
	if step == 0:
		cancelled.emit()
		return
	set_step(step - 1)


func _select_race(rid: String) -> void:
	if not ClassData.RACES.has(rid):
		return
	_race = rid
	for k in _race_cards:
		(_race_cards[k] as PanelContainer).add_theme_stylebox_override("panel",
			MenuKit.card_style(_race_color(String(k)), String(k) == _race))
	# На других шагах — пересобрать (профессии и превью новой расы)
	if step > 0:
		set_step(step)


func _select_gender(g: String) -> void:
	if g != "f" and g != "m":
		return
	_gender = g
	for k in _gender_cards:
		(_gender_cards[k] as PanelContainer).add_theme_stylebox_override("panel",
			MenuKit.card_style(Color(0.4, 0.45, 0.6), String(k) == _gender))
	if step == STEPS.find("name"):
		set_step(step)


## Модель превью по ключу ("f", "m" — шаг «Пол», "name" — шаг «Ник»); null — нет.
func preview_model(k: String) -> CharacterModel:
	var p: Dictionary = _previews.get(k, {})
	var m: Variant = p.get("model", null)
	if is_instance_valid(m) and m is CharacterModel:
		return m as CharacterModel
	return null


func _race_color(rid: String) -> Color:
	var r := ClassData.race(rid)
	var c: Color = r["eyes"]
	return c.lightened(0.15)


# ---------- 1. Раса ----------

func _build_race() -> void:
	_content.add_child(MenuKit.label("Выберите расу. Каждый герой начинает Бродягой-новичком в деревне своей расы; "
		+ "у каждой расы — три свои профессии.", UiScale.FONT_TEXT, MenuKit.MUTED, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiScale.px(10)))
	_content.add_child(row)
	for rid in ClassData.RACES:
		var id := String(rid)
		var r := ClassData.race(id)
		var card := _card(_race_color(id), id == _race)
		card.gui_input.connect(_on_card_input.bind(func() -> void: _select_race(id)))
		row.add_child(card)
		_race_cards[id] = card
		var v := card.get_child(0) as VBoxContainer
		v.add_child(MenuKit.label(String(r["name"]), UiScale.FONT_NAME, _race_color(id).lightened(0.3)))
		v.add_child(MenuKit.label(String(r["desc"]), UiScale.FONT_BODY, MenuKit.TEXT, true))
		v.add_child(MenuKit.label("Сильные стороны", UiScale.FONT_TEXT, MenuKit.GOOD))
		v.add_child(MenuKit.bullets(r.get("strengths", []), UiScale.FONT_SMALL, MenuKit.TEXT))
		v.add_child(MenuKit.label("Слабые стороны", UiScale.FONT_TEXT, MenuKit.BAD))
		v.add_child(MenuKit.bullets(r.get("weaknesses", []), UiScale.FONT_SMALL, MenuKit.TEXT))
		var jobs: PackedStringArray = []
		for jid in ClassData.jobs_of(id):
			jobs.append(ClassData.job_name(String(jid)))
		v.add_child(MenuKit.label("Профессии: " + ", ".join(jobs), UiScale.FONT_SMALL, MenuKit.GOLD, true))


# ---------- 2. Профессии ----------

func _build_jobs() -> void:
	var w := ClassData.cls(ClassData.WANDERER)
	var st := HeroStats.base_stats(ClassData.WANDERER, 1)
	var parts: PackedStringArray = []
	for k in Stats.STATS:
		parts.append("%s %d" % [String(Stats.STAT_NAMES[k]), int(st[k])])
	_content.add_child(MenuKit.label("Профессии расы «%s». Сейчас — только знакомство: все начинают Бродягой (%s), "
		% [String(ClassData.race(_race)["name"]), String(w["weapon_text"])]
		+ "профессию предложит Мудрец Альдерик с %d уровня. Бродяга 1-го уровня: %s." % [ClassData.JOB_LEVEL,
		" · ".join(parts)], UiScale.FONT_BODY, MenuKit.MUTED, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiScale.px(10)))
	_content.add_child(row)
	for jid in ClassData.jobs_of(_race):
		var id := String(jid)
		var j := ClassData.cls(id)
		var jc: Color = j["color"]
		var card := _card(jc.lightened(0.25), false)
		row.add_child(card)
		_job_cards.append(card)
		var v := card.get_child(0) as VBoxContainer
		v.add_child(MenuKit.label(String(j["name"]), UiScale.FONT_NAME, jc.lightened(0.4)))
		v.add_child(MenuKit.label(String(j["role"]), UiScale.FONT_BODY, MenuKit.MUTED, true))
		v.add_child(MenuKit.label("Оружие: " + String(j["weapon_text"]), UiScale.FONT_SMALL, MenuKit.TEXT, true))
		v.add_child(MenuKit.label("Сильные стороны", UiScale.FONT_TEXT, MenuKit.GOOD))
		v.add_child(MenuKit.bullets(j.get("strengths", []), UiScale.FONT_SMALL, MenuKit.TEXT))
		v.add_child(MenuKit.label("Особенности", UiScale.FONT_TEXT, Color(1.0, 0.75, 0.45)))
		v.add_child(MenuKit.bullets(j.get("features", []), UiScale.FONT_SMALL, MenuKit.TEXT))
		v.add_child(MenuKit.label("Ключевые умения: " + MenuKit.key_skill_names(id), UiScale.FONT_SMALL, MenuKit.GOLD, true))


# ---------- 3. Пол ----------

func _build_gender() -> void:
	_content.add_child(MenuKit.label("Выберите пол. Так выглядит Бродяга-новичок расы «%s» (покрутите пальцем):"
		% String(ClassData.race(_race)["name"]), UiScale.FONT_TEXT, MenuKit.MUTED, true))
	var center := CenterContainer.new()
	_content.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiScale.px(24)))
	center.add_child(row)
	for e in ClassData.GENDERS:
		var g := String(e[0])
		var card := _card(Color(0.4, 0.45, 0.6), g == _gender)
		row.add_child(card)
		_gender_cards[g] = card
		var v := card.get_child(0) as VBoxContainer
		v.add_child(_preview(g, g, PREVIEW_SIZE, func() -> void: _select_gender(g)))
		var b := MenuKit.button(String(e[1]))
		b.pressed.connect(func() -> void: _select_gender(g))
		v.add_child(b)


# ---------- 4. Ник ----------

func _build_name() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiScale.px(16)))
	_content.add_child(row)
	var pc := _card(_race_color(_race), false)
	row.add_child(pc)
	pc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	(pc.get_child(0) as VBoxContainer).add_child(_preview("name", _gender, NAME_PREVIEW_SIZE, Callable()))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", int(UiScale.px(8)))
	row.add_child(v)
	var r := ClassData.race(_race)
	v.add_child(MenuKit.label("%s · %s · Бродяга" % [String(r["name"]), ClassData.gender_name(_gender).to_lower()],
		UiScale.FONT_NAME, MenuKit.GOLD, true))
	v.add_child(MenuKit.label("Начало пути — деревня своей расы на тренировочном острове. С 10 уровня Мудрец Альдерик "
		+ "в городе предложит одну из профессий: " + _jobs_text() + ".", UiScale.FONT_BODY, MenuKit.TEXT, true))
	v.add_child(MenuKit.label("Ник персонажа", UiScale.FONT_HEAD, MenuKit.MUTED))
	_name_edit = MenuKit.line_edit("Ник персонажа", _nick)
	_name_edit.text_submitted.connect(func(_t: String) -> void: go_next())
	v.add_child(_name_edit)
	v.add_child(MenuKit.label(Accounts.NAME_RULES + ". Ник не должен повторяться у других персонажей.",
		UiScale.FONT_SMALL, MenuKit.MUTED, true))


func _jobs_text() -> String:
	var jobs: PackedStringArray = []
	for jid in ClassData.jobs_of(_race):
		jobs.append(ClassData.job_name(String(jid)))
	return ", ".join(jobs)


# ---------- Карточки и превью ----------

## Карточка (PanelContainer с VBoxContainer внутри): рамка цвета col, выбранная — золотая.
func _card(col: Color, selected: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", MenuKit.card_style(col, selected))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(UiScale.px(5)))
	panel.add_child(v)
	return panel


func _on_card_input(e: InputEvent, cb: Callable) -> void:
	var mb := e as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		cb.call()


## 3D-превью Бродяги расы _race пола g в отдельном мире (свой свет и фон): ключ k, размер box (для «Среднего»),
## касание — on_tap (и показать атаку), перетаскивание крутит.
func _preview(k: String, g: String, box: Vector2, on_tap: Callable) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(UiScale.px(4)))
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = UiScale.v2(box.x, box.y)
	v.add_child(svc)

	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.size = Vector2i(int(UiScale.px(box.x)), int(UiScale.px(box.y)))
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
	cam.transform = Transform3D(Basis.IDENTITY, Vector3(0, 1.1, 4.1)).looking_at(Vector3(0, 0.93, 0), Vector3.UP)
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

	var pivot := Node3D.new()
	# Модель смотрит в -Z, камера стоит на +Z: разворачиваем лицом к камере (и чуть вполоборота)
	pivot.rotation.y = PI - 0.45
	vp.add_child(pivot)
	var model := CharacterModel.new()
	var starter := ItemData.default_weapon(ClassData.WANDERER)
	model.setup(CharacterModel.spec_for(_race, ClassData.WANDERER, ItemData.weapon_kind(starter), g, false, starter))
	pivot.add_child(model)
	_previews[k] = {"pivot": pivot, "model": model}
	svc.gui_input.connect(_on_preview_input.bind(k, on_tap))

	var cap := MenuKit.label("%s · %s" % [String(ClassData.race(_race)["name"]), ClassData.gender_name(g).to_lower()],
		UiScale.FONT_BODY, MenuKit.MUTED)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cap)
	return v


## Перетаскивание по превью вращает персонажа, касание — on_tap и показать атаку.
## Касания приходят как мышь (pointing/emulate_mouse_from_touch в project.godot).
func _on_preview_input(e: InputEvent, k: String, on_tap: Callable) -> void:
	var p: Dictionary = _previews.get(k, {})
	if p.is_empty():
		return
	var pv: Variant = p.get("pivot", null)
	if not is_instance_valid(pv):
		return
	var pivot := pv as Node3D
	var dx := 0.0
	if e is InputEventMouseMotion:
		var mm := e as InputEventMouseMotion
		if (int(mm.button_mask) & int(MOUSE_BUTTON_MASK_LEFT)) != 0:
			dx = mm.relative.x
	elif e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var m := preview_model(k)
			if m != null and m.is_inside_tree():
				m.play_attack()
			if on_tap.is_valid():
				on_tap.call()
	if dx != 0.0:
		pivot.rotation.y += dx * 0.012
		_drag_pause = 2.0


func _process(delta: float) -> void:
	if _drag_pause > 0.0:
		_drag_pause -= delta
		return
	for k in _previews:
		var p: Dictionary = _previews[k]
		var pv: Variant = p.get("pivot", null)
		if is_instance_valid(pv):
			var pivot := pv as Node3D
			pivot.rotation.y += delta * 0.5
