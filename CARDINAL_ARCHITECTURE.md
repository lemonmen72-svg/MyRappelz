# Кардинал — архитектура (по CARDINAL_MASTER_INSTRUCTION.md §3)
Кардинал строится поверх тест-бота, второго движка нет. Статусы: implemented / tested / planned / blocked.

| Компонент (§3) | Где | Статус |
|---|---|---|
| A. ScenarioRunner | `TestBot` (шаги, лимиты, пауза на остывание, остановка) + `BotScenarioCardinal` | implemented |
| B. GameActionAdapter | `CardinalRun`: джойстик (`HUD.move_vec`), цель (`select_target`), удержание «Атаки» (`try_attack`), подход к мешочку | implemented (бой, путь, добыча, отдых) |
| C. SimulationClock | фаза 1: игровое время = сумма `delta` (с `Engine.time_scale`), настоящее — `Time.get_ticks_usec` | partial; свои часы — фаза 2 |
| D. EventScheduler | — | planned (фаза 2) |
| E. BotPolicy | `CardinalRun.PROFILE_REGULAR` (обычный игрок: отдых ниже 45 % HP, звери не старше героя + 1) | implemented (1 из 5) |
| F. Telemetry | `CardinalRun.result()`: убийства (вид, уровень, TTK, опыт и формула), смерти, урон, золото, время по видам | implemented |
| G. ReportEngine | `cardinal.json` (машинный) + раздел отчёта бота (`report_lines`), сводка | implemented |
| H. AndroidExecution | режим в приложении (экран включён), перегрев — паузы бота | partial; фон — фаза 5 |
| I. AdminUI | режим «Кардинал: первый срез» на вкладке «Тест-бот» | partial; своя вкладка — фаза 6 |

## Срез фазы 1
1. Тестовый герой (Бродяга-человек 1 ур.) в хранилище бота — данные игрока не трогаются.
2. Прогон «С картинкой» (×1): фарм у «Окрестностей деревни людей» `BotScenarioCardinal.game_limit` игровых секунд
   (на телефоне 240 с).
3. Сброс героя (уровень, опыт, золото, сумка) и зверей (возрождение) — прогон «Ускоренный ×4»: `Engine.time_scale` 4,
   без 3D, без предела кадров, шагов физики на кадр до 12.
4. Сравнение: точные инварианты — проверки (опыт за каждое убийство = `Combat.xp_for`; оба прогона дошли до конца;
   есть убийства; ускоренный быстрее); статистика — с допуском 0.6–1.6 (опыт/мин, TTK, убийства, урон, золото;
   смерти ±1) — расхождение в отчёте, не ошибка.

## Схема cardinal.json (version 1)
`{version, game_version, scenario, seed, game_limit, runs: [run], compare: [{metric, visual, fast, ratio, ok}]}`,
`run`: `{run, title, profile, profile_version, seed, accel, zone, stop, game_sec, wall_sec, speedup, start, finish,
kills, deaths, damage_taken, xp, xp_per_min, gold, ttk_avg, time_split{seek, approach, fight, loot, rest},
xp_mismatch[], kill_log[{type, level, ttk, xp, xp_expected, hero_level, t}]}`.

## Дальше (planned)
Фаза 2 — игровые часы и свой ГСЧ боя (детерминизм), перемотка безопасных промежутков, тела Неофита на игровом
времени. Фаза 3 — адаптеры: умения, зелья, питомец, задания, торговля. Фаза 4 — профили новичок / ветеран / фармер /
экспериментатор, серии seed. Фаза 5 — фон Android. Фаза 6 — вкладка «Кардинал», сравнение запусков.
