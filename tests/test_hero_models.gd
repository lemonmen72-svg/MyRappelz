extends "res://tests/test_base.gd"
## Герои из Meshy с родным скелетом (tools/prepare_hero.py): каждый файл грузится через CharacterModel с полем
## asset, есть все клипы героя (каждое действие — свой основной клип, как у героини), кости кистей и головы по
## ролям из <модель>.json, оружие в руках, рост (мужчины ~1.8 м, женщины ~1.7 м), меш в бюджете, клипы на месте,
## шаг и бег включаются по скорости, поза покоя по костям — голова наверху, стопы у земли, кисти не выше головы.
## Женская пластика (tools/prepare_hero.py, FEM_STYLES): у героинь таз в шаге и беге вращается вокруг вертикали
## заметно сильнее, чем у героев, — по трекам анимации, без графики.
## Плечи (_check_shoulders): плечевые суставы в покое, стойках, шаге и беге не позади шеи больше SHOULDER_BACK — как у
## исходной модели Meshy (0…−1 см); до исправления ключиц в клипах UAL было −5…−7 см («плечи за головой»).
## Бег (_check_loco): носок в переносе не выше RUN_LIFT_MAX роста, колено ниже таза, при 7 м/с не чаще RUN_CADENCE_MAX
## шагов в секунду (бег спринтера манекена с темпом ×1.2–1.3 поднимал ноги «как по воде»).

const HEROES := [
	"res://assets/characters/hero_assassin_m.glb",
	"res://assets/characters/hero_swordsman_f.glb",
	"res://assets/characters/hero_warrior_m.glb",
	"res://assets/characters/hero_swordsman_m.glb",
	"res://assets/characters/hero_assassin_f.glb",
	"res://assets/characters/hero_warrior_f.glb",
	"res://assets/characters/hero_human_m_starter.glb",
	"res://assets/characters/hero_human_f_starter.glb",
	"res://assets/characters/hero_dark_elf_m_starter.glb",
	"res://assets/characters/hero_dark_elf_f_starter.glb",
	"res://assets/characters/hero_light_elf_m_starter.glb",
	"res://assets/characters/hero_light_elf_f_starter.glb",
	"res://assets/characters/hero_neophyte_m.glb",
	"res://assets/characters/hero_neophyte_f.glb",
	"res://assets/characters/hero_adept_m.glb",
	"res://assets/characters/hero_adept_f.glb",
	"res://assets/characters/hero_wizard_m.glb",
	"res://assets/characters/hero_wizard_f.glb",
	"res://assets/characters/hero_beastmaster_m.glb",
	"res://assets/characters/hero_beastmaster_f.glb",
	"res://assets/characters/hero_shaman_m.glb",
	"res://assets/characters/hero_shaman_f.glb",
	"res://assets/characters/hero_conjurer_m.glb",
	"res://assets/characters/hero_conjurer_f.glb",
]
## Клипы героя (имена в нижнем регистре): перенесённые из Quaternius UAL — как у героини, плюс шаг, бег и взмах рукой.
const CLIPS := ["idle", "walking", "running", "wave", "sword_idle", "sword_slash", "sword_attack", "sword_combo",
	"sword_heavy_combo", "sword_dash", "sword_block", "dodge", "hit", "death", "cast", "pickup", "sword_slash_b",
	"sword_slash_c", "crossbow_idle", "crossbow_shoot"]
