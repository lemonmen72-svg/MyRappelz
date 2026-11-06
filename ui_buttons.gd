class_name UiButtons
extends RefCounted
## Значки и вид кнопок окон (0.41, просьба Максима: «все кнопки в окнах должны получить значки и свой дизайн»).
## decorate(кнопка, имя) — значок UiIcons слева от подписи и вид темы: главные действия — золотые (BtnPrimary),
## опасные — алые (BtnDanger), остальные — тёмно-синие с золотой рамкой (Util.ui_theme). Имя — node_name кнопки
## (ключ buttons окна): сумка, лавки, склад, кузница, окна героя, существа, питомцев, заданий, диалоги.

## Имя кнопки → значок UiIcons. Ключ с «*» в конце — начало имени.
const ICONS := {
	"act_equip": "act_equip", "act_equip_off": "act_offhand", "act_equip_ring2": "act_ring2",
	"act_unequip": "act_unequip", "act_unshield": "act_unequip", "act_use": "act_use", "act_form": "act_form",
	"act_sell": "act_sell", "act_sell_all": "act_sell_all", "act_move": "act_move", "act_move_cancel": "act_cancel",
	"act_drop": "act_drop", "act_drop_yes": "act_drop", "act_drop_no": "act_cancel", "act_drop_minus": "act_minus",
	"act_drop_plus": "act_plus", "act_drop_all": "act_drop_all", "act_buy": "act_buy", "act_buy5": "act_buy_many",
	"act_store": "act_store", "act_store_all": "act_store_all", "act_take": "act_take", "act_take_all": "act_take_all",
	"gold_put": "act_gold_in", "gold_take": "act_gold_out", "sort": "act_sort", "sort_store": "act_sort",
	"act_craft_put": "act_craft_put", "act_craft": "btn_craft", "act_craft_yes": "act_confirm",
	"act_craft_no": "act_cancel", "act_craft_clear": "act_slot_clear", "act_forge_put": "act_forge_put",
	"act_forge": "btn_forge", "act_forge_clear": "act_slot_clear", "act_read": "act_read",
	"act_belt_take": "act_belt_take", "act_belt_expand": "act_belt_expand", "belt_pet_*": "act_belt_put",
	"craft_recipes": "act_recipes", "recipes": "act_recipes",
	# Окно героя и существа, древо умений
	"learn": "act_learn", "learn_*": "act_learn", "assign_*": "act_assign", "slot_*": "act_assign",
	"aura_*": "act_assign", "unassign": "act_slot_clear", "clear_slot": "act_slot_clear", "toggle": "act_toggle",
	"pet_gear_equip": "act_pet_gear", "pet_gear_off": "act_unequip", "create": "act_use",
	# Питомцы
	"summon_*": "act_summon", "recall_*": "act_recall", "release_*": "act_release", "revive_*": "act_revive",
	"details_*": "act_details", "evolve_*": "act_evolve", "form_*": "act_form",
	# Задания, диалоги, выбор профессии
	"track": "act_track", "untrack": "act_track", "abandon": "act_abandon", "abandon_yes": "act_abandon",
	"abandon_no": "act_cancel", "take_quest": "act_quest_take", "turn_in": "act_quest_turnin", "take_all": "act_quest_take",
	"opt_trade": "act_trade", "opt_bye": "act_bye", "bye": "act_bye", "bless_*": "act_bless",
	"confirm": "act_confirm", "cancel": "act_cancel",
	"accept": "act_quest_take", "complete": "act_quest_turnin", "create_*": "act_use", "gear_equip": "act_pet_gear",
	"gear_off_*": "act_unequip", "toggle_*": "act_toggle", "unslot_*": "act_slot_clear", "unequip_shield": "act_unequip",
	"offhand_*": "act_offhand", "act_quick_*": "quick_edit",
}
## Главные действия (золотые) и опасные (алые) — тоже по имени, «*» — начало.
const PRIMARY := ["act_equip", "act_buy", "act_buy5", "act_craft", "act_craft_yes", "act_forge", "act_use", "act_form",
	"act_belt_expand", "learn", "learn_*", "summon_*", "turn_in", "take_quest", "take_all", "confirm", "pick_*",
	"evolve_*", "pet_gear_equip", "accept", "complete", "gear_equip"]
const DANGER := ["act_drop", "act_drop_yes", "act_drop_all", "abandon", "abandon_yes", "release_*"]


static func _match(dict_or_list: Variant, name: String) -> Variant:
	if dict_or_list is Dictionary:
		var d: Dictionary = dict_or_list
		if d.has(name):
			return d[name]
		for k in d:
			var ks := String(k)
			if ks.ends_with("*") and name.begins_with(ks.trim_suffix("*")):
				return d[k]
		return null
	for k in (dict_or_list as Array):
		var ks := String(k)
		if ks == name or (ks.ends_with("*") and name.begins_with(ks.trim_suffix("*"))):
			return true
	return null


## Значок и вид кнопки b по её имени name (по умолчанию — имя узла). Уже есть значок — не меняется.
static func decorate(b: Button, name: String = "") -> void:
	if b == null:
		return
	var n := name if name != "" else String(b.name)
	var ic: Variant = _match(ICONS, n)
	if ic != null and b.icon == null and b.text.length() > 2:
		UiIcons.add_icon(b, String(ic), 20.0)
	if _match(PRIMARY, n) != null:
		b.theme_type_variation = "BtnPrimary"
	elif _match(DANGER, n) != null:
		b.theme_type_variation = "BtnDanger"


## Значок и вид кнопкам окна по словарю buttons {имя: кнопка}.
static func decorate_all(buttons: Dictionary) -> void:
	for k in buttons:
		var b: Variant = buttons[k]
		if b is Button:
			decorate(b, String(k))
