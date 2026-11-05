class_name CardinalRun
extends RefCounted
## Кардинал, фаза 1 (CARDINAL_MASTER_INSTRUCTION.md, CARDINAL_ARCHITECTURE.md): один прогон «фарма» у деревни —
## бот-игрок теми же действиями, что и человек: цель — касание зверя (Player.select_target), ходьба — джойстик
## (HUD.move_vec относительно камеры, мосты — IslandWorld.Route), удар — удержание «Атаки» (Player.try_attack, как
## main._process при удержании), добыча — подойти к мешочку (LootDrop сам подбирается в 2.5 м), отдых — стоять вне
## боя. Ничего не начисляется напрямую: опыт, золото, добыча — по правилам игры (main._on_mob_gone, Economy).
## Ускоренный режим (accel > 1, с 0.30 — ×8, тиков физики ×8, шаг тика 1/60 с): Engine.time_scale × без отрисовки 3D (Viewport.disable_3d) и без предела
## кадров — та же логика и формулы, только больше шагов физики на кадр (max_physics_steps_per_frame). Это временная
## замена SimulationClock фазы 2 — расхождения с прогоном «с картинкой» измеряются и попадают в отчёт.
## Время (фаза 2): game — игровые часы Util.game_time (сумма шагов физики со шкалой времени: идут с ускорением, не
## зависят от кадров отрисовки), wall — Time.get_ticks_usec (настоящее), отдельно — путь, бой, добыча, отдых, поиск. Ограничители:
## игровое время, wall-время, застревание (цель брошена), шаги.
## Безопасная перемотка (фаза 2, только ускоренный прогон): отдых — промежуток без важных событий, пока рядом нет
## опасности, ускорение игры × REST_BOOST (мир идёт честно: возрождение зверей, восстановление — то же, только
## быстрее). Опасность (героя ударили, зверь целит в героя ближе SAFE_RADIUS) — сразу обычное ускорение (откат, в
## журнал). Каждый отдых сверяется с расчётом по формуле восстановления (rest_predict): расхождение больше REST_TOL —
## буст выключается до конца прогона (откат к точному режиму).

## Профиль 3 (0.32): игрок с торбой 1-го ранга (Inventory.capacity 48) и взятым первым заданием старосты (убить
## трёх фазанов) — сверки: прогресс задания = числу убитых фазанов (до цели), занятые ячейки сумки не выходят за
## вместимость, сообщения «Сумка полна» считаются (мешочек остаётся лежать).
const PROFILE_REGULAR := {
	"id": "regular", "name": "Обычный игрок", "version": 3,
	"bag": "bag_r1",        # торба, надетая перед прогоном ("" — без торбы)
	"quest": "elder_hunt",  # задание, взятое перед прогоном ("" — без задания)
	"rest_below": 0.45,     # доля HP: ниже — отдых перед следующим зверем
	"rest_until": 0.95,     # отдых до этой доли HP
	"level_gap": 1,         # зверь не старше героя + gap
	"loot_radius": 14.0,    # за мешочком — не дальше
	"approach_limit": 20.0, # с: не дошёл до цели — бросить
	"fight_limit": 60.0,    # с: бой дольше — бросить (звери «застряли» / промахи)
}

var bot: TestBot
var run_name := "visual"
var title := "С картинкой"
var accel := 1.0
var seed_value := 1
var game_limit := 240.0
var wall_limit := 600.0
var zone_id := "human_outskirts"
var profile: Dictionary = PROFILE_REGULAR

## Буст отдыха: во сколько раз сверх accel, допуск сверки, радиус опасности.
const REST_BOOST := 8.0
const REST_TOL := 0.15
const SAFE_RADIUS := 12.0
var rest_boost := true
var boost_game := 0.0
var boost_aborts := 0
var boost_off_reason := ""
var rests: Array[Dictionary] = []
var _boosted := false
var _rest_t0 := 0.0
var _rest_hp0 := 0
var _rest_pred := 0.0
var _clock0 := 0.0

