class_name Merchant
extends Npc
## Торговец в безопасной зоне: добродушный странствующий торговец (аниме-модель CharacterModel) —
## широкая шляпа с пером, усы, глаза-улыбки, фартук и большой рюкзак со скаткой и фонариком.
## Рядом ящик с товаром. Поворачивается к игроку и машет рукой, когда тот подходит (Npc).
## Товары — NpcData.shop("merchant"), окно торговли — Economy / InventoryWindow.


func _init() -> void:
	npc_id = "merchant"


func _build_extra() -> void:
	add_to_group("merchant")
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
