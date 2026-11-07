extends "res://tests/test_base.gd"
## Каталог автотестов (фаза 6, tests/catalog.gd — TestCatalog): у каждого теста в tests/ есть строка каталога
## (группа, название, что проверяет, флаги, секунды), и у каждой строки — файл; группы, флаги и числа правильные;
## список для телефона tests/tests_index.txt совпадает с каталогом; docs/TESTS.md (есть только в репозитории, не в
## APK) называет каждый тест, каждую группу и каждый режим бота; режимы бота разложены по группам MODE_GROUPS,
## у каждого — «что проверяет» и «когда запускать»; «Автотесты» берут быстрые, «только CI» и «нужен пакет» из
## каталога. Не сходится — python3 -I tools/tests_catalog.py (пишет docs/TESTS.md и tests/tests_index.txt).


func run_step() -> void:
	match step:
		0:
			_entries()
			_files()
			_doc()
			_modes()
			_autotests()
			ok_done()


## Строки каталога: группа из GROUPS, название и описание, флаги, секунды; в каждой группе есть тесты.
func _entries() -> void:
	var gids := TestCatalog.group_ids()
	check(gids.size() >= 10, "групп в каталоге: %d" % gids.size())
	for k in TestCatalog.TESTS:
		var id := String(k)
		var e: Array = TestCatalog.TESTS[k]
		check(e.size() == 5, "%s: [группа, название, что проверяет, флаги, секунды]" % id)
		if e.size() != 5:
			continue
		check(gids.has(String(e[0])), "%s: группа «%s» есть" % [id, String(e[0])])
		check(String(e[1]) != "" and String(e[2]).length() >= 20, "%s: название и описание («%s»)" % [id, String(e[1])])
		for f in e[3] as Array:
			var fs := String(f)
			check(fs == "quick" or fs == "pack" or (fs.begins_with("ci:") and fs.length() > 10),
				"%s: флаг «%s» известен (quick, pack, ci:<причина>)" % [id, fs])
		check(float(e[4]) > 0.0, "%s: секунды в CI > 0" % id)
	for g in gids:
		check(not TestCatalog.in_group(g).is_empty(), "в группе «%s» есть тесты" % TestCatalog.group_name(g))
	check(TestCatalog.quick().size() >= 15 and TestCatalog.quick()[0] == "smoke_test",
		"быстрых %d, первый — smoke_test" % TestCatalog.quick().size())


## Каталог и папка tests/: у каждого файла теста — строка, у каждой строки — файл; tests_index.txt — тот же список.
func _files() -> void:
	var scan := BotScenarioAutotests.scan_tests()
	var idx := BotScenarioAutotests.index_tests()
	var have := scan if not scan.is_empty() else idx
	check(not have.is_empty(), "список тестов получен (папка %d, tests_index.txt %d)" % [scan.size(), idx.size()])
	for n in have:
		check(TestCatalog.has(String(n)), "тест %s описан в tests/catalog.gd" % String(n))
	for k in TestCatalog.TESTS:
		check(have.has(String(k)), "у строки каталога %s есть файл tests/%s.gd" % [String(k), String(k)])
	var want := PackedStringArray()
	for k in TestCatalog.TESTS:
		want.append(String(k))
	want.sort()
	want.remove_at(want.find("smoke_test"))
	want.insert(0, "smoke_test")
	check(idx == want, "tests/tests_index.txt = каталог (%d и %d) — python3 -I tools/tests_catalog.py" % [idx.size(),
		want.size()])
	for n in TestCatalog.NOT_TESTS:
		check(not TestCatalog.has(String(n)), "служебный %s — не тест" % String(n))


## docs/TESTS.md (только в репозитории): каждый тест, группа и режим бота.
func _doc() -> void:
	var path := "res://docs/TESTS.md"
	if not FileAccess.file_exists(path):
		print("docs/TESTS.md нет (APK) — сверка документа пропущена")
		return
	var text := FileAccess.get_file_as_string(path)
	var miss := PackedStringArray()
	for k in TestCatalog.TESTS:
		if not text.contains("`%s`" % String(k)) or not text.contains(TestCatalog.title(String(k))):
			miss.append(String(k))
	check(miss.is_empty(), "docs/TESTS.md: все тесты с названиями (нет: %s) — python3 -I tools/tests_catalog.py" % [miss])
	for g in TestCatalog.GROUPS:
		check(text.contains("### " + String(g[1])), "docs/TESTS.md: группа «%s»" % String(g[1]))
	for e in BotScenario.MODES:
		check(text.contains(String((e as Dictionary)["name"])), "docs/TESTS.md: режим «%s»" % String((e as Dictionary)["name"]))


## Режимы бота: в группах MODE_GROUPS, «что проверяет» и «когда запускать»; в каждой группе есть режимы.
func _modes() -> void:
	var gids := []
	for g in BotScenario.MODE_GROUPS:
		gids.append(String(g[0]))
		check(String(g[1]) != "" and String(g[2]).length() > 20, "группа режимов «%s»: название и описание" % String(g[1]))
		check(not BotScenario.modes_in(String(g[0])).is_empty(), "в группе режимов «%s» есть режимы" % String(g[1]))
	for e in BotScenario.MODES:
		var m: Dictionary = e
		check(gids.has(String(m.get("group", ""))), "режим %s: группа «%s» есть" % [m["id"], m.get("group", "")])
		check(String(m.get("about", "")).length() > 20 and String(m.get("when", "")) != "",
			"режим %s: «что проверяет» и «когда запускать»" % m["id"])
		check(BotScenario.create(String(m["id"])) != null, "режим %s создаётся" % m["id"])


## «Автотесты»: быстрые, «только CI» и «нужен пакет» — из каталога; режим по группам берёт тесты выбранных групп.
func _autotests() -> void:
	check(Array(BotScenarioAutotests.QUICK) == Array(TestCatalog.quick()), "быстрые автотесты — из каталога")
	for k in TestCatalog.TESTS:
		var id := String(k)
		var why := TestCatalog.ci_only(id)
		check(BotScenarioAutotests.CI_ONLY.has(id) == (why != ""), "%s: «только CI» — из каталога" % id)
		check(BotScenarioAutotests.NEED_PACK.has(id) == TestCatalog.needs_pack(id), "%s: «нужен пакет» — из каталога" % id)
	var keep := BotScenarioAutotests.chosen_groups.duplicate()
	BotScenarioAutotests.chosen_groups = PackedStringArray(["dungeon", "pets"])
	var sc := BotScenario.create("autotests_groups") as BotScenarioAutotests
	var names := sc.test_names()
	var ok := not names.is_empty()
	for n in names:
		if not ["dungeon", "pets"].has(TestCatalog.group_of(String(n))):
			ok = false
	check(ok and names.has("test_dungeon") and names.has("test_pets"), "по группам «Подземелье» и «Питомцы»: %d тестов" % names.size())
	check(sc.limit() > 60.0 and sc.limit() < 75.0 * 60.0, "лимит по группам — по оценке (%.0f с)" % sc.limit())
	BotScenarioAutotests.chosen_groups = PackedStringArray()
	check(BotScenarioAutotests.groups_block() != "", "без выбранных групп начать нельзя: %s" % BotScenarioAutotests.groups_block())
	BotScenarioAutotests.chosen_groups = keep
