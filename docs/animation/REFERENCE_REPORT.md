# Эталон анимаций — сравнение с манекенами

Считано `tools/anim_reference.py` (Blender 4.2.3 LTS, без рендера) за 117 с: клипов-эталонов 60, героев 24. Угол — среднее по сегментам группы после совмещения кадров (DTW) и калибровки рига (ниже), в градусах; пороги: руки 25°, ноги 25° (шаг/бег 40°), корпус 15°.

Выше порога — не обязательно ошибка (женская пластика, ноги на месте у выпадов, сжатие удара), но такие клипы смотреть глазами: листы в `reference/sheets/`.

## Выше порога: 19 из 1440

| Герой | Клип | Руки ср./макс. | Ноги ср./макс. | Корпус ср./макс. | Где |
|---|---|---|---|---|---|
| hero_beastmaster_f | Mq_Sprint | 29 / 32 | 18 / 27 | 13 / 15 | руки |
| hero_wizard_f | Mq_Sprint | 29 / 31 | 18 / 28 | 10 / 10 | руки |
| hero_adept_f | Mq_Sprint | 28 / 31 | 17 / 26 | 10 / 11 | руки |
| hero_conjurer_f | Mq_Sprint | 28 / 31 | 18 / 28 | 14 / 18 | руки |
| hero_human_f_starter | Mq_Sprint | 28 / 31 | 18 / 28 | 12 / 15 | руки |
| hero_neophyte_f | Mq_Sprint | 28 / 31 | 18 / 27 | 11 / 12 | руки |
| hero_dark_elf_f_starter | Mq_Sprint | 28 / 31 | 17 / 27 | 12 / 13 | руки |
| hero_swordsman_f | Mq_Sprint | 28 / 31 | 18 / 28 | 11 / 12 | руки |
| hero_light_elf_f_starter | Mq_Sprint | 28 / 31 | 17 / 28 | 11 / 12 | руки |
| hero_shaman_f | Mq_Sprint | 28 / 31 | 18 / 28 | 16 / 21 | руки, корпус |
| hero_warrior_f | Mq_Sprint | 28 / 31 | 17 / 27 | 11 / 12 | руки |
| hero_shaman_f | Mq_Charged_Slash | 2 / 16 | 6 / 12 | 24 / 47 | корпус |
| hero_shaman_f | Mq_Heavy_Swing | 4 / 12 | 4 / 13 | 24 / 48 | корпус |
| hero_conjurer_f | Mq_Charged_Slash | 2 / 16 | 5 / 11 | 22 / 36 | корпус |
| hero_shaman_f | Mq_Kick | 3 / 10 | 10 / 21 | 19 / 47 | корпус |
| hero_shaman_f | Mq_Leap_Slam | 3 / 31 | 5 / 14 | 18 / 34 | корпус |
| hero_conjurer_f | Mq_Heavy_Swing | 4 / 11 | 4 / 14 | 16 / 23 | корпус |
| hero_human_f_starter | Mq_Charged_Slash | 2 / 16 | 4 / 11 | 16 / 26 | корпус |
| hero_shaman_f | Mq_Death | 1 / 2 | 2 / 3 | 16 / 36 | корпус |

## Сдвиг рига (калибровка, градусы; вычтен из сравнения)

Постоянный поворот сегмента героя относительно манекена во всех клипах — форма скелета, а не движение. Большой сдвиг корпуса или головы — роль кости «шея» / «макушка» в `<id>.json` стоит на другой кости.

