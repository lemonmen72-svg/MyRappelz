class_name CharacterModel
extends Node3D
## Аниме-гуманоид из примитивов (cel-shading, контур): крупная голова, большие глаза, причёска по расе,
## одежда и оружие по классу. Временная модель до замены на аватары из VRoid.
## Рост ~1.8 м, ноги на y = 0, лицом к -Z.
## Если в параметрах есть "asset" (путь к glTF), вместо примитивов берётся готовая модель из файла
## со своим скелетом и анимациями (Meshy/Mixamo), см. раздел «Готовая модель из файла».
##
## Использование:
##   var m := CharacterModel.new()
##   m.setup(CharacterModel.spec_for(race_id, class_id))   # или merchant_spec()
##   add_child(m)
## Анимации кодом: дыхание и моргание в покое, ходьба (set_move_speed), play_attack() (по оружию),
## play_shoot(), play_cast(), play_buff(), play_bash(), play_spin(), play_hit(), play_wave();
## волосы, плащ и шарф покачиваются сами.
##
## Скелет узлов (анимация): Root (отдача при уроне) → LegL/LegR (от бедра), Torso (от бедра) → Head,
## ArmL/ArmR (от плеча) → GripL/GripR (кисть, оружие вдоль +Y). Плечо повёрнуто по X > 0 — рука вперёд.
##
## Отрисовка (бюджет телефона): узлы-кости — пустые Node3D, их анимируют код и твины. Все детали
## склеены в один меш с жёсткой привязкой к костям (Skeleton3D, вес 1 на кость) и цветами вершин:
## Body — всё освещаемое (1 материал, 1 контур), Glow — светящиеся детали (без освещения), Face — лицо.
## Каждый кадр позы костей скелета копируются из узлов (_sync_bones). Итого 2–4 вызова отрисовки
## на персонажа (+1 на контур). Геометрия кэшируется по параметрам внешности.

## Высота бёдер над землёй.
const HIP_Y := 0.9
## Плечи и центр головы — относительно бёдер (узел Torso).
const SHOULDER_Y := 0.46
const SHOULDER_X := 0.215
const HEAD_Y := 0.69
const HEAD_R := 0.2
## Толщина контура: основной и для мелких деталей (0 — без контура).
## Хранится в альфе цвета вершины как доля от OL.
const OL := 0.017
const OL_THIN := 0.01
const FLASH := Color(1.0, 0.32, 0.28)
const FACE_SEG := 14
const LASH := Color(0.12, 0.07, 0.1)
const GOLD := Color(0.95, 0.78, 0.35)
## Виды деталей: освещаемые, светящиеся, полупрозрачное свечение.
const SOLID := 0
const GLOW := 1
const HALO := 2
## Рамка для отсечения (кости двигаются: поднятый посох, взмах рук).
const CULL_AABB := AABB(Vector3(-1.7, -0.3, -1.7), Vector3(3.4, 4.0, 3.4))

## Главный герой — модель из файла (тёмная эльфийка-Бродяга). Пока она одна, её получают все расы
## и классы; своя модель расы или класса задаётся полем "model" в ClassData (у класса или расы).
const MAIN_ASSET := "res://assets/characters/dark_elf_wanderer.glb"
## Клипы модели из файла: у каждого действия варианты [клип, с какой секунды, до какой, скорость],
## берётся первый, который есть в модели (наборы анимаций бывают разные). Первыми стоят клипы,
## перенесённые из Quaternius UAL (tools/retarget_animations.py), за ними — прежние клипы Meshy.
## Корневое смещение бёдер по земле убрано (_pin_root), удары идут на месте. Пока действие
## доигрывается, шаг и бег не включаются, поэтому действия короткие (до ~1.5 с).
const ASSET_ACTIONS := {
	"slash": [["sword_slash", 0.0, 1.1, 1.3], ["left_slash", 0.5, 1.4, 1.6], ["attack", 0.2, 1.4, 2.0]],
	"chop": [["sword_attack", 0.1, 1.45, 1.4], ["attack", 0.2, 1.4, 2.0]],
	"combo": [["sword_combo", 0.0, 2.8, 1.8], ["double_combo_attack", 0.0, 2.6, 1.8], ["attack", 0.0, 2.4, 2.0]],
	"spin": [["sword_heavy_combo", 0.0, 2.1, 1.7], ["double_combo_attack", 0.0, 2.6, 1.8],
		["attack", 0.0, 2.4, 2.0]],
	"leap": [["sword_dash", 0.0, 1.3, 1.4], ["standard_forward_charge_inplace", 0.0, 0.63, 1.0],
		["sword_judgment", 0.4, 3.0, 2.0], ["attack", 0.2, 1.4, 2.0]],
	"buff": [["sword_block", 0.0, 1.2, 1.2], ["standard_forward_charge_inplace", 0.0, 0.63, 1.0],
		["attack", 0.2, 1.4, 2.0]],
	"cast": [["cast", 0.1, 1.4, 1.3], ["attack", 0.2, 1.4, 2.0]],
	"wave": [["wave", 0.0, 2.0, 1.2], ["attack", 0.2, 1.4, 2.0]],
	"hit": [["hit", 0.0, 0.33, 0.8], ["hit_reaction", 0.0, 0.45, 1.5]],
	"pickup": [["pickup", 0.2, 2.3, 1.8]],
	"dodge": [["dodge", 0.0, 1.47, 1.3], ["standard_forward_charge_inplace", 0.0, 0.63, 1.0]],
	# Смерть: клип есть, вызвать пока негде (игрок сразу возрождается)
	"death": [["death", 0.0, 2.4, 1.0], ["hit_reaction", 0.0, 1.6, 1.0]],
}
## Покой: свой клип Idle (из Quaternius UAL, цикл). Если его нет (наборы Meshy без Idle) — кадры
## с какой секунды по какую проигрываются туда-обратно (дыхание): спокойная стойка в начале
## прыжка или стойка с мечом в начале «Sword_Judgment».
const ASSET_IDLE := [["idle", 0.0, 2.0, 1.0], ["regular_jump", 0.0, 0.07, 0.0],
	["sword_judgment", 0.0, 0.22, 0.0]]
const ASSET_WALK := [["walking_woman"], ["walking"]]
const ASSET_RUN := [["running"]]
## Рамка отсечения модели из файла (с запасом на прыжок и взмахи); не больше нужного — по ней же
## выбирается уровень детализации меша.
const ASSET_AABB := AABB(Vector3(-1.2, -0.2, -1.2), Vector3(2.4, 2.8, 2.4))
## Скорость, с которой клипы шага и бега выглядят без проскальзывания, м/с.
const WALK_NATIVE := 1.4
const RUN_NATIVE := 4.2
## Доля собственного свечения текстуры модели из файла (подсветка теневой стороны).
const ASSET_GLOW := 0.3
## Меч в правой руке модели из файла (кость RightHand, Mixamo): центр кулака и направление клинка
## (от мизинца к указательному) в пространстве кости.
const GRIP_POS := Vector3(-0.02, 0.072, 0.017)
const GRIP_DIR := Vector3(0.76, 0.12, 0.64)

## Контур модели из файла: оболочка по нормалям, один тёмный цвет.
const ASSET_OUTLINE_SHADER := """shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(0.1, 0.07, 0.12, 1.0);
uniform float width = 0.012;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = length(world - CAMERA_POSITION_WORLD);
	float scale = length(MODEL_MATRIX[0].xyz);
	VERTEX += normalize(NORMAL) * width * clamp(dist / 10.0, 0.6, 3.0) / max(scale, 0.001);
}

void fragment() {
	ALBEDO = color.rgb;
}
"""

## Контур по нормалям («вывернутая оболочка»): у капсул и сфер толщина ровная по всей длине.
## Толщина детали — альфа цвета вершины × width (0 — деталь без контура: вершины стягиваются в точку),
## цвет — тёмный насыщенный оттенок цвета вершины (как Util.outline_mat).
const OUTLINE_SHADER := """shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, fog_disabled;

uniform float width = 0.017;

varying vec3 ol_color;

vec3 rgb2hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 k = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + k.xyz) * 6.0 - k.www);
	return c.z * mix(k.xxx, clamp(p - k.xxx, 0.0, 1.0), c.y);
}

void vertex() {
	float w = COLOR.a * width;
	if (w < 0.0001) {
		VERTEX = vec3(0.0);
	} else {
		vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float dist = length(world - CAMERA_POSITION_WORLD);
		float scale = length(MODEL_MATRIX[0].xyz);
		VERTEX += normalize(NORMAL) * w * clamp(dist / 10.0, 0.6, 3.0) / max(scale, 0.001);
	}
	vec3 hsv = rgb2hsv(COLOR.rgb);
	vec3 c = hsv2rgb(vec3(hsv.x, min(1.0, hsv.y * 1.2 + 0.1), hsv.z * 0.28));
	if (!OUTPUT_IS_SRGB) {
		c = mix(pow((c + vec3(0.055)) * (1.0 / (1.0 + 0.055)), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
	}
	ol_color = c;
}

void fragment() {
	ALBEDO = ol_color;
}
"""


