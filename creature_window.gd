class_name CreatureWindow
extends Node
## Окно существа: характеристики питомца и его умения (изучение за очки умений JP, ячейки умений).
## Открывается кнопкой «Подробнее» в окне «Питомцы» и кнопкой «Существо» у панели питомца в HUD (клавиша C).
## Вкладки (кнопки сверху, не прокручиваются):
## «Существо» — 3D-превью модели, вид, роль, редкость, стадия, уровень и опыт, HP/MP, JP, 7 характеристик
## и боевые показатели (PetStats); «Умения» — компактное древо (SkillTree: ярусы по уровню питомца,
## линии пререквизитов) и карточка выбранного умения: тип, уровень, эффект сейчас и на следующем уровне,
## требования, кнопка «+ N JP» (изучить), «В ячейку 1–3» / «В ячейку ауры 1–2» и «Убрать».
## Над древом — 5 ячеек умений: 3 «Авто» (активные: ИИ питомца применяет только их, по порядку) и 2 «Ауры»
## (переключаемые: включены, пока стоят в ячейке). Касание занятой ячейки убирает умение, пустой — ставит туда
## выбранное в древе изученное умение подходящего типа. Пассивные действуют всегда, ячеек не занимают.
## Значки: res://assets/icons/pets/<вид>/<id умения>.png (нет файла — кружок с буквой).
## Живёт в PetManager (pets.creature). Данные — запись Game.pets[index]; призванный питомец пересчитывается сразу.

## Размеры — для «Среднего» размера интерфейса (умножаются на UiScale.k(); было 1180×660, древо 660×420).
const WINDOW_SIZE := Vector2(1060, 600)
## Ширина переносимого текста по умолчанию.
const TEXT_W := 700.0
## Древо умений и карточка рядом (помещаются в окно без прокрутки вместе с рядом ячеек).
const TREE_SIZE := Vector2(600, 350)
## Ячейка умения (квадрат) над древом.
const SLOT_PX := 46.0
const CARD_W := 380.0
const PREVIEW_SIZE := Vector2(230, 230)
const GOLD := Color(1.0, 0.85, 0.45)
const MUTED := Color(0.78, 0.8, 0.9)
const GOOD := Color(0.55, 1.0, 0.6)
const BAD := Color(1.0, 0.62, 0.45)

var main: Node
var pets: PetManager
## Индекс питомца в Game.pets (-1 — окно не открыто) и вкладка: "stats" | "skills".
var index := -1
var tab := "stats"
## Кнопки открытого окна: "tab_stats", "tab_skills", "back", "skill_<id>" (значки древа), ячейки "slot_auto_<0..2>",
## "slot_aura_<0..1>"; карточка выбранного умения: "learn_<id>", "toslot_<id>_<номер>" (в ячейку), "unslot_<id>"
## (убрать из ячейки), "toggle_<id>" (включить ауру из ячейки, выключенную нехваткой MP).
var buttons: Dictionary = {}
## Выбранное в древе умение и само древо (на вкладке «Умения»).
var selected := ""
var tree: SkillTree = null

var _body: VBoxContainer = null
var _scroll: ScrollContainer = null
var _pivot: Node3D = null
var _holder: Node3D = null
var _species := ""
var _anim_t := 0.0
var _scroll_restore := -1
var _scroll_frames := 0


func setup(m: Node, pm: PetManager) -> void:
	main = m
	pets = pm


## Открывает окно существа для питомца i на вкладке which ("" — та же, что была). true — открыто.
func open(i: int, which: String = "") -> bool:
	if i < 0 or i >= Game.pets.size():
		return false
	if i != index:
		selected = ""
	index = i
	if which != "":
		tab = which
	buttons.clear()
	tree = null
	_pivot = null
	_holder = null
	var rec: Dictionary = Game.pets[i]
	PetSkills.ensure_record(rec)
	_species = String(rec.get("species", "boar"))
	var body: VBoxContainer = main.hud.create_window("Существо: %s" % String(rec.get("name", "Питомец")), WINDOW_SIZE)
	_body = body
	_scroll = body.get_parent() as ScrollContainer
	_add_tabs(body)
	if tab == "skills":
		_build_skills(body, rec)
	else:
		_build_stats(body, rec)
	return true


