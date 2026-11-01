class_name JobWindow
extends Node
## Окно выбора первой профессии (сдача задания «Доклад мудрецу» мудрецу, QuestData "sage_first_job"):
## три карточки профессий расы героя (MenuKit.job_card) — арт профессии целиком (весь рост, 3:4, карточка по высоте
## окна), поверх низа на затемнении имя, роль и оружие одной строкой, кнопки «Подробнее» и «Выбрать»; часть пакета
## «art» не загружена — те же строки текстом и описание. «Подробнее» (или касание карточки) — вместо трёх карточек
## подробности (MenuKit.job_details: арт слева, справа описание, сильные стороны, особенности, ключевые умения со
## значками и уровнем, с прокруткой; «Назад», «Выбрать»). Окно не прокручивается — помещается при любом размере
## интерфейса. «Выбрать» — подтверждение под карточками («Сменить профессию позже нельзя», бонус сверх-эволюции
## ClassData.over_jp). «Да» — задание сдаётся (Quests.complete: награды), профессия меняется (Game.change_job:
## древо, стартовое оружие профессии в сумку и в руки), игрок пересчитывается, сообщение на экране.
## Закрыть окно без выбора можно — задание остаётся выполненным, вернуться к мудрецу можно в любой момент.
## Живёт в main (main.job_window). Кнопки открытого окна для тестов (buttons): "pick_<профессия>",
## "info_<профессия>" (на карточках), "back" (в подробностях), "confirm", "cancel"; detail — открытые подробности.

## Размер окна для «Среднего» размера интерфейса.
const WINDOW_SIZE := Vector2(1060, 600)
const GOLD := Color(1.0, 0.85, 0.45)
const MUTED := Color(0.78, 0.8, 0.9)
const GOOD := Color(0.55, 1.0, 0.6)

var main: Node
## Задание, при сдаче которого открыто окно ("" — без задания: только смена профессии).
var quest_id := ""
## Профессия, выбранная карточкой (ждёт подтверждения; "" — ещё не выбрана).
var picked := ""
## Профессия, чьи подробности открыты ("" — три карточки).
var detail := ""
var buttons: Dictionary = {}
var _body: VBoxContainer = null


func setup(m: Node) -> void:
	main = m


## Открыть выбор профессии для задания qid.
func open(qid: String = "") -> void:
	quest_id = qid
	picked = ""
	detail = ""
	_build()


func is_open() -> bool:
	if not is_instance_valid(_body):
		return false
	var n: Node = _body
	while n != null:
		if n.is_queued_for_deletion():
			return false
		n = n.get_parent()
	return main.hud.is_window_open()


func _build() -> void:
	buttons.clear()
	_body = main.hud.create_window("Выбор профессии", WINDOW_SIZE)
	# Во всю высоту окна: карточки занимают свободное место, прокрутки нет
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var over := ClassData.over_jp(Game.level)
	var head := "%s · ур. %d · Бродяга. Выберите одну из трёх профессий своей расы." % [
		String(ClassData.race(Game.race_id)["name"]), Game.level]
	_body.add_child(_label(head, UiScale.FONT_TEXT, MUTED))
	if over > 0:
		_body.add_child(_label("Сверх-эволюция: +%d очков умений (за уровни выше %d)" % [over, ClassData.JOB_LEVEL],
			UiScale.FONT_HEAD, GOOD))
	if detail != "" and ClassData.jobs_of(Game.race_id).has(detail):
		_details(detail)
	else:
		detail = ""
		var row := HBoxContainer.new()
		row.name = "JobRow"
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", int(UiScale.px(10)))
		_body.add_child(row)
		for jid in ClassData.jobs_of(Game.race_id):
			row.add_child(_card(String(jid)))
	if picked != "":
		_confirm_ui(over)


## Карточка профессии: арт во весь рост, имя, роль, оружие, «Подробнее» и «Выбрать».
func _card(job: String) -> Control:
	var col: Color = ClassData.cls(job)["color"]
	var cd := MenuKit.job_card(job, col.lightened(0.2), picked == job, col.lightened(0.5))
	var card := cd["card"] as PanelContainer
	card.gui_input.connect(_on_card_input.bind(job))
	var actions := cd["actions"] as HBoxContainer
	var info := MenuKit.card_button("Подробнее")
	info.pressed.connect(_on_info.bind(job))
	buttons["info_" + job] = info
	actions.add_child(info)
	var b := MenuKit.card_button("Выбрать")
	b.pressed.connect(_on_pick.bind(job))
	b.disabled = Game.job_change_block(job) != ""
	buttons["pick_" + job] = b
	actions.add_child(b)
	return cd["slot"] as Control


## Подробности профессии вместо трёх карточек: арт, полный текст с прокруткой, «Назад» и «Выбрать».
func _details(job: String) -> void:
	var col: Color = ClassData.cls(job)["color"]
	var d := MenuKit.job_details(job, col.lightened(0.2), col.lightened(0.5))
	_body.add_child(d["view"] as Control)
	var back := d["back"] as Button
	back.pressed.connect(_on_back)
	buttons["back"] = back
	var b := _button("Выбрать", "pick_" + job, _on_pick.bind(job))
	b.disabled = Game.job_change_block(job) != ""
	(d["actions"] as HBoxContainer).add_child(b)


func _confirm_ui(over: int) -> void:
	var q := "Стать: «%s»? Сменить профессию позже нельзя." % ClassData.job_name(picked)
	if over > 0:
		q += " Сверх-эволюция: +%d очков умений." % over
	_body.add_child(_label(q, UiScale.FONT_TEXT, GOLD))
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", int(UiScale.px(UiScale.GAP)))
	_body.add_child(r)
	r.add_child(_button("Да, выбрать", "confirm", _on_confirm))
	r.add_child(_button("Отмена", "cancel", _on_cancel))


func _on_pick(job: String) -> void:
	picked = job
	_build()


## «Подробнее» на карточке — подробности профессии вместо трёх карточек.
func _on_info(job: String) -> void:
	detail = job
	_build()


## «Назад» в подробностях — снова три карточки.
func _on_back() -> void:
	detail = ""
	_build()


## Касание карточки (не по кнопкам) — подробности.
func _on_card_input(e: InputEvent, job: String) -> void:
	var mb := e as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_on_info.call_deferred(job)


func _on_cancel() -> void:
	picked = ""
	_build()


## Подтверждение: сдать задание (награды) и сменить профессию.
func _on_confirm() -> void:
	choose(picked)


## Выбрать профессию job (сдача задания quest_id, если оно есть). true — профессия сменена.
func choose(job: String) -> bool:
	var why := Game.job_change_block(job)
	if why != "":
		main.hud.show_message(why)
		return false
	if quest_id != "" and main.get("quests") != null:
		if not main.quests.complete(quest_id):
			return false
	var over := Game.change_job(job)
	if over < 0:
		return false
	main.player.apply_class()
	main.hud.close_window()
	var text := "Новая профессия: %s! Древо умений открыто (окно героя, K)." % ClassData.job_name(job)
	if over > 0:
		text += " Сверх-эволюция: +%d очков умений." % over
	main.hud.show_message(text, 7.0)
	Vfx.level_up(main, main.player.global_position)
	Game.changed.emit()
	Game.save_game()
	return true


func _button(text: String, key: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(UiScale.px(150), UiScale.button_h())
	b.pressed.connect(cb)
	buttons[key] = b
	return b


func _label(text: String, font_size: int, col: Color, wrap_w: float = 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", UiScale.fs(font_size))
	l.add_theme_color_override("font_color", col)
	if wrap_w > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(wrap_w, 0)
	return l
