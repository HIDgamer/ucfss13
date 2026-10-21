/// Whether the subject wins by getting close, so the brain would rather shoot it from far away
/datum/human_ai_brain/proc/melee_threat(mob/living/subject)
	return isxeno(subject) || iszombie(subject)

/// The tiles the brain wants between itself and the threat, more for xenos and zombies and for the cautious
/datum/human_ai_brain/proc/comfort_distance(mob/living/threat, obj/item/weapon/gun/gun)
	var/wanted = melee_threat(threat) ? HAI_KEEP_AWAY_MELEE : HAI_KEEP_AWAY_OTHER
	wanted += round(personality.scaled("caution", -1, 2))
	return clamp(wanted, 2, max(2, shooting_range(gun) - 1))

/// The closest enemy in view that wins by getting close, null when there is none
/datum/human_ai_brain/proc/nearest_melee_threat()
	var/mob/living/closest
	var/closest_distance = INFINITY
	var/mob/living/target = get_target()
	if(target && melee_threat(target) && world.time <= target_seen_time + 20)
		closest = target
		closest_distance = get_dist(body, target)
	for(var/key in contacts)
		var/datum/ai_contact/contact = contacts[key]
		if(!contact.visible)
			continue
		var/mob/living/subject = contact.get_subject()
		if(QDELETED(subject) || subject.stat == DEAD || !melee_threat(subject) || !is_valid_target(subject))
			continue
		var/distance = get_dist(body, subject)
		if(distance < closest_distance)
			closest = subject
			closest_distance = distance
	return closest

/**
 * A turf a few steps away that is farther from the threat than the body is, keeps what cover there is and does not lead toward another enemy.
 * Null when staying put is as good as anything.
 */
/datum/human_ai_brain/proc/find_kite_turf(mob/living/threat)
	var/turf/here = get_turf(body)
	var/turf/threat_turf = get_turf(threat)
	if(!here || !threat_turf)
		return null
	var/here_distance = get_dist(here, threat_turf)
	var/list/others = list()
	for(var/key in contacts)
		var/datum/ai_contact/contact = contacts[key]
		if(contact.visible && contact.last_turf && contact.get_subject() != threat)
			others += contact.last_turf
	var/turf/best
	var/best_score = 1.5
	for(var/turf/candidate in range(HAI_KITE_RADIUS, here))
		if(candidate == here || !cover_turf_usable(candidate) || is_blocked_turf(candidate))
			continue
		var/gain = get_dist(candidate, threat_turf) - here_distance
		if(gain < 1)
			continue
		var/score = gain * 2 + cover_against(candidate, threat_turf) * 1.5 - get_dist(here, candidate) * 0.4
		if(cover_has_line(candidate, threat_turf))
			score += 0.5
		for(var/turf/other as anything in others)
			if(get_dist(candidate, other) < get_dist(here, other))
				score -= 1.5
		if(score > best_score)
			best_score = score
			best = candidate
	return best

/**
 * Backing away from something that wins by getting close while still shooting it, a few steps at a time. Once it has been tried for a while,
 * or there is nowhere better to go, the brain stands and fights instead of running forever from something faster.
 */
/datum/human_ai_action/keep_distance
	id = "keep_distance"
	conflicts = HAI_LIMB_LEGS
	intents = list(HAI_INTENT_ENGAGE)

/datum/human_ai_action/keep_distance/get_weight(datum/human_ai_brain/brain)
	if(brain.rushing() || brain.current_order?.hard || brain.is_acting() || world.time < brain.next_kite_time)
		return 0
	var/obj/item/weapon/gun/gun = brain.peek_gun()
	if(!gun)
		return 0
	var/mob/living/threat = brain.nearest_melee_threat()
	if(!threat)
		return 0
	var/distance = get_dist(brain.body, threat)
	if(distance <= 1 || distance > brain.comfort_distance(threat, gun))
		return 0
	if(world.time >= brain.kite_window_end)
		brain.kite_window_end = world.time + HAI_KITE_WINDOW
		brain.kite_steps = 0
	if(brain.kite_steps >= HAI_KITE_STEP_LIMIT || !SShuman_ai.take_cover_budget())
		return 0
	brain.kite_goal_turf = brain.find_kite_turf(threat)
	return brain.kite_goal_turf ? 80 : 0

/datum/human_ai_action/keep_distance/trigger(datum/human_ai_brain/brain)
	var/turf/goal = brain.kite_goal_turf
	if(!goal)
		return FALSE
	brain.next_kite_time = world.time + HAI_KITE_INTERVAL
	if(!brain.move_to(goal, 0, TRUE))
		return FALSE
	brain.kite_steps++
	brain.kites++
	return TRUE
