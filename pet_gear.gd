class_name PetGear
extends RefCounted
## Снаряжение питомца (0.31, задача Максима; база оригинала: Creature Item Expert, Vital Unit, Fighter Unit, Unit Card).
## Две ячейки в окне существа: «Оружие» (любое оружие, кроме щита) и «Броня» (доспех на тело). Надеть — вещь из сумки
## запечатывается в «Карту снаряжения» (unit_card тратится, вещь уходит из сумки в запись питомца rec["gear"]),
## снять — «Мел восстановления» (restore_chalk тратится, вещь — обратно в сумку). Вещь — по уровню питомца (ранг:
## ItemData.required_level), любой вариант доспеха.
## Питомец получает долю характеристик вещи — «Знаток снаряжения» (80 / 90 / 100 % по виду) — и всю прибавку её заточки;
## с доспехом своего варианта — «Живучесть: доспех …» (макс. HP + доля), с оружием ближнего боя — «Боец: …» (атака +
## доля; у фазана — крит +5 с кинжалом). Без «Знатока снаряжения» надеть нельзя (умение 1-го уровня, 1 JP).

const SLOTS := ["weapon", "armor"]
const SLOT_NAMES := {"weapon": "Оружие", "armor": "Броня"}
const UNIT_CARD := "unit_card"
const CHALK := "restore_chalk"
## Оружие ближнего боя (для «Боец: ближний бой»).
const MELEE := ["sword_1h", "sword_2h", "dagger", "mace_1h", "mace_2h", "axe_1h", "axe_2h", "spear"]


## Надетое в ячейке slot записи rec ("" — пусто).
static func gear_in(rec: Dictionary, slot: String) -> String:
	var g: Variant = rec.get("gear", {})
	return String((g as Dictionary).get(slot, "")) if g is Dictionary else ""


## Ячейка, в которую встаёт вещь id ("" — питомцу не надеть).
static func slot_for(id: String) -> String:
	if ItemData.is_weapon(id) and not ItemData.is_shield(id) and not ItemData.is_broken(id):
		return "weapon"
	if ItemData.is_armor(id) and ItemData.gear_kind(id) == "body":
		return "armor"
	return ""


## Доля характеристик снаряжения («Знаток снаряжения»; 0 — умение не изучено).
static func expert(rec: Dictionary) -> float:
	var sp := String(rec.get("species", ""))
	var id := "item_expert_" + sp
	var n := PetSkills.skill_level(rec, id)
	return PetSkills.value(PetSkills.get_skill(id)["value"], n) if n > 0 else 0.0


## Почему вещь id нельзя надеть питомцу rec ("" — можно).
static func equip_block(rec: Dictionary, id: String) -> String:
	var slot := slot_for(id)
	if slot == "":
		return "Питомцу — только оружие (не щит) или доспех"
	if expert(rec) <= 0.0:
		return "Нужно умение «Знаток снаряжения»"
	var need := ItemData.required_level(id)
	if int(rec.get("level", 1)) < need:
		return "Питомцу нужен %d уровень" % need
	if not Game.inventory.has(id) or Enchant.free_count(id) <= 0:
		return "Этой вещи нет в сумке (надетое героем сначала снимите)"
	if not Game.inventory.has(UNIT_CARD):
		return "Нужна «Карта снаряжения» (Кирк, 500 зол.)"
	return ""


## Надеть вещь id питомцу rec (прежняя в той же ячейке — обратно в сумку без мела не снимается: сначала снять).
static func equip(rec: Dictionary, id: String) -> String:
	var err := equip_block(rec, id)
	var slot := slot_for(id)
	if err == "" and gear_in(rec, slot) != "":
		err = "Ячейка занята — сначала снимите (нужен Мел восстановления)"
	if err != "":
		return err
	Game.inventory.remove(UNIT_CARD)
	Game.inventory.remove(id)
	if not (rec.get("gear") is Dictionary):
		rec["gear"] = {}
	(rec["gear"] as Dictionary)[slot] = id
	Game.changed.emit()
	return ""


## Почему снять нельзя ("" — можно).
static func unequip_block(rec: Dictionary, slot: String) -> String:
	if gear_in(rec, slot) == "":
		return "Ячейка пуста"
	if not Game.inventory.has(CHALK):
		return "Нужен «Мел восстановления» (Кирк, 1000 зол.)"
	if Game.inventory.room_for(gear_in(rec, slot)) <= 0:
		return "Сумка полна"
	return ""


static func unequip(rec: Dictionary, slot: String) -> String:
	var err := unequip_block(rec, slot)
	if err != "":
		return err
	var id := gear_in(rec, slot)
	Game.inventory.remove(CHALK)
	(rec["gear"] as Dictionary).erase(slot)
	Game.inventory.add(id)
	Game.changed.emit()
	return ""


