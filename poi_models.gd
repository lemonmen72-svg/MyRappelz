class_name PoiModels
extends RefCounted
## Низкополигональные модели построек и декора острова (заглушки из примитивов; позже их можно
## заменить настоящими ассетами — одна функция = один тип объекта, см. get_kit()/get_mesh()).
## Модель собирается в Kit: поверхности по материалам (toon-цвет из вершин, кристаллы, ткань...).
## Свечение (окна, огни) — вершины toon-поверхности с флагом UV2.y = 1 (см. toon.gdshader),
## поэтому дом — 1–2 поверхности. IslandPois склеивает неподвижные модели зоны в общие меши
## (Kit.append_kit): на зону — пара MeshInstance3D, по вызову отрисовки на материал.
## Одинаковые модели делят Kit, меш и материалы (кэш). Оси модели: низ на y = 0, фасад (дверь) на +Z.
##
## Каналы UV у вершин (их читают шейдеры склеенных мешей):
## - "crystal_*": UV.x — высота над основанием модели (градиент), UV.y — фаза пульсации;
## - "cloth": UV.x — высота над основанием модели (покачивание);
## - "toon_ol": UV.xy и UV2.x — центр детали (контур раздувается от него);
## - "halo": UV — угол квадрата, UV2.x — размер ореола;
## - toon-поверхности: UV2.y = 1 — светящаяся вершина.
##
## Альфа цвета вершины — номер рисованной текстуры детали (WorldTextures: доски, каменная кладка,
## штукатурка, черепица, солома, скала, кора стоячего и лежачего бревна; см. toon.gdshader):
## по цвету из палитры (texture_of) или явно — Kit.tex (кора — всегда явно: цвета у брёвен те же,
## что у досок).

const TOON_SHADER := "res://toon.gdshader"
const CRYSTAL_SHADER := "res://crystal.gdshader"

## Ореолы склеенным мешем: каждый ореол — четыре вершины в центре, вершинный шейдер разворачивает
## их к камере (UV — угол квадрата, UV2.x — размер, цвет — в вершинах). Аддитивно, как Vfx.fx_mat.
const HALO_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform;

uniform sampler2D dot_tex : hint_default_white, filter_linear;

void vertex() {
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz + vec3((UV - vec2(0.5)) * UV2.x, 0.0);
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * texture(dot_tex, UV).a;
}
"""

## Контур склеенного меша (как outline.gdshader, но раздувание — от центра своей детали:
## он записан при склейке в UV.xy и UV2.x; у несклеенной модели там ноль — центр модели).
const OUTLINE_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(0.12, 0.09, 0.14, 1.0);
uniform float width = 0.02;

void vertex() {
	vec3 d = VERTEX - vec3(UV.x, UV.y, UV2.x);
	vec3 dir = length(d) > 0.0001 ? normalize(d) : NORMAL;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = length(world - CAMERA_POSITION_WORLD);
	float scale = length(MODEL_MATRIX[0].xyz);
	VERTEX += dir * width * clamp(dist / 10.0, 0.6, 3.0) / max(scale, 0.001);
}

void fragment() {
	ALBEDO = color.rgb;
}
"""

# ---------- Палитра (sRGB) ----------
const WOOD := Color(0.56, 0.38, 0.24)
const WOOD_DARK := Color(0.36, 0.24, 0.16)
const WOOD_LIGHT := Color(0.74, 0.57, 0.38)
const STONE := Color(0.7, 0.69, 0.72)
const STONE_DARK := Color(0.48, 0.47, 0.52)
const PLASTER := Color(0.97, 0.92, 0.8)
const ROOF_ORANGE := Color(0.95, 0.52, 0.22)
const ROOF_RED := Color(0.8, 0.27, 0.21)
const THATCH := Color(0.9, 0.74, 0.4)
const THATCH_DARK := Color(0.74, 0.56, 0.28)
const ELF_WHITE := Color(0.98, 0.97, 0.94)
const ELF_ROOF := Color(0.9, 0.94, 1.0)
const ELF_STONE := Color(0.84, 0.86, 0.88)
const GOLD := Color(1.0, 0.8, 0.34)
const DARK_STONE := Color(0.27, 0.24, 0.33)
const DARK_STONE2 := Color(0.36, 0.32, 0.44)
const DARK_ROOF := Color(0.24, 0.16, 0.34)
const DARK_TRIM := Color(0.5, 0.36, 0.62)
const WIN_WARM := Color(1.0, 0.84, 0.48)
const WIN_BLUE := Color(0.62, 0.92, 1.0)
const WIN_PURPLE := Color(0.82, 0.48, 1.0)
const CANVAS := Color(0.94, 0.89, 0.76)
const CANVAS_DARK := Color(0.76, 0.68, 0.54)
const ROCK := Color(0.6, 0.6, 0.63)
const ROCK_DARK := Color(0.44, 0.44, 0.48)
const WOOL := Color(0.97, 0.96, 0.92)
const FIRE := Color(1.0, 0.55, 0.15)
const FIRE_CORE := Color(1.0, 0.9, 0.45)
const WHITEWASH := Color(0.95, 0.92, 0.84)
const HULL := Color(0.45, 0.29, 0.18)

## Рисованная текстура по цвету палитры (детали с другими цветами — без текстуры или Kit.tex).
const TEXTURE_OF := {
	WOOD: WorldTextures.WOOD, WOOD_DARK: WorldTextures.WOOD, WOOD_LIGHT: WorldTextures.WOOD,
	HULL: WorldTextures.WOOD,
	STONE: WorldTextures.MASONRY, STONE_DARK: WorldTextures.MASONRY, ELF_STONE: WorldTextures.MASONRY,
	DARK_STONE: WorldTextures.MASONRY, DARK_STONE2: WorldTextures.MASONRY,
	PLASTER: WorldTextures.PLASTER, ELF_WHITE: WorldTextures.PLASTER, WHITEWASH: WorldTextures.PLASTER,
	ROOF_ORANGE: WorldTextures.TILES, ROOF_RED: WorldTextures.TILES, ELF_ROOF: WorldTextures.TILES,
	DARK_ROOF: WorldTextures.TILES,
	THATCH: WorldTextures.THATCH, THATCH_DARK: WorldTextures.THATCH,
	ROCK: WorldTextures.ROCK, ROCK_DARK: WorldTextures.ROCK,
}

static var _mats := {}
static var _meshes := {}
static var _prims := {}
static var _kits := {}


# ---------- Сборщик мешей ----------

## Одна поверхность меша (вершины одного материала).
class Surf:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var indices := PackedInt32Array()


