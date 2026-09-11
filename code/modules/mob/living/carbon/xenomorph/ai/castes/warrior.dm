/**
 * Warrior AI - a heavy melee brawler: closes with Lunge (a grab-range
 * closer, not a pounce-style throw) instead of walking the whole distance,
 * then prefers Punch (can fracture/target limbs) over a plain claw once
 * engaged, falling through to Tail Stab as a follow-up hit whenever Punch
 * itself is still on cooldown - "use its punch ability with its other
 * lunge ability and follow ups" - instead of a bare claw the instant Punch
 * isn't up. Patrol/search behavior is entirely inherited from the base
 * controller.
 */
/datum/xeno_ai_controller/warrior
	/// Rotational direction (90 or -90) this Warrior always sidesteps toward - same reasoning as ravager.dm's identical var, picked once so repositioning reads as one consistent circling motion.
	var/circle_dir
	/// pilot.health as of the last process_attack() call - lets the reposition check tell "just got hit, this is a reactive dodge" from "nothing happened, this is just the baseline roll," same pattern as ravager.dm.
	var/last_known_health

/datum/xeno_ai_controller/warrior/New(mob/living/carbon/xenomorph/new_pilot)
	. = ..()
	circle_dir = pick(90, -90)

/**
 * Same duplication tradeoff as crusher.dm/ravager.dm/runner.dm - attempting
 * Lunge before falling through to the inherited approach chain differs
 * enough from the base melee policy to warrant a full override.
 */
/datum/xeno_ai_controller/warrior/process_movement()
	if(!pilot || !current_target)
		disengage_plates_if_idle()
		return

	if(!is_valid_target(current_target))
		drop_target()
		return

	note_last_seen(get_turf(current_target), current_target)

	if(get_dist(pilot, current_target) <= 1 && pilot.Adjacent(current_target))
		ai_state = AI_STATE_ATTACKING
		blocked_attempts = 0
		path_queue = null
		return

	if(attempt_lunge(current_target))
		return

	// Bulwark strain replaces Lunge with Plate Bash - get_ability() is null for whichever of the
	// two the pilot's actual strain doesn't grant, so at most one of these two calls ever fires.
	if(attempt_plate_bash(current_target))
		return

	return ..()

/// Fires Lunge at target if it's off cooldown and within grab range; returns FALSE (and does nothing else) otherwise, so the caller falls back to the inherited approach/pathfinding chain.
/datum/xeno_ai_controller/warrior/proc/attempt_lunge(atom/target)
	var/datum/action/xeno_action/activable/lunge/lunge = get_ability(/datum/action/xeno_action/activable/lunge)
	if(!lunge || !lunge.action_cooldown_check())
		return FALSE
	if(get_dist(pilot, target) > lunge.grab_range)
		return FALSE
	if(!has_line_of_sight(target, physical_path = TRUE)) // A lunge is a physical throw - tables/fences/barricades block it same as a wall would, same fix already applied to every other dash-type ability.
		return FALSE
	lunge.use_ability(target)
	return TRUE

/**
 * Fling (a knockback/stun/slow, adjacency-required) was granted but never
 * called anywhere - tried first as a crowd-control peel when 2+ valid
 * targets are already adjacent (same nearby-count-scan shape as crusher.dm's
 * Stomp check), before Punch/Tail Stab's normal single-target rotation.
 */
/datum/xeno_ai_controller/warrior/use_caste_ability(mob/living/target)
	// Bulwark-only from here down - manage_plate_stance()/attempt_reflective_shield()/
	// attempt_tail_swing() all no-op via their own get_ability() checks for a base Warrior
	// (toggle_plates/reflective_shield/tail_swing were never granted), so this is safe to call
	// unconditionally rather than branching on strain type.
	manage_plate_stance() // Side effect only - see its own doc comment.

	if(attempt_reflective_shield())
		return TRUE
	if(attempt_tail_swing())
		return TRUE

	if(attempt_fling(target))
		return TRUE

	// Bulwark strain replaces Punch with Plate Bash as her adjacent single-target option.
	if(attempt_plate_bash(target))
		return TRUE

	var/datum/action/xeno_action/activable/warrior_punch/punch = get_ability(/datum/action/xeno_action/activable/warrior_punch)
	if(punch && punch.action_cooldown_check())
		punch.use_ability(target)
		return TRUE
	return attempt_tail_stab(target)

