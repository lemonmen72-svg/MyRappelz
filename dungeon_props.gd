class_name DungeonProps
extends RefCounted
## Объекты подземелья (DungeonWorld): модели Максима из папки «ДАНЖ» (assets/props/dg_*.glb, атласы props_dg_*.png —
## tools/prepare_props.py) по списку world/dungeon.json "props" ([id, x, z, поворот°, масштаб, сдвиг по высоте,
## вертикальный масштаб, 1 — сдвиг это точная высота основания в мире, наклон вокруг осей модели X и Z, °];
## раскладку усаживает по настоящей геометрии
## сцена Blender tools/dungeon_layout/blender_scene.py) и мосты — своя модель dg_bridges (доски, сваи до дна, перила;
## координаты мира; "bridge_model"), без неё — верёвочная модель пролётом. Камней на скальной стене нет.
## Экземпляры склеиваются в меши участков ZONE м по странице атласа (один материал страницы — prop.gdshader), как
## постройки острова (IslandPois). Коллизия — коробка по габаритам модели × COLLIDE_K у крупных (SOLID), мелочь и
## лежащее на полу (ковры, кости, золото) — без коллизии. Огни — OmniLight3D у главных источников (LIGHTS, не больше
## MAX_LIGHTS: в Compatibility свет на объект ограничен), без теней. Без части пакета — запасные коробки и столбы
## из примитивов (FALLBACK_COLORS), подземелье проходимо и узнаваемо.

const ZONE := 40.0
## Участок при дальности «В подземелье» (Quality.dungeon_range): мельче — видимость режется ровнее; ставит build.
static var zone_size := ZONE
## Сколько видно участок сверх дальности: половина его диагонали и камера позади героя, м.
const VIEW_CAMERA := 10.0
const COLLIDE_K := 0.8
## Крупное и твёрдое — с коллизией (коробка).
const SOLID := ["dg_spire", "dg_crag", "dg_moss_stones", "dg_amethyst_spires", "dg_crystal_purple", "dg_crystal_blue",
	"dg_tent", "dg_cauldron", "dg_chest", "dg_chest_open", "dg_crates", "dg_barrel", "dg_bell", "dg_palisade",
	"dg_barricade", "dg_spikes", "dg_barricade_moss", "dg_totem", "dg_table", "dg_prison", "dg_armory", "dg_obelisk",
	"dg_monolith", "dg_crypt_altar", "dg_witch_brazier", "dg_throne", "dg_oracle", "dg_coral_altar", "dg_mine",
	"dg_cannon", "dg_relics", "dg_hoard", "dg_brazier", "dg_siren",
	"dg_helm", "dg_leviathan", "dg_cavern", "dg_cliffs", "dg_dripstone"]
const MAX_LIGHTS := 10
## Огни (0.46, атмосфера): модели с пламенем — id → [вид огня FireFx, цвет FireFx.COLORS, высота пламени, м]
## (у основания — точка «glow» модели); свет ночью — NightLights (пул ближайших вместо прежних 10 постоянных).
const FIRES := {
	"dg_torch": ["torch", "warm", 0.42], "dg_brazier": ["brazier", "warm", 0.7], "dg_cauldron": ["camp", "warm", 0.55],
	"dg_witch_brazier": ["brazier", "emerald", 0.75], "dg_candles": ["torch", "emerald", 0.22],
}
## Светящиеся модели без пламени: id → [цвет, радиус света, сила, вид "crystal" / "lamp"].
const GLOWS := {
	"dg_crystal_blue": [Color(0.4, 0.75, 1.0), 7.0, 1.0, "crystal"], "dg_crystal_purple": [Color(0.72, 0.4, 1.0), 7.0, 1.0, "crystal"],
	"dg_glowcaps": [Color(0.4, 0.8, 1.0), 5.5, 0.8, "crystal"], "dg_coral": [Color(0.35, 0.85, 1.0), 4.5, 0.6, "crystal"],
	"dg_coral_altar": [Color(0.35, 1.0, 0.55), 14.0, 2.0, "crystal"], "dg_crypt_altar": [Color(0.35, 1.0, 0.55), 8.0, 1.2, "crystal"],
	"dg_spiral": [Color(0.35, 1.0, 0.55), 10.0, 1.4, "crystal"], "dg_rune_arch": [Color(0.35, 1.0, 0.55), 8.0, 1.2, "crystal"],
	"dg_lantern": [Color(1.0, 0.7, 0.35), 6.0, 0.9, "lamp"], "dg_harbor_post": [Color(1.0, 0.7, 0.35), 7.0, 1.0, "lamp"],
	"dg_chest_open": [Color(1.0, 0.8, 0.35), 6.0, 0.9, "lamp"],
}
## Модель моста на настил мостов и мостков, насколько опустить её (доски модели — у её основания), м.
const BRIDGE_PROP := "dg_rope_bridge"
const BRIDGE_SINK := 0.33
## Огни: id объекта → [цвет, энергия, радиус, высота над основанием (доля высоты модели)].
const LIGHTS := {
	"dg_brazier": [Color(1.0, 0.62, 0.3), 1.4, 7.5, 0.92],
	"dg_cauldron": [Color(1.0, 0.55, 0.25), 1.3, 7.0, 0.5],
	"dg_coral_altar": [Color(0.35, 1.0, 0.55), 2.0, 14.0, 0.6],
	"dg_witch_brazier": [Color(0.35, 1.0, 0.5), 1.2, 7.0, 0.9],
	"dg_spiral": [Color(0.35, 1.0, 0.55), 1.6, 10.0, 1.0],
	"dg_chest_open": [Color(1.0, 0.8, 0.35), 1.3, 7.5, 0.8],
	"dg_harbor_post": [Color(1.0, 0.7, 0.35), 1.1, 7.0, 0.85],
	"dg_rune_arch": [Color(0.35, 1.0, 0.55), 1.3, 8.0, 1.0],
}
## Запасные модели без части пакета: id → [цвет, форма "box"/"cyl"].
const FALLBACK_COLORS := {
	"rock": Color(0.36, 0.33, 0.42), "wood": Color(0.42, 0.3, 0.2), "glow": Color(0.3, 0.95, 0.55),
	"gold": Color(0.95, 0.78, 0.3), "bone": Color(0.85, 0.82, 0.7),
}

