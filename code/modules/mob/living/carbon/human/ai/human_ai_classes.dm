/**
 * Classes: roles that change how a unit fights and not what it can build or heal. A rusher closes on whatever it sees, a flanker is who a squad
 * sends round the side, a stealth unit lies in wait and only fires once the enemy is close or has found it, and a suicider runs at the enemy with
 * a primed grenade in its hand.
 */
/datum/human_ai_role/rusher
	id = "rusher"
	name = "Rusher"
	rushes = TRUE

/datum/human_ai_role/flanker
	id = "flanker"
	name = "Flanker"
	flanks = TRUE

/datum/human_ai_role/stealth
	id = "stealth"
	name = "Stealth"
	nests = TRUE
	ambush = TRUE

/datum/human_ai_role/suicider
	id = "suicider"
	name = "Suicider"
	rushes = TRUE
	bomber = TRUE

/// Whether the brain charges in without caring for cover or range, a broken one in a rage and a rusher always
/datum/human_ai_brain/proc/rushing()
	return berserk_until || role?.rushes

/// The grenade in either hand that is armed already
/datum/human_ai_brain/proc/live_charge()
	RETURN_TYPE(/obj/item/explosive/grenade)
	for(var/obj/item/explosive/grenade/grenade in list(body.get_active_hand(), body.get_inactive_hand()))
		if(grenade.active)
			return grenade
	return null

/// The grenade a suicider would rather take with it than lose, null when it has none or a friend stands where the blast would reach
/datum/human_ai_brain/proc/charge_for(mob/living/target)
	if(!role?.bomber || roe == HAI_ROE_WEAPONS_HOLD || live_charge())
		return null
	if(!target || world.time > target_seen_time + 20 || get_dist(body, target) > HAI_BOMBER_RANGE)
		return null
	var/obj/item/explosive/grenade/grenade = find_grenade(HAI_GRENADE_LETHAL)
	if(!grenade)
		return null
	for(var/mob/living/bystander in view(HAI_GRENADE_SAFE_RADIUS + 1, body))
		if(bystander != body && is_protected(bystander))
			return null
	return grenade

/// Takes the grenade in hand and arms it, then keeps it there
/datum/human_ai_brain/proc/prime_charge(obj/item/explosive/grenade/grenade)
	var/obj/item/weapon/gun/gun = peek_gun()
	if(gun && (gun.flags_item & WIELDED))
		gun.unwield(body)
	take_out_of_holder(grenade)
	if(!body.put_in_hands(grenade, FALSE))
		grenade.forceMove(body.loc)
		return FALSE
	grenade.attack_self(body)
	if(!grenade.active)
		log_decision("[grenade.name] would not prime")
		return FALSE
	charges_primed++
	express(HAI_EXPR_BATTLE_CRY, null, "scream")
	log_decision("armed [grenade.name] to take the enemy with it")
	return TRUE

/datum/human_ai_action/prime_charge
	id = "prime_charge"
	conflicts = HAI_LIMB_HANDS
	intents = list(HAI_INTENT_ENGAGE)

/datum/human_ai_action/prime_charge/get_weight(datum/human_ai_brain/brain)
	if(!brain.role?.bomber || brain.reload_phase != HAI_RELOAD_NONE)
		return 0
	return brain.charge_for(brain.get_target()) ? 88 : 0

/datum/human_ai_action/prime_charge/trigger(datum/human_ai_brain/brain)
	var/obj/item/explosive/grenade/grenade = brain.charge_for(brain.get_target())
	return grenade ? brain.prime_charge(grenade) : FALSE

/// The members of the group with the ones whose job it is to go round the side first
/datum/human_ai_squad/proc/flankers_first(list/group)
	var/list/ordered = list()
	for(var/datum/human_ai_brain/brain as anything in group)
		if(brain.role?.flanks)
			ordered += brain
	for(var/datum/human_ai_brain/brain as anything in group)
		if(!brain.role?.flanks)
			ordered += brain
	return ordered
