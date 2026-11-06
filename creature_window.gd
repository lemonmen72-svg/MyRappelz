class_name CreatureWindow
extends Node
## Окно существа: характеристики питомца, его умения (изучение за очки умений JP, ячейки умений) и снаряжение.
## Открывается кнопкой «Подробнее» в окне «Питомцы» и кнопкой «Существо» у панели питомца в HUD (клавиша C).
## Вкладки (кнопки сверху, не прокручиваются; значок и подпись):
## «Существо» ("stats") — 3D-превью модели, вид, роль, редкость, стадия, уровень и опыт, HP/MP, JP, 7 характеристик,
## боевые показатели (PetStats) и коротко снаряжение; умения — на трёх вкладках (PetSkills.TABS, PetSkills.tab_of):
## «Активные» ("active": урон, ослабления, «Создание»), «Ауры и бафы» ("aura": узы, вызов, активные усиления),
## «Пассивные» ("passive": в т. ч. «Знаток снаряжения», «Живучесть», «Боец», «Способности карты», «Благословения») —
## на каждой крупное древо (SkillTree, крупный режим: ярусы по уровню питомца, перенос строк, линии пререквизитов)
## и карточка выбранного умения: тип, уровень, эффект сейчас и на следующем уровне, требования, кнопка «+ N JP»
## (изучить), «В ячейку 1–3» / «В ячейку ауры 1–2» и «Убрать». На вкладках «Активные» и «Ауры и бафы» над древом —
## 5 ячеек умений: 3 «Авто» (активные: ИИ питомца применяет только их, по порядку) и 2 «Ауры» (переключаемые:
## включены, пока стоят в ячейке). Касание занятой ячейки убирает умение, пустой — ставит туда выбранное в древе
## изученное умение подходящего типа. Пассивные действуют всегда, ячеек не занимают.
## «Оружие и доспехи» ("gear") — ячейки питомца «Оружие» и «Броня» (PetGear) и сетка сумки: только оружие (не щит)
## и доспехи на тело, свободные штуки (не надетые героем). Касание вещи — карточка (характеристики, что получит
## питомец с «Знатоком снаряжения», «Боец» / «Живучесть», почему нельзя) и «Надеть питомцу» (тратит карту
## снаряжения); перетаскивание значка на ячейку — то же. Касание надетой — карточка и «Снять» (тратит мел).
## Под вкладками — ряд значков всех питомцев героя (pet_chip: карта вида с душой; призванный — золотая рамка,
## погибший — затемнён, в поясе — метка «П»): касание — окно переключается на этого питомца, вкладка та же.
## Значки умений: res://assets/icons/pets/<вид>/<id умения>.png (нет файла — кружок с буквой).
## Живёт в PetManager (pets.creature). Данные — запись Game.pets[index]; призванный питомец пересчитывается сразу.

## Размеры — для «Среднего» размера интерфейса (умножаются на UiScale.k(); было 1180×660, древо 660×420).
const WINDOW_SIZE := Vector2(1060, 600)
## Ширина переносимого текста по умолчанию.
const TEXT_W := 700.0
## Древо умений рядом с карточкой: с рядом ячеек над ним (активные, ауры) и без него (пассивные). Значки — крупный
## режим SkillTree (до 86 px; было до 58 px в одном древе на все 32 умения — ≈ 46 px).
const TREE_W := 620.0
const TREE_H := 350.0
const TREE_H_FULL := 412.0
## Ячейка умения (квадрат) над древом.
const SLOT_PX := 54.0
const CARD_W := 384.0
const PREVIEW_SIZE := Vector2(230, 230)
## Значок питомца в ряду питомцев.
const CHIP_PX := 46.0
## Вкладка «Оружие и доспехи»: ячейка питомца, ячейка сумки, столбцов сетки.
const GEAR_SLOT_PX := 92.0
const GEAR_CELL_PX := 72.0
const GEAR_COLS := 5
## Вкладки: [ключ, подпись, значок UiIcons] (умения — PetSkills.TABS между «Существом» и «Оружием»).
const STATS_TAB := ["stats", "Существо", "menu_creature"]
const GEAR_TAB := ["gear", "Оружие и доспехи", "tab_pet_gear"]
const GOLD := Color(1.0, 0.85, 0.45)
const MUTED := Color(0.78, 0.8, 0.9)
const GOOD := Color(0.55, 1.0, 0.6)
const BAD := Color(1.0, 0.62, 0.45)
const CELL_BG := Color(0.1, 0.12, 0.22, 0.95)

