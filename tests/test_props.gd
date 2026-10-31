extends "res://tests/test_base.gd"
## Объекты локации из файлов (PropAsset, assets/props — модели Meshy, tools/prepare_props.py):
## у каждого объекта таблицы есть GLB и страница атласа, модель грузится, размер — как в props.json и в
## пределах процедурной модели того же вида, основание на y = 0; на острове постройки — модели из файлов
## (поверхности с материалом атласа в мешах зон), коллизия по габаритам модели, постройки не висят в воздухе
## и не утонули; крылья мельницы и корабль — модели из файлов; деревья, кусты и камни — тоже.
## Стены построек без дыр: лучи снаружи на высоте первого этажа упираются в ближнюю стену (не проходят
## внутрь дома и насквозь) и попадают в лицевую сторону грани (панели Meshy развёрнуты наружу); материал
## двусторонний (страховка); свечение домов эльфов — только окна и кристаллы и умеренное.

const IDS := ["town_house", "town_house_b", "town_hall", "well", "notice_board", "town_gate", "merchant_stall",
	"human_house_thatch", "human_house_red", "windmill_tower", "windmill_sails", "scarecrow", "hay_bale", "trough",
	"light_elf_house", "light_elf_tower", "dark_elf_house", "dark_elf_tower", "lighthouse", "ship", "cave_entrance",
	"tent_bell", "tent_ridge", "campfire", "dock_crates", "lantern_town", "lantern_elf", "weapon_rack",
	"training_dummy", "bollard", "crate", "barrel", "brazier_dark", "dark_spire", "crystal_blue", "crystal_gold",
	"crystal_purple", "tree_oak", "tree_pine", "tree_elf", "tree_dead", "bush", "rock", "rock_dark"]
## Модели, у которых основание не на y = 0: крылья мельницы (ступица в центре), корабль (ватерлиния).
const NOT_ON_GROUND := ["windmill_sails", "ship"]
## Постройки: стены проверяются лучами (_check_walls).
const BUILDINGS := ["town_house", "town_house_b", "town_hall", "human_house_thatch", "human_house_red",
	"windmill_tower", "light_elf_house", "light_elf_tower", "dark_elf_house", "dark_elf_tower", "lighthouse"]
## Дома и башни эльфов: свечение ограничено (_check_glow).
const ELF_BUILDINGS := ["light_elf_house", "light_elf_tower", "dark_elf_house", "dark_elf_tower"]
## Процедурные модели, с которыми сравнивается размер (вид PoiModels → id).
const COMPARE := ["town_house", "town_house_b", "town_hall", "well", "notice_board", "lantern_town", "weapon_rack",
	"dummy", "crate", "barrel", "human_house_thatch", "human_house_red", "windmill", "scarecrow", "hay", "trough",
	"light_elf_house", "light_elf_tower", "lantern_elf", "crystals_blue", "crystals_gold", "dark_elf_house",
	"dark_elf_tower", "dark_spire", "crystals_purple", "lighthouse", "tent_bell", "tent_ridge"]


func race_class() -> Array:
	return ["human", "warrior"]


func run_step() -> void:
	match step:
		0:
			_check_files()
			_check_walls()
			_check_glow()
			step = 1
		1:
			_check_island()
			_check_vegetation()
			ok_done()


func _check_files() -> void:
	for i in IDS:
		var id := String(i)
		check(ResourceLoader.exists(PropAsset.DIR + id + ".glb"), "файл модели %s" % id)
		check(PropAsset.has(id), "модель %s в props.json" % id)
		var m := PropAsset.mesh(id)
		check(m != null and m.get_surface_count() == 1, "модель %s грузится (одна поверхность)" % id)
		var pg := PropAsset.page(id)
		check(ResourceLoader.exists(PropAsset.DIR + "props_%s.png" % pg), "страница атласа %s у %s" % [pg, id])
		var bb := m.get_aabb()
		var want := PropAsset.size(id)
		check(bb.size.distance_to(want) < 0.05 * want.length() + 0.02,
			"размер %s: %s ≈ %s из props.json" % [id, bb.size, want])
		if not NOT_ON_GROUND.has(id):
			check(absf(bb.position.y) < 0.03, "%s стоит на y = 0 (низ %.3f)" % [id, bb.position.y])
			check(absf(bb.position.x + bb.size.x * 0.5) < 0.05 and absf(bb.position.z + bb.size.z * 0.5) < 0.05,
				"%s по центру X/Z" % id)
	# Ватерлиния корабля: корпус уходит под воду, мачта — над ней
	var sb := PropAsset.mesh("ship").get_aabb()
	check(sb.position.y < -0.5 and sb.end.y > 6.0, "корабль: корпус под водой, мачта над водой (%s)" % sb)
	# Размер — в пределах процедурной модели того же вида (высота от 0.5 до 1.7 раза, ширина от 0.5 до 2.5 раза:
	# у фонаря эльфов изогнутый столб с подвесом шире прямого столбика)
	for k in COMPARE:
		var kind := String(k)
		var id := PropAsset.for_kind(kind)
		check(id != "", "у вида %s есть модель из файла" % kind)
		var pb := PoiModels.get_kit(kind).to_mesh().get_aabb()
		var fb := PropAsset.mesh(id).get_aabb()
		var rh := fb.size.y / maxf(pb.size.y, 0.01)
		var rw := maxf(fb.size.x, fb.size.z) / maxf(maxf(pb.size.x, pb.size.z), 0.01)
		check(rh > 0.5 and rh < 1.7 and rw > 0.5 and rw < 2.5,
			"%s: размер как у процедурной (высота ×%.2f, ширина ×%.2f)" % [kind, rh, rw])


