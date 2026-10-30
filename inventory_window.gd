class_name InventoryWindow
extends Node
## Окно сумки как в MMORPG (кнопка «Сумка», клавиши I и B) и окно торговца в том же стиле. Живёт в Economy
## (main.economy.window); данные — Game.inventory (ячейки Inventory), Game.weapon, Game.gold.
## Сумка: слева — экипировка героя (слот «Оружие» рабочий, Голова / Тело / Руки / Ноги / Аксессуар — заглушки
## «скоро»), в центре — золото, занятость «N/40», «Сортировать» и сетка ячеек (COLS столбцов; если ячеек больше
## вместимости — окно прокручивается), справа — карточка выбранного: значок, название цветом редкости, тип и
## редкость, описание, характеристики (у оружия — сравнение с надетым: лучше зелёным, хуже красным), цена продажи
## и кнопки по типу: «Надеть», «Использовать», «Продать» / «Продать все» (только рядом с торговцем),
## «Переместить», «Выбросить» (с подтверждением, у стопок — сколько).
## Пальцем: касание ячейки — карточка; «Переместить», затем касание другой ячейки — стопки одного предмета
## складываются, разные предметы меняются местами; то же — перетаскиванием значка (касания эмулируют мышь),
## оружие можно перетащить в слот «Оружие». Надетое оружие меняется местами с выбранным (старое — в ту же ячейку).
## Торговец: слева — товары (касание — карточка с «Купить» / «Купить ×5»), в центре — сумка (касание — карточка
## с «Продать» / «Продать все»), справа — карточка.
## Кнопки открытого окна для тестов (buttons): "cell_<i>", "equip_<слот>", "good_<id>", "sort", "act_equip",
## "act_use", "act_sell", "act_sell_all", "act_move", "act_move_cancel", "act_drop", "act_drop_yes", "act_drop_no",
## "act_drop_minus", "act_drop_plus", "act_drop_all", "act_buy", "act_buy5".

const WINDOW_SIZE := Vector2(1240, 680)
## Сетка сумки: столбцов, размер ячейки в окне сумки и в окне торговца, зазор.
const COLS := 8
const CELL := 88.0
const SHOP_CELL := 72.0
const GAP := 6
## Товары торговца: столбцов.
const SHOP_COLS := 3
const EQUIP_CELL := 76.0
## Ширина карточки предмета (окно сумки / окно торговца).
const CARD_W := 336.0
const SHOP_CARD_W := 316.0
const BIG_ICON := 92.0
## Сколько штук покупается кнопкой «Купить ×N».
const BUY_MANY := 5

const GOLD := Color(1.0, 0.85, 0.3)
const MUTED := Color(0.76, 0.78, 0.88)
const GOOD := Color(0.55, 1.0, 0.6)
const BAD := Color(1.0, 0.55, 0.45)
const SEL_COLOR := Color(1.0, 0.96, 0.62)
const EMPTY_FRAME := Color(0.42, 0.44, 0.58, 0.75)
const CELL_BG := Color(0.05, 0.06, 0.13, 0.92)

## Слоты экипировки: [id, название]. Рабочий пока только «Оружие» (Game.weapon), остальные — заглушки.
const EQUIP_SLOTS := [
	["weapon", "Оружие"], ["head", "Голова"], ["body", "Тело"],
	["hands", "Руки"], ["feet", "Ноги"], ["accessory", "Аксессуар"],
]

var main: Node
var economy: Node
## Открытое окно: "" (закрыто), "bag" или "shop".
var mode := ""
## Выбранное: sel_kind "cell" (ячейка сумки sel_index с предметом sel_id), "equip" (слот EQUIP_SLOTS[sel_index]),
## "good" (товар sel_id), "" — ничего.
var sel_kind := ""
var sel_index := -1
var sel_id := ""
## Режим «Переместить»: следующее касание ячейки кладёт туда выбранный предмет.
var moving := false
## Подтверждение «Выбросить» и сколько штук.
var drop_confirm := false
var drop_count := 1
var buttons: Dictionary = {}
## Сумка или золото изменились — Economy перестроит окно в _process.
var dirty := false
var seen_gold := 0

