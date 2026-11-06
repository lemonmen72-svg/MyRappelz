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
	"tab_pet_active", "tab_pet_auras", "tab_pet_passive", "tab_pet_gear",
	# 0.41: вкладки сумки, кнопки окон, быстрые слоты и листание умений (tools/Промты_значки_сумка_кнопки_оружие2.docx)
	"bagtab_all", "bagtab_gear", "bagtab_loot", "bagtab_cards", "bagtab_jewelry", "bagtab_quest", "bagtab_potions",
	"bagtab_other",
	"act_equip", "act_unequip", "act_offhand", "act_use", "act_sell", "act_sell_all", "act_buy", "act_buy_many",
	"act_move", "act_drop", "act_drop_all", "act_sort", "act_form", "act_read", "act_craft_put", "act_recipes",
	"act_store", "act_store_all", "act_take", "act_take_all", "act_gold_in", "act_gold_out", "act_forge_put",
	"act_confirm", "act_cancel", "act_plus", "act_minus", "act_belt_put", "act_belt_take", "act_belt_expand",
	"act_details", "act_ring2",
	"act_learn", "act_assign", "act_slot_clear", "act_toggle", "act_summon", "act_recall", "act_release", "act_revive",
	"act_evolve", "act_pet_gear", "act_quest_take", "act_quest_turnin", "act_track", "act_abandon", "act_trade",
	"act_bye",
	"quick_slot_empty", "quick_edit", "skill_swipe", "skill_slot_empty", "auto_attack", "act_bless",
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
	"tab_pet_active": "Активные умения", "tab_pet_auras": "Ауры и бафы", "tab_pet_passive": "Пассивные умения",
	"tab_pet_gear": "Оружие и доспехи",
	"bagtab_all": "Все предметы", "bagtab_gear": "Оружие и броня", "bagtab_loot": "Добыча монстров",
	"bagtab_cards": "Карты питомцев", "bagtab_jewelry": "Украшения", "bagtab_quest": "Предметы заданий",
	"bagtab_potions": "Зелья и усиления", "bagtab_other": "Остальное",
	"act_equip": "Надеть", "act_unequip": "Снять", "act_offhand": "Во 2-ю руку", "act_use": "Использовать",
	"act_sell": "Продать", "act_sell_all": "Продать все", "act_buy": "Купить", "act_buy_many": "Купить несколько",
	"act_move": "Переместить", "act_drop": "Выбросить", "act_drop_all": "Выбросить все", "act_sort": "Сортировать",
	"act_form": "Сформировать", "act_read": "Прочитать", "act_craft_put": "В крафт", "act_recipes": "Рецепты",
	"act_store": "На склад", "act_store_all": "На склад все", "act_take": "В сумку", "act_take_all": "В сумку все",
	"act_gold_in": "Положить золото", "act_gold_out": "Забрать золото", "act_forge_put": "На наковальню",
	"act_confirm": "Да", "act_cancel": "Отмена", "act_plus": "Больше", "act_minus": "Меньше",
	"act_belt_put": "В пояс", "act_belt_take": "Из пояса", "act_belt_expand": "Расширить пояс",
	"act_details": "Подробнее", "act_ring2": "Во 2-е кольцо", "act_learn": "Изучить", "act_assign": "На кнопку",
	"act_slot_clear": "Убрать", "act_toggle": "Вкл / выкл", "act_summon": "Призвать", "act_recall": "Отозвать",
	"act_release": "Отпустить", "act_revive": "Воскресить", "act_evolve": "Эволюция", "act_pet_gear": "Надеть питомцу",
	"act_quest_take": "Взять задание", "act_quest_turnin": "Сдать задание", "act_track": "Отслеживать",
	"act_abandon": "Отказаться", "act_trade": "Торговля", "act_bye": "До встречи",
	"quick_slot_empty": "Быстрый слот", "quick_edit": "Настроить быстрые слоты", "skill_swipe": "Листать умения",
	"skill_slot_empty": "Пустая ячейка умения", "auto_attack": "Автоатака", "act_bless": "Благословения",
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
	# Квадратная рамка (0.41): не растягивать широкую рамку кнопок с подписью
	var off := Util.square_skin(false)
	b.add_theme_stylebox_override("normal", off)
	b.add_theme_stylebox_override("hover", off)
	b.add_theme_stylebox_override("disabled", off)
	b.add_theme_stylebox_override("pressed", Util.square_skin(true))
	b.add_theme_stylebox_override("hover_pressed", Util.square_skin(true))
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
		"tab_pet_active":
			# Три следа когтей
			var claw := Color(1.0, 0.55, 0.4)
			for i in 3:
				var dx := 0.17 * float(i - 1)
				pt.seg(Vector2(0.36 + dx, 0.18), Vector2(0.62 + dx, 0.82), 0.09, claw)
		"tab_pet_auras":
			# Лапа в сияющем кольце
			var glow := Color(0.5, 0.95, 0.65)
			pt.arc(c, 0.38, 0.07, 0.0, TAU, glow)
			for i in 8:
				var a := TAU * float(i) / 8.0
				pt.circle(c + Vector2(cos(a), sin(a)) * 0.38, 0.05, glow.lightened(0.3))
			_paw(pt, Vector2(0.5, 0.53), 0.36, light)
		"tab_pet_passive":
			# Щит со звездой
			pt.poly(_v([Vector2(0.2, 0.16), Vector2(0.8, 0.16), Vector2(0.8, 0.5), Vector2(0.5, 0.88),
				Vector2(0.2, 0.5)]), Color(0.55, 0.65, 0.95))
			pt.poly(_star(Vector2(0.5, 0.44), 0.2, 0.08, 5), gold)
		"tab_pet_gear":
			# Клинок поверх нагрудника
			pt.poly(_v([Vector2(0.18, 0.3), Vector2(0.38, 0.2), Vector2(0.62, 0.2), Vector2(0.82, 0.3),
				Vector2(0.74, 0.86), Vector2(0.26, 0.86)]), Color(0.62, 0.66, 0.76))
			pt.seg(Vector2(0.3, 0.78), Vector2(0.78, 0.14), 0.09, light)
			pt.seg(Vector2(0.22, 0.7), Vector2(0.38, 0.86), 0.07, gold)
			pt.seg(Vector2(0.3, 0.78), Vector2(0.2, 0.9), 0.07, Color(0.6, 0.4, 0.22))
		"bagtab_all":
			_bag(pt, Color(0.8, 0.58, 0.32))
			pt.circle(Vector2(0.36, 0.28), 0.08, Color(0.6, 0.85, 1.0))
			pt.circle(Vector2(0.62, 0.26), 0.07, Color(1.0, 0.45, 0.4))
		"bagtab_gear":
			pt.poly(_v([Vector2(0.18, 0.18), Vector2(0.62, 0.18), Vector2(0.62, 0.52), Vector2(0.4, 0.82),
				Vector2(0.18, 0.52)]), Color(0.45, 0.6, 0.95))
			pt.seg(Vector2(0.36, 0.84), Vector2(0.84, 0.2), 0.09, light)
			pt.seg(Vector2(0.38, 0.62), Vector2(0.56, 0.8), 0.07, gold)
		"bagtab_loot":
			pt.box(Rect2(0.14, 0.58, 0.72, 0.26), 0.1, Color(0.6, 0.45, 0.32))
			pt.poly(_v([Vector2(0.3, 0.6), Vector2(0.42, 0.14), Vector2(0.52, 0.6)]), Color(0.96, 0.92, 0.8))
			pt.poly(_v([Vector2(0.5, 0.6), Vector2(0.7, 0.22), Vector2(0.72, 0.6)]), Color(0.92, 0.86, 0.7))
		"bagtab_cards":
			pt.box(Rect2(0.16, 0.22, 0.42, 0.6), 0.05, Color(0.55, 0.42, 0.85))
			pt.box(Rect2(0.42, 0.16, 0.42, 0.6), 0.05, Color(0.98, 0.9, 0.7))
			_paw(pt, Vector2(0.63, 0.48), 0.28, Color(0.45, 0.3, 0.75))
		"bagtab_jewelry":
			pt.arc(Vector2(0.42, 0.58), 0.22, 0.08, 0.0, TAU, gold)
			pt.poly(_v([Vector2(0.42, 0.22), Vector2(0.53, 0.34), Vector2(0.42, 0.44), Vector2(0.31, 0.34)]),
				Color(0.4, 0.75, 1.0))
			pt.circle(Vector2(0.74, 0.3), 0.1, Color(1.0, 0.45, 0.6))
		"bagtab_quest":
			_scroll(pt, Color(0.96, 0.88, 0.66))
			pt.circle(Vector2(0.62, 0.64), 0.12, Color(0.85, 0.15, 0.15))
			pt.seg(Vector2(0.62, 0.58), Vector2(0.62, 0.66), 0.035, gold)
		"bagtab_potions":
			_flask(pt, Vector2(0.38, 0.58), 0.22, Color(1.0, 0.3, 0.35))
			_flask(pt, Vector2(0.68, 0.64), 0.15, Color(0.35, 0.6, 1.0))
		"bagtab_other":
			pt.box(Rect2(0.16, 0.44, 0.68, 0.4), 0.05, Color(0.72, 0.5, 0.28))
			pt.box(Rect2(0.3, 0.2, 0.26, 0.26), 0.04, Color(0.6, 0.8, 1.0))
			pt.circle(Vector2(0.68, 0.32), 0.1, Color(0.78, 0.8, 0.86))
		"act_equip", "act_unequip":
			_chest(pt, Color(0.6, 0.68, 0.85))
			if id == "act_equip":
				_arrow(pt, Vector2(0.5, 0.08), Vector2(0.5, 0.46), 0.1, gold)
			else:
				_arrow(pt, Vector2(0.5, 0.5), Vector2(0.5, 0.1), 0.1, gold)
		"act_offhand":
			pt.poly(_v([Vector2(0.24, 0.18), Vector2(0.76, 0.18), Vector2(0.76, 0.5), Vector2(0.5, 0.86),
				Vector2(0.24, 0.5)]), Color(0.55, 0.65, 0.95))
			pt.circle(Vector2(0.5, 0.42), 0.1, gold)
		"act_use":
			_flask(pt, Vector2(0.5, 0.6), 0.24, Color(0.4, 1.0, 0.55))
			pt.poly(_star(Vector2(0.78, 0.22), 0.12, 0.04, 4), light)
		"act_sell", "act_sell_all":
			pt.box(Rect2(0.14, 0.62, 0.72, 0.18), 0.09, Color(0.95, 0.78, 0.6))
			pt.circle(Vector2(0.5, 0.34), 0.17, gold)
			if id == "act_sell_all":
				pt.circle(Vector2(0.3, 0.42), 0.13, gold.darkened(0.1))
				pt.circle(Vector2(0.7, 0.42), 0.13, gold.darkened(0.1))
		"act_buy", "act_buy_many":
			_bag(pt, Color(0.82, 0.6, 0.35))
			pt.circle(Vector2(0.7, 0.7), 0.15, gold)
			if id == "act_buy_many":
				pt.circle(Vector2(0.3, 0.72), 0.13, gold.darkened(0.1))
		"act_move":
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				var dv: Vector2 = d
				_arrow(pt, c + dv * 0.1, c + dv * 0.4, 0.08, light)
			pt.box(Rect2(0.42, 0.42, 0.16, 0.16), 0.03, gold)
		"act_drop", "act_drop_all":
			pt.box(Rect2(0.2, 0.2, 0.36, 0.3), 0.06, Color(0.95, 0.78, 0.6))
			_arrow(pt, Vector2(0.62, 0.36), Vector2(0.62, 0.86), 0.09, Color(1.0, 0.5, 0.4))
			if id == "act_drop_all":
				_arrow(pt, Vector2(0.84, 0.36), Vector2(0.84, 0.76), 0.07, Color(1.0, 0.5, 0.4))
		"act_sort":
			for i in 3:
				pt.seg(Vector2(0.16, 0.28 + 0.2 * float(i)), Vector2(0.62 - 0.14 * float(i), 0.28 + 0.2 * float(i)), 0.08, light)
			_arrow(pt, Vector2(0.78, 0.2), Vector2(0.78, 0.8), 0.08, gold)
		"act_form":
			pt.box(Rect2(0.18, 0.3, 0.38, 0.56), 0.05, Color(0.98, 0.9, 0.7))
			pt.circle(Vector2(0.68, 0.32), 0.18, Color(0.5, 1.0, 0.75))
			_paw(pt, Vector2(0.68, 0.33), 0.2, light)
		"act_read", "act_recipes":
			pt.poly(_v([Vector2(0.1, 0.26), Vector2(0.5, 0.34), Vector2(0.5, 0.84), Vector2(0.1, 0.76)]),
				Color(0.96, 0.9, 0.72))
			pt.poly(_v([Vector2(0.9, 0.26), Vector2(0.5, 0.34), Vector2(0.5, 0.84), Vector2(0.9, 0.76)]),
				Color(0.9, 0.82, 0.62))
			if id == "act_recipes":
				pt.box(Rect2(0.6, 0.44, 0.18, 0.18), 0.03, Color(0.55, 0.75, 1.0))
			else:
				pt.circle(Vector2(0.3, 0.52), 0.07, Color(0.6, 0.9, 1.0))
		"act_craft_put":
			pt.box(Rect2(0.46, 0.38, 0.4, 0.4), 0.05, Color(0.55, 0.75, 1.0))
			_arrow(pt, Vector2(0.1, 0.24), Vector2(0.46, 0.5), 0.08, gold)
		"act_store", "act_store_all", "act_take", "act_take_all":
			var wood := Color(0.74, 0.5, 0.28)
			pt.box(Rect2(0.14, 0.5, 0.72, 0.36), 0.05, wood)
			pt.box(Rect2(0.14, 0.4, 0.72, 0.14), 0.05, wood.lightened(0.12))
			if id.begins_with("act_store"):
				_arrow(pt, Vector2(0.5, 0.04), Vector2(0.5, 0.42), 0.09, gold)
			else:
				_arrow(pt, Vector2(0.5, 0.44), Vector2(0.5, 0.04), 0.09, gold)
			if id.ends_with("_all"):
				pt.circle(Vector2(0.82, 0.18), 0.1, Color(1.0, 0.5, 0.4))
		"act_gold_in", "act_gold_out":
			pt.box(Rect2(0.14, 0.52, 0.72, 0.32), 0.05, Color(0.74, 0.5, 0.28))
			pt.circle(Vector2(0.5, 0.3), 0.16, gold)
			_arrow(pt, Vector2(0.8, 0.1 if id == "act_gold_in" else 0.5), Vector2(0.8, 0.5 if id == "act_gold_in" else 0.1),
				0.07, light)
		"act_forge_put":
			pt.poly(_v([Vector2(0.12, 0.52), Vector2(0.86, 0.52), Vector2(0.7, 0.66), Vector2(0.72, 0.84),
				Vector2(0.3, 0.84), Vector2(0.32, 0.66)]), Color(0.62, 0.65, 0.74))
			pt.seg(Vector2(0.2, 0.44), Vector2(0.8, 0.3), 0.07, light)
		"act_confirm":
			var gc := Color(0.45, 1.0, 0.5)
			pt.seg(Vector2(0.2, 0.52), Vector2(0.42, 0.74), 0.13, gc)
			pt.seg(Vector2(0.42, 0.74), Vector2(0.82, 0.28), 0.13, gc)
		"act_cancel":
			var rc := Color(1.0, 0.55, 0.45)
			pt.arc(c, 0.28, 0.1, PI * 1.1, PI * 2.6, rc)
			pt.poly(_v([Vector2(0.12, 0.42), Vector2(0.36, 0.42), Vector2(0.24, 0.62)]), rc)
		"act_plus", "act_minus":
			pt.circle(c, 0.38, Color(0.25, 0.3, 0.55))
			pt.seg(Vector2(0.3, 0.5), Vector2(0.7, 0.5), 0.12, gold)
			if id == "act_plus":
				pt.seg(Vector2(0.5, 0.3), Vector2(0.5, 0.7), 0.12, gold)
		"act_belt_put", "act_belt_take", "act_belt_expand":
			pt.box(Rect2(0.08, 0.52, 0.84, 0.2), 0.06, Color(0.6, 0.42, 0.25))
			pt.box(Rect2(0.42, 0.48, 0.16, 0.28), 0.03, gold)
			if id == "act_belt_expand":
				pt.seg(Vector2(0.5, 0.12), Vector2(0.5, 0.38), 0.09, Color(0.5, 1.0, 0.55))
				pt.seg(Vector2(0.37, 0.25), Vector2(0.63, 0.25), 0.09, Color(0.5, 1.0, 0.55))
			else:
				pt.box(Rect2(0.62, 0.14, 0.2, 0.3), 0.03, Color(0.55, 0.42, 0.85))
				_arrow(pt, Vector2(0.36, 0.1 if id == "act_belt_put" else 0.44), Vector2(0.36, 0.44 if id == "act_belt_put" else 0.1),
					0.07, light)
		"act_details":
			pt.arc(Vector2(0.42, 0.42), 0.22, 0.09, 0.0, TAU, gold)
			pt.seg(Vector2(0.58, 0.58), Vector2(0.82, 0.82), 0.12, gold)
		"act_ring2":
			pt.arc(Vector2(0.34, 0.52), 0.18, 0.08, 0.0, TAU, gold.darkened(0.15))
			pt.arc(Vector2(0.66, 0.52), 0.18, 0.08, 0.0, TAU, gold)
			pt.circle(Vector2(0.66, 0.32), 0.07, Color(0.45, 0.8, 1.0))
		"act_learn":
			pt.poly(_star(Vector2(0.44, 0.56), 0.3, 0.11, 4), Color(1.0, 0.78, 0.35))
			_arrow(pt, Vector2(0.8, 0.8), Vector2(0.8, 0.2), 0.08, Color(0.5, 1.0, 0.55))
		"act_assign":
			pt.arc(Vector2(0.64, 0.6), 0.22, 0.07, 0.0, TAU, light)
			pt.poly(_star(Vector2(0.3, 0.3), 0.16, 0.06, 4), gold)
			_arrow(pt, Vector2(0.36, 0.38), Vector2(0.56, 0.54), 0.06, gold)
		"act_slot_clear", "skill_slot_empty", "quick_slot_empty":
			pt.arc(c, 0.34, 0.06, 0.0, TAU, Color(0.7, 0.72, 0.85))
			if id == "act_slot_clear":
				pt.seg(Vector2(0.38, 0.38), Vector2(0.62, 0.62), 0.08, Color(1.0, 0.5, 0.4))
				pt.seg(Vector2(0.62, 0.38), Vector2(0.38, 0.62), 0.08, Color(1.0, 0.5, 0.4))
			elif id == "quick_slot_empty":
				_flask(pt, Vector2(0.5, 0.55), 0.14, Color(0.7, 0.72, 0.85, 0.6))
			else:
				pt.poly(_star(c, 0.16, 0.06, 4), Color(0.7, 0.72, 0.85, 0.6))
		"act_toggle":
			pt.arc(c, 0.3, 0.09, -PI * 0.3, PI * 1.3, Color(0.5, 1.0, 0.6))
			pt.seg(Vector2(0.5, 0.14), Vector2(0.5, 0.48), 0.1, Color(0.5, 1.0, 0.6))
		"act_summon", "act_recall":
			pt.arc(Vector2(0.5, 0.74), 0.3, 0.05, 0.0, TAU, Color(0.6, 0.9, 1.0))
			_paw(pt, Vector2(0.5, 0.42), 0.42, Color(0.62, 0.85, 1.0) if id == "act_summon" else Color(0.62, 0.85, 1.0, 0.5))
			if id == "act_recall":
				_arrow(pt, Vector2(0.82, 0.2), Vector2(0.82, 0.6), 0.07, gold)
		"act_release":
			pt.box(Rect2(0.14, 0.6, 0.5, 0.2), 0.09, Color(0.95, 0.78, 0.6))
			_paw(pt, Vector2(0.66, 0.32), 0.3, Color(0.62, 0.85, 1.0))
		"act_revive":
			pt.seg(Vector2(0.3, 0.82), Vector2(0.62, 0.22), 0.16, light)
			pt.arc(Vector2(0.62, 0.22), 0.14, 0.05, 0.0, TAU, gold)
		"act_evolve":
			_paw(pt, Vector2(0.22, 0.72), 0.2, Color(0.62, 0.85, 1.0))
			_paw(pt, Vector2(0.48, 0.58), 0.28, Color(0.62, 0.85, 1.0))
			_paw(pt, Vector2(0.76, 0.4), 0.36, Color(0.62, 0.85, 1.0))
			_arrow(pt, Vector2(0.2, 0.4), Vector2(0.4, 0.14), 0.06, gold)
		"act_pet_gear":
			_paw(pt, Vector2(0.38, 0.6), 0.4, Color(0.62, 0.85, 1.0))
			pt.seg(Vector2(0.56, 0.62), Vector2(0.86, 0.16), 0.08, light)
		"act_quest_take", "act_quest_turnin":
			_scroll(pt, Color(0.96, 0.88, 0.66))
			if id == "act_quest_take":
				pt.seg(Vector2(0.5, 0.32), Vector2(0.5, 0.56), 0.1, Color(1.0, 0.75, 0.15))
				pt.circle(Vector2(0.5, 0.68), 0.06, Color(1.0, 0.75, 0.15))
			else:
				pt.seg(Vector2(0.34, 0.5), Vector2(0.46, 0.62), 0.08, Color(0.3, 0.75, 0.3))
				pt.seg(Vector2(0.46, 0.62), Vector2(0.68, 0.36), 0.08, Color(0.3, 0.75, 0.3))
		"act_track":
			pt.poly(_v([Vector2(0.32, 0.46), Vector2(0.68, 0.46), Vector2(0.5, 0.88)]), Color(1.0, 0.45, 0.35))
			pt.circle(Vector2(0.5, 0.38), 0.22, Color(1.0, 0.45, 0.35))
			pt.circle(Vector2(0.5, 0.38), 0.08, light)
		"act_abandon":
			_scroll(pt, Color(0.9, 0.82, 0.62))
			pt.seg(Vector2(0.32, 0.32), Vector2(0.68, 0.68), 0.1, Color(0.9, 0.2, 0.15))
			pt.seg(Vector2(0.68, 0.32), Vector2(0.32, 0.68), 0.1, Color(0.9, 0.2, 0.15))
		"act_trade":
			pt.seg(Vector2(0.5, 0.18), Vector2(0.5, 0.8), 0.06, gold)
			pt.seg(Vector2(0.18, 0.3), Vector2(0.82, 0.3), 0.06, gold)
			pt.arc(Vector2(0.24, 0.52), 0.14, 0.05, 0.0, PI, gold)
			pt.arc(Vector2(0.76, 0.52), 0.14, 0.05, 0.0, PI, gold)
			pt.box(Rect2(0.34, 0.78, 0.32, 0.08), 0.03, gold)
		"act_bye":
			pt.box(Rect2(0.28, 0.4, 0.4, 0.42), 0.15, Color(0.95, 0.8, 0.62))
			for i in 4:
				pt.seg(Vector2(0.32 + 0.11 * float(i), 0.42), Vector2(0.3 + 0.12 * float(i), 0.16), 0.08, Color(0.95, 0.8, 0.62))
		"quick_edit":
			_flask(pt, Vector2(0.42, 0.58), 0.22, Color(1.0, 0.35, 0.4))
			pt.circle(Vector2(0.74, 0.3), 0.15, Color(0.82, 0.84, 0.92))
			pt.circle(Vector2(0.74, 0.3), 0.06, INK)
		"skill_swipe":
			for x in [0.3, 0.5, 0.7]:
				pt.circle(Vector2(float(x), 0.5), 0.07, gold if float(x) == 0.5 else light)
			pt.arc(c, 0.38, 0.06, PI * 0.8, PI * 1.2, light)
			pt.arc(c, 0.38, 0.06, -PI * 0.2, PI * 0.2, light)
		"auto_attack":
			pt.arc(c, 0.36, 0.07, -PI * 0.25, PI * 1.3, Color(1.0, 0.6, 0.3))
			pt.seg(Vector2(0.32, 0.7), Vector2(0.68, 0.3), 0.09, light)
			pt.seg(Vector2(0.28, 0.58), Vector2(0.42, 0.74), 0.07, gold)
		"act_bless":
			pt.poly(_star(Vector2(0.5, 0.44), 0.36, 0.2, 12), Color(1.0, 0.85, 0.35))
			pt.circle(Vector2(0.5, 0.44), 0.16, Color(1.0, 0.97, 0.8))
		_:
			pt.circle(c, 0.3, Color(0.7, 0.72, 0.8))