## Окно открыто и принадлежит этому модулю.
func is_open() -> bool:
	if not is_instance_valid(_body):
		return false
	var n: Node = _body
	while n != null:
		if n.is_queued_for_deletion():
			return false
		n = n.get_parent()
	return main.hud.is_window_open()


## Перестраивает открытое окно (после изучения умения и т. п.), сохраняя прокрутку.
func refresh() -> void:
	if not is_open():
		return
	var sv := _scroll.scroll_vertical if is_instance_valid(_scroll) else 0
	if open(index):
		_scroll_restore = sv
		_scroll_frames = 2


func _process(delta: float) -> void:
	if _scroll_restore >= 0:
		_scroll_frames -= 1
		if _scroll_frames <= 0:
			if is_instance_valid(_scroll):
				_scroll.scroll_vertical = _scroll_restore
			_scroll_restore = -1
	if _pivot == null or not is_instance_valid(_pivot) or not is_instance_valid(_holder):
		_pivot = null
		return
	_anim_t += delta
	_pivot.rotation.y += delta * 0.35
	var ca := CreatureModels.asset_of(_holder)
	if ca != null:
		ca.update(delta, 0.0)
	else:
		CreatureModels.animate(_holder, _species, _anim_t, 0.0)


## Призванный питомец с этой записью (или null).
func _live_pet(rec: Dictionary) -> Pet:
	if pets == null or not is_instance_valid(pets.active_pet) or pets.active_pet.is_down:
		return null
	if is_same(pets.active_pet.record, rec):
		return pets.active_pet
	return null


# ---------- Вкладки ----------

