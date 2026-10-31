class_name Inventory
extends RefCounted
## Сумка как в MMORPG: items — id предмета → количество (по нему считают все модули), и раскладка по ячейкам
## (окно сумки InventoryWindow). Ячейка — {"id": String, "n": int} или пустая {}. Вместимость — CAPACITY ячеек,
## в ячейке стопка до ItemData.stack_size (оружие и карты с душой по 1, пустые карты до 20, расходники и трофеи до 99).
## Надетое оружие (equipped, его ставит Game через Game.weapon) числится в items, но ячейку не занимает.
## Раскладка подстраивается под items сама (_sync): лишнее снимается с последних стопок, новое докладывается
## в неполные стопки, затем в первые пустые ячейки. Принудительный add() не теряет предметы: если ячеек не хватает,
## они добавляются сверх вместимости. Добыча и покупки проверяют место (room_for, try_add) — «Сумка полна».
## Раскладка сохраняется отдельно от количеств (layout_to_array / load_layout); у старых сохранений её нет —
## предметы раскладываются по порядку сортировки.

signal changed

## Вместимость сумки, ячеек.
const CAPACITY := 40

var items: Dictionary = {}
## Надетое оружие (id предмета): одна штука не лежит в ячейках.
var equipped := "":
	set(v):
		if v != equipped:
			equipped = v
			_dirty = true

var _cells: Array = []
var _dirty := true


func count(id: String) -> int:
	return int(items.get(id, 0))


func has(id: String, n: int = 1) -> bool:
	return count(id) >= n


## Положить в сумку без проверки места (стартовые предметы, награды). Добыча и покупки — try_add.
func add(id: String, n: int = 1) -> void:
	if n <= 0:
		return
	items[id] = count(id) + n
	_dirty = true
	changed.emit()


## Положить столько, сколько поместится. Возвращает, сколько положено.
func try_add(id: String, n: int = 1) -> int:
	var k := mini(n, room_for(id))
	if k > 0:
		add(id, k)
	return k


func remove(id: String, n: int = 1) -> bool:
	if not has(id, n):
		return false
	var c := count(id) - n
	if c <= 0:
		items.erase(id)
	else:
		items[id] = c
	_dirty = true
	changed.emit()
	return true


## Заменить одну штуку old_id на new_id (пустая карта существа → карта с душой). Если ячейка, откуда взята
## штука, опустела, новый предмет ложится в неё; сумка полна — new_id всё равно кладётся (сверх вместимости,
## как add), чтобы ничего не пропало. false — old_id в сумке нет.
func replace_one(old_id: String, new_id: String) -> bool:
	if not has(old_id):
		return false
	var i := find_cell(old_id, true)
	remove(old_id)
	add(new_id)
	if i >= 0 and cell(i).is_empty():
		var j := find_cell(new_id, true)
		if j >= 0 and j != i:
			move(j, i)
	return true


## id предметов в сумке, по алфавиту.
func ids() -> Array:
	var a := items.keys()
	a.sort()
	return a


func to_dict() -> Dictionary:
	return items.duplicate()


## Количества из сохранения. Раскладка сбрасывается (её загружает load_layout).
func from_dict(d: Dictionary) -> void:
	items = {}
	for k in d:
		var c := int(d[k])
		if c > 0:
			items[String(k)] = c
	_cells = []
	_dirty = true
	changed.emit()


# ---------- Ячейки ----------

## Копия раскладки: [{"id", "n"} или {}], не меньше CAPACITY ячеек.
func cells() -> Array:
	_sync()
	return _cells.duplicate(true)


## Ячейка i: {"id": String, "n": int} или {} (пустая или за пределами).
func cell(i: int) -> Dictionary:
	_sync()
	if i < 0 or i >= _cells.size():
		return {}
	return (_cells[i] as Dictionary).duplicate()


## Сколько ячеек показывать: вместимость (или больше, если сумка переполнена принудительно).
func cell_count() -> int:
	_sync()
	return maxi(CAPACITY, _cells.size())


## Занятые ячейки.
func used_cells() -> int:
	_sync()
	var n := 0
	for c in _cells:
		if not (c as Dictionary).is_empty():
			n += 1
	return n


func is_full() -> bool:
	return used_cells() >= CAPACITY


## Сколько штук предмета ещё поместится: место в неполных стопках и свободные ячейки.
func room_for(id: String) -> int:
	_sync()
	var st := ItemData.stack_size(id)
	var room := maxi(0, CAPACITY - used_cells()) * st
	for c in _cells:
		var d: Dictionary = c
		if not d.is_empty() and String(d["id"]) == id:
			room += maxi(0, st - int(d["n"]))
	return room


## Индекс первой ячейки с предметом id (или -1). last = true — последней.
func find_cell(id: String, last: bool = false) -> int:
	_sync()
	var res := -1
	for i in _cells.size():
		var d: Dictionary = _cells[i]
		if not d.is_empty() and String(d["id"]) == id:
			res = i
			if not last:
				break
	return res


