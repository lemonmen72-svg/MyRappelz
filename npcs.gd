class_name Npcs
extends Node
## Жители-NPC (NpcData) и разговор с ними. Ставит Учителя Кирка (Npc "kirk") в центре города рядом с торговцем
## и остальных жителей по полю spot (NpcData.placed_ids: мудрец, кузнец и кладовщик по краям площади города,
## старосты у центров своих деревень, охотница в Западном лагере, глава наёмников на посту у входа в пещеру) —
## на свободное место (find_spot: проходимая ровная земля, не на дороге, не в постройке, не у других жителей
## и точек старта; жители лагеря и пещеры — внутри своей безопасной зоны). Торговца ставит Economy, здесь
## он только учитывается (значки заданий, отступ).
## Кнопка «Говорить» (HUD "talk", клавиша R) видна, когда игрок ближе TALK_RANGE к NPC с разговором (ближайший);
## касание — окно диалога (HUD.create_window, тема Util.ui_theme): реплика NPC и варианты «Задания» (если у NPC
## есть задания), «Торговля» (окно торговли Economy с его товарами), пункты о делах NPC (NpcData talk; дела,
## которых ещё нет, — «— скоро»: страница с рассказом, что будет; пункт с action открывает окно — «Склад»
## у кладовщика), «До встречи». Страница «Задания» — задания NPC (Quests.npc_quests): взять, посмотреть прогресс,
## сдать; два и больше доступных — ещё «Взять все». Отошёл дальше — диалог закрывается.
## Значки над NPC («!» — можно взять, «?» — взято, «=» — можно сдать) — Quests.npc_mark, обновляются по
## Quests.updated и раз в MARK_PERIOD; там же — красные значки над зверями-целями заданий (Quests.refresh_mob_marks).
## Кнопки открытого диалога для тестов (buttons): "opt_quests", "opt_trade", "opt_bye", "opt_<пункт talk>",
## "dq_<id>", "accept", "accept_all", "complete", "back".

## Значки пунктов о делах NPC в диалоге (id пункта NpcData talk → id значка UiIcons).
const DIALOG_ICONS := {"storage": "btn_storage", "forge": "btn_forge", "craft": "btn_craft"}

## Кнопка «Говорить» видна ближе этого расстояния, м; диалог закрывается дальше TALK_RANGE + 1.
const TALK_RANGE := 4.0
## Где хочется поставить Учителя Кирка: северо-запад площади, в ~8 м от торговца (Economy.MERCHANT_POS) —
## так их имена над головой не наползают друг на друга.
const KIRK_SPOT := Vector2(-7.5, -6.0)
## Свободно от оси дороги (половина ширины дороги + запас), м.
const ROAD_CLEAR := 3.2
## Кирк — не ближе к торговцу и точкам старта, м.
const KEEP_AWAY := 2.5
## Остальные жители — не ближе друг к другу, к торговцу, Кирку и точкам старта, м (с точки старта кнопки
## «Говорить» не видно: NPC_GAP > TALK_RANGE).
const NPC_GAP := 5.0
## Допустимый перепад высоты под ногами NPC (на 1.2 м от центра), м.
const FLAT := 0.35
## Радиусы поиска места вокруг желаемой точки, м.
const SEARCH_RADII := [0.0, 0.7, 1.4, 2.1, 2.8, 3.5, 4.5, 5.5, 6.5]
## Жители деревни или города стоят не дальше радиуса POI минус это, м.
const POI_MARGIN := 4.0
## Жители лагеря и пещеры стоят не дальше радиуса своей безопасной зоны минус это, м.
const ZONE_MARGIN := 1.0
## Окно диалога — для «Среднего» размера интерфейса (умножается на UiScale.k(); было 940×610).
const DIALOG_SIZE := Vector2(760, 520)
const MARK_PERIOD := 0.3
const GOLD := Color(1.0, 0.85, 0.3)
const MUTED := Color(0.76, 0.78, 0.88)
const GOOD := Color(0.55, 1.0, 0.6)
const SOON := Color(0.62, 0.66, 0.78)

