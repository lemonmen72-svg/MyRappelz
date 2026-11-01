class_name UiIcons
extends RefCounted
## Значки интерфейса вместо надписей: кнопки меню HUD, «Существо», вкладки окон, «Закрыть», команды питомца,
## кнопки «Говорить» / «Торговец», золото, джойстик, значки заданий над жителями и зверями.
## UiIcons.texture(id) — картинка assets/icons/ui/<id>.png, если она есть (Максим рисует их по списку IDS),
## иначе процедурный рисунок (простые узнаваемые формы с тёмным контуром, 64×64, рисуется один раз и кэшируется).
## Список id — КОНТРАКТ с картинками: имя файла = id. Подпись к значку (подсказка, долгое касание) — title(id).
## Картинки: PNG с прозрачным фоном, квадратные (128 или 256), рисунок по центру с небольшим полем; грузятся
## только через load() (в APK — импортированные ресурсы). Лежат в части «icons» пакета ресурсов: наличие — через
## Assets.exists (без части — процедурные рисунки).

const DIR := "res://assets/icons/ui/"
## Размер процедурного рисунка, px.
const SIZE := 64
## Все id значков (контракт с картинками Максима).
const IDS := [
	"menu_hero", "menu_pets", "menu_bag", "menu_quests", "menu_settings", "menu_creature",
	"tab_graphics", "tab_interface", "tab_other", "tab_skills", "close", "back",
	"pet_auto", "pet_attack", "pet_defend", "pet_follow",
	"btn_talk", "btn_merchant", "btn_tame", "btn_storage", "btn_forge", "btn_craft",
	"gold", "map", "joystick_base", "joystick_knob",
	"quest_available", "quest_active", "quest_complete", "quest_target",
]
## Подписи значков (подсказка на ПК, подпись по долгому касанию).
const NAMES := {
	"menu_hero": "Герой", "menu_pets": "Питомцы", "menu_bag": "Сумка", "menu_quests": "Задания",
	"menu_settings": "Настройки", "menu_creature": "Существо", "tab_graphics": "Графика",
	"tab_interface": "Интерфейс", "tab_other": "Прочее", "tab_skills": "Умения", "close": "Закрыть", "back": "Назад",
	"pet_auto": "Авто", "pet_attack": "Атака", "pet_defend": "Защита", "pet_follow": "За мной",
	"btn_talk": "Говорить", "btn_merchant": "Торговец", "btn_tame": "Приручить", "btn_storage": "Склад",
	"btn_forge": "Кузница", "btn_craft": "Ремесло", "gold": "Золото", "map": "Карта",
	"joystick_base": "Джойстик", "joystick_knob": "Ручка джойстика",
	"quest_available": "Можно взять задание", "quest_active": "Задание выполняется",
	"quest_complete": "Задание выполнено — можно сдать", "quest_target": "Цель задания",
}
## Контур процедурных рисунков (доля размера) и его цвет.
const OUTLINE := 0.05
const INK := Color(0.09, 0.07, 0.13, 1.0)

## Тест: вести себя так, будто картинок нет (процедурные рисунки).
static var force_procedural := false
static var _cache: Dictionary = {}


static func path(id: String) -> String:
	return DIR + id + ".png"


## Есть ли картинка id (файл в assets/icons/ui).
static func has_file(id: String) -> bool:
	return not force_procedural and Assets.exists(path(id))


## Забыть картинки (Assets.reset_caches: подключена часть пакета, тест без пакета).
static func reset_cache() -> void:
	_cache.clear()


## Текстура значка: картинка из файла или процедурный рисунок (null не бывает).
static func texture(id: String) -> Texture2D:
	var key := id + ("#p" if force_procedural else "")
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = null
	if has_file(id):
		tex = load(path(id)) as Texture2D
	if tex == null:
		tex = _procedural(id)
	_cache[key] = tex
	return tex


static func title(id: String) -> String:
	return String(NAMES.get(id, id))


## Спецификация IconView (круглые кнопки HUD): картинка UiIcons, если есть файл, иначе запасной рисунок fallback.
static func icon_spec(id: String, fallback: Dictionary) -> Dictionary:
	var s := fallback.duplicate()
	if has_file(id):
		s["path"] = path(id)
	return s


