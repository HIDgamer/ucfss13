/// What the brain does with a grenade, from its type
/proc/human_ai_grenade_kind(obj/item/explosive/grenade/grenade)
	if(grenade.active || !grenade.hand_throwable)
		return HAI_GRENADE_NONE
	if(istype(grenade, /obj/item/explosive/grenade/smokebomb))
		return HAI_GRENADE_SMOKE
	if(istype(grenade, /obj/item/explosive/grenade/flashbang))
		return HAI_GRENADE_FLASH
	if(istype(grenade, /obj/item/explosive/grenade/high_explosive/starshell) || istype(grenade, /obj/item/explosive/grenade/high_explosive/frag/toy))
		return HAI_GRENADE_NONE
	if(istype(grenade, /obj/item/explosive/grenade/high_explosive) || istype(grenade, /obj/item/explosive/grenade/incendiary) || istype(grenade, /obj/item/explosive/grenade/phosphorus))
		return HAI_GRENADE_LETHAL
	return HAI_GRENADE_NONE

/// The grenade of a kind that the body carries
/datum/human_ai_brain/proc/find_grenade(kind)
	if(world.time >= grenade_cache_time)
		grenade_cache_time = world.time + HAI_SPARE_CHECK_INTERVAL
		grenade_cache = list()
		for(var/obj/item/explosive/grenade/grenade in body.get_contents())
			var/grenade_kind = human_ai_grenade_kind(grenade)
			if(grenade_kind != HAI_GRENADE_NONE && !grenade_cache["[grenade_kind]"])
				grenade_cache["[grenade_kind]"] = grenade
	var/obj/item/explosive/grenade/found = grenade_cache["[kind]"]
	if(found && (QDELETED(found) || found.active))
		grenade_cache_time = 0
		return null
	return found

/// True when no one who is not an enemy stands near the point and the body is far enough from it
/datum/human_ai_brain/proc/grenade_spot_is_safe(turf/spot, kind)
	var/min_distance = (kind == HAI_GRENADE_LETHAL) ? HAI_GRENADE_LETHAL_RANGE : HAI_GRENADE_SOFT_RANGE
	if(get_dist(body, spot) < min_distance)
		return FALSE
	// A blast reaches further than a flash, and it must spare anyone who is not an enemy, not only friends
	var/lethal = (kind == HAI_GRENADE_LETHAL)
	for(var/mob/living/bystander in view(HAI_GRENADE_SAFE_RADIUS + (lethal ? 1 : 0), spot))
		if(lethal ? is_protected(bystander) : (bystander != body && bystander.stat != DEAD && get_disposition(bystander) <= HAI_DISP_FRIEND))
			return FALSE
	var/turf/here = get_turf(body)
	for(var/turf/line_turf in get_line(here, spot))
		if(line_turf == spot)
			continue
		if(line_turf.density || line_turf.opacity)
			return FALSE
		// A thrown grenade stops at the first body it meets
		if(line_turf != here)
			for(var/mob/living/in_flight in line_turf)
				if(is_protected(in_flight))
					return FALSE
	return TRUE

/// How many enemies the brain has in view within a couple of tiles of the point
/datum/human_ai_brain/proc/enemies_near(turf/spot)
	var/count = 0
	for(var/key in contacts)
		var/datum/ai_contact/contact = contacts[key]
		if(contact.visible && contact.last_turf && get_dist(contact.last_turf, spot) <= 2)
			count++
	return count

/// The grenade worth throwing at the target right now, or null
/datum/human_ai_brain/proc/grenade_for(mob/living/target)
	if(roe == HAI_ROE_WEAPONS_HOLD || world.time < next_grenade_time || world.time < grenade_blocked_until)
		return null
	if(!target || world.time > target_seen_time + 20)
		return null
	if(!find_grenade(HAI_GRENADE_LETHAL) && !find_grenade(HAI_GRENADE_SMOKE) && !find_grenade(HAI_GRENADE_FLASH))
		return null
	var/turf/spot = get_turf(target)
	var/distance = get_dist(body, spot)
	if(distance > HAI_GRENADE_MAX_RANGE)
		return null
	var/datum/ai_contact/contact = get_contact(target)
	var/threat = contact ? contact.threat : 20
	var/cluster = enemies_near(spot)
	var/score = (threat / 60 + (cluster - 1) * 0.5) * personality.scaled("caution", 0.7, 1.4)
	var/obj/item/weapon/gun/gun = peek_gun()
	if(gun && !has_clear_line(target))
		score += 0.5
	if(score >= 1)
		var/obj/item/explosive/grenade/lethal = find_grenade(HAI_GRENADE_LETHAL)
		if(lethal && grenade_spot_is_safe(spot, HAI_GRENADE_LETHAL))
			return lethal
	if(stress >= 40 && distance >= HAI_GRENADE_SOFT_RANGE)
		var/obj/item/explosive/grenade/smoke = find_grenade(HAI_GRENADE_SMOKE)
		if(smoke && grenade_spot_is_safe(spot, HAI_GRENADE_SMOKE))
			return smoke
	if(distance >= HAI_GRENADE_SOFT_RANGE && (cluster >= 2 || score >= 0.7))
		var/obj/item/explosive/grenade/flash = find_grenade(HAI_GRENADE_FLASH)
		if(flash && grenade_spot_is_safe(spot, HAI_GRENADE_FLASH))
			return flash
	return null

