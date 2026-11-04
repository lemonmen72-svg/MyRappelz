class_name Stats
extends RefCounted
## Общие формулы характеристик героя (HeroStats), питомцев (PetStats) и зверей мира (MobStats) — формулы сервера
## оригинала (StructCreature::calcAttribute, CalculateStat; tools/rappelz_db_reference.md, «Формулы сервера»).
## 7 статов: Сила, Выносливость, Ловкость, Интеллект, Мудрость, Меткость, Удача (в оригинале str, vit, agi, int,
## men, dex, luk). L — настоящий уровень, fcm — множитель статов (герой и зверь 1.0, существо 0.7).
## Попадание, урон через защиту и крит в бою — Combat. Опорные точки и интерполяция — для таблиц питомцев.

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
# s — 7 статов, lvl — уровень, fcm — множитель статов (FCM оригинала).

## Макс. HP: 30·Вын + 20·L.
static func raw_hp(s: Dictionary, lvl: float, fcm: float = 1.0) -> float:
	return 30.0 * float(s["vit"]) * fcm + 20.0 * lvl


## Физ. атака ближнего боя: 2·Сила + L (оружие — сверху).
static func raw_patk(s: Dictionary, lvl: float, fcm: float = 1.0) -> float:
	return 2.0 * float(s["str"]) * fcm + lvl


## Физ. атака дальнего боя (лук, арбалет): (1.6·Меткость + 0.4·Сила) + L.
static func raw_ratk(s: Dictionary, lvl: float, fcm: float = 1.0) -> float:
	return (1.6 * float(s["dex"]) + 0.4 * float(s["str"])) * fcm + lvl


## Маг. атака: 2·Инт + L.
static func raw_matk(s: Dictionary, lvl: float, fcm: float = 1.0) -> float:
	return 2.0 * float(s["int"]) * fcm + lvl


## Сила лечения (умения лечения питомцев): маг. атака от Интеллекта и Мудрости поровну.
static func raw_heal(s: Dictionary, lvl: float, fcm: float = 1.0) -> float:
	return (float(s["int"]) + float(s["wis"])) * fcm + lvl


## Физ. защита: 2·Вын + L.
static func raw_pdef(s: Dictionary, lvl: float, fcm: float = 1.0) -> float:
	return 2.0 * float(s["vit"]) * fcm + lvl


## Маг. защита: 2·Мдр + L.
static func raw_mdef(s: Dictionary, lvl: float, fcm: float = 1.0) -> float:
	return 2.0 * float(s["wis"]) * fcm + lvl


## Макс. MP: 30·Инт + 20·L.
static func raw_mp(s: Dictionary, lvl: float, fcm: float = 1.0) -> float:
	return 30.0 * float(s["int"]) * fcm + 20.0 * lvl


## Восстановление HP в секунду в бою (наше: в оригинале — тики раз в несколько секунд; отдых — Player.REST_*).
static func raw_hp_regen(s: Dictionary, lvl: float) -> float:
	return 0.05 * float(s["vit"]) + 0.1 * lvl


## Восстановление MP в секунду.
static func mp_regen(s: Dictionary, lvl: float) -> float:
	return 0.5 + 0.05 * float(s["wis"]) + 0.02 * lvl


## Точность: 0.5·Меткость + L (+ бонус умений). Попадание — Combat.hit_chance (точность / уклонение цели).
static func accuracy(s: Dictionary, lvl: float, bonus: float = 0.0, fcm: float = 1.0) -> int:
	return roundi(0.5 * float(s["dex"]) * fcm + lvl + bonus)


## Уклонение (избегание, avoid): 0.5·Ловкость + L.
static func avoidance(s: Dictionary, lvl: float, fcm: float = 1.0) -> int:
	return roundi(0.5 * float(s["agi"]) * fcm + lvl)


## Отдельный шанс увернуться, % — в оригинале его нет (всё решает точность против уклонения); только от умений,
## поясов и т. п.
static func evasion(_s: Dictionary, _lvl: float) -> float:
	return 0.0


## Шанс крита, %: 0.2·Удача + 3.
static func crit_chance(s: Dictionary) -> float:
	return 0.2 * float(s["luck"]) + 3.0


## Скорость атаки, % (100 — обычная): в оригинале от статов не зависит — только оружие и умения.
static func attack_speed(_s: Dictionary) -> int:
	return 100
