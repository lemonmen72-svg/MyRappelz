extends "res://tests/test_base.gd"
## Пакет ресурсов (Assets, AssetLoader) по частям (Assets.PACKS): в автотестах ресурсы встроены — экран загрузки не
## показывается, мир запускается сразу. Части совпадают с пресетами экспорта («Assets <часть>», исключения APK
## «Android», манифест в APK, разрешение INTERNET); какие модели в какой части, а какие запасные остаются в APK;
## часть подключена, другая нет — модели первой настоящие, второй «нет». Без пакета (Assets.simulate_missing) герой
## любой расы, пола и профессии — запасная модель пола, звери старших стадий — модель 1-й стадии.
## Манифест: новый формат (части) и старый (один пакет — часть «all»), битые. Экран загрузки без сети (манифест
## подставляется, файлы кладёт тест; три настоящих .pck из PCKPacker — по части): предупреждение о размере только
## недостающих частей (одна часть уже в кэше), «Играть без загрузки», части по очереди, битый файл (sha256), обрыв
## сети, «Повторить» (только недостающее), установка части — прежние версии этой части удалены, все части на месте —
## удалено остальное (прежние версии, старый пакет целиком, недокачанные файлы), подключены все (их файлы видны
## в res://); те же хэши — из кэша без загрузки; манифест из сети (битый, 404, части, старый формат).
## Фоновая загрузка Android DownloadManager — подставной плагин FakeDownloads (Assets.plugin_override): без плагина
## (не Android) и когда DownloadManager не принял загрузку — HTTPRequest; все недостающие части отдаются сразу,
## суммарный ход загрузки, ожидание сети, ошибка и отмена одной части (остальные убираются, «Повторить»), битый файл,
## успех — проверка sha256 каждой части с копированием из «внешней папки» в кэш и подключение; записи о загрузках
## переживают перезапуск (следующий экран сразу следит за ними; запись старой версии игры и другого хэша
## убираются); «Играть, пока грузится» — фоновый AssetLoader допроверяет часть, кладёт в кэш (не подключая посреди
## игры) и пишет в HUD; плагин Android и его включение в проекте на месте.
## Части мира, зверей 1-й стадии, оружия и значков (world, creatures_base, handheld, icons): какие файлы в какой
## части, .json — в APK; порядок загрузки Assets.LOAD_ORDER (мир первым). Быстрый старт при загрузке HTTPRequest:
## мир загружен — «Играть, пока грузится» подключает его сразу, остальные части загружает фоновый AssetLoader
## (http_resume), кладёт в кэш, не подключая посреди игры. Игра целиком без пакета — tests/test_asset_fallback.gd.

const TEST_DIR := "user://test_packs/"
const SRC_DIR := "user://test_pack_src/"
const PROBE_DIR := "res://test_asset_pack/"
## Части теста (настоящие имена частей; в каждом .pck — один файл PROBE_DIR + <часть>.txt).
const PA := "heroes_dark"
const PB := "npcs"
const PC := "creatures"
const H0 := "0000000000000000"
const H1 := "a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1"
const H2 := "b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2"
const H3 := "c3c3c3c3c3c3c3c3"
const H4 := "d4d4d4d4d4d4d4d4"
const H5 := "e5e5e5e5e5e5e5e5"
const H6 := "f6f6f6f6f6f6f6f6"
const PLUGIN_DIR := "res://android/plugins/myrappelz_download/"
const STAGED := ["panther", "pheasant", "turtle", "wolf", "centaur"]
const RACE_PART := {"dark_elf": "heroes_dark", "light_elf": "heroes_light", "human": "heroes_human"}
## Часть «мир» теста быстрого старта (файл — тестовый .pck части PC).
const PW := "world"

var loader: AssetLoader
var results: Array = []
## Тестовые .pck: часть → {bytes, sha, size}.
var packs: Dictionary = {}
var ma: Dictionary = {}
var m3: Dictionary = {}
var m4: Dictionary = {}
var fake: FakeDownloads
var id_b := ""
var id_c := ""
var bg: AssetLoader
var saved_loaded: Dictionary = {}


## Подставной плагин фоновой загрузки (те же методы, что у MyRappelzDownload на Android): загрузки — словари,
## «внешняя папка приложения» — user://test_ext/. Тест сам меняет состояние загрузки (set_job) и кладёт файл.
class FakeDownloads:
	extends RefCounted
	const DIR := "user://test_ext/"
	var next_id := 100
	var started: Array = []
	var removed: Array = []
	var asked := 0
	var fail_start := false
	var jobs: Dictionary = {}

	func externalPath(rel: String) -> String:
		return DIR + rel

	func start(url: String, rel: String, title: String, text: String) -> String:
		if fail_start:
			return ""
		next_id += 1
		var id := str(next_id)
		started.append([url, rel, title, text])
		jobs[id] = {"status": AssetLoader.DM_PENDING, "reason": 0, "bytes": 0, "total": -1, "path": externalPath(rel)}
		DirAccess.make_dir_recursive_absolute(externalPath(rel).get_base_dir())
		return id

	func query(id: String) -> Dictionary:
		if not jobs.has(id):
			return {"found": false}
		var d: Dictionary = (jobs[id] as Dictionary).duplicate()
		d["found"] = true
		return d

	## Как DownloadManager.remove: загрузка и её файл удаляются.
	func remove(id: String) -> bool:
		removed.append(id)
		if not jobs.has(id):
			return false
		Assets.remove_file(String((jobs[id] as Dictionary)["path"]))
		jobs.erase(id)
		return true

	func requestNotifications() -> void:
		asked += 1

	func notificationsAllowed() -> bool:
		return true

	func lastError() -> String:
		return "тест"

	func set_job(id: String, status: int, bytes: int, total: int, reason: int = 0) -> void:
		var j: Dictionary = jobs[id]
		j["status"] = status
		j["bytes"] = bytes
		j["total"] = total
		j["reason"] = reason


func race_class() -> Array:
	return ["light_elf", "wizard"]


