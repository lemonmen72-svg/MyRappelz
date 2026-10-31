class_name PenSheep
extends Node3D
## Овца в загоне деревни людей: модель из файла (Meshy от Максима, tools/prepare_creatures.py «sheep»,
## CreatureAsset — меш на скелете и процедурные клипы). Стоит и щиплет траву (Idle), время от времени
## неспешно переходит на новое место внутри загона (Walk без проскальзывания). Не зверь: без коллизии,
## не цель, не приручается. Нет файла модели — овец нет (процедурные овцы больше не ставятся).

const ID := "sheep"

var world: IslandWorld
## Центр загона (x, z) и радиус, в котором овца бродит, м.
var center := Vector2.ZERO
var radius := 3.0
var asset: CreatureAsset = null

var _rng := RandomNumberGenerator.new()
var _target := Vector2.ZERO
var _wait := 0.0
var _speed := 0.25


## Овца в загоне (центр c, радиус r) или null, если модели нет.
static func create(w: IslandWorld, c: Vector2, r: float, seed_v: int) -> PenSheep:
	if not CreatureAsset.has_asset(ID):
		return null
	var sh := PenSheep.new()
	sh.world = w
	sh.center = c
	sh.radius = r
	sh._rng.seed = seed_v
	var a := CreatureAsset.new()
	if not a.setup(ID, sh._rng.randf_range(0.9, 1.08)):
		a.free()
		sh.free()
		return null
	sh.asset = a
	sh.add_child(a)
	sh._speed = float(a.info.get("walk_speed", 0.25)) * a.scale.x
	var p := sh._random_spot()
	sh.position = Vector3(p.x, w.height_at(p.x, p.y), p.y)
	sh.rotation.y = sh._rng.randf() * TAU
	sh._target = p
	sh._wait = sh._rng.randf_range(0.5, 6.0)
	return sh


func _random_spot() -> Vector2:
	var a := _rng.randf() * TAU
	return center + Vector2(cos(a), sin(a)) * radius * sqrt(_rng.randf())


func _process(delta: float) -> void:
	if asset == null or world == null:
		return
	if _wait > 0.0:
		_wait -= delta
		asset.update(delta, 0.0)
		return
	var p := Vector2(position.x, position.z)
	var d := _target - p
	if d.length() < 0.05:
		_wait = _rng.randf_range(3.0, 9.0)
		_target = _random_spot()
		asset.update(delta, 0.0)
		return
	var stp := d.normalized() * minf(_speed * delta, d.length())
	p += stp
	position = Vector3(p.x, world.height_at(p.x, p.y), p.y)
	# Перед узла — −Z (модель внутри CreatureAsset повёрнута)
	rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.y), minf(1.0, 3.0 * delta))
	asset.update(delta, _speed)
