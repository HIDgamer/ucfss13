/**
 * Movement for xeno_ai_controller. When the native xeno_pathfind library is
 * present (see code/__DEFINES/__xeno_pathfind.dm), routes through a real A*
 * plan over a small local grid via advance_along_path() - this is what fixes
 * zigzagging and lets the AI route around walls properly. When it isn't
 * present (or a planned step fails - a mob wandered into the way, a door
 * closed), falls straight back to the original greedy step_towards() + one
 * tile sidestep. Either way a host with no native library at all behaves
 * exactly as before this was added.
 *
 * "Long pathfinding to go around a building or a wall is not possible, the
 * aliens just walk back and forth unable to find a path if outside and the
 * enemy is inside a big building." advance_along_path()'s real A* only ever
 * solves within a small local grid around pilot/goal (compute_path()'s own
 * margin, capped at XENO_PATHFIND_MAX_CELLS) - a detour around a whole
 * building is routinely far outside that box, so it correctly finds no plan
 * at all, and the greedy fallback below just walks straight at the wall
 * every tick, sidesteps one tile, then walks straight at the wall again -
 * that's the "back and forth." attempt_skirt_obstacle() (checked first, and
 * committed to by navigate_around() below) fixes this not by solving a real
 * long-range path, but by refusing to re-aim at the goal every single tick
 * while blocked: once a side is picked, she keeps walking that direction for
 * several seconds so she actually travels far enough to clear the corner,
 * instead of re-evaluating "which way is the goal" every tick and
 * potentially flip-flopping before ever making real progress.
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

	var/atom/movable/approach_goal = current_target
	if(count_engaged_allies(current_target))
		var/turf/flank_turf = get_flanking_position(current_target)
		if(flank_turf)
			approach_goal = flank_turf

	if(attempt_skirt_obstacle())
		return

	if(advance_along_path(approach_goal))
		blocked_attempts = 0
		skirt_until = 0 // Making real progress toward the goal again - no need to keep committing to a skirt.
		return

	if(cardinal_step_towards(approach_goal))
		blocked_attempts = 0
		skirt_until = 0
		return

	var/obj/structure/climbable_obstacle = get_climbable_obstacle(approach_goal)
	if(climbable_obstacle)
		if(should_smash_instead_of_climb(climbable_obstacle))
			attack_blocking_obstacle(climbable_obstacle)
			blocked_attempts = 0
			return
		if(attempt_climb_obstacle(climbable_obstacle))
			blocked_attempts = 0
			return

	var/atom/blocking_obstacle = get_blocking_obstacle(current_target)
	if(blocking_obstacle)
		attack_blocking_obstacle(blocking_obstacle)
		blocked_attempts = 0
		return

	if(navigate_around())
		blocked_attempts = 0
		return

	blocked_attempts++
	if(blocked_attempts >= get_pathfind_giveup_attempts())
		drop_target(TRUE) // Couldn't force through - go investigate where it was last seen instead of forgetting it outright.

/**
 * Shared continuous-kiting movement decision for every ranged caste
 * (Spitter/Boiler/Sentinel/Queen) - "approach, spit, and die in place" /
 * "spitter and all other ranged variants are really bad and die instantly."
 * The bug was the old binary min/preferred band each of them duplicated:
 * hold completely still anywhere inside the "preferred" distance, only
 * retreat once the target was already almost on top of her
 * (AI_XENO_RANGED_MIN_DISTANCE). A marine walking straight at her crossed
 * that whole multi-tile band completely unopposed - she just stood there
 * spitting - and by the time the emergency-floor retreat finally triggered,
 * one more step already closed it to melee. Now retreats the moment the
 * target is closer than preferred (not just inside a tight emergency
 * floor), holds only at/near the ideal ring, and advances only when
 * meaningfully farther - real continuous kiting instead of a static hold.
 * Prefers falling back toward a nearby defensible corner/wall
 * (find_defensible_turf()) over open ground when one's actually closer.
 * Sets ai_state directly (ATTACKING once holding in band) so callers are
 * just this one call from their own process_movement() override.
 */
