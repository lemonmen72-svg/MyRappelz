class_name Assets
extends RefCounted
## Пакет ресурсов: тяжёлые модели (герои профессий, стадии эволюции зверей) не лежат в APK, а загружаются
## отдельным файлом .pck при первом запуске и хранятся в кэше игры (user://packs/assets-<хэш>.pck).
##
## Что в пакете — PACK_FILTERS (те же шаблоны, что include_filter пресета экспорта «Assets» и часть
## exclude_filter пресета «Android» в export_presets.cfg; тест tests/test_asset_pack.gd следит, чтобы совпадали).
## Сборка пакета — только при сборке APK (.github/workflows/android-apk.yml, tools/asset_pack.py): хэш содержимого
## (исходники пакета + их .import + версия Godot) — версия пакета; манифест (hash, sha256 и размер .pck, url)
## кладётся в APK как res://assets_pack.json и в релиз как assets-manifest.json.
##
## В редакторе и автотестах файлы пакета лежат прямо в res:// (embedded) — загрузка не нужна.
## Код моделей проверяет файлы через Assets.exists(path): без пакета модель из пакета «не существует», и
## CharacterModel / CreatureAsset берут запасную (стартовые модели людей в APK, модель 1-й стадии, примитивы).
## Экран загрузки — AssetLoader (main.gd показывает его до создания персонажа и входа в мир).
##
## Фоновая загрузка на Android — системный DownloadManager через плагин Godot v2 «MyRappelzDownload»
## (download_plugin(); исходники android/plugins/myrappelz_download, AAR собирается при сборке APK с Gradle):
## качает сам Android — игру можно свернуть, ход загрузки в уведомлении. Файл ложится во внешнюю папку приложения,
## запись о загрузке (хэш, id, путь) — packs_dir + JOB_FILE (переживает перезапуск игры); после загрузки файл
## проверяется (sha256) с копированием в assets-<хэш>.pck.part и ставится в кэш как обычно. Нет плагина (ПК,
## редактор, тесты, APK без Gradle) — прежняя загрузка HTTPRequest.

## Файлы пакета (пути от res://, шаблоны String.matchn: * — любые символы, ? — один).
## Остаются в APK: hero_human_m_starter и hero_human_f_starter (запасные герои), звери 1-й стадии, постройки.
const PACK_FILTERS := [
	"assets/characters/dark_elf_wanderer.glb",
	"assets/characters/dark_elf_wanderer.png",
	"assets/characters/hero_*_?.glb",
	"assets/characters/hero_*_?.png",
	"assets/characters/hero_*elf_?_starter.glb",
	"assets/characters/hero_*elf_?_starter.png",
	"assets/characters/npc_*.glb",
	"assets/characters/npc_*.png",
	"assets/creatures/*_2.glb",
	"assets/creatures/*_2.png",
	"assets/creatures/*_3.glb",
	"assets/creatures/*_3.png",
]
## Файл пакета, по которому видно, что ресурсы уже лежат в res:// (редактор, автотесты, полная сборка).
const PROBE := "res://assets/characters/hero_wizard_f.glb"
## Манифест пакета внутри APK (пишет сборка APK; в репозитории его нет).
const EMBEDDED_MANIFEST := "res://assets_pack.json"
## Манифест в релизе версии игры (если в APK его нет).
const RELEASES_URL := "https://github.com/lemonmen72-svg/MyRappelz/releases/download/v%s/assets-manifest.json"
const PACK_PREFIX := "assets-"
const PART_SUFFIX := ".part"
## Singleton плагина фоновой загрузки (Engine.get_singleton на Android).
const DOWNLOAD_PLUGIN := "MyRappelzDownload"
## Запись о фоновой загрузке DownloadManager в папке кэша (не начинается с PACK_PREFIX — remove_old её не трогает).
const JOB_FILE := "download.cfg"
## Папка загрузки DownloadManager во внешней папке приложения (getExternalFilesDir).
const DOWNLOAD_DIR := "packs/"

## Папка кэша пакетов (тест подменяет на свою).
static var packs_dir := "user://packs/"
## Пакет загружен в res:// (путь файла).
static var loaded_path := ""
## Игрок выбрал «Играть без загрузки» в этом запуске.
static var skipped := false
## Тест: вести себя так, будто пакета нет (embedded и загруженный пакет не в счёт).
static var force_missing := false
## Тест: подставной плагин фоновой загрузки (те же методы, что у MyRappelzDownload); null — настоящий или нет.
static var plugin_override: Object = null
static var _embedded := -1


## Ресурсы пакета лежат прямо в res:// (не нужно ничего грузить). Проверяется один раз, до загрузки пакета.
static func embedded() -> bool:
	if _embedded < 0:
		_embedded = 1 if loaded_path == "" and ResourceLoader.exists(PROBE) else 0
	return _embedded == 1


