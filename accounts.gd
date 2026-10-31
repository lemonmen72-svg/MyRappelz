class_name Accounts
extends RefCounted
## Аккаунты и слоты персонажей. Пока хранятся на устройстве (решение Максима: сервер — с началом бета-теста),
## интерфейс узкий, чтобы потом заменить хранилище сервером: create, login, logout, list_slots, save_slot,
## load_slot, delete_slot (+ проверки логина и ника, перенос старого сохранения).
## Вход — только по логину (пароль появится вместе с сервером: параметр password уже есть, сейчас не хранится).
## Файлы: <dir>accounts.json — {"accounts": {ключ: {"login": как набран, "created": unix-время}}, "last": логин};
## персонаж — <dir>accounts/<ключ>/slot<1..4>.json (то, что пишет Game.to_dict). Ключ — логин в нижнем регистре.
## На аккаунт SLOTS (4) персонажа, ник уникален среди всех персонажей устройства (без учёта регистра).
## Админ-панель — только у логина ADMIN_LOGIN (Dedok_max, без учёта регистра; AdminPanel.enabled).
## Тесты переключают хранилище (use_storage) — настоящие аккаунты и старый save.json не трогаются.

const SLOTS := 4
const ADMIN_LOGIN := "dedok_max"
const DEFAULT_DIR := "user://"
## Сохранение до аккаунтов (один герой): при первом входе в аккаунт без персонажей становится слотом 1.
const LEGACY_FILE := "save.json"
const NAME_MIN := 3
const NAME_MAX := 16
## Подсказка к правилам логина и ника.
const NAME_RULES := "3–16 символов: русские или латинские буквы, цифры, _"

## Папка хранилища (с «/» в конце).
static var dir := DEFAULT_DIR
## Вошедший аккаунт (логин как набран при создании; "" — никто).
static var current := ""


## Хранилище в папке path (тесты: "user://test_accounts/"); wipe — стереть всё, что там было. Выход из аккаунта.
static func use_storage(path: String, wipe: bool = false) -> void:
	dir = path if path.ends_with("/") else path + "/"
	current = ""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	if wipe and dir != DEFAULT_DIR:
		_remove_tree(dir + "accounts")
		for f in ["accounts.json", LEGACY_FILE, LEGACY_FILE + ".bak"]:
			if FileAccess.file_exists(dir + String(f)):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + String(f)))


## Ключ логина (и ника для сравнения): без пробелов по краям, в нижнем регистре.
static func key(text: String) -> String:
	return text.strip_edges().to_lower()


static func legacy_path() -> String:
	return dir + LEGACY_FILE


static func slot_path(i: int, login_name: String = "") -> String:
	return dir + "accounts/" + key(login_name if login_name != "" else current) + "/slot%d.json" % (i + 1)


# ---------- Правила имён ----------

## Почему text не годится в логин или ник ("" — годится): длина NAME_MIN…NAME_MAX, буквы русские и латинские,
## цифры, «_».
static func name_error(text: String, what: String = "Ник") -> String:
	var t := text.strip_edges()
	if t.length() < NAME_MIN or t.length() > NAME_MAX:
		return "%s: от %d до %d символов" % [what, NAME_MIN, NAME_MAX]
	for i in t.length():
		var c := t.unicode_at(i)
		var latin := (c >= 0x30 and c <= 0x39) or (c >= 0x41 and c <= 0x5A) or (c >= 0x61 and c <= 0x7A) or c == 0x5F
		var cyr := (c >= 0x410 and c <= 0x44F) or c == 0x401 or c == 0x451
		if not (latin or cyr):
			return "%s: только русские или латинские буквы, цифры и _" % what
	return ""


# ---------- Аккаунты ----------

static func exists(login_name: String) -> bool:
	return (_index().get("accounts", {}) as Dictionary).has(key(login_name))


## Создать аккаунт и войти в него. "" — получилось, иначе причина. password — на будущее (сервер), сейчас не хранится.
static func create(login_name: String, password: String = "") -> String:
	var l := login_name.strip_edges()
	var err := name_error(l, "Логин")
	if err != "":
		return err
	if exists(l):
		return "Логин «%s» уже занят" % l
	var idx := _index()
	var accs: Dictionary = idx.get("accounts", {})
	accs[key(l)] = {"login": l, "created": int(Time.get_unix_time_from_system())}
	idx["accounts"] = accs
	if not _write_index(idx):
		return "Не удалось сохранить аккаунт"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir + "accounts/" + key(l)))
	return login(l, password)


