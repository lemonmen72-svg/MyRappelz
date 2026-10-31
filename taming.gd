class_name Taming
extends Node
## Приручение по системе карт существ. У каждого вида своя карта (ItemData: пустая card_<вид>, с душой
## card_<вид>_soul). С пустой картой вида в сумке умение «Приручить» ставит метку на зверя, затем зверя нужно
## победить (кому угодно). При смерти помеченного зверя бросается шанс по тиру карты (CHANCE): успех — пустая
## карта становится картой с душой; неудача — карта существа ломается, но если в сумке есть зеркальная карта,
## ломается она, а карта существа остаётся. Формирование (form): карта с душой расходуется, в коллекции
## Game.pets появляется существо 1-го уровня (если в коллекции есть место).
## Метка одна, держится 30 с или пока зверь жив и не ушёл домой. Перезарядка умения 3 с.
## Не всех зверей можно приручить (MobData.tameable: кабан и каменный страж — нельзя, карт у них нет).
## Описание карты для карточки предмета (где водится вид, уровни, тир, где взять) — card_lines.

## Дальность умения, м.
const RANGE := 8.0
const MARK_TIME := 30.0
const COOLDOWN := 3.0
## Шанс успеха по тиру карты (ItemData.CARD_TIERS): базовая проще, уникальная сложнее.
const CHANCE := {"basic": 0.7, "rare": 0.45, "special": 0.35, "unique": 0.25}
## Состояния значка приручения на панели цели (badge_state).
const BADGE_READY := "ready"
const BADGE_NEED_CARD := "need_card"
const BADGE_NO := "no"

var main: Node
## Помеченный зверь или null.
var marked: Mob = null
## Сколько секунд ещё держится метка.
var mark_left := 0.0
## Перезарядка умения, с.
var cooldown := 0.0
## Сколько попыток приручения состоялось (зверь с меткой побеждён и карта была в сумке).
var attempts := 0
## Тесты: >= 0 — вместо случайного числа (0 — точно успех, 0.99 — точно неудача).
var force_roll := -1.0

var _rng := RandomNumberGenerator.new()

## Зоны острова из конфига (кэш для описаний карт): [{"name", "levels": [мин., макс.], "mobs": [id]}].
static var _zones: Array = []
static var _zones_loaded := false


func setup(m: Node) -> void:
	main = m
	_rng.randomize()


## Обрабатывает действие "tame". true, если действие своё.
func handle_action(id: String) -> bool:
	if id == "tame":
		try_tame()
		return true
	return false


## Ставит метку приручения на цель игрока (или ближайшего зверя). true, если метка поставлена.
## Нужна пустая карта существа этого вида в сумке.
func try_tame() -> bool:
	if cooldown > 0.0:
		_msg("«Приручить» перезаряжается: %.1f с" % cooldown)
		return false
	var mob := _pick_target()
	if mob == null:
		_msg("Рядом нет зверя для приручения (до %d м)" % int(RANGE))
		return false
	var card := ItemData.card_for(mob.type_id)
	if not MobData.tameable(mob.type_id) or card == "":
		_msg("Этого зверя нельзя приручить: «%s»" % mob.mob_name)
		return false
	if not Game.inventory.has(card):
		_msg("Нужна карта существа: %s — %s" % [String(MobData.get_type(mob.type_id)["name"]), where_to_get(card)])
		return false
	if is_instance_valid(marked) and marked != mob:
		marked.set_tame_mark(false)
	marked = mob
	mark_left = MARK_TIME
	cooldown = COOLDOWN
	mob.set_tame_mark(true)
	_msg("Метка на звере «%s». Победите его! (%s, шанс %d%%)" % [mob.mob_name, ItemData.item_name(card),
		roundi(chance_for(ItemData.card_tier(card)) * 100.0)])
	return true


