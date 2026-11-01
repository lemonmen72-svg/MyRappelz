class_name InventoryWindow
extends Node
## Окно сумки как в MMORPG (кнопка «Сумка», клавиши I и B) и окно торговца в том же стиле. Живёт в Economy
## (main.economy.window); данные — Game.inventory (ячейки Inventory), Game.weapon, Game.gold.
## Сумка: слева — экипировка героя в два столбца (EQUIP_SLOTS: «Оружие», «2-я рука», «Голова», «Тело», «Руки», «Ноги»;
## «Кольцо 1», «Кольцо 2», «Серьги», «Кулон», «Пояс» — броня и украшения, Game.equip), в центре — золото,
## занятость «N/40», «Сортировать» и сетка ячеек (COLS столбцов; если ячеек больше
## вместимости — окно прокручивается), справа — карточка выбранного: значок, название цветом редкости, тип и
## редкость, описание, характеристики (у оружия — сравнение с надетым: лучше зелёным, хуже красным), цена продажи
## и кнопки по типу: «Надеть», «Использовать», «Сформировать» (карта существа с душой — питомец в коллекцию),
## «Продать» / «Продать все» (только рядом с торговцем),
## «Переместить», «Выбросить» (с подтверждением, у стопок — сколько).
## Пальцем: касание ячейки — карточка; «Переместить», затем касание другой ячейки — стопки одного предмета
## складываются, разные предметы меняются местами; то же — перетаскиванием значка (касания эмулируют мышь),
## оружие можно перетащить в слот «Оружие», броню и украшения — в свою ячейку экипировки. Надетое меняется местами
## с выбранным (старое — в ту же ячейку сумки). Карточка брони и украшения — бонусы, сравнение с надетым в той же
## ячейке (лучше зелёным, хуже красным), кому подходит доспех, ранг и уровень; «Надеть» (кольцо — «Во 2-е кольцо»),
## у надетого — «Снять».
## Торговля (у торговца или другого NPC — seller, ассортимент NpcData.shop): слева — товары (касание — карточка
## с «Купить» / «Купить ×5»), в центре — сумка (касание — карточка с «Продать» / «Продать все»), справа — карточка.
## Продать из сумки можно рядом с любым торгующим NPC.
## Склад (у Кладовщика Тобина, Economy.open_storage): слева — ячейки склада (Game.storage), в центре — сумка, справа —
## карточка: у вещи из сумки «На склад» / «На склад все», у вещи со склада «В сумку» / «В сумку все»; значок можно
## перетащить из сумки на склад и обратно. Надетое оружие в ячейках сумки не лежит — на склад его не положить.
## Золото на складе (Game.storage_gold): под ячейками склада «На складе: N зол.», поле суммы с «Положить» / «Забрать»
## и быстрые кнопки +100 / +1000 / всё в обе стороны (Economy.deposit_gold / withdraw_gold).
## Зелья (ItemData.POTION_KINDS): «Использовать» — Economy.drink; в карточке ранг и с какого уровня можно пить.
## Оружие: в карточке ранг и с какого уровня можно надеть (ниже — «Надеть» выключена).
## Крафт (этап 3, Enchant): кнопка «Крафт» в сумке меняет столбец экипировки на панель чарования — ячейка вещи
## (оружие, броня, щит — из сумки или надетая) и ячейка куба, шанс, предел, что будет при неудаче, «Крафт» с
## подтверждением (вещь может сломаться), итог. Положить — перетащить значок в ячейку панели, или «В крафт» в карточке,
## или касание пустой ячейки панели при выбранной вещи (телефон); касание занятой — убрать. Ниже — надетое
## (оружие и броня): касание — карточка с «В крафт». Сумка в режиме крафта — помельче (SHOP_CELL), чтобы всё
## поместилось.
## Кузница (окно "forge", Кузнец Гуннар — Economy.open_forge): слева наковальня — ячейка вещи, «+N → +N+1», цена,
## «Закалить» (нет золота — серая, причина красным), итог и надетое; в центре сумка; справа карточка с
## «На наковальню». Отошёл от кузнеца — окно закрывается.
## Кнопки открытого окна для тестов (buttons): "cell_<i>", "store_<i>", "equip_<слот>", "good_<id>", "sort",
## "sort_store", "act_equip", "act_equip_ring2", "act_unequip", "act_use", "act_form", "act_sell", "act_sell_all",
## "act_move", "act_move_cancel",
## "act_drop", "act_drop_yes", "act_drop_no", "act_drop_minus", "act_drop_plus", "act_drop_all", "act_buy", "act_buy5",
## "act_store", "act_store_all", "act_take", "act_take_all", "gold_put", "gold_take", "gold_put_100",
## "gold_put_1000", "gold_put_all", "gold_take_100", "gold_take_1000", "gold_take_all"; поле суммы — gold_edit;
## крафт и кузница: "craft_toggle", "craft_0" (вещь), "craft_1" (куб), "act_craft_put", "act_craft", "act_craft_yes",
## "act_craft_no", "act_craft_clear", "forge_0", "act_forge_put", "act_forge", "act_forge_clear", надетое на панели —
## "worn_<слот>".

## Размеры — для «Среднего» размера интерфейса (умножаются на UiScale.k(); было окно 1240×680, ячейка 88).
const WINDOW_SIZE := Vector2(1060, 580)
## Сетка сумки: столбцов, размер ячейки в окне сумки и в окне торговца, зазор.
const COLS := 8
const CELL := 64.0
const SHOP_CELL := 54.0
const GAP := 5.0
## Товары торговца: столбцов.
const SHOP_COLS := 3
const EQUIP_CELL := 54.0
## Ширина карточки предмета (окно сумки / окно торговца).
const CARD_W := 300.0
const SHOP_CARD_W := 290.0
const BIG_ICON := 72.0
## Сколько штук покупается кнопкой «Купить ×N».
const BUY_MANY := 5
## Панель крафта и наковальня: ширина столбца, ячейки вещи и куба, ячейки надетого.
const CRAFT_W := 200.0
const CRAFT_CELL := 60.0
const WORN_CELL := 44.0
## Надетое, что точится: на панели крафта и наковальне.
const WORN_SLOTS := ["weapon", "offhand", "head", "body", "hands", "feet"]
## Окно склада: ячейки склада и сумки (по COLS столбцов) и ширина карточки — поуже, чтобы две сетки поместились.
const STORE_SIZE := Vector2(1040, 560)
const STORE_CELL := 42.0
const STORE_CARD_W := 240.0

const GOLD := Color(1.0, 0.85, 0.3)
const MUTED := Color(0.76, 0.78, 0.88)
const GOOD := Color(0.55, 1.0, 0.6)
const BAD := Color(1.0, 0.55, 0.45)
const SEL_COLOR := Color(1.0, 0.96, 0.62)
const EMPTY_FRAME := Color(0.42, 0.44, 0.58, 0.75)
const CELL_BG := Color(0.05, 0.06, 0.13, 0.92)

## Слоты экипировки: [id, название]. «Оружие» (Game.weapon) и «2-я рука» (щит или второй такой же клинок,
## Game.offhand), остальные — броня и украшения (ItemData.GEAR_SLOTS, Game.equip). Первые EQUIP_COL_A — левый
## столбец (оружие и броня), остальные — правый (украшения).
const EQUIP_SLOTS := [
	["weapon", "Оружие"], ["offhand", "2-я рука"], ["head", "Голова"], ["body", "Тело"],
	["hands", "Руки"], ["feet", "Ноги"], ["ring1", "Кольцо 1"], ["ring2", "Кольцо 2"], ["earring", "Серьги"],
	["pendant", "Кулон"], ["belt", "Пояс"],
]
const EQUIP_COL_A := 6

