/**
 * Warrior AI - a heavy melee brawler: closes with Lunge (a grab-range
 * closer, not a pounce-style throw) instead of walking the whole distance,
 * then prefers Punch (can fracture/target limbs) over a plain claw once
 * engaged, falling through to Tail Stab as a follow-up hit whenever Punch
 * itself is still on cooldown - "use its punch ability with its other
 * lunge ability and follow ups" - instead of a bare claw the instant Punch
 * isn't up. Patrol/search behavior is entirely inherited from the base
 * controller.
 */
/datum/xeno_ai_controller/warrior

/**
 * Same duplication tradeoff as crusher.dm/ravager.dm/runner.dm - attempting
 * Lunge before falling through to the inherited approach chain differs
 * enough from the base melee policy to warrant a full override.
 */
/datum/xeno_ai_controller/warrior/process_movement()
	if(!pilot || !current_target)
		return

	if(!is_valid_target(current_target))
		drop_target()
		return

	last_seen_turf = get_turf(current_target)

	if(get_dist(pilot, current_target) <= 1 && pilot.Adjacent(current_target))
		ai_state = AI_STATE_ATTACKING
		blocked_attempts = 0
		path_queue = null
		return

	if(attempt_lunge(current_target))
		return

	return ..()

/// Fires Lunge at target if it's off cooldown and within grab range; returns FALSE (and does nothing else) otherwise, so the caller falls back to the inherited approach/pathfinding chain.
/datum/xeno_ai_controller/warrior/proc/attempt_lunge(atom/target)
	var/datum/action/xeno_action/activable/lunge/lunge = get_ability(/datum/action/xeno_action/activable/lunge)
	if(!lunge || !lunge.action_cooldown_check())
		return FALSE
	if(get_dist(pilot, target) > lunge.grab_range)
		return FALSE
	if(!has_line_of_sight(target, physical_path = TRUE)) // A lunge is a physical throw - tables/fences/barricades block it same as a wall would, same fix already applied to every other dash-type ability.
		return FALSE
	lunge.use_ability(target)
	return TRUE

/datum/xeno_ai_controller/warrior/use_caste_ability(mob/living/target)
	var/datum/action/xeno_action/activable/warrior_punch/punch = get_ability(/datum/action/xeno_action/activable/warrior_punch)
	if(punch && punch.action_cooldown_check())
		punch.use_ability(target)
		return TRUE
	return attempt_tail_stab(target)
