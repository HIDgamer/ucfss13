/**
 * Obstacle forcing for zombie_ai_controller - ported from xeno_ai_movement.dm's
 * handle_travel_obstacles()/get_climbable_obstacle()/get_blocking_obstacle()/
 * attack_blocking_obstacle(), trimmed to what a "brainless drone... ruthless"
 * zombie actually needs: no hive/pack/cover-check/friendly-wall logic, no
 * vehicle handling, no wall-digging (never requested - zombies force through
 * doors/windows/barricades and climb furniture, they don't claw through
 * turfs). Still no real pathfinding (Phase 3) - this only kicks in once a
 * direct cardinal_step_towards() has already failed.
 */

/**
 * Route-first entry point every movement flow (process_movement()/return_to_anchor()) calls
 * instead of cardinal_step_towards() directly. A goal already close is stepped at directly -
 * routing to a moving nearby goal plans to where it WAS, walks the stale route the wrong way,
 * replans, turns around - exactly the "walking back and forth" pacing a route would cause at
 * short range where a plain cardinal step can't meaningfully be wrong anyway. Mirrors xeno's
 * travel_to() reasoning exactly, minus the flag param - a zombie only ever has the one travel
 * mode (always force obstacles, no cover-check/static-goal variants to select between).
 */
/datum/zombie_ai_controller/proc/travel_to(atom/goal)
	if(!pilot || !goal)
		return FALSE
	if(get_dist(pilot, goal) <= ZOMBIE_AI_TRAVEL_DIRECT_RANGE)
		// cardinal_step_towards() tries the primary direction toward goal, then falls back to
		// secondary if primary fails - and treats EITHER succeeding as "handled." When primary is
		// genuinely blocked (a window, a table) but secondary is open floor running alongside the
		// obstacle (the common case unless the target is perfectly axis-aligned), it just walks
		// sideways every tick, travel_to() reports progress, and handle_travel_obstacles() - the
		// only place that ever looks at get_climbable_obstacle()/get_blocking_obstacle() - never
		// runs at all. Checked here, not inside cardinal_step_towards() itself, which advance_along_path()
		// also calls (to consume a single routed step) and should keep its existing behavior unchanged.
		if(!primary_direction_blocked(goal) && cardinal_step_towards(goal))
			return TRUE
		return handle_travel_obstacles(goal)
	if(advance_along_path(goal))
		return TRUE
	return handle_travel_obstacles(goal)

/**
 * Shared obstacle-handling tail for travel_to()'s two "a direct/routed step didn't work" cases:
 * climb what's climbable (barricades get smashed instead, see should_smash_instead_of_climb()),
 * otherwise claw through whatever's blocking. A routed step that just failed
 * (advance_along_path()) points every check below at the actual blocked waypoint instead of the
 * far ultimate goal - consumed and cleared unconditionally so a stale value can never survive
 * into a later, unrelated call; falls back to goal when this is a direct-step failure that never
 * went through advance_along_path() at all.
 */
/datum/zombie_ai_controller/proc/handle_travel_obstacles(atom/goal)
	var/atom/obstacle_goal = route_block_turf || goal
	route_block_turf = null

	var/obj/structure/climbable_obstacle = get_climbable_obstacle(obstacle_goal)
	if(climbable_obstacle)
		if(should_smash_instead_of_climb(climbable_obstacle))
			attack_blocking_obstacle(climbable_obstacle)
			return TRUE
		if(attempt_climb_obstacle(climbable_obstacle))
			return TRUE

	var/atom/blocking_obstacle = get_blocking_obstacle(obstacle_goal)
	if(blocking_obstacle)
		attack_blocking_obstacle(blocking_obstacle)
		return TRUE

	return navigate_around(obstacle_goal)

/**
 * Last-resort one-tile sidestep once nothing above found anything worth forcing/climbing.
 * Mirrors xeno's navigate_around() exactly, including the
 * same anti-oscillation fix: a bare re-aimed sidestep every tick reads as "walking back and
 * forth" against anything wider than a single tile, so this commits to the winning side for
 * ZOMBIE_AI_FALLBACK_WALK_DURATION instead of re-evaluating fresh every call.
 */