func _add_tabs(body: VBoxContainer) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", int(UiScale.px(UiScale.GAP)))
	# Над прокруткой: вкладки всегда на виду
	var root: Node = null
	if body.get_parent() != null:
		root = body.get_parent().get_parent()
	if root is VBoxContainer:
		root.add_child(bar)
		root.move_child(bar, 1)
	else:
		body.add_child(bar)
	_tab_button(bar, "tab_stats", "Существо", tab == "stats", _on_tab.bind("stats"))
	_tab_button(bar, "tab_skills", "Умения", tab == "skills", _on_tab.bind("skills"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	_tab_button(bar, "back", "К питомцам", false, _on_back)


func _tab_button(bar: HBoxContainer, key: String, text: String, active: bool, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(UiScale.px(130), UiScale.px(UiScale.TAB_H))
	b.toggle_mode = key != "back"
	b.button_pressed = active
	b.pressed.connect(cb)
	bar.add_child(b)
	buttons[key] = b


func _on_tab(which: String) -> void:
	open(index, which)


func _on_back() -> void:
	pets.open_window()


# ---------- Вкладка «Существо» ----------

func _build_stats(body: VBoxContainer, rec: Dictionary) -> void:
	var sp := _species
	var lvl := int(rec.get("level", 1))
	var pet := _live_pet(rec)
	var st: Dictionary = pet.stats if pet != null else PetData.stats_for(sp, lvl, rec["skills"], rec["toggles"])
	var dead := bool(rec.get("dead", false))
	var mhp := int(st["max_hp"])
	var mmp := int(st["max_mp"])
	var hp: int = pet.hp if pet != null else int(rec.get("hp", -1))
	if hp < 0 or hp > mhp:
		hp = mhp
	if dead:
		hp = 0
	var mp: int = pet.mp if pet != null else int(rec.get("mp", -1))
	if mp < 0 or mp > mmp:
		mp = mmp

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", int(UiScale.px(16)))
	body.add_child(top)
	top.add_child(_build_preview(rec))

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", int(UiScale.px(4)))
	top.add_child(info)
	var nm := _label(String(rec.get("name", "Питомец")), UiScale.FONT_NAME, GOLD)
	info.add_child(nm)
	info.add_child(_label("%s · %s · %s" % [String(MobData.get_type(sp)["name"]), PetData.role_name(sp),
		MobData.rarity_name(sp)], UiScale.FONT_HEAD, MUTED))
	var stage := PetData.stage_for(lvl)
	var stage_line := "Стадия эволюции %d из 3: %s" % [stage + 1, PetData.stage_name(sp, lvl)]
	if stage < PetData.STAGE_LEVELS.size() - 1:
		stage_line += " (следующая — с ур. %d)" % int(PetData.STAGE_LEVELS[stage + 1])
	info.add_child(_label(stage_line, UiScale.FONT_HEAD, Color.WHITE))
	var status := "погиб — воскресите свитком" if dead else ("призван" if pet != null else "отдыхает")
	info.add_child(_label("Уровень %d / %d  ·  %s" % [lvl, PetData.MAX_LEVEL, status], UiScale.FONT_HEAD,
		BAD if dead else Color.WHITE))
	if lvl < PetData.MAX_LEVEL:
		var need := PetData.xp_to_next(lvl)
		info.add_child(_bar_line("Опыт", int(rec.get("xp", 0)), need, Color(0.95, 0.82, 0.3)))
	info.add_child(_bar_line("HP", hp, mhp, Color(0.35, 0.85, 0.4)))
	info.add_child(_bar_line("MP", mp, mmp, Color(0.4, 0.55, 1.0)))
	var jp_row := HBoxContainer.new()
	jp_row.add_theme_constant_override("separation", int(UiScale.px(12)))
	info.add_child(jp_row)
	var jp := _label("Очки умений: %d JP" % int(rec.get("jp", 0)), UiScale.FONT_HEAD, GOLD)
	jp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	jp_row.add_child(jp)
	var to_sk := Button.new()
	to_sk.text = "Открыть умения"
	to_sk.focus_mode = Control.FOCUS_NONE
	to_sk.custom_minimum_size = Vector2(0, UiScale.button_h())
	to_sk.pressed.connect(_on_tab.bind("skills"))
	jp_row.add_child(to_sk)
	buttons["to_skills"] = to_sk
	info.add_child(_label("JP копятся за победы питомца: %d за каждый уровень опыта." % PetSkills.JP_PER_LEVEL,
		UiScale.FONT_BODY, MUTED))

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", int(UiScale.px(32)))
	body.add_child(cols)
	# 7 характеристик
	var left := VBoxContainer.new()
	cols.add_child(left)
	left.add_child(_label("Характеристики", UiScale.FONT_HEAD, GOLD))
	var g1 := GridContainer.new()
	g1.columns = 2
	g1.add_theme_constant_override("h_separation", int(UiScale.px(18)))
	g1.add_theme_constant_override("v_separation", 2)
	left.add_child(g1)
	var stats: Dictionary = st["stats"]
	var main_stat := "int" if PetStats.is_magic(sp) else "str"
	for k in PetStats.STATS:
		var key := String(k)
		var mark := " ★" if key == main_stat or (PetData.role(sp) == "healer" and key == "wis") else ""
		g1.add_child(_label(String(PetStats.STAT_NAMES[key]) + mark, UiScale.FONT_TEXT, MUTED))
		g1.add_child(_label(str(int(stats[key])), UiScale.FONT_TEXT, Color.WHITE))
	# Боевые показатели (две колонки пар)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	right.add_child(_label("Боевые показатели", UiScale.FONT_HEAD, GOLD))
	var g2 := GridContainer.new()
	g2.columns = 4
	g2.add_theme_constant_override("h_separation", int(UiScale.px(18)))
	g2.add_theme_constant_override("v_separation", 2)
	right.add_child(g2)
	var main_key := "matk" if PetStats.is_magic(sp) else "patk"
	for pair in PetStats.DERIVED_NAMES:
		var key := String(pair[0])
		var title := String(pair[1]) + (" ★" if key == main_key else "")
		g2.add_child(_label(title, UiScale.FONT_TEXT, MUTED))
		g2.add_child(_label(_derived_text(key, st), UiScale.FONT_TEXT, Color.WHITE))
	body.add_child(_label("★ — главная характеристика и атака роли: от неё считается урон умений%s." %
		(", лечение — от Мудрости" if PetData.role(sp) == "healer" else ""), UiScale.FONT_BODY, MUTED))


func _derived_text(key: String, st: Dictionary) -> String:
	match key:
		"eva", "crit":
			return "%.1f%%" % float(st[key])
		"aspd":
			return "%d%%" % int(st[key])
		"hp_regen", "mp_regen":
			return "%.1f/с" % float(st[key])
	return str(int(st[key]))


## Полоска «HP 120 / 300».
func _bar_line(title: String, v: int, mx: int, col: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiScale.px(10)))
	var l := _label(title, UiScale.FONT_TEXT, MUTED)
	l.custom_minimum_size = Vector2(UiScale.px(56), 0)
	row.add_child(l)
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = UiScale.v2(280, 14)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.max_value = maxi(1, mx)
	b.value = clampi(v, 0, maxi(1, mx))
	var r := int(UiScale.px(7))
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(r)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.06, 0.14, 0.8)
	bg.border_color = Color(1.0, 0.95, 0.82, 0.7)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(r)
	b.add_theme_stylebox_override("fill", fill)
	b.add_theme_stylebox_override("background", bg)
	row.add_child(b)
	row.add_child(_label("%d / %d" % [v, mx], UiScale.FONT_TEXT, Color.WHITE))
	return row


## 3D-превью: модель питомца на подиуме (своя сцена в SubViewport), медленно вращается.
func _build_preview(rec: Dictionary) -> Control:
	var sp := _species
	var lvl := int(rec.get("level", 1))
	var svc := SubViewportContainer.new()
	svc.stretch = true
	var psz := UiScale.v2(PREVIEW_SIZE.x, PREVIEW_SIZE.y)
	svc.custom_minimum_size = psz
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.size = Vector2i(psz)
	svc.add_child(vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.11, 0.13, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.76)
	env.ambient_light_energy = 0.6
	var sc := PetData.stage_scale(sp, lvl)
	var stage := PetData.stage_for(lvl)
	# Своя модель стадии эволюции, если есть (CreatureAsset.model_for)
	var mid := CreatureAsset.model_for(sp, stage)
	var h := CreatureModels.height(mid, sc)
	var r := CreatureModels.ring_radius(mid, sc)
	var size := maxf(h, r * 2.2)
	var cam := Camera3D.new()
	cam.environment = env
	cam.fov = 34.0
	var look := Vector3(0, h * 0.45, 0)
	cam.transform = Transform3D(Basis.IDENTITY, Vector3(0, h * 0.75 + 0.3, size * 2.1 + 0.9)).looking_at(look, Vector3.UP)
	vp.add_child(cam)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -35, 0)
	key.light_energy = 1.15
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 155, 0)
	rim.light_color = Color(0.7, 0.8, 1.0)
	rim.light_energy = 0.6
	vp.add_child(rim)

	var podium := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = maxf(0.6, r * 1.6)
	pm.bottom_radius = pm.top_radius + 0.08
	pm.height = 0.08
	pm.radial_segments = 32
	podium.mesh = pm
	podium.position.y = -0.04
	podium.set_meta("no_outline", true)
	podium.material_override = Util.mat(Color(0.24, 0.26, 0.36))
	vp.add_child(podium)

	_pivot = Node3D.new()
	# Модель смотрит в −Z, камера на +Z: разворот лицом к камере, вполоборота
	_pivot.rotation.y = PI - 0.6
	vp.add_child(_pivot)
	_holder = Node3D.new()
	_pivot.add_child(_holder)
	CreatureModels.build(_holder, sp, PetData.stage_color(sp, lvl), sc, PetData.asset_tint(sp, lvl), stage)
	CreatureModels.decorate_pet(_holder, sp, sc, stage, PetData.role(sp))
	return svc


