class_name IslandPois
extends RefCounted
## Постройки и точки интереса острова по конфигу (pois): город новичков, деревни рас, порт с маяком,
## причалом и кораблём, пещера, лагеря, мельница, пшеничные поля, загон, перила мостов.
## Всё ставится от центров POI из конфига по своей раскладке (углы и радиусы относительно центра);
## каждое место проверяется: не на дороге, не в воде и у обрыва, не на точке старта, не на другой
## постройке. В центре города свободен круг TOWN_FREE (торговец, точка старта, тесты).
##
## Модели — заглушки из примитивов (PoiModels, одна функция = один тип), материалы — toon.gdshader
## и crystal.gdshader. Постройки — StaticBody3D (слой 1) с простыми боксами/цилиндрами; клетки под
## ними помечаются непроходимыми (звери и растительность туда не попадут), настил причала — проходимым.
## Следы построек для других модулей: world.get_meta("poi_footprints") — [{"c": Vector2, "r": float}].
##
## Отрисовка (телефон: важно число вызовов). Всё неподвижное склеивается по зонам (город, деревня с
## мельницей, полями и загоном, порт с маяком и причалом, пещера с лагерями, ...): у зоны два меша —
## «Static» (постройки, ограды, отбрасывают тень, видны всегда) и «Props» (мелочи, кристаллы, ореолы,
## туман; без теней, до NEAR_RANGE) — по одной поверхности на материал. Тела StaticBody3D остаются
## (коллизия, группа poi_buildings), но мешей в них нет. Отдельно — только анимированное: крылья
## мельницы, луч маяка, корабль, овцы и огни (MultiMesh), полотнища флажков; частицы и подписи.

## Свободный круг в центре города, м.
const TOWN_FREE := 9.5
## Дальность видимости мелочей (ящики, бочки, фонари, кристаллы), м.
const PROP_RANGE := 75.0
## Дальность видимости колосьев, м.
const DECOR_RANGE := 120.0
## Дальность видимости меша мелочей зоны (от его центра), м.
const NEAR_RANGE := 110.0
## POI ближе этого к центру зоны склеиваются в её меши, м.
const ZONE_JOIN := 45.0
## Типы POI — центры своих зон.
const BIG_ZONES := ["town", "light_elf_village", "dark_elf_village", "human_village", "port", "cave"]
const LABEL_COLORS := {
	"town": Color(1.0, 0.9, 0.55),
	"light_elf_village": Color(0.8, 0.95, 1.0),
	"dark_elf_village": Color(0.88, 0.7, 1.0),
	"human_village": Color(1.0, 0.82, 0.6),
	"port": Color(0.75, 0.92, 1.0),
	"cave": Color(0.85, 0.85, 0.9),
	"tent": Color(1.0, 0.9, 0.75),
}


## Зона склейки: неподвижная геометрия рядом стоящих POI — в двух Kit (координаты от origin).
class Zone:
	## Центр зоны на карте (для поиска ближайшей).
	var c := Vector2.ZERO
	## Узел, в который ставятся меши зоны, и их положение в нём.
	var node: Node3D
	var origin := Vector3.ZERO
	## Координаты острова → координаты мешей зоны.
	var inv := Transform3D.IDENTITY
	## Постройки (тени, без ограничения дальности) и мелочи (без теней, до NEAR_RANGE).
	var far := PoiModels.Kit.new()
	var near := PoiModels.Kit.new()
	## Огни (MultiMesh, мерцают) в координатах мешей зоны.
	var flames: Array[Transform3D] = []


var w: IslandWorld
var rng := RandomNumberGenerator.new()
var root: Node3D
var anim: PoiAnimator
var road_half := 1.6
## Занятые места (круги): [{"c": Vector2, "r": float}]
var taken: Array[Dictionary] = []
## Занятые прямоугольники (поля, причал): [{"c": Vector2, "half": Vector2, "rot": float}]
var rects: Array[Dictionary] = []
## Следы построек для других модулей.
var footprints: Array = []
## Сдвинутые с дороги центры POI (id → Vector2).
var moved := {}
## Зоны склейки мешей и текущая (куда идут модели строящегося POI).
var zones: Array[Zone] = []
var _zone: Zone
## Общий меш полотнища флажка.
var _flag_cloth: ArrayMesh


static func build(world: IslandWorld, _rng: RandomNumberGenerator) -> void:
	var b := IslandPois.new()
	b._build(world)


func _build(world: IslandWorld) -> void:
	w = world
	# Своё зерно: раскладка декора не сдвигает общий генератор мира (звери, растительность)
	rng.seed = 7311
	road_half = float(w.cfg.get("roads", {}).get("width", 3.2)) * 0.5
	PoiModels.apply_quality()
	root = Node3D.new()
	root.name = "Pois"
	w.add_child(root)
	anim = PoiAnimator.new()
	anim.name = "PoiAnimator"
	root.add_child(anim)
	_register()
	# Узлы POI и зоны крупных POI заранее: мелкие POI рядом склеиваются с ними
	var holders: Array[Node3D] = []
	for p in w.cfg.get("pois", []):
		var poi: Dictionary = p
		var holder := Node3D.new()
		holder.name = String(poi.get("id", "poi"))
		root.add_child(holder)
		holders.append(holder)
		if BIG_ZONES.has(String(poi.get("type", ""))):
			_new_zone(v2(poi["center"]), holder)
	var hi := 0
	for p in w.cfg.get("pois", []):
		var poi: Dictionary = p
		var holder := holders[hi]
		hi += 1
		_zone = _zone_at(v2(poi["center"]), holder)
		var type := String(poi.get("type", ""))
		match type:
			"town":
				_town(holder, poi)
			"light_elf_village":
				_light_elf_village(holder, poi)
			"dark_elf_village":
				_dark_elf_village(holder, poi)
			"human_village":
				_human_village(holder, poi)
			"windmill":
				_windmill(holder, poi)
			"wheat_field":
				_wheat_field(holder, poi)
			"sheep_pen":
				_sheep_pen(holder, poi)
			"port":
				_port(holder, poi)
			"lighthouse":
				_lighthouse(holder, poi)
			"pier":
				_pier(holder, poi)
			"ship":
				_ship(holder, poi)
			"cave":
				_cave(holder, poi)
			"tent":
				_camp(holder, poi)
			_:
				_marker(holder, poi)
		if LABEL_COLORS.has(type):
			_poi_label(holder, poi, type)
	_bridge_rails()
	_finish_zones()
	w.set_meta("poi_footprints", footprints)


# ---------- Места: занятость, проверки, поиск ----------

static func v2(a) -> Vector2:
	return IslandWorld.v2(a)


func _center(poi: Dictionary) -> Vector2:
	var id := String(poi.get("id", ""))
	if moved.has(id):
		return moved[id]
	return v2(poi["center"])


func _take(c: Vector2, r: float) -> void:
	taken.append({"c": c, "r": r})


## Заранее занимаем места мелких POI, точек старта, переходов и центра города —
## постройки деревень их обходят.
func _register() -> void:
	for p in w.pois_of_type("town"):
		var t: Dictionary = p
		_take(v2(t["center"]), TOWN_FREE)
	var sp: Dictionary = w.cfg.get("spawn_points", {})
	for key in sp:
		_take(v2(sp[key]), 2.5)
	for t in w.transitions():
		var tr: Dictionary = t
		_take(v2(tr["center"]), float(tr.get("radius", 3.0)))
	for p in w.cfg.get("pois", []):
		var poi: Dictionary = p
		var c := v2(poi["center"])
		var r := float(poi.get("radius", 3.0))
		match String(poi.get("type", "")):
			"windmill":
				_take(c, 3.3)
			"sheep_pen":
				_take(c, r + 0.8)
			"lighthouse":
				# Маяк не должен стоять на дороге: сдвигаем от неё на свой радиус
				var mc := _away_from_road(c, 2.6)
				moved[String(poi.get("id", ""))] = mc
				_take(mc, 2.8)
			"tent":
				_take(c, 1.3)
			"cave":
				_take(c, r)
			"wheat_field":
				var sz: Array = poi.get("size", [20, 12])
				rects.append({"c": c, "half": Vector2(float(sz[0]), float(sz[1])) * 0.5 + Vector2(0.5, 0.5),
					"rot": deg_to_rad(float(poi.get("rotation", 0.0)))})
			"pier":
				var info := _pier_frame(poi)
				var a: Vector2 = info["a"]
				var d: Vector2 = info["dir"]
				var length: float = info["length"]
				rects.append({"c": a + d * length * 0.5, "half": Vector2(4.0, length * 0.5 + 1.0),
					"rot": atan2(d.x, d.y)})


## Точка p не задевает занятые места (круги и прямоугольники) с запасом r.
func _free(p: Vector2, r: float) -> bool:
	for t in taken:
		var c: Vector2 = t["c"]
		if p.distance_to(c) < r + float(t["r"]):
			return false
	for rc in rects:
		var rot: float = rc["rot"]
		var half: Vector2 = rc["half"]
		var rcc: Vector2 = rc["c"]
		var d := p - rcc
		# Оси прямоугольника, повёрнутого на rot вокруг Y (как Basis(UP, rot))
		var ax := Vector2(cos(rot), -sin(rot))
		var az := Vector2(sin(rot), cos(rot))
		if absf(d.dot(ax)) < half.x + r and absf(d.dot(az)) < half.y + r:
			return false
	return true


