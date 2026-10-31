class_name QuestData
extends RefCounted
## Задания (как в MMORPG): кто выдаёт и кому сдавать, тексты, требования, цели, награды. Логика — Quests,
## журнал — QuestWindow, разговор с NPC — Npcs. Состояние игрока — Game.quests_active / quests_done.
##
## Поля задания:
##   name — название; giver — NPC, который выдаёт (NpcData); turn_in — кому сдавать (по умолчанию giver);
##   level — с какого уровня героя можно взять; prev — какое задание нужно сдать раньше ("" — никакое);
##   repeatable — можно брать снова после сдачи;
##   wanderer_only — только для Бродяги (задание на профессию: после смены профессии не предлагается);
##   job_choice — сдача открывает окно выбора профессии (JobWindow): задание сдаётся вместе с выбором;
##   desc — описание в журнале; offer — реплика NPC при выдаче; progress — реплика, пока задание не выполнено;
##   done — реплика при сдаче;
##   goals — цели (см. ниже); rewards — {"xp": опыт героя, "gold": золото, "items": {id: количество},
##   "jp": очки умений героя}.
## Цель — словарь: type, n (сколько; у "level" — нужный уровень), text (подпись; по умолчанию — goal_text) и:
##   "kill"     — победить n зверей вида target ("" — любых), min_level — не ниже этого уровня;
##   "tame"     — поймать душу зверя вида target ("" — любого) в карту существа;
##   "form"     — сформировать существо вида target из карты с душой;
##   "summon"   — призвать питомца (вида target);
##   "pet_kill" — победить n зверей (вида target), пока призван живой питомец;
##   "buy"      — купить n штук любого из items у NPC npc ("" — у любого);
##   "collect"  — иметь в сумке n штук любого из items; take = true — забрать при сдаче;
##   "level"    — достичь уровня n;
##   "talk"     — поговорить с NPC npc ("@elder" — староста деревни расы героя, ELDERS).
##   counts_existing = true (для событийных целей) — цель засчитывается сразу при взятии, если игрок уже это
##   сделал раньше (карта или душа в сумке, существо в коллекции, питомец призван) — цепочка не застревает.
##
## Опыт наград — от таблицы опыта героя (Game.xp_to_next): примерно 35–65 % уровня, с которого задание
## можно взять (1 ур. — 30 оп., 2 ур. — 45, 3 ур. — 67).

