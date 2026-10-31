class_name IslandWorld
extends Node3D
## Тренировочный остров. Всё берётся из конфига world/training_island.json (координаты в метрах:
## x — восток, z — юг; город новичков в начале координат на высоте 0) и маски берега,
## извлечённой из reference/training_island.png (tools/extract_island_masks.py).
##
## Строит: сетку высот (холмы, скалистый берег, русло реки, пруд, площадки под постройки, дороги),
## меш рельефа участками, коллизию HeightMapShape3D, сетку проходимости (аналог навмеша: вода и
## крутые склоны непроходимы, мосты проходимы), мосты там, где дорога пересекает реку.
## Вода, постройки и растительность — отдельные модули: IslandWater, IslandPois, IslandVegetation.
##
## Запросы для других модулей через IslandWorld.current:
## height_at(x, z), is_walkable(x, z), in_safe_zone(pos), road_distance(x, z), water_distance(x, z),
## zone_tint_at(x, z), forest_at(x, z), spawn_point(race), mob_slots(rng), poi(id), pois_of_type(type).

const CONFIG_PATH := "res://world/training_island.json"
## Размер участка меша рельефа, клеток.
const CHUNK := 48
## Дальше этого расстояния (м) дороги и вода в сетках расстояний не считаются.
const FAR := 16.0
## Самый крутой проходимый перепад высоты между соседними клетками сетки, м на клетку.
const MAX_STEP := 0.9
## «Не вода» для _raster_segment.
const NO_LEVEL := -1000.0
## Ширина склона русла реки от края воды, м (дальше — ровный берег).
const RIVER_BANK := 4.0
## Мост: на сколько метров концы настила заходят на ровный берег за склоном русла (поперёк реки), толщина настила.
const BRIDGE_BANK := 1.2
const BRIDGE_THICK := 0.3
## Точек профиля настила (высота верха по длине моста).
const BRIDGE_SAMPLES := 16
## Подход к мосту — точка на дороге за концом настила, м (bridge_waypoint: путь питомцев и зверей).
const BRIDGE_APPROACH := 1.8
## Лесная подстилка: шаг сетки веса леса, м, и радиус пятна под деревом, м.
const FOREST_STEP := 2.0
const FOREST_RADIUS := 5.5

static var current: IslandWorld = null

var cfg: Dictionary = {}
var step := 1.0
## Мировые x, z узла сетки (0, 0).
var origin := Vector2.ZERO
var nx := 0
var nz := 0
var heights := PackedFloat32Array()
## 1 — можно ходить.
var walk := PackedByteArray()
## Расстояние до оси ближайшей дороги и до воды (река, пруд), м (не больше FAR).
var road_d := PackedFloat32Array()
var water_d := PackedFloat32Array()
## Уровень воды в узле (для реки и пруда), иначе уровень моря.
var water_level := PackedFloat32Array()
var sea_level := -2.5
var river_level := -2.2
## Материал рельефа (Quality переключает облегчённый режим шейдера).
var terrain_material: ShaderMaterial = null
## Мосты: {"a": Vector3, "b": Vector3, "width": float, "deck": PackedFloat32Array} — концы на земле (a, b),
## ширина настила и высоты верха настила в BRIDGE_SAMPLES + 1 точках от a до b (bridge_point).
var bridges: Array[Dictionary] = []
## Вес леса 0..1 на сетке FOREST_STEP (лесная подстилка под деревьями; bake_forest).
var forest_w := PackedFloat32Array()
var forest_nx := 0
var forest_nz := 0

var _coast := PackedByteArray()
var _coast_w := 0
var _coast_h := 0
var _ref_origin := Vector2.ZERO
var _ref_mpp := 0.2
var _ref_k := 0.25
var _coast_scale := 4.0
var _noise := FastNoiseLite.new()
var _flat_w := PackedFloat32Array()
var _flat_h := PackedFloat32Array()
## Кэш оттенков зон: [[центр Vector2, Color], ...]
var _tints: Array = []


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


## Строит остров. rng — общий генератор мира (зерно фиксировано в main).
func build(rng: RandomNumberGenerator) -> void:
	_load_config()
	_init_grid()
	_compute_distances()
	_compute_heights(rng)
	_find_bridges()
	_compute_walkable()
	WorldBuilder._build_environment(self)
	_build_collision()
	_build_bridges()
	IslandWater.build(self)
	IslandPois.build(self, rng)
	# Растительность до меша рельефа: она расставляет деревья и запекает вес леса (bake_forest),
	# который меш рельефа пишет в UV2.x вершин (лесная подстилка в island_terrain.gdshader)
	IslandVegetation.build(self, rng)
	_build_terrain_mesh()


# ---------- Конфиг и сетка ----------

func _load_config() -> void:
	var text := FileAccess.get_file_as_string(CONFIG_PATH)
	var d = JSON.parse_string(text)
	if not (d is Dictionary):
		push_error("Не прочитан конфиг острова " + CONFIG_PATH)
		d = {}
	cfg = d
	var hcfg: Dictionary = cfg.get("heights", {})
	sea_level = float(hcfg.get("sea_level", -2.5))
	step = float(hcfg.get("grid_step", 1.0))
	river_level = float(cfg.get("river", {}).get("water_level", -2.2))
	var ref: Dictionary = cfg.get("reference", {})
	var osz: Array = ref.get("origin_px", [896, 504])
	_ref_origin = Vector2(float(osz[0]), float(osz[1]))
	_ref_mpp = float(ref.get("meters_per_px", 0.2))
	var isz: Array = ref.get("image_size", [1792, 1008])
	var msz: Array = ref.get("mask_size", [448, 252])
	_coast_w = int(msz[0])
	_coast_h = int(msz[1])
	_ref_k = float(_coast_w) / float(isz[0])
	_coast_scale = float(ref.get("coast_distance_scale", 4.0))
	_coast = FileAccess.get_file_as_bytes(String(ref.get("coast_distance", "")))
	if _coast.size() != _coast_w * _coast_h:
		push_error("Не прочитана маска берега острова")
		_coast = PackedByteArray()
	_noise.seed = 7
	_noise.frequency = float(hcfg.get("hill_frequency", 0.018))
	_noise.fractal_octaves = 3