## Модели с вырезами (world/dungeon.json "prop_cuts": id → [[x0, y0, z0, x1, y1, z1], …] в осях модели): треугольники
## с центром внутри коробки убираются — проходы в перилах корабля на стыках его частей и там, где подходит мост
## (0.35.3: нос, средняя палуба и корма — отдельные модели с закрытыми торцами). Кэш — по id и коробкам.
static var _cut_meshes := {}


class Zone:
	var origin := Vector3.ZERO
	## страница → [[меш, преобразование относительно origin]]
	var items := {}


static func build(world: DungeonWorld, _rng: RandomNumberGenerator) -> void:
	var holder := Node3D.new()
	holder.name = "DungeonProps"
	world.add_child(holder)
	var view := Quality.dungeon_range()
	zone_size = clampf(view * 0.5, 10.0, ZONE) if view > 0.0 else ZONE
	var zones := {}
	var fallback := Node3D.new()
	fallback.name = "Fallback"
	holder.add_child(fallback)
	var lights := 0
	var placed := 0
	var fires: Array = []
	var glows: Array = []
	# Раскладка редактора объектов у администратора (DungeonEditor.props_for), иначе world/dungeon.json "props"
	for e in DungeonEditor.props_for(world):
		var a: Array = e
		var id := String(a[0])
		var x := float(a[1])
		var z := float(a[2])
		var yaw := deg_to_rad(float(a[3]) if a.size() > 3 else 0.0)
		var s := float(a[4]) if a.size() > 4 else 1.0
		var pos := base_pos(world, a)
		var sy := float(a[6]) if a.size() > 6 else 1.0
		_place(world, holder, fallback, zones, id, pos, yaw, s, SOLID.has(id), sy, tilt_of(a))
		placed += 1
		# Огни и свечение (0.46): точка «glow» модели в мире; свет ночью — пул NightLights
		if FIRES.has(id) or GLOWS.has(id):
			var xf := Transform3D(Basis(Vector3.UP, yaw) * tilt_of(a) * Basis.from_scale(Vector3(s, s * sy, s)), pos)
			var gp := xf * (PropAsset.marker(id, "glow", Vector3(0, 0.8, 0)) if PropAsset.has(id) else Vector3(0, 0.8, 0))
			if FIRES.has(id):
				var fd: Array = FIRES[id]
				fires.append({"pos": gp, "size": float(fd[2]) * s, "color": FireFx.color_of(String(fd[1])), "kind": String(fd[0])})
			else:
				var g: Array = GLOWS[id]
				glows.append({"pos": gp + Vector3(0, 0.3, 0), "color": g[0], "range": float(g[1]) * s, "energy": float(g[2]),
					"kind": String(g[3])})
	# Мосты — свои меши участков (редактор объектов DungeonEditor прячет склеенные объекты, мосты остаются)
	var bridge_zones := {}
	placed += _bridge_decks(world, holder, fallback, bridge_zones)
	for key in zones:
		_zone_mesh(holder, zones[key])
	for key in bridge_zones:
		_zone_mesh(holder, bridge_zones[key], "Bridges")
	holder.set_meta("placed", placed)
	holder.set_meta("lights", lights)
	world.set_meta("dg_fires", fires)
	world.set_meta("dg_glows", glows)


