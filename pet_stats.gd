class_name PetStats
extends RefCounted
## Характеристики питомцев (по образцу Rappelz, механика и числа — из вики, оформление своё).
## 7 статов: Сила, Выносливость, Ловкость, Интеллект, Мудрость, Меткость, Удача — по таблицам вики
## с опорными точками по уровню и стадии эволюции (между точками — линейная интерполяция).
## Уровень вики = наш уровень / 0.3 (у нас макс. 50 и эволюция на 15 и 30, в оригинале — 150 и 50/100).
## Из статов — производные значения нашего масштаба (общие формулы с героем — Stats, сборка — derived()).
## Чтобы бой не сломался, у каждого вида они калибруются так, что на 1 уровне равны прежним hp/atk/def
## из PetData.SPECIES.
## Исходные таблицы и расчёт баланса — tools/rappelz_pet_reference.md.

const STATS := Stats.STATS
const STAT_NAMES := Stats.STAT_NAMES
## Наш уровень → уровень вики: уровень / WIKI_LEVEL_SCALE.
const WIKI_LEVEL_SCALE := Stats.WIKI_LEVEL_SCALE
## Множитель урона крита питомца.
const CRIT_MULT := 1.5

## Опорные точки статов: по стадии эволюции — список [уровень вики, [Str, Vit, Agi, Int, Wis, Dex, Luck]].
## Стадия с одной точкой растёт с наклоном предыдущей стадии. Числа пантеры, черепахи, фазана и кентавра — из вики
## (Pantera, Tortus, Poultry, Kentauros; стадия улучшения 0) до обмена статов под нашу роль (SWAP).
## Кабан, волк и страж — своя раскладка тех же столбцов (у стража ×1.25: уникальный зверь).
const TABLES := {
	"panther": [
		[[1, [16, 14, 5, 10, 8, 7, 10]], [60, [38, 34, 12, 24, 19, 17, 10]]],
		[[60, [72, 64, 23, 45, 36, 31, 20]], [115, [91, 80, 29, 56, 46, 39, 20]]],
		[[150, [119, 104, 37, 74, 60, 52, 30]]],
	],
	"turtle": [
		[[1, [14, 16, 5, 10, 8, 7, 10]], [60, [34, 38, 12, 24, 19, 17, 10]]],
		[[60, [64, 72, 23, 45, 36, 31, 20]], [115, [80, 91, 29, 56, 46, 39, 20]]],
		[[150, [104, 119, 37, 74, 60, 52, 30]]],
	],
	"pheasant": [
		[[1, [14, 7, 5, 10, 8, 16, 10]], [60, [34, 17, 12, 24, 19, 38, 10]]],
		[[60, [64, 31, 23, 45, 36, 72, 20]], [115, [80, 39, 29, 56, 46, 91, 20]]],
		[[150, [104, 52, 37, 74, 60, 119, 30]]],
	],
	"boar": [
		[[1, [16, 14, 8, 5, 7, 10, 10]], [60, [38, 34, 19, 12, 17, 24, 10]]],
		[[60, [72, 64, 36, 23, 31, 45, 20]], [115, [91, 80, 46, 29, 39, 56, 20]]],
		[[150, [119, 104, 60, 37, 52, 74, 30]]],
	],
	"wolf": [
		[[1, [16, 8, 14, 5, 7, 10, 10]], [60, [38, 19, 34, 12, 17, 24, 10]]],
		[[60, [72, 36, 64, 23, 31, 45, 20]], [115, [91, 46, 80, 29, 39, 56, 20]]],
		[[150, [119, 60, 104, 37, 52, 74, 30]]],
	],
	# Кентавр — числа вики (Kentauros, существо 4-го тира: статы выше, чем у пантеры), без обмена: Сила главная
	"centaur": [
		[[1, [23, 17, 8, 12, 12, 8, 10]], [60, [55, 41, 19, 28, 28, 19, 10]]],
		[[60, [98, 72, 33, 50, 50, 33, 20]], [115, [130, 95, 45, 67, 67, 45, 20]]],
		[[150, [168, 124, 58, 87, 87, 58, 30]]],
	],
	"golem": [
		[[1, [18, 20, 6, 9, 10, 12, 12]], [60, [42, 48, 15, 21, 24, 30, 12]]],
		[[60, [80, 90, 29, 39, 45, 56, 25]], [115, [100, 114, 36, 49, 58, 70, 25]]],
		[[150, [130, 149, 46, 65, 75, 92, 38]]],
	],
}
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


