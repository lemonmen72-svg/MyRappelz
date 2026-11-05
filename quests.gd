class_name Quests
extends Node
## Задания как в MMORPG (данные — QuestData, состояние — Game.quests_active / quests_done / quest_tracked).
## Взять задание можно у NPC-выдающего (диалог — Npcs), если выполнены требования (уровень героя, предыдущее
## задание). Модуль принимает события игры и двигает прогресс целей:
##   убийство зверя (main._on_mob_gone → on_mob_killed: цели kill и pet_kill — если призван живой питомец),
##   душа поймана (Taming.soul_caught → tame), существо сформировано (Taming.formed → form),
##   питомец призван (PetManager.summoned → summon), покупка у NPC (Economy.bought → buy), продажа NPC
##   (Economy.sold → sell), выпито зелье (Economy.used → use), вещь положена на склад (Economy.stored → store),
##   разговор с NPC (Npcs → on_talk → talk), сумка, уровень, умения и снаряжение (Inventory.changed, Game.changed
##   и опрос раз в POLL с — collect, level, skill, equip, upgrade, pet_gear, gather, quest), умения питомцев (опрос:
##   сумма изученных уровней выросла → pet_skill). Квестовая добыча: пока цель collect с drop_from не выполнена,
##   Economy кладёт её предмет в мешочек с каждого такого зверя (quest_loot).
## Находки (цель gather): пока цель не выполнена, в её зоне зверей лежат FIND_COUNT светящихся трав (QuestFind);
##   подошёл ближе QuestFind.PICK_RANGE — трава в сумке, новая вырастет через FIND_RESPAWN с.
## Суточные задания (cooldown): после сдачи берутся снова через cooldown с настоящего времени (Game.quests_time,
##   QuestData.now); заказ писаря (gen) — цели и награда выбираются при взятии (generate) и хранятся в записи.
## Сообщает на экране («Задание обновлено: Поймать душу 1/1», «… выполнено — вернитесь к Учителю Кирку»).
## Сдача (complete) — у NPC-сдающего: награды — опыт героя (Player.gain_xp: уровни и доля JP), золото, предметы
## (если не помещаются — «Освободите место в сумке», задание остаётся взятым), JP героя; предметы целей collect
## с take = true забираются. Сверх того — 1–2 случайных предмета (правило Максима; LootTable.quest_reward: зелья,
## оружие и броня для профессии, украшения, карта существа — с шансами вдвое ниже, чем в добыче, ранг по уровню
## героя); что выпало —
## в сообщении о сдаче и в last_bonus.
## Журнал — QuestWindow (window; кнопка «Задания» в меню HUD, клавиша J), трекер отслеживаемого задания —
## компактный блок справа вверху под меню (tracker; касание — журнал). Значки над NPC — npc_mark (Npcs), красные
## значки над зверями-целями — target_species / refresh_mob_marks (Mob.set_quest_target).

## Задание взято, сдано, прогресс изменился.
signal updated

## Ширина трекера на экране и отступ сверху (под кнопками меню), px — для «Среднего» размера интерфейса
## (умножаются на UiScale.k(); было 330 / 84).
const TRACKER_W := 270.0
const TRACKER_TOP := 60.0
const GOLD := Color(1.0, 0.85, 0.3)
const DONE_COLOR := Color(0.55, 1.0, 0.6)
const MUTED := Color(0.8, 0.82, 0.9)
## Опрос состояния (снаряжение, умения питомцев, находки), с.
const POLL := 0.5
## Находок одной цели gather в зоне сразу; через сколько секунд после сбора вырастают новые.
const FIND_COUNT := 5
const FIND_RESPAWN := 12.0
## Находки не ближе этого друг к другу, м.
const FIND_GAP := 3.0
## Узел находки (quest_find.gd, класс QuestFind) — через preload: так модуль не зависит от кэша глобальных классов.
const FindScript := preload("res://quest_find.gd")