const QUESTS := {
	"kirk_first_card": {
		"name": "Первая карта", "giver": "kirk", "turn_in": "kirk", "level": 1, "prev": "",
		"desc": "Учитель Кирк советует начать с чистой карты существа. Купите у него любую: пантеры, черепахи или фазана.",
		"offer": "Каждый укротитель начинает с чистой карты. Она как пустая лодка — ждёт, кто в неё сядет. Купи у меня карту существа: пантеры, черепахи или фазана. Выбирай по сердцу, а не по цене.",
		"progress": "Карты лежат прямо здесь, на прилавке. Загляни в «Торговлю» — не прогадаешь.",
		"done": "Хороший выбор! Береги её от сырости и не клади рядом с сыром — уж поверь моему опыту.",
		"goals": [
			{"type": "buy", "items": ["card_panther", "card_turtle", "card_pheasant"], "npc": "kirk", "n": 1,
				"counts_existing": true, "text": "Купить карту существа у Учителя Кирка"},
		],
		"rewards": {"xp": 35, "gold": 10},
	},
	"kirk_soul": {
		"name": "Душа в карте", "giver": "kirk", "turn_in": "kirk", "level": 2, "prev": "kirk_first_card",
		"desc": "Поймайте душу зверя в карту существа: примените «Приручить» к зверю, чья карта лежит у вас в сумке, и победите его. Фазаны водятся в Светлой роще.",
		"offer": "Карта есть — теперь нужен зверь. Найди того, чья карта у тебя, коснись его «Приручить» и победи в честном бою. Если душа признает тебя, она уснёт в карте. Фазаны в Светлой роще посговорчивее прочих.",
		"progress": "Не вышло с первого раза? Бывает со всеми. Зеркальная карта убережёт настоящую от поломки.",
		"done": "Слышишь, карта чуть тёплая? Это душа. Держи зеркальную карту — пригодится, когда удача отвернётся.",
		"goals": [
			{"type": "tame", "target": "", "n": 1, "counts_existing": true, "text": "Поймать душу зверя в карту"},
		],
		"rewards": {"xp": 60, "gold": 20, "items": {"mirror_card": 1}},
	},
	"kirk_new_friend": {
		"name": "Новый друг", "giver": "kirk", "turn_in": "kirk", "level": 2, "prev": "kirk_soul",
		"desc": "Сформируйте существо из карты с душой (сумка или окно «Питомцы» — «Сформировать») и призовите его.",
		"offer": "Душа в карте — ещё не друг. Сформируй существо: открой сумку, коснись карты с душой и нажми «Сформировать». А потом позови его к себе — пусть увидит мир твоими глазами.",
		"progress": "Карта с душой — в сумке. «Сформировать», а потом «Призвать» в окне «Питомцы». Он уже ждёт.",
		"done": "Ну здравствуй, малыш! Смотри, как он на тебя глядит. Вот тебе зелья: первые бои всегда синяками кончаются.",
		"goals": [
			{"type": "form", "target": "", "n": 1, "counts_existing": true, "text": "Сформировать существо из карты"},
			{"type": "summon", "target": "", "n": 1, "counts_existing": true, "text": "Призвать питомца"},
		],
		"rewards": {"xp": 70, "items": {"hp_potion": 3}, "jp": 5},
	},
	"kirk_bond_trial": {
		"name": "Испытание связи", "giver": "kirk", "turn_in": "kirk", "level": 3, "prev": "kirk_new_friend",
		"desc": "Победите 5 зверей, пока рядом призванный питомец: связь укротителя и зверя крепнет в деле.",
		"offer": "Связь крепнет в деле. Сходи с питомцем на охоту и одолейте вместе пятерых зверей. Пусть он будет рядом, когда ты бьёшься, — так вы научитесь понимать друг друга без слов.",
		"progress": "Зови питомца — и в бой. Если он падёт, свиток воскрешения вернёт его.",
		"done": "Вот теперь вижу — вы команда. Держи свиток воскрешения: надеюсь, не понадобится, но укротитель без свитка — что рыбак без сети.",
		"goals": [
			{"type": "pet_kill", "target": "", "n": 5, "text": "Победить зверей вместе с питомцем"},
		],
		"rewards": {"xp": 100, "gold": 40, "items": {"revive_scroll": 1}},
	},
	"sage_first_job": {
		"name": "Первая профессия", "giver": "sage", "turn_in": "sage", "level": 10, "prev": "",
		"wanderer_only": true, "job_choice": true,
		"desc": "Мудрец Альдерик готов помочь выбрать профессию. Сначала поговорите со старостой своей деревни — он расскажет, чем живёт ваш народ, — и докажите силу: победите пятерых зверей 8 уровня и выше. Потом вернитесь к мудрецу и выберите путь.",
		"offer": "Десять зим на острове — и ты всё ещё бродяга? Пора выбрать путь. Но путь выбирают не наугад: сходи к старосте своей деревни, послушай, чем живёт твой народ. А потом покажи, что рука не дрогнет: одолей пятерых зверей посильнее — восьмого уровня, не меньше.",
		"progress": "Староста ждёт тебя в деревне, а сильные звери — у скал, реки и на восточных равнинах. Не торопись: выбор профессии делают один раз.",
		"done": "Хорошо. Ты сделал выбор, и путь сам начнёт учить тебя. Заглядывай в окно героя: древо умений теперь открыто.",
		"goals": [
			{"type": "talk", "npc": "@elder", "n": 1, "text": "Поговорить со старостой своей деревни"},
			{"type": "kill", "target": "", "min_level": 8, "n": 5, "text": "Победить зверей 8 уровня и выше"},
		],
		"rewards": {"xp": 600, "gold": 100},
	},
	"sage_town_tour": {
		"name": "Знакомство с городом", "giver": "sage", "turn_in": "sage", "level": 1, "prev": "",
		"desc": "Мудрец Альдерик советует познакомиться с жителями площади: поговорите с Кузнецом Гуннаром (у тренировочной площадки) и Кладовщиком Тобином (у колодца), потом вернитесь к мудрецу.",
		"offer": "Город начинается с людей, а не со стен. Загляни к Гуннару в кузню и к Тобину — он стережёт склад. Поговори с обоими: однажды их помощь понадобится, и лучше, чтобы они помнили твоё лицо.",
		"progress": "Гуннар — у тренировочной площадки, его молот слышно издалека. Тобин — у колодца, с гроссбухом под мышкой.",
		"done": "Вот и славно: теперь ты не чужой на этой площади. Возьми немного золота — знания ценнее монет, но и монеты не помешают.",
		"goals": [
			{"type": "talk", "npc": "smith", "n": 1},
			{"type": "talk", "npc": "storekeeper", "n": 1},
		],
		"rewards": {"xp": 30, "gold": 15},
	},
}

