class_name StatusRow
extends Control
## Ряд значков эффектов (StatusEffects) у полоски HP: игрок, питомец, цель (HUD).
## Каждый эффект — круглый значок источника (IconView), рамка: светло-зелёная — баф, красная — дебаф,
## золотая — включённое переключаемое (без таймера). Истёкшая доля времени — тёмный сектор от 12 часов
## по часовой стрелке (значок «исчезает по часовой стрелке»); кончился — значка нет.
## Не помещаются (max_w) — последний значок «+N». Узлы-значки создаются один раз и переиспользуются:
## перестройка только при смене набора (StatusEffects.version), каждый кадр — лишь сектор у видимых.

const BUFF := Color(0.55, 1.0, 0.6)
const DEBUFF := Color(1.0, 0.3, 0.25)
const TOGGLE := Color(1.0, 0.82, 0.35)

## Источник (null — ряд пуст).
var source: StatusEffects = null
## Размер значка и зазор, px (уже с масштабом), наибольшая ширина ряда.
var icon_px := 26.0
var gap := 4.0
var max_w := 200.0

var _icons: Array[IconView] = []
## Какая запись реестра на каком значке (параллельно _icons; лишние значки скрыты).
var _shown: Array[Dictionary] = []
var _more: Label = null
var _version := -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func bind(src: StatusEffects) -> void:
	if src != source:
		source = src
		_version = -1


## Размер значка, зазор и ширина ряда (после смены масштаба интерфейса) — перестроить.
func set_layout(px: float, g: float, w: float) -> void:
	if is_equal_approx(px, icon_px) and is_equal_approx(g, gap) and is_equal_approx(w, max_w):
		return
	icon_px = px
	gap = g
	max_w = w
	_version = -1


## Сколько значков помещается в ряд.
func capacity() -> int:
	return maxi(1, int((max_w + gap) / (icon_px + gap)))


## Каждый кадр: при смене набора — перестроить, иначе только сектора времени.
func refresh() -> void:
	if source == null or not visible_in_tree_safe():
		if source == null and not _shown.is_empty():
			_rebuild()
		return
	if source.version != _version:
		_rebuild()
	for i in _shown.size():
		var e: Dictionary = _shown[i]
		if not bool(e.get("toggle", false)):
			_icons[i].set_sector(0.0, 1.0 - StatusEffects.left_frac(e))


func visible_in_tree_safe() -> bool:
	return is_inside_tree() and is_visible_in_tree()


## Записи на видимых значках (для тестов и подписей).
func shown() -> Array[Dictionary]:
	return _shown


func icon(i: int) -> IconView:
	return _icons[i] if i < _icons.size() else null


## Сколько эффектов спрятано под «+N» (0 — все видны).
func hidden_count() -> int:
	if source == null:
		return 0
	return maxi(0, source.entries().size() - _shown.size())


## Запись эффекта под точкой p (координаты экрана); пусто — мимо.
func entry_at(p: Vector2) -> Dictionary:
	if not visible_in_tree_safe():
		return {}
	for i in _shown.size():
		if _icons[i].get_global_rect().grow(2.0).has_point(p):
			return _shown[i]
	if _more != null and _more.visible and _more.get_global_rect().has_point(p):
		return {"name": "Ещё эффектов: %d" % hidden_count(), "toggle": true}
	return {}


func _rebuild() -> void:
	_version = source.version if source != null else -1
	_shown.clear()
	var list: Array[Dictionary] = []
	if source != null:
		list = source.entries()
	var cap := capacity()
	var n := list.size() if list.size() <= cap else cap - 1
	while _icons.size() < n:
		var ic := IconView.new()
		add_child(ic)
		_icons.append(ic)
	var step := icon_px + gap
	for i in _icons.size():
		var ic := _icons[i]
		ic.visible = i < n
		if i >= n:
			continue
		var e: Dictionary = list[i]
		_shown.append(e)
		ic.position = Vector2(step * float(i), 0)
		ic.size = Vector2(icon_px, icon_px)
		ic.set_spec(e.get("icon", {}))
		var col := TOGGLE if bool(e.get("toggle", false)) else (DEBUFF if bool(e.get("debuff", false)) else BUFF)
		ic.set_ring(col, maxf(2.0, icon_px * 0.09))
		ic.set_sector(0.0, 0.0 if bool(e.get("toggle", false)) else 1.0 - StatusEffects.left_frac(e))
	var extra := list.size() - n
	if extra > 0:
		if _more == null:
			_more = Label.new()
			_more.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_more.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_more.add_theme_color_override("font_outline_color", Color.BLACK)
			add_child(_more)
		_more.text = "+%d" % extra
		_more.add_theme_font_size_override("font_size", maxi(10, int(icon_px * 0.5)))
		_more.add_theme_constant_override("outline_size", 4)
		_more.position = Vector2(step * float(n), 0)
		_more.size = Vector2(icon_px, icon_px)
	if _more != null:
		_more.visible = extra > 0
	var count := n + (1 if extra > 0 else 0)
	size = Vector2(maxf(0.0, step * float(count) - gap), icon_px)
