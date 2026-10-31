extends "res://tests/test_base.gd"
## Замер нагрузки на настоящем рендере (CI, задача visual): для каждого пресета качества и
## нескольких точек острова — вызовы отрисовки, объекты, треугольники в кадре и время скриптов.
## Строки начинаются с «PERF» — их собирает .github/scripts/screenshots.sh.
## Время кадра на программном рендере CI не показательно, важны вызовы, объекты и треугольники.
## «Максимальное» — только в первых ULTRA_SPOTS точках (время задачи visual ограничено).

const SPOTS := [["город", Vector2(0, 5)], ["поле", Vector2(30, 30)], ["тёмные эльфы", Vector2(72, -58)],
	["светлые эльфы", Vector2(-80, -50)], ["деревня людей", Vector2(80, 32)], ["порт", Vector2(12, 60)]]
const FRAMES := 40
const ULTRA_SPOTS := 2

var _q := 0
var _spot := 0
var _acc := {}
var _n := 0


func run_step() -> void:
	match step:
		0:
			Quality.set_level(_q, false)
			Quality.apply(get_tree())
			var p: Vector2 = SPOTS[_spot][1]
			main.player.global_position = IslandWorld.current.ground(p.x, p.y, 0.2)
			_acc = {"draw": 0.0, "obj": 0.0, "prim": 0.0, "proc": 0.0, "phys": 0.0}
			_n = 0
			wait = 30
			step = 1
		1:
			_acc["draw"] += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			_acc["obj"] += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
			_acc["prim"] += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
			_acc["proc"] += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			_acc["phys"] += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			_n += 1
			if _n >= FRAMES:
				var k := float(_n)
				print("PERF %-8s %-14s вызовов %5d  объектов %5d  треуг. %7d  кадр(process) %.1f мс  физика %.1f мс" % [
					Quality.level_name(_q), SPOTS[_spot][0], int(_acc["draw"] / k), int(_acc["obj"] / k),
					int(_acc["prim"] / k), _acc["proc"] / k, _acc["phys"] / k])
				_spot += 1
				if _spot >= (ULTRA_SPOTS if _q == Quality.ULTRA else SPOTS.size()):
					_spot = 0
					_q += 1
				if _q > Quality.ULTRA:
					print("PERF узлов в сцене: %d, зверей: %d" % [
						int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), count_mobs()])
					Quality.reload()
					ok_done()
					return
				step = 0
