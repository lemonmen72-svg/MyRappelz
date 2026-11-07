extends "res://tests/test_base.gd"
## Герой физикой через мосты острова (0.43, жалоба Максима: Кардинала переносило у мостов). Две части:
## 1) у каждого моста в обе стороны — по оси дороги, наискось с берега (ходьба Кардинала CardinalWalk: путь по сетке
##    CardinalNav, обход), с края настила посреди моста, маршрутом существ IslandWorld.Route (питомцы, звери);
## 2) дальние поездки между жителями через реку (город — Западный лагерь, деревня светлых эльфов, пост наёмников) —
##    той же ходьбой CardinalWalk, что у CardinalStory._go: дошёл без «застрял». Для сравнения считается, сколько
##    поездок прежний подсчёт прогресса (расстояние по прямой, до 0.43) объявил бы «застрял» — так и выходили
##    переносы у мостов: путь к мосту и вдоль него по прямой цель не приближает.
## Застрял по-настоящему (3 с не сдвинулся на 0.3 м) или CardinalWalk сказал «застрял» — ошибка с местом.

## Кадров на одну прогулку (60 = 1 с).
const WALK_LIMIT := 60 * 60
## Сколько кадров без движения — «не двигается».
const STALL := 60 * 3
## Поездки между жителями: [откуда, куда] (id NpcData).
const TRIPS := [["sage", "hunter"], ["hunter", "sage"], ["kirk", "elder_light"], ["elder_light", "kirk"],
	["jeweler", "merc_chief"], ["merc_chief", "jeweler"], ["herbalist", "smith"], ["hunter", "elder_light"]]

var walks: Array = []
var wi := 0
var walker := CardinalWalk.new()
var route := IslandWorld.Route.new()
var moved_f := 0
var moved_pos := Vector3.ZERO
var t0 := 0
var old_best := INF
var old_best_t := 0.0
var old_stuck := false
var stuck: Array[String] = []
var old_stucks := 0
var trips_done := 0


func race_class() -> Array:
	return ["human", "warrior"]


func hero_level() -> int:
	return 20


func before_start() -> void:
	# Звери не нужны (бои не идут) — меньше тел на острове, прогулки быстрее
	Quality.mob_range_override = 0


func run_step() -> void:
	match step:
		0:
			if not bool(main.get("_started")):
				return
			AdminPanel.god = true
			max_frames = 60 * 60 * 30
			var w := IslandWorld.current
			check(w != null and w.bridges.size() >= 3, "мостов на острове: %d" % (w.bridges.size() if w != null else 0))
			CardinalNav.ensure(w, get_tree())
			_plan(w)
			print("МОСТЫ: прогулок %d" % walks.size())
			step = 1
		1:
			if wi >= walks.size():
				main.player.move_input = Vector2.ZERO
				main.hud.move_vec = Vector2.ZERO
				AdminPanel.god = false
				check(stuck.is_empty(), "герой прошёл мосты и дальние поездки через реку (%d)%s" % [walks.size(),
					"" if stuck.is_empty() else "; застрял: " + "; ".join(stuck)])
				check(trips_done >= 10, "дальних поездок через реку пройдено %d" % trips_done)
				print("МОСТЫ: прежний подсчёт прогресса (по прямой) объявил бы «застрял» на %d из %d дальних поездок" % [
					old_stucks, trips_done])
				ok_done()
				return
			_start(walks[wi])
			step = 2
		2:
			_drive()