/datum/xeno_ai_controller/proc/maintain_kiting_distance(atom/target, preferred_distance)
	if(!pilot || !target)
		return
	var/dist = get_dist(pilot, target)

	if(dist < preferred_distance)
		var/turf/defensible = find_defensible_turf()
		if(defensible && get_dist(pilot, defensible) > 0 && cardinal_step_towards(defensible))
			return
		var/away_dir = get_dir(target, pilot)
		if(!ai_step(away_dir))
			navigate_around(target)
		return

	if(dist <= preferred_distance + 1)
		ai_state = AI_STATE_ATTACKING
		blocked_attempts = 0
		path_queue = null
		return

	if(advance_along_path(target))
		blocked_attempts = 0
		return
	if(cardinal_step_towards(target))
		blocked_attempts = 0
		return

	var/obj/structure/climbable_obstacle = get_climbable_obstacle(target)
	if(climbable_obstacle)
		if(should_smash_instead_of_climb(climbable_obstacle))
			attack_blocking_obstacle(climbable_obstacle)
			blocked_attempts = 0
			return
		if(attempt_climb_obstacle(climbable_obstacle))
			blocked_attempts = 0
			return

	var/atom/blocking_obstacle = get_blocking_obstacle(target)
	if(blocking_obstacle)
		attack_blocking_obstacle(blocking_obstacle)
		blocked_attempts = 0
		return

	if(navigate_around(target))
		blocked_attempts = 0
		return

	blocked_attempts++
	if(blocked_attempts >= 2)
		drop_target(TRUE)

/**
 * "I want better pathfinding as it's still too much, varied by the caste's
 * size/tier T1 vs T2 vs T3." Three knobs scaled by pilot.tier instead of one
 * flat setting for every caste regardless of size: a disposable, numerous
 * Tier 1 gives up on a blocked target sooner and gets a smaller local
 * pathfinding grid (not worth the compute or the exposure time for a caste
 * that's cheap to lose), while a Tier 2/3 - fewer of them, each one a much
 * bigger investment - gets a wider grid budget and commits longer to a
 * skirt, worth spending more to actually solve a real detour instead of
 * falling back to the greedy walk early.
 */
/datum/xeno_ai_controller/proc/get_pathfind_cell_budget()
	if(!pilot)
		return XENO_PATHFIND_MAX_CELLS
	if(pilot.tier >= 3)
		return XENO_PATHFIND_MAX_CELLS * 2
	if(pilot.tier == 2)
		return round(XENO_PATHFIND_MAX_CELLS * 1.5)
	return XENO_PATHFIND_MAX_CELLS

/// See get_pathfind_cell_budget()'s doc comment - same tier scaling applied to how long a committed obstacle-skirt lasts.
/datum/xeno_ai_controller/proc/get_skirt_duration()
	if(!pilot)
		return AI_XENO_SKIRT_DURATION
	if(pilot.tier >= 3)
		return AI_XENO_SKIRT_DURATION * 1.5
	if(pilot.tier == 2)
		return AI_XENO_SKIRT_DURATION * 1.25
	return AI_XENO_SKIRT_DURATION

/// See get_pathfind_cell_budget()'s doc comment - same tier scaling applied to how many consecutive blocked ticks the chase path tolerates before giving up on the target entirely.
/datum/xeno_ai_controller/proc/get_pathfind_giveup_attempts()
	if(!pilot)
		return 2
	if(pilot.tier >= 3)
		return 4
	if(pilot.tier == 2)
		return 3
	return 2

/**
 * Plain turf-density line check between pilot and target, reusing the
 * existing get_line() helper rather than a real raycast library - good
 * enough to tell "clean shot" from "there's a wall in the way" for ranged
 * castes (see ranged.dm's process_attack()) without adding a new dependency.
 * Ignores the two endpoint tiles themselves (the pilot's and target's own
 * turf) since a dense structure the target happens to be standing against
 * shouldn't block a shot at the target on that same tile.
 *
 * physical_path = TRUE also counts climbable obstacles (tables, some
 * fences/barricades) as blocking - "charge/pounce/lunge stuck on terrain...
 * still a problem with tables, fences, barricades." A ranged shot can fly
 * over a table just fine, which is why climbable structures are normally
 * exempted here, but a charge/pounce is a physical dash, not a projectile -
 * it collides with furniture the same way footstep movement climbing over
 * it doesn't happen mid-dash. Callers doing a physical gap-closer (crusher/
 * ravager charge, runner/lurker pounce) pass this TRUE; ranged spit/shot
 * callers leave it FALSE.
 */
