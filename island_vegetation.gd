class_name IslandVegetation
extends RefCounted
## Растительность и камни тренировочного острова по зонам (настроение по брифу):
## - светлоэльфийская (северо-запад): светлые деревья с пышными золотисто-зелёными кронами,
##   светлые кусты и цветы, тёплый оттенок травы, редкие голубые кристаллы;
## - тёмноэльфийская (северо-восток): мёртвые кривые деревья (голые ветви, тёмная кора, кое-где
##   фиолетовая листва), колючие кусты, сухая трава, мало цветов, редкие фиолетовые кристаллы;
## - людская (юго-восток): сады (ряды фруктовых деревьев), кусты с ягодами, полевые цветы
##   (сами поля пшеницы ставит модуль построек);
## - центр и остальное: редкие рощи (круглые, хвойные, цветущие), кусты, камни, высокая трава, цветы;
## - юго-запад у пещеры и лагерей: больше камней и кустов, реже трава. У берега — валуны.
## Зоны смешиваются плавно (вес зоны по расстоянию до деревень и зон зверей из конфига).
## Под деревьями — лесная подстилка: по точкам деревьев IslandWorld.bake_forest запекает вес леса,
## меш рельефа строится после растительности и пишет его в UV2.x (island_terrain.gdshader).
##
## Ничего твёрдого не ставится на дороги, в воду, на непроходимые клетки (кроме прибрежных валунов),
## на площадки построек (_flat_w) и в безопасные зоны — там только трава и цветы.
##
## Производительность (GL Compatibility, мобильные):
## - трава и цветы — MultiMesh участками GRASS_CHUNK×GRASS_CHUNK, плотность и дальность из Quality;
##   вдали пучки плавно уходят в землю (шейдер), участки дальше дальности отсекаются visibility_range_end;
## - деревья, кусты, камни и кристаллы сливаются в один меш на участок DECOR_CHUNK×DECOR_CHUNK и группу
##   материала (7 общих материалов на весь остров); коллизия — цилиндры в одном StaticBody3D (слой 1).
## Модели из файлов (PropAsset, страница атласа «nature»: деревья tree_oak / tree_pine / tree_elf / tree_dead,
## куст bush, камни rock / rock_dark — модели Meshy от Максима) — свои группы G_PTREE и G_PSMALL (материал —
## атлас, prop.gdshader, контур по нормалям); нет файла — процедурные, как раньше. Колючие кусты тёмных земель,
## кристаллы — процедурные.
## Качество: apply_quality(tree) меняет дальность, тени и контуры мелочей без перезапуска;
## плотность травы и цветов задаётся при построении (смена — при следующем запуске).

# Зоны
const B_CENTER := 0
const B_LIGHT := 1
const B_DARK := 2
const B_HUMAN := 3
const B_ROCKY := 4
const BIOMES := 5
## Шаг сетки весов зон, м.
const BIO_STEP := 4.0
## Вес «обычной» зоны (центр) при смешивании.
const CENTER_W := 0.3

## Размер участка травы и цветов (MultiMesh), м.
const GRASS_CHUNK := 16.0
## Размер участка слитых мешей деревьев, кустов и камней, м.
const DECOR_CHUNK := 40.0
## Пучков травы на квадратный метр при плотности 1.0 (до множителей зон и шума).
const GRASS_PER_M2 := 1.25
## Шаги сеток расстановки, м.
const FLOWER_CELL := 6.0
const TREE_CELL := 4.5
const BUSH_CELL := 3.5
const ROCK_CELL := 5.0
const CRYSTAL_CELL := 9.0
const WIND_DIR := Vector2(0.86, 0.5)

# Виды деревьев
const T_ROUND := 0
const T_PINE := 1
const T_BLOSSOM := 2
const T_LIGHT := 3
const T_ORCHARD := 4
const T_DEAD := 5
const T_DEAD_PURPLE := 6
const TREE_KINDS := 7
const VARIANTS := 3
## Радиус ствола по видам (для коллизии), м при масштабе 1.
const TRUNK_R := [0.36, 0.3, 0.32, 0.34, 0.26, 0.3, 0.3]

# Группы слияния (у каждой свой общий материал)
const G_TREES := 0
const G_DEAD := 1
const G_BUSH := 2
const G_ROCK := 3
const G_GLOW := 4
## Модели из файлов (PropAsset): деревья и мелочи (кусты, камни).
const G_PTREE := 5
const G_PSMALL := 6
const GROUP_NAMES := ["veg_trees", "veg_trees", "veg_small", "veg_small", "veg_glow", "veg_trees", "veg_small"]
## Модель из файла для вида дерева (T_ROUND...) и её масштаб (сады — деревья поменьше).
const TREE_PROP := ["tree_oak", "tree_pine", "tree_elf", "tree_elf", "tree_oak", "tree_dead", "tree_dead"]
const TREE_PROP_SCALE := [1.0, 1.0, 0.95, 1.0, 0.72, 1.0, 0.92]

static var _outline_shader: Shader = null


## Состояние построения.
class Ctx:
	var w: IslandWorld
	var rng := RandomNumberGenerator.new()
	var noise := FastNoiseLite.new()
	var road_half := 1.6
	## Веса зон: BIOMES чисел на клетку сетки BIO_STEP (нормированы, сумма 1).
	var bio := PackedFloat32Array()
	var bio_nx := 0
	var bio_nz := 0
	var bio_origin := Vector2.ZERO
	## Запретные круги: [Vector2 центр, float радиус] (безопасные зоны, постройки, переходы).
	var blocked: Array = []
	## Vector3i(участок x, участок z, группа) -> [[Mesh, Transform3D], ...]
	var decor := {}
	## Vector3i(участок x, участок z, группа) -> id моделей из файлов в участке (для тестов: meta "props").
	var decor_ids := {}
	## Коллизии: [Vector3 основание, float радиус, float высота]
	var colliders: Array = []
	## Точки деревьев, кустов и камней (для проверок и тестов).
	var solids := PackedVector3Array()
	var trees: Array[Vector3] = []
	## Модели из файлов для проверки корней: [id модели, Transform3D] (тесты: meta "prop_bases").
	var bases: Array = []
	var stats := {"trees": 0, "bushes": 0, "rocks": 0, "crystals": 0, "grass": 0, "flowers": 0}


## Экземпляры одного участка MultiMesh: 12 чисел преобразования + 4 числа custom data.
class Bucket:
	var data := PackedFloat32Array()
	var count := 0
	var center := Vector3.ZERO

	func put(b: Basis, o: Vector3, custom: Color) -> void:
		var p := o - center
		data.append_array(PackedFloat32Array([
			b.x.x, b.y.x, b.z.x, p.x,
			b.x.y, b.y.y, b.z.y, p.y,
			b.x.z, b.y.z, b.z.z, p.z,
			custom.r, custom.g, custom.b, custom.a]))
		count += 1


static func build(world: IslandWorld, rng: RandomNumberGenerator) -> void:
	var t0 := Time.get_ticks_msec()
	var c := Ctx.new()
	c.w = world
	# Свой генератор от зерна мира: общий rng не расходуем (от него зависят слоты зверей)
	c.rng.seed = rng.seed + 7919
	c.noise.seed = int(rng.seed % 100000) + 17
	c.noise.frequency = 0.03
	c.road_half = float(world.cfg.get("roads", {}).get("width", 3.2)) * 0.5
	_build_biomes(c)
	_build_blocked(c)

	var holder := Node3D.new()
	holder.name = "Vegetation"
	holder.add_to_group("vegetation")
	world.add_child(holder)

	var mats := _materials()
	_place_trees(c, _tree_kits(c.rng))
	# Лесная подстилка на земле под деревьями (вес леса → UV2.x меша рельефа)
	world.bake_forest(c.trees)
	var bush_kits: Array = []
	var rock_kits: Array = []
	for b in BIOMES:
		bush_kits.append(_bush_kit(c.rng, b))
		rock_kits.append(_rock_kit(c.rng, b))
	_place_bushes(c, bush_kits)
	_place_rocks(c, rock_kits)
	_place_crystals(c)
	_build_decor(c, holder, mats)
	_build_colliders(c, holder)
	c.stats["grass"] = _build_grass(c, holder)
	c.stats["flowers"] = _build_flowers(c, holder)

	holder.set_meta("small_mats", [mats[G_BUSH], mats[G_ROCK], mats[G_PSMALL]])
	holder.set_meta("stats", c.stats)
	holder.set_meta("solid_points", c.solids)
	holder.set_meta("prop_bases", c.bases)
	holder.set_meta("built_grass", Quality.option("grass"))
	if world.is_inside_tree():
		apply_quality(world.get_tree())
	Quality.apply_lights(world)
	print("Растительность (трава «%s», %d мс): трава %d, цветы %d, деревья %d, кусты %d, камни %d, кристаллы %d" % [
		Quality.option_label("grass"), Time.get_ticks_msec() - t0, c.stats["grass"], c.stats["flowers"],
		c.stats["trees"], c.stats["bushes"], c.stats["rocks"], c.stats["crystals"]])


