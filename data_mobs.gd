class_name MobData
extends RefCounted
## Звери мира: вид, редкость, приручение (карта существа и её тир), добыча, боссы. Характеристики из 7 статов
## по уровню — MobStats, модель боя — Combat.
## Где и какого уровня они появляются — mob_zones в world/training_island.json.
## id зверя совпадает с id вида питомца (PetData; у летающих рыб и анатем вида питомца нет). Пантера, черепаха, фазан,
## волк, кентавр, летающие рыбы и анатемы — модели из файлов (CreatureAsset, assets/creatures/), кабан и страж — из примитивов
## (CreatureModels) и в мире больше не появляются.
## defense — множитель защиты (по умолчанию 1.0), attack_cd — пауза между ударами (по умолчанию 1.3 с).
## flying: true — летающий зверь (парит на уровне головы героя, падает только после смерти).

## Радиус безопасной зоны города новичков в центре мира (там торговец, звери туда не заходят).
## Источник правды — safe_zones в world/training_island.json; здесь — для кода без острова.
const SAFE_RADIUS := 22.0

## Редкости по возрастанию: «Базовый» (common), «Обычный» (uncommon), «Редкий» (rare), «Уникальный» (unique).
## Новый вид другой редкости — одно поле "rarity" в TYPES: от неё ранг, тир карты, цвет подписи и сила (power).
## Ранг редкости (сортировка, сравнение).
const RARITY_TIER := {"common": 1, "uncommon": 2, "rare": 3, "unique": 4}
## Тир карты существа по редкости зверя (если у вида нет поля "card"): базовые — коричневая, обычные — синяя,
## редкие — фиолетовая, уникальные — жёлтая. Цвета и названия тиров — ItemData.CARD_TIERS, шанс приручения —
## Taming.CHANCE.
const CARD_TIER_BY_RARITY := {"common": "basic", "uncommon": "rare", "rare": "special", "unique": "unique"}
## Названия редкостей для игрока («common» — «Базовый»).
const RARITY_NAMES := {"common": "Базовый", "uncommon": "Обычный", "rare": "Редкий", "unique": "Уникальный"}
## Цвет подписи редкости (имя зверя над головой, панель цели) — в тон карты существа.
const RARITY_COLORS := {
	"common": Color(1, 1, 1), "uncommon": Color(0.6, 0.8, 1.0), "rare": Color(0.82, 0.62, 1.0),
	"unique": Color(1.0, 0.8, 0.3),
}
## Сила по редкости — множитель поверх статов вида: у зверя мира HP, атака, опыт и золото (MobStats, Economy),
## у питомца HP, атаки, лечение и защиты (PetStats.derived). Поле вида "power" заменяет его (у стража числа
## подобраны вручную — power 1.0).
const RARITY_POWER := {"common": 1.0, "uncommon": 1.15, "rare": 1.3, "unique": 1.5}
## Прежние id зверей (и видов питомцев) → новые: старые сохранения переводит Game.from_dict.
const RENAMED := {"bear": "panther", "sparkbug": "turtle", "fairy": "pheasant"}

