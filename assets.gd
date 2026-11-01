class_name Assets
extends RefCounted
## Пакет ресурсов: модели и картинки (герои профессий, жители, звери всех стадий, постройки и деревья мира, текстуры,
## оружие в руках, значки) не лежат в APK, а загружаются отдельными файлами .pck при первом запуске и хранятся в кэше
## игры. Пакет разбит на части (PACKS: герои по расам, жители, стадии зверей, мир, звери 1-й стадии, оружие, значки) —
## у каждой свой хэш содержимого и свой файл в кэше user://packs/assets-<часть>-<хэш>.pck: изменилась одна модель —
## игрок скачивает только её часть. Порядок загрузки — LOAD_ORDER (мир первым).
##
## Части и их шаблоны — PACKS (те же шаблоны, что include_filter пресетов экспорта «Assets <часть>», их объединение —
## часть exclude_filter пресета «Android» в export_presets.cfg; tools/asset_pack.py check и тест
## tests/test_asset_pack.gd следят, чтобы совпадали). Сборка частей — только при сборке APK
## (.github/workflows/android-apk.yml, tools/asset_pack.py): хэш содержимого части (исходники + их .import + версия
## Godot) — версия части; манифест {format 2, version, parts: [{name, hash, sha256, size, url, file}]} кладётся в APK
## как res://assets_pack.json и в релиз как assets-manifest.json. Старый манифест (один пакет: hash, sha256, size,
## url) читается как одна часть ALL, которая заменяет все части (её файл в кэше — прежнее имя assets-<хэш>.pck).
##
## В редакторе и автотестах файлы пакета лежат прямо в res:// (embedded) — загрузка не нужна.
## Код проверяет файлы через Assets.exists(path): без своей части файл «не существует», и берётся запасное:
## CharacterModel — стартовые модели людей в APK, CreatureAsset — модель 1-й стадии или примитивы CreatureModels,
## PropAsset — процедурные постройки PoiModels и деревья IslandVegetation, WorldTextures — без текстур,
## Handheld / NpcProps — процедурное оружие и жители без предметов, UiIcons / ItemIcon / SkillTree — процедурные
## значки. load()/preload() файла части без проверки Assets.exists нельзя (в APK его нет).
## Части подключаются по отдельности: «Играть без загрузки» подключает те, что есть в кэше, — их модели настоящие.
## Экран загрузки — AssetLoader (main.gd показывает его до создания персонажа и входа в мир).
##
## Фоновая загрузка на Android — системный DownloadManager через плагин Godot v2 «MyRappelzDownload»
## (download_plugin(); исходники android/plugins/myrappelz_download, AAR собирается при сборке APK с Gradle):
## качает сам Android — игру можно свернуть, ход загрузки в уведомлении. Недостающие части отдаются DownloadManager
## все сразу, файлы ложатся во внешнюю папку приложения; записи о загрузках (часть, хэш, id, путь) — packs_dir +
## JOB_FILE (переживают перезапуск игры); готовый файл проверяется (sha256) с копированием в
## assets-<часть>-<хэш>.pck.part и ставится в кэш как обычно. Нет плагина (ПК, редактор, тесты, APK без Gradle) —
## загрузка HTTPRequest, части по очереди.

