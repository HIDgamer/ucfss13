/**
 * King AI - the Yautja-hive counterpart to Queen: a solo tier-4 boss, not a
 * population-scale caste, so (like Queen) he gets real per-tick reasoning
 * instead of the simpler population-budget logic every other caste uses.
 *
 * - Rend is cheap and short-cooldown (2.5s) - used as the default option
 *   over a plain claw whenever it's off cooldown, not gated on anything.
 * - Doom (AoE daze/blind/slow, 45s CD) and Destroy (huge-damage AoE slam,
 *   60s CD) used to be reserved for 2+ nearby targets on the theory that
 *   either would "waste most of their value" on a lone target - false for
 *   both (Destroy's damage number doesn't care how many mobs it hit, and
 *   dazing/slowing even one marine solo is a big setup for the follow-up),
 *   and since most engagements are actually 1v1, that gate meant "does not
 *   use its abilities well at all" - he'd sit on Rend alone almost every
 *   fight. Now used on cooldown against any live target. Destroy is
 *   preferred over Doom when both are available, since it's the bigger
 *   payoff.
 *
 * Proactively pops King Shield (a party-wide damage-cap buff) once he's
 * actually taking a beating - see attempt_shield() - rather than only ever
 * using his offensive kit and going down without ever bolstering himself or
 * nearby daughters.
 *
 * "Coordination with other AI xenos is very poor" - King never broadcast a
 * hive alert or escort call the way Queen does, so other AI xenos never
 * rallied to a fight he was personally in. broadcast_hive_alert()/
 * broadcast_escort_call() are shared base-controller procs (promoted off
 * Queen's controller, xeno_ai_controller.dm) - process_target()/
 * process_attack() below call them the same way Queen's own tick() does,
 * just without needing King to override the whole state machine the way
 * she does (he has no economy/command loop of his own to layer on top of).
 */
/datum/xeno_ai_controller/king
	/// Last applied update_enrage() damage bonus - re-applied by delta each call so it never stacks past what the current health fraction actually justifies.
	var/last_enrage_bonus = 0

/// "King needs a face lift as well in the combat department and pathfinding" - he's the same kind of one-per-round solo boss as Queen but had no New() override at all, leaving him on the flat population-default attack/return radius instead of a boss-scale one.
/datum/xeno_ai_controller/king/New(mob/living/carbon/xenomorph/new_pilot)
	. = ..()
	attack_distance = AI_KING_ATTACK_DISTANCE
	return_distance = AI_KING_RETURN_DISTANCE

/// Destroy (King.dm) self-immobilizes for its leap windup - King.dm uses a bare "Destroy" string as the trait source, not the TRAIT_SOURCE_ABILITY() macro, so this has to match that literally rather than reusing the macro like every other override does.
/datum/xeno_ai_controller/king/can_act_while_immobilized()
	if(..())
		return TRUE
	return HAS_TRAIT_FROM_ONLY(pilot, TRAIT_IMMOBILIZED, "Destroy")

/// Exactly as hard to replace as Queen (one-per-round investment) - mirrors AI_QUEEN_FLEE_HEALTH_PERCENT, which he never had a matching override for before Phase 3.
/datum/xeno_ai_controller/king/get_flee_threshold()
	return AI_KING_FLEE_HEALTH_PERCENT

/// Broadcasts the instant he acquires a target, same as Queen's own tick() does for her - other AI xenos don't have to wait for him to already be swinging before they hear about it.
/datum/xeno_ai_controller/king/process_target()
	. = ..()
	if(current_target)
		broadcast_hive_alert(pilot)
		broadcast_escort_call(pilot, FALSE)

/// Keeps refreshing both broadcasts every attack tick, same as Queen's tick() does every tick she has a live target - so the alert/escort call stay fresh for as long as he's actually fighting.
/datum/xeno_ai_controller/king/process_attack()
	if(current_target)
		broadcast_hive_alert(pilot)
		broadcast_escort_call(pilot, FALSE)
		attempt_periodic_combat_pheromones()
	return ..()

// Closes distance with Destroy (a ~7-tile leap) before falling back to plain walking -
// use_caste_ability() is only reached once already melee-adjacent otherwise.
/datum/xeno_ai_controller/king/process_movement()
	if(!pilot || !current_target)
		return ..()
	if(!is_valid_target(current_target))
		drop_target()
		return
	if(get_dist(pilot, current_target) > 1 && attempt_destroy_leap(current_target))
		return
	return ..()

