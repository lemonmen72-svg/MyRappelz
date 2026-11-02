extends BotSection
## Раздел «Мир»: перенос по всем постройкам, местам и зонам зверей острова (AdminPanel.teleports; быстрый проход —
## каждое QUICK_EVERY-е): герой на проходимой земле, не под землёй; звери у деревень рас — не старше 5 ур.;
## ходьба джойстиком (как палец: HUD.move_vec, относительно камеры) по дорогам острова — через мосты, мимо построек
## и деревьев: застрял (за STUCK_TIME с сдвинулся меньше STUCK_MOVE м) или провалился под землю — ошибка с местом
## и снимок, героя переносит к следующей точке, ходьба продолжается.

## Дороги острова (world/training_island.json roads.paths): быстрый и полный проход.
const QUICK_ROADS := ["town_human"]
const FULL_ROADS := ["town_human", "town_elf", "town_dark", "town_port", "town_west", "west_tents"]
const QUICK_EVERY := 4
## Точка маршрута достигнута ближе, м.
const REACH := 1.6
## Застревание: за STUCK_TIME с сдвинулся меньше STUCK_MOVE м.
const STUCK_TIME := 3.0
const STUCK_MOVE := 1.0
## Под землёй: ниже рельефа больше чем на, м.
const UNDER := 1.2
## Звери у деревень: не старше этого уровня ближе VILLAGE_R м от центра деревни.
const VILLAGE_MAX := 5
const VILLAGE_R := 30.0

var _route: Array[Vector3] = []
var _road := ""
var _wi := 0
var _nav := IslandWorld.Route.new()
var _st_t := 0.0
var _st_from := Vector3.ZERO
var _stuck_n := 0
var _fall_n := 0
var _walked := 0.0
var _last := Vector3.ZERO
var _tp_bad := 0


func id() -> String:
	return "world"


func _build() -> void:
	do("Мир: герой", _setup)
	do("Звери у деревень — до %d ур." % VILLAGE_MAX, _village_mobs)
	var tps := AdminPanel.teleports()
	var n := 0
	for i in tps.size():
		if quick and i % QUICK_EVERY != 0:
			continue
		var d: Dictionary = tps[i]
		var nm := String(d["name"]).replace("\n", ", ")
		do("Перенос: %s" % nm, _tp.bind(d["c"], nm, n % 6 == 0))
		wait(0.35)
		do("Перенос: %s — проверка" % nm, _tp_check.bind(nm))
		n += 1
	do("Перенос: итог", func() -> void: note("Переносов: %d, плохих мест: %d" % [n, _tp_bad]))
	for r in (QUICK_ROADS if quick else FULL_ROADS):
		var road := String(r)
		do("Дорога «%s»: начало" % road, _walk_start.bind(road))
		until("дорога «%s» пройдена" % road, _walk_done, _walk_timeout(road))
		do("Дорога «%s»: итог" % road, _walk_end)


func _setup() -> void:
	hero(Game.class_id, maxi(Game.level, 10))
	no_pets()


## Живые звери острова (не бота) ближе VILLAGE_R м от центра деревни расы — не старше VILLAGE_MAX ур.
func _village_mobs() -> void:
	var w := IslandWorld.current
	if w == null:
		return
	var bad := PackedStringArray()
	var near := 0
	for v in w.cfg.get("safe_zones", []):
		var vz: Dictionary = v
		if not String(vz.get("id", "")).ends_with("_village"):
			continue
		var vc := IslandWorld.v2(vz["center"])
		for node in bot.get_tree().get_nodes_in_group("mobs"):
			var m := node as Mob
			if m == null or m.is_dead or m.slot < 0:
				continue
			if Vector2(m.global_position.x, m.global_position.z).distance_to(vc) > VILLAGE_R:
				continue
			near += 1
			if m.level > VILLAGE_MAX:
				bad.append("%s %d ур. у %s" % [m.mob_name, m.level, String(vz["id"])])
	check(bad.is_empty(), "звери у деревень (%d) — не старше %d ур.%s" % [near, VILLAGE_MAX,
		"" if bad.is_empty() else ": " + ", ".join(bad)])


func _tp(c: Vector2, nm: String, take_shot: bool) -> void:
	bot.reset_camera()
	bot.teleport(c, nm)
	if take_shot:
		shot("Mir %s" % nm)


func _tp_check(nm: String) -> void:
	var p := player()
	var w := IslandWorld.current
	if p == null or w == null:
		return
	var q := p.global_position
	var g := w.height_at(q.x, q.z)
	var ok := w.is_walkable(q.x, q.z) and q.y > g - UNDER and q.y < g + 3.0
	if not check(ok, "перенос «%s»: герой на земле (%.0f, %.0f), высота %.2f, рельеф %.2f" % [nm, q.x, q.z, q.y, g]):
		_tp_bad += 1