# ---------- Качество (без перезапуска) ----------

## Дальность участков, тени, контуры мелочей и затухание травы по текущему Quality.
static func apply_quality(tree: SceneTree) -> void:
	if tree == null:
		return
	var far := false
	var outlines := Quality.outlines()
	for h in tree.get_nodes_in_group("vegetation"):
		var holder := h as Node
		if holder == null:
			continue
		if bool(holder.get_meta("far_view", false)):
			far = true
		var small: Array = holder.get_meta("small_mats", [])
		for m in small:
			var sm := m as Material
			if sm == null or not sm.has_meta("outline"):
				continue
			if outlines:
				sm.next_pass = sm.get_meta("outline") as Material
			else:
				sm.next_pass = null

	var gd := Quality.grass_distance()
	var fd := gd * 0.85
	_set_range(tree, "veg_grass", 0.0 if far else gd + GRASS_CHUNK * 0.75)
	_set_range(tree, "veg_flowers", 0.0 if far else fd + GRASS_CHUNK * 0.75)
	_set_range(tree, "veg_trees", 0.0 if far else Quality.tree_distance() + DECOR_CHUNK * 0.7)
	_set_range(tree, "veg_small", 0.0 if far else Quality.detail_distance() + DECOR_CHUNK * 0.7)
	_set_range(tree, "veg_glow", 0.0 if far else Quality.detail_distance() + DECOR_CHUNK * 0.7)
	_set_fade(tree, "veg_grass", 1.0e5 if far else gd)
	_set_fade(tree, "veg_flowers", 1.0e5 if far else fd)

	var tree_sh := GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if Quality.shadows():
		tree_sh = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var small_sh := GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if Quality.small_shadows():
		small_sh = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for n in tree.get_nodes_in_group("veg_trees"):
		(n as GeometryInstance3D).cast_shadow = tree_sh
	for n in tree.get_nodes_in_group("veg_small"):
		(n as GeometryInstance3D).cast_shadow = small_sh


## Вид издалека (скриншот острова сверху): без ограничения дальности и затухания травы.
static func set_far_view(tree: SceneTree, on: bool) -> void:
	if tree == null:
		return
	for h in tree.get_nodes_in_group("vegetation"):
		(h as Node).set_meta("far_view", on)
	apply_quality(tree)


## Густота травы (Quality.option("grass")), с которой построена трава (-1 — растительности нет).
static func built_grass(tree: SceneTree) -> int:
	if tree == null:
		return -1
	for h in tree.get_nodes_in_group("vegetation"):
		return int((h as Node).get_meta("built_grass", -1))
	return -1


static func _set_range(tree: SceneTree, group: String, dist: float) -> void:
	for n in tree.get_nodes_in_group(group):
		var gi := n as GeometryInstance3D
		if gi == null:
			continue
		gi.visibility_range_end = dist
		gi.visibility_range_end_margin = 0.0 if dist <= 0.0 else 6.0


static func _set_fade(tree: SceneTree, group: String, end: float) -> void:
	var nodes := tree.get_nodes_in_group(group)
	if nodes.is_empty():
		return
	var gi := nodes[0] as GeometryInstance3D
	if gi == null:
		return
	var sm := gi.material_override as ShaderMaterial
	if sm == null:
		return
	sm.set_shader_parameter("fade_end", end)
	sm.set_shader_parameter("fade_start", end * 0.7)


# ---------- Зоны ----------

## Источники зон из конфига: деревни, поля, мельница, пещера, лагеря и зоны зверей.
static func _build_biomes(c: Ctx) -> void:
	var w := c.w
	var src: Array = []  # [зона, Vector2 центр, радиус]
	var poi_biome := {
		"light_elf_village": [B_LIGHT, 62.0], "dark_elf_village": [B_DARK, 64.0],
		"human_village": [B_HUMAN, 52.0], "wheat_field": [B_HUMAN, 28.0], "windmill": [B_HUMAN, 22.0],
		"sheep_pen": [B_HUMAN, 20.0], "cave": [B_ROCKY, 36.0],
	}
	for p in w.cfg.get("pois", []):
		var poi: Dictionary = p
		var t := String(poi.get("type", ""))
		var ctr := IslandWorld.v2(poi["center"])
		if poi_biome.has(t):
			var e: Array = poi_biome[t]
			src.append([int(e[0]), ctr, float(e[1])])
		elif t == "tent" and ctr.x < 0.0:
			src.append([B_ROCKY, ctr, 30.0])
	var zone_biome := {"elf_grove": B_LIGHT, "dead_grove": B_DARK, "south_fields": B_HUMAN,
		"west_camps": B_ROCKY, "cave": B_ROCKY}
	for z in w.cfg.get("mob_zones", []):
		var zone: Dictionary = z
		var id := String(zone.get("id", ""))
		if zone_biome.has(id):
			src.append([int(zone_biome[id]), IslandWorld.v2(zone["center"]), float(zone.get("radius", 15.0)) + 16.0])

	c.bio_origin = w.origin
	c.bio_nx = int(float(w.nx) * w.step / BIO_STEP) + 2
	c.bio_nz = int(float(w.nz) * w.step / BIO_STEP) + 2
	c.bio.resize(c.bio_nx * c.bio_nz * BIOMES)
	var ws := PackedFloat32Array()
	ws.resize(BIOMES)
	for j in c.bio_nz:
		for i in c.bio_nx:
			var p := c.bio_origin + Vector2(float(i), float(j)) * BIO_STEP
			ws.fill(0.0)
			ws[B_CENTER] = CENTER_W
			# Неровные границы зон
			var jitter := c.noise.get_noise_2d(p.x * 1.3 + 500.0, p.y * 1.3) * 8.0
			for s in src:
				var e: Array = s
				var b: int = e[0]
				var ctr: Vector2 = e[1]
				var r: float = e[2]
				var wt := 1.0 - smoothstep(r * 0.55, r, p.distance_to(ctr) + jitter)
				if wt > ws[b]:
					ws[b] = wt
			var sum := 0.0
			for b in BIOMES:
				ws[b] = ws[b] * ws[b]
				sum += ws[b]
			var k := (j * c.bio_nx + i) * BIOMES
			for b in BIOMES:
				c.bio[k + b] = ws[b] / sum


static func _bio_cell(c: Ctx, x: float, z: float) -> int:
	var i := clampi(int(roundf((x - c.bio_origin.x) / BIO_STEP)), 0, c.bio_nx - 1)
	var j := clampi(int(roundf((z - c.bio_origin.y) / BIO_STEP)), 0, c.bio_nz - 1)
	return (j * c.bio_nx + i) * BIOMES


## Вес зоны b в точке (0..1).
static func _bw(c: Ctx, x: float, z: float, b: int) -> float:
	return c.bio[_bio_cell(c, x, z) + b]


## Случайная зона по весам в точке: на границах зоны перемешиваются.
static func _pick_biome(c: Ctx, x: float, z: float) -> int:
	var k := _bio_cell(c, x, z)
	var r := c.rng.randf()
	for b in BIOMES:
		r -= c.bio[k + b]
		if r <= 0.0:
			return b
	return B_CENTER


# ---------- Где можно ставить ----------

static func _build_blocked(c: Ctx) -> void:
	for z in c.w.cfg.get("safe_zones", []):
		var sz: Dictionary = z
		c.blocked.append([IslandWorld.v2(sz["center"]), float(sz.get("radius", 10.0)) + 2.0])
	for p in c.w.cfg.get("pois", []):
		var poi: Dictionary = p
		var r := 6.0
		if poi.has("radius"):
			r = float(poi["radius"]) + 3.0
		elif poi.has("length"):
			r = float(poi["length"]) * 0.5 + 2.0
		elif poi.has("size"):
			var size: Array = poi["size"]
			r = maxf(float(size[0]), float(size[1])) * 0.5 + 2.0
		c.blocked.append([IslandWorld.v2(poi["center"]), r])
	for t in c.w.transitions():
		var tr: Dictionary = t
		c.blocked.append([IslandWorld.v2(tr["center"]), float(tr.get("radius", 3.0)) + 1.0])