var _body: VBoxContainer = null


func setup(m: Node, eco: Node) -> void:
	main = m
	economy = eco


## Открыть окно kind ("bag" или "shop") заново, без выделения.
func open(kind: String) -> void:
	mode = kind
	clear_selection()
	_build()


func close() -> void:
	if is_open():
		main.hud.close_window()
	mode = ""
	_body = null


func is_open() -> bool:
	if mode == "" or not is_instance_valid(_body):
		return false
	var n: Node = _body
	while n != null:
		if n.is_queued_for_deletion():
			return false
		n = n.get_parent()
	return main.hud.is_window_open()


## Перестроить открытое окно (после действия, изменения сумки или золота); выделение сохраняется.
func refresh() -> void:
	if is_open():
		_build()


func clear_selection() -> void:
	sel_kind = ""
	sel_index = -1
	sel_id = ""
	moving = false
	drop_confirm = false
	drop_count = 1


## Выбрать ячейку сумки (как касание).
func select_cell(i: int) -> void:
	_on_cell("bag", i)


## Товары торговца: продаётся (buy > 0), оружие — только подходящее классу героя class_id.
static func goods(class_id: String) -> Array:
	var res: Array = []
	for key in ItemData.ITEMS:
		var id := String(key)
		if int(ItemData.get_item(id).get("buy", 0)) <= 0:
			continue
		if ItemData.is_weapon(id) and not ItemData.weapon_fits(id, class_id):
			continue
		res.append(id)
	return res


# ---------- Построение ----------

func _build() -> void:
	dirty = false
	seen_gold = Game.gold
	buttons.clear()
	_validate_selection()
	_body = main.hud.create_window("Сумка" if mode == "bag" else "Торговец", WINDOW_SIZE)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_body.add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", GAP)
	row.add_child(left)
	var center := VBoxContainer.new()
	center.add_theme_constant_override("separation", 8)
	row.add_child(center)
	var card_panel := PanelContainer.new()
	card_panel.add_theme_stylebox_override("panel", _card_style())
	card_panel.custom_minimum_size = Vector2(_card_w(), 0)
	card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(card_panel)
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 6)
	card_panel.add_child(card)
	if mode == "shop":
		_build_goods(left)
		_build_bag(center, SHOP_CELL)
	else:
		_build_equipment(left)
		_build_bag(center, CELL)
	_build_card(card)


func _card_w() -> float:
	return SHOP_CARD_W if mode == "shop" else CARD_W


## Выделение после изменений: ячейка сумки следует за своим предметом (сортировка, продажа части стопки).
func _validate_selection() -> void:
	if sel_kind != "cell":
		return
	var inv: Inventory = Game.inventory
	if String(inv.cell(sel_index).get("id", "")) == sel_id and sel_id != "":
		return
	var j := inv.find_cell(sel_id) if sel_id != "" else -1
	if j < 0:
		clear_selection()
	else:
		sel_index = j


func _build_equipment(parent: VBoxContainer) -> void:
	for i in EQUIP_SLOTS.size():
		var slot_id := String(EQUIP_SLOTS[i][0])
		var id: String = Game.weapon if slot_id == "weapon" else ""
		var b := _make_cell("equip", i, id, "", EQUIP_CELL, sel_kind == "equip" and sel_index == i,
			String(EQUIP_SLOTS[i][1]))
		parent.add_child(b)
		buttons["equip_" + slot_id] = b