var main: Node
var economy: Node
## Открытое окно: "" (закрыто), "bag", "shop", "storage" (склад) или "forge" (кузница).
var mode := ""
## Панель «Крафт» в сумке открыта (вместо экипировки); в ячейках — вещь craft_item (где: craft_where — "" сумка или
## ячейка экипировки) и куб craft_cube; craft_confirm — ждёт подтверждения; итог последней попытки — craft_result
## (craft_ok — удалось).
var craft_open := false
var craft_item := ""
var craft_where := ""
var craft_cube := ""
var craft_confirm := false
var craft_result := ""
var craft_ok := false
## Наковальня кузницы: вещь forge_item (где — forge_where), итог последней закалки.
var forge_item := ""
var forge_where := ""
var forge_result := ""
## У кого открыта торговля (id NPC, NpcData).
var seller := "merchant"
## Выбранное: sel_kind "cell" (ячейка сумки sel_index с предметом sel_id), "equip" (слот EQUIP_SLOTS[sel_index]),
## "good" (товар sel_id), "store" (ячейка склада sel_index с предметом sel_id), "" — ничего.
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
## Поле суммы золота в окне склада (null — окно не склада).
var gold_edit: LineEdit = null


func setup(m: Node, eco: Node) -> void:
	main = m
	economy = eco


## Открыть окно kind ("bag", "shop" или "storage") заново, без выделения. who — продавец для "shop" ("" — прежний).
func open(kind: String, who: String = "") -> void:
	mode = kind
	# Сумка открывается с экипировкой; панель «Крафт» — кнопкой «Крафт» или open_craft
	craft_open = false
	craft_confirm = false
	if kind == "shop" and who != "":
		seller = who
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


## Выбрать ячейку склада (как касание; окно склада).
func select_store(i: int) -> void:
	_on_cell("store", i)


## Товары NPC who (NpcData.shop): продаётся (buy > 0; id, которого ещё нет в ItemData, пропускается — у него
## buy 0), оружие и доспех — только подходящие классу героя class_id.
static func goods(class_id: String, who: String = "merchant") -> Array:
	var res: Array = []
	for key in NpcData.shop(who):
		var id := String(key)
		if int(ItemData.get_item(id).get("buy", 0)) <= 0:
			continue
		if ItemData.is_weapon(id) and not ItemData.weapon_fits(id, class_id):
			continue
		if ItemData.is_armor(id) and not ItemData.armor_fits(id, class_id):
			continue
		res.append(id)
	return res


# ---------- Построение ----------

func _build() -> void:
	dirty = false
	seen_gold = Game.gold
	buttons.clear()
	gold_edit = null
	_validate_selection()
	_validate_craft()
	var title := "Сумка" if mode == "bag" else NpcData.shop_title(seller)
	if mode == "storage":
		title = "Склад — %s" % NpcData.npc_name(Economy.STORAGE_NPC)
	elif mode == "forge":
		title = "Кузница — %s" % NpcData.npc_name(Enchant.SMITH_NPC)
	_body = main.hud.create_window(title, STORE_SIZE if mode == "storage" else WINDOW_SIZE)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiScale.px(10)))
	_body.add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", int(UiScale.px(GAP)))
	row.add_child(left)
	var center := VBoxContainer.new()
	center.add_theme_constant_override("separation", int(UiScale.px(6)))
	row.add_child(center)
	var card_panel := PanelContainer.new()
	card_panel.add_theme_stylebox_override("panel", _card_style())
	card_panel.custom_minimum_size = Vector2(_card_w(), 0)
	card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(card_panel)
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", int(UiScale.px(5)))
	card_panel.add_child(card)
	if mode == "shop":
		_build_goods(left)
		_build_bag(center, UiScale.px(SHOP_CELL))
	elif mode == "storage":
		_build_storage(left)
		_build_bag(center, UiScale.px(STORE_CELL))
	elif mode == "forge":
		_build_forge(left)
		_build_bag(center, UiScale.px(SHOP_CELL))
	elif craft_open:
		_build_craft(left)
		_build_bag(center, UiScale.px(SHOP_CELL))
	else:
		_build_equipment(left)
		_build_bag(center, UiScale.px(CELL))
	_build_card(card)


## Ширина карточки предмета (с масштабом интерфейса).
func _card_w() -> float:
	if mode == "storage":
		return UiScale.px(STORE_CARD_W)
	return UiScale.px(SHOP_CARD_W if mode == "shop" else CARD_W)


## Выделение после изменений: ячейка сумки следует за своим предметом (сортировка, продажа части стопки).
func _validate_selection() -> void:
	if sel_kind != "cell" and sel_kind != "store":
		return
	var inv: Inventory = Game.storage if sel_kind == "store" else Game.inventory
	if String(inv.cell(sel_index).get("id", "")) == sel_id and sel_id != "":
		return
	var j := inv.find_cell(sel_id) if sel_id != "" else -1
	if j < 0:
		clear_selection()
	else:
		sel_index = j


func _build_equipment(parent: VBoxContainer) -> void:
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", int(UiScale.px(GAP)))
	parent.add_child(cols)
	var col_a := VBoxContainer.new()
	col_a.add_theme_constant_override("separation", int(UiScale.px(GAP)))
	cols.add_child(col_a)
	var col_b := VBoxContainer.new()
	col_b.add_theme_constant_override("separation", int(UiScale.px(GAP)))
	cols.add_child(col_b)
	for i in EQUIP_SLOTS.size():
		var slot_id := String(EQUIP_SLOTS[i][0])
		var b := _make_cell("equip", i, equipped_in(slot_id), "", UiScale.px(EQUIP_CELL), sel_kind == "equip" and sel_index == i,
			String(EQUIP_SLOTS[i][1]))
		(col_a if i < EQUIP_COL_A else col_b).add_child(b)
		buttons["equip_" + slot_id] = b


## Что надето в слоте slot_id ("weapon", "offhand" или ячейка брони и украшений): id предмета или "".
static func equipped_in(slot_id: String) -> String:
	if slot_id == "weapon":
		return Game.weapon
	if slot_id == "offhand":
		return Game.offhand
	return Game.gear_in(slot_id)


## Индекс слота экипировки по id ("ring2" → 7; −1 — нет).
static func equip_index(slot_id: String) -> int:
	for i in EQUIP_SLOTS.size():
		if String(EQUIP_SLOTS[i][0]) == slot_id:
			return i
	return -1


## Выбрать слот экипировки (как касание): "weapon", "offhand", "head", … "belt".
func select_equip(slot_id: String) -> void:
	var i := equip_index(slot_id)
	if i >= 0:
		_on_cell("equip", i)


func _build_goods(parent: VBoxContainer) -> void:
	parent.add_child(_label("Товары", UiScale.FONT_HEAD, GOLD))
	var grid := GridContainer.new()
	grid.columns = SHOP_COLS
	grid.add_theme_constant_override("h_separation", int(UiScale.px(GAP)))
	grid.add_theme_constant_override("v_separation", int(UiScale.px(GAP)))
	parent.add_child(grid)
	var list := goods(Game.class_id, seller)
	for i in list.size():
		var id := String(list[i])
		var price := int(ItemData.get_item(id).get("buy", 0))
		var b := _make_cell("good", i, id, str(price), UiScale.px(SHOP_CELL), sel_kind == "good" and sel_id == id)
		grid.add_child(b)
		buttons["good_" + id] = b


