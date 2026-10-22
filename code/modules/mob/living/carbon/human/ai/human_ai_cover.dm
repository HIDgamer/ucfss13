/// How well standing on the turf shields against fire from the threat, 0 to 1. The object doing it is left in last_cover_object
/datum/human_ai_brain/proc/cover_against(turf/stand, turf/threat)
	var/best = 0
	last_cover_object = null
	var/looked = 0
	for(var/turf/step_turf as anything in get_line(stand, threat))
		if(step_turf == threat)
			break
		for(var/obj/thing in step_turf)
			if(thing.projectile_coverage < PROJECTILE_COVERAGE_LOW || !thing.density)
				continue
			if(thing.flags_atom & ON_BORDER)
				if(!(thing.dir & get_dir(step_turf, threat)))
					continue
			else if(step_turf == stand)
				continue
			var/value = thing.projectile_coverage * 0.01
			if(value > best)
				best = value
				last_cover_object = thing
		if(++looked >= 2)
			break
	return best

/// True when nothing solid sits between the turf and the threat, so a gun there can shoot
/datum/human_ai_brain/proc/cover_has_line(turf/stand, turf/threat)
	for(var/turf/step_turf as anything in get_line(stand, threat))
		if(step_turf == stand || step_turf == threat)
			continue
		if(step_turf.density || step_turf.opacity)
			return FALSE
	return TRUE

/// Whether the turf can be stood on and is free of what hurts
/datum/human_ai_brain/proc/cover_turf_usable(turf/candidate)
	if(candidate.density || !istype(candidate, /turf/open))
		return FALSE
	if(locate(/obj/flamer_fire) in candidate)
		return FALSE
	for(var/mob/living/occupant in candidate)
		if(occupant != body)
			return FALSE
	for(var/obj/thing in candidate)
		if(thing.density && !(thing.flags_atom & ON_BORDER))
			return FALSE
	return TRUE

/// How well the body is covered where it stands right now against the target
/datum/human_ai_brain/proc/cover_here(turf/threat)
	var/turf/here = get_turf(body)
	if(cover_memo_time == world.time && cover_memo_here == here && cover_memo_threat == threat)
		return cover_memo_value
	cover_memo_time = world.time
	cover_memo_here = here
	cover_memo_threat = threat
	cover_memo_value = cover_against(here, threat)
	return cover_memo_value

/// True while standing behind something that stops most of what comes from the threat
/datum/human_ai_brain/proc/in_good_cover(turf/threat)
	return cover_here(threat) >= HAI_COVER_MIN_SCORE

/// The best turf to fight from against the threat, or null when none beats where the body stands
/datum/human_ai_brain/proc/find_cover(turf/threat, any_range = FALSE, displacing = FALSE)
	var/turf/here = get_turf(body)
	var/best_score = displacing ? HAI_COVER_MIN_SCORE : cover_here(threat) + HAI_COVER_HYSTERESIS
	var/turf/best_turf
	var/obj/best_object
	var/list/candidates = list()
	for(var/obj/thing in range(HAI_COVER_SEARCH_RADIUS, here))
		if(thing.projectile_coverage >= PROJECTILE_COVERAGE_LOW && thing.density && thing.anchored)
			for(var/turf/neighbor in range(1, thing))
				candidates |= neighbor
	var/list/others
	for(var/key in contacts)
		var/datum/ai_contact/contact = contacts[key]
		if(contact.visible && contact.last_turf && contact.last_turf != threat)
			LAZYADD(others, contact.last_turf)
	var/obj/item/weapon/gun/gun = peek_gun()
	var/min_distance = 0
	var/max_distance = any_range ? INFINITY : HAI_SIGHT_RANGE
	if(gun)
		var/datum/human_ai_gun_appraisal/appraisal = get_human_ai_gun_appraisal(gun)
		min_distance = appraisal.min_range
		if(!any_range)
			max_distance = shooting_range(gun)
	for(var/turf/candidate as anything in candidates)
		if(candidate == here || !cover_turf_usable(candidate) || (role?.nests && nest_avoided(candidate)))
			continue
		var/distance = get_dist(candidate, threat)
		if(distance < min_distance || distance > max_distance)
			continue
		var/value = cover_against(candidate, threat)
		if(value < HAI_COVER_MIN_SCORE)
			continue
		var/obj/main_object = last_cover_object
		var/score = value * (cover_has_line(candidate, threat) ? 1 : 0.35) - get_dist(here, candidate) * 0.05
		if(role?.id == "sniper")
			score += clamp(distance / max(max_distance, 1), 0, 1) * 0.3
		if(others)
			var/shared = 0
			for(var/turf/other as anything in others)
				shared += cover_against(candidate, other)
			score = score * 0.7 + (shared / length(others)) * 0.3
		if(score > best_score)
			best_score = score
			best_turf = candidate
			best_object = main_object
	last_cover_object = best_object
	return best_turf

