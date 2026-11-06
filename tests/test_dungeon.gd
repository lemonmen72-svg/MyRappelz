extends "res://tests/test_base.gd"
## Подземелье (0.35, DungeonWorld): портал у пещеры острова (вплотную к проёму) не пускает ниже 20 уровня и без
## задания Корвена «Тропа во тьму», с заданием — пускает; переход строит сцену заново только с подземельем (острова
## нет), герой встаёт у портала подземелья, цель задания «спуститься» засчитана; в подземелье — все залы и корабль
## связаны путём (CardinalNav: мосты, мостки), край пещеры непроходим, вода есть, мосты на месте, объекты расставлены
## (с пакетом — модели dg_*, без — запасные), огней не больше DungeonProps.MAX_LIGHTS; жителей и торговца нет;
## смерть — у входа подземелья; портал подземелья возвращает к пещере острова; задание можно сдать.
## 0.35.1: стены — 7 м над местным полом, у залов свой уровень пола (спуски и подъёмы), портал на уступе над
## лестницей; герой ФИЗИКОЙ (джойстик, путь CardinalNav) доходит от портала до каждого зала, каждой площадки мостков
## и палубы корабля — в 0.35 сетка путь находила, а герой застревал на мостках к кораблю.

var cave := Vector3.ZERO
var first_main: Node = null
var tries := 0
## Прогулка: цели [имя, точка], номер цели, путь, номер точки, кадр старта и последнего сдвига, место сдвига.
var walk_targets: Array = []
var wi := 0
var wpath := PackedVector3Array()
var wpi := 0
var w_t0 := 0
var w_moved := 0
var w_last := Vector3.ZERO
var w_start := Vector3.ZERO


func race_class() -> Array:
	return ["human", "warrior"]


func hero_level() -> int:
	return 19


func before_start() -> void:
	# Прогулка ногами до 18 точек (залы, концы мостов, оба конца палубы корабля) — дольше обычных 300 с
	max_frames = 60 * 600
	Game.quests_done["sage_to_merc"] = 1
	Game.quests_done["merc_closed_cave"] = 1


func _w() -> IslandWorld:
	return main.get("world") as IslandWorld


