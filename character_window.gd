class_name CharacterWindow
extends Node
## Окно героя (кнопка «Герой» в HUD, клавиша K). Вкладки сверху (не прокручиваются):
## «Герой» — 3D-превью с оружием в руках, уровень и опыт, HP/MP, очки умений, 7 характеристик (HeroStats, как
## у питомцев) и боевые показатели (HP, MP, физ./маг. атака и защита, точность, уклонение, крит, скорость атаки и каста,
## восстановление HP/MP, блок, дальность, бег — с оружием и умениями), выбор оружия из сумки (подходящее профессии,
## щит — во вторую руку, «Во 2-ю руку» — второй такой же клинок или топор, «Снять щит» / «Освободить 2-ю руку»);
## древо умений — вкладки профессии (у Наёмника «Общие» / «Мечи и кинжалы» / «Арбалет», у других — JobSkills.TABS);
## у Бродяги одна вкладка «Умения» с подсказкой: умения появятся после выбора профессии на 10 уровне.
## Древо — SkillTree (ярусы по уровню героя, линии пререквизитов), справа карточка выбранного умения:
## тип, оружие, уровень, эффект сейчас и на следующем, требования, «+ N JP», у переключаемых «Вкл/Выкл»,
## у активных и переключаемых — «На кнопку 1…4» (кнопки умений в HUD).
## Значки умений героя: res://assets/icons/skills/<id>.png (нет файла — кружок с буквой).
## Живёт в main (main.hero_window). Данные — Game.hero, Game.weapon; игрок пересчитывается сразу.

## Размеры — для «Среднего» размера интерфейса (умножаются на UiScale.k(); было 1180×660, древо 660×430).
const WINDOW_SIZE := Vector2(1060, 600)
const TREE_SIZE := Vector2(600, 410)
const CARD_W := 380.0
const PREVIEW_SIZE := Vector2(200, 240)
const GOLD := Color(1.0, 0.85, 0.45)
const MUTED := Color(0.78, 0.8, 0.9)
const GOOD := Color(0.55, 1.0, 0.6)
const BAD := Color(1.0, 0.62, 0.45)

var main: Node
## Вкладка: "hero" или id вкладки древа ("common", "blades", "crossbow").
var tab := "hero"
## Выбранное в древе умение и древо открытой вкладки.
var selected := ""
var tree: SkillTree = null
## Кнопки открытого окна: "tab_<вкладка>", "weapon_<id предмета>", "to_skills", "skill_<id>" (значки),
## "learn_<id>", "toggle_<id>", "slot_<1..4>" (карточка выбранного умения).
var buttons: Dictionary = {}

var _body: VBoxContainer = null
var _pivot: Node3D = null


func setup(m: Node) -> void:
	main = m


## Открыть окно на вкладке which ("" — прежняя). true — открыто.
func open(which: String = "") -> bool:
	if which != "":
		tab = which
	if tab != "hero" and not _tab_ids().has(tab):
		tab = "hero"
	buttons.clear()
	tree = null
	_pivot = null
	var body: VBoxContainer = main.hud.create_window("Герой: %s · %s" % [Game.char_name, ClassData.job_name(Game.class_id)],
		WINDOW_SIZE)
	_body = body
	_add_tabs(body)
	if tab == "hero":
		_build_hero(body)
	elif tab == "wanderer":
		_build_wanderer(body)
	else:
		_build_skills(body)
	return true


func is_open() -> bool:
	if not is_instance_valid(_body):
		return false
	var n: Node = _body
	while n != null:
		if n.is_queued_for_deletion():
			return false
		n = n.get_parent()
	return main.hud.is_window_open()


## Перестроить открытое окно (после изучения, смены оружия и т. п.).
func refresh() -> void:
	if is_open():
		open()


func _process(delta: float) -> void:
	if _pivot != null and is_instance_valid(_pivot):
		_pivot.rotation.y += delta * 0.3


func _player() -> Player:
	return main.player


