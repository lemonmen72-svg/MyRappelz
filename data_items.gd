class_name ItemData
extends RefCounted
## Предметы. type: "card" (карта существа — приручение), "consumable" (расходник), "trophy" (на продажу),
## "weapon" (оружие).
## buy: цена покупки у NPC (0 = не продаётся; кто чем торгует — NpcData.shop: зелья, свиток и оружие — торговец,
## карты существ и зеркальная карта — Учитель Кирк), sell: цена продажи торговцу.
## Оружие (type "weapon"): weapon — вид (WEAPON_KINDS: одноручный и двуручный меч, кинжал, одноручная и двуручная
## булава, топоры, посохи, арбалет, лук, щит), atk — физ. атака, matk — маг. атака, def — физ. защита и block — шанс
## блока (щит): действуют только те, что есть у вида (WEAPON_KINDS stats; там же скорость атаки и каста вида),
## range — дальность, м, crit — прибавка к шансу крита, rank — ранг (EQUIP_RANKS: 1 — 1–20 ур., 2 — 21–50…; надеть —
## с нижнего уровня ранга, level_block), model — файл модели в руках (Handheld; нет — модель вида). Кому подходит — по виду:
## ClassData weapons профессии (weapon_fits; Бродяге — любое). Надетое оружие — Game.weapon, вторая рука —
## Game.offhand (щит или второе такое же одноручное — пара, offhand_block); id предметов лежат в сумке,
## но в окне сумки показаны в слотах экипировки, а не в ячейках.
## Для окна сумки: rarity — редкость ("common" по умолчанию, "improved", "rare", "unique": цвет рамки ячейки),
## icon — что рисовать процедурным значком, пока нет картинки (ItemIcon: "flask", "scroll", "card",
## "dagger", "daggers", "sword", "swords", "crossbow", "bow", "fang", "pelt", "feather", "plate", "shard"), stack —
## размер стопки в ячейке (по умолчанию 99, у оружия 1). Картинка значка: res://assets/icons/items/<id>.png (128×128, прозрачные углы).
## Карты существ (type "card", приручение — Taming): species — вид зверя (MobData), soul = true — карта с пойманной
## душой (из неё формируется питомец). Пустая карта вида — card_<вид> (стопка до CARD_STACK), заполненная —
## card_<вид>_soul (по одной в ячейке), зеркальная карта mirror_card (без вида) — ломается вместо карты существа
## при неудачном приручении. Тир и цвет карты — по виду (MobData.card_tier, CARD_TIERS).
## Зелья (potion_<вид>_r<ранг>: здоровье, мана, скорость атаки, каста, бега; ранги 1–15) — POTION_KINDS, строятся
## в _static_init; ITEMS — BASE_ITEMS + зелья. Ранги предметов и требования уровня — «Ранги предметов» ниже.
## Добыча со зверей и случайные награды заданий — LootTable.

