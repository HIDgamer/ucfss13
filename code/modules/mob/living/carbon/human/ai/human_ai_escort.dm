/// Words in the name of an area that make it a place to hold prisoners
GLOBAL_LIST_INIT(human_ai_holding_words, list("brig", "cell", "detention", "holding", "jail", "prison", "confinement"))

/proc/human_ai_is_holding_area(area/candidate)
	var/text = lowertext(candidate.name)
	for(var/word in GLOB.human_ai_holding_words)
		if(findtext(text, word))
			return TRUE
	return FALSE

/// The closest open, empty turf of a cell area within reach, null when there is none
/datum/human_ai_brain/proc/find_holding_turf()
	RETURN_TYPE(/turf)
	var/turf/here = get_turf(body)
	var/turf/best
	var/best_distance = INFINITY
	for(var/turf/open/candidate in range(HAI_HOLDING_RANGE, here))
		var/area/where = candidate.loc
		if(!istype(where) || !human_ai_is_holding_area(where) || candidate.density)
			continue
		if(locate(/mob/living) in candidate)
			continue
		var/distance = get_dist(here, candidate)
		if(distance < best_distance)
			best = candidate
			best_distance = distance
	return best

/// The captive this brain cuffed and still has to take away, null when there is none or it is not worth the walk
/datum/human_ai_brain/proc/prisoner_to_escort()
	RETURN_TYPE(/mob/living/carbon/human)
	var/mob/living/carbon/human/captive = captive_ref?.resolve()
	if(!captive || QDELETED(captive) || captive.stat == DEAD || captive.z != body.z)
		captive_ref = null
		return null
	if(!captive.handcuffed || get_dist(body, captive) > HAI_ESCORT_RANGE)
		return null
	return captive

/// The captive has been taken as far as they are going to be taken
/datum/human_ai_brain/proc/release_prisoner(mob/living/carbon/human/captive, reason)
	if(body.pulling == captive)
		body.stop_pulling()
	captive_ref = null
	holding_turf = null
	prisoners_delivered++
	log_decision("left [captive] ([reason])")

/// Takes a prisoner it cuffed to the nearest cell, pulling them along, and lets go of them there
/datum/human_ai_action/escort_prisoner
	id = "escort_prisoner"
	conflicts = HAI_LIMB_HANDS|HAI_LIMB_LEGS
	intents = list(HAI_INTENT_IDLE, HAI_INTENT_ALERT, HAI_INTENT_ORDERED)

/datum/human_ai_action/escort_prisoner/get_weight(datum/human_ai_brain/brain)
	if(brain.is_civilian() || brain.get_target() || brain.is_acting() || brain.reload_phase != HAI_RELOAD_NONE || brain.surrendered || brain.broken_kind)
		return 0
	return brain.prisoner_to_escort() ? 68 : 0

/datum/human_ai_action/escort_prisoner/trigger(datum/human_ai_brain/brain)
	var/mob/living/carbon/human/captive = brain.prisoner_to_escort()
	if(!captive)
		return FALSE
	if(!brain.holding_turf || world.time > brain.holding_search_time)
		brain.holding_turf = brain.find_holding_turf()
		brain.holding_search_time = world.time + 30 SECONDS
	var/turf/destination = brain.holding_turf
	if(!destination)
		brain.release_prisoner(captive, "there is nowhere to take them")
		return FALSE
	// Let go once the prisoner is inside the cell and not at its door
	if(get_area(captive) == get_area(destination))
		brain.release_prisoner(captive, "in the cell")
		return TRUE
	if(brain.body.pulling != captive)
		if(!brain.body.Adjacent(captive))
			return brain.move_to(captive, 1, FALSE)
		if(!brain.start_drag(captive))
			brain.release_prisoner(captive, "they cannot be pulled")
			return FALSE
		return TRUE
	return brain.move_to(destination, 0, FALSE)
