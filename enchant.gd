class_name Enchant
extends RefCounted
## Чарование кубами и закалка у кузнеца (этап 3, задачи Максима 26–31). Заточка «+N» — у конкретной вещи: свой id
## «<id>+N» (ItemData, раздел «Чарование, закалка, кубы»), сломанная — «<id>!broken» (лом). Чарование и закалка —
## одна шкала «+N».
##
## Чарование кубом (инструмент «Крафт» в сумке — InventoryWindow): вещь + куб своего вида (куб атаки — оружие, куб
## защиты — броня и щит) ранга не ниже ранга вещи (ItemData.CUBE_KINDS). Куб тратится в любом случае. Успех —
## заточка +1, неудача — вещь ломается (заточка теряется, лом продаётся торговцу за малую цену, надеть нельзя).
## Шанс — по уровню, который получится (CHANCES; «+N при текущем +(N−1)»):
##   +1…+4   — 50 %      (переход +0→+1 … +3→+4)
##   +5…+10  — 25 %      (+4→+5 … +9→+10)
##   +11…+15 — 12.5 %    (+10→+11 … +14→+15)
##   +16…+20 — 6.25 %    (+15→+16 … +19→+20)
## Предел кубами (cube_cap): оружие 1-го ранга — +10, 2-го ранга и выше — +20; броня и щит — +10 при любом ранге.
##
## Закалка у Кузнеца Гуннара (пункт «Закалка» в его диалоге, окно — InventoryWindow "forge"): любая вещь, которая
## точится (оружие, броня, щит), до +10 (SMITH_MAX), всегда успешно, за золото. Цена следующего уровня
## (temper_price) растёт геометрически от цены до +1 к цене до +10 по рангу вещи (TEMPER_PRICES):
##   1-й ранг: 300, 440, 650, 970, 1 400, 2 100, 3 100, 4 600, 6 800, 10 000 (всего ≈ 30 000);
##   2-й ранг: 20 000, 24 000, 29 000, 34 000, 41 000, 49 000, 58 000, 70 000, 84 000, 100 000;
##   3-й ранг: 100 000, 130 000, 170 000, 220 000, 280 000, 360 000, 460 000, 600 000, 770 000, 1 000 000;
##   старше — ×10 за ранг.
## Дальше +10 — только кубы (оружие 2-го ранга и выше — до +20).
##
## Где лежит вещь (where): "" — свободная штука в ячейках сумки, "weapon" / "offhand" / ячейка брони
## (ItemData.GEAR_SLOTS) — надетая. Заточенная надетая вещь остаётся надетой (новый id в Game.weapon / offhand /
## equip), сломанная — снимается. После изменения надетого — Player.refresh_equipment (характеристики, модель).

## Шанс чарования кубом: [до какого «+N» (получится) включительно, шанс].
const CHANCES := [[4, 0.5], [10, 0.25], [15, 0.125], [20, 0.0625]]
## Пределы чарования кубами: броня и щит — ARMOR_MAX; оружие 1-го ранга — WEAPON_MAX_R1, 2-го и выше — WEAPON_MAX.
const ARMOR_MAX := 10
const WEAPON_MAX_R1 := 10
const WEAPON_MAX := 20
## Закалка у кузнеца: до SMITH_MAX, 100 %.
const SMITH_MAX := 10
const SMITH_NPC := "smith"
## Цена закалки по рангу вещи: [до +1, до +10]; между — геометрически, округление до 2 значащих цифр.
const TEMPER_PRICES := {1: [300, 10000], 2: [20000, 100000], 3: [100000, 1000000]}


## Шанс получить заточку target (из target − 1) кубом.
static func chance_for(target: int) -> float:
	for e in CHANCES:
		if target <= int(e[0]):
			return float(e[1])
	return 0.0


## Шанс следующего уровня заточки вещи id кубом.
static func chance(id: String) -> float:
	return chance_for(ItemData.enchant_level(id) + 1)


## Предел чарования кубами у вещи id (0 — не точится).
static func cube_cap(id: String) -> int:
	match ItemData.enchant_kind(id):
		"defense":
			return ARMOR_MAX
		"attack":
			return WEAPON_MAX_R1 if ItemData.rank(id) <= 1 else WEAPON_MAX
	return 0


