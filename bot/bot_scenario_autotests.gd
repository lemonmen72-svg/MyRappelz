extends BotScenario
## Режим «Автотесты на телефоне» тест-бота (этап 4, просьба Максима): наши автотесты tests/smoke_test.gd и
## tests/test_*.gd (папка tests/ лежит в APK — скрипты, ≈ 1.3 МБ текста) по одному в той же игре, итог — раздел
## «Автотесты» отчёта бота (.txt и .zip в «Загрузки/DarkPact_test», как у «Производительности»).
## Режимы MODES: "autotests" — все, "autotests_quick" — быстрые (QUICK: логика боя, предметов, заданий, питомцев).
##
## Как идёт: мир тестового героя не грузится (needs_world false) — бот сохраняет героя игрока, переключается на своё
## хранилище и убирает главную сцену; настройки игрока (settings.cfg) убираются на время (TestBot.backup_settings —
## копия в папке отчётов; упала игра — вернутся при следующем запуске, TestBot.recover_after_crash), тесты видят
## настройки по умолчанию, как в CI. Каждый тест — узел у корня дерева, как tests/runner.gd в CI: test_base.gd
## входит своим аккаунтом в хранилище ACCOUNTS (не test_accounts CI и не хранилище игрока), ставит свою главную
## сцену; конец теста — device_hook (вместо выхода из игры). Затем всё, что тест добавил к корню дерева, удаляется,
## состояние классов (статические поля, которые тесты меняют: AdminPanel, Quality, Assets, подмены моделей и т. п.)
## возвращается к умолчаниям CI (reset_env), и — следующий тест. Таймаут теста — TIMEOUT с активного времени
## (паузы бота на остывание не в счёт: дерево на паузе — тест стоит). Ошибки Godot за время теста — из файла лога
## (user://logs/godot.log с того места, где тест начался): SCRIPT ERROR и прочие ошибки GDScript — тест не прошёл
## (как в CI, smoke_test.sh), остальные ERROR / WARNING — в отчёт.
## В конце (и при остановке — on_finish): аккаунты тестов стёрты, настройки игрока и файлы рендерера — как до
## запуска, бот возвращает героя игрока (TestBot._return_home) и создаёт главную сцену заново.
##
## Чего нет на телефоне: --fixed-fps 60 (кадр — настоящее время, экран рисуется) и headless. Тесты, которым нужно
## то, чего в APK или на телефоне нет, — CI_ONLY («пропущен (только CI)» с причиной); тесты моделей из пакета
## ресурсов без всех частей пакета — NEED_PACK. Тест, на котором в прошлый раз игра закрылась (шаг в метке RUNNING),
## пропускается один раз. Новый тест в tests/ попадает в режим «все» сам (список — DirAccess по res://tests/).

const TESTS_DIR := "res://tests/"
## Хранилище аккаунтов тестов на телефоне.
const ACCOUNTS := "user://bot_test_accounts/"
## Таймаут одного теста (с активного времени; test_base сам сдаётся после MAX_FRAMES кадров).
const TIMEOUT := 300.0
## Кадров между тестами: удалённые узлы освобождаются.
const SETTLE_FRAMES := 3
## Строк ошибок Godot на тест в отчёте.
const LOG_ERRORS := 12
## Ошибки GDScript (как в CI, .github/scripts/smoke_test.sh): тест не прошёл.
const SCRIPT_ERRORS := ["SCRIPT ERROR", "Parse Error", "Compile Error", "Failed to load script", "Invalid call",
	"Invalid access", "Invalid assignment"]
