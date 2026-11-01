extends "res://tests/test_base.gd"
## Хват второй рукой (TwoHandIK, задача Максима «двуручное — в двух руках, арбалет и лук — двумя руками»): у героев
## из файлов (мужчины и женщины разных рас, прежняя героиня со скелетом Mixamo) с каждым двуручным видом оружия, луком
## и арбалетом. Позы — по меткам костей (BoneAttachment3D получает позу после модификаторов скелета):
##   двуручное в покое (наперевес) и в двуручном ударе — левый кулак у точки на рукояти (цель модификатора) ближе
##   MAX_DIST, цель — на оси рукояти модели в правой руке, между концом рукояти и правым кулаком; в покое — у grip2
##   (handheld.json), если дотягивается; локоть согнут в разумных пределах, в покое — вниз и наружу;
##   арбалет в стойке и при выстреле — левый кулак под ложем (на отрезке опоры); лук при натяжении — правый кулак на
##   линии натяжения тетивы, в покое правая свободна; удар по герою — рука отпускает оружие (вес к нулю);
##   одноручное, пары, щит — модификатора нет; без файла оружия — запасная точка второй руки (FALLBACK_GRIP2).
## Обычная атака двуручным — двуручный клип манекена (MQ_ATTACKS).

## Кулак ближе к цели, м.
const MAX_DIST := 0.07
## Угол в локте (между плечом и предплечьем), град.
const ELBOW_MIN := 25.0
const ELBOW_MAX := 178.5
## [модель героя, вид оружия ItemData, предмет]
const CASES := [
	["hero_warrior_m", "sword_2h", "weapon_sword_2h_r1"],
	["hero_light_elf_f_starter", "sword_2h", "weapon_sword_2h_r1"],
	["dark_elf_wanderer", "sword_2h", "weapon_sword_2h_r1"],
	["hero_swordsman_f", "spear", "weapon_spear_r1"],
	["hero_human_m_starter", "spear", "weapon_spear_r1"],
	["hero_warrior_f", "axe_2h", "weapon_axe_2h_r1"],
	["hero_conjurer_m", "axe_2h", "weapon_axe_2h_r1"],
	["hero_beastmaster_m", "mace_2h", "weapon_mace_2h_r1"],
	["hero_dark_elf_f_starter", "mace_2h", "weapon_mace_2h_r1"],
	["hero_wizard_f", "staff_2h", "weapon_staff_2h_r1"],
	["hero_shaman_m", "staff_2h", "weapon_staff_2h_r1"],
	["hero_assassin_f", "crossbow", "crossbow_starter"],
	["hero_human_f_starter", "crossbow", "crossbow_starter"],
	["dark_elf_wanderer", "crossbow", "crossbow_starter"],
	["hero_warrior_m", "bow", "weapon_bow_r1"],
	["hero_light_elf_m_starter", "bow", "weapon_bow_r1"],
	["hero_warrior_f", "bow", "weapon_bow_r1"],
]
## Одноручное, пары, щит: [модель, вид, основное, вторая рука]
const ONE_HANDED := [
	["hero_swordsman_m", "sword_1h", "weapon_sword_1h_r1", "weapon_shield_r1"],
	["hero_assassin_m", "daggers", "weapon_dagger_r1", "weapon_dagger_r1"],
	["hero_neophyte_f", "staff_1h", "weapon_staff_1h_r1", ""],
	["hero_conjurer_f", "dual_axes", "weapon_axe_1h_r1", "weapon_axe_1h_r1"],
	["hero_adept_m", "dagger", "weapon_dagger_r1", "weapon_shield_r1"],
]
## Позы ударов: [клип, момент, с]
const ATTACK_POSE := {"two": ["mq_heavy_swing", 0.55], "crossbow": ["crossbow_shoot", 0.25], "bow": ["mq_bow_draw", 0.9]}

var models: Array[CharacterModel] = []
var one_handed: Array[CharacterModel] = []
var fallback: CharacterModel = null


