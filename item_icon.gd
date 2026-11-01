class_name ItemIcon
extends Control
## Значок предмета (ячейки сумки, слоты экипировки, товары торговца, карточка предмета).
## Картинка: res://assets/icons/items/<id предмета>.png (PNG 128×128 с прозрачными углами), загружается только
## через load() после Assets.exists (часть «icons» пакета ресурсов; без неё картинки «нет»). Нет картинки — процедурный значок по полю
## "icon" предмета (ItemData.icon_shape): мягкий круг цвета типа и простой силуэт (колба, свиток, карта существа,
## кристалл, клинки, арбалет, клык, шкура, перо, пластина, осколок, чешуя, плавник); неизвестный — первая буква названия.
## Карта существа: вертикальная карточка с рамкой цвета тира и буквой вида; с душой — яркая, с сиянием;
## зеркальная — серебристая с бликами отражения.
## Зелья: картинка одна на вид и размер колбы (ItemData.icon_path: potion_<вид>_t<1|2|3>.png — ранги 1–5, 6–10,
## 11–15), без картинки — колба цвета вида, крупнее с размером; номер ранга — римской цифрой в правом верхнем углу.
## Оружие 2-го ранга и выше — номер ранга в углу тоже, кубы чарования — всегда.
## Заточенная вещь («<id>+N», ItemData «Чарование») — значок базовой вещи и «+N» в левом верхнем углу; сломанная —
## картинка broken_weapon / broken_armor (поле icon_file), без картинки — силуэт вещи серым с красной трещиной.

## Цвет контуров силуэтов.
const INK := Color(0.08, 0.06, 0.12, 0.95)

## Предмет; "" — пустой значок.
var item_id := ""

static var _tex_cache: Dictionary = {}


## Картинка значка предмета или null (файла нет).
static func texture(id: String) -> Texture2D:
	if id == "":
		return null
	var path := ItemData.icon_path(id)
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


static func make(id: String, sz: float) -> ItemIcon:
	var ic := ItemIcon.new()
	ic.item_id = id
	ic.custom_minimum_size = Vector2(sz, sz)
	ic.size = Vector2(sz, sz)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ic


func set_item(id: String) -> void:
	item_id = id
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if item_id == "":
		return
	var tex := texture(item_id)
	if tex != null:
		draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
		_rank_mark()
		_enchant_mark()
		return
	var base: Color = ItemData.get_item(item_id).get("color", Color.WHITE)
	# Мягкий фон цвета рамки
	var fc := ItemData.frame_color(item_id)
	draw_circle(_p(0.5, 0.5), _s(0.46), Color(fc.r, fc.g, fc.b, 0.16))
	draw_circle(_p(0.5, 0.5), _s(0.36), Color(fc.r, fc.g, fc.b, 0.14))
	match ItemData.icon_shape(item_id):
		"flask":
			if ItemData.is_potion(item_id):
				# Размер колбы по рангу: малая (1–5), средняя (6–10), большая (11–15)
				var sizes: Array = [0.78, 0.9, 1.04]
				var k: float = sizes[ItemData.potion_tier(ItemData.rank(item_id)) - 1]
				var c := _p(0.5, 0.56)
				draw_set_transform(c - c * k, 0.0, Vector2(k, k))
				_flask(base)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				_flask(base)
		"scroll":
			_scroll(base)
		"card":
			_card(base)
		"crystal":
			_crystal(base)
		"daggers":
			_blade(_p(0.30, 0.74), Vector2(1.0, -1.25), 0.40, 0.085, base)
			_blade(_p(0.70, 0.74), Vector2(-1.0, -1.25), 0.40, 0.085, base)
		"swords":
			_blade(_p(0.24, 0.80), Vector2(1.0, -1.1), 0.62, 0.075, base)
			_blade(_p(0.76, 0.80), Vector2(-1.0, -1.1), 0.62, 0.075, base)
		"dagger":
			_blade(_p(0.34, 0.74), Vector2(1.0, -1.25), 0.46, 0.09, base)
		"sword":
			_blade(_p(0.28, 0.80), Vector2(1.0, -1.1), 0.66, 0.08, base)
		"crossbow":
			_crossbow(base)
		"spear":
			_spear(base)
		"bow":
			_bow(base)
		"fang":
			_fang(base)
		"pelt":
			_pelt(base)
		"feather":
			_feather(base)
		"plate":
			_plate(base)
		"shard":
			_shard(base)
		"scale":
			_fish_scale(base)
		"fin":
			_fin(base)
		"spike":
			_spike(base)
		"cube":
			_cube(base)
		_:
			_letter(base)
	if ItemData.is_broken(item_id):
		_crack()
	_rank_mark()
	_enchant_mark()