var done := false
var stop_reason := ""
var state := "seek"
var game_t := 0.0
## Брошенные цели (не дошёл, бой затянулся): id экземпляра → до какого игрового времени не выбирать (как игрок —
## зверь за оградой или на уступе: ищет другого, отчёт 0.27.0 — 10 раз подряд один и тот же фазан).
var _skip := {}
const SKIP_SEC := 60.0
var t_split := {"seek": 0.0, "approach": 0.0, "fight": 0.0, "loot": 0.0, "rest": 0.0}
var kills: Array[Dictionary] = []
var deaths := 0
var damage_taken := 0
var xp_mismatch: Array[String] = []
## Сверки профиля 3: задание (прогресс цели «победить» = убитым зверям его вида), сумка (вместимость, «Сумка полна»).
var quest_id := ""
var quest_species := ""
var quest_need := 0
var quest_kills := 0
var quest_mismatch: Array[String] = []
var bag_capacity := 0
var bag_used_max := 0
var bag_over := 0
var bag_full_msgs := 0
## Диагностика: целей выбрано, брошено, ударов по цели, «не нашёл цель» (кадров)
var picks := 0
var abandoned := 0
var swings := 0
var idle_frames := 0
## Живых зверей в зоне в начале прогона (до возрождения) и возрождено перед прогоном
var zone_mobs_start := 0
var respawned := 0
var start := {}
var finish := {}

var _wall0 := 0
var _target: Mob
var _target_xp := 0
var _target_t0 := 0.0
var _hero_lvl := 1
var _state_t := 0.0
var _loot: Node3D
var _last_hp := 0
var _center := Vector3.ZERO
var _radius := 30.0
var _nav := IslandWorld.Route.new()
var _saved := {}


static func cumulative_xp(lvl: int, xp: int) -> int:
	var s := 0
	for l in range(1, lvl):
		s += MobStats.xp_to_next(l)
	return s + xp


func begin() -> void:
	var p := bot.player()
	seed(seed_value)
	Combat.reseed(seed_value)
	# Точность как при ×1: тиков физики в accel раз больше, шаг тика тот же 1/60 с (CardinalMove.speed_up)
	_saved = CardinalMove.speed_up(bot, accel)
	var w := IslandWorld.current
	for z in w.cfg.get("mob_zones", []):
		var zd: Dictionary = z
		if String(zd.get("id", "")) == zone_id:
			var c := IslandWorld.v2(zd["center"])
			_center = w.ground(c.x, c.y)
			_radius = float(zd.get("radius", 12.0)) + 18.0
	bot.teleport(Vector2(_center.x, _center.z), "Кардинал: %s" % title)
	# Одинаковое начало прогонов: звери зоны на месте (пустой участок у деревни — тоже находка, пишется в отчёт)
	zone_mobs_start = _zone_alive()
	# Фаза 2: все звери мира заново на своих местах, прежние таймеры возрождения погашены (main.reset_mobs) — оба
	# прогона начинаются с одинакового мира
	respawned = int(bot.main.call("reset_mobs")) if bot.main.has_method("reset_mobs") else AdminPanel.respawn_all(bot.main)
	if zone_mobs_start == 0:
		bot.note("Кардинал: в зоне «%s» в начале прогона живых зверей нет — возрождено по миру %d" % [zone_id, respawned])
	_prepare_profile()
	p.hp = p.max_hp
	p.mp = p.max_mp
	_last_hp = p.hp
	if not p.message.is_connected(_on_message):
		p.message.connect(_on_message)
	start = _snapshot()
	_wall0 = Time.get_ticks_usec()
	_clock0 = Util.game_time()
	bot.note("Кардинал «%s»: профиль «%s», seed %d, ускорение ×%.0f, лимит игрового времени %s" % [title,
		String(profile["name"]), seed_value, accel, TestBot.clock(game_limit)])
	# Решения «игрока» — каждый тик физики, а не кадр: при ×8 на кадр приходится 8 тиков, на телефоне кадры неровные —
	# по кадрам прогоны с одним seed расходились (0.30: совпало 4 из 7 убийств); по тикам — одинаково при любой частоте
	bot.get_tree().physics_frame.connect(_on_physics_frame)