## Модели пакета доступны: встроены или пакет загружен.
static func available() -> bool:
	if force_missing:
		return false
	return embedded() or loaded_path != ""


## Тест: «пакета нет» (on) или как обычно; сбрасывает кэш наличия моделей зверей.
static func simulate_missing(on: bool) -> void:
	force_missing = on
	CreatureAsset.reset_cache()


## Файл из пакета (путь res://… или от корня проекта).
static func is_packed(path: String) -> bool:
	var p := path.trim_prefix("res://")
	for f in PACK_FILTERS:
		if p.matchn(String(f)):
			return true
	return false


## Есть ли ресурс: как ResourceLoader.exists, но файл пакета без пакета «не существует» (запасная модель).
static func exists(path: String) -> bool:
	if is_packed(path) and not available():
		return false
	return ResourceLoader.exists(path)


## Версия игры (сборка APK пишет application/config/version), "" — неизвестна.
static func game_version() -> String:
	return String(ProjectSettings.get_setting("application/config/version", "")).strip_edges().trim_prefix("v")


## Адрес манифеста в релизе версии (пусто — версия неизвестна).
static func manifest_url(version: String = "") -> String:
	var v := version if version != "" else game_version()
	return RELEASES_URL % v if v != "" else ""


## Манифест из текста JSON: {hash, sha256, size, url, version?}; {} — неполный или битый.
static func parse_manifest(text: String) -> Dictionary:
	var d: Variant = JSON.parse_string(text)
	if not d is Dictionary:
		return {}
	var m: Dictionary = d
	var h := String(m.get("hash", "")).to_lower()
	var sha := String(m.get("sha256", "")).to_lower()
	var url := String(m.get("url", ""))
	var size := int(m.get("size", 0))
	if not _is_hex(h, 16, 64) or not _is_hex(sha, 64, 64) or size <= 0 or not url.begins_with("http"):
		return {}
	return {"hash": h, "sha256": sha, "size": size, "url": url, "version": String(m.get("version", ""))}


## Манифест из APK (res://assets_pack.json), {} — нет.
static func read_embedded_manifest() -> Dictionary:
	if not FileAccess.file_exists(EMBEDDED_MANIFEST):
		return {}
	return parse_manifest(FileAccess.get_file_as_string(EMBEDDED_MANIFEST))


static func _is_hex(s: String, min_len: int, max_len: int) -> bool:
	if s.length() < min_len or s.length() > max_len:
		return false
	for c in s:
		if not "0123456789abcdef".contains(c):
			return false
	return true


## Плагин фоновой загрузки (Android DownloadManager) или null — нет (не Android, APK без плагина): тогда
## загрузка через HTTPRequest. Методы (строки, bool, Dictionary): externalPath(rel), start(url, rel, title, text) → id
## или "", query(id) → {found, status, reason, bytes, total, uri, error?}, remove(id), requestNotifications(),
## notificationsAllowed(), lastError().
static func download_plugin() -> Object:
	if plugin_override != null:
		return plugin_override
	if OS.get_name() == "Android" and Engine.has_singleton(DOWNLOAD_PLUGIN):
		return Engine.get_singleton(DOWNLOAD_PLUGIN)
	return null


## Файл загрузки DownloadManager относительно внешней папки приложения.
static func download_rel_path(content_hash: String) -> String:
	return DOWNLOAD_DIR + PACK_PREFIX + content_hash + ".pck.download"


## Запись о фоновой загрузке: {hash, id, path}; {} — нет.
static func read_job() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(packs_dir + JOB_FILE) != OK:
		return {}
	var h := String(cfg.get_value("job", "hash", ""))
	var id := String(cfg.get_value("job", "id", ""))
	if h == "" or id == "":
		return {}
	return {"hash": h, "id": id, "path": String(cfg.get_value("job", "path", ""))}


static func save_job(content_hash: String, id: String, path: String) -> void:
	ensure_dir()
	var cfg := ConfigFile.new()
	cfg.set_value("job", "hash", content_hash)
	cfg.set_value("job", "id", id)
	cfg.set_value("job", "path", path)
	cfg.save(packs_dir + JOB_FILE)


static func clear_job() -> void:
	remove_file(packs_dir + JOB_FILE)


## Путь пакета в кэше по хэшу содержимого.
static func pack_path(content_hash: String) -> String:
	return packs_dir + PACK_PREFIX + content_hash + ".pck"


## Временный файл загрузки (после проверки переименовывается в pack_path).
static func part_path(content_hash: String) -> String:
	return pack_path(content_hash) + PART_SUFFIX


static func ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(packs_dir)


## Размер файла в байтах (-1 — нет файла).
static func file_size(path: String) -> int:
	if not FileAccess.file_exists(path):
		return -1
	var f := FileAccess.open(path, FileAccess.READ)
	return int(f.get_length()) if f != null else -1