/datum/xeno_ai_controller/proc/has_line_of_sight(atom/target, physical_path = FALSE)
	if(!pilot || !target)
		return FALSE
	var/turf/pilot_turf = get_turf(pilot)
	var/turf/target_turf = get_turf(target)
	if(!pilot_turf || !target_turf || pilot_turf.z != target_turf.z)
		return FALSE
	for(var/turf/line_turf in get_line(pilot_turf, target_turf))
		if(line_turf == pilot_turf || line_turf == target_turf)
			continue
		if(line_turf.density)
			return FALSE
		for(var/obj/structure/blocker in line_turf)
			if(blocker.density && (physical_path || !blocker.climbable))
				return FALSE
	return TRUE

/// Same-hive AI xenos already actively approaching/attacking this exact target - see get_flanking_position()/process_movement()'s flanking check.
/datum/xeno_ai_controller/proc/count_engaged_allies(atom/movable/target)
	if(!pilot)
		return 0
	var/count = 0
	for(var/mob/living/carbon/xenomorph/ally as anything in GLOB.ai_xeno_list)
		if(ally == pilot || ally.stat == DEAD || ally.hivenumber != pilot.hivenumber)
			continue
		var/datum/xeno_ai_controller/ally_controller = ally.ai_controller
		if(!ally_controller || ally_controller.current_target != target)
			continue
		if(ally_controller.ai_state != AI_STATE_APPROACHING && ally_controller.ai_state != AI_STATE_ATTACKING)
			continue
		count++
	return count

/**
 * "Flanking logic to flank humans" - once at least one same-hive ally is
 * already closing on/fighting the same target, a fresh approacher heads for
 * an unoccupied side of it instead of the same tile everyone else is
 * beelining for, so a group actually surrounds a marine from different
 * angles rather than stacking into a single-file queue on one side. Returns
 * null (meaning "just approach the target directly, same as before") if
 * every side is already taken or blocked - flanking only matters when there's
 * actually a free side left to take.
 */
/datum/xeno_ai_controller/proc/get_flanking_position(atom/movable/target)
	var/turf/target_turf = get_turf(target)
	if(!target_turf)
		return null

	var/list/free_sides = list()
	var/list/taken_sides = list()
	for(var/dir_option in list(NORTH, SOUTH, EAST, WEST))
		var/turf/side_turf = get_step(target_turf, dir_option)
		if(!side_turf || side_turf.density)
			continue
		var/occupied = FALSE
		for(var/mob/living/carbon/xenomorph/ally in side_turf)
			if(ally != pilot && ally.hivenumber == pilot.hivenumber && ally.stat != DEAD)
				occupied = TRUE
				break
		if(occupied)
			taken_sides += side_turf
		else
			free_sides += side_turf

	if(!length(free_sides))
		return null

	// Prefer whichever free side sits farthest from the already-taken ones -
	// the opposite/most different angle, not just the nearest empty tile
	// (which is often right next to a clustered ally anyway).
	if(!length(taken_sides))
		return free_sides[1]

	var/turf/best
	var/best_score = -1
	for(var/turf/candidate in free_sides)
		var/score = 0
		for(var/turf/taken in taken_sides)
			score += get_dist(candidate, taken)
		if(score > best_score)
			best_score = score
			best = candidate
	return best

/**
 * Consumes one step of a cached native-pathfinder route toward goal,
 * (re)computing it first if needed. Returns FALSE - meaning "fall through to
 * the old greedy behavior for this tick" - if the native library isn't
 * available, no path exists, the goal is out of local-grid range, or the
 * planned next tile turned out to be blocked when we actually tried to move
 * (something wandered into the way, a door shut) - in that last case the
 * stale plan is dropped and a fresh one gets computed next tick.
 *
 * The cached plan is reused as long as the goal hasn't moved far from where
 * it was computed for (PATH_GOAL_REPLAN_TOLERANCE), not just whenever it
 * isn't in the exact same tile - a live target shifts by a tile almost every
 * heartbeat, and replanning from scratch every single tick near a corner let
 * minor start/goal differences flip the solver's tie-breaking back and
 * forth, which is what the reported "walks in a triangle near walls" turned
 * out to be: a fresh plan every tick, not a bad plan.
 */