var main: Node
## Журнал заданий.
var window: QuestWindow
## Трекер на экране (дочерний узел HUD).
var tracker: PanelContainer

var _tracker_box: VBoxContainer
var _last_level := -1
## Случайные предметы последней сдачи {id: количество} (сообщение, тесты).
var last_bonus: Dictionary = {}
## Генератор заказов писаря (тесты подставляют свой; null — случайный).
var gen_rng: RandomNumberGenerator = null

var _poll_t := 0.0
## Сумма изученных уровней умений всех питомцев при прошлом опросе (рост — событие pet_skill).
var _pet_skill_sum := 0
## Находки: ключ цели ("<предмет>@<зона>") → сколько секунд до новых.
var _find_cd: Dictionary = {}
var _rng := RandomNumberGenerator.new()


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
		main.economy.sold.connect(on_sold)
		main.economy.used.connect(on_used)
		main.economy.stored.connect(on_stored)
	window = QuestWindow.new()
	window.name = "QuestWindow"
	add_child(window)
	window.setup(main, self)
	_build_tracker()
	_last_level = Game.level
	_pet_skill_sum = pet_skill_sum()
	_rng.randomize()
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
## Сданное повторяемое на перезарядке (cooldown_left > 0) — "locked".
func state(id: String) -> String:
	if Game.quests_active.has(id):
		return "ready" if is_ready(id) else "active"
	if int(Game.quests_done.get(id, 0)) > 0 and not bool(QuestData.get_quest(id).get("repeatable", false)):
		return "done"
	return "available" if accept_block(id) == "" else "locked"


## Сколько секунд до того, как сданное суточное задание можно взять снова (0 — можно или перезарядки нет).
func cooldown_left(id: String) -> float:
	var cd := QuestData.cooldown(id)
	if cd <= 0.0 or times_done(id) <= 0:
		return 0.0
	return maxf(0.0, float(Game.quests_time.get(id, 0.0)) + cd - QuestData.now())


## Время словами: «5 ч 20 мин», «12 мин».
static func time_text(sec: float) -> String:
	var m := int(ceil(sec / 60.0))
	if m >= 60:
		return "%d ч %d мин" % [m / 60, m % 60]
	return "%d мин" % maxi(1, m)


## Носит ли профессия что-то во второй руке (щит или пару клинков).
static func can_offhand(class_id: String) -> bool:
	var w := ClassData.weapons(class_id)
	for k in ["shield", "daggers", "dual_swords", "dual_axes"]:
		if w.has(k):
			return true
	return false


## Почему задание нельзя взять ("" — можно).
func accept_block(id: String) -> String:
	var q := QuestData.get_quest(id)
	if q.is_empty():
		return "Такого задания нет"
	if Game.quests_active.has(id):
		return "Задание уже взято"
	if int(Game.quests_done.get(id, 0)) > 0 and not bool(q.get("repeatable", false)):
		return "Задание уже выполнено"
	for p in QuestData.prereqs(id):
		if not prereq_done(String(p)):
			return "Сначала выполните задание «%s»" % QuestData.quest_name(String(p))
	if bool(q.get("wanderer_only", false)) and not ClassData.is_wanderer(Game.class_id):
		return "Профессия уже выбрана"
	if bool(q.get("job_only", false)) and ClassData.is_wanderer(Game.class_id):
		return "Сначала выберите профессию"
	if bool(q.get("offhand_only", false)) and not can_offhand(Game.class_id):
		return "Ваша профессия не носит щит или второй клинок"
	var wa := String(q.get("while_active", ""))
	if wa != "" and not Game.quests_active.has(wa):
		return "Сначала возьмите задание «%s»" % QuestData.quest_name(wa)
	var left := cooldown_left(id)
	if left > 0.0:
		return "Снова можно взять через %s" % time_text(left)
	var lvl := int(q.get("level", 1))
	if Game.level < lvl:
		return "Задание доступно с %d уровня" % lvl
	return ""


