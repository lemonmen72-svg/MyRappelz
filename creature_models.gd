class_name CreatureModels
extends RefCounted
## Модели зверей и питомцев в аниме-стиле (чиби): округлые формы из сфер и капсул, большие глаза
## с бликами, румянец, характерные детали вида. Всё своё, из примитивов.
## Пантера, черепаха, фазан, волк, летающие рыбы и анатемы — модели из файлов (CreatureAsset, assets/creatures/<id>.glb): build() берёт
## файл, если он есть, иначе строит их запасную модель из примитивов (размеры — CreatureAsset.info_for).
## Для модели из файла: asset_of(корень) — узел CreatureAsset (анимации вызывают Mob и Pet).
## build() строит только меши в отдельном узле, коллизию добавляет add_collision().
## Передом модель смотрит в -Z. Части для анимации хранятся в meta "anim" корня модели.
## Питомцы: decorate_pet() добавляет ошейник цвета роли и украшения по стадии эволюции.
##
## Отрисовка (под слабые телефоны): детали не отдельные MeshInstance3D, а один меш на модель.
## Подвижные части (тело, голова, лапы, хвост, крылья, усики, руки, рунные камни, нимб) — узлы-шарниры
## Node3D, как раньше: animate() вращает их, а в конце переносит их положение в кости Skeleton3D,
## к которым привязаны вершины слитого меша (у каждой вершины одна кость с весом 1).
## Цвет детали — в цвете вершин, свет и вспышка удара — creature.gdshader, контур — creature_outline.gdshader.
## Полупрозрачные детали (GLASS) — вторая поверхность того же меша. Геометрия (ArrayMesh и Skin) кэшируется
## по виду, цвету и размеру и общая у всех одинаковых зверей; материал тела у каждого зверя свой (вспышка).
## Итого зверь — 1 вызов отрисовки (+1 контур), питомец — ещё круг и сияние 3-й стадии.
## skinned = false — запасной режим без скелета: один меш на каждую подвижную часть (≈5–11 вызовов).

## Цвета ролей питомцев (ошейник, бантик, узоры).
const ROLE_COLORS := {
	"tank": Color(0.35, 0.6, 1.0),
	"fighter": Color(1.0, 0.38, 0.35),
	"mage": Color(0.72, 0.45, 1.0),
	"healer": Color(1.0, 0.58, 0.8),
}
const BLUSH := Color(1.0, 0.45, 0.55, 0.55)
const GOLD := Color(1.0, 0.82, 0.3)
## Виды краски детали: освещаемая (toon), без освещения (глаза, руны), полупрозрачная (крылья).
const LIT := 0
const FLAT := 1
const GLASS := 2
const BODY_SHADER := "res://creature.gdshader"
const OUTLINE_SHADER := "res://creature_outline.gdshader"
## Толщина контура (как у Util.outline_mat).
const OUTLINE_WIDTH := 0.02

## Слитый меш на скелете (true) или по мешу на подвижную часть без скелета (false).
static var skinned := true

static var _prims := {}
static var _geo_cache := {}
static var _body_shader: Shader
static var _outline_m: ShaderMaterial
static var _glass_m: StandardMaterial3D


## Краска детали: цвет и вид (LIT, FLAT, GLASS).
class Paint extends RefCounted:
	var color := Color.WHITE
	var kind := 0

	func _init(c: Color, k: int) -> void:
		color = c
		kind = k


## Деталь модели: примитив (prim + dims), положение относительно узла host, краска.
class Part extends RefCounted:
	var host: Node3D
	## "s" — сфера, "c" — капсула, "y" — цилиндр/конус, "t" — тор, "b" — бокс.
	var prim := ""
	var dims := PackedFloat32Array()
	var key := ""
	var position := Vector3.ZERO
	var rotation := Vector3.ZERO
	var scale := Vector3.ONE
	var color := Color.WHITE
	var kind := 0
	var outline := true
	## Контур раздувается от центра детали (как outline.gdshader); false — вдоль нормали (тор).
	var radial := true

	func xform() -> Transform3D:
		return Transform3D(Basis.from_euler(rotation) * Basis.from_scale(scale), position)


## Сборка модели: детали, кости (bones[0] — корень модели), созданные узлы.
class Rig extends RefCounted:
	var key := ""
	var parts: Array = []
	var bones: Array = []
	var scaled: Array = []
	var mat: ShaderMaterial
	var skel: Skeleton3D
	var mi: MeshInstance3D
	## Режим без скелета: индекс кости → MeshInstance3D.
	var rigid := {}


## Накопитель вершин слитого меша.
class Acc extends RefCounted:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var tans := PackedFloat32Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var idx := PackedInt32Array()

	## Добавляет примитив arr, преобразованный m. flags: UV (освещение, контур). bone < 0 — без костей.
	func add(arr: Array, m: Transform3D, col: Color, flags: Vector2, bone: int, radial: bool) -> void:
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var ind: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var nb := m.basis.inverse().transposed()
		var base := verts.size()
		for i in v.size():
			var lv := v[i]
			verts.append(m * lv)
			var n := (nb * nrm[i]).normalized()
			if n.length_squared() < 0.5:
				n = Vector3.UP
			norms.append(n)
			var d := n
			if radial and lv.length_squared() > 1e-8:
				d = (m.basis * lv.normalized()).normalized()
				if d.length_squared() < 0.5:
					d = n
			tans.append(d.x)
			tans.append(d.y)
			tans.append(d.z)
			tans.append(1.0)
			cols.append(col)
			uvs.append(flags)
			if bone >= 0:
				bones.append(bone)
				bones.append(0)
				bones.append(0)
				bones.append(0)
				weights.append(1.0)
				weights.append(0.0)
				weights.append(0.0)
				weights.append(0.0)
		if ind.is_empty():
			for i in v.size():
				idx.append(base + i)
		else:
			for i in ind:
				idx.append(base + i)

	func is_empty() -> bool:
		return verts.is_empty()

	func arrays() -> Array:
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = verts
		a[Mesh.ARRAY_NORMAL] = norms
		a[Mesh.ARRAY_TANGENT] = tans
		a[Mesh.ARRAY_COLOR] = cols
		a[Mesh.ARRAY_TEX_UV] = uvs
		if not bones.is_empty():
			a[Mesh.ARRAY_BONES] = bones
			a[Mesh.ARRAY_WEIGHTS] = weights
		a[Mesh.ARRAY_INDEX] = idx
		return a


## Строит модель вида species в root. Возвращает материал тела (свой у каждого зверя): вспышка
## при ударе — CreatureModels.flash(узел, материал). tint — оттенок текстуры модели из файла
## (стадия питомца, PetData.asset_tint); у моделей из примитивов цвет задаёт color.
## stage — стадия эволюции питомца (0..2): если у вида есть своя модель стадии (CreatureAsset.model_for),
## строится она, без оттенка tint (дикие звери — stage 0).
static func build(root: Node3D, species: String, color: Color, s: float, tint: Color = Color.WHITE,
		stage: int = 0) -> Material:
	var mid := CreatureAsset.model_for(species, stage)
	if mid != species:
		tint = Color.WHITE
	if CreatureAsset.has_asset(mid):
		var ca := CreatureAsset.new()
		if ca.setup(mid, s, color, tint):
			root.add_child(ca)
			root.set_meta("asset", ca)
			return ca.material
		ca.free()
	var rig := Rig.new()
	rig.key = "%s|%s|%.4f" % [species, color.to_html(true), s]
	rig.bones.append(root)
	rig.scaled.append(false)
	rig.mat = _body_mat()
	root.set_meta("cm_rig", rig)
	match species:
		"panther":
			_panther(root, rig, color, s)
		"turtle":
			_turtle(root, rig, color, s)
		"pheasant":
			_pheasant(root, rig, color, s)
		"golem":
			_golem(root, rig, color, s)
		"flyfish", "flyfish_sail", "flyfish_drake":
			_fish(root, rig, species, color, s)
		"anathema", "anathema_blade", "anathema_chief":
			_lizard(root, rig, species, color, s)
		_:
			_beast(root, rig, species, color, s)
	var a: Dictionary = root.get_meta("anim", {})
	_finish(root, rig, a)
	root.set_meta("anim", a)
	return rig.mat


## Модель из файла в корне модели root (после build()) или null — модель из примитивов.
static func asset_of(root: Node3D) -> CreatureAsset:
	if root == null or not root.has_meta("asset"):
		return null
	var ca = root.get_meta("asset")
	if not is_instance_valid(ca):
		return null
	return ca as CreatureAsset


