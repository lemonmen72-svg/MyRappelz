class_name ModelLod
extends RefCounted
## Дальние модели персонажей, жителей и зверей — без контура (бережение телефона, см. Quality).
## Контур модели — второй проход того же меша со скелетом («вывернутая оболочка»): вызов отрисовки и все
## треугольники модели ещё раз. Дальше Quality.outline_far() м от камеры своего вьюпорта (превью в окнах — своя
## камера) он почти не виден, а стоит как вторая модель — снимается; ближе — возвращается (запас HYST м).
## Регистрация: ModelLod.register(узел модели, материалы с контуром) — CharacterModel (модель из файла) и
## CreatureAsset. Проверка — tick(dt) раз в TICK с (ThermalGuard._process). Материал дальней модели помечен
## meta "lod_far" — Quality.apply не возвращает ему контур (Quality.outline_for).

const TICK := 0.25
## Запас на границе, м: контур снимается дальше outline_far + HYST, возвращается ближе outline_far − HYST.
const HYST := 2.0

## [WeakRef узла, Array материалов]
static var _entries: Array = []
static var _t := 0.0


## Модель root с материалами mats (у каждого meta "outline" — материал контура, его ставит Quality.track_model).
static func register(root: Node3D, mats: Array) -> void:
	if root == null or mats.is_empty():
		return
	var list: Array[Material] = []
	for m in mats:
		if m is Material:
			list.append(m as Material)
	if list.is_empty():
		return
	_entries.append([weakref(root), list])


## Сколько моделей под наблюдением (тест).
static func count() -> int:
	var n := 0
	for e in _entries:
		if (e[0] as WeakRef).get_ref() != null:
			n += 1
	return n


## Дальняя ли модель сейчас (у материала снят контур по расстоянию).
static func is_far(m: Material) -> bool:
	return m != null and bool(m.get_meta("lod_far", false))


static func tick(dt: float) -> void:
	_t -= dt
	if _t > 0.0:
		return
	_t = TICK
	update_all()


## Проверить все модели сейчас (тест и смена настроек).
static func update_all() -> void:
	var far_d := Quality.outline_far()
	var on := Quality.outlines()
	var alive: Array = []
	var cams := {}
	for e in _entries:
		var node := (e[0] as WeakRef).get_ref() as Node3D
		if node == null:
			continue
		alive.append(e)
		if not node.is_inside_tree():
			continue
		var vp := node.get_viewport()
		var cam: Camera3D = null
		if cams.has(vp):
			cam = cams[vp]
		else:
			if vp != null:
				cam = vp.get_camera_3d()
			cams[vp] = cam
		var d := 0.0
		if cam != null:
			d = cam.global_position.distance_to(node.global_position)
		var mats: Array[Material] = e[1]
		for m in mats:
			if m == null:
				continue
			var was := bool(m.get_meta("lod_far", false))
			var far := was
			if far_d <= 0.0:
				far = false
			elif was:
				far = d > far_d - HYST
			else:
				far = d > far_d + HYST
			if far != was:
				m.set_meta("lod_far", far)
			var want: Material = null
			if on and not far and m.has_meta("outline"):
				want = m.get_meta("outline") as Material
			if m.next_pass != want:
				m.next_pass = want
	_entries = alive
