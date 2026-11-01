class_name Npc
extends StaticBody3D
## Житель-NPC в мире (данные — NpcData по npc_id): аниме-модель CharacterModel.npc_spec(npc_id) — из файла
## npc_<id>.glb (пакет ресурсов; предметы в руках — NpcProps) или из примитивов, имя над головой,
## значок задания над именем («!» — можно взять задание, «?» золотой — задание готово к сдаче, «?» серый — взято,
## но не выполнено; ставит Npcs по Quests.npc_mark). Поворачивается к игроку и машет рукой, когда тот подходит
## и когда с ним заговорили (greet).
## Группы: "npc", торгующие — ещё "trader" (Economy). Коллизия — цилиндр (слой 1, мир).
## Наследники (Merchant) добавляют свои мелочи в _build_extra().

const TURN_RANGE := 10.0
const WAVE_RANGE := 6.0
const WAVE_COOLDOWN := 8.0
## Сколько длится взмах рукой, с (повторно в разговоре не машет, пока не закончил).
const WAVE_TIME := 2.0
## Высота подписи с именем, м.
const LABEL_Y := 2.55
const MARK_GOLD := Color(1.0, 0.82, 0.18)
const MARK_GREY := Color(0.72, 0.74, 0.8)

## id NPC (NpcData.NPCS); задаётся до добавления в дерево.
var npc_id := ""
## Значок задания: "" (нет), "offer" («!»), "ready" («?» золотой), "active" («?» серый).
var mark_kind := ""
## Куда смотрит модель, пока игрок далеко (поворот вокруг Y; 0 — на север, −Z).
var face_yaw := 0.0

var _model: CharacterModel
var _label: Label3D
var _mark: Label3D
var _near := false
var _wave_cd := 0.0
var _t := 0.0


func _ready() -> void:
	add_to_group("npc")
	if NpcData.is_trader(npc_id):
		add_to_group("trader")
	collision_layer = 1
	collision_mask = 0

	var col := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 0.45
	cs.height = 1.9
	col.shape = cs
	col.position.y = 0.95
	add_child(col)

	_model = CharacterModel.new()
	_model.name = "Model"
	_model.setup(CharacterModel.npc_spec(npc_id))
	_model.rotation.y = face_yaw
	add_child(_model)
	# Модель из файла (npc_<id>.glb): предметы в руках, на поясе и за спиной — отдельные файлы (NpcProps)
	NpcProps.attach(_model, npc_id)

	_build_extra()

	_label = Label3D.new()
	_label.name = "NameLabel"
	_label.text = NpcData.npc_name(npc_id)
	_label.modulate = Color(1.0, 0.85, 0.35)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Имя компактное (~0.17 м высотой на «Среднем», UiScale.world_px), чтобы имена соседних жителей не сливались
	_label.pixel_size = UiScale.world_px(0.006)
	_label.font_size = 44
	_label.outline_size = 10
	_label.position.y = LABEL_Y
	add_child(_label)

	_mark = Label3D.new()
	_mark.name = "QuestMark"
	_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mark.pixel_size = UiScale.world_px(0.008)
	_mark.font_size = 96
	_mark.outline_size = 18
	_mark.outline_modulate = Color(0.25, 0.14, 0.02)
	_mark.position.y = mark_height()
	_mark.visible = false
	add_child(_mark)
	set_mark(mark_kind)


## Приветствие в начале разговора: машет рукой, если не машет прямо сейчас (Npcs.open_dialog).
func greet() -> void:
	if _model == null or _wave_cd > WAVE_COOLDOWN - WAVE_TIME:
		return
	_model.play_wave()
	_wave_cd = WAVE_COOLDOWN


## Мелочи вокруг модели (у торговца — ящик с товаром). Переопределяется наследниками.
func _build_extra() -> void:
	pass


## Высота значка задания над землёй, м.
func mark_height() -> float:
	return float(NpcData.npc(npc_id).get("mark_y", 3.15))


## Значок задания над головой: "" — нет, "offer" — «!», "ready" — золотой «?», "active" — серый «?».
func set_mark(kind: String) -> void:
	if _mark != null and kind == mark_kind and _mark.visible == (kind != ""):
		return
	mark_kind = kind
	if _mark == null:
		return
	_mark.visible = kind != ""
	_mark.text = "!" if kind == "offer" else "?"
	_mark.modulate = MARK_GREY if kind == "active" else MARK_GOLD


## Текст значка над головой ("" — значка нет).
func mark_text() -> String:
	if _mark == null or not _mark.visible:
		return ""
	return _mark.text


func _process(delta: float) -> void:
	_t += delta
	if _mark != null and _mark.visible:
		_mark.position.y = mark_height() + sin(_t * 2.6) * 0.06
	_wave_cd = maxf(0.0, _wave_cd - delta)
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null or _model == null:
		return
	var to := p.global_position - global_position
	to.y = 0.0
	var d := to.length()
	if d > 0.1 and d < TURN_RANGE:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(-to.x, -to.z), 4.0 * delta)
	# Приветствие, когда игрок подходит
	var near := d < WAVE_RANGE
	if near and not _near and _wave_cd <= 0.0:
		_model.play_wave()
		_wave_cd = WAVE_COOLDOWN
	_near = near