## Накопитель модели: примитивы (бокс, цилиндр/конус, шар, призма) и плоские грани с цветом
## в вершинах; поверхности по ключу материала ("toon", "toon_ol", "crystal_blue", ...).
## Ключ "glow" (свечение) пишется в поверхность "toon" с флагом UV2.y = 1.
## base — текущее преобразование, применяется ко всему добавляемому.
## mats — свои материалы по ключу (иначе PoiModels.material(key)).
## tex — номер текстуры (WorldTextures.WOOD...) для добавляемых деталей; −1 — по цвету (texture_of).
class Kit:
	var surfs := {}
	var base := Transform3D.IDENTITY
	var mats := {}
	var tex := -1

	## Цвет вершины (линейный) с номером текстуры детали в альфе. Свечение, ткань, колосья
	## и кристаллы — без текстуры.
	func _vcolor(c: Color, key: String) -> Color:
		var lc := c.srgb_to_linear()
		var layer := WorldTextures.NONE
		if key != "glow" and key != "cloth" and key != "wheat" and not key.begins_with("crystal"):
			layer = tex if tex >= 0 else PoiModels.texture_of(c)
		lc.a = WorldTextures.layer_alpha(layer)
		return lc

	func surf(key: String) -> Surf:
		if not surfs.has(key):
			surfs[key] = Surf.new()
		return surfs[key]

	func is_empty() -> bool:
		for key in surfs:
			var s: Surf = surfs[key]
			if not s.verts.is_empty():
				return false
		return true

	## Каналы UV вершины p (координаты модели) для поверхности key.
	static func _uv(key: String, p: Vector3) -> Vector2:
		if key == "cloth" or key.begins_with("crystal"):
			return Vector2(p.y, 0.0)
		return Vector2.ZERO

	## Массивы примитива с преобразованием xf и цветом c (sRGB).
	func add_arrays(arr: Array, xf: Transform3D, c: Color, key: String) -> void:
		var sk := "toon" if key == "glow" else key
		var s := surf(sk)
		var full := base * xf
		var nb := full.basis.inverse().transposed()
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var lc := _vcolor(c, key)
		var uv2 := Vector2(0.0, 1.0 if key == "glow" else 0.0)
		var start := s.verts.size()
		for i in v.size():
			var p := full * v[i]
			s.verts.append(p)
			s.normals.append((nb * n[i]).normalized())
			s.colors.append(lc)
			s.uvs.append(_uv(sk, p))
			s.uv2s.append(uv2)
		var idx = arr[Mesh.ARRAY_INDEX]
		if idx == null:
			for i in v.size():
				s.indices.append(start + i)
		else:
			var ia: PackedInt32Array = idx
			for i in ia:
				s.indices.append(start + i)

	## Бокс: pos — центр, size — размеры, rot — углы Эйлера (рад).
	func box(pos: Vector3, size: Vector3, c: Color, rot: Vector3 = Vector3.ZERO, key: String = "toon") -> void:
		add_arrays(PoiModels.prim("box"), PoiModels.xf(pos, size, rot), c, key)

	## Цилиндр или конус (rt = 0): pos — центр, rb/rt — радиусы низа и верха, h — высота.
	func cyl(pos: Vector3, rb: float, rt: float, h: float, c: Color, seg: int = 8,
			rot: Vector3 = Vector3.ZERO, key: String = "toon") -> void:
		var ratio := snappedf(rt / maxf(rb, 0.001), 0.01)
		add_arrays(PoiModels.prim("cyl|%.2f|%d" % [ratio, seg]), PoiModels.xf(pos, Vector3(rb, h, rb), rot), c, key)

	## Шар (эллипсоид): radii — полуоси.
	func ball(pos: Vector3, radii: Vector3, c: Color, seg: int = 8, rings: int = 5,
			rot: Vector3 = Vector3.ZERO, key: String = "toon") -> void:
		add_arrays(PoiModels.prim("ball|%d|%d" % [seg, rings]), PoiModels.xf(pos, radii, rot), c, key)

	## Треугольная призма: ребро-конёк сверху, вдоль Z (size.x — ширина, size.y — высота, size.z — длина).
	func prism(pos: Vector3, size: Vector3, c: Color, rot: Vector3 = Vector3.ZERO, key: String = "toon") -> void:
		add_arrays(PoiModels.prim("prism"), PoiModels.xf(pos, size, rot), c, key)

	## Плоский треугольник. hint — примерное направление лица (нормаль развернётся к нему).
	func tri(a: Vector3, b: Vector3, cc: Vector3, c: Color, key: String = "toon", hint: Vector3 = Vector3.ZERO) -> void:
		var sk := "toon" if key == "glow" else key
		var s := surf(sk)
		var pa := base * a
		var pb := base * b
		var pc := base * cc
		var n := (pc - pa).cross(pb - pa).normalized()
		var h := base.basis * hint
		if h != Vector3.ZERO and n.dot(h) < 0.0:
			var tmp := pb
			pb = pc
			pc = tmp
			n = -n
		var lc := _vcolor(c, key)
		var uv2 := Vector2(0.0, 1.0 if key == "glow" else 0.0)
		var start := s.verts.size()
		for p in [pa, pb, pc]:
			var pv: Vector3 = p
			s.verts.append(pv)
			s.normals.append(n)
			s.colors.append(lc)
			s.uvs.append(_uv(sk, pv))
			s.uv2s.append(uv2)
		s.indices.append(start)
		s.indices.append(start + 1)
		s.indices.append(start + 2)

	## Плоский четырёхугольник a-b-c-d (по контуру).
	func quad(a: Vector3, b: Vector3, cc: Vector3, d: Vector3, c: Color, key: String = "toon",
			hint: Vector3 = Vector3.ZERO) -> void:
		var h := hint
		if h == Vector3.ZERO:
			h = (cc - a).cross(b - a)
		tri(a, b, cc, c, key, h)
		tri(a, cc, d, c, key, h)

	## Горизонтальный квадрат с текстурными координатами 0..1 (туман и т. п.): центр pos, размер size.
	func plane_uv(pos: Vector3, size: Vector2, c: Color, key: String) -> void:
		var s := surf(key)
		var lc := c.srgb_to_linear()
		var start := s.verts.size()
		var n := (base.basis * Vector3.UP).normalized()
		for k in 4:
			var u := float(k == 1 or k == 2)
			var v := float(k >= 2)
			s.verts.append(base * (pos + Vector3((u - 0.5) * size.x, 0.0, (v - 0.5) * size.y)))
			s.normals.append(n)
			s.colors.append(lc)
			s.uvs.append(Vector2(u, v))
			s.uv2s.append(Vector2.ZERO)
		for i in [0, 1, 2, 0, 2, 3]:
			s.indices.append(start + int(i))

	## Ореол-свечение в точке pos (поверхность "halo"): цвет c с альфой (sRGB), размер size, м.
	func halo(pos: Vector3, c: Color, size: float) -> void:
		var s := surf("halo")
		var lc := c.srgb_to_linear()
		lc.a = c.a
		var p := base * pos
		var start := s.verts.size()
		for k in 4:
			s.verts.append(p)
			s.normals.append(Vector3.UP)
			s.colors.append(lc)
			s.uvs.append(Vector2(float(k == 1 or k == 2), float(k >= 2)))
			s.uv2s.append(Vector2(size, 0.0))
		for i in [0, 1, 2, 0, 2, 3]:
			s.indices.append(start + int(i))

	## Добавляет всю модель src с преобразованием xf (склейка неподвижных объектов в один меш).
	## phase — фаза пульсации кристаллов этого объекта.
	func append_kit(src: Kit, xf: Transform3D, phase: float = 0.0) -> void:
		var full := base * xf
		var nb := full.basis.inverse().transposed()
		for key in src.surfs:
			var sk := String(key)
			var s: Surf = src.surfs[key]
			if s.verts.is_empty():
				continue
			if src.mats.has(sk) and not mats.has(sk):
				mats[sk] = src.mats[sk]
			var d := surf(sk)
			var start := d.verts.size()
			d.verts.append_array(full * s.verts)
			for nv: Vector3 in s.normals:
				d.normals.append((nb * nv).normalized())
			d.colors.append_array(s.colors)
			if sk.begins_with("crystal"):
				for uv: Vector2 in s.uvs:
					d.uvs.append(Vector2(uv.x, phase))
				d.uv2s.append_array(s.uv2s)
			elif sk == "toon_ol":
				for i in s.uvs.size():
					var uv: Vector2 = s.uvs[i]
					var u2: Vector2 = s.uv2s[i]
					var cp := full * Vector3(uv.x, uv.y, u2.x)
					d.uvs.append(Vector2(cp.x, cp.y))
					d.uv2s.append(Vector2(cp.z, u2.y))
			else:
				d.uvs.append_array(s.uvs)
				d.uv2s.append_array(s.uv2s)
			for i: int in s.indices:
				d.indices.append(start + i)

	func to_mesh() -> ArrayMesh:
		var m := ArrayMesh.new()
		for key in surfs:
			var s: Surf = surfs[key]
			if s.verts.is_empty():
				continue
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = s.verts
			arrays[Mesh.ARRAY_NORMAL] = s.normals
			arrays[Mesh.ARRAY_COLOR] = s.colors
			arrays[Mesh.ARRAY_TEX_UV] = s.uvs
			arrays[Mesh.ARRAY_TEX_UV2] = s.uv2s
			arrays[Mesh.ARRAY_INDEX] = s.indices
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var mat: Material = mats[key] if mats.has(key) else PoiModels.material(String(key))
			m.surface_set_material(m.get_surface_count() - 1, mat)
		return m


static func xf(pos: Vector3, size: Vector3, rot: Vector3 = Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(rot) * Basis.from_scale(size), pos)


## Номер рисованной текстуры для цвета палитры (WorldTextures.NONE — без текстуры).
static func texture_of(c: Color) -> int:
	return int(TEXTURE_OF.get(c, WorldTextures.NONE))


## Массивы единичного примитива (кэш): "box", "cyl|<верх/низ>|<сегменты>", "ball|<сегм>|<кольца>", "prism".
static func prim(key: String) -> Array:
	if _prims.has(key):
		return _prims[key]
	var parts := key.split("|")
	var pm: PrimitiveMesh
	match parts[0]:
		"box":
			var b := BoxMesh.new()
			b.size = Vector3.ONE
			pm = b
		"cyl":
			var cm := CylinderMesh.new()
			cm.bottom_radius = 1.0
			cm.top_radius = float(parts[1])
			cm.height = 1.0
			cm.radial_segments = int(parts[2])
			cm.rings = 1
			cm.cap_top = float(parts[1]) > 0.001
			pm = cm
		"ball":
			var sm := SphereMesh.new()
			sm.radius = 1.0
			sm.height = 2.0
			sm.radial_segments = int(parts[1])
			sm.rings = int(parts[2])
			pm = sm
		_:
			var pr := PrismMesh.new()
			pr.size = Vector3.ONE
			pr.left_to_right = 0.5
			pm = pr
	var arr := pm.get_mesh_arrays()
	_prims[key] = arr
	return arr


# ---------- Материалы ----------

## Toon-материал (toon.gdshader). vertex_color — брать цвет из вершин.
static func toon_material(c: Color, vertex_color: bool = false, tones: int = 2, rim: float = 0.2) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(TOON_SHADER)
	m.set_shader_parameter("albedo", c)
	m.set_shader_parameter("use_vertex_color", vertex_color)
	m.set_shader_parameter("tones", tones)
	m.set_shader_parameter("rim_strength", rim)
	# Рисованные текстуры по качеству (номер текстуры — в альфе цвета вершин или tex_layer)
	WorldTextures.register_toon(m)
	return m


