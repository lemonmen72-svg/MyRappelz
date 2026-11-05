class_name DungeonWater
extends RefCounted
## Вода подземелья (DungeonWorld): канал под мостами, озеро с кораблём, озёра у алтаря — один меш на уровне
## воды (dungeon_water.gdshader: тёмная бирюза с изумрудным свечением, рябь, светлые линии у кромки).
## Меш — квадраты сетки мира, где хотя бы один угол — вода (water_level узла задан). В вершинах UV.x — глубина
## под водой (м, по высоте дна), UV.y — расстояние до кромки (м, по знаковому расстоянию до воды).

static var material: ShaderMaterial = null


static func build(world: DungeonWorld) -> void:
	var y := world.water_y
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var map := {}
	for j in range(world.nz - 1):
		for i in range(world.nx - 1):
			var any := false
			for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var k: int = (j + d.y) * world.nx + (i + d.x)
				if world.water_level[k] > -50.0:
					any = true
			if not any:
				continue
			var ids: Array[int] = []
			for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var key := Vector2i(i + d.x, j + d.y)
				if not map.has(key):
					var k := key.y * world.nx + key.x
					map[key] = verts.size()
					var p := world.origin + Vector2(key) * world.step
					verts.append(Vector3(p.x, y, p.y))
					uvs.append(Vector2(maxf(0.0, y - world.heights[k]), maxf(0.0, -world.water_sd[k])))
				ids.append(int(map[key]))
			idx.append_array([ids[0], ids[1], ids[2], ids[1], ids[3], ids[2]])
	if idx.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://dungeon_water.gdshader")
	mat.set_shader_parameter("rich", Quality.rich_shaders())
	material = mat
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("no_outline", true)
	world.add_child(mi)
