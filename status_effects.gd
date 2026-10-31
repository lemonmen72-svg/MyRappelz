class_name StatusEffects
extends RefCounted
## Реестр действующих эффектов сущности (герой Player, питомец Pet, зверь Mob): бафы и дебафы с длительностью
## и включённые переключаемые умения. Логику эффектов по-прежнему ведут сами сущности своими полями-таймерами
## (atk_buff_time, slow_time, dots…); реестр знает, что сейчас действует, откуда оно (значок источника — IconView)
## и сколько осталось. Его читает HUD (StatusRow — значки справа от полосок HP игрока, питомца и цели).
##
## Как пользоваться: при наложении — add(id, сек, info) (info — effect_info(): название, источник, значок,
## баф/дебаф); каждый кадр сущность сверяет оставшееся время со своим полем — sync(id, поле) (0 — эффект снят);
## переключаемые — sync_toggles(префикс, {id: info}). version растёт, только когда набор эффектов или их
## значки меняются: HUD перестраивает значки лишь тогда, а сектор времени обновляет у видимых.
##
## Запись: {"id", "name" (эффект), "src" (источник: умение, питомец; может быть ""), "icon" (спецификация IconView),
## "debuff": bool, "toggle": bool, "dur": полная длительность, с (у переключаемых 0), "left": осталось, с,
## "count": число в углу значка (заряды: искры духа Воина; −1 — без числа; задаётся в info)}.

## Виды эффектов: [название, дебаф, цвет значка без источника].
const KINDS := {
	"atk": ["Атака выше", false, Color(0.95, 0.45, 0.25)],
	"speed": ["Скорость выше", false, Color(0.45, 0.9, 0.55)],
	"guard": ["Защита: меньше урона", false, Color(1.0, 0.9, 0.5)],
	"shade": ["Уклонение, атака и крит выше", false, Color(0.55, 0.35, 0.8)],
	"stun": ["Оглушение", true, Color(1.0, 0.9, 0.35)],
	"sleep": ["Сон", true, Color(0.5, 0.6, 1.0)],
	"fear": ["Страх", true, Color(0.7, 0.4, 0.9)],
	"slow": ["Замедление", true, Color(0.55, 0.8, 1.0)],
	"blind": ["Морок: все удары мимо", true, Color(0.6, 0.5, 0.8)],
	"miss": ["Сбит прицел: часть ударов мимо", true, Color(1.0, 0.85, 0.45)],
	"vuln": ["Уязвимость: урон по цели выше", true, Color(1.0, 0.55, 0.35)],
	"weak": ["Ослабление: удары слабее", true, Color(0.95, 0.65, 0.45)],
	"taunt": ["Провокация", true, Color(0.95, 0.4, 0.3)],
	"dot": ["Урон со временем", true, Color(0.85, 0.3, 0.45)],
	"buff": ["Усиление", false, Color(0.95, 0.75, 0.35)],
	"hot": ["Лечение со временем", false, Color(0.45, 0.92, 0.55)],
}

## Растёт при добавлении, снятии эффекта и смене значка.
var version := 0
var _list: Array[Dictionary] = []


## Сведения об эффекте вида kind (KINDS) от источника src ({"name", "icon"} — source_*; пусто — значок по виду).
static func effect_info(kind: String, src: Dictionary = {}) -> Dictionary:
	var k: Array = KINDS.get(kind, [kind, false, Color(0.6, 0.6, 0.7)])
	var nm := String(k[0])
	var icon: Dictionary = src.get("icon", {})
	if icon.is_empty():
		icon = IconView.glyph(nm.substr(0, 1), k[2])
	return {"name": nm, "src": String(src.get("name", "")), "icon": icon, "debuff": bool(k[1])}


## Источник — умение героя (значок как на кнопке и в древе).
static func source_hero_skill(id: String) -> Dictionary:
	return {"name": String(HeroSkills.get_skill(id).get("name", id)), "icon": IconView.hero_skill(id)}


## Источник — умение питомца вида species.
static func source_pet_skill(species: String, id: String) -> Dictionary:
	return {"name": String(PetSkills.get_skill(id).get("name", id)), "icon": IconView.pet_skill(species, id)}


## Источник — врождённое умение роли питомца (PetData.skill: «Вызов» танка и т. п.).
static func source_role_skill(species: String) -> Dictionary:
	var sk := PetData.skill(species)
	var nm := String(sk.get("name", "Умение"))
	return {"name": nm, "icon": IconView.glyph(nm.substr(0, 1), CreatureModels.role_color(PetData.role(species)))}


