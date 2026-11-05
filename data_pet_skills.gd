class_name PetSkills
extends RefCounted
## Умения питомцев (механика и числа — по образцу Rappelz: Pantera, Tortus, Poultry, Kentauros; названия, описания
## и значки свои). Умение изучается и повышается за очки умений (JP) в окне существа (CreatureWindow).
## Уровни умения открываются блоками по стадиям эволюции: tiers = [[уровень вики, макс. ур. умения], ...]
## на 1-й, 2-й и 3-й стадии ([0, 0] — на этой стадии умения ещё нет). Уровень вики → наш: × 0.3 (req_level()).
## Виды умений: "active" — применяет ИИ питомца (цель есть, перезарядка готова, хватает MP; сильные первыми),
## "toggle" — включается в окне существа и тратит MP каждые 10 с, "passive" — действует всегда.
## Ячейки умений питомца (окно существа): 3 «Авто» (slots) — активные умения, которые ИИ применяет сам, по порядку
## ячеек (только из них); 2 «Ауры» (aura_slots) — переключаемые (узы, вызов): включены, только пока стоят в ячейке,
## снятие из ячейки выключает. Пассивные ячеек не занимают. Первое изучение активного умения ставит его в свободную
## ячейку «Авто». Старые записи (без ячеек): изученные активные заполняют «Авто» по силе (prio), включённые
## переключаемые — ячейки аур (больше двух — остальные выключаются). Команда питомца — поле записи cmd
## ("auto" | "defend" | "follow", COMMANDS).
## Числовые поля — [на 1 уровне, прибавка за уровень] (value()). MP — в единицах вики, × MP_SCALE.
## Перезарядки (cd) и время каста (cast) — наши: бои на острове короткие (вики — в tools/rappelz_pet_reference.md).
##
## Поля активных: dmg — доля главной атаки роли за удар, hits — число ударов, radius — по площади вокруг цели,
## threat — зверь переключается на питомца, charge — рывок к цели в 3–10 м, slow / vuln / miss — замедление,
## уязвимость (больше урона) и промахи зверя (доля, 10 с), weaken — ослабление: удары зверя слабее (доля, 10 с),
## stun — оглушение (с), blind — морок: зверь бьёт мимо (с), fear — страх: зверь убегает и не бьёт (с, Mob.frighten),
## buff — "atk" (атака хозяина, % на time с), "guard" (хозяин получает меньше урона), "heal" (лечение хозяина
## и питомца, доля макс. HP). prio — порядок выбора ИИ (больше — раньше).
## Поля пассивных и переключаемых: bonus — что усиливает (PetStats.derived), value; owner — бонус и хозяину.

## Очки умений: у нового питомца и за каждый уровень опыта (начисляются по долям за убийства).
const JP_START := 2
const JP_PER_LEVEL := 3
## Стоимость MP из вики × MP_SCALE: с баланса по базе запас MP — как в оригинале, MP умений тоже 1:1.
const MP_SCALE := 1.0
## Поддержка переключаемых умений списывается раз в UPKEEP_PERIOD секунд.
const UPKEEP_PERIOD := 10.0
const KIND_NAMES := {"active": "активное", "passive": "пассивное", "toggle": "переключаемое", "manual": "создание"}
## Ячейки умений: «Авто» (активные) и «Ауры» (переключаемые).
const AUTO_SLOTS := 3
const AURA_SLOTS := 2
## Режимы питомца, которые запоминаются в записи (cmd): сам нападает рядом, защищает хозяина, следует.
## Разовая команда «Атака» (атаковать цель героя) не запоминается.
const COMMANDS := ["auto", "defend", "follow"]
const DEFAULT_COMMAND := "defend"

const VIOLET := Color(0.55, 0.32, 0.95)
const GREEN := Color(0.3, 0.68, 0.45)
const GOLD := Color(0.95, 0.72, 0.25)
const RED := Color(0.88, 0.32, 0.28)
const BLUE := Color(0.3, 0.55, 0.95)
const TEAL := Color(0.25, 0.7, 0.75)
const GRAY := Color(0.55, 0.55, 0.62)

