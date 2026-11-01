class_name SkillTree
extends Control
## Компактное древо умений (окно героя CharacterWindow и окно существа CreatureWindow).
## Сетка круглых значков по ярусам: строка — требуемый уровень (сверху вниз; если ярусов больше, чем
## помещается по высоте, соседние уровни сливаются в одну строку «ур. 5–6»), линии — пререквизиты
## (умение под своим пререквизитом, если место свободно). На значке мелко в углу — уровень «изучено/всего».
## Изученные — яркие, доступные к изучению — с золотой подсветкой, недоступные — затемнены, не подходящие
## текущему оружию — с красной меткой, у переключаемых — точка (зелёная — включено), у пассивных — двойное кольцо.
## Касание значка — сигнал picked(id): окно показывает карточку умения.
## Картинка значка — PNG по пути из поля "icon" (128×128, прозрачные углы); нет файла — кружок с буквой.
##
## Использование:
##   var t := SkillTree.new()
##   t.setup(items, Vector2(640, 420), selected_id)
##   t.picked.connect(func(id): ...)
## items — массив словарей: {"id", "name", "glyph", "color": Color, "kind": "active"|"passive"|"toggle",
##   "level": изучено, "max", "row": требуемый уровень (ярус), "pre": id пререквизита или "",
##   "learned": bool, "can": bool (можно изучить следующий уровень), "unfit": bool (не подходит оружию),
##   "on": bool (переключаемое включено), "icon": путь к PNG}.

signal picked(id: String)

## Размеры — для «Среднего» размера интерфейса (умножаются на UiScale.k(): row_min(), icon_min() и т. д.).
## Значки крупнее относительно текста: подписи мелкие (UiScale.FONT_SMALL / FONT_TINY), значок до 58 px.
## Высота строки: не меньше (иначе ярусы сливаются) и не больше.
const ROW_MIN := 54.0
const ROW_MAX := 74.0
## Ширина подписи яруса слева и ширина колонки значков.
const LABEL_W := 70.0
const COL_MIN := 60.0
const COL_MAX := 100.0
const ICON_MIN := 42.0
const ICON_MAX := 58.0
const GOLD := Color(1.0, 0.82, 0.38)
const LINE_ON := Color(1.0, 0.85, 0.45, 0.9)
const LINE_OFF := Color(0.6, 0.62, 0.75, 0.45)

var items: Array = []
var selected := ""
## id умения → кнопка-значок.
var icons: Dictionary = {}
## Ярусы после слияния: [{"from": ур., "to": ур., "ids": [id, ...]}, ...].
var rows: Array = []
var icon_size := 60.0

## Центры значков и пререквизиты (для линий).
var _center: Dictionary = {}
var _pre: Dictionary = {}
var _learned: Dictionary = {}
var _row_y: Array = []

static var _tex_cache: Dictionary = {}


## Наименьшая высота яруса с масштабом интерфейса (больше ярусов, чем size.y / row_min(), не бывает).
static func row_min() -> float:
	return UiScale.px(ROW_MIN)


## Наименьший значок с масштабом интерфейса.
static func icon_min() -> float:
	return UiScale.px(ICON_MIN)


## Картинка значка по пути или null (файла нет). Проверка через Assets.exists — значки лежат в части «icons»
## пакета ресурсов (без неё — кружок с буквой); работает и в собранном APK.
static func load_icon(path: String) -> Texture2D:
	if path == "":
		return null
	if _tex_cache.has(path):
		return _tex_cache[path]
	var tex: Texture2D = null
	if Assets.exists(path):
		tex = load(path) as Texture2D
	_tex_cache[path] = tex
	return tex


## Забыть картинки (Assets.reset_caches).
static func reset_cache() -> void:
	_tex_cache.clear()


