class_name Dungeon
extends RefCounted
## Правила подземелья (0.35): кто проходит в портал у пещеры. Решение Максима: вход — с 20 уровня
## (QuestData.DUNGEON_LEVEL), доступ открывает взятое у Корвена задание «Тропа во тьму» (QuestData.DUNGEON_QUEST;
## сданное — тоже). Обратно на остров портал пропускает всегда. Само подземелье — DungeonWorld, переход — main.travel.

## Тесты и админ-панель: пропускать без проверки.
static var force_open := false


## "" — портал пропускает, иначе причина (сообщение игроку).
static func enter_block() -> String:
	if force_open:
		return ""
	if Game.level < QuestData.DUNGEON_LEVEL:
		return "Подземелье откроется с %d уровня" % QuestData.DUNGEON_LEVEL
	var q := QuestData.DUNGEON_QUEST
	if not Game.quests_active.has(q) and not Game.quests_done.has(q):
		return "Проход охраняют наёмники: возьмите у Корвена задание «%s»" % QuestData.quest_name(q)
	return ""
