extends "res://tests/test_base.gd"
## Нейтральные и агрессивные звери (задача Максима 10): обычные звери нейтральны — героя рядом не трогают, пока их не
## атакуют; после удара героя дерутся с ним (сосед-зверь на помощь не идёт); ослабление умением героя и урон со
## временем тоже втягивают нейтрального в бой (Mob.provoke). Боссы и мини-боссы (MobStats.is_aggressive) нападают
## сами, когда герой подходит на дистанцию их атаки с запасом (Mob.aggro_range = _reach() + AGGRO_MARGIN), и не
## трогают героя дальше. Питомец в «Авто» сам нападает на нейтрального зверя — и тот бьёт питомца в ответ.

var arena := Vector3.ZERO
var timer := 0
var mob: Mob = null
var bystander: Mob = null
var elite: Mob = null
## Агрессивные для проверки: мини-босс (кентавр — «Редкий»), босс.
const ELITES := [["centaur", 10], ["boss_pheasant", 15]]
var elite_i := 0


func race_class() -> Array:
	return ["human", "wanderer"]


func hero_level() -> int:
	return 10


func before_start() -> void:
	AdminPanel.god = true
	game.add_pet("wolf", "Серохвост", 10)
	game.active_pet = -1


func run_step() -> void:
	var p: Player = main.player
	match step:
		0:
			_unit_rules()
			# Арена: звери острова убраны (без возрождения)
			for n in get_tree().get_nodes_in_group("mobs"):
				var m := n as Mob
				m.remove_from_group("mobs")
				m.queue_free()
			arena = _find_arena()
			check(arena != Vector3.ZERO, "арена найдена: %s" % arena)
			mob = main.spawn_mob("pheasant", 10, arena)
			bystander = main.spawn_mob("pheasant", 10, _ground(Vector3(-4.0, 0, 0)))
			check(not mob.aggressive and is_zero_approx(mob.aggro_range), "фазан — нейтральный")
			_put_hero(arena + Vector3(0, 0, 2.0))
			p.last_attacker = null
			timer = 0
			step = 1
		1:
			# Нейтральный зверь не трогает героя рядом 3 с
			timer += 1
			_keep_near(mob, 2.0)
			if mob.target != null or bystander.target != null or p.last_attacker != null:
				fail("нейтральный зверь напал сам на героя рядом")
				return
			if timer < 180:
				return
			check(true, "нейтральный фазан 3 с стоит рядом с героем и не нападает")
			p._set_target(mob)
			timer = 0
			step = 2
		2:
			# Герой бьёт — зверь отвечает
			timer += 1
			_keep_near(mob, 2.0)
			if mob.target == p:
				check(true, "после удара героя зверь бьёт его (%d кадров)" % timer)
				timer = 0
				step = 3
				return
			p.try_attack()
			if timer > 300:
				fail("герой не попал по зверю за 5 с")
		3:
			timer += 1
			_keep_near(mob, 2.0)
			if bystander.target != null:
				fail("соседний нейтральный зверь вступился за сородича")
				return
			if is_same(p.last_attacker, mob):
				check(true, "атакованный зверь ударил героя (%d кадров)" % timer)
				check(bystander.target == null, "соседний нейтральный зверь на помощь не идёт")
				mob.consume()
				bystander.consume()
				_check_provoke()
				elite_i = 0
				step = 4
				return
			if timer > 300:
				fail("атакованный зверь не бьёт героя")
		4:
			# Агрессивный: вдали от героя — не трогает
			if elite_i >= ELITES.size():
				step = 7
				return
			var e: Array = ELITES[elite_i]
			elite = main.spawn_mob(String(e[0]), int(e[1]), _ground(Vector3(18.0, 0, 0)))
			_put_hero(arena)
			p.last_attacker = null
			check(elite.aggressive, "%s — агрессивный" % elite.mob_name)
			check(elite.aggro_range >= elite._reach() + 3.0 and elite.aggro_range <= elite._reach() + 6.0,
				"%s замечает на %.1f м (атака достаёт на %.1f м)" % [elite.mob_name, elite.aggro_range, elite._reach()])
			timer = 0
			step = 5
		5:
			timer += 1
			var d := _dist(elite)
			if elite.target != null:
				fail("%s напал на героя в %.1f м (замечает на %.1f м)" % [elite.mob_name, d, elite.aggro_range])
				return
			if timer < 120:
				return
			check(d > elite.aggro_range, "%s в %.1f м не нападает" % [elite.mob_name, d])
			# Герой подошёл на дистанцию атаки
			var dir := p.global_position - elite.global_position
			dir.y = 0.0
			_put_hero(elite.global_position + dir.normalized() * maxf(1.0, elite.aggro_range - 1.5))
			timer = 0
			step = 6
		6:
			timer += 1
			if elite.target == p:
				if is_same(p.last_attacker, elite):
					check(true, "%s сам напал на подошедшего героя и ударил (%d кадров)" % [elite.mob_name, timer])
					elite.consume()
					elite = null
					elite_i += 1
					step = 4
					return
			elif elite.target != null:
				fail("%s взял чужую цель" % elite.mob_name)
				return
			if timer > 360:
				fail("%s не нападает на героя в %.1f м" % [elite.mob_name, _dist(elite)])
		7:
			# Питомец в «Авто» сам нападает на нейтрального зверя, тот бьёт питомца в ответ
			_put_hero(arena)
			check(main.pets.summon(0), "волк призван")
			main._on_action("pet_auto")
			var pet: Pet = main.pets.active_pet
			check(pet != null and pet.mode == "auto", "питомец в режиме «Авто»")
			mob = main.spawn_mob("pheasant", 8, _ground(Vector3(6.0, 0, 0)))
			timer = 0
			step = 8
		8:
			timer += 1
			var pet: Pet = main.pets.active_pet
			if pet == null:
				fail("питомец пропал")
				return
			if mob_ok(mob) and mob.target == pet:
				check(pet.target == mob, "«Авто»: питомец напал на нейтрального зверя, зверь отвечает питомцу (%d кадров)" % timer)
				mob.consume()
				ok_done()
				return
			if mob_ok(mob) and mob.target == p:
				fail("нейтральный зверь, которого бьёт питомец, напал на героя")
				return
			if timer > 600:
				fail("«Авто»: питомец не втянул нейтрального зверя в бой (цель питомца: %s)" % [pet.target])


