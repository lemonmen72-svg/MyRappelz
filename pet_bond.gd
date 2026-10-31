class_name PetBond
extends RefCounted
## Связь героя и призванного питомца — общая «питомцевая» механика умений героя (этап 2: профессии Зверолов,
## Адепт, Колдун; ауры «both» / «pet» других профессий — тоже здесь). Логику держат поля Pet (hero_buffs, hero_fx,
## bond_mode, bond_guard, bond_light) и этот файл; Pet, Player и HeroSkillFx зовут его в нескольких точках:
##   * ауры и пассивки героя для питомца — HeroSkills.pet_aura_bonuses (aura "pet" / "both", у пассивок питомца —
##     aura "pet") + усиления на время Pet.apply_hero_buff (эффект "buff" с who "pet" / "both") → pet_bonuses():
##     статы (str…luck, pet_stats — все сразу) идут в PetStats.derived (extra), остальное — apply_to_pet поверх
##     производных: атаки, HP, MP, защиты (доли и числа), уклонение и крит (доли героя → проценты питомца), скорость
##     атаки и бега, восстановление (pet_regen), угроза (threat), урон по питомцу (guard), урон светом обычных атак
##     (pet_light). Значки: включённые ауры героя — "hero:<id>", усиления — "hero_buff:<id>", лечение со временем —
##     "hot:<id>" у полоски HP питомца (Pet.effects);
##   * опыт питомца (pet_xp — PetManager.on_mob_killed), «Общая боль» (pass_dmg — Player.take_damage → share_pain),
##     «Нить жизни» (life_thread — Pet.take_damage → save_from_death);
##   * воскрешение питомца умением (revive), жертва питомцем (sacrifice) и отбор его HP (drain: не ниже PET_FLOOR);
##   * слияние с питомцем и звериный облик (переключаемые с полем "bond": "merge" / "form" — Pet.bond_mode):
##     «Слияние душ» — питомец «уходит» в героя (скрыт, не бьёт и не получает урона), герою — доля его статов
##     (add_hero_bonus) и сияние; «Звериный облик» — модель героя скрыта, на её месте бежит модель питомца. Выключили,
##     не хватило MP, питомец пропал — связь рвётся, питомец снова рядом (hero_changed, pet_gone).
## Особые обработчики умений, общие для профессий (эффект {"do": "special", "handler": ...}): sp_revive_pet,
## sp_sacrifice_pet, sp_cleanse_pet и проверки can_* — их подключает job_fx_beastmaster.gd (HeroSkillFx.JOB_FX_FILES;
## файлы грузятся все сразу, поэтому обработчики работают у любой профессии).

## «Слияние душ»: какая доля Силы, Интеллекта и макс. HP питомца переходит герою.
const MERGE_SHARE := 0.25
## «Нить жизни»: после срабатывания — перезарядка, с.
const LIFE_THREAD_CD := 60.0
## Отбор HP питомца умениями (жертва частью HP, «Общая боль») не опускает его ниже этой доли макс. HP.
const PET_FLOOR := 0.25
## «Общая боль» не передаёт урон питомцу, у которого меньше этой доли HP.
const PAIN_MIN := 0.3
## Слияние, облик и жертвы: питомец не дальше, м.
const BOND_RANGE := 20.0
## Урон сила духов («Гнев духов») раз в столько секунд.
const SPIRIT_TICK := 1.0
const BOND_COLOR := Color(0.55, 0.85, 0.4)
const BLOOD_COLOR := Color(0.85, 0.12, 0.2)
## Тексты бонусов, которых нет у героя (HeroSkills.bonus_text спрашивает сначала здесь).
const BONUS_KEYS := ["pet_stats", "pet_xp", "pet_regen", "threat", "pet_light", "pass_dmg", "life_thread", "mdef_pct"]

## Не даёт hero_changed / recalc_stats звать друг друга по кругу.
static var _busy := false


# ---------- Тексты ----------