/datum/xeno_ai_controller/proc/advance_along_path(atom/goal)
	if(!pilot || !goal)
		return FALSE

	var/turf/goal_turf = get_turf(goal)
	if(!goal_turf)
		return FALSE

	if(!path_queue || !length(path_queue) || !path_goal || get_dist(path_goal, goal_turf) > PATH_GOAL_REPLAN_TOLERANCE)
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
	if(!cardinal_step_towards(next_step))
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
	if(width <= 0 || height <= 0 || width * height > get_pathfind_cell_budget())
		return null

	var/list/blocked = list()
	for(var/y in min_y to max_y)
		for(var/x in min_x to max_x)
			var/turf/T = locate(x, y, pilot_turf.z)
			var/tile_blocked = (T && T.density)
			// Fire is walkable, not a wall - so it isn't blocked outright, but
			// it's treated as blocked for routing purposes so the solver
			// prefers a route around it. Never blocks the pilot's own tile or
			// the goal's tile - if either end is already on fire, the pilot
			// still needs a route in/out of it.
			if(!tile_blocked && T && T != pilot_turf && T != goal_turf && (locate(/obj/flamer_fire) in T))
				tile_blocked = TRUE
			blocked += tile_blocked ? "1" : "0"

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

/**
 * Single-tile sidestep around one obstacle. Not real pathfinding - if this
 * fails too the caller gives up on the target. Prefers whichever side
 * worked last time before trying the other - target_dir shifts by a notch
 * almost every tick a mob is near a corner, and always re-deriving "left or
 * right" fresh from it made the pilot flip-flop between both sides of the
 * corner instead of committing to going around one way, which is what the
 * reported "walks in a triangle near walls" turned out to be for hosts
 * without the native pathfinder available (or wherever it falls through to
 * this greedy tail).
 */
/**
 * Single choke point every AI-driven step() call in this whole controller
 * goes through - "AI pathfinding is now too fast, need to nerf it so they
 * move exactly at the same speed a normal player controlled mob would."
 * Raw BYOND step() has no pacing of its own; a real player's movement rate
 * is throttled by /client/Move()'s own next_movement var (mob_movement.dm),
 * which only exists on a client and never applies to a clientless AI mob
 * calling step() directly - nothing was gating AI movement speed at all.
 * Recomputes and enforces the pilot's own movement_delay() (the same speed
 * a player of this caste would actually move at) before allowing another
 * step, independent of how often tick() itself runs.
 */
/datum/xeno_ai_controller/proc/ai_step(direction)
	if(!pilot || world.time < next_step_time)
		return FALSE
	. = step(pilot, direction)
	if(.)
		next_step_time = world.time + pilot.movement_delay()

/**
 * goal defaults to current_target so every existing chase-path call site is
 * unaffected - passed explicitly by return_to_anchor() (xeno_ai_controller.dm),
 * which has no current_target at all (drop_target() cleared it on entering
 * AI_STATE_RETURNING) and would otherwise have this bail out immediately
 * every time it's called while fleeing.
 */
/datum/xeno_ai_controller/proc/navigate_around(atom/goal = current_target)
	if(!pilot || !goal)
		return FALSE

	var/target_dir = get_dir(pilot, goal)
	var/list/side_dirs = list(turn(target_dir, 90), turn(target_dir, -90))
	if(last_sidestep_dir && (last_sidestep_dir in side_dirs))
		side_dirs = list(last_sidestep_dir) + (side_dirs - last_sidestep_dir)

	for(var/side_dir in side_dirs)
		if(ai_step(side_dir))
			last_sidestep_dir = side_dir
			// Commit to this direction for a while instead of only taking
			// one step and re-aiming at the goal next tick - see
			// attempt_skirt_obstacle()/process_movement()'s doc comment for
			// why a single sidestep isn't enough to actually clear a large
			// obstacle like a building.
			skirt_dir = side_dir
			skirt_until = world.time + get_skirt_duration()
			return TRUE
	last_sidestep_dir = null
	return FALSE

/**
 * "They should also consider corners and walls as defensive positions" -
 * a nearby turf with at least AI_XENO_DEFENSIBLE_MIN_DENSE_SIDES
 * cardinally-adjacent dense tiles (a wall, a corner, tucked against a
 * structure), meaning fewer directions something can actually approach it
 * from. Used by a fleeing/kiting xeno as a nearer, defensible fallback
 * instead of always crossing open ground back to anchor_turf. Returns null
 * if nothing suitable exists within radius - callers just fall back to
 * their normal destination.
 */