## Можно ли поставить твёрдый предмет (дерево, куст, камень): суша, не дорога, не вода,
## не площадка постройки, не безопасная зона и не точка интереса.
## need_walk = false — допускаются крутые склоны (валуны на прибрежных скалах), но не вода.
static func _spot_ok(c: Ctx, x: float, z: float, road_gap: float, water_gap: float, need_walk: bool = true) -> bool:
	var w := c.w
	var cell := w._cell(x, z)
	var k := w._idx(cell.x, cell.y)
	if need_walk:
		if w.walk[k] == 0:
			return false
	else:
		var h := w.heights[k]
		if h < w.sea_level + 0.4 or h < w.water_level[k] + 0.3 or w.coast_distance(x, z) < 0.6:
			return false
	if w.road_d[k] < c.road_half + road_gap:
		return false
	if w.water_d[k] < water_gap:
		return false
	if w._flat_w[k] > 0.08:
		return false
	var p := Vector2(x, z)
	for b in c.blocked:
		var e: Array = b
		var ctr: Vector2 = e[0]
		var r: float = e[1]
		if p.distance_to(ctr) < r:
			return false
	return true


static func _decor_add(c: Ctx, group: int, mesh: Mesh, xf: Transform3D, prop_id: String = "") -> void:
	var key := Vector3i(floori(xf.origin.x / DECOR_CHUNK), floori(xf.origin.z / DECOR_CHUNK), group)
	if not c.decor.has(key):
		c.decor[key] = []
	(c.decor[key] as Array).append([mesh, xf])
	if prop_id != "":
		if not c.decor_ids.has(key):
			c.decor_ids[key] = []
		var ids: Array = c.decor_ids[key]
		if not ids.has(prop_id):
			ids.append(prop_id)


## Высота основания процедурной модели на склоне: наименьшая высота рельефа под следом (центр и по 8 точек
## на кругах r/2 и r) — низ не висит над склоном (на ровном месте — как высота в центре). Ни эта функция,
## ни _fit_base ГСЧ не расходуют: расстановка та же.
static func _base_y(w: IslandWorld, x: float, z: float, r: float) -> float:
	var y := w.height_at(x, z)
	for ring in 2:
		var rr := r * (0.5 + 0.5 * float(ring))
		for k in 8:
			var a := TAU * (float(k) + 0.5 * float(ring)) / 8.0
			y = minf(y, w.height_at(x + cos(a) * rr, z + sin(a) * rr))
	return y


## Высота основания модели из файла на склоне: каждая вершина основания (корни, низ камня или куста —
## PropAsset.base_points) не выше рельефа под ней (с запасом gap); на ровном месте — y0.
static func _fit_base(w: IslandWorld, pid: String, b: Basis, x: float, z: float, y0: float, gap: float) -> float:
	var y := y0
	var pts := PropAsset.base_points(pid)
	for i in pts.size():
		var p := b * pts[i]
		y = minf(y, w.height_at(x + p.x, z + p.z) - p.y - gap)
	return y


static func _yaw_scale(rng: RandomNumberGenerator, s: float) -> Basis:
	return Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(s, s, s))


# ---------- Деревья ----------

static func _place_trees(c: Ctx, kits: Array) -> void:
	var w := c.w
	var gx := int(float(w.nx - 1) * w.step / TREE_CELL)
	var gz := int(float(w.nz - 1) * w.step / TREE_CELL)
	for j in gz:
		for i in gx:
			var x := w.origin.x + (float(i) + 0.5 + c.rng.randf_range(-0.32, 0.32)) * TREE_CELL
			var z := w.origin.y + (float(j) + 0.5 + c.rng.randf_range(-0.32, 0.32)) * TREE_CELL
			if w.coast_distance(x, z) < 3.0:
				continue
			var b := _pick_biome(c, x, z)
			var n := c.noise.get_noise_2d(x, z)
			var prob := 0.0
			match b:
				B_LIGHT:
					prob = 0.5 * (0.3 + smoothstep(-0.25, 0.25, n))
				B_DARK:
					prob = 0.36 * (0.35 + smoothstep(-0.2, 0.3, n))
				B_HUMAN:
					prob = 0.035
				B_ROCKY:
					prob = 0.07
				_:
					prob = 0.02 + 0.3 * smoothstep(0.15, 0.45, n)
			if c.rng.randf() > prob:
				continue
			if not _spot_ok(c, x, z, 2.2, 3.0):
				continue
			_add_tree(c, kits, _tree_kind(c, b), x, z, c.rng.randf_range(0.85, 1.2))
	_place_orchards(c, kits)


static func _tree_kind(c: Ctx, b: int) -> int:
	var r := c.rng.randf()
	match b:
		B_LIGHT:
			return T_LIGHT if r < 0.78 else (T_ROUND if r < 0.92 else T_PINE)
		B_DARK:
			return T_DEAD if r < 0.66 else T_DEAD_PURPLE
		B_HUMAN:
			return T_ORCHARD if r < 0.5 else (T_ROUND if r < 0.8 else T_BLOSSOM)
		B_ROCKY:
			return T_PINE if r < 0.7 else T_ROUND
	return T_ROUND if r < 0.5 else (T_PINE if r < 0.85 else T_BLOSSOM)


static func _add_tree(c: Ctx, kits: Array, kind: int, x: float, z: float, s: float) -> void:
	var kit: Array = kits[kind]
	var mesh: Mesh = kit[c.rng.randi() % kit.size()]
	var pos := Vector3(x, c.w.height_at(x, z) - 0.12, z)
	var pid: String = TREE_PROP[kind]
	var tr: float = TRUNK_R[kind]
	if PropAsset.has(pid):
		var ps: float = TREE_PROP_SCALE[kind]
		# На склоне корни не висят: основание — по самой низкой точке рельефа под ними
		var tb := _yaw_scale(c.rng, s * ps)
		pos.y = _fit_base(c.w, pid, tb, x, z, pos.y, 0.03)
		var xf := Transform3D(tb, pos)
		_decor_add(c, G_PTREE, PropAsset.mesh(pid), xf, pid)
		c.bases.append([pid, xf])
	else:
		pos.y = minf(pos.y, _base_y(c.w, x, z, tr * s * 1.6) - 0.04)
		_decor_add(c, G_DEAD if kind >= T_DEAD else G_TREES, mesh, Transform3D(_yaw_scale(c.rng, s), pos))
	c.colliders.append([pos, tr * s, 3.0])
	c.trees.append(pos)
	c.solids.append(pos)
	c.stats["trees"] = int(c.stats["trees"]) + 1


## Сады у деревни людей: ряды фруктовых деревьев рядом с деревней (вне её площадки).
static func _place_orchards(c: Ctx, kits: Array) -> void:
	for p in c.w.pois_of_type("human_village"):
		var poi: Dictionary = p
		var ctr := IslandWorld.v2(poi["center"])
		var vr := float(poi.get("radius", 16.0))
		var made := 0
		for attempt in 12:
			if made >= 3:
				break
			var a := c.rng.randf() * TAU
			var o := ctr + Vector2(cos(a), sin(a)) * c.rng.randf_range(vr + 14.0, vr + 34.0)
			var rot := c.rng.randf() * PI
			var ax := Vector2(cos(rot), sin(rot))
			var az := Vector2(-ax.y, ax.x)
			var planted := 0
			for r in 3:
				for k in 4:
					var q := o + ax * (float(k) - 1.5) * 4.4 + az * (float(r) - 1.0) * 4.4
					q += Vector2(c.rng.randf_range(-0.4, 0.4), c.rng.randf_range(-0.4, 0.4))
					if not _spot_ok(c, q.x, q.y, 2.0, 3.0):
						continue
					if _near_tree(c, q, 2.6):
						continue
					_add_tree(c, kits, T_ORCHARD, q.x, q.y, c.rng.randf_range(0.9, 1.1))
					planted += 1
			if planted >= 5:
				made += 1


static func _near_tree(c: Ctx, q: Vector2, d: float) -> bool:
	for t in c.trees:
		if Vector2(t.x, t.z).distance_to(q) < d:
			return true
	return false


