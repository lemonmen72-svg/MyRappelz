class_name DungeonWorld
extends IslandWorld
## Подземелье за пещерой острова (0.35, папка Максима «ДАНЖ»): отдельная локация, остров при входе выгружается
## целиком (main.restart_scene с Game.location = "dungeon" — сцена строится заново только с подземельем).
## Тот же интерфейс, что у острова (IslandWorld): сетка высот и проходимости, коллизия, мосты (настил — bridges),
## зоны зверей и безопасные зоны, точки старта — поэтому герой, звери, питомцы, путь Кардинала (CardinalNav) и
## админ-панель работают без особых случаев. Конфиг — world/dungeon.json (карта Максима, 0.12 м на пиксель):
## залы (rooms) и коридоры (corridors) — пол, вода (water: канал, озеро, озёра у алтаря), палубы (decks) — острова
## пола своей высоты (корабль, площадки мостков), мосты (bridges), объекты (props — DungeonProps).
## Рельеф (0.35.1, просьба Максима «спуски, подъёмы»): у залов свой уровень пола (rooms[].level, м) — между залами
## пол плавно поднимается и опускается по коридорам (_level_field: два ближайших зала по пути вдоль пола, взвешено
## по расстоянию, вода — уровень floor_y), внутри залов — пологие волны (FLOOR_WAVE, у воды затухают) и холмы
## (mounds), лестницы и пандусы (ramps), уступы (decks с "kind": "stone"). Вокруг пола и воды — скальная стена
## высотой rim_h над местным полом (≈ 4 роста героя) шириной rim_w, за ней тёмная пустота (void_y, не рисуется).
## Край рваный (edge_noise). Свет — тёмный, изумрудный и фиолетовый: без неба, слабый «лунный» свет сверху, огни.

const DUNGEON_CONFIG := "res://world/dungeon.json"
## Край пола: от границы пола вглубь скалы — подъём до rim_h за RIM_RISE м, дальше спуск в пустоту.
const RIM_RISE := 1.6
## Пол чуть неровный (шум), м.
const FLOOR_BUMP := 0.12
## Пологие волны пола в залах: высота, частота шума; у воды (ближе WAVE_WATER м) — ровно.
const FLOOR_WAVE := 0.45
const WAVE_FREQ := 0.9
const WAVE_WATER := 5.0
## Уровни залов: сетка расчёта (шаг, клеток основной сетки), ядро зала (уровень ровно его) — глубже LEVEL_CORE м
## от края (не больше доли радиуса), цена пути по скале (не пол и не вода), проходов сглаживания.
const LEVEL_STEP := 2
const LEVEL_CORE := 3.5
const ROCK_COST := 4.0
const LEVEL_BLUR := 3
## Настил мостов над водой — не ниже воды + столько, м (конфиг "bridge_over_water"; 0.35.4 — 0.3: свои мосты
## dg_bridges со сваями до дна не провисают, как прежняя верёвочная модель).
const BRIDGE_OVER_WATER := 0.7
## Палуба по поверхности (decks "surface", корабль 0.35.4): бортик коллизии по краю, м (не сойти с палубы в воду
## там, где нет фальшборта), и проход в нём у конца моста — полуширина моста + столько.
const SURFACE_WALL := 1.4
const SURFACE_GAP := 0.4
## Берег без стены: пол и вода ближе SHORE_GAP м друг к другу — между ними пологий спуск к воде, а не скала (иначе
## узкая полоска края между залом и водой становилась стеной поперёк моста).
const SHORE_GAP := 5.0
## Дно воды: от кромки до полной глубины, м.
const BANK := 2.0

## Знаковое расстояние до пола (< 0 — пол) и до воды (< 0 — вода) в узлах сетки; палуба узла (−1 — нет).
var floor_sd := PackedFloat32Array()
var water_sd := PackedFloat32Array()
var deck_of := PackedInt32Array()
var water_y := -0.45
## Уровень пола в узле (_level_field), м.
var level := PackedFloat32Array()


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
	_surface_walkable()
	# полоса берега между полом и водой (_rim_unwalkable) закрывала узлы мостов у берега — герой упирался в
	# невидимую стену на настиле (0.35.4, скриншоты Максима)
	_bridges_walkable()
	_dungeon_environment()
	_build_collision()
	_deck_collision()
	_build_bridges()
	var t2 := Time.get_ticks_msec()
	DungeonWater.build(self)
	DungeonProps.build(self, rng)
	_build_atmo_fx()
	var t3 := Time.get_ticks_msec()
	_build_dungeon_mesh()
	print("Подземелье: сетка %d мс, рельеф и мосты %d мс, вода и объекты %d мс, меш %d мс" % [t1 - t0, t2 - t1, t3 - t2,
		Time.get_ticks_msec() - t3])
	# Остров кладёт сюда следы построек и мелочей (жители, находки, путь Кардинала ищут их) — у подземелья пусто
	set_meta("poi_footprints", [])
	set_meta("poi_props", [])


