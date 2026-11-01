class_name NpcProps
extends RefCounted
## Предметы жителей из файлов (решение Максима: персонажи Meshy — с пустыми руками, всё, что житель держит или носит,
## — отдельные модели assets/handheld/<id>.glb, их крепим к костям). Только у модели жителя из файла
## (CharacterModel с asset, npc_<id>.glb); у модели из примитивов — свои процедурные предметы.
##
## Контракт файла предмета (assets/handheld/handheld.json — его описание): точка хвата (у книги, свитка, ключей,
## колчана — точка, за которую держат или крепят) в начале координат, ось предмета «рукоять → верх» — +Y.
## Нет файла предмета — житель просто без него.
##
## Как ставится (ITEMS): роль кости — из npc_<id>.json (tools/prepare_hero.py).
##   * hand_r / hand_l — в кисть: точка хвата — центр кулака (grip_r / grip_l из .json), поворот задан в позе
##     первого кадра клипа Idle (прямая кинематика по трекам анимации): ось +Y предмета — вдоль up, +Z — к front
##     (пространство модели: +Y вверх, +Z — вперёд от лица, +X — влево от жителя). Дальше предмет движется с кистью
##     (взмах Wave, покой).
##   * hips / chest — на тело в позе покоя скелета: точка pos в пространстве модели (м; у каждого жителя своя —
##     по его мешу), поворот так же.
##   * ground — длинный предмет до земли (трость, посох): если нижний конец ушёл бы под землю, кисть «перехватывает»
##     его ниже — предмет сдвигается вдоль своей оси вверх (не дальше верхнего конца), нижний конец — у земли.

const DIR := "res://assets/handheld/"
## Запас над землёй нижнего конца предмета «до земли», м.
const GROUND_GAP := 0.03

## Житель → предметы. Кто что держит — по промтам Максима (tools/Промты_NPC.docx): Кирк — посох с зелёным камнем,
## мудрец — книга со звёздами, Ольвин — трость, Элиарна — жезл, Вейрис — свиток, кладовщик — учётная книга в левой
## руке и связка ключей на поясе, кузнец — молот, охотница — лук в левой руке и колчан за спиной. У торговца
## (рюкзак) и Корвена (меч в ножнах) файлов предметов пока нет.
const ITEMS := {
	"kirk": [
		{"item": "npc_antlerstaff", "at": "hand_r", "up": Vector3(0.06, 1.0, 0.05), "front": Vector3(0, 0, 1), "ground": true},
	],
	"sage": [
		{"item": "npc_grimoire", "at": "hand_l", "up": Vector3(0, 1.0, 0.1), "front": Vector3(1, 0, 0)},
	],
	"elder_human": [
		{"item": "npc_cane", "at": "hand_r", "up": Vector3(0.08, 1.0, 0.06), "front": Vector3(0, 0, 1), "ground": true},
	],
	"elder_light": [
		{"item": "npc_wand", "at": "hand_r", "up": Vector3(-0.1, -0.7, 0.7), "front": Vector3(-1, 0, 0)},
	],
	"elder_dark": [
		{"item": "npc_scroll", "at": "hand_r", "up": Vector3(0, 1.0, 0.15), "front": Vector3(-1, 0, 0)},
	],
	"storekeeper": [
		{"item": "npc_tome", "at": "hand_l", "up": Vector3(0, 1.0, 0.1), "front": Vector3(1, 0, 0)},
		{"item": "npc_keys", "at": "hips", "pos": Vector3(-0.225, 0.96, 0.02), "up": Vector3(0, 1.0, 0),
			"front": Vector3(-1, 0, 0)},
	],
	"smith": [
		{"item": "npc_hammer", "at": "hand_r", "up": Vector3(-0.15, -1.0, 0.12), "front": Vector3(-1, 0, 0)},
	],
	"hunter": [
		{"item": "npc_longbow", "at": "hand_l", "up": Vector3(0.04, 1.0, 0.08), "front": Vector3(-1, 0, 0)},
		{"item": "npc_quiver", "at": "chest", "pos": Vector3(-0.04, 1.08, -0.15), "up": Vector3(-0.4, 1.0, -0.12),
			"front": Vector3(0, 0, -1)},
	],
}


## Путь файла предмета.
static func item_path(item: String) -> String:
	return DIR + item + ".glb"


## Предметы жителя (записи ITEMS; нет — []).
static func items_of(npc_id: String) -> Array:
	return ITEMS.get(npc_id, [])


## Имя узла-метки предмета на кости (BoneAttachment3D): по нему предмет ищут тесты.
static func node_name(item: String) -> String:
	return "Prop_" + item


