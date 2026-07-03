/**
 * "Hive Incursion" - a selectable variant of Distress Signal built around the
 * Stage 1/2 NPC Xenomorph AI work (see code/modules/mob/living/carbon/xenomorph/ai/
 * and code/game/gamemodes/colonialmarines/objectives/). A real, AI-piloted
 * hive already exists and is growing before marines ever land - this
 * subtypes /datum/game_mode/colonialmarines directly so it inherits the
 * entire existing win/loss and hijack chain unchanged; it only adds the
 * initial hive spawn, the ambient-patrol -> hive-alert "contact" trigger, and
 * an additional marine-victory path (completing enough of the procedural
 * objective chain), per the agreed design:
 *
 *   Marines win if: the hive is wiped (existing MODE_INFESTATION_M_MAJOR path,
 *   untouched) OR enough procedural objectives are completed (new, this file).
 *   Xenos win via the existing hijack chain, completely unchanged: marines
 *   pushed off/wiped/forced to evac -> hive boards the dropship -> crash-lands
 *   on the Almayer -> search-and-destroy.
 *
 * Known interim limitation: the initial Queen is piloted by the same generic
 * Stage 1 melee/patrol controller as every other AI xeno for now. The real
 * command/economy Queen AI (lay eggs, direct drones, only personally fight
 * when the hive is under heavy threat and her other duties are clear) is
 * separate, larger design work already captured in the plan
 * (/datum/xeno_ai_controller/queen) - not yet built. Until it lands, she'll
 * behave like an oversized Drone: alive, patrolling, and will defend herself,
 * but won't yet command the hive or manage eggs autonomously.
 */
/datum/game_mode/colonialmarines/hive_encounter
	name = "Hive Incursion"
	config_tag = GAMEMODE_HIVE_INCURSION
	/// How many AI drones accompany the initial queen at round start.
	var/starting_drone_count = 3
	/// Set the moment any AI-piloted xeno first spots a marine - flips the round from ambient patrol into hive-wide alert. See on_contact_made() and the hook in xeno_ai_controller.dm's process_target().
	var/contact_made = FALSE
	/// How many completed objectives count as a marine victory via the objective path (as opposed to wiping the hive entirely).
	var/objectives_required_for_marine_win = 3

/datum/game_mode/colonialmarines/hive_encounter/post_setup()
	. = ..()
	// Let hive_status/map setup finish settling before we go looking for a
	// nest/weed node to anchor the starting hive to.
	addtimer(CALLBACK(src, PROC_REF(spawn_initial_hive)), 2 SECONDS)

/**
 * Finds the map's pre-placed hive location (the same weed node/nest
 * structures every Distress Signal round already spawns via
 * code/game/objects/effects/landmarks/structure_spawners/setup_distress.dm)
 * and puts a real, AI-piloted Queen and a handful of Drones there before
 * marines ever land - "the hive was already here."
 */
/datum/game_mode/colonialmarines/hive_encounter/proc/spawn_initial_hive()
	var/turf/hive_turf = get_hive_anchor_turf()
	if(!hive_turf)
		log_world("hive_encounter: no hive anchor turf (nest/weed node) found on this map - could not spawn the initial hive.")
		return

	spawn_ai_xeno(XENO_CASTE_QUEEN, hive_turf, XENO_HIVE_NORMAL)
	for(var/i in 1 to starting_drone_count)
		spawn_ai_xeno(XENO_CASTE_DRONE, hive_turf, XENO_HIVE_NORMAL)

/// One-time round-start lookup, not a hot path - a plain world scan is fine here.
/datum/game_mode/colonialmarines/hive_encounter/proc/get_hive_anchor_turf()
	for(var/obj/effect/alien/weeds/node/weed_node in world)
		return get_turf(weed_node)
	for(var/obj/structure/bed/nest/nest in world)
		return get_turf(nest)
	return null

/**
 * Fired once, the first time any AI-piloted xeno acquires a marine as a
 * target (see the hook in xeno_ai_controller.dm's process_target()) -
 * this is the "they've been spotted" beat: ARES gets nervous, and the hive's
 * ambient patrol posture flips to alert. Deliberately doesn't change any AI
 * behavior directly yet (that's the per-caste alert-state work still to
 * come) - for now this is purely the narrative/ARES trigger the design calls
 * for, wired through the announcement plumbing that already exists.
 */
/datum/game_mode/colonialmarines/hive_encounter/proc/on_contact_made(mob/living/carbon/xenomorph/spotter, mob/living/target)
	if(contact_made)
		return
	contact_made = TRUE
	ai_announcement("Unconfirmed contact, [get_area_name(spotter)]. Possible hostile bio-signs. Command recommends caution.")
	playsound_z(SSmapping.levels_by_trait(ZTRAIT_GROUND), 'sound/voice/alien_distantroar_3.ogg', 50)

/**
 * Additional marine-victory path layered on top of the existing check_win()
 * (called via ..() first, unchanged) - completing enough of the procedural
 * objective chain counts as a win even if the hive isn't fully wiped.
 * MODE_INFESTATION_X_MINOR is reused for this (an existing "marines
 * succeeded without total hive annihilation" outcome, the same bucket
 * evac-while-xenos-alive already uses) rather than adding a new outcome
 * constant, so declare_completion()'s narration needs no changes either.
 */
/datum/game_mode/colonialmarines/hive_encounter/check_win()
	. = ..()
	if(round_finished || is_in_endgame)
		return .
	if(!mission_controller)
		return .
	if(length(mission_controller.completed_objective_types) >= objectives_required_for_marine_win)
		round_finished = MODE_INFESTATION_X_MINOR
	return .
