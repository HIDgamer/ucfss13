/**
 * Predalien AI - "could use a face lift in the combat department too." The
 * old AI only ever threw Feral Smash and nothing else, despite a real kit
 * of five offensive/support actions (Predalien.dm's base_actions):
 *
 * - Feral Rush (self speed/armor buff, no target) - popped once at the
 *   start of an engagement rather than never used at all.
 * - Feral Smash (grab-lunge-slam, works from range same as Warrior's
 *   Lunge) - now fired as a gap-closer while still approaching, on top of
 *   its existing use as a hard-hitting finisher once adjacent.
 * - Eviscerate/Devastate (feralfrenzy, single-target by default per
 *   toggle_gut_targeting's initial value) - the actual biggest finisher in
 *   the kit, immobilizes both her and the target for a windup then deals
 *   heavy damage; preferred over a plain Feral Smash reuse once adjacent.
 * - Predalien Roar (AoE debuff on nearby humans + a stacking buff for
 *   nearby same-hive xenos) - fired opportunistically on engagement, cheap
 *   value that cost nothing to add.
 * - Tail Stab - the plain melee fallback once everything else is on
 *   cooldown, instead of a bare claw swing.
 */
/datum/xeno_ai_controller/predalien

/datum/xeno_ai_controller/predalien/process_movement()
	if(!pilot || !current_target)
		return
	if(!is_valid_target(current_target))
		drop_target()
		return

	last_seen_turf = get_turf(current_target)
	attempt_feral_rush()
	attempt_roar()

	if(get_dist(pilot, current_target) <= 1 && pilot.Adjacent(current_target))
		ai_state = AI_STATE_ATTACKING
		blocked_attempts = 0
		path_queue = null
		return

	var/datum/action/xeno_action/activable/feral_smash/smash = get_ability(/datum/action/xeno_action/activable/feral_smash)
	if(smash && smash.action_cooldown_check() && get_dist(pilot, current_target) <= smash.grab_range && has_line_of_sight(current_target, physical_path = TRUE))
		smash.use_ability(current_target)
		return

	return ..()

/// Self-buff, no target needed - fires once per cooldown rather than never at all.
/datum/xeno_ai_controller/predalien/proc/attempt_feral_rush()
	var/datum/action/xeno_action/onclick/feralrush/rush = get_ability(/datum/action/xeno_action/onclick/feralrush)
	if(!rush || !rush.action_cooldown_check())
		return FALSE
	rush.use_ability(pilot)
	return TRUE

/// AoE debuff/support - opportunistic, no real downside to firing it the moment it's off cooldown while a fight's on.
/datum/xeno_ai_controller/predalien/proc/attempt_roar()
	var/datum/action/xeno_action/onclick/predalien_roar/roar = get_ability(/datum/action/xeno_action/onclick/predalien_roar)
	if(!roar || !roar.action_cooldown_check())
		return FALSE
	roar.use_ability(pilot)
	return TRUE

/datum/xeno_ai_controller/predalien/use_caste_ability(mob/living/target)
	var/datum/action/xeno_action/activable/feralfrenzy/frenzy = get_ability(/datum/action/xeno_action/activable/feralfrenzy)
	if(frenzy && frenzy.action_cooldown_check())
		frenzy.use_ability(target)
		return TRUE

	var/datum/action/xeno_action/activable/feral_smash/smash = get_ability(/datum/action/xeno_action/activable/feral_smash)
	if(smash && smash.action_cooldown_check())
		smash.use_ability(target)
		return TRUE

	return attempt_tail_stab(target)
