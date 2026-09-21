/**
 * NPC decision-making for an AI-piloted zombie. Mirrors xeno_ai_controller's
 * architecture (own coroutine, sleep-based heartbeat, try/catch-wrapped tick())
 * but deliberately much simpler: zombies don't flee, don't coordinate with each
 * other, and have no caste/economy layer - "brainless drones that will do
 * anything to get to their target... ruthless."
 *
 * Phase 1 scope only: straight-line chase/attack, no obstacle handling, no
 * pathfinding, no population-shared target cache. See
 * zombie_ai_movement.dm (Phase 2+) for obstacle forcing/climbing and
 * zombie_ai_lifecycle.dm for attach/detach.
 */
/datum/zombie_ai_controller
	/// The human mob this controller is piloting. Null once detached/destroyed.
	var/mob/living/carbon/human/pilot
	/// Current chase/attack target, if any.
	var/atom/movable/current_target
	/// Home/rally point - where a disengaged zombie walks back to.
	var/turf/anchor_turf
	var/ai_state = ZOMBIE_AI_STATE_IDLE
	var/ai_heartbeat = ZOMBIE_AI_DEFAULT_HEARTBEAT
	var/ai_idle_heartbeat = ZOMBIE_AI_DEFAULT_IDLE_HEARTBEAT
	var/attack_distance = ZOMBIE_AI_DEFAULT_ATTACK_DISTANCE
	var/return_distance = ZOMBIE_AI_DEFAULT_RETURN_DISTANCE
	/// Set TRUE to signal the ai_loop() coroutine to exit at its next check.
	var/detached = FALSE
	/// world.time floor before the next ai_step() is allowed - mirrors the pilot's own movement cooldown.
	var/next_step_time = 0
	/// The blocking obstacle (door/window/barricade) currently being forced through - see get_blocking_obstacle()'s doc comment in zombie_ai_movement.dm.
	var/atom/committed_obstacle
	/// world.time deadline on the above commitment.
	var/committed_obstacle_until = 0
	/// Cached route (list of turfs) toward path_goal - see advance_along_path().
	var/list/path_queue
	/// The turf path_queue was last computed against.
	var/turf/path_goal
	/// Whether the most recent path attempt against path_goal failed - gates the retry cooldown.
	var/path_failed = FALSE
	/// world.time floor before another path attempt against a still-failing goal is allowed.
	var/next_path_attempt = 0
	/// world.time floor before a route toward a merely-drifted goal is recomputed from scratch.
	var/next_replan_time = 0
	/// Set by advance_along_path() when a routed step turns out blocked - handle_travel_obstacles() consumes this in place of the far goal, see its doc comment.
	var/turf/route_block_turf
	/// Sidestep direction currently being committed to - see navigate_around()'s doc comment.
	var/fallback_walk_dir
	/// world.time deadline on the above commitment.
	var/fallback_walk_until = 0
	/// Which side (turn ±90 from goal direction) was picked last time, preferred again first to avoid flip-flopping between both sides of a corner.
	var/last_sidestep_dir

/datum/zombie_ai_controller/New(mob/living/carbon/human/new_pilot)
	. = ..()
	pilot = new_pilot
	anchor_turf = get_turf(pilot)

/datum/zombie_ai_controller/Destroy()
	detached = TRUE
	pilot = null
	current_target = null
	anchor_turf = null
	return ..()

/// Starts the coroutine. Safe to call more than once; the loop exits immediately if detached is already set.
/datum/zombie_ai_controller/proc/start()
	if(!pilot)
		return
	detached = FALSE
	INVOKE_ASYNC(src, PROC_REF(ai_loop))

/// Signals the coroutine to exit at its next check. Does not touch the pilot mob itself.
/datum/zombie_ai_controller/proc/stop()
	detached = TRUE

/**
 * Outer loop is intentionally just error containment + sleep timing - mirrors
 * xeno_ai_controller/ai_loop()'s reasoning exactly: a runtime error anywhere in
 * tick()'s call chain would otherwise unwind all the way up through this proc
 * and permanently kill the coroutine, leaving the mob standing frozen forever
 * with nothing left to ever tick it again. Catching here means one bad tick
 * just gets logged and skipped; the mob keeps trying next tick.
 */
