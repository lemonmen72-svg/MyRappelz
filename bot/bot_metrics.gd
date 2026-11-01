class_name BotMetrics
extends RefCounted
## Замер тест-бота (TestBot, шаг «measure»): время каждого кадра (настоящее, по часам — не delta движка), к/с,
## процентили, счётчики отрисовки (вызовы, треугольники, объекты — Performance, как tests/perf.gd), время работы
## кадра у видеочипа и процессора (RenderingServer.viewport_get_measured_render_time_*; у GL Compatibility на
## телефоне бывает 0 — тогда «—»), время скриптов, память и видеопамять.
## begin(viewport) → frame(dt) каждый кадр → finish() → словарь (ключи — в finish).

## Кадр дольше стольких мс — заминка.
const HITCH_MS := 100.0

var _ft: PackedFloat32Array = PackedFloat32Array()
var _draw := 0.0
var _prim := 0.0
var _obj := 0.0
var _proc := 0.0
var _gpu := 0.0
var _gpu_n := 0
var _cpu := 0.0
var _cpu_n := 0
var _mem := 0.0
var _vmem := 0.0
var _tex := 0.0
var _vp := RID()


## Начать замер окна viewport (null — без времени видеочипа).
func begin(viewport: Viewport) -> void:
	_ft = PackedFloat32Array()
	_draw = 0.0
	_prim = 0.0
	_obj = 0.0
	_proc = 0.0
	_gpu = 0.0
	_gpu_n = 0
	_cpu = 0.0
	_cpu_n = 0
	_mem = 0.0
	_vmem = 0.0
	_tex = 0.0
	_vp = RID()
	if viewport != null:
		_vp = viewport.get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(_vp, true)


## Кадр: dt — его настоящая длительность, с.
func frame(dt: float) -> void:
	_ft.append(dt * 1000.0)
	_draw += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	_prim += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	_obj += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	_proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_mem = maxf(_mem, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
	_vmem = maxf(_vmem, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)
	_tex = maxf(_tex, Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0)
	if _vp.is_valid():
		var g := RenderingServer.viewport_get_measured_render_time_gpu(_vp)
		if g > 0.0:
			_gpu += g
			_gpu_n += 1
		var c := RenderingServer.viewport_get_measured_render_time_cpu(_vp)
		if c > 0.0:
			_cpu += c
			_cpu_n += 1


func frames() -> int:
	return _ft.size()


## Итог: frames, sec, fps (среднее), fps_min (худшая секунда), ms (среднее), p50, p95, p99, max, hitches (кадров
## дольше HITCH_MS), draw, prim, obj (среднее за кадр), proc (скрипты, мс), gpu, cpu (мс; −1 — нет данных),
## mem, vmem, tex (МБ, наибольшее).
func finish() -> Dictionary:
	if _vp.is_valid():
		RenderingServer.viewport_set_measure_render_time(_vp, false)
	var n := _ft.size()
	var res := {"frames": n, "sec": 0.0, "fps": 0.0, "fps_min": 0.0, "ms": 0.0, "p50": 0.0, "p95": 0.0, "p99": 0.0,
		"max": 0.0, "hitches": 0, "draw": 0.0, "prim": 0.0, "obj": 0.0, "proc": 0.0, "gpu": -1.0, "cpu": -1.0,
		"mem": _mem, "vmem": _vmem, "tex": _tex}
	if n == 0:
		return res
	var total := 0.0
	var hitches := 0
	for v in _ft:
		total += v
		if v > HITCH_MS:
			hitches += 1
	var sorted := _ft.duplicate()
	sorted.sort()
	var k := float(n)
	res["sec"] = total / 1000.0
	res["fps"] = k / maxf(total / 1000.0, 0.000001)
	res["fps_min"] = _worst_second(float(res["fps"]))
	res["ms"] = total / k
	res["p50"] = percentile(sorted, 0.5)
	res["p95"] = percentile(sorted, 0.95)
	res["p99"] = percentile(sorted, 0.99)
	res["max"] = sorted[n - 1]
	res["hitches"] = hitches
	res["draw"] = _draw / k
	res["prim"] = _prim / k
	res["obj"] = _obj / k
	res["proc"] = _proc / k
	if _gpu_n > 0:
		res["gpu"] = _gpu / float(_gpu_n)
	if _cpu_n > 0:
		res["cpu"] = _cpu / float(_cpu_n)
	return res


## Значение доли q (0…1) отсортированного массива.
static func percentile(sorted: PackedFloat32Array, q: float) -> float:
	if sorted.is_empty():
		return 0.0
	var i := clampi(int(ceil(q * float(sorted.size()))) - 1, 0, sorted.size() - 1)
	return sorted[i]


## К/с худшей секунды: кадры подряд набираются в окна не короче секунды; окон нет — среднее fps.
func _worst_second(avg: float) -> float:
	var worst := -1.0
	var acc := 0.0
	var cnt := 0
	for v in _ft:
		acc += v
		cnt += 1
		if acc >= 1000.0:
			var f := float(cnt) / (acc / 1000.0)
			if worst < 0.0 or f < worst:
				worst = f
			acc = 0.0
			cnt = 0
	return avg if worst < 0.0 else worst
