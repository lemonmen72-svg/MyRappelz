extends "res://tests/test_base.gd"
## Герои из Meshy с родным скелетом (tools/prepare_hero.py): каждый файл грузится через CharacterModel с полем
## asset, есть все клипы героя (каждое действие — свой основной клип, как у героини), кости кистей и головы по
## ролям из <модель>.json, оружие в руках, рост (мужчины ~1.8 м, женщины ~1.7 м), меш в бюджете, клипы на месте,
## шаг и бег включаются по скорости, поза покоя по костям — голова наверху, стопы у земли, кисти не выше головы.

const HEROES := [
	"res://assets/characters/hero_assassin_m.glb",
	"res://assets/characters/hero_swordsman_f.glb",
	"res://assets/characters/hero_warrior_m.glb",
	"res://assets/characters/hero_swordsman_m.glb",
]
## Клипы героя (имена в нижнем регистре): перенесённые из Quaternius UAL — как у героини, плюс шаг, бег и взмах рукой.
const CLIPS := ["idle", "walking", "running", "wave", "sword_idle", "sword_slash", "sword_attack", "sword_combo",
	"sword_heavy_combo", "sword_dash", "sword_block", "dodge", "hit", "death", "cast", "pickup", "sword_slash_b",
	"sword_slash_c", "crossbow_idle", "crossbow_shoot"]
const MAX_TRIS := 31000

var models: Array[CharacterModel] = []
var heroine: CharacterModel = null


func _spawn(path: String, weapon: String, x: float) -> CharacterModel:
	var spec := CharacterModel.spec_for("dark_elf", "assassin", weapon)
	spec["asset"] = path
	var m := CharacterModel.new()
	m.setup(spec)
	main.add_child(m)
	m.position = Vector3(x, 0.0, 30.0)
	return m


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
			heroine = _spawn(CharacterModel.MAIN_ASSET, "dual_swords", -8.0)
			for i in HEROES.size():
				var p := String(HEROES[i])
				check(ResourceLoader.exists(p), "%s: файл есть" % p)
				var w := "crossbow" if i == 3 else "dual_swords"
				models.append(_spawn(p, w, -5.0 + 2.5 * float(i)))
			for i in models.size():
				_check_model(models[i], String(HEROES[i]))
			for m in models:
				m.set_move_speed(1.4)
			wait = 30
			step = 1
		1:
			for i in models.size():
				var m := models[i]
				check(m._anim.current_animation == m._clip("walking"), "%s: на 1.4 м/с — шаг (%s)" % [
					HEROES[i], m._anim.current_animation])
				m.set_move_speed(6.5)
			wait = 30
			step = 2
		2:
			for i in models.size():
				var m := models[i]
				check(m._anim.current_animation == m._clip("running"), "%s: на 6.5 м/с — бег (%s)" % [
					HEROES[i], m._anim.current_animation])
				check(m._anim.speed_scale > 1.0, "%s: темп бега по скорости (%.2f)" % [HEROES[i], m._anim.speed_scale])
				m.set_move_speed(0.0)
			wait = 40
			step = 3
		3:
			for i in models.size():
				_check_pose(models[i], String(HEROES[i]))
				models[i].play_attack()
			wait = 4
			step = 4
		4:
			for i in models.size():
				var m := models[i]
				var kind: String = "shoot" if m.weapon_kind == "crossbow" else ["slash", "slash_b", "slash_c"][m._swing]
				var want: String = m._pick(CharacterModel.ASSET_ACTIONS[kind])[0]
				check(m._anim.current_animation == want, "%s: удар играет свой клип (%s)" % [HEROES[i],
					m._anim.current_animation])
			wait = 80
			step = 5
		5:
			for i in models.size():
				models[i].play_wave()
			wait = 5
			step = 6
		6:
			for i in models.size():
				var m := models[i]
				check(m._anim.current_animation == m._clip("wave"), "%s: машет рукой — клип Wave (%s)" % [HEROES[i],
					m._anim.current_animation])
				m.queue_free()
			heroine.queue_free()
			ok_done()