## Задание закрыто только уровнем героя (предыдущее сдано, не взято и не сдано).
func level_locked(id: String) -> bool:
	if state(id) != "locked":
		return false
	var q := QuestData.get_quest(id)
	for p in QuestData.prereqs(id):
		if not prereq_done(String(p)):
			return false
	if bool(q.get("wanderer_only", false)) and not ClassData.is_wanderer(Game.class_id):
		return false
	if bool(q.get("job_only", false)) and ClassData.is_wanderer(Game.class_id):
		return false
	if bool(q.get("offhand_only", false)) and not can_offhand(Game.class_id):
		return false
	var wa := String(q.get("while_active", ""))
	if (wa != "" and not Game.quests_active.has(wa)) or cooldown_left(id) > 0.0:
		return false
	return Game.level < int(q.get("level", 1))


## Условие «сначала сдать задание id» выполнено. Задание на профессию засчитано и у героя, получившего профессию
## иначе (админ-панель, автотесты, старые сохранения) — цепочка после профессии не застревает.
func prereq_done(id: String) -> bool:
	if is_done(id):
		return true
	return id == QuestData.JOB_QUEST and Game.job_changed and not ClassData.is_wanderer(Game.class_id)


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


## Значок над NPC: "ready" — у него можно сдать выполненное задание («=»), "offer" — у него есть задание,
## которое можно взять («!»), "active" — взятое задание, которое сдавать ему, ещё не выполнено («?»), "" — ничего.
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


## Значки над всеми NPC сразу: {npc_id: "ready" | "offer" | "active"} (как npc_mark, но состояние каждого задания
## считается один раз — Npcs.refresh_marks зовёт это раз в MARK_PERIOD: по npc_mark для каждого из 17 жителей
## выходило 1000 вызовов state(), ≈ 7.5 мс на ПК — заминка каждые 0.3 с).
func npc_marks() -> Dictionary:
	var res: Dictionary = {}
	for k in QuestData.all_ids():
		var id := String(k)
		var st := state(id)
		if st == "ready":
			res[QuestData.turn_in(id)] = "ready"
		elif st == "available":
			var g := QuestData.giver(id)
			if String(res.get(g, "")) != "ready":
				res[g] = "offer"
		elif st == "active":
			var t := QuestData.turn_in(id)
			if String(res.get(t, "")) == "":
				res[t] = "active"
	return res


## Звери — цели взятых заданий: {вид зверя: наименьший уровень} по невыполненным целям kill (вид задан, с min_level)
## и collect с drop_from (квестовая добыча). Цели «любой зверь» (target "") и pet_kill не в счёт — иначе значок
## был бы над каждым зверем.
func target_species() -> Dictionary:
	var res: Dictionary = {}
	for k in Game.quests_active.keys():
		var id := String(k)
		var goals := QuestData.goals(id)
		for gi in goals.size():
			var g: Dictionary = goals[gi]
			if goal_done(id, gi):
				continue
			var sp := ""
			var lvl := 0
			var list: Array = []
			match String(g.get("type", "")):
				"kill":
					list = QuestData.goal_species(g)
					lvl = int(g.get("min_level", 0))
				"collect":
					sp = String(g.get("drop_from", ""))
					if sp != "":
						list = [sp]
			for e in list:
				res[String(e)] = mini(int(res.get(String(e), lvl)), lvl)
	return res


## Нужен ли зверь (вид species, уровень lvl) по взятому заданию — красный значок над ним.
func is_mob_target(species: String, lvl: int, targets: Dictionary = {}) -> bool:
	var t := targets if not targets.is_empty() else target_species()
	return t.has(species) and lvl >= int(t[species])


## Обновить красные значки над зверями (Mob.set_quest_target): по Quests.updated и раз в Npcs.MARK_PERIOD.
func refresh_mob_marks() -> void:
	if not is_inside_tree():
		return
	var t := target_species()
	for n in get_tree().get_nodes_in_group("mobs"):
		var m := n as Mob
		if m != null and not m.is_dead:
			m.set_quest_target(t.has(m.type_id) and m.level >= int(t[m.type_id]))


