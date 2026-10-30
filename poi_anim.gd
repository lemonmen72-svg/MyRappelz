class_name PoiAnimator
extends Node
## Простые анимации построек острова одним узлом: вращение (крылья мельницы, луч маяка),
## покачивание корабля на волнах, овцы «пасутся», мерцание огня.
## Овцы и огни — экземпляры MultiMesh (все овцы загона — два меша, все огни зоны — один):
## анимация меняет преобразования экземпляров. Остальное — узлы.
## Объекты дальше FAR от камеры не обновляются (экономия на телефоне).

const FAR := 110.0

const SPIN := 0
const BOB := 1
const GRAZE := 2
const FLICKER := 3
const GRAZE_MM := 4
const FLICKER_MM := 5

var _items: Array[Dictionary] = []
var _t := 0.0


## Вращение узла вокруг локальной оси axis со скоростью speed (рад/с).
func spin(node: Node3D, axis: Vector3, speed: float) -> void:
	_items.append({"kind": SPIN, "node": node, "axis": axis.normalized(), "speed": speed,
		"basis": node.transform.basis, "pos": node.position})


## Покачивание на воде: подъём amp (м), крен roll и дифферент pitch (рад).
func bob(node: Node3D, amp: float, roll: float, pitch: float, speed: float = 1.0) -> void:
	_items.append({"kind": BOB, "node": node, "amp": amp, "roll": roll, "pitch": pitch, "speed": speed,
		"basis": node.transform.basis, "pos": node.position, "phase": randf() * TAU})


## Овца-узел: тело слегка покачивается, голова то опускается к траве, то поднимается.
func graze(body: Node3D, head: Node3D) -> void:
	_items.append({"kind": GRAZE, "node": body, "head": head, "phase": randf() * TAU,
		"basis": body.transform.basis, "pos": body.position, "head_basis": head.transform.basis})


## Овца из MultiMesh: экземпляр idx тел (bodies) и голов (heads); xf — тело в покое
## (в координатах bodies), head_xf — голова относительно тела.
func graze_mm(bodies: MultiMeshInstance3D, heads: MultiMeshInstance3D, idx: int, xf: Transform3D,
		head_xf: Transform3D) -> void:
	_items.append({"kind": GRAZE_MM, "node": bodies, "heads": heads, "idx": idx, "xf": xf,
		"head_xf": head_xf, "at": xf.origin, "phase": randf() * TAU})


## Мерцание пламени-узла: масштаб «дышит» неровно.
func flicker(node: Node3D) -> void:
	_items.append({"kind": FLICKER, "node": node, "phase": randf() * TAU})


## Мерцание пламени — экземпляра idx MultiMesh (xf — в покое, со своим масштабом).
func flicker_mm(mmi: MultiMeshInstance3D, idx: int, xf: Transform3D) -> void:
	_items.append({"kind": FLICKER_MM, "node": mmi, "idx": idx, "xf": xf, "at": xf.origin,
		"phase": randf() * TAU})


## Поза пасущейся овцы в момент ph: [поворот тела, подъём тела, наклон головы].
static func _graze_pose(ph: float) -> Array:
	# Цикл ~7 с: голова внизу (щиплет траву) большую часть времени, потом поднимается
	var cyc := fposmod(ph, 7.0) / 7.0
	var down := smoothstep(0.0, 0.08, cyc) * (1.0 - smoothstep(0.6, 0.7, cyc))
	var head := Basis(Vector3.RIGHT, -0.75 * down + sin(ph * 6.0) * 0.06 * down)
	var body := Basis(Vector3.UP, sin(ph * 0.25) * 0.35)
	var lift := Vector3(0, absf(sin(ph * 1.7)) * 0.02, 0)
	return [body, lift, head]


static func _flicker_scale(f: float) -> Vector3:
	var k := 1.0 + sin(f) * 0.08 + sin(f * 2.3 + 1.1) * 0.06
	return Vector3(1.0 + sin(f * 1.7) * 0.05, k, 1.0 + cos(f * 1.3) * 0.05)


func _process(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_3d()
	var far2 := FAR * FAR
	for e in _items:
		var n: Node3D = e["node"]
		if not is_instance_valid(n):
			continue
		if cam != null:
			var at: Vector3 = e.get("at", Vector3.ZERO)
			if (n.global_transform * at).distance_squared_to(cam.global_position) > far2:
				continue
		var b: Basis
		match int(e["kind"]):
			SPIN:
				b = e["basis"]
				var axis: Vector3 = e["axis"]
				n.transform.basis = b * Basis(axis, _t * float(e["speed"]))
			BOB:
				b = e["basis"]
				var p: Vector3 = e["pos"]
				var t := _t * float(e["speed"]) + float(e["phase"])
				n.position = p + Vector3(0, sin(t * 1.3) * float(e["amp"]), 0)
				n.transform.basis = b * Basis.from_euler(Vector3(sin(t * 0.9) * float(e["pitch"]), 0.0,
					sin(t * 1.1 + 0.7) * float(e["roll"])))
			GRAZE:
				b = e["basis"]
				var pose := _graze_pose(_t + float(e["phase"]))
				var bpose: Basis = pose[0]
				var lift: Vector3 = pose[1]
				var hpose: Basis = pose[2]
				var head: Node3D = e["head"]
				if is_instance_valid(head):
					var hb: Basis = e["head_basis"]
					head.transform.basis = hb * hpose
				n.transform.basis = b * bpose
				var p0: Vector3 = e["pos"]
				n.position = p0 + lift
			GRAZE_MM:
				var pose := _graze_pose(_t + float(e["phase"]))
				var bpose: Basis = pose[0]
				var lift: Vector3 = pose[1]
				var hpose: Basis = pose[2]
				var xf: Transform3D = e["xf"]
				var hxf: Transform3D = e["head_xf"]
				var body_xf := Transform3D(xf.basis * bpose, xf.origin + lift)
				var head_xf := body_xf * Transform3D(hxf.basis * hpose, hxf.origin)
				var idx := int(e["idx"])
				var bodies := n as MultiMeshInstance3D
				bodies.multimesh.set_instance_transform(idx, body_xf)
				var heads: MultiMeshInstance3D = e["heads"]
				if is_instance_valid(heads):
					heads.multimesh.set_instance_transform(idx, head_xf)
			FLICKER:
				n.scale = _flicker_scale(_t * 9.0 + float(e["phase"]))
			FLICKER_MM:
				var fxf: Transform3D = e["xf"]
				var s := _flicker_scale(_t * 9.0 + float(e["phase"]))
				var mmi := n as MultiMeshInstance3D
				mmi.multimesh.set_instance_transform(int(e["idx"]),
					Transform3D(fxf.basis * Basis.from_scale(s), fxf.origin))
