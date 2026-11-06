extends Node
## Генератор эффектов умений: `godot --headless --path . res://tools/vfx_generate.tscn`
## Пишет vfx/skill_vfx.json (таблица VfxGenerate.build_table) и docs/vfx/VFX_PRESETS_CATALOG.md (каталог).
## Сцена, а не --script: так подключены автозагрузки (Game), без которых часть данных не компилируется.


func _ready() -> void:
	var t := VfxGenerate.build_table()
	var f := FileAccess.open("res://vfx/skill_vfx.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(t, "\t", true) + "\n")
	f.close()
	var c := FileAccess.open("res://docs/vfx/VFX_PRESETS_CATALOG.md", FileAccess.WRITE)
	c.store_string(VfxGenerate.catalog_md(t))
	c.close()
	print("VFX: умений героя %d, питомцев %d, монстров %d" % [(t["hero"] as Dictionary).size(),
		(t["pet"] as Dictionary).size(), (t["mob"] as Dictionary).size()])
	get_tree().quit()
