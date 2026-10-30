class_name CreatureModels
extends RefCounted
## Модели зверей и питомцев в аниме-стиле (чиби): округлые формы из сфер и капсул, большие глаза
## с бликами, румянец, характерные детали вида. Всё своё, из примитивов.
## build() строит только меши в отдельном узле, коллизию добавляет add_collision().
## Передом модель смотрит в -Z. Части для анимации хранятся в meta "anim" корня модели.
## Питомцы: decorate_pet() добавляет ошейник цвета роли и украшения по стадии эволюции.

## Цвета ролей питомцев (ошейник, бантик, узоры).
const ROLE_COLORS := {
	"tank": Color(0.35, 0.6, 1.0),
	"fighter": Color(1.0, 0.38, 0.35),
	"mage": Color(0.72, 0.45, 1.0),
	"healer": Color(1.0, 0.58, 0.8),
}
const BLUSH := Color(1.0, 0.45, 0.55, 0.55)
const GOLD := Color(1.0, 0.82, 0.3)

static var _mesh_cache := {}
static var _flat_cache := {}


## Строит модель вида species в root. Возвращает основной материал (цвет color, для вспышки при ударе).
static func build(root: Node3D, species: String, color: Color, s: float) -> StandardMaterial3D:
	match species:
		"fairy":
			return _fairy(root, color, s)
		"sparkbug":
			return _sparkbug(root, color, s)
		"golem":
			return _golem(root, color, s)
	return _beast(root, species, color, s)


## Высота макушки модели над землёй (для подписи и значков над головой).
static func height(species: String, s: float) -> float:
	match species:
		"fairy":
			return 1.75 * s
		"sparkbug":
			return 1.1 * s
		"golem":
			return 2.15 * s
	return 1.4 * s


## Коробка-коллизия вида, нижняя грань на уровне земли.
static func add_collision(body: Node3D, species: String, s: float) -> CollisionShape3D:
	var size := Vector3(0.9, 1.2, 1.5)
	match species:
		"fairy":
			size = Vector3(0.6, 1.2, 0.6)
		"sparkbug":
			size = Vector3(1.0, 0.8, 1.5)
		"golem":
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


## Анимация модели (вызывать каждый кадр). moving: 0 — стоит, 1 — бежит на полной скорости.
## Звери покачиваются и переставляют лапы, фея парит и машет крыльями, у искрожука пульсирует
## брюшко, у стража кружат рунные камни.
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
		"fairy":
			if body != null:
				body.position.y = float(a.get("base_y", 0.0)) + sin(t * 2.4) * 0.15 * s
				body.rotation.z = sin(t * 1.3) * 0.08
				body.rotation.x = -0.25 * mv
			var flap := sin(t * 22.0) * 0.55
			var wl: Node3D = a.get("wing_l")
			var wr: Node3D = a.get("wing_r")
			if wl != null and wr != null:
				wl.rotation.y = flap
				wr.rotation.y = -flap
			if head != null:
				head.rotation.z = sin(t * 1.6) * 0.1
		"bug":
			if body != null:
				body.position.y = absf(sin(t * 14.0)) * 0.03 * s * mv + sin(t * 2.0) * 0.012 * s
			for i in legs.size():
				var leg := legs[i] as Node3D
				leg.rotation.x = sin(t * 16.0 + float(i) * 2.1) * (0.15 + 0.45 * mv)
			var ants: Array = a.get("ants", [])
			for i in ants.size():
				var ant := ants[i] as Node3D
				ant.rotation.y = sin(t * 3.0 + float(i) * 1.7) * 0.25
			if head != null:
				head.rotation.z = sin(t * 1.4) * 0.08
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
	# Общие детали: свечение (брюшко искрожука, ореол феи) и нимб питомца 3-й стадии
	var glow: Node3D = a.get("glow")
	if glow != null:
		var k := 1.0 + sin(t * 4.0) * 0.12
		var gb: Vector3 = glow.get_meta("base", Vector3.ONE)
		glow.scale = gb * k
	var halo: Node3D = a.get("halo")
	if halo != null:
		halo.rotation.y = t * 1.5
		halo.position.y = float(a.get("halo_y", 0.0)) + sin(t * 2.5) * 0.04


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
static func decorate_pet(root: Node3D, species: String, s: float, stage: int, role: String) -> void:
	var rc := role_color(role)
	var a: Dictionary = root.get_meta("anim", {})
	var neck := root.find_child("Neck", true, false) as Node3D
	if neck != null:
		var r := float(neck.get_meta("r", 0.25 * s))
		var collar := _torus(neck, r, r + 0.075 * s, Vector3.ZERO, Util.mat(rc))
		collar.name = "Collar"
		var host := neck.get_parent() as Node3D
		var off: Vector3 = neck.get_meta("charm", Vector3(0, -r, 0))
		_ball(host, 0.065 * s, neck.position + off, Util.mat(GOLD))
	if stage >= 1:
		var bow := root.find_child("Bow", true, false) as Node3D
		if bow != null:
			var bm := Util.mat(rc.lightened(0.15))
			for i in 2:
				var side := float(i * 2 - 1)
				var loop := _ball(bow, 0.085 * s, Vector3(0.085 * side * s, 0.0, 0.0), bm, Vector3(1.0, 0.65, 0.45))
				loop.rotation.z = -0.35 * side
			_ball(bow, 0.045 * s, Vector3.ZERO, Util.mat(rc.darkened(0.15)))
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
				var mk := _ball(back, msize, p, mark_m, Vector3(1.0, 0.75, 0.3), true)
				_face(mk, n)
				mk.name = "Mark%d" % i
	if stage >= 2:
		var top := root.find_child("Top", true, false) as Node3D
		if top != null:
			var holder := Node3D.new()
			holder.name = "Halo"
			top.add_child(holder)
			var hy := 0.22 * s + 0.08
			holder.position.y = hy
			var ring := _torus(holder, 0.17 * s, 0.22 * s, Vector3.ZERO, _flat(Color(1.0, 0.92, 0.5)), true)
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
	root.set_meta("anim", a)