func _check_island() -> void:
	var w := IslandWorld.current
	var pois := w.get_node("Pois")
	# Меши зон: у деревень и города есть поверхности с материалом атласа (prop.gdshader)
	for id in ["town", "light_elf_village", "dark_elf_village", "human_village", "port"]:
		var holder := pois.get_node(id)
		var found := 0
		for n in ["Static", "Props"]:
			var mi := holder.get_node_or_null(n) as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			for si in mi.mesh.get_surface_count():
				var sm := mi.mesh.surface_get_material(si) as ShaderMaterial
				if sm != null and sm.shader != null and sm.shader.resource_path == PropAsset.SHADER:
					found += 1
		check(found >= 1, "в %s модели из файлов (поверхностей атласа: %d)" % [id, found])
	# Постройки из файлов (тела с коллизией-боксом по модели — _building): коллизия по габаритам модели,
	# основание — не выше земли и не глубоко под ней
	var checked := 0
	for b in get_tree().get_nodes_in_group("poi_buildings"):
		var body := b as StaticBody3D
		var kind := _kind_of(body)
		var pid := PropAsset.for_kind(kind)
		var box := _first_box(body)
		if pid == "" or box == Vector3.ZERO:
			continue
		var p := body.global_position
		var lo := INF
		var hi := -INF
		var s := PropAsset.size(pid)
		for k in 9:
			var a := TAU * float(k) / 8.0
			var r := 0.0 if k == 8 else minf(s.x, s.z) * 0.4
			var q := p + body.global_transform.basis * Vector3(cos(a) * r, 0, sin(a) * r)
			var gh := w.height_at(q.x, q.z)
			lo = minf(lo, gh)
			hi = maxf(hi, gh)
		check(p.y <= lo + 0.15, "%s не висит над землёй (низ %.2f, земля от %.2f)" % [kind, p.y, lo])
		check(p.y > hi - 2.0, "%s не утонул (низ %.2f, земля до %.2f)" % [kind, p.y, hi])
		var want := IslandPois._model_box(pid, PropAsset.kind_scale(kind))
		check(box.distance_to(want) < 0.1, "коллизия %s по модели: %s ≈ %s" % [kind, box, want])
		checked += 1
	check(checked >= 12, "постройки из файлов проверены: %d" % checked)
	# Крылья мельницы и корабль — модели из файлов
	var sails := pois.find_child("Sails", true, false) as MeshInstance3D
	check(sails != null and sails.mesh == PropAsset.mesh("windmill_sails"), "крылья мельницы из файла")
	var ship := pois.find_child("Ship", true, false) as Node3D
	var ship_mi: MeshInstance3D = null
	if ship != null:
		for c in ship.get_children():
			if c is MeshInstance3D:
				ship_mi = c as MeshInstance3D
	check(ship_mi != null and ship_mi.mesh == PropAsset.mesh("ship"), "корабль из файла")
	check(pois.find_child("MarketStall", true, false) != null, "торговый прилавок в городе")


## Вид постройки по имени тела (_building называет тело видом; у одноимённых соседей Godot дописывает
## «@имя@номер» или цифры).
func _kind_of(body: Node) -> String:
	var nm := String(body.name)
	if nm.begins_with("@"):
		nm = nm.get_slice("@", 1)
	if PropAsset.KINDS.has(nm):
		return nm
	var t := nm.rstrip("0123456789")
	return t if PropAsset.KINDS.has(t) else ""


func _first_box(body: Node) -> Vector3:
	for c in body.get_children():
		var cs := c as CollisionShape3D
		if cs != null and cs.shape is BoxShape3D:
			return (cs.shape as BoxShape3D).size
	return Vector3.ZERO


func _check_vegetation() -> void:
	var ids := {}
	var prop_chunks := 0
	for g in ["veg_trees", "veg_small"]:
		for n in get_tree().get_nodes_in_group(g):
			var mi := n as MeshInstance3D
			if mi == null:
				continue
			var list: Array = mi.get_meta("props", [])
			if list.is_empty():
				continue
			prop_chunks += 1
			var sm := mi.material_override as ShaderMaterial
			check(sm != null and sm.shader.resource_path == PropAsset.SHADER, "участок %s — материал атласа" % mi.name)
			for i in list:
				ids[String(i)] = true
	print("  растительность из файлов: участков %d, модели %s" % [prop_chunks, ids.keys()])
	for id in ["tree_oak", "tree_pine", "tree_elf", "tree_dead", "bush", "rock"]:
		check(ids.has(id), "на острове есть %s из файла" % id)