## Накопитель геометрии одной поверхности: вершины в пространстве своей кости, цвет, кость (вес 1).
class GeoBuf:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var idx := PackedInt32Array()
	## Кость для tri() (лицо).
	var tri_bone := 0

	## Добавить меш (массивы PrimitiveMesh.get_mesh_arrays()) с трансформом xf относительно кости.
	func add(a: Array, xf: Transform3D, col: Color, bone: int) -> void:
		var pv: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var pn := PackedVector3Array()
		var an: Variant = a[Mesh.ARRAY_NORMAL]
		if an is PackedVector3Array:
			pn = an
		var n := pv.size()
		var base := verts.size()
		var nb := xf.basis.inverse().transposed()
		var has_n := pn.size() == n
		for i in n:
			verts.append(xf * pv[i])
			var nn: Vector3 = (nb * pn[i]) if has_n else pv[i]
			norms.append(nn.normalized())
			cols.append(col)
			bones.append(bone)
			bones.append(0)
			bones.append(0)
			bones.append(0)
			weights.append(1.0)
			weights.append(0.0)
			weights.append(0.0)
			weights.append(0.0)
		var ia := PackedInt32Array()
		var ai: Variant = a[Mesh.ARRAY_INDEX]
		if ai is PackedInt32Array:
			ia = ai
		if not ia.is_empty():
			for k in ia:
				idx.append(base + k)
		else:
			for k in n:
				idx.append(base + k)

	## Треугольник лица (нормаль — от центра головы).
	func tri(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
		for p in [a, b, c]:
			var v: Vector3 = p
			idx.append(verts.size())
			verts.append(v)
			norms.append(v.normalized())
			cols.append(col)
			bones.append(tri_bone)
			bones.append(0)
			bones.append(0)
			bones.append(0)
			weights.append(1.0)
			weights.append(0.0)
			weights.append(0.0)
			weights.append(0.0)

	func is_empty() -> bool:
		return verts.is_empty()

	## Добавить накопленное поверхностью в меш.
	func commit(mesh: ArrayMesh) -> void:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = norms
		arr[Mesh.ARRAY_COLOR] = cols
		arr[Mesh.ARRAY_BONES] = bones
		arr[Mesh.ARRAY_WEIGHTS] = weights
		arr[Mesh.ARRAY_INDEX] = idx
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)


## Вид оружия: "axe" | "bow" | "sword_shield" | "sword" | "staff" | "daggers" | "" (без оружия).
var weapon_kind := ""
## Параметры внешности, из которых собрана модель (см. spec_for()).
var spec: Dictionary = {}

var _root: Node3D
var _torso: Node3D
var _head: Node3D
var _hair_back: Node3D
var _cape: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _grip_l: Node3D
var _grip_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _face: MeshInstance3D
var _face_open: ArrayMesh
var _face_closed: ArrayMesh
var _orb: Node3D
var _has_ears := false
var _flash_mats: Array[StandardMaterial3D] = []

# Скелет: кости повторяют узлы-кости; _bone_pre — неподвижные промежуточные узлы между костью
# и её родительской костью (например, Staff между GripR и Orb).
var _skel: Skeleton3D
var _bone_nodes: Array[Node3D] = []
var _bone_pre: Array[Transform3D] = []
var _bone_idx: Dictionary = {}
# Сборка геометрии (только если её нет в кэше)
var _collect := false
var _bufs: Array[GeoBuf] = []

# Поза покоя (углы X плеч и кистей), разведение рук, размах при ходьбе
var _rest_arm_r := 0.1
var _rest_arm_l := 0.1
var _rest_grip_r := 0.0
var _rest_grip_l := 0.0
var _spread := 0.1
var _amp_r := 0.55
var _amp_l := 0.55
var _leg_amp := 0.7
var _cape_rest := -0.1
var _girth := 1.0
var _can_blink := true

var _t := 0.0
var _speed := 0.0
var _move := 0.0
var _phase := 0.0
var _lock_r := 0.0
var _lock_l := 0.0
var _action: Tween
var _hit: Tween
var _flash := 0.0
var _blink := 3.0
var _blinking := false
var _spinning := false

# Готовая модель из файла: сцена glTF, её проигрыватель анимаций, клипы по имени в нижнем регистре
var _asset: Node3D
var _anim: AnimationPlayer
var _clips: Dictionary = {}
var _asset_speed := 0.0
var _act_end := -1.0
var _loco := ""
var _alt := false

## Массивы примитивов (одинаковые детали у всех персонажей).
static var _arr_cache: Dictionary = {}
## Готовая геометрия по параметрам внешности: body, glow (или null), glow_kinds, face_open, face_closed.
static var _geo_cache: Dictionary = {}
static var _outline_shader: Shader
static var _outline_material: ShaderMaterial
static var _glow_mats: Dictionary = {}
static var _face_material: StandardMaterial3D
## Модели из файлов вместо примитивов (false — всегда примитивы, для тестов).
static var use_assets := true
## Пути моделей, у которых анимации уже подготовлены (зацикливание, без смещения по земле).
static var _prepared: Dictionary = {}
static var _asset_outline: ShaderMaterial
static var _sword: ArrayMesh
static var _sword_material: StandardMaterial3D


# ---------- Параметры внешности ----------

## Внешность персонажа по расе и классу (ClassData).
static func spec_for(race_id: String, class_id: String) -> Dictionary:
	var r := ClassData.race(race_id)
	var c := ClassData.cls(class_id)
	var main_c: Color = c.get("color", Color(0.6, 0.3, 0.2))
	var s := {
		"skin": r.get("skin", Color(0.95, 0.8, 0.65)),
		"hair": r.get("hair", Color(0.4, 0.25, 0.12)),
		"hair_style": String(r.get("hair_style", "short")),
		"eyes": r.get("eyes", Color(0.3, 0.5, 0.85)),
		"eye_style": "normal",
		"ears": bool(r.get("ears", false)),
		"outfit": String(c.get("outfit", class_id)),
		"main": main_c,
		"accent": c.get("accent", main_c.lightened(0.4)),
		"weapon": String(c.get("weapon", "sword")),
	}
	var asset := String(c.get("model", r.get("model", MAIN_ASSET)))
	if use_assets and asset != "" and ResourceLoader.exists(asset):
		s["asset"] = asset
		s["weapon"] = "sword"
		s["ears"] = true
	return s


## Добродушный странствующий торговец: широкая шляпа, усы, глаза-улыбки, большой рюкзак.
static func merchant_spec() -> Dictionary:
	return {
		"skin": Color(0.96, 0.8, 0.66), "hair": Color(0.56, 0.5, 0.45), "hair_style": "short",
		"eyes": Color(0.4, 0.28, 0.15), "eye_style": "smile", "ears": false,
		"outfit": "merchant", "main": Color(0.2, 0.5, 0.52), "accent": Color(0.92, 0.7, 0.25),
		"weapon": "", "girth": 1.22, "hat": true, "beard": true,
	}


## Собрать модель по параметрам (можно вызывать до добавления в дерево). Возвращает себя.
func setup(s: Dictionary) -> CharacterModel:
	spec = s
	for ch in get_children():
		remove_child(ch)
		ch.queue_free()
	_flash_mats.clear()
	_bone_nodes.clear()
	_bone_pre.clear()
	_bone_idx.clear()
	_has_ears = false
	_orb = null
	_cape = null
	_hair_back = null
	_face = null
	_root = null
	_skel = null
	_asset = null
	_anim = null
	_clips.clear()
	_act_end = -1.0
	_loco = ""
	weapon_kind = String(s.get("weapon", ""))
	if s.has("asset") and _setup_asset(String(s["asset"])):
		return self
	_girth = float(s.get("girth", 1.0))
	_can_blink = String(s.get("eye_style", "normal")) != "smile"
	var outfit := String(s.get("outfit", "warrior"))
	var pal := _palette(outfit)
	_leg_amp = 0.45 if String(pal["skirt_len"]) == "long" else 0.7
	_cape_rest = -0.1

	var key := var_to_str(s)
	var geo: Dictionary = _geo_cache.get(key, {})
	_collect = geo.is_empty()
	_bufs.clear()
	if _collect:
		for _i in 3:
			_bufs.append(GeoBuf.new())

	_skel = Skeleton3D.new()
	_skel.name = "Skeleton"
	add_child(_skel)
	_root = _bone(self, "Root", Vector3.ZERO)
	_build_legs(pal)
	_torso = _bone(_root, "Torso", Vector3(0, HIP_Y, 0))
	_build_body(pal)
	_build_arms(pal)
	_head = _bone(_torso, "Head", Vector3(0, HEAD_Y, 0))
	_build_head()
	_build_hair()
	_build_outfit(outfit)
	_build_weapon()

	if _collect:
		geo = _bake()
		_geo_cache[key] = geo
		_bufs.clear()
		_collect = false
	_make_meshes(geo)
	_apply_rest()
	_sync_bones()
	_blink = randf_range(1.5, 4.0)
	return self


## Есть ли заострённые уши (эльфы).
func has_ears() -> bool:
	return _has_ears


## Сколько мешей в модели (для проверки бюджета на телефоне).
func mesh_count() -> int:
	return find_children("*", "MeshInstance3D", true, false).size()


## Сколько поверхностей (вызовов отрисовки без контура) у мешей модели.
func surface_count() -> int:
	var n := 0
	for mi in find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		if m != null:
			n += m.get_surface_count()
	return n


## Скорость движения, м/с: от неё зависят шаг, размах рук и наклон.
func set_move_speed(v: float) -> void:
	_speed = maxf(0.0, v)


## Цвета одежды по образу.
func _palette(outfit: String) -> Dictionary:
	var main_c: Color = spec.get("main", Color(0.6, 0.3, 0.2))
	var acc: Color = spec.get("accent", GOLD)
	var p := {
		"chest": main_c, "sleeve": main_c.darkened(0.12), "skirt": main_c.darkened(0.28),
		"belt": Color(0.36, 0.23, 0.13), "pants": Color(0.28, 0.24, 0.24), "boots": Color(0.33, 0.21, 0.13),
		"skirt_len": "short",
	}
	match outfit:
		"warrior":
			p["pants"] = Color(0.32, 0.27, 0.22)
		"ranger":
			p["sleeve"] = Color(0.88, 0.83, 0.7)
			p["skirt"] = main_c.darkened(0.2)
			p["pants"] = Color(0.45, 0.34, 0.22)
			p["boots"] = Color(0.27, 0.22, 0.15)
		"guardian":
			p["sleeve"] = acc.darkened(0.15)
			p["skirt"] = acc
			p["skirt_len"] = "mid"
			p["belt"] = GOLD
			p["pants"] = Color(0.32, 0.36, 0.5)
			p["boots"] = Color(0.75, 0.77, 0.84)
		"cleric":
			var white := Color(0.97, 0.95, 0.9)
			p["chest"] = white
			p["sleeve"] = white
			p["skirt"] = Color(0.95, 0.93, 0.87)
			p["skirt_len"] = "long"
			p["belt"] = main_c
			p["boots"] = Color(0.72, 0.56, 0.36)
		"assassin":
			p["skirt"] = main_c.darkened(0.35)
			p["pants"] = Color(0.16, 0.13, 0.2)
			p["boots"] = Color(0.13, 0.1, 0.15)
			p["belt"] = acc
		"warlock":
			p["sleeve"] = main_c.darkened(0.2)
			p["skirt"] = main_c.darkened(0.38)
			p["skirt_len"] = "long"
			p["belt"] = acc
			p["boots"] = Color(0.15, 0.12, 0.18)
		"merchant":
			p["sleeve"] = Color(0.9, 0.85, 0.72)
			p["skirt"] = main_c.darkened(0.15)
			p["skirt_len"] = "mid"
			p["belt"] = acc
			p["pants"] = Color(0.45, 0.35, 0.25)
	return p


