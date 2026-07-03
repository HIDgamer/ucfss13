/**
 * Base class for a procedurally-selectable mission objective (see the Stage 2
 * "Dynamic Mission System" design). This is deliberately NOT
 * /datum/cm_objective (code/modules/objectives/objective.dm) - that's an
 * unrelated WY/UPP/CLF hidden-intel tech-tree metagame, wrong shape for a
 * round-wide mission tracker.
 *
 * Concrete objective types override check_complete()/check_failed() and the
 * announce_*() hooks; on_complete()/on_failed() are called exactly once each
 * by the controller and are where an objective can set up follow-on state
 * (e.g. spawning the next objective's target location).
 */
/datum/mission_objective
	/// Player-facing name, e.g. "Establish the Forward Operating Base".
	var/name = "Unknown Objective"
	/// Player-facing flavor/instruction text.
	var/description = ""
	/// Relative pick weight when the controller is choosing the next objective from the pool - duplicate-equivalent entries can just use a higher number.
	var/weight = 1
	/// Objective typepaths that must already be in the controller's completed list before this one can be picked. Empty list means no prerequisite.
	var/list/prerequisites = list()
	/// world.time this objective was started, set by the controller.
	var/started_at = 0
	/// Optional hard time limit (world.time delta) after which check_failed() should report failure - 0 means no limit.
	var/time_limit = 0

	/// Set true once on_complete()/on_failed() has fired, so the controller doesn't double-fire either hook if process() is called again in the same tick window.
	var/resolved = FALSE
	/// Back-reference to the controller that started this objective, set at pick time (see mission_controller.dm's start_next_objective()). Lets an objective read the live-adjustable difficulty_multiplier (see the admin mission control panel) without a global lookup.
	var/datum/mission_controller/controller

/datum/mission_objective/New()
	. = ..()
	started_at = world.time

/// Called once when the controller activates this objective - do announce_start() and any one-time setup here.
/datum/mission_objective/proc/start()
	announce_start()

// No /proc/ keyword - /datum/proc/process(delta_time) already exists (the
// generic SSprocessing interface); this overrides it. Called manually by
// the mission controller's own process(), never via START_PROCESSING.
/// Called every mission controller tick while this objective is active.
/datum/mission_objective/process()
	return

/// Return TRUE once the objective's success condition is met.
/datum/mission_objective/proc/check_complete()
	return FALSE

/// Return TRUE if the objective should be abandoned as failed (e.g. time_limit elapsed, a required NPC died). Default only checks time_limit.
/datum/mission_objective/proc/check_failed()
	if(time_limit && (world.time - started_at) > time_limit)
		return TRUE
	return FALSE

/// Fired exactly once by the controller when check_complete() first returns TRUE.
/datum/mission_objective/proc/on_complete()
	announce_complete()

/// Fired exactly once by the controller when check_failed() first returns TRUE.
/datum/mission_objective/proc/on_failed()
	announce_failed()

/// Hook triple below is intentionally thin wrappers so every objective type gets ARES narration for free just by filling in message text (see the Stage 2.5 ARES integration plan) - concrete types should override the message, not the plumbing.
/datum/mission_objective/proc/announce_start()
	if(description)
		marine_announcement(description, "ARES Tactical Update", 'sound/AI/commandreport.ogg')

/datum/mission_objective/proc/announce_progress(message)
	if(message)
		marine_announcement(message, "ARES Tactical Update", 'sound/AI/commandreport.ogg')

/datum/mission_objective/proc/announce_complete()
	marine_announcement("Objective complete: [name].", "ARES Tactical Update", 'sound/AI/commandreport.ogg')

/datum/mission_objective/proc/announce_failed()
	marine_announcement("Objective failed: [name].", "ARES Tactical Update", 'sound/AI/commandreport.ogg')