const BASE_ITEMS := {
	# ---------- Карты существ: базовые продаёт Учитель Кирк, остальные выпадают из зверей своего вида ----------
	"card_panther": {
		"name": "Карта существа: Пантера", "type": "card", "species": "panther", "icon": "card", "stack": 20,
		"buy": 25, "sell": 8, "color": Color(0.62, 0.52, 0.78), "desc": "Чистая карта: ловит дух пантеры.",
	},
	"card_turtle": {
		"name": "Карта существа: Черепаха", "type": "card", "species": "turtle", "icon": "card", "stack": 20,
		"buy": 25, "sell": 8, "color": Color(0.5, 0.72, 0.45), "desc": "Чистая карта: ловит дух черепахи.",
	},
	"card_pheasant": {
		"name": "Карта существа: Фазан", "type": "card", "species": "pheasant", "icon": "card", "stack": 20,
		"buy": 25, "sell": 8, "color": Color(0.9, 0.58, 0.3), "desc": "Чистая карта: ловит дух фазана.",
	},
	"card_wolf": {
		"name": "Карта существа: Волк", "type": "card", "species": "wolf", "icon": "card", "stack": 20,
		"buy": 0, "sell": 12, "color": Color(0.66, 0.68, 0.74), "desc": "Чистая карта: ловит дух волка.",
	},
	"card_centaur": {
		"name": "Карта существа: Кентавр", "type": "card", "species": "centaur", "icon": "card", "stack": 20,
		"buy": 0, "sell": 20, "color": Color(0.78, 0.58, 0.38), "desc": "Чистая карта: ловит дух кентавра.",
	},
	"card_panther_soul": {
		"name": "Карта пантеры (с душой)", "type": "card", "species": "panther", "soul": true, "icon": "card",
		"stack": 1, "buy": 0, "sell": 15, "color": Color(0.62, 0.52, 0.78), "desc": "В карте спит пойманная душа пантеры.",
	},
	"card_turtle_soul": {
		"name": "Карта черепахи (с душой)", "type": "card", "species": "turtle", "soul": true, "icon": "card",
		"stack": 1, "buy": 0, "sell": 15, "color": Color(0.5, 0.72, 0.45), "desc": "В карте спит пойманная душа черепахи.",
	},
	"card_pheasant_soul": {
		"name": "Карта фазана (с душой)", "type": "card", "species": "pheasant", "soul": true, "icon": "card",
		"stack": 1, "buy": 0, "sell": 15, "color": Color(0.9, 0.58, 0.3), "desc": "В карте спит пойманная душа фазана.",
	},
	"card_wolf_soul": {
		"name": "Карта волка (с душой)", "type": "card", "species": "wolf", "soul": true, "icon": "card",
		"stack": 1, "buy": 0, "sell": 18, "color": Color(0.66, 0.68, 0.74), "desc": "В карте спит пойманная душа волка.",
	},
	"card_centaur_soul": {
		"name": "Карта кентавра (с душой)", "type": "card", "species": "centaur", "soul": true, "icon": "card",
		"stack": 1, "buy": 0, "sell": 30, "color": Color(0.78, 0.58, 0.38), "desc": "В карте спит пойманная душа кентавра.",
	},
	"mirror_card": {
		"name": "Зеркальная карта", "type": "card", "icon": "card", "stack": 20, "buy": 60, "sell": 20,
		"color": Color(0.82, 0.88, 0.98),
		"desc": "Оберег для приручения: если попытка не удалась, ломается зеркальная карта, а карта существа остаётся цела.",
	},
	# Зелья (potion_<вид>_r<ранг>) — не здесь: их 5 видов × 15 рангов строит _static_init (POTION_KINDS)
	"revive_scroll": {
		"name": "Свиток воскрешения", "type": "consumable", "icon": "scroll", "buy": 30, "sell": 10,
		"color": Color(0.95, 0.9, 0.6), "desc": "Воскрешает погибшего питомца.",
	},
	# ---------- Оружие 1-го ранга (ур. 1–20): у торговца; стартовое у Бродяги и профессий (STARTER_WEAPONS) ----------
	# Бонусы — по виду (WEAPON_KINDS stats / aspd / cast): из чисел atk, matk, def, block действуют только те, что есть у вида.
	"weapon_sword_1h_r1": {
		"name": "Учебный меч", "type": "weapon", "icon": "sword", "weapon": "sword_1h", "rank": 1,
		"atk": 4, "range": 2.6, "crit": 0.02, "buy": 40, "sell": 8,
		"color": Color(0.85, 0.87, 0.92), "desc": "Простой одноручный меч новичка. Вторая рука свободна — для щита или второго меча.",
	},
	"weapon_sword_2h_r1": {
		"name": "Двуручный меч новичка", "type": "weapon", "icon": "swords", "weapon": "sword_2h", "rank": 1,
		"atk": 8, "range": 2.9, "crit": 0.02, "buy": 55, "sell": 12,
		"color": Color(0.8, 0.83, 0.92), "desc": "Длинный тяжёлый клинок: бьёт реже, но сильнее.",
	},
	"weapon_dagger_r1": {
		"name": "Кинжал новичка", "type": "weapon", "icon": "dagger", "weapon": "dagger", "rank": 1,
		"atk": 2, "matk": 2, "range": 2.2, "crit": 0.05, "buy": 35, "sell": 7,
		"color": Color(0.78, 0.75, 0.9), "desc": "Короткий клинок: частые удары и больше критов, немного помогает и магии.",
	},
	"weapon_mace_1h_r1": {
		"name": "Учебная булава", "type": "weapon", "icon": "mace", "weapon": "mace_1h", "rank": 1,
		"atk": 4, "matk": 2, "range": 2.5, "crit": 0.0, "buy": 40, "sell": 8,
		"color": Color(0.72, 0.7, 0.66), "desc": "Окованная булава в одну руку. Хороша со щитом.",
	},
	"weapon_mace_2h_r1": {
		"name": "Тяжёлая булава новичка", "type": "weapon", "icon": "mace", "weapon": "mace_2h", "rank": 1,
		"atk": 7, "matk": 4, "range": 2.8, "crit": 0.0, "buy": 55, "sell": 12,
		"color": Color(0.68, 0.66, 0.62), "desc": "Двуручная булава: медленно, зато каждый удар чувствуется.",
	},
	"weapon_axe_1h_r1": {
		"name": "Учебный топор", "type": "weapon", "icon": "axe", "weapon": "axe_1h", "rank": 1,
		"atk": 4, "matk": 1, "range": 2.5, "crit": 0.03, "buy": 40, "sell": 8,
		"color": Color(0.8, 0.72, 0.6), "desc": "Лёгкий топор в одну руку. Во второй руке может быть ещё один.",
	},
	"weapon_axe_2h_r1": {
		"name": "Двуручный топор новичка", "type": "weapon", "icon": "axe", "weapon": "axe_2h", "rank": 1,
		"atk": 8, "matk": 2, "range": 2.9, "crit": 0.04, "buy": 55, "sell": 12,
		"color": Color(0.78, 0.68, 0.55), "desc": "Широкое лезвие на длинной рукояти: самый тяжёлый удар среди оружия новичка.",
	},
	"weapon_staff_1h_r1": {
		"name": "Жезл новичка", "type": "weapon", "icon": "staff", "weapon": "staff_1h", "rank": 1,
		"matk": 4, "range": 9.0, "crit": 0.0, "buy": 40, "sell": 8,
		"color": Color(0.82, 0.68, 0.45), "desc": "Короткий посох: обычная атака — сгусток магии издалека, заклинания быстрее. Вторая рука свободна.",
	},
	"weapon_staff_2h_r1": {
		"name": "Посох новичка", "type": "weapon", "icon": "staff", "weapon": "staff_2h", "rank": 1,
		"matk": 7, "range": 10.0, "crit": 0.0, "buy": 55, "sell": 12,
		"color": Color(0.8, 0.64, 0.4), "desc": "Посох в две руки: магия сильнее, сгусток летит дальше.",
	},
	"weapon_spear_r1": {
		"name": "Копьё новичка", "type": "weapon", "icon": "spear", "weapon": "spear", "rank": 1,
		"atk": 7, "range": 3.3, "crit": 0.03, "buy": 55, "sell": 12,
		"color": Color(0.82, 0.8, 0.72), "desc": "Длинное копьё в две руки: достаёт зверя дальше меча, бьёт сильно и точно.",
	},
	"weapon_shield_r1": {
		"name": "Деревянный щит", "type": "weapon", "icon": "shield", "weapon": "shield", "rank": 1,
		"def": 3, "block": 0.1, "range": 0.0, "crit": 0.0, "buy": 35, "sell": 7,
		"color": Color(0.62, 0.45, 0.28), "desc": "Щит во вторую руку (к одноручному оружию): защита выше, часть ударов приходится в щит.",
	},
	"weapon_bow_r1": {
		"name": "Лук новичка", "type": "weapon", "icon": "bow", "weapon": "bow", "rank": 1,
		"atk": 9, "range": 13.0, "crit": 0.03, "buy": 50, "sell": 10,
		"color": Color(0.62, 0.44, 0.26), "desc": "Простой лук в две руки: стрелы летят дальше всех, но натягивать тетиву долго.",
	},
	"crossbow_starter": {
		"name": "Лёгкий арбалет", "type": "weapon", "icon": "crossbow", "weapon": "crossbow", "rank": 1,
		"atk": 6, "range": 11.0, "crit": 0.0, "buy": 50, "sell": 10,
		"color": Color(0.72, 0.52, 0.32), "desc": "Стреляет болтами издалека, но реже.",
	},
	# ---------- Оружие 2-го ранга (ур. 21–50): на острове не продаётся (только 1-й ранг), выпадает из зверей 21+ ур.
	# и бывает в награде заданий. Числа — ×3.25 к 1-му рангу: атака героя без оружия в середине 2-го ранга (35 ур.,
	# ≈ 90) в 3.3 раза выше, чем в середине 1-го (10 ур., ≈ 27) — доля оружия в атаке та же (≈ 15 %). Модель —
	# assets/handheld/weapon_<вид>_r2.glb (поле model; нет файла — модель вида 1-го ранга, Handheld.model_for).
	"weapon_sword_1h_r2": {
		"name": "Меч стражника", "type": "weapon", "icon": "sword", "weapon": "sword_1h", "rank": 2,
		"model": "weapon_sword_1h_r2", "atk": 13, "range": 2.6, "crit": 0.03, "buy": 0, "sell": 32,
		"color": Color(0.82, 0.88, 0.96), "desc": "Надёжный одноручный меч стражи. Вторая рука свободна — для щита или второго меча.",
	},
	"weapon_sword_2h_r2": {
		"name": "Двуручный меч ветерана", "type": "weapon", "icon": "swords", "weapon": "sword_2h", "rank": 2,
		"model": "weapon_sword_2h_r2", "atk": 26, "range": 2.9, "crit": 0.03, "buy": 0, "sell": 48,
		"color": Color(0.78, 0.84, 0.95), "desc": "Тяжёлый клинок бывалого бойца: бьёт реже, но рассекает надвое.",
	},
	"weapon_dagger_r2": {
		"name": "Кинжал следопыта", "type": "weapon", "icon": "dagger", "weapon": "dagger", "rank": 2,
		"model": "weapon_dagger_r2", "atk": 7, "matk": 7, "range": 2.2, "crit": 0.06, "buy": 0, "sell": 28,
		"color": Color(0.76, 0.74, 0.95), "desc": "Узкий клинок с рунной канавкой: частые удары, много критов, помогает и магии.",
	},
	"weapon_mace_1h_r2": {
		"name": "Булава стражника", "type": "weapon", "icon": "mace", "weapon": "mace_1h", "rank": 2,
		"model": "weapon_mace_1h_r2", "atk": 13, "matk": 7, "range": 2.5, "crit": 0.0, "buy": 0, "sell": 32,
		"color": Color(0.74, 0.72, 0.68), "desc": "Шипастая булава в одну руку. Хороша со щитом.",
	},
	"weapon_mace_2h_r2": {
		"name": "Тяжёлая булава ветерана", "type": "weapon", "icon": "mace", "weapon": "mace_2h", "rank": 2,
		"model": "weapon_mace_2h_r2", "atk": 23, "matk": 13, "range": 2.8, "crit": 0.0, "buy": 0, "sell": 48,
		"color": Color(0.7, 0.68, 0.64), "desc": "Окованная двуручная булава: медленно, зато зверь чувствует каждый удар.",
	},
	"weapon_axe_1h_r2": {
		"name": "Топор следопыта", "type": "weapon", "icon": "axe", "weapon": "axe_1h", "rank": 2,
		"model": "weapon_axe_1h_r2", "atk": 13, "matk": 3, "range": 2.5, "crit": 0.04, "buy": 0, "sell": 32,
		"color": Color(0.82, 0.74, 0.62), "desc": "Острый топор в одну руку. Во второй руке может быть ещё один.",
	},
	"weapon_axe_2h_r2": {
		"name": "Секира ветерана", "type": "weapon", "icon": "axe", "weapon": "axe_2h", "rank": 2,
		"model": "weapon_axe_2h_r2", "atk": 26, "matk": 7, "range": 2.9, "crit": 0.05, "buy": 0, "sell": 48,
		"color": Color(0.8, 0.7, 0.56), "desc": "Широкая секира на длинном древке: самый тяжёлый удар среди оружия 2-го ранга.",
	},
	"weapon_staff_1h_r2": {
		"name": "Жезл чародея", "type": "weapon", "icon": "staff", "weapon": "staff_1h", "rank": 2,
		"model": "weapon_staff_1h_r2", "matk": 13, "range": 9.0, "crit": 0.0, "buy": 0, "sell": 32,
		"color": Color(0.84, 0.7, 0.48), "desc": "Жезл с кристаллом в навершии: сгусток магии издалека, заклинания быстрее. Вторая рука свободна.",
	},
	"weapon_staff_2h_r2": {
		"name": "Посох чародея", "type": "weapon", "icon": "staff", "weapon": "staff_2h", "rank": 2,
		"model": "weapon_staff_2h_r2", "matk": 23, "range": 10.0, "crit": 0.0, "buy": 0, "sell": 48,
		"color": Color(0.82, 0.66, 0.42), "desc": "Посох в две руки из старого дерева: магия сильнее, сгусток летит дальше.",
	},
	"weapon_spear_r2": {
		"name": "Копьё ветерана", "type": "weapon", "icon": "spear", "weapon": "spear", "rank": 2,
		"model": "weapon_spear_r2", "atk": 23, "range": 3.3, "crit": 0.04, "buy": 0, "sell": 48,
		"color": Color(0.84, 0.82, 0.74), "desc": "Длинное копьё с широким наконечником: достаёт зверя дальше меча.",
	},
	"weapon_shield_r2": {
		"name": "Окованный щит", "type": "weapon", "icon": "shield", "weapon": "shield", "rank": 2,
		"model": "weapon_shield_r2", "def": 10, "block": 0.14, "range": 0.0, "crit": 0.0, "buy": 0, "sell": 28,
		"color": Color(0.66, 0.5, 0.32), "desc": "Щит с железной оковкой во вторую руку (к одноручному оружию): защита выше, часть ударов приходится в щит.",
	},
	"weapon_bow_r2": {
		"name": "Охотничий лук", "type": "weapon", "icon": "bow", "weapon": "bow", "rank": 2,
		"model": "weapon_bow_r2", "atk": 29, "range": 13.0, "crit": 0.04, "buy": 0, "sell": 40,
		"color": Color(0.66, 0.48, 0.28), "desc": "Тугой лук в две руки: стрелы летят дальше всех, но натягивать тетиву долго.",
	},
	"weapon_crossbow_r2": {
		"name": "Арбалет стражника", "type": "weapon", "icon": "crossbow", "weapon": "crossbow", "rank": 2,
		"model": "weapon_crossbow_r2", "atk": 20, "range": 11.5, "crit": 0.01, "buy": 0, "sell": 40,
		"color": Color(0.74, 0.54, 0.34), "desc": "Арбалет с воротом: болты пробивают шкуру издалека, но заряжать его дольше.",
	},
	# ---------- Улучшенное оружие у торговца ----------
	"dagger_steel": {
		"name": "Стальной кинжал", "type": "weapon", "icon": "dagger", "rarity": "improved", "weapon": "dagger", "rank": 1,
		"atk": 4, "matk": 3, "range": 2.2, "crit": 0.06, "buy": 60, "sell": 20,
		"color": Color(0.7, 0.8, 1.0), "desc": "Закалённый кинжал странницы. Два таких — в обе руки.",
	},
	"sword_steel": {
		"name": "Стальной меч", "type": "weapon", "icon": "sword", "rarity": "improved", "weapon": "sword_1h", "rank": 1,
		"atk": 7, "range": 2.6, "crit": 0.01, "buy": 60, "sell": 20,
		"color": Color(0.75, 0.9, 1.0), "desc": "Закалённый одноручный меч. Два таких — в обе руки.",
	},
	"crossbow_heavy": {
		"name": "Тяжёлый арбалет", "type": "weapon", "icon": "crossbow", "rarity": "improved", "weapon": "crossbow", "rank": 1,
		"atk": 11, "range": 12.0, "crit": 0.02, "buy": 140, "sell": 45,
		"color": Color(0.85, 0.6, 0.35), "desc": "Мощные болты, бьёт чуть дальше.",
	},
	"boar_tusk": {"name": "Клык кабана", "type": "trophy", "icon": "fang", "buy": 0, "sell": 4, "color": Color(0.95, 0.9, 0.8), "desc": "Крепкий изогнутый клык кабана. Трофей для торговца."},
	"wolf_pelt": {"name": "Волчья шкура", "type": "trophy", "icon": "pelt", "buy": 0, "sell": 7, "color": Color(0.6, 0.6, 0.65), "desc": "Серая шкура с густым мехом. Трофей для торговца."},
	"panther_fang": {"name": "Клык пантеры", "type": "trophy", "icon": "fang", "buy": 0, "sell": 12, "color": Color(0.9, 0.86, 0.95), "desc": "Острый клык пантеры. Трофей для торговца."},
	"pheasant_feather": {"name": "Перо фазана", "type": "trophy", "icon": "feather", "buy": 0, "sell": 15, "color": Color(0.85, 0.5, 0.2), "desc": "Яркое рыжее перо. Трофей для торговца."},
	"shell_plate": {"name": "Пластина панциря", "type": "trophy", "icon": "plate", "buy": 0, "sell": 18, "color": Color(0.45, 0.6, 0.35), "desc": "Прочная пластина черепашьего панциря. Трофей для торговца."},
	"golem_shard": {"name": "Осколок стража", "type": "trophy", "icon": "shard", "rarity": "rare", "buy": 0, "sell": 40, "color": Color(0.55, 0.55, 0.5), "desc": "Обломок каменного стража, в трещинах мерцают руны. Ценный трофей."},
	"flyfish_scale": {"name": "Летучая чешуя", "type": "trophy", "icon": "scale", "buy": 0, "sell": 10, "color": Color(0.35, 0.55, 0.85), "desc": "Лёгкая синяя чешуйка летучего зубана, переливается на свету. Трофей для торговца."},
	"sail_fin": {"name": "Плавник-парус", "type": "trophy", "icon": "fin", "buy": 0, "sell": 16, "color": Color(0.95, 0.6, 0.3), "desc": "Тонкий плавник рыбы-парусника с прочными лучами. Трофей для торговца."},
	"drake_crest": {"name": "Гребень змеекрыла", "type": "trophy", "icon": "fin", "buy": 0, "sell": 30, "color": Color(0.3, 0.45, 0.8), "desc": "Колючий гребень змеекрыла, ещё хранит запах ветра. Ценный трофей."},
	# Трофеи кентавра
	"spear_tip": {"name": "Наконечник копья", "type": "trophy", "icon": "spike", "buy": 0, "sell": 26, "color": Color(0.78, 0.8, 0.86), "desc": "Стальной наконечник копья кентавра, по лезвию — степной узор. Ценный трофей."},
	"horse_hair": {"name": "Конский волос", "type": "trophy", "icon": "pelt", "buy": 0, "sell": 14, "color": Color(0.42, 0.26, 0.15), "desc": "Жёсткая прядь из хвоста кентавра, годится на тетиву. Трофей для торговца."},
	# Трофеи анатем (ящеры с костяными клинками)
	"lizard_scale": {"name": "Чешуя ящера", "type": "trophy", "icon": "scale", "buy": 0, "sell": 12, "color": Color(0.3, 0.45, 0.25), "desc": "Жёсткая тёмно-зелёная чешуя анатемы. Трофей для торговца."},
	"bone_blade": {"name": "Костяной клинок", "type": "trophy", "icon": "fang", "buy": 0, "sell": 22, "color": Color(0.92, 0.88, 0.78), "desc": "Изогнутый костяной серп с предплечья анатемы-рубаки, острый как сталь. Ценный трофей."},
	"chief_spike": {"name": "Шип вожака", "type": "trophy", "icon": "spike", "rarity": "rare", "buy": 0, "sell": 40, "color": Color(0.85, 0.8, 0.68), "desc": "Костяной шип с плеча вожака анатем, весь в зазубринах. Ценный трофей."},
	# Трофеи боссов (MobData boss_*): выпадают всегда
	"golden_plume": {"name": "Пламенное перо", "type": "trophy", "icon": "feather", "rarity": "rare", "buy": 0, "sell": 70, "color": Color(1.0, 0.72, 0.25), "desc": "Перо Пламенного Златохвоста, тёплое, будто из костра. Трофей босса."},
	"storm_fang": {"name": "Клык бури", "type": "trophy", "icon": "fang", "rarity": "rare", "buy": 0, "sell": 85, "color": Color(0.78, 0.84, 1.0), "desc": "Клык Седого Вожака бури, по нему пробегают искры. Трофей босса."},
	"bastion_shard": {"name": "Осколок бастиона", "type": "trophy", "icon": "plate", "rarity": "rare", "buy": 0, "sell": 100, "color": Color(0.35, 0.68, 0.62), "desc": "Обломок панциря Тысячелетнего Бастиона, тяжёлый, как камень. Трофей босса."},
	"current_pearl": {"name": "Жемчужина течений", "type": "trophy", "icon": "shard", "rarity": "rare", "buy": 0, "sell": 105, "color": Color(0.55, 0.78, 1.0), "desc": "Жемчужина из гребня Владыки течений, внутри словно плещется вода. Трофей босса."},
	"midnight_claw": {"name": "Коготь полуночи", "type": "trophy", "icon": "fang", "rarity": "rare", "buy": 0, "sell": 115, "color": Color(0.62, 0.42, 0.95), "desc": "Чёрный коготь Владычицы полуночи с фиолетовым отливом. Трофей босса."},
	"thunder_spear": {"name": "Громовой наконечник", "type": "trophy", "icon": "spike", "rarity": "rare", "buy": 0, "sell": 130, "color": Color(1.0, 0.85, 0.45), "desc": "Наконечник копья Громового хана, звенит от прикосновения. Трофей босса."},
	"bone_crown": {"name": "Костяной венец", "type": "trophy", "icon": "spike", "rarity": "unique", "buy": 0, "sell": 160, "color": Color(0.95, 0.9, 0.72), "desc": "Венец из костяных шипов Костяного владыки. Трофей босса."},
}

