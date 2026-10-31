class_name MobData
extends RefCounted
## Звери мира: характеристики, редкость, приручение (карта существа и её тир), добыча.
## Где и какого уровня они появляются — mob_zones в world/training_island.json.
## id зверя совпадает с id вида питомца (PetData; у летающих рыб и анатем вида питомца нет). Пантера, черепаха, фазан,
## волк, летающие рыбы и анатемы — модели из файлов (CreatureAsset, assets/creatures/), кабан и страж — из примитивов
## (CreatureModels) и в мире больше не появляются.
## defense — защита относительно обычной (по умолчанию 1.0), attack_cd — пауза между ударами (по умолчанию 1.3 с).
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
## Сила по редкости — множитель поверх чисел вида: у зверя мира HP, атака, опыт и золото (Mob, Economy),
## у питомца HP, атаки, лечение и защиты (PetStats.derived). Поле вида "power" заменяет его (у стража числа
## подобраны вручную — power 1.0).
const RARITY_POWER := {"common": 1.0, "uncommon": 1.15, "rare": 1.3, "unique": 1.5}
## Прежние id зверей (и видов питомцев) → новые: старые сохранения переводит Game.from_dict.
const RENAMED := {"bear": "panther", "sparkbug": "turtle", "fairy": "pheasant"}

