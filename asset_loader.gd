class_name AssetLoader
extends CanvasLayer
## Экран «Загрузка ресурсов»: до создания персонажа и входа в мир подключает пакет ресурсов (Assets) — модели
## героев профессий, жителей и стадий эволюции зверей, которых нет в APK. Пакет — несколько частей (Assets.PACKS),
## у каждой свой хэш и файл в кэше: после обновления игры загружаются только изменившиеся части.
## Порядок: манифест (из APK res://assets_pack.json, иначе assets-manifest.json из релиза версии игры; старый формат
## «один пакет» — одна часть) → части этих хэшей, что уже есть в кэше user://packs, не загружаются; все есть — сразу
## подключить; иначе предупреждение «Будет загружено N МБ» (сумма недостающих частей; на мобильной сети — лучше
## Wi-Fi) → загрузка частей по очереди HTTPRequest.download_file во временный файл assets-<часть>-<хэш>.pck.part
## (МБ из МБ всех частей, скорость, сколько осталось) → проверка размера и sha256 каждой части по кускам →
## переименование в assets-<часть>-<хэш>.pck, прежние версии этой части удаляются → следующая часть → все на месте:
## остальное из кэша удаляется (Assets.remove_stale), каждая часть — ProjectSettings.load_resource_pack.
## Обрыв, ошибка сети, битый файл — сообщение и «Повторить» (загрузка заново, но только недостающих частей: уже
## проверенные лежат в кэше). «Играть без загрузки» — подключить части, что есть в кэше (Assets.load_cached: этой
## версии, прежней, старый пакет целиком); остальные модели — запасные.
## Сигнал finished(with_pack) — можно продолжать (main.gd). Если ресурсы уже есть (Assets.available()),
## экран не нужен — main.gd его не создаёт.
## Фоновая загрузка (Android, плагин MyRappelzDownload — Assets.download_plugin()): «Загрузить» отдаёт системному
## DownloadManager все недостающие части сразу (файлы — во внешнюю папку приложения, уведомление «Dark Pact —
## загрузка ресурсов» с ходом загрузки у каждой, на Android 13+ при первом нажатии спрашивается разрешение на
## уведомления), игру можно свернуть или закрыть — качает Android. Экран опрашивает загрузки (_poll_dm раз в
## POLL_TIME): МБ из МБ всех частей, скорость, ожидание сети; часть готова — проверка sha256 с копированием в
## assets-<часть>-<хэш>.pck.part (Verifier copy_to), установка в кэш, дальше ждём остальные; ошибка или отмена любой
## части в уведомлении — остальные загрузки убираются, сообщение и «Повторить». Записи о загрузках (Assets.read_jobs)
## переживают перезапуск: при следующем запуске экран сразу продолжает следить за ними (без вопроса о размере).
## «Играть без загрузки» во время такой загрузки её не останавливает: невидимый фоновый AssetLoader (background)
## у корня дерева следит дальше, по окончании проверяет файлы и кладёт части в кэш, сообщение — в HUD; части
## подключаются при следующем входе в мир («Сменить персонажа» или запуск игры) — посреди игры не подключаются:
## готовые модели остались бы запасными, а новые — нет.
## Нет плагина или DownloadManager не принял загрузку — загрузка HTTPRequest (игру не сворачивать).
## Тест (tests/test_asset_pack.gd): preset_manifest — манифест без файла и сети (формат Assets.manifest_from);
## offline — загрузка не идёт в сеть (тест сам кладёт временный файл части current и зовёт _on_download_completed);
## Assets.plugin_override — подставной плагин.

signal finished(with_pack: bool)

enum State { START, MANIFEST, CONFIRM, DOWNLOAD, VERIFY, ERROR, DONE }

