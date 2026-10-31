extends Node
## Автозагрузка Game: персонаж, сумка, оружие и умения героя, питомцы, сохранение в user://.
## Новый герой любой расы и пола — Бродяга (ClassData.WANDERER); с 10 ур. — задание на профессию у мудреца, смена —
## change_job (одна из трёх профессий своей расы, сверх-эволюция ClassData.over_jp, стартовое оружие профессии).
## Сохранения версии 1 (до профессий): герой-Наёмник остаётся Наёмником (профессия уже получена, без бонуса),
## другие раса и класс переводятся в тёмную эльфийку-Наёмника (как раньше) — уровень, опыт, золото, сумка и питомцы
## сохраняются, выдаётся оружие Наёмника, JP — как будто копились с 1 уровня. new_character принимает и профессию
## сразу (автотесты, админ-панель).

signal changed

## 2 — профессии (Бродяга, смена профессии, пол, щит).
const SAVE_VERSION := 2
const MAX_PETS := 6
## Виды питомцев, ушедшие с острова (модели из примитивов), → вид, которым становится питомец при загрузке.
const RETIRED_PETS := {"boar": "wolf", "golem": "turtle"}

## Тесты подменяют путь, чтобы не трогать настоящее сохранение.
var save_path := "user://save.json"

var has_character := false
var char_name := ""
var race_id := ""
## Профессия (ClassData.CLASSES; "wanderer" — Бродяга). Данные общих умений берутся для неё (HeroSkills.job).
var class_id := "":
	set(v):
		class_id = v
		HeroSkills.job = v
## Пол героя: "f" | "m" (модель — CharacterModel.hero_asset).
var gender := "f"
## Профессия получена (сменой у мудреца, админ-панелью; у сохранений версии 1 — Наёмник) и уровень, на котором
## это случилось (0 — неизвестно: старое сохранение).
var job_changed := false
var job_level_at_change := 0
var level := 1
var xp := 0
var gold := 0
var inventory := Inventory.new()
## Надетое оружие (id предмета ItemData из сумки; "" — нет), основная рука. Надетое оружие не занимает ячейку
## сумки (inventory.equipped), в окне сумки оно в слоте «Оружие».
var weapon := "":
	set(v):
		weapon = v
		inventory.equipped = v
## Вторая рука (id предмета из сумки, "" — пусто): щит (у профессий со щитом, к одноручному оружию) или второе
## одноручное того же вида — пара (два кинжала, два меча, два топора; ItemData.offhand_block). Двуручное — пусто.
var offhand := "":
	set(v):
		offhand = v
		inventory.equipped_off = v
## Щит во второй руке ("" — щита нет; запись — то же, что offhand).
var shield: String:
	get:
		return offhand if ItemData.is_shield(offhand) else ""
	set(v):
		offhand = v
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
## Множитель опыта за зверей (админ-панель, вкладка «Опыт»: 1, 2, 5, 10, 20, 50): герою и питомцу
## (main._on_mob_gone, PetManager.on_mob_killed). Хранится в сохранении; без админ-панели — всегда 1.
var xp_mult := 1


func _ready() -> void:
	inventory.changed.connect(func(): changed.emit())


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if has_character:
			save_game()


## Опыт до следующего уровня персонажа (кривая — MobStats.xp_to_next: сколько зверей своего уровня на уровень).
func xp_to_next(lvl: int) -> int:
	return MobStats.xp_to_next(lvl)


func reset() -> void:
	has_character = false
	char_name = ""
	race_id = ""
	class_id = ""
	gender = "f"
	job_changed = false
	job_level_at_change = 0
	level = 1
	xp = 0
	gold = 0
	inventory.from_dict({})
	weapon = ""
	offhand = ""
	hero = {}
	load_note = ""
	pets.clear()
	active_pet = -1
	quests_active = {}
	quests_done = {}
	quest_tracked = ""
	xp_mult = 1


