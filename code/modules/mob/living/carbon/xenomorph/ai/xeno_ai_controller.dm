/**
 * Core decision-making datum for an NPC-piloted Xenomorph.
 *
 * One instance is composed onto a real xenomorph mob (see xeno_ai_lifecycle.dm's
 * attach_xeno_ai()) that has no client. It drives itself via its own INVOKE_ASYNC
 * coroutine (ai_loop()) rather than a shared subsystem tick, so idle mobs cost almost
 * nothing and busy mobs never stall the tick budget for player-piloted xenos on
 * SSxeno. The pilot's normal Life() ticking (health/plasma/status) is untouched -
 * this datum only adds a decision layer on top.
 */
/datum/xeno_ai_controller
	/// The xenomorph mob this controller pilots. Never changes for the lifetime of the datum.
	var/mob/living/carbon/xenomorph/pilot
	/// Current target being pursued/attacked, if any - either a living hostile or an attackable structure (e.g. a sentry turret).
	var/atom/movable/current_target
	/// Turf the pilot leashes to; wandering more than return_distance from this turf aborts the chase.
	var/turf/anchor_turf
	/// Cached bounded turf list from the last scan; reused across idle ticks until a target is found or the pilot moves on.
	var/list/turf_block
	var/ai_state = AI_STATE_IDLE
	/// Ticks slept between loop iterations while actively engaged (chasing/attacking).
	var/ai_heartbeat = AI_XENO_DEFAULT_HEARTBEAT
	/// Ticks slept between loop iterations while idle and scanning - deliberately longer than ai_heartbeat.
	var/ai_idle_heartbeat = AI_XENO_DEFAULT_IDLE_HEARTBEAT
	/// Radius (tiles) of the bounded target scan.
	var/attack_distance = AI_XENO_DEFAULT_ATTACK_DISTANCE
	/// Leash radius (tiles) from anchor_turf before the pilot disengages and returns.
	var/return_distance = AI_XENO_DEFAULT_RETURN_DISTANCE
	/// Set TRUE the instant the pilot should stop being AI-driven (client attached, death, deletion). The coroutine checks this at the top of every loop and exits cleanly - no forced kill of an in-flight sleep().
	var/detached = FALSE
	/// Consecutive failed movement attempts against the current target; used to give up rather than loop forever against an unreachable target (this AI does not pathfind).
	var/blocked_attempts = 0
	/// Last known turf of a target that escaped rather than died - drives AI_STATE_SEARCHING instead of instantly forgetting about it.
	var/turf/last_seen_turf
	/// world.time the current search began, to bound how long SEARCHING lasts.
	var/search_started_at = 0
	/// Cached native-pathfinder route (remaining waypoint turfs, nearest first). Null whenever there's no live plan - the old greedy step_towards() handles movement whenever this is empty, so a host without the native pathfinding library behaves exactly as before.
	var/list/path_queue
	/// The turf path_queue was computed to reach; a route is only reused while the goal hasn't moved to a different tile.
	var/turf/path_goal

/datum/xeno_ai_controller/New(mob/living/carbon/xenomorph/new_pilot)
	. = ..()
	pilot = new_pilot
	anchor_turf = get_turf(pilot)

/datum/xeno_ai_controller/Destroy()
	detached = TRUE
	pilot = null
	current_target = null
	anchor_turf = null
	turf_block = null
	path_queue = null
	path_goal = null
	return ..()

/// Starts the coroutine. Safe to call more than once; only ever spawns one loop per start() since the loop exits immediately if detached is already set.
/datum/xeno_ai_controller/proc/start()
	if(!pilot)
		return
	detached = FALSE
	INVOKE_ASYNC(src, PROC_REF(ai_loop))

/// Signals the coroutine to exit at its next check. Does not touch the pilot mob itself.
/datum/xeno_ai_controller/proc/stop()
	detached = TRUE