func _tab_ids() -> Array:
	var res: Array = []
	for t in _tabs():
		res.append(String(t[0]))
	return res


## Вкладки древа (у Бродяги — одна «Умения» с подсказкой).
func _tabs() -> Array:
	if ClassData.is_wanderer(Game.class_id):
		return [["wanderer", "Умения"]]
	return HeroSkills.tabs_for(Game.class_id)


# ---------- Вкладки ----------

func _add_tabs(body: VBoxContainer) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", int(UiScale.px(UiScale.GAP)))
	var root: Node = null
	if body.get_parent() != null:
		root = body.get_parent().get_parent()
	if root is VBoxContainer:
		root.add_child(bar)
		root.move_child(bar, 1)
	else:
		body.add_child(bar)
	# Вкладки — значок и подпись (UiIcons: menu_hero — «Герой», tab_skills — древа умений)
	_tab_button(bar, "hero", "Герой", "menu_hero")
	for t in _tabs():
		_tab_button(bar, String(t[0]), String(t[1]), "tab_skills")


func _tab_button(bar: HBoxContainer, id: String, text: String, icon_id: String = "") -> void:
	var b := Button.new()
	b.text = text
	if icon_id != "":
		UiIcons.add_icon(b, icon_id)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(UiScale.px(120), UiScale.px(UiScale.TAB_H))
	b.toggle_mode = true
	b.button_pressed = tab == id
	b.pressed.connect(_on_tab.bind(id))
	bar.add_child(b)
	buttons["tab_" + id] = b


func _on_tab(which: String) -> void:
	open(which)


# ---------- Вкладка «Герой» ----------