## Характеристики (HP, атака, защиты, точность, крит, опыт) — не числами вида, а из 7 статов по уровню (MobStats):
## level — базовый уровень вида (где он обычно водится; уровень в мире — из зоны острова), speed — скорость бега,
## scale — размер модели, color — цвет запасной модели.
## Добыча (LootTable, правила Максима): loot — материалы зверя (трофеи, id предметов ItemData), special — особые
## материалы босса, mirror: true — в категории «карты» бывает зеркальная карта (у боссов — всегда); карта своего
## вида — у приручаемых (и у боссов приручаемого вида). Золото ≈ цене продажи материала (gold_range); gold —
## [мин., макс.] на базовом уровне вида — запасная вилка, если материалов у вида нет.
## gen — название в родительном падеже («душа пантеры», «выпадает из волка»).
## Приручение: tameable (по умолчанию true; false — фиолетовый значок «нельзя приручить» на панели цели,
## карт вида нет), card — тир карты существа ("basic" | "rare" | "special" | "unique"; по умолчанию — по редкости).
## Пустая карта вида — предмет card_<id>, заполненная — card_<id>_soul (ItemData).
## Кабана и каменного стража приручить нельзя (решение Максима); их вид питомца (PetData) остаётся
## для уже прирученных в старых версиях.
## Боссы (boss: true; решение Максима — по одному на каждое существо острова): species — чьи статы и модель,
## stage — стадия модели (2 — 3-я эволюция «<вид>_3»; у рыб и анатем эволюций нет — модель старшего вида),
## редкость «Уникальный», статы выше зверя 3-й стадии того же уровня (MobStats.BOSS_*), крупнее, не приручаются,
## своя добыча (4 предмета, особый материал — special, золото по его цене, шанс карты), долгий респаун respawn (с).
## Минибоссы (is_mini_boss): «Редкие» звери мира — вожак анатем, змеекрыл, кентавр (поле mini_boss заменяет
## правило): добычи больше (3 предмета против 2), агрессивнее (mob.gd — по тому же признаку).
const TYPES := {
	"boar": {
		"name": "Кабан", "gen": "кабана", "level": 1, "speed": 3.0, "gold": [2, 5],
		"color": Color(0.55, 0.35, 0.2), "scale": 0.9, "rarity": "common", "tameable": false,
		"loot": ["boar_tusk"],
	},
	# Волк — «Обычный»: сильнее базовых (RARITY_POWER)
	"wolf": {
		"name": "Волк", "gen": "волка", "level": 3, "speed": 4.4, "gold": [4, 8],
		"color": Color(0.5, 0.5, 0.55), "scale": 1.0, "rarity": "uncommon",
		"loot": ["wolf_pelt"],
	},
	"panther": {
		"name": "Пантера", "gen": "пантеры", "level": 11, "speed": 4.2, "gold": [10, 20],
		"color": Color(0.24, 0.2, 0.32), "scale": 1.0, "rarity": "common",
		"loot": ["panther_fang"], "mirror": true,
	},
	"pheasant": {
		"name": "Фазан", "gen": "фазана", "level": 2, "speed": 3.6, "gold": [5, 10],
		"color": Color(0.74, 0.4, 0.2), "scale": 1.0, "rarity": "common",
		"loot": ["pheasant_feather"], "mirror": true,
	},
	"turtle": {
		"name": "Черепаха", "gen": "черепахи", "level": 5, "speed": 1.6, "gold": [10, 20],
		"color": Color(0.36, 0.55, 0.32), "scale": 1.0, "rarity": "common",
		"loot": ["shell_plate"], "mirror": true,
	},
	# Летающие рыбы: парят на уровне головы героя (модель из файла, высота парения — hover в creatures.json),
	# на землю падают только после смерти. Не приручаются и не бывают питомцами (вида в PetData нет).
	"flyfish": {
		"name": "Летучий зубан", "gen": "летучего зубана", "level": 5, "speed": 3.8,
		"gold": [8, 15], "color": Color(0.25, 0.4, 0.68), "scale": 1.0, "rarity": "common", "tameable": false,
		"flying": true,
		"loot": ["flyfish_scale"],
	},
	"flyfish_sail": {
		"name": "Рыба-парусник", "gen": "рыбы-парусника", "level": 9, "speed": 4.4,
		"gold": [12, 24], "color": Color(0.22, 0.36, 0.62), "scale": 1.0, "rarity": "common", "tameable": false,
		"flying": true,
		"loot": ["sail_fin"],
	},
	"flyfish_drake": {
		"name": "Змеекрыл", "gen": "змеекрыла", "level": 16, "speed": 4.0,
		"gold": [30, 60], "color": Color(0.2, 0.32, 0.58), "scale": 1.0, "rarity": "rare", "tameable": false,
		"flying": true,
		"loot": ["drake_crest"], "mirror": true,
	},
	# Анатемы — человекоподобные ящеры с костяными клинками на предплечьях (модели Максима из файлов, двуногие,
	# клипы — Quaternius UAL). Физический ближний бой: статы Сила и Ловкость, частые удары (attack_cd),
	# низкая Выносливость и защита (defense < 1). Не приручаются и не бывают питомцами (вида в PetData нет).
	"anathema": {
		"name": "Анатема", "gen": "анатемы", "level": 9, "speed": 4.0, "gold": [10, 20],
		"color": Color(0.22, 0.32, 0.2), "scale": 1.0, "rarity": "common", "tameable": false,
		"defense": 0.7, "attack_cd": 1.0,
		"loot": ["lizard_scale"],
	},
	"anathema_blade": {
		"name": "Анатема-рубака", "gen": "анатемы-рубаки", "level": 18, "speed": 4.2,
		"gold": [16, 30], "color": Color(0.2, 0.3, 0.18), "scale": 1.0, "rarity": "common", "tameable": false,
		"defense": 0.7, "attack_cd": 1.0,
		"loot": ["bone_blade", "lizard_scale"],
	},
	# Вожак анатем — страж логова у пещеры (вместо каменного стража): «Редкий», крепче остальных. Не босс:
	# босс анатем — отдельный «Костяной владыка»
	"anathema_chief": {
		"name": "Вожак анатем", "gen": "вожака анатем", "level": 25, "speed": 4.0,
		"gold": [60, 120], "color": Color(0.24, 0.3, 0.18), "scale": 1.0, "rarity": "rare", "tameable": false,
		"defense": 0.8, "attack_cd": 1.1,
		"loot": ["chief_spike", "bone_blade"], "mirror": true,
	},
	# Кентавр — «Редкий» копейщик (модели Максима из файлов, 3 стадии): сильнее базовых и «Обычного» волка
	# (RARITY_POWER 1.3), бьёт реже, но больно. Карта кентавра только выпадает из него (Кирк её не продаёт).
	"centaur": {
		"name": "Кентавр", "gen": "кентавра", "level": 14, "speed": 4.6, "gold": [24, 45],
		"color": Color(0.5, 0.33, 0.2), "scale": 1.0, "rarity": "rare", "attack_cd": 1.4,
		"loot": ["spear_tip", "horse_hair"],
	},
	# ---------- Боссы: по одному на существо острова, логова — зоны boss_* острова ----------
	"boss_pheasant": {
		"name": "Пламенный Златохвост", "gen": "Пламенного Златохвоста", "level": 15, "speed": 4.0,
		"gold": [150, 260], "color": Color(0.74, 0.4, 0.2), "scale": 1.0, "rarity": "unique", "tameable": false,
		"boss": true, "species": "pheasant", "stage": 2, "respawn": 360.0,
		"loot": ["pheasant_feather"], "special": ["golden_plume"],
	},
	"boss_wolf": {
		"name": "Седой Вожак бури", "gen": "Седого Вожака бури", "level": 18, "speed": 4.8,
		"gold": [200, 340], "color": Color(0.5, 0.5, 0.55), "scale": 1.0, "rarity": "unique", "tameable": false,
		"boss": true, "species": "wolf", "stage": 2, "respawn": 360.0,
		"loot": ["wolf_pelt"], "special": ["storm_fang"],
	},
	"boss_turtle": {
		"name": "Тысячелетний Бастион", "gen": "Тысячелетнего Бастиона", "level": 21, "speed": 2.0,
		"gold": [260, 420], "color": Color(0.36, 0.55, 0.32), "scale": 1.0, "rarity": "unique", "tameable": false,
		"boss": true, "species": "turtle", "stage": 2, "respawn": 420.0,
		"loot": ["shell_plate"], "special": ["bastion_shard"],
	},
	"boss_flyfish": {
		"name": "Владыка течений", "gen": "Владыки течений", "level": 22, "speed": 4.4,
		"gold": [280, 450], "color": Color(0.2, 0.32, 0.58), "scale": 1.0, "rarity": "unique", "tameable": false,
		"flying": true, "boss": true, "species": "flyfish_drake", "stage": 0, "respawn": 420.0,
		"loot": ["drake_crest"], "special": ["current_pearl"],
	},
	"boss_panther": {
		"name": "Владычица полуночи", "gen": "Владычицы полуночи", "level": 24, "speed": 4.6,
		"gold": [320, 500], "color": Color(0.24, 0.2, 0.32), "scale": 1.0, "rarity": "unique", "tameable": false,
		"boss": true, "species": "panther", "stage": 2, "respawn": 480.0,
		"loot": ["panther_fang"], "special": ["midnight_claw"],
	},
	"boss_centaur": {
		"name": "Громовой хан", "gen": "Громового хана", "level": 27, "speed": 5.0,
		"gold": [380, 600], "color": Color(0.5, 0.33, 0.2), "scale": 1.0, "rarity": "unique", "tameable": false,
		"attack_cd": 1.4, "boss": true, "species": "centaur", "stage": 2, "respawn": 540.0,
		"loot": ["spear_tip", "horse_hair"], "special": ["thunder_spear"],
	},
	# Босс анатем — отдельный от «Вожака анатем» (тот остаётся «Редким» стражем логова у пещеры)
	"boss_anathema": {
		"name": "Костяной владыка", "gen": "Костяного владыки", "level": 30, "speed": 4.4,
		"gold": [450, 700], "color": Color(0.24, 0.3, 0.18), "scale": 1.0, "rarity": "unique", "tameable": false,
		"defense": 0.8, "attack_cd": 1.1, "boss": true, "species": "anathema_chief", "stage": 0, "respawn": 600.0,
		"loot": ["chief_spike", "bone_blade"], "special": ["bone_crown"],
	},
	# Кабан и каменный страж — модели из примитивов: в мире больше не появляются (на острове только существа
	# Максима), данные — для совместимости (старые сохранения, тесты)
	"golem": {
		"name": "Каменный страж", "gen": "каменного стража", "level": 10, "speed": 2.6, "gold": [60, 120],
		"color": Color(0.5, 0.5, 0.45), "scale": 2.0, "rarity": "unique", "tameable": false, "power": 1.0,
		"loot": ["golem_shard"], "mirror": true,
	},
}
## Подпись босса над головой и на панели цели.
const BOSS_COLOR := Color(1.0, 0.5, 0.22)
## Через сколько секунд зверь появляется снова (у боссов — поле respawn).
const RESPAWN_TIME := 20.0