## Готовый пакет этого хэша в кэше (размер совпадает с манифестом), "" — нет.
static func cached_pack(m: Dictionary) -> String:
	var p := pack_path(String(m.get("hash", "")))
	var sz := file_size(p)
	if sz < 0:
		return ""
	if int(m.get("size", 0)) > 0 and sz != int(m["size"]):
		return ""
	return p


## Файлы папки кэша (имена).
static func _cache_files() -> PackedStringArray:
	var d := DirAccess.open(packs_dir)
	if d == null:
		return PackedStringArray()
	return d.get_files()


## Какой-нибудь прежний пакет в кэше (другой версии) — на случай «Играть без загрузки»; "" — нет.
static func any_cached_pack() -> String:
	for f in _cache_files():
		if f.begins_with(PACK_PREFIX) and f.ends_with(".pck"):
			return packs_dir + f
	return ""


## Удалить из кэша всё, кроме пакета keep_hash (прежние версии, недокачанные файлы). Сколько удалено.
static func remove_old(keep_hash: String) -> int:
	var keep := (PACK_PREFIX + keep_hash + ".pck") if keep_hash != "" else ""
	var n := 0
	for f in _cache_files():
		if f == keep or not f.begins_with(PACK_PREFIX):
			continue
		if packs_dir + f == loaded_path:
			continue
		if DirAccess.remove_absolute(packs_dir + f) == OK:
			n += 1
	return n


static func remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Проверенный временный файл → пакет кэша (переименование), прежние версии удаляются. Путь пакета или "".
static func install(content_hash: String) -> String:
	var part := part_path(content_hash)
	var dst := pack_path(content_hash)
	if not FileAccess.file_exists(part):
		return ""
	remove_file(dst)
	if DirAccess.rename_absolute(part, dst) != OK:
		return ""
	remove_old(content_hash)
	return dst


## Подключить пакет: его файлы появляются в res:// по своим путям (файлы APK не заменяются). false — не читается.
static func load_pack(path: String) -> bool:
	embedded()
	if path == "":
		return false
	if loaded_path == path:
		return true
	if not ProjectSettings.load_resource_pack(path, false):
		return false
	loaded_path = path
	CreatureAsset.reset_cache()
	return true


## sha256 файла целиком (тесты, небольшие файлы); "" — нет файла.
static func file_sha256(path: String) -> String:
	var v := Verifier.new(path, "", -1)
	while not v.done:
		v.step(1 << 24)
	return v.digest


## Проверка загруженного файла по частям (экран загрузки — несколько МБ за кадр, без подвисания):
## размер, затем sha256. done — закончено, ok — совпало, error — что не так. copy_to — заодно копировать
## прочитанное в этот файл (загрузка DownloadManager: из внешней папки приложения в кэш user://, за один проход;
## при ошибке файл копии удаляет вызывающий).
class Verifier:
	extends RefCounted
	var path := ""
	var expect_sha := ""
	var expect_size := -1
	var size := 0
	var read := 0
	var done := false
	var ok := false
	var error := ""
	var digest := ""
	var _file: FileAccess
	var _out: FileAccess
	var _ctx := HashingContext.new()

	func _init(p: String, sha: String, sz: int, copy_to: String = "") -> void:
		path = p
		expect_sha = sha.to_lower()
		expect_size = sz
		_file = FileAccess.open(p, FileAccess.READ)
		if _file == null:
			_finish("файл не найден")
			return
		size = int(_file.get_length())
		if expect_size >= 0 and size != expect_size:
			_finish("размер %d вместо %d байт" % [size, expect_size])
			return
		if copy_to != "":
			_out = FileAccess.open(copy_to, FileAccess.WRITE)
			if _out == null:
				_finish("не удалось записать файл")
				return
		_ctx.start(HashingContext.HASH_SHA256)

	## Прочитать до budget байт. true — проверка закончена.
	func step(budget: int) -> bool:
		if done:
			return true
		var left := budget
		while left > 0 and read < size:
			var chunk := _file.get_buffer(mini(left, 1 << 20))
			if chunk.is_empty():
				break
			_ctx.update(chunk)
			if _out != null:
				_out.store_buffer(chunk)
			read += chunk.size()
			left -= chunk.size()
		if read >= size or _file.eof_reached():
			digest = _ctx.finish().hex_encode()
			var copied := true
			if _out != null:
				_out.flush()
				copied = _out.get_error() == OK and int(_out.get_length()) == read
			if read != size:
				_finish("файл прочитан не целиком")
			elif not copied:
				_finish("не удалось записать файл — проверьте свободное место")
			elif expect_sha != "" and digest != expect_sha:
				_finish("контрольная сумма не совпала")
			else:
				_finish("")
		return done

	## Доля проверенного 0..1.
	func progress() -> float:
		return 1.0 if size <= 0 else clampf(float(read) / float(size), 0.0, 1.0)

	func _finish(err: String) -> void:
		done = true
		ok = err == ""
		error = err
		_file = null
		_out = null
