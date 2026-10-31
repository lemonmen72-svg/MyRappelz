class_name Quests
extends Node
## Задания как в MMORPG (данные — QuestData, состояние — Game.quests_active / quests_done / quest_tracked).
## Взять задание можно у NPC-выдающего (диалог — Npcs), если выполнены требования (уровень героя, предыдущее
## задание). Модуль принимает события игры и двигает прогресс целей:
##   убийство зверя (main._on_mob_gone → on_mob_killed: цели kill и pet_kill — если призван живой питомец),
##   душа поймана (Taming.soul_caught → tame), существо сформировано (Taming.formed → form),
##   питомец призван (PetManager.summoned → summon), покупка у NPC (Economy.bought → buy),
##   разговор с NPC (Npcs → on_talk → talk), сумка и уровень (Inventory.changed, Game.changed → collect, level).
## Сообщает на экране («Задание обновлено: Поймать душу 1/1», «… выполнено — вернитесь к Учителю Кирку»).
## Сдача (complete) — у NPC-сдающего: награды — опыт героя (Player.gain_xp: уровни и доля JP), золото, предметы
## (если не помещаются — «Освободите место в сумке», задание остаётся взятым), JP героя; предметы целей collect
## с take = true забираются.
## Журнал — QuestWindow (window; кнопка «Задания» в меню HUD, клавиша J), трекер отслеживаемого задания —
## компактный блок справа вверху под меню (tracker; касание — журнал). Значки над NPC — npc_mark (Npcs).

## Задание взято, сдано, прогресс изменился.
signal updated

## Ширина трекера на экране и отступ сверху (под кнопками меню), px.
const TRACKER_W := 330.0
const TRACKER_TOP := 84.0
const GOLD := Color(1.0, 0.85, 0.3)
const DONE_COLOR := Color(0.55, 1.0, 0.6)
const MUTED := Color(0.8, 0.82, 0.9)

var main: Node
## Журнал заданий.
var window: QuestWindow
## Трекер на экране (дочерний узел HUD).
var tracker: PanelContainer

var _tracker_box: VBoxContainer
var _last_level := -1


func setup(m: Node) -> void:
	main = m
	Game.inventory.changed.connect(_on_state_changed)
	Game.changed.connect(_on_state_changed)
	if main.get("taming") != null:
		main.taming.soul_caught.connect(on_tamed)
		main.taming.formed.connect(on_formed)
	if main.get("pets") != null:
		main.pets.summoned.connect(on_summoned)
	if main.get("economy") != null:
		main.economy.bought.connect(on_bought)
	window = QuestWindow.new()
	window.name = "QuestWindow"
	add_child(window)
	window.setup(main, self)
	_build_tracker()
	_last_level = Game.level
	_refresh_state_goals(false)
	refresh_tracker()


## Обрабатывает действие "quest_window" (журнал). true, если действие своё.
func handle_action(id: String) -> bool:
	if id == "quest_window":
		if window.is_open():
			window.close()
		else:
			window.open()
		return true
	return false


# ---------- Состояние ----------

## Состояние задания: "active" (взято), "ready" (все цели выполнены, можно сдать), "done" (сдано, не повторяется),
## "available" (можно взять), "locked" (требования не выполнены).
func state(id: String) -> String:
	if Game.quests_active.has(id):
		return "ready" if is_ready(id) else "active"
	if int(Game.quests_done.get(id, 0)) > 0 and not bool(QuestData.get_quest(id).get("repeatable", false)):
		return "done"
	return "available" if accept_block(id) == "" else "locked"


## Почему задание нельзя взять ("" — можно).
func accept_block(id: String) -> String:
	var q := QuestData.get_quest(id)
	if q.is_empty():
		return "Такого задания нет"
	if Game.quests_active.has(id):
		return "Задание уже взято"
	if int(Game.quests_done.get(id, 0)) > 0 and not bool(q.get("repeatable", false)):
		return "Задание уже выполнено"
	var prev := String(q.get("prev", ""))
	if prev != "" and int(Game.quests_done.get(prev, 0)) <= 0:
		return "Сначала выполните задание «%s»" % QuestData.quest_name(prev)
	var lvl := int(q.get("level", 1))
	if Game.level < lvl:
		return "Задание доступно с %d уровня" % lvl
	return ""


