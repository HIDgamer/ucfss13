/**
 * Despoiler AI - a fragile-feeling but heavily armored acid artillery unit (XENO_HEALTH_TIER_9,
 * armor_deflection TIER_2, but deevolves_to Spitter and spit_types is her whole kit identity - no
 * melee tools worth leading with). Kites like the rest of ranged.dm's family, firing Corrosive Acid
 * at range, but layers in her unique hypertension/Catalyze economy on top: banks a Catalyze charge
 * opportunistically, then spends it immediately on Caustic Embrace (a normally melee-only pounce
 * that reaches 5 tiles and hits much harder while empowered) rather than letting the buff expire
 * unused, self-casts Oozing Wounds as area denial once something's actually closing the distance,
 * and fires Acid Barrage as a heavier volley option against a real cluster instead of only ever
 * using the cheaper single-target spit.
 */
/datum/xeno_ai_controller/ranged/despoiler

/datum/xeno_ai_controller/ranged/despoiler/get_ranged_ability()
	return get_ability(/datum/action/xeno_action/activable/corrosive_acid/strong)

/// Cornered-only, same as every other ranged.dm subtype - tail_stab/despoiler is a subtype of the plain base type, get_ability()'s locate() matches it fine.
/datum/xeno_ai_controller/ranged/despoiler/use_caste_ability(mob/living/target)
	return attempt_tail_stab(target)

/**
 * Overrides the base ranged process_attack() entirely to weave her unique kit in around the normal
 * kite-and-fire loop: bank a Catalyze charge opportunistically, spend an active empowerment on
 * Caustic Embrace immediately rather than let it expire unused, self-cast Oozing Wounds once
 * something's actually closing in, and fire Acid Barrage as a heavier option against a real cluster
 * instead of only ever using the cheaper single-target acid spit.
 */
/datum/xeno_ai_controller/ranged/despoiler/process_attack()
	if(!pilot || !current_target)
		ai_state = AI_STATE_IDLE
		return
	if(!is_valid_target(current_target))
		drop_target()
		return

	attempt_catalyze()

	if(attempt_empowered_embrace(current_target))
		return

	if(pilot.Adjacent(current_target))
		attempt_oozing_wounds()
		execute_attack(current_target)
		if(stale_attack_ticks >= AI_PRIORITY_STALE_ATTACK_GIVEUP) // Same as ranged.dm's own cornered case - give up rather than claw an undamageable target forever.
			drop_target()
		return

	if(attempt_acid_barrage(current_target))
		return

	var/datum/action/xeno_action/ability = get_ranged_ability()
	if(ability && ability.action_cooldown_check() && has_line_of_sight(current_target, allow_partial_cover = TRUE))
		pilot.setDir(get_dir(pilot, current_target))
		ability.use_ability(current_target)
	ai_state = AI_STATE_APPROACHING

/// Banks a Catalyze charge whenever she has hypertension to spare and isn't already sitting on an unused empowerment - see attempt_empowered_embrace() for where it actually gets spent.
/datum/xeno_ai_controller/ranged/despoiler/proc/attempt_catalyze()
	if(!pilot || !current_target)
		return FALSE
	var/mob/living/carbon/xenomorph/despoiler/xeno_pilot = pilot
	if(!istype(xeno_pilot))
		return FALSE
	var/datum/behavior_delegate/despoiler_base/delegate = xeno_pilot.behavior_delegate
	if(!istype(delegate) || delegate.next_ability_empowered || delegate.hypertension_stacks < 1)
		return FALSE
	var/datum/action/xeno_action/onclick/catalyze/catalyze = get_ability(/datum/action/xeno_action/onclick/catalyze)
	if(!catalyze || !catalyze.action_cooldown_check())
		return FALSE
	catalyze.use_ability(current_target)
	return TRUE