## Склад (окно склада): «Склад», занятость «N/40», «Сортировать» и сетка ячеек Game.storage.
func _build_storage(parent: VBoxContainer) -> void:
	var st: Inventory = Game.storage
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", int(UiScale.px(10)))
	parent.add_child(head)
	var used := _label("На складе: %d/%d" % [st.used_cells(), Inventory.CAPACITY], UiScale.FONT_HEAD,
		BAD if st.is_full() else MUTED)
	used.name = "store_used_label"
	used.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(used)
	head.add_child(_button("Сортировать", "sort_store", _on_sort_store))
	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", int(UiScale.px(GAP)))
	grid.add_theme_constant_override("v_separation", int(UiScale.px(GAP)))
	parent.add_child(grid)
	var list := st.cells()
	var total := st.cell_count()
	for i in total:
		var c: Dictionary = list[i] if i < list.size() else {}
		var id := String(c.get("id", ""))
		var n := int(c.get("n", 0))
		var b := _make_cell("store", i, id, str(n) if n > 1 else "", UiScale.px(STORE_CELL),
			sel_kind == "store" and sel_index == i)
		grid.add_child(b)
		buttons["store_%d" % i] = b
	_build_storage_gold(parent)


## Золото на складе: сколько лежит, поле суммы с «Положить» / «Забрать», быстрые суммы.
func _build_storage_gold(parent: VBoxContainer) -> void:
	var l := _label("На складе: %d зол." % Game.storage_gold, UiScale.FONT_HEAD, GOLD)
	l.name = "store_gold_label"
	parent.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiScale.px(6)))
	parent.add_child(row)
	gold_edit = LineEdit.new()
	gold_edit.name = "gold_edit"
	gold_edit.placeholder_text = "Сумма"
	gold_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	gold_edit.custom_minimum_size = Vector2(UiScale.px(90), UiScale.button_h())
	gold_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gold_edit.add_theme_font_size_override("font_size", UiScale.fs(UiScale.FONT_TEXT))
	row.add_child(gold_edit)
	row.add_child(_button("Положить", "gold_put", _on_gold_typed.bind(true)))
	row.add_child(_button("Забрать", "gold_take", _on_gold_typed.bind(false)))
	for side in [[true, "На склад:", "gold_put_", "+"], [false, "В сумку:", "gold_take_", ""]]:
		var e: Array = side
		var put := bool(e[0])
		var q := HBoxContainer.new()
		q.add_theme_constant_override("separation", int(UiScale.px(5)))
		parent.add_child(q)
		var cap := _label(String(e[1]), UiScale.FONT_BODY, MUTED)
		cap.custom_minimum_size = Vector2(UiScale.px(80), 0)
		q.add_child(cap)
		for n in [100, 1000]:
			q.add_child(_button("%s%d" % [String(e[3]), int(n)], "%s%d" % [String(e[2]), int(n)], _on_gold.bind(put, int(n))))
		q.add_child(_button("Всё", String(e[2]) + "all", _on_gold.bind(put, -1)))


func _build_bag(parent: VBoxContainer, cell_sz: float) -> void:
	var inv: Inventory = Game.inventory
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", int(UiScale.px(10)))
	parent.add_child(head)
	head.add_child(_label("Золото: %d" % Game.gold, UiScale.FONT_HEAD, GOLD))
	var used := _label("Занято: %d/%d" % [inv.used_cells(), Inventory.CAPACITY], UiScale.FONT_HEAD,
		BAD if inv.is_full() else MUTED)
	used.name = "used_label"
	used.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(used)
	head.add_child(_button("Сортировать", "sort", _on_sort))
	if mode == "bag":
		var cb := _button("Экипировка" if craft_open else "Крафт", "craft_toggle", _on_craft_toggle)
		UiIcons.add_icon(cb, "menu_bag" if craft_open else "btn_craft")
		head.add_child(cb)
	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", int(UiScale.px(GAP)))
	grid.add_theme_constant_override("v_separation", int(UiScale.px(GAP)))
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


# ---------- Крафт и кузница ----------

## Вещи на панели крафта и наковальне ещё есть (продали, выбросили, сломалась — ячейка пустеет); куб — в сумке.
func _validate_craft() -> void:
	if craft_item != "" and not Enchant.has_item(craft_item, craft_where):
		craft_item = ""
		craft_where = ""
		craft_confirm = false
	elif craft_item != "":
		craft_where = Enchant.locate(craft_item, craft_where)
	if craft_cube != "" and not Game.inventory.has(craft_cube):
		craft_cube = ""
		craft_confirm = false
	if forge_item != "" and not Enchant.has_item(forge_item, forge_where):
		forge_item = ""
		forge_where = ""
	elif forge_item != "":
		forge_where = Enchant.locate(forge_item, forge_where)


## Открыть сумку с панелью крафта.
func open_craft() -> void:
	open("bag")
	craft_open = true
	refresh()


## Положить вещь id на панель крафта (where — "" из сумки или ячейка экипировки). "" — положено, иначе причина.
func put_craft(id: String, where: String = "") -> String:
	if ItemData.is_cube(id):
		return put_cube(id)
	if not ItemData.is_enchantable(id):
		var why := "Сломанную вещь не чаруют" if ItemData.is_broken(id) else "Чаруются только оружие, броня и щит"
		_msg(why)
		return why
	if not Enchant.has_item(id, where):
		return "Этой вещи нет"
	craft_open = true
	craft_item = id
	craft_where = Enchant.locate(id, where)
	craft_confirm = false
	craft_result = ""
	# Подходящий куб из сумки — сразу во вторую ячейку, если там пусто или не тот
	if craft_cube == "" or Enchant.cube_block(id, craft_cube) != "":
		var best := _best_cube(id)
		if best != "":
			craft_cube = best
	refresh()
	return ""


## Положить куб id на панель крафта.
func put_cube(id: String) -> String:
	if not ItemData.is_cube(id) or not Game.inventory.has(id):
		return "Это не куб"
	craft_open = true
	craft_cube = id
	craft_confirm = false
	craft_result = ""
	refresh()
	return ""


## Положить вещь на наковальню кузницы.
func put_forge(id: String, where: String = "") -> String:
	if not ItemData.is_enchantable(id):
		var why := "Сломанную вещь не закалить" if ItemData.is_broken(id) else "Закаляют только оружие, броню и щит"
		_msg(why)
		return why
	if not Enchant.has_item(id, where):
		return "Этой вещи нет"
	forge_item = id
	forge_where = Enchant.locate(id, where)
	forge_result = ""
	refresh()
	return ""


## Подходящий вещи куб из сумки (младший из подходящих по рангу; "" — нет).
func _best_cube(item: String) -> String:
	var best := ""
	for k in Game.inventory.ids():
		var cid := String(k)
		if ItemData.is_cube(cid) and Enchant.cube_block(item, cid) == "":
			if best == "" or ItemData.rank(cid) < ItemData.rank(best):
				best = cid
	return best