## Зверь убит: если на нём была метка приручения, решаем исход.
func on_mob_killed(mob: Mob) -> void:
	if mob == null or not is_instance_valid(marked) or mob != marked:
		return
	_clear_mark()
	var pos := mob.global_position
	var card := ItemData.card_for(mob.type_id)
	if card == "" or not Game.inventory.has(card):
		_msg("Карты существа нет в сумке — приручение сорвалось")
		return
	attempts += 1
	var roll := force_roll if force_roll >= 0.0 else _rng.randf()
	if roll < chance_for(ItemData.card_tier(card)):
		var soul := ItemData.soul_card_for(mob.type_id)
		Game.inventory.replace_one(card, soul)
		Util.float_text(main, pos + Vector3(0, 3.0, 0), "Душа поймана!", Color(0.5, 1.0, 0.7), 1.4)
		Vfx.tame_success(main, pos, clampf(mob.body_scale, 0.8, 1.6))
		_msg("Душа %s поймана в карту. Сформируйте существо (окно «Питомцы» или карта в сумке)"
			% MobData.name_gen(mob.type_id))
	elif Game.inventory.has(ItemData.MIRROR_CARD):
		Game.inventory.remove(ItemData.MIRROR_CARD)
		Util.float_text(main, pos + Vector3(0, 3.0, 0), "Зеркальная карта сломалась", Color(0.8, 0.88, 1.0))
		_msg("Зеркальная карта сломалась, карта существа цела: зверь «%s» не приручен" % mob.mob_name)
	else:
		Game.inventory.remove(card)
		Util.float_text(main, pos + Vector3(0, 3.0, 0), "Карта сломалась", Color(1.0, 0.5, 0.4))
		_msg("Карта существа сломалась: зверь «%s» не приручен" % mob.mob_name)


## Формирование: из карты с душой card_id в сумке — существо 1-го уровня в коллекции. true — сформировано.
## Если никто не призван, новое существо сразу выходит к хозяину.
func form(card_id: String) -> bool:
	if not ItemData.is_soul_card(card_id) or not Game.inventory.has(card_id):
		_msg("Нет карты с душой для формирования")
		return false
	if Game.pets.size() >= Game.MAX_PETS:
		_msg("Коллекция полна (%d). Отпустите кого-нибудь в окне «Питомцы»" % Game.MAX_PETS)
		return false
	var sp := ItemData.card_species(card_id)
	Game.inventory.remove(card_id)
	var pet_name := PetData.stage_name(sp, 1)
	var idx: int = Game.add_pet(sp, pet_name, 1)
	if main != null and main.get("player") != null and is_instance_valid(main.player):
		var pos: Vector3 = main.player.global_position
		Vfx.tame_success(main, pos, 1.0)
	if idx >= 0 and Game.active_pet == -1 and main != null and main.get("pets") != null:
		main.pets.summon(idx)
	_msg("Сформировано существо: «%s» (%s)!" % [pet_name, PetData.role_name(sp)])
	return true


## Шанс успеха для тира карты.
func chance_for(tier: String) -> float:
	return float(CHANCE.get(tier, 0.5))


## Значок приручения для зверя вида type_id: BADGE_READY — можно приручить, нужная карта в сумке;
## BADGE_NEED_CARD — можно приручить, карты нет; BADGE_NO — нельзя приручить.
static func badge_state(type_id: String) -> String:
	var card := ItemData.card_for(type_id)
	if not MobData.tameable(type_id) or card == "":
		return BADGE_NO
	return BADGE_READY if Game.inventory.has(card) else BADGE_NEED_CARD


## Где взять карту: «продаётся у торговца» или «выпадает из волка» (по добыче MobData).
static func where_to_get(card_id: String) -> String:
	if int(ItemData.get_item(card_id).get("buy", 0)) > 0:
		return "продаётся у торговца"
	var from: Array = []
	for k in MobData.TYPES:
		for e in MobData.get_type(String(k)).get("loot", []):
			var entry: Array = e
			if String(entry[0]) == card_id:
				from.append(MobData.name_gen(String(k)))
	if from.is_empty():
		return "пока не добыть"
	return "выпадает из " + ", ".join(PackedStringArray(from))


