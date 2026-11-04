class_name MobStats
extends RefCounted
## Характеристики зверей мира по базе оригинала (tools/rappelz_db_reference.md, «Звери по уровню»): у обычного зверя
## уровня L — числа MonsterResource (медиана обычных зверей уровня: HP, атака, маг. атака, защита, маг. защита, опыт)
## плюс формулы сервера по его маленьким статам (StatResource зверя): HP + 30·Вын + 20·L, атака + 2·Сила + L,
## защита + 2·Вын + L, маг. защита + 2·Мдр + L, точность 0.5·Метк + L, уклонение 0.5·Ловк + L, крит 0.2·Удача + 3 %
## (StructMonster::onApplyAttributeAdjustment прибавляет числа базы к расчёту StructCreature). Вид облик меняет, силу —
## нет (в базе звери одного уровня равны): у пантеры и фазана атака магическая. Поверх — сила редкости MobData.power
## (HP, атака, опыт), защита вида MobData.defense (анатемы ниже), темп ударов MobData.attack_cd.
## Типы оригинала того же уровня (во сколько раз против обычного): мини-босс («Редкий» зверь мира) — элитный
## (monster_type 6), босс — именной (21): ELITE_* и BOSS_*.
## Опыт за зверя — опыт базы × XP_RATE (решение Максима: «рейт» ×5); кривая героя — XP_TABLE (LevelResource).

## Обычный зверь по уровню 1…60: [HP, атака, маг. атака, защита, маг. защита, опыт, JP, [7 статов]] (статы — порядок
## Stats.STATS). Выше 60 — продолжение последнего отрезка.
const LEVELS := [
	[105, 20, 20, 6, 7, 5, 3, [1, 1, 0, 0, 0, 0, 10]], [140, 23, 23, 7, 8, 9, 4, [1, 1, 0, 0, 0, 0, 10]],
	[175, 27, 27, 9, 10, 15, 5, [1, 1, 0, 0, 0, 0, 10]], [210, 28, 31, 11, 12, 20, 6, [1, 1, 0, 0, 1, 0, 10]],
	[246, 33, 35, 13, 14, 26, 7, [2, 3, 1, 1, 1, 1, 10]], [304, 38, 38, 14, 16, 33, 8, [2, 3, 1, 1, 1, 1, 10]],
	[362, 41, 41, 16, 18, 40, 9, [2, 3, 1, 1, 1, 1, 10]], [421, 41, 44, 18, 20, 48, 10, [2, 3, 1, 1, 2, 1, 10]],
	[479, 44, 47, 20, 22, 56, 11, [2, 3, 1, 1, 2, 1, 10]], [538, 48, 50, 22, 24, 64, 12, [3, 5, 2, 2, 3, 2, 10]],
	[613, 53, 53, 25, 27, 73, 13, [3, 5, 2, 2, 3, 2, 10]], [688, 54, 57, 28, 30, 82, 14, [3, 5, 2, 2, 3, 2, 10]],
	[763, 60, 60, 31, 34, 92, 15, [3, 5, 2, 2, 3, 2, 10]], [838, 64, 64, 34, 37, 102, 16, [3, 5, 2, 2, 3, 2, 10]],
	[913, 68, 68, 38, 41, 112, 17, [5, 6, 3, 3, 3, 3, 10]], [1006, 71, 71, 41, 44, 123, 18, [5, 6, 3, 3, 3, 3, 10]],
	[1100, 74, 74, 44, 47, 134, 19, [5, 6, 3, 3, 3, 3, 10]], [1193, 77, 77, 47, 51, 145, 20, [5, 6, 3, 3, 3, 3, 10]],
	[1287, 80, 80, 50, 54, 157, 21, [5, 6, 3, 3, 3, 3, 10]], [1381, 84, 84, 54, 58, 169, 22, [6, 8, 4, 4, 4, 4, 15]],
	[1488, 88, 88, 57, 61, 181, 23, [6, 8, 4, 4, 4, 4, 15]], [1596, 92, 92, 60, 65, 194, 25, [6, 8, 4, 4, 4, 4, 15]],
	[1703, 96, 96, 63, 68, 207, 26, [6, 8, 4, 4, 4, 4, 15]], [1811, 100, 100, 66, 72, 220, 28, [6, 8, 4, 4, 4, 4, 15]],
	[1919, 105, 105, 70, 76, 234, 29, [7, 10, 5, 5, 5, 5, 15]],
	[2031, 109, 109, 74, 80, 248, 32, [7, 10, 5, 5, 5, 5, 15]],
	[2143, 113, 113, 78, 84, 262, 33, [7, 10, 5, 5, 5, 5, 15]],
	[2255, 117, 117, 82, 89, 277, 35, [7, 10, 5, 5, 5, 5, 15]],
	[2367, 121, 121, 86, 93, 292, 36, [7, 10, 5, 5, 5, 5, 15]],
	[2480, 126, 126, 91, 98, 307, 37, [9, 12, 6, 6, 6, 6, 15]],
	[2594, 130, 130, 95, 102, 322, 39, [9, 12, 6, 6, 6, 6, 15]],
	[2709, 134, 134, 99, 107, 338, 40, [9, 12, 6, 6, 6, 6, 15]],
	[2824, 138, 138, 104, 112, 354, 41, [9, 12, 6, 6, 6, 6, 15]],
	[2939, 142, 142, 108, 117, 371, 43, [9, 12, 6, 6, 6, 6, 15]],
	[3054, 147, 147, 113, 122, 388, 44, [10, 14, 7, 7, 7, 7, 15]],
	[3173, 151, 151, 117, 126, 405, 45, [10, 14, 7, 7, 7, 7, 15]],
	[3292, 155, 155, 122, 131, 422, 46, [10, 14, 7, 7, 7, 7, 15]],
	[3411, 159, 159, 126, 136, 440, 48, [10, 14, 7, 7, 7, 7, 15]],
	[3530, 163, 163, 131, 141, 458, 49, [10, 14, 7, 7, 7, 7, 15]],
	[3650, 168, 168, 136, 146, 476, 50, [11, 15, 8, 8, 8, 8, 15]],
	[3771, 172, 172, 140, 151, 494, 51, [11, 15, 8, 8, 8, 8, 15]],
	[3893, 176, 176, 145, 156, 513, 52, [11, 15, 8, 8, 8, 8, 15]],
	[4015, 180, 180, 149, 161, 532, 53, [11, 15, 8, 8, 8, 8, 15]],
	[4137, 184, 184, 154, 166, 552, 55, [11, 15, 8, 8, 8, 8, 15]],
	[4259, 189, 189, 159, 172, 571, 56, [13, 17, 10, 10, 10, 10, 15]],
	[4385, 193, 193, 163, 176, 591, 57, [13, 17, 10, 10, 10, 10, 15]],
	[4511, 197, 197, 167, 181, 611, 58, [13, 17, 10, 10, 10, 10, 15]],
	[4638, 201, 201, 172, 185, 632, 59, [13, 17, 10, 10, 10, 10, 15]],
	[4764, 205, 205, 176, 190, 653, 60, [13, 17, 10, 10, 10, 10, 15]],
	[4764, 210, 210, 181, 190, 674, 61, [14, 19, 11, 11, 11, 11, 20]],
	[5019, 214, 214, 185, 200, 695, 62, [14, 19, 11, 11, 11, 11, 20]],
	[5148, 218, 218, 190, 205, 717, 63, [14, 19, 11, 11, 11, 11, 20]],
	[5276, 222, 222, 194, 210, 739, 64, [14, 19, 11, 11, 11, 11, 20]],
	[5405, 226, 226, 199, 215, 761, 65, [14, 19, 11, 11, 11, 11, 20]],
	[5534, 231, 231, 204, 220, 783, 66, [16, 21, 12, 12, 12, 12, 20]],
	[5667, 235, 235, 208, 224, 806, 67, [16, 21, 12, 12, 12, 12, 20]],
	[5800, 239, 239, 213, 229, 829, 68, [16, 21, 12, 12, 12, 12, 20]],
	[5934, 243, 243, 217, 234, 853, 69, [16, 21, 12, 12, 12, 12, 20]],
	[6067, 247, 247, 222, 239, 876, 70, [16, 21, 12, 12, 12, 12, 20]],
	[6201, 252, 252, 227, 244, 900, 71, [17, 23, 13, 13, 13, 13, 20]],
]