static func get_type(id: String) -> Dictionary:
	return TYPES.get(id, TYPES["boar"])


static func rarity_tier(id: String) -> int:
	return int(RARITY_TIER.get(get_type(id)["rarity"], 1))


## Сила вида по редкости (RARITY_POWER) или его поле "power": 1.0 у базовых.
static func power(id: String) -> float:
	var d := get_type(id)
	return float(d.get("power", RARITY_POWER.get(String(d["rarity"]), 1.0)))


static func rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity, RARITY_COLORS["common"])


## Можно ли приручить зверя этого вида (неизвестный вид — нельзя).
static func tameable(id: String) -> bool:
	return TYPES.has(id) and bool(get_type(id).get("tameable", true))


## Защита вида относительно обычной (1.0; поле "defense", множитель физ. и маг. защиты MobStats): < 1 — по зверю
## проходит больше урона (анатемы).
static func defense(id: String) -> float:
	return clampf(float(get_type(id).get("defense", 1.0)), 0.2, 3.0)


## Босс (по одному на каждое существо острова).
static func is_boss(id: String) -> bool:
	return TYPES.has(id) and bool(get_type(id).get("boss", false))


## Минибосс: «Редкий» зверь мира, не босс (вожак анатем, змеекрыл, кентавр); поле "mini_boss" заменяет правило.
static func is_mini_boss(id: String) -> bool:
	if not TYPES.has(id) or is_boss(id):
		return false
	var d := get_type(id)
	if d.has("mini_boss"):
		return bool(d["mini_boss"])
	return String(d.get("rarity", "common")) == "rare"


