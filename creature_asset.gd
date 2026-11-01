class_name CreatureAsset
extends Node3D
## Зверь или питомец — модель из файла (Meshy AI: меш на скелете и свои анимации).
## Строит её CreatureModels.build(), если файл вида есть (иначе — запасная модель из примитивов).
##
## Контракт ассета (assets/creatures/):
## - <id>.glb: скелет (узел «Armature», после импорта Skeleton3D), AnimationPlayer, клипы Idle, Walk, Run,
##   Attack, Hit, Death, Cast (регистр и приставки вида «Armature|» не важны, любой клип может отсутствовать).
##   Морда смотрит в +Z (в игре перед — −Z, модель внутри повёрнута на PI), ноги на y = 0, размеры в метрах.
## - <id>.png: цветовая текстура. Встроенные картинки GLB при импорте отбрасываются, материал свой:
##   toon, без металла, эмиссия для вспышки урона, контур по нормалям (если Quality.outlines()).
## - creatures.json: {id: {height, length, width, walk_speed, run_speed, attack_hit_time,
##   clips: {имя: длина}, bones: {...}}}. Нет файла или поля — значения из DEFAULTS.
## - Стадии эволюции питомца: <вид>_2.glb, <вид>_3.glb (+ .png, запись в creatures.json) — своя модель 2-й и 3-й
##   стадии (model_for). Её высота — «база» (как у 1-й стадии при масштабе 1), крупнее делает игра
##   (PetData.stage_scale). Нет файла стадии — модель 1-й стадии с процедурными украшениями (decorate).
##   Дикие звери в мире — всегда 1-я стадия.
##
## Узел масштабируется на s (питомцы и стадии эволюции). Для Mob и Pet:
## update(delta, скорость м/с) каждый кадр — Idle / Walk / Run (speed_scale = скорость / скорость клипа);
## play_attack() — через сколько секунд удар; play_hit(); play_cast(); play_death() — сколько длится;
## set_sleeping() — AnimationPlayer стоит, пока зверь спит; decorate() — украшения питомца;
## material — материал для вспышки урона (CreatureModels.flash).