# ---------- Вкладка «Умения» ----------

## Древо умений (SkillTree) слева и карточка выбранного умения справа.
func _build_skills(body: VBoxContainer, rec: Dictionary) -> void:
	var sp := _species
	var lvl := int(rec.get("level", 1))
	var pet := _live_pet(rec)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", int(UiScale.px(20)))
	body.add_child(head)
	head.add_child(_label("Очки умений: %d JP" % int(rec.get("jp", 0)), UiScale.FONT_HEAD, GOLD))
	var st := PetData.stage_for(lvl)
	head.add_child(_label("Ур. %d, стадия %d" % [lvl, st + 1], UiScale.FONT_TEXT, Color.WHITE))
	if pet != null:
		var up := pet.toggle_upkeep()
		head.add_child(_label("MP %d / %d%s" % [pet.mp, pet.max_mp,
			("  (поддержка −%d / 10 с)" % up) if up > 0 else ""], UiScale.FONT_TEXT, Color(0.6, 0.75, 1.0)))
	var ids := PetSkills.list_for(sp)
	if selected == "" or not ids.has(selected):
		selected = _default_pick(rec, ids)
	body.add_child(_slots_row(rec))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiScale.px(12)))
	body.add_child(row)
	var items: Array = []
	for id in ids:
		items.append(_tree_item(rec, String(id), pet))
	tree = SkillTree.new()
	tree.setup(items, UiScale.v2(TREE_SIZE.x, TREE_SIZE.y), selected)
	tree.picked.connect(_on_pick)
	row.add_child(tree)
	for id in tree.icons:
		buttons["skill_" + String(id)] = tree.icons[id]
	row.add_child(_card(rec, selected, pet))