## Задания NPC для диалога: готовые к сдаче, доступные, взятые, следующее, закрытое уровнем, и суточные
## на перезарядке («снова через …»).
func npc_quests(npc_id: String) -> Array:
	var order := ["ready", "available", "active", "level", "later"]
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
				"later":
					if QuestData.giver(id) == npc_id and st == "locked" and cooldown_left(id) > 0.0:
						res.append(id)
	return res


# ---------- Действия ----------

## Взять задание. true — взято. Цели-состояния (collect, level) и уже сделанное (counts_existing) засчитываются сразу.
func accept(id: String) -> bool:
	var why := accept_block(id)
	if why != "":
		_msg(why)
		return false
	# Выдать при взятии то, без чего задание не сделать (зелье для «выпей зелье»), если в сумке меньше
	var given: Array = []
	var give: Dictionary = QuestData.get_quest(id).get("give", {})
	for k in give:
		var gid := String(k)
		var miss := int(give[k]) - Game.inventory.count(gid)
		if miss > 0:
			Game.inventory.add(gid, miss)
			given.append("%s ×%d" % [ItemData.item_name(gid), miss])
	var talking := _talking_to()
	# Заказ писаря: цели и награда — при взятии, в записи задания (QuestData.goals / rewards читают её)
	var rec: Dictionary = {"progress": []}
	if QuestData.get_quest(id).has("gen"):
		var gen := generate(id)
		rec["goals"] = gen["goals"]
		rec["rewards"] = gen["rewards"]
	Game.quests_active[id] = rec
	# Умения питомцам — в счёт только изученные после взятия
	_pet_skill_sum = pet_skill_sum()
	var goals := QuestData.goals(id)
	var prog: Array = []
	for gi in goals.size():
		var g: Dictionary = goals[gi]
		var v := 0
		if QuestData.is_state_goal(g):
			v = _state_value(g)
		elif bool(g.get("counts_existing", false)):
			v = _existing(g)
		elif String(g.get("type", "")) == "talk" and talking != "" and QuestData.goal_npc(g) == talking:
			# Задание взято в разговоре с тем, с кем нужно поговорить
			v = 1
		prog.append(mini(v, QuestData.goal_need(g)))
	rec["progress"] = prog
	if Game.quest_tracked == "" or not Game.quests_active.has(Game.quest_tracked):
		Game.quest_tracked = id
	if is_ready(id):
		_msg_ready(id)
	elif not given.is_empty():
		_msg("Новое задание: «%s». Получено: %s" % [QuestData.quest_name(id), ", ".join(PackedStringArray(given))])
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
	# Награда — до того, как задание станет сданным (у повторной сдачи своя, у заказа — из записи)
	var r := QuestData.rewards(id)
	var said := QuestData.rewards_line(r)
	var items: Dictionary = r.get("items", {})
	# Случайная награда (1–2 предмета): бросок при сдаче, место — вместе с наградой из данных
	var bonus := LootTable.quest_reward(Game.level, Game.class_id)
	var all_items: Dictionary = items.duplicate()
	for k in bonus:
		all_items[k] = int(all_items.get(k, 0)) + int(bonus[k])
	if not Game.inventory.room_for_all(all_items):
		_msg("Освободите место в сумке: награда не помещается")
		return false
	last_bonus = bonus
	var goals := QuestData.goals(id)
	Game.quests_active.erase(id)
	Game.quests_done[id] = times_done(id) + 1
	Game.quests_time[id] = QuestData.now()
	if Game.quest_tracked == id:
		Game.quest_tracked = _first_active()
	# Предметы целей «собрать» с take = true — забираем
	for g in goals:
		var gd: Dictionary = g
		if ["collect", "gather"].has(String(gd.get("type", ""))) and bool(gd.get("take", false)):
			var left := QuestData.goal_need(gd)
			for it in gd.get("items", []):
				var take_n := mini(left, Game.inventory.count(String(it)))
				if take_n > 0:
					Game.inventory.remove(String(it), take_n)
					left -= take_n
	var xp := int(r.get("xp", 0))
	var gold := int(r.get("gold", 0))
	var jp := int(r.get("jp", 0))
	Game.gold += gold
	for k in all_items:
		Game.inventory.add(String(k), int(all_items[k]))
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
	if not bonus.is_empty():
		said += ("; " if said != "" else "") + "случайная награда: " + LootDrop.describe(bonus)
	_msg("Задание «%s» выполнено! Награда: %s" % [QuestData.quest_name(id), said], 5.0)
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
	var lvl := mob.level
	_event("kill", func(g: Dictionary) -> bool: return _kill_ok(g, sp, lvl))
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
	_event("buy", func(g: Dictionary) -> bool: return _trade_ok(g, id, seller), n)


