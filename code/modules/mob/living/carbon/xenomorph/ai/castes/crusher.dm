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
 * Known interim simplification: never proactively uses its defensive
 * Shield ability - Stage 1 keeps this caste's decision surface to
 * offense/mobility; a shield-when-badly-hurt-but-still-fighting trigger
 * is a reasonable follow-up once this is proven in a real round.
 */
/datum/xeno_ai_controller/crusher

/datum/xeno_ai_controller/crusher/should_flee()
	if(!pilot)
		return FALSE
	if(pilot.on_fire)
		return TRUE
	if(!pilot.maxHealth)
		return FALSE
	return (pilot.health / pilot.maxHealth) < AI_CRUSHER_FLEE_HEALTH_PERCENT

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
	charge.use_ability(target)
	return TRUE

/**
 * Stomp is a self-centered AoE (hits everything within its own distance
 * var, not just the current_target), so it's only worth using in place of
 * a plain melee swing when there's more than one valid target already
 * that close - otherwise it's strictly worse than a normal attack for the
 * same plasma/cooldown cost.
 */
/datum/xeno_ai_controller/crusher/use_caste_ability(mob/living/target)
	var/datum/action/xeno_action/onclick/crusher_stomp/stomp = get_ability(/datum/action/xeno_action/onclick/crusher_stomp)
	if(!pilot || !stomp || !stomp.action_cooldown_check())
		return FALSE

	var/nearby_targets = 0
	for(var/mob/living/carbon/nearby in orange(stomp.distance, pilot))
		if(!is_valid_target(nearby))
			continue
		nearby_targets++
		if(nearby_targets >= AI_CRUSHER_STOMP_MIN_TARGETS)
			break

	if(nearby_targets < AI_CRUSHER_STOMP_MIN_TARGETS)
		return FALSE

	stomp.use_ability(pilot) // Atom arg is unused by this ability (self-centered AoE) - see crusher_powers.dm.
	return TRUE
