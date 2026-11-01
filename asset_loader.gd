class_name AssetLoader
extends CanvasLayer
## Экран «Загрузка ресурсов»: до создания персонажа и входа в мир подключает пакет ресурсов (Assets) — модели
## героев профессий и стадий эволюции зверей, которых нет в APK.
## Порядок: манифест (из APK res://assets_pack.json, иначе assets-manifest.json из релиза версии игры) →
## пакет этого хэша уже в кэше user://packs — сразу подключить; иначе предупреждение «Будет загружено N МБ»
## (на мобильной сети — лучше Wi-Fi) → загрузка HTTPRequest.download_file во временный файл
## assets-<хэш>.pck.part (МБ из МБ, скорость, сколько осталось) → проверка размера и sha256 по частям →
## переименование в assets-<хэш>.pck, прежние версии удаляются → ProjectSettings.load_resource_pack.
## Обрыв, ошибка сети, битый файл — сообщение и «Повторить» (загрузка начинается заново, временный файл удаляется).
## «Играть без загрузки» — без пакета (запасные модели; если в кэше есть пакет прошлой версии — он).
## Сигнал finished(with_pack) — можно продолжать (main.gd). Если ресурсы уже есть (Assets.available()),
## экран не нужен — main.gd его не создаёт.
## Фоновая загрузка (Android, плагин MyRappelzDownload — Assets.download_plugin()): «Загрузить» отдаёт файл системному
## DownloadManager (файл — во внешнюю папку приложения, уведомление «MyRappelz — загрузка ресурсов» с ходом загрузки,
## на Android 13+ при первом нажатии спрашивается разрешение на уведомления), игру можно свернуть или закрыть.
## Экран опрашивает загрузку (_poll_dm раз в POLL_TIME): МБ из МБ, скорость, ожидание сети; готово — проверка sha256
## с копированием в assets-<хэш>.pck.part (Verifier copy_to), дальше как обычно; ошибка или отмена в уведомлении —
## сообщение и «Повторить». Запись о загрузке (Assets.read_job) переживает перезапуск: при следующем запуске экран
## сразу продолжает следить за ней (без вопроса о размере). «Играть без загрузки» во время такой загрузки её не
## останавливает: невидимый фоновый AssetLoader (background) у корня дерева следит дальше, по окончании проверяет
## файл и кладёт пакет в кэш, сообщение — в HUD; пакет подключается при следующем входе в мир («Сменить
## персонажа» или запуск игры) — посреди игры не подключается: готовые модели остались бы запасными, а новые — нет.
## Нет плагина или DownloadManager не принял загрузку — прежняя загрузка HTTPRequest (игру не сворачивать).
## Тест (tests/test_asset_pack.gd): preset_manifest — манифест без файла и сети; offline — загрузка не идёт в сеть
## (тест сам кладёт временный файл и зовёт _on_download_completed); Assets.plugin_override — подставной плагин.

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
const NOTIFY_TITLE := "MyRappelz — загрузка ресурсов"
const NOTIFY_TEXT := "Пакет моделей, %s"

var state := State.START
var manifest: Dictionary = {}
var preset_manifest: Dictionary = {}
var offline := false
## Пакет загружался в этом запуске (не из кэша).
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

var _title: Label
var _text: Label
var _bar: ProgressBar
var _detail: Label
var _main_btn: Button
var _skip_btn: Button
var _http_manifest: HTTPRequest
var _http: HTTPRequest
var _verifier: Assets.Verifier
var _last_bytes := 0
var _stall := 0.0
## Замеры для скорости: [время с, байт].
var _samples: Array = []
var _clock := 0.0
## Плагин фоновой загрузки (null — HTTPRequest).
var _dm: Object = null
## Идущая загрузка DownloadManager: id и файл во внешней папке ("" — загрузка через HTTPRequest или нет её).
var _dm_id := ""
var _dm_path := ""
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
	if Assets.available():
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


