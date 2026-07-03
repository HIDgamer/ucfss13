/**
 * Attack execution for xeno_ai_controller. Reuses the real, input-agnostic
 * attack_alien() receiver chain (code/modules/mob/living/carbon/xenomorph/attack_alien.dm)
 * instead of any player-facing UI/ability-click layer - attack_alien() already reads
 * the attacker's a_intent and works identically regardless of whether a client set it.
 */
/datum/xeno_ai_controller/proc/process_attack()
	if(!pilot || !current_target)
		ai_state = AI_STATE_IDLE
		return

	if(!is_valid_target(current_target))
		drop_target()
		return

	if(!pilot.Adjacent(current_target))
		ai_state = AI_STATE_APPROACHING
		return

	execute_attack(current_target)

/**
 * Orientation is only touched here, at the moment of the strike - never polled
 * every tick - per the reference implementation's own performance approach.
 * Branches on target type: living targets go through the full
 * ability/facehugger/melee chain below, while structures (sentry turrets)
 * skip straight to attack_alien() - abilities and facehugger logic don't
 * apply to attacking machinery.
 */
/datum/xeno_ai_controller/proc/execute_attack(atom/movable/target)
	if(!pilot || !target || QDELETED(target))
		return

	pilot.setDir(get_dir(pilot, target))

	if(!isliving(target))
		pilot.a_intent = INTENT_HARM
		target.attack_alien(pilot)
		return

	var/mob/living/living_target = target

	if(use_caste_ability(living_target))
		return

	// Facehuggers don't claw - they climb onto a downed human's face. Reusing the
	// generic melee fallback below would be actively wrong for this caste, not
	// just suboptimal, so it's special-cased here rather than left for the
	// Stage 2+ per-caste audit.
	if(istype(pilot, /mob/living/carbon/xenomorph/facehugger))
		execute_facehugger_hug(living_target)
		return

	pilot.a_intent = INTENT_HARM
	living_target.attack_alien(pilot)

/**
 * Hook point for Stage 2+ caste-specific offensive abilities (see the plan's caste
 * audit, section 2.6): a caste's controller subtype can override this to call a
 * specific /datum/action/xeno_action's use_ability() body directly, bypassing the
 * click/mouse input layer, and return TRUE to skip the plain-melee fallback below.
 * Drone has no offensive ability worth AI-triggering, so this always falls through.
 */
/datum/xeno_ai_controller/proc/use_caste_ability(mob/living/target)
	return FALSE

/**
 * Mirrors the validity checks and windup in Facehugger.dm's UnarmedAttack()/
 * handle_hug() (can only hug a target that's lying down), but skips the
 * click-driven visible_message flavor since nobody needs to read it for an
 * NPC. Calls the same handle_hug() so the actual infection logic is identical
 * to a player-controlled hugger. No-ops (waits adjacent) against a standing
 * target rather than doing anything else - a real hugger has no other attack.
 */
/datum/xeno_ai_controller/proc/execute_facehugger_hug(mob/living/target)
	if(!ishuman(target))
		return
	var/mob/living/carbon/human/human_target = target
	var/mob/living/carbon/xenomorph/facehugger/hugger = pilot
	if(!istype(hugger))
		return
	if(human_target.body_position != LYING_DOWN)
		return
	if(!can_hug(human_target, hugger.hivenumber))
		return
	if(!do_after(hugger, FACEHUGGER_WINDUP_DURATION, INTERRUPT_ALL, BUSY_ICON_HOSTILE, human_target, INTERRUPT_MOVED, BUSY_ICON_HOSTILE))
		return
	if(human_target.body_position != LYING_DOWN || !can_hug(human_target, hugger.hivenumber))
		return
	hugger.handle_hug(human_target)
