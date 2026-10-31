class_name IconView
extends Control
## Круглый значок: умение, предмет или простой рисунок. Общий для кнопок HUD (умения, «Атака», «Зелье»,
## «Приручить», «Говорить», «Торговец») и значков эффектов у панелей HP (StatusRow).
## Спецификация значка (set_spec) — словарь:
##   "path": PNG умения (res://assets/icons/skills/<id>.png и т. п.; грузится через SkillTree.load_icon, как в древе),
##   "item": id предмета (картинка ItemIcon.texture или процедурный значок ItemIcon),
##   "shape": простой рисунок ("sword", "talk", "shop"), "glyph" + "color": кружок с буквой (как в древе умений,
##   когда картинки нет). Порядок: path (если файл есть) → item → shape → glyph.
## Картинка вписана в круг (полигон-круг с UV — маска круга). Поверх (отдельный узел, перерисовывается без
## картинки): тёмный сектор от 12 часов по часовой стрелке (set_sector — перезарядка кнопки или истёкшая доля
## эффекта), кольцо-рамка (set_ring), число в углу (set_count), красная метка «нельзя» (set_blocked).

## Сторон у многоугольника-круга.
const SEGMENTS := 40
## Затемнение сектора.
const SHADE := Color(0.0, 0.0, 0.05, 0.62)

## Слой поверх картинки (и поверх дочернего ItemIcon): сектор, кольцо, число, метка.
class _Overlay:
	extends Control
	var view: IconView

	func _draw() -> void:
		view._draw_overlay(self)


## Текущая спецификация (set_spec). Предмет без картинки рисует дочерний ItemIcon, всё остальное — _draw.
var spec: Dictionary = {}

var _spec_hash := 0
var _tex: Texture2D = null
var _item: ItemIcon = null
var _over: _Overlay = null
var _circle := PackedVector2Array()
var _uvs := PackedVector2Array()
var _sector_pts := PackedVector2Array()
var _sec_from := 0.0
var _sec_to := 0.0
var _ring := Color(0, 0, 0, 0)
var _ring_w := 0.0
var _count := -1
var _blocked := false


## Значок умения героя (древо HeroSkills, у других классов — обёртка ClassData).
static func hero_skill(id: String) -> Dictionary:
	var sk := HeroSkills.get_skill(id)
	return {"path": HeroSkills.icon_path(id), "glyph": String(sk.get("glyph", "?")),
		"color": sk.get("color", Color(0.5, 0.5, 0.6))}


## Значок умения питомца вида species (картинки у видов свои).
static func pet_skill(species: String, id: String) -> Dictionary:
	var sk := PetSkills.get_skill(id)
	return {"path": CreatureWindow.icon_path(species, id), "glyph": String(sk.get("glyph", "?")),
		"color": sk.get("color", Color(0.5, 0.5, 0.6))}


static func item(id: String) -> Dictionary:
	return {"item": id}


## Буква на цветном кружке.
static func glyph(text: String, col: Color) -> Dictionary:
	return {"glyph": text, "color": col}


static func shape(kind: String, col: Color) -> Dictionary:
	return {"shape": kind, "color": col}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over = _Overlay.new()
	_over.view = self
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_over)
	resized.connect(_on_resized)


func set_spec(s: Dictionary) -> void:
	var h := s.hash()
	if h == _spec_hash and not spec.is_empty():
		return
	_spec_hash = h
	spec = s
	_tex = SkillTree.load_icon(String(s.get("path", "")))
	var item_id := String(s.get("item", ""))
	if _tex == null and item_id != "":
		_tex = ItemIcon.texture(item_id)
	var need_item := _tex == null and item_id != ""
	if need_item and _item == null:
		_item = ItemIcon.make(item_id, size.x)
		_item.custom_minimum_size = Vector2.ZERO
		add_child(_item)
		move_child(_over, -1)
	if _item != null:
		_item.visible = need_item
		if need_item:
			_item.set_item(item_id)
	_on_resized()