## Наборы мешей деревьев: [вид][вариант] -> ArrayMesh (ствол и крона в одном меше).
static func _tree_kits(rng: RandomNumberGenerator) -> Array:
	var kits: Array = []
	for kind in TREE_KINDS:
		var arr: Array = []
		for v in VARIANTS:
			arr.append(_make_tree(rng, kind, v))
		kits.append(arr)
	return kits


static func _make_tree(rng: RandomNumberGenerator, kind: int, v: int) -> Mesh:
	match kind:
		T_ROUND, T_BLOSSOM:
			var round_parts := WorldBuilder._make_round_tree(rng, kind == T_BLOSSOM)
			return _merge_parts(round_parts[0], round_parts[1], float(round_parts[2]))
		T_PINE:
			var pine_parts := WorldBuilder._make_pine(rng)
			return _merge_parts(pine_parts[0], pine_parts[1], float(pine_parts[2]))
		T_LIGHT:
			return _make_light_tree(rng, v == 1)
		T_ORCHARD:
			var fruits := [Color(0.92, 0.22, 0.2), Color(1.0, 0.6, 0.18), Color(0.98, 0.86, 0.3)]
			return _make_orchard_tree(rng, fruits[v % fruits.size()])
		T_DEAD:
			return _make_dead_tree(rng, false)
	return _make_dead_tree(rng, true)


## Ствол и крона (отдельные меши WorldBuilder) в один меш.
static func _merge_parts(trunk: Mesh, crown: Mesh, crown_y: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(trunk, 0, Transform3D.IDENTITY)
	st.append_from(crown, 0, Transform3D(Basis.IDENTITY, Vector3(0, crown_y, 0)))
	return st.commit()


## Базис, у которого ось Y смотрит вдоль d.
static func _basis_y(d: Vector3) -> Basis:
	var y := d.normalized()
	var ref := Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.FORWARD
	var z := ref.cross(y).normalized()
	var x := y.cross(z).normalized()
	return Basis(x, y, z)


## Светлое эльфийское дерево: высокий светлый ствол, пышная золотисто-зелёная крона.
static func _make_light_tree(rng: RandomNumberGenerator, golden: bool) -> ArrayMesh:
	var acc := WorldBuilder.MeshAcc.new()
	var th := rng.randf_range(2.5, 3.2)
	var bark_bot := Color(0.58, 0.52, 0.46)
	var bark_top := Color(0.9, 0.86, 0.76)
	WorldBuilder._cone(acc, Transform3D.IDENTITY, 8, 0.48, 0.3, 0.4, bark_bot, bark_top, 0.0, th)
	WorldBuilder._cone(acc, Transform3D(Basis.IDENTITY, Vector3(0, 0.35, 0)), 8, 0.3, 0.15, th + 0.6,
		bark_bot, bark_top, 0.0, th)
	for b in 3:
		var bb := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3(0, 0, 1), deg_to_rad(rng.randf_range(30.0, 48.0)))
		WorldBuilder._cone(acc, Transform3D(bb, Vector3(0, th * rng.randf_range(0.55, 0.8), 0)), 6, 0.1, 0.04, 1.2,
			bark_top, bark_top, 0.0, 1.0)
	var big_r := rng.randf_range(1.6, 1.95)
	var cy := th + big_r * 0.55
	var top := Color(0.93, 0.9, 0.48) if golden else Color(0.74, 0.87, 0.4)
	var bot := Color(0.5, 0.5, 0.2) if golden else Color(0.24, 0.5, 0.28)
	var alt_top := Color(1.0, 0.84, 0.42)
	var alt_bot := Color(0.62, 0.5, 0.2)
	var blobs: Array = [[Vector3.ZERO, big_r]]
	var n := 6
	var a0 := rng.randf() * TAU
	for k in n:
		var a := a0 + float(k) * TAU / float(n) + rng.randf_range(-0.3, 0.3)
		blobs.append([Vector3(cos(a) * big_r * 0.8, rng.randf_range(-0.35, 0.3) * big_r, sin(a) * big_r * 0.8),
			big_r * rng.randf_range(0.55, 0.72)])
	blobs.append([Vector3(rng.randf_range(-0.2, 0.2) * big_r, big_r * 0.8, rng.randf_range(-0.2, 0.2) * big_r), big_r * 0.68])
	blobs.append([Vector3(rng.randf_range(-0.15, 0.15) * big_r, big_r * 1.35, rng.randf_range(-0.15, 0.15) * big_r), big_r * 0.45])
	for idx in blobs.size():
		var blob: Array = blobs[idx]
		var bc: Vector3 = blob[0]
		var rad: float = blob[1]
		var k := rng.randf_range(0.93, 1.03)
		var t := top
		var bt := bot
		if idx > 0 and rng.randf() < 0.25:
			t = alt_top
			bt = alt_bot
		var xf := Transform3D(Basis.from_scale(Vector3(rad, rad * 0.9, rad)), bc + Vector3(0, cy, 0))
		WorldBuilder._sphere(acc, xf, 9, 5, WorldBuilder._shade(bt, k), WorldBuilder._shade(t, k), cy - big_r, cy + big_r * 1.6)
	return acc.to_mesh()


## Садовое (фруктовое) дерево: короткий ствол, круглая крона с плодами.
static func _make_orchard_tree(rng: RandomNumberGenerator, fruit: Color) -> ArrayMesh:
	var acc := WorldBuilder.MeshAcc.new()
	var th := rng.randf_range(1.3, 1.6)
	var bark_bot := Color(0.36, 0.24, 0.16)
	var bark_top := Color(0.58, 0.4, 0.26)
	WorldBuilder._cone(acc, Transform3D.IDENTITY, 7, 0.3, 0.2, 0.3, bark_bot, bark_top, 0.0, th)
	WorldBuilder._cone(acc, Transform3D(Basis.IDENTITY, Vector3(0, 0.25, 0)), 7, 0.2, 0.12, th + 0.3,
		bark_bot, bark_top, 0.0, th)
	for b in 2:
		var bb := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3(0, 0, 1), deg_to_rad(rng.randf_range(35.0, 50.0)))
		WorldBuilder._cone(acc, Transform3D(bb, Vector3(0, th * 0.7, 0)), 5, 0.08, 0.03, 0.8, bark_top, bark_top, 0.0, 1.0)
	var big_r := rng.randf_range(1.05, 1.25)
	var cy := th + big_r * 0.55
	var top := Color(0.56, 0.8, 0.32)
	var bot := Color(0.2, 0.46, 0.25)
	var blobs: Array = [[Vector3.ZERO, big_r]]
	var a0 := rng.randf() * TAU
	for k in 4:
		var a := a0 + float(k) * TAU / 4.0 + rng.randf_range(-0.3, 0.3)
		blobs.append([Vector3(cos(a) * big_r * 0.75, rng.randf_range(-0.3, 0.2) * big_r, sin(a) * big_r * 0.75),
			big_r * rng.randf_range(0.58, 0.72)])
	for blob in blobs:
		var bl: Array = blob
		var bc: Vector3 = bl[0]
		var rad: float = bl[1]
		var k := rng.randf_range(0.93, 1.02)
		WorldBuilder._sphere(acc, Transform3D(Basis.from_scale(Vector3(rad, rad * 0.88, rad)), bc + Vector3(0, cy, 0)),
			9, 5, WorldBuilder._shade(bot, k), WorldBuilder._shade(top, k), cy - big_r, cy + big_r * 1.1)
	var light := fruit.lerp(Color.WHITE, 0.3)
	for f in rng.randi_range(10, 15):
		var bl: Array = blobs[rng.randi() % blobs.size()]
		var bc: Vector3 = bl[0]
		var rad: float = bl[1]
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.2, 0.9), rng.randf_range(-1, 1)).normalized()
		var p := bc + Vector3(dir.x * rad, dir.y * rad * 0.88, dir.z * rad) * 0.96 + Vector3(0, cy, 0)
		WorldBuilder._sphere(acc, Transform3D(Basis.from_scale(Vector3.ONE * 0.09), p), 5, 3, fruit, light, p.y - 0.09, p.y + 0.09)
	return acc.to_mesh()