## Задание закрыто только уровнем героя (предыдущее сдано, не взято и не сдано).
func level_locked(id: String) -> bool:
	if state(id) != "locked":
		return false
	var q := QuestData.get_quest(id)
	var prev := String(q.get("prev", ""))
	if prev != "" and int(Game.quests_done.get(prev, 0)) <= 0:
		return false
	return Game.level < int(q.get("level", 1))


func is_active(id: String) -> bool:
	return Game.quests_active.has(id)


func is_done(id: String) -> bool:
	return int(Game.quests_done.get(id, 0)) > 0


## Сколько раз задание сдано.
func times_done(id: String) -> int:
	return int(Game.quests_done.get(id, 0))


## Прогресс целей взятого задания (копия; [] — не взято).
func progress(id: String) -> Array:
	if not Game.quests_active.has(id):
		return []
	return (_prog(id)).duplicate()


## Прогресс цели gi взятого задания (сдано — нужное число, не взято — 0).
func goal_progress(id: String, gi: int) -> int:
	var goals := QuestData.goals(id)
	if gi < 0 or gi >= goals.size():
		return 0
	if not Game.quests_active.has(id):
		return QuestData.goal_need(goals[gi]) if is_done(id) else 0
	var p := _prog(id)
	return int(p[gi]) if gi < p.size() else 0


func goal_done(id: String, gi: int) -> bool:
	var goals := QuestData.goals(id)
	return gi >= 0 and gi < goals.size() and goal_progress(id, gi) >= QuestData.goal_need(goals[gi])


## Все цели взятого задания выполнены.
func is_ready(id: String) -> bool:
	if not Game.quests_active.has(id):
		return false
	var goals := QuestData.goals(id)
	for gi in goals.size():
		if not goal_done(id, gi):
			return false
	return true


## Взятые задания (id в порядке взятия).
func active_ids() -> Array:
	return Game.quests_active.keys()


## Сданные задания (id в порядке сдачи).
func done_ids() -> Array:
	return Game.quests_done.keys()


## Значок над NPC: "ready" — у него можно сдать выполненное задание (золотой «?»), "offer" — у него есть задание,
## которое можно взять («!»), "active" — взятое у него задание ещё не выполнено (серый «?»), "" — ничего.
func npc_mark(npc_id: String) -> String:
	var best := ""
	for k in QuestData.all_ids():
		var id := String(k)
		var st := state(id)
		if st == "ready" and QuestData.turn_in(id) == npc_id:
			return "ready"
		if st == "available" and QuestData.giver(id) == npc_id:
			best = "offer"
		elif st == "active" and QuestData.turn_in(id) == npc_id and best == "":
			best = "active"
	return best


## Задания NPC для диалога: готовые к сдаче, доступные, взятые и следующее, закрытое уровнем.
func npc_quests(npc_id: String) -> Array:
	var order := ["ready", "available", "active", "level"]
	var res: Array = []
	for want in order:
		for k in QuestData.all_ids():
			var id := String(k)
			var st := state(id)
			var mine := QuestData.giver(id) == npc_id or QuestData.turn_in(id) == npc_id
			match want:
				"ready":
					if st == "ready" and QuestData.turn_in(id) == npc_id:
						res.append(id)
				"available":
					if st == "available" and QuestData.giver(id) == npc_id:
						res.append(id)
				"active":
					if st == "active" and mine:
						res.append(id)
				"level":
					if QuestData.giver(id) == npc_id and level_locked(id):
						res.append(id)
	return res


# ---------- Действия ----------

## Взять задание. true — взято. Цели-состояния (collect, level) и уже сделанное (counts_existing) засчитываются сразу.
func accept(id: String) -> bool:
	var why := accept_block(id)
	if why != "":
		_msg(why)
		return false
	var goals := QuestData.goals(id)
	var prog: Array = []
	for gi in goals.size():
		var g: Dictionary = goals[gi]
		var v := 0
		if QuestData.is_state_goal(g):
			v = _state_value(g)
		elif bool(g.get("counts_existing", false)):
			v = _existing(g)
		prog.append(mini(v, QuestData.goal_need(g)))
	Game.quests_active[id] = {"progress": prog}
	if Game.quest_tracked == "" or not Game.quests_active.has(Game.quest_tracked):
		Game.quest_tracked = id
	if is_ready(id):
		_msg_ready(id)
	else:
		_msg("Новое задание: «%s»" % QuestData.quest_name(id))
	_changed()
	Game.save_game()
	return true