func run_step() -> void:
	match step:
		0:
			first_main = main
			var w := _w()
			check(w.location() == "island", "старт на острове")
			var pt: Portal = main.get("portal")
			check(pt != null, "портал у пещеры поставлен")
			var cp: Dictionary = w.poi("cave")
			var c := IslandWorld.v2(cp["center"])
			cave = Vector3(c.x, 0, c.y)
			var d := Vector2(pt.global_position.x - c.x, pt.global_position.z - c.y).length()
			check(d < 9.0, "портал у входа в пещеру (%.1f м от центра пещеры)" % d)
			# 19 уровень — не пускает
			check(Dungeon.enter_block().contains("20 уровня"), "ниже 20 уровня портал не пускает: %s" % Dungeon.enter_block())
			Game.level = 20
			check(Dungeon.enter_block().contains("Корвен"), "без задания Корвена не пускает: %s" % Dungeon.enter_block())
			_put_at(pt.front_point())
			wait = 20
			step = 1
		1:
			check(main == first_main and _w().location() == "island", "без задания герой остаётся на острове")
			var q: Quests = main.quests
			check(q.accept(QuestData.DUNGEON_QUEST), "задание «Тропа во тьму» взято у Корвена")
			check(Dungeon.enter_block() == "", "с заданием портал пускает")
			_put_at((main.get("portal") as Portal).exit_point())
			wait = 5
			step = 2
		2:
			_put_at((main.get("portal") as Portal).front_point())
			wait = 10
			step = 3
		3:
			# Переход: сцена строится заново (ждём мир подземелья)
			if main == first_main or not bool(main.get("_started")):
				tries += 1
				if tries % 60 == 0:
					print("  ждём подземелье: сцена новая %s, мир %s, _started %s" % [main != first_main, main.get("world"), main.get("_started")])
				if tries > 600:
					fail("портал не перенёс в подземелье")
				return
			var w := _w()
			check(w is DungeonWorld and w.location() == "dungeon", "мир — подземелье (DungeonWorld)")
			check(Game.location == "dungeon", "локация героя сохранена: подземелье")
			check(main.find_child("Island", false, false) == null and main.find_child("Vegetation", true, false) == null,
				"острова в сцене нет")
			var pt: Portal = main.get("portal")
			check(pt != null and pt.to == "island", "в подземелье — портал на остров")
			var pp: Vector3 = main.player.global_position
			check(Vector2(pp.x - pt.global_position.x, pp.z - pt.global_position.z).length() < 6.0,
				"герой у портала подземелья (%.1f м)" % Vector2(pp.x - pt.global_position.x, pp.z - pt.global_position.z).length())
			check(main.quests.goal_progress(QuestData.DUNGEON_QUEST, 0) == 1, "цель «Спуститься в подземелье» засчитана")
			_check_world(w as DungeonWorld)
			_relief(w as DungeonWorld)
			# Прогулка ногами: от выхода портала (уступ над лестницей) ко всем залам, мосткам и кораблю
			AdminPanel.god = true
			w_start = pp
			for e in (w as DungeonWorld).cfg["pois"]:
				walk_targets.append([String(e["name"]), IslandWorld.v2(e["center"])])
			for br in (w as DungeonWorld).cfg["bridges"]:
				walk_targets.append(["конец моста " + str(br["b"]), IslandWorld.v2(br["b"])])
			# Палуба корабля (0.35.4 — поверхность по модели): крайние точки по оси — у двери рубки и у носа, затем
			# зигзагом от борта к борту по всей длине (у бортов не застревает, у носа палуба поднимается)
			for dk in (w as DungeonWorld).cfg["decks"]:
				var dd: Dictionary = dk
				if dd.has("points"):
					for dpt in dd["points"]:
						walk_targets.append(["палуба %s %s" % [String(dd["id"]), str(dpt)], IslandWorld.v2(dpt)])
				if dd.has("surface"):
					var zs: Array[float] = []
					for zi in range(0, 120):
						var zq := 10.0 + float(zi) * 0.5
						if not is_nan(DungeonWorld.surface_at(dd, Vector2(32.0, zq))):
							zs.append(zq)
					check(zs.size() > 40, "палуба корабля по поверхности: %d точек по оси" % zs.size())
					if zs.size() > 4:
						walk_targets.append(["палуба у рубки", Vector2(32.0, zs[1])])
						walk_targets.append(["палуба у носа", Vector2(32.0, zs[zs.size() - 2])])
						var side := 1.0
						var zq2 := zs[2]
						while zq2 < zs[zs.size() - 3]:
							for off in [3.0, 2.5, 2.0, 1.5]:
								var q := Vector2(32.0 + side * off, zq2)
								var roomy := true
								for dq in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
									if is_nan(DungeonWorld.surface_at(dd, q + dq)):
										roomy = false
								if roomy and w.is_walkable(q.x, q.y):
									walk_targets.append(["палуба корабля у борта " + str(q), q])
									break
							side = -side
							zq2 += 4.5
			# Каждый мост — строго по оси с берега на берег в обе стороны (0.35.4: у конца настила была ступенька в берег,
			# герой упирался, хотя путь в обход находился)
			for br in (w as DungeonWorld).cfg["bridges"]:
				var ba := IslandWorld.v2(br["a"])
				var bb := IslandWorld.v2(br["b"])
				var dv := (bb - ba).normalized() * 1.5
				walk_targets.append(["по мосту %s → %s" % [str(br["a"]), str(br["b"])], bb + dv, ba - dv])
				walk_targets.append(["по мосту %s → %s" % [str(br["b"]), str(br["a"])], ba - dv, bb + dv])
			wait = 10
			step = 30
		30:
			if wi >= walk_targets.size():
				AdminPanel.god = false
				main.hud.move_vec = Vector2.ZERO
				wait = 20
				step = 4
				return
			var w := _w()
			main.player.global_position = w_start
			main.player.velocity = Vector3.ZERO
			var c: Vector2 = walk_targets[wi][1]
			if (walk_targets[wi] as Array).size() > 2:
				# прямо: из точки у начала к цели, без поиска пути
				var st: Vector2 = walk_targets[wi][2]
				main.player.global_position = Vector3(st.x, w.height_at(st.x, st.y) + 0.3, st.y)
				wpath = [Vector3(c.x, 0, c.y)]
			else:
				CardinalNav.ensure(w, get_tree())
				wpath = CardinalNav.path(w_start, Vector3(c.x, 0, c.y))
				wpath.append(Vector3(c.x, 0, c.y))
			wpi = 0
			w_t0 = frame
			w_moved = frame
			w_last = main.player.global_position
			step = 31
		31:
			var p: Player = main.player
			var c: Vector2 = walk_targets[wi][1]
			var pos := p.global_position
			var d := Vector2(pos.x - c.x, pos.z - c.y).length()
			if Vector2(pos.x - w_last.x, pos.z - w_last.z).length() > 0.5:
				w_last = pos
				w_moved = frame
			if d < 1.2 or frame - w_moved > 180 or frame - w_t0 > 60 * 90:
				p.move_input = Vector2.ZERO
				main.hud.move_vec = Vector2.ZERO
				check(d < 1.2, "ногами от портала: «%s» — %s (герой у (%.1f, %.1f, %.1f), до цели %.1f м)" % [
					walk_targets[wi][0], "дошёл" if d < 1.2 else "ЗАСТРЯЛ", pos.x, pos.y, pos.z, d])
				wi += 1
				step = 30
				return
			while wpi < wpath.size() - 1 and Vector2(pos.x - wpath[wpi].x, pos.z - wpath[wpi].z).length() < 0.8:
				wpi += 1
			var dir := Vector2(wpath[wpi].x - pos.x, wpath[wpi].z - pos.z)
			var mv := Vector3(dir.x, 0.0, dir.y).normalized().rotated(Vector3.UP, -float(main.cam_yaw))
			main.hud.move_vec = Vector2(mv.x, mv.z)
			p.move_input = dir.normalized() if dir.length() > 0.05 else Vector2.ZERO
		4:
			# Смерть — у входа подземелья
			var p: Player = main.player
			var w := _w() as DungeonWorld
			p.global_position = w.ground(40.3, 23.6, 0.3)
			p.take_damage(p.max_hp * 10, null)
			var sp := w.spawn_point("human")
			check(Vector2(p.global_position.x - sp.x, p.global_position.z - sp.z).length() < 3.0,
				"погиб в подземелье — возродился у его входа")
			first_main = main
			tries = 0
			_put_at((main.get("portal") as Portal).front_point())
			wait = 10
			step = 5
		5:
			if main == first_main or not bool(main.get("_started")):
				tries += 1
				if tries > 600:
					fail("портал подземелья не вернул на остров")
				return
			check(_w().location() == "island" and Game.location == "island", "портал подземелья вернул на остров")
			var pp: Vector3 = main.player.global_position
			var d := Vector2(pp.x - cave.x, pp.z - cave.z).length()
			check(d < 14.0, "герой у пещеры острова (%.1f м)" % d)
			check(main.quests.is_ready(QuestData.DUNGEON_QUEST), "задание можно сдать Корвену")
			check(main.quests.complete(QuestData.DUNGEON_QUEST), "задание сдано")
			check(Dungeon.enter_block() == "", "после сдачи портал по-прежнему пускает")
			ok_done()