## Номер ранга в правом верхнем углу: у зелий — всегда, у снаряжения — со 2-го ранга.
func _rank_mark() -> void:
	var on := ItemData.is_potion(item_id) or ItemData.is_cube(item_id) \
		or (ItemData.is_equipment(item_id) and ItemData.rank(item_id) >= 2)
	if not on:
		return
	var font := ThemeDB.fallback_font
	var fs := maxi(8, int(_s(0.3)))
	var t := ItemData.roman(ItemData.rank(item_id))
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(size.x - w - _s(0.06), _s(0.06) + font.get_ascent(fs))
	draw_string_outline(font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(2, int(_s(0.05))), INK)
	draw_string(font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.93, 0.6))


# ---------- Координаты: доли размера значка ----------

func _p(x: float, y: float) -> Vector2:
	return Vector2(x * size.x, y * size.y)


func _s(v: float) -> float:
	return v * minf(size.x, size.y)


func _poly(pts: Array) -> PackedVector2Array:
	var res := PackedVector2Array()
	for e in pts:
		var v: Vector2 = e
		res.append(_p(v.x, v.y))
	return res


func _outline(pts: PackedVector2Array, c: Color, w: float) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, c, w, true)


# ---------- Силуэты ----------

## Колба с зельем: круглое донышко, горлышко, пробка, блик.
func _flask(c: Color) -> void:
	var glass := Color(0.85, 0.92, 1.0, 0.55)
	draw_rect(Rect2(_p(0.42, 0.22), _p(0.16, 0.22)), glass)
	draw_circle(_p(0.5, 0.62), _s(0.25), INK)
	draw_circle(_p(0.5, 0.62), _s(0.23), glass)
	draw_circle(_p(0.5, 0.64), _s(0.19), c)
	draw_circle(_p(0.5, 0.68), _s(0.14), c.darkened(0.2))
	draw_rect(Rect2(_p(0.39, 0.13), _p(0.22, 0.11)), Color(0.62, 0.42, 0.24))
	draw_rect(Rect2(_p(0.39, 0.13), _p(0.22, 0.11)), INK, false, _s(0.025))
	draw_rect(Rect2(_p(0.42, 0.24), _p(0.16, 0.18)), INK, false, _s(0.02))
	draw_circle(_p(0.42, 0.56), _s(0.05), Color(1, 1, 1, 0.85))
	draw_circle(_p(0.58, 0.72), _s(0.025), Color(1, 1, 1, 0.5))


## Свиток: лист с двумя валиками, строчки и печать.
func _scroll(c: Color) -> void:
	var paper := _poly([Vector2(0.26, 0.28), Vector2(0.74, 0.28), Vector2(0.74, 0.74), Vector2(0.26, 0.74)])
	draw_colored_polygon(paper, c)
	_outline(paper, INK, _s(0.025))
	var roll := c.darkened(0.35)
	for yv in [0.26, 0.74]:
		var y := float(yv)
		var r := Rect2(_p(0.18, y - 0.055), _p(0.64, 0.11))
		draw_rect(r, roll)
		draw_rect(r, INK, false, _s(0.022))
		draw_circle(_p(0.18, y), _s(0.055), roll.darkened(0.2))
		draw_circle(_p(0.82, y), _s(0.055), roll.darkened(0.2))
	var ink := Color(0.45, 0.32, 0.2, 0.9)
	for i in 3:
		var y := 0.4 + 0.08 * float(i)
		draw_line(_p(0.33, y), _p(0.67 - 0.08 * float(i), y), ink, _s(0.025), true)
	draw_circle(_p(0.64, 0.62), _s(0.065), Color(0.85, 0.2, 0.25))
	draw_circle(_p(0.64, 0.62), _s(0.03), Color(1.0, 0.75, 0.4))


