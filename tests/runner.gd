extends Node
## Запуск автотеста как обычной сцены (автозагрузки уже на месте):
## godot --headless --fixed-fps 60 --path . res://tests/runner.tscn -- res://tests/<тест>.gd


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var path := String(args[0]) if args.size() > 0 else "res://tests/smoke_test.gd"
	var script: GDScript = load(path)
	if script == null:
		printerr("[FAIL] не загружен тест " + path)
		get_tree().quit(1)
		return
	var t: Node = script.new()
	add_child(t)
