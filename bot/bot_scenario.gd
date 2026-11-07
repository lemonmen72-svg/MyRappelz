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
## Долгий режим, который продолжается после прерывания (resumable true: «Кардинал: профили игроков», «Автотесты»):
## после каждой законченной части (прогон, тест) — bot.save_checkpoint(данные, прогресс); «Продолжить» во вкладке
## «Тест-бот» создаёт сценарий заново и зовёт resume(данные) до limit() и build — готовое не повторяется.
## Игровые режимы «Быстрый», «Полный», «По разделам» — BotScenarioGame (bot/bot_scenario_game.gd) из разделов
## BotSection (bot/bot_section.gd, bot/section_<id>.gd); minutes — лимит активного времени (у «По разделам» — по
## оценке выбранных разделов, BotScenarioGame.estimate).

## Группы режимов на вкладке «Тест-бот» (фаза 6 — порядок в тестах): [id, название, что это за режимы].
const MODE_GROUPS := [
	["game", "Бот играет и проверяет", "Бот сам играет тестовым героем по разделам игры и проверяет, что всё работает (бой, питомцы, торговля, задания, мир, интерфейс, подземелье)."],
	["perf", "Производительность", "Кадры в секунду, нагрузка и нагрев телефона на сценах и пресетах графики."],
	["autotests", "Автотесты на телефоне", "Те же проверки кода, что идут в CI на каждый пуш, — прямо на телефоне. Что какой тест проверяет — по группам ниже и в docs/TESTS.md."],
	["cardinal", "Кардинал: как играют разные игроки", "Бот проходит игру как игрок и ищет тупики, застревания, долгий гринд и странности баланса."],
]

## Режимы вкладки «Тест-бот»: id, группа (MODE_GROUPS), название, готов ли, сценарий, лимит активного времени (мин),
## что проверяет (about) и когда запускать (when) — показываются во вкладке и в docs/TESTS.md.
## Литерал без выражений: tools/tests_catalog.py читает его для docs/TESTS.md.
const MODES := [
	{"id": "quick", "group": "game", "name": "Быстрый (5 мин)", "ready": true, "script": "res://bot/bot_scenario_quick.gd",
		"minutes": 6, "about": "12 разделов коротко: бой 5 профессий, питомцы, приручение, торговля, склад, задания, задания жителей, экипировка, торба и пояс, мир, интерфейс, подземелье.",
		"when": "После каждой новой сборки."},
	{"id": "full", "group": "game", "name": "Полный (10 мин)", "ready": true, "script": "res://bot/bot_scenario_full.gd",
		"minutes": 12, "about": "Те же 12 разделов подробно: все 9 профессий, все виды питомцев, все дороги острова, все залы подземелья.",
		"when": "Перед выпуском или если быстрый нашёл ошибку."},
	{"id": "sections", "group": "game", "name": "По разделам", "ready": true, "script": "res://bot/bot_scenario_sections.gd",
		"minutes": 10, "about": "Только выбранные разделы, подробно.",
		"when": "Проверить раздел после исправления."},
	{"id": "perf", "group": "perf", "name": "Производительность", "ready": true, "script": "res://bot/bot_scenario_perf.gd",
		"minutes": 15, "about": "Кадры в секунду, время кадра, вызовы, треугольники, нагрев: 6 сцен (город, поле, толпа, бой, даль, подземелье) × 4 пресета, тяжёлые настройки по одной, ночь и гроза.",
		"when": "После изменений графики и на новом телефоне."},
	{"id": "autotests_quick", "group": "autotests", "name": "Автотесты: быстрые", "ready": true,
		"script": "res://bot/bot_scenario_autotests.gd", "minutes": 15,
		"about": "Проверки логики: бой, предметы, торговля, задания, питомцы, звери (флаг «быстрые» в каталоге).",
		"when": "Убедиться, что на телефоне игра считает так же, как в CI."},
	{"id": "autotests_groups", "group": "autotests", "name": "Автотесты: по группам", "ready": true,
		"script": "res://bot/bot_scenario_autotests.gd", "minutes": 75,
		"about": "Проверки выбранных групп каталога (бой и умения, предметы, подземелье, модели …).",
		"when": "Проверить одну область игры."},
	{"id": "autotests", "group": "autotests", "name": "Автотесты на телефоне (все)", "ready": true,
		"script": "res://bot/bot_scenario_autotests.gd", "minutes": 75,
		"about": "Все проверки кода, которые можно запустить на телефоне (кроме «только CI»).",
		"when": "Редко: долгий полный прогон кода на телефоне."},
	{"id": "cardinal", "group": "cardinal", "name": "Кардинал: первый срез", "ready": true,
		"script": "res://bot/bot_scenario_cardinal.gd", "minutes": 12,
		"about": "Бродяга 1 ур. фармит у деревни как игрок; опыт за каждое убийство сверяется с формулой, добыча и золото — со статистикой.",
		"when": "После изменений опыта, боя, добычи."},
	{"id": "cardinal_det", "group": "cardinal", "name": "Кардинал: детерминизм", "ready": true,
		"script": "res://bot/bot_scenario_cardinal.gd", "minutes": 6,
		"about": "Два одинаковых ускоренных прогона должны совпасть убийство в убийство — ускорение ×8 честное.",
		"when": "После изменений бота или ускорения."},
	{"id": "cardinal_story", "group": "cardinal", "name": "Кардинал: прохождение острова", "ready": true,
		"script": "res://bot/bot_scenario_cardinal_story.gd", "minutes": 40,
		"about": "Свежий Бродяга проходит все задания острова с крафтом, питомцами и поясом ускоренно; по каждому заданию — взято, сдано, застряло, награды.",
		"when": "После изменений заданий и наград."},
	{"id": "cardinal_profiles", "group": "cardinal", "name": "Кардинал: профили игроков", "ready": true,
		"script": "res://bot/bot_scenario_cardinal_profiles.gd", "minutes": 60,
		"about": "Честное прохождение отрезка острова 5 типами игроков (новичок, обычный, ветеран, фармер, экспериментатор): время, смерти, застревания, гринд, золото, подозрения.",
		"when": "Оценить баланс и удобство."},
]


