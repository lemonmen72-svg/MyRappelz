extends "res://tests/test_base.gd"
## Сетка подземелья (высоты, пол, вода, палубы, проходимость) в файл DUMP_PATH — для tools/dungeon_layout/plan.py.

func before_start() -> void:
	Dungeon.force_open = true


func run_step() -> void:
	match step:
		0:
			main.travel("dungeon")
			step = 1
		1:
			if main.get("world") == null or not (main.world is DungeonWorld) or not bool(main.get("_started")):
				return
			var w: DungeonWorld = main.world
			var f := FileAccess.open(OS.get_environment("DUMP_PATH"), FileAccess.WRITE)
			f.store_string(JSON.stringify({"nx": w.nx, "nz": w.nz, "ox": w.origin.x, "oz": w.origin.y, "step": w.step,
				"h": Array(w.heights), "fs": Array(w.floor_sd), "ws": Array(w.water_sd), "dk": Array(w.deck_of),
				"walk": Array(w.walk)}))
			f.close()
			ok_done()
