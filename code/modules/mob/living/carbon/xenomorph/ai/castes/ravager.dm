/**
 * Ravager AI - the hive's mobile bruiser: no innate dodge/evasion actually
 * exists on the base caste (evasion = XENO_EVASION_NONE, confirmed against
 * Xenomorph.dm's recalculate_evasion() and projectile.dm's hit-chance
 * calc), so "nimble and good at dodging" per the user's original design
 * is built here as a behavior instead of a stat: a Ravager sidesteps to a
 * flanking tile after most attacks rather than trading blows standing
 * still like every other melee caste, and prefers its multi-target
 * abilities over a plain swing whenever a fight is worth escalating.
 * Patrol/search behavior is entirely inherited from the base controller.
 *
 * - While closing on a target still out of melee range, fires Charge to
 *   dash in instead of walking the whole distance - same reasoning as
 *   crusher.dm, just a shorter-range dash (Ravager's Charge distance is
 *   5, versus the Crusher's 9).
 * - Sweeps with Scissor Cut (a frontal line attack reaching several tiles
 *   ahead) instead of a plain melee swing whenever more than one valid
 *   target is nearby, so a Ravager fighting a cluster hits several of
 *   them in one motion rather than only the one it's facing.
 * - Arms Empower when several hostiles are nearby at once (a real group
 *   fight, e.g. an LZ siege) rather than every engagement - Empower's
 *   payoff scales with how many enemies are close when it resolves, so
 *   using it in a 1-on-1 would waste most of its value. Once armed, its
 *   own built-in timeout auto-resolves it a few seconds later (see
 *   empower/timeout() in Ravager.dm) - the AI doesn't need to remember to
 *   fire it a second time itself.
 * - After landing an attack, has a chance to sidestep to a flanking tile
 *   instead of standing in place - a Ravager should look like it's
 *   circling its prey, not slugging it out toe-to-toe.
 *
 * Known interim simplification: the repositioning step is a plain
 * probability roll, not a real "am I about to get hit back" read - a
 * smarter reactive dodge (e.g. sidestepping specifically when a marine
 * takes aim) is a reasonable follow-up once this is proven in a real
 * round.
 */
/datum/xeno_ai_controller/ravager

/**
 * Same duplication tradeoff as crusher.dm - the "close in" trigger
 * condition (attempt a dash first) differs enough from the base melee
 * approach that this is a full override rather than a shared helper.
 */
/datum/xeno_ai_controller/ravager/process_movement()
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
/datum/xeno_ai_controller/ravager/proc/attempt_charge(atom/target)
	var/datum/action/xeno_action/activable/pounce/charge/charge = get_ability(/datum/action/xeno_action/activable/pounce/charge)
	if(!charge || !charge.action_cooldown_check())
		return FALSE
	if(get_dist(pilot, target) > charge.distance)
		return FALSE
	charge.use_ability(target)
	return TRUE

/**
 * Prefers Scissor Cut (hits everything in a line several tiles ahead)
 * over a plain melee swing whenever more than one valid target is
 * nearby, then considers arming Empower when a real group fight is
 * happening. Falls through to the inherited single-target melee whenever
 * neither condition is met (the common case: a normal 1-on-1).
 */
/datum/xeno_ai_controller/ravager/use_caste_ability(mob/living/target)
	if(!pilot)
		return FALSE

	var/datum/action/xeno_action/activable/scissor_cut/cut = get_ability(/datum/action/xeno_action/activable/scissor_cut)
	if(cut && cut.action_cooldown_check())
		var/nearby_targets = 0
		for(var/mob/living/carbon/nearby in orange(4, pilot))
			if(!is_valid_target(nearby))
				continue
			nearby_targets++
			if(nearby_targets >= AI_RAVAGER_SCISSOR_MIN_TARGETS)
				break
		if(nearby_targets >= AI_RAVAGER_SCISSOR_MIN_TARGETS)
			cut.use_ability(target)
			return TRUE

	var/datum/action/xeno_action/onclick/empower/empower = get_ability(/datum/action/xeno_action/onclick/empower)
	if(empower && !empower.activated_once && empower.action_cooldown_check())
		var/hostiles_nearby = 0
		for(var/mob/living/carbon/nearby in orange(empower.empower_range, pilot))
			if(!is_valid_target(nearby))
				continue
			hostiles_nearby++
			if(hostiles_nearby >= AI_RAVAGER_EMPOWER_MIN_TARGETS)
				break
		if(hostiles_nearby >= AI_RAVAGER_EMPOWER_MIN_TARGETS)
			empower.use_ability(pilot)
			return TRUE

	return FALSE

/**
 * Adds a post-attack flanking step on top of the base attack handling -
 * this is the "nimble" half of the caste's identity, independent of
 * whichever ability (or plain melee) actually landed above.
 */
/datum/xeno_ai_controller/ravager/process_attack()
	. = ..()
	if(!pilot || !current_target || ai_state != AI_STATE_ATTACKING)
		return // Target died/escaped/moved out of melee range during the attack above - nothing to flank around.
	if(!prob(AI_RAVAGER_REPOSITION_CHANCE))
		return
	var/target_dir = get_dir(pilot, current_target)
	step(pilot, pick(turn(target_dir, 90), turn(target_dir, -90)))