## Тёмный сектор от доли a0 до a1 окружности (0 — 12 часов, по часовой стрелке); a0 >= a1 — без сектора.
## Перерисовывается только при заметном изменении (меньше пикселя дуги — нет).
func set_sector(a0: float, a1: float) -> void:
	a0 = clampf(a0, 0.0, 1.0)
	a1 = clampf(a1, 0.0, 1.0)
	if a1 - a0 < 0.004:
		a0 = 0.0
		a1 = 0.0
	if absf(a0 - _sec_from) < 0.004 and absf(a1 - _sec_to) < 0.004 and (a1 > 0.0) == (_sec_to > 0.0):
		return
	_sec_from = a0
	_sec_to = a1
	_over.queue_redraw()


func sector() -> Vector2:
	return Vector2(_sec_from, _sec_to)


func set_ring(c: Color, w: float) -> void:
	if c == _ring and is_equal_approx(w, _ring_w):
		return
	_ring = c
	_ring_w = w
	_over.queue_redraw()


## Число в правом нижнем углу (-1 — нет).
func set_count(n: int) -> void:
	if n != _count:
		_count = n
		_over.queue_redraw()


func count() -> int:
	return _count


func set_blocked(b: bool) -> void:
	if b != _blocked:
		_blocked = b
		_over.queue_redraw()


## Есть ли картинка (иначе рисунок или буква).
func has_texture() -> bool:
	return _tex != null


func _on_resized() -> void:
	_over.position = Vector2.ZERO
	_over.size = size
	var r := minf(size.x, size.y) * 0.5
	var c := size * 0.5
	_circle.resize(SEGMENTS)
	_uvs.resize(SEGMENTS)
	for i in SEGMENTS:
		var a := TAU * float(i) / float(SEGMENTS)
		var d := Vector2(cos(a), sin(a))
		_circle[i] = c + d * r
		_uvs[i] = Vector2(0.5, 0.5) + d * 0.5
	if _item != null:
		var s := r * 2.0 * 0.86
		_item.size = Vector2(s, s)
		_item.position = c - Vector2(s, s) * 0.5
	queue_redraw()
	_over.queue_redraw()