## Строит древо в прямоугольнике sz. sel — выделенное умение.
func setup(list: Array, sz: Vector2, sel: String = "") -> void:
	items = list
	selected = sel
	custom_minimum_size = sz
	size = sz
	mouse_filter = Control.MOUSE_FILTER_PASS
	for c in get_children():
		remove_child(c)
		c.queue_free()
	icons.clear()
	_center.clear()
	_pre.clear()
	_learned.clear()
	_row_y.clear()
	_make_rows(sz.y)
	if rows.is_empty():
		return
	var row_h := minf(UiScale.px(ROW_MAX), sz.y / float(rows.size()))
	icon_size = clampf(row_h - UiScale.px(12), icon_min(), UiScale.px(ICON_MAX))
	var label_w := UiScale.px(LABEL_W)
	# Колонки: умение под своим пререквизитом, если там свободно
	var col_of: Dictionary = {}
	var ncols := 1
	for r in rows:
		var used: Dictionary = {}
		for id in r["ids"]:
			var it := _item(String(id))
			var c := -1
			var pre := String(it.get("pre", ""))
			if pre != "" and col_of.has(pre) and not used.has(int(col_of[pre])):
				c = int(col_of[pre])
			if c < 0:
				c = 0
				while used.has(c):
					c += 1
			used[c] = true
			col_of[String(id)] = c
			ncols = maxi(ncols, c + 1)
	var avail := sz.x - label_w
	var col_w := clampf(avail / float(ncols), UiScale.px(COL_MIN), UiScale.px(COL_MAX))
	var x0 := label_w + maxf(0.0, (avail - col_w * float(ncols)) * 0.5)
	for ri in rows.size():
		var r: Dictionary = rows[ri]
		var cy := row_h * (float(ri) + 0.5)
		_row_y.append(cy)
		var lt := "ур. %d" % int(r["from"]) if int(r["from"]) == int(r["to"]) else "ур. %d–%d" % [int(r["from"]), int(r["to"])]
		var l := Label.new()
		l.text = lt
		var lf := UiScale.fs(UiScale.FONT_SMALL)
		l.add_theme_font_size_override("font_size", lf)
		l.add_theme_color_override("font_color", Color(0.78, 0.8, 0.9))
		l.position = Vector2(0, cy - float(lf) * 0.75)
		l.size = Vector2(label_w - 4.0, float(lf) * 1.5)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
		for id in r["ids"]:
			var sid := String(id)
			var center := Vector2(x0 + col_w * (float(col_of[sid]) + 0.5), cy)
			_center[sid] = center
			var it := _item(sid)
			_pre[sid] = String(it.get("pre", ""))
			_learned[sid] = bool(it.get("learned", false))
			_add_icon(it, center)
	queue_redraw()


## Ярусы: различные требуемые уровни; если не помещаются по высоте h — сливаются ближайшие соседние.
func _make_rows(h: float) -> void:
	rows.clear()
	var levels: Array = []
	for it in items:
		var lv := int((it as Dictionary).get("row", 1))
		if not levels.has(lv):
			levels.append(lv)
	levels.sort()
	var groups: Array = []
	for lv in levels:
		groups.append([lv])
	var max_rows := maxi(1, int(floor(h / row_min())))
	while groups.size() > max_rows:
		var best := 0
		var best_gap := INF
		for i in groups.size() - 1:
			var a: Array = groups[i]
			var b: Array = groups[i + 1]
			var gap := float(int(b[0]) - int(a[a.size() - 1])) + 0.01 * float(a.size() + b.size())
			# Пререквизит и умение не сливаются в один ярус, пока есть другие пары (линия шла бы вбок)
			if _pre_between(a, b):
				gap += 1000.0
			if gap < best_gap:
				best_gap = gap
				best = i
		var merged: Array = groups[best]
		merged.append_array(groups[best + 1])
		groups.remove_at(best + 1)
	for g in groups:
		var ga: Array = g
		var ids: Array = []
		for it in items:
			var d: Dictionary = it
			if ga.has(int(d.get("row", 1))):
				ids.append(String(d["id"]))
		rows.append({"from": int(ga[0]), "to": int(ga[ga.size() - 1]), "ids": ids})


## Есть ли умение яруса b (требуемые уровни), чей пререквизит — в ярусе a.
func _pre_between(a: Array, b: Array) -> bool:
	for it in items:
		var d: Dictionary = it
		if not b.has(int(d.get("row", 1))):
			continue
		var pre := String(d.get("pre", ""))
		if pre == "":
			continue
		var pd := _item(pre)
		if not pd.is_empty() and a.has(int(pd.get("row", 1))):
			return true
	return false


func _item(id: String) -> Dictionary:
	for it in items:
		if String((it as Dictionary)["id"]) == id:
			return it
	return {}


## Номер яруса умения id (-1 — нет).
func row_of(id: String) -> int:
	for i in rows.size():
		if (rows[i]["ids"] as Array).has(id):
			return i
	return -1


## Центр значка id в координатах древа.
func icon_center(id: String) -> Vector2:
	return _center.get(id, Vector2.ZERO)