## Панель «Крафт»: ячейки вещи и куба, шанс и предел, «Крафт» (с подтверждением), итог, надетое.
func _build_craft(parent: VBoxContainer) -> void:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(UiScale.px(CRAFT_W), 0)
	box.add_theme_constant_override("separation", int(UiScale.px(GAP)))
	parent.add_child(box)
	box.add_child(_label("Крафт", UiScale.FONT_HEAD, GOLD))
	var cells := HBoxContainer.new()
	cells.add_theme_constant_override("separation", int(UiScale.px(8)))
	box.add_child(cells)
	var c0 := _make_cell("craft", 0, craft_item, "", UiScale.px(CRAFT_CELL), false, "Вещь")
	cells.add_child(c0)
	buttons["craft_0"] = c0
	cells.add_child(_label("+", UiScale.FONT_TITLE, MUTED))
	var c1 := _make_cell("craft", 1, craft_cube, str(Game.inventory.count(craft_cube)) if craft_cube != "" else "",
		UiScale.px(CRAFT_CELL), false, "Куб")
	cells.add_child(c1)
	buttons["craft_1"] = c1
	if craft_item == "":
		box.add_child(_text("Положите оружие, броню или щит (перетащите значок или «В крафт» в карточке) и куб: атаки — для оружия, защиты — для брони и щита.",
			UiScale.FONT_BODY, MUTED))
	else:
		var n := ItemData.enchant_level(craft_item)
		var cap := Enchant.cube_cap(craft_item)
		var block := Enchant.cube_block(craft_item, craft_cube)
		if craft_cube == "" and block == "":
			block = "Нужен %s %d-го ранга или старше" % ["куб атаки" if ItemData.enchant_kind(craft_item) == "attack"
				else "куб защиты", ItemData.rank(craft_item)]
		if n < cap:
			box.add_child(_text("+%d → +%d · шанс %s" % [n, n + 1, _pct(Enchant.chance(craft_item))], UiScale.FONT_TEXT,
				Color.WHITE))
		box.add_child(_text("Предел кубами: +%d" % cap, UiScale.FONT_BODY, MUTED))
		if block != "":
			box.add_child(_text(block, UiScale.FONT_BODY, BAD))
		else:
			box.add_child(_text("Неудача — вещь сломается. Куб тратится в любом случае.", UiScale.FONT_BODY, BAD.lerp(MUTED, 0.4)))
		if craft_confirm and block == "":
			box.add_child(_text("Чаровать «%s»? Шанс %s, иначе вещь сломается." % [ItemData.item_name(craft_item),
				_pct(Enchant.chance(craft_item))], UiScale.FONT_BODY, BAD))
			box.add_child(_action_grid([["Да, крафт", "act_craft_yes", _on_craft_yes], ["Отмена", "act_craft_no", _on_craft_no]]))
		else:
			var g := _action_grid([["Крафт", "act_craft", _on_craft_ask, block != ""],
				["Очистить", "act_craft_clear", _on_craft_clear]])
			UiIcons.add_icon(buttons["act_craft"] as Button, "btn_craft")
			box.add_child(g)
	if craft_result != "":
		var rl := _text(craft_result, UiScale.FONT_BODY, GOOD if craft_ok else BAD)
		rl.name = "craft_result"
		box.add_child(rl)
	_build_worn_row(box)


## Наковальня кузницы: ячейка вещи, «+N → +N+1», цена, «Закалить», итог, надетое.
func _build_forge(parent: VBoxContainer) -> void:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(UiScale.px(CRAFT_W), 0)
	box.add_theme_constant_override("separation", int(UiScale.px(GAP)))
	parent.add_child(box)
	var head := _label("Закалка", UiScale.FONT_HEAD, GOLD)
	box.add_child(head)
	var c0 := _make_cell("forge", 0, forge_item, "", UiScale.px(CRAFT_CELL), false, "Вещь")
	box.add_child(c0)
	buttons["forge_0"] = c0
	if forge_item == "":
		box.add_child(_text("Положите оружие, броню или щит на наковальню: перетащите значок или «На наковальню» в карточке.",
			UiScale.FONT_BODY, MUTED))
	else:
		var n := ItemData.enchant_level(forge_item)
		var block := Enchant.temper_block(forge_item)
		var gold_err := ""
		if block == "":
			var price := Enchant.temper_price(forge_item)
			gold_err = Enchant.temper_gold_block(forge_item)
			box.add_child(_text("+%d → +%d · успех 100%%" % [n, n + 1], UiScale.FONT_TEXT, Color.WHITE))
			var pl := _text("Цена: %d зол." % price, UiScale.FONT_TEXT, GOLD if gold_err == "" else BAD)
			pl.name = "forge_price"
			box.add_child(pl)
		if block != "":
			box.add_child(_text(block, UiScale.FONT_BODY, BAD))
		elif gold_err != "":
			box.add_child(_text(gold_err, UiScale.FONT_BODY, BAD))
		box.add_child(_action_grid([["Закалить", "act_forge", _on_forge, block != "" or gold_err != ""],
			["Убрать", "act_forge_clear", _on_forge_clear]]))
		UiIcons.add_icon(buttons["act_forge"] as Button, "btn_forge")
	if forge_result != "":
		var rl := _text(forge_result, UiScale.FONT_BODY, GOOD)
		rl.name = "forge_result"
		box.add_child(rl)
	box.add_child(_text("Кузнец закаляет до +%d. Дальше — только кубы («Крафт» в сумке): оружие 2-го ранга и выше — до +%d, броня и щит — до +%d."
		% [Enchant.SMITH_MAX, Enchant.WEAPON_MAX, Enchant.ARMOR_MAX], UiScale.FONT_SMALL, MUTED))
	_build_worn_row(box)


## Надетое, что точится (оружие и броня): маленькие ячейки, касание — карточка с «В крафт» / «На наковальню».
func _build_worn_row(parent: VBoxContainer) -> void:
	parent.add_child(_label("Надетое", UiScale.FONT_BODY, MUTED))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", int(UiScale.px(GAP)))
	grid.add_theme_constant_override("v_separation", int(UiScale.px(GAP)))
	parent.add_child(grid)
	for s in WORN_SLOTS:
		var slot := String(s)
		var i := equip_index(slot)
		var b := _make_cell("equip", i, equipped_in(slot), "", UiScale.px(WORN_CELL), sel_kind == "equip" and sel_index == i)
		b.tooltip_text = String(EQUIP_SLOTS[i][1])
		grid.add_child(b)
		buttons["worn_" + slot] = b


## Шанс процентами: «50 %», «12.5 %», «6.25 %».
static func _pct(v: float) -> String:
	var p := v * 100.0
	if is_equal_approx(p, roundf(p)):
		return "%d%%" % roundi(p)
	if is_equal_approx(p * 10.0, roundf(p * 10.0)):
		return "%.1f%%" % p
	return "%.2f%%" % p


func _on_craft_toggle() -> void:
	craft_open = not craft_open
	craft_confirm = false
	moving = false
	drop_confirm = false
	refresh()


func _on_craft_ask() -> void:
	if Enchant.cube_block(craft_item, craft_cube) != "":
		_msg(Enchant.cube_block(craft_item, craft_cube))
		return
	craft_confirm = true
	refresh()


func _on_craft_no() -> void:
	craft_confirm = false
	refresh()


func _on_craft_yes() -> void:
	craft_confirm = false
	var cube := craft_cube
	var r: Dictionary = economy.craft(craft_item, cube, craft_where)
	if String(r.get("error", "")) != "":
		refresh()
		return
	craft_ok = bool(r.get("ok", false))
	craft_result = String(r.get("text", ""))
	if craft_ok:
		craft_item = String(r.get("item", ""))
		craft_where = Enchant.locate(craft_item, craft_where)
	else:
		craft_item = ""
		craft_where = ""
	if not Game.inventory.has(cube):
		craft_cube = ""
	clear_selection()
	refresh()


func _on_craft_clear() -> void:
	craft_item = ""
	craft_where = ""
	craft_cube = ""
	craft_confirm = false
	craft_result = ""
	refresh()


func _on_forge() -> void:
	var r: Dictionary = economy.temper(forge_item, forge_where)
	if bool(r.get("ok", false)):
		forge_item = String(r.get("item", ""))
		forge_where = Enchant.locate(forge_item, forge_where)
		forge_result = String(r.get("text", ""))
	clear_selection()
	refresh()


func _on_forge_clear() -> void:
	forge_item = ""
	forge_where = ""
	forge_result = ""
	refresh()


## «В крафт» / «На наковальню» в карточке выбранного (ячейка сумки или надетое).
func _on_put_selected() -> void:
	var id := sel_id
	var where := ""
	if sel_kind == "equip":
		where = String(EQUIP_SLOTS[sel_index][0])
		id = equipped_in(where)
	if mode == "forge":
		put_forge(id, where)
	else:
		put_craft(id, where)


