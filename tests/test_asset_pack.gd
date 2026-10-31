extends "res://tests/test_base.gd"
## Пакет ресурсов (Assets, AssetLoader): в автотестах ресурсы встроены — экран загрузки не показывается, мир
## запускается сразу. Шаблоны пакета совпадают с пресетами экспорта (пакет «Assets», исключения APK «Android»,
## манифест в APK, разрешение INTERNET); какие модели в пакете, а какие запасные остаются в APK.
## Без пакета (Assets.simulate_missing) герой любой расы, пола и профессии — запасная модель пола, звери старших
## стадий — модель 1-й стадии. Экран загрузки без сети (манифест подставляется, файл кладёт тест): предупреждение
## о размере, «Играть без загрузки», битый файл (sha256), обрыв сети, «Повторить», успешная проверка —
## переименование временного файла, удаление прежних версий, подключение .pck (его файл виден в res://);
## пакет того же хэша берётся из кэша без загрузки; манифест из сети (битый и верный).

const TEST_DIR := "user://test_packs/"
const SRC := "user://test_pack_probe.txt"
const GOOD := "user://test_pack_good.pck"
const PROBE_RES := "res://test_asset_pack/probe.txt"
const H0 := "0000000000000000"
const H1 := "a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1"
const H2 := "b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2"
const STAGED := ["panther", "pheasant", "turtle", "wolf", "centaur"]