## Атмосфера подземелья (0.46): пламя факелов, жаровен, свечей (FireFx), свет огней и кристаллов (NightLights —
## пул ближайших), изумрудная дымка над зелёными озёрами у алтаря (HazeFx «emerald»), чёрная магическая — над
## озером, где корабль капитана («abyss»), и над каналом — лёгкая изумрудная.
func _build_atmo_fx() -> void:
	var nl := NightLights.new()
	add_child(nl)
	var ff := FireFx.new()
	add_child(ff)
	for f in get_meta("dg_fires", []):
		var fd: Dictionary = f
		ff.add(fd["pos"], float(fd["size"]), fd["color"], String(fd["kind"]))
		nl.add((fd["pos"] as Vector3) + Vector3(0.0, float(fd["size"]) * 0.7, 0.0), fd["color"],
			7.5 if String(fd["kind"]) == "brazier" else 6.0, 1.2 if String(fd["kind"]) == "brazier" else 0.9, "fire", 1.4)
	ff.build()
	for g in get_meta("dg_glows", []):
		var gd: Dictionary = g
		nl.add(gd["pos"], gd["color"], float(gd["range"]), float(gd["energy"]), String(gd["kind"]), 1.4)
	var hz := HazeFx.new()
	add_child(hz)
	for wt in cfg.get("water", []):
		var wd: Dictionary = wt
		var id := String(wd.get("id", ""))
		if String(wd.get("shape", "")) == "ellipse":
			var c := IslandWorld.v2(wd["center"])
			var r := IslandWorld.v2(wd["radius"])
			var kind := "abyss" if id == "lake" else "emerald"
			hz.add(kind, Vector3(c.x, water_y, c.y), r * 2.2)
		elif String(wd.get("shape", "")) == "path":
			var pts: Array = wd.get("points", [])
			for i in range(1, pts.size()):
				var a := IslandWorld.v2(pts[i - 1])
				var b := IslandWorld.v2(pts[i])
				var n := maxi(1, ceili(a.distance_to(b) / 14.0))
				for k in n:
					var p := a.lerp(b, (float(k) + 0.5) / float(n))
					hz.add("emerald", Vector3(p.x, water_y, p.y), Vector2(14.0, float(wd.get("width", 6.0)) * 1.8))


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
	if d.has("surface"):
		return -0.5 if not is_nan(surface_at(d, p)) else 1.0
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


## Палуба по поверхности (decks "surface": {ox, oz, step, nx, nz, h} — высоты, снятые лучами с моделей корабля в
## tools/dungeon_layout/blender_scene.py; −99 — не палуба): высота в точке (билинейно по соседним точкам палубы,
## ближайшая — если соседи не все), NAN — не палуба.
static func surface_at(d: Dictionary, p: Vector2) -> float:
	var sf: Dictionary = d["surface"]
	var st := float(sf["step"])
	var snx := int(sf["nx"])
	var snz := int(sf["nz"])
	var h: Array = sf["h"]
	var u := (p.x - float(sf["ox"])) / st
	var v := (p.y - float(sf["oz"])) / st
	var ni := int(roundf(u))
	var nj := int(roundf(v))
	if ni < 0 or nj < 0 or ni >= snx or nj >= snz or float(h[nj * snx + ni]) < -50.0:
		return NAN
	var i0 := clampi(int(floorf(u)), 0, snx - 2)
	var j0 := clampi(int(floorf(v)), 0, snz - 2)
	var a := float(h[j0 * snx + i0])
	var b := float(h[j0 * snx + i0 + 1])
	var c := float(h[(j0 + 1) * snx + i0])
	var e := float(h[(j0 + 1) * snx + i0 + 1])
	if a < -50.0 or b < -50.0 or c < -50.0 or e < -50.0:
		return float(h[nj * snx + ni])
	var fu := clampf(u - float(i0), 0.0, 1.0)
	var fv := clampf(v - float(j0), 0.0, 1.0)
	return lerpf(lerpf(a, b, fu), lerpf(c, e, fu), fv)


