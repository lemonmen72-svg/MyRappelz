extends "res://tests/test_base.gd"
## Мосты и питомец у реки: настил моста лежит на дороге и вровень с землёй у концов (без ступеньки), между
## концами — не ниже земли и без крутых изломов; мост и подходы к нему проходимы; путь в обход реки
## (IslandWorld.bridge_waypoint) ведёт к мосту. Питомец, оставленный на одном берегу, когда хозяин на другом,
## сам приходит к хозяину (через мост или, если застрял, переносом) — и когда хозяин стоит на мосту.
## Подпись над питомцем не крупнее подписи зверя.

## Сколько кадров ждать питомца (60 кадров = 1 с).
const PET_WAIT := 60 * 14

var pet: Pet = null
var br: Dictionary = {}
var frames := 0
var on_bridge_seen := false
var teleports_before := 0


func race_class() -> Array:
	return ["dark_elf", "assassin"]


func before_start() -> void:
	game.active_pet = game.add_pet("turtle", PetData.stage_name("turtle", 6), 6)


func run_step() -> void:
	var player: Player = main.player
	var w := IslandWorld.current
	match step:
		0:
			check(w != null and w.bridges.size() >= 2, "мосты через реку: %d" % w.bridges.size())
			var road_half := float(w.cfg.get("roads", {}).get("width", 3.2)) * 0.5
			for b in w.bridges:
				_check_bridge(w, b, road_half)
			pet = main.pets.active_pet
			check(pet != null, "питомец призван")
			pet.set_mode("follow")
			# Подпись питомца — не крупнее подписи зверя (питомец всегда близко к камере)
			var m := _any_mob()
			check(m != null, "зверь для сравнения подписи найден")
			if m != null:
				var pet_h := pet._label.pixel_size * float(pet._label.font_size)
				var mob_h := m._label.pixel_size * float(m._label.font_size)
				check(pet_h <= mob_h + 0.0001 and pet_h >= mob_h * 0.5,
					"подпись питомца не крупнее подписи зверя (%.3f м против %.3f м)" % [pet_h, mob_h])
			br = w.bridges[0]
			# Хозяин — на дальнем берегу в стороне от моста, питомец — на ближнем: по прямой между ними река
			var spots := _bank_spots(w, br)
			check(not spots.is_empty(), "места на берегах у моста найдены")
			if spots.is_empty():
				ok_done()
				return
			var ps: Vector3 = spots[0]
			var os: Vector3 = spots[1]
			check(not w.segment_walkable(ps, os), "по прямой между берегами — вода")
			var wp := w.bridge_waypoint(ps, os)
			check(wp.is_finite(), "путь в обход реки найден")
			var axis := _axis(br)
			var a: Vector3 = br["a"]
			var e: Vector3 = br["b"]
			if wp.is_finite():
				var d_a := Vector2(wp.x - (a - axis * IslandWorld.BRIDGE_APPROACH).x, wp.z - (a - axis * IslandWorld.BRIDGE_APPROACH).z).length()
				var d_e := Vector2(wp.x - (e + axis * IslandWorld.BRIDGE_APPROACH).x, wp.z - (e + axis * IslandWorld.BRIDGE_APPROACH).z).length()
				check(minf(d_a, d_e) < 0.5, "путь ведёт к подходу моста (%.2f м)" % minf(d_a, d_e))
			player.global_position = os
			player.velocity = Vector3.ZERO
			pet.global_position = ps
			pet.velocity = Vector3.ZERO
			teleports_before = pet.stuck_teleports
			frames = 0
			on_bridge_seen = false
			step = 1
		1:
			# Ждём питомца у хозяина
			frames += 1
			player.velocity = Vector3.ZERO
			if w._near_bridge(br, pet.global_position, 0.0):
				on_bridge_seen = true
			var d := _flat(pet.global_position, player.global_position)
			if d < Pet.FOLLOW_DIST + 1.5 or frames > PET_WAIT:
				var tp := pet.stuck_teleports - teleports_before
				print("  питомец у хозяина за %.1f с: по мосту %s, переносов %d" % [frames / 60.0, on_bridge_seen, tp])
				check(d < Pet.FOLLOW_DIST + 1.5, "питомец пришёл к хозяину на другой берег (%.1f м)" % d)
				check(on_bridge_seen or tp > 0, "через мост или переносом (не сквозь реку)")
				# Хозяин на середине моста, питомец — на берегу в стороне от дороги
				var mid := IslandWorld.bridge_point(br, 0.5)
				player.global_position = mid + Vector3(0, 0.15, 0)
				var spots := _bank_spots(w, br)
				pet.global_position = spots[0]
				pet.velocity = Vector3.ZERO
				frames = 0
				step = 2
		2:
			frames += 1
			player.velocity = Vector3.ZERO
			var d := _flat(pet.global_position, player.global_position)
			if d < Pet.FOLLOW_DIST + 1.5 or frames > PET_WAIT:
				print("  к хозяину на мосту — за %.1f с" % (frames / 60.0))
				check(d < Pet.FOLLOW_DIST + 1.5, "питомец пришёл к хозяину на мост (%.1f м)" % d)
				check(pet.global_position.y > IslandWorld.bridge_point(br, 0.5).y - 1.5, "питомец не в реке под мостом")
				ok_done()