## Карта существа: вертикальная карточка, рамка цвета тира, в центре буква вида. С душой — яркий фон,
## сияние и искры; зеркальная — серебро с косыми бликами.
func _card(c: Color) -> void:
	var sp := ItemData.card_species(item_id)
	var soul := ItemData.is_soul_card(item_id)
	var frame := ItemData.frame_color(item_id)
	var r := Rect2(_p(0.22, 0.1), _p(0.56, 0.8))
	if soul:
		# Сияние вокруг карты
		draw_circle(_p(0.5, 0.5), _s(0.47), Color(frame.r, frame.g, frame.b, 0.22))
		draw_circle(_p(0.5, 0.5), _s(0.4), Color(1.0, 0.95, 0.75, 0.18))
	var bg := c.darkened(0.55)
	if sp == "":
		bg = Color(0.62, 0.68, 0.78)
	elif soul:
		bg = c.lerp(Color.WHITE, 0.15)
	draw_rect(r.grow(_s(0.025)), INK)
	draw_rect(r, frame)
	var inner := r.grow(-_s(0.05))
	draw_rect(inner, bg)
	if sp == "":
		# Зеркало: косые блики и отражение рамки
		var hl := Color(1, 1, 1, 0.55)
		draw_line(_p(0.3, 0.42), _p(0.52, 0.2), hl, _s(0.05), true)
		draw_line(_p(0.36, 0.56), _p(0.66, 0.26), Color(1, 1, 1, 0.3), _s(0.03), true)
		draw_line(_p(0.42, 0.8), _p(0.7, 0.52), Color(1, 1, 1, 0.4), _s(0.04), true)
		draw_rect(inner.grow(-_s(0.04)), Color(0.9, 0.94, 1.0, 0.6), false, _s(0.015))
		return
	# Узор: ромб-печать по центру и буква вида
	var dia := _poly([Vector2(0.5, 0.26), Vector2(0.66, 0.5), Vector2(0.5, 0.74), Vector2(0.34, 0.5)])
	draw_colored_polygon(dia, Color(frame.r, frame.g, frame.b, 0.35 if not soul else 0.6))
	_outline(dia, Color(frame.r, frame.g, frame.b, 0.9), _s(0.015))
	var font := ThemeDB.fallback_font
	var fs := maxi(6, int(_s(0.3)))
	var t := String(MobData.get_type(sp)["name"]).substr(0, 1).to_upper()
	var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tc := Color.WHITE if soul else Color(0.92, 0.88, 0.8)
	draw_string_outline(font, _p(0.5, 0.5) + Vector2(-tw * 0.5, fs * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
		maxi(1, int(_s(0.03))), INK)
	draw_string(font, _p(0.5, 0.5) + Vector2(-tw * 0.5, fs * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tc)
	if soul:
		# Искры души в углах
		for e in [Vector2(0.32, 0.2), Vector2(0.68, 0.8), Vector2(0.7, 0.22)]:
			var v: Vector2 = e
			var sp2 := _p(v.x, v.y)
			var a := _s(0.06)
			var b := _s(0.015)
			draw_colored_polygon(PackedVector2Array([sp2 + Vector2(0, -a), sp2 + Vector2(b, -b), sp2 + Vector2(a, 0),
				sp2 + Vector2(b, b), sp2 + Vector2(0, a), sp2 + Vector2(-b, b), sp2 + Vector2(-a, 0), sp2 + Vector2(-b, -b)]),
				Color(1, 1, 0.85, 0.95))


## Кристалл души: ромб с гранями и искоркой.
func _crystal(c: Color) -> void:
	var gem := _poly([Vector2(0.5, 0.1), Vector2(0.76, 0.42), Vector2(0.5, 0.9), Vector2(0.24, 0.42)])
	draw_colored_polygon(gem, c)
	draw_colored_polygon(_poly([Vector2(0.5, 0.1), Vector2(0.24, 0.42), Vector2(0.5, 0.9)]), c.lightened(0.35))
	draw_colored_polygon(_poly([Vector2(0.5, 0.1), Vector2(0.76, 0.42), Vector2(0.5, 0.42)]), c.lightened(0.15))
	draw_colored_polygon(_poly([Vector2(0.5, 0.42), Vector2(0.76, 0.42), Vector2(0.5, 0.9)]), c.darkened(0.25))
	var hl := Color(1, 1, 1, 0.55)
	draw_line(_p(0.24, 0.42), _p(0.76, 0.42), hl, _s(0.018), true)
	draw_line(_p(0.5, 0.1), _p(0.5, 0.9), hl, _s(0.018), true)
	_outline(gem, INK, _s(0.03))
	var sp := _p(0.72, 0.2)
	var a := _s(0.08)
	var b := _s(0.02)
	draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -a), sp + Vector2(b, -b), sp + Vector2(a, 0),
		sp + Vector2(b, b), sp + Vector2(0, a), sp + Vector2(-b, b), sp + Vector2(-a, 0), sp + Vector2(-b, -b)]),
		Color(1, 1, 0.9, 0.95))