## Все предметы: BASE_ITEMS и зелья всех видов и рангов (_static_init). Читать через get_item / ITEMS.
static var ITEMS: Dictionary = {}


static func _static_init() -> void:
	ITEMS = BASE_ITEMS.duplicate(true)
	for k in POTION_KINDS:
		for r in range(1, POTION_RANKS + 1):
			var kind := String(k)
			ITEMS[potion_id(kind, r)] = _make_potion(kind, r)


# ---------- Ранги предметов ----------
## Снаряжение (оружие, позже броня и украшения) — по рангам уровня героя (решение Максима): 1-й — 1–20 ур.,
## 2-й — 21–50, 3-й — 51–80, дальше по 30 уровней до потолка 150 (4-й — 81–110, 5-й — 111–140, 6-й — 141–150).
## Надеть снаряжение можно с нижнего уровня его ранга (required_level, level_block).
## Зелья — ранг на каждые 10 уровней: 1-й — 1–10, 2-й — 11–20 … 15-й — 141–150; пить — с нижнего уровня ранга.
## Добыча (LootTable): зелье — ранга по уровню зверя, оружие — ранга по уровню зверя (по таблице снаряжения),
## награды заданий — по уровню героя.
const EQUIP_RANKS := [[1, 20], [21, 50], [51, 80], [81, 110], [111, 140], [141, 150]]
const MAX_LEVEL := 150
const POTION_RANKS := 15
const POTION_RANK_LEVELS := 10