var main: Node
## NPC по id: Npc (Учитель Кирк, торговец, жители из NpcData.placed_ids).
var nodes: Dictionary = {}
var kirk: Npc
## Открытый диалог: с кем, страница ("main" | "quests" | "quest" | "info"), задание на странице "quest",
## пункт о делах NPC на странице "info" (путь "guide" или "guide/pets").
var dialog_npc := ""
var page := ""
var page_quest := ""
var page_info := ""
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
	avoid.append(p)
	place_all(w, avoid)
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


## NPC по id (null — нет такого в мире).
func npc(id: String) -> Npc:
	var v: Variant = nodes.get(id)
	if not is_instance_valid(v):
		return null
	return v as Npc


# ---------- Место ----------

## Ставит жителей из NpcData.placed_ids по их полю spot. avoid — занятые точки (торговец, Кирк, точки старта);
## дополняется местами поставленных.
func place_all(w: IslandWorld, avoid: Array) -> void:
	for k in NpcData.placed_ids():
		var id := String(k)
		var info := spot_info(w, id)
		var want: Vector2 = info["want"]
		var area_c: Vector2 = info["area_c"]
		var p := find_spot(w, want, avoid, NPC_GAP, area_c, float(info["area_r"]), float(info["flat"]))
		var n := Npc.new()
		n.npc_id = id
		n.name = id.to_pascal_case()
		n.position = Vector3(p.x, w.height_at(p.x, p.y) if w != null else 0.0, p.y)
		var look: Vector2 = info["look"]
		if look.distance_to(p) < 0.5:
			look = p + Vector2(0, 1)
		# Лицом к точке look (модель смотрит в −Z; к игроку повернётся сама)
		n.face_yaw = atan2(p.x - look.x, p.y - look.y)
		main.add_child(n)
		nodes[id] = n
		avoid.append(p)


## Где хочется поставить жителя по его spot: {"want": Vector2, "area_c": Vector2, "area_r": float (0 — без
## ограничения), "look": Vector2, "flat": float, "base": Vector2 (центр POI или безопасной зоны)}.
static func spot_info(w: IslandWorld, id: String) -> Dictionary:
	var s := NpcData.spot(id)
	var base := Vector2.ZERO
	var area_c := Vector2.ZERO
	var area_r := 0.0
	if w != null:
		var zone := zone_cfg(w, String(s.get("zone", "")))
		var poi: Dictionary = w.poi(String(s.get("poi", "")))
		if not zone.is_empty():
			base = IslandWorld.v2(zone["center"])
			area_c = base
			area_r = float(zone.get("radius", 5.0)) - ZONE_MARGIN
		elif not poi.is_empty():
			base = IslandWorld.v2(poi["center"])
			area_c = base
			area_r = float(poi.get("radius", 16.0)) - POI_MARGIN
	var off: Vector2 = s.get("off", Vector2.ZERO)
	var look: Vector2 = s.get("look", Vector2.ZERO)
	return {"want": base + off, "area_c": area_c, "area_r": area_r, "look": base + look,
		"flat": float(s.get("flat", FLAT)), "base": base}


## Безопасная зона конфига острова по id ({} — нет).
static func zone_cfg(w: IslandWorld, id: String) -> Dictionary:
	if w == null or id == "":
		return {}
	for z in w.cfg.get("safe_zones", []):
		var d: Dictionary = z
		if String(d.get("id", "")) == id:
			return d
	return {}