func run_step() -> void:
	match step:
		0:
			check(Assets.embedded() and Assets.available(), "в тестах ресурсы встроены (Assets.embedded)")
			check(main.hud != null and main.player != null, "мир запущен сразу, без экрана загрузки")
			var loaders := 0
			for c in main.get_children():
				if c is AssetLoader:
					loaders += 1
			check(loaders == 0, "экрана загрузки нет")
			_check_presets()
			_check_files()
			_check_partial()
			_check_manifest_parse()
			step = 1
		1:
			_check_fallback()
			_prepare_packs()
			ma = _man([_part(PA, H1), _part(PB, H2), _part(PC, H3)])
			_new_loader(ma)
			wait = 2
			step = 2
		2:
			var all_size := _size(PA) + _size(PB) + _size(PC)
			check(loader.state == AssetLoader.State.CONFIRM, "без частей в кэше — предупреждение перед загрузкой")
			check(loader.todo.size() == 3 and loader.total_bytes == all_size, "загрузить все 3 части: %d байт" % loader.total_bytes)
			check(loader._text.text.contains("Будет загружено") and loader._text.text.contains("Wi-Fi")
				and loader._text.text.contains(AssetLoader._mb(all_size)), "предупреждение о размере и сети: " + loader._text.text)
			check(loader._main_btn.visible and loader._main_btn.text.contains("МБ"), "кнопка «%s»" % loader._main_btn.text)
			(loader.buttons["skip"] as Button).pressed.emit()
			wait = 2
			step = 3
		3:
			check(results == [false], "«Играть без загрузки» — без пакета: %s" % str(results))
			check(Assets.skipped and Assets.loaded.is_empty(), "ничего не подключено, выбор запомнен")
			loader.queue_free()
			Assets.skipped = false
			# Часть A уже в кэше; там же прежние версии A и B, недокачанный файл C и старый пакет целиком
			_write(Assets.pack_path(PA, H1), _bytes(PA))
			_write(Assets.pack_path(PA, H0), PackedByteArray([1, 2, 3]))
			_write(Assets.pack_path(PB, H0), PackedByteArray([4]))
			_write(Assets.part_path(PC, H0), PackedByteArray([5]))
			_write(Assets.pack_path(Assets.ALL, H4), PackedByteArray([6, 7]))
			_new_loader(ma)
			wait = 2
			step = 4
		4:
			var need := _size(PB) + _size(PC)
			check(loader.state == AssetLoader.State.CONFIRM, "часть в кэше — остальные спрашиваем")
			check(_names(loader.todo) == [PB, PC] and loader.total_bytes == need,
				"загрузить только недостающие: %s, %d байт" % [str(_names(loader.todo)), loader.total_bytes])
			check(loader._text.text.contains(AssetLoader._mb(need)) and loader._text.text.contains("2 из 3"),
				"размер только недостающих частей: " + loader._text.text)
			# Битый файл: размер тот же, один байт другой — sha256 не совпадает
			(loader.buttons["main"] as Button).pressed.emit()
			check(loader.state == AssetLoader.State.DOWNLOAD and String(loader.current.get("name", "")) == PB,
				"«Загрузить» — первая недостающая часть")
			check(loader._text.text.contains("Часть 1 из 2"), "подпись части: " + loader._text.text)
			_write(Assets.part_path(PB, H2), _broken(_bytes(PB)))
			loader._on_download_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), PackedByteArray())
			check(loader.state == AssetLoader.State.VERIFY, "файл загружен — проверка")
			wait = 3
			step = 5
		5:
			if loader.state == AssetLoader.State.VERIFY:
				return
			check(loader.state == AssetLoader.State.ERROR and loader.error_text.contains("повреждён"),
				"битый файл — ошибка: " + loader.error_text)
			check(not FileAccess.file_exists(Assets.part_path(PB, H2)) and not FileAccess.file_exists(Assets.pack_path(PB, H2)),
				"битый временный файл удалён, в кэш не попал")
			check(loader._main_btn.visible and loader._main_btn.text == "Повторить", "кнопка «Повторить»")
			# «Повторить» → снова предупреждение → «Загрузить» → обрыв сети
			(loader.buttons["main"] as Button).pressed.emit()
			check(loader.state == AssetLoader.State.CONFIRM and loader.todo.size() == 2, "«Повторить» — снова предупреждение")
			(loader.buttons["main"] as Button).pressed.emit()
			_write(Assets.part_path(PB, H2), _bytes(PB).slice(0, 10))
			loader._on_download_completed(HTTPRequest.RESULT_CONNECTION_ERROR, 0, PackedStringArray(), PackedByteArray())
			check(loader.state == AssetLoader.State.ERROR and loader.error_text.contains("нет соединения"),
				"обрыв сети — ошибка: " + loader.error_text)
			check(not FileAccess.file_exists(Assets.part_path(PB, H2)), "недокачанный файл удалён")
			# Ещё раз — часть B успешно
			(loader.buttons["main"] as Button).pressed.emit()
			(loader.buttons["main"] as Button).pressed.emit()
			_write(Assets.part_path(PB, H2), _bytes(PB))
			loader._on_download_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), PackedByteArray())
			wait = 3
			step = 6
		6:
			if loader.state == AssetLoader.State.VERIFY:
				return
			check(loader.state == AssetLoader.State.DOWNLOAD and String(loader.current.get("name", "")) == PC,
				"часть B проверена — загружается следующая (%s)" % loader.error_text)
			check(FileAccess.file_exists(Assets.pack_path(PB, H2)) and not FileAccess.file_exists(Assets.part_path(PB, H2)),
				"часть B: временный файл переименован в assets-<часть>-<хэш>.pck")
			check(not FileAccess.file_exists(Assets.pack_path(PB, H0)), "прежняя версия части B удалена")
			check(FileAccess.file_exists(Assets.pack_path(PA, H0)), "прежние версии других частей — до конца загрузки")
			check(loader.done_bytes == _size(PB) and loader._text.text.contains("Часть 2 из 2"),
				"ход загрузки с учётом готовой части: %d, «%s»" % [loader.done_bytes, loader._text.text])
			check(Assets.loaded.is_empty(), "до конца загрузки части не подключаются")
			_write(Assets.part_path(PC, H3), _bytes(PC))
			loader._on_download_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), PackedByteArray())
			wait = 3
			step = 7
		7:
			if loader.state == AssetLoader.State.VERIFY:
				return
			check(loader.state == AssetLoader.State.DONE, "все части проверены (%s)" % loader.error_text)
			wait = 2
			step = 8
		8:
			check(results == [true], "загрузка закончена с пакетом: %s" % str(results))
			check(loader.downloaded, "части загружены по сети (не только из кэша)")
			for p in Assets.manifest_parts(ma):
				var path := Assets.pack_path_of(p)
				check(FileAccess.file_exists(path) and String(Assets.loaded.get(p["name"], "")) == path,
					"часть %s в кэше и подключена: %s" % [p["name"], str(Assets.loaded)])
				check(FileAccess.get_file_as_string(PROBE_DIR + String(p["name"]) + ".txt") == String(p["name"]),
					"файл части %s виден по своему пути res://" % p["name"])
			check(not FileAccess.file_exists(Assets.pack_path(PA, H0)) and not FileAccess.file_exists(Assets.part_path(PC, H0))
				and not FileAccess.file_exists(Assets.pack_path(Assets.ALL, H4)),
				"прежние версии, недокачанный файл и старый пакет целиком удалены")
			check(_cache_count() == 3, "в кэше только 3 части: %d файлов" % _cache_count())
			loader.queue_free()
			# Те же хэши — из кэша, без предупреждения и загрузки
			var wrong: Dictionary = (Assets.manifest_parts(ma)[1] as Dictionary).duplicate()
			wrong["size"] = int(wrong["size"]) + 1
			check(Assets.cached_pack(wrong) == "", "в кэше другой размер — не годится")
			_new_loader(ma)
			check(loader.state == AssetLoader.State.DONE and not loader.downloaded, "те же хэши — сразу из кэша")
			wait = 2
			step = 9
		9:
			check(results == [true], "из кэша — с пакетом: %s" % str(results))
			loader.queue_free()
			# Манифест из сети: в тестах версии игры нет, манифеста в APK нет — ошибка; ответ сервера подставляем
			_new_loader({})
			check(loader.state == AssetLoader.State.ERROR, "без манифеста и версии — ошибка: " + loader.error_text)
			_net_manifest("{\"parts\": [{\"name\": \"npcs\", \"hash\": \"zz\"}]}", 200)
			check(loader.state == AssetLoader.State.ERROR and loader.error_text.contains("повреждены"),
				"битый манифест — ошибка: " + loader.error_text)
			_net_manifest("", 404)
			check(loader.state == AssetLoader.State.ERROR and loader.error_text.contains("404"), "нет манифеста (404)")
			# Новая версия игры: изменилась только часть C
			_net_manifest(JSON.stringify({"format": 2, "version": "test2",
				"parts": [_part(PA, H1), _part(PB, H2), _part(PC, H5)]}), 200)
			check(loader.state == AssetLoader.State.CONFIRM and _names(loader.todo) == [PC] and loader.total_bytes == _size(PC),
				"манифест из сети — загрузить только изменившуюся часть: %s" % str(_names(loader.todo)))
			check(loader._text.text.contains("1 из 3"), "«частей: 1 из 3»: " + loader._text.text)
			# Старый формат (один пакет на всё) — одна часть «all»
			_net_manifest(JSON.stringify({"hash": H6, "sha256": String(packs[PA]["sha"]), "size": _size(PA),
				"url": "https://example.invalid/old.pck", "version": "0.23.0"}), 200)
			var parts := Assets.manifest_parts(loader.manifest)
			check(loader.state == AssetLoader.State.CONFIRM and parts.size() == 1
				and String((parts[0] as Dictionary)["name"]) == Assets.ALL and loader.total_bytes == _size(PA),
				"старый манифест — одна часть «all»: %s" % str(loader.manifest))
			# «Играть без загрузки» — подключено то, что есть в кэше
			(loader.buttons["skip"] as Button).pressed.emit()
			wait = 2
			step = 10
		10:
			check(results == [true], "без загрузки, но с частями из кэша: %s" % str(results))
			loader.queue_free()
			_check_plugin_files()
			# Фоновая загрузка: не Android — плагина нет, загрузка через HTTPRequest (всё, что выше)
			check(Assets.download_plugin() == null, "не Android — плагина фоновой загрузки нет, загрузка HTTPRequest")
			fake = FakeDownloads.new()
			Assets.plugin_override = fake
			check(Assets.download_plugin() == fake, "подставной плагин фоновой загрузки")
			m3 = _man([_part(PA, H1), _part(PB, H4), _part(PC, H5)])
			# DownloadManager не принял загрузку — откат на HTTPRequest
			fake.fail_start = true
			_new_loader(m3)
			check(loader.state == AssetLoader.State.CONFIRM and loader.todo.size() == 2, "с плагином — то же предупреждение")
			(loader.buttons["main"] as Button).pressed.emit()
			check(loader.state == AssetLoader.State.DOWNLOAD and loader.jobs.is_empty() and fake.started.is_empty(),
				"DownloadManager не принял загрузку — загрузка через HTTPRequest")
			check(Assets.read_jobs().is_empty(), "записей о фоновой загрузке нет")
			check(loader._text.text.contains("Не закрывайте"), "HTTPRequest — «Не закрывайте игру»")
			loader.queue_free()
			fake.fail_start = false
			_new_loader(m3)
			(loader.buttons["main"] as Button).pressed.emit()
			check(loader.state == AssetLoader.State.DOWNLOAD and loader.jobs.size() == 2 and fake.started.size() == 2,
				"«Загрузить» — обе недостающие части отданы DownloadManager сразу")
			check(fake.asked == 1, "спрошено разрешение на уведомления")
			if fake.started.size() == 2:
				var st: Array = fake.started[0]
				check(String(st[0]) == String(_part(PB, H4)["url"]) and String(st[1]) == Assets.download_rel_path(PB, H4),
					"адрес и файл загрузки части: %s" % str(st))
				check(String(st[2]).contains("Dark Pact") and String(st[3]).contains("МБ") and String(st[3]).contains("1 из 2"),
					"уведомление: %s" % str(st))
				check(String((fake.started[1] as Array)[1]) == Assets.download_rel_path(PC, H5), "вторая часть")
			id_b = _job_id(PB)
			id_c = _job_id(PC)
			var saved := Assets.read_jobs()
			check(saved.size() == 2 and String((saved.get(PB, {}) as Dictionary).get("id", "")) == id_b
				and String((saved.get(PC, {}) as Dictionary).get("hash", "")) == H5
				and String((saved.get(PB, {}) as Dictionary).get("path", "")) == fake.externalPath(Assets.download_rel_path(PB, H4)),
				"записи о загрузках частей: %s" % str(saved))
			check(loader._text.text.contains("свернуть") and loader._text.text.contains("уведомлени"),
				"игру можно свернуть, ход — в уведомлениях: " + loader._text.text)
			check(loader._skip_btn.visible and loader._skip_btn.text == "Играть, пока грузится", "«Играть, пока грузится»")
			var sb := _size(PB)
			var sc := _size(PC)
			fake.set_job(id_b, AssetLoader.DM_RUNNING, sb >> 1, sb)
			fake.set_job(id_c, AssetLoader.DM_PENDING, 0, sc)
			loader._poll_dm()
			var want := 100.0 * float(sb >> 1) / float(sb + sc)
			check(absf(loader._bar.value - want) < 0.5 and loader._detail.text.contains(" из "),
				"суммарный ход загрузки: %.1f %% (нужно %.1f), «%s»" % [loader._bar.value, want, loader._detail.text])
			fake.set_job(id_b, AssetLoader.DM_PAUSED, sb >> 1, sb, 2)
			fake.set_job(id_c, AssetLoader.DM_PAUSED, 0, sc, 2)
			loader._poll_dm()
			check(loader.state == AssetLoader.State.DOWNLOAD and loader._detail.text.contains("ожидание сети"),
				"пауза — «%s»" % loader._detail.text)
			loader._on_download_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), PackedByteArray())
			check(loader.state == AssetLoader.State.DOWNLOAD, "ответ HTTPRequest при загрузке DownloadManager не в счёт")
			# Ошибка загрузки одной части — убираются обе, «Повторить»
			fake.set_job(id_c, AssetLoader.DM_FAILED, 0, sc, 1006)
			loader._poll_dm()
			check(loader.state == AssetLoader.State.ERROR and loader.error_text.contains("недостаточно места"),
				"ошибка DownloadManager: " + loader.error_text)
			check(fake.removed.has(id_b) and fake.removed.has(id_c) and Assets.read_jobs().is_empty(),
				"загрузки всех частей убраны, записи стёрты")
			check(loader._main_btn.visible and loader._main_btn.text == "Повторить", "кнопка «Повторить»")
			# Отмена одной части в уведомлении («Загрузки»)
			(loader.buttons["main"] as Button).pressed.emit()
			(loader.buttons["main"] as Button).pressed.emit()
			check(loader.jobs.size() == 2 and _job_id(PB) != id_b, "«Повторить» — новые загрузки")
			id_b = _job_id(PB)
			id_c = _job_id(PC)
			fake.jobs.erase(id_b)
			loader._poll_dm()
			check(loader.state == AssetLoader.State.ERROR and loader.error_text.contains("отменена"),
				"отмена загрузки: " + loader.error_text)
			check(Assets.read_jobs().is_empty() and fake.removed.has(id_c), "после отмены другая загрузка убрана, записей нет")
			# Загружен битый файл части B
			(loader.buttons["main"] as Button).pressed.emit()
			(loader.buttons["main"] as Button).pressed.emit()
			id_b = _job_id(PB)
			id_c = _job_id(PC)
			_write(fake.externalPath(Assets.download_rel_path(PB, H4)), _broken(_bytes(PB)))
			fake.set_job(id_b, AssetLoader.DM_SUCCESS, sb, sb)
			fake.set_job(id_c, AssetLoader.DM_RUNNING, 1, sc)
			loader._poll_dm()
			check(loader.state == AssetLoader.State.VERIFY and loader._text.text.contains("перенос"),
				"часть загружена — проверка и перенос в кэш")
			wait = 3
			step = 11
		11:
			if loader.state == AssetLoader.State.VERIFY:
				return
			check(loader.state == AssetLoader.State.ERROR and loader.error_text.contains("повреждён"),
				"битый файл DownloadManager — ошибка: " + loader.error_text)
			var ext := fake.externalPath(Assets.download_rel_path(PB, H4))
			check(not FileAccess.file_exists(Assets.part_path(PB, H4)) and not FileAccess.file_exists(ext)
				and not FileAccess.file_exists(Assets.pack_path(PB, H4)), "битый файл и его копия удалены, в кэш не попали")
			check(fake.removed.has(id_b) and fake.removed.has(id_c) and Assets.read_jobs().is_empty(),
				"загрузки убраны (и второй части)")
			# Успех: обе части готовы
			(loader.buttons["main"] as Button).pressed.emit()
			(loader.buttons["main"] as Button).pressed.emit()
			id_b = _job_id(PB)
			id_c = _job_id(PC)
			_write(ext, _bytes(PB))
			_write(fake.externalPath(Assets.download_rel_path(PC, H5)), _bytes(PC))
			fake.set_job(id_b, AssetLoader.DM_SUCCESS, _size(PB), _size(PB))
			fake.set_job(id_c, AssetLoader.DM_SUCCESS, _size(PC), _size(PC))
			loader.poll_time = 0.0
			wait = 3
			step = 12
		12:
			if loader.state == AssetLoader.State.DOWNLOAD or loader.state == AssetLoader.State.VERIFY:
				return
			check(loader.state == AssetLoader.State.DONE, "загрузка DownloadManager проверена (%s)" % loader.error_text)
			wait = 2
			step = 13
		13:
			check(results == [true], "загрузка DownloadManager закончена с пакетом: %s" % str(results))
			for pair in [[PB, H4], [PC, H5]]:
				var pname := String(pair[0])
				var h := String(pair[1])
				check(FileAccess.file_exists(Assets.pack_path(pname, h)) and not FileAccess.file_exists(Assets.part_path(pname, h)),
					"часть %s скопирована в кэш" % pname)
				check(not FileAccess.file_exists(fake.externalPath(Assets.download_rel_path(pname, h))),
					"файл части %s во внешней папке удалён" % pname)
				check(String(Assets.loaded.get(pname, "")) == Assets.pack_path(pname, h), "часть %s подключена" % pname)
			check(fake.removed.has(id_b) and fake.removed.has(id_c) and Assets.read_jobs().is_empty(),
				"загрузки убраны, записи стёрты")
			check(FileAccess.file_exists(Assets.pack_path(PB, H2)) and FileAccess.file_exists(Assets.pack_path(PC, H3)),
				"подключённые прежние версии частей не удаляются, пока игра идёт")
			loader.queue_free()
			# Записи старой версии игры ([job]) и другого хэша части — загрузки убираются
			m4 = _man([_part(PA, H1), _part(PB, H6), _part(PC, H5)])
			var old_rel := Assets.DOWNLOAD_DIR + "assets-" + H2 + ".pck.download"
			var old_id := String(fake.start("https://example.invalid/old.pck", old_rel, "", ""))
			_write(fake.externalPath(old_rel), PackedByteArray([1, 2, 3]))
			var other_rel := Assets.download_rel_path(PB, H0)
			var other_id := String(fake.start("https://example.invalid/b.pck", other_rel, "", ""))
			var cfg := ConfigFile.new()
			cfg.set_value("job", "hash", H2)
			cfg.set_value("job", "id", old_id)
			cfg.set_value("job", "path", fake.externalPath(old_rel))
			cfg.set_value("part." + PB, "hash", H0)
			cfg.set_value("part." + PB, "id", other_id)
			cfg.set_value("part." + PB, "path", fake.externalPath(other_rel))
			cfg.save(Assets.packs_dir + Assets.JOB_FILE)
			check(Assets.read_jobs().size() == 2, "записи читаются: %s" % str(Assets.read_jobs()))
			_new_loader(m4)
			check(loader.state == AssetLoader.State.CONFIRM and _names(loader.todo) == [PB],
				"записи не той версии — снова предупреждение о размере")
			check(fake.removed.has(old_id) and fake.removed.has(other_id) and Assets.read_jobs().is_empty()
				and not FileAccess.file_exists(fake.externalPath(old_rel)), "загрузки прежних версий убраны")
			loader.queue_free()
			# Загрузка шла, игру закрыли: следующий запуск сразу следит за ней, без вопроса
			var rel := Assets.download_rel_path(PB, H6)
			id_b = String(fake.start(String(_part(PB, H6)["url"]), rel, "", ""))
			var size := _size(PB)
			fake.set_job(id_b, AssetLoader.DM_RUNNING, int(size * 0.3), size)
			Assets.save_jobs({PB: {"hash": H6, "id": id_b, "path": fake.externalPath(rel)}})
			_new_loader(m4)
			check(loader.state == AssetLoader.State.DOWNLOAD and _job_id(PB) == id_b,
				"после перезапуска — та же загрузка, без вопроса о размере")
			check(absf(loader._bar.value - 100.0 * float(int(size * 0.3)) / float(size)) < 0.5,
				"ход загрузки сразу: %.1f %%" % loader._bar.value)
			# «Играть, пока грузится»: загрузка не останавливается, за ней следит фоновый узел
			(loader.buttons["skip"] as Button).pressed.emit()
			check(not fake.removed.has(id_b) and String((Assets.read_jobs().get(PB, {}) as Dictionary).get("id", "")) == id_b,
				"загрузка DownloadManager продолжается")
			check(Assets.skipped, "выбор «без загрузки» запомнен")
			wait = 2
			step = 14
		14:
			check(results.size() == 1, "экран загрузки закрыт: %s" % str(results))
			loader.queue_free()
			bg = null
			for n in get_tree().root.get_children():
				if n is AssetLoader and (n as AssetLoader).background:
					bg = n as AssetLoader
			check(bg != null and not bg.visible, "фоновый узел у корня дерева, невидимый")
			if bg == null:
				return
			check(bg.state == AssetLoader.State.DOWNLOAD and String((bg.jobs.get(PB, {}) as Dictionary).get("id", "")) == id_b,
				"фоновый узел следит за загрузкой")
			# Подключённого будто нет — тогда новая часть подключится при следующем входе в мир
			saved_loaded = Assets.loaded.duplicate()
			Assets.loaded = {}
			_write(fake.externalPath(Assets.download_rel_path(PB, H6)), _bytes(PB))
			fake.set_job(id_b, AssetLoader.DM_SUCCESS, _size(PB), _size(PB))
			bg.poll_time = 0.0
			wait = 3
			step = 15
		15:
			if is_instance_valid(bg) and (bg.state == AssetLoader.State.DOWNLOAD or bg.state == AssetLoader.State.VERIFY):
				return
			check(FileAccess.file_exists(Assets.pack_path(PB, H6)), "фоновая загрузка — часть в кэше")
			check(Assets.read_jobs().is_empty() and fake.removed.has(id_b)
				and not FileAccess.file_exists(fake.externalPath(Assets.download_rel_path(PB, H6))), "загрузка и её файл убраны")
			check(Assets.loaded.is_empty(), "посреди игры части не подключаются")
			check(not Assets.skipped, "при следующем входе в мир экран загрузки возьмёт части из кэша")
			wait = 2
			step = 16
		16:
			check(not is_instance_valid(bg), "фоновый узел удалён")
			check(String(main.hud._msg_label.text).contains("Пакет ресурсов загружен"),
				"сообщение в HUD: " + String(main.hud._msg_label.text))
			Assets.loaded = saved_loaded
			_cleanup()
			# Быстрый старт (HTTPRequest): мир первым, «Играть, пока грузится» после него
			Assets.packs_dir = TEST_DIR
			Assets.ensure_dir()
			Assets.simulate_missing(true)
			main.hud.show_message("", 0.1)
			_new_loader(_man([_part(PA, H1), _world_part()]))
			check(loader.state == AssetLoader.State.CONFIRM and _names(loader.todo) == [PW, PA],
				"мир загружается первым: %s" % str(_names(loader.todo)))
			(loader.buttons["main"] as Button).pressed.emit()
			check(loader.state == AssetLoader.State.DOWNLOAD and String(loader.current.get("name", "")) == PW,
				"первая загружается часть «мир»")
			check(loader._skip_btn.visible and loader._skip_btn.text == "Играть, пока грузится"
				and loader._text.text.contains("Можно играть и сейчас"), "HTTPRequest — можно играть, пока грузится")
			_write(Assets.part_path(PW, H3), _bytes(PC))
			loader._on_download_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), PackedByteArray())
			wait = 3
			step = 17
		17:
			if loader.state == AssetLoader.State.VERIFY:
				return
			check(loader.state == AssetLoader.State.DOWNLOAD and String(loader.current.get("name", "")) == PA
				and FileAccess.file_exists(Assets.pack_path(PW, H3)), "мир в кэше, загружается следующая часть")
			(loader.buttons["skip"] as Button).pressed.emit()
			check(Assets.skipped and String(Assets.loaded.get(PW, "")) == Assets.pack_path(PW, H3),
				"«Играть, пока грузится» — мир подключён сразу: %s" % str(Assets.loaded))
			wait = 2
			step = 18
		18:
			check(results == [true], "экран загрузки закрыт с пакетом: %s" % str(results))
			loader.queue_free()
			bg = null
			for n in get_tree().root.get_children():
				if n is AssetLoader and (n as AssetLoader).background and (n as AssetLoader).http_resume:
					bg = n as AssetLoader
			check(bg != null and not bg.visible, "фоновый узел загрузки HTTPRequest у корня дерева")
			if bg == null:
				return
			check(bg.state == AssetLoader.State.DOWNLOAD and String(bg.current.get("name", "")) == PA
				and _names(bg.todo) == [PA], "фоновый узел загружает оставшуюся часть без вопроса")
			_write(Assets.part_path(PA, H1), _bytes(PA))
			bg._on_download_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), PackedByteArray())
			wait = 3
			step = 19
		19:
			if is_instance_valid(bg) and (bg.state == AssetLoader.State.DOWNLOAD or bg.state == AssetLoader.State.VERIFY):
				return
			check(FileAccess.file_exists(Assets.pack_path(PA, H1)), "фоновая загрузка HTTPRequest — часть в кэше")
			check(not Assets.loaded.has(PA), "посреди игры часть не подключается")
			check(not Assets.skipped, "при следующем входе в мир экран загрузки возьмёт части из кэша")
			wait = 3
			step = 20
		20:
			check(not is_instance_valid(bg), "фоновый узел удалён")
			check(String(main.hud._msg_label.text).contains("Пакет ресурсов загружен"),
				"сообщение в HUD: " + String(main.hud._msg_label.text))
			_cleanup()
			ok_done()