## Опыт до следующего уровня героя 1…60 (LevelResource: разница normal_exp). Выше — ×1.06 за уровень.
const XP_TABLE := [
	15, 32, 72, 160, 320, 540, 885, 1332, 1725, 2754, 3906, 5472, 7266, 9310, 11550, 14335, 17664, 21000, 31042, 36784,
	42465, 48925, 56000, 64009, 72625, 81606, 91728, 102564, 138580, 153825, 169818, 186559, 205238, 224536, 245700,
	266664, 289562, 314496, 411840, 444600, 479745, 514885, 552808, 593640, 634125, 677603, 724200, 770408, 996660,
	1061208, 1125264, 1193998, 1266597, 1339182, 1416250, 1497390, 1578520, 1664397, 2134826, 2249000,
]

## «Рейт» опыта (решение Максима): опыт за зверя × XP_RATE, кривая героя — как в оригинале.
const XP_RATE := 5.0
## Мини-босс («Редкий» зверь мира: вожак анатем, змеекрыл, кентавр) — элитный зверь оригинала (monster_type 6).
const ELITE_HP := 5.5
const ELITE_ATK := 1.25
const ELITE_DEF := 1.44
const ELITE_XP := 5.6
## Босс — именной зверь оригинала (monster_type 21); размер модели — BOSS_SCALE к зверю 3-й стадии.
const BOSS_HP := 7.24
const BOSS_ATK := 2.0
const BOSS_DEF := 1.1
const BOSS_XP := 5.6
const BOSS_SCALE := 1.35
## Модель дикого зверя по уровню: с 12 ур. — 2-я стадия эволюции (<вид>_2), с 22 — 3-я (<вид>_3), если файл есть.
const WILD_STAGE_LEVELS := [1, 12, 22]