## Материал светящихся кристаллов (crystal.gdshader).
static func crystal_material(c: Color, core: Color, edge: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(CRYSTAL_SHADER)
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("core_color", core)
	m.set_shader_parameter("edge_color", edge)
	return m


## Общие материалы по ключу поверхности Kit. Toon-материалы Kit понимают флаг свечения (UV2.y).
static func material(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m: Material
	match key:
		"toon_ol":
			# Мелкий декор и животные: toon и тонкий контур (контур — только если включён в качестве)
			var t := toon_material(Color.WHITE, true, 2, 0.25)
			t.set_shader_parameter("uv2_glow", true)
			if Quality.outlines():
				t.next_pass = outline_material()
			m = t
		"toon3":
			# Постройки с полутоном (3 тона)
			var t3 := toon_material(Color.WHITE, true, 3, 0.15)
			t3.set_shader_parameter("uv2_glow", true)
			m = t3
		"glow":
			# Свечение теперь — вершины toon-поверхности (UV2.y = 1); ключ оставлен для совместимости
			m = material("toon")
		"crystal_blue":
			m = crystal_material(Color(0.5, 0.86, 1.0), Color(0.2, 0.42, 0.85), Color(0.95, 1.0, 1.0))
		"crystal_gold":
			m = crystal_material(Color(1.0, 0.86, 0.45), Color(0.8, 0.5, 0.16), Color(1.0, 0.98, 0.85))
		"crystal_purple":
			m = crystal_material(Color(0.78, 0.42, 1.0), Color(0.3, 0.1, 0.5), Color(0.98, 0.82, 1.0))
		"wheat":
			var w := toon_material(Color.WHITE, true, 2, 0.1)
			w.set_shader_parameter("sway", 0.09)
			w.set_shader_parameter("sway_speed", 1.8)
			w.set_shader_parameter("normal_up", true)
			m = w
		"cloth":
			var cl := toon_material(Color.WHITE, true, 2, 0.15)
			cl.set_shader_parameter("sway", 0.025)
			cl.set_shader_parameter("sway_speed", 2.6)
			# Высота над основанием модели — из UV.x (у склеенного меша начало координат — центр зоны)
			cl.set_shader_parameter("sway_uv_height", true)
			cl.set_shader_parameter("uv2_glow", true)
			m = cl
		"halo":
			var hs := Shader.new()
			hs.code = HALO_SHADER_CODE
			var hm := ShaderMaterial.new()
			hm.shader = hs
			hm.set_shader_parameter("dot_tex", Vfx.tex("dot"))
			m = hm
		"fog_dark":
			m = soft_material(Color(0.58, 0.46, 0.74, 0.22), false, "dot")
		_:
			var d := toon_material(Color.WHITE, true, 2, 0.2)
			d.set_shader_parameter("uv2_glow", true)
			m = d
	_mats[key] = m
	return m


## Контур мелкого декора (второй проход "toon_ol"): цвет — тёмный оттенок дерева, как раньше.
static func outline_material() -> ShaderMaterial:
	if _mats.has("outline"):
		return _mats["outline"]
	var sh := Shader.new()
	sh.code = OUTLINE_SHADER_CODE
	var om := ShaderMaterial.new()
	om.shader = sh
	var base := Color(0.42, 0.32, 0.26)
	om.set_shader_parameter("color", Color.from_hsv(base.h, minf(1.0, base.s * 1.2 + 0.1), base.v * 0.28))
	om.set_shader_parameter("width", 0.012)
	_mats["outline"] = om
	return om


## Применяет качество к общим материалам: контур мелочей только при Quality.outlines().
## Вызывается при постройке острова; при смене качества без перестройки — из Quality.apply().
static func apply_quality() -> void:
	var t := material("toon_ol") as ShaderMaterial
	t.next_pass = outline_material() if Quality.outlines() else null


## Материал эффекта-ореола (аддитивное мягкое пятно, всегда лицом к камере).
static func halo_material(c: Color) -> StandardMaterial3D:
	var key := "halo|" + c.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := Vfx.fx_mat(c, Vfx.tex("dot"), true, BaseMaterial3D.BILLBOARD_ENABLED)
	_mats[key] = m
	return m


## Мягкий полупрозрачный материал (туман, луч маяка).
static func soft_material(c: Color, add: bool, texture: String = "") -> StandardMaterial3D:
	var key := "soft|%s|%s|%s" % [c.to_html(), add, texture]
	if _mats.has(key):
		return _mats[key]
	var t: Texture2D = null
	if texture != "":
		t = Vfx.tex(texture)
	var m := Vfx.fx_mat(c, t, add)
	_mats[key] = m
	return m


# ---------- Модели по имени (кэш) ----------

## Меш модели по имени (для отдельных, анимированных объектов: крылья мельницы, корабль, овцы, огонь).
static func get_mesh(kind: String) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var m := get_kit(kind).to_mesh()
	_meshes[kind] = m
	return m


## Модель по имени как Kit (для склейки в меш зоны: Kit.append_kit). Модели, которые зависят
## от места (ограды, причал, пещера), строятся в IslandPois на своём Kit. Kit из кэша не менять.
static func get_kit(kind: String) -> Kit:
	if _kits.has(kind):
		return _kits[kind]
	var k := Kit.new()
	match kind:
		"town_house":
			town_house(k, ROOF_ORANGE, false)
		"town_house_b":
			town_house(k, Color(0.96, 0.62, 0.26), true)
		"town_hall":
			town_hall(k)
		"light_elf_house":
			light_elf_house(k)
		"light_elf_tower":
			light_elf_tower(k)
		"dark_elf_house":
			dark_elf_house(k)
		"dark_elf_tower":
			dark_elf_tower(k)
		"dark_spire":
			dark_spire(k)
		"human_house_thatch":
			human_house(k, true)
		"human_house_red":
			human_house(k, false)
		"windmill":
			windmill_tower(k)
		"windmill_sails":
			windmill_sails(k)
		"lighthouse":
			lighthouse(k)
		"ship":
			ship(k)
		"tent_bell":
			tent_bell(k)
		"tent_ridge":
			tent_ridge(k)
		"campfire":
			campfire_base(k)
		"flame":
			flame(k)
		"crate":
			crate(k)
		"barrel":
			barrel(k)
		"dummy":
			training_dummy(k)
		"scarecrow":
			scarecrow(k)
		"well":
			well(k)
		"notice_board":
			notice_board(k)
		"lantern_town":
			lantern_town(k)
		"lantern_elf":
			lantern_elf(k)
		"brazier_dark":
			brazier_dark(k)
		"crystals_blue":
			crystal_cluster(k, "crystal_blue", 1.0, 5)
		"crystals_blue_big":
			crystal_monument(k, "crystal_blue")
		"crystals_gold":
			crystal_cluster(k, "crystal_gold", 0.8, 4)
		"crystals_purple":
			crystal_cluster(k, "crystal_purple", 1.1, 5)
		"crystals_purple_big":
			crystal_monument(k, "crystal_purple")
		"sheep_body":
			sheep_body(k)
		"sheep_head":
			sheep_head(k)
		"trough":
			trough(k)
		"hay":
			hay_bale(k)
		"bollard":
			k.tex = WorldTextures.BARK
			k.cyl(Vector3(0, 0.35, 0), 0.16, 0.14, 0.7, WOOD_DARK, 6)
			k.cyl(Vector3(0, 0.74, 0), 0.2, 0.2, 0.08, WOOD_DARK, 6)
			k.tex = -1
		"wheat_clump":
			wheat_clump(k)
		"rock":
			k.ball(Vector3.ZERO, Vector3.ONE, ROCK, 6, 4)
		"rock_dark":
			k.ball(Vector3.ZERO, Vector3.ONE, ROCK_DARK, 6, 4)
		"weapon_rack":
			weapon_rack(k)
		_:
			k.box(Vector3(0, 1, 0), Vector3(2, 2, 2), Color(0.8, 0.6, 0.4))
	_kits[kind] = k
	return k


# ---------- Части построек ----------

## Двускатная крыша с коньком вдоль X: два ската-плиты и фронтоны цвета стены.
## top — высота верха стен, w — ширина дома поперёк конька (по Z), l — длина вдоль конька,
## h — высота крыши, ov — свес, th — толщина ската.
static func gable_roof(k: Kit, top: float, w: float, l: float, h: float, ov: float, th: float,
		roof: Color, gable: Color, key: String = "toon") -> void:
	var a := atan2(h, w * 0.5)
	var sl := sqrt(h * h + w * w * 0.25) + ov
	# Скаты — черепица (или солома, если цвет соломенный), даже если цвет не из палитры
	var prev_tex := k.tex
	if prev_tex < 0:
		k.tex = WorldTextures.THATCH if texture_of(roof) == WorldTextures.THATCH else WorldTextures.TILES
	for s in [-1.0, 1.0]:
		var sd: float = s
		var u := Vector3(0.0, -sin(a), sd * cos(a))
		var ridge := Vector3(0.0, top + h + th * 0.5, 0.0)
		k.box(ridge + u * sl * 0.5, Vector3(l + ov * 2.0, th, sl), roof, Vector3(sd * a, 0.0, 0.0), key)
	k.tex = prev_tex
	# Фронтоны: призма цвета стен под скатами
	k.prism(Vector3(0.0, top + h * 0.5, 0.0), Vector3(w, h, l), gable, Vector3(0.0, PI * 0.5, 0.0), key)


## Изогнутая крыша светлых эльфов (конёк вдоль X): скаты прогнуты, свесы и концы конька приподняты.
static func curved_roof(k: Kit, top: float, w: float, l: float, h: float, ov: float, lift: float,
		roof: Color, trim: Color, gable: Color) -> void:
	var nu := 4
	var nv := 6
	var hw := w * 0.5 + ov
	var hl := l * 0.5 + ov
	for s in [-1.0, 1.0]:
		var sd: float = s
		var g: Array = []
		for i in nu + 1:
			var su := float(i) / float(nu)
			var row: Array[Vector3] = []
			for j in nv + 1:
				var t := float(j) / float(nv) * 2.0 - 1.0
				var at := absf(t)
				var y := top + h * pow(1.0 - su, 1.6) + lift * (0.45 * pow(at, 4.0) + pow(su, 3.0) * (0.45 + 0.55 * pow(at, 3.0)))
				row.append(Vector3(t * hl, y, sd * su * hw))
			g.append(row)
		for i in nu:
			var r0: Array[Vector3] = g[i]
			var r1: Array[Vector3] = g[i + 1]
			var c := trim if i == nu - 1 else roof
			for j in nv:
				k.quad(r0[j], r0[j + 1], r1[j + 1], r1[j], c, "toon", Vector3(0, 1, sd * 0.3))
	# Фронтоны под крышей (веер треугольников по профилю ската)
	for e in [-1.0, 1.0]:
		var ed: float = e
		var ex := ed * l * 0.5
		var bottom := Vector3(ex, top, 0.0)
		for s in [-1.0, 1.0]:
			var sd: float = s
			var prev := Vector3(ex, top + h * 0.98, 0.0)
			for i in range(1, 5):
				var frac := float(i) / 4.0
				var su := frac * (w * 0.5) / hw
				var p := Vector3(ex, top + h * pow(1.0 - su, 1.6) * 0.98, sd * frac * w * 0.5)
				k.tri(bottom, prev, p, gable, "toon", Vector3(ed, 0, 0))
				prev = p
			k.tri(bottom, prev, Vector3(ex, top, sd * w * 0.5), gable, "toon", Vector3(ed, 0, 0))
	# Золотые наконечники на концах конька
	for e in [-1.0, 1.0]:
		var ex2: float = e * hl
		k.cyl(Vector3(ex2, top + h + lift * 0.45 + 0.35, 0.0), 0.12, 0.0, 0.7, trim, 6)


## Окно-свечение на стене: pos — центр, normal_axis — "x" или "z" (куда смотрит стена).
static func window(k: Kit, pos: Vector3, size: Vector2, glow: Color, frame: Color, on_x: bool = false) -> void:
	var gs := Vector3(0.06, size.y, size.x) if on_x else Vector3(size.x, size.y, 0.06)
	var fs := Vector3(0.08, size.y + 0.16, size.x + 0.16) if on_x else Vector3(size.x + 0.16, size.y + 0.16, 0.08)
	var out := Vector3(signf(pos.x) * 0.02, 0, 0) if on_x else Vector3(0, 0, signf(pos.z) * 0.02)
	k.box(pos, fs, frame)
	k.box(pos + out, gs, glow, Vector3.ZERO, "glow")


# ---------- Город новичков ----------

## Дом города: каменный цоколь, светлые стены с фахверком, оранжевая черепица, труба.
static func town_house(k: Kit, roof: Color, wide: bool) -> void:
	var w := 4.4
	var l := 6.0 if wide else 5.2
	var wall := 2.9
	k.box(Vector3(0, 0.25, 0), Vector3(l + 0.4, 0.5, w + 0.4), STONE)
	k.box(Vector3(0, 0.5 + wall * 0.5, 0), Vector3(l, wall, w), PLASTER)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			k.box(Vector3(x * l * 0.5, 0.5 + wall * 0.5, z * w * 0.5), Vector3(0.26, wall, 0.26), WOOD_DARK)
	for z in [-1.0, 1.0]:
		k.box(Vector3(0, 0.5 + wall * 0.55, z * (w * 0.5 + 0.02)), Vector3(l, 0.16, 0.06), WOOD_DARK)
	# Дверь с козырьком
	k.box(Vector3(0, 1.45, w * 0.5 + 0.04), Vector3(1.1, 1.9, 0.08), WOOD_DARK)
	k.box(Vector3(0, 2.55, w * 0.5 + 0.35), Vector3(1.7, 0.1, 0.7), roof, Vector3(0.25, 0, 0))
	for x in [-1.0, 1.0]:
		window(k, Vector3(x * l * 0.3, 2.0, w * 0.5 + 0.03), Vector2(0.8, 0.7), WIN_WARM, WOOD_DARK)
		window(k, Vector3(x * l * 0.3, 2.0, -w * 0.5 - 0.03), Vector2(0.8, 0.7), WIN_WARM, WOOD_DARK)
	window(k, Vector3(l * 0.5 + 0.03, 2.0, 0), Vector2(0.8, 0.7), WIN_WARM, WOOD_DARK, true)
	gable_roof(k, 0.5 + wall, w, l, 1.9, 0.45, 0.2, roof, PLASTER)
	# Труба
	k.box(Vector3(l * 0.28, 0.5 + wall + 1.6, -0.7), Vector3(0.6, 1.6, 0.6), STONE_DARK)
	k.box(Vector3(l * 0.28, 0.5 + wall + 2.45, -0.7), Vector3(0.75, 0.12, 0.75), STONE)
	if wide:
		# Цветочные ящики под окнами
		for x in [-1.0, 1.0]:
			k.box(Vector3(x * l * 0.3, 1.5, w * 0.5 + 0.18), Vector3(0.9, 0.2, 0.25), WOOD)
			k.box(Vector3(x * l * 0.3, 1.65, w * 0.5 + 0.18), Vector3(0.8, 0.12, 0.2), Color(0.95, 0.42, 0.5))


## Главный дом города (ратуша): два этажа, крыльцо со ступенями и колоннами, башенка с колоколом.
static func town_hall(k: Kit) -> void:
	var w := 6.0
	var l := 8.6
	var wall := 4.4
	k.box(Vector3(0, 0.35, 0), Vector3(l + 0.5, 0.7, w + 0.5), STONE)
	k.box(Vector3(0, 0.7 + wall * 0.5, 0), Vector3(l, wall, w), PLASTER)
	for x in [-1.0, -0.33, 0.33, 1.0]:
		var xx: float = x
		k.box(Vector3(xx * l * 0.5, 0.7 + wall * 0.5, w * 0.5 + 0.02), Vector3(0.28, wall, 0.12), WOOD_DARK)
	for z in [-1.0, 1.0]:
		k.box(Vector3(0, 0.7 + wall * 0.5, z * (w * 0.5 + 0.03)), Vector3(l, 0.2, 0.08), WOOD_DARK)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			k.box(Vector3(x * l * 0.5, 0.7 + wall * 0.5, z * w * 0.5), Vector3(0.32, wall, 0.32), WOOD_DARK)
	# Окна двух этажей
	for x in [-0.66, 0.66]:
		var xx: float = x
		for y in [1.9, 3.9]:
			window(k, Vector3(xx * l * 0.5, y, w * 0.5 + 0.03), Vector2(0.9, 0.8), WIN_WARM, WOOD_DARK)
			window(k, Vector3(xx * l * 0.5, y, -w * 0.5 - 0.03), Vector2(0.9, 0.8), WIN_WARM, WOOD_DARK)
	window(k, Vector3(0, 3.9, w * 0.5 + 0.03), Vector2(1.0, 0.8), WIN_WARM, WOOD_DARK)
	# Двустворчатая дверь, крыльцо и ступени
	k.box(Vector3(0, 1.8, w * 0.5 + 0.05), Vector3(1.8, 2.2, 0.1), WOOD_DARK)
	k.box(Vector3(0, 0.55, w * 0.5 + 1.0), Vector3(3.6, 0.3, 2.0), STONE)
	k.box(Vector3(0, 0.3, w * 0.5 + 2.2), Vector3(3.2, 0.3, 0.6), STONE)
	k.box(Vector3(0, 0.12, w * 0.5 + 2.6), Vector3(3.0, 0.24, 0.5), STONE_DARK)
	for x in [-1.5, 1.5]:
		var xx: float = x
		k.cyl(Vector3(xx, 1.85, w * 0.5 + 1.75), 0.16, 0.16, 2.3, WOOD, 8)
	# Навес крыльца (малый фронтон, конёк вдоль Z)
	k.base = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 0, w * 0.5 + 1.0))
	gable_roof(k, 3.0, 3.6, 2.2, 1.1, 0.25, 0.16, ROOF_ORANGE, PLASTER)
	k.base = Transform3D.IDENTITY
	gable_roof(k, 0.7 + wall, w, l, 2.6, 0.55, 0.24, ROOF_ORANGE, PLASTER)
	# Башенка с колоколом на коньке
	var ty := 0.7 + wall + 2.2
	k.box(Vector3(0, ty + 0.7, 0), Vector3(1.3, 1.4, 1.3), PLASTER)
	for x in [-0.5, 0.5]:
		for z in [-0.5, 0.5]:
			k.box(Vector3(x, ty + 1.7, z), Vector3(0.16, 0.8, 0.16), WOOD_DARK)
	k.ball(Vector3(0, ty + 1.65, 0), Vector3(0.3, 0.32, 0.3), GOLD, 8, 4)
	k.cyl(Vector3(0, ty + 2.65, 0), 1.05, 0.0, 1.3, ROOF_ORANGE, 4, Vector3(0, PI * 0.25, 0))
	k.ball(Vector3(0, ty + 3.4, 0), Vector3(0.12, 0.12, 0.12), GOLD, 6, 3)