## Мёртвое кривое дерево: тёмная кора, голые ветви; purple — кое-где фиолетовая листва.
static func _make_dead_tree(rng: RandomNumberGenerator, purple: bool) -> ArrayMesh:
	var acc := WorldBuilder.MeshAcc.new()
	var bot := Color(0.15, 0.11, 0.15)
	var top := Color(0.36, 0.28, 0.33)
	var h := rng.randf_range(3.4, 4.4)
	var tips: Array[Vector3] = []
	WorldBuilder._cone(acc, Transform3D.IDENTITY, 7, 0.52, 0.3, 0.45, bot, bot, 0.0, h)
	# Корни
	for k in 3:
		var a := rng.randf() * TAU * 0.3 + float(k) * TAU / 3.0
		var d := Vector3(cos(a), -0.35, sin(a)).normalized()
		WorldBuilder._cone(acc, Transform3D(_basis_y(d), Vector3(0, 0.25, 0)), 5, 0.14, 0.03, 0.8, bot, bot, 0.0, h)
	var lean := Vector3(rng.randf_range(-0.2, 0.2), 1.0, rng.randf_range(-0.2, 0.2)).normalized()
	_dead_branch(acc, rng, Vector3(0, 0.35, 0), lean, h, 0.3, 2, bot, top, h, tips)
	if purple:
		var pb := Color(0.34, 0.14, 0.46)
		var pt := Color(0.74, 0.46, 0.92)
		for p in tips:
			if rng.randf() < 0.75:
				var r := rng.randf_range(0.32, 0.5)
				WorldBuilder._sphere(acc, Transform3D(Basis.from_scale(Vector3(r, r * 0.75, r)), p), 7, 4, pb, pt, p.y - r, p.y + r)
	return acc.to_mesh()


## Кривая ветвь из нескольких сужающихся конусов; depth > 0 — с боковыми ветвями.
static func _dead_branch(acc: WorldBuilder.MeshAcc, rng: RandomNumberGenerator, start: Vector3, dir: Vector3,
		length: float, radius: float, depth: int, bot: Color, top: Color, h: float, tips: Array[Vector3]) -> void:
	var segs := 3 if depth >= 2 else 2
	var p := start
	var d := dir
	var r := radius
	var seg_len := length / float(segs)
	for s in segs:
		var r2 := r * 0.74
		WorldBuilder._cone(acc, Transform3D(_basis_y(d), p), 6 if depth >= 2 else 5, r, r2, seg_len * 1.04, bot, top, 0.0, h)
		p += d * seg_len
		r = r2
		d = (d + Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.05, 0.3), rng.randf_range(-0.5, 0.5)) * 0.6).normalized()
		if d.y < 0.1:
			d = (d + Vector3(0, 0.3, 0)).normalized()
	if depth <= 0:
		tips.append(p)
		return
	var n := rng.randi_range(2, 3)
	var a0 := rng.randf() * TAU
	for b in n:
		var a := a0 + TAU * float(b) / float(n) + rng.randf_range(-0.5, 0.5)
		var out := Vector3(cos(a), 0.0, sin(a))
		var nd := (d * rng.randf_range(0.5, 0.9) + out * rng.randf_range(0.7, 1.2)).normalized()
		var fork := p - d * seg_len * rng.randf_range(0.0, 0.5)
		_dead_branch(acc, rng, fork, nd, length * rng.randf_range(0.48, 0.62), r * 0.95, depth - 1, bot, top, h, tips)
	tips.append(p)


# ---------- Кусты ----------

static func _place_bushes(c: Ctx, kits: Array) -> void:
	var w := c.w
	var spots: Array[Vector2] = []
	var gx := int(float(w.nx - 1) * w.step / BUSH_CELL)
	var gz := int(float(w.nz - 1) * w.step / BUSH_CELL)
	for j in gz:
		for i in gx:
			spots.append(Vector2(w.origin.x + (float(i) + c.rng.randf()) * BUSH_CELL,
				w.origin.y + (float(j) + c.rng.randf()) * BUSH_CELL))
	# У стволов деревьев — чаще
	var near_tree: Array[Vector2] = []
	for t in c.trees:
		if c.rng.randf() < 0.25:
			var a := c.rng.randf() * TAU
			near_tree.append(Vector2(t.x, t.z) + Vector2(cos(a), sin(a)) * c.rng.randf_range(1.6, 2.6))
	var probs := [0.04, 0.07, 0.06, 0.05, 0.15]
	for idx in spots.size() + near_tree.size():
		var q: Vector2
		var forced := idx >= spots.size()
		if forced:
			q = near_tree[idx - spots.size()]
		else:
			q = spots[idx]
		var b := _pick_biome(c, q.x, q.y)
		var pr: float = probs[b]
		if not forced and c.rng.randf() > pr:
			continue
		if not _spot_ok(c, q.x, q.y, 1.0, 2.0):
			continue
		var kit: Array = kits[b]
		var mesh: Mesh = kit[c.rng.randi() % kit.size()]
		var pos := Vector3(q.x, c.w.height_at(q.x, q.y) - 0.05, q.y)
		var bs := c.rng.randf_range(0.75, 1.3)
		if b != B_DARK and PropAsset.has("bush"):
			# Куст из файла (1.6 м) чуть мельче процедурного; колючие тёмных земель — процедурные
			var bb := _yaw_scale(c.rng, bs * 0.85)
			pos.y = _fit_base(c.w, "bush", bb, q.x, q.y, pos.y, 0.03)
			var xf := Transform3D(bb, pos)
			_decor_add(c, G_PSMALL, PropAsset.mesh("bush"), xf, "bush")
			c.bases.append(["bush", xf])
		else:
			pos.y = minf(pos.y, _base_y(c.w, q.x, q.y, 0.6 * bs) - 0.03)
			_decor_add(c, G_BUSH, mesh, Transform3D(_yaw_scale(c.rng, bs), pos))
		c.solids.append(pos)
		c.stats["bushes"] = int(c.stats["bushes"]) + 1


## Варианты кустов зоны: центр — зелёные с цветками, светлые — золотистые с белыми цветками,
## тёмные — колючие, людские — с ягодами, юго-запад — суховатые.
static func _bush_kit(rng: RandomNumberGenerator, b: int) -> Array:
	var kit: Array = []
	for v in VARIANTS:
		match b:
			B_LIGHT:
				kit.append(_make_bush(rng, Color(0.86, 0.86, 0.45), Color(0.36, 0.54, 0.26),
					[Color(0.98, 0.97, 0.94), Color(0.72, 0.86, 1.0)], 0.7))
			B_DARK:
				kit.append(_make_thorn_bush(rng))
			B_HUMAN:
				kit.append(_make_bush(rng, Color(0.48, 0.74, 0.3), Color(0.16, 0.4, 0.24),
					[Color(0.88, 0.16, 0.2), Color(0.32, 0.28, 0.78), Color(0.98, 0.97, 0.94)], 0.85))
			B_ROCKY:
				kit.append(_make_bush(rng, Color(0.56, 0.68, 0.34), Color(0.24, 0.38, 0.22), [], 0.0))
			_:
				kit.append(_make_bush(rng, Color(0.5, 0.77, 0.32), Color(0.17, 0.43, 0.28),
					[Color(0.98, 0.97, 0.94), Color(1.0, 0.58, 0.74), Color(1.0, 0.84, 0.3)], 0.55))
	return kit


static func _make_bush(rng: RandomNumberGenerator, top: Color, bot: Color, dots: Array, dot_chance: float) -> ArrayMesh:
	var acc := WorldBuilder.MeshAcc.new()
	var blobs: Array = []
	for k in rng.randi_range(2, 4):
		var r := rng.randf_range(0.42, 0.66)
		var ctr := Vector3(0, r * 0.6, 0)
		if k > 0:
			ctr = Vector3(rng.randf_range(-0.45, 0.45), r * 0.55, rng.randf_range(-0.45, 0.45))
		blobs.append([ctr, r])
		WorldBuilder._sphere(acc, Transform3D(Basis.from_scale(Vector3(r, r * 0.8, r)), ctr), 8, 5, bot, top, 0.0, 1.1)
	if not dots.is_empty() and rng.randf() < dot_chance:
		var fc: Color = dots[rng.randi() % dots.size()]
		for k in rng.randi_range(5, 9):
			var blob: Array = blobs[rng.randi() % blobs.size()]
			var bc: Vector3 = blob[0]
			var r: float = blob[1]
			var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.3, 1.0), rng.randf_range(-1, 1)).normalized()
			var p := bc + Vector3(dir.x * r, dir.y * r * 0.8, dir.z * r) * 0.97
			WorldBuilder._sphere(acc, Transform3D(Basis.from_scale(Vector3.ONE * 0.08), p), 5, 3, fc, fc, 0.0, 1.0)
	return acc.to_mesh()