## Место для NPC рядом с want: проходимая ровная суша, не на дороге, не у воды, не в постройке
## (следы построек — poi_footprints) и не в мелочах (poi_props), не ближе keep к точкам avoid, внутри круга area_c / area_r (если area_r > 0),
## перепад высоты под ногами не больше flat. Нет такого — want.
static func find_spot(w: IslandWorld, want: Vector2, avoid: Array, keep: float = KEEP_AWAY,
		area_c: Vector2 = Vector2.ZERO, area_r: float = 0.0, flat: float = FLAT) -> Vector2:
	if w == null:
		return want
	for rad in SEARCH_RADII:
		var r := float(rad)
		var steps := 1 if r == 0.0 else 12
		for k in steps:
			var a := TAU * float(k) / float(steps)
			var p := want + Vector2(cos(a), sin(a)) * r
			if area_r > 0.0 and p.distance_to(area_c) > area_r:
				continue
			if spot_ok(w, p, avoid, keep, flat):
				return p
	return want


## Можно ли поставить NPC в точку p (см. find_spot).
static func spot_ok(w: IslandWorld, p: Vector2, avoid: Array, keep: float = KEEP_AWAY, flat: float = FLAT) -> bool:
	if not w.is_walkable(p.x, p.y):
		return false
	if w.road_distance(p.x, p.y) < ROAD_CLEAR or w.water_distance(p.x, p.y) < 3.0:
		return false
	var h0 := w.height_at(p.x, p.y)
	for k in 8:
		var a := TAU * float(k) / 8.0
		var q := p + Vector2(cos(a), sin(a)) * 1.2
		if not w.is_walkable(q.x, q.y) or absf(w.height_at(q.x, q.y) - h0) > flat:
			return false
	var fps: Array = w.get_meta("poi_footprints", [])
	for f in fps:
		var fd: Dictionary = f
		var c: Vector2 = fd["c"]
		if p.distance_to(c) < float(fd["r"]) + 1.0:
			return false
	var props: Array = w.get_meta("poi_props", [])
	for f in props:
		var pd: Dictionary = f
		var pc: Vector2 = pd["c"]
		if p.distance_to(pc) < float(pd["r"]) + 0.6:
			return false
	for e in avoid:
		var v: Vector2 = e
		if p.distance_to(v) < keep:
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
	# Красные значки над зверями — целями взятых заданий (новые звери появляются — тоже здесь)
	main.quests.refresh_mob_marks()


# ---------- Диалог ----------

## Заговорить с NPC: событие для заданий «поговорить» и окно диалога на главной странице.
func talk_to(npc_id: String) -> void:
	if not NpcData.has_npc(npc_id):
		return
	if main.get("quests") != null:
		main.quests.on_talk(npc_id)
	open_dialog(npc_id)


## Открыть (перестроить) диалог с NPC на странице pg ("main" | "quests" | "quest" | "info"; для "quest" —
## задание qid, для "info" — путь пункта о делах NPC в qid: "forge", "guide/pets").
func open_dialog(npc_id: String, pg: String = "main", qid: String = "") -> void:
	# Новый разговор — житель машет рукой (если только что не махал при приближении)
	if dialog_npc != npc_id or not is_dialog_open():
		var n := npc(npc_id)
		if n != null:
			n.greet()
	dialog_npc = npc_id
	page = pg
	page_quest = qid if pg == "quest" else ""
	page_info = qid if pg == "info" else ""
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


## Приветствие NPC по положению дел с его заданиями, а если о них сказать нечего — по положению героя.
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
	if kind == "idle":
		kind = situation(npc_id)
	return NpcData.greet(npc_id, kind)


## Вид реплики по положению героя (см. NpcData greet): "young" | "veteran" | "kin" | "full_bag" | "idle" —
## первый подходящий из тех, что есть у NPC.
static func situation(npc_id: String) -> String:
	var d := NpcData.npc(npc_id)
	if NpcData.has_greet(npc_id, "young") and Game.level < int(d.get("young_below", 0)):
		return "young"
	if NpcData.has_greet(npc_id, "veteran") and d.has("veteran_from") and Game.level >= int(d["veteran_from"]):
		return "veteran"
	if NpcData.has_greet(npc_id, "kin"):
		if (d.has("race") and String(d["race"]) == Game.race_id) or (d.has("class") and String(d["class"]) == Game.class_id):
			return "kin"
	if NpcData.has_greet(npc_id, "full_bag") and Game.inventory.used_cells() >= Inventory.CAPACITY - 4:
		return "full_bag"
	return "idle"