## Меш героя: 70 тыс. треугольников (tools/prepare_hero.py TRIS), дальние — LOD Godot.
const MIN_TRIS := 50000
const MAX_TRIS := 80000
## Плечевой сустав (среднее левого и правого за клип) позади основания шеи не дальше, м. Клипы — покой, стойки, шаг, бег.
## После исправления ключиц у 24 героев худшее — 4.1–4.2 см (Sword_Idle у hero_light_elf_m_starter и
## hero_beastmaster_m: стойка UAL наклоняет корпус вперёд), обычно 1–3 см; до исправления Idle, Crossbow_Idle и
## Walking UAL — 6.2–7.7 см.
const SHOULDER_BACK := 0.05
const SHOULDER_CLIPS := ["idle", "sword_idle", "crossbow_idle", "walking", "mq_walking", "mq_running", "mq_cast_hold"]
## Бег Mq_Running: носок в переносе над своей высотой в покое — не выше доли роста (у манекена 0.47–0.50, у героев
## после tools/retarget_mannequin.py MQ_LIFT ≈ 0.3), колено ниже тазобедренного сустава хотя бы на долю роста (у
## манекена — почти вровень), шагов в секунду при 7 м/с (скорость героя) не больше.
const RUN_LIFT_MAX := 0.38
const RUN_KNEE_MIN := 0.05
const RUN_CADENCE_MAX := 3.6
## Движения манекенов Meshy (tools/retarget_mannequin.py, MQ_CLIPS): у каждого героя все, в .json — длина и удар.
const MQ_CLIPS := ["mq_sword_a1", "mq_sword_a2", "mq_sword_a3", "mq_combo_b1", "mq_combo_b2", "mq_combo_b3",
	"mq_dual_a1", "mq_dual_a2", "mq_left_slash", "mq_thrust", "mq_heavy_swing", "mq_axe_spin", "mq_axe_chop",
	"mq_charged_slash", "mq_judgment", "mq_leap_slam", "mq_blade_spin", "mq_reap", "mq_ground_slam", "mq_kick",
	"mq_jump", "mq_bow_shot", "mq_bow_draw", "mq_reload", "mq_cast_a", "mq_cast_b", "mq_cast_c", "mq_cast_wide",
	"mq_cast_slam", "mq_cast_beam", "mq_cast_up", "mq_cast_pray", "mq_charged_cast", "mq_charged_cast1", "mq_taunt",
	"mq_hit", "mq_death", "mq_pickup", "mq_walking", "mq_running", "mq_cast_release", "mq_charge_release",
	"mq_cast_hold", "mq_charge_hold", "mq_bow_aim_hold", "mq_crossbow_aim_hold",
	"mq_thrust_b", "mq_blade_spin_b", "mq_bow_draw_b", "mq_bow_draw_c", "mq_bow_draw_d", "mq_pickup_b", "mq_guard",
	"mq_rise", "mq_bow_scan_hold", "mq_crouch_charge_hold", "mq_turn_l90", "mq_turn_r90", "mq_turn_l180",
	"mq_running_b", "mq_sprint"]
## Петли каста умений героя (CharacterModel.MQ_CAST_LOOPS, MQ_CAST_ALT): зацикленные, первый и последний кадр совпадают.
const MQ_LOOPS := ["mq_cast_hold", "mq_charge_hold", "mq_bow_aim_hold", "mq_crossbow_aim_hold", "mq_bow_scan_hold",
	"mq_crouch_charge_hold"]
## Шаг и бег манекенов (CharacterModel.MQ_LOCO): [клип, ход таза по высоте за цикл до, м; длина шага от, до, м].
## Своя скорость — clips.<имя>.speed в .json.
const MQ_LOCO := [["mq_walking", 0.09, 0.5, 1.1], ["mq_running_b", 0.12, 0.9, 1.5],
	["mq_running", 0.08, 1.7, 2.4], ["mq_sprint", 0.08, 1.4, 2.6]]
## Опорная стопа (носок у земли) едет назад со скоростью клипа: отклонение не больше, м.
const MQ_LOCO_SLIDE := 0.04
## Повороты на месте: угол корпуса за клип (clips.<имя>.turn, °) по модулю не меньше.
const MQ_TURNS := ["mq_turn_l90", "mq_turn_r90", "mq_turn_l180"]
const MQ_TURN_MIN_DEG := 60.0
## Длина клипа обычной атаки при темпе 1 (игра ускоряет до MQ_SPEED_MAX под интервал атаки), умений и прочих, с.
const MQ_ATTACK_MAX := 1.25
const MQ_ACT_MAX := 2.8
## Опора стопы (носок, 4-я кость ноги) у земли (не выше своей высоты в покое + 4 см) едет по земле не дальше, м
## (как ground_slide в tools/retarget_mannequin.py; поворот на носке — не скольжение).
const MQ_GROUND_SLIDE := 0.08

