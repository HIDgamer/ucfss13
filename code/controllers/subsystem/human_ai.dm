/// Thinks for every NPC human brain, tiered by how much each one matters right now
SUBSYSTEM_DEF(human_ai)
	name = "Human AI"
	wait = HAI_TIER_ENGAGED
	flags = SS_NO_INIT | SS_KEEP_TIMING
	priority = SS_PRIORITY_HUMAN_AI

	var/list/datum/human_ai_brain/brains = list()
	var/list/datum/human_ai_brain/currentrun = list()
	var/list/datum/human_ai_squad/squads = list()
	/// Brains thinking above the dormant tier, never above max_full
	var/full_count = 0
	var/max_full = HAI_MAX_FULL
	/// Brains allowed to exist at all, 0 for no limit
	var/max_total = HAI_MAX_TOTAL
	/// Think interval multiplier, raised by the lag switch
	var/interval_multiplier = 1
	/// Milliseconds spent thinking over the last fire, and a smoothed average of the same
	var/last_cost_ms = 0
	var/avg_cost_ms = 0
	var/thinks_last_fire = 0
	/// Totals since the last reset_cost_meter(), for measuring a stretch of time
	var/total_cost_ms = 0
	var/total_thinks = 0
	/// Part of total_cost_ms the stock gun code spent firing, which any shooter pays, and what the noise bus spent
	var/gun_cost_ms = 0
	var/noise_cost_ms = 0
	var/squad_cost_ms = 0
	/// Window the talk caps count in, what was said in it, and a log of what was said kept only while record_talk is on
	var/talk_window_end = 0
	var/talk_count = 0
	var/list/area_talk = list()
	var/total_barks = 0
	var/record_talk = FALSE
	var/list/talk_log = list()
	var/path_budget = HAI_PATH_REQUESTS_PER_FIRE
	var/cover_budget = HAI_COVER_SEARCHES_PER_FIRE
	/// Difficulty knobs, one is neutral: bigger aim error makes brains miss more, bigger reaction makes them slower to start shooting
	var/aim_error_mult = 1
	var/reaction_mult = 1
	/// How quick the brains are to notice and hear, one is neutral and the bigger it is the harder it is to move about unseen, and whether a marker goes over a head that is stirred by something
	var/detection_mult = 1
	var/stealth_cues = FALSE
	/// Brains switched off for throwing too many errors
	var/disabled_count = 0
	/// Nothing thinks while this is set, switched from the command panel
	var/paused = FALSE
	/// Minus one to one, leans every brain toward caution or aggression
	var/aggression_bias = 0
	/// Follows the marine players awake with the difficulty knobs while set
	var/auto_scale = FALSE
	var/next_scale_time = 0
	var/scale_players = -1
	/// Think interval multiplier the budget arbiter puts on brains that are not in a fight, and the smoothed load it saw last
	var/arbiter_multiplier = 1
	var/arbiter_load = 0
	var/next_arbiter_time = 0
	var/arbiter_cost_mark = 0
	var/arbiter_time_mark = 0

/datum/controller/subsystem/human_ai/stat_entry(msg)
	msg = "[paused ? "PAUSED " : ""]B:[length(brains)] F:[full_count] C:[round(avg_cost_ms, 0.01)]ms"
	return ..()

/datum/controller/subsystem/human_ai/fire(resumed = FALSE)
	if(paused)
		currentrun.Cut()
		return
	if(!resumed)
		currentrun = brains.Copy()
		last_cost_ms = 0
		thinks_last_fire = 0
		path_budget = HAI_PATH_REQUESTS_PER_FIRE
		cover_budget = HAI_COVER_SEARCHES_PER_FIRE
		interval_multiplier = SSlag_switch.measures[SIMPLIFY_HUMAN_AI] ? 2 : 1
		if(auto_scale && world.time >= next_scale_time)
			next_scale_time = world.time + HAI_SCALE_INTERVAL
			apply_scaling(get_active_player_count(TRUE, TRUE, TRUE, FACTION_MARINE))
		if(world.time >= next_arbiter_time)
			next_arbiter_time = world.time + HAI_ARBITER_INTERVAL
			arbitrate()
		plan_squads()

	while(length(currentrun))
		var/datum/human_ai_brain/brain = currentrun[length(currentrun)]
		currentrun.len--

		if(QDELETED(brain) || brain.stopped || brain.next_think > world.time)
			continue

		var/started = TICK_USAGE
		brain.run_think()
		var/cost = max(0, TICK_USAGE_TO_MS(started))
		last_cost_ms += cost
		total_cost_ms += cost
		total_thinks++
		thinks_last_fire++

		if(MC_TICK_CHECK)
			return

	avg_cost_ms = avg_cost_ms * 0.8 + last_cost_ms * 0.2

/// Lets every squad that is due make its plan
/datum/controller/subsystem/human_ai/proc/plan_squads()
	for(var/datum/human_ai_squad/squad as anything in squads.Copy())
		if(QDELETED(squad) || squad.next_plan > world.time)
			continue
		var/started = TICK_USAGE
		squad.run_plan()
		var/cost = max(0, TICK_USAGE_TO_MS(started))
		squad_cost_ms += cost
		total_cost_ms += cost

/// Brings a brain onto the schedule, staggered so a whole squad does not think on the same tick
/datum/controller/subsystem/human_ai/proc/register(datum/human_ai_brain/brain)
	if(brain in brains)
		return
	brains += brain
	brain.next_think = world.time + (length(brains) % HAI_TIER_IDLE) + 1
	set_tier(brain, HAI_TIER_IDLE)

/datum/controller/subsystem/human_ai/proc/unregister(datum/human_ai_brain/brain)
	if(!(brain in brains))
		return
	brains -= brain
	currentrun -= brain
	if(brain.tier != HAI_TIER_DORMANT)
		full_count = max(0, full_count - 1)
	brain.tier = null

/// Moves a brain to the wanted tier, anything that would push full fidelity past the cap goes dormant instead
/datum/controller/subsystem/human_ai/proc/set_tier(datum/human_ai_brain/brain, wanted)
	if(brain.tier == wanted)
		return wanted
	var/was_full = !isnull(brain.tier) && brain.tier != HAI_TIER_DORMANT
	if(wanted != HAI_TIER_DORMANT && !was_full && full_count >= max_full)
		wanted = HAI_TIER_DORMANT
	var/is_full = wanted != HAI_TIER_DORMANT
	if(is_full && !was_full)
		full_count++
	else if(!is_full && was_full)
		full_count--
	brain.tier = wanted
	return wanted

/datum/controller/subsystem/human_ai/proc/reset_cost_meter()
	total_cost_ms = 0
	total_thinks = 0
	gun_cost_ms = 0
	noise_cost_ms = 0
	squad_cost_ms = 0

/// Spends one of the route requests this fire allows, false when none are left
/datum/controller/subsystem/human_ai/proc/take_path_budget()
	if(path_budget <= 0)
		return FALSE
	path_budget--
	return TRUE

/// Spends one of the cover searches this fire allows, false when none are left
/datum/controller/subsystem/human_ai/proc/take_cover_budget()
	if(cover_budget <= 0)
		return FALSE
	cover_budget--
	return TRUE

/datum/controller/subsystem/human_ai/proc/has_room()
	return !max_total || length(brains) < max_total

/// Shortest wait before the next think for a tier at the current lag switch level
/datum/controller/subsystem/human_ai/proc/interval_for(tier)
	return tier * interval_multiplier * ((tier > HAI_TIER_ALERT) ? arbiter_multiplier : 1)