## Ряд ячеек: «Авто» 1–3, «Ауры» 1–2 и подсказка.
func _slots_row(rec: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiScale.px(6)))
	for kind in ["auto", "aura"]:
		var k := String(kind)
		var title := _label("Авто:" if k == "auto" else "   Ауры:", UiScale.FONT_HEAD, GOLD)
		title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(title)
		var arr := PetSkills.slots_of(rec, k)
		for i in arr.size():
			row.add_child(_slot_cell(rec, k, i, String(arr[i])))
	var hint := _label("ИИ применяет умения из ячеек «Авто» по порядку, ауры в ячейках включены. Касание ячейки — убрать; "
		+ "пустой — поставить выбранное умение.", UiScale.FONT_SMALL, MUTED, UiScale.px(470))
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(hint)
	return row


## Ячейка kind ("auto" | "aura") номер i: значок умения id (пустая — номер). Аура, выключенная нехваткой MP, — бледнее.
func _slot_cell(rec: Dictionary, kind: String, i: int, id: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	var sz := UiScale.px(SLOT_PX)
	b.custom_minimum_size = Vector2(sz, sz)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.22, 0.95)
	sb.border_color = Color(0.45, 0.75, 1.0, 0.85) if kind == "auto" else Color(0.55, 0.95, 0.6, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(UiScale.px(8)))
	for st in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(st, sb)
	if id != "":
		var ic := IconView.new()
		var inset := UiScale.px(4)
		ic.position = Vector2(inset, inset)
		ic.size = Vector2(sz - inset * 2.0, sz - inset * 2.0)
		ic.set_spec(IconView.pet_skill(_species, id))
		if kind == "aura" and not PetSkills.toggle_on(rec, id):
			ic.modulate = Color(1, 1, 1, 0.45)
		b.add_child(ic)
		b.tooltip_text = String(PetSkills.get_skill(id).get("name", id))
	else:
		b.text = str(i + 1)
		b.add_theme_color_override("font_color", Color(0.55, 0.6, 0.75))
		b.add_theme_font_size_override("font_size", UiScale.fs(UiScale.FONT_TEXT))
	b.pressed.connect(_on_slot.bind(kind, i))
	buttons["slot_%s_%d" % [kind, i]] = b
	return b


## Первое умение, которое можно изучить, иначе первое в списке.
func _default_pick(rec: Dictionary, ids: Array) -> String:
	for id in ids:
		if PetSkills.learn_block(rec, String(id)) == "":
			return String(id)
	return String(ids[0]) if not ids.is_empty() else ""