## Высота палубы d в точке p (палуба по поверхности — по ней, иначе — "height").
static func deck_height(d: Dictionary, p: Vector2) -> float:
	if d.has("surface"):
		var v := surface_at(d, p)
		return v if not is_nan(v) else 0.3
	return float(d.get("height", 0.3))


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
	var rim_h := float(cfg.get("rim_h", 7.0))
	var rim_w := float(cfg.get("rim_w", 3.0))
	var void_y := float(cfg.get("void_y", -14.0))
	var bed := float(cfg.get("water_bed", -1.9))
	var decks: Array = cfg.get("decks", [])
	level = _level_field(fy)
	for j in nz:
		for i in nx:
			var k := _idx(i, j)
			var p := _pos(i, j)
			var fs := floor_sd[k]
			var ws := water_sd[k]
			var lv := level[k]
			var h: float
			# Вода — поверх пола залов (озёра у алтаря внутри зала), палубы — поверх воды
			if deck_of[k] >= 0:
				h = deck_height(decks[deck_of[k]], p)
			elif ws <= 0.0:
				# Дно: от кромки (уровень воды − 0.15) к глубине за BANK м
				h = lerpf(water_y - 0.15, bed, smoothstep(0.0, BANK, -ws))
			elif fs <= 0.0:
				h = lv + _noise.get_noise_2d(p.x * 2.3 + 17.0, p.y * 2.3) * FLOOR_BUMP
				# Волны пола: от края пола внутрь и от воды
				var wave := smoothstep(0.0, 3.0, -fs) * smoothstep(1.0, WAVE_WATER, ws) * _room_wave(p)
				h += _noise.get_noise_2d(p.x * WAVE_FREQ + 211.0, p.y * WAVE_FREQ - 97.0) * FLOOR_WAVE * wave
				h += _mound_at(p)
			elif fs + ws < SHORE_GAP:
				# Узкая полоса между полом и водой — берег: от пола к кромке воды
				h = lerpf(lv, water_y - 0.1, smoothstep(0.0, 1.0, fs / maxf(fs + ws, 0.01)))
			else:
				# Скальная стена вокруг пола и воды (над местным уровнем пола), за ней пустота
				var d := minf(fs, ws)
				var base := lv if fs <= ws else maxf(lv, fy)
				var top := base + rim_h * (0.88 + 0.24 * (_noise.get_noise_2d(p.x * 0.7 + 50.0, p.y * 0.7) * 0.5 + 0.5))
				if d < RIM_RISE:
					h = lerpf(base, top, smoothstep(0.0, RIM_RISE, d))
				elif d < rim_w:
					h = top
				else:
					h = lerpf(top, void_y, smoothstep(rim_w, rim_w + 2.5, d))
			heights[k] = h
			# Вода: узлы воды и кромка (меш воды и шейдер земли — мокрое дно); под досками палуб — тоже (меш воды;
			# рельеф там не рисуется — без неё под причалом зияла чёрная пустота, 0.35.3)
			if ws < 1.5 and (deck_of[k] < 0 or _plank_deck(j, i)):
				water_level[k] = water_y
				water_d[k] = maxf(0.0, ws + 1.5)
	_apply_ramps()


