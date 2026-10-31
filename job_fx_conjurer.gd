class_name JobFxConjurer
extends RefCounted
## Особые механики умений Колдуна (подключение — HeroSkillFx.JOB_FX_FILES): «Гнев духов». Созвучия,
## «Колыбельная», «Дикий рёв», «Гнев стаи» — данными (JobSkills), «Очищение зверя» — PetBond (cleanse_pet) + данные,
## «Слияние душ» и «Звериный облик» — переключаемые с полем "bond" (PetBond.set_mode: питомец «внутри» героя или
## его облик).

const SPIRIT := Color(0.95, 0.75, 0.35)


static func pre_cast(fx: HeroSkillFx, sid: String, n: int, sk: Dictionary) -> String:
	for e in PetBond.specials(sk):
		if String(e.get("handler", "")) == "spirit_wrath":
			var why := can_spirit_wrath(fx, sid, n, null, e)
			if why != "":
				return why
	return ""


static func special(fx: HeroSkillFx, handler: String, sid: String, n: int, t: Mob, e: Dictionary) -> bool:
	if handler != "spirit_wrath":
		return false
	sp_spirit_wrath(fx, sid, n, t, e)
	return true


static func on_basic_hit(_fx: HeroSkillFx, _t: Mob, _dealt: int) -> void:
	pass


static func on_hurt(_fx: HeroSkillFx, _attacker: Node3D, _amount: int) -> void:
	pass


static func tick(_fx: HeroSkillFx, _delta: float) -> void:
	pass


static func reset(_fx: HeroSkillFx) -> void:
	pass


## «Гнев духов»: time секунд зверей в radius м вокруг питомца каждую секунду жжёт сила духов (маг. атака героя × mult,
## магия: защита зверя, уровни); питомец стоит на месте и бьёт подошедших (Pet.hero_buffs: spirit_dps, hold).
static func can_spirit_wrath(fx: HeroSkillFx, _sid: String, _n: int, _t: Mob, _e: Dictionary) -> String:
	return PetBond.need_pet(fx.p, false)


static func sp_spirit_wrath(fx: HeroSkillFx, sid: String, n: int, _t: Mob, e: Dictionary) -> void:
	var p := fx.p
	var pet := PetBond.active_pet(p)
	if pet == null:
		return
	var r := HeroSkills.value_at(e.get("radius", 5.0), n)
	var dps := float(p.cur_matk()) * HeroSkills.value_at(e.get("mult", 0.3), n)
	pet.apply_hero_buff(sid, HeroSkills.value_at(e.get("time", 15.0), n), {"spirit_dps": dps, "spirit_r": r, "hold": 1.0})
	if pet.is_inside_tree():
		CreatureModels.spawn_ring(pet.get_parent(), pet.global_position, r, SPIRIT, 0.6)
		Vfx.magic_burst(pet.get_parent(), pet.global_position + Vector3(0, 0.8, 0), SPIRIT, 1.4, 0.5)
