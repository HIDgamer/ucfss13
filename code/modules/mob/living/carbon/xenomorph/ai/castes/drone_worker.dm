/**
 * Drone AI - extends the shared melee/patrol controller with a build duty
 * cycle: instead of just wandering while idle, a Drone periodically expands
 * the hive's weed coverage (see xeno_ai_controller.dm's attempt_plant_weeds(),
 * shared with the Queen's own patrol()). Combat/searching/returning behavior
 * is entirely inherited unchanged (see patrol() below - that's the only
 * override), so a target wandering into range mid-build still gets chased
 * and fought normally - "aid and assist in attacking" per the user, not a
 * builder that ignores threats.
 *
 * Also occasionally attempts a defensive resin wall at the hive perimeter
 * (attempt_build_defense(), xeno_ai_controller.dm) on top of plain weeding -
 * a real, if simple, "wall a chokepoint around the hive" placement instead
 * of only ever weeding wherever she happens to be standing.
 */
/datum/xeno_ai_controller/drone_worker

/// "Drones... dive to their deaths" - she's a builder pressed into a fight, not a caste actually built to brawl, so she should break off sooner than the population default.
/datum/xeno_ai_controller/drone_worker/get_flee_threshold()
	return AI_DRONE_FLEE_HEALTH_PERCENT

/**
 * Only override needed: patrol() is called from the base tick() at exactly
 * the point where the pilot is confirmed idle with no target - rolling build
 * attempts in here instead of duplicating the whole state machine. Checks
 * for a Queen hive-alert first, same priority order as the base controller -
 * a call to arms takes precedence over routine building.
 */
/datum/xeno_ai_controller/drone_worker/patrol()
	if(respond_to_hive_alert())
		idle_activity = IDLE_ACTIVITY_ALERT
		return
	if(attempt_help_queen_build_core())
		idle_activity = IDLE_ACTIVITY_BUILD
		return
	if(prob(AI_DEFENSE_BUILD_CHANCE) && attempt_build_defense())
		idle_activity = IDLE_ACTIVITY_BUILD
		return
	if(prob(AI_DRONE_BUILD_CHANCE) && attempt_plant_weeds())
		idle_activity = IDLE_ACTIVITY_BUILD
		return
	return ..() // Falls through to the base patrol() (long patrol/pack cohesion/ambush hide/wander) instead of only ever plain wander().

/// A builder first, but "aid and assist in attacking" means an actual hit when it comes to that, not a bare claw.
/datum/xeno_ai_controller/drone_worker/use_caste_ability(mob/living/target)
	return attempt_tail_stab(target)