## Только CI: причина.
const CI_ONLY := {
	"test_bot": "сам запускает тест-бота, а второй бот не запускается, пока идёт этот",
	"test_bot_game": "сам запускает тест-бота (режим «Быстрый» — его и так можно запустить на вкладке), а второй бот не запускается",
	"test_asset_pack": "читает export_presets.cfg (его нет в APK) и подменяет состояние пакета ресурсов — на телефоне это настоящий кэш загрузок",
	"test_asset_fallback": "проверяет игру без пакета ресурсов (файлы частей не загружены) — на телефоне игра их уже загрузила",
	"test_renderer": "подставляет Android и пишет файлы рендерера — на телефоне это настоящие файлы запуска (страховка Vulkan)",
	"test_branding": "читает export_presets.cfg и папку данных проекта сборки — в APK их нет",
	"test_texture_quality": "читает .import и заголовки PNG исходников — в APK их нет (только сжатые текстуры)",
	"test_movement_smooth": "мерит дрожь движения при ровно 60 кадрах/с (CI: --fixed-fps 60 без экрана)",
}
## Проверяют модели и текстуры из пакета ресурсов: без всех частей — пропуск.
const NEED_PACK := ["test_hero_models", "test_npc_models", "test_props", "test_handheld", "test_pet_stages",
	"test_two_hand", "test_textures"]
## Быстрые: логика без тяжёлых сцен (режим "autotests_quick").
const QUICK := ["smoke_test", "test_accounts", "test_combat", "test_combat_melee", "test_combat_magic", "test_economy",
	"test_inventory", "test_loot", "test_potions", "test_equipment", "test_enchant", "test_quests", "test_jobs",
	"test_taming_cards", "test_pet_skills", "test_monster_stats", "test_balance_start", "test_mob_aggro"]
const STATUS_TEXT := {"ok": "прошёл", "fail": "НЕ ПРОШЁЛ", "timeout": "ТАЙМАУТ", "error": "ОШИБКА", "skip": "пропущен",
	"stopped": "прерван"}

var bot: TestBot
## Свой список тестов (тест раннера); пусто — по режиму.
var only: PackedStringArray = PackedStringArray()
## Свои скрипты (тест раннера): имя → Script; иначе res://tests/<имя>.gd.
var scripts: Dictionary = {}
var timeout := TIMEOUT
## Свой таймаут теста (тест раннера): имя → с.
var timeouts: Dictionary = {}
## Итоги: {name, status, text, sec, frames, fps, errors: PackedStringArray, script_errors, other_errors, warnings}.
var results: Array[Dictionary] = []
var planned := 0

var _cur: Dictionary = {}
## "" — нет теста, "run", "settle", "next" (записан).
var _phase := ""
var _node: Node = null
var _before: Dictionary = {}
var _log_from := 0
var _settle := 0
var _t0 := 0.0
var _frames := 0
var _ended := false
var _end_ok := false
var _end_text := ""
var _crashed_on := ""
var _settings_moved := false
## Как было до тестов (вернуть в конце): статические поля и файлы рендерера.
var _saved: Dictionary = {}
var _renderer_files: Dictionary = {}


func id() -> String:
	return "autotests"


func title() -> String:
	return "Автотесты на телефоне" + (" (быстрые)" if mode_key == "autotests_quick" else "")


func limit() -> float:
	var m := mode(mode_key if mode_key != "" else id())
	return float(m.get("minutes", 75)) * 60.0


func needs_world() -> bool:
	return false


## Тесты по порядку: свой список, быстрые или все (smoke_test первым).
func test_names() -> PackedStringArray:
	if not only.is_empty():
		return only
	var all := list_tests()
	if mode_key != "autotests_quick":
		return all
	var out := PackedStringArray()
	for n in QUICK:
		if all.has(String(n)):
			out.append(String(n))
	return out


## Имена тестов в res://tests/ (в APK скрипты — .gdc и .gd.remap, в редакторе — .gd).
static func list_tests() -> PackedStringArray:
	var seen := {}
	for f in DirAccess.get_files_at(TESTS_DIR):
		var s := String(f).trim_suffix(".remap")
		var ext := s.get_extension()
		if ext != "gd" and ext != "gdc":
			continue
		var base := s.get_basename()
		if base == "smoke_test" or (base.begins_with("test_") and base != "test_base"):
			seen[base] = true
	var out := PackedStringArray()
	for k in seen:
		out.append(String(k))
	out.sort()
	var si := out.find("smoke_test")
	if si > 0:
		out.remove_at(si)
		out.insert(0, "smoke_test")
	return out