## Значок древа: ярус — уровень питомца для 1-го уровня умения, линия — от пререквизита.
func _tree_item(rec: Dictionary, id: String, pet: Pet) -> Dictionary:
	var sk := PetSkills.get_skill(id)
	var cur := PetSkills.skill_level(rec, id)
	var pre := ""
	if sk.has("pre"):
		pre = String((sk["pre"] as Array)[0])
	return {
		"id": id, "name": String(sk["name"]), "glyph": String(sk.get("glyph", "?")), "color": sk["color"],
		"kind": String(sk["kind"]), "level": cur, "max": PetSkills.max_level(id),
		"row": PetSkills.level_needed(id, 1), "pre": pre, "learned": cur > 0,
		"can": PetSkills.learn_block(rec, id) == "", "unfit": false,
		"on": PetSkills.toggle_on(rec, id) if pet == null else bool(pet.toggles.get(id, false)),
		"icon": icon_path(_species, id),
	}


## Значок умения питомца: res://assets/icons/pets/<вид>/<id умения>.png (у каждого вида свои картинки).
static func icon_path(species: String, id: String) -> String:
	return "res://assets/icons/pets/%s/%s.png" % [species, id]


## Карточка умения: название, тип, уровень, эффект сейчас и на следующем, требования, «+ JP», «Вкл/Выкл».
func _card(rec: Dictionary, id: String, pet: Pet) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = UiScale.v2(CARD_W, TREE_SIZE.y)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.15, 0.28, 0.95)
	sb.border_color = Color(1.0, 0.85, 0.5, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(UiScale.px(UiScale.BTN_RADIUS)))
	sb.set_content_margin_all(UiScale.px(10))
	panel.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(UiScale.px(3)))
	panel.add_child(box)
	# Ширина текста карточки (с масштабом)
	var w := UiScale.px(CARD_W - 24.0)
	var sk := PetSkills.get_skill(id)
	if sk.is_empty():
		box.add_child(_label("Выберите умение в древе", UiScale.FONT_TEXT, MUTED, w))
		return panel
	var lvl := int(rec.get("level", 1))
	var cur := PetSkills.skill_level(rec, id)
	var mx := PetSkills.max_level(id)
	var cap := PetSkills.cap_for(id, lvl)
	var block := PetSkills.learn_block(rec, id)
	var kind := String(sk["kind"])
	box.add_child(_label(String(sk["name"]), UiScale.FONT_NAME, GOLD, w))
	var lvl_text := "ур. %d/%d" % [cur, mx]
	if cap < mx:
		lvl_text += " (сейчас до %d)" % cap
	var meta := "%s · %s · стадия %d+" % [PetSkills.kind_name(id), lvl_text, PetSkills.first_stage(id) + 1]
	var on := kind == "toggle" and PetSkills.toggle_on(rec, id)
	var slot := PetSkills.slot_of(rec, id)
	if slot >= 0:
		meta += " · %s %d" % ["ячейка «Авто»" if kind == "active" else "ячейка ауры", slot + 1]
	if on:
		meta += " · ВКЛЮЧЕНО"
	box.add_child(_label(meta, UiScale.FONT_BODY, GOOD if on else MUTED, w))
	box.add_child(_label(String(sk["desc"]), UiScale.FONT_BODY, MUTED, w))
	if cur > 0:
		box.add_child(_label("Сейчас: " + PetSkills.effect_text(id, cur), UiScale.FONT_BODY, Color.WHITE, w))
	if cur < mx:
		box.add_child(_label("Ур. %d: %s" % [cur + 1, PetSkills.effect_text(id, cur + 1)], UiScale.FONT_BODY,
			Color(0.85, 0.88, 1.0), w))
		var req := "Нужно: " + PetSkills.requirement_text(id, cur + 1)
		if block == "":
			box.add_child(_label(req + " — можно изучить", UiScale.FONT_BODY, GOOD, w))
		else:
			box.add_child(_label(req + " — " + block, UiScale.FONT_BODY, BAD, w))
	if kind == "active" and pet != null and cur > 0:
		var left := float(pet.skill_cds.get(id, 0.0))
		if left > 0.0:
			box.add_child(_label("Перезарядка: %.0f с" % ceilf(left), UiScale.FONT_BODY, MUTED))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", int(UiScale.px(UiScale.GAP)))
	box.add_child(btns)
	if cur < mx:
		var plus := Button.new()
		plus.text = "+ %d JP" % int(sk["jp"])
		plus.focus_mode = Control.FOCUS_NONE
		plus.custom_minimum_size = Vector2(UiScale.px(120), UiScale.button_h())
		plus.disabled = block != ""
		plus.pressed.connect(_on_learn.bind(id))
		btns.add_child(plus)
		buttons["learn_" + id] = plus
	# Аура в ячейке, выключенная нехваткой MP, — включить сейчас
	if kind == "toggle" and cur > 0 and slot >= 0 and not on:
		var tb := Button.new()
		tb.text = "Вкл"
		tb.focus_mode = Control.FOCUS_NONE
		tb.custom_minimum_size = Vector2(UiScale.px(80), UiScale.button_h())
		tb.pressed.connect(_on_toggle.bind(id))
		btns.add_child(tb)
		buttons["toggle_" + id] = tb
	# Ячейки: «В ячейку 1–3» (активные) / «В ячейку ауры 1–2» (переключаемые), «Убрать»
	var sk_kind := PetSkills.slot_kind(id)
	if sk_kind != "" and cur > 0:
		var srow := HBoxContainer.new()
		srow.add_theme_constant_override("separation", int(UiScale.px(4)))
		box.add_child(srow)
		var st := _label("В ячейку:" if sk_kind == "auto" else "В ячейку ауры:", UiScale.FONT_BODY, MUTED)
		st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		srow.add_child(st)
		var n: int = PetSkills.AUTO_SLOTS if sk_kind == "auto" else PetSkills.AURA_SLOTS
		for i in n:
			var sbtn := Button.new()
			sbtn.text = str(i + 1)
			sbtn.focus_mode = Control.FOCUS_NONE
			sbtn.custom_minimum_size = Vector2(UiScale.px(44), UiScale.button_h())
			sbtn.disabled = slot == i
			sbtn.pressed.connect(_on_to_slot.bind(id, i))
			srow.add_child(sbtn)
			buttons["toslot_%s_%d" % [id, i]] = sbtn
		if slot >= 0:
			var ub := Button.new()
			ub.text = "Убрать"
			ub.focus_mode = Control.FOCUS_NONE
			ub.custom_minimum_size = Vector2(0, UiScale.button_h())
			ub.pressed.connect(_on_unslot.bind(id))
			srow.add_child(ub)
			buttons["unslot_" + id] = ub
	return panel


