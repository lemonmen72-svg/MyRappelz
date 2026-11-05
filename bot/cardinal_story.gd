class_name CardinalStory
extends RefCounted
## Кардинал «Прохождение острова» (задача Максима: «чтобы он умел проходить вообще все квесты, крафтить, вставлять в
## пояс питомцев, давать питомцам оружие…»): свежий Бродяга 1 ур. проходит ВСЮ цепочку острова и задания всех жителей
## (QuestData.QUESTS) — как игрок, теми же входами: ходьба джойстиком по маршруту (CardinalMove, IslandWorld.Route),
## «Говорить» → диалог → «Задания» → взять / сдать (кнопки Npcs.buttons), окна торговли, склада, кузницы, панель крафта
## сумки (InventoryWindow.buttons), окно героя (изучить умения, назначить кнопки), окно «Питомцы» (сформировать,
## призвать, воскресить), окно существа (умения, «Оружие и доспехи»), ячейки пояса в сумке, окно выбора профессии
## (JobWindow), кнопки HUD («Атака» удержанием, умения, «Зелье», «Приручить», команды питомца). Прогресс заданий
## НИКОГДА не выставляется — только событиями игры.
##
## Устройство: корутина run() — каждый шаг ждёт тик физики (_tick: решения по тикам физики, как у CardinalRun; пауза
## бота на остывание — ждёт). Планировщик (_plan) по порядку: сумка почти полна — продать лишнее; есть задание к сдаче
## — к ближайшему сдающему; есть доступное — к ближайшему выдающему, взять; готова «фича» (торба, склад, крафт,
## снаряжение питомцу, эволюция, пояс, расширитель); иначе — решатель каждой невыполненной цели взятых заданий
## (_solve: kill, collect с drop_from и без, buy (fits), sell, use, store, level, skill, tame, form, summon, pet_kill,
## talk, equip, upgrade, pet_skill, pet_gear, gather, quest) предлагает действие с ценой (путь), берётся дешёвое;
## ничего — прокачка на зверях по силам. Цель, по которой GOAL_TRIES попыток нет прогресса, — «застряла» (причина в
## отчёте), задание дальше не мешает.
##
## Допуски (профиль PROFILE_STORY, каждое — «помощь» в отчёте): Game.xp_mult (опыт героя и питомца), бессмертие
## AdminPanel.god на боях с боссами и вожаками, перенос к цели, если застрял на маршруте дольше stuck_teleport с.
## Упрощение симуляции (не помощь герою): звери дальше sim_radius м спят (Mob.sleep_dist; в игре — 55 м) — шаг физики
## дешевле. Ускорение — accel (×8 по умолчанию, ×16, ×32: тиков физики ×N при шаге 1/60 с, без 3D, без предела кадров)
## и перемотка отдыха ×REST_BOOST поверх.
## Итог — result(): по каждому заданию взято / сдано / застряло (причина), время, уровень, сверка наград; фичи (крафт,
## закалка, торба, питомец, пояс, эволюция, склад), помощь, смерти, убийства; журнал событий (детерминизм ×8 / ×16).

const PROFILE_STORY := {
	"id": "story", "name": "Прохождение острова", "version": 1,
	"xp_mult": 50,           # Game.xp_mult на прогон (помощь: опыт за зверей героя и питомца)
	"god_bosses": true,      # бессмертие на боях с боссами и «Редкими» вожаками (помощь)
	"stuck_teleport": 14.0,  # с без продвижения к цели — перенос (помощь)
	"sim_radius": 24.0,      # Mob.sleep_dist на время прогона (упрощение симуляции; дальше «Авто» питомца 12 м и агрессии 6 м)
	"rest_below": 0.45, "rest_until": 0.9, "potion_below": 0.35,
	"level_gap": 2,          # обычные звери не старше героя + gap
	"boss_gap": 3,           # босс — когда герой не младше босса − gap
	"bag_reserve": 5,        # свободных ячеек меньше — продать лишнее
	"fight_limit": 120.0, "approach_limit": 90.0,
	"goal_tries": 8,         # попыток цели без прогресса — «застряла»
	# После заданий: питомцу — до 50 ур. (эволюция у Кирка) и «Способности карты» (пояс, с 40 ур.): на острове звери
	# не старше 30, опыт питомца на 10+ уровней выше зверя — ×0.1, поэтому опыт ×pet_phase_xp (помощь), не дольше
	# pet_phase_sec игровых секунд
	"pet_phase_xp": 5000, "pet_phase_sec": 900.0,
	# Бег героя ×N (AdminPanel.speed_mult; 1 — как у игрока). Помощь: только для быстрого прогона в CI (тест), на
	# телефоне — 1
	"run_speed": 1,
}
## Перемотка отдыха (как у CardinalRun): ускорение игры × REST_BOOST, пока рядом нет опасности.
const REST_BOOST := 8.0
const SAFE_RADIUS := 12.0
## Сколько раз подряд план «ничего» до конца прогона (все цели застряли).
const IDLE_PLANS := 40

var bot: TestBot
var profile: Dictionary = PROFILE_STORY
var run_name := "story"
var title := "Прохождение"
var race := "human"
var job := ""
var gender := "m"
var accel := 8.0
var seed_value := 1
var game_limit := 6.0 * 3600.0
var wall_limit := 3600.0
## Остановиться, когда сданы все эти задания (детерминизм — короткий отрезок; [] — до конца).
var stop_after: Array = []
## Только до выбора профессии (вторая и третья раса в тесте).
var until_job := false

var done := false
var stop_reason := ""
var game_t := 0.0
var deaths := 0
var kills := 0
var kills_by: Dictionary = {}
var t_split := {"walk": 0.0, "fight": 0.0, "loot": 0.0, "rest": 0.0, "npc": 0.0, "ui": 0.0, "wait": 0.0}
## Задания: id → {name, giver, taken, done, level_taken, level_done, status, reason, reward_ok, reward, tries}
var quests: Dictionary = {}
## Фичи: имя → {ok (true/false/null — не проверено), text, n}
var features: Dictionary = {}
## Помощь: вид → {n, where: []}
var help: Dictionary = {}
## Находки (сломано в данных/игре): строки
var findings: PackedStringArray = PackedStringArray()
## Журнал событий: [{t, kind, text}] (take / done / kill / job / death / feature / help)
var events: Array = []
var start := {}
var finish := {}
var boost_game := 0.0

var _tree: SceneTree
var _saved := {}
var _clock0 := 0.0
var _wall0 := 0
var _wall_end := -1.0
var _stopping := false
var _nav := IslandWorld.Route.new()
var _split := "wait"
var _boosted := false
var _skip_mob: Dictionary = {}
var _goal_state: Dictionary = {}
var _stuck_goals: Dictionary = {}
var _last_skill_level := 0
var _last_pet_learn := -1
var _skill_try: Dictionary = {}
var _idle_plans := 0
var _rng := RandomNumberGenerator.new()
var _sleep_saved := Mob.SLEEP_DIST
var _xp_saved := 1
var _god_saved := false
var _msg_last := ""
var _last_plan := ""
var _last_pos := Vector3.ZERO
var _steps := 0
## Строка «идёт — …» в журнал раз в BEAT_SEC игровых секунд.
const BEAT_SEC := 60.0
var _beat_t := 0.0
var _beat_ticks := 0
var _beat_us := 0
## Тиков прогона и настоящее время в коде Кардинала (решения, окна), мкс — доля Кардинала в нагрузке.
var ticks := 0
var self_us := 0
var _resume_us := 0
## Сколько мс строилась сетка пути (CardinalNav; 0 — уже была).
var nav_ms := 0
## Отладка детерминизма: след каждого тика до trace_until игровых секунд (0 — нет).
var trace_until := 0.0
var trace: PackedStringArray = PackedStringArray()


# ==================== Запуск, часы, конец ====================

func begin() -> void:
	_tree = bot.get_tree()
	_saved = CardinalMove.speed_up(bot, accel)
	_sleep_saved = Mob.sleep_dist
	_xp_saved = Game.xp_mult
	_god_saved = AdminPanel.god
	Mob.sleep_dist = float(profile["sim_radius"])
	var nav_t := Time.get_ticks_usec()
	CardinalNav.ensure(IslandWorld.current, _tree)
	nav_ms = (Time.get_ticks_usec() - nav_t) / 1000
	_fresh_hero()
	_wall0 = Time.get_ticks_usec()
	_clock0 = Util.game_time()
	start = _snapshot()
	bot.note("Кардинал «%s»: %s, %s, seed %d, ускорение ×%.0f, опыт ×%d, звери спят дальше %.0f м" % [title,
		String(ClassData.race(race).get("name", race)), ClassData.job_name(job), seed_value, accel, int(profile["xp_mult"]),
		float(profile["sim_radius"])])
	run()


## Свежий Бродяга (раса race) в деревне своей расы; мир — звери на местах, мешочки и находки убраны.
func _fresh_hero() -> void:
	seed(seed_value)
	Combat.reseed(seed_value)
	_rng.seed = seed_value
	if job == "":
		var js := ClassData.jobs_of(race)
		job = String(js[0]) if not js.is_empty() else "warrior"
	Game.new_character(TestBot.BOT_NICK, race, ClassData.WANDERER, gender)
	Game.xp_mult = int(profile["xp_mult"])
	AdminPanel.god = false
	AdminPanel.speed_mult = maxi(1, int(profile.get("run_speed", 1)))
	if AdminPanel.speed_mult > 1:
		_help("speed", "бег ×%d всё время (профиль быстрого прогона)" % AdminPanel.speed_mult)
	var m := bot.main
	var q := _q()
	if q != null:
		var r := RandomNumberGenerator.new()
		r.seed = seed_value + 7
		q.gen_rng = r
		q.set("_rng", RandomNumberGenerator.new())
		(q.get("_rng") as RandomNumberGenerator).seed = seed_value + 11
		(q.get("_find_cd") as Dictionary).clear()
		q.set("_pet_skill_sum", 0)
	var tm: Taming = m.get("taming") as Taming
	if tm != null:
		var tr: RandomNumberGenerator = tm.get("_rng")
		if tr != null:
			tr.seed = seed_value + 13
		tm.cooldown = 0.0
		tm.marked = null
	var eco := _eco()
	if eco != null:
		eco.set("_potion_cd", 0.0)
		eco.set("_mana_cd", 0.0)
		eco.craft_rng = null
	for g in ["loot_drops", "quest_finds"]:
		for n in _tree.get_nodes_in_group(g):
			(n as Node).queue_free()
	var h := _h()
	if h != null:
		h.close_window()
	var p := _p()
	p.select_target(null)
	p.clear_buffs()
	p.apply_class()
	p.refresh_equipment(true)
	p.recalc_stats()
	p.hp = p.max_hp
	p.mp = p.max_mp
	p.global_position = p.respawn_point()
	p.velocity = Vector3.ZERO
	# Одинаковое начало прогонов: поворот героя и его плавный поворот (прошлый прогон оставил свои)
	p.rotation = Vector3.ZERO
	p.set("_face_yaw", 0.0)
	p.set("_face_hold", 0.0)
	p.set("_phys_prev", p.global_position)
	p.set("_phys_cur", p.global_position)
	p.move_input = Vector2.ZERO
	bot.reset_camera()
	p.last_attacker = null
	p.skill_cd.clear()
	p.attack_cd = 0.0
	p.regen_delay = 0.0
	JobFxNeophyte.corpses.clear()
	var pm := _pm()
	if pm != null:
		pm.call("_sync")
	if m.has_method("reset_mobs"):
		m.call("reset_mobs")
	if not p.message.is_connected(_on_message):
		p.message.connect(_on_message)
	Game.changed.emit()


func _snapshot() -> Dictionary:
	var pet_lv := 0
	var pet_st := 0
	for rec in Game.pets:
		if int(rec.get("level", 1)) > pet_lv:
			pet_lv = int(rec.get("level", 1))
			pet_st = PetData.stage_of(rec) + 1
	return {"level": Game.level, "xp": Game.xp, "cum_xp": CardinalRun.cumulative_xp(Game.level, Game.xp), "gold": Game.gold,
		"job": Game.class_id, "pets": Game.pets.size(), "pet_level": pet_lv, "pet_form": pet_st, "done": Game.quests_done.size(),
		"bag": Game.inventory.capacity, "belt_slots": Game.belt_slots}


func wall_sec() -> float:
	if _wall_end >= 0.0:
		return _wall_end
	return float(Time.get_ticks_usec() - _wall0) / 1.0e6


## Остановить снаружи (бот кончился: «Стоп», лимит, перегрев) — настройки движка на место.
func abort(reason: String) -> void:
	if done:
		return
	_stopping = true
	_end(reason)


func _end(reason: String) -> void:
	if done:
		return
	done = true
	_stopping = true
	stop_reason = reason
	_wall_end = float(Time.get_ticks_usec() - _wall0) / 1.0e6
	_set_boost(false)
	var p := _p()
	var h := _h()
	if p != null:
		CardinalMove.stop(p, h)
		if p.message.is_connected(_on_message):
			p.message.disconnect(_on_message)
	if h != null:
		h.close_window()
	CardinalMove.restore(bot, _saved)
	Mob.sleep_dist = _sleep_saved
	AdminPanel.god = _god_saved
	AdminPanel.speed_mult = 1
	finish = _snapshot()
	for k in quests:
		var r: Dictionary = quests[k]
		if String(r["status"]) == "active" or String(r["status"]) == "ready":
			r["status"] = "active"
			if String(r.get("reason", "")) == "":
				r["reason"] = _why_open(String(k))
	bot.note("Кардинал «%s» закончен: %s — игровое %s, настоящее %s (×%.1f), сдано %d из %d, помощь %d, смертей %d" % [
		title, reason, TestBot.clock(game_t), TestBot.clock(wall_sec()), game_t / maxf(wall_sec(), 0.001), done_count(),
		QuestData.all_ids().size(), help_count(), deaths])


func _alive() -> bool:
	return not _stopping and bot != null and is_instance_valid(bot) and bot.main != null and is_instance_valid(bot.main)