## Уровень пола в каждом узле: залы с "level" — ядро зала (глубже LEVEL_CORE от края) ровно на уровне зала, вода —
## floor_y; между ними — по двум ближайшим (по пути вдоль пола и воды, через скалу — дороже ROCK_COST) с весом
## 1/расстояние², затем сглаживание. Считается на сетке крупнее (LEVEL_STEP) и раскладывается билинейно.
func _level_field(fy: float) -> PackedFloat32Array:
	var anchors: Array[float] = [fy]
	var rooms: Array = cfg.get("rooms", [])
	var room_anchor: Array[int] = []
	for r in rooms:
		var d: Dictionary = r
		if d.has("level"):
			room_anchor.append(anchors.size())
			anchors.append(fy + float(d["level"]))
		else:
			room_anchor.append(-1)
	var cs := LEVEL_STEP
	var cx := int(ceilf(float(nx - 1) / cs)) + 1
	var cz := int(ceilf(float(nz - 1) / cs)) + 1
	var n := cx * cz
	var d1 := PackedFloat32Array()
	var d2 := PackedFloat32Array()
	var i1 := PackedInt32Array()
	var i2 := PackedInt32Array()
	var cost := PackedFloat32Array()
	d1.resize(n)
	d2.resize(n)
	i1.resize(n)
	i2.resize(n)
	cost.resize(n)
	var big := 1.0e9
	for cj in cz:
		for ci in cx:
			var c := cj * cx + ci
			var i := mini(ci * cs, nx - 1)
			var j := mini(cj * cs, nz - 1)
			var k := _idx(i, j)
			var p := _pos(i, j)
			d1[c] = big
			d2[c] = big
			i1[c] = -1
			i2[c] = -1
			cost[c] = 1.0 if (floor_sd[k] <= 0.0 or water_sd[k] <= 0.0) else ROCK_COST
			if water_sd[k] <= 0.0 and floor_sd[k] > -1.0:
				d1[c] = 0.0
				i1[c] = 0
				continue
			for ri in rooms.size():
				if room_anchor[ri] < 0:
					continue
				var room: Dictionary = rooms[ri]
				var rr: Array = room.get("radius", [5, 5])
				var core := minf(LEVEL_CORE, minf(float(rr[0]), float(rr[1])) * 0.35)
				if shape_sd(room, p) < -core:
					d1[c] = 0.0
					i1[c] = room_anchor[ri]
					break
	var st := float(cs) * step
	var diag := st * 1.41421
	for _pass in 5:
		for cj in cz:
			for ci in cx:
				var c := cj * cx + ci
				if ci > 0:
					_level_relax(c, c - 1, st * cost[c], d1, d2, i1, i2)
				if cj > 0:
					_level_relax(c, c - cx, st * cost[c], d1, d2, i1, i2)
					if ci > 0:
						_level_relax(c, c - cx - 1, diag * cost[c], d1, d2, i1, i2)
					if ci < cx - 1:
						_level_relax(c, c - cx + 1, diag * cost[c], d1, d2, i1, i2)
		for cj in range(cz - 1, -1, -1):
			for ci in range(cx - 1, -1, -1):
				var c := cj * cx + ci
				if ci < cx - 1:
					_level_relax(c, c + 1, st * cost[c], d1, d2, i1, i2)
				if cj < cz - 1:
					_level_relax(c, c + cx, st * cost[c], d1, d2, i1, i2)
					if ci < cx - 1:
						_level_relax(c, c + cx + 1, diag * cost[c], d1, d2, i1, i2)
					if ci > 0:
						_level_relax(c, c + cx - 1, diag * cost[c], d1, d2, i1, i2)
	var lv := PackedFloat32Array()
	lv.resize(n)
	for c in n:
		if i1[c] < 0:
			lv[c] = fy
		elif d1[c] <= 0.0 or i2[c] < 0:
			lv[c] = anchors[i1[c]]
		else:
			var w1 := 1.0 / (d1[c] * d1[c])
			var w2 := 1.0 / (d2[c] * d2[c])
			lv[c] = (anchors[i1[c]] * w1 + anchors[i2[c]] * w2) / (w1 + w2)
	# Сглаживание (стык зон, где меняется второй ближайший зал); ядра залов и вода остаются на месте
	for _b in LEVEL_BLUR:
		var sm := lv.duplicate()
		for cj in range(1, cz - 1):
			for ci in range(1, cx - 1):
				var c := cj * cx + ci
				if d1[c] <= 0.0:
					continue
				var acc := 0.0
				for dj in range(-1, 2):
					for di in range(-1, 2):
						acc += lv[c + dj * cx + di]
				sm[c] = acc / 9.0
		lv = sm
	var out := PackedFloat32Array()
	out.resize(nx * nz)
	for j in nz:
		var fj := float(j) / cs
		var cj0 := mini(int(fj), cz - 1)
		var cj1 := mini(cj0 + 1, cz - 1)
		var tj := fj - float(cj0)
		for i in nx:
			var fi := float(i) / cs
			var ci0 := mini(int(fi), cx - 1)
			var ci1 := mini(ci0 + 1, cx - 1)
			var ti := fi - float(ci0)
			var a := lerpf(lv[cj0 * cx + ci0], lv[cj0 * cx + ci1], ti)
			var b := lerpf(lv[cj1 * cx + ci0], lv[cj1 * cx + ci1], ti)
			out[_idx(i, j)] = lerpf(a, b, tj)
	return out


## Узел c: два ближайших якоря (разных) — с учётом соседа nc и цены шага.
static func _level_relax(c: int, nc: int, w: float, d1: PackedFloat32Array, d2: PackedFloat32Array,
		i1: PackedInt32Array, i2: PackedInt32Array) -> void:
	if i1[nc] >= 0:
		_level_put(c, d1[nc] + w, i1[nc], d1, d2, i1, i2)
	if i2[nc] >= 0:
		_level_put(c, d2[nc] + w, i2[nc], d1, d2, i1, i2)


static func _level_put(c: int, d: float, id: int, d1: PackedFloat32Array, d2: PackedFloat32Array,
		i1: PackedInt32Array, i2: PackedInt32Array) -> void:
	if id == i1[c]:
		if d < d1[c]:
			d1[c] = d
		return
	if id == i2[c]:
		if d < d2[c]:
			d2[c] = d
			if d2[c] < d1[c]:
				var td := d1[c]
				d1[c] = d2[c]
				d2[c] = td
				var ti := i1[c]
				i1[c] = i2[c]
				i2[c] = ti
		return
	if d < d1[c]:
		d2[c] = d1[c]
		i2[c] = i1[c]
		d1[c] = d
		i1[c] = id
	elif d < d2[c]:
		d2[c] = d
		i2[c] = id


## Сила волн пола в точке: у зала с полем "wave" — оно (вход — ровный, у подножия лестницы), иначе 1.
func _room_wave(p: Vector2) -> float:
	for r in cfg.get("rooms", []):
		var d: Dictionary = r
		if d.has("wave") and shape_sd(d, p) < 2.0:
			return float(d["wave"])
	return 1.0