/**
 * Outer loop is intentionally just error containment + sleep timing - all
 * actual decision-making lives in tick(). A runtime error anywhere in that
 * call chain (movement, pathfinding, attack resolution, etc.) would otherwise
 * unwind all the way up through this proc and permanently kill the coroutine,
 * leaving the mob standing frozen forever with nothing further to fix it -
 * this is why "AI gets stuck for no reason" happened. Catching here means one
 * bad tick just gets logged and skipped; the mob keeps trying next tick.
 */
/datum/xeno_ai_controller/proc/ai_loop()
	while(!detached && pilot && !QDELETED(pilot) && pilot.stat != DEAD)
		try
			tick()
		catch(var/exception/error)
			stack_trace("xeno_ai_controller/tick() error for [pilot] ([pilot.type]): [error]")
		// Idle mobs sleep longer between ticks than engaged ones - checked
		// against the post-tick state so this still matches whatever tick()
		// just decided, same throttling as before the try/catch refactor.
		sleep((ai_state == AI_STATE_IDLE) ? ai_idle_heartbeat : ai_heartbeat)

/datum/xeno_ai_controller/proc/tick()
	if(pilot.is_mob_incapacitated() || HAS_TRAIT(pilot, TRAIT_IMMOBILIZED))
		// Stunned/knocked down/floored/etc - do nothing until it passes, same
		// as a player would be unable to act. TRAIT_IMMOBILIZED is checked
		// directly (not just is_mob_incapacitated()) because knockdown only
		// applies TRAIT_FLOORED/TRAIT_IMMOBILIZED, not TRAIT_INCAPACITATED -
		// relying on is_mob_incapacitated() alone missed that case entirely.
		// Deliberately does not touch ai_state so it resumes exactly where
		// it left off once the effect ends.
		return

	if(ai_state != AI_STATE_RETURNING && should_flee())
		drop_target()
		ai_state = AI_STATE_RETURNING

	switch(ai_state)
		if(AI_STATE_RETURNING)
			return_to_anchor()
			return
		if(AI_STATE_ATTACKING)
			process_attack()
			return
		if(AI_STATE_SEARCHING)
			process_search()
			return

	if(current_target && should_disengage())
		ai_state = AI_STATE_RETURNING
		return

	if(!current_target)
		process_target()

	if(!current_target)
		ai_state = AI_STATE_IDLE
		patrol()
		return

	process_movement()

/**
 * Idle xenos drift a short distance around their anchor instead of standing
 * perfectly still - makes an idle group look alive rather than frozen, and
 * doubles as a light patrol behavior. Bounded to AI_XENO_PATROL_RADIUS (well
 * inside return_distance) so it never turns into an unbounded wander; a mob
 * that's drifted to the edge heads back in instead of continuing outward.
 */
/datum/xeno_ai_controller/proc/patrol()
	if(!pilot || !anchor_turf)
		return
	if(!prob(AI_XENO_PATROL_CHANCE))
		return
	if(get_dist(pilot, anchor_turf) >= AI_XENO_PATROL_RADIUS)
		step_towards(pilot, anchor_turf)
		return
	step(pilot, pick(GLOB.alldirs))

/// Critically wounded or on-fire xenos disengage and head home instead of fighting on - mirrors a player's own instinct to flee/resist rather than burn or fight to the death.
/datum/xeno_ai_controller/proc/should_flee()
	if(!pilot)
		return FALSE
	if(pilot.on_fire)
		return TRUE
	if(!pilot.maxHealth)
		return FALSE
	return (pilot.health / pilot.maxHealth) < AI_XENO_FLEE_HEALTH_PERCENT

/**
 * Bounded, cached target scan. Only recomputes the block() rectangle when there is
 * no cached one to reuse - deliberately avoids re-scanning the map every idle tick.
 * Picks the NEAREST valid candidate found in the block (marines or active
 * sentry turrets - see is_valid_target()), not just the first one encountered
 * in scan order, so targeting doesn't depend on incidental turf iteration
 * order.
 */