/datum/zombie_ai_controller/proc/navigate_around(atom/goal)
	if(!pilot || !goal)
		return FALSE

	if(fallback_walk_dir && world.time < fallback_walk_until)
		if(ai_step(fallback_walk_dir))
			return TRUE
		fallback_walk_dir = null

	var/target_dir = get_dir(pilot, goal)
	var/list/side_dirs = list(turn(target_dir, 90), turn(target_dir, -90))
	if(last_sidestep_dir && (last_sidestep_dir in side_dirs))
		side_dirs = list(last_sidestep_dir) + (side_dirs - last_sidestep_dir)

	for(var/side_dir in side_dirs)
		if(ai_step(side_dir))
			last_sidestep_dir = side_dir
			fallback_walk_dir = side_dir
			fallback_walk_until = world.time + ZOMBIE_AI_FALLBACK_WALK_DURATION
			return TRUE
	last_sidestep_dir = null
	fallback_walk_dir = null
	return FALSE

/**
 * Real, whole-route answer to "is there actually a way around this specific tile" - reuses the
 * same pure path-computing procs advance_along_path() already calls (compute_path_global() first,
 * the bounded local solver as fallback) rather than a local 1-tile peek, which can report a "free"
 * tile beside an obstacle that's really just another edge of the same wall/platform and never
 * actually leads anywhere. Side-effect-free: only inspects a freshly-computed route, never
 * consumes/mutates path_queue or moves the pilot. Mirrors xeno's has_real_detour() exactly.
 */
/datum/zombie_ai_controller/proc/has_real_detour(atom/goal, turf/blocked_turf)
	if(!pilot || !goal || !blocked_turf)
		return FALSE
	var/turf/goal_turf = get_turf(goal)
	if(!goal_turf)
		return FALSE
	var/list/route = compute_path_global(goal_turf)
	if(!route)
		route = compute_path(goal_turf)
	if(!route || !length(route))
		return FALSE
	return !(blocked_turf in route)

/// Same cardinal-decomposition cardinal_step_towards() uses internally, exposed here so get_blocking_obstacle() checks the same candidate tiles a step attempt already tried. Mirrors xeno's get_cardinal_candidates().
/datum/zombie_ai_controller/proc/get_cardinal_candidates(atom/goal)
	if(!pilot || !goal)
		return null
	var/dir_to_goal = get_dir(pilot, goal)
	if(!dir_to_goal)
		return null
	if(!(dir_to_goal & (dir_to_goal - 1))) // Single bit set - already a pure cardinal, nothing to decompose.
		return list(dir_to_goal, null)

	var/turf/pilot_turf = get_turf(pilot)
	var/turf/goal_turf = get_turf(goal)
	if(!pilot_turf || !goal_turf)
		return null
	var/dx = goal_turf.x - pilot_turf.x
	var/dy = goal_turf.y - pilot_turf.y
	var/primary_dir = (abs(dx) >= abs(dy)) ? (dx > 0 ? EAST : WEST) : (dy > 0 ? NORTH : SOUTH)
	var/secondary_dir = (primary_dir == EAST || primary_dir == WEST) ? (dy > 0 ? NORTH : SOUTH) : (dx > 0 ? EAST : WEST)
	return list(primary_dir, secondary_dir)

/**
 * Whether the PRIMARY cardinal direction toward goal (get_cardinal_candidates()[1] - the one
 * cardinal_step_towards() tries first) is blocked by a real, dense structure or wall - see
 * travel_to()'s doc comment on why this needs checking before cardinal_step_towards() runs, not
 * after. Only checks for a genuine obstacle (a dense /obj/structure, or a closed wall turf) - a
 * mob standing in the way is deliberately NOT treated as blocking here.
 */