const SKILLS := {
	# ---------- Общие (у пантеры, черепахи и фазана; первые три — и у остальных зверей) ----------
	"inner_fire": {  # ← Awakening: P.Atk (30 ур. по +5 → у нас 15 ур. по +3%)
		"name": "Внутренний огонь", "kind": "passive", "glyph": "О", "color": RED, "jp": 1,
		"desc": "Главная атака питомца сильнее.",
		"tiers": [[1, 5], [50, 10], [100, 15]], "bonus": "atk_pct", "value": [0.03, 0.03],
	},
	"hardening": {  # ← Awakening: P.Def
		"name": "Закалка", "kind": "passive", "glyph": "З", "color": GRAY, "jp": 1,
		"desc": "Физическая и магическая защита выше.",
		"tiers": [[1, 5], [50, 10], [100, 15]], "bonus": "def_pct", "value": [0.05, 0.05],
	},
	"vitality": {  # ← Bless the Body (+100 Max HP за ур.)
		"name": "Живучесть", "kind": "passive", "glyph": "Ж", "color": Color(0.85, 0.25, 0.35), "jp": 1,
		"desc": "Больше максимального здоровья.",
		"tiers": [[20, 5], [70, 10], [120, 15]], "bonus": "hp_pct", "value": [0.03, 0.03],
	},
	"deep_spring": {  # ← Bless the Soul (+100 Max MP за ур.)
		"name": "Глубокий родник", "kind": "passive", "glyph": "Р", "color": BLUE, "jp": 1,
		"desc": "Больше максимального запаса MP.",
		"tiers": [[20, 5], [70, 10], [120, 15]], "bonus": "mp_pct", "value": [0.05, 0.05],
	},
	"mending": {  # ← Meditation (HP Recov +10 за ур.)
		"name": "Быстрое заживление", "kind": "passive", "glyph": "Б", "color": Color(0.4, 0.85, 0.45), "jp": 1,
		"desc": "Здоровье восстанавливается быстрее, даже в бою.",
		"tiers": [[30, 5], [80, 10], [130, 15]], "bonus": "hp_regen", "value": [0.3, 0.3],
	},
	"calm_mind": {  # ← Clarity (MP Recov +10 за ур.)
		"name": "Тихий разум", "kind": "passive", "glyph": "Т", "color": Color(0.45, 0.65, 1.0), "jp": 1,
		"desc": "MP восстанавливается быстрее.",
		"tiers": [[30, 5], [80, 10], [130, 15]], "bonus": "mp_regen", "value": [0.15, 0.15],
	},
	"keen_eye": {  # ← Sharp Vision (P.Acc +2 за ур.)
		"name": "Верный глаз", "kind": "passive", "glyph": "Г", "color": Color(0.9, 0.8, 0.35), "jp": 2,
		"desc": "Выше точность: реже промахи по сильным зверям.",
		"tiers": [[45, 5], [95, 10], [145, 15]], "bonus": "acc", "value": [2.0, 2.0],
	},
	"endless_life": {  # ← Awakening: HP Regen (1 ур.)
		"name": "Неиссякаемая жизнь", "kind": "passive", "glyph": "Н", "color": Color(0.3, 0.9, 0.6), "jp": 2,
		"desc": "Постоянное восстановление здоровья.",
		"tiers": [[0, 0], [0, 0], [140, 1]], "bonus": "hp_regen", "value": [1.0, 0.0],
	},
	"feather_step": {  # ← Awakening: Evasion (1 ур., +5%)
		"name": "Лёгкое перо", "kind": "passive", "glyph": "Л", "color": Color(0.85, 0.9, 1.0), "jp": 2,
		"desc": "Питомец чаще уклоняется от ударов.",
		"tiers": [[0, 0], [0, 0], [140, 1]], "bonus": "eva", "value": [5.0, 0.0],
	},
	"ancestor_gift": {  # ← Eden's Blessing (+1 ко всем статам за ур.)
		"name": "Дар предков", "kind": "passive", "glyph": "Д", "color": GOLD, "jp": 2,
		"desc": "Все семь характеристик выше.",
		"tiers": [[0, 0], [0, 0], [150, 2]], "bonus": "all_stats", "value": [1.0, 1.0],
	},
	"provoke": {  # ← Threatening Essence (угроза +25%…+95%, поддержка 41…251 MP / 10 с)
		"name": "Дерзкий вызов", "kind": "toggle", "glyph": "!", "color": Color(0.95, 0.45, 0.2), "jp": 1,
		"desc": "Пока включено, удары питомца могут переключить зверя на него (отвлекает от хозяина).",
		"tiers": [[15, 5], [65, 10], [115, 15]], "bonus": "threat", "value": [0.25, 0.05],
		"mp": [10.0, 0.0], "upkeep": [41.0, 15.0],
	},
	"daze": {  # ← Sneaky Raid (ослепление 2.2…5.0 с)
		"name": "Морок", "kind": "active", "glyph": "М", "color": Color(0.5, 0.45, 0.7), "jp": 2,
		"desc": "Окутывает цель мороком: пока он держится, зверь бьёт мимо.",
		"tiers": [[25, 5], [75, 10], [125, 15]], "mp": [127.0, 7.0], "cd": 60.0, "cast": 0.5,
		"blind": [2.2, 0.2], "prio": 50,
	},
	# ---------- Пантера (у нас маг: урон тьмой от маг. атаки) ----------
	"shadow_rend": {  # ← Scratch: 2 удара по 60%…200%
		"name": "Двойной росчерк", "kind": "active", "glyph": "Р", "color": VIOLET, "jp": 1,
		"desc": "Два быстрых росчерка теневыми когтями по цели.",
		"tiers": [[10, 5], [60, 10], [110, 15]], "mp": [54.0, 9.0], "cd": 8.0, "cast": 0.5,
		"dmg": [0.6, 0.1], "hits": 2, "prio": 40,
	},
	"dusk_rupture": {  # ← Bloody Crush: 170%…450% + замедление 6%…20% на 10 с
		"name": "Сумрачный разрыв", "kind": "active", "glyph": "С", "color": VIOLET, "jp": 1,
		"desc": "Сгусток тьмы рвётся на цели: большой урон и замедление на 10 с.",
		"tiers": [[20, 5], [70, 10], [120, 15]], "pre": ["shadow_rend", [1, 6, 11]],
		"mp": [117.0, 13.0], "cd": 15.0, "cast": 0.75, "dmg": [1.7, 0.2], "slow": [0.06, 0.01], "prio": 60,
	},
	"shadow_fang": {  # ← Bite (на 3-й стадии — Soul Shock): 60%…200% + оглушение 2 с, угроза
		"name": "Клык полуночи", "kind": "active", "glyph": "К", "color": VIOLET, "jp": 2,
		"desc": "Укус из тени: урон и оглушение на 2 с, зверь переключается на пантеру.",
		"tiers": [[30, 5], [80, 10], [130, 15]], "mp": [159.0, 9.0], "cd": 20.0, "cast": 0.0,
		"dmg": [0.6, 0.1], "stun": 2.0, "threat": true, "prio": 70,
	},
	"shadow_squall": {  # ← Pantera Blast: 3 удара по 120%…210%
		"name": "Теневой шквал", "kind": "active", "glyph": "Ш", "color": VIOLET, "jp": 2,
		"desc": "Три удара тьмой подряд.",
		"tiers": [[0, 0], [90, 5], [140, 10]], "mp": [209.0, 19.0], "cd": 45.0, "cast": 0.5,
		"dmg": [1.2, 0.1], "hits": 3, "prio": 90,
	},
	"hunter_call": {  # ← Encouragement: Strength (+5%…23% на 10 с)
		"name": "Зов охотницы", "kind": "active", "glyph": "З", "color": Color(0.75, 0.4, 1.0), "jp": 2,
		"desc": "Боевой клич: атака хозяина выше на 15 с.",
		"tiers": [[0, 0], [85, 5], [135, 10]], "mp": [98.0, 21.0], "cd": 90.0, "cast": 0.5,
		"buff": "atk", "value": [0.05, 0.02], "time": 15.0, "prio": 85,
	},
	"midnight_vortex": {  # ← Fatal Storm: 200% по площади 5 м + замедление 30% на 10 с
		"name": "Полуночный вихрь", "kind": "active", "glyph": "В", "color": Color(0.4, 0.2, 0.75), "jp": 2,
		"desc": "Вихрь тьмы бьёт всех зверей вокруг цели и замедляет их на 10 с.",
		"tiers": [[0, 0], [0, 0], [150, 1]], "pre": ["shadow_squall", [0, 0, 6]],
		"mp": [597.0, 0.0], "cd": 90.0, "cast": 0.75, "dmg": [2.0, 0.0], "radius": 5.0,
		"slow": [0.3, 0.0], "prio": 100,
	},
	"shadow_bond": {  # ← Unity: Pantera (+P.Atk хозяину и питомцу +27…+125)
		"name": "Узы тени", "kind": "toggle", "glyph": "У", "color": Color(0.65, 0.4, 1.0), "jp": 2,
		"desc": "Пока включено, атака хозяина и пантеры выше.",
		"tiers": [[45, 5], [95, 10], [145, 15]], "bonus": "atk_pct", "value": [0.04, 0.01], "owner": true,
		"mp": [46.0, 36.0], "upkeep": [3.0, 3.0],
	},
	# ---------- Черепаха (танк) ----------
	"stone_jaws": {  # ← Turtle's Teeth: 2 удара по 60%…200%, угроза
		"name": "Каменные челюсти", "kind": "active", "glyph": "Ч", "color": GREEN, "jp": 1,
		"desc": "Два укуса подряд; зверь переключается на черепаху.",
		"tiers": [[10, 5], [60, 10], [110, 15]], "mp": [54.0, 9.0], "cd": 8.0, "cast": 0.5,
		"dmg": [0.6, 0.1], "hits": 2, "threat": true, "prio": 40,
	},
	"shell_wrath": {  # ← Angry Shell: 170%…450% + снижение защиты цели 6%…20% на 10 с, угроза
		"name": "Гнев панциря", "kind": "active", "glyph": "Г", "color": GREEN, "jp": 1,
		"desc": "Тяжёлый удар панцирем: 10 с цель получает больше урона от всех.",
		"tiers": [[20, 5], [70, 10], [120, 15]], "pre": ["stone_jaws", [1, 6, 11]],
		"mp": [117.0, 13.0], "cd": 15.0, "cast": 0.75, "dmg": [1.7, 0.2], "vuln": [0.06, 0.01],
		"threat": true, "prio": 60,
	},
	"ram": {  # ← Tortus Combo: рывок к цели на расстоянии, 60%…200% + оглушение 2 с, угроза
		"name": "Таран", "kind": "active", "glyph": "Т", "color": GREEN, "jp": 2,
		"desc": "Разгон к цели в 3–10 м и удар панцирем: оглушение на 2 с.",
		"tiers": [[30, 5], [80, 10], [130, 15]], "mp": [159.0, 9.0], "cd": 20.0, "cast": 0.0,
		"dmg": [0.6, 0.1], "stun": 2.0, "charge": true, "threat": true, "prio": 70,
	},
	"rockfall": {  # ← Tortus Blast: 3 удара по 120%…210%, угроза
		"name": "Камнепад", "kind": "active", "glyph": "К", "color": GREEN, "jp": 2,
		"desc": "Три удара подряд; зверь переключается на черепаху.",
		"tiers": [[0, 0], [90, 5], [140, 10]], "mp": [209.0, 19.0], "cd": 45.0, "cast": 0.5,
		"dmg": [1.2, 0.1], "hits": 3, "threat": true, "prio": 90,
	},
	"clan_wall": {  # ← Encouragement: Vitality (+8%…35% Vit на 10 с)
		"name": "Стена клана", "kind": "active", "glyph": "С", "color": TEAL, "jp": 2,
		"desc": "Черепаха прикрывает хозяина: он получает меньше урона 10 с.",
		"tiers": [[0, 0], [85, 5], [135, 10]], "mp": [98.0, 21.0], "cd": 90.0, "cast": 0.5,
		"buff": "guard", "value": [0.08, 0.03], "time": 10.0, "prio": 85,
	},
	"earthquake": {  # ← Tortus Special: 200% по площади + оглушение 3 с, угроза
		"name": "Землетрясение", "kind": "active", "glyph": "З", "color": Color(0.55, 0.45, 0.3), "jp": 2,
		"desc": "Удар по земле: урон и оглушение на 3 с всем зверям вокруг, они переключаются на черепаху.",
		"tiers": [[0, 0], [0, 0], [150, 1]], "pre": ["rockfall", [0, 0, 6]],
		"mp": [597.0, 0.0], "cd": 90.0, "cast": 0.75, "dmg": [2.0, 0.0], "radius": 5.0, "stun": 3.0,
		"threat": true, "prio": 100,
	},
	"shell_bond": {  # ← Unity: Tortus (+P.Def хозяину и питомцу +27…+125)
		"name": "Узы панциря", "kind": "toggle", "glyph": "У", "color": TEAL, "jp": 2,
		"desc": "Пока включено, защита хозяина и черепахи выше.",
		"tiers": [[45, 5], [95, 10], [145, 15]], "bonus": "def_flat", "value": [2.0, 0.5], "owner": true,
		"mp": [46.0, 36.0], "upkeep": [3.0, 3.0],
	},
	# ---------- Фазан (у нас лекарь: урон светом от маг. атаки) ----------
	"spark_peck": {  # ← Peck: 2 удара по 60%…200%
		"name": "Искристый клевок", "kind": "active", "glyph": "И", "color": GOLD, "jp": 1,
		"desc": "Два клевка светом подряд.",
		"tiers": [[10, 5], [60, 10], [110, 15]], "mp": [54.0, 9.0], "cd": 8.0, "cast": 0.5,
		"dmg": [0.6, 0.1], "hits": 2, "prio": 40,
	},
	"shrill_cry": {  # ← Poultry Crow: 170%…450% + снижение точности цели 6%…20% на 10 с
		"name": "Пронзительный клич", "kind": "active", "glyph": "П", "color": GOLD, "jp": 1,
		"desc": "Резкий клич светом: урон, и 10 с цель чаще промахивается.",
		"tiers": [[20, 5], [70, 10], [120, 15]], "pre": ["spark_peck", [1, 6, 11]],
		"mp": [117.0, 13.0], "cd": 15.0, "cast": 0.75, "dmg": [1.7, 0.2], "miss": [0.06, 0.01], "prio": 60,
	},
	"spur_strike": {  # ← Poultry Kick: 60%…200% + оглушение 2 с, угроза
		"name": "Удар шпорой", "kind": "active", "glyph": "Ш", "color": GOLD, "jp": 2,
		"desc": "Вспышка-удар шпорой: оглушение на 2 с, зверь переключается на фазана.",
		"tiers": [[30, 5], [80, 10], [130, 15]], "mp": [159.0, 9.0], "cd": 20.0, "cast": 0.0,
		"dmg": [0.6, 0.1], "stun": 2.0, "threat": true, "prio": 70,
	},
	"feather_storm": {  # ← Poultry Blast: 3 удара по 120%…210%
		"name": "Перьевой шквал", "kind": "active", "glyph": "Ш", "color": Color(1.0, 0.6, 0.3), "jp": 2,
		"desc": "Три удара сияющими перьями подряд.",
		"tiers": [[0, 0], [90, 5], [140, 10]], "mp": [209.0, 19.0], "cd": 45.0, "cast": 0.5,
		"dmg": [1.2, 0.1], "hits": 3, "prio": 90,
	},
	"dawn_song": {  # ← Encouragement: Dexterity (у нас лекарь: Меткость ↔ Мудрость → лечение)
		"name": "Песнь рассвета", "kind": "active", "glyph": "П", "color": Color(1.0, 0.85, 0.45), "jp": 2,
		"desc": "Тёплая песня лечит хозяина и фазана, когда им тяжело.",
		"tiers": [[0, 0], [85, 5], [135, 10]], "mp": [98.0, 21.0], "cd": 90.0, "cast": 0.5,
		"buff": "heal", "value": [0.05, 0.02], "prio": 85,
	},
	"dawn_curse": {  # ← Curse of Garuda: 200% по площади + снижение точности 30% на 10 с
		"name": "Проклятие зари", "kind": "active", "glyph": "З", "color": Color(1.0, 0.5, 0.2), "jp": 2,
		"desc": "Слепящая вспышка по зверям вокруг цели: урон, и 10 с они чаще промахиваются.",
		"tiers": [[0, 0], [0, 0], [150, 1]], "pre": ["feather_storm", [0, 0, 6]],
		"mp": [597.0, 0.0], "cd": 90.0, "cast": 0.75, "dmg": [2.0, 0.0], "radius": 5.0,
		"miss": [0.3, 0.0], "prio": 100,
	},
	"dawn_bond": {  # ← Unity: Poultry (у нас лекарь: вместо точности — восстановление HP хозяину и питомцу)
		"name": "Узы зари", "kind": "toggle", "glyph": "У", "color": Color(1.0, 0.8, 0.4), "jp": 2,
		"desc": "Пока включено, хозяин и фазан постоянно восстанавливают здоровье.",
		"tiers": [[45, 5], [95, 10], [145, 15]], "bonus": "hp_regen", "value": [0.5, 0.25], "owner": true,
		"mp": [46.0, 36.0], "upkeep": [3.0, 3.0],
	},
	# ---------- Кентавр (боец-копейщик: физический урон, числа — по Kentauros вики) ----------
	"spear_flurry": {  # ← Continuous Attack: 2 удара по 90%…230%
		"name": "Двойной выпад", "kind": "active", "glyph": "В", "color": Color(0.8, 0.55, 0.3), "jp": 1,
		"desc": "Два быстрых укола копьём подряд.",
		"tiers": [[10, 5], [60, 10], [110, 15]], "mp": [54.0, 9.0], "cd": 8.0, "cast": 0.5,
		"dmg": [0.9, 0.1], "hits": 2, "prio": 40,
	},
	"piercing_strike": {  # ← Kentauros Strike: 200%…480% + атака цели −13%…−27% на 10 с
		"name": "Пронзающий удар", "kind": "active", "glyph": "П", "color": Color(0.85, 0.45, 0.25), "jp": 1,
		"desc": "Тяжёлый удар копьём с разгона: большой урон, и 10 с удары цели слабее.",
		"tiers": [[20, 5], [70, 10], [120, 15]], "pre": ["spear_flurry", [1, 6, 11]],
		"mp": [117.0, 13.0], "cd": 15.0, "cast": 0.75, "dmg": [2.0, 0.2], "weaken": [0.13, 0.01], "prio": 60,
	},
	"hoof_quake": {  # ← Kentauros' Shuddering: 60%…200% + оглушение 2 с, угроза
		"name": "Топот копыт", "kind": "active", "glyph": "Т", "color": Color(0.65, 0.45, 0.3), "jp": 2,
		"desc": "Кентавр встаёт на дыбы и обрушивает копыта: урон и оглушение на 2 с, зверь переключается на него.",
		"tiers": [[30, 5], [80, 10], [130, 15]], "mp": [159.0, 9.0], "cd": 20.0, "cast": 0.0,
		"dmg": [0.6, 0.1], "stun": 2.0, "threat": true, "prio": 70,
	},
	"spear_storm": {  # ← Kentauros Blast: 3 удара по 170%…260%
		"name": "Копейный шквал", "kind": "active", "glyph": "Ш", "color": Color(0.9, 0.5, 0.2), "jp": 2,
		"desc": "Три мощных удара копьём подряд.",
		"tiers": [[0, 0], [90, 5], [140, 10]], "mp": [209.0, 19.0], "cd": 45.0, "cast": 0.5,
		"dmg": [1.7, 0.1], "hits": 3, "prio": 90,
	},
	"war_horn": {  # ← Encouragement: Strength (+12%…+57% Силы на 10 с)
		"name": "Боевой рог", "kind": "active", "glyph": "Р", "color": Color(0.95, 0.65, 0.3), "jp": 2,
		"desc": "Кентавр трубит в рог: атака хозяина выше на 15 с.",
		"tiers": [[0, 0], [85, 5], [135, 10]], "mp": [98.0, 21.0], "cd": 90.0, "cast": 0.5,
		"buff": "atk", "value": [0.06, 0.025], "time": 15.0, "prio": 85,
	},
	"ruin_storm": {  # ← Storm of Ruin: 240% по площади + атака целей −30% на 10 с
		"name": "Сокрушающий вихрь", "kind": "active", "glyph": "С", "color": Color(0.75, 0.3, 0.15), "jp": 2,
		"desc": "Копьё вихрем бьёт всех зверей вокруг цели: урон, и 10 с их удары слабее.",
		"tiers": [[0, 0], [0, 0], [150, 1]], "pre": ["spear_storm", [0, 0, 6]],
		"mp": [597.0, 0.0], "cd": 90.0, "cast": 0.75, "dmg": [2.4, 0.0], "radius": 5.0,
		"weaken": [0.3, 0.0], "prio": 100,
	},
	"steppe_bond": {  # ← Unity: Kentauros (+P.Atk хозяину и питомцу +68…+320 — сильнее, чем у пантеры)
		"name": "Узы степи", "kind": "toggle", "glyph": "У", "color": Color(0.9, 0.6, 0.35), "jp": 2,
		"desc": "Пока включено, атака хозяина и кентавра выше.",
		"tiers": [[45, 5], [95, 10], [145, 15]], "bonus": "atk_pct", "value": [0.06, 0.015], "owner": true,
		"mp": [46.0, 36.0], "upkeep": [3.0, 3.0],
	},
	# ---------- Волк (Wolf Pup → Warg → Fenrir; числа — база оригинала: SkillResource, StateResource, SkillTreeResource;
	# урон и MP — 1:1, перезарядки и каст — наши, как у других видов) ----------
	"rending_bite": {  # ← Gouging Bite: 160%…460% (+20 %/ур.), 10 с точность цели −11 %…−25 %
		"name": "Рвущий укус", "kind": "active", "glyph": "Р", "color": Color(0.85, 0.25, 0.25), "jp": 1,
		"desc": "Глубокий укус: большой урон, и 10 с зверь чаще промахивается.",
		"tiers": [[20, 5], [70, 10], [120, 15]], "pre": ["fierce_rush", [1, 6, 11]],
		"mp": [117.0, 13.0], "cd": 15.0, "cast": 0.75, "dmg": [1.8, 0.2], "miss": [0.11, 0.01], "prio": 60,
	},
	"chilling_howl": {  # ← Roar: страх 2.2…5.0 с (Fear, +0.2 с за ур.)
		"name": "Леденящий вой", "kind": "active", "glyph": "В", "color": Color(0.55, 0.75, 0.95), "jp": 2,
		"desc": "Волк воет: зверь в страхе убегает и не нападает.",
		"tiers": [[30, 5], [80, 10], [130, 15]], "mp": [127.0, 7.0], "cd": 30.0, "cast": 0.5,
		"fear": [2.2, 0.2], "prio": 65,
	},
	"lunging_bite": {  # ← Lunging Bite: рывок к цели, 60%…200%, оглушение 2 с
		"name": "Бросок волка", "kind": "active", "glyph": "Б", "color": Color(0.75, 0.6, 0.45), "jp": 2,
		"desc": "Разгон к цели в 3–10 м и укус в прыжке: оглушение на 2 с.",
		"tiers": [[35, 5], [85, 10], [135, 15]], "mp": [159.0, 9.0], "cd": 20.0, "cast": 0.0,
		"dmg": [0.6, 0.1], "stun": 2.0, "charge": true, "prio": 70,
	},
	"fang_flurry": {  # ← Shredding Fangs: 3 укуса по 130%…220%
		"name": "Шквал клыков", "kind": "active", "glyph": "Ш", "color": Color(0.8, 0.35, 0.3), "jp": 2,
		"desc": "Три мощных укуса подряд.",
		"tiers": [[0, 0], [90, 5], [140, 10]], "mp": [209.0, 19.0], "cd": 45.0, "cast": 0.5,
		"dmg": [1.3, 0.1], "hits": 3, "prio": 90,
	},
	"alpha_call": {  # ← Encouragement: Strength, Agility (Сила и Ловкость хозяина, 10 с)
		"name": "Клич вожака", "kind": "active", "glyph": "К", "color": Color(0.7, 0.8, 0.95), "jp": 2,
		"desc": "Волк зовёт стаю: атака хозяина выше на 10 с.",
		"tiers": [[0, 0], [85, 5], [135, 10]], "mp": [98.0, 21.0], "cd": 90.0, "cast": 0.5,
		"buff": "atk", "value": [0.06, 0.025], "time": 10.0, "prio": 85,
	},
	"moon_frenzy": {  # ← Rampage: 220% по зверям вокруг (4 м), 10 с их точность −30 %
		"name": "Лунное буйство", "kind": "active", "glyph": "Л", "color": Color(0.6, 0.65, 0.95), "jp": 2,
		"desc": "Вихрь укусов по всем зверям вокруг цели: урон, и 10 с они чаще промахиваются.",
		"tiers": [[0, 0], [0, 0], [150, 1]], "pre": ["fang_flurry", [0, 0, 6]],
		"mp": [597.0, 0.0], "cd": 90.0, "cast": 0.75, "dmg": [2.2, 0.0], "radius": 4.0,
		"miss": [0.3, 0.0], "prio": 100,
	},
	"pack_bond": {  # ← Unity: Wolf (уклонение хозяину и волку; в базе избегание +29…+147 — у нас доля уклонения)
		"name": "Узы стаи", "kind": "toggle", "glyph": "У", "color": Color(0.65, 0.75, 0.9), "jp": 2,
		"desc": "Пока включено, хозяин и волк чаще уклоняются от ударов.",
		"tiers": [[45, 5], [95, 10], [145, 15]], "bonus": "eva", "value": [2.0, 0.5], "owner": true,
		"mp": [46.0, 36.0], "upkeep": [3.0, 3.0],
	},
	# ---------- Кабан, каменный страж (своё: одно активное по роли); «Свирепый натиск» — и у волка ----------
	"fierce_rush": {  # ← у волка — Piercing Fangs: 2 укуса по 70%…210% (MP 54…180)
		"name": "Свирепый натиск", "kind": "active", "glyph": "С", "color": RED, "jp": 1,
		"desc": "Два стремительных укуса подряд.",
		"tiers": [[10, 5], [60, 10], [110, 15]], "mp": [54.0, 9.0], "cd": 8.0, "cast": 0.5,
		"dmg": [0.7, 0.1], "hits": 2, "prio": 50,
	},
	"ground_roar": {
		"name": "Гул земли", "kind": "active", "glyph": "Г", "color": Color(0.6, 0.6, 0.5), "jp": 1,
		"desc": "Удар по земле: урон зверям вокруг цели, они переключаются на стража.",
		"tiers": [[10, 5], [60, 10], [110, 15]], "mp": [80.0, 10.0], "cd": 15.0, "cast": 0.5,
		"dmg": [1.0, 0.1], "radius": 4.0, "threat": true, "prio": 50,
	},
}