# ---------- Виды ----------

## Четвероногий зверь-чиби: кабан (пятачок, клыки, хохолок, хвостик-завиток), волк (уши торчком,
## пушистый хвост, светлая грудка), медведь (круглые уши, пузико, короткий хвостик).
static func _beast(root: Node3D, species: String, color: Color, s: float) -> StandardMaterial3D:
	var boar := species == "boar"
	var wolf := species == "wolf"
	var bear := species == "bear"
	var m := Util.mat(color)
	var light := Util.mat(color.lightened(0.42))
	var dark := Util.mat(color.darkened(0.3))
	var anim := {"kind": "quad", "s": s}

	var body := _pivot(root, "Body", Vector3.ZERO)
	anim["body"] = body
	var torso_sc := Vector3(0.95, 0.85, 1.15) if bear else Vector3(0.86, 0.76, 1.2)
	_ball(body, 0.5 * s, Vector3(0, 0.7, 0.05) * s, m, torso_sc, false, 16)
	if bear:
		_ball(body, 0.34 * s, Vector3(0, 0.6, -0.26) * s, light, Vector3(0.95, 0.9, 1.0))
	elif wolf:
		_ball(body, 0.27 * s, Vector3(0, 0.82, -0.48) * s, light, Vector3(1.0, 1.1, 0.75))

	# Голова
	var hr := (0.4 if bear else (0.36 if wolf else 0.38)) * s
	var head := _pivot(body, "Head", Vector3(0, 1.02 if bear else 1.0, -0.62) * s)
	anim["head"] = head
	_ball(head, hr, Vector3.ZERO, m, Vector3(1.05, 0.95, 0.95), false, 16)
	var iris := Color(0.16, 0.1, 0.07)
	if wolf:
		iris = Color(0.16, 0.3, 0.55)
	_eyes(head, hr, 0.115 * s, iris, 0.46, 0.2 if boar else 0.17, true)
	_blush(head, hr, 0.07 * s)

	if boar:
		# Пятачок с ноздрями и клыки
		var snout_m := Util.mat(color.lerp(Color(1.0, 0.7, 0.68), 0.55))
		var snout := _cyl(head, 0.13 * s, 0.13 * s, 0.15 * s, Vector3(0, -0.13 * s, -hr - 0.02 * s), snout_m)
		snout.rotation.x = PI / 2.0
		var nost := _flat(Color(0.35, 0.18, 0.15))
		var tusk_m := Util.mat(Color(1.0, 0.97, 0.88))
		for i in 2:
			var side := float(i * 2 - 1)
			_ball(head, 0.032 * s, Vector3(0.05 * side * s, -0.13 * s, -hr - 0.095 * s), nost,
				Vector3(0.8, 1.2, 0.4), true)
			var tusk := _cyl(head, 0.0, 0.04 * s, 0.15 * s, Vector3(0.12 * side * s, -0.21 * s, -hr * 0.92 - 0.03 * s), tusk_m, true)
			tusk.rotation = Vector3(-0.35, 0.0, -0.4 * side)
			# Ушки-треугольники, чуть свисают вперёд
			var ear := _cyl(head, 0.0, 0.1 * s, 0.2 * s, Vector3(0.25 * side, 0.27, 0.02) * s, dark)
			ear.rotation = Vector3(-0.45, 0.0, -0.7 * side)
		# Хохолок из трёх прядей
		var tuft_m := Util.mat(color.darkened(0.45).lerp(Color(0.95, 0.55, 0.25), 0.3))
		for i in 3:
			var tuft := _cyl(head, 0.0, (0.08 - 0.012 * float(i)) * s, (0.26 - 0.04 * float(i)) * s,
				Vector3(0, 0.36 - 0.05 * float(i), 0.0 + 0.11 * float(i)) * s, tuft_m)
			tuft.rotation.x = 0.55 + 0.25 * float(i)
	elif wolf:
		# Мордочка, носик, уши торчком с розовой серединкой
		_ball(head, 0.17 * s, Vector3(0, -0.1 * s, -hr * 0.93), light, Vector3(0.9, 0.72, 1.25))
		_ball(head, 0.055 * s, Vector3(0, -0.06 * s, -hr - 0.17 * s), _flat(Color(0.12, 0.1, 0.12)),
			Vector3(1.2, 0.85, 0.8), true)
		var inner := _flat(Color(1.0, 0.7, 0.75))
		for i in 2:
			var side := float(i * 2 - 1)
			var ear := _cyl(head, 0.0, 0.12 * s, 0.32 * s, Vector3(0.19 * side, 0.33, 0.03) * s, dark)
			ear.rotation = Vector3(-0.1, 0.0, -0.28 * side)
			ear.scale = Vector3(1.0, 1.0, 0.6)
			var ein := _cyl(head, 0.0, 0.065 * s, 0.2 * s, Vector3(0.185 * side, 0.31, 0.0) * s, inner, true)
			ein.rotation = Vector3(-0.1, 0.0, -0.28 * side)
			ein.scale = Vector3(1.0, 1.0, 0.45)
	else:
		# Медведь: светлая мордочка, носик, круглые ушки
		_ball(head, 0.18 * s, Vector3(0, -0.11 * s, -hr * 0.88), light, Vector3(1.1, 0.82, 0.9))
		_ball(head, 0.06 * s, Vector3(0, -0.05 * s, -hr - 0.11 * s), _flat(Color(0.1, 0.07, 0.06)),
			Vector3(1.25, 0.85, 0.8), true)
		var inner := _flat(color.lightened(0.5).lerp(Color(1.0, 0.75, 0.7), 0.4))
		for i in 2:
			var side := float(i * 2 - 1)
			_ball(head, 0.13 * s, Vector3(0.28 * side, 0.28, 0.02) * s, dark, Vector3(1.0, 1.0, 0.6))
			_ball(head, 0.075 * s, Vector3(0.28 * side, 0.28, -0.045) * s, inner, Vector3(1.0, 1.0, 0.4), true)

	# Хвост
	var tail := _pivot(body, "Tail", Vector3(0, 0.88, 0.62) * s)
	anim["tail"] = tail
	if boar:
		var curl := _torus(tail, 0.045 * s, 0.085 * s, Vector3(0, 0.02, 0.06) * s, Util.mat(color.lerp(Color(1.0, 0.7, 0.68), 0.3)))
		curl.rotation.z = PI / 2.0
	elif wolf:
		tail.rotation.x = -0.75
		_ball(tail, 0.17 * s, Vector3(0, 0, 0.3) * s, m, Vector3(0.8, 0.8, 1.9))
		_ball(tail, 0.13 * s, Vector3(0, 0, 0.6) * s, light)
	else:
		_ball(tail, 0.1 * s, Vector3(0, -0.04, 0.02) * s, m)

	# Лапки на шарнирах у бедра
	var legs: Array = []
	var lr := (0.14 if bear else 0.12) * s
	var zs := [-0.34, 0.38]
	for zi in 2:
		for i in 2:
			var side := float(i * 2 - 1)
			var hip := _pivot(root, "Leg", Vector3(0.27 * side, 0.4, float(zs[zi])) * s)
			_capsule(hip, lr, 0.46 * s, Vector3(0, -0.17 * s, 0), dark)
			legs.append(hip)
	# Порядок для походки: передняя левая, передняя правая, задняя левая, задняя правая
	anim["legs"] = legs

	# Точки для украшений питомца
	# Ошейник — кольцо сразу за головой, бубенчик на груди
	var neck := _pivot(body, "Neck", Vector3(0, 0.72, -0.33) * s)
	neck.rotation.x = -1.32
	neck.set_meta("r", (0.4 if bear else 0.36) * s)
	neck.set_meta("charm", Vector3(0, -0.14, -0.27) * s)
	var bow := _pivot(head, "Bow", Vector3(-0.17, 0.29, -0.12) * s)
	bow.rotation.z = 0.35
	_pivot(head, "Top", Vector3(0, hr * 0.95, 0))
	var back := _pivot(body, "Back", Vector3(0, 0.7, 0.05) * s)
	back.set_meta("radii", Vector3(0.5 * torso_sc.x, 0.5 * torso_sc.y, 0.5 * torso_sc.z) * s)
	root.set_meta("anim", anim)
	return m