## Пресеты экспорта: по пресету «Assets <часть>» на каждую часть Assets.PACKS (Android, ETC2), шаблоны те же,
## APK их исключает, включает манифест, есть разрешение INTERNET.
func _check_presets() -> void:
	var cfg := ConfigFile.new()
	check(cfg.load("res://export_presets.cfg") == OK, "export_presets.cfg читается")
	var apk := ""
	var parts := {}
	for sec in cfg.get_sections():
		if not sec.begins_with("preset.") or sec.ends_with(".options"):
			continue
		var pname := String(cfg.get_value(sec, "name", ""))
		if pname == "Android":
			apk = sec
		elif pname.begins_with("Assets "):
			parts[pname.trim_prefix("Assets ")] = sec
	check(apk != "", "пресет «Android» есть")
	var names: Array = parts.keys()
	var want_names: Array = Assets.part_names()
	names.sort()
	want_names.sort()
	check(names == want_names, "пресеты частей = Assets.PACKS: %s" % str(names))
	var apk_exc := _split(String(cfg.get_value(apk, "exclude_filter", "")))
	for n in Assets.PACKS:
		if not parts.has(n):
			continue
		var psec := String(parts[n])
		check(String(cfg.get_value(psec, "platform", "")) == "Android", "часть %s экспортируется под Android (ETC2/ASTC)" % n)
		var inc := _split(String(cfg.get_value(psec, "include_filter", "")))
		var want: Array = []
		for f in Assets.PACKS[n]:
			want.append(String(f))
		inc.sort()
		want.sort()
		check(inc == want, "шаблоны части %s в export_presets.cfg = Assets.PACKS" % n)
		var missing: Array = []
		for f in want:
			if not apk_exc.has(f):
				missing.append(f)
		check(missing.is_empty(), "APK исключает файлы части %s (нет: %s)" % [n, str(missing)])
	check(_split(String(cfg.get_value(apk, "include_filter", ""))).has("assets_pack.json"), "манифест пакета — в APK")
	check(_split(String(cfg.get_value(apk, "include_filter", ""))).has("assets/characters/*.json"),
		"роли костей героев (.json) — в APK")
	check(bool(cfg.get_value(apk + ".options", "permissions/internet", false)), "у APK есть разрешение INTERNET")


