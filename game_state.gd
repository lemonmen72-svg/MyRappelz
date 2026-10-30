extends Node
## Автозагрузка Game: персонаж, сумка, оружие и умения героя, питомцы, сохранение в user://.

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
## Надетое оружие (id предмета ItemData из сумки; "" — нет). Сменное оружие только у классов
## со стартовым набором (Бродяга), у остальных оружие задано классом. Надетое оружие не занимает ячейку сумки
## (inventory.equipped), в окне сумки оно в слоте «Оружие».
var weapon := "":
	set(v):
		weapon = v
		inventory.equipped = v
## Умения героя (HeroSkills): {"jp": int, "jp_part": float, "skills": {id: ур.}, "toggles": {id: true},
## "slots": [id умения на кнопке skill1…skill4 или ""]}.
var hero: Dictionary = {}
## Переключаемые умения, выключенные последней сменой оружия (для сообщения игроку).
var last_dropped_toggles: Array = []
## Питомцы: {"species": String, "name": String, "level": int, "xp": int, "hp": int, "dead": bool,
## "mp": int, "jp": int (очки умений), "jp_part": float (накопленная доля JP), "skills": {id умения: уровень},
## "toggles": {id включённого переключаемого умения: true}} (умения — PetSkills). hp, mp = -1: полный запас.
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
	weapon = ""
	hero = {}
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
	hero = HeroSkills.new_record(cls, 1)
	ensure_hero()
	changed.emit()


## Приводит умения и оружие героя к текущему классу: запись умений (HeroSkills.ensure_record),
## стартовый набор оружия в сумке у Бродяги (если оружия нет совсем) и надетое оружие (по умолчанию — первое
## из набора, у старых сохранений — парные мечи). Вызывается при создании, загрузке и смене класса.
func ensure_hero() -> void:
	if hero.is_empty():
		hero = HeroSkills.new_record(class_id, level)
	HeroSkills.ensure_record(hero, class_id)
	if not ItemData.class_uses_weapons(class_id):
		weapon = ""
		return
	var has_any := false
	for id in inventory.ids():
		if ItemData.weapon_fits(String(id), class_id):
			has_any = true
	if not has_any:
		for id in ItemData.STARTER_WEAPONS[class_id]:
			inventory.add(String(id))
	if not (ItemData.weapon_fits(weapon, class_id) and inventory.has(weapon)):
		weapon = ItemData.default_weapon(class_id)
		if not inventory.has(weapon):
			for id in inventory.ids():
				if ItemData.weapon_fits(String(id), class_id):
					weapon = String(id)
					break
	HeroSkills.drop_unfit_toggles(hero, weapon_kind())


## Вид надетого оружия ("daggers" | "dual_swords" | "crossbow"); у классов без сменного оружия — "".
func weapon_kind() -> String:
	return ItemData.weapon_kind(weapon)


## Надеть оружие id из сумки. "" — получилось, иначе причина. Переключаемые умения, которым новое оружие
## не подходит, выключаются (их id — в last_dropped_toggles).
func equip_weapon(id: String) -> String:
	last_dropped_toggles = []
	if not ItemData.is_weapon(id):
		return "Это не оружие"
	if not ItemData.weapon_fits(id, class_id):
		return "Это оружие не для класса «%s»" % String(ClassData.cls(class_id)["name"])
	if not inventory.has(id):
		return "Этого оружия нет в сумке"
	weapon = id
	last_dropped_toggles = HeroSkills.drop_unfit_toggles(hero, weapon_kind())
	changed.emit()
	return ""


## Добавляет питомца в коллекцию. Возвращает индекс или -1, если места нет.
func add_pet(species: String, pet_name: String, lvl: int = 1) -> int:
	if pets.size() >= MAX_PETS:
		return -1
	pets.append({
		"species": species, "name": pet_name, "level": lvl, "xp": 0, "hp": -1, "dead": false,
		"mp": -1, "jp": PetStats.default_jp(lvl), "jp_part": 0.0, "skills": {}, "toggles": {},
	})
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
		# Раскладка сумки по ячейкам (у старых сохранений нет — предметы ложатся по порядку сортировки)
		"bag": inventory.layout_to_array(),
		"weapon": weapon,
		"hero": hero.duplicate(true),
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
	inventory.load_layout(d.get("bag", []))
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
			"mp": int(r.get("mp", -1)),
			# Старые сохранения без JP: столько, сколько питомец накопил бы к своему уровню
			"jp": int(r.get("jp", PetStats.default_jp(lvl))),
			"jp_part": float(r.get("jp_part", 0.0)),
			"skills": _load_skills(sp, r.get("skills", {})),
			"toggles": _load_toggles(r.get("toggles", {})),
		})
	active_pet = int(d.get("active_pet", -1))
	if active_pet >= pets.size():
		active_pet = -1
	# Оружие (старые сохранения Бродяги — парные мечи и стартовый набор в сумку, см. ensure_hero)
	weapon = String(d.get("weapon", ""))
	# Умения героя: старые сохранения — JP, как будто копились с 1 уровня, стартовые умения
	var h: Variant = d.get("hero", null)
	if h is Dictionary:
		hero = (h as Dictionary).duplicate(true)
		hero["jp"] = int(hero.get("jp", HeroSkills.default_jp(level)))
		hero["jp_part"] = float(hero.get("jp_part", 0.0))
	else:
		hero = HeroSkills.new_record(class_id, level)
	ensure_hero()
	changed.emit()


## Изученные умения из сохранения: только известные виду, уровни — целые (JSON хранит числа как float).
static func _load_skills(species: String, src: Variant) -> Dictionary:
	var res: Dictionary = {}
	if not (src is Dictionary):
		return res
	var d: Dictionary = src
	for k in d:
		var id := String(k)
		var n := mini(int(d[k]), PetSkills.max_level(id))
		if n > 0 and PetSkills.has_skill(species, id):
			res[id] = n
	return res


static func _load_toggles(src: Variant) -> Dictionary:
	var res: Dictionary = {}
	if not (src is Dictionary):
		return res
	var d: Dictionary = src
	for k in d:
		if bool(d[k]):
			res[String(k)] = true
	return res


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