var main: Node
var pets: PetManager
## Индекс питомца в Game.pets (-1 — окно не открыто) и вкладка: "stats" | "active" | "aura" | "passive" | "gear"
## (прежнее "skills" = "active").
var index := -1
var tab := "stats"
## Кнопки открытого окна: вкладки "tab_stats", "tab_active", "tab_aura", "tab_passive", "tab_gear" ("tab_skills" — та
## же, что "tab_active"), "back", питомцы "pet_<i>", "to_skills", "to_gear"; "skill_<id>" (значки древа открытой
## вкладки), ячейки "slot_auto_<0..2>", "slot_aura_<0..1>"; карточка умения: "learn_<id>", "toslot_<id>_<номер>",
## "unslot_<id>", "toggle_<id>", "create_<id>"; вкладка «Оружие и доспехи»: ячейки питомца "gear_slot_weapon",
## "gear_slot_armor", вещи сумки "gear_item_<id>", в карточке "gear_equip" (надеть выбранную), "gear_off_<ячейка>".
var buttons: Dictionary = {}
## Выбранное в древе умение и само древо (на вкладках умений).
var selected := ""
var tree: SkillTree = null
## Вкладка «Оружие и доспехи»: выбранная вещь сумки (id) или ячейка питомца ("slot:weapon" / "slot:armor").
var gear_sel := ""

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


## Открывает окно существа для питомца i на вкладке which ("" — та же, что была; "skills" — «Активные»).
## true — открыто.
func open(i: int, which: String = "") -> bool:
	if i < 0 or i >= Game.pets.size():
		return false
	if i != index:
		selected = ""
		gear_sel = ""
	index = i
	if which == "skills":
		which = "active"
	if which != "":
		tab = which
	if not tab_keys().has(tab):
		tab = "stats"
	buttons.clear()
	tree = null
	_pivot = null
	_holder = null
	var rec: Dictionary = Game.pets[i]
	PetSkills.ensure_record(rec)
	_species = String(rec.get("species", "boar"))
	var body: VBoxContainer = main.hud.create_window("Существо: %s" % String(rec.get("name", "Питомец")), WINDOW_SIZE)
	UiButtons.decorate_all.call_deferred(buttons)
	_body = body
	_scroll = body.get_parent() as ScrollContainer
	_add_tabs(body)
	_add_pet_strip(body, rec)
	match tab:
		"active", "aura", "passive":
			_build_skills(body, rec)
		"gear":
			_build_gear_tab(body, rec)
		_:
			_build_stats(body, rec)
	return true


## Ключи вкладок по порядку.
static func tab_keys() -> Array:
	var res: Array = [String(STATS_TAB[0])]
	for t in PetSkills.TABS:
		res.append(String(t[0]))
	res.append(String(GEAR_TAB[0]))
	return res


## Показать умение id: вкладка, где оно лежит, и его карточка.
func show_skill(id: String) -> void:
	if index < 0:
		return
	selected = id
	open(index, PetSkills.tab_of(id))


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
	bar.add_theme_constant_override("separation", int(UiScale.px(6)))
	_put_above_scroll(body, bar, 1)
	# Вкладки — значок и короткая подпись (UiIcons: menu_creature, tab_pet_*, back)
	var all: Array = [STATS_TAB]
	all.append_array(PetSkills.TABS)
	all.append(GEAR_TAB)
	for t in all:
		var key := String(t[0])
		_tab_button(bar, "tab_" + key, String(t[1]), tab == key, _on_tab.bind(key), String(t[2]))
	# Прежняя вкладка «Умения» — теперь «Активные»
	buttons["tab_skills"] = buttons["tab_active"]
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	_tab_button(bar, "back", "К питомцам", false, _on_back, "back")


## Узел n — в окно над прокруткой (на месте at среди строк окна), иначе — в тело.
func _put_above_scroll(body: VBoxContainer, n: Control, at: int) -> void:
	var root: Node = null
	if body.get_parent() != null:
		root = body.get_parent().get_parent()
	if root is VBoxContainer:
		root.add_child(n)
		root.move_child(n, mini(at, root.get_child_count() - 1))
	else:
		body.add_child(n)


