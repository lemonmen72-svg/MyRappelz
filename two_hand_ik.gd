class_name TwoHandIK
extends SkeletonModifier3D
## Хват второй рукой (задача Максима: «Двуручное оружие должно быть в двух руках. Так же двумя руками используется
## арбалет и лук»). Модификатор скелета героя из файла (ставит CharacterModel._setup_asset): после анимации каждый
## кадр двухзвенный IK руки (плечо — предплечье — кисть) ставит кулак руки на оружие, кисть поворачивается по
## оружию, пальцы добирают сгиб к ладони (если в <модель>.json есть роли пальцев).
##   HOLD_TWO      — двуручное (TWO_HANDED_KINDS): правая держит у хвата (начало модели оружия), левая — на рукояти
##                   у grip2 (handheld.json; нет файла оружия — FALLBACK_GRIP2). В покое, шаге и беге (CARRY_CLIPS)
##                   оружие наперевес: поза CARRY от середины плеч, обе руки — IK. В двуручных клипах
##                   (TWO_HAND_CLIPS — у манекена обе руки на рукояти) оружие идёт по правой руке клипа, левая
##                   скользит по рукояти туда, где её держит клип (между концом рукояти и HAND_GAP от правой).
##   HOLD_CROSSBOW — левая поддерживает ложе снизу ладонью вверх, как можно ближе к дуге — насколько дотягивается
##                   рука (стойка и выстрел, SUPPORT_CLIPS); правая — на ложе у спуска, как в клипе.
##   HOLD_BOW      — правая на линии натяжения: от середины тетивы к лучнику, на сколько натянута — по клипу
##                   (DRAW_CLIPS); поворот кисти — из клипа. В покое правая свободна (тетиву не держит).
## Остальные клипы (урон, смерть, подбор, заклинания, удары одной рукой) — вес 0: рука отпускает оружие. Вес меняется
## плавно (WEIGHT_RATE), повороты костей смешиваются с позой клипа по весу; цель дальше, чем дотягивается рука, —
## вес убывает (REACH_FADE), рука не вытягивается в струну и не тянется через тело.

