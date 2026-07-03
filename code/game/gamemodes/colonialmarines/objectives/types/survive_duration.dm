/**
 * Trivial first objective type, used to validate the mission controller's
 * chaining/announcement plumbing end-to-end before building anything more
 * elaborate (FOB entity, generalized wave defense, etc.) on top of it. Not
 * meant to be the final objective pool - see the Stage 2 design's example
 * mission flow (establish FOB, restore comms, recover documents, etc.) for
 * what the real pool should eventually contain.
 */
/datum/mission_objective/survive_duration
	name = "Hold The Line"
	description = "Xenomorph activity detected in the area. Marines are to hold their current position and repel all hostiles."
	weight = 1
	/// How long marines need to survive, in world.time deltas.
	var/duration = 5 MINUTES

/datum/mission_objective/survive_duration/check_complete()
	var/scaled_duration = duration * (controller?.difficulty_multiplier || 1)
	return (world.time - started_at) >= scaled_duration

/datum/mission_objective/survive_duration/check_failed()
	if(..())
		return TRUE
	if(!istype(SSticker.mode, /datum/game_mode/colonialmarines))
		return FALSE
	var/datum/game_mode/colonialmarines/mode = SSticker.mode
	var/list/living_counts = mode.count_humans_and_xenos(SSmapping.levels_by_trait(ZTRAIT_GROUND))
	var/num_humans = living_counts[1]
	return !num_humans // No marines left groundside - nothing left to hold the line with.

/datum/mission_objective/survive_duration/on_complete()
	announce_progress("Hostile activity has quieted. Good work, marines.")
	..()