## Плагин Android фоновой загрузки: имя singleton совпадает с Assets.DOWNLOAD_PLUGIN (класс, манифест AAR),
## плагин редактора включён в проекте и подключает AAR, который собирает сборка APK.
func _check_plugin_files() -> void:
	var java := FileAccess.get_file_as_string(PLUGIN_DIR + "src/main/java/com/lemonmen/myrappelz/download/DownloadPlugin.java")
	var manifest_xml := FileAccess.get_file_as_string(PLUGIN_DIR + "src/main/AndroidManifest.xml")
	check(java.contains("\"%s\"" % Assets.DOWNLOAD_PLUGIN) and java.contains("DownloadManager"),
		"класс плагина — singleton %s" % Assets.DOWNLOAD_PLUGIN)
	for m in ["externalPath", "start", "query", "remove", "requestNotifications", "notificationsAllowed", "lastError"]:
		check(java.contains("public ") and java.contains(" %s(" % m), "метод плагина %s" % m)
	check(manifest_xml.contains("org.godotengine.plugin.v2." + Assets.DOWNLOAD_PLUGIN)
		and manifest_xml.contains("com.lemonmen.myrappelz.download.DownloadPlugin"), "манифест плагина v2")
	check(manifest_xml.contains("android.permission.POST_NOTIFICATIONS"), "разрешение на уведомления (Android 13+)")
	var enabled: Variant = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())
	check(enabled is PackedStringArray and (enabled as PackedStringArray).has("res://addons/myrappelz_download/plugin.cfg"),
		"плагин редактора включён в project.godot")
	var gd := FileAccess.get_file_as_string("res://addons/myrappelz_download/plugin.gd")
	check(gd.contains("_get_android_libraries") and gd.contains("myrappelz_download-release.aar"),
		"плагин экспорта подключает AAR")