/// The cover to head for against the target, searched at most every few seconds and within the per-fire budget
/datum/human_ai_brain/proc/cover_goal(turf/threat, any_range = FALSE)
	if(cover_goal_turf && world.time < next_cover_search)
		return cover_goal_turf
	if(world.time < next_cover_search || !SShuman_ai.take_cover_budget())
		return null
	next_cover_search = world.time + HAI_COVER_SEARCH_INTERVAL
	cover_goal_turf = find_cover(threat, any_range)
	cover_goal_object = last_cover_object
	return cover_goal_turf

/datum/human_ai_brain/proc/clear_cover_goal()
	cover_goal_turf = null
	cover_goal_object = null

/// How strongly this brain wants to be behind something: bolder types and healthy ones fight in the open
/datum/human_ai_brain/proc/cover_desire()
	if(rushing())
		return 0
	var/health_fraction = clamp(body.health / max(body.maxHealth, 1), 0, 1)
	return personality.scaled("caution", 0.6, 1.5) * (1 + (1 - health_fraction) * 0.7) * (1 + stress * 0.006)

/datum/human_ai_action/move_to_cover
	id = "move_to_cover"
	conflicts = HAI_LIMB_LEGS
	intents = list(HAI_INTENT_ENGAGE)

/datum/human_ai_action/move_to_cover/get_weight(datum/human_ai_brain/brain)
	if(!brain.cover_enabled || brain.reload_phase != HAI_RELOAD_NONE)
		return 0
	var/mob/living/target = brain.get_target()
	if(!target || world.time > brain.target_seen_time + 20)
		return 0
	var/turf/threat = get_turf(target)
	if(get_dist(brain.body, threat) <= 1 || brain.in_good_cover(threat))
		brain.clear_cover_goal()
		return 0
	var/desire = brain.cover_desire()
	if(desire < HAI_COVER_MIN_DESIRE)
		return 0
	return brain.cover_goal(threat) ? 52 * desire : 0

/datum/human_ai_action/move_to_cover/trigger(datum/human_ai_brain/brain)
	var/turf/goal = brain.cover_goal_turf
	if(!goal)
		return FALSE
	if(brain.body.loc == goal)
		brain.clear_cover_goal()
		return FALSE
	if(brain.move_to(goal, 0, get_dist(brain.body, goal) > HAI_SPRINT_MIN_DISTANCE))
		brain.cover_moves++
		return TRUE
	brain.clear_cover_goal()
	return FALSE

/// Flipping a table over to hide behind when nothing better is around
/datum/human_ai_action/flip_cover
	id = "flip_cover"
	conflicts = HAI_LIMB_HANDS
	intents = list(HAI_INTENT_ENGAGE)