## Умения вида в порядке открытия.
const SPECIES_SKILLS := {
	"panther": ["inner_fire", "hardening", "shadow_rend", "provoke", "dusk_rupture", "vitality", "deep_spring",
		"daze", "shadow_fang", "mending", "calm_mind", "shadow_bond", "keen_eye", "hunter_call", "shadow_squall",
		"endless_life", "midnight_vortex", "ancestor_gift"],
	"turtle": ["inner_fire", "hardening", "stone_jaws", "provoke", "shell_wrath", "vitality", "deep_spring",
		"daze", "ram", "mending", "calm_mind", "shell_bond", "keen_eye", "clan_wall", "rockfall",
		"endless_life", "earthquake", "ancestor_gift"],
	"pheasant": ["inner_fire", "hardening", "spark_peck", "provoke", "shrill_cry", "vitality", "deep_spring",
		"daze", "spur_strike", "mending", "calm_mind", "dawn_bond", "keen_eye", "dawn_song", "feather_storm",
		"feather_step", "dawn_curse", "ancestor_gift"],
	"centaur": ["inner_fire", "hardening", "spear_flurry", "provoke", "piercing_strike", "vitality", "deep_spring",
		"daze", "hoof_quake", "mending", "calm_mind", "steppe_bond", "keen_eye", "war_horn", "spear_storm",
		"endless_life", "ruin_storm", "ancestor_gift"],
	"boar": ["inner_fire", "hardening", "vitality", "fierce_rush"],
	"wolf": ["inner_fire", "hardening", "fierce_rush", "provoke", "rending_bite", "vitality", "deep_spring",
		"chilling_howl", "mending", "calm_mind", "lunging_bite", "pack_bond", "keen_eye", "alpha_call", "fang_flurry",
		"feather_step", "moon_frenzy", "ancestor_gift"],
	"golem": ["inner_fire", "hardening", "vitality", "ground_roar"],
}


