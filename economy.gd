class_name Economy
extends Node
## Предметы и деньги: добыча со зверей, торговец в безопасной зоне, сумка, зелья.
## ЗАГЛУШКА каркаса: реализует модуль «Предметы и торговля».

var main: Node


func setup(m: Node) -> void:
	main = m


## Обрабатывает действия: "potion", "bag_window", "shop". true, если действие своё.
func handle_action(id: String) -> bool:
	match id:
		"potion":
			var p: Player = main.player
			if p.hp >= p.max_hp:
				main.hud.show_message("Здоровье и так полное")
			elif Game.inventory.remove("hp_potion"):
				p.heal(int(p.max_hp * 0.5))
			else:
				main.hud.show_message("Нет зелий здоровья")
			return true
		"bag_window", "shop":
			main.hud.show_message("Сумка и торговец: в разработке")
			return true
	return false


## Зверь убит: золото и добыча.
func on_mob_killed(mob: Mob) -> void:
	var d := MobData.get_type(mob.type_id)
	var g := randi_range(int(d["gold"][0]), int(d["gold"][1]))
	Game.gold += g
	Util.float_text(main, mob.global_position + Vector3(0, 2.8, 0), "+%d зол." % g, Color(1, 0.9, 0.3))
	Game.changed.emit()