/datum/zombie_ai_controller/proc/ai_loop()
	while(!detached && pilot && !QDELETED(pilot) && pilot.stat != DEAD)
		try
			tick()
		catch(var/exception/error)
			stack_trace("zombie_ai_controller/tick() error for [pilot] ([pilot?.type]): [error] at [error.file],[error.line]")
		sleep((ai_state == ZOMBIE_AI_STATE_IDLE) ? ai_idle_heartbeat : ai_heartbeat)

/datum/zombie_ai_controller/proc/tick()
	if(!pilot || pilot.is_mob_incapacitated())
		// Stunned/knocked down/etc - do nothing until it passes, same as a
		// player would be unable to act. Deliberately doesn't touch ai_state
		// so it resumes exactly where it left off once the effect ends.
		return

	switch(ai_state)
		if(ZOMBIE_AI_STATE_RETURNING)
			return_to_anchor()
			return
		if(ZOMBIE_AI_STATE_ATTACKING)
			process_attack()
			return

	if(current_target && should_disengage())
		drop_target()
		return

	if(!current_target)
		process_target()

	if(!current_target)
		ai_state = ZOMBIE_AI_STATE_IDLE
		return

	process_movement()

/**
 * Full scan of every living human for the nearest valid target within
 * attack_distance. No shared population-wide cache in v1 (see xeno's
 * GLOB.ai_target_candidate_pool for that pattern) - a single zombie's own scan
 * of GLOB.alive_human_list is cheap; this gets revisited in Phase 4 if/when
 * zombie population counts get large enough for it to matter.
 */
/datum/zombie_ai_controller/proc/process_target()
	if(!pilot)
		return
	var/turf/pilot_turf = get_turf(pilot)
	if(!pilot_turf)
		return

	var/mob/living/carbon/human/best_candidate
	var/best_dist = INFINITY
	for(var/mob/living/carbon/human/candidate as anything in GLOB.alive_human_list)
		if(candidate == pilot || candidate.z != pilot_turf.z)
			continue
		var/dist = get_dist(pilot, candidate)
		if(dist > attack_distance || dist >= best_dist)
			continue // Cheaper than is_valid_zombie_target() - worth checking distance first.
		if(!is_valid_zombie_target(candidate))
			continue
		best_dist = dist
		best_candidate = candidate

	if(!best_candidate)
		return
	acquire_target(best_candidate)

/**
 * Zombies never target other zombies - zombie_claws' own attack() already
 * refuses this too (black_goo.dm), but checking here means the AI doesn't even
 * walk toward one in the first place - and never target the dead.
 */
/datum/zombie_ai_controller/proc/is_valid_zombie_target(mob/living/carbon/human/candidate)
	if(!istype(candidate) || QDELETED(candidate))
		return FALSE
	if(candidate.stat == DEAD)
		return FALSE
	if(iszombie(candidate))
		return FALSE
	return TRUE

/datum/zombie_ai_controller/proc/acquire_target(atom/movable/target)
	current_target = target
	committed_obstacle = null
	committed_obstacle_until = 0
	path_queue = null
	path_goal = null
	route_block_turf = null
	fallback_walk_dir = null
	last_sidestep_dir = null
	ai_state = ZOMBIE_AI_STATE_APPROACHING

/datum/zombie_ai_controller/proc/drop_target()
	current_target = null
	committed_obstacle = null
	committed_obstacle_until = 0
	path_queue = null
	path_goal = null
	route_block_turf = null
	fallback_walk_dir = null
	last_sidestep_dir = null
	ai_state = ZOMBIE_AI_STATE_IDLE

/// Leash: give up and head home once a chase has dragged too far from anchor_turf. Zombies never disengage for being hurt (no should_flee() equivalent at all) - only for this.
/datum/zombie_ai_controller/proc/should_disengage()
	if(!pilot || !anchor_turf || !current_target)
		return FALSE
	return get_dist(pilot, anchor_turf) > return_distance