func _put_at(p: Vector3) -> void:
	var pl: Player = main.player
	pl.global_position = _w().ground(p.x, p.z, 0.2)
	pl.velocity = Vector3.ZERO


## Рельеф 0.35.1: уровни залов (склеп ниже, шахта выше), уступ портала над залом входа, стены ≥ 6 м над полом.
func _relief(w: DungeonWorld) -> void:
	var lv := {}
	for r in w.cfg["rooms"]:
		var c := IslandWorld.v2(r["center"])
		lv[String(r["id"])] = w.height_at(c.x, c.y)
	check(float(lv["crypt"]) < -1.0 and float(lv["mine"]) > 2.0 and float(lv["goblin_camp"]) > 0.8,
		"у залов свой уровень пола: склеп %.1f, логово %.1f, шахта %.1f" % [lv["crypt"], lv["goblin_camp"], lv["mine"]])
	var pt := w.portal()
	var c2: Vector2 = pt["center"]
	check(w.height_at(c2.x, c2.y) > float(lv["entrance"]) + 3.0, "портал на уступе над залом входа (%.1f над %.1f)" % [
		w.height_at(c2.x, c2.y), lv["entrance"]])
	# Стена: узлы края на расстоянии rim_w − 0.5 от пола — не ниже 6 м над полом зала рядом
	var low := 0
	var n := 0
	for k in w.walk.size():
		if w.deck_of[k] < 0 and w.floor_sd[k] > 2.0 and w.floor_sd[k] < 2.6 and w.water_sd[k] > 6.0:
			n += 1
			if w.heights[k] - w.level[k] < 6.0:
				low += 1
	check(n > 200 and low < n / 50, "стены высотой ≥ 6 м над полом (%d узлов стены, ниже — %d)" % [n, low])


