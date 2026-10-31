class_name QuestWindow
extends Node
## Журнал заданий (кнопка «Задания» в меню HUD, клавиша J, касание трекера). Живёт в Quests (quests.window).
## Вкладки «Активные / Выполненные»; слева — список заданий, справа — карточка выбранного: название, от кого
## и кому сдавать, описание, цели с прогрессом (галочки), награды (опыт, золото, предметы со значками ItemIcon,
## JP), кнопки «Отслеживать» / «Не отслеживать» и «Отказаться» (с подтверждением). У выполненного — слова NPC
## при сдаче и полученная награда.
## Кнопки открытого окна для тестов (buttons): "tab_active", "tab_done", "q_<id>", "track", "abandon",
## "abandon_yes", "abandon_no".

## Размеры — для «Среднего» размера интерфейса (умножаются на UiScale.k(); было 1140×640, список 330).
const WINDOW_SIZE := Vector2(900, 560)
const LIST_W := 260.0
const ICON := 30.0
const GOLD := Color(1.0, 0.85, 0.3)
const MUTED := Color(0.76, 0.78, 0.88)
const GOOD := Color(0.55, 1.0, 0.6)
const BAD := Color(1.0, 0.55, 0.45)
const SEL_COLOR := Color(1.0, 0.96, 0.62)

var main: Node
var quests: Quests
## Вкладка: "active" или "done".
var tab := "active"
## Выбранное задание ("" — первое в списке).
var selected := ""
var buttons: Dictionary = {}
## Ждёт подтверждения «Отказаться».
var abandon_confirm := false

var _body: VBoxContainer = null


func setup(m: Node, q: Quests) -> void:
	main = m
	quests = q


## Открыть журнал; select — задание, которое выбрать (вкладка — по его состоянию).
func open(select: String = "") -> void:
	abandon_confirm = false
	if select != "":
		selected = select
		tab = "done" if not quests.is_active(select) and quests.is_done(select) else "active"
	_build()


func close() -> void:
	if is_open():
		main.hud.close_window()
	_body = null


func is_open() -> bool:
	if not is_instance_valid(_body):
		return false
	var n: Node = _body
	while n != null:
		if n.is_queued_for_deletion():
			return false
		n = n.get_parent()
	return main.hud.is_window_open()


func refresh() -> void:
	if is_open():
		_build()


## Список заданий текущей вкладки.
func list_ids() -> Array:
	if tab == "done":
		var res: Array = quests.done_ids()
		res.reverse()
		return res
	return quests.active_ids()


# ---------- Построение ----------

func _build() -> void:
	buttons.clear()
	var ids := list_ids()
	if not ids.has(selected):
		selected = String(ids[0]) if not ids.is_empty() else ""
	_body = main.hud.create_window("Задания", WINDOW_SIZE)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", int(UiScale.px(UiScale.GAP)))
	_body.add_child(tabs)
	tabs.add_child(_tab_button("Активные (%d)" % quests.active_ids().size(), "tab_active", "active"))
	tabs.add_child(_tab_button("Выполненные (%d)" % quests.done_ids().size(), "tab_done", "done"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiScale.px(10)))
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(row)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(UiScale.px(LIST_W), 0)
	list.add_theme_constant_override("separation", int(UiScale.px(5)))
	row.add_child(list)
	var card_panel := PanelContainer.new()
	card_panel.add_theme_stylebox_override("panel", _card_style())
	card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(card_panel)
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", int(UiScale.px(5)))
	card_panel.add_child(card)
	if ids.is_empty():
		var t := "Активных заданий нет. Учитель Кирк в центре города подскажет, с чего начать." if tab == "active" \
			else "Вы ещё не сдали ни одного задания."
		list.add_child(_text(t, UiScale.FONT_TEXT, MUTED))
		card.add_child(_label("Журнал заданий", UiScale.FONT_HEAD, GOLD))
		card.add_child(_text("Задания выдают жители: над головой у них золотой «!». Золотой «?» — задание можно сдать, серый «?» — задание взято, но ещё не выполнено.", UiScale.FONT_BODY, MUTED))
		return
	for k in ids:
		var id := String(k)
		list.add_child(_quest_button(id))
	_build_card(card, selected)


func _tab_button(text: String, key: String, which: String) -> Button:
	var b := _button(text, key, _on_tab.bind(which))
	b.toggle_mode = true
	b.button_pressed = tab == which
	return b


func _quest_button(id: String) -> Button:
	var t := QuestData.quest_name(id)
	if tab == "active" and quests.is_ready(id):
		t += "  — готово"
	elif tab == "done" and quests.times_done(id) > 1:
		t += "  ×%d" % quests.times_done(id)
	var b := _button(t, "q_" + id, _on_select.bind(id))
	b.toggle_mode = true
	b.button_pressed = id == selected
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.custom_minimum_size = Vector2(UiScale.px(LIST_W), UiScale.button_h())
	if id == Game.quest_tracked and tab == "active":
		b.add_theme_color_override("font_color", Color(0.45, 0.28, 0.02))
	return b