## Точка основания записи раскладки: 6-е поле — сдвиг по высоте от рельефа, а при 8-м поле 1 — точная высота в
## мире (корабль, вещи на палубе, причалы: их высоту задаёт поверхность палубы и настил, а не сетка рельефа).
static func base_pos(world: IslandWorld, a: Array) -> Vector3:
	var x := float(a[1])
	var z := float(a[2])
	var dy := float(a[5]) if a.size() > 5 else 0.0
	if a.size() > 7 and int(a[7]) == 1:
		return Vector3(x, dy, z)
	return Vector3(x, world.height_at(x, z) - 0.04 + dy, z)


## Одна модель: в меш участка (или запасная из примитивов) и коллизия: форма по модели из конфига ("prop_shapes" —
## призма по следу ниже роста героя или столб мачты, сцена Blender), иначе у solid — коробка по габаритам.
static func _place(world: DungeonWorld, holder: Node3D, fallback: Node3D, zones: Dictionary, id: String, pos: Vector3,
		yaw: float, s: float, solid: bool, sy: float = 1.0, tilt := Basis.IDENTITY) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw) * tilt * Basis.from_scale(Vector3(s, s * sy, s)), pos)
	var size := PropAsset.size(id) * s if PropAsset.has(id) else _fallback_size(id) * s
	size.y *= sy
	if PropAsset.has(id):
		var m := mesh_of(world, id)
		if m != null:
			var key := Vector2i(floori(pos.x / zone_size), floori(pos.z / zone_size))
			if not zones.has(key):
				var zn := Zone.new()
				zn.origin = Vector3((float(key.x) + 0.5) * zone_size, 0.0, (float(key.y) + 0.5) * zone_size)
				zones[key] = zn
			var zone: Zone = zones[key]
			var pg := PropAsset.page(id)
			if not zone.items.has(pg):
				zone.items[pg] = []
			(zone.items[pg] as Array).append([m, Transform3D(Basis.IDENTITY, -zone.origin) * xf])
	else:
		_fallback(fallback, id, xf, _fallback_size(id))
	var shapes: Dictionary = world.cfg.get("prop_shapes", {})
	if shapes.has(id):
		holder.add_child(shape_body(id, shapes[id], pos, yaw, s, sy))
		return
	if solid and not world.cfg.has("prop_shapes"):
		var body := StaticBody3D.new()
		body.name = id
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = pos
		body.rotation.y = yaw
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(size.x * COLLIDE_K, maxf(size.y, 1.2), size.z * COLLIDE_K)
		col.shape = box
		col.position.y = box.size.y * 0.5
		body.add_child(col)
		holder.add_child(body)


## Наклон записи раскладки (9-е и 10-е поля — повороты вокруг осей модели X и Z, °: факелы, фонари, сети на наклонной
## скале — тыльной стороной вдоль неё, сцена Blender).
static func tilt_of(a: Array) -> Basis:
	if a.size() < 10:
		return Basis.IDENTITY
	return Basis(Vector3.RIGHT, deg_to_rad(float(a[8]))) * Basis(Vector3.BACK, deg_to_rad(float(a[9])))