const DIR := "res://assets/creatures/"
const INFO_PATH := "res://assets/creatures/creatures.json"
## Значения по умолчанию: высота, длина, ширина (м, при s = 1), скорости, при которых клипы шага и бега
## идут без проскальзывания (м/с), момент удара в клипе Attack (с от начала).
## hover — у летающих (рыбы) высота оси тела над землёй: модель парит уже в файле (поза покоя и все клипы,
## кроме Death — он роняет её на землю), height у них — верх модели над землёй; 0 — зверь ходит по земле.
const BASE_INFO := {
	"height": 1.0, "length": 1.2, "width": 0.6, "walk_speed": 1.5, "run_speed": 4.0, "attack_hit_time": 0.4,
	"hover": 0.0,
}
## Виды с моделью из файла и их размеры, если creatures.json нет. По этим же размерам строится
## запасная модель из примитивов, коллизия и высота подписи.
const DEFAULTS := {
	"panther": {"height": 1.15, "length": 1.9, "width": 0.5, "walk_speed": 1.6, "run_speed": 5.0,
		"attack_hit_time": 0.45},
	"turtle": {"height": 0.85, "length": 1.3, "width": 0.95, "walk_speed": 0.6, "run_speed": 1.4,
		"attack_hit_time": 0.5},
	"pheasant": {"height": 0.85, "length": 1.1, "width": 0.4, "walk_speed": 1.0, "run_speed": 3.0,
		"attack_hit_time": 0.35},
	"wolf": {"height": 0.95, "length": 1.4, "width": 0.35, "walk_speed": 0.65, "run_speed": 4.2,
		"attack_hit_time": 0.36},
	# Овца в загоне деревни людей (PenSheep, не зверь для боя): шаг медленный
	"sheep": {"height": 0.95, "length": 1.14, "width": 0.82, "walk_speed": 0.25, "run_speed": 0.8,
		"attack_hit_time": 0.25},
	# Кентавр (стиль «centaur»): высота — до наконечника копья
	"centaur": {"height": 2.25, "length": 1.66, "width": 0.8, "walk_speed": 0.85, "run_speed": 3.92,
		"attack_hit_time": 0.42},
	# Летающие рыбы (tools/prepare_creatures.py, стиль «fish»): парят на уровне головы героя
	"flyfish": {"height": 1.84, "length": 1.0, "width": 0.61, "walk_speed": 1.4, "run_speed": 4.0,
		"attack_hit_time": 0.42, "hover": 1.45},
	"flyfish_sail": {"height": 2.0, "length": 1.4, "width": 0.32, "walk_speed": 1.5, "run_speed": 4.4,
		"attack_hit_time": 0.42, "hover": 1.5},
	"flyfish_drake": {"height": 2.17, "length": 1.8, "width": 1.25, "walk_speed": 1.5, "run_speed": 4.2,
		"attack_hit_time": 0.42, "hover": 1.55},
	# Анатемы — двуногие ящеры (tools/prepare_creatures.py, стиль «biped»: клипы Quaternius UAL); ширина — с клинками
	"anathema": {"height": 1.9, "length": 0.55, "width": 0.89, "walk_speed": 0.92, "run_speed": 5.72,
		"attack_hit_time": 0.23},
	"anathema_blade": {"height": 2.0, "length": 0.64, "width": 0.98, "walk_speed": 1.0, "run_speed": 5.71,
		"attack_hit_time": 0.23},
	"anathema_chief": {"height": 2.2, "length": 0.72, "width": 1.31, "walk_speed": 1.16, "run_speed": 6.94,
		"attack_hit_time": 0.27},
}
## Окончания моделей стадий эволюции: стадия 1 (в коде 0..2) → "_2", стадия 2 → "_3".
const STAGE_SUFFIX := ["", "_2", "_3"]
const CLIPS := ["idle", "walk", "run", "attack", "hit", "death", "cast"]
const LOOPED := ["idle", "walk", "run"]
## Цвет эмиссии в начале вспышки урона.
const FLASH := Color(0.8, 0.8, 0.8)
## Самая долгая реакция на урон и смерть, с (длинные клипы ускоряются).
const HIT_MAX := 0.6
const DEATH_MAX := 2.2
## Толщина контура (тоньше, чем у героя: звери мельче на экране).
const OUTLINE_WIDTH := 0.01

## false — всегда запасные модели из примитивов (тесты).
static var use_assets := true
static var _exists := {}
static var _json: Dictionary = {}
static var _json_loaded := false
static var _infos := {}
static var _outline: ShaderMaterial

var species := ""
## Своя модель стадии эволюции (<вид>_2 / <вид>_3): процедурные украшения стадии ей не нужны.
var stage_model := false
## Размеры и скорости вида (info_for).
var info: Dictionary = {}
var material: StandardMaterial3D
var anim: AnimationPlayer = null
var skeleton: Skeleton3D = null
## Ключ клипа ("idle", "walk", …) → имя анимации в AnimationPlayer.
var clips := {}

var _model: Node3D
var _s := 1.0
var _loco := ""
var _act_left := 0.0
var _speed := 0.0
var _dead := false
var _t := 0.0
var _head_bone := -1
var _skel_xf := Transform3D.IDENTITY
var _decor: Node3D = null
var _charm: Node3D = null
var _halo: Node3D = null
# AnimationPlayer крутится, только пока зверь не спит и виден на экране (бережём процессор телефона)
var _asleep := false
var _onscreen := true


## Путь к модели вида.
static func path_for(id: String) -> String:
	return DIR + id + ".glb"


## Вид, для которого предусмотрена модель из файла (есть размеры в DEFAULTS), даже если файла пока нет.
## id модели стадии («panther_2») — по своему виду.
static func is_asset_species(id: String) -> bool:
	return DEFAULTS.has(species_of(id))


