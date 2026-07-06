/**
 * Crusher AI - the hive's frontline tank: a slow, heavily-armored charger
 * built to soak damage and punch a hole in whatever's in front of it,
 * matching the user's "head-on scary" caste design (as opposed to
 * Ravager's hit-and-reposition style - see ravager.dm). Patrol/search
 * behavior is entirely inherited from the base controller - the three
 * overrides below are what make a Crusher feel different to fight:
 *
 * - While closing on a target still out of melee range, fires its Charge
 *   ability (a long dash that knocks down and hits hard on landing)
 *   instead of plodding over on foot - a Crusher is XENO_SPEED_TIER_2
 *   (the slowest AI caste built so far), so without this it would take
 *   noticeably longer than every other caste to actually reach a target.
 * - Stomps (a self-centered AoE) instead of a plain melee swing whenever
 *   more than one valid target is already in range, so a Crusher wading
 *   into a cluster of marines hits all of them, not just whichever one
 *   it happens to be facing.
 * - Flees at a much lower health fraction than the default - a Crusher
 *   is meant to be the wall the hive leans on, not a caste that breaks
 *   off at the first sign of trouble like a squishier one would.
 *
 * Also proactively pops its defensive Shield (explosion immunity + a
 * per-hit damage cap) once actually taking a beating (below half health)
 * but not yet at the much lower flee threshold - "hurt but still fighting,"
 * not a panic button held in reserve forever.
 */
/datum/xeno_ai_controller/crusher

/datum/xeno_ai_controller/crusher/get_flee_threshold()
	return AI_CRUSHER_FLEE_HEALTH_PERCENT

/**
 * Duplicates the base controller's adjacency-to-attacking transition and
 * obstacle-handling tail (see xeno_ai_movement.dm's process_movement())
 * rather than sharing it, since the trigger condition for "close in" is
 * fundamentally different here - a real shared-helper refactor is a
 * reasonable follow-up, not done here to avoid touching the
 * already-verified base melee path (same tradeoff ranged.dm already
 * made for the same reason).
 */
/datum/xeno_ai_controller/crusher/process_movement()
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

	if(attempt_charge(current_target))
		return

	return ..()

/// Fires Charge at target if it's off cooldown and within its reach; returns FALSE (and does nothing else) otherwise, so the caller falls back to the inherited approach/pathfinding chain.
/datum/xeno_ai_controller/crusher/proc/attempt_charge(atom/target)
	var/datum/action/xeno_action/activable/pounce/crusher_charge/charge = get_ability(/datum/action/xeno_action/activable/pounce/crusher_charge)
	if(!charge || !charge.action_cooldown_check())
		return FALSE
	if(get_dist(pilot, target) > charge.distance)
		return FALSE
	if(!has_line_of_sight(target, physical_path = TRUE)) // "Immediately lunge and often get stuck on easily avoidable terrain (tables, fences, barricades)" - a dash needs a clear physical line, not just distance/no-walls, or she rams straight into furniture between her and the target.
		return FALSE
	charge.use_ability(target)
	return TRUE

/**
 * "Crusher never uses their stomping ability when near enemies" - Stomp
 * isn't just a self-centered AoE, it also knocks down everything it hits
 * (crusher_powers.dm's create_stomp()/get_xeno_stun_duration()), so it was
 * wrong to treat it as "strictly worse than a normal attack" against a lone
 * target and gate it behind 2+ nearby marines - a single-target knockdown
 * is still a big win, and 2+ marines standing that close together is the
 * less common case in practice, which is exactly why it read as "never"
 * firing. Now fires on anything valid in range, no minimum headcount.
 */
/datum/xeno_ai_controller/crusher/use_caste_ability(mob/living/target)
	if(!pilot)
		return FALSE

	attempt_shield() // Side effect only (own independent cooldown/plasma cost) - never blocks also using Stomp the same tick below.

	var/datum/action/xeno_action/onclick/crusher_stomp/stomp = get_ability(/datum/action/xeno_action/onclick/crusher_stomp)
	if(!stomp || !stomp.action_cooldown_check())
		return FALSE

	var/found_target = FALSE
	for(var/mob/living/carbon/nearby in orange(stomp.distance, pilot))
		if(is_valid_target(nearby))
			found_target = TRUE
			break
	if(!found_target)
		return FALSE

	stomp.use_ability(pilot) // Atom arg is unused by this ability (self-centered AoE) - see crusher_powers.dm.
	return TRUE

/// Pops Shield once actually taking a beating (below half health) but above the much lower flee threshold - "hurt but still fighting."
/datum/xeno_ai_controller/crusher/proc/attempt_shield()
	if(!pilot || !pilot.maxHealth || (pilot.health / pilot.maxHealth) >= 0.5)
		return FALSE
	var/datum/action/xeno_action/onclick/crusher_shield/shield = get_ability(/datum/action/xeno_action/onclick/crusher_shield)
	if(!shield || !shield.action_cooldown_check())
		return FALSE
	shield.use_ability(pilot)
	return TRUE