## Лесная фея: девочка-цветок с платьем-колокольчиком из лепестков, листиком на макушке,
## четырьмя прозрачными крылышками и мягким сиянием. Парит над землёй.
static func _fairy(root: Node3D, color: Color, s: float) -> StandardMaterial3D:
	var m := Util.mat(color)
	var petal := Util.mat(color.lightened(0.3))
	var skin := Util.mat(Color(1.0, 0.9, 0.82))
	var hair := Util.mat(color.lerp(Color(1.0, 0.95, 0.6), 0.35))
	var anim := {"kind": "fairy", "s": s}
	var fl := _pivot(root, "Float", Vector3(0, 0.8, 0) * s)
	anim["body"] = fl
	anim["base_y"] = 0.8 * s

	# Платье-колокольчик и лепестки подола
	_cyl(fl, 0.09 * s, 0.25 * s, 0.42 * s, Vector3(0, -0.05, 0) * s, m)
	for i in 4:
		var ang := TAU * float(i) / 4.0 + PI / 4.0
		var d := Vector3(cos(ang), -0.6, sin(ang)).normalized()
		var p := _ball(fl, 0.13 * s, Vector3(cos(ang) * 0.2, -0.24, sin(ang) * 0.2) * s, petal, Vector3(0.8, 0.3, 1.4))
		_face(p, d)
	# Ручки
	for i in 2:
		var side := float(i * 2 - 1)
		var arm := _capsule(fl, 0.035 * s, 0.2 * s, Vector3(0.12 * side, 0.07, 0) * s, skin)
		arm.rotation.z = 0.45 * side

	# Голова, волосы, листик и цветок
	var head := _pivot(fl, "Head", Vector3(0, 0.36, 0) * s)
	anim["head"] = head
	var hr := 0.2 * s
	_ball(head, hr, Vector3.ZERO, skin, Vector3.ONE, false, 16)
	_ball(head, 0.205 * s, Vector3(0, 0.055, 0.055) * s, hair, Vector3(1.06, 1.0, 1.0), false, 16)
	var leaf := _ball(head, 0.08 * s, Vector3(0.02, 0.27, 0.0) * s, Util.mat(Color(0.45, 0.85, 0.35)), Vector3(0.45, 0.14, 1.0))
	leaf.rotation = Vector3(0.3, 0.5, 0.9)
	_ball(head, 0.05 * s, Vector3(0.14, 0.15, -0.08) * s, Util.mat(Color(1.0, 0.6, 0.8)))
	_eyes(head, hr, 0.065 * s, Color(0.15, 0.45, 0.3), 0.4, -0.05, false)
	_blush(head, hr, 0.04 * s)

	# Крылышки: по два с каждой стороны, на шарнирах для взмахов
	var wing_m := Vfx.fx_mat(Color(color.lightened(0.6), 0.5), null, false)
	for i in 2:
		var side := float(i * 2 - 1)
		var pivot := _pivot(fl, "WingL" if side < 0.0 else "WingR", Vector3(0.05 * side, 0.12, 0.1) * s)
		var up := _ball(pivot, 0.18 * s, Vector3(0.2 * side, 0.12, 0) * s, wing_m, Vector3(1.1, 0.75, 0.06), true)
		up.rotation.z = 0.5 * side
		var low := _ball(pivot, 0.12 * s, Vector3(0.14 * side, -0.07, 0.02) * s, wing_m, Vector3(1.0, 0.7, 0.06), true)
		low.rotation.z = -0.45 * side
		anim["wing_l" if side < 0.0 else "wing_r"] = pivot

	# Светящаяся пыльца и сияние вокруг
	_ball(fl, 0.06 * s, Vector3(0, -0.36, 0) * s, _flat(Color(1.0, 1.0, 0.65)), Vector3.ONE, true)
	var glow := MeshInstance3D.new()
	glow.set_meta("no_outline", true)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.mesh = Vfx._quad()
	glow.material_override = Vfx.fx_mat(Color(color.lightened(0.4), 0.4), Vfx.tex("dot"), true, BaseMaterial3D.BILLBOARD_ENABLED)
	glow.scale = Vector3.ONE * 1.3 * s
	glow.position = Vector3(0, 0.15, 0) * s
	fl.add_child(glow)
	glow.set_meta("base", glow.scale)
	anim["glow"] = glow
	var sp := Vfx.ambient_sparkles(fl, Color(1.0, 1.0, 0.7), 0.3 * s, 5)
	sp.position.y = -0.1 * s

	# Точки для украшений питомца
	var neck := _pivot(fl, "Neck", Vector3(0, 0.17, 0) * s)
	neck.set_meta("r", 0.1 * s)
	neck.set_meta("charm", Vector3(0, -0.02, -0.11) * s)
	var bow := _pivot(head, "Bow", Vector3(-0.17, 0.19, 0.03) * s)
	bow.rotation.z = 0.5
	_pivot(head, "Top", Vector3(0, 0.3, 0) * s)
	var back := _pivot(fl, "Back", Vector3(0, -0.1, 0) * s)
	back.set_meta("radii", Vector3(0.19, 0.2, 0.19) * s)
	back.set_meta("u", Vector3(0.5, 0.0, -0.85))
	root.set_meta("anim", anim)
	return m


