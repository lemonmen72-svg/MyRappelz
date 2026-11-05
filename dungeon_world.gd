class_name DungeonWorld
extends IslandWorld
## Подземелье за пещерой острова (0.35, папка Максима «ДАНЖ»): отдельная локация, остров при входе выгружается
## целиком (main.restart_scene с Game.location = "dungeon" — сцена строится заново только с подземельем).
## Тот же интерфейс, что у острова (IslandWorld): сетка высот и проходимости, коллизия, мосты (настил — bridges),
## зоны зверей и безопасные зоны, точки старта — поэтому герой, звери, питомцы, путь Кардинала (CardinalNav) и
## админ-панель работают без особых случаев. Конфиг — world/dungeon.json (карта Максима, 0.12 м на пиксель):
## залы (rooms) и коридоры (corridors) — пол, вода (water: канал, озеро, озёра у алтаря), палубы (decks) — острова
## пола своей высоты (корабль, площадки мостков), мосты (bridges), объекты (props — DungeonProps).
## Рельеф: пол на floor_y, вокруг пола и воды — скальный край высотой rim_h шириной rim_w (невысокий: камера
## от третьего лица смотрит сверху, как на карте), за краем — тёмная пустота (void_y). Край рваный (edge_noise).
## Свет — тёмный, изумрудный и фиолетовый: окружение без неба, слабый «лунный» свет сверху, свечение объектов.

const DUNGEON_CONFIG := "res://world/dungeon.json"
## Край пола: от границы пола вглубь скалы — подъём до rim_h за RIM_RISE м, дальше спуск в пустоту.
const RIM_RISE := 1.2
## Пол чуть неровный (шум), м.
const FLOOR_BUMP := 0.12
## Дно воды: от кромки до полной глубины, м.
const BANK := 2.0

## Знаковое расстояние до пола (< 0 — пол) и до воды (< 0 — вода) в узлах сетки; палуба узла (−1 — нет).
var floor_sd := PackedFloat32Array()
var water_sd := PackedFloat32Array()
var deck_of := PackedInt32Array()
var water_y := -0.45


func location() -> String:
	return "dungeon"


func build(rng: RandomNumberGenerator) -> void:
	var t0 := Time.get_ticks_msec()
	_load_dungeon_config()
	_init_dungeon_grid()
	_rasterize()
	var t1 := Time.get_ticks_msec()
	_dungeon_heights()
	_find_dungeon_bridges()
	_compute_walkable()
	_rim_unwalkable()
	_dungeon_environment()
	_build_collision()
	_build_bridges()
	var t2 := Time.get_ticks_msec()
	DungeonWater.build(self)
	DungeonProps.build(self, rng)
	var t3 := Time.get_ticks_msec()
	_build_dungeon_mesh()
	print("Подземелье: сетка %d мс, рельеф и мосты %d мс, вода и объекты %d мс, меш %d мс" % [t1 - t0, t2 - t1, t3 - t2,
		Time.get_ticks_msec() - t3])
	# Остров кладёт сюда следы построек и мелочей (жители, находки, путь Кардинала ищут их) — у подземелья пусто
	set_meta("poi_footprints", [])
	set_meta("poi_props", [])


func _load_dungeon_config() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(DUNGEON_CONFIG))
	if not (d is Dictionary):
		push_error("Не прочитан конфиг подземелья " + DUNGEON_CONFIG)
		d = {}
	cfg = d
	step = float(cfg.get("grid_step", 1.0))
	water_y = float(cfg.get("water_level", -0.45))
	# Моря нет: всё ниже этого — не вода (вода — water_level узла)
	sea_level = -100.0
	river_level = water_y
	_noise.seed = 31
	_noise.frequency = 0.09
	_noise.fractal_octaves = 2


func _init_dungeon_grid() -> void:
	var b: Array = cfg.get("bounds", [-90, -70, 90, 70])
	origin = Vector2(float(b[0]), float(b[1]))
	nx = int(ceilf((float(b[2]) - origin.x) / step)) + 1
	nz = int(ceilf((float(b[3]) - origin.y) / step)) + 1
	var n := nx * nz
	heights.resize(n)
	walk.resize(n)
	solid.resize(n)
	solid.fill(0)
	road_d.resize(n)
	road_d.fill(FAR)
	water_d.resize(n)
	water_d.fill(FAR)
	water_level.resize(n)
	water_level.fill(sea_level)
	_flat_w.resize(n)
	_flat_w.fill(0.0)
	_flat_h.resize(n)
	_flat_h.fill(0.0)
	floor_sd.resize(n)
	water_sd.resize(n)
	deck_of.resize(n)


# ---------- Формы ----------