func _tab_button(bar: HBoxContainer, key: String, text: String, active: bool, cb: Callable, icon_id: String = "") -> void:
	var b := Button.new()
	b.text = text
	if icon_id != "":
		UiIcons.add_icon(b, icon_id)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(UiScale.px(96), UiScale.px(UiScale.TAB_H))
	b.toggle_mode = key != "back"
	b.button_pressed = active
	b.pressed.connect(cb)
	bar.add_child(b)
	buttons[key] = b


## Ряд значков питомцев героя (касание — окно этого питомца) и справа — сводка вкладки (JP, MP; карты и мел).
func _add_pet_strip(body: VBoxContainer, rec: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiScale.px(6)))
	_put_above_scroll(body, row, 2)
	var t := _label("Питомцы:", UiScale.FONT_SMALL, MUTED)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(t)
	for i in Game.pets.size():
		var b := pet_chip(i, UiScale.px(CHIP_PX), i == index)
		b.pressed.connect(_on_pet_chip.bind(i))
		row.add_child(b)
		buttons["pet_%d" % i] = b
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var info := ""
	match tab:
		"active", "aura", "passive":
			var lvl := int(rec.get("level", 1))
			info = "JP: %d  ·  ур. %d, форма %d" % [int(rec.get("jp", 0)), lvl, PetData.stage_of(rec) + 1]
			var pet := _live_pet(rec)
			if pet != null:
				var up := pet.toggle_upkeep()
				info += "  ·  MP %d / %d%s" % [pet.mp, pet.max_mp, ("  (−%d / 10 с)" % up) if up > 0 else ""]
		"gear":
			info = "Карт снаряжения: %d  ·  мела: %d" % [Game.inventory.count(PetGear.UNIT_CARD), Game.inventory.count(PetGear.CHALK)]
	if info != "":
		var l := _label(info, UiScale.FONT_TEXT, GOLD)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)


## Значок питомца i коллекции (sz — сторона, уже с масштабом): карта вида с душой, уровень в углу; current — этот
## питомец открыт; призванный — золотая рамка, погибший — затемнён с красной рамкой, в поясе — фиолетовая метка «П».
## Общий для окна существа и окна «Питомцы».
static func pet_chip(i: int, sz: float, current: bool) -> Button:
	var rec: Dictionary = Game.pets[i]
	var sp := String(rec.get("species", "boar"))
	var dead := bool(rec.get("dead", false))
	var summoned := i == Game.active_pet and not dead
	var belt := PetBelt.in_belt(rec)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(sz, sz)
	b.name = "Pet_%d" % i
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.22, 0.25, 0.4, 0.98) if current else CELL_BG
	sb.border_color = Color(1.0, 0.82, 0.3) if summoned else (Color(1.0, 0.4, 0.35) if dead
		else (Color.WHITE if current else Color(0.45, 0.47, 0.6)))
	sb.set_border_width_all(3 if (summoned or current) else 2)
	sb.set_corner_radius_all(int(sz * 0.18))
	sb.anti_aliasing = true
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var card := "card_%s_soul" % sp
	var inset := roundf(sz * 0.1)
	var pic: Control = null
	if not ItemData.get_item(card).is_empty():
		pic = ItemIcon.make(card, sz - inset * 2.0)
	else:
		var iv := IconView.new()
		iv.set_spec(IconView.glyph(String(MobData.get_type(sp).get("name", "?")).substr(0, 1), Color(0.5, 0.55, 0.7)))
		pic = iv
	pic.position = Vector2(inset, inset)
	pic.size = Vector2(sz - inset * 2.0, sz - inset * 2.0)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dead:
		pic.modulate = Color(0.4, 0.38, 0.4)
	b.add_child(pic)
	var lv := Label.new()
	lv.text = str(int(rec.get("level", 1)))
	var f := UiScale.fs(UiScale.FONT_TINY)
	lv.add_theme_font_size_override("font_size", f)
	lv.add_theme_color_override("font_color", Color.WHITE)
	lv.add_theme_color_override("font_outline_color", Color.BLACK)
	lv.add_theme_constant_override("outline_size", 4)
	lv.position = Vector2(2.0, sz - float(f) * 1.45)
	lv.size = Vector2(sz * 0.6, float(f) * 1.4)
	lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(lv)
	if belt:
		var badge := Label.new()
		badge.text = "П"
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", f)
		badge.add_theme_color_override("font_color", Color.WHITE)
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color(0.55, 0.32, 0.95)
		bs.set_corner_radius_all(int(f))
		badge.add_theme_stylebox_override("normal", bs)
		var d := float(f) * 1.35
		badge.position = Vector2(sz - d - 1.0, 1.0)
		badge.size = Vector2(d, d)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(badge)
	var status := "погиб" if dead else ("призван" if summoned else ("в поясе" if belt else "отдыхает"))
	b.tooltip_text = "%s, ур. %d — %s" % [String(rec.get("name", "Питомец")), int(rec.get("level", 1)), status]
	return b


