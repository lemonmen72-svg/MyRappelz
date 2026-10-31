class_name AdminPanel
extends RefCounted
## Админ-панель для тестирования (Максим на своём телефоне): кнопка «Админ» в окне «Настройки».
## Всё — через обычные функции Game / Player, сохранение не ломается:
##   раса и пол героя на лету (Game.admin_set_look → модель hero_<раса>_<пол>.glb, откат к героине);
##   профессия сразу — любая из 9 или Бродяга (Game.admin_set_job: умения прежней профессии сбрасываются с возвратом
##   JP, оружие профессии выдаётся и надевается; древо и кнопки HUD обновляются);
##   уровень героя 1…40 (−/+), «+100 JP», «Изучить все доступные умения», «Полное HP/MP»;
##   «Сбросить профессию в Бродягу» — заодно забывает задание мудреца «Первая профессия» (проверить задание
##   и сверх-эволюцию заново).
## Выключить панель — ADMIN_TOOLS = false (кнопка в «Настройках» пропадёт).
## Кнопки открытого окна для тестов (buttons): "race_<id>", "gender_<f|m>", "job_<id>", "lvl_minus", "lvl_plus",
## "lvl_plus5", "jp100", "learn_all", "full", "reset_job".

const ADMIN_TOOLS := true
## Размер окна для «Среднего» размера интерфейса.
const WINDOW_SIZE := Vector2(820, 590)
const MAX_LEVEL := 40
const NOTE := Color(1.0, 0.86, 0.55)
## Задание на профессию (сбрасывается вместе с профессией).
const JOB_QUEST := "sage_first_job"

static var buttons: Dictionary = {}


static func open(main: Node) -> void:
	if main == null or not is_instance_valid(main) or main.get("hud") == null or main.get("player") == null:
		return
	var hud: HUD = main.hud
	buttons.clear()
	var body := hud.create_window("Админ: тест героя", WINDOW_SIZE)
	var p: Player = main.player
	body.add_child(_text("%s · %s · %s · ур. %d · JP %d" % [ClassData.job_name(Game.class_id),
		String(ClassData.race(Game.race_id)["name"]), ClassData.gender_name(Game.gender).to_lower(), Game.level,
		int(Game.hero.get("jp", 0))], UiScale.FONT_HEAD, Color.WHITE))

	body.add_child(_text("Раса и пол (модель меняется сразу)", UiScale.FONT_TEXT, NOTE))
	var rr := _row(body)
	for rid in ClassData.RACES:
		var r := String(rid)
		_btn(rr, "race_" + r, String(ClassData.race(r)["name"]), r == Game.race_id,
			func() -> void: AdminPanel.set_look(main, r, Game.gender))
	for e in ClassData.GENDERS:
		var g := String(e[0])
		_btn(rr, "gender_" + g, String(e[1]), g == Game.gender, func() -> void: AdminPanel.set_look(main, Game.race_id, g))

	body.add_child(_text("Профессия (сразу, без задания; умения прежней — сброс с возвратом JP)", UiScale.FONT_TEXT, NOTE))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", int(UiScale.px(6)))
	grid.add_theme_constant_override("v_separation", int(UiScale.px(6)))
	body.add_child(grid)
	for jid in ClassData.CLASSES:
		var j := String(jid)
		var label := ClassData.job_name(j)
		var race := ClassData.job_race(j)
		if race != "" and race != Game.race_id:
			label += " *"
		_btn(grid, "job_" + j, label, j == Game.class_id, func() -> void: AdminPanel.set_job(main, j))
	body.add_child(_text("* — профессия другой расы (для теста можно).", UiScale.FONT_SMALL, Color(0.75, 0.78, 0.9)))

	body.add_child(_text("Уровень и ресурсы", UiScale.FONT_TEXT, NOTE))
	var lr := _row(body)
	_btn(lr, "lvl_minus", "Ур. −1", false, func() -> void: AdminPanel.set_level(main, Game.level - 1))
	_btn(lr, "lvl_plus", "Ур. +1", false, func() -> void: AdminPanel.set_level(main, Game.level + 1))
	_btn(lr, "lvl_plus5", "Ур. +5", false, func() -> void: AdminPanel.set_level(main, Game.level + 5))
	_btn(lr, "jp100", "+100 JP", false, func() -> void: AdminPanel.add_jp(main, 100))
	var ar := _row(body)
	_btn(ar, "learn_all", "Изучить все доступные", false, func() -> void: AdminPanel.learn_all(main))
	_btn(ar, "full", "Полное HP/MP", false, func() -> void: AdminPanel.full(main))
	_btn(ar, "reset_job", "Сбросить в Бродягу", false, func() -> void: AdminPanel.reset_job(main))
	body.add_child(_text("HP %d/%d · MP %d/%d" % [p.hp, p.max_hp, p.mp, p.max_mp], UiScale.FONT_BODY, Color(0.85, 0.88, 0.95)))


## Раса и пол героя: модель, деревня старта и возрождения.
static func set_look(main: Node, race: String, sex: String) -> void:
	Game.admin_set_look(race, sex)
	_apply(main, "Герой: %s, %s" % [String(ClassData.race(Game.race_id)["name"]), ClassData.gender_name(Game.gender).to_lower()])


## Профессия сразу (Game.admin_set_job).
static func set_job(main: Node, job: String) -> void:
	var back := Game.admin_set_job(job)
	var t := "Профессия: %s" % ClassData.job_name(job)
	if back > 0:
		t += " (возвращено %d JP)" % back
	_apply(main, t)


static func set_level(main: Node, lvl: int) -> void:
	Game.level = clampi(lvl, 1, MAX_LEVEL)
	Game.xp = 0
	_apply(main, "Уровень героя: %d" % Game.level)


static func add_jp(main: Node, n: int) -> void:
	Game.hero["jp"] = int(Game.hero.get("jp", 0)) + n
	_apply(main, "+%d JP" % n)


static func learn_all(main: Node) -> void:
	var n := HeroSkills.learn_all(Game.hero, Game.class_id, Game.level)
	_apply(main, "Изучено уровней умений: %d" % n)


static func full(main: Node) -> void:
	var p: Player = main.player
	p.hp = p.max_hp
	p.mp = p.max_mp
	p.stats_changed.emit()
	open(main)


## Профессия — Бродяга; задание мудреца на профессию можно пройти заново.
static func reset_job(main: Node) -> void:
	Game.quests_done.erase(JOB_QUEST)
	Game.quests_active.erase(JOB_QUEST)
	if Game.quest_tracked == JOB_QUEST:
		Game.quest_tracked = ""
	set_job(main, ClassData.WANDERER)
	if main.get("quests") != null:
		main.quests.refresh_tracker()


## После изменения: игрок пересчитан (модель, умения, оружие), HP/MP полные, кнопки HUD, сообщение, окно заново.
static func _apply(main: Node, msg: String) -> void:
	var p: Player = main.player
	p.apply_class()
	Game.changed.emit()
	main.hud.show_message(msg)
	open(main)


static func _row(body: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiScale.px(6)))
	body.add_child(row)
	return row


static func _btn(parent: Control, key: String, text: String, on: bool, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = on
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(UiScale.px(110), UiScale.button_h())
	b.add_theme_font_size_override("font_size", UiScale.fs(UiScale.FONT_BODY))
	b.pressed.connect(cb)
	parent.add_child(b)
	buttons[key] = b


static func _text(t: String, font_size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", UiScale.fs(font_size))
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