## Продано n штук id NPC buyer.
func on_sold(id: String, n: int, buyer: String) -> void:
	_event("sell", func(g: Dictionary) -> bool: return _trade_ok(g, id, buyer), n)


## Использован предмет id (выпито зелье).
func on_used(id: String) -> void:
	_event("use", func(g: Dictionary) -> bool: return _item_ok(g, id))


## На склад положено n штук id.
## Герой вошёл в локацию (main: мир построен; "dungeon" — подземелье): цели enter.
func on_entered(location: String) -> void:
	_event("enter", func(g: Dictionary) -> bool: return String(g.get("location", "dungeon")) == location)


func on_stored(id: String, n: int) -> void:
	_event("store", func(g: Dictionary) -> bool: return _item_ok(g, id), n)


## Квестовая добыча со зверя вида species: {id: 1} для каждой невыполненной цели collect с drop_from == species
## (первый предмет цели; Economy кладёт его в мешочек, если обычный бросок его не дал).
func quest_loot(species: String) -> Dictionary:
	var res: Dictionary = {}
	for k in Game.quests_active.keys():
		for g in QuestData.goals(String(k)):
			var gd: Dictionary = g
			if String(gd.get("type", "")) != "collect" or String(gd.get("drop_from", "")) != species:
				continue
			var items: Array = gd.get("items", [])
			if items.is_empty() or _state_value(gd) >= QuestData.goal_need(gd):
				continue
			res[String(items[0])] = 1
	return res


## Разговор с NPC npc_id (открыт диалог).
func on_talk(npc_id: String) -> void:
	_event("talk", func(g: Dictionary) -> bool: return QuestData.goal_npc(g) == npc_id)


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
	var title := _label(QuestData.quest_name(id), UiScale.FONT_TEXT, GOLD)
	title.name = "TrackerTitle"
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_tracker_box.add_child(title)
	var goals := QuestData.goals(id)
	for gi in goals.size():
		var g: Dictionary = goals[gi]
		var done := goal_done(id, gi)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(UiScale.px(5)))
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ch := QuestWindow.Check.new()
		ch.done = done
		ch.custom_minimum_size = UiScale.v2(13, 13)
		ch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ch)
		# Подпись в одну строку (длинная — с многоточием), прогресс справа: высота трекера постоянна
		var l := _label(QuestData.goal_text(g), UiScale.FONT_SMALL, DONE_COLOR if done else Color.WHITE)
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var n := _label("%d/%d" % [goal_progress(id, gi), QuestData.goal_need(g)], UiScale.FONT_SMALL, DONE_COLOR if done else GOLD)
		row.add_child(n)
		_tracker_box.add_child(row)
	if is_ready(id):
		_tracker_box.add_child(_label("Сдать: " + NpcData.npc_name(QuestData.turn_in(id)), UiScale.FONT_BODY, GOLD))
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
	tracker.add_theme_stylebox_override("panel", sb)
	tracker.mouse_filter = Control.MOUSE_FILTER_STOP
	tracker.gui_input.connect(_on_tracker_input)
	_tracker_box = VBoxContainer.new()
	_tracker_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tracker.add_child(_tracker_box)
	tracker.visible = false
	_size_tracker()
	main.hud.add_child(tracker)
	main.hud.add_blocker(tracker)
	main.hud.scale_changed.connect(func() -> void:
		_size_tracker()
		refresh_tracker())


