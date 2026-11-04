class_name HeroStats
extends RefCounted
## Характеристики героя по базе оригинала (tools/rappelz_db_reference.md, «Профессии»): 7 статов — база профессии
## (StatResource) плюс прирост за уровень профессии JLv (JobLevelBonus) отрезками: JLv 1–20 — первая строка
## прироста, 21–40 — вторая, 41–50 — третья (так считает сервер, GameContent::GetJobLevelBonus). Бродяга — первая
## профессия своей расы (Rogue / Guide / Stepper, JLv до 10); после выбора профессии её 10 JLv остаются в статах.
## JLv у нас не покупается за JP, а идёт от уровня героя: Бродяга — min(ур., 10), профессия — ⌈(ур. − 10) / 0.75⌉
## (JLv 40 на 40 ур., как требования умений древа: 10 + JLv × 0.75).
## Производные — формулы сервера (Stats): HP 30·Вын + 20·ур., атака 2·Сила + ур., защита 2·Вын + ур. и т. д.
## Оружие (атака, скорость, дальность, крит), броня и умения древа (HeroSkills.bonuses) накладывает Player поверх.

## Прирост статов Бродяги за JLv по расе [Сила, Вын, Ловк, Инт, Мдр, Метк, Удача] (Rogue / Guide / Stepper).
const ROOKIE := {
	"human": [0.5, 0.4, 0.4, 0.4, 0.5, 0.5, 0.2],
	"light_elf": [0.4, 0.5, 0.5, 0.5, 0.5, 0.4, 0.2],
	"dark_elf": [0.4, 0.4, 0.5, 0.5, 0.4, 0.5, 0.2],
}
## База Бродяги — по 10 каждого стата; JLv Бродяги, с которым выбирают профессию.
const ROOKIE_BASE := 10.0
const ROOKIE_JLV := 10
## Профессии: база статов и прирост за JLv тремя отрезками (1–20, 21–40, 41–50) — порядок как в Stats.STATS.
const JOBS := {
	"warrior": {"base": [20, 19, 16, 13, 12, 16, 10], "jlv": [[1, 0.9, 0.8, 0.6, 0.6, 0.8, 0.3], [1, 0.9, 0.8, 0.7, 0.7, 0.8, 0.3], [0.5, 0.5, 0.4, 0.4, 0.4, 0.5, 0.2]]},
	"shaman": {"base": [13, 17, 14, 20, 19, 13, 10], "jlv": [[0.7, 0.7, 0.7, 0.8, 0.9, 0.8, 0.3], [0.7, 0.9, 0.7, 1, 1, 0.7, 0.3], [0.4, 0.4, 0.4, 0.5, 0.5, 0.4, 0.2]]},
	"conjurer": {"base": [17, 18, 16, 15, 14, 16, 10], "jlv": [[0.8, 0.8, 0.8, 0.7, 0.7, 0.8, 0.3], [0.9, 1, 0.8, 0.8, 0.8, 0.8, 0.3], [0.5, 0.5, 0.4, 0.4, 0.4, 0.5, 0.2]]},
	"swordsman": {"base": [19, 20, 15, 13, 13, 16, 10], "jlv": [[0.9, 1, 0.7, 0.7, 0.7, 0.8, 0.3], [0.9, 1, 0.8, 0.7, 0.7, 0.8, 0.3], [0.5, 0.5, 0.4, 0.4, 0.4, 0.4, 0.2]]},
	"wizard": {"base": [13, 15, 14, 20, 20, 14, 10], "jlv": [[0.7, 0.8, 0.7, 1, 1, 0.7, 0.3], [0.7, 0.8, 0.7, 1, 1, 0.7, 0.3], [0.4, 0.4, 0.4, 0.5, 0.5, 0.4, 0.2]]},
	"beastmaster": {"base": [16, 16, 15, 17, 17, 15, 10], "jlv": [[0.2, 0.3, 0.3, 0.7, 0.7, 0.2, 0.3], [0.2, 0.3, 0.4, 1, 1, 0.4, 0.3], [0.2, 0.1, 0.3, 0.4, 0.4, 0.2, 0.2]]},
	"assassin": {"base": [16, 17, 19, 12, 13, 19, 10], "jlv": [[0.8, 0.8, 0.9, 0.6, 0.6, 0.9, 0.3], [0.8, 0.8, 1, 0.7, 0.7, 1, 0.3], [0.4, 0.5, 0.5, 0.4, 0.4, 0.5, 0.2]]},
	"neophyte": {"base": [14, 16, 13, 20, 20, 13, 10], "jlv": [[0.4, 0.5, 0.5, 0.9, 0.7, 0.6, 0.3], [0, 0.3, 0.3, 1, 0.6, 0.4, 0.3], [0.4, 0.5, 0.5, 0.5, 0.6, 0.5, 0.2]]},
	"adept": {"base": [16, 17, 14, 18, 18, 13, 10], "jlv": [[0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.3], [0.8, 0.8, 0.8, 0.9, 0.9, 0.7, 0.3], [0.4, 0.4, 0.4, 0.5, 0.5, 0.4, 0.2]]},
}
## Отрезки JLv прироста: [длина отрезка] — 20, 20, 10 (JLv 50 — предел 1-й профессии).
const JLV_SPANS := [20, 20, 10]
const JLV_MAX := 50
## Уровней героя на JLv профессии (как в требованиях умений древа).
const JLV_PER_LEVEL := 0.75
## Главный стат атаки: ближний бой — Сила, стрельба — Меткость, магия — Интеллект (в окне героя помечен звёздочкой).
const MAIN_STAT := {"melee": "str", "ranged": "dex", "magic": "int"}