## Умения существ из базы, которых раньше не было (0.31; SkillTreeResource 2101–2903, 1701–1703; задачи Максима
## «бонус существа», «снаряжение существа»): по виду — DB_EXTRAS, строит _static_init в _extra и _lists.
##   * «Знаток снаряжения» (Creature Item Expert): питомец получает долю характеристик надетых оружия и доспеха
##     и всю прибавку их заточки (PetGear);
##   * «Живучесть: доспех …» (Vital Unit, 40 ур.): макс. HP + доля, если надет доспех своего варианта (воина или охотника);
##   * «Боец: …» (Fighter Unit, 90 ур.): атака + доля с оружием ближнего боя (у фазана — крит с кинжалом);
##   * «Способность карты» ×2 (Card Ability, 40 и 90 ур.): карта питомца встаёт в пояс героя (PetBelt) и даёт герою
##     долю его характеристики (Сила, Выносливость …) или атаки / защиты / точности / избегания;
##     у этих пяти — ровно 3 уровня, по одному на форму питомца (PER_FORM: 1-я форма — до 1 ур., 2-я — до 2,
##     3-я — до 3; решение Максима). В базе каждое — умение в 1 уровень, а сила растёт с «рангом» существа
##     (варианты «<Stage N>» SkillResource: Item Expert 80 / 90 / 95 / 100 %, Vital и Fighter Unit, Card Ability —
##     5 / 10 / 12 / 14 / 16 / 18 %): ур. 1 — ранг вида в базе (пантера, черепаха, фазан — 1-й, волк — 2-й,
##     кентавр — 4-й), ур. 2 и 3 — следующие ранги. Требования: ур. 1 — уровень базы (1 / 40 / 90), ур. 2 — 2-я форма
##     (с 50 ур.; у «Бойца» и 2-й карты — с 90), ур. 3 — 3-я форма (со 100 ур.). Числа — tools/rappelz_db_reference.md;
##   * «Зализать раны» (Wound Lick, 2-я и 3-я форма): восстановление HP хозяину и питомцу на 30 с (база: +100 за
##     уровень — у нас × 0.03, как «Быстрое заживление» ← Meditation), тратит материал вида;
##   * «Создание: материал» (2-я форма, раз в 12 ч) и «Создание: зелье» (3-я форма, раз в час, нужен пустой флакон) —
##     вручную в окне существа (вид "manual");
##   * «Благословение …» ×6 (Blessing of Strength … Wisdom, Basic / Intermediate): +1 к характеристике за уровень,
##     с 51 ур. (1-я форма) и 101 ур. (2-я форма).
## Числа по уровням 1–3 (поле "value" — таблица из 3 чисел, value()): expert — доля снаряжения, unit — [Живучесть, Боец]
## (доли; у фазана «Боец» — крит, единицы), cards — [[ключ, [ур. 1, 2, 3]], …]. Без значения в базе (ранг 5–6 у
## «Способности карты: атака» кентавра, ранг 4 «избегания» волка) — по шагу +2 % соседних рангов.
const DB_EXTRAS := {
	"panther": {"expert": [0.8, 0.9, 0.95], "armor": "warrior", "vital": [0.05, 0.10, 0.12],
		"fighter": [0.05, 0.10, 0.12], "weapon": "melee",
		"cards": [["str", [0.05, 0.10, 0.12]], ["atk", [0.05, 0.10, 0.12]]], "material": "panther_fang"},
	"turtle": {"expert": [0.8, 0.9, 0.95], "armor": "warrior", "vital": [0.05, 0.10, 0.12],
		"fighter": [0.05, 0.10, 0.12], "weapon": "melee",
		"cards": [["vit", [0.05, 0.10, 0.12]], ["def", [0.05, 0.10, 0.12]]], "material": "shell_plate"},
	"pheasant": {"expert": [0.8, 0.9, 0.95], "armor": "hunter", "vital": [0.05, 0.10, 0.12],
		"fighter": [5.0, 10.0, 12.0], "weapon": "dagger",
		"cards": [["dex", [0.05, 0.10, 0.12]], ["acc", [0.05, 0.10, 0.12]]], "material": "pheasant_feather"},
	"wolf": {"expert": [0.9, 0.95, 1.0], "armor": "hunter", "vital": [0.10, 0.12, 0.14],
		"fighter": [0.10, 0.12, 0.14], "weapon": "melee",
		"cards": [["agi", [0.10, 0.12, 0.14]], ["avoid", [0.10, 0.12, 0.14]]], "material": "wolf_claw"},
	"centaur": {"expert": [1.0, 1.0, 1.0], "armor": "warrior", "vital": [0.14, 0.16, 0.18],
		"fighter": [0.14, 0.16, 0.18], "weapon": "melee",
		"cards": [["str", [0.14, 0.16, 0.18]], ["atk", [0.14, 0.16, 0.18]]], "material": "horse_hair"},
}
## Уровни умений «по формам» (у каждого — 3 уровня, по одному на форму): требования по стадиям для ур. 1, 2, 3.
const FORM_TIERS := {
	"item_expert": [[1, 1], [50, 2], [100, 3]],
	"vital_unit": [[40, 1], [50, 2], [100, 3]],
	"card_1": [[40, 1], [50, 2], [100, 3]],
	"fighter_unit": [[90, 1], [90, 2], [100, 3]],
	"card_2": [[90, 1], [90, 2], [100, 3]],
}
## Подписи характеристик и чисел для «Способности карты».
const CARD_NAMES := {"str": "Сила", "vit": "Выносливость", "agi": "Ловкость", "dex": "Меткость", "int": "Интеллект",
	"wis": "Мудрость", "luck": "Удача", "atk": "атака", "def": "защита", "acc": "точность", "avoid": "избегание"}
