/**
 * Base controller for castes that fight from range instead of melee
 * (Spitter now; Boiler/Praetorian/Lurker are natural next additions - see
 * the plan's 2.6 section). Confirmed zero ranged AI existed anywhere to
 * port technique from, so this is new design: maintain distance instead of
 * closing to melee, back off if the target gets too close, and fire the
 * caste's ranged ability instead of attack_alien() once in range.
 *
 * Known interim simplification: range is purely distance-based, there's no
 * line-of-sight check yet (a target behind a wall at the right distance
 * would still be "in range" as far as this controller is concerned, even
 * though the actual spit ability would fail/hit the wall instead). Adding a
 * real LOS check is a reasonable follow-up once this base movement policy is
 * proven.
 */
/datum/xeno_ai_controller/ranged

/// Concrete subtypes override this to return their ranged ability instance (or null if the pilot doesn't have it for some reason - triggers a melee/re-approach fallback in process_attack()).
/datum/xeno_ai_controller/ranged/proc/get_ranged_ability()
	return null

/**
 * Overrides the base melee movement policy entirely: too close means back
 * away, in-band means hold and fire, too far means close in using the same
 * pathfinding/obstacle-handling tail as the melee controller (duplicated
 * here rather than shared, since the trigger condition for "close in" is
 * fundamentally different - a real shared-helper refactor is a reasonable
 * follow-up, not done here to avoid touching the already-verified melee path
 * under time pressure).
 */
/datum/xeno_ai_controller/ranged/process_movement()
	if(!pilot || !current_target)
		return

	if(!is_valid_target(current_target))
		drop_target()
		return

	last_seen_turf = get_turf(current_target)
	var/dist = get_dist(pilot, current_target)

	if(dist <= AI_XENO_RANGED_MIN_DISTANCE)
		var/away_dir = get_dir(current_target, pilot)
		if(!step(pilot, away_dir))
			navigate_around()
		return

	if(dist <= AI_XENO_RANGED_PREFERRED_DISTANCE)
		ai_state = AI_STATE_ATTACKING
		blocked_attempts = 0
		path_queue = null
		return

	if(advance_along_path(current_target))
		blocked_attempts = 0
		return

	if(step_towards(pilot, current_target))
		blocked_attempts = 0
		return

	var/obj/structure/blocking_obstacle = get_blocking_obstacle(current_target)
	if(blocking_obstacle)
		attack_blocking_obstacle(blocking_obstacle)
		blocked_attempts = 0
		return

	if(navigate_around())
		blocked_attempts = 0
		return

	blocked_attempts++
	if(blocked_attempts >= 2)
		drop_target(TRUE)

/// Fires the ranged ability once in band; resumes closing in if the target moved out of range, and falls back to melee/re-approach if the caste has no ranged ability attached for some reason.
/datum/xeno_ai_controller/ranged/process_attack()
	if(!pilot || !current_target)
		ai_state = AI_STATE_IDLE
		return

	if(!is_valid_target(current_target))
		drop_target()
		return

	var/dist = get_dist(pilot, current_target)
	if(dist > AI_XENO_RANGED_PREFERRED_DISTANCE + 2)
		ai_state = AI_STATE_APPROACHING
		return

	var/datum/action/xeno_action/ability = get_ranged_ability()
	if(!ability)
		if(pilot.Adjacent(current_target))
			execute_attack(current_target)
		else
			ai_state = AI_STATE_APPROACHING
		return

	pilot.setDir(get_dir(pilot, current_target))
	ability.use_ability(current_target)

/**
 * Spitter - the simplest ranged caste to prove this controller against: one
 * ranged ability, no secondary mechanics.
 */
/datum/xeno_ai_controller/ranged/spitter

/datum/xeno_ai_controller/ranged/spitter/get_ranged_ability()
	return get_ability(/datum/action/xeno_action/activable/xeno_spit/spitter)