func run_step() -> void:
	match step:
		0:
			_check_attacks()
			var x := -12.0
			for e in CASES:
				models.append(_spawn(String(e[0]), String(e[1]), String(e[2]), "", x))
				x += 1.4
			for e in ONE_HANDED:
				one_handed.append(_spawn(String(e[0]), String(e[1]), String(e[2]), String(e[3]), x))
				x += 1.4
			# Без файла оружия — процедурный меч и запасная точка второй руки
			Handheld.force_missing = true
			fallback = _spawn("hero_swordsman_m", "sword_2h", "weapon_sword_2h_r1", "", x)
			Handheld.force_missing = false
			wait = 50
			step = 1
		1:
			for m in models:
				_check_pose(m, "в покое", true)
			_check_pose(fallback, "в покое, оружие из примитивов", true)
			_check_fallback()
			for m in one_handed:
				var e: Array = m.get_meta("case")
				check(m._ik == null and m.find_children("*", "TwoHandIK", true, false).is_empty(),
					"%s с «%s»: одной рукой — модификатора второй руки нет" % [String(e[0]), String(e[1])])
			for m in models:
				if m._ik != null:
					var pose: Array = ATTACK_POSE[m._ik.hold]
					_pose(m, String(pose[0]), float(pose[1]))
			_pose(fallback, "mq_heavy_swing", 0.55)
			wait = 50
			step = 2
		2:
			for m in models:
				_check_pose(m, "в ударе", false)
			_check_pose(fallback, "в ударе, оружие из примитивов", false)
			# Удар по герою: двуручное — левая отпускает рукоять (Mq_Hit), плавно
			for m in models:
				m._anim.speed_scale = 1.0
				m._act_end = -1.0
				m.play_hit()
			# реакция — случайный вариант (Mq_Hit / UAL Hit / Hit_Reaction ≈ 0.3 с): смотрим посреди клипа
			wait = 10
			step = 3
		3:
			for m in models:
				var e: Array = m.get_meta("case")
				if m._ik == null or m._ik.hold != TwoHandIK.HOLD_TWO:
					continue
				var who := "%s с «%s»" % [String(e[0]), String(e[1])]
				check(["mq_hit", "hit", "hit_reaction"].has(m._ik.clip), "%s: при уроне клип реакции (%s)" % [who, m._ik.clip])
				check(m._ik.weight_hold < 0.1, "%s: при уроне вторая рука отпускает рукоять (вес %.2f)" % [who,
					m._ik.weight_hold])
			for m in models + one_handed:
				m.queue_free()
			fallback.queue_free()
			ok_done()


## Обычная атака двуручным — клипы, где у манекена обе руки на рукояти.
func _check_attacks() -> void:
	for g in ["sword_2h", "axe_2h", "mace_2h", "spear"]:
		var list: Array = CharacterModel.MQ_ATTACKS.get(g, [])
		check(not list.is_empty(), "обычная атака «%s» — движение манекена" % g)
		for c in list:
			check(TwoHandIK.TWO_HAND_CLIPS.has(String(c)), "обычная атака «%s»: %s — обеими руками" % [g, c])
		for c in CharacterModel.MQ_STRIKES.get(g, []):
			check(TwoHandIK.TWO_HAND_CLIPS.has(String(c)), "удар умением «%s»: %s — обеими руками" % [g, c])


func _spawn(hero: String, kind: String, item: String, off: String, x: float) -> CharacterModel:
	var spec := CharacterModel.spec_for("dark_elf", "assassin", kind, "f", ItemData.is_shield(off), item, off)
	spec["asset"] = CharacterModel.HERO_ASSET_DIR + hero + ".glb"
	var m := CharacterModel.new()
	m.setup(spec)
	main.add_child(m)
	m.position = Vector3(x, 0.0, 44.0)
	m.set_meta("case", [hero, kind, item])
	if m._ik != null:
		# Метки на костях обеих рук: их поза — после модификаторов скелета (то, что видно на экране)
		var sk := m._ik.get_skeleton()
		for side in ["L", "R"]:
			var arm: PackedInt32Array = m._ik.arm_l if side == "L" else m._ik.arm_r
			for i in 3:
				var att := BoneAttachment3D.new()
				att.name = "Probe%s%d" % [side, i]
				att.bone_name = sk.get_bone_name(arm[i])
				sk.add_child(att)
	return m


## Клип key с момента t, замер (темп 0, действие не кончается).
func _pose(m: CharacterModel, key: String, t: float) -> void:
	var c := String(m._clips.get(key, ""))
	var e: Array = m.get_meta("case")
	check(c != "", "%s: есть клип %s" % [String(e[0]), key])
	if c == "":
		return
	m._anim.play(c, 0.0)
	m._anim.seek(t, true)
	m._anim.speed_scale = 0.0
	m._act_end = 99.0
	m._act_hit = 99.0


func _probe(m: CharacterModel, side: String, i: int) -> Vector3:
	var n := m.find_child("Probe%s%d" % [side, i], true, false) as Node3D
	return n.global_position if n != null else Vector3.INF