## Тело коллизии по форме модели: {"hull": [[x, z], …] (модель), "h": высота модели} — выпуклая призма от
## основания до высоты модели (не ниже 1.2 м), или {"pole": [x, z, радиус]} — столб (мачта).
static func shape_body(id: String, sh: Dictionary, pos: Vector3, yaw: float, s: float, sy: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = id
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	body.rotation.y = yaw
	var h := maxf(float(sh.get("h", 1.0)) * s * sy, 1.2)
	var col := CollisionShape3D.new()
	if sh.has("pole"):
		var pl: Array = sh["pole"]
		var cap := CapsuleShape3D.new()
		cap.radius = float(pl[2]) * s
		cap.height = maxf(h, cap.radius * 2.0 + 0.1)
		col.shape = cap
		col.position = Vector3(float(pl[0]) * s, h * 0.5, float(pl[1]) * s)
	else:
		var pts := PackedVector3Array()
		for q in sh.get("hull", []):
			var a: Array = q
			pts.append(Vector3(float(a[0]) * s, 0.0, float(a[1]) * s))
			pts.append(Vector3(float(a[0]) * s, h, float(a[1]) * s))
		var cv := ConvexPolygonShape3D.new()
		cv.points = pts
		col.shape = cv
	body.add_child(col)
	return body


## Меш модели id с вырезами из конфига мира (нет вырезов — общий меш PropAsset).
static func mesh_of(world: IslandWorld, id: String) -> Mesh:
	var base := PropAsset.mesh(id)
	var cuts: Dictionary = world.cfg.get("prop_cuts", {}) if world != null else {}
	if base == null or not cuts.has(id):
		return base
	var key := "%s:%d" % [id, str(cuts[id]).hash()]
	if not _cut_meshes.has(key):
		_cut_meshes[key] = cut_mesh(base, cuts[id])
	return _cut_meshes[key]


## Копия меша без треугольников, чей центр внутри одной из коробок [x0, y0, z0, x1, y1, z1] (7-е поле — ось 1/2/3:
## только грани, смотрящие вдоль этой оси, |нормаль| > 0.7 — торцевые переборки корабля на стыках частей, 0.35.4).
static func cut_mesh(base: Mesh, boxes: Array) -> ArrayMesh:
	var out := ArrayMesh.new()
	for si in base.get_surface_count():
		var arr := base.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		if idx.is_empty():
			idx.resize(v.size())
			for k in v.size():
				idx[k] = k
		var keep := PackedInt32Array()
		for t in range(0, idx.size() - 2, 3):
			var a := v[idx[t]]
			var b := v[idx[t + 1]]
			var e := v[idx[t + 2]]
			var c := (a + b + e) / 3.0
			var nrm := (b - a).cross(e - a).normalized()
			var inside := false
			for bx in boxes:
				var q: Array = bx
				if c.x >= float(q[0]) and c.y >= float(q[1]) and c.z >= float(q[2]) \
						and c.x <= float(q[3]) and c.y <= float(q[4]) and c.z <= float(q[5]):
					if q.size() > 6 and int(q[6]) > 0 and absf(nrm[int(q[6]) - 1]) <= 0.7:
						continue
					inside = true
					break
			if not inside:
				keep.append(idx[t])
				keep.append(idx[t + 1])
				keep.append(idx[t + 2])
		arr[Mesh.ARRAY_INDEX] = keep
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return out


static func _zone_mesh(holder: Node3D, zone: Zone, node_name := "Props") -> void:
	var mesh := ArrayMesh.new()
	for pg in zone.items:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for it in zone.items[pg]:
			var e: Array = it
			st.append_from(e[0] as Mesh, 0, e[1] as Transform3D)
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, PropAsset.material(String(pg)))
	if mesh.get_surface_count() == 0:
		return
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = zone.origin
	mi.set_meta("no_outline", true)
	# «В подземелье»: участок дальше дальности от камеры не рисуется
	var view := Quality.dungeon_range()
	if view > 0.0:
		mi.visibility_range_end = view + zone_size * 0.71 + VIEW_CAMERA
	holder.add_child(mi)


## Мосты и мостки — модель верёвочного моста вдоль настила (растянута по длине и ширине, наклон — от конца к концу
## по профилю настила IslandWorld.bridge_point).
## Настил и коллизия — свои (IslandWorld._build_bridges), их доски скрыты.
static func _bridge_decks(world: DungeonWorld, holder: Node3D, fallback: Node3D, zones: Dictionary) -> int:
	# Свои мосты (0.35.4, Максим: «нарисуй мосты сам и натяни текстуры»): одна модель в координатах мира — доски
	# поперёк, балки, сваи до дна, перила и верёвка по профилю настила (сцена Blender)
	var own := String(world.cfg.get("bridge_model", ""))
	if own != "" and PropAsset.has(own) and PropAsset.mesh(own) != null:
		var mi := MeshInstance3D.new()
		mi.name = "Bridges"
		mi.mesh = PropAsset.mesh(own)
		mi.material_override = PropAsset.material(PropAsset.page(own))
		mi.set_meta("no_outline", true)
		holder.add_child(mi)
		_hide_plain_decks(world)
		return world.bridges.size()
	if not PropAsset.has(BRIDGE_PROP):
		return 0
	var sz := PropAsset.size(BRIDGE_PROP)
	var n := 0
	for br in world.bridges:
		var a: Vector3 = br["a"]
		var b: Vector3 = br["b"]
		var flat := Vector2(b.x - a.x, b.z - a.z)
		var length := flat.length()
		# Одна модель на мост: модель верёвочного моста провисает и у неё на концах столбы без досок — пролётами
		# выходила пила с щелями (проверено на скриншотах 0.35.1)
		var spans := 1
		var yaw := atan2(flat.x, flat.y)
		var seg := length / float(spans)
		for si in spans:
			var t0 := float(si) / float(spans)
			var t1 := float(si + 1) / float(spans)
			var p0 := IslandWorld.bridge_point(br, t0)
			var p1 := IslandWorld.bridge_point(br, t1)
			var mid := (p0 + p1) * 0.5
			var pitch := -atan2(p1.y - p0.y, seg)
			var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
			var sc := Vector3(float(br["width"]) / sz.x * 1.05, 1.0, seg / sz.z * 1.04)
			var xf := Transform3D(basis * Basis.from_scale(sc), Vector3(mid.x, mid.y - BRIDGE_SINK, mid.z))
			var key := Vector2i(floori(mid.x / zone_size), floori(mid.z / zone_size))
			if not zones.has(key):
				var zn := Zone.new()
				zn.origin = Vector3((float(key.x) + 0.5) * zone_size, 0.0, (float(key.y) + 0.5) * zone_size)
				zones[key] = zn
			var zone: Zone = zones[key]
			var pg := PropAsset.page(BRIDGE_PROP)
			if not zone.items.has(pg):
				zone.items[pg] = []
			(zone.items[pg] as Array).append([PropAsset.mesh(BRIDGE_PROP), Transform3D(Basis.IDENTITY, -zone.origin) * xf])
			n += 1
	_hide_plain_decks(world)
	return n


