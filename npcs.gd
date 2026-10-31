class_name Npcs
extends Node
## Жители-NPC (NpcData) и разговор с ними. Ставит Учителя Кирка (Npc "kirk") в центре города рядом с торговцем —
## на свободное место (find_spot: проходимая ровная земля, не на дороге, не в постройке, не у торговца и точек
## старта). Торговца ставит Economy, здесь он только учитывается (значки заданий).
## Кнопка «Говорить» (HUD "talk", клавиша R) видна, когда игрок ближе TALK_RANGE к NPC с разговором;
## касание — окно диалога (HUD.create_window, тема Util.ui_theme): реплика NPC и варианты «Задания»,
## «Торговля» (окно торговли Economy с его товарами), «До встречи». Страница «Задания» — задания NPC
## (Quests.npc_quests): взять, посмотреть прогресс, сдать. Отошёл дальше — диалог закрывается.
## Значки над NPC («!», «?») — Quests.npc_mark, обновляются по Quests.updated и раз в MARK_PERIOD.
## Кнопки открытого диалога для тестов (buttons): "opt_quests", "opt_trade", "opt_bye", "dq_<id>", "accept",
## "complete", "back".

## Кнопка «Говорить» видна ближе этого расстояния, м; диалог закрывается дальше TALK_RANGE + 1.
const TALK_RANGE := 4.0
## Где хочется поставить Учителя Кирка: северо-запад площади, в ~8 м от торговца (Economy.MERCHANT_POS) —
## так их имена над головой не наползают друг на друга.
const KIRK_SPOT := Vector2(-7.5, -6.0)
## Свободно от оси дороги (половина ширины дороги + запас), м.
const ROAD_CLEAR := 3.2
## Не ближе к торговцу и точкам старта, м.
const KEEP_AWAY := 2.5
const DIALOG_SIZE := Vector2(940, 610)
const MARK_PERIOD := 0.3
const GOLD := Color(1.0, 0.85, 0.3)
const MUTED := Color(0.76, 0.78, 0.88)
const GOOD := Color(0.55, 1.0, 0.6)

var main: Node
## NPC по id: Npc (Учитель Кирк, торговец).
var nodes: Dictionary = {}
var kirk: Npc
## Открытый диалог: с кем, страница ("main" | "quests" | "quest"), задание на странице "quest".
var dialog_npc := ""
var page := ""
var page_quest := ""
## Реплика NPC в открытом диалоге.
var reply := ""
var buttons: Dictionary = {}

var _body: VBoxContainer = null
var _near_id := ""
var _mark_t := 0.0
## Реплика вместо обычной на следующей странице (слова NPC при сдаче задания).
var _say_next := ""


func setup(m: Node) -> void:
	main = m
	kirk = Npc.new()
	kirk.npc_id = "kirk"
	kirk.name = "Kirk"
	var avoid: Array = []
	var w := IslandWorld.current
	var eco: Economy = main.get("economy")
	if eco != null and eco.merchant != null:
		avoid.append(Vector2(eco.merchant.position.x, eco.merchant.position.z))
		nodes["merchant"] = eco.merchant
	if w != null:
		var sp: Dictionary = w.cfg.get("spawn_points", {})
		for key in sp:
			avoid.append(IslandWorld.v2(sp[key]))
	var p := find_spot(w, KIRK_SPOT, avoid)
	var y := w.height_at(p.x, p.y) if w != null else 0.0
	kirk.position = Vector3(p.x, y, p.y)
	# Лицом к центру площади (к игроку он повернётся сам)
	kirk.face_yaw = atan2(p.x, p.y)
	main.add_child(kirk)
	nodes["kirk"] = kirk
	main.hud.set_button_visible("talk", false)
	if main.get("quests") != null:
		main.quests.updated.connect(refresh_marks)
	refresh_marks()


## Обрабатывает действие "talk". true, если действие своё.
func handle_action(id: String) -> bool:
	if id != "talk":
		return false
	if is_dialog_open():
		close_dialog()
		return true
	var who := nearest_talker()
	if who != "":
		talk_to(who)
	else:
		_msg("Рядом не с кем поговорить")
	return true


# ---------- Место ----------

## Место для NPC рядом с want: проходимая ровная суша, не на дороге, не у воды, не в постройке
## (следы построек — poi_footprints), не ближе KEEP_AWAY к точкам avoid. Нет такого — want.
static func find_spot(w: IslandWorld, want: Vector2, avoid: Array) -> Vector2:
	if w == null:
		return want
	for rad in [0.0, 0.7, 1.4, 2.1, 2.8, 3.5, 4.5]:
		var r := float(rad)
		var steps := 1 if r == 0.0 else 12
		for k in steps:
			var a := TAU * float(k) / float(steps)
			var p := want + Vector2(cos(a), sin(a)) * r
			if spot_ok(w, p, avoid):
				return p
	return want