const HOLD_TWO := "two"
const HOLD_CROSSBOW := "crossbow"
const HOLD_BOW := "bow"
## Виды оружия ItemData, которые держат двумя руками (лук и арбалет — свои режимы).
const TWO_HANDED_KINDS := ["sword_2h", "staff_2h", "mace_2h", "axe_2h", "spear"]
## Клипы, где у манекена Meshy обе руки на рукояти (проверено по всем кадрам: левый кулак у оси оружия правой руки).
const TWO_HAND_CLIPS := ["mq_heavy_swing", "mq_leap_slam"]
## Покой и передвижение: двуручное наперевес.
const CARRY_CLIPS := ["idle", "walking", "walking_woman", "running"]
## Арбалет: стойка на изготовку, выстрел и прицеливание (петля каста умения) — левая под ложем.
const SUPPORT_CLIPS := ["crossbow_idle", "crossbow_shoot", "mq_crossbow_aim_loop"]
## Лук: выстрел, выстрел умением и прицеливание (петля каста умения) — правая на тетиве.
const DRAW_CLIPS := ["mq_bow_shot", "mq_bow_draw", "mq_bow_aim_loop"]
## Скорость смены веса, 1/с (за 0.1 с — 70 %).
const WEIGHT_RATE := 12.0
## Доля длины руки (плечо + предплечье), до которой рука тянется к цели; дальше — вес убывает на REACH_FADE м.
const REACH := 0.97
const REACH_FADE := 0.12
## Наперевес по виду: [вправо от середины плеч, доля полуширины плеч; вниз, доля длины руки; вперёд, доля длины руки;
## ось оружия в осях корпуса (влево, вверх, вперёд)] — правый кулак у груди, оружие наискось через тело (остриё
## вверх-вправо, рукоять к левому бедру), костяшки вперёд.
const CARRY := {
	"sword_2h": [0.45, 0.55, 0.75, Vector3(-0.65, 0.65, 0.35)],
	"axe_2h": [0.45, 0.55, 0.75, Vector3(-0.7, 0.6, 0.3)],
	"mace_2h": [0.45, 0.55, 0.75, Vector3(-0.7, 0.6, 0.3)],
	"spear": [0.45, 0.5, 0.75, Vector3(-0.6, 0.72, 0.3)],
	"staff_2h": [0.5, 0.45, 0.7, Vector3(-0.35, 0.9, 0.25)],
}
## Модель оружия из примитивов (нет файла): вторая рука и конец рукояти по оси +Y, м.
const FALLBACK_GRIP2 := {"sword_2h": -0.1, "axe_2h": -0.11, "mace_2h": -0.1, "staff_2h": -0.3, "spear": -0.4}
const FALLBACK_BUTT := {"sword_2h": -0.09, "axe_2h": -0.13, "mace_2h": -0.12, "staff_2h": -0.45, "spear": -0.47}
## Кулаки на рукояти не ближе (центр к центру), м; от конца рукояти — не ближе BUTT_GAP.
const HAND_GAP := 0.095
const BUTT_GAP := 0.06
## Арбалет: опора левого кулака под ложем — от передней точки (у дуги) до задней (вплотную перед правым кулаком),
## рамка арбалета (ложе −Z, верх +Y). Модель из файла и из примитивов.
const SUPPORT_FILE := [Vector3(0, 0.03, -0.27), Vector3(0, 0.03, -0.055)]
const SUPPORT_PROC := [Vector3(0, 0.05, -0.25), Vector3(0, 0.05, -0.055)]
## В стойке UAL (пистолетная, руки почти прямые) левая не достаёт и до задней точки опоры — арбалет подтягивается
## к себе вдоль ложа (правая сгибается), не дальше PULL_MAX (дальше приклад уходит в грудь), м.
const PULL_MAX := 0.07
## Левый кулак под ложем в рамке арбалета: костяшки вправо (+X), указательный вперёд (−Z), ладонь вверх (+Y).
const SUPPORT_BASIS := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
## Лук: точка натяжения над рукоятью (полка стрелы), м; натяжение не дальше DRAW_MAX от тетивы. Правая кисть клипа
## дальше NEAR_FAR от линии натяжения — не на тетиве (тянется к колчану, опущена), ближе NEAR_ON — на ней.
const STRING_LIFT := 0.05
const DRAW_MAX := 0.75
const NEAR_ON := 0.15
const NEAR_FAR := 0.32
## Сгиб пальцев при хвате (основная, средняя, ногтевая фаланги), рад; на тетиве — доля DRAW_FLEX.
const FLEX := [0.95, 1.25, 0.7]
const DRAW_FLEX := 0.55
const FINGERS := ["index", "middle", "ring", "pinky"]

var hold := ""
## Вид оружия ItemData (поза наперевес).
var kind := ""
var anim: AnimationPlayer = null
## Кости рук: плечо, предплечье, кисть.
var arm_r := PackedInt32Array()
var arm_l := PackedInt32Array()
var fingers_r: Array[PackedInt32Array] = []
var fingers_l: Array[PackedInt32Array] = []
## Кулаки в пространстве кистей (центр, ось хвата от мизинца к указательному, +X — к костяшкам): _grip_xf.
var fist_r := Transform3D.IDENTITY
var fist_l := Transform3D.IDENTITY
## Оружие в пространстве своей кисти (правой — двуручное и арбалет, левой — лук), как стоит на метке кости.
var weapon_xf := Transform3D.IDENTITY
## Двуручное: вторая рука и пределы рукояти по оси +Y оружия.
var grip2 := Vector3(0, -0.2, 0)
var handle_lo := -0.3
var handle_hi := -0.095
## Арбалет: опора под ложем; лук: точка натяжения на тетиве (рамка оружия).
var support_front := Vector3.ZERO
var support_back := Vector3.ZERO
var string_c := Vector3.ZERO
## Вес хвата (вторая рука на оружии) и позы наперевес: текущий и к какому идёт.
var weight_hold := 0.0
var weight_carry := 0.0
var want_hold := 0.0
var want_carry := 0.0
## Клип сейчас (ключ в нижнем регистре, без библиотеки).
var clip := ""
## Для тестов: цель кулака руки, которую ставит IK (пространство скелета), точка на оружии (рамка оружия) и итоговый
## вес последнего кадра.
var last_target := Vector3.ZERO
var last_point := Vector3.ZERO
var last_weight := 0.0
var _snap := true


