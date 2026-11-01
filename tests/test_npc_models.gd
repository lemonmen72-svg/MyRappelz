extends "res://tests/test_base.gd"
## Жители из Meshy с родным скелетом (tools/prepare_npcs.py → tools/prepare_hero.py): у каждого жителя NpcData есть
## npc_<id>.glb, CharacterModel.npc_spec грузит его (без оружия в руках), есть клипы Idle и Wave (и шаг, бег, жесты
## героя), покой зациклен, кости по ролям из npc_<id>.json, рост по tools/prepare_npcs.py (мужчины ~1.8 м,
## женщины ~1.7 м), меш в бюджете, ноги на земле, поза покоя — голова наверху, стопы у земли. Предметы (NpcProps):
## есть файл assets/handheld/<id>.glb — висит на своей кости (кисть, таз, грудь), у кисти, длинный предмет не уходит
## под землю; нет файла — житель без предмета. Без пакета ресурсов — модели из примитивов. Житель в мире с моделью
## из файла машет рукой (клип Wave), когда герой подходит и когда с ним заговорили, и поворачивается к герою.

## Житель → [пол, рост меша, м] — как NPCS в tools/prepare_npcs.py.
const NPCS := {
	"merchant": ["m", 1.80], "kirk": ["m", 1.74], "sage": ["m", 1.72], "smith": ["m", 1.86],
	"storekeeper": ["m", 1.72], "elder_human": ["m", 1.76], "elder_light": ["f", 1.74], "elder_dark": ["f", 1.80],
	"hunter": ["f", 1.68], "merc_chief": ["m", 1.82],
	"weaponsmith": ["m", 1.84], "armorer": ["f", 1.74], "jeweler": ["f", 1.70],
}
## Клипы жителя (нижний регистр): покой и приветствие обязательны, остальные — общий набор героя.
const CLIPS := ["idle", "wave", "walking", "running", "hit", "cast", "pickup"]
## Меш жителя: до 50 тыс. (tools/prepare_npcs.py NPC_TRIS), у большинства исходник целиком (~31 тыс.).
const MAX_TRIS := 52000

var ids: Array = []
var models: Array[CharacterModel] = []
var walker: Npc = null


func race_class() -> Array:
	return ["human", "warrior"]


func _skel(m: CharacterModel) -> Skeleton3D:
	if m._asset == null:
		return null
	var s := m._asset.find_children("*", "Skeleton3D", true, false)
	return null if s.is_empty() else s[0] as Skeleton3D


func _bone_y(m: CharacterModel, skel: Skeleton3D, bone: String) -> float:
	var i := skel.find_bone(bone)
	if i < 0:
		return -100.0
	return (skel.global_transform * skel.get_bone_global_pose(i).origin).y - m.global_position.y


func run_step() -> void:
	match step:
		0:
			for k in NpcData.NPCS:
				check(NPCS.has(String(k)), "у жителя %s есть модель из файла (список NPCS)" % k)
			ids = NPCS.keys()
			for i in ids.size():
				var id := String(ids[i])
				var path := CharacterModel.npc_asset(id)
				check(ResourceLoader.exists(path), "%s: файл %s есть" % [id, path])
				var spec := CharacterModel.npc_spec(id)
				check(String(spec.get("asset", "")) == path and String(spec.get("weapon", "?")) == "",
					"%s: npc_spec — модель из файла, без оружия" % id)
				var m := CharacterModel.new()
				m.setup(spec)
				main.add_child(m)
				m.position = Vector3(-10.0 + 2.2 * float(i), 0.0, 40.0)
				NpcProps.attach(m, id)
				models.append(m)
				_check_model(m, id)
			wait = 40
			step = 1
		1:
			for i in models.size():
				_check_pose(models[i], String(ids[i]))
				_check_props(models[i], String(ids[i]))
				models[i].play_wave()
			wait = 5
			step = 2
		2:
			for i in models.size():
				var m := models[i]
				check(m._anim.current_animation == m._clip("wave"), "%s: машет рукой — клип Wave (%s)" % [ids[i],
					m._anim.current_animation])
				m.queue_free()
			models.clear()
			_check_fallback()
			# Житель в мире рядом с героем: подходит — машет, поворачивается к нему
			var p: Player = main.player
			walker = Npc.new()
			walker.npc_id = "smith"
			walker.face_yaw = -PI * 0.5
			main.add_child(walker)
			walker.global_position = p.global_position + Vector3(3.0, 0.0, 0.0)
			wait = 6
			step = 3
		3:
			var m := walker._model
			check(m._asset != null, "житель в мире — модель из файла")
			check(m._anim != null and m._anim.current_animation == m._clip("wave"),
				"герой подошёл — житель машет (%s)" % (m._anim.current_animation if m._anim != null else ""))
			wait = 150
			step = 4
		4:
			var m := walker._model
			var to: Vector3 = main.player.global_position - walker.global_position
			var want := atan2(-to.x, -to.z)
			check(absf(angle_difference(m.rotation.y, want)) < 0.2, "житель повернулся к герою (%.2f / %.2f)" % [
				m.rotation.y, want])
			check(m._anim.current_animation == m._clip("idle"), "после взмаха — покой (%s)" % m._anim.current_animation)
			# Разговор: машет снова (Npcs.open_dialog → greet), но не перебивает свой же взмах
			walker._wave_cd = 0.0
			walker.greet()
			check(m._anim.current_animation == m._clip("wave"), "в разговоре житель машет рукой")
			var cd := walker._wave_cd
			walker.greet()
			check(walker._wave_cd == cd, "второй раз подряд не машет")
			walker.queue_free()
			ok_done()


