/**
 * Boiler AI - "should only use ranged attacks, and only attack if enemies
 * get too close, otherwise attack ranged, hide, then come out to attack
 * again once the ability has recharged." Bombard has a genuine 60s cooldown
 * (general_abilities.dm's base xeno_spit, which bombard inherits unchanged)
 * - the ranged base's own melee fallback (ranged.dm's process_attack(), used
 * whenever nothing's off cooldown) would have her closing to melee for most
 * of that minute, exactly the opposite of "only use ranged attacks." Fully
 * overrides both process_attack() and process_movement() instead of
 * inheriting the shared kiting policy: rotates Bombard/Spray Acid (10s
 * cooldown - the old code never actually looked at this second ability, so
 * there was nothing to fall back on but melee) when either is up, actively
 * retreats out to a safe distance whenever both are on cooldown instead of
 * holding the kiting band and waiting to get pounced on, and only ever
 * swings in melee once something is already adjacent.
 */
/datum/xeno_ai_controller/ranged/boiler

/datum/xeno_ai_controller/ranged/boiler/New(mob/living/carbon/xenomorph/new_pilot)
	. = ..()
	attack_distance = AI_BOILER_ATTACK_DISTANCE

/datum/xeno_ai_controller/ranged/boiler/get_flee_threshold()
	return AI_BOILER_FLEE_HEALTH_PERCENT

/datum/xeno_ai_controller/ranged/boiler/get_ranged_ability()
	var/datum/action/xeno_action/activable/xeno_spit/bombard/bombard = get_ability(/datum/action/xeno_action/activable/xeno_spit/bombard)
	if(bombard && bombard.action_cooldown_check())
		return bombard
	return get_ability(/datum/action/xeno_action/activable/spray_acid/boiler)

/datum/xeno_ai_controller/ranged/boiler/process_attack()
	if(!pilot || !current_target)
		ai_state = AI_STATE_IDLE
		return
	if(!is_valid_target(current_target))
		drop_target()
		return

	if(pilot.Adjacent(current_target)) // Cornered - fight back rather than just standing there and dying.
		execute_attack(current_target)
		return

	var/datum/action/xeno_action/ability = get_ranged_ability()
	if(ability && has_line_of_sight(current_target))
		pilot.setDir(get_dir(pilot, current_target))
		ability.use_ability(current_target)
	ai_state = AI_STATE_APPROACHING // Always re-evaluate positioning next tick, win or lose - process_movement() below decides hide vs. hold vs. close in.

/**
 * "Attack ranged, hide, then come out to attack again once the ability has
 * recharged" - retreats to a wider, safer distance whenever nothing's off
 * cooldown, instead of holding the plain ranged kiting band and waiting
 * around to get closed on. Once something's ready again, closes back in to
 * the normal preferred band so process_attack() can actually use it.
 */
/datum/xeno_ai_controller/ranged/boiler/process_movement()
	if(!pilot || !current_target)
		return
	if(!is_valid_target(current_target))
		drop_target()
		return

	last_seen_turf = get_turf(current_target)
	var/dist = get_dist(pilot, current_target)

	var/ability_ready = !!get_ranged_ability()
	if(!ability_ready)
		if(dist < AI_BOILER_HIDE_DISTANCE)
			var/turf/defensible = find_defensible_turf()
			if(defensible && get_dist(pilot, defensible) > 0 && cardinal_step_towards(defensible))
				return
			var/away_dir = get_dir(current_target, pilot)
			if(!ai_step(away_dir))
				navigate_around(current_target)
			return
		return // Already far enough out - just sit tight and let the cooldown run.

	// Ability's up - same continuous-kiting policy every other ranged caste
	// uses (xeno_ai_movement.dm's maintain_kiting_distance()) instead of the
	// old static hold-band that let a marine close in unopposed.
	maintain_kiting_distance(current_target, AI_XENO_RANGED_PREFERRED_DISTANCE)