## Искрожук: круглый жучок-светлячок — панцирь из двух половинок с пятнышками, светлая мордочка
## с большими глазами, усики с огоньками, светящееся брюшко, шесть коротких лапок.
static func _sparkbug(root: Node3D, color: Color, s: float) -> StandardMaterial3D:
	var m := Util.mat(color)
	var dark := Util.mat(color.darkened(0.55))
	var face_m := Util.mat(color.lerp(Color(1.0, 0.92, 0.75), 0.55))
	var glow_c := color.lightened(0.5)
	var anim := {"kind": "bug", "s": s}
	var body := _pivot(root, "Body", Vector3.ZERO)
	anim["body"] = body

	# Панцирь-надкрылья с пятнышками
	var spot := _flat(color.darkened(0.6))
	for i in 2:
		var side := float(i * 2 - 1)
		var half := _ball(body, 0.42 * s, Vector3(0.2 * side, 0.6, 0.0) * s, m, Vector3(0.6, 0.62, 1.08), false, 16)
		half.rotation.z = 0.12 * side
		var sp := _ball(body, 0.09 * s, Vector3(0.24 * side, 0.83, -0.05) * s, spot, Vector3(1.0, 0.3, 1.1), true)
		sp.rotation.z = 0.35 * side
	# Светящееся брюшко
	var glow := _ball(body, 0.3 * s, Vector3(0, 0.5, 0.46) * s, _flat(glow_c), Vector3(1.0, 0.85, 1.0), true)
	glow.name = "Glow"
	glow.set_meta("base", glow.scale)
	anim["glow"] = glow

	# Голова-мордочка
	var hr := 0.3 * s
	var head := _pivot(body, "Head", Vector3(0, 0.56, -0.5) * s)
	anim["head"] = head
	_ball(head, hr, Vector3.ZERO, face_m, Vector3(1.05, 0.95, 0.95), false, 16)
	_eyes(head, hr, 0.105 * s, Color(0.12, 0.08, 0.14), 0.46, 0.14, true)
	_blush(head, hr, 0.055 * s)
	# Усики с огоньками
	var ants: Array = []
	var tip_m := _flat(glow_c.lightened(0.2))
	var stalk := Util.mat(color.darkened(0.5))
	for i in 2:
		var side := float(i * 2 - 1)
		var ant := _pivot(head, "Antenna", Vector3(0.1 * side, 0.22, -0.04) * s)
		ant.rotation = Vector3(-0.45, 0.0, -0.45 * side)
		_cyl(ant, 0.018 * s, 0.025 * s, 0.36 * s, Vector3(0, 0.18, 0) * s, stalk, true)
		_ball(ant, 0.065 * s, Vector3(0, 0.38, 0) * s, tip_m, Vector3.ONE, true)
		ants.append(ant)
	anim["ants"] = ants

	# Лапки
	var legs: Array = []
	for zi in 3:
		var z := -0.25 + 0.28 * float(zi)
		for i in 2:
			var side := float(i * 2 - 1)
			var hip := _pivot(body, "Leg", Vector3(0.3 * side, 0.36, z) * s)
			hip.rotation.z = 0.55 * side
			_capsule(hip, 0.06 * s, 0.36 * s, Vector3(0, -0.17, 0) * s, dark)
			legs.append(hip)
	anim["legs"] = legs

	# Точки для украшений питомца
	var neck := _pivot(body, "Neck", Vector3(0, 0.56, -0.42) * s)
	neck.rotation.x = PI / 2.0
	neck.set_meta("r", 0.33 * s)
	neck.set_meta("charm", Vector3(0, -0.29, -0.08) * s)
	var bow := _pivot(head, "Bow", Vector3(-0.21, 0.22, 0.04) * s)
	bow.rotation.z = 0.5
	_pivot(head, "Top", Vector3(0, 0.34, 0) * s)
	var back := _pivot(body, "Back", Vector3(0, 0.6, 0) * s)
	back.set_meta("radii", Vector3(0.45, 0.26, 0.45) * s)
	back.set_meta("u", Vector3(0.45, 0.75, 0.5))
	root.set_meta("anim", anim)
	return m