## Один тик физики (решения «игрока» — по тикам, как у CardinalRun). false — прогон кончается.
func _tick() -> bool:
	if not _alive():
		return false
	if _resume_us > 0:
		self_us += Time.get_ticks_usec() - _resume_us
	await _tree.physics_frame
	_resume_us = Time.get_ticks_usec()
	ticks += 1
	while _alive() and (bot.state == "cooling" or _tree.paused):
		await _tree.physics_frame
	if not _alive() or bot.state != "running":
		if not done:
			_end("бот остановлен")
		return false
	var pp := _p()
	if pp != null:
		_last_pos = pp.global_position
		if trace_until > 0.0 and game_t < trace_until:
			trace.append("%.4f %.9f %.9f y%.9f hp%d mi%s pl[%s] tg%s" % [game_t, pp.global_position.x, pp.global_position.z, pp.global_position.y, pp.hp,
				str(pp.move_input), _last_plan, str(pp.current_target.get_instance_id() % 100000) if pp.current_target != null else "-"])
	# Игровое время — целым числом шагов по 1/60 с (тик физики — 1/60 с, на перемотке отдыха — REST_BOOST/60):
	# у прогонов с одним seed сравнения «прошло ли N с» совпадают до тика (сумма дробных шагов давала сдвиг на тик)
	var steps := maxi(0, roundi(Engine.time_scale * 60.0 / float(Engine.physics_ticks_per_second)))
	_steps += steps
	var now := float(_steps) / 60.0
	var gdt := maxf(0.0, now - game_t)
	game_t = now
	t_split[_split] = float(t_split.get(_split, 0.0)) + gdt
	if _boosted:
		boost_game += gdt
	# Окно игры ставит предел кадров (MENU_FPS) — на ускорении его нет
	if accel > 1.0 and Engine.max_fps != 0:
		Engine.max_fps = 0
	if game_t - _beat_t >= BEAT_SEC:
		_beat_t = game_t
		var bp := _p()
		var awake := 0
		for n in _tree.get_nodes_in_group("mobs"):
			if (n as Node).process_mode != Node.PROCESS_MODE_DISABLED:
				awake += 1
		var tk := ticks - _beat_ticks
		var ms := float(Time.get_ticks_usec() - _beat_us) / 1000.0 / maxf(float(tk), 1.0)
		_beat_ticks = ticks
		_beat_us = Time.get_ticks_usec()
		bot.note("Кардинал [%s, %d ур., %s]: идёт — %s; герой у (%.0f, %.0f), HP %d/%d; сдано %d; убийств %d, смертей %d; %.2f мс/тик, узлов %d, зверей не спят %d, физика %.1f мс, кадр %.1f мс" % [
			TestBot.clock(game_t), Game.level, title, _last_plan, bp.global_position.x, bp.global_position.z, bp.hp, bp.max_hp,
			done_count(), kills, deaths, ms, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), awake,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
	if game_t >= game_limit:
		_end("лимит игрового времени")
		return false
	if wall_sec() >= wall_limit:
		_end("лимит настоящего времени")
		return false
	return true


## Подождать sec игровых секунд.
func _wait(sec: float, split: String = "wait") -> bool:
	_split = split
	var t0 := game_t
	while game_t - t0 < sec:
		if not await _tick():
			return false
	return true


func _on_message(text: String) -> void:
	_msg_last = text
	if text.contains("погибли"):
		deaths += 1
		var who := ""
		var p := _p()
		if p != null and p.last_attacker is Mob and is_instance_valid(p.last_attacker):
			var m := p.last_attacker as Mob
			who = ", напал «%s» %d ур." % [m.mob_name, m.level]
		_ev("death", "смерть у (%.0f, %.0f), герой %d ур.%s (план: %s)" % [_last_pos.x, _last_pos.z, Game.level, who, _last_plan])


func _last_msg() -> String:
	var h := _h()
	if h != null and h.get("_msg_label") != null:
		var l := h.get("_msg_label") as Label
		if l != null:
			return l.text
	return _msg_last


# ==================== Доступ к миру ====================

func _p() -> Player:
	return bot.player() if bot != null and is_instance_valid(bot) else null


func _h() -> HUD:
	if bot == null or not is_instance_valid(bot) or bot.main == null or not is_instance_valid(bot.main):
		return null
	return bot.main.get("hud") as HUD


func _q() -> Quests:
	return bot.main.get("quests") as Quests if bot.main != null else null


func _npcs() -> Npcs:
	return bot.main.get("npcs") as Npcs


func _eco() -> Economy:
	return bot.main.get("economy") as Economy


func _pm() -> PetManager:
	return bot.main.get("pets") as PetManager


func _win() -> InventoryWindow:
	var e := _eco()
	return e.window if e != null else null


func _ev(kind: String, text: String) -> void:
	events.append({"t": snappedf(game_t, 0.1), "kind": kind, "text": text})
	if ["take", "done", "job", "death", "help", "feature", "tame", "pet"].has(kind):
		var t := text
		if kind == "take" or kind == "done":
			t = "%s «%s»" % [text, QuestData.quest_name(text)]
		bot.note("Кардинал [%s, %d ур., %s]: %s — %s" % [TestBot.clock(game_t), Game.level, title, kind, t])


func _help(kind: String, text: String) -> void:
	var r: Dictionary = help.get(kind, {"n": 0, "where": []})
	r["n"] = int(r["n"]) + 1
	if (r["where"] as Array).size() < 12:
		(r["where"] as Array).append("%s: %s" % [TestBot.clock(game_t), text])
	help[kind] = r
	_ev("help", "%s — %s" % [kind, text])


func help_count() -> int:
	var n := 0
	for k in help:
		n += int((help[k] as Dictionary)["n"])
	return n


func _find(text: String) -> void:
	if not findings.has(text):
		findings.append(text)
		bot.note("Кардинал: находка — " + text)


func _feature(name: String, ok: Variant, text: String) -> void:
	var r: Dictionary = features.get(name, {"ok": null, "text": "", "n": 0})
	r["n"] = int(r["n"]) + 1
	# Ошибка остаётся ошибкой: последняя удача её не затирает
	if r["ok"] == null or ok == false or (ok == true and r["ok"] != false):
		r["ok"] = ok
		r["text"] = text
	features[name] = r
	_ev("feature", "%s: %s" % [name, text])


func _flat(a: Vector3, b: Vector3) -> float:
	return CardinalMove.flat(a, b)


func _mob_alive(m: Variant) -> bool:
	return m != null and is_instance_valid(m) and not (m as Mob).is_dead and (m as Mob).is_inside_tree()


# ==================== Кнопки окон ====================

## Нажать кнопку окна (словарь кнопок окна: Npcs.buttons, InventoryWindow.buttons …) — как касание.
func _press(btns: Dictionary, key: String) -> bool:
	var b: Variant = btns.get(key)
	if b == null or not is_instance_valid(b):
		return false
	var bt := b as BaseButton
	if bt == null or bt.disabled:
		return false
	bt.pressed.emit()
	return true


## Действие кнопки HUD (как касание круглой кнопки или пункта меню).
func _action(id: String) -> void:
	var h := _h()
	if h != null:
		h.action.emit(id)


func _close() -> void:
	var h := _h()
	if h != null and h.is_window_open():
		h.close_window()


# ==================== Ходьба, бой, отдых ====================

## Дойти до точки to (ближе near). Застрял (за stuck_teleport с не стал ближе на 0.5 м) — перенос к цели (помощь).
func _go(to: Vector3, near: float, what: String, defend: bool = true) -> bool:
	_close()
	_nav.reset()
	var best := INF
	var best_t := game_t
	var t0 := game_t
	# Обход препятствия (стена, ограда, дерево): за DETOUR_CHECK с почти не сдвинулся — шаг вбок DETOUR_SEC с
	var win_pos := _p().global_position if _p() != null else Vector3.ZERO
	var win_t := game_t
	var detour_until := -1.0
	var detour_to := Vector3.ZERO
	var side := 1.0
	var fails := 0
	# Путь по сетке (ограды, стены, деревья — CardinalNav); пусто — по прямой с маршрутом через мосты
	var path := CardinalNav.path(_p().global_position, to) if _p() != null else PackedVector3Array()
	var pi := 0
	var fought := 0
	while _alive():
		var p := _p()
		var h := _h()
		if p == null:
			return false
		var d := _flat(p.global_position, to)
		if d <= near:
			CardinalMove.stop(p, h)
			return true
		if d < best - 0.5:
			best = d
			best_t = game_t
		elif game_t - best_t > float(profile["stuck_teleport"]) or game_t - t0 > float(profile["approach_limit"]) * 4.0:
			CardinalMove.stop(p, h)
			_help("teleport", "застрял по пути к «%s» у (%.0f, %.0f), до цели %.0f м" % [what, p.global_position.x,
				p.global_position.z, d])
			bot.teleport(Vector2(to.x, to.z), "Кардинал: к «%s»" % what)
			_nav.reset()
			best = INF
			best_t = game_t
			path = CardinalNav.path(_p().global_position, to)
			pi = 0
			if not await _tick():
				return false
			continue
		# Отбиться от напавшего — не больше THREAT_MAX раз за путь (у логова кентавров они возрождаются быстрее, чем
		# герой проходит мимо: 7 игровых минут на месте); время боя в «застрял» не идёт
		if defend and fought < THREAT_MAX:
			var th := _threat()
			if th != null:
				CardinalMove.stop(p, h)
				fought += 1
				var tf := game_t
				await _fight(th, "напал по пути")
				_nav.reset()
				best_t += game_t - tf
				path = CardinalNav.path(_p().global_position, to)
				pi = 0
				continue
		_drink_if_low()
		_split = "walk"
		if game_t - win_t >= DETOUR_CHECK:
			if _flat(p.global_position, win_pos) < 0.8 and game_t >= detour_until:
				fails += 1
				if fails % 2 == 0:
					side = -side
				detour_to = _detour_point(p.global_position, to, side, 2.0 + float(fails))
				detour_until = game_t + DETOUR_SEC
			elif _flat(p.global_position, win_pos) >= 0.8 and game_t >= detour_until:
				fails = 0
			win_pos = p.global_position
			win_t = game_t
		if game_t < detour_until:
			var dd := Vector3(detour_to.x - p.global_position.x, 0.0, detour_to.z - p.global_position.z)
			if dd.length() < 0.5:
				detour_until = -1.0
				path = CardinalNav.path(p.global_position, to)
				pi = 0
			else:
				_walk_dir(p, h, dd.normalized())
		elif not path.is_empty() and pi < path.size():
			var pos := p.global_position
			# Точки пути — точки поворота (AStarGrid2D с прыжками): между ними прямая по свободным клеткам
			while pi < path.size() - 1 and _flat(pos, path[pi]) < 1.0:
				pi += 1
			if pi == path.size() - 1 and _flat(pos, path[pi]) < 1.0:
				pi += 1
			var aim: Vector3 = path[pi] if pi < path.size() else to
			_walk_dir(p, h, Vector3(aim.x - pos.x, 0.0, aim.z - pos.z).normalized())
		else:
			_walk(p, h, to)
		if not await _tick():
			return false
	return false


const DETOUR_CHECK := 1.2
const THREAT_MAX := 3
const DETOUR_SEC := 1.6


## Точка обхода: вбок от направления на цель (side ±1), на проходимой земле, dist м.
func _detour_point(pos: Vector3, to: Vector3, side: float, dist: float) -> Vector3:
	var fwd := Vector3(to.x - pos.x, 0.0, to.z - pos.z).normalized()
	var w := IslandWorld.current
	for a in [90.0, 60.0, 120.0, 135.0, 45.0, 160.0]:
		var d := fwd.rotated(Vector3.UP, deg_to_rad(a) * side)
		var q := pos + d * dist
		if w == null or w.is_walkable(q.x, q.z):
			return q
	return pos - fwd * dist


## Шаг к точке to по маршруту (мосты — IslandWorld.Route).
func _walk(p: Player, h: HUD, to: Vector3) -> void:
	var pos := p.global_position
	var dir := _nav.dir_to(pos, to, 1.0 / 60.0)
	if dir.length() < 0.01:
		dir = Vector3(to.x - pos.x, 0.0, to.z - pos.z).normalized()
	_walk_dir(p, h, dir)


## Движение героя в сторону dir (мир): Player.move_input в этом тике физики. Джойстик HUD не трогаем: main._process
## раз в кадр отрисовки переводит его в move_input через поворот камеры — с округлением, и при ×8 и ×16 (кадры на
## разных тиках) путь героя расходился в 4-м знаке (детерминизм ×8 / ×16).
func _walk_dir(p: Player, h: HUD, dir: Vector3) -> void:
	if h != null:
		h.move_vec = Vector2.ZERO
	p.move_input = Vector2(dir.x, dir.z) if dir.length() >= 0.15 else Vector2.ZERO


## Зверь, который бьёт героя рядом и по силам (иначе — уходим дальше, он отстанет у поводка).
func _threat() -> Mob:
	var p := _p()
	for n in _tree.get_nodes_in_group("mobs"):
		var m := n as Mob
		if _mob_alive(m) and m.target == p and _flat(m.global_position, p.global_position) < 4.5:
			# Вожак или босс бьёт героя — отбиваться (бессмертие на таком бою — помощь, как на задании)
			if m.is_boss or MobData.is_mini_boss(m.type_id):
				if bool(profile["god_bosses"]) and not ClassData.is_wanderer(Game.class_id):
					return m
				continue
			if m.level <= Game.level + int(profile["level_gap"]) + 2 or AdminPanel.god:
				return m
	return null


## Выпить зелье здоровья (кнопка «Зелье»), если HP низко и зелье готово.
func _drink_if_low(force: bool = false) -> void:
	var p := _p()
	var eco := _eco()
	if p == null or eco == null or p.hp >= p.max_hp:
		return
	if not force and float(p.hp) > float(p.max_hp) * float(profile["potion_below"]):
		return
	if eco.potion_cooldown_frac() > 0.0 or Economy.best_potion("hp") == "":
		return
	_action("potion")


## Бой со зверем m как игрок: подойти, цель касанием, удержание «Атаки», умения на кнопках, зелье. true — побеждён.
func _fight(m: Mob, why: String) -> bool:
	if not _mob_alive(m):
		return false
	var deaths0 := deaths
	var t0 := game_t
	var god_on := false
	if bool(profile["god_bosses"]) and (m.is_boss or MobData.is_mini_boss(m.type_id)) and not AdminPanel.god \
			and (m.is_boss or Game.level < m.level + 5 or why.begins_with("напал")):
		AdminPanel.god = true
		god_on = true
		_help("god", "бессмертие: бой с «%s» %d ур. (герой %d ур.)" % [m.mob_name, m.level, Game.level])
	_close()
	_nav.reset()
	var hp_seen := m.hp
	var hp_t := game_t
	var sk_t := 0.0
	while _mob_alive(m) and _alive():
		var p := _p()
		var h := _h()
		if deaths != deaths0:
			break
		if game_t - t0 > float(profile["fight_limit"]) * (4.0 if m.is_boss else (3.0 if MobData.is_mini_boss(m.type_id) else 1.0)):
			_skip_mob[m.get_instance_id()] = game_t + 60.0
			bot.note("Кардинал: бой с «%s» дольше %.0f с — брошен (%s)" % [m.mob_name, game_t - t0, why])
			break
		if m.hp < hp_seen:
			hp_seen = m.hp
			hp_t = game_t
		elif game_t - hp_t > 30.0:
			_skip_mob[m.get_instance_id()] = game_t + 60.0
			bot.note("Кардинал: «%s» 30 с без урона — брошен (зверь у (%.1f, %.1f), дом (%.1f, %.1f), идёт домой %s, цель %s; герой у (%.1f, %.1f), до зверя %.1f м, дальность %.1f)" % [
				m.mob_name, m.global_position.x, m.global_position.z, m.home.x, m.home.z, m.returning, m.target,
				p.global_position.x, p.global_position.z, p.global_position.distance_to(m.global_position), p.attack_range])
			break
		var d := p.global_position.distance_to(m.global_position)
		if d > p.attack_range * 0.85 and _flat(p.global_position, m.global_position) > p.attack_range * 0.75:
			# Подойти по сетке пути (ограды, скалы у пещеры), с обходом и переносом, если застрял
			if not await _go(m.global_position, p.attack_range * 0.75, m.mob_name, false):
				break
			if d > p.attack_range * 0.85 + 3.0:
				hp_t = game_t
			continue
		elif d > p.attack_range * 0.85:
			# Рядом по земле, но выше или ниже (склон) — шаг к нему
			_split = "fight"
			_walk(p, h, m.global_position)
		else:
			CardinalMove.stop(p, h)
			if p.current_target != m:
				p.select_target(m)
			if game_t >= sk_t and p.casting == "":
				if _use_skills():
					sk_t = game_t + 0.4
			if p.casting == "":
				p.try_attack()
		_drink_if_low()
		_split = "fight"
		if not await _tick():
			break
	if god_on:
		AdminPanel.god = false
	var p2 := _p()
	if p2 != null:
		CardinalMove.stop(p2, _h())
	var killed := m == null or not is_instance_valid(m) or m.is_dead
	if killed and deaths == deaths0:
		kills += 1
		var sp := m.type_id if is_instance_valid(m) else "?"
		kills_by[sp] = int(kills_by.get(sp, 0)) + 1
		await _loot()
		return true
	return false


## Умения на кнопках: готовое, подходящее оружию, хватает MP — нажать кнопку (одну за тик). true — нажата.
func _use_skills() -> bool:
	var p := _p()
	if p == null or ClassData.is_wanderer(Game.class_id):
		return false
	for slot in ["skill1", "skill2", "skill3", "skill4"]:
		var sid := p.skill_id(slot)
		if sid == "" or not HeroSkills.is_skill(sid) or HeroSkills.kind(sid) != "active" or not HeroSkills.is_ready(sid):
			continue
		if p.slot_block(slot) != "" or float(p.skill_cd.get(sid, 0.0)) > 0.0:
			continue
		var n := HeroSkills.skill_level(Game.hero, sid)
		if n <= 0 or p.mp < HeroSkills.mp_cost(sid, n):
			continue
		if float(_skill_try.get(sid, -1.0)) > game_t:
			continue
		_skill_try[sid] = game_t + 2.0
		_action(slot)
		return true
	return false


## Подобрать мешочек рядом (подходит — LootDrop сам кладёт в сумку в PICKUP_RANGE).
func _loot() -> void:
	var p := _p()
	if p == null:
		return
	var best: Node3D = null
	var bd := 14.0
	for n in _tree.get_nodes_in_group("loot_drops"):
		var l := n as Node3D
		if l == null or l.is_queued_for_deletion():
			continue
		var d := _flat(l.global_position, p.global_position)
		if d < bd:
			bd = d
			best = l
	if best == null:
		return
	var t0 := game_t
	_nav.reset()
	# Мешочек подбирается в кадре отрисовки (LootDrop._process): ждём его исчезновения и не меньше LOOT_MIN с —
	# так следующий шаг начинается на одном и том же тике при любом ускорении (×8 / ×16: кадров разное число)
	while game_t - t0 < 8.0 and _alive():
		_split = "loot"
		var pp := _p()
		var gone := not is_instance_valid(best) or best.is_queued_for_deletion()
		if gone and game_t - t0 >= LOOT_MIN:
			break
		if not gone and _flat(pp.global_position, best.global_position) > 1.2:
			_walk(pp, _h(), best.global_position)
		else:
			CardinalMove.stop(pp, _h())
		if not await _tick():
			return
		if is_instance_valid(best) and not best.is_queued_for_deletion() \
				and _flat(_p().global_position, best.global_position) < 2.0 and game_t - t0 > 3.0:
			break
	CardinalMove.stop(_p(), _h())


const LOOT_MIN := 1.2


## Отдых до rest_until (перемотка, пока рядом нет опасности).
func _rest() -> bool:
	var p := _p()
	if p == null or float(p.hp) >= float(p.max_hp) * float(profile["rest_below"]):
		return true
	CardinalMove.stop(p, _h())
	var t0 := game_t
	var last := p.hp
	while _alive() and float(_p().hp) < float(_p().max_hp) * float(profile["rest_until"]) and game_t - t0 < 120.0:
		_split = "rest"
		var th := _threat()
		if th != null:
			_set_boost(false)
			await _fight(th, "напал на отдыхе")
			continue
		var danger := _p().hp < last
		last = _p().hp
		_set_boost(not danger)
		if not await _tick():
			_set_boost(false)
			return false
	_set_boost(false)
	return true


func _set_boost(on: bool) -> void:
	if on == _boosted or accel <= 1.0:
		_boosted = on and accel > 1.0
		return
	_boosted = on
	Engine.time_scale = accel * (REST_BOOST if on else 1.0)
	Engine.max_physics_steps_per_frame = maxi(8, int(ceil(accel * 4.0)))


# ==================== Звери: поиск ====================

## Ближайший живой зверь по фильтру: виды (пусто — любые), уровни, боссы — только если вид — босс.
func _find_mob(species: Array, lo: int, hi: int, allow_strong: bool = false) -> Mob:
	var p := _p()
	var best: Mob = null
	var bd := INF
	var cap := Game.level + int(profile["level_gap"])
	for n in _tree.get_nodes_in_group("mobs"):
		var m := n as Mob
		if not _mob_alive(m):
			continue
		if float(_skip_mob.get(m.get_instance_id(), -1.0)) > game_t:
			continue
		if not species.is_empty() and not species.has(m.type_id):
			continue
		if species.is_empty() and (m.is_boss or MobData.is_mini_boss(m.type_id)):
			continue
		if m.level < lo or (hi > 0 and m.level > hi):
			continue
		if not allow_strong and not m.is_boss and m.level > cap:
			continue
		if m.is_boss and Game.level < m.level - int(profile["boss_gap"]):
			continue
		var d := _flat(m.global_position, p.global_position)
		if d < bd:
			bd = d
			best = m
	return best


## Есть ли такие звери в мире вообще (живые или нет — по слотам; для причины «застряло»).
func _species_exists(species: Array) -> bool:
	for n in _tree.get_nodes_in_group("mobs"):
		var m := n as Mob
		if m != null and (species.is_empty() or species.has(m.type_id)):
			return true
	return false


## Самый сильный зверь, что водится в мире, из видов species (уровень) — для «ждём уровня».
func _species_max_level(species: Array) -> int:
	var best := 0
	for n in _tree.get_nodes_in_group("mobs"):
		var m := n as Mob
		if m != null and (species.is_empty() or species.has(m.type_id)):
			best = maxi(best, m.level)
	return best


## Убить одного зверя по фильтру. true — убит.
func _kill_one(species: Array, lo: int, hi: int, why: String, allow_strong: bool = false) -> bool:
	var m := _find_mob(species, lo, hi, allow_strong)
	if m == null:
		return false
	if not await _go(m.global_position, maxf(3.0, _p().attack_range * 0.8), m.mob_name):
		return false
	if not _mob_alive(m):
		return true
	var ok: bool = await _fight(m, why)
	if ok:
		await _rest()
	return ok


# ==================== Жители, диалоги, торговля ====================

func _npc_node(npc_id: String) -> Node3D:
	if npc_id == "merchant":
		var e := _eco()
		return e.merchant as Node3D if e != null and is_instance_valid(e.merchant) else null
	var n := _npcs()
	return n.npc(npc_id) if n != null else null


func _npc_pos(npc_id: String) -> Vector3:
	var n := _npc_node(npc_id)
	return n.global_position if n != null else Vector3.INF


func _go_npc(npc_id: String) -> bool:
	var n := _npc_node(npc_id)
	if n == null:
		_find("житель «%s» не стоит в мире" % NpcData.npc_name(npc_id))
		return false
	_split = "walk"
	return await _go(n.global_position, 2.3, NpcData.npc_name(npc_id))


## Подойти и заговорить («Говорить» — ближайший житель). true — диалог с ним открыт.
func _talk(npc_id: String) -> bool:
	if not await _go_npc(npc_id):
		return false
	var nn := _npcs()
	for attempt in 3:
		_close()
		_action("talk")
		if nn.is_dialog_open() and nn.dialog_npc == npc_id:
			_split = "npc"
			return true
		# Рядом другой житель ближе — подойти вплотную
		await _go(_npc_pos(npc_id), 1.4, NpcData.npc_name(npc_id))
		if not await _tick():
			return false
	_find("не открыть диалог с «%s» кнопкой «Говорить» (%s)" % [NpcData.npc_name(npc_id), _last_msg()])
	return false


func _dlg(key: String) -> bool:
	var nn := _npcs()
	return nn != null and _press(nn.buttons, key)


## Окно торговли у NPC (торговец — кнопка «Торговец», остальные — «Торговля» в диалоге). true — открыто.
func _open_shop(npc_id: String) -> bool:
	var eco := _eco()
	if npc_id == "merchant":
		if not await _go_npc("merchant"):
			return false
		_close()
		_action("shop")
	else:
		if not await _talk(npc_id):
			return false
		_dlg("opt_trade")
	_split = "ui"
	if not eco.is_shop_open():
		_find("лавка «%s» не открылась (%s)" % [NpcData.npc_name(npc_id), _last_msg()])
		return false
	return true


## Купить n штук id у NPC (окно торговли: товар → «Купить» / «Купить ×5»). true — куплено столько.
func _buy(npc_id: String, id: String, n: int) -> bool:
	var price := int(ItemData.get_item(id).get("buy", 0)) * n
	if Game.gold < price:
		await _raise_gold(price)
		if Game.gold < price:
			return false
	if not await _open_shop(npc_id):
		return false
	var w := _win()
	var have := Game.inventory.count(id)
	var left := n
	var guard := 0
	while left > 0 and guard < 40:
		guard += 1
		if not _press(w.buttons, "good_" + id):
			_find("у «%s» нет товара «%s»" % [NpcData.npc_name(npc_id), ItemData.item_name(id)])
			break
		var key := "act_buy5" if left >= InventoryWindow.BUY_MANY else "act_buy"
		if not _press(w.buttons, key):
			break
		left = n - (Game.inventory.count(id) - have)
		if not await _tick():
			return false
	_close()
	return Game.inventory.count(id) - have >= n


## Нужно не меньше gold золота: продать лишнее (ближайшему торговцу).
func _raise_gold(gold: int) -> void:
	if Game.gold >= gold:
		return
	if _junk_cells().is_empty():
		return
	await _sell_junk(_nearest_trader())


func _nearest_trader() -> String:
	var p := _p()
	var best := "merchant"
	var bd := INF
	for t in ["merchant", "weaponsmith", "armorer", "jeweler", "kirk", "rare_merchant"]:
		var pos := _npc_pos(t)
		if pos == Vector3.INF:
			continue
		var d := _flat(pos, p.global_position)
		if d < bd:
			bd = d
			best = t
	return best


## Продать лишнее торговцу npc_id: ячейки сумки (кроме нужного заданиям и прокачке) — «Продать все».
func _sell_junk(npc_id: String, at_least: int = 0) -> int:
	var cells := _junk_cells()
	if cells.is_empty() and at_least <= 0:
		return 0
	if not await _open_shop(npc_id):
		return 0
	var w := _win()
	var sold := 0
	var gold0 := Game.gold
	for _i in 60:
		cells = _junk_cells()
		if cells.is_empty():
			break
		var i := int(cells[0])
		if not _press(w.buttons, "cell_%d" % i):
			break
		if not _press(w.buttons, "act_sell_all") and not _press(w.buttons, "act_sell"):
			_skip_sell[String(Game.inventory.cell(i).get("id", ""))] = true
			continue
		sold += 1
		if not await _tick():
			break
	_close()
	if sold > 0:
		_ev("sell", "продано стопок %d (+%d зол.) у «%s»" % [sold, Game.gold - gold0, NpcData.npc_name(npc_id)])
	return sold


var _skip_sell: Dictionary = {}


## Ячейки сумки с лишним: трофеи и лом, которые не нужны несданным заданиям; оружие, броня и украшения, что не
## понадобятся (не надеты, не для питомца, не для цели «надеть»).
func _junk_cells() -> Array:
	var need := _needed_items()
	var res: Array = []
	var inv := Game.inventory
	var keep_weapon := ""
	var keep_body := ""
	for i in inv.cell_count():
		var c := inv.cell(i)
		if c.is_empty():
			continue
		var id := String(c["id"])
		if _skip_sell.has(id) or int(ItemData.get_item(id).get("sell", 0)) <= 0:
			continue
		var t := ItemData.item_type(id)
		match t:
			"trophy":
				if need.has(id) and inv.count(id) <= int(need[id]) + 2:
					continue
			"broken":
				pass
			"weapon":
				if need.has(id) or ItemData.is_shield(id) and _offhand_wanted() and not need.has("@shield_sold"):
					continue
				if keep_weapon == "" and not ItemData.is_shield(id) and ItemData.enchant_level(id) == 0:
					keep_weapon = id
					continue
				if ItemData.enchant_level(id) > 0:
					continue
			"armor":
				if need.has(id) or ItemData.enchant_level(id) > 0:
					continue
				if ItemData.gear_kind(id) == "body" and keep_body == "":
					keep_body = id
					continue
				var sl := ItemData.gear_slots_for(id)
				if not sl.is_empty() and Game.gear_in(String(sl[0])) == "" and ItemData.armor_fits(id, Game.class_id):
					continue
			"jewelry":
				if need.has(id):
					continue
				var sl2 := ItemData.gear_slots_for(id)
				var empty_slot := false
				for s in sl2:
					if Game.gear_in(String(s)) == "":
						empty_slot = true
				if empty_slot:
					continue
			_:
				continue
		res.append(i)
	return res


func _offhand_wanted() -> bool:
	return Quests.can_offhand(Game.class_id) and Game.offhand == ""


## Предметы, нужные несданным заданиям (collect, gather): id → сколько.
func _needed_items() -> Dictionary:
	var res: Dictionary = {}
	var q := _q()
	for k in QuestData.all_ids():
		var id := String(k)
		if q.is_done(id) and not q.is_active(id):
			continue
		for g in QuestData.goals(id):
			var gd: Dictionary = g
			if ["collect", "gather"].has(String(gd.get("type", ""))):
				for it in gd.get("items", []):
					res[String(it)] = int(res.get(String(it), 0)) + QuestData.goal_need(gd)
	return res


# ==================== Задания: взять, сдать ====================

func _qrec(id: String) -> Dictionary:
	if not quests.has(id):
		quests[id] = {"name": QuestData.quest_name(id), "giver": QuestData.giver(id), "taken": -1.0, "done": -1.0,
			"level_taken": 0, "level_done": 0, "status": "not_taken", "reason": "", "reward_ok": null, "reward": "",
			"goals": []}
	return quests[id]


## Хочу ли брать задание (повторяемое — один раз; до профессии — только до неё).
func _want(id: String) -> bool:
	var q := _q()
	if q.times_done(id) > 0:
		return false
	if until_job and not ClassData.is_wanderer(Game.class_id):
		return false
	return true


## Взять доступные задания у NPC (диалог → «Задания» → задание → «Взять задание» → «Назад»).
func _accept_at(npc_id: String) -> int:
	if not await _talk(npc_id):
		return 0
	var q := _q()
	var n := 0
	if not _dlg("opt_quests"):
		_find("у «%s» нет пункта «Задания»" % NpcData.npc_name(npc_id))
		return 0
	for k in q.npc_quests(npc_id):
		var id := String(k)
		if q.state(id) != "available" or not _want(id) or QuestData.giver(id) != npc_id:
			continue
		if not _dlg("dq_" + id):
			continue
		if _dlg("accept") and q.is_active(id):
			var r := _qrec(id)
			r["taken"] = snappedf(game_t, 0.1)
			r["level_taken"] = Game.level
			r["status"] = "active"
			_ev("take", id)
			n += 1
		_dlg("back")
	_close()
	return n


## Сдать готовые задания у NPC (диалог → «Задания» → задание → «Сдать задание»; профессия — окно JobWindow).
func _turn_in_at(npc_id: String) -> int:
	if not await _talk(npc_id):
		return 0
	var q := _q()
	var n := 0
	if not _dlg("opt_quests"):
		return 0
	for k in q.npc_quests(npc_id):
		var id := String(k)
		if q.state(id) != "ready" or QuestData.turn_in(id) != npc_id:
			continue
		if not _dlg("dq_" + id):
			continue
		var before := _reward_snapshot(id)
		var job_q := bool(QuestData.get_quest(id).get("job_choice", false))
		_dlg("complete")
		if job_q:
			await _choose_job(id)
		if q.is_active(id):
			var why := _last_msg()
			_qrec(id)["reason"] = "не сдаётся: " + why
			if why.contains("место"):
				_close()
				await _sell_junk(_nearest_trader())
				return n
			if not job_q:
				_dlg("back")
			continue
		_verify_rewards(id, before)
		n += 1
		if job_q:
			# Окно профессии закрылось — дальше снова через «Говорить»
			break
	_close()
	return n


## Окно выбора профессии: «Выбрать» на карточке профессии job → «Да».
func _choose_job(qid: String) -> void:
	var jw: JobWindow = bot.main.get("job_window") as JobWindow
	if jw == null or not jw.is_open():
		_find("сдача «%s» не открыла окно выбора профессии" % QuestData.quest_name(qid))
		return
	_split = "ui"
	if not _press(jw.buttons, "pick_" + job):
		_find("в окне профессии нет карточки «%s»" % ClassData.job_name(job))
		return
	var jp0 := float(Game.hero.get("jp", 0))
	var lvl0 := Game.level
	if not _press(jw.buttons, "confirm"):
		_find("нет кнопки подтверждения профессии")
		return
	if Game.class_id == job:
		_ev("job", "профессия «%s» на %d ур." % [ClassData.job_name(job), Game.level])
		# Сверх-эволюция: +5 JP за уровень выше 10 (ClassData.over_jp); сверх неё — доля JP за опыт награды
		var over := ClassData.over_jp(lvl0)
		var djp := float(Game.hero.get("jp", 0)) - jp0
		_feature("job", djp + 0.01 >= float(over), "«%s» на %d ур.: JP %+.0f (сверх-эволюция +%d), оружие «%s»" % [
			ClassData.job_name(job), lvl0, djp, over, ItemData.item_name(Game.weapon)])
		_last_skill_level = 0
	else:
		_feature("job", false, "профессия не сменилась (%s)" % _last_msg())
	await _tick()


func _reward_snapshot(id: String) -> Dictionary:
	var r := QuestData.rewards(id)
	var take: Dictionary = {}
	for g in QuestData.goals(id):
		var gd: Dictionary = g
		if ["collect", "gather"].has(String(gd.get("type", ""))) and bool(gd.get("take", false)):
			var left := QuestData.goal_need(gd)
			for it in gd.get("items", []):
				var t := mini(left, Game.inventory.count(String(it)))
				if t > 0:
					take[String(it)] = int(take.get(String(it), 0)) + t
					left -= t
	var counts: Dictionary = {}
	for it in (r.get("items", {}) as Dictionary):
		counts[String(it)] = Game.inventory.count(String(it))
	for it in take:
		counts[String(it)] = Game.inventory.count(String(it))
	return {"rewards": r, "take": take, "counts": counts, "gold": Game.gold,
		"cum": CardinalRun.cumulative_xp(Game.level, Game.xp), "level": Game.level, "jp": float(Game.hero.get("jp", 0))}


## Сверка наград: опыт = rewards.xp (по xp_level), золото = rewards.gold, предметы пришли (с учётом случайной награды
## Quests.last_bonus и забранных предметов целей).
func _verify_rewards(id: String, b: Dictionary) -> void:
	var r: Dictionary = b["rewards"]
	var q := _q()
	var bonus: Dictionary = q.last_bonus
	var bad := PackedStringArray()
	var dxp := CardinalRun.cumulative_xp(Game.level, Game.xp) - int(b["cum"])
	var dgold := Game.gold - int(b["gold"])
	if dxp != int(r.get("xp", 0)):
		bad.append("опыт %+d, ожидалось %+d" % [dxp, int(r.get("xp", 0))])
	if dgold != int(r.get("gold", 0)):
		bad.append("золото %+d, ожидалось %+d" % [dgold, int(r.get("gold", 0))])
	var items: Dictionary = r.get("items", {})
	var raw: Dictionary = QuestData.get_quest(id).get("rewards", {}).get("items", {}) if not QuestData.get_quest(id).has("gen") else {}
	for k in raw:
		if String(k).begins_with("@") and QuestData.resolve_item(String(k)) == "":
			bad.append("заготовка «%s» не превратилась в предмет" % String(k))
	for it in items:
		var want := int(items[it]) + int(bonus.get(it, 0)) - int((b["take"] as Dictionary).get(it, 0))
		var got := Game.inventory.count(String(it)) - int((b["counts"] as Dictionary).get(it, 0))
		if got < want:
			bad.append("«%s» +%d, ожидалось +%d" % [ItemData.item_name(String(it)), got, want])
	for it in (b["take"] as Dictionary):
		if items.has(it):
			continue
		var got2 := Game.inventory.count(String(it)) - int((b["counts"] as Dictionary).get(it, 0))
		var want2 := int(bonus.get(it, 0)) - int((b["take"] as Dictionary)[it])
		if got2 != want2:
			bad.append("забрано «%s» %d, ожидалось %d" % [ItemData.item_name(String(it)), -got2, -want2])
	var rec := _qrec(id)
	rec["done"] = snappedf(game_t, 0.1)
	rec["level_done"] = Game.level
	rec["status"] = "done"
	rec["reason"] = ""
	rec["reward_ok"] = bad.is_empty()
	rec["reward"] = "опыт +%d, золото +%d%s%s" % [dxp, dgold, (", " + LootDrop.describe(items)) if not items.is_empty() else "",
		(" · случайно: " + LootDrop.describe(bonus)) if not bonus.is_empty() else ""]
	if not bad.is_empty():
		rec["reward"] += " ! " + "; ".join(bad)
		_find("награда «%s» не сходится: %s" % [QuestData.quest_name(id), "; ".join(bad)])
	_ev("done", id)


func done_count() -> int:
	var n := 0
	for k in quests:
		if String((quests[k] as Dictionary)["status"]) == "done":
			n += 1
	return n


## Почему задание не сдано (для отчёта): первая невыполненная цель и что решатель о ней думает.
func _why_open(id: String) -> String:
	var q := _q()
	if q == null or not q.is_active(id):
		return q.accept_block(id) if q != null else ""
	var goals := QuestData.goals(id)
	for gi in goals.size():
		if not q.goal_done(id, gi):
			var key := "%s#%d" % [id, gi]
			var st: Dictionary = _goal_state.get(key, {})
			return "цель «%s» %d/%d: %s" % [QuestData.goal_text(goals[gi]), q.goal_progress(id, gi),
				QuestData.goal_need(goals[gi]), String(_stuck_goals.get(key, st.get("why", "не начата")))]
	return "все цели выполнены, не сдано"


# ==================== Планировщик ====================

func run() -> void:
	if not await _tick():
		return
	# Герой постоит секунду: после переноса в деревню физика героя (пол, скорость падения) приходит в одно и то же
	# состояние — прогоны с одним seed начинаются одинаково
	CardinalMove.stop(_p(), _h())
	if not await _wait(1.0):
		return
	while _alive():
		if _finished():
			_end("все задания пройдены" if stop_after.is_empty() and not until_job else "отрезок пройден")
			return
		var acted: bool = await _step()
		if not _alive():
			return
		if acted:
			_idle_plans = 0
		else:
			_idle_plans += 1
			if _idle_plans >= IDLE_PLANS:
				_end("делать больше нечего: оставшиеся цели застряли")
				return
			if not await _wait(1.0):
				return


func _finished() -> bool:
	var q := _q()
	if not stop_after.is_empty():
		for id in stop_after:
			if not q.is_done(String(id)):
				return false
		return true
	if until_job:
		return not ClassData.is_wanderer(Game.class_id)
	return _quests_finished() and _features_done()


func _quests_finished() -> bool:
	var q := _q()
	for k in QuestData.all_ids():
		var id := String(k)
		if not q.is_done(id) and not (_quest_given_up(id)):
			return false
	return true


## Задание, у которого все невыполненные цели застряли (или взять нельзя по данным) — дальше не ждём.
func _quest_given_up(id: String) -> bool:
	var q := _q()
	if q.is_active(id):
		var goals := QuestData.goals(id)
		for gi in goals.size():
			if not q.goal_done(id, gi) and not _stuck_goals.has("%s#%d" % [id, gi]):
				return false
		return not q.is_ready(id)
	return String(_qrec(id).get("status", "")) == "stuck"


## Один шаг плана. true — что-то сделано.
func _step() -> bool:
	var q := _q()
	var p := _p()
	if p == null:
		return false
	# 0. Сумка почти полна — продать лишнее
	var inv := Game.inventory
	if inv.capacity - inv.used_cells() < int(profile["bag_reserve"]):
		if not _junk_cells().is_empty():
			_last_plan = "sell"
			return await _sell_junk(_nearest_trader()) > 0
		if not _stash_tried:
			_stash_tried = true
			_last_plan = "stash"
			return await _stash()
	else:
		_stash_tried = false
	# 1. Восстановиться: HP, погибший питомец, питомец не призван
	if float(p.hp) < float(p.max_hp) * float(profile["rest_below"]):
		return await _rest()
	if await _care_pet():
		return true
	# 2. Умения героя и питомца, фичи
	if await _maybe_learn_skills():
		return true
	if await _maybe_learn_pet():
		return true
	if await _features():
		return true
	# 3. Самое дешёвое по пути: сдать готовое, взять доступное, цель взятого задания (цена — путь; сдать и взять —
	# со скидкой: открывают цепочки; Бродяге задания пути к профессии — вчетверо дешевле). Раньше сдача и взятие шли
	# первыми — герой метался через весь остров за каждым «=» и «!» (в пути 55 % игрового времени)
	var turn := _nearest_npc_cost(func(id: String) -> bool: return q.state(id) == "ready", true)
	var take := _nearest_npc_cost(func(id: String) -> bool: return q.state(id) == "available" and _want(id), false)
	var task := _pick_goal()
	var best := "goal" if not task.is_empty() else ""
	var bc := float(task.get("cost", INF)) if not task.is_empty() else INF
	if String(turn[0]) != "" and float(turn[1]) * TURN_IN_K <= bc:
		best = "turn"
		bc = float(turn[1]) * TURN_IN_K
	if String(take[0]) != "" and float(take[1]) * ACCEPT_K <= bc:
		best = "take"
	match best:
		"turn":
			_last_plan = "turn_in " + String(turn[0])
			return await _turn_in_at(String(turn[0])) > 0
		"take":
			_last_plan = "accept " + String(take[0])
			return await _accept_at(String(take[0])) > 0
		"goal":
			_last_plan = "goal %s" % String(task.get("key", ""))
			return await _do_goal(task)
	# 6. Задания ждут уровня (или цели — сильнее героя) — прокачка
	if _need_levels():
		_last_plan = "grind"
		return await _grind()
	# 7. Задания пройдены — питомцу до эволюции и пояса
	if _quests_finished() and not _features_done():
		_last_plan = "pet_phase"
		return await _pet_phase()
	return false


## Скидка пути к сдающему и выдающему (см. _step).
const TURN_IN_K := 0.5
const ACCEPT_K := 0.6


## [NPC, цена] — ближайший NPC с заданием cond (turn — сдать ему, иначе — взять у него); цена — путь, у заданий пути
## к профессии (Бродяга) — вчетверо меньше. ["", INF] — нет такого.
func _nearest_npc_cost(cond: Callable, turn: bool) -> Array:
	var p := _p()
	var best := ""
	var bd := INF
	for k in QuestData.all_ids():
		var id := String(k)
		if not bool(cond.call(id)):
			continue
		var npc := QuestData.turn_in(id) if turn else QuestData.giver(id)
		if not turn and _qrec(id).get("status") == "stuck":
			continue
		var pos := _npc_pos(npc)
		if pos == Vector3.INF:
			continue
		var d := _flat(pos, p.global_position)
		if ClassData.is_wanderer(Game.class_id) and (QuestData.PRE_JOB.has(id) or id == QuestData.JOB_QUEST):
			d *= 0.25
		if d < bd:
			bd = d
			best = npc
	return [best, bd]


## Ближайший NPC, у которого есть задание со свойством cond (turn — сдать ему, иначе — взять у него).
func _nearest_npc_with(cond: Callable, turn: bool) -> String:
	var p := _p()
	var best := ""
	var bd := INF
	for k in QuestData.all_ids():
		var id := String(k)
		if not bool(cond.call(id)):
			continue
		var npc := QuestData.turn_in(id) if turn else QuestData.giver(id)
		if not turn and _qrec(id).get("status") == "stuck":
			continue
		var pos := _npc_pos(npc)
		if pos == Vector3.INF:
			_qrec(id)["status"] = "stuck"
			_qrec(id)["reason"] = "житель «%s» не стоит в мире" % npc
			continue
		var d := _flat(pos, p.global_position)
		if d < bd:
			bd = d
			best = npc
	return best


## Нужен уровень: есть задания, закрытые только уровнем, или цели, отложенные «зверь сильнее героя».
func _need_levels() -> bool:
	var q := _q()
	for k in QuestData.all_ids():
		var id := String(k)
		if _want(id) and q.level_locked(id):
			return true
	for key in _goal_state:
		var qid := String(key).get_slice("#", 0)
		var gi := int(String(key).get_slice("#", 1))
		if not q.is_active(qid) or q.goal_done(qid, gi) or _stuck_goals.has(key):
			continue
		if String((_goal_state[key] as Dictionary).get("why", "")).begins_with("ждём уровня"):
			return true
	return false


## Прокачка: зверь по силам с лучшим опытом рядом.
func _grind() -> bool:
	var p := _p()
	var best: Mob = null
	var bs := -INF
	for n in _tree.get_nodes_in_group("mobs"):
		var m := n as Mob
		if not _mob_alive(m) or m.is_boss or MobData.is_mini_boss(m.type_id):
			continue
		if m.level > Game.level + int(profile["level_gap"]) or float(_skip_mob.get(m.get_instance_id(), -1.0)) > game_t:
			continue
		var d := _flat(m.global_position, p.global_position)
		var s := float(Combat.xp_for(m.xp_reward, m.level, Game.level)) / (d + 25.0)
		if s > bs:
			bs = s
			best = m
	if best == null:
		return false
	if not await _go(best.global_position, maxf(3.0, _p().attack_range * 0.8), best.mob_name):
		return false
	return await _fight(best, "прокачка")


# ==================== Решатели целей ====================

## Лучшая невыполненная цель взятых заданий: {key, quest, gi, kind, cost, …}.
func _pick_goal() -> Dictionary:
	var q := _q()
	var best: Dictionary = {}
	var bc := INF
	for k in q.active_ids():
		var id := String(k)
		var goals := QuestData.goals(id)
		for gi in goals.size():
			if q.goal_done(id, gi):
				continue
			var key := "%s#%d" % [id, gi]
			if _stuck_goals.has(key):
				continue
			var t := _solve(id, gi, goals[gi])
			var st: Dictionary = _goal_state.get(key, {"tries": 0, "prog": -1, "why": ""})
			st["why"] = String(t.get("why", ""))
			_goal_state[key] = st
			if not t.has("kind"):
				continue
			t["key"] = key
			t["quest"] = id
			t["gi"] = gi
			var c := float(t.get("cost", 0.0))
			# Бродяга сначала идёт к профессии (умения и оружие профессии ускоряют всё остальное)
			if ClassData.is_wanderer(Game.class_id) and (QuestData.PRE_JOB.has(id) or id == QuestData.JOB_QUEST):
				c *= 0.25
			if c < bc:
				bc = c
				best = t
	return best


## Решатель цели g (задание id, номер gi): {kind, cost, …} — что делать; {why} — почему пока нельзя.
func _solve(id: String, gi: int, g: Dictionary) -> Dictionary:
	var q := _q()
	var p := _p()
	var type := String(g.get("type", ""))
	var need := QuestData.goal_need(g)
	var have := q.goal_progress(id, gi)
	match type:
		"kill":
			var sp := QuestData.goal_species(g)
			var lo := int(g.get("min_level", 0))
			var hi := int(g.get("max_level", 0))
			return _kill_task(sp, lo, hi)
		"pet_kill":
			if not _pet_out():
				return {"why": "нет призванного питомца"}
			var t := _kill_task(QuestData.goal_species(g), 0, 0)
			return t
		"collect":
			var items: Array = g.get("items", [])
			var df := String(g.get("drop_from", ""))
			if df != "":
				return _kill_task([df], 0, 0)
			var src: Array = []
			for it in items:
				for s in _droppers(String(it)):
					if not src.has(s):
						src.append(s)
			if src.is_empty():
				return {"why": "предмет «%s» ни с кого не падает и не продаётся" % ItemData.item_name(String(items[0]))}
			var t2 := _kill_task(src, 0, 0)
			t2["cost"] = float(t2.get("cost", 0.0)) + 30.0
			return t2
		"gather":
			return {"kind": "gather", "cost": _dist_finds(String(g.get("zone", "")))}
		"buy":
			var npc := String(g.get("npc", ""))
			var it := _buy_choice(g)
			if it == "":
				return {"why": "нечего купить по условию"}
			if npc == "":
				var s2 := NpcData.sellers_of(it)
				npc = String(s2[0]) if not s2.is_empty() else "merchant"
			var price := int(ItemData.get_item(it).get("buy", 0)) * (need - have)
			if Game.gold < price and _junk_cells().is_empty():
				return {"why": "ждём золота: «%s» за %d" % [ItemData.item_name(it), price]}
			return {"kind": "buy", "npc": npc, "item": it, "n": need - have, "cost": _npc_dist(npc)}
		"sell":
			var npc2 := String(g.get("npc", ""))
			if npc2 == "":
				npc2 = _nearest_trader()
			return {"kind": "sell", "npc": npc2, "n": need - have, "items": g.get("items", []), "cost": _npc_dist(npc2)}
		"use":
			return {"kind": "use", "cost": 5.0}
		"store":
			return {"kind": "store", "cost": _npc_dist(Economy.STORAGE_NPC)}
		"level":
			return {"why": "ждём уровня %d" % need}
		"skill":
			if ClassData.is_wanderer(Game.class_id):
				return {"why": "нужна профессия"}
			return {"kind": "learn", "cost": 1.0}
		"tame":
			return _tame_task(String(g.get("target", "")))
		"form":
			var card := _soul_card(String(g.get("target", "")))
			if card == "":
				return {"why": "нет карты с душой"}
			return {"kind": "form", "card": card, "cost": 1.0}
		"summon":
			if Game.pets.is_empty():
				return {"why": "нет питомцев"}
			return {"kind": "summon", "cost": 1.0}
		"talk":
			var who := QuestData.goal_npc(g)
			return {"kind": "talk", "npc": who, "cost": _npc_dist(who)}
		"equip":
			return _equip_task(g)
		"upgrade":
			return _upgrade_task(g)
		"pet_skill":
			if Game.pets.is_empty():
				return {"why": "нет питомцев"}
			if _pet_learnable() == "":
				return {"why": "ждём уровня питомца (нет JP или доступных умений)"}
			return {"kind": "pet_learn", "cost": 1.0}
		"pet_gear":
			return _pet_gear_task()
		"quest":
			return {"why": "ждём сдачи «%s»" % QuestData.quest_name(String(g.get("id", "")))}
	return {"why": "неизвестный вид цели «%s»" % type}


func _npc_dist(npc_id: String) -> float:
	var pos := _npc_pos(npc_id)
	return _flat(pos, _p().global_position) if pos != Vector3.INF else 1.0e6


## Задача «убить» по фильтру: ближайший подходящий зверь, иначе — почему нельзя.
func _kill_task(species: Array, lo: int, hi: int) -> Dictionary:
	var m := _find_mob(species, lo, hi)
	if m != null and ClassData.is_wanderer(Game.class_id) and (m.is_boss or MobData.is_mini_boss(m.type_id)):
		return {"why": "ждём профессии: «%s» — вожак" % m.mob_name}
	if m != null:
		return {"kind": "kill", "species": species, "lo": lo, "hi": hi, "cost": _flat(m.global_position, _p().global_position)}
	if not _species_exists(species):
		return {"why": "таких зверей нет в мире: %s" % ", ".join(PackedStringArray(species))}
	var strong := _find_mob(species, lo, hi, true)
	if strong != null:
		return {"why": "ждём уровня: ближайший %s %d ур." % [strong.type_id, strong.level]}
	var mx := _species_max_level(species)
	if lo > 0 and mx < lo:
		return {"why": "в мире нет %s %d+ ур. (самый сильный — %d)" % [", ".join(PackedStringArray(species)), lo, mx]}
	return {"why": "ждём возрождения: %s" % ", ".join(PackedStringArray(species))}


## С каких зверей падает предмет (MobData.materials).
func _droppers(item: String) -> Array:
	var res: Array = []
	for k in MobData.TYPES:
		var sp := String(k)
		if MobData.is_boss(sp):
			continue
		if MobData.materials(sp).has(item) and _species_exists([sp]):
			res.append(sp)
	return res


func _dist_finds(zone: String) -> float:
	var q := _q()
	var p := _p()
	var bd := INF
	for f in q.finds():
		bd = minf(bd, _flat((f as Node3D).global_position, p.global_position))
	if bd < INF:
		return bd
	var w := IslandWorld.current
	for z in w.cfg.get("mob_zones", []):
		if String((z as Dictionary).get("id", "")) == zone:
			var c := IslandWorld.v2((z as Dictionary)["center"])
			return _flat(Vector3(c.x, 0, c.y), p.global_position)
	return 500.0


## Что купить для цели buy: предметы цели (дешёвый), иначе дешёвый товар продавца (fits — подходящее оружие).
func _buy_choice(g: Dictionary) -> String:
	var npc := String(g.get("npc", ""))
	var items: Array = g.get("items", [])
	var cand: Array = []
	if not items.is_empty():
		cand = items
	elif npc != "":
		cand = InventoryWindow.goods(Game.class_id, npc)
	var best := ""
	var bp := 1 << 30
	for e in cand:
		var it := String(e)
		if bool(g.get("fits", false)) and not ItemData.weapon_fits(it, Game.class_id):
			continue
		var price := int(ItemData.get_item(it).get("buy", 0))
		if price > 0 and price < bp:
			bp = price
			best = it
	return best


func _soul_card(species: String) -> String:
	for k in Game.inventory.ids():
		var it := String(k)
		if ItemData.is_soul_card(it) and (species == "" or ItemData.card_species(it) == species):
			return it
	return ""


## Приручить: пустая карта в сумке и такой зверь рядом; нет карты — купить у Кирка.
func _tame_task(species: String) -> Dictionary:
	var cards: Array = []
	for k in Game.inventory.ids():
		var it := String(k)
		if ItemData.is_empty_card(it) and (species == "" or ItemData.card_species(it) == species):
			cards.append(ItemData.card_species(it))
	if cards.is_empty():
		var sp := species if species != "" else "pheasant"
		var card := ItemData.card_for(sp)
		var price := int(ItemData.get_item(card).get("buy", 0))
		if Game.gold < price:
			return {"why": "ждём золота на «%s» (%d)" % [ItemData.item_name(card), price]}
		return {"kind": "buy", "npc": "kirk", "item": card, "n": 1, "cost": _npc_dist("kirk") + 20.0}
	# Самая сговорчивая карта (шанс выше)
	var best_sp := String(cards[0])
	for c in cards:
		if Taming.CHANCE.get(ItemData.card_tier(ItemData.card_for(String(c))), 0.0) > Taming.CHANCE.get(ItemData.card_tier(ItemData.card_for(best_sp)), 0.0):
			best_sp = String(c)
	var m := _find_mob([best_sp], 0, 0)
	if m == null:
		return {"why": "нет живого «%s» по силам" % best_sp}
	return {"kind": "tame", "species": best_sp, "cost": _flat(m.global_position, _p().global_position)}


## Что надеть для цели equip: в сумке подходящая вещь — надеть; нет — купить в лавке.
func _equip_task(g: Dictionary) -> Dictionary:
	for e in g.get("slots", []):
		var entry := String(e)
		if Quests._slot_item(entry, 0) != "":
			continue
		var slot := entry.split("|")[0]
		var have := _bag_item_for(slot)
		if have != "":
			return {"kind": "equip", "item": have, "slot": slot, "cost": 2.0}
		if slot == "offhand":
			return _offhand_task()
		var buy := _shop_item_for(slot)
		if buy.is_empty():
			return {"why": "в лавках нет вещи для ячейки «%s»" % slot}
		var price := int(ItemData.get_item(String(buy[1])).get("buy", 0))
		if Game.gold < price and _junk_cells().is_empty():
			return {"why": "ждём золота на «%s» (%d)" % [ItemData.item_name(String(buy[1])), price]}
		return {"kind": "buy", "npc": buy[0], "item": buy[1], "n": 1, "cost": _npc_dist(String(buy[0]))}
	return {"why": "всё надето — ждём опроса"}


## Вещь из сумки для ячейки slot (подходит профессии и уровню).
func _bag_item_for(slot: String) -> String:
	for k in Game.inventory.ids():
		var it := String(k)
		if ItemData.is_broken(it) or ItemData.level_block(it, Game.level) != "":
			continue
		if slot == "offhand":
			if Game.offhand_block(it) == "" and Enchant.free_count(it) > 0:
				return it
			continue
		if slot == "weapon":
			if ItemData.is_weapon(it) and not ItemData.is_shield(it) and ItemData.weapon_fits(it, Game.class_id):
				return it
			continue
		if ItemData.gear_slots_for(it).has(slot) and Game.gear_block(it, slot) == "":
			return it
	return ""


## Вторая рука: щит к одноручному или второй такой же клинок; в руках двуручное — сменить на одноручное профессии,
## которое она держит парой (или с щитом). {kind: "offhand_setup", main, off}.
func _offhand_task() -> Dictionary:
	var wk := ClassData.weapons(Game.class_id)
	var goods := InventoryWindow.goods(Game.class_id, "weaponsmith")
	var cheapest := func(kind: String) -> String:
		var best := ""
		var bp := 1 << 30
		for e in goods:
			var it := String(e)
			if ItemData.weapon_kind(it) == kind and ItemData.level_block(it, Game.level) == "":
				var pr := int(ItemData.get_item(it).get("buy", 0))
				if pr < bp:
					bp = pr
					best = it
		return best
	var shield := String(cheapest.call("shield")) if wk.has("shield") else ""
	var cur_kind := ItemData.weapon_kind(Game.weapon) if Game.weapon != "" else ""
	if cur_kind != "" and ItemData.is_one_handed(cur_kind):
		if shield != "":
			return {"kind": "offhand_setup", "main": Game.weapon, "off": shield, "cost": _npc_dist("weaponsmith")}
		var pk := ItemData.pair_kind(cur_kind)
		if pk != "" and wk.has(pk):
			return {"kind": "offhand_setup", "main": Game.weapon, "off": ItemData.base_id(Game.weapon), "cost": _npc_dist("weaponsmith")}
	for k in wk:
		var kind := String(k)
		if ["daggers", "dual_swords", "dual_axes"].has(kind):
			var one := String(cheapest.call(ItemData.single_kind(kind)))
			if one != "":
				return {"kind": "offhand_setup", "main": one, "off": one, "cost": _npc_dist("weaponsmith")}
	if shield != "":
		for k in wk:
			if ItemData.is_one_handed(String(k)) and String(k) != "shield":
				var one2 := String(cheapest.call(String(k)))
				if one2 != "":
					return {"kind": "offhand_setup", "main": one2, "off": shield, "cost": _npc_dist("weaponsmith")}
	return {"why": "профессия не держит вторую руку"}


## Сменить оружие на main (из сумки, нет — купить у оружейника) и надеть off во вторую руку.
func _offhand_setup(main_id: String, off_id: String) -> bool:
	var need_main := 0 if Game.weapon == main_id else 1
	var need_off := 1
	var want := {}
	want[main_id] = need_main
	want[off_id] = int(want.get(off_id, 0)) + need_off
	for id in want:
		var miss := int(want[id]) - Enchant.free_count(String(id))
		if miss > 0 and not await _buy("weaponsmith", String(id), miss):
			return false
	if Game.weapon != main_id and not await _equip(main_id, "weapon"):
		return false
	var ok: bool = await _equip(off_id, "offhand")
	_ev("equip", "вторая рука: %s + %s — %s" % [ItemData.item_name(main_id), ItemData.item_name(off_id), "да" if ok else "нет"])
	_last_skill_level = 0
	return ok


## [NPC, предмет] — где купить вещь для ячейки slot.
func _shop_item_for(slot: String) -> Array:
	var npc := "armorer"
	if ["ring1", "ring2", "earring", "pendant", "belt"].has(slot):
		npc = "jeweler"
	elif slot == "offhand" or slot == "weapon":
		npc = "weaponsmith"
	elif slot == "bag":
		npc = "merchant"
	var best := ""
	var bp := 1 << 30
	for e in InventoryWindow.goods(Game.class_id, npc):
		var it := String(e)
		var fits := false
		if slot == "offhand":
			# Щит или второй такой же клинок (пара)
			fits = (ItemData.is_shield(it) and ItemData.weapon_fits(it, Game.class_id)) or \
				(Game.weapon != "" and ItemData.base_id(it) == ItemData.base_id(Game.weapon) \
				and ItemData.pair_kind(ItemData.weapon_kind(it)) != "")
		elif slot == "weapon":
			fits = ItemData.is_weapon(it) and ItemData.weapon_fits(it, Game.class_id) and not ItemData.is_shield(it)
		else:
			fits = ItemData.gear_slots_for(it).has(slot) and ItemData.armor_fits(it, Game.class_id) \
				and ItemData.level_block(it, Game.level) == ""
		if not fits:
			continue
		var price := int(ItemData.get_item(it).get("buy", 0))
		if price < bp:
			bp = price
			best = it
	return [npc, best] if best != "" else []


## Заточка для цели upgrade: пусто в ячейке — надеть; куб в сумке и шанс 100 % — крафт; иначе закалка у кузнеца.
func _upgrade_task(g: Dictionary) -> Dictionary:
	var plus := int(g.get("plus", 1))
	for e in g.get("slots", []):
		var entry := String(e)
		if Quests._slot_item(entry, plus) != "":
			continue
		var slot := entry.split("|")[0]
		var cur := Enchant.equipped_in(slot)
		if cur == "":
			var t := _equip_task({"slots": [slot]})
			return t
		var cube := _cube_for(cur, true)
		if cube != "":
			return {"kind": "craft", "slot": slot, "item": cur, "cube": cube, "cost": 3.0}
		var price := Enchant.temper_price(cur)
		if Enchant.temper_block(cur) != "":
			return {"why": "закалка: %s" % Enchant.temper_block(cur)}
		if Game.gold < price and _junk_cells().is_empty():
			return {"why": "ждём золота на закалку (%d)" % price}
		return {"kind": "temper", "slot": slot, "item": cur, "cost": _npc_dist(Enchant.SMITH_NPC)}
	return {"why": "всё заточено — ждём опроса"}


## Куб из сумки для вещи item (sure — только если шанс 100 %).
func _cube_for(item: String, sure: bool) -> String:
	for k in Game.inventory.ids():
		var c := String(k)
		if ItemData.is_cube(c) and Enchant.cube_block(item, c) == "":
			if sure and Enchant.chance(item, c, false) < 0.999:
				continue
			return c
	return ""


## Снаряжение питомцу: «Знаток снаряжения», карта снаряжения, вещь (оружие не щит / доспех).
func _pet_gear_task() -> Dictionary:
	if Game.pets.is_empty():
		return {"why": "нет питомцев"}
	var i := _main_pet()
	var rec: Dictionary = Game.pets[i]
	if PetGear.expert(rec) <= 0.0:
		var ex := "item_expert_" + String(rec.get("species", ""))
		if PetSkills.learn_block(rec, ex) != "":
			return {"why": "«Знаток снаряжения» не изучить: %s" % PetSkills.learn_block(rec, ex)}
		return {"kind": "pet_learn", "skill": ex, "cost": 1.0}
	if not Game.inventory.has(PetGear.UNIT_CARD):
		return {"kind": "buy", "npc": "kirk", "item": PetGear.UNIT_CARD, "n": 1, "cost": _npc_dist("kirk")}
	var w := _pet_weapon_item(rec)
	if w == "":
		var buy := _shop_item_for("weapon")
		if buy.is_empty():
			return {"why": "нет оружия для питомца"}
		return {"kind": "buy", "npc": buy[0], "item": buy[1], "n": 1, "cost": _npc_dist(String(buy[0]))}
	return {"kind": "pet_gear", "pet": i, "item": w, "cost": 2.0}


func _pet_weapon_item(rec: Dictionary) -> String:
	for k in Game.inventory.ids():
		var it := String(k)
		if PetGear.slot_for(it) == "weapon" and PetGear.equip_block(rec, it) == "":
			return it
	return ""


func _main_pet() -> int:
	if Game.active_pet >= 0 and Game.active_pet < Game.pets.size():
		return Game.active_pet
	var best := 0
	for i in Game.pets.size():
		if int(Game.pets[i].get("level", 1)) > int(Game.pets[best].get("level", 1)):
			best = i
	return best


func _pet_out() -> bool:
	var pm := _pm()
	return pm != null and is_instance_valid(pm.active_pet) and not pm.active_pet.is_down


# ==================== Исполнение цели ====================

func _do_goal(t: Dictionary) -> bool:
	var key := String(t["key"])
	var id := String(t["quest"])
	var gi := int(t["gi"])
	var q := _q()
	var before := q.goal_progress(id, gi)
	var ok := false
	match String(t["kind"]):
		"kill":
			ok = await _kill_one(t["species"], int(t["lo"]), int(t["hi"]), "задание «%s»" % QuestData.quest_name(id))
		"gather":
			ok = await _gather(id, gi)
		"buy":
			ok = await _buy(String(t["npc"]), String(t["item"]), int(t["n"]))
		"sell":
			ok = await _sell_for_goal(String(t["npc"]), int(t["n"]), t.get("items", []))
		"use":
			ok = await _hurt_and_drink()
		"store":
			ok = await _storage_trip(true)
		"learn":
			ok = await _learn_skills(true)
		"tame":
			ok = await _tame(String(t["species"]))
		"form":
			ok = await _form(String(t["card"]))
		"summon":
			ok = await _summon()
		"talk":
			ok = await _talk(String(t["npc"]))
			_close()
		"equip":
			ok = await _equip(String(t["item"]), String(t["slot"]))
		"offhand_setup":
			ok = await _offhand_setup(String(t["main"]), String(t["off"]))
		"craft":
			ok = await _craft(String(t["slot"]), String(t["cube"]))
		"temper":
			ok = await _temper(String(t["slot"]))
		"pet_learn":
			ok = await _learn_pet(String(t.get("skill", "")))
		"pet_gear":
			ok = await _pet_gear(int(t["pet"]), String(t["item"]))
	if not _alive():
		return false
	# Опрос заданий (цели-состояния) — как раз в 0.5 с; не ждём его, считаем по факту
	q.poll(0.0)
	var after := q.goal_progress(id, gi)
	var st: Dictionary = _goal_state.get(key, {"tries": 0})
	if after > before or q.goal_done(id, gi):
		st["tries"] = 0
	else:
		st["tries"] = int(st.get("tries", 0)) + 1
		if int(st["tries"]) >= int(profile["goal_tries"]) and not ["kill", "gather"].has(String(t["kind"])):
			_stuck_goals[key] = "%d попыток «%s» без прогресса (%s)" % [int(st["tries"]), String(t["kind"]), _last_msg()]
			_qrec(id)["reason"] = String(_stuck_goals[key])
			_find("задание «%s», цель «%s»: %s" % [QuestData.quest_name(id), QuestData.goal_text(QuestData.goals(id)[gi]),
				String(_stuck_goals[key])])
		elif int(st["tries"]) >= int(profile["goal_tries"]) * 6:
			_stuck_goals[key] = "%d попыток «%s» без прогресса" % [int(st["tries"]), String(t["kind"])]
			_qrec(id)["reason"] = String(_stuck_goals[key])
			_find("задание «%s»: %s" % [QuestData.quest_name(id), String(_stuck_goals[key])])
	_goal_state[key] = st
	return ok


## Сбор находок (QuestFind): к ближайшей светящейся траве; нет в мире — к зоне цели.
func _gather(id: String, gi: int) -> bool:
	var q := _q()
	var p := _p()
	var best: Node3D = null
	var bd := INF
	for f in q.finds():
		var fn := f as Node3D
		var d := _flat(fn.global_position, p.global_position)
		if d < bd:
			bd = d
			best = fn
	if best == null:
		var zone := String((QuestData.goals(id)[gi] as Dictionary).get("zone", ""))
		for z in IslandWorld.current.cfg.get("mob_zones", []):
			if String((z as Dictionary).get("id", "")) == zone:
				var c := IslandWorld.v2((z as Dictionary)["center"])
				await _go(IslandWorld.current.ground(c.x, c.y), 4.0, "зона «%s»" % zone)
		# Все сорваны — ждём, пока вырастет новая (Quests.FIND_RESPAWN), одной попыткой, а не по секунде: иначе
		# ожидание засчитывалось как «попытки без прогресса» (48 за прогон)
		var t0 := game_t
		while q.finds().is_empty() and game_t - t0 < Quests.FIND_RESPAWN + 2.0:
			if not await _tick():
				return false
		return false
	var item := String(best.get("item"))
	var have := Game.inventory.count(item)
	await _go(best.global_position, 1.2, "находка")
	await _wait(0.7)
	return Game.inventory.count(item) > have


## Цель «продать»: продать лишнее, нет лишнего — дешёвое зелье (купить и продать тому же NPC).
func _sell_for_goal(npc_id: String, n: int, items: Array) -> bool:
	var sold := await _sell_junk(npc_id)
	if sold >= n:
		return true
	if not await _open_shop(npc_id):
		return false
	var w := _win()
	for _i in n:
		var cell := -1
		for i in Game.inventory.cell_count():
			var c := Game.inventory.cell(i)
			if c.is_empty():
				continue
			var it := String(c["id"])
			if (items.is_empty() or items.has(it)) and ItemData.item_type(it) == "consumable" and int(ItemData.get_item(it).get("sell", 0)) > 0 \
					and ItemData.is_potion(it):
				cell = i
				break
		if cell < 0:
			break
		_press(w.buttons, "cell_%d" % cell)
		_press(w.buttons, "act_sell")
		await _tick()
	_close()
	return true


## Цель «выпить зелье»: ранен — «Зелье»; не ранен — бой со слабым зверем до раны.
func _hurt_and_drink() -> bool:
	var p := _p()
	if Economy.best_potion("hp") == "":
		await _buy("merchant", "potion_hp_r1", 3)
	for _i in 6:
		if not _alive():
			return false
		if _p().hp < _p().max_hp:
			var eco := _eco()
			while eco.potion_cooldown_frac() > 0.0:
				if not await _tick():
					return false
			_action("potion")
			return true
		var m := _find_mob([], 0, Game.level + 1)
		if m == null:
			return false
		await _go(m.global_position, 3.0, m.mob_name)
		# Подставиться под удар: бить, пока не ранит (умения в стороне — пусть ударит)
		var t0 := game_t
		while _alive() and _mob_alive(m) and _p().hp >= _p().max_hp and game_t - t0 < 30.0:
			var pp := _p()
			if pp.global_position.distance_to(m.global_position) > pp.attack_range * 0.85:
				_walk(pp, _h(), m.global_position)
			else:
				CardinalMove.stop(pp, _h())
				pp.select_target(m)
				if game_t - t0 > 3.0:
					pp.try_attack()
			if not await _tick():
				return false
		CardinalMove.stop(_p(), _h())
	return false


## Склад: диалог Тобина → «Склад» → вещь из сумки «На склад»; back — забрать обратно (и золото туда-обратно).
func _storage_trip(back: bool) -> bool:
	if not await _talk(Economy.STORAGE_NPC):
		return false
	if not _dlg("opt_storage"):
		_find("у кладовщика нет пункта «Склад»")
		return false
	var eco := _eco()
	var w := _win()
	if not eco.is_storage_open():
		_find("склад не открылся (%s)" % _last_msg())
		return false
	_split = "ui"
	# Что положить: трофей или зелье (не нужное заданиям)
	var cell := -1
	var item := ""
	var need := _needed_items()
	for i in Game.inventory.cell_count():
		var c := Game.inventory.cell(i)
		if c.is_empty():
			continue
		var it := String(c["id"])
		if (ItemData.item_type(it) == "trophy" and not need.has(it)) or ItemData.is_potion(it):
			cell = i
			item = it
			break
	if cell < 0:
		_close()
		return false
	var bag0 := Game.inventory.count(item)
	var st0 := Game.storage.count(item)
	_press(w.buttons, "cell_%d" % cell)
	_press(w.buttons, "act_store")
	var stored := Game.storage.count(item) - st0
	var ok := stored == 1 and Game.inventory.count(item) == bag0 - 1
	var txt := "«%s»: на склад %d" % [ItemData.item_name(item), stored]
	if back and ok:
		var sc := Game.storage.find_cell(item)
		_press(w.buttons, "store_%d" % sc)
		_press(w.buttons, "act_take")
		var ok2 := Game.storage.count(item) == st0 and Game.inventory.count(item) == bag0
		txt += ", обратно — %s" % ("да" if ok2 else "нет")
		ok = ok and ok2
		# Золото туда-обратно
		if Game.gold >= 100:
			var g0 := Game.gold
			var sg0 := Game.storage_gold
			_press(w.buttons, "gold_put_100")
			var put_ok := Game.gold == g0 - 100 and Game.storage_gold == sg0 + 100
			_press(w.buttons, "gold_take_100")
			var take_ok := Game.gold == g0 and Game.storage_gold == sg0
			txt += ", золото 100 туда — %s, обратно — %s" % ["да" if put_ok else "нет", "да" if take_ok else "нет"]
			ok = ok and put_ok and take_ok
	_feature("storage", ok, txt)
	_close()
	return stored > 0


var _stash_tried := false


## Сумка полна, продать нечего: на склад — вещи, что не нужны сейчас (трофеи, оружие, броня, украшения, не надетые).
func _stash() -> bool:
	if not await _talk(Economy.STORAGE_NPC):
		return false
	if not _dlg("opt_storage"):
		return false
	var w := _win()
	var need := _needed_items()
	var n := 0
	for _i in 40:
		var cell := -1
		for i in Game.inventory.cell_count():
			var c := Game.inventory.cell(i)
			if c.is_empty():
				continue
			var it := String(c["id"])
			var t := ItemData.item_type(it)
			if (t == "trophy" and not need.has(it)) or ["weapon", "armor", "jewelry", "broken"].has(t):
				cell = i
				break
		if cell < 0 or Game.storage.used_cells() >= Game.storage.capacity:
			break
		_press(w.buttons, "cell_%d" % cell)
		if not _press(w.buttons, "act_store_all") and not _press(w.buttons, "act_store"):
			break
		n += 1
	_close()
	_ev("stash", "на склад стопок %d" % n)
	return n > 0


## Изучить умения профессии в окне героя (K): атакующие — сперва, на кнопки 1–4. need — цель «изучить».
func _maybe_learn_skills() -> bool:
	if ClassData.is_wanderer(Game.class_id):
		return false
	var wk := _p().weapon_kind
	if Game.level == _last_skill_level and wk == _slots_weapon:
		return false
	if int(Game.hero.get("jp", 0)) <= 0 and wk == _slots_weapon:
		_last_skill_level = Game.level
		return false
	return await _learn_skills(false)


var _slots_weapon := "?"


func _learn_skills(for_goal: bool) -> bool:
	_last_skill_level = Game.level
	_slots_weapon = _p().weapon_kind
	var hw: CharacterWindow = bot.main.get("hero_window") as CharacterWindow
	if hw == null:
		return false
	_close()
	_action("hero_window")
	if not hw.is_open():
		_find("окно героя не открылось")
		return false
	_split = "ui"
	var learned := 0
	var jp0 := int(Game.hero.get("jp", 0))
	# Порядок: атакующие активные (урон), остальные активные, переключаемые, пассивные
	var order: Array = []
	for pass_i in 4:
		for t in HeroSkills.tabs_for(Game.class_id):
			for e in HeroSkills.list_tab(Game.class_id, String(t[0])):
				var sid := String(e)
				var kd := HeroSkills.kind(sid)
				var dmg := _is_damage(sid)
				var want := (pass_i == 0 and kd == "active" and dmg) or (pass_i == 1 and kd == "active" and not dmg) \
					or (pass_i == 2 and kd == "toggle") or (pass_i == 3 and kd == "passive")
				if want and not order.has([sid, String(t[0])]):
					order.append([sid, String(t[0])])
	var p := _p()
	for e in order:
		var sid := String(e[0])
		var tab := String(e[1])
		if HeroSkills.learn_block(Game.hero, Game.class_id, Game.level, sid) != "":
			continue
		# Атакующие — до 3-го уровня, прочие — 1 уровень (JP хватит на многое)
		var cap := 3 if _is_damage(sid) else 1
		if HeroSkills.skill_level(Game.hero, sid) >= cap:
			continue
		if not _press(hw.buttons, "tab_" + tab) and hw.tab != tab:
			continue
		if not _press(hw.buttons, "skill_" + sid):
			continue
		while HeroSkills.skill_level(Game.hero, sid) < cap and _press(hw.buttons, "learn_" + sid):
			learned += 1
	# Кнопки 1–4: атакующие активные, что подходят оружию
	var dmg_skills: Array = []
	for e in order:
		var sid2 := String(e[0])
		if HeroSkills.kind(sid2) == "active" and _is_damage(sid2) and HeroSkills.skill_level(Game.hero, sid2) > 0 \
				and HeroSkills.weapon_ok(sid2, p.weapon_kind, p.has_shield) and HeroSkills.is_ready(sid2):
			dmg_skills.append(e)
	var slot_i := 0
	for e in dmg_skills:
		if slot_i >= HeroSkills.SLOTS:
			break
		var sid3 := String(e[0])
		var slots: Array = Game.hero.get("slots", [])
		if slot_i < slots.size() and String(slots[slot_i]) == sid3:
			slot_i += 1
			continue
		_press(hw.buttons, "tab_" + String(e[1]))
		_press(hw.buttons, "skill_" + sid3)
		_press(hw.buttons, "slot_%d" % (slot_i + 1))
		slot_i += 1
	_close()
	if learned > 0:
		_ev("skills", "изучено уровней %d (JP %d → %d), кнопки: %s" % [learned, jp0, int(Game.hero.get("jp", 0)),
			", ".join(PackedStringArray(Game.hero.get("slots", [])))])
	return learned > 0 or for_goal


static func _is_damage(sid: String) -> bool:
	for f in HeroSkills.get_skill(sid).get("fx", []):
		var fd: Dictionary = f
		if ["damage", "dot"].has(String(fd.get("do", ""))):
			return true
	return false


## Питомец: призвать (окно «Питомцы»), воскресить свитком, режим «Авто».
func _care_pet() -> bool:
	if Game.pets.is_empty():
		return false
	var pm := _pm()
	var i := _main_pet()
	var rec: Dictionary = Game.pets[i]
	if PetBelt.in_belt(rec):
		return false
	if bool(rec.get("dead", false)):
		if not Game.inventory.has("revive_scroll"):
			if Game.gold >= int(ItemData.get_item("revive_scroll").get("buy", 0)) + 500 and not _care_tried:
				_care_tried = true
				return await _buy("merchant", "revive_scroll", 1)
			return false
		_close()
		_action("pets_window")
		var ok := _press(pm.window_buttons, "revive_%d" % i)
		_close()
		_ev("pet", "воскрешён свитком: %s" % ("да" if ok and not bool(rec.get("dead", false)) else "нет"))
		return ok
	_care_tried = false
	if not _pet_out():
		_close()
		_action("pets_window")
		_press(pm.window_buttons, "summon_%d" % i)
		_close()
		if _pet_out():
			_action("pet_auto")
			return true
		return false
	if String(pm.active_pet.record.get("cmd", "")) != "auto":
		_action("pet_auto")
	return false


var _care_tried := false


## Умения питомца в окне существа: изучить что можно (сначала «Знаток снаряжения», «Способности карты», активные).
func _maybe_learn_pet() -> bool:
	if Game.pets.is_empty():
		return false
	var i := _main_pet()
	var rec: Dictionary = Game.pets[i]
	var lv := int(rec.get("level", 1))
	if lv == _last_pet_learn or _pet_learnable() == "":
		return false
	_last_pet_learn = lv
	return await _learn_pet("")


## Что питомец может изучить сейчас ("" — ничего).
func _pet_learnable() -> String:
	if Game.pets.is_empty():
		return ""
	var rec: Dictionary = Game.pets[_main_pet()]
	var sp := String(rec.get("species", ""))
	var prio: Array = ["item_expert_" + sp, "card_%s_1" % sp, "card_%s_2" % sp]
	for id in prio:
		if PetSkills.has_skill(sp, String(id)) and PetSkills.learn_block(rec, String(id)) == "":
			return String(id)
	for id in PetSkills.list_for(sp):
		if PetSkills.learn_block(rec, String(id)) == "":
			return String(id)
	return ""


## Изучить питомцу умение sid (или всё, что можно): окно существа → вкладка → умение → «+ JP».
func _learn_pet(sid: String) -> bool:
	var pm := _pm()
	var i := _main_pet()
	var rec: Dictionary = Game.pets[i]
	var cw := pm.creature
	var n := 0
	var sum0 := Quests.pet_skill_sum()
	_close()
	for _k in 30:
		var id := sid if sid != "" else _pet_learnable()
		if id == "" or PetSkills.learn_block(rec, id) != "":
			break
		if not pm.open_creature(i, PetSkills.tab_of(id)):
			break
		_split = "ui"
		_press(cw.buttons, "skill_" + id)
		var lv0 := PetSkills.skill_level(rec, id)
		_press(cw.buttons, "learn_" + id)
		if PetSkills.skill_level(rec, id) <= lv0:
			_find("питомцу не изучить «%s» кнопкой «+ JP» (%s)" % [id, _last_msg()])
			break
		n += 1
		if sid != "":
			break
	_close()
	if n > 0:
		_ev("pet_skill", "питомцу изучено уровней %d (сумма %d → %d)" % [n, sum0, Quests.pet_skill_sum()])
	return n > 0


## Приручить: цель — зверь вида species, «Приручить», победить.
func _tame(species: String) -> bool:
	var tm: Taming = bot.main.get("taming") as Taming
	var m := _find_mob([species], 0, 0)
	if m == null:
		return false
	if not await _go(m.global_position, 5.0, m.mob_name):
		return false
	if not _mob_alive(m):
		return false
	var p := _p()
	p.select_target(m)
	var card := ItemData.card_for(species)
	var cards0 := Game.inventory.count(card)
	var souls0 := Game.inventory.count(ItemData.soul_card_for(species))
	var mirror0 := Game.inventory.count(ItemData.MIRROR_CARD)
	while tm.cooldown > 0.0:
		if not await _tick():
			return false
	_action("tame")
	if tm.marked != m:
		_find("«Приручить» не поставил метку на «%s» (%s)" % [m.mob_name, _last_msg()])
		return false
	await _fight(m, "приручение")
	var soul := Game.inventory.count(ItemData.soul_card_for(species)) > souls0
	var mirror_broke := Game.inventory.count(ItemData.MIRROR_CARD) < mirror0
	var card_broke := Game.inventory.count(card) < cards0 and not soul
	_feature("tame", true, "%s: %s" % [MobData.get_type(species)["name"], "душа поймана" if soul else
		("неудача — сломалась зеркальная карта" if mirror_broke else ("неудача — карта сломалась" if card_broke else "неясно"))])
	_ev("tame", "%s — %s" % [species, "душа" if soul else "неудача"])
	return soul


## Сформировать: окно «Питомцы» → «Сформировать» (карта с душой).
func _form(card: String) -> bool:
	var pm := _pm()
	var n0 := Game.pets.size()
	_close()
	_action("pets_window")
	_split = "ui"
	if not _press(pm.window_buttons, "form_" + card):
		# Иначе — из сумки: карта → «Сформировать»
		_close()
		_action("bag_window")
		var w := _win()
		var c := Game.inventory.find_cell(card)
		_press(w.buttons, "cell_%d" % c)
		_press(w.buttons, "act_form")
	_close()
	var ok := Game.pets.size() > n0
	_feature("form", ok, "сформировано из «%s»: %s" % [ItemData.item_name(card), "да" if ok else "нет (%s)" % _last_msg()])
	if ok:
		_ev("pet", "сформирован %s" % String(Game.pets[Game.pets.size() - 1].get("species", "")))
		if _pet_out():
			_action("pet_auto")
	return ok


func _summon() -> bool:
	var pm := _pm()
	var i := _main_pet()
	_close()
	_action("pets_window")
	if _pet_out():
		_press(pm.window_buttons, "recall_%d" % i)
	_press(pm.window_buttons, "summon_%d" % i)
	_close()
	if _pet_out():
		_action("pet_auto")
	return _pet_out()


## Надеть вещь из сумки в ячейку: окно сумки → ячейка → «Надеть» («Во 2-е кольцо», «Во 2-ю руку»).
func _equip(item: String, slot: String) -> bool:
	_close()
	_action("bag_window")
	var w := _win()
	var c := Game.inventory.find_cell(item)
	if c < 0:
		_close()
		return false
	_split = "ui"
	_press(w.buttons, "cell_%d" % c)
	var key := "act_equip"
	if slot == "ring2":
		key = "act_equip_ring2"
	elif slot == "offhand":
		key = "act_equip_off"
	var ok := _press(w.buttons, key)
	_close()
	ok = ok and (Enchant.equipped_in(slot) != "" or (slot == "ring1" and Enchant.equipped_in("ring2") != ""))
	_ev("equip", "%s → %s: %s" % [ItemData.item_name(item), slot, "да" if ok else "нет (%s)" % _last_msg()])
	return ok


## Крафт кубом в панели крафта сумки: «Крафт» → надетое → «В крафт» (куб подставится) → «Крафт» → «Да, крафт».
## Сверка по правилам: удача — заточка +1 той же вещи; неудача — с порошком вещь цела, без — лом (украшение — +0).
func _craft(slot: String, cube: String) -> bool:
	_close()
	_action("bag_window")
	var w := _win()
	_split = "ui"
	if not _press(w.buttons, "craft_toggle") or not w.craft_open:
		_find("кнопка «Крафт» в сумке не открыла панель")
		_close()
		return false
	var item := Enchant.equipped_in(slot)
	_press(w.buttons, "worn_" + slot)
	_press(w.buttons, "act_craft_put")
	if w.craft_item != item:
		_find("«В крафт» не положил «%s» на панель" % ItemData.item_name(item))
		_close()
		return false
	if w.craft_cube != cube and Game.inventory.has(cube):
		w.put_cube(cube)
	var powder := Enchant.powder_for(item)
	var element := Enchant.element_for(w.craft_cube)
	var use_powder := powder != "" and w.craft_powder
	var use_el := element != "" and w.craft_element
	var chance := Enchant.chance(item, w.craft_cube, use_el)
	var lv0 := ItemData.enchant_level(item)
	var cube_n := Game.inventory.count(w.craft_cube)
	var used_cube := w.craft_cube
	_press(w.buttons, "act_craft")
	if not _press(w.buttons, "act_craft_yes"):
		_find("нет подтверждения крафта (%s)" % _last_msg())
		_close()
		return false
	var after := Enchant.equipped_in(slot)
	var ok := w.craft_ok
	var rule := false
	var what := ""
	if ok:
		rule = ItemData.base_id(after) == ItemData.base_id(item) and ItemData.enchant_level(after) == lv0 + 1
		what = "удача +%d → +%d" % [lv0, lv0 + 1]
	elif use_powder:
		rule = after == item
		what = "неудача с порошком — вещь цела"
	elif ItemData.enchant_kind(item) == "acc":
		rule = ItemData.enchant_level(after) == 0
		what = "неудача — заточка украшения пропала"
	else:
		# Сломанная снимается: в ячейке пусто, лом в сумке
		rule = after == "" and Game.inventory.has(ItemData.broken_id(item))
		what = "неудача — вещь сломалась"
	rule = rule and Game.inventory.count(used_cube) == cube_n - 1
	_feature("craft", rule, "«%s» %s кубом «%s» (шанс %d%%%s%s): %s" % [ItemData.item_name(item), slot,
		ItemData.item_name(used_cube), roundi(chance * 100.0), ", порошок" if use_powder else "", ", элемент" if use_el else "", what])
	_close()
	return ok


## Закалка у Кузнеца Гуннара: «Говорить» → «Закалка» → надетое → «На наковальню» → «Закалить». Сверка: +1, золото.
func _temper(slot: String) -> bool:
	var item := Enchant.equipped_in(slot)
	var price := Enchant.temper_price(item)
	if Game.gold < price:
		await _raise_gold(price)
	if not await _talk(Enchant.SMITH_NPC):
		return false
	if not _dlg("opt_forge"):
		_find("у кузнеца нет пункта «Закалка»")
		return false
	var eco := _eco()
	if not eco.is_forge_open():
		_find("кузница не открылась (%s)" % _last_msg())
		return false
	var w := _win()
	_split = "ui"
	item = Enchant.equipped_in(slot)
	price = Enchant.temper_price(item)
	var g0 := Game.gold
	var lv0 := ItemData.enchant_level(item)
	_press(w.buttons, "worn_" + slot)
	_press(w.buttons, "act_forge_put")
	var ok := _press(w.buttons, "act_forge")
	var after := Enchant.equipped_in(slot)
	var rule := ok and ItemData.enchant_level(after) == lv0 + 1 and Game.gold == g0 - price
	_feature("temper", rule if ok else false, "«%s» +%d → +%d за %d зол. (списано %d)%s" % [ItemData.item_name(item), lv0,
		ItemData.enchant_level(after), price, g0 - Game.gold, "" if ok else " — не вышло: " + _last_msg()])
	_close()
	return ok


## Питомцу вещь: окно существа → «Оружие и доспехи» → вещь → «Надеть питомцу». Сверка: прибавка по «Знатоку».
func _pet_gear(i: int, item: String) -> bool:
	var pm := _pm()
	var rec: Dictionary = Game.pets[i]
	var before := PetData.stats_of(rec)
	var k := PetGear.expert(rec)
	var cards0 := Game.inventory.count(PetGear.UNIT_CARD)
	_close()
	if not pm.open_creature(i, "gear"):
		return false
	var cw := pm.creature
	_split = "ui"
	_press(cw.buttons, "gear_item_" + item)
	var ok := _press(cw.buttons, "gear_equip")
	_close()
	var slot := PetGear.slot_for(item)
	ok = ok and PetGear.gear_in(rec, slot) == item
	var after := PetData.stats_of(rec)
	var it := ItemData.get_item(item)
	var base := ItemData.get_item(ItemData.base_id(item))
	var exp_patk := roundi(float(base.get("atk", 0)) * k + float(it.get("atk", 0)) - float(base.get("atk", 0)))
	var exp_def := roundi(float(base.get("def", 0)) * k + float(it.get("def", 0)) - float(base.get("def", 0)))
	var d_patk := int(after.get("patk", 0)) - int(before.get("patk", 0))
	var d_def := int(after.get("def", 0)) - int(before.get("def", 0))
	var fighter := PetSkills.skill_level(rec, "fighter_unit_" + String(rec.get("species", ""))) > 0
	var rule := ok and Game.inventory.count(PetGear.UNIT_CARD) == cards0 - 1 and d_def == exp_def \
		and (fighter or d_patk == exp_patk)
	_feature("pet_gear", rule, "%s → «%s» (%s): «Знаток» %d%%, физ. атака %+d (по правилу %+d), защита %+d (%+d), карта снаряжения потрачена" % [
		ItemData.item_name(item), String(rec.get("name", "")), slot, roundi(k * 100.0), d_patk, exp_patk, d_def, exp_def])
	if ok:
		var p := _pm().active_pet
		if p != null and is_instance_valid(p):
			p.refresh_skills()
	return ok


# ==================== Фичи «как игрок» ====================

## Фича, которую можно сделать сейчас (одна за шаг). true — сделано что-то.
func _features() -> bool:
	if until_job:
		return false
	var inv := Game.inventory
	# Торба 1-го ранга у Гордея
	if not features.has("bag") and Game.gear_in("bag") == "" and Game.gold >= 3000 + 2000:
		return await _feature_bag()
	# Склад туда-обратно (после «Городского склада»)
	if not features.has("storage") and _q().is_done("sage_storage"):
		return await _storage_trip(true)
	# Крафт с порошком: есть порошок стабильности, куб и вещь для него
	if not features.has("craft_powder") and _has_type_prefix("stab_powder"):
		var done_c: bool = await _feature_craft_powder()
		if done_c:
			return true
	# Доспех питомцу (вторая ячейка)
	if not features.has("pet_armor") and not Game.pets.is_empty() and _q().is_done("kirk_pet_gear"):
		return await _feature_pet_armor()
	# Эволюция у Кирка
	if not Game.pets.is_empty():
		var rec: Dictionary = Game.pets[_main_pet()]
		if PetData.evolve_block(rec) == "" and int(features.get("evolve", {}).get("n", 0)) < 2:
			return await _feature_evolve()
	# Пояс: питомец со «Способностью карты» в ячейку пояса
	if not features.has("belt") and not Game.pets.is_empty() and not PetBelt.abilities(Game.pets[_main_pet()]).is_empty():
		return await _feature_belt()
	# Расширитель пояса
	if features.has("belt") and not features.has("belt_expand") and Game.gold >= int(ItemData.get_item(PetBelt.ITEM).get("buy", 0)) + 3000:
		return await _feature_belt_expand()
	return false


func _features_done() -> bool:
	if until_job or Game.pets.is_empty():
		return true
	# Питомец: эволюция и пояс; не вышло за pet_phase_sec — не ждём (в отчёте «не проверено» с причиной)
	if _pet_phase_t >= 0.0 and game_t - _pet_phase_t > float(profile["pet_phase_sec"]):
		return true
	return features.has("evolve") and features.has("belt")


var _pet_phase_t := -1.0


## После заданий: прокачка питомца до 50 ур. (опыт ×pet_phase_xp — помощь) — эволюция и пояс станут доступны.
func _pet_phase() -> bool:
	if _pet_phase_t < 0.0:
		_pet_phase_t = game_t
		_help("xp_pet", "после заданий опыт ×%d — питомцу до %d ур. (эволюция, «Способность карты» для пояса)" % [
			int(profile["pet_phase_xp"]), int(PetData.EVOLVE_LEVELS[0])])
	Game.xp_mult = int(profile["pet_phase_xp"])
	var ok: bool = await _grind()
	Game.xp_mult = int(profile["xp_mult"])
	return ok


func _has_type_prefix(prefix: String) -> bool:
	for k in Game.inventory.ids():
		if String(k).begins_with(prefix):
			return true
	return false


func _feature_bag() -> bool:
	var cap0 := Game.inventory.capacity
	if not await _buy("merchant", "bag_r1", 1):
		_feature("bag", false, "торба не куплена (%s)" % _last_msg())
		return false
	var ok := await _equip("bag_r1", "bag")
	var cap := Game.inventory.capacity
	_feature("bag", ok and cap == Inventory.CAPACITY + ItemData.bag_slots("bag_r1"),
		"«%s» куплена и надета: ячеек %d → %d (ожидалось %d)" % [ItemData.item_name("bag_r1"), cap0, cap,
		Inventory.CAPACITY + ItemData.bag_slots("bag_r1")])
	return true


## Крафт с порошком стабильности: вещь из лавки (дешёвая) или надетая, куб — любой подходящий (и элемент, если есть).
func _feature_craft_powder() -> bool:
	var slot := ""
	for s in ["weapon", "head", "body", "hands", "feet"]:
		var it := Enchant.equipped_in(s)
		if it != "" and _cube_for(it, false) != "" and Enchant.powder_for(it) != "":
			slot = s
			break
	if slot == "":
		return false
	var item := Enchant.equipped_in(slot)
	var cube := _cube_for(item, false)
	var ok: bool = await _craft(slot, cube)
	_feature("craft_powder", true, "крафт с порошком: «%s» — %s" % [ItemData.item_name(item), "удача" if ok else "неудача, вещь цела"])
	return true


func _feature_pet_armor() -> bool:
	var i := _main_pet()
	var rec: Dictionary = Game.pets[i]
	if PetGear.gear_in(rec, "armor") != "":
		_feature("pet_armor", true, "доспех уже надет")
		return false
	if PetGear.expert(rec) <= 0.0:
		return false
	var body := ""
	for k in Game.inventory.ids():
		var it := String(k)
		if PetGear.slot_for(it) == "armor" and PetGear.equip_block(rec, it).begins_with("Нужна") or \
				(PetGear.slot_for(it) == "armor" and PetGear.equip_block(rec, it) == ""):
			body = it
			break
	if body == "":
		var b := _shop_item_for("body")
		if b.is_empty():
			_feature("pet_armor", false, "нет доспеха в лавке")
			return false
		if not await _buy(String(b[0]), String(b[1]), 1):
			return false
		body = String(b[1])
	if not Game.inventory.has(PetGear.UNIT_CARD):
		if not await _buy("kirk", PetGear.UNIT_CARD, 1):
			_feature("pet_armor", false, "карта снаряжения не куплена (%s)" % _last_msg())
			return false
	var ok: bool = await _pet_gear(i, body)
	var r: Dictionary = features.get("pet_gear", {})
	_feature("pet_armor", ok, String(r.get("text", "")))
	return true


func _feature_evolve() -> bool:
	var i := _main_pet()
	var rec: Dictionary = Game.pets[i]
	var st0 := PetData.stage_of(rec)
	if not await _talk("kirk"):
		return false
	if not _dlg("opt_evolve"):
		_feature("evolve", false, "у Кирка нет пункта «Эволюция»")
		_close()
		return false
	var pm := _pm()
	var ok := _press(pm.window_buttons, "evolve_%d" % i)
	_close()
	var st := PetData.stage_of(rec)
	_feature("evolve", ok and st == st0 + 1, "«%s» %d ур.: форма %d → %d" % [String(rec.get("name", "")), int(rec.get("level", 1)),
		st0 + 1, st + 1])
	return true


## Пояс: надеть пояс (ювелир), отозвать питомца, касание ячейки пояса в сумке → касание карты питомца; бонус герою
## = PetBelt.hero_bonus; «Из пояса».
func _feature_belt() -> bool:
	if Game.gear_in("belt") == "":
		var have := _bag_item_for("belt")
		if have == "":
			var b := _shop_item_for("belt")
			if b.is_empty() or not await _buy(String(b[0]), String(b[1]), 1):
				_feature("belt", false, "пояс не куплен (%s)" % _last_msg())
				return true
			have = String(b[1])
		await _equip(have, "belt")
	var i := _main_pet()
	var pm := _pm()
	if _pet_out():
		_close()
		_action("pets_window")
		_press(pm.window_buttons, "recall_%d" % i)
		_close()
	var p := _p()
	var st0: Dictionary = (p.hero_stats.get("stats", {}) as Dictionary).duplicate()
	_action("bag_window")
	var w := _win()
	_split = "ui"
	_press(w.buttons, "belt_0")
	var put := _press(w.buttons, "belt_pet_%d" % i)
	var bonus := PetBelt.hero_bonus(Game.class_id, Game.level)
	var in_belt := PetBelt.pet_in(0) == i
	p.recalc_stats()
	var same := str(p.belt_bonus) == str(bonus)
	var stat_ok := true
	var st1: Dictionary = p.hero_stats.get("stats", {})
	for k in bonus:
		if Stats.STATS.has(String(k)):
			stat_ok = stat_ok and int(st1.get(k, 0)) - int(st0.get(k, 0)) == roundi(float(bonus[k]))
	_feature("belt", put and in_belt and not bonus.is_empty() and same and stat_ok,
		"«%s» в ячейке 1: бонус герою %s (Player.belt_bonus %s)%s" % [String(Game.pets[i].get("name", "")),
		PetBelt.bonus_text(bonus), "совпал" if same else "НЕ совпал: %s" % str(p.belt_bonus),
		"" if stat_ok else ", характеристики героя выросли не на бонус"])
	# Обратно: «Из пояса», питомец снова призывается
	_press(w.buttons, "belt_0")
	_press(w.buttons, "act_belt_take")
	_close()
	await _care_pet()
	return true


func _feature_belt_expand() -> bool:
	var n0 := Game.belt_slots
	if not await _buy("rare_merchant", PetBelt.ITEM, 1):
		_feature("belt_expand", false, "расширитель не куплен (%s)" % _last_msg())
		return true
	_action("bag_window")
	var w := _win()
	_press(w.buttons, "belt_%d" % n0)
	var ok := _press(w.buttons, "act_belt_expand")
	_close()
	var n1 := Game.belt_slots
	var rule := ok and (n1 == n0 + 1 or n1 == 1) and not Game.inventory.has(PetBelt.ITEM)
	_feature("belt_expand", rule, "ячеек пояса %d → %d (шанс %d%%)" % [n0, n1, roundi(PetBelt.expand_chance(n0) * 100.0)])
	return true


# ==================== Итог ====================

func result() -> Dictionary:
	var qs: Dictionary = {}
	var q := _q() if bot != null and is_instance_valid(bot) and bot.main != null and is_instance_valid(bot.main) else null
	for k in QuestData.all_ids():
		var id := String(k)
		var r: Dictionary = _qrec(id).duplicate()
		if q != null and String(r["status"]) != "done":
			if q.is_active(id):
				r["status"] = "active"
				if String(r["reason"]) == "":
					r["reason"] = _why_open(id)
			elif String(r["status"]) == "not_taken":
				r["reason"] = q.accept_block(id) if String(r["reason"]) == "" else String(r["reason"])
		qs[id] = r
	return {
		"run": run_name, "title": title, "profile": profile["id"], "profile_version": profile["version"],
		"race": race, "job": job, "seed": seed_value, "accel": accel, "stop": stop_reason,
		"game_sec": snappedf(game_t, 0.1), "wall_sec": snappedf(wall_sec(), 0.1),
		"speedup": snappedf(game_t / maxf(wall_sec(), 0.001), 0.01),
		"start": start, "finish": finish if done else _snapshot(),
		"quests_done": done_count(), "quests_total": QuestData.all_ids().size(),
		"kills": kills, "kills_by": kills_by, "deaths": deaths, "time_split": t_split,
		"rest_boost_game": snappedf(boost_game, 0.1),
		"help": help, "help_total": help_count(), "features": features, "findings": findings,
		"quests": qs, "events": events, "sim_radius": profile["sim_radius"], "xp_mult": profile["xp_mult"],
		"nav": {"build_ms": nav_ms, "blocked_cells": CardinalNav.blocked_cells},
		"cost": {"ticks": ticks, "ms_per_tick": snappedf(wall_sec() * 1000.0 / maxf(float(ticks), 1.0), 0.001),
			"cardinal_ms_per_tick": snappedf(float(self_us) / 1000.0 / maxf(float(ticks), 1.0), 0.001)},
	}
