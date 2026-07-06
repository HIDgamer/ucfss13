/**
 * Lurker AI - the hive's stealth ambush predator: cloaks while stalking a
 * target instead of closing in visibly, pounces once in range (cloaked
 * Lurkers get a speed buff, making the cloak-then-pounce combo the fast
 * option too, not just the sneaky one), and arms Assassinate for a
 * bonus-damage opener before the first real hit lands. Decloaking itself
 * on attack/bump is already handled by the caste's own signal handlers
 * (Lurker.dm) - nothing extra needed here for that part.
 *
 * "Use their abilities to attack enemies as is, but make retreating a
 * strategic part of their attack plan too, as they attack and die" - she's
 * fast but low-HP/no-armor, exactly the caste that should never just stand
 * and trade once the opener's spent. use_caste_ability() below queues a
 * tactical retreat after a few hits (the shared hit-and-run helper, same as
 * Praetorian/Ravager/Burrower), and process_movement() re-cloaks while
 * pulling out so she actually vanishes again instead of retreating in
 * plain sight, ready to re-pounce once she's got room.
 */
/datum/xeno_ai_controller/lurker

/**
 * Same duplication tradeoff as crusher.dm/ravager.dm/runner.dm - attempting
 * the pounce (and keeping cloak up while closing) differs enough from the
 * base melee policy to warrant a full override.
 */
/datum/xeno_ai_controller/lurker/process_movement()
	if(!pilot || !current_target)
		return

	if(!is_valid_target(current_target))
		drop_target()
		return

	last_seen_turf = get_turf(current_target)
	attempt_cloak()

	if(is_tactical_retreating())
		// Cornered with nowhere to actually back into cancels the retreat
		// outright instead of standing frozen for the rest of the window.
		if(step_away_from_target())
			return
		tactical_retreat_until = 0

	if(get_dist(pilot, current_target) <= 1 && pilot.Adjacent(current_target))
		ai_state = AI_STATE_ATTACKING
		blocked_attempts = 0
		path_queue = null
		return

	if(attempt_pounce(current_target))
		return

	return ..()

/// Cloaks while hunting if not already cloaked and off cooldown - a silent approach instead of announcing the chase.
/datum/xeno_ai_controller/lurker/proc/attempt_cloak()
	var/mob/living/carbon/xenomorph/xeno_pilot = pilot
	if(xeno_pilot.stealth)
		return
	var/datum/action/xeno_action/onclick/lurker_invisibility/cloak = get_ability(/datum/action/xeno_action/onclick/lurker_invisibility)
	if(!cloak || !cloak.action_cooldown_check())
		return
	cloak.use_ability(xeno_pilot)

/// Fires Pounce at target if it's off cooldown and within its reach; returns FALSE (and does nothing else) otherwise, so the caller falls back to the inherited approach/pathfinding chain.
/datum/xeno_ai_controller/lurker/proc/attempt_pounce(atom/target)
	var/datum/action/xeno_action/activable/pounce/lurker/pounce = get_ability(/datum/action/xeno_action/activable/pounce/lurker)
	if(!pounce || !pounce.action_cooldown_check())
		return FALSE
	if(get_dist(pilot, target) > pounce.distance)
		return FALSE
	if(!has_line_of_sight(target, physical_path = TRUE)) // A pounce is a physical dash - tables/fences/barricades block it same as a wall would, not just line-of-sight.
		return FALSE
	pounce.use_ability(target)
	return TRUE

/// Arms a bonus-damage slash before the first hit if it isn't armed already - an opener, not something to keep re-arming mid-fight.
/datum/xeno_ai_controller/lurker/use_caste_ability(mob/living/target)
	var/mob/living/carbon/xenomorph/xeno_pilot = pilot
	var/datum/behavior_delegate/lurker_base/behavior = xeno_pilot.behavior_delegate
	if(istype(behavior) && behavior.next_slash_buffed)
		return FALSE

	var/datum/action/xeno_action/onclick/lurker_assassinate/assassinate = get_ability(/datum/action/xeno_action/onclick/lurker_assassinate)
	if(assassinate && assassinate.action_cooldown_check())
		assassinate.use_ability(xeno_pilot)
		return FALSE // Arms the next swing rather than replacing it - always fall through to the plain melee attack this tick.

	if(prob(AI_LURKER_RETREAT_CHANCE))
		start_tactical_retreat(AI_LURKER_RETREAT_DURATION)
	return FALSE
