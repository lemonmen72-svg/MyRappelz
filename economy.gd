class_name Economy
extends Node
## Предметы и деньги: добыча со зверей (мешочки на земле), торговец в безопасной зоне,
## окна сумки и магазина, зелья здоровья с перезарядкой.

## Где стоит торговец (внутри безопасной зоны MobData.SAFE_RADIUS).
const MERCHANT_POS := Vector3(0, 0, -4)
## Кнопка «Торговец» видна, когда игрок ближе этого расстояния; дальше окно магазина закрывается.
const SHOP_RANGE := 4.0
const POTION_CD := 5.0
## Зелье лечит такую долю максимального здоровья.
const POTION_HEAL := 0.5
const GOLD_COLOR := Color(1.0, 0.85, 0.3)
const DIM_COLOR := Color(0.72, 0.72, 0.76)

var main: Node
var merchant: Merchant

var _potion_cd := 0.0
var _shop_near := false
## Окно модуля: "" (нет), "shop", "bag". _win_body — тело окна из HUD, чтобы понять, что оно ещё наше.
var _win_kind := ""
var _win_body: Control = null
var _win_dirty := false
var _win_gold := 0


func setup(m: Node) -> void:
	main = m
	_build_safe_zone()
	merchant = Merchant.new()
	merchant.position = MERCHANT_POS
	main.add_child(merchant)
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
	var d := MobData.get_type(mob.type_id)
	var gold_range: Array = d["gold"]
	var g := randi_range(int(gold_range[0]), int(gold_range[1]))
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
	return _win_kind == "shop" and _window_alive()


func is_bag_open() -> bool:
	return _win_kind == "bag" and _window_alive()


func open_shop() -> void:
	var body: VBoxContainer = main.hud.create_window("Торговец", Vector2(880, 620))
	_set_window("shop", body)
	body.add_child(_label("Золото: %d" % Game.gold, 26, GOLD_COLOR))

	body.add_child(HSeparator.new())
	body.add_child(_label("Купить", 26, Color.WHITE))
	for key in ItemData.ITEMS:
		var id: String = key
		var it := ItemData.get_item(id)
		var price: int = int(it.get("buy", 0))
		if price <= 0:
			continue
		var desc := String(it.get("desc", ""))
		var have: int = Game.inventory.count(id)
		if have > 0:
			desc += "  В сумке: %d" % have
		var row := _item_row(id, ItemData.item_name(id), desc, "%d зол." % price)
		row.add_child(_button("Купить", "buy_" + id, _buy.bind(id, 1)))
		row.add_child(_button("×5", "buy5_" + id, _buy.bind(id, 5)))
		body.add_child(row)

	body.add_child(HSeparator.new())
	body.add_child(_label("Продать", 26, Color.WHITE))
	var any := false
	var ids: Array = Game.inventory.ids()
	for key in ids:
		var id: String = key
		var price: int = int(ItemData.get_item(id).get("sell", 0))
		if price <= 0:
			continue
		any = true
		var cnt: int = Game.inventory.count(id)
		var title := "%s  ×%d" % [ItemData.item_name(id), cnt]
		var row := _item_row(id, title, String(ItemData.get_item(id).get("desc", "")), "%d зол./шт." % price)
		row.add_child(_button("Продать 1", "sell1_" + id, _sell.bind(id, 1)))
		row.add_child(_button("Продать все", "sellall_" + id, _sell.bind(id, -1)))
		body.add_child(row)
	if not any:
		body.add_child(_label("Нечего продавать: трофеи выпадают со зверей.", 20, DIM_COLOR))


func _buy(id: String, n: int) -> void:
	var price: int = int(ItemData.get_item(id).get("buy", 0)) * n
	if price <= 0:
		return
	if Game.gold < price:
		_msg("Не хватает золота: нужно %d, есть %d" % [price, Game.gold])
		return
	# Сначала золото: сигнал сумки обновит HUD уже с новым золотом
	Game.gold -= price
	Game.inventory.add(id, n)
	_msg("Куплено: %s ×%d за %d зол." % [ItemData.item_name(id), n, price])
	_rebuild_window()