## Можно ли поставить NPC в точку p (см. find_spot).
static func spot_ok(w: IslandWorld, p: Vector2, avoid: Array) -> bool:
	if not w.is_walkable(p.x, p.y):
		return false
	if w.road_distance(p.x, p.y) < ROAD_CLEAR or w.water_distance(p.x, p.y) < 3.0:
		return false
	var h0 := w.height_at(p.x, p.y)
	for k in 8:
		var a := TAU * float(k) / 8.0
		var q := p + Vector2(cos(a), sin(a)) * 1.2
		if not w.is_walkable(q.x, q.y) or absf(w.height_at(q.x, q.y) - h0) > 0.35:
			return false
	var fps: Array = w.get_meta("poi_footprints", [])
	for f in fps:
		var fd: Dictionary = f
		var c: Vector2 = fd["c"]
		if p.distance_to(c) < float(fd["r"]) + 1.0:
			return false
	for e in avoid:
		var v: Vector2 = e
		if p.distance_to(v) < KEEP_AWAY:
			return false
	return true


# ---------- Рядом ли ----------

## Расстояние от игрока до NPC по земле (INF — нет игрока или NPC).
func distance_to(npc_id: String) -> float:
	var v: Variant = nodes.get(npc_id)
	if not is_instance_valid(v) or main == null or main.get("player") == null:
		return INF
	var n := v as Node3D
	if n == null or not n.is_inside_tree():
		return INF
	var d: Vector3 = main.player.global_position - n.global_position
	d.y = 0.0
	return d.length()


## Ближайший NPC с разговором ближе TALK_RANGE ("" — никого).
func nearest_talker() -> String:
	var best := ""
	var bd := TALK_RANGE
	for k in nodes:
		var id := String(k)
		if not NpcData.has_dialog(id):
			continue
		var d := distance_to(id)
		if d < bd:
			bd = d
			best = id
	return best


## Обновить значки заданий над NPC.
func refresh_marks() -> void:
	if main == null or main.get("quests") == null:
		return
	for k in nodes:
		var v: Variant = nodes[k]
		if not is_instance_valid(v):
			continue
		var n := v as Npc
		if n != null:
			n.set_mark(main.quests.npc_mark(String(k)))


# ---------- Диалог ----------

## Заговорить с NPC: событие для заданий «поговорить» и окно диалога на главной странице.
func talk_to(npc_id: String) -> void:
	if not NpcData.has_npc(npc_id):
		return
	if main.get("quests") != null:
		main.quests.on_talk(npc_id)
	open_dialog(npc_id)


## Открыть (перестроить) диалог с NPC на странице pg ("main" | "quests" | "quest"; для "quest" — задание qid).
func open_dialog(npc_id: String, pg: String = "main", qid: String = "") -> void:
	dialog_npc = npc_id
	page = pg
	page_quest = qid
	_build()


func close_dialog() -> void:
	if is_dialog_open():
		main.hud.close_window()
	_body = null
	dialog_npc = ""


func is_dialog_open() -> bool:
	if dialog_npc == "" or not is_instance_valid(_body):
		return false
	var n: Node = _body
	while n != null:
		if n.is_queued_for_deletion():
			return false
		n = n.get_parent()
	return main.hud.is_window_open()


## Приветствие NPC по положению дел с его заданиями.
func greeting(npc_id: String) -> String:
	var q: Quests = main.get("quests")
	var kind := "idle"
	if q != null:
		var ids := q.npc_quests(npc_id)
		for want in ["ready", "available", "active"]:
			for k in ids:
				if q.state(String(k)) == want and kind == "idle":
					kind = {"ready": "ready", "available": "offer", "active": "busy"}[want]
		if kind == "idle":
			for k in ids:
				if q.level_locked(String(k)):
					kind = "wait"
	return NpcData.greet(npc_id, kind)


func _build() -> void:
	buttons.clear()
	var q: Quests = main.get("quests")
	_body = main.hud.create_window(NpcData.npc_name(dialog_npc), DIALOG_SIZE)
	var sub := _label(String(NpcData.npc(dialog_npc).get("title", "")), 18, MUTED)
	_body.add_child(sub)
	match page:
		"quests":
			reply = _say_next if _say_next != "" else "Вот чем я могу тебя занять."
			if q == null or q.npc_quests(dialog_npc).is_empty():
				reply = _say_next if _say_next != "" else "Пока поручений нет. Загляни позже — у старого учителя всегда найдётся дело."
		"quest":
			reply = _quest_reply(page_quest)
		_:
			reply = greeting(dialog_npc)
	_say_next = ""
	_body.add_child(_speech(reply))
	match page:
		"quests":
			_page_quests()
		"quest":
			_page_quest()
		_:
			_page_main()


func _page_main() -> void:
	var q: Quests = main.get("quests")
	var opts := VBoxContainer.new()
	opts.add_theme_constant_override("separation", 8)
	_body.add_child(opts)
	var qt := "Задания"
	if q != null:
		match q.npc_mark(dialog_npc):
			"ready":
				qt += "  (?) — можно сдать"
			"offer":
				qt += "  (!) — есть новое"
	opts.add_child(_option(qt, "opt_quests", _on_quests))
	if NpcData.is_trader(dialog_npc):
		opts.add_child(_option("Торговля", "opt_trade", _on_trade))
	opts.add_child(_option("До встречи", "opt_bye", close_dialog))