## Прибавки снаряжения к производным питомца r (PetStats.derived) по записи rec: атаки, защиты, HP, крит.
static func apply(rec: Dictionary, r: Dictionary) -> void:
	var k := expert(rec)
	var sp := String(rec.get("species", ""))
	var w := gear_in(rec, "weapon")
	var a := gear_in(rec, "armor")
	if k <= 0.0 or (w == "" and a == ""):
		return
	var add := {"patk": 0.0, "matk": 0.0, "def": 0.0, "mdef": 0.0}
	for id in [w, a]:
		if id == "":
			continue
		var it := ItemData.get_item(id)
		var base := ItemData.get_item(ItemData.base_id(id))
		for key in [["atk", "patk"], ["matk", "matk"], ["def", "def"], ["mdef", "mdef"]]:
			var v0 := float(base.get(key[0], 0))
			var v1 := float(it.get(key[0], 0))
			# Доля характеристик базовой вещи + вся прибавка заточки (база: «plus 100% of enhancement»)
			add[key[1]] = float(add[key[1]]) + v0 * k + (v1 - v0)
	r["patk"] = int(r.get("patk", 0)) + roundi(float(add["patk"]))
	r["matk"] = int(r.get("matk", 0)) + roundi(float(add["matk"]))
	r["def"] = int(r.get("def", 0)) + roundi(float(add["def"]))
	r["mdef"] = int(r.get("mdef", 0)) + roundi(float(add["mdef"]))
	# «Боец»: оружие ближнего боя — атака + доля; у фазана — крит с кинжалом
	var fu := "fighter_unit_" + sp
	var fn := PetSkills.skill_level(rec, fu)
	if w != "" and fn > 0:
		var fsk := PetSkills.get_skill(fu)
		var fv := PetSkills.value(fsk["value"], fn)
		var kind := ItemData.weapon_kind(w)
		if String(fsk.get("weapon", "")) == "dagger":
			if kind == "dagger":
				r["crit"] = snappedf(float(r.get("crit", 0.0)) + fv, 0.1)
		elif MELEE.has(kind):
			r["patk"] = roundi(float(r["patk"]) * (1.0 + fv))
	# «Живучесть»: доспех своего варианта — макс. HP + доля
	var vu := "vital_unit_" + sp
	var vn := PetSkills.skill_level(rec, vu)
	if a != "" and vn > 0 and ItemData.armor_variant(a) == String(PetSkills.get_skill(vu).get("armor", "")):
		r["max_hp"] = roundi(float(r.get("max_hp", 0)) * (1.0 + PetSkills.value(PetSkills.get_skill(vu)["value"], vn)))
	var magic := PetStats.is_magic(sp)
	r["atk"] = int(r["matk"]) if magic else int(r["patk"])


## Описание надетого одной строкой для окна существа: «Оружие: Меч +3 (физ. атака +26)».
static func slot_text(rec: Dictionary, slot: String) -> String:
	var id := gear_in(rec, slot)
	if id == "":
		return "%s: пусто" % String(SLOT_NAMES[slot])
	return "%s: %s" % [String(SLOT_NAMES[slot]), ItemData.item_name(id)]


# ---------- «Создание» (умения вида "manual": Creation базы) ----------

## Почему питомец rec не может сейчас применить умение-создание id (pet — призванный узел или null).
static func create_block(rec: Dictionary, id: String, pet: Node) -> String:
	var sk := PetSkills.get_skill(id)
	var n := PetSkills.skill_level(rec, id)
	if n <= 0 or String(sk.get("kind", "")) != "manual":
		return "Умение не изучено"
	if pet == null or not is_instance_valid(pet):
		return "Призовите питомца"
	var made: Dictionary = rec.get("made", {}) if rec.get("made") is Dictionary else {}
	var left := float(made.get(id, 0.0)) + float(sk.get("cd", 0.0)) - Time.get_unix_time_from_system()
	if left > 0.0:
		return "Снова можно через %s" % _time_text(left)
	if int(pet.get("mp")) < PetSkills.mp_cost(id, n):
		return "Не хватает MP (нужно %d)" % PetSkills.mp_cost(id, n)
	var need := String(sk.get("needs", ""))
	if need != "" and not Game.inventory.has(need):
		return "Нужен «%s» (Кирк)" % ItemData.item_name(need)
	var out := String(sk.get("creates", ""))
	if Game.inventory.room_for(out) <= 0:
		return "Сумка полна"
	return ""


## Применить: тратит MP питомца (и пустой флакон), кладёт созданное в сумку. Возвращает сообщение.
static func create(rec: Dictionary, id: String, pet: Node) -> String:
	var why := create_block(rec, id, pet)
	if why != "":
		return why
	var sk := PetSkills.get_skill(id)
	var n := PetSkills.skill_level(rec, id)
	pet.set("mp", int(pet.get("mp")) - PetSkills.mp_cost(id, n))
	var need := String(sk.get("needs", ""))
	if need != "":
		Game.inventory.remove(need)
	var out := String(sk.get("creates", ""))
	Game.inventory.add(out)
	if not (rec.get("made") is Dictionary):
		rec["made"] = {}
	(rec["made"] as Dictionary)[id] = Time.get_unix_time_from_system()
	Game.changed.emit()
	return "%s создал «%s»" % [String(rec.get("name", "Питомец")), ItemData.item_name(out)]


static func _time_text(sec: float) -> String:
	var m := ceili(sec / 60.0)
	if m >= 60:
		return "%d ч %d мин" % [m / 60, m % 60]
	return "%d мин" % m