func _init_grid() -> void:
	var isz: Array = cfg.get("reference", {}).get("image_size", [1792, 1008])
	var x0 := -_ref_origin.x * _ref_mpp
	var z0 := -_ref_origin.y * _ref_mpp
	var x1 := (float(isz[0]) - _ref_origin.x) * _ref_mpp
	var z1 := (float(isz[1]) - _ref_origin.y) * _ref_mpp
	origin = Vector2(floorf(x0), floorf(z0))
	nx = int(ceilf((x1 - origin.x) / step)) + 1
	nz = int(ceilf((z1 - origin.y) / step)) + 1
	var n := nx * nz
	heights.resize(n)
	walk.resize(n)
	road_d.resize(n)
	water_d.resize(n)
	water_level.resize(n)
	_flat_w.resize(n)
	_flat_h.resize(n)
	road_d.fill(FAR)
	water_d.fill(FAR)
	water_level.fill(sea_level)
	_flat_w.fill(0.0)
	_flat_h.fill(0.0)


func _idx(i: int, j: int) -> int:
	return j * nx + i


func _pos(i: int, j: int) -> Vector2:
	return Vector2(origin.x + float(i) * step, origin.y + float(j) * step)


static func v2(a) -> Vector2:
	var arr: Array = a
	return Vector2(float(arr[0]), float(arr[1]))


## Расстояние со знаком до берега, м (больше нуля — суша).
func coast_distance(x: float, z: float) -> float:
	if _coast.is_empty():
		return 10.0
	var u := (x / _ref_mpp + _ref_origin.x) * _ref_k - 0.5
	var v := (z / _ref_mpp + _ref_origin.y) * _ref_k - 0.5
	var i0 := clampi(int(floorf(u)), 0, _coast_w - 1)
	var j0 := clampi(int(floorf(v)), 0, _coast_h - 1)
	var i1 := mini(i0 + 1, _coast_w - 1)
	var j1 := mini(j0 + 1, _coast_h - 1)
	var fu := clampf(u - float(i0), 0.0, 1.0)
	var fv := clampf(v - float(j0), 0.0, 1.0)
	var a := lerpf(float(_coast[j0 * _coast_w + i0]), float(_coast[j0 * _coast_w + i1]), fu)
	var b := lerpf(float(_coast[j1 * _coast_w + i0]), float(_coast[j1 * _coast_w + i1]), fu)
	return (lerpf(a, b, fv) - 128.0) / _coast_scale


# ---------- Расстояния до дорог и воды (растеризация отрезков) ----------

func _compute_distances() -> void:
	var roads: Dictionary = cfg.get("roads", {})
	for key in roads.get("paths", {}):
		var path: Array = roads["paths"][key]
		for s in range(path.size() - 1):
			_raster_segment(v2(path[s]), v2(path[s + 1]), road_d, FAR, NO_LEVEL)
	var river: Dictionary = cfg.get("river", {})
	for br in river.get("branches", []):
		var pts: Array = br
		for s in range(pts.size() - 1):
			_raster_segment(v2(pts[s]), v2(pts[s + 1]), water_d, FAR, river_level)
	for p in cfg.get("ponds", []):
		var pond: Dictionary = p
		var c := v2(pond["center"])
		var r := float(pond.get("radius", 6.0))
		var lvl := float(pond.get("water_level", -0.6))
		_raster_circle(c, r, lvl)


## Записывает в grid минимум расстояния до отрезка ab. level != NO_LEVEL: заодно уровень воды.
func _raster_segment(a: Vector2, b: Vector2, grid: PackedFloat32Array, reach: float, level: float) -> void:
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(reach, reach)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(reach, reach)
	var i0 := clampi(int((lo.x - origin.x) / step), 0, nx - 1)
	var i1 := clampi(int((hi.x - origin.x) / step) + 1, 0, nx - 1)
	var j0 := clampi(int((lo.y - origin.y) / step), 0, nz - 1)
	var j1 := clampi(int((hi.y - origin.y) / step) + 1, 0, nz - 1)
	var ab := b - a
	var len2 := maxf(ab.length_squared(), 0.0001)
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var p := _pos(i, j)
			var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
			var d := p.distance_to(a + ab * t)
			var k := _idx(i, j)
			if d < grid[k]:
				grid[k] = d
				if level > NO_LEVEL:
					water_level[k] = level


## Пруд: расстояние до края круга (внутри — 0), уровень воды пруда.
func _raster_circle(c: Vector2, r: float, level: float) -> void:
	var reach := r + FAR
	var i0 := clampi(int((c.x - reach - origin.x) / step), 0, nx - 1)
	var i1 := clampi(int((c.x + reach - origin.x) / step) + 1, 0, nx - 1)
	var j0 := clampi(int((c.y - reach - origin.y) / step), 0, nz - 1)
	var j1 := clampi(int((c.y + reach - origin.y) / step) + 1, 0, nz - 1)
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var d := maxf(0.0, _pos(i, j).distance_to(c) - r)
			var k := _idx(i, j)
			if d < water_d[k]:
				water_d[k] = d
				water_level[k] = level


