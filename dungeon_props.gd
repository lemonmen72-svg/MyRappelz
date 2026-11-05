class_name DungeonProps
extends RefCounted
## Объекты подземелья (DungeonWorld): модели Максима из папки «ДАНЖ» (assets/props/dg_*.glb, атласы props_dg_*.png —
## tools/prepare_props.py) по списку world/dungeon.json "props" ([id, x, z, поворот°, масштаб, сдвиг по высоте]) и
## верёвочные мосты пролётами по настилу мостов. Камней на скальной стене нет (0.35.1, Максим: «камни со стен убрать»).
## Экземпляры склеиваются в меши участков ZONE м по странице атласа (один материал страницы — prop.gdshader), как
## постройки острова (IslandPois). Коллизия — коробка по габаритам модели × COLLIDE_K у крупных (SOLID), мелочь и
## лежащее на полу (ковры, кости, золото) — без коллизии. Огни — OmniLight3D у главных источников (LIGHTS, не больше
## MAX_LIGHTS: в Compatibility свет на объект ограничен), без теней. Без части пакета — запасные коробки и столбы
## из примитивов (FALLBACK_COLORS), подземелье проходимо и узнаваемо.

const ZONE := 40.0
const COLLIDE_K := 0.8
## Крупное и твёрдое — с коллизией (коробка).
const SOLID := ["dg_spire", "dg_crag", "dg_moss_stones", "dg_amethyst_spires", "dg_crystal_purple", "dg_crystal_blue",
	"dg_tent", "dg_cauldron", "dg_chest", "dg_chest_open", "dg_crates", "dg_barrel", "dg_bell", "dg_palisade",
	"dg_barricade", "dg_spikes", "dg_barricade_moss", "dg_totem", "dg_table", "dg_prison", "dg_armory", "dg_obelisk",
	"dg_monolith", "dg_crypt_altar", "dg_witch_brazier", "dg_throne", "dg_oracle", "dg_coral_altar", "dg_mine",
	"dg_cannon", "dg_relics", "dg_hoard", "dg_brazier", "dg_siren", "dg_mast", "dg_crows_nest",
	"dg_helm", "dg_leviathan", "dg_cavern", "dg_cliffs", "dg_dripstone"]
const MAX_LIGHTS := 10
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

class Zone:
	var origin := Vector3.ZERO
	## страница → [[меш, преобразование относительно origin]]
	var items := {}


static func build(world: DungeonWorld, _rng: RandomNumberGenerator) -> void:
	var holder := Node3D.new()
	holder.name = "DungeonProps"
	world.add_child(holder)
	var zones := {}
	var fallback := Node3D.new()
	fallback.name = "Fallback"
	holder.add_child(fallback)
	var lights := 0
	var placed := 0
	for e in world.cfg.get("props", []):
		var a: Array = e
		var id := String(a[0])
		var x := float(a[1])
		var z := float(a[2])
		var yaw := deg_to_rad(float(a[3]) if a.size() > 3 else 0.0)
		var s := float(a[4]) if a.size() > 4 else 1.0
		# 6-е поле — сдвиг по высоте (корабль и причалы: их палуба — вровень с палубой-островом, где ходит герой)
		var dy := float(a[5]) if a.size() > 5 else 0.0
		var pos := Vector3(x, world.height_at(x, z) - 0.04 + dy, z)
		_place(world, holder, fallback, zones, id, pos, yaw, s, SOLID.has(id))
		placed += 1
		if LIGHTS.has(id) and lights < MAX_LIGHTS:
			_light(holder, id, pos, s)
			lights += 1
	placed += _bridge_decks(world, holder, fallback, zones)
	for key in zones:
		_zone_mesh(holder, zones[key])
	holder.set_meta("placed", placed)
	holder.set_meta("lights", lights)


## Одна модель: в меш участка (или запасная из примитивов) и, если solid, коробка коллизии.
static func _place(world: DungeonWorld, holder: Node3D, fallback: Node3D, zones: Dictionary, id: String, pos: Vector3,
		yaw: float, s: float, solid: bool) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s)), pos)
	var size := PropAsset.size(id) * s if PropAsset.has(id) else _fallback_size(id) * s
	if PropAsset.has(id):
		var m := PropAsset.mesh(id)
		if m != null:
			var key := Vector2i(floori(pos.x / ZONE), floori(pos.z / ZONE))
			if not zones.has(key):
				var zn := Zone.new()
				zn.origin = Vector3((float(key.x) + 0.5) * ZONE, 0.0, (float(key.y) + 0.5) * ZONE)
				zones[key] = zn
			var zone: Zone = zones[key]
			var pg := PropAsset.page(id)
			if not zone.items.has(pg):
				zone.items[pg] = []
			(zone.items[pg] as Array).append([m, Transform3D(Basis.IDENTITY, -zone.origin) * xf])
	else:
		_fallback(fallback, id, xf, _fallback_size(id))
	if solid:
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


static func _zone_mesh(holder: Node3D, zone: Zone) -> void:
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
	mi.name = "Props"
	mi.mesh = mesh
	mi.position = zone.origin
	mi.set_meta("no_outline", true)
	holder.add_child(mi)


## Мосты и мостки — модель верёвочного моста вдоль настила (растянута по длине и ширине, наклон — от конца к концу
## по профилю настила IslandWorld.bridge_point).
## Настил и коллизия — свои (IslandWorld._build_bridges), их доски скрыты.
static func _bridge_decks(world: DungeonWorld, holder: Node3D, fallback: Node3D, zones: Dictionary) -> int:
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
			var key := Vector2i(floori(mid.x / ZONE), floori(mid.z / ZONE))
			if not zones.has(key):
				var zn := Zone.new()
				zn.origin = Vector3((float(key.x) + 0.5) * ZONE, 0.0, (float(key.y) + 0.5) * ZONE)
				zones[key] = zn
			var zone: Zone = zones[key]
			var pg := PropAsset.page(BRIDGE_PROP)
			if not zone.items.has(pg):
				zone.items[pg] = []
			(zone.items[pg] as Array).append([PropAsset.mesh(BRIDGE_PROP), Transform3D(Basis.IDENTITY, -zone.origin) * xf])
			n += 1
	# Свой настил (светлые доски) под моделью не виден: коллизия остаётся
	for node in world.get_children():
		if node is StaticBody3D and node.is_in_group("bridges"):
			for c in node.get_children():
				if c is MeshInstance3D:
					(c as MeshInstance3D).visible = false
	return n


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