var models: Array[CharacterModel] = []
var heroine: CharacterModel = null
## Родитель модели для проверки поворота на месте (поворачивается, как герой).
var _pivot: Node3D = null


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
				models.append(_spawn(p, w, -5.0 + 2.0 * float(i)))
			for i in models.size():
				_check_model(models[i], String(HEROES[i]))
			_check_gait()
			for m in models:
				m.set_move_speed(1.4)
			wait = 30
			step = 1
		1:
			# Шаг — движение манекена
			for i in models.size():
				var m := models[i]
				check(m._anim.current_animation.to_lower() == "mq_walking" and m.loco_clip() != "", "%s: на 1.4 м/с — шаг Mq_Walking (%s)" % [
					HEROES[i], m._anim.current_animation])
				m.set_move_speed(6.5)
			wait = 30
			step = 2
		2:
			# Бег — Mq_Running, темп = скорость / своя скорость клипа (стопа не скользит)
			for i in models.size():
				var m := models[i]
				check(m._anim.current_animation.to_lower() == "mq_running", "%s: на 6.5 м/с — бег Mq_Running (%s)" % [
					HEROES[i], m._anim.current_animation])
				var v := float(CharacterModel.asset_rig(HEROES[i]).get("clips", {}).get(m._anim.current_animation, {}).get("speed", 0.0))
				check(v > 0.0 and absf(m._anim.speed_scale - m._asset_speed / v) < 0.02,
					"%s: темп бега %.2f = скорость / %.2f м/с" % [HEROES[i], m._anim.speed_scale, v])
				m.set_move_speed(3.6)
			wait = 20
			step = 20
		20:
			# Трусца между шагом и бегом (порог с запасом: с бега вниз — ниже 4.6 × 0.92)
			for i in models.size():
				var m := models[i]
				check(m._anim.current_animation.to_lower() == "mq_running_b", "%s: на 3.6 м/с — трусца (%s)" % [
					HEROES[i], m._anim.current_animation])
				# Чуть выше порога бега, но в пределах запаса — вид держится
				m.set_move_speed(4.8)
			wait = 20
			step = 21
		21:
			for i in models.size():
				var m := models[i]
				check(m._anim.current_animation.to_lower() == "mq_running_b", "%s: 4.8 м/с — в запасе порога, трусца держится (%s)" % [
					HEROES[i], m._anim.current_animation])
				m.set_move_speed(10.0)
			wait = 20
			step = 22
		22:
			for i in models.size():
				var m := models[i]
				check(m._anim.current_animation.to_lower() == "mq_sprint", "%s: на 10 м/с — быстрый бег (%s)" % [
					HEROES[i], m._anim.current_animation])
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
			# Обычная атака — движение манекена Meshy по хвату (первая часть комбо), арбалет — выстрел UAL
			for i in models.size():
				var m := models[i]
				var want := _mq_attack_clip(m, 0)
				if m.weapon_kind == "crossbow":
					want = String(m._pick(CharacterModel.ASSET_ACTIONS["shoot"])[0])
				check(want != "" and m._anim.current_animation == want, "%s: удар играет свой клип (%s, ждём %s)" % [
					HEROES[i], m._anim.current_animation, want])
				if m.weapon_kind != "crossbow":
					# Следующая атака — следующая часть комбо, темп под интервал 0.8 с
					m.play_attack(0.8)
			wait = 3
			step = 40
		40:
			for i in models.size():
				var m := models[i]
				if m.weapon_kind == "crossbow":
					continue
				var want := _mq_attack_clip(m, 1)
				check(m._anim.current_animation == want, "%s: вторая атака — следующая часть комбо (%s, ждём %s)" % [
					HEROES[i], m._anim.current_animation, want])
				var sp := m._anim.get_playing_speed()
				check(sp >= CharacterModel.MQ_SPEED_MIN - 0.01 and sp <= CharacterModel.MQ_SPEED_MAX + 0.01,
					"%s: темп атаки %.2f под интервал" % [HEROES[i], sp])
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
				# Умение «Вызов» — своё движение (удар в грудь)
				check(m.play_skill("buff", "challenge", "near"), "%s: умение играет движение манекена" % HEROES[i])
			wait = 3
			step = 7
		7:
			for i in models.size():
				var m := models[i]
				var taunt := String(m._clips.get(String(CharacterModel.MQ_SKILL_BY_ID["challenge"]), ""))
				check(taunt != "" and m._anim.current_animation == taunt, "%s: «Вызов» — клип %s (%s)" % [HEROES[i],
					taunt, m._anim.current_animation])
				# Заклинание на цель — один из клипов MQ_CASTS
				m.play_skill("cast", "fire_spark", "magic")
			wait = 3
			step = 8
		8:
			for i in models.size():
				var m := models[i]
				var cur := m._anim.current_animation.to_lower()
				check(CharacterModel.MQ_CASTS.has(cur), "%s: заклинание — клип манекена (%s)" % [HEROES[i], cur])
				# Каст умения: петля накопления силы, пока не снята
				check(m.play_cast_loop("magic"), "%s: петля каста магии есть" % HEROES[i])
			wait = 120
			step = 9
		9:
			for i in models.size():
				var m := models[i]
				var cur := m._anim.current_animation.to_lower()
				check(cur == "mq_cast_hold" and m._anim.is_playing(), "%s: через 2 с петля каста ещё играет (%s)" % [HEROES[i], cur])
				m.stop_cast_loop()
				# Выпуск после каста: клип умения с момента незадолго до удара
				m.play_skill("cast", "fire_spark", "magic", true)
				var cn := m._anim.current_animation
				var hit := float(CharacterModel.asset_rig(String(m.spec.get("asset", ""))).get("clips", {}).get(cn, {}).get("hit", 0.0))
				check(absf(m._anim.current_animation_position - maxf(0.0, hit - CharacterModel.MQ_RELEASE_LEAD)) < 0.05,
					"%s: выпуск — %s с %.2f с (удар %.2f)" % [HEROES[i], cn, m._anim.current_animation_position, hit])
			wait = 90
			step = 10
		10:
			for i in models.size():
				var m := models[i]
				var idle := m._pick(CharacterModel.ASSET_IDLE_CROSSBOW if m.weapon_kind == "crossbow" else CharacterModel.ASSET_IDLE)
				check(not idle.is_empty() and m._anim.current_animation == String(idle[0]), "%s: после выпуска — покой (%s)" % [
					HEROES[i], m._anim.current_animation])
			# Поворот на месте: герой (родитель) развернулся на 100° влево — модель сначала смотрит по-старому и
			# переступает клипом поворота
			_pivot = Node3D.new()
			main.add_child(_pivot)
			_pivot.global_position = models[0].global_position
			models[0].reparent(_pivot)
			models[0].turn_in_place = true
			wait = 3
			step = 11
		11:
			_pivot.rotation.y = deg_to_rad(100.0)
			wait = 4
			step = 12
		12:
			var m := models[0]
			var cur := m._anim.current_animation.to_lower()
			check(CharacterModel.MQ_TURNS.has(cur), "%s: развернули стоя — клип поворота (%s)" % [HEROES[0], cur])
			check(absf(m.rotation.y + deg_to_rad(100.0)) < 0.35, "%s: модель сначала смотрит по-старому (%.0f°)" % [
				HEROES[0], rad_to_deg(m.rotation.y)])
			wait = 120
			step = 13
		13:
			var m := models[0]
			check(m._turn_clip == "" and absf(m.rotation.y) < 0.1, "%s: поворот доигран — модель смотрит, куда герой (%.0f°)" % [
				HEROES[0], rad_to_deg(m.rotation.y)])
			check(m.loco_clip() == "" and m._anim.current_animation.to_lower() == "idle", "%s: после поворота — покой (%s)" % [
				HEROES[0], m._anim.current_animation])
			# Эмоции, уклонение, подъём при возрождении
			for i in models.size():
				models[i].play_emote("level")
			wait = 3
			step = 14
		14:
			for i in models.size():
				var cur := models[i]._anim.current_animation.to_lower()
				check(CharacterModel.MQ_EMOTES["level"].has(cur), "%s: новый уровень — эмоция (%s)" % [HEROES[i], cur])
			wait = 150
			step = 15
		15:
			for i in models.size():
				models[i].play_dodge()
			wait = 3
			step = 16
		16:
			for i in models.size():
				var cur := models[i]._anim.current_animation.to_lower()
				check(cur == "dodge", "%s: уклонение — отскок Dodge (%s)" % [HEROES[i], cur])
			wait = 120
			step = 17
		17:
			for i in models.size():
				models[i].play_rise()
			wait = 3
			step = 18
		18:
			for i in models.size():
				var m := models[i]
				check(m._anim.current_animation.to_lower() == "mq_rise", "%s: возрождение — подъём (%s)" % [
					HEROES[i], m._anim.current_animation])
				m.queue_free()
			heroine.queue_free()
			_pivot.queue_free()
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
	# Пол — в конце имени (у Бродяги перед «_starter»): hero_warrior_f, hero_human_f_starter
	var female := who.get_file().get_basename().trim_suffix("_starter").ends_with("_f")
	var lo := 1.65 if female else 1.75
	var hi := 1.75 if female else 1.85
	var tris := 0
	var h := 0.0
	for n in m._asset.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		# Только тело героя: оружие в руках (под BoneAttachment3D) — отдельные меши со своим материалом
		if mi.mesh == null or _on_bone(mi, m._asset):
			continue
		h = maxf(h, mi.mesh.get_aabb().size.y)
		for s in mi.mesh.get_surface_count():
			tris += (mi.mesh as ArrayMesh).surface_get_array_index_len(s) / 3
		var mat := mi.material_override as StandardMaterial3D
		check(mat != null and mat.albedo_texture != null, "%s: toon-материал с текстурой" % who)
	check(h > lo and h < hi, "%s: рост %.2f м (%.2f…%.2f)" % [who, h, lo, hi])
	check(tris >= MIN_TRIS and tris <= MAX_TRIS, "%s: треугольников %d (%d…%d)" % [who, tris, MIN_TRIS, MAX_TRIS])
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
	_check_mq(m, who, skel, rig)
	_check_loco(m, who, skel, rig)
	_check_shoulders(m, who, skel, rig)


