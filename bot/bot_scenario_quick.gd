extends BotScenarioGame
## Режим «Быстрый (5 мин)»: все разделы коротким проходом (BotSection quick).


func id() -> String:
	return "quick"


func title() -> String:
	return "Быстрый"


func is_quick() -> bool:
	return true