## Холмы и впадины пола (mounds: center, radius, height; height < 0 — впадина): плавный купол.
func _mound_at(p: Vector2) -> float:
	var h := 0.0
	for m in cfg.get("mounds", []):
		var d: Dictionary = m
		var r := float(d.get("radius", 5.0))
		var t := clampf(1.0 - p.distance_to(v2(d["center"])) / r, 0.0, 1.0)
		h += float(d.get("height", 1.0)) * t * t * (3.0 - 2.0 * t)
	return h


## Лестницы и пандусы (ramps: a, b, width; ha, hb — высоты концов, нет — пол в этой точке): ровный уклон от a к b,
## по ширине целиком. Под моделью лестницы — пандус (по нему ходят), края — обрыв.
func _apply_ramps() -> void:
	for r in cfg.get("ramps", []):
		var d: Dictionary = r
		var a := v2(d["a"])
		var b := v2(d["b"])
		var ha := float(d["ha"]) if d.has("ha") else height_at(a.x, a.y)
		var hb := float(d["hb"]) if d.has("hb") else height_at(b.x, b.y)
		var half := float(d.get("width", 3.0)) * 0.5
		var ab := b - a
		var len2 := maxf(ab.length_squared(), 0.0001)
		var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(half, half)
		var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(half, half)
		for j in range(clampi(int((lo.y - origin.y) / step), 0, nz - 1), clampi(int((hi.y - origin.y) / step) + 2, 0, nz)):
			for i in range(clampi(int((lo.x - origin.x) / step), 0, nx - 1), clampi(int((hi.x - origin.x) / step) + 2, 0, nx)):
				var p := _pos(i, j)
				var t := (p - a).dot(ab) / len2
				if t < 0.0 or t > 1.0:
					continue
				if p.distance_to(a + ab * t) <= half:
					heights[_idx(i, j)] = lerpf(ha, hb, t)


func _find_dungeon_bridges() -> void:
	bridges.clear()
	for b in cfg.get("bridges", []):
		var d: Dictionary = b
		var pa := v2(d["a"])
		var pb := v2(d["b"])
		var br := {
			"a": Vector3(pa.x, _ground_or_deck(pa), pa.y),
			"b": Vector3(pb.x, _ground_or_deck(pb), pb.y),
			"width": float(d.get("width", 3.2)),
		}
		# Настил — прямо от конца к концу (концы вровень с полом), над водой не ниже воды + запас. Профиль острова
		# (_deck_profile) берёт высоту земли по ширине моста — у края пола это скальная стена: настил у начала
		# мостков к кораблю вздымался на 2 м (0.35, «до босса не добраться»)
		var over := float(cfg.get("bridge_over_water", BRIDGE_OVER_WATER))
		br["deck"] = bridge_profile(pa, pb, float(br["width"]), _ground_or_deck(pa) - 0.03, _ground_or_deck(pb) - 0.03, over)
		bridges.append(br)


## Профиль настила моста подземелья (точка на каждые BRIDGE_STEP м): прямая от конца к концу, над водой не ниже воды +
## over, сглажено, и **не ниже земли под мостом** (0.35.4: у берега земля бывала выше прямой — настил уходил под берег,
## получалась ступенька 0.2 м, герой упирался; доски и перила там рисуются только над водой — модель dg_bridges).
## Земля — по оси и в 0.3 м по бокам; та же функция — в tools/dungeon_layout/blender_scene.py (bridge_profile).
const BRIDGE_STEP := 0.5


## Самый высокий угол клетки сетки под точкой: физика рельефа — треугольники, на крутом берегу треугольник выше
## билинейной высоты до 0.2 м (ступенька у конца моста).
func _cell_top(x: float, z: float) -> float:
	var i0 := clampi(int(floorf((x - origin.x) / step)), 0, nx - 2)
	var j0 := clampi(int(floorf((z - origin.y) / step)), 0, nz - 2)
	return maxf(maxf(heights[_idx(i0, j0)], heights[_idx(i0 + 1, j0)]),
		maxf(heights[_idx(i0, j0 + 1)], heights[_idx(i0 + 1, j0 + 1)]))


func bridge_profile(pa: Vector2, pb: Vector2, width: float, ya: float, yb: float, over: float) -> PackedFloat32Array:
	var n := maxi(BRIDGE_SAMPLES, int(ceilf(pa.distance_to(pb) / BRIDGE_STEP)))
	var side := (pb - pa).normalized().orthogonal() * minf(0.3, width * 0.5)
	var deck := PackedFloat32Array()
	var ground := PackedFloat32Array()
	deck.resize(n + 1)
	ground.resize(n + 1)
	for i in n + 1:
		var t := float(i) / float(n)
		var q := pa.lerp(pb, t)
		deck[i] = lerpf(ya, yb, t)
		ground[i] = maxf(_cell_top(q.x, q.y), maxf(_cell_top(q.x + side.x, q.y + side.y), _cell_top(q.x - side.x, q.y - side.y)))
	for i in range(1, n):
		deck[i] = maxf(deck[i], water_y + over)
	for _pass in 2:
		var sm := deck.duplicate()
		for i in range(1, n):
			sm[i] = maxf(deck[i - 1] * 0.25 + deck[i] * 0.5 + deck[i + 1] * 0.25, water_y + over - 0.05)
		deck = sm
	for i in range(1, n):
		deck[i] = maxf(deck[i], ground[i] + 0.02)
	return deck