## Почему тест не запускать на этом телефоне ("" — запускать).
func skip_reason(n: String) -> String:
	if CI_ONLY.has(n):
		return "только CI: " + String(CI_ONLY[n])
	if NEED_PACK.has(n) and not (Assets.embedded() or Assets.available()):
		return "нет пакета ресурсов (загружены частей %d из %d) — проверяет модели из него" % [Assets.ready_count(),
			Assets.PACKS.size()]
	if n == _crashed_on:
		return "в прошлый запуск автотестов игра закрылась на этом тесте — пропущен один раз (см. «Прошлые завершения игры»)"
	return ""


func build(b: TestBot) -> void:
	bot = b
	var names := test_names()
	planned = names.size()
	var ib := b.interrupted_before
	if String(ib.get("mode", "")).begins_with("autotests") and String(ib.get("step", "")) != "":
		_crashed_on = String(ib["step"])
	b.do("Подготовка автотестов", _prepare.bind(names))
	for i in names.size():
		var n := String(names[i])
		# Свой таймаут теста — TIMEOUT; у шага бота — с запасом (если сценарий не справился)
		b.wait_until("Автотест %s (%d/%d)" % [n, i + 1, names.size()], _run_one.bind(n), timeout + 60.0)
	b.do("Конец автотестов", func() -> void: bot.note(summary(bot)))


func _prepare(names: PackedStringArray) -> void:
	bot.note("Автотесты: %d (%s)%s" % [names.size(), "быстрые" if mode_key == "autotests_quick" else "все",
		"; в прошлый раз игра закрылась на «%s»" % _crashed_on if _crashed_on != "" else ""])
	if names.is_empty():
		bot.check(false, "список автотестов пуст (папки res://tests/ нет в сборке?)")
	_saved = {
		"tab": AdminPanel.tab, "bot_mode": AdminPanel.bot_mode, "spawn_level": AdminPanel.spawn_level,
		"job": HeroSkills.job, "extra": QuestData.extra.duplicate(true), "plugin": Assets.plugin_override,
		"missing": Assets.force_missing, "packs_dir": Assets.packs_dir,
		"rg": [RendererGuard.override_path, RendererGuard.state_path, RendererGuard.log_path,
			RendererGuard.platform_override, RendererGuard.method_override, RendererGuard.gpu_override,
			RendererGuard.plugin_override],
	}
	for p in [RendererGuard.OVERRIDE_PATH, RendererGuard.STATE_PATH]:
		_renderer_files[p] = _file_state(String(p))
	# Настройки — по умолчанию, как в CI (у игрока они свои): settings.cfg — в копию на время тестов
	if bot.backup_settings():
		_settings_moved = true
		if FileAccess.file_exists(Quality.PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(Quality.PATH))
		bot.note("Настройки игрока убраны на время тестов (копия: %s)" % (bot.report_dir + TestBot.SETTINGS_BACKUP))
	else:
		bot.note("Копию настроек игрока записать не удалось — тесты идут с его настройками")


## Шаг одного теста (каждый кадр): true — тест закончен и записан.
func _run_one(n: String) -> bool:
	if String(_cur.get("name", "")) != n:
		if _phase == "run" or _phase == "settle":
			_abort("шаг бота закончился раньше теста")
		_start(n)
	match _phase:
		"run":
			_tick_run()
		"settle":
			_settle -= 1
			if _settle <= 0:
				_record()
	return _phase == "next"


