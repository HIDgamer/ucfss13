/**
 * The fake stairs. The decks of a ship are drawn in different places of the map, sometimes on the same level and sometimes on another one, and a
 * row of step triggers carries whoever steps on it across by a fixed vector. The native pathfinder only knows what can be walked to, so to it the
 * other deck is somewhere that cannot be reached. A brain that finds there is no walking route to where it is going looks for a stair that
 * leads there, walks onto it and carries on from the other side.
 */

/// Every step trigger that moves what steps on it by a vector, so the stairs do not have to be hunted for in the world
GLOBAL_LIST_EMPTY(vector_triggers)
/// How many times that list has changed, which says when the stairs built from it are out of date
GLOBAL_VAR_INIT(vector_trigger_changes, 0)

/// A set of triggers side by side with the same vector, which is one flight of stairs
/datum/human_ai_stair_group
	var/vector_x = 0
	var/vector_y = 0
	var/vector_z = 0
	var/list/turf/entries = list()

/datum/human_ai_stair_group/Destroy()
	entries = null
	return ..()

/// Where a step on the entry ends up
/datum/human_ai_stair_group/proc/exit_of(turf/entry)
	RETURN_TYPE(/turf)
	return locate(entry.x + vector_x, entry.y + vector_y, entry.z + vector_z)

/// The entry of the flight closest to the turf
/datum/human_ai_stair_group/proc/nearest_entry(turf/from_turf)
	RETURN_TYPE(/turf)
	var/turf/best
	var/best_distance = INFINITY
	for(var/turf/entry as anything in entries)
		if(entry.z != from_turf.z)
			continue
		var/distance = get_dist(from_turf, entry)
		if(distance < best_distance)
			best = entry
			best_distance = distance
	return best

/// The flights of stairs in the world, rebuilt whenever the triggers that make them up have changed
GLOBAL_LIST_EMPTY(human_ai_stair_groups)
GLOBAL_VAR_INIT(human_ai_stairs_built_for, -1)

/// The pairs of turfs found to be walkable between or not, by the key of the pair to list(answer, until when it holds)
GLOBAL_LIST_EMPTY(human_ai_reach_cache)

/proc/human_ai_stair_groups()
	RETURN_TYPE(/list)
	if(GLOB.vector_trigger_changes == GLOB.human_ai_stairs_built_for)
		return GLOB.human_ai_stair_groups
	QDEL_LIST(GLOB.human_ai_stair_groups)
	for(var/obj/effect/step_trigger/teleporter_vector/trigger as anything in GLOB.vector_triggers)
		var/turf/entry = get_turf(trigger)
		if(QDELETED(trigger) || !entry)
			continue
		// A step of a tile or two is the map's way of lining two things up, a stair carries someone clear across the map or to another level
		if(trigger.vector_z == 0 && abs(trigger.vector_x) + abs(trigger.vector_y) < HAI_STAIR_MIN_VECTOR)
			continue
		var/turf/exit = locate(entry.x + trigger.vector_x, entry.y + trigger.vector_y, entry.z + trigger.vector_z)
		if(!exit || exit.density)
			continue
		var/datum/human_ai_stair_group/found
		for(var/datum/human_ai_stair_group/group as anything in GLOB.human_ai_stair_groups)
			if(group.vector_x != trigger.vector_x || group.vector_y != trigger.vector_y || group.vector_z != trigger.vector_z)
				continue
			for(var/turf/other as anything in group.entries)
				if(other.z == entry.z && get_dist(other, entry) <= HAI_STAIR_GROUP_RANGE)
					found = group
					break
			if(found)
				break
		if(!found)
			found = new
			found.vector_x = trigger.vector_x
			found.vector_y = trigger.vector_y
			found.vector_z = trigger.vector_z
			GLOB.human_ai_stair_groups += found
		found.entries |= entry
	GLOB.human_ai_stairs_built_for = GLOB.vector_trigger_changes
	return GLOB.human_ai_stair_groups

/// Whether the native router finds a way on foot from one turf to the other, remembered for a while because answering takes a search of the whole level
/proc/human_ai_route_exists(turf/from_turf, turf/to_turf)
	if(!from_turf || !to_turf || from_turf.z != to_turf.z)
		return FALSE
	if(from_turf == to_turf)
		return TRUE
	if(!SSxeno_pathfinding?.available || !xeno_pathfind_profiles_available())
		return FALSE
	var/key = "[from_turf.x],[from_turf.y],[to_turf.x],[to_turf.y],[to_turf.z]"
	var/list/known = GLOB.human_ai_reach_cache[key]
	if(known && world.time < known[2])
		return known[1]
	if(length(GLOB.human_ai_reach_cache) > HAI_REACH_CACHE_SIZE)
		GLOB.human_ai_reach_cache = list()
	var/found = length(rust_xeno_pathfind_route("[from_turf.z],[from_turf.x],[from_turf.y],[to_turf.x],[to_turf.y]", XENO_PATHFIND_PROFILE_HUMAN)) > 0
	GLOB.human_ai_reach_cache[key] = list(found, world.time + HAI_REACH_CACHE_TIME)
	return found

