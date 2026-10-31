class_name PropAsset
extends RefCounted
## Объекты локации из файлов: модели Meshy от Максима, переработанные tools/prepare_props.py
## (assets/props/<id>.glb — упрощённый меш, UV сразу в атласе страницы; props_<страница>.png — атлас;
## props.json — размеры, страница, точки: «lamp» — фонарь, «glow» — центр свечения, «front» — самая
## передняя точка, у башни мельницы — ступица крыльев).
## Если файла нет (или PropAsset.enabled = false), IslandPois и IslandVegetation ставят процедурные
## модели PoiModels / свои — они остаются запасом.
##
## Материал — prop.gdshader: атлас страницы, cel-shading, свечение из альфы цвета вершин. Все объекты
## страницы — один материал, поэтому экземпляры склеиваются (IslandPois — по зонам, IslandVegetation —
## по участкам) в одну поверхность на страницу. Меш одного id загружается один раз (кэш).
## Оси модели как у PoiModels: низ на y = 0, фасад (дверь) на +Z; корабль — ватерлиния y = 0, нос на −Z.

const DIR := "res://assets/props/"
const SHADER := "res://prop.gdshader"
const META := "res://assets/props/props.json"

## Процедурная модель PoiModels (вид в get_kit) → [id модели из файла, масштаб].
const KINDS := {
	"town_house": ["town_house", 1.0],
	"town_house_b": ["town_house_b", 1.0],
	"town_hall": ["town_hall", 1.0],
	"town_gate": ["town_gate", 1.0],
	"well": ["well", 1.0],
	"notice_board": ["notice_board", 1.0],
	"merchant_stall": ["merchant_stall", 1.0],
	"lantern_town": ["lantern_town", 1.0],
	"weapon_rack": ["weapon_rack", 1.0],
	"dummy": ["training_dummy", 1.0],
	"crate": ["crate", 1.0],
	"barrel": ["barrel", 1.0],
	"human_house_thatch": ["human_house_thatch", 1.0],
	"human_house_red": ["human_house_red", 1.0],
	"windmill": ["windmill_tower", 1.0],
	"windmill_sails": ["windmill_sails", 1.0],
	"scarecrow": ["scarecrow", 1.0],
	"hay": ["hay_bale", 1.0],
	"trough": ["trough", 1.0],
	"light_elf_house": ["light_elf_house", 1.0],
	"light_elf_tower": ["light_elf_tower", 1.0],
	"lantern_elf": ["lantern_elf", 1.0],
	"crystals_blue": ["crystal_blue", 1.0],
	"crystals_blue_big": ["crystal_blue", 2.2],
	"crystals_gold": ["crystal_gold", 1.0],
	"dark_elf_house": ["dark_elf_house", 1.0],
	"dark_elf_tower": ["dark_elf_tower", 1.0],
	"dark_spire": ["dark_spire", 1.0],
	"brazier_dark": ["brazier_dark", 1.0],
	"crystals_purple": ["crystal_purple", 1.0],
	"crystals_purple_big": ["crystal_purple", 2.2],
	"lighthouse": ["lighthouse", 1.0],
	"ship": ["ship", 1.0],
	"bollard": ["bollard", 1.0],
	"dock_crates": ["dock_crates", 1.0],
	"tent_bell": ["tent_bell", 1.0],
	"tent_ridge": ["tent_ridge", 1.0],
	"campfire": ["campfire", 1.0],
	"cave_entrance": ["cave_entrance", 1.0],
	"rock": ["rock", 1.0],
	"rock_dark": ["rock_dark", 1.0],
}

## Модели из файлов включены (тесты могут выключить, чтобы сравнить с процедурными).
static var enabled := true
static var _meta := {}
static var _meta_loaded := false
static var _meshes := {}
static var _bases := {}
static var _mats := {}
## Материалы мелочей зон: контур включается по качеству (apply_quality).
static var _near_mats: Array[ShaderMaterial] = []


