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
			CardinalNav.ensure(w, get_tree())
			wpath = CardinalNav.path(w_start, Vector3(c.x, 0, c.y))
			wpath.append(Vector3(c.x, 0, c.y))
			wpi = 0
			w_t0 = frame
			w_moved = frame
			w_last = w_start
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
			if w.walk[k] == 1:
				bad += 1
	check(rim > 100 and bad == 0, "скальный край и пустота непроходимы (%d узлов, проходимых %d)" % [rim, bad])