## Свой настил (светлые доски) под моделью моста не виден: коллизия остаётся.
static func _hide_plain_decks(world: DungeonWorld) -> void:
	for node in world.get_children():
		if node is StaticBody3D and node.is_in_group("bridges"):
			for c in node.get_children():
				if c is MeshInstance3D:
					(c as MeshInstance3D).visible = false


static func _light(holder: Node3D, id: String, pos: Vector3, s: float) -> void:
	var l: Array = LIGHTS[id]
	var om := OmniLight3D.new()
	om.name = "Light_" + id
	om.light_color = l[0]
	om.light_energy = float(l[1])
	om.omni_range = float(l[2]) * s
	om.shadow_enabled = false
	var h := (PropAsset.size(id).y if PropAsset.has(id) else 1.5) * s
	om.position = pos + Vector3(0, h * float(l[3]) + 0.3, 0)
	holder.add_child(om)


# ---------- Запасные модели (без части пакета) ----------

static func _fallback_size(id: String) -> Vector3:
	match id:
		"dg_ship_deck", "dg_ship_bow", "dg_wreck":
			return Vector3(10, 4, 5)
		"dg_coral_altar":
			return Vector3(7, 5, 7)
		"dg_spire", "dg_obelisk", "dg_mast", "dg_crows_nest":
			return Vector3(1.6, 4.0, 1.6)
		"dg_cliffs", "dg_cavern", "dg_mine":
			return Vector3(5, 3, 3)
	return Vector3(1.2, 1.2, 1.2)


static func _fallback_kind(id: String) -> String:
	for k in ["crystal", "candles", "brazier", "torch", "lantern", "spiral", "rune", "altar", "glowcaps", "coral"]:
		if id.contains(k):
			return "glow"
	for k in ["gold", "chest", "hoard", "spoils"]:
		if id.contains(k):
			return "gold"
	for k in ["remains", "mariner", "leviathan", "totem"]:
		if id.contains(k):
			return "bone"
	for k in ["crag", "stones", "spire", "cliffs", "cavern", "mine", "obelisk", "monolith", "ascent", "dripstone", "ring"]:
		if id.contains(k):
			return "rock"
	return "wood"


static func _fallback(parent: Node3D, id: String, xf: Transform3D, size: Vector3) -> void:
	var kind := _fallback_kind(id)
	var mi := MeshInstance3D.new()
	mi.name = id
	var m: PrimitiveMesh
	if kind == "rock" or kind == "glow":
		var c := CylinderMesh.new()
		c.top_radius = minf(size.x, size.z) * (0.25 if kind == "rock" else 0.35)
		c.bottom_radius = minf(size.x, size.z) * 0.5
		c.height = size.y
		c.radial_segments = 7
		m = c
	else:
		var b := BoxMesh.new()
		b.size = size
		m = b
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = FALLBACK_COLORS[kind]
	if kind == "glow" or kind == "gold":
		mat.emission_enabled = true
		mat.emission = FALLBACK_COLORS[kind]
		mat.emission_energy_multiplier = 0.8
	mi.material_override = mat
	mi.transform = xf * Transform3D(Basis.IDENTITY, Vector3(0, size.y * 0.5, 0))
	parent.add_child(mi)