## Столбик ограды из бревна (кора, волокна вертикальны) с острой верхушкой: p — низ, h — высота.
## Цвет — свой у каждой ограды (темнее палитры), поэтому текстура задаётся явно.
static func fence_post(k: Kit, p: Vector3, h: float, c: Color) -> void:
	var prev := k.tex
	k.tex = WorldTextures.BARK
	k.box(p + Vector3(0, h * 0.5, 0), Vector3(0.18, h, 0.18), c)
	k.cyl(p + Vector3(0, h + 0.1, 0), 0.13, 0.0, 0.2, c, 4, Vector3(0, PI * 0.25, 0))
	k.tex = prev


## Две жерди ограды между низами столбиков p0 и p1 (брёвна: волокна вдоль жерди); post_h — высота
## столбиков. Возвращает поворот пролёта вокруг вертикали (для коллизии).
static func fence_rails(k: Kit, p0: Vector3, p1: Vector3, post_h: float, c: Color) -> float:
	var mid := (p0 + p1) * 0.5
	var flat := Vector2(p1.x - p0.x, p1.z - p0.z)
	var length := flat.length()
	var yaw := atan2(-flat.y, flat.x)
	var pitch := atan2(p1.y - p0.y, length)
	var prev := k.tex
	k.tex = WorldTextures.LOG
	for hy in [0.45, 0.9]:
		var yy: float = float(hy) * post_h
		k.box(mid + Vector3(0, yy, 0), Vector3(length + 0.1, 0.12, 0.08), c, Vector3(0, yaw, pitch))
	k.tex = prev
	return yaw


## Тренировочный манекен: крестовина, столб, соломенное тело с мишенью, руки-перекладина, голова.
static func training_dummy(k: Kit) -> void:
	k.box(Vector3(0, 0.08, 0), Vector3(1.0, 0.16, 0.2), WOOD_DARK, Vector3.ZERO, "toon_ol")
	k.box(Vector3(0, 0.08, 0), Vector3(0.2, 0.16, 1.0), WOOD_DARK, Vector3.ZERO, "toon_ol")
	k.tex = WorldTextures.BARK
	k.cyl(Vector3(0, 0.75, 0), 0.08, 0.08, 1.4, WOOD, 6, Vector3.ZERO, "toon_ol")
	k.tex = -1
	k.cyl(Vector3(0, 1.3, 0), 0.34, 0.3, 0.95, THATCH, 8, Vector3.ZERO, "toon_ol")
	for y in [1.0, 1.6]:
		var yy: float = y
		k.cyl(Vector3(0, yy, 0), 0.36, 0.36, 0.08, WOOD_DARK, 8, Vector3.ZERO, "toon_ol")
	k.tex = WorldTextures.LOG
	k.cyl(Vector3(0, 1.5, 0), 0.06, 0.06, 1.5, WOOD, 6, Vector3(0, 0, PI * 0.5), "toon_ol")
	k.tex = -1
	k.ball(Vector3(0, 2.0, 0), Vector3(0.24, 0.26, 0.24), Color(0.86, 0.76, 0.56), 8, 5, Vector3.ZERO, "toon_ol")
	# Мишень на груди
	k.cyl(Vector3(0, 1.32, 0.31), 0.2, 0.2, 0.03, Color(0.92, 0.3, 0.26), 10, Vector3(PI * 0.5, 0, 0), "toon_ol")
	k.cyl(Vector3(0, 1.32, 0.33), 0.1, 0.1, 0.03, Color(0.98, 0.95, 0.88), 10, Vector3(PI * 0.5, 0, 0), "toon_ol")