func _draw() -> void:
	if size.x < 2.0:
		return
	var r := minf(size.x, size.y) * 0.5
	var c := size * 0.5
	var col: Color = spec.get("color", Color(0.45, 0.47, 0.6))
	if _tex != null:
		draw_circle(c, r, Color(0.06, 0.07, 0.14, 0.9))
		draw_colored_polygon(_circle, Color.WHITE, _uvs, _tex)
		return
	if _item != null and _item.visible:
		draw_circle(c, r, Color(0.08, 0.09, 0.18, 0.85))
		return
	var shp := String(spec.get("shape", ""))
	if shp != "":
		draw_circle(c, r, Color(0.08, 0.09, 0.18, 0.85))
		_draw_shape(shp, c, r, col)
		return
	draw_circle(c, r, col.darkened(0.15))
	var g := String(spec.get("glyph", ""))
	if g != "":
		var font := get_theme_default_font()
		var fs := maxi(8, int(r * 0.95))
		var w := font.get_string_size(g, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(c.x - w * 0.5, c.y + font.get_ascent(fs) * 0.5 - font.get_descent(fs) * 0.35)
		draw_string_outline(font, pos, g, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(2, int(r * 0.18)), col.darkened(0.6))
		draw_string(font, pos, g, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


## Простые рисунки кнопок HUD: меч (атака без оружия), облачко речи, мешочек с монетами.
func _draw_shape(shp: String, c: Color, r: float, col: Color) -> void:
	var ink := Color(0.08, 0.06, 0.12, 0.95)
	match shp:
		"sword":
			var d := Vector2(1, -1).normalized()
			var n := Vector2(d.y, -d.x)
			var tip := c + d * r * 0.62
			var base := c - d * r * 0.25
			var blade := PackedVector2Array([base + n * r * 0.11, tip, base - n * r * 0.11])
			draw_colored_polygon(blade, col.lightened(0.55))
			draw_polyline(PackedVector2Array([blade[0], blade[1], blade[2], blade[0]]), ink, 1.5, true)
			draw_line(base + n * r * 0.3, base - n * r * 0.3, col.darkened(0.2), maxf(2.0, r * 0.12), true)
			draw_line(base, c - d * r * 0.55, Color(0.45, 0.3, 0.2), maxf(2.0, r * 0.13), true)
		"talk":
			var rect := Rect2(c.x - r * 0.55, c.y - r * 0.45, r * 1.1, r * 0.72)
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.97, 0.95, 0.88)
			sb.set_corner_radius_all(int(r * 0.25))
			sb.anti_aliasing = true
			draw_style_box(sb, rect)
			var tail := PackedVector2Array([Vector2(c.x - r * 0.25, rect.end.y - 1.0), Vector2(c.x - r * 0.38, c.y + r * 0.55),
				Vector2(c.x - r * 0.02, rect.end.y - 1.0)])
			draw_colored_polygon(tail, Color(0.97, 0.95, 0.88))
			for i in 3:
				draw_circle(Vector2(c.x + (float(i) - 1.0) * r * 0.3, rect.get_center().y), maxf(1.5, r * 0.08), col.darkened(0.3))
		"shop":
			var bag := c + Vector2(0, r * 0.12)
			draw_circle(bag, r * 0.45, Color(0.72, 0.52, 0.3))
			draw_colored_polygon(PackedVector2Array([bag + Vector2(-r * 0.2, -r * 0.38), bag + Vector2(r * 0.2, -r * 0.38),
				bag + Vector2(r * 0.3, -r * 0.62), bag + Vector2(-r * 0.3, -r * 0.62)]), Color(0.72, 0.52, 0.3))
			draw_line(bag + Vector2(-r * 0.22, -r * 0.38), bag + Vector2(r * 0.22, -r * 0.38), ink, maxf(1.5, r * 0.07), true)
			draw_circle(bag + Vector2(r * 0.05, r * 0.05), r * 0.2, Color(1.0, 0.85, 0.3))
			draw_arc(bag + Vector2(r * 0.05, r * 0.05), r * 0.2, 0.0, TAU, 20, ink, 1.2, true)
		_:
			draw_circle(c, r * 0.5, col)


## Сектор, кольцо, число и метка — на слое поверх картинки.
func _draw_overlay(ci: Control) -> void:
	var r := minf(size.x, size.y) * 0.5
	if r < 1.0:
		return
	var c := size * 0.5
	if _sec_to > _sec_from:
		var span := _sec_to - _sec_from
		var n := maxi(2, ceili(span * float(SEGMENTS)))
		_sector_pts.resize(n + 2)
		_sector_pts[0] = c
		for i in n + 1:
			var a := -PI * 0.5 + TAU * (_sec_from + span * float(i) / float(n))
			_sector_pts[i + 1] = c + Vector2(cos(a), sin(a)) * r
		if span >= 0.999:
			ci.draw_circle(c, r, SHADE)
		else:
			ci.draw_colored_polygon(_sector_pts, SHADE)
	if _ring_w > 0.0 and _ring.a > 0.0:
		ci.draw_arc(c, r - _ring_w * 0.5, 0.0, TAU, SEGMENTS, _ring, _ring_w, true)
	if _blocked:
		var bc := c + Vector2(r, r) * 0.62
		var br := maxf(4.0, r * 0.3)
		ci.draw_circle(bc, br, Color(0.85, 0.15, 0.15))
		ci.draw_line(bc - Vector2(br * 0.55, 0), bc + Vector2(br * 0.55, 0), Color.WHITE, maxf(1.5, br * 0.35), true)
	if _count >= 0:
		var font := get_theme_default_font()
		var fs := maxi(10, int(r * 0.62))
		var t := str(_count)
		var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(size.x - w - r * 0.08, size.y - r * 0.08)
		ci.draw_string_outline(font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color.BLACK)
		ci.draw_string(font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.97, 0.85))