## Место под объект радиуса r: свободно, не на дороге (с зазором gap), на ровной суше вдали от воды.
func _clear(p: Vector2, r: float, gap: float = 0.6) -> bool:
	if not _free(p, r):
		return false
	if w.road_distance(p.x, p.y) < r + road_half + gap:
		return false
	if w.coast_distance(p.x, p.y) < r + 2.0:
		return false
	if w.water_distance(p.x, p.y) < r + 1.5:
		return false
	if not w.is_walkable(p.x, p.y):
		return false
	var h0 := w.height_at(p.x, p.y)
	for k in 6:
		var a := TAU * float(k) / 6.0
		var q := p + Vector2(cos(a), sin(a)) * r
		if w.road_distance(q.x, q.y) < road_half + 0.3:
			return false
		if absf(w.height_at(q.x, q.y) - h0) > 1.0:
			return false
	return true


## Ищет место рядом с желаемым (угол ang в градусах от востока, −90 — север; радиус rad от центра c).
## max_r — внешняя граница (ограда), 0 — без неё. Возвращает Vector2.INF, если места нет.
func _spot(c: Vector2, ang_deg: float, rad: float, r: float, max_r: float = 0.0, gap: float = 0.6) -> Vector2:
	var a0 := deg_to_rad(ang_deg)
	for dr in [0.0, -1.0, 1.0, -2.0, 2.0]:
		var rr: float = rad + float(dr)
		if max_r > 0.0 and rr + r > max_r:
			continue
		for da in [0.0, 0.07, -0.07, 0.14, -0.14, 0.21, -0.21, 0.3, -0.3, 0.4, -0.4]:
			var a: float = a0 + float(da)
			var p := c + Vector2(cos(a), sin(a)) * rr
			if _clear(p, r, gap):
				return p
	return Vector2.INF


## Сдвигает точку от дороги, пока до оси дороги не станет need + половина ширины дороги.
func _away_from_road(p: Vector2, need: float) -> Vector2:
	var q := p
	for i in 24:
		var d := w.road_distance(q.x, q.y)
		if d >= need + road_half + 0.4:
			break
		var gx := w.road_distance(q.x + 1.5, q.y) - w.road_distance(q.x - 1.5, q.y)
		var gz := w.road_distance(q.x, q.y + 1.5) - w.road_distance(q.x, q.y - 1.5)
		var g := Vector2(gx, gz)
		if g.length() < 0.01:
			g = Vector2(1, 0)
		q += g.normalized() * 0.5
	return q


## Поворот вокруг Y, при котором +Z модели смотрит из p на target.
static func _yaw_to(p: Vector2, target: Vector2) -> float:
	var d := target - p
	if d.length() < 0.01:
		return 0.0
	return atan2(d.x, d.y)


## Высота опоры постройки: самая низкая точка под ней (цоколь уходит в землю, а не висит).
func _floor_y(p: Vector2, r: float) -> float:
	var y := w.height_at(p.x, p.y)
	for k in 4:
		var a := TAU * float(k) / 4.0 + PI * 0.25
		y = minf(y, w.height_at(p.x + cos(a) * r, p.y + sin(a) * r))
	return y - 0.05


## Клетки сетки под прямоугольником (центр c, полуразмеры half, поворот yaw) — непроходимы (или проходимы).
func _mark_walk(c: Vector2, half: Vector2, yaw: float, value: int) -> void:
	var ax := Vector2(cos(yaw), -sin(yaw))
	var az := Vector2(sin(yaw), cos(yaw))
	var ext := half.length()
	# Копия сетки один раз (PackedByteArray копируется при записи), потом обратно в мир
	var wk := w.walk
	var i0 := clampi(int((c.x - ext - w.origin.x) / w.step), 0, w.nx - 1)
	var i1 := clampi(int((c.x + ext - w.origin.x) / w.step) + 1, 0, w.nx - 1)
	var j0 := clampi(int((c.y - ext - w.origin.y) / w.step), 0, w.nz - 1)
	var j1 := clampi(int((c.y + ext - w.origin.y) / w.step) + 1, 0, w.nz - 1)
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var p := Vector2(w.origin.x + float(i) * w.step, w.origin.y + float(j) * w.step)
			var d := p - c
			if absf(d.dot(ax)) <= half.x and absf(d.dot(az)) <= half.y:
				wk[j * w.nx + i] = value
	w.walk = wk


## Учёт постройки: место занято, след для других модулей, клетки под ней непроходимы.
func _occupy(p: Vector2, r: float, block_half: Vector2 = Vector2.ZERO, yaw: float = 0.0) -> void:
	_take(p, r)
	footprints.append({"c": p, "r": r})
	if block_half.x > 0.0:
		_mark_walk(p, block_half, yaw, 0)


# ---------- Узлы: тела, меши, подписи ----------

func _body(parent: Node3D, pos: Vector3, yaw: float) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	b.collision_mask = 0
	b.position = pos
	b.rotation.y = yaw
	b.add_to_group("poi_buildings")
	parent.add_child(b)
	return b


func _box_shape(body: Node3D, size: Vector3, pos: Vector3, yaw: float = 0.0) -> void:
	var col := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	col.shape = s
	col.position = pos
	col.rotation.y = yaw
	body.add_child(col)


func _cyl_shape(body: Node3D, r: float, h: float, pos: Vector3) -> void:
	var col := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = r
	s.height = h
	col.shape = s
	col.position = pos + Vector3(0, h * 0.5, 0)
	body.add_child(col)


## Отдельный меш-узел (только для анимированного: крылья мельницы, корабль).
func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, yaw: float = 0.0, range_end: float = 0.0,
		shadow: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation.y = yaw
	if range_end > 0.0:
		mi.visibility_range_end = range_end
		mi.visibility_range_end_margin = 5.0
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Постройка: тело с коллизией-боксом size (по центру основания), модель kind — в меш зоны.
## Фасад (+Z) смотрит на face. cyl_r > 0 — коллизия цилиндром этого радиуса.
func _building(parent: Node3D, kind: String, p: Vector2, face: Vector2, size: Vector3, r_place: float,
		cyl_r: float = 0.0) -> StaticBody3D:
	var yaw := _yaw_to(p, face)
	var body := _body(parent, Vector3(p.x, _floor_y(p, maxf(size.x, size.z) * 0.45), p.y), yaw)
	body.name = kind
	_put(body, kind)
	if cyl_r > 0.0:
		_cyl_shape(body, cyl_r, size.y, Vector3.ZERO)
		_occupy(p, r_place, Vector2(cyl_r, cyl_r) * 0.75, 0.0)
	else:
		_box_shape(body, size, Vector3(0, size.y * 0.5, 0))
		_occupy(p, r_place, Vector2(size.x, size.z) * 0.5 - Vector2(0.3, 0.3), yaw)
	return body


## Мелкий предмет (в меш мелочей зоны) без коллизии или с маленьким цилиндром col_r > 0.
## Возвращает тело (если есть коллизия) — к нему можно привязать ореол.
func _prop(parent: Node3D, kind: String, p: Vector2, yaw: float, col_r: float = 0.0,
		col_h: float = 1.0) -> StaticBody3D:
	var pos := Vector3(p.x, w.height_at(p.x, p.y) - 0.03, p.y)
	if col_r > 0.0:
		var body := _body(parent, pos, yaw)
		body.name = kind
		_put(body, kind, Transform3D.IDENTITY, true)
		_cyl_shape(body, col_r, col_h, Vector3.ZERO)
		_occupy(p, col_r + 0.3)
		return body
	_put(parent, kind, _xf(pos, yaw), true)
	_take(p, 0.5)
	return null


## Ореол-свечение (аддитивное пятно лицом к камере) — дешёвая замена bloom у кристаллов и огней.
## Все ореолы зоны — одна поверхность меша мелочей (разворот к камере в шейдере).
func _halo(parent: Node3D, pos: Vector3, c: Color, size: float) -> void:
	var p := _zone.inv * (_world_xf(parent) * pos)
	_zone.near.halo(p, c, snappedf(size, 0.1))


## Огонь (мерцает): экземпляр MultiMesh огней зоны; parent и local — как у _put.
func _flame(parent: Node3D, local: Transform3D) -> void:
	_zone.flames.append(_zone.inv * _world_xf(parent) * local)


# ---------- Зоны: склейка мешей ----------

static func _xf(pos: Vector3, yaw: float = 0.0, s: Vector3 = Vector3.ONE) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(s), pos)


## Фаза пульсации кристаллов объекта в точке p (у каждого своя).
static func _phase(p: Vector3) -> float:
	return fposmod(sin(p.x * 12.9898 + p.z * 78.233) * 43758.5453, 1.0) * TAU


