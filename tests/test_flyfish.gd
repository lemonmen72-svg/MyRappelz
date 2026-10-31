extends "res://tests/test_base.gd"
## Летающие рыбы: три вида (зубан, парусник, змеекрыл) — звери мира, не питомцы и не приручаются (фиолетовый
## значок, «Приручить» отказывает, карт нет); модели из файлов со всеми 7 клипами; рыба парит на уровне головы
## героя (голова по кости в клипе Idle выше 1.2 м), после клипа Death лежит у земли; запасная модель из примитивов
## тоже парит; спауны на острове вне безопасных зон; болт арбалета долетает до рыбы на высоте парения и ранит её,
## обычная атака клинками по рыбе попадает; после смерти рыба падает на землю.

const FISH := ["flyfish", "flyfish_sail", "flyfish_drake"]
## Голова рыбы в покое и в полёте выше этого (м над землёй), после смерти — ниже DOWN_Y.
const HOVER_MIN := 1.2
const DOWN_Y := 0.6

var holders: Array[Node3D] = []
var mob: Mob = null
var bolt: Projectile = null
var bolt_last := Vector3.ZERO
var hp0 := 0
var frames := 0
var death_wait := 0


func race_class() -> Array:
	return ["dark_elf", "assassin"]


func run_step() -> void:
	var player: Player = main.player
	var hud: HUD = main.hud
	var tm: Taming = main.taming
	match step:
		0:
			_unit_data()
			_unit_spawns()
			_unit_fallback()
			_build_models()
			wait = 30
			step = 1
		1:
			# Модели из файла парят: играет Idle, голова по кости — на уровне головы героя
			for h in holders:
				var ca := CreatureModels.asset_of(h)
				var id := String(h.get_meta("species"))
				check(ca.anim != null and ca.anim.is_playing() and ca.anim.current_animation == String(ca.clips["idle"]),
					"%s: играет Idle (%s)" % [id, ca.anim.current_animation if ca.anim != null else "нет"])
				var hy := _head_y(h)
				check(hy > HOVER_MIN and hy < 2.4, "%s парит: голова на высоте %.2f м" % [id, hy])
				death_wait = maxi(death_wait, int(ceil(ca.play_death() * 60.0)) + 20)
			wait = death_wait
			step = 2
		2:
			# После клипа Death рыба лежит у земли
			for h in holders:
				var hy := _head_y(h)
				check(hy < DOWN_Y and hy > -0.05, "%s после смерти у земли: голова на высоте %.2f м" % [h.get_meta("species"), hy])
				h.queue_free()
			holders.clear()
			# Рыба в мире: цель на высоте парения, приручить нельзя
			mob = find_mob("flyfish")
			check(mob != null, "летучий зубан есть в мире")
			if mob == null:
				return
			stand_near(mob, 6.0)
			check(mob.hover_y > HOVER_MIN, "зубан парит: hover_y %.2f" % mob.hover_y)
			check(mob.aim_point().y - mob.global_position.y > HOVER_MIN, "прицел на высоте тела: %.2f"
				% (mob.aim_point().y - mob.global_position.y))
			check(mob._label.position.y > mob.hover_y, "подпись над рыбой: %.2f" % mob._label.position.y)
			player._set_target(mob)
			check(hud.target_tame_state == Taming.BADGE_NO and hud.target_card_tier == "",
				"значок зубана: нельзя приручить (%s)" % hud.target_tame_state)
			tm.cooldown = 0.0
			main._on_action("tame")
			check(tm.marked == null and not mob.tame_marked, "метка на рыбу не ставится")
			check(hud._msg_label.text.contains("Этого зверя нельзя приручить"), "сообщение: " + hud._msg_label.text)
			# Болт арбалета летит к рыбе
			hp0 = mob.hp
			bolt = Projectile.new()
			bolt.setup(mob, player, 3, false, "bolt", Color(0.9, 0.8, 0.5))
			main.add_child(bolt)
			bolt.global_position = player.global_position + Vector3(0, 1.25, 0)
			frames = 0
			step = 3
		3:
			frames += 1
			main.player.hp = main.player.max_hp
			if is_instance_valid(bolt):
				bolt_last = bolt.global_position
				if frames > 240:
					fail("болт не долетел за 4 с")
				return
			check(mob_ok(mob) and mob.hp < hp0, "болт ранил рыбу: %d → %d" % [hp0, mob.hp])
			var dy := bolt_last.y - mob.global_position.y
			check(dy > 1.0, "болт попал на высоте тела: %.2f м над землёй" % dy)
			# Обычная атака клинками (может промахнуться — бьём, пока не попадёт)
			stand_near(mob, 1.4)
			mob.target = null
			hp0 = mob.hp
			frames = 0
			step = 4
		4:
			frames += 1
			player.hp = player.max_hp
			if not mob_ok(mob):
				fail("рыба пропала до удара клинками")
				return
			if mob.hp < hp0:
				check(true, "удар клинками по рыбе попал: %d → %d" % [hp0, mob.hp])
				mob.take_damage(mob.hp + 5, player)
				check(mob.is_dead, "рыба побеждена")
				wait = 100
				step = 5
				return
			if frames > 60 * 20:
				fail("за 20 с ни один удар клинками не попал по рыбе")
				return
			if frames % 10 == 0:
				var d := mob.global_position - player.global_position
				d.y = 0.0
				if d.length() > 1.6:
					stand_near(mob, 1.4)
				player._set_target(mob)
				player.attack_cd = 0.0
				player.try_attack()
		5:
			# Клип Death уронил рыбу на землю (узел ещё не удалён: растворяется после паузы)
			if is_instance_valid(mob):
				var ca := mob._asset
				if ca != null and ca.skeleton != null:
					var hy := _head_y(mob)
					check(hy < DOWN_Y, "убитая рыба упала на землю: голова на высоте %.2f м" % hy)
			ok_done()