## Уровень вики для нашего уровня.
static func wiki_level(lvl: int) -> float:
	return Stats.wiki_level(lvl)


## 7 статов вида на уровне (с обменом под роль, без бонусов умений): {"str": int, ...}.
static func base_stats(species: String, lvl: int) -> Dictionary:
	var tab: Array = TABLES.get(species, TABLES["boar"])
	var lv := clampi(lvl, 1, PetData.MAX_LEVEL)
	var st := PetData.stage_for(lv)
	var w := wiki_level(lv)
	var res: Dictionary = {}
	for i in STATS.size():
		res[STATS[i]] = roundi(_interp(tab, st, i, w))
	var sw: Array = SWAP.get(species, [])
	if sw.size() == 2:
		var a := String(sw[0])
		var b := String(sw[1])
		var t: int = res[a]
		res[a] = res[b]
		res[b] = t
	return res


## Значение стата i на стадии st для уровня вики w: линейно между опорными точками стадии,
## за краями — продолжение ближайшего отрезка; у стадии с одной точкой — наклон предыдущей стадии.
static func _interp(tab: Array, st: int, i: int, w: float) -> float:
	var pts: Array = tab[st]
	if pts.size() == 1:
		var p: Array = pts[0]
		var sl := 0.0
		if st > 0:
			sl = Stats.slope(tab[st - 1], i)
		return float(p[1][i]) + sl * (w - float(p[0]))
	return Stats.interp(pts, i, w)


# ---------- Производные значения ----------
# «Сырые» формулы — общие с героем (Stats.raw_*). L — наш уровень. Вид ведут: HP — Выносливость, физ. атаку —
# Сила, маг. атаку — Интеллект, лечение и MP — Мудрость, защиту — Выносливость и Ловкость, точность — Меткость,
# уклонение, крит и скорость атаки — Ловкость и Удача. Прибавка за уровень — как в Rappelz (HP ≈ 33·Vit + 20·Lv),
# пересчитанная на нашу шкалу уровней; подобрана расчётом (tools/rappelz_pet_reference.md).

## Главная атака роли: маг и лекарь — магическая (Интеллект), танк и боец — физическая (Сила).
static func is_magic(species: String) -> bool:
	var r := PetData.role(species)
	return r == "mage" or r == "healer"


## Множители калибровки вида: на 1 уровне HP, главная атака и защита = hp/atk/def из PetData.SPECIES.
static func calibration(species: String) -> Dictionary:
	var sp := PetData.get_species(species)
	var s1 := base_stats(species, 1)
	var main1 := Stats.raw_matk(s1, 1.0) if is_magic(species) else Stats.raw_patk(s1, 1.0)
	return {
		"hp": float(sp["hp"]) / Stats.raw_hp(s1, 1.0),
		"atk": float(sp["atk"]) / main1,
		"def": float(sp["def"]) / Stats.raw_pdef(s1, 1.0),
	}