## Стены построек: с 8 сторон на высоте 0.7 м, 1.5 м и 40 % высоты (и со сдвигом вбок) луч к середине
## модели должен упереться в стену до середины (не уйти в дыру внутрь дома или насквозь) и попасть в лицевую
## сторону грани. Модели 0.14.0 (дыры в стенах) не проходили: у town_house_b 9, у dark_elf_house 19 лучей
## из 48 уходили внутрь.
func _check_walls() -> void:
	var sh := load(PropAsset.SHADER) as Shader
	check(sh != null and sh.code.contains("cull_disabled"), "материал моделей из файлов двусторонний (страховка от дыр)")
	for i in BUILDINGS:
		var id := String(i)
		var m := PropAsset.mesh(id)
		if m == null:
			continue
		var faces := m.get_faces()
		var bb := m.get_aabb()
		var rays := 0
		var holes := 0
		var backs := 0
		for y in [0.7, 1.5, bb.size.y * 0.4]:
			# Только треугольники на высоте луча (быстрее: лучи горизонтальные)
			var yy := bb.position.y + float(y)
			var band := PackedVector3Array()
			var fi := 0
			while fi + 2 < faces.size():
				var y0 := minf(faces[fi].y, minf(faces[fi + 1].y, faces[fi + 2].y))
				var y1 := maxf(faces[fi].y, maxf(faces[fi + 1].y, faces[fi + 2].y))
				if y0 <= yy and y1 >= yy:
					band.append(faces[fi])
					band.append(faces[fi + 1])
					band.append(faces[fi + 2])
				fi += 3
			for k in 8:
				var a := TAU * float(k) / 8.0 + 0.2
				var out := Vector3(sin(a), 0.0, cos(a))
				var side := Vector3(out.z, 0.0, -out.x)
				# Расстояние от середины до края габарита по направлению луча
				var ext := minf(bb.size.x * 0.5 / maxf(absf(out.x), 0.001), bb.size.z * 0.5 / maxf(absf(out.z), 0.001))
				for off in [-0.2, 0.2]:
					var c := Vector3(bb.get_center().x, yy, bb.get_center().z) + side * ext * float(off)
					var from := c + out * (ext + 2.0)
					var hit := _ray_hit(band, from, -out)
					rays += 1
					if hit.is_empty():
						holes += 1
						continue
					var p: Vector3 = hit["pos"]
					if (p - c).dot(out) < 0.0:
						holes += 1
					var n: Vector3 = hit["normal"]
					if n.dot(-out) > 0.0:
						backs += 1
		check(holes <= 1, "%s: стены без дыр (лучей сквозь стену %d из %d)" % [id, holes, rays])
		check(backs <= 2, "%s: снаружи видна лицевая сторона граней (изнанкой %d из %d)" % [id, backs, rays])


## Ближайшее пересечение луча с треугольниками faces (тройки вершин): {"pos", "normal"} или пусто.
## Нормаль — лицевой стороны грани у Godot (Plane(a, b, c), по часовой).
func _ray_hit(faces: PackedVector3Array, from: Vector3, dir: Vector3) -> Dictionary:
	var best := INF
	var res := {}
	var i := 0
	while i + 2 < faces.size():
		var hit: Variant = Geometry3D.ray_intersects_triangle(from, dir, faces[i], faces[i + 1], faces[i + 2])
		if hit != null:
			var p: Vector3 = hit
			var d := (p - from).dot(dir)
			if d < best:
				best = d
				res = {"pos": p, "normal": Plane(faces[i], faces[i + 1], faces[i + 2]).normal}
		i += 3
	return res


## Свечение домов и башен эльфов: альфа цвета вершин (сила свечения) не больше 0.6, светится не больше 6 %
## площади (окна, кристаллы — не стены и не крыши).
func _check_glow() -> void:
	for i in ELF_BUILDINGS:
		var id := String(i)
		var m := PropAsset.mesh(id)
		if m == null:
			continue
		var arr := m.surface_get_arrays(0)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		check(cols.size() == verts.size(), "%s: цвет вершин (свечение) есть" % id)
		if cols.size() != verts.size():
			continue
		var amax := 0.0
		for ci in cols.size():
			amax = maxf(amax, cols[ci].a)
		var total := 0.0
		var lit := 0.0
		var t := 0
		while t + 2 < idx.size():
			var va := verts[idx[t]]
			var ar := (verts[idx[t + 1]] - va).cross(verts[idx[t + 2]] - va).length() * 0.5
			total += ar
			var g := (cols[idx[t]].a + cols[idx[t + 1]].a + cols[idx[t + 2]].a) / 3.0
			if g > 0.15:
				lit += ar
			t += 3
		var share := lit / maxf(total, 0.001)
		check(amax <= 0.6, "%s: свечение умеренное (наибольшее %.2f)" % [id, amax])
		check(share <= 0.06, "%s: светятся только окна и кристаллы (%.1f %% площади)" % [id, share * 100.0])