## Зелья (type "consumable", поле potion — вид, rank — ранг 1–15, id potion_<вид>_r<ранг>): name — название вида,
## color — цвет колбы, buy — цена 1-го ранга (ранг N — × (1 + 1.5·(N − 1)); продажа — треть), order — порядок в сумке.
## Здоровье и мана — мгновенно: POTION_PCT запаса + число по рангу (potion_flat ≈ четверть HP / MP героя на нижнем
## уровне ранга: на нижнем уровне ранга зелье даёт ≈ 50 % запаса, на верхнем ≈ 35 %), перезарядка Economy.POTION_CD.
## Скорость атаки, каста и бега — усиление на POTION_BUFF_TIME с: +10 % на 1-м ранге, +1 % за ранг (15-й — +24 %);
## значок у полоски HP ("buff:potion_<вид>"), повтор того же вида — заменяет и продлевает.
const POTION_KINDS := {
	"hp": {"name": "Зелье здоровья", "color": Color(0.9, 0.2, 0.25), "buy": 10, "order": 0},
	"mp": {"name": "Зелье маны", "color": Color(0.25, 0.48, 0.98), "buy": 12, "order": 1},
	"aspd": {"name": "Зелье скорости атаки", "color": Color(0.98, 0.55, 0.15), "buy": 20, "order": 2},
	"cast": {"name": "Зелье скорости каста", "color": Color(0.72, 0.38, 0.98), "buy": 20, "order": 3},
	"speed": {"name": "Зелье скорости бега", "color": Color(0.3, 0.86, 0.45), "buy": 15, "order": 4},
}
const POTION_PCT := 0.25
const POTION_BUFF_TIME := 60.0
## Ключ бонуса героя (Player.timed_bonus → recalc_stats) у зелий-ускорений.
const POTION_BUFF_KEYS := {"aspd": "aspd", "cast": "cast", "speed": "speed_pct"}
const ROMAN := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV", "XV"]