## Сведения о переключаемом умении (значок без таймера); owner — чьё умение (имя питомца), если не своё.
static func toggle_info(src: Dictionary, owner: String = "") -> Dictionary:
	return {"name": "включено", "src": String(src.get("name", "")) + (" (%s)" % owner if owner != "" else ""),
		"icon": src.get("icon", {}), "debuff": false}


## Наложить (или продлить) эффект id на sec секунд. Если уже действует дольше — остаётся как есть.
## Продление сверх оставшегося — отсчёт доли заново (dur = sec).
func add(id: String, sec: float, info: Dictionary) -> void:
	if sec <= 0.0:
		return
	var e := get_entry(id)
	if e.is_empty():
		e = {"id": id, "toggle": false, "dur": sec, "left": sec}
		_set_info(e, info)
		_list.append(e)
		version += 1
		return
	if sec > float(e["left"]) + 0.01:
		e["dur"] = sec
		e["left"] = sec
		e["toggle"] = false
		if _set_info(e, info):
			version += 1


## Оставшееся время эффекта id из поля сущности: left <= 0 — эффект снят. Продлили в обход add — доля заново.
func sync(id: String, left: float) -> void:
	for i in _list.size():
		var e: Dictionary = _list[i]
		if String(e["id"]) != id:
			continue
		if bool(e["toggle"]):
			return
		if left <= 0.0:
			_list.remove_at(i)
			version += 1
		else:
			if left > float(e["left"]) + 0.05:
				e["dur"] = left
			e["left"] = left
		return


## Переключаемые с префиксом prefix ("toggle:", "pet:"): ровно те, что в on ({полный id: info}).
func sync_toggles(prefix: String, on: Dictionary) -> void:
	var i := _list.size() - 1
	while i >= 0:
		var id := String(_list[i]["id"])
		if id.begins_with(prefix) and not on.has(id):
			_list.remove_at(i)
			version += 1
		i -= 1
	for id in on:
		var e := get_entry(String(id))
		if e.is_empty():
			e = {"id": String(id), "toggle": true, "dur": 0.0, "left": 0.0}
			_set_info(e, on[id])
			_list.append(e)
			version += 1
		elif _set_info(e, on[id]):
			version += 1


func remove(id: String) -> void:
	for i in _list.size():
		if String(_list[i]["id"]) == id:
			_list.remove_at(i)
			version += 1
			return


func clear() -> void:
	if not _list.is_empty():
		_list.clear()
		version += 1


func has(id: String) -> bool:
	return not get_entry(id).is_empty()


func is_empty() -> bool:
	return _list.is_empty()


## Запись эффекта id (пустой словарь — нет такого).
func get_entry(id: String) -> Dictionary:
	for e in _list:
		if String(e["id"]) == id:
			return e
	return {}


## Действующие эффекты в порядке наложения (сам массив реестра — не менять).
func entries() -> Array[Dictionary]:
	return _list


## Доля оставшегося времени записи e: 1 — только что наложен, 0 — кончился; у переключаемых — 1.
static func left_frac(e: Dictionary) -> float:
	if bool(e.get("toggle", false)):
		return 1.0
	var dur := float(e.get("dur", 0.0))
	if dur <= 0.0:
		return 0.0
	return clampf(float(e.get("left", 0.0)) / dur, 0.0, 1.0)


## Подпись для касания по значку: «Сумрачный разрыв: Замедление — 7 с» / «Узы тени (Серохвост): включено».
static func describe(e: Dictionary) -> String:
	var src := String(e.get("src", ""))
	var nm := String(e.get("name", ""))
	var head := nm if src == "" or src == nm else "%s: %s" % [src, nm]
	if bool(e.get("toggle", false)):
		return head
	return "%s — %d с" % [head, ceili(float(e.get("left", 0.0)))]


## Название, источник, значок и баф/дебаф из info. true — значок или название сменились.
func _set_info(e: Dictionary, info: Dictionary) -> bool:
	var icon: Dictionary = info.get("icon", {})
	var old_icon: Dictionary = e.get("icon", {})
	var cnt := int(info.get("count", -1))
	var changed := String(e.get("name", "")) != String(info.get("name", "")) \
		or String(e.get("src", "")) != String(info.get("src", "")) or old_icon.hash() != icon.hash() \
		or int(e.get("count", -1)) != cnt
	e["count"] = cnt
	e["name"] = String(info.get("name", ""))
	e["src"] = String(info.get("src", ""))
	e["icon"] = icon
	e["debuff"] = bool(info.get("debuff", false))
	return changed
