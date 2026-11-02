extends BotSection
## Раздел «Питомцы»: для каждого вида (быстрый проход — QUICK_SPECIES, полный — все виды админ-панели) — питомец
## 12 ур. с изученными умениями призывается; команды кнопками HUD: «За мной», «Защита», «Авто» (сам нападает на
## зверя рядом), «Атака» (бьёт цель героя); умения питомца срабатывают в бою (ИИ, ячейки «Авто»); опыт поднимает
## уровень; эволюция (15 и 30 ур.) меняет стадию и модель стадии (если файл модели есть).

const QUICK_SPECIES := ["wolf", "panther"]
const PET_LEVEL := 12
const MOB := "pheasant"
const BIG_HP := 2000000

var _sp := ""
var _mob: Mob = null
var _uses0 := 0
var _has_active := false
var _lvl0 := 0
var _model0 := ""
var _refill := 0.0


func id() -> String:
	return "pets"


func _build() -> void:
	do("Питомцы: герой и поле", _setup)
	var list: Array = QUICK_SPECIES if quick else AdminPanel.pet_species()
	for s in list:
		var sp := String(s)
		var nm := String(MobData.get_type(sp).get("name", sp))
		do("Питомец «%s»: призыв" % nm, _add.bind(sp))
		until("питомец «%s» призван" % nm, _summoned, 5.0)
		do("«%s»: «За мной», «Защита», «Авто»" % nm, _modes)
		wait(0.3)
		do("«%s»: «Авто» — зверь рядом" % nm, _auto_start)
		until("«%s» сам напал на зверя рядом" % nm, _pet_on_mob, 8.0)
		do("«%s»: «Атака» по цели героя" % nm, _attack_start)
		until("«%s» бьёт цель героя" % nm, _pet_hits_target, 8.0)
		do("«%s»: умения в бою" % nm, _skills_start)
		until("«%s» применил умение" % nm, _skill_used, 14.0)
		do("«%s»: итог умений" % nm, _skills_done)
		do("«%s»: опыт и уровень" % nm, _xp)
		do("«%s»: эволюция до 15 ур." % nm, _evolve.bind(15))
		wait(1.2)
		do("«%s»: модель 2-й стадии" % nm, _check_stage.bind(1))
		if not quick:
			do("«%s»: эволюция до 30 ур." % nm, _evolve.bind(30))
			wait(1.2)
			do("«%s»: модель 3-й стадии" % nm, _check_stage.bind(2))
	do("Питомцы: отпустить", _end)


func _end() -> void:
	bot.set_tick(Callable())
	bot.clear_spawned()
	no_pets()


func _setup() -> void:
	hero(Game.class_id, 30)
	fresh_bag(500)
	no_pets()
	to_arena()


## Новый питомец вида sp: умения изучены до призыва (ячейки «Авто» заполняются сами), затем призыв.
func _add(sp: String) -> void:
	bot.set_tick(Callable())
	bot.clear_spawned()
	_mob = null
	_sp = sp
	no_pets()
	var i := Game.add_pet(sp, PetData.stage_name(sp, PET_LEVEL), PET_LEVEL)
	if not check(i >= 0, "питомец «%s» в коллекции" % sp):
		return
	var rec: Dictionary = Game.pets[i]
	rec["jp"] = 999
	var learned := 0
	for _pass in 3:
		for id_v in PetSkills.list_for(sp):
			if PetSkills.learn(rec, String(id_v)):
				learned += 1
	_has_active = false
	for v in PetSkills.slots_of(rec, "auto"):
		if String(v) != "":
			_has_active = true
	note("Питомец «%s»: изучено уровней умений %d, активные в ячейках: %s" % [sp, learned, "да" if _has_active else "нет"])
	pets().summon(i)


func _summoned() -> bool:
	var pt := pet()
	return pt != null and pt.species == _sp


func _modes() -> void:
	var pt := pet()
	if not check(pt != null, "питомец «%s» призван" % _sp):
		return
	for e in [["pet_follow", "follow"], ["pet_defend", "defend"], ["pet_auto", "auto"]]:
		var a: Array = e
		press(String(a[0]))
		check(pt.mode == String(a[1]) and PetSkills.command(pt.record) == String(a[1]), "кнопка «%s» — режим %s (%s)"
			% [String(a[0]), String(a[1]), pt.mode])
	shot("Питомец %s" % _sp)