func _check_model(m: CharacterModel, id: String) -> void:
	check(m._asset != null, "%s: модель из файла загружена" % id)
	check(m._anim != null, "%s: есть проигрыватель анимаций" % id)
	if m._asset == null or m._anim == null:
		return
	for c in CLIPS:
		check(m._clips.has(c), "%s: есть клип «%s»" % [id, c])
	check(String(m._pick(CharacterModel.ASSET_IDLE)[0]) == m._clip("idle"), "%s: покой — клип Idle" % id)
	check(String(m._pick(CharacterModel.ASSET_ACTIONS["wave"])[0]) == m._clip("wave"), "%s: взмах — клип Wave" % id)
	check(m._anim.get_animation(m._clip("idle")).loop_mode == Animation.LOOP_LINEAR, "%s: покой зациклен" % id)
	check(m.find_child("Sword", true, false) == null and m.find_child("Staff", true, false) == null,
		"%s: без оружия героя в руках" % id)
	var path := CharacterModel.npc_asset(id)
	var rig := CharacterModel.asset_rig(path)
	check(not rig.is_empty(), "%s: есть роли костей (npc_%s.json)" % [id, id])
	var bones: Dictionary = rig.get("bones", {})
	var skel := _skel(m)
	check(skel != null, "%s: есть скелет" % id)
	if skel == null:
		return
	for role in ["root", "hips", "chest", "head", "hand_r", "hand_l", "foot_r", "foot_l"]:
		var bn := String(bones.get(role, ""))
		check(bn != "" and skel.find_bone(bn) >= 0, "%s: кость «%s» (%s) есть в скелете" % [id, role, bn])
	check(m.find_child("Head", true, false) != null and m.find_child("Face", true, false) != null,
		"%s: метки головы и лица" % id)
	var e: Array = NPCS[id]
	var want := float(e[1])
	var female := String(e[0]) == "f"
	var tris := 0
	var h := 0.0
	var low := 100.0
	for n in m._asset.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or _on_bone(mi, m._asset):
			continue
		var bb := mi.mesh.get_aabb()
		h = maxf(h, bb.size.y)
		low = minf(low, bb.position.y)
		for s in mi.mesh.get_surface_count():
			tris += (mi.mesh as ArrayMesh).surface_get_array_index_len(s) / 3
		var mat := mi.material_override as StandardMaterial3D
		check(mat != null and mat.albedo_texture != null, "%s: toon-материал с текстурой" % id)
	check(absf(h - want) < 0.03, "%s: рост %.2f м (ждём %.2f)" % [id, h, want])
	check(h > (1.6 if female else 1.68) and h < (1.84 if female else 1.9), "%s: рост по полу (%.2f м)" % [id, h])
	check(absf(low) < 0.02, "%s: ноги на земле (низ меша %.3f м)" % [id, low])
	check(tris > 10000 and tris <= MAX_TRIS, "%s: треугольников %d (до %d)" % [id, tris, MAX_TRIS])
	print("  %s: рост %.2f м, треугольников %d, клипов %d" % [id, h, tris, m._clips.size()])