const GOLD := Color(0.95, 0.8, 0.4)
const MUTED := Color(0.75, 0.77, 0.83)
## Нет новых байтов столько секунд — загрузка считается оборванной.
const STALL_TIME := 30.0
## Сколько байт проверять за кадр.
const VERIFY_STEP := 8 << 20
const MANIFEST_TIMEOUT := 20.0
## Запас места сверх размера пакета.
const SPACE_MARGIN := 1.1
## Опрос загрузки DownloadManager, с.
const POLL_TIME := 0.5
## Сколько байт проверять за кадр в фоне (идёт игра — понемногу).
const VERIFY_STEP_BG := 2 << 20
## Фоновый узел ждёт HUD для сообщения не дольше, с.
const NOTE_WAIT := 600.0
## DownloadManager.STATUS_*.
const DM_PENDING := 1
const DM_RUNNING := 2
const DM_PAUSED := 4
const DM_SUCCESS := 8
const DM_FAILED := 16
## Уведомление системы о загрузке.
const NOTIFY_TITLE := "Dark Pact — загрузка ресурсов"
const NOTIFY_TEXT := "Пакет моделей, часть %d из %d, %s"
## Высота логотипа Dark Pact над окном загрузки («Средний»).
const LOGO_H := 140.0

var state := State.START
## Манифест: {version, parts: [{name, hash, sha256, size, url, file}]} (Assets.manifest_from).
var manifest: Dictionary = {}
var preset_manifest: Dictionary = {}
var offline := false
## Части загружались в этом запуске (не только из кэша).
var downloaded := false
## Текст последней ошибки.
var error_text := ""
## Кнопки для тестов: "main" (Загрузить / Повторить), "skip" (Играть без загрузки).
var buttons: Dictionary = {}
## Фоновый режим: экрана нет, загрузка DownloadManager продолжается после «Играть без загрузки».
var background := false
## Сообщение фонового режима (показывается в HUD; тесты).
var note_text := ""
## Опрос DownloadManager, с (тест ставит 0 или зовёт _poll_dm сам).
var poll_time := POLL_TIME
## Части манифеста, которых нет в кэше (ещё загрузить), по порядку манифеста.
var todo: Array = []
## Сколько байт у недостающих частей всего и сколько из них уже проверено и лежит в кэше.
var total_bytes := 0
var done_bytes := 0
## Загрузка HTTPRequest: часть, которая грузится сейчас ({} — нет).
var current: Dictionary = {}
## Загрузки DownloadManager: имя части → {id, path, hash, size, bytes} (пусто — загрузка HTTPRequest или нет её).
var jobs: Dictionary = {}

var _title: Label
var _text: Label
var _bar: ProgressBar
var _detail: Label
var _main_btn: Button
var _skip_btn: Button
var _http_manifest: HTTPRequest
var _http: HTTPRequest
var _verifier: Assets.Verifier
## Часть, которую проверяет _verifier, и пришла ли она от DownloadManager (проверка с копированием в кэш).
var _vpart: Dictionary = {}
var _v_dm := false
## Сколько частей было в очереди при «Загрузить» (подпись «Часть N из M»).
var _count := 0
var _last_bytes := 0
var _stall := 0.0
## Замеры для скорости: [время с, байт].
var _samples: Array = []
var _clock := 0.0
## Плагин фоновой загрузки (null — HTTPRequest).
var _dm: Object = null
var _poll := 0.0
var _note_left := 0.0


func _ready() -> void:
	layer = 50
	visible = not background
	_dm = Assets.download_plugin()
	_build_ui()
	_http_manifest = HTTPRequest.new()
	_http_manifest.timeout = MANIFEST_TIMEOUT
	_http_manifest.request_completed.connect(_on_manifest_completed)
	add_child(_http_manifest)
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.download_chunk_size = 1 << 18
	_http.request_completed.connect(_on_download_completed)
	add_child(_http)
	begin()


## Начать сначала (и «Повторить»).
func begin() -> void:
	error_text = ""
	# Фоновый узел доводит загрузку до конца, даже если подключены прежние версии частей.
	if Assets.available() and not background:
		_finish(true)
		return
	manifest = preset_manifest if not preset_manifest.is_empty() else Assets.read_embedded_manifest()
	if not manifest.is_empty():
		_have_manifest()
		return
	var url := Assets.manifest_url()
	if url == "":
		_fail("Не удалось узнать версию игры, пакет ресурсов не найден.")
		return
	if offline:
		_fail("Нет соединения с сетью.")
		return
	_set_state(State.MANIFEST)
	_http_manifest.cancel_request()
	if _http_manifest.request(url) != OK:
		_fail("Не удалось обратиться к серверу загрузки.")


