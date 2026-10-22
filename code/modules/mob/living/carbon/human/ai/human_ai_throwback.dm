/// Whether a live grenade is one that hurts, a blast or fire, as against smoke and flash
/proc/human_ai_grenade_hurts(obj/item/explosive/grenade/grenade)
	return initial(grenade.dangerous) || istype(grenade, /obj/item/explosive/grenade/high_explosive) || istype(grenade, /obj/item/explosive/grenade/incendiary)

/// How long a live grenade has left to burn in deciseconds, null when it is not lit or its fuse is not a timed one
/proc/human_ai_fuse_left(obj/item/explosive/grenade/grenade)
	if(!grenade.active || isnull(grenade.primed_at))
		return null
	return max(0, grenade.primed_at + grenade.det_time - world.time)

/// A live grenade that hurts, on the ground within reach, with fuse enough left to be picked up and thrown back, null when there is none
/datum/human_ai_brain/proc/find_throw_back()
	if(world.time < hands_busy_until || reload_phase != HAI_RELOAD_NONE || body.stat != CONSCIOUS || body.is_mob_incapacitated())
		return null
	for(var/obj/item/explosive/grenade/grenade in range(HAI_THROW_BACK_REACH, body))
		if(QDELETED(grenade) || !isturf(grenade.loc) || !human_ai_grenade_hurts(grenade))
			continue
		var/fuse = human_ai_fuse_left(grenade)
		if(isnull(fuse) || fuse < HAI_THROW_BACK_MIN_FUSE)
			continue
		return grenade
	return null

/// Where a grenade is thrown back to: at the enemy when the blast spares everyone else, otherwise somewhere well away from all who are not enemies
/datum/human_ai_brain/proc/throw_back_spot()
	var/turf/here = get_turf(body)
	var/mob/living/target = get_target()
	if(target)
		var/turf/aim = get_turf(target)
		if(aim && get_dist(here, aim) <= HAI_THROW_BACK_RANGE && grenade_spot_is_safe(aim, HAI_GRENADE_LETHAL))
			return aim
	var/turf/best
	var/best_enemies = -1
	for(var/distance in list(6, 5, 7))
		for(var/direction in GLOB.alldirs)
			var/turf/candidate = get_ranged_target_turf(here, direction, distance)
			if(!candidate || candidate.density || get_dist(here, candidate) > HAI_THROW_BACK_RANGE || !grenade_spot_is_safe(candidate, HAI_GRENADE_LETHAL))
				continue
			var/enemies = enemies_near(candidate)
			if(enemies > best_enemies)
				best_enemies = enemies
				best = candidate
		if(best)
			break
	return best

/**
 * Takes the gun down, picks the live grenade up and throws it back once the pickup has taken its moment, the way a trained soldier does with a grenade that
 * has landed at their feet and has a second or more left to burn. The throw is made from the grenade's own fuse, not a fresh one.
 */
/datum/human_ai_brain/proc/throw_back(obj/item/explosive/grenade/grenade, turf/spot)
	var/obj/item/weapon/gun/gun = peek_gun()
	if(gun && (gun.flags_item & WIELDED))
		gun.unwield(body)
	cancel_reload("grenade")
	if(!body.put_in_hands(grenade, FALSE))
		return FALSE
	if(grenade == body.get_inactive_hand())
		body.swap_hand()
	body.face_atom(spot)
	hands_busy_until = world.time + HAI_THROW_BACK_PICKUP + HAI_GRENADE_RECOVER_TIME
	acting_until = world.time + HAI_THROW_BACK_PICKUP
	INVOKE_ASYNC(src, PROC_REF(hurl_back), grenade, spot, gun)
	return TRUE

/// The second half of a throw back, after the pickup: throws what is in the hand where it was meant to go
/datum/human_ai_brain/proc/hurl_back(obj/item/explosive/grenade/grenade, turf/spot, obj/item/weapon/gun/gun)
	sleep(HAI_THROW_BACK_PICKUP)
	if(QDELETED(src) || QDELETED(body))
		return
	acting_until = 0
	if(stopped || QDELETED(grenade) || grenade.loc != body || body.stat != CONSCIOUS || body.is_mob_incapacitated())
		hands_busy_until = world.time
		return
	body.face_atom(spot)
	body.throw_item(spot)
	grenades_returned++
	express(HAI_EXPR_FRAG)
	if(gun && gun.loc == body && gun == body.get_inactive_hand())
		body.swap_hand()
	log_decision("threw [grenade.name] back at [spot]")

/// A live grenade at the feet outranks getting clear of it, as long as there is time to throw it
/datum/human_ai_action/throw_back_grenade
	id = "throw_back_grenade"
	conflicts = HAI_LIMB_HANDS|HAI_LIMB_LEGS

/datum/human_ai_action/throw_back_grenade/get_weight(datum/human_ai_brain/brain)
	// Getting clear of a live grenade already looks for one every think and keeps what it found, so nothing is searched for here until it has found one
	if(!brain.hazard_turf)
		return 0
	return brain.find_throw_back() && brain.throw_back_spot() ? 120 : 0

/datum/human_ai_action/throw_back_grenade/trigger(datum/human_ai_brain/brain)
	var/obj/item/explosive/grenade/grenade = brain.find_throw_back()
	var/turf/spot = grenade ? brain.throw_back_spot() : null
	if(!grenade || !spot)
		return FALSE
	return brain.throw_back(grenade, spot)