## Почему вещь item нельзя чаровать кубом cube ("" — можно; cube "" — проверка только вещи).
static func cube_block(item: String, cube: String = "") -> String:
	if item == "":
		return "Положите вещь"
	if ItemData.is_broken(item):
		return "Сломанную вещь не чаруют"
	var kind := ItemData.enchant_kind(item)
	if kind == "":
		return "Это не чаруется: только оружие, броня и щит"
	var n := ItemData.enchant_level(item)
	var cap := cube_cap(item)
	if n >= cap:
		if ItemData.enchant_kind(item) == "defense":
			return "Заточка +%d — предел брони и щита" % cap
		return "Заточка +%d — предел для оружия %d-го ранга" % [cap, ItemData.rank(item)]
	if cube == "":
		return ""
	if not ItemData.is_cube(cube):
		return "Положите куб"
	if ItemData.cube_kind(cube) != kind:
		return "Нужен %s" % ("куб атаки (для оружия)" if kind == "attack" else "куб защиты (для брони и щита)")
	if ItemData.rank(cube) < ItemData.rank(item):
		return "Нужен куб %d-го ранга или старше" % ItemData.rank(item)
	if not Game.inventory.has(cube):
		return "Куба нет в сумке"
	return ""


## Цена закалки вещи ранга rank_n до заточки target (1…SMITH_MAX).
static func temper_price_at(rank_n: int, target: int) -> int:
	var r := clampi(rank_n, 1, 3)
	var p: Array = TEMPER_PRICES[r]
	var t := clampi(target, 1, SMITH_MAX)
	var lo := float(p[0])
	var hi := float(p[1])
	var v := lo * pow(hi / lo, float(t - 1) / float(SMITH_MAX - 1))
	v *= pow(10.0, float(maxi(0, rank_n - 3)))
	return _round2(v)


## Цена закалки вещи id до следующего уровня.
static func temper_price(id: String) -> int:
	return temper_price_at(ItemData.rank(id), ItemData.enchant_level(id) + 1)


## Почему вещь нельзя закалить ("" — можно; золото не проверяется — temper_gold_block).
static func temper_block(item: String) -> String:
	if item == "":
		return "Положите вещь на наковальню"
	if ItemData.is_broken(item):
		return "Сломанную вещь не закалить"
	if not ItemData.is_enchantable(item):
		return "Закаляют только оружие, броню и щит"
	if ItemData.enchant_level(item) >= SMITH_MAX:
		return "Кузнец закаляет до +%d — дальше только кубы" % SMITH_MAX
	return ""


## Хватает ли золота на закалку ("" — хватает).
static func temper_gold_block(item: String) -> String:
	var price := temper_price(item)
	if Game.gold < price:
		return "Не хватает золота: нужно %d, есть %d" % [price, Game.gold]
	return ""


# ---------- Где вещь ----------

## Что надето в ячейке slot ("weapon", "offhand" или ячейка брони; "" — пусто).
static func equipped_in(slot: String) -> String:
	if slot == "weapon":
		return Game.weapon
	if slot == "offhand":
		return Game.offhand
	if slot == "":
		return ""
	return Game.gear_in(slot)


## Сколько штук вещи id лежит в ячейках сумки (не надето).
static func free_count(id: String) -> int:
	var n := Game.inventory.count(id)
	if Game.weapon == id:
		n -= 1
	if Game.offhand == id:
		n -= 1
	for s in Game.equip:
		if String(Game.equip[s]) == id:
			n -= 1
	return maxi(0, n)


## Где взять штуку вещи id: where, если там она и есть; иначе свободная в сумке (""), иначе первая надетая;
## "-" — вещи нет.
static func locate(id: String, where: String = "") -> String:
	if id == "":
		return "-"
	if where != "" and equipped_in(where) == id:
		return where
	if free_count(id) > 0:
		return ""
	for s in ["weapon", "offhand"]:
		if equipped_in(s) == id:
			return s
	for e in ItemData.GEAR_SLOTS:
		if Game.gear_in(String(e[0])) == id:
			return String(e[0])
	return "-"


## Есть ли такая вещь (там, где сказано, или где-нибудь).
static func has_item(id: String, where: String = "") -> bool:
	return locate(id, where) != "-"