/// The table next to the body on the side of the threat that would make a barricade, null if there is none
/datum/human_ai_brain/proc/flippable_table(turf/threat)
	if(world.time < next_flip_time)
		return null
	var/threat_dir = get_dir(body, threat)
	for(var/obj/structure/surface/table/table in range(1, body))
		if(table.flipped || table.loc == body.loc || (table.flags_atom & ON_BORDER))
			continue
		var/side = get_dir(body, table)
		if(!(side in GLOB.cardinals) || !(side & threat_dir))
			continue
		if(table.flipped_projectile_coverage < PROJECTILE_COVERAGE_MEDIUM)
			continue
		return table
	return null

/datum/human_ai_action/flip_cover/get_weight(datum/human_ai_brain/brain)
	if(!brain.cover_enabled || brain.cover_desire() < HAI_COVER_MIN_DESIRE)
		return 0
	var/mob/living/target = brain.get_target()
	if(!target || world.time > brain.target_seen_time + 20)
		return 0
	var/turf/threat = get_turf(target)
	if(get_dist(brain.body, threat) <= 1 || brain.in_good_cover(threat) || brain.cover_goal_turf)
		return 0
	return brain.flippable_table(threat) ? 56 : 0

/datum/human_ai_action/flip_cover/trigger(datum/human_ai_brain/brain)
	var/mob/living/target = brain.get_target()
	if(!target)
		return FALSE
	var/obj/structure/surface/table/table = brain.flippable_table(get_turf(target))
	brain.next_flip_time = world.time + HAI_FLIP_COOLDOWN
	if(!table)
		return FALSE
	var/direction = get_dir(brain.body, table)
	if(brain.body.a_intent != INTENT_HARM)
		brain.body.a_intent_change(INTENT_HARM)
	brain.body.face_atom(table)
	if(!table.flip(direction))
		return FALSE
	table.flip_cooldown = world.time + 5 SECONDS
	brain.tables_flipped++
	brain.log_decision("flipped [table.name]")
	return TRUE

/// What is about to hurt the body where it stands: a live grenade nearby or flames on the tile, null when it is safe
/datum/human_ai_brain/proc/find_hazard()
	var/turf/here = get_turf(body)
	if(locate(/obj/flamer_fire) in here)
		return here
	if(world.time < next_hazard_check)
		return hazard_turf
	next_hazard_check = world.time + HAI_HAZARD_CHECK_INTERVAL
	hazard_turf = null
	for(var/obj/item/explosive/grenade/grenade in range(HAI_HAZARD_RADIUS, here))
		if(grenade.active && !QDELETED(grenade) && human_ai_grenade_hurts(grenade))
			hazard_turf = get_turf(grenade)
			break
	return hazard_turf

/// A turf close by and farther from the hazard than it can reach, without fire on it
/datum/human_ai_brain/proc/escape_turf(turf/hazard)
	var/turf/here = get_turf(body)
	var/turf/best
	var/best_score = -INFINITY
	for(var/turf/candidate in range(4, here))
		if(!cover_turf_usable(candidate))
			continue
		var/away = get_dist(candidate, hazard)
		if(away <= HAI_HAZARD_RADIUS && !(hazard == here && away >= 2))
			continue
		var/score = away - get_dist(here, candidate) * 0.6
		if(score > best_score)
			best_score = score
			best = candidate
	return best

/// Getting clear of a live grenade or burning ground takes over almost everything else
/datum/human_ai_action/avoid_hazard
	id = "avoid_hazard"
	conflicts = HAI_LIMB_LEGS

/datum/human_ai_action/avoid_hazard/get_weight(datum/human_ai_brain/brain)
	if(brain.body.on_fire)
		return 0
	return brain.find_hazard() ? 115 : 0

/datum/human_ai_action/avoid_hazard/trigger(datum/human_ai_brain/brain)
	var/turf/hazard = brain.find_hazard()
	if(!hazard)
		return FALSE
	var/turf/goal = brain.escape_turf(hazard)
	if(!goal)
		return FALSE
	brain.cancel_reload("hazard")
	if(brain.move_to(goal, 0, TRUE))
		brain.hazard_dodges++
		return TRUE
	return FALSE