## Пугало в поле: манекен в шляпе.
static func scarecrow(k: Kit) -> void:
	k.tex = WorldTextures.BARK
	k.cyl(Vector3(0, 1.0, 0), 0.07, 0.07, 2.0, WOOD, 6, Vector3.ZERO, "toon_ol")
	k.tex = WorldTextures.LOG
	k.cyl(Vector3(0, 1.45, 0), 0.32, 0.26, 0.85, Color(0.42, 0.55, 0.78), 8, Vector3.ZERO, "toon_ol")
	k.cyl(Vector3(0, 1.6, 0), 0.05, 0.05, 1.7, WOOD, 6, Vector3(0, 0, PI * 0.5), "toon_ol")
	k.tex = -1
	for x in [-0.85, 0.85]:
		var xx: float = x
		k.cyl(Vector3(xx, 1.6, 0), 0.1, 0.06, 0.22, THATCH, 6, Vector3(0, 0, PI * 0.5), "toon_ol")
	k.ball(Vector3(0, 2.1, 0), Vector3(0.22, 0.24, 0.22), Color(0.88, 0.78, 0.55), 8, 5, Vector3.ZERO, "toon_ol")
	k.cyl(Vector3(0, 2.32, 0), 0.5, 0.48, 0.05, THATCH_DARK, 10, Vector3.ZERO, "toon_ol")
	k.cyl(Vector3(0, 2.45, 0), 0.22, 0.16, 0.25, THATCH_DARK, 8, Vector3.ZERO, "toon_ol")


## Колодец: каменное кольцо, вода, два столба с воротом и крышей, ведро.
static func well(k: Kit) -> void:
	k.cyl(Vector3(0, 0.42, 0), 0.95, 0.95, 0.84, STONE, 10)
	k.cyl(Vector3(0, 0.88, 0), 1.02, 1.02, 0.1, STONE_DARK, 10)
	k.cyl(Vector3(0, 0.78, 0), 0.72, 0.72, 0.04, Color(0.3, 0.58, 0.82), 10)
	for x in [-0.85, 0.85]:
		var xx: float = x
		k.box(Vector3(xx, 1.5, 0), Vector3(0.16, 1.5, 0.16), WOOD)
	k.tex = WorldTextures.LOG
	k.cyl(Vector3(0, 1.85, 0), 0.08, 0.08, 1.8, WOOD_DARK, 6, Vector3(0, 0, PI * 0.5))
	k.tex = -1
	k.cyl(Vector3(0, 1.45, 0), 0.16, 0.13, 0.26, WOOD_LIGHT, 8)
	k.box(Vector3(0, 1.67, 0), Vector3(0.02, 0.4, 0.02), CANVAS_DARK)
	gable_roof(k, 2.25, 1.5, 2.0, 0.6, 0.2, 0.1, ROOF_ORANGE, WOOD)


## Доска объявлений: два столба, доска с листками, маленький навес.
static func notice_board(k: Kit) -> void:
	for x in [-1.0, 1.0]:
		var xx: float = x
		k.box(Vector3(xx, 1.2, 0), Vector3(0.16, 2.4, 0.16), WOOD_DARK)
	k.box(Vector3(0, 1.5, 0), Vector3(2.0, 1.3, 0.12), WOOD)
	k.box(Vector3(0, 1.5, 0.01), Vector3(2.1, 0.1, 0.14), WOOD_DARK)
	var papers := [[-0.6, 1.75, 0.04, PLASTER], [-0.1, 1.55, -0.06, CANVAS], [0.45, 1.8, 0.08, Color(0.98, 0.94, 0.7)],
		[0.55, 1.3, -0.04, PLASTER], [-0.45, 1.25, 0.1, Color(0.9, 0.95, 1.0)]]
	for p in papers:
		var px: float = p[0]
		var py: float = p[1]
		var pr: float = p[2]
		var pc: Color = p[3]
		k.box(Vector3(px, py, 0.07), Vector3(0.38, 0.46, 0.02), pc, Vector3(0, 0, pr))
	gable_roof(k, 2.25, 0.6, 2.3, 0.3, 0.12, 0.08, ROOF_ORANGE, WOOD_DARK)


## Стойка с оружием (у арены).
static func weapon_rack(k: Kit) -> void:
	for x in [-0.8, 0.8]:
		var xx: float = x
		k.box(Vector3(xx, 0.6, 0), Vector3(0.12, 1.2, 0.12), WOOD_DARK, Vector3.ZERO, "toon_ol")
	k.box(Vector3(0, 1.05, 0), Vector3(1.8, 0.1, 0.12), WOOD, Vector3.ZERO, "toon_ol")
	k.box(Vector3(0, 0.35, 0), Vector3(1.8, 0.1, 0.12), WOOD, Vector3.ZERO, "toon_ol")
	for i in 4:
		var x := -0.55 + float(i) * 0.37
		k.cyl(Vector3(x, 0.8, 0.08), 0.03, 0.03, 1.3, Color(0.78, 0.8, 0.86), 4, Vector3(0, 0, 0.12), "toon_ol")


## Фонарь города и деревни людей: столб, тёплый огонёк, крыша-пирамидка.
static func lantern_town(k: Kit) -> void:
	k.box(Vector3(0, 0.15, 0), Vector3(0.5, 0.3, 0.5), STONE)
	k.tex = WorldTextures.BARK
	k.cyl(Vector3(0, 1.5, 0), 0.07, 0.07, 2.4, WOOD_DARK, 6)
	k.tex = -1
	k.box(Vector3(0, 2.72, 0), Vector3(0.44, 0.06, 0.44), WOOD_DARK)
	k.box(Vector3(0, 2.93, 0), Vector3(0.28, 0.36, 0.28), WIN_WARM, Vector3.ZERO, "glow")
	for x in [-0.16, 0.16]:
		for z in [-0.16, 0.16]:
			k.box(Vector3(x, 2.93, z), Vector3(0.05, 0.38, 0.05), WOOD_DARK)
	k.cyl(Vector3(0, 3.24, 0), 0.34, 0.02, 0.26, ROOF_ORANGE, 4, Vector3(0, PI * 0.25, 0))


## Светлый фонарь эльфов: тонкая белая колонна с золотом и светящийся шар.
static func lantern_elf(k: Kit) -> void:
	k.cyl(Vector3(0, 0.12, 0), 0.32, 0.36, 0.24, ELF_STONE, 8)
	k.cyl(Vector3(0, 1.4, 0), 0.07, 0.09, 2.4, ELF_WHITE, 8)
	k.cyl(Vector3(0, 2.62, 0), 0.22, 0.1, 0.12, GOLD, 8)
	k.ball(Vector3(0, 2.95, 0), Vector3(0.24, 0.24, 0.24), WIN_BLUE, 8, 5, Vector3.ZERO, "glow")
	k.cyl(Vector3(0, 3.28, 0), 0.08, 0.0, 0.3, GOLD, 6)
	# Золотые полукольца-«крылья» вокруг шара
	for s in [-1.0, 1.0]:
		var sd: float = s
		k.box(Vector3(sd * 0.3, 2.95, 0), Vector3(0.04, 0.5, 0.04), GOLD, Vector3(0, 0, sd * 0.35))


## Жаровня тёмных эльфов: каменный столб и фиолетовый кристалл в чаше.
static func brazier_dark(k: Kit) -> void:
	k.cyl(Vector3(0, 0.15, 0), 0.4, 0.45, 0.3, DARK_STONE, 6)
	k.cyl(Vector3(0, 1.05, 0), 0.14, 0.18, 1.6, DARK_STONE2, 6)
	k.cyl(Vector3(0, 1.95, 0), 0.38, 0.18, 0.25, DARK_STONE, 6)
	for i in 3:
		var a := TAU * float(i) / 3.0
		k.base = Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 0.25), Vector3(cos(a) * 0.08, 2.0, sin(a) * 0.08))
		_shard(k, 0.12, 0.6, "crystal_purple")
	k.base = Transform3D.IDENTITY


# ---------- Деревня светлых эльфов ----------

## Дом светлых эльфов: белые стены с золотом, светлый цоколь, изогнутая крыша, голубые окна.
static func light_elf_house(k: Kit) -> void:
	var w := 4.2
	var l := 5.2
	var wall := 3.0
	k.box(Vector3(0, 0.3, 0), Vector3(l + 0.6, 0.6, w + 0.6), ELF_STONE)
	k.box(Vector3(0, 0.6 + wall * 0.5, 0), Vector3(l, wall, w), ELF_WHITE)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			k.box(Vector3(x * l * 0.5, 0.6 + wall * 0.5, z * w * 0.5), Vector3(0.2, wall, 0.2), GOLD)
	for z in [-1.0, 1.0]:
		k.box(Vector3(0, 0.6 + wall - 0.1, z * (w * 0.5 + 0.02)), Vector3(l, 0.14, 0.06), GOLD)
	# Арка входа
	k.box(Vector3(0, 1.6, w * 0.5 + 0.05), Vector3(1.2, 2.0, 0.08), WOOD_LIGHT)
	k.cyl(Vector3(0, 2.6, w * 0.5 + 0.06), 0.62, 0.62, 0.1, GOLD, 10, Vector3(PI * 0.5, 0, 0))
	k.cyl(Vector3(0, 2.6, w * 0.5 + 0.09), 0.5, 0.5, 0.1, WIN_BLUE, 10, Vector3(PI * 0.5, 0, 0), "glow")
	for x in [-1.0, 1.0]:
		window(k, Vector3(x * l * 0.32, 2.1, w * 0.5 + 0.03), Vector2(0.6, 1.0), WIN_BLUE, GOLD)
		window(k, Vector3(x * l * 0.32, 2.1, -w * 0.5 - 0.03), Vector2(0.6, 1.0), WIN_BLUE, GOLD)
	# Крыша опущена на 0.35 м: прогнутый скат проходит над краем стены без щели
	curved_roof(k, 0.6 + wall - 0.35, w, l, 2.2, 0.7, 0.75, ELF_ROOF, GOLD, ELF_WHITE)
	# Голубой кристалл над входом
	k.base = Transform3D(Basis.IDENTITY, Vector3(0, 0.6 + wall + 1.95, 0))
	_shard(k, 0.18, 0.9, "crystal_blue")
	k.base = Transform3D.IDENTITY