func _check_model(m: CharacterModel, who: String) -> void:
	check(m._asset != null, "%s: модель из файла загружена" % who)
	check(m._anim != null, "%s: есть проигрыватель анимаций" % who)
	if m._asset == null or m._anim == null:
		return
	# Все клипы героя
	for c in CLIPS:
		check(m._clips.has(c), "%s: есть клип «%s»" % [who, c])
	# У героини — те же клипы, что и у новых героев (кроме собственного взмаха рукой и шага/бега Meshy)
	for c in CLIPS:
		if c != "wave":
			check(heroine._clips.has(c), "героиня: есть клип «%s» (сверка)" % c)
	# Каждое действие — основной (первый) клип своего списка, как у героини
	for kind in CharacterModel.ASSET_ACTIONS:
		var opts: Array = CharacterModel.ASSET_ACTIONS[kind]
		var got := m._pick(opts)
		check(not got.is_empty() and String(got[0]) == m._clip(String(opts[0][0])),
			"%s: действие «%s» — клип %s" % [who, kind, String(opts[0][0])])
	check(String(m._pick(CharacterModel.ASSET_IDLE)[0]) == m._clip("idle"), "%s: покой — клип Idle" % who)
	for c in ["idle", "walking", "running", "crossbow_idle"]:
		check(m._anim.get_animation(m._clip(c)).loop_mode == Animation.LOOP_LINEAR, "%s: клип %s зациклен" % [who, c])
	# Роли костей из <модель>.json
	var rig := CharacterModel.asset_rig(who)
	check(not rig.is_empty(), "%s: есть роли костей (.json)" % who)
	var bones: Dictionary = rig.get("bones", {})
	var skel := _skel(m)
	check(skel != null, "%s: есть скелет" % who)
	if skel == null:
		return
	for role in ["root", "hips", "head", "hand_r", "hand_l", "foot_r", "foot_l"]:
		var bn := String(bones.get(role, ""))
		check(bn != "" and skel.find_bone(bn) >= 0, "%s: кость «%s» (%s) есть в скелете" % [who, role, bn])
	var grip := m.find_child("GripR", true, false) as BoneAttachment3D
	check(grip != null and grip.bone_name == String(bones.get("hand_r", "")), "%s: метка правой кисти на %s" % [
		who, String(bones.get("hand_r", ""))])
	check(m.find_child("Head", true, false) != null and m.find_child("Face", true, false) != null,
		"%s: метки головы и лица" % who)
	if m.weapon_kind == "crossbow":
		check(m.find_child("Crossbow", true, false) != null, "%s: арбалет в руках" % who)
	else:
		var gl := m.find_child("GripL", true, false) as BoneAttachment3D
		check(gl != null and gl.bone_name == String(bones.get("hand_l", "")), "%s: метка левой кисти" % who)
		check(m.find_child("Sword", true, false) != null and m.find_child("SwordL", true, false) != null,
			"%s: парные мечи в руках" % who)
	for k in ["grip_r", "grip_l"]:
		var g: Dictionary = rig.get(k, {})
		var d := CharacterModel._rig_vec(g, "dir", Vector3.ZERO)
		var p := CharacterModel._rig_vec(g, "pos", Vector3(9, 9, 9))
		check(absf(d.length() - 1.0) < 0.01 and p.length() < 0.15, "%s: хват %s (%s, %s)" % [who, k, p, d])
	# Рост и бюджет меша
	var female := who.get_file().get_basename().ends_with("_f")
	var lo := 1.65 if female else 1.75
	var hi := 1.75 if female else 1.85
	var tris := 0
	var h := 0.0
	for n in m._asset.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		h = maxf(h, mi.mesh.get_aabb().size.y)
		for s in mi.mesh.get_surface_count():
			tris += (mi.mesh as ArrayMesh).surface_get_array_index_len(s) / 3
		var mat := mi.material_override as StandardMaterial3D
		check(mat != null and mat.albedo_texture != null, "%s: toon-материал с текстурой" % who)
	check(h > lo and h < hi, "%s: рост %.2f м (%.2f…%.2f)" % [who, h, lo, hi])
	check(tris > 10000 and tris <= MAX_TRIS, "%s: треугольников %d (до %d)" % [who, tris, MAX_TRIS])
	# Клипы на месте: корень скелета по X/Z не уходит (рывок, кувырок)
	var root := String(bones.get("root", ""))
	for c in ["sword_dash", "dodge", "walking"]:
		var a := m._anim.get_animation(m._clip(c))
		var ok := true
		for t in a.get_track_count():
			if a.track_get_type(t) != Animation.TYPE_POSITION_3D:
				continue
			if String(a.track_get_path(t).get_concatenated_subnames()) != root:
				continue
			var k0: Vector3 = a.track_get_key_value(t, 0)
			for k in a.track_get_key_count(t):
				var v: Vector3 = a.track_get_key_value(t, k)
				if absf(v.x - k0.x) > 0.001 or absf(v.z - k0.z) > 0.001:
					ok = false
		check(ok, "%s: клип %s на месте (корень по X/Z не уходит)" % [who, c])
	print("  %s: рост %.2f м, треугольников %d, клипов %d, костей %d" % [who, h, tris, m._clips.size(),
		skel.get_bone_count()])


## Поза покоя по костям: голова на высоте человека, стопы у земли, кисти ниже головы.
func _check_pose(m: CharacterModel, who: String) -> void:
	var skel := _skel(m)
	if skel == null:
		return
	var bones: Dictionary = CharacterModel.asset_rig(who).get("bones", {})
	var head := _bone_y(m, skel, String(bones.get("head", "")))
	check(head > 1.3 and head < 1.75, "%s: голова в покое на %.2f м" % [who, head])
	for k in ["foot_l", "foot_r"]:
		var y := _bone_y(m, skel, String(bones.get(k, "")))
		check(y > 0.0 and y < 0.3, "%s: стопа %s у земли (%.2f м)" % [who, k, y])
	for k in ["hand_l", "hand_r"]:
		var y := _bone_y(m, skel, String(bones.get(k, "")))
		check(y > 0.5 and y < head + 0.15, "%s: кисть %s не выше головы (%.2f м)" % [who, k, y])
