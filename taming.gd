class_name Taming
extends Node
## Приручение: умение «Приручить» ставит метку на зверя (нужен подходящий кристалл души в сумке),
## затем зверя нужно добить (кому угодно). При смерти помеченного зверя тратится кристалл
## и бросается шанс по редкости: успех — новый питомец в Game.pets, неудача — кристалл треснул.
## Метка одна, держится 30 с или пока зверь жив и не ушёл домой. Перезарядка умения 3 с.

## Дальность умения, м.
const RANGE := 8.0
const MARK_TIME := 30.0
const COOLDOWN := 3.0
## Шанс успеха по редкости зверя.
const CHANCE := {"common": 0.7, "rare": 0.45, "unique": 0.25}

var main: Node
## Помеченный зверь или null.
var marked: Mob = null
## Сколько секунд ещё держится метка.
var mark_left := 0.0
## Перезарядка умения, с.
var cooldown := 0.0
## Сколько кристаллов потрачено на попытки (для тестов и статистики).
var crystals_used := 0

var _rng := RandomNumberGenerator.new()


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
func try_tame() -> bool:
	if cooldown > 0.0:
		_msg("«Приручить» перезаряжается: %.1f с" % cooldown)
		return false
	if Game.pets.size() >= Game.MAX_PETS:
		_msg("Коллекция питомцев полна (%d). Отпустите кого-нибудь в окне «Питомцы»" % Game.MAX_PETS)
		return false
	var mob := _pick_target()
	if mob == null:
		_msg("Рядом нет зверя для приручения (до %d м)" % int(RANGE))
		return false
	var crystal := pick_crystal(mob.type_id)
	if crystal == "":
		_msg("Для зверя «%s» нужен: %s" % [mob.mob_name, ItemData.item_name(needed_crystal(mob.type_id))])
		return false
	if is_instance_valid(marked) and marked != mob:
		marked.set_tame_mark(false)
	marked = mob
	mark_left = MARK_TIME
	cooldown = COOLDOWN
	mob.set_tame_mark(true)
	_msg("Метка на звере «%s». Добейте его! (%s)" % [mob.mob_name, ItemData.item_name(crystal)])
	return true


## Зверь убит: если на нём была метка приручения, решаем исход.
func on_mob_killed(mob: Mob) -> void:
	if mob == null or not is_instance_valid(marked) or mob != marked:
		return
	_clear_mark()
	var pos := mob.global_position
	if Game.pets.size() >= Game.MAX_PETS:
		_msg("Коллекция питомцев полна — приручение не удалось")
		return
	var crystal := pick_crystal(mob.type_id)
	if crystal == "":
		_msg("Нет подходящего кристалла — приручение сорвалось")
		return
	Game.inventory.remove(crystal)
	crystals_used += 1
	if _rng.randf() < chance_for(mob.rarity):
		var pet_name := PetData.stage_name(mob.type_id, 1)
		var idx: int = Game.add_pet(mob.type_id, pet_name, 1)
		Util.float_text(main, pos + Vector3(0, 3.0, 0), "Приручено!", Color(0.5, 1.0, 0.7), 1.4)
		Vfx.tame_success(main, pos, clampf(mob.body_scale, 0.8, 1.6))
		# Если никто не призван, новый питомец сразу выходит к хозяину
		if idx >= 0 and Game.active_pet == -1 and main.get("pets") != null:
			main.pets.summon(idx)
		_msg("Приручен новый питомец: «%s» (%s)!" % [pet_name, PetData.role_name(mob.type_id)])
	else:
		Util.float_text(main, pos + Vector3(0, 3.0, 0), "Кристалл треснул", Color(1.0, 0.5, 0.4))
		_msg("Кристалл треснул: зверь «%s» не приручен" % mob.mob_name)


## Шанс успеха для редкости зверя.
func chance_for(rarity: String) -> float:
	return float(CHANCE.get(rarity, 0.5))


## Самый дешёвый кристалл из сумки, подходящий для зверя ("" — нет подходящего).
func pick_crystal(type_id: String) -> String:
	return _cheapest_crystal(MobData.rarity_tier(type_id), true)


## Самый дешёвый кристалл, подходящий для зверя (для подсказки, есть ли он в сумке — неважно).
func needed_crystal(type_id: String) -> String:
	return _cheapest_crystal(MobData.rarity_tier(type_id), false)


func _cheapest_crystal(need: int, in_bag: bool) -> String:
	var best := ""
	var best_key := INF
	for k in ItemData.ITEMS:
		var id := String(k)
		var it: Dictionary = ItemData.ITEMS[k]
		if String(it.get("type", "")) != "crystal":
			continue
		var tier := int(it.get("tier", 0))
		if tier < need:
			continue
		if in_bag and not Game.inventory.has(id):
			continue
		var key := float(tier) * 100000.0 + float(it.get("sell", 0))
		if key < best_key:
			best_key = key
			best = id
	return best


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