func _page_quests() -> void:
	var q: Quests = main.get("quests")
	var opts := VBoxContainer.new()
	opts.add_theme_constant_override("separation", 8)
	_body.add_child(opts)
	if q != null:
		for k in q.npc_quests(dialog_npc):
			var id := String(k)
			var b: Button
			match q.state(id):
				"ready":
					b = _option("?  " + QuestData.quest_name(id) + " — сдать", "dq_" + id, _on_quest.bind(id))
					b.add_theme_color_override("font_color", Color(0.15, 0.45, 0.12))
				"available":
					b = _option("!  " + QuestData.quest_name(id), "dq_" + id, _on_quest.bind(id))
					b.add_theme_color_override("font_color", Color(0.5, 0.3, 0.0))
				"active":
					b = _option("…  " + QuestData.quest_name(id) + " — в процессе", "dq_" + id, _on_quest.bind(id))
				_:
					b = _option("%s — с %d уровня" % [QuestData.quest_name(id), int(QuestData.get_quest(id).get("level", 1))],
						"dq_" + id, _on_quest.bind(id))
					b.disabled = true
			opts.add_child(b)
	opts.add_child(_option("Назад", "back", _on_back))


func _page_quest() -> void:
	var q: Quests = main.get("quests")
	var id := page_quest
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_body.add_child(box)
	box.add_child(_label(QuestData.quest_name(id), 24, GOLD))
	var st := q.state(id) if q != null else "locked"
	var goals := QuestData.goals(id)
	for gi in goals.size():
		var g: Dictionary = goals[gi]
		var have := q.goal_progress(id, gi) if q != null else 0
		var done := q.goal_done(id, gi) if q != null else false
		box.add_child(QuestWindow.goal_row(g, have, done))
	box.add_child(_label("Награда", 20, GOLD))
	box.add_child(QuestWindow.reward_row(id))
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 10)
	_body.add_child(acts)
	match st:
		"available":
			acts.add_child(_option("Взять задание", "accept", _on_accept.bind(id)))
		"ready":
			acts.add_child(_option("Сдать задание", "complete", _on_complete.bind(id)))
	acts.add_child(_option("Назад", "back", _on_quests))


## Реплика NPC о задании: предложение, напоминание, похвала перед сдачей.
func _quest_reply(id: String) -> String:
	var q: Quests = main.get("quests")
	var d := QuestData.get_quest(id)
	var st := q.state(id) if q != null else ""
	match st:
		"available":
			return String(d.get("offer", ""))
		"active":
			return String(d.get("progress", ""))
		"ready":
			return NpcData.greet(dialog_npc, "ready")
		"done":
			return String(d.get("done", ""))
	var why := q.accept_block(id) if q != null else ""
	return "Не торопись. %s." % why if why != "" else String(d.get("offer", ""))


func _on_quests() -> void:
	open_dialog(dialog_npc, "quests")


func _on_back() -> void:
	open_dialog(dialog_npc, "main")


func _on_quest(id: String) -> void:
	open_dialog(dialog_npc, "quest", id)


func _on_trade() -> void:
	var who := dialog_npc
	close_dialog()
	if main.get("economy") != null:
		main.economy.open_shop(who)


func _on_accept(id: String) -> void:
	if main.quests.accept(id):
		open_dialog(dialog_npc, "quest", id)
	else:
		_build()


func _on_complete(id: String) -> void:
	if main.quests.complete(id):
		_say_next = String(QuestData.get_quest(id).get("done", ""))
		open_dialog(dialog_npc, "quests")
	else:
		_build()


# ---------- Кадр ----------

func _process(delta: float) -> void:
	if main == null or main.get("hud") == null or main.get("player") == null:
		return
	var near := nearest_talker()
	if near != _near_id:
		_near_id = near
		main.hud.set_button_visible("talk", near != "")
	if dialog_npc != "":
		if not is_dialog_open():
			dialog_npc = ""
		elif distance_to(dialog_npc) > TALK_RANGE + 1.0:
			var who := dialog_npc
			close_dialog()
			_msg("Вы отошли от %s" % NpcData.name_gen(who))
	_mark_t -= delta
	if _mark_t <= 0.0:
		_mark_t = MARK_PERIOD
		refresh_marks()


# ---------- Элементы ----------

## Реплика NPC в рамке.
func _speech(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "Speech"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.17, 0.75)
	sb.border_color = Color(0.98, 0.88, 0.6, 0.5)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(14)
	p.add_theme_stylebox_override("panel", sb)
	var l := _label("«%s»" % text, 22, Color.WHITE)
	l.name = "SpeechText"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(DIALOG_SIZE.x - 140.0, 0)
	p.add_child(l)
	return p


func _option(text: String, node_name: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.name = node_name
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(320, 56)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	buttons[node_name] = b
	return b


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _msg(t: String) -> void:
	main.hud.show_message(t)