## Части пакета: имя → файлы (пути от res://, шаблоны String.matchn: * — любые символы, ? — один).
## Остаются в APK: hero_human_m_starter и hero_human_f_starter (запасные герои), все .json (роли костей, creatures.json,
## props.json, handheld.json), шейдеры, сцены, данные мира.
## Новая модель героя профессии — шаблон в часть её расы (и в пресет «Assets <часть>», и в exclude_filter «Android»).
const PACKS := {
	"heroes_dark": [
		"assets/characters/dark_elf_wanderer.glb",
		"assets/characters/dark_elf_wanderer.png",
		"assets/characters/hero_assassin_?.glb",
		"assets/characters/hero_assassin_?.png",
		"assets/characters/hero_adept_?.glb",
		"assets/characters/hero_adept_?.png",
		"assets/characters/hero_neophyte_?.glb",
		"assets/characters/hero_neophyte_?.png",
		"assets/characters/hero_dark_elf_?_starter.glb",
		"assets/characters/hero_dark_elf_?_starter.png",
	],
	"heroes_light": [
		"assets/characters/hero_swordsman_?.glb",
		"assets/characters/hero_swordsman_?.png",
		"assets/characters/hero_wizard_?.glb",
		"assets/characters/hero_wizard_?.png",
		"assets/characters/hero_beastmaster_?.glb",
		"assets/characters/hero_beastmaster_?.png",
		"assets/characters/hero_light_elf_?_starter.glb",
		"assets/characters/hero_light_elf_?_starter.png",
	],
	"heroes_human": [
		"assets/characters/hero_warrior_?.glb",
		"assets/characters/hero_warrior_?.png",
		"assets/characters/hero_shaman_?.glb",
		"assets/characters/hero_shaman_?.png",
		"assets/characters/hero_conjurer_?.glb",
		"assets/characters/hero_conjurer_?.png",
	],
	"npcs": [
		"assets/characters/npc_*.glb",
		"assets/characters/npc_*.png",
	],
	"creatures": [
		"assets/creatures/*_2.glb",
		"assets/creatures/*_2.png",
		"assets/creatures/*_3.glb",
		"assets/creatures/*_3.png",
	],
	# Мир: постройки и атласы (props.json — в APK), деревья, кусты, камни, текстуры окружения, овцы в загоне.
	"world": [
		"assets/props/*.glb",
		"assets/props/*.png",
		"assets/textures/*.png",
		"assets/creatures/sheep.glb",
		"assets/creatures/sheep.png",
	],
	# Звери 1-й стадии, рыбы, анатемы (стадии — creatures; creatures.json — в APK). Новый вид — шаблон сюда.
	"creatures_base": [
		"assets/creatures/panther.glb",
		"assets/creatures/panther.png",
		"assets/creatures/turtle.glb",
		"assets/creatures/turtle.png",
		"assets/creatures/pheasant.glb",
		"assets/creatures/pheasant.png",
		"assets/creatures/wolf.glb",
		"assets/creatures/wolf.png",
		"assets/creatures/centaur.glb",
		"assets/creatures/centaur.png",
		"assets/creatures/flyfish*.glb",
		"assets/creatures/flyfish*.png",
		"assets/creatures/anathema*.glb",
		"assets/creatures/anathema*.png",
	],
	# Оружие и предметы в руках (handheld.json — в APK).
	"handheld": [
		"assets/handheld/*.glb",
		"assets/handheld/*.png",
	],
	# Значки: предметы, умения героя и питомцев, интерфейс.
	"icons": [
		"assets/icons/*.png",
	],
	# Арты Dark Pact для экранов создания персонажа: расы, профессии, портреты (MenuKit.race_art и др.;
	# логотип и главный арт — в APK, assets/art/). Нет части — экраны без артов.
	"art": [
		"assets/art/pack/*.jpg",
		"assets/art/pack/*.png",
	],
}
## Порядок загрузки частей: сначала мир (с ним игра выглядит нормально), затем значки, оружие, звери; части не из
## списка (герои, жители, стадии, новые) — после, в порядке манифеста. По нему идут HTTPRequest (по очереди) и
## DownloadManager (все сразу, но в этом порядке).
const LOAD_ORDER := ["world", "icons", "handheld", "creatures_base"]
## Часть старого манифеста (один пакет на все файлы, до разбиения на части): подключена — готовы все части.
const ALL := "all"
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
## Записи о фоновых загрузках DownloadManager в папке кэша (не начинается с PACK_PREFIX — remove_old её не трогает).
const JOB_FILE := "download.cfg"
## Папка загрузки DownloadManager во внешней папке приложения (getExternalFilesDir).
const DOWNLOAD_DIR := "packs/"