## Режимы тестов (tests/test_bot_lifecycle.gd): id → Callable, создающий сценарий, — как строки MODES (имя «Тест: id»),
## чтобы «Продолжить» во вкладке шёл настоящим путём. В игре пусто.
static var test_modes: Dictionary = {}


## Сценарий режима mode_id (null — режима нет или он «скоро»).
static func create(mode_id: String) -> BotScenario:
	if test_modes.has(mode_id):
		var ts: BotScenario = (test_modes[mode_id] as Callable).call()
		if ts != null:
			ts.mode_key = mode_id
		return ts
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
	if test_modes.has(mode_id):
		return {"id": mode_id, "name": "Тест: " + mode_id, "ready": true, "minutes": 15}
	for e in MODES:
		var d: Dictionary = e
		if String(d["id"]) == mode_id:
			return d
	return {}


static func mode_name(mode_id: String) -> String:
	var m := mode(mode_id)
	return String(m.get("name", mode_id)) if not m.is_empty() else mode_id


## Название группы режимов.
static func group_name(group_id: String) -> String:
	for g in MODE_GROUPS:
		if String(g[0]) == group_id:
			return String(g[1])
	return group_id


## Режимы группы по порядку MODES.
static func modes_in(group_id: String) -> Array:
	var res: Array = []
	for e in MODES:
		if String((e as Dictionary).get("group", "")) == group_id:
			res.append(e)
	return res


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
## Телефон не остывает в паузе — снизить нагрузку сценария (щадящий режим TestBot). Вернуть — что сделано, для журнала.
func on_hot(_bot: TestBot) -> String:
	return ""


## Данные сценария для сводки запуска report.json (BotHistory.summary: сравнение запусков и предложения):
## «Автотесты» — {"autotests": [...]}, «Кардинал: профили игроков» — {"suspicions": [...]} и т. п.
func report_data(_bot: TestBot) -> Dictionary:
	return {}


func on_finish(_bot: TestBot) -> void:
	pass


## Продолжается ли режим с контрольной точки (TestBot.save_checkpoint после каждой законченной части).
func resumable() -> bool:
	return false


## Продолжение: data — данные контрольной точки (что уже готово); зовётся до limit() и build. "" — можно, иначе
## причина (точка не подходит — запуск не начинается).
func resume(_data: Dictionary) -> String:
	return "режим «%s» не продолжается с контрольной точки" % title()