func _on_manifest_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if state != State.MANIFEST:
		return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail("Не удалось получить сведения о пакете ресурсов (%s)." % _net_error(result, code))
		return
	manifest = Assets.parse_manifest(body.get_string_from_utf8())
	if manifest.is_empty():
		_fail("Сведения о пакете ресурсов повреждены.")
		return
	_have_manifest()


## Манифест есть: какие части уже в кэше; все — подключить, иначе продолжить фоновую загрузку или спросить.
func _have_manifest() -> void:
	todo = Assets.missing_parts(manifest)
	total_bytes = Assets.parts_size(todo)
	done_bytes = 0
	_count = todo.size()
	if todo.is_empty():
		_drop_jobs()
		_complete()
		return
	if _resume_jobs():
		return
	if background:
		_bg_end("")
		return
	_set_state(State.CONFIRM)


## «Загрузить»: место на диске, временные файлы, загрузка недостающих частей.
func start_download() -> void:
	if manifest.is_empty() or todo.is_empty():
		begin()
		return
	Assets.ensure_dir()
	var need := Assets.parts_size(todo)
	# Через DownloadManager файл сначала ложится во внешнюю папку приложения и копируется в кэш — нужно две копии.
	var want := int(float(need) * (SPACE_MARGIN + (1.0 if _dm != null else 0.0)))
	var d := DirAccess.open(Assets.packs_dir)
	if d != null:
		var left := int(d.get_space_left())
		if left > 0 and left < want:
			# Не хватает — сначала убрать прежние версии частей и старый пакет целиком (обновление с 0.23).
			if left + Assets.stale_size(manifest) >= want:
				Assets.remove_stale(manifest)
			else:
				_fail("Недостаточно места: нужно %s, свободно %s." % [_mb(want), _mb(left)])
				return
	for p in todo:
		Assets.remove_file(Assets.part_path_of(p))
	downloaded = true
	total_bytes = need
	done_bytes = 0
	_count = todo.size()
	_samples.clear()
	if _dm != null and _start_dm():
		return
	_next_http()


## HTTPRequest: следующая недостающая часть (по одной); все в кэше — подключение.
func _next_http() -> void:
	if todo.is_empty():
		current = {}
		_complete()
		return
	current = todo[0]
	_last_bytes = 0
	_stall = 0.0
	_set_state(State.DOWNLOAD)
	if offline:
		return
	_http.cancel_request()
	_http.download_file = Assets.part_path_of(current)
	if _http.request(String(current["url"])) != OK:
		_fail("Не удалось начать загрузку.")


func _on_download_completed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if state != State.DOWNLOAD or not jobs.is_empty() or current.is_empty():
		return
	var part := Assets.part_path_of(current)
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		Assets.remove_file(part)
		_fail("Загрузка прервалась (%s)." % _net_error(result, code))
		return
	_begin_verify(current, part, "")


## Проверка размера и sha256 файла части src; copy_to — заодно копировать во временный файл кэша (DownloadManager).
func _begin_verify(p: Dictionary, src: String, copy_to: String) -> void:
	_vpart = p
	_v_dm = copy_to != ""
	_verifier = Assets.Verifier.new(src, String(p["sha256"]), int(p["size"]), copy_to)
	_set_state(State.VERIFY)


## Загрузка через DownloadManager: прежние загрузки убираются, все недостающие части отдаются сразу, записи —
## Assets.save_jobs. false — плагин не смог (нет внешней памяти, DownloadManager выключен) — тогда HTTPRequest.
func _start_dm() -> bool:
	_drop_jobs()
	if not _start_dm_parts():
		return false
	# Android 13+: без разрешения система не покажет уведомление с ходом загрузки (качать будет и без него).
	_dm.call("requestNotifications")
	_poll = 0.0
	_set_state(State.DOWNLOAD)
	return true