## Папка кэша пакетов (тест подменяет на свою).
static var packs_dir := "user://packs/"
## Подключённые части: имя → путь файла (ALL — старый пакет целиком).
static var loaded: Dictionary = {}
## Все подключённые файлы (и прежние версии частей): их нельзя удалять, пока игра идёт.
static var loaded_files: Array = []
## Игрок выбрал «Играть без загрузки» в этом запуске.
static var skipped := false
## Тест: вести себя так, будто пакета нет (embedded и подключённые части не в счёт).
static var force_missing := false
## Тест: подставной плагин фоновой загрузки (те же методы, что у MyRappelzDownload); null — настоящий или нет.
static var plugin_override: Object = null
static var _embedded := -1
## part_of: путь → часть (PACKS не меняется).
static var _part_cache: Dictionary = {}


## Ресурсы пакета лежат прямо в res:// (не нужно ничего грузить). Проверяется один раз, до подключения частей.
static func embedded() -> bool:
	if _embedded < 0:
		_embedded = 1 if loaded.is_empty() and ResourceLoader.exists(PROBE) else 0
	return _embedded == 1


## Имена частей по порядку.
static func part_names() -> Array:
	return PACKS.keys()


## Части манифеста в порядке загрузки: сначала LOAD_ORDER, остальные — в прежнем порядке.
static func load_ordered(parts: Array) -> Array:
	var first: Array = []
	for n in LOAD_ORDER:
		for p in parts:
			if String((p as Dictionary).get("name", "")) == String(n):
				first.append(p)
	var out: Array = first.duplicate()
	for p in parts:
		if not first.has(p):
			out.append(p)
	return out


## Шаблоны всех частей (объединение).
static func all_filters() -> Array:
	var out: Array = []
	for n in PACKS:
		for f in PACKS[n]:
			out.append(String(f))
	return out


## Модели части доступны: встроены, часть подключена или подключён старый пакет целиком.
static func part_ready(part: String) -> bool:
	if force_missing:
		return false
	return embedded() or loaded.has(part) or loaded.has(ALL)


## Модели всех частей доступны.
static func available() -> bool:
	if force_missing:
		return false
	if embedded() or loaded.has(ALL):
		return true
	for n in PACKS:
		if not loaded.has(n):
			return false
	return true


## Сколько частей доступно (настройки: «загружен частично»).
static func ready_count() -> int:
	var n := 0
	for p in PACKS:
		if part_ready(String(p)):
			n += 1
	return n


## Тест: «пакета нет» (on) или как обычно; сбрасывает кэши наличия файлов.
static func simulate_missing(on: bool) -> void:
	force_missing = on
	reset_caches()


## Забыть, какие файлы пакета есть и что из них загружено (после подключения части или в тесте): модели зверей,
## постройки, текстуры, оружие, значки. Уже построенное не меняется — новое берёт файлы заново.
static func reset_caches() -> void:
	CreatureAsset.reset_cache()
	PropAsset.reset_cache()
	WorldTextures.reset_cache()
	Handheld.reset_cache()
	UiIcons.reset_cache()
	ItemIcon.reset_cache()
	SkillTree.reset_cache()


## Часть, в которой лежит файл (путь res://… или от корня проекта); "" — файл в APK.
static func part_of(path: String) -> String:
	var p := path.trim_prefix("res://")
	if _part_cache.has(p):
		return String(_part_cache[p])
	var out := ""
	for n in PACKS:
		for f in PACKS[n]:
			if out == "" and p.matchn(String(f)):
				out = String(n)
	_part_cache[p] = out
	return out


## Файл из пакета (любой части).
static func is_packed(path: String) -> bool:
	return part_of(path) != ""


## Есть ли ресурс: как ResourceLoader.exists, но файл части без этой части «не существует» (запасная модель).
static func exists(path: String) -> bool:
	var part := part_of(path)
	if part != "" and not part_ready(part):
		return false
	return ResourceLoader.exists(path)