const BLESS_STATS := ["str", "int", "agi", "vit", "dex", "wis"]
static var _extra: Dictionary = {}
static var _lists: Dictionary = {}


static func _static_init() -> void:
	_extra.clear()
	_lists.clear()
	var arm := {"warrior": "доспех воина", "hunter": "доспех охотника"}
	for stv in BLESS_STATS:
		var st := String(stv)
		var nm := String(CARD_NAMES[st])
		_extra["bless_" + st] = {"name": "Благословение: %s" % nm, "kind": "passive", "glyph": nm.substr(0, 1), "color": GOLD,
			"jp": 1, "desc": "%s питомца выше на 1 за уровень умения." % nm, "tiers": [[51, 10], [101, 20], [0, 0]],
			"bonus": "stat_" + st, "value": [1.0, 1.0]}
	for spv in DB_EXTRAS:
		var sp := String(spv)
		var d: Dictionary = DB_EXTRAS[sp]
		var ids: Array = []
		var ex := "item_expert_" + sp
		var xp: Array = d["expert"]
		_extra[ex] = {"name": "Знаток снаряжения", "kind": "passive", "glyph": "С", "color": GRAY, "jp": 1, "per_form": true,
			"desc": "Питомец носит оружие и доспех (окно существа, вкладка «Оружие и доспехи»; нужна карта снаряжения) и получает долю их характеристик (%s %% по уровням умения) и всю прибавку заточки." % _pct_list(xp),
			"tiers": FORM_TIERS["item_expert"], "bonus": "item_expert", "value": xp}
		ids.append(ex)
		var vu := "vital_unit_" + sp
		var av := String(d["armor"])
		_extra[vu] = {"name": "Живучесть: %s" % String(arm[av]), "kind": "passive", "glyph": "Ж", "color": Color(0.85, 0.3, 0.35),
			"jp": 1, "armor": av, "per_form": true, "desc": "Макс. HP питомца выше, когда на нём %s." % String(arm[av]),
			"tiers": FORM_TIERS["vital_unit"], "bonus": "vital_unit", "value": d["vital"]}
		ids.append(vu)
		var fu := "fighter_unit_" + sp
		var dagger := String(d["weapon"]) == "dagger"
		_extra[fu] = {"name": "Боец: кинжал" if dagger else "Боец: ближний бой", "kind": "passive", "glyph": "Б", "color": RED,
			"jp": 1, "weapon": String(d["weapon"]), "per_form": true,
			"desc": "Шанс крита питомца выше, когда на нём кинжал." if dagger else "Атака питомца выше, когда на нём оружие ближнего боя.",
			"tiers": FORM_TIERS["fighter_unit"], "bonus": "fighter_unit", "value": d["fighter"]}
		ids.append(fu)
		for k in 2:
			var c: Array = d["cards"][k]
			var cid := "card_%s_%d" % [sp, k + 1]
			var what := String(CARD_NAMES[String(c[0])])
			_extra[cid] = {"name": "Способность карты: %s" % what, "kind": "passive", "glyph": "К", "color": VIOLET, "jp": 1,
				"card": String(c[0]), "per_form": true,
				"desc": "Отозванного питомца можно вставить в пояс героя (сумка, пояс с картами существ): %s героя выше (%s %% по уровням умения)." % [what, _pct_list(c[1])],
				"tiers": FORM_TIERS["card_%d" % (k + 1)], "bonus": "card", "value": c[1]}
			ids.append(cid)
		var mat := String(d["material"])
		var wl := "wound_lick_" + sp
		_extra[wl] = {"name": "Зализать раны", "kind": "active", "glyph": "З", "color": Color(0.4, 0.85, 0.45), "jp": 2,
			"desc": "Восстановление HP хозяину и питомцу на 30 с. Тратит «%s» из сумки." % ItemData.item_name(mat),
			"tiers": [[0, 0], [50, 1], [100, 2]], "mp": [30.0, 10.0], "cd": 1200.0, "cast": 0.5, "buff": "regen",
			"value": [3.0, 3.0], "time": 30.0, "needs": mat, "prio": 5}
		ids.append(wl)
		var cm := "creation_" + sp
		_extra[cm] = {"name": "Создание: %s" % ItemData.item_name(mat), "kind": "manual", "glyph": "+", "color": GOLD, "jp": 1,
			"desc": "Питомец создаёт «%s» (для «Зализать раны»). Раз в 12 часов." % ItemData.item_name(mat),
			"tiers": [[0, 0], [50, 1], [0, 0]], "mp": [1000.0, 0.0], "cd": 43200.0, "creates": mat}
		ids.append(cm)
		var cp := "creation_potion_" + sp
		var pot := "potion_" + sp
		_extra[cp] = {"name": "Создание: зелье", "kind": "manual", "glyph": "+", "color": GOLD, "jp": 2,
			"desc": "Питомец варит «%s» (герою на 1 час) из пустого флакона. Раз в час." % ItemData.item_name(pot),
			"tiers": [[0, 0], [0, 0], [100, 1]], "mp": [2000.0, 0.0], "cd": 3600.0, "creates": pot, "needs": "empty_bottle"}
		ids.append(cp)
		for st in BLESS_STATS:
			ids.append("bless_" + st)
		var base: Array = SPECIES_SKILLS.get(sp, [])
		_lists[sp] = base + ids