## Знаковое расстояние от точки p до формы d (ellipse / path); < 0 — внутри.
static func shape_sd(d: Dictionary, p: Vector2) -> float:
	if String(d.get("shape", "path" if d.has("points") else "ellipse")) == "path":
		var pts: Array = d.get("points", [])
		var half := float(d.get("width", 4.0)) * 0.5
		var best := INF
		for i in range(pts.size() - 1):
			var a := v2(pts[i])
			var b := v2(pts[i + 1])
			var ab := b - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			best = minf(best, p.distance_to(a + ab * t))
		if pts.size() == 1:
			best = p.distance_to(v2(pts[0]))
		return best - half
	var c := v2(d.get("center", [0, 0]))
	var r: Array = d.get("radius", [5, 5])
	var rx := float(r[0])
	var rz := float(r[1])
	var q := (p - c).rotated(-deg_to_rad(float(d.get("rot", 0.0))))
	var k := Vector2(q.x / rx, q.y / rz).length()
	return (k - 1.0) * minf(rx, rz)


func _rasterize() -> void:
	var floors: Array = cfg.get("rooms", []) + cfg.get("corridors", [])
	var waters: Array = cfg.get("water", [])
	var decks: Array = cfg.get("decks", [])
	var amp := float(cfg.get("edge_noise", 1.0))
	for j in nz:
		for i in nx:
			var k := _idx(i, j)
			var p := _pos(i, j)
			# Рваный край пещеры: шум сдвигает границу пола и воды (сам пол внутри — без дыр)
			var wob := _noise.get_noise_2d(p.x, p.y) * amp
			var fs := INF
			for f in floors:
				fs = minf(fs, shape_sd(f, p))
			var ws := INF
			for w in waters:
				ws = minf(ws, shape_sd(w, p))
			var dk := -1
			for di in decks.size():
				if shape_sd(decks[di], p) < 0.0:
					dk = di
					break
			floor_sd[k] = fs + (wob if fs > -2.0 else 0.0)
			water_sd[k] = ws + (wob * 0.6 if ws > -2.0 else 0.0)
			deck_of[k] = dk


func _dungeon_heights() -> void:
	var fy := float(cfg.get("floor_y", 0.0))
	var rim_h := float(cfg.get("rim_h", 2.6))
	var rim_w := float(cfg.get("rim_w", 2.4))
	var void_y := float(cfg.get("void_y", -14.0))
	var bed := float(cfg.get("water_bed", -1.9))
	var decks: Array = cfg.get("decks", [])
	for j in nz:
		for i in nx:
			var k := _idx(i, j)
			var p := _pos(i, j)
			var fs := floor_sd[k]
			var ws := water_sd[k]
			var h: float
			if deck_of[k] >= 0:
				h = float((decks[deck_of[k]] as Dictionary).get("height", 0.3))
			elif fs <= 0.0:
				h = fy + _noise.get_noise_2d(p.x * 2.3 + 17.0, p.y * 2.3) * FLOOR_BUMP
			elif ws <= 0.0:
				# Дно: от кромки (уровень воды − 0.1) к глубине за BANK м
				h = lerpf(water_y - 0.15, bed, smoothstep(0.0, BANK, -ws))
			else:
				# Скальный край вокруг пола и воды, за ним пустота
				var d := minf(fs, ws)
				var top := fy + rim_h * (0.8 + 0.4 * (_noise.get_noise_2d(p.x * 0.7 + 50.0, p.y * 0.7) * 0.5 + 0.5))
				if d < RIM_RISE:
					h = lerpf(fy, top, smoothstep(0.0, RIM_RISE, d))
				elif d < rim_w:
					h = top
				else:
					h = lerpf(top, void_y, smoothstep(rim_w, rim_w + 2.5, d))
			heights[k] = h
			# Вода: узлы воды и кромка (меш воды и шейдер земли — мокрое дно)
			if ws < 1.5 and deck_of[k] < 0 and fs > 0.0:
				water_level[k] = water_y
				water_d[k] = maxf(0.0, ws + 1.5)


func _find_dungeon_bridges() -> void:
	bridges.clear()
	for b in cfg.get("bridges", []):
		var d: Dictionary = b
		var pa := v2(d["a"])
		var pb := v2(d["b"])
		var br := {
			"a": Vector3(pa.x, height_at(pa.x, pa.y), pa.y),
			"b": Vector3(pb.x, height_at(pb.x, pb.y), pb.y),
			"width": float(d.get("width", 3.2)),
		}
		br["deck"] = _deck_profile(br)
		# Над водой настил не ниже уровня воды + запас (концы — вровень с землёй)
		var deck: PackedFloat32Array = br["deck"]
		for i in range(1, deck.size() - 1):
			deck[i] = maxf(deck[i], water_y + 0.35)
		for _pass in 2:
			var sm := deck.duplicate()
			for i in range(1, deck.size() - 1):
				sm[i] = maxf(deck[i - 1] * 0.25 + deck[i] * 0.5 + deck[i + 1] * 0.25, water_y + 0.3)
			deck = sm
		br["deck"] = deck
		bridges.append(br)