## Клинок: рукоять у base, лезвие по направлению dir длиной len_k (доля размера), ширина w.
## Копьё по диагонали: древко и листовидный наконечник.
func _spear(c: Color) -> void:
	var a := _p(0.2, 0.84)
	var tip := _p(0.84, 0.16)
	var d := (tip - a).normalized()
	var n := Vector2(-d.y, d.x)
	var head := tip - d * _s(0.26)
	draw_line(a, head, Color(0.55, 0.4, 0.25), _s(0.05), true)
	draw_line(a, head, INK, maxf(1.0, _s(0.012)), true)
	var hw := _s(0.075)
	var leaf := PackedVector2Array([head, head + d * _s(0.08) + n * hw, tip, head + d * _s(0.08) - n * hw])
	draw_colored_polygon(leaf, c.lightened(0.25))
	_outline(leaf, INK, _s(0.02))


func _blade(base: Vector2, dir: Vector2, len_k: float, w: float, c: Color) -> void:
	var d := dir.normalized()
	var n := Vector2(-d.y, d.x)
	var blade_len := _s(len_k)
	var hw := _s(w) * 0.5
	var steel := c.lightened(0.25)
	var tip := base + d * blade_len
	var blade := PackedVector2Array([base + n * hw, base + d * blade_len * 0.8 + n * hw, tip,
		base + d * blade_len * 0.8 - n * hw, base - n * hw])
	draw_colored_polygon(blade, steel)
	draw_line(base + d * _s(0.03), base + d * blade_len * 0.82, Color(1, 1, 1, 0.7), maxf(1.0, hw * 0.35), true)
	_outline(blade, INK, _s(0.022))
	# Гарда, рукоять, навершие
	var gold := Color(0.95, 0.75, 0.3)
	draw_line(base + n * hw * 2.6, base - n * hw * 2.6, INK, _s(0.075), true)
	draw_line(base + n * hw * 2.4, base - n * hw * 2.4, gold, _s(0.045), true)
	var grip_end := base - d * _s(0.17)
	draw_line(base, grip_end, INK, _s(0.075), true)
	draw_line(base, grip_end, Color(0.42, 0.26, 0.18), _s(0.045), true)
	draw_circle(grip_end, _s(0.04), INK)
	draw_circle(grip_end, _s(0.028), gold)


