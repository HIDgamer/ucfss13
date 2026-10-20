/// Whether something slow, like a vault or a pry, is still running
/datum/human_ai_brain/proc/is_acting()
	return acting_until > world.time

/**
 * Walks the body toward the goal one step per call and handles what is in the way.
 * Returns TRUE while it is walking or waiting on an obstacle, FALSE once arrived or when the goal cannot be reached, see move_state.
 */
/datum/human_ai_brain/proc/move_to(atom/goal, arrive_distance = HAI_ARRIVE_DISTANCE, want_sprint = FALSE)
	move_state = HAI_MOVE_BLOCKED
	var/turf/goal_turf = get_turf(goal)
	var/turf/here = get_turf(body)
	if(!goal_turf || !here || goal_turf.z != here.z)
		return FALSE
	if(get_dist(here, goal_turf) <= arrive_distance)
		move_state = HAI_MOVE_ARRIVED
		climb_detours = 0
		set_sprint(FALSE)
		return FALSE
	if(!move_goal || get_dist(move_goal, goal_turf) > 2)
		reset_progress()
	move_goal = goal_turf
	move_state = HAI_MOVE_WALKING
	if(is_acting() || world.time < next_step_time)
		// A vault, a pry or a hack keeps the body in place for a while, which is work and not being stuck
		if(is_acting())
			last_progress_time = world.time
		return TRUE
	if(!stand_up())
		return TRUE

	if(here != last_progress_turf)
		last_progress_turf = here
		last_progress_time = world.time
		stuck_recoveries = 0
		route_retries = 0
	else if(world.time > last_progress_time + HAI_STUCK_TIME)
		if(!recover_stuck(here, goal_turf))
			move_state = HAI_MOVE_BLOCKED
			return FALSE

	set_sprint(want_sprint && move_cap >= HAI_MOVE_CAP_SPRINT && get_dist(here, goal_turf) > HAI_SPRINT_MIN_DISTANCE)
	body.m_intent = (move_cap <= HAI_MOVE_CAP_WALK) ? MOVE_INTENT_WALK : MOVE_INTENT_RUN

	var/turf/next_turf
	if(get_dist(here, goal_turf) <= 2 && cover_has_line(here, goal_turf))
		next_turf = get_step(here, get_dir(here, goal_turf))
	else
		next_turf = next_path_turf(here, goal_turf)
		if(move_state == HAI_MOVE_BLOCKED)
			return FALSE

	if(next_turf && is_blocked_turf(next_turf))
		path = null
		route_retries++
		if(route_retries > HAI_ROUTE_RETRIES)
			log_decision("every way to [goal_turf.x],[goal_turf.y] is blocked")
			move_state = HAI_MOVE_BLOCKED
			return FALSE
	else if(next_turf)
		if(step_to_turf(next_turf))
			return TRUE
		var/list/obstacle = find_obstacle(here, next_turf)
		if(obstacle)
			handle_obstacle(obstacle, next_turf)
			return TRUE
	sidestep(get_dir(here, goal_turf), goal_turf)
	return TRUE

/datum/human_ai_brain/proc/reset_progress()
	last_progress_turf = null
	last_progress_time = world.time
	stuck_recoveries = 0
	route_retries = 0
	climb_detours = 0
	path = null

/// Gets the body onto its feet, false while that takes the turn
/datum/human_ai_brain/proc/stand_up()
	if(body.body_position != LYING_DOWN)
		return TRUE
	if(HAS_TRAIT(body, TRAIT_FLOORED))
		return FALSE
	body.set_resting(FALSE)
	next_step_time = world.time + 5
	return FALSE

/datum/human_ai_brain/proc/set_sprint(on)
	if(on == body.sprinting)
		return
	if(!on)
		body.stop_sprint()
		return
	if(body.get_sprint_energy() >= HAI_SPRINT_MIN_ENERGY && !body.sprint_exhausted)
		body.start_sprint()

/// Called when the body has not moved for a while, true if it tried something, false when the goal is given up
/datum/human_ai_brain/proc/recover_stuck(turf/here, turf/goal_turf)
	stuck_recoveries++
	last_progress_time = world.time
	path = null
	next_path_request = 0
	if(stuck_recoveries > HAI_GIVE_UP_LIMIT)
		log_decision("gave up reaching [goal_turf.x],[goal_turf.y]")
		reset_progress()
		return FALSE
	var/turf/ahead = get_step(here, get_dir(here, goal_turf))
	if(ahead)
		remember_blocked(ahead, "stuck")
	log_decision("stuck, recovery [stuck_recoveries]")
	body.resist()
	sidestep(turn(get_dir(here, goal_turf), pick(90, -90)), goal_turf)
	return TRUE

/datum/human_ai_brain/proc/step_to_turf(turf/next_turf)
	var/turf/here = get_turf(body)
	var/direction = get_dir(here, next_turf)
	if(!direction)
		return FALSE
	body.set_step_glide(body.move_delay)
	if(!step(body, direction))
		return FALSE
	next_step_time = world.time + body.movement_delay()
	if(length(path) && get_turf(body) == path[1])
		path.Cut(1, 2)
	return TRUE