# ---------- Высоты ----------

func _compute_heights(_rng: RandomNumberGenerator) -> void:
	var hc: Dictionary = cfg.get("heights", {})
	var sea_floor := float(hc.get("sea_floor", -7.0))
	var town := float(hc.get("town_level", 0.0))
	var amp := float(hc.get("hill_amplitude", 5.0))
	var depth := float(hc.get("river_depth", 1.6))
	var road_w := float(cfg.get("roads", {}).get("width", 3.2))
	var river_w := float(cfg.get("river", {}).get("width", 5.0))

	# Площадки под постройки: вес выравнивания и целевая высота
	for p in cfg.get("pois", []):
		var poi: Dictionary = p
		var fr := float(poi.get("flatten", 0.0))
		if fr <= 0.0:
			continue
		_raster_flatten(v2(poi["center"]), fr, town)

	for j in nz:
		for i in nx:
			var k := _idx(i, j)
			var p := _pos(i, j)
			var cd := coast_distance(p.x, p.y)
			# Холмы: шум, приглушённый у построек, дорог и воды
			var n := _noise.get_noise_2d(p.x, p.y) * 0.5 + 0.5
			var wild := 1.0 - _flat_w[k]
			wild *= smoothstep(road_w * 0.5, road_w * 0.5 + 7.0, road_d[k])
			wild *= smoothstep(river_w * 0.5, river_w * 0.5 + 9.0, water_d[k])
			wild *= smoothstep(2.0, 14.0, cd)
			var land := lerpf(town, _flat_h[k], _flat_w[k]) + pow(n, 1.6) * amp * wild
			land += _noise.get_noise_2d(p.x * 3.1 + 40.0, p.y * 3.1) * 0.25 * wild
			# Дороги чуть ниже травы
			land -= 0.06 * (1.0 - smoothstep(road_w * 0.4, road_w * 0.6, road_d[k]))
			var h: float
			if cd <= 0.0:
				h = lerpf(sea_level - 1.0, sea_floor, clampf(-cd / 14.0, 0.0, 1.0))
			else:
				# Скалистый берег: крутой подъём на первых метрах от воды
				var edge := 2.5 + _noise.get_noise_2d(p.x * 0.7, p.y * 0.7 + 90.0) * 1.5
				h = lerpf(sea_level - 1.0, land, smoothstep(0.0, edge, cd))
			# Русло реки и пруд
			var wl := water_level[k]
			var bed := wl - depth
			var half := river_w * 0.5
			if water_d[k] < half + RIVER_BANK:
				var t := smoothstep(half * 0.55, half + RIVER_BANK, water_d[k])
				h = minf(h, lerpf(bed, maxf(h, wl + 0.6), t))
			heights[k] = h

	# Холм с пещерой и прочие «hill» из конфига
	for p in cfg.get("pois", []):
		var poi: Dictionary = p
		var hill := float(poi.get("hill", 0.0))
		if hill <= 0.0:
			continue
		var c := v2(poi["center"]) + Vector2(0, -9)
		_raster_hill(c, 20.0, hill)


func _raster_flatten(c: Vector2, r: float, level: float) -> void:
	var reach := r + 10.0
	var i0 := clampi(int((c.x - reach - origin.x) / step), 0, nx - 1)
	var i1 := clampi(int((c.x + reach - origin.x) / step) + 1, 0, nx - 1)
	var j0 := clampi(int((c.y - reach - origin.y) / step), 0, nz - 1)
	var j1 := clampi(int((c.y + reach - origin.y) / step) + 1, 0, nz - 1)
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var d := _pos(i, j).distance_to(c)
			var w := 1.0 - smoothstep(r, reach, d)
			var k := _idx(i, j)
			if w > _flat_w[k]:
				_flat_w[k] = w
				_flat_h[k] = level


func _raster_hill(c: Vector2, r: float, h: float) -> void:
	var i0 := clampi(int((c.x - r - origin.x) / step), 0, nx - 1)
	var i1 := clampi(int((c.x + r - origin.x) / step) + 1, 0, nx - 1)
	var j0 := clampi(int((c.y - r - origin.y) / step), 0, nz - 1)
	var j1 := clampi(int((c.y + r - origin.y) / step) + 1, 0, nz - 1)
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var d := _pos(i, j).distance_to(c)
			if d < r:
				var k := _idx(i, j)
				var t := 1.0 - d / r
				heights[k] += h * t * t * (3.0 - 2.0 * t) * smoothstep(0.0, 6.0, coast_distance(_pos(i, j).x, _pos(i, j).y))


# ---------- Мосты: пересечения дорог с рекой ----------