## Новый герой: обычно Бродяга (экран создания); профессия cls сразу — автотесты и админ-панель
## (герой как будто уже сменил профессию, без бонуса сверх-эволюции).
func new_character(n: String, race: String, cls: String = ClassData.WANDERER, sex: String = "f") -> void:
	reset()
	has_character = true
	char_name = n
	race_id = race
	gender = sex
	class_id = ClassData.migrate_id(cls)
	if not ClassData.has_class(class_id):
		class_id = ClassData.WANDERER
	job_changed = ClassData.is_job(class_id)
	job_level_at_change = 1 if job_changed else 0
	gold = 50
	inventory.add("hp_potion", 3)
	inventory.add("revive_scroll", 1)
	hero = HeroSkills.new_record(class_id, 1)
	_give_starters(class_id)
	ensure_hero()
	changed.emit()


## Приводит умения и оружие героя к текущей профессии: запись умений (HeroSkills.ensure_record),
## стартовый набор оружия в сумке (если подходящего оружия нет совсем), надетое оружие (по умолчанию — первое
## из набора) и вторая рука (щит или пара — только по правилам ItemData.offhand_block).
## Вызывается при создании, загрузке и смене профессии.
func ensure_hero() -> void:
	if not ClassData.has_class(class_id):
		class_id = ClassData.WANDERER
	if hero.is_empty():
		hero = HeroSkills.new_record(class_id, level)
	HeroSkills.ensure_record(hero, class_id)
	var has_any := false
	for id in inventory.ids():
		if ItemData.weapon_fits(String(id), class_id) and not ItemData.is_shield(String(id)):
			has_any = true
	if not has_any:
		_give_starters(class_id)
	if not (ItemData.weapon_fits(weapon, class_id) and not ItemData.is_shield(weapon) and inventory.has(weapon)):
		weapon = ItemData.default_weapon(class_id)
		if not inventory.has(weapon):
			weapon = ""
			for id in inventory.ids():
				if ItemData.weapon_fits(String(id), class_id) and not ItemData.is_shield(String(id)):
					weapon = String(id)
					break
	if offhand != "" and offhand_block(offhand) != "":
		offhand = ""
	HeroSkills.drop_unfit_toggles(hero, weapon_kind(), has_shield())


## Стартовое оружие профессии в сумку (чего не хватает) и надеть: первое — в руку, повтор того же — во вторую руку
## (пара), щит из набора — во вторую руку (к одноручному).
func _give_starters(job: String) -> void:
	var need: Dictionary = {}
	for k in ItemData.starter_weapons(job):
		need[String(k)] = int(need.get(String(k), 0)) + 1
	for id in need:
		var miss := int(need[id]) - inventory.count(String(id))
		if miss > 0:
			inventory.add(String(id), miss)
	var first := ""
	var off := ""
	for k in ItemData.starter_weapons(job):
		var id := String(k)
		if ItemData.is_shield(id) or (first != "" and id == first):
			if off == "":
				off = id
		elif first == "":
			first = id
	if first != "":
		weapon = first
	offhand = ""
	if off != "" and offhand_block(off) == "":
		offhand = off


## Вид хвата (ItemData.grip_kind): вид надетого оружия ("sword_1h", "crossbow" …), у пары — вид пары ("daggers",
## "dual_swords", "dual_axes"); "" — без оружия. По нему — умения, модель и тип атаки.
func weapon_kind() -> String:
	return ItemData.grip_kind(weapon, offhand)


## Вид оружия в основной руке (без учёта пары).
func main_kind() -> String:
	return ItemData.weapon_kind(weapon)


## Щит во второй руке.
func has_shield() -> bool:
	return ItemData.is_shield(offhand)


