extends "res://tests/test_base.gd"
## Старт без питомца (задача Максима 10: «на первом уровне я вообще не в состоянии справиться ни с кем, а меня убивают
## за 3–4 удара»): вход новичка MobStats.MOB_HP_START / MOB_ATK_START. Бродяга 1, 3, 5 ур. с учебным мечом, без
## питомца, умений и зелий против зверя своего уровня:
## • по формулам (Combat): удар зверя снимает не больше 12 % HP героя, до смерти героя ≥ 8 ударов, сила зверя
##   (Combat.power_ratio) ≤ 0.75 — бой выигрышный;
## • настоящий бой в мире (обычные атаки героя каждый кадр, зверь отвечает — он нейтрален и сам не нападает): герой
##   побеждает каждого (фазан, черепаха, на 1 ур. и «Обычный» волк), у базовых зверей теряет в среднем 30–70 % HP,
##   ни один удар зверя (без крита) не снимает больше 12 % HP.

## [уровень героя и зверя, вид]: базовые фазан и черепаха, на 1-м ур. — ещё «Обычный» волк (сильнее базовых).
const FIGHTS := [[1, "pheasant"], [1, "turtle"], [1, "wolf"], [3, "pheasant"], [3, "turtle"], [5, "pheasant"], [5, "turtle"]]
const COMMON := ["pheasant", "turtle", "panther"]
const GOLD := 1000
## Доля HP героя, которую может снять один удар зверя (без крита).
const MAX_HIT := 0.12

var arena := Vector3.ZERO
var idx := 0
var mob: Mob = null
var frames := 0
var prev_hp := 0
var max_hit := 0.0
var lost_sum := 0.0
var lost_n := 0


func race_class() -> Array:
	return ["human", "wanderer"]


func run_step() -> void:
	var p: Player = main.player
	match step:
		0:
			seed(20261101)
			_unit_formulas()
			# Арена: звери острова убраны (без возрождения), чтобы бой шёл один на один
			for n in get_tree().get_nodes_in_group("mobs"):
				var m := n as Mob
				m.remove_from_group("mobs")
				m.queue_free()
			arena = _find_arena()
			check(arena != Vector3.ZERO, "арена найдена: %s" % arena)
			if game.weapon != "weapon_sword_1h_r1":
				if not game.inventory.has("weapon_sword_1h_r1"):
					game.inventory.add("weapon_sword_1h_r1")
				check(p.equip("weapon_sword_1h_r1") == "", "учебный меч надет")
			check(game.weapon == "weapon_sword_1h_r1" and game.offhand == "", "у Бродяги учебный меч, вторая рука пуста")
			game.xp_mult = 1
			step = 1
		1:
			if idx >= FIGHTS.size():
				var avg := lost_sum / maxf(1.0, float(lost_n))
				check(avg >= 0.3 and avg <= 0.7, "базовые звери своего уровня: в среднем потеряно %.0f %% HP" % (avg * 100.0))
				game.level = 1
				game.xp = 0
				p.recalc_stats()
				ok_done()
				return
			var f: Array = FIGHTS[idx]
			var lvl := int(f[0])
			game.level = lvl
			game.xp = 0
			game.gold = GOLD
			p.recalc_stats()
			p.hp = p.max_hp
			p.global_position = arena + Vector3(0, 0.1, 1.6)
			mob = main.spawn_mob(String(f[1]), lvl, arena)
			check(mob != null and not mob.aggressive, "%s %d ур. — нейтральный" % [String(f[1]), lvl])
			frames = 0
			max_hit = 0.0
			step = 2
		2:
			# Нейтральный зверь рядом с героем не нападает сам
			frames += 1
			if mob.target != null or p.hp < p.max_hp:
				fail("%s напал сам на героя рядом" % mob.mob_name)
				return
			if frames < 45:
				return
			p._set_target(mob)
			prev_hp = p.hp
			frames = 0
			step = 3
		3:
			frames += 1
			var f: Array = FIGHTS[idx]
			if game.gold < GOLD:
				fail("Бродяга %d ур. погиб в бою с %s своего уровня" % [int(f[0]), mob.mob_name])
				return
			if p.hp < prev_hp:
				if not mob._last_crit:
					max_hit = maxf(max_hit, float(prev_hp - p.hp) / float(p.max_hp))
			prev_hp = p.hp
			if not mob_ok(mob):
				var left := float(p.hp) / float(p.max_hp)
				check(true, "Бродяга %d ур. победил %s за %.1f с: осталось %.0f %% HP, сильнейший удар зверя — %.0f %% HP"
					% [int(f[0]), String(f[1]), float(frames) / 60.0, left * 100.0, max_hit * 100.0])
				check(max_hit <= MAX_HIT, "%s %d ур.: удар зверя ≤ %.0f %% HP героя (%.1f %%)" % [String(f[1]), int(f[0]),
					MAX_HIT * 100.0, max_hit * 100.0])
				if String(f[1]) != "wolf":
					lost_sum += 1.0 - left
					lost_n += 1
				mob = null
				idx += 1
				step = 1
				wait = 10
				return
			if frames > 60 * 40:
				fail("бой с %s %d ур. затянулся (HP зверя %d/%d)" % [mob.mob_name, int(f[0]), mob.hp, mob.max_hp])
				return
			# Держимся рядом со зверем (он мог чуть сдвинуться) и бьём обычной атакой
			var to := mob.global_position - p.global_position
			to.y = 0.0
			if to.length() > 2.2:
				var pos := mob.global_position + Vector3(0, 0.1, 1.6)
				p.global_position = pos
			p._set_target(mob)
			p.try_attack()


## Формулы (Combat): удар зверя своего уровня, ударов до смерти героя, сила зверя.
func _unit_formulas() -> void:
	var p: Player = main.player
	for lvl in [1, 3, 5]:
		game.level = lvl
		p.recalc_stats()
		var hp := Combat.profile_of(p)
		for id in COMMON:
			var m := Mob.new()
			m.setup(String(id), -1, Vector3.ZERO, lvl)
			var dmg := Combat.damage(float(m.atk) * 1.08, float(m.atk), Combat.defense_of(p, m.magic), lvl, lvl)
			var hits := ceili(float(p.max_hp) / float(dmg))
			var r := Combat.power_ratio(hp, Combat.profile_of(m))
			check(float(dmg) <= MAX_HIT * float(p.max_hp) and hits >= 8 and r <= 0.75,
				"Бродяга %d ур. (HP %d) против %s: удар до %d (%.0f %% HP), до смерти %d ударов, сила зверя %.2f"
				% [lvl, p.max_hp, String(id), dmg, 100.0 * float(dmg) / float(p.max_hp), hits, r])
			m.free()
	game.level = 1
	p.recalc_stats()


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
		for rr in [5.0, 10.0, 15.0]:
			var pp := q + Vector2(cos(ang), sin(ang)) * float(rr)
			if not w.is_walkable(pp.x, pp.y) or w.in_safe_zone(Vector3(pp.x, 0, pp.y)) or absf(w.height_at(pp.x, pp.y) - h0) > 4.0:
				return false
	return true