## Модификатор для модели из файла. skel — скелет, rig — <модель>.json (CharacterModel.asset_rig; {} — кости по
## именам Mixamo), hold_kind — HOLD_*, weapon_kind — вид оружия ItemData, wid — модель оружия из файла (Handheld;
## "" — из примитивов), wxf — оружие в пространстве своей кисти, fr / fl — кулаки (_grip_xf). null — костей рук нет.
static func create(skel: Skeleton3D, rig: Dictionary, hold_kind: String, weapon_kind: String, wid: String,
		wxf: Transform3D, fr: Transform3D, fl: Transform3D) -> TwoHandIK:
	if skel == null or hold_kind == "":
		return null
	var ar := arm_bones(skel, rig, "R")
	var al := arm_bones(skel, rig, "L")
	if ar.is_empty() or al.is_empty():
		return null
	var ik := TwoHandIK.new()
	ik.name = "TwoHandIK"
	ik.hold = hold_kind
	ik.kind = weapon_kind
	ik.arm_r = ar
	ik.arm_l = al
	ik.fingers_r = finger_bones(skel, rig, "R")
	ik.fingers_l = finger_bones(skel, rig, "L")
	ik.fist_r = fr
	ik.fist_l = fl
	ik.weapon_xf = wxf
	match hold_kind:
		HOLD_TWO:
			var g2 := Vector3(0.0, float(FALLBACK_GRIP2.get(weapon_kind, -0.2)), 0.0)
			var butt := float(FALLBACK_BUTT.get(weapon_kind, -0.3))
			if wid != "":
				g2 = Handheld.point(wid, "grip2", g2)
				butt = Handheld.point(wid, "butt", Vector3(0.0, butt, 0.0)).y
			ik.grip2 = g2
			ik.handle_hi = maxf(-HAND_GAP, g2.y)
			ik.handle_lo = minf(butt + BUTT_GAP, g2.y)
		HOLD_CROSSBOW:
			var sp: Array = SUPPORT_FILE if wid != "" else SUPPORT_PROC
			ik.support_front = sp[0]
			ik.support_back = sp[1]
		HOLD_BOW:
			var c := Vector3(0.0, 0.0, 0.14)
			if wid != "":
				# Середина тетивы — между концами плеч лука
				var tip := Handheld.point(wid, "tip", Vector3(0, 0.7, 0.14))
				var end := Handheld.point(wid, "butt", Vector3(0, -0.7, 0.14))
				c = (tip + end) * 0.5
				c.y = 0.0
			ik.string_c = c + Vector3(0.0, STRING_LIFT, 0.0)
	skel.add_child(ik)
	return ik


## Кости руки side ("L"/"R"): плечо, предплечье, кисть — роли из <модель>.json (bones.arms: ключица, плечо,
## предплечье, кисть, …), иначе имена Mixamo. Пусто — не нашлись или идут не цепочкой.
static func arm_bones(skel: Skeleton3D, rig: Dictionary, side: String) -> PackedInt32Array:
	var out := PackedInt32Array()
	var bones: Dictionary = rig.get("bones", {})
	var arms: Dictionary = bones.get("arms", {})
	var chain: Array = arms.get(side, [])
	if chain.size() >= 4:
		for i in [1, 2, 3]:
			out.append(skel.find_bone(String(chain[i])))
	else:
		var s := "Left" if side == "L" else "Right"
		for n in [s + "Arm", s + "ForeArm", s + "Hand"]:
			out.append(find_suffix(skel, n))
	if out.has(-1) or skel.get_bone_parent(out[1]) != out[0] or skel.get_bone_parent(out[2]) != out[1]:
		return PackedInt32Array()
	return out


## Пальцы руки side без большого (bones.fingers в <модель>.json): цепочки от основания, только идущие подряд.
static func finger_bones(skel: Skeleton3D, rig: Dictionary, side: String) -> Array[PackedInt32Array]:
	var out: Array[PackedInt32Array] = []
	var bones: Dictionary = rig.get("bones", {})
	var fingers: Dictionary = bones.get("fingers", {})
	var fs: Dictionary = fingers.get(side, {})
	for f in FINGERS:
		var names: Array = fs.get(f, [])
		var ch := PackedInt32Array()
		for n in names:
			var b := skel.find_bone(String(n))
			if b < 0 or (not ch.is_empty() and skel.get_bone_parent(b) != ch[ch.size() - 1]):
				break
			ch.append(b)
		if ch.size() >= 2:
			out.append(ch)
	return out


