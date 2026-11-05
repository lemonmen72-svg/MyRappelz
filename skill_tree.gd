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
## Крупный режим (setup(…, true); окно существа — вкладки «Активные», «Ауры и бафы», «Пассивные»): значки до
## ICON_BIG, ярус может переноситься на несколько строк (подпись «ур. N» — у первой), раскладка (сколько ярусов
## слить, сколько значков в строке) выбирается та, где значки крупнее всего.
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
## Крупный режим: наибольшие значок, строка и колонка; наименьший значок (касание на телефоне).
const ICON_BIG := 86.0
const ROW_BIG := 104.0
const COL_BIG := 124.0
const ICON_BIG_MIN := 40.0
## Крупный режим: ярусов — сколько можно, пока значки не мельче этой доли самой крупной раскладки.
const BIG_KEEP := 0.86
## Крупный режим: до стольких разных уровней перебираются все разбиения на ярусы (больше — слияние ближайших).
const BIG_PARTITION_MAX := 12
## Крупный режим: ширина подписи яруса.
const LABEL_BIG := 86.0
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
## Крупный режим (переносы ярусов, значки до ICON_BIG).
var big := false
## Строки значков (в крупном режиме ярус бывает в нескольких строках): [{"ids": [...], "row": ярус, "first": bool}].
var lines: Array = []

## Центры значков и пререквизиты (для линий).
var _center: Dictionary = {}
var _pre: Dictionary = {}
var _learned: Dictionary = {}
var _row_y: Array = []
## Высоты разделителей ярусов.
var _sep_y: Array = []

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


## Строит древо в прямоугольнике sz. sel — выделенное умение; big_mode — крупные значки (см. шапку).
func setup(list: Array, sz: Vector2, sel: String = "", big_mode: bool = false) -> void:
	items = list
	selected = sel
	big = big_mode
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
	_sep_y.clear()
	lines.clear()
	if big:
		_setup_big(sz)
		queue_redraw()
		return
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
	# Много умений в ярусе (у питомцев с 0.31 — до 32 умений) — колонки уже, значки мельче, всё внутри древа
	var col_w := minf(avail / float(ncols), UiScale.px(COL_MAX))
	icon_size = minf(icon_size, col_w - UiScale.px(6))
	var x0 := label_w + maxf(0.0, (avail - col_w * float(ncols)) * 0.5)
	for ri in rows.size():
		var r: Dictionary = rows[ri]
		var cy := row_h * (float(ri) + 0.5)
		_row_y.append(cy)
		lines.append({"ids": r["ids"], "row": ri, "first": true})
		if ri > 0:
			_sep_y.append(row_h * float(ri))
		_add_row_label(r, cy, label_w, UiScale.FONT_SMALL)
		for id in r["ids"]:
			var sid := String(id)
			var center := Vector2(x0 + col_w * (float(col_of[sid]) + 0.5), cy)
			_center[sid] = center
			var it := _item(sid)
			_pre[sid] = String(it.get("pre", ""))
			_learned[sid] = bool(it.get("learned", false))
			_add_icon(it, center)
	queue_redraw()


## Подпись яруса «ур. 5» / «ур. 5–6» слева от строки с центром cy.
func _add_row_label(r: Dictionary, cy: float, label_w: float, font: int) -> void:
	var lt := "ур. %d" % int(r["from"]) if int(r["from"]) == int(r["to"]) else "ур. %d–%d" % [int(r["from"]), int(r["to"])]
	var l := Label.new()
	l.text = lt
	var lf := UiScale.fs(font)
	l.add_theme_font_size_override("font_size", lf)
	l.add_theme_color_override("font_color", Color(0.78, 0.8, 0.9))
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.position = Vector2(0, cy - float(lf) * 0.75)
	l.size = Vector2(label_w - 4.0, float(lf) * 1.5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)