var loader: AssetLoader
var results: Array = []
var m1: Dictionary = {}
var good_bytes := PackedByteArray()


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
			_check_manifest_parse()
			step = 1
		1:
			_check_fallback()
			_prepare_pack()
			_new_loader(m1)
			wait = 2
			step = 2
		2:
			check(loader.state == AssetLoader.State.CONFIRM, "без пакета в кэше — предупреждение перед загрузкой")
			check(loader._text.text.contains("Будет загружено") and loader._text.text.contains("Wi-Fi"),
				"предупреждение о размере и мобильной сети: " + loader._text.text)
			check(loader._main_btn.visible and loader._main_btn.text.contains("МБ"), "кнопка «%s»" % loader._main_btn.text)
			(loader.buttons["skip"] as Button).pressed.emit()
			wait = 2
			step = 3
		3:
			check(results == [false], "«Играть без загрузки» — без пакета: %s" % str(results))
			check(Assets.skipped and Assets.loaded_path == "", "пакет не подключён, выбор запомнен")
			loader.queue_free()
			Assets.skipped = false
			_new_loader(m1)
			wait = 2
			step = 4
		4:
			# Битый файл: размер тот же, один байт другой — sha256 не совпадает
			(loader.buttons["main"] as Button).pressed.emit()
			check(loader.state == AssetLoader.State.DOWNLOAD, "«Загрузить» — загрузка началась")
			var bad := good_bytes.duplicate()
			var mid := bad.size() >> 1
			bad[mid] = (bad[mid] + 1) % 256
			_write(Assets.part_path(H1), bad)
			loader._on_download_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), PackedByteArray())
			check(loader.state == AssetLoader.State.VERIFY, "файл загружен — проверка")
			wait = 3
			step = 5
		5:
			if loader.state == AssetLoader.State.VERIFY:
				return
			check(loader.state == AssetLoader.State.ERROR and loader.error_text.contains("повреждён"),
				"битый файл — ошибка: " + loader.error_text)
			check(not FileAccess.file_exists(Assets.part_path(H1)) and not FileAccess.file_exists(Assets.pack_path(H1)),
				"битый временный файл удалён, в кэш не попал")
			check(loader._main_btn.visible and loader._main_btn.text == "Повторить", "кнопка «Повторить»")
			# «Повторить» → снова предупреждение → «Загрузить» → обрыв сети
			(loader.buttons["main"] as Button).pressed.emit()
			check(loader.state == AssetLoader.State.CONFIRM, "«Повторить» — снова предупреждение о размере")
			(loader.buttons["main"] as Button).pressed.emit()
			_write(Assets.part_path(H1), good_bytes.slice(0, 100))
			loader._on_download_completed(HTTPRequest.RESULT_CONNECTION_ERROR, 0, PackedStringArray(), PackedByteArray())
			check(loader.state == AssetLoader.State.ERROR and loader.error_text.contains("нет соединения"),
				"обрыв сети — ошибка: " + loader.error_text)
			check(not FileAccess.file_exists(Assets.part_path(H1)), "недокачанный файл удалён")
			# Ещё раз — успешно; в кэше лежат прежняя версия и недокачанный файл другой версии
			(loader.buttons["main"] as Button).pressed.emit()
			(loader.buttons["main"] as Button).pressed.emit()
			_write(Assets.pack_path(H0), PackedByteArray([1, 2, 3]))
			_write(Assets.part_path(H0), PackedByteArray([4, 5]))
			_write(Assets.part_path(H1), good_bytes)
			loader._on_download_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), PackedByteArray())
			wait = 3
			step = 6
		6:
			if loader.state == AssetLoader.State.VERIFY:
				return
			check(loader.state == AssetLoader.State.DONE, "проверка прошла (%s)" % loader.error_text)
			wait = 2
			step = 7
		7:
			check(results == [true], "загрузка закончена с пакетом: %s" % str(results))
			check(loader.downloaded, "пакет загружен по сети (не из кэша)")
			check(FileAccess.file_exists(Assets.pack_path(H1)) and not FileAccess.file_exists(Assets.part_path(H1)),
				"временный файл переименован в assets-<хэш>.pck")
			check(not FileAccess.file_exists(Assets.pack_path(H0)) and not FileAccess.file_exists(Assets.part_path(H0)),
				"прежняя версия и недокачанный файл удалены")
			check(Assets.loaded_path == Assets.pack_path(H1), "пакет подключён: " + Assets.loaded_path)
			check(FileAccess.file_exists(PROBE_RES) and FileAccess.get_file_as_string(PROBE_RES) == "probe",
				"файл пакета виден по своему пути res://")
			loader.queue_free()
			# Тот же хэш — из кэша, без предупреждения и загрузки
			check(Assets.cached_pack(m1) == Assets.pack_path(H1), "пакет хэша есть в кэше")
			var wrong := m1.duplicate()
			wrong["size"] = int(m1["size"]) + 1
			check(Assets.cached_pack(wrong) == "", "в кэше другой размер — не годится")
			_new_loader(m1)
			check(loader.state == AssetLoader.State.DONE and not loader.downloaded, "тот же хэш — сразу из кэша")
			wait = 2
			step = 8
		8:
			check(results == [true], "из кэша — с пакетом: %s" % str(results))
			loader.queue_free()
			# Манифест из сети: в тестах версии игры нет, манифеста в APK нет — ошибка; ответ сервера подставляем
			_new_loader({})
			check(loader.state == AssetLoader.State.ERROR, "без манифеста и версии — ошибка: " + loader.error_text)
			loader.state = AssetLoader.State.MANIFEST
			loader._on_manifest_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(),
				"{\"hash\": \"zz\"}".to_utf8_buffer())
			check(loader.state == AssetLoader.State.ERROR and loader.error_text.contains("повреждены"),
				"битый манифест — ошибка: " + loader.error_text)
			loader.state = AssetLoader.State.MANIFEST
			loader._on_manifest_completed(HTTPRequest.RESULT_SUCCESS, 404, PackedStringArray(), PackedByteArray())
			check(loader.state == AssetLoader.State.ERROR and loader.error_text.contains("404"), "нет манифеста (404)")
			var m2 := m1.duplicate()
			m2["hash"] = H2
			loader.state = AssetLoader.State.MANIFEST
			loader._on_manifest_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(),
				JSON.stringify(m2).to_utf8_buffer())
			check(loader.state == AssetLoader.State.CONFIRM and String(loader.manifest["hash"]) == H2,
				"манифест из сети — новая версия, предупреждение о загрузке")
			# «Играть без загрузки» при пакете прошлой версии в кэше — он и подключается
			(loader.buttons["skip"] as Button).pressed.emit()
			wait = 2
			step = 9
		9:
			check(results == [true], "без загрузки, но с прошлым пакетом из кэша: %s" % str(results))
			loader.queue_free()
			_cleanup()
			ok_done()