func _check_pose(m: CharacterModel, when: String, idle: bool) -> void:
	var e: Array = m.get_meta("case")
	var who := "%s с «%s» %s" % [String(e[0]), String(e[1]), when]
	var ik := m._ik
	check(ik != null, "%s: есть модификатор второй руки" % who)
	if ik == null:
		return
	var sk := ik.get_skeleton()
	var side := "R" if ik.hold == TwoHandIK.HOLD_BOW else "L"
	var fist_xf := ik.fist_r if side == "R" else ik.fist_l
	var hand := m.find_child("Probe%s2" % side, true, false) as Node3D
	check(hand != null, "%s: метка кисти" % who)
	if hand == null:
		return
	if ik.hold == TwoHandIK.HOLD_BOW and idle:
		# В покое правая свободна (тетиву не держит)
		check(ik.last_weight < 0.05, "%s: правая рука свободна (вес %.2f)" % [who, ik.last_weight])
		return
	check(ik.last_weight > 0.85, "%s: вторая рука на оружии (вес %.2f, клип %s)" % [who, ik.last_weight, ik.clip])
	var target := sk.global_transform * ik.last_target
	var fist := hand.global_transform * fist_xf.origin
	var d := fist.distance_to(target)
	check(d < MAX_DIST, "%s: кулак у цели (%.3f м)" % [who, d])
	# Цель — на оружии (рамка модели оружия на метке кисти)
	var wnode := _weapon_node(m, ik.hold)
	check(wnode != null, "%s: оружие в руке" % who)
	if wnode == null:
		return
	var loc := wnode.global_transform.affine_inverse() * target
	match ik.hold:
		TwoHandIK.HOLD_TWO:
			check(Vector2(loc.x - ik.grip2.x, loc.z - ik.grip2.z).length() < 0.02
				and loc.y >= ik.handle_lo - 0.01 and loc.y <= ik.handle_hi + 0.01,
				"%s: цель на рукояти (%s, рукоять %.2f…%.2f)" % [who, loc, ik.handle_lo, ik.handle_hi])
			if idle and absf(loc.y - ik.grip2.y) > 0.02:
				# Не у grip2 — значит, рука до него не достаёт: взята ближайшая точка рукояти, рука почти вытянута
				var reach := _probe(m, side, 0).distance_to(_probe(m, side, 1)) + _probe(m, side, 1).distance_to(
					_probe(m, side, 2))
				var ext := _probe(m, side, 0).distance_to(_probe(m, side, 2)) / maxf(reach, 0.001)
				check(ext > 0.85, "%s: наперевес — ближе к grip2 рука не достаёт (%.2f / %.2f, рука %.0f %%)" % [who,
					loc.y, ik.grip2.y, ext * 100.0])
		TwoHandIK.HOLD_CROSSBOW:
			check(absf(loc.x - ik.support_front.x) < 0.02 and absf(loc.y - ik.support_front.y) < 0.02
				and loc.z >= ik.support_front.z - 0.01 and loc.z <= ik.support_back.z + 0.01,
				"%s: левая под ложем (%s)" % [who, loc])
		TwoHandIK.HOLD_BOW:
			check(Vector2(loc.x - ik.string_c.x, loc.y - ik.string_c.y).length() < 0.02
				and loc.z >= ik.string_c.z - 0.01 and loc.z <= ik.string_c.z + TwoHandIK.DRAW_MAX + 0.01,
				"%s: правая на линии натяжения тетивы (%s)" % [who, loc])
	# Локоть: согнут в разумных пределах; наперевес — вниз и наружу
	var s := _probe(m, side, 0)
	var el := _probe(m, side, 1)
	var wr := _probe(m, side, 2)
	var ang := rad_to_deg((s - el).angle_to(wr - el))
	check(ang > ELBOW_MIN and ang < ELBOW_MAX, "%s: угол в локте %.0f°" % [who, ang])
	if idle and ik.hold == TwoHandIK.HOLD_TWO:
		var inv := sk.global_transform.affine_inverse()
		var sl := inv * s
		var mid := (sl + inv * wr) * 0.5
		var off := inv * el - mid
		check(off.y < 0.03, "%s: локоть не вверх (%.3f)" % [who, off.y])
		check(off.x > -0.04, "%s: локоть не внутрь, к телу (%.3f)" % [who, off.x])


## Модель оружия на метке кисти: двуручное и арбалет — в правой, лук — в левой.
func _weapon_node(m: CharacterModel, hold: String) -> Node3D:
	var grip := m.find_child("GripL" if hold == TwoHandIK.HOLD_BOW else "GripR", true, false)
	if grip == null:
		return null
	for c in grip.get_children():
		if c is MeshInstance3D:
			return c as Node3D
	return null


## Без файла оружия: процедурный меч, вторая рука — FALLBACK_GRIP2.
func _check_fallback() -> void:
	var ik := fallback._ik
	var w := _weapon_node(fallback, TwoHandIK.HOLD_TWO)
	check(w != null and not w.has_meta("handheld"), "без файла оружия — процедурный меч")
	check(ik != null and is_equal_approx(ik.grip2.y, float(TwoHandIK.FALLBACK_GRIP2["sword_2h"])),
		"без файла оружия — запасная точка второй руки (%s)" % (ik.grip2 if ik != null else Vector3.INF))