/// Forgets the stair being headed for
/datum/human_ai_brain/proc/clear_stairs(reason)
	if(stair_entry && reason)
		log_decision("done with the stair at [stair_entry.x],[stair_entry.y]: [reason]")
	stair_entry = null
	stair_exit = null
	stair_goal = null
	stair_ladder = null
	stair_direction = null
	stair_on_entry_since = 0

/**
 * The stair to take to get to a goal there is no way on foot to, from where the body stands, and whether one was found. A flight that can be walked to
 * and that comes out where the goal can be walked to is taken, and when none does a pair of flights, one after the other, is looked for.
 */
/datum/human_ai_brain/proc/plan_stairs(turf/here, turf/goal_turf)
	if(world.time < next_stair_plan || !SShuman_ai.take_path_budget())
		return FALSE
	next_stair_plan = world.time + HAI_STAIR_PLAN_GAP
	var/list/groups = human_ai_stair_groups()
	var/list/options = list()
	for(var/datum/human_ai_stair_group/group as anything in groups)
		var/turf/entry = group.nearest_entry(here)
		if(!entry || stair_skips[REF(entry)] > world.time || !human_ai_route_exists(here, entry))
			continue
		var/turf/exit = group.exit_of(entry)
		if(!exit)
			continue
		options += list(list(group, entry, exit, get_dist(here, entry), null, null))
	// The ladders of a ship join its decks as the stairs do, and many of them join places of the same level
	for(var/obj/structure/ladder/ladder as anything in GLOB.ladder_list)
		var/turf/ladder_turf = get_turf(ladder)
		if(QDELETED(ladder) || !ladder_turf || ladder_turf.z != here.z || stair_skips[REF(ladder_turf)] > world.time)
			continue
		for(var/direction in list("up", "down"))
			var/obj/structure/ladder/partner = (direction == "up") ? ladder.up : ladder.down
			var/turf/partner_turf = partner ? get_turf(partner) : null
			if(!partner_turf || partner_turf.z != here.z || get_dist(ladder_turf, partner_turf) < HAI_STAIR_MIN_VECTOR)
				continue
			var/turf/stand = ladder_standing_turf(ladder_turf, here)
			if(!stand || !human_ai_route_exists(here, stand))
				continue
			options += list(list(null, ladder_turf, partner_turf, get_dist(here, ladder_turf), ladder, direction))
	if(!length(options))
		return FALSE
	// The nearest flight first, so the shortest way wins
	for(var/index in 1 to length(options) - 1)
		for(var/other in index + 1 to length(options))
			if(options[other][4] < options[index][4])
				options.Swap(index, other)
	for(var/list/option as anything in options)
		if(human_ai_route_exists(option[3], goal_turf))
			return start_stairs(option[2], option[3], goal_turf, option[5], option[6])
	// No single one does it, so one to somewhere from which another one does
	for(var/list/option as anything in options)
		var/turf/landing = option[3]
		for(var/datum/human_ai_stair_group/second as anything in groups)
			var/turf/second_entry = second.nearest_entry(landing)
			if(!second_entry || second_entry == option[2] || !human_ai_route_exists(landing, second_entry))
				continue
			var/turf/second_exit = second.exit_of(second_entry)
			if(second_exit && human_ai_route_exists(second_exit, goal_turf))
				return start_stairs(option[2], option[3], goal_turf, option[5], option[6])
	return FALSE

/// A turf beside the ladder to climb it from, the one closest to the body
/datum/human_ai_brain/proc/ladder_standing_turf(turf/ladder_turf, turf/from_turf)
	RETURN_TYPE(/turf)
	var/turf/best
	var/best_distance = INFINITY
	for(var/turf/candidate in range(1, ladder_turf))
		if(candidate.density || !cover_turf_usable(candidate))
			continue
		var/distance = get_dist(from_turf, candidate)
		if(distance < best_distance)
			best = candidate
			best_distance = distance
	return best

/datum/human_ai_brain/proc/start_stairs(turf/entry, turf/exit, turf/goal_turf, obj/structure/ladder/ladder, direction)
	stair_entry = entry
	stair_exit = exit
	stair_ladder = ladder
	stair_direction = direction
	stair_goal = goal_turf
	stair_until = world.time + HAI_STAIR_TIME
	stair_on_entry_since = 0
	path = null
	log_decision("no way on foot to [goal_turf.x],[goal_turf.y],[goal_turf.z], taking the stair at [entry.x],[entry.y],[entry.z]")
	return TRUE