/// Only worth the knockback when actually surrounded - a lone target is better handled by Punch/Tail Stab's straight damage.
/datum/xeno_ai_controller/warrior/proc/attempt_fling(mob/living/target)
	if(!pilot || !target)
		return FALSE
	var/datum/action/xeno_action/activable/fling/fling = get_ability(/datum/action/xeno_action/activable/fling)
	if(!fling || !fling.action_cooldown_check())
		return FALSE
	if(!pilot.Adjacent(target))
		return FALSE
	var/nearby_targets = 0
	for(var/mob/living/carbon/nearby in orange(1, pilot))
		if(!is_valid_target(nearby))
			continue
		nearby_targets++
		if(nearby_targets >= 2)
			break
	if(nearby_targets < 2)
		return FALSE
	fling.use_ability(target)
	return TRUE

//
// Bulwark strain - each get_ability() lookup below returns null for a base Warrior (the strain
// removes warrior_punch/lunge/fling and grants these four in exchange, bulwark.dm), so every proc
// here degrades to a safe no-op unless the pilot actually has the strain, same pattern already
// established by crusher.dm's Charger/defender.dm's Steelcrest wiring.
//

/**
 * Plates trade damage output/tackle efficiency/speed for armor and knockback immunity - not worth
 * leaving up permanently, same shape as defender.dm's manage_crest_defense(). Raises them once
 * actually fighting a gun-carrying human (the specific threat her directional armor is built to
 * soak) or once 2+ valid targets are already adjacent, lowers them once neither condition holds so
 * she isn't perpetually damage-reduced finishing off a lone unarmed straggler.
 */
/datum/xeno_ai_controller/warrior/proc/manage_plate_stance()
	if(!pilot)
		return
	var/mob/living/carbon/xenomorph/xeno_pilot = pilot
	var/datum/action/xeno_action/onclick/toggle_plates/plates = get_ability(/datum/action/xeno_action/onclick/toggle_plates)
	if(!plates || !plates.action_cooldown_check())
		return

	var/facing_threat = FALSE
	if(current_target && ishuman(current_target))
		var/mob/living/carbon/human/human_target = current_target
		if(istype(human_target.get_active_hand(), /obj/item/weapon/gun))
			facing_threat = TRUE
	if(!facing_threat)
		var/nearby_targets = 0
		for(var/mob/living/carbon/nearby in orange(1, pilot))
			if(!is_valid_target(nearby))
				continue
			nearby_targets++
			if(nearby_targets >= 2)
				facing_threat = TRUE
				break

	if(facing_threat && !HAS_TRAIT(xeno_pilot, TRAIT_ABILITY_ENCLOSED_PLATES))
		plates.use_ability()
	else if(!facing_threat && HAS_TRAIT(xeno_pilot, TRAIT_ABILITY_ENCLOSED_PLATES))
		plates.use_ability()

/// Plates left up after combat ends would leave her permanently damage-reduced/slower while just patrolling - lower them once there's nothing left to actually brace against, same reasoning defender.dm's un-fortify-to-reposition follows for its own toggle stance.
/datum/xeno_ai_controller/warrior/proc/disengage_plates_if_idle()
	if(!pilot)
		return
	var/mob/living/carbon/xenomorph/xeno_pilot = pilot
	if(!HAS_TRAIT(xeno_pilot, TRAIT_ABILITY_ENCLOSED_PLATES))
		return
	var/datum/action/xeno_action/onclick/toggle_plates/plates = get_ability(/datum/action/xeno_action/onclick/toggle_plates)
	if(plates && plates.action_cooldown_check())
		plates.use_ability()

