extends BotSection
## Раздел «Торговля»: у каждого торгующего — Торговец Гордей (своя кнопка «Торговец»), Оружейник Бранд (пункт
## «Торговля» в диалоге), Бронница Хельга, Ювелир Лиора, Учитель Кирк — окно его лавки, товары есть, покупка
## (золото списано по цене, вещь в сумке), продажа ему же (золото по цене продажи, вещь ушла). Полный проход —
## ещё «Купить ×5» расходника у Гордея.

## [id NPC, как открыть лавку: "button" — кнопка HUD «Торговец», "dialog" — «Торговля» в диалоге, "" — сразу].
const TRADERS := [["merchant", "button"], ["weaponsmith", "dialog"], ["armorer", ""], ["jeweler", ""], ["kirk", "dialog"], ["rare_merchant", ""]]
const QUICK_TRADERS := ["merchant", "weaponsmith", "kirk"]


func id() -> String:
	return "trade"


func _build() -> void:
	do("Торговля: герой, золото", _setup)
	for e in TRADERS:
		var t: Array = e
		var who := String(t[0])
		if quick and not QUICK_TRADERS.has(who):
			continue
		var nm := NpcData.npc_name(who)
		do("%s: подойти, лавка" % nm, _open.bind(who, String(t[1])))
		wait(0.3)
		do("%s: купить и продать" % nm, _trade.bind(who))
	do("Торговля: конец", close_window)


func _setup() -> void:
	hero(Game.class_id, 20)
	fresh_bag(20000)


func _open(who: String, how: String) -> void:
	close_window()
	if not go_near(who):
		return
	match how:
		"button":
			press("shop")
		"dialog":
			npcs().talk_to(who)
			press_dialog("opt_trade")
		_:
			economy().open_shop(who)


func _trade(who: String) -> void:
	var eco := economy()
	var nm := NpcData.npc_name(who)
	if not check(eco.is_shop_open() and eco.window.seller == who, "%s: окно лавки открыто" % nm):
		return
	window_fits("Лавка: %s" % nm)
	var goods := InventoryWindow.goods(Game.class_id, who)
	if not check(not goods.is_empty(), "%s: товары есть (%d)" % [nm, goods.size()]):
		return
	shot("Lavka %s" % who)
	# Первый товар, который по карману
	var id := ""
	for g in goods:
		var gid := String(g)
		if int(ItemData.get_item(gid).get("buy", 0)) <= Game.gold and Game.inventory.room_for(gid) > 0:
			id = gid
			break
	if not check(id != "", "%s: есть что купить" % nm):
		return
	var price := int(ItemData.get_item(id).get("buy", 0))
	var gold0 := Game.gold
	var have0 := Game.inventory.count(id)
	check(eco.buy(id, 1, who) and Game.gold == gold0 - price and Game.inventory.count(id) == have0 + 1,
		"%s: куплено «%s» за %d зол. (%s)" % [nm, ItemData.item_name(id), price, last_msg()])
	# Продать купленное ему же (ближайший торгующий — он)
	var cell := Game.inventory.find_cell(id, true)
	var sell := int(ItemData.get_item(id).get("sell", 0))
	gold0 = Game.gold
	if sell > 0 and cell >= 0:
		check(eco.nearest_trader() == who, "%s: продажа уходит ему (ближайший — %s)" % [nm, eco.nearest_trader()])
		check(eco.sell_cell(cell, 1) == 1 and Game.gold == gold0 + sell and Game.inventory.count(id) == have0,
			"%s: продано «%s» за %d зол. (%s)" % [nm, ItemData.item_name(id), sell, last_msg()])
	if who == "merchant" and not quick:
		# «Купить ×5» расходника
		var pot := ItemData.potion_id("hp", 1)
		var p5 := int(ItemData.get_item(pot).get("buy", 0)) * 5
		gold0 = Game.gold
		var c0 := Game.inventory.count(pot)
		check(eco.buy(pot, 5, who) and Game.gold == gold0 - p5 and Game.inventory.count(pot) == c0 + 5,
			"%s: «Купить ×5» — %s за %d зол." % [nm, ItemData.item_name(pot), p5])
	close_window()
