class_name BotScenarioGame
extends BotScenario
## Игровые режимы тест-бота (этап 4): «Быстрый (5 мин)» — короткий проход по всем разделам (BotSection, quick:
## три профессии, два вида питомцев, часть мест и окон), «Полный (10 мин)» — все разделы полностью, «По разделам» —
## разделы, выбранные на вкладке «Тест-бот» (chosen(), выбор хранится в CHOICE_PATH), полностью. Разделы живут
## в sections (их методы — шаги очереди бота: Callable держит объект только по id, поэтому ссылки нужны здесь).
## Отчёт: разделы — блок «Разделы» BotReport (время, проверки, ошибки, снимки, ошибки лога по разделам).

## Выбор разделов режима «По разделам» (ConfigFile [bot] sections; тест подменяет путь).
static var choice_path := "user://bot_sections.cfg"

var sections: Array[BotSection] = []


func id() -> String:
	return "game"


func title() -> String:
	return "Игровые сценарии"


func hero() -> Dictionary:
	return {"race": "human", "job": "warrior", "gender": "m", "level": 30}


## Короткий проход (режим «Быстрый»).
func is_quick() -> bool:
	return false


## id разделов этого режима по порядку.
func section_ids() -> Array:
	return BotSection.ids()


func build(b: TestBot) -> void:
	sections.clear()
	for v in section_ids():
		var s := BotSection.create(String(v))
		if s == null:
			b.check(false, "раздел «%s» есть" % String(v))
			continue
		sections.append(s)
		s.build(b, is_quick())


## Выбранные разделы «По разделам» (по порядку SECTIONS; нет выбора — все).
static func chosen() -> Array:
	var cf := ConfigFile.new()
	var res: Array = []
	if cf.load(choice_path) == OK:
		var v: Variant = cf.get_value("bot", "sections", [])
		if v is Array:
			for id_v in BotSection.ids():
				if (v as Array).has(String(id_v)):
					res.append(String(id_v))
			return res
	return BotSection.ids()


static func set_chosen(list: Array) -> void:
	var cf := ConfigFile.new()
	var keep: Array = []
	for id_v in BotSection.ids():
		if list.has(String(id_v)):
			keep.append(String(id_v))
	cf.set_value("bot", "sections", keep)
	cf.save(choice_path)


## Переключить раздел в выборе «По разделам».
static func toggle_chosen(sec_id: String) -> void:
	var cur := chosen()
	if cur.has(sec_id):
		cur.erase(sec_id)
	else:
		cur.append(sec_id)
	set_chosen(cur)


## Оценка времени разделов list (полный проход), с.
static func estimate(list: Array, is_quick: bool = false) -> float:
	var t := 0.0
	for v in list:
		t += BotSection.estimate(String(v), is_quick)
	return t