## Плечи: в покое, стойках, шаге и беге плечевые суставы (2-я кость руки) не уходят назад от основания шеи (Z — вперёд
## модели) дальше SHOULDER_BACK — в среднем за клип и по обеим рукам (повороты корпуса в шаге взаимно гасятся).
func _check_shoulders(m: CharacterModel, who: String, skel: Skeleton3D, rig: Dictionary) -> void:
	var bones: Dictionary = rig.get("bones", {})
	var arms: Dictionary = bones.get("arms", {})
	var neck := skel.find_bone(String(bones.get("neck", "")))
	check(neck >= 0 and arms.has("L") and arms.has("R"), "%s: кости шеи и рук для проверки плеч" % who)
	if neck < 0 or not arms.has("L") or not arms.has("R"):
		return
	var sh := [skel.find_bone(String(arms["L"][1])), skel.find_bone(String(arms["R"][1]))]
	for c in SHOULDER_CLIPS:
		if not m._clips.has(c):
			continue
		var a := m._anim.get_animation(String(m._clips[c]))
		var pn := _bone_points(skel, a, neck, 30)
		var pl := _bone_points(skel, a, int(sh[0]), 30)
		var pr := _bone_points(skel, a, int(sh[1]), 30)
		var d := 0.0
		for k in pn.size():
			d += 0.5 * (pl[k].z + pr[k].z) - pn[k].z
		d /= float(maxi(pn.size(), 1))
		check(d >= -SHOULDER_BACK, "%s: %s — плечи позади шеи на %.3f м (до %.3f)" % [who, c, -d, SHOULDER_BACK])


