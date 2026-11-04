class_name PetBelt
extends RefCounted
## Пояс героя с картами существ (0.31, задача Максима; база оригинала: Card Ability, Belt Slot, StringResource
## ui_beltslot_1…6). Отозванного питомца, у которого изучена хотя бы одна «Способность карты», можно вставить в ячейку
## пояса (окно «Питомцы», блок «Пояс»): пока он там, его нельзя призвать, а герой получает бонусы его «Способностей
## карты»: доля своей характеристики (Сила, Выносливость, Меткость, Ловкость …) — от базовой характеристики героя, или
## доля атаки, защиты, точности, избегания. Пояс должен быть надет (ячейка «Пояс» экипировки).
## Ячеек — Game.belt_slots (1 у нового героя, до MAX_SLOTS — «Расширитель пояса»: шанс EXPAND_CHANCE по числу ячеек,
## неудача — снова 1 ячейка, как в подсказке базы; в этой версии базы самого предмета нет — шансы наши).
## Ограничения ячеек (база): 3-я — питомец 2-й формы и старше, 4-я — 3-й формы; остальные — любой.
## Предел (база, ui_beltslot_1): бонус к одной характеристике — не больше 30 % + 1 % за каждую карту, что её даёт.
## Где питомец: запись rec["belt"] — номер ячейки (0…), нет поля — не в поясе.

const MAX_SLOTS := 6
## Шанс расширения: из N ячеек в N + 1 (индекс — N − 1).
const EXPAND_CHANCE := [1.0, 0.8, 0.6, 0.4, 0.25]
## Ячейка → нужная стадия питомца (0 — 1-я форма).
const SLOT_STAGE := {2: 1, 3: 2}
const CAP_BASE := 0.30
const CAP_PER_CARD := 0.01
const ITEM := "belt_expander"


## Надет ли пояс (без него ячейки не работают).
static func belt_worn() -> bool:
	return Game.gear_in("belt") != ""


## Индекс питомца в ячейке slot (-1 — пусто).
static func pet_in(slot: int) -> int:
	for i in Game.pets.size():
		if int(Game.pets[i].get("belt", -1)) == slot:
			return i
	return -1


static func in_belt(rec: Dictionary) -> bool:
	return int(rec.get("belt", -1)) >= 0


## «Способности карты» питомца: [[ключ ("str", "atk" …), доля], …] — только изученные.
static func abilities(rec: Dictionary) -> Array:
	var res: Array = []
	var sp := String(rec.get("species", ""))
	for k in [1, 2]:
		var id := "card_%s_%d" % [sp, k]
		var n := PetSkills.skill_level(rec, id)
		if n > 0:
			var sk := PetSkills.get_skill(id)
			res.append([String(sk.get("card", "")), PetSkills.value(sk["value"], n)])
	return res


## Почему питомца i нельзя вставить в ячейку slot ("" — можно).
static func put_block(i: int, slot: int) -> String:
	if i < 0 or i >= Game.pets.size():
		return "Нет питомца"
	var rec: Dictionary = Game.pets[i]
	if slot < 0 or slot >= Game.belt_slots:
		return "Ячейка закрыта — нужен «Расширитель пояса»"
	if abilities(rec).is_empty():
		return "Нужна изученная «Способность карты» (с 40 ур. питомца)"
	if bool(rec.get("dead", false)):
		return "Погибшего питомца в пояс не вставить"
	var need := int(SLOT_STAGE.get(slot, 0))
	if PetData.stage_of(rec) < need:
		return "В эту ячейку — питомец %d-й формы и старше" % (need + 1)
	var other := pet_in(slot)
	if other >= 0 and other != i:
		return "Ячейка занята"
	return ""


## Вставить питомца i в ячейку slot (призванный — отзывается: pet_manager). "" — удалось.
static func put(i: int, slot: int, pet_manager: Node = null) -> String:
	var err := put_block(i, slot)
	if err != "":
		return err
	if Game.active_pet == i and pet_manager != null and pet_manager.has_method("recall"):
		pet_manager.call("recall")
	if Game.active_pet == i:
		Game.active_pet = -1
	Game.pets[i]["belt"] = slot
	Game.changed.emit()
	return ""


