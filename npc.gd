class_name Npc
extends StaticBody3D
## Житель-NPC в мире (данные — NpcData по npc_id): аниме-модель CharacterModel.npc_spec(npc_id) — из файла
## npc_<id>.glb (пакет ресурсов; предметы в руках — NpcProps) или из примитивов, имя над головой,
## значок задания сразу над именем (ставит Npcs по Quests.npc_mark): «!» золотой — можно взять задание,
## «?» серый — взято, но не выполнено, «=» зелёный — выполнено, можно сдать. Картинка UiIcons quest_available /
## quest_active / quest_complete (Sprite3D «QuestMarkIcon»), если файл есть, иначе буква (Label3D «QuestMark»).
## Поворачивается к игроку и машет рукой, когда тот подходит и когда с ним заговорили (greet).
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
const MARK_GREEN := Color(0.45, 0.95, 0.45)
## Значок задания: вид → [буква, цвет, id значка UiIcons].
const MARKS := {
	"offer": ["!", MARK_GOLD, "quest_available"],
	"active": ["?", MARK_GREY, "quest_active"],
	"ready": ["=", MARK_GREEN, "quest_complete"],
}
## Значок задания: высота, м (буква — по шрифту, картинка — по этой высоте), зазор над именем.
const MARK_H := 0.4
const MARK_GAP := 0.05

## id NPC (NpcData.NPCS); задаётся до добавления в дерево.
var npc_id := ""
## Значок задания: "" (нет), "offer" («!»), "active" («?»), "ready" («=»).
var mark_kind := ""
## Куда смотрит модель, пока игрок далеко (поворот вокруг Y; 0 — на север, −Z).
var face_yaw := 0.0

var _model: CharacterModel
var _label: Label3D
var _mark: Label3D
## Картинка значка задания (если в assets/icons/ui есть файл значка).
var _mark_icon: Sprite3D
var _near := false
var _wave_cd := 0.0
var _t := 0.0


func _ready() -> void:
	add_to_group("npc")
	if NpcData.is_trader(npc_id):
		add_to_group("trader")
	collision_layer = 1
	collision_mask = 0

	# Капсула-столб (Util.pillar), не цилиндр: у CylinderShape3D в физике Godot 4.3 дрожат контакты — герой
	# дёргался, подойдя к жителю вплотную
	add_child(Util.pillar(0.45, 1.9))

	_model = CharacterModel.new()
	_model.name = "Model"
	_model.setup(CharacterModel.npc_spec(npc_id))
	_model.rotation.y = face_yaw
	add_child(_model)
	# Модель из файла (npc_<id>.glb): предметы в руках, на поясе и за спиной — отдельные файлы (NpcProps)
	NpcProps.attach(_model, npc_id)
	# За кадром житель не анимируется (кости не считаются) — бережение телефона
	_model.pause_offscreen()

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
	_mark.font_size = 76
	_mark.outline_size = 16
	_mark.outline_modulate = Color(0.12, 0.08, 0.04)
	_mark.position.y = mark_height()
	_mark.visible = false
	add_child(_mark)
	_mark_icon = Sprite3D.new()
	_mark_icon.name = "QuestMarkIcon"
	_mark_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mark_icon.position.y = mark_height()
	_mark_icon.visible = false
	add_child(_mark_icon)
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


## Высота центра значка задания над землёй, м: сразу над именем (имя не перекрывается).
func mark_height() -> float:
	var name_half := 0.5 * float(_label.font_size) * _label.pixel_size if _label != null else 0.1
	return LABEL_Y + name_half + MARK_GAP + MARK_H * 0.5 * UiScale.k()


## Значок задания над головой: "" — нет, "offer" — «!», "active" — «?», "ready" — «=».
func set_mark(kind: String) -> void:
	if not MARKS.has(kind):
		kind = ""
	if _mark != null and kind == mark_kind and mark_shown() == (kind != ""):
		return
	mark_kind = kind
	if _mark == null:
		return
	_mark.visible = false
	_mark_icon.visible = false
	if kind == "":
		return
	var m: Array = MARKS[kind]
	_mark.text = String(m[0])
	_mark.modulate = m[1]
	var icon_id := String(m[2])
	if UiIcons.has_file(icon_id):
		var tex := UiIcons.texture(icon_id)
		_mark_icon.texture = tex
		_mark_icon.pixel_size = MARK_H * UiScale.k() / maxf(1.0, float(tex.get_height()))
		_mark_icon.visible = true
	else:
		_mark.visible = true


## Виден ли значок задания (буква или картинка).
func mark_shown() -> bool:
	return _mark != null and (_mark.visible or _mark_icon.visible)


## Текст значка над головой ("" — значка нет): «!», «?» или «=» (и при картинке).
func mark_text() -> String:
	if not mark_shown():
		return ""
	return _mark.text


func _process(delta: float) -> void:
	_t += delta
	if mark_shown():
		var my := mark_height() + sin(_t * 2.6) * 0.04
		_mark.position.y = my
		_mark_icon.position.y = my
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