## Круглая башенка-дом эльфов: белый барабан, золотые пояса, изогнутый конус крыши.
static func light_elf_tower(k: Kit) -> void:
	k.cyl(Vector3(0, 0.3, 0), 3.0, 3.1, 0.6, ELF_STONE, 10)
	k.cyl(Vector3(0, 2.6, 0), 2.4, 2.3, 4.0, ELF_WHITE, 10)
	for y in [1.4, 4.4]:
		var yy: float = y
		k.cyl(Vector3(0, yy, 0), 2.46, 2.46, 0.16, GOLD, 10)
	k.box(Vector3(0, 1.7, 2.3), Vector3(1.1, 2.0, 0.2), WOOD_LIGHT)
	for i in 4:
		var a := PI * 0.25 + float(i) * PI * 0.5
		k.base = Transform3D(Basis(Vector3.UP, -a + PI * 0.5), Vector3.ZERO)
		window(k, Vector3(0, 3.2, 2.36), Vector2(0.5, 1.0), WIN_BLUE, GOLD)
		k.base = Transform3D.IDENTITY
	# Крыша: широкий низ-«юбка» с золотым краем и вытянутый вогнутый конус
	k.cyl(Vector3(0, 4.85, 0), 3.2, 2.6, 0.4, GOLD, 10)
	k.cyl(Vector3(0, 5.5, 0), 2.6, 1.3, 0.9, ELF_ROOF, 10)
	k.cyl(Vector3(0, 6.65, 0), 1.3, 0.45, 1.4, ELF_ROOF, 10)
	k.cyl(Vector3(0, 7.95, 0), 0.45, 0.0, 1.2, ELF_ROOF, 10)
	k.base = Transform3D(Basis.IDENTITY, Vector3(0, 8.4, 0))
	_shard(k, 0.22, 1.1, "crystal_gold")
	k.base = Transform3D.IDENTITY


# ---------- Деревня тёмных эльфов ----------

## Дом тёмных эльфов: тёмный камень, контрфорсы со шпилями, крутая крыша, фиолетовые окна.
static func dark_elf_house(k: Kit) -> void:
	var w := 4.2
	var l := 5.4
	var wall := 3.4
	k.box(Vector3(0, 0.3, 0), Vector3(l + 0.6, 0.6, w + 0.6), DARK_STONE)
	k.box(Vector3(0, 0.6 + wall * 0.5, 0), Vector3(l, wall, w), DARK_STONE2)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			var p := Vector3(x * (l * 0.5 + 0.05), 0, z * (w * 0.5 + 0.05))
			k.box(p + Vector3(0, 2.4, 0), Vector3(0.5, 4.8, 0.5), DARK_STONE)
			k.cyl(p + Vector3(0, 5.6, 0), 0.32, 0.0, 1.6, DARK_TRIM, 4, Vector3(0, PI * 0.25, 0))
	k.box(Vector3(0, 1.7, w * 0.5 + 0.05), Vector3(1.1, 2.2, 0.1), Color(0.18, 0.12, 0.2))
	k.cyl(Vector3(0, 3.1, w * 0.5 + 0.06), 0.4, 0.0, 0.8, DARK_TRIM, 4, Vector3(PI * 0.5, PI * 0.25, 0))
	for x in [-1.0, 1.0]:
		window(k, Vector3(x * l * 0.3, 2.3, w * 0.5 + 0.03), Vector2(0.4, 1.2), WIN_PURPLE, DARK_STONE)
		window(k, Vector3(x * l * 0.3, 2.3, -w * 0.5 - 0.03), Vector2(0.4, 1.2), WIN_PURPLE, DARK_STONE)
	gable_roof(k, 0.6 + wall, w, l, 3.2, 0.35, 0.2, DARK_ROOF, DARK_STONE2)
	# Шпили на концах конька
	for x in [-1.0, 1.0]:
		k.cyl(Vector3(x * l * 0.5, 0.6 + wall + 4.0, 0), 0.18, 0.0, 2.2, DARK_TRIM, 4)
		k.ball(Vector3(x * l * 0.5, 0.6 + wall + 3.0, 0), Vector3(0.14, 0.14, 0.14), WIN_PURPLE, 6, 3, Vector3.ZERO, "glow")


## Башня тёмных эльфов (главное здание деревни): восьмигранник, острый шпиль и малые шпили.
static func dark_elf_tower(k: Kit) -> void:
	k.cyl(Vector3(0, 0.4, 0), 3.3, 3.5, 0.8, DARK_STONE, 8)
	k.cyl(Vector3(0, 4.8, 0), 2.6, 2.3, 8.0, DARK_STONE2, 8)
	for y in [3.0, 6.4, 8.8]:
		var yy: float = y
		k.cyl(Vector3(0, yy, 0), 2.7 - yy * 0.03, 2.7 - yy * 0.03, 0.22, DARK_STONE, 8)
	k.box(Vector3(0, 1.9, 2.45), Vector3(1.4, 2.6, 0.3), Color(0.18, 0.12, 0.2))
	k.cyl(Vector3(0, 3.6, 2.5), 0.6, 0.0, 1.0, DARK_TRIM, 4, Vector3(PI * 0.5, PI * 0.25, 0))
	for i in 8:
		var a := float(i) * TAU / 8.0
		k.base = Transform3D(Basis(Vector3.UP, a), Vector3.ZERO)
		if i % 2 == 1:
			window(k, Vector3(0, 5.0, 2.48), Vector2(0.4, 1.3), WIN_PURPLE, DARK_STONE)
		window(k, Vector3(0, 7.6, 2.38), Vector2(0.3, 0.8), WIN_PURPLE, DARK_STONE)
		# Зубцы и малые шпили по кругу
		k.cyl(Vector3(0, 9.3, 2.45), 0.22, 0.0, 1.4 if i % 2 == 0 else 0.8, DARK_TRIM, 4)
		k.base = Transform3D.IDENTITY
	k.cyl(Vector3(0, 9.1, 0), 2.6, 2.6, 0.3, DARK_STONE, 8)
	k.cyl(Vector3(0, 12.3, 0), 2.1, 0.0, 6.2, DARK_ROOF, 8)
	k.cyl(Vector3(0, 16.2, 0), 0.12, 0.0, 2.0, DARK_TRIM, 4)
	k.ball(Vector3(0, 15.3, 0), Vector3(0.28, 0.4, 0.28), WIN_PURPLE, 6, 3, Vector3.ZERO, "glow")


## Отдельный острый шпиль-обелиск с рунами.
static func dark_spire(k: Kit) -> void:
	k.cyl(Vector3(0, 0.3, 0), 0.9, 1.0, 0.6, DARK_STONE, 4, Vector3(0, PI * 0.25, 0))
	k.cyl(Vector3(0, 2.6, 0), 0.45, 0.2, 4.0, DARK_STONE2, 4, Vector3(0, PI * 0.25, 0))
	k.cyl(Vector3(0, 5.3, 0), 0.2, 0.0, 1.4, DARK_TRIM, 4, Vector3(0, PI * 0.25, 0))
	for y in [1.4, 2.4, 3.4]:
		var yy: float = y
		k.box(Vector3(0, yy, 0.38 - yy * 0.045), Vector3(0.14, 0.4, 0.04), WIN_PURPLE, Vector3.ZERO, "glow")


# ---------- Деревня людей ----------

## Дом людей: фахверк (светлые стены, тёмные балки и раскосы), соломенная или красная крыша, труба.
static func human_house(k: Kit, thatch: bool) -> void:
	var w := 4.4
	var l := 5.6
	var wall := 2.8
	k.box(Vector3(0, 0.25, 0), Vector3(l + 0.3, 0.5, w + 0.3), STONE_DARK)
	k.box(Vector3(0, 0.5 + wall * 0.5, 0), Vector3(l, wall, w), PLASTER)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			k.box(Vector3(x * l * 0.5, 0.5 + wall * 0.5, z * w * 0.5), Vector3(0.24, wall, 0.24), WOOD_DARK)
	for z in [-1.0, 1.0]:
		var zz: float = z * (w * 0.5 + 0.02)
		k.box(Vector3(0, 0.5 + wall * 0.5, zz), Vector3(l, 0.14, 0.06), WOOD_DARK)
		k.box(Vector3(0, 0.5 + wall - 0.07, zz), Vector3(l, 0.14, 0.06), WOOD_DARK)
		# Раскосы
		for x in [-1.0, 1.0]:
			k.box(Vector3(x * l * 0.36, 0.5 + wall * 0.25, zz), Vector3(0.12, 1.6, 0.05), WOOD_DARK, Vector3(0, 0, x * 0.6))
	k.box(Vector3(0, 1.4, w * 0.5 + 0.05), Vector3(1.0, 1.8, 0.08), WOOD)
	for x in [-1.0, 1.0]:
		window(k, Vector3(x * l * 0.3, 2.35, w * 0.5 + 0.04), Vector2(0.7, 0.55), WIN_WARM, WOOD_DARK)
	window(k, Vector3(l * 0.5 + 0.04, 1.9, 0), Vector2(0.7, 0.6), WIN_WARM, WOOD_DARK, true)
	if thatch:
		gable_roof(k, 0.5 + wall, w, l, 2.2, 0.6, 0.45, THATCH, PLASTER)
		# Валик-конёк соломы
		k.cyl(Vector3(0, 0.5 + wall + 2.45, 0), 0.28, 0.28, l + 1.0, THATCH_DARK, 6, Vector3(0, 0, PI * 0.5))
	else:
		gable_roof(k, 0.5 + wall, w, l, 2.0, 0.45, 0.2, ROOF_RED, PLASTER)
	k.box(Vector3(-l * 0.3, 0.5 + wall + 1.7, 0.8), Vector3(0.55, 1.7, 0.55), STONE)
	# Бочка у входа
	k.cyl(Vector3(l * 0.35, 0.45, w * 0.5 + 0.6), 0.32, 0.32, 0.9, WOOD, 8)


## Башня мельницы: беленая коническая башня, деревянные пояса, дверь, красная шапка.
## Ступица крыльев — на (0, 7.4, 2.0); крылья — отдельный меш "windmill_sails".
static func windmill_tower(k: Kit) -> void:
	k.cyl(Vector3(0, 0.3, 0), 2.7, 2.8, 0.6, STONE_DARK, 8)
	k.cyl(Vector3(0, 3.9, 0), 2.3, 1.65, 6.6, WHITEWASH, 8)
	for y in [2.4, 5.0]:
		var yy: float = y
		var r := lerpf(2.3, 1.65, (yy - 0.6) / 6.6) + 0.05
		k.cyl(Vector3(0, yy, 0), r, r, 0.18, WOOD_DARK, 8)
	k.box(Vector3(0, 1.5, 2.18), Vector3(1.1, 1.8, 0.2), WOOD_DARK)
	window(k, Vector3(0, 4.2, 1.95), Vector2(0.6, 0.7), WIN_WARM, WOOD_DARK)
	k.cyl(Vector3(0, 7.3, 0), 1.85, 1.85, 0.2, WOOD_DARK, 8)
	k.cyl(Vector3(0, 8.6, 0), 1.95, 0.15, 2.5, ROOF_RED, 8)
	k.box(Vector3(0, 7.4, 1.6), Vector3(0.7, 0.7, 1.0), WOOD_DARK)
	k.cyl(Vector3(0, 7.4, 2.0), 0.22, 0.22, 0.6, WOOD, 6, Vector3(PI * 0.5, 0, 0))


