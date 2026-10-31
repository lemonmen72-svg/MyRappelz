extends "res://tests/test_base.gd"
## Тренировочный остров: конфиг загружен, рельеф и коллизия, проходимость (суша — да, море и
## река — нет, мосты — да), точки старта рас в своих деревнях, звери по зонам вне безопасных зон,
## игрок не уходит в море, переход в порту показывает сообщение.

var w: IslandWorld
var start_pos := Vector3.ZERO
var frames_walked := 0


func race_class() -> Array:
	return ["dark_elf", "assassin"]


func run_step() -> void:
	var player: Player = main.player
	match step:
		0:
			w = IslandWorld.current
			check(w != null, "остров построен")
			check(w.cfg.get("pois", []).size() >= 10, "точки интереса из конфига: %d" % w.cfg.get("pois", []).size())
			check(w.is_walkable(0, 0), "центр города проходим")
			check(absf(w.height_at(0, 0)) < 0.3, "город на уровне 0: %.2f" % w.height_at(0, 0))
			check(not w.is_walkable(-170, 0) and not w.is_walkable(0, 95), "открытое море непроходимо")
			check(w.bridges.size() >= 1, "мосты через реку: %d" % w.bridges.size())
			# Точка реки посередине ветки — вода, непроходима
			var br: Array = w.cfg["river"]["branches"][1]
			var rp := IslandWorld.v2(br[2])
			check(not w.is_walkable(rp.x, rp.y), "река непроходима")
			# Середина первого моста — проходима
			var b: Dictionary = w.bridges[0]
			var mid: Vector3 = (b["a"] + b["b"]) * 0.5
			check(w.is_walkable(mid.x, mid.z), "мост проходим")
			for race in ["human", "light_elf", "dark_elf"]:
				var sp := w.spawn_point(race)
				check(w.is_walkable(sp.x, sp.z), "точка старта %s на проходимой суше" % race)
				check(w.in_safe_zone(sp), "точка старта %s в безопасной зоне" % race)
			var village: Dictionary = w.poi("dark_elf_village")
			var vc := IslandWorld.v2(village["center"])
			check(Vector2(player.global_position.x, player.global_position.z).distance_to(vc) < 20.0,
				"тёмный эльф стартует в своей деревне")
			check(absf(player.global_position.y - w.height_at(player.global_position.x, player.global_position.z)) < 1.5,
				"игрок стоит на земле")
			var bad := 0
			for s in main._slots:
				var sl: Dictionary = s
				var p: Vector3 = sl["pos"]
				if w.in_safe_zone(p) or not w.is_walkable(p.x, p.z):
					bad += 1
			check(bad == 0, "звери появляются вне безопасных зон и на суше (плохих: %d)" % bad)
			check(find_mob("anathema_chief") != null and find_mob("anathema_chief").level == 10, "вожак анатем в пещере 10 уровня")
			check(find_mob("golem") == null and find_mob("boar") == null, "кабанов и стражей на острове нет")
			wait = 30
			step = 1
		1:
			# Игрок идёт на запад к морю от точки у западного берега — должен остановиться на суше
			player.global_position = w.ground(-120.0, 10.0)
			start_pos = player.global_position
			frames_walked = 0
			step = 2
		2:
			player.move_input = Vector2(-1, 0)
			frames_walked += 1
			if frames_walked > 60 * 8:
				player.move_input = Vector2.ZERO
				var p := player.global_position
				check(w.is_walkable(p.x, p.z), "игрок не зашёл в море (x=%.1f)" % p.x)
				check(p.y > w.sea_level, "игрок не под водой")
				step = 3
		3:
			var tr: Dictionary = w.transitions()[0]
			var c := IslandWorld.v2(tr["center"])
			player.global_position = w.ground(c.x, c.y, 0.3)
			wait = 10
			step = 4
		4:
			check(main.hud._msg_label.text.contains("материк"), "переход в порту: сообщение")
			ok_done()
