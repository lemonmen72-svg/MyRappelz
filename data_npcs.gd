class_name NpcData
extends RefCounted
## Жители-NPC: имя над головой, титул, формы имени для сообщений, реплики приветствия, ассортимент торговли,
## где стоят и есть ли с ними разговор (кнопка «Говорить» в HUD, окно диалога — Npcs).
## Внешность — CharacterModel.npc_spec(id). Задания NPC — QuestData (поля giver / turn_in).
##
## Поля: name — имя над головой и в окнах; title — подпись под именем в диалоге; gen / dat — родительный
## и дательный падеж («у Учителя Кирка», «вернитесь к Учителю Кирку»); where — где искать («в центре города»);
## shop — товары (id предметов ItemData; оружие показывается только подходящее классу героя);
## shop_title — заголовок окна торговли; dialog — с NPC можно говорить (кнопка «Говорить»);
## greet — реплики приветствия по положению дел с заданиями (Npcs.greeting): "ready" — есть что сдать,
## "offer" — есть новое задание, "busy" — задание взято, "wait" — следующее откроется с уровнем,
## "idle" — заданий нет; mark_y — высота значка задания («!», «?») над землёй, м.

const NPCS := {
	"merchant": {
		"name": "Торговец", "gen": "торговца", "dat": "торговцу", "where": "в центре города",
		"title": "Странствующий торговец", "shop_title": "Торговец", "dialog": false, "mark_y": 3.15,
		"shop": ["hp_potion", "revive_scroll", "daggers_steel", "dual_swords_steel", "crossbow_heavy"],
		"greet": {
			"idle": "Зелья, свитки, клинки! Заходи, пока не разобрали.",
		},
	},
	"kirk": {
		"name": "Учитель Кирк", "gen": "Учителя Кирка", "dat": "Учителю Кирку", "where": "в центре города",
		"title": "Наставник укротителей", "shop_title": "Лавка Учителя Кирка", "dialog": true, "mark_y": 3.2,
		"shop": ["card_panther", "card_pheasant", "card_turtle", "mirror_card"],
		"greet": {
			"ready": "Ну-ка, ну-ка… По глазам вижу — справился! Рассказывай, не томи старика.",
			"offer": "А, вот и ты! Подойди поближе: у старого Кирка как раз найдётся для тебя дело.",
			"busy": "Не спеши, дружок. Зверь торопливых не любит. Как продвигается наше дело?",
			"wait": "Ты молодец, но погоди немного. Подрасти в деле — и я расскажу тебе больше.",
			"idle": "Я учу укротителей на этом острове уже сорок вёсен. Звери чувствуют доброе сердце, а карты помогают им найти к нему дорогу. Заглядывай — карты у меня всегда свежие.",
		},
	},
}


static func npc(id: String) -> Dictionary:
	return NPCS.get(id, {})


static func has_npc(id: String) -> bool:
	return NPCS.has(id)


## Имя NPC («Учитель Кирк»); неизвестный — его id.
static func npc_name(id: String) -> String:
	return String(npc(id).get("name", id))


## Родительный падеж: «у Учителя Кирка».
static func name_gen(id: String) -> String:
	return String(npc(id).get("gen", npc_name(id)))


## Дательный падеж: «вернитесь к Учителю Кирку».
static func name_dat(id: String) -> String:
	return String(npc(id).get("dat", npc_name(id)))


## Товары NPC (id предметов), [] — не торгует.
static func shop(id: String) -> Array:
	return npc(id).get("shop", [])


static func is_trader(id: String) -> bool:
	return not shop(id).is_empty()


## Можно ли с NPC говорить (кнопка «Говорить», окно диалога).
static func has_dialog(id: String) -> bool:
	return bool(npc(id).get("dialog", false))


## Заголовок окна торговли.
static func shop_title(id: String) -> String:
	return String(npc(id).get("shop_title", npc_name(id)))


## Кто продаёт предмет: id NPC по порядку NPCS.
static func sellers_of(item_id: String) -> Array:
	var res: Array = []
	for k in NPCS:
		if shop(String(k)).has(item_id):
			res.append(String(k))
	return res


## Реплика приветствия: kind — "ready" | "offer" | "busy" | "wait" | "idle" (нет своей — "idle").
static func greet(id: String, kind: String) -> String:
	var g: Dictionary = npc(id).get("greet", {})
	return String(g.get(kind, g.get("idle", "")))
