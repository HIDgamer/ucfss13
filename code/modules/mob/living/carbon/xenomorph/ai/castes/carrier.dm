/**
 * Carrier AI - pure logistics/support (throws facehuggers/eggs at range,
 * no offensive ability beyond a plain tail_stab per Carrier.dm), MOB_SIZE_BIG
 * and slow off weeds, no vent-crawl. Not built to fight or to run, so the
 * only sensible AI treatment is to disengage sooner than the population
 * default rather than trading blows she has no real tools to win.
 *
 * Proactively throws a stored facehugger at a target while still closing
 * distance (see process_movement()/attempt_hugger_throw()) instead of never
 * using her signature tool at all - has to happen during the approach, not
 * from the usual use_caste_ability() hook, since that only fires once
 * already adjacent and a thrown hugger needs real distance to be worth
 * using over just letting her walk up. Throwing is a real two-step
 * interaction even for a player (empty hand grabs one from storage, a
 * second throw actually launches it) - this plays out over two AI ticks the
 * same way, rather than trying to special-case both steps into one call.
 */
/datum/xeno_ai_controller/carrier

/datum/xeno_ai_controller/carrier/get_flee_threshold()
	return AI_CARRIER_FLEE_HEALTH_PERCENT

/datum/xeno_ai_controller/carrier/process_movement()
	if(!pilot || !current_target)
		return
	if(is_valid_target(current_target) && get_dist(pilot, current_target) >= 2)
		attempt_hugger_throw(current_target)
	return ..()

/// See the caste doc comment above for why this has to run during the approach rather than through the normal use_caste_ability() hook.
/datum/xeno_ai_controller/carrier/proc/attempt_hugger_throw(mob/living/target)
	if(!pilot || !ishuman(target))
		return FALSE
	var/mob/living/carbon/xenomorph/carrier/carrier_pilot = pilot
	if(!istype(carrier_pilot) || carrier_pilot.threw_a_hugger)
		return FALSE

	var/mob/living/carbon/human/human_target = target
	if(human_target.stat == DEAD)
		return FALSE

	if(get_dist(pilot, target) > 7) // Too far for a realistic throw - let the normal approach close in first.
		return FALSE
	if(!has_line_of_sight(target))
		return FALSE

	var/datum/action/xeno_action/activable/throw_hugger/throw_ability = get_ability(/datum/action/xeno_action/activable/throw_hugger)
	if(!throw_ability)
		return FALSE

	var/obj/item/clothing/mask/facehugger/held = carrier_pilot.get_active_hand()
	if(!istype(held) && carrier_pilot.huggers_cur <= 0)
		return FALSE // Nothing in hand and nothing left in storage - genuinely nothing to throw.

	pilot.setDir(get_dir(pilot, target))
	throw_ability.use_ability(target) // Grabs one from storage into hand if empty-handed, or throws the one already held - see the doc comment above.
	return TRUE

/// "No offensive ability beyond a plain tail_stab" - true, but nothing was actually using even that; a slightly harder hit than a bare claw once she's cornered into melee.
/datum/xeno_ai_controller/carrier/use_caste_ability(mob/living/target)
	return attempt_tail_stab(target)