## Есть ли у NPC задания (выдаёт или принимает хоть одно) — пункт «Задания» в диалоге.
static func gives_quests(npc_id: String) -> bool:
	for k in QuestData.all_ids():
		var id := String(k)
		if QuestData.giver(id) == npc_id or QuestData.turn_in(id) == npc_id:
			return true
	return false


func _build() -> void:
	buttons.clear()
	var q: Quests = main.get("quests")
	_body = main.hud.create_window(NpcData.npc_name(dialog_npc), DIALOG_SIZE)
	var sub := _label(String(NpcData.npc(dialog_npc).get("title", "")), UiScale.FONT_BODY, MUTED)
	_body.add_child(sub)
	match page:
		"quests":
			reply = _say_next if _say_next != "" else "Вот чем я могу тебя занять."
			if q == null or q.npc_quests(dialog_npc).is_empty():
				reply = _say_next if _say_next != "" else NpcData.no_quests(dialog_npc)
		"quest":
			reply = _quest_reply(page_quest)
		"info":
			reply = String(NpcData.talk_entry(dialog_npc, page_info).get("text", ""))
		_:
			reply = greeting(dialog_npc)
	_say_next = ""
	_body.add_child(_speech(reply))
	match page:
		"quests":
			_page_quests()
		"quest":
			_page_quest()
		"info":
			_page_info()
		_:
			_page_main()


func _page_main() -> void:
	var q: Quests = main.get("quests")
	var opts := VBoxContainer.new()
	opts.add_theme_constant_override("separation", int(UiScale.px(6)))
	_body.add_child(opts)
	if gives_quests(dialog_npc):
		var qt := "Задания"
		if q != null:
			match q.npc_mark(dialog_npc):
				"ready":
					qt += "  (=) — можно сдать"
				"offer":
					qt += "  (!) — есть новое"
		var qb := _option(qt, "opt_quests", _on_quests)
		UiIcons.add_icon(qb, "menu_quests")
		opts.add_child(qb)
	if NpcData.is_trader(dialog_npc):
		var tb := _option("Торговля", "opt_trade", _on_trade)
		UiIcons.add_icon(tb, "btn_merchant")
		opts.add_child(tb)
	for e in NpcData.talk_options(dialog_npc):
		var d: Dictionary = e
		var id := String(d.get("id", ""))
		var action := String(d.get("action", ""))
		var b := _option(NpcData.talk_label(d), "opt_" + id,
			_on_npc_action.bind(action) if action != "" else _on_info.bind(id))
		if bool(d.get("soon", false)):
			b.add_theme_color_override("font_color", SOON)
		# Значки дел (UiIcons): склад, кузница
		if DIALOG_ICONS.has(id):
			UiIcons.add_icon(b, String(DIALOG_ICONS[id]))
		opts.add_child(b)
	opts.add_child(_option("До встречи", "opt_bye", close_dialog))


## Страница пункта о делах NPC: рассказ (реплика), вложенные пункты (справочник мудреца) и «Назад».
func _page_info() -> void:
	var entry := NpcData.talk_entry(dialog_npc, page_info)
	var topics: Array = entry.get("topics", [])
	if not topics.is_empty():
		# Пункты справочника — в две колонки, чтобы окно не вытягивалось
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", int(UiScale.px(6)))
		grid.add_theme_constant_override("v_separation", int(UiScale.px(6)))
		_body.add_child(grid)
		for t in topics:
			var td: Dictionary = t
			var tid := String(td.get("id", ""))
			grid.add_child(_option(NpcData.talk_label(td), "opt_" + tid, _on_info.bind(page_info + "/" + tid)))
	var back := page_info.get_base_dir() if page_info.contains("/") else ""
	_body.add_child(_option("Назад", "back", _on_info_back.bind(back)))


