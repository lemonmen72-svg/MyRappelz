class_name Blessing
extends RefCounted
## Благословения Сестры Аделины (баффер, NpcData "buffer"; пункт диалога «Благословения» — action "bless", страница
## Npcs "bless"). По базе оригинала (скрипт сервера «NPC Buff», баффер Hidden Valley): семь отдельных усилений
## (состояния 1007–1013 StateResource, effect_type 2: доля за уровень × уровень) — физ. атака, маг. атака, защита,
## маг. защита, скорость каста и бег — уровень 6.5 по 3 % (+19.5 %), скорость атаки — уровень 9 по 2 % (+18 %);
## на 1 час (add_state 360000 = 3600 с), каждое — и герою, и призванному существу (add_cstate), по 3000 зол. (в
## оригинале — только премиум-игрокам; у нас всем). Повтор того же — отсчёт заново. «Все сразу» — все семь.

## Баффер всем — только на время тестирования игры (решение Максима); к релизу false: жрица и святилище — только
## у админа (AdminPanel.enabled(), логин Dedok_max), у остальных её в мире нет.
const PUBLIC := true
const DURATION := 3600.0
const PRICE := 3000
## id → [название, ключ бонуса героя (HeroSkills.BONUS_NAMES), уровень, доля за уровень, буква значка, цвет].
const BUFFS := {
	"might": ["Благословение силы", "atk_pct", 6.5, 0.03, "С", Color(0.95, 0.45, 0.3)],
	"arcana": ["Благословение чар", "matk_pct", 6.5, 0.03, "Ч", Color(0.6, 0.45, 0.95)],
	"bulwark": ["Благословение стойкости", "def_pct", 6.5, 0.03, "З", Color(0.75, 0.62, 0.4)],
	"ward": ["Благословение оберега", "mdef_pct", 6.5, 0.03, "О", Color(0.45, 0.7, 0.95)],
	"fury": ["Благословение ярости", "aspd", 9.0, 0.02, "Я", Color(0.95, 0.65, 0.25)],
	"word": ["Благословение слова", "cast", 6.5, 0.03, "К", Color(0.55, 0.85, 0.95)],
	"wind": ["Благословение ветра", "speed_pct", 6.5, 0.03, "В", Color(0.55, 0.9, 0.55)],
}
const ORDER := ["might", "arcana", "bulwark", "ward", "fury", "word", "wind"]


## Доступен ли баффер этому игроку (PUBLIC или админ).
static func available() -> bool:
	return PUBLIC or AdminPanel.enabled()


## Состояние героя / питомца: "bless_<id>".
static func sid(id: String) -> String:
	return "bless_" + id


## Доля прибавки: 0.195 (+19.5 %).
static func amount(id: String) -> float:
	var b: Array = BUFFS.get(id, ["", "", 0.0, 0.0])
	return float(b[2]) * float(b[3])


static func title(id: String) -> String:
	return String((BUFFS.get(id, [id]) as Array)[0])


## «физ. атака +19.5 %».
static func effect_text(id: String) -> String:
	var b: Array = BUFFS.get(id, ["", ""])
	var key := String(b[1])
	var nm := "маг. защита" if key == "mdef_pct" else String(HeroSkills.BONUS_NAMES.get(key, key))
	return "%s +%s %%" % [nm, String.num(amount(id) * 100.0, 1).trim_suffix(".0")]


## Подпись кнопки: «Благословение силы: атака +19.5 % — 3000 зол.».
static func label(id: String) -> String:
	return "%s: %s — %d зол." % [title(id), effect_text(id), PRICE]


static func label_all() -> String:
	return "Все благословения сразу — %d зол." % (PRICE * ORDER.size())


static func source(id: String) -> Dictionary:
	var b: Array = BUFFS[id]
	return {"name": String(b[0]), "icon": IconView.effect(sid(id), String(b[4]), b[5])}


## Благословить героя p (и призванного питомца pet) одним усилением id: "" — получилось, иначе причина отказа.
static func give(p: Player, id: String, pet: Node = null) -> String:
	return give_many(p, [id], pet)


## Несколько усилений за раз (цена — за каждое): "" — получилось.
static func give_many(p: Player, ids: Array, pet: Node = null) -> String:
	if p == null:
		return "Героя нет"
	for id in ids:
		if not BUFFS.has(String(id)):
			return "Нет такого благословения"
	var cost := PRICE * ids.size()
	if Game.gold < cost:
		return "Не хватает золота: нужно %d зол." % cost
	Game.gold -= cost
	Game.changed.emit()
	for id in ids:
		var s := String(id)
		var bonus := {String((BUFFS[s] as Array)[1]): amount(s)}
		p.add_timed_bonus(sid(s), DURATION, bonus, source(s))
		if pet != null and is_instance_valid(pet) and pet.has_method("apply_hero_buff"):
			pet.call("apply_hero_buff", sid(s), DURATION, bonus, source(s))
	return ""


## Действует ли усиление id на герое p.
static func active(p: Player, id: String) -> bool:
	return p != null and p.timed_bonus.has(sid(id))


## Сколько секунд осталось (0 — нет).
static func left(p: Player, id: String) -> float:
	if p == null or not p.timed_bonus.has(sid(id)):
		return 0.0
	return float((p.timed_bonus[sid(id)] as Dictionary).get("left", 0.0))