func _build_hero(body: VBoxContainer) -> void:
	var p := _player()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", int(UiScale.px(16)))
	body.add_child(top)
	top.add_child(_build_preview(p))

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", int(UiScale.px(3)))
	top.add_child(info)
	info.add_child(_label(Game.char_name, UiScale.FONT_NAME, GOLD))
	info.add_child(_label("%s · %s · %s" % [String(ClassData.race(Game.race_id)["name"]),
		ClassData.gender_name(Game.gender).to_lower(), ClassData.job_name(Game.class_id)], UiScale.FONT_TEXT, MUTED))
	info.add_child(_bar_line("Опыт", Game.xp, Game.xp_to_next(Game.level), Color(0.95, 0.82, 0.3),
		"Ур. %d" % Game.level))
	info.add_child(_bar_line("HP", p.hp, p.max_hp, Color(0.35, 0.85, 0.4)))
	if p.max_mp > 0:
		info.add_child(_bar_line("MP", p.mp, p.max_mp, Color(0.4, 0.55, 1.0)))
	var jp_row := HBoxContainer.new()
	jp_row.add_theme_constant_override("separation", int(UiScale.px(12)))
	info.add_child(jp_row)
	var jp := _label("Очки умений: %d JP" % int(Game.hero.get("jp", 0)), UiScale.FONT_HEAD, GOLD)
	jp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	jp_row.add_child(jp)
	var to_sk := Button.new()
	to_sk.text = "Открыть умения"
	to_sk.focus_mode = Control.FOCUS_NONE
	to_sk.custom_minimum_size = Vector2(0, UiScale.button_h())
	to_sk.pressed.connect(_on_tab.bind(String(_tabs()[0][0])))
	jp_row.add_child(to_sk)
	buttons["to_skills"] = to_sk
	info.add_child(_label("JP копятся за победы: %d за каждый уровень опыта." % HeroSkills.JP_PER_LEVEL, UiScale.FONT_BODY, MUTED))

	# 7 характеристик (как у питомцев): у героя со статами (Наёмник)
	if not p.hero_stats.is_empty():
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", int(UiScale.px(2)))
		top.add_child(col)
		col.add_child(_label("Характеристики", UiScale.FONT_HEAD, GOLD))
		var g1 := GridContainer.new()
		g1.columns = 2
		g1.add_theme_constant_override("h_separation", int(UiScale.px(14)))
		g1.add_theme_constant_override("v_separation", 0)
		col.add_child(g1)
		var st: Dictionary = p.hero_stats["stats"]
		var main_stat := String(HeroStats.MAIN_STAT.get(p.attack_kind, "str"))
		for k in Stats.STATS:
			var key := String(k)
			g1.add_child(_label(String(Stats.STAT_NAMES[key]) + (" ★" if key == main_stat else ""), UiScale.FONT_TEXT, MUTED))
			g1.add_child(_label(str(int(st[key])), UiScale.FONT_TEXT, Color.WHITE))

	# Боевые показатели (с оружием, умениями и усилениями; по три пары в ряд)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", int(UiScale.px(12)))
	body.add_child(head)
	head.add_child(_label("Боевые показатели", UiScale.FONT_HEAD, GOLD))
	if not p.hero_stats.is_empty():
		var note := _label("★ — от главной характеристики оружия: ближний бой — Сила, стрельба — Меткость, магия — Интеллект",
			UiScale.FONT_SMALL, MUTED)
		note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(note)
	var g := GridContainer.new()
	g.columns = 6
	g.add_theme_constant_override("h_separation", int(UiScale.px(14)))
	g.add_theme_constant_override("v_separation", 0)
	body.add_child(g)
	for r in _combat_rows(p):
		g.add_child(_label(String(r[0]), UiScale.FONT_TEXT, MUTED))
		g.add_child(_label(String(r[1]), UiScale.FONT_TEXT, Color.WHITE))

	# Оружие: основная рука, вторая рука (щит или второе такое же одноручное — пара)
	var wrow := HFlowContainer.new()
	wrow.add_theme_constant_override("h_separation", int(UiScale.px(UiScale.GAP)))
	wrow.add_theme_constant_override("v_separation", int(UiScale.px(4)))
	body.add_child(wrow)
	wrow.add_child(_label("Оружие:", UiScale.FONT_HEAD, GOLD))
	for id in Game.inventory.ids():
		var wid := String(id)
		if not ItemData.weapon_fits(wid, Game.class_id):
			continue
		var b := _weapon_button(wid, "%s\n%s" % [ItemData.item_name(wid), _weapon_line(wid)],
			wid == Game.weapon or (wid == Game.offhand and ItemData.is_shield(wid)))
		b.pressed.connect(_on_weapon.bind(wid))
		wrow.add_child(b)
		buttons["weapon_" + wid] = b
		# Второй такой же клинок во вторую руку (пара)
		if not ItemData.is_shield(wid) and ItemData.offhand_block(wid, Game.weapon, Game.class_id) == "":
			var b2 := _weapon_button(wid, "Во 2-ю руку\n%s" % ItemData.item_name(wid), wid == Game.offhand)
			b2.disabled = Game.offhand_block(wid) != "" and wid != Game.offhand
			b2.pressed.connect(_on_offhand.bind(wid))
			wrow.add_child(b2)
			buttons["offhand_" + wid] = b2
	if Game.offhand != "":
		var off := Button.new()
		off.text = "Снять щит" if Game.has_shield() else "Освободить 2-ю руку"
		off.focus_mode = Control.FOCUS_NONE
		off.custom_minimum_size = Vector2(0, UiScale.px(50))
		off.pressed.connect(_on_unshield)
		wrow.add_child(off)
		buttons["unequip_shield"] = off


func _weapon_button(_id: String, text: String, on: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, UiScale.px(50))
	b.add_theme_font_size_override("font_size", UiScale.fs(UiScale.FONT_SMALL))
	b.toggle_mode = true
	b.button_pressed = on
	return b


