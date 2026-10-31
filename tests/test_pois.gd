extends "res://tests/test_base.gd"
## Постройки острова (IslandPois): здания поставлены с коллизией, центр города свободен (торговец,
## точка старта), точки старта рас проходимы и не заняты, по настилу причала можно ходить,
## над деревнями есть подписи, анимации (мельница, корабль) работают, овец (модели из примитивов) на острове нет.
## Отрисовка: неподвижное склеено в меши зон — MeshInstance3D в узле построек немного,
## в телах построек мешей нет (кроме анимированных: мельница, маяк).

## Предел MeshInstance3D в узле построек (было ~200, по одному на объект).
const MAX_MESHES := 40

var w: IslandWorld
var sails_basis := Basis.IDENTITY
var ship_y := 0.0


func race_class() -> Array:
	return ["light_elf", "cleric"]


func run_step() -> void:
	match step:
		0:
			w = IslandWorld.current
			check(w != null, "остров построен")
			var pois := w.get_node_or_null("Pois")
			check(pois != null, "узел построек создан")
			var buildings := get_tree().get_nodes_in_group("poi_buildings")
			check(buildings.size() >= 40, "постройки с коллизией: %d" % buildings.size())
			# Центр города свободен: ни одна форма коллизии построек не ближе 9 м к (0,0)
			# (смотрим на формы, а не на тела: тело ограды стоит в центре, а её формы — на кольце)
			var near := 0
			for b in buildings:
				for sh in (b as Node).find_children("*", "CollisionShape3D", true, false):
					var n := sh as Node3D
					if Vector2(n.global_position.x, n.global_position.z).length() < 9.0:
						near += 1
			check(near == 0, "центр города свободен (построек ближе 9 м: %d)" % near)
			for p in [Vector2(0, 0), Vector2(0, -1.5), Vector2(0, 7), Vector2(0, 2)]:
				var v: Vector2 = p
				check(w.is_walkable(v.x, v.y), "точка (%.1f, %.1f) в городе проходима" % [v.x, v.y])
			for race in ["human", "light_elf", "dark_elf"]:
				var sp := w.spawn_point(race)
				check(w.is_walkable(sp.x, sp.z), "точка старта %s проходима" % race)
			# В каждой деревне и в городе — постройки (тела) и склеенный меш построек зоны
			for id in ["town", "light_elf_village", "dark_elf_village", "human_village"]:
				var holder := pois.get_node_or_null(id)
				check(holder != null and holder.get_child_count() >= 5, "постройки в %s" % id)
				check(holder.get_node_or_null("Label") is Label3D, "подпись над %s" % id)
				var st := holder.get_node_or_null("Static") as MeshInstance3D
				check(st != null and st.mesh != null and st.mesh.get_surface_count() >= 1,
					"склеенный меш построек в %s" % id)
				check(holder.get_node_or_null("Props") is MeshInstance3D, "склеенный меш мелочей в %s" % id)
			check(w.has_meta("poi_footprints") and (w.get_meta("poi_footprints") as Array).size() > 30,
				"следы построек для других модулей")
			# Вызовы отрисовки: мешей немного, у каждого — по поверхности на материал
			var meshes := pois.find_children("*", "MeshInstance3D", true, false)
			var surfaces := 0
			for m in meshes:
				var mi := m as MeshInstance3D
				if mi.mesh != null:
					surfaces += mi.mesh.get_surface_count()
			print("Постройки: MeshInstance3D %d, поверхностей %d, MultiMesh %d" % [meshes.size(), surfaces,
				pois.find_children("*", "MultiMeshInstance3D", true, false).size()])
			check(meshes.size() <= MAX_MESHES, "MeshInstance3D в узле построек: %d (не больше %d)" % [
				meshes.size(), MAX_MESHES])
			# В телах построек мешей нет: геометрия в мешах зон (кроме анимированных частей)
			var in_bodies := 0
			for b in buildings:
				var body := b as Node
				if body.name == "Windmill" or body.name == "Lighthouse":
					continue
				in_bodies += body.find_children("*", "MeshInstance3D", true, false).size()
			check(in_bodies == 0, "в телах построек нет мешей (найдено %d)" % in_bodies)
			# Причал проходим, маяк и мельница стоят
			var pier: Dictionary = w.poi("pier")
			var pc := IslandWorld.v2(pier["center"])
			check(w.is_walkable(pc.x, pc.y), "по причалу можно ходить")
			check(pois.find_child("Lighthouse", true, false) != null, "маяк построен")
			var sails := pois.find_child("Sails", true, false) as Node3D
			check(sails != null, "крылья мельницы")
			sails_basis = sails.transform.basis
			var ship := pois.find_child("Ship", true, false) as Node3D
			check(ship != null and ship.global_position.y < 0.0, "корабль на воде")
			ship_y = ship.global_position.y
			# На острове только существа Максима: овец из примитивов в загоне нет
			check(pois.find_child("Sheep", true, false) == null and pois.find_child("Bodies", true, false) == null,
				"овец в загоне нет")
			check(pois.find_child("Flames", true, false) is MultiMeshInstance3D, "огни пещеры и лагерей")
			check(PoiModels.get_mesh("light_elf_house").get_surface_count() >= 2, "модель дома: несколько поверхностей")
			# Анимации идут только рядом с камерой: переносим игрока в деревню людей у мельницы
			main.player.global_position = w.spawn_point("human")
			wait = 40
			step = 1
		1:
			var pois := w.get_node("Pois")
			var sails := pois.find_child("Sails", true, false) as Node3D
			check(not sails.transform.basis.is_equal_approx(sails_basis), "крылья мельницы вращаются")
			var ship := pois.find_child("Ship", true, false) as Node3D
			check(absf(ship.global_position.y - ship_y) < 0.5, "корабль качается рядом с уровнем моря")
			var grazing := 0
			for e in (pois.get_node("PoiAnimator") as PoiAnimator)._items:
				if int(e["kind"]) == PoiAnimator.GRAZE_MM or int(e["kind"]) == PoiAnimator.GRAZE:
					grazing += 1
			check(grazing == 0, "пасущихся овец нет")
			ok_done()