## Заменить штуку old на new_id там, где она лежит (where — как locate). Надетая остаётся надетой, сломанная
## снимается (основное оружие — рука пуста, вторая рука — по правилам). Возвращает, где была ("-" — не нашлась).
static func swap(old: String, new_id: String, where: String = "") -> String:
	var inv: Inventory = Game.inventory
	var w := locate(old, where)
	if w == "-":
		return w
	if w == "":
		inv.replace_one(old, new_id)
		return w
	var wear := not ItemData.is_broken(new_id)
	inv.remove(old)
	inv.add(new_id)
	match w:
		"weapon":
			Game.weapon = new_id if wear else ""
			if Game.offhand != "" and Game.offhand_block(Game.offhand) != "":
				Game.offhand = ""
		"offhand":
			Game.offhand = new_id if wear else ""
		_:
			if wear:
				Game.equip[w] = new_id
			else:
				Game.equip.erase(w)
			Game._sync_worn()
	if not wear:
		Game.last_dropped_toggles = HeroSkills.drop_unfit_toggles(Game.hero, Game.weapon_kind(), Game.has_shield())
	Game.changed.emit()
	return w


# ---------- Чарование и закалка ----------

## Чаровать вещь item кубом cube (where — где вещь, как locate). rng — свой генератор (тесты), null — общий.
## player — пересчитать героя, если вещь надета. {"ok": удалось, "broke": сломалась, "item": id вещи после,
## "chance": шанс, "text": сообщение, "error": причина отказа ("" — попытка была)}.
static func use_cube(item: String, cube: String, where: String = "", rng: RandomNumberGenerator = null,
		player: Node = null) -> Dictionary:
	var res := {"ok": false, "broke": false, "item": item, "chance": 0.0, "text": "", "error": ""}
	var err := cube_block(item, cube)
	if err == "" and not has_item(item, where):
		err = "Этой вещи нет"
	if err != "":
		res["error"] = err
		res["text"] = err
		return res
	var w := locate(item, where)
	var ch := chance(item)
	res["chance"] = ch
	Game.inventory.remove(cube)
	var roll := rng.randf() if rng != null else randf()
	var nm := ItemData.item_name(item)
	if roll < ch:
		var up := ItemData.enchanted_id(item, ItemData.enchant_level(item) + 1)
		swap(item, up, w)
		res["ok"] = true
		res["item"] = up
		res["text"] = "Чарование удалось: «%s»" % ItemData.item_name(up)
	else:
		var br := ItemData.broken_id(item)
		swap(item, br, w)
		res["broke"] = true
		res["item"] = br
		res["text"] = "Чарование не удалось — «%s» сломано. Куб потрачен." % nm
	_refresh(player, w)
	return res


## Закалить вещь item у кузнеца (100 %, до SMITH_MAX, за золото). {"ok", "item", "price", "text", "error"}.
static func temper(item: String, where: String = "", player: Node = null) -> Dictionary:
	var res := {"ok": false, "item": item, "price": 0, "text": "", "error": ""}
	var err := temper_block(item)
	if err == "" and not has_item(item, where):
		err = "Этой вещи нет"
	if err == "":
		err = temper_gold_block(item)
	if err != "":
		res["error"] = err
		res["text"] = err
		return res
	var w := locate(item, where)
	var price := temper_price(item)
	var up := ItemData.enchanted_id(item, ItemData.enchant_level(item) + 1)
	Game.gold -= price
	swap(item, up, w)
	res["ok"] = true
	res["item"] = up
	res["price"] = price
	res["text"] = "Закалка: «%s» за %d зол." % [ItemData.item_name(up), price]
	_refresh(player, w)
	return res


## Админ-панель: заточка надетой вещи в ячейке slot — n (0…предел кубами). Новый id ("" — в ячейке ничего).
static func admin_set(slot: String, n: int, player: Node = null) -> String:
	var id := equipped_in(slot)
	if id == "" or not ItemData.is_enchantable(id):
		return ""
	var want := ItemData.enchanted_id(id, clampi(n, 0, cube_cap(id)))
	if want != id:
		swap(id, want, slot)
		_refresh(player, slot)
	return want


## Надетое изменилось — пересчитать героя (характеристики, модель оружия).
static func _refresh(player: Node, where: String) -> void:
	if where == "" or player == null or not is_instance_valid(player):
		return
	if player.has_method("refresh_equipment"):
		player.call("refresh_equipment", where == "weapon" or where == "offhand")


## Округление цены до 2 значащих цифр (≥ 100) или до 10.
static func _round2(v: float) -> int:
	if v < 100.0:
		return maxi(10, roundi(v / 10.0) * 10)
	var mag := pow(10.0, floorf(log(v) / log(10.0)) - 1.0)
	return roundi(roundf(v / mag) * mag)
