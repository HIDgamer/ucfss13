/**
 * Base controller for castes that fight from range instead of melee
 * (Spitter now; Boiler/Praetorian/Lurker are natural next additions - see
 * the plan's 2.6 section). Confirmed zero ranged AI existed anywhere to
 * port technique from, so this is new design: maintain distance instead of
 * closing to melee, back off if the target gets too close, and fire the
 * caste's ranged ability instead of attack_alien() once in range.
 *
 * Checks line-of-sight (has_line_of_sight(), xeno_ai_movement.dm) before
 * actually firing - a target at the right distance but behind a wall now
 * gets closed in on instead of plinked at uselessly through it.
 */
/datum/xeno_ai_controller/ranged

/// Concrete subtypes override this to return their ranged ability instance (or null if the pilot doesn't have it for some reason - triggers a melee/re-approach fallback in process_attack()).
/datum/xeno_ai_controller/ranged/proc/get_ranged_ability()
	return null

/**
 * Overrides the base melee movement policy entirely - continuous kiting via
 * the shared maintain_kiting_distance() helper (xeno_ai_movement.dm) instead
 * of a bespoke band, so the "die in place" bug it fixes is fixed once for
 * every ranged caste rather than four times.
 */
/datum/xeno_ai_controller/ranged/process_movement()
	if(!pilot || !current_target)
		return

	if(!is_valid_target(current_target))
		drop_target()
		return

	last_seen_turf = get_turf(current_target)
	maintain_kiting_distance(current_target, AI_XENO_RANGED_PREFERRED_DISTANCE)

/**
 * Fires the ranged ability once in band. Spitter's spit is a 60-second
 * cooldown - with no fallback, the AI would just stand at range doing
 * nothing for roughly 59 of every 60 seconds mid-fight (use_ability()'s own
 * cooldown check silently no-ops). Now checks the cooldown itself first: if
 * the ability isn't ready, it fights in melee instead of idling out the
 * wait, closing distance directly if not yet adjacent rather than routing
 * through ai_state (APPROACHING would immediately flip back to ATTACKING
 * via process_movement()'s own "within preferred distance" check without
 * ever actually taking a step, since nothing here changed how far away it
 * is). Once the ability comes off cooldown again, too-close/too-far both
 * hand off to APPROACHING so process_movement() re-establishes the
 * preferred kiting distance instead of plinking away point-blank forever.
 */
/datum/xeno_ai_controller/ranged/process_attack()
	if(!pilot || !current_target)
		ai_state = AI_STATE_IDLE
		return

	if(!is_valid_target(current_target))
		drop_target()
		return

	var/datum/action/xeno_action/ability = get_ranged_ability()
	var/ability_ready = ability && ability.action_cooldown_check()

	if(!ability_ready)
		if(pilot.Adjacent(current_target))
			execute_attack(current_target)
		else if(!advance_along_path(current_target))
			cardinal_step_towards(current_target)
		return

	var/dist = get_dist(pilot, current_target)
	if(dist <= AI_XENO_RANGED_MIN_DISTANCE || dist > AI_XENO_RANGED_PREFERRED_DISTANCE + 2)
		ai_state = AI_STATE_APPROACHING
		return

	if(!has_line_of_sight(current_target))
		ai_state = AI_STATE_APPROACHING // No clean shot (wall/dense obstacle in the way) - close in instead of plinking uselessly at cover.
		return

	pilot.setDir(get_dir(pilot, current_target))
	ability.use_ability(current_target)

/**
 * Spitter - "doesn't have an AI fight preset, they just death charge" was a
 * real bug, not a design gap: this queried /xeno_spit/spitter, a cosmetic
 * subtype Spitter.dm's own base_actions never actually grants (it grants
 * the plain /xeno_spit base type instead) - get_ability()'s locate() only
 * matches a held instance that IS the queried type or a stricter subtype of
 * it, never the other way around, so this always returned null and every
 * Spitter fell straight into ranged.dm's melee fallback, permanently. Fixed
 * to query the type actually granted. That ability still has a genuine 60s
 * cooldown though (general_abilities.dm), so on its own she'd still spend
 * most of a fight in the melee fallback - falls back to Spray Acid (8s
 * cooldown, a real ranged line attack) instead of closing to melee whenever
 * the big spit isn't up, so she stays a ranged threat continuously rather
 * than only once a minute.
 */
/datum/xeno_ai_controller/ranged/spitter

/datum/xeno_ai_controller/ranged/spitter/get_ranged_ability()
	var/datum/action/xeno_action/activable/xeno_spit/spit = get_ability(/datum/action/xeno_action/activable/xeno_spit)
	if(spit && spit.action_cooldown_check())
		return spit
	return get_ability(/datum/action/xeno_action/activable/spray_acid/spitter)
