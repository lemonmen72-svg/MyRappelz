class_name CharacterSelect
extends CanvasLayer
## Выбор персонажа: 4 карточки слотов вошедшего аккаунта (Accounts.list_slots) — ник, раса, профессия, уровень,
## пол, сверху портрет (MenuKit.portrait: по профессии и полу, у Бродяги — по расе и полу; часть пакета «art» не
## загружена — без портрета); пустой слот — «Создать», без портрета. Фон — главный арт (MenuKit.KEY_ART), затемнённый.
## Касание карточки выбирает её; «Играть» — сигнал play(слот), «Удалить» —
## подтверждение вводом ника (Accounts.delete_slot), «Сменить аккаунт» — сигнал switch_account.
## Для тестов: select(i), cards (панели), buttons ("play", "delete", "switch", "create_<i>", "delete_yes", "delete_no"),
## confirm_delete(текст) — удалить выбранного, если ник совпал.

signal play(slot: int)
signal create(slot: int)
signal switch_account

## Карточка слота для «Среднего» размера интерфейса.
const CARD_SIZE := Vector2(225, 300)
## Сторона портрета на карточке («Средний»).
const PORTRAIT := 118.0
## Затемнение главного арта на фоне (карточки поверх).
const SHADE := 0.6

## Сообщение над карточками (перенос старого сохранения и т. п.).
var note := ""
var selected := -1
var slots: Array = []
var cards: Array[PanelContainer] = []
var buttons: Dictionary = {}
var _cards_row: HBoxContainer
var _info: Label
var _confirm_box: VBoxContainer
var _confirm_edit: LineEdit
## Нижний ряд «Удалить» / «Играть» — на время подтверждения удаления скрыт (место под строку ввода ника).
var _bottom: HBoxContainer


func _ready() -> void:
	var root := MenuKit.build_root(self, MenuKit.KEY_ART, SHADE)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", int(UiScale.px(10)))
	root.add_child(head)
	var t := MenuKit.title("Выбор персонажа")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var sw := MenuKit.button("Сменить аккаунт")
	sw.pressed.connect(func() -> void: switch_account.emit())
	head.add_child(sw)
	buttons["switch"] = sw

	var who := "Аккаунт: %s · персонажей до %d" % [Accounts.current, Accounts.SLOTS]
	if Accounts.is_admin():
		who += " · администратор"
	# Без переноса (перенос в контейнере считает высоту по самой узкой ширине и раздувает экран); строка короткая
	root.add_child(MenuKit.label(who, UiScale.FONT_TEXT, MenuKit.MUTED))
	_info = MenuKit.label(note, UiScale.FONT_TEXT, MenuKit.GOOD, true)
	root.add_child(_info)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)
	_cards_row = HBoxContainer.new()
	_cards_row.add_theme_constant_override("separation", int(UiScale.px(12)))
	center.add_child(_cards_row)

	_confirm_box = VBoxContainer.new()
	_confirm_box.add_theme_constant_override("separation", int(UiScale.px(6)))
	_confirm_box.visible = false
	root.add_child(_confirm_box)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", int(UiScale.px(12)))
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(bottom)
	_bottom = bottom
	var del := MenuKit.button("Удалить", UiScale.BUTTON_H + 4)
	del.pressed.connect(_on_delete)
	bottom.add_child(del)
	buttons["delete"] = del
	var pl := MenuKit.main_button("Играть")
	pl.custom_minimum_size.x = UiScale.px(260)
	pl.pressed.connect(_on_play)
	bottom.add_child(pl)
	buttons["play"] = pl
	refresh()


## Перечитать слоты и перестроить карточки (выбор — первый занятый слот, если прежний опустел).
func refresh() -> void:
	slots = Accounts.list_slots()
	if selected < 0 or selected >= slots.size() or (slots[selected] as Dictionary).is_empty():
		selected = -1
		for i in slots.size():
			if not (slots[i] as Dictionary).is_empty():
				selected = i
				break
	for c in _cards_row.get_children():
		_cards_row.remove_child(c)
		c.queue_free()
	cards.clear()
	for k in buttons.keys():
		if String(k).begins_with("create_"):
			buttons.erase(k)
	for i in slots.size():
		var card := _card(i)
		_cards_row.add_child(card)
		cards.append(card)
	_update_buttons()


func select(i: int) -> void:
	if i < 0 or i >= slots.size():
		return
	selected = i if not (slots[i] as Dictionary).is_empty() else selected
	_hide_confirm()
	for j in cards.size():
		var s: Dictionary = slots[j]
		cards[j].add_theme_stylebox_override("panel", MenuKit.card_style(_card_color(s), j == selected))
	_update_buttons()


func show_error(text: String) -> void:
	_info.text = text
	_info.add_theme_color_override("font_color", MenuKit.BAD)


## Портрет карточки слота i (null — пустой слот или нет картинки).
func portrait_of(i: int) -> TextureRect:
	if i < 0 or i >= cards.size():
		return null
	var found := cards[i].find_child("Portrait", true, false)
	return found as TextureRect