## Правило агрессии: боссы и «Редкие» звери мира — агрессивны, остальные — нейтральны.
func _unit_rules() -> void:
	var aggr: PackedStringArray = []
	for k in MobData.TYPES:
		var id := String(k)
		var want := MobData.is_boss(id) or (String(MobData.get_type(id)["rarity"]) == "rare")
		check(MobStats.is_aggressive(id) == want, "%s: %s" % [id, "агрессивный" if want else "нейтральный"])
		if want:
			aggr.append(id)
	for id in ["anathema_chief", "flyfish_drake", "centaur"]:
		check(MobStats.is_mini_boss(id) and MobStats.is_aggressive(id), "мини-босс %s агрессивен" % id)
	for id in ["pheasant", "wolf", "turtle", "panther", "flyfish", "anathema", "anathema_blade"]:
		check(not MobStats.is_aggressive(id), "%s нейтрален" % id)
	print("  агрессивные: " + ", ".join(aggr))


## Ослабление умением героя и урон со временем втягивают нейтрального зверя в бой (Mob.provoke).
func _check_provoke() -> void:
	var p: Player = main.player
	var a: Mob = main.spawn_mob("turtle", 10, _ground(Vector3(8.0, 0, 0)))
	var b: Mob = main.spawn_mob("panther", 10, _ground(Vector3(-8.0, 0, 0)))
	var c: Mob = main.spawn_mob("wolf", 10, _ground(Vector3(0, 0, -8.0)))
	check(a.target == null and b.target == null and c.target == null, "нейтральные звери без цели")
	p._fx.status(a, "slow", 3.0, 0.3, {})
	check(a.target == p, "ослабление умением героя — зверь вступает в бой")
	b.add_dot("test", 1.0, 3.0, p)
	check(b.target == p, "урон со временем от героя — зверь вступает в бой")
	c.take_damage(1, p)
	check(c.target == p, "урон героя — зверь вступает в бой")
	# Зверь уже дерётся с другим — провокация цель не меняет
	var keep := c.target
	c.provoke(a)
	check(c.target == keep, "provoke не отнимает цель у дерущегося зверя")
	a.consume()
	b.consume()
	c.consume()


func _put_hero(pos: Vector3) -> void:
	var p: Player = main.player
	var g := pos
	if IslandWorld.current != null:
		g = IslandWorld.current.ground(pos.x, pos.z)
	p.global_position = g + Vector3(0, 0.1, 0)
	p.velocity = Vector3.ZERO


## Держать героя рядом со зверем (зверь мог отойти), HP не трогаем.
func _keep_near(m: Mob, dist: float) -> void:
	if _dist(m) > dist + 0.6:
		_put_hero(m.global_position + Vector3(0, 0, dist))


func _dist(m: Mob) -> float:
	var d := m.global_position - main.player.global_position
	d.y = 0.0
	return d.length()


func _ground(off: Vector3) -> Vector3:
	var pp := arena + off
	if IslandWorld.current != null:
		return IslandWorld.current.ground(pp.x, pp.z)
	return pp


## Ровное место вне безопасных зон, далеко от воды: вокруг на 15 м проходимо.
func _find_arena() -> Vector3:
	var w := IslandWorld.current
	if w == null:
		return Vector3.ZERO
	var r := 20.0
	while r < 260.0:
		for k in 32:
			var ang := TAU * float(k) / 32.0
			var q := Vector2(cos(ang), sin(ang)) * r
			if _arena_ok(w, q):
				return w.ground(q.x, q.y)
		r += 5.0
	return Vector3.ZERO


func _arena_ok(w: IslandWorld, q: Vector2) -> bool:
	if not w.is_walkable(q.x, q.y) or w.in_safe_zone(Vector3(q.x, 0, q.y)) or w.water_distance(q.x, q.y) < 12.0:
		return false
	var h0 := w.height_at(q.x, q.y)
	for k in 8:
		var ang := TAU * float(k) / 8.0
		for rr in [5.0, 10.0, 15.0, 22.0]:
			var pp := q + Vector2(cos(ang), sin(ang)) * float(rr)
			if not w.is_walkable(pp.x, pp.y) or w.in_safe_zone(Vector3(pp.x, 0, pp.y)) or absf(w.height_at(pp.x, pp.y) - h0) > 4.0:
				return false
	return true