## Староста деревни расы героя (цель "talk" с npc "@elder").
const ELDERS := {"human": "elder_human", "light_elf": "elder_light", "dark_elf": "elder_dark"}
## Цели, у которых прогресс — текущее состояние (пересчитывается), а не счётчик событий.
const STATE_GOALS := ["collect", "level"]
## Все виды целей.
const GOAL_TYPES := ["kill", "tame", "form", "summon", "pet_kill", "buy", "collect", "level", "talk"]

## Дополнительные задания (тесты, будущие события): id → задание в том же формате, что QUESTS.
static var extra: Dictionary = {}


static func get_quest(id: String) -> Dictionary:
	if QUESTS.has(id):
		return QUESTS[id]
	return extra.get(id, {})


static func has_quest(id: String) -> bool:
	return QUESTS.has(id) or extra.has(id)


## Все id заданий по порядку (сначала QUESTS, потом extra).
static func all_ids() -> Array:
	var res: Array = QUESTS.keys()
	for k in extra:
		if not res.has(k):
			res.append(k)
	return res


static func quest_name(id: String) -> String:
	return String(get_quest(id).get("name", id))


static func giver(id: String) -> String:
	return String(get_quest(id).get("giver", ""))


static func turn_in(id: String) -> String:
	var q := get_quest(id)
	return String(q.get("turn_in", q.get("giver", "")))


static func goals(id: String) -> Array:
	return get_quest(id).get("goals", [])


static func rewards(id: String) -> Dictionary:
	return get_quest(id).get("rewards", {})


## Предметы награды {id: количество}.
static func reward_items(id: String) -> Dictionary:
	return rewards(id).get("items", {})


static func is_state_goal(g: Dictionary) -> bool:
	return STATE_GOALS.has(String(g.get("type", "")))


## С кем поговорить для цели "talk": "@elder" — староста деревни расы героя.
static func goal_npc(g: Dictionary) -> String:
	var npc := String(g.get("npc", ""))
	if npc == "@elder":
		return String(ELDERS.get(Game.race_id, "elder_human"))
	return npc


## Сколько нужно для цели (у "level" — уровень).
static func goal_need(g: Dictionary) -> int:
	return maxi(1, int(g.get("n", 1)))


## Подпись цели: своя (text) или по виду цели.
static func goal_text(g: Dictionary) -> String:
	if g.has("text"):
		return String(g["text"])
	var target := String(g.get("target", ""))
	var who := String(MobData.get_type(target)["name"]) if target != "" and MobData.TYPES.has(target) else ""
	var items: Array = g.get("items", [])
	var names: Array = []
	for it in items:
		names.append(ItemData.item_name(String(it)))
	var what := " / ".join(PackedStringArray(names))
	match String(g.get("type", "")):
		"kill":
			return "Победить зверей" + (": " + who if who != "" else "")
		"tame":
			return "Поймать душу в карту" + (": " + who if who != "" else "")
		"form":
			return "Сформировать существо" + (": " + who if who != "" else "")
		"summon":
			return "Призвать питомца" + (": " + who if who != "" else "")
		"pet_kill":
			return "Победить зверей вместе с питомцем" + (": " + who if who != "" else "")
		"buy":
			var npc := String(g.get("npc", ""))
			return "Купить: " + what + (" у " + NpcData.name_gen(npc) if npc != "" else "")
		"collect":
			return "Собрать: " + what
		"level":
			return "Достичь %d уровня" % goal_need(g)
		"talk":
			return "Поговорить: " + NpcData.npc_name(goal_npc(g))
	return String(g.get("type", "?"))


## Награда одной строкой: «15 оп., 10 зол., Зеркальная карта ×1, 5 JP».
static func reward_text(id: String) -> String:
	var r := rewards(id)
	var parts: Array = []
	if int(r.get("xp", 0)) > 0:
		parts.append("%d оп." % int(r["xp"]))
	if int(r.get("gold", 0)) > 0:
		parts.append("%d зол." % int(r["gold"]))
	var items: Dictionary = r.get("items", {})
	for k in items:
		parts.append("%s ×%d" % [ItemData.item_name(String(k)), int(items[k])])
	if int(r.get("jp", 0)) > 0:
		parts.append("%d JP" % int(r["jp"]))
	return ", ".join(PackedStringArray(parts))
