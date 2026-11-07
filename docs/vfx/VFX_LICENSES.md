# Эффекты — лицензии и происхождение

Эффекты генератора — свой код (`vfx/`), маски рисуются кодом при запуске (`VfxKit.tex`), меши — штатные
примитивы Godot. С VFX 3.0 (0.42) к ним добавлены сторонние пакеты:

| Что | Где | Автор, источник | Лицензия |
|---|---|---|---|
| Magic Circles 3D Free (класс `MagicArea`: магический круг и рябь на земле, 8 стихий; шейдеры) | `vfx/third_party/magic_circles/` (без демо; пути шейдеров исправлены под эту папку) | heyheythere — https://heyheythere.itch.io/magic-circles-3d-free | CC BY 4.0 (`LICENSE.txt` рядом). Строка автора — в игре: «Настройки → Прочее» (`SettingsMenu.CREDITS`). |
| Storm & Wind 3D Free (класс `StormFX`: молния с неба, порыв ветра; шейдеры) | `vfx/third_party/storm_wind/` (без демо; пути шейдеров исправлены) | heyheythere — https://heyheythere.itch.io/storm-wind-3d-free | CC BY 4.0 (`LICENSE.txt` рядом). Строка автора — там же. |
| Particle Pack 1.1 (дым, пламя, искры, треск разряда, подпалины, земля, следы; 88 текстур) | `vfx/tex/kenney/` (уменьшены до 256 px, форма и яркость перенесены в альфу; `*r.png` — повёрнутые) | Kenney — https://kenney.nl/assets/particle-pack (копия из github.com/Calinou/kenney-particle-pack) | CC0 (`LICENSE.txt` рядом). |
| Раскадровки эффектов (0.46.1): 42 листа по 16 кадров — каст и выпуск силы, удары, стихии, лечение и бафы | `vfx/flip/fx_*.png` (нарезаны, оттенки серого, 1024², скрипт `tools/prepare_flipbook.py`; какой файл каким эффектом стал — `tools/flipbook_sources.txt`) | Нарисованы Максимом в ChatGPT (генерация изображений OpenAI) по своим промтам `tools/Промты_раскадровки_эффектов.docx` — абстрактные эффекты белым по чёрному, без чужих игр и картинок в запросе | Условия OpenAI (Terms of Use, «Content»): права на результат — у пользователя, коммерческое использование разрешено. |

Строки для указания авторов (CC BY 4.0):
- Magic Circles 3D Free by heyheythere - https://heyheythere.itch.io/magic-circles-3d-free - CC BY 4.0
- Storm & Wind 3D Free by heyheythere - https://heyheythere.itch.io/storm-wind-3d-free - CC BY 4.0

Не взят: **Basic Godot VFX Pack** — его лицензия запрещает размещать файлы в публичных репозиториях и использовать
их как входные данные для ИИ (наш репозиторий публичный, код пишет Claude).

Изучены, но не используются (подробно — `VFX_AUDIT.md`):

| Проект | Лицензия | Почему не взят |
|---|---|---|
| VFEZ-godot | MIT | Набор материалов, не генератор; приёмы своими силами. Если будем заимствовать шейдер — с атрибуцией MIT здесь. |
| Godot Six-Way Volumetric Shader | CC BY 4.0 | Опирается на возможности Forward+, дорогая прозрачность; архив. |
| Brackeys Particle Controls | MIT | Панель редактора на ПК (Godot 4.4.1); Максим работает с телефона. |
| godot-2DVFX | MIT | 2D, Godot 4.6, облачный ИИ с ключом. |
| H-Style-RBD-Nodes | GPL-3.0 | Blender 5.2+, у нас 4.2.3. |
| Point Animate | Apache-2.0 | Blender 5.0+, у нас 4.2.3. |
