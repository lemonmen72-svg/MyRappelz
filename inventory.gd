class_name Inventory
extends RefCounted
## Сумка: id предмета -> количество.

signal changed

var items: Dictionary = {}


func count(id: String) -> int:
	return int(items.get(id, 0))


func has(id: String, n: int = 1) -> bool:
	return count(id) >= n


func add(id: String, n: int = 1) -> void:
	if n <= 0:
		return
	items[id] = count(id) + n
	changed.emit()


func remove(id: String, n: int = 1) -> bool:
	if not has(id, n):
		return false
	var c := count(id) - n
	if c <= 0:
		items.erase(id)
	else:
		items[id] = c
	changed.emit()
	return true


## id предметов в сумке, по алфавиту.
func ids() -> Array:
	var a := items.keys()
	a.sort()
	return a


func to_dict() -> Dictionary:
	return items.duplicate()


func from_dict(d: Dictionary) -> void:
	items = {}
	for k in d:
		var c := int(d[k])
		if c > 0:
			items[String(k)] = c
	changed.emit()