## Профиль 3: надеть торбу и взять задание — как игрок (купил торбу, поговорил со старостой).
func _prepare_profile() -> void:
	var bag := String(profile.get("bag", ""))
	if bag != "" and Game.gear_in("bag") != bag:
		if not Game.inventory.has(bag):
			Game.inventory.add(bag)
		var err := Game.equip_gear(bag)
		if err != "":
			bot.note("Кардинал: торба «%s» не надета — %s" % [ItemData.item_name(bag), err])
	bag_capacity = Game.inventory.capacity
	quest_id = String(profile.get("quest", ""))
	var qs: Quests = bot.main.get("quests") as Quests if bot.main != null else null
	if quest_id == "" or qs == null:
		quest_id = ""
		return
	if not qs.is_active(quest_id) and not qs.is_done(quest_id):
		qs.accept(quest_id)
	if not qs.is_active(quest_id):
		bot.note("Кардинал: задание «%s» не взято (%s)" % [quest_id, qs.accept_block(quest_id)])
		quest_id = ""
		return
	var goals := QuestData.goals(quest_id)
	if goals.is_empty() or String((goals[0] as Dictionary).get("type", "")) != "kill":
		quest_id = ""
		return
	quest_species = String((goals[0] as Dictionary).get("target", ""))
	quest_need = QuestData.goal_need(goals[0])
	quest_kills = qs.goal_progress(quest_id, 0)


## Сверка после убийства: прогресс задания и сумка.
func _check_profile(mob_type: String) -> void:
	var inv := Game.inventory
	bag_used_max = maxi(bag_used_max, inv.used_cells())
	if inv.used_cells() > inv.capacity:
		bag_over += 1
	if quest_id == "":
		return
	if quest_species == "" or mob_type == quest_species:
		quest_kills = mini(quest_kills + 1, quest_need)
	var qs: Quests = bot.main.get("quests") as Quests if bot.main != null else null
	if qs == null or not qs.is_active(quest_id):
		return
	var got := qs.goal_progress(quest_id, 0)
	if got != quest_kills:
		quest_mismatch.append("после «%s»: прогресс %d, ожидалось %d" % [mob_type, got, quest_kills])


func _on_physics_frame() -> void:
	if done or bot == null or bot.state != "running" or bot.get_tree().paused:
		return
	tick(Engine.time_scale / float(Engine.physics_ticks_per_second))


func _snapshot() -> Dictionary:
	var p := bot.player()
	return {"level": Game.level, "xp": Game.xp, "cum_xp": cumulative_xp(Game.level, Game.xp), "gold": Game.gold,
		"items": Game.inventory.ids().size(), "hp": p.hp if p != null else 0}


func wall_sec() -> float:
	return float(Time.get_ticks_usec() - _wall0) / 1.0e6