func _on_pick(id: String) -> void:
	selected = id
	refresh()


func _on_learn(id: String) -> void:
	if index < 0 or index >= Game.pets.size():
		return
	var rec: Dictionary = Game.pets[index]
	var why := PetSkills.learn_block(rec, id)
	var nm := String(PetSkills.get_skill(id).get("name", id))
	if why != "" or not PetSkills.learn(rec, id):
		_msg("«%s»: %s" % [nm, why])
		refresh()
		return
	var pet := _live_pet(rec)
	if pet != null:
		pet.refresh_skills()
	_msg("«%s» — ур. %d" % [nm, PetSkills.skill_level(rec, id)])
	Game.changed.emit()
	refresh()


## Включить или выключить переключаемое умение (включение ставит его в свободную ячейку ауры, выключение — убирает).
func _on_toggle(id: String) -> void:
	if index < 0 or index >= Game.pets.size():
		return
	var rec: Dictionary = Game.pets[index]
	var nm := String(PetSkills.get_skill(id).get("name", id))
	var on := not PetSkills.toggle_on(rec, id)
	var pet := _live_pet(rec)
	if pet != null:
		var err := pet.set_toggle(id, on)
		if err != "":
			_msg("«%s»: %s" % [nm, err])
			refresh()
			return
	else:
		if PetSkills.skill_level(rec, id) <= 0:
			return
		if on:
			var idx := PetSkills.slot_of(rec, id)
			if idx < 0:
				idx = PetSkills.free_slot(rec, "aura")
			if idx < 0:
				_msg("«%s»: обе ячейки аур заняты — сначала уберите умение из ячейки" % nm)
				refresh()
				return
			PetSkills.assign_slot(rec, id, idx)
			(rec["toggles"] as Dictionary)[id] = true
		else:
			var at := PetSkills.slot_of(rec, id)
			if at >= 0:
				PetSkills.clear_slot(rec, "aura", at)
	if on:
		_msg("«%s» включено%s" % [nm, "" if pet != null else " (заработает, когда питомец будет призван)"])
	else:
		_msg("«%s» выключено" % nm)
	Game.changed.emit()
	refresh()