## Колючий сухой куст тёмных земель: тёмное основание, шипы-ветки, редкие фиолетовые ягоды.
static func _make_thorn_bush(rng: RandomNumberGenerator) -> ArrayMesh:
	var acc := WorldBuilder.MeshAcc.new()
	var bot := Color(0.16, 0.12, 0.16)
	var top := Color(0.44, 0.34, 0.4)
	var r := rng.randf_range(0.3, 0.4)
	WorldBuilder._sphere(acc, Transform3D(Basis.from_scale(Vector3(r, r * 0.7, r)), Vector3(0, r * 0.4, 0)), 7, 4,
		bot, Color(0.3, 0.24, 0.28), 0.0, 0.6)
	var ends: Array[Vector3] = []
	for k in rng.randi_range(9, 13):
		var a := rng.randf() * TAU
		var d := Vector3(cos(a) * rng.randf_range(0.3, 0.9), rng.randf_range(0.5, 1.0), sin(a) * rng.randf_range(0.3, 0.9)).normalized()
		var spike := rng.randf_range(0.6, 1.1)
		WorldBuilder._cone(acc, Transform3D(_basis_y(d), Vector3(0, 0.2, 0)), 4, 0.05, 0.0, spike, bot, top, 0.0, 1.0)
		ends.append(Vector3(0, 0.2, 0) + d * spike * 0.6)
	var berry := Color(0.62, 0.3, 0.86)
	for k in rng.randi_range(0, 5):
		var p: Vector3 = ends[rng.randi() % ends.size()]
		WorldBuilder._sphere(acc, Transform3D(Basis.from_scale(Vector3.ONE * 0.06), p), 5, 3, berry, berry, 0.0, 1.0)
	return acc.to_mesh()


# ---------- Камни ----------

static func _place_rocks(c: Ctx, kits: Array) -> void:
	var w := c.w
	var probs := [0.04, 0.035, 0.12, 0.03, 0.32]
	var gx := int(float(w.nx - 1) * w.step / ROCK_CELL)
	var gz := int(float(w.nz - 1) * w.step / ROCK_CELL)
	for j in gz:
		for i in gx:
			var x := w.origin.x + (float(i) + c.rng.randf()) * ROCK_CELL
			var z := w.origin.y + (float(j) + c.rng.randf()) * ROCK_CELL
			var cd := w.coast_distance(x, z)
			if cd < 0.6:
				continue
			var b := _pick_biome(c, x, z)
			var pr: float = probs[b]
			var coast := 1.0 - smoothstep(2.0, 7.0, cd)
			pr += 0.3 * coast
			if c.rng.randf() > pr:
				continue
			if not _spot_ok(c, x, z, 0.6, 1.2, cd > 7.0):
				continue
			var big := (b == B_ROCKY or coast > 0.3) and c.rng.randf() < 0.3
			var s := c.rng.randf_range(1.2, 2.3) if big else c.rng.randf_range(0.35, 1.0)
			_add_rock(c, kits, b, x, z, s)
	# Камешки по краям дорог
	var step := 2.5
	gx = int(float(w.nx - 1) * w.step / step)
	gz = int(float(w.nz - 1) * w.step / step)
	for j in gz:
		for i in gx:
			var x := w.origin.x + (float(i) + c.rng.randf()) * step
			var z := w.origin.y + (float(j) + c.rng.randf()) * step
			var rd := w.road_distance(x, z)
			if rd < c.road_half + 0.4 or rd > c.road_half + 1.6:
				continue
			if c.rng.randf() > 0.06:
				continue
			if not _spot_ok(c, x, z, 0.4, 1.2):
				continue
			_add_rock(c, kits, _pick_biome(c, x, z), x, z, c.rng.randf_range(0.18, 0.4))


static func _add_rock(c: Ctx, kits: Array, b: int, x: float, z: float, s: float) -> void:
	var kit: Array = kits[b]
	var mesh: Mesh = kit[c.rng.randi() % kit.size()]
	var pos := Vector3(x, c.w.height_at(x, z) - 0.12 * s, z)
	var pid := "rock_dark" if b == B_DARK else "rock"
	# Камешки у дорог (мельче 0.5) — процедурные: модель из файла для них слишком подробная
	if s >= 0.5 and PropAsset.has(pid):
		# Камень из файла: ниже и шире (как процедурный — валун, вросший в землю)
		var rb := Basis(Vector3.UP, c.rng.randf() * TAU) * Basis.from_scale(Vector3(s, s * 0.75, s))
		pos.y = _fit_base(c.w, pid, rb, x, z, pos.y, 0.03)
		_decor_add(c, G_PSMALL, PropAsset.mesh(pid), Transform3D(rb, pos), pid)
		c.bases.append([pid, Transform3D(rb, pos)])
	else:
		pos.y = minf(pos.y, _base_y(c.w, x, z, 0.7 * s) - 0.03)
		_decor_add(c, G_ROCK, mesh, Transform3D(_yaw_scale(c.rng, s), pos))
	if s > 1.1 and c.w.is_walkable(x, z):
		c.colliders.append([pos, 0.85 * s, 1.0 * s])
	c.solids.append(pos)
	c.stats["rocks"] = int(c.stats["rocks"]) + 1


## Варианты камней зоны: светлые у светлых эльфов, тёмные с лиловым лишайником у тёмных.
static func _rock_kit(rng: RandomNumberGenerator, b: int) -> Array:
	var stone := Color(0.6, 0.61, 0.64)
	var moss := Color(0.44, 0.62, 0.3)
	match b:
		B_LIGHT:
			stone = Color(0.76, 0.75, 0.72)
			moss = Color(0.62, 0.74, 0.36)
		B_DARK:
			stone = Color(0.38, 0.35, 0.42)
			moss = Color(0.46, 0.32, 0.56)
		B_HUMAN:
			stone = Color(0.65, 0.61, 0.56)
			moss = Color(0.48, 0.64, 0.3)
		B_ROCKY:
			stone = Color(0.57, 0.57, 0.59)
			moss = Color(0.46, 0.58, 0.3)
	var kit: Array = []
	for v in VARIANTS:
		kit.append(_make_rock(rng, stone, moss, v > 0))
	return kit


## Низкополигональный камень (как в WorldBuilder, но с цветами зоны).
static func _make_rock(rng: RandomNumberGenerator, stone: Color, moss: Color, mossy: bool) -> ArrayMesh:
	var acc := WorldBuilder.MeshAcc.new()
	var seg := 7
	var rings := 4
	var sc := Vector3(rng.randf_range(0.9, 1.3), rng.randf_range(0.55, 0.85), rng.randf_range(0.8, 1.1))
	var rows: Array = []
	for j in rings + 1:
		var phi := PI * float(j) / float(rings)
		var row := PackedVector3Array()
		var pole_k := rng.randf_range(0.85, 1.1)
		for i in seg:
			var th := TAU * float(i) / float(seg) + (0.25 if j % 2 == 1 else 0.0)
			var k := pole_k if (j == 0 or j == rings) else rng.randf_range(0.82, 1.12)
			var p := Vector3(sin(phi) * cos(th) * sc.x * k, cos(phi) * sc.y * k, sin(phi) * sin(th) * sc.z * k)
			p.y = maxf(p.y, -0.15)
			row.append(p)
		rows.append(row)
	for j in rings:
		var ra: PackedVector3Array = rows[j]
		var rb: PackedVector3Array = rows[j + 1]
		for i in seg:
			var i2 := (i + 1) % seg
			var tris: Array = []
			if j > 0:
				tris.append([ra[i], rb[i], ra[i2]])
			if j < rings - 1:
				tris.append([ra[i2], rb[i], rb[i2]])
			for t in tris:
				var p0: Vector3 = t[0]
				var p1: Vector3 = t[1]
				var p2: Vector3 = t[2]
				var n := (p2 - p0).cross(p1 - p0).normalized()
				var col := WorldBuilder._shade(stone, rng.randf_range(0.9, 1.05))
				if mossy and n.y > 0.55:
					col = WorldBuilder._shade(moss, rng.randf_range(0.92, 1.05))
				elif n.y < -0.2:
					col = WorldBuilder._shade(stone, 0.75)
				WorldBuilder._flat_tri(acc, p0, p1, p2, col)
	return acc.to_mesh()


# ---------- Кристаллы (редкий светящийся декор в диких местах эльфийских земель) ----------

