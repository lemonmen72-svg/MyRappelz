class_name Economy
extends Node
## Предметы и деньги: добыча со зверей (мешочки на земле; сумка полна — мешочек остаётся лежать), торговец
## в безопасной зоне, покупка и продажа, зелья здоровья с перезарядкой. Окна сумки и торговли — InventoryWindow
## (window): сетка ячеек, экипировка, карточка предмета. Надетое оружие лежит не в ячейке, а в слоте «Оружие»,
## поэтому его нельзя продать или выбросить.
## Торгуют несколько NPC (группа "trader", поле npc_id; ассортимент — NpcData.shop): торговец (кнопка «Торговец»)
## и Учитель Кирк (карты существ; «Торговля» в его диалоге — Npcs). Окно торговли открыто у одного продавца
## (window.seller) и закрывается, если игрок от него отошёл; продавать из сумки можно рядом с любым из них.

## Куплено n штук предмета id у NPC seller (слушают задания — Quests).
signal bought(id: String, n: int, seller: String)

## Где стоит торговец (внутри безопасной зоны MobData.SAFE_RADIUS).
const MERCHANT_POS := Vector3(0, 0, -4)
## Кнопка «Торговец» видна, когда игрок ближе этого расстояния; дальше окно магазина закрывается.
const SHOP_RANGE := 4.0
const POTION_CD := 5.0
## Зелье лечит такую долю максимального здоровья.
const POTION_HEAL := 0.5
const GOLD_COLOR := Color(1.0, 0.85, 0.3)

var main: Node
var merchant: Merchant
## Окно сумки и торговца.
var window: InventoryWindow

var _potion_cd := 0.0
var _shop_near := false


func setup(m: Node) -> void:
	main = m
	_build_safe_zone()
	merchant = Merchant.new()
	merchant.position = MERCHANT_POS
	main.add_child(merchant)
	window = InventoryWindow.new()
	window.name = "InventoryWindow"
	add_child(window)
	window.setup(main, self)
	Game.inventory.changed.connect(_on_inventory_changed)
	main.hud.set_button_visible("shop", false)
	_update_potion_button()


## Обрабатывает действия: "potion", "bag_window", "shop". true, если действие своё.
func handle_action(id: String) -> bool:
	match id:
		"potion":
			use_potion()
			return true
		"bag_window":
			if is_bag_open():
				_close_window()
			else:
				open_bag()
			return true
		"shop":
			if is_shop_open():
				_close_window()
			elif is_near_merchant():
				open_shop()
			else:
				_msg("Подойдите к торговцу")
			return true
	return false


## Зверь убит: золото сразу в кошелёк, предметы — мешочком на землю.
func on_mob_killed(mob: Mob) -> void:
	# Золото растёт с уровнем зверя (MobData.gold_range) и с силой редкости вида (MobData.power); у боссов — своё
	var gold_range := MobData.gold_range(mob.type_id, mob.level)
	var g := roundi(float(randi_range(int(gold_range[0]), int(gold_range[1]))) * MobData.power(mob.type_id))
	Game.gold += g
	Util.float_text(main, mob.global_position + Vector3(0, 2.8, 0), "+%d зол." % g, GOLD_COLOR)
	Game.changed.emit()
	var loot := roll_loot(mob.type_id)
	if not loot.is_empty():
		spawn_drop(mob.global_position, loot)


## Бросок добычи по MobData loot: [id, шанс, мин., макс.]. Возвращает {id: количество}.
static func roll_loot(type_id: String) -> Dictionary:
	var res: Dictionary = {}
	var d := MobData.get_type(type_id)
	var loot: Array = d.get("loot", [])
	for e in loot:
		var entry: Array = e
		var id: String = entry[0]
		var chance: float = float(entry[1])
		var lo: int = int(entry[2])
		var hi: int = int(entry[3])
		if randf() < chance:
			var n := randi_range(lo, maxi(lo, hi))
			if n > 0:
				res[id] = int(res.get(id, 0)) + n
	return res


## Кладёт мешочек с добычей на землю в точке pos.
func spawn_drop(pos: Vector3, items: Dictionary) -> LootDrop:
	var drop := LootDrop.new()
	drop.items = items.duplicate()
	drop.position = Vector3(pos.x, 0.0, pos.z)
	drop.picked_up.connect(_on_drop_picked)
	drop.bag_full.connect(_on_bag_full)
	main.add_child(drop)
	return drop


# ---------- Зелья ----------

## Выпить зелье здоровья. true, если выпито.
func use_potion() -> bool:
	var p: Player = main.player
	if _potion_cd > 0.0:
		_msg("Зелье ещё не готово: %.1f с" % _potion_cd)
		return false
	if p.hp >= p.max_hp:
		_msg("Здоровье и так полное")
		return false
	if not Game.inventory.remove("hp_potion"):
		_msg("Нет зелий здоровья")
		return false
	p.heal(int(p.max_hp * POTION_HEAL))
	_potion_cd = POTION_CD
	main.hud.set_cooldown("potion", 1.0)
	return true


## Доля оставшейся перезарядки зелья: 0 = готово, 1 = только что выпито.
func potion_cooldown_frac() -> float:
	return clampf(_potion_cd / POTION_CD, 0.0, 1.0)


func _update_potion_button() -> void:
	if main == null or main.hud == null:
		return
	main.hud.set_button_text("potion", "Зелье\n%d" % Game.inventory.count("hp_potion"))
	main.hud.set_button_icon("potion", IconView.item("hp_potion"))
	main.hud.set_button_count("potion", Game.inventory.count("hp_potion"))