/datum/xeno_ai_controller/proc/process_target()
	if(!pilot)
		return
	if(!turf_block || !length(turf_block))
		var/turf/pilot_turf = get_turf(pilot)
		if(!pilot_turf)
			return
		turf_block = block(
			locate(max(1, pilot_turf.x - attack_distance), max(1, pilot_turf.y - attack_distance), pilot_turf.z),
			locate(min(world.maxx, pilot_turf.x + attack_distance), min(world.maxy, pilot_turf.y + attack_distance), pilot_turf.z),
		)

	// Two targeted scans (mobs, then sentries) rather than one broad
	// atom/movable scan - keeps this to the same cheap candidate set as
	// before (living mobs) plus one narrow additional type, instead of
	// walking every item/decal/effect on every scanned turf.
	var/atom/movable/best_candidate
	var/best_dist = INFINITY
	for(var/turf/scanned_turf as anything in turf_block)
		for(var/mob/living/candidate in scanned_turf)
			if(!is_valid_target(candidate))
				continue
			var/dist = get_dist(pilot, candidate)
			if(dist < best_dist)
				best_dist = dist
				best_candidate = candidate
		for(var/obj/structure/machinery/defenses/sentry/candidate in scanned_turf)
			if(!is_valid_target(candidate))
				continue
			var/dist = get_dist(pilot, candidate)
			if(dist < best_dist)
				best_dist = dist
				best_candidate = candidate

	if(!best_candidate)
		return

	current_target = best_candidate
	last_seen_turf = get_turf(best_candidate)
	turf_block = null
	blocked_attempts = 0
	ai_state = AI_STATE_APPROACHING

	// Narrow, istype-guarded hook for the "Hive Incursion" gamemode's
	// ambient-patrol -> hive-alert contact trigger (see hive_encounter.dm) -
	// a no-op for every other gamemode, so this doesn't couple the generic
	// AI controller to that mode's logic beyond this one guarded call.
	if(isliving(best_candidate) && istype(SSticker.mode, /datum/game_mode/colonialmarines/hive_encounter))
		var/datum/game_mode/colonialmarines/hive_encounter/mode = SSticker.mode
		var/mob/living/living_candidate = best_candidate
		mode.on_contact_made(pilot, living_candidate)

/**
 * Valid targets are living marines, or active sentry turrets (xenos should
 * fight back against defenses shooting at them, not just claw through one
 * incidentally blocking a path to a marine). Stage 1 keeps this to those two
 * categories to stay predictable - broadening to other hostile
 * factions/synths/etc. is Stage 2+ work.
 */
/datum/xeno_ai_controller/proc/is_valid_target(atom/movable/candidate)
	if(!pilot || !candidate || QDELETED(candidate))
		return FALSE
	if(candidate == pilot)
		return FALSE

	if(isliving(candidate))
		var/mob/living/living_candidate = candidate
		if(living_candidate.stat == DEAD)
			return FALSE
		if(!ishuman(living_candidate))
			return FALSE
		if(should_block_game_interaction(living_candidate))
			return FALSE
		if(pilot.hive?.is_ally(living_candidate))
			return FALSE
		return TRUE

	if(istype(candidate, /obj/structure/machinery/defenses/sentry))
		var/obj/structure/machinery/defenses/sentry/turret = candidate
		if(turret.stat == DEFENSE_DESTROYED || !turret.turned_on)
			return FALSE
		return TRUE

	return FALSE

/**
 * Drops the current target. If should_search is set and we have a last-known
 * position, transitions to AI_STATE_SEARCHING to go investigate it instead of
 * instantly forgetting the target ever existed - used when a chase is broken off
 * by an obstacle (door/ladder/etc.) rather than the target actually dying or
 * becoming invalid, where there's nothing worth investigating.
 */
/datum/xeno_ai_controller/proc/drop_target(should_search = FALSE)
	current_target = null
	turf_block = null
	blocked_attempts = 0
	path_queue = null
	path_goal = null
	if(should_search && last_seen_turf)
		ai_state = AI_STATE_SEARCHING
		search_started_at = world.time
	else
		last_seen_turf = null
		ai_state = AI_STATE_IDLE