static func take(i: int) -> void:
	if i >= 0 and i < Game.pets.size():
		Game.pets[i].erase("belt")
		Game.changed.emit()


## Убрать из пояса тех, кто там быть не может (ячейка закрылась, умения сброшены, ячейка занята дважды).
static func ensure() -> void:
	var used: Dictionary = {}
	for rec in Game.pets:
		var s := int(rec.get("belt", -1))
		if s < 0:
			continue
		if s >= Game.belt_slots or used.has(s) or abilities(rec).is_empty() or PetData.stage_of(rec) < int(SLOT_STAGE.get(s, 0)):
			rec.erase("belt")
		else:
			used[s] = true


## Бонусы героя от карт в поясе: характеристики — числа (от базовой характеристики героя класса cls уровня lvl),
## "atk_pct", "def_pct", "acc_pct", "avoid_pct" — доли. Предел на ключ — CAP_BASE + CAP_PER_CARD × карт с ним.
static func hero_bonus(cls: String, lvl: int) -> Dictionary:
	var res: Dictionary = {}
	if not belt_worn():
		return res
	var pct: Dictionary = {}
	var cards: Dictionary = {}
	for rec in Game.pets:
		if not in_belt(rec) or int(rec["belt"]) >= Game.belt_slots:
			continue
		for a in abilities(rec):
			var k := String(a[0])
			pct[k] = float(pct.get(k, 0.0)) + float(a[1])
			cards[k] = int(cards.get(k, 0)) + 1
	if pct.is_empty():
		return res
	var base: Dictionary = HeroStats.base_stats(cls, lvl) if HeroStats.has_stats(cls) else {}
	for k in pct:
		var p := minf(float(pct[k]), CAP_BASE + CAP_PER_CARD * float(cards[k]))
		if Stats.STATS.has(k):
			res[k] = roundf(float(base.get(k, 0)) * p)
		else:
			res[k + "_pct"] = p
	return res


## Бонусы одной строкой («Сила +3, атака +5 %»; "" — нет).
static func bonus_text(b: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k in b:
		var key := String(k)
		if key.ends_with("_pct"):
			parts.append("%s +%d%%" % [String(PetSkills.CARD_NAMES.get(key.trim_suffix("_pct"), key)), roundi(float(b[k]) * 100.0)])
		else:
			parts.append("%s +%d" % [String(PetSkills.CARD_NAMES.get(key, key)), roundi(float(b[k]))])
	return ", ".join(parts)


## Шанс расширить пояс из n ячеек.
static func expand_chance(n: int) -> float:
	if n < 1 or n >= MAX_SLOTS:
		return 0.0
	return float(EXPAND_CHANCE[n - 1])


static func expand_block() -> String:
	if Game.belt_slots >= MAX_SLOTS:
		return "У пояса уже %d ячеек" % MAX_SLOTS
	if not Game.inventory.has(ITEM):
		return "Нужен «Расширитель пояса» (Торговец наград)"
	return ""


## Расширить пояс (тратит предмет): {"ok", "text", "error"}. rng — тесты.
static func expand(rng: RandomNumberGenerator = null) -> Dictionary:
	var err := expand_block()
	if err != "":
		return {"ok": false, "text": err, "error": err}
	Game.inventory.remove(ITEM)
	var ch := expand_chance(Game.belt_slots)
	var roll := rng.randf() if rng != null else Combat.rand()
	if roll < ch:
		Game.belt_slots += 1
		Game.changed.emit()
		return {"ok": true, "text": "Пояс расширен: ячеек %d" % Game.belt_slots, "error": ""}
	Game.belt_slots = 1
	ensure()
	Game.changed.emit()
	return {"ok": false, "text": "Расширить не удалось — у пояса снова одна ячейка", "error": ""}