| Герой | arm_up_l | arm_lo_l | arm_up_r | arm_lo_r | leg_up_l | leg_lo_l | leg_up_r | leg_lo_r | spine | head |
|---|---|---|---|---|---|---|---|---|---|---|
| hero_adept_f | 0 | 1 | 0 | 0 | 1 | 2 | 1 | 2 | 4 | 9 |
| hero_adept_m | 0 | 0 | 0 | 0 | 2 | 3 | 2 | 2 | 4 | 4 |
| hero_assassin_f | 0 | 1 | 0 | 0 | 3 | 4 | 3 | 3 | 0 | 8 |
| hero_assassin_m | 0 | 0 | 0 | 0 | 2 | 3 | 2 | 3 | 6 | 15 |
| hero_beastmaster_f | 1 | 1 | 0 | 0 | 1 | 2 | 1 | 2 | 5 | 7 |
| hero_beastmaster_m | 0 | 0 | 0 | 0 | 1 | 2 | 1 | 2 | 2 | 4 |
| hero_conjurer_f | 0 | 1 | 0 | 0 | 1 | 2 | 1 | 3 | 1 | 46 |
| hero_conjurer_m | 0 | 0 | 0 | 0 | 2 | 2 | 2 | 2 | 3 | 17 |
| hero_dark_elf_f_starter | 0 | 1 | 0 | 0 | 2 | 2 | 2 | 2 | 9 | 7 |
| hero_dark_elf_m_starter | 0 | 0 | 0 | 0 | 2 | 2 | 2 | 2 | 2 | 9 |
| hero_human_f_starter | 0 | 1 | 0 | 0 | 2 | 2 | 2 | 2 | 7 | 31 |
| hero_human_m_starter | 0 | 0 | 0 | 0 | 2 | 3 | 2 | 2 | 1 | 17 |
| hero_light_elf_f_starter | 0 | 1 | 0 | 0 | 2 | 2 | 2 | 2 | 10 | 6 |
| hero_light_elf_m_starter | 0 | 0 | 0 | 0 | 1 | 3 | 2 | 3 | 3 | 11 |
| hero_neophyte_f | 0 | 1 | 0 | 0 | 1 | 2 | 1 | 2 | 9 | 3 |
| hero_neophyte_m | 0 | 0 | 0 | 0 | 1 | 2 | 2 | 3 | 3 | 23 |
| hero_shaman_f | 1 | 1 | 0 | 0 | 2 | 2 | 2 | 2 | 0 | 89 |
| hero_shaman_m | 0 | 0 | 0 | 0 | 1 | 2 | 1 | 2 | 2 | 16 |
| hero_swordsman_f | 0 | 1 | 0 | 0 | 2 | 2 | 2 | 2 | 6 | 2 |
| hero_swordsman_m | 0 | 0 | 0 | 0 | 1 | 2 | 2 | 3 | 1 | 7 |
| hero_warrior_f | 0 | 1 | 0 | 0 | 2 | 2 | 2 | 2 | 3 | 21 |
| hero_warrior_m | 0 | 0 | 0 | 0 | 1 | 3 | 1 | 3 | 3 | 9 |
| hero_wizard_f | 0 | 1 | 0 | 0 | 1 | 2 | 2 | 2 | 2 | 2 |
| hero_wizard_m | 0 | 0 | 0 | 0 | 1 | 2 | 2 | 2 | 0 | 2 |

## По клипам (среднее по всем героям)

