class_name CreatureModels
extends RefCounted
## Модели зверей и питомцев из простых фигур (заглушки до настоящих моделей).
## build() строит только меши в отдельном узле, коллизию добавляет add_collision().
## Передом модель смотрит в -Z.


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


## Анимация модели (вызывать каждый кадр): фея парит и машет крыльями, у искрожука пульсирует брюшко.
static func animate(root: Node3D, species: String, t: float) -> void:
	if root == null:
		return
	if species == "fairy":
		var fl := root.get_node_or_null("Float") as Node3D
		if fl == null:
			return
		var base_y: float = fl.get_meta("base_y", 0.0)
		fl.position.y = base_y + sin(t * 2.4) * 0.15
		fl.rotation.z = sin(t * 1.3) * 0.1
		var flap := sin(t * 22.0) * 0.55
		var wl := fl.get_node_or_null("WingL") as Node3D
		var wr := fl.get_node_or_null("WingR") as Node3D
		if wl != null and wr != null:
			wl.rotation.y = flap
			wr.rotation.y = -flap
	elif species == "sparkbug":
		var glow := root.get_node_or_null("Glow") as Node3D
		if glow != null:
			var k := 1.0 + sin(t * 4.0) * 0.12
			glow.scale = Vector3(k, k * 0.85, k)


## Материал без освещения: светящиеся детали, метки, снаряды.
static func flat_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


## Расходящийся круг на земле (удар по площади, лечение, эволюция). Сам исчезает.
static func spawn_ring(parent: Node, pos: Vector3, radius: float, color: Color, time: float = 0.5) -> void:
	if parent == null:
		return
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.06
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color, 0.55)
	mi.material_override = m
	parent.add_child(mi)
	mi.global_position = Vector3(pos.x, 0.06, pos.z)
	mi.scale = Vector3(0.15, 1.0, 0.15)
	var t := mi.create_tween()
	t.set_parallel(true)
	t.tween_property(mi, "scale", Vector3.ONE, time)
	t.tween_property(m, "albedo_color:a", 0.0, time)
	t.chain().tween_callback(mi.queue_free)


# ---------- Виды ----------

## Четвероногий зверь из коробок: кабан (клыки, щетина), волк (уши, хвост), медведь (горб).
static func _beast(root: Node3D, species: String, color: Color, s: float) -> StandardMaterial3D:
	var m := Util.mat(color)
	var dark := Util.mat(color.darkened(0.35))
	var eye := flat_mat(Color(0.05, 0.05, 0.05))
	_box(root, Vector3(0.9, 0.7, 1.4) * s, Vector3(0, 0.75, 0) * s, m)
	_box(root, Vector3(0.6, 0.55, 0.6) * s, Vector3(0, 0.95, -0.85) * s, m)
	_box(root, Vector3(0.34, 0.26, 0.3) * s, Vector3(0, 0.84, -1.25) * s, dark)
	for side in [-1.0, 1.0]:
		_box(root, Vector3(0.08, 0.08, 0.04) * s, Vector3(0.15 * side, 1.05, -1.16) * s, eye)
		for z in [-0.45, 0.45]:
			_box(root, Vector3(0.18, 0.4, 0.18) * s, Vector3(0.3 * side, 0.2, z) * s, dark)
	match species:
		"boar":
			var tusk := Util.mat(Color(0.95, 0.92, 0.8))
			for side in [-1.0, 1.0]:
				_box(root, Vector3(0.06, 0.2, 0.06) * s, Vector3(0.14 * side, 0.8, -1.38) * s, tusk)
			_box(root, Vector3(0.12, 0.25, 0.9) * s, Vector3(0, 1.15, -0.1) * s, dark)
		"wolf":
			for side in [-1.0, 1.0]:
				_box(root, Vector3(0.12, 0.26, 0.1) * s, Vector3(0.18 * side, 1.33, -0.8) * s, dark)
			var tail := _box(root, Vector3(0.14, 0.14, 0.7) * s, Vector3(0, 0.95, 0.95) * s, dark)
			tail.rotation.x = 0.5
		"bear":
			for side in [-1.0, 1.0]:
				_box(root, Vector3(0.16, 0.14, 0.1) * s, Vector3(0.22 * side, 1.27, -0.8) * s, dark)
			_box(root, Vector3(0.95, 0.35, 0.6) * s, Vector3(0, 1.05, -0.3) * s, m)
	return m


