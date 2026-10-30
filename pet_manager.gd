class_name PetManager
extends Node
## Питомцы: призыв из коллекции Game.pets, команды, опыт за убийства, окно питомцев.
## ЗАГЛУШКА каркаса: реализует модуль «Питомцы».

var main: Node
## Призванный питомец (узел в мире) или null.
var active_pet: Node3D = null


func setup(m: Node) -> void:
	main = m


## Обрабатывает действия: "pet_attack", "pet_follow", "pets_window". true, если действие своё.
func handle_action(id: String) -> bool:
	match id:
		"pet_attack", "pet_follow", "pets_window":
			main.hud.show_message("Питомцы: в разработке")
			return true
	return false


## Зверь убит (игроком или питомцем): опыт питомцу.
func on_mob_killed(_mob: Mob) -> void:
	pass
