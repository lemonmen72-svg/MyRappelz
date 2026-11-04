extends "res://tests/test_base.gd"
## Система анимаций 1.0 (AnimResolver, docs/animation/): цепочки выбора клипа, матрица покрытия всех 24 героев (CSV в
## user://anim_coverage.csv, печать «ПОКРЫТИЕ …»), вертикальный срез на настоящих моделях — Мечник и Мечница с мечом
## (атака → умение → каст → урон → покой, оружие в руке остаётся, решения записаны), откат флагом, модель без клипов
## (запасной уровень, не зависает), быстрая смена оружия (одна модель оружия в руке), урон обычной атаки не зависит от
## системы анимаций (одинаков при enabled = true / false).

const PAIR := ["res://assets/characters/hero_swordsman_m.glb", "res://assets/characters/hero_swordsman_f.glb"]
const CSV := "user://anim_coverage.csv"

var models: Array[CharacterModel] = []
var mob: Mob = null
var dmg_on := 0
var dmg_off := 0
var rows: Array = []
## Проверено срезом на настоящей модели: "модель/хват/действие".
var verified: Dictionary = {}


func race_class() -> Array:
	return ["light_elf", "swordsman"]


func run_step() -> void:
	match step:
		0:
			AnimResolver.reset_stats()
			_unit_chains()
			_coverage()
			for i in PAIR.size():
				var spec := CharacterModel.spec_for("light_elf", "swordsman", "sword", "m" if i == 0 else "f")
				spec["asset"] = PAIR[i]
				var m := CharacterModel.new()
				m.setup(spec)
				main.add_child(m)
				m.position = Vector3(-4.0 + 3.0 * i, 0.0, 30.0)
				models.append(m)
			step = 1
			wait = 20
		1:
			for m in models:
				_slice(m)
			step = 2
			wait = 30
		2:
			for m in models:
				var c := m._anim.current_animation if m._anim != null else ""
				check(m._anim != null and m._anim.is_playing(), "%s: после среза анимация идёт (%s)" % [_id(m), c])
				check(_held(m) == 1, "%s: оружие в руке одно (%d)" % [_id(m), _held(m)])
			# Боевой покой: после действий в покое — стойка с клинком; через COMBAT_HOLD — обычный покой
			var m0 := models[0]
			check(m0.in_combat_stance(), "%s: после боя — боевой покой" % _id(m0))
			m0._combat_t = m0._t - CharacterModel.COMBAT_HOLD - 1.0
			check(not m0.in_combat_stance(), "%s: через %.0f с — обычный покой" % [_id(m0), CharacterModel.COMBAT_HOLD])
			m0._combat_t = m0._t
			_rollback(models[0])
			_no_clips(models[1])
			step = 3
		3:
			_swaps()
			_damage_setup()
			step = 4
			wait = 5
		4:
			dmg_on = _hits(true)
			dmg_off = _hits(false)
			check(dmg_on > 0 and dmg_on == dmg_off,
				"урон 10 обычных атак одинаков с системой анимаций и без неё (%d = %d)" % [dmg_on, dmg_off])
			AnimResolver.enabled = true
			_creatures_live()
			print("АНИМАЦИИ: " + AnimResolver.summary_line())
			models[1]._combat_t = models[1]._t
			step = 5
			wait = 150
		5:
			var m1 := models[1]
			var cur := m1._anim.current_animation
			check(m1.in_combat_stance() and cur.to_lower().contains("sword_idle"),
				"%s: в бою без дела — стойка с клинком (%s)" % [_id(m1), cur])
			if cur.to_lower().contains("sword_idle"):
				verified["%s/%s/%s" % [_id(m1), m1.mq_grip(), "combat_idle"]] = true
			_write_csv()
			ok_done()


func _id(m: CharacterModel) -> String:
	return String(m.spec.get("asset", "")).get_file().get_basename()


## Цепочки: лук и арбалет — без взмаха мечом; своё движение умения первым; каст и усиление — общие клипы.
func _unit_chains() -> void:
	var names := func(chain: Array) -> Array:
		var out: Array = []
		for lv in chain:
			out.append_array(lv[1])
		return out
	check(not names.call(AnimResolver.skill_chain("attack", "", "melee", "bow", false)).has("mq_charged_slash"),
		"удар умения с луком — не взмах мечом")
	check(not names.call(AnimResolver.skill_chain("bash", "", "melee", "crossbow", false)).has("mq_charged_slash"),
		"удар умения с арбалетом — не взмах мечом (прежний выстрел)")
	check(names.call(AnimResolver.skill_chain("attack", "", "ranged", "bow", false)).has("mq_bow_draw"),
		"выстрел умением из лука — натяжение")
	var ch := AnimResolver.skill_chain("bash", "challenge", "melee", "sword", true)
	check(not ch.is_empty() and ch[0][0] == "skill" and ch[0][1] == ["mq_taunt"], "своё движение умения — первый уровень")
	check(AnimResolver.skill_chain("spin", "", "melee", "staff", false)[0][1] == CharacterModel.MQ_STRIKES["staff"],
		"круговой удар посохом — удары посохом, не топор")
	var none := AnimResolver.pick([["grip", ["нет_такого"]]], func(_k: String) -> String: return "")
	check(none["level"] == "legacy" and none["names"].is_empty(), "нет клипов — уровень legacy")