## Вид по id модели: «panther_3» → «panther», «panther» → «panther».
static func species_of(model_id: String) -> String:
	for i in range(1, STAGE_SUFFIX.size()):
		var suf := String(STAGE_SUFFIX[i])
		if model_id.ends_with(suf) and DEFAULTS.has(model_id.trim_suffix(suf)):
			return model_id.trim_suffix(suf)
	return model_id


## Модель вида на стадии эволюции stage (0..2): «<вид>_2» / «<вид>_3», если её файл есть, иначе сам вид
## (модель 1-й стадии или запасная из примитивов).
static func model_for(id: String, stage: int) -> String:
	if stage <= 0 or stage >= STAGE_SUFFIX.size():
		return id
	var mid := id + String(STAGE_SUFFIX[stage])
	return mid if has_asset(mid) else id


## Есть ли файл модели вида (и модели из файлов не выключены). Модели стадий лежат в пакете ресурсов
## (Assets): без пакета их «нет» — берётся модель 1-й стадии.
static func has_asset(id: String) -> bool:
	if not use_assets or id == "":
		return false
	if not _exists.has(id):
		_exists[id] = Assets.exists(path_for(id))
	return bool(_exists[id])


## Забыть, какие файлы моделей есть (после загрузки пакета ресурсов Assets).
static func reset_cache() -> void:
	_exists.clear()


## Размеры, скорости, клипы и кости вида: creatures.json поверх DEFAULTS и BASE_INFO.
static func info_for(id: String) -> Dictionary:
	if _infos.has(id):
		return _infos[id]
	_load_json()
	var r: Dictionary = BASE_INFO.duplicate()
	r.merge(DEFAULTS.get(species_of(id), {}), true)
	r["clips"] = {}
	r["bones"] = {}
	var j = _json.get(id)
	if j is Dictionary:
		var jd: Dictionary = j
		for k in BASE_INFO:
			var v = jd.get(k)
			if (v is float or v is int) and float(v) > 0.0:
				r[k] = float(v)
		if jd.get("clips") is Dictionary:
			r["clips"] = jd["clips"]
		if jd.get("bones") is Dictionary:
			r["bones"] = jd["bones"]
	for k in BASE_INFO:
		r[k] = float(r[k])
	_infos[id] = r
	return r