## Белая вспышка модели при ударе (материал из build()); твин принадлежит узлу owner.
## Модель из примитивов — параметр flash шейдера, модель из файла — эмиссия материала.
static func flash(owner: Node, mat: Material) -> void:
	if mat == null or owner == null or not owner.is_inside_tree():
		return
	var sm := mat as ShaderMaterial
	if sm != null:
		sm.set_shader_parameter("flash", 1.0)
		var setter := func(v: float) -> void:
			sm.set_shader_parameter("flash", v)
		var t := owner.create_tween()
		t.tween_method(setter, 1.0, 0.0, 0.15)
		return
	var bm := mat as BaseMaterial3D
	if bm != null and bm.emission_enabled:
		bm.emission = CreatureAsset.FLASH
		var te := owner.create_tween()
		te.tween_property(bm, "emission", Color.BLACK, 0.18)


## Высота макушки модели над землёй (для подписи и значков над головой). species — вид или id модели
## стадии (CreatureAsset.model_for); то же у add_collision и ring_radius.
static func height(species: String, s: float) -> float:
	if CreatureAsset.is_asset_species(species):
		return CreatureAsset.height_for(species, s)
	if species == "golem":
		return 2.15 * s
	return 1.4 * s


## Коробка-коллизия вида, нижняя грань на уровне земли.
static func add_collision(body: Node3D, species: String, s: float) -> CollisionShape3D:
	var size := Vector3(0.9, 1.2, 1.5)
	if CreatureAsset.is_asset_species(species):
		# Размеры вида из creatures.json (длина с хвостом — коробка чуть короче)
		var inf := CreatureAsset.info_for(species)
		size = Vector3(maxf(0.3, float(inf["width"])), maxf(0.3, float(inf["height"])),
			maxf(0.3, float(inf["length"]) * 0.8))
	elif species == "golem":
		size = Vector3(1.3, 2.1, 0.9)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size * s
	col.shape = sh
	col.position = Vector3(0, size.y * s * 0.5, 0)
	body.add_child(col)
	return col


## Цвет роли питомца.
static func role_color(role: String) -> Color:
	return ROLE_COLORS.get(role, Color(0.3, 0.8, 1.0))


## Радиус круга под питомцем (своя модель — по размерам вида).
static func ring_radius(species: String, s: float) -> float:
	if CreatureAsset.is_asset_species(species):
		var inf := CreatureAsset.info_for(species)
		return maxf(0.45, 0.32 * maxf(float(inf["length"]), float(inf["width"]))) * s
	return 0.45 * s


## Анимация модели из примитивов (вызывать каждый кадр). moving: 0 — стоит, 1 — бежит на полной скорости.
## Звери и птицы покачиваются и переставляют лапы, у стража кружат рунные камни.
## Модель из файла анимирует CreatureAsset.update() (здесь ничего не делается).
static func animate(root: Node3D, _species: String, t: float, moving: float = 0.0) -> void:
	if root == null or not root.has_meta("anim"):
		return
	var a: Dictionary = root.get_meta("anim")
	var mv := clampf(moving, 0.0, 1.0)
	var kind := String(a.get("kind", ""))
	var body: Node3D = a.get("body")
	var head: Node3D = a.get("head")
	var legs: Array = a.get("legs", [])
	var s := float(a.get("s", 1.0))
	match kind:
		"quad":
			var f := 10.0
			if body != null:
				body.position.y = absf(sin(t * f)) * 0.07 * s * mv + sin(t * 2.2) * 0.015 * s * (1.0 - mv)
				body.rotation.z = sin(t * f) * 0.04 * mv
			for i in legs.size():
				var leg := legs[i] as Node3D
				var ph := 0.0 if (i == 0 or i == 3) else PI
				leg.rotation.x = sin(t * f + ph) * 0.65 * mv
			if head != null:
				head.rotation.x = sin(t * 1.7) * 0.05 + sin(t * f * 2.0) * 0.03 * mv
				head.rotation.z = sin(t * 1.1) * 0.07
			var tail: Node3D = a.get("tail")
			if tail != null:
				tail.rotation.y = sin(t * (5.0 + 7.0 * mv)) * 0.45
		"golem":
			var f := 5.0
			if body != null:
				body.position.y = absf(sin(t * f)) * 0.05 * s * mv + sin(t * 1.5) * 0.02 * s
				body.rotation.z = sin(t * f) * 0.05 * mv
			for i in legs.size():
				var leg := legs[i] as Node3D
				leg.rotation.x = sin(t * f + PI * float(i)) * 0.45 * mv
			var arms: Array = a.get("arms", [])
			for i in arms.size():
				var arm := arms[i] as Node3D
				arm.rotation.x = -sin(t * f + PI * float(i)) * 0.4 * mv + sin(t * 1.5 + float(i)) * 0.05
			var runes: Node3D = a.get("runes")
			if runes != null:
				runes.rotation.y = t * 1.1
				runes.position.y = float(a.get("runes_y", 0.0)) + sin(t * 2.0) * 0.06 * s
			if head != null:
				head.rotation.z = sin(t * 1.2) * 0.05
		"fish":
			# Парит: покачивание, хвост виляет, грудные плавники машут (на ходу чаще и шире)
			if body != null:
				body.position.y = float(a.get("body_y", 0.0)) + sin(t * 2.0) * 0.04 * s
				body.rotation.x = -0.1 * mv
			var fish_tail: Node3D = a.get("tail")
			if fish_tail != null:
				fish_tail.rotation.y = sin(t * (5.0 + 6.0 * mv)) * (0.3 + 0.2 * mv)
			var fins: Array = a.get("fins", [])
			for i in fins.size():
				var fin := fins[i] as Node3D
				fin.rotation.z = (1.0 if i == 0 else -1.0) * sin(t * (6.0 + 6.0 * mv)) * (0.35 + 0.25 * mv)
	# Общие детали: пульсирующее свечение (узел glow) и нимб питомца 3-й стадии
	var glow: Node3D = a.get("glow")
	if glow != null:
		var k := 1.0 + sin(t * 4.0) * 0.12
		var gb: Vector3 = glow.get_meta("base", Vector3.ONE)
		glow.scale = gb * k
	var halo: Node3D = a.get("halo")
	if halo != null:
		halo.rotation.y = t * 1.5
		halo.position.y = float(a.get("halo_y", 0.0)) + sin(t * 2.5) * 0.04
	_sync(a)


## Переносит положение узлов-шарниров в кости скелета слитого меша.
static func _sync(a: Dictionary) -> void:
	var skel: Skeleton3D = a.get("skel")
	if skel == null:
		return
	var bones: Array = a["bones"]
	var offs: Array = a["offs"]
	var flags: PackedByteArray = a["bflags"]
	var n := mini(bones.size(), mini(flags.size(), skel.get_bone_count()))
	for i in range(1, n):
		var node := bones[i] as Node3D
		var f := flags[i]
		if f & 1:
			var off: Transform3D = offs[i]
			var tr := off * node.transform
			skel.set_bone_pose_position(i, tr.origin)
			skel.set_bone_pose_rotation(i, tr.basis.get_rotation_quaternion())
			if f & 2:
				skel.set_bone_pose_scale(i, tr.basis.get_scale())
		else:
			skel.set_bone_pose_position(i, node.position)
			skel.set_bone_pose_rotation(i, node.quaternion)
			if f & 2:
				skel.set_bone_pose_scale(i, node.scale)


## Материал без освещения: светящиеся детали, метки, снаряды.
static func flat_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