## Высота земли, а на палубе-острове — ровно высота палубы (конец моста встаёт вровень с площадкой, без ступеньки).
func _ground_or_deck(p: Vector2) -> float:
	for d in cfg.get("decks", []):
		if shape_sd(d, p) < 0.0:
			return deck_height(d, p)
	return height_at(p.x, p.y)


## Палубы-острова (площадки мостков, корабль, уступ у портала): своя ровная коллизия — призма по эллипсу палубы
## (у сетки рельефа 1 м край площадки 2.3 м — ступеньки и скосы, герой на ней спотыкался и съезжал в воду); палуба-
## полоса ("path": корабль 0.35.3) — капсула на каждый отрезок.
func _deck_collision() -> void:
	var decks: Array = cfg.get("decks", [])
	for d in decks:
		var dk: Dictionary = d
		if dk.has("surface"):
			_deck_surface_collision(dk)
			continue
		if dk.has("points"):
			_deck_path_collision(dk)
			continue
		var c := v2(dk["center"])
		var r: Array = dk.get("radius", [2, 2])
		var top := float(dk.get("height", 0.3))
		var rot := deg_to_rad(float(dk.get("rot", 0.0)))
		var pts := PackedVector3Array()
		for k in 16:
			var a := TAU * float(k) / 16.0
			var q := Vector2(cos(a) * float(r[0]), sin(a) * float(r[1])).rotated(rot)
			pts.append(Vector3(q.x, 0.0, q.y))
			pts.append(Vector3(q.x, -1.2, q.y))
		var shape := ConvexPolygonShape3D.new()
		shape.points = pts
		var body := StaticBody3D.new()
		body.name = "Deck_" + String(dk.get("id", ""))
		body.position = Vector3(c.x, top, c.y)
		var col := CollisionShape3D.new()
		col.shape = shape
		body.add_child(col)
		add_child(body)


## Палуба по поверхности: треугольники по точкам палубы (расширено на точку — край не обрывается под ногой), по
## краю — бортик SURFACE_WALL (не сойти в воду там, где у модели нет фальшборта), у концов мостов — проход.
func _deck_surface_collision(dk: Dictionary) -> void:
	var sf: Dictionary = dk["surface"]
	var st := float(sf["step"])
	var snx := int(sf["nx"])
	var snz := int(sf["nz"])
	var src: Array = sf["h"]
	var ox := float(sf["ox"])
	var oz := float(sf["oz"])
	# расширение на одну точку: высота — ближайшей точки палубы
	var h := PackedFloat32Array()
	h.resize(snx * snz)
	for j in snz:
		for i in snx:
			var v := float(src[j * snx + i])
			if v < -50.0:
				var best := -99.0
				var bd := INF
				for b in range(maxi(0, j - 1), mini(snz, j + 2)):
					for a in range(maxi(0, i - 1), mini(snx, i + 2)):
						var w := float(src[b * snx + a])
						var dd := float((a - i) * (a - i) + (b - j) * (b - j))
						if w > -50.0 and dd < bd:
							bd = dd
							best = w
				v = best
			h[j * snx + i] = v
	var gaps: Array[Vector3] = []
	for b in cfg.get("bridges", []):
		for key in ["a", "b"]:
			var q := v2(b[key])
			if not is_nan(surface_at(dk, q)) or not is_nan(surface_at(dk, q + (q - v2(b["b" if key == "a" else "a"])).normalized() * 1.0)):
				gaps.append(Vector3(q.x, q.y, float(b.get("width", 3.2)) * 0.5 + SURFACE_GAP + 0.6))
	var faces := PackedVector3Array()
	var pt := func(i: int, j: int) -> Vector3:
		return Vector3(ox + float(i) * st, h[j * snx + i], oz + float(j) * st)
	for j in snz - 1:
		for i in snx - 1:
			var ok := h[j * snx + i] > -50.0 and h[j * snx + i + 1] > -50.0 and h[(j + 1) * snx + i] > -50.0 \
				and h[(j + 1) * snx + i + 1] > -50.0
			if not ok:
				continue
			var a: Vector3 = pt.call(i, j)
			var b: Vector3 = pt.call(i + 1, j)
			var c: Vector3 = pt.call(i, j + 1)
			var e: Vector3 = pt.call(i + 1, j + 1)
			faces.append_array([a, b, c, b, e, c])
	# бортик: рёбра между клеткой палубы и не палубой
	var cell := func(i: int, j: int) -> bool:
		return i >= 0 and j >= 0 and i < snx - 1 and j < snz - 1 and h[j * snx + i] > -50.0 \
			and h[j * snx + i + 1] > -50.0 and h[(j + 1) * snx + i] > -50.0 and h[(j + 1) * snx + i + 1] > -50.0
	var up := Vector3(0, SURFACE_WALL, 0)
	for j in snz - 1:
		for i in snx - 1:
			if not cell.call(i, j):
				continue
			for d in [[Vector2i(1, 0), Vector2i(1, 0), Vector2i(1, 1)], [Vector2i(-1, 0), Vector2i(0, 0), Vector2i(0, 1)],
					[Vector2i(0, 1), Vector2i(0, 1), Vector2i(1, 1)], [Vector2i(0, -1), Vector2i(0, 0), Vector2i(1, 0)]]:
				var nb: Vector2i = d[0]
				if cell.call(i + nb.x, j + nb.y):
					continue
				var c0: Vector2i = d[1]
				var c1: Vector2i = d[2]
				var p0: Vector3 = pt.call(i + c0.x, j + c0.y)
				var p1: Vector3 = pt.call(i + c1.x, j + c1.y)
				var mid := (p0 + p1) * 0.5
				var open := false
				for g in gaps:
					if Vector2(mid.x - g.x, mid.z - g.y).length() < g.z:
						open = true
				if open:
					continue
				faces.append_array([p0, p1, p1 + up, p0, p1 + up, p0 + up])
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var body := StaticBody3D.new()
	body.name = "Deck_" + String(dk.get("id", ""))
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)