func _on_pet_chip(i: int) -> void:
	if i == index:
		return
	open(i, tab)


func _on_tab(which: String) -> void:
	open(index, which)


func _on_back() -> void:
	pets.open_window()


# ---------- Вкладка «Существо» ----------

func _build_stats(body: VBoxContainer, rec: Dictionary) -> void:
	var sp := _species
	var lvl := int(rec.get("level", 1))
	var pet := _live_pet(rec)
	var st: Dictionary = pet.stats if pet != null else PetData.stats_of(rec)
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
	var stage := PetData.stage_of(rec)
	var stage_line := "Форма %d из 3: %s" % [stage + 1, PetData.stage_name(sp, stage)]
	if PetData.super_bonus(rec) > 0.0:
		stage_line += " · сверх +%d%%" % roundi(PetData.super_bonus(rec) * 100.0)
	info.add_child(_label(stage_line, UiScale.FONT_HEAD, Color.WHITE))
	if stage < PetData.EVOLVE_LEVELS.size():
		info.add_child(_label("Эволюция у Кирка: с %d ур. (сверх — на %d)" % [int(PetData.EVOLVE_LEVELS[stage]),
			int(PetData.SUPER_LEVELS[stage])], UiScale.FONT_SMALL, MUTED))
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
	to_sk.pressed.connect(_on_tab.bind("active"))
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
	# Снаряжение коротко (надеть и снять — вкладка «Оружие и доспехи»)
	var gr := HBoxContainer.new()
	gr.add_theme_constant_override("separation", int(UiScale.px(10)))
	body.add_child(gr)
	var gl := _label("Снаряжение — %s · %s" % [PetGear.slot_text(rec, "weapon"), PetGear.slot_text(rec, "armor")],
		UiScale.FONT_TEXT, Color.WHITE)
	gl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gr.add_child(gl)
	var tg := Button.new()
	tg.text = "Оружие и доспехи"
	tg.focus_mode = Control.FOCUS_NONE
	tg.custom_minimum_size = Vector2(0, UiScale.button_h())
	tg.pressed.connect(_on_tab.bind("gear"))
	gr.add_child(tg)
	buttons["to_gear"] = tg


# ---------- Вкладка «Оружие и доспехи» ----------

## Оружие (не щит) и доспехи на тело в сумке героя, которые можно отдать питомцу: свободные штуки (Enchant.free_count),
## по порядку сортировки сумки.
static func gear_items() -> Array:
	var res: Array = []
	for id in Inventory.sorted_ids(Game.inventory.ids()):
		var gid := String(id)
		if PetGear.slot_for(gid) != "" and Enchant.free_count(gid) > 0:
			res.append(gid)
	return res