## Какие файлы в какой части: герои профессий — в части своей расы, стартовые эльфов — тоже, прежняя героиня —
## у тёмных эльфов, жители — npcs, стадии зверей — creatures, звери 1-й стадии — creatures_base, постройки, текстуры
## и овца — world, оружие — handheld, значки — icons; запасные герои и все .json — в APK; порядок загрузки частей.
func _check_files() -> void:
	check(Assets.part_of(Assets.PROBE) != "" and ResourceLoader.exists(Assets.PROBE), "файл-признак пакета — в пакете")
	for g in CharacterModel.FALLBACK_HEROES:
		var p := String(CharacterModel.FALLBACK_HEROES[g])
		check(ResourceLoader.exists(p) and not Assets.is_packed(p) and not Assets.is_packed(p.get_basename() + ".png"),
			"запасная модель «%s» — в APK" % p.get_file())
	check(Assets.part_of(CharacterModel.MAIN_ASSET) == "heroes_dark", "прежняя героиня — в части heroes_dark")
	for r in ClassData.RACES:
		var part := String(RACE_PART.get(r, ""))
		check(part != "", "раса %s — своя часть героев" % r)
		for g in ["f", "m"]:
			for j in ClassData.jobs_of(String(r)):
				var path := CharacterModel.HERO_ASSET_DIR + "hero_%s_%s.glb" % [j, g]
				check(Assets.part_of(path) == part and Assets.part_of(path.get_basename() + ".png") == part,
					"%s — в части %s (%s)" % [path.get_file(), part, Assets.part_of(path)])
			var starter := CharacterModel.HERO_ASSET_DIR + "hero_%s_%s_starter.glb" % [r, g]
			var want := "" if r == "human" else part
			check(Assets.part_of(starter) == want, "%s — %s" % [starter.get_file(), want if want != "" else "в APK"])
	var heroes := 0
	for f in _list("res://assets/characters/", ".glb"):
		var p: String = "res://assets/characters/" + String(f)
		var fallback := CharacterModel.FALLBACK_HEROES.values().has(p)
		check(Assets.is_packed(p) != fallback, "%s — %s" % [f, "в APK" if fallback else "в пакете"])
		check(Assets.part_of(p.get_basename() + ".png") == Assets.part_of(p), "%s: текстура в той же части" % f)
		check(not Assets.is_packed(p.get_basename() + ".json"), "%s: роли костей (.json) — в APK" % f)
		if String(f).begins_with("npc_"):
			check(Assets.part_of(p) == "npcs", "%s — в части npcs" % f)
		if not fallback:
			heroes += 1
	check(heroes >= 33, "в пакете моделей героев и жителей: %d" % heroes)
	for f in _list("res://assets/creatures/", ".glb"):
		var p: String = "res://assets/creatures/" + String(f)
		var stage: bool = String(f).ends_with("_2.glb") or String(f).ends_with("_3.glb")
		var want_part := "creatures" if stage else "creatures_base"
		if String(f) == "sheep.glb":
			want_part = "world"
		check(Assets.part_of(p) == want_part and Assets.part_of(p.get_basename() + ".png") == want_part,
			"%s — в части %s (%s)" % [f, want_part, Assets.part_of(p)])
	var dirs := {"res://assets/props/": "world|world_b", "res://assets/textures/": "world",
		"res://assets/handheld/": "handheld|handheld_r2",
		"res://assets/icons/items/": "icons", "res://assets/icons/skills/": "icons", "res://assets/icons/ui/": "icons",
		"res://assets/icons/pets/wolf/": "icons"}
	for d in dirs:
		var n := 0
		for ext in [".glb", ".png"]:
			for f in _list(String(d), String(ext)):
				var p: String = String(d) + String(f)
				check(String(dirs[d]).split("|").has(Assets.part_of(p)), "%s — в части %s (%s)" % [
					p.trim_prefix("res://"), dirs[d], Assets.part_of(p)])
				n += 1
		check(n > 0, "%s: файлов %d" % [d, n])
	for j in ["res://assets/creatures/creatures.json", "res://assets/props/props.json", "res://assets/handheld/handheld.json",
			"res://assets/characters/npc_kirk.json"]:
		check(not Assets.is_packed(String(j)) and FileAccess.file_exists(String(j)), "%s — в APK" % String(j).get_file())
	# Порядок загрузки: мир, значки, оружие, звери, затем остальные по порядку манифеста
	var order := Assets.load_ordered([{"name": "heroes_dark"}, {"name": "icons"}, {"name": "npcs"}, {"name": "world"},
		{"name": "creatures_base"}, {"name": "handheld"}, {"name": "art"}])
	check(_names(order) == ["world", "icons", "handheld", "creatures_base", "heroes_dark", "npcs", "art"],
		"порядок загрузки частей: %s" % str(_names(order)))
	for n in Assets.LOAD_ORDER:
		check(Assets.PACKS.has(n), "часть порядка загрузки %s есть в Assets.PACKS" % n)