## Отказаться от взятого задания (прогресс пропадает, задание можно взять снова).
func abandon(id: String) -> bool:
	if not Game.quests_active.has(id):
		return false
	Game.quests_active.erase(id)
	if Game.quest_tracked == id:
		Game.quest_tracked = _first_active()
	_msg("Вы отказались от задания «%s»" % QuestData.quest_name(id))
	_changed()
	return true


## Сдать выполненное задание: награды, предметы целей с take. true — сдано.
func complete(id: String) -> bool:
	if not Game.quests_active.has(id):
		_msg("Задание не взято")
		return false
	if not is_ready(id):
		_msg("Задание «%s» ещё не выполнено" % QuestData.quest_name(id))
		return false
	var items := QuestData.reward_items(id)
	if not Game.inventory.room_for_all(items):
		_msg("Освободите место в сумке: награда не помещается")
		return false
	var goals := QuestData.goals(id)
	Game.quests_active.erase(id)
	Game.quests_done[id] = times_done(id) + 1
	if Game.quest_tracked == id:
		Game.quest_tracked = _first_active()
	# Предметы целей «собрать» с take = true — забираем
	for g in goals:
		var gd: Dictionary = g
		if String(gd.get("type", "")) == "collect" and bool(gd.get("take", false)):
			var left := QuestData.goal_need(gd)
			for it in gd.get("items", []):
				var take_n := mini(left, Game.inventory.count(String(it)))
				if take_n > 0:
					Game.inventory.remove(String(it), take_n)
					left -= take_n
	var r := QuestData.rewards(id)
	var xp := int(r.get("xp", 0))
	var gold := int(r.get("gold", 0))
	var jp := int(r.get("jp", 0))
	Game.gold += gold
	for k in items:
		Game.inventory.add(String(k), int(items[k]))
	if jp > 0:
		HeroSkills.add_jp(Game.hero, float(jp))
	var p: Node3D = main.get("player")
	if xp > 0:
		if p != null and is_instance_valid(p):
			main.player.gain_xp(xp)
		else:
			Game.xp += xp
	if p != null and is_instance_valid(p):
		var text := "+%d оп." % xp if xp > 0 else ""
		if gold > 0:
			text += ("  " if text != "" else "") + "+%d зол." % gold
		if text != "":
			Util.float_text(main, p.global_position + Vector3(0, 3.0, 0), text, GOLD, 1.2)
		Vfx.level_up(main, p.global_position)
	_msg("Задание «%s» выполнено! Награда: %s" % [QuestData.quest_name(id), QuestData.reward_text(id)], 5.0)
	Game.changed.emit()
	_changed()
	Game.save_game()
	return true


## Отслеживать задание на экране ("" — ничего).
func track(id: String) -> void:
	Game.quest_tracked = id if Game.quests_active.has(id) else ""
	_changed()


# ---------- События игры ----------

## Зверь побеждён (игроком или питомцем): цели kill и pet_kill (pet_kill — только при призванном живом питомце).
func on_mob_killed(mob: Mob) -> void:
	if mob == null:
		return
	var sp := mob.type_id
	_event("kill", func(g: Dictionary) -> bool: return _species_ok(g, sp))
	if _pet_out():
		_event("pet_kill", func(g: Dictionary) -> bool: return _species_ok(g, sp))


## Душа зверя вида species поймана в карту.
func on_tamed(species: String) -> void:
	_event("tame", func(g: Dictionary) -> bool: return _species_ok(g, species))


## Сформировано существо вида species.
func on_formed(species: String) -> void:
	_event("form", func(g: Dictionary) -> bool: return _species_ok(g, species))


## Призван питомец вида species.
func on_summoned(species: String) -> void:
	_event("summon", func(g: Dictionary) -> bool: return _species_ok(g, species))


## Куплено n штук id у NPC seller.
func on_bought(id: String, n: int, seller: String) -> void:
	var fits := func(g: Dictionary) -> bool:
		var npc := String(g.get("npc", ""))
		var items: Array = g.get("items", [])
		return items.has(id) and (npc == "" or npc == seller)
	_event("buy", fits, n)


