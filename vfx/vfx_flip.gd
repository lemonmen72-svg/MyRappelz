class_name VfxFlip
extends RefCounted
## Раскадровки эффектов (flipbook, 0.46.1): листы Максима из ChatGPT (промты — tools/Промты_раскадровки_эффектов.docx)
## после tools/prepare_flipbook.py — vfx/flip/fx_<id>[_N].png: сетка кадров одной анимации (4×4 по 256 px), яркость —
## оттенки серого. Импорт Godot «Image»: в пакете ресурсов лежит сам PNG, раскодирует игра в фоновом потоке, в
## видеопамяти — L8 с мипмапами (≈ 1.4 МБ на лист). vfx/flip/flipbooks.json — вид, опора, кадры, яркость, варианты.
## Слой эффекта строит VfxKit.flipbook (квад с шейдером VfxMat в режиме раскадровки, цвет — палитра стихии), листы
## берут архетипы VfxArchetypes (_flip) и прежние эффекты Vfx (удар, искра). Листы — часть пакета «vfx»: нет части,
## листа или он ещё не загружен — эффект рисует прежние слои (откат). Загрузка: prewarm_world (вход в мир — листы
## умений героя, его питомцев и зверей) и по первому требованию (pick → пусто, лист грузится в фоне).

const DIR := "res://vfx/flip/"
const META := "res://vfx/flip/flipbooks.json"
## Листов в видеопамяти не больше этого: лишние — давно не нужные (живые эффекты держат свой лист сами).
const MAX_LOADED := 30
## Архетип VfxArchetypes → листы, которые он может взять (загрузить заранее). "orb" — снаряд, "basic" — удары и
## искры обычных атак (Vfx.slash_arc, Vfx.hit_spark).
const ARCH_SHEETS := {
	"explosion": ["explosion"], "flame_burst": ["flame_burst", "burn_loop"], "frost_nova": ["frost_nova"],
	"ice_shards": ["ice_shards"], "water_splash": ["water_splash"], "water_wave": ["water_splash"],
	"rock_impact": ["rock_impact"], "ground_spike": ["ground_spikes"], "shockwave": ["rock_impact"],
	"lightning_strike": ["lightning_strike"], "lightning_bolt": ["lightning_arc", "hit_spark"],
	"spark_hit": ["hit_spark"], "heal_burst": ["heal_burst", "heal_rise"], "holy_beam": ["holy_beam"],
	"shield": ["shield_bubble"], "blessing": ["blessing"],
	"buff_up": ["buff_up", "haste", "aura_ring"], "shadow_burst": ["shadow_burst"], "cursed_sigil": ["shadow_burst"],
	"soul_drain": ["soul_drain"], "toxic_pool": ["poison_cloud"],
	"blood_burst": ["blood_burst"], "ritual_circle": ["aura_ring"], "ghost": ["spirit_burst"],
	"wind_slash": ["wind_slash"], "tornado": ["tornado"], "slash": ["slash_arc", "slash_cross", "crit_flash"],
	"cleave": ["cleave", "crit_flash"], "stab": ["stab"], "blunt_hit": ["blunt_impact"], "spin_slash": ["spin_slash"],
	"arrow_impact": ["arrow_impact"], "claw": ["claw"], "roar": ["roar"], "spirit_burst": ["spirit_burst"],
	"cast_gather": ["cast_gather"], "release": ["cast_release"], "orb": ["magic_orb"],
	"basic": ["slash_arc", "hit_spark", "claw"],
}

## Листы включены (false — везде прежние слои; админ-панель «Тест-бот» → «Эффекты»).
static var enabled := true
## Тест: грузить лист сразу, а не в фоновом потоке.
static var sync_load := false
## Сколько листов загружено с запуска (тест, отчёт).
static var loads := 0
static var _meta := {}
static var _meta_ok := false
static var _tex := {}
static var _used := {}
static var _imgs := {}
static var _bad := {}
static var _ok := {}
static var _want: Array = []
static var _lock := Mutex.new()
static var _task := -1
static var _rng := RandomNumberGenerator.new()