func _have_manifest() -> void:
	var cached := Assets.cached_pack(manifest)
	if cached != "":
		_drop_job()
		Assets.remove_old(String(manifest["hash"]))
		_load(cached)
		return
	if _resume_job():
		return
	if background:
		_bg_end("")
		return
	_set_state(State.CONFIRM)


## «Загрузить»: место на диске, временный файл, запрос.
func start_download() -> void:
	if manifest.is_empty():
		begin()
		return
	Assets.ensure_dir()
	var need := int(manifest["size"])
	# Через DownloadManager файл сначала ложится во внешнюю папку приложения и копируется в кэш — нужно две копии.
	var want := int(float(need) * (SPACE_MARGIN + (1.0 if _dm != null else 0.0)))
	var d := DirAccess.open(Assets.packs_dir)
	if d != null:
		var left := int(d.get_space_left())
		if left > 0 and left < want:
			_fail("Недостаточно места: нужно %s, свободно %s." % [_mb(want), _mb(left)])
			return
	var part := Assets.part_path(String(manifest["hash"]))
	Assets.remove_file(part)
	downloaded = true
	_last_bytes = 0
	_stall = 0.0
	_samples.clear()
	if _dm != null and _start_dm():
		return
	_set_state(State.DOWNLOAD)
	if offline:
		return
	_http.cancel_request()
	_http.download_file = part
	if _http.request(String(manifest["url"])) != OK:
		_fail("Не удалось начать загрузку.")


## Загрузка через DownloadManager: прежняя загрузка (другого хэша, неудачная) убирается, новая записывается в
## Assets.save_job. false — плагин не смог (нет внешней памяти, DownloadManager выключен) — тогда HTTPRequest.
func _start_dm() -> bool:
	_drop_job()
	var h := String(manifest["hash"])
	var rel := Assets.download_rel_path(h)
	var path := String(_dm.call("externalPath", rel))
	if path == "":
		return false
	var id := String(_dm.call("start", String(manifest["url"]), rel, NOTIFY_TITLE,
		NOTIFY_TEXT % _mb(int(manifest["size"]))))
	if id == "":
		push_warning("DownloadManager: %s — загрузка через HTTPRequest" % String(_dm.call("lastError")))
		return false
	# Android 13+: без разрешения система не покажет уведомление с ходом загрузки (качать будет и без него).
	_dm.call("requestNotifications")
	_dm_id = id
	_dm_path = path
	_poll = 0.0
	Assets.save_job(h, id, path)
	_set_state(State.DOWNLOAD)
	return true


## Загрузка DownloadManager этого пакета уже идёт или закончилась (игру свернули или закрыли, «Играть без
## загрузки»): следить за ней без вопроса о размере. true — продолжаем; загрузки нет, она неудачна или другого
## хэша — запись убирается, false.
func _resume_job() -> bool:
	var job := Assets.read_job()
	if job.is_empty():
		return false
	if _dm == null or String(job["hash"]) != String(manifest["hash"]):
		_drop_job(job)
		return false
	_dm_id = String(job["id"])
	_dm_path = String(job["path"])
	var info := _dm_query()
	if info.has("error"):
		info = {"found": true, "status": DM_PENDING}
	var st := int(info.get("status", 0))
	if not bool(info.get("found", false)) or st == DM_FAILED or _dm_path == "":
		_drop_job(job)
		_dm_id = ""
		return false
	downloaded = true
	_samples.clear()
	_poll = 0.0
	_set_state(State.DOWNLOAD)
	if st == DM_SUCCESS:
		_dm_finished(info)
	else:
		_dm_progress(info)
	return true


## Убрать загрузку DownloadManager (идущая останавливается, файл удаляется) и запись о ней.
func _drop_job(job: Dictionary = {}) -> void:
	var j := job if not job.is_empty() else Assets.read_job()
	if not j.is_empty():
		if _dm != null:
			_dm.call("remove", String(j["id"]))
		Assets.remove_file(String(j.get("path", "")))
	Assets.clear_job()