func _deck_path_collision(dk: Dictionary) -> void:
	var pts_in: Array = dk.get("points", [])
	var half := float(dk.get("width", 4.0)) * 0.5
	var top := float(dk.get("height", 0.3))
	for i in range(maxi(1, pts_in.size() - 1)):
		var a := v2(pts_in[i])
		var b := v2(pts_in[mini(i + 1, pts_in.size() - 1)])
		var c := (a + b) * 0.5
		var pts := PackedVector3Array()
		for e in [a, b]:
			for k in 16:
				var ang := TAU * float(k) / 16.0
				var q: Vector2 = (e as Vector2) - c + Vector2(cos(ang), sin(ang)) * half
				pts.append(Vector3(q.x, 0.0, q.y))
				pts.append(Vector3(q.x, -1.2, q.y))
		var shape := ConvexPolygonShape3D.new()
		shape.points = pts
		var body := StaticBody3D.new()
		body.name = "Deck_%s_%d" % [String(dk.get("id", "")), i]
		body.position = Vector3(c.x, top, c.y)
		var col := CollisionShape3D.new()
		col.shape = shape
		body.add_child(col)
		add_child(body)


## Палуба по поверхности (корабль): проходим каждый узел на ней — уклон к воде за бортом или к пробоине узел не
## закрывает (сетка 1 м отрезала края палубы, по кораблю оставалась полоса 2–4 м), сойти с палубы не даёт бортик
## коллизии (_deck_surface_collision).
func _surface_walkable() -> void:
	var decks: Array = cfg.get("decks", [])
	for k in walk.size():
		var dk := deck_of[k]
		if dk >= 0 and (decks[dk] as Dictionary).has("surface"):
			walk[k] = 1


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
	env.ambient_light_color = Color(0.5, 0.47, 0.6)
	env.ambient_light_energy = 0.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color(0.04, 0.05, 0.08)
	env.fog_light_energy = 1.0
	env.fog_density = 0.009
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
	sun.light_color = Color(0.8, 0.84, 0.95)
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)
	# Атмосфера подземелья (0.46): неба и дождя нет, огни и кристаллы — как ночью
	var atmo := Atmosphere.new()
	atmo.setup_dungeon(env, sun)
	add_child(atmo)


func _build_dungeon_mesh() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://dungeon_terrain.gdshader")
	mat.set_shader_parameter("rich", Quality.rich_shaders())
	mat.set_shader_parameter("water_y", water_y)
	mat.set_shader_parameter("floor_y", float(cfg.get("floor_y", 0.0)))
	mat.set_shader_parameter("rim_w", float(cfg.get("rim_w", 3.0)))
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
			# Палуба-остров из досок (площадки мостков, корабль): видна модель, свой рельеф под ней не рисуется (был
			# тёмной коробкой под площадкой); ходят по призме _deck_collision
			if _plank_deck(j0 + j, i0 + i) or _plank_deck(j0 + j, i0 + i + 1) or _plank_deck(j0 + j + 1, i0 + i) \
					or _plank_deck(j0 + j + 1, i0 + i + 1):
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


