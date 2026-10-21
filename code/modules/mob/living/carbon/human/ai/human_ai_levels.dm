/**
 * Which ladder on the level the body is standing on starts the shortest way to the target level, as list(ladder, "up" or "down"), null when no chain
 * of ladders leads there. The levels the ladders join are searched breadth first, so a goal two decks away is reached by climbing twice.
 */
/datum/human_ai_brain/proc/find_ladder_toward(target_z)
	var/start_z = body.z
	if(start_z == target_z)
		return null
	var/list/links = list()
	for(var/obj/structure/ladder/ladder as anything in GLOB.ladder_list)
		for(var/obj/structure/ladder/other in list(ladder.up, ladder.down))
			var/turf/from_turf = get_turf(ladder)
			var/turf/to_turf = get_turf(other)
			if(!from_turf || !to_turf)
				continue
			var/list/reach = links["[from_turf.z]"]
			if(!reach)
				reach = list()
				links["[from_turf.z]"] = reach
			reach |= to_turf.z
	var/list/previous = list("[start_z]" = 0)
	var/list/queue = list(start_z)
	var/index = 0
	while(index < length(queue))
		index++
		var/level = queue[index]
		if(level == target_z)
			break
		for(var/next_level in links["[level]"])
			if(!isnull(previous["[next_level]"]))
				continue
			previous["[next_level]"] = level
			queue += next_level
	if(isnull(previous["[target_z]"]))
		return null
	// The first level on the way, found by walking the chain back from the goal
	var/first_level = target_z
	while(previous["[first_level]"] != start_z)
		first_level = previous["[first_level]"]
	var/obj/structure/ladder/best
	var/best_direction
	var/best_distance = INFINITY
	for(var/obj/structure/ladder/candidate as anything in GLOB.ladder_list)
		var/turf/candidate_turf = get_turf(candidate)
		if(!candidate_turf || candidate_turf.z != start_z)
			continue
		var/direction
		var/turf/up_turf = candidate.up ? get_turf(candidate.up) : null
		var/turf/down_turf = candidate.down ? get_turf(candidate.down) : null
		if(up_turf && up_turf.z == first_level)
			direction = "up"
		else if(down_turf && down_turf.z == first_level)
			direction = "down"
		else
			continue
		var/distance = get_dist(body, candidate_turf)
		if(distance < best_distance)
			best = candidate
			best_direction = direction
			best_distance = distance
	if(!best)
		return null
	return list(best, best_direction)

/**
 * The goal is on another level: walks to the ladder that leads toward it and climbs. True while the body is on its way or climbing, false when
 * there is no ladder that leads there or the ladder cannot be reached, see move_state.
 */
/datum/human_ai_brain/proc/climb_toward(turf/goal_turf, want_sprint)
	move_state = HAI_MOVE_WALKING
	if(is_acting())
		last_progress_time = world.time
		return TRUE
	var/list/route = find_ladder_toward(goal_turf.z)
	if(!route)
		log_decision("no ladder leads from level [body.z] to level [goal_turf.z]")
		move_state = HAI_MOVE_BLOCKED
		return FALSE
	var/obj/structure/ladder/ladder = route[1]
	var/turf/ladder_turf = get_turf(ladder)
	if(get_dist(body, ladder_turf) > 1)
		if(move_to(ladder_turf, 1, want_sprint))
			return TRUE
		if(move_state != HAI_MOVE_ARRIVED)
			return FALSE
	if(!stand_up())
		return TRUE
	acting_until = world.time + HAI_LADDER_TIME
	INVOKE_ASYNC(src, PROC_REF(use_ladder), ladder, route[2])
	return TRUE

/// Climbs the ladder, the ladder does the climbing and moves the body to the other level
/datum/human_ai_brain/proc/use_ladder(obj/structure/ladder/ladder, direction)
	var/from_level = body.z
	if(!QDELETED(body) && !QDELETED(ladder) && ladder.ai_use(body, direction))
		ladders_climbed++
		log_decision("climbed [direction] from level [from_level] to level [body.z]")
		reset_progress()
		move_goal = null
		next_step_time = world.time + 5
	if(!QDELETED(src))
		acting_until = 0
