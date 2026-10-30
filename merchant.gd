class_name Merchant
extends StaticBody3D
## Торговец в безопасной зоне: простая фигура из примитивов и подпись. Поворачивается к игроку.

const TURN_RANGE := 10.0

var _model: Node3D


func _ready() -> void:
	add_to_group("merchant")
	collision_layer = 1
	collision_mask = 0

	var col := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 0.45
	cs.height = 1.9
	col.shape = cs
	col.position.y = 0.95
	add_child(col)

	_model = Node3D.new()
	add_child(_model)

	# Мантия
	var robe := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.26
	rm.bottom_radius = 0.5
	rm.height = 1.3
	robe.mesh = rm
	robe.position.y = 0.65
	robe.material_override = Util.mat(Color(0.18, 0.42, 0.48))
	_model.add_child(robe)

	# Пояс
	var belt := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.37
	bm.bottom_radius = 0.37
	bm.height = 0.08
	belt.mesh = bm
	belt.position.y = 0.75
	belt.material_override = Util.mat(Color(0.85, 0.65, 0.2))
	_model.add_child(belt)

	# Голова
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.24
	hm.height = 0.48
	head.mesh = hm
	head.position.y = 1.52
	head.material_override = Util.mat(Color(0.95, 0.8, 0.65))
	_model.add_child(head)

	# Нос: видно, куда смотрит торговец (вперёд = -Z)
	var nose := MeshInstance3D.new()
	var nm := BoxMesh.new()
	nm.size = Vector3(0.08, 0.08, 0.1)
	nose.mesh = nm
	nose.position = Vector3(0, 1.5, -0.25)
	nose.material_override = Util.mat(Color(0.9, 0.7, 0.55))
	_model.add_child(nose)

	# Шляпа: поля и конус
	var hat_mat := Util.mat(Color(0.72, 0.5, 0.2))
	var brim := MeshInstance3D.new()
	var brm := CylinderMesh.new()
	brm.top_radius = 0.45
	brm.bottom_radius = 0.45
	brm.height = 0.04
	brim.mesh = brm
	brim.position.y = 1.7
	brim.material_override = hat_mat
	_model.add_child(brim)
	var hat := MeshInstance3D.new()
	var htm := CylinderMesh.new()
	htm.top_radius = 0.0
	htm.bottom_radius = 0.28
	htm.height = 0.45
	hat.mesh = htm
	hat.position.y = 1.94
	hat.material_override = hat_mat
	_model.add_child(hat)

	# Заплечный мешок с товаром
	var pack := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.55, 0.65, 0.3)
	pack.mesh = pm
	pack.position = Vector3(0, 1.05, 0.38)
	pack.material_override = Util.mat(Color(0.5, 0.35, 0.2))
	_model.add_child(pack)

	# Ящик с товаром рядом (без коллизии)
	var crate := MeshInstance3D.new()
	var crm := BoxMesh.new()
	crm.size = Vector3(0.6, 0.5, 0.6)
	crate.mesh = crm
	crate.position = Vector3(0.95, 0.25, 0.1)
	crate.material_override = Util.mat(Color(0.6, 0.45, 0.25))
	add_child(crate)

	var label := Label3D.new()
	label.text = "Торговец"
	label.modulate = Color(1.0, 0.85, 0.35)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.01
	label.font_size = 44
	label.outline_size = 10
	label.position.y = 2.55
	add_child(label)


func _process(delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	var to := p.global_position - global_position
	to.y = 0.0
	var d := to.length()
	if d > 0.1 and d < TURN_RANGE:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(-to.x, -to.z), 4.0 * delta)