func _card_color(s: Dictionary) -> Color:
	if s.is_empty():
		return Color(0.4, 0.42, 0.5)
	var c: Color = ClassData.cls(String(s.get("class", ClassData.WANDERER)))["color"]
	return c.lightened(0.25)


func _card(i: int) -> PanelContainer:
	var s: Dictionary = slots[i]
	var panel := PanelContainer.new()
	panel.custom_minimum_size = UiScale.v2(CARD_SIZE.x, CARD_SIZE.y)
	panel.add_theme_stylebox_override("panel", MenuKit.card_style(_card_color(s), i == selected))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_card_input.bind(i))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(UiScale.px(6)))
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)
	if s.is_empty():
		# Номер — только у пустого слота (у занятого карточка ниже: экран влезает в 720 px на «Крупном»)
		v.add_child(_pass(MenuKit.label("Слот %d" % (i + 1), UiScale.FONT_SMALL, MenuKit.MUTED)))
		var sp := Control.new()
		sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(sp)
		var l := _pass(MenuKit.label("Пустой слот", UiScale.FONT_HEAD, MenuKit.MUTED))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		var b := MenuKit.main_button("Создать")
		b.pressed.connect(func() -> void: create.emit(i))
		v.add_child(b)
		buttons["create_%d" % i] = b
		var sp2 := Control.new()
		sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sp2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(sp2)
		return panel
	var cls := String(s.get("class", ClassData.WANDERER))
	var col := _card_color(s)
	var pic := MenuKit.portrait(cls, String(s.get("race", "")), String(s.get("gender", "f")), PORTRAIT)
	if pic != null:
		v.add_child(pic)
	var nick := _pass(MenuKit.label(String(s.get("name", "")), UiScale.FONT_NAME + 2, MenuKit.GOLD))
	# Длинный ник (до 16 букв) не раздвигает карточку: обрезается многоточием, полностью — в подсказке
	nick.clip_text = true
	nick.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nick.tooltip_text = nick.text
	v.add_child(nick)
	v.add_child(_pass(MenuKit.label("Уровень %d" % int(s.get("level", 1)), UiScale.FONT_HEAD, Color.WHITE)))
	v.add_child(_pass(MenuKit.label(ClassData.job_name(cls), UiScale.FONT_HEAD, col)))
	# Раса и пол — одной строкой (карточка невысокая: экран с подтверждением удаления влезает в 720 px на «Крупном»)
	var race_name := String(ClassData.race(String(s.get("race", ""))).get("name", ""))
	var who := _pass(MenuKit.label("%s · %s" % [race_name, ClassData.gender_name(String(s.get("gender", "f")))],
		UiScale.FONT_TEXT, MenuKit.TEXT))
	v.add_child(who)
	return panel


## Касание карточки выбирает её.
func _on_card_input(e: InputEvent, i: int) -> void:
	var mb := e as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		select(i)


## Подписи внутри карточки не перехватывают касание (оно выбирает карточку).
func _pass(l: Label) -> Label:
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _update_buttons() -> void:
	var has := selected >= 0
	(buttons["play"] as Button).disabled = not has
	(buttons["delete"] as Button).disabled = not has


func _on_play() -> void:
	if selected >= 0:
		play.emit(selected)


## «Удалить»: подтверждение — ввести ник выбранного персонажа.
func _on_delete() -> void:
	if selected < 0:
		return
	for c in _confirm_box.get_children():
		_confirm_box.remove_child(c)
		c.queue_free()
	var nick := String((slots[selected] as Dictionary).get("name", ""))
	# Без переноса: перенос в контейнере считает высоту по самой узкой ширине и выталкивает экран за 720 px
	_confirm_box.add_child(MenuKit.label("Удалить «%s» навсегда? Введите ник для подтверждения:" % nick, UiScale.FONT_TEXT,
		MenuKit.BAD))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiScale.px(10)))
	_confirm_box.add_child(row)
	_confirm_edit = MenuKit.line_edit("Ник персонажа")
	_confirm_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_confirm_edit)
	var yes := MenuKit.button("Удалить навсегда")
	yes.pressed.connect(func() -> void: confirm_delete(_confirm_edit.text))
	row.add_child(yes)
	buttons["delete_yes"] = yes
	var no := MenuKit.button("Отмена")
	no.pressed.connect(_hide_confirm)
	row.add_child(no)
	buttons["delete_no"] = no
	_confirm_box.visible = true
	_bottom.visible = false


func _hide_confirm() -> void:
	if _confirm_box != null:
		_confirm_box.visible = false
	if _bottom != null:
		_bottom.visible = true


## Удалить выбранного персонажа, если text совпал с его ником (без учёта регистра). true — удалён.
func confirm_delete(text: String) -> bool:
	if selected < 0:
		return false
	var nick := String((slots[selected] as Dictionary).get("name", ""))
	if Accounts.key(text) != Accounts.key(nick):
		show_error("Ник не совпал — персонаж не удалён")
		return false
	if not Accounts.delete_slot(selected):
		show_error("Не удалось удалить персонажа")
		return false
	_hide_confirm()
	_info.text = "Персонаж «%s» удалён" % nick
	_info.add_theme_color_override("font_color", MenuKit.MUTED)
	selected = -1
	refresh()
	return true
