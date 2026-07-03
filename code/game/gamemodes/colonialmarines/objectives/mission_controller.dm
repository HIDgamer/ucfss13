/**
 * Drives the procedural objective chain for a round (see the Stage 2
 * "Dynamic Mission System" design). Owned by /datum/game_mode/colonialmarines
 * (see colonialmarines.dm's mission_controller var and process() hook) -
 * deliberately does NOT touch round win/loss (check_win()/hijack) yet; this
 * is purely an additive narrative/objective layer on top of the existing
 * round flow, per the plan's own sequencing (objective skeleton validated in
 * isolation before anything touches the live win/loss switch).
 */
/datum/mission_controller
	/// Currently active objective, if any. Kept to a single active objective for this first pass - concurrent objectives are a later refinement.
	var/datum/mission_objective/current_objective
	/// Typepaths of objectives already completed or failed this round, so prerequisites and "don't repeat" checks work and so admins/debug tools can see mission history.
	var/list/completed_objective_types = list()
	var/list/failed_objective_types = list()
	/// All concrete objective typepaths available to pick from, minus ones already resolved.
	var/list/objective_pool
	/// Live-adjustable pacing knob (see the admin mission control panel, event_tab.dm's /datum/admin_mission_control) - objective types that want difficulty scaling (time limits, wave size once 2.3 lands) read this off their controller back-reference. 1 = default pacing, >1 = slower/easier, <1 = faster/harder.
	var/difficulty_multiplier = 1

/datum/mission_controller/New()
	. = ..()
	objective_pool = list()
	for(var/datum/mission_objective/objective_type as anything in subtypesof(/datum/mission_objective))
		objective_pool += objective_type

/datum/mission_controller/Destroy()
	QDEL_NULL(current_objective)
	return ..()

// No /proc/ keyword here - /datum/proc/process(delta_time) already exists
// (the generic SSprocessing interface), so this overrides it rather than
// declaring a new proc. We call this manually from the gamemode's own
// process() override, never via START_PROCESSING, so the shared name is
// purely cosmetic/interface-matching, not a functional hookup to SSobj/etc.
/datum/mission_controller/process()
	if(!current_objective)
		start_next_objective()
		return

	current_objective.process()

	if(!current_objective.resolved && current_objective.check_failed())
		current_objective.resolved = TRUE
		failed_objective_types += current_objective.type
		current_objective.on_failed()
		QDEL_NULL(current_objective)
		start_next_objective()
		return

	if(!current_objective.resolved && current_objective.check_complete())
		current_objective.resolved = TRUE
		completed_objective_types += current_objective.type
		current_objective.on_complete()
		QDEL_NULL(current_objective)
		start_next_objective()
		return

/// Weighted-random pick from whatever's left in the pool with satisfied prerequisites; does nothing (silently) once the pool is exhausted, since not every round needs to end with a scripted "no more objectives" state yet - that's an endgame-design question for later.
/datum/mission_controller/proc/start_next_objective()
	var/list/eligible = list()
	for(var/datum/mission_objective/objective_type as anything in objective_pool)
		if(objective_type in completed_objective_types)
			continue
		if(objective_type in failed_objective_types)
			continue
		var/list/prereqs = initial(objective_type.prerequisites)
		var/prereqs_met = TRUE
		for(var/prereq_type in prereqs)
			if(!(prereq_type in completed_objective_types))
				prereqs_met = FALSE
				break
		if(!prereqs_met)
			continue
		var/weight = initial(objective_type.weight)
		eligible[objective_type] = weight

	if(!length(eligible))
		return

	var/picked_type = pick_weight(eligible)
	current_objective = new picked_type()
	current_objective.controller = src
	current_objective.start()

/// Admin-tool entry points (see event_tab.dm's /datum/admin_mission_control) - kept here rather than inlined in the TGUI datum so the actual state transitions have exactly one code path regardless of whether they're triggered by the normal check_complete()/check_failed() flow or forced by staff.
/datum/mission_controller/proc/force_complete_current()
	if(!current_objective || current_objective.resolved)
		return FALSE
	current_objective.resolved = TRUE
	completed_objective_types += current_objective.type
	current_objective.on_complete()
	QDEL_NULL(current_objective)
	start_next_objective()
	return TRUE

/datum/mission_controller/proc/force_fail_current()
	if(!current_objective || current_objective.resolved)
		return FALSE
	current_objective.resolved = TRUE
	failed_objective_types += current_objective.type
	current_objective.on_failed()
	QDEL_NULL(current_objective)
	start_next_objective()
	return TRUE