static func _place_crystals(c: Ctx) -> void:
	var w := c.w
	var purple: Array = []
	var blue: Array = []
	for v in 2:
		purple.append(_make_crystals(c.rng, Color(0.72, 0.4, 1.0)))
		blue.append(_make_crystals(c.rng, Color(0.55, 0.82, 1.0)))
	var gx := int(float(w.nx - 1) * w.step / CRYSTAL_CELL)
	var gz := int(float(w.nz - 1) * w.step / CRYSTAL_CELL)
	for j in gz:
		for i in gx:
			var x := w.origin.x + (float(i) + c.rng.randf()) * CRYSTAL_CELL
			var z := w.origin.y + (float(j) + c.rng.randf()) * CRYSTAL_CELL
			var wd := _bw(c, x, z, B_DARK)
			var wl := _bw(c, x, z, B_LIGHT)
			var kit: Array
			if wd > 0.6 and c.rng.randf() < 0.14:
				kit = purple
			elif wl > 0.6 and c.rng.randf() < 0.06:
				kit = blue
			else:
				continue
			if not _spot_ok(c, x, z, 1.5, 2.0):
				continue
			var mesh: Mesh = kit[c.rng.randi() % kit.size()]
			var pos := Vector3(x, w.height_at(x, z) - 0.05, z)
			_decor_add(c, G_GLOW, mesh, Transform3D(_yaw_scale(c.rng, c.rng.randf_range(0.7, 1.2)), pos))
			c.solids.append(pos)
			c.stats["crystals"] = int(c.stats["crystals"]) + 1


## Друза из 3–5 шестигранных кристаллов с острыми вершинами (плоские грани, светлее к вершине).
static func _make_crystals(rng: RandomNumberGenerator, base: Color) -> ArrayMesh:
	var acc := WorldBuilder.MeshAcc.new()
	var seg := 6
	for k in rng.randi_range(3, 5):
		var tilt := 0.0 if k == 0 else rng.randf_range(0.25, 0.6)
		var ang := rng.randf() * TAU
		var dir := Vector3(sin(tilt) * cos(ang), cos(tilt), sin(tilt) * sin(ang))
		var off := Vector3.ZERO if k == 0 else Vector3(cos(ang), 0, sin(ang)) * rng.randf_range(0.12, 0.3)
		var h := rng.randf_range(0.9, 1.5) if k == 0 else rng.randf_range(0.4, 0.9)
		var r := h * rng.randf_range(0.14, 0.2)
		var xf := Transform3D(_basis_y(dir), off + Vector3(0, -0.1, 0))
		var bot_ring: Array[Vector3] = []
		var top_ring: Array[Vector3] = []
		for i in seg:
			var th := TAU * float(i) / float(seg)
			bot_ring.append(xf * Vector3(cos(th) * r * 0.8, 0.0, sin(th) * r * 0.8))
			top_ring.append(xf * Vector3(cos(th) * r, h * 0.72, sin(th) * r))
		var tip := xf * Vector3(0, h, 0)
		for i in seg:
			var i2 := (i + 1) % seg
			var side := base.lerp(Color.WHITE, rng.randf_range(0.0, 0.25)).darkened(rng.randf_range(0.0, 0.25))
			WorldBuilder._flat_tri(acc, top_ring[i], bot_ring[i], top_ring[i2], side)
			WorldBuilder._flat_tri(acc, top_ring[i2], bot_ring[i], bot_ring[i2], side)
			WorldBuilder._flat_tri(acc, tip, top_ring[i], top_ring[i2], base.lerp(Color.WHITE, rng.randf_range(0.3, 0.55)))
	return acc.to_mesh()


# ---------- Слияние декора по участкам, материалы, коллизия ----------

## Материал с цветом вершин, toon-светом и своим контуром по нормалям (работает и у слитых мешей).
static func _vc_mat(outline: Color, width: float) -> StandardMaterial3D:
	var m := Util.mat(Color.WHITE)
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.set_meta("toon_done", true)
	if _outline_shader == null:
		_outline_shader = load("res://veg_outline.gdshader")
	var om := ShaderMaterial.new()
	om.shader = _outline_shader
	om.set_shader_parameter("color", outline)
	om.set_shader_parameter("width", width)
	m.next_pass = om
	m.set_meta("outline", om)
	return m


static func _materials() -> Array:
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.vertex_color_use_as_albedo = true
	glow.vertex_color_is_srgb = true
	glow.set_meta("toon_done", true)
	return [
		_vc_mat(Color(0.1, 0.17, 0.08), 0.022),  # деревья
		_vc_mat(Color(0.08, 0.04, 0.1), 0.02),  # мёртвые деревья
		_vc_mat(Color(0.1, 0.18, 0.08), 0.018),  # кусты
		_vc_mat(Color(0.18, 0.17, 0.2), 0.018),  # камни
		glow,  # кристаллы
		PropAsset.material("nature", Color(0.09, 0.12, 0.07), 0.022),  # деревья из файлов
		PropAsset.material("nature", Color(0.12, 0.13, 0.1), 0.018),  # кусты и камни из файлов
	]


static func _build_decor(c: Ctx, holder: Node3D, mats: Array) -> void:
	for key in c.decor:
		var k: Vector3i = key
		var items: Array = c.decor[key]
		if items.is_empty():
			continue
		var ysum := 0.0
		for it in items:
			var e: Array = it
			var xf: Transform3D = e[1]
			ysum += xf.origin.y
		var center := Vector3((float(k.x) + 0.5) * DECOR_CHUNK, ysum / float(items.size()), (float(k.y) + 0.5) * DECOR_CHUNK)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for it in items:
			var e: Array = it
			var m: Mesh = e[0]
			var xf: Transform3D = e[1]
			xf.origin -= center
			st.append_from(m, 0, xf)
		var mi := MeshInstance3D.new()
		mi.name = "Decor%d_%d_%d" % [k.z, k.x, k.y]
		mi.mesh = st.commit()
		mi.position = center
		mi.material_override = mats[k.z]
		mi.set_meta("no_outline", true)
		mi.set_meta("props", c.decor_ids.get(k, []))
		mi.add_to_group(GROUP_NAMES[k.z])
		if k.z == G_GLOW:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mi)


static func _build_colliders(c: Ctx, holder: Node3D) -> void:
	if c.colliders.is_empty():
		return
	var body := StaticBody3D.new()
	body.name = "VegetationColliders"
	var shapes := {}
	for e in c.colliders:
		var it: Array = e
		var pos: Vector3 = it[0]
		var r0: float = it[1]
		var hh: float = it[2]
		var r := maxf(0.1, snappedf(r0, 0.05))
		hh = snappedf(hh, 0.1)
		var key := "%.2f|%.1f" % [r, hh]
		if not shapes.has(key):
			var cs := CylinderShape3D.new()
			cs.radius = r
			cs.height = hh
			shapes[key] = cs
		var col := CollisionShape3D.new()
		col.shape = shapes[key]
		col.position = pos + Vector3(0, hh * 0.5, 0)
		body.add_child(col)
	holder.add_child(body)


# ---------- Трава и цветы (MultiMesh по участкам) ----------

static func _bucket(buckets: Dictionary, x: float, z: float) -> Bucket:
	var key := Vector2i(floori(x / GRASS_CHUNK), floori(z / GRASS_CHUNK))
	var b: Bucket = buckets.get(key)
	if b == null:
		b = Bucket.new()
		b.center = Vector3((float(key.x) + 0.5) * GRASS_CHUNK, 0.0, (float(key.y) + 0.5) * GRASS_CHUNK)
		buckets[key] = b
	return b


static func _buckets_to_nodes(holder: Node3D, buckets: Dictionary, mesh: Mesh, mat: Material, group: String) -> int:
	var total := 0
	var half := GRASS_CHUNK * 0.5 + 1.0
	for key in buckets:
		var b: Bucket = buckets[key]
		if b.count == 0:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = b.count
		mm.buffer = b.data
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.position = b.center
		mmi.custom_aabb = AABB(Vector3(-half, -10.0, -half), Vector3(half * 2.0, 26.0, half * 2.0))
		mmi.add_to_group(group)
		holder.add_child(mmi)
		total += b.count
	return total