## Кость, имя которой — name или оканчивается на «_name» / «:name» (Mixamo); -1 — нет.
static func find_suffix(skel: Skeleton3D, bone_name: String) -> int:
	for i in skel.get_bone_count():
		var bn := skel.get_bone_name(i)
		if bn == bone_name or bn.ends_with("_" + bone_name) or bn.ends_with(":" + bone_name):
			return i
	return -1


## Каждый кадр (CharacterModel._asset_process): вес по текущему клипу, плавно.
func update(delta: float) -> void:
	clip = _clip_key()
	if clip == "":
		return
	var h := 0.0
	var c := 0.0
	match hold:
		HOLD_TWO:
			if CARRY_CLIPS.has(clip):
				h = 1.0
				c = 1.0
			elif TWO_HAND_CLIPS.has(clip):
				h = 1.0
		HOLD_CROSSBOW:
			if SUPPORT_CLIPS.has(clip):
				h = 1.0
		HOLD_BOW:
			if DRAW_CLIPS.has(clip):
				h = 1.0
	want_hold = h
	want_carry = c
	var k := 1.0 if _snap else 1.0 - exp(-WEIGHT_RATE * delta)
	_snap = false
	weight_hold = lerpf(weight_hold, want_hold, k)
	weight_carry = lerpf(weight_carry, want_carry, k)


func _clip_key() -> String:
	if anim == null:
		return ""
	var n := String(anim.current_animation)
	if n.contains("/"):
		n = n.get_slice("/", 1)
	return n.to_lower()


func _process_modification() -> void:
	last_weight = 0.0
	if weight_hold < 0.002 and weight_carry < 0.002:
		return
	var sk := get_skeleton()
	if sk == null:
		return
	match hold:
		HOLD_TWO:
			_two_hands(sk)
		HOLD_CROSSBOW:
			_support(sk)
		HOLD_BOW:
			_bow_string(sk)


## Двуручное: наперевес — оружие в позе CARRY (правая рука за ним), в двуручном клипе — по правой руке клипа; левая
## на рукояти.
func _two_hands(sk: Skeleton3D) -> void:
	var hr := sk.get_bone_global_pose(arm_r[2])
	var hl := sk.get_bone_global_pose(arm_l[2])
	var su := sk.get_bone_global_pose(arm_r[0]).origin
	var sl := sk.get_bone_global_pose(arm_l[0]).origin
	var tor := _torso(su, sl)
	var w := (hr * weapon_xf).orthonormalized()
	if weight_carry > 0.002:
		var reach := (_arm_len(sk, arm_r) + _arm_len(sk, arm_l)) * 0.5
		var wc := _carry_frame(tor, su.distance_to(sl) * 0.5, reach)
		var t := clampf(weight_carry, 0.0, 1.0)
		var wb := Transform3D(w.basis.slerp(wc.basis, t), w.origin.lerp(wc.origin, t))
		hr = _solve(sk, arm_r, wb * weapon_xf.affine_inverse(), 1.0, tor.basis * Vector3(-0.6, -0.75, -0.25), t)
		w = (hr * weapon_xf).orthonormalized()
	# Где левая сейчас по клипу (вдоль рукояти) → в позе наперевес — у grip2
	var s_clip := (w.affine_inverse() * (hl * fist_l.origin)).y
	var s_pref := lerpf(clampf(s_clip, handle_lo, handle_hi), grip2.y, clampf(weight_carry, 0.0, 1.0))
	# Кулак левой — в рамке оружия (костяшки как у правой): запястье = рамка в точке рукояти × кулак⁻¹, по s — прямая
	var inv := fist_l.affine_inverse()
	var w0 := (Transform3D(w.basis, w * Vector3(grip2.x, 0.0, grip2.z)) * inv).origin
	var pick := _reach_pick(w0, w.basis.y, sl, _arm_len(sk, arm_l) * REACH, handle_lo, handle_hi, s_pref)
	var point := Vector3(grip2.x, pick.x, grip2.z)
	var wl := weight_hold * (1.0 - smoothstep(0.0, REACH_FADE, pick.y))
	last_point = point
	last_target = w * point
	last_weight = wl
	if wl > 0.002:
		var hl2 := _solve(sk, arm_l, Transform3D(w.basis, w * point) * inv, wl,
			tor.basis * Vector3(0.6, -0.75, -0.25), clampf(weight_carry, 0.0, 1.0))
		_curl(sk, arm_l[2], hl2, fingers_l, fist_l, 1.0, wl)
	_curl(sk, arm_r[2], hr, fingers_r, fist_r, -1.0, weight_hold)