## Поля, скругление и ширина трекера по размеру интерфейса (UiScale).
func _size_tracker() -> void:
	var sb := tracker.get_theme_stylebox("panel") as StyleBoxFlat
	if sb != null:
		sb.set_corner_radius_all(int(UiScale.px(10)))
		sb.content_margin_left = UiScale.px(9)
		sb.content_margin_right = UiScale.px(9)
		sb.content_margin_top = UiScale.px(5)
		sb.content_margin_bottom = UiScale.px(5)
	tracker.custom_minimum_size = Vector2(UiScale.px(TRACKER_W), 0)
	_tracker_box.add_theme_constant_override("separation", int(UiScale.px(1)))


## Трекер — справа вверху под кнопками меню; высота — по содержимому (каждый кадр: размер окна мог измениться).
func _layout_tracker() -> void:
	if tracker == null or not tracker.visible:
		return
	var vw := tracker.get_viewport_rect().size.x
	# Под меню HUD: высота кнопок меню зависит от шрифта, поэтому берём её край, а не только константу
	var top := UiScale.px(TRACKER_TOP)
	var hud: HUD = null
	if main != null:
		hud = main.get("hud") as HUD
	if hud != null:
		top = maxf(top, hud.menu_rect().end.y + UiScale.px(6))
	var w := UiScale.px(TRACKER_W)
	tracker.position = Vector2(vw - w - UiScale.px(12), top)
	tracker.size = Vector2(w, 0.0)


func _process(delta: float) -> void:
	_layout_tracker()
	_poll_t -= delta
	if _poll_t <= 0.0:
		_poll_t = POLL
		poll(POLL)


## Опрос раз в POLL с: умения питомцев (pet_skill), цели-состояния без своих сигналов (снаряжение, заточка,
## вещи питомцев, сданные задания), находки (gather). dt — сколько прошло с прошлого опроса.
func poll(dt: float = POLL) -> void:
	var sum := pet_skill_sum()
	if sum > _pet_skill_sum:
		_event("pet_skill", func(_g: Dictionary) -> bool: return true, sum - _pet_skill_sum)
	_pet_skill_sum = sum
	_refresh_state_goals(true)
	finds_tick(dt)


## Сумма изученных уровней умений всех питомцев коллекции.
static func pet_skill_sum() -> int:
	var n := 0
	for rec in Game.pets:
		var sk: Variant = (rec as Dictionary).get("skills", {})
		if sk is Dictionary:
			for k in sk:
				n += maxi(0, int((sk as Dictionary)[k]))
	return n


# ---------- Заказ писаря ----------

## Цели и награда заказа (gen) по уровню героя: {"goals", "rewards"} (QuestData.contract по зонам острова).
func generate(id: String) -> Dictionary:
	var zones: Array = []
	if IslandWorld.current != null:
		zones = IslandWorld.current.cfg.get("mob_zones", [])
	var res := QuestData.contract(Game.level, zones, gen_rng)
	if String(QuestData.get_quest(id).get("gen", "")) != "scribe":
		push_warning("Неизвестный заказ: %s" % id)
	return res


# ---------- Находки (цель gather) ----------

## Нужные сейчас находки: ключ "<предмет>@<зона>" → {"item", "zone"} по невыполненным целям gather взятых заданий.
func wanted_finds() -> Dictionary:
	var res: Dictionary = {}
	for k in Game.quests_active.keys():
		var id := String(k)
		var goals := QuestData.goals(id)
		for gi in goals.size():
			var g: Dictionary = goals[gi]
			if String(g.get("type", "")) != "gather" or goal_done(id, gi):
				continue
			var items: Array = g.get("items", [])
			if items.is_empty():
				continue
			var item := String(items[0])
			var zone := String(g.get("zone", ""))
			res["%s@%s" % [item, zone]] = {"item": item, "zone": zone}
	return res