## Поза покоя (Idle) по костям: голова на высоте человека, стопы у земли, кисти ниже головы.
func _check_pose(m: CharacterModel, id: String) -> void:
	var skel := _skel(m)
	if skel == null:
		return
	var bones: Dictionary = CharacterModel.asset_rig(CharacterModel.npc_asset(id)).get("bones", {})
	var head := _bone_y(m, skel, String(bones.get("head", "")))
	check(head > 1.25 and head < 1.8, "%s: голова в покое на %.2f м" % [id, head])
	for k in ["foot_l", "foot_r"]:
		var y := _bone_y(m, skel, String(bones.get(k, "")))
		check(y > -0.02 and y < 0.3, "%s: стопа %s у земли (%.2f м)" % [id, k, y])
	for k in ["hand_l", "hand_r"]:
		var y := _bone_y(m, skel, String(bones.get(k, "")))
		check(y > 0.5 and y < head, "%s: кисть %s опущена (%.2f м)" % [id, k, y])


## Предметы NpcProps: файл есть — на своей кости, рядом с ней, не под землёй; нет файла — предмета нет.
func _check_props(m: CharacterModel, id: String) -> void:
	var bones: Dictionary = CharacterModel.asset_rig(CharacterModel.npc_asset(id)).get("bones", {})
	var skel := _skel(m)
	for e in NpcProps.items_of(id):
		var d: Dictionary = e
		var item := String(d["item"])
		var role := String(d["at"])
		var att := m.find_child(NpcProps.node_name(item), true, false) as BoneAttachment3D
		if not ResourceLoader.exists(NpcProps.item_path(item)):
			check(att == null, "%s: файла %s нет — предмета нет" % [id, item])
			continue
		check(att != null, "%s: %s на модели" % [id, item])
		if att == null or skel == null:
			continue
		check(att.bone_name == String(bones.get(role, "")), "%s: %s на кости «%s» (%s)" % [id, item, role, att.bone_name])
		var node := att.get_node_or_null("Item") as Node3D
		check(node != null, "%s: %s — модель предмета" % [id, item])
		if node == null:
			continue
		var bi := skel.find_bone(att.bone_name)
		var bone_p := skel.global_transform * skel.get_bone_global_pose(bi).origin
		var dist := node.global_position.distance_to(bone_p)
		if bool(d.get("ground", false)):
			# Трость, посох: кисть перехватывает ниже — у кисти ось предмета, а не точка хвата
			var ax := node.global_transform.basis.y.normalized()
			var v := bone_p - node.global_position
			dist = (v - ax * v.dot(ax)).length()
		var near := 0.2 if role.begins_with("hand") else 0.45
		check(dist < near, "%s: %s у кости (%.2f м)" % [id, item, dist])
		var low := 100.0
		for c in node.find_children("*", "MeshInstance3D", true, false):
			var mi := c as MeshInstance3D
			if mi.mesh != null:
				low = minf(low, (mi.global_transform * mi.mesh.get_aabb()).position.y)
		check(low - m.global_position.y > -0.06, "%s: %s не под землёй (низ %.2f м)" % [id, item,
			low - m.global_position.y])


## Без пакета ресурсов — модели из примитивов; у модели из примитивов NpcProps ничего не вешает.
func _check_fallback() -> void:
	Assets.simulate_missing(true)
	for k in NPCS:
		var spec := CharacterModel.npc_spec(String(k))
		check(not spec.has("asset"), "%s: без пакета — модель из примитивов" % k)
	var m := CharacterModel.new()
	m.setup(CharacterModel.npc_spec("hunter"))
	main.add_child(m)
	check(m._asset == null and NpcProps.attach(m, "hunter") == 0, "модель из примитивов — без предметов из файлов")
	m.queue_free()
	Assets.simulate_missing(false)


func _on_bone(n: Node, top: Node) -> bool:
	var p := n.get_parent()
	while p != null and p != top:
		if p is BoneAttachment3D:
			return true
		p = p.get_parent()
	return false