/datum/zombie_ai_controller/proc/primary_direction_blocked(atom/goal)
	if(!pilot || !goal)
		return FALSE
	var/list/candidates = get_cardinal_candidates(goal)
	if(!candidates)
		return FALSE
	var/turf/next_turf = get_step(pilot, candidates[1])
	if(!next_turf)
		return FALSE
	if(next_turf.density)
		return TRUE
	for(var/obj/structure/blocker in next_turf)
		if(blocker.density)
			return TRUE
	return FALSE

/**
 * Defensive double-check on top of plain Adjacent(): "click-adjacent" (touch range for a real
 * player's click, which click.dm then redirects onto whatever border object is actually in the
 * way) is not the same guarantee this controller needs, since process_attack() swings
 * zombie_claws straight at current_target with no such redirection. Rather than trust exactly how
 * Adjacent()'s border-crossing math resolves for every window/door placement, this explicitly
 * refuses "melee ready" whenever a real blocking structure sits on either the target's tile or
 * the pilot's own tile - a zombie standing at an unbroken window should always go through
 * handle_travel_obstacles() and attack the window, never skip straight to attacking whoever's on
 * the other side of it. get_blocking_obstacle() alone only scans the tile being stepped INTO
 * (target's side); a border structure can just as easily be registered on the PILOT's own tile
 * instead, so that's checked directly here too.
 */
/datum/zombie_ai_controller/proc/is_melee_reachable(atom/target)
	if(!pilot || !target || !pilot.Adjacent(target))
		return FALSE
	if(get_blocking_obstacle(target))
		return FALSE
	var/turf/pilot_turf = get_turf(pilot)
	if(pilot_turf)
		for(var/obj/structure/blocker in pilot_turf)
			if(blocker.density && !blocker.climbable && !blocker.unslashable)
				return FALSE
	return TRUE

/**
 * A door directly ahead is preferred over any other blocking structure
 * (windows/crates/etc, the "other" bucket) - it's the intended route through,
 * not incidental cover. Stays committed to whatever's already mid-smash for a
 * while (ZOMBIE_AI_OBSTACLE_COMMIT_DURATION) rather than re-picking fresh
 * every tick and abandoning partial progress. Resin/mineral doors are
 * deliberately out of scope - hive-specific, not something a zombie needs.
 */
/datum/zombie_ai_controller/proc/get_blocking_obstacle(atom/goal)
	if(!pilot || !goal)
		return null

	var/list/candidates = get_cardinal_candidates(goal)
	if(!candidates)
		return null

	// Stays committed to whatever's already mid-smash for a while, but ONLY while it's still
	// sitting on one of the cardinal tiles toward THIS goal - otherwise this was goal-blind:
	// is_melee_reachable() calls this with the current living target as goal, and a
	// window/barricade the zombie legitimately committed to smashing earlier (while it really
	// was in the way of something) kept getting returned here forever after, as long as the
	// pilot stayed adjacent and it was still standing - even once standing right next to a fully
	// open path to its actual target. That permanently vetoed ever attacking the real target
	// (reported live as attacking an unrelated obstacle instead of a clearly-reachable human).
	if(committed_obstacle && world.time < committed_obstacle_until && is_obstacle_still_blocking(committed_obstacle))
		var/turf/committed_turf = get_turf(committed_obstacle)
		if(committed_turf == get_step(pilot, candidates[1]) || (candidates[2] && committed_turf == get_step(pilot, candidates[2])))
			return committed_obstacle
	committed_obstacle = null

	var/obj/structure/door_candidate
	var/door_candidate_dir
	var/obj/structure/other_candidate
	var/other_candidate_dir

	for(var/candidate_dir in candidates)
		if(!candidate_dir)
			continue
		var/turf/next_turf = get_step(pilot, candidate_dir)
		if(!next_turf)
			continue
		for(var/obj/structure/blocking_obstacle in next_turf)
			if(!blocking_obstacle.density || blocking_obstacle.unslashable || blocking_obstacle.climbable)
				continue
			if(istype(blocking_obstacle, /obj/structure/machinery/door))
				var/obj/structure/machinery/door/door_obstacle = blocking_obstacle
				if(!door_candidate && !door_obstacle.heavy)
					door_candidate = door_obstacle
					door_candidate_dir = candidate_dir
			else if(!other_candidate)
				other_candidate = blocking_obstacle
				other_candidate_dir = candidate_dir

	// A door found only via the secondary (sideways) direction no longer preempts a candidate
	// sitting directly on the path to goal (primary direction) - type priority (door > other,
	// below) is only meant to break a tie between candidates stacked on the same tile.
	var/primary_dir = candidates[1]
	if(door_candidate && door_candidate_dir != primary_dir && other_candidate && other_candidate_dir == primary_dir)
		door_candidate = null

	if(door_candidate)
		var/obj/structure/machinery/door/airlock/locked_airlock = door_candidate
		var/skip_locked_door = istype(locked_airlock) && locked_airlock.locked && has_real_detour(goal, get_turf(door_candidate))
		if(!skip_locked_door)
			return commit_to_obstacle(door_candidate)
	if(other_candidate)
		return commit_to_obstacle(other_candidate)
	return null