/// Fires Destroy at target if it's off cooldown and within leap range; returns FALSE (and does nothing else) otherwise, so the caller falls back to plain walking - same shape as every other dash-capable caste's own attempt_*() gap-closer.
/datum/xeno_ai_controller/king/proc/attempt_destroy_leap(atom/target)
	var/datum/action/xeno_action/activable/destroy/destroy = get_ability(/datum/action/xeno_action/activable/destroy)
	if(!destroy || !destroy.action_cooldown_check())
		return FALSE
	if(get_dist(pilot, target) > destroy.range)
		return FALSE
	if(!has_line_of_sight(target, physical_path = TRUE))
		return FALSE
	destroy.use_ability(target)
	return TRUE

/datum/xeno_ai_controller/king/use_caste_ability(mob/living/target)
	if(!pilot)
		return FALSE

	attempt_shield() // Side effect only (its own independent cooldown/plasma cost) - never blocks also using an offensive ability the same tick below.
	update_enrage() // Side effect only - see its own doc comment.

	var/datum/action/xeno_action/activable/destroy/destroy = get_ability(/datum/action/xeno_action/activable/destroy)
	if(destroy && destroy.action_cooldown_check())
		destroy.use_ability(pilot)
		return TRUE

	var/datum/action/xeno_action/activable/doom/doom = get_ability(/datum/action/xeno_action/activable/doom)
	if(doom && doom.action_cooldown_check())
		doom.use_ability(target)
		return TRUE

	// Rend only fires once 2+ valid targets are adjacent (far weaker single-target DPS than a plain
	// claw), matching the AoE-priority pattern other multi-target castes (Crusher/Predalien/Ravager/
	// Lurker/Warrior) use.
	var/nearby_targets = 0
	for(var/mob/living/carbon/nearby in orange(1, pilot))
		if(!is_valid_target(nearby))
			continue
		nearby_targets++
		if(nearby_targets >= 2)
			break
	var/datum/action/xeno_action/onclick/rend/rend = get_ability(/datum/action/xeno_action/onclick/rend)
	if(nearby_targets >= 2 && rend && rend.action_cooldown_check())
		rend.use_ability(pilot)
		return TRUE

	// King grants tail_stab (King.dm) but was silently falling through to
	// plain melee whenever Destroy/Doom/Rend were all on cooldown - Queen
	// already does this exact fallback (queen.dm).
	return attempt_tail_stab(target)

/**
 * Berserk/enrage - "a creature of destruction" should get MORE dangerous as he's dying, not just
 * weaker like every other caste. Scales his melee/Rend damage upward the lower his health drops
 * (missing-health fraction, not damage dealt - unlike Despoiler's hypertension system this mirrors
 * architecturally), re-applying damage_modifier only by the delta since the last check so repeated
 * calls across a fight don't stack indefinitely. Self-corrects back down if he heals - AI-only,
 * since this only ever runs from the AI controller's own use_caste_ability(), never touched by a
 * player-piloted King.
 */
/datum/xeno_ai_controller/king/proc/update_enrage()
	if(!pilot || !pilot.maxHealth || !pilot.caste)
		return
	var/missing_fraction = 1 - (pilot.health / pilot.maxHealth)
	var/base_damage = (pilot.caste.melee_damage_lower + pilot.caste.melee_damage_upper) * 0.5
	var/desired_bonus = round(base_damage * missing_fraction * AI_KING_ENRAGE_DAMAGE_FRACTION)
	if(desired_bonus == last_enrage_bonus)
		return
	pilot.damage_modifier += (desired_bonus - last_enrage_bonus)
	last_enrage_bonus = desired_bonus
	pilot.recalculate_damage()

/// Pops King Shield once he's actually taking a beating (below half health) - the same "is the fight bad enough" bar crusher.dm's own attempt_shield() uses, not just whenever it happens to be off cooldown.
/datum/xeno_ai_controller/king/proc/attempt_shield()
	if(!pilot || !pilot.maxHealth || (pilot.health / pilot.maxHealth) >= 0.5)
		return FALSE
	var/datum/action/xeno_action/onclick/king_shield/shield = get_ability(/datum/action/xeno_action/onclick/king_shield)
	if(!shield || !shield.action_cooldown_check())
		return FALSE
	shield.use_ability(pilot)
	return TRUE