## Строка таблицы LEVELS уровня lvl (выше 60 — продолжение последнего отрезка).
static func _row(lvl: int) -> Array:
	var l := maxi(1, lvl)
	if l <= LEVELS.size():
		return LEVELS[l - 1]
	var a: Array = LEVELS[LEVELS.size() - 2]
	var b: Array = LEVELS[LEVELS.size() - 1]
	var k := float(l - LEVELS.size())
	var res: Array = []
	for i in 7:
		res.append(roundi(float(b[i]) + (float(b[i]) - float(a[i])) * k))
	var st: Array = []
	for i in 7:
		st.append(roundi(float(b[7][i]) + (float(b[7][i]) - float(a[7][i])) * k))
	res.append(st)
	return res


## Главная атака вида магическая (маг и лекарь среди видов питомцев).
static func is_magic(species: String) -> bool:
	return PetData.SPECIES.has(species) and PetStats.is_magic(species)


## 7 статов зверя на уровне lvl (у всех видов одни — как в базе).
static func stats(_species: String, lvl: int) -> Dictionary:
	var st: Array = _row(lvl)[7]
	var res: Dictionary = {}
	for i in Stats.STATS.size():
		res[Stats.STATS[i]] = int(st[i])
	return res


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


## Мини-босс — «Редкий» зверь мира, не босс (вожак анатем, змеекрыл, кентавр). То же правило, что у
## MobData.is_mini_boss (после слияния можно звать его).
static func is_mini_boss(type_id: String) -> bool:
	return MobData.TYPES.has(type_id) and not MobData.is_boss(type_id) \
		and String(MobData.get_type(type_id).get("rarity", "common")) == "rare"


## Агрессивный зверь (решение Максима): боссы и мини-боссы нападают сами, когда герой или его питомец подходит на
## дистанцию их атаки (Mob.aggro_range); остальные нейтральны — не вступают в бой, пока их не атакуют.
static func is_aggressive(type_id: String) -> bool:
	return MobData.is_boss(type_id) or is_mini_boss(type_id)


## Опыт за обычного зверя уровня lvl (база × рейт, до силы редкости и разницы уровней).
static func base_xp(lvl: int) -> float:
	return float(_row(lvl)[5]) * XP_RATE


## Опыт до следующего уровня героя уровня lvl (XP_TABLE; выше 60 — ×1.06 за уровень).
static func xp_to_next(lvl: int) -> int:
	var l := maxi(1, lvl)
	if l <= XP_TABLE.size():
		return int(XP_TABLE[l - 1])
	return roundi(float(XP_TABLE[XP_TABLE.size() - 1]) * pow(1.06, float(l - XP_TABLE.size())))


## Все характеристики зверя type_id на уровне lvl.
## Ключи: stats (7 статов), max_hp, atk (главная атака), patk, matk, magic (атака магическая), def, mdef,
## acc (точность), avoid (уклонение), eva и crit (%), aspd (% скорости атаки), attack_cd (с между ударами), xp.
static func derived(type_id: String, lvl: int) -> Dictionary:
	var lv := maxi(1, lvl)
	var sp := MobData.species_of(type_id)
	var row := _row(lv)
	var s := stats(sp, lv)
	var lf := float(lv)
	var magic := is_magic(sp)
	var pw := MobData.power(type_id)
	var boss := MobData.is_boss(type_id)
	var elite := not boss and is_mini_boss(type_id)
	var hp_m := pw * (BOSS_HP if boss else (ELITE_HP if elite else 1.0))
	var atk_m := pw * (BOSS_ATK if boss else (ELITE_ATK if elite else 1.0))
	var def_m := MobData.defense(type_id) * (BOSS_DEF if boss else (ELITE_DEF if elite else 1.0))
	var xp_m := pw * (BOSS_XP if boss else (ELITE_XP if elite else 1.0))
	var patk := maxi(1, roundi((float(row[1]) + Stats.raw_patk(s, lf)) * atk_m))
	var matk := maxi(1, roundi((float(row[2]) + Stats.raw_matk(s, lf)) * atk_m))
	var aspd := Stats.attack_speed(s)
	return {
		"stats": s,
		"max_hp": maxi(1, roundi((float(row[0]) + Stats.raw_hp(s, lf)) * hp_m)),
		"patk": patk,
		"matk": matk,
		"atk": matk if magic else patk,
		"magic": magic,
		"def": roundi((float(row[3]) + Stats.raw_pdef(s, lf)) * def_m),
		"mdef": roundi((float(row[4]) + Stats.raw_mdef(s, lf)) * def_m),
		"acc": Stats.accuracy(s, lf),
		"avoid": Stats.avoidance(s, lf),
		"eva": Stats.evasion(s, lf),
		"crit": snappedf(Stats.crit_chance(s), 0.1),
		"aspd": aspd,
		"attack_cd": MobData.attack_cd(type_id) * 100.0 / float(aspd),
		"xp": maxi(1, roundi(base_xp(lv) * xp_m)),
	}