static func bonus_text(key: String, v: float) -> String:
	match key:
		"pet_stats":
			return "все характеристики питомца +%s" % _num(v)
		"pet_xp":
			return "опыт питомца +%s" % _pct(v)
		"pet_regen":
			return "восстановление HP и MP питомца +%s" % _pct(v)
		"threat":
			return "удар питомца переманивает зверя, бьющего героя: шанс %s" % _pct(v)
		"pet_light":
			return "обычные атаки питомца + %s урона светом" % _pct(v)
		"pass_dmg":
			return "%s урона по герою принимает питомец (пока у него больше %s HP)" % [_pct(v), _pct(PAIN_MIN)]
		"life_thread":
			return "питомец при гибели встаёт с %s HP (раз в %d с)" % [_pct(v), roundi(LIFE_THREAD_CD)]
		"mdef_pct":
			return "маг. защита +%s" % _pct(v)
	return ""


static func _pct(v: float) -> String:
	var p := v * 100.0
	if is_equal_approx(p, roundf(p)):
		return "%d%%" % roundi(p)
	return "%.1f%%" % p


static func _num(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(roundi(v))
	return "%.1f" % v


# ---------- Кто есть кто ----------

## Призванный живой питомец героя p (и слитый с героем — тоже) или null.
static func active_pet(p: Player) -> Pet:
	if p == null or not is_instance_valid(p):
		return null
	return p._active_pet() as Pet


## Модуль питомцев (main.pets) или null.
static func manager(p: Player) -> PetManager:
	if p == null or not is_instance_valid(p) or p.get_parent() == null:
		return null
	var mgr: Variant = p.get_parent().get("pets")
	if not is_instance_valid(mgr):
		return null
	return mgr as PetManager


## Бонусы героя (пассивные и включённые переключаемые) — значение ключа key ("pass_dmg", "life_thread"…).
static func hero_value(key: String) -> float:
	if Game.hero.is_empty():
		return 0.0
	var b := HeroSkills.bonuses(Game.hero, Game.class_id, Game.weapon_kind(), Game.has_shield())
	return float(b.get(key, 0.0))


# ---------- Бонусы питомцу ----------

## Все бонусы питомцу от героя: ауры и пассивки (HeroSkills.pet_aura_bonuses) + усиления на время (pet.hero_buffs).
static func pet_bonuses(pet: Pet) -> Dictionary:
	var b: Dictionary = {}
	if not Game.hero.is_empty():
		b = HeroSkills.pet_aura_bonuses(Game.hero, Game.class_id, Game.weapon_kind(), Game.has_shield())
	if pet != null:
		for id in pet.hero_buffs:
			var hb: Dictionary = (pet.hero_buffs[id] as Dictionary)["bonus"]
			for k in hb:
				b[k] = float(b.get(k, 0.0)) + float(hb[k])
	return b


## Прибавки 7 статов питомца (до формул PetStats.derived): статы и pet_stats (все сразу).
static func stat_extra(b: Dictionary) -> Dictionary:
	var ex: Dictionary = {}
	var all := float(b.get("pet_stats", 0.0))
	for k in Stats.STATS:
		var v := float(b.get(k, 0.0)) + all
		if v != 0.0:
			ex[k] = v
	return ex


## Бонусы героя поверх производных питомца r (PetStats.derived) и поля связи у pet. Единицы героя → питомца:
## уклонение и крит — доли → проценты, скорость атаки — доля → ×.
static func apply_to_pet(pet: Pet, r: Dictionary, b: Dictionary) -> void:
	var mg := PetStats.is_magic(pet.species)
	var atk_pct := float(b.get("atk_pct", 0.0))
	r["patk"] = maxi(1, roundi(float(r["patk"]) * (1.0 + atk_pct)) + roundi(float(b.get("atk_flat", 0.0))))
	r["matk"] = maxi(1, roundi(float(r["matk"]) * (1.0 + atk_pct + float(b.get("matk_pct", 0.0)))))
	r["atk"] = int(r["matk"]) if mg else int(r["patk"])
	r["max_hp"] = maxi(1, roundi(float(r["max_hp"]) * (1.0 + float(b.get("hp_pct", 0.0)))) + roundi(float(b.get("hp_flat", 0.0))))
	r["max_mp"] = maxi(0, roundi(float(r["max_mp"]) * (1.0 + float(b.get("mp_pct", 0.0)))))
	var def_pct := float(b.get("def_pct", 0.0))
	r["def"] = roundi(float(r["def"]) * (1.0 + def_pct)) + roundi(float(b.get("def_flat", 0.0)))
	r["mdef"] = roundi(float(r["mdef"]) * (1.0 + def_pct + float(b.get("mdef_pct", 0.0)))) + roundi(float(b.get("mdef_flat", 0.0)))
	r["eva"] = snappedf(float(r["eva"]) + 100.0 * float(b.get("eva", 0.0)), 0.1)
	r["crit"] = snappedf(float(r["crit"]) + 100.0 * float(b.get("crit", 0.0)), 0.1)
	var aspd := float(b.get("aspd", 0.0))
	if aspd != 0.0:
		r["aspd"] = roundi(float(r["aspd"]) * (1.0 + aspd))
		r["cd"] = float(r["cd"]) / maxf(0.2, 1.0 + aspd)
	r["speed"] = float(r["speed"]) * (1.0 + float(b.get("speed_pct", 0.0)))
	var rg := float(b.get("pet_regen", 0.0))
	r["hp_regen"] = snappedf(float(r["hp_regen"]) * (1.0 + rg) + float(r["max_hp"]) * 0.002 * rg + float(b.get("regen", 0.0)), 0.1)
	r["mp_regen"] = snappedf(float(r["mp_regen"]) * (1.0 + rg) + float(b.get("mp_regen", 0.0)), 0.1)
	r["threat"] = float(r["threat"]) + float(b.get("threat", 0.0))
	pet.bond_guard = clampf(float(b.get("guard", 0.0)), 0.0, 0.9)
	pet.bond_light = maxf(0.0, float(b.get("pet_light", 0.0)))
	pet.bond_hash = b.hash()


## Значки включённых аур героя у полоски HP питомца ("hero:<id>").
static func sync_aura_icons(pet: Pet) -> void:
	var on := {}
	if not pet.is_down and not Game.hero.is_empty():
		var tg: Dictionary = Game.hero.get("toggles", {})
		for id in tg:
			var sid := String(id)
			if not bool(tg[id]) or String(HeroSkills.get_skill(sid).get("aura", "")) == "":
				continue
			if not HeroSkills.weapon_ok(sid, Game.weapon_kind(), Game.has_shield()):
				continue
			on["hero:" + sid] = StatusEffects.toggle_info(StatusEffects.source_hero_skill(sid), Game.char_name)
	pet.effects.sync_toggles("hero:", on)


## Опыт питомцу за убийство × это («Наставник зверя»).
static func xp_mult() -> float:
	return 1.0 + maxf(0.0, pet_value("pet_xp"))


## Значение ключа из бонусов питомцу (ауры и пассивки, без усилений на время).
static func pet_value(key: String) -> float:
	if Game.hero.is_empty():
		return 0.0
	return float(HeroSkills.pet_aura_bonuses(Game.hero, Game.class_id, Game.weapon_kind(), Game.has_shield()).get(key, 0.0))


# ---------- Герой ----------

## Добавить к бонусам героя b то, что даёт связь с питомцем: «Слияние душ» — доля Силы, Интеллекта и HP питомца.
static func add_hero_bonus(p: Player, b: Dictionary) -> void:
	var pet := active_pet(p)
	if pet == null or pet.bond_mode != "merge":
		return
	var st: Dictionary = pet.stats.get("stats", {})
	b["str"] = float(b.get("str", 0.0)) + roundf(float(st.get("str", 0)) * MERGE_SHARE)
	b["int"] = float(b.get("int", 0.0)) + roundf(float(st.get("int", 0)) * MERGE_SHARE)
	b["hp_flat"] = float(b.get("hp_flat", 0.0)) + roundf(float(pet.max_hp) * MERGE_SHARE)


## Какую связь хотят включённые умения героя: "merge", "form" или "" (поле "bond" переключаемого умения).
static func bond_want() -> String:
	if Game.hero.is_empty():
		return ""
	var tg: Dictionary = Game.hero.get("toggles", {})
	for id in tg:
		if bool(tg[id]):
			var bd := String(HeroSkills.get_skill(String(id)).get("bond", ""))
			if bd != "":
				return bd
	return ""


## Почему переключаемое умение id нельзя включить ("" — можно): связь с питомцем требует призванного питомца рядом.
static func toggle_block(p: Player, id: String) -> String:
	if not HeroSkills.get_skill(id).has("bond"):
		return ""
	var pet := active_pet(p)
	if pet == null:
		return "Нужен призванный питомец"
	if pet.bond_mode == "" and pet.global_position.distance_to(p.global_position) > BOND_RANGE:
		return "Питомец слишком далеко"
	return ""


## После пересчёта героя (Player.recalc_stats): связь питомца — как велят включённые умения, бонусы питомцу —
## свежие (ауры включили / выключили, изучили пассивку, сменили оружие).
static func hero_changed(p: Player) -> void:
	if _busy or p == null or not is_instance_valid(p):
		return
	_busy = true
	var pet := active_pet(p)
	var want := bond_want()
	if want != "" and pet == null:
		_drop_bond_toggles(p, "нет призванного питомца")
		want = ""
	if pet != null:
		if pet.bond_mode != want:
			set_mode(pet, want)
			p.recalc_stats()
		pet.refresh_hero_bonuses()
	_busy = false


## Выключить переключаемые умения связи (питомца нет) с сообщением и пересчитать героя.
static func _drop_bond_toggles(p: Player, why: String) -> void:
	var tg: Dictionary = Game.hero.get("toggles", {})
	var off: PackedStringArray = []
	for id in tg.keys():
		if HeroSkills.get_skill(String(id)).has("bond"):
			tg.erase(id)
			off.append(String(HeroSkills.get_skill(String(id)).get("name", id)))
	if off.is_empty():
		return
	p.message.emit("%s выключено: %s" % [", ".join(off), why])
	p.recalc_stats()


## Урон по герою amount: «Общая боль» отдаёт часть питомцу (не ниже PET_FLOOR его HP; слабого питомца не трогает).
## Возвращает урон, что остался герою.
static func share_pain(p: Player, amount: int) -> int:
	if amount <= 1:
		return amount
	var share := hero_value("pass_dmg")
	if share <= 0.0:
		return amount
	var pet := active_pet(p)
	if pet == null or pet.bond_mode != "" or float(pet.hp) < float(pet.max_hp) * PAIN_MIN:
		return amount
	var part := drain(pet, roundi(float(amount) * share))
	return maxi(1, amount - part)


# ---------- Питомец ----------

## Урон по питомцу с защитой от героя («Оберег», «Гнев стаи»…).
static func pet_incoming(pet: Pet, amount: int) -> int:
	if pet.bond_guard <= 0.0:
		return amount
	return maxi(1, roundi(float(amount) * (1.0 - pet.bond_guard)))


## Обычный удар питомца по t: «Светлые когти» добавляют урон светом. Возвращает «сырой» урон.
static func pet_basic_hit(pet: Pet, t: Mob, dmg: int) -> int:
	if pet.bond_light <= 0.0:
		return dmg
	if pet.is_inside_tree() and is_instance_valid(t):
		Vfx.hit_spark(pet.get_parent(), t.mid_point(), Color(1.0, 0.92, 0.55), 0.7)
	return dmg + maxi(1, roundi(float(dmg) * pet.bond_light))


## Питомец получил смертельный удар: «Нить жизни» поднимает его (раз в LIFE_THREAD_CD). true — спасён.
static func save_from_death(pet: Pet) -> bool:
	if pet.bond_mode != "" or pet.life_thread_cd > 0.0:
		return false
	var v := hero_value("life_thread")
	if v <= 0.0:
		return false
	pet.life_thread_cd = LIFE_THREAD_CD
	pet.hp = maxi(1, roundi(float(pet.max_hp) * v))
	pet.bond_hp_changed()
	if pet.is_inside_tree():
		Vfx.level_up(pet.get_parent(), pet.global_position, 0.7)
		Util.float_text(pet.get_parent(), pet.global_position + Vector3(0, 2.0, 0), "Нить жизни!", Color(0.6, 1.0, 0.7), 1.2)
	var sid := "life_thread"
	pet.hero_effect("hero_cd:" + sid, LIFE_THREAD_CD, {"name": "Нить жизни перезаряжается", "src": "",
		"icon": IconView.hero_skill(sid), "debuff": true})
	if is_instance_valid(pet.owner_node):
		pet.owner_node.message.emit("«Нить жизни»: «%s» снова встаёт" % pet.pet_name)
	return true


## Забрать у питомца до want HP (жертвы частью HP, «Общая боль»): не ниже PET_FLOOR его макс. HP. Возвращает, сколько
## забрано.
static func drain(pet: Pet, want: int) -> int:
	if pet == null or pet.is_down or want <= 0:
		return 0
	var keep := ceili(float(pet.max_hp) * PET_FLOOR)
	var take := mini(want, pet.hp - keep)
	if take <= 0:
		return 0
	pet.hp -= take
	pet.bond_hp_changed()
	if pet.is_inside_tree():
		Util.float_text(pet.get_parent(), pet.global_position + Vector3(0, 1.8, 0), "−%d" % take, Color(0.9, 0.35, 0.55))
		Vfx.hit_spark(pet.get_parent(), pet.global_position + Vector3(0, 0.8, 0), BLOOD_COLOR, 0.7)
	return take


## Сколько HP можно забрать у питомца сейчас (выше PET_FLOOR).
static func drainable(pet: Pet) -> int:
	if pet == null or pet.is_down:
		return 0
	return maxi(0, pet.hp - ceili(float(pet.max_hp) * PET_FLOOR))


## Питомец жертвует собой (погибает — нужно воскрешение). «Нить жизни» жертву не отменяет.
static func sacrifice(pet: Pet) -> void:
	if pet == null or pet.is_down:
		return
	if pet.is_inside_tree():
		Vfx.magic_burst(pet.get_parent(), pet.global_position + Vector3(0, 0.8, 0), BLOOD_COLOR, 1.6, 0.5)
	pet.bond_sacrifice()


## Индекс погибшего питомца для воскрешения умением: погибший последним (record "died_at"), иначе первый погибший.
static func dead_index() -> int:
	var best := -1
	var best_t := -1
	for i in Game.pets.size():
		var rec: Dictionary = Game.pets[i]
		if not bool(rec.get("dead", false)):
			continue
		var t := int(rec.get("died_at", 0))
		if best < 0 or t > best_t:
			best = i
			best_t = t
	return best


## Воскресить погибшего питомца (dead_index) с долей HP и MP и призвать рядом с героем. true — воскрешён.
static func revive(p: Player, hp_frac: float, mp_frac: float) -> bool:
	var i := dead_index()
	var mgr := manager(p)
	if i < 0 or mgr == null:
		return false
	var rec: Dictionary = Game.pets[i]
	PetSkills.ensure_record(rec)
	var st := PetData.stats_for(String(rec.get("species", "boar")), int(rec.get("level", 1)), rec["skills"], rec["toggles"])
	rec["dead"] = false
	rec["hp"] = maxi(1, roundi(float(st["max_hp"]) * clampf(hp_frac, 0.01, 1.0)))
	rec["mp"] = maxi(0, roundi(float(st["max_mp"]) * clampf(mp_frac, 0.0, 1.0)))
	if not mgr.summon(i):
		return false
	var pet := active_pet(p)
	if pet != null:
		# Доли — от макс. HP и MP с бонусами героя (у призванного они выше, чем в записи)
		pet.hp = maxi(1, roundi(float(pet.max_hp) * clampf(hp_frac, 0.01, 1.0)))
		pet.mp = maxi(0, roundi(float(pet.max_mp) * clampf(mp_frac, 0.0, 1.0)))
		pet.bond_hp_changed()
	if pet != null and pet.is_inside_tree():
		Vfx.level_up(pet.get_parent(), pet.global_position, 0.8)
		Vfx.heal_sparkles(pet.get_parent(), pet.global_position, 0.9)
	return true


## Слияние ("merge"), облик ("form") или обычный питомец (""): вид и поведение питомца, модель героя, сияние.
static func set_mode(pet: Pet, mode: String) -> void:
	var old := pet.bond_mode
	if old == mode:
		return
	var p := pet.owner_node
	pet.bond_mode = mode
	var parent := pet.get_parent()
	if mode == "":
		pet.visible = true
		pet.collision_layer = 2
		if not pet.is_in_group("pets"):
			pet.add_to_group("pets")
		pet.set_label_visible(true)
		if is_instance_valid(p):
			_hero_model_visible(p, true)
			_hero_aura(p, false, BOND_COLOR)
			if pet.is_inside_tree():
				pet._teleport_to_owner()
		if pet.is_inside_tree() and parent != null:
			Vfx.magic_burst(parent, pet.global_position + Vector3(0, 0.7, 0), BOND_COLOR, 1.3, 0.45)
		pet.refresh_skills()
		return
	# Звери, что били питомца, переключаются на героя: питомца больше нет в мире
	pet.target = null
	pet.collision_layer = 0
	if pet.is_in_group("pets"):
		pet.remove_from_group("pets")
	if pet.is_inside_tree():
		for n in pet.get_tree().get_nodes_in_group("mobs"):
			var m := n as Mob
			if m != null and m.target == pet:
				m.target = p
	var col := PetData.fx_color(pet.species, BOND_COLOR)
	if mode == "merge":
		pet.visible = false
		if is_instance_valid(p):
			_hero_model_visible(p, true)
			_hero_aura(p, true, col)
	else:
		pet.visible = true
		pet.set_label_visible(false)
		if is_instance_valid(p):
			_hero_model_visible(p, false)
			_hero_aura(p, false, col)
	if is_instance_valid(p) and p.is_inside_tree() and parent != null:
		Vfx.magic_burst(parent, p.global_position + Vector3(0, 1.0, 0), col, 1.6, 0.5)
		Vfx.death_puff(parent, p.global_position + Vector3(0, 0.6, 0), 0.8)
	pet.refresh_skills()


## Каждый кадр у питомца в слиянии или облике: стоит в герое. true — ИИ питомца в этот кадр не работает.
static func tick_pet(pet: Pet, _delta: float) -> bool:
	if pet.bond_mode == "":
		return false
	var p := pet.owner_node
	if not is_instance_valid(p):
		return true
	pet.velocity = p.velocity
	pet.global_position = p.global_position
	if pet.bond_mode == "form":
		pet.rotation.y = p.rotation.y
		# Модель героя могла пересобраться (смена оружия): облик держится
		_hero_model_visible(p, false)
	return true


## Питомец ушёл из мира (отозван, погиб, заменён): связь рвётся — модель героя на месте, умения связи выключены.
static func pet_gone(pet: Pet) -> void:
	var p := pet.owner_node
	pet.bond_mode = ""
	if not is_instance_valid(p) or not p.is_inside_tree():
		return
	_hero_model_visible(p, true)
	_hero_aura(p, false, BOND_COLOR)
	if bond_want() != "":
		_drop_bond_toggles(p, "питомца нет рядом")


## Питомец погиб: когда (воскрешение умением поднимает погибшего последним).
static func pet_died(pet: Pet) -> void:
	pet.record["died_at"] = Time.get_ticks_msec()
	pet_gone(pet)


static func _hero_model_visible(p: Player, on: bool) -> void:
	if p._has_model() and p._model.visible != on:
		p._model.visible = on


## Сияние вокруг героя в «Слиянии душ»: цветная оболочка (оттенок) и искры цвета питомца.
static func _hero_aura(p: Player, on: bool, c: Color) -> void:
	var old := p.get_node_or_null("PetBondAura")
	if not on:
		if old != null:
			old.queue_free()
		return
	if old != null:
		return
	var root := Node3D.new()
	root.name = "PetBondAura"
	p.add_child(root)
	var shell := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.5
	cm.height = 2.0
	shell.mesh = cm
	shell.position.y = 1.0
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.material_override = Vfx.fx_mat(Color(c, 0.16))
	shell.set_meta("no_outline", true)
	root.add_child(shell)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.7
	tm.outer_radius = 0.8
	ring.mesh = tm
	ring.position.y = 0.05
	ring.material_override = CreatureModels.flat_mat(c)
	ring.set_meta("no_outline", true)
	root.add_child(ring)
	var sp := Vfx.ambient_sparkles(root, c, 0.6, 14)
	sp.position.y = 1.0


# ---------- Особые обработчики (HeroSkillFx.JOB_FX_FILES через job_fx_beastmaster.gd): общие для профессий ----------

## Эффекты {"do": "special"} умения sk: [словарь эффекта, …] (для pre_cast файлов профессий).
static func specials(sk: Dictionary) -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	for e in sk.get("fx", []):
		var d: Dictionary = e
		if String(d.get("do", "")) == "special":
			res.append(d)
	return res

## Воскресить погибшего питомца: e — {"hp": доля HP, "mp": доля MP} по уровням.
static func can_revive_pet(fx: HeroSkillFx, _sid: String, _n: int, _t: Mob, _e: Dictionary) -> String:
	if active_pet(fx.p) != null:
		return "питомец жив и рядом"
	if dead_index() < 0:
		return "нет погибших питомцев"
	return ""


static func sp_revive_pet(fx: HeroSkillFx, _sid: String, n: int, _t: Mob, e: Dictionary) -> void:
	var hp := HeroSkills.value_at(e.get("hp", 0.3), n)
	var mp := HeroSkills.value_at(e.get("mp", 0.2), n)
	var nm := String(Game.pets[dead_index()].get("name", "")) if dead_index() >= 0 else ""
	if revive(fx.p, hp, mp):
		fx.p.message.emit("«%s» воскрешён: %s HP" % [nm, _pct(hp)])


## Питомец жертвует собой (дальше в fx — что получает герой: лечение, защита…).
static func can_sacrifice_pet(fx: HeroSkillFx, _sid: String, _n: int, _t: Mob, _e: Dictionary) -> String:
	return need_pet(fx.p, false)


static func sp_sacrifice_pet(fx: HeroSkillFx, _sid: String, _n: int, _t: Mob, _e: Dictionary) -> void:
	var pet := active_pet(fx.p)
	if pet != null:
		sacrifice(pet)


## Снять с питомца ослабления с шансом e["chance"]: значки-дебафы (Pet.effects).
static func can_cleanse_pet(fx: HeroSkillFx, _sid: String, _n: int, _t: Mob, _e: Dictionary) -> String:
	return need_pet(fx.p, false)


static func sp_cleanse_pet(fx: HeroSkillFx, _sid: String, n: int, _t: Mob, e: Dictionary) -> void:
	var pet := active_pet(fx.p)
	if pet == null:
		return
	var removed := 0
	if randf() < HeroSkills.value_at(e.get("chance", 1.0), n):
		removed = pet.cleanse_debuffs()
	if pet.is_inside_tree():
		Vfx.heal_sparkles(pet.get_parent(), pet.global_position, 0.8)
	fx.p.message.emit("Очищение: снято ослаблений — %d" % removed if removed > 0 else "Очищение: ослаблений нет, питомец под защитой")


## Нужен призванный питомец рядом (не в слиянии); need_hp — ещё и не слабее PET_FLOOR + 5 % HP. "" — есть.
static func need_pet(p: Player, need_hp: bool) -> String:
	var pet := active_pet(p)
	if pet == null:
		return "нет призванного питомца"
	if pet.bond_mode != "":
		return "питомец слит с героем"
	if pet.global_position.distance_to(p.global_position) > BOND_RANGE:
		return "питомец слишком далеко"
	if need_hp and float(pet.hp) < float(pet.max_hp) * (PET_FLOOR + 0.05):
		return "питомец слишком слаб"
	return ""