/// Sets/refreshes the obstacle commitment and returns it, so every "found a new obstacle" branch above stays a one-liner.
/datum/zombie_ai_controller/proc/commit_to_obstacle(atom/obstacle)
	committed_obstacle = obstacle
	committed_obstacle_until = world.time + ZOMBIE_AI_OBSTACLE_COMMIT_DURATION
	return obstacle

/// Whether a previously-committed obstacle is still actually there, still blocking, and still reachable - a destroyed structure is QDELETED or no longer dense, and a pilot forced elsewhere is no longer adjacent to it.
/datum/zombie_ai_controller/proc/is_obstacle_still_blocking(atom/obstacle)
	if(!pilot || QDELETED(obstacle) || !pilot.Adjacent(obstacle))
		return FALSE
	if(istype(obstacle, /obj/structure))
		var/atom/movable/movable_obstacle = obstacle
		return movable_obstacle.density
	return FALSE

/**
 * A climbable structure (table, barricade) directly ahead on the way to goal. Checks BOTH
 * cardinal candidate tiles cardinal_step_towards() would actually try (get_cardinal_candidates()
 * - primary axis first, then secondary), not just the raw get_dir(pilot, goal) tile - that raw
 * direction is diagonal any time goal isn't exactly aligned on a row/column with the pilot (the
 * common case, not an edge case), which pointed this at an empty diagonal tile while a real
 * table sat one tile over on the cardinal the zombie was actually trying to step into.
 */
/datum/zombie_ai_controller/proc/get_climbable_obstacle(atom/goal)
	if(!pilot || !goal)
		return null
	var/list/candidates = get_cardinal_candidates(goal)
	if(!candidates)
		return null
	var/primary_dir = candidates[1]
	var/primary_blocked_by_other = FALSE
	for(var/candidate_dir in candidates)
		if(!candidate_dir)
			continue
		var/turf/next_turf = get_step(pilot, candidate_dir)
		if(!next_turf)
			continue
		var/obj/structure/found_climbable
		for(var/obj/structure/S in next_turf)
			if(!S.density)
				continue
			if(S.climbable)
				found_climbable = S
			else if(candidate_dir == primary_dir)
				primary_blocked_by_other = TRUE
		if(!found_climbable)
			continue
		if(candidate_dir == primary_dir)
			return found_climbable
		// A climbable structure found only on the SECONDARY (sideways) tile must not preempt a
		// genuine non-climbable blocking obstacle sitting on the PRIMARY tile - that's the one
		// actually on the direct line to goal and needs attacking (get_blocking_obstacle()
		// below), not a sideways vault that goes nowhere toward goal.
		if(!primary_blocked_by_other)
			return found_climbable
	return null