## Крылья мельницы: ступица в начале координат, плоскость крыльев XY, ось вращения Z.
static func windmill_sails(k: Kit) -> void:
	k.cyl(Vector3.ZERO, 0.32, 0.32, 0.35, WOOD_DARK, 8, Vector3(PI * 0.5, 0, 0))
	for i in 4:
		k.base = Transform3D(Basis(Vector3.BACK, float(i) * PI * 0.5), Vector3.ZERO)
		k.box(Vector3(0, 2.3, 0.1), Vector3(0.16, 4.6, 0.12), WOOD_DARK)
		k.box(Vector3(0.55, 2.75, 0.12), Vector3(0.95, 3.3, 0.04), CANVAS)
		for y in [1.4, 2.5, 3.6]:
			var yy: float = y
			k.box(Vector3(0.55, yy, 0.16), Vector3(1.05, 0.07, 0.05), WOOD)
	k.base = Transform3D.IDENTITY


## Овца: шерстяное тело, ножки (без головы — она отдельно, чтобы «пастись»).
static func sheep_body(k: Kit) -> void:
	k.ball(Vector3(0, 0.62, 0), Vector3(0.42, 0.36, 0.58), WOOL, 8, 5, Vector3.ZERO, "toon_ol")
	k.ball(Vector3(0, 0.82, 0.05), Vector3(0.34, 0.24, 0.45), WOOL, 8, 4, Vector3.ZERO, "toon_ol")
	for x in [-0.2, 0.2]:
		for z in [-0.3, 0.3]:
			k.cyl(Vector3(x, 0.18, z), 0.06, 0.06, 0.36, Color(0.25, 0.22, 0.24), 5, Vector3.ZERO, "toon_ol")


## Голова овцы: ось шеи в начале координат, морда к -Z.
static func sheep_head(k: Kit) -> void:
	k.ball(Vector3(0, 0.0, -0.2), Vector3(0.17, 0.19, 0.24), Color(0.3, 0.26, 0.28), 8, 5, Vector3.ZERO, "toon_ol")
	k.ball(Vector3(0, 0.12, -0.12), Vector3(0.18, 0.12, 0.16), WOOL, 6, 4, Vector3.ZERO, "toon_ol")
	for s in [-1.0, 1.0]:
		var sd: float = s
		k.box(Vector3(sd * 0.2, 0.05, -0.12), Vector3(0.16, 0.05, 0.08), Color(0.3, 0.26, 0.28), Vector3(0, 0, sd * -0.4), "toon_ol")


static func trough(k: Kit) -> void:
	k.box(Vector3(0, 0.3, 0), Vector3(1.6, 0.45, 0.6), WOOD, Vector3.ZERO, "toon_ol")
	k.box(Vector3(0, 0.5, 0), Vector3(1.4, 0.06, 0.42), Color(0.55, 0.72, 0.36))
	for x in [-0.65, 0.65]:
		var xx: float = x
		k.box(Vector3(xx, 0.08, 0), Vector3(0.12, 0.16, 0.7), WOOD_DARK)


static func hay_bale(k: Kit) -> void:
	k.cyl(Vector3(0, 0.55, 0), 0.55, 0.55, 1.0, THATCH, 8, Vector3(0, 0, PI * 0.5), "toon_ol")
	for x in [-0.3, 0.3]:
		var xx: float = x
		k.cyl(Vector3(xx, 0.55, 0), 0.57, 0.57, 0.06, THATCH_DARK, 8, Vector3(0, 0, PI * 0.5), "toon_ol")


## Пучок колосьев (для MultiMesh поля): 4 стебля — тонкая полоска и колос пошире.
static func wheat_clump(k: Kit) -> void:
	var stem := Color(0.66, 0.68, 0.3)
	var ear := Color(0.98, 0.8, 0.35)
	var ear_tip := Color(1.0, 0.9, 0.55)
	var spots := [[0.0, 0.0, 0.0, 1.0], [0.16, 0.07, 1.1, 0.9], [-0.1, 0.14, 2.2, 1.08], [0.05, -0.15, 0.6, 0.95]]
	for sp in spots:
		var x: float = sp[0]
		var z: float = sp[1]
		var a: float = sp[2]
		var h: float = sp[3]
		var b := Basis(Vector3.UP, a)
		var o := Vector3(x, 0, z)
		var r := b * Vector3(1, 0, 0)
		var lean := b * Vector3(0, 0, 0.08)
		var hs := 0.62 * h
		var he := 0.98 * h
		k.quad(o - r * 0.02, o + r * 0.02, o + r * 0.018 + Vector3(0, hs, 0) + lean, o - r * 0.018 + Vector3(0, hs, 0) + lean,
			stem, "wheat")
		var top := o + Vector3(0, he, 0) + lean * 1.4
		var mid := o + Vector3(0, hs, 0) + lean
		k.quad(mid - r * 0.05, mid + r * 0.05, top + r * 0.02, top - r * 0.02, ear, "wheat")
		k.tri(top - r * 0.02, top + r * 0.02, top + Vector3(0, 0.08, 0), ear_tip, "wheat")


# ---------- Порт ----------

## Маяк: белая башня с красными поясами, галерея с перилами, светящийся фонарь, красный купол.
static func lighthouse(k: Kit) -> void:
	k.cyl(Vector3(0, 0.4, 0), 2.5, 2.6, 0.8, STONE_DARK, 10)
	var bands := 5
	var h := 11.0
	for i in bands:
		var y0 := 0.8 + h * float(i) / float(bands)
		var y1 := 0.8 + h * float(i + 1) / float(bands)
		var r0 := lerpf(2.1, 1.35, float(i) / float(bands))
		var r1 := lerpf(2.1, 1.35, float(i + 1) / float(bands))
		var c := Color(0.97, 0.96, 0.93) if i % 2 == 0 else ROOF_RED
		k.tex = WorldTextures.PLASTER
		k.cyl(Vector3(0, (y0 + y1) * 0.5, 0), r0, r1, y1 - y0, c, 10)
		k.tex = -1
	k.box(Vector3(0, 1.8, 2.05), Vector3(1.0, 2.0, 0.2), WOOD_DARK)
	for y in [4.5, 8.0]:
		var yy: float = y
		var r := lerpf(2.1, 1.35, (yy - 0.8) / h) + 0.02
		window(k, Vector3(0, yy, r), Vector2(0.45, 0.7), WIN_WARM, WOOD_DARK)
	var top := 0.8 + h
	k.cyl(Vector3(0, top + 0.12, 0), 2.0, 2.0, 0.24, STONE_DARK, 10)
	for i in 10:
		var a := TAU * float(i) / 10.0
		k.box(Vector3(cos(a) * 1.85, top + 0.6, sin(a) * 1.85), Vector3(0.08, 0.75, 0.08), WOOD_DARK)
		var a2 := a + TAU / 20.0
		k.box(Vector3(cos(a2) * 1.82, top + 0.95, sin(a2) * 1.82), Vector3(0.06, 0.07, 1.16), WOOD_DARK, Vector3(0, -a2, 0))
	k.cyl(Vector3(0, top + 0.95, 0), 1.0, 1.0, 1.4, WIN_WARM, 10, Vector3.ZERO, "glow")
	for i in 6:
		var a := TAU * float(i) / 6.0
		k.box(Vector3(cos(a) * 1.02, top + 0.95, sin(a) * 1.02), Vector3(0.1, 1.45, 0.1), WOOD_DARK)
	k.cyl(Vector3(0, top + 1.75, 0), 1.25, 1.25, 0.2, ROOF_RED, 10)
	k.cyl(Vector3(0, top + 2.45, 0), 1.25, 0.1, 1.2, ROOF_RED, 10)
	k.ball(Vector3(0, top + 3.15, 0), Vector3(0.2, 0.2, 0.2), GOLD, 6, 3)


## Корабль: корпус с носом-клином, палуба, кормовая надстройка, мачта с двумя парусами.
## Ватерлиния — y = 0, нос смотрит на -Z.
static func ship(k: Kit) -> void:
	var hull := HULL
	k.box(Vector3(0, -0.2, 0.2), Vector3(2.8, 1.6, 6.6), hull)
	k.box(Vector3(0, -0.85, 0.2), Vector3(2.2, 0.5, 6.2), WOOD_DARK)
	k.prism(Vector3(0, -0.2, -4.0), Vector3(2.8, 2.2, 1.6), hull, Vector3(-PI * 0.5, 0, 0))
	k.box(Vector3(0, 0.42, 0.2), Vector3(3.0, 0.14, 6.8), Color(0.98, 0.84, 0.42))
	k.box(Vector3(0, 0.62, -0.3), Vector3(2.5, 0.1, 7.4), WOOD_LIGHT)
	for s in [-1.0, 1.0]:
		var sd: float = s
		k.box(Vector3(sd * 1.35, 0.95, 0.0), Vector3(0.12, 0.6, 6.2), WOOD)
	k.box(Vector3(0, 1.3, 2.6), Vector3(2.8, 1.3, 2.0), WOOD)
	k.box(Vector3(0, 2.0, 2.6), Vector3(3.0, 0.12, 2.2), WOOD_DARK)
	for x in [-0.7, 0.7]:
		var xx: float = x
		window(k, Vector3(xx, 1.35, 3.63), Vector2(0.45, 0.4), WIN_WARM, WOOD_DARK)
	k.cyl(Vector3(0, 4.6, -0.4), 0.14, 0.11, 8.0, WOOD_DARK, 6)
	k.cyl(Vector3(0, 0.95, -4.8), 0.08, 0.05, 2.6, WOOD_DARK, 6, Vector3(-1.1, 0, 0))
	for y in [3.0, 6.2]:
		var yy: float = y
		k.cyl(Vector3(0, yy, -0.25), 0.07, 0.07, 3.4 if yy < 4.0 else 2.6, WOOD_DARK, 6, Vector3(0, 0, PI * 0.5))
	k.box(Vector3(0, 4.55, -0.3), Vector3(3.2, 2.9, 0.08), CANVAS, Vector3(-0.06, 0, 0), "cloth")
	k.box(Vector3(0, 7.15, -0.3), Vector3(2.4, 1.7, 0.08), CANVAS, Vector3(-0.06, 0, 0), "cloth")
	k.box(Vector3(0, 4.55, -0.26), Vector3(3.22, 0.4, 0.08), ROOF_RED, Vector3(-0.06, 0, 0), "cloth")
	k.box(Vector3(0.4, 8.75, -0.4), Vector3(0.8, 0.4, 0.04), ROOF_RED, Vector3.ZERO, "cloth")


