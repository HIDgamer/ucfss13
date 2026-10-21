/// The ghillie suit the body has on, null when it wears something else
/datum/human_ai_brain/proc/worn_ghillie()
	RETURN_TYPE(/obj/item/clothing/suit/storage/marine/ghillie)
	var/obj/item/clothing/suit/storage/marine/ghillie/suit = body.wear_suit
	return istype(suit) ? suit : null

/// Whether the brain has settled somewhere and means to stay: it holds a post or has been told to hold or guard
/datum/human_ai_brain/proc/is_settled()
	if(holds_a_post())
		return TRUE
	return istype(current_order, /datum/npc_order/hold) || istype(current_order, /datum/npc_order/guard) || istype(current_order, /datum/npc_order/hold_area)

/// Whether the wearer knows how to rig the suit up, the suit refuses anyone else
/datum/human_ai_brain/proc/can_use_ghillie()
	return skillcheck(body, SKILL_SPEC_WEAPONS, SKILL_SPEC_ALL) || body.skills?.get_skill_level(SKILL_SPEC_WEAPONS) == SKILL_SPEC_SNIPER

/**
 * A sniper in a ghillie suit who has settled at a post or been told to hold rigs the suit up and lies in wait, the way a player would. The suit gives
 * the position away when the wearer fires or moves, and the wearer waits a while before hiding again.
 */
/datum/human_ai_action/use_camouflage
	id = "use_camouflage"
	conflicts = HAI_LIMB_HANDS|HAI_LIMB_LEGS
	intents = list(HAI_INTENT_IDLE, HAI_INTENT_ALERT, HAI_INTENT_HOLD, HAI_INTENT_ORDERED)

/datum/human_ai_action/use_camouflage/get_weight(datum/human_ai_brain/brain)
	var/obj/item/clothing/suit/storage/marine/ghillie/suit = brain.worn_ghillie()
	if(!suit || suit.camo_active || suit.hide_in_progress || !suit.can_camo || world.time < brain.next_camo_time)
		return 0
	if(brain.is_acting() || brain.get_target() || brain.suppressed() || brain.is_civilian() || brain.surrendered || brain.broken_kind)
		return 0
	if(brain.body.body_position != STANDING_UP || !brain.is_settled() || !brain.can_use_ghillie())
		return 0
	return 26

/datum/human_ai_action/use_camouflage/trigger(datum/human_ai_brain/brain)
	var/obj/item/clothing/suit/storage/marine/ghillie/suit = brain.worn_ghillie()
	if(!suit)
		return FALSE
	brain.next_camo_time = world.time + HAI_CAMO_GAP
	brain.camo_uses++
	brain.acting_until = world.time + suit.camouflage_enter_delay + 2 SECONDS
	INVOKE_ASYNC(suit, TYPE_PROC_REF(/obj/item/clothing/suit/storage/marine/ghillie, prepare_position), brain.body)
	brain.log_decision("rigging [suit] to lie in wait")
	return TRUE
