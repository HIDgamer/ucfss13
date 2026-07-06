/**
 * Defender AI - a stationary chokepoint tank rather than a chaser
 * (can_vent_crawl = 0, built around Fortify's big armor/explosive buff
 * while anchored in place). Patrol/search/movement are entirely inherited
 * from the base melee controller - only the attack decision differs:
 *
 * - Tail Sweep (a short AoE knockback) instead of a plain swing whenever
 *   more than one valid target is already adjacent, same threshold pattern
 *   as Crusher's Stomp.
 * - Fortify once actually engaged and not already anchored - she's meant
 *   to plant herself and hold, not fortify while still mid-chase (Fortify
 *   immobilizes her, so this only fires once adjacent/attacking).
 * - Headbutt (knockback + damage) as the default single-target option
 *   once neither of the above applies, since usable_while_fortified is
 *   only guaranteed on the steel_crest strain variant - falls through to
 *   plain melee if it's not off cooldown.
 *
 * Un-fortifies to reposition once the target's no longer adjacent instead of
 * staying planted uselessly (see process_attack() override) - Fortify sets
 * TRAIT_IMMOBILIZED, which used to hit the base tick()'s generic stun/
 * knockdown freeze check every single tick while fortified, meaning a
 * fortified Defender could never attack OR un-root herself again once the
 * fight moved out of reach - the ability effectively bricked her AI for the
 * rest of the round. can_act_while_immobilized() below carves out the
 * exception so she can still act while deliberately planted.
 */
/datum/xeno_ai_controller/defender

/// Fortify is a deliberate, voluntary immobilize - she's still meant to fight (and, per process_attack() below, un-root) from where she's planted, unlike an ordinary stun/knockdown.
/datum/xeno_ai_controller/defender/can_act_while_immobilized()
	var/mob/living/carbon/xenomorph/xeno_pilot = pilot
	return istype(xeno_pilot) && xeno_pilot.fortify

/**
 * If the target's wandered out of melee range while she's fortified, staying
 * planted accomplishes nothing - un-fortify first so the base process_attack()'s
 * own Adjacent check below can transition her to APPROACHING and she can
 * actually move again next tick (Fortify also sets anchored = TRUE, which
 * blocks movement outright until this runs).
 */
/datum/xeno_ai_controller/defender/process_attack()
	var/mob/living/carbon/xenomorph/xeno_pilot = pilot
	if(istype(xeno_pilot) && xeno_pilot.fortify && current_target && !pilot.Adjacent(current_target))
		var/datum/action/xeno_action/activable/fortify/fortify = get_ability(/datum/action/xeno_action/activable/fortify)
		fortify?.use_ability(pilot) // Toggles off - see Defender.dm's use_ability().
	return ..()

/datum/xeno_ai_controller/defender/use_caste_ability(mob/living/target)
	if(!pilot)
		return FALSE
	var/mob/living/carbon/xenomorph/xeno_pilot = pilot

	var/datum/action/xeno_action/onclick/tail_sweep/sweep = get_ability(/datum/action/xeno_action/onclick/tail_sweep)
	if(sweep && sweep.action_cooldown_check())
		var/nearby_targets = 0
		for(var/mob/living/carbon/nearby in orange(1, pilot))
			if(!is_valid_target(nearby))
				continue
			nearby_targets++
			if(nearby_targets >= AI_DEFENDER_SWEEP_MIN_TARGETS)
				break
		if(nearby_targets >= AI_DEFENDER_SWEEP_MIN_TARGETS)
			sweep.use_ability(pilot)
			return TRUE

	var/datum/action/xeno_action/activable/fortify/fortify = get_ability(/datum/action/xeno_action/activable/fortify)
	if(fortify && !xeno_pilot.fortify && !xeno_pilot.crest_defense && fortify.action_cooldown_check())
		fortify.use_ability(target)
		return TRUE

	var/datum/action/xeno_action/activable/headbutt/headbutt = get_ability(/datum/action/xeno_action/activable/headbutt)
	if(headbutt && headbutt.action_cooldown_check())
		headbutt.use_ability(target)
		return TRUE

	return FALSE