## Стрелка от a к b толщиной w (наконечник у b).
static func _arrow(pt: _Paint, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	pt.seg(a, b - d * w * 1.2, w, col)
	pt.poly(_v([b, b - d * w * 2.2 + n * w * 1.5, b - d * w * 2.2 - n * w * 1.5]), col)


## Сумка (мешок).
static func _bag(pt: _Paint, bag: Color) -> void:
	pt.poly(_v([Vector2(0.37, 0.38), Vector2(0.63, 0.38), Vector2(0.72, 0.16), Vector2(0.28, 0.16)]), bag)
	pt.circle(Vector2(0.5, 0.62), 0.28, bag)


## Колба с центром c размера r.
static func _flask(pt: _Paint, c: Vector2, r: float, col: Color) -> void:
	pt.box(Rect2(c.x - r * 0.3, c.y - r * 1.6, r * 0.6, r * 0.8), r * 0.1, Color(0.85, 0.88, 0.95))
	pt.circle(c, r, col)


## Свиток.
static func _scroll(pt: _Paint, paper: Color) -> void:
	pt.box(Rect2(0.24, 0.2, 0.52, 0.6), 0.03, paper)
	pt.box(Rect2(0.17, 0.12, 0.66, 0.12), 0.06, paper.darkened(0.1))
	pt.box(Rect2(0.17, 0.76, 0.66, 0.12), 0.06, paper.darkened(0.1))


## Нагрудник.
static func _chest(pt: _Paint, col: Color) -> void:
	pt.poly(_v([Vector2(0.18, 0.4), Vector2(0.36, 0.3), Vector2(0.64, 0.3), Vector2(0.82, 0.4),
		Vector2(0.74, 0.88), Vector2(0.26, 0.88)]), col)