## Материалы зверя (трофеи; у босса — материалы его вида): id предметов.
static func materials(id: String) -> Array:
	var res: Array = []
	for e in get_type(id).get("loot", []):
		if e is String and not ItemData.get_item(String(e)).is_empty():
			res.append(String(e))
	return res


## Особые материалы босса (у прочих — []).
static func special_materials(id: String) -> Array:
	var res: Array = []
	if not is_boss(id):
		return res
	for e in get_type(id).get("special", []):
		res.append(String(e))
	return res


## Роняет ли зверь зеркальную карту (категория «карты» добычи): боссы и виды с mirror: true.
static func drops_mirror(id: String) -> bool:
	return is_boss(id) or bool(get_type(id).get("mirror", false))


## Вид, чьи статы и модель у зверя: у босса — поле species, у остальных — сам id.
static func species_of(id: String) -> String:
	return String(get_type(id).get("species", id if TYPES.has(id) else "boar"))


## Через сколько секунд зверь появится снова: боссы — долго (поле respawn), остальные — RESPAWN_TIME.
static func respawn_time(id: String) -> float:
	return float(get_type(id).get("respawn", RESPAWN_TIME))


## Золото за зверя уровня lvl: [мин., макс.] (правило Максима — немного, ± цена материала): средняя цена продажи
## материалов (у босса — особого материала, если он дороже) × 0.8…1.2 и мягкий рост с уровнем ((lvl + 4) / (база + 4),
## 0.75…1.5). Нет материалов — прежняя вилка gold вида.
## Множитель золота за зверя (решение Максима: «количество выпадаемых денег увеличь в 4 раза» — впереди новые
## товары и механики): вилка gold_range — цена материала × 0.8…1.2 × уровень × GOLD_MULT.
const GOLD_MULT := 4.0


