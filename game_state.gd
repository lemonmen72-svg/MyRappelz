extends Node
## Автозагрузка Game: персонаж, сумка, оружие и умения героя, питомцы, сохранение в user://.
## Герой игрока всегда тёмная эльфийка-Наёмник (ClassData.HERO_RACE / HERO_CLASS): старые сохранения с другой
## расой или классом переводятся при загрузке (from_dict) — уровень, опыт, золото, сумка и питомцы сохраняются,
## выдаётся оружие Наёмника, JP — как будто копились с 1 уровня. Новый персонаж другого класса создаётся
## только автотестами (проверка механики классов).

signal changed

const SAVE_VERSION := 1
const MAX_PETS := 6
## Виды питомцев, ушедшие с острова (модели из примитивов), → вид, которым становится питомец при загрузке.
const RETIRED_PETS := {"boar": "wolf", "golem": "turtle"}

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
## со стартовым набором (Наёмник), у остальных оружие задано классом. Надетое оружие не занимает ячейку сумки
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
## Сообщение игроку после загрузки (герой переведён в Наёмника); main показывает его при входе и очищает.
var load_note := ""
## Питомцы: {"species": String, "name": String, "level": int, "xp": int, "hp": int, "dead": bool,
## "mp": int, "jp": int (очки умений), "jp_part": float (накопленная доля JP), "skills": {id умения: уровень},
## "toggles": {id включённого переключаемого умения: true}} (умения — PetSkills). hp, mp = -1: полный запас.
var pets: Array[Dictionary] = []
## Индекс призванного питомца в pets, -1: никого.
var active_pet := -1
## Задания (QuestData, логика — Quests): взятые {id: {"progress": [число по каждой цели]}} в порядке взятия,
## сданные {id: сколько раз сдано}, отслеживаемое на экране ("" — никакое).
var quests_active: Dictionary = {}
var quests_done: Dictionary = {}
var quest_tracked := ""


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
	load_note = ""
	pets.clear()
	active_pet = -1
	quests_active = {}
	quests_done = {}
	quest_tracked = ""


func new_character(n: String, race: String, cls: String) -> void:
	reset()
	has_character = true
	char_name = n
	race_id = race
	class_id = cls
	gold = 50
	inventory.add("hp_potion", 3)
	inventory.add("revive_scroll", 1)
	hero = HeroSkills.new_record(cls, 1)
	ensure_hero()
	changed.emit()


## Приводит умения и оружие героя к текущему классу: запись умений (HeroSkills.ensure_record),
## стартовый набор оружия в сумке у Наёмника (если оружия нет совсем) и надетое оружие (по умолчанию — первое
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
		"quests": {"active": quests_active.duplicate(true), "done": quests_done.duplicate(), "tracked": quest_tracked},
	}


func from_dict(d: Dictionary) -> void:
	reset()
	has_character = true
	char_name = String(d.get("name", "Герой"))
	race_id = String(d.get("race", ClassData.HERO_RACE))
	class_id = String(d.get("class", ClassData.HERO_CLASS))
	# Герой — всегда Наёмник: другие раса и класс (старые сохранения) переводятся, прежние умения класса
	# не переносятся (у Наёмника своё древо)
	var converted := race_id != ClassData.HERO_RACE or class_id != ClassData.HERO_CLASS
	if converted:
		race_id = ClassData.HERO_RACE
		class_id = ClassData.HERO_CLASS
		load_note = "Ваш герой стал Наёмником: остальные профессии появятся позже"
	level = int(d.get("level", 1))
	xp = int(d.get("xp", 0))
	gold = int(d.get("gold", 0))
	# Кристаллы души старых версий заменены зеркальными картами (ItemData.RENAMED), за редкий и древний —
	# доплата золотом; убранные карты кабана и стража — тоже зеркальные карты
	var old_inv: Dictionary = d.get("inventory", {})
	gold += ItemData.legacy_gold(old_inv)
	var legacy_note := _legacy_note(old_inv)
	if legacy_note != "":
		load_note = legacy_note if load_note == "" else load_note + ". " + legacy_note
	inventory.from_dict(migrate_items(old_inv))
	inventory.load_layout(d.get("bag", []))
	var retired := false
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
		# Кабан и каменный страж (модели из примитивов) ушли с острова: питомец становится волком / черепахой
		# с тем же уровнем и опытом, JP за умения, которых у нового вида нет, возвращаются
		var refund := 0
		if RETIRED_PETS.has(sp):
			var old_sp := sp
			sp = String(RETIRED_PETS[old_sp])
			refund = retired_refund(sp, r.get("skills", {}))
			if (PetData.get_species(old_sp)["stages"] as Array).has(pet_name):
				pet_name = PetData.stage_name(sp, lvl)
			retired = true
		pets.append({
			"species": sp, "name": pet_name,
			"level": lvl, "xp": int(r.get("xp", 0)),
			"hp": int(r.get("hp", -1)), "dead": bool(r.get("dead", false)),
			"mp": int(r.get("mp", -1)),
			# Старые сохранения без JP: столько, сколько питомец накопил бы к своему уровню
			"jp": int(r.get("jp", PetStats.default_jp(lvl))) + refund,
			"jp_part": float(r.get("jp_part", 0.0)),
			"skills": _load_skills(sp, r.get("skills", {})),
			"toggles": _load_toggles(r.get("toggles", {}), sp),
		})
	if retired:
		var pet_note := "Кабаны и каменные стражи ушли с острова: ваши питомцы-кабаны стали волками, стражи — черепахами (уровень и опыт сохранены, JP за недоступные умения возвращены)"
		load_note = pet_note if load_note == "" else load_note + ". " + pet_note
	active_pet = int(d.get("active_pet", -1))
	if active_pet >= pets.size():
		active_pet = -1
	# Задания (старые сохранения — без заданий)
	_load_quests(d.get("quests", {}))
	# Оружие (старые сохранения Наёмника и переведённые герои — парные мечи и стартовый набор в сумку,
	# см. ensure_hero)
	weapon = "" if converted else String(d.get("weapon", ""))
	# Умения героя: старые сохранения — JP, как будто копились с 1 уровня, стартовые умения
	var h: Variant = d.get("hero", null)
	if converted:
		# Прежний класс тратил JP только на свои умения (бесплатные): ничего не теряется
		hero = HeroSkills.new_record(class_id, level)
		if h is Dictionary:
			var old: Dictionary = h
			hero["jp"] = maxi(int(hero["jp"]), int(old.get("jp", 0)))
			hero["jp_part"] = float(old.get("jp_part", 0.0))
	elif h is Dictionary:
		hero = (h as Dictionary).duplicate(true)
		hero["jp"] = int(hero.get("jp", HeroSkills.default_jp(level)))
		hero["jp_part"] = float(hero.get("jp_part", 0.0))
	else:
		hero = HeroSkills.new_record(class_id, level)
	ensure_hero()
	changed.emit()


