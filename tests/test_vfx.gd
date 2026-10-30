extends "res://tests/test_base.gd"
## Графика зверей и эффекты: модели всех зверей и всех стадий питомцев собираются (с разумным
## числом мешей), анимация работает; все функции Vfx создают эффекты, которые сами удаляются;
## всплывающий текст исчезает; метка приручения и крит-удар по зверю не ломают бой.

const MAX_MOB_MESHES := 26
const MAX_PET_MESHES := 36

var box: Node3D = null
var models: Array[Node3D] = []
var timer := 0


func run_step() -> void:
	match step:
		0:
			box = Node3D.new()
			box.name = "VfxTest"
			main.add_child(box)
			box.global_position = Vector3(0, 0, -5)
			_build_models()
			_spawn_effects()
			_test_mob()
			timer = 0
			step = 1
		1:
			# Несколько кадров анимации всех моделей (стоя и на бегу)
			timer += 1
			for n in models:
				var sp := String(n.get_meta("species"))
				CreatureModels.animate(n, sp, float(timer) * 0.05, 1.0 if timer % 2 == 0 else 0.0)
			if timer >= 30:
				check(_effects_left() > 0, "эффекты ещё видны: %d" % _effects_left())
				wait = 60 * 4
				step = 2
		2:
			check(_effects_left() == 0, "все эффекты удалились сами (осталось %d)" % _effects_left())
			check(box.get_child_count() == models.size(), "в контейнере остались только модели: %d/%d"
				% [box.get_child_count(), models.size()])
			var m := find_mob("boar")
			if m != null:
				m.set_tame_mark(false)
			box.queue_free()
			ok_done()


func _build_models() -> void:
	var x := -12.0
	for key in MobData.TYPES:
		var id := String(key)
		var d := MobData.get_type(id)
		var n := _holder(id, Vector3(x, 0, 0))
		var m := CreatureModels.build(n, id, d["color"], float(d["scale"]))
		check(m != null, "модель зверя %s собрана" % id)
		var cnt := _meshes(n)
		check(cnt >= 10 and cnt <= MAX_MOB_MESHES, "мешей у зверя %s: %d" % [id, cnt])
		check(n.has_meta("anim"), "у модели %s есть части для анимации" % id)
		for st in PetData.STAGE_LEVELS.size():
			var lvl := int(PetData.STAGE_LEVELS[st])
			var sc := PetData.stage_scale(id, lvl)
			var p := _holder(id, Vector3(x, 0, 3.0 + 3.0 * float(st)))
			check(CreatureModels.build(p, id, PetData.stage_color(id, lvl), sc) != null, "модель питомца %s собрана" % id)
			CreatureModels.decorate_pet(p, id, sc, PetData.stage_for(lvl), PetData.role(id))
			check(p.find_child("Collar", true, false) != null, "ошейник у питомца %s (стадия %d)" % [id, st + 1])
			if st >= 1:
				check(p.find_child("Mark0", true, false) != null, "узоры у питомца %s (стадия %d)" % [id, st + 1])
			check((p.find_child("Halo", true, false) != null) == (st == 2), "нимб только на 3-й стадии: %s" % id)
			var pc := _meshes(p)
			check(pc <= MAX_PET_MESHES, "мешей у питомца %s стадии %d: %d" % [id, st + 1, pc])
		x += 4.0


func _holder(id: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.set_meta("species", id)
	box.add_child(n)
	n.position = pos
	models.append(n)
	return n


func _spawn_effects() -> void:
	var p := box.global_position + Vector3(0, 1, 0)
	var roots: Array[Node3D] = [
		Vfx.hit_spark(box, p),
		Vfx.hit_spark(box, p, Color(1, 0.3, 0.3), 1.6),
		Vfx.slash_arc(box, p, Vector3(1, 0, 0), Color(1, 0.4, 0.4)),
		Vfx.slash_arc(box, p, Vector3.ZERO),
		Vfx.heal_sparkles(box, p),
		Vfx.level_up(box, p),
		Vfx.tame_success(box, p),
		Vfx.evolution(box, p),
		Vfx.pickup(box, p),
		Vfx.magic_burst(box, p, Color(0.6, 0.3, 1.0), 2.0),
		Vfx.death_puff(box, p, 1.5),
	]
	var ok := 0
	for r in roots:
		if r != null and r.is_in_group("vfx"):
			ok += 1
	check(ok == roots.size(), "все эффекты Vfx созданы: %d/%d" % [ok, roots.size()])
	Projectile.burst(box, p, Color(1, 0.4, 0.2), 1.5, 0.3)
	CreatureModels.spawn_ring(box, p, 3.0, Color(1, 0.5, 0.2), 0.5)
	Util.float_text(box, p, "123", Color.WHITE)
	Util.float_text(box, p, "45", Color(1, 0.8, 0.2), 1.5)
	Util.float_text(box, p, "Эволюция!", Color(1, 0.9, 0.4), 1.4)
	# Вне дерева сцены эффекты не создаются и не падают
	var lonely := Node3D.new()
	check(Vfx.hit_spark(lonely, Vector3.ZERO) == null, "эффект без сцены не создаётся")
	Util.float_text(lonely, Vector3.ZERO, "1", Color.WHITE)
	lonely.free()


func _test_mob() -> void:
	var m := find_mob("boar")
	check(m != null, "найден кабан")
	m.set_tame_mark(true)
	check(m.get("_mark") != null and m.tame_marked, "метка приручения построена")
	var hp0 := m.hp
	m.take_damage(1, null, true)
	check(m.hp == hp0 - 1, "крит-удар по зверю наносит урон")


## Сколько узлов эффектов (и текстов) осталось в контейнере, кроме моделей.
func _effects_left() -> int:
	return box.get_child_count() - models.size()


func _meshes(n: Node) -> int:
	return n.find_children("*", "MeshInstance3D", true, false).size()
