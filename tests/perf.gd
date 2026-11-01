extends "res://tests/test_base.gd"
## Замер нагрузки на настоящем рендере (CI, задача visual): для каждого пресета качества и
## нескольких точек острова — вызовы отрисовки, объекты, треугольники в кадре и время скриптов.
## Строки начинаются с «PERF» — их собирает .github/scripts/perf.sh (задачи perf в check.yml).
## Время кадра на программном рендере CI не показательно, важны вызовы, объекты и треугольники.
## «Максимальное» — только в первых ULTRA_SPOTS точках (время задачи visual ограничено).
## Пресеты: все по порядку или только --perf-levels=0,1 (номера Quality.LOW…ULTRA; CI делит замер на задачи perf).
##
## Сравнение до/после: BASELINE — замер CI до оптимизации нагрева (тени 4 каскада в атласе 4096, родное
## разрешение, деревья до 248 м, контуры везде); в строке PERF — «было … (±N %)».
## Разбор по частям (в точке BREAKDOWN_SPOT каждого пресета): часть скрывается на несколько кадров, разница
## вызовов и треугольников — её доля («PERF   часть …»): тени (солнце без теней — проход карты теней), контуры,
## персонажи (герой и жители), звери и питомцы, постройки, деревья, кусты и камни, трава и цветы, земля и вода.
## Треугольники Godot считает с LOD (у моделей героев, жителей и зверей) и по каждому каскаду теней.

const SPOTS := [["город", Vector2(0, 5)], ["поле", Vector2(30, 30)], ["тёмные эльфы", Vector2(72, -58)],
	["светлые эльфы", Vector2(-80, -50)], ["деревня людей", Vector2(80, 32)], ["порт", Vector2(12, 60)]]
const FRAMES := 40
const ULTRA_SPOTS := 2
## Замер до оптимизации нагрева (CI, ветка ci-screenshots, perf.txt): пресет → [вызовов, треугольников] по SPOTS.
const BASELINE := [
	[[96, 267328], [92, 195931], [79, 142344], [79, 162885], [78, 181457], [90, 156830]],
	[[232, 1278849], [177, 770255], [151, 632550], [159, 739842], [158, 727135], [161, 565546]],
	[[316, 1474122], [294, 1099268], [230, 854461], [235, 947572], [240, 914950], [245, 789502]],
	[[520, 2424784], [471, 1720826]],
]
## Точка разбора по частям (номер в SPOTS).
const BREAKDOWN_SPOT := 0
const PARTS := ["тени", "контуры", "персонажи", "звери и питомцы", "постройки", "деревья", "кусты и камни",
	"трава и цветы", "земля и вода"]
## Кадров до замера части (часть скрыта) и кадров замера.
const PART_WAIT := 2
const PART_FRAMES := 3

var _q := 0
## Пресеты замера по порядку и номер текущего в этом списке.
var _levels: Array[int] = []
var _li := 0
var _spot := 0
var _acc := {}
var _n := 0
## Разбор: вызовы и треугольники всей сцены, номер части, скрытые узлы части.
var _base := Vector2.ZERO
var _part := 0
var _hidden: Array[GeometryInstance3D] = []
var _parts_of := {}


func before_start() -> void:
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--perf-levels="):
			for v in s.get_slice("=", 1).split(",", false):
				var lv: int = String(v).to_int()
				if lv >= Quality.LOW and lv <= Quality.ULTRA and not _levels.has(lv):
					_levels.append(lv)
	if _levels.is_empty():
		for i in range(Quality.LOW, Quality.ULTRA + 1):
			_levels.append(i)
	_q = _levels[0]


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
				var draw := int(_acc["draw"] / k)
				var prim := int(_acc["prim"] / k)
				print("PERF %-8s %-14s вызовов %5d  объектов %5d  треуг. %7d  кадр(process) %.1f мс  физика %.1f мс%s" % [
					Quality.level_name(_q), SPOTS[_spot][0], draw, int(_acc["obj"] / k),
					prim, _acc["proc"] / k, _acc["phys"] / k, _was(draw, prim)])
				if _spot == BREAKDOWN_SPOT:
					_base = Vector2(draw, prim)
					_part = 0
					_parts_of = _classify()
					_hide_part()
					wait = PART_WAIT
					step = 2
					return
				_next_spot()
		2:
			_acc = {"draw": 0.0, "prim": 0.0}
			_n = 0
			step = 3
			_sample_part()
		3:
			_sample_part()