func _find_bridges() -> void:
	var river_w := float(cfg.get("river", {}).get("width", 5.0))
	var road_w := float(cfg.get("roads", {}).get("width", 3.2))
	# Концы моста — там, где дорога вышла из русла на ровный берег (за склоном RIVER_BANK + BRIDGE_BANK):
	# по самой дороге, поэтому и при косом пересечении, и на изгибе дороги концы не остаются на склоне
	# (0.14.0: у кольцевой дороги конец был на склоне русла — настил шёл криво, со ступенькой)
	var dry := river_w * 0.5 + RIVER_BANK + BRIDGE_BANK
	var segs: Array = []
	for br in cfg.get("river", {}).get("branches", []):
		var pts: Array = br
		for s in range(pts.size() - 1):
			segs.append([v2(pts[s]), v2(pts[s + 1])])
	for key in cfg.get("roads", {}).get("paths", {}):
		var path: Array = cfg["roads"]["paths"][key]
		var along := 0.0
		for s in range(path.size() - 1):
			var a := v2(path[s])
			var b := v2(path[s + 1])
			for rs in segs:
				var hit = Geometry2D.segment_intersects_segment(a, b, rs[0], rs[1])
				if hit == null:
					continue
				var p: Vector2 = hit
				var s0 := along + a.distance_to(p)
				var sa := s0
				while s0 - sa < 25.0:
					var q := _path_point(path, sa)
					if water_distance(q.x, q.y) >= dry:
						break
					sa -= 0.5
				var sb := s0
				while sb - s0 < 25.0:
					var q := _path_point(path, sb)
					if water_distance(q.x, q.y) >= dry:
						break
					sb += 0.5
				var pa := _path_point(path, sa)
				var pb := _path_point(path, sb)
				var br := {
					"a": Vector3(pa.x, height_at(pa.x, pa.y), pa.y),
					"b": Vector3(pb.x, height_at(pb.x, pb.y), pb.y),
					"width": road_w + 0.8,
				}
				# Две дороги пересекают реку рядом и сходятся на берегу (кольцевая и дорога к эльфам у развилки):
				# второй мост лёг бы настилом на первый — он не нужен, берега уже связаны
				if _bridge_overlaps(br):
					continue
				br["deck"] = _deck_profile(br)
				bridges.append(br)
			along += a.distance_to(b)


## Настил br ближе ширины к настилу уже поставленного моста.
func _bridge_overlaps(br: Dictionary) -> bool:
	var a3: Vector3 = br["a"]
	var b3: Vector3 = br["b"]
	for o in bridges:
		var c3: Vector3 = o["a"]
		var e3: Vector3 = o["b"]
		var gap := (float(br["width"]) + float(o["width"])) * 0.5 + 0.5
		for i in 11:
			var t := float(i) / 10.0
			var p := Vector2(a3.x, a3.z).lerp(Vector2(b3.x, b3.z), t)
			var q := Geometry2D.get_closest_point_to_segment(p, Vector2(c3.x, c3.z), Vector2(e3.x, e3.z))
			if p.distance_to(q) < gap:
				return true
	return false


## Точка ломаной на расстоянии s от начала (за концами — по продолжению крайнего отрезка).
func _path_point(path: Array, s: float) -> Vector2:
	var along := 0.0
	for i in range(path.size() - 1):
		var a := v2(path[i])
		var b := v2(path[i + 1])
		var l := a.distance_to(b)
		if s <= along + l or i == path.size() - 2:
			if s < 0.0 and i == 0:
				return a + (b - a).normalized() * s
			return a + (b - a).normalized() * (s - along)
		along += l
	return v2(path[path.size() - 1])


## Профиль настила: верх концов вровень с землёй (чуть ниже — без ступеньки, на которой застревает
## коробка питомца), между ними — прямая от конца к концу, но не ниже земли под настилом (по всей ширине)
## на 8 см; сглажено, чтобы на горбе берега не было излома.
func _deck_profile(br: Dictionary) -> PackedFloat32Array:
	var a: Vector3 = br["a"]
	var e: Vector3 = br["b"]
	var half_w := float(br["width"]) * 0.5
	var flat := Vector2(e.x - a.x, e.z - a.z)
	var side := Vector2(-flat.y, flat.x).normalized()
	var n := BRIDGE_SAMPLES
	var floor_y := PackedFloat32Array()
	floor_y.resize(n + 1)
	for i in n + 1:
		var t := float(i) / float(n)
		var q := Vector2(a.x, a.z) + flat * t
		var g := -INF
		for k in 5:
			var o := side * half_w * (float(k) / 2.0 - 1.0)
			g = maxf(g, height_at(q.x + o.x, q.y + o.y))
		floor_y[i] = g
	var ya := height_at(a.x, a.z) - 0.03
	var yb := height_at(e.x, e.z) - 0.03
	var deck := PackedFloat32Array()
	deck.resize(n + 1)
	for i in n + 1:
		deck[i] = maxf(lerpf(ya, yb, float(i) / float(n)), floor_y[i] + 0.08)
	deck[0] = ya
	deck[n] = yb
	for _pass in 3:
		var sm := deck.duplicate()
		for i in range(1, n):
			sm[i] = maxf(deck[i - 1] * 0.25 + deck[i] * 0.5 + deck[i + 1] * 0.25, floor_y[i] + 0.06)
		deck = sm
	return deck


## Верх настила моста в доле t (0 — конец a, 1 — конец b), мировые координаты.
static func bridge_point(br: Dictionary, t: float) -> Vector3:
	var a: Vector3 = br["a"]
	var e: Vector3 = br["b"]
	var deck: PackedFloat32Array = br.get("deck", PackedFloat32Array())
	var p := a.lerp(e, clampf(t, 0.0, 1.0))
	if deck.size() < 2:
		return p
	var f := clampf(t, 0.0, 1.0) * float(deck.size() - 1)
	var i := mini(int(floorf(f)), deck.size() - 2)
	p.y = lerpf(deck[i], deck[i + 1], f - float(i))
	return p


# ---------- Проходимость ----------