func _add_icon(it: Dictionary, center: Vector2) -> void:
	var id := String(it["id"])
	var s := icon_size
	var col: Color = it.get("color", Color(0.5, 0.5, 0.6))
	var learned := bool(it.get("learned", false))
	var can := bool(it.get("can", false))
	var kind := String(it.get("kind", "active"))
	var tex := load_icon(String(it.get("icon", "")))

	var b := Button.new()
	b.name = "Skill_" + id
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(s, s)
	b.size = Vector2(s, s)
	b.position = center - Vector2(s, s) * 0.5
	b.tooltip_text = String(it.get("name", id))
	var sb := StyleBoxFlat.new()
	sb.bg_color = (col.darkened(0.15) if tex == null else Color(0.06, 0.07, 0.14, 0.9))
	if kind == "passive" and tex == null:
		sb.bg_color = col.darkened(0.45)
	sb.set_corner_radius_all(int(s * 0.5))
	sb.anti_aliasing = true
	var bw := 3
	sb.border_color = Color(0.45, 0.47, 0.6)
	if learned:
		sb.border_color = col.lightened(0.45)
	if can:
		sb.border_color = GOLD
		sb.shadow_color = Color(1.0, 0.8, 0.3, 0.75)
		sb.shadow_size = int(UiScale.px(8))
	if id == selected:
		sb.border_color = Color.WHITE
		bw = 5
	sb.set_border_width_all(bw)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(_on_pick.bind(id))
	add_child(b)
	icons[id] = b

	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.position = Vector2(3, 3)
		tr.size = Vector2(s - 6.0, s - 6.0)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tr)
	else:
		var g := Label.new()
		g.text = String(it.get("glyph", "?"))
		g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		g.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		g.position = Vector2.ZERO
		g.size = Vector2(s, s)
		g.add_theme_font_size_override("font_size", int(s * 0.44))
		g.add_theme_color_override("font_color", Color.WHITE)
		g.add_theme_color_override("font_outline_color", col.darkened(0.6))
		g.add_theme_constant_override("outline_size", 5)
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(g)
	if kind == "passive":
		# Двойное кольцо: внутренняя окантовка
		var ring := Panel.new()
		var rs := StyleBoxFlat.new()
		rs.draw_center = false
		rs.border_color = Color(1, 1, 1, 0.45)
		rs.set_border_width_all(2)
		rs.set_corner_radius_all(int(s * 0.5) - 5)
		rs.anti_aliasing = true
		ring.add_theme_stylebox_override("panel", rs)
		ring.position = Vector2(5, 5)
		ring.size = Vector2(s - 10.0, s - 10.0)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ring)
	elif kind == "toggle":
		var on := bool(it.get("on", false))
		var dd := UiScale.px(11)
		b.add_child(_dot(Vector2((s - dd) * 0.5, s - dd - 2.0), dd,
			Color(0.35, 1.0, 0.5) if on else Color(1, 1, 1, 0.85)))
	if bool(it.get("unfit", false)):
		var ud := UiScale.px(12)
		b.add_child(_dot(Vector2(s - ud - 1.0, 1.0), ud, Color(1.0, 0.35, 0.3)))
	# Уровень мелко в углу
	var lv := Label.new()
	lv.text = "%d/%d" % [int(it.get("level", 0)), int(it.get("max", 1))]
	var lvf := UiScale.fs(UiScale.FONT_TINY)
	lv.add_theme_font_size_override("font_size", lvf)
	lv.add_theme_color_override("font_color", GOLD if learned else Color(0.85, 0.86, 0.95))
	lv.add_theme_color_override("font_outline_color", Color.BLACK)
	lv.add_theme_constant_override("outline_size", 4)
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lv.position = Vector2(s - float(lvf) * 3.0, s - float(lvf) * 1.35)
	lv.size = Vector2(float(lvf) * 3.0 + 4.0, float(lvf) * 1.5)
	lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(lv)
	if not learned and not can:
		b.modulate = Color(0.5, 0.5, 0.58)


func _dot(pos: Vector2, d: float, c: Color) -> Panel:
	var p := Panel.new()
	var ds := StyleBoxFlat.new()
	ds.bg_color = c
	ds.set_corner_radius_all(int(d * 0.5))
	ds.border_color = Color(0, 0, 0, 0.6)
	ds.set_border_width_all(1)
	ds.anti_aliasing = true
	p.add_theme_stylebox_override("panel", ds)
	p.position = pos
	p.size = Vector2(d, d)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _on_pick(id: String) -> void:
	selected = id
	picked.emit(id)


func _draw() -> void:
	# Тонкие разделители ярусов
	var h := size.y / float(maxi(1, rows.size()))
	for i in range(1, rows.size()):
		draw_line(Vector2(4, h * float(i)), Vector2(size.x - 4.0, h * float(i)), Color(1, 1, 1, 0.07), 1.0)
	# Линии пререквизитов: от нижнего края значка-предка к верхнему краю умения
	var r := icon_size * 0.5
	for id in _pre:
		var pre := String(_pre[id])
		if pre == "" or not _center.has(pre):
			continue
		var a: Vector2 = _center[pre]
		var b: Vector2 = _center[id]
		var d := b - a
		if d.length() < 1.0:
			continue
		var n := d.normalized()
		var col := LINE_ON if bool(_learned.get(id, false)) else LINE_OFF
		draw_line(a + n * (r + 2.0), b - n * (r + 2.0), col, 3.0, true)
