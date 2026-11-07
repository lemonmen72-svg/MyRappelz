class_name NightLights
extends Node3D
## Ночные огни (0.46, задача Максима: «на факелах и кострах огонь своего цвета, а в тёмное время суток — свечение от
## них; свечение от кристаллов своего цвета»). Источники света в мире регистрируются (add: точка, цвет, радиус,
## вид — "fire" мерцает, "lamp", "crystal" пульсирует); настоящих OmniLight3D немного — пул count() (по качеству
## графики: на телефоне в GL Compatibility у объекта не больше 8 источников света), каждые REASSIGN с они
## переставляются к ближайшим к камере источникам (не дальше MAX_DIST), яркость — по ночи (Atmosphere.night():
## днём огонь светит слабо, ночью — в полную силу; в подземелье всегда ночь). Тени у огней выключены.
## Свечение вдали (ореолы, пламя) — у FireFx и ореолов построек, не здесь.

const REASSIGN := 0.4
const MAX_DIST := 45.0
## Сила днём (доля от ночной).
const DAY_SHARE := 0.15
## Источников света по настройке «Эффекты» («Низкое», «Среднее», «Высокое»).
const COUNTS := [3, 6, 8]

## Источники: {pos, color, range, energy, kind, phase}.
var sources: Array[Dictionary] = []
var _pool: Array[OmniLight3D] = []
var _assigned: Array[int] = []
var _t := 0.0
var _time := 0.0
## Сколько перестановок было (тесты).
var reassigns := 0
## Своя камера (тесты; null — камера вьюпорта).
var camera_override: Node3D = null

static var current: NightLights = null


func _ready() -> void:
	name = "NightLights"
	current = self
	_build_pool(count())


func _exit_tree() -> void:
	if current == self:
		current = null


## Сколько настоящих источников света (по настройке «Эффекты» с авто-снижением; тесты — count_override).
static var count_override := -1


static func count() -> int:
	if count_override >= 0:
		return count_override
	var lv := clampi(Quality.effective("effects"), 0, COUNTS.size() - 1)
	return int(COUNTS[lv])


## Источник света в точке pos (координаты мира): kind "fire" / "lamp" / "crystal".
func add(pos: Vector3, color: Color, range_m: float, energy: float, kind: String) -> void:
	sources.append({"pos": pos, "color": color, "range": range_m, "energy": energy, "kind": kind,
		"phase": fposmod(pos.x * 0.73 + pos.z * 1.31, TAU)})


static func add_source(pos: Vector3, color: Color, range_m: float, energy: float, kind: String) -> void:
	if current != null and is_instance_valid(current):
		current.add(pos, color, range_m, energy, kind)


func _build_pool(n: int) -> void:
	for l in _pool:
		l.queue_free()
	_pool.clear()
	_assigned.clear()
	for i in n:
		var om := OmniLight3D.new()
		om.name = "NightLight%d" % i
		om.shadow_enabled = false
		om.light_energy = 0.0
		om.visible = false
		om.omni_attenuation = 1.4
		add_child(om)
		_pool.append(om)
		_assigned.append(-1)


func _process(delta: float) -> void:
	tick(delta)


## Шаг на dt с: раз в REASSIGN — ближайшие источники, каждый кадр — яркость (ночь, мерцание огня).
func tick(dt: float) -> void:
	_time += dt
	if _pool.size() != count():
		_build_pool(count())
	_t -= dt
	if _t <= 0.0:
		_t = REASSIGN
		_reassign()
	var night := Atmosphere.night()
	var k := lerpf(DAY_SHARE, 1.0, night)
	for i in _pool.size():
		var si := _assigned[i]
		var om := _pool[i]
		if si < 0:
			om.visible = false
			continue
		var s: Dictionary = sources[si]
		var e := float(s["energy"]) * k
		match String(s["kind"]):
			"fire":
				var ph := float(s["phase"])
				e *= 0.82 + 0.12 * sin(_time * 9.0 + ph) + 0.06 * sin(_time * 23.0 + ph * 2.0)
			"crystal":
				e *= 0.85 + 0.15 * sin(_time * 1.6 + float(s["phase"]))
		om.light_energy = e
		om.visible = e > 0.01


func _camera_pos() -> Vector3:
	if camera_override != null and is_instance_valid(camera_override):
		return camera_override.global_position
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp != null else null
	return cam.global_position if cam != null else Vector3.ZERO


func _reassign() -> void:
	reassigns += 1
	var cp := _camera_pos()
	var best: Array = []
	for i in sources.size():
		var d := cp.distance_to(sources[i]["pos"])
		if d <= MAX_DIST + float(sources[i]["range"]):
			best.append([d, i])
	best.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for i in _pool.size():
		var om := _pool[i]
		if i >= best.size():
			_assigned[i] = -1
			om.visible = false
			continue
		var si := int(best[i][1])
		_assigned[i] = si
		var s: Dictionary = sources[si]
		om.global_position = s["pos"]
		om.light_color = s["color"]
		om.omni_range = float(s["range"])


## Сколько источников света сейчас горит (тесты).
func lit() -> int:
	var n := 0
	for om in _pool:
		if om.visible:
			n += 1
	return n