/**
 * Takes the gun down and the grenade out, which cannot be done with the gun at the shoulder. The pin is pulled and the grenade thrown once the time it
 * takes has passed, by which time the target has moved and a friend may have walked into the way, and the hands are busy a moment longer getting the
 * gun back up. Nothing is shot in any of it.
 */
/datum/human_ai_brain/proc/throw_grenade(obj/item/explosive/grenade/grenade, atom/target, recheck = TRUE)
	next_grenade_time = world.time + HAI_GRENADE_COOLDOWN
	var/obj/item/weapon/gun/gun = peek_gun()
	if(gun && (gun.flags_item & WIELDED))
		gun.unwield(body)
	take_out_of_holder(grenade)
	if(!body.put_in_hands(grenade, FALSE))
		grenade.forceMove(body.loc)
		return FALSE
	if(grenade == body.get_inactive_hand())
		body.swap_hand()
	body.face_atom(target)
	hands_busy_until = world.time + HAI_GRENADE_DRAW_TIME + HAI_GRENADE_RECOVER_TIME
	acting_until = world.time + HAI_GRENADE_DRAW_TIME
	INVOKE_ASYNC(src, PROC_REF(lob_grenade), grenade, target, gun, recheck)
	return TRUE

/// The second half of a throw: waits out the draw, checks the throw is still a good one, primes the grenade and throws it
/datum/human_ai_brain/proc/lob_grenade(obj/item/explosive/grenade/grenade, atom/target, obj/item/weapon/gun/gun, recheck = TRUE)
	var/kind = human_ai_grenade_kind(grenade)
	var/turf/spot = get_turf(target)
	sleep(HAI_GRENADE_DRAW_TIME)
	if(QDELETED(src) || QDELETED(body))
		return
	acting_until = 0
	// Whoever it was thrown at has moved on in the meantime, a place has not
	if(!QDELETED(target))
		var/mob/living/victim = target
		if(!istype(victim) || victim.stat != DEAD)
			spot = get_turf(target)
	if(stopped || QDELETED(grenade) || grenade.loc != body || body.stat != CONSCIOUS || body.is_mob_incapacitated())
		hands_busy_until = world.time
		return
	// A friend may have stepped into the way while the grenade was being drawn, which is looked at again for a throw the unit chose itself and not for one a plan has already made sure of
	if(!spot || (recheck && !grenade_spot_is_safe(spot, kind)))
		log_decision("did not throw [grenade.name], the throw was no longer safe")
		stow_item(grenade)
		hands_busy_until = world.time + 5
		return
	body.face_atom(spot)
	grenade.attack_self(body)
	if(!grenade.active)
		grenade_blocked_until = world.time + HAI_GRENADE_BLOCK_TIME
		log_decision("[grenade.name] would not prime")
		hands_busy_until = world.time
		return
	body.throw_item(spot)
	grenades_thrown++
	switch(kind)
		if(HAI_GRENADE_LETHAL)
			express(HAI_EXPR_FRAG)
		if(HAI_GRENADE_FLASH)
			express(HAI_EXPR_FLASH)
		if(HAI_GRENADE_SMOKE)
			express(HAI_EXPR_SMOKE)
	if(gun && gun.loc == body && gun == body.get_inactive_hand())
		body.swap_hand()
	log_decision("threw [grenade.name] at [target]")

/datum/human_ai_action/throw_grenade
	id = "throw_grenade"
	conflicts = HAI_LIMB_HANDS
	intents = list(HAI_INTENT_ENGAGE)

/datum/human_ai_action/throw_grenade/get_weight(datum/human_ai_brain/brain)
	if(brain.reload_phase != HAI_RELOAD_NONE || world.time < brain.hands_busy_until)
		return 0
	var/mob/living/target = brain.get_target()
	if(!target || !brain.grenade_for(target))
		return 0
	return 75

/datum/human_ai_action/throw_grenade/trigger(datum/human_ai_brain/brain)
	var/mob/living/target = brain.get_target()
	var/obj/item/explosive/grenade/grenade = target ? brain.grenade_for(target) : null
	if(!grenade)
		return FALSE
	return brain.throw_grenade(grenade, target)