## Слева — ячейки питомца «Оружие» и «Броня», в центре — сетка вещей сумки (gear_items), справа — карточка.
func _build_gear_tab(body: VBoxContainer, rec: Dictionary) -> void:
	var list := gear_items()
	if gear_sel != "" and not gear_sel.begins_with("slot:") and not list.has(gear_sel):
		gear_sel = ""
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiScale.px(14)))
	body.add_child(row)
	# Ячейки питомца
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", int(UiScale.px(6)))
	row.add_child(left)
	left.add_child(_label("Питомец", UiScale.FONT_HEAD, GOLD))
	for slot in PetGear.SLOTS:
		var sid := String(slot)
		var cur := PetGear.gear_in(rec, sid)
		var cell := _gear_cell("slot", sid, cur, UiScale.px(GEAR_SLOT_PX), gear_sel == "slot:" + sid)
		cell.pressed.connect(_on_gear_slot.bind(sid))
		left.add_child(cell)
		buttons["gear_slot_" + sid] = cell
		var cap := _label(String(PetGear.SLOT_NAMES[sid]), UiScale.FONT_SMALL, MUTED)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.custom_minimum_size = Vector2(UiScale.px(GEAR_SLOT_PX), 0)
		left.add_child(cap)
	# Сумка: только оружие и доспехи
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", int(UiScale.px(6)))
	row.add_child(mid)
	mid.add_child(_label("Сумка: оружие и доспехи", UiScale.FONT_HEAD, GOLD))
	var k := PetGear.expert(rec)
	var hint := ("Питомец получает %d%% характеристик вещи и всю заточку («Знаток снаряжения»). Касание — карточка, значок можно перетащить в ячейку питомца." % roundi(k * 100.0)) if k > 0.0 \
		else "Сначала изучите «Знаток снаряжения» (вкладка «Пассивные», 1 JP) — без него питомец снаряжение не носит."
	mid.add_child(_label(hint, UiScale.FONT_SMALL, MUTED if k > 0.0 else BAD, UiScale.px(GEAR_CELL_PX * GEAR_COLS + 6.0 * (GEAR_COLS - 1))))
	var grid := GridContainer.new()
	grid.columns = GEAR_COLS
	grid.add_theme_constant_override("h_separation", int(UiScale.px(6)))
	grid.add_theme_constant_override("v_separation", int(UiScale.px(6)))
	mid.add_child(grid)
	var shown := 0
	for gid in list:
		var id := String(gid)
		var cell := _gear_cell("item", id, id, UiScale.px(GEAR_CELL_PX), gear_sel == id)
		cell.pressed.connect(_on_gear_item.bind(id))
		grid.add_child(cell)
		buttons["gear_item_" + id] = cell
		shown += 1
	# Пустые ячейки до полной строки (сетка не «прыгает»), не меньше двух строк
	var total := maxi(GEAR_COLS * 2, ceili(float(shown) / float(GEAR_COLS)) * GEAR_COLS)
	for e in total - shown:
		var empty := _gear_cell("item", "", "", UiScale.px(GEAR_CELL_PX), false)
		empty.disabled = true
		grid.add_child(empty)
	if shown == 0:
		mid.add_child(_label("В сумке нет оружия и доспехов для питомца (щиты и надетое героем — не в счёт).",
			UiScale.FONT_SMALL, MUTED, UiScale.px(GEAR_CELL_PX * GEAR_COLS)))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(_gear_card(rec))


## Ячейка вкладки снаряжения: kind "slot" (ячейка питомца, key — "weapon" / "armor") или "item" (вещь сумки, key — id);
## id — что показать ("" — пусто). Вещь сумки перетаскивается, на ячейку питомца её можно бросить.
func _gear_cell(kind: String, key: String, id: String, sz: float, sel: bool) -> GearCell:
	var b := GearCell.new()
	b.kind = kind
	b.key = key
	b.item_id = id
	b.drop_fn = _on_gear_drop
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(sz, sz)
	var frame := ItemData.frame_color(id) if id != "" else Color(0.4, 0.42, 0.55)
	var sb := StyleBoxFlat.new()
	sb.bg_color = CELL_BG.lerp(frame, 0.12) if id != "" else CELL_BG
	sb.border_color = Color.WHITE if sel else frame
	sb.set_border_width_all(4 if sel else 2)
	sb.set_corner_radius_all(int(sz * 0.12))
	sb.anti_aliasing = true
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if id != "":
		var pad := roundf(sz * 0.08)
		var ic := ItemIcon.make(id, sz - pad * 2.0)
		ic.position = Vector2(pad, pad)
		b.add_child(ic)
		b.tooltip_text = ItemData.item_name(id)
		if kind == "item" and Enchant.free_count(id) > 1:
			var n := Label.new()
			n.text = str(Enchant.free_count(id))
			var f := UiScale.fs(UiScale.FONT_SMALL)
			n.add_theme_font_size_override("font_size", f)
			n.add_theme_color_override("font_outline_color", Color.BLACK)
			n.add_theme_constant_override("outline_size", 4)
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			n.position = Vector2(0, sz - float(f) * 1.45)
			n.size = Vector2(sz - 4.0, float(f) * 1.4)
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(n)
	elif kind == "slot":
		var g := Label.new()
		g.text = "пусто"
		g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		g.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		g.add_theme_font_size_override("font_size", UiScale.fs(UiScale.FONT_SMALL))
		g.add_theme_color_override("font_color", Color(0.55, 0.6, 0.75))
		g.size = Vector2(sz, sz)
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(g)
	return b