## Находки в мире (живые узлы QuestFind).
func finds() -> Array:
	var res: Array = []
	if not is_inside_tree():
		return res
	for n in get_tree().get_nodes_in_group("quest_finds"):
		if not n.is_queued_for_deletion():
			res.append(n)
	return res


## Находки: ненужные убрать, нужных — до FIND_COUNT в зоне (новые — когда прошла пауза после сбора).
func finds_tick(dt: float) -> void:
	if main == null or not is_inside_tree():
		return
	var want := wanted_finds()
	var have: Dictionary = {}
	for n in finds():
		var f := n as Node3D
		if f == null:
			continue
		var fk := String(f.get("key"))
		if not want.has(fk):
			f.queue_free()
			continue
		have[fk] = int(have.get(fk, 0)) + 1
	for key in want:
		var cd := float(_find_cd.get(key, 0.0)) - dt
		_find_cd[key] = cd
		if cd > 0.0:
			continue
		var w: Dictionary = want[key]
		for i in FIND_COUNT - int(have.get(key, 0)):
			if _spawn_find(String(key), String(w["item"]), String(w["zone"])) == null:
				break


## Точка для находки в зоне зверей zone острова: суша, не у воды, не в безопасной зоне, не у других находок.
func find_spot(zone: String) -> Variant:
	var w := IslandWorld.current
	if w == null:
		return null
	var zd: Dictionary = {}
	for z in w.cfg.get("mob_zones", []):
		if String((z as Dictionary).get("id", "")) == zone:
			zd = z
	if zd.is_empty():
		return null
	var c := IslandWorld.v2(zd["center"])
	var r := float(zd.get("radius", 10.0)) * 0.9
	var others: Array = []
	for n in finds():
		var nd := n as Node3D
		others.append(Vector2(nd.global_position.x, nd.global_position.z))
	for t in 40:
		var a := _rng.randf() * TAU
		var p := c + Vector2(cos(a), sin(a)) * sqrt(_rng.randf()) * r
		if not w.is_walkable(p.x, p.y) or w.water_distance(p.x, p.y) < 2.0:
			continue
		var pos := Vector3(p.x, w.height_at(p.x, p.y), p.y)
		if w.in_safe_zone(pos):
			continue
		var ok := true
		for o in others:
			if p.distance_to(o) < FIND_GAP:
				ok = false
				break
		if ok:
			return pos
	return null


func _spawn_find(key: String, item: String, zone: String) -> Node3D:
	var pos: Variant = find_spot(zone)
	if pos == null:
		return null
	var f: Node3D = FindScript.new()
	f.set("key", key)
	f.set("item", item)
	f.set("quests", self)
	main.add_child(f)
	f.global_position = pos
	return f


## Сорвать находку f (герой подошёл): предмет в сумку, находка исчезает, новая — через FIND_RESPAWN с.
func pick_find(f: Node3D) -> bool:
	if f == null or f.is_queued_for_deletion():
		return false
	var item := String(f.get("item"))
	if Game.inventory.room_for(item) <= 0:
		f.set("full_cd", 3.0)
		_msg("Сумка полна — освободите место")
		return false
	Game.inventory.add(item, 1)
	var pos := f.global_position
	f.queue_free()
	_find_cd[String(f.get("key"))] = FIND_RESPAWN
	Vfx.pickup(main, pos + Vector3(0, 0.3, 0))
	Util.float_text(main, pos + Vector3(0, 1.2, 0), "+" + ItemData.item_name(item), DONE_COLOR, 0.9)
	return true


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
		"skill":
			return learned_skills()
		"gather":
			var items: Array = g.get("items", [])
			return Game.inventory.count(String(items[0])) if not items.is_empty() else 0
		"equip":
			var n := 0
			for e in g.get("slots", []):
				if _slot_item(String(e), 0) != "":
					n += 1
			return n
		"upgrade":
			return _upgraded(g)
		"pet_gear":
			var n := 0
			for rec in Game.pets:
				for s in PetGear.SLOTS:
					if PetGear.gear_in(rec, String(s)) != "":
						n += 1
			return n
		"quest":
			return 1 if is_done(String(g.get("id", ""))) else 0
	return 0


