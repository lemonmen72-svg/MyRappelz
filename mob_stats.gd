class_name MobStats
extends RefCounted
## Характеристики зверей мира (решение Максима): тот же набор из 7 статов, что у героя и питомцев (Сила,
## Выносливость, Ловкость, Интеллект, Мудрость, Меткость, Удача), и производные по общим формулам Stats.
## • Статы по уровню: профиль вида (доли статов) × средний стат героя того же уровня (HeroStats, REF_CLASS) —
##   звери растут вместе с героем. Профиль вида питомца — его статы 1-го уровня из таблиц PetStats с обменом
##   под роль (пантера — Интеллект, фазан — Мудрость, волк — Ловкость, черепаха — Выносливость, кентавр — Сила);
##   у рыб и анатем — свои профили PROFILES (рыбы — Ловкость, анатемы — Сила и Ловкость при низкой Выносливости).
## • Производные: HP, атака (у мага и лекаря — магическая), физ. и маг. защита, точность, избегание, уклонение,
##   крит, скорость атаки — формулы Stats с калибровкой героя REF_CLASS (HeroStats.calibration) × множители зверей
##   HP_K, ATK_K (+ATK_FLAT — «природное оружие», ×(1 + ATK_LVL·(L − 1)) — рост по уровню), DEF_K, MDEF_K.
##   Профиль меняет облик (танк — HP и защита, маг — урон), но не силу: HP и атака каждого вида нормируются
##   к зверю с ровным профилем (с учётом скорости атаки).
## • Калибровка (решение Максима: «персонажа равным монстру равного уровня, и HP монстров ×3»): без прибавки HP
##   зверь своего уровня равен герою по «эффективной силе» HP × урон в секунду (Combat.power_ratio ≈ 0.96–1.04 у
##   Бродяги с учебным мечом на всех уровнях 1–30; ATK_FLAT держит низкие уровни, ATK_LVL — высокие, где герой быстрее
##   бьёт от Ловкости), затем HP всех зверей × MOB_HP_MULT (3): зверь своего уровня ≈ втрое сильнее героя без умений,
##   питомца и зелий — бой 1×1 проигрышный, с питомцем — уверенная победа. Вход новичка: у зверей 1–4 ур. прибавка
##   HP меньше (MOB_HP_START), иначе Бродяга 1-го ур. без питомца и умений не одолел бы ни одного зверя.
##   Расчёт — tools/rappelz_strider_reference.md, раздел «Звери мира».
## • Поверх: сила редкости MobData.power (HP, атака, опыт), защита вида MobData.defense (анатемы — ниже), темп ударов
##   MobData.attack_cd; боссы — BOSS_* (HP, атака, защита, опыт, размер).
## • Опыт за зверя — base_xp(уровень) × сила; кривая опыта героя — Game.xp_to_next (KILLS_*: сколько зверей своего
##   уровня на уровень).

## Герой-ориентир калибровки (статы по уровню и множители HeroStats.calibration).
const REF_CLASS := "wanderer"
## Множители зверей к калибровке героя: HP, атака (+ прибавка ATK_FLAT, рост ATK_LVL за уровень), физ. и маг. защита.
## С ними зверь своего уровня равен герою (до MOB_HP_MULT).
const HP_K := 1.0
const ATK_K := 1.765
const ATK_FLAT := 9.0
const ATK_LVL := 0.003
## HP всех зверей мира (и боссов) × MOB_HP_MULT — решение Максима; одно место для настройки.
const MOB_HP_MULT := 3.0
## Вход новичка: множитель HP зверей 1-го, 2-го, 3-го, 4-го ур. вместо MOB_HP_MULT (Бродяга без питомца и умений:
## зверь 1-го ур. ему равен, дальше всё тяжелее; луга новичков 1–3 ур.). Пустой массив — ×MOB_HP_MULT с 1-го ур.
const MOB_HP_START := [1.0, 1.5, 2.0, 2.5]
const DEF_K := 1.0
const MDEF_K := 0.75
## Профили статов видов без питомца [Str, Vit, Agi, Int, Wis, Dex, Luck] (доли; масштаб задаёт уровень).
const PROFILES := {
	"flyfish": [12, 9, 18, 8, 8, 14, 10],
	"flyfish_sail": [13, 9, 18, 8, 8, 14, 10],
	"flyfish_drake": [14, 11, 16, 10, 9, 13, 10],
	"anathema": [18, 8, 15, 6, 6, 12, 9],
	"anathema_blade": [19, 8, 16, 6, 6, 12, 9],
	"anathema_chief": [19, 10, 15, 7, 7, 12, 10],
}
## Боссы: HP, атака, защита, опыт и размер модели поверх зверя 3-й стадии того же уровня (и силы «Уникального»).
const BOSS_HP := 1.8
const BOSS_ATK := 1.3
const BOSS_DEF := 1.15
const BOSS_XP := 5.0
const BOSS_SCALE := 1.35
## Модель дикого зверя по уровню: с 12 ур. — 2-я стадия эволюции (<вид>_2), с 22 — 3-я (<вид>_3), если файл есть.
const WILD_STAGE_LEVELS := [1, 12, 22]
## Опыт за зверя своего уровня: XP_BASE + XP_LVL·L + XP_SQ·L².
const XP_BASE := 8.0
const XP_LVL := 4.0
const XP_SQ := 0.15
## Сколько зверей своего уровня нужно на уровень героя: KILLS_BASE + KILLS_LVL·L, после KILLS_HIGH_FROM ур. —
## ещё KILLS_HIGH·(L − KILLS_HIGH_FROM)² (Game.xp_to_next).
const KILLS_BASE := 5.0
const KILLS_LVL := 1.5
const KILLS_HIGH := 0.25
const KILLS_HIGH_FROM := 20