/// Spends an active empowerment on Caustic Embrace the moment it's usable (empowered reach is 5 tiles vs. her normal 1) instead of leaving it to expire unused - a real alpha-strike combo, not just a passive buff.
/datum/xeno_ai_controller/ranged/despoiler/proc/attempt_empowered_embrace(mob/living/target)
	if(!pilot || !target)
		return FALSE
	var/mob/living/carbon/xenomorph/despoiler/xeno_pilot = pilot
	if(!istype(xeno_pilot))
		return FALSE
	var/datum/behavior_delegate/despoiler_base/delegate = xeno_pilot.behavior_delegate
	if(!istype(delegate) || !delegate.next_ability_empowered)
		return FALSE
	var/datum/action/xeno_action/activable/pounce/caustic_embrace/embrace = get_ability(/datum/action/xeno_action/activable/pounce/caustic_embrace)
	if(!embrace || !embrace.action_cooldown_check())
		return FALSE
	if(get_dist(pilot, target) > embrace.empowered_distance)
		return FALSE
	if(!has_line_of_sight(target, physical_path = TRUE))
		return FALSE
	embrace.use_ability(target)
	return TRUE

/// Self-centered area-denial acid - worth it once something's actually closing in on her rather than staying at range where a single-target spit is more efficient.
/datum/xeno_ai_controller/ranged/despoiler/proc/attempt_oozing_wounds()
	if(!pilot || !current_target)
		return FALSE
	if(get_dist(pilot, current_target) > 2)
		return FALSE
	var/datum/action/xeno_action/onclick/oozing_wounds/oozing = get_ability(/datum/action/xeno_action/onclick/oozing_wounds)
	if(!oozing || !oozing.action_cooldown_check())
		return FALSE
	oozing.use_ability()
	return TRUE

/**
 * A heavier volley option than the base single-target Corrosive Acid - worth the longer charge
 * commitment specifically against a real cluster (same nearby-hostile-count reasoning as
 * should_hold_and_fight()) rather than on every single shot. Charges for a fixed window
 * (AI_DESPOILER_BARRAGE_CHARGE_TIME) rather than the ability's own maximum, then fires directly -
 * an AI-piloted mob has no mouse to release with, so release_barrage() is invoked directly (it's a
 * plain proc despite being registered as a signal handler for the player-driven mouse-up case, and
 * already does its own full cleanup/cooldown/UnregisterSignal regardless of how it's called).
 */
/datum/xeno_ai_controller/ranged/despoiler/proc/attempt_acid_barrage(mob/living/target)
	if(!pilot || !target)
		return FALSE
	if(!has_line_of_sight(target, allow_partial_cover = TRUE))
		return FALSE
	var/datum/action/xeno_action/activable/acid_barrage/barrage = get_ability(/datum/action/xeno_action/activable/acid_barrage)
	if(!barrage || !barrage.action_cooldown_check())
		return FALSE
	var/nearby_hostiles = 0
	for(var/mob/living/nearby in orange(AI_RANGED_HOLD_GROUP_RADIUS, target))
		if(nearby == target || !is_valid_target(nearby))
			continue
		nearby_hostiles++
		if(nearby_hostiles >= AI_RANGED_HOLD_GROUP_THRESHOLD)
			break
	if(nearby_hostiles < AI_RANGED_HOLD_GROUP_THRESHOLD)
		return FALSE
	pilot.setDir(get_dir(pilot, target))
	if(!barrage.use_ability(target))
		return FALSE
	addtimer(CALLBACK(src, PROC_REF(release_barrage_at), barrage, target), AI_DESPOILER_BARRAGE_CHARGE_TIME)
	return TRUE

/datum/xeno_ai_controller/ranged/despoiler/proc/release_barrage_at(datum/action/xeno_action/activable/acid_barrage/barrage, atom/target)
	if(!barrage || QDELETED(barrage) || !pilot || QDELETED(pilot))
		return
	barrage.release_barrage(pilot, target)