# ---------- Тело ----------

func _build_legs(pal: Dictionary) -> void:
	var hip_x := 0.095 + (_girth - 1.0) * 0.1
	for sd in [-1.0, 1.0]:
		var side: float = sd
		var leg := _bone(_root, "LegR" if side > 0.0 else "LegL", Vector3(hip_x * side, HIP_Y, 0))
		_add(leg, _capsule(0.075, 0.84), Vector3(0, -0.42, 0), pal["pants"])
		_add(leg, _capsule(0.088, 0.25), Vector3(0, -0.78, -0.025), pal["boots"])
		if side > 0.0:
			_leg_r = leg
		else:
			_leg_l = leg


func _build_body(pal: Dictionary) -> void:
	var g := _girth
	_add(_torso, _capsule(0.165, 0.6), Vector3(0, 0.27, 0), pal["chest"], OL, Vector3.ZERO, Vector3(g, 1.0, 0.8 * g))
	_add(_torso, _cyl(0.172, 0.172, 0.07), Vector3(0, 0.07, 0), pal["belt"], OL_THIN, Vector3.ZERO,
		Vector3(g, 1.0, 0.82 * g))
	var bottom := 0.25
	var h := 0.3
	match String(pal["skirt_len"]):
		"mid":
			bottom = 0.29
			h = 0.5
		"long":
			bottom = 0.33
			h = 0.76
	_add(_torso, _cyl(0.165, bottom, h, 12), Vector3(0, 0.06 - h * 0.5, 0), pal["skirt"], OL, Vector3.ZERO,
		Vector3(g, 1.0, 0.85 * g))


func _build_arms(pal: Dictionary) -> void:
	var skin: Color = spec.get("skin", Color(0.95, 0.8, 0.65))
	var sx := SHOULDER_X + (_girth - 1.0) * 0.14
	for sd in [-1.0, 1.0]:
		var side: float = sd
		var arm := _bone(_torso, "ArmR" if side > 0.0 else "ArmL", Vector3(sx * side, SHOULDER_Y, 0))
		_add(arm, _capsule(0.058, 0.5), Vector3(0, -0.22, 0), pal["sleeve"])
		_add(arm, _sphere(0.062, 0.124, 10, 5), Vector3(0, -0.5, 0), skin, OL_THIN)
		var grip := _bone(arm, "GripR" if side > 0.0 else "GripL", Vector3(0, -0.52, -0.01))
		if side > 0.0:
			_arm_r = arm
			_grip_r = grip
		else:
			_arm_l = arm
			_grip_l = grip


# ---------- Голова и лицо ----------

func _build_head() -> void:
	var skin: Color = spec.get("skin", Color(0.95, 0.8, 0.65))
	_add(_head, _sphere(HEAD_R, HEAD_R * 2.0, 16, 8), Vector3.ZERO, skin)

	if bool(spec.get("ears", false)):
		_has_ears = true
		for sd in [-1.0, 1.0]:
			var side: float = sd
			var base := _dir(1.5 * side, -0.08) * 0.185
			var d := Vector3(0.88 * side, 0.42, 0.2).normalized()
			_put(_head, _cyl(0.0, 0.046, 0.21, 6),
				Transform3D(_basis_y(d) * Basis.from_scale(Vector3(1.0, 1.0, 0.45)), base + d * 0.1), skin, OL_THIN)

	if bool(spec.get("beard", false)):
		var hair: Color = spec.get("hair", Color(0.5, 0.45, 0.4))
		for sd in [-1.0, 1.0]:
			var side: float = sd
			_add(_head, _sphere(0.035, 0.07, 8, 4),
				_dir(0.12 * side, -0.42) * (HEAD_R + 0.008) + Vector3(0.012 * side, 0, 0), hair, OL_THIN,
				Vector3(0, 0, -0.35 * side), Vector3(1.3, 0.6, 0.5))


## Направление от центра головы: u — поворот (0 = вперёд, + = вправо), v — наклон (+ = вверх).
static func _dir(u: float, v: float) -> Vector3:
	return Vector3(sin(u) * cos(v), sin(v), -cos(u) * cos(v))


## Лицо — один меш с цветами вершин (глаза, брови, рот, румянец), привязан к кости головы.
## Моргание — подмена меша на вариант с закрытыми глазами.
func _face_mesh(closed: bool) -> ArrayMesh:
	var b := GeoBuf.new()
	b.tri_bone = int(_bone_idx[_head])
	var skin: Color = spec.get("skin", Color(0.95, 0.8, 0.65))
	var hair: Color = spec.get("hair", Color(0.4, 0.25, 0.12))
	var iris: Color = spec.get("eyes", Color(0.3, 0.5, 0.85))
	var smile := String(spec.get("eye_style", "normal")) == "smile"
	var brow := hair.darkened(0.45)
	var blush := skin.lerp(Color(1.0, 0.45, 0.5), 0.35)
	for sd in [-1.0, 1.0]:
		var side: float = sd
		var u := 0.37 * side
		var v := -0.15
		# Румянец и бровь
		_f_ellipse(b, 0.56 * side, -0.36, Vector2.ZERO, 0.032, 0.015, 0.0015, blush)
		_f_arc(b, 0.38 * side, 0.24, Vector2.ZERO, 0.046, 0.012, 0.12 * PI, 0.88 * PI, 0.011, side, 0.0025, brow)
		if smile:
			# Глаза-улыбки «^ ^»
			_f_arc(b, u, v, Vector2(0, -0.012), 0.036, 0.03, 0.1 * PI, 0.9 * PI, 0.012, side, 0.003, LASH)
		elif closed:
			_f_arc(b, u, v, Vector2(0, 0.006), 0.044, 0.014, 1.05 * PI, 1.95 * PI, 0.011, side, 0.003, LASH)
		else:
			# Белок, радужка с осветлением снизу, зрачок, два блика, ресницы сверху
			var ic := Vector2(-0.004 * side, -0.006)
			_f_ellipse(b, u, v, Vector2.ZERO, 0.044, 0.052, 0.0015, Color(0.98, 0.98, 1.0))
			_f_ellipse(b, u, v, ic, 0.031, 0.042, 0.003, iris)
			_f_ellipse(b, u, v, ic + Vector2(0, -0.02), 0.022, 0.015, 0.0038, iris.lightened(0.35))
			_f_ellipse(b, u, v, ic + Vector2(0, 0.004), 0.016, 0.024, 0.0045, iris.darkened(0.72))
			_f_ellipse(b, u, v, ic + Vector2(0.013 * side, 0.017), 0.011, 0.012, 0.006, Color.WHITE)
			_f_ellipse(b, u, v, ic + Vector2(-0.011 * side, -0.02), 0.005, 0.005, 0.006, Color.WHITE)
			_f_arc(b, u, v, Vector2.ZERO, 0.046, 0.054, -0.06 * PI, 0.95 * PI, 0.013, side, 0.0055, LASH)
	# Маленький рот-улыбка
	_f_arc(b, 0.0, -0.55, Vector2.ZERO, 0.022, 0.009, 1.12 * PI, 1.88 * PI, 0.006, 1.0, 0.002,
		Color(0.5, 0.2, 0.22))
	var m := ArrayMesh.new()
	b.commit(m)
	return m


## Точка на поверхности головы: центр (u, v), смещение off (м) в касательной плоскости, lift — над кожей.
func _fp(u: float, v: float, off: Vector2, lift: float) -> Vector3:
	var d := _dir(u, v)
	var tx := d.cross(Vector3.UP).normalized()
	var ty := tx.cross(d).normalized()
	return (d * HEAD_R + tx * off.x + ty * off.y).normalized() * (HEAD_R + lift)


func _f_ellipse(b: GeoBuf, u: float, v: float, c: Vector2, ra: float, rb: float, lift: float,
		col: Color) -> void:
	var center := _fp(u, v, c, lift)
	var prev := _fp(u, v, c + Vector2(ra, 0.0), lift)
	for i in range(1, FACE_SEG + 1):
		var th := TAU * float(i) / float(FACE_SEG)
		var cur := _fp(u, v, c + Vector2(ra * cos(th), rb * sin(th)), lift)
		b.tri(center, prev, cur, col)
		prev = cur


## Дуга-мазок по эллипсу (ra, rb) от угла t0 до t1, толщина сходит на нет к концам. side отражает по X.
func _f_arc(b: GeoBuf, u: float, v: float, c: Vector2, ra: float, rb: float, t0: float, t1: float,
		thick: float, side: float, lift: float, col: Color) -> void:
	var n := 10
	var p_in := Vector3.ZERO
	var p_out := Vector3.ZERO
	for i in n + 1:
		var f := float(i) / float(n)
		var th := lerpf(t0, t1, f)
		var k := thick * maxf(0.2, sin(PI * f))
		var cs := cos(th) * side
		var sn := sin(th)
		var a_in := _fp(u, v, c + Vector2(ra * cs, rb * sn), lift)
		var a_out := _fp(u, v, c + Vector2((ra + k) * cs, (rb + k) * sn), lift)
		if i > 0:
			b.tri(p_in, p_out, a_out, col)
			b.tri(p_in, a_out, a_in, col)
		p_in = a_in
		p_out = a_out