## Версия игры (сборка APK пишет application/config/version), "" — неизвестна.
static func game_version() -> String:
	return String(ProjectSettings.get_setting("application/config/version", "")).strip_edges().trim_prefix("v")


## Адрес манифеста в релизе версии (пусто — версия неизвестна).
static func manifest_url(version: String = "") -> String:
	var v := version if version != "" else game_version()
	return RELEASES_URL % v if v != "" else ""


## Манифест из текста JSON → {version, parts: [{name, hash, sha256, size, url, file}]}; {} — неполный или битый.
static func parse_manifest(text: String) -> Dictionary:
	var d: Variant = JSON.parse_string(text)
	if not d is Dictionary:
		return {}
	return manifest_from(d as Dictionary)


## Манифест из словаря: новый формат (parts) или старый (один пакет — часть ALL). {} — неполный, битый, части
## повторяются.
static func manifest_from(m: Dictionary) -> Dictionary:
	var raw: Array = []
	if m.has("parts"):
		var list: Variant = m["parts"]
		if not list is Array:
			return {}
		raw = list
	else:
		var one := m.duplicate()
		one["name"] = ALL
		raw = [one]
	if raw.is_empty():
		return {}
	var parts: Array = []
	var names := {}
	for item in raw:
		if not item is Dictionary:
			return {}
		var part := _parse_part(item as Dictionary)
		if part.is_empty() or names.has(part["name"]):
			return {}
		names[part["name"]] = true
		parts.append(part)
	return {"version": str(m.get("version", "")), "parts": parts}


static func _parse_part(m: Dictionary) -> Dictionary:
	var name := str(m.get("name", "")).to_lower()
	var h := str(m.get("hash", "")).to_lower()
	var sha := str(m.get("sha256", "")).to_lower()
	var url := str(m.get("url", ""))
	var sz: Variant = m.get("size", 0)
	var size := int(sz) if (sz is int or sz is float) else 0
	if not _is_name(name) or not _is_hex(h, 16, 64) or not _is_hex(sha, 64, 64) or size <= 0 \
			or not url.begins_with("http"):
		return {}
	return {"name": name, "hash": h, "sha256": sha, "size": size, "url": url, "file": str(m.get("file", ""))}


## Части манифеста (массив словарей).
static func manifest_parts(m: Dictionary) -> Array:
	var p: Variant = m.get("parts", [])
	return p if p is Array else []


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


## Имя части: 1–32 знака a–z, 0–9, _.
static func _is_name(s: String) -> bool:
	if s.length() < 1 or s.length() > 32:
		return false
	for c in s:
		if not "abcdefghijklmnopqrstuvwxyz0123456789_".contains(c):
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


## Файл загрузки DownloadManager части относительно внешней папки приложения.
static func download_rel_path(part: String, content_hash: String) -> String:
	return DOWNLOAD_DIR + PACK_PREFIX + part + "-" + content_hash + ".pck.download"


## Записи о фоновых загрузках: часть → {hash, id, path}; {} — нет. Запись старой версии игры (одна загрузка,
## секция [job]) — под пустым именем части (не совпадёт ни с одной частью — её загрузка убирается).
static func read_jobs() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(packs_dir + JOB_FILE) != OK:
		return {}
	var out := {}
	for sec in cfg.get_sections():
		var part := ""
		if sec.begins_with("part."):
			part = sec.trim_prefix("part.")
		elif sec != "job":
			continue
		var h := str(cfg.get_value(sec, "hash", ""))
		var id := str(cfg.get_value(sec, "id", ""))
		if h == "" or id == "":
			continue
		out[part] = {"hash": h, "id": id, "path": str(cfg.get_value(sec, "path", ""))}
	return out


