class_name VfxTrail
extends MeshInstance3D
## След снаряда (VFX 2.0, VfxKit.trail): лента из последних положений узла, повёрнутая к камере; голова у снаряда,
## хвост сужается и тает за life с. Живёт в мире (не дочерний снаряду): снаряд попал и исчез — след догорает и
## удаляется сам. Группа "vfx" — учитывается в пределе эффектов.

const MAX_POINTS := 48
const MAX_SEC := 6.0

var who: WeakRef = null
var width := 0.3
var life := 0.3
var _mat: Material = null
var _im: ImmediateMesh = null
var _pts: Array[Vector3] = []
var _ages: Array[float] = []
var _alive_t := 0.0


## Повесить след на узел who (в его родителя — мир). null — узел не в дереве.
static func attach(w: Node3D, mat: Material, wd: float, lf: float) -> VfxTrail:
	if w == null or not w.is_inside_tree() or w.get_parent() == null:
		return null
	var tr := VfxTrail.new()
	tr.who = weakref(w)
	tr._mat = mat
	tr.width = wd
	tr.life = maxf(lf, 0.05)
	tr.name = "VfxTrail"
	tr.add_to_group("vfx")
	tr.set_meta("no_outline", true)
	tr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tr.top_level = true
	w.get_parent().add_child(tr)
	tr.global_transform = Transform3D.IDENTITY
	return tr


func _ready() -> void:
	_im = ImmediateMesh.new()
	mesh = _im


func _process(delta: float) -> void:
	_alive_t += delta
	var w: Node3D = who.get_ref() if who != null else null
	var alive := w != null and is_instance_valid(w) and w.is_inside_tree() and not w.is_queued_for_deletion()
	for i in _ages.size():
		_ages[i] += delta
	if alive:
		var p := w.global_position
		if _pts.is_empty() or _pts[0].distance_to(p) > 0.05:
			_pts.push_front(p)
			_ages.push_front(0.0)
		else:
			_pts[0] = p
			_ages[0] = 0.0
	while _ages.size() > 0 and (_ages[_ages.size() - 1] > life or _ages.size() > MAX_POINTS):
		_ages.pop_back()
		_pts.pop_back()
	_im.clear_surfaces()
	if (not alive and _pts.size() < 2) or _alive_t > MAX_SEC:
		queue_free()
		return
	if _pts.size() < 2:
		return
	var cam := get_viewport().get_camera_3d()
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _mat)
	var n := _pts.size()
	for i in n:
		var p0: Vector3 = _pts[maxi(i - 1, 0)]
		var p1: Vector3 = _pts[mini(i + 1, n - 1)]
		var tan := p0 - p1
		if tan.length() < 0.0001:
			tan = Vector3.FORWARD
		var view := (cam.global_position - _pts[i]) if cam != null else Vector3.UP
		var side := tan.cross(view)
		if side.length() < 0.0001:
			side = tan.cross(Vector3.UP)
		var u := clampf(_ages[i] / life, 0.0, 1.0)
		side = side.normalized() * width * (1.0 - 0.7 * u)
		_im.surface_set_uv(Vector2(u, 0.0))
		_im.surface_add_vertex(_pts[i] + side)
		_im.surface_set_uv(Vector2(u, 1.0))
		_im.surface_add_vertex(_pts[i] - side)
	_im.surface_end()