## Ранг снаряжения для уровня lvl (EQUIP_RANKS; выше потолка — последний).
static func equip_rank_for_level(lvl: int) -> int:
	for i in EQUIP_RANKS.size():
		if lvl <= int((EQUIP_RANKS[i] as Array)[1]):
			return i + 1
	return EQUIP_RANKS.size()


## Ранг зелья для уровня lvl: по 10 уровней на ранг, 1…15.
static func potion_rank_for_level(lvl: int) -> int:
	return clampi(ceili(float(maxi(1, lvl)) / float(POTION_RANK_LEVELS)), 1, POTION_RANKS)


## Уровни ранга [от, до]: снаряжения (EQUIP_RANKS) или зелья (potion = true).
static func rank_level_range(rank_n: int, potion: bool = false) -> Array:
	if potion:
		var r := clampi(rank_n, 1, POTION_RANKS)
		return [(r - 1) * POTION_RANK_LEVELS + 1, r * POTION_RANK_LEVELS]
	var e: Array = EQUIP_RANKS[clampi(rank_n, 1, EQUIP_RANKS.size()) - 1]
	return [int(e[0]), int(e[1])]


## С какого уровня можно надеть или выпить предмет: нижний уровень его ранга (снаряжение, зелья), иначе 1.
static func required_level(id: String) -> int:
	var it := get_item(id)
	if it.has("level"):
		return int(it["level"])
	if is_potion(id):
		return int(rank_level_range(rank(id), true)[0])
	if is_equipment(id):
		return int(rank_level_range(rank(id))[0])
	return 1


## Почему герою уровня lvl нельзя надеть или выпить предмет ("" — можно).
static func level_block(id: String, lvl: int) -> String:
	var need := required_level(id)
	if lvl < need:
		return "Нужен %d уровень: «%s» — %d-го ранга" % [need, item_name(id), rank(id)]
	return ""


## Снаряжение (оружие, броня, украшения): у него ранг по таблице EQUIP_RANKS.
static func is_equipment(id: String) -> bool:
	var t := item_type(id)
	return t == "weapon" or t == "armor" or t == "jewelry"


## Ранг римской цифрой (1 → «I»).
static func roman(n: int) -> String:
	return String(ROMAN[n - 1]) if n >= 1 and n <= ROMAN.size() else str(n)


# ---------- Зелья ----------

static func potion_id(kind: String, rank_n: int) -> String:
	return "potion_%s_r%d" % [kind, rank_n]


static func is_potion(id: String) -> bool:
	return get_item(id).has("potion")


## Вид зелья ("hp", "mp", "aspd", "cast", "speed"; "" — не зелье).
static func potion_kind(id: String) -> String:
	return String(get_item(id).get("potion", ""))


## Семья зелья для целей заданий: "potion_hp" — любое зелье здоровья ("" — не зелье).
static func potion_family(id: String) -> String:
	var k := potion_kind(id)
	return "potion_" + k if k != "" else ""


## Размер колбы на значке: ранги 1–5 — 1, 6–10 — 2, 11–15 — 3 (картинка potion_<вид>_t<размер>.png).
static func potion_tier(rank_n: int) -> int:
	return clampi(1 + (rank_n - 1) / 5, 1, 3)


## Сколько восстанавливает зелье здоровья или маны сверх доли POTION_PCT: ≈ четверть HP (MP) героя на нижнем
## уровне ранга (HP героя ≈ 77 + 19·ур., MP ≈ 25 + 5·ур. — таблица Бродяги в tools/rappelz_strider_reference.md).
static func potion_flat(kind: String, rank_n: int) -> int:
	var l := float(rank_level_range(rank_n, true)[0])
	if kind == "hp":
		return roundi(19.25 + 4.75 * l)
	if kind == "mp":
		return roundi(6.25 + 1.25 * l)
	return 0


## Сколько HP (MP) вернёт зелье id при запасе max_value.
static func potion_restore(id: String, max_value: int) -> int:
	return roundi(float(max_value) * POTION_PCT) + potion_flat(potion_kind(id), rank(id))


## Прибавка зелья-ускорения ранга rank_n (доля): +10 % на 1-м ранге, +1 % за ранг.
static func potion_buff(rank_n: int) -> float:
	return 0.10 + 0.01 * float(clampi(rank_n, 1, POTION_RANKS) - 1)


## Цена покупки зелья вида kind ранга rank_n.
static func potion_price(kind: String, rank_n: int) -> int:
	return roundi(float(POTION_KINDS[kind]["buy"]) * (1.0 + 1.5 * float(rank_n - 1)))


static func _make_potion(kind: String, r: int) -> Dictionary:
	var pk: Dictionary = POTION_KINDS[kind]
	var buy := potion_price(kind, r)
	var desc := ""
	var pct := roundi(POTION_PCT * 100.0)
	var buff := roundi(potion_buff(r) * 100.0)
	match kind:
		"hp":
			desc = "Восстанавливает %d%% здоровья и ещё %d HP." % [pct, potion_flat(kind, r)]
		"mp":
			desc = "Восстанавливает %d%% маны и ещё %d MP." % [pct, potion_flat(kind, r)]
		"aspd":
			desc = "Скорость атаки +%d%% на %d с." % [buff, int(POTION_BUFF_TIME)]
		"cast":
			desc = "Скорость каста +%d%% на %d с: заклинания и магическая атака быстрее." % [buff, int(POTION_BUFF_TIME)]
		"speed":
			desc = "Скорость бега +%d%% на %d с." % [buff, int(POTION_BUFF_TIME)]
	return {
		"name": "%s %s" % [String(pk["name"]), roman(r)], "type": "consumable", "icon": "flask", "potion": kind,
		"rank": r, "buy": buy, "sell": maxi(1, buy / 3), "color": pk["color"], "desc": desc,
	}


