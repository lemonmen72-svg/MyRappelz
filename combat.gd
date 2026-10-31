class_name Combat
extends RefCounted
## Единая модель боя «статы против статов» (решение Максима): герой, питомец и зверь мира сталкивают свои
## характеристики — одинаковыми формулами для всех сторон.
## • Попадание: точность атакующего (Stats.accuracy — Меткость) против избегания цели (Stats.avoidance — Ловкость)
##   и разница уровней. Равный уровень ≈ 95 %, цель выше на 5 ур. — 65 %, на 10 — 21 %, на 20 — 0.2 %;
##   цель ниже — до 99 %. Уклонение героя и питомца (eva, %) — отдельный бросок у них (Player/Pet.take_damage).
##   Умения не промахиваются по цели своего уровня и ниже (и до +SKILL_SURE_LEVELS), выше — по той же кривой уровней.
## • Урон: «сырой» удар (атака × множитель умения + разброс, крит) × пробивание защиты power / (power + защита)
##   (защита снижает урон, но не в ноль; физ. атака — против физ. защиты, магия — против маг. защиты)
##   × множитель разницы уровней 1 + 0.0015·d·|d| (±1.4 % на 3 ур., ±15 % на 10, ×1.6 / ×0.4 на 20).
## • Крит: шанс атакующего (Удача, Ловкость, оружие) ±1 % за уровень разницы, не больше 75 %.
## • Опыт: множитель по разнице уровней зверя и героя (питомца) — xp_factor, глобальный Game.xp_mult.
## Где применяется: Player (обычная атака, умения, HeroSkillFx), Pet (атаки и умения), Mob (удары по герою и питомцу).
## take_damage у всех — уже готовый урон (защиту учитывает атакующий через damage()).

## Попадание: база на равном уровне, потолок, ширина спада по уровням (шанс × exp(−d² / HIT_SPREAD)).
const HIT_BASE := 0.95
const HIT_MAX := 0.99
const HIT_SPREAD := 66.0
## Цель ниже: +0.5 % за уровень (до HIT_MAX).
const HIT_LOWER_STEP := 0.005
## Точность против избегания: ±0.2 % за единицу разницы, не больше ±5 %.
const HIT_STAT_K := 0.002
const HIT_STAT_CAP := 0.05
## Умения бьют без промаха по цели выше героя не больше чем на столько уровней.
const SKILL_SURE_LEVELS := 2
## Множитель урона по разнице уровней: 1 + K·d·|d| в пределах [MIN, MAX].
const LEVEL_DMG_K := 0.0015
const LEVEL_DMG_MIN := 0.4
const LEVEL_DMG_MAX := 1.6
## Крит: ±1 % за уровень разницы, потолок.
const CRIT_LEVEL_K := 0.01
const CRIT_MAX := 0.75
## Крит зверя — ×1.5 (у героя Player.CRIT_MULT, у питомца PetStats.CRIT_MULT).
const MOB_CRIT_MULT := 1.5


# ---------- Попадание ----------

## Шанс попасть только по уровням (d = уровень цели − уровень атакующего).
static func level_hit(d: int) -> float:
	if d <= 0:
		return minf(HIT_MAX, HIT_BASE + HIT_LOWER_STEP * float(-d))
	return HIT_BASE * exp(-float(d * d) / HIT_SPREAD)


## Шанс попасть обычной атакой: точность acc против избегания avoid цели, уровни атакующего и цели (0..0.99).
static func hit_chance(acc: float, avoid: float, atk_lvl: int, def_lvl: int) -> float:
	var base := level_hit(def_lvl - atk_lvl)
	var st := clampf(HIT_STAT_K * (acc - avoid), -HIT_STAT_CAP, HIT_STAT_CAP)
	return clampf(base + st * base / HIT_BASE, 0.0, HIT_MAX)


## Шанс, что умение достанет цель: 1.0 до +SKILL_SURE_LEVELS, выше — та же кривая уровней.
static func skill_hit_chance(atk_lvl: int, def_lvl: int) -> float:
	var d := def_lvl - atk_lvl
	if d <= SKILL_SURE_LEVELS:
		return 1.0
	return minf(1.0, level_hit(d) / HIT_BASE)


# ---------- Урон ----------

## Множитель урона по разнице уровней атакующего и цели.
static func level_damage(atk_lvl: int, def_lvl: int) -> float:
	var d := float(atk_lvl - def_lvl)
	return clampf(1.0 + LEVEL_DMG_K * d * absf(d), LEVEL_DMG_MIN, LEVEL_DMG_MAX)


## Доля урона, которая проходит сквозь защиту: power / (power + armor) × разница уровней.
static func damage_factor(power: float, armor: float, atk_lvl: int, def_lvl: int) -> float:
	var p := maxf(1.0, power)
	return p / (p + maxf(0.0, armor)) * level_damage(atk_lvl, def_lvl)


## Готовый урон по цели: «сырой» удар raw (атака × множитель, крит) после защиты armor и уровней. Не меньше 1.
static func damage(raw: float, power: float, armor: float, atk_lvl: int, def_lvl: int) -> int:
	return maxi(1, roundi(raw * damage_factor(power, armor, atk_lvl, def_lvl)))


## Шанс крита base (0..1) с поправкой на разницу уровней.
static func crit_chance(base: float, atk_lvl: int, def_lvl: int) -> float:
	return clampf(base + CRIT_LEVEL_K * float(atk_lvl - def_lvl), 0.0, CRIT_MAX)


# ---------- Стороны боя ----------