static func crate(k: Kit) -> void:
	k.box(Vector3(0, 0.4, 0), Vector3(0.8, 0.8, 0.8), WOOD_LIGHT, Vector3.ZERO, "toon_ol")
	for y in [0.08, 0.72]:
		var yy: float = y
		k.box(Vector3(0, yy, 0), Vector3(0.84, 0.12, 0.84), WOOD, Vector3.ZERO, "toon_ol")
	k.box(Vector3(0, 0.4, 0.41), Vector3(0.12, 0.8, 0.04), WOOD, Vector3(0, 0, 0.78), "toon_ol")


static func barrel(k: Kit) -> void:
	k.cyl(Vector3(0, 0.45, 0), 0.34, 0.34, 0.9, WOOD, 8, Vector3.ZERO, "toon_ol")
	k.tex = WorldTextures.NONE
	for y in [0.15, 0.75]:
		var yy: float = y
		k.cyl(Vector3(0, yy, 0), 0.36, 0.36, 0.08, STONE_DARK, 8, Vector3.ZERO, "toon_ol")
	k.tex = -1


# ---------- Лагеря ----------

## Шатёр-колокол: брезентовый конус, юбка, тёмный вход, шест с вымпелом.
static func tent_bell(k: Kit) -> void:
	k.cyl(Vector3(0, 0.25, 0), 1.9, 1.85, 0.5, CANVAS_DARK, 8)
	k.cyl(Vector3(0, 1.75, 0), 1.85, 0.1, 2.5, CANVAS, 8)
	k.quad(Vector3(-0.45, 0.02, 1.86), Vector3(0.45, 0.02, 1.86), Vector3(0.12, 1.5, 1.05), Vector3(-0.12, 1.5, 1.05),
		Color(0.32, 0.24, 0.2), "toon", Vector3(0, 0.4, 1))
	k.tex = WorldTextures.BARK
	k.cyl(Vector3(0, 3.2, 0), 0.04, 0.04, 0.9, WOOD_DARK, 5)
	k.tex = -1
	k.box(Vector3(0.25, 3.45, 0), Vector3(0.5, 0.26, 0.03), ROOF_RED, Vector3.ZERO, "cloth")
	for i in 4:
		var a := PI * 0.25 + float(i) * PI * 0.5
		k.box(Vector3(cos(a) * 2.2, 0.15, sin(a) * 2.2), Vector3(0.08, 0.3, 0.08), WOOD_DARK)


## Палатка-домик (двускатная): брезент на коньке, торцы, колышки.
static func tent_ridge(k: Kit) -> void:
	var h := 1.8
	var w := 2.6
	var l := 3.0
	var a := atan2(h, w * 0.5)
	var sl := sqrt(h * h + w * w * 0.25) + 0.1
	k.base = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO)
	for s in [-1.0, 1.0]:
		var sd: float = s
		var u := Vector3(0.0, -sin(a), sd * cos(a))
		k.box(Vector3(0, h, 0) + u * sl * 0.5, Vector3(l, 0.06, sl), CANVAS, Vector3(sd * a, 0, 0))
	k.base = Transform3D.IDENTITY
	for e in [-1.0, 1.0]:
		var ez: float = e * l * 0.5
		k.tri(Vector3(-w * 0.5, 0.02, ez), Vector3(w * 0.5, 0.02, ez), Vector3(0, h - 0.05, ez),
			CANVAS_DARK if e > 0.0 else CANVAS, "toon", Vector3(0, 0, e))
	k.tri(Vector3(-0.4, 0.03, l * 0.5 + 0.02), Vector3(0.4, 0.03, l * 0.5 + 0.02), Vector3(0, 1.2, l * 0.5 + 0.02),
		Color(0.32, 0.24, 0.2), "toon", Vector3(0, 0, 1))
	for e in [-1.0, 1.0]:
		var ez2: float = e * (l * 0.5 + 0.1)
		k.tex = WorldTextures.BARK
		k.cyl(Vector3(0, h * 0.5 + 0.1, ez2), 0.04, 0.04, h + 0.2, WOOD_DARK, 5)
		k.tex = -1


## Кострище: кольцо камней и сложенные шалашом поленья (огонь — отдельный меш "flame").
static func campfire_base(k: Kit) -> void:
	for i in 8:
		var a := TAU * float(i) / 8.0
		k.ball(Vector3(cos(a) * 0.62, 0.1, sin(a) * 0.62), Vector3(0.18, 0.14, 0.16), ROCK, 6, 3, Vector3(0, a, 0))
	# Поленья шалашом: каждое наклонено верхушкой к центру
	for i in 4:
		var a := float(i) * PI * 0.5 + 0.3
		var tangent := Vector3(-sin(a), 0.0, cos(a))
		k.base = Transform3D(Basis(tangent, 0.45), Vector3(cos(a) * 0.25, 0.3, sin(a) * 0.25))
		k.tex = WorldTextures.BARK
		k.cyl(Vector3.ZERO, 0.07, 0.06, 0.75, WOOD_DARK, 5)
		k.tex = -1
	k.base = Transform3D.IDENTITY
	# Брёвна-скамейки по касательной
	for i in 2:
		var a := float(i) * PI + 0.6
		k.tex = WorldTextures.LOG
		k.cyl(Vector3(cos(a) * 1.6, 0.18, sin(a) * 1.6), 0.18, 0.18, 1.3, WOOD, 6, Vector3(0, PI * 0.5 - a, PI * 0.5))
		k.tex = -1


## Пламя: два вложенных светящихся конуса (наружный оранжевый, внутренний жёлтый).
static func flame(k: Kit) -> void:
	k.cyl(Vector3(0, 0.45, 0), 0.32, 0.0, 0.9, FIRE, 6, Vector3.ZERO, "glow")
	k.cyl(Vector3(0, 0.38, 0), 0.18, 0.0, 0.65, FIRE_CORE, 6, Vector3(0, 0.5, 0), "glow")


# ---------- Кристаллы ----------

## Один кристалл: шестигранная призма с острой верхушкой (плоские грани), растёт вверх из base.
static func _shard(k: Kit, r: float, h: float, key: String) -> void:
	var n := 6
	var hb := h * 0.72
	var ring0: Array[Vector3] = []
	var ring1: Array[Vector3] = []
	for i in n:
		var a := TAU * float(i) / float(n)
		ring0.append(Vector3(cos(a) * r * 0.8, -r * 0.5, sin(a) * r * 0.8))
		ring1.append(Vector3(cos(a) * r, hb, sin(a) * r))
	var tip := Vector3(0, h, 0)
	var white := Color.WHITE
	for i in n:
		var j := (i + 1) % n
		var a := TAU * (float(i) + 0.5) / float(n)
		var out := Vector3(cos(a), 0.0, sin(a))
		k.quad(ring0[i], ring0[j], ring1[j], ring1[i], white, key, out)
		k.tri(ring1[i], ring1[j], tip, white, key, out + Vector3(0, 0.6, 0))


## Друза кристаллов на камне: count кристаллов, наклонённых наружу; s — общий масштаб.
static func crystal_cluster(k: Kit, key: String, s: float, count: int) -> void:
	k.ball(Vector3(0, 0.1 * s, 0), Vector3(0.9, 0.4, 0.8) * s, ROCK_DARK, 7, 4)
	var sizes := [[0.0, 0.0, 0.0, 0.28, 1.9], [0.5, 0.0, 0.55, 0.2, 1.2], [-0.45, 0.2, 0.6, 0.18, 1.0],
		[0.1, -0.5, 0.5, 0.16, 0.8], [-0.2, 0.45, 0.7, 0.14, 0.7], [0.45, 0.4, 0.5, 0.12, 0.6]]
	for i in mini(count, sizes.size()):
		var e: Array = sizes[i]
		var x: float = e[0]
		var z: float = e[1]
		var tilt: float = e[2]
		var r: float = e[3]
		var h: float = e[4]
		var dir := atan2(z, x) if (absf(x) + absf(z)) > 0.01 else 0.0
		var b := Basis(Vector3.UP, -dir) * Basis(Vector3.BACK, -tilt)
		k.base = Transform3D(b * Basis.from_scale(Vector3(s, s, s)), Vector3(x * s, 0.25 * s, z * s))
		_shard(k, r, h, key)
	k.base = Transform3D.IDENTITY


## Большой кристалл-монумент на постаменте (центр деревни эльфов).
static func crystal_monument(k: Kit, key: String) -> void:
	var dark := key == "crystal_purple"
	var stone := DARK_STONE if dark else ELF_STONE
	var trim := DARK_TRIM if dark else GOLD
	k.cyl(Vector3(0, 0.25, 0), 1.9, 2.0, 0.5, stone, 8)
	k.cyl(Vector3(0, 0.7, 0), 1.4, 1.6, 0.4, stone, 8)
	k.cyl(Vector3(0, 0.95, 0), 1.45, 1.45, 0.1, trim, 8)
	k.base = Transform3D(Basis.IDENTITY, Vector3(0, 0.9, 0))
	_shard(k, 0.55, 3.6, key)
	for i in 4:
		var a := float(i) * PI * 0.5 + 0.4
		k.base = Transform3D(Basis(Vector3.UP, -a) * Basis(Vector3.BACK, -0.45), Vector3(cos(a) * 0.6, 0.9, sin(a) * 0.6))
		_shard(k, 0.25, 1.6, key)
	k.base = Transform3D.IDENTITY
	# Четыре столбика с золотыми/фиолетовыми навершиями вокруг
	for i in 4:
		var a := float(i) * PI * 0.5 + PI * 0.25
		var p := Vector3(cos(a) * 1.75, 0, sin(a) * 1.75)
		k.box(p + Vector3(0, 0.9, 0), Vector3(0.22, 1.3, 0.22), stone)
		k.ball(p + Vector3(0, 1.65, 0), Vector3(0.16, 0.16, 0.16), trim, 6, 3)
