/**
 * Queen AI - fundamentally different from every other caste's controller:
 * her default loop is hive economy (grow/maintain an ovipositor for larva
 * production), not chase-and-attack. She only drops into the shared
 * combat loop (via ..() -> the base tick()'s normal state machine) when a
 * threat is actually visible, matching the user's design: "if the hive is
 * under heavy attack she would assist if all other conditions such as the
 * hive not needing eggs or anything else check out."
 *
 * Known interim simplification: "heavy attack" is currently just "any
 * hostile within her normal scan radius" (the same process_target() every
 * other caste uses) - there's no separate "hive under attack" signal yet
 * (e.g. other xenos reporting damage taken). Egg/larva-economy need is also
 * not yet weighed - she always tries to mount when safe, rather than
 * checking whether the hive actually needs more larva right now. Both are
 * reasonable follow-ups once this base loop is proven in a real round.
 */
/datum/xeno_ai_controller/queen

// No /proc/ keyword - overriding the base tick(), which itself overrides
// /datum/proc/process(delta_time) (see xeno_ai_controller.dm's own note on
// this). Deliberately does not call ..() at the top the way a normal
// override might - the Queen's decision loop replaces the base one, only
// falling through to it (via explicit ..() calls below) once she's
// committed to fighting.
/datum/xeno_ai_controller/queen/tick()
	var/mob/living/carbon/xenomorph/queen/queen_pilot = pilot
	if(!istype(queen_pilot))
		return

	// Keep scanning for danger even while mounted (immobilized) - the one
	// exception to the base tick()'s "incapacitated means do nothing"
	// shortcut, since a mounted Queen still needs to notice a threat in
	// order to decide to dismount.
	if(!current_target)
		process_target()

	if(queen_pilot.ovipositor)
		if(current_target)
			queen_pilot.dismount_ovipositor(TRUE) // TRUE = instant, no confirmation dialog, no player-facing channel - she needs to be able to react immediately, not wait through the flavor animation a player would.
		return // Otherwise stay mounted and do nothing else this tick - TRAIT_IMMOBILIZED already prevents movement/attack.

	if(queen_pilot.is_mob_incapacitated() || HAS_TRAIT(queen_pilot, TRAIT_IMMOBILIZED))
		return

	if(current_target)
		return ..() // Hand off to the shared approach/attack/leash state machine - she defends herself and the hive normally once committed.

	if(should_flee())
		return ..() // Critically wounded/on fire - let the base flee-and-resist logic run even though she's not mounted.

	attempt_mount_ovipositor(queen_pilot)
	if(!queen_pilot.ovipositor) // Mount attempt failed (not on hive weeds, on cooldown, etc.) or is still channeling - patrol instead of standing frozen.
		patrol()

/// Calls the real grow_ovipositor ability directly - reuses all of its existing validation (hive-owned weeds, plasma cost, cooldown, not-in-interior) rather than reimplementing any of it.
/datum/xeno_ai_controller/queen/proc/attempt_mount_ovipositor(mob/living/carbon/xenomorph/queen/queen_pilot)
	if(queen_pilot.ovipositor)
		return
	var/datum/action/xeno_action/onclick/grow_ovipositor/action = get_ability(/datum/action/xeno_action/onclick/grow_ovipositor)
	if(!action)
		return
	action.use_ability(queen_pilot)
