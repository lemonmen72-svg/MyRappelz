extends "res://tests/test_base.gd"
## Аниме-модель персонажа (CharacterModel): собирается для всех 6 сочетаний раса/класс,
## у эльфов есть уши, у каждого класса — своё оружие, бюджет мешей, анимации без ошибок.
## Модель игрока и торговца — CharacterModel; экран создания строит 3D-превью.

## Узлы оружия, которые должны быть у модели (по полю weapon класса).
const WEAPON_PARTS := {
	"axe": ["Axe"],
	"bow": ["Bow", "Quiver"],
	"sword_shield": ["Sword", "Shield"],
	"staff": ["Staff", "Orb"],
	"daggers": ["DaggerR", "DaggerL"],
}
const MAX_MESHES := 42

var models: Array[CharacterModel] = []
var create: CharacterCreate = null


func run_step() -> void:
	match step:
		0:
			var x := -9.0
			for cid in ClassData.CLASSES:
				var c := ClassData.cls(String(cid))
				var rid := String(c["race"])
				var wk := String(c["weapon"])
				var m := CharacterModel.new()
				m.setup(CharacterModel.spec_for(rid, String(cid)))
				main.add_child(m)
				m.position = Vector3(x, 0.0, 30.0)
				x += 3.0
				models.append(m)
				var who := "%s/%s" % [rid, String(cid)]
				check(m.weapon_kind == wk, "%s: оружие %s" % [who, wk])
				for part in WEAPON_PARTS[wk]:
					check(m.find_child(String(part), true, false) != null, "%s: есть %s" % [who, String(part)])
				var elf: bool = ClassData.race(rid)["ears"]
				check(m.has_ears() == elf, "%s: уши %s" % [who, "эльфа" if elf else "человека"])
				var n := m.mesh_count()
				check(n >= 20 and n <= MAX_MESHES, "%s: мешей %d (до %d)" % [who, n, MAX_MESHES])
				var head := m.find_child("Head", true, false) as Node3D
				check(head != null, "%s: есть голова" % who)
				var hy := head.global_position.y
				check(hy > 1.45 and hy < 1.75, "%s: голова на высоте %.2f м (рост ~1.8 м)" % [who, hy])
				check(m.find_child("Face", true, false) != null, "%s: есть лицо" % who)
				m.set_move_speed(6.5)
				m.play_attack()
			wait = 20
			step = 1
		1:
			for m in models:
				m.play_hit()
				m.play_cast()
				m.set_move_speed(0.0)
			wait = 20
			step = 2
		2:
			for m in models:
				m.play_shoot()
				m.play_bash()
				m.play_buff()
			wait = 15
			step = 3
		3:
			for m in models:
				m.play_spin()
			wait = 40
			step = 4
		4:
			for m in models:
				check(is_zero_approx(m.rotation.y), "после кругового удара модель развёрнута обратно")
				m.play_wave()
			wait = 10
			step = 5
		5:
			var player: Player = main.player
			check(player._model is CharacterModel, "у игрока модель CharacterModel")
			check(player._guard_fx != null and player._guard_fx.get_parent() == player._model,
				"сияние «Щита света» на модели игрока")
			var mer: Merchant = main.economy.merchant
			check(mer._model is CharacterModel and mer._model.weapon_kind == "",
				"торговец — CharacterModel без оружия")
			check(mer._model.mesh_count() <= MAX_MESHES, "мешей у торговца: %d" % mer._model.mesh_count())
			# Урон по игроку запускает анимацию получения урона без ошибок
			player.take_damage(1, null)
			player.hp = player.max_hp
			for m in models:
				m.queue_free()
			models.clear()
			create = CharacterCreate.new()
			get_tree().root.add_child(create)
			wait = 5
			step = 6
		6:
			check(create._preview_model != null and is_instance_valid(create._preview_model),
				"экран создания: 3D-превью построено")
			create._select_race("dark_elf")
			create._select_class("warlock")
			wait = 5
			step = 7
		7:
			var pm: CharacterModel = create._preview_model
			check(pm != null and pm.weapon_kind == "staff" and pm.has_ears(), "превью обновилось: чернокнижник")
			create.queue_free()
			ok_done()