/// Tries the directions beside the wanted one
/datum/human_ai_brain/proc/sidestep(wanted_dir, turf/goal_turf)
	if(!wanted_dir)
		return FALSE
	var/first = prob(50) ? 45 : -45
	for(var/angle in list(first, -first, first * 2, -first * 2))
		var/turf/candidate = get_step(body, turn(wanted_dir, angle))
		if(!candidate || is_blocked_turf(candidate))
			continue
		if(goal_turf && get_dist(candidate, goal_turf) > get_dist(body, goal_turf) + 1)
			continue
		if(step_to_turf(candidate))
			return TRUE
	return FALSE

/// The next turf of the cached route, asking for a new route when the cache is stale or its next step is blocked
/datum/human_ai_brain/proc/next_path_turf(turf/here, turf/goal_turf)
	if(length(path) && path[1] == here)
		path.Cut(1, 2)
	if(length(path) && is_blocked_turf(path[1]))
		route_retries++
		path = null
		if(route_retries > HAI_ROUTE_RETRIES)
			log_decision("every route to [goal_turf.x],[goal_turf.y] is blocked")
			move_state = HAI_MOVE_BLOCKED
			return null
	var/stale = !length(path) || !path_goal || get_dist(path_goal, goal_turf) > 2 || world.time > path_built_at + HAI_PATH_MAX_AGE
	if(stale && world.time >= next_path_request && SShuman_ai.take_path_budget())
		next_path_request = world.time + HAI_PATH_REQUEST_COOLDOWN
		var/list/routed = request_path(here, goal_turf)
		path = routed
		path_goal = goal_turf
		path_built_at = world.time
		if(islist(routed) && !length(routed))
			route_retries++
			path = null
			if(route_retries > HAI_ROUTE_RETRIES)
				log_decision("no route to [goal_turf.x],[goal_turf.y]")
				move_state = HAI_MOVE_BLOCKED
				return null
	if(length(path))
		return path[1]
	return get_step(here, get_dir(here, goal_turf))

/// Whole-map human route from the native solver, null when it is unavailable and an empty list when it finds no route
/datum/human_ai_brain/proc/request_path(turf/here, turf/goal_turf)
	if(!SSxeno_pathfinding?.available || !xeno_pathfind_profiles_available())
		return null
	var/result = rust_xeno_pathfind_route("[here.z],[here.x],[here.y],[goal_turf.x],[goal_turf.y]", XENO_PATHFIND_PROFILE_HUMAN)
	if(!length(result))
		return list()
	var/list/waypoints = list()
	for(var/pair in splittext(result, ";"))
		var/list/point = splittext(pair, ",")
		if(length(point) != 2)
			continue
		var/turf/waypoint_turf = locate(text2num(point[1]), text2num(point[2]), here.z)
		if(waypoint_turf)
			waypoints += waypoint_turf
	if(length(waypoints) && waypoints[1] == here)
		waypoints.Cut(1, 2)
	return waypoints

/// The turf a follower with this slot number should stand on relative to the leader
/datum/human_ai_brain/proc/formation_turf(atom/leader, slot = 0, spacing = HAI_FORMATION_SPACING)
	var/turf/slot_turf = get_turf(leader)
	if(!slot_turf)
		return null
	var/back = turn(leader.dir, 180)
	var/side = turn(leader.dir, 90)
	var/rank = 1 + round(slot / 2)
	var/lateral = (slot % 2) ? 1 : -1
	var/sideways = slot > 0 ? 1 + round(slot / 4) : 0
	switch(squad?.formation)
		if(HAI_FORM_COLUMN)
			rank = slot + 1
			sideways = 0
		if(HAI_FORM_LINE)
			rank = 1
			sideways = (1 + round(slot / 2)) * spacing
		if(HAI_FORM_SCATTER)
			rank = 1 + (slot * 3) % 3
			lateral = ((slot * 7) % 2) ? 1 : -1
			sideways = (slot * 5) % 4
	for(var/step_count in 1 to rank * spacing)
		var/turf/behind = get_step(slot_turf, back)
		if(!behind || behind.density)
			break
		slot_turf = behind
	for(var/step_count in 1 to sideways)
		var/turf/beside = get_step(slot_turf, lateral > 0 ? side : turn(side, 180))
		if(!beside || beside.density)
			break
		slot_turf = beside
	return slot_turf

/// Keeps the body in its formation slot behind the leader
/datum/human_ai_brain/proc/follow_leader(atom/leader, slot = 0)
	var/turf/slot_turf = formation_turf(leader, slot)
	if(!slot_turf)
		return FALSE
	return move_to(slot_turf, 0, get_dist(body, slot_turf) > HAI_SPRINT_MIN_DISTANCE)