# ---------- Причёски ----------

func _build_hair() -> void:
	var hair: Color = spec.get("hair", Color(0.4, 0.25, 0.12))
	var acc: Color = spec.get("accent", GOLD)
	var style := String(spec.get("hair_style", "short"))
	var hat := bool(spec.get("hat", false))
	# «Шапка» волос сдвинута вверх-назад: лицо открыто, затылок и виски закрыты
	var cap_c := Vector3(0, 0.035, 0.045)
	_add(_head, _sphere(0.218, 0.436, 14, 7), cap_c, hair)
	if not hat:
		# Светлое кольцо-блик на волосах (аниме-приём)
		var rh := 0.105
		var rho := sqrt(0.218 * 0.218 - rh * rh)
		_add(_head, _torus(rho - 0.006, rho + 0.012), cap_c + Vector3(0, rh, 0), hair.lightened(0.4), 0.0)

	match style:
		"long":
			# Косая чёлка, длинные пряди до груди, волосы до пояса, заколка
			_strand(-0.45, 1.05, -0.75, 0.22, 0.06, hair)
			_strand(-0.15, 1.15, -0.33, 0.33, 0.065, hair)
			_strand(0.12, 1.15, 0.12, 0.38, 0.06, hair)
			_strand(0.4, 1.1, 0.6, 0.3, 0.06, hair)
			for sd in [-1.0, 1.0]:
				var side: float = sd
				_spike(_head, _dir(1.2 * side, 0.5) * (HEAD_R + 0.012), Vector3(0.175 * side, -0.37, -0.085),
					0.065, hair)
			_hair_back = _bone(_head, "HairBack", Vector3(0, 0.02, 0.13))
			_add(_hair_back, _sphere(0.17, 0.78, 12, 6), Vector3(0, -0.3, 0.06), hair, OL, Vector3.ZERO,
				Vector3(1.1, 1.0, 0.55))
			for sd in [-1.0, 1.0]:
				var side: float = sd
				_spike(_hair_back, Vector3(0.1 * side, -0.05, 0.08), Vector3(0.16 * side, -0.66, 0.08), 0.07, hair)
			_add(_head, _sphere(0.026, 0.052, 8, 4), _dir(0.95, 0.6) * (HEAD_R + 0.035), acc, OL_THIN)
		"ponytail":
			# Асимметричная чёлка, пряди у лица, высокий хвост
			_strand(-0.3, 1.1, -0.58, 0.25, 0.065, hair)
			_strand(-0.05, 1.15, -0.12, 0.3, 0.065, hair)
			_strand(0.2, 1.12, 0.26, 0.4, 0.06, hair)
			_strand(0.45, 1.05, 0.78, 0.2, 0.055, hair)
			_strand(1.2, 0.5, 1.3, -0.48, 0.055, hair)
			_strand(-1.2, 0.5, -1.3, -0.48, 0.055, hair)
			_add(_head, _sphere(0.045, 0.09, 8, 4), Vector3(0, 0.17, 0.2), acc, OL_THIN)
			_hair_back = _bone(_head, "HairBack", Vector3(0, 0.17, 0.22))
			_add(_hair_back, _sphere(0.075, 0.13, 10, 5), Vector3(0, -0.01, 0.04), hair)
			_spike(_hair_back, Vector3(0, 0.0, 0.05), Vector3(0, -0.72, 0.15), 0.085, hair)
			_spike(_hair_back, Vector3(0.035, -0.02, 0.04), Vector3(0.08, -0.5, 0.22), 0.055, hair)
		_:
			# Короткая: чёлка прядями, пряди у висков, острые пряди на затылке, «антенна» на макушке
			_strand(-0.35, 1.1, -0.62, 0.3, 0.06, hair)
			_strand(-0.1, 1.15, -0.2, 0.32, 0.065, hair)
			_strand(0.13, 1.15, 0.1, 0.36, 0.065, hair)
			_strand(0.38, 1.1, 0.55, 0.3, 0.06, hair)
			_strand(1.25, 0.55, 1.3, -0.55, 0.065, hair)
			_strand(-1.25, 0.55, -1.3, -0.55, 0.065, hair)
			_hair_back = _bone(_head, "HairBack", Vector3(0, 0.05, 0.1))
			_spike(_hair_back, Vector3(0.1, 0.07, 0.04), Vector3(0.14, -0.2, 0.11), 0.085, hair)
			_spike(_hair_back, Vector3(-0.1, 0.07, 0.04), Vector3(-0.14, -0.2, 0.11), 0.085, hair)
			_spike(_hair_back, Vector3(0, 0.08, 0.06), Vector3(0, -0.24, 0.13), 0.09, hair)
			if not hat:
				_spike(_head, Vector3(0, 0.24, 0.0), Vector3(0.05, 0.34, -0.07), 0.025, hair)

	if hat:
		var hat_c := Color(0.78, 0.58, 0.3)
		_add(_head, _cyl(0.36, 0.36, 0.03, 16), Vector3(0, 0.16, 0.03), hat_c, OL, Vector3(0.12, 0, 0))
		_add(_head, _sphere(0.18, 0.24, 12, 6), Vector3(0, 0.24, 0.04), hat_c)
		_add(_head, _cyl(0.183, 0.183, 0.045, 12), Vector3(0, 0.19, 0.04), Color(0.72, 0.25, 0.2), OL_THIN)
		_spike(_head, Vector3(0.15, 0.2, 0.08), Vector3(0.27, 0.42, 0.18), 0.03, Color(0.95, 0.92, 0.82))


## Прядь: конус от корня (под «шапкой») к кончику у кожи; точки заданы углами (u, v) на голове.
func _strand(u0: float, v0: float, u1: float, v1: float, r: float, col: Color) -> void:
	_spike(_head, _dir(u0, v0) * (HEAD_R + 0.012), _dir(u1, v1) * (HEAD_R + 0.012), r, col)


# ---------- Одежда по образу ----------

func _build_outfit(outfit: String) -> void:
	var main_c: Color = spec.get("main", Color(0.6, 0.3, 0.2))
	var acc: Color = spec.get("accent", GOLD)
	var metal := Color(0.66, 0.68, 0.74)
	match outfit:
		"warrior":
			# Стальные наплечники, меховой воротник, пряжка, кожаные наручи
			_pads(0.1, 0.15, metal)
			_add(_torso, _sphere(0.2, 0.13), Vector3(0, 0.47, 0.01), Color(0.85, 0.75, 0.58), OL, Vector3.ZERO,
				Vector3(1.0, 1.0, 0.85))
			_add(_torso, _box(Vector3(0.075, 0.06, 0.025)), Vector3(0, 0.07, -0.145), acc, OL_THIN)
			for arm in [_arm_l, _arm_r]:
				_add(arm, _cyl(0.066, 0.07, 0.15), Vector3(0, -0.37, 0), Color(0.42, 0.28, 0.16), OL_THIN)
		"ranger":
			# Короткая накидка с откинутым капюшоном, колчан за спиной, поясная сумка
			var cape_c := main_c.darkened(0.3)
			_add(_torso, _cyl(0.1, 0.25, 0.24, 12), Vector3(0, 0.44, 0), cape_c, OL, Vector3.ZERO,
				Vector3(1.0, 1.0, 0.88))
			_add(_torso, _sphere(0.13, 0.17), Vector3(0, 0.53, 0.15), cape_c, OL, Vector3.ZERO, Vector3(1.1, 1.0, 0.75))
			var q := _node(_torso, "Quiver", Vector3(0.08, 0.28, 0.2))
			q.rotation.z = -0.35
			_add(q, _cyl(0.06, 0.055, 0.5), Vector3.ZERO, Color(0.45, 0.28, 0.15))
			_add(q, _cyl(0.08, 0.035, 0.12, 8), Vector3(0, 0.3, 0), Color(0.93, 0.9, 0.82), OL_THIN)
			_add(_torso, _box(Vector3(0.1, 0.1, 0.06)), Vector3(-0.13, 0.02, -0.12), Color(0.5, 0.35, 0.2), OL_THIN)
		"guardian":
			# Крупные наплечники, плащ цвета акцента, знак на груди
			_pads(0.125, 0.17, main_c)
			_cape = _bone(_torso, "Cape", Vector3(0, 0.5, 0.12))
			_cape_rest = -0.14
			_add(_cape, _box(Vector3(0.36, 0.95, 0.025)), Vector3(0, -0.47, 0.03), acc.darkened(0.1))
			_add(_torso, _box(Vector3(0.08, 0.08, 0.02)), Vector3(0, 0.33, -0.135), GOLD, OL_THIN,
				Vector3(0, 0, PI * 0.25))
		"cleric":
			# Накидка цвета класса, полоса ткани спереди, золотая кайма подола
			_add(_torso, _cyl(0.1, 0.26, 0.22, 12), Vector3(0, 0.45, 0), main_c, OL, Vector3.ZERO,
				Vector3(1.0, 1.0, 0.88))
			_add(_torso, _box(Vector3(0.12, 0.62, 0.02)), Vector3(0, -0.25, -0.2), main_c, OL, Vector3(0.17, 0, 0))
			_add(_torso, _torus(0.315, 0.35), Vector3(0, -0.69, 0), acc, OL_THIN, Vector3.ZERO, Vector3(1.0, 1.0, 0.85))
		"assassin":
			# Шарф с длинными концами, развевающимися за спиной
			_add(_torso, _sphere(0.155, 0.13), Vector3(0, 0.5, -0.005), acc)
			_cape = _bone(_torso, "Scarf", Vector3(0.06, 0.5, 0.12))
			_cape_rest = -0.25
			_add(_cape, _box(Vector3(0.09, 0.5, 0.02)), Vector3(0, -0.25, 0.02), acc)
			_add(_cape, _box(Vector3(0.08, 0.38, 0.02)), Vector3(0.07, -0.2, 0.03), acc.darkened(0.15), OL,
				Vector3(0, 0, 0.15))
		"warlock":
			# Высокий воротник-веер за головой, длинный плащ, светящийся камень на груди
			_add(_torso, _sphere(0.21, 0.32), Vector3(0, 0.6, 0.13), main_c.darkened(0.45), OL, Vector3.ZERO,
				Vector3(1.0, 1.0, 0.3))
			_cape = _bone(_torso, "Cape", Vector3(0, 0.5, 0.12))
			_cape_rest = -0.16
			_add(_cape, _box(Vector3(0.4, 1.05, 0.025)), Vector3(0, -0.52, 0.03), main_c.darkened(0.5))
			_glow(_torso, _sphere(0.035, 0.07, 8, 4), Vector3(0, 0.36, -0.14), acc, 1.0)
		"merchant":
			# Большой рюкзак со скаткой и фонариком, фартук, лямки
			var pack_z := 0.132 * _girth + 0.14
			_add(_torso, _box(Vector3(0.48, 0.58, 0.28)), Vector3(0, 0.27, pack_z), Color(0.55, 0.38, 0.22))
			_add(_torso, _cyl(0.09, 0.09, 0.6, 10), Vector3(0, 0.62, pack_z), Color(0.66, 0.27, 0.22), OL,
				Vector3(0, 0, PI * 0.5))
			_glow(_torso, _sphere(0.05, 0.1, 8, 4), Vector3(0.3, 0.08, pack_z), Color(1.0, 0.85, 0.45), 1.0)
			_add(_torso, _box(Vector3(0.28, 0.42, 0.02)), Vector3(0, -0.12, -0.235), Color(0.93, 0.87, 0.72), OL,
				Vector3(0.2, 0, 0))
			for sd in [-1.0, 1.0]:
				var side: float = sd
				_add(_torso, _box(Vector3(0.04, 0.3, 0.02)), Vector3(0.1 * side, 0.36, -0.165),
					Color(0.42, 0.28, 0.16), OL_THIN)