## Часть подключена, другая нет: модели первой «есть», второй — нет; старый пакет целиком — все части.
func _check_partial() -> void:
	var was_embedded := Assets._embedded
	var was_loaded := Assets.loaded
	var hero := "res://assets/characters/hero_wizard_f.glb"
	var npc := "res://assets/characters/npc_kirk.glb"
	Assets._embedded = 0
	Assets.loaded = {}
	check(not Assets.available() and Assets.ready_count() == 0, "ничего не подключено — пакета нет")
	Assets.loaded = {"npcs": "user://x.pck"}
	check(Assets.part_ready("npcs") and not Assets.part_ready("heroes_light") and not Assets.available(),
		"подключена одна часть — готова только она")
	check(Assets.exists(npc) and not Assets.exists(hero), "модели подключённой части есть, другой — нет")
	check(Assets.exists("res://assets/characters/hero_human_m_starter.glb"), "файл APK есть всегда")
	check(Assets.ready_count() == 1, "готово частей: %d" % Assets.ready_count())
	Assets.loaded = {}
	for n in Assets.PACKS:
		Assets.loaded[n] = "user://x.pck"
	check(Assets.available() and Assets.exists(hero), "все части подключены — пакет готов")
	Assets.loaded = {Assets.ALL: "user://x.pck"}
	check(Assets.available() and Assets.exists(hero) and Assets.exists(npc), "старый пакет целиком — готовы все части")
	Assets._embedded = was_embedded
	Assets.loaded = was_loaded