func _compute_walkable() -> void:
	for j in nz:
		for i in nx:
			var k := _idx(i, j)
			var h := heights[k]
			var ok := h > water_level[k] + 0.2 and h > sea_level + 0.2
			if ok:
				var hx := heights[_idx(mini(i + 1, nx - 1), j)]
				var hz := heights[_idx(i, mini(j + 1, nz - 1))]
				var hx0 := heights[_idx(maxi(i - 1, 0), j)]
				var hz0 := heights[_idx(i, maxi(j - 1, 0))]
				var slope := maxf(maxf(absf(hx - h), absf(hz - h)), maxf(absf(hx0 - h), absf(hz0 - h)))
				ok = slope < MAX_STEP * step
			walk[k] = 1 if ok else 0
	# Мосты проходимы
	for b in bridges:
		var a3: Vector3 = b["a"]
		var b3: Vector3 = b["b"]
		var half := float(b["width"]) * 0.5
		var a := Vector2(a3.x, a3.z)
		var bb := Vector2(b3.x, b3.z)
		var lo := Vector2(minf(a.x, bb.x), minf(a.y, bb.y)) - Vector2(half, half)
		var hi := Vector2(maxf(a.x, bb.x), maxf(a.y, bb.y)) + Vector2(half, half)
		for j in range(clampi(int((lo.y - origin.y) / step), 0, nz - 1), clampi(int((hi.y - origin.y) / step) + 2, 0, nz)):
			for i in range(clampi(int((lo.x - origin.x) / step), 0, nx - 1), clampi(int((hi.x - origin.x) / step) + 2, 0, nx)):
				var p := _pos(i, j)
				var ab := bb - a
				var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
				if p.distance_to(a + ab * t) <= half:
					walk[_idx(i, j)] = 1


# ---------- Меш и коллизия ----------

func _build_terrain_mesh() -> void:
	# Свой шейдер земли (island_terrain.gdshader): рисованная трава, дороги, скалы, песок, toon-свет
	var mat := ShaderMaterial.new()
	mat.shader = load("res://island_terrain.gdshader")
	mat.set_shader_parameter("road_half", float(cfg.get("roads", {}).get("width", 3.2)) * 0.45)
	mat.set_shader_parameter("rich", Quality.rich_shaders())
	# Город: мощёная площадь вокруг свободного центра и мощёные улицы внутри ограды (с текстурами)
	var towns := pois_of_type("town")
	if not towns.is_empty():
		var town: Dictionary = towns[0]
		mat.set_shader_parameter("town_center", v2(town["center"]))
		mat.set_shader_parameter("plaza_radius", IslandPois.TOWN_FREE + 2.0)
		mat.set_shader_parameter("paved_radius", float(town.get("radius", 22.0)))
	# Рисованные текстуры (WorldTextures): включаются по качеству
	WorldTextures.register_terrain(mat)
	terrain_material = mat
	var holder := Node3D.new()
	holder.name = "Terrain"
	add_child(holder)
	var cj := 0
	while cj < nz - 1:
		var ci := 0
		while ci < nx - 1:
			var mi := MeshInstance3D.new()
			mi.set_meta("no_outline", true)
			mi.mesh = _chunk_mesh(ci, cj, mini(ci + CHUNK, nx - 1), mini(cj + CHUNK, nz - 1))
			mi.material_override = mat
			holder.add_child(mi)
			ci += CHUNK
		cj += CHUNK


