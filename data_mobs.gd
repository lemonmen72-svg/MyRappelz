class_name MobData
extends RefCounted
## Звери мира: характеристики, редкость, приручение (карта существа и её тир), добыча.
## Где и какого уровня они появляются — mob_zones в world/training_island.json.
## id зверя совпадает с id вида питомца (PetData). Пантера, черепаха и фазан — модели из файлов
## (CreatureAsset, assets/creatures/), остальные — из примитивов (CreatureModels).

## Радиус безопасной зоны города новичков в центре мира (там торговец, звери туда не заходят).
## Источник правды — safe_zones в world/training_island.json; здесь — для кода без острова.
const SAFE_RADIUS := 22.0

## Ранг редкости (сортировка, сравнение).
const RARITY_TIER := {"common": 1, "rare": 2, "unique": 3}
## Тир карты существа по редкости зверя (если у вида нет поля "card"): базовая (коричневая) — обычные звери,
## редкая (синяя) — боссы поверхности и чемпионы, особая (фиолетовая) — только полем "card", уникальная
## (жёлтая) — боссы. Цвета и названия тиров — ItemData.CARD_TIERS, шанс приручения — Taming.CHANCE.
const CARD_TIER_BY_RARITY := {"common": "basic", "rare": "rare", "unique": "unique"}
## Названия редкостей для игрока («common» — «Базовый»).
const RARITY_NAMES := {"common": "Базовый", "rare": "Редкий", "unique": "Уникальный"}
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
	"wolf": {
		"name": "Волк", "gen": "волка", "level": 3, "hp": 50, "atk": 9, "speed": 4.4, "xp": 25, "gold": [4, 9],
		"color": Color(0.5, 0.5, 0.55), "scale": 1.0, "rarity": "common",
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
	"golem": {
		"name": "Каменный страж", "gen": "каменного стража", "level": 10, "hp": 400, "atk": 24, "speed": 2.6, "xp": 250, "gold": [60, 120],
		"color": Color(0.5, 0.5, 0.45), "scale": 2.0, "rarity": "unique", "tameable": false,
		"loot": [["golem_shard", 1.0, 1, 3], ["mirror_card", 0.3, 1, 1]],
	},
}


static func get_type(id: String) -> Dictionary:
	return TYPES.get(id, TYPES["boar"])


static func rarity_tier(id: String) -> int:
	return int(RARITY_TIER.get(get_type(id)["rarity"], 1))


## Можно ли приручить зверя этого вида (неизвестный вид — нельзя).
static func tameable(id: String) -> bool:
	return TYPES.has(id) and bool(get_type(id).get("tameable", true))


## Тир карты существа для вида: "basic" | "rare" | "special" | "unique".
static func card_tier(id: String) -> String:
	var d := get_type(id)
	return String(d.get("card", CARD_TIER_BY_RARITY.get(String(d["rarity"]), "basic")))


## Название вида в родительном падеже, со строчной («пантеры»).
static func name_gen(id: String) -> String:
	var d := get_type(id)
	return String(d.get("gen", String(d["name"]).to_lower()))


## Редкость зверя для игрока: «Базовый», «Редкий», «Уникальный».
static func rarity_name(id: String) -> String:
	return rarity_label(String(get_type(id)["rarity"]))


static func rarity_label(rarity: String) -> String:
	return String(RARITY_NAMES.get(rarity, RARITY_NAMES["common"]))


## Новый id зверя по прежнему (из старого сохранения); неизвестный и актуальный — как есть.
static func migrate_id(id: String) -> String:
	return String(RENAMED.get(id, id))
