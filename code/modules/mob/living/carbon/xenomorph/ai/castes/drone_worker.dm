/**
 * Drone AI - extends the shared melee/patrol controller with a build duty
 * cycle: instead of just wandering while idle, a Drone periodically expands
 * the hive's weed coverage. Combat/searching/returning behavior is entirely
 * inherited unchanged (see patrol() below - that's the only override), so a
 * target wandering into range mid-build still gets chased and fought
 * normally - "aid and assist in attacking" per the user, not a builder that
 * ignores threats.
 *
 * Known interim simplification: only plants weeds for now. Real resin
 * structures (walls at chokepoints, etc. via build_resin()/
 * place_construction() in Powers.dm) need the drone to have first chosen
 * what to build and where - a real placement-decision algorithm, not just
 * "try it on my current tile" - so that's follow-up work, not this pass.
 */
/datum/xeno_ai_controller/drone_worker

/**
 * Only override needed: patrol() is called from the base tick() at exactly
 * the point where the pilot is confirmed idle with no target - rolling build
 * attempts in here instead of duplicating the whole state machine. Checks
 * for a Queen hive-alert first, same priority order as the base controller -
 * a call to arms takes precedence over routine building.
 */
/datum/xeno_ai_controller/drone_worker/patrol()
	if(respond_to_hive_alert())
		return
	if(prob(AI_DRONE_BUILD_CHANCE) && attempt_build_action())
		return
	wander()

/// Calls the real plant_weeds ability directly - its own internal checks (weedable ground, not already weeded enough, hive ownership) handle rejection silently if the current tile isn't suitable, same as a player clicking it somewhere bad.
/datum/xeno_ai_controller/drone_worker/proc/attempt_build_action()
	var/datum/action/xeno_action/onclick/plant_weeds/action = get_ability(/datum/action/xeno_action/onclick/plant_weeds)
	if(!action)
		return FALSE
	action.use_ability(pilot)
	return TRUE