static func get_skill(id: String) -> Dictionary:
	if SKILLS.has(id):
		return SKILLS[id]
	return _extra.get(id, {})


## id умений вида.
static func list_for(species: String) -> Array:
	if _lists.has(species):
		return _lists[species]
	return SPECIES_SKILLS.get(species, SPECIES_SKILLS["boar"])


static func has_skill(species: String, id: String) -> bool:
	return list_for(species).has(id)


## Значение поля-пары [на 1 ур., за уровень] на уровне умения n (n ≥ 1). Массив из 3 и больше чисел — таблица
## по уровням (ур. 1, 2, 3 …; умения «по формам» из базы — DB_EXTRAS); выше последнего — последнее.
static func value(pair: Array, n: int) -> float:
	if pair.size() > 2:
		return float(pair[clampi(n - 1, 0, pair.size() - 1)])
	if pair.size() < 2:
		return 0.0
	return float(pair[0]) + float(pair[1]) * float(maxi(n, 1) - 1)


## «80 / 90 / 95» — таблица долей по уровням.
static func _pct_list(vals: Array) -> String:
	var parts: PackedStringArray = []
	for v in vals:
		parts.append(str(roundi(float(v) * 100.0)) if float(v) <= 1.0 else str(roundi(float(v))))
	return " / ".join(parts)


## Уровень вики → наш уровень питомца: 1:1 с оригиналом (решение Максима), не меньше 1.
static func req_level(wiki_lvl: int) -> int:
	return maxi(1, wiki_lvl)


## Наибольший уровень умения.
static func max_level(id: String) -> int:
	var best := 0
	for t in get_skill(id).get("tiers", []):
		best = maxi(best, int(t[1]))
	return best


## Номер стадии (0..2), на которой открывается уровень n умения; -1 — такого уровня нет.
static func tier_for(id: String, n: int) -> int:
	var tiers: Array = get_skill(id).get("tiers", [])
	for i in tiers.size():
		if int(tiers[i][1]) >= n:
			return i
	return -1


## Стадия (0..2), на которой умение появляется.
static func first_stage(id: String) -> int:
	return maxi(0, tier_for(id, 1))


## Наш уровень питомца, нужный для уровня n умения (0 — такого уровня нет).
static func level_needed(id: String, n: int) -> int:
	var t := tier_for(id, n)
	if t < 0:
		return 0
	var tiers: Array = get_skill(id)["tiers"]
	return req_level(int(tiers[t][0]))


## Наибольший уровень умения, доступный питомцу уровня lvl на стадии st (по стадии и уровню).
static func cap_for(id: String, lvl: int, st: int = 0) -> int:
	var tiers: Array = get_skill(id).get("tiers", [])
	var best := 0
	for i in tiers.size():
		var mx := int(tiers[i][1])
		if mx <= 0 or i > st or lvl < req_level(int(tiers[i][0])):
			continue
		best = maxi(best, mx)
	return best


## Стоимость применения (активные, включение переключаемых) на уровне n, наш MP.
static func mp_cost(id: String, n: int) -> int:
	var sk := get_skill(id)
	if not sk.has("mp"):
		return 0
	return maxi(1, roundi(value(sk["mp"], n) * MP_SCALE))


## Поддержка переключаемого умения на уровне n: MP за UPKEEP_PERIOD секунд.
static func upkeep(id: String, n: int) -> int:
	var sk := get_skill(id)
	if not sk.has("upkeep"):
		return 0
	return maxi(1, roundi(value(sk["upkeep"], n) * MP_SCALE))


## Сила эффекта field (пара) на уровне n.
static func field(id: String, key: String, n: int) -> float:
	var sk := get_skill(id)
	if not sk.has(key):
		return 0.0
	var v: Variant = sk[key]
	if v is Array:
		return value(v, n)
	return float(v)


# ---------- Запись питомца ----------

## Дополняет запись питомца (Game.pets) полями умений: jp, jp_part, skills {id: ур.}, toggles {id: true}, mp,
## ячейки slots (3 id активных, "" — пусто), aura_slots (2 id переключаемых), команда cmd. Ячейки чистятся:
## неизученное, чужое виду и умение не того типа убираются; включённое переключаемое без ячейки занимает
## свободную ячейку ауры, а если их нет — выключается. Массивы и словари меняются на месте (питомец в мире
## держит ссылки на них).
static func ensure_record(rec: Dictionary) -> void:
	if not rec.has("jp"):
		rec["jp"] = PetStats.default_jp(int(rec.get("level", 1)))
	if not rec.has("jp_part"):
		rec["jp_part"] = 0.0
	if not (rec.get("skills") is Dictionary):
		rec["skills"] = {}
	if not (rec.get("toggles") is Dictionary):
		rec["toggles"] = {}
	if not rec.has("mp"):
		rec["mp"] = -1
	if not COMMANDS.has(String(rec.get("cmd", ""))):
		rec["cmd"] = DEFAULT_COMMAND
	_clamp_form_levels(rec)
	_ensure_slots(rec)


## Наибольший уровень умения id на форме st (0..2) без учёта уровня питомца.
static func form_cap(id: String, st: int) -> int:
	var best := 0
	var tiers: Array = get_skill(id).get("tiers", [])
	for i in mini(st + 1, tiers.size()):
		best = maxi(best, int(tiers[i][1]))
	return best