## Почему id нельзя взять во вторую руку при нынешнем оружии ("" — можно): правила ItemData.offhand_block,
## предмет в сумке (второй такой же — если в основной руке тот же предмет).
func offhand_block(id: String) -> String:
	var err := ItemData.offhand_block(id, weapon, class_id)
	if err != "":
		return err
	if not inventory.has(id, 2 if id == weapon else 1):
		return "Второго такого оружия нет в сумке" if id == weapon else "Этого оружия нет в сумке"
	return ""


## Надеть оружие id из сумки в основную руку (щит — во вторую руку). "" — получилось, иначе причина. Двуручное
## оружие освобождает вторую руку, другое одноручное — снимает пару, щит остаётся. Переключаемые умения, которым
## новое оружие не подходит, выключаются (их id — в last_dropped_toggles).
func equip_weapon(id: String) -> String:
	last_dropped_toggles = []
	if not ItemData.is_weapon(id):
		return "Это не оружие"
	if ItemData.is_shield(id):
		return equip_offhand(id)
	if not ItemData.weapon_fits(id, class_id):
		return "Это оружие не для профессии «%s»" % ClassData.job_name(class_id)
	if not inventory.has(id):
		return "Этого оружия нет в сумке"
	if id == offhand and not inventory.has(id, 2):
		offhand = ""
	weapon = id
	if offhand != "" and offhand_block(offhand) != "":
		offhand = ""
	last_dropped_toggles = HeroSkills.drop_unfit_toggles(hero, weapon_kind(), has_shield())
	changed.emit()
	return ""


## Взять id во вторую руку: щит или второе такое же одноручное (пара). "" — получилось, иначе причина.
func equip_offhand(id: String) -> String:
	last_dropped_toggles = []
	if not ItemData.is_weapon(id):
		return "Это не оружие"
	if not ItemData.weapon_fits(id, class_id):
		return "Это оружие не для профессии «%s»" % ClassData.job_name(class_id)
	var err := offhand_block(id)
	if err != "":
		return err
	offhand = id
	last_dropped_toggles = HeroSkills.drop_unfit_toggles(hero, weapon_kind(), has_shield())
	changed.emit()
	return ""


## Освободить вторую руку (щит или второй клинок остаются в сумке).
func unequip_offhand() -> void:
	if offhand == "":
		return
	offhand = ""
	last_dropped_toggles = HeroSkills.drop_unfit_toggles(hero, weapon_kind(), false)
	changed.emit()


## Снять щит (то же, что освободить вторую руку).
func unequip_shield() -> void:
	unequip_offhand()


# ---------- Профессия ----------

## Можно ли сейчас сменить профессию на job ("" — можно): только Бродяга, с ClassData.JOB_LEVEL, профессия своей расы.
func job_change_block(job: String) -> String:
	if not ClassData.is_wanderer(class_id):
		return "Профессия уже выбрана: %s" % ClassData.job_name(class_id)
	if level < ClassData.JOB_LEVEL:
		return "Профессию можно выбрать с %d уровня" % ClassData.JOB_LEVEL
	if not ClassData.is_job(job) or not ClassData.jobs_of(race_id).has(job):
		return "Эта профессия не для вашей расы"
	return ""


## Сменить профессию Бродяги на job (задание мудреца): сверх-эволюция (+5 JP за уровень выше 10, до 20 ур.),
## стартовое оружие профессии в сумку и в руки, древо профессии. Возвращает бонус JP или -1 (нельзя).
func change_job(job: String) -> int:
	if job_change_block(job) != "":
		return -1
	var over := ClassData.over_jp(level)
	_set_job(job)
	job_level_at_change = level
	hero["jp"] = int(hero.get("jp", 0)) + over
	changed.emit()
	return over


## Админ-панель: профессия сразу (любая из 9 или Бродяга), без задания и бонуса. Изученные умения прежней
## профессии сбрасываются с возвратом JP. Возвращает возвращённые JP.
func admin_set_job(job: String) -> int:
	if not ClassData.has_class(job):
		return 0
	var back := HeroSkills.refund_all(hero, class_id)
	if ClassData.is_wanderer(job):
		class_id = job
		job_changed = false
		job_level_at_change = 0
		_give_starters(job)
		ensure_hero()
	else:
		_set_job(job)
		job_level_at_change = level
	changed.emit()
	return back