## Наплечники на обоих плечах (двигаются вместе с рукой).
func _pads(r: float, h: float, col: Color) -> void:
	for arm in [_arm_l, _arm_r]:
		var a: Node3D = arm
		var side := signf(a.position.x)
		_add(a, _sphere(r, h), Vector3(0.025 * side, 0.01, 0), col, OL, Vector3(0, 0, -0.35 * side))


# ---------- Оружие (вдоль +Y узла кисти) ----------

func _build_weapon() -> void:
	var main_c: Color = spec.get("main", Color(0.6, 0.3, 0.2))
	var acc: Color = spec.get("accent", GOLD)
	var steel := Color(0.82, 0.85, 0.9)
	var wood := Color(0.48, 0.31, 0.17)
	match weapon_kind:
		"axe":
			var w := _node(_grip_r, "Axe", Vector3.ZERO)
			_add(w, _cyl(0.024, 0.026, 1.0, 8), Vector3(0, 0.3, 0), wood, OL_THIN)
			_add(w, _cyl(0.032, 0.032, 0.14, 8), Vector3(0, 0.0, 0), acc.darkened(0.3), OL_THIN)
			_add(w, _cyl(0.15, 0.15, 0.03, 14), Vector3(0, 0.64, -0.11), steel, OL_THIN, Vector3(0, 0, PI * 0.5))
			_add(w, _box(Vector3(0.06, 0.15, 0.07)), Vector3(0, 0.64, 0), Color(0.42, 0.42, 0.48), OL_THIN)
		"sword", "sword_shield":
			var s := _node(_grip_r, "Sword", Vector3.ZERO)
			_add(s, _cyl(0.022, 0.022, 0.2, 8), Vector3.ZERO, Color(0.3, 0.2, 0.15), OL_THIN)
			_add(s, _sphere(0.03, 0.06, 8, 4), Vector3(0, -0.11, 0), GOLD, OL_THIN)
			_add(s, _box(Vector3(0.05, 0.045, 0.22)), Vector3(0, 0.11, 0), GOLD, OL_THIN)
			_add(s, _box(Vector3(0.016, 0.7, 0.07)), Vector3(0, 0.48, 0), steel, OL_THIN)
			_add(s, _prism(Vector3(0.07, 0.12, 0.016)), Vector3(0, 0.89, 0), steel, OL_THIN, Vector3(0, PI * 0.5, 0))
			if weapon_kind == "sword_shield":
				var sh := _node(_grip_l, "Shield", Vector3(-0.07, 0.1, -0.05))
				_add(sh, _cyl(0.25, 0.25, 0.05, 16), Vector3.ZERO, acc, OL, Vector3(PI * 0.5, 0, 0))
				_add(sh, _torus(0.225, 0.265), Vector3.ZERO, main_c, OL_THIN, Vector3(PI * 0.5, 0, 0))
				_add(sh, _sphere(0.065, 0.13, 10, 5), Vector3(0, 0, -0.035), GOLD, OL_THIN)
		"staff":
			var st := _node(_grip_r, "Staff", Vector3.ZERO)
			var dark := String(spec.get("outfit", "")) == "warlock"
			var wood_c := Color(0.3, 0.19, 0.28) if dark else Color(0.8, 0.66, 0.44)
			var metal_c := Color(0.55, 0.55, 0.64) if dark else GOLD
			var glow_c := acc if dark else main_c
			_add(st, _cyl(0.022, 0.026, 1.65, 8), Vector3(0, 0.3, 0), wood_c, OL_THIN)
			_add(st, _torus(0.075, 0.1), Vector3(0, 1.22, 0), metal_c, OL_THIN, Vector3(PI * 0.5, 0, 0))
			if dark:
				for sd in [-1.0, 1.0]:
					var side: float = sd
					_spike(st, Vector3(0.06 * side, 1.12, 0), Vector3(0.14 * side, 1.43, 0), 0.026, metal_c)
			else:
				_spike(st, Vector3(0, 1.3, 0), Vector3(0, 1.45, 0), 0.026, metal_c)
			_orb = _bone(st, "Orb", Vector3(0, 1.22, 0))
			_glow(_orb, _sphere(0.06, 0.12, 10, 5), Vector3.ZERO, glow_c.lightened(0.4), 1.0)
			_glow(_orb, _sphere(0.12, 0.24, 12, 6), Vector3.ZERO, glow_c, 0.3)
		"bow":
			var b := _node(_grip_l, "Bow", Vector3.ZERO)
			var bw := Color(0.44, 0.27, 0.14)
			_add(b, _cyl(0.027, 0.027, 0.22, 8), Vector3.ZERO, Color(0.3, 0.2, 0.12), OL_THIN)
			for sd in [-1.0, 1.0]:
				var y: float = sd
				_segment(b, Vector3(0, 0.1 * y, 0), Vector3(0, 0.36 * y, 0.05), 0.022, 0.018, bw)
				_segment(b, Vector3(0, 0.36 * y, 0.05), Vector3(0, 0.56 * y, 0.14), 0.018, 0.012, bw)
			_segment(b, Vector3(0, 0.56, 0.14), Vector3(0, -0.56, 0.14), 0.004, 0.004, Color(0.95, 0.95, 0.88), 0.0)
		"daggers":
			for sd in [-1.0, 1.0]:
				var side: float = sd
				var g: Node3D = _grip_r if side > 0.0 else _grip_l
				var d := _node(g, "DaggerR" if side > 0.0 else "DaggerL", Vector3.ZERO)
				_add(d, _cyl(0.02, 0.02, 0.13, 6), Vector3.ZERO, acc, OL_THIN)
				_add(d, _box(Vector3(0.12, 0.025, 0.03)), Vector3(0, 0.075, 0), Color(0.3, 0.3, 0.36), OL_THIN)
				_add(d, _cyl(0.0, 0.034, 0.34, 6), Vector3(0, 0.25, 0), Color(0.78, 0.75, 0.88), OL_THIN,
					Vector3.ZERO, Vector3(1.0, 1.0, 0.35))


## Поза покоя под оружие. Угол оружия = плечо + кисть: 0 — вверх, −π/2 — вперёд.
func _apply_rest() -> void:
	_spread = 0.1 + (_girth - 1.0) * 0.6
	_rest_arm_r = 0.1
	_rest_arm_l = 0.1
	_rest_grip_r = 0.0
	_rest_grip_l = 0.0
	_amp_r = 0.55
	_amp_l = 0.55
	match weapon_kind:
		"axe":
			_rest_arm_r = 0.2
			_rest_grip_r = -1.2
			_amp_r = 0.3
		"sword", "sword_shield":
			_rest_arm_r = 0.2
			_rest_grip_r = -1.0
			_amp_r = 0.3
			if weapon_kind == "sword_shield":
				_rest_arm_l = 0.35
				_rest_grip_l = -0.35
				_amp_l = 0.25
		"staff":
			_rest_arm_r = 0.25
			_rest_grip_r = -0.25
			_amp_r = 0.2
		"bow":
			_rest_arm_l = 0.12
			_rest_grip_l = -0.12
			_amp_l = 0.3
		"daggers":
			_rest_arm_r = 0.15
			_rest_grip_r = -1.35
			_rest_arm_l = 0.15
			_rest_grip_l = -1.35
			_amp_r = 0.45
			_amp_l = 0.45
	_arm_r.rotation = Vector3(_rest_arm_r, 0.0, _spread)
	_arm_l.rotation = Vector3(_rest_arm_l, 0.0, -_spread)
	_grip_r.rotation.x = _rest_grip_r
	_grip_l.rotation.x = _rest_grip_l
	if _cape != null:
		_cape.rotation.x = _cape_rest


# ---------- Анимации ----------