## Преобразование узла n в координатах острова (w) — по цепочке родителей, без дерева сцены.
func _world_xf(n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != w:
		var n3 := cur as Node3D
		if n3 != null:
			xf = n3.transform * xf
		cur = cur.get_parent()
	return xf


func _new_zone(c: Vector2, node: Node3D) -> Zone:
	var z := Zone.new()
	z.c = c
	z.node = node
	var nw := _world_xf(node)
	z.origin = nw.affine_inverse() * w.ground(c.x, c.y, 0.0)
	z.inv = (nw * Transform3D(Basis.IDENTITY, z.origin)).affine_inverse()
	zones.append(z)
	return z


## Зона для POI в точке p: ближайшая не дальше ZONE_JOIN, иначе новая (меши — в node).
func _zone_at(p: Vector2, node: Node3D) -> Zone:
	var best: Zone = null
	var best_d := ZONE_JOIN
	for z in zones:
		var d := z.c.distance_to(p)
		if d < best_d:
			best_d = d
			best = z
	if best == null:
		best = _new_zone(p, node)
	return best


## Модель kind в меш текущей зоны: parent — узел-опора (тело постройки, ограда...), local —
## положение относительно него; near — в меш мелочей (без теней, до NEAR_RANGE), иначе построек.
func _put(parent: Node3D, kind: String, local: Transform3D = Transform3D.IDENTITY, near: bool = false) -> void:
	_put_kit(parent, PoiModels.get_kit(kind), local, near)


func _put_kit(parent: Node3D, kit: PoiModels.Kit, local: Transform3D = Transform3D.IDENTITY,
		near: bool = false) -> void:
	var wx := _world_xf(parent) * local
	var layer: PoiModels.Kit = _zone.near if near else _zone.far
	layer.append_kit(kit, _zone.inv * wx, _phase(wx.origin))


## Собирает меши зон: «Static» (постройки) и «Props» (мелочи), огни — MultiMesh «Flames».
func _finish_zones() -> void:
	for z in zones:
		_zone_mesh(z, z.far, "Static", false)
		_zone_mesh(z, z.near, "Props", true)
		if z.flames.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = PoiModels.get_mesh("flame")
		mm.instance_count = z.flames.size()
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Flames"
		mmi.multimesh = mm
		mmi.position = z.origin
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = NEAR_RANGE
		mmi.visibility_range_end_margin = 8.0
		z.node.add_child(mmi)
		for i in z.flames.size():
			mm.set_instance_transform(i, z.flames[i])
			anim.flicker_mm(mmi, i, z.flames[i])


func _zone_mesh(z: Zone, kit: PoiModels.Kit, mesh_name: String, near: bool) -> void:
	if kit.is_empty():
		return
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	mi.mesh = kit.to_mesh()
	mi.position = z.origin
	mi.set_meta("no_outline", true)
	if near:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = NEAR_RANGE
		mi.visibility_range_end_margin = 8.0
		# Ореолы разворачиваются в шейдере, AABB меша — по их центрам: запас на их размер
		mi.extra_cull_margin = 4.0
	z.node.add_child(mi)


func _label(parent: Node3D, text: String, pos: Vector3, c: Color, font: int, px: float) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = font
	l.outline_size = maxi(8, int(float(font) / 6.0))
	l.pixel_size = px
	l.modulate = c
	l.outline_modulate = Color.from_hsv(c.h, minf(1.0, c.s * 0.8 + 0.4), 0.22)
	l.position = pos
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(l)
	return l


## Название над деревней/городом: крупно, видно издалека.
func _poi_label(parent: Node3D, poi: Dictionary, type: String) -> void:
	var c := _center(poi)
	var big := type == "town" or type.ends_with("village")
	var y := w.height_at(c.x, c.y) + (17.0 if type == "town" else (14.0 if big else 7.0))
	var l := _label(parent, String(poi.get("name", "")), Vector3(c.x, y, c.y), LABEL_COLORS[type],
		96 if big else 64, 0.032 if big else 0.024)
	l.name = "Label"


## Запасной вариант для неизвестного типа: ящик с подписью.
func _marker(parent: Node3D, poi: Dictionary) -> void:
	var c := _center(poi)
	_prop(parent, "crate", c, 0.0, 0.5, 0.8)
	_label(parent, String(poi.get("name", "")), w.ground(c.x, c.y, 3.0), Color.WHITE, 48, 0.02)


# ---------- Ограды ----------

## Деревянная ограда по кругу (центр c, радиус r): столбики через ~step м и две жерди — брёвна
## с корой (столбики — WorldTextures.BARK, волокна вертикальны; жерди — LOG, волокна вдоль жерди).
## gaps — углы проёмов (рад), gap_half — полуширина проёма (рад). Жерди над дорогой не ставятся.
## Коллизия — бокс на каждый пролёт (одно тело на всю ограду), модель — в меш построек зоны.
func _fence_ring(parent: Node3D, c: Vector2, r: float, gaps: Array, gap_half: float, post_h: float,
		step: float, color: Color) -> void:
	var base_y := w.height_at(c.x, c.y)
	var node := Node3D.new()
	node.name = "Fence"
	node.position = Vector3(c.x, base_y, c.y)
	parent.add_child(node)
	var body := _body(node, Vector3.ZERO, 0.0)
	body.name = "FenceBody"
	var k := PoiModels.Kit.new()
	var n := maxi(8, int(ceilf(TAU * r / step)))
	var pts: Array[Vector3] = []
	var ok: Array[bool] = []
	for i in n:
		var a := TAU * float(i) / float(n)
		var p := Vector2(cos(a), sin(a)) * r
		var y := w.height_at(c.x + p.x, c.y + p.y) - base_y
		pts.append(Vector3(p.x, y, p.y))
		var in_gap := false
		for g in gaps:
			if absf(wrapf(a - float(g), -PI, PI)) < gap_half:
				in_gap = true
		ok.append(not in_gap and w.road_distance(c.x + p.x, c.y + p.y) > road_half + 0.3)
	var dark := color.darkened(0.25)
	for i in n:
		var j := (i + 1) % n
		var p0 := pts[i]
		var p1 := pts[j]
		if ok[i]:
			PoiModels.fence_post(k, p0, post_h, dark)
		if not (ok[i] and ok[j]):
			continue
		var yaw := PoiModels.fence_rails(k, p0, p1, post_h, color)
		var mid := (p0 + p1) * 0.5
		var length := Vector2(p1.x - p0.x, p1.z - p0.z).length()
		_box_shape(body, Vector3(length, post_h, 0.25), mid + Vector3(0, post_h * 0.5, 0), yaw)
	_put_kit(node, k)


## Углы (рад), под которыми дороги пересекают окружность радиуса r вокруг c
## (или подходят к ней концом снаружи не дальше 8 м).
func _gate_angles(c: Vector2, r: float) -> Array[float]:
	var res: Array[float] = []
	var paths: Dictionary = w.cfg.get("roads", {}).get("paths", {})
	for key in paths:
		var path: Array = paths[key]
		var found := false
		for s in range(path.size() - 1):
			var a := v2(path[s]) - c
			var b := v2(path[s + 1]) - c
			var da := a.length()
			var db := b.length()
			if (da - r) * (db - r) <= 0.0 and absf(da - db) > 0.001:
				# Пересечение окружности: делим отрезок пополам до точности
				var lo := 0.0
				var hi := 1.0
				for it in 24:
					var mid := (lo + hi) * 0.5
					var dm := a.lerp(b, mid).length()
					if (dm - r) * (da - r) > 0.0:
						lo = mid
					else:
						hi = mid
				res.append(a.lerp(b, lo).angle())
				found = true
		if not found:
			for e in [path[0], path[path.size() - 1]]:
				var q := v2(e) - c
				if q.length() >= r and q.length() < r + 8.0:
					res.append(q.angle())
	# Близкие углы — одни ворота
	var merged: Array[float] = []
	for a in res:
		var dup := false
		for m in merged:
			if absf(wrapf(a - m, -PI, PI)) < 0.2:
				dup = true
		if not dup:
			merged.append(a)
	return merged


## Арка ворот: два столба, перекладина с вывеской, маленькая крыша, фонари на столбах.
func _gate_arch(parent: Node3D, c: Vector2, r: float, ang: float, half_w: float) -> void:
	var p := c + Vector2(cos(ang), sin(ang)) * r
	# +Z арки смотрит в город, столбы стоят по касательной к ограде
	var yaw := _yaw_to(p, c)
	var body := _body(parent, Vector3(p.x, w.height_at(p.x, p.y) - 0.05, p.y), yaw)
	body.name = "Gate"
	var k := PoiModels.Kit.new()
	var wood := PoiModels.WOOD
	var dark := PoiModels.WOOD_DARK
	for s in [-1.0, 1.0]:
		var x: float = float(s) * half_w
		k.box(Vector3(x, 0.2, 0), Vector3(0.7, 0.4, 0.7), PoiModels.STONE)
		k.box(Vector3(x, 2.0, 0), Vector3(0.36, 4.0, 0.36), dark)
		k.box(Vector3(x, 3.0, 0.3), Vector3(0.24, 0.32, 0.24), PoiModels.WIN_WARM, Vector3.ZERO, "glow")
		k.box(Vector3(x, 3.2, 0.3), Vector3(0.34, 0.08, 0.34), dark)
		_box_shape(body, Vector3(0.5, 4.0, 0.5), Vector3(x, 2.0, 0))
	k.box(Vector3(0, 3.85, 0), Vector3(half_w * 2.0 + 1.0, 0.3, 0.32), wood)
	k.box(Vector3(0, 3.45, 0), Vector3(half_w * 2.0, 0.14, 0.2), dark)
	k.box(Vector3(0, 3.35, 0.0), Vector3(1.8, 0.55, 0.1), PoiModels.WOOD_LIGHT)
	k.box(Vector3(0, 3.35, 0.0), Vector3(1.4, 0.12, 0.13), PoiModels.ROOF_ORANGE)
	PoiModels.gable_roof(k, 4.0, 0.9, half_w * 2.0 + 0.8, 0.45, 0.2, 0.12, PoiModels.ROOF_ORANGE, wood)
	_put_kit(body, k)


# ---------- Город новичков ----------

func _town(h: Node3D, poi: Dictionary) -> void:
	var c := _center(poi)
	var fence_r := float(poi.get("radius", 22.0)) - 0.8
	var gates := _gate_angles(c, fence_r)
	var gate_half := (road_half + 1.3) / fence_r
	# Проходы от ворот к центру свободны
	for g in gates:
		var rr := TOWN_FREE
		while rr < fence_r + 2.0:
			_take(c + Vector2(cos(g), sin(g)) * rr, road_half + 0.6)
			rr += 2.5
	_fence_ring(h, c, fence_r, gates, gate_half, 1.3, 2.4, PoiModels.WOOD)
	for g in gates:
		_gate_arch(h, c, fence_r, g, gate_half * fence_r - 0.2)
	var inner := fence_r - 0.4
	# Ратуша на севере, дома по краю (угол — от востока, −90° — север)
	var plan := [
		["town_hall", -92.5, 15.5, Vector3(9.0, 7.0, 6.4), 4.0],
		["town_house", -122.0, 16.3, Vector3(5.6, 5.4, 4.8), 2.9],
		["town_house_b", -63.0, 16.3, Vector3(6.4, 5.4, 4.8), 2.9],
		["town_house", -14.0, 16.3, Vector3(5.6, 5.4, 4.8), 2.9],
		["town_house_b", 197.0, 16.3, Vector3(6.4, 5.4, 4.8), 2.9],
	]
	for e in plan:
		var p := _spot(c, float(e[1]), float(e[2]), float(e[4]), inner)
		if p.is_finite():
			_building(h, String(e[0]), p, c, e[3], float(e[4]))
	# Тренировочная площадка: маленькая арена и ряд манекенов (вне свободного круга)
	var ap := _spot(c, 50.0, 15.0, 3.9, inner)
	if ap.is_finite():
		_arena(h, ap, c)
	var dp := _spot(c, 82.0, 14.5, 2.6, inner)
	if dp.is_finite():
		_dummies(h, dp, c)
	# Колодец и две доски объявлений
	var wp := _spot(c, 140.0, 13.0, 1.3, inner)
	if wp.is_finite():
		var wb := _body(h, Vector3(wp.x, _floor_y(wp, 1.0), wp.y), _yaw_to(wp, c))
		wb.name = "Well"
		_put(wb, "well")
		_cyl_shape(wb, 1.05, 2.6, Vector3.ZERO)
		_occupy(wp, 1.4, Vector2(0.9, 0.9))
	for a in [125.0, 158.0]:
		var bp := _spot(c, a, 17.5, 1.4, inner)
		if bp.is_finite():
			var bb := _body(h, Vector3(bp.x, _floor_y(bp, 1.0), bp.y), _yaw_to(bp, c))
			bb.name = "NoticeBoard"
			_put(bb, "notice_board")
			_box_shape(bb, Vector3(2.2, 2.6, 0.4), Vector3(0, 1.3, 0))
			_occupy(bp, 1.4)
	# Фонари по кругу вокруг площади
	for i in 8:
		var lp := _spot(c, 22.5 + 45.0 * float(i), 10.6, 0.45, inner, 0.4)
		if lp.is_finite():
			_lantern(h, "lantern_town", lp, PoiModels.WIN_WARM)
	# Немного бочек и ящиков у домов
	_scatter(h, c, ["barrel", "crate", "barrel", "crate"], 12.0, inner - 1.0, 0.6)


func _lantern(parent: Node3D, kind: String, p: Vector2, glow: Color) -> void:
	var body := _prop(parent, kind, p, rng.randf() * TAU, 0.25, 3.2)
	_halo(body, Vector3(0, 2.95, 0), Color(glow, 0.55), 1.3)


## Мелочи (ящики, бочки, сено) в случайных свободных местах кольца r0..r1 вокруг c.
func _scatter(parent: Node3D, c: Vector2, kinds: Array, r0: float, r1: float, r: float) -> void:
	for kd in kinds:
		for attempt in 12:
			var a := rng.randf() * TAU
			var rr := rng.randf_range(r0, r1)
			var p := c + Vector2(cos(a), sin(a)) * rr
			if _clear(p, r, 0.4):
				_prop(parent, String(kd), p, rng.randf() * TAU)
				break


## Арена: круг утоптанного песка, низкая ограда с входом к центру города, стойка с оружием, флажки.
func _arena(parent: Node3D, p: Vector2, town_c: Vector2) -> void:
	var node := Node3D.new()
	node.name = "Arena"
	parent.add_child(node)
	var r := 3.6
	var to_town := (town_c - p).angle()
	var fk := PoiModels.Kit.new()
	fk.cyl(Vector3(p.x, w.height_at(p.x, p.y) + 0.02, p.y), r + 0.3, r + 0.2, 0.12, Color(0.9, 0.78, 0.55), 20)
	_put_kit(node, fk)
	_fence_ring(node, p, r, [to_town], 0.42, 0.9, 1.3, PoiModels.WOOD_LIGHT)
	var back := p - Vector2(cos(to_town), sin(to_town)) * (r - 0.9)
	_prop(node, "weapon_rack", back, _yaw_to(back, p), 0.5, 1.3)
	var dummy := p + Vector2(cos(to_town + PI * 0.5), sin(to_town + PI * 0.5)) * 1.2
	_prop(node, "dummy", dummy, _yaw_to(dummy, town_c), 0.35, 2.2)
	_occupy(p, r + 0.4)
	# Флажки у входа
	for s in [-1.0, 1.0]:
		var a: float = to_town + float(s) * 0.62
		var fp := p + Vector2(cos(a), sin(a)) * (r + 0.6)
		_flag(node, w.ground(fp.x, fp.y, -0.05),
			Color(0.95, 0.42, 0.38) if s < 0.0 else Color(0.16, 0.66, 0.74), Color(1.0, 0.92, 0.6), float(s) * 1.3)


## Флажок на шесте (как WorldBuilder._add_flag): основание, шест и шарик — в меш построек зоны,
## полотнище — своим мешем (flag.gdshader, волнуется), коллизия — тонкий цилиндр.
func _flag(parent: Node3D, pos: Vector3, main: Color, stripe: Color, phase: float) -> void:
	var body := WorldBuilder._small_body(parent, pos, 0.12, 4.4)
	body.name = "Flag"
	var k := PoiModels.Kit.new()
	k.box(Vector3(0, 0.125, 0), Vector3(0.5, 0.25, 0.5), PoiModels.STONE)
	k.cyl(Vector3(0, 2.3, 0), 0.06, 0.045, 4.4, Color(0.82, 0.74, 0.6), 8)
	k.ball(Vector3(0, 4.56, 0), Vector3(0.1, 0.1, 0.1), PoiModels.GOLD, 10, 6)
	_put_kit(body, k)
	if _flag_cloth == null:
		var acc := WorldBuilder.MeshAcc.new()
		var segs := 10
		for sg in segs + 1:
			var u := float(sg) / float(segs)
			var x := u * 1.7
			var hh := lerpf(0.42, 0.06, u)
			var cy := -0.42 - u * 0.12
			acc.add(Vector3(x, cy + hh, 0), Vector3.BACK, Color.WHITE, Vector2(u, 0))
			acc.add(Vector3(x, cy - hh, 0), Vector3.BACK, Color.WHITE, Vector2(u, 1))
		for sg in segs:
			var t0 := sg * 2
			acc.tri(t0, t0 + 2, t0 + 1)
			acc.tri(t0 + 2, t0 + 3, t0 + 1)
		_flag_cloth = acc.to_mesh()
	var fm := WorldBuilder._shader_mat("res://flag.gdshader")
	fm.set_shader_parameter("main_color", main)
	fm.set_shader_parameter("stripe_color", stripe)
	fm.set_shader_parameter("phase", phase)
	var cloth := MeshInstance3D.new()
	cloth.name = "FlagCloth"
	cloth.mesh = _flag_cloth
	cloth.material_override = fm
	cloth.set_meta("no_outline", true)
	cloth.position = Vector3(0.05, 4.35, 0)
	# Локальная +X смотрит по ветру
	cloth.rotation.y = -atan2(WorldBuilder.WIND_DIR.y, WorldBuilder.WIND_DIR.x)
	cloth.visibility_range_end = NEAR_RANGE
	body.add_child(cloth)


## Ряд из трёх тренировочных манекенов лицом к центру города.
func _dummies(parent: Node3D, p: Vector2, town_c: Vector2) -> void:
	var to_town := (town_c - p).normalized()
	var side := Vector2(-to_town.y, to_town.x)
	for i in 3:
		var q := p + side * (float(i) - 1.0) * 1.9
		_prop(parent, "dummy", q, _yaw_to(q, town_c), 0.35, 2.2)
	_occupy(p, 2.6)


# ---------- Деревни рас ----------

## Ставит постройки по плану [вид, угол°, радиус, размер коллизии, радиус места, (радиус цилиндра)].
func _plan(h: Node3D, c: Vector2, plan: Array, face: Vector2, max_r: float) -> void:
	for e in plan:
		var item: Array = e
		var p := _spot(c, float(item[1]), float(item[2]), float(item[4]), max_r)
		if not p.is_finite():
			continue
		var cyl_r := float(item[5]) if item.size() > 5 else 0.0
		_building(h, String(item[0]), p, face, item[3], float(item[4]), cyl_r)


## Центральный объект деревни: в центре или рядом, если центр занят дорогой.
func _central(h: Node3D, c: Vector2, kind: String, r: float, col_h: float) -> Vector2:
	for rad in [0.0, 2.5, 4.0, 5.5]:
		for k in 8:
			var a := TAU * float(k) / 8.0
			var p := c + Vector2(cos(a), sin(a)) * float(rad)
			if _clear(p, r, 0.5):
				var body := _body(h, Vector3(p.x, _floor_y(p, r * 0.8), p.y), rng.randf() * TAU)
				body.name = kind
				_put(body, kind)
				_cyl_shape(body, r * 0.85, col_h, Vector3.ZERO)
				_occupy(p, r, Vector2(r, r) * 0.6)
				return p
			if float(rad) == 0.0:
				break
	return Vector2.INF


## Кристаллы вокруг центра: count друз в кольце r0..r1, у каждой ореол.
func _crystals(h: Node3D, c: Vector2, kinds: Array, count: int, r0: float, r1: float, halo: Color) -> void:
	var placed := 0
	for attempt in count * 10:
		if placed >= count:
			break
		var a := rng.randf() * TAU
		var p := c + Vector2(cos(a), sin(a)) * rng.randf_range(r0, r1)
		if not _clear(p, 1.0, 0.4):
			continue
		var kind: String = kinds[placed % kinds.size()]
		var s := rng.randf_range(0.8, 1.35)
		_put(h, kind, _xf(Vector3(p.x, w.height_at(p.x, p.y) - 0.1, p.y), rng.randf() * TAU, Vector3(s, s, s)), true)
		_halo(h, Vector3(p.x, w.height_at(p.x, p.y) + 1.0 * s, p.y), halo, 2.8 * s)
		_occupy(p, 1.0 * s)
		placed += 1


func _light_elf_village(h: Node3D, poi: Dictionary) -> void:
	var c := _center(poi)
	var r := float(poi.get("radius", 16.0))
	var mc := _central(h, c, "crystals_blue_big", 2.1, 4.5)
	if mc.is_finite():
		_halo(h, w.ground(mc.x, mc.y, 3.0), Color(0.55, 0.85, 1.0, 0.6), 6.0)
		var sp := Vfx.ambient_sparkles(h, Color(0.7, 0.92, 1.0), 2.5, 10)
		sp.position = w.ground(mc.x, mc.y, 2.5)
		sp.visibility_range_end = PROP_RANGE
	var plan := [
		["light_elf_tower", -95.0, 11.0, Vector3(6.0, 8.5, 6.0), 3.3, 3.0],
		["light_elf_house", -150.0, 10.5, Vector3(5.8, 5.5, 4.8), 3.1],
		["light_elf_house", -35.0, 10.5, Vector3(5.8, 5.5, 4.8), 3.1],
		["light_elf_house", 160.0, 10.5, Vector3(5.8, 5.5, 4.8), 3.1],
		["light_elf_house", 110.0, 11.0, Vector3(5.8, 5.5, 4.8), 3.1],
	]
	_plan(h, c, plan, c, r + 4.0)
	_crystals(h, c, ["crystals_blue", "crystals_blue", "crystals_gold"], 8, 5.0, r + 3.0, Color(0.5, 0.82, 1.0, 0.45))
	for i in 6:
		var lp := _spot(c, 30.0 + 60.0 * float(i), 6.5, 0.45, 0.0, 0.4)
		if lp.is_finite():
			_lantern(h, "lantern_elf", lp, PoiModels.WIN_BLUE)


func _dark_elf_village(h: Node3D, poi: Dictionary) -> void:
	var c := _center(poi)
	var r := float(poi.get("radius", 16.0))
	var plan := [
		["dark_elf_tower", -90.0, 9.5, Vector3(7.0, 16.0, 7.0), 3.7, 3.4],
		["dark_elf_house", -160.0, 10.5, Vector3(6.0, 6.5, 4.8), 3.1],
		["dark_elf_house", -20.0, 10.5, Vector3(6.0, 6.5, 4.8), 3.1],
		["dark_elf_house", 165.0, 10.5, Vector3(6.0, 6.5, 4.8), 3.1],
		["dark_elf_house", 20.0, 11.5, Vector3(6.0, 6.5, 4.8), 3.1],
	]
	_plan(h, c, plan, c, r + 4.0)
	var mc := _central(h, c, "crystals_purple_big", 2.1, 4.5)
	if mc.is_finite():
		_halo(h, w.ground(mc.x, mc.y, 3.0), Color(0.75, 0.4, 1.0, 0.6), 6.0)
	# Острые шпили-обелиски
	for a in [-130.0, -50.0, 60.0, 125.0]:
		var sp := _spot(c, a, 13.5, 1.1, 0.0, 0.5)
		if sp.is_finite():
			var body := _body(h, Vector3(sp.x, _floor_y(sp, 0.8), sp.y), rng.randf() * TAU)
			body.name = "Spire"
			_put(body, "dark_spire")
			_cyl_shape(body, 0.9, 6.0, Vector3.ZERO)
			_occupy(sp, 1.1, Vector2(0.6, 0.6))
	_crystals(h, c, ["crystals_purple"], 10, 5.0, r + 5.0, Color(0.72, 0.38, 1.0, 0.45))
	for i in 4:
		var bp := _spot(c, 45.0 + 90.0 * float(i), 6.0, 0.5, 0.0, 0.4)
		if bp.is_finite():
			var b := _prop(h, "brazier_dark", bp, 0.0, 0.4, 2.2)
			_halo(b, Vector3(0, 2.3, 0), Color(0.75, 0.4, 1.0, 0.5), 1.4)
	_dark_fog(h, c, r)


## Лёгкий туман: несколько больших мягких полупрозрачных спрайтов, медленно плывущих по ветру,
## и пара плоских слоёв дымки над землёй. Дёшево: ~14 частиц на всю деревню.
func _dark_fog(h: Node3D, c: Vector2, r: float) -> void:
	var y := w.height_at(c.x, c.y)
	var fog := CPUParticles3D.new()
	fog.name = "Fog"
	fog.amount = 14
	fog.lifetime = 14.0
	fog.preprocess = 14.0
	fog.randomness = 0.6
	fog.mesh = Vfx._quad()
	fog.material_override = Vfx._particle_mat("puff", false)
	fog.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fog.emission_box_extents = Vector3(r, 0.5, r)
	fog.direction = Vector3(0.86, 0.0, 0.5)
	fog.spread = 35.0
	fog.initial_velocity_min = 0.25
	fog.initial_velocity_max = 0.6
	fog.gravity = Vector3.ZERO
	fog.angle_min = 0.0
	fog.angle_max = 360.0
	fog.scale_amount_min = 5.0
	fog.scale_amount_max = 9.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	var fc := Color(0.6, 0.52, 0.72)
	g.colors = PackedColorArray([Color(fc, 0.0), Color(fc, 0.2), Color(fc, 0.2), Color(fc, 0.0)])
	fog.color_ramp = g
	fog.position = Vector3(c.x, y + 1.3, c.y)
	fog.visibility_range_end = 160.0
	fog.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	h.add_child(fog)
	fog.emitting = true
	# Слои дымки — поверхность «fog_dark» меша мелочей зоны
	var k := PoiModels.Kit.new()
	for i in 3:
		var a := TAU * float(i) / 3.0 + 0.4
		var p := c + Vector2(cos(a), sin(a)) * r * 0.45
		k.plane_uv(Vector3(p.x, w.height_at(p.x, p.y) + 0.35 + float(i) * 0.12, p.y), Vector2(r * 1.3, r * 1.3),
			Color.WHITE, "fog_dark")
	_put_kit(h, k, Transform3D.IDENTITY, true)


func _human_village(h: Node3D, poi: Dictionary) -> void:
	var c := _center(poi)
	var r := float(poi.get("radius", 16.0))
	var plan := [
		["human_house_thatch", -118.0, 12.0, Vector3(6.0, 5.4, 4.8), 3.1],
		["human_house_red", -40.0, 10.5, Vector3(6.0, 5.4, 4.8), 3.1],
		["human_house_thatch", 150.0, 10.5, Vector3(6.0, 5.4, 4.8), 3.1],
		["human_house_red", 110.0, 11.0, Vector3(6.0, 5.4, 4.8), 3.1],
		["human_house_red", 20.0, 11.0, Vector3(6.0, 5.4, 4.8), 3.1],
	]
	_plan(h, c, plan, c, r + 4.0)
	_central(h, c, "well", 1.3, 2.6)
	for i in 4:
		var lp := _spot(c, 45.0 + 90.0 * float(i), 6.0, 0.45, 0.0, 0.4)
		if lp.is_finite():
			_lantern(h, "lantern_town", lp, PoiModels.WIN_WARM)
	_scatter(h, c, ["hay", "hay", "barrel", "crate", "barrel"], 4.0, r, 0.8)


# ---------- Мельница, поля, загон ----------

## Ближайший центр деревни или города (куда «смотрят» постройки).
func _nearest_village(p: Vector2) -> Vector2:
	var best := Vector2.ZERO
	var best_d := INF
	for q in w.cfg.get("pois", []):
		var poi: Dictionary = q
		var t := String(poi.get("type", ""))
		if t == "town" or t.ends_with("village"):
			var c := v2(poi["center"])
			if p.distance_to(c) < best_d and p.distance_to(c) > 0.5:
				best_d = p.distance_to(c)
				best = c
	return best


func _windmill(h: Node3D, poi: Dictionary) -> void:
	var c := _center(poi)
	var face := _nearest_village(c)
	var body := _body(h, Vector3(c.x, _floor_y(c, 2.4), c.y), _yaw_to(c, face))
	body.name = "Windmill"
	_put(body, "windmill")
	_cyl_shape(body, 2.4, 9.0, Vector3.ZERO)
	var sails := _mesh(body, PoiModels.get_mesh("windmill_sails"), Vector3(0, 7.4, 2.35))
	sails.name = "Sails"
	anim.spin(sails, Vector3.BACK, 0.7)
	footprints.append({"c": c, "r": 3.3})
	_mark_walk(c, Vector2(1.9, 1.9), 0.0, 0)


## Пшеничное поле: золотая подложка и колосья (MultiMesh), качающиеся от ветра в шейдере.
func _wheat_field(h: Node3D, poi: Dictionary) -> void:
	var c := _center(poi)
	var sz: Array = poi.get("size", [20, 12])
	var size := Vector2(float(sz[0]), float(sz[1]))
	var rot := deg_to_rad(float(poi.get("rotation", 0.0)))
	var base_y := w.height_at(c.x, c.y)
	var node := Node3D.new()
	node.name = "WheatField"
	node.position = Vector3(c.x, base_y, c.y)
	node.rotation.y = rot
	h.add_child(node)
	var uk := PoiModels.Kit.new()
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	uk.quad(Vector3(-hx, 0.06, -hz), Vector3(hx, 0.06, -hz), Vector3(hx, 0.06, hz), Vector3(-hx, 0.06, hz),
		Color(0.8, 0.62, 0.3), "toon", Vector3.UP)
	_put_kit(node, uk)
	var b := Basis(Vector3.UP, rot)
	var xfs: Array[Transform3D] = []
	var stp := 0.75
	var nx := int(size.x / stp)
	var nz := int(size.y / stp)
	for i in nx:
		for j in nz:
			var lx := (float(i) + 0.5) * stp - size.x * 0.5 + rng.randf_range(-0.25, 0.25)
			var lz := (float(j) + 0.5) * stp - size.y * 0.5 + rng.randf_range(-0.25, 0.25)
			var wp := b * Vector3(lx, 0, lz)
			var gx := c.x + wp.x
			var gz := c.y + wp.z
			if w.road_distance(gx, gz) < road_half + 0.3 or not w.is_walkable(gx, gz):
				continue
			var s := rng.randf_range(0.85, 1.2)
			var ib := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(s, s * rng.randf_range(0.9, 1.15), s))
			xfs.append(Transform3D(ib, Vector3(lx, w.height_at(gx, gz) - base_y + 0.04, lz)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = PoiModels.get_mesh("wheat_clump")
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Wheat"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = DECOR_RANGE
	node.add_child(mmi)
	# Пугало посередине
	_prop(h, "scarecrow", c + Vector2(size.x * 0.12, 0.0).rotated(-rot), rng.randf() * TAU, 0.3, 2.4)


## Загон: круглая ограда с калиткой к деревне, овцы пасутся, кормушка и сено.
func _sheep_pen(h: Node3D, poi: Dictionary) -> void:
	var c := _center(poi)
	var r := float(poi.get("radius", 5.0))
	var to_v := (_nearest_village(c) - c).angle()
	_fence_ring(h, c, r, [to_v], 0.32, 1.1, 1.6, PoiModels.WOOD_LIGHT)
	footprints.append({"c": c, "r": r + 0.5})
	var back := c - Vector2(cos(to_v), sin(to_v)) * (r - 1.3)
	_prop(h, "trough", back, _yaw_to(back, c) + PI * 0.5, 0.0)
	var hay := c + Vector2(cos(to_v + 1.6), sin(to_v + 1.6)) * (r - 1.4)
	_prop(h, "hay", hay, rng.randf() * TAU)
	var flock: Array[Transform3D] = []
	for i in 4:
		var a := to_v + PI * 0.5 + float(i) * 1.3 + rng.randf_range(-0.3, 0.3)
		var p := c + Vector2(cos(a), sin(a)) * rng.randf_range(1.2, r - 1.8)
		flock.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), w.ground(p.x, p.y, -0.02)))
	_sheep(h, flock)


