class_name CardinalWalk
extends RefCounted
## Ходьба Кардинала к точке (как игрок): путь по сетке CardinalNav (точки поворота AStarGrid2D — между ними прямая по
## свободным клеткам), обход шагом вбок, если за DETOUR_CHECK с почти не сдвинулся, без сетки — маршрут существ
## IslandWorld.Route (мосты через реку). Общая для CardinalStory._go и теста tests/test_bridge_walk.gd.
##
## Прогресс — ОСТАТОК ПУТИ по точкам (от героя до текущей точки + отрезки до цели), а не расстояние по прямой: путь
## через реку уводит к мосту и вдоль него — по прямой цель не ближе (а то и дальше), а герой идёт. До 0.43 прогресс
## мерился по прямой, и 14 с в обход реки считались «застрял» — Кардинала переносило у мостов (отчёты 0.34–0.41:
## все переносы — у концов мостов и на настиле). Застрял — остаток пути не короче на PROGRESS м за stuck_sec с
## своего времени ходьбы (бои по дороге в него не входят: step не зовётся).

const DETOUR_CHECK := 1.2
const DETOUR_SEC := 1.6
const PROGRESS := 0.5
## Ближе этого к точке пути — к следующей, м.
const POINT_NEAR := 1.0

var to := Vector3.ZERO
var near := 1.0
var stuck_sec := 14.0
## "walk" — идёт, "arrived" — пришёл (ближе near по земле), "stuck" — застрял.
var status := "walk"
var path := PackedVector3Array()
var pi := 0
var best := INF
var best_t := 0.0
## Своё время ходьбы, с (сумма dt шагов).
var t := 0.0
var route := IslandWorld.Route.new()
## Сколько раз путь пересчитывался (обход, бой), обходов шагом вбок.
var repaths := 0
var detours := 0

var _win_pos := Vector3.ZERO
var _win_t := 0.0
var _detour_until := -1.0
var _detour_to := Vector3.ZERO
var _side := 1.0
var _fails := 0


## Начать путь от from к target (ближе near_m — пришёл); stuck — с без прогресса до «застрял».
func begin(from: Vector3, target: Vector3, near_m: float, stuck: float) -> void:
	to = target
	near = near_m
	stuck_sec = stuck
	status = "walk"
	t = 0.0
	best = INF
	best_t = 0.0
	_win_pos = from
	_win_t = 0.0
	_detour_until = -1.0
	_side = 1.0
	_fails = 0
	route.reset()
	path = CardinalNav.path(from, to)
	pi = 0
	best = remaining(from)


## Путь заново от from (после боя, обхода, переноса). Лучший остаток и его время не сбрасываются: обход по кругу не
## должен откладывать «застрял» без конца.
func repath(from: Vector3) -> void:
	path = CardinalNav.path(from, to)
	pi = 0
	route.reset()
	repaths += 1


## После переноса к цели: всё заново.
func restart(from: Vector3) -> void:
	begin(from, to, near, stuck_sec)


## Остаток пути от pos: до текущей точки пути, дальше по точкам и до цели (пути нет — по прямой).
func remaining(pos: Vector3) -> float:
	if path.is_empty() or pi >= path.size():
		return flat(pos, to)
	var s := flat(pos, path[pi])
	for k in range(pi, path.size() - 1):
		s += flat(path[k], path[k + 1])
	return s + flat(path[path.size() - 1], to)


static func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Шаг ходьбы: pos — где герой, dt — игровые секунды с прошлого шага. Возвращает направление по земле (единичное;
## ZERO — пришёл или застрял), status — что вышло.
func step(pos: Vector3, dt: float) -> Vector3:
	t += dt
	if flat(pos, to) <= near:
		status = "arrived"
		return Vector3.ZERO
	var rem := remaining(pos)
	if rem < best - PROGRESS:
		best = rem
		best_t = t
	elif t - best_t > stuck_sec:
		status = "stuck"
		return Vector3.ZERO
	status = "walk"
	# Обход: за DETOUR_CHECK с почти не сдвинулся — шаг вбок (каждые два неудачных — в другую сторону)
	if t - _win_t >= DETOUR_CHECK:
		var moved := flat(pos, _win_pos)
		if moved < 0.8 and t >= _detour_until:
			_fails += 1
			if _fails % 2 == 0:
				_side = -_side
			_detour_to = _detour_point(pos, _side, 2.0 + float(_fails))
			_detour_until = t + DETOUR_SEC
			detours += 1
		elif moved >= 0.8 and t >= _detour_until:
			_fails = 0
		_win_pos = pos
		_win_t = t
	if t < _detour_until:
		var dd := Vector3(_detour_to.x - pos.x, 0.0, _detour_to.z - pos.z)
		if dd.length() < 0.5:
			_detour_until = -1.0
			repath(pos)
		else:
			return dd.normalized()
	if not path.is_empty() and pi < path.size():
		while pi < path.size() - 1 and flat(pos, path[pi]) < POINT_NEAR:
			pi += 1
		if pi == path.size() - 1 and flat(pos, path[pi]) < POINT_NEAR:
			pi += 1
		var aim: Vector3 = path[pi] if pi < path.size() else to
		return Vector3(aim.x - pos.x, 0.0, aim.z - pos.z).normalized()
	var dir := route.dir_to(pos, to, dt)
	if dir.length() < 0.01:
		dir = Vector3(to.x - pos.x, 0.0, to.z - pos.z).normalized()
	return dir


## Точка обхода: вбок от направления на цель (side ±1), на проходимой земле, dist м.
func _detour_point(pos: Vector3, side: float, dist: float) -> Vector3:
	var fwd := Vector3(to.x - pos.x, 0.0, to.z - pos.z).normalized()
	var w := IslandWorld.current
	for a in [90.0, 60.0, 120.0, 135.0, 45.0, 160.0]:
		var d := fwd.rotated(Vector3.UP, deg_to_rad(a) * side)
		var q := pos + d * dist
		if w == null or w.is_walkable(q.x, q.z):
			return q
	return pos - fwd * dist