## Поставить умение id в ячейку i своего типа (у призванного питомца аура сразу включается и тратит MP).
func _on_to_slot(id: String, i: int) -> void:
	if index < 0 or index >= Game.pets.size():
		return
	var rec: Dictionary = Game.pets[index]
	var nm := String(PetSkills.get_skill(id).get("name", id))
	var kind := PetSkills.slot_kind(id)
	var pet := _live_pet(rec)
	var err := ""
	if pet != null:
		err = pet.assign_slot(id, i)
	else:
		err = PetSkills.assign_slot(rec, id, i)
		if err == "" and kind == "aura":
			(rec["toggles"] as Dictionary)[id] = true
	if err != "" and PetSkills.slot_of(rec, id) != i:
		_msg("«%s»: %s" % [nm, err])
	elif err != "":
		_msg("«%s» — в ячейке ауры %d. %s" % [nm, i + 1, err])
	else:
		_msg("«%s» — в ячейке %s%d" % [nm, "«Авто» " if kind == "auto" else "ауры ", i + 1])
	Game.changed.emit()
	refresh()


## Убрать умение id из его ячейки (аура выключается).
func _on_unslot(id: String) -> void:
	if index < 0 or index >= Game.pets.size():
		return
	var rec: Dictionary = Game.pets[index]
	var at := PetSkills.slot_of(rec, id)
	if at >= 0:
		_clear_slot(rec, PetSkills.slot_kind(id), at)
	refresh()


## Касание ячейки: занятая — убрать умение; пустая — поставить выбранное в древе изученное умение её типа.
func _on_slot(kind: String, i: int) -> void:
	if index < 0 or index >= Game.pets.size():
		return
	var rec: Dictionary = Game.pets[index]
	var arr := PetSkills.slots_of(rec, kind)
	if i < 0 or i >= arr.size():
		return
	if String(arr[i]) != "":
		_clear_slot(rec, kind, i)
		refresh()
		return
	if selected != "" and PetSkills.slot_kind(selected) == kind and PetSkills.skill_level(rec, selected) > 0:
		_on_to_slot(selected, i)
		return
	_msg("Выберите в древе изученное %s и нажмите «В ячейку%s»" % [
		"активное умение" if kind == "auto" else "переключаемое умение (узы, вызов)", "" if kind == "auto" else " ауры"])


func _clear_slot(rec: Dictionary, kind: String, i: int) -> void:
	var pet := _live_pet(rec)
	var id: String = pet.clear_slot(kind, i) if pet != null else PetSkills.clear_slot(rec, kind, i)
	if id == "":
		return
	var nm := String(PetSkills.get_skill(id).get("name", id))
	_msg("«%s» убрано из ячейки%s" % [nm, " и выключено" if kind == "aura" else ""])
	Game.changed.emit()


## Подпись; font_size — для «Среднего» размера интерфейса (UiScale.FONT_*); wrap_w > 0 — перенос строк
## по этой ширине (уже с масштабом).
func _label(text: String, font_size: int, col: Color, wrap_w: float = 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", UiScale.fs(font_size))
	l.add_theme_color_override("font_color", col)
	if wrap_w > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(wrap_w, 0)
	return l


func _msg(t: String) -> void:
	main.hud.show_message(t)