## Профиль статов вида (7 чисел).
static func profile(species: String) -> Array:
	if PROFILES.has(species):
		return PROFILES[species]
	if PetStats.TABLES.has(species):
		var s := PetStats.base_stats(species, 1)
		var res: Array = []
		for k in Stats.STATS:
			res.append(float(s[k]))
		return res
	return [1, 1, 1, 1, 1, 1, 1]


## Главная атака вида магическая (маг и лекарь среди видов питомцев).
static func is_magic(species: String) -> bool:
	return PetData.SPECIES.has(species) and PetStats.is_magic(species)


## 7 статов вида на уровне lvl: профиль × средний стат героя-ориентира этого уровня.
static func stats(species: String, lvl: int) -> Dictionary:
	return _scaled(profile(species), lvl)


static func _scaled(pr: Array, lvl: int) -> Dictionary:
	var h := HeroStats.base_stats(REF_CLASS, maxi(1, lvl))
	var mean := 0.0
	for k in Stats.STATS:
		mean += float(h[k])
	mean /= float(Stats.STATS.size())
	var pm := 0.0
	for v in pr:
		pm += float(v)
	pm = maxf(0.001, pm / float(pr.size()))
	var res: Dictionary = {}
	for i in Stats.STATS.size():
		res[Stats.STATS[i]] = maxi(1, roundi(float(pr[i]) / pm * mean))
	return res


## Нормировка силы вида к ровному профилю: √(HP·атака·скорость ровного / то же у вида) на уровне lvl.
static func _norm(s: Dictionary, magic: bool, lvl: int) -> float:
	var lf := HeroStats.formula_level(lvl)
	var n := _scaled([1, 1, 1, 1, 1, 1, 1], lvl)
	var main_s := Stats.raw_matk(s, lf) if magic else Stats.raw_patk(s, lf)
	var pn := Stats.raw_hp(n, lf) * Stats.raw_patk(n, lf) * float(Stats.attack_speed(n))
	var ps := Stats.raw_hp(s, lf) * main_s * float(Stats.attack_speed(s))
	return sqrt(pn / maxf(0.001, ps))


## Модель дикого зверя вида type_id на уровне lvl: стадия эволюции 0..2 (у босса — своя из MobData "stage").
static func stage_for(type_id: String, lvl: int) -> int:
	if MobData.is_boss(type_id):
		return int(MobData.get_type(type_id).get("stage", 0))
	if not PetData.SPECIES.has(type_id):
		return 0
	var st := 0
	for i in WILD_STAGE_LEVELS.size():
		if lvl >= int(WILD_STAGE_LEVELS[i]):
			st = i
	return st


## id модели зверя (вид или модель стадии «panther_3», если её файл есть).
static func model_id(type_id: String, lvl: int) -> String:
	return CreatureAsset.model_for(MobData.species_of(type_id), stage_for(type_id, lvl))