## Раскладка из сцены Blender (0.35.4): столбы — высотой со стены, факелы — тыльной пластиной к скале, у твёрдых —
## формы коллизии по модели, мосты — своя модель со сваями.
func _props_placed(w: DungeonWorld, props: Node) -> void:
	var tall := 0
	var low := 0
	var torches := 0
	var on_wall := 0
	var space := w.get_world_3d().direct_space_state
	for e in w.cfg["props"]:
		var a: Array = e
		var id := String(a[0])
		var s := float(a[4]) if a.size() > 4 else 1.0
		var sy := float(a[6]) if a.size() > 6 else 1.0
		if id == "dg_spire" or id == "dg_obelisk":
			var h := float((w.cfg["prop_shapes"] as Dictionary).get(id, {}).get("h", 0.0)) * s * sy
			if h >= 6.0:
				tall += 1
			else:
				low += 1
		if id == "dg_torch":
			torches += 1
			var pos := DungeonProps.base_pos(w, a)
			var bas := Basis(Vector3.UP, deg_to_rad(float(a[3]))) * DungeonProps.tilt_of(a) * Basis.from_scale(Vector3.ONE * s)
			var back := (bas * Vector3.RIGHT).normalized()
			# Тыльная пластина (вершины модели у края +X): лучи от неё к скале — самый большой зазор
			var worst := 0.0
			for vtx in _plate_points():
				var pw: Vector3 = pos + bas * (vtx as Vector3)
				var q := PhysicsRayQueryParameters3D.create(pw - back * 0.5, pw + back * 1.5, 1)
				var hit := space.intersect_ray(q)
				worst = maxf(worst, 2.0 if hit.is_empty() else (pw - back * 0.5).distance_to(hit["position"]) - 0.5)
			if worst < 0.35:
				on_wall += 1
			else:
				print("ФАКЕЛ не у стены: (%.1f, %.1f) зазор пластины до %.2f м" % [pos.x, pos.z, worst])
	check(low == 0 and tall > 0, "столбы и обелиски высотой со стены: %d, ниже 6 м — %d" % [tall, low])
	check(torches > 0 and on_wall == torches, "факелы тыльной пластиной к скале: %d из %d" % [on_wall, torches])
	check((w.cfg.get("prop_shapes", {}) as Dictionary).size() > 30, "формы коллизии по моделям: %d" % (w.cfg.get("prop_shapes", {}) as Dictionary).size())
	if PropAsset.has(String(w.cfg.get("bridge_model", ""))):
		check(props.find_child("Bridges", false, false) != null, "мосты — своя модель со сваями")


## Точки тыльной пластины факела (модель; без файла — точка у края +X): до 16 вершин у края +X.
func _plate_points() -> Array:
	var out := []
	var m := PropAsset.mesh("dg_torch") if PropAsset.has("dg_torch") else null
	if m == null:
		return [Vector3(0.2, 0.3, 0.0)]
	var v: PackedVector3Array = m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var mx := -INF
	for p in v:
		mx = maxf(mx, p.x)
	for i in range(0, v.size(), 1):
		if v[i].x > mx - 0.06:
			out.append(v[i])
	var step := maxi(1, out.size() / 16)
	var res := []
	for i in range(0, out.size(), step):
		res.append(out[i])
	return res


func _check_world(w: DungeonWorld) -> void:
	# Жителей и торговца нет
	var npcs := 0
	for n in main.get_children():
		if n is Npc:
			npcs += 1
	check(npcs == 0, "в подземелье нет жителей и торговца (%d)" % npcs)
	check(w.bridges.size() == (w.cfg["bridges"] as Array).size(), "мосты и мостки: %d" % w.bridges.size())
	check(main.find_child("Water", true, false) != null, "вода есть")
	var props := main.find_child("DungeonProps", true, false)
	check(props != null and int(props.get_meta("placed", 0)) >= (w.cfg["props"] as Array).size(),
		"объекты расставлены: %d" % int(props.get_meta("placed", 0)))
	check(int(props.get_meta("lights", 0)) <= DungeonProps.MAX_LIGHTS, "огней %d" % int(props.get_meta("lights", 0)))
	if PropAsset.has("dg_ship_deck"):
		check(props.find_child("Props", false, false) != null, "модели подземелья из файлов (меши участков)")
	_props_placed(w, props)
	# Все залы и корабль связаны путём от входа (мосты, мостки)
	CardinalNav.ensure(w, get_tree())
	var start := w.spawn_point("human")
	for e in w.cfg["pois"]:
		var d: Dictionary = e
		var c := IslandWorld.v2(d["center"])
		check(w.is_walkable(c.x, c.y), "«%s»: точка проходима" % String(d["name"]))
		var path := CardinalNav.path(start, Vector3(c.x, 0, c.y))
		var end_ok := Vector2(start.x - c.x, start.z - c.y).length() < 3.0 or (not path.is_empty()
			and Vector2(path[path.size() - 1].x - c.x, path[path.size() - 1].z - c.y).length() < 3.0)
		check(end_ok, "«%s»: путь от входа есть (%d точек)" % [String(d["name"]), path.size()])
	# Край пещеры непроходим, пустота за ним — тоже
	var rim := 0
	var bad := 0
	for k in w.walk.size():
		if w.floor_sd[k] > 0.6 and w.water_sd[k] > 0.6 and w.deck_of[k] < 0:
			rim += 1
			var pk := w.origin + Vector2(k % w.nx, k / w.nx) * w.step
			if w.walk[k] == 1 and not w._on_bridge(Vector3(pk.x, 0, pk.y)):
				bad += 1
	check(rim > 100 and bad == 0, "скальный край и пустота непроходимы (%d узлов, проходимых %d)" % [rim, bad])
