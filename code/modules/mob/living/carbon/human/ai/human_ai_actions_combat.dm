/datum/human_ai_action/fire_gun
	id = "fire_gun"
	conflicts = HAI_LIMB_HANDS
	intents = list(HAI_INTENT_ENGAGE)

/datum/human_ai_action/fire_gun/get_weight(datum/human_ai_brain/brain)
	if(brain.roe == HAI_ROE_WEAPONS_HOLD && world.time > brain.last_shot_at_time + 100)
		return 0
	var/mob/living/target = brain.get_target()
	if(!target || world.time > brain.target_seen_time + 20 || world.time < brain.reaction_until)
		return 0
	// A stealth unit lies in wait and opens fire once the enemy is close or has found it
	if(brain.role?.ambush && !brain.suppressed() && get_dist(brain.body, target) > HAI_AMBUSH_RANGE)
		return 0
	if(brain.spares_downed(target) || brain.baton_pressing(target))
		return 0
	var/obj/item/weapon/gun/held_gun = brain.peek_gun()
	if(held_gun && brain.lethal_forbidden() && !brain.gun_is_nonlethal(held_gun))
		return 0
	var/obj/item/weapon/gun/gun = brain.peek_gun()
	if(!gun || brain.reload_phase != HAI_RELOAD_NONE || world.time < brain.volley_pause_until || !brain.gun_can_shoot_now(gun))
		return 0
	if(!brain.safe_to_fire(gun, target))
		return 0
	if(get_human_ai_gun_appraisal(gun).area_effect && !brain.launcher_worthwhile(target))
		return 0
	return 60

/datum/human_ai_action/fire_gun/trigger(datum/human_ai_brain/brain)
	var/mob/living/target = brain.get_target()
	var/obj/item/weapon/gun/gun = brain.get_gun()
	if(!target || !gun)
		return FALSE
	return brain.shoot(gun, target)

/// Feeding, cycling and closing the gun so it can shoot again
/datum/human_ai_action/weapon_care
	id = "weapon_care"
	conflicts = HAI_LIMB_HANDS|HAI_LIMB_LEGS

/datum/human_ai_action/weapon_care/get_weight(datum/human_ai_brain/brain)
	var/obj/item/weapon/gun/gun = brain.peek_gun()
	if(!gun)
		return 0
	if(brain.reload_phase != HAI_RELOAD_NONE)
		return 100
	if(brain.is_acting())
		return 0
	switch(brain.weapon_state(gun))
		if(HAI_WEAPON_OPEN)
			return 98
		if(HAI_WEAPON_SAFE)
			return (brain.get_target() && brain.roe != HAI_ROE_WEAPONS_HOLD) ? 93 : 0
		if(HAI_WEAPON_CYCLE)
			return brain.get_target() ? 92 : 50
		if(HAI_WEAPON_EMPTY)
			if(brain.target_adjacent() || !brain.has_spare_ammo(gun))
				return 0
			return 95
		if(HAI_WEAPON_READY)
			if(brain.get_target() && brain.needs_wield(gun))
				return 91
			if(!brain.in_contact() && brain.wants_tactical_reload(gun))
				return 40
	return 0

/datum/human_ai_action/weapon_care/trigger(datum/human_ai_brain/brain)
	var/obj/item/weapon/gun/gun = brain.get_gun()
	if(!gun)
		return FALSE
	if(brain.reload_phase != HAI_RELOAD_NONE)
		return brain.reload_step(gun)
	var/datum/human_ai_gun_appraisal/appraisal = get_human_ai_gun_appraisal(gun)
	switch(brain.weapon_state(gun))
		if(HAI_WEAPON_OPEN)
			brain.close_after_loading(gun, appraisal)
			return TRUE
		if(HAI_WEAPON_CYCLE)
			return brain.cycle_step(gun)
		if(HAI_WEAPON_SAFE)
			brain.release_safety(gun)
			return TRUE
		if(HAI_WEAPON_READY)
			if(brain.needs_wield(gun))
				gun.wield(brain.body)
				return TRUE
	return brain.reload_step(gun)