## Каменный страж: круглый добродушный великан-валун — мох и росток на голове, светящиеся глаза,
## руна на груди, кулаки-булыжники и три рунных камня, кружащих вокруг.
static func _golem(root: Node3D, color: Color, s: float) -> StandardMaterial3D:
	var m := Util.mat(color)
	var dark := Util.mat(color.darkened(0.25))
	var moss := Util.mat(Color(0.35, 0.62, 0.3))
	var rune_c := Color(0.45, 0.95, 1.0)
	var rune := _flat(rune_c)
	var anim := {"kind": "golem", "s": s}

	# Ножки на шарнирах
	var legs: Array = []
	for i in 2:
		var side := float(i * 2 - 1)
		var hip := _pivot(root, "Leg", Vector3(0.28 * side, 0.62, 0.0) * s)
		_capsule(hip, 0.21 * s, 0.66 * s, Vector3(0, -0.29, 0) * s, dark)
		legs.append(hip)
	anim["legs"] = legs

	var body := _pivot(root, "Body", Vector3.ZERO)
	anim["body"] = body
	_ball(body, 0.6 * s, Vector3(0, 1.12, 0) * s, m, Vector3(1.08, 0.92, 0.82), false, 16)
	var chest := _box(body, Vector3(0.18, 0.18, 0.05) * s, Vector3(0, 1.15, -0.49) * s, rune)
	chest.rotation.z = PI / 4.0
	chest.set_meta("no_outline", true)

	# Голова
	var hr := 0.32 * s
	var head := _pivot(body, "Head", Vector3(0, 1.8, -0.02) * s)
	anim["head"] = head
	_ball(head, hr, Vector3.ZERO, m, Vector3(1.1, 0.95, 1.0), false, 16)
	for i in 2:
		var side := float(i * 2 - 1)
		var d := Vector3(0.38 * side, 0.05, -1.0).normalized()
		var eye := _ball(head, 0.075 * s, d * hr * 0.95, rune, Vector3(0.85, 1.2, 0.4), true)
		_face(eye, d)
	_blush(head, hr, 0.06 * s)
	_ball(head, 0.27 * s, Vector3(0, 0.2, 0.03) * s, moss, Vector3(1.15, 0.42, 1.1))
	var leaf_m := Util.mat(Color(0.5, 0.88, 0.4))
	for i in 2:
		var side := float(i * 2 - 1)
		var leaf := _ball(head, 0.075 * s, Vector3(0.06 * side, 0.36, 0.0) * s, leaf_m, Vector3(1.0, 0.16, 0.5))
		leaf.rotation.z = 0.55 * side

	# Руки с кулаками-булыжниками
	var arms: Array = []
	for i in 2:
		var side := float(i * 2 - 1)
		var sh := _pivot(body, "Arm", Vector3(0.7 * side, 1.45, 0.0) * s)
		sh.rotation.z = 0.15 * side
		_capsule(sh, 0.15 * s, 0.56 * s, Vector3(0, -0.24, 0) * s, dark)
		_ball(sh, 0.24 * s, Vector3(0, -0.58, -0.03) * s, m)
		arms.append(sh)
	anim["arms"] = arms

	# Рунные камни на орбите
	var runes := _pivot(root, "Runes", Vector3(0, 1.25, 0) * s)
	anim["runes"] = runes
	anim["runes_y"] = 1.25 * s
	for i in 3:
		var ang := TAU * float(i) / 3.0
		var stone := _box(runes, Vector3(0.17, 0.2, 0.17) * s,
			Vector3(cos(ang) * 0.98, 0.12 * float(i) - 0.1, sin(ang) * 0.98) * s, dark)
		stone.rotation = Vector3(0.35, -ang + PI / 2.0, 0.25)
		var glyph := _box(stone, Vector3(0.08, 0.11, 0.02) * s, Vector3(0, 0, -0.09) * s, rune)
		glyph.set_meta("no_outline", true)

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
	return m