## Кнопка-значок без текста (меню, «Закрыть», вкладки окон): значок на всю кнопку, подсказка — title(id).
## side — сторона квадрата для «Среднего» размера интерфейса (UiScale).
static func icon_button(id: String, side: float) -> Button:
	var b := Button.new()
	b.icon = texture(id)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	b.tooltip_text = title(id)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(UiScale.px(side), UiScale.px(side))
	b.set_meta("icon_id", id)
	return b


## Значок слева от подписи кнопки (вкладки окна героя и существа): высота значка — side («Средний»).
static func add_icon(b: Button, id: String, side: float = 22.0) -> void:
	b.icon = texture(id)
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", int(UiScale.px(side)))
	b.set_meta("icon_id", id)
	if b.tooltip_text == "":
		b.tooltip_text = title(id)


# ---------- Процедурные рисунки ----------

## Рисование по функциям расстояния в буфер RGBA (premultiplied): координаты — доли размера значка (0..1, y вниз).
## ink = true — проход контура: всё рисуется цветом INK и толще на OUTLINE (затем второй проход — цветом).
class _Paint:
	const P_INK := Color(0.09, 0.07, 0.13, 1.0)
	const P_OUTLINE := 0.05
	var n := 64
	var ink := false
	var buf := PackedFloat32Array()

	func _init(sz: int) -> void:
		n = sz
		buf.resize(sz * sz * 4)
		buf.fill(0.0)

	func _col(c: Color) -> Color:
		return P_INK if ink else c

	func _grow() -> float:
		return P_OUTLINE if ink else 0.0

	## Покрытие пикселя по расстоянию d (доли размера): край сглажен на пиксель.
	func _put(x: int, y: int, d: float, c: Color) -> void:
		var cov := clampf(0.5 - d * float(n), 0.0, 1.0)
		if cov <= 0.0:
			return
		var a := c.a * cov
		var i := (y * n + x) * 4
		var k := 1.0 - a
		buf[i] = c.r * a + buf[i] * k
		buf[i + 1] = c.g * a + buf[i + 1] * k
		buf[i + 2] = c.b * a + buf[i + 2] * k
		buf[i + 3] = a + buf[i + 3] * k

	## Пиксели прямоугольника r (доли) с запасом в пиксель: [x0, y0, x1, y1].
	func _span(r: Rect2) -> PackedInt32Array:
		var m := 1.5 / float(n)
		var x0 := clampi(floori((r.position.x - m) * n), 0, n - 1)
		var y0 := clampi(floori((r.position.y - m) * n), 0, n - 1)
		var x1 := clampi(ceili((r.end.x + m) * n), 0, n - 1)
		var y1 := clampi(ceili((r.end.y + m) * n), 0, n - 1)
		return PackedInt32Array([x0, y0, x1, y1])

	func circle(c: Vector2, r: float, col: Color) -> void:
		r += _grow()
		col = _col(col)
		var s := _span(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0))
		for y in range(s[1], s[3] + 1):
			for x in range(s[0], s[2] + 1):
				var p := Vector2((float(x) + 0.5) / n, (float(y) + 0.5) / n)
				_put(x, y, p.distance_to(c) - r, col)

	## Дуга окружности радиуса r толщиной w от угла a0 до a1 (рад, по часовой стрелке от «3 часов», y вниз).
	func arc(c: Vector2, r: float, w: float, a0: float, a1: float, col: Color) -> void:
		var hw := w * 0.5 + _grow()
		col = _col(col)
		var full := a1 - a0 >= TAU - 0.001
		var e0 := c + Vector2(cos(a0), sin(a0)) * r
		var e1 := c + Vector2(cos(a1), sin(a1)) * r
		var rr := r + hw
		var s := _span(Rect2(c - Vector2(rr, rr), Vector2(rr, rr) * 2.0))
		for y in range(s[1], s[3] + 1):
			for x in range(s[0], s[2] + 1):
				var p := Vector2((float(x) + 0.5) / n, (float(y) + 0.5) / n)
				var v := p - c
				var d := absf(v.length() - r) - hw
				if not full and fposmod(atan2(v.y, v.x) - a0, TAU) > a1 - a0:
					d = minf(p.distance_to(e0), p.distance_to(e1)) - hw
				_put(x, y, d, col)

	## Отрезок толщиной w со скруглёнными концами.
	func seg(a: Vector2, b: Vector2, w: float, col: Color) -> void:
		var hw := w * 0.5 + _grow()
		col = _col(col)
		var ab := b - a
		var l2 := maxf(ab.length_squared(), 0.000001)
		var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(hw, hw)
		var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(hw, hw)
		var s := _span(Rect2(lo, hi - lo))
		for y in range(s[1], s[3] + 1):
			for x in range(s[0], s[2] + 1):
				var p := Vector2((float(x) + 0.5) / n, (float(y) + 0.5) / n)
				var h := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
				_put(x, y, (p - a - ab * h).length() - hw, col)

	## Прямоугольник со скруглением rad.
	func box(r: Rect2, rad: float, col: Color) -> void:
		var g := _grow()
		r = r.grow(g)
		rad += g
		col = _col(col)
		var cen := r.get_center()
		var half := r.size * 0.5
		var s := _span(r)
		for y in range(s[1], s[3] + 1):
			for x in range(s[0], s[2] + 1):
				var p := Vector2((float(x) + 0.5) / n, (float(y) + 0.5) / n)
				var q := (p - cen).abs() - half + Vector2(rad, rad)
				var d := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - rad
				_put(x, y, d, col)

	## Многоугольник (любой простой); в проходе контура — расширен на OUTLINE.
	func poly(pts: PackedVector2Array, col: Color) -> void:
		var g := _grow()
		col = _col(col)
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for q in pts:
			lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
			hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
		var s := _span(Rect2(lo, hi - lo).grow(g))
		var cnt := pts.size()
		for y in range(s[1], s[3] + 1):
			for x in range(s[0], s[2] + 1):
				var p := Vector2((float(x) + 0.5) / n, (float(y) + 0.5) / n)
				var dmin := INF
				var inside := false
				for i in cnt:
					var a := pts[i]
					var b := pts[(i + 1) % cnt]
					var ab := b - a
					var h := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
					dmin = minf(dmin, (p - a - ab * h).length())
					if (a.y > p.y) != (b.y > p.y) and p.x < a.x + (p.y - a.y) / (b.y - a.y) * ab.x:
						inside = not inside
				_put(x, y, (-dmin if inside else dmin) - g, col)

	func image() -> Image:
		var bytes := PackedByteArray()
		bytes.resize(n * n * 4)
		for i in n * n:
			var a := buf[i * 4 + 3]
			var inv := 1.0 / a if a > 0.0001 else 0.0
			bytes[i * 4] = clampi(roundi(buf[i * 4] * inv * 255.0), 0, 255)
			bytes[i * 4 + 1] = clampi(roundi(buf[i * 4 + 1] * inv * 255.0), 0, 255)
			bytes[i * 4 + 2] = clampi(roundi(buf[i * 4 + 2] * inv * 255.0), 0, 255)
			bytes[i * 4 + 3] = clampi(roundi(a * 255.0), 0, 255)
		return Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, bytes)