func _process(delta: float) -> void:
	if _asset != null:
		_asset_process(delta)
		return
	if _root == null:
		return
	_t += delta
	_move = lerpf(_move, clampf(_speed / 6.0, 0.0, 1.0), 1.0 - exp(-10.0 * delta))
	_phase = fmod(_phase + delta * _speed * 2.3, TAU)
	var s := sin(_phase) * _move
	var idle := 1.0 - _move
	var k := 1.0 - exp(-14.0 * delta)

	# Шаг, подскок, наклон вперёд при беге, дыхание и покачивание головы в покое
	_leg_l.rotation.x = s * _leg_amp
	_leg_r.rotation.x = -s * _leg_amp
	_root.position.y = absf(cos(_phase)) * 0.045 * _move
	_torso.rotation.x = -0.1 * _move
	_torso.scale.y = 1.0 + sin(_t * 2.2) * 0.012 * idle
	_head.rotation = Vector3(
		sin(_phase * 2.0) * 0.03 * _move + sin(_t * 0.9) * 0.02 * idle,
		sin(_t * 0.55) * 0.08 * idle,
		sin(_t * 0.8) * 0.03 * idle)

	# Руки: качаются в противофазе ногам; во время действия ими управляет твин
	_lock_r = maxf(0.0, _lock_r - delta)
	_lock_l = maxf(0.0, _lock_l - delta)
	if _lock_r <= 0.0:
		_arm_r.rotation.x = lerpf(_arm_r.rotation.x, _rest_arm_r + s * _amp_r, k)
		_arm_r.rotation.z = lerpf(_arm_r.rotation.z, _spread, k)
		_grip_r.rotation.x = lerpf(_grip_r.rotation.x, _rest_grip_r, k)
	if _lock_l <= 0.0:
		_arm_l.rotation.x = lerpf(_arm_l.rotation.x, _rest_arm_l - s * _amp_l, k)
		_arm_l.rotation.z = lerpf(_arm_l.rotation.z, -_spread, k)
		_grip_l.rotation.x = lerpf(_grip_l.rotation.x, _rest_grip_l, k)
	if _lock_r <= 0.0 and _lock_l <= 0.0:
		_torso.rotation.y = lerpf(_torso.rotation.y, 0.0, k)
		if _orb != null:
			_orb.scale = _orb.scale.lerp(Vector3.ONE, k)

	# Волосы и плащ отстают при беге и слегка колышутся
	if _hair_back != null:
		_hair_back.rotation.x = -0.35 * _move + sin(_t * 1.7 + 0.5) * 0.04 + sin(_phase * 2.0) * 0.05 * _move
		_hair_back.rotation.z = sin(_t * 1.3) * 0.03
	if _cape != null:
		_cape.rotation.x = _cape_rest - 0.45 * _move + sin(_t * 1.6) * 0.03 + sin(_phase * 2.0) * 0.05 * _move
		_cape.rotation.z = sin(_t * 1.1) * 0.025

	# Вспышка при уроне
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 5.0)
		var fc := FLASH * (_flash * 0.9)
		for m in _flash_mats:
			m.emission = fc

	# Моргание
	if _can_blink and _face != null:
		_blink -= delta
		if _blinking:
			if _blink <= 0.0:
				_blinking = false
				_face.mesh = _face_open
				_blink = randf_range(2.0, 5.0)
		elif _blink <= 0.0:
			_blinking = true
			_face.mesh = _face_closed
			_blink = 0.12

	_sync_bones()


## Обычная атака под оружие: удар, выстрел из лука или взмах посохом.
func play_attack() -> void:
	if _asset != null:
		_alt = not _alt
		_asset_act("slash" if _alt else "chop")
		return
	match weapon_kind:
		"bow":
			play_shoot()
		"staff":
			play_cast()
		"daggers":
			_play_stabs()
		"":
			play_wave()
		_:
			_play_chop()


