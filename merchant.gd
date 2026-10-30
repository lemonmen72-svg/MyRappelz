class_name Merchant
extends StaticBody3D
## Торговец в безопасной зоне: добродушный странствующий торговец (аниме-модель CharacterModel) —
## широкая шляпа с пером, усы, глаза-улыбки, фартук и большой рюкзак со скаткой и фонариком.
## Рядом ящик с товаром. Поворачивается к игроку и машет рукой, когда тот подходит.

const TURN_RANGE := 10.0
const WAVE_RANGE := 6.0
const WAVE_COOLDOWN := 8.0

var _model: CharacterModel
var _near := false
var _wave_cd := 0.0


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

	_model = CharacterModel.new()
	_model.name = "Model"
	_model.setup(CharacterModel.merchant_spec())
	add_child(_model)

	# Ящик с товаром рядом (без коллизии): на крышке пара зелий
	var crate := MeshInstance3D.new()
	var crm := BoxMesh.new()
	crm.size = Vector3(0.6, 0.5, 0.6)
	crate.mesh = crm
	crate.position = Vector3(0.95, 0.25, 0.1)
	crate.material_override = Util.mat(Color(0.6, 0.45, 0.25))
	add_child(crate)
	var potions := [[Vector3(0.85, 0.58, 0.0), Color(0.9, 0.2, 0.3)], [Vector3(1.07, 0.58, 0.18), Color(0.25, 0.5, 0.95)]]
	for p in potions:
		var bottle := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = 0.08
		bm.height = 0.16
		bm.radial_segments = 10
		bm.rings = 5
		bottle.mesh = bm
		bottle.position = p[0]
		bottle.material_override = Util.mat(p[1])
		add_child(bottle)
		var cork := MeshInstance3D.new()
		var km := CylinderMesh.new()
		km.top_radius = 0.025
		km.bottom_radius = 0.03
		km.height = 0.06
		km.radial_segments = 6
		cork.mesh = km
		cork.position = p[0] + Vector3(0, 0.09, 0)
		cork.material_override = Util.mat(Color(0.55, 0.4, 0.25))
		add_child(cork)

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
	_wave_cd = maxf(0.0, _wave_cd - delta)
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	var to := p.global_position - global_position
	to.y = 0.0
	var d := to.length()
	if d > 0.1 and d < TURN_RANGE:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(-to.x, -to.z), 4.0 * delta)
	# Приветствие, когда игрок подходит
	var near := d < WAVE_RANGE
	if near and not _near and _wave_cd <= 0.0:
		_model.play_wave()
		_wave_cd = WAVE_COOLDOWN
	_near = near
