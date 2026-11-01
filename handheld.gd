class_name Handheld
extends RefCounted
## Оружие и предметы в руках из файлов (модели Meshy Максима, конвейер tools/prepare_handheld.py):
## assets/handheld/<id>.glb (меш без материала) + <id>.png (текстура), handheld.json — вид, рамка осей, точки.
## Лежат в APK (не в пакете ресурсов): ~10 МБ исходников, без них герой держал бы процедурное оружие.
##
## Контракт осей (шапка tools/prepare_handheld.py): начало координат — точка хвата (центр кулака на рукояти;
## у двуручного — ведущая правая рука, вторая — точка grip2 в handheld.json);
##   frame "blade"    — ось предмета +Y (рукоять → остриё / навершие), плоскость клинка XY, лезвие топора и боёк
##                      молота — к +X (как процедурные мечи CharacterModel под _grip_xf: +X — к костяшкам кулака);
##   frame "bow"      — плечи лука ±Y, тетива к +Z (как _bow_mesh в левой кисти);
##   frame "crossbow" — ложе вдоль −Z (вперёд), верх +Y, кулак под ложем (как _crossbow_mesh под crossbow_rot);
##   frame "shield"   — лицо +Z, верх +Y, ручка за щитом; в левой кисти поворачивается SHIELD_IN_HAND;
##   frame "book"     — обложка +Z, верх +Y, корешок к −X, хват у корешка.
##
## Какая модель у оружия героя: поле "model" предмета ItemData (оружие 2-го ранга и выше — свой файл), иначе модель
## вида по умолчанию KIND_MODELS (оружие 1-го ранга); нет файла — процедурный меш CharacterModel (откат).
## Жители: Handheld.make("npc_cane") — готовый MeshInstance3D (меш, материал, контур), поставить на метку кости
## с поворотом по рамке (grip_xf / hold_basis).

const DIR := "res://assets/handheld/"
const INFO_PATH := "res://assets/handheld/handheld.json"
## Модель вида оружия ItemData по умолчанию (1-й ранг). Пары («daggers» …) — по одиночному виду (ItemData.single_kind).
## Лука среди оружия Максима нет — у героев лук жителя «Огненный длинный лук» (npc_longbow).
const KIND_MODELS := {
	"sword_1h": "weapon_sword_1h_r1",
	"sword_2h": "weapon_sword_2h_r1",
	"dagger": "weapon_dagger_r1",
	"mace_1h": "weapon_mace_1h_r1",
	"mace_2h": "weapon_mace_2h_r1",
	"axe_1h": "weapon_axe_1h_r1",
	"axe_2h": "weapon_axe_2h_r1",
	"staff_1h": "weapon_staff_1h_r1",
	"staff_2h": "weapon_staff_2h_r1",
	"spear": "weapon_spear_r1",
	"crossbow": "weapon_crossbow_r1",
	"bow": "npc_longbow",
	"shield": "weapon_shield_r1",
}
## Вид модели CharacterModel (spec "weapon") → вид оружия ItemData, если предмет и вид не заданы (превью, тесты):
## одноручное по умолчанию, посох — двуручный (как у профессий).
const MODEL_KINDS := {
	"sword": "sword_1h", "dual_swords": "sword_1h", "dagger": "dagger", "daggers": "dagger", "axe": "axe_1h",
	"dual_axes": "axe_1h", "mace": "mace_1h", "staff": "staff_2h", "spear": "spear", "crossbow": "crossbow",
	"bow": "bow",
}
## Щит из файла (лицо +Z, верх +Y) в левой кисти под _grip_xf: лицо — к −Z (тыльная сторона кисти, наружу),
## верх — к −X (от костяшек к локтю, вдоль предплечья). Столбцы — куда идут оси X, Y, Z файла.
const SHIELD_IN_HAND := Basis(Vector3(0, -1, 0), Vector3(-1, 0, 0), Vector3(0, 0, -1))
## Толщина контура предмета (тоньше, чем у героя: рукояти в 2–3 см).
const OUTLINE_WIDTH := 0.006

## Тест: вести себя так, будто файлов нет (откат на процедурные модели).
static var force_missing := false
static var _info: Dictionary = {}
static var _info_loaded := false
static var _meshes: Dictionary = {}
static var _mats: Dictionary = {}
static var _outline: ShaderMaterial = null