## Отдать DownloadManager части из todo, у которых ещё нет загрузки. false — не вышло (всё убрано).
func _start_dm_parts() -> bool:
	var i := 0
	for p in todo:
		i += 1
		var pname := String(p["name"])
		if jobs.has(pname):
			continue
		var h := String(p["hash"])
		var rel := Assets.download_rel_path(pname, h)
		var path := String(_dm.call("externalPath", rel))
		var id := ""
		if path != "":
			id = String(_dm.call("start", String(p["url"]), rel, NOTIFY_TITLE,
				NOTIFY_TEXT % [i, todo.size(), _mb(int(p["size"]))]))
			if id == "":
				push_warning("DownloadManager: %s — загрузка через HTTPRequest" % String(_dm.call("lastError")))
		if id == "":
			_drop_jobs()
			return false
		jobs[pname] = {"id": id, "path": path, "hash": h, "size": int(p["size"]), "bytes": 0}
	_save_jobs()
	return true


## Загрузки DownloadManager частей уже идут или закончились (игру свернули или закрыли, «Играть без загрузки»):
## следить за ними без вопроса о размере. Загрузка другого хэша, неудачная или отменённая убирается; части без
## загрузки отдаются заново. true — продолжаем; false — загрузок нет (записи убраны).
func _resume_jobs() -> bool:
	var saved := Assets.read_jobs()
	if saved.is_empty():
		return false
	if _dm == null:
		_drop_jobs(saved)
		return false
	var by_name := {}
	for p in todo:
		by_name[String(p["name"])] = p
	var alive := {}
	for pname in saved:
		var j: Dictionary = saved[pname]
		var p: Dictionary = by_name.get(pname, {})
		var good := not p.is_empty() and String(j["hash"]) == String(p["hash"]) and String(j["path"]) != ""
		if good:
			var info := _dm_query(String(j["id"]))
			if info.has("error"):
				info = {"found": true, "status": DM_PENDING}
			good = bool(info.get("found", false)) and int(info.get("status", 0)) != DM_FAILED
		if good:
			alive[pname] = {"id": String(j["id"]), "path": String(j["path"]), "hash": String(j["hash"]),
				"size": int(p["size"]), "bytes": 0}
		else:
			_remove_download(j)
	if alive.is_empty():
		Assets.clear_jobs()
		return false
	jobs = alive
	if not _start_dm_parts():
		return false
	downloaded = true
	total_bytes = Assets.parts_size(todo)
	done_bytes = 0
	_count = todo.size()
	_samples.clear()
	_poll = 0.0
	_set_state(State.DOWNLOAD)
	_poll_dm()
	return true


## Убрать загрузку DownloadManager (идущая останавливается) и её файл.
func _remove_download(j: Dictionary) -> void:
	if _dm != null:
		_dm.call("remove", String(j.get("id", "")))
	Assets.remove_file(String(j.get("path", "")))


## Убрать все загрузки DownloadManager (свои и записанные; или переданные) и записи о них.
func _drop_jobs(saved: Dictionary = {}) -> void:
	var all: Dictionary = saved if not saved.is_empty() else Assets.read_jobs()
	for pname in jobs:
		all[pname] = jobs[pname]
	for pname in all:
		_remove_download(all[pname] as Dictionary)
	jobs.clear()
	Assets.clear_jobs()


## Убрать одну загрузку (часть проверена или битая) и переписать записи.
func _drop_job(pname: String) -> void:
	if not jobs.has(pname):
		return
	_remove_download(jobs[pname] as Dictionary)
	jobs.erase(pname)
	_save_jobs()


func _save_jobs() -> void:
	Assets.save_jobs(jobs)


func _dm_query(id: String) -> Dictionary:
	if _dm == null or id == "":
		return {}
	var r: Variant = _dm.call("query", id)
	if r is Dictionary:
		return r
	return {}