## Расходящийся круг на земле (удар по площади, лечение, предупреждение). Сам исчезает.
static func spawn_ring(parent: Node, pos: Vector3, radius: float, color: Color, time: float = 0.5) -> void:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var mi := MeshInstance3D.new()
	mi.set_meta("no_outline", true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.04
	cm.radial_segments = 32
	cm.rings = 1
	mi.mesh = cm
	var m := Vfx.fx_mat(Color(color, 0.3), null, false)
	mi.material_override = m
	parent.add_child(mi)
	mi.global_position = Vector3(pos.x, 0.05, pos.z)
	mi.scale = Vector3(0.15, 1.0, 0.15)
	# Яркая кромка круга
	var edge := MeshInstance3D.new()
	edge.set_meta("no_outline", true)
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	edge.mesh = Vfx._plane()
	var em := Vfx.fx_mat(Color(color, 0.95), Vfx.tex("ring"), false)
	edge.material_override = em
	mi.add_child(edge)
	edge.position.y = 0.03
	edge.scale = Vector3(radius, 1.0, radius) / 0.82
	var t := mi.create_tween()
	t.set_parallel(true)
	t.tween_property(mi, "scale", Vector3.ONE, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(m, "albedo_color:a", 0.0, time)
	t.tween_property(em, "albedo_color:a", 0.0, time * 0.5).set_delay(time * 0.5)
	t.chain().tween_callback(mi.queue_free)


# ---------- Питомцы ----------

## Украшения питомца: ошейник цвета роли с бубенчиком (все стадии); бантик и узоры на спине
## (со 2-й стадии); золотой нимб, сияние под ногами и искорки (3-я стадия). Вызывать после build().
## У модели из файла — CreatureAsset.decorate() (самоцвет роли над головой, нимб, сияние).
## Детали украшений вливаются в слитый меш модели (меш пересобирается).
static func decorate_pet(root: Node3D, species: String, s: float, stage: int, role: String) -> void:
	var ca := asset_of(root)
	if ca != null:
		ca.decorate(stage, role)
		return
	var rig := root.get_meta("cm_rig", null) as Rig
	if rig == null:
		return
	var rc := role_color(role)
	var a: Dictionary = root.get_meta("anim", {})
	var neck := root.find_child("Neck", true, false) as Node3D
	if neck != null:
		var r := float(neck.get_meta("r", 0.25 * s))
		_torus(rig, neck, r, r + 0.075 * s, Vector3.ZERO, _lit(rc))
		_pivot(neck, "Collar", Vector3.ZERO)
		var host := neck.get_parent() as Node3D
		var off: Vector3 = neck.get_meta("charm", Vector3(0, -r, 0))
		_ball(rig, host, 0.065 * s, neck.position + off, _lit(GOLD))
	if stage >= 1:
		var bow := root.find_child("Bow", true, false) as Node3D
		if bow != null:
			var bm := _lit(rc.lightened(0.15))
			for i in 2:
				var side := float(i * 2 - 1)
				var loop := _ball(rig, bow, 0.085 * s, Vector3(0.085 * side * s, 0.0, 0.0), bm, Vector3(1.0, 0.65, 0.45))
				loop.rotation.z = -0.35 * side
			_ball(rig, bow, 0.045 * s, Vector3.ZERO, _lit(rc.darkened(0.15)))
		var back := root.find_child("Back", true, false) as Node3D
		if back != null:
			# Узоры-пятнышки на поверхности тела (эллипсоид radii вокруг узла Back)
			var radii: Vector3 = back.get_meta("radii", Vector3.ONE * 0.4 * s)
			var u0: Vector3 = back.get_meta("u", Vector3(0.55, 0.8, 0.1))
			var mark_m := _flat(rc.lightened(0.35))
			var msize := minf(radii.x, minf(radii.y, radii.z)) * 0.32
			for i in 2:
				var side := float(i * 2 - 1)
				var u := Vector3(u0.x * side, u0.y, u0.z).normalized()
				var p := Vector3(u.x * radii.x, u.y * radii.y, u.z * radii.z)
				var n := Vector3(u.x / radii.x, u.y / radii.y, u.z / radii.z)
				var mk := _ball(rig, back, msize, p, mark_m, Vector3(1.0, 0.75, 0.3), true)
				_face(mk, n)
				_pivot(back, "Mark%d" % i, p)
	if stage >= 2:
		var top := root.find_child("Top", true, false) as Node3D
		if top != null:
			var hy := 0.22 * s + 0.08
			var holder := _joint(rig, top, "Halo", Vector3(0, hy, 0))
			var ring := _torus(rig, holder, 0.17 * s, 0.22 * s, Vector3.ZERO, _flat(Color(1.0, 0.92, 0.5)), true)
			ring.rotation.x = 0.2
			a["halo"] = holder
			a["halo_y"] = hy
		# Сияние под ногами и искорки
		var aura := MeshInstance3D.new()
		aura.name = "Aura"
		aura.set_meta("no_outline", true)
		aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var pm := PlaneMesh.new()
		pm.size = Vector2(1.6, 1.6) * s + Vector2(0.4, 0.4)
		aura.mesh = pm
		aura.material_override = Vfx.fx_mat(Color(1.0, 0.88, 0.45, 0.55), Vfx.tex("dot"), true)
		aura.position.y = 0.04
		root.add_child(aura)
		var sp := Vfx.ambient_sparkles(root, Color(1.0, 0.92, 0.55), 0.6 * s, 6)
		sp.position.y = height(species, s) * 0.55
	rig.key += "|pet%d|%s" % [stage, role]
	_finish(root, rig, a)
	root.set_meta("anim", a)


# ---------- Виды ----------

## Четвероногий зверь-чиби: кабан (пятачок, клыки, хохолок, хвостик-завиток), волк (уши торчком,
## пушистый хвост, светлая грудка).
static func _beast(root: Node3D, rig: Rig, species: String, color: Color, s: float) -> void:
	var boar := species == "boar"
	var wolf := species == "wolf"
	var m := _lit(color)
	var light := _lit(color.lightened(0.42))
	var dark := _lit(color.darkened(0.3))
	var anim := {"kind": "quad", "s": s}

	var body := _joint(rig, root, "Body", Vector3.ZERO)
	anim["body"] = body
	var torso_sc := Vector3(0.86, 0.76, 1.2)
	_ball(rig, body, 0.5 * s, Vector3(0, 0.7, 0.05) * s, m, torso_sc, false, 16)
	if wolf:
		_ball(rig, body, 0.27 * s, Vector3(0, 0.82, -0.48) * s, light, Vector3(1.0, 1.1, 0.75))

	# Голова
	var hr := (0.36 if wolf else 0.38) * s
	var head := _joint(rig, body, "Head", Vector3(0, 1.0, -0.62) * s)
	anim["head"] = head
	_ball(rig, head, hr, Vector3.ZERO, m, Vector3(1.05, 0.95, 0.95), false, 16)
	var iris := Color(0.16, 0.1, 0.07)
	if wolf:
		iris = Color(0.16, 0.3, 0.55)
	_eyes(rig, head, hr, 0.115 * s, iris, 0.46, 0.2 if boar else 0.17, true)
	_blush(rig, head, hr, 0.07 * s, color)

	if boar:
		# Пятачок с ноздрями и клыки
		var snout_m := _lit(color.lerp(Color(1.0, 0.7, 0.68), 0.55))
		var snout := _cyl(rig, head, 0.13 * s, 0.13 * s, 0.15 * s, Vector3(0, -0.13 * s, -hr - 0.02 * s), snout_m)
		snout.rotation.x = PI / 2.0
		var nost := _flat(Color(0.35, 0.18, 0.15))
		var tusk_m := _lit(Color(1.0, 0.97, 0.88))
		for i in 2:
			var side := float(i * 2 - 1)
			_ball(rig, head, 0.032 * s, Vector3(0.05 * side * s, -0.13 * s, -hr - 0.095 * s), nost,
				Vector3(0.8, 1.2, 0.4), true)
			var tusk := _cyl(rig, head, 0.0, 0.04 * s, 0.15 * s, Vector3(0.12 * side * s, -0.21 * s, -hr * 0.92 - 0.03 * s), tusk_m, true)
			tusk.rotation = Vector3(-0.35, 0.0, -0.4 * side)
			# Ушки-треугольники, чуть свисают вперёд
			var ear := _cyl(rig, head, 0.0, 0.1 * s, 0.2 * s, Vector3(0.25 * side, 0.27, 0.02) * s, dark)
			ear.rotation = Vector3(-0.45, 0.0, -0.7 * side)
		# Хохолок из трёх прядей
		var tuft_m := _lit(color.darkened(0.45).lerp(Color(0.95, 0.55, 0.25), 0.3))
		for i in 3:
			var tuft := _cyl(rig, head, 0.0, (0.08 - 0.012 * float(i)) * s, (0.26 - 0.04 * float(i)) * s,
				Vector3(0, 0.36 - 0.05 * float(i), 0.0 + 0.11 * float(i)) * s, tuft_m)
			tuft.rotation.x = 0.55 + 0.25 * float(i)
	elif wolf:
		# Мордочка, носик, уши торчком с розовой серединкой
		_ball(rig, head, 0.17 * s, Vector3(0, -0.1 * s, -hr * 0.93), light, Vector3(0.9, 0.72, 1.25))
		_ball(rig, head, 0.055 * s, Vector3(0, -0.06 * s, -hr - 0.17 * s), _flat(Color(0.12, 0.1, 0.12)),
			Vector3(1.2, 0.85, 0.8), true)
		var inner := _flat(Color(1.0, 0.7, 0.75))
		for i in 2:
			var side := float(i * 2 - 1)
			var ear := _cyl(rig, head, 0.0, 0.12 * s, 0.32 * s, Vector3(0.19 * side, 0.33, 0.03) * s, dark)
			ear.rotation = Vector3(-0.1, 0.0, -0.28 * side)
			ear.scale = Vector3(1.0, 1.0, 0.6)
			var ein := _cyl(rig, head, 0.0, 0.065 * s, 0.2 * s, Vector3(0.185 * side, 0.31, 0.0) * s, inner, true)
			ein.rotation = Vector3(-0.1, 0.0, -0.28 * side)
			ein.scale = Vector3(1.0, 1.0, 0.45)

	# Хвост
	var tail := _joint(rig, body, "Tail", Vector3(0, 0.88, 0.62) * s)
	anim["tail"] = tail
	if boar:
		var curl := _torus(rig, tail, 0.045 * s, 0.085 * s, Vector3(0, 0.02, 0.06) * s, _lit(color.lerp(Color(1.0, 0.7, 0.68), 0.3)))
		curl.rotation.z = PI / 2.0
	elif wolf:
		tail.rotation.x = -0.75
		_ball(rig, tail, 0.17 * s, Vector3(0, 0, 0.3) * s, m, Vector3(0.8, 0.8, 1.9))
		_ball(rig, tail, 0.13 * s, Vector3(0, 0, 0.6) * s, light)

	# Лапки на шарнирах у бедра
	var legs: Array = []
	var lr := 0.12 * s
	var zs := [-0.34, 0.38]
	for zi in 2:
		for i in 2:
			var side := float(i * 2 - 1)
			var hip := _joint(rig, root, "Leg", Vector3(0.27 * side, 0.4, float(zs[zi])) * s)
			_capsule(rig, hip, lr, 0.46 * s, Vector3(0, -0.17 * s, 0), dark)
			legs.append(hip)
	# Порядок для походки: передняя левая, передняя правая, задняя левая, задняя правая
	anim["legs"] = legs

	# Точки для украшений питомца
	# Ошейник — кольцо сразу за головой, бубенчик на груди
	var neck := _pivot(body, "Neck", Vector3(0, 0.72, -0.33) * s)
	neck.rotation.x = -1.32
	neck.set_meta("r", 0.36 * s)
	neck.set_meta("charm", Vector3(0, -0.14, -0.27) * s)
	var bow := _pivot(head, "Bow", Vector3(-0.17, 0.29, -0.12) * s)
	bow.rotation.z = 0.35
	_pivot(head, "Top", Vector3(0, hr * 0.95, 0))
	var back := _pivot(body, "Back", Vector3(0, 0.7, 0.05) * s)
	back.set_meta("radii", Vector3(0.5 * torso_sc.x, 0.5 * torso_sc.y, 0.5 * torso_sc.z) * s)
	root.set_meta("anim", anim)


## Пантера (запасная модель, если нет assets/creatures/panther.glb): гибкая кошка — вытянутое тело,
## небольшая голова с ушками-треугольниками, фиолетовые глаза, светящаяся руна на лбу, длинный хвост.
## Размеры по CreatureAsset.DEFAULTS: высота 1.15, длина 1.9 (с хвостом), ширина 0.5.
static func _panther(root: Node3D, rig: Rig, color: Color, s: float) -> void:
	var m := _lit(color)
	var light := _lit(color.lightened(0.22))
	var dark := _lit(color.darkened(0.3))
	var rune_c := Color(0.72, 0.45, 1.0)
	var anim := {"kind": "quad", "s": s}

	var body := _joint(rig, root, "Body", Vector3.ZERO)
	anim["body"] = body
	var torso_sc := Vector3(0.62, 0.6, 1.3)
	_ball(rig, body, 0.4 * s, Vector3(0, 0.6, 0.02) * s, m, torso_sc, false, 16)
	_ball(rig, body, 0.19 * s, Vector3(0, 0.56, -0.34) * s, light, Vector3(0.95, 1.0, 0.8))

	# Голова: мордочка, носик, ушки, руна на лбу
	var hr := 0.25 * s
	var head := _joint(rig, body, "Head", Vector3(0, 0.84, -0.6) * s)
	anim["head"] = head
	_ball(rig, head, hr, Vector3.ZERO, m, Vector3(1.05, 0.92, 0.95), false, 16)
	_ball(rig, head, 0.12 * s, Vector3(0, -0.08 * s, -hr * 0.88), light, Vector3(1.0, 0.72, 0.9))
	_ball(rig, head, 0.04 * s, Vector3(0, -0.04 * s, -hr - 0.07 * s), _flat(Color(0.12, 0.08, 0.14)),
		Vector3(1.2, 0.8, 0.8), true)
	_eyes(rig, head, hr, 0.085 * s, Color(0.5, 0.25, 0.85), 0.44, 0.16, true)
	_blush(rig, head, hr, 0.045 * s, color)
	var inner := _flat(color.lightened(0.35).lerp(Color(0.85, 0.6, 1.0), 0.4))
	for i in 2:
		var side := float(i * 2 - 1)
		var ear := _cyl(rig, head, 0.0, 0.09 * s, 0.17 * s, Vector3(0.15 * side, 0.21, 0.02) * s, dark)
		ear.rotation = Vector3(-0.15, 0.0, -0.32 * side)
		ear.scale = Vector3(1.0, 1.0, 0.6)
		var ein := _cyl(rig, head, 0.0, 0.05 * s, 0.11 * s, Vector3(0.145 * side, 0.2, -0.01) * s, inner, true)
		ein.rotation = Vector3(-0.15, 0.0, -0.32 * side)
		ein.scale = Vector3(1.0, 1.0, 0.45)
	var rune_d := Vector3(0, 0.45, -1.0).normalized()
	var rune := _ball(rig, head, 0.045 * s, rune_d * hr * 0.97, _flat(rune_c), Vector3(0.7, 1.2, 0.3), true)
	_face(rune, rune_d)

	# Длинный хвост, слегка поднят
	var tail := _joint(rig, body, "Tail", Vector3(0, 0.7, 0.5) * s)
	anim["tail"] = tail
	tail.rotation.x = -0.35
	var tc := _capsule(rig, tail, 0.06 * s, 0.72 * s, Vector3(0, 0, 0.34) * s, m)
	tc.rotation.x = PI / 2.0
	_ball(rig, tail, 0.075 * s, Vector3(0, 0, 0.68) * s, dark)

	# Лапы
	var legs: Array = []
	var zs := [-0.3, 0.32]
	for zi in 2:
		for i in 2:
			var side := float(i * 2 - 1)
			var hip := _joint(rig, root, "Leg", Vector3(0.16 * side, 0.36, float(zs[zi])) * s)
			_capsule(rig, hip, 0.085 * s, 0.42 * s, Vector3(0, -0.15 * s, 0), m)
			_ball(rig, hip, 0.075 * s, Vector3(0, -0.3, -0.03) * s, dark, Vector3(1.0, 0.6, 1.25))
			legs.append(hip)
	anim["legs"] = legs

	# Точки для украшений питомца
	var neck := _pivot(body, "Neck", Vector3(0, 0.72, -0.42) * s)
	neck.rotation.x = -1.2
	neck.set_meta("r", 0.19 * s)
	neck.set_meta("charm", Vector3(0, -0.1, -0.15) * s)
	var bow := _pivot(head, "Bow", Vector3(-0.14, 0.2, -0.04) * s)
	bow.rotation.z = 0.35
	_pivot(head, "Top", Vector3(0, hr * 0.95, 0))
	var back := _pivot(body, "Back", Vector3(0, 0.6, 0.02) * s)
	back.set_meta("radii", Vector3(0.4 * torso_sc.x, 0.4 * torso_sc.y, 0.4 * torso_sc.z) * s)
	root.set_meta("anim", anim)


## Черепаха (запасная модель): высокий панцирь с пластинами и светлой каймой, голова на шее,
## четыре толстые лапы, хвостик. Размеры: высота 0.85, длина 1.3, ширина 0.95.
static func _turtle(root: Node3D, rig: Rig, color: Color, s: float) -> void:
	var shell := _lit(color)
	var plate := _lit(color.darkened(0.25))
	var rim := _lit(color.lerp(Color(0.95, 0.85, 0.55), 0.55))
	var skin_c := color.lerp(Color(0.75, 0.85, 0.5), 0.55).lightened(0.1)
	var skin := _lit(skin_c)
	var anim := {"kind": "quad", "s": s}

	var body := _joint(rig, root, "Body", Vector3.ZERO)
	anim["body"] = body
	var shell_sc := Vector3(0.95, 0.78, 1.1)
	_ball(rig, body, 0.5 * s, Vector3(0, 0.45, 0.05) * s, shell, shell_sc, false, 16)
	_ball(rig, body, 0.5 * s, Vector3(0, 0.36, 0.05) * s, rim, Vector3(0.99, 0.3, 1.13), false, 16)
	# Пластины панциря: одна сверху, четыре по бокам (повёрнуты по поверхности)
	var top_p := _ball(rig, body, 0.15 * s, Vector3(0, 0.82, 0.05) * s, plate, Vector3(1.0, 1.0, 0.22), true)
	_face(top_p, Vector3.UP)
	for zi in 2:
		for i in 2:
			var side := float(i * 2 - 1)
			var fz := float(zi * 2 - 1)
			var u := Vector3(0.55 * side, 0.7, 0.45 * fz).normalized()
			var p := Vector3(u.x * 0.475, 0.45 + u.y * 0.39, 0.05 + u.z * 0.55) * s
			var pl := _ball(rig, body, 0.12 * s, p, plate, Vector3(1.0, 1.0, 0.22), true)
			_face(pl, Vector3(u.x / 0.475, u.y / 0.39, u.z / 0.55))

	# Шея и голова
	var nk := _capsule(rig, body, 0.1 * s, 0.32 * s, Vector3(0, 0.41, -0.5) * s, skin)
	nk.rotation.x = -1.1
	var hr := 0.19 * s
	var head := _joint(rig, body, "Head", Vector3(0, 0.46, -0.6) * s)
	anim["head"] = head
	_ball(rig, head, hr, Vector3.ZERO, skin, Vector3(1.0, 0.9, 1.05), false, 16)
	_eyes(rig, head, hr, 0.07 * s, Color(0.14, 0.1, 0.08), 0.5, 0.18, true)
	_blush(rig, head, hr, 0.04 * s, skin_c)
	_ball(rig, head, 0.035 * s, Vector3(0, -0.07 * s, -hr * 0.95), _flat(skin_c.darkened(0.45)),
		Vector3(1.6, 0.4, 0.5), true)

	# Хвостик
	var tail := _joint(rig, body, "Tail", Vector3(0, 0.3, 0.6) * s)
	anim["tail"] = tail
	var tc := _cyl(rig, tail, 0.0, 0.07 * s, 0.18 * s, Vector3(0, 0, 0.07) * s, skin)
	tc.rotation.x = PI / 2.0

	# Толстые лапы
	var legs: Array = []
	var zs := [-0.3, 0.32]
	for zi in 2:
		for i in 2:
			var side := float(i * 2 - 1)
			var hip := _joint(rig, root, "Leg", Vector3(0.36 * side, 0.26, float(zs[zi])) * s)
			_capsule(rig, hip, 0.12 * s, 0.32 * s, Vector3(0, -0.1 * s, 0), skin)
			legs.append(hip)
	anim["legs"] = legs

	# Точки для украшений питомца
	var neck := _pivot(body, "Neck", Vector3(0, 0.42, -0.5) * s)
	neck.rotation.x = -1.1
	neck.set_meta("r", 0.12 * s)
	neck.set_meta("charm", Vector3(0, -0.12, -0.04) * s)
	var bow := _pivot(head, "Bow", Vector3(-0.12, 0.15, 0.0) * s)
	bow.rotation.z = 0.4
	_pivot(head, "Top", Vector3(0, hr * 0.95, 0))
	var back := _pivot(body, "Back", Vector3(0, 0.45, 0.05) * s)
	back.set_meta("radii", Vector3(0.5 * shell_sc.x, 0.5 * shell_sc.y, 0.5 * shell_sc.z) * s)
	back.set_meta("u", Vector3(0.75, 0.55, -0.1))
	root.set_meta("anim", anim)


## Фазан (запасная модель): медное тело, бирюзовая голова с красными «масками» у глаз и ушками-перьями,
## белое колечко на шее, светлые крылья, длинный полосатый хвост, тонкие ножки.
## Размеры: высота 0.85, длина 1.1, ширина 0.4.
static func _pheasant(root: Node3D, rig: Rig, color: Color, s: float) -> void:
	var m := _lit(color)
	var breast := _lit(color.darkened(0.15).lerp(Color(0.6, 0.18, 0.12), 0.35))
	var wing := _lit(color.lerp(Color(0.9, 0.8, 0.55), 0.45))
	var head_c := Color(0.12, 0.45, 0.42)
	var head_m := _lit(head_c)
	var tail_m := _lit(color.lerp(Color(0.85, 0.7, 0.45), 0.3))
	var stripe := _lit(color.darkened(0.45))
	var leg_m := _lit(Color(0.6, 0.48, 0.36))
	var anim := {"kind": "quad", "s": s}

	var body := _joint(rig, root, "Body", Vector3.ZERO)
	anim["body"] = body
	var body_sc := Vector3(0.85, 0.85, 1.25)
	_ball(rig, body, 0.26 * s, Vector3(0, 0.46, 0.02) * s, m, body_sc, false, 16)
	_ball(rig, body, 0.17 * s, Vector3(0, 0.44, -0.18) * s, breast, Vector3(0.95, 1.0, 0.8))
	for i in 2:
		var side := float(i * 2 - 1)
		var w := _ball(rig, body, 0.17 * s, Vector3(0.17 * side, 0.5, 0.06) * s, wing, Vector3(0.35, 0.68, 1.25))
		w.rotation.x = 0.2
	# Шея с белым колечком
	var nk := _capsule(rig, body, 0.07 * s, 0.22 * s, Vector3(0, 0.62, -0.2) * s, head_m)
	nk.rotation.x = -0.3
	var ring := _torus(rig, body, 0.065 * s, 0.09 * s, Vector3(0, 0.58, -0.19) * s, _lit(Color(0.97, 0.97, 0.93)))
	ring.rotation.x = -0.3

	# Голова: красные «маски», глаза, клювик, ушки-перья
	var hr := 0.11 * s
	var head := _joint(rig, body, "Head", Vector3(0, 0.74, -0.25) * s)
	anim["head"] = head
	_ball(rig, head, hr, Vector3.ZERO, head_m, Vector3.ONE, false, 14)
	var red := _lit(Color(0.92, 0.2, 0.18))
	for i in 2:
		var side := float(i * 2 - 1)
		var d := Vector3(0.62 * side, -0.05, -0.78).normalized()
		var patch := _ball(rig, head, 0.055 * s, d * hr * 0.8, red, Vector3(0.9, 1.1, 0.7))
		_face(patch, d)
		var tuft := _cyl(rig, head, 0.0, 0.03 * s, 0.09 * s, Vector3(0.05 * side, 0.1, 0.04) * s,
			_lit(head_c.darkened(0.3)))
		tuft.rotation = Vector3(0.6, 0.0, -0.2 * side)
	_eyes(rig, head, hr, 0.04 * s, Color(0.12, 0.08, 0.05), 0.6, 0.12, true)
	var beak := _cyl(rig, head, 0.0, 0.035 * s, 0.09 * s, Vector3(0, -0.025, -0.14) * s, _lit(Color(0.95, 0.85, 0.55)))
	beak.rotation.x = -PI / 2.0

	# Длинный хвост из трёх перьев с тёмными полосками
	var tail := _joint(rig, body, "Tail", Vector3(0, 0.5, 0.3) * s)
	anim["tail"] = tail
	tail.rotation.x = -0.35
	for i in 3:
		var side := float(i - 1)
		var ln := 1.0 - 0.18 * absf(side)
		var fz := 0.27 * ln
		var f := _ball(rig, tail, 0.065 * s, Vector3(0.04 * side, 0.0, fz) * s, tail_m,
			Vector3(0.65, 0.25, 4.2 * ln))
		f.rotation.y = 0.16 * side
		for k in 2:
			var z := (0.18 + 0.2 * float(k)) * ln
			var st := _ball(rig, tail, 0.05 * s, Vector3(0.04 * side + 0.16 * side * (z - fz), 0.012, z) * s, stripe,
				Vector3(0.75, 0.2, 0.25), true)
			st.rotation.y = 0.16 * side

	# Тонкие ножки с лапками
	var legs: Array = []
	for i in 2:
		var side := float(i * 2 - 1)
		var hip := _joint(rig, root, "Leg", Vector3(0.08 * side, 0.3, 0.04) * s)
		_capsule(rig, hip, 0.025 * s, 0.3 * s, Vector3(0, -0.14 * s, 0), leg_m)
		_ball(rig, hip, 0.05 * s, Vector3(0, -0.29, -0.03) * s, leg_m, Vector3(1.0, 0.3, 1.4))
		legs.append(hip)
	anim["legs"] = legs

	# Точки для украшений питомца
	var neck := _pivot(body, "Neck", Vector3(0, 0.66, -0.21) * s)
	neck.rotation.x = -0.3
	neck.set_meta("r", 0.075 * s)
	neck.set_meta("charm", Vector3(0, -0.03, -0.08) * s)
	var bow := _pivot(head, "Bow", Vector3(-0.09, 0.08, 0.03) * s)
	bow.rotation.z = 0.4
	_pivot(head, "Top", Vector3(0, hr * 0.95 + 0.04 * s, 0))
	var back := _pivot(body, "Back", Vector3(0, 0.46, 0.02) * s)
	back.set_meta("radii", Vector3(0.26 * body_sc.x, 0.26 * body_sc.y, 0.26 * body_sc.z) * s)
	root.set_meta("anim", anim)


## Летающая рыба (запасная модель, если нет assets/creatures/<вид>.glb): тело-капля на высоте парения,
## светлое брюхо, глаза, хвостовой и спинной плавники, грудные плавники-крылья.
## Размеры — CreatureAsset.info_for: длина и высота парения (hover).
static func _fish(root: Node3D, rig: Rig, species: String, color: Color, s: float) -> void:
	var inf := CreatureAsset.info_for(species)
	var ln := float(inf["length"]) * s
	var hy := float(inf["hover"]) * s
	var m := _lit(color)
	var belly := _lit(color.lerp(Color(1.0, 0.55, 0.2), 0.7))
	var fin_m := _lit(color.lerp(Color(1.0, 0.6, 0.25), 0.35))
	var anim := {"kind": "fish", "s": s, "body_y": hy}

	var body := _joint(rig, root, "Body", Vector3(0, hy, 0))
	anim["body"] = body
	var r := 0.17 * ln
	_ball(rig, body, r, Vector3(0, 0, -0.05 * ln), m, Vector3(0.8, 1.0, 2.1), false, 16)
	_ball(rig, body, r * 0.8, Vector3(0, -0.07 * ln, -0.1 * ln), belly, Vector3(0.75, 0.6, 1.8))
	var hr := r * 0.75
	var head := _joint(rig, body, "Head", Vector3(0, 0.02 * ln, -0.3 * ln))
	anim["head"] = head
	_ball(rig, head, hr, Vector3.ZERO, m, Vector3(0.85, 0.9, 1.0), false, 14)
	_eyes(rig, head, hr, 0.045 * ln, Color(0.1, 0.08, 0.05), 0.9, 0.25, true)

	var tail := _joint(rig, body, "Tail", Vector3(0, 0, 0.3 * ln))
	anim["tail"] = tail
	_ball(rig, tail, r * 0.55, Vector3(0, 0, 0.05 * ln), m, Vector3(0.6, 0.8, 1.6))
	for i in 2:
		var side := float(i * 2 - 1)
		var lobe := _ball(rig, tail, 0.13 * ln, Vector3(0, 0.08 * side * ln, 0.2 * ln), fin_m, Vector3(0.12, 0.45, 1.0))
		lobe.rotation.x = 0.6 * side
	var dor := _ball(rig, body, 0.12 * ln, Vector3(0, r * 0.95, 0.02 * ln), fin_m, Vector3(0.1, 0.8, 1.1))
	dor.rotation.x = 0.4
	var fins: Array = []
	for i in 2:
		var side := 1.0 - 2.0 * float(i)
		var fj := _joint(rig, body, "Fin", Vector3(0.12 * side * ln, -0.02 * ln, -0.12 * ln))
		var f := _ball(rig, fj, 0.17 * ln, Vector3(0.14 * side * ln, -0.03 * ln, 0.04 * ln), fin_m, Vector3(1.0, 0.1, 0.55))
		f.rotation.z = -0.35 * side
		fins.append(fj)
	anim["fins"] = fins
	root.set_meta("anim", anim)


## Анатема (запасная модель, если нет assets/creatures/<вид>.glb): ящер на двух ногах — тёмно-зелёное тело,
## светлое брюхо, вытянутая морда, костяные клинки-серпы вдоль предплечий, гребень из шипов (у старших — больше).
## Размеры — CreatureAsset.info_for; анимация как у стража (ноги и руки на шарнирах).
static func _lizard(root: Node3D, rig: Rig, species: String, color: Color, s: float) -> void:
	var h := float(CreatureAsset.info_for(species)["height"]) * s
	var m := _lit(color)
	var belly := _lit(Color(0.85, 0.62, 0.38))
	var bone := _lit(Color(0.92, 0.88, 0.78))
	var spikes := 3 if species == "anathema" else (5 if species == "anathema_blade" else 7)
	var anim := {"kind": "golem", "s": s}

	var legs: Array = []
	for i in 2:
		var side := float(i * 2 - 1)
		var hip := _joint(rig, root, "Leg", Vector3(0.1 * side * h, 0.47 * h, 0.0))
		_capsule(rig, hip, 0.05 * h, 0.3 * h, Vector3(0, -0.14 * h, -0.02 * h), m)
		_capsule(rig, hip, 0.04 * h, 0.22 * h, Vector3(0, -0.36 * h, 0.03 * h), m)
		_ball(rig, hip, 0.05 * h, Vector3(0, -0.46 * h, -0.04 * h), m, Vector3(0.9, 0.5, 1.6))
		legs.append(hip)
	anim["legs"] = legs

	var body := _joint(rig, root, "Body", Vector3.ZERO)
	anim["body"] = body
	_capsule(rig, body, 0.12 * h, 0.36 * h, Vector3(0, 0.63 * h, 0), m)
	_ball(rig, body, 0.09 * h, Vector3(0, 0.62 * h, -0.07 * h), belly, Vector3(0.9, 1.6, 0.5))
	for i in spikes:
		var sp := _cyl(rig, body, 0.0, 0.025 * h, 0.09 * h, Vector3(0, (0.76 - 0.05 * float(i)) * h, 0.1 * h), bone)
		sp.rotation.x = 0.9

	var head := _joint(rig, body, "Head", Vector3(0, 0.86 * h, -0.02 * h))
	anim["head"] = head
	_ball(rig, head, 0.07 * h, Vector3.ZERO, m, Vector3(0.9, 0.9, 1.1))
	_ball(rig, head, 0.045 * h, Vector3(0, -0.02 * h, -0.08 * h), m, Vector3(0.8, 0.6, 1.4))
	for i in 2:
		var side := float(i * 2 - 1)
		var eye := _ball(rig, head, 0.014 * h, Vector3(0.04 * side * h, 0.02 * h, -0.05 * h), _flat(Color(1.0, 0.75, 0.2)),
			Vector3.ONE, true)
		_face(eye, Vector3(0.5 * side, 0.2, -1.0).normalized())
		var horn := _cyl(rig, head, 0.0, 0.02 * h, 0.1 * h, Vector3(0.03 * side * h, 0.06 * h, 0.05 * h), bone)
		horn.rotation = Vector3(1.0, 0.0, -0.3 * side)

	var arms: Array = []
	for i in 2:
		var side := float(i * 2 - 1)
		var sh := _joint(rig, body, "Arm", Vector3(0.15 * side * h, 0.78 * h, 0.0))
		sh.rotation.z = 0.12 * side
		_capsule(rig, sh, 0.035 * h, 0.34 * h, Vector3(0, -0.15 * h, 0), m)
		var blade := _cyl(rig, sh, 0.0, 0.03 * h, 0.3 * h, Vector3(0.02 * side * h, -0.3 * h, 0.05 * h), bone)
		blade.rotation.x = -0.25
		arms.append(sh)
	anim["arms"] = arms
	root.set_meta("anim", anim)


## Каменный страж: круглый добродушный великан-валун — мох и росток на голове, светящиеся глаза,
## руна на груди, кулаки-булыжники и три рунных камня, кружащих вокруг.
static func _golem(root: Node3D, rig: Rig, color: Color, s: float) -> void:
	var m := _lit(color)
	var dark := _lit(color.darkened(0.25))
	var moss := _lit(Color(0.35, 0.62, 0.3))
	var rune_c := Color(0.45, 0.95, 1.0)
	var rune := _flat(rune_c)
	var anim := {"kind": "golem", "s": s}

	# Ножки на шарнирах
	var legs: Array = []
	for i in 2:
		var side := float(i * 2 - 1)
		var hip := _joint(rig, root, "Leg", Vector3(0.28 * side, 0.62, 0.0) * s)
		_capsule(rig, hip, 0.21 * s, 0.66 * s, Vector3(0, -0.29, 0) * s, dark)
		legs.append(hip)
	anim["legs"] = legs

	var body := _joint(rig, root, "Body", Vector3.ZERO)
	anim["body"] = body
	_ball(rig, body, 0.6 * s, Vector3(0, 1.12, 0) * s, m, Vector3(1.08, 0.92, 0.82), false, 16)
	var chest := _box(rig, body, Vector3(0.18, 0.18, 0.05) * s, Vector3(0, 1.15, -0.49) * s, rune, true)
	chest.rotation.z = PI / 4.0

	# Голова
	var hr := 0.32 * s
	var head := _joint(rig, body, "Head", Vector3(0, 1.8, -0.02) * s)
	anim["head"] = head
	_ball(rig, head, hr, Vector3.ZERO, m, Vector3(1.1, 0.95, 1.0), false, 16)
	for i in 2:
		var side := float(i * 2 - 1)
		var d := Vector3(0.38 * side, 0.05, -1.0).normalized()
		var eye := _ball(rig, head, 0.075 * s, d * hr * 0.95, rune, Vector3(0.85, 1.2, 0.4), true)
		_face(eye, d)
	_blush(rig, head, hr, 0.06 * s, color)
	_ball(rig, head, 0.27 * s, Vector3(0, 0.2, 0.03) * s, moss, Vector3(1.15, 0.42, 1.1))
	var leaf_m := _lit(Color(0.5, 0.88, 0.4))
	for i in 2:
		var side := float(i * 2 - 1)
		var leaf := _ball(rig, head, 0.075 * s, Vector3(0.06 * side, 0.36, 0.0) * s, leaf_m, Vector3(1.0, 0.16, 0.5))
		leaf.rotation.z = 0.55 * side

	# Руки с кулаками-булыжниками
	var arms: Array = []
	for i in 2:
		var side := float(i * 2 - 1)
		var sh := _joint(rig, body, "Arm", Vector3(0.7 * side, 1.45, 0.0) * s)
		sh.rotation.z = 0.15 * side
		_capsule(rig, sh, 0.15 * s, 0.56 * s, Vector3(0, -0.24, 0) * s, dark)
		_ball(rig, sh, 0.24 * s, Vector3(0, -0.58, -0.03) * s, m)
		arms.append(sh)
	anim["arms"] = arms

	# Рунные камни на орбите
	var runes := _joint(rig, root, "Runes", Vector3(0, 1.25, 0) * s)
	anim["runes"] = runes
	anim["runes_y"] = 1.25 * s
	for i in 3:
		var ang := TAU * float(i) / 3.0
		var stone := _pivot(runes, "Stone",
			Vector3(cos(ang) * 0.98, 0.12 * float(i) - 0.1, sin(ang) * 0.98) * s)
		stone.rotation = Vector3(0.35, -ang + PI / 2.0, 0.25)
		_box(rig, stone, Vector3(0.17, 0.2, 0.17) * s, Vector3.ZERO, dark)
		_box(rig, stone, Vector3(0.08, 0.11, 0.02) * s, Vector3(0, 0, -0.09) * s, rune, true)

	# Точки для украшений питомца
	var neck := _pivot(body, "Neck", Vector3(0, 1.62, -0.02) * s)
	neck.set_meta("r", 0.34 * s)
	neck.set_meta("charm", Vector3(0, -0.05, -0.36) * s)
	var bow := _pivot(head, "Bow", Vector3(-0.26, 0.21, 0.0) * s)
	bow.rotation.z = 0.5
	_pivot(head, "Top", Vector3(0, 0.42, 0) * s)
	var back := _pivot(body, "Back", Vector3(0, 1.12, 0) * s)
	back.set_meta("radii", Vector3(0.65, 0.55, 0.49) * s)
	root.set_meta("anim", anim)


# ---------- Части лица ----------

## Большие аниме-глаза на голове head (центр головы в нуле head, радиус hr): тёмный овал iris,
## крупный блик сверху и маленький снизу (two_hl). Без освещения и контура.
static func _eyes(rig: Rig, head: Node3D, hr: float, er: float, iris: Color, spread: float, lift: float,
		two_hl: bool) -> void:
	var im := _flat(iris)
	var hm := _flat(Color(1, 1, 1))
	for i in 2:
		var side := float(i * 2 - 1)
		var d := Vector3(spread * side, lift, -1.0).normalized()
		var c := d * hr * 0.93
		var e := _ball(rig, head, er, c, im, Vector3(0.8, 1.0, 0.45), true)
		_face(e, d)
		# Блики одинаковы для обоих глаз (свет с одной стороны), чуть впереди овала
		var h1 := _ball(rig, head, er * 0.34, c + d * er * 0.4 + Vector3(er * 0.25, er * 0.36, 0), hm, Vector3(1, 1, 0.5), true)
		_face(h1, d)
		if two_hl:
			var h2 := _ball(rig, head, er * 0.16, c + d * er * 0.42 + Vector3(-er * 0.25, -er * 0.38, 0), hm, Vector3(1, 1, 0.5), true)
			_face(h2, d)


## Розовый румянец на щеках. Непрозрачный: цвет заранее смешан с цветом головы under
## (раньше — полупрозрачный BLUSH поверх головы).
static func _blush(rig: Rig, head: Node3D, hr: float, br: float, under: Color) -> void:
	var bm := _lit(under.lerp(Color(BLUSH.r, BLUSH.g, BLUSH.b), BLUSH.a))
	for i in 2:
		var side := float(i * 2 - 1)
		var d := Vector3(0.78 * side, -0.2, -0.85).normalized()
		var b := _ball(rig, head, br, d * hr * 0.97, bm, Vector3(1.0, 0.55, 0.3), true, 10)
		_face(b, d)


# ---------- Шарниры и детали ----------

## Пустой узел (точка крепления, неподвижная относительно родителя).
static func _pivot(parent: Node3D, pname: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = pname
	n.position = pos
	parent.add_child(n)
	return n


## Подвижный узел-шарнир: становится костью скелета слитого меша. scaled — animate() меняет его масштаб.
static func _joint(rig: Rig, parent: Node3D, pname: String, pos: Vector3, scaled: bool = false) -> Node3D:
	var n := _pivot(parent, pname, pos)
	rig.bones.append(n)
	rig.scaled.append(scaled)
	return n


## Поворачивает деталь так, чтобы её -Z смотрел по направлению d.
static func _face(p: Part, d: Vector3) -> void:
	var dn := d.normalized()
	p.rotation = Vector3(asin(clampf(dn.y, -1.0, 1.0)), atan2(-dn.x, -dn.z), 0.0)


static func _lit(c: Color) -> Paint:
	return Paint.new(c, LIT)


## Краска без освещения: глаза, блики, узоры, светящиеся детали.
static func _flat(c: Color) -> Paint:
	return Paint.new(c, FLAT)


## Полупрозрачная краска без освещения (крылья), альфа — из цвета.
static func _glass(c: Color) -> Paint:
	return Paint.new(c, GLASS)


static func _part(rig: Rig, host: Node3D, prim: String, dims: PackedFloat32Array, pos: Vector3, paint: Paint,
		no_outline: bool) -> Part:
	var p := Part.new()
	p.host = host
	p.prim = prim
	p.dims = dims
	var k := prim
	for d in dims:
		k += "|%.4f" % d
	p.key = k
	p.position = pos
	p.color = paint.color
	p.kind = paint.kind
	p.outline = paint.kind == LIT and not no_outline
	rig.parts.append(p)
	return p


static func _ball(rig: Rig, parent: Node3D, radius: float, pos: Vector3, paint: Paint, sc: Vector3 = Vector3.ONE,
		no_outline: bool = false, seg: int = 12) -> Part:
	var p := _part(rig, parent, "s", PackedFloat32Array([radius, float(seg)]), pos, paint, no_outline)
	p.scale = sc
	return p


static func _capsule(rig: Rig, parent: Node3D, radius: float, h: float, pos: Vector3, paint: Paint) -> Part:
	return _part(rig, parent, "c", PackedFloat32Array([radius, h]), pos, paint, false)


## Цилиндр или конус (top = 0) вдоль оси Y.
static func _cyl(rig: Rig, parent: Node3D, top: float, bottom: float, h: float, pos: Vector3, paint: Paint,
		no_outline: bool = false) -> Part:
	return _part(rig, parent, "y", PackedFloat32Array([top, bottom, h]), pos, paint, no_outline)


static func _torus(rig: Rig, parent: Node3D, inner: float, outer: float, pos: Vector3, paint: Paint,
		no_outline: bool = false) -> Part:
	var p := _part(rig, parent, "t", PackedFloat32Array([inner, outer]), pos, paint, no_outline)
	p.radial = false
	return p


static func _box(rig: Rig, parent: Node3D, size: Vector3, pos: Vector3, paint: Paint, no_outline: bool = false) -> Part:
	return _part(rig, parent, "b", PackedFloat32Array([size.x, size.y, size.z]), pos, paint, no_outline)


## Массивы примитива детали (кэш по размерам).
static func _prim_arrays(p: Part) -> Array:
	if _prims.has(p.key):
		return _prims[p.key]
	var d := p.dims
	var pm: PrimitiveMesh
	match p.prim:
		"s":
			var sm := SphereMesh.new()
			var seg := int(d[1])
			sm.radius = d[0]
			sm.height = d[0] * 2.0
			sm.radial_segments = seg
			sm.rings = maxi(4, int(seg / 2.0))
			pm = sm
		"c":
			var cm := CapsuleMesh.new()
			cm.radius = d[0]
			cm.height = maxf(d[1], d[0] * 2.0)
			cm.radial_segments = 10
			cm.rings = 3
			pm = cm
		"y":
			var ym := CylinderMesh.new()
			ym.top_radius = d[0]
			ym.bottom_radius = d[1]
			ym.height = d[2]
			ym.radial_segments = 10
			ym.rings = 1
			ym.cap_top = d[0] > 0.0001
			pm = ym
		"t":
			var tm := TorusMesh.new()
			tm.inner_radius = d[0]
			tm.outer_radius = d[1]
			tm.rings = 20
			tm.ring_segments = 8
			pm = tm
		_:
			var bm := BoxMesh.new()
			bm.size = Vector3(d[0], d[1], d[2])
			pm = bm
	var arr := pm.get_mesh_arrays()
	_prims[p.key] = arr
	return arr


# ---------- Сборка слитого меша ----------

## Положение узла n относительно корня модели в позе покоя (у шарниров — сохранённая поза покоя).
static func _rest_global(n: Node3D, root: Node3D, memo: Dictionary) -> Transform3D:
	if n == root or n == null:
		return Transform3D.IDENTITY
	if memo.has(n):
		return memo[n]
	var local: Transform3D = n.get_meta("cm_rest", n.transform)
	var t := _rest_global(n.get_parent() as Node3D, root, memo) * local
	memo[n] = t
	return t


## Индекс кости ближайшего шарнира-предка узла n (включая сам n); 0 — корень модели.
static func _bone_of(n: Node, root: Node3D, idx: Dictionary) -> int:
	var cur := n
	while cur != null and cur != root:
		if idx.has(cur):
			return int(idx[cur])
		cur = cur.get_parent()
	return 0


static func _bone_index(rig: Rig) -> Dictionary:
	var idx := {}
	for i in rig.bones.size():
		idx[rig.bones[i]] = i
	return idx


## Сливает детали в ArrayMesh: поверхность непрозрачных деталей (материал тела назначается
## экземпляру) и поверхность полупрозрачных (общий материал). bone < 0 — все детали в системе
## координат модели, с костями (для скелета, плюс Skin); bone >= 0 — только детали этой кости
## в системе координат её узла (режим без скелета).
static func _bake(rig: Rig, root: Node3D, bone: int) -> Dictionary:
	var memo := {}
	var idx := _bone_index(rig)
	var solid := Acc.new()
	var glass := Acc.new()
	var inv := Transform3D.IDENTITY
	if bone >= 0:
		inv = _rest_global(rig.bones[bone] as Node3D, root, memo).affine_inverse()
	for item in rig.parts:
		var p := item as Part
		var b := _bone_of(p.host, root, idx)
		if bone >= 0 and b != bone:
			continue
		var m := inv * _rest_global(p.host, root, memo) * p.xform()
		var flags := Vector2(1.0 if p.kind == LIT else 0.0, 1.0 if p.outline else 0.0)
		var acc := glass if p.kind == GLASS else solid
		acc.add(_prim_arrays(p), m, p.color, flags, b if bone < 0 else -1, p.radial)
	var mesh := ArrayMesh.new()
	var opaque := -1
	if not solid.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, solid.arrays())
		opaque = mesh.get_surface_count() - 1
	if not glass.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, glass.arrays())
		mesh.surface_set_material(mesh.get_surface_count() - 1, _glass_mat())
	var g := {"mesh": mesh, "opaque": opaque, "glass_only": opaque < 0 and not glass.is_empty(),
		"count": mesh.get_surface_count()}
	if bone < 0:
		var skin := Skin.new()
		for i in rig.bones.size():
			skin.add_bind(i, _rest_global(rig.bones[i] as Node3D, root, memo).affine_inverse())
		g["skin"] = skin
	return g


static func _geo(rig: Rig, root: Node3D, bone: int) -> Dictionary:
	var key := "%s|%d" % [rig.key, bone]
	if _geo_cache.has(key):
		return _geo_cache[key]
	var g := _bake(rig, root, bone)
	_geo_cache[key] = g
	return g


## Собирает (или пересобирает после украшений) меш модели и скелет.
static func _finish(root: Node3D, rig: Rig, a: Dictionary) -> void:
	for b in rig.bones:
		var n := b as Node3D
		if n != root and not n.has_meta("cm_rest"):
			n.set_meta("cm_rest", n.transform)
	if skinned:
		_finish_skinned(root, rig, a)
	else:
		_finish_rigid(root, rig, a)


static func _finish_skinned(root: Node3D, rig: Rig, a: Dictionary) -> void:
	var g := _geo(rig, root, -1)
	if rig.skel == null:
		rig.skel = Skeleton3D.new()
		rig.skel.name = "Skeleton"
		root.add_child(rig.skel)
		rig.mi = MeshInstance3D.new()
		rig.mi.name = "Mesh"
		rig.mi.set_meta("no_outline", true)
		rig.mi.skeleton = NodePath("..")
		rig.skel.add_child(rig.mi)
	else:
		rig.skel.clear_bones()
	var skel := rig.skel
	var memo := {}
	var idx := _bone_index(rig)
	var n := rig.bones.size()
	var offs: Array = []
	offs.resize(n)
	var flags := PackedByteArray()
	flags.resize(n)
	for i in n:
		skel.add_bone("b%d" % i)
	offs[0] = Transform3D.IDENTITY
	flags[0] = 0
	for i in range(1, n):
		var node := rig.bones[i] as Node3D
		var parent := node.get_parent() as Node3D
		var pb := _bone_of(parent, root, idx)
		var off := _rest_global(rig.bones[pb] as Node3D, root, memo).affine_inverse() * _rest_global(parent, root, memo)
		skel.set_bone_parent(i, pb)
		var rest: Transform3D = node.get_meta("cm_rest")
		skel.set_bone_rest(i, off * rest)
		var f := 0
		if not off.is_equal_approx(Transform3D.IDENTITY):
			f |= 1
		if bool(rig.scaled[i]):
			f |= 2
		offs[i] = off
		flags[i] = f
	a["skel"] = skel
	a["bones"] = rig.bones
	a["offs"] = offs
	a["bflags"] = flags
	var mesh: ArrayMesh = g["mesh"]
	rig.mi.mesh = mesh
	var skin: Skin = g["skin"]
	rig.mi.skin = skin
	var opaque := int(g["opaque"])
	if opaque >= 0:
		rig.mi.set_surface_override_material(opaque, rig.mat)
	_sync(a)


static func _finish_rigid(root: Node3D, rig: Rig, a: Dictionary) -> void:
	a.erase("skel")
	for b in rig.bones.size():
		var g := _geo(rig, root, b)
		var mi: MeshInstance3D = rig.rigid.get(b)
		if int(g["count"]) == 0:
			if mi != null:
				mi.mesh = null
			continue
		if mi == null:
			mi = MeshInstance3D.new()
			mi.name = "Mesh"
			mi.set_meta("no_outline", true)
			(rig.bones[b] as Node3D).add_child(mi)
			rig.rigid[b] = mi
		var mesh: ArrayMesh = g["mesh"]
		mi.mesh = mesh
		var opaque := int(g["opaque"])
		if opaque >= 0:
			mi.set_surface_override_material(opaque, rig.mat)
		if bool(g["glass_only"]):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ---------- Материалы ----------

## Материал тела (свой у каждой модели — для вспышки), контур — если включён в настройках качества.
static func _body_mat() -> ShaderMaterial:
	if _body_shader == null:
		_body_shader = load(BODY_SHADER)
	var m := ShaderMaterial.new()
	m.shader = _body_shader
	m.set_shader_parameter("flash", 0.0)
	Quality.track_model(m, _outline_material())
	return m


static func _outline_material() -> ShaderMaterial:
	if _outline_m == null:
		_outline_m = ShaderMaterial.new()
		_outline_m.shader = load(OUTLINE_SHADER)
		_outline_m.set_shader_parameter("width", OUTLINE_WIDTH)
	return _outline_m


## Полупрозрачный неосвещаемый материал (крылья феи): цвет и прозрачность из вершин.
static func _glass_mat() -> StandardMaterial3D:
	if _glass_m == null:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.disable_receive_shadows = true
		m.set_meta("toon_done", true)
		_glass_m = m
	return _glass_m