## Имя клипа k-й обычной атаки по хвату модели (MQ_ATTACKS) или "".
func _mq_attack_clip(m: CharacterModel, k: int) -> String:
	var list: Array = CharacterModel.MQ_ATTACKS.get(m.mq_grip(), [])
	if list.is_empty():
		return ""
	return String(m._clips.get(String(list[k % list.size()]), ""))


## Движения манекенов Meshy: все клипы есть, в .json длина и момент удара (в пределах клипа), обычные атаки короткие,
## действия на месте (корень по X/Z не уходит), носок у земли не едет по ней (опоры закреплены, переступание дугой).
func _check_mq(m: CharacterModel, who: String, skel: Skeleton3D, rig: Dictionary) -> void:
	var info: Dictionary = rig.get("clips", {})
	var bones: Dictionary = rig.get("bones", {})
	var attacks: Array = []
	for list in CharacterModel.MQ_ATTACKS.values():
		attacks.append_array(list)
	for c in MQ_CLIPS:
		check(m._clips.has(c), "%s: есть клип манекена «%s»" % [who, c])
		if not m._clips.has(c):
			continue
		var cn := String(m._clips[c])
		var a := m._anim.get_animation(cn)
		var ci: Dictionary = info.get(cn, {})
		check(not ci.is_empty() and absf(float(ci.get("length", 0.0)) - a.length) < 0.05,
			"%s: %s — длина в .json (%.2f / %.2f с)" % [who, cn, float(ci.get("length", 0.0)), a.length])
		var loop: bool = CharacterModel.MQ_LOCO_CLIPS.has(c) or MQ_LOOPS.has(c)
		if MQ_LOOPS.has(c):
			check(bool(ci.get("loop", false)) and a.loop_mode == Animation.LOOP_LINEAR, "%s: %s — петля" % [who, cn])
			check(_loop_seam(a) < 0.01, "%s: %s — шов петли %.4f" % [who, cn, _loop_seam(a)])
		if not loop:
			var hit := float(ci.get("hit", -1.0))
			check(hit > 0.0 and hit < a.length, "%s: %s — момент удара %.2f с в клипе %.2f с" % [who, cn, hit, a.length])
			var lim := MQ_ATTACK_MAX if attacks.has(c) else MQ_ACT_MAX
			check(a.length <= lim, "%s: %s — длина %.2f с (до %.2f)" % [who, cn, a.length, lim])
		check(_root_still(a, String(bones.get("root", ""))), "%s: %s на месте (корень по X/Z не уходит)" % [who, cn])
		if MQ_TURNS.has(c):
			check(absf(float(ci.get("turn", 0.0))) >= MQ_TURN_MIN_DEG, "%s: %s — поворот корпуса %.0f°" % [who, cn,
				float(ci.get("turn", 0.0))])
		if attacks.has(c) or c == "mq_charged_slash" or c == "mq_axe_chop" or MQ_LOOPS.has(c) or MQ_TURNS.has(c):
			for side in ["L", "R"]:
				var leg: Array = bones.get("legs", {}).get(side, [])
				var toe := String(leg[mini(3, leg.size() - 1)]) if not leg.is_empty() else ""
				var s := _ground_slide(skel, a, skel.find_bone(toe))
				check(s <= MQ_GROUND_SLIDE, "%s: %s — стопа %s не едет по земле (%.3f м)" % [who, cn, side, s])