## loot: [id предмета, шанс 0..1, мин., макс.]. gold: [мин., макс.].
## gen — название в родительном падеже («душа пантеры», «выпадает из волка»).
## Приручение: tameable (по умолчанию true; false — фиолетовый значок «нельзя приручить» на панели цели,
## карт вида нет), card — тир карты существа ("basic" | "rare" | "special" | "unique"; по умолчанию — по редкости).
## Пустая карта вида — предмет card_<id>, заполненная — card_<id>_soul (ItemData).
## Кабана и каменного стража приручить нельзя (решение Максима); их вид питомца (PetData) остаётся
## для уже прирученных в старых версиях.
const TYPES := {
	"boar": {
		"name": "Кабан", "gen": "кабана", "level": 1, "hp": 30, "atk": 5, "speed": 3.0, "xp": 12, "gold": [2, 5],
		"color": Color(0.55, 0.35, 0.2), "scale": 0.9, "rarity": "common", "tameable": false,
		"loot": [["boar_tusk", 0.6, 1, 1], ["hp_potion", 0.08, 1, 1]],
	},
	# Волк — «Обычный»: числа на уровне базовых, сильнее их делает RARITY_POWER
	"wolf": {
		"name": "Волк", "gen": "волка", "level": 3, "hp": 48, "atk": 8, "speed": 4.4, "xp": 20, "gold": [4, 8],
		"color": Color(0.5, 0.5, 0.55), "scale": 1.0, "rarity": "uncommon",
		"loot": [["wolf_pelt", 0.55, 1, 1], ["hp_potion", 0.1, 1, 1], ["card_wolf", 0.04, 1, 1]],
	},
	"panther": {
		"name": "Пантера", "gen": "пантеры", "level": 6, "hp": 120, "atk": 17, "speed": 4.2, "xp": 70, "gold": [10, 20],
		"color": Color(0.24, 0.2, 0.32), "scale": 1.0, "rarity": "common",
		"loot": [["panther_fang", 0.5, 1, 2], ["hp_potion", 0.15, 1, 1], ["revive_scroll", 0.05, 1, 1],
			["mirror_card", 0.03, 1, 1]],
	},
	"pheasant": {
		"name": "Фазан", "gen": "фазана", "level": 4, "hp": 45, "atk": 7, "speed": 3.6, "xp": 35, "gold": [6, 12],
		"color": Color(0.74, 0.4, 0.2), "scale": 1.0, "rarity": "common",
		"loot": [["pheasant_feather", 0.6, 1, 2], ["hp_potion", 0.15, 1, 1], ["mirror_card", 0.03, 1, 1]],
	},
	"turtle": {
		"name": "Черепаха", "gen": "черепахи", "level": 7, "hp": 150, "atk": 14, "speed": 1.6, "xp": 80, "gold": [12, 24],
		"color": Color(0.36, 0.55, 0.32), "scale": 1.0, "rarity": "common",
		"loot": [["shell_plate", 0.5, 1, 1], ["revive_scroll", 0.08, 1, 1], ["mirror_card", 0.04, 1, 1]],
	},
	# Летающие рыбы: парят на уровне головы героя (модель из файла, высота парения — hover в creatures.json),
	# на землю падают только после смерти. Не приручаются и не бывают питомцами (вида в PetData нет).
	"flyfish": {
		"name": "Летучий зубан", "gen": "летучего зубана", "level": 5, "hp": 70, "atk": 12, "speed": 3.8, "xp": 50,
		"gold": [8, 15], "color": Color(0.25, 0.4, 0.68), "scale": 1.0, "rarity": "common", "tameable": false,
		"flying": true,
		"loot": [["flyfish_scale", 0.55, 1, 2], ["hp_potion", 0.15, 1, 1]],
	},
	"flyfish_sail": {
		"name": "Рыба-парусник", "gen": "рыбы-парусника", "level": 7, "hp": 120, "atk": 16, "speed": 4.4, "xp": 85,
		"gold": [12, 24], "color": Color(0.22, 0.36, 0.62), "scale": 1.0, "rarity": "common", "tameable": false,
		"flying": true,
		"loot": [["sail_fin", 0.5, 1, 1], ["hp_potion", 0.18, 1, 1], ["revive_scroll", 0.05, 1, 1]],
	},
	"flyfish_drake": {
		"name": "Змеекрыл", "gen": "змеекрыла", "level": 9, "hp": 230, "atk": 22, "speed": 4.0, "xp": 160,
		"gold": [30, 60], "color": Color(0.2, 0.32, 0.58), "scale": 1.0, "rarity": "rare", "tameable": false,
		"flying": true,
		"loot": [["drake_crest", 0.6, 1, 2], ["hp_potion", 0.25, 1, 2], ["revive_scroll", 0.08, 1, 1],
			["mirror_card", 0.08, 1, 1]],
	},
	# Анатемы — человекоподобные ящеры с костяными клинками на предплечьях (модели Максима из файлов, двуногие,
	# клипы — Quaternius UAL). Физический ближний бой: высокая атака, частые удары (attack_cd), но низкая защита
	# (defense < 1: по ним проходит больше урона). Не приручаются и не бывают питомцами (вида в PetData нет).
	"anathema": {
		"name": "Анатема", "gen": "анатемы", "level": 6, "hp": 95, "atk": 18, "speed": 4.0, "xp": 75, "gold": [10, 20],
		"color": Color(0.22, 0.32, 0.2), "scale": 1.0, "rarity": "common", "tameable": false,
		"defense": 0.7, "attack_cd": 1.0,
		"loot": [["lizard_scale", 0.55, 1, 2], ["hp_potion", 0.15, 1, 1], ["revive_scroll", 0.04, 1, 1]],
	},
	"anathema_blade": {
		"name": "Анатема-рубака", "gen": "анатемы-рубаки", "level": 8, "hp": 140, "atk": 23, "speed": 4.2, "xp": 120,
		"gold": [16, 30], "color": Color(0.2, 0.3, 0.18), "scale": 1.0, "rarity": "common", "tameable": false,
		"defense": 0.7, "attack_cd": 1.0,
		"loot": [["bone_blade", 0.5, 1, 1], ["lizard_scale", 0.4, 1, 1], ["hp_potion", 0.2, 1, 1],
			["revive_scroll", 0.06, 1, 1]],
	},
	# Вожак анатем — главный враг логова в пещере (вместо каменного стража): крепче остальных
	"anathema_chief": {
		"name": "Вожак анатем", "gen": "вожака анатем", "level": 10, "hp": 320, "atk": 24, "speed": 4.0, "xp": 260,
		"gold": [60, 120], "color": Color(0.24, 0.3, 0.18), "scale": 1.0, "rarity": "rare", "tameable": false,
		"defense": 0.8, "attack_cd": 1.1,
		"loot": [["chief_spike", 1.0, 1, 2], ["bone_blade", 0.5, 1, 1], ["hp_potion", 0.4, 1, 2],
			["revive_scroll", 0.15, 1, 1], ["mirror_card", 0.3, 1, 1]],
	},
	# Кабан и каменный страж — модели из примитивов: в мире больше не появляются (на острове только существа
	# Максима), данные — для совместимости (старые сохранения, тесты)
	"golem": {
		"name": "Каменный страж", "gen": "каменного стража", "level": 10, "hp": 400, "atk": 24, "speed": 2.6, "xp": 250, "gold": [60, 120],
		"color": Color(0.5, 0.5, 0.45), "scale": 2.0, "rarity": "unique", "tameable": false, "power": 1.0,
		"loot": [["golem_shard", 1.0, 1, 3], ["mirror_card", 0.3, 1, 1]],
	},
}


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


## Защита вида относительно обычной (1.0; поле "defense"): < 1 — по зверю проходит больше урона.
static func defense(id: String) -> float:
	return clampf(float(get_type(id).get("defense", 1.0)), 0.2, 3.0)


## Множитель получаемого зверем урона: 1 / защита (у анатем ≈ 1.4).
static func damage_taken(id: String) -> float:
	return 1.0 / defense(id)


## Пауза между ударами зверя, с (поле "attack_cd"; у анатем удары чаще).
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
