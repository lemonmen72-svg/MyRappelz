class_name JobFxBeastmaster
extends RefCounted
## Особые механики умений Зверолова; подключение — HeroSkillFx.JOB_FX_FILES (шесть функций, описание — шапка
## HeroSkillFx). Свой обработчик — «Небесный обмен» (sky_offering); здесь же подключены общие обработчики питомца
## из PetBond: revive_pet («Второе дыхание»), sacrifice_pet («Кровь бездны» Адепта), cleanse_pet («Очищение зверя»
## Колдуна) — работают у любой профессии. Остальное — данными (JobSkills: ауры поддержки, «Оберег», «Светлые когти»,
## пассивки питомца, «Лечение зверя», «Целебная роса») и механикой PetBond («Нить жизни», «Общая боль»).

const LIGHT := Color(1.0, 0.9, 0.55)


## Перед умением: можно ли (есть питомец, есть погибший для воскрешения…). "" — можно.
static func pre_cast(fx: HeroSkillFx, sid: String, n: int, sk: Dictionary) -> String:
	for e in PetBond.specials(sk):
		var why := ""
		match String(e.get("handler", "")):
			"sky_offering":
				why = can_sky_offering(fx, sid, n, null, e)
			"revive_pet":
				why = PetBond.can_revive_pet(fx, sid, n, null, e)
			"sacrifice_pet":
				why = PetBond.can_sacrifice_pet(fx, sid, n, null, e)
			"cleanse_pet":
				why = PetBond.can_cleanse_pet(fx, sid, n, null, e)
		if why != "":
			return why
	return ""


static func special(fx: HeroSkillFx, handler: String, sid: String, n: int, t: Mob, e: Dictionary) -> bool:
	match handler:
		"sky_offering":
			sp_sky_offering(fx, sid, n, t, e)
		"revive_pet":
			PetBond.sp_revive_pet(fx, sid, n, t, e)
		"sacrifice_pet":
			PetBond.sp_sacrifice_pet(fx, sid, n, t, e)
		"cleanse_pet":
			PetBond.sp_cleanse_pet(fx, sid, n, t, e)
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


## «Небесный обмен»: питомец отдаёт силы — герою value доли макс. HP и MP, питомец погибает (нужно воскрешение).
static func can_sky_offering(fx: HeroSkillFx, _sid: String, _n: int, _t: Mob, _e: Dictionary) -> String:
	return PetBond.need_pet(fx.p, false)


static func sp_sky_offering(fx: HeroSkillFx, _sid: String, n: int, _t: Mob, e: Dictionary) -> void:
	var p := fx.p
	var pet := PetBond.active_pet(p)
	if pet == null:
		return
	var v := HeroSkills.value_at(e.get("value", 0.41), n)
	var nm := pet.pet_name
	if p.is_inside_tree():
		Vfx.magic_burst(p.get_parent(), pet.global_position + Vector3(0, 0.8, 0), LIGHT, 1.4, 0.5)
		Vfx.level_up(p.get_parent(), p.global_position, 0.9)
	PetBond.sacrifice(pet)
	p.heal(maxi(1, roundi(float(p.max_hp) * v)))
	var mp := maxi(1, roundi(float(p.max_mp) * v))
	p.mp = mini(p.max_mp, p.mp + mp)
	p.stats_changed.emit()
	p.message.emit("«%s» отдал силы: HP и MP +%d%%" % [nm, roundi(v * 100.0)])
