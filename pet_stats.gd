class_name PetStats
extends RefCounted
## Характеристики питомцев по базе оригинала (tools/rappelz_db_reference.md, «Существа»): 7 статов формы —
## база формы (StatResource) + прирост формы (CreatureLevelBonus) × уровень (так считает сервер:
## GameContent::GetSummonLevelBonus × уровень, StructSummon::applyJobLevelBonus); производные — общие формулы
## сервера (Stats) с множителем статов существа FCM 0.7 (StructSummon::GetFCM). Формы — 1-я (с 1 ур.), 2-я и 3-я
## (эволюция у Учителя Кирка с 50 и 100 ур., PetData.EVOLVE_LEVELS), сверх-эволюция — + доля ко всем статам
## (PetData.super_bonus). Роли у нас свои: статы пантеры, фазана и волка переставлены под роль (SWAP).

const STATS := Stats.STATS
const STAT_NAMES := Stats.STAT_NAMES
## Множитель урона крита питомца (сила крита сервера 80 — как у всех).
const CRIT_MULT := 1.8
## Множитель статов существа в формулах (FCM сервера).
const FCM := 0.7

## Формы вида: {"base": 7 статов, "grow": прирост за уровень} — порядок Stats.STATS (Сила, Вын, Ловк, Инт, Мдр,
## Метк, Удача). У 3-й формы в базе прироста нет (до 100 ур. у нас не дойти) — берём прирост 2-й.
const FORMS := {
	"panther": [{"base": [16, 14, 5, 10, 8, 7, 10], "grow": [0.367, 0.334, 0.117, 0.234, 0.184, 0.167, 0]}, {"base": [69, 61, 22, 43, 35, 30, 20], "grow": [0.334, 0.288, 0.107, 0.197, 0.167, 0.137, 0]}, {"base": [119, 104, 37, 74, 60, 52, 30], "grow": [0.334, 0.288, 0.107, 0.197, 0.167, 0.137, 0]}],
	"turtle": [{"base": [14, 16, 5, 10, 8, 7, 10], "grow": [0.334, 0.367, 0.117, 0.234, 0.184, 0.167, 0]}, {"base": [61, 69, 22, 43, 35, 30, 20], "grow": [0.288, 0.334, 0.107, 0.197, 0.167, 0.137, 0]}, {"base": [104, 119, 37, 74, 60, 52, 30], "grow": [0.288, 0.334, 0.107, 0.197, 0.167, 0.137, 0]}],
	"pheasant": [{"base": [14, 7, 5, 10, 8, 16, 10], "grow": [0.334, 0.167, 0.117, 0.234, 0.184, 0.367, 0]}, {"base": [61, 30, 22, 43, 35, 69, 20], "grow": [0.288, 0.137, 0.107, 0.197, 0.167, 0.334, 0]}, {"base": [104, 52, 37, 74, 60, 119, 30], "grow": [0.288, 0.137, 0.107, 0.197, 0.167, 0.334, 0]}],
	"wolf": [{"base": [14, 10, 12, 8, 9, 7, 10], "grow": [0.367, 0.2, 0.317, 0.184, 0.2, 0.15, 0]}, {"base": [64, 43, 59, 31, 39, 29, 20], "grow": [0.622, 0.304, 0.304, 0.197, 0.197, 0.182, 0]}, {"base": [134, 81, 101, 56, 66, 52, 30], "grow": [0.622, 0.304, 0.304, 0.197, 0.197, 0.182, 0]}],
	# Скелет и Спрут (0.37): StatResource 2401–2403, 3501–3503, CreatureLevelBonus тех же id
	"skeleton": [{"base": [19, 14, 7, 10, 9, 6, 10], "grow": [0.45, 0.317, 0.167, 0.234, 0.217, 0.134, 0]}, {"base": [82, 60, 30, 43, 39, 26, 20], "grow": [0.41, 0.288, 0.137, 0.197, 0.182, 0.122, 0]}, {"base": [140, 103, 52, 74, 67, 44, 30], "grow": [0.41, 0.288, 0.137, 0.197, 0.182, 0.122, 0]}],
	"octopus": [{"base": [13, 9, 10, 16, 11, 6, 10], "grow": [0.217, 0.2, 0.234, 0.417, 0.3, 0.134, 0]}, {"base": [50, 39, 43, 76, 44, 26, 20], "grow": [0.204, 0.186, 0.204, 0.408, 0.278, 0.13, 0]}, {"base": [97, 69, 74, 126, 71, 43, 30], "grow": [0.204, 0.186, 0.204, 0.408, 0.278, 0.13, 0]}],
	"centaur": [{"base": [23, 17, 8, 12, 12, 8, 10], "grow": [0.534, 0.4, 0.184, 0.267, 0.267, 0.184, 0]}, {"base": [98, 72, 34, 51, 51, 34, 20], "grow": [0.485, 0.349, 0.167, 0.243, 0.243, 0.167, 0]}, {"base": [168, 124, 58, 87, 87, 58, 30], "grow": [0.485, 0.349, 0.167, 0.243, 0.243, 0.167, 0]}],
}
## Ушедшие из мира виды (кабан, страж — питомцы старых сохранений до перевода): формы волка и черепахи.
const FORM_ALIAS := {"boar": "wolf", "golem": "turtle"}
## Обмен статов под нашу роль: пантера у нас маг (Сила ↔ Интеллект: урон от Интеллекта),
## фазан — лекарь (Меткость ↔ Мудрость: лечение от Мудрости). Черепаха — танк, как в оригинале.
## Волк — боец-«существо ловкости» (Сила ↔ Ловкость): Ловкость главная — скорость атаки, уклонение, крит.
const SWAP := {"panther": ["str", "int"], "pheasant": ["dex", "wis"], "wolf": ["str", "agi"]}
## Названия производных значений (порядок показа в окне существа).
const DERIVED_NAMES := [
	["max_hp", "Макс. HP"], ["max_mp", "Макс. MP"], ["patk", "Физ. атака"], ["matk", "Маг. атака"],
	["heal", "Сила лечения"], ["def", "Физ. защита"], ["mdef", "Маг. защита"], ["acc", "Точность"],
	["eva", "Уклонение"], ["crit", "Шанс крита"], ["aspd", "Скорость атаки"], ["hp_regen", "Восст. HP"],
	["mp_regen", "Восст. MP"],
]


