extends "res://tests/test_base.gd"
## Подземелье (0.35, DungeonWorld): портал у пещеры острова (вплотную к проёму) не пускает ниже 20 уровня и без
## задания Корвена «Тропа во тьму», с заданием — пускает; переход строит сцену заново только с подземельем (острова
## нет), герой встаёт у портала подземелья, цель задания «спуститься» засчитана; в подземелье — все залы и корабль
## связаны путём (CardinalNav: мосты, мостки), край пещеры непроходим, вода есть, мосты на месте, объекты расставлены
## (с пакетом — модели dg_*, без — запасные), огней не больше DungeonProps.MAX_LIGHTS; жителей и торговца нет;
## смерть — у входа подземелья; портал подземелья возвращает к пещере острова; задание можно сдать.

var cave := Vector3.ZERO
var first_main: Node = null
var tries := 0


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
			wait = 30
			step = 4
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