## Умения «по формам» (поле per_form: «Знаток снаряжения», «Живучесть», «Боец», «Способности карты») — не выше, чем
## разрешает форма питомца (старые записи, возврат в 1-ю форму); лишние уровни снимаются, их JP возвращаются.
static func _clamp_form_levels(rec: Dictionary) -> void:
	var skills: Dictionary = rec["skills"]
	var st := PetData.stage_of(rec)
	for k in skills.keys():
		var id := String(k)
		var sk := get_skill(id)
		if not bool(sk.get("per_form", false)):
			continue
		var cap := form_cap(id, st)
		var n := int(skills[k])
		if n > cap:
			rec["jp"] = int(rec.get("jp", 0)) + (n - cap) * int(sk.get("jp", 1))
			if cap > 0:
				skills[k] = cap
			else:
				skills.erase(k)


## Ячейки «Авто» и «Ауры»: перенос старых записей и чистка (см. ensure_record).
static func _ensure_slots(rec: Dictionary) -> void:
	var sp := String(rec.get("species", "boar"))
	var skills: Dictionary = rec["skills"]
	var toggles: Dictionary = rec["toggles"]
	var migrate := not (rec.get("slots") is Array)
	var auto := _clean_slots(rec.get("slots", []), AUTO_SLOTS, sp, skills, "active")
	var aura := _clean_slots(rec.get("aura_slots", []), AURA_SLOTS, sp, skills, "toggle")
	if migrate:
		# Старая запись: изученные активные — по силе (prio), как раньше выбирал ИИ
		var learned: Array[String] = []
		for aid in list_for(sp):
			var act := String(aid)
			if String(get_skill(act).get("kind", "")) == "active" and int(skills.get(act, 0)) > 0:
				learned.append(act)
		learned.sort_custom(func(a: String, b: String) -> bool:
			return int(get_skill(a).get("prio", 0)) > int(get_skill(b).get("prio", 0)))
		for lid in learned:
			var empty_i := auto.find("")
			if empty_i < 0:
				break
			auto[empty_i] = lid
	# Включённые переключаемые: в ячейках ауры; без ячейки — в свободную, мест нет — выключить
	for id in list_for(sp):
		var sid := String(id)
		if not bool(toggles.get(sid, false)) or aura.has(sid):
			continue
		var free := aura.find("")
		if free >= 0 and String(get_skill(sid).get("kind", "")) == "toggle" and int(skills.get(sid, 0)) > 0:
			aura[free] = sid
		else:
			toggles.erase(sid)
	for k in toggles.keys():
		if not aura.has(String(k)):
			toggles.erase(k)
	_store_slots(rec, "slots", auto)
	_store_slots(rec, "aura_slots", aura)


## count ячеек из src: только изученные умения вида с типом kind, без повторов; остальное — "".
static func _clean_slots(src: Variant, count: int, species: String, skills: Dictionary, kind: String) -> Array:
	var res: Array = []
	var arr: Array = src if src is Array else []
	for i in count:
		var id: String = String(arr[i]) if i < arr.size() and arr[i] is String else ""
		if id != "" and (res.has(id) or not has_skill(species, id) or int(skills.get(id, 0)) <= 0
				or String(get_skill(id).get("kind", "")) != kind):
			id = ""
		res.append(id)
	return res


## Записать ячейки в rec[key]: тот же массив (на месте), если он уже есть.
static func _store_slots(rec: Dictionary, key: String, vals: Array) -> void:
	var cur: Variant = rec.get(key, null)
	if cur is Array:
		var a: Array = cur
		if a == vals:
			return
		a.clear()
		a.append_array(vals)
	else:
		rec[key] = vals


# ---------- Ячейки умений («Авто» и «Ауры») ----------

## Ячейка для умения id: "auto" (активное), "aura" (переключаемое), "" — пассивное, в ячейку не ставится.
static func slot_kind(id: String) -> String:
	match String(get_skill(id).get("kind", "")):
		"active":
			return "auto"
		"toggle":
			return "aura"
	return ""


## Ячейки записи: kind "auto" — slots, "aura" — aura_slots (массив записи, не копия).
static func slots_of(rec: Dictionary, kind: String) -> Array:
	ensure_record(rec)
	return rec["aura_slots"] if kind == "aura" else rec["slots"]


## Номер ячейки, где стоит умение id (-1 — не стоит).
static func slot_of(rec: Dictionary, id: String) -> int:
	var kind := slot_kind(id)
	if kind == "":
		return -1
	return slots_of(rec, kind).find(id)


## Первая свободная ячейка kind (-1 — все заняты).
static func free_slot(rec: Dictionary, kind: String) -> int:
	return slots_of(rec, kind).find("")


## Почему умение id нельзя поставить в ячейку ("" — можно).
static func slot_block(rec: Dictionary, id: String) -> String:
	var sp := String(rec.get("species", "boar"))
	if get_skill(id).is_empty() or not has_skill(sp, id):
		return "Этому виду умение недоступно"
	if slot_kind(id) == "":
		return "Пассивное умение действует всегда, ячейка не нужна"
	if skill_level(rec, id) <= 0:
		return "Сначала изучите умение"
	return ""


## Поставить умение id в ячейку idx своего типа ("" — получилось, иначе причина). Умение из другой ячейки
## переносится (стоявшее там меняется с ним местами); вытесненная аура выключается. Включение ауры (MP) —
## у призванного питомца (Pet.assign_slot), у отдыхающего — отметка в записи (CreatureWindow).
static func assign_slot(rec: Dictionary, id: String, idx: int) -> String:
	var why := slot_block(rec, id)
	if why != "":
		return why
	var kind := slot_kind(id)
	var arr := slots_of(rec, kind)
	if idx < 0 or idx >= arr.size():
		return "Нет такой ячейки"
	var old := arr.find(id)
	var prev := String(arr[idx])
	if old == idx:
		return ""
	if old >= 0:
		arr[old] = prev
	elif prev != "" and kind == "aura":
		(rec["toggles"] as Dictionary).erase(prev)
	arr[idx] = id
	return ""


## Убрать умение из ячейки idx типа kind; аура выключается. Возвращает id убранного ("" — ячейка была пуста).
static func clear_slot(rec: Dictionary, kind: String, idx: int) -> String:
	var arr := slots_of(rec, kind)
	if idx < 0 or idx >= arr.size():
		return ""
	var id := String(arr[idx])
	arr[idx] = ""
	if kind == "aura" and id != "":
		(rec["toggles"] as Dictionary).erase(id)
	return id


## Режим питомца из записи ("auto" | "defend" | "follow").
static func command(rec: Dictionary) -> String:
	var c := String(rec.get("cmd", DEFAULT_COMMAND))
	return c if COMMANDS.has(c) else DEFAULT_COMMAND


static func skill_level(rec: Dictionary, id: String) -> int:
	var sk: Variant = rec.get("skills", {})
	if sk is Dictionary:
		return int((sk as Dictionary).get(id, 0))
	return 0


static func toggle_on(rec: Dictionary, id: String) -> bool:
	var tg: Variant = rec.get("toggles", {})
	if tg is Dictionary:
		return bool((tg as Dictionary).get(id, false))
	return false


## Почему нельзя изучить следующий уровень умения id ("" — можно).
static func learn_block(rec: Dictionary, id: String) -> String:
	var species := String(rec.get("species", "boar"))
	var sk := get_skill(id)
	if sk.is_empty() or not has_skill(species, id):
		return "Этому виду умение недоступно"
	var cur := skill_level(rec, id)
	var n := cur + 1
	if n > max_level(id):
		return "Изучено полностью"
	var t := tier_for(id, n)
	var lvl := int(rec.get("level", 1))
	var st := PetData.stage_of(rec)
	var need_lvl := level_needed(id, n)
	if st < t:
		return "Нужна стадия %d (эволюция у Учителя Кирка, ур. %d)" % [t + 1, need_lvl]
	if lvl < need_lvl:
		return "Нужен ур. %d" % need_lvl
	if sk.has("pre"):
		var pre: Array = sk["pre"]
		var pre_id := String(pre[0])
		var pre_lvls: Array = pre[1]
		var pl := int(pre_lvls[t])
		if pl > 0 and skill_level(rec, pre_id) < pl:
			return "Нужно «%s» ур. %d" % [String(get_skill(pre_id)["name"]), pl]
	var cost := int(sk["jp"])
	if int(rec.get("jp", 0)) < cost:
		return "Не хватает JP (нужно %d)" % cost
	return ""