func _check_manifest_parse() -> void:
	var good := {"format": 2, "version": "0.24.0", "parts": [
		{"name": "npcs", "hash": H3, "sha256": H1, "size": 10, "url": "https://x/a.pck", "file": "a.pck"},
		{"name": "creatures", "hash": H2, "sha256": H1, "size": 20, "url": "https://x/b.pck"}]}
	var m := Assets.parse_manifest(JSON.stringify(good))
	var parts := Assets.manifest_parts(m)
	check(parts.size() == 2 and String((parts[0] as Dictionary)["name"]) == "npcs" and int((parts[1] as Dictionary)["size"]) == 20
		and String(m.get("version", "")) == "0.24.0", "манифест с частями читается: %s" % str(m))
	var old := Assets.parse_manifest(JSON.stringify({"hash": H1, "sha256": H1, "size": 10, "url": "https://x/y.pck"}))
	parts = Assets.manifest_parts(old)
	check(parts.size() == 1 and String((parts[0] as Dictionary)["name"]) == Assets.ALL
		and String((parts[0] as Dictionary)["hash"]) == H1, "старый манифест — одна часть «all»")
	check(Assets.parse_manifest("не json").is_empty(), "не JSON — пусто")
	check(Assets.parse_manifest(JSON.stringify({"hash": H1, "sha256": "zz", "size": 10, "url": "https://x"})).is_empty(),
		"неверный sha256 — пусто")
	check(Assets.parse_manifest(JSON.stringify({"hash": H1, "sha256": H1, "size": 0, "url": "https://x"})).is_empty(),
		"нулевой размер — пусто")
	var dup := good.duplicate(true)
	var dp := _part_of(dup, 1)
	dp["name"] = "npcs"
	check(Assets.parse_manifest(JSON.stringify(dup)).is_empty(), "часть дважды — пусто")
	var bad_name := good.duplicate(true)
	var np := _part_of(bad_name, 0)
	np["name"] = "heroes-1"
	check(Assets.parse_manifest(JSON.stringify(bad_name)).is_empty(), "неверное имя части — пусто")
	var bad_part := good.duplicate(true)
	var bp := _part_of(bad_part, 1)
	bp["size"] = "много"
	check(Assets.parse_manifest(JSON.stringify(bad_part)).is_empty(), "битая часть — весь манифест пуст")
	check(Assets.parse_manifest("{\"parts\": []}").is_empty() and Assets.parse_manifest("{\"parts\": 5}").is_empty(),
		"без частей — пусто")
	check(Assets.manifest_url("0.17.0")
		== "https://github.com/lemonmen72-svg/MyRappelz/releases/download/v0.17.0/assets-manifest.json",
		"адрес манифеста в релизе версии")
	check(Assets.pack_path("npcs", H1).ends_with("/assets-npcs-" + H1 + ".pck")
		and Assets.part_path("npcs", H1).ends_with("/assets-npcs-" + H1 + ".pck.part"), "имена файлов кэша части")
	check(Assets.pack_path(Assets.ALL, H1).ends_with("/assets-" + H1 + ".pck"), "старый пакет — прежнее имя файла")
	check(Assets.download_rel_path("npcs", H3) == "packs/assets-npcs-" + H3 + ".pck.download", "файл загрузки части")
	var c1 := Assets.parse_cache_name("assets-heroes_dark-" + H3 + ".pck")
	check(String(c1.get("part", "")) == "heroes_dark" and String(c1.get("hash", "")) == H3 and not bool(c1.get("temp", true)),
		"имя файла части разбирается: %s" % str(c1))
	var c2 := Assets.parse_cache_name("assets-npcs-" + H3 + ".pck.part")
	check(String(c2.get("part", "")) == "npcs" and bool(c2.get("temp", false)), "недокачанный файл части")
	var c3 := Assets.parse_cache_name("assets-" + H3 + ".pck")
	check(String(c3.get("part", "")) == Assets.ALL and String(c3.get("hash", "")) == H3, "старый пакет целиком")
	check(Assets.parse_cache_name("download.cfg").is_empty() and Assets.parse_cache_name("assets-x.txt").is_empty(),
		"чужие файлы — не части")


