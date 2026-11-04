class_name CardinalRun
extends RefCounted
## Кардинал, фаза 1 (CARDINAL_MASTER_INSTRUCTION.md, CARDINAL_ARCHITECTURE.md): один прогон «фарма» у деревни —
## бот-игрок теми же действиями, что и человек: цель — касание зверя (Player.select_target), ходьба — джойстик
## (HUD.move_vec относительно камеры, мосты — IslandWorld.Route), удар — удержание «Атаки» (Player.try_attack, как
## main._process при удержании), добыча — подойти к мешочку (LootDrop сам подбирается в 2.5 м), отдых — стоять вне
## боя. Ничего не начисляется напрямую: опыт, золото, добыча — по правилам игры (main._on_mob_gone, Economy).
## Ускоренный режим (accel > 1) этой фазы: Engine.time_scale × без отрисовки 3D (Viewport.disable_3d) и без предела
## кадров — та же логика и формулы, только больше шагов физики на кадр (max_physics_steps_per_frame). Это временная
## замена SimulationClock фазы 2 — расхождения с прогоном «с картинкой» измеряются и попадают в отчёт.
## Время: game — сумма delta игры (со шкалой), wall — Time.get_ticks_usec (настоящее), отдельно — путь, бой, добыча,
## отдых, поиск. Ограничители: игровое время, wall-время, застревание (цель брошена), шаги.

const PROFILE_REGULAR := {
	"id": "regular", "name": "Обычный игрок", "version": 1,
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

var done := false
var stop_reason := ""
var state := "seek"
var game_t := 0.0
var t_split := {"seek": 0.0, "approach": 0.0, "fight": 0.0, "loot": 0.0, "rest": 0.0}
var kills: Array[Dictionary] = []
var deaths := 0
var damage_taken := 0
var xp_mismatch: Array[String] = []
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
	_saved = {"time_scale": Engine.time_scale, "steps": Engine.max_physics_steps_per_frame, "fps": Engine.max_fps,
		"no3d": bot.get_viewport().disable_3d}
	if accel > 1.0:
		Engine.time_scale = accel
		Engine.max_physics_steps_per_frame = maxi(8, int(ceil(accel * 3.0)))
		Engine.max_fps = 0
		bot.get_viewport().disable_3d = true
	var w := IslandWorld.current
	for z in w.cfg.get("mob_zones", []):
		var zd: Dictionary = z
		if String(zd.get("id", "")) == zone_id:
			var c := IslandWorld.v2(zd["center"])
			_center = w.ground(c.x, c.y)
			_radius = float(zd.get("radius", 12.0)) + 18.0
	bot.teleport(Vector2(_center.x, _center.z), "Кардинал: %s" % title)
	p.hp = p.max_hp
	p.mp = p.max_mp
	_last_hp = p.hp
	if not p.message.is_connected(_on_message):
		p.message.connect(_on_message)
	start = _snapshot()
	_wall0 = Time.get_ticks_usec()
	bot.note("Кардинал «%s»: профиль «%s», seed %d, ускорение ×%.0f, лимит игрового времени %s" % [title,
		String(profile["name"]), seed_value, accel, TestBot.clock(game_limit)])
	bot.set_tick(tick)


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
	game_t += dt
	_state_t += dt
	t_split[state] = float(t_split[state]) + dt
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
				_go("approach")
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
				p.try_attack()  # удержание «Атаки» (main._process)
			if _state_t > float(profile["fight_limit"]):
				bot.note("Кардинал: бой с «%s» дольше %.0f с — брошен" % [_target.type_id, _state_t])
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
				_go("seek")


func _go(s: String) -> void:
	state = s
	_state_t = 0.0
	_nav.reset()


func _alive(m: Mob) -> bool:
	return m != null and is_instance_valid(m) and not m.is_dead


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _need_rest(p: Player) -> bool:
	return float(p.hp) < float(p.max_hp) * float(profile["rest_below"])


## Ближайший живой зверь зоны: не босс, не старше героя + gap (как выбирает осторожный игрок).
func _pick_target(p: Player) -> Mob:
	var best: Mob = null
	var bd := INF
	for n in bot.get_tree().get_nodes_in_group("mobs"):
		var m := n as Mob
		if not _alive(m) or m.is_boss or m.level > Game.level + int(profile["level_gap"]):
			continue
		if _flat(m.global_position, _center) > _radius:
			continue
		var d := _flat(m.global_position, p.global_position)
		if d < bd:
			bd = d
			best = m
	return best


func _walk(p: Player, h: HUD, to: Vector3, dt: float) -> void:
	var pos := p.global_position
	var dir := _nav.dir_to(pos, to, dt)
	if dir.length() < 0.01:
		dir = Vector3(to.x - pos.x, 0.0, to.z - pos.z).normalized()
	var yaw := float(bot.main.get("cam_yaw"))
	var mv := Vector3(dir.x, 0.0, dir.z).rotated(Vector3.UP, -yaw)
	h.move_vec = Vector2(mv.x, mv.z)


func _stop_move(h: HUD) -> void:
	h.move_vec = Vector2.ZERO


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
	bot.set_tick(Callable())
	var h: HUD = (bot.main.get("hud") as HUD) if bot.main != null else null
	if h != null:
		h.move_vec = Vector2.ZERO
	var p := bot.player()
	if p != null and p.message.is_connected(_on_message):
		p.message.disconnect(_on_message)
	Engine.time_scale = float(_saved.get("time_scale", 1.0))
	Engine.max_physics_steps_per_frame = int(_saved.get("steps", 8))
	Engine.max_fps = int(_saved.get("fps", 0))
	bot.get_viewport().disable_3d = bool(_saved.get("no3d", false))
	finish = _snapshot()
	bot.note("Кардинал «%s» закончен: %s — игровое время %s, настоящее %s, убийств %d, смертей %d" % [title, reason,
		TestBot.clock(game_t), TestBot.clock(wall_sec()), kills.size(), deaths])


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
	}


var _wall_end_v := -1.0


func _wall_end() -> float:
	if _wall_end_v < 0.0:
		_wall_end_v = wall_sec()
	return _wall_end_v