func tick(dt: float) -> void:
	if done:
		return
	var p := bot.player()
	var h: HUD = (bot.main.get("hud") as HUD) if bot.main != null else null
	if p == null or h == null:
		return
	# Игровые часы — Util.game_time (сумма delta физики со шкалой времени; dt кадра не нужен)
	var now := Util.game_time() - _clock0
	var gdt := maxf(0.0, now - game_t)
	game_t = now
	_state_t += gdt
	t_split[state] = float(t_split[state]) + gdt
	if _boosted:
		boost_game += gdt
	var hurt := p.hp < _last_hp
	if p.hp < _last_hp:
		damage_taken += _last_hp - p.hp
	_last_hp = p.hp
	if game_t >= game_limit:
		_end("лимит игрового времени")
		return
	if wall_sec() >= wall_limit:
		_end("лимит настоящего времени")
		return
	match state:
		"seek":
			_stop_move(h)
			_target = _pick_target(p)
			if _target != null:
				picks += 1
				_go("approach")
			else:
				idle_frames += 1
		"approach":
			if not _alive(_target):
				_go("seek")
				return
			var d := _flat(p.global_position, _target.global_position)
			if d <= p.attack_range * 0.9:
				_stop_move(h)
				p.select_target(_target)
				_target_xp = cumulative_xp(Game.level, Game.xp)
				_target_t0 = game_t
				_hero_lvl = Game.level
				_go("fight")
			elif _state_t > float(profile["approach_limit"]):
				bot.note("Кардинал: не дошёл до «%s» за %.0f с — цель брошена" % [_target.type_id, _state_t])
				abandoned += 1
				_skip[_target.get_instance_id()] = game_t + SKIP_SEC
				_target = null
				_go("seek")
			else:
				_walk(p, h, _target.global_position, dt)
		"fight":
			if not _alive(_target):
				_on_kill(p)
				return
			var d2 := _flat(p.global_position, _target.global_position)
			if d2 > p.attack_range:
				_walk(p, h, _target.global_position, dt)
			else:
				_stop_move(h)
				if p.current_target != _target:
					p.select_target(_target)
				if p.try_attack():  # удержание «Атаки» (main._process)
					swings += 1
			if _state_t > float(profile["fight_limit"]):
				bot.note("Кардинал: бой с «%s» дольше %.0f с — брошен" % [_target.type_id, _state_t])
				abandoned += 1
				_skip[_target.get_instance_id()] = game_t + SKIP_SEC
				_target = null
				_go("seek")
		"loot":
			if _loot == null or not is_instance_valid(_loot) or _state_t > 10.0:
				_go("rest" if _need_rest(p) else "seek")
				return
			_walk(p, h, _loot.global_position, dt)
		"rest":
			_stop_move(h)
			if float(p.hp) >= float(p.max_hp) * float(profile["rest_until"]) or _state_t > 90.0:
				_rest_done(p)
				_go("seek")
			else:
				_rest_tick(p, hurt)


func _go(s: String) -> void:
	if state == "rest" and s != "rest":
		_set_boost(false)
	if s == "rest" and state != "rest":
		var p := bot.player()
		_rest_t0 = game_t
		_rest_hp0 = p.hp if p != null else 0
		_rest_pred = rest_predict(p) if p != null else 0.0
	state = s
	_state_t = 0.0
	_nav.reset()


func _alive(m: Mob) -> bool:
	return m != null and is_instance_valid(m) and not m.is_dead


func _flat(a: Vector3, b: Vector3) -> float:
	return CardinalMove.flat(a, b)


func _need_rest(p: Player) -> bool:
	return float(p.hp) < float(p.max_hp) * float(profile["rest_below"])


func _zone_alive() -> int:
	var n_alive := 0
	for n in bot.get_tree().get_nodes_in_group("mobs"):
		var m := n as Mob
		if _alive(m) and _flat(m.global_position, _center) <= _radius:
			n_alive += 1
	return n_alive


## Ближайший живой зверь зоны: не босс, не старше героя + gap (как выбирает осторожный игрок).
func _pick_target(p: Player) -> Mob:
	var best: Mob = null
	var bd := INF
	for n in bot.get_tree().get_nodes_in_group("mobs"):
		var m := n as Mob
		if not _alive(m) or m.is_boss or m.level > Game.level + int(profile["level_gap"]):
			continue
		if float(_skip.get(m.get_instance_id(), -1.0)) > game_t:
			continue
		if _flat(m.global_position, _center) > _radius:
			continue
		var d := _flat(m.global_position, p.global_position)
		if d < bd:
			bd = d
			best = m
	return best


func _walk(p: Player, h: HUD, to: Vector3, dt: float) -> void:
	CardinalMove.walk(bot, _nav, p, h, to, dt)


func _stop_move(h: HUD) -> void:
	CardinalMove.stop(bot.player(), h)