static func _load_json() -> void:
	if _json_loaded:
		return
	_json_loaded = true
	if not FileAccess.file_exists(INFO_PATH):
		return
	var f := FileAccess.open(INFO_PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		_json = d


## Высота макушки над землёй при масштабе s.
static func height_for(id: String, s: float) -> float:
	return float(info_for(id)["height"]) * s


## Высота оси тела парящего зверя над землёй при масштабе s (0 — зверь ходит по земле).
static func hover_for(id: String, s: float) -> float:
	return float(info_for(id)["hover"]) * s


## Ключ клипа по имени анимации: "Armature|Walk" → "walk"; "" — не наш клип.
static func clip_key(anim_name: String) -> String:
	var k := anim_name.to_lower()
	for sep in ["/", "|", ":"]:
		if k.contains(sep):
			k = k.get_slice(sep, k.get_slice_count(sep) - 1)
	k = k.strip_edges()
	if k in CLIPS:
		return k
	return ""


## Загрузить модель вида с масштабом s. color — цвет вида (если текстуры нет), tint — оттенок
## текстуры (стадия питомца). false — файла нет или он не читается.
func setup(id: String, s: float, color: Color = Color.WHITE, tint: Color = Color.WHITE) -> bool:
	species = id
	stage_model = species_of(id) != id
	name = "Asset"
	_s = s
	info = info_for(id)
	var path := path_for(id)
	if not Assets.exists(path):
		return false
	var ps := load(path) as PackedScene
	if ps == null:
		return false
	var node := ps.instantiate()
	_model = node as Node3D
	if _model == null:
		if node != null:
			node.free()
		return false
	_model.name = "Model"
	# glTF смотрит в +Z, наши модели — в -Z
	_model.rotation.y = PI
	add_child(_model)
	scale = Vector3.ONE * s

	_setup_material(id, color, tint)
	for n in _model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		mi.set_meta("no_toon", true)
		mi.material_override = material

	var skels := _model.find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty():
		skeleton = skels[0] as Skeleton3D
		_head_bone = _find_head()
		_skel_xf = _rel_xform(skeleton)
	var aps := _model.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		anim = aps[0] as AnimationPlayer
		_map_clips()
		# Один раз на ресурс анимации (метка на Animation, не по пути: выгруженная и загруженная заново сцена —
		# новые клипы без петли)
		_prepare_clips()
		# За кадром анимация стоит (кости не считаются); рамка с запасом на прыжки и взмахи
		var vis := VisibleOnScreenNotifier3D.new()
		vis.name = "OnScreen"
		var hw := maxf(float(info["length"]), float(info["width"])) * 0.6 * _s
		vis.aabb = AABB(Vector3(-hw, -0.2, -hw), Vector3(hw * 2.0, float(info["height"]) * 1.4 * _s + 0.4, hw * 2.0))
		vis.screen_entered.connect(_on_screen_changed.bind(true))
		vis.screen_exited.connect(_on_screen_changed.bind(false))
		add_child(vis)
	return true


func _on_screen_changed(on: bool) -> void:
	_onscreen = on
	_apply_active()


func _apply_active() -> void:
	if anim != null:
		anim.active = not _asleep and _onscreen


func _ready() -> void:
	if anim != null and not _dead:
		_set_loco("idle", 0.0)


## Свой материал вместо импортированного (у того металличность glTF по умолчанию 1): toon,
## текстура вида, эмиссия для вспышки урона, контур.
func _setup_material(id: String, color: Color, tint: Color) -> void:
	material = StandardMaterial3D.new()
	material.metallic = 0.0
	var tex_path := DIR + id + ".png"
	if Assets.exists(tex_path):
		material.albedo_texture = load(tex_path) as Texture2D
	if material.albedo_texture != null:
		material.albedo_color = tint
	else:
		material.albedo_color = Color(color.r * tint.r, color.g * tint.g, color.b * tint.b)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	Util.toon(material)
	# Эмиссия включена заранее (чёрная), чтобы вспышка урона не перекомпилировала шейдер
	material.emission_enabled = true
	material.emission = Color.BLACK
	# Без самозатенения картой теней (Quality.model_shadows) и контур — меняются сразу в настройках
	Quality.track_model(material, _outline_mat())
	material.set_meta("toon_done", true)
	# Дальше Quality.outline_far() м — без контура (ModelLod)
	ModelLod.register(self, [material])


func _map_clips() -> void:
	for an in anim.get_animation_list():
		var k := clip_key(String(an))
		if k != "" and not clips.has(k):
			clips[k] = String(an)
	# Запасной поиск по вхождению ("Walk_Cycle" и т. п.), только для ещё не найденных клипов
	for an in anim.get_animation_list():
		var low := String(an).to_lower()
		for k in CLIPS:
			if not clips.has(k) and low.contains(k):
				clips[k] = String(an)


## Один раз на ресурс модели: покой, шаг и бег зациклены (смещение корня по земле убрано —
## зверь идёт на месте, двигает его код), остальные клипы играют один раз.
func _prepare_clips() -> void:
	for k in clips:
		var a := anim.get_animation(clips[k])
		if a == null or a.has_meta("ca_prepared"):
			continue
		a.set_meta("ca_prepared", true)
		if k in LOOPED:
			a.loop_mode = Animation.LOOP_LINEAR
			_pin_root(a)
		else:
			a.loop_mode = Animation.LOOP_NONE


## Убрать смещение корневой кости по X и Z (высота остаётся).
func _pin_root(a: Animation) -> void:
	if skeleton == null:
		return
	var root_name := String((info["bones"] as Dictionary).get("root", ""))
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_POSITION_3D:
			continue
		var bn := String(a.track_get_path(t).get_concatenated_subnames())
		var bi := skeleton.find_bone(bn)
		if bi < 0:
			continue
		var is_root := bn == root_name if root_name != "" else skeleton.get_bone_parent(bi) < 0
		if not is_root:
			continue
		var rest := skeleton.get_bone_rest(bi).origin
		for k in a.track_get_key_count(t):
			var v: Vector3 = a.track_get_key_value(t, k)
			a.track_set_key_value(t, k, Vector3(rest.x, v.y, rest.z))


## Кость головы: bones.head из creatures.json или первая кость с «head» в имени.
func _find_head() -> int:
	var named = (info["bones"] as Dictionary).get("head")
	if named is String and skeleton.find_bone(named) >= 0:
		return skeleton.find_bone(named)
	for i in skeleton.get_bone_count():
		var bn := skeleton.get_bone_name(i).to_lower()
		if bn.contains("head") and not bn.contains("end") and not bn.contains("top"):
			return i
	return -1


## Положение узла n относительно этого узла (без дерева сцены).
func _rel_xform(n: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != self:
		var n3 := cur as Node3D
		if n3 != null:
			xf = n3.transform * xf
		cur = cur.get_parent()
	return xf


# ---------- Анимация ----------

## Каждый кадр: покой, шаг или бег по скорости spd (м/с); действие доигрывается до конца.
func update(delta: float, spd: float) -> void:
	_t += delta
	_speed = spd
	_update_decor()
	if anim == null or _dead or not anim.active:
		return
	if _act_left > 0.0:
		_act_left -= delta
		if _act_left > 0.0:
			return
		_loco = ""
	var walk_v := float(info["walk_speed"]) * _s
	var run_v := float(info["run_speed"]) * _s
	var want := "idle"
	if spd > 0.2:
		want = "run" if spd > (walk_v + run_v) * 0.5 else "walk"
	if want == "run" and not clips.has("run"):
		want = "walk"
	if want == "walk" and not clips.has("walk"):
		want = "run" if clips.has("run") else "idle"
	_set_loco(want, 0.2)
	if want == "idle":
		anim.speed_scale = 1.0
	else:
		var native := walk_v if want == "walk" else run_v
		anim.speed_scale = clampf(spd / maxf(native, 0.05), 0.5, 3.0)


func _set_loco(want: String, blend: float) -> void:
	if want == _loco or not clips.has(want):
		return
	_loco = want
	anim.speed_scale = 1.0
	anim.play(clips[want], blend)


## Сыграть клип key один раз (не дольше max_len с, если > 0). Возвращает скорость клипа или -1.
func _act(key: String, max_len: float = 0.0) -> float:
	if anim == null or _dead or not clips.has(key):
		return -1.0
	var a := anim.get_animation(clips[key])
	if a == null or a.length <= 0.0:
		return -1.0
	var sp := 1.0
	if max_len > 0.0 and a.length > max_len:
		sp = a.length / max_len
	anim.speed_scale = 1.0
	anim.play(clips[key], 0.08, sp)
	anim.seek(0.0, true)
	_act_left = a.length / sp
	_loco = ""
	return sp


## Атака (клип Attack не дольше max_len с). Возвращает, через сколько секунд удар (0 — клипа нет, бить сразу).
func play_attack(max_len: float = 0.0) -> float:
	var sp := _act("attack", max_len)
	if sp <= 0.0:
		return 0.0
	return clampf(float(info["attack_hit_time"]) / sp, 0.0, _act_left * 0.9)


## Реакция на урон: только на месте (на ходу клип не сбивает шаг) и не прерывает атаку и умение.
func play_hit() -> void:
	if _act_left > 0.0 or _speed > 0.5:
		return
	_act("hit", HIT_MAX)


## Умение (клип Cast, если его нет — Attack). Возвращает, через сколько секунд эффект (0 — сразу).
func play_cast(max_len: float = 1.2) -> float:
	var sp := _act("cast", max_len)
	if sp <= 0.0:
		return play_attack(max_len)
	return clampf(float(info["attack_hit_time"]) / sp, 0.0, _act_left * 0.9)


## Смерть: клип Death (последний кадр остаётся). Возвращает его длительность, с (0 — клипа нет).
func play_death() -> float:
	if _dead:
		return 0.0
	var sp := _act("death", DEATH_MAX)
	_dead = true
	if sp <= 0.0:
		return 0.0
	return _act_left


## Зверь спит (далеко от игрока): анимации не считаются.
func set_sleeping(on: bool) -> void:
	_asleep = on
	_apply_active()


# ---------- Питомец ----------

## Украшения питомца: самоцвет цвета роли над головой (все стадии), искорки цвета роли (со 2-й стадии),
## золотой нимб, сияние под ногами и золотые искорки (3-я стадия). Узлы: Charm, Sparkles, Halo, Aura.
## У своей модели стадии (stage_model) — только самоцвет роли: стадию видно по самой модели.
func decorate(stage: int, role: String) -> void:
	if stage_model:
		stage = 0
	if _decor != null:
		_decor.queue_free()
	var rc := CreatureModels.role_color(role)
	var h := float(info["height"])
	_decor = Node3D.new()
	_decor.name = "Decor"
	add_child(_decor)
	# Ромбик-самоцвет: сфера с 4 гранями по кругу — октаэдр, один вызов отрисовки
	var charm := MeshInstance3D.new()
	charm.name = "Charm"
	charm.set_meta("no_outline", true)
	charm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var gm := SphereMesh.new()
	gm.radius = 0.085
	gm.height = 0.24
	gm.radial_segments = 4
	gm.rings = 1
	charm.mesh = gm
	charm.material_override = CreatureModels.flat_mat(rc.lightened(0.25))
	_decor.add_child(charm)
	_charm = charm
	if stage == 1:
		var sp := Vfx.ambient_sparkles(self, rc.lightened(0.35), 0.45, 4)
		sp.name = "Sparkles"
		sp.position.y = h * 0.55
	if stage >= 2:
		var ring := MeshInstance3D.new()
		ring.name = "Halo"
		ring.set_meta("no_outline", true)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var tm := TorusMesh.new()
		tm.inner_radius = 0.17
		tm.outer_radius = 0.22
		tm.rings = 20
		tm.ring_segments = 6
		ring.mesh = tm
		ring.rotation.x = 0.2
		ring.material_override = CreatureModels.flat_mat(Color(1.0, 0.92, 0.5))
		_decor.add_child(ring)
		_halo = ring
		var aura := MeshInstance3D.new()
		aura.name = "Aura"
		aura.set_meta("no_outline", true)
		aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var pm := PlaneMesh.new()
		var foot := maxf(float(info["length"]), float(info["width"]))
		pm.size = Vector2(foot, foot) * 1.1 + Vector2(0.4, 0.4)
		aura.mesh = pm
		aura.material_override = Vfx.fx_mat(Color(1.0, 0.88, 0.45, 0.55), Vfx.tex("dot"), true)
		aura.position.y = 0.04
		add_child(aura)
		var gold := Vfx.ambient_sparkles(self, Color(1.0, 0.92, 0.55), 0.6, 6)
		gold.name = "Sparkles"
		gold.position.y = h * 0.55
	_update_decor()


## Украшения над головой: следуют за костью головы (если найдена), самоцвет покачивается, нимб кружится.
func _update_decor() -> void:
	if _decor == null:
		return
	var top := Vector3(0, float(info["height"]), -float(info["length"]) * 0.3)
	if skeleton != null and _head_bone >= 0:
		top = _skel_xf * skeleton.get_bone_global_pose(_head_bone).origin
		top.y = maxf(top.y, float(info["height"]) * 0.6)
	_decor.position = top + Vector3(0, 0.3, 0)
	if _charm != null:
		_charm.position.y = (0.25 if _halo != null else 0.08) + sin(_t * 2.5) * 0.05
		_charm.rotation.y = _t * 2.0
	if _halo != null:
		_halo.rotation.y = _t * 1.5


static func _outline_mat() -> ShaderMaterial:
	if _outline == null:
		var sh := Shader.new()
		sh.code = CharacterModel.ASSET_OUTLINE_SHADER
		_outline = ShaderMaterial.new()
		_outline.shader = sh
		_outline.set_shader_parameter("width", OUTLINE_WIDTH)
	return _outline
