class_name Story
extends RefCounted
## Сюжетные тексты главы I (канон — docs/story/DUNGEON_CHAPTER1_STORY.md): документы (свиток вождя гоблинов, приказ
## Старшего жреца — предметы с полем "story", в сумке «Прочитать») и последние слова Проклятого капитана. Окно —
## обычное окно HUD (create_window): заголовок и реплики/абзацы, «Закрыть».

## id → {title, lines: [[кто, текст]]} (кто "" — текст документа, "hero" — герой).
const TEXTS := {
	"goblin_exodus_scroll": {"title": "Приказ об исходе", "lines": [
		["", "В нижние ходы не спускаться. Зелёные знаки появились снова. Мёртвые люди ходят по воде и не боятся копий."],
		["", "Разведчики не вернулись; те, кто пришёл вместо них, уже не были живыми. Старый проход закрыть."],
		["", "Собирать еду и оружие. На поверхности есть деревня людей. Мы должны занять остров, прежде чем мёртвые поднимутся сюда."],
	]},
	"priest_order_scroll": {"title": "Распоряжение хранителю святилища", "lines": [
		["", "Старшему служителю нижнего святилища. Поддерживать ритуальные печати до нового приказа. Не допускать посторонних к затопленному гроту. Мёртвые стражи должны оставаться на местах."],
		["", "Все сведения об исследованиях хранить в закрытом архиве. В случае нарушения печатей немедленно сообщить капитану-первосвященнику."],
		["", "Воля Секты Мрака превыше вашей смерти. По приказу капитана, Хранителя Изумрудной Клятвы."],
	]},
	"captain_confession": {"title": "Последние слова капитана", "lines": [
		["Капитан", "Значит… наконец-то. Ты разорвал цепи."],
		["hero", "Что здесь произошло? Кто заставил тебя охранять пещеру?"],
		["Капитан", "Когда-то я был капитаном свободного корабля. Мы нашли древний грот и людей в чёрных одеяниях. Они называли себя наследниками Мрака. Обещали богатство, силу и бессмертие. Я согласился."],
		["Капитан", "Они провели ритуал. Моя команда погибла, но поднялась вновь. Я тоже умер, однако остался жить. Они сделали меня хранителем своих исследований, связали с кораблём и приказали охранять печати."],
		["hero", "Значит, Секта Мрака всё ещё существует?"],
		["Капитан", "Этот остров — забытая точка на их карте. Тысячу лет назад три расы победили их армии, но не уничтожили саму секту. Уцелевшие ушли в тень, собирали знания и ждали, пока победители забудут войну."],
		["Капитан", "Теперь они возвращаются. Они готовят реванш и знают, что в прошлый раз их победил союз трёх рас. Отправляйся на континент. Найди тех, кто помнит Великий Пакт."],
		["Капитан", "Скажи им… Мрак никогда не уходил…"],
		["", "Кристалл в груди капитана гаснет. Проклятие слабеет."],
	]},
}
const GOLD := Color(1.0, 0.85, 0.45)
const HERO := Color(0.7, 0.9, 1.0)
const TEXT := Color(0.92, 0.92, 0.88)
## Последнее открытое окно (тесты).
static var last_opened := ""


static func has(id: String) -> bool:
	return TEXTS.has(id)


## Текст одной строкой (журнал, проверки).
static func plain(id: String) -> String:
	var out: PackedStringArray = []
	for l in (TEXTS.get(id, {}) as Dictionary).get("lines", []):
		out.append(String((l as Array)[1]))
	return " ".join(out)


## Открыть окно с текстом id в HUD hud. Нет такого текста — false.
static func open(hud: Node, id: String) -> bool:
	if hud == null or not is_instance_valid(hud) or not TEXTS.has(id):
		return false
	var d: Dictionary = TEXTS[id]
	var body: VBoxContainer = hud.call("create_window", String(d["title"]), Vector2(760, 520))
	for l in d["lines"]:
		var who := String((l as Array)[0])
		var lab := Label.new()
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lab.add_theme_font_size_override("font_size", UiScale.fs(UiScale.FONT_TEXT))
		if who == "":
			lab.text = String((l as Array)[1])
			lab.add_theme_color_override("font_color", TEXT)
		elif who == "hero":
			lab.text = "%s: «%s»" % [Game.char_name if Game.char_name != "" else "Вы", String((l as Array)[1])]
			lab.add_theme_color_override("font_color", HERO)
		else:
			lab.text = "%s: «%s»" % [who, String((l as Array)[1])]
			lab.add_theme_color_override("font_color", GOLD)
		body.add_child(lab)
	last_opened = id
	return true