/datum/xeno_ai_controller/proc/find_defensible_turf(radius = AI_XENO_DEFENSIBLE_SEARCH_RADIUS)
	if(!pilot)
		return null
	var/turf/pilot_turf = get_turf(pilot)
	if(!pilot_turf)
		return null

	var/turf/best
	var/best_dist = INFINITY
	for(var/turf/candidate in range(radius, pilot_turf))
		if(candidate.density)
			continue
		var/dense_sides = 0
		for(var/dir_option in list(NORTH, SOUTH, EAST, WEST))
			var/turf/neighbor = get_step(candidate, dir_option)
			if(!neighbor || neighbor.density)
				dense_sides++
				continue
			for(var/obj/structure/blocker in neighbor)
				if(blocker.density)
					dense_sides++
					break
		if(dense_sides < AI_XENO_DEFENSIBLE_MIN_DENSE_SIDES)
			continue
		var/dist = get_dist(pilot_turf, candidate)
		if(dist < best_dist)
			best_dist = dist
			best = candidate
	return best

/**
 * Continues an already-committed skirt (see navigate_around() above) for as
 * long as skirt_until hasn't lapsed, instead of re-deriving "which way is
 * the goal" fresh every tick while stuck. Returns FALSE (nothing to do,
 * caller falls through to the normal approach/obstacle chain) once there's
 * no active skirt, it's expired, or the committed direction itself becomes
 * blocked (a corner of the obstacle, or something wandered into the way) -
 * in the last case the commitment ends immediately rather than standing
 * there retrying the same blocked direction until the timer runs out.
 */
/datum/xeno_ai_controller/proc/attempt_skirt_obstacle()
	if(!pilot || !skirt_dir || world.time >= skirt_until)
		skirt_dir = null
		skirt_until = 0
		return FALSE
	if(ai_step(skirt_dir))
		blocked_attempts = 0
		return TRUE
	skirt_dir = null
	skirt_until = 0
	return FALSE

/**
 * Cardinal-only replacement for BYOND's step_towards() - this AI never
 * moves diagonally by design (the native pathfinder's own DIRECTIONS list
 * is cardinal-only), but step_towards() doesn't know that and will happily
 * cut a diagonal corner whenever the goal is both north/south AND east/west
 * of the pilot. Every direct chase/return/search step in this AI goes
 * through here instead of calling step_towards() itself, so a diagonal goal
 * always resolves into exactly one cardinal step - along whichever axis has
 * the larger remaining distance first, falling back to the other axis if
 * that step is blocked (mirrors navigate_around()'s two-option fallback).
 */
/datum/xeno_ai_controller/proc/cardinal_step_towards(atom/goal)
	if(!pilot || !goal)
		return FALSE

	var/dir_to_goal = get_dir(pilot, goal)
	if(!dir_to_goal)
		return FALSE
	if(!(dir_to_goal & (dir_to_goal - 1))) // Single bit set - already a pure cardinal direction, nothing to decompose.
		return ai_step(dir_to_goal)

	var/turf/pilot_turf = get_turf(pilot)
	var/turf/goal_turf = get_turf(goal)
	if(!pilot_turf || !goal_turf)
		return FALSE

	var/dx = goal_turf.x - pilot_turf.x
	var/dy = goal_turf.y - pilot_turf.y
	var/primary_dir = (abs(dx) >= abs(dy)) ? (dx > 0 ? EAST : WEST) : (dy > 0 ? NORTH : SOUTH)
	var/secondary_dir = (primary_dir == EAST || primary_dir == WEST) ? (dy > 0 ? NORTH : SOUTH) : (dx > 0 ? EAST : WEST)

	if(ai_step(primary_dir))
		return TRUE
	return ai_step(secondary_dir)