## Арбалет: левый кулак под ложем ладонью вверх — самая передняя точка опоры, до которой дотягивается рука; не
## достаёт и до задней — арбалет чуть ближе к себе (PULL_MAX).
func _support(sk: Skeleton3D) -> void:
	var hr := sk.get_bone_global_pose(arm_r[2])
	var su := sk.get_bone_global_pose(arm_r[0]).origin
	var sl := sk.get_bone_global_pose(arm_l[0]).origin
	var w := (hr * weapon_xf).orthonormalized()
	var inv := fist_l.affine_inverse()
	var r := _arm_len(sk, arm_l) * REACH
	var pick := _support_pick(w, inv, sl, r)
	if pick.y > 0.0:
		var pull := minf(pick.y * 1.3 + 0.01, PULL_MAX) * clampf(weight_hold, 0.0, 1.0)
		var wp := Transform3D(w.basis, w.origin + w.basis.z * pull)
		hr = _solve(sk, arm_r, wp * weapon_xf.affine_inverse(), 1.0, Vector3.ZERO, 0.0)
		w = (hr * weapon_xf).orthonormalized()
		pick = _support_pick(w, inv, sl, r)
	var point := Vector3(support_front.x, support_front.y, pick.x)
	var wl := weight_hold * (1.0 - smoothstep(0.0, REACH_FADE, pick.y))
	last_point = point
	last_target = w * point
	last_weight = wl
	if wl <= 0.002:
		return
	var tor := _torso(su, sl)
	var hl2 := _solve(sk, arm_l, w * Transform3D(SUPPORT_BASIS, point) * inv, wl,
		tor.basis * Vector3(0.5, -0.8, -0.2), 0.35)
	_curl(sk, arm_l[2], hl2, fingers_l, fist_l, 1.0, wl)


## Опора под ложем (оружие w, кулак⁻¹ inv, плечо sh, радиус r): Vector2(z, на сколько не достаёт).
func _support_pick(w: Transform3D, inv: Transform3D, sh: Vector3, r: float) -> Vector2:
	var w0 := (w * Transform3D(SUPPORT_BASIS, Vector3(support_front.x, support_front.y, 0.0)) * inv).origin
	return _reach_pick(w0, w.basis.z, sh, r, support_front.z, support_back.z, support_front.z)


## Лук: правый кулак на линии натяжения (от точки на тетиве к лучнику), натяжение и поворот кисти — из клипа; рука
## далеко от линии (тянется к колчану, опущена) — отпускает.
func _bow_string(sk: Skeleton3D) -> void:
	var hr := sk.get_bone_global_pose(arm_r[2])
	var hl := sk.get_bone_global_pose(arm_l[2])
	var w := (hl * weapon_xf).orthonormalized()
	var c := w * string_c
	var ax := w.basis.z
	var v := hr * fist_r.origin - c
	var s_raw := v.dot(ax)
	var perp := (v - ax * s_raw).length()
	var near := (1.0 - smoothstep(NEAR_ON, NEAR_FAR, perp)) * smoothstep(-0.2, -0.04, s_raw)
	var point := string_c + Vector3(0.0, 0.0, clampf(s_raw, 0.0, DRAW_MAX))
	var fist := w * point
	var wl := weight_hold * near
	last_point = point
	last_target = fist
	last_weight = wl
	if wl <= 0.002:
		return
	var hr2 := _solve(sk, arm_r, Transform3D(hr.basis, fist - hr.basis * fist_r.origin), wl, Vector3.ZERO, 0.0)
	_curl(sk, arm_r[2], hr2, fingers_r, fist_r, -1.0, wl * DRAW_FLEX)


