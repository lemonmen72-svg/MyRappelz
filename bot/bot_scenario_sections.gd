extends BotScenarioGame
## Режим «По разделам»: выбранные на вкладке «Тест-бот» разделы (BotScenarioGame.chosen()), полностью.


func id() -> String:
	return "sections"


func title() -> String:
	return "По разделам"


func section_ids() -> Array:
	return BotScenarioGame.chosen()


## По оценке выбранных разделов: ×1.5 + 1 мин, не меньше 3 мин.
func limit() -> float:
	return maxf(180.0, BotScenarioGame.estimate(section_ids()) * 1.5 + 60.0)