## «было …» по BASELINE: вызовы и треугольники до оптимизации и изменение, %.
func _was(draw: int, prim: int) -> String:
	if _q >= BASELINE.size():
		return ""
	var row: Array = BASELINE[_q]
	if _spot >= row.size():
		return ""
	var b: Array = row[_spot]
	var bd := float(b[0])
	var bp := float(b[1])
	return "  | было вызовов %d (%+.0f %%), треуг. %d (%+.0f %%)" % [int(bd), (float(draw) / maxf(bd, 1.0) - 1.0) * 100.0,
		int(bp), (float(prim) / maxf(bp, 1.0) - 1.0) * 100.0]


## Кадр замера скрытой части; набралось — строка и следующая часть.
func _sample_part() -> void:
	_acc["draw"] += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	_acc["prim"] += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	_n += 1
	if _n < PART_FRAMES:
		return
	var d: float = _base.x - float(_acc["draw"]) / float(_n)
	var t: float = _base.y - float(_acc["prim"]) / float(_n)
	print("PERF   часть %-8s %-16s вызовов %5d (%3.0f %%)  треуг. %8d (%3.0f %%)  узлов %d" % [Quality.level_name(_q),
		PARTS[_part], int(d), d / maxf(_base.x, 1.0) * 100.0, int(t), t / maxf(_base.y, 1.0) * 100.0,
		_hidden.size()])
	_show_part()
	_part += 1
	if _part >= PARTS.size():
		_next_spot()
		return
	_hide_part()
	wait = PART_WAIT
	step = 2


## Следующая точка или пресет; всё — конец.
func _next_spot() -> void:
	_spot += 1
	if _spot >= (ULTRA_SPOTS if _q == Quality.ULTRA else SPOTS.size()):
		_spot = 0
		_li += 1
		if _li < _levels.size():
			_q = _levels[_li]
	if _li >= _levels.size():
		print("PERF узлов в сцене: %d, зверей: %d, моделей под ModelLod: %d" % [
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), count_mobs(), ModelLod.count()])
		Quality.reload()
		ok_done()
		return
	step = 0


## Скрыть часть PARTS[_part] (тени — солнце без теней, контуры — настройка «Контуры: Выкл»).
func _hide_part() -> void:
	_hidden.clear()
	var pname := String(PARTS[_part])
	match pname:
		"тени":
			for s in _suns():
				s.shadow_enabled = false
		"контуры":
			Quality.set_option("outlines", 0, false)
			Quality.apply(get_tree())
		_:
			var list: Array = _parts_of.get(pname, [])
			for gi in list:
				var g := gi as GeometryInstance3D
				if is_instance_valid(g) and g.visible:
					g.visible = false
					_hidden.append(g)


func _show_part() -> void:
	match String(PARTS[_part]):
		"тени":
			Quality.apply_lights(get_tree().root)
		"контуры":
			Quality.set_level(_q, false)
			Quality.apply(get_tree())
	for g in _hidden:
		if is_instance_valid(g):
			g.visible = true
	_hidden.clear()


func _suns() -> Array[DirectionalLight3D]:
	var out: Array[DirectionalLight3D] = []
	for n in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
		out.append(n as DirectionalLight3D)
	return out


## Все видимые геометрии сцены по частям (имя части → узлы).
func _classify() -> Dictionary:
	var out := {}
	for n in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		if gi == null or not gi.is_visible_in_tree():
			continue
		var part := _part_of(gi)
		if part == "":
			continue
		if not out.has(part):
			out[part] = []
		(out[part] as Array).append(gi)
	return out


func _part_of(gi: Node) -> String:
	var p: Node = gi
	while p != null:
		if p is Mob or p is Pet or p is CreatureAsset:
			return "звери и питомцы"
		if p is CharacterModel or p is Npc or p is Player:
			return "персонажи"
		if p.is_in_group("veg_grass") or p.is_in_group("veg_flowers"):
			return "трава и цветы"
		if p.is_in_group("veg_trees"):
			return "деревья"
		if p.is_in_group("veg_small") or p.is_in_group("veg_glow"):
			return "кусты и камни"
		if p.is_in_group("veg_far"):
			# Двойник участка без контура: группа — по номеру слияния в имени «Decor<группа>_x_zFar»
			var z := String(p.name).get_slice("_", 0).trim_prefix("Decor").to_int()
			return "деревья" if String(IslandVegetation.GROUP_NAMES[clampi(z, 0, 6)]) == "veg_trees" else "кусты и камни"
		if String(p.name) == "Pois":
			return "постройки"
		if p is IslandWorld:
			return "земля и вода"
		p = p.get_parent()
	return ""