## Виды оружия: name — название, hands — 1 (одноручное: во вторую руку можно щит или второе такое же),
## 2 (двуручное: вторая рука пуста), "dual" (пара: два одинаковых одноручных в обеих руках — вид хвата, предметов
## такого вида нет), "off" (щит, только вторая рука); attack — обычная атака ("melee" удар, "ranged" стрела или болт,
## "magic" сгусток магии); model — что держит модель героя (CharacterModel: модель из файла умеет sword, dagger,
## daggers, dual_swords, dual_axes, crossbow, bow, axe, mace, staff; щит — отдельно); pair — вид пары одноручного
## (кинжал → "daggers"), of — одиночный вид пары. Группы видов для умений — HeroSkills.WEAPON_GROUPS.
## Бонусы вида (решение Максима): stats — какие числа предмета действуют (atk — физ. атака, matk — маг. атака,
## def — физ. защита, block — шанс блока), aspd — скорость атаки, %, cast — скорость каста заклинаний, %
## (Player.recalc_stats: прибавляются к производным героя). У пары скорость — по одиночному виду, атаки обеих рук
## складываются. Булавы Максим не задал: как у топоров (физ. и маг. атака, −10 / −25%).
const WEAPON_KINDS := {
	"sword_1h": {"name": "одноручный меч", "hands": 1, "attack": "melee", "model": "sword", "pair": "dual_swords",
		"stats": ["atk"], "aspd": -5},
	"sword_2h": {"name": "двуручный меч", "hands": 2, "attack": "melee", "model": "sword", "stats": ["atk"], "aspd": -15},
	"dagger": {"name": "кинжал", "hands": 1, "attack": "melee", "model": "dagger", "pair": "daggers",
		"stats": ["atk", "matk"], "aspd": 25},
	"daggers": {"name": "два кинжала", "hands": "dual", "attack": "melee", "model": "daggers", "of": "dagger"},
	"dual_swords": {"name": "два меча", "hands": "dual", "attack": "melee", "model": "dual_swords", "of": "sword_1h"},
	"mace_1h": {"name": "одноручная булава", "hands": 1, "attack": "melee", "model": "mace", "stats": ["atk", "matk"],
		"aspd": -10},
	"mace_2h": {"name": "двуручная булава", "hands": 2, "attack": "melee", "model": "mace", "stats": ["atk", "matk"],
		"aspd": -20},
	"axe_1h": {"name": "одноручный топор", "hands": 1, "attack": "melee", "model": "axe", "pair": "dual_axes",
		"stats": ["atk", "matk"], "aspd": -10},
	"axe_2h": {"name": "двуручный топор", "hands": 2, "attack": "melee", "model": "axe", "stats": ["atk", "matk"],
		"aspd": -25},
	"dual_axes": {"name": "два топора", "hands": "dual", "attack": "melee", "model": "dual_axes", "of": "axe_1h"},
	"staff_1h": {"name": "одноручный посох", "hands": 1, "attack": "magic", "model": "staff", "stats": ["matk"], "cast": 20},
	"staff_2h": {"name": "двуручный посох", "hands": 2, "attack": "magic", "model": "staff", "stats": ["matk"], "cast": 10},
	"spear": {"name": "копьё", "hands": 2, "attack": "melee", "model": "spear", "stats": ["atk"], "aspd": -15},
	"crossbow": {"name": "арбалет", "hands": 2, "attack": "ranged", "model": "crossbow", "stats": ["atk"], "aspd": -20},
	"bow": {"name": "лук", "hands": 2, "attack": "ranged", "model": "bow", "stats": ["atk"], "aspd": -40},
	"shield": {"name": "щит", "hands": "off", "attack": "", "model": "", "stats": ["def", "block"]},
}
## Время между обычными атаками при скорости атаки 100% (до бонуса вида и Ловкости), с: по типу атаки оружия.
const BASE_CD := {"melee": 0.75, "ranged": 0.75, "magic": 1.0}
## Стартовый набор оружия профессии: выдаётся новому герою (Бродяга) и при смене профессии (Game.change_job);
## первое — в основную руку, повтор того же id — второй такой же во вторую руку (пара), щит — во вторую руку.
const STARTER_WEAPONS := {
	"wanderer": ["weapon_sword_1h_r1"],
	"swordsman": ["weapon_sword_1h_r1", "weapon_shield_r1"],
	"wizard": ["weapon_staff_2h_r1", "weapon_staff_1h_r1"],
	"beastmaster": ["weapon_mace_2h_r1", "weapon_staff_2h_r1"],
	"assassin": ["weapon_dagger_r1", "weapon_dagger_r1", "crossbow_starter"],
	"neophyte": ["weapon_staff_2h_r1", "weapon_staff_1h_r1"],
	"adept": ["weapon_dagger_r1", "weapon_shield_r1", "weapon_staff_2h_r1"],
	"warrior": ["weapon_axe_2h_r1", "weapon_bow_r1"],
	"shaman": ["weapon_staff_2h_r1", "weapon_axe_2h_r1"],
	"conjurer": ["weapon_axe_1h_r1", "weapon_axe_2h_r1"],
}

## Прежние id предметов → новые (старые сохранения переводит Game.from_dict). Кристаллы души заменены картами:
## каждый кристалл — зеркальная карта (за редкий и древний ещё LEGACY_GOLD). Карт кабана и каменного стража
## больше нет (их нельзя приручить) — если они остались в сумке, становятся зеркальными картами.
const RENAMED := {
	"bear_claw": "panther_fang", "fairy_dust": "pheasant_feather", "spark_core": "shell_plate",
	"crystal_common": "mirror_card", "crystal_rare": "mirror_card", "crystal_unique": "mirror_card",
	"card_boar": "mirror_card", "card_boar_soul": "mirror_card", "card_golem": "mirror_card", "card_golem_soul": "mirror_card",
	# Зелья получили ранги: прежнее зелье здоровья — 1-го ранга
	"hp_potion": "potion_hp_r1",
}
## Прежние парные предметы Наёмника (один предмет — пара клинков) → два одиночных (вторая рука): каждый прежний
## предмет становится двумя новыми, надетая пара — тем же оружием в обеих руках (Game.from_dict).
const PAIRED := {
	"daggers_starter": "weapon_dagger_r1", "dual_swords_starter": "weapon_sword_1h_r1",
	"daggers_steel": "dagger_steel", "dual_swords_steel": "sword_steel",
}
## Доплата золотом за каждый прежний предмет при переводе: цена продажи прежнего кристалла (редкий — 30,
## древний — 100), зеркальная карта идёт сверху.
const LEGACY_GOLD := {"crystal_rare": 30, "crystal_unique": 100}


static func get_item(id: String) -> Dictionary:
	return ITEMS.get(id, {})


static func item_name(id: String) -> String:
	if not ITEMS.has(id) and id.begins_with("potion_") and POTION_KINDS.has(id.substr(7)):
		# Семья зелий в целях заданий ("potion_hp" — любое зелье здоровья)
		return String(POTION_KINDS[id.substr(7)]["name"])
	return String(get_item(id).get("name", id))


## Новый id предмета по прежнему (из старого сохранения; прежняя пара — одиночный предмет, их два — PAIRED);
## остальные — как есть.
static func migrate_id(id: String) -> String:
	if PAIRED.has(id):
		return String(PAIRED[id])
	return String(RENAMED.get(id, id))


## Сколько новых предметов даёт один прежний (пара клинков — два).
static func migrate_count(id: String) -> int:
	return 2 if PAIRED.has(id) else 1


## Доплата золотом за прежние предметы сумки {id: количество} (LEGACY_GOLD).
static func legacy_gold(src: Dictionary) -> int:
	var g := 0
	for k in src:
		g += int(LEGACY_GOLD.get(String(k), 0)) * maxi(0, int(src[k]))
	return g


static func is_weapon(id: String) -> bool:
	return String(get_item(id).get("type", "")) == "weapon"


## Вид оружия предмета (WEAPON_KINDS: "sword_1h", "dagger", "crossbow", "shield" и т. д.; "" — не оружие).
static func weapon_kind(id: String) -> String:
	return String(get_item(id).get("weapon", ""))


## Название вида оружия по-русски ("два меча").
static func weapon_kind_name(kind: String) -> String:
	return String(WEAPON_KINDS.get(kind, {}).get("name", kind))


## Хват вида оружия: 1, 2, "dual" или "off" (щит).
static func hands(kind: String) -> Variant:
	var d: Dictionary = WEAPON_KINDS.get(kind, {})
	return d.get("hands", 2)


## Одноручное оружие (во вторую руку можно щит или второе такое же).
static func is_one_handed(kind: String) -> bool:
	var h: Variant = hands(kind)
	return h is int and int(h) == 1


static func is_shield(id: String) -> bool:
	return weapon_kind(id) == "shield"