## Изучить следующий уровень умения id: тратит JP. true — изучено.
static func learn(rec: Dictionary, id: String) -> bool:
	ensure_record(rec)
	if learn_block(rec, id) != "":
		return false
	var skills: Dictionary = rec["skills"]
	var first := skill_level(rec, id) == 0
	skills[id] = skill_level(rec, id) + 1
	rec["jp"] = int(rec["jp"]) - int(get_skill(id)["jp"])
	# Новое активное умение само встаёт в свободную ячейку «Авто» (ИИ применяет только умения из ячеек)
	if first and slot_kind(id) == "auto":
		var free := free_slot(rec, "auto")
		if free >= 0 and slot_of(rec, id) < 0:
			assign_slot(rec, id, free)
	return true


# ---------- Бонусы ----------

## Сумма бонусов пассивных умений и включённых переключаемых: {"atk_pct", "def_pct", "def_flat", "hp_pct",
## "mp_pct", "hp_regen", "mp_regen", "acc", "eva", "crit", "all_stats", "threat"}.
## owner_only = true: только то, что переключаемые умения дают хозяину (поле owner).
static func bonuses(species: String, skills: Dictionary, toggles: Dictionary, owner_only: bool = false) -> Dictionary:
	var res: Dictionary = {}
	for id in list_for(species):
		var sk := get_skill(String(id))
		if not sk.has("bonus"):
			continue
		var n := int(skills.get(id, 0))
		if n <= 0:
			continue
		var kind := String(sk["kind"])
		if kind == "toggle" and not bool(toggles.get(id, false)):
			continue
		if owner_only and not bool(sk.get("owner", false)):
			continue
		var key := String(sk["bonus"])
		res[key] = float(res.get(key, 0.0)) + value(sk["value"], n)
	return res


# ---------- Вкладки окна существа ----------

## Вкладки умений окна существа: [ключ, подпись, значок UiIcons].
const TABS := [["active", "Активные", "tab_pet_active"], ["aura", "Ауры и бафы", "tab_pet_auras"],
	["passive", "Пассивные", "tab_pet_passive"]]


## Вкладка умения id: "active" — активные (урон, ослабления зверя) и «Создание» (вручную), "aura" — переключаемые
## (узы, вызов) и активные усиления (поле buff: клич, стена, песнь, «Зализать раны»), "passive" — пассивные (в т. ч.
## «Знаток снаряжения», «Живучесть», «Боец», «Способности карты», «Благословения»).
static func tab_of(id: String) -> String:
	var sk := get_skill(id)
	match String(sk.get("kind", "")):
		"toggle":
			return "aura"
		"passive":
			return "passive"
		"active":
			return "aura" if sk.has("buff") else "active"
	return "active"


## Умения вида на вкладке tab (в порядке list_for).
static func list_tab(species: String, tab: String) -> Array:
	var res: Array = []
	for id in list_for(species):
		if tab_of(String(id)) == tab:
			res.append(String(id))
	return res


# ---------- Тексты для окна существа ----------

static func kind_name(id: String) -> String:
	return String(KIND_NAMES.get(String(get_skill(id).get("kind", "")), ""))


static func _pct(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)


static func _num(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(roundi(v))
	return "%.1f" % v


## Эффект умения id на уровне n (n ≥ 1) одной строкой: урон, эффекты, MP, перезарядка.
static func effect_text(id: String, n: int) -> String:
	var sk := get_skill(id)
	var parts: PackedStringArray = []
	var kind := String(sk.get("kind", ""))
	if kind == "passive" or kind == "toggle":
		var v := value(sk["value"], n)
		match String(sk["bonus"]):
			"atk_pct":
				parts.append("атака +%s" % _pct(v))
			"def_pct":
				parts.append("защита +%s" % _pct(v))
			"def_flat":
				parts.append("защита +%s" % _num(v))
			"hp_pct":
				parts.append("макс. HP +%s" % _pct(v))
			"mp_pct":
				parts.append("макс. MP +%s" % _pct(v))
			"hp_regen":
				parts.append("HP +%s/с" % _num(v))
			"mp_regen":
				parts.append("MP +%s/с" % _num(v))
			"acc":
				parts.append("точность +%s" % _num(v))
			"eva":
				parts.append("уклонение +%s%%" % _num(v))
			"all_stats":
				parts.append("все характеристики +%s" % _num(v))
			"threat":
				parts.append("шанс отвлечь зверя %s" % _pct(v))
			"item_expert":
				parts.append("%s характеристик снаряжения, 100%% заточки" % _pct(v))
			"vital_unit":
				parts.append("макс. HP +%s с доспехом" % _pct(v))
			"fighter_unit":
				if String(sk.get("weapon", "")) == "dagger":
					parts.append("крит +%s с кинжалом" % _num(v))
				else:
					parts.append("атака +%s с оружием ближнего боя" % _pct(v))
			"card":
				parts.append("в поясе: %s героя +%s" % [String(CARD_NAMES.get(String(sk.get("card", "")), "")), _pct(v)])
			_:
				if String(sk["bonus"]).begins_with("stat_"):
					parts.append("%s +%s" % [String(CARD_NAMES.get(String(sk["bonus"]).substr(5), "")), _num(v)])
		if bool(sk.get("owner", false)):
			parts[parts.size() - 1] = parts[parts.size() - 1] + " (и хозяину)"
		if kind == "toggle":
			parts.append("включение %d MP, %d MP / 10 с" % [mp_cost(id, n), upkeep(id, n)])
		return ", ".join(parts)
	if kind == "manual":
		var need := String(sk.get("needs", ""))
		return "создаёт «%s»%s, MP %d, раз в %s" % [ItemData.item_name(String(sk.get("creates", ""))),
			(" из «%s»" % ItemData.item_name(need)) if need != "" else "", mp_cost(id, n),
			("%d ч" % roundi(float(sk["cd"]) / 3600.0))]
	if sk.has("dmg"):
		var hits := int(sk.get("hits", 1))
		var d := _pct(value(sk["dmg"], n))
		parts.append(("урон %d × %s" % [hits, d]) if hits > 1 else "урон %s" % d)
	if sk.has("radius"):
		parts.append("по площади %s м" % _num(float(sk["radius"])))
	if sk.has("slow"):
		parts.append("замедление %s на 10 с" % _pct(value(sk["slow"], n)))
	if sk.has("vuln"):
		parts.append("урон по цели +%s на 10 с" % _pct(value(sk["vuln"], n)))
	if sk.has("miss"):
		parts.append("промахи зверя +%s на 10 с" % _pct(value(sk["miss"], n)))
	if sk.has("weaken"):
		parts.append("атака зверя −%s на 10 с" % _pct(value(sk["weaken"], n)))
	if sk.has("stun"):
		parts.append("оглушение %s с" % _num(float(sk["stun"])))
	if sk.has("blind"):
		parts.append("морок %s с" % _num(value(sk["blind"], n)))
	if sk.has("fear"):
		parts.append("страх %s с" % _num(value(sk["fear"], n)))
	match String(sk.get("buff", "")):
		"atk":
			parts.append("атака хозяина +%s на %s с" % [_pct(value(sk["value"], n)), _num(float(sk["time"]))])
		"guard":
			parts.append("урон по хозяину −%s на %s с" % [_pct(value(sk["value"], n)), _num(float(sk["time"]))])
		"heal":
			parts.append("лечение %s макс. HP" % _pct(value(sk["value"], n)))
		"regen":
			parts.append("восст. HP +%s хозяину и питомцу на %s с, тратит «%s»" % [_num(value(sk["value"], n)),
				_num(float(sk["time"])), ItemData.item_name(String(sk.get("needs", "")))])
	parts.append("MP %d" % mp_cost(id, n))
	parts.append("перезарядка %s с" % _num(float(sk["cd"])))
	return ", ".join(parts)


## Требования к уровню n умения одной строкой: «ур. 6, стадия 1, после «…» ур. 1, 1 JP».
static func requirement_text(id: String, n: int) -> String:
	var sk := get_skill(id)
	var t := tier_for(id, n)
	if t < 0:
		return ""
	var parts: PackedStringArray = ["ур. %d" % level_needed(id, n), "стадия %d" % (t + 1)]
	if sk.has("pre"):
		var pre: Array = sk["pre"]
		var pl := int(pre[1][t])
		if pl > 0:
			parts.append("«%s» ур. %d" % [String(get_skill(String(pre[0]))["name"]), pl])
	parts.append("%d JP" % int(sk["jp"]))
	return ", ".join(parts)
