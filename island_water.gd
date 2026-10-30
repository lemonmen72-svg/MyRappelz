class_name IslandWater
extends RefCounted
## Вода острова: океан вокруг, река по линиям конфига, пруды.
## Каркас: простая полупрозрачная вода. Модуль «Вода и берег» заменяет на стилизованные шейдеры.


static func build(world: IslandWorld) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.55, 0.85, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.2

	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	var pm := PlaneMesh.new()
	pm.size = Vector2(900, 900)
	sea.mesh = pm
	sea.position.y = world.sea_level
	sea.material_override = mat
	sea.set_meta("no_outline", true)
	world.add_child(sea)

	var river: Dictionary = world.cfg.get("river", {})
	var w := float(river.get("width", 5.0)) + 1.5
	var lvl := float(river.get("water_level", world.sea_level))
	for br in river.get("branches", []):
		var pts: Array = br
		for s in range(pts.size() - 1):
			var a := IslandWorld.v2(pts[s])
			var b := IslandWorld.v2(pts[s + 1])
			var seg := MeshInstance3D.new()
			var bm := PlaneMesh.new()
			bm.size = Vector2(w, a.distance_to(b) + w)
			seg.mesh = bm
			var mid := (a + b) * 0.5
			seg.transform = Transform3D(Basis(Vector3.UP, atan2(b.x - a.x, b.y - a.y)), Vector3(mid.x, lvl, mid.y))
			seg.material_override = mat
			seg.set_meta("no_outline", true)
			world.add_child(seg)

	for p in world.cfg.get("ponds", []):
		var pond: Dictionary = p
		var c := IslandWorld.v2(pond["center"])
		var disc := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = float(pond.get("radius", 6.0)) + 0.8
		cm.bottom_radius = cm.top_radius
		cm.height = 0.02
		disc.mesh = cm
		disc.position = Vector3(c.x, float(pond.get("water_level", -0.6)), c.y)
		disc.material_override = mat
		disc.set_meta("no_outline", true)
		world.add_child(disc)