## Опрос DownloadManager: ход загрузки всех частей, ожидание сети, готово (проверка по одной), ошибка, отмена
## (в уведомлении или «Загрузках»).
func _poll_dm() -> void:
	if state != State.DOWNLOAD or jobs.is_empty():
		return
	var got := 0
	var ready_part := ""
	var ready_info: Dictionary = {}
	var paused := -1
	var running := false
	for pname in jobs.keys():
		var j: Dictionary = jobs[pname]
		var info := _dm_query(String(j["id"]))
		if info.has("error"):
			got += int(j["bytes"])
			running = true
			continue
		if not bool(info.get("found", false)):
			_fail("Загрузка отменена.")
			return
		var size := int(j["size"])
		match int(info.get("status", 0)):
			DM_SUCCESS:
				j["bytes"] = size
				if ready_part == "":
					ready_part = String(pname)
					ready_info = info
			DM_FAILED:
				_fail("Загрузка прервалась (%s)." % _dm_reason(int(info.get("reason", 0))))
				return
			DM_PAUSED:
				j["bytes"] = clampi(int(info.get("bytes", 0)), 0, size)
				if paused < 0:
					paused = int(info.get("reason", 0))
			DM_RUNNING:
				j["bytes"] = clampi(int(info.get("bytes", 0)), 0, size)
				running = true
			_:
				j["bytes"] = clampi(int(info.get("bytes", 0)), 0, size)
		got += int(j["bytes"])
	if ready_part != "":
		_dm_finished(ready_part, ready_info)
		return
	got += done_bytes
	if paused >= 0 and not running:
		_samples.clear()
		_bar.value = 100.0 * float(got) / float(maxi(total_bytes, 1))
		_detail.text = "%s из %s · %s" % [_mb(got), _mb(total_bytes), _dm_pause_text(paused)]
		return
	_show_progress(got, total_bytes)


## Часть загружена: проверка sha256 с копированием во временный файл кэша (дальше — как у HTTPRequest).
## Файл — где его записал DownloadManager (uri), обычно это и есть путь из записи о загрузке.
func _dm_finished(pname: String, info: Dictionary) -> void:
	var j: Dictionary = jobs[pname]
	var uri := String(info.get("uri", ""))
	if uri.begins_with("file://"):
		var real := uri.trim_prefix("file://").uri_decode()
		if real != String(j["path"]) and FileAccess.file_exists(real):
			j["path"] = real
	var p: Dictionary = {}
	for t in todo:
		if String(t["name"]) == pname:
			p = t
	if p.is_empty():
		_drop_job(pname)
		return
	var part := Assets.part_path_of(p)
	Assets.ensure_dir()
	Assets.remove_file(part)
	_begin_verify(p, String(j["path"]), part)


func _process(delta: float) -> void:
	_clock += delta
	match state:
		State.DOWNLOAD:
			_update_download(delta)
		State.VERIFY:
			_update_verify()
		State.DONE:
			if background and note_text != "":
				_note_left -= delta
				if _show_note() or _note_left <= 0.0:
					note_text = ""
					queue_free()


func _update_download(delta: float) -> void:
	if not jobs.is_empty():
		_poll += delta
		if _poll >= poll_time:
			_poll = 0.0
			_poll_dm()
		return
	if offline or current.is_empty():
		return
	var got := _http.get_downloaded_bytes()
	if got != _last_bytes:
		_last_bytes = got
		_stall = 0.0
	else:
		_stall += delta
		if _stall > STALL_TIME:
			_http.cancel_request()
			Assets.remove_file(Assets.part_path_of(current))
			_fail("Нет данных %d с — соединение прервано." % int(STALL_TIME))
			return
	_show_progress(done_bytes + mini(got, int(current["size"])), total_bytes)