func _start(n: String) -> void:
	_cur = {"name": n, "status": "", "text": "", "sec": 0.0, "frames": 0, "fps": 0.0, "errors": PackedStringArray(),
		"script_errors": 0, "other_errors": 0, "warnings": 0}
	_ended = false
	_node = null
	var why := skip_reason(n)
	if why != "":
		_cur["status"] = "skip"
		_cur["text"] = why
		_phase = "next"
		results.append(_cur)
		bot.note("Автотест %s — пропущен: %s" % [n, why])
		return
	reset_env()
	var tree := bot.get_tree()
	_before = {}
	for c in tree.root.get_children():
		_before[c.get_instance_id()] = true
	_log_from = _log_len()
	_t0 = bot.active_time
	_frames = 0
	bot.mark({"step": n})
	print("TestBot: автотест %s — старт" % n)
	var scr: GDScript = scripts.get(n, null) as GDScript
	if scr == null:
		var path := TESTS_DIR + n + ".gd"
		scr = load(path) as GDScript if ResourceLoader.exists(path) else null
	if scr == null:
		_cur["status"] = "error"
		_cur["text"] = "скрипт теста не загрузился"
		_end_run()
		return
	var node: Variant = scr.new()
	if not (node is Node) or not ("device_hook" in node):
		_cur["status"] = "error"
		_cur["text"] = "тест не наследует tests/test_base.gd"
		if node is Node:
			(node as Node).free()
		_end_run()
		return
	_node = node
	_node.name = "Autotest_" + n
	_node.set("accounts_dir", ACCOUNTS)
	_node.set("device_hook", _on_test_end)
	_phase = "run"
	tree.root.add_child(_node)


## Конец теста (test_base: ok_done / fail).
func _on_test_end(ok: bool, text: String) -> void:
	if _phase != "run" or _ended:
		return
	_ended = true
	_end_ok = ok
	_end_text = text


func _tick_run() -> void:
	_frames += 1
	var el := bot.active_time - _t0
	if _ended:
		_cur["status"] = "ok" if _end_ok else "fail"
		_cur["text"] = _end_text
		_end_run()
	elif not is_instance_valid(_node) or not _node.is_inside_tree():
		_cur["status"] = "error"
		_cur["text"] = "узел теста пропал из дерева"
		_end_run()
	elif el > float(timeouts.get(String(_cur["name"]), timeout)):
		_cur["status"] = "timeout"
		_cur["text"] = "не закончился за %s (шаг теста %s)" % [TestBot.clock(float(timeouts.get(String(_cur["name"]),
			timeout))), str(_node.get("step"))]
		_node.set("done", true)
		_end_run()


## Тест закончен: время, уборка узлов; запись — через SETTLE_FRAMES кадров (ошибки в логе, узлы освобождены).
func _end_run() -> void:
	var el := maxf(bot.active_time - _t0, 0.0)
	_cur["sec"] = el
	_cur["frames"] = _frames
	_cur["fps"] = float(_frames) / el if el > 0.05 else 0.0
	_cleanup_nodes()
	_phase = "settle"
	_settle = SETTLE_FRAMES


## Прервать идущий тест (остановка бота, шаг бота кончился).
func _abort(text: String) -> void:
	if _phase == "run":
		_cur["status"] = "stopped"
		_cur["text"] = text
		_end_run()
	_record()


## Убрать всё, что тест добавил к корню дерева (его узел, главные сцены, экраны).
func _cleanup_nodes() -> void:
	var tree := bot.get_tree()
	for c in tree.root.get_children():
		if c == bot or _before.has(c.get_instance_id()) or c.is_queued_for_deletion():
			continue
		c.process_mode = Node.PROCESS_MODE_DISABLED
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
		c.queue_free()
	_node = null


func _record() -> void:
	if _phase == "next" or _cur.is_empty():
		_phase = "next"
		return
	_collect_log()
	if String(_cur["status"]) == "ok" and int(_cur["script_errors"]) > 0:
		_cur["status"] = "fail"
		_cur["text"] = "ошибки GDScript в логе (%d) — как в CI, тест не прошёл" % int(_cur["script_errors"])
	results.append(_cur)
	reset_env()
	_phase = "next"
	var line := "Автотест %s — %s за %s" % [String(_cur["name"]), String(STATUS_TEXT.get(String(_cur["status"]), "?")),
		_sec(float(_cur["sec"]))]
	if String(_cur["text"]) != "":
		line += ": " + String(_cur["text"]).left(160)
	bot.note(line)
	bot.mark({"step": ""})


