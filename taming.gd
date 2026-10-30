class_name Taming
extends Node
## Приручение: кристалл души + умение «Приручить» на цель, затем зверя нужно добить.
## ЗАГЛУШКА каркаса: реализует модуль «Питомцы».

var main: Node


func setup(m: Node) -> void:
	main = m


## Обрабатывает действие "tame". true, если действие своё.
func handle_action(id: String) -> bool:
	if id == "tame":
		main.hud.show_message("Приручение: в разработке")
		return true
	return false


## Зверь убит: если на нём была метка приручения, решаем исход.
func on_mob_killed(_mob: Mob) -> void:
	pass