## Полоса и строка «МБ из МБ · скорость · осталось» (скорость — по замерам за 3 с).
func _show_progress(got: int, total: int) -> void:
	_samples.append([_clock, got])
	while _samples.size() > 2 and _clock - float(_samples[0][0]) > 3.0:
		_samples.pop_front()
	var speed := 0.0
	var dt := _clock - float(_samples[0][0])
	if dt > 0.2:
		speed = float(got - int(_samples[0][1])) / dt
	_bar.value = 100.0 * float(got) / float(maxi(total, 1))
	var line := "%s из %s" % [_mb(got), _mb(total)]
	if speed > 0.0:
		line += " · %s/с" % _mb(int(speed))
		var left := float(total - got) / speed
		line += " · осталось %s" % _time_text(left)
	_detail.text = line


func _update_verify() -> void:
	if _verifier == null:
		return
	_verifier.step(VERIFY_STEP_BG if background else VERIFY_STEP)
	_bar.value = 100.0 * _verifier.progress()
	if not _verifier.done:
		return
	var p := _vpart
	var pname := String(p["name"])
	var h := String(p["hash"])
	var from_dm := _v_dm
	_vpart = {}
	_v_dm = false
	if from_dm:
		# Файл DownloadManager больше не нужен: скопирован в кэш или битый (загрузка — заново).
		_drop_job(pname)
	if not _verifier.ok:
		var why := _verifier.error
		_verifier = null
		Assets.remove_file(Assets.part_path(pname, h))
		_fail("Файл пакета повреждён (%s). Попробуйте загрузить ещё раз." % why)
		return
	_verifier = null
	var path := Assets.install(pname, h)
	if path == "":
		Assets.remove_file(Assets.part_path(pname, h))
		_fail("Не удалось сохранить пакет ресурсов.")
		return
	done_bytes += int(p["size"])
	for i in range(todo.size() - 1, -1, -1):
		if String((todo[i] as Dictionary)["name"]) == pname:
			todo.remove_at(i)
	if not from_dm:
		_next_http()
		return
	if todo.is_empty():
		_complete()
		return
	if jobs.is_empty():
		_fail("Загрузка прервалась.")
		return
	_set_state(State.DOWNLOAD)
	_poll_dm()


## Все части манифеста в кэше: остальное из кэша удаляется, части подключаются. В фоне — не подключаются посреди
## игры (при следующем входе в мир main.gd покажет экран, он возьмёт части из кэша).
func _complete() -> void:
	current = {}
	Assets.remove_stale(manifest)
	var parts := Assets.manifest_parts(manifest)
	if background:
		# Подключена прежняя версия части — её файлы не заменить, новая подключится при следующем запуске.
		var clash := false
		for p in parts:
			if Assets.clashes(p):
				clash = true
		if not clash:
			Assets.skipped = false
			_bg_end("Пакет ресурсов загружен. Новые модели героев и зверей появятся при следующем входе в мир "
				+ "(«Настройки» → «Сменить персонажа») или запуске игры.")
		else:
			_bg_end("Пакет ресурсов загружен. Новые модели появятся при следующем запуске игры.")
		return
	for p in parts:
		var path := Assets.cached_pack(p)
		if not Assets.load_part(String(p["name"]), path):
			Assets.remove_file(path)
			_fail("Пакет ресурсов не открывается — он будет загружен заново.")
			return
	_finish(true)


## «Играть без загрузки»: загрузка HTTPRequest останавливается; загрузки DownloadManager идут дальше — за ними
## следит фоновый AssetLoader у корня дерева. Части, что есть в кэше (и прежних версий), подключаются.
func skip() -> void:
	if state == State.DONE:
		return
	if state == State.DOWNLOAD and not jobs.is_empty():
		# Записи о загрузках остаются в файле — фоновый узел подхватит их (_resume_jobs).
		jobs.clear()
		var bg := AssetLoader.new()
		bg.background = true
		bg.preset_manifest = manifest
		bg.offline = offline
		get_tree().root.add_child.call_deferred(bg)
	else:
		_http.cancel_request()
		_http_manifest.cancel_request()
		_verifier = null
		if not current.is_empty():
			Assets.remove_file(Assets.part_path_of(current))
		if not _vpart.is_empty():
			Assets.remove_file(Assets.part_path_of(_vpart))
		current = {}
		_vpart = {}
	Assets.skipped = true
	_finish(Assets.load_cached(manifest))