/// Her Lunge/Punch replacement - closes up to 2 tiles (throwing her at the target when not yet encased) or, while encased, launches the target away and knocks it down instead. Same range-and-line-of-sight guard shape as attempt_lunge().
/datum/xeno_ai_controller/warrior/proc/attempt_plate_bash(atom/target)
	if(!pilot || !target)
		return FALSE
	var/datum/action/xeno_action/activable/plate_bash/bash = get_ability(/datum/action/xeno_action/activable/plate_bash)
	if(!bash || !bash.action_cooldown_check())
		return FALSE
	if(get_dist(pilot, target) > 2)
		return FALSE
	if(!has_line_of_sight(target, physical_path = TRUE))
		return FALSE
	bash.use_ability(target)
	return TRUE

/**
 * Anti-bullet stance, only usable while already encased - only worth raising against an actual
 * gun-carrying human target, and only while not already active (its own use_ability() toggles OFF
 * if called while active, so calling this every tick while up would immediately cancel it).
 */
/datum/xeno_ai_controller/warrior/proc/attempt_reflective_shield()
	if(!pilot)
		return FALSE
	var/mob/living/carbon/xenomorph/xeno_pilot = pilot
	if(!HAS_TRAIT(xeno_pilot, TRAIT_ABILITY_ENCLOSED_PLATES) || HAS_TRAIT(xeno_pilot, TRAIT_ABILITY_REFLECTIVE_PLATES))
		return FALSE
	var/datum/action/xeno_action/onclick/reflective_shield/shield = get_ability(/datum/action/xeno_action/onclick/reflective_shield)
	if(!shield || !shield.action_cooldown_check())
		return FALSE
	if(!current_target || !ishuman(current_target))
		return FALSE
	var/mob/living/carbon/human/human_target = current_target
	if(!istype(human_target.get_active_hand(), /obj/item/weapon/gun))
		return FALSE
	shield.use_ability()
	return TRUE

/**
 * AoE trip around herself, or a grenade deflect - breaks her own Plates/Reflective stance when
 * used (tail_swing.dm's use_ability()), so only worth it when it actually earns that cost: 2+
 * valid targets already adjacent, or an incoming grenade nearby to punt away.
 */
/datum/xeno_ai_controller/warrior/proc/attempt_tail_swing()
	if(!pilot)
		return FALSE
	var/datum/action/xeno_action/onclick/tail_swing/swing = get_ability(/datum/action/xeno_action/onclick/tail_swing)
	if(!swing || !swing.action_cooldown_check())
		return FALSE

	var/nearby_targets = 0
	for(var/mob/living/carbon/nearby in orange(swing.swing_range, pilot))
		if(!is_valid_target(nearby))
			continue
		nearby_targets++
		if(nearby_targets >= 2)
			break

	var/grenade_nearby = FALSE
	if(nearby_targets < 2)
		for(var/obj/item/explosive/grenade/grenade in orange(swing.swing_range, get_turf(pilot)))
			grenade_nearby = TRUE
			break

	if(nearby_targets < 2 && !grenade_nearby)
		return FALSE
	swing.use_ability()
	return TRUE

/// Warrior had no post-attack repositioning at all - same damage-reactive-plus-baseline-roll shape as ravager.dm's own circle-step.
/datum/xeno_ai_controller/warrior/get_flee_threshold()
	return AI_WARRIOR_FLEE_HEALTH_PERCENT

/datum/xeno_ai_controller/warrior/process_attack()
	. = ..()
	if(!pilot || !current_target || ai_state != AI_STATE_ATTACKING)
		last_known_health = pilot?.health
		return
	var/took_damage = (last_known_health != null) && (pilot.health < last_known_health)
	last_known_health = pilot.health
	if(!took_damage && !prob(AI_WARRIOR_REPOSITION_CHANCE))
		return
	var/target_dir = get_dir(pilot, current_target)
	if(!ai_step(turn(target_dir, circle_dir)))
		ai_step(turn(target_dir, -circle_dir))
