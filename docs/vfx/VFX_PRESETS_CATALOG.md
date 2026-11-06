# Dark Pact — каталог эффектов умений

Сгенерировано `tools/vfx_generate.gd` по правилам `vfx/vfx_rules.gd`; ручные правки — `vfx/skill_vfx_overrides.json`.
Фазы: каст — на герое, пока идёт каст; выпуск — сила срывается с рук; снаряд — вид полёта; попадание — по цели;
площадь — вокруг цели; усиление — на герое или питомце. Стоимость: частиц на «Высоком» (на «Среднем» ×0.7, на «Низком» ×0.4).

## Архетипы

| Архетип | Категория | Фаза | Название |
|---|---|---|---|
| `explosion` | fire | area | Огненный взрыв |
| `flame_burst` | fire | impact | Вспышка пламени |
| `frost_nova` | ice | area | Морозная волна |
| `ice_shards` | ice | impact | Ледяные осколки |
| `water_splash` | water | impact | Всплеск воды |
| `water_wave` | water | area | Водяная волна |
| `rock_impact` | earth | impact | Удар камня |
| `ground_spike` | earth | area | Шипы из земли |
| `shockwave` | earth | area | Ударная волна |
| `lightning_strike` | storm | impact | Молния с неба |
| `lightning_bolt` | storm | impact | Разряд от героя |
| `spark_hit` | storm | impact | Искры разряда |
| `heal_burst` | light | buff | Исцеление |
| `holy_beam` | light | impact | Столб света |
| `holy_nova` | light | area | Сияющий круг |
| `shield` | light | buff | Щит |
| `blessing` | light | buff | Благословение |
| `shadow_burst` | dark | impact | Взрыв тьмы |
| `cursed_sigil` | dark | area | Проклятый знак |
| `soul_drain` | dark | impact | Похищение жизни |
| `emerald_curse` | dark | buff | Изумрудное проклятие |
| `toxic_pool` | dark | area | Ядовитая лужа |
| `blood_burst` | dark | impact | Кровавый всплеск |
| `wind_slash` | wind | impact | Ветряной серп |
| `tornado` | wind | area | Вихрь |
| `slash` | weapon | impact | Удар клинком |
| `cleave` | weapon | impact | Тяжёлый удар |
| `stab` | weapon | impact | Укол |
| `blunt_hit` | weapon | impact | Дробящий удар |
| `spin_slash` | weapon | area | Круговой удар |
| `arrow_impact` | weapon | impact | Попадание стрелы |
| `claw` | beast | impact | Удар когтями |
| `roar` | beast | buff | Рёв |
| `spirit_burst` | spirit | impact | Вспышка духа |
| `ritual_circle` | dark | area | Ритуальный круг |
| `ghost` | dark | impact | Призрак |
| `cast_gather` | cast | cast | Каст: сбор силы |
| `release` | cast | release | Выпуск силы |
| `buff_up` | buff | buff | Усиление |
| `orb` | projectile | projectile | Снаряд стихии |

Сколько раз используется: `release` 71, `buff_up` 50, `cast_gather` 45, `heal_burst` 16, `blunt_hit` 15, `blessing` 15, `shadow_burst` 14, `stab` 11, `slash` 10, `water_splash` 7, `shield` 7, `flame_burst` 7, `claw` 7, `shockwave` 7, `spirit_burst` 6, `roar` 6, `blood_burst` 6, `rock_impact` 4, `lightning_strike` 4, `emerald_curse` 4, `ice_shards` 4, `arrow_impact` 4, `cleave` 4, `soul_drain` 3, `holy_nova` 3, `holy_beam` 3, `ritual_circle` 3, `cursed_sigil` 3, `spin_slash` 3, `wind_slash` 2, `toxic_pool` 2, `explosion` 1, `ground_spike` 1, `lightning_bolt` 1, `tornado` 1, `water_wave` 1

## Умения героя