## Шаг и бег манекенов: у клипа своя скорость в .json; пока носок у земли (не выше покоя + 4 см), он едет назад ровно
## с этой скоростью (иначе в игре стопа скользит); таз по высоте ходит в меру (без «прыжков»); длина шага (скорость ×
## полцикла) — человеческая. 91 точка цикла, треки клипа (импорт 90 к/с).
func _check_loco(m: CharacterModel, who: String, skel: Skeleton3D, rig: Dictionary) -> void:
	var info: Dictionary = rig.get("clips", {})
	var bones: Dictionary = rig.get("bones", {})
	for e in MQ_LOCO:
		var row: Array = e
		var cn := String(m._clips.get(String(row[0]), ""))
		if cn == "":
			continue
		var a := m._anim.get_animation(cn)
		var v := float((info.get(cn, {}) as Dictionary).get("speed", 0.0))
		check(v > 0.5, "%s: %s — своя скорость в .json (%.2f м/с)" % [who, cn, v])
		if v <= 0.5:
			continue
		var worst := 0.0
		for side in ["L", "R"]:
			var leg: Array = bones.get("legs", {}).get(side, [])
			var toe := skel.find_bone(String(leg[mini(3, leg.size() - 1)])) if not leg.is_empty() else -1
			if toe < 0:
				continue
			var pts := _bone_points(skel, a, toe, 90)
			var near := skel.get_bone_global_rest(toe).origin.y + 0.04
			var start := -1
			for k in pts.size():
				if pts[k].y >= near:
					start = -1
				elif start < 0:
					start = k
				else:
					var dt := a.length * float(k - start) / 90.0
					worst = maxf(worst, Vector2(pts[k].x - pts[start].x, pts[k].z - pts[start].z + v * dt).length())
		check(worst <= MQ_LOCO_SLIDE, "%s: %s — опорная стопа не скользит при %.2f м/с (%.3f м)" % [who, cn, v, worst])
		var hips := skel.find_bone(String(bones.get("hips", "")))
		var hp := _bone_points(skel, a, hips, 90)
		var lo := INF
		var hi := -INF
		for p in hp:
			lo = minf(lo, p.y)
			hi = maxf(hi, p.y)
		check(hi - lo <= float(row[1]), "%s: %s — таз по высоте ходит на %.3f м (до %.2f)" % [who, cn, hi - lo, float(row[1])])
		var step_len := v * a.length * 0.5
		if float(row[3]) > 0.0:
			check(step_len >= float(row[2]) and step_len <= float(row[3]), "%s: %s — шаг %.2f м (%.1f…%.1f)" % [who, cn,
				step_len, float(row[2]), float(row[3])])
		if cn.to_lower() == "mq_running":
			# Высота ног в переносе: носок над покоем, колено относительно тазобедренного сустава (доли роста)
			var height := float(rig.get("height", 1.8))
			var lift := 0.0
			var knee := INF
			for side in ["L", "R"]:
				var leg: Array = bones.get("legs", {}).get(side, [])
				if leg.size() < 4:
					continue
				var toe := skel.find_bone(String(leg[3]))
				var tp := _bone_points(skel, a, toe, 90)
				var kp := _bone_points(skel, a, skel.find_bone(String(leg[1])), 90)
				var hp2 := _bone_points(skel, a, skel.find_bone(String(leg[0])), 90)
				for k in tp.size():
					lift = maxf(lift, tp[k].y - skel.get_bone_global_rest(toe).origin.y)
					knee = minf(knee, hp2[k].y - kp[k].y)
			var cad := 2.0 / a.length * 7.0 / v
			check(lift <= RUN_LIFT_MAX * height, "%s: бег — носок в переносе на %.2f м (до %.2f)" % [who, lift,
				RUN_LIFT_MAX * height])
			check(knee >= RUN_KNEE_MIN * height, "%s: бег — колено ниже таза на %.2f м (от %.2f)" % [who, knee,
				RUN_KNEE_MIN * height])
			check(cad <= RUN_CADENCE_MAX, "%s: бег — при 7 м/с %.2f шаг/с (до %.1f)" % [who, cad, RUN_CADENCE_MAX])
			print("  %s: бег %.2f м/с, шаг %.2f м, %.2f шаг/с (при 7 м/с — %.2f), таз %.3f м, скольжение %.3f м, носок %.2f м, колено ниже таза %.2f м" % [
				who, v, step_len, 2.0 / a.length, cad, hi - lo, worst, lift, knee])


