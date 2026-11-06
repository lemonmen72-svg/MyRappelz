class_name VfxShake
extends Node
## Тряска камеры от мощных умений (VFX 2.0, VfxKit.shake): «травма» копится от ударов и спадает, камера сдвигается
## через h_offset / v_offset — положение и поворот камеры (main.gd) не трогаются, геймплей не меняется. Дальше от
## камеры — слабее, на «Низком» качестве эффектов — нет. Узел живёт под камерой.

const MAX_OFFSET := 0.2
const DECAY := 1.9
const NEAR := 8.0
const FAR := 30.0

## Выключатель (тесты, админ-панель «Эффекты» выключает вместе с новыми эффектами).
static var enabled := true

var trauma := 0.0
var _t := 0.0


## Толчок силы strength (0…1) от удара в точке at, камера — вьюпорта узла node.
static func kick(node: Node, at: Vector3, strength: float) -> void:
	if not enabled or strength <= 0.0 or node == null or not node.is_inside_tree():
		return
	var q := SkillVfx.quality_override if SkillVfx.quality_override >= 0 else Quality.effective("effects")
	if q < 1:
		return
	var cam := node.get_viewport().get_camera_3d()
	if cam == null:
		return
	var k := clampf(1.0 - (cam.global_position.distance_to(at) - NEAR) / (FAR - NEAR), 0.0, 1.0)
	if k <= 0.0:
		return
	var s := cam.get_node_or_null("VfxShake") as VfxShake
	if s == null:
		s = VfxShake.new()
		s.name = "VfxShake"
		cam.add_child(s)
	s.trauma = minf(1.0, s.trauma + strength * k)
	s.set_process(true)


func _process(delta: float) -> void:
	var cam := get_parent() as Camera3D
	if cam == null:
		return
	trauma = maxf(0.0, trauma - delta * DECAY)
	_t += delta
	var a := trauma * trauma * MAX_OFFSET
	cam.h_offset = a * (sin(_t * 47.0) * 0.6 + sin(_t * 89.0 + 1.3) * 0.4)
	cam.v_offset = a * (sin(_t * 53.0 + 2.1) * 0.6 + sin(_t * 97.0) * 0.4)
	if trauma <= 0.0:
		cam.h_offset = 0.0
		cam.v_offset = 0.0
		set_process(false)