## Рубящий удар правой рукой: замах из-за плеча и удар вниз-вперёд с разворотом корпуса
## (поворот Torso по Y > 0 выводит вперёд правое плечо).
func _play_chop() -> void:
	var t := _new_action(0.34, 0.0)
	if t == null:
		return
	t.tween_property(_arm_r, "rotation:x", 2.6, 0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(_grip_r, "rotation:x", -0.4, 0.11)
	t.tween_property(_torso, "rotation:y", -0.35, 0.11)
	t.chain().tween_property(_arm_r, "rotation:x", 0.45, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_grip_r, "rotation:x", -1.9, 0.08)
	t.tween_property(_torso, "rotation:y", 0.3, 0.08)


## Два быстрых выпада кинжалами: правым, затем левым.
func _play_stabs() -> void:
	var t := _new_action(0.2, 0.32)
	if t == null:
		return
	t.tween_property(_arm_r, "rotation:x", 1.35, 0.07)
	t.tween_property(_grip_r, "rotation:x", -2.3, 0.07)
	t.tween_property(_torso, "rotation:y", 0.25, 0.07)
	t.tween_property(_arm_l, "rotation:x", 1.35, 0.07).set_delay(0.12)
	t.tween_property(_grip_l, "rotation:x", -2.3, 0.07).set_delay(0.12)
	t.tween_property(_torso, "rotation:y", -0.25, 0.07).set_delay(0.12)


## Выстрел из лука: лук вперёд, правая рука натягивает тетиву.
func play_shoot() -> void:
	if _asset != null:
		_asset_act("slash")
		return
	var t := _new_action(0.42, 0.45)
	if t == null:
		return
	t.tween_property(_arm_l, "rotation:x", 1.45, 0.08)
	t.tween_property(_grip_l, "rotation:x", -1.45, 0.08)
	t.tween_property(_arm_r, "rotation:x", 1.4, 0.08)
	t.tween_property(_arm_r, "rotation:z", -0.25, 0.08)
	t.chain().tween_property(_arm_r, "rotation:x", 1.05, 0.12)
	t.tween_property(_arm_r, "rotation:z", 0.15, 0.12)


## Заклинание: посох вскинут вперёд-вверх, навершие вспыхивает; левая рука раскрыта.
func play_cast() -> void:
	if _asset != null:
		_asset_act("cast")
		return
	var t := _new_action(0.45, 0.45)
	if t == null:
		return
	if weapon_kind == "staff":
		t.tween_property(_arm_r, "rotation:x", 1.8, 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(_grip_r, "rotation:x", -2.2, 0.13)
	else:
		t.tween_property(_arm_r, "rotation:x", 2.3, 0.13)
		t.tween_property(_arm_r, "rotation:z", 0.5, 0.13)
	t.tween_property(_arm_l, "rotation:x", 1.0, 0.13)
	t.tween_property(_arm_l, "rotation:z", -0.5, 0.13)
	if _orb != null:
		t.tween_property(_orb, "scale", Vector3.ONE * 1.8, 0.13)
		t.chain().tween_property(_orb, "scale", Vector3.ONE, 0.25)


## Усиление (клич, щит, ускорение): обе руки вверх; у модели из файла — защитная стойка с мечом.
func play_buff() -> void:
	if _asset != null:
		_asset_act("buff")
		return
	var t := _new_action(0.5, 0.5)
	if t == null:
		return
	t.tween_property(_arm_r, "rotation:x", 2.5, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_arm_r, "rotation:z", 0.55, 0.14)
	t.tween_property(_arm_l, "rotation:x", 2.5, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_arm_l, "rotation:z", -0.55, 0.14)


## Рывок к цели (Шаг тени): у модели из файла — выпад с мечом, у модели из примитивов — как усиление.
func play_dash() -> void:
	if _asset != null:
		_asset_act("leap")
		return
	play_buff()


## Подбор добычи: присесть и поднять с земли. Только у модели из файла и только стоя без дела,
## чтобы не прерывать удар и не скользить в позе приседа на бегу.
func play_pickup() -> void:
	if _asset != null and _act_end < 0.0 and _asset_speed < 0.3:
		_asset_act("pickup")


## Удар щитом: выпад левой рукой, щит остаётся лицом к врагу.
func play_bash() -> void:
	if _asset != null:
		_asset_act("combo")
		return
	var t := _new_action(0.0, 0.32)
	if t == null:
		return
	t.tween_property(_arm_l, "rotation:x", 1.4, 0.08)
	t.tween_property(_grip_l, "rotation:x", -1.4, 0.08)
	t.tween_property(_torso, "rotation:y", -0.35, 0.08)


## Круговой удар: оборот всей модели с вытянутой в сторону рукой.
func play_spin() -> void:
	if _asset != null:
		_asset_act("spin")
		return
	var t := _new_action(0.42, 0.0)
	if t == null:
		return
	t.tween_property(_arm_r, "rotation:z", 1.3, 0.08)
	t.tween_property(_arm_r, "rotation:x", 0.3, 0.08)
	_spinning = true
	t.tween_property(self, "rotation:y", TAU, 0.35).from(0.0)
	t.chain().tween_callback(_reset_spin)


## Взмах рукой (приветствие).
func play_wave() -> void:
	if _asset != null:
		_asset_act("wave")
		return
	var t := _new_action(1.1, 0.0)
	if t == null:
		return
	t.set_parallel(false)
	t.tween_property(_arm_r, "rotation:z", 2.5, 0.2)
	t.parallel().tween_property(_arm_r, "rotation:x", 0.25, 0.2)
	for _i in 3:
		t.tween_property(_arm_r, "rotation:z", 2.15, 0.13)
		t.tween_property(_arm_r, "rotation:z", 2.55, 0.13)


## Получение урона: красноватая вспышка и отшатывание назад.
func play_hit() -> void:
	_flash = 1.0
	if _asset != null:
		_asset_recoil()
		# Клип реакции на удар — только когда стоит и ничего не делает
		if _act_end < 0.0 and _asset_speed < 0.3:
			_asset_act("hit")
		return
	if _root == null or not is_inside_tree():
		return
	if _hit != null and _hit.is_valid():
		_hit.kill()
	_hit = create_tween()
	_hit.set_parallel(true)
	_hit.tween_property(_root, "rotation:x", 0.22, 0.06)
	_hit.tween_property(_root, "position:z", 0.07, 0.06)
	_hit.chain().tween_property(_root, "rotation:x", 0.0, 0.2)
	_hit.tween_property(_root, "position:z", 0.0, 0.2)


## Новый твин действия; руки lock_r/lock_l секунд не трогает ходьба, потом плавно возвращаются в покой.
func _new_action(lock_r: float, lock_l: float) -> Tween:
	if _root == null or not is_inside_tree():
		return null
	if _action != null and _action.is_valid():
		_action.kill()
	if _spinning:
		_reset_spin()
	_lock_r = lock_r
	_lock_l = lock_l
	_action = create_tween()
	_action.set_parallel(true)
	return _action


func _reset_spin() -> void:
	_spinning = false
	rotation.y = 0.0




# ---------- Готовая модель из файла (Meshy/Mixamo) ----------

## Загрузить модель из файла: свой материал (toon, контур, вспышка урона), меч в правой руке,
## метки Head и Face на костях. false — файла нет, модель соберётся из примитивов.
func _setup_asset(path: String) -> bool:
	if not ResourceLoader.exists(path):
		return false
	var ps := load(path) as PackedScene
	if ps == null:
		return false
	var inst := ps.instantiate() as Node3D
	if inst == null:
		return false
	_asset = inst
	_asset.name = "Asset"
	# glTF смотрит в +Z, наши модели — в -Z
	_asset.rotation.y = PI
	add_child(_asset)
	_has_ears = true
	weapon_kind = "sword"

	var tex_path := path.get_basename() + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(tex_path):
		tex = load(tex_path) as Texture2D
	for n in _asset.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		mi.set_meta("no_toon", true)
		mi.custom_aabb = ASSET_AABB
		# Свой материал вместо импортированного: у того металличность glTF по умолчанию 1
		# (без карты металла модель выглядит тёмным металлом)
		var m := StandardMaterial3D.new()
		m.metallic = 0.0
		if tex != null:
			m.albedo_texture = tex
			# Тёмная кожа и одежда в тени почти чёрные: слабое собственное свечение текстуры
			m.emission_texture = tex
			m.emission_energy_multiplier = ASSET_GLOW
		m.albedo_color = Color.WHITE
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		Util.toon(m)
		# Эмиссия включена заранее (чёрная), чтобы вспышка урона не перекомпилировала шейдер
		m.emission_enabled = true
		m.emission = Color.BLACK
		if Quality.outlines():
			m.next_pass = _asset_outline_mat()
		m.set_meta("toon_done", true)
		mi.material_override = m
		_flash_mats.append(m)

	var skels := _asset.find_children("*", "Skeleton3D", true, false)
	var skel: Skeleton3D = null
	if not skels.is_empty():
		skel = skels[0] as Skeleton3D
	if skel != null:
		var head := _attach(skel, "Head", "Head")
		if head != null:
			_node(head, "Face", Vector3(0, 0.08, 0.1))
		var hand := _attach(skel, "RightHand", "GripR")
		if hand != null:
			var up := GRIP_DIR.normalized()
			var fx := (Vector3.UP - up * up.dot(Vector3.UP)).normalized()
			var sword := MeshInstance3D.new()
			sword.name = "Sword"
			sword.mesh = _sword_mesh()
			sword.material_override = _sword_mat()
			sword.set_meta("no_toon", true)
			sword.transform = Transform3D(Basis(fx, up, fx.cross(up)), GRIP_POS)
			hand.add_child(sword)

	var aps := _asset.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		_anim = aps[0] as AnimationPlayer
		for an in _anim.get_animation_list():
			var k := String(an).to_lower()
			if k.contains("/"):
				k = k.get_slice("/", 1)
			_clips[k] = String(an)
		if not _prepared.has(path):
			_prepared[path] = true
			for an in _anim.get_animation_list():
				var a := _anim.get_animation(an)
				var k := String(an).to_lower()
				if k.contains("walk") or k.ends_with("running") or k == "idle":
					a.loop_mode = Animation.LOOP_LINEAR
				_pin_root(a, skel)
	return true


## Метка на кости, имя которой оканчивается на bone_suffix (у Mixamo «mixamorig_Head» и т. п.).
func _attach(skel: Skeleton3D, bone_suffix: String, node_name: String) -> BoneAttachment3D:
	for i in skel.get_bone_count():
		var bn := skel.get_bone_name(i)
		if bn == bone_suffix or bn.ends_with("_" + bone_suffix) or bn.ends_with(":" + bone_suffix):
			var att := BoneAttachment3D.new()
			att.name = node_name
			att.bone_name = bn
			skel.add_child(att)
			# Сразу в позу покоя, не дожидаясь обновления скелета
			att.transform = skel.get_bone_global_pose(i)
			return att
	return null


## Убрать смещение бёдер по земле (X, Z) — анимации на месте; высота (прыжок, присед) остаётся.
static func _pin_root(a: Animation, skel: Skeleton3D) -> void:
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_POSITION_3D:
			continue
		var bn := String(a.track_get_path(t).get_concatenated_subnames())
		if not bn.ends_with("Hips"):
			continue
		var rest := Vector3.ZERO
		if skel != null and skel.find_bone(bn) >= 0:
			rest = skel.get_bone_rest(skel.find_bone(bn)).origin
		for k in a.track_get_key_count(t):
			var v: Vector3 = a.track_get_key_value(t, k)
			a.track_set_key_value(t, k, Vector3(rest.x, v.y, rest.z))


## Первый вариант из options, чей клип есть в модели: копия с настоящим именем клипа или [].
func _pick(options: Array) -> Array:
	for o in options:
		var c := _clip(String(o[0]))
		if c != "":
			var src: Array = o
			var r := src.duplicate()
			r[0] = c
			return r
	return []


## Имя клипа по ключу в нижнем регистре (или "").
func _clip(key: String) -> String:
	if _clips.has(key):
		return _clips[key]
	for k in _clips:
		if String(k).contains(key):
			return _clips[k]
	return ""


## Покой, шаг или бег по скорости; действие (удар, умение) доигрывается до конца.
func _asset_process(delta: float) -> void:
	_t += delta
	_asset_speed = lerpf(_asset_speed, _speed, 1.0 - exp(-10.0 * delta))
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 5.0)
		# Эмиссия умножается на ASSET_GLOW — вспышку усиливаем
		var fc := FLASH * (_flash * 0.9 / ASSET_GLOW)
		for m in _flash_mats:
			m.emission = fc
	if _anim == null:
		return
	if _act_end >= 0.0:
		if _anim.is_playing() and _anim.current_animation_position < _act_end:
			return
		_act_end = -1.0
		_loco = ""
	var want := "idle"
	if _asset_speed > 2.6:
		want = "run"
	elif _asset_speed > 0.3:
		want = "walk"
	if want == "idle":
		var idle := _pick(ASSET_IDLE)
		if idle.is_empty():
			return
		var looped := float(idle[3]) > 0.0
		if _loco != "idle":
			_loco = "idle"
			_anim.speed_scale = 1.0
			_anim.play(String(idle[0]), 0.25, float(idle[3]))
		if not looped:
			var t0 := float(idle[1])
			_anim.seek(t0 + (0.5 - 0.5 * cos(_t * 1.6)) * (float(idle[2]) - t0), true)
		return
	var loco := _pick(ASSET_WALK if want == "walk" else ASSET_RUN)
	if loco.is_empty():
		return
	var c := String(loco[0])
	if _loco != want:
		_loco = want
		_anim.play(c, 0.2)
	_anim.speed_scale = clampf(_asset_speed / (WALK_NATIVE if want == "walk" else RUN_NATIVE), 0.6, 1.7)


## Действие модели из файла: отрезок клипа (см. ASSET_ACTIONS).
func _asset_act(kind: String) -> void:
	if _anim == null or not is_inside_tree():
		return
	var a := _pick(ASSET_ACTIONS[kind])
	if a.is_empty():
		return
	var c := String(a[0])
	_anim.speed_scale = 1.0
	_anim.play(c, 0.08, float(a[3]))
	_anim.seek(float(a[1]), true)
	_act_end = float(a[2])
	_loco = ""


## Отшатывание модели из файла при уроне.
func _asset_recoil() -> void:
	if not is_inside_tree():
		return
	if _hit != null and _hit.is_valid():
		_hit.kill()
	_hit = create_tween()
	_hit.tween_property(_asset, "position:z", 0.08, 0.06)
	_hit.tween_property(_asset, "position:z", 0.0, 0.2)


static func _asset_outline_mat() -> ShaderMaterial:
	if _asset_outline == null:
		var sh := Shader.new()
		sh.code = ASSET_OUTLINE_SHADER
		_asset_outline = ShaderMaterial.new()
		_asset_outline.shader = sh
	return _asset_outline


## Короткий меч: клинок с острием, гарда, рукоять, навершие. Ось клинка +Y, рукоять в нуле.
static func _sword_mesh() -> ArrayMesh:
	if _sword != null:
		return _sword
	var b := GeoBuf.new()
	var steel := Color(0.85, 0.88, 0.96)
	var brass := Color(0.78, 0.6, 0.3)
	b.add(_box(Vector3(0.045, 0.6, 0.012)), Transform3D(Basis(), Vector3(0, 0.38, 0)), steel, 0)
	b.add(_prism(Vector3(0.045, 0.08, 0.012)), Transform3D(Basis(), Vector3(0, 0.72, 0)), steel, 0)
	b.add(_box(Vector3(0.15, 0.024, 0.036)), Transform3D(Basis(), Vector3(0, 0.07, 0)), brass, 0)
	b.add(_cyl(0.015, 0.015, 0.14, 8), Transform3D(Basis(), Vector3(0, -0.01, 0)), Color(0.26, 0.17, 0.13), 0)
	b.add(_sphere(0.022, 0.044, 8, 4), Transform3D(Basis(), Vector3(0, -0.09, 0)), brass, 0)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = b.verts
	arr[Mesh.ARRAY_NORMAL] = b.norms
	arr[Mesh.ARRAY_COLOR] = b.cols
	arr[Mesh.ARRAY_INDEX] = b.idx
	_sword = ArrayMesh.new()
	_sword.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return _sword


static func _sword_mat() -> StandardMaterial3D:
	if _sword_material != null:
		return _sword_material
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	Util.toon(m)
	m.metallic_specular = 0.7
	if Quality.outlines():
		m.next_pass = _outline_mat()
	m.set_meta("toon_done", true)
	_sword_material = m
	return m


# ---------- Узлы, кости и сборка геометрии ----------

func _node(parent: Node3D, node_name: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	n.position = pos
	parent.add_child(n)
	return n


## Узел-кость: его поворот/положение/масштаб каждый кадр копируются в кость скелета.
## Родитель кости — ближайший узел-кость выше; неподвижные узлы между ними запоминаются в _bone_pre.
func _bone(parent: Node3D, node_name: String, pos: Vector3) -> Node3D:
	var n := _node(parent, node_name, pos)
	var pre := Transform3D.IDENTITY
	var parent_bone := -1
	var p: Node3D = parent
	while p != null and p != self:
		if _bone_idx.has(p):
			parent_bone = int(_bone_idx[p])
			break
		pre = p.transform * pre
		p = p.get_parent() as Node3D
	var i := _skel.get_bone_count()
	_skel.add_bone(node_name)
	if parent_bone >= 0:
		_skel.set_bone_parent(i, parent_bone)
	_skel.set_bone_rest(i, pre * n.transform)
	_bone_idx[n] = i
	_bone_nodes.append(n)
	_bone_pre.append(pre)
	return n


## Освещаемая деталь: положение pos, поворот rot (как Node3D.rotation), масштаб scl относительно parent.
## ow — толщина контура (OL, OL_THIN или 0).
func _add(parent: Node3D, arrays: Array, pos: Vector3, col: Color, ow: float = OL,
		rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> void:
	_put(parent, arrays, Transform3D(Basis.from_euler(rot) * Basis.from_scale(scl), pos), col, ow, SOLID)


## Светящаяся неосвещаемая деталь (навершие посоха, фонарь, камень); alpha < 1 — полупрозрачная.
func _glow(parent: Node3D, arrays: Array, pos: Vector3, col: Color, alpha: float) -> void:
	_put(parent, arrays, Transform3D(Basis.IDENTITY, pos), Color(col.r, col.g, col.b, alpha), 0.0,
		HALO if alpha < 1.0 else GLOW)


## Деталь с трансформом xf относительно parent: вершины переводятся в пространство ближайшей кости.
## Если геометрия уже в кэше — ничего не делает (узлы-кости всё равно строятся).
func _put(parent: Node3D, arrays: Array, xf: Transform3D, col: Color, ow: float = OL, kind: int = SOLID) -> void:
	if not _collect:
		return
	var acc := xf
	var n: Node3D = parent
	while n != null and not _bone_idx.has(n):
		acc = n.transform * acc
		n = n.get_parent() as Node3D
	if n == null:
		push_error("CharacterModel: деталь вне костей")
		return
	var c := col
	if kind == SOLID:
		c = Color(col.r, col.g, col.b, clampf(ow / OL, 0.0, 1.0))
	_bufs[kind].add(arrays, acc, c, int(_bone_idx[n]))


## Конус от root (основание радиуса r) к острому кончику tip.
func _spike(parent: Node3D, root: Vector3, tip: Vector3, r: float, col: Color) -> void:
	var d := tip - root
	_put(parent, _cyl(0.0, r, d.length(), 7), Transform3D(_basis_y(d), (root + tip) * 0.5), col, OL_THIN)


## Цилиндр (или усечённый конус) от точки a (радиус ra) до точки b (радиус rb).
func _segment(parent: Node3D, a: Vector3, b: Vector3, ra: float, rb: float, col: Color,
		ow: float = OL_THIN) -> void:
	var d := b - a
	_put(parent, _cyl(rb, ra, d.length(), 7), Transform3D(_basis_y(d), (a + b) * 0.5), col, ow)


## Поворот, переводящий ось +Y в направление dir.
static func _basis_y(dir: Vector3) -> Basis:
	var d := dir.normalized()
	if d.dot(Vector3.UP) < -0.9999:
		return Basis(Vector3.RIGHT, PI)
	return Basis(Quaternion(Vector3.UP, d))


## Собрать накопленные детали в меши: Body (освещаемое), Glow (свечение по видам), лицо.
func _bake() -> Dictionary:
	var body := ArrayMesh.new()
	_bufs[SOLID].commit(body)
	var glow: ArrayMesh = null
	var kinds: Array[int] = []
	for kind: int in [GLOW, HALO]:
		var b: GeoBuf = _bufs[kind]
		if b.is_empty():
			continue
		if glow == null:
			glow = ArrayMesh.new()
		b.commit(glow)
		kinds.append(kind)
	var face_open := _face_mesh(false)
	var face_closed := _face_mesh(true) if _can_blink else face_open
	return {"body": body, "glow": glow, "glow_kinds": kinds, "face_open": face_open, "face_closed": face_closed}


## Меши модели под скелетом: одна привязка (Skin) на все, позы привязки единичные
## (вершины уже в пространстве своей кости).
func _make_meshes(geo: Dictionary) -> void:
	var skin := Skin.new()
	for i in _skel.get_bone_count():
		skin.add_bind(i, Transform3D.IDENTITY)

	var body := _skinned("Body", geo["body"], skin)
	var bm := StandardMaterial3D.new()
	bm.vertex_color_use_as_albedo = true
	bm.vertex_color_is_srgb = true
	Util.toon(bm)
	# Эмиссия включена заранее (чёрная), чтобы вспышка урона не перекомпилировала шейдер
	bm.emission_enabled = true
	bm.emission = Color.BLACK
	if Quality.outlines():
		bm.next_pass = _outline_mat()
	# Хук main.gd (Util.toonify_mesh) уже не тронет: свет и контур настроены здесь
	bm.set_meta("toon_done", true)
	body.material_override = bm
	_flash_mats.append(bm)

	var glow: ArrayMesh = geo["glow"]
	if glow != null:
		var gi := _skinned("Glow", glow, skin)
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gi.set_meta("no_outline", true)
		var kinds: Array[int] = geo["glow_kinds"]
		for si in kinds.size():
			gi.set_surface_override_material(si, _glow_mat(kinds[si]))

	_face_open = geo["face_open"]
	_face_closed = geo["face_closed"]
	_face = _skinned("Face", _face_open, skin)
	_face.material_override = _face_mat()
	_face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_face.set_meta("no_outline", true)


func _skinned(node_name: String, mesh: ArrayMesh, skin: Skin) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.skin = skin
	mi.custom_aabb = CULL_AABB
	mi.skeleton = NodePath("..")
	_skel.add_child(mi)
	return mi


## Позы костей скелета = текущие трансформы узлов-костей (их двигают _process и твины).
func _sync_bones() -> void:
	if _skel == null:
		return
	for i in _bone_nodes.size():
		var t: Transform3D = _bone_pre[i] * _bone_nodes[i].transform
		_skel.set_bone_pose_position(i, t.origin)
		_skel.set_bone_pose_rotation(i, t.basis.get_rotation_quaternion())
		_skel.set_bone_pose_scale(i, t.basis.get_scale())


# ---------- Материалы (общие для всех моделей, кроме освещаемого: у него своя вспышка) ----------

## Контур по нормалям: толщина и цвет — из цвета вершины.
static func _outline_mat() -> ShaderMaterial:
	if _outline_material != null:
		return _outline_material
	_outline_shader = Shader.new()
	_outline_shader.code = OUTLINE_SHADER
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = _outline_shader
	_outline_material.set_shader_parameter("width", OL)
	return _outline_material


## Свечение: неосвещаемый цвет вершины; HALO — полупрозрачное (альфа вершины).
static func _glow_mat(kind: int) -> StandardMaterial3D:
	if _glow_mats.has(kind):
		return _glow_mats[kind]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	if kind == HALO:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.set_meta("toon_done", true)
	_glow_mats[kind] = m
	return m


## Лицо: неосвещаемое, цвета вершин, видно с обеих сторон.
static func _face_mat() -> StandardMaterial3D:
	if _face_material != null:
		return _face_material
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.vertex_color_use_as_albedo = true
	fm.vertex_color_is_srgb = true
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	fm.set_meta("toon_done", true)
	_face_material = fm
	return fm


# ---------- Низкополигональные примитивы (массивы вершин, общий кэш) ----------

static func _sphere(r: float, h: float, seg: int = 12, rings: int = 6) -> Array:
	var key := "s%.4f|%.4f|%d|%d" % [r, h, seg, rings]
	if not _arr_cache.has(key):
		var m := SphereMesh.new()
		m.radius = r
		m.height = h
		m.radial_segments = seg
		m.rings = rings
		_arr_cache[key] = m.get_mesh_arrays()
	return _arr_cache[key]


static func _capsule(r: float, h: float) -> Array:
	var key := "c%.4f|%.4f" % [r, h]
	if not _arr_cache.has(key):
		var m := CapsuleMesh.new()
		m.radius = r
		m.height = h
		m.radial_segments = 10
		m.rings = 3
		_arr_cache[key] = m.get_mesh_arrays()
	return _arr_cache[key]


static func _cyl(top: float, bottom: float, h: float, seg: int = 10) -> Array:
	var key := "y%.4f|%.4f|%.4f|%d" % [top, bottom, h, seg]
	if not _arr_cache.has(key):
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = h
		m.radial_segments = seg
		m.rings = 1
		_arr_cache[key] = m.get_mesh_arrays()
	return _arr_cache[key]


static func _torus(inner: float, outer: float) -> Array:
	var key := "t%.4f|%.4f" % [inner, outer]
	if not _arr_cache.has(key):
		var m := TorusMesh.new()
		m.inner_radius = inner
		m.outer_radius = outer
		m.rings = 16
		m.ring_segments = 6
		_arr_cache[key] = m.get_mesh_arrays()
	return _arr_cache[key]


static func _box(size: Vector3) -> Array:
	var key := "b%s" % size
	if not _arr_cache.has(key):
		var m := BoxMesh.new()
		m.size = size
		_arr_cache[key] = m.get_mesh_arrays()
	return _arr_cache[key]


static func _prism(size: Vector3) -> Array:
	var key := "p%s" % size
	if not _arr_cache.has(key):
		var m := PrismMesh.new()
		m.size = size
		_arr_cache[key] = m.get_mesh_arrays()
	return _arr_cache[key]
