extends "res://tests/test_base.gd"
## Объекты локации из файлов (PropAsset, assets/props — модели Meshy, tools/prepare_props.py):
## у каждого объекта таблицы есть GLB и страница атласа, модель грузится, размер — как в props.json и в
## пределах процедурной модели того же вида, основание на y = 0; на острове постройки — модели из файлов
## (поверхности с материалом атласа в мешах зон), коллизия по габаритам модели, постройки не висят в воздухе
## и не утонули; крылья мельницы и корабль — модели из файлов; деревья, кусты и камни — тоже.

const IDS := ["town_house", "town_house_b", "town_hall", "well", "notice_board", "town_gate", "merchant_stall",
	"human_house_thatch", "human_house_red", "windmill_tower", "windmill_sails", "scarecrow", "hay_bale", "trough",
	"light_elf_house", "light_elf_tower", "dark_elf_house", "dark_elf_tower", "lighthouse", "ship", "cave_entrance",
	"tent_bell", "tent_ridge", "campfire", "dock_crates", "lantern_town", "lantern_elf", "weapon_rack",
	"training_dummy", "bollard", "crate", "barrel", "brazier_dark", "dark_spire", "crystal_blue", "crystal_gold",
	"crystal_purple", "tree_oak", "tree_pine", "tree_elf", "tree_dead", "bush", "rock", "rock_dark"]
## Модели, у которых основание не на y = 0: крылья мельницы (ступица в центре), корабль (ватерлиния).
const NOT_ON_GROUND := ["windmill_sails", "ship"]
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