## Касание ячейки панели крафта (index 0 — вещь, 1 — куб) или наковальни: занятая — убрать, пустая — положить
## выбранное в сумке.
func _on_tool_cell(kind: String, index: int) -> void:
	var filled := forge_item if kind == "forge" else (craft_item if index == 0 else craft_cube)
	if filled != "":
		if kind == "forge":
			_on_forge_clear()
		elif index == 0:
			craft_item = ""
			craft_where = ""
			craft_confirm = false
			refresh()
		else:
			craft_cube = ""
			craft_confirm = false
			refresh()
		return
	if sel_kind == "cell" and sel_id != "":
		if kind == "forge":
			put_forge(sel_id)
		elif index == 1:
			put_cube(sel_id)
		else:
			put_craft(sel_id)
	elif sel_kind == "equip":
		_on_put_selected()
	else:
		_msg("Выберите вещь в сумке или перетащите её сюда")


## Ячейка: рамка цвета редкости или типа, значок, число в углу (стопка или цена), подпись (слот экипировки).
## sz — размер ячейки на экране (уже с масштабом UiScale).
func _make_cell(kind: String, index: int, id: String, corner: String, sz: float, selected: bool,
		caption: String = "") -> Cell:
	var b := Cell.new()
	b.kind = kind
	b.index = index
	b.item_id = id
	b.drop_fn = _on_drop
	b.can_drop_fn = _can_drop
	if mode == "storage":
		b.take_fn = _on_take_drop
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
		sb.set_border_width_all(3 if selected else 2)
		sb.set_corner_radius_all(int(sz * 0.12))
		sb.anti_aliasing = true
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var pad := roundf(sz * 0.08)
	var icon_sz := sz - pad * 2.0
	var icon_y := pad
	if caption != "":
		icon_sz = roundf(sz * 0.64)
		icon_y = roundf(sz * 0.06)
	if id != "":
		var ic := ItemIcon.make(id, icon_sz)
		ic.position = Vector2((sz - icon_sz) * 0.5, icon_y)
		b.add_child(ic)
	if caption != "":
		var cap := _label(caption, UiScale.FONT_TINY, MUTED if id != "" else EMPTY_FRAME.lightened(0.3))
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM if id != "" else VERTICAL_ALIGNMENT_CENTER
		cap.position = Vector2(0, 0)
		cap.size = Vector2(sz, sz - 3.0)
		b.add_child(cap)
	if corner != "":
		var cf := UiScale.FONT_SMALL if sz >= UiScale.px(CELL) else UiScale.FONT_TINY
		var lh := float(UiScale.fs(cf)) * 1.4
		var l := _label(corner, cf, GOLD if kind == "good" else Color.WHITE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.position = Vector2(2, sz - lh - 1.0)
		l.size = Vector2(sz - 7.0, lh)
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
		elif ItemData.is_gear(sel_id):
			t += " Своя ячейка экипировки — надеть."
		card.add_child(_text(t, UiScale.FONT_TEXT, Color.WHITE))
		card.add_child(_action_grid([["Отмена", "act_move_cancel", _on_move_cancel]]))
		return
	match sel_kind:
		"cell":
			_card_item(card)
		"equip":
			_card_equip(card)
		"good":
			_card_good(card)
		"store":
			_card_store(card)
		_:
			card.add_child(_label("Предмет", UiScale.FONT_HEAD, GOLD))
			var t := "Коснитесь предмета, чтобы увидеть описание и действия. Перетащите значок в другую ячейку, чтобы переложить."
			if mode == "shop":
				t = "Коснитесь товара слева, чтобы купить, или предмета в сумке, чтобы продать."
			elif mode == "storage":
				t = "Коснитесь вещи в сумке, чтобы положить её на склад, или вещи на складе, чтобы забрать. Значок можно перетащить. Надетое оружие на склад не кладётся."
			card.add_child(_text(t, UiScale.FONT_TEXT, MUTED))


## Заголовок карточки: крупный значок в рамке, название цветом редкости, тип и редкость, строка sub.
func _card_head(card: VBoxContainer, id: String, sub: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiScale.px(UiScale.GAP)))
	card.add_child(row)
	var big := UiScale.px(BIG_ICON)
	var frame := Panel.new()
	frame.custom_minimum_size = Vector2(big, big)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = CELL_BG
	sb.border_color = ItemData.frame_color(id) if id != "" else EMPTY_FRAME
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(int(UiScale.px(UiScale.BTN_RADIUS)))
	frame.add_theme_stylebox_override("panel", sb)
	if id != "":
		var ic := ItemIcon.make(id, big - 10.0)
		ic.name = "card_icon"
		ic.position = Vector2(5, 5)
		frame.add_child(ic)
	row.add_child(frame)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", int(UiScale.px(2)))
	row.add_child(info)
	if id != "":
		var title := _text(ItemData.item_name(id), UiScale.FONT_HEAD, _name_color(id))
		title.name = "card_title"
		info.add_child(title)
		info.add_child(_text("%s · %s" % [ItemData.type_name(id), ItemData.grade_name(id)], UiScale.FONT_BODY, MUTED))
	if sub != "":
		info.add_child(_text(sub, UiScale.FONT_BODY, GOLD))


