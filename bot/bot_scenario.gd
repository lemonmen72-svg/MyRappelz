class_name BotScenario
extends RefCounted
## Сценарий тест-бота (TestBot): какой герой нужен и какие шаги сделать. Наследник переопределяет id(), title(),
## hero(), limit() и build(bot); build ставит шаги в очередь бота (они идут по порядку, каждый — со своим временем):
##   bot.do("что делаю", Callable)                  — действие один раз (перенос, уровень, профессия, звери…);
##   bot.wait(сек)                                   — подождать (игра идёт);
##   bot.wait_until("чего жду", Callable → bool, сек) — ждать условия (не дождался — ошибка проверки в отчёте);
##   bot.measure(сцена, настройка, сек, {preset, option: [ключ, значение], shot, base, tick: Callable(dt)})
##                                                   — прогрев bot.warmup с, затем замер (метрики, температура
##                                                     до/после, снимок) — строка таблицы отчёта;
##   bot.tick(Callable(dt))                          — вызывать каждый кадр до следующего шага bot.tick(Callable());
##                                                     из действия шага (не очередью) — bot.set_tick(Callable(dt)).
## Внутри действий — API бота (TestBot, раздел «API для сценариев»): teleport, set_camera, reset_camera, set_preset,
## set_option, spawn, clear_spawned, set_job, set_level, set_look, learn_all, add_pet, player(), check(cond, текст),
## note(текст), shot(имя), main. Бот сам следит за температурой (паузы на остывание, остановка) и за лимитом времени.
## Новый режим: файл bot/bot_scenario_<id>.gd (extends BotScenario) и строка в MODES с "ready": true.
## Один сценарий — несколько режимов: в mode_key — id строки MODES, по которой он создан (create).
## Сценарий без мира тестового героя (needs_world false — «Автотесты») сам ставит и убирает сцены (owns_scene):
## бот не следит за главной сценой, в конце создаёт её заново; on_finish — уборка при любом конце (стоп, перегрев).
## Игровые режимы «Быстрый», «Полный», «По разделам» — BotScenarioGame (bot/bot_scenario_game.gd) из разделов
## BotSection (bot/bot_section.gd, bot/section_<id>.gd); minutes — лимит активного времени (у «По разделам» — по
## оценке выбранных разделов, BotScenarioGame.estimate).

## Режимы вкладки «Тест-бот»: id, название, готов ли, сценарий, лимит активного времени (мин).
const MODES := [
	{"id": "perf", "name": "Производительность", "ready": true, "script": "res://bot/bot_scenario_perf.gd", "minutes": 12},
	{"id": "autotests", "name": "Автотесты на телефоне (все)", "ready": true,
		"script": "res://bot/bot_scenario_autotests.gd", "minutes": 75},
	{"id": "autotests_quick", "name": "Автотесты: быстрые", "ready": true,
		"script": "res://bot/bot_scenario_autotests.gd", "minutes": 15},
	{"id": "quick", "name": "Быстрый (5 мин)", "ready": true, "script": "res://bot/bot_scenario_quick.gd", "minutes": 6},
	{"id": "full", "name": "Полный (10 мин)", "ready": true, "script": "res://bot/bot_scenario_full.gd", "minutes": 12},
	{"id": "sections", "name": "По разделам", "ready": true, "script": "res://bot/bot_scenario_sections.gd", "minutes": 10},
	{"id": "cardinal", "name": "Кардинал: первый срез", "ready": true, "script": "res://bot/bot_scenario_cardinal.gd",
		"minutes": 12},
	{"id": "cardinal_det", "name": "Кардинал: детерминизм", "ready": true, "script": "res://bot/bot_scenario_cardinal.gd",
		"minutes": 6},
	{"id": "cardinal_story", "name": "Кардинал: прохождение острова", "ready": true,
		"script": "res://bot/bot_scenario_cardinal_story.gd", "minutes": 40},
]


## Сценарий режима mode_id (null — режима нет или он «скоро»).
static func create(mode_id: String) -> BotScenario:
	var m := mode(mode_id)
	if m.is_empty() or not bool(m.get("ready", false)):
		return null
	var path := String(m.get("script", ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var scr := load(path) as GDScript
	if scr == null:
		return null
	var sc := scr.new() as BotScenario
	if sc != null:
		sc.mode_key = mode_id
	return sc


static func mode(mode_id: String) -> Dictionary:
	for e in MODES:
		var d: Dictionary = e
		if String(d["id"]) == mode_id:
			return d
	return {}


static func mode_name(mode_id: String) -> String:
	var m := mode(mode_id)
	return String(m.get("name", mode_id)) if not m.is_empty() else mode_id


## Режим из MODES, по которому создан сценарий ("" — создан напрямую, как в тестах).
var mode_key := ""


func id() -> String:
	return "custom"


func title() -> String:
	return "Сценарий"


## Тестовый герой: race, job (ClassData), gender ("f"/"m"), level.
func hero() -> Dictionary:
	return {"race": "human", "job": ClassData.WANDERER, "gender": "f", "level": 1}


## Лимит активного времени сценария (без пауз на остывание), с.
func limit() -> float:
	var m := mode(id())
	return float(m.get("minutes", 12)) * 60.0


## Поставить шаги в очередь бота.
func build(_bot: TestBot) -> void:
	pass


## Строки своего раздела отчёта (этап 4: итоги проверок по разделам); [] — нет.
func report_lines(_bot: TestBot) -> PackedStringArray:
	return PackedStringArray()


## Строка итога в сводке отчёта (под «Итог»); "" — нет.
func summary(_bot: TestBot) -> String:
	return ""


## Нужен ли мир тестового героя (false — бот не грузит его, главная сцена убирается до build).
func needs_world() -> bool:
	return true


## Сценарий сам ставит и убирает сцены (бот не проверяет, что главная сцена на месте).
func owns_scene() -> bool:
	return not needs_world()


## Конец режима при любом исходе (готово, стоп, перегрев, лимит) — до отчёта и возврата игрока.
func on_finish(_bot: TestBot) -> void:
	pass