## Кратко об оружии на кнопке: «атака +4 · −5% · 2.6 м», у щита — «защита +3 · блок 10%».
func _weapon_line(id: String) -> String:
	var it := ItemData.get_item(id)
	var wb := ItemData.weapon_bonus(id)
	if ItemData.is_shield(id):
		return "защита +%d · блок %d%%" % [int(wb["def"]), roundi(float(wb["block"]) * 100.0)]
	var parts: PackedStringArray = []
	if int(wb["atk"]) > 0:
		parts.append("атака +%d" % int(wb["atk"]))
	if int(wb["matk"]) > 0:
		parts.append("маг. +%d" % int(wb["matk"]))
	if int(wb["aspd"]) != 0:
		parts.append("%s%d%%" % ["+" if int(wb["aspd"]) > 0 else "−", absi(int(wb["aspd"]))])
	if int(wb["cast"]) != 0:
		parts.append("каст +%d%%" % int(wb["cast"]))
	parts.append("%.1f м" % float(it.get("range", 2.0)))
	return " · ".join(parts)


func _on_offhand(id: String) -> void:
	var err: String = "" if id == Game.offhand else _player().equip(id, true)
	if err != "":
		_msg(err)
	refresh()


func _on_unshield() -> void:
	Game.unequip_shield()
	_player().refresh_skills()
	_player()._build_model()
	refresh()


## Строки боевых показателей: [название, значение]. У героя со статами — набор как в окне существа
## (HP, MP, атаки, защиты, точность, уклонение, крит, скорость атаки, восстановление) плюс дальность и бег.
func _combat_rows(p: Player) -> Array:
	var aps := 1.0 / maxf(p.attack_time, 0.05)
	var rows: Array = []
	var hs := p.hero_stats
	if hs.is_empty():
		rows.append(["Атака", str(p.cur_atk())])
		rows.append(["Защита", str(p.defense + p.aura_def)])
	else:
		rows.append(["Макс. HP", str(p.max_hp)])
		rows.append(["Макс. MP", str(p.max_mp)])
		rows.append(["Физ. атака ★", "%d (%s)" % [p.cur_atk(), _attack_text(p)]])
		rows.append(["Маг. атака", str(p.cur_matk())])
		rows.append(["Физ. защита", str(p.defense + p.aura_def)])
		rows.append(["Маг. защита", str(p.mdef)])
		rows.append(["Точность", str(p.accuracy)])
	rows.append(["Уклонение", "%.1f%%" % (p.cur_eva() * 100.0)])
	rows.append(["Шанс крита", "%.1f%%" % (p.cur_crit() * 100.0)])
	if hs.is_empty():
		rows.append(["Скорость атаки", "%.2f / с" % aps])
	else:
		rows.append(["Скорость атаки", "%d%% · %.2f уд./с" % [roundi(p.aspd * 100.0), aps]])
		rows.append(["Восст. HP", "%.1f/с" % (p.hp_regen + p.aura_regen)])
		rows.append(["Восст. MP", "%.1f/с" % p.mp_regen_rate(true)])
	if p.cast_speed != 0.0:
		rows.append(["Скорость каста", "+%d%% · %.2f с" % [roundi(p.cast_speed * 100.0), p.cast_time()]])
	if p.block > 0.0:
		rows.append(["Блок", "%.1f%%" % (p.block * 100.0)])
	rows.append(["Дальность", "%.1f м" % p.attack_range])
	rows.append(["Скорость бега", "%.1f м/с" % p.cur_speed()])
	if hs.is_empty():
		rows.append(["Атака", _attack_text(p)])
	return rows


func _attack_text(p: Player) -> String:
	match p.weapon_kind:
		"crossbow":
			return "болтами"
		"bow":
			return "стрелами"
		"daggers", "dual_swords":
			return "клинками"
		"dual_axes":
			return "двумя топорами"
		"":
			return ClassData.attack_name(p.attack_kind)
	return ItemData.weapon_kind_name(p.weapon_kind)


func _on_weapon(id: String) -> void:
	var err := _player().equip(id)
	if err != "":
		_msg(err)
	refresh()