## Участок рельефа. Вершины: цвет — оттенок травы и вес площадки (_ground_color),
## UV — (расстояние до дороги, уровень ближайшей воды), UV2.x — вес леса (без площадок построек);
## остальное считает шейдер по пикселям.
func _chunk_mesh(i0: int, j0: int, i1: int, j1: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var idx := PackedInt32Array()
	var w := i1 - i0 + 1
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var p := _pos(i, j)
			var k := _idx(i, j)
			verts.append(Vector3(p.x, heights[k], p.y))
			normals.append(_normal(i, j))
			colors.append(_ground_color(i, j))
			var wl := maxf(water_level[k], sea_level)
			# Река у устья опускается к уровню моря (как и вода в IslandWater)
			if water_d[k] < FAR and absf(wl - river_level) < 0.001:
				wl = lerpf(sea_level, river_level, smoothstep(1.5, 12.0, coast_distance(p.x, p.y)))
			uvs.append(Vector2(road_d[k], wl))
			uv2s.append(Vector2(forest_at(p.x, p.y) * (1.0 - clampf(_flat_w[k], 0.0, 1.0)), 0.0))
	for j in range(j1 - j0):
		for i in range(i1 - i0):
			var a := j * w + i
			var b := a + w
			idx.append_array([a, a + 1, b, a + 1, b + 1, b])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


func _normal(i: int, j: int) -> Vector3:
	var hl := heights[_idx(maxi(i - 1, 0), j)]
	var hr := heights[_idx(mini(i + 1, nx - 1), j)]
	var hd := heights[_idx(i, maxi(j - 1, 0))]
	var hu := heights[_idx(i, mini(j + 1, nz - 1))]
	return Vector3(hl - hr, 2.0 * step, hd - hu).normalized()


## Цвет земли в узле (sRGB, шейдер переводит в линейный): оттенок травы зоны с крупными
## мягкими переливами; альфа — вес площадки постройки. Дороги, песок, скалы и мелкие пятна
## рисует island_terrain.gdshader по пикселям.
func _ground_color(i: int, j: int) -> Color:
	var k := _idx(i, j)
	var p := _pos(i, j)
	var c := zone_tint_at(p.x, p.y)
	# Крупные переливы оттенка (чуть желтее / чуть синее), чтобы луг не был однотонным
	var n := _noise.get_noise_2d(p.x * 0.6 + 11.0, p.y * 0.6)
	if n > 0.0:
		c = c.lerp(Color(0.62, 0.74, 0.30), n * 0.35)
	else:
		c = c.lerp(Color(0.26, 0.54, 0.36), -n * 0.3)
	c.a = clampf(_flat_w[k], 0.0, 1.0)
	return c


func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	var col := CollisionShape3D.new()
	var shape := HeightMapShape3D.new()
	shape.map_width = nx
	shape.map_depth = nz
	shape.map_data = heights
	col.shape = shape
	# Форма центрирована: узел (0,0) сетки окажется в origin
	col.position = Vector3(origin.x + float(nx - 1) * step * 0.5, 0.0, origin.y + float(nz - 1) * step * 0.5)
	col.scale = Vector3(step, 1.0, step)
	body.add_child(col)
	add_child(body)


func _build_bridges() -> void:
	# Настил — toon.gdshader с текстурой досок (WorldTextures.WOOD) по качеству, контур — как у построек
	var deck_color := Color(0.62, 0.44, 0.28)
	var deck_mat := PoiModels.toon_material(deck_color, false, 2, 0.2)
	deck_mat.set_shader_parameter("tex_layer", WorldTextures.WOOD)
	if Quality.outlines():
		deck_mat.next_pass = Util.outline_mat(deck_color)
	for b in bridges:
		var a: Vector3 = b["a"]
		var e: Vector3 = b["b"]
		var mid := (a + e) * 0.5
		var body := StaticBody3D.new()
		body.name = "Bridge"
		body.add_to_group("bridges")
		body.position = mid
		var built := _deck_mesh(b, mid)
		var mesh: ArrayMesh = built[0]
		var faces: PackedVector3Array = built[1]
		var col := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		col.shape = shape
		body.add_child(col)
		var deck := MeshInstance3D.new()
		deck.mesh = mesh
		deck.material_override = deck_mat
		body.add_child(deck)
		add_child(body)


## Меш настила по профилю (bridge_point): верх, бока и низ толщиной BRIDGE_THICK; концы уходят в землю.
## Возвращает [ArrayMesh, PackedVector3Array треугольников для коллизии].
func _deck_mesh(br: Dictionary, center: Vector3) -> Array:
	var a: Vector3 = br["a"]
	var e: Vector3 = br["b"]
	var half_w := float(br["width"]) * 0.5
	var flat := Vector3(e.x - a.x, 0.0, e.z - a.z)
	var side := Vector3(-flat.z, 0.0, flat.x).normalized() * half_w
	var down := Vector3(0.0, -BRIDGE_THICK, 0.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Плоские нормали — как у прежнего настила-коробки (рёбра досок не скругляются светом)
	st.set_smooth_group(-1)
	var faces := PackedVector3Array()
	var n := BRIDGE_SAMPLES
	for i in n:
		var p0 := bridge_point(br, float(i) / float(n)) - center
		var p1 := bridge_point(br, float(i + 1) / float(n)) - center
		var l0 := p0 + side
		var r0 := p0 - side
		var l1 := p1 + side
		var r1 := p1 - side
		faces.append_array(_quad(st, l0, l1, r1, r0))
		faces.append_array(_quad(st, l0 + down, r0 + down, r1 + down, l1 + down))
		faces.append_array(_quad(st, l0, l0 + down, l1 + down, l1))
		faces.append_array(_quad(st, r1, r1 + down, r0 + down, r0))
	var s0 := bridge_point(br, 0.0) - center
	var s1 := bridge_point(br, 1.0) - center
	faces.append_array(_quad(st, s0 - side, s0 - side + down, s0 + side + down, s0 + side))
	faces.append_array(_quad(st, s1 + side, s1 + side + down, s1 - side + down, s1 - side))
	st.generate_normals()
	return [st.commit(), faces]


## Четырёхугольник a-b-c-d (против часовой при взгляде с лицевой стороны) двумя треугольниками; возвращает
## их вершины (для коллизии). У Godot лицевая сторона — по часовой, поэтому вершины идут в обратном порядке.
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> PackedVector3Array:
	var tri := PackedVector3Array([a, c, b, a, d, c])
	for i in tri.size():
		st.add_vertex(tri[i])
	return tri


# ---------- Запросы ----------

func _cell(x: float, z: float) -> Vector2i:
	return Vector2i(clampi(int(roundf((x - origin.x) / step)), 0, nx - 1),
		clampi(int(roundf((z - origin.y) / step)), 0, nz - 1))


## Высота земли (билинейно).
func height_at(x: float, z: float) -> float:
	var u := (x - origin.x) / step
	var v := (z - origin.y) / step
	var i0 := clampi(int(floorf(u)), 0, nx - 1)
	var j0 := clampi(int(floorf(v)), 0, nz - 1)
	var i1 := mini(i0 + 1, nx - 1)
	var j1 := mini(j0 + 1, nz - 1)
	var fu := clampf(u - float(i0), 0.0, 1.0)
	var fv := clampf(v - float(j0), 0.0, 1.0)
	var a := lerpf(heights[_idx(i0, j0)], heights[_idx(i1, j0)], fu)
	var b := lerpf(heights[_idx(i0, j1)], heights[_idx(i1, j1)], fu)
	return lerpf(a, b, fv)


func is_walkable(x: float, z: float) -> bool:
	var c := _cell(x, z)
	return walk[_idx(c.x, c.y)] == 1


func road_distance(x: float, z: float) -> float:
	var c := _cell(x, z)
	return road_d[_idx(c.x, c.y)]


## Расстояние до реки или пруда, м (не больше FAR).
func water_distance(x: float, z: float) -> float:
	var c := _cell(x, z)
	return water_d[_idx(c.x, c.y)]


func in_safe_zone(pos: Vector3) -> bool:
	for z in cfg.get("safe_zones", []):
		var sz: Dictionary = z
		if Vector2(pos.x, pos.z).distance_to(v2(sz["center"])) < float(sz.get("radius", 10.0)):
			return true
	return false


## Лесная подстилка: по точкам деревьев (низ ствола) — сумма мягких пятен радиуса FOREST_RADIUS
## на сетке FOREST_STEP, сжатая в 0..1: одиночное дерево даёт пятно листвы у ствола, роща — сплошной
## покров. Вызывает IslandVegetation после расстановки деревьев, до меша рельефа.
func bake_forest(trees: Array[Vector3]) -> void:
	forest_nx = int(ceilf(float(nx - 1) * step / FOREST_STEP)) + 1
	forest_nz = int(ceilf(float(nz - 1) * step / FOREST_STEP)) + 1
	forest_w.resize(forest_nx * forest_nz)
	forest_w.fill(0.0)
	var cells := int(ceilf(FOREST_RADIUS / FOREST_STEP))
	for t in trees:
		var gi := roundi((t.x - origin.x) / FOREST_STEP)
		var gj := roundi((t.z - origin.y) / FOREST_STEP)
		for j in range(maxi(gj - cells, 0), mini(gj + cells, forest_nz - 1) + 1):
			for i in range(maxi(gi - cells, 0), mini(gi + cells, forest_nx - 1) + 1):
				var d := Vector2(origin.x + float(i) * FOREST_STEP - t.x, origin.y + float(j) * FOREST_STEP - t.z).length()
				if d < FOREST_RADIUS:
					forest_w[j * forest_nx + i] += 1.0 - smoothstep(1.2, FOREST_RADIUS, d)
	for k in forest_w.size():
		forest_w[k] = smoothstep(0.15, 1.1, forest_w[k])


## Вес леса в точке (билинейно, 0..1); до bake_forest — 0.
func forest_at(x: float, z: float) -> float:
	if forest_w.is_empty():
		return 0.0
	var u := clampf((x - origin.x) / FOREST_STEP, 0.0, float(forest_nx - 1))
	var v := clampf((z - origin.y) / FOREST_STEP, 0.0, float(forest_nz - 1))
	var i0 := int(floorf(u))
	var j0 := int(floorf(v))
	var i1 := mini(i0 + 1, forest_nx - 1)
	var j1 := mini(j0 + 1, forest_nz - 1)
	var fu := u - float(i0)
	var fv := v - float(j0)
	var a := lerpf(forest_w[j0 * forest_nx + i0], forest_w[j0 * forest_nx + i1], fu)
	var b := lerpf(forest_w[j1 * forest_nx + i0], forest_w[j1 * forest_nx + i1], fu)
	return lerpf(a, b, fv)


## Оттенок травы по зонам деревень: золотистый у светлых эльфов, холодный у тёмных, тёплый у людей.
func zone_tint_at(x: float, z: float) -> Color:
	if _tints.is_empty():
		var colors := {
			"light_elf_village": Color(0.58, 0.74, 0.34),
			"dark_elf_village": Color(0.36, 0.42, 0.38),
			"human_village": Color(0.5, 0.66, 0.3),
		}
		for p in cfg.get("pois", []):
			var poi: Dictionary = p
			var t := String(poi.get("type", ""))
			if colors.has(t):
				_tints.append([v2(poi["center"]), colors[t]])
	var c := Color(0.42, 0.68, 0.33)
	for e in _tints:
		var d := Vector2(x, z).distance_to(e[0])
		var w := 1.0 - smoothstep(18.0, 55.0, d)
		if w > 0.0:
			c = c.lerp(e[1], w)
	return c


func poi(id: String) -> Dictionary:
	for p in cfg.get("pois", []):
		var d: Dictionary = p
		if String(d.get("id", "")) == id:
			return d
	return {}


func pois_of_type(type: String) -> Array:
	var res := []
	for p in cfg.get("pois", []):
		var d: Dictionary = p
		if String(d.get("type", "")) == type:
			res.append(d)
	return res


## Точка в мире на поверхности земли.
func ground(x: float, z: float, lift: float = 0.1) -> Vector3:
	return Vector3(x, height_at(x, z) + lift, z)


## Точка старта расы (деревня расы).
func spawn_point(race: String) -> Vector3:
	var sp: Dictionary = cfg.get("spawn_points", {})
	var p = sp.get(race, sp.get("default", [0, 6]))
	var v := v2(p)
	return ground(v.x, v.y, 0.2)


## Слоты зверей по зонам конфига: [{"type", "pos", "level", "zone"}]. Точки — на проходимой
## суше, вне безопасных зон и не на дорогах.
func mob_slots(rng: RandomNumberGenerator) -> Array:
	var res := []
	for z in cfg.get("mob_zones", []):
		var zone: Dictionary = z
		var c := v2(zone["center"])
		var r := float(zone.get("radius", 10.0))
		var lv: Array = zone.get("levels", [1, 1])
		for m in zone.get("mobs", []):
			# [вид, сколько] или [вид, сколько, мин. ур., макс. ур.] — свои уровни вида внутри зоны
			var entry: Array = m
			var elv: Array = [entry[2], entry[3]] if entry.size() >= 4 else lv
			for n in int(entry[1]):
				var pos := Vector3.ZERO
				var found := false
				# Сначала в круге зоны; если там почти всё — вода или дорога, ищем шире (до 2.5 радиуса)
				for attempt in 100:
					var ang := rng.randf() * TAU
					var rr := sqrt(rng.randf()) * r * (1.0 if attempt < 40 else 2.5)
					var x := c.x + cos(ang) * rr
					var zz := c.y + sin(ang) * rr
					pos = ground(x, zz)
					if is_walkable(x, zz) and not in_safe_zone(pos) and road_distance(x, zz) > 2.5:
						found = true
						break
				if not found:
					pos = ground(c.x, c.y)
				res.append({
					"type": String(entry[0]), "pos": pos, "zone": String(zone.get("id", "")),
					"level": rng.randi_range(int(elv[0]), int(elv[1])),
				})
	return res


## Переходы (порт → материк): {"center": Vector2, "radius", "message"}.
func transitions() -> Array:
	return cfg.get("transitions", [])


## Не даёт телу зайти в непроходимую клетку (вода, крутой склон) и провалиться под землю.
## prev — позиция до move_and_slide.
static func constrain(body: Node3D, prev: Vector3) -> void:
	var w := current
	if w == null or not is_instance_valid(w):
		return
	var p := body.global_position
	if not w.is_walkable(p.x, p.z) and w.is_walkable(prev.x, prev.z):
		body.global_position = Vector3(prev.x, p.y, prev.z)
		p = body.global_position
	var h := w.height_at(p.x, p.z)
	if p.y < h - 0.6 and not w._on_bridge(p):
		body.global_position.y = h + 0.05


## Прямой путь от a до b по суше: все клетки на отрезке проходимы (шаг — полклетки сетки).
func segment_walkable(a: Vector3, b: Vector3) -> bool:
	var d := Vector2(b.x - a.x, b.z - a.z)
	var n := maxi(1, int(ceilf(d.length() / (step * 0.5))))
	for i in range(1, n + 1):
		var t := float(i) / float(n)
		if not is_walkable(a.x + d.x * t, a.z + d.y * t):
			return false
	return true


## Куда идти от from к to, если прямой путь упирается в воду (реку): через мост с наименьшим обходом.
## Не на мосту — к подходу ближнего конца (на дороге в BRIDGE_APPROACH м от настила), от подхода и на
## мосту — к сходу с дальнего конца. Vector3.INF — прямой путь свободен (или мостов нет).
func bridge_waypoint(from: Vector3, to: Vector3) -> Vector3:
	if bridges.is_empty() or segment_walkable(from, to):
		return Vector3.INF
	var best := Vector3.INF
	var best_cost := INF
	for br in bridges:
		var a: Vector3 = br["a"]
		var e: Vector3 = br["b"]
		var axis := Vector3(e.x - a.x, 0.0, e.z - a.z).normalized()
		var outs: Array[Vector3] = [a - axis * BRIDGE_APPROACH, e + axis * BRIDGE_APPROACH]
		var on := _near_bridge(br, from, 0.3)
		for k in 2:
			var near_in: Vector3 = outs[k]
			var far_out: Vector3 = outs[1 - k]
			var cost := 0.0
			var wp := far_out
			if on:
				# На мосту: к сходу с того конца, откуда ближе к цели
				cost = _flat_dist(from, far_out) + _flat_dist(far_out, to)
			else:
				var at_in := _flat_dist(from, near_in) < 1.2
				if not at_in and not segment_walkable(from, near_in):
					continue
				if not at_in:
					wp = near_in
				cost = _flat_dist(from, near_in) + _flat_dist(near_in, far_out) + _flat_dist(far_out, to)
			if not segment_walkable(far_out, to):
				cost += 60.0
			if cost < best_cost:
				best_cost = cost
				best = wp
	# Слишком далёкий обход (мост на другом краю острова) — не идём: застрявшего питомца перенесёт к хозяину
	if best_cost > _flat_dist(from, to) * 3.0 + 40.0:
		return Vector3.INF
	return best


## Путь существа (питомец, зверь) в обход реки: направление к цели напрямую или через мост
## (bridge_waypoint; путь пересчитывается раз в 0.25 с или когда цель сдвинулась больше чем на 1.5 м).
class Route:
	var waypoint := Vector3.INF
	var goal := Vector3.INF
	var timer := 0.0

	## Единичное направление по земле от from к to (ноль — уже на месте).
	func dir_to(from: Vector3, to: Vector3, delta: float) -> Vector3:
		var straight := Vector3(to.x - from.x, 0.0, to.z - from.z)
		straight = straight.normalized() if straight.length() > 0.001 else Vector3.ZERO
		timer -= delta
		if timer <= 0.0 or not goal.is_finite() or to.distance_to(goal) > 1.5:
			timer = 0.25
			goal = to
			waypoint = Vector3.INF
			var w := IslandWorld.current
			if w != null and is_instance_valid(w):
				waypoint = w.bridge_waypoint(from, to)
		if not waypoint.is_finite():
			return straight
		var d := Vector3(waypoint.x - from.x, 0.0, waypoint.z - from.z)
		if d.length() < 0.4:
			# Дошёл до точки обхода — следующую посчитать сразу
			timer = 0.0
			return straight
		return d.normalized()

	func reset() -> void:
		waypoint = Vector3.INF
		goal = Vector3.INF
		timer = 0.0


static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Точка над мостом br (в пределах ширины настила + margin, между концами).
func _near_bridge(br: Dictionary, p: Vector3, margin: float) -> bool:
	var a3: Vector3 = br["a"]
	var b3: Vector3 = br["b"]
	var a := Vector2(a3.x, a3.z)
	var ab := Vector2(b3.x, b3.z) - a
	var q := Vector2(p.x, p.z)
	var t := (q - a).dot(ab) / maxf(ab.length_squared(), 0.0001)
	if t < 0.0 or t > 1.0:
		return false
	return q.distance_to(a + ab * t) <= float(br["width"]) * 0.5 + margin


func _on_bridge(p: Vector3) -> bool:
	for b in bridges:
		var a3: Vector3 = b["a"]
		var b3: Vector3 = b["b"]
		var a := Vector2(a3.x, a3.z)
		var bb := Vector2(b3.x, b3.z)
		var q := Vector2(p.x, p.z)
		var ab := bb - a
		var t := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		if q.distance_to(a + ab * t) <= float(b["width"]) * 0.5 + 0.5:
			return true
	return false