## Пучок из blades травинок высотой 1 (масштабируется экземпляром). UV.y — высота точки.
static func _grass_mesh(rng: RandomNumberGenerator, blades: int) -> ArrayMesh:
	var acc := WorldBuilder.MeshAcc.new()
	var up := Vector3.UP
	var w := Color.WHITE
	var wk := sqrt(6.0 / float(maxi(blades, 1)))  # меньше травинок — чуть шире
	for b in blades:
		var ang := TAU * float(b) / float(blades) + rng.randf_range(-0.4, 0.4)
		var out := Vector3(cos(ang), 0, sin(ang))
		var root_p := out * rng.randf_range(0.0, 0.16)
		var face := rng.randf() * TAU
		var side := Vector3(cos(face), 0, sin(face)) * rng.randf_range(0.042, 0.056) * wk
		var h := rng.randf_range(0.6, 1.0)
		var lean := out * rng.randf_range(0.1, 0.3)
		var mid := root_p + lean * 0.35 + Vector3(0, h * 0.5, 0)
		var tip := root_p + lean + Vector3(0, h, 0)
		var i0 := acc.add(root_p - side, up, w, Vector2(0, 0))
		var i1 := acc.add(root_p + side, up, w, Vector2(1, 0))
		var i2 := acc.add(mid - side * 0.7, up, w, Vector2(0, h * 0.5))
		var i3 := acc.add(mid + side * 0.7, up, w, Vector2(1, h * 0.5))
		var i4 := acc.add(tip, up, w, Vector2(0.5, h))
		acc.tri(i0, i2, i1)
		acc.tri(i1, i2, i3)
		acc.tri(i2, i4, i3)
	return acc.to_mesh()


## Трава по сетке рельефа: цвет зоны (zone_tint_at; сухая у тёмных эльфов, золотистая у светлых),
## высокие пятна в лугах, низкая у дорог, реже у юго-западных камней, нет на площадках и в воде.
static func _build_grass(c: Ctx, holder: Node3D) -> int:
	var w := c.w
	var dens := Quality.grass_density()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://island_grass.gdshader")
	mat.set_shader_parameter("wind_dir", WIND_DIR.normalized())
	var buckets := {}
	var base := GRASS_PER_M2 * w.step * w.step * dens
	var road_w := c.road_half * 2.0
	var dry := Color(0.56, 0.5, 0.33)
	var gold := Color(0.8, 0.8, 0.4)
	var rocky := Color(0.46, 0.54, 0.3)
	for j in w.nz:
		for i in w.nx:
			var k := j * w.nx + i
			if w.walk[k] == 0:
				continue
			var fw := w._flat_w[k]
			if fw > 0.97:
				continue
			var e := base * (1.0 - smoothstep(0.75, 0.97, fw))
			var rd := w.road_d[k]
			e *= smoothstep(road_w * 0.3, road_w * 0.62, rd)
			var h := w.heights[k]
			var wl := maxf(w.water_level[k], w.sea_level)
			e *= smoothstep(wl + 0.5, wl + 1.1, h)
			if e <= 0.0:
				continue
			var px := w.origin.x + float(i) * w.step
			var pz := w.origin.y + float(j) * w.step
			var bk := _bio_cell(c, px, pz)
			var wd := c.bio[bk + B_DARK]
			var wr := c.bio[bk + B_ROCKY]
			var wlt := c.bio[bk + B_LIGHT]
			e *= 1.0 - 0.3 * wd - 0.45 * wr
			var n := c.noise.get_noise_2d(px * 1.7 + 300.0, pz * 1.7)
			e *= clampf(0.75 + n * 0.9, 0.25, 1.3)
			var cnt := int(e + c.rng.randf())
			if cnt <= 0:
				continue
			var tint := w.zone_tint_at(px, pz)
			tint = tint.lerp(dry, wd * 0.5).lerp(gold, wlt * 0.15).lerp(rocky, wr * 0.3)
			var tall := smoothstep(0.2, 0.5, n) * (1.0 - wd) * (1.0 - wr)
			var near_road := lerpf(0.5, 1.0, smoothstep(road_w * 0.3, road_w * 0.9, rd))
			var hk := (1.0 + tall * 0.7) * near_road * (1.0 - 0.3 * wd)
			for q in cnt:
				var x := px + c.rng.randf_range(-0.5, 0.5) * w.step
				var z := pz + c.rng.randf_range(-0.5, 0.5) * w.step
				var hh := c.rng.randf_range(0.3, 0.52) * hk
				var ww := c.rng.randf_range(0.85, 1.3)
				var sh := c.rng.randf_range(0.88, 1.1)
				var basis := Basis(Vector3.UP, c.rng.randf() * TAU) * Basis.from_scale(Vector3(ww, hh, ww))
				_bucket(buckets, x, z).put(basis, Vector3(x, w.height_at(x, z) - 0.03, z),
					Color(tint.r * sh, tint.g * sh, tint.b * sh, c.rng.randf()))
	return _buckets_to_nodes(holder, buckets, _grass_mesh(c.rng, Quality.grass_blades()), mat, "veg_grass")


## Цветы куртинами: много светлых у светлых эльфов, полевые у людей, редкие лиловые у тёмных.
static func _build_flowers(c: Ctx, holder: Node3D) -> int:
	var w := c.w
	var dens := Quality.flower_density()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://island_flower.gdshader")
	mat.set_shader_parameter("wind_dir", WIND_DIR.normalized())
	var white := Color(0.98, 0.97, 0.94)
	var palettes := [
		[white, Color(1.0, 0.84, 0.24), Color(1.0, 0.56, 0.74), Color(0.5, 0.68, 1.0)],  # центр
		[white, Color(1.0, 0.92, 0.55), Color(0.62, 0.8, 1.0), Color(1.0, 0.78, 0.86)],  # светлые эльфы
		[Color(0.82, 0.7, 0.95), Color(0.62, 0.36, 0.85)],  # тёмные эльфы
		[white, Color(0.95, 0.25, 0.2), Color(1.0, 0.84, 0.24), Color(0.38, 0.55, 1.0)],  # люди
		[white, Color(1.0, 0.84, 0.24)],  # юго-запад
	]
	var probs := [0.18, 0.4, 0.04, 0.3, 0.07]
	var buckets := {}
	var gx := int(float(w.nx - 1) * w.step / FLOWER_CELL)
	var gz := int(float(w.nz - 1) * w.step / FLOWER_CELL)
	for j in gz:
		for i in gx:
			var cx := w.origin.x + (float(i) + c.rng.randf()) * FLOWER_CELL
			var cz := w.origin.y + (float(j) + c.rng.randf()) * FLOWER_CELL
			var b := _pick_biome(c, cx, cz)
			var pr: float = probs[b]
			if c.rng.randf() > pr:
				continue
			if not _flower_ok(c, cx, cz):
				continue
			var pal: Array = palettes[b]
			var main: Color = pal[c.rng.randi() % pal.size()]
			var rad := c.rng.randf_range(0.7, 1.6)
			var cnt := int(float(c.rng.randi_range(8, 18)) * dens + 0.5)
			for f in cnt:
				var a := c.rng.randf() * TAU
				var d := sqrt(c.rng.randf()) * rad
				var x := cx + cos(a) * d
				var z := cz + sin(a) * d
				if not _flower_ok(c, x, z):
					continue
				var col: Color = pal[0] if c.rng.randf() < 0.2 else main
				col = col.lerp(Color.WHITE, c.rng.randf_range(0.0, 0.15)).srgb_to_linear()
				var s := c.rng.randf_range(0.9, 1.3)
				var fh := c.rng.randf_range(0.22, 0.4)
				var basis := Basis(Vector3.UP, c.rng.randf() * TAU) * Basis.from_scale(Vector3(s, fh, s))
				_bucket(buckets, x, z).put(basis, Vector3(x, w.height_at(x, z) - 0.02, z),
					Color(col.r, col.g, col.b, c.rng.randf()))
	return _buckets_to_nodes(holder, buckets, WorldBuilder._flower_mesh(), mat, "veg_flowers")


## Цветок: проходимая суша, не дорога, не у самой воды, не на площадке постройки.
static func _flower_ok(c: Ctx, x: float, z: float) -> bool:
	var w := c.w
	var cell := w._cell(x, z)
	var k := w._idx(cell.x, cell.y)
	if w.walk[k] == 0 or w._flat_w[k] > 0.85:
		return false
	if w.road_d[k] < c.road_half + 0.4 or w.water_d[k] < 1.5:
		return false
	var wl := maxf(w.water_level[k], w.sea_level)
	return w.heights[k] > wl + 0.9