## Войти в существующий аккаунт. "" — получилось, иначе причина. password — на будущее (сервер).
static func login(login_name: String, password: String = "") -> String:
	var l := login_name.strip_edges()
	if l == "":
		return "Введите логин"
	var accs: Dictionary = _index().get("accounts", {})
	if not accs.has(key(l)):
		return "Аккаунта «%s» нет на этом устройстве — создайте его" % l
	var rec: Dictionary = accs[key(l)]
	current = String(rec.get("login", l))
	var idx := _index()
	idx["last"] = current
	_write_index(idx)
	return ""


static func logout() -> void:
	current = ""


static func is_logged_in() -> bool:
	return current != ""


## Последний вошедший логин (подставляется на экране входа).
static func last_login() -> String:
	return String(_index().get("last", ""))


## Логин администратора (админ-панель): Dedok_max без учёта регистра. login "" — вошедший аккаунт.
static func is_admin(login_name: String = "") -> bool:
	return key(login_name if login_name != "" else current) == ADMIN_LOGIN


# ---------- Слоты ----------

## Слоты вошедшего аккаунта: SLOTS записей, пустой слот — {}, занятый — сводка (summary).
static func list_slots() -> Array:
	var res: Array = []
	for i in SLOTS:
		var d := load_slot(i)
		res.append(summary(d) if not d.is_empty() else {})
	return res


## Сводка персонажа для карточки: name, race, class, level, gender.
static func summary(d: Dictionary) -> Dictionary:
	return {
		"name": String(d.get("name", "Герой")), "race": String(d.get("race", ClassData.HERO_RACE)),
		"class": ClassData.migrate_id(String(d.get("class", ClassData.WANDERER))), "level": int(d.get("level", 1)),
		"gender": String(d.get("gender", "f")),
	}


## Первый пустой слот (-1 — все SLOTS заняты).
static func free_slot() -> int:
	for i in SLOTS:
		if not FileAccess.file_exists(slot_path(i)):
			return i
	return -1


static func has_characters() -> bool:
	for i in SLOTS:
		if FileAccess.file_exists(slot_path(i)):
			return true
	return false


static func save_slot(i: int, data: Dictionary) -> bool:
	if current == "" or i < 0 or i >= SLOTS:
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir + "accounts/" + key(current)))
	var f := FileAccess.open(slot_path(i), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


## Данные персонажа слота i ({} — пусто или файл испорчен).
static func load_slot(i: int, login_name: String = "") -> Dictionary:
	if (login_name == "" and current == "") or i < 0 or i >= SLOTS:
		return {}
	return _read_json(slot_path(i, login_name))


static func delete_slot(i: int) -> bool:
	if current == "" or i < 0 or i >= SLOTS or not FileAccess.file_exists(slot_path(i)):
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(i))) == OK


## Занят ли ник среди всех персонажей устройства (без учёта регистра); except_* — свой слот (не считается).
static func nick_taken(nick: String, except_login: String = "", except_slot: int = -1) -> bool:
	var n := key(nick)
	for k in (_index().get("accounts", {}) as Dictionary):
		for i in SLOTS:
			if String(k) == key(except_login) and i == except_slot:
				continue
			var d := load_slot(i, String(k))
			if not d.is_empty() and key(String(d.get("name", ""))) == n:
				return true
	return false


## Почему nick нельзя дать новому персонажу ("" — можно): правила и уникальность.
static func nick_error(nick: String) -> String:
	var err := name_error(nick, "Ник")
	if err != "":
		return err
	if nick_taken(nick):
		return "Ник «%s» уже занят" % nick.strip_edges()
	return ""


## Перенос сохранения до аккаунтов: есть <dir>save.json, а у вошедшего аккаунта нет персонажей — файл становится
## слотом 1 (имя героя сохраняется), прежний файл переименовывается в save.json.bak. Возвращает слот или -1.
static func migrate_legacy() -> int:
	if current == "" or not FileAccess.file_exists(legacy_path()):
		return -1
	if has_characters():
		return -1
	var d := _read_json(legacy_path())
	if d.is_empty() or not save_slot(0, d):
		return -1
	var bak := legacy_path() + ".bak"
	if FileAccess.file_exists(bak):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(bak))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(legacy_path()), ProjectSettings.globalize_path(bak))
	return 0


# ---------- Файлы ----------

static func _index() -> Dictionary:
	var d := _read_json(dir + "accounts.json")
	if not (d.get("accounts", null) is Dictionary):
		d["accounts"] = {}
	return d


static func _write_index(d: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var f := FileAccess.open(dir + "accounts.json", FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
	return true


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary else {}


## Удалить папку path со всем содержимым (только хранилище тестов).
static func _remove_tree(path: String) -> void:
	var da := DirAccess.open(path)
	if da == null:
		return
	for sub in da.get_directories():
		_remove_tree(path + "/" + String(sub))
	for f in da.get_files():
		da.remove(String(f))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