## Крупный режим: перебор числа ярусов (слияние соседних уровней) и значков в строке — самые крупные значки.
func _setup_big(sz: Vector2) -> void:
	rows.clear()
	var levels := _levels()
	if levels.is_empty():
		return
	var label_w := UiScale.px(LABEL_BIG)
	var avail := sz.x - label_w
	var pad := UiScale.px(16)
	# Варианты ярусов: все разбиения уровней на соседние группы (уровней мало — до 2^(n−1)), при многих уровнях —
	# слияние ближайших (_group_levels). Для каждого — лучшее число значков в строке; ярус, где пререквизит слит
	# с умением, — хуже (×0.88)
	var parts: Array = []
	if levels.size() <= BIG_PARTITION_MAX:
		for mask in 1 << (levels.size() - 1):
			var groups: Array = [[levels[0]]]
			for i in range(1, levels.size()):
				if mask & (1 << (i - 1)):
					groups.append([levels[i]])
				else:
					(groups[groups.size() - 1] as Array).append(levels[i])
			parts.append(groups)
	else:
		for nr in range(levels.size(), 0, -1):
			parts.append(_group_levels(levels, nr))
	var cands: Array = []
	var top := 0.0
	for groups in parts:
		var counts: Array = []
		var most := 1
		var pre_merged := false
		for g in groups:
			var n := _ids_of(g).size()
			counts.append(n)
			most = maxi(most, n)
			pre_merged = pre_merged or _pre_inside(g)
		var nr_icon := -1.0
		var nr_c := 1
		for c in range(1, most + 1):
			var nl := 0
			for n in counts:
				nl += maxi(1, ceili(float(n) / float(c)))
			var row_h := minf(UiScale.px(ROW_BIG), sz.y / float(nl))
			var col_w := minf(UiScale.px(COL_BIG), avail / float(c))
			var ic := minf(minf(row_h - pad, col_w - UiScale.px(8)), UiScale.px(ICON_BIG))
			if ic > nr_icon + 0.5:
				nr_icon = ic
				nr_c = c
		var score := nr_icon * (0.88 if pre_merged else 1.0)
		top = maxf(top, score)
		cands.append([(groups as Array).size(), groups, nr_c, nr_icon, score])
	# Больше ярусов (уровни видны), пока значки не мельче BIG_KEEP самой крупной раскладки; при равных — крупнее
	var best_icon := -1.0
	var best_groups: Array = []
	var best_c := 1
	var best_n := -1
	for cd in cands:
		if float(cd[4]) < top * BIG_KEEP:
			continue
		if int(cd[0]) > best_n or (int(cd[0]) == best_n and float(cd[4]) > best_icon + 0.5):
			best_n = int(cd[0])
			best_groups = cd[1]
			best_c = int(cd[2])
			best_icon = float(cd[4])
	if best_groups.is_empty():
		best_groups = [levels]
	for cd in cands:
		if cd[1] == best_groups:
			best_icon = float(cd[3])
	icon_size = maxf(best_icon, UiScale.px(ICON_BIG_MIN))
	var nlines := 0
	for g in best_groups:
		nlines += maxi(1, ceili(float(_ids_of(g).size()) / float(best_c)))
	var row_h := minf(UiScale.px(ROW_BIG), sz.y / float(maxi(1, nlines)))
	var col_w := minf(UiScale.px(COL_BIG), avail / float(best_c))
	var x0 := label_w + maxf(0.0, (avail - col_w * float(best_c)) * 0.5)
	# Сетка по центру высоты, если строк мало
	var y0 := maxf(0.0, (sz.y - row_h * float(nlines)) * 0.5)
	var col_of: Dictionary = {}
	var li := 0
	for gi in best_groups.size():
		var g: Array = best_groups[gi]
		var ids := _ids_of(g)
		rows.append({"from": int(g[0]), "to": int(g[g.size() - 1]), "ids": ids})
		if gi > 0:
			_sep_y.append(y0 + row_h * float(li))
		var chunks: Array = []
		var k := 0
		while k < ids.size():
			chunks.append(ids.slice(k, mini(k + best_c, ids.size())))
			k += best_c
		if chunks.is_empty():
			chunks.append([])
		for ci in chunks.size():
			var line_ids: Array = chunks[ci]
			var cy := y0 + row_h * (float(li) + 0.5)
			_row_y.append(cy)
			lines.append({"ids": line_ids, "row": gi, "first": ci == 0})
			if ci == 0:
				_add_row_label(rows[gi], cy, label_w, UiScale.FONT_SMALL)
			# Колонка: под пререквизитом, если она свободна в этой строке; иначе первая свободная
			var used: Dictionary = {}
			var place: Dictionary = {}
			for id in line_ids:
				var pre := String(_item(String(id)).get("pre", ""))
				if pre != "" and col_of.has(pre) and int(col_of[pre]) < best_c and not used.has(int(col_of[pre])):
					place[String(id)] = int(col_of[pre])
					used[int(col_of[pre])] = true
			for id in line_ids:
				if place.has(String(id)):
					continue
				var c := 0
				while used.has(c):
					c += 1
				place[String(id)] = c
				used[c] = true
			for id in line_ids:
				var sid := String(id)
				col_of[sid] = int(place[sid])
				var center := Vector2(x0 + col_w * (float(place[sid]) + 0.5), cy)
				_center[sid] = center
				var it := _item(sid)
				_pre[sid] = String(it.get("pre", ""))
				_learned[sid] = bool(it.get("learned", false))
				_add_icon(it, center)
			li += 1