## Все предметы handheld.json: id → {kind, frame, length, size, min, max, grip, grip2, tip, butt, tris, …}.
static func items() -> Dictionary:
	if not _info_loaded:
		_info_loaded = true
		if FileAccess.file_exists(INFO_PATH):
			var f := FileAccess.open(INFO_PATH, FileAccess.READ)
			if f != null:
				var d: Variant = JSON.parse_string(f.get_as_text())
				if d is Dictionary:
					var it: Variant = (d as Dictionary).get("items", {})
					if it is Dictionary:
						_info = it
	return _info


static func info(id: String) -> Dictionary:
	var d: Variant = items().get(id, {})
	return d if d is Dictionary else {}


## Модель есть (файл и запись в handheld.json).
static func exists(id: String) -> bool:
	if force_missing or id == "":
		return false
	return items().has(id) and ResourceLoader.exists(DIR + id + ".glb")


## Рамка осей модели ("blade", "bow", "crossbow", "shield", "book").
static func frame(id: String) -> String:
	return String(info(id).get("frame", "blade"))


## Точка из handheld.json ("grip2", "tip", "butt"; нет — def).
static func point(id: String, key: String, def: Vector3 = Vector3.ZERO) -> Vector3:
	var v: Variant = info(id).get(key, null)
	if v is Array and (v as Array).size() == 3:
		var a: Array = v
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return def


## Вид оружия ItemData для модели: weapon_type — вид из spec (sword_2h, daggers …), иначе по виду модели CharacterModel.
static func item_kind(weapon_type: String, model_kind: String) -> String:
	if ItemData.WEAPON_KINDS.has(weapon_type):
		return ItemData.single_kind(weapon_type)
	return String(MODEL_KINDS.get(model_kind, ""))


## Какая модель у предмета item_id (поле "model" предмета, иначе вид предмета → KIND_MODELS); без предмета — по виду
## kind. "" — файла нет (держать процедурную модель).
static func model_for(item_id: String, kind: String = "") -> String:
	var id := ""
	var k := kind
	if item_id != "":
		var it := ItemData.get_item(item_id)
		id = String(it.get("model", ""))
		var wk := String(it.get("weapon", ""))
		if wk != "":
			k = ItemData.single_kind(wk)
	if id == "" or not exists(id):
		id = String(KIND_MODELS.get(k, ""))
	return id if exists(id) else ""


## Меш модели (общий ресурс).
static func mesh(id: String) -> Mesh:
	if not exists(id):
		return null
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


## Материал модели (общий): текстура, cel-свет как у героя из файла, двусторонний, контур по нормалям.
static func material(id: String) -> StandardMaterial3D:
	if _mats.has(id):
		return _mats[id]
	var m := StandardMaterial3D.new()
	m.metallic = 0.0
	var tex_path := DIR + id + ".png"
	if ResourceLoader.exists(tex_path):
		m.albedo_texture = load(tex_path) as Texture2D
	m.albedo_color = Color.WHITE
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	Util.toon(m)
	Quality.track_model(m, outline())
	m.set_meta("toon_done", true)
	_mats[id] = m
	return m


static func outline() -> ShaderMaterial:
	if _outline == null:
		var sh := Shader.new()
		sh.code = CharacterModel.ASSET_OUTLINE_SHADER
		_outline = ShaderMaterial.new()
		_outline.shader = sh
		_outline.set_shader_parameter("width", OUTLINE_WIDTH)
	return _outline


## Готовый узел модели: меш, материал, метка "handheld" = id (тесты). null — файла нет.
static func make(id: String) -> MeshInstance3D:
	var me := mesh(id)
	if me == null:
		return null
	var w := MeshInstance3D.new()
	w.name = id
	w.mesh = me
	w.material_override = material(id)
	w.set_meta("no_toon", true)
	w.set_meta("handheld", id)
	return w


## Поворот модели в кисти поверх хвата CharacterModel (_grip_xf / crossbow_rot): у щита — SHIELD_IN_HAND.
static func hold_basis(id: String) -> Basis:
	return SHIELD_IN_HAND if frame(id) == "shield" else Basis.IDENTITY