## Прогулки у каждого моста и дальние поездки между жителями.
func _plan(w: IslandWorld) -> void:
	for bi in w.bridges.size():
		var br: Dictionary = w.bridges[bi]
		var a: Vector3 = br["a"]
		var e: Vector3 = br["b"]
		var u := Vector3(e.x - a.x, 0.0, e.z - a.z).normalized()
		var v := Vector3(-u.z, 0.0, u.x)
		var nm := "мост %d (%.0f, %.0f)–(%.0f, %.0f)" % [bi, a.x, a.z, e.x, e.z]
		for dirn: int in [1, -1]:
			var p0: Vector3 = a if dirn == 1 else e
			var p1: Vector3 = e if dirn == 1 else a
			var du: Vector3 = u * float(dirn)
			var arrow := " →" if dirn == 1 else " ←"
			_add(w, nm + " по оси" + arrow, p0 - du * 12.0, p1 + du * 12.0, "walk")
			for sv: float in [1.0, -1.0]:
				_add(w, nm + " наискось с берега" + arrow + (" слева" if sv > 0 else " справа"),
					p0 - du * 8.0 + v * 7.0 * sv, p1 + du * 8.0 - v * 7.0 * sv, "walk")
			_add(w, nm + " путь существ" + arrow, p0 - du * 8.0 + v * 6.0, p1 + du * 8.0 - v * 6.0, "route")
			# С края настила посреди моста (остановился на мосту — бой, отдых) — к берегу
			var mid := IslandWorld.bridge_point(br, 0.5)
			for sv: float in [1.0, -1.0]:
				var edge: Vector3 = mid + v * sv * (float(br["width"]) * 0.5 - 0.45)
				edge.y = mid.y + 0.3
				walks.append({"name": nm + " с края настила" + arrow + (" слева" if sv > 0 else " справа"),
					"start": edge, "goal": p1 + du * 10.0, "mode": "walk", "deck": true})
	# Вдоль реки на тот берег: старт и цель — в 55 м от моста вверх или вниз по течению, по разные стороны реки. По
	# прямой цель рядом (через воду), путь — к мосту и обратно вдоль реки: прямая до цели долго не короче
	for bi in w.bridges.size():
		var br2: Dictionary = w.bridges[bi]
		var a2: Vector3 = br2["a"]
		var e2: Vector3 = br2["b"]
		var u2 := Vector3(e2.x - a2.x, 0.0, e2.z - a2.z).normalized()
		var v2 := Vector3(-u2.z, 0.0, u2.x)
		for sv: float in [1.0, -1.0]:
			_add(w, "поездка вдоль реки у моста %d%s" % [bi, " вверх" if sv > 0 else " вниз"], a2 - u2 * 6.0 + v2 * 55.0 * sv,
				e2 + u2 * 6.0 + v2 * 55.0 * sv, "walk", true)
	var npcs: Npcs = main.get("npcs") as Npcs
	for tr in TRIPS:
		var a3 := _npc_pos(npcs, String(tr[0]))
		var b3 := _npc_pos(npcs, String(tr[1]))
		if not a3.is_finite() or not b3.is_finite():
			print("МОСТЫ: пропуск поездки %s → %s — жителя нет" % [tr[0], tr[1]])
			continue
		_add(w, "поездка %s → %s" % [tr[0], tr[1]], a3, b3, "walk", true)


func _npc_pos(npcs: Npcs, id: String) -> Vector3:
	if npcs == null:
		return Vector3.INF
	var n := npcs.npc(id)
	if n == null:
		return Vector3.INF
	# Встать в 3 м перед жителем (сам житель — капсула коллизии)
	var p := n.global_position
	return p + n.global_transform.basis.z.normalized() * 3.0


func _add(w: IslandWorld, nm: String, s: Vector3, g: Vector3, mode: String, trip: bool = false) -> void:
	var s2 := _dry(w, s)
	var g2 := _dry(w, g)
	if not s2.is_finite() or not g2.is_finite():
		print("МОСТЫ: пропуск «%s» — нет суши рядом" % nm)
		return
	walks.append({"name": nm, "start": s2, "goal": g2, "mode": mode, "trip": trip})