## Пресеты экспорта: пакет «Assets» — ровно Assets.PACK_FILTERS (Android, ETC2), APK их исключает, включает
## манифест, есть разрешение INTERNET.
func _check_presets() -> void:
	var cfg := ConfigFile.new()
	check(cfg.load("res://export_presets.cfg") == OK, "export_presets.cfg читается")
	var apk := ""
	var pack := ""
	for sec in cfg.get_sections():
		if not sec.begins_with("preset.") or sec.ends_with(".options"):
			continue
		match String(cfg.get_value(sec, "name", "")):
			"Android":
				apk = sec
			"Assets":
				pack = sec
	check(apk != "" and pack != "", "пресеты «Android» и «Assets» есть")
	check(String(cfg.get_value(pack, "platform", "")) == "Android", "пакет экспортируется под Android (ETC2/ASTC)")
	var inc := _split(String(cfg.get_value(pack, "include_filter", "")))
	var want: Array = []
	for f in Assets.PACK_FILTERS:
		want.append(String(f))
	inc.sort()
	want.sort()
	check(inc == want, "шаблоны пакета в export_presets.cfg = Assets.PACK_FILTERS")
	var apk_exc := _split(String(cfg.get_value(apk, "exclude_filter", "")))
	var missing: Array = []
	for f in want:
		if not apk_exc.has(f):
			missing.append(f)
	check(missing.is_empty(), "APK исключает все файлы пакета (нет: %s)" % str(missing))
	check(_split(String(cfg.get_value(apk, "include_filter", ""))).has("assets_pack.json"), "манифест пакета — в APK")
	check(_split(String(cfg.get_value(apk, "include_filter", ""))).has("assets/characters/*.json"),
		"роли костей героев (.json) — в APK")
	check(bool(cfg.get_value(apk + ".options", "permissions/internet", false)), "у APK есть разрешение INTERNET")


## Какие файлы в пакете: все модели героев, кроме запасных (FALLBACK_HEROES), и модели стадий зверей.
func _check_files() -> void:
	check(Assets.is_packed(Assets.PROBE) and ResourceLoader.exists(Assets.PROBE), "файл-признак пакета — в пакете")
	for g in CharacterModel.FALLBACK_HEROES:
		var p := String(CharacterModel.FALLBACK_HEROES[g])
		check(ResourceLoader.exists(p) and not Assets.is_packed(p) and not Assets.is_packed(p.get_basename() + ".png"),
			"запасная модель «%s» — в APK" % p.get_file())
	check(Assets.is_packed(CharacterModel.MAIN_ASSET), "прежняя героиня — в пакете")
	var heroes := 0
	for f in _list("res://assets/characters/", ".glb"):
		var p := "res://assets/characters/" + f
		var fallback := CharacterModel.FALLBACK_HEROES.values().has(p)
		check(Assets.is_packed(p) != fallback, "%s — %s" % [f, "в APK" if fallback else "в пакете"])
		check(Assets.is_packed(p.get_basename() + ".png") == Assets.is_packed(p), "%s: текстура там же" % f)
		check(not Assets.is_packed(p.get_basename() + ".json"), "%s: роли костей (.json) — в APK" % f)
		if not fallback:
			heroes += 1
	check(heroes >= 23, "в пакете моделей героев: %d" % heroes)
	for f in _list("res://assets/creatures/", ".glb"):
		var p := "res://assets/creatures/" + f
		var stage := f.ends_with("_2.glb") or f.ends_with("_3.glb")
		check(Assets.is_packed(p) == stage and Assets.is_packed(p.get_basename() + ".png") == stage,
			"%s — %s" % [f, "в пакете" if stage else "в APK"])
	check(not Assets.is_packed("res://assets/creatures/creatures.json"), "creatures.json — в APK")
	check(not Assets.is_packed("res://assets/props/town_hall.glb") and not Assets.is_packed("res://assets/props/props_town.png"),
		"постройки — в APK")