## «Авто»: зверь в 6 м от героя — питомец нападает сам.
func _auto_start() -> void:
	var pt := pet()
	if pt == null:
		return
	press("pet_auto")
	_mob = spawn_ahead(MOB, PET_LEVEL, 6.0, 2.0)
	if _mob != null:
		_mob.max_hp = BIG_HP
		_mob.hp = BIG_HP
	bot.set_tick(_keep_alive)


func _keep_alive(dt: float) -> void:
	_refill -= dt
	if _refill > 0.0:
		return
	_refill = 0.5
	var pt := pet()
	if pt != null:
		pt.hp = pt.max_hp
		pt.mp = pt.max_mp
	var p := player()
	if p != null:
		# Хозяин «ранен» — лекарю есть кого лечить (бессмертие: урон не проходит)
		p.hp = int(float(p.max_hp) * 0.5)


func _pet_on_mob() -> bool:
	var pt := pet()
	# Зверь рядом — бот поставил или зверь острова (питомец выбирает ближайшего к хозяину)
	return pt != null and (is_instance_valid(pt.target) or (alive(_mob) and _mob.hp < BIG_HP))


## «Атака»: герой выбирает другого зверя целью, кнопка — питомец бьёт его.
func _attack_start() -> void:
	var p := player()
	var pt := pet()
	if p == null or pt == null:
		return
	press("pet_follow")
	var other := spawn_ahead(MOB, PET_LEVEL, 5.0, -2.5)
	if other == null:
		return
	other.max_hp = BIG_HP
	other.hp = BIG_HP
	_mob = other
	p.select_target(other)
	press("pet_attack")
	check(pt.mode == "attack" and pt.target == other, "«Атака»: питомец взял цель героя (режим %s)" % pt.mode)


func _pet_hits_target() -> bool:
	return alive(_mob) and _mob.hp < BIG_HP


## Умения: питомец бьёт зверя, MP полное — ИИ применяет умения из ячеек «Авто».
func _skills_start() -> void:
	var pt := pet()
	if pt == null:
		return
	_uses0 = pt.learned_uses
	pt.skill_cds.clear()
	pt.mp = pt.max_mp
	if alive(_mob):
		pt.command_attack(_mob)


func _skill_used() -> bool:
	var pt := pet()
	if not _has_active or pt == null:
		return true
	if not alive(_mob):
		_mob = spawn_ahead(MOB, PET_LEVEL, 4.0, 1.5)
		if _mob != null:
			_mob.max_hp = BIG_HP
			_mob.hp = BIG_HP
			pt.command_attack(_mob)
	return pt.learned_uses > _uses0


func _skills_done() -> void:
	var pt := pet()
	if pt != null:
		note("Питомец «%s»: умений применено %d" % [_sp, pt.learned_uses - _uses0])
	bot.set_tick(Callable())
	bot.clear_spawned()
	_mob = null
	press("pet_follow")


## Опыт до следующего уровня — уровень растёт, JP прибавились.
func _xp() -> void:
	var pt := pet()
	if pt == null:
		return
	_lvl0 = pt.level
	var jp0 := int(pt.record.get("jp", 0))
	AdminPanel.pet_xp_next(bot.main)
	pt = pet()
	check(pt != null and pt.level == _lvl0 + 1, "опыт: питомец %d → %d ур." % [_lvl0, pt.level if pt != null else -1])
	if pt != null:
		check(int(pt.record.get("jp", 0)) > jp0 - 1, "JP питомца за уровень: %d → %d" % [jp0, int(pt.record.get("jp", 0))])


func _evolve(lvl: int) -> void:
	var pt := pet()
	if pt == null:
		return
	_model0 = pt.model_id
	AdminPanel.set_pet_level(bot.main, lvl)


func _check_stage(stage: int) -> void:
	var pt := pet()
	if not check(pt != null, "питомец на месте после эволюции"):
		return
	check(pt.stage == stage and pt.pet_name == PetData.stage_name(_sp, pt.level), "стадия %d: «%s» (%d ур.)"
		% [stage + 1, pt.pet_name, pt.level])
	var want := CreatureAsset.model_for(_sp, stage)
	check(pt.model_id == want, "модель стадии: %s (нужна %s)" % [pt.model_id, want])
	if want != CreatureAsset.model_for(_sp, stage - 1):
		check(pt.model_id != _model0, "модель сменилась при эволюции: %s → %s" % [_model0, pt.model_id])
	shot("Питомец %s стадия %d" % [_sp, stage + 1])