## Позиции кости (в пространстве скелета) в n + 1 точках клипа: позы костей от корня — треки клипа, иначе поза покоя.
func _bone_points(skel: Skeleton3D, a: Animation, bone: int, n: int) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	if bone < 0:
		return pts
	var chain: Array[int] = []
	var b := bone
	while b >= 0:
		chain.push_front(b)
		b = skel.get_bone_parent(b)
	var rot := {}
	var pos := {}
	for t in a.get_track_count():
		var nm := String(a.track_get_path(t).get_concatenated_subnames())
		if a.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			rot[nm] = t
		elif a.track_get_type(t) == Animation.TYPE_POSITION_3D:
			pos[nm] = t
	for k in n + 1:
		var tm := a.length * float(k) / float(n)
		var xf := Transform3D.IDENTITY
		for c in chain:
			var bn := skel.get_bone_name(c)
			var rest := skel.get_bone_rest(c)
			var q := rest.basis.get_rotation_quaternion()
			var o := rest.origin
			if rot.has(bn):
				q = a.rotation_track_interpolate(int(rot[bn]), tm)
			if pos.has(bn):
				o = a.position_track_interpolate(int(pos[bn]), tm)
			xf = xf * Transform3D(Basis(q), o)
		pts.append(xf.origin)
	return pts


## Шов петли: наибольший угол (рад) между первым и последним ключом поворота у всех костей.
func _loop_seam(a: Animation) -> float:
	var worst := 0.0
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_ROTATION_3D or a.track_get_key_count(t) < 2:
			continue
		var q0: Quaternion = a.track_get_key_value(t, 0)
		var q1: Quaternion = a.track_get_key_value(t, a.track_get_key_count(t) - 1)
		worst = maxf(worst, q0.angle_to(q1))
	return worst


## Корень по X/Z во всех ключах как в первом.
func _root_still(a: Animation, root: String) -> bool:
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_POSITION_3D:
			continue
		if String(a.track_get_path(t).get_concatenated_subnames()) != root:
			continue
		var k0: Vector3 = a.track_get_key_value(t, 0)
		for k in a.track_get_key_count(t):
			var v: Vector3 = a.track_get_key_value(t, k)
			if absf(v.x - k0.x) > 0.001 or absf(v.z - k0.z) > 0.001:
				return false
	return true


## Наибольший сдвиг кости по земле (X/Z), пока она у земли (не выше своей высоты в покое + 4 см): 61 точка клипа, позы
## костей от корня — треки клипа, иначе поза покоя.
func _ground_slide(skel: Skeleton3D, a: Animation, bone: int) -> float:
	if bone < 0:
		return 0.0
	var chain: Array[int] = []
	var b := bone
	while b >= 0:
		chain.push_front(b)
		b = skel.get_bone_parent(b)
	var rot := {}
	var pos := {}
	for t in a.get_track_count():
		var nm := String(a.track_get_path(t).get_concatenated_subnames())
		if a.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			rot[nm] = t
		elif a.track_get_type(t) == Animation.TYPE_POSITION_3D:
			pos[nm] = t
	var pts: Array[Vector3] = []
	var near := skel.get_bone_global_rest(bone).origin.y + 0.04
	for k in 61:
		var tm := a.length * float(k) / 60.0
		var xf := Transform3D.IDENTITY
		for c in chain:
			var bn := skel.get_bone_name(c)
			var rest := skel.get_bone_rest(c)
			var q := rest.basis.get_rotation_quaternion()
			var o := rest.origin
			if rot.has(bn):
				q = a.rotation_track_interpolate(int(rot[bn]), tm)
			if pos.has(bn):
				o = a.position_track_interpolate(int(pos[bn]), tm)
			xf = xf * Transform3D(Basis(q), o)
		pts.append(xf.origin)
	var worst := 0.0
	var start := -1
	for k in pts.size():
		if pts[k].y >= near:
			start = -1
		elif start < 0:
			start = k
		else:
			worst = maxf(worst, Vector2(pts[k].x - pts[start].x, pts[k].z - pts[start].z).length())
	return worst


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


## Меш висит на кости (оружие, метки) — где-то между ним и корнем модели есть BoneAttachment3D.
func _on_bone(n: Node, top: Node) -> bool:
	var p := n.get_parent()
	while p != null and p != top:
		if p is BoneAttachment3D:
			return true
		p = p.get_parent()
	return false


