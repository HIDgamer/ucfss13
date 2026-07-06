/**
 * Sentinel AI - "modify the sentinel and queen AI to only use ranged, and
 * to use melee if unable to escape or enemies are too close." Overrides
 * process_attack() so melee is only ever the explicit cornered case, never
 * incidental, and delegates actual positioning to the shared
 * maintain_kiting_distance() helper (xeno_ai_movement.dm) so she actually
 * keeps her distance instead of holding still once in range. Still arms
 * Paralyzing Slash (primes the next melee swing to knock down) whenever
 * it's off cooldown, for whenever that cornered case actually happens.
 */
/datum/xeno_ai_controller/ranged/sentinel

/datum/xeno_ai_controller/ranged/sentinel/get_ranged_ability()
	return get_ability(/datum/action/xeno_action/activable/slowing_spit)

/datum/xeno_ai_controller/ranged/sentinel/process_attack()
	if(!pilot || !current_target)
		ai_state = AI_STATE_IDLE
		return
	if(!is_valid_target(current_target))
		drop_target()
		return

	if(pilot.Adjacent(current_target)) // Cornered - fight back rather than just standing there.
		execute_attack(current_target)
		return

	var/datum/action/xeno_action/ability = get_ranged_ability()
	if(ability && ability.action_cooldown_check() && has_line_of_sight(current_target))
		pilot.setDir(get_dir(pilot, current_target))
		ability.use_ability(current_target)
	ai_state = AI_STATE_APPROACHING

/datum/xeno_ai_controller/ranged/sentinel/process_movement()
	if(!pilot || !current_target)
		return
	if(!is_valid_target(current_target))
		drop_target()
		return

	last_seen_turf = get_turf(current_target)
	maintain_kiting_distance(current_target, AI_XENO_RANGED_PREFERRED_DISTANCE)

/datum/xeno_ai_controller/ranged/sentinel/use_caste_ability(mob/living/target)
	var/datum/action/xeno_action/onclick/paralyzing_slash/buff = get_ability(/datum/action/xeno_action/onclick/paralyzing_slash)
	if(buff && buff.action_cooldown_check())
		buff.use_ability(pilot)
	return FALSE // Arms the next swing rather than replacing it - always fall through to the plain melee attack this tick.
