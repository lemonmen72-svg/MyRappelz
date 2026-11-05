class_name Blessing
extends RefCounted
## Благословение света у Сестры Аделины (баффер, NpcData "buffer"; пункт диалога «Благословение» — action "bless"):
## усиление героя на DURATION — атака, маг. атака, защита, бег (Player.add_timed_bonus, значок "buff:blessing").
## Новичкам до FREE_BELOW уровня — даром, дальше — PRICE_PER_LEVEL зол. за уровень героя. Повтор — отсчёт заново.

const ID := "blessing"
const TITLE := "Благословение света"
const DURATION := 1800.0
const FREE_BELOW := 20
const PRICE_PER_LEVEL := 100
const BONUS := {"atk_pct": 0.08, "matk_pct": 0.08, "def_pct": 0.08, "speed_pct": 0.05}
const COLOR := Color(1.0, 0.82, 0.35)


## Цена благословения для героя уровня lvl (0 — даром).
static func price(lvl: int) -> int:
	return 0 if lvl < FREE_BELOW else PRICE_PER_LEVEL * lvl


## Что даёт («атака +8 %, …»).
static func bonus_text() -> String:
	var parts: PackedStringArray = []
	for k in BONUS:
		parts.append("%s +%d %%" % [String(HeroSkills.BONUS_NAMES.get(k, k)), roundi(float(BONUS[k]) * 100.0)])
	return ", ".join(parts)


## Подпись пункта диалога: «Благословение (даром)» / «Благословение (2500 зол.)».
static func label(lvl: int) -> String:
	var p := price(lvl)
	return "Благословение (%s)" % ("даром" if p == 0 else "%d зол." % p)


## Благословить героя p: "" — получилось, иначе причина отказа.
static func give(p: Player) -> String:
	if p == null:
		return "Героя нет"
	var cost := price(Game.level)
	if Game.gold < cost:
		return "Не хватает золота: благословение стоит %d зол." % cost
	Game.gold -= cost
	Game.changed.emit()
	p.add_timed_bonus(ID, DURATION, BONUS.duplicate(), {"name": TITLE, "icon": IconView.glyph("Б", COLOR)})
	return ""


## Действует ли благословение на герое p.
static func active(p: Player) -> bool:
	return p != null and p.timed_bonus.has(ID)