## Повесить предметы жителя npc_id на модель из файла. Возвращает число повешенных (файлов предметов может не быть).
static func attach(model: CharacterModel, npc_id: String) -> int:
	if model == null or model._asset == null or not ITEMS.has(npc_id):
		return 0
	var rig := CharacterModel.asset_rig(String(model.spec.get("asset", "")))
	var bones: Dictionary = rig.get("bones", {})
	var skels := model._asset.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return 0
	var skel := skels[0] as Skeleton3D
	var n := 0
	for e in ITEMS[npc_id]:
		var d: Dictionary = e
		var item := String(d["item"])
		var role := String(d["at"])
		var bi := skel.find_bone(String(bones.get(role, "")))
		if bi < 0:
			continue
		var node := load_item(item)
		if node == null:
			continue
		var hand := role == "hand_r" or role == "hand_l"
		var ref: Transform3D = idle_pose(model, skel, bi) if hand else skel.get_bone_global_rest(bi)
		var origin := ref.origin
		if hand:
			var g: Dictionary = rig.get("grip_r" if role == "hand_r" else "grip_l", {})
			origin = ref * CharacterModel._rig_vec(g, "pos", Vector3.ZERO)
		elif d.has("pos"):
			origin = d["pos"]
		var up: Vector3 = d.get("up", Vector3.UP)
		var front: Vector3 = d.get("front", Vector3.BACK)
		if bool(d.get("ground", false)):
			origin += ground_shift(node, origin.y, up)
		var att := BoneAttachment3D.new()
		att.name = node_name(item)
		att.bone_name = skel.get_bone_name(bi)
		skel.add_child(att)
		att.transform = skel.get_bone_global_pose(bi)
		node.name = "Item"
		node.transform = ref.affine_inverse() * Transform3D(basis_of(up, front), origin)
		att.add_child(node)
		n += 1
	return n


## Модель предмета из файла (нет файла — null): свой toon-материал, как у модели жителя (текстура — <id>.png рядом
## или из материала файла), без самозатенения и с контуром по настройкам (Quality.track_model).
static func load_item(item: String) -> Node3D:
	var path := item_path(item)
	if not Assets.exists(path):
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var inst := ps.instantiate() as Node3D
	if inst == null:
		return null
	var tex: Texture2D = null
	var tp := DIR + item + ".png"
	if Assets.exists(tp):
		tex = load(tp) as Texture2D
	for c in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		mi.set_meta("no_toon", true)
		var t := tex
		var col := Color.WHITE
		if mi.mesh != null and mi.mesh.get_surface_count() > 0:
			var sm := mi.mesh.surface_get_material(0) as StandardMaterial3D
			if sm != null:
				if t == null:
					t = sm.albedo_texture
				if t == null:
					col = sm.albedo_color
		var m := StandardMaterial3D.new()
		m.metallic = 0.0
		m.albedo_color = col
		m.emission_enabled = true
		m.emission = Color.BLACK
		if t != null:
			m.albedo_texture = t
			m.emission_texture = t
			m.emission_energy_multiplier = CharacterModel.ASSET_GLOW
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		Util.toon(m)
		Quality.track_model(m, CharacterModel._asset_outline_mat())
		m.set_meta("toon_done", true)
		mi.material_override = m
	return inst


## Поза кости в пространстве скелета в первом кадре клипа Idle (прямая кинематика по трекам; кость без трека —
## поза покоя). Клипа нет — поза покоя скелета.
static func idle_pose(model: CharacterModel, skel: Skeleton3D, bone: int) -> Transform3D:
	var a: Animation = null
	if model._anim != null:
		var clip := model._clip("idle")
		if clip != "":
			a = model._anim.get_animation(clip)
	var pos_t := {}
	var rot_t := {}
	if a != null:
		for t in a.get_track_count():
			var bn := String(a.track_get_path(t).get_concatenated_subnames())
			match a.track_get_type(t):
				Animation.TYPE_POSITION_3D:
					pos_t[bn] = t
				Animation.TYPE_ROTATION_3D:
					rot_t[bn] = t
	var chain: Array[int] = []
	var b := bone
	while b >= 0:
		chain.push_front(b)
		b = skel.get_bone_parent(b)
	var xf := Transform3D.IDENTITY
	for c in chain:
		var rest := skel.get_bone_rest(c)
		var p := rest.origin
		var q := rest.basis.get_rotation_quaternion()
		var nm := skel.get_bone_name(c)
		if a != null and pos_t.has(nm):
			p = a.position_track_interpolate(int(pos_t[nm]), 0.0)
		if a != null and rot_t.has(nm):
			q = a.rotation_track_interpolate(int(rot_t[nm]), 0.0)
		xf = xf * Transform3D(Basis(q) * Basis.from_scale(rest.basis.get_scale()), p)
	return xf


## Базис: ось +Y — вдоль up, +Z — к front (ортогонализуется к up).
static func basis_of(up: Vector3, front: Vector3) -> Basis:
	var y := up.normalized()
	var z := front - y * y.dot(front)
	if z.length() < 0.01:
		z = Vector3.BACK - y * y.z
	z = z.normalized()
	return Basis(y.cross(z), y, z)


## Сдвиг длинного предмета «до земли» вдоль его оси up: хват на высоте grip_y, нижний конец (по рамке меша
## предмета) — не ниже GROUND_GAP над землёй; кисть остаётся на предмете (сдвиг не больше его части выше хвата).
static func ground_shift(item: Node3D, grip_y: float, up: Vector3) -> Vector3:
	var box := item_bounds(item)
	var below := -box.position.y
	var above := box.end.y
	var u := up.normalized()
	if below <= 0.0 or u.y < 0.3:
		return Vector3.ZERO
	var shift := below - (grip_y - GROUND_GAP) / u.y
	if shift <= 0.0:
		return Vector3.ZERO
	return u * minf(shift, maxf(0.0, above - 0.05))


## Рамка мешей предмета в его собственном пространстве (до установки на кость).
static func item_bounds(item: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for c in item.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != null and n != item:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var bb := xf * mi.mesh.get_aabb()
		box = bb if first else box.merge(bb)
		first = false
	return box