## Полоска «HP 120 / 300».
func _bar_line(title: String, v: int, mx: int, col: Color, prefix: String = "") -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiScale.px(10)))
	var l := _label(prefix if prefix != "" else title, UiScale.FONT_TEXT, MUTED)
	l.custom_minimum_size = Vector2(UiScale.px(56), 0)
	row.add_child(l)
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = UiScale.v2(210, 14)
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
	row.add_child(_label("%s %d / %d" % [title, v, mx], UiScale.FONT_TEXT, Color.WHITE))
	return row


## 3D-превью: герой с надетым оружием на подиуме (своя сцена в SubViewport), медленно поворачивается.
func _build_preview(p: Player) -> Control:
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
	var cam := Camera3D.new()
	cam.environment = env
	cam.fov = 34.0
	cam.transform = Transform3D(Basis.IDENTITY, Vector3(0, 1.15, 3.9)).looking_at(Vector3(0, 0.9, 0), Vector3.UP)
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
	pm.top_radius = 0.75
	pm.bottom_radius = 0.83
	pm.height = 0.08
	pm.radial_segments = 32
	podium.mesh = pm
	podium.position.y = -0.04
	podium.set_meta("no_outline", true)
	podium.material_override = Util.mat(Color(0.24, 0.26, 0.36))
	vp.add_child(podium)
	_pivot = Node3D.new()
	# Модель смотрит в −Z, камера на +Z: лицом к камере, вполоборота
	_pivot.rotation.y = PI - 0.5
	vp.add_child(_pivot)
	var m := CharacterModel.new()
	m.name = "PreviewModel"
	m.setup(CharacterModel.spec_for(Game.race_id, Game.class_id, p.weapon_kind, Game.gender, p.has_shield,
		Game.weapon, Game.offhand))
	_pivot.add_child(m)
	return svc


# ---------- Вкладки древа ----------

## Бродяга: умений нет — подсказка и профессии расы с ключевыми умениями.
func _build_wanderer(body: VBoxContainer) -> void:
	body.add_child(_label(HeroSkills.WANDERER_NOTE + ".", UiScale.FONT_HEAD, GOLD))
	body.add_child(_label("Очки умений копятся уже сейчас: %d JP. С %d уровня Мудрец Альдерик (город, у ратуши) даст задание "
		% [int(Game.hero.get("jp", 0)), ClassData.JOB_LEVEL] + "на профессию. Чем позже выбор (до %d ур.), тем больше бонус сверх-эволюции: +%d JP за уровень."
		% [ClassData.OVER_LEVEL_CAP, ClassData.OVER_JP_PER_LEVEL], UiScale.FONT_TEXT, MUTED, UiScale.px(WINDOW_SIZE.x - 60.0)))
	for jid in ClassData.jobs_of(Game.race_id):
		var j := ClassData.cls(String(jid))
		var names: PackedStringArray = []
		for sid in j.get("key_skills", []):
			names.append(String(HeroSkills.get_skill(String(sid), String(jid)).get("name", sid)))
		var jc: Color = j["color"]
		body.add_child(_label("%s — %s" % [String(j["name"]), String(j["role"])], UiScale.FONT_HEAD, jc.lightened(0.35)))
		body.add_child(_label("Оружие: %s. Умения: %s." % [String(j["weapon_text"]), ", ".join(names)], UiScale.FONT_BODY,
			Color(0.88, 0.9, 0.95), UiScale.px(WINDOW_SIZE.x - 60.0)))