static func _load_meta() -> void:
	if _meta_loaded:
		return
	_meta_loaded = true
	if not FileAccess.file_exists(META):
		return
	var f := FileAccess.open(META, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		_meta = data


## Запись модели из props.json (пусто — нет).
static func info(id: String) -> Dictionary:
	_load_meta()
	var props: Dictionary = _meta.get("props", {})
	return props.get(id, {})


## Есть ли модель id из файла.
static func has(id: String) -> bool:
	if not enabled or info(id).is_empty():
		return false
	return ResourceLoader.exists(DIR + id + ".glb")


## Модель из файла для процедурного вида PoiModels ("" — нет, ставить процедурную).
static func for_kind(kind: String) -> String:
	if not KINDS.has(kind):
		return ""
	var e: Array = KINDS[kind]
	var id := String(e[0])
	return id if has(id) else ""


## Масштаб модели для процедурного вида (крупные кристаллы-монументы — та же друза крупнее).
static func kind_scale(kind: String) -> float:
	if not KINDS.has(kind):
		return 1.0
	var e: Array = KINDS[kind]
	return float(e[1])


## Габариты модели (м).
static func size(id: String) -> Vector3:
	var a: Array = info(id).get("size", [1, 1, 1])
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


## Точка модели из props.json (координаты модели) или def, если её нет.
static func marker(id: String, key: String, def: Vector3) -> Vector3:
	var mk: Dictionary = info(id).get("markers", {})
	if not mk.has(key):
		return def
	var a: Array = mk[key]
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


## Страница атласа модели.
static func page(id: String) -> String:
	return String(info(id).get("page", ""))


## Меш модели (общий ресурс на все экземпляры).
static func mesh(id: String) -> Mesh:
	if _meshes.has(id):
		return _meshes[id]
	var m: Mesh = null
	var ps := load(DIR + id + ".glb") as PackedScene
	if ps != null:
		var root := ps.instantiate()
		var mis := root.find_children("*", "MeshInstance3D", true, false)
		if root is MeshInstance3D:
			mis.push_front(root)
		if not mis.is_empty():
			m = (mis[0] as MeshInstance3D).mesh
		root.free()
	_meshes[id] = m
	return m


## Вершины основания модели (ниже h над низом модели, координаты модели) — корни дерева, низ камня или куста.
static func base_points(id: String, h: float = 0.1) -> PackedVector3Array:
	var key := "%s|%.3f" % [id, h]
	if _bases.has(key):
		return _bases[key]
	var out := PackedVector3Array()
	var m := mesh(id)
	if m != null and m.get_surface_count() > 0:
		var arr := m.surface_get_arrays(0)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var lo := INF
		for i in verts.size():
			lo = minf(lo, verts[i].y)
		for i in verts.size():
			if verts[i].y < lo + h:
				out.append(verts[i])
	_bases[key] = out
	return out


## Радиус основания модели (м, по X/Z от оси): насколько далеко от ствола касаются земли корни.
static func base_radius(id: String, h: float = 0.1) -> float:
	var r := 0.0
	var pts := base_points(id, h)
	for i in pts.size():
		r = maxf(r, Vector2(pts[i].x, pts[i].z).length())
	return r


## Материал страницы атласа (prop.gdshader, общий). outline.a > 0 — контур (veg_outline.gdshader:
## раздувание по нормали, работает и у склеенных мешей) цвета outline толщиной width.
static func material(pg: String, outline: Color = Color(0, 0, 0, 0), width: float = 0.0) -> ShaderMaterial:
	var key := "%s|%s|%.3f" % [pg, outline.to_html(), width]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = load(SHADER) as Shader
	_load_meta()
	var pages: Dictionary = _meta.get("pages", {})
	var pinfo: Dictionary = pages.get(pg, {})
	var path := DIR + String(pinfo.get("file", "props_%s.png" % pg))
	if ResourceLoader.exists(path):
		m.set_shader_parameter("albedo_tex", load(path) as Texture2D)
	m.set_meta("toon_done", true)
	if outline.a > 0.0:
		var om := ShaderMaterial.new()
		om.shader = load("res://veg_outline.gdshader") as Shader
		om.set_shader_parameter("color", outline)
		om.set_shader_parameter("width", width)
		m.next_pass = om
		m.set_meta("outline", om)
	_mats[key] = m
	return m


## Материал мелочей зоны (как "toon_ol" у PoiModels): контур — только если включён в качестве.
static func near_material(pg: String) -> ShaderMaterial:
	var m := material(pg, Color(0.12, 0.09, 0.08, 1.0), 0.012)
	if not _near_mats.has(m):
		_near_mats.append(m)
	m.next_pass = (m.get_meta("outline") as Material) if Quality.outlines() else null
	return m


## Качество без перестройки острова: контуры мелочей зон.
static func apply_quality() -> void:
	for m in _near_mats:
		m.next_pass = (m.get_meta("outline") as Material) if Quality.outlines() else null