static func gold_range(id: String, lvl: int) -> Array:
	var d := get_type(id)
	var k := clampf(float(maxi(1, lvl) + 4) / float(int(d["level"]) + 4), 0.75, 1.5) * GOLD_MULT
	var base := maxf(_avg_sell(materials(id)), _avg_sell(special_materials(id)))
	if base <= 0.0:
		var g: Array = d["gold"]
		return [maxi(1, roundi(float(g[0]) * k)), maxi(1, roundi(float(g[1]) * k))]
	return [maxi(1, roundi(base * 0.8 * k)), maxi(1, roundi(base * 1.2 * k))]


static func _avg_sell(ids: Array) -> float:
	if ids.is_empty():
		return 0.0
	var s := 0.0
	for e in ids:
		s += float(ItemData.get_item(String(e)).get("sell", 0))
	return s / float(ids.size())


## Цвет подписи зверя: у босса — BOSS_COLOR, иначе — цвет редкости.
static func label_color(id: String) -> Color:
	return BOSS_COLOR if is_boss(id) else rarity_color(String(get_type(id)["rarity"]))


## Пауза между ударами зверя, с (поле "attack_cd"; у анатем удары чаще), до скорости атаки от Ловкости (MobStats).
static func attack_cd(id: String) -> float:
	return float(get_type(id).get("attack_cd", 1.3))


## Летающий зверь (парит над землёй, падает только после смерти).
static func flying(id: String) -> bool:
	return TYPES.has(id) and bool(get_type(id).get("flying", false))


## Тир карты существа для вида: "basic" | "rare" | "special" | "unique".
static func card_tier(id: String) -> String:
	var d := get_type(id)
	return String(d.get("card", CARD_TIER_BY_RARITY.get(String(d["rarity"]), "basic")))


## Название вида в родительном падеже, со строчной («пантеры»).
static func name_gen(id: String) -> String:
	var d := get_type(id)
	return String(d.get("gen", String(d["name"]).to_lower()))


## Редкость зверя для игрока: «Базовый», «Обычный», «Редкий», «Уникальный».
static func rarity_name(id: String) -> String:
	return rarity_label(String(get_type(id)["rarity"]))


static func rarity_label(rarity: String) -> String:
	return String(RARITY_NAMES.get(rarity, RARITY_NAMES["common"]))


## Новый id зверя по прежнему (из старого сохранения); неизвестный и актуальный — как есть.
static func migrate_id(id: String) -> String:
	return String(RENAMED.get(id, id))