func _dm_query() -> Dictionary:
	if _dm == null or _dm_id == "":
		return {}
	var r: Variant = _dm.call("query", _dm_id)
	if r is Dictionary:
		return r
	return {}


## Опрос DownloadManager: ход загрузки, ожидание сети, готово, ошибка, отмена (в уведомлении или «Загрузках»).
func _poll_dm() -> void:
	if state != State.DOWNLOAD or _dm_id == "":
		return
	var info := _dm_query()
	if info.has("error"):
		return
	if not bool(info.get("found", false)):
		_dm_fail("Загрузка отменена.")
		return
	match int(info.get("status", 0)):
		DM_SUCCESS:
			_dm_finished(info)
		DM_FAILED:
			_dm_fail("Загрузка прервалась (%s)." % _dm_reason(int(info.get("reason", 0))))
		_:
			_dm_progress(info)


func _dm_progress(info: Dictionary) -> void:
	var got := maxi(int(info.get("bytes", 0)), 0)
	var total := int(info.get("total", 0))
	if total <= 0:
		total = int(manifest["size"])
	if int(info.get("status", 0)) == DM_PAUSED:
		_samples.clear()
		_bar.value = 100.0 * float(got) / float(maxi(total, 1))
		_detail.text = "%s из %s · %s" % [_mb(got), _mb(total), _dm_pause_text(int(info.get("reason", 0)))]
		return
	_show_progress(got, total)


## Файл загружен: проверка sha256 с копированием во временный файл кэша (дальше — как у HTTPRequest).
## Файл — где его записал DownloadManager (uri), обычно это и есть путь из записи о загрузке.
func _dm_finished(info: Dictionary) -> void:
	var uri := String(info.get("uri", ""))
	if uri.begins_with("file://"):
		var real := uri.trim_prefix("file://").uri_decode()
		if real != _dm_path and FileAccess.file_exists(real):
			_dm_path = real
	var part := Assets.part_path(String(manifest["hash"]))
	Assets.ensure_dir()
	Assets.remove_file(part)
	_verifier = Assets.Verifier.new(_dm_path, String(manifest["sha256"]), int(manifest["size"]), part)
	_set_state(State.VERIFY)


func _dm_fail(text: String) -> void:
	_drop_job()
	_dm_id = ""
	_fail(text)


func _on_download_completed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if state != State.DOWNLOAD or _dm_id != "":
		return
	var part := Assets.part_path(String(manifest["hash"]))
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		Assets.remove_file(part)
		_fail("Загрузка прервалась (%s)." % _net_error(result, code))
		return
	_verifier = Assets.Verifier.new(part, String(manifest["sha256"]), int(manifest["size"]))
	_set_state(State.VERIFY)


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
	if _dm_id != "":
		_poll += delta
		if _poll >= poll_time:
			_poll = 0.0
			_poll_dm()
		return
	if offline:
		return
	var got := _http.get_downloaded_bytes()
	var total := _http.get_body_size()
	if total <= 0:
		total = int(manifest["size"])
	if got != _last_bytes:
		_last_bytes = got
		_stall = 0.0
	else:
		_stall += delta
		if _stall > STALL_TIME:
			_http.cancel_request()
			Assets.remove_file(Assets.part_path(String(manifest["hash"])))
			_fail("Нет данных %d с — соединение прервано." % int(STALL_TIME))
			return
	_show_progress(got, total)


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
	var h := String(manifest["hash"])
	if _dm_id != "":
		# Файл DownloadManager больше не нужен: скопирован в кэш или битый (загрузка — заново).
		_drop_job()
		_dm_id = ""
	if not _verifier.ok:
		var why := _verifier.error
		_verifier = null
		Assets.remove_file(Assets.part_path(h))
		_fail("Файл пакета повреждён (%s). Попробуйте загрузить ещё раз." % why)
		return
	_verifier = null
	var path := Assets.install(h)
	if path == "":
		Assets.remove_file(Assets.part_path(h))
		_fail("Не удалось сохранить пакет ресурсов.")
		return
	_load(path)