## Разговор с NPC npc_id (открыт диалог).
func on_talk(npc_id: String) -> void:
	_event("talk", func(g: Dictionary) -> bool: return String(g.get("npc", "")) == npc_id)


# ---------- Трекер ----------

## Перестроить трекер: название отслеживаемого задания и цели с прогрессом (нет задания — скрыт).
func refresh_tracker() -> void:
	if tracker == null:
		return
	for c in _tracker_box.get_children():
		_tracker_box.remove_child(c)
		c.queue_free()
	var id := Game.quest_tracked
	if not Game.quests_active.has(id):
		tracker.visible = false
		return
	tracker.visible = true
	var title := _label(QuestData.quest_name(id), 20, GOLD)
	title.name = "TrackerTitle"
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_tracker_box.add_child(title)
	var goals := QuestData.goals(id)
	for gi in goals.size():
		var g: Dictionary = goals[gi]
		var done := goal_done(id, gi)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ch := QuestWindow.Check.new()
		ch.done = done
		ch.custom_minimum_size = Vector2(16, 16)
		ch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ch)
		# Подпись в одну строку (длинная — с многоточием), прогресс справа: высота трекера постоянна
		var l := _label(QuestData.goal_text(g), 16, DONE_COLOR if done else Color.WHITE)
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var n := _label("%d/%d" % [goal_progress(id, gi), QuestData.goal_need(g)], 16, DONE_COLOR if done else GOLD)
		row.add_child(n)
		_tracker_box.add_child(row)
	if is_ready(id):
		_tracker_box.add_child(_label("Сдать: " + NpcData.npc_name(QuestData.turn_in(id)), 17, GOLD))
	_layout_tracker()


## Тексты трекера (для тестов): заголовок и строки целей.
func tracker_lines() -> Array:
	var res: Array = []
	if tracker == null or not tracker.visible:
		return res
	for l in _tracker_box.find_children("*", "Label", true, false):
		if not l.is_queued_for_deletion():
			res.append((l as Label).text)
	return res


## Касание трекера — журнал на отслеживаемом задании.
func open_tracked() -> void:
	window.open(Game.quest_tracked)


func _build_tracker() -> void:
	tracker = PanelContainer.new()
	tracker.name = "QuestTracker"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.16, 0.58)
	sb.border_color = Color(0.98, 0.88, 0.6, 0.55)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	tracker.add_theme_stylebox_override("panel", sb)
	tracker.mouse_filter = Control.MOUSE_FILTER_STOP
	tracker.custom_minimum_size = Vector2(TRACKER_W, 0)
	tracker.gui_input.connect(_on_tracker_input)
	_tracker_box = VBoxContainer.new()
	_tracker_box.add_theme_constant_override("separation", 2)
	_tracker_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tracker.add_child(_tracker_box)
	tracker.visible = false
	main.hud.add_child(tracker)
	main.hud.add_blocker(tracker)


## Трекер — справа вверху под кнопками меню; высота — по содержимому (каждый кадр: размер окна мог измениться).
func _layout_tracker() -> void:
	if tracker == null or not tracker.visible:
		return
	var vw := tracker.get_viewport_rect().size.x
	# Под меню HUD: высота кнопок меню зависит от шрифта, поэтому берём её край, а не только константу
	var top := TRACKER_TOP
	var hud := main.get("hud") as HUD if main != null else null
	if hud != null:
		top = maxf(top, hud.menu_rect().end.y + 8.0)
	tracker.position = Vector2(vw - TRACKER_W - 16.0, top)
	tracker.size = Vector2(TRACKER_W, 0.0)


func _process(_delta: float) -> void:
	_layout_tracker()