## Записать загрузки: часть → {hash, id, path}; пусто — файл удаляется.
static func save_jobs(jobs: Dictionary) -> void:
	if jobs.is_empty():
		clear_jobs()
		return
	ensure_dir()
	var cfg := ConfigFile.new()
	for part in jobs:
		var j: Dictionary = jobs[part]
		var sec := "part." + String(part)
		cfg.set_value(sec, "hash", str(j.get("hash", "")))
		cfg.set_value(sec, "id", str(j.get("id", "")))
		cfg.set_value(sec, "path", str(j.get("path", "")))
	cfg.save(packs_dir + JOB_FILE)


static func clear_jobs() -> void:
	remove_file(packs_dir + JOB_FILE)


## Путь части в кэше по хэшу содержимого (ALL — прежнее имя пакета целиком assets-<хэш>.pck).
static func pack_path(part: String, content_hash: String) -> String:
	if part == ALL:
		return packs_dir + PACK_PREFIX + content_hash + ".pck"
	return packs_dir + PACK_PREFIX + part + "-" + content_hash + ".pck"


## Временный файл загрузки части (после проверки переименовывается в pack_path).
static func part_path(part: String, content_hash: String) -> String:
	return pack_path(part, content_hash) + PART_SUFFIX


## Файл кэша части манифеста ({name, hash}).
static func pack_path_of(p: Dictionary) -> String:
	return pack_path(String(p["name"]), String(p["hash"]))


## Временный файл загрузки части манифеста.
static func part_path_of(p: Dictionary) -> String:
	return part_path(String(p["name"]), String(p["hash"]))


## Имя файла кэша → {part, hash, temp (недокачанный .part)}; {} — не файл пакета. assets-<хэш>.pck — часть ALL.
static func parse_cache_name(file: String) -> Dictionary:
	if not file.begins_with(PACK_PREFIX):
		return {}
	var s := file.trim_prefix(PACK_PREFIX)
	var temp := s.ends_with(".pck" + PART_SUFFIX)
	if temp:
		s = s.trim_suffix(PART_SUFFIX)
	if not s.ends_with(".pck"):
		return {}
	s = s.trim_suffix(".pck")
	var i := s.rfind("-")
	if i < 0:
		return {"part": ALL, "hash": s, "temp": temp}
	return {"part": s.substr(0, i), "hash": s.substr(i + 1), "temp": temp}


static func ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(packs_dir)


## Размер файла в байтах (-1 — нет файла).
static func file_size(path: String) -> int:
	if not FileAccess.file_exists(path):
		return -1
	var f := FileAccess.open(path, FileAccess.READ)
	return int(f.get_length()) if f != null else -1


## Готовый файл части манифеста в кэше (размер совпадает), "" — нет.
static func cached_pack(p: Dictionary) -> String:
	var path := pack_path_of(p)
	var sz := file_size(path)
	if sz < 0:
		return ""
	if int(p.get("size", 0)) > 0 and sz != int(p["size"]):
		return ""
	return path


## Части манифеста, которых нет в кэше (в порядке загрузки: LOAD_ORDER, затем по порядку манифеста).
static func missing_parts(m: Dictionary) -> Array:
	var out: Array = []
	for p in load_ordered(manifest_parts(m)):
		if cached_pack(p) == "":
			out.append(p)
	return out


## Сколько байт у частей.
static func parts_size(parts: Array) -> int:
	var n := 0
	for p in parts:
		n += int((p as Dictionary).get("size", 0))
	return n


## Файлы папки кэша (имена).
static func _cache_files() -> PackedStringArray:
	var d := DirAccess.open(packs_dir)
	if d == null:
		return PackedStringArray()
	return d.get_files()


## Какая-нибудь версия части в кэше (готовый файл, не недокачанный) — для «Играть без загрузки»; "" — нет.
static func any_cached(part: String) -> String:
	for f in _cache_files():
		var info := parse_cache_name(f)
		if not info.is_empty() and String(info["part"]) == part and not bool(info["temp"]):
			return packs_dir + f
	return ""