## Уровень участника боя: героя — Game.level, питомца и зверя — свой.
static func level_of(n: Object) -> int:
	if n is Player:
		return Game.level
	if n is Mob:
		return (n as Mob).level
	if n is Pet:
		return (n as Pet).level
	return 1


## Защита цели: физическая или магическая (у героя — с бонусом «Уз» питомца).
static func defense_of(n: Object, magic: bool) -> float:
	if n is Player:
		var p := n as Player
		return float((p.mdef if magic else p.defense) + p.aura_def)
	if n is Mob:
		var m := n as Mob
		return float(m.mdef if magic else m.pdef)
	if n is Pet:
		var pt := n as Pet
		return float(pt.mdef if magic else pt.defense)
	return 0.0


## Избегание цели (против точности атакующего).
static func avoid_of(n: Object) -> float:
	if n is Player:
		return float((n as Player).avoid)
	if n is Mob:
		return float((n as Mob).avoid)
	if n is Pet:
		return float((n as Pet).avoid)
	return 0.0


# ---------- Опыт ----------

## Множитель опыта по разнице уровней d = уровень зверя − уровень героя (питомца):
## равный — 100 %, ниже на 6 — 50 % (плавно), на 10 — 15 %, ещё ниже — 10 %; выше на 6 — +25 %, на 11+ — +30 %.
static func xp_factor(d: int) -> float:
	if d >= 0:
		return 1.0 + 0.25 * minf(float(d), 6.0) / 6.0 + 0.01 * clampf(float(d - 6), 0.0, 5.0)
	if d >= -6:
		return 1.0 + 0.5 * float(d) / 6.0
	if d >= -10:
		return 0.5 - 0.0875 * float(-6 - d)
	return 0.1


## Опыт за зверя уровня mob_lvl с базовой наградой base для героя (питомца) уровня lvl: разница уровней
## (не меньше 1), затем — ровно × Game.xp_mult (множитель админ-панели, целый).
static func xp_for(base: int, mob_lvl: int, lvl: int) -> int:
	return maxi(1, roundi(float(base) * xp_factor(mob_lvl - lvl))) * maxi(1, Game.xp_mult)


# ---------- Оценка силы (баланс, тесты) ----------

## Профиль бойца (героя, зверя или питомца) для оценки силы: level, max_hp, atk (главная атака), magic, def, mdef,
## acc, avoid, eva и crit (0..1), interval (с между ударами), crit_mult, block (0..1).
static func profile_of(n: Object) -> Dictionary:
	if n is Player:
		var p := n as Player
		return {
			"level": Game.level, "max_hp": p.max_hp, "atk": p.cur_matk() if p.attack_kind == "magic" else p.cur_atk(),
			"magic": p.attack_kind == "magic", "def": p.defense + p.aura_def, "mdef": p.mdef + p.aura_def,
			"acc": p.accuracy, "avoid": p.avoid, "eva": p.cur_eva(), "crit": p.cur_crit(), "interval": p.attack_time,
			"crit_mult": Player.CRIT_MULT, "block": p.block,
		}
	if n is Mob:
		var m := n as Mob
		return {
			"level": m.level, "max_hp": m.max_hp, "atk": m.atk, "magic": m.magic, "def": m.pdef, "mdef": m.mdef,
			"acc": m.acc, "avoid": m.avoid, "eva": 0.0, "crit": m.crit / 100.0, "interval": m.attack_every,
			"crit_mult": MOB_CRIT_MULT, "block": 0.0,
		}
	if n is Pet:
		var pt := n as Pet
		return {
			"level": pt.level, "max_hp": pt.max_hp, "atk": pt.atk, "magic": PetStats.is_magic(pt.species),
			"def": pt.defense, "mdef": pt.mdef, "acc": pt.accuracy, "avoid": pt.avoid, "eva": pt.evasion / 100.0,
			"crit": pt.crit / 100.0, "interval": pt.attack_time, "crit_mult": PetStats.CRIT_MULT, "block": 0.0,
		}
	return {}


## Ожидаемый урон в секунду a по b (профили profile_of): попадание, уклонение и блок цели, защита, уровни, крит.
static func expected_dps(a: Dictionary, b: Dictionary) -> float:
	var la := int(a["level"])
	var lb := int(b["level"])
	var hit := hit_chance(float(a["acc"]), float(b["avoid"]), la, lb)
	hit *= (1.0 - float(b.get("eva", 0.0))) * (1.0 - float(b.get("block", 0.0)))
	var armor := float(b["mdef"]) if bool(a["magic"]) else float(b["def"])
	var dmg := float(a["atk"]) * damage_factor(float(a["atk"]), armor, la, lb)
	var cr := crit_chance(float(a["crit"]), la, lb)
	return hit * dmg * (1.0 + cr * (float(a["crit_mult"]) - 1.0)) / maxf(0.1, float(a["interval"]))


## «Эффективная сила» зверя m относительно героя h (профили): (HP × урон в секунду) зверя / то же у героя.
## < 1 — герой сильнее (бой 1×1 выигрышный), равный уровень ≈ 0.8 (зверь слабее на ~20 %). Вместо героя может
## быть питомец (profile_of(pet), PetStats.combat_profile): питомец своего уровня тоже побеждает зверя своего уровня.
static func power_ratio(h: Dictionary, m: Dictionary) -> float:
	var dh := expected_dps(h, m)
	var dm := expected_dps(m, h)
	return (float(m["max_hp"]) * dm) / maxf(0.001, float(h["max_hp"]) * dh)