func _set_job(job: String) -> void:
	class_id = job
	job_changed = true
	_give_starters(job)
	ensure_hero()


## Админ-панель: раса и пол на лету (модель героя, деревня старта и возрождения). Профессия остаётся.
func admin_set_look(race: String, sex: String) -> void:
	if ClassData.RACES.has(race):
		race_id = race
	if sex == "f" or sex == "m":
		gender = sex
	changed.emit()


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
		"name": char_name, "race": race_id, "class": class_id, "gender": gender,
		"job_changed": job_changed, "job_level": job_level_at_change,
		"level": level, "xp": xp, "gold": gold,
		"inventory": inventory.to_dict(),
		# Раскладка сумки по ячейкам (у старых сохранений нет — предметы ложатся по порядку сортировки)
		"bag": inventory.layout_to_array(),
		"weapon": weapon,
		"offhand": offhand,
		"hero": hero.duplicate(true),
		"pets": pets.duplicate(true),
		"active_pet": active_pet,
		"quests": {"active": quests_active.duplicate(true), "done": quests_done.duplicate(), "tracked": quest_tracked},
		"xp_mult": xp_mult,
	}


func from_dict(d: Dictionary) -> void:
	reset()
	has_character = true
	char_name = String(d.get("name", "Герой"))
	var version := int(d.get("version", 1))
	race_id = String(d.get("race", ClassData.HERO_RACE))
	class_id = String(d.get("class", ClassData.HERO_CLASS))
	gender = String(d.get("gender", "f"))
	if gender != "m":
		gender = "f"
	var converted := false
	if version < 2:
		# Сохранения до профессий: герой — всегда Наёмник (профессия уже получена, без сверх-эволюции);
		# другие раса и класс переводятся, прежние умения класса не переносятся (у Наёмника своё древо)
		converted = race_id != ClassData.HERO_RACE or class_id != ClassData.HERO_CLASS
		if converted:
			race_id = ClassData.HERO_RACE
			class_id = ClassData.HERO_CLASS
			load_note = "Ваш герой стал Наёмником: остальные профессии появятся позже"
		job_changed = true
		job_level_at_change = 0
	else:
		if not ClassData.RACES.has(race_id):
			race_id = ClassData.HERO_RACE
		class_id = ClassData.migrate_id(class_id)
		if not ClassData.has_class(class_id):
			class_id = ClassData.WANDERER
		job_changed = bool(d.get("job_changed", ClassData.is_job(class_id))) and ClassData.is_job(class_id)
		job_level_at_change = int(d.get("job_level", 0))
	level = int(d.get("level", 1))
	# Кривая опыта менялась: накопленного не больше, чем нужно до следующего уровня
	xp = clampi(int(d.get("xp", 0)), 0, maxi(0, xp_to_next(level) - 1))
	gold = int(d.get("gold", 0))
	xp_mult = clampi(int(d.get("xp_mult", 1)), 1, 50) if AdminPanel.ADMIN_TOOLS else 1
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
	# Оружие (переведённые герои — стартовый набор Наёмника, см. ensure_hero). Вторая рука — "offhand"
	# (раньше "shield"); прежняя пара клинков одним предметом (ItemData.PAIRED) — тот же клинок в обеих руках
	var w := "" if converted else String(d.get("weapon", ""))
	var off := "" if converted else String(d.get("offhand", d.get("shield", "")))
	if ItemData.PAIRED.has(w):
		off = ItemData.migrate_id(w)
	weapon = ItemData.migrate_id(w)
	offhand = ItemData.migrate_id(off)
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
		res[id] = int(res.get(id, 0)) + int(src[k]) * ItemData.migrate_count(String(k))
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
