# Плагины Blender для построения локаций

Решение Максима (06.11): бесплатные плагины, которыми строим локации, хранятся здесь. Оба — GPL-3.0-or-later:
код плагинов в игру не попадает (папка `tools/` не экспортируется, `.gdignore` — Godot её не сканирует), а меши,
которые они строят, — наши и годятся для коммерческой игры. Проверено в Blender 4.2.3 LTS без окна (06.11).

## BagaPie 11.0.10 — мосты, причалы, перила, лестницы
- Файл: `bagapie-v11.0.10.zip`. Источник — https://extensions.blender.org (расширение «Bagapie»), sha256
  `2e55574dcb37ca4a86e1942317906f769e269d382d6a82d0b1330cfb94707c9c`, `blender_version_min = 4.2.0`.
- Автор — Antoine Bagattini, лицензия — `BAGAPIE_LICENSE.txt` (GPL-3.0-or-later). Документация —
  https://github.com/antbaga/BagaPie_Documentation.
- Что берём: массив досок вдоль кривой (настил моста и причала), Handrail и Fence по кривой (перила, ограждения),
  Cable — тросы между точками с провисом (верёвочный мост), Plank — грани в доски (палуба, настил), прямые и винтовые
  лестницы с перилами, стены по рёбрам, разброс объектов.
- Установка без окна (в свою папку настроек, чтобы не трогать общие):
  ```
  BLENDER_USER_RESOURCES=<папка> blender -b --factory-startup --command extension install-file -r user_default -e tools/blender_addons/bagapie-v11.0.10.zip
  ```
  После этого в `blender -b --python …` (с той же `BLENDER_USER_RESOURCES`) модуль `bl_ext.user_default.Bagapie`
  включён, узлы Geometry Nodes — в `BagaPie_Nodes.blend` внутри архива. Из скриптов сцены лучше брать узлы
  (append группы из .blend) и звать их своим Python, а не кнопки интерфейса.

## BlenderLevelArchitect (коммит 6bf468f, 22.10.2026) — комнаты, коридоры, лестницы, пещеры
- Папка `BlenderLevelArchitect/`: `levelArchitect_v2.py` (весь плагин одним файлом), `LICENSE` (GPL-3.0-or-later),
  README, CHANGELOG, тесты автора (`tests/blender_headless_test.py`, `run_blender_tests.sh`). Источник —
  https://github.com/dottyboy/BlenderLevelArchitect (без `docs/` и снимков — 82 МБ).
- Что умеет: план уровня (комнаты прямоугольные, круглые, «пещера», коридоры, этажи), стены коробками или кладкой
  с проломами (Ruin), арки, двери, окна, лестницы (в том числе изогнутые), факелы, башня, замок; экспорт GLB,
  отдельная сетка коллизии и JSON с проходимыми зонами, комнатами, лестницами, огнями. Мостов по своей кривой нет —
  мосты и причалы берём у BagaPie.
- Текстуры `Textures/` — лицензия у автора не указана: в игру их не берём, только геометрию.
- Запуск без окна (проверено: операторы `bpy.ops.object.generate_game_blueprint`, `generate_all_steps`):
  ```
  blender -b --factory-startup --python <скрипт, который грузит levelArchitect_v2.py и зовёт register()>
  ```
  Настройки генерации — свойства сцены `wfc_*` и пресеты, результат повторяется по seed.

## Как это ложится на наш конвейер
Сцена подземелья — `tools/dungeon_layout/blender_scene.py` (раздел «0.35.4 — сцена Blender» в CLAUDE.md): геометрию
мостов, причалов, перил и лестниц можно строить узлами BagaPie по кривым из `world/dungeon.json`, каркас новых залов —
BlenderLevelArchitect; дальше — та же усадка объектов, проверка проходов и запись в игру.