/// Vaults over a climbable obstacle the same way a real player's do_climb() interaction would. do_climb()'s own do_after() windup blocks this controller's tick() the same safe way a door-pry or table-break do_after() does.
/datum/zombie_ai_controller/proc/attempt_climb_obstacle(obj/structure/obstacle)
	if(!pilot || !obstacle)
		return FALSE
	return obstacle.do_climb(pilot)

/**
 * Climbing is the default for everything climbable - it's near-instant and
 * furniture was never meant to be destroyed. A barricade is the one
 * exception: "ruthless" means it never bothers vaulting one when it can just
 * tear it down, so nothing behind it stays defensible against an AI zombie.
 * Unlike xeno's version there's no wall_smash/ally-count gate to weigh - a
 * zombie has no strength tiers and no allies to coordinate with, so this is
 * unconditional for any non-unslashable barricade.
 */
/datum/zombie_ai_controller/proc/should_smash_instead_of_climb(obj/structure/obstacle)
	if(!pilot || !obstacle)
		return FALSE
	return istype(obstacle, /obj/structure/barricade) && !obstacle.unslashable

/// Paces obstacle-smashing to next_move, same as process_attack() and for the same reason - attack_zombie() is called directly, bypassing click.dm's dispatch entirely.
/datum/zombie_ai_controller/proc/attack_blocking_obstacle(atom/target_obstacle)
	if(!pilot || !target_obstacle)
		return
	if(world.time <= pilot.next_move)
		return
	pilot.setDir(get_dir(pilot, target_obstacle))
	target_obstacle.attack_zombie(pilot)
	if(pilot) // attack_zombie() can retaliate/kill the pilot (e.g. an electrified/explosive obstacle) - don't write to it if it just died.
		pilot.next_move = world.time + ZOMBIE_AI_MELEE_ATTACK_DELAY
		if(committed_obstacle == target_obstacle)
			committed_obstacle_until = world.time + ZOMBIE_AI_OBSTACLE_COMMIT_DURATION

/**
 * Consumes one step of a cached native-pathfinder route toward goal, (re)computing it first if
 * needed. Returns FALSE - meaning "fall through to handle_travel_obstacles() for this tick" - if
 * the native library isn't available, no path exists, the goal is out of local-grid range, or
 * the planned next tile turned out to be blocked when actually tried (something wandered into
 * the way, a door shut) - in that last case the stale plan is dropped and a fresh one gets
 * computed next tick. Ported from xeno's advance_along_path() (xeno_ai_movement.dm) with the
 * dig-escalation branch removed - see zombie_ai.dm's pathfinding-defines comment for why.
 *
 * The cached plan is reused as long as the goal hasn't moved far from where it was computed for
 * (ZOMBIE_AI_PATH_GOAL_REPLAN_TOLERANCE), not just whenever it isn't the exact same tile - a
 * live target shifts by a tile almost every heartbeat, and replanning from scratch every tick
 * near a corner would flip the solver's tie-breaking back and forth.
 */
