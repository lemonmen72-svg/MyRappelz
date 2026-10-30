class_name CharacterModel
extends Node3D
## Аниме-гуманоид из примитивов (cel-shading, контур): крупная голова, большие глаза, причёска по расе,
## одежда и оружие по классу. Временная модель до замены на аватары из VRoid.
## Рост ~1.8 м, ноги на y = 0, лицом к -Z.
##
## Использование:
##   var m := CharacterModel.new()
##   m.setup(CharacterModel.spec_for(race_id, class_id))   # или merchant_spec()
##   add_child(m)
## Анимации кодом: дыхание и моргание в покое, ходьба (set_move_speed), play_attack() (по оружию),
## play_shoot(), play_cast(), play_buff(), play_bash(), play_spin(), play_hit(), play_wave();
## волосы, плащ и шарф покачиваются сами.
##
## Скелет узлов: Root (отдача при уроне) → LegL/LegR (от бедра), Torso (от бедра) → Head,
## ArmL/ArmR (от плеча) → GripL/GripR (кисть, оружие вдоль +Y). Плечо повёрнуто по X > 0 — рука вперёд.

## Высота бёдер над землёй.
const HIP_Y := 0.9
## Плечи и центр головы — относительно бёдер (узел Torso).
const SHOULDER_Y := 0.46
const SHOULDER_X := 0.215
const HEAD_Y := 0.69
const HEAD_R := 0.2
## Толщина контура (как width в outline.gdshader): основной и для мелких деталей.
const OL := 0.017
const OL_THIN := 0.01
const FLASH := Color(1.0, 0.32, 0.28)
const FACE_SEG := 14
const LASH := Color(0.12, 0.07, 0.1)
const GOLD := Color(0.95, 0.78, 0.35)