/**
 * Walks to the stair planned and steps on it, which carries the body across. True while it is on its way and once across, false when the stair
 * could not be reached or did not take it anywhere, see move_state. The goal it was planned for may have been changed since, which cancels it.
 */
/datum/human_ai_brain/proc/walk_stairs(turf/goal_turf, want_sprint)
	if(!stair_entry)
		return FALSE
	var/turf/here = get_turf(body)
	if(world.time > stair_until || (stair_goal && goal_turf && get_dist(stair_goal, goal_turf) > 3 && stair_goal.z == goal_turf.z))
		clear_stairs("it took too long or the goal changed")
		return FALSE
	// Across: the body is where the stair comes out and not where it went in
	if(here.z == stair_exit.z && get_dist(here, stair_exit) <= HAI_STAIR_LANDING && (here.z != stair_entry.z || get_dist(here, stair_entry) >= HAI_STAIR_MIN_VECTOR - 1))
		stairs_taken++
		clear_stairs("came out at [here.x],[here.y],[here.z]")
		reset_progress()
		move_goal = null
		next_step_time = world.time + 5
		next_stair_plan = 0
		move_state = HAI_MOVE_WALKING
		return TRUE
	move_state = HAI_MOVE_WALKING
	if(stair_ladder)
		// A ladder is climbed from beside it
		if(get_dist(here, stair_entry) <= 1)
			if(is_acting())
				return TRUE
			if(QDELETED(stair_ladder) || !stand_up())
				return TRUE
			body.face_atom(stair_ladder)
			acting_until = world.time + HAI_LADDER_TIME
			INVOKE_ASYNC(src, PROC_REF(use_ladder), stair_ladder, stair_direction)
			return TRUE
		stair_inner = TRUE
		var/approaching = move_to(stair_entry, 1, want_sprint)
		stair_inner = FALSE
		if(!approaching && move_state != HAI_MOVE_ARRIVED)
			stair_skips[REF(stair_entry)] = world.time + HAI_STAIR_SKIP
			clear_stairs("could not get to the ladder")
			move_state = HAI_MOVE_BLOCKED
			return FALSE
		move_state = HAI_MOVE_WALKING
		return TRUE
	if(here == stair_entry)
		// The trigger takes a moment, if it never does the stair is not one to rely on
		if(!stair_on_entry_since)
			stair_on_entry_since = world.time
		else if(world.time > stair_on_entry_since + HAI_STAIR_WAIT)
			stair_skips[REF(stair_entry)] = world.time + HAI_STAIR_SKIP
			clear_stairs("stood on it and went nowhere")
			move_state = HAI_MOVE_BLOCKED
			return FALSE
		return TRUE
	stair_on_entry_since = 0
	stair_inner = TRUE
	var/walking = move_to(stair_entry, 0, want_sprint)
	stair_inner = FALSE
	if(!walking && move_state != HAI_MOVE_ARRIVED)
		stair_skips[REF(stair_entry)] = world.time + HAI_STAIR_SKIP
		clear_stairs("could not get to it")
		move_state = HAI_MOVE_BLOCKED
		return FALSE
	move_state = HAI_MOVE_WALKING
	return TRUE

/**
 * The stair on this level that leads toward another level, found by working out which levels the stairs join and taking the first step of the
 * shortest chain, as list(entry turf, exit turf), null when none does. Looked for when there is no ladder to climb.
 */
/datum/human_ai_brain/proc/find_stair_toward(target_z)
	var/start_z = body.z
	if(start_z == target_z)
		return null
	var/list/groups = human_ai_stair_groups()
	var/list/links = list()
	for(var/datum/human_ai_stair_group/group as anything in groups)
		if(!group.vector_z)
			continue
		for(var/turf/entry as anything in group.entries)
			var/list/reach = links["[entry.z]"]
			if(!reach)
				reach = list()
				links["[entry.z]"] = reach
			reach |= entry.z + group.vector_z
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
	var/first_level = target_z
	while(previous["[first_level]"] != start_z)
		first_level = previous["[first_level]"]
	var/turf/here = get_turf(body)
	var/turf/best_entry
	var/turf/best_exit
	var/best_distance = INFINITY
	for(var/datum/human_ai_stair_group/group as anything in groups)
		if(group.vector_z != first_level - start_z)
			continue
		var/turf/entry = group.nearest_entry(here)
		if(!entry || stair_skips[REF(entry)] > world.time || !human_ai_route_exists(here, entry))
			continue
		var/distance = get_dist(here, entry)
		if(distance < best_distance)
			best_entry = entry
			best_exit = group.exit_of(entry)
			best_distance = distance
	if(!best_entry || !best_exit)
		return null
	return list(best_entry, best_exit)