# ---------- Ходьба джойстиком ----------

## Точки дороги road (с концами), длина пути.
static func road_points(road: String) -> Array[Vector3]:
	var res: Array[Vector3] = []
	var w := IslandWorld.current
	if w == null:
		return res
	var path: Array = w.cfg.get("roads", {}).get("paths", {}).get(road, [])
	for p in path:
		var v := IslandWorld.v2(p)
		res.append(w.ground(v.x, v.y))
	return res


func _walk_timeout(road: String) -> float:
	var pts := road_points(road)
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
	# Бег ~7 м/с, с обходом через мост и запасом
	return total / 3.5 + 20.0


func _walk_start(road: String) -> void:
	_road = road
	_route = road_points(road)
	_wi = 1
	_stuck_n = 0
	_fall_n = 0
	_walked = 0.0
	_nav.reset()
	if _route.size() < 2:
		check(false, "дорога «%s» есть в мире" % road)
		_route.clear()
		return
	var p := player()
	p.global_position = _route[0]
	p.velocity = Vector3.ZERO
	_st_t = 0.0
	_st_from = p.global_position
	_last = p.global_position
	bot.reset_camera()
	shot("Doroga %s" % road)
	bot.tick(_drive)


## Каждый кадр: джойстик к следующей точке (через мост, если по прямой вода), застревание, провал.
func _drive(dt: float) -> void:
	var p := player()
	var h := hud()
	if p == null or h == null:
		return
	if _wi >= _route.size():
		h.move_vec = Vector2.ZERO
		return
	var pos := p.global_position
	_walked += Vector2(pos.x - _last.x, pos.z - _last.z).length()
	_last = pos
	var tgt := _route[_wi]
	if Vector2(tgt.x - pos.x, tgt.z - pos.z).length() < REACH:
		_wi += 1
		_nav.reset()
		return
	var dir := _nav.dir_to(pos, tgt, dt)
	if dir.length() < 0.01:
		dir = Vector3(tgt.x - pos.x, 0.0, tgt.z - pos.z).normalized()
	# Джойстик — относительно камеры (main: dir = (mv.x, 0, mv.y) повёрнут на cam_yaw)
	var yaw := float(bot.main.get("cam_yaw"))
	var mv := Vector3(dir.x, 0.0, dir.z).rotated(Vector3.UP, -yaw)
	h.move_vec = Vector2(mv.x, mv.z)
	# Провал под землю
	var w := IslandWorld.current
	if w != null and pos.y < w.height_at(pos.x, pos.z) - UNDER:
		_fall_n += 1
		check(false, "дорога «%s»: герой под землёй у (%.0f, %.0f): высота %.2f, рельеф %.2f" % [_road, pos.x, pos.z,
			pos.y, w.height_at(pos.x, pos.z)])
		_skip_to(tgt)
		return
	# Застревание
	_st_t += dt
	if _st_t >= STUCK_TIME:
		var moved := Vector2(pos.x - _st_from.x, pos.z - _st_from.z).length()
		if moved < STUCK_MOVE:
			_stuck_n += 1
			check(false, "дорога «%s»: застрял у (%.1f, %.1f) — за %.0f с сдвинулся на %.2f м (к точке %d из %d)" % [_road,
				pos.x, pos.z, STUCK_TIME, moved, _wi + 1, _route.size()])
			shot("Zastryal %s" % _road)
			_skip_to(tgt)
		_st_t = 0.0
		_st_from = p.global_position


## Перенести героя к точке маршрута и идти дальше.
func _skip_to(tgt: Vector3) -> void:
	var p := player()
	p.global_position = ground(tgt.x, tgt.z)
	p.velocity = Vector3.ZERO
	_last = p.global_position
	_st_from = p.global_position
	_st_t = 0.0
	_wi += 1
	_nav.reset()


func _walk_done() -> bool:
	return _wi >= _route.size()


func _walk_end() -> void:
	bot.tick(Callable())
	var h := hud()
	if h != null:
		h.move_vec = Vector2.ZERO
	check(_wi >= _route.size(), "дорога «%s» пройдена до конца (точка %d из %d)" % [_road, mini(_wi + 1, _route.size()),
		_route.size()])
	check(_stuck_n == 0 and _fall_n == 0, "дорога «%s»: без застреваний и провалов (застреваний %d, провалов %d), пройдено %.0f м"
		% [_road, _stuck_n, _fall_n, _walked])