func _card_item(card: VBoxContainer) -> void:
	var inv: Inventory = Game.inventory
	var c := inv.cell(sel_index)
	var id := sel_id
	var n := int(c.get("n", 1))
	var sub := "В ячейке: %d" % n if n > 1 else ""
	_card_head(card, id, sub)
	_card_body(card, id, _compare_with(id))
	if mode == "forge":
		if ItemData.is_enchantable(id):
			card.add_child(_action_grid([["На наковальню", "act_forge_put", _on_put_selected]]))
		return
	if mode == "storage":
		var sa: Array = [["На склад", "act_store", _on_store.bind(false)]]
		if n > 1:
			sa.append(["На склад все", "act_store_all", _on_store.bind(true)])
		card.add_child(_action_grid(sa))
		return
	var sell := int(ItemData.get_item(id).get("sell", 0))
	if sell > 0:
		var t := "Цена продажи: %d зол." % sell
		if n > 1:
			t += " (все: %d)" % (sell * n)
		card.add_child(_text(t, UiScale.FONT_BODY, GOLD))
	if drop_confirm:
		_drop_confirm_ui(card, id, n)
		return
	var acts: Array = []
	if ItemData.is_weapon(id):
		acts.append(["Надеть", "act_equip", _on_equip, not ItemData.weapon_fits(id, Game.class_id)
			or ItemData.level_block(id, Game.level) != ""])
		# Второй такой же клинок или топор — во вторую руку (пара)
		if not ItemData.is_shield(id) and ItemData.weapon_fits(id, Game.class_id) \
				and ItemData.offhand_block(id, Game.weapon, Game.class_id) == "":
			acts.append(["Во 2-ю руку", "act_equip_off", _on_equip_off, Game.offhand_block(id) != ""])
	elif ItemData.is_gear(id):
		var gs: String = Game.gear_slot_for(id)
		acts.append(["Надеть", "act_equip", _on_equip, Game.gear_block(id, gs) != ""])
		# Кольцо — и именно во второе кольцо (если «Надеть» положит его в первое)
		if ItemData.gear_kind(id) == "ring" and gs != "ring2":
			acts.append(["Во 2-е кольцо", "act_equip_ring2", _on_equip_ring2, Game.gear_block(id, "ring2") != ""])
	elif _usable(id):
		acts.append(["Использовать", "act_use", _on_use])
	elif ItemData.is_soul_card(id):
		acts.append(["Сформировать", "act_form", _on_form])
	# Чарование: вещь или куб — на панель «Крафт»
	if mode == "bag" and (ItemData.is_enchantable(id) or ItemData.is_cube(id)):
		acts.append(["В крафт", "act_craft_put", _on_put_selected])
	if sell > 0 and economy.is_near_trader():
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
	card.add_child(_text(q, UiScale.FONT_TEXT, BAD))
	if n > 1:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(UiScale.px(6)))
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(row)
		row.add_child(_button("−", "act_drop_minus", _on_drop_count.bind(-1)))
		var l := _label(str(drop_count), UiScale.FONT_HEAD, Color.WHITE)
		l.custom_minimum_size = Vector2(UiScale.px(44), 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(l)
		row.add_child(_button("+", "act_drop_plus", _on_drop_count.bind(1)))
		row.add_child(_button("Все", "act_drop_all", _on_drop_count.bind(n)))
	card.add_child(_action_grid([["Выбросить", "act_drop_yes", _on_drop_yes], ["Отмена", "act_drop_no", _on_drop_no]]))


func _card_equip(card: VBoxContainer) -> void:
	var slot_id := String(EQUIP_SLOTS[sel_index][0])
	var slot_name := String(EQUIP_SLOTS[sel_index][1])
	var on := equipped_in(slot_id)
	if on != "" and (mode == "forge" or craft_open):
		# Крафт и кузница: надетое — на панель («В крафт» / «На наковальню»)
		_card_head(card, on, "Надето · слот «%s»" % slot_name)
		_card_body(card, on, "")
		if ItemData.is_enchantable(on):
			card.add_child(_action_grid([["На наковальню" if mode == "forge" else "В крафт",
				"act_forge_put" if mode == "forge" else "act_craft_put", _on_put_selected]]))
		return
	if slot_id == "weapon" and Game.weapon != "":
		_card_head(card, Game.weapon, "Надето · слот «%s»" % slot_name)
		_card_body(card, Game.weapon, "")
		card.add_child(_text("Сменить: коснитесь другого оружия в сумке и «Надеть» или перетащите его сюда.", UiScale.FONT_BODY, MUTED))
		card.add_child(_action_grid([["В крафт", "act_craft_put", _on_put_selected]]))
		return
	if slot_id == "offhand" and Game.offhand != "":
		_card_head(card, Game.offhand, "Надето · слот «%s»" % slot_name)
		_card_body(card, Game.offhand, "")
		card.add_child(_action_grid([["Снять щит" if Game.has_shield() else "Снять", "act_unshield", _on_unshield],
			["В крафт", "act_craft_put", _on_put_selected]]))
		return
	var worn: String = Game.gear_in(slot_id)
	if worn != "":
		_card_head(card, worn, "Надето · слот «%s»" % slot_name)
		_card_body(card, worn, "")
		var ga: Array = [["Снять", "act_unequip", _on_unequip.bind(slot_id)]]
		if ItemData.is_enchantable(worn):
			ga.append(["В крафт", "act_craft_put", _on_put_selected])
		card.add_child(_action_grid(ga))
		return
	_card_head(card, "", "")
	card.add_child(_label(slot_name, UiScale.FONT_HEAD, GOLD))
	if slot_id == "weapon":
		card.add_child(_text("Оружия в руках нет: коснитесь оружия в сумке и «Надеть».", UiScale.FONT_TEXT, MUTED))
	elif slot_id == "offhand":
		card.add_child(_text("Вторая рука — к одноручному оружию: щит (если профессия им владеет) или второй такой же кинжал, меч или топор (если профессия держит пару). Двуручное оружие занимает обе руки.",
			UiScale.FONT_TEXT, MUTED))
	else:
		var what := String(ItemData.GEAR_KIND_NAMES.get(ItemData.gear_slot_kind(slot_id), "вещь"))
		var t := "Здесь — %s. Коснитесь вещи в сумке и «Надеть» или перетащите её сюда." % what
		if slot_id == "body":
			var v := ItemData.body_armor_for(Game.class_id)
			t += " Ваш доспех — %s." % (String(ItemData.BODY_ARMOR[v]["name"]) if v != "" else "любой (Бродяга)")
		card.add_child(_text(t, UiScale.FONT_TEXT, MUTED))


## Карточка вещи на складе: «В сумку» / «В сумку все».
func _card_store(card: VBoxContainer) -> void:
	var c: Dictionary = Game.storage.cell(sel_index)
	var id := sel_id
	var n := int(c.get("n", 1))
	_card_head(card, id, "На складе: %d" % n)
	_card_body(card, id, "")
	var acts: Array = [["В сумку", "act_take", _on_take.bind(false)]]
	if n > 1:
		acts.append(["В сумку все", "act_take_all", _on_take.bind(true)])
	card.add_child(_action_grid(acts))


func _card_good(card: VBoxContainer) -> void:
	var id := sel_id
	var price := int(ItemData.get_item(id).get("buy", 0))
	_card_head(card, id, "В сумке: %d" % Game.inventory.count(id))
	_card_body(card, id, _compare_with(id))
	var pl := _text("Цена: %d зол." % price, UiScale.FONT_TEXT, GOLD if Game.gold >= price else BAD)
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
		card.add_child(_text(desc, UiScale.FONT_BODY, Color.WHITE))
	match ItemData.item_type(id):
		"weapon":
			_weapon_stats(card, id, cmp)
		"armor", "jewelry":
			_gear_stats(card, id, cmp)
		"card":
			for line in Taming.card_lines(id):
				card.add_child(_text(String(line), UiScale.FONT_BODY, MUTED))
		"trophy":
			card.add_child(_text("Продаётся торговцу в городе.", UiScale.FONT_BODY, MUTED))
		"cube":
			card.add_child(_text("Шанс: +1…+4 — 50 %, +5…+10 — 25 %, +11…+15 — 12.5 %, +16…+20 — 6.25 %.", UiScale.FONT_BODY, MUTED))
	# Заточка и чарование (Enchant)
	if ItemData.enchant_level(id) > 0:
		card.add_child(_text(ItemData.enchant_text(id), UiScale.FONT_BODY, GOOD))
	if ItemData.is_enchantable(id):
		var cube := "куб атаки" if ItemData.enchant_kind(id) == "attack" else "куб защиты"
		card.add_child(_text("Улучшение: %s %d-го ранга и старше — до +%d («Крафт» в сумке); закалка у кузнеца — до +%d."
			% [cube, ItemData.rank(id), Enchant.cube_cap(id), Enchant.SMITH_MAX], UiScale.FONT_SMALL, MUTED))
	if ItemData.is_potion(id) or ItemData.is_equipment(id):
		var lr := ItemData.rank_level_range(ItemData.rank(id), ItemData.is_potion(id))
		var need := ItemData.required_level(id)
		var what := "пить" if ItemData.is_potion(id) else "надеть"
		card.add_child(_text("Ранг %d (ур. %d–%d) · %s можно с %d уровня" % [ItemData.rank(id), int(lr[0]), int(lr[1]),
			what, need], UiScale.FONT_BODY, BAD if Game.level < need else MUTED))
	if ItemData.potion_kind(id) == "hp":
		card.add_child(_text("Пить можно и кнопкой «Зелье» на экране (Q): берётся старший ранг, который можно по уровню. После глотка — перезарядка.", UiScale.FONT_BODY, MUTED))


func _weapon_stats(card: VBoxContainer, id: String, cmp: String) -> void:
	var it := ItemData.get_item(id)
	var has_cmp := cmp != "" and cmp != id and ItemData.is_weapon(cmp)
	var ot := ItemData.get_item(cmp) if has_cmp else {}
	var kind := ItemData.weapon_kind_name(ItemData.weapon_kind(id))
	card.add_child(_text("Вид: %s" % kind, UiScale.FONT_BODY, MUTED))
	if not ItemData.weapon_fits(id, Game.class_id):
		card.add_child(_text("Не подходит вашей профессии", UiScale.FONT_BODY, BAD))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", int(UiScale.px(12)))
	g.add_theme_constant_override("v_separation", 0)
	card.add_child(g)
	# Бонусы вида (ItemData.weapon_bonus): показаны те, что есть у этого оружия или у надетого для сравнения
	var wb := ItemData.weapon_bonus(id)
	var ob := ItemData.weapon_bonus(cmp) if has_cmp else wb
	for row in [["Физ. атака", "atk", "+%.0f", "%.0f", 1.0], ["Маг. атака", "matk", "+%.0f", "%.0f", 1.0],
			["Физ. защита", "def", "+%.0f", "%.0f", 1.0], ["Шанс блока", "block", "%.0f%%", "%.0f%%", 100.0],
			["Скорость атаки", "aspd", "%+.0f%%", "%.0f%%", 1.0], ["Скорость каста", "cast", "%+.0f%%", "%.0f%%", 1.0]]:
		var r: Array = row
		var v := float(wb[r[1]]) * float(r[4])
		var o := float(ob[r[1]]) * float(r[4])
		if v != 0.0 or (has_cmp and o != 0.0):
			_stat(g, String(r[0]), v, o, has_cmp, String(r[2]), String(r[3]), true)
	if not ItemData.is_shield(id):
		_stat(g, "Дальность", float(it.get("range", 2.0)), float(ot.get("range", 2.0)), has_cmp, "%.1f м", "%.1f", true)
		_stat(g, "Крит", float(it.get("crit", 0.0)) * 100.0, float(ot.get("crit", 0.0)) * 100.0, has_cmp,
			"+%.0f%%", "%.0f%%", true)
	var hands_text := "двуручное" if not ItemData.is_one_handed(ItemData.weapon_kind(id)) else "одноручное"
	if ItemData.is_shield(id):
		hands_text = "во вторую руку"
	elif ItemData.pair_kind(ItemData.weapon_kind(id)) != "":
		hands_text += ", можно два — по одному в каждой руке"
	card.add_child(_text("Хват: %s" % hands_text, UiScale.FONT_SMALL, MUTED))
	if has_cmp:
		card.add_child(_text("В скобках — разница с надетым: %s" % ItemData.item_name(cmp), UiScale.FONT_SMALL, MUTED))


## С чем сравнивать предмет id в карточке: оружие — с надетым оружием (щит — со щитом), броня и украшение — с вещью
## в той ячейке, куда он встанет («Надеть»); "" — не с чем.
func _compare_with(id: String) -> String:
	if ItemData.is_gear(id):
		return Game.gear_in(Game.gear_slot_for(id))
	if ItemData.is_weapon(id):
		return Game.shield if ItemData.is_shield(id) else Game.weapon
	return ""


## Броня и украшения: вид, кому подходит доспех, бонусы со сравнением с надетым cmp (у того же вида ячейки).
func _gear_stats(card: VBoxContainer, id: String, cmp: String) -> void:
	var kind := ItemData.gear_kind(id)
	var line := "Вид: %s" % String(ItemData.GEAR_KIND_NAMES.get(kind, kind))
	var v := ItemData.armor_variant(id)
	if v != "":
		line += " · %s" % String(ItemData.BODY_ARMOR[v]["name"])
	card.add_child(_text(line, UiScale.FONT_BODY, MUTED))
	if not ItemData.armor_fits(id, Game.class_id):
		card.add_child(_text("Не подходит вашей профессии: %s — для профессий %s" % [String(ItemData.BODY_ARMOR[v]["name"]),
			String(ItemData.BODY_ARMOR[v]["who"])], UiScale.FONT_BODY, BAD))
	var has_cmp := cmp != "" and cmp != id and ItemData.is_gear(cmp)
	var gb := ItemData.gear_bonus(id)
	var ob := ItemData.gear_bonus(cmp) if has_cmp else gb
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", int(UiScale.px(12)))
	g.add_theme_constant_override("v_separation", 0)
	card.add_child(g)
	for k in ItemData.GEAR_BONUS_ORDER:
		var key := String(k)
		var val := float(gb.get(key, 0.0))
		var o := float(ob.get(key, 0.0))
		if absf(val) < 0.0001 and not (has_cmp and absf(o) > 0.0001):
			continue
		var title := String(ItemData.GEAR_BONUS_NAMES[key])
		title = title.substr(0, 1).to_upper() + title.substr(1)
		if ItemData.GEAR_PCT_KEYS.has(key):
			_stat(g, title, val * 100.0, o * 100.0, has_cmp, "+%.0f%%", "%.0f%%", true)
		else:
			_stat(g, title, val, o, has_cmp, "+%.0f", "%.0f", true)
	if has_cmp:
		card.add_child(_text("В скобках — разница с надетым: %s" % ItemData.item_name(cmp), UiScale.FONT_SMALL, MUTED))


## Строка характеристики: значение и (если есть с чем сравнить) разница — лучше зелёным, хуже красным.
func _stat(g: GridContainer, title: String, v: float, other: float, cmp: bool, fmt: String, dfmt: String,
		higher_better: bool) -> void:
	g.add_child(_label(title, UiScale.FONT_BODY, MUTED))
	var text := fmt % v
	var col := Color.WHITE
	if cmp:
		var d := v - other
		if absf(d) > 0.0001:
			col = GOOD if (d > 0.0) == higher_better else BAD
			text += "  (%s%s)" % ["+" if d > 0.0 else "−", dfmt % absf(d)]
	g.add_child(_label(text, UiScale.FONT_BODY, col))


## Кнопки действий в два столбца: [текст, имя, обработчик, (выключена)].
func _action_grid(acts: Array) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", int(UiScale.px(6)))
	g.add_theme_constant_override("v_separation", int(UiScale.px(6)))
	for a in acts:
		var e: Array = a
		var b := _button(String(e[0]), String(e[1]), e[2])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if e.size() > 3 and bool(e[3]):
			b.disabled = true
		g.add_child(b)
	return g


func _usable(id: String) -> bool:
	return ItemData.is_potion(id) or id == "revive_scroll"


func _name_color(id: String) -> Color:
	if ItemData.is_card(id):
		return ItemData.frame_color(id).lerp(Color.WHITE, 0.3)
	if ItemData.rarity(id) != "common":
		return ItemData.rarity_color(id)
	var c: Color = ItemData.get_item(id).get("color", Color.WHITE)
	return c.lerp(Color.WHITE, 0.55)


# ---------- Действия ----------

func _on_cell(kind: String, index: int) -> void:
	var inv: Inventory = Game.inventory
	if (kind == "craft" or kind == "forge") and not moving:
		drop_confirm = false
		_on_tool_cell(kind, index)
		return
	if moving and sel_kind == "cell":
		moving = false
		if kind == "bag":
			_move_to(index)
		elif kind == "craft" or kind == "forge":
			_on_tool_cell(kind, index)
			return
		elif kind == "equip" and index <= 1:
			_equip_cell(sel_index)
		elif kind == "equip":
			_equip_gear_cell(sel_index, String(EQUIP_SLOTS[index][0]))
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
			var list := goods(Game.class_id, seller)
			if index >= 0 and index < list.size():
				sel_kind = "good"
				sel_index = index
				sel_id = String(list[index])
		"store":
			var sid := String(Game.storage.cell(index).get("id", ""))
			if sid == "":
				clear_selection()
			else:
				sel_kind = "store"
				sel_index = index
				sel_id = sid
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
	elif kind == "equip" and index <= 1:
		_equip_cell(from, index == 1)
	elif kind == "equip":
		_equip_gear_cell(from, String(EQUIP_SLOTS[index][0]))
	elif kind == "store":
		economy.deposit(from, -1)
		clear_selection()
	elif kind == "craft" or kind == "forge":
		var id := String(Game.inventory.cell(from).get("id", ""))
		if kind == "forge":
			put_forge(id)
		elif index == 1:
			put_cube(id)
		else:
			put_craft(id)
	refresh()


## Перетаскивание: ячейку склада from бросили на ячейку сумки — забрать стопку в сумку.
func _on_take_drop(_index: int, from: int) -> void:
	moving = false
	drop_confirm = false
	economy.withdraw(from, -1)
	clear_selection()
	refresh()


func _can_drop(kind: String, index: int, from: int) -> bool:
	if kind == "craft" or kind == "forge":
		var cid := String(Game.inventory.cell(from).get("id", ""))
		if kind == "craft" and index == 1:
			return ItemData.is_cube(cid)
		return ItemData.is_enchantable(cid)
	if kind == "store":
		return String(Game.inventory.cell(from).get("id", "")) != ""
	if kind == "bag":
		return index != from
	if kind == "equip" and index <= 1:
		var id := String(Game.inventory.cell(from).get("id", ""))
		if not ItemData.is_weapon(id):
			return false
		if index == 0:
			return not ItemData.is_shield(id)
		return ItemData.is_shield(id) or ItemData.offhand_block(id, Game.weapon, Game.class_id) == ""
	if kind == "equip" and index < EQUIP_SLOTS.size():
		var gid := String(Game.inventory.cell(from).get("id", ""))
		return ItemData.gear_slots_for(gid).has(String(EQUIP_SLOTS[index][0]))
	return false


## Надеть оружие из ячейки i (second — во вторую руку; щит — всегда во вторую); снятое оружие ложится в ту же
## ячейку (обмен).
func _equip_cell(i: int, second: bool = false) -> void:
	var inv: Inventory = Game.inventory
	var id := String(inv.cell(i).get("id", ""))
	if not ItemData.is_weapon(id):
		_msg("Это нельзя надеть")
		return
	var off := second or ItemData.is_shield(id)
	var old: String = Game.offhand if off else Game.weapon
	var err: String = main.player.equip(id, off)
	if err != "":
		_msg(err)
		return
	if old != "" and old != id:
		var j := inv.find_cell(old, true)
		var here := String(inv.cell(i).get("id", ""))
		if j >= 0 and j != i and (here == "" or here == id):
			inv.move(j, i)
	sel_kind = "equip"
	sel_index = 1 if off else 0
	sel_id = "offhand" if off else "weapon"


## Надеть броню или украшение из ячейки сумки i в ячейку экипировки gslot ("" — первая свободная подходящая);
## прежняя вещь ячейки ложится в ту же ячейку сумки (обмен). Выделение — на ячейке экипировки.
func _equip_gear_cell(i: int, gslot: String = "") -> void:
	var inv: Inventory = Game.inventory
	var id := String(inv.cell(i).get("id", ""))
	if not ItemData.is_gear(id):
		_msg("Это нельзя надеть сюда")
		return
	var target: String = gslot if gslot != "" else Game.gear_slot_for(id)
	var old: String = Game.gear_in(target)
	var err: String = main.player.equip_gear(id, target)
	if err != "":
		_msg(err)
		return
	if old != "" and old != id:
		var j := inv.find_cell(old, true)
		var here := String(inv.cell(i).get("id", ""))
		if j >= 0 and j != i and (here == "" or here == id):
			inv.move(j, i)
	sel_kind = "equip"
	sel_index = equip_index(target)
	sel_id = target


func _on_unequip(gslot: String) -> void:
	main.player.unequip_gear(gslot)
	refresh()


func _on_equip_ring2() -> void:
	_equip_gear_cell(sel_index, "ring2")
	refresh()


func _on_unshield() -> void:
	main.player.unequip_offhand()
	refresh()


func _on_equip_off() -> void:
	_equip_cell(sel_index, true)
	refresh()


func _on_equip() -> void:
	if ItemData.is_gear(sel_id):
		_equip_gear_cell(sel_index)
	else:
		_equip_cell(sel_index)
	refresh()


func _on_use() -> void:
	if ItemData.is_potion(sel_id):
		economy.drink(sel_id)
	elif sel_id == "revive_scroll":
		main.pets.revive_any()
	else:
		_msg("Этот предмет нельзя использовать")
	refresh()


## «Положить» / «Забрать» сумму из поля (пусто или не число — сообщение).
func _on_gold_typed(put: bool) -> void:
	var t := gold_edit.text.strip_edges() if gold_edit != null else ""
	if not t.is_valid_int() or int(t) <= 0:
		_msg("Введите сумму золота")
		return
	_on_gold(put, int(t))


## Быстрые суммы золота склада: put — на склад, n < 0 — всё.
func _on_gold(put: bool, n: int) -> void:
	if put:
		economy.deposit_gold(n)
	else:
		economy.withdraw_gold(n)
	refresh()


## «Сформировать»: существо из карты с душой — в коллекцию питомцев (Taming.form).
func _on_form() -> void:
	main.taming.form(sel_id)
	refresh()


## «На склад» (all — всю стопку).
func _on_store(all: bool) -> void:
	economy.deposit(sel_index, -1 if all else 1)
	refresh()


## «В сумку» со склада (all — всю стопку).
func _on_take(all: bool) -> void:
	economy.withdraw(sel_index, -1 if all else 1)
	refresh()


func _on_sort_store() -> void:
	Game.storage.sort()
	clear_selection()
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
	sb.set_corner_radius_all(int(UiScale.px(UiScale.BTN_RADIUS)))
	sb.set_content_margin_all(UiScale.px(10))
	return sb


## Подпись; font_size — для «Среднего» размера интерфейса (UiScale.FONT_*).
func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", UiScale.fs(font_size))
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
	b.custom_minimum_size = Vector2(0, UiScale.button_h())
	b.add_theme_font_size_override("font_size", UiScale.fs(UiScale.FONT_TEXT))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	buttons[node_name] = b
	return b


## Ячейка-кнопка с перетаскиванием значка: из сумки — в другую ячейку, (оружие) в слот «Оружие», (броня, украшение)
## в свою ячейку экипировки или на склад;
## со склада — в сумку.
class Cell extends Button:
	## "bag" (ячейка сумки), "equip" (слот экипировки), "good" (товар торговца), "store" (ячейка склада).
	var kind := ""
	var index := -1
	var item_id := ""
	## (kind: String, index: int, from: int) — на эту ячейку бросили ячейку сумки from.
	var drop_fn: Callable
	## (kind: String, index: int, from: int) -> bool — можно ли бросить.
	var can_drop_fn: Callable
	## (index: int, from: int) — на эту ячейку сумки бросили ячейку склада from (окно склада).
	var take_fn: Callable

	func _get_drag_data(_at_position: Vector2) -> Variant:
		if (kind != "bag" and kind != "store") or item_id == "":
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
		return {"store_cell": index} if kind == "store" else {"inv_cell": index}

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		if not (data is Dictionary):
			return false
		var d: Dictionary = data
		if d.has("store_cell"):
			return kind == "bag" and take_fn.is_valid()
		if not can_drop_fn.is_valid() or not d.has("inv_cell"):
			return false
		return bool(can_drop_fn.call(kind, index, int(d["inv_cell"])))

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if not (data is Dictionary):
			return
		var d: Dictionary = data
		if d.has("store_cell"):
			if kind == "bag" and take_fn.is_valid():
				take_fn.call(index, int(d["store_cell"]))
			return
		if drop_fn.is_valid():
			drop_fn.call(kind, index, int(d.get("inv_cell", -1)))
