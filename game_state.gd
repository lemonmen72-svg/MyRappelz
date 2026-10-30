extends Node
## Автозагрузка Game: персонаж, сумка, питомцы, сохранение в user://.

signal changed

const SAVE_VERSION := 1
const MAX_PETS := 6

## Тесты подменяют путь, чтобы не трогать настоящее сохранение.
var save_path := "user://save.json"

var has_character := false
var char_name := ""
var race_id := ""
var class_id := ""
var level := 1
var xp := 0
var gold := 0
var inventory := Inventory.new()
## Питомцы: {"species": String, "name": String, "level": int, "xp": int, "hp": int, "dead": bool}.
## hp = -1: полное здоровье.
var pets: Array[Dictionary] = []
## Индекс призванного питомца в pets, -1: никого.
var active_pet := -1


func _ready() -> void:
	inventory.changed.connect(func(): changed.emit())


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if has_character:
			save_game()


## Опыт до следующего уровня персонажа.
func xp_to_next(lvl: int) -> int:
	return int(30.0 * pow(1.5, lvl - 1))


func reset() -> void:
	has_character = false
	char_name = ""
	race_id = ""
	class_id = ""
	level = 1
	xp = 0
	gold = 0
	inventory.from_dict({})
	pets.clear()
	active_pet = -1


func new_character(n: String, race: String, cls: String) -> void:
	reset()
	has_character = true
	char_name = n
	race_id = race
	class_id = cls
	gold = 50
	inventory.add("crystal_common", 3)
	inventory.add("hp_potion", 3)
	inventory.add("revive_scroll", 1)
	changed.emit()


## Добавляет питомца в коллекцию. Возвращает индекс или -1, если места нет.
func add_pet(species: String, pet_name: String, lvl: int = 1) -> int:
	if pets.size() >= MAX_PETS:
		return -1
	pets.append({"species": species, "name": pet_name, "level": lvl, "xp": 0, "hp": -1, "dead": false})
	changed.emit()
	return pets.size() - 1


func remove_pet(i: int) -> void:
	if i < 0 or i >= pets.size():
		return
	pets.remove_at(i)
	if active_pet == i:
		active_pet = -1
	elif active_pet > i:
		active_pet -= 1
	changed.emit()


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"name": char_name, "race": race_id, "class": class_id,
		"level": level, "xp": xp, "gold": gold,
		"inventory": inventory.to_dict(),
		"pets": pets.duplicate(true),
		"active_pet": active_pet,
	}


func from_dict(d: Dictionary) -> void:
	reset()
	has_character = true
	char_name = String(d.get("name", "Герой"))
	race_id = String(d.get("race", "human"))
	class_id = String(d.get("class", "warrior"))
	level = int(d.get("level", 1))
	xp = int(d.get("xp", 0))
	gold = int(d.get("gold", 0))
	inventory.from_dict(migrate_items(d.get("inventory", {})))
	for p in d.get("pets", []):
		var r: Dictionary = p
		var sp := String(r.get("species", "boar"))
		var lvl := int(r.get("level", 1))
		var pet_name := String(r.get("name", "Питомец"))
		var new_sp := MobData.migrate_id(sp)
		if new_sp != sp:
			# Вид из старой версии заменён новым: имя — название стадии нового вида
			sp = new_sp
			pet_name = PetData.stage_name(sp, lvl)
		pets.append({
			"species": sp, "name": pet_name,
			"level": lvl, "xp": int(r.get("xp", 0)),
			"hp": int(r.get("hp", -1)), "dead": bool(r.get("dead", false)),
		})
	active_pet = int(d.get("active_pet", -1))
	if active_pet >= pets.size():
		active_pet = -1
	changed.emit()


## Сумка из сохранения с прежними id предметов (bear_claw и т. п.) → новые id, количества складываются.
static func migrate_items(src: Dictionary) -> Dictionary:
	var res: Dictionary = {}
	for k in src:
		var id := ItemData.migrate_id(String(k))
		res[id] = int(res.get(id, 0)) + int(src[k])
	return res


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func save_game() -> bool:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict(), "\t"))
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return false
	var d = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary):
		return false
	from_dict(d)
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