## Арбалет: дуга плеч, тетива, ложе и болт.
## Лук: изогнутая дуга слева, прямая тетива справа и стрела поперёк.
func _bow(c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		var y := lerpf(0.14, 0.86, t)
		var x := 0.62 - 0.3 * sin(t * PI)
		pts.append(_p(x, y))
	draw_polyline(pts, INK, _s(0.1), true)
	draw_polyline(pts, c, _s(0.065), true)
	draw_line(_p(0.62, 0.14), _p(0.62, 0.86), Color(0.95, 0.93, 0.85), _s(0.018), true)
	draw_line(_p(0.2, 0.5), _p(0.8, 0.5), INK, _s(0.045), true)
	draw_line(_p(0.2, 0.5), _p(0.8, 0.5), Color(0.6, 0.45, 0.3), _s(0.025), true)
	draw_colored_polygon(_poly([Vector2(0.14, 0.5), Vector2(0.24, 0.45), Vector2(0.24, 0.55)]), Color(0.78, 0.8, 0.86))
	draw_colored_polygon(_poly([Vector2(0.8, 0.5), Vector2(0.88, 0.44), Vector2(0.86, 0.5), Vector2(0.88, 0.56)]),
		Color(0.9, 0.3, 0.25))


func _crossbow(c: Color) -> void:
	var center := _p(0.5, 0.6)
	var r := _s(0.36)
	var a0 := deg_to_rad(200.0)
	var a1 := deg_to_rad(340.0)
	var left := center + Vector2(cos(a0), sin(a0)) * r
	var right := center + Vector2(cos(a1), sin(a1)) * r
	var nock := _p(0.5, 0.62)
	draw_line(left, nock, Color(0.95, 0.92, 0.85), _s(0.02), true)
	draw_line(right, nock, Color(0.95, 0.92, 0.85), _s(0.02), true)
	draw_arc(center, r, a0, a1, 24, INK, _s(0.085), true)
	draw_arc(center, r, a0, a1, 24, Color(0.75, 0.78, 0.85), _s(0.05), true)
	# Ложе
	draw_line(_p(0.5, 0.2), _p(0.5, 0.9), INK, _s(0.11), true)
	draw_line(_p(0.5, 0.21), _p(0.5, 0.89), c, _s(0.075), true)
	# Болт
	draw_line(_p(0.5, 0.62), _p(0.5, 0.14), Color(0.92, 0.9, 0.85), _s(0.025), true)
	var head := PackedVector2Array([_p(0.5, 0.06), _p(0.55, 0.16), _p(0.45, 0.16)])
	draw_colored_polygon(head, Color(0.8, 0.85, 0.95))
	_outline(head, INK, _s(0.015))


## Клык: изогнутый рог, сужающийся к острию.
func _fang(c: Color) -> void:
	var p0 := Vector2(0.32, 0.84)
	var p1 := Vector2(0.30, 0.34)
	var p2 := Vector2(0.72, 0.16)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var steps := 12
	for i in steps + 1:
		var t := float(i) / float(steps)
		var pt := p0 * (1.0 - t) * (1.0 - t) + p1 * 2.0 * t * (1.0 - t) + p2 * t * t
		var dv := (p1 - p0) * 2.0 * (1.0 - t) + (p2 - p1) * 2.0 * t
		var nv := Vector2(-dv.y, dv.x).normalized()
		var w := 0.11 * (1.0 - t) + 0.004
		left.append(_p(pt.x + nv.x * w, pt.y + nv.y * w))
		right.append(_p(pt.x - nv.x * w, pt.y - nv.y * w))
	var shape := PackedVector2Array()
	shape.append_array(left)
	right.reverse()
	shape.append_array(right)
	draw_colored_polygon(shape, c)
	_outline(shape, INK, _s(0.025))
	draw_line(_p(0.25, 0.78), _p(0.42, 0.84), c.darkened(0.35), _s(0.04), true)


## Шкура: распластанный мех с полосами.
func _pelt(c: Color) -> void:
	var shape := _poly([Vector2(0.30, 0.18), Vector2(0.42, 0.28), Vector2(0.58, 0.28), Vector2(0.70, 0.18),
		Vector2(0.74, 0.36), Vector2(0.68, 0.50), Vector2(0.80, 0.70), Vector2(0.66, 0.80), Vector2(0.56, 0.72),
		Vector2(0.50, 0.88), Vector2(0.44, 0.72), Vector2(0.34, 0.80), Vector2(0.20, 0.70), Vector2(0.32, 0.50),
		Vector2(0.26, 0.36)])
	draw_colored_polygon(shape, c)
	var dark := c.darkened(0.35)
	for i in 3:
		var y := 0.4 + 0.1 * float(i)
		draw_line(_p(0.4, y), _p(0.6, y + 0.02), dark, _s(0.035), true)
	draw_line(_p(0.5, 0.3), _p(0.5, 0.78), c.lightened(0.25), _s(0.02), true)
	_outline(shape, INK, _s(0.025))


## Перо: стержень и опахало с тёмными полосками.
func _feather(c: Color) -> void:
	var a := Vector2(0.30, 0.88)
	var b := Vector2(0.70, 0.12)
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var steps := 12
	for i in steps + 1:
		var t := 0.18 + 0.82 * float(i) / float(steps)
		var pt := a.lerp(b, t)
		var w := 0.15 * sin(PI * (t - 0.18) / 0.82) + 0.005
		left.append(_p(pt.x + n.x * w, pt.y + n.y * w))
		right.append(_p(pt.x - n.x * w * 0.8, pt.y - n.y * w * 0.8))
	var shape := PackedVector2Array()
	shape.append_array(left)
	right.reverse()
	shape.append_array(right)
	draw_colored_polygon(shape, c)
	var dark := c.darkened(0.4)
	for kv in [0.45, 0.6, 0.75]:
		var pt := a.lerp(b, float(kv))
		draw_line(_p(pt.x, pt.y), _p(pt.x + n.x * 0.12, pt.y + n.y * 0.12 + 0.03), dark, _s(0.025), true)
	_outline(shape, INK, _s(0.022))
	draw_line(_p(a.x, a.y), _p(b.x, b.y), Color(0.98, 0.95, 0.85), _s(0.025), true)


## Пластина панциря: шестиугольник с внутренним узором.
func _plate(c: Color) -> void:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 6:
		var ang := PI / 6.0 + float(i) * PI / 3.0
		outer.append(_p(0.5 + cos(ang) * 0.36, 0.52 + sin(ang) * 0.36))
		inner.append(_p(0.5 + cos(ang) * 0.18, 0.52 + sin(ang) * 0.18))
	draw_colored_polygon(outer, c)
	draw_colored_polygon(inner, c.lightened(0.25))
	for i in 6:
		draw_line(inner[i], outer[i], c.darkened(0.35), _s(0.025), true)
	_outline(inner, c.darkened(0.35), _s(0.022))
	_outline(outer, INK, _s(0.03))


## Осколок стража: угловатый камень со светящейся руной.
func _shard(c: Color) -> void:
	var shape := _poly([Vector2(0.42, 0.1), Vector2(0.68, 0.28), Vector2(0.74, 0.62), Vector2(0.52, 0.9),
		Vector2(0.28, 0.72), Vector2(0.26, 0.38)])
	draw_colored_polygon(shape, c)
	draw_colored_polygon(_poly([Vector2(0.42, 0.1), Vector2(0.68, 0.28), Vector2(0.5, 0.42), Vector2(0.26, 0.38)]),
		c.lightened(0.25))
	_outline(shape, INK, _s(0.03))
	var rune := Color(0.45, 0.95, 1.0)
	var pts := _poly([Vector2(0.44, 0.36), Vector2(0.56, 0.52), Vector2(0.46, 0.62), Vector2(0.56, 0.76)])
	draw_polyline(pts, Color(rune.r, rune.g, rune.b, 0.35), _s(0.07), true)
	draw_polyline(pts, rune, _s(0.03), true)


## Костяной шип: высокий изогнутый рог с зазубринами по внутреннему краю и бликом.
func _spike(c: Color) -> void:
	var shape := _poly([Vector2(0.3, 0.88), Vector2(0.36, 0.56), Vector2(0.5, 0.3), Vector2(0.72, 0.1),
		Vector2(0.64, 0.34), Vector2(0.7, 0.4), Vector2(0.6, 0.5), Vector2(0.66, 0.58), Vector2(0.58, 0.68),
		Vector2(0.62, 0.88)])
	draw_colored_polygon(shape, c)
	draw_colored_polygon(_poly([Vector2(0.36, 0.84), Vector2(0.4, 0.56), Vector2(0.52, 0.34), Vector2(0.45, 0.58),
		Vector2(0.42, 0.84)]), c.lightened(0.3))
	draw_line(_p(0.32, 0.86), _p(0.6, 0.86), c.darkened(0.35), _s(0.04))
	_outline(shape, INK, _s(0.03))


## Чешуйка: округлый щиток с острым краем, полосками роста и бликом.
func _fish_scale(c: Color) -> void:
	var shape := PackedVector2Array()
	for i in 17:
		var ang := PI * float(i) / 16.0
		shape.append(_p(0.5 + cos(ang) * 0.32, 0.42 + sin(ang) * 0.4))
	shape.append(_p(0.5, 0.22))
	draw_colored_polygon(shape, c)
	var dark := c.darkened(0.3)
	for k in 3:
		var r := 0.12 + 0.07 * float(k)
		var arc := PackedVector2Array()
		for i in 9:
			var ang := PI * (0.15 + 0.7 * float(i) / 8.0)
			arc.append(_p(0.5 + cos(ang) * r, 0.42 + sin(ang) * r * 1.2))
		draw_polyline(arc, dark, _s(0.02), true)
	draw_line(_p(0.36, 0.42), _p(0.44, 0.3), c.lightened(0.5), _s(0.035), true)
	_outline(shape, INK, _s(0.028))


## Плавник: веер с лучами и рваным краем.
func _fin(c: Color) -> void:
	var base := Vector2(0.24, 0.8)
	var shape := PackedVector2Array([_p(base.x, base.y)])
	var tips: Array[Vector2] = []
	for i in 6:
		var ang := -PI * 0.5 + 0.22 * float(i) - 0.1
		var ln := 0.62 - 0.05 * absf(float(i) - 2.0)
		var tip := base + Vector2(cos(ang + 0.55), sin(ang + 0.55)) * ln
		tips.append(tip)
		shape.append(_p(tip.x, tip.y))
		if i < 5:
			var mid_a := ang + 0.11 + 0.55
			var notch := base + Vector2(cos(mid_a), sin(mid_a)) * (ln * 0.86)
			shape.append(_p(notch.x, notch.y))
	draw_colored_polygon(shape, c)
	var ray := c.darkened(0.35)
	for tip in tips:
		draw_line(_p(base.x, base.y), _p(tip.x, tip.y), ray, _s(0.025), true)
	_outline(shape, INK, _s(0.025))


## Неизвестный предмет: первая буква названия.
## Заточка «+N» в левом верхнем углу (зеленовато-золотая, с +11 — ярче).
func _enchant_mark() -> void:
	var n := ItemData.enchant_level(item_id)
	if n <= 0:
		return
	var font := ThemeDB.fallback_font
	var fs := maxi(8, int(_s(0.3)))
	var t := "+%d" % n
	var pos := Vector2(_s(0.05), _s(0.06) + font.get_ascent(fs))
	var col := Color(0.55, 1.0, 0.6) if n <= 10 else Color(1.0, 0.72, 0.3)
	draw_string_outline(font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(2, int(_s(0.05))), INK)
	draw_string(font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Куб чарования: кубик в изометрии (верх светлее, бока темнее) с руной.
func _cube(c: Color) -> void:
	var top := _poly([Vector2(0.5, 0.18), Vector2(0.8, 0.33), Vector2(0.5, 0.48), Vector2(0.2, 0.33)])
	var left := _poly([Vector2(0.2, 0.33), Vector2(0.5, 0.48), Vector2(0.5, 0.84), Vector2(0.2, 0.68)])
	var right := _poly([Vector2(0.5, 0.48), Vector2(0.8, 0.33), Vector2(0.8, 0.68), Vector2(0.5, 0.84)])
	draw_colored_polygon(left, c.darkened(0.25))
	draw_colored_polygon(right, c.darkened(0.45))
	draw_colored_polygon(top, c.lightened(0.3))
	_outline(top, INK, _s(0.03))
	_outline(left, INK, _s(0.03))
	_outline(right, INK, _s(0.03))
	draw_circle(_p(0.5, 0.33), _s(0.06), Color(1.0, 1.0, 0.85, 0.9))


## Трещина сломанной вещи: красная ломаная поперёк значка.
func _crack() -> void:
	var pts := PackedVector2Array([_p(0.22, 0.2), _p(0.42, 0.42), _p(0.34, 0.52), _p(0.6, 0.7), _p(0.52, 0.78), _p(0.8, 0.86)])
	draw_polyline(pts, INK, _s(0.07))
	draw_polyline(pts, Color(1.0, 0.3, 0.25), _s(0.035))


func _letter(c: Color) -> void:
	draw_circle(_p(0.5, 0.5), _s(0.3), c.darkened(0.3))
	var font := ThemeDB.fallback_font
	var fs := int(_s(0.4))
	var t := ItemData.item_name(item_id).substr(0, 1).to_upper()
	var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, _p(0.5, 0.5) + Vector2(-tw * 0.5, fs * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
