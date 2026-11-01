class_name JobWindow
extends Node
## Окно выбора первой профессии (сдача задания «Доклад мудрецу» мудрецу, QuestData "sage_first_job"):
## три карточки профессий расы героя — арт профессии с названием внизу (MenuKit.job_art_head; часть пакета «art» не
## загружена — название строкой), роль, оружие, описание, 3–4 ключевых умения (значки и названия),
## кнопка «Выбрать»; затем подтверждение («Сменить профессию позже нельзя», бонус сверх-эволюции
## ClassData.over_jp). «Да» — задание сдаётся (Quests.complete: награды), профессия меняется (Game.change_job:
## древо, стартовое оружие профессии в сумку и в руки), игрок пересчитывается, сообщение на экране.
## Закрыть окно без выбора можно — задание остаётся выполненным, вернуться к мудрецу можно в любой момент.
## Живёт в main (main.job_window). Кнопки открытого окна для тестов (buttons): "pick_<профессия>", "confirm", "cancel".

## Размер окна для «Среднего» размера интерфейса.
const WINDOW_SIZE := Vector2(1060, 600)
const CARD_W := 330.0
## Арт профессии в карточке («Средний»): во всю ширину карточки, окно сверху.
const ART_H := 190.0
const GOLD := Color(1.0, 0.85, 0.45)
const MUTED := Color(0.78, 0.8, 0.9)
const GOOD := Color(0.55, 1.0, 0.6)

var main: Node
## Задание, при сдаче которого открыто окно ("" — без задания: только смена профессии).
var quest_id := ""
## Профессия, выбранная карточкой (ждёт подтверждения; "" — ещё не выбрана).
var picked := ""
var buttons: Dictionary = {}
var _body: VBoxContainer = null


func setup(m: Node) -> void:
	main = m


## Открыть выбор профессии для задания qid.
func open(qid: String = "") -> void:
	quest_id = qid
	picked = ""
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
	var over := ClassData.over_jp(Game.level)
	var head := "%s · ур. %d · Бродяга. Выберите одну из трёх профессий своей расы." % [
		String(ClassData.race(Game.race_id)["name"]), Game.level]
	_body.add_child(_label(head, UiScale.FONT_TEXT, MUTED))
	if over > 0:
		_body.add_child(_label("Сверх-эволюция: +%d очков умений (за уровни выше %d)" % [over, ClassData.JOB_LEVEL],
			UiScale.FONT_HEAD, GOOD))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiScale.px(10)))
	_body.add_child(row)
	for jid in ClassData.jobs_of(Game.race_id):
		row.add_child(_card(String(jid)))
	if picked != "":
		_confirm_ui(over)


## Карточка профессии: название, роль, оружие, описание, ключевые умения, «Выбрать».
func _card(job: String) -> Control:
	var c := ClassData.cls(job)
	var col: Color = c["color"]
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(UiScale.px(CARD_W), 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.14, 0.26, 0.95)
	sb.border_color = GOLD if picked == job else col.lightened(0.2)
	sb.set_border_width_all(3 if picked == job else 2)
	sb.set_corner_radius_all(int(UiScale.px(UiScale.BTN_RADIUS)))
	sb.set_content_margin_all(UiScale.px(10))
	panel.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(UiScale.px(3)))
	panel.add_child(box)
	var w := UiScale.px(CARD_W - 24.0)
	var head := MenuKit.job_art_head(job, Vector2(CARD_W - 24.0, ART_H), String(c["name"]), col.lightened(0.5),
		(CARD_W - 24.0) / ART_H)
	if head != null:
		box.add_child(head)
	else:
		box.add_child(_label(String(c["name"]), UiScale.FONT_NAME, col.lightened(0.4), w))
	box.add_child(_label("Роль: " + String(c["role"]), UiScale.FONT_BODY, MUTED, w))
	box.add_child(_label("Оружие: " + String(c["weapon_text"]), UiScale.FONT_BODY, MUTED, w))
	box.add_child(_label(String(c["desc"]), UiScale.FONT_SMALL, Color.WHITE, w))
	box.add_child(_label("Ключевые умения", UiScale.FONT_TEXT, GOLD, w))
	for sid in c.get("key_skills", []):
		var id := String(sid)
		var sk := HeroSkills.get_skill(id, job)
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", int(UiScale.px(6)))
		var ic := IconView.new()
		ic.custom_minimum_size = UiScale.v2(28, 28)
		ic.set_spec(IconView.hero_skill(id))
		r.add_child(ic)
		r.add_child(_label("%s (ур. %d)" % [String(sk.get("name", id)), HeroSkills.level_needed(id, 1, job)],
			UiScale.FONT_SMALL, Color(0.9, 0.9, 0.95)))
		box.add_child(r)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var b := _button("Выбрать", "pick_" + job, _on_pick.bind(job))
	b.disabled = Game.job_change_block(job) != ""
	box.add_child(b)
	return panel


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