## n < 0: продать все.
func _sell(id: String, n: int) -> void:
	var have: int = Game.inventory.count(id)
	var cnt: int = have if n < 0 else mini(n, have)
	var price: int = int(ItemData.get_item(id).get("sell", 0))
	if cnt <= 0 or price <= 0:
		_msg("Нечего продать")
		_rebuild_window()
		return
	Game.gold += price * cnt
	Game.inventory.remove(id, cnt)
	_msg("Продано: %s ×%d за %d зол." % [ItemData.item_name(id), cnt, price * cnt])
	_rebuild_window()


# ---------- Сумка ----------

func open_bag() -> void:
	var body: VBoxContainer = main.hud.create_window("Сумка", Vector2(780, 600))
	_set_window("bag", body)
	body.add_child(_label("Золото: %d" % Game.gold, 26, GOLD_COLOR))
	var ids: Array = Game.inventory.ids()
	if ids.is_empty():
		var l := _label("Сумка пуста. Добыча со зверей и покупки у торговца появятся здесь.", 22, DIM_COLOR)
		l.name = "empty_label"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(l)
		return
	for key in ids:
		var id: String = key
		var title := "%s  ×%d" % [ItemData.item_name(id), Game.inventory.count(id)]
		var row := _item_row(id, title, String(ItemData.get_item(id).get("desc", "")), "")
		if id == "hp_potion":
			row.add_child(_button("Использовать", "use_" + id, _use_from_bag.bind(id)))
		body.add_child(row)


func _use_from_bag(id: String) -> void:
	if id == "hp_potion":
		use_potion()
	_rebuild_window()


# ---------- Окна: общее ----------

func _set_window(kind: String, body: Control) -> void:
	_win_kind = kind
	_win_body = body
	_win_dirty = false
	_win_gold = Game.gold


func _close_window() -> void:
	main.hud.close_window()
	_win_kind = ""
	_win_body = null


## Окно модуля ещё открыто (его не закрыли и не заменили другим окном).
func _window_alive() -> bool:
	if _win_kind == "" or not is_instance_valid(_win_body):
		return false
	if not main.hud.is_window_open():
		return false
	var n: Node = _win_body
	while n != null:
		if n.is_queued_for_deletion():
			return false
		n = n.get_parent()
	return true


## Перестроить открытое окно модуля (после покупки, продажи, изменения сумки или золота).
func _rebuild_window() -> void:
	if is_shop_open():
		open_shop()
	elif is_bag_open():
		open_bag()


func _item_row(id: String, title: String, desc: String, price_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	info.add_child(_label(title, 24, _item_color(id)))
	if desc != "":
		info.add_child(_label(desc, 18, DIM_COLOR))
	row.add_child(info)
	if price_text != "":
		var pl := _label(price_text, 22, GOLD_COLOR)
		pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(pl)
	return row


## Цвет названия предмета; тёмные цвета осветляются, чтобы читались на тёмном окне.
func _item_color(id: String) -> Color:
	var c: Color = ItemData.get_item(id).get("color", Color.WHITE)
	if c.get_luminance() < 0.45:
		c = c.lightened(0.4)
	return c


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	return l


func _button(text: String, node_name: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.name = node_name
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 56)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	return b


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
	_win_dirty = true


func _on_drop_picked(items: Dictionary) -> void:
	if main != null and main.hud != null:
		_msg("Подобрано: " + LootDrop.describe(items))


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

	if is_shop_open() and not near:
		_close_window()
		_msg("Вы отошли от торговца")
	elif (is_shop_open() or is_bag_open()) and (_win_dirty or Game.gold != _win_gold):
		_rebuild_window()
