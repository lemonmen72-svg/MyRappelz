class_name Stats
extends RefCounted
## Общие формулы характеристик героя (HeroStats) и питомцев (PetStats), по образцу Rappelz
## (механика и числа — из вики, оформление своё). 7 статов: Сила, Выносливость, Ловкость, Интеллект,
## Мудрость, Меткость, Удача. Из них — производные значения нашего масштаба: здесь «сырые» формулы,
## а HeroStats и PetStats калибруют их так, чтобы на 1 уровне получались прежние HP, атака и защита.
## Опорные точки статов по уровню и линейная интерполяция между ними — тоже здесь.
## Справка: tools/rappelz_pet_reference.md (питомцы), tools/rappelz_strider_reference.md (герой).

const STATS := ["str", "vit", "agi", "int", "wis", "dex", "luck"]
const STAT_NAMES := {
	"str": "Сила", "vit": "Выносливость", "agi": "Ловкость", "int": "Интеллект",
	"wis": "Мудрость", "dex": "Меткость", "luck": "Удача",
}
## Наш уровень → уровень вики: уровень / WIKI_LEVEL_SCALE (у героя — уровень профессии, у питомца — его уровень).
const WIKI_LEVEL_SCALE := 0.3


## Уровень вики для нашего уровня.
static func wiki_level(lvl: int) -> float:
	return float(lvl) / WIKI_LEVEL_SCALE


# ---------- Опорные точки ----------

## Значение стата i по списку опорных точек pts ([уровень вики, [Str, Vit, Agi, Int, Wis, Dex, Luck]], по
## возрастанию) для уровня вики w: линейно между соседними точками, за краями — продолжение крайнего отрезка.
## Одна точка — её значение.
static func interp(pts: Array, i: int, w: float) -> float:
	if pts.is_empty():
		return 0.0
	if pts.size() == 1:
		return float(pts[0][1][i])
	var k := 0
	while k < pts.size() - 2 and w > float(pts[k + 1][0]):
		k += 1
	var a: Array = pts[k]
	var b: Array = pts[k + 1]
	var wa := float(a[0])
	var wb := float(b[0])
	return float(a[1][i]) + (float(b[1][i]) - float(a[1][i])) * (w - wa) / (wb - wa)


## Наклон стата i (на 1 уровень вики) по первому и последнему из опорных точек pts.
static func slope(pts: Array, i: int) -> float:
	if pts.size() < 2:
		return 0.0
	var a: Array = pts[0]
	var b: Array = pts[pts.size() - 1]
	return (float(b[1][i]) - float(a[1][i])) / (float(b[0]) - float(a[0]))


# ---------- «Сырые» формулы (до калибровки) ----------
# s — 7 статов, lvl — уровень в формуле (у питомца — наш уровень, у героя — с весом HeroStats.LEVEL_WEIGHT).
# Как в Rappelz: HP ведёт Выносливость (там 33·Vit + 20·Lv), физ. атаку ближнего боя — Сила (2.8·Str + Lv),
# дальнего — Меткость и Ловкость (2.2·Dex + 1.2·Agi + Lv), маг. атаку — Интеллект, MP и маг. защиту — Мудрость,
# физ. защиту — Выносливость, точность — Меткость, уклонение и скорость атаки — Ловкость, крит — Удача.
# Коэффициенты пересчитаны на нашу шкалу уровней (tools/rappelz_pet_reference.md).

static func raw_hp(s: Dictionary, lvl: float) -> float:
	return 2.0 * float(s["vit"]) + 3.0 * lvl


static func raw_patk(s: Dictionary, lvl: float) -> float:
	return float(s["str"]) + 0.2 * float(s["dex"]) + 4.0 * lvl


## Физ. атака дальнего боя (лук, арбалет): Rappelz 2.2·Dex + 1.2·Agi в масштабе raw_patk (÷ 2.8).
static func raw_ratk(s: Dictionary, lvl: float) -> float:
	return 0.79 * float(s["dex"]) + 0.43 * float(s["agi"]) + 4.0 * lvl


static func raw_matk(s: Dictionary, lvl: float) -> float:
	return float(s["int"]) + 0.2 * float(s["wis"]) + 4.0 * lvl


static func raw_heal(s: Dictionary, lvl: float) -> float:
	return float(s["wis"]) + 0.2 * float(s["int"]) + 4.0 * lvl


static func raw_pdef(s: Dictionary, lvl: float) -> float:
	return 0.5 * float(s["vit"]) + 0.2 * float(s["agi"]) + 3.0 * lvl


static func raw_mdef(s: Dictionary, lvl: float) -> float:
	return 0.5 * float(s["wis"]) + 0.2 * float(s["int"]) + 3.0 * lvl


## MP: Мудрость ×2, Интеллект, 4 за уровень и запас 15.
static func raw_mp(s: Dictionary, lvl: float) -> float:
	return 2.0 * float(s["wis"]) + float(s["int"]) + 4.0 * lvl + 15.0


## Восстановление HP в секунду (до калибровки по HP).
static func raw_hp_regen(s: Dictionary, lvl: float) -> float:
	return 0.01 * float(s["vit"]) + 0.01 * lvl


## Восстановление MP в секунду.
static func mp_regen(s: Dictionary, lvl: float) -> float:
	return 0.5 + 0.05 * float(s["wis"]) + 0.02 * lvl


## Точность (шанс попасть — hit_chance), bonus — от умений.
static func accuracy(s: Dictionary, lvl: float, bonus: float = 0.0) -> int:
	return roundi(0.5 * float(s["dex"]) + 1.5 * lvl + 5.0 + bonus)


## Уклонение, % (без бонусов умений).
static func evasion(s: Dictionary, lvl: float) -> float:
	return 0.1 * float(s["agi"]) + 0.05 * float(s["luck"]) + 0.05 * lvl


## Шанс крита, % (без бонусов умений).
static func crit_chance(s: Dictionary) -> float:
	return 2.0 + 0.1 * float(s["luck"]) + 0.05 * float(s["agi"])


## Скорость атаки, % (100 — обычная; перезарядка атаки делится на неё / 100).
static func attack_speed(s: Dictionary) -> int:
	return roundi(100.0 * (1.0 + 0.002 * float(s["agi"])))


## Шанс попасть обычной атакой по зверю уровня mob_level при точности acc (0.75..1.0):
## 95% против зверя «своего» уровня, ±1% за единицу точности.
static func hit_chance(acc: int, mob_level: int) -> float:
	return clampf(0.95 + 0.01 * float(acc - (8 + 2 * mob_level)), 0.75, 1.0)