## Двухзвенный IK руки arm (плечо, предплечье, кисть) к позе кисти target (пространство скелета): локоть — в
## плоскости локтя клипа, повёрнутой к pole на долю pole_mix (pole нулевой — как в клипе); weight — доля (повороты
## костей смешиваются с позой клипа). Цель дальше длины руки — рука прямая к ней. Возвращает новую позу кисти.
func _solve(sk: Skeleton3D, arm: PackedInt32Array, target: Transform3D, weight: float, pole: Vector3,
		pole_mix: float) -> Transform3D:
	var u := arm[0]
	var f := arm[1]
	var h := arm[2]
	var pu := sk.get_bone_parent(u)
	var pg := sk.get_bone_global_pose(pu) if pu >= 0 else Transform3D.IDENTITY
	var ug := sk.get_bone_global_pose(u)
	var fg := sk.get_bone_global_pose(f)
	var hg := sk.get_bone_global_pose(h)
	var s := ug.origin
	var e := fg.origin
	var l1 := s.distance_to(e)
	var l2 := e.distance_to(hg.origin)
	var to := target.origin - s
	var d := to.length()
	if d < 0.001 or l1 < 0.001 or l2 < 0.001:
		return hg
	var n := to / d
	d = clampf(d, absf(l1 - l2) + 0.001, (l1 + l2) * 0.999)
	# Плоскость сгиба: локоть клипа, повёрнутый к подсказке
	var p := (e - s) - n * (e - s).dot(n)
	p = p.normalized() if p.length_squared() > 1e-8 else Vector3.ZERO
	if pole != Vector3.ZERO and pole_mix > 0.0:
		p = p.lerp(pole.normalized(), clampf(pole_mix, 0.0, 1.0))
	p -= n * p.dot(n)
	if p.length_squared() < 1e-8:
		p = Vector3.DOWN - n * n.dot(Vector3.DOWN)
		if p.length_squared() < 1e-8:
			p = Vector3.BACK - n * n.dot(Vector3.BACK)
	p = p.normalized()
	var ca := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var e2 := s + (n * ca + p * sqrt(maxf(0.0, 1.0 - ca * ca))) * l1
	var w2 := s + n * d
	var ug2 := Transform3D(Basis(_arc(e - s, e2 - s)) * ug.basis, s)
	var fg1 := ug2 * (ug.affine_inverse() * fg)
	var hg1 := ug2 * (ug.affine_inverse() * hg)
	var fg2 := Transform3D(Basis(_arc(hg1.origin - fg1.origin, w2 - fg1.origin)) * fg1.basis, fg1.origin)
	var hg2 := Transform3D(target.basis.orthonormalized(), (fg2 * (fg.affine_inverse() * hg)).origin)
	var qu := (pg.affine_inverse() * ug2).basis.get_rotation_quaternion()
	var qf := (ug2.affine_inverse() * fg2).basis.get_rotation_quaternion()
	var qh := (fg2.affine_inverse() * hg2).basis.get_rotation_quaternion()
	if weight < 0.999:
		qu = sk.get_bone_pose_rotation(u).normalized().slerp(qu, weight)
		qf = sk.get_bone_pose_rotation(f).normalized().slerp(qf, weight)
		qh = sk.get_bone_pose_rotation(h).normalized().slerp(qh, weight)
	sk.set_bone_pose_rotation(u, qu)
	sk.set_bone_pose_rotation(f, qf)
	sk.set_bone_pose_rotation(h, qh)
	var ub := pg * Transform3D(Basis(qu), sk.get_bone_pose_position(u))
	var fb := ub * Transform3D(Basis(qf), sk.get_bone_pose_position(f))
	return fb * Transform3D(Basis(qh), sk.get_bone_pose_position(h))


## Поворот, переводящий направление a в b.
static func _arc(a: Vector3, b: Vector3) -> Quaternion:
	if a.length_squared() < 1e-10 or b.length_squared() < 1e-10:
		return Quaternion.IDENTITY
	return Quaternion(a.normalized(), b.normalized())


## Точка на отрезке оси [lo, hi] (wrist(s) = w0 + ax·s — запястье при кулаке в точке s), ближайшая к pref, до
## которой дотягивается рука (плечо sh, радиус r): Vector2(s, на сколько не достаёт; 0 — достаёт).
static func _reach_pick(w0: Vector3, ax: Vector3, sh: Vector3, r: float, lo: float, hi: float, pref: float) -> Vector2:
	var v := w0 - sh
	var b := v.dot(ax)
	var disc := b * b - (v.length_squared() - r * r)
	if disc >= 0.0:
		var q := sqrt(disc)
		var a0 := maxf(lo, -b - q)
		var a1 := minf(hi, -b + q)
		if a0 <= a1:
			return Vector2(clampf(pref, a0, a1), 0.0)
	var s := clampf(-b, lo, hi)
	return Vector2(s, maxf(0.0, (v + ax * s).length() - r))


