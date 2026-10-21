/**
 * A unit that has lost its gun, knocked out of its hand by a wound or put down for something else, goes and gets one instead of punching its way through
 * the fight: the one it dropped by preference, and failing that any loaded gun lying close by. It does so with the fight going on, which is when it needs
 * it most, and only stops short of it with an enemy already on top of it.
 */

/// Remembers the gun in hand so that it can be found again when it is not
/datum/human_ai_brain/proc/remember_gun()
	var/obj/item/weapon/gun/held = peek_gun()
	if(held)
		main_gun_ref = WEAKREF(held)

/// Whether a loose gun is worth running to: it works, it is one it may use and it is not one that could not be reached before
/datum/human_ai_brain/proc/recoverable_gun(obj/item/weapon/gun/candidate)
	if(QDELETED(candidate) || !isturf(candidate.loc) || candidate.anchored || (candidate.flags_item & (NODROP|ITEM_ABSTRACT)))
		return FALSE
	if(recover_skips[REF(candidate)] > world.time)
		return FALSE
	if(get_human_ai_gun_appraisal(candidate).feed == HAI_FEED_NONE)
		return FALSE
	if(lethal_forbidden() && !gun_is_nonlethal(candidate))
		return FALSE
	// One that is empty is only worth having with something to put in it
	return gun_rounds(candidate) > 0 || has_spare_ammo(candidate)

/// The gun to go and get, the one dropped first and otherwise the closest loaded one in sight, null when there is none or the body already has one to use
/datum/human_ai_brain/proc/find_weapon_to_recover()
	RETURN_TYPE(/obj/item/weapon/gun)
	if(has_usable_gun())
		recover_ref = null
		return null
	var/obj/item/weapon/gun/kept = recover_ref?.resolve()
	if(kept && world.time < next_recover_search && recoverable_gun(kept) && get_dist(body, kept) <= HAI_RECOVER_RANGE + 2)
		return kept
	if(world.time < next_recover_search)
		return null
	// Looking round for a gun is only hurried when something is going on
	next_recover_search = world.time + ((intent == HAI_INTENT_ENGAGE || intent == HAI_INTENT_ADVANCE) ? HAI_RECOVER_SEARCH_GAP : 4 * HAI_RECOVER_SEARCH_GAP)
	var/obj/item/weapon/gun/mine = main_gun_ref?.resolve()
	var/obj/item/weapon/gun/best
	var/best_score = -INFINITY
	for(var/obj/item/weapon/gun/candidate in view(HAI_RECOVER_RANGE, body))
		if(!recoverable_gun(candidate))
			continue
		var/score = -get_dist(body, candidate)
		if(candidate == mine)
			score += 8
		if(gun_rounds(candidate) > 0)
			score += 3
		if(score > best_score)
			best_score = score
			best = candidate
	recover_ref = best ? WEAKREF(best) : null
	return best

/// Runs to the gun and takes it up, true while it is on its way
/datum/human_ai_brain/proc/recover_weapon(obj/item/weapon/gun/gun)
	if(get_dist(body, gun) > 1)
		if(move_to(gun, 1, get_dist(body, gun) > HAI_SPRINT_MIN_DISTANCE))
			return TRUE
		if(move_state == HAI_MOVE_BLOCKED)
			recover_skips[REF(gun)] = world.time + HAI_RECOVER_SKIP
			recover_ref = null
			next_recover_search = 0
			log_decision("cannot get to [gun]")
		return FALSE
	if(pick_up(gun))
		recovered_weapons++
		recover_ref = null
		next_recover_search = 0
		log_decision("took [gun] up again")
		return TRUE
	recover_skips[REF(gun)] = world.time + HAI_RECOVER_SKIP
	recover_ref = null
	return FALSE

/datum/human_ai_action/recover_weapon
	id = "recover_weapon"
	conflicts = HAI_LIMB_HANDS|HAI_LIMB_LEGS
	intents = list(HAI_INTENT_IDLE, HAI_INTENT_ALERT, HAI_INTENT_INVESTIGATE, HAI_INTENT_ENGAGE, HAI_INTENT_ADVANCE, HAI_INTENT_HOLD, HAI_INTENT_ORDERED)

/datum/human_ai_action/recover_weapon/get_weight(datum/human_ai_brain/brain)
	if(brain.is_civilian() || brain.role?.maintains || brain.surrendered || brain.broken_kind || brain.current_order?.hard || brain.reload_phase != HAI_RELOAD_NONE)
		return 0
	if(brain.is_acting() || world.time < brain.hands_busy_until)
		return 0
	// One that never had a gun and has nothing going on picks one up the way it picks up anything else it is short of, which is not looked for every second
	if(!brain.main_gun_ref && brain.intent != HAI_INTENT_ENGAGE && brain.intent != HAI_INTENT_ADVANCE)
		return 0
	var/obj/item/weapon/gun/gun = brain.find_weapon_to_recover()
	if(!gun)
		return 0
	// An enemy in arm's reach is fought where it stands unless the gun is at the feet
	if(brain.target_adjacent() && get_dist(brain.body, gun) > 1)
		return 0
	return get_dist(brain.body, gun) <= 2 ? 82 : 68

/datum/human_ai_action/recover_weapon/trigger(datum/human_ai_brain/brain)
	var/obj/item/weapon/gun/gun = brain.find_weapon_to_recover()
	return gun ? brain.recover_weapon(gun) : FALSE