func _on_tracker_input(ev: InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		open_tracked()


# ---------- Внутреннее ----------

func _prog(id: String) -> Array:
	var rec: Dictionary = Game.quests_active[id]
	return rec["progress"]


## Событие для целей вида type: matcher(цель) решает, подходит ли цель; amount — сколько засчитать.
func _event(type: String, matcher: Callable, amount: int = 1) -> void:
	var any := false
	for k in Game.quests_active.keys():
		var id := String(k)
		var goals := QuestData.goals(id)
		var prog := _prog(id)
		var was_ready := is_ready(id)
		for gi in goals.size():
			var g: Dictionary = goals[gi]
			if String(g.get("type", "")) != type or gi >= prog.size() or not bool(matcher.call(g)):
				continue
			var need := QuestData.goal_need(g)
			var cur := int(prog[gi])
			if cur >= need:
				continue
			prog[gi] = mini(need, cur + maxi(1, amount))
			any = true
			_msg("Задание обновлено: %s %d/%d" % [QuestData.goal_text(g), int(prog[gi]), need])
		if not was_ready and is_ready(id):
			_msg_ready(id)
	if any:
		_changed()


## Пересчитать цели-состояния (collect — предметы в сумке, level — уровень героя). announce — сообщать.
func _refresh_state_goals(announce: bool) -> void:
	var any := false
	for k in Game.quests_active.keys():
		var id := String(k)
		var goals := QuestData.goals(id)
		var prog := _prog(id)
		var was_ready := is_ready(id)
		for gi in goals.size():
			var g: Dictionary = goals[gi]
			if not QuestData.is_state_goal(g) or gi >= prog.size():
				continue
			var need := QuestData.goal_need(g)
			var v := mini(_state_value(g), need)
			var old := int(prog[gi])
			if v == old:
				continue
			prog[gi] = v
			any = true
			if announce and v > old:
				_msg("Задание обновлено: %s %d/%d" % [QuestData.goal_text(g), v, need])
		if announce and not was_ready and is_ready(id):
			_msg_ready(id)
	if any:
		_changed()


func _on_state_changed() -> void:
	_refresh_state_goals(true)
	# Новый уровень может открыть задания — значки над NPC и журнал
	if Game.level != _last_level:
		_last_level = Game.level
		_changed()


## Текущее значение цели-состояния: collect — сколько предметов в сумке, level — уровень героя.
func _state_value(g: Dictionary) -> int:
	match String(g.get("type", "")):
		"collect":
			var n := 0
			for it in g.get("items", []):
				n += Game.inventory.count(String(it))
			return n
		"level":
			return Game.level
	return 0


## Сколько уже сделано до взятия (counts_existing): tame — карты с душой вида в сумке и существа вида
## в коллекции, form — существа в коллекции, summon — призванный питомец, buy — такие предметы в сумке.
func _existing(g: Dictionary) -> int:
	var t := String(g.get("target", ""))
	var pets_n := 0
	for rec in Game.pets:
		var r: Dictionary = rec
		if t == "" or String(r.get("species", "")) == t:
			pets_n += 1
	match String(g.get("type", "")):
		"tame":
			var n := pets_n
			for id in Game.inventory.ids():
				var it := String(id)
				if ItemData.is_soul_card(it) and (t == "" or ItemData.card_species(it) == t):
					n += Game.inventory.count(it)
			return n
		"form":
			return pets_n
		"summon":
			var i: int = Game.active_pet
			if i >= 0 and i < Game.pets.size() and not bool(Game.pets[i].get("dead", false)):
				if t == "" or String(Game.pets[i].get("species", "")) == t:
					return 1
			return 0
		"buy":
			var n := 0
			for it in g.get("items", []):
				n += Game.inventory.count(String(it))
			return n
	return 0


static func _species_ok(g: Dictionary, species: String) -> bool:
	var t := String(g.get("target", ""))
	return t == "" or t == species


## Призван живой питомец.
func _pet_out() -> bool:
	if main == null or main.get("pets") == null:
		return false
	var pm: PetManager = main.pets
	return is_instance_valid(pm.active_pet) and not pm.active_pet.is_down


func _first_active() -> String:
	for k in Game.quests_active:
		return String(k)
	return ""


func _msg_ready(id: String) -> void:
	_msg("Задание «%s» выполнено — вернитесь к %s" % [QuestData.quest_name(id), NpcData.name_dat(QuestData.turn_in(id))],
		5.0)


func _changed() -> void:
	refresh_tracker()
	if window != null and window.is_open():
		window.refresh()
	updated.emit()


func _msg(t: String, sec: float = 3.5) -> void:
	if main != null and main.get("hud") != null:
		main.hud.show_message(t, sec)


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