/datum/zombie_ai_controller/proc/advance_along_path(atom/goal)
	if(!pilot || !goal)
		return FALSE

	var/turf/goal_turf = get_turf(goal)
	if(!goal_turf)
		return FALSE

	var/goal_unchanged = path_goal && get_dist(path_goal, goal_turf) <= ZOMBIE_AI_PATH_GOAL_REPLAN_TOLERANCE
	// A live route toward a goal that merely drifted keeps being consumed while inside the
	// replan throttle window - without this, a moving target more than the tolerance away from
	// path_goal forces a whole-map native solve every single tick, per mob.
	if(length(path_queue) && !goal_unchanged && world.time < next_replan_time && path_goal && get_dist(path_goal, goal_turf) <= ZOMBIE_AI_PATH_GOAL_REPLAN_TOLERANCE * 2)
		goal_unchanged = TRUE
	if(!path_queue || !length(path_queue) || !goal_unchanged)
		// A prior failure against essentially the same goal waits out a short cooldown before
		// trying again, instead of re-running the full grid-build + native solver call every
		// single tick indefinitely.
		if(path_failed && goal_unchanged && world.time < next_path_attempt)
			return FALSE
		// The persistent full-map grid (SSxeno_pathfinding) is tried first when available - both
		// cheaper per replan and sees the whole z-level. The native global grid has no concept of
		// fire/toxic water at all - reject a global route that crosses either and fall through to
		// the fire-aware local solver instead, same as a genuine solve failure would.
		path_queue = compute_path_global(goal_turf)
		if(path_queue && (path_has_fire(path_queue) || path_has_toxic_water(path_queue)))
			path_queue = null
		if(!path_queue)
			path_queue = compute_path(goal_turf)
		path_goal = goal_turf
		if(!path_queue || !length(path_queue))
			path_failed = TRUE
			next_path_attempt = world.time + ZOMBIE_AI_PATH_RETRY_COOLDOWN
			return FALSE
		path_failed = FALSE
		next_replan_time = world.time + ZOMBIE_AI_PATH_REPLAN_MIN_INTERVAL

	var/turf/pilot_turf = get_turf(pilot)
	if(pilot_turf == path_queue[1])
		path_queue.Cut(1, 2)
		if(!length(path_queue))
			return FALSE

	var/turf/next_step = path_queue[1]
	if(!cardinal_step_towards(next_step))
		route_block_turf = next_step // handle_travel_obstacles() picks this up next, in place of the far goal.
		path_queue = null // Plan is stale - let this tick fall back to greedy/obstacle handling, replan next tick.
		return FALSE

	if(get_turf(pilot) == next_step)
		path_queue.Cut(1, 2)
	return TRUE

/**
 * Full-map route against SSxeno_pathfinding's persistent native grid - the primary planner
 * whenever that subsystem loaded successfully. Reused directly, not forked: the grid encodes
 * generic map state (turf blockage/door/window cost), nothing xeno-specific, and zombie
 * controllers are simply a second consumer of the same persistent grid xeno AI already
 * maintains. Returns null (fall through to the bounded local solver, then greedy) when
 * unavailable or no route exists.
 */
/datum/zombie_ai_controller/proc/compute_path_global(turf/goal_turf)
	if(!SSxeno_pathfinding?.available)
		return null
	var/turf/pilot_turf = get_turf(pilot)
	if(!pilot_turf || !goal_turf || pilot_turf.z != goal_turf.z)
		return null

	var/result = rust_xeno_pathfind_route("[pilot_turf.z],[pilot_turf.x],[pilot_turf.y],[goal_turf.x],[goal_turf.y]")
	if(!result || !length(result))
		return null

	var/list/waypoints = list()
	for(var/pair in splittext(result, ";"))
		var/list/point = splittext(pair, ",")
		if(length(point) != 2)
			continue
		var/turf/waypoint = locate(text2num(point[1]), text2num(point[2]), pilot_turf.z)
		if(waypoint)
			waypoints += waypoint

	if(length(waypoints) && waypoints[1] == pilot_turf)
		waypoints.Cut(1, 2)
	if(!length(waypoints))
		return null
	return waypoints

/// Whether any turf in a computed route is currently on fire - the global grid's own result needs this checked externally since the native solver has no concept of fire.
/datum/zombie_ai_controller/proc/path_has_fire(list/turf/queue)
	for(var/turf/step in queue)
		if(locate(/obj/flamer_fire) in step)
			return TRUE
	return FALSE

/// Same idea as path_has_fire() above, for Desert Dam's toxic water - checks the live `toxic` var since it's a dynamically toggleable hazard, not mere presence of the blocker object.
/datum/zombie_ai_controller/proc/path_has_toxic_water(list/turf/queue)
	for(var/turf/step in queue)
		for(var/obj/effect/blocker/toxic_water/hazard in step)
			if(hazard.toxic)
				return TRUE
	return FALSE