## Ближайшая к p проходимая суша (не вода, не под постройкой).
func _dry(w: IslandWorld, p: Vector3) -> Vector3:
	for r in [0.0, 1.0, 2.0, 3.0, 4.5]:
		for k in 12:
			var q: Vector3 = p + Vector3(cos(TAU * k / 12.0), 0.0, sin(TAU * k / 12.0)) * r
			if w.is_walkable(q.x, q.z) and CardinalNav.free_at(q) and w.water_distance(q.x, q.z) > 3.0:
				return Vector3(q.x, w.height_at(q.x, q.z), q.z)
			if r == 0.0:
				break
	return Vector3.INF


func _start(wk: Dictionary) -> void:
	var p: Player = main.player
	var s: Vector3 = wk["start"]
	var w := IslandWorld.current
	if bool(wk.get("deck", false)):
		p.global_position = s
	else:
		p.global_position = Vector3(s.x, w.height_at(s.x, s.z) + 0.4, s.z)
	p.velocity = Vector3.ZERO
	route.reset()
	var g: Vector3 = wk["goal"]
	walker = CardinalWalk.new()
	walker.begin(p.global_position, g, 1.2, 14.0)
	moved_f = frame
	moved_pos = p.global_position
	t0 = frame
	old_best = INF
	old_best_t = 0.0
	old_stuck = false


## Шаг: ходьба Кардинала (CardinalWalk.step) или маршрут существ (Route.dir_to), как джойстик игрока.
func _drive() -> void:
	var p: Player = main.player
	var wk: Dictionary = walks[wi]
	var g: Vector3 = wk["goal"]
	var pos := p.global_position
	var secs := float(frame - t0) / 60.0
	if CardinalWalk.flat(pos, moved_pos) > 0.3:
		moved_pos = pos
		moved_f = frame
	# Прежний подсчёт (до 0.43): расстояние по прямой не короче на 0.5 м за 14 с — «застрял»
	var d := CardinalWalk.flat(pos, g)
	if d < old_best - 0.5:
		old_best = d
		old_best_t = secs
	elif secs - old_best_t > 14.0:
		old_stuck = true
	var dir := Vector3.ZERO
	var arrived := d < 1.2
	var why := ""
	if String(wk["mode"]) == "route":
		dir = route.dir_to(pos, g, 1.0 / 60.0)
		if dir.length() < 0.01:
			dir = Vector3(g.x - pos.x, 0.0, g.z - pos.z).normalized()
	else:
		dir = walker.step(pos, 1.0 / 60.0)
		arrived = walker.status == "arrived"
		if walker.status == "stuck":
			why = "CardinalWalk: остаток пути %.1f м не короче 14 с" % walker.remaining(pos)
	if not arrived and why == "" and frame - moved_f > STALL:
		why = "3 с не двигается"
	if not arrived and why == "" and frame - t0 > WALK_LIMIT:
		why = "не дошёл за %.0f с" % (float(WALK_LIMIT) / 60.0)
	if arrived or why != "":
		p.move_input = Vector2.ZERO
		main.hud.move_vec = Vector2.ZERO
		var trip := bool(wk.get("trip", false))
		if arrived:
			print("МОСТЫ: %s — дошёл за %.1f с%s%s" % [String(wk["name"]), secs,
				" (путь пересчитан %d, обходов %d)" % [walker.repaths, walker.detours] if String(wk["mode"]) == "walk" else "",
				"; по прямой было бы «застрял»" if old_stuck else ""])
			if trip:
				trips_done += 1
				if old_stuck:
					old_stucks += 1
		else:
			var msg := "%s — ЗАСТРЯЛ (%s) у (%.2f, %.2f, %.2f), до цели %.1f м, %.1f с" % [String(wk["name"]), why, pos.x,
				pos.y, pos.z, d, secs]
			print("МОСТЫ: " + msg)
			stuck.append(msg)
		wi += 1
		step = 1
		return
	# Как джойстик игрока: main._process каждый кадр переводит HUD.move_vec (относительно камеры) в move_input
	var mv := Vector3(dir.x, 0.0, dir.z).rotated(Vector3.UP, -float(main.cam_yaw))
	main.hud.move_vec = Vector2(mv.x, mv.z)
	p.move_input = Vector2(dir.x, dir.z)