## Карточка выбранной вещи сумки («Надеть питомцу») или ячейки питомца («Снять»).
func _gear_card(rec: Dictionary) -> Control:
	var panel := _panel(UiScale.v2(CARD_W - 40.0, TREE_H_FULL))
	var box: VBoxContainer = panel.get_child(0)
	var w := UiScale.px(CARD_W - 64.0)
	var slot := gear_sel.substr(5) if gear_sel.begins_with("slot:") else ""
	var id := PetGear.gear_in(rec, slot) if slot != "" else gear_sel
	if id == "":
		box.add_child(_label("Снаряжение питомца" if slot == "" else "%s: пусто" % String(PetGear.SLOT_NAMES[slot]),
			UiScale.FONT_NAME, GOLD, w))
		box.add_child(_label("Коснитесь вещи в сумке — характеристики и «Надеть питомцу». Надеть тратит «%s» (Кирк), снять — «%s»."
			% [ItemData.item_name(PetGear.UNIT_CARD), ItemData.item_name(PetGear.CHALK)], UiScale.FONT_BODY, MUTED, w))
		box.add_child(_label("Ячейка «Оружие» — любое оружие, кроме щита; «Броня» — доспех на тело. Вещь — по уровню питомца.",
			UiScale.FONT_BODY, MUTED, w))
		return panel
	var nm := _label(ItemData.item_name(id), UiScale.FONT_NAME, ItemData.frame_color(id).lerp(Color.WHITE, 0.35), w)
	box.add_child(nm)
	var kind_line := ItemData.weapon_kind_name(ItemData.weapon_kind(id)) if ItemData.is_weapon(id) else "Доспех"
	box.add_child(_label("%s · %d ранг · с %d ур." % [kind_line, maxi(1, ItemData.rank(id)), ItemData.required_level(id)],
		UiScale.FONT_BODY, MUTED, w))
	var it := ItemData.get_item(id)
	var stats: PackedStringArray = []
	for e in [["atk", "Физ. атака"], ["matk", "Маг. атака"], ["def", "Физ. защита"], ["mdef", "Маг. защита"]]:
		var v := int(it.get(String(e[0]), 0))
		if v != 0:
			stats.append("%s %d" % [String(e[1]), v])
	if not stats.is_empty():
		box.add_child(_label(", ".join(stats), UiScale.FONT_BODY, Color.WHITE, w))
	var k := PetGear.expert(rec)
	if k > 0.0:
		var gt := PetGear.gain_text(rec, id)
		box.add_child(_label("Питомцу (%d%% + заточка): %s" % [roundi(k * 100.0), gt if gt != "" else "ничего"],
			UiScale.FONT_BODY, GOOD, w))
	var ut := PetGear.unit_text(rec, id)
	if ut != "":
		box.add_child(_label(ut, UiScale.FONT_BODY, Color(0.85, 0.88, 1.0), w))
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(sp)
	if slot != "":
		var why := PetGear.unequip_block(rec, slot)
		if why != "":
			box.add_child(_label(why, UiScale.FONT_BODY, BAD, w))
		var ub := Button.new()
		ub.text = "Снять (мел)"
		ub.focus_mode = Control.FOCUS_NONE
		ub.custom_minimum_size = Vector2(UiScale.px(150), UiScale.button_h())
		ub.disabled = why != ""
		ub.pressed.connect(_on_gear_off.bind(slot))
		box.add_child(ub)
		buttons["gear_off_" + slot] = ub
		return panel
	var cur := PetGear.gear_in(rec, PetGear.slot_for(id))
	if cur != "":
		box.add_child(_label("Сейчас в ячейке: %s" % ItemData.item_name(cur), UiScale.FONT_BODY, MUTED, w))
	var why2 := PetGear.equip_block(rec, id)
	if why2 == "" and cur != "":
		why2 = "Ячейка занята — сначала снимите (нужен мел)"
	if why2 != "":
		box.add_child(_label(why2, UiScale.FONT_BODY, BAD, w))
	var eb := Button.new()
	eb.text = "Надеть питомцу"
	eb.focus_mode = Control.FOCUS_NONE
	eb.custom_minimum_size = Vector2(UiScale.px(170), UiScale.button_h())
	eb.disabled = why2 != ""
	eb.pressed.connect(_on_gear_on.bind(id))
	box.add_child(eb)
	buttons["gear_equip"] = eb
	return panel