## Ошибки и предупреждения Godot в логе с начала теста.
func _collect_log() -> void:
	var lines := _log_since(_log_from)
	var errs := PackedStringArray()
	var se := 0
	var oe := 0
	var wn := 0
	for i in lines.size():
		var l := lines[i]
		var is_script := false
		for p in SCRIPT_ERRORS:
			if l.contains(String(p)):
				is_script = true
				break
		if is_script or l.contains("ERROR"):
			if is_script:
				se += 1
			else:
				oe += 1
			if errs.size() < LOG_ERRORS:
				errs.append(l.strip_edges().left(220))
				if i + 1 < lines.size() and lines[i + 1].strip_edges().begins_with("at:"):
					errs.append("  " + lines[i + 1].strip_edges().left(200))
		elif l.contains("WARNING"):
			wn += 1
	_cur["errors"] = errs
	_cur["script_errors"] = se
	_cur["other_errors"] = oe
	_cur["warnings"] = wn


func _log_len() -> int:
	var f := FileAccess.open(BotReport.log_file(), FileAccess.READ)
	if f == null:
		return 0
	return int(f.get_length())


func _log_since(from: int) -> PackedStringArray:
	var f := FileAccess.open(BotReport.log_file(), FileAccess.READ)
	if f == null:
		return PackedStringArray()
	var n := int(f.get_length()) - from
	if n <= 0:
		return PackedStringArray()
	f.seek(from)
	return f.get_buffer(mini(n, 4 * 1024 * 1024)).get_string_from_utf8().split("\n", false)


## Состояние, как у нового процесса в CI: дерево не на паузе, настройки по умолчанию (файла нет), подмены тестов сняты.
## Статические поля, которые тесты меняют (без поля — не нужно: тесты возвращают сами или не трогают).
func reset_env() -> void:
	var tree := bot.get_tree()
	tree.paused = false
	tree.root.disable_3d = false
	Engine.time_scale = 1.0
	if _settings_moved and FileAccess.file_exists(Quality.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Quality.PATH))
	Quality.reload()
	UiScale.reload()
	Util.refresh_theme()
	Quality.set_throttle(0)
	Quality._menu_open = false
	Quality._screen_idle = false
	Quality._background = false
	Quality.renderer_override = -1
	Quality.msaa_scaled_override = -1
	AdminPanel.reset_session()
	AdminPanel.spawn_level = int(_saved.get("spawn_level", 5))
	JobFxNeophyte.corpses.clear()
	CreatureAsset.use_assets = true
	CharacterModel.use_assets = true
	Handheld.force_missing = false
	UiIcons.force_procedural = false
	HeroSkills.job = String(_saved.get("job", ""))
	QuestData.extra = (_saved.get("extra", {}) as Dictionary).duplicate(true)
	Assets.plugin_override = _saved.get("plugin", null) as Object
	Assets.packs_dir = String(_saved.get("packs_dir", Assets.packs_dir))
	if Assets.force_missing != bool(_saved.get("missing", false)):
		Assets.simulate_missing(bool(_saved.get("missing", false)))
	var rg: Array = _saved.get("rg", [])
	if rg.size() == 7:
		RendererGuard.override_path = String(rg[0])
		RendererGuard.state_path = String(rg[1])
		RendererGuard.log_path = String(rg[2])
		RendererGuard.platform_override = int(rg[3])
		RendererGuard.method_override = String(rg[4])
		RendererGuard.gpu_override = String(rg[5])
		RendererGuard.plugin_override = int(rg[6])
	# Бот сам следит за температурой (авто-снижение главных сцен тестов — выключено)
	ThermalGuard.suspended = true
	Quality.apply_fps()


## Конец режима при любом исходе: идущий тест прерван, аккаунты тестов стёрты, настройки и файлы рендерера игрока —
## как до запуска.
func on_finish(b: TestBot) -> void:
	if bot == null:
		return
	if _phase == "run" or _phase == "settle":
		_abort("прерван: " + (b.stop_reason if b.stop_reason != "" else "бот остановлен"))
	reset_env()
	AdminPanel.tab = String(_saved.get("tab", AdminPanel.tab))
	AdminPanel.bot_mode = String(_saved.get("bot_mode", AdminPanel.bot_mode))
	Accounts.use_storage(ACCOUNTS, true)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ACCOUNTS).trim_suffix("/"))
	b.restore_settings()
	for p in _renderer_files:
		var was: String = _renderer_files[p]
		if _file_state(String(p)) == was:
			continue
		if was == "":
			DirAccess.remove_absolute(ProjectSettings.globalize_path(String(p)))
		else:
			var f := FileAccess.open(String(p), FileAccess.WRITE)
			if f != null:
				f.store_string(was.substr(1))
				f.close()
		b.note("Файл %s изменился во время автотестов — возвращён, как был" % String(p))
	UiScale.reload()
	Util.refresh_theme()