## Мост: настил на дороге, концы вровень с землёй, между ними — не ниже земли, без крутых изломов, проходим.
func _check_bridge(w: IslandWorld, b: Dictionary, road_half: float) -> void:
	var a: Vector3 = b["a"]
	var e: Vector3 = b["b"]
	var deck: PackedFloat32Array = b.get("deck", PackedFloat32Array())
	check(deck.size() == IslandWorld.BRIDGE_SAMPLES + 1, "у моста профиль настила")
	var p0 := IslandWorld.bridge_point(b, 0.0)
	var p1 := IslandWorld.bridge_point(b, 1.0)
	check(absf(p0.y - w.height_at(a.x, a.z)) < 0.06 and absf(p1.y - w.height_at(e.x, e.z)) < 0.06,
		"концы настила вровень с землёй (%.2f / %.2f м)" % [p0.y - w.height_at(a.x, a.z), p1.y - w.height_at(e.x, e.z)])
	check(w.road_distance(a.x, a.z) < road_half and w.road_distance(e.x, e.z) < road_half,
		"концы моста на дороге (%.1f / %.1f м от оси)" % [w.road_distance(a.x, a.z), w.road_distance(e.x, e.z)])
	var low := 0
	var steep := 0
	var blocked := 0
	var n := IslandWorld.BRIDGE_SAMPLES
	var length := Vector2(e.x - a.x, e.z - a.z).length()
	for i in range(1, n):
		var p := IslandWorld.bridge_point(b, float(i) / float(n))
		if p.y < w.height_at(p.x, p.z) + 0.04:
			low += 1
	for i in n:
		var dy := absf(deck[i + 1] - deck[i])
		if dy / (length / float(n)) > 0.85:
			steep += 1
	for i in 21:
		var p := IslandWorld.bridge_point(b, float(i) / 20.0)
		if not w.is_walkable(p.x, p.z):
			blocked += 1
	var axis := _axis(b)
	for q in [a - axis * IslandWorld.BRIDGE_APPROACH, e + axis * IslandWorld.BRIDGE_APPROACH]:
		var v: Vector3 = q
		if not w.is_walkable(v.x, v.z):
			blocked += 1
	check(low == 0, "настил не уходит в землю (точек ниже: %d)" % low)
	check(steep == 0, "настил без крутых изломов (круче 0.85: %d)" % steep)
	check(blocked == 0, "по мосту и к его подходам можно пройти (непроходимых точек: %d)" % blocked)


## Точки на двух берегах у моста в стороне от него: [ближний к a, дальний у b] (проходимые, по прямой — река).
func _bank_spots(w: IslandWorld, b: Dictionary) -> Array:
	var a: Vector3 = b["a"]
	var e: Vector3 = b["b"]
	var axis := _axis(b)
	var side := Vector3(-axis.z, 0.0, axis.x)
	for sg in [1.0, -1.0]:
		for off in [6.0, 5.0, 4.0, 7.0, 8.0]:
			var ps := a - axis * 2.0 + side * float(off) * float(sg)
			var os := e + axis * 2.0 + side * float(off) * float(sg)
			if w.is_walkable(ps.x, ps.z) and w.is_walkable(os.x, os.z) and not w.segment_walkable(ps, os):
				return [w.ground(ps.x, ps.z, 0.15), w.ground(os.x, os.z, 0.15)]
	return []


func _axis(b: Dictionary) -> Vector3:
	var a: Vector3 = b["a"]
	var e: Vector3 = b["b"]
	return Vector3(e.x - a.x, 0.0, e.z - a.z).normalized()


func _flat(p: Vector3, q: Vector3) -> float:
	return Vector2(p.x - q.x, p.z - q.z).length()


func _any_mob() -> Mob:
	for n in get_tree().get_nodes_in_group("mobs"):
		var m := n as Mob
		if m != null and m._label != null:
			return m
	return null