# ---------- Части лица ----------

## Большие аниме-глаза на голове head (центр головы в нуле head, радиус hr): тёмный овал iris,
## крупный блик сверху и маленький снизу (two_hl). Без контура.
static func _eyes(head: Node3D, hr: float, er: float, iris: Color, spread: float, lift: float, two_hl: bool) -> void:
	var im := _flat(iris)
	var hm := _flat(Color(1, 1, 1))
	for i in 2:
		var side := float(i * 2 - 1)
		var d := Vector3(spread * side, lift, -1.0).normalized()
		var c := d * hr * 0.93
		var e := _ball(head, er, c, im, Vector3(0.8, 1.0, 0.45), true)
		_face(e, d)
		# Блики одинаковы для обоих глаз (свет с одной стороны), чуть впереди овала
		var h1 := _ball(head, er * 0.34, c + d * er * 0.4 + Vector3(er * 0.25, er * 0.36, 0), hm, Vector3(1, 1, 0.5), true)
		_face(h1, d)
		if two_hl:
			var h2 := _ball(head, er * 0.16, c + d * er * 0.42 + Vector3(-er * 0.25, -er * 0.38, 0), hm, Vector3(1, 1, 0.5), true)
			_face(h2, d)


## Розовый румянец на щеках.
static func _blush(head: Node3D, hr: float, br: float) -> void:
	var bm := _blush_mat()
	for i in 2:
		var side := float(i * 2 - 1)
		var d := Vector3(0.78 * side, -0.2, -0.85).normalized()
		var b := _ball(head, br, d * hr * 0.97, bm, Vector3(1.0, 0.55, 0.3), true, 10)
		_face(b, d)