## Масштаб модели: размер вида × размер стадии эволюции (PetData.STAGES) × размер босса.
static func body_scale(type_id: String, lvl: int) -> float:
	var d := MobData.get_type(type_id)
	var s := float(d.get("scale", 1.0))
	var st := stage_for(type_id, lvl)
	if st > 0 and st < PetData.STAGES.size():
		s *= float((PetData.STAGES[st] as Dictionary)["scale"])
	if MobData.is_boss(type_id):
		s *= BOSS_SCALE
	return s


## Множитель HP зверя уровня lvl: MOB_HP_MULT, у зверей 1–4 ур. — меньше (MOB_HP_START).
static func hp_mult(lvl: int) -> float:
	var l := maxi(1, lvl)
	if l <= MOB_HP_START.size():
		return float(MOB_HP_START[l - 1])
	return MOB_HP_MULT


## Опыт за зверя своего уровня lvl (до силы редкости и разницы уровней).
static func base_xp(lvl: int) -> float:
	var l := float(maxi(1, lvl))
	return XP_BASE + XP_LVL * l + XP_SQ * l * l


## Опыт до следующего уровня героя уровня lvl: зверей своего уровня на уровень × base_xp (Game.xp_to_next).
## 1 → 10 ур. ≈ 110 зверей своего уровня, 10 → 20 ≈ 270. С HP зверей ×3 опыт не менялся: с питомцем (он теперь на
## равных со зверем) до 10 ур. ≈ 1 ч, до 20 ≈ 3.4–3.8 ч (модель — справка «Звери мира»).
static func xp_to_next(lvl: int) -> int:
	var l := maxi(1, lvl)
	var kills := KILLS_BASE + KILLS_LVL * float(l) + KILLS_HIGH * pow(float(maxi(0, l - KILLS_HIGH_FROM)), 2.0)
	return roundi(base_xp(l) * kills)


## Все характеристики зверя type_id на уровне lvl.
## Ключи: stats (7 статов), max_hp, atk (главная атака), patk, matk, magic (атака магическая), def, mdef,
## acc (точность), avoid (избегание), eva и crit (%), aspd (% скорости атаки), attack_cd (с между ударами), xp.
static func derived(type_id: String, lvl: int) -> Dictionary:
	var lv := maxi(1, lvl)
	var sp := MobData.species_of(type_id)
	var s := stats(sp, lv)
	var magic := is_magic(sp)
	var lf := HeroStats.formula_level(lv)
	var k := HeroStats.calibration(REF_CLASS)
	var n := _norm(s, magic, lv)
	var pw := MobData.power(type_id)
	var boss := MobData.is_boss(type_id)
	var dm := MobData.defense(type_id)
	var hp_m := HP_K * hp_mult(lv) * n * pw * (BOSS_HP if boss else 1.0)
	var atk_m := pw * (BOSS_ATK if boss else 1.0)
	var def_m := DEF_K * dm * (BOSS_DEF if boss else 1.0)
	var ka := float(k["atk"]) * ATK_K * n * (1.0 + ATK_LVL * float(lv - 1))
	var patk := maxi(1, roundi((ka * Stats.raw_patk(s, lf) + ATK_FLAT) * atk_m))
	var matk := maxi(1, roundi((ka * Stats.raw_matk(s, lf) + ATK_FLAT) * atk_m))
	var aspd := Stats.attack_speed(s)
	return {
		"stats": s,
		"max_hp": maxi(1, roundi(float(k["hp"]) * Stats.raw_hp(s, lf) * hp_m)),
		"patk": patk,
		"matk": matk,
		"atk": matk if magic else patk,
		"magic": magic,
		"def": roundi(float(k["def"]) * Stats.raw_pdef(s, lf) * def_m),
		"mdef": roundi(float(k["def"]) * MDEF_K * Stats.raw_mdef(s, lf) * def_m),
		"acc": Stats.accuracy(s, float(lv)),
		"avoid": Stats.avoidance(s, float(lv)),
		"eva": snappedf(Stats.evasion(s, float(lv)), 0.1),
		"crit": snappedf(Stats.crit_chance(s), 0.1),
		"aspd": aspd,
		"attack_cd": MobData.attack_cd(type_id) * 100.0 / float(aspd),
		"xp": maxi(1, roundi(base_xp(lv) * pw * (BOSS_XP if boss else 1.0))),
	}