/**
 * Straight-line movement with obstacle forcing (see zombie_ai_movement.dm's
 * travel_to()/handle_travel_obstacles()) - a closed door/window/barricade
 * between the zombie and its target gets clawed/pried through rather than
 * leaving it stuck. Still no real pathfinding (Phase 3): a zombie can still
 * fail to route around a wall with no direct line to goal.
 */
/datum/zombie_ai_controller/proc/process_movement()
	if(!pilot || !current_target)
		return
	if(!is_valid_zombie_target(current_target))
		drop_target()
		return

	if(get_dist(pilot, current_target) <= 1 && is_melee_reachable(current_target))
		ai_state = ZOMBIE_AI_STATE_ATTACKING
		return

	travel_to(current_target)

/datum/zombie_ai_controller/proc/return_to_anchor()
	if(!pilot || !anchor_turf)
		ai_state = ZOMBIE_AI_STATE_IDLE
		return
	if(get_turf(pilot) == anchor_turf)
		ai_state = ZOMBIE_AI_STATE_IDLE
		return
	travel_to(anchor_turf)

/**
 * Melee execution - reuses zombie_claws' own attack() (black_goo.dm), the exact
 * same code path a player's click delivers, so damage/infection-bite logic is
 * never duplicated here. Falls back to l_hand if r_hand isn't zombie_claws for
 * any reason (should never happen for an intact zombie - species setup equips
 * it to both hands - defensive only).
 *
 * Gated on pilot.next_move (set below) - this call bypasses click.dm's
 * do_click() dispatch entirely (the only other place that normally paces melee),
 * so without this the engaged heartbeat would let it re-attack every tick. Same
 * gap xeno_ai_attack.dm's execute_attack() documents and fixes for attack_alien().
 */
/datum/zombie_ai_controller/proc/process_attack()
	if(!pilot || !current_target)
		ai_state = ZOMBIE_AI_STATE_IDLE
		return
	if(!is_valid_zombie_target(current_target))
		drop_target()
		return
	if(!is_melee_reachable(current_target))
		ai_state = ZOMBIE_AI_STATE_APPROACHING
		return
	if(world.time <= pilot.next_move)
		return

	var/obj/item/weapon/zombie_claws/claws = istype(pilot.r_hand, /obj/item/weapon/zombie_claws) ? pilot.r_hand : pilot.l_hand
	if(!istype(claws))
		return // No claws (disarmed somehow) - nothing to attack with this tick.
	pilot.setDir(get_dir(pilot, current_target))
	claws.attack(current_target, pilot)
	if(pilot) // attack() can retaliate/kill the pilot - don't write to it if it just died.
		pilot.next_move = world.time + ZOMBIE_AI_MELEE_ATTACK_DELAY

/// Single BYOND step() toward goal, cardinal-decomposed if goal is diagonal - mirrors xeno's cardinal_step_towards()/ai_step().
/datum/zombie_ai_controller/proc/cardinal_step_towards(atom/goal)
	if(!pilot || !goal || world.time < next_step_time)
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

/datum/zombie_ai_controller/proc/ai_step(direction)
	if(!pilot || world.time < next_step_time)
		return FALSE
	direction = get_cardinal_direction(direction)
	. = step(pilot, direction)
	if(. && pilot)
		next_step_time = world.time + pilot.movement_delay()

/// Defensive normalization if a diagonal ever reaches ai_step() directly - cardinal_step_towards() already only ever passes pure cardinals, this is just cheap insurance, mirrors xeno's own copy of the same helper.
/datum/zombie_ai_controller/proc/get_cardinal_direction(direction)
	if(!direction || !(direction & (direction - 1)))
		return direction // Already a pure cardinal (or zero) - nothing to decompose.
	var/list/components = list()
	if(direction & NORTH)
		components += NORTH
	else if(direction & SOUTH)
		components += SOUTH
	if(direction & EAST)
		components += EAST
	else if(direction & WEST)
		components += WEST
	return pick(components)