func _on_gear_item(id: String) -> void:
	gear_sel = id
	refresh()


func _on_gear_slot(slot: String) -> void:
	gear_sel = "slot:" + slot
	refresh()


## Значок вещи id бросили на ячейку питомца slot.
func _on_gear_drop(slot: String, id: String) -> void:
	if PetGear.slot_for(id) != slot:
		_msg("В ячейку «%s» эта вещь не встанет" % String(PetGear.SLOT_NAMES.get(slot, slot)))
		return
	_on_gear_on(id)


func _on_gear_on(id: String) -> void:
	if index < 0 or index >= Game.pets.size():
		return
	var rec: Dictionary = Game.pets[index]
	var err := PetGear.equip(rec, id)
	_msg(err if err != "" else "Питомец надел «%s»" % ItemData.item_name(id))
	if err == "":
		gear_sel = "slot:" + PetGear.slot_for(id)
	_pet_restat(rec)
	refresh()


func _on_gear_off(slot: String) -> void:
	if index < 0 or index >= Game.pets.size():
		return
	var rec: Dictionary = Game.pets[index]
	var id := PetGear.gear_in(rec, slot)
	var err := PetGear.unequip(rec, slot)
	_msg(err if err != "" else "«%s» — снова в сумке" % ItemData.item_name(id))
	if err == "":
		gear_sel = id
	_pet_restat(rec)
	refresh()


## Призванный питомец пересчитывает характеристики (снаряжение, умения).
func _pet_restat(rec: Dictionary) -> void:
	var pet := _live_pet(rec)
	if pet != null:
		pet.refresh_skills()


## «Создать» (умения вида "manual": материал, зелье) — питомец должен быть призван (MP — его).
func _on_create(id: String) -> void:
	if index < 0 or index >= Game.pets.size():
		return
	var rec: Dictionary = Game.pets[index]
	var r := PetGear.create(rec, id, _live_pet(rec))
	_msg(r)
	refresh()


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
	var stage := PetData.stage_of(rec)
	var sc := PetData.stage_scale(sp, stage)
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
	CreatureModels.build(_holder, sp, PetData.stage_color(sp, stage), sc, PetData.asset_tint(sp, stage), stage)
	CreatureModels.decorate_pet(_holder, sp, sc, stage, PetData.role(sp))
	return svc


# ---------- Вкладка «Умения» ----------

## Вкладка умений (tab: "active" | "aura" | "passive"): ячейки «Авто» и «Ауры» (кроме пассивных), крупное древо
## умений вкладки (SkillTree, крупный режим) слева и карточка выбранного умения справа.
func _build_skills(body: VBoxContainer, rec: Dictionary) -> void:
	var sp := _species
	var pet := _live_pet(rec)
	var ids := PetSkills.list_tab(sp, tab)
	if selected == "" or not ids.has(selected):
		selected = _default_pick(rec, ids)
	var with_slots := tab != "passive"
	if with_slots:
		body.add_child(_slots_row(rec))
	var tree_h := TREE_H if with_slots else TREE_H_FULL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiScale.px(12)))
	body.add_child(row)
	if ids.is_empty():
		var empty := _label("На этой вкладке у питомца умений нет.", UiScale.FONT_TEXT, MUTED, UiScale.px(TREE_W))
		empty.custom_minimum_size = UiScale.v2(TREE_W, tree_h)
		row.add_child(empty)
		row.add_child(_card(rec, "", pet, tree_h))
		return
	var items: Array = []
	for id in ids:
		items.append(_tree_item(rec, String(id), pet))
	tree = SkillTree.new()
	tree.setup(items, UiScale.v2(TREE_W, tree_h), selected, true)
	tree.picked.connect(_on_pick)
	row.add_child(tree)
	for id in tree.icons:
		buttons["skill_" + String(id)] = tree.icons[id]
	row.add_child(_card(rec, selected, pet, tree_h))


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
		+ "пустой — поставить выбранное умение.", UiScale.FONT_SMALL, MUTED, UiScale.px(440))
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
	var p := "res://assets/icons/pets/%s/%s.png" % [species, id]
	# Общие умения всех видов («Благословение …») — один значок в assets/icons/pets/common/
	if not Assets.exists(p):
		var c := "res://assets/icons/pets/common/%s.png" % id
		if Assets.exists(c):
			return c
	return p


