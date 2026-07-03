/**
 * Movement for xeno_ai_controller. When the native xeno_pathfind library is
 * present (see code/__DEFINES/__xeno_pathfind.dm), routes through a real A*
 * plan over a small local grid via advance_along_path() - this is what fixes
 * zigzagging and lets the AI route around walls properly. When it isn't
 * present (or a planned step fails - a mob wandered into the way, a door
 * closed), falls straight back to the original greedy step_towards() + one
 * tile sidestep. Either way a host with no native library at all behaves
 * exactly as before this was added.
 */
/datum/xeno_ai_controller/proc/process_movement()
	if(!pilot || !current_target)
		return

	if(!is_valid_target(current_target))
		drop_target() // Target actually died/became invalid - nothing to go investigate.
		return

	last_seen_turf = get_turf(current_target)

	if(get_dist(pilot, current_target) <= 1 && pilot.Adjacent(current_target))
		ai_state = AI_STATE_ATTACKING
		blocked_attempts = 0
		path_queue = null
		return

	if(advance_along_path(current_target))
		blocked_attempts = 0
		return

	if(step_towards(pilot, current_target))
		blocked_attempts = 0
		return

	var/obj/structure/blocking_obstacle = get_blocking_obstacle(current_target)
	if(blocking_obstacle)
		attack_blocking_obstacle(blocking_obstacle)
		blocked_attempts = 0
		return

	if(navigate_around())
		blocked_attempts = 0
		return

	blocked_attempts++
	if(blocked_attempts >= 2)
		drop_target(TRUE) // Couldn't force through - go investigate where it was last seen instead of forgetting it outright.

/**
 * Consumes one step of a cached native-pathfinder route toward goal,
 * (re)computing it first if needed. Returns FALSE - meaning "fall through to
 * the old greedy behavior for this tick" - if the native library isn't
 * available, no path exists, the goal is out of local-grid range, or the
 * planned next tile turned out to be blocked when we actually tried to move
 * (something wandered into the way, a door shut) - in that last case the
 * stale plan is dropped and a fresh one gets computed next tick.
 */
/datum/xeno_ai_controller/proc/advance_along_path(atom/goal)
	if(!pilot || !goal)
		return FALSE

	var/turf/goal_turf = get_turf(goal)
	if(!goal_turf)
		return FALSE

	if(!path_queue || !length(path_queue) || path_goal != goal_turf)
		path_queue = compute_path(goal_turf)
		path_goal = goal_turf

	if(!path_queue || !length(path_queue))
		return FALSE

	var/turf/pilot_turf = get_turf(pilot)
	if(pilot_turf == path_queue[1])
		path_queue.Cut(1, 2)
		if(!length(path_queue))
			return FALSE

	var/turf/next_step = path_queue[1]
	if(!step_towards(pilot, next_step))
		path_queue = null // Plan is stale - let this tick fall back to greedy/obstacle handling, replan next tick.
		return FALSE

	if(get_turf(pilot) == next_step)
		path_queue.Cut(1, 2)
	return TRUE

/**
 * Builds a bounded local grid around the pilot and goal (only turf density
 * counts as "blocked" - doors/windows/tables are left for the existing
 * per-step obstacle-forcing and native climb-over handling, not modeled in
 * the grid) and asks the native solver for a route. Returns null (meaning
 * "no plan, use the old behavior") if the library isn't present, the hop is
 * too large for local grid pathing, or no path exists - long-range chases
 * are already handled fine by the greedy approach, this is specifically for
 * routing around nearby walls/dead-ends.
 */
/datum/xeno_ai_controller/proc/compute_path(turf/goal_turf)
	var/turf/pilot_turf = get_turf(pilot)
	if(!pilot_turf || !goal_turf || pilot_turf.z != goal_turf.z)
		return null

	var/margin = 2
	var/min_x = max(min(pilot_turf.x, goal_turf.x) - margin, 1)
	var/min_y = max(min(pilot_turf.y, goal_turf.y) - margin, 1)
	var/max_x = min(max(pilot_turf.x, goal_turf.x) + margin, world.maxx)
	var/max_y = min(max(pilot_turf.y, goal_turf.y) + margin, world.maxy)

	var/width = max_x - min_x + 1
	var/height = max_y - min_y + 1
	if(width <= 0 || height <= 0 || width * height > XENO_PATHFIND_MAX_CELLS)
		return null

	var/list/blocked = list()
	for(var/y in min_y to max_y)
		for(var/x in min_x to max_x)
			var/turf/T = locate(x, y, pilot_turf.z)
			blocked += (T && T.density) ? "1" : "0"

	var/grid_desc = "[width],[height],[pilot_turf.x - min_x],[pilot_turf.y - min_y],[goal_turf.x - min_x],[goal_turf.y - min_y]"
	var/blocked_map = blocked.Join("")

	var/result = rustg_xeno_pathfind(grid_desc, blocked_map)
	if(!result || !length(result))
		return null

	var/list/waypoints = list()
	for(var/pair in splittext(result, ";"))
		var/list/point = splittext(pair, ",")
		if(length(point) != 2)
			continue
		var/turf/T = locate(text2num(point[1]) + min_x, text2num(point[2]) + min_y, pilot_turf.z)
		if(T)
			waypoints += T

	if(length(waypoints) && waypoints[1] == pilot_turf)
		waypoints.Cut(1, 2)

	return waypoints

/// Single-tile sidestep around one obstacle. Not real pathfinding - if this fails too the caller gives up on the target.
/datum/xeno_ai_controller/proc/navigate_around()
	if(!pilot || !current_target)
		return FALSE

	var/target_dir = get_dir(pilot, current_target)
	var/list/side_dirs = list(turn(target_dir, 90), turn(target_dir, -90))
	for(var/side_dir in side_dirs)
		if(step(pilot, side_dir))
			return TRUE
	return FALSE

/**
 * A dense, slashable structure directly between the pilot and its goal, if any
 * (locked airlocks, windows, girders, etc.). Climbable structures like tables
 * are never returned here - BlockedPassDirs() already lets any isliving() mob
 * climb over those for free via native movement, same as bump-opening an
 * unlocked door, so there's nothing for the AI to do about those. This only
 * matters for obstacles that actually need force: xenos can't badge through
 * access-locked doors and can't walk through glass, so they slash instead,
 * same as a player would.
 */
/datum/xeno_ai_controller/proc/get_blocking_obstacle(atom/goal)
	if(!pilot || !goal)
		return null
	var/turf/next_turf = get_step(pilot, get_dir(pilot, goal))
	if(!next_turf)
		return null
	for(var/obj/structure/blocking_obstacle in next_turf)
		if(!blocking_obstacle.density || blocking_obstacle.unslashable || blocking_obstacle.climbable)
			continue
		return blocking_obstacle
	return null

/datum/xeno_ai_controller/proc/attack_blocking_obstacle(obj/structure/target_obstacle)
	if(!pilot || !target_obstacle)
		return
	pilot.setDir(get_dir(pilot, target_obstacle))
	pilot.a_intent = INTENT_HARM
	target_obstacle.attack_alien(pilot)