## Форма вида (словарь FORMS) стадии stage.
static func form(species: String, stage: int) -> Dictionary:
	var fs: Array = FORMS.get(FORM_ALIAS.get(species, species), FORMS["wolf"])
	return fs[clampi(stage, 0, fs.size() - 1)]


## 7 статов вида на уровне lvl в форме stage (с обменом под роль, без бонусов умений): {"str": int, ...}.
## sup — прибавка сверх-эволюции (доля, PetData.super_bonus).
static func base_stats(species: String, lvl: int, stage: int = 0, sup: float = 0.0) -> Dictionary:
	var f := form(species, stage)
	var lv := clampi(lvl, 1, PetData.MAX_LEVEL)
	var res: Dictionary = {}
	for i in STATS.size():
		var v := float((f["base"] as Array)[i]) + float((f["grow"] as Array)[i]) * float(lv)
		res[STATS[i]] = int(floor(v * (1.0 + sup)))
	var sw: Array = SWAP.get(species, [])
	if sw.size() == 2:
		var x := String(sw[0])
		var y := String(sw[1])
		var t: int = res[x]
		res[x] = res[y]
		res[y] = t
	return res


# ---------- Производные значения ----------
# Формулы сервера (Stats) с FCM существа: HP 30·Вын·0.7 + 20·L, атака 2·Сила·0.7 + L, маг. атака 2·Инт·0.7 + L,
# защиты 2·Вын/Мдр·0.7 + L, точность 0.5·Метк·0.7 + L, уклонение 0.5·Ловк·0.7 + L, крит 0.2·Удача + 3 %.

## Главная атака роли: маг и лекарь — магическая (Интеллект), танк и боец — физическая (Сила).
static func is_magic(species: String) -> bool:
	var r := PetData.role(species)
	return r == "mage" or r == "healer"