func _build_goods(parent: VBoxContainer) -> void:
	parent.add_child(_label("Товары", 22, GOLD))
	var grid := GridContainer.new()
	grid.columns = SHOP_COLS
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	parent.add_child(grid)
	var list := goods(Game.class_id)
	for i in list.size():
		var id := String(list[i])
		var price := int(ItemData.get_item(id).get("buy", 0))
		var b := _make_cell("good", i, id, str(price), SHOP_CELL, sel_kind == "good" and sel_id == id)
		grid.add_child(b)
		buttons["good_" + id] = b


func _build_bag(parent: VBoxContainer, cell_sz: float) -> void:
	var inv: Inventory = Game.inventory
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	parent.add_child(head)
	head.add_child(_label("Золото: %d" % Game.gold, 22, GOLD))
	var used := _label("Занято: %d/%d" % [inv.used_cells(), Inventory.CAPACITY], 22,
		BAD if inv.is_full() else MUTED)
	used.name = "used_label"
	used.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(used)
	head.add_child(_button("Сортировать", "sort", _on_sort))
	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	parent.add_child(grid)
	var list := inv.cells()
	var total := inv.cell_count()
	for i in total:
		var c: Dictionary = list[i] if i < list.size() else {}
		var id := String(c.get("id", ""))
		var n := int(c.get("n", 0))
		var b := _make_cell("bag", i, id, str(n) if n > 1 else "", cell_sz, sel_kind == "cell" and sel_index == i)
		grid.add_child(b)
		buttons["cell_%d" % i] = b