func _female(path: String) -> bool:
	return path.get_file().get_basename().trim_suffix("_starter").ends_with("_f")


## Размах вращения таза (°) в клипе: вокруг вертикали (x) и наклона в сторону (y) — мировой поворот кости таза
## (произведение треков от корня скелета) относительно позы покоя, 48 точек за клип.
func _hips_swing(m: CharacterModel, who: String, clip: String) -> Vector2:
	var skel := _skel(m)
	if skel == null or m._anim == null:
		return Vector2.ZERO
	var hips := skel.find_bone(String(CharacterModel.asset_rig(who).get("bones", {}).get("hips", "")))
	if hips < 0:
		return Vector2.ZERO
	var a := m._anim.get_animation(m._clip(clip))
	var chain: Array[int] = []
	var b := hips
	while b >= 0:
		chain.push_front(b)
		b = skel.get_bone_parent(b)
	var tracks := {}
	for t in a.get_track_count():
		if a.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			tracks[String(a.track_get_path(t).get_concatenated_subnames())] = t
	var rest := Quaternion.IDENTITY
	for c in chain:
		rest = rest * skel.get_bone_rest(c).basis.get_rotation_quaternion()
	var yaw := Vector2(INF, -INF)
	var roll := Vector2(INF, -INF)
	for k in 48:
		var tm := a.length * float(k) / 48.0
		var q := Quaternion.IDENTITY
		for c in chain:
			var bn := skel.get_bone_name(c)
			if tracks.has(bn):
				q = q * a.rotation_track_interpolate(int(tracks[bn]), tm)
			else:
				q = q * skel.get_bone_rest(c).basis.get_rotation_quaternion()
		var rel := q * rest.inverse()
		var f := rel * Vector3(0, 0, 1)
		var sx := rel * Vector3(1, 0, 0)
		var y := rad_to_deg(atan2(f.x, f.z))
		var r := rad_to_deg(atan2(sx.y, sx.x))
		yaw = Vector2(minf(yaw.x, y), maxf(yaw.y, y))
		roll = Vector2(minf(roll.x, r), maxf(roll.y, r))
	return Vector2(yaw.y - yaw.x, roll.y - roll.x)


## Женская пластика: у каждой героини таз в шаге вращается вокруг вертикали в 1.6+ раза сильнее, чем в среднем у
## героев, и качается в сторону сильнее; в беге — вокруг вертикали заметно (у героев бег UAL почти без вращения).
func _check_gait() -> void:
	var male_walk := 0.0
	var male_roll := 0.0
	var male_run := 0.0
	var male_mq := 0.0
	var n := 0
	for i in models.size():
		if not _female(String(HEROES[i])):
			var w := _hips_swing(models[i], String(HEROES[i]), "walking")
			male_walk += w.x
			male_roll += w.y
			male_run += _hips_swing(models[i], String(HEROES[i]), "running").x
			male_mq += _hips_swing(models[i], String(HEROES[i]), "mq_walking").x
			n += 1
	check(n > 0, "есть мужские герои для сравнения пластики")
	if n == 0:
		return
	male_walk /= float(n)
	male_roll /= float(n)
	male_run /= float(n)
	male_mq /= float(n)
	print("  пластика героев: таз в шаге %.1f° вокруг вертикали, %.1f° в сторону, в беге %.1f°" % [
		male_walk, male_roll, male_run])
	for i in models.size():
		var who := String(HEROES[i])
		if not _female(who):
			continue
		var w := _hips_swing(models[i], who, "walking")
		var r := _hips_swing(models[i], who, "running")
		check(w.x > male_walk * 1.6, "%s: шаг — таз вокруг вертикали %.1f° (у героев %.1f°)" % [who, w.x, male_walk])
		check(w.y > male_roll * 1.4, "%s: шаг — таз в сторону %.1f° (у героев %.1f°)" % [who, w.y, male_roll])
		check(r.x > male_run + 3.0, "%s: бег — таз вокруг вертикали %.1f° (у героев %.1f°)" % [who, r.x, male_run])
		# Шаг манекена (в игре — он): женская пластика тоже (у бега манекена таз и так вращается на 15°, у героинь —
		# колея уже, мах рук и наклон меньше: tools/retarget_mannequin.py --check)
		var mw := _hips_swing(models[i], who, "mq_walking")
		check(mw.x > male_mq * 1.5, "%s: шаг манекена — таз вокруг вертикали %.1f° (у героев %.1f°)" % [who, mw.x, male_mq])