| Клип | Эталон | Руки | Ноги | Корпус |
|---|---|---|---|---|
| Mq_Axe_Chop | m2:Charged_Axe_Chop | 2 | 6 | 4 |
| Mq_Axe_Spin | m2:Axe_Spin_Attack | 4 | 8 | 4 |
| Mq_Blade_Spin | m2:Double_Blade_Spin | 4 | 6 | 2 |
| Mq_Blade_Spin_B | m2:Double_Blade_Spin | 2 | 3 | 2 |
| Mq_Bow_Aim_Hold | m3:Archery_Shot_2 | 1 | 1 | 2 |
| Mq_Bow_Draw | m3:Draw_and_Shoot_from_Back_2 | 2 | 3 | 2 |
| Mq_Bow_Draw_B | m2:Archery_Shot | 2 | 3 | 2 |
| Mq_Bow_Draw_C | m3:Draw_and_Shoot_from_Back | 3 | 3 | 4 |
| Mq_Bow_Draw_D | m3:Draw_and_Shoot_from_Back_1 | 3 | 3 | 4 |
| Mq_Bow_Scan_Hold | m3:Archery_Aim_with_Lateral_Scan | 1 | 3 | 3 |
| Mq_Cast_A | m1:mage_soell_cast | 2 | 4 | 3 |
| Mq_Cast_B | m1:mage_soell_cast_4 | 4 | 5 | 2 |
| Mq_Cast_Beam | m1:mage_soell_cast_3 | 3 | 4 | 3 |
| Mq_Cast_C | m1:mage_soell_cast_7 | 2 | 8 | 2 |
| Mq_Cast_Hold | m1:mage_soell_cast_5 | 2 | 2 | 2 |
| Mq_Cast_Pray | m1:mage_soell_cast_8 | 1 | 5 | 3 |
| Mq_Cast_Release | m1:mage_soell_cast_5 | 1 | 2 | 2 |
| Mq_Cast_Slam | m1:mage_soell_cast_2 | 4 | 5 | 3 |
| Mq_Cast_Up | m1:mage_soell_cast_6 | 3 | 4 | 3 |
| Mq_Cast_Wide | m1:mage_soell_cast_1 | 4 | 8 | 2 |
| Mq_Charge_Hold | m1:Charged_Spell_Cast | 2 | 2 | 2 |
| Mq_Charge_Release | m1:Charged_Spell_Cast | 2 | 6 | 3 |
| Mq_Charged_Cast | m1:Charged_Spell_Cast | 3 | 4 | 2 |
| Mq_Charged_Cast1 | m1:Charged_Spell_Cast_1 | 3 | 8 | 2 |
| Mq_Charged_Slash | m2:Charged_Slash | 2 | 5 | 7 |
| Mq_Combo_B1 | m3:Weapon_Combo_2 | 3 | 5 | 4 |
| Mq_Combo_B2 | m3:Weapon_Combo_2 | 3 | 5 | 3 |
| Mq_Combo_B3 | m3:Weapon_Combo_2 | 3 | 6 | 3 |
| Mq_Crossbow_Aim_Hold | m3:Gun_Hold_Left_Turn | 1 | 2 | 2 |
| Mq_Crouch_Charge_Hold | m2:Charged_Axe_Chop | 4 | 4 | 5 |
| Mq_Death | m1:Dead | 1 | 2 | 4 |
| Mq_Dual_A1 | m2:Double_Combo_Attack | 6 | 4 | 3 |
| Mq_Dual_A2 | m2:Double_Combo_Attack | 4 | 7 | 4 |
| Mq_Ground_Slam | m1:Charged_Ground_Slam | 3 | 4 | 3 |
| Mq_Guard | m2:Sword_Judgment | 1 | 8 | 5 |
| Mq_Heavy_Swing | m3:Heavy_Hammer_Swing | 4 | 4 | 6 |
| Mq_Hit | m1:Hit_Reaction_1 | 2 | 5 | 2 |
| Mq_Judgment | m2:Sword_Judgment | 3 | 5 | 4 |
| Mq_Jump | m2:Basic_Jump | 3 | 5 | 4 |
| Mq_Kick | m3:Simple_Kick | 3 | 9 | 5 |
| Mq_Leap_Slam | m2:Attack | 3 | 5 | 6 |
| Mq_Left_Slash | m3:Left_Slash | 4 | 4 | 5 |
| Mq_Pickup | m1:Female_Bend_Over_Pick_Up_Inspect | 1 | 3 | 3 |
| Mq_Pickup_B | m1:Female_Bend_Over_Pick_Up_Inspect | 1 | 4 | 2 |
| Mq_Reap | m1:Reaping_Swing | 5 | 7 | 2 |
| Mq_Reload | m1:Standing_Reload | 2 | 3 | 1 |
| Mq_Rise | m1:Reaping_Swing | 1 | 3 | 2 |
| Mq_Running | m1:Running | 8 | 11 | 5 |
| Mq_Running_B | m2:run_fast_3_inplace | 6 | 4 | 3 |
| Mq_Sprint | m2:RunFast | 15 | 16 | 7 |
| Mq_Sword_A1 | m3:Triple_Combo_Attack | 5 | 4 | 2 |
| Mq_Sword_A2 | m3:Triple_Combo_Attack | 3 | 5 | 4 |
| Mq_Sword_A3 | m3:Triple_Combo_Attack | 3 | 6 | 2 |
| Mq_Taunt | m1:Chest_Pound_Taunt | 1 | 7 | 3 |
| Mq_Thrust | m3:Thrust_Slash | 4 | 8 | 4 |
| Mq_Thrust_B | m3:Thrust_Slash | 4 | 8 | 3 |
| Mq_Turn_L180 | m3:Gun_Hold_Left_Turn | 1 | 6 | 1 |
| Mq_Turn_L90 | m2:Walk_Turn_Left_with_Weapon | 2 | 11 | 3 |
| Mq_Turn_R90 | m2:Walk_Turn_Right_Female | 1 | 11 | 3 |
| Mq_Walking | m1:Walking | 4 | 4 | 2 |