/// Changing to another gun when the one in hand has run dry or does not suit the fight
/datum/human_ai_action/switch_weapon
	id = "switch_weapon"
	conflicts = HAI_LIMB_HANDS
	intents = list(HAI_INTENT_ENGAGE, HAI_INTENT_ALERT, HAI_INTENT_ADVANCE, HAI_INTENT_HOLD, HAI_INTENT_FALLBACK)

/datum/human_ai_action/switch_weapon/get_weight(datum/human_ai_brain/brain)
	if(brain.is_acting() || brain.reload_phase != HAI_RELOAD_NONE || world.time < brain.next_switch_time)
		return 0
	var/obj/item/weapon/gun/gun = brain.peek_gun()
	if(!gun)
		return brain.find_other_gun(null) ? 80 : 0
	if(!brain.gun_unusable(gun) || !brain.find_other_gun(gun))
		return 0
	return 90

/datum/human_ai_action/switch_weapon/trigger(datum/human_ai_brain/brain)
	var/obj/item/weapon/gun/gun = brain.peek_gun()
	var/obj/item/weapon/gun/other = brain.find_other_gun(gun)
	brain.next_switch_time = world.time + HAI_SWITCH_COOLDOWN
	if(!other)
		return FALSE
	return brain.switch_to(other)

/datum/human_ai_action/melee
	id = "melee"
	conflicts = HAI_LIMB_HANDS
	intents = list(HAI_INTENT_ENGAGE)

/datum/human_ai_action/melee/get_weight(datum/human_ai_brain/brain)
	var/mob/living/target = brain.get_target()
	if(!target || get_dist(brain.body, target) > 1 || !brain.body.Adjacent(target))
		return 0
	if(brain.holding_melee_weapon())
		return 65
	var/obj/item/weapon/gun/gun = brain.peek_gun()
	if(gun && brain.weapon_state(gun) == HAI_WEAPON_READY && brain.gun_can_shoot_now(gun))
		return 20
	return 50

/datum/human_ai_action/melee/trigger(datum/human_ai_brain/brain)
	var/mob/living/target = brain.get_target()
	return target ? brain.melee_attack(target) : FALSE

/datum/human_ai_action/close_in
	id = "close_in"
	conflicts = HAI_LIMB_LEGS
	intents = list(HAI_INTENT_ENGAGE)

/datum/human_ai_action/close_in/get_weight(datum/human_ai_brain/brain)
	if(brain.role?.ambush)
		return 0
	// A unit that keeps out of fights still goes after somebody who has bothered it too much
	if(brain.role?.passive && !(brain.role.tolerant && brain.holds_grudge_against(brain.get_target())))
		return 0
	var/mob/living/baton_target = brain.get_target()
	if(baton_target && brain.baton_pressing(baton_target))
		return 55
	var/mob/living/target = brain.get_target()
	if(!target)
		return 0
	var/distance = get_dist(brain.body, target)
	var/obj/item/weapon/gun/gun = brain.peek_gun()
	if(gun && brain.weapon_state(gun) != HAI_WEAPON_EMPTY)
		if(distance <= brain.engage_range(gun) && world.time <= brain.target_seen_time + 20 && !brain.rushing())
			return 0
		// Something that wins by getting close is let come, shot at on the way, never walked up to
		if(brain.melee_threat(target) && distance <= brain.shooting_range(gun) && world.time <= brain.target_seen_time + 20 && !brain.rushing())
			return 0
		if(brain.cover_enabled && !brain.rushing() && distance <= brain.shooting_range(gun) && world.time <= brain.target_seen_time + 20)
			if(brain.in_good_cover(get_turf(target)))
				return 0
			if(brain.cover_desire() >= HAI_COVER_MIN_DESIRE && brain.flippable_table(get_turf(target)))
				return 0
	else if(distance <= 1)
		return 0
	return 40

/datum/human_ai_action/close_in/trigger(datum/human_ai_brain/brain)
	var/mob/living/target = brain.get_target()
	return target ? brain.move_to(target, HAI_ARRIVE_DISTANCE, get_dist(brain.body, target) > HAI_SPRINT_MIN_DISTANCE + 1) : FALSE