| Умение | Стихия | Каст | Выпуск | Снаряд | Попадание | Площадь | Усиление |
|---|---|---|---|---|---|---|---|
| Кровь бездны `abyss_blood` | blood |  |  |  |  |  | blood_burst |
| Вопль бездны `abyss_howl` | dark | cast_gather |  |  |  | roar ×1.4 | buff_up |
| Едкая роса `acid_mist` | poison |  | release | poison | water_splash |  |  |
| Чуткая защита `alert_guard` | shield |  |  |  |  |  | shield |
| Пролом брони `armor_breach` | light |  |  |  | cleave |  |  |
| Раскол брони `armor_split` | steel |  |  |  | cleave |  |  |
| Буря топоров `axe_storm` | steel |  |  |  | spin_slash ×1.15 |  |  |
| Удар в спину `backstab` | steel |  |  |  | stab |  |  |
| Дурной сон `bad_dream` | dark | cast_gather | release |  | cursed_sigil |  |  |
| Боевой задор `battle_fervor` | spirit |  |  |  |  |  | blessing |
| Сигнальный луч `beacon_ray` | light | cast_gather | release | light | spirit_burst |  |  |
| Звериное спокойствие `beast_calm` | beast |  |  |  |  |  | buff_up |
| Звериный облик `beast_form` | beast |  |  |  |  |  | buff_up |
| Звериная шкура `beast_hide` | beast |  |  |  |  |  | buff_up |
| Звериная мощь `beast_might` | beast |  |  |  |  |  | buff_up |
| Звериный рык `beast_roar` | beast |  |  |  |  |  | buff_up |
| Звериная смекалка `beast_wit` | beast |  |  |  |  |  | buff_up |
| Сковывающий удар `binding_strike` | steel |  |  |  | slash |  |  |
| Благословенный клинок `blessed_blade` | light |  |  |  |  |  | blessing |
| Ослепляющая вспышка `blinding_flash` | light | cast_gather | release |  | holy_beam |  |  |
| Кровный дар `blood_gift` | blood | cast_gather |  |  |  |  | blood_burst |
| Кровавый ливень `blood_rain` | blood | cast_gather | release |  | blood_burst |  |  |
| Алая жатва `bloody_blade` | steel |  |  |  | slash |  |  |
| Жизнь взаймы `borrowed_life` | blood | cast_gather |  |  |  |  | soul_drain |
| Хрупкая чешуя `brittle_hide` | dark | cast_gather | release |  | shadow_burst |  |  |
| Непробиваемый заслон `bulwark` | shield |  |  |  |  |  | shield |
| Горящая стрела `burning_arrow` | fire |  |  |  | flame_burst ×0.8 |  |  |
| Пылающая земля `burning_ground` | fire | cast_gather | release |  | flame_burst |  |  |
| Вызов `challenge` | spirit |  | release |  |  | roar ×2.4 |  |
| Пронзающий выпад `charge_stab` | steel |  |  |  | stab |  |  |
| Созвучие разума `chord_mind` | mind |  |  |  |  |  | buff_up |
| Созвучие силы `chord_strength` | spirit |  |  |  |  |  | blessing |
| Созвучие крепости `chord_vitality` | shield |  |  |  |  |  | shield |
| Созвучие покоя `chord_wisdom` | mind |  |  |  |  |  | buff_up |
| Очищение зверя `cleanse_beast` | heal | cast_gather |  |  |  |  | blessing |
| Холодный расчёт `concentration` | ice |  |  |  |  |  | buff_up |
| Выстрел в сердце `critical_shot` | steel |  |  |  | arrow_impact |  |  |
| Сокрушающий звон `crushing_toll` | steel |  |  |  | cleave |  |  |
| Чёрная метка `cursed_arrow` | dark |  |  |  | shadow_burst ×0.8 |  |  |
| Три тени `dark_strike` | dark |  |  |  | slash |  |  |
| Крест рассвета `dawn_cross` | light |  |  |  | slash |  |  |
| Тлен `decay` | dark | cast_gather | release |  | shadow_burst |  |  |
| Танец теней `deep_evasion` | dark |  |  |  |  |  | buff_up |
| Выбить оружие `disarm_blow` | shield |  |  |  | blunt_hit |  |  |
| Иссушающие болты `drain_arrow` | steel |  |  |  |  |  | buff_up |
| Сдвоенный болт `dual_shot` | steel |  |  |  | arrow_impact |  |  |
| Притупление `dull_strike` | light |  |  |  | slash |  |  |
| Покров сумрака `dusk_veil` | dark |  |  |  |  |  | buff_up |
| Неистовство земли `earth_frenzy` | earth |  |  |  |  |  | buff_up |
| Хватка земли `earth_grip` | earth | cast_gather | release |  | ground_spike |  |  |
| Огненное лезвие `fire_edge` | fire |  |  |  |  |  | buff_up |
| Огненная подпитка `fire_feed` | fire |  |  |  |  |  | buff_up |
| Неистовство огня `fire_frenzy` | fire |  |  |  |  |  | buff_up |
| Огненное сердце `fire_heart` | fire |  |  |  |  |  | buff_up |
| Огненная кожа `fire_skin` | fire |  |  |  |  |  | buff_up |
| Огненная искра `fire_spark` | fire | cast_gather | release | fire | flame_burst |  |  |
| Огненный смерч `fire_tornado` | fire | cast_gather | release |  | flame_burst | explosion ×1.4 |  |
| Свет в ладонях `first_aid` | light |  |  |  |  |  | heal_burst |
| Сгусток пламени `flame_orb` | fire | cast_gather | release | fire | flame_burst |  |  |
| Миг сосредоточения `focus_moment` | mind |  |  |  |  |  | buff_up |
| Стрела стужи `frost_arrow` | ice |  |  |  | ice_shards ×0.8 |  |  |
| Морозный шип `frost_thorn` | ice | cast_gather | release | ice | ice_shards |  |  |
| Дар ясности `gift_intellect` | mind |  |  |  |  |  | buff_up |
| Дар силы `gift_strength` | spirit |  |  |  |  |  | blessing |
| Дар крепости `gift_vitality` | shield |  |  |  |  |  | shield |
| Дар мудрости `gift_wisdom` | mind |  |  |  |  |  | buff_up |
| Благодать `grace` | light |  |  |  |  |  | blessing |
| Порыв `gust` | wind |  |  |  |  |  | buff_up |
| Боевой ритм `haste` | steel |  |  |  |  |  | buff_up |
| Устрашающий удар `head_breaker` | steel |  |  |  | slash |  |  |
| Целебная роса `healing_dew` | heal |  |  |  |  |  | heal_burst |
| Целительное касание `healing_touch` | heal | cast_gather |  |  |  |  | heal_burst |
| Небесная кара `heaven_smite` | light | cast_gather | release |  | holy_beam |  |  |
| Карающий удар `holy_strike` | light |  |  |  | blunt_hit |  |  |
| Беглый огонь `hunter_mark` | fire |  |  |  |  |  | buff_up |
| Ледяные сферы `ice_orbs` | ice | cast_gather | release | ice | ice_shards |  |  |
| Ледяные путы `ice_shackles` | ice | cast_gather | release | ice | ice_shards |  |  |
| Разжечь искру `kindle_spark` | spirit |  |  |  |  |  | spirit_burst |
| Последний вздох `last_breath` | dark | cast_gather |  |  |  |  | soul_drain |
| Глоток жизни `life_sip` | dark | cast_gather | release | dark | shadow_burst |  |  |
| Нить жизни `life_thread` | heal |  |  |  |  |  | blessing |
| Шквал света `light_barrage` | light | cast_gather | release |  | spirit_burst |  |  |
| Купол света `light_dome` | light |  |  |  |  |  | blessing |
| Световой толчок `light_pulse` | light | cast_gather | release | light | spirit_burst |  |  |
| Колыбельная `lullaby` | heal | cast_gather |  |  |  |  | heal_burst |
| Лечение зверя `mend_beast` | heal | cast_gather |  |  |  |  | heal_burst |
| Топь `mire` | earth | cast_gather | release |  | rock_impact |  |  |
| Тихая поступь `oblivion` | steel |  |  |  |  |  | buff_up |
| Гнев стаи `pack_wrath` | beast |  |  |  |  |  | buff_up |
| Кровоточащий болт `piercing_arrow` | blood |  |  |  | blood_burst ×0.8 |  |  |
| Пригвоздить `pin_down` | steel |  |  |  | arrow_impact |  |  |
| Вдох силы `power_breath` | spirit |  |  |  |  |  | heal_burst |
| Когти хищника `predator_claws` | beast |  |  |  |  |  | buff_up |
| Чистый родник `pure_spring` | heal | cast_gather |  |  |  |  | heal_burst |
| Скорое исцеление `quick_heal` | heal | cast_gather |  |  |  |  | heal_burst |
| Попутный ветер `quick_pace` | wind |  |  |  |  |  | buff_up |
| Сияющий круг `radiant_circle` | light | cast_gather | release |  | holy_beam | holy_nova ×1.75 |  |
| Светлые когти `radiant_claws` | light |  |  |  |  |  | blessing |
| Сияющее лезвие `radiant_edge` | light |  |  |  |  |  | blessing |
| Сияющий покров `radiant_veil` | light |  |  |  |  |  | blessing |
| Живительный свет `renewal` | heal |  |  |  |  |  | heal_burst |
| Гулкий удар `ringing_blow` | steel |  |  |  | blunt_hit |  |  |
| Сила скалы `rock_strength` | earth |  |  |  |  |  | buff_up |
| Обвал `rockslide` | earth | cast_gather | release |  | rock_impact | shockwave ×1.55 |  |
| Священный огонь `sacred_fire` | fire |  |  |  |  |  | buff_up |
| Ярость дикаря `savage_fury` | blood |  |  |  |  |  | buff_up |
| Палящий жар `scorching_heat` | fire | cast_gather | release |  | flame_burst |  |  |
| Второе дыхание `second_wind` | heal | cast_gather |  |  |  |  | blessing |
| Град тьмы `shadow_hail` | dark | cast_gather | release |  | shadow_burst |  |  |
| Теневая печать `shadow_seal` | emerald |  |  |  |  |  | buff_up |
| Шаг тени `shadow_step` | dark |  | shadow_burst |  | slash |  |  |
| Общая боль `shared_pain` | blood |  |  |  |  |  | buff_up |
| Щит-молот `shield_hammer` | shield |  |  |  | blunt_hit |  |  |
| Натиск щита `shield_rush` | shield |  | release |  | blunt_hit | shockwave ×1.4 |  |
| Гром щита `shield_thunder` | shield |  |  |  | blunt_hit | shockwave ×1.9 |  |
| Небесный обмен `sky_offering` | light |  |  |  |  |  | holy_nova |
| Сонная пыльца `sleeping_dust` | dark |  | release |  |  | cursed_sigil ×2.3 |  |
| Омут сна `slumber_pool` | water | cast_gather | release |  | water_splash |  |  |
| Слияние душ `soul_merge` | spirit |  |  |  |  |  | blessing |
| Остаток силы `soul_remnant` | dark | cast_gather |  |  |  |  | soul_drain |
| Возвращение души `soul_return` | spirit | cast_gather |  |  |  |  | blessing |
| Ударная искра `spark_shot` | spirit |  |  |  | spirit_burst ×0.8 |  |  |
| Искра крепости `spark_vigor` | spirit |  |  |  |  |  | buff_up |
| Удар с разворота `spin_strike` | steel |  |  |  | spin_slash |  |  |
| Гнев духов `spirit_wrath` | spirit |  |  |  |  | ritual_circle ×1.4 | blessing |
| Вязкая стрела `sticky_arrow` | earth |  |  |  | rock_impact ×0.8 |  |  |
| Каменное лезвие `stone_edge` | earth |  |  |  |  |  | buff_up |
| Каменный клык `stone_fang` | earth | cast_gather | release | earth | rock_impact |  |  |
| Камнелом `stonebreaker` | earth |  |  |  | cleave | shockwave ×1.15 |  |
| Грозовой круг `storm_circle` | storm | cast_gather | release |  | lightning_strike |  |  |
| Грозовое лезвие `storm_edge` | storm |  |  |  |  |  | buff_up |
| Колючий щит `thorn_shield` | shield |  |  |  |  |  | shield |
| Таранный болт `thrust_arrow` | steel |  |  |  | arrow_impact |  |  |
| Неистовство грома `thunder_frenzy` | storm |  |  |  |  |  | buff_up |
| Раскат грома `thunder_roll` | storm | cast_gather | release |  | lightning_strike | lightning_strike ×1.75 |  |
| Громовой удар `thunderclap` | storm | cast_gather | release |  | lightning_strike |  |  |
| Вихрь клинков `twin_fury` | wind |  |  |  |  |  | buff_up |
| Ядовитый наконечник `venom_tip` | poison |  |  |  |  |  | buff_up |
| Оберег `ward_charm` | shield |  |  |  |  |  | shield |
| Водное лезвие `water_edge` | water |  |  |  |  |  | buff_up |
| Неистовство воды `water_frenzy` | water |  |  |  |  |  | buff_up |
| Дикий рёв `wild_roar` | beast |  | release |  |  | roar ×2.4 |  |
| Пожар `wildfire` | fire | cast_gather | release | fire | flame_burst |  |  |
| Разбитая воля `will_breaker` | mind |  |  |  | slash |  |  |
| Ветряная подпитка `wind_feed` | wind |  |  |  |  |  | buff_up |
| Ветряные оковы `wind_fetters` | wind | cast_gather | release |  | wind_slash |  |  |
| Серп ветра `wind_sickle` | wind | cast_gather | release | wind | wind_slash |  |  |
| Рассекающий ветер `wind_slash` | wind |  |  |  | spin_slash |  |  |
| Шаг ветра `wind_step` | wind |  |  |  |  |  | buff_up |
| Крылья ветра `wind_wings` | wind |  |  |  |  |  | buff_up |
| Разряд `zap` | storm | cast_gather | release |  | lightning_bolt |  |  |