## Узел — палуба из досок (не каменный уступ).
func _plank_deck(j: int, i: int) -> bool:
	var dk := deck_of[_idx(i, j)]
	if dk < 0:
		return false
	return String(((cfg.get("decks", []) as Array)[dk] as Dictionary).get("kind", "")) != "stone"


## Вид пола в точке: 1 — утоптанная земля (лагерь гоблинов, шахта, сокровищница), 2 — доски (палубы), 0 — камень.
func _floor_kind(p: Vector2) -> float:
	var decks: Array = cfg.get("decks", [])
	for d in decks:
		if String((d as Dictionary).get("kind", "")) != "stone" and shape_sd(d, p) < 0.3:
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


## Слоты монстров по зонам mob_zones (формат острова: [вид, сколько, мин. ур., макс. ур.]): точка — на полу зала
## (room_at, не мост, не палуба, не коридор), вне безопасной зоны, не ближе MOB_PORTAL_GAP к порталу и не в твёрдом
## объекте (круг по следу коллизии из prop_shapes + MOB_PROP_GAP).
const MOB_PORTAL_GAP := 14.0
const MOB_PROP_GAP := 0.7


func mob_slots(rng: RandomNumberGenerator) -> Array:
	var res := []
	var solids := _solid_circles()
	var por := v2((cfg.get("portal", {}) as Dictionary).get("center", [0, 0]))
	for z in cfg.get("mob_zones", []):
		var zone: Dictionary = z
		var c := v2(zone["center"])
		var r := float(zone.get("radius", 8.0))
		var lv: Array = zone.get("levels", [20, 20])
		for m in zone.get("mobs", []):
			var entry: Array = m
			var elv: Array = [entry[2], entry[3]] if entry.size() >= 4 else lv
			for n in int(entry[1]):
				var pos := Vector3.ZERO
				var found := false
				# Место задано точно (босс на палубе корабля): центр зоны, высота — палубы
				if bool(zone.get("fixed", false)):
					pos = Vector3(c.x, _ground_or_deck(c) + 0.1, c.y)
					found = true
				for attempt in (0 if found else 160):
					var ang := rng.randf() * TAU
					var rr := sqrt(rng.randf()) * r * (1.0 if attempt < 80 else 1.6)
					var x := c.x + cos(ang) * rr
					var zz := c.y + sin(ang) * rr
					if _mob_spot_ok(x, zz, solids, por):
						pos = ground(x, zz)
						found = true
						break
				if not found:
					pos = ground(c.x, c.y)
				res.append({
					"type": String(entry[0]), "pos": pos, "zone": String(zone.get("id", "")),
					"level": rng.randi_range(int(elv[0]), int(elv[1])),
				})
	return res


func _mob_spot_ok(x: float, z: float, solids: Array, por: Vector2) -> bool:
	if not is_walkable(x, z) or room_at(x, z) == "" or Vector2(x, z).distance_to(por) < MOB_PORTAL_GAP:
		return false
	if in_safe_zone(Vector3(x, 0.0, z)):
		return false
	for d in cfg.get("decks", []):
		if shape_sd(d, Vector2(x, z)) < 1.0:
			return false
	for sc in solids:
		var a: Array = sc
		if Vector2(x, z).distance_to(a[0]) < float(a[1]) + MOB_PROP_GAP:
			return false
	return true


## Твёрдые объекты раскладки кругами [центр, радиус] по их форме коллизии (prop_shapes).
func _solid_circles() -> Array:
	var out: Array = []
	var shapes: Dictionary = cfg.get("prop_shapes", {})
	for e in cfg.get("props", []):
		var a: Array = e
		var id := String(a[0])
		if not shapes.has(id):
			continue
		var sh: Dictionary = shapes[id]
		var s := float(a[4]) if a.size() > 4 else 1.0
		var yaw := deg_to_rad(float(a[3])) if a.size() > 3 else 0.0
		var ctr := Vector2(float(a[1]), float(a[2]))
		if sh.has("pole"):
			var pl: Array = sh["pole"]
			out.append([ctr + Vector2(float(pl[0]), float(pl[1])).rotated(-yaw) * s, float(pl[2]) * s])
			continue
		var rad := 0.0
		for q in sh.get("hull", []):
			var qa: Array = q
			rad = maxf(rad, Vector2(float(qa[0]), float(qa[1])).length())
		out.append([ctr, rad * s])
	return out


## Зал, в котором точка (id из rooms; "" — коридор, вода, край).
func room_at(x: float, z: float) -> String:
	for r in cfg.get("rooms", []):
		var room: Dictionary = r
		if shape_sd(room, Vector2(x, z)) < 0.0:
			return String(room.get("id", ""))
	return ""
