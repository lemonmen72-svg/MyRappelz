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
	# ---------- Подземелье (этап 2, 0.36; модели Максима из «ДАНЖ», клипы UAL): 20–30 ур. Решения Максима: обычные —
	# сила босса острова (поле dungeon: множители MobStats.BOSS_* × power), мини-боссы — HP ×2 к ним (dungeon_hp),
	# возрождение обычных как на острове, мини-боссов — 20 мин. Оружие в руке — weapon (assets/handheld/mw_*, кисть
	# hand, хват — grips в creatures.json). Зоны — world/dungeon.json mob_zones (логово гоблинов, склеп, святилище, причал).
	"dg_goblin": {
		"name": "Гоблин-мародёр", "gen": "гоблина-мародёра", "level": 20, "speed": 4.4, "gold": [20, 40],
		"color": Color(0.35, 0.5, 0.25), "scale": 1.0, "rarity": "uncommon", "tameable": false, "dungeon": true,
		"power": 1.5, "mini_boss": false, "attack_cd": 1.1, "weapon": "mw_rusty_dagger",
		"loot": ["goblin_token", "rusty_buckle"],
	},
	"dg_goblin_chief": {
		"name": "Вождь гоблинов", "gen": "вождя гоблинов", "level": 23, "speed": 4.2, "gold": [60, 120],
		"color": Color(0.3, 0.45, 0.22), "scale": 1.0, "rarity": "rare", "tameable": false, "dungeon": true,
		"power": 1.5, "mini_boss": true, "dungeon_hp": 2.0, "respawn": 1200.0, "attack_cd": 1.3,
		"weapon": "mw_broad_sword", "loot": ["goblin_token", "warlord_tusk"], "mirror": true,
	},
	"dg_sailor": {
		"name": "Мёртвый матрос", "gen": "мёртвого матроса", "level": 22, "speed": 3.6, "gold": [24, 46],
		"color": Color(0.3, 0.42, 0.36), "scale": 1.0, "rarity": "uncommon", "tameable": false, "dungeon": true,
		"power": 1.5, "mini_boss": false, "attack_cd": 1.3, "weapon": "mw_cleaver",
		"loot": ["brine_rag", "sea_bone"], "undead": true,
	},
	"dg_graveguard": {
		"name": "Мёртвый страж", "gen": "мёртвого стража", "level": 24, "speed": 3.6, "gold": [28, 52],
		"color": Color(0.3, 0.4, 0.34), "scale": 1.0, "rarity": "uncommon", "tameable": false, "dungeon": true,
		"power": 1.5, "mini_boss": false, "defense": 1.15, "attack_cd": 1.4, "weapon": "mw_knight_sword",
		"loot": ["dead_plate", "grave_chain"], "undead": true, "knight": true,
	},
	"dg_wight": {
		"name": "Мёртвый мечник", "gen": "мёртвого мечника", "level": 24, "speed": 3.8, "gold": [28, 52],
		"color": Color(0.28, 0.4, 0.34), "scale": 1.0, "rarity": "uncommon", "tameable": false, "dungeon": true,
		"power": 1.5, "mini_boss": false, "attack_cd": 1.3, "weapon": "mw_longsword",
		"loot": ["dead_plate", "grave_chain"], "undead": true, "knight": true,
	},
	"dg_dead_knight": {
		"name": "Мёртвый рыцарь", "gen": "Мёртвого рыцаря", "level": 26, "speed": 3.6, "gold": [80, 150],
		"color": Color(0.22, 0.3, 0.26), "scale": 1.0, "rarity": "rare", "tameable": false, "dungeon": true,
		"power": 1.5, "mini_boss": true, "dungeon_hp": 2.0, "respawn": 1200.0, "defense": 1.15, "attack_cd": 1.6,
		"weapon": "mw_bastard_sword", "loot": ["dead_plate", "black_seal"], "mirror": true, "undead": true, "knight": true,
	},
	"dg_bone_oracle": {
		"name": "Костяной жрец", "gen": "костяного жреца", "level": 26, "speed": 3.4, "gold": [30, 56],
		"color": Color(0.34, 0.46, 0.34), "scale": 1.0, "rarity": "uncommon", "tameable": false, "dungeon": true,
		"power": 1.5, "mini_boss": false, "magic": true, "defense": 0.85, "attack_cd": 1.5,
		"loot": ["sect_candle", "ritual_ash"], "undead": true, "sect": true,
	},
	"dg_grave_oracle": {
		"name": "Могильный жрец", "gen": "могильного жреца", "level": 26, "speed": 3.4, "gold": [30, 56],
		"color": Color(0.32, 0.44, 0.32), "scale": 1.0, "rarity": "uncommon", "tameable": false, "dungeon": true,
		"power": 1.5, "mini_boss": false, "magic": true, "defense": 0.85, "attack_cd": 1.4, "weapon": "mw_ritual_dagger",
		"loot": ["sect_candle", "ritual_ash"], "undead": true, "sect": true,
	},
	"dg_plague_shaman": {
		"name": "Чумной шаман", "gen": "чумного шамана", "level": 27, "speed": 3.4, "gold": [32, 60],
		"color": Color(0.36, 0.5, 0.28), "scale": 1.0, "rarity": "uncommon", "tameable": false, "dungeon": true,
		"power": 1.5, "mini_boss": false, "magic": true, "defense": 0.85, "attack_cd": 1.5,
		"loot": ["sect_candle", "ritual_ash"], "sect": true,
	},
	"dg_sect_wraith": {
		"name": "Призрак секты", "gen": "призрака секты", "level": 28, "speed": 3.8, "gold": [34, 62],
		"color": Color(0.25, 0.45, 0.36), "scale": 1.0, "rarity": "uncommon", "tameable": false, "dungeon": true,
		"power": 1.5, "mini_boss": false, "attack_cd": 1.5, "weapon": "mw_scythe",
		"loot": ["sect_candle", "ritual_ash"], "undead": true, "sect": true,
	},
	"dg_elder_priest": {
		"name": "Старший жрец", "gen": "Старшего жреца", "level": 29, "speed": 3.4, "gold": [90, 170],
		"color": Color(0.3, 0.5, 0.34), "scale": 1.0, "rarity": "rare", "tameable": false, "dungeon": true,
		"power": 1.5, "mini_boss": true, "dungeon_hp": 2.0, "respawn": 1200.0, "magic": true, "defense": 0.9,
		"attack_cd": 1.6, "weapon": "mw_runic_sword", "loot": ["ritual_ash", "sect_sigil"], "mirror": true, "sect": true,
	},
	"dg_coral_corsair": {
		"name": "Коралловый корсар", "gen": "кораллового корсара", "level": 28, "speed": 3.8, "gold": [34, 62],
		"color": Color(0.38, 0.42, 0.36), "scale": 1.0, "rarity": "uncommon", "tameable": false, "dungeon": true,
		"power": 1.5, "mini_boss": false, "attack_cd": 1.5, "weapon": "mw_axe",
		"loot": ["brine_rag", "coral_shard"], "undead": true,
	},
	"dg_rot_corsair": {
		"name": "Гнилой корсар", "gen": "гнилого корсара", "level": 28, "speed": 3.8, "gold": [34, 62],
		"color": Color(0.34, 0.44, 0.3), "scale": 1.0, "rarity": "uncommon", "tameable": false, "dungeon": true,
		"power": 1.5, "mini_boss": false, "attack_cd": 1.3, "weapon": "mw_cutlass",
		"loot": ["brine_rag", "sea_bone"], "undead": true,
	},
	"dg_reef_wraith": {
		"name": "Рифовый утопленник", "gen": "рифового утопленника", "level": 29, "speed": 3.6, "gold": [36, 66],
		"color": Color(0.26, 0.45, 0.42), "scale": 1.0, "rarity": "uncommon", "tameable": false, "dungeon": true,
		"power": 1.5, "mini_boss": false, "attack_cd": 1.4, "weapon": "mw_curved_dagger",
		"loot": ["coral_shard", "sea_bone"], "undead": true,
	},
	# Питомцы подземелья (этап 3, 0.37): «Обычные», приручаются (синяя карта), в подземелье — его сила (dungeon).
	# Модель — стадия по уровню (MobStats.stage_for: 22+ — 3-я), оружие скелета — по стадии (weapons).
	"skeleton": {
		"name": "Скелет", "gen": "скелета", "level": 21, "speed": 4.0, "gold": [26, 48],
		"color": Color(0.82, 0.86, 0.74), "scale": 0.8, "rarity": "uncommon", "dungeon": true, "power": 1.5,
		"mini_boss": false, "attack_cd": 1.2, "weapons": ["mw_rusty_dagger", "mw_shortsword", "mw_straight_sword"],
		"loot": ["skeleton_bone", "grave_chain"], "undead": true,
	},
	"octopus": {
		"name": "Спрут", "gen": "спрута", "level": 26, "speed": 3.6, "gold": [30, 56],
		"color": Color(0.3, 0.72, 0.6), "scale": 0.85, "rarity": "uncommon", "dungeon": true, "power": 1.5,
		"mini_boss": false, "magic": true, "attack_cd": 1.5, "loot": ["octopus_tentacle", "coral_shard"],
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


## Монстр подземелья (поле dungeon): сила босса острова (MobStats.derived).
static func is_dungeon(id: String) -> bool:
	return TYPES.has(id) and bool(get_type(id).get("dungeon", false))


## Оружие в руке модели монстра (id модели assets/handheld, "" — без оружия).
## У питомцев подземелья (скелет) — по стадии модели: поле weapons [1-я, 2-я, 3-я].
static func weapon_of(id: String, stage: int = 0) -> String:
	var d := get_type(id)
	if d.has("weapons"):
		var w: Array = d["weapons"]
		return String(w[clampi(stage, 0, w.size() - 1)])
	return String(d.get("weapon", ""))


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


## Золото за зверя — база оригинала (MonsterResource, решение Максима 04.11): обычный зверь уровня L — вилка
## GOLD_MIN / GOLD_MAX (медиана обычных зверей уровня, 1–60, выше — как 60), × GOLD_MULT (решение Максима 01.11:
## «количество выпадаемых денег увеличь в 4 раза»), × сила редкости MobData.power; мини-босс — ×GOLD_ELITE (элитный
## зверь оригинала), босс — ×GOLD_BOSS (именной). Золото выпадает с шансом GOLD_CHANCE (80 %, как в оригинале).
const GOLD_MULT := 4.0
const GOLD_CHANCE := 0.8
const GOLD_ELITE := 8.44
const GOLD_BOSS := 7.5
const GOLD_MIN := [4, 6, 8, 13, 13, 13, 14, 21, 21, 22, 22, 26, 26, 26, 26, 27, 29, 30, 31, 33, 34, 35, 37, 38, 39, 41, 42,
	43, 44, 46, 47, 49, 50, 52, 53, 54, 56, 57, 58, 59, 61, 62, 63, 64, 65, 66, 68, 69, 70, 95, 95, 95, 95, 95, 95, 95, 95, 95,
	95, 95]
const GOLD_MAX := [7, 10, 13, 21, 22, 22, 24, 35, 35, 37, 37, 42, 42, 42, 43, 46, 48, 50, 52, 54, 57, 59, 61, 63, 65, 68, 70,
	72, 74, 76, 79, 82, 84, 86, 88, 91, 93, 95, 97, 99, 101, 103, 105, 107, 109, 111, 113, 114, 116, 158, 158, 158, 158, 158,
	158, 158, 158, 158, 158, 158]


static func gold_range(id: String, lvl: int) -> Array:
	var i := clampi(lvl, 1, GOLD_MIN.size()) - 1
	var k := GOLD_MULT * power(id)
	if is_boss(id):
		k *= GOLD_BOSS
	elif is_mini_boss(id):
		k *= GOLD_ELITE
	return [maxi(1, roundi(float(GOLD_MIN[i]) * k)), maxi(1, roundi(float(GOLD_MAX[i]) * k))]


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