## Все характеристики питомца вида species на уровне lvl с изученными умениями skills {id: уровень}
## и включёнными переключаемыми умениями toggles {id: true}.
## Ключи: stats (7 статов с бонусами), max_hp, max_mp, patk, matk, heal, atk (главная атака роли),
## def, mdef, acc (точность), eva и crit (%, 0..100), aspd (% скорости атаки), hp_regen и mp_regen (в секунду),
## speed, range, cd (перезарядка обычной атаки с учётом скорости), threat (шанс перехватить внимание зверя 0..1).
static func derived(species: String, lvl: int, skills: Dictionary = {}, toggles: Dictionary = {}) -> Dictionary:
	var sp := PetData.get_species(species)
	var lv := clampi(lvl, 1, PetData.MAX_LEVEL)
	var bon := PetSkills.bonuses(species, skills, toggles)
	var s := base_stats(species, lv)
	var all_up := int(bon.get("all_stats", 0))
	if all_up != 0:
		for key in STATS:
			s[key] = int(s[key]) + all_up
	var k := calibration(species)
	var kh := float(k["hp"])
	var ka := float(k["atk"])
	var kd := float(k["def"])
	var atk_mult := 1.0 + float(bon.get("atk_pct", 0.0))
	var def_mult := 1.0 + float(bon.get("def_pct", 0.0))
	# Сила редкости вида (MobData.power: базовые 1.0, «Обычный» волк 1.15…) — на HP, атаки, лечение и защиты
	var pw := MobData.power(species)
	kh *= pw
	ka *= pw
	kd *= pw
	var r := {"stats": s}
	var lf := float(lv)
	r["max_hp"] = roundi(kh * Stats.raw_hp(s, lf) * (1.0 + float(bon.get("hp_pct", 0.0))))
	# MP — новая величина, без калибровки: Мудрость ×2, Интеллект, 4 за уровень и запас 15
	r["max_mp"] = roundi(Stats.raw_mp(s, lf) * (1.0 + float(bon.get("mp_pct", 0.0))))
	r["patk"] = maxi(1, roundi(ka * Stats.raw_patk(s, lf) * atk_mult))
	r["matk"] = maxi(1, roundi(ka * Stats.raw_matk(s, lf) * atk_mult))
	r["heal"] = maxi(1, roundi(ka * Stats.raw_heal(s, lf)))
	r["atk"] = int(r["matk"]) if is_magic(species) else int(r["patk"])
	r["def"] = roundi(kd * Stats.raw_pdef(s, lf) * def_mult) + int(bon.get("def_flat", 0))
	# Звери пока бьют только физически: маг. защита показана на будущее
	r["mdef"] = roundi(kd * Stats.raw_mdef(s, lf) * def_mult)
	# Точность: шанс попасть по зверю — hit_chance()
	r["acc"] = Stats.accuracy(s, lf, float(bon.get("acc", 0.0)))
	r["eva"] = snappedf(Stats.evasion(s, lf) + float(bon.get("eva", 0.0)), 0.1)
	r["crit"] = snappedf(Stats.crit_chance(s) + float(bon.get("crit", 0.0)), 0.1)
	r["aspd"] = Stats.attack_speed(s)
	r["hp_regen"] = snappedf(kh * Stats.raw_hp_regen(s, lf) + float(bon.get("hp_regen", 0.0)), 0.1)
	r["mp_regen"] = snappedf(Stats.mp_regen(s, lf) + float(bon.get("mp_regen", 0.0)), 0.1)
	r["threat"] = float(bon.get("threat", 0.0))
	r["speed"] = float(sp["speed"])
	r["range"] = float(sp["range"])
	r["cd"] = float(sp["cd"]) * 100.0 / float(r["aspd"])
	return r


## Шанс попасть обычной атакой по зверю уровня mob_level при точности acc (0.75..1.0):
## 95% против зверя «своего» уровня, ±1% за единицу точности.
static func hit_chance(acc: int, mob_level: int) -> float:
	return Stats.hit_chance(acc, mob_level)


## Очки умений (JP) по умолчанию для питомца уровня lvl (старые сохранения, новые питомцы).
static func default_jp(lvl: int) -> int:
	return PetSkills.JP_START + PetSkills.JP_PER_LEVEL * (clampi(lvl, 1, PetData.MAX_LEVEL) - 1)