## Процедурный рисунок id: сначала проход контура (тёмный, толще), затем цветной.
static func _procedural(id: String) -> ImageTexture:
	var pt := _Paint.new(SIZE)
	if not id.begins_with("joystick"):
		pt.ink = true
		_draw(pt, id)
	pt.ink = false
	_draw(pt, id)
	var img := pt.image()
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Отпечаток лапы с центром c размера s (подушечка и четыре пальца).
static func _paw(pt: _Paint, c: Vector2, s: float, col: Color) -> void:
	pt.circle(c + Vector2(0, 0.2) * s, 0.32 * s, col)
	for t in [Vector2(-0.42, -0.2), Vector2(-0.15, -0.47), Vector2(0.15, -0.47), Vector2(0.42, -0.2)]:
		var tv: Vector2 = t
		pt.circle(c + tv * s, 0.14 * s, col)


## Звезда с points лучами: внешний радиус ro, внутренний ri.
static func _star(c: Vector2, ro: float, ri: float, points: int) -> PackedVector2Array:
	var res := PackedVector2Array()
	for i in points * 2:
		var a := -PI * 0.5 + PI * float(i) / float(points)
		var r := ro if i % 2 == 0 else ri
		res.append(c + Vector2(cos(a), sin(a)) * r)
	return res