## Пререквизит и умение — оба в группе уровней g.
func _pre_inside(g: Array) -> bool:
	for it in items:
		var d: Dictionary = it
		var pre := String(d.get("pre", ""))
		if pre == "" or not g.has(int(d.get("row", 1))):
			continue
		var pd := _item(pre)
		if not pd.is_empty() and g.has(int(pd.get("row", 1))):
			return true
	return false


## Требуемые уровни умений (ярусы до слияния), по возрастанию.
func _levels() -> Array:
	var levels: Array = []
	for it in items:
		var lv := int((it as Dictionary).get("row", 1))
		if not levels.has(lv):
			levels.append(lv)
	levels.sort()
	return levels


## id умений с требуемым уровнем из группы g (в порядке items; в крупном режиме — по уровню, при равном — как в items).
func _ids_of(g: Array) -> Array:
	var ids: Array = []
	if big:
		for lv in g:
			for it in items:
				var d: Dictionary = it
				if int(d.get("row", 1)) == int(lv):
					ids.append(String(d["id"]))
		return ids
	for it in items:
		var d: Dictionary = it
		if g.has(int(d.get("row", 1))):
			ids.append(String(d["id"]))
	return ids


## Ярусы: различные требуемые уровни; если не помещаются по высоте h — сливаются ближайшие соседние.
func _make_rows(h: float) -> void:
	rows.clear()
	var max_rows := maxi(1, int(floor(h / row_min())))
	for g in _group_levels(_levels(), max_rows):
		var ga: Array = g
		rows.append({"from": int(ga[0]), "to": int(ga[ga.size() - 1]), "ids": _ids_of(ga)})


## Уровни levels группами, не больше max_rows групп: сливаются ближайшие соседние (пререквизит и умение — в последнюю
## очередь).
func _group_levels(levels: Array, max_rows: int) -> Array:
	var groups: Array = []
	for lv in levels:
		groups.append([lv])
	while groups.size() > maxi(1, max_rows):
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
		var merged: Array = (groups[best] as Array).duplicate()
		merged.append_array(groups[best + 1])
		groups[best] = merged
		groups.remove_at(best + 1)
	return groups


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
		var dd := UiScale.px(11) if not big else maxf(UiScale.px(11), s * 0.16)
		b.add_child(_dot(Vector2((s - dd) * 0.5, s - dd - 2.0), dd,
			Color(0.35, 1.0, 0.5) if on else Color(1, 1, 1, 0.85)))
	if bool(it.get("unfit", false)):
		var ud := UiScale.px(12)
		b.add_child(_dot(Vector2(s - ud - 1.0, 1.0), ud, Color(1.0, 0.35, 0.3)))
	# Уровень мелко в углу
	var lv := Label.new()
	lv.text = "%d/%d" % [int(it.get("level", 0)), int(it.get("max", 1))]
	var lvf := UiScale.fs(UiScale.FONT_SMALL if big else UiScale.FONT_TINY)
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
	for y in _sep_y:
		draw_line(Vector2(4, float(y)), Vector2(size.x - 4.0, float(y)), Color(1, 1, 1, 0.07), 1.0)
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