# ---------- Примитивы ----------

## Пустой узел-шарнир.
static func _pivot(parent: Node3D, pname: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = pname
	n.position = pos
	parent.add_child(n)
	return n


## Поворачивает узел так, чтобы его -Z смотрел по направлению d.
static func _face(n: Node3D, d: Vector3) -> void:
	var dn := d.normalized()
	n.rotation = Vector3(asin(clampf(dn.y, -1.0, 1.0)), atan2(-dn.x, -dn.z), 0.0)


static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, m: Material, no_outline: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if no_outline:
		# Мелкие детали (глаза, блики, румянец, узоры): без контура и без тени
		mi.set_meta("no_outline", true)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = m
	parent.add_child(mi)
	return mi


static func _ball(parent: Node3D, radius: float, pos: Vector3, m: Material, sc: Vector3 = Vector3.ONE,
		no_outline: bool = false, seg: int = 12) -> MeshInstance3D:
	var key := "s|%.4f|%d" % [radius, seg]
	var sm: SphereMesh = _mesh_cache.get(key)
	if sm == null:
		sm = SphereMesh.new()
		sm.radius = radius
		sm.height = radius * 2.0
		sm.radial_segments = seg
		sm.rings = maxi(4, int(seg / 2.0))
		_mesh_cache[key] = sm
	var mi := _add(parent, sm, pos, m, no_outline)
	mi.scale = sc
	return mi


static func _capsule(parent: Node3D, radius: float, h: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var key := "c|%.4f|%.4f" % [radius, h]
	var cm: CapsuleMesh = _mesh_cache.get(key)
	if cm == null:
		cm = CapsuleMesh.new()
		cm.radius = radius
		cm.height = maxf(h, radius * 2.0)
		cm.radial_segments = 10
		cm.rings = 3
		_mesh_cache[key] = cm
	return _add(parent, cm, pos, m, false)


## Цилиндр или конус (top = 0) вдоль оси Y.
static func _cyl(parent: Node3D, top: float, bottom: float, h: float, pos: Vector3, m: Material,
		no_outline: bool = false) -> MeshInstance3D:
	var key := "y|%.4f|%.4f|%.4f" % [top, bottom, h]
	var cm: CylinderMesh = _mesh_cache.get(key)
	if cm == null:
		cm = CylinderMesh.new()
		cm.top_radius = top
		cm.bottom_radius = bottom
		cm.height = h
		cm.radial_segments = 10
		cm.rings = 1
		_mesh_cache[key] = cm
	return _add(parent, cm, pos, m, no_outline)


static func _torus(parent: Node3D, inner: float, outer: float, pos: Vector3, m: Material,
		no_outline: bool = false) -> MeshInstance3D:
	var key := "t|%.4f|%.4f" % [inner, outer]
	var tm: TorusMesh = _mesh_cache.get(key)
	if tm == null:
		tm = TorusMesh.new()
		tm.inner_radius = inner
		tm.outer_radius = outer
		tm.rings = 20
		tm.ring_segments = 8
		_mesh_cache[key] = tm
	return _add(parent, tm, pos, m, no_outline)


static func _box(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = m
	parent.add_child(mi)
	return mi


## Материал без освещения (общий для одинаковых цветов): глаза, блики, узоры, светящиеся детали.
static func _flat(c: Color) -> StandardMaterial3D:
	var key := c.to_html(true)
	if _flat_cache.has(key):
		return _flat_cache[key]
	var m := flat_mat(c)
	_flat_cache[key] = m
	return m


static func _blush_mat() -> StandardMaterial3D:
	if _flat_cache.has("blush"):
		return _flat_cache["blush"]
	var m := flat_mat(BLUSH)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flat_cache["blush"] = m
	return m