## Задания из сохранения: только известные (QuestData), прогресс — целые числа по числу целей (JSON хранит
## числа как float), отслеживаемое — только из взятых.
func _load_quests(src: Variant) -> void:
	quests_active = {}
	quests_done = {}
	quest_tracked = ""
	if not (src is Dictionary):
		return
	var d: Dictionary = src
	var act: Variant = d.get("active", {})
	if act is Dictionary:
		for k in act:
			var id := String(k)
			if not QuestData.has_quest(id):
				continue
			var rec: Variant = (act as Dictionary)[k]
			var old: Array = []
			if rec is Dictionary and (rec as Dictionary).get("progress", []) is Array:
				old = (rec as Dictionary)["progress"]
			var prog: Array = []
			var goals := QuestData.goals(id)
			for gi in goals.size():
				var v := int(old[gi]) if gi < old.size() else 0
				prog.append(clampi(v, 0, QuestData.goal_need(goals[gi])))
			quests_active[id] = {"progress": prog}
	var dn: Variant = d.get("done", {})
	if dn is Dictionary:
		for k in dn:
			var n := int((dn as Dictionary)[k])
			if n > 0 and QuestData.has_quest(String(k)):
				quests_done[String(k)] = n
	var tr := String(d.get("tracked", ""))
	if quests_active.has(tr):
		quest_tracked = tr


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


static func _load_toggles(src: Variant, species: String = "") -> Dictionary:
	var res: Dictionary = {}
	if not (src is Dictionary):
		return res
	var d: Dictionary = src
	for k in d:
		if bool(d[k]) and (species == "" or PetSkills.has_skill(species, String(k))):
			res[String(k)] = true
	return res


## JP за изученные умения, которых нет у вида species (питомец ушедшего с острова вида): уровень × цена уровня.
static func retired_refund(species: String, src: Variant) -> int:
	var jp := 0
	if not (src is Dictionary):
		return jp
	var d: Dictionary = src
	for k in d:
		var id := String(k)
		var sk := PetSkills.get_skill(id)
		if sk.is_empty() or PetSkills.has_skill(species, id):
			continue
		jp += mini(int(d[k]), PetSkills.max_level(id)) * int(sk.get("jp", 1))
	return jp


## Сообщение о замене кристаллов души и убранных карт (кабана, стража) зеркальными картами
## ("" — заменять было нечего).
static func _legacy_note(src: Dictionary) -> String:
	var crystals := false
	var cards := false
	for k in src:
		var id := String(k)
		if int(src[k]) <= 0:
			continue
		if id.begins_with("crystal_"):
			crystals = true
		elif id.begins_with("card_boar") or id.begins_with("card_golem"):
			cards = true
	var parts: Array = []
	if crystals:
		parts.append("Кристаллы души заменены картами: теперь зверей приручают картами существ")
	if cards:
		parts.append("Кабана и каменного стража больше нельзя приручить: их карты стали зеркальными")
	return ". ".join(PackedStringArray(parts))


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