func _on_kill(p: Player) -> void:
	var gained := cumulative_xp(Game.level, Game.xp) - _target_xp
	# Ожидание по формуле игры (main._on_mob_gone): награда зверя × разница уровней (уровень героя до убийства) ×
	# множитель админ-панели. Других источников опыта в прогоне нет (питомца и заданий нет) — должно совпасть точно.
	var expect := Combat.xp_for(_target.xp_reward, _target.level, _hero_lvl)
	kills.append({"type": _target.type_id, "level": _target.level, "ttk": snappedf(game_t - _target_t0, 0.01),
		"xp": gained, "xp_expected": expect, "hero_level": _hero_lvl, "t": snappedf(game_t, 0.1)})
	if gained != expect:
		xp_mismatch.append("%s %d ур. (герой %d): получено %d, по формуле %d" % [_target.type_id, _target.level, _hero_lvl,
			gained, expect])
	_check_profile(_target.type_id)
	_target = null
	_loot = _nearest_loot(p)
	_go("loot" if _loot != null else ("rest" if _need_rest(p) else "seek"))


func _nearest_loot(p: Player) -> Node3D:
	var best: Node3D = null
	var bd := float(profile["loot_radius"])
	for n in bot.get_tree().get_nodes_in_group("loot_drops"):
		var l := n as Node3D
		if l == null:
			continue
		var d := _flat(l.global_position, p.global_position)
		if d < bd:
			bd = d
			best = l
	return best


func _on_message(text: String) -> void:
	if text.contains("Сумка полна"):
		bag_full_msgs += 1
	if text.contains("погибли"):
		deaths += 1
		_target = null
		_go("rest")


func _end(reason: String) -> void:
	if done:
		return
	done = true
	stop_reason = reason
	_wall_end_v = wall_sec()
	if bot.get_tree().physics_frame.is_connected(_on_physics_frame):
		bot.get_tree().physics_frame.disconnect(_on_physics_frame)
	var h: HUD = (bot.main.get("hud") as HUD) if bot.main != null else null
	if h != null:
		h.move_vec = Vector2.ZERO
	_set_boost(false)
	var p := bot.player()
	if p != null and p.message.is_connected(_on_message):
		p.message.disconnect(_on_message)
	CardinalMove.restore(bot, _saved)
	finish = _snapshot()
	# Где закончил: состояние, цель, звери рядом (для разбора прогонов без убийств)
	var near := _zone_alive()
	bot.note("Кардинал «%s»: конец в состоянии «%s» (%.1f с), целей %d, брошено %d, ударов %d, кадров без цели %d, живых зверей в зоне %d%s%s" % [
		title, state, _state_t, picks, abandoned, swings, idle_frames, near,
		(", герой у (%.0f, %.0f), до центра %.0f м" % [p.global_position.x, p.global_position.z,
			_flat(p.global_position, _center)]) if p != null else "",
		(", цель %s %d ур. в %.1f м" % [_target.type_id, _target.level, _flat(_target.global_position, p.global_position)])
			if _alive(_target) and p != null else ""])
	bot.note("Кардинал «%s» закончен: %s — игровое время %s, настоящее %s, убийств %d, смертей %d" % [title, reason,
		TestBot.clock(game_t), TestBot.clock(wall_sec()), kills.size(), deaths])


# ---------- Фаза 2: безопасная перемотка отдыха ----------

## Сколько игровых секунд отдыхать до profile.rest_until по формуле восстановления Player: статы и питомец (hp_regen,
## aura_regen) всегда, отдых — max_hp × REST_REGEN после regen_delay.
func rest_predict(p: Player) -> float:
	return CardinalMove.rest_predict(p, float(profile["rest_until"]))