## Ячейка: рамка цвета редкости или типа, значок, число в углу (стопка или цена), подпись (слот экипировки).
func _make_cell(kind: String, index: int, id: String, corner: String, sz: float, selected: bool,
		caption: String = "") -> Cell:
	var b := Cell.new()
	b.kind = kind
	b.index = index
	b.item_id = id
	b.drop_fn = _on_drop
	b.can_drop_fn = _can_drop
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(sz, sz)
	b.name = "%s_%d" % [kind, index]
	var frame := ItemData.frame_color(id) if id != "" else EMPTY_FRAME
	if moving and kind == "bag" and not selected:
		frame = frame.lerp(SEL_COLOR, 0.35)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = CELL_BG.lightened(0.12) if st == "pressed" else CELL_BG
		if id != "":
			sb.bg_color = sb.bg_color.lerp(frame, 0.12)
		sb.border_color = SEL_COLOR if selected else frame
		sb.set_border_width_all(4 if selected else 2)
		sb.set_corner_radius_all(10)
		sb.anti_aliasing = true
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var icon_sz := sz - 12.0
	var icon_y := 6.0
	if caption != "":
		icon_sz = sz - 30.0
		icon_y = 4.0
	if id != "":
		var ic := ItemIcon.make(id, icon_sz)
		ic.position = Vector2((sz - icon_sz) * 0.5, icon_y)
		b.add_child(ic)
	if caption != "":
		var cap := _label(caption if id != "" or index == 0 else caption + "\nскоро", 13, MUTED if id != "" else EMPTY_FRAME.lightened(0.3))
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM if id != "" else VERTICAL_ALIGNMENT_CENTER
		cap.position = Vector2(0, 0)
		cap.size = Vector2(sz, sz - 3.0)
		b.add_child(cap)
	if corner != "":
		var l := _label(corner, 17 if sz >= CELL else 15, GOLD if kind == "good" else Color.WHITE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.position = Vector2(2, sz - 25.0)
		l.size = Vector2(sz - 8.0, 22)
		b.add_child(l)
	b.pressed.connect(_on_cell.bind(kind, index))
	return b


# ---------- Карточка ----------

func _build_card(card: VBoxContainer) -> void:
	if moving and sel_kind == "cell":
		_card_head(card, sel_id, "Переместить")
		var t := "Коснитесь ячейки, куда положить предмет. Тот же предмет сложится в стопку, другой поменяется местами."
		if ItemData.is_weapon(sel_id):
			t += " Слот «Оружие» — надеть."
		card.add_child(_text(t, 19, Color.WHITE))
		card.add_child(_action_grid([["Отмена", "act_move_cancel", _on_move_cancel]]))
		return
	match sel_kind:
		"cell":
			_card_item(card)
		"equip":
			_card_equip(card)
		"good":
			_card_good(card)
		_:
			card.add_child(_label("Предмет", 24, GOLD))
			var t := "Коснитесь предмета, чтобы увидеть описание и действия. Перетащите значок в другую ячейку, чтобы переложить."
			if mode == "shop":
				t = "Коснитесь товара слева, чтобы купить, или предмета в сумке, чтобы продать."
			card.add_child(_text(t, 19, MUTED))


## Заголовок карточки: крупный значок в рамке, название цветом редкости, тип и редкость, строка sub.
func _card_head(card: VBoxContainer, id: String, sub: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var frame := Panel.new()
	frame.custom_minimum_size = Vector2(BIG_ICON, BIG_ICON)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = CELL_BG
	sb.border_color = ItemData.frame_color(id) if id != "" else EMPTY_FRAME
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	frame.add_theme_stylebox_override("panel", sb)
	if id != "":
		var ic := ItemIcon.make(id, BIG_ICON - 12.0)
		ic.name = "card_icon"
		ic.position = Vector2(6, 6)
		frame.add_child(ic)
	row.add_child(frame)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)
	if id != "":
		var title := _text(ItemData.item_name(id), 22, _name_color(id))
		title.name = "card_title"
		info.add_child(title)
		info.add_child(_text("%s · %s" % [ItemData.type_name(id), ItemData.rarity_name(id)], 17, MUTED))
	if sub != "":
		info.add_child(_text(sub, 17, GOLD))


func _card_item(card: VBoxContainer) -> void:
	var inv: Inventory = Game.inventory
	var c := inv.cell(sel_index)
	var id := sel_id
	var n := int(c.get("n", 1))
	var sub := "В ячейке: %d" % n if n > 1 else ""
	_card_head(card, id, sub)
	_card_body(card, id, Game.weapon)
	var sell := int(ItemData.get_item(id).get("sell", 0))
	if sell > 0:
		var t := "Цена продажи: %d зол." % sell
		if n > 1:
			t += " (все: %d)" % (sell * n)
		card.add_child(_text(t, 18, GOLD))
	if drop_confirm:
		_drop_confirm_ui(card, id, n)
		return
	var acts: Array = []
	if ItemData.is_weapon(id):
		acts.append(["Надеть", "act_equip", _on_equip, not ItemData.weapon_fits(id, Game.class_id)])
	elif _usable(id):
		acts.append(["Использовать", "act_use", _on_use])
	if sell > 0 and economy.is_near_merchant():
		acts.append(["Продать", "act_sell", _on_sell.bind(false)])
		if n > 1:
			acts.append(["Продать все", "act_sell_all", _on_sell.bind(true)])
	acts.append(["Переместить", "act_move", _on_move])
	acts.append(["Выбросить", "act_drop", _on_drop_ask])
	card.add_child(_action_grid(acts))


## Подтверждение «Выбросить»: у стопки — сколько (−, +, «Все»).
func _drop_confirm_ui(card: VBoxContainer, id: String, n: int) -> void:
	drop_count = clampi(drop_count, 1, maxi(1, n))
	var q := "Выбросить «%s»%s? Предмет пропадёт." % [ItemData.item_name(id), " ×%d" % drop_count if n > 1 else ""]
	card.add_child(_text(q, 19, BAD))
	if n > 1:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(row)
		row.add_child(_button("−", "act_drop_minus", _on_drop_count.bind(-1)))
		var l := _label(str(drop_count), 24, Color.WHITE)
		l.custom_minimum_size = Vector2(56, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(l)
		row.add_child(_button("+", "act_drop_plus", _on_drop_count.bind(1)))
		row.add_child(_button("Все", "act_drop_all", _on_drop_count.bind(n)))
	card.add_child(_action_grid([["Выбросить", "act_drop_yes", _on_drop_yes], ["Отмена", "act_drop_no", _on_drop_no]]))


func _card_equip(card: VBoxContainer) -> void:
	var slot_id := String(EQUIP_SLOTS[sel_index][0])
	var slot_name := String(EQUIP_SLOTS[sel_index][1])
	if slot_id == "weapon" and Game.weapon != "":
		_card_head(card, Game.weapon, "Надето · слот «%s»" % slot_name)
		_card_body(card, Game.weapon, "")
		card.add_child(_text("Сменить: коснитесь другого оружия в сумке и «Надеть» или перетащите его сюда.", 17, MUTED))
		return
	_card_head(card, "", "")
	card.add_child(_label(slot_name, 24, GOLD))
	if slot_id == "weapon":
		card.add_child(_text("Оружие героя задано классом.", 19, MUTED))
	else:
		card.add_child(_text("Скоро: доспехи и украшения появятся вместе с экипировкой.", 19, MUTED))


func _card_good(card: VBoxContainer) -> void:
	var id := sel_id
	var price := int(ItemData.get_item(id).get("buy", 0))
	_card_head(card, id, "В сумке: %d" % Game.inventory.count(id))
	_card_body(card, id, Game.weapon)
	var pl := _text("Цена: %d зол." % price, 20, GOLD if Game.gold >= price else BAD)
	pl.name = "price_label"
	card.add_child(pl)
	var acts: Array = [["Купить", "act_buy", _on_buy.bind(1)]]
	if ItemData.stack_size(id) > 1:
		acts.append(["Купить ×%d" % BUY_MANY, "act_buy5", _on_buy.bind(BUY_MANY)])
	card.add_child(_action_grid(acts))


## Описание и характеристики. cmp — с чем сравнивать оружие (надетое), "" — без сравнения.
func _card_body(card: VBoxContainer, id: String, cmp: String) -> void:
	var desc := String(ItemData.get_item(id).get("desc", ""))
	if desc != "":
		card.add_child(_text(desc, 18, Color.WHITE))
	match ItemData.item_type(id):
		"weapon":
			_weapon_stats(card, id, cmp)
		"crystal":
			card.add_child(_text("Тратится умением «Приручить»: метка на звере, затем зверя нужно добить.", 17, MUTED))
		"trophy":
			card.add_child(_text("Продаётся торговцу в городе.", 17, MUTED))
	if id == "hp_potion":
		card.add_child(_text("Пить можно и кнопкой «Зелье» на экране (Q). После глотка — перезарядка.", 17, MUTED))


func _weapon_stats(card: VBoxContainer, id: String, cmp: String) -> void:
	var it := ItemData.get_item(id)
	var has_cmp := cmp != "" and cmp != id and ItemData.is_weapon(cmp)
	var ot := ItemData.get_item(cmp) if has_cmp else {}
	var kind := ItemData.weapon_kind_name(ItemData.weapon_kind(id))
	card.add_child(_text("Вид: %s" % kind, 17, MUTED))
	if not ItemData.weapon_fits(id, Game.class_id):
		card.add_child(_text("Не подходит вашему классу", 17, BAD))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 0)
	card.add_child(g)
	_stat(g, "Атака", float(it.get("atk", 0)), float(ot.get("atk", 0)), has_cmp, "+%.0f", "%.0f", true)
	_stat(g, "Удар раз в", float(it.get("cd", 1.0)), float(ot.get("cd", 1.0)), has_cmp, "%.2f с", "%.2f", false)
	_stat(g, "Дальность", float(it.get("range", 2.0)), float(ot.get("range", 2.0)), has_cmp, "%.1f м", "%.1f", true)
	_stat(g, "Крит", float(it.get("crit", 0.0)) * 100.0, float(ot.get("crit", 0.0)) * 100.0, has_cmp,
		"+%.0f%%", "%.0f%%", true)
	if has_cmp:
		card.add_child(_text("В скобках — разница с надетым: %s" % ItemData.item_name(cmp), 15, MUTED))


## Строка характеристики: значение и (если есть с чем сравнить) разница — лучше зелёным, хуже красным.
func _stat(g: GridContainer, title: String, v: float, other: float, cmp: bool, fmt: String, dfmt: String,
		higher_better: bool) -> void:
	g.add_child(_label(title, 18, MUTED))
	var text := fmt % v
	var col := Color.WHITE
	if cmp:
		var d := v - other
		if absf(d) > 0.0001:
			col = GOOD if (d > 0.0) == higher_better else BAD
			text += "  (%s%s)" % ["+" if d > 0.0 else "−", dfmt % absf(d)]
	g.add_child(_label(text, 18, col))


## Кнопки действий в два столбца: [текст, имя, обработчик, (выключена)].
func _action_grid(acts: Array) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	for a in acts:
		var e: Array = a
		var b := _button(String(e[0]), String(e[1]), e[2])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if e.size() > 3 and bool(e[3]):
			b.disabled = true
		g.add_child(b)
	return g


func _usable(id: String) -> bool:
	return id == "hp_potion" or id == "revive_scroll"


func _name_color(id: String) -> Color:
	if ItemData.rarity(id) != "common":
		return ItemData.rarity_color(id)
	var c: Color = ItemData.get_item(id).get("color", Color.WHITE)
	return c.lerp(Color.WHITE, 0.55)


# ---------- Действия ----------

func _on_cell(kind: String, index: int) -> void:
	var inv: Inventory = Game.inventory
	if moving and sel_kind == "cell":
		moving = false
		if kind == "bag":
			_move_to(index)
		elif kind == "equip" and index == 0:
			_equip_cell(sel_index)
		refresh()
		return
	drop_confirm = false
	moving = false
	match kind:
		"bag":
			var id := String(inv.cell(index).get("id", ""))
			if id == "":
				clear_selection()
			else:
				sel_kind = "cell"
				sel_index = index
				sel_id = id
		"equip":
			sel_kind = "equip"
			sel_index = index
			sel_id = String(EQUIP_SLOTS[index][0])
		"good":
			var list := goods(Game.class_id)
			if index >= 0 and index < list.size():
				sel_kind = "good"
				sel_index = index
				sel_id = String(list[index])
	refresh()


## Переложить выбранную ячейку в to; выделение — на месте предмета.
func _move_to(to: int) -> void:
	var inv: Inventory = Game.inventory
	if inv.move(sel_index, to):
		sel_index = to
		sel_id = String(inv.cell(to).get("id", ""))
		if sel_id == "":
			clear_selection()


## Перетаскивание: ячейку сумки from бросили на ячейку (kind, index).
func _on_drop(kind: String, index: int, from: int) -> void:
	moving = false
	drop_confirm = false
	if kind == "bag":
		sel_kind = "cell"
		sel_index = from
		sel_id = String(Game.inventory.cell(from).get("id", ""))
		_move_to(index)
	elif kind == "equip" and index == 0:
		_equip_cell(from)
	refresh()


func _can_drop(kind: String, index: int, from: int) -> bool:
	if kind == "bag":
		return index != from
	if kind == "equip" and index == 0:
		return ItemData.is_weapon(String(Game.inventory.cell(from).get("id", "")))
	return false


## Надеть оружие из ячейки i; снятое оружие ложится в ту же ячейку (обмен).
func _equip_cell(i: int) -> void:
	var inv: Inventory = Game.inventory
	var id := String(inv.cell(i).get("id", ""))
	if not ItemData.is_weapon(id):
		_msg("Это нельзя надеть")
		return
	var old: String = Game.weapon
	var err: String = main.player.equip(id)
	if err != "":
		_msg(err)
		return
	if old != "" and old != id:
		var j := inv.find_cell(old, true)
		var here := String(inv.cell(i).get("id", ""))
		if j >= 0 and j != i and (here == "" or here == id):
			inv.move(j, i)
	sel_kind = "equip"
	sel_index = 0
	sel_id = "weapon"


func _on_equip() -> void:
	_equip_cell(sel_index)
	refresh()


func _on_use() -> void:
	match sel_id:
		"hp_potion":
			economy.use_potion()
		"revive_scroll":
			main.pets.revive_any()
		_:
			_msg("Этот предмет нельзя использовать")
	refresh()


func _on_sell(all: bool) -> void:
	economy.sell_cell(sel_index, -1 if all else 1)
	refresh()


func _on_buy(n: int) -> void:
	economy.buy(sel_id, n)
	refresh()


func _on_move() -> void:
	moving = true
	drop_confirm = false
	refresh()


func _on_move_cancel() -> void:
	moving = false
	refresh()


func _on_drop_ask() -> void:
	drop_confirm = true
	drop_count = 1
	refresh()


## d > 0 и равно стопке — «Все»; ±1 — на одну.
func _on_drop_count(d: int) -> void:
	var n := int(Game.inventory.cell(sel_index).get("n", 1))
	if absi(d) > 1:
		drop_count = d
	else:
		drop_count = clampi(drop_count + d, 1, maxi(1, n))
	refresh()


func _on_drop_yes() -> void:
	var k: int = Game.inventory.remove_at(sel_index, drop_count)
	if k > 0:
		_msg("Выброшено: %s%s" % [ItemData.item_name(sel_id), " ×%d" % k if k > 1 else ""])
	drop_confirm = false
	refresh()


func _on_drop_no() -> void:
	drop_confirm = false
	refresh()


func _on_sort() -> void:
	moving = false
	drop_confirm = false
	Game.inventory.sort()
	refresh()


func _msg(t: String) -> void:
	main.hud.show_message(t)


# ---------- Элементы ----------

func _card_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.17, 0.75)
	sb.border_color = Color(0.98, 0.88, 0.6, 0.5)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(12)
	return sb


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Текст с переносом по ширине карточки.
func _text(text: String, font_size: int, color: Color) -> Label:
	var l := _label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(80, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _button(text: String, node_name: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.name = node_name
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 54)
	b.add_theme_font_size_override("font_size", 20)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	buttons[node_name] = b
	return b


## Ячейка-кнопка с перетаскиванием значка: из сумки — в другую ячейку или (оружие) в слот «Оружие».
class Cell extends Button:
	## "bag" (ячейка сумки), "equip" (слот экипировки), "good" (товар торговца).
	var kind := ""
	var index := -1
	var item_id := ""
	## (kind: String, index: int, from: int) — на эту ячейку бросили ячейку сумки from.
	var drop_fn: Callable
	## (kind: String, index: int, from: int) -> bool — можно ли бросить.
	var can_drop_fn: Callable

	func _get_drag_data(_at_position: Vector2) -> Variant:
		if kind != "bag" or item_id == "":
			return null
		var holder := Control.new()
		var ic := ItemIcon.make(item_id, size.x * 0.9)
		ic.position = -ic.size * 0.5
		ic.modulate = Color(1, 1, 1, 0.85)
		holder.add_child(ic)
		# Картинка под пальцем — только во время настоящего перетаскивания (тесты зовут метод напрямую)
		var vp := get_viewport()
		if vp != null and vp.gui_is_dragging():
			set_drag_preview(holder)
		else:
			holder.free()
		return {"inv_cell": index}

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		if not (data is Dictionary) or not can_drop_fn.is_valid():
			return false
		var d: Dictionary = data
		if not d.has("inv_cell"):
			return false
		return bool(can_drop_fn.call(kind, index, int(d["inv_cell"])))

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if not (data is Dictionary) or not drop_fn.is_valid():
			return
		var d: Dictionary = data
		drop_fn.call(kind, index, int(d.get("inv_cell", -1)))