## Умения питомцев

| Умение | Стихия | Каст | Выпуск | Снаряд | Попадание | Площадь | Усиление |
|---|---|---|---|---|---|---|---|
| boar: Свирепый натиск `fierce_rush` | beast |  | release ×0.8 |  | claw |  |  |
| centaur: Морок `daze` | dark |  | release ×0.8 |  | shadow_burst |  |  |
| centaur: Топот копыт `hoof_quake` | earth |  |  |  | stab |  |  |
| centaur: Пронзающий удар `piercing_strike` | steel |  | release ×0.8 |  | stab |  |  |
| centaur: Сокрушающий вихрь `ruin_storm` | wind |  | release ×0.8 |  | stab | tornado ×1.9 |  |
| centaur: Двойной выпад `spear_flurry` | steel |  | release ×0.8 |  | stab |  |  |
| centaur: Копейный шквал `spear_storm` | steel |  | release ×0.8 |  | stab ×1.15 |  |  |
| centaur: Боевой рог `war_horn` | steel |  |  |  |  |  | buff_up |
| centaur: Зализать раны `wound_lick_centaur` | steel |  |  |  |  |  | heal_burst |
| golem: Гул земли `ground_roar` | earth |  | release ×0.8 |  | blunt_hit | shockwave ×1.55 |  |
| octopus: Вой пучины `abyss_wail` | water |  | roar |  |  |  |  |
| octopus: Кровавая жажда `blood_thirst` | blood |  |  |  |  |  | blood_burst |
| octopus: Омут порчи `corruption_pool` | water |  | release ×0.8 |  | water_splash | toxic_pool ×1.9 |  |
| octopus: Импульс глубин `deep_pulse` | water |  | release ×0.8 |  | water_splash ×1.15 | water_wave ×1.15 |  |
| octopus: Вихрь щупалец `tentacle_whirl` | wind |  | release ×0.8 |  | water_splash |  |  |
| octopus: Зов прилива `tide_call` | water |  |  |  |  |  | buff_up |
| octopus: Ядовитая кровь `venom_blood` | poison |  |  |  | water_splash |  |  |
| octopus: Зализать раны `wound_lick_octopus` | water |  |  |  |  |  | heal_burst |
| panther: Морок `daze` | dark |  | release ×0.8 |  | shadow_burst |  |  |
| panther: Сумрачный разрыв `dusk_rupture` | dark |  | release ×0.8 |  | shadow_burst |  |  |
| panther: Зов охотницы `hunter_call` | dark |  |  |  |  |  | buff_up |
| panther: Полуночный вихрь `midnight_vortex` | dark |  | release ×0.8 |  | shadow_burst | cursed_sigil ×1.9 |  |
| panther: Клык полуночи `shadow_fang` | dark |  |  |  | blunt_hit |  |  |
| panther: Двойной росчерк `shadow_rend` | dark |  | release ×0.8 |  | claw |  |  |
| panther: Теневой шквал `shadow_squall` | dark |  | release ×0.8 |  | claw ×1.15 |  |  |
| panther: Зализать раны `wound_lick_panther` | dark |  |  |  |  |  | heal_burst |
| pheasant: Проклятие зари `dawn_curse` | light |  | release ×0.8 |  | spirit_burst | holy_nova ×1.9 |  |
| pheasant: Песнь рассвета `dawn_song` | light |  |  |  |  |  | heal_burst |
| pheasant: Морок `daze` | dark |  | release ×0.8 |  | shadow_burst |  |  |
| pheasant: Перьевой шквал `feather_storm` | wind |  | release ×0.8 |  | stab ×1.15 |  |  |
| pheasant: Пронзительный клич `shrill_cry` | beast |  | release ×0.8 |  | stab |  |  |
| pheasant: Искристый клевок `spark_peck` | light |  | release ×0.8 |  | stab |  |  |
| pheasant: Удар шпорой `spur_strike` | light |  |  |  | stab |  |  |
| pheasant: Зализать раны `wound_lick_pheasant` | light |  |  |  |  |  | heal_burst |
| skeleton: Костяная ярость `bone_fury` | emerald |  | release ×0.8 |  | slash |  |  |
| skeleton: Дрожь костей `bone_shudder` | emerald |  |  |  | blunt_hit |  |  |
| skeleton: Морок `daze` | dark |  | release ×0.8 |  | shadow_burst |  |  |
| skeleton: Шквал тлена `decay_flurry` | poison |  | release ×0.8 |  | slash ×1.15 |  |  |
| skeleton: Могильная жажда `grave_thirst_skeleton` | emerald |  |  |  |  |  | blood_burst |
| skeleton: Мрачный клич `grim_call` | dark |  |  |  |  |  | buff_up |
| skeleton: Клинок латника `knight_blade` | emerald |  | release ×0.8 |  | shadow_burst | ritual_circle ×1.9 |  |
| skeleton: Гнилой раскол `rot_cleave` | poison |  | release ×0.8 |  | water_splash |  |  |
| turtle: Стена клана `clan_wall` | shield |  |  |  |  |  | shield |
| turtle: Морок `daze` | dark |  | release ×0.8 |  | shadow_burst |  |  |
| turtle: Землетрясение `earthquake` | earth |  | release ×0.8 |  | blunt_hit | shockwave ×1.9 |  |
| turtle: Таран `ram` | earth |  |  |  | blunt_hit |  |  |
| turtle: Камнепад `rockfall` | earth |  | release ×0.8 |  | blunt_hit ×1.15 |  |  |
| turtle: Гнев панциря `shell_wrath` | earth |  | release ×0.8 |  | blunt_hit |  |  |
| turtle: Каменные челюсти `stone_jaws` | earth |  | release ×0.8 |  | blunt_hit |  |  |
| turtle: Зализать раны `wound_lick_turtle` | earth |  |  |  |  |  | heal_burst |
| wolf: Клич вожака `alpha_call` | beast |  |  |  |  |  | buff_up |
| wolf: Леденящий вой `chilling_howl` | beast |  | roar |  |  |  |  |
| wolf: Шквал клыков `fang_flurry` | beast |  | release ×0.8 |  | claw ×1.15 |  |  |
| wolf: Свирепый натиск `fierce_rush` | beast |  | release ×0.8 |  | claw |  |  |
| wolf: Бросок волка `lunging_bite` | beast |  |  |  | blunt_hit |  |  |
| wolf: Лунное буйство `moon_frenzy` | beast |  | release ×0.8 |  | claw | roar ×1.55 |  |
| wolf: Рвущий укус `rending_bite` | beast |  | release ×0.8 |  | claw |  |  |
| wolf: Зализать раны `wound_lick_wolf` | beast |  |  |  |  |  | heal_burst |

## Способности монстров

| Умение | Стихия | Каст | Выпуск | Снаряд | Попадание | Площадь | Усиление |
|---|---|---|---|---|---|---|---|
| `dg_captain:curse:armor` | emerald |  |  |  |  |  | emerald_curse |
| `dg_captain:curse:aslow` | emerald |  |  |  |  |  | emerald_curse |
| `dg_captain:curse:poison` | poison |  |  |  |  |  | toxic_pool ×0.6 |
| `dg_captain:curse:slow` | emerald |  |  |  |  |  | emerald_curse |
| `dg_captain:curse:stun` | emerald |  |  |  |  |  | emerald_curse |
| `dg_captain:slam` | emerald |  |  |  |  | ritual_circle ×1.9 |  |
| `golem:slam` | earth |  |  |  |  | shockwave ×1.75 |  |
