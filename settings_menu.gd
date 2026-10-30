class_name SettingsMenu
extends RefCounted
## Окно настроек графики (через HUD.create_window): три пресета качества и описание текущего.
## Тени солнца, постобработка, дальность и контуры растительности применяются сразу
## (Quality.apply), густота травы и цветов — при следующем запуске игры.
## Открытие: SettingsMenu.open(hud) (действие HUD "settings_window").


static func open(hud: HUD) -> void:
	if hud == null or not is_instance_valid(hud):
		return
	var body := hud.create_window("Настройки", Vector2(680, 500))
	var cur := Quality.level()

	var title := Label.new()
	title.text = "Качество графики: %s" % Quality.level_name(cur)
	body.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	body.add_child(row)
	for l in 3:
		var b := Button.new()
		b.text = Quality.level_name(l)
		b.toggle_mode = true
		b.button_pressed = l == cur
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 64)
		var lvl := l
		b.pressed.connect(func() -> void: SettingsMenu._select(hud, lvl))
		row.add_child(b)

	body.add_child(_wrap_label(Quality.description(cur), 21, Color(0.98, 0.96, 0.9)))
	var note := "Тени и постобработка меняются сразу. Густота травы и цветов — при следующем запуске игры."
	var built := IslandVegetation.built_level(hud.get_tree())
	if built >= 0 and built != cur:
		note += "\nСейчас трава построена для качества «%s»." % Quality.level_name(built)
	body.add_child(_wrap_label(note, 18, Color(1.0, 0.86, 0.55)))


static func _select(hud: HUD, l: int) -> void:
	if hud == null or not is_instance_valid(hud):
		return
	Quality.set_level(l)
	Quality.apply(hud.get_tree())
	open(hud)


static func _wrap_label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(600, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l