## Матрица покрытия всех героев по их .json: CSV и печать; у подходящего профессии оружия — нет missing.
func _coverage() -> void:
	var dir := DirAccess.open("res://assets/characters")
	var files: Array = []
	for f in dir.get_files():
		if f.begins_with("hero_") and f.ends_with(".json"):
			files.append(f)
	files.sort()
	check(files.size() >= 24, "героев с .json: %d" % files.size())
	for f in files:
		var id := String(f).get_basename()
		var cls := ClassData.WANDERER if id.ends_with("_starter") else id.trim_prefix("hero_").rsplit("_", true, 1)[0]
		rows.append_array(AnimResolver.coverage(id, cls, AnimResolver.rig_clips("res://assets/characters/" + f)))
	var miss: Array[String] = []
	for r in rows:
		if r["status"] == "missing":
			miss.append("%s/%s/%s" % [r["model"], r["grip"], r["action"]])
	for k in miss.slice(0, 20):
		print("ПОКРЫТИЕ missing: " + k)
	check(miss.is_empty(), "у оружия профессий нет действий без клипа (missing: %d)" % miss.size())
	# Фазы E, F: жители (npc_<id>.json) и существа (creatures.json) — клипы, которые им включает игра
	var npc_n := 0
	for f in dir.get_files():
		if f.begins_with("npc_") and f.ends_with(".json"):
			var nc := AnimResolver.rig_clips("res://assets/characters/" + f)
			rows.append_array(AnimResolver.npc_coverage(String(f).get_basename(), nc))
			npc_n += 1
	check(npc_n >= 13, "жителей с .json: %d" % npc_n)
	var cj: Variant = JSON.parse_string(FileAccess.get_file_as_string(CreatureAsset.INFO_PATH))
	var cre_n := 0
	if cj is Dictionary:
		for mid in cj:
			rows.append_array(AnimResolver.creature_coverage(String(mid), (cj[mid] as Dictionary).get("clips", {})))
			cre_n += 1
	check(cre_n >= 20, "моделей существ в creatures.json: %d" % cre_n)
	var miss2: Array[String] = []
	for r in rows:
		if r["status"] == "missing" and (r["class"] == "npc" or r["class"] == "creature"):
			miss2.append("%s/%s" % [r["model"], r["action"]])
	print("ПОКРЫТИЕ жители и существа missing: %s" % str(miss2))
	check(miss2.is_empty(), "у жителей и существ нет нужных игре действий без клипа (%d)" % miss2.size())


## CSV матрицы: строки, проверенные срезом, — verified.
func _write_csv() -> void:
	var by: Dictionary = {}
	var out := FileAccess.open(CSV, FileAccess.WRITE)
	out.store_line("model,variant,class,grip,action,level,clip,status")
	for r in rows:
		if verified.get("%s/%s/%s" % [r["model"], r["grip"], r["action"]], false) and r["status"] != "not_applicable":
			r["status"] = "verified"
		by[r["status"]] = int(by.get(r["status"], 0)) + 1
		out.store_line(",".join([r["model"], r["variant"], r["class"], r["grip"], r["action"], r["level"], r["clip"],
			r["status"]]))
	out.close()
	print("ПОКРЫТИЕ: строк %d · %s · файл %s" % [rows.size(), by, ProjectSettings.globalize_path(CSV)])


## Срез: атака, удар умения, каст (петля и выпуск), урон — клипы из модели, решения записаны, оружие в руке.
func _slice(m: CharacterModel) -> void:
	var n0 := AnimResolver.trace.size()
	m.play_attack(0.8)
	var atk := m._anim.current_animation
	_ver(m, "attack", atk.begins_with("Mq_"), "обычная атака мечом — клип манекена (%s)" % atk)
	_ver(m, "strike", m.play_skill("attack", "", "melee"), "удар умения — свой клип (%s)" % m._anim.current_animation)
	_ver(m, "bash", m.play_skill("bash", "", "melee"), "удар щитом/умения — свой клип (%s)" % m._anim.current_animation)
	_ver(m, "spin", m.play_skill("spin", "", "melee"), "круговой удар — свой клип (%s)" % m._anim.current_animation)
	_ver(m, "dash", m.play_skill("dash", "", "melee"), "рывок — свой клип (%s)" % m._anim.current_animation)
	_ver(m, "buff", m.play_skill("buff", "", "self"), "усиление — свой клип (%s)" % m._anim.current_animation)
	_ver(m, "cast_self", m.play_skill("cast", "", "self"), "заклинание на себя (%s)" % m._anim.current_animation)
	check(m.play_cast_loop("magic"), "%s: петля каста (%s)" % [_id(m), m.cast_loop_clip()])
	m.stop_cast_loop()
	_ver(m, "cast", m.play_skill("cast", "", "magic", true), "выпуск заклинания после каста")
	m.play_hit()
	check(AnimResolver.trace.size() >= n0 + 3, "%s: решения резолвера записаны (%d)" % [_id(m), AnimResolver.trace.size() - n0])
	check(_held(m) == 1, "%s: меч в руке после действий" % _id(m))