func _build_card(card: VBoxContainer, id: String) -> void:
	var q := QuestData.get_quest(id)
	var title := _label(QuestData.quest_name(id), UiScale.FONT_NAME, GOLD)
	title.name = "quest_title"
	card.add_child(title)
	var giver := QuestData.giver(id)
	var to := QuestData.turn_in(id)
	var who := "Выдаёт: " + NpcData.npc_name(giver)
	if to != giver:
		who += " · сдать: " + NpcData.npc_name(to)
	card.add_child(_text(who, UiScale.FONT_BODY, MUTED))
	var active := quests.is_active(id)
	if active and quests.is_ready(id):
		card.add_child(_text("Все цели выполнены — вернитесь к %s." % NpcData.name_dat(to), UiScale.FONT_BODY, GOOD))
	card.add_child(_text(String(q.get("desc", "")), UiScale.FONT_TEXT, Color.WHITE))
	if not active:
		var said := String(q.get("done", ""))
		if said != "":
			card.add_child(_text("%s: «%s»" % [NpcData.npc_name(to), said], UiScale.FONT_BODY, MUTED))
	card.add_child(_label("Цели", UiScale.FONT_TEXT, GOLD))
	var goals := QuestData.goals(id)
	for gi in goals.size():
		var g: Dictionary = goals[gi]
		card.add_child(goal_row(g, quests.goal_progress(id, gi), quests.goal_done(id, gi) or not active))
	card.add_child(_label("Награда" if active else "Получено", UiScale.FONT_TEXT, GOLD))
	card.add_child(reward_row(id))
	if active:
		var acts := HBoxContainer.new()
		acts.add_theme_constant_override("separation", int(UiScale.px(UiScale.GAP)))
		card.add_child(acts)
		if abandon_confirm:
			card.add_child(_text("Отказаться от «%s»? Прогресс пропадёт, взять задание можно будет снова." %
				QuestData.quest_name(id), UiScale.FONT_BODY, BAD))
			acts.add_child(_button("Отказаться", "abandon_yes", _on_abandon_yes))
			acts.add_child(_button("Отмена", "abandon_no", _on_abandon_no))
		else:
			var tracked := Game.quest_tracked == id
			acts.add_child(_button("Не отслеживать" if tracked else "Отслеживать", "track", _on_track))
			acts.add_child(_button("Отказаться", "abandon", _on_abandon))


## Строка цели: галочка, подпись и прогресс «x/n» (у выполненного — зелёным).
static func goal_row(g: Dictionary, have: int, done: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiScale.px(6)))
	var ch := Check.new()
	ch.done = done
	ch.custom_minimum_size = UiScale.v2(18, 18)
	ch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ch)
	var need := QuestData.goal_need(g)
	var l := Label.new()
	l.text = "%s   %d/%d" % [QuestData.goal_text(g), mini(have, need) if not done else need, need]
	l.add_theme_font_size_override("font_size", UiScale.fs(UiScale.FONT_TEXT))
	l.add_theme_color_override("font_color", GOOD if done else Color.WHITE)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(80, 0)
	row.add_child(l)
	return row


## Награды задания: опыт, золото, JP — подписями, предметы — значком и названием.
static func reward_row(id: String) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", int(UiScale.px(14)))
	flow.add_theme_constant_override("v_separation", int(UiScale.px(5)))
	var r := QuestData.rewards(id)
	if int(r.get("xp", 0)) > 0:
		flow.add_child(_chip("Опыт: %d" % int(r["xp"]), Color(0.6, 0.9, 1.0)))
	if int(r.get("gold", 0)) > 0:
		flow.add_child(_chip("Золото: %d" % int(r["gold"]), GOLD))
	var items: Dictionary = r.get("items", {})
	for k in items:
		var item_id := String(k)
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", int(UiScale.px(5)))
		box.name = "reward_" + item_id
		var ic := ItemIcon.make(item_id, UiScale.px(ICON))
		box.add_child(ic)
		var l := _chip("%s ×%d" % [ItemData.item_name(item_id), int(items[k])], ItemData.frame_color(item_id).lerp(Color.WHITE, 0.45))
		box.add_child(l)
		flow.add_child(box)
	if int(r.get("jp", 0)) > 0:
		flow.add_child(_chip("Очки умений: %d JP" % int(r["jp"]), Color(0.85, 0.7, 1.0)))
	return flow


static func _chip(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", UiScale.fs(UiScale.FONT_TEXT))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


# ---------- Действия ----------

func _on_tab(which: String) -> void:
	tab = which
	selected = ""
	abandon_confirm = false
	_build()


func _on_select(id: String) -> void:
	selected = id
	abandon_confirm = false
	_build()


func _on_track() -> void:
	quests.track("" if Game.quest_tracked == selected else selected)
	refresh()


func _on_abandon() -> void:
	abandon_confirm = true
	_build()


func _on_abandon_yes() -> void:
	abandon_confirm = false
	quests.abandon(selected)
	selected = ""
	refresh()


func _on_abandon_no() -> void:
	abandon_confirm = false
	_build()


# ---------- Элементы ----------

func _card_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.17, 0.75)
	sb.border_color = Color(0.98, 0.88, 0.6, 0.5)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(UiScale.px(UiScale.BTN_RADIUS)))
	sb.set_content_margin_all(UiScale.px(UiScale.PAD))
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
	b.pressed.connect(cb)
	buttons[node_name] = b
	return b


## Галочка цели: рамка-квадрат, у выполненной — зелёная заливка и белая «птичка».
class Check extends Control:
	var done := false:
		set(v):
			done = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2(1, 1), size - Vector2(2, 2))
		if done:
			draw_rect(r, Color(0.25, 0.72, 0.38))
		else:
			draw_rect(r, Color(0.05, 0.06, 0.13, 0.8))
		draw_rect(r, Color(1.0, 0.95, 0.82, 0.9), false, 2.0)
		if done:
			var s := size
			var pts := PackedVector2Array([s * Vector2(0.22, 0.52), s * Vector2(0.42, 0.72), s * Vector2(0.8, 0.28)])
			draw_polyline(pts, Color.WHITE, maxf(2.0, s.x * 0.14), true)