func _page_quests() -> void:
	var q: Quests = main.get("quests")
	var opts := VBoxContainer.new()
	opts.add_theme_constant_override("separation", int(UiScale.px(6)))
	_body.add_child(opts)
	if q != null:
		var avail := 0
		for k in q.npc_quests(dialog_npc):
			if q.state(String(k)) == "available":
				avail += 1
		if avail >= 2:
			opts.add_child(_option("Взять все задания (%d)" % avail, "accept_all", _on_accept_all))
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
	box.add_theme_constant_override("separation", int(UiScale.px(5)))
	_body.add_child(box)
	box.add_child(_label(QuestData.quest_name(id), UiScale.FONT_HEAD, GOLD))
	var st := q.state(id) if q != null else "locked"
	var goals := QuestData.goals(id)
	for gi in goals.size():
		var g: Dictionary = goals[gi]
		var have := q.goal_progress(id, gi) if q != null else 0
		var done := q.goal_done(id, gi) if q != null else false
		box.add_child(QuestWindow.goal_row(g, have, done))
	box.add_child(_label("Награда", UiScale.FONT_TEXT, GOLD))
	box.add_child(QuestWindow.reward_row(id))
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", int(UiScale.px(UiScale.GAP)))
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
	var st := q.state(id) if q != null else ""
	match st:
		"available":
			return QuestData.text(id, "offer")
		"active":
			return QuestData.text(id, "progress")
		"ready":
			return NpcData.greet(dialog_npc, "ready")
		"done":
			return QuestData.text(id, "done")
	var why := q.accept_block(id) if q != null else ""
	return "Не торопись. %s." % why if why != "" else QuestData.text(id, "offer")


func _on_quests() -> void:
	open_dialog(dialog_npc, "quests")


func _on_back() -> void:
	open_dialog(dialog_npc, "main")


func _on_info(path: String) -> void:
	open_dialog(dialog_npc, "info", path)


func _on_info_back(path: String) -> void:
	if path == "":
		open_dialog(dialog_npc, "main")
	else:
		open_dialog(dialog_npc, "info", path)


func _on_quest(id: String) -> void:
	open_dialog(dialog_npc, "quest", id)


## Пункт о делах NPC, который открывает окно (action): "storage" — склад кладовщика.
func _on_npc_action(action: String) -> void:
	match action:
		"storage":
			close_dialog()
			if main.get("economy") != null:
				main.economy.open_storage()


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


## «Взять все задания»: все доступные у этого NPC.
func _on_accept_all() -> void:
	var q: Quests = main.quests
	var n := 0
	for k in q.npc_quests(dialog_npc):
		var id := String(k)
		if q.state(id) == "available" and q.accept(id):
			n += 1
	if n > 1:
		_msg("Взято заданий: %d — журнал (J)" % n)
	open_dialog(dialog_npc, "quests")


func _on_complete(id: String) -> void:
	# Задание на профессию: сдача — в окне выбора профессии (JobWindow)
	if bool(QuestData.get_quest(id).get("job_choice", false)) and main.get("job_window") != null:
		close_dialog()
		main.job_window.open(id)
		return
	if main.quests.complete(id):
		_say_next = QuestData.text(id, "done")
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
	sb.set_corner_radius_all(int(UiScale.px(UiScale.BTN_RADIUS)))
	sb.set_content_margin_all(UiScale.px(UiScale.PAD))
	p.add_theme_stylebox_override("panel", sb)
	var l := _label("«%s»" % text, UiScale.FONT_TEXT + 1, Color.WHITE)
	l.name = "SpeechText"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(UiScale.px(DIALOG_SIZE.x - 90.0), 0)
	p.add_child(l)
	return p


func _option(text: String, node_name: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.name = node_name
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(UiScale.px(280), UiScale.button_h())
	b.add_theme_font_size_override("font_size", UiScale.fs(UiScale.FONT_TEXT + 1))
	b.pressed.connect(cb)
	buttons[node_name] = b
	return b


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


func _msg(t: String) -> void:
	main.hud.show_message(t)