## Метаданные всех листов: id → {title, order, kind, view, files: [{file, view, grid, frames, pivot, hot, peak,
## loop, energy, variant}]}.
static func meta() -> Dictionary:
	if not _meta_ok:
		_meta_ok = true
		_meta = {}
		if FileAccess.file_exists(META):
			var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(META))
			if v is Dictionary:
				var sh: Variant = (v as Dictionary).get("sheets", {})
				if sh is Dictionary:
					_meta = sh
	return _meta


static func info(id: String) -> Dictionary:
	return meta().get(id, {})


static func files_of(id: String) -> Array:
	return info(id).get("files", [])


## Лист id есть в игре: метаданные и файл в подключённой части пакета (без части «vfx» — нет).
static func has(id: String) -> bool:
	if not enabled:
		return false
	var fl := files_of(id)
	return not fl.is_empty() and file_ok(String((fl[0] as Dictionary).get("file", "")))


## Файл листа есть (в подключённой части пакета или в res:// редактора и автотестов); запоминается.
static func file_ok(file: String) -> bool:
	if not _ok.has(file):
		_ok[file] = Assets.exists(DIR + file)
	return bool(_ok[file])


## Вариант листа id для эффекта: variant ≥ 1 — этот, иначе случайный из загруженных. {rec, tex} или {} (листа нет
## или он ещё грузится — тогда загрузка запрошена).
static func pick(id: String, variant: int = -1, rng: RandomNumberGenerator = null) -> Dictionary:
	if not has(id):
		return {}
	var ready: Array = []
	for r in files_of(id):
		var rec: Dictionary = r
		if variant >= 1 and int(rec.get("variant", 1)) != variant:
			continue
		var f := String(rec.get("file", ""))
		if not file_ok(f):
			continue
		var t := texture(f)
		if t != null:
			ready.append({"rec": rec, "tex": t})
	if ready.is_empty():
		return {}
	var g := rng if rng != null else _rng
	return ready[g.randi() % ready.size()]


## Текстура листа (файл в vfx/flip) или null — тогда загрузка запрошена (в фоне; у теста sync_load — сразу).
static func texture(file: String) -> Texture2D:
	if _tex.has(file):
		_used[file] = Time.get_ticks_msec()
		return _tex[file]
	if _bad.has(file):
		return null
	poll()
	var got: Variant = null
	_lock.lock()
	if _imgs.has(file):
		got = _imgs[file]
		_imgs.erase(file)
	_lock.unlock()
	if got == null and sync_load:
		got = _decode(file)
		if got == null:
			got = false
	if got == null:
		request([file])
		return null
	if not (got is Image):
		_bad[file] = true
		return null
	var t := ImageTexture.create_from_image(got)
	_tex[file] = t
	_used[file] = Time.get_ticks_msec()
	loads += 1
	_evict()
	return t


## Лист готов к показу: текстура есть или картинка уже раскодирована в фоне (текстура — при первом показе).
static func ready(file: String) -> bool:
	if _tex.has(file):
		return true
	poll()
	_lock.lock()
	var got: Variant = _imgs.get(file, null)
	_lock.unlock()
	return got is Image


## Загрузить листы (файлы) в фоне, если их ещё нет.
static func request(files: Array) -> void:
	for f in files:
		var fs := String(f)
		if fs == "" or _tex.has(fs) or _bad.has(fs) or fs in _want:
			continue
		_lock.lock()
		var have := _imgs.has(fs)
		_lock.unlock()
		if not have:
			_want.append(fs)
	poll()


## Загрузить заранее все варианты листов ids.
static func prewarm(ids: Array) -> void:
	if not enabled:
		return
	var files: Array = []
	for id in ids:
		if not has(String(id)):
			continue
		for r in files_of(String(id)):
			files.append(String((r as Dictionary).get("file", "")))
	request(files)


