class_name JobFxAdept
extends RefCounted
## Особые механики умений Адепта (подключение — HeroSkillFx.JOB_FX_FILES) — кровная связь с питомцем:
## часть HP питомца идёт в урон или лечение героя. Питомец от этого не погибает: PetBond.drain не опускает его ниже
## PetBond.PET_FLOOR макс. HP, а слабого (меньше PET_FLOOR + 5 %) умения не трогают. Насмерть — только «Кровь
## бездны» (PetBond: sacrifice_pet). Остальное — данными (подпитки, «Боевой задор», «Звериный рык», «Когти хищника»).

const BLOOD := Color(0.85, 0.12, 0.2)
const ABYSS := Color(0.45, 0.2, 0.65)


static func pre_cast(fx: HeroSkillFx, sid: String, n: int, sk: Dictionary) -> String:
	for e in PetBond.specials(sk):
		var why := ""
		match String(e.get("handler", "")):
			"blood_rain":
				why = can_blood_rain(fx, sid, n, null, e)
			"borrowed_life":
				why = can_borrowed_life(fx, sid, n, null, e)
			"abyss_howl":
				why = can_abyss_howl(fx, sid, n, null, e)
		if why != "":
			return why
	return ""


static func special(fx: HeroSkillFx, handler: String, sid: String, n: int, t: Mob, e: Dictionary) -> bool:
	match handler:
		"blood_rain":
			sp_blood_rain(fx, sid, n, t, e)
		"borrowed_life":
			sp_borrowed_life(fx, sid, n, t, e)
		"abyss_howl":
			sp_abyss_howl(fx, sid, n, t, e)
		_:
			return false
	return true


static func on_basic_hit(_fx: HeroSkillFx, _t: Mob, _dealt: int) -> void:
	pass


static func on_hurt(_fx: HeroSkillFx, _attacker: Node3D, _amount: int) -> void:
	pass


static func tick(_fx: HeroSkillFx, _delta: float) -> void:
	pass


static func reset(_fx: HeroSkillFx) -> void:
	pass


## «Кровавый ливень»: питомец отдаёт cost доли макс. HP — hits ударов по цели, каждый = маг. атака × mult +
## отданное HP × share (магия: защита зверя, уровни — Combat).
static func can_blood_rain(fx: HeroSkillFx, _sid: String, _n: int, _t: Mob, _e: Dictionary) -> String:
	return PetBond.need_pet(fx.p, true)


static func sp_blood_rain(fx: HeroSkillFx, _sid: String, n: int, t: Mob, e: Dictionary) -> void:
	var p := fx.p
	var pet := PetBond.active_pet(p)
	if pet == null or t == null or not is_instance_valid(t) or t.is_dead:
		return
	var spent := PetBond.drain(pet, roundi(float(pet.max_hp) * HeroSkills.value_at(e.get("cost", 0.08), n)))
	var hits := maxi(1, int(HeroSkills.value_at(e.get("hits", 4), n)))
	var raw := float(p.cur_matk()) * HeroSkills.value_at(e.get("mult", 0.8), n) + float(spent) * HeroSkills.value_at(e.get("share", 0.5), n)
	if p.is_inside_tree():
		Vfx.magic_burst(p.get_parent(), pet.global_position + Vector3(0, 0.8, 0), BLOOD, 0.9, 0.35)
	# Удары подряд (без таймеров: всё в один кадр, вспышки — на каждом)
	for i in hits:
		_rain_hit(p, t, raw)


## Один кровавый удар по m (зверь мог уже погибнуть от прошлого).
static func _rain_hit(p: Player, m: Mob, raw: float) -> void:
	if m == null or not is_instance_valid(m) or m.is_dead:
		return
	if not p.skill_hits(m):
		p._miss_text(m)
		return
	p._last_magic = true
	p._last_crit = randf() < p.crit_rate()
	var dmg := raw + float(randi_range(-2, 3))
	if p._last_crit:
		dmg *= p.crit_mult
	if p.is_inside_tree():
		Vfx.hit_spark(p.get_parent(), m.aim_point(), BLOOD, 1.1)
		Vfx.magic_burst(p.get_parent(), m.aim_point() + Vector3(0, 0.6, 0), BLOOD, 0.5, 0.25)
	p._deal(m, maxi(1, roundi(dmg)))


## «Жизнь взаймы»: забрать take доли макс. HP питомца (не ниже PetBond.PET_FLOOR) — герой лечится на забранное × gain.
static func can_borrowed_life(fx: HeroSkillFx, _sid: String, _n: int, _t: Mob, _e: Dictionary) -> String:
	var why := PetBond.need_pet(fx.p, true)
	if why == "" and fx.p.hp >= fx.p.max_hp:
		return "здоровье и так полное"
	return why


static func sp_borrowed_life(fx: HeroSkillFx, _sid: String, n: int, _t: Mob, e: Dictionary) -> void:
	var p := fx.p
	var pet := PetBond.active_pet(p)
	if pet == null:
		return
	var took := PetBond.drain(pet, roundi(float(pet.max_hp) * HeroSkills.value_at(e.get("take", 0.15), n)))
	if took <= 0:
		return
	if p.is_inside_tree():
		Vfx.magic_burst(p.get_parent(), pet.global_position + Vector3(0, 0.8, 0), BLOOD, 0.9, 0.35)
		Vfx.magic_burst(p.get_parent(), p.global_position + Vector3(0, 1.0, 0), BLOOD, 1.1, 0.4)
	p.heal(maxi(1, roundi(float(took) * HeroSkills.value_at(e.get("gain", 1.2), n))))


## «Вопль бездны»: питомец отдаёт cost доли макс. HP — урон всем зверям в radius м вокруг него: макс. HP питомца × pct
## + маг. атака героя × mult (магия: защита зверя, уровни). Звери злятся на питомца.
static func can_abyss_howl(fx: HeroSkillFx, _sid: String, _n: int, _t: Mob, e: Dictionary) -> String:
	var why := PetBond.need_pet(fx.p, true)
	if why != "":
		return why
	var pet := PetBond.active_pet(fx.p)
	if fx.p._mobs_around(pet.global_position, float(e.get("radius", 6.0))).is_empty():
		return "рядом с питомцем нет зверей"
	return ""


static func sp_abyss_howl(fx: HeroSkillFx, _sid: String, n: int, _t: Mob, e: Dictionary) -> void:
	var p := fx.p
	var pet := PetBond.active_pet(p)
	if pet == null:
		return
	var r := HeroSkills.value_at(e.get("radius", 6.0), n)
	PetBond.drain(pet, roundi(float(pet.max_hp) * HeroSkills.value_at(e.get("cost", 0.1), n)))
	var raw := float(pet.max_hp) * HeroSkills.value_at(e.get("pct", 0.3), n) + float(p.cur_matk()) * HeroSkills.value_at(e.get("mult", 1.0), n)
	if pet.is_inside_tree():
		CreatureModels.spawn_ring(pet.get_parent(), pet.global_position, r, ABYSS, 0.5)
		Vfx.magic_burst(pet.get_parent(), pet.global_position + Vector3(0, 0.6, 0), ABYSS, r * 0.7, 0.5)
	for m in p._mobs_around(pet.global_position, r):
		if not p.skill_hits(m):
			p._miss_text(m)
			continue
		p._last_magic = true
		p._last_crit = false
		var dealt := p.mitigate(m, maxi(1, roundi(raw + float(randi_range(-2, 3)))))
		if pet.is_inside_tree():
			Vfx.hit_spark(pet.get_parent(), m.aim_point(), ABYSS, 1.2)
		m.take_damage(dealt, pet)