## Содержимое файла с меткой «есть»: "" — файла нет, иначе "+" и текст.
static func _file_state(path: String) -> String:
	return "+" + FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


func _count(st: String) -> int:
	var k := 0
	for r in results:
		if String(r["status"]) == st:
			k += 1
	return k


func summary(_b: TestBot) -> String:
	var bad := _count("fail") + _count("timeout") + _count("error") + _count("stopped")
	var left := planned - results.size()
	return "Автотесты: прошло %d, не прошло %d, пропущено %d%s — из %d" % [_count("ok"), bad, _count("skip"),
		", не успели %d" % left if left > 0 else "", planned]


static func _sec(v: float) -> String:
	return "%.1f с" % v if v < 60.0 else TestBot.clock(v)


func report_lines(_b: TestBot) -> PackedStringArray:
	var L := PackedStringArray()
	L.append("Автотесты")
	L.append("  " + summary(_b))
	L.append("  Условия: тесты писались для CI (без экрана, ровно 60 кадров/с — --fixed-fps 60); на телефоне кадр — "
		+ "настоящее время и экран рисуется, поэтому тесты на точное время могут вести себя иначе. Настройки — по "
		+ "умолчанию (настройки игрока убраны на время тестов и возвращены), аккаунты тестов — свои (стёрты в конце).")
	L.append("  %3s  %-34s %-12s %8s %7s %6s  %s" % ["№", "Тест", "Итог", "Время", "Кадров", "к/с", "Ошибок Godot (GDScript / прочих), предупреждений"])
	var i := 0
	for r in results:
		i += 1
		var st := String(r["status"])
		var errs := "—" if st == "skip" else "%d / %d, %d" % [int(r["script_errors"]), int(r["other_errors"]), int(r["warnings"])]
		L.append("  %3d  %-34s %-12s %8s %7s %6s  %s" % [i, String(r["name"]).left(34), String(STATUS_TEXT.get(st, st)),
			"—" if st == "skip" else _sec(float(r["sec"])), "—" if st == "skip" else str(int(r["frames"])),
			"—" if st == "skip" or float(r["fps"]) <= 0.0 else "%.0f" % float(r["fps"]), errs])
	var left := planned - results.size()
	if left > 0:
		L.append("  … ещё %d тестов не запускались (бот остановлен раньше)" % left)
	var bad: Array = []
	for r in results:
		if not ["ok", "skip"].has(String(r["status"])):
			bad.append(r)
	L.append("")
	L.append("Автотесты: не прошли — подробно (%d)" % bad.size())
	if bad.is_empty():
		L.append("  нет")
	for r in bad:
		L.append("  %s — %s: %s" % [String(r["name"]), String(STATUS_TEXT.get(String(r["status"]), "?")), String(r["text"])])
		var errs: PackedStringArray = r["errors"]
		if not errs.is_empty():
			L.append("    ошибки Godot за время теста (первые %d):" % errs.size())
			for e in errs:
				L.append("      " + e)
	var warn: Array = []
	for r in results:
		if String(r["status"]) == "ok" and int(r["other_errors"]) > 0:
			warn.append(r)
	if not warn.is_empty():
		L.append("")
		L.append("Автотесты: прошли, но в логе были ошибки Godot")
		for r in warn:
			L.append("  %s — ошибок %d:" % [String(r["name"]), int(r["other_errors"])])
			for e in (r["errors"] as PackedStringArray):
				L.append("      " + e)
	var skipped: Array = []
	for r in results:
		if String(r["status"]) == "skip":
			skipped.append(r)
	if not skipped.is_empty():
		L.append("")
		L.append("Автотесты: пропущены (%d)" % skipped.size())
		for r in skipped:
			L.append("  %s — %s" % [String(r["name"]), String(r["text"])])
	return L