func _build_skills(body: VBoxContainer) -> void:
	var p := _player()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", int(UiScale.px(20)))
	body.add_child(head)
	head.add_child(_label("Очки умений: %d JP" % int(Game.hero.get("jp", 0)), UiScale.FONT_HEAD, GOLD))
	if p.weapon_kind != "":
		head.add_child(_label("В руках: %s%s" % [ItemData.weapon_kind_name(p.weapon_kind), " и щит" if p.has_shield else ""],
			UiScale.FONT_TEXT, Color.WHITE))
	if p.max_mp > 0:
		var up := p.toggle_upkeep()
		head.add_child(_label("MP %d / %d%s" % [p.mp, p.max_mp, ("  (поддержка −%d / 10 с)" % up) if up > 0 else ""],
			UiScale.FONT_TEXT, Color(0.6, 0.75, 1.0)))
	var ids := HeroSkills.list_tab(Game.class_id, tab)
	if selected == "" or not ids.has(selected):
		selected = _default_pick(ids)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiScale.px(12)))
	body.add_child(row)
	var items: Array = []
	for id in ids:
		items.append(_tree_item(String(id), p))
	tree = SkillTree.new()
	tree.setup(items, UiScale.v2(TREE_SIZE.x, TREE_SIZE.y), selected)
	tree.picked.connect(_on_pick)
	row.add_child(tree)
	for id in tree.icons:
		buttons["skill_" + String(id)] = tree.icons[id]
	row.add_child(_card(selected, p))


func _default_pick(ids: Array) -> String:
	for id in ids:
		if HeroSkills.learn_block(Game.hero, Game.class_id, Game.level, String(id)) == "":
			return String(id)
	return String(ids[0]) if not ids.is_empty() else ""


func _tree_item(id: String, p: Player) -> Dictionary:
	var sk := HeroSkills.get_skill(id)
	var cur := HeroSkills.skill_level(Game.hero, id)
	var pre := ""
	if sk.has("pre"):
		pre = String((sk["pre"] as Array)[0])
	return {
		"id": id, "name": String(sk["name"]), "glyph": String(sk.get("glyph", "?")), "color": sk["color"],
		"kind": String(sk["kind"]), "level": cur, "max": HeroSkills.max_level(id),
		"row": HeroSkills.level_needed(id, 1), "pre": pre, "learned": cur > 0,
		"can": HeroSkills.learn_block(Game.hero, Game.class_id, Game.level, id) == "",
		"unfit": not HeroSkills.weapon_ok(id, p.weapon_kind, p.has_shield),
		"on": HeroSkills.toggle_on(Game.hero, id), "icon": HeroSkills.icon_path(id),
	}


