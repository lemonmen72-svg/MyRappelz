class_name HeroStats
extends RefCounted
## Характеристики героя: те же 7 статов, что у питомцев (Сила, Выносливость, Ловкость, Интеллект, Мудрость,
## Меткость, Удача), и производные значения по общим формулам Stats (как в Rappelz: механика и числа —
## из вики, оформление своё). Пока статы есть у Бродяги (класс "assassin", ≈ Strider): базовые статы асуры
## после начальной профессии (Stepper, 10 уровней) плюс бонусы профессии Strider по её уровню.
## Уровень вики (уровень профессии) = наш уровень / 0.3 — та же шкала, что у требований умений древа.
## Калибровка: на 1 уровне HP, MP, атака, защита, уклонение и крит равны прежним числам класса
## (ClassData.CLASSES: hp, mp, atk, def, eva, crit), дальше растут по статам и уровню.
## Оружие (атака, скорость, дальность, крит) и умения древа (HeroSkills.bonuses) накладывает Player поверх.
## Остальные классы (не доступны игроку) — по-прежнему ClassData.stats_for.
## Таблицы и расчёт баланса — tools/rappelz_strider_reference.md.

## Вес уровня в формулах HP, MP, атак и защит героя. В Rappelz основную прибавку за уровень герою дают
## экипировка и её улучшение (у нас их пока нет), а бонусы профессии растут медленно (+1 к стату раз
## в 2–3 уровня профессии); с весом 2.5 рост за уровень близок к прежнему (ClassData *_lvl).
const LEVEL_WEIGHT := 2.5

## Опорные точки статов: [уровень профессии вики, [Str, Vit, Agi, Int, Wis, Dex, Luck]] — суммы из вики:
## асура после Stepper 1–10 (по 10 на старте + бонусы уровней) и бонусы Strider по уровню профессии
## (1-й уровень профессии — большой скачок; 41–50 — «перерождение» Strider). Дальше 50 — продолжение
## последнего отрезка.
const TABLES := {
	"assassin": [
		[1, [20, 21, 24, 17, 17, 24, 12]], [5, [22, 23, 26, 18, 18, 26, 12]],
		[10, [24, 25, 28, 20, 20, 28, 13]], [15, [26, 27, 31, 22, 22, 31, 14]],
		[20, [28, 29, 33, 23, 23, 33, 15]], [25, [30, 31, 36, 25, 25, 36, 16]],
		[30, [32, 33, 38, 27, 27, 38, 16]], [35, [34, 35, 40, 28, 28, 40, 17]],
		[40, [36, 37, 43, 30, 30, 43, 18]], [45, [38, 39, 45, 32, 32, 45, 19]],
		[50, [40, 42, 48, 34, 34, 48, 20]],
	],
}
## Главный стат атаки: ближний бой — Сила, арбалет — Меткость (в окне героя помечен звёздочкой).
const MAIN_STAT := {"melee": "str", "ranged": "dex"}


## Есть ли у класса таблица статов (иначе характеристики — ClassData.stats_for).
static func has_stats(class_id: String) -> bool:
	return TABLES.has(class_id)


## 7 статов героя класса class_id на нашем уровне lvl: {"str": int, ...}.
static func base_stats(class_id: String, lvl: int) -> Dictionary:
	var pts: Array = TABLES.get(class_id, TABLES["assassin"])
	var w := Stats.wiki_level(maxi(lvl, 1))
	var res: Dictionary = {}
	for i in Stats.STATS.size():
		res[Stats.STATS[i]] = roundi(Stats.interp(pts, i, w))
	return res


## Уровень в формулах HP, MP, атак и защит.
static func formula_level(lvl: int) -> float:
	return float(maxi(lvl, 1)) * LEVEL_WEIGHT


## Калибровка класса: множители hp, mp, atk (ближний бой), ratk (дальний), def и прибавки eva, crit (%),
## чтобы на 1 уровне получались числа ClassData (без оружия и умений).
static func calibration(class_id: String) -> Dictionary:
	var c := ClassData.cls(class_id)
	var s1 := base_stats(class_id, 1)
	var l1 := formula_level(1)
	var atk1 := float(c["atk"])
	return {
		"hp": float(c["hp"]) / Stats.raw_hp(s1, l1),
		"mp": float(c.get("mp", 0)) / Stats.raw_mp(s1, l1),
		"atk": atk1 / Stats.raw_patk(s1, l1),
		"ratk": atk1 / Stats.raw_ratk(s1, l1),
		"def": float(c["def"]) / Stats.raw_pdef(s1, l1),
		"eva": 100.0 * float(c.get("eva", 0.0)) - Stats.evasion(s1, 1.0),
		"crit": 100.0 * float(c.get("crit", 0.0)) - Stats.crit_chance(s1),
	}


## Характеристики героя класса class_id на уровне lvl без оружия и умений.
## Ключи: stats (7 статов), max_hp, max_mp, patk (ближний бой), ratk (дальний), matk, def, mdef,
## acc (точность), eva и crit (%, 0..100), aspd (% скорости атаки), hp_regen (HP в секунду, и в бою).
static func derived(class_id: String, lvl: int) -> Dictionary:
	var lv := maxi(lvl, 1)
	var s := base_stats(class_id, lv)
	var k := calibration(class_id)
	var lf := formula_level(lv)
	var kh := float(k["hp"])
	var ka := float(k["atk"])
	var kd := float(k["def"])
	return {
		"stats": s,
		"max_hp": roundi(kh * Stats.raw_hp(s, lf)),
		"max_mp": roundi(float(k["mp"]) * Stats.raw_mp(s, lf)),
		"patk": maxi(1, roundi(ka * Stats.raw_patk(s, lf))),
		"ratk": maxi(1, roundi(float(k["ratk"]) * Stats.raw_ratk(s, lf))),
		"matk": maxi(1, roundi(ka * Stats.raw_matk(s, lf))),
		"def": roundi(kd * Stats.raw_pdef(s, lf)),
		"mdef": roundi(kd * Stats.raw_mdef(s, lf)),
		"acc": Stats.accuracy(s, float(lv)),
		"eva": maxf(0.0, Stats.evasion(s, float(lv)) + float(k["eva"])),
		"crit": maxf(0.0, Stats.crit_chance(s) + float(k["crit"])),
		"aspd": Stats.attack_speed(s),
		"hp_regen": snappedf(kh * Stats.raw_hp_regen(s, float(lv)), 0.1),
	}
