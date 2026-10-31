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
## Тест (tests/test_asset_pack.gd): preset_manifest — манифест без файла и сети; offline — загрузка не идёт в сеть
## (тест сам кладёт временный файл и зовёт _on_download_completed).

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


func _ready() -> void:
	layer = 50
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
		Assets.remove_old(String(manifest["hash"]))
		_load(cached)
		return
	_set_state(State.CONFIRM)


## «Загрузить»: место на диске, временный файл, запрос.
func start_download() -> void:
	if manifest.is_empty():
		begin()
		return
	Assets.ensure_dir()
	var need := int(manifest["size"])
	var d := DirAccess.open(Assets.packs_dir)
	if d != null:
		var left := int(d.get_space_left())
		if left > 0 and float(left) < float(need) * SPACE_MARGIN:
			_fail("Недостаточно места: нужно %s, свободно %s." % [_mb(int(need * SPACE_MARGIN)), _mb(left)])
			return
	var part := Assets.part_path(String(manifest["hash"]))
	Assets.remove_file(part)
	downloaded = true
	_last_bytes = 0
	_stall = 0.0
	_samples.clear()
	_set_state(State.DOWNLOAD)
	if offline:
		return
	_http.cancel_request()
	_http.download_file = part
	if _http.request(String(manifest["url"])) != OK:
		_fail("Не удалось начать загрузку.")


func _on_download_completed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if state != State.DOWNLOAD:
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


func _update_download(delta: float) -> void:
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
	_verifier.step(VERIFY_STEP)
	_bar.value = 100.0 * _verifier.progress()
	if not _verifier.done:
		return
	var h := String(manifest["hash"])
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
	if Assets.load_pack(path):
		_finish(true)
		return
	Assets.remove_file(path)
	_fail("Пакет ресурсов не открывается — он будет загружен заново.")


## «Играть без загрузки»: загрузка останавливается; пакет прошлой версии из кэша, если есть.
func skip() -> void:
	if state == State.DONE:
		return
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
	_set_state(State.ERROR)


func _finish(with_pack: bool) -> void:
	if state == State.DONE:
		return
	_set_state(State.DONE)
	call_deferred("_emit_finished", with_pack)


func _emit_finished(with_pack: bool) -> void:
	finished.emit(with_pack)


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
			_text.text = "Загружается пакет ресурсов (%s). Не закрывайте игру." % size_mb
			_bar.value = 0.0
			_detail.text = "0 из %s" % size_mb
		State.VERIFY:
			_text.text = "Проверка файла…"
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