func _on_main_pressed() -> void:
	match state:
		State.CONFIRM:
			start_download()
		State.ERROR:
			begin()


## Ошибка: загрузки DownloadManager убираются (проверенные части остаются в кэше), «Повторить».
func _fail(text: String) -> void:
	error_text = text
	if not jobs.is_empty():
		_drop_jobs()
	current = {}
	if background:
		_bg_end("Пакет ресурсов не загружен: %s Загрузить его можно при следующем запуске игры." % text)
		return
	_set_state(State.ERROR)


func _finish(with_pack: bool) -> void:
	if state == State.DONE:
		return
	_set_state(State.DONE)
	call_deferred("_emit_finished", with_pack)


func _emit_finished(with_pack: bool) -> void:
	finished.emit(with_pack)
	if background:
		queue_free()


## Фоновый режим окончен: сообщение в HUD (когда он появится) и узел удаляется; "" — без сообщения.
func _bg_end(text: String) -> void:
	_set_state(State.DONE)
	note_text = text
	_note_left = NOTE_WAIT
	if text == "":
		queue_free()


## Показать сообщение фонового режима в HUD главной сцены (мир). true — показано.
func _show_note() -> bool:
	for n in get_tree().root.get_children():
		var hud: Variant = n.get("hud")
		if hud is Object and is_instance_valid(hud) and (hud as Object).has_method("show_message"):
			(hud as Object).call("show_message", note_text, 8.0)
			return true
	return false


## Почему пауза (DownloadManager.PAUSED_*).
static func _dm_pause_text(reason: int) -> String:
	match reason:
		1:
			return "повтор через несколько секунд"
		2:
			return "ожидание сети"
		3:
			return "ожидание Wi-Fi"
	return "пауза"


## Почему ошибка (DownloadManager.ERROR_* или код ответа сервера).
static func _dm_reason(reason: int) -> String:
	match reason:
		1001:
			return "ошибка записи файла"
		1002:
			return "неожиданный ответ сервера"
		1004, 1008:
			return "соединение прервано"
		1005:
			return "слишком много перенаправлений"
		1006:
			return "недостаточно места"
		1007:
			return "нет доступа к памяти"
	if reason >= 400 and reason < 600:
		return "сервер ответил %d" % reason
	return "ошибка %d" % reason


# ---------- Вид ----------

func _set_state(s: State) -> void:
	state = s
	if _text == null:
		return
	var size_mb := _mb(total_bytes)
	_bar.visible = s == State.DOWNLOAD or s == State.VERIFY
	_detail.text = ""
	_main_btn.visible = s == State.CONFIRM or s == State.ERROR
	_skip_btn.visible = s != State.DONE and s != State.VERIFY
	_skip_btn.text = "Играть, пока грузится" if s == State.DOWNLOAD and not jobs.is_empty() else "Играть без загрузки"
	_title.text = "Загрузка ресурсов"
	match s:
		State.START, State.MANIFEST:
			_text.text = "Получаем сведения о пакете ресурсов…"
		State.CONFIRM:
			_text.text = ("Для героев всех профессий, жителей и старших стадий питомцев нужен пакет ресурсов.\n"
				+ "Будет загружено %s%s. Загрузка нужна один раз: пакет сохранится в памяти игры, после обновлений "
				+ "загружаются только изменившиеся части.\n"
				+ "На мобильной сети за трафик может взиматься плата — лучше подключиться к Wi-Fi.") % [size_mb, _parts_note()]
			_main_btn.text = "Загрузить (%s)" % size_mb
		State.DOWNLOAD:
			if not jobs.is_empty():
				_text.text = ("Загружается пакет ресурсов (%s). Игру можно свернуть — загрузка продолжится, "
					+ "её ход виден в уведомлениях.\nМожно играть и сейчас, на запасных моделях: пакет загрузится "
					+ "в фоне и подключится при следующем входе в мир.") % size_mb
			else:
				_text.text = "Загружается пакет ресурсов (%s). Не закрывайте игру." % size_mb
				if _count > 1:
					_text.text += "\nЧасть %d из %d." % [clampi(_count - todo.size() + 1, 1, _count), _count]
			_bar.value = 100.0 * float(done_bytes) / float(maxi(total_bytes, 1))
			_detail.text = "%s из %s" % [_mb(done_bytes), size_mb]
		State.VERIFY:
			_text.text = "Проверка и перенос файла…" if _v_dm else "Проверка файла…"
			_bar.value = 0.0
		State.ERROR:
			_title.text = "Ресурсы не загружены"
			_text.text = error_text + ("\nБез пакета вместо героев профессий, жителей и старших стадий зверей — "
				+ "запасные модели.")
			_main_btn.text = "Повторить"
		State.DONE:
			_text.text = "Готово."