## Без пакета: герой — запасная модель своего пола, звери старших стадий — модель 1-й стадии; с пакетом — как раньше.
func _check_fallback() -> void:
	Assets.simulate_missing(true)
	check(not Assets.available() and not Assets.exists(Assets.PROBE), "без пакета модели пакета «нет»")
	var bad: Array = []
	for r in ClassData.RACES:
		for g in ["f", "m"]:
			var jobs: Array = [ClassData.WANDERER]
			jobs.append_array(ClassData.jobs_of(String(r)))
			for j in jobs:
				var path := CharacterModel.hero_asset(String(r), g, String(j))
				var spec := CharacterModel.spec_for(String(r), String(j), "", g)
				if path != CharacterModel.FALLBACK_HEROES[g] or String(spec.get("asset", "")) != path:
					bad.append("%s/%s/%s → %s" % [r, g, j, path])
	check(bad.is_empty(), "без пакета все герои — запасная модель пола (%s)" % str(bad))
	for sp in STAGED:
		# звери 1-й стадии теперь тоже в пакете (creatures_base): без пакета — модель из примитивов, стадии — та же
		check(CreatureAsset.model_for(sp, 1) == sp and CreatureAsset.model_for(sp, 2) == sp and not CreatureAsset.has_asset(sp),
			"%s: без пакета старшие стадии — модель 1-й стадии (из примитивов)" % sp)
	var m := CharacterModel.new()
	m.setup(CharacterModel.spec_for("dark_elf", "assassin", "", "m"))
	main.add_child(m)
	check(m._asset != null, "запасная модель из файла строится")
	m.queue_free()
	Assets.simulate_missing(false)
	check(CharacterModel.hero_asset("light_elf", "m", "wizard") == CharacterModel.HERO_ASSET_DIR + "hero_wizard_m.glb",
		"с пакетом — модель профессии")
	check(CreatureAsset.model_for("wolf", 1) == "wolf_2", "с пакетом — модель стадии")
	check(main.player != null and String(main.player._model.spec.get("asset", "")).ends_with("hero_wizard_f.glb"),
		"герой в мире — на своей модели")


## Настоящие .pck (PCKPacker) — по одному на часть PA, PB, PC, с одним файлом PROBE_DIR + <часть>.txt;
## их sha256 и размер; проверка по кускам.
func _prepare_packs() -> void:
	Assets.packs_dir = TEST_DIR
	_clear_dir()
	Assets.ensure_dir()
	DirAccess.make_dir_recursive_absolute(SRC_DIR)
	for pname in [PA, PB, PC]:
		var src := SRC_DIR + String(pname) + ".txt"
		var out := SRC_DIR + String(pname) + ".pck"
		var f := FileAccess.open(src, FileAccess.WRITE)
		f.store_string(String(pname))
		f = null
		var pk := PCKPacker.new()
		check(pk.pck_start(out) == OK, "тестовый .pck части %s создаётся" % pname)
		pk.add_file(PROBE_DIR + String(pname) + ".txt", src)
		pk.flush()
		var data := FileAccess.get_file_as_bytes(out)
		packs[pname] = {"bytes": data, "sha": Assets.file_sha256(out), "size": data.size()}
	var good: PackedByteArray = _bytes(PA)
	var sha := String(packs[PA]["sha"])
	check(sha.length() == 64 and good.size() > 0, "sha256 тестового пакета")
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(good)
	check(ctx.finish().hex_encode() == sha, "sha256 по частям = sha256 целиком")
	var path := SRC_DIR + PA + ".pck"
	var v := Assets.Verifier.new(path, sha, good.size())
	while not v.step(7):
		pass
	check(v.ok and v.progress() == 1.0, "проверка мелкими кусками проходит")
	v = Assets.Verifier.new(path, sha, good.size() + 1)
	check(v.done and not v.ok and v.error.contains("размер"), "другой размер — ошибка")
	v = Assets.Verifier.new(path, H1, good.size())
	v.step(1 << 20)
	check(v.done and not v.ok, "другая контрольная сумма — ошибка")
	Assets.simulate_missing(true)


## Часть манифеста теста (Assets.manifest_from: name, hash, sha256, size, url, file).
func _part(pname: String, h: String) -> Dictionary:
	return {"name": pname, "hash": h, "sha256": String(packs[pname]["sha"]), "size": int(packs[pname]["size"]),
		"url": "https://example.invalid/%s-%s.pck" % [pname, h], "file": "%s.pck" % pname}


## Часть «мир» (файл — тестовый .pck части PC, хэш H3).
func _world_part() -> Dictionary:
	var w := _part(PC, H3)
	w["name"] = PW
	w["url"] = "https://example.invalid/world-%s.pck" % H3
	return w


func _man(parts: Array) -> Dictionary:
	return Assets.manifest_from({"version": "test", "parts": parts})


func _bytes(pname: String) -> PackedByteArray:
	return packs[pname]["bytes"]


func _size(pname: String) -> int:
	return int(packs[pname]["size"])


## Тот же размер, один байт в середине другой (sha256 не совпадёт).
func _broken(data: PackedByteArray) -> PackedByteArray:
	var bad := data.duplicate()
	var mid := bad.size() >> 1
	bad[mid] = (bad[mid] + 1) % 256
	return bad


func _names(parts: Array) -> Array:
	var out: Array = []
	for p in parts:
		out.append(String((p as Dictionary)["name"]))
	return out


func _job_id(pname: String) -> String:
	return String((loader.jobs.get(pname, {}) as Dictionary).get("id", ""))


## Часть i словаря манифеста (для порчи в тесте разбора).
func _part_of(m: Dictionary, i: int) -> Dictionary:
	var list: Array = m["parts"]
	return list[i]


## Ответ сервера на запрос манифеста (тело, код).
func _net_manifest(body: String, code: int) -> void:
	loader.state = AssetLoader.State.MANIFEST
	loader._on_manifest_completed(HTTPRequest.RESULT_SUCCESS, code, PackedStringArray(), body.to_utf8_buffer())


func _cache_count() -> int:
	var n := 0
	var d := DirAccess.open(TEST_DIR)
	if d == null:
		return 0
	for f in d.get_files():
		if f.begins_with(Assets.PACK_PREFIX):
			n += 1
	return n


func _new_loader(m: Dictionary) -> void:
	results.clear()
	loader = AssetLoader.new()
	loader.preset_manifest = m
	loader.offline = true
	loader.finished.connect(func(with_pack: bool) -> void: results.append(with_pack))
	main.add_child(loader)


func _cleanup() -> void:
	Assets.simulate_missing(false)
	Assets.skipped = false
	Assets.plugin_override = null
	Assets.clear_jobs()
	Assets.loaded = {}
	Assets.loaded_files = []
	_clear_dir()
	for d in [FakeDownloads.DIR + Assets.DOWNLOAD_DIR, FakeDownloads.DIR, SRC_DIR]:
		var da := DirAccess.open(String(d))
		if da != null:
			for f in da.get_files():
				DirAccess.remove_absolute(String(d) + f)
			DirAccess.remove_absolute(String(d).trim_suffix("/"))
	Assets.packs_dir = "user://packs/"


func _clear_dir() -> void:
	var d := DirAccess.open(TEST_DIR)
	if d == null:
		return
	for f in d.get_files():
		DirAccess.remove_absolute(TEST_DIR + f)


func _write(path: String, data: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(data)


func _list(dir: String, ext: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(ext):
			out.append(f)
	out.sort()
	return out


func _split(s: String) -> Array:
	var out: Array = []
	for part in s.split(","):
		var t := part.strip_edges()
		if t != "":
			out.append(t)
	return out