## Все характеристики питомца вида species на уровне lvl с изученными умениями skills {id: уровень}
## и включёнными переключаемыми умениями toggles {id: true}; stage — форма (0..2), sup — сверх-эволюция (доля).
## Ключи: stats (7 статов с бонусами), max_hp, max_mp, patk, matk, heal, atk (главная атака роли),
## def, mdef, acc (точность), avoid (уклонение), eva и crit (%, 0..100), aspd (% скорости атаки), hp_regen и mp_regen
## (в секунду), speed, range, cd (перезарядка обычной атаки с учётом скорости), threat (шанс перехватить внимание 0..1).
## extra — прибавки 7 статов от героя ({"str": 3, …}: ауры и усиления «питомцевых» профессий, PetBond.stat_extra).
static func derived(species: String, lvl: int, skills: Dictionary = {}, toggles: Dictionary = {}, extra: Dictionary = {},
		stage: int = 0, sup: float = 0.0) -> Dictionary:
	var sp := PetData.get_species(species)
	var lv := clampi(lvl, 1, PetData.MAX_LEVEL)
	var bon := PetSkills.bonuses(species, skills, toggles)
	var s := base_stats(species, lv, stage, sup)
	var all_up := int(bon.get("all_stats", 0))
	for key in STATS:
		# «Дар предков» — все, «Благословение …» — своя характеристика
		var up := all_up + int(bon.get("stat_" + String(key), 0))
		if up != 0:
			s[key] = int(s[key]) + up
	# Статы от героя (PetBond: ауры, пассивки, усиления на время)
	for key in extra:
		if s.has(key):
			s[key] = int(s[key]) + roundi(float(extra[key]))
	var atk_mult := 1.0 + float(bon.get("atk_pct", 0.0))
	var def_mult := 1.0 + float(bon.get("def_pct", 0.0))
	var r := {"stats": s}
	var lf := float(lv)
	r["max_hp"] = roundi(Stats.raw_hp(s, lf, FCM) * (1.0 + float(bon.get("hp_pct", 0.0))))
	r["max_mp"] = roundi(Stats.raw_mp(s, lf, FCM) * (1.0 + float(bon.get("mp_pct", 0.0))))
	r["patk"] = maxi(1, roundi(Stats.raw_patk(s, lf, FCM) * atk_mult))
	r["matk"] = maxi(1, roundi(Stats.raw_matk(s, lf, FCM) * atk_mult))
	r["heal"] = maxi(1, roundi(Stats.raw_heal(s, lf, FCM)))
	r["atk"] = int(r["matk"]) if is_magic(species) else int(r["patk"])
	r["def"] = roundi(Stats.raw_pdef(s, lf, FCM) * def_mult) + int(bon.get("def_flat", 0))
	r["mdef"] = roundi(Stats.raw_mdef(s, lf, FCM) * def_mult)
	# Точность против уклонения зверя и уровни — Combat.hit_chance
	r["acc"] = Stats.accuracy(s, lf, float(bon.get("acc", 0.0)), FCM)
	r["avoid"] = Stats.avoidance(s, lf, FCM)
	r["eva"] = snappedf(Stats.evasion(s, lf) + float(bon.get("eva", 0.0)), 0.1)
	r["crit"] = snappedf(Stats.crit_chance(s) + float(bon.get("crit", 0.0)), 0.1)
	r["aspd"] = roundi(Stats.attack_speed(s) * (1.0 + float(bon.get("aspd_pct", 0.0))))
	r["hp_regen"] = snappedf(Stats.raw_hp_regen(s, lf) * FCM + float(bon.get("hp_regen", 0.0)), 0.1)
	r["mp_regen"] = snappedf(Stats.mp_regen(s, lf) + float(bon.get("mp_regen", 0.0)), 0.1)
	r["threat"] = float(bon.get("threat", 0.0))
	r["veil"] = float(bon.get("veil", 0.0))
	r["speed"] = float(sp["speed"])
	r["range"] = float(sp["range"])
	r["cd"] = float(sp["cd"]) * 100.0 / float(r["aspd"])
	return r


## Профиль питомца вида species уровня lvl для оценки силы (Combat.power_ratio против зверя мира; как
## Combat.profile_of у призванного питомца).
static func combat_profile(species: String, lvl: int, skills: Dictionary = {}, toggles: Dictionary = {}, stage: int = 0) -> Dictionary:
	var d := derived(species, lvl, skills, toggles, {}, stage)
	return {
		"level": clampi(lvl, 1, PetData.MAX_LEVEL), "max_hp": int(d["max_hp"]), "atk": int(d["atk"]),
		"magic": is_magic(species), "def": int(d["def"]), "mdef": int(d["mdef"]), "acc": int(d["acc"]),
		"avoid": int(d["avoid"]), "eva": float(d["eva"]) / 100.0, "crit": float(d["crit"]) / 100.0,
		"interval": float(d["cd"]), "crit_mult": CRIT_MULT, "block": 0.0,
	}


## Очки умений (JP) по умолчанию для питомца уровня lvl (старые сохранения, новые питомцы).
static func default_jp(lvl: int) -> int:
	return PetSkills.JP_START + PetSkills.JP_PER_LEVEL * (clampi(lvl, 1, PetData.MAX_LEVEL) - 1)