## Карточка умения: название, тип, уровень, эффект сейчас и на следующем, требования, «+ JP», «Вкл/Выкл»;
## h — высота (для «Среднего»).
func _card(rec: Dictionary, id: String, pet: Pet, h: float = TREE_H) -> Control:
	var panel := _panel(UiScale.v2(CARD_W, h))
	var box: VBoxContainer = panel.get_child(0)
	# Ширина текста карточки (с масштабом)
	var w := UiScale.px(CARD_W - 24.0)
	var sk := PetSkills.get_skill(id)
	if sk.is_empty():
		box.add_child(_label("Выберите умение в древе", UiScale.FONT_TEXT, MUTED, w))
		return panel
	var lvl := int(rec.get("level", 1))
	var cur := PetSkills.skill_level(rec, id)
	var mx := PetSkills.max_level(id)
	var cap := PetSkills.cap_for(id, lvl, PetData.stage_of(rec))
	var block := PetSkills.learn_block(rec, id)
	var kind := String(sk["kind"])
	box.add_child(_label(String(sk["name"]), UiScale.FONT_NAME, GOLD, w))
	var lvl_text := "ур. %d/%d" % [cur, mx]
	if cap < mx:
		lvl_text += " (сейчас до %d)" % cap
	var meta := "%s · %s · стадия %d+" % [PetSkills.kind_name(id), lvl_text, PetSkills.first_stage(id) + 1]
	if bool(sk.get("per_form", false)):
		meta = "%s · %s · по уровню на форму" % [PetSkills.kind_name(id), lvl_text]
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
	if kind == "manual" and cur > 0:
		var why := PetGear.create_block(rec, id, pet)
		box.add_child(_label(why if why != "" else "Можно создать", UiScale.FONT_BODY, BAD if why != "" else GOOD, w))
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
	if kind == "manual" and cur > 0:
		var cb := Button.new()
		cb.text = "Создать"
		cb.focus_mode = Control.FOCUS_NONE
		cb.custom_minimum_size = Vector2(UiScale.px(110), UiScale.button_h())
		cb.disabled = PetGear.create_block(rec, id, pet) != ""
		cb.pressed.connect(_on_create.bind(id))
		btns.add_child(cb)
		buttons["create_" + id] = cb
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


## Панель карточки размера sz (уже с масштабом) с VBoxContainer внутри (первый ребёнок).
func _panel(sz: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = sz
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


## Ячейка вкладки «Оружие и доспехи»: вещь сумки (kind "item") перетаскивается, на ячейку питомца (kind "slot")
## её можно бросить — drop_fn(ячейка, id).
class GearCell extends Button:
	var kind := ""
	var key := ""
	var item_id := ""
	var drop_fn: Callable

	func _get_drag_data(_at_position: Vector2) -> Variant:
		if kind != "item" or item_id == "":
			return null
		var holder := Control.new()
		var ic := ItemIcon.make(item_id, size.x * 0.9)
		ic.position = -ic.size * 0.5
		ic.modulate = Color(1, 1, 1, 0.85)
		holder.add_child(ic)
		var vp := get_viewport()
		if vp != null and vp.gui_is_dragging():
			set_drag_preview(holder)
		else:
			holder.free()
		return {"pet_gear": item_id}

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return kind == "slot" and data is Dictionary and (data as Dictionary).has("pet_gear") \
			and PetGear.slot_for(String((data as Dictionary)["pet_gear"])) == key

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if kind == "slot" and data is Dictionary and drop_fn.is_valid():
			drop_fn.call(key, String((data as Dictionary).get("pet_gear", "")))