## Переложить ячейку from в ячейку to: в пустую — переносится, к стопке того же предмета — докладывается
## (что не влезло, остаётся на месте), иначе ячейки меняются местами. true — что-то изменилось.
func move(from: int, to: int) -> bool:
	_sync()
	if from == to or from < 0 or to < 0 or from >= _cells.size() or to >= cell_count():
		return false
	while _cells.size() <= to:
		_cells.append({})
	var a: Dictionary = _cells[from]
	if a.is_empty():
		return false
	var b: Dictionary = _cells[to]
	if not b.is_empty() and String(b["id"]) == String(a["id"]):
		var st := ItemData.stack_size(String(a["id"]))
		var k := mini(st - int(b["n"]), int(a["n"]))
		if k > 0:
			b["n"] = int(b["n"]) + k
			a["n"] = int(a["n"]) - k
			if int(a["n"]) <= 0:
				_cells[from] = {}
			changed.emit()
			return true
	_cells[from] = b
	_cells[to] = a
	_trim()
	changed.emit()
	return true


## Убрать n штук из ячейки i (n < 0 — всю стопку). Возвращает, сколько убрано.
func remove_at(i: int, n: int = -1) -> int:
	_sync()
	if i < 0 or i >= _cells.size():
		return 0
	var c: Dictionary = _cells[i]
	if c.is_empty():
		return 0
	var have := int(c["n"])
	var k := have if n < 0 else mini(n, have)
	if k <= 0:
		return 0
	var id := String(c["id"])
	if have - k <= 0:
		_cells[i] = {}
	else:
		c["n"] = have - k
	var left := count(id) - k
	if left <= 0:
		items.erase(id)
	else:
		items[id] = left
	_trim()
	changed.emit()
	return k


## Сортировка: по типу (оружие, расходники, карты, трофеи), редкости (сначала лучшие), названию;
## стопки собираются до максимума, пустые ячейки — в конце.
func sort() -> void:
	_sync()
	var totals: Dictionary = {}
	for c in _cells:
		var d: Dictionary = c
		if not d.is_empty():
			var id := String(d["id"])
			totals[id] = int(totals.get(id, 0)) + int(d["n"])
	_cells = []
	for key in sorted_ids(totals.keys()):
		var id := String(key)
		var st := ItemData.stack_size(id)
		var left := int(totals[id])
		while left > 0:
			var k := mini(st, left)
			_cells.append({"id": id, "n": k})
			left -= k
	while _cells.size() < CAPACITY:
		_cells.append({})
	changed.emit()


## id в порядке сортировки сумки (ItemData.sort_before).
static func sorted_ids(list: Array) -> Array:
	var a: Array = []
	for x in list:
		a.append(String(x))
	a.sort_custom(func(x: String, y: String) -> bool: return ItemData.sort_before(x, y))
	return a


# ---------- Сохранение раскладки ----------

## Раскладка для save.json: [{"id": String, "n": int} или {}] по ячейкам.
func layout_to_array() -> Array:
	return cells()


## Раскладка из сохранения (после from_dict). Неизвестные записи пропускаются; расхождения с количествами
## исправит _sync. Старые сохранения (нет раскладки) — предметы ложатся по порядку сортировки.
func load_layout(src: Variant) -> void:
	_cells = []
	if src is Array:
		for e in src:
			if e is Dictionary and (e as Dictionary).has("id"):
				var d: Dictionary = e
				var id := ItemData.migrate_id(String(d["id"]))
				var n := int(d.get("n", 1))
				_cells.append({"id": id, "n": n} if n > 0 and id != "" else {})
			else:
				_cells.append({})
	_dirty = true
	changed.emit()


# ---------- Внутреннее ----------

## Привести ячейки к количествам items (минус надетое оружие).
func _sync() -> void:
	if not _dirty:
		return
	_dirty = false
	while _cells.size() < CAPACITY:
		_cells.append({})
	var want: Dictionary = {}
	for key in items:
		var id := String(key)
		var n := count(id) - (1 if id == equipped else 0)
		if n > 0:
			want[id] = n
	# Лишнее и чужое снимается с последних стопок (ранние стопки сохраняются)
	var have: Dictionary = {}
	for i in _cells.size():
		var d: Dictionary = _cells[i]
		if d.is_empty():
			continue
		var id := String(d["id"])
		var n := mini(int(d["n"]), ItemData.stack_size(id))
		n = mini(n, int(want.get(id, 0)) - int(have.get(id, 0)))
		if n <= 0:
			_cells[i] = {}
		else:
			_cells[i] = {"id": id, "n": n}
			have[id] = int(have.get(id, 0)) + n
	# Недостающее — в неполные стопки, затем в первые пустые ячейки
	for key in sorted_ids(want.keys()):
		var id := String(key)
		var miss := int(want[id]) - int(have.get(id, 0))
		if miss <= 0:
			continue
		var st := ItemData.stack_size(id)
		for c in _cells:
			if miss <= 0:
				break
			var d: Dictionary = c
			if not d.is_empty() and String(d["id"]) == id and int(d["n"]) < st:
				var k := mini(st - int(d["n"]), miss)
				d["n"] = int(d["n"]) + k
				miss -= k
		var i := 0
		while miss > 0:
			if i >= _cells.size():
				_cells.append({})
			if (_cells[i] as Dictionary).is_empty():
				var k := mini(st, miss)
				_cells[i] = {"id": id, "n": k}
				miss -= k
			i += 1
	_trim()


## Пустые ячейки сверх вместимости в конце не нужны.
func _trim() -> void:
	while _cells.size() > CAPACITY and (_cells.back() as Dictionary).is_empty():
		_cells.pop_back()
