# Навыки Claude Code для Dark Pact

Источник — [awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills)
(Apache-2.0, коммит 19d93f97, 28.10.2026; лицензия и NOTICE — рядом: `LICENSE-awesome-gamedev-agent-skills`,
`NOTICE-awesome-gamedev-agent-skills`). Тексты не менялись. Взято по просьбе Максима (06.11): то, что нужно игре.

Взято:
- Godot: `godot-3d-essentials`, `godot-animation`, `godot-audio`, `godot-export`, `godot-gdscript`,
  `godot-gdscript-headless-testing`, `godot-multiplayer`, `godot-nodes-scenes`, `godot-physics`, `godot-resources`,
  `godot-shaders`, `godot-signals-groups`, `godot-ui-control`.
- Общие: `game-feel`, `performance-optimization`, `shader-programming`, `camera-systems`, `game-ai`, `save-systems`,
  `level-design`, `game-ui-ux`, `audio-design`, `dialogue-systems`, `procedural-gen`, жанр `rpg`.

Не взято: Unity, Unreal, Roblox, веб-движки, 2D (движение, тайлы), C#, остальные жанры, публикация в Steam/itch.

Важно:
- Навыки написаны под Godot 4.7, у нас **Godot 4.3** — API сверять с 4.3 (например, Jolt, новые узлы и параметры
  4.4+ у нас нет).
- Правила проекта (`CLAUDE.md`) важнее советов навыков: рендерер Mobile/Compatibility, CPUParticles вместо
  GPUParticles, APK только по команде Максима, свой формат тестов (`tests/test_base.gd`, `tests/runner.tscn`).