## Контур по нормалям («вывернутая оболочка»): у капсул и сфер толщина ровная по всей длине,
## в отличие от раздувания от центра в outline.gdshader (у вытянутых деталей бока остаются без контура).
const OUTLINE_SHADER := """shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(0.12, 0.09, 0.14, 1.0);
uniform float width = 0.02;

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
var _ears: Array[MeshInstance3D] = []
var _mats: Dictionary = {}
var _flash_mats: Array[StandardMaterial3D] = []

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

static var _mesh_cache: Dictionary = {}
static var _outline_cache: Dictionary = {}
static var _outline_shader: Shader


# ---------- Параметры внешности ----------

## Внешность персонажа по расе и классу (ClassData).
static func spec_for(race_id: String, class_id: String) -> Dictionary:
	var r := ClassData.race(race_id)
	var c := ClassData.cls(class_id)
	var main_c: Color = c.get("color", Color(0.6, 0.3, 0.2))
	return {
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
	_mats.clear()
	_flash_mats.clear()
	_ears.clear()
	_orb = null
	_cape = null
	_hair_back = null
	weapon_kind = String(s.get("weapon", ""))
	_girth = float(s.get("girth", 1.0))
	_can_blink = String(s.get("eye_style", "normal")) != "smile"
	var outfit := String(s.get("outfit", "warrior"))
	var pal := _palette(outfit)
	_leg_amp = 0.45 if String(pal["skirt_len"]) == "long" else 0.7

	_root = _node(self, "Root", Vector3.ZERO)
	_build_legs(pal)
	_torso = _node(_root, "Torso", Vector3(0, HIP_Y, 0))
	_build_body(pal)
	_build_arms(pal)
	_head = _node(_torso, "Head", Vector3(0, HEAD_Y, 0))
	_build_head()
	_build_hair()
	_build_outfit(outfit)
	_build_weapon()
	_apply_rest()
	_blink = randf_range(1.5, 4.0)
	return self


## Есть ли заострённые уши (эльфы).
func has_ears() -> bool:
	return not _ears.is_empty()


## Сколько мешей в модели (для проверки бюджета на телефоне).
func mesh_count() -> int:
	return find_children("*", "MeshInstance3D", true, false).size()


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
		var leg := _node(_root, "LegR" if side > 0.0 else "LegL", Vector3(hip_x * side, HIP_Y, 0))
		_add(leg, _capsule_mesh(0.075, 0.84), Vector3(0, -0.42, 0), _mat(pal["pants"]))
		_add(leg, _capsule_mesh(0.088, 0.25), Vector3(0, -0.78, -0.025), _mat(pal["boots"]))
		if side > 0.0:
			_leg_r = leg
		else:
			_leg_l = leg


func _build_body(pal: Dictionary) -> void:
	var g := _girth
	var chest := _add(_torso, _capsule_mesh(0.165, 0.6), Vector3(0, 0.27, 0), _mat(pal["chest"]))
	chest.scale = Vector3(g, 1.0, 0.8 * g)
	var belt := _add(_torso, _cyl_mesh(0.172, 0.172, 0.07), Vector3(0, 0.07, 0), _mat(pal["belt"], OL_THIN))
	belt.scale = Vector3(g, 1.0, 0.82 * g)
	var bottom := 0.25
	var h := 0.3
	match String(pal["skirt_len"]):
		"mid":
			bottom = 0.29
			h = 0.5
		"long":
			bottom = 0.33
			h = 0.76
	var skirt := _add(_torso, _cyl_mesh(0.165, bottom, h, 12), Vector3(0, 0.06 - h * 0.5, 0), _mat(pal["skirt"]))
	skirt.scale = Vector3(g, 1.0, 0.85 * g)


func _build_arms(pal: Dictionary) -> void:
	var skin: Color = spec.get("skin", Color(0.95, 0.8, 0.65))
	var sx := SHOULDER_X + (_girth - 1.0) * 0.14
	for sd in [-1.0, 1.0]:
		var side: float = sd
		var arm := _node(_torso, "ArmR" if side > 0.0 else "ArmL", Vector3(sx * side, SHOULDER_Y, 0))
		_add(arm, _capsule_mesh(0.058, 0.5), Vector3(0, -0.22, 0), _mat(pal["sleeve"]))
		_add(arm, _sphere_mesh(0.062, 0.124, 10, 5), Vector3(0, -0.5, 0), _mat(skin, OL_THIN))
		var grip := _node(arm, "GripR" if side > 0.0 else "GripL", Vector3(0, -0.52, -0.01))
		if side > 0.0:
			_arm_r = arm
			_grip_r = grip
		else:
			_arm_l = arm
			_grip_l = grip


# ---------- Голова и лицо ----------

func _build_head() -> void:
	var skin: Color = spec.get("skin", Color(0.95, 0.8, 0.65))
	_add(_head, _sphere_mesh(HEAD_R, HEAD_R * 2.0, 16, 8), Vector3.ZERO, _mat(skin))

	# Лицо — один меш с цветами вершин (глаза, брови, рот, румянец): дёшево для телефона.
	# Моргание — подмена меша на вариант с закрытыми глазами.
	_face_open = _face_mesh(false)
	_face_closed = _face_mesh(true) if _can_blink else _face_open
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.vertex_color_use_as_albedo = true
	fm.vertex_color_is_srgb = true
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	fm.set_meta("toon_done", true)
	_face = _add(_head, _face_open, Vector3.ZERO, fm, false)
	_face.name = "Face"
	_face.set_meta("no_outline", true)

	if bool(spec.get("ears", false)):
		for sd in [-1.0, 1.0]:
			var side: float = sd
			var base := _dir(1.5 * side, -0.08) * 0.185
			var d := Vector3(0.88 * side, 0.42, 0.2).normalized()
			var ear := _add(_head, _cyl_mesh(0.0, 0.046, 0.21, 6), base + d * 0.1, _mat(skin, OL_THIN))
			ear.basis = _basis_y(d)
			ear.scale = Vector3(1.0, 1.0, 0.45)
			ear.name = "EarR" if side > 0.0 else "EarL"
			_ears.append(ear)

	if bool(spec.get("beard", false)):
		var hair: Color = spec.get("hair", Color(0.5, 0.45, 0.4))
		for sd in [-1.0, 1.0]:
			var side: float = sd
			var m := _add(_head, _sphere_mesh(0.035, 0.07, 8, 4),
				_dir(0.12 * side, -0.42) * (HEAD_R + 0.008) + Vector3(0.012 * side, 0, 0), _mat(hair, OL_THIN), false)
			m.rotation.z = -0.35 * side
			m.scale = Vector3(1.3, 0.6, 0.5)


## Направление от центра головы: u — поворот (0 = вперёд, + = вправо), v — наклон (+ = вверх).
static func _dir(u: float, v: float) -> Vector3:
	return Vector3(sin(u) * cos(v), sin(v), -cos(u) * cos(v))


func _face_mesh(closed: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
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
		_f_ellipse(st, 0.56 * side, -0.36, Vector2.ZERO, 0.032, 0.015, 0.0015, blush)
		_f_arc(st, 0.38 * side, 0.24, Vector2.ZERO, 0.046, 0.012, 0.12 * PI, 0.88 * PI, 0.011, side, 0.0025, brow)
		if smile:
			# Глаза-улыбки «^ ^»
			_f_arc(st, u, v, Vector2(0, -0.012), 0.036, 0.03, 0.1 * PI, 0.9 * PI, 0.012, side, 0.003, LASH)
		elif closed:
			_f_arc(st, u, v, Vector2(0, 0.006), 0.044, 0.014, 1.05 * PI, 1.95 * PI, 0.011, side, 0.003, LASH)
		else:
			# Белок, радужка с осветлением снизу, зрачок, два блика, ресницы сверху
			var ic := Vector2(-0.004 * side, -0.006)
			_f_ellipse(st, u, v, Vector2.ZERO, 0.044, 0.052, 0.0015, Color(0.98, 0.98, 1.0))
			_f_ellipse(st, u, v, ic, 0.031, 0.042, 0.003, iris)
			_f_ellipse(st, u, v, ic + Vector2(0, -0.02), 0.022, 0.015, 0.0038, iris.lightened(0.35))
			_f_ellipse(st, u, v, ic + Vector2(0, 0.004), 0.016, 0.024, 0.0045, iris.darkened(0.72))
			_f_ellipse(st, u, v, ic + Vector2(0.013 * side, 0.017), 0.011, 0.012, 0.006, Color.WHITE)
			_f_ellipse(st, u, v, ic + Vector2(-0.011 * side, -0.02), 0.005, 0.005, 0.006, Color.WHITE)
			_f_arc(st, u, v, Vector2.ZERO, 0.046, 0.054, -0.06 * PI, 0.95 * PI, 0.013, side, 0.0055, LASH)
	# Маленький рот-улыбка
	_f_arc(st, 0.0, -0.55, Vector2.ZERO, 0.022, 0.009, 1.12 * PI, 1.88 * PI, 0.006, 1.0, 0.002,
		Color(0.5, 0.2, 0.22))
	return st.commit()


## Точка на поверхности головы: центр (u, v), смещение off (м) в касательной плоскости, lift — над кожей.
func _fp(u: float, v: float, off: Vector2, lift: float) -> Vector3:
	var d := _dir(u, v)
	var tx := d.cross(Vector3.UP).normalized()
	var ty := tx.cross(d).normalized()
	return (d * HEAD_R + tx * off.x + ty * off.y).normalized() * (HEAD_R + lift)


func _f_ellipse(st: SurfaceTool, u: float, v: float, c: Vector2, a: float, b: float, lift: float,
		col: Color) -> void:
	var center := _fp(u, v, c, lift)
	var prev := _fp(u, v, c + Vector2(a, 0.0), lift)
	for i in range(1, FACE_SEG + 1):
		var th := TAU * float(i) / float(FACE_SEG)
		var cur := _fp(u, v, c + Vector2(a * cos(th), b * sin(th)), lift)
		_tri(st, center, prev, cur, col)
		prev = cur


## Дуга-мазок по эллипсу (a, b) от угла t0 до t1, толщина сходит на нет к концам. side отражает по X.
func _f_arc(st: SurfaceTool, u: float, v: float, c: Vector2, a: float, b: float, t0: float, t1: float,
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
		var a_in := _fp(u, v, c + Vector2(a * cs, b * sn), lift)
		var a_out := _fp(u, v, c + Vector2((a + k) * cs, (b + k) * sn), lift)
		if i > 0:
			_tri(st, p_in, p_out, a_out, col)
			_tri(st, p_in, a_out, a_in, col)
		p_in = a_in
		p_out = a_out


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	st.set_color(col)
	st.add_vertex(a)
	st.set_color(col)
	st.add_vertex(b)
	st.set_color(col)
	st.add_vertex(c)


# ---------- Причёски ----------

func _build_hair() -> void:
	var hair: Color = spec.get("hair", Color(0.4, 0.25, 0.12))
	var acc: Color = spec.get("accent", GOLD)
	var style := String(spec.get("hair_style", "short"))
	var hat := bool(spec.get("hat", false))
	# «Шапка» волос сдвинута вверх-назад: лицо открыто, затылок и виски закрыты
	var cap_c := Vector3(0, 0.035, 0.045)
	_add(_head, _sphere_mesh(0.218, 0.436, 14, 7), cap_c, _mat(hair))
	if not hat:
		# Светлое кольцо-блик на волосах (аниме-приём)
		var rh := 0.105
		var rho := sqrt(0.218 * 0.218 - rh * rh)
		_add(_head, _torus_mesh(rho - 0.006, rho + 0.012), cap_c + Vector3(0, rh, 0),
			_mat(hair.lightened(0.4), 0.0), false)

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
			_hair_back = _node(_head, "HairBack", Vector3(0, 0.02, 0.13))
			var mass := _add(_hair_back, _sphere_mesh(0.17, 0.78, 12, 6), Vector3(0, -0.3, 0.06), _mat(hair))
			mass.scale = Vector3(1.1, 1.0, 0.55)
			for sd in [-1.0, 1.0]:
				var side: float = sd
				_spike(_hair_back, Vector3(0.1 * side, -0.05, 0.08), Vector3(0.16 * side, -0.66, 0.08), 0.07, hair)
			_add(_head, _sphere_mesh(0.026, 0.052, 8, 4), _dir(0.95, 0.6) * (HEAD_R + 0.035),
				_mat(acc, OL_THIN), false)
		"ponytail":
			# Асимметричная чёлка, пряди у лица, высокий хвост
			_strand(-0.3, 1.1, -0.58, 0.25, 0.065, hair)
			_strand(-0.05, 1.15, -0.12, 0.3, 0.065, hair)
			_strand(0.2, 1.12, 0.26, 0.4, 0.06, hair)
			_strand(0.45, 1.05, 0.78, 0.2, 0.055, hair)
			_strand(1.2, 0.5, 1.3, -0.48, 0.055, hair)
			_strand(-1.2, 0.5, -1.3, -0.48, 0.055, hair)
			_add(_head, _sphere_mesh(0.045, 0.09, 8, 4), Vector3(0, 0.17, 0.2), _mat(acc, OL_THIN), false)
			_hair_back = _node(_head, "HairBack", Vector3(0, 0.17, 0.22))
			_add(_hair_back, _sphere_mesh(0.075, 0.13, 10, 5), Vector3(0, -0.01, 0.04), _mat(hair))
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
			_hair_back = _node(_head, "HairBack", Vector3(0, 0.05, 0.1))
			_spike(_hair_back, Vector3(0.1, 0.07, 0.04), Vector3(0.14, -0.2, 0.11), 0.085, hair)
			_spike(_hair_back, Vector3(-0.1, 0.07, 0.04), Vector3(-0.14, -0.2, 0.11), 0.085, hair)
			_spike(_hair_back, Vector3(0, 0.08, 0.06), Vector3(0, -0.24, 0.13), 0.09, hair)
			if not hat:
				_spike(_head, Vector3(0, 0.24, 0.0), Vector3(0.05, 0.34, -0.07), 0.025, hair)

	if hat:
		var hat_c := Color(0.78, 0.58, 0.3)
		var brim := _add(_head, _cyl_mesh(0.36, 0.36, 0.03, 16), Vector3(0, 0.16, 0.03), _mat(hat_c))
		brim.rotation.x = 0.12
		_add(_head, _sphere_mesh(0.18, 0.24, 12, 6), Vector3(0, 0.24, 0.04), _mat(hat_c))
		_add(_head, _cyl_mesh(0.183, 0.183, 0.045, 12), Vector3(0, 0.19, 0.04), _mat(Color(0.72, 0.25, 0.2), OL_THIN))
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
			var fur := _add(_torso, _sphere_mesh(0.2, 0.13), Vector3(0, 0.47, 0.01), _mat(Color(0.85, 0.75, 0.58)))
			fur.scale = Vector3(1.0, 1.0, 0.85)
			_add(_torso, _box_mesh(Vector3(0.075, 0.06, 0.025)), Vector3(0, 0.07, -0.145), _mat(acc, OL_THIN), false)
			for arm in [_arm_l, _arm_r]:
				_add(arm, _cyl_mesh(0.066, 0.07, 0.15), Vector3(0, -0.37, 0), _mat(Color(0.42, 0.28, 0.16), OL_THIN))
		"ranger":
			# Короткая накидка с откинутым капюшоном, колчан за спиной, поясная сумка
			var cape_c := main_c.darkened(0.3)
			var capelet := _add(_torso, _cyl_mesh(0.1, 0.25, 0.24, 12), Vector3(0, 0.44, 0), _mat(cape_c))
			capelet.scale = Vector3(1.0, 1.0, 0.88)
			var hood := _add(_torso, _sphere_mesh(0.13, 0.17), Vector3(0, 0.53, 0.15), _mat(cape_c))
			hood.scale = Vector3(1.1, 1.0, 0.75)
			var q := _node(_torso, "Quiver", Vector3(0.08, 0.28, 0.2))
			q.rotation.z = -0.35
			_add(q, _cyl_mesh(0.06, 0.055, 0.5), Vector3.ZERO, _mat(Color(0.45, 0.28, 0.15)))
			_add(q, _cyl_mesh(0.08, 0.035, 0.12, 8), Vector3(0, 0.3, 0), _mat(Color(0.93, 0.9, 0.82), OL_THIN), false)
			_add(_torso, _box_mesh(Vector3(0.1, 0.1, 0.06)), Vector3(-0.13, 0.02, -0.12),
				_mat(Color(0.5, 0.35, 0.2), OL_THIN), false)
		"guardian":
			# Крупные наплечники, плащ цвета акцента, знак на груди
			_pads(0.125, 0.17, main_c)
			_cape = _node(_torso, "Cape", Vector3(0, 0.5, 0.12))
			_cape_rest = -0.14
			_add(_cape, _box_mesh(Vector3(0.36, 0.95, 0.025)), Vector3(0, -0.47, 0.03), _mat(acc.darkened(0.1)))
			var em := _add(_torso, _box_mesh(Vector3(0.08, 0.08, 0.02)), Vector3(0, 0.33, -0.135), _mat(GOLD, OL_THIN), false)
			em.rotation.z = PI * 0.25
		"cleric":
			# Накидка цвета класса, полоса ткани спереди, золотая кайма подола
			var capelet := _add(_torso, _cyl_mesh(0.1, 0.26, 0.22, 12), Vector3(0, 0.45, 0), _mat(main_c))
			capelet.scale = Vector3(1.0, 1.0, 0.88)
			var panel := _add(_torso, _box_mesh(Vector3(0.12, 0.62, 0.02)), Vector3(0, -0.25, -0.2), _mat(main_c))
			panel.rotation.x = 0.17
			var hem := _add(_torso, _torus_mesh(0.315, 0.35), Vector3(0, -0.69, 0), _mat(acc, OL_THIN), false)
			hem.scale = Vector3(1.0, 1.0, 0.85)
		"assassin":
			# Шарф с длинными концами, развевающимися за спиной
			_add(_torso, _sphere_mesh(0.155, 0.13), Vector3(0, 0.5, -0.005), _mat(acc))
			_cape = _node(_torso, "Scarf", Vector3(0.06, 0.5, 0.12))
			_cape_rest = -0.25
			_add(_cape, _box_mesh(Vector3(0.09, 0.5, 0.02)), Vector3(0, -0.25, 0.02), _mat(acc))
			var tail := _add(_cape, _box_mesh(Vector3(0.08, 0.38, 0.02)), Vector3(0.07, -0.2, 0.03), _mat(acc.darkened(0.15)))
			tail.rotation.z = 0.15
		"warlock":
			# Высокий воротник-веер за головой, длинный плащ, светящийся камень на груди
			var collar := _add(_torso, _sphere_mesh(0.21, 0.32), Vector3(0, 0.6, 0.13), _mat(main_c.darkened(0.45)))
			collar.scale = Vector3(1.0, 1.0, 0.3)
			_cape = _node(_torso, "Cape", Vector3(0, 0.5, 0.12))
			_cape_rest = -0.16
			_add(_cape, _box_mesh(Vector3(0.4, 1.05, 0.025)), Vector3(0, -0.52, 0.03), _mat(main_c.darkened(0.5)))
			_add(_torso, _sphere_mesh(0.035, 0.07, 8, 4), Vector3(0, 0.36, -0.14), _glow(acc, 1.0), false)
		"merchant":
			# Большой рюкзак со скаткой и фонариком, фартук, лямки
			var pack_z := 0.132 * _girth + 0.14
			_add(_torso, _box_mesh(Vector3(0.48, 0.58, 0.28)), Vector3(0, 0.27, pack_z), _mat(Color(0.55, 0.38, 0.22)))
			var roll := _add(_torso, _cyl_mesh(0.09, 0.09, 0.6, 10), Vector3(0, 0.62, pack_z), _mat(Color(0.66, 0.27, 0.22)))
			roll.rotation.z = PI * 0.5
			_add(_torso, _sphere_mesh(0.05, 0.1, 8, 4), Vector3(0.3, 0.08, pack_z), _glow(Color(1.0, 0.85, 0.45), 1.0), false)
			var apron := _add(_torso, _box_mesh(Vector3(0.28, 0.42, 0.02)), Vector3(0, -0.12, -0.235),
				_mat(Color(0.93, 0.87, 0.72)))
			apron.rotation.x = 0.2
			for sd in [-1.0, 1.0]:
				var side: float = sd
				_add(_torso, _box_mesh(Vector3(0.04, 0.3, 0.02)), Vector3(0.1 * side, 0.36, -0.165),
					_mat(Color(0.42, 0.28, 0.16), OL_THIN), false)


## Наплечники на обоих плечах (двигаются вместе с рукой).
func _pads(r: float, h: float, col: Color) -> void:
	for arm in [_arm_l, _arm_r]:
		var a: Node3D = arm
		var side := signf(a.position.x)
		var pad := _add(a, _sphere_mesh(r, h), Vector3(0.025 * side, 0.01, 0), _mat(col))
		pad.rotation.z = -0.35 * side


# ---------- Оружие (вдоль +Y узла кисти) ----------

func _build_weapon() -> void:
	var main_c: Color = spec.get("main", Color(0.6, 0.3, 0.2))
	var acc: Color = spec.get("accent", GOLD)
	var steel := Color(0.82, 0.85, 0.9)
	var wood := Color(0.48, 0.31, 0.17)
	match weapon_kind:
		"axe":
			var w := _node(_grip_r, "Axe", Vector3.ZERO)
			_add(w, _cyl_mesh(0.024, 0.026, 1.0, 8), Vector3(0, 0.3, 0), _mat(wood, OL_THIN))
			_add(w, _cyl_mesh(0.032, 0.032, 0.14, 8), Vector3(0, 0.0, 0), _mat(acc.darkened(0.3), OL_THIN), false)
			var blade := _add(w, _cyl_mesh(0.15, 0.15, 0.03, 14), Vector3(0, 0.64, -0.11), _mat(steel, OL_THIN))
			blade.rotation.z = PI * 0.5
			_add(w, _box_mesh(Vector3(0.06, 0.15, 0.07)), Vector3(0, 0.64, 0), _mat(Color(0.42, 0.42, 0.48), OL_THIN), false)
		"sword", "sword_shield":
			var s := _node(_grip_r, "Sword", Vector3.ZERO)
			_add(s, _cyl_mesh(0.022, 0.022, 0.2, 8), Vector3.ZERO, _mat(Color(0.3, 0.2, 0.15), OL_THIN), false)
			_add(s, _sphere_mesh(0.03, 0.06, 8, 4), Vector3(0, -0.11, 0), _mat(GOLD, OL_THIN), false)
			_add(s, _box_mesh(Vector3(0.05, 0.045, 0.22)), Vector3(0, 0.11, 0), _mat(GOLD, OL_THIN), false)
			_add(s, _box_mesh(Vector3(0.016, 0.7, 0.07)), Vector3(0, 0.48, 0), _mat(steel, OL_THIN))
			var tip := _add(s, _prism_mesh(Vector3(0.07, 0.12, 0.016)), Vector3(0, 0.89, 0), _mat(steel, OL_THIN), false)
			tip.rotation.y = PI * 0.5
			if weapon_kind == "sword_shield":
				var sh := _node(_grip_l, "Shield", Vector3(-0.07, 0.1, -0.05))
				var disc := _add(sh, _cyl_mesh(0.25, 0.25, 0.05, 16), Vector3.ZERO, _mat(acc))
				disc.rotation.x = PI * 0.5
				var rim := _add(sh, _torus_mesh(0.225, 0.265), Vector3.ZERO, _mat(main_c, OL_THIN), false)
				rim.rotation.x = PI * 0.5
				_add(sh, _sphere_mesh(0.065, 0.13, 10, 5), Vector3(0, 0, -0.035), _mat(GOLD, OL_THIN), false)
		"staff":
			var st := _node(_grip_r, "Staff", Vector3.ZERO)
			var dark := String(spec.get("outfit", "")) == "warlock"
			var wood_c := Color(0.3, 0.19, 0.28) if dark else Color(0.8, 0.66, 0.44)
			var metal_c := Color(0.55, 0.55, 0.64) if dark else GOLD
			var glow_c := acc if dark else main_c
			_add(st, _cyl_mesh(0.022, 0.026, 1.65, 8), Vector3(0, 0.3, 0), _mat(wood_c, OL_THIN))
			var ring := _add(st, _torus_mesh(0.075, 0.1), Vector3(0, 1.22, 0), _mat(metal_c, OL_THIN), false)
			ring.rotation.x = PI * 0.5
			if dark:
				for sd in [-1.0, 1.0]:
					var side: float = sd
					_spike(st, Vector3(0.06 * side, 1.12, 0), Vector3(0.14 * side, 1.43, 0), 0.026, metal_c)
			else:
				_spike(st, Vector3(0, 1.3, 0), Vector3(0, 1.45, 0), 0.026, metal_c)
			_orb = _node(st, "Orb", Vector3(0, 1.22, 0))
			_add(_orb, _sphere_mesh(0.06, 0.12, 10, 5), Vector3.ZERO, _glow(glow_c.lightened(0.4), 1.0), false)
			_add(_orb, _sphere_mesh(0.12, 0.24, 12, 6), Vector3.ZERO, _glow(glow_c, 0.3), false)
		"bow":
			var b := _node(_grip_l, "Bow", Vector3.ZERO)
			var bw := Color(0.44, 0.27, 0.14)
			_add(b, _cyl_mesh(0.027, 0.027, 0.22, 8), Vector3.ZERO, _mat(Color(0.3, 0.2, 0.12), OL_THIN), false)
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
				_add(d, _cyl_mesh(0.02, 0.02, 0.13, 6), Vector3.ZERO, _mat(acc, OL_THIN), false)
				_add(d, _box_mesh(Vector3(0.12, 0.025, 0.03)), Vector3(0, 0.075, 0), _mat(Color(0.3, 0.3, 0.36), OL_THIN), false)
				var bl := _add(d, _cyl_mesh(0.0, 0.034, 0.34, 6), Vector3(0, 0.25, 0), _mat(Color(0.78, 0.75, 0.88), OL_THIN))
				bl.scale = Vector3(1.0, 1.0, 0.35)


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


## Обычная атака под оружие: удар, выстрел из лука или взмах посохом.
func play_attack() -> void:
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


## Усиление (клич, щит, рывок): обе руки вверх.
func play_buff() -> void:
	var t := _new_action(0.5, 0.5)
	if t == null:
		return
	t.tween_property(_arm_r, "rotation:x", 2.5, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_arm_r, "rotation:z", 0.55, 0.14)
	t.tween_property(_arm_l, "rotation:x", 2.5, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_arm_l, "rotation:z", -0.55, 0.14)


## Удар щитом: выпад левой рукой, щит остаётся лицом к врагу.
func play_bash() -> void:
	var t := _new_action(0.0, 0.32)
	if t == null:
		return
	t.tween_property(_arm_l, "rotation:x", 1.4, 0.08)
	t.tween_property(_grip_l, "rotation:x", -1.4, 0.08)
	t.tween_property(_torso, "rotation:y", -0.35, 0.08)


## Круговой удар: оборот всей модели с вытянутой в сторону рукой.
func play_spin() -> void:
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


# ---------- Меши и материалы ----------

func _node(parent: Node3D, node_name: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	n.position = pos
	parent.add_child(n)
	return n


func _add(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, shadow: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Конус от root (основание радиуса r) к острому кончику tip.
func _spike(parent: Node3D, root: Vector3, tip: Vector3, r: float, col: Color) -> MeshInstance3D:
	var d := tip - root
	var mi := _add(parent, _cyl_mesh(0.0, r, d.length(), 7), (root + tip) * 0.5, _mat(col, OL_THIN), false)
	mi.basis = _basis_y(d)
	return mi


## Цилиндр (или усечённый конус) от точки a (радиус ra) до точки b (радиус rb).
func _segment(parent: Node3D, a: Vector3, b: Vector3, ra: float, rb: float, col: Color,
		ow: float = OL_THIN) -> MeshInstance3D:
	var d := b - a
	var mi := _add(parent, _cyl_mesh(rb, ra, d.length(), 7), (a + b) * 0.5, _mat(col, ow), false)
	mi.basis = _basis_y(d)
	return mi


## Поворот, переводящий ось +Y в направление dir.
static func _basis_y(dir: Vector3) -> Basis:
	var d := dir.normalized()
	if d.dot(Vector3.UP) < -0.9999:
		return Basis(Vector3.RIGHT, PI)
	return Basis(Quaternion(Vector3.UP, d))


## Toon-материал с контуром по нормалям (ow = 0 — без контура). Кэш по цвету внутри модели;
## эмиссия включена заранее (чёрная), чтобы вспышка урона не перекомпилировала шейдер.
func _mat(c: Color, ow: float = OL) -> StandardMaterial3D:
	var key := "%s|%.3f" % [c.to_html(false), ow]
	if _mats.has(key):
		return _mats[key]
	var m := Util.mat(c)
	m.emission_enabled = true
	m.emission = Color.BLACK
	if ow > 0.0 and Quality.outlines():
		m.next_pass = _outline(c, ow)
	# Хук main.gd (Util.toonify_mesh) уже не тронет: свет и контур настроены здесь
	m.set_meta("toon_done", true)
	_mats[key] = m
	_flash_mats.append(m)
	return m


## Светящийся неосвещаемый материал (навершие посоха, фонарь, камень).
func _glow(c: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.set_meta("toon_done", true)
	return m


## Материал контура: тёмный оттенок базового цвета (как Util.outline_mat), с кэшем.
static func _outline(base: Color, width: float) -> ShaderMaterial:
	var key := "%s|%.3f" % [base.to_html(false), width]
	if _outline_cache.has(key):
		return _outline_cache[key]
	if _outline_shader == null:
		_outline_shader = Shader.new()
		_outline_shader.code = OUTLINE_SHADER
	var om := ShaderMaterial.new()
	om.shader = _outline_shader
	var c := Color.from_hsv(base.h, minf(1.0, base.s * 1.2 + 0.1), base.v * 0.28)
	om.set_shader_parameter("color", c)
	om.set_shader_parameter("width", width)
	_outline_cache[key] = om
	return om


# Низкополигональные меши с общим кэшем (одинаковые детали у всех персонажей).

static func _sphere_mesh(r: float, h: float, seg: int = 12, rings: int = 6) -> SphereMesh:
	var key := "s%.4f|%.4f|%d|%d" % [r, h, seg, rings]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var m := SphereMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = seg
	m.rings = rings
	_mesh_cache[key] = m
	return m


static func _capsule_mesh(r: float, h: float) -> CapsuleMesh:
	var key := "c%.4f|%.4f" % [r, h]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 10
	m.rings = 3
	_mesh_cache[key] = m
	return m


static func _cyl_mesh(top: float, bottom: float, h: float, seg: int = 10, caps: bool = true) -> CylinderMesh:
	var key := "y%.4f|%.4f|%.4f|%d|%s" % [top, bottom, h, seg, caps]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	m.cap_top = caps
	m.cap_bottom = caps
	_mesh_cache[key] = m
	return m


static func _torus_mesh(inner: float, outer: float) -> TorusMesh:
	var key := "t%.4f|%.4f" % [inner, outer]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 16
	m.ring_segments = 6
	_mesh_cache[key] = m
	return m


static func _box_mesh(size: Vector3) -> BoxMesh:
	var key := "b%s" % size
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var m := BoxMesh.new()
	m.size = size
	_mesh_cache[key] = m
	return m


static func _prism_mesh(size: Vector3) -> PrismMesh:
	var key := "p%s" % size
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var m := PrismMesh.new()
	m.size = size
	_mesh_cache[key] = m
	return m