## Кадр отдыха: буст при безопасности, откат при опасности.
func _rest_tick(p: Player, hurt: bool) -> void:
	if not rest_boost or accel <= 1.0:
		return
	var danger := hurt
	for n in bot.get_tree().get_nodes_in_group("mobs"):
		var m := n as Mob
		if _alive(m) and m.target == p and _flat(m.global_position, p.global_position) < SAFE_RADIUS:
			danger = true
			break
	if danger and _boosted:
		boost_aborts += 1
		bot.note("Кардинал: отдых — опасность рядом, перемотка снята")
	_set_boost(not danger)


## Отдых закончен: сверка с расчётом; расхождение больше REST_TOL — буст выключается до конца прогона.
func _rest_done(p: Player) -> void:
	var actual := game_t - _rest_t0
	var err := absf(actual - _rest_pred) / maxf(_rest_pred, 0.001)
	rests.append({"hp0": _rest_hp0, "predicted": snappedf(_rest_pred, 0.1), "actual": snappedf(actual, 0.1),
		"error": snappedf(err, 0.01), "boost": rest_boost and accel > 1.0})
	if rest_boost and accel > 1.0 and _rest_pred > 2.0 and err > REST_TOL:
		rest_boost = false
		boost_off_reason = "отдых %.1f с против расчёта %.1f с (расхождение %.0f %%)" % [actual, _rest_pred, err * 100.0]
		bot.note("Кардинал: перемотка отдыха выключена — " + boost_off_reason)


func _set_boost(on: bool) -> void:
	if on == _boosted:
		return
	_boosted = on
	if accel > 1.0:
		# Отдых: шаг тика крупнее (REST_BOOST / 60 с) — во время отдыха считается только восстановление
		Engine.time_scale = accel * (REST_BOOST if on else 1.0)
		Engine.max_physics_steps_per_frame = maxi(8, int(ceil(accel * 4.0)))


## Итог прогона — машинный JSON (CARDINAL_ARCHITECTURE.md, «Отчёт»).
func result() -> Dictionary:
	var ttk := 0.0
	var xp_total := int(finish.get("cum_xp", 0)) - int(start.get("cum_xp", 0))
	for k in kills:
		ttk += float((k as Dictionary)["ttk"])
	var wall := wall_sec() if not done else float(_wall_end())
	return {
		"run": run_name, "title": title, "profile": profile["id"], "profile_version": profile["version"],
		"seed": seed_value, "accel": accel, "zone": zone_id, "stop": stop_reason,
		"game_sec": snappedf(game_t, 0.1), "wall_sec": snappedf(wall, 0.1),
		"speedup": snappedf(game_t / maxf(wall, 0.001), 0.01),
		"start": start, "finish": finish, "kills": kills.size(), "deaths": deaths, "damage_taken": damage_taken,
		"xp": xp_total, "xp_per_min": snappedf(float(xp_total) / maxf(game_t / 60.0, 0.01), 0.1),
		"gold": int(finish.get("gold", 0)) - int(start.get("gold", 0)),
		"ttk_avg": snappedf(ttk / maxf(float(kills.size()), 1.0), 0.01),
		"time_split": t_split, "xp_mismatch": xp_mismatch, "kill_log": kills,
		"quest": {"id": quest_id, "species": quest_species, "need": quest_need, "kills": quest_kills,
			"mismatch": quest_mismatch},
		"bag": {"id": String(profile.get("bag", "")), "capacity": bag_capacity, "used_max": bag_used_max,
			"over": bag_over, "full_msgs": bag_full_msgs},
		"clock": "Util.game_time",
		"anim": AnimResolver.summary(),
		"rest_boost": {"on": accel > 1.0, "boost": REST_BOOST, "game_sec": snappedf(boost_game, 0.1), "aborts": boost_aborts,
			"off_reason": boost_off_reason, "rests": rests},
		"diag": {"zone_mobs_start": zone_mobs_start, "respawned": respawned, "picks": picks, "abandoned": abandoned, "swings": swings, "idle_frames": idle_frames, "end_state": state},
	}


var _wall_end_v := -1.0


func _wall_end() -> float:
	if _wall_end_v < 0.0:
		_wall_end_v = wall_sec()
	return _wall_end_v