## Вещь, надетая в ячейке entry ("ring1|ring2" — любая из), с заточкой не ниже plus ("" — нет такой).
static func _slot_item(entry: String, plus: int) -> String:
	for s in entry.split("|"):
		var id := Enchant.equipped_in(String(s))
		if id != "" and not ItemData.is_broken(id) and ItemData.enchant_level(id) >= plus:
			return id
	return ""


## Прогресс цели upgrade: ячейки slots с заточкой +plus, иначе — сколько вещей вида what (в сумке и надетых) +plus.
static func _upgraded(g: Dictionary) -> int:
	var plus := int(g.get("plus", 1))
	var n := 0
	var slots: Array = g.get("slots", [])
	if not slots.is_empty():
		for e in slots:
			if _slot_item(String(e), plus) != "":
				n += 1
		return n
	var what := String(g.get("what", "any"))
	for k in Game.inventory.ids():
		var id := String(k)
		if ItemData.is_broken(id) or ItemData.enchant_level(id) < plus:
			continue
		var kind := ItemData.enchant_kind(id)
		var fits := kind != ""
		match what:
			"weapon":
				fits = kind == "attack"
			"armor":
				fits = kind == "defense"
		if fits:
			n += Game.inventory.count(id)
	return n


## Сколько умений профессии герой изучил сам (стартовые бесплатные умения 1-го уровня не в счёт).
static func learned_skills() -> int:
	var n := 0
	var src: Variant = Game.hero.get("skills", {})
	if not (src is Dictionary):
		return 0
	var d: Dictionary = src
	for k in d:
		var lv := int(d[k])
		if bool(HeroSkills.get_skill(String(k), Game.class_id).get("start", false)):
			lv -= 1
		if lv > 0:
			n += 1
	return n


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


## Убийство подходит цели kill: вид (target / targets; пусто — любой) и уровень (min_level … max_level).
static func _kill_ok(g: Dictionary, species: String, lvl: int) -> bool:
	var list := QuestData.goal_species(g)
	if not list.is_empty() and not list.has(species):
		return false
	var mx := int(g.get("max_level", 0))
	return lvl >= int(g.get("min_level", 0)) and (mx <= 0 or lvl <= mx)


## Предмет подходит цели: items пусто — любой; семья зелий ("potion_hp") — зелье этого вида любого ранга.
static func _item_ok(g: Dictionary, id: String) -> bool:
	var items: Array = g.get("items", [])
	return items.is_empty() or items.has(id) or (ItemData.is_potion(id) and items.has(ItemData.potion_family(id)))


## Покупка или продажа подходит цели: предмет (items пусто — любой) и NPC (npc "" — любой).
static func _trade_ok(g: Dictionary, id: String, who: String) -> bool:
	var npc := String(g.get("npc", ""))
	if bool(g.get("fits", false)) and not ItemData.weapon_fits(id, Game.class_id):
		return false
	return _item_ok(g, id) and (npc == "" or npc == who)


## С кем сейчас открыт разговор ("" — ни с кем).
func _talking_to() -> String:
	if main == null:
		return ""
	var n: Node = main.get("npcs")
	if n == null:
		return ""
	var npcs := n as Npcs
	if npcs == null or not npcs.is_dialog_open():
		return ""
	return npcs.dialog_npc


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


## Подпись трекера; font_size — для «Среднего» размера интерфейса (UiScale.FONT_*).
func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", UiScale.fs(font_size))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