## Овцы загона: тела и головы — два MultiMesh (2 меша на всё стадо), пасутся (PoiAnimator).
func _sheep(parent: Node3D, flock: Array[Transform3D]) -> void:
	var node := Node3D.new()
	node.name = "Sheep"
	parent.add_child(node)
	var head_xf := Transform3D(Basis.IDENTITY, Vector3(0, 0.85, -0.55))
	var parts: Array[MultiMeshInstance3D] = []
	for part in ["sheep_body", "sheep_head"]:
		var body_part: bool = part == "sheep_body"
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = PoiModels.get_mesh(String(part))
		mm.instance_count = flock.size()
		for i in flock.size():
			mm.set_instance_transform(i, flock[i] if body_part else flock[i] * head_xf)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Bodies" if body_part else "Heads"
		mmi.multimesh = mm
		mmi.visibility_range_end = PROP_RANGE
		mmi.visibility_range_end_margin = 5.0
		node.add_child(mmi)
		parts.append(mmi)
	for i in flock.size():
		anim.graze_mm(parts[0], parts[1], i, flock[i], head_xf)


# ---------- Порт ----------

func _port(h: Node3D, poi: Dictionary) -> void:
	var c := _center(poi)
	var r := float(poi.get("radius", 10.0))
	# Склад у дороги, ящики и бочки, фонари
	for a in [200.0, 250.0, 150.0, 300.0, 100.0]:
		var p := _spot(c, a, r * 0.6, 3.1, 0.0, 0.8)
		if p.is_finite():
			# Склад фасадом к дороге (или к центру порта)
			var road_pt := _toward_road(p)
			_building(h, "town_house_b", p, road_pt if road_pt.is_finite() else c, Vector3(6.4, 5.4, 4.8), 3.1)
			break
	_scatter(h, c, ["crate", "crate", "barrel", "barrel", "crate"], 3.0, r, 0.6)
	for a in [0.0, 120.0, 240.0]:
		var lp := _spot(c, a, r * 0.5, 0.45, 0.0, 0.4)
		if lp.is_finite():
			_lantern(h, "lantern_town", lp, PoiModels.WIN_WARM)