func _check_manifest_parse() -> void:
	var ok := Assets.parse_manifest(JSON.stringify({"hash": H1, "sha256": H1, "size": 10, "url": "https://x/y.pck"}))
	check(ok.get("hash", "") == H1 and int(ok.get("size", 0)) == 10, "манифест читается")
	check(Assets.parse_manifest("не json").is_empty(), "не JSON — пусто")
	check(Assets.parse_manifest(JSON.stringify({"hash": H1, "sha256": "zz", "size": 10, "url": "https://x"})).is_empty(),
		"неверный sha256 — пусто")
	check(Assets.parse_manifest(JSON.stringify({"hash": H1, "sha256": H1, "size": 0, "url": "https://x"})).is_empty(),
		"нулевой размер — пусто")
	check(Assets.manifest_url("0.17.0")
		== "https://github.com/lemonmen72-svg/MyRappelz/releases/download/v0.17.0/assets-manifest.json",
		"адрес манифеста в релизе версии")
	check(Assets.pack_path(H1).ends_with("assets-" + H1 + ".pck") and Assets.part_path(H1).ends_with(".pck.part"),
		"имена файлов кэша")


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
		check(CreatureAsset.model_for(sp, 1) == sp and CreatureAsset.model_for(sp, 2) == sp and CreatureAsset.has_asset(sp),
			"%s: без пакета старшие стадии — модель 1-й стадии" % sp)
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


## Настоящий .pck (PCKPacker) с одним файлом, его sha256 и размер; проверка по частям.
func _prepare_pack() -> void:
	Assets.packs_dir = TEST_DIR
	_clear_dir()
	Assets.ensure_dir()
	var f := FileAccess.open(SRC, FileAccess.WRITE)
	f.store_string("probe")
	f = null
	var pk := PCKPacker.new()
	check(pk.pck_start(GOOD) == OK, "тестовый .pck создаётся")
	pk.add_file(PROBE_RES, SRC)
	pk.flush()
	good_bytes = FileAccess.get_file_as_bytes(GOOD)
	var sha := Assets.file_sha256(GOOD)
	check(sha.length() == 64 and good_bytes.size() > 0, "sha256 тестового пакета")
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(good_bytes)
	check(ctx.finish().hex_encode() == sha, "sha256 по частям = sha256 целиком")
	var v := Assets.Verifier.new(GOOD, sha, good_bytes.size())
	while not v.step(7):
		pass
	check(v.ok and v.progress() == 1.0, "проверка мелкими частями проходит")
	v = Assets.Verifier.new(GOOD, sha, good_bytes.size() + 1)
	check(v.done and not v.ok and v.error.contains("размер"), "другой размер — ошибка")
	v = Assets.Verifier.new(GOOD, H1, good_bytes.size())
	v.step(1 << 20)
	check(v.done and not v.ok, "другая контрольная сумма — ошибка")
	m1 = {"hash": H1, "sha256": sha, "size": good_bytes.size(), "url": "https://example.invalid/pack.pck", "version": "test"}
	Assets.simulate_missing(true)


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
	_clear_dir()
	Assets.packs_dir = "user://packs/"
	for p in [SRC, GOOD]:
		Assets.remove_file(p)


func _clear_dir() -> void:
	var d := DirAccess.open(TEST_DIR)
	if d == null:
		return
	for f in d.get_files():
		DirAccess.remove_absolute(TEST_DIR + f)


func _write(path: String, data: PackedByteArray) -> void:
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