## Удалить из кэша прежние версии части и её недокачанные файлы (кроме файла keep_hash и подключённых).
## Сколько удалено.
static func remove_old(part: String, keep_hash: String) -> int:
	var n := 0
	for f in _cache_files():
		var info := parse_cache_name(f)
		if info.is_empty() or String(info["part"]) != part:
			continue
		if not bool(info["temp"]) and String(info["hash"]) == keep_hash:
			continue
		if loaded_files.has(packs_dir + f):
			continue
		if DirAccess.remove_absolute(packs_dir + f) == OK:
			n += 1
	return n


## Все части манифеста в кэше: удалить остальное (прежние версии, части прошлых разбиений, старый пакет целиком,
## недокачанные файлы), кроме подключённых. Сколько удалено.
static func remove_stale(m: Dictionary) -> int:
	var keep := {}
	for p in manifest_parts(m):
		keep[pack_path_of(p).get_file()] = true
	var n := 0
	for f in _cache_files():
		if not f.begins_with(PACK_PREFIX) or keep.has(f) or loaded_files.has(packs_dir + f):
			continue
		if DirAccess.remove_absolute(packs_dir + f) == OK:
			n += 1
	return n


## Сколько байт освободит remove_stale (прежние версии, старый пакет целиком; подключённые не в счёт).
static func stale_size(m: Dictionary) -> int:
	var keep := {}
	for p in manifest_parts(m):
		keep[pack_path_of(p).get_file()] = true
	var n := 0
	for f in _cache_files():
		if f.begins_with(PACK_PREFIX) and not keep.has(f) and not loaded_files.has(packs_dir + f):
			n += maxi(file_size(packs_dir + f), 0)
	return n


static func remove_file(path: String) -> void:
	if path != "" and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Проверенный временный файл части → файл кэша (переименование), прежние версии части удаляются. Путь или "".
static func install(part: String, content_hash: String) -> String:
	var tmp := part_path(part, content_hash)
	var dst := pack_path(part, content_hash)
	if not FileAccess.file_exists(tmp):
		return ""
	remove_file(dst)
	if DirAccess.rename_absolute(tmp, dst) != OK:
		return ""
	remove_old(part, content_hash)
	return dst


## Подключить часть: её файлы появляются в res:// по своим путям (файлы APK и уже подключённые не заменяются).
## Подключена прежняя версия части — новая подключается поверх (её новые файлы появятся, прежние останутся до
## перезапуска). false — файл не читается.
static func load_part(part: String, path: String) -> bool:
	embedded()
	if path == "":
		return false
	if loaded_files.has(path):
		loaded[part] = path
		return true
	if not ProjectSettings.load_resource_pack(path, false):
		return false
	loaded[part] = path
	loaded_files.append(path)
	reset_caches()
	return true


## Подключена другая версия этой части (или старый пакет целиком): новая версия заменит модели только после
## перезапуска игры.
static func clashes(p: Dictionary) -> bool:
	var part := String(p["name"])
	if part != ALL and loaded.has(ALL):
		return true
	return loaded.has(part) and String(loaded[part]) != pack_path_of(p)


## «Играть без загрузки»: подключить то, что есть в кэше, — сначала части версии манифеста, затем прежние версии
## частей, затем старый пакет целиком (файлы, подключённые раньше, не заменяются). true — подключено хоть что-то.
static func load_cached(m: Dictionary) -> bool:
	var names: Array = part_names()
	for p in manifest_parts(m):
		var path := cached_pack(p)
		if path != "":
			load_part(String(p["name"]), path)
		if not names.has(p["name"]):
			names.append(p["name"])
	for n in names:
		if String(n) != ALL and not loaded.has(n):
			var old := any_cached(String(n))
			if old != "":
				load_part(String(n), old)
	if not loaded.has(ALL):
		var covered := true
		for n in PACKS:
			if not loaded.has(n):
				covered = false
		var whole := any_cached(ALL) if not covered else ""
		if whole != "":
			load_part(ALL, whole)
	return not loaded.is_empty()


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