## Где водится вид: «Луга новичков (ур. 1–2), Южные поля (ур. 2–3)» по mob_zones конфига острова.
static func habitat_text(species: String) -> String:
	var parts: Array = []
	for z in zones():
		var zone: Dictionary = z
		if (zone["mobs"] as Array).has(species):
			var lv: Array = zone["levels"]
			var lt := "ур. %d" % int(lv[0]) if int(lv[0]) == int(lv[1]) else "ур. %d–%d" % [int(lv[0]), int(lv[1])]
			parts.append("%s (%s)" % [String(zone["name"]), lt])
	return ", ".join(PackedStringArray(parts))


## Зоны зверей острова: [{"name": String, "levels": [мин., макс.], "mobs": [id вида]}].
static func zones() -> Array:
	if _zones_loaded:
		return _zones
	_zones_loaded = true
	_zones = []
	var cfg: Variant = null
	if IslandWorld.current != null:
		cfg = IslandWorld.current.cfg
	else:
		cfg = JSON.parse_string(FileAccess.get_file_as_string(IslandWorld.CONFIG_PATH))
	if not (cfg is Dictionary):
		return _zones
	for z in (cfg as Dictionary).get("mob_zones", []):
		if not (z is Dictionary):
			continue
		var zone: Dictionary = z
		var lv: Array = zone.get("levels", [1, 1])
		var mobs: Array = []
		for m in zone.get("mobs", []):
			mobs.append(String((m as Array)[0]))
		_zones.append({"name": String(zone.get("name", "")), "levels": [int(lv[0]), int(lv[1])], "mobs": mobs})
	return _zones


## Строки описания карты для карточки предмета: вид и роль, где водится, тир и шанс, где взять, что делать.
static func card_lines(card_id: String) -> Array:
	var res: Array = []
	if not ItemData.is_card(card_id):
		return res
	var sp := ItemData.card_species(card_id)
	if sp == "":
		res.append("Нужна в сумке во время приручения. При неудаче ломается одна зеркальная карта вместо карты существа.")
		res.append("Где взять: " + where_to_get(card_id))
		return res
	var d := MobData.get_type(sp)
	var tier := ItemData.card_tier(card_id)
	res.append("Существо: %s (%s)" % [String(d["name"]), PetData.role_name(sp)])
	var hab := habitat_text(sp)
	if hab != "":
		res.append("Водится: " + hab)
	res.append("Карта: %s · шанс приручения %d%%" % [ItemData.card_tier_label(tier),
		roundi(float(CHANCE.get(tier, 0.5)) * 100.0)])
	if ItemData.is_soul_card(card_id):
		res.append("Сформируйте существо в окне «Питомцы» или кнопкой «Сформировать». Появится «%s», ур. 1."
			% PetData.stage_name(sp, 1))
	else:
		res.append("Где взять: " + where_to_get(card_id))
		res.append("Примените «Приручить» к зверю, затем победите его. Неудача ломает карту, если в сумке нет зеркальной карты.")
	return res


func _pick_target() -> Mob:
	var pl: Node3D = main.player
	var ct = main.player.current_target
	if is_instance_valid(ct) and ct is Mob and not ct.is_dead:
		if pl.global_position.distance_to(ct.global_position) <= RANGE:
			return ct as Mob
	return Util.nearest(pl, "mobs", RANGE) as Mob


func _clear_mark() -> void:
	if is_instance_valid(marked):
		marked.set_tame_mark(false)
	marked = null
	mark_left = 0.0


func _msg(t: String) -> void:
	main.hud.show_message(t)


func _process(delta: float) -> void:
	if main == null or main.get("hud") == null:
		return
	if cooldown > 0.0:
		cooldown = maxf(0.0, cooldown - delta)
	main.hud.set_cooldown("tame", cooldown / COOLDOWN)

	if not is_instance_valid(marked):
		marked = null
		return
	if marked.is_dead:
		_clear_mark()
		return
	mark_left -= delta
	if marked.returning:
		_clear_mark()
		_msg("Зверь ушёл домой — метка приручения снята")
	elif mark_left <= 0.0:
		_clear_mark()
		_msg("Метка приручения рассеялась")