func _load(path: String) -> void:
	if background:
		# Посреди игры пакет не подключается — при следующем входе в мир (main.gd покажет экран, он возьмёт кэш).
		# Уже подключён пакет прошлой версии — его файлы не заменить, новый подключится при следующем запуске.
		if Assets.loaded_path == "":
			Assets.skipped = false
			_bg_end("Пакет ресурсов загружен. Новые модели героев и зверей появятся при следующем входе в мир "
				+ "(«Настройки» → «Сменить персонажа») или запуске игры.")
		else:
			_bg_end("Пакет ресурсов загружен. Новые модели появятся при следующем запуске игры.")
		return
	if Assets.load_pack(path):
		_finish(true)
		return
	Assets.remove_file(path)
	_fail("Пакет ресурсов не открывается — он будет загружен заново.")


## «Играть без загрузки»: загрузка HTTPRequest останавливается; загрузка DownloadManager идёт дальше — за ней следит
## фоновый AssetLoader у корня дерева. Пакет прошлой версии из кэша, если есть, подключается.
func skip() -> void:
	if state == State.DONE:
		return
	if state == State.DOWNLOAD and _dm_id != "":
		_dm_id = ""
		var bg := AssetLoader.new()
		bg.background = true
		bg.preset_manifest = manifest
		bg.offline = offline
		get_tree().root.add_child.call_deferred(bg)
	else:
		_http.cancel_request()
		_http_manifest.cancel_request()
		_verifier = null
		if not manifest.is_empty():
			Assets.remove_file(Assets.part_path(String(manifest["hash"])))
	Assets.skipped = true
	var old := Assets.any_cached_pack()
	_finish(old != "" and Assets.load_pack(old))


func _on_main_pressed() -> void:
	match state:
		State.CONFIRM:
			start_download()
		State.ERROR:
			begin()


func _fail(text: String) -> void:
	error_text = text
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
	var size_mb := _mb(int(manifest.get("size", 0)))
	_bar.visible = s == State.DOWNLOAD or s == State.VERIFY
	_detail.text = ""
	_main_btn.visible = s == State.CONFIRM or s == State.ERROR
	_skip_btn.visible = s != State.DONE and s != State.VERIFY
	_skip_btn.text = "Играть, пока грузится" if s == State.DOWNLOAD and _dm_id != "" else "Играть без загрузки"
	_title.text = "Загрузка ресурсов"
	match s:
		State.START, State.MANIFEST:
			_text.text = "Получаем сведения о пакете ресурсов…"
		State.CONFIRM:
			_text.text = ("Для героев всех профессий и старших стадий питомцев нужен пакет ресурсов.\n"
				+ "Будет загружено %s. Загрузка нужна один раз: пакет сохранится в памяти игры.\n"
				+ "На мобильной сети за трафик может взиматься плата — лучше подключиться к Wi-Fi.") % size_mb
			_main_btn.text = "Загрузить (%s)" % size_mb
		State.DOWNLOAD:
			if _dm_id != "":
				_text.text = ("Загружается пакет ресурсов (%s). Игру можно свернуть — загрузка продолжится, "
					+ "её ход виден в уведомлениях.\nМожно играть и сейчас, на запасных моделях: пакет загрузится "
					+ "в фоне и подключится при следующем входе в мир.") % size_mb
			else:
				_text.text = "Загружается пакет ресурсов (%s). Не закрывайте игру." % size_mb
			_bar.value = 0.0
			_detail.text = "0 из %s" % size_mb
		State.VERIFY:
			_text.text = "Проверка и перенос файла…" if _dm_id != "" else "Проверка файла…"
			_bar.value = 0.0
		State.ERROR:
			_title.text = "Ресурсы не загружены"
			_text.text = error_text + "\nБез пакета вместо героев профессий и старших стадий зверей — запасные модели."
			_main_btn.text = "Повторить"
		State.DONE:
			_text.text = "Готово."


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.theme = Util.ui_theme()
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = UiScale.v2(660, 0)
	center.add_child(panel)
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