## Вид пары одноручного вида ("dagger" → "daggers"; "" — парным не бывает).
static func pair_kind(kind: String) -> String:
	var d: Dictionary = WEAPON_KINDS.get(kind, {})
	return String(d.get("pair", ""))


## Одиночный вид пары ("daggers" → "dagger"); у остальных — сам вид.
static func single_kind(kind: String) -> String:
	var d: Dictionary = WEAPON_KINDS.get(kind, {})
	return String(d.get("of", kind))


## Вид хвата: оружие main в основной руке и off во второй. Два одинаковых одноручных — вид пары ("daggers",
## "dual_swords", "dual_axes"), иначе — вид основного оружия ("" — без оружия). Его получают умения
## (HeroSkills.WEAPON_GROUPS), модель и тип атаки.
static func grip_kind(main: String, off: String) -> String:
	var k := weapon_kind(main)
	if off != "" and not is_shield(off) and weapon_kind(off) == k and pair_kind(k) != "":
		return pair_kind(k)
	return k


## Обычная атака оружием вида kind: "melee" | "ranged" | "magic" ("" — щит или не оружие).
static func weapon_attack(kind: String) -> String:
	var d: Dictionary = WEAPON_KINDS.get(kind, {})
	return String(d.get("attack", ""))


## Что держит модель героя для вида kind (CharacterModel).
static func model_kind(kind: String) -> String:
	var d: Dictionary = WEAPON_KINDS.get(kind, {})
	return String(d.get("model", ""))


## Ранг предмета (оружие — EQUIP_RANKS, зелья — по 10 уровней; у прочих 1).
static func rank(id: String) -> int:
	return int(get_item(id).get("rank", 1))


## Подходит ли оружие профессии: вид — среди ClassData weapons профессии (у Бродяги — все виды).
static func weapon_fits(id: String, class_id: String) -> bool:
	if not is_weapon(id):
		return false
	return ClassData.weapons(class_id).has(weapon_kind(id))


## Можно ли взять off во вторую руку при оружии main у профессии class_id: "" — можно, иначе причина. Во второй
## руке — щит (если профессия им владеет, а основное оружие одноручное) или второе одноручное того же вида,
## если пара этого вида есть у профессии (ClassData weapons: "daggers", "dual_swords", "dual_axes").
static func offhand_block(off: String, main: String, class_id: String) -> String:
	if not is_weapon(off):
		return "Это не оружие"
	if main == "":
		return "Сначала возьмите оружие в основную руку"
	var mk := weapon_kind(main)
	if not is_one_handed(mk):
		return "Вторая рука занята: %s держат двумя руками" % weapon_kind_name(mk)
	var cls := ClassData.weapons(class_id)
	if is_shield(off):
		if not cls.has("shield"):
			return "Щит не для профессии «%s»" % ClassData.job_name(class_id)
		return ""
	var pk := pair_kind(mk)
	if weapon_kind(off) != mk or pk == "":
		return "Во второй руке — только щит или второе такое же одноручное оружие"
	if not cls.has(pk):
		return "Профессия «%s» не держит %s" % [ClassData.job_name(class_id), weapon_kind_name(pk)]
	return ""


## Пользуется ли класс сменным оружием (у всех профессий есть стартовый набор).
static func class_uses_weapons(class_id: String) -> bool:
	return STARTER_WEAPONS.has(ClassData.migrate_id(class_id))


## Стартовый набор профессии.
static func starter_weapons(class_id: String) -> Array:
	return STARTER_WEAPONS.get(ClassData.migrate_id(class_id), [])


## Оружие по умолчанию у класса (первое из стартового набора) или "".
static func default_weapon(class_id: String) -> String:
	var a := starter_weapons(class_id)
	return String(a[0]) if not a.is_empty() else ""


## Бонусы предмета-оружия id по его виду: {"atk", "matk", "def": int, "block": доля, "aspd", "cast": % скорости
## атаки и каста}. Из чисел предмета берутся только те, что есть у вида (WEAPON_KINDS stats).
static func weapon_bonus(id: String) -> Dictionary:
	var res := {"atk": 0, "matk": 0, "def": 0, "block": 0.0, "aspd": 0, "cast": 0}
	var it := get_item(id)
	if it.is_empty() or not is_weapon(id):
		return res
	var kd: Dictionary = WEAPON_KINDS.get(weapon_kind(id), {})
	var st: Array = kd.get("stats", [])
	for k in ["atk", "matk", "def"]:
		if st.has(k):
			res[k] = int(it.get(k, 0))
	if st.has("block"):
		res["block"] = float(it.get("block", 0.0))
	res["aspd"] = int(kd.get("aspd", 0))
	res["cast"] = int(kd.get("cast", 0))
	return res


## Бонусы хвата (основное оружие main и вторая рука off): атаки, защита и блок обеих рук складываются, скорость
## атаки и каста — по основному оружию.
static func grip_bonus(main: String, off: String) -> Dictionary:
	var res := weapon_bonus(main)
	if off != "":
		var o := weapon_bonus(off)
		for k in ["atk", "matk", "def"]:
			res[k] = int(res[k]) + int(o[k])
		res["block"] = float(res["block"]) + float(o["block"])
	return res


## Время между обычными атаками оружием вида kind при скорости 100%, с (BASE_CD по типу атаки).
static func base_cd(kind: String) -> float:
	return float(BASE_CD.get(weapon_attack(kind), 0.75))


## Бонусы оружия одной строкой: «физ. атака +2, маг. атака +2, скорость атаки +25%, дальность 2.2 м, крит +5%».
static func weapon_stats_text(id: String) -> String:
	var it := get_item(id)
	if it.is_empty():
		return ""
	var b := weapon_bonus(id)
	var parts: PackedStringArray = []
	if int(b["atk"]) > 0:
		parts.append("физ. атака +%d" % int(b["atk"]))
	if int(b["matk"]) > 0:
		parts.append("маг. атака +%d" % int(b["matk"]))
	if int(b["def"]) > 0:
		parts.append("физ. защита +%d" % int(b["def"]))
	if float(b["block"]) > 0.0:
		parts.append("блок %d%%" % roundi(float(b["block"]) * 100.0))
	if int(b["aspd"]) != 0:
		parts.append("скорость атаки %s%d%%" % ["+" if int(b["aspd"]) > 0 else "−", absi(int(b["aspd"]))])
	if int(b["cast"]) != 0:
		parts.append("скорость каста +%d%%" % int(b["cast"]))
	if is_shield(id):
		parts.append("во второй руке")
		return ", ".join(parts)
	parts.append("дальность %.1f м" % float(it.get("range", 2.0)))
	if float(it.get("crit", 0.0)) > 0.0:
		parts.append("крит +%d%%" % roundi(float(it["crit"]) * 100.0))
	return ", ".join(parts)


# ---------- Сумка: типы, редкость, стопки, значки ----------