/**
 * Builds a bounded local grid around the pilot and goal (only turf density counts as "blocked" -
 * doors/windows/tables are left for the existing per-step obstacle-forcing and climb handling,
 * not modeled in the grid) and asks the native solver for a route. Returns null (meaning "no
 * plan, use the old behavior") if the library isn't present, the hop is too large for local grid
 * pathing, or no path exists. Fallback for hosts whose native library predates the persistent
 * full-map grid (see compute_path_global()).
 *
 * Grows the search margin around the direct pilot-goal bounding box as far as the cell budget
 * (ZOMBIE_AI_PATHFIND_MAX_CELLS) allows, capped at ZOMBIE_AI_PATHFIND_MAX_MARGIN, rather than a
 * small flat margin - a real door/entrance is rarely within just a couple tiles of the straight
 * line between two points in a room-and-corridor layout. Unlike xeno's compute_path(), there's
 * no escalation tier that widens further after repeated failures - see zombie_ai.dm's
 * pathfinding-defines comment for why that doesn't apply here.
 */
/datum/zombie_ai_controller/proc/compute_path(turf/goal_turf)
	var/turf/pilot_turf = get_turf(pilot)
	if(!pilot_turf || !goal_turf || pilot_turf.z != goal_turf.z)
		return null

	var/base_width = abs(pilot_turf.x - goal_turf.x) + 1
	var/base_height = abs(pilot_turf.y - goal_turf.y) + 1
	var/budget = ZOMBIE_AI_PATHFIND_MAX_CELLS
	var/margin = ZOMBIE_AI_PATHFIND_MIN_MARGIN
	while(margin < ZOMBIE_AI_PATHFIND_MAX_MARGIN && (base_width + 2 * (margin + 1)) * (base_height + 2 * (margin + 1)) <= budget)
		margin++

	var/min_x = max(min(pilot_turf.x, goal_turf.x) - margin, 1)
	var/min_y = max(min(pilot_turf.y, goal_turf.y) - margin, 1)
	var/max_x = min(max(pilot_turf.x, goal_turf.x) + margin, world.maxx)
	var/max_y = min(max(pilot_turf.y, goal_turf.y) + margin, world.maxy)

	var/width = max_x - min_x + 1
	var/height = max_y - min_y + 1
	if(width <= 0 || height <= 0 || width * height > budget)
		return null

	var/list/blocked = list()
	for(var/y in min_y to max_y)
		for(var/x in min_x to max_x)
			var/turf/T = locate(x, y, pilot_turf.z)
			var/tile_blocked = (T && T.density)
			// A dense, unslashable, non-climbable, non-border structure (blast doors/shutters)
			// is a real hard block, not just an "obstacle" - get_blocking_obstacle() never forces
			// one open, so a route planned straight at one leaves the AI standing there with
			// nothing left to do but blindly sidestep, ignoring a real detour a few tiles over.
			if(!tile_blocked && T)
				for(var/obj/structure/blocker in T)
					if(blocker.density && blocker.unslashable && !blocker.climbable && !(blocker.flags_atom & ON_BORDER))
						tile_blocked = TRUE
						break
			// Fire/toxic water are walkable, not walls - treated as blocked for routing purposes
			// so the solver prefers a route around them. Never blocks the pilot's own tile or the
			// goal's tile - if either end is already hazardous, the pilot still needs a route in/out.
			if(!tile_blocked && T && T != pilot_turf && T != goal_turf && (locate(/obj/flamer_fire) in T))
				tile_blocked = TRUE
			if(!tile_blocked && T && T != pilot_turf && T != goal_turf)
				var/obj/effect/blocker/toxic_water/hazard = locate() in T
				if(hazard?.toxic)
					tile_blocked = TRUE
			blocked += tile_blocked ? "1" : "0"

	var/grid_desc = "[width],[height],[pilot_turf.x - min_x],[pilot_turf.y - min_y],[goal_turf.x - min_x],[goal_turf.y - min_y]"
	var/blocked_map = blocked.Join("")

	var/result = rust_xeno_pathfind(grid_desc, blocked_map)
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