/**
 * "Pathfinding is very messed up when it comes to none blocking, blocking
 * tiles like tables, vehicles, and fences" - a climbable structure (table,
 * some fences/crates) directly ahead of a raw step() from ordinary floor is
 * NOT actually passable for free the way an earlier version of this comment
 * assumed: tables_racks.dm's own BlockedPassDirs() only waives the block
 * when the mover is already standing on some other climbable structure
 * (hopping furniture to furniture), not from plain ground. A real player
 * instead climbs over it directly (do_climb(), a MouseDrop/verb
 * interaction) - see get_climbable_obstacle()/attempt_climb_obstacle()
 * below for the AI equivalent, checked before this proc in
 * process_movement(). This proc is left for what genuinely does need
 * force: locked airlocks, windows, girders, and walls a strong-enough
 * caste can actually melt through - xenos can't badge through
 * access-locked doors, can't walk through glass, and can't walk through
 * walls unless their claws are strong enough, so they attack instead, same
 * as a player would.
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
	// /obj/vehicle is a sibling of /obj/structure, not a subtype - the loop
	// above never matches one, so a parked vehicle directly in the way was
	// invisible to this whole obstacle-forcing chain regardless of caste,
	// same class of gap as the wall check below used to be.
	for(var/obj/vehicle/blocking_vehicle in next_turf)
		if(blocking_vehicle.density)
			return blocking_vehicle
	// "King/Queen/most T3 can smash open walls, and yet they get stuck on
	// walls instead" - only obj obstacles were ever considered breakable; a
	// solid wall turf directly in the way was never in scope at all, even
	// for a caste with the actual claw strength to melt through it. Gated
	// purely on claw_type vs the wall's own claws_minimum - the exact same
	// check walls.dm's attack_alien() itself makes - NOT mob_size: an
	// earlier version of this check required mob_size >= MOB_SIZE_BIG, which
	// sounded right but is actually wrong - Queen and King never set
	// mob_size to MOB_SIZE_BIG at all (only Crusher/Ravager/Praetorian/etc.
	// do; mob_size here is a push-resistance stat, not a "can act big"
	// flag), so that check silently excluded exactly the two castes this
	// was written for.
	if(istype(next_turf, /turf/closed/wall))
		var/turf/closed/wall/wall = next_turf
		if(pilot.claw_type >= wall.claws_minimum)
			return wall
	return null

/// A climbable structure (table, some fences/crates) directly ahead on the way to goal - see get_blocking_obstacle()'s doc comment above for why this needs separate handling instead of being treated as freely passable.
/datum/xeno_ai_controller/proc/get_climbable_obstacle(atom/goal)
	if(!pilot || !goal)
		return null
	var/turf/next_turf = get_step(pilot, get_dir(pilot, goal))
	if(!next_turf)
		return null
	for(var/obj/structure/climbable_obstacle in next_turf)
		if(climbable_obstacle.density && climbable_obstacle.climbable)
			return climbable_obstacle
	return null

/// Vaults over a climbable obstacle the same way a real player's do_climb() interaction would, instead of only ever sidestepping around it or standing there unable to proceed. do_climb()'s own do_after() windup blocks this controller's tick() the same safe way Queen's Gut/Burrower's burrow already do.
/datum/xeno_ai_controller/proc/attempt_climb_obstacle(obj/structure/obstacle)
	if(!pilot || !obstacle)
		return FALSE
	return obstacle.do_climb(pilot)

/**
 * "Add a decision where is it better to climb over something or just smash
 * it." Climbing is the default - it's instant (a ~0.2-2s vault, no combat
 * risk) and most climbable furniture (tables, crates) was never meant to be
 * destroyed by a xeno at all. A barricade is the one climbable structure
 * that's also genuinely built to be fought through (real health/maxhealth,
 * its own attack_alien() destruction path) - worth actually smashing down
 * instead of just hopping over it, but only when it pays off: either the
 * pilot already melts real walls (wall_smash - a strong-melee caste tears
 * through it fast) or enough same-hive allies are right behind her that
 * clearing the chokepoint permanently helps the whole push, not just her
 * own one-time crossing.
 */
/datum/xeno_ai_controller/proc/should_smash_instead_of_climb(obj/structure/obstacle)
	if(!pilot || !obstacle)
		return FALSE
	if(!istype(obstacle, /obj/structure/barricade) || obstacle.unslashable)
		return FALSE
	return pilot.wall_smash || count_nearby_hive_allies(3) >= 2

/**
 * "No click delay when smashing stuff, they spam walls until smashed,
 * barricades, windows too" - same root cause as plain melee's own next_move
 * gap (xeno_ai_attack.dm's execute_attack()): attack_alien() never sets
 * next_move itself for a basic hit, only click.dm's do_click() dispatch
 * does, which this AI bypasses by calling attack_alien() directly. This is
 * called fresh every tick process_movement() is still blocked, with nothing
 * previously pacing it at all - unlimited-rate smashing, exactly like the
 * melee spam bug before it was gated the same way.
 */
/datum/xeno_ai_controller/proc/attack_blocking_obstacle(atom/target_obstacle)
	if(!pilot || !target_obstacle)
		return
	if(world.time <= pilot.next_move)
		return
	pilot.setDir(get_dir(pilot, target_obstacle))
	pilot.a_intent = INTENT_HARM
	target_obstacle.attack_alien(pilot)
	if(pilot) // attack_alien() can retaliate/kill the pilot (e.g. an explosive barricade) - don't write to it if it just died.
		pilot.next_move = world.time + XENO_MELEE_ATTACK_DELAY