func _card(id: String, p: Player) -> Control:
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
	var w := UiScale.px(CARD_W - 24.0)
	var sk := HeroSkills.get_skill(id)
	if sk.is_empty():
		box.add_child(_label("Выберите умение в древе", UiScale.FONT_TEXT, MUTED, w))
		return panel
	var cur := HeroSkills.skill_level(Game.hero, id)
	var mx := HeroSkills.max_level(id)
	var kind := HeroSkills.kind(id)
	var block := HeroSkills.learn_block(Game.hero, Game.class_id, Game.level, id)
	var on := kind == "toggle" and HeroSkills.toggle_on(Game.hero, id)
	box.add_child(_label(String(sk["name"]), UiScale.FONT_NAME, GOLD, w))
	var meta := "%s · оружие: %s · ур. %d/%d" % [HeroSkills.kind_name(id), HeroSkills.weapon_name(id), cur, mx]
	# Время каста активного: «Каст: 1.2 с» (со скоростью каста героя — «сейчас …») / «Мгновенно»
	var cast_t := HeroSkills.cast_text(id, maxi(1, cur), p.cast_speed)
	if cast_t != "":
		meta += " · " + cast_t
	if on:
		meta += " · ВКЛЮЧЕНО"
	box.add_child(_label(meta, UiScale.FONT_BODY, GOOD if on else MUTED, w))
	var wb := HeroSkills.weapon_block(id, p.weapon_kind, p.has_shield)
	if wb != "":
		box.add_child(_label("Не подходит к текущему оружию: %s" % wb.to_lower(), UiScale.FONT_BODY, BAD, w))
	box.add_child(_label(String(sk.get("desc", "")), UiScale.FONT_BODY, MUTED, w))
	if cur > 0:
		box.add_child(_label("Сейчас: " + HeroSkills.effect_text(id, cur), UiScale.FONT_BODY, Color.WHITE, w))
		var need_now := HeroSkills.level_needed(id, cur)
		if need_now > Game.level:
			# Старые сохранения: изучено по прежним требованиям — не отбирается
			box.add_child(_label("Изучено раньше; по новым правилам этот уровень — с ур. %d" % need_now, UiScale.FONT_BODY,
				BAD, w))
	if cur < mx:
		box.add_child(_label("Ур. %d: %s" % [cur + 1, HeroSkills.effect_text(id, cur + 1)], UiScale.FONT_BODY, Color(0.85, 0.88, 1.0), w))
		var req := "Нужно: " + HeroSkills.requirement_text(id, cur + 1)
		if block == "":
			box.add_child(_label(req + " — можно изучить", UiScale.FONT_BODY, GOOD, w))
		else:
			box.add_child(_label(req + " — " + block, UiScale.FONT_BODY, BAD, w))
	var left := float(p.skill_cd.get(id, 0.0))
	if left > 0.0:
		box.add_child(_label("Перезарядка: %.0f с" % ceilf(left), UiScale.FONT_BODY, MUTED))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", int(UiScale.px(UiScale.GAP)))
	box.add_child(btns)
	if cur < mx:
		var plus := _button("+ %d JP" % HeroSkills.jp_cost(id, cur + 1), 120)
		plus.disabled = block != ""
		plus.pressed.connect(_on_learn.bind(id))
		btns.add_child(plus)
		buttons["learn_" + id] = plus
	if kind == "toggle" and cur > 0:
		var tb := _button("Выкл" if on else "Вкл", 90)
		tb.pressed.connect(_on_toggle.bind(id))
		btns.add_child(tb)
		buttons["toggle_" + id] = tb
	if kind != "passive" and cur > 0:
		var srow := HBoxContainer.new()
		srow.add_theme_constant_override("separation", int(UiScale.px(6)))
		box.add_child(srow)
		srow.add_child(_label("На кнопку:", UiScale.FONT_BODY, MUTED))
		var slots: Array = Game.hero.get("slots", [])
		for i in HeroSkills.SLOTS:
			var sbn := _button(str(i + 1), 46)
			sbn.toggle_mode = true
			sbn.button_pressed = i < slots.size() and String(slots[i]) == id
			sbn.pressed.connect(_on_slot.bind(id, i))
			srow.add_child(sbn)
			buttons["slot_%d" % (i + 1)] = sbn
	return panel


## Кнопка карточки; w — ширина для «Среднего» размера интерфейса.
func _button(text: String, w: float) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(UiScale.px(w), UiScale.button_h())
	return b


func _on_pick(id: String) -> void:
	selected = id
	refresh()


func _on_learn(id: String) -> void:
	var nm := String(HeroSkills.get_skill(id).get("name", id))
	var why := HeroSkills.learn_block(Game.hero, Game.class_id, Game.level, id)
	if why != "" or not HeroSkills.learn(Game.hero, Game.class_id, Game.level, id):
		_msg("«%s»: %s" % [nm, why])
		refresh()
		return
	_player().refresh_skills()
	_msg("«%s» — ур. %d" % [nm, HeroSkills.skill_level(Game.hero, id)])
	Game.changed.emit()
	refresh()


func _on_toggle(id: String) -> void:
	var nm := String(HeroSkills.get_skill(id).get("name", id))
	var err := _player().set_toggle(id, not HeroSkills.toggle_on(Game.hero, id))
	if err != "":
		_msg("«%s»: %s" % [nm, err])
	refresh()


## Кнопка «На кнопку i»: назначить; повторное нажатие на ту же кнопку — убрать.
func _on_slot(id: String, i: int) -> void:
	var slots: Array = Game.hero.get("slots", [])
	var nm := String(HeroSkills.get_skill(id).get("name", id))
	if i < slots.size() and String(slots[i]) == id:
		_player().assign_slot("", i)
		_msg("Кнопка %d пуста" % (i + 1))
	elif _player().assign_slot(id, i):
		_msg("«%s» — на кнопке %d" % [nm, i + 1])
	refresh()


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