static func _v(pts: Array) -> PackedVector2Array:
	var res := PackedVector2Array()
	for p in pts:
		res.append(p as Vector2)
	return res


static func _draw(pt: _Paint, id: String) -> void:
	var c := Vector2(0.5, 0.5)
	var light := Color(0.97, 0.95, 0.88)
	var gold := Color(1.0, 0.82, 0.25)
	match id:
		"menu_hero":
			var col := Color(1.0, 0.82, 0.45)
			pt.box(Rect2(0.2, 0.55, 0.6, 0.33), 0.15, col)
			pt.circle(Vector2(0.5, 0.33), 0.17, col)
		"menu_pets":
			_paw(pt, Vector2(0.5, 0.55), 0.75, Color(0.62, 0.85, 1.0))
		"menu_bag", "btn_merchant":
			var bag := Color(0.8, 0.58, 0.32)
			pt.poly(_v([Vector2(0.37, 0.38), Vector2(0.63, 0.38), Vector2(0.72, 0.16), Vector2(0.28, 0.16)]), bag)
			pt.circle(Vector2(0.5, 0.62), 0.28, bag)
			pt.seg(Vector2(0.34, 0.38), Vector2(0.66, 0.38), 0.05, INK)
			if id == "btn_merchant":
				pt.circle(Vector2(0.64, 0.68), 0.16, gold)
				pt.arc(Vector2(0.64, 0.68), 0.1, 0.035, 0.0, TAU, Color(0.85, 0.6, 0.15))
			else:
				pt.seg(Vector2(0.42, 0.6), Vector2(0.58, 0.6), 0.05, Color(0.55, 0.36, 0.18))
		"menu_quests":
			var paper := Color(0.96, 0.88, 0.66)
			pt.box(Rect2(0.25, 0.2, 0.5, 0.6), 0.03, paper)
			pt.box(Rect2(0.18, 0.12, 0.64, 0.13), 0.065, paper.darkened(0.1))
			pt.box(Rect2(0.18, 0.75, 0.64, 0.13), 0.065, paper.darkened(0.1))
			for y in [0.36, 0.48, 0.6]:
				pt.seg(Vector2(0.34, float(y)), Vector2(0.66 if float(y) < 0.55 else 0.56, float(y)), 0.045, Color(0.45, 0.32, 0.2))
		"menu_settings":
			var steel := Color(0.82, 0.84, 0.92)
			for i in 8:
				var a := TAU * float(i) / 8.0
				var d := Vector2(cos(a), sin(a))
				pt.seg(c + d * 0.24, c + d * 0.38, 0.14, steel)
			pt.circle(c, 0.29, steel)
			pt.circle(c, 0.11, INK)
		"menu_creature":
			var fur := Color(0.55, 0.86, 0.58)
			pt.poly(_v([Vector2(0.18, 0.52), Vector2(0.22, 0.12), Vector2(0.47, 0.32)]), fur)
			pt.poly(_v([Vector2(0.82, 0.52), Vector2(0.78, 0.12), Vector2(0.53, 0.32)]), fur)
			pt.circle(Vector2(0.5, 0.57), 0.3, fur)
			pt.circle(Vector2(0.39, 0.53), 0.05, INK)
			pt.circle(Vector2(0.61, 0.53), 0.05, INK)
			pt.poly(_v([Vector2(0.45, 0.66), Vector2(0.55, 0.66), Vector2(0.5, 0.72)]), INK)
		"tab_graphics":
			pt.box(Rect2(0.12, 0.2, 0.76, 0.6), 0.06, Color(0.55, 0.78, 1.0))
			pt.circle(Vector2(0.68, 0.37), 0.08, Color(1.0, 0.9, 0.4))
			pt.poly(_v([Vector2(0.15, 0.77), Vector2(0.4, 0.42), Vector2(0.55, 0.62), Vector2(0.66, 0.5),
				Vector2(0.85, 0.77)]), Color(0.4, 0.75, 0.45))
		"tab_interface":
			pt.box(Rect2(0.14, 0.18, 0.72, 0.64), 0.08, Color(0.32, 0.38, 0.58))
			for e in [[0.34, 0.42], [0.5, 0.64], [0.66, 0.34]]:
				var y := float(e[0])
				pt.seg(Vector2(0.26, y), Vector2(0.74, y), 0.05, light)
				pt.circle(Vector2(float(e[1]), y), 0.07, gold)
		"tab_other":
			for x in [0.24, 0.5, 0.76]:
				pt.circle(Vector2(float(x), 0.5), 0.1, Color(0.85, 0.87, 0.95))
		"tab_skills":
			pt.poly(_star(c, 0.42, 0.14, 4), Color(1.0, 0.78, 0.35))
			pt.circle(Vector2(0.76, 0.24), 0.07, Color(1.0, 0.93, 0.6))
		"close":
			var red := Color(0.95, 0.42, 0.38)
			pt.seg(Vector2(0.27, 0.27), Vector2(0.73, 0.73), 0.15, red)
			pt.seg(Vector2(0.73, 0.27), Vector2(0.27, 0.73), 0.15, red)
		"back":
			var bc := Color(0.85, 0.9, 1.0)
			pt.seg(Vector2(0.3, 0.5), Vector2(0.76, 0.5), 0.13, bc)
			pt.seg(Vector2(0.28, 0.5), Vector2(0.5, 0.28), 0.13, bc)
			pt.seg(Vector2(0.28, 0.5), Vector2(0.5, 0.72), 0.13, bc)
		"pet_auto":
			_paw(pt, Vector2(0.5, 0.53), 0.42, Color(0.6, 0.82, 1.0))
			var a1 := PI * 1.3
			pt.arc(c, 0.36, 0.07, -PI * 0.25, a1, light)
			var tip := c + Vector2(cos(a1), sin(a1)) * 0.36
			var tg := Vector2(-sin(a1), cos(a1))
			var nr := Vector2(cos(a1), sin(a1))
			pt.poly(_v([tip + tg * 0.14, tip + nr * 0.11, tip - nr * 0.11]), light)
		"pet_attack":
			var rc := Color(1.0, 0.5, 0.4)
			pt.arc(c, 0.26, 0.07, 0.0, TAU, rc)
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				var dv: Vector2 = d
				pt.seg(c + dv * 0.14, c + dv * 0.42, 0.07, rc)
			pt.circle(c, 0.06, light)
		"pet_defend":
			pt.poly(_v([Vector2(0.2, 0.16), Vector2(0.8, 0.16), Vector2(0.8, 0.5), Vector2(0.5, 0.88),
				Vector2(0.2, 0.5)]), Color(0.4, 0.72, 0.5))
			_paw(pt, Vector2(0.5, 0.47), 0.3, light)
		"pet_follow":
			_paw(pt, Vector2(0.32, 0.66), 0.34, Color(0.9, 0.74, 0.46))
			_paw(pt, Vector2(0.67, 0.34), 0.34, Color(0.96, 0.84, 0.6))
		"btn_talk":
			pt.poly(_v([Vector2(0.3, 0.6), Vector2(0.22, 0.84), Vector2(0.48, 0.62)]), light)
			pt.box(Rect2(0.12, 0.18, 0.76, 0.48), 0.15, light)
			for x in [0.34, 0.5, 0.66]:
				pt.circle(Vector2(float(x), 0.42), 0.05, Color(0.6, 0.38, 0.18))
		"btn_tame":
			pt.box(Rect2(0.26, 0.12, 0.48, 0.76), 0.07, Color(0.62, 0.42, 0.25))
			pt.box(Rect2(0.32, 0.18, 0.36, 0.64), 0.04, Color(0.96, 0.9, 0.7))
			pt.poly(_star(c, 0.15, 0.06, 4), Color(0.35, 0.85, 0.45))
		"btn_storage":
			var wood := Color(0.74, 0.5, 0.28)
			pt.box(Rect2(0.14, 0.42, 0.72, 0.4), 0.05, wood)
			pt.box(Rect2(0.14, 0.2, 0.72, 0.26), 0.1, wood.lightened(0.12))
			pt.seg(Vector2(0.14, 0.45), Vector2(0.86, 0.45), 0.04, INK)
			pt.box(Rect2(0.44, 0.38, 0.12, 0.17), 0.03, gold)
		"btn_forge":
			pt.poly(_v([Vector2(0.12, 0.3), Vector2(0.8, 0.3), Vector2(0.88, 0.38), Vector2(0.66, 0.48),
				Vector2(0.6, 0.62), Vector2(0.74, 0.82), Vector2(0.26, 0.82), Vector2(0.4, 0.62), Vector2(0.34, 0.48),
				Vector2(0.12, 0.4)]), Color(0.62, 0.65, 0.74))
			pt.circle(Vector2(0.28, 0.16), 0.05, Color(1.0, 0.6, 0.2))
			pt.circle(Vector2(0.5, 0.12), 0.04, Color(1.0, 0.8, 0.3))
		"btn_craft":
			pt.seg(Vector2(0.28, 0.82), Vector2(0.6, 0.4), 0.11, Color(0.62, 0.42, 0.25))
			pt.seg(Vector2(0.42, 0.2), Vector2(0.8, 0.5), 0.2, Color(0.66, 0.7, 0.78))
		"gold":
			pt.circle(c, 0.38, gold)
			pt.arc(c, 0.26, 0.05, 0.0, TAU, Color(0.85, 0.58, 0.12))
			pt.seg(Vector2(0.37, 0.33), Vector2(0.45, 0.27), 0.06, Color(1.0, 0.97, 0.8))
		"map":
			var paper := Color(0.95, 0.88, 0.66)
			pt.poly(_v([Vector2(0.1, 0.24), Vector2(0.37, 0.15), Vector2(0.63, 0.25), Vector2(0.9, 0.16),
				Vector2(0.9, 0.78), Vector2(0.63, 0.87), Vector2(0.37, 0.77), Vector2(0.1, 0.86)]), paper)
			pt.seg(Vector2(0.37, 0.17), Vector2(0.37, 0.76), 0.025, Color(0.6, 0.48, 0.3))
			pt.seg(Vector2(0.63, 0.27), Vector2(0.63, 0.85), 0.025, Color(0.6, 0.48, 0.3))
			for e in [[0.2, 0.68], [0.3, 0.6], [0.42, 0.56], [0.53, 0.52]]:
				pt.circle(Vector2(float(e[0]), float(e[1])), 0.025, Color(0.45, 0.32, 0.2))
			pt.seg(Vector2(0.62, 0.36), Vector2(0.78, 0.52), 0.055, Color(0.9, 0.2, 0.15))
			pt.seg(Vector2(0.78, 0.36), Vector2(0.62, 0.52), 0.055, Color(0.9, 0.2, 0.15))
		"joystick_base":
			pt.circle(c, 0.45, Color(1, 1, 1, 0.12))
			pt.arc(c, 0.45, 0.045, 0.0, TAU, Color(1.0, 0.95, 0.82, 0.8))
		"joystick_knob":
			pt.circle(c, 0.47, Color(1, 1, 1, 0.4))
			pt.circle(c - Vector2(0.1, 0.1), 0.2, Color(1, 1, 1, 0.3))
		"quest_available":
			var qc := Color(1.0, 0.82, 0.18)
			pt.poly(_v([Vector2(0.38, 0.1), Vector2(0.62, 0.1), Vector2(0.56, 0.62), Vector2(0.44, 0.62)]), qc)
			pt.circle(Vector2(0.5, 0.8), 0.1, qc)
		"quest_active":
			var qa := Color(0.74, 0.78, 0.88)
			pt.arc(Vector2(0.5, 0.33), 0.17, 0.12, PI * 0.95, PI * 2.5, qa)
			pt.seg(Vector2(0.5, 0.5), Vector2(0.5, 0.6), 0.12, qa)
			pt.circle(Vector2(0.5, 0.82), 0.085, qa)
		"quest_complete":
			var qd := Color(0.45, 0.95, 0.45)
			pt.box(Rect2(0.18, 0.28, 0.64, 0.15), 0.06, qd)
			pt.box(Rect2(0.18, 0.57, 0.64, 0.15), 0.06, qd)
		"quest_target":
			var red := Color(1.0, 0.25, 0.2)
			pt.poly(_v([Vector2(0.27, 0.5), Vector2(0.73, 0.5), Vector2(0.5, 0.92)]), red)
			pt.circle(Vector2(0.5, 0.38), 0.28, red)
			pt.seg(Vector2(0.4, 0.28), Vector2(0.6, 0.48), 0.07, light)
			pt.seg(Vector2(0.6, 0.28), Vector2(0.4, 0.48), 0.07, light)
		_:
			pt.circle(c, 0.3, Color(0.7, 0.72, 0.8))