## Плоский верх скального края и дно пустоты проходимы по уклону, но туда не попасть — закрыты (звери не встают
## на край). Мосты — над водой (там вода, не край), палубы — свои острова.
func _rim_unwalkable() -> void:
	for k in walk.size():
		if walk[k] == 1 and deck_of[k] < 0 and floor_sd[k] > 0.4 and water_sd[k] > 0.4:
			walk[k] = 0


# ---------- Окружение и меш ----------

func _dungeon_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.03, 0.05)
	# Тени сиренево-бирюзовые, освещённое — изумрудный и тёплый свет огней (свечение объектов)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.5, 0.62)
	env.ambient_light_energy = 0.62
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.12, 0.13)
	env.fog_light_energy = 1.0
	env.fog_density = 0.012
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# «Лунный» свет сверху: даёт объём и тени; основной цвет — от огней и рун
	var sun := DirectionalLight3D.new()
	sun.name = "DungeonLight"
	sun.rotation_degrees = Vector3(-62, -35, 0)
	sun.light_color = Color(0.62, 0.86, 0.8)
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)


func _build_dungeon_mesh() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://dungeon_terrain.gdshader")
	mat.set_shader_parameter("rich", Quality.rich_shaders())
	mat.set_shader_parameter("water_y", water_y)
	mat.set_shader_parameter("floor_y", float(cfg.get("floor_y", 0.0)))
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
			mi.mesh = _dungeon_chunk(ci, cj, mini(ci + CHUNK, nx - 1), mini(cj + CHUNK, nz - 1))
			if mi.mesh != null:
				mi.material_override = mat
				holder.add_child(mi)
			ci += CHUNK
		cj += CHUNK


## Участок рельефа: только узлы не глубже пустоты (пустота не рисуется — фон). Вершины: COLOR.r — зал (вид пола:
## 0 камень, 1 земля лагеря, 2 доски палуб), COLOR.g — вес «у воды»; UV — (расстояние до пола, до воды), м.
func _dungeon_chunk(i0: int, j0: int, i1: int, j1: int) -> ArrayMesh:
	var void_y := float(cfg.get("void_y", -14.0))
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var w := i1 - i0 + 1
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var p := _pos(i, j)
			var k := _idx(i, j)
			verts.append(Vector3(p.x, heights[k], p.y))
			normals.append(_normal(i, j))
			colors.append(Color(_floor_kind(p), 0.0, 0.0, 1.0))
			uvs.append(Vector2(floor_sd[k], water_sd[k]))
	for j in range(j1 - j0):
		for i in range(i1 - i0):
			var a := j * w + i
			var b := a + w
			# Квадрат целиком в пустоте — не рисуем
			if maxf(maxf(verts[a].y, verts[a + 1].y), maxf(verts[b].y, verts[b + 1].y)) <= void_y + 0.5:
				continue
			idx.append_array([a, a + 1, b, a + 1, b + 1, b])
	if idx.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## Вид пола в точке: 1 — утоптанная земля (лагерь гоблинов, шахта, сокровищница), 2 — доски (палубы), 0 — камень.
func _floor_kind(p: Vector2) -> float:
	var decks: Array = cfg.get("decks", [])
	for d in decks:
		if shape_sd(d, p) < 0.3:
			return 1.0
	for r in cfg.get("rooms", []):
		var room: Dictionary = r
		if ["goblin_camp", "mine", "treasury"].has(String(room.get("id", ""))) and shape_sd(room, p) < 2.0:
			return 0.5
	return 0.0


# ---------- Запросы ----------

func spawn_point(_race: String) -> Vector3:
	var sp: Dictionary = cfg.get("spawn_points", {})
	var v := v2(sp.get("default", [0, 0]))
	return ground(v.x, v.y, 0.2)


func transitions() -> Array:
	return []


## Портал обратно на остров: {"center": Vector2, "yaw": градусы, "to": "island"}.
func portal() -> Dictionary:
	var p: Dictionary = cfg.get("portal", {})
	return {"center": v2(p.get("center", [0, 0])), "yaw": float(p.get("yaw", 0.0)), "to": String(p.get("to", "island"))}


func zone_tint_at(_x: float, _z: float) -> Color:
	return Color(0.5, 0.5, 0.55)


func forest_at(_x: float, _z: float) -> float:
	return 0.0


## Зал, в котором точка (id из rooms; "" — коридор, вода, край).
func room_at(x: float, z: float) -> String:
	for r in cfg.get("rooms", []):
		var room: Dictionary = r
		if shape_sd(room, Vector2(x, z)) < 0.0:
			return String(room.get("id", ""))
	return ""
