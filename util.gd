class_name Util
extends RefCounted
## Общие вспомогательные функции.


static func mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


## Ближайший живой узел из группы в пределах max_dist.
static func nearest(from: Node3D, group: String, max_dist: float) -> Node3D:
	var best: Node3D = null
	var best_d := max_dist
	for n in from.get_tree().get_nodes_in_group(group):
		var node := n as Node3D
		if node == null:
			continue
		if node.get("is_dead") == true:
			continue
		var d := from.global_position.distance_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best


## Простое тело зверя из коробок (заглушка вместо модели). Возвращает материал.
static func creature_body(parent: Node3D, color: Color, s: float) -> StandardMaterial3D:
	var m := mat(color)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.9, 0.7, 1.4) * s
	body.mesh = bm
	body.position = Vector3(0, 0.75 * s, 0)
	body.material_override = m
	parent.add_child(body)

	var head := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.6, 0.55, 0.6) * s
	head.mesh = hm
	head.position = Vector3(0, 0.95 * s, -0.85 * s)
	head.material_override = m
	parent.add_child(head)

	for x in [-0.3, 0.3]:
		for z in [-0.45, 0.45]:
			var leg := MeshInstance3D.new()
			var lm := BoxMesh.new()
			lm.size = Vector3(0.18, 0.4, 0.18) * s
			leg.mesh = lm
			leg.position = Vector3(x * s, 0.2 * s, z * s)
			leg.material_override = m
			parent.add_child(leg)

	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.9, 1.2, 1.5) * s
	col.shape = sh
	col.position = Vector3(0, 0.6 * s, 0)
	parent.add_child(col)
	return m


## Всплывающий текст (урон, опыт).
static func float_text(parent: Node, pos: Vector3, text: String, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.012
	l.font_size = 48
	l.outline_size = 12
	parent.add_child(l)
	l.global_position = pos
	var t := l.create_tween()
	t.set_parallel(true)
	t.tween_property(l, "global_position:y", pos.y + 1.5, 0.8)
	t.tween_property(l, "modulate:a", 0.0, 0.8)
	t.chain().tween_callback(l.queue_free)