## Лесная фея: маленькая, парит над землёй, прозрачные крылышки, светящаяся пыльца.
static func _fairy(root: Node3D, color: Color, s: float) -> StandardMaterial3D:
	var m := Util.mat(color)
	var skin := Util.mat(Color(1.0, 0.9, 0.82))
	var fl := Node3D.new()
	fl.name = "Float"
	fl.position.y = 0.85 * s
	fl.set_meta("base_y", 0.85 * s)
	root.add_child(fl)

	# Платье-колокольчик
	var dress := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.08 * s
	cm.bottom_radius = 0.3 * s
	cm.height = 0.55 * s
	dress.mesh = cm
	dress.material_override = m
	fl.add_child(dress)

	_sphere(fl, 0.17 * s, Vector3(0, 0.42, 0) * s, skin)
	_sphere(fl, 0.18 * s, Vector3(0, 0.48, 0.05) * s, Util.mat(color.lightened(0.45)))
	var eye := flat_mat(Color(0.1, 0.15, 0.1))
	var wing_mat := StandardMaterial3D.new()
	wing_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wing_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wing_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	wing_mat.albedo_color = Color(color.lightened(0.55), 0.55)
	for side in [-1.0, 1.0]:
		_sphere(fl, 0.03 * s, Vector3(0.06 * side, 0.43, -0.15) * s, eye)
		var arm := _box(fl, Vector3(0.05, 0.28, 0.05) * s, Vector3(0.14 * side, 0.12, 0) * s, skin)
		arm.rotation.z = 0.35 * side
		var pivot := Node3D.new()
		pivot.name = "WingL" if side < 0.0 else "WingR"
		pivot.position = Vector3(0.06 * side, 0.2, 0.12) * s
		fl.add_child(pivot)
		var w := _box(pivot, Vector3(0.5, 0.6, 0.02) * s, Vector3(0.27 * side, 0.12, 0) * s, wing_mat)
		w.rotation.z = -0.3 * side
	# Светящаяся пыльца под феей
	_sphere(fl, 0.07 * s, Vector3(0, -0.4, 0) * s, flat_mat(Color(1.0, 1.0, 0.6)))
	return m


## Искрожук: панцирь, светящееся брюшко, усики с огоньками, шесть лапок.
static func _sparkbug(root: Node3D, color: Color, s: float) -> StandardMaterial3D:
	var m := Util.mat(color)
	var dark := Util.mat(color.darkened(0.6))
	var glow_c := color.lightened(0.45)
	var glow_m := flat_mat(glow_c)
	var shell := _sphere(root, 0.5 * s, Vector3(0, 0.55, -0.05) * s, m)
	shell.scale = Vector3(1.0, 0.6, 1.15)
	var glow := _sphere(root, 0.36 * s, Vector3(0, 0.5, 0.6) * s, glow_m)
	glow.name = "Glow"
	_sphere(root, 0.24 * s, Vector3(0, 0.5, -0.62) * s, dark)
	_box(root, Vector3(0.03, 0.05, 0.95) * s, Vector3(0, 0.86, -0.05) * s, dark)
	for side in [-1.0, 1.0]:
		_sphere(root, 0.05 * s, Vector3(0.1 * side, 0.56, -0.82) * s, glow_m)
		var ant := _box(root, Vector3(0.03, 0.03, 0.45) * s, Vector3(0.12 * side, 0.78, -0.9) * s, dark)
		ant.rotation = Vector3(0.6, 0.35 * side, 0.0)
		_sphere(root, 0.05 * s, Vector3(0.2 * side, 0.92, -1.08) * s, glow_m)
		for z in [-0.3, 0.0, 0.3]:
			var leg := _box(root, Vector3(0.5, 0.06, 0.06) * s, Vector3(0.5 * side, 0.25, z) * s, dark)
			leg.rotation.z = -0.5 * side
	return m


## Каменный страж: крупный гуманоид из каменных блоков, светящиеся глаза и руна на груди.
static func _golem(root: Node3D, color: Color, s: float) -> StandardMaterial3D:
	var m := Util.mat(color)
	var dark := Util.mat(color.darkened(0.3))
	var moss := Util.mat(Color(0.3, 0.5, 0.25))
	var rune := flat_mat(Color(0.4, 0.95, 1.0))
	for side in [-1.0, 1.0]:
		_box(root, Vector3(0.34, 0.7, 0.4) * s, Vector3(0.25 * side, 0.35, 0) * s, dark)
		_box(root, Vector3(0.32, 0.8, 0.32) * s, Vector3(0.68 * side, 1.15, 0) * s, dark)
		_box(root, Vector3(0.42, 0.38, 0.42) * s, Vector3(0.7 * side, 0.62, -0.02) * s, m)
		_box(root, Vector3(0.4, 0.3, 0.45) * s, Vector3(0.62 * side, 1.6, 0) * s, m)
		_box(root, Vector3(0.08, 0.06, 0.04) * s, Vector3(0.1 * side, 1.98, -0.23) * s, rune)
	_box(root, Vector3(0.75, 0.3, 0.45) * s, Vector3(0, 0.8, 0) * s, dark)
	_box(root, Vector3(1.0, 0.75, 0.6) * s, Vector3(0, 1.3, 0) * s, m)
	_box(root, Vector3(0.45, 0.4, 0.42) * s, Vector3(0, 1.92, 0) * s, m)
	_box(root, Vector3(0.22, 0.22, 0.05) * s, Vector3(0, 1.35, -0.31) * s, rune)
	_box(root, Vector3(0.5, 0.08, 0.3) * s, Vector3(0.62, 1.78, 0.05) * s, moss)
	return m


# ---------- Примитивы ----------

static func _box(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = m
	parent.add_child(mi)
	return mi


static func _sphere(parent: Node3D, radius: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	mi.position = pos
	mi.material_override = m
	parent.add_child(mi)
	return mi
