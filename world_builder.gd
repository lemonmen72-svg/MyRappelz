class_name WorldBuilder
extends RefCounted
## Строит мир: небо и свет, земля с коллизией, деревья. Модуль «Мир» (графика).
## Звери, игрок и безопасная зона создаются в других модулях; зона в центре (MobData.SAFE_RADIUS) должна оставаться свободной.

## Половина размера карты: игрок ограничен ±70 м, земля 200×200 м.
const MAP_HALF := 100.0


## Строит мир внутри root (узел main). rng — общий генератор с фиксированным зерном.
static func build(root: Node3D, rng: RandomNumberGenerator) -> void:
	_build_environment(root)
	_build_ground(root)
	for i in 90:
		var pos := Vector3(rng.randf_range(-75, 75), 0.0, rng.randf_range(-75, 75))
		if Vector2(pos.x, pos.z).length() < MobData.SAFE_RADIUS + 2.0:
			continue
		_add_tree(root, pos, rng)


static func _build_environment(root: Node3D) -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.25, 0.55, 0.95)
	sm.sky_horizon_color = Color(0.7, 0.85, 1.0)
	sm.ground_horizon_color = Color(0.7, 0.85, 1.0)
	sm.ground_bottom_color = Color(0.35, 0.5, 0.4)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Светлые голубоватые тени, как в аниме
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.7, 0.9)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	root.add_child(sun)


static func _build_ground(root: Node3D) -> void:
	var ground := StaticBody3D.new()
	var gcol := CollisionShape3D.new()
	var gshape := BoxShape3D.new()
	gshape.size = Vector3(MAP_HALF * 2.0, 1, MAP_HALF * 2.0)
	gcol.shape = gshape
	gcol.position.y = -0.5
	ground.add_child(gcol)
	var gm := MeshInstance3D.new()
	gm.set_meta("no_outline", true)
	var plane := PlaneMesh.new()
	plane.size = Vector2(MAP_HALF * 2.0, MAP_HALF * 2.0)
	gm.mesh = plane
	gm.material_override = Util.mat(Color(0.42, 0.72, 0.36))
	ground.add_child(gm)
	root.add_child(ground)


static func _add_tree(root: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> void:
	var tree := StaticBody3D.new()
	tree.position = pos
	var col := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 0.35
	cs.height = 2.4
	col.shape = cs
	col.position.y = 1.2
	tree.add_child(col)

	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.2
	tm.bottom_radius = 0.3
	tm.height = 2.4
	trunk.mesh = tm
	trunk.position.y = 1.2
	trunk.material_override = Util.mat(Color(0.5, 0.33, 0.2))
	tree.add_child(trunk)

	var r := rng.randf_range(1.1, 1.7)
	var crown := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	crown.mesh = sm
	crown.position.y = 2.6 + r * 0.4
	crown.material_override = Util.mat(Color(0.25, rng.randf_range(0.6, 0.75), 0.3))
	tree.add_child(crown)
	root.add_child(tree)