## Длина руки (плечо + предплечье) в текущей позе.
static func _arm_len(sk: Skeleton3D, arm: PackedInt32Array) -> float:
	var a := sk.get_bone_global_pose(arm[0]).origin
	var b := sk.get_bone_global_pose(arm[1]).origin
	var c := sk.get_bone_global_pose(arm[2]).origin
	return a.distance_to(b) + b.distance_to(c)


## Рамка корпуса: начало — середина плеч, X — влево (от правого плеча к левому, по горизонтали), Y — вверх, Z — вперёд.
static func _torso(su: Vector3, sl: Vector3) -> Transform3D:
	var x := sl - su
	x.y = 0.0
	x = x.normalized() if x.length_squared() > 1e-6 else Vector3.RIGHT
	return Transform3D(Basis(x, Vector3.UP, x.cross(Vector3.UP)), (su + sl) * 0.5)


## Оружие наперевес (рамка оружия, начало — правый кулак): по CARRY вида, half — полуширина плеч, reach — длина руки.
func _carry_frame(tor: Transform3D, half: float, reach: float) -> Transform3D:
	var c: Array = CARRY.get(kind, CARRY["sword_2h"])
	var pos := tor * Vector3(-float(c[0]) * half, -float(c[1]) * reach, float(c[2]) * reach)
	var dv: Vector3 = c[3]
	var y := (tor.basis * dv).normalized()
	var fwd := tor.basis.z
	var x := fwd - y * fwd.dot(y)
	x = x.normalized() if x.length_squared() > 1e-6 else tor.basis.x
	return Transform3D(Basis(x, y, x.cross(y)), pos)


## Пальцы кисти hand (поза hand_g) добирают сгиб к ладони до FLEX × weight (уже согнутые клипом сильнее — как есть).
## Ось сгиба — поперёк ладони (ось кулака), ладонь — ±Z кулака: у левой +Z, у правой −Z (palm_sign).
func _curl(sk: Skeleton3D, hand: int, hand_g: Transform3D, chains: Array[PackedInt32Array], fist: Transform3D,
		palm_sign: float, weight: float) -> void:
	if chains.is_empty() or weight < 0.01:
		return
	var fg := hand_g * fist
	var axis := fg.basis.y.normalized()
	var palm := fg.basis.z.normalized() * palm_sign
	for ch in chains:
		var pg := _parent_global(sk, ch[0], hand, hand_g)
		var prev := (pg * sk.get_bone_pose(ch[0])).origin - hand_g.origin
		for j in mini(FLEX.size(), ch.size() - 1):
			var b: int = ch[j]
			var g := pg * sk.get_bone_pose(b)
			var v := g * sk.get_bone_pose_position(ch[j + 1]) - g.origin
			if v.length_squared() < 1e-10 or prev.length_squared() < 1e-10:
				break
			var k := axis if axis.cross(v).dot(palm) >= 0.0 else -axis
			var cur := atan2(prev.cross(v).dot(k), prev.dot(v))
			var add := clampf(float(FLEX[j]) - cur, 0.0, float(FLEX[j])) * weight
			if add > 0.001:
				var q := Quaternion(k, add)
				g.basis = Basis(q) * g.basis
				v = q * v
				sk.set_bone_pose_rotation(b, (pg.affine_inverse() * g).basis.get_rotation_quaternion())
			prev = v
			pg = g


## Поза родителя кости bone при кисти в позе hand_g (кости между кистью и пальцем — по позам клипа).
static func _parent_global(sk: Skeleton3D, bone: int, hand: int, hand_g: Transform3D) -> Transform3D:
	var path: Array[int] = []
	var p := sk.get_bone_parent(bone)
	while p >= 0 and p != hand:
		path.push_front(p)
		p = sk.get_bone_parent(p)
	if p != hand:
		return sk.get_bone_global_pose(sk.get_bone_parent(bone))
	var g := hand_g
	for b in path:
		g = g * sk.get_bone_pose(b)
	return g