## Ближайшая точка дороги к p в радиусе 12 м (по сетке расстояний), иначе Vector2.INF.
func _toward_road(p: Vector2) -> Vector2:
	var best := Vector2.INF
	var best_d := INF
	for k in 16:
		var a := TAU * float(k) / 16.0
		for rr in [3.0, 5.0, 7.0, 9.0, 12.0]:
			var q := p + Vector2(cos(a), sin(a)) * float(rr)
			var d := w.road_distance(q.x, q.y)
			if d < 1.0 and float(rr) < best_d:
				best_d = float(rr)
				best = q
	return best


func _lighthouse(h: Node3D, poi: Dictionary) -> void:
	var c := _center(poi)
	var port := w.poi("port")
	var face := v2(port["center"]) if not port.is_empty() else Vector2.ZERO
	var body := _body(h, Vector3(c.x, _floor_y(c, 2.2), c.y), _yaw_to(c, face))
	body.name = "Lighthouse"
	_put(body, "lighthouse")
	_cyl_shape(body, 2.3, 14.5, Vector3.ZERO)
	footprints.append({"c": c, "r": 2.8})
	_mark_walk(c, Vector2(1.8, 1.8), 0.0, 0)
	# Огонь и вращающийся луч
	var top := 0.8 + 11.0 + 0.95
	_halo(body, Vector3(0, top, 0), Color(1.0, 0.85, 0.5, 0.8), 5.0)
	var beam := Node3D.new()
	beam.name = "Beam"
	beam.position = Vector3(0, top, 0)
	body.add_child(beam)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.2
	cone.bottom_radius = 1.8
	cone.height = 18.0
	cone.radial_segments = 10
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	# Два конуса — один меш (узкий конец у фонаря: ось цилиндра (Y) кладём вдоль ±X)
	var st := SurfaceTool.new()
	for s in [-1.0, 1.0]:
		var sd: float = s
		st.append_from(cone, 0, Transform3D(Basis(Vector3.BACK, sd * PI * 0.5), Vector3(sd * 9.0, 0, 0)))
	var mi := MeshInstance3D.new()
	mi.name = "BeamMesh"
	mi.mesh = st.commit()
	mi.material_override = PoiModels.soft_material(Color(1.0, 0.9, 0.6, 0.16), true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("no_outline", true)
	beam.add_child(mi)
	anim.spin(beam, Vector3.UP, 0.8)


## Направление и начало причала: от берега (выше) в море (ниже), длина из конфига.
func _pier_frame(poi: Dictionary) -> Dictionary:
	var c := v2(poi["center"])
	var length := float(poi.get("length", 16.0))
	var rot := deg_to_rad(float(poi.get("rotation", 0.0)))
	var d := Vector2(sin(rot), cos(rot))
	var a := c - d * length * 0.5
	var b := c + d * length * 0.5
	if w.height_at(b.x, b.y) > w.height_at(a.x, a.y):
		d = -d
		var t := a
		a = b
		b = t
	return {"a": a, "b": b, "dir": d, "length": length}


## Причал: дощатый настил на сваях от берега в море, поперечная площадка в конце, тумбы, фонарь.
## Сваи доходят до дна (height_at). Клетки под настилом помечаются проходимыми.
func _pier(h: Node3D, poi: Dictionary) -> void:
	var f := _pier_frame(poi)
	var a: Vector2 = f["a"]
	var d: Vector2 = f["dir"]
	var length: float = f["length"]
	var yaw := atan2(d.x, d.y)
	var deck_y := maxf(w.height_at(a.x, a.y) + 0.25, w.sea_level + 1.2)
	var node := _body(h, Vector3(a.x, deck_y, a.y), yaw)
	node.name = "Pier"
	var k := PoiModels.Kit.new()
	var width := 2.8
	var head_w := 7.5
	var head_l := 3.2
	var b := Basis(Vector3.UP, yaw)
	# Доски настила
	var z := 0.0
	var i := 0
	while z < length:
		var c := PoiModels.WOOD_LIGHT if i % 2 == 0 else PoiModels.WOOD
		k.box(Vector3(0, -0.07, z + 0.24), Vector3(width, 0.14, 0.46), c)
		z += 0.5
		i += 1
	for s in [-1.0, 1.0]:
		var sx: float = float(s) * (width * 0.5 - 0.25)
		k.box(Vector3(sx, -0.25, length * 0.5), Vector3(0.22, 0.2, length), PoiModels.WOOD_DARK)
	# Площадка в конце
	k.box(Vector3(0, -0.07, length - head_l * 0.5), Vector3(head_w, 0.14, head_l), PoiModels.WOOD_LIGHT)
	k.box(Vector3(0, -0.25, length - head_l * 0.5), Vector3(head_w, 0.2, 0.3), PoiModels.WOOD_DARK)
	# Сваи до дна
	var piles: Array[Vector3] = []
	var zz := 1.5
	while zz <= length:
		for s in [-1.0, 1.0]:
			piles.append(Vector3(float(s) * (width * 0.5 - 0.1), 0, zz))
		zz += 2.5
	for s in [-1.0, -0.33, 0.33, 1.0]:
		piles.append(Vector3(float(s) * (head_w * 0.5 - 0.15), 0, length - 0.15))
		piles.append(Vector3(float(s) * (head_w * 0.5 - 0.15), 0, length - head_l + 0.15))
	for lp in piles:
		var wp := b * lp
		var ground := w.height_at(a.x + wp.x, a.y + wp.z) - deck_y
		if ground > -0.5:
			continue
		var top := 0.35
		var bottom := ground - 0.4
		k.tex = WorldTextures.BARK
		k.cyl(Vector3(lp.x, (top + bottom) * 0.5, lp.z), 0.15, 0.15, top - bottom, PoiModels.WOOD_DARK, 6)
		k.cyl(Vector3(lp.x, top + 0.02, lp.z), 0.17, 0.12, 0.08, PoiModels.WOOD, 6)
		k.tex = -1
	# Тумбы для швартовки и фонарь на площадке
	for zb in [length * 0.45, length * 0.75]:
		for s in [-1.0, 1.0]:
			k.tex = WorldTextures.BARK
			k.cyl(Vector3(float(s) * (width * 0.5 - 0.25), 0.25, float(zb)), 0.14, 0.12, 0.5, PoiModels.WOOD_DARK, 6)
			k.tex = -1
	k.box(Vector3(head_w * 0.5 - 0.4, 1.5, length - 0.4), Vector3(0.16, 3.0, 0.16), PoiModels.WOOD_DARK)
	k.box(Vector3(head_w * 0.5 - 0.4, 3.05, length - 0.4), Vector3(0.3, 0.36, 0.3), PoiModels.WIN_WARM, Vector3.ZERO, "glow")
	k.cyl(Vector3(head_w * 0.5 - 0.4, 3.35, length - 0.4), 0.3, 0.02, 0.25, PoiModels.ROOF_ORANGE, 4, Vector3(0, PI * 0.25, 0))
	k.box(Vector3(-head_w * 0.5 + 0.8, 0.4, length - 1.0), Vector3(0.8, 0.8, 0.8), PoiModels.WOOD_LIGHT)
	k.cyl(Vector3(-head_w * 0.5 + 1.8, 0.45, length - 0.8), 0.34, 0.34, 0.9, PoiModels.WOOD, 8)
	_put_kit(node, k)
	_halo(node, Vector3(head_w * 0.5 - 0.4, 3.05, length - 0.4), Color(1.0, 0.85, 0.5, 0.5), 1.4)
	# Коллизия настила и площадки
	_box_shape(node, Vector3(width, 0.3, length), Vector3(0, -0.15, length * 0.5))
	_box_shape(node, Vector3(head_w, 0.3, head_l), Vector3(0, -0.15, length - head_l * 0.5))
	# По настилу можно ходить (сетка проходимости считает там море)
	var mid := a + d * length * 0.5
	_mark_walk(mid, Vector2(width * 0.5 - 0.2, length * 0.5), yaw, 1)
	var hc := a + d * (length - head_l * 0.5)
	_mark_walk(hc, Vector2(head_w * 0.5 - 0.2, head_l * 0.5 - 0.2), yaw, 1)
	footprints.append({"c": mid, "r": 2.0})


## Корабль у берега: ищет рядом с точкой конфига достаточно глубокую воду, качается на волнах.
func _ship(h: Node3D, poi: Dictionary) -> void:
	var c := v2(poi["center"])
	var yaw := deg_to_rad(float(poi.get("rotation", 0.0)))
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var spot := Vector2.INF
	for rr in [0.0, 2.0, 4.0, 6.0, 8.0, 10.0, 13.0, 16.0]:
		for k in 12:
			var a := TAU * float(k) / 12.0
			var p := c + Vector2(cos(a), sin(a)) * float(rr)
			var bow := p + fwd * 4.5
			var stern := p - fwd * 3.5
			if _deep(p, 1.3) and _deep(bow, 0.6) and _deep(stern, 0.8):
				spot = p
				break
			if float(rr) == 0.0:
				break
		if spot.is_finite():
			break
	if not spot.is_finite():
		spot = c
	var node := Node3D.new()
	node.name = "Ship"
	node.position = Vector3(spot.x, w.sea_level, spot.y)
	node.rotation.y = yaw
	h.add_child(node)
	_mesh(node, PoiModels.get_mesh("ship"), Vector3.ZERO)
	anim.bob(node, 0.12, 0.045, 0.02, 1.0)
	footprints.append({"c": spot, "r": 4.5})


func _deep(p: Vector2, depth: float) -> bool:
	return w.height_at(p.x, p.y) < w.sea_level - depth and w.coast_distance(p.x, p.y) < 1.5


# ---------- Пещера и лагеря ----------

## Пещера: тёмный вход в скале на склоне холма (холм ядро поднимает к северу от центра), камни вокруг.
## Вход смотрит вниз по склону; если за входом оказалась бы дорога, вход поворачивается.
func _cave(h: Node3D, poi: Dictionary) -> void:
	var c := _center(poi)
	var hill_c := c + Vector2(0, -9)
	var down := (c - hill_c).normalized()
	# Выбор направления: коллизия скалы (глыба позади входа, столбы входа) не должна лечь
	# на дорогу; из подходящих — ближайшее к «вниз по склону»
	var checks := [[Vector2(0, -3.6), 2.4], [Vector2(-2.5, -0.6), 1.5], [Vector2(2.5, -0.4), 1.5],
		[Vector2(-4.5, -3.6), 0.3], [Vector2(4.5, -3.6), 0.3]]
	var best := down
	var best_score := -INF
	for k in 16:
		var f := Vector2.from_angle(TAU * float(k) / 16.0)
		var ok := true
		for e in checks:
			var q := c + _local_to_world(e[0], f)
			if w.road_distance(q.x, q.y) < road_half + float(e[1]):
				ok = false
		var score := f.dot(down) + (10.0 if ok else 0.0)
		if score > best_score:
			best_score = score
			best = f
	var yaw := atan2(best.x, best.y)
	var base_y := w.height_at(c.x, c.y)
	var body := _body(h, Vector3(c.x, base_y, c.y), yaw)
	body.name = "Cave"
	var kit := PoiModels.Kit.new()
	var rocks := [
		[Vector3(-2.5, 1.5, -0.6), Vector3(1.5, 2.2, 1.6), PoiModels.ROCK],
		[Vector3(2.5, 1.4, -0.4), Vector3(1.6, 2.0, 1.5), PoiModels.ROCK],
		[Vector3(0.0, 3.5, -1.0), Vector3(3.3, 1.3, 1.8), PoiModels.ROCK_DARK],
		[Vector3(0.0, 2.0, -3.8), Vector3(4.6, 3.2, 3.2), PoiModels.ROCK],
		[Vector3(-4.2, 1.1, -2.5), Vector3(2.4, 1.8, 2.2), PoiModels.ROCK_DARK],
		[Vector3(4.2, 0.9, -2.5), Vector3(2.2, 1.6, 2.0), PoiModels.ROCK_DARK],
		[Vector3(-1.5, 4.2, -2.8), Vector3(2.0, 1.4, 1.8), PoiModels.ROCK],
		[Vector3(1.8, 4.0, -3.0), Vector3(1.8, 1.2, 1.6), PoiModels.ROCK_DARK],
	]
	for e in rocks:
		var lp: Vector3 = e[0]
		var rad: Vector3 = e[1]
		var col: Color = e[2]
		var wp := c + _local_to_world(Vector2(lp.x, lp.z), best)
		# Боковые глыбы (без коллизии) не кладём на дорогу
		if absf(lp.x) > 3.0 and w.road_distance(wp.x, wp.y) < road_half + 1.0:
			continue
		var gy := w.height_at(wp.x, wp.y) - base_y
		kit.ball(Vector3(lp.x, lp.y + gy, lp.z), rad, col, 7, 4, Vector3(0, lp.x * 0.7, 0.15 * lp.x))
	# Тёмный проём (без освещения) и порог
	kit.box(Vector3(0, 1.35, -1.0), Vector3(2.8, 2.7, 1.4), Color(0.05, 0.035, 0.07), Vector3.ZERO, "glow")
	kit.ball(Vector3(0, 0.05, 0.1), Vector3(1.6, 0.12, 1.0), PoiModels.ROCK_DARK, 7, 3)
	# Факелы по сторонам входа
	for s in [-1.0, 1.0]:
		var x: float = float(s) * 1.75
		kit.tex = WorldTextures.BARK
		kit.cyl(Vector3(x, 1.0, 0.45), 0.07, 0.06, 2.0, PoiModels.WOOD_DARK, 5)
		kit.tex = -1
		kit.cyl(Vector3(x, 2.05, 0.45), 0.14, 0.1, 0.16, PoiModels.STONE_DARK, 6)
	_put_kit(body, kit)
	for s in [-1.0, 1.0]:
		var x: float = float(s) * 1.75
		_flame(body, _xf(Vector3(x, 2.1, 0.45), 0.0, Vector3(0.6, 0.7, 0.6)))
		_halo(body, Vector3(x, 2.4, 0.45), Color(1.0, 0.6, 0.25, 0.6), 1.6)
	# Коллизия: скала позади и закрытый проём (внутрь не пройти)
	_box_shape(body, Vector3(9.0, 6.0, 4.5), Vector3(0, 3.0, -3.6))
	_box_shape(body, Vector3(3.2, 3.2, 1.0), Vector3(0, 1.6, -0.9))
	for s in [-1.0, 1.0]:
		_cyl_shape(body, 1.4, 4.0, Vector3(float(s) * 2.5, 0, -0.6))
	_occupy(c + _local_to_world(Vector2(0, -2.5), best), 4.5, Vector2(4.2, 2.6), yaw)
	# Камни вокруг (без коллизии, мелкие)
	for i in 14:
		var a := rng.randf() * TAU
		var p := c + Vector2(cos(a), sin(a)) * rng.randf_range(5.5, 13.0)
		if w.road_distance(p.x, p.y) < road_half + 0.8 or not _free(p, 0.8):
			continue
		var kind := "rock" if rng.randf() < 0.6 else "rock_dark"
		var s := rng.randf_range(0.35, 1.0)
		var rpos := w.ground(p.x, p.y, s * 0.1)
		var ryaw := rng.randf() * TAU
		var sx := s * rng.randf_range(1.0, 1.5)
		var sz := s * rng.randf_range(0.9, 1.3)
		# Крупные — в меш построек (с тенью), мелкие — в меш мелочей
		_put(h, kind, _xf(rpos, ryaw, Vector3(sx, s, sz)), s <= 0.7)


## Локальная точка (x — вправо, y — вперёд по f) в мировое смещение.
static func _local_to_world(lp: Vector2, f: Vector2) -> Vector2:
	var right := Vector2(f.y, -f.x)
	# Правый вектор модели при +Z = f: Basis(UP, yaw) * (1,0,0) = (cos yaw, −sin yaw) = (f.y, −f.x)
	return right * lp.x + f * lp.y


## Лагерь: костёр в центре (там кончается дорога), палатки и ящики там, где нет дороги.
func _camp(h: Node3D, poi: Dictionary) -> void:
	var c := _center(poi)
	var fire := Node3D.new()
	fire.name = "Campfire"
	fire.position = w.ground(c.x, c.y, -0.03)
	h.add_child(fire)
	_put(fire, "campfire", Transform3D.IDENTITY, true)
	_flame(fire, _xf(Vector3(0, 0.1, 0)))
	_halo(fire, Vector3(0, 0.7, 0), Color(1.0, 0.6, 0.25, 0.65), 2.6)
	var sparks := CPUParticles3D.new()
	sparks.name = "Sparks"
	sparks.amount = 8
	sparks.lifetime = 1.4
	sparks.mesh = Vfx._quad()
	sparks.material_override = Vfx._particle_mat("star", true)
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 0.25
	sparks.direction = Vector3.UP
	sparks.spread = 15.0
	sparks.initial_velocity_min = 0.8
	sparks.initial_velocity_max = 1.6
	sparks.gravity = Vector3(0, 0.4, 0)
	sparks.scale_amount_min = 0.06
	sparks.scale_amount_max = 0.14
	sparks.color_ramp = Vfx._ramp(Color(1.0, 0.6, 0.2))
	sparks.position = Vector3(0, 0.6, 0)
	sparks.visibility_range_end = PROP_RANGE
	fire.add_child(sparks)
	sparks.emitting = true
	# Палатки: две в свободных от дороги направлениях
	var tents := 0
	var start := rng.randf() * TAU
	for k in 16:
		if tents >= 2:
			break
		var a := start + TAU * float(k) / 16.0 * 7.0
		var p := c + Vector2(cos(a), sin(a)) * 4.3
		if _clear(p, 2.0, 0.4):
			var kind := "tent_bell" if tents == 0 else "tent_ridge"
			var size := Vector3(3.6, 3.0, 3.6) if tents == 0 else Vector3(2.8, 2.0, 3.2)
			_building(h, kind, p, c, size, 2.2, 1.8 if tents == 0 else 0.0)
			tents += 1
	_scatter(h, c, ["crate", "barrel", "crate"], 2.4, 5.5, 0.6)
	footprints.append({"c": c, "r": 1.2})


# ---------- Мосты ----------

## Перила мостов: столбики по краям настила и поручни; настил и его коллизию строит ядро.
func _bridge_rails() -> void:
	var holder := Node3D.new()
	holder.name = "BridgeRails"
	root.add_child(holder)
	for br in w.bridges:
		var a: Vector3 = br["a"]
		var e: Vector3 = br["b"]
		var width := float(br["width"])
		var flat := Vector2(e.x - a.x, e.z - a.z)
		var length := flat.length()
		if length < 0.5:
			continue
		var mid := (a + e) * 0.5
		# Перила — в меш построек ближайшей зоны (или своей)
		_zone = _zone_at(Vector2(mid.x, mid.z), holder)
		var yaw := atan2(flat.x, flat.y)
		var k := PoiModels.Kit.new()
		var n := maxi(2, int(ceilf(length / 1.6)))
		var dy := e.y - a.y
		var pitch := -atan2(dy, length)
		for s in [-1.0, 1.0]:
			var x: float = float(s) * (width * 0.5 - 0.1)
			for i in n + 1:
				var t := float(i) / float(n)
				var z := (t - 0.5) * length
				var y := a.y + dy * t + 0.05 - mid.y
				var end := i == 0 or i == n
				var ps := 0.24 if end else 0.14
				var ph := 1.25 if end else 1.0
				k.tex = WorldTextures.BARK
				k.box(Vector3(x, y + ph * 0.5, z), Vector3(ps, ph, ps), PoiModels.WOOD_DARK)
				k.tex = -1
				if end:
					k.ball(Vector3(x, y + ph + 0.1, z), Vector3(0.16, 0.16, 0.16), PoiModels.WOOD, 6, 3)
			var ymid := 0.05 + (a.y + e.y) * 0.5 - mid.y
			k.tex = WorldTextures.LOG
			k.box(Vector3(x, ymid + 0.95, 0), Vector3(0.12, 0.12, length), PoiModels.WOOD, Vector3(pitch, 0, 0))
			k.box(Vector3(x, ymid + 0.5, 0), Vector3(0.08, 0.08, length), PoiModels.WOOD, Vector3(pitch, 0, 0))
			k.tex = -1
		_put_kit(holder, k, _xf(mid, yaw))