## Вход в мир: листы умений профессии героя, его питомцев, зверей и обычных атак — в фоне, пока игрок осматривается.
static func prewarm_world() -> void:
	if not enabled:
		return
	var arches := {"release": true, "cast_gather": true, "orb": true, "basic": true, "spark_hit": true}
	var tab := SkillVfx.table()
	var hero: Dictionary = tab.get("hero", {})
	for sid in HeroSkills.list_for(Game.class_id):
		_arches_of(hero.get(String(sid), {}), arches)
	var species := {}
	for rec in Game.pets:
		species[String((rec as Dictionary).get("species", ""))] = true
	var pets: Dictionary = tab.get("pet", {})
	for k in pets:
		if species.has(String(k).get_slice(":", 0)):
			_arches_of(pets[k], arches)
	var mobs: Dictionary = tab.get("mob", {})
	for k in mobs:
		_arches_of(mobs[k], arches)
	prewarm(sheets_for(arches.keys()))


static func _arches_of(entry: Variant, out: Dictionary) -> void:
	if not (entry is Dictionary):
		return
	for ph in (entry as Dictionary):
		var e: Variant = entry[ph]
		if e is Dictionary and (e as Dictionary).has("arch"):
			out[String(e["arch"])] = true
		elif ph == "proj":
			out["orb"] = true


## Листы архетипов arches (ARCH_SHEETS), без повторов.
static func sheets_for(arches: Array) -> Array:
	var out: Array = []
	for a in arches:
		for id in ARCH_SHEETS.get(String(a), []):
			if not String(id) in out:
				out.append(String(id))
	return out


## Фоновый поток: закончил — освободить задачу; есть ещё запрошенные — следующий поток.
static func poll() -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	if _task < 0 and not _want.is_empty():
		var batch := _want.duplicate()
		_want.clear()
		_task = WorkerThreadPool.add_task(_work.bind(batch), false, "VfxFlip sheets")


## Дождаться фонового потока (выход из сцены: скрипт не выгружается под потоком).
static func finish() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


## Загрузка идёт или ждёт очереди.
static func busy() -> bool:
	poll()
	return _task >= 0 or not _want.is_empty()


static func _work(files: Array) -> void:
	for f in files:
		var img := _decode(String(f))
		_lock.lock()
		_imgs[String(f)] = img if img != null else false
		_lock.unlock()


## Раскодировать лист (можно в фоновом потоке): L8 с мипмапами.
static func _decode(file: String) -> Image:
	var path := DIR + file
	if not ResourceLoader.exists(path):
		return null
	var img := ResourceLoader.load(path, "Image", ResourceLoader.CACHE_MODE_IGNORE) as Image
	if img == null or img.is_empty():
		return null
	if img.get_format() != Image.FORMAT_L8:
		img.convert(Image.FORMAT_L8)
	if not img.has_mipmaps():
		img.generate_mipmaps()
	return img


static func _evict() -> void:
	if _tex.size() <= MAX_LOADED:
		return
	var order: Array = _tex.keys()
	order.sort_custom(func(x: Variant, y: Variant) -> bool: return int(_used.get(x, 0)) < int(_used.get(y, 0)))
	while _tex.size() > MAX_LOADED and not order.is_empty():
		var f: Variant = order.pop_front()
		_tex.erase(f)
		_used.erase(f)


## Сколько листов в видеопамяти (тест, отчёт).
static func loaded_count() -> int:
	return _tex.size()


## Забыть загруженное (тест; подключилась часть пакета — Assets.reset_caches).
static func reset() -> void:
	finish()
	_tex.clear()
	_used.clear()
	_bad.clear()
	_ok.clear()
	_want.clear()
	_lock.lock()
	_imgs.clear()
	_lock.unlock()
	_meta_ok = false
	_meta = {}