## Типы предметов: название, порядок сортировки, цвет рамки (у обычных расходников и трофеев; у карт — цвет тира).
const TYPES := {
	"weapon": {"name": "Оружие", "order": 0, "color": Color(0.7, 0.72, 0.78)},
	"armor": {"name": "Доспех", "order": 1, "color": Color(0.7, 0.72, 0.78)},
	"consumable": {"name": "Расходник", "order": 2, "color": Color(0.95, 0.45, 0.5)},
	"card": {"name": "Карта существа", "order": 3, "color": Color(0.78, 0.56, 0.34)},
	"trophy": {"name": "Трофей", "order": 4, "color": Color(0.85, 0.65, 0.4)},
}
## Редкость: название, ранг (для сортировки), цвет рамки и названия.
const RARITIES := {
	"common": {"name": "Обычный", "rank": 0, "color": Color(0.7, 0.72, 0.78)},
	"improved": {"name": "Улучшенный", "rank": 1, "color": Color(0.45, 0.95, 0.45)},
	"rare": {"name": "Редкий", "rank": 2, "color": Color(0.4, 0.62, 1.0)},
	"unique": {"name": "Уникальный", "rank": 3, "color": Color(1.0, 0.8, 0.25)},
}
## Размер стопки в ячейке сумки по умолчанию (у оружия — 1).
const STACK := 99
## Тиры карт существ (как в руководстве: цвет карты по группе зверя): название, цвет, ранг (сортировка).
## Тир идёт от редкости зверя (MobData.CARD_TIER_BY_RARITY), названия — как у редкостей: базовая (коричневая) —
## «Базовые» звери, обычная (синяя) — «Обычные» (волк), редкая (фиолетовая) — «Редкие», уникальная (жёлтая) —
## «Уникальные». Ключи тиров внутренние (шансы — Taming.CHANCE по ним же).
const CARD_TIERS := {
	"basic": {"name": "базовая", "color_name": "коричневая", "rank": 0, "color": Color(0.8, 0.56, 0.32)},
	"rare": {"name": "обычная", "color_name": "синяя", "rank": 1, "color": Color(0.36, 0.58, 1.0)},
	"special": {"name": "редкая", "color_name": "фиолетовая", "rank": 2, "color": Color(0.72, 0.42, 1.0)},
	"unique": {"name": "уникальная", "color_name": "жёлтая", "rank": 3, "color": Color(1.0, 0.82, 0.25)},
}
## Зеркальная карта: id и цвет рамки (серебро).
const MIRROR_CARD := "mirror_card"
const MIRROR_COLOR := Color(0.8, 0.86, 0.96)
## Картинки значков предметов: <ICON_DIR><id>.png (нет файла — процедурный значок ItemIcon).
const ICON_DIR := "res://assets/icons/items/"


static func item_type(id: String) -> String:
	return String(get_item(id).get("type", ""))


static func type_name(id: String) -> String:
	return String(TYPES.get(item_type(id), {}).get("name", "Предмет"))


static func rarity(id: String) -> String:
	var r := String(get_item(id).get("rarity", "common"))
	return r if RARITIES.has(r) else "common"


static func rarity_name(id: String) -> String:
	return String(RARITIES[rarity(id)]["name"])


static func rarity_color(id: String) -> Color:
	return RARITIES[rarity(id)]["color"]


## Цвет рамки ячейки: у карт — цвет тира (зеркальная — серебро), иначе по редкости (у оружия и необычных
## предметов) или по типу.
static func frame_color(id: String) -> Color:
	if is_card(id):
		return MIRROR_COLOR if card_species(id) == "" else card_tier_color(card_tier(id))
	var r := rarity(id)
	if r != "common" or is_weapon(id) or not TYPES.has(item_type(id)):
		return RARITIES[r]["color"]
	return TYPES[item_type(id)]["color"]


## Сколько штук лежит в одной ячейке сумки.
static func stack_size(id: String) -> int:
	var t := item_type(id)
	if t == "weapon" or t == "armor":
		return 1
	return maxi(1, int(get_item(id).get("stack", STACK)))


## Что рисовать процедурным значком ("flask", "card", ...; "" — буква названия).
static func icon_shape(id: String) -> String:
	return String(get_item(id).get("icon", ""))


## Картинка значка: <id>.png; у зелий — одна на вид и размер колбы: potion_<вид>_t<1|2|3>.png (potion_tier).
static func icon_path(id: String) -> String:
	if is_potion(id):
		return ICON_DIR + "potion_%s_t%d.png" % [potion_kind(id), potion_tier(rank(id))]
	return ICON_DIR + id + ".png"


## Порядок в сумке: тип, затем редкость (лучшие раньше; у карт — тир, заполненные раньше пустых, зеркальные
## в конце), название, id.
static func sort_before(a: String, b: String) -> bool:
	var ta := int(TYPES.get(item_type(a), {}).get("order", 9))
	var tb := int(TYPES.get(item_type(b), {}).get("order", 9))
	if ta != tb:
		return ta < tb
	var ra := _sort_rank(a)
	var rb := _sort_rank(b)
	if ra != rb:
		return ra > rb
	# Зелья: по виду (здоровье, мана, ускорения), старшие ранги раньше; оружие — старшие ранги раньше
	var pa := potion_kind(a)
	var pb := potion_kind(b)
	if pa != "" and pb != "":
		if pa != pb:
			return int(POTION_KINDS[pa]["order"]) < int(POTION_KINDS[pb]["order"])
		return rank(a) > rank(b)
	if is_equipment(a) and is_equipment(b) and rank(a) != rank(b):
		return rank(a) > rank(b)
	var na := item_name(a)
	var nb := item_name(b)
	if na != nb:
		return na < nb
	return a < b


static func _sort_rank(id: String) -> int:
	if is_card(id):
		if card_species(id) == "":
			return -1
		return int(CARD_TIERS[card_tier(id)]["rank"]) * 2 + (1 if is_soul_card(id) else 0)
	return int(RARITIES[rarity(id)]["rank"])


# ---------- Карты существ ----------

static func is_card(id: String) -> bool:
	return item_type(id) == "card"


## Вид зверя карты ("" — не карта существа или зеркальная).
static func card_species(id: String) -> String:
	return String(get_item(id).get("species", "")) if is_card(id) else ""


## Карта с пойманной душой (из неё формируется существо).
static func is_soul_card(id: String) -> bool:
	return is_card(id) and bool(get_item(id).get("soul", false))


## Пустая карта существа (ловит дух своего вида).
static func is_empty_card(id: String) -> bool:
	return card_species(id) != "" and not is_soul_card(id)


## Пустая карта вида species ("" — у вида нет карты).
static func card_for(species: String) -> String:
	var id := "card_" + species
	return id if is_empty_card(id) else ""


## Заполненная карта вида species ("" — нет).
static func soul_card_for(species: String) -> String:
	var id := "card_%s_soul" % species
	return id if is_soul_card(id) else ""


## Тир карты: "basic" | "rare" | "special" | "unique" ("" — зеркальная или не карта).
static func card_tier(id: String) -> String:
	var sp := card_species(id)
	if sp == "":
		return ""
	var t := MobData.card_tier(sp)
	return t if CARD_TIERS.has(t) else "basic"


static func card_tier_color(tier: String) -> Color:
	return CARD_TIERS.get(tier, CARD_TIERS["basic"])["color"]


## Тир словами: «коричневая (базовая)».
static func card_tier_label(tier: String) -> String:
	var t: Dictionary = CARD_TIERS.get(tier, CARD_TIERS["basic"])
	return "%s (%s)" % [String(t["color_name"]), String(t["name"])]


## Вторая строка в карточке предмета после типа: у карт — тир («Коричневая (базовая)»), у зеркальной —
## «Оберег», у остальных — редкость.
static func grade_name(id: String) -> String:
	if is_card(id):
		if card_species(id) == "":
			return "Оберег"
		var t := card_tier_label(card_tier(id))
		return t.substr(0, 1).to_upper() + t.substr(1)
	return rarity_name(id)