## Есть ли у класса статы (у всех профессий и Бродяги).
static func has_stats(class_id: String) -> bool:
	return class_id == ClassData.WANDERER or JOBS.has(class_id)


## Уровень профессии (JLv) героя класса class_id на уровне lvl: Бродяга — до 10, профессия — от 11 ур.
static func job_level(class_id: String, lvl: int) -> int:
	var lv := maxi(1, lvl)
	if not JOBS.has(class_id):
		return mini(lv, ROOKIE_JLV)
	return clampi(ceili(float(lv - ROOKIE_JLV) / JLV_PER_LEVEL), 1, JLV_MAX)


## Прирост за jlv уровней профессии по трём отрезкам rows ([[7], [7], [7]]), стат i.
static func _gain(rows: Array, i: int, jlv: int) -> float:
	var left := jlv
	var g := 0.0
	for k in JLV_SPANS.size():
		if left <= 0 or k >= rows.size():
			break
		var n := mini(left, int(JLV_SPANS[k]))
		g += float((rows[k] as Array)[i]) * float(n)
		left -= n
	return g


## 7 статов героя класса class_id на уровне lvl: {"str": int, ...}. race — раса Бродяги (пусто — раса героя).
static func base_stats(class_id: String, lvl: int, race: String = "") -> Dictionary:
	var r := race if race != "" else Game.race_id
	var rookie: Array = ROOKIE.get(r, ROOKIE["human"])
	var job: Dictionary = JOBS.get(class_id, {})
	var jl := job_level(class_id, lvl)
	var res: Dictionary = {}
	for i in Stats.STATS.size():
		var v := 0.0
		if job.is_empty():
			v = ROOKIE_BASE + float(rookie[i]) * float(jl)
		else:
			v = float((job["base"] as Array)[i]) + float(rookie[i]) * float(ROOKIE_JLV) + _gain(job["jlv"], i, jl)
		res[Stats.STATS[i]] = int(floor(v))
	return res


## Уровень в формулах HP, MP, атак и защит — настоящий уровень героя (как у сервера).
static func formula_level(lvl: int) -> float:
	return float(maxi(lvl, 1))


## Характеристики героя класса class_id на уровне lvl без оружия, брони и умений.
## Ключи: stats (7 статов), max_hp, max_mp, patk (ближний бой), ratk (дальний), matk, def, mdef,
## acc (точность), avoid (уклонение), eva и crit (%, 0..100), aspd (% скорости атаки), hp_regen (HP в секунду).
## extra — прибавки к статам от умений ({"str": 4, …}: пассивные, переключаемые, усиления на время).
static func derived(class_id: String, lvl: int, extra: Dictionary = {}, race: String = "") -> Dictionary:
	var lv := maxi(lvl, 1)
	var s := base_stats(class_id, lv, race)
	for sk in extra:
		if s.has(sk):
			s[sk] = int(s[sk]) + roundi(float(extra[sk]))
	var lf := formula_level(lv)
	return {
		"stats": s,
		"max_hp": roundi(Stats.raw_hp(s, lf)),
		"max_mp": roundi(Stats.raw_mp(s, lf)),
		"patk": maxi(1, roundi(Stats.raw_patk(s, lf))),
		"ratk": maxi(1, roundi(Stats.raw_ratk(s, lf))),
		"matk": maxi(1, roundi(Stats.raw_matk(s, lf))),
		"def": roundi(Stats.raw_pdef(s, lf)),
		"mdef": roundi(Stats.raw_mdef(s, lf)),
		"acc": Stats.accuracy(s, lf),
		"avoid": Stats.avoidance(s, lf),
		"eva": Stats.evasion(s, lf),
		"crit": Stats.crit_chance(s),
		"aspd": Stats.attack_speed(s),
		"hp_regen": snappedf(Stats.raw_hp_regen(s, lf), 0.1),
	}