func _ver(m: CharacterModel, action: String, ok: bool, what: String) -> void:
	check(ok, "%s: %s" % [_id(m), what])
	if ok:
		verified["%s/%s/%s" % [_id(m), m.mq_grip(), action]] = true


## Число моделей оружия в руках (метка handheld или процедурный меш оружия).
func _held(m: CharacterModel) -> int:
	var n := 0
	for c in m.find_children("*", "MeshInstance3D", true, false):
		if c.has_meta("handheld") or String(c.name).begins_with("Weapon"):
			n += 1
	return n


## Откат: enabled = false — прежний выбор, клип тот же набор, решений не пишет.
func _rollback(m: CharacterModel) -> void:
	AnimResolver.enabled = false
	var n0 := AnimResolver.trace.size()
	check(m.play_skill("attack", "", "melee"), "откат: прежний выбор удара умения работает")
	check(AnimResolver.trace.size() == n0, "откат: резолвер не вызывался")
	AnimResolver.enabled = true


## Модель без клипов: умение — false (прежний жест), действие — покой; не падает.
func _no_clips(m: CharacterModel) -> void:
	var keep := m._clips
	m._clips = {}
	check(not m.play_skill("bash", "", "melee"), "без клипов: умение отдаёт прежнему жесту")
	m.play_hit()
	check(AnimResolver.missing.size() > 0, "без клипов: пропуск в диагностике (%s)" % str(AnimResolver.missing))
	m._clips = keep


## Быстрая смена оружия героя: 12 раз подряд — в руке одна модель оружия, анимация идёт.
func _swaps() -> void:
	var p: Player = main.player
	for w in ["weapon_sword_1h_r1", "weapon_sword_2h_r1"]:
		if not game.inventory.has(w):
			game.inventory.add(w)
	for i in 12:
		p.equip("weapon_sword_2h_r1" if i % 2 == 0 else "weapon_sword_1h_r1")
		p.try_attack()
	var m := p._model
	check(m != null and is_instance_valid(m), "после 12 смен оружия модель героя есть")
	if m != null and m._asset != null:
		check(_held(m) <= 2, "после смен оружия в руках не больше двух моделей оружия (%d)" % _held(m))


func _damage_setup() -> void:
	var p: Player = main.player
	p.equip("weapon_sword_1h_r1")
	mob = main.spawn_mob("turtle", game.level, p.global_position + Vector3(0, 0, 1.6))
	mob.max_hp = 1000000
	mob.hp = mob.max_hp


## Фазы E, F вживую: зверь бьёт (учёт «mob:»), питомец (учёт «pet:»), житель машет (учёт «npc:»); отсчёт действия
## зверя идёт и во сне (за кадром) — вернувшись, он не доигрывает старый удар.
func _creatures_live() -> void:
	var asset := mob._asset
	check(asset != null and asset.anim_actor == "mob", "зверь из файла — учёт как «mob»")
	if asset != null:
		var n0 := int(AnimResolver.summary()["by_actor"].get("mob", 0))
		asset.play_attack(1.0)
		check(int(AnimResolver.summary()["by_actor"].get("mob", 0)) > n0, "удар зверя записан в учёт")
		asset.set_sleeping(true)
		asset.play_attack(1.0)
		for i in 120:
			asset.update(1.0 / 60.0, 0.0)
		check(asset._act_left <= 0.0, "во сне отсчёт удара зверя дошёл до конца (%.2f с)" % asset._act_left)
		asset.set_sleeping(false)
	game.active_pet = game.add_pet("wolf", PetData.stage_name("wolf", 0), 5)
	main.pets.summon(game.pets.size() - 1)
	var pt: Pet = main.pets.active_pet
	check(pt != null and pt._asset != null and pt._asset.anim_actor == "pet", "питомец из файла — учёт как «pet»")
	if pt != null and pt._asset != null:
		pt._asset.play_cast()
		check(int(AnimResolver.summary()["by_actor"].get("pet", 0)) > 0, "умение питомца записано в учёт")
	var npc: Npc = null
	for n in get_tree().get_nodes_in_group("npc"):
		if n is Npc:
			npc = n
			break
	check(npc != null, "житель найден")
	if npc != null:
		check(npc._model.anim_actor == "npc", "житель — учёт как «npc»")
		npc._wave_cd = 0.0
		npc.greet()
		check(int(AnimResolver.summary()["by_actor"].get("npc", 0)) > 0,
			"приветствие жителя записано в учёт (%s)" % AnimResolver.summary_line())


## Урон 10 обычных атак при заданном флаге (ГСЧ боя — с одного зерна).
func _hits(flag: bool) -> int:
	AnimResolver.enabled = flag
	var p: Player = main.player
	Combat.reseed(4242)
	var hp0 := mob.hp
	p._set_target(mob)
	for i in 10:
		p.attack_cd = 0.0
		p.try_attack()
	return hp0 - mob.hp
