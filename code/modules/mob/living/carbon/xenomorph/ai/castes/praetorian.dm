/**
 * Praetorian AI - a melee-primary hybrid "warleader": closes with Dash like
 * Crusher/Ravager's own dashes, throws Acid Ball as a heavy periodic hit in
 * between plain swings, then deliberately breaks off - "hop into action,
 * use its abilities, slash marines, and hop back into safety, and repeat."
 * Per the user's explicit design ("use retreating in combat instead of low
 * health = retreat"), this is a proactive hit-and-run rotation, not
 * should_flee()'s health-threshold panic button - see the shared
 * start_tactical_retreat()/is_tactical_retreating() helpers.
 */
/datum/xeno_ai_controller/praetorian

/**
 * Same duplication tradeoff as crusher.dm/ravager.dm/runner.dm/warrior.dm -
 * attempting the dash before falling through to the inherited approach
 * chain differs enough from the base melee policy to warrant a full
 * override.
 */
/datum/xeno_ai_controller/praetorian/process_movement()
	if(!pilot || !current_target)
		return

	if(!is_valid_target(current_target))
		drop_target()
		return

	last_seen_turf = get_turf(current_target)

	if(is_tactical_retreating())
		// "Hop back into safety" - Dash only ever closes distance, so
		// retreating is a plain backstep, same as every other hit-and-run
		// caste. Cornered with nowhere to actually back into cancels the
		// retreat outright and falls through to fighting instead of
		// standing frozen for the rest of the retreat window.
		if(step_away_from_target())
			return
		tactical_retreat_until = 0

	if(get_dist(pilot, current_target) <= 1 && pilot.Adjacent(current_target))
		ai_state = AI_STATE_ATTACKING
		blocked_attempts = 0
		path_queue = null
		return

	if(attempt_dash(current_target))
		return

	return ..()

/// Fires Dash at target if it's off cooldown and within its reach; returns FALSE (and does nothing else) otherwise, so the caller falls back to the inherited approach/pathfinding chain.
/datum/xeno_ai_controller/praetorian/proc/attempt_dash(atom/target)
	var/datum/action/xeno_action/activable/pounce/base_prae_dash/dash = get_ability(/datum/action/xeno_action/activable/pounce/base_prae_dash)
	if(!dash || !dash.action_cooldown_check())
		return FALSE
	if(get_dist(pilot, target) > dash.distance)
		return FALSE
	if(!has_line_of_sight(target, physical_path = TRUE)) // A dash is a physical lunge - furniture blocks it same as a wall would.
		return FALSE
	dash.use_ability(target)
	return TRUE

/// "Slash marines and hop back into safety" - Acid Ball is the "use its abilities" hit that ends the engagement window; without it, a chance per plain swing still eventually breaks off the fight.
/datum/xeno_ai_controller/praetorian/use_caste_ability(mob/living/target)
	var/datum/action/xeno_action/activable/prae_acid_ball/acid_ball = get_ability(/datum/action/xeno_action/activable/prae_acid_ball)
	if(acid_ball && acid_ball.action_cooldown_check())
		acid_ball.use_ability(target)
		start_tactical_retreat(AI_PRAETORIAN_RETREAT_DURATION)
		return TRUE

	if(prob(AI_PRAETORIAN_RETREAT_CHANCE))
		start_tactical_retreat(AI_PRAETORIAN_RETREAT_DURATION)
	return FALSE