## Виды, предметы, приручение, клипы в creatures.json.
func _unit_data() -> void:
	for id in FISH:
		check(MobData.TYPES.has(id) and MobData.flying(id), "%s — летающий зверь" % id)
		check(not MobData.tameable(id) and Taming.badge_state(id) == Taming.BADGE_NO, "%s нельзя приручить" % id)
		check(ItemData.card_for(id) == "" and ItemData.soul_card_for(id) == "", "у %s нет карт" % id)
		check(not PetData.SPECIES.has(id), "%s не бывает питомцем" % id)
		check(MobData.rarity_tier(id) < int(MobData.RARITY_TIER["unique"]), "%s не уникальный" % id)
		for e in MobData.get_type(id)["loot"]:
			check(not ItemData.get_item(String(e[0])).is_empty(), "добыча %s есть в предметах: %s" % [id, e[0]])
		check(CreatureAsset.has_asset(id), "модель %s из файла есть" % id)
		var inf := CreatureAsset.info_for(id)
		check(float(inf["hover"]) > HOVER_MIN and float(inf["height"]) > float(inf["hover"]),
			"%s: парит на %.2f м, верх %.2f м" % [id, inf["hover"], inf["height"]])
		var clips: Dictionary = inf["clips"]
		for k in ["Idle", "Walk", "Run", "Attack", "Hit", "Death", "Cast"]:
			check(clips.has(k), "у %s в creatures.json есть клип %s" % [id, k])
	check(int(MobData.get_type("flyfish")["level"]) < int(MobData.get_type("flyfish_sail")["level"])
		and int(MobData.get_type("flyfish_sail")["level"]) < int(MobData.get_type("flyfish_drake")["level"]),
		"уровни рыб растут: зубан < парусник < змеекрыл")
	for id in ["flyfish_scale", "sail_fin", "drake_crest"]:
		check(ItemData.item_type(id) == "trophy", "трофей %s" % id)
		var ic := ItemIcon.make(id, 64.0)
		check(ic.item_id == id, "значок %s создаётся" % id)
		ic.free()


## Каждый вид рыб появляется на острове, вне безопасных зон и на суше.
func _unit_spawns() -> void:
	var w := IslandWorld.current
	for id in FISH:
		var n := 0
		for s in main._slots:
			var sl: Dictionary = s
			if String(sl["type"]) != id:
				continue
			n += 1
			var p: Vector3 = sl["pos"]
			check(not w.in_safe_zone(p) and w.is_walkable(p.x, p.z), "спаун %s вне безопасной зоны, на суше: %s" % [id, p])
		check(n >= 2, "спаунов %s на острове: %d" % [id, n])
		check(find_mob(id) != null, "%s есть в мире" % id)
	check(Taming.habitat_text("flyfish").contains("Пруд у Светлой рощи"), "где водится зубан: " + Taming.habitat_text("flyfish"))


## Запасная модель из примитивов (файлы выключены) тоже парит: тело на высоте парения.
func _unit_fallback() -> void:
	CreatureAsset.use_assets = false
	for id in FISH:
		var n := Node3D.new()
		main.add_child(n)
		var d := MobData.get_type(id)
		var m := CreatureModels.build(n, id, d["color"], 1.0)
		check(m != null and CreatureModels.asset_of(n) == null, "запасная модель %s собрана" % id)
		var body := n.find_child("Body", true, false) as Node3D
		check(body != null and body.position.y > HOVER_MIN, "запасная %s парит: %.2f м" % [id, body.position.y if body != null else -1.0])
		CreatureModels.animate(n, id, 0.5, 1.0)
		n.free()
	CreatureAsset.use_assets = true


## Модели из файлов в ряд у игрока (все 7 клипов).
func _build_models() -> void:
	var base: Vector3 = main.player.global_position + Vector3(0, 0, -6)
	var x := -3.0
	for id in FISH:
		var h := Node3D.new()
		h.set_meta("species", id)
		main.add_child(h)
		h.global_position = Vector3(base.x + x, base.y, base.z)
		x += 3.0
		var d := MobData.get_type(id)
		CreatureModels.build(h, id, d["color"], 1.0)
		var ca := CreatureModels.asset_of(h)
		check(ca != null and ca.skeleton != null, "модель %s из файла со скелетом" % id)
		if ca == null:
			continue
		for k in CreatureAsset.CLIPS:
			check(ca.clips.has(k), "у %s есть клип %s" % [id, k])
		holders.append(h)


## Высота кости головы модели из файла над узлом h (м).
func _head_y(h: Node3D) -> float:
	var ca: CreatureAsset = null
	if h is Mob:
		ca = (h as Mob)._asset
	else:
		ca = CreatureModels.asset_of(h)
	if ca == null or ca.skeleton == null:
		return -1.0
	var hb := ca.skeleton.find_bone(String((ca.info["bones"] as Dictionary).get("head", "Head")))
	if hb < 0:
		return -1.0
	var p := ca.skeleton.global_transform * ca.skeleton.get_bone_global_pose(hb).origin
	return p.y - h.global_position.y