## «(частей: 2 из 5 — остальные уже загружены)», если часть пакета уже в кэше.
func _parts_note() -> String:
	var n := Assets.manifest_parts(manifest).size()
	if n > 1 and todo.size() < n:
		return " (частей: %d из %d — остальные уже загружены)" % [todo.size(), n]
	return ""


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# Dark Pact: главный арт на фоне и логотип над окном (в APK — видны до загрузки пакета; фоновому узлу не нужны)
	var logo: TextureRect = null
	if not background:
		MenuKit.set_backdrop(self, MenuKit.art(MenuKit.KEY_ART), MenuKit.KEY_SHADE)
		logo = MenuKit.logo(LOGO_H)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.theme = Util.ui_theme()
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(UiScale.px(14)))
	center.add_child(col)
	if logo != null:
		col.add_child(logo)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = UiScale.v2(660, 0)
	col.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(UiScale.px(12)))
	panel.add_child(v)
	_title = _label("Загрузка ресурсов", UiScale.FONT_TITLE + 2, GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_title)
	_text = _label("", UiScale.FONT_TEXT, Color(0.98, 0.96, 0.9))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = UiScale.v2(620, 0)
	v.add_child(_text)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = UiScale.v2(0, 26)
	_bar.max_value = 100.0
	_bar.show_percentage = true
	v.add_child(_bar)
	_detail = _label("", UiScale.FONT_BODY, MUTED)
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_detail)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(UiScale.px(16)))
	v.add_child(row)
	_main_btn = _button("Загрузить")
	_main_btn.pressed.connect(_on_main_pressed)
	row.add_child(_main_btn)
	_skip_btn = _button("Играть без загрузки")
	_skip_btn.pressed.connect(skip)
	row.add_child(_skip_btn)
	buttons = {"main": _main_btn, "skip": _skip_btn}
	_set_state(state)


func _label(text: String, font_size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", UiScale.fs(font_size))
	l.add_theme_color_override("font_color", col)
	return l


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = UiScale.v2(220, UiScale.BUTTON_H + 4)
	b.add_theme_font_size_override("font_size", UiScale.fs(UiScale.FONT_TEXT + 1))
	return b


## Байты → «12.3 МБ».
static func _mb(bytes: int) -> String:
	return "%.1f МБ" % (float(bytes) / 1048576.0)


static func _time_text(sec: float) -> String:
	if sec >= 90.0:
		return "%d мин" % int(ceil(sec / 60.0))
	return "%d с" % int(ceil(maxf(sec, 1.0)))


## Почему не вышло: результат HTTPRequest или код ответа сервера.
static func _net_error(result: int, code: int) -> String:
	match result:
		HTTPRequest.RESULT_SUCCESS:
			return "сервер ответил %d" % code
		HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CANT_RESOLVE, HTTPRequest.RESULT_CONNECTION_ERROR:
			return "нет соединения с сетью"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "ошибка защищённого соединения"
		HTTPRequest.RESULT_TIMEOUT:
			return "сервер не отвечает"
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN, HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
			return "не удалось записать файл — проверьте свободное место"
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
			return "слишком много перенаправлений"
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED, HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED:
			return "ошибка данных"
	return "ошибка %d" % result
