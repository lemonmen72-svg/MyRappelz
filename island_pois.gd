class_name IslandPois
extends RefCounted
## Постройки и точки интереса острова по конфигу (pois): город новичков, деревни рас, порт,
## пещера, лагеря, мельница, поля, загон. Всё ставится из конфига, ничего не захардкожено по месту.
## Каркас: подписи и простые заглушки. Модуль «Постройки» заменяет на низкополигональные модели.


static func build(world: IslandWorld, _rng: RandomNumberGenerator) -> void:
	var holder := Node3D.new()
	holder.name = "Pois"
	world.add_child(holder)
	for p in world.cfg.get("pois", []):
		var poi: Dictionary = p
		var c := IslandWorld.v2(poi["center"])
		var node := Node3D.new()
		node.name = String(poi.get("id", "poi"))
		node.position = world.ground(c.x, c.y, 0.0)
		holder.add_child(node)
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(2, 2, 2)
		box.mesh = bm
		box.position.y = 1.0
		box.material_override = Util.mat(Color(0.8, 0.6, 0.4))
		node.add_child(box)
		var l := Label3D.new()
		l.text = String(poi.get("name", ""))
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font_size = 48
		l.outline_size = 10
		l.pixel_size = 0.02
		l.position.y = 4.0
		node.add_child(l)
