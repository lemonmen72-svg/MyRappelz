extends BotSection
## Раздел «Приручение»: карта фазана — у Учителя Кирка (окно торговли, покупка), на поле — фазан, «Приручить»
## (кнопка HUD) ставит метку, герой побеждает зверя обычными атаками — успех подставлен (Taming.force_roll = 0):
## пустая карта стала картой с душой; формирование (как в карточке карты) — существо 1-го уровня в коллекции,
## призвано. Полный проход — ещё неудача с зеркальной картой в сумке: ломается зеркальная, карта вида цела.

const SPECIES := "pheasant"
const MOB_LEVEL := 3
## Бить зверя не дольше, с; потом — добить (как «Убить цель» админ-панели).
const FIGHT := 12.0

var _mob: Mob = null
var _pets0 := 0
var _attempts0 := 0
var _fight_t := 0.0


func id() -> String:
	return "taming"


func _build() -> void:
	var card := ItemData.card_for(SPECIES)
	do("Приручение: герой, сумка, питомцы", _setup)
	do("Карта у Учителя Кирка", _buy_card.bind(card))
	wait(0.3)
	do("Приручение: на поле, метка", _mark.bind(card))
	until("зверь с меткой побеждён", _won, FIGHT + 3.0)
	until("душа поймана в карту", _soul_caught, 3.0)
	do("Формирование и призыв", _form)
	until("сформированное существо призвано", _formed_summoned, 4.0)
	do("Приручение: снимок", func() -> void: shot("Priruchenie fazan"))
	if not quick:
		do("Неудача с зеркальной картой", _fail_mark.bind(card))
		until("зверь с меткой побеждён (неудача)", _won, FIGHT + 3.0)
		do("Неудача: сломалась зеркальная карта", _fail_check.bind(card))
	do("Приручение: конец", _end)


func _setup() -> void:
	hero(Game.class_id, 20)
	fresh_bag(1000)
	no_pets()


## Карта вида — у Учителя Кирка: окно его лавки, покупка (золото списано, карта в сумке).
func _buy_card(card: String) -> void:
	if not go_near("kirk"):
		return
	var eco := economy()
	eco.open_shop("kirk")
	check(eco.is_shop_open(), "окно лавки Учителя Кирка")
	var gold0 := Game.gold
	var price := int(ItemData.get_item(card).get("buy", 0))
	var ok := eco.buy(card, 1, "kirk")
	check(ok and Game.inventory.has(card) and Game.gold == gold0 - price, "куплена «%s» за %d зол. (%s)"
		% [ItemData.item_name(card), price, last_msg()])
	close_window()


## На поле: фазан, цель героя, «Приручить» — метка; бой, успех подставлен.
func _mark(card: String) -> void:
	if not Game.inventory.has(card):
		Game.inventory.add(card, 1)
	to_arena()
	_mob = spawn_ahead(SPECIES, MOB_LEVEL, 4.0)
	var p := player()
	if _mob == null or p == null:
		check(false, "зверь для приручения поставлен")
		return
	p.select_target(_mob)
	var tm := bot.main.get("taming") as Taming
	tm.cooldown = 0.0
	tm.force_roll = 0.0
	_attempts0 = tm.attempts
	press("tame")
	check(tm.marked == _mob and _mob.tame_marked, "«Приручить»: метка на звере (%s)" % last_msg())
	bot.tick(_fight)


func _fight(dt: float) -> void:
	var p := player()
	if p == null or not alive(_mob):
		return
	_fight_t += dt
	if p.current_target != _mob:
		p.select_target(_mob)
	if _fight_t > FIGHT:
		kill(_mob)
		return
	# Подойти вплотную и бить (как удержание «Атаки»)
	var d := _mob.global_position - p.global_position
	d.y = 0.0
	if d.length() > p.attack_range * 0.8:
		p.global_position = ground(_mob.global_position.x - d.normalized().x * 1.5, _mob.global_position.z - d.normalized().z * 1.5)
	p.try_attack()


func _won() -> bool:
	if not alive(_mob):
		bot.tick(Callable())
		_fight_t = 0.0
		return true
	return false


func _soul_caught() -> bool:
	return Game.inventory.has(ItemData.soul_card_for(SPECIES))


func _formed_summoned() -> bool:
	var pt := pet()
	return pt != null and pt.species == SPECIES


func _form() -> void:
	var soul := ItemData.soul_card_for(SPECIES)
	var tm := bot.main.get("taming") as Taming
	check(tm.attempts == _attempts0 + 1, "попытка приручения засчитана")
	if not check(Game.inventory.has(soul), "карта с душой в сумке"):
		return
	_pets0 = Game.pets.size()
	check(tm.form(soul), "сформировано существо (%s)" % last_msg())
	check(Game.pets.size() == _pets0 + 1 and not Game.inventory.has(soul), "существо в коллекции, карта с душой ушла")
	if pet() == null and not Game.pets.is_empty():
		pets().summon(Game.pets.size() - 1)


## Неудача (force_roll 0.99) с зеркальной картой: ломается зеркальная, карта вида остаётся.
func _fail_mark(card: String) -> void:
	no_pets()
	if not Game.inventory.has(card):
		Game.inventory.add(card, 1)
	Game.inventory.add(ItemData.MIRROR_CARD, 1)
	_mob = spawn_ahead(SPECIES, MOB_LEVEL, 4.0)
	var p := player()
	if _mob == null or p == null:
		return
	p.select_target(_mob)
	var tm := bot.main.get("taming") as Taming
	tm.cooldown = 0.0
	tm.force_roll = 0.99
	press("tame")
	check(tm.marked == _mob, "метка на втором звере")
	bot.tick(_fight)


func _fail_check(card: String) -> void:
	check(not Game.inventory.has(ItemData.MIRROR_CARD) and Game.inventory.has(card)
		and not Game.inventory.has(ItemData.soul_card_for(SPECIES)), "неудача: зеркальная карта сломалась, карта вида цела")


func _end() -> void:
	bot.tick(Callable())
	var tm := bot.main.get("taming") as Taming
	if tm != null:
		tm.force_roll = -1.0
	bot.clear_spawned()
