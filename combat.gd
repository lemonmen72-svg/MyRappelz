class_name Combat
extends RefCounted
## Единая модель боя для героя, питомца и зверя — формулы сервера оригинала (StructCreature::CalcDamage,
## GetCriticalDamage; tools/rappelz_db_reference.md, «Формулы сервера»).
## • Попадание: шанс, % = точность / уклонение цели × max(10, 2·(44 + L атакующего − L цели)) + 7 (бросок 0…99).
##   Равные уровни и статы — 95 %, цель на 10 ур. выше — 75 %, на 39+ — 17 %; цель ниже — почти всегда.
##   Отдельный бросок уклонения героя и питомца (eva, %: умения, пояса) и блок щитом — у них (take_damage).
##   Умения не промахиваются по цели до +SKILL_SURE_LEVELS выше, дальше — доля шанса по уровням.
## • Урон: A — атака (у умения — атака × множитель), D — защита цели (физ. или маг.), L — уровень атакующего:
##   A·max(0.05, 1 − 0.5·D/A) + 1.7·L·max(0.3, 1 − 0.4·D/A), не меньше 1 (защита вычитается наполовину).
##   У нас урон умения и крит — доля от урона по атаке (damage_factor = урон(A) / A), так множители умений
##   и разброс остаются как были.
## • Крит: шанс атакующего (0.2·Удача + 3 %, оружие, умения), урон × 1.8 у всех (сила крита 80).
## • Опыт: множитель по разнице уровней зверя и героя (питомца) — xp_factor, глобальный Game.xp_mult.
## Где применяется: Player (обычная атака, умения, HeroSkillFx), Pet (атаки и умения), Mob (удары по герою и питомцу).
## take_damage у всех — уже готовый урон (защиту учитывает атакующий через damage()).

## Попадание: множитель уровней 2·(HIT_LEVEL_BASE + L атакующего − L цели), не меньше HIT_LEVEL_MIN, + HIT_FLAT %.
const HIT_LEVEL_BASE := 44
const HIT_LEVEL_MIN := 10.0
const HIT_FLAT := 7.0
## Шанс на равных уровнях и статах (для доли у умений).
const HIT_BASE := 0.95
const HIT_MAX := 1.0
## Умения бьют без промаха по цели выше героя не больше чем на столько уровней.
const SKILL_SURE_LEVELS := 2
## Урон: доля атаки после защиты (A − 0.5·D, не меньше 5 % A) и «уровневая» часть 1.7·L (× 1 − 0.4·D/A, не меньше 30 %).
const DEF_HALF := 0.5
const ATK_FLOOR := 0.05
const LEVEL_PART := 1.7
const LEVEL_DEF := 0.4
const LEVEL_FLOOR := 0.3
## Крит не выше CRIT_MAX; урон крита зверя — как у всех (×1.8; герой — Player.CRIT_MULT, питомец — PetStats.CRIT_MULT).
const CRIT_MAX := 0.75
const MOB_CRIT_MULT := 1.8


# ---------- Попадание ----------

## Множитель уровней в шансе попасть (d = уровень цели − уровень атакующего), в процентах на единицу «точность /
## уклонение».
static func level_factor(d: int) -> float:
	return maxf(HIT_LEVEL_MIN, 2.0 * float(HIT_LEVEL_BASE - d))


## Шанс попасть только по уровням (точность равна уклонению цели).
static func level_hit(d: int) -> float:
	return clampf((level_factor(d) + HIT_FLAT) / 100.0, 0.0, HIT_MAX)


## Шанс попасть обычной атакой: точность acc против уклонения avoid цели, уровни атакующего и цели (0..1).
static func hit_chance(acc: float, avoid: float, atk_lvl: int, def_lvl: int) -> float:
	var ratio := maxf(0.0, acc) / maxf(1.0, avoid)
	return clampf((ratio * level_factor(def_lvl - atk_lvl) + HIT_FLAT) / 100.0, 0.0, HIT_MAX)


## Шанс, что умение достанет цель: 1.0 до +SKILL_SURE_LEVELS, выше — доля шанса по уровням.
static func skill_hit_chance(atk_lvl: int, def_lvl: int) -> float:
	var d := def_lvl - atk_lvl
	if d <= SKILL_SURE_LEVELS:
		return 1.0
	return minf(1.0, level_hit(d) / HIT_BASE)


# ---------- Урон ----------

## Урон сервера по атаке power против защиты armor, уровень атакующего atk_lvl.
static func server_damage(power: float, armor: float, atk_lvl: int) -> float:
	var a := maxf(1.0, power)
	var r := maxf(0.0, armor) / a
	return maxf(1.0, a * maxf(ATK_FLOOR, 1.0 - DEF_HALF * r) + LEVEL_PART * float(atk_lvl) * maxf(LEVEL_FLOOR, 1.0 - LEVEL_DEF * r))


## Доля урона, которая проходит сквозь защиту: урон сервера / атака. def_lvl — для совместимости (в оригинале
## разница уровней урон не меняет, только попадание).
static func damage_factor(power: float, armor: float, atk_lvl: int, _def_lvl: int = 0) -> float:
	var p := maxf(1.0, power)
	return server_damage(p, armor, atk_lvl) / p


## Готовый урон по цели: «сырой» удар raw (атака × множитель, крит) после защиты armor. Не меньше 1.
static func damage(raw: float, power: float, armor: float, atk_lvl: int, def_lvl: int) -> int:
	return maxi(1, roundi(raw * damage_factor(power, armor, atk_lvl, def_lvl)))


## Шанс крита base (0..1): как у сервера, от уровней не зависит.
static func crit_chance(base: float, _atk_lvl: int = 0, _def_lvl: int = 0) -> float:
	return clampf(base, 0.0, CRIT_MAX)


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
			"crit_mult": p.crit_mult, "block": p.block,
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
## < 1 — герой сильнее (бой 1×1 выигрышный). Вместо героя может быть питомец (profile_of(pet), PetStats.combat_profile).
static func power_ratio(h: Dictionary, m: Dictionary) -> float:
	var dh := expected_dps(h, m)
	var dm := expected_dps(m, h)
	return (float(m["max_hp"]) * dm) / maxf(0.001, float(h["max_hp"]) * dh)