/datum/xeno_ai_controller/proc/should_disengage()
	if(!pilot || !anchor_turf || !current_target)
		return FALSE
	return get_dist(pilot, anchor_turf) > return_distance

/datum/xeno_ai_controller/proc/return_to_anchor()
	if(!pilot)
		return
	if(pilot.on_fire && pilot.can_resist())
		pilot.resist() // Same rolling/stop-drop-and-roll a player would do to put themselves out.
	if(!anchor_turf)
		ai_state = AI_STATE_IDLE
		return
	if(get_turf(pilot) == anchor_turf)
		if(!pilot.on_fire)
			ai_state = AI_STATE_IDLE
		return
	step_towards(pilot, anchor_turf)

/**
 * Travels toward the last place a lost target was seen, crossing z-levels via a
 * connected ladder if needed (see code/game/objects/structures/ladders.dm's
 * ai_use()). Keeps re-scanning for a fresh target en route so a different
 * marine wandering past will interrupt the search. Gives up after
 * AI_XENO_SEARCH_TIMEOUT or if there's simply no ladder connecting toward the
 * target's z-level, rather than getting stuck forever.
 */
/datum/xeno_ai_controller/proc/process_search()
	if(!pilot || !last_seen_turf)
		ai_state = AI_STATE_IDLE
		return

	if(world.time - search_started_at > AI_XENO_SEARCH_TIMEOUT)
		last_seen_turf = null
		ai_state = AI_STATE_IDLE
		return

	var/turf/pilot_turf = get_turf(pilot)
	if(!pilot_turf)
		return

	if(pilot_turf.z != last_seen_turf.z)
		var/obj/structure/ladder/target_ladder = find_ladder_towards(last_seen_turf.z)
		if(!target_ladder)
			last_seen_turf = null
			ai_state = AI_STATE_IDLE
			return
		if(get_dist(pilot, target_ladder) <= 0)
			target_ladder.ai_use(pilot, (last_seen_turf.z > pilot_turf.z) ? "up" : "down")
		else if(!advance_along_path(target_ladder))
			step_towards(pilot, target_ladder)
		return

	if(get_dist(pilot, last_seen_turf) <= 1)
		last_seen_turf = null
		ai_state = AI_STATE_IDLE
		return

	process_target()
	if(current_target)
		return

	if(!advance_along_path(last_seen_turf))
		step_towards(pilot, last_seen_turf)

/// Nearest ladder on the pilot's current z-level that actually connects toward target_z, or null if none does.
/datum/xeno_ai_controller/proc/find_ladder_towards(target_z)
	if(!pilot)
		return null
	var/turf/pilot_turf = get_turf(pilot)
	if(!pilot_turf)
		return null

	var/obj/structure/ladder/best
	var/best_dist = INFINITY
	for(var/obj/structure/ladder/candidate as anything in GLOB.ladder_list)
		var/turf/ladder_turf = get_turf(candidate)
		if(!ladder_turf || ladder_turf.z != pilot_turf.z)
			continue
		if(target_z > pilot_turf.z && !candidate.up)
			continue
		if(target_z < pilot_turf.z && !candidate.down)
			continue
		var/d = get_dist(pilot, candidate)
		if(d < best_dist)
			best_dist = d
			best = candidate
	return best

/**
 * Finds a specific ability instance on the pilot's action bar, for
 * per-caste controller subtypes that call a caste ability's use_ability()
 * body directly (bypassing the click/mouse layer) rather than the generic
 * melee attack_alien() chain - see the per-caste ability audit in the plan
 * (section 2.6). Returns null if the pilot doesn't have that ability at all.
 */
/datum/xeno_ai_controller/proc/get_ability(action_type)
	if(!pilot)
		return null
	return locate(action_type) in pilot.actions
