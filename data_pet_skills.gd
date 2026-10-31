class_name PetSkills
extends RefCounted
## Умения питомцев (механика и числа — по образцу Rappelz: Pantera, Tortus, Poultry, Kentauros; названия, описания
## и значки свои). Умение изучается и повышается за очки умений (JP) в окне существа (CreatureWindow).
## Уровни умения открываются блоками по стадиям эволюции: tiers = [[уровень вики, макс. ур. умения], ...]
## на 1-й, 2-й и 3-й стадии ([0, 0] — на этой стадии умения ещё нет). Уровень вики → наш: × 0.3 (req_level()).
## Виды умений: "active" — применяет ИИ питомца (цель есть, перезарядка готова, хватает MP; сильные первыми),
## "toggle" — включается в окне существа и тратит MP каждые 10 с, "passive" — действует всегда.
## Числовые поля — [на 1 уровне, прибавка за уровень] (value()). MP — в единицах вики, × MP_SCALE.
## Перезарядки (cd) и время каста (cast) — наши: бои на острове короткие (вики — в tools/rappelz_pet_reference.md).
##
## Поля активных: dmg — доля главной атаки роли за удар, hits — число ударов, radius — по площади вокруг цели,
## threat — зверь переключается на питомца, charge — рывок к цели в 3–10 м, slow / vuln / miss — замедление,
## уязвимость (больше урона) и промахи зверя (доля, 10 с), weaken — ослабление: удары зверя слабее (доля, 10 с),
## stun — оглушение (с), blind — морок: зверь бьёт мимо (с),
## buff — "atk" (атака хозяина, % на time с), "guard" (хозяин получает меньше урона), "heal" (лечение хозяина
## и питомца, доля макс. HP). prio — порядок выбора ИИ (больше — раньше).
## Поля пассивных и переключаемых: bonus — что усиливает (PetStats.derived), value; owner — бонус и хозяину.

## Очки умений: у нового питомца и за каждый уровень опыта (начисляются по долям за убийства).
const JP_START := 2
const JP_PER_LEVEL := 3
## Стоимость MP из вики × MP_SCALE (наш запас MP примерно в 10 раз меньше).
const MP_SCALE := 0.1
## Поддержка переключаемых умений списывается раз в UPKEEP_PERIOD секунд.
const UPKEEP_PERIOD := 10.0
const KIND_NAMES := {"active": "активное", "passive": "пассивное", "toggle": "переключаемое"}

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
	# ---------- Кабан, волк, каменный страж (своё: одно активное по роли) ----------
	"fierce_rush": {
		"name": "Свирепый натиск", "kind": "active", "glyph": "С", "color": RED, "jp": 1,
		"desc": "Мощный удар по цели.",
		"tiers": [[10, 5], [60, 10], [110, 15]], "mp": [60.0, 10.0], "cd": 10.0, "cast": 0.0,
		"dmg": [1.5, 0.15], "prio": 50,
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
	"wolf": ["inner_fire", "hardening", "vitality", "fierce_rush"],
	"golem": ["inner_fire", "hardening", "vitality", "ground_roar"],
}


static func get_skill(id: String) -> Dictionary:
	return SKILLS.get(id, {})


## id умений вида.
static func list_for(species: String) -> Array:
	return SPECIES_SKILLS.get(species, SPECIES_SKILLS["boar"])


static func has_skill(species: String, id: String) -> bool:
	return list_for(species).has(id)


## Значение поля-пары [на 1 ур., за уровень] на уровне умения n (n ≥ 1).
static func value(pair: Array, n: int) -> float:
	if pair.size() < 2:
		return 0.0
	return float(pair[0]) + float(pair[1]) * float(maxi(n, 1) - 1)


## Уровень вики → наш уровень питомца: × 0.3, к ближайшему, не меньше 1.
static func req_level(wiki_lvl: int) -> int:
	return maxi(1, roundi(float(wiki_lvl) * PetStats.WIKI_LEVEL_SCALE))


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


## Наибольший уровень умения, доступный питомцу уровня lvl (по стадии и уровню).
static func cap_for(id: String, lvl: int) -> int:
	var st := PetData.stage_for(lvl)
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

## Дополняет запись питомца (Game.pets) полями умений: jp, jp_part, skills {id: ур.}, toggles {id: true}, mp.
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
	var st := PetData.stage_for(lvl)
	var need_lvl := level_needed(id, n)
	if st < t:
		return "Нужна стадия %d (ур. %d)" % [t + 1, need_lvl]
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
	skills[id] = skill_level(rec, id) + 1
	rec["jp"] = int(rec["jp"]) - int(get_skill(id)["jp"])
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
		if bool(sk.get("owner", false)):
			parts[parts.size() - 1] = parts[parts.size() - 1] + " (и хозяину)"
		if kind == "toggle":
			parts.append("включение %d MP, %d MP / 10 с" % [mp_cost(id, n), upkeep(id, n)])
		return ", ".join(parts)
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
	match String(sk.get("buff", "")):
		"atk":
			parts.append("атака хозяина +%s на %s с" % [_pct(value(sk["value"], n)), _num(float(sk["time"]))])
		"guard":
			parts.append("урон по хозяину −%s на %s с" % [_pct(value(sk["value"], n)), _num(float(sk["time"]))])
		"heal":
			parts.append("лечение %s макс. HP" % _pct(value(sk["value"], n)))
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