# ---------- Торговец ----------

func is_near_merchant() -> bool:
	if main == null or merchant == null or not is_instance_valid(merchant):
		return false
	var p: Player = main.player
	if p == null:
		return false
	var d := p.global_position - merchant.global_position
	d.y = 0.0
	return d.length() < SHOP_RANGE


func is_shop_open() -> bool:
	return window != null and window.mode == "shop" and window.is_open()


func is_bag_open() -> bool:
	return window != null and window.mode == "bag" and window.is_open()


## Окно торговли у NPC seller (по умолчанию — торговец): товары, сумка и карточка (InventoryWindow).
func open_shop(seller: String = "merchant") -> void:
	window.open("shop", seller)


## Узел торгующего NPC с id npc_id (группа "trader") или null.
func trader_node(npc_id: String) -> Node3D:
	if main == null or not main.is_inside_tree():
		return null
	for n in main.get_tree().get_nodes_in_group("trader"):
		var t := n as Node3D
		if t != null and is_instance_valid(t) and String(t.get("npc_id")) == npc_id:
			return t
	return null


## Игрок рядом (ближе SHOP_RANGE) с торгующим NPC npc_id; "" — с любым.
func is_near_trader(npc_id: String = "") -> bool:
	if main == null or main.player == null or not main.is_inside_tree():
		return false
	var p: Player = main.player
	for n in main.get_tree().get_nodes_in_group("trader"):
		var t := n as Node3D
		if t == null or not is_instance_valid(t):
			continue
		if npc_id != "" and String(t.get("npc_id")) != npc_id:
			continue
		var d := p.global_position - t.global_position
		d.y = 0.0
		if d.length() < SHOP_RANGE:
			return true
	return false


## Окно сумки: экипировка, сетка ячеек и карточка (InventoryWindow).
func open_bag() -> void:
	window.open("bag")


## Купить n штук предмета id у NPC seller ("" — у того, чьё окно торговли открыто). true — куплено.
func buy(id: String, n: int = 1, seller: String = "") -> bool:
	var who := seller if seller != "" else window.seller
	var price: int = int(ItemData.get_item(id).get("buy", 0)) * n
	if price <= 0 or n <= 0 or not InventoryWindow.goods(Game.class_id, who).has(id):
		_msg("%s это не продаёт" % NpcData.npc_name(who))
		return false
	if Game.gold < price:
		_msg("Не хватает золота: нужно %d, есть %d" % [price, Game.gold])
		return false
	if Game.inventory.room_for(id) < n:
		_msg("Сумка полна")
		return false
	# Сначала золото: сигнал сумки обновит HUD уже с новым золотом
	Game.gold -= price
	Game.inventory.add(id, n)
	_msg("Куплено: %s ×%d за %d зол." % [ItemData.item_name(id), n, price])
	bought.emit(id, n, who)
	return true


## Продать n штук из ячейки сумки i (n < 0 — всю стопку) торгующему NPC рядом. Возвращает, сколько продано.
## Надетое оружие в ячейках не лежит — его продать нельзя.
func sell_cell(i: int, n: int = 1) -> int:
	var c: Dictionary = Game.inventory.cell(i)
	if c.is_empty():
		return 0
	var id := String(c["id"])
	var price: int = int(ItemData.get_item(id).get("sell", 0))
	if price <= 0:
		_msg("Торговец это не купит")
		return 0
	if not is_near_trader():
		_msg("Продать можно только торговцу")
		return 0
	var have := int(c["n"])
	var cnt := have if n < 0 else mini(n, have)
	if cnt <= 0:
		return 0
	Game.gold += price * cnt
	Game.inventory.remove_at(i, cnt)
	_msg("Продано: %s ×%d за %d зол." % [ItemData.item_name(id), cnt, price * cnt])
	return cnt


func _close_window() -> void:
	window.close()


func _msg(t: String) -> void:
	main.hud.show_message(t)


# ---------- Мир ----------

## Видимый круг безопасной зоны: полупрозрачный диск и кольцо по краю.
func _build_safe_zone() -> void:
	var zone := Node3D.new()
	zone.name = "SafeZone"
	var r := MobData.SAFE_RADIUS


	var ring := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = r - 0.18
	rm.outer_radius = r
	rm.rings = 96
	rm.ring_segments = 8
	ring.mesh = rm
	ring.position.y = 0.03
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.material_override = _zone_mat(Color(0.6, 0.9, 1.0, 0.55))
	zone.add_child(ring)

	main.add_child(zone)


func _zone_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


# ---------- События ----------

func _on_inventory_changed() -> void:
	_update_potion_button()
	if window != null:
		window.dirty = true


func _on_drop_picked(items: Dictionary) -> void:
	if main != null and main.hud != null:
		_msg("Подобрано: " + LootDrop.describe(items))


func _on_bag_full(_left: Dictionary) -> void:
	if main != null and main.hud != null:
		_msg("Сумка полна")


func _process(delta: float) -> void:
	if main == null or main.hud == null or main.player == null:
		return
	if _potion_cd > 0.0:
		_potion_cd = maxf(0.0, _potion_cd - delta)
	main.hud.set_cooldown("potion", potion_cooldown_frac())

	var near := is_near_merchant()
	if near != _shop_near:
		_shop_near = near
		main.hud.set_button_visible("shop", near)

	if is_shop_open() and not is_near_trader(window.seller):
		_close_window()
		_msg("Вы отошли от %s" % NpcData.name_gen(window.seller))
	elif window.is_open() and (window.dirty or Game.gold != window.seen_gold):
		window.refresh()
