#define HAI_LOG(text) if(GLOB.ai_debug_pathing) { WRITE_LOG(GLOB.ai_debug_log, "HAI: [text]") }

/// The decision making of one NPC human, scheduled by SShuman_ai
/datum/human_ai_brain
	var/mob/living/carbon/human/body
	var/datum/human_ai_personality/personality
	var/intent = HAI_INTENT_IDLE
	/// Current LOD tier, null while not on the schedule
	var/tier
	var/next_think = 0
	var/stopped = FALSE
	var/stop_reason
	/// Keeps the brain out of the dormant tier even with no player nearby
	var/keep_awake = FALSE

	var/stress = 0
	var/roe = HAI_ROE_WEAPONS_FREE
	/// Who the brain fights among humans, one of the HAI_AGGRO defines
	var/aggression = HAI_AGGRO_FACTIONS
	/// Replaces the global enemy faction table of the body's faction when set
	var/list/enemy_factions

	/// Subject reference text to /datum/ai_contact
	var/list/contacts = list()
	var/last_perceive_time = 0
	var/scan_count = 0
	/// Scans that really looked, the rest were skipped by the spatial grid cull
	var/view_scans = 0
	var/alert_until = 0
	var/turf/investigate_turf
	var/investigate_until = 0
	var/investigate_strength = 0
	var/list/turf/search_points
	var/search_index = 0
	var/search_wait_until = 0
	var/datum/weakref/last_attacker_ref
	var/last_hurt_time = 0
	var/last_shot_at_time = 0

	var/datum/weakref/target_ref
	var/target_seen_time = 0
	var/turf/waypoint
	/// Run to the waypoint instead of walking
	var/waypoint_sprint = FALSE
	var/next_scan_time = 0
	var/debug_text_shown = FALSE

	var/list/turf/path
	var/turf/path_goal
	var/path_built_at = 0
	var/next_path_request = 0
	var/next_step_time = 0
	var/move_state = HAI_MOVE_ARRIVED
	var/turf/move_goal
	var/turf/last_progress_turf
	var/last_progress_time = 0
	var/stuck_recoveries = 0
	var/route_retries = 0
	/// Turf to the world.time it stops being avoided
	var/list/blocked_turfs = list()
	/// Set while a vault or a pry is running
	var/acting_until = 0
	var/datum/weakref/follow_ref
	var/follow_slot = 0

	/// Reload in progress, the gun it is for and what goes in
	var/reload_phase = HAI_RELOAD_NONE
	var/reload_until = 0
	var/datum/weakref/reload_gun_ref
	var/datum/weakref/reload_item_ref
	var/atom/reload_start_loc
	var/reload_rounds_loaded = 0
	var/reload_count = 0
	var/spare_check_time = 0
	var/datum/weakref/spare_check_gun_ref
	var/spare_check_result = FALSE
	var/next_cycle_time = 0
	/// Firing: reaction delay, fire mode flapping guard, volley bookkeeping and failure tracking
	var/reaction_until = 0
	var/next_mode_time = 0
	var/volley_left = 0
	var/volley_pause_until = 0
	var/fire_failures = 0
	var/gun_blocked_until = 0
	var/last_shot_time = 0
	var/shots_fired = 0
	var/next_switch_time = 0
	/// Cover: whether the brain looks for it, the spot it is heading for and the thing that makes it cover
	var/cover_enabled = TRUE
	var/turf/cover_goal_turf
	var/obj/cover_goal_object
	var/obj/last_cover_object
	var/next_cover_search = 0
	var/next_flip_time = 0
	var/cover_shots = 0
	var/next_hazard_check = 0
	var/list/hive_cache
	var/hive_cache_time = 0
	var/mob/living/target_memo
	var/target_memo_time = -1
	var/turf/hazard_turf
	var/cover_memo_time = -1
	var/turf/cover_memo_here
	var/turf/cover_memo_threat
	var/cover_memo_value = 0
	var/grenade_cache_time = 0
	var/list/grenade_cache
	var/peeks = 0
	var/cover_moves = 0
	var/tables_flipped = 0
	var/hazard_dodges = 0
	var/next_shove_time = 0
	var/shoves = 0
	var/melee_draws = 0
	var/next_resist_time = 0
	var/fire_rolls = 0
	var/next_grenade_time = 0
	/// The gun last held, the one it is going to take up and when it may look for one again, guns it could not get to until the time given, how many it took up again and shots held back for a wall in the way
	var/datum/weakref/main_gun_ref
	var/datum/weakref/recover_ref
	var/next_recover_search = 0
	var/list/recover_skips = list()
	var/recovered_weapons = 0
	var/wall_holds = 0
	/// How alarmed it is, from nothing to one, and since when; bodies found and until when they are remembered; the time of the last marker over the head
	var/vigilance_level = 0
	var/vigilance_time = 0
	var/list/known_bodies
	var/next_cue_time = 0
	/// The farthest it sees through what it wears and the state of its eyes, and when that was worked out
	var/eye_reach_value = 0
	var/eye_reach_time = -1
	/// The next look over its gear, the thing to do about it, the places where the lights and the night vision went on, how long a welding mask stays down and how often the gear was switched
	var/next_gear_check = 0
	var/list/gear_job
	var/area/lamp_area
	var/area/vision_area
	var/weld_until = 0
	var/gear_toggles = 0
	/// Told to keep the lights off whatever the dark
	var/lights_out = FALSE
	var/footsteps_heard = 0
	/// The vehicle of an enemy side it is firing on, when it last looked for one and how many shots it put into vehicles
	var/datum/weakref/vehicle_ref
	var/next_vehicle_scan = 0
	var/vehicle_shots = 0
	/// How many times in a row the router found no way to the goal, kept apart from the retries because a step sideways on the way gives those back
	var/no_route_count = 0
	/// The way it keeps watch where it stands and the place that was worked out for, and when it last turned to look round a place
	var/watch_dir
	var/turf/watch_turf
	var/next_look_time = 0
	var/bodies_found = 0
	/// Until when the hands are tied up with something that is not shooting, a grenade being drawn and thrown for one
	var/hands_busy_until = 0
	/// The light on a tile as the unit sees it when set, for tests that need a dark place
	var/light_override
	var/grenade_blocked_until = 0
	var/grenades_thrown = 0
	var/weapon_switches = 0
	var/other_gun_check_time = 0
	var/datum/weakref/other_gun_ref
	var/datum/weakref/other_gun_check_for_ref

	var/datum/human_ai_role/role
	var/datum/human_ai_squad/squad
	var/squad_role = HAI_SQUAD_ROLE_NONE
	/// The job being carried out and the counts of how the ones given went
	var/datum/npc_order/current_order
	var/orders_received = 0
	var/orders_refused = 0
	var/orders_completed = 0
	var/last_refused_order
	var/last_refused_time = 0
	var/posture = HAI_POSTURE_NORMAL
	var/datum/human_ai_personality/base_personality
	var/move_cap = HAI_MOVE_CAP_SPRINT
	var/roe_before_order = HAI_ROE_WEAPONS_FREE
	var/roe_restore_time = 0
	var/next_mood_time = 0
	var/last_mood_time = 0
	var/broken_kind = HAI_BREAK_NONE
	var/broken_until = 0
	var/break_count = 0
	var/surrendered = FALSE
	var/surrender_until = 0
	var/berserk_until = 0
	var/turf/flee_goal
	var/next_flee_time = 0
	var/retreats = 0
	/// Humans who are not enemies yet but could be, and who the brain has turned hostile on its own account until when
	var/list/watching = list()
	var/list/disposition_override = list()
	var/challenges = 0
	/// Kind to when it was last said, when anything was last said and how much has been said or emoted
	var/list/talk_times = list()
	var/last_talk_time = 0
	var/barks = 0
	var/emotes_made = 0
	var/turf/home_turf
	var/turf/idle_goal
	var/next_idle_time = 0
	var/idle_wanders = 0
	/// The spot an idle armed brain stands watch from, the way it faces there, when it weighs spots again and how many it has taken
	var/turf/post_turf
	var/post_dir
	/// The circle the brain is held to by an order, null when it is free to go where it likes
	var/turf/leash_center
	var/leash_radius = 0
	var/next_post_search = 0
	var/posts_taken = 0
	/// Looking for a way round something climbable before climbing it, when the next vault is allowed and how many were made
	var/climb_detours = 0
	var/next_vault_time = 0
	var/vaults = 0
	/// Shots held back for a friend in the way, steps taken backing off, the window those steps are counted in and the time of the next one
	var/ff_holds = 0
	var/kites = 0
	var/kite_steps = 0
	var/kite_window_end = 0
	var/next_kite_time = 0
	var/turf/kite_goal_turf
	/// Patient reference text to chemical id to when it was last injected, and how many injections were given
	var/list/inject_times = list()
	var/injections = 0
	/// Doors hacked open
	var/hacks = 0
	/// Dead doors forced open with a crowbar
	var/pries = 0
	/// Machine limbs mended with a welder or cable
	var/repairs = 0
	/// Walls brought down with a breaching hammer
	var/walls_hammered = 0
	/// The door it is forcing with a charge, the charge, where the door stands, the stage it is at, when it started and when it gives up waiting, and the doors it forced
	var/datum/weakref/breach_door_ref
	var/datum/weakref/breach_charge_ref
	var/turf/breach_door_turf
	var/breach_phase = 0
	var/breach_started = 0
	var/breach_wait_until = 0
	var/forced_doors = 0
	/// Grenades armed in the hand to take an enemy along
	var/charges_primed = 0
	/// The prisoner it cuffed and has still to take away, where it takes them, when it looks for the place again and how many it has taken
	var/datum/weakref/captive_ref
	var/turf/holding_turf
	var/holding_search_time = 0
	var/prisoners_delivered = 0
	/// Ladders climbed to follow a goal to another level
	var/ladders_climbed = 0
	/// The dead friend a medic is heading for with a defibrillator, when it may look for the next one, bodies left alone until the time given and how many shocks were tried and took
	var/datum/weakref/corpse_ref
	var/next_corpse_search = 0
	var/list/corpse_skips = list()
	var/defib_tries = 0
	var/revives = 0
	/// When it may rig a ghillie suit up again and how often it has
	var/next_camo_time = 0
	var/camo_uses = 0
	/// Hits from its own side by shooter reference text, calls for backup made and answered
	var/list/tolerance = list()
	var/next_backup_call = 0
	/// Where the thing a call-out is about stands, only held while the call-out is made
	var/callout_spot
	var/backups_called = 0
	var/backups_answered = 0
	/// The loose item it is heading for, when it may pick up the next one and how much it has picked up
	var/datum/weakref/loot_ref
	var/next_loot_time = 0
	var/loot_count = 0
	/// Player reference text to when that player last gave this unit a voice command, and how many were obeyed
	var/list/voice_heard = list()
	var/voice_orders = 0
	/// Enemies who called out that they give up and are believed until the time given, and how many surrenders the brain has taken
	var/list/surrender_accepted = list()
	var/surrenders_taken = 0
	var/next_convo_time = 0
	var/convos_started = 0
	var/convo_answers = 0
	var/list/greeted = list()
	var/datum/weakref/patient_ref
	var/next_patient_search = 0
	var/treatments = 0
	var/dragged = 0
	var/turf/drag_goal_turf
	var/next_drag_search = 0
	var/triage_until = 0
	var/list/treated_patients = list()
	var/list/med_cache
	var/med_cache_time = 0
	var/datum/weakref/utility_ref
	var/list/avoid_nests = list()
	var/nest_hits = 0
	var/nest_moves = 0
	var/turf/displace_goal
	var/suppressive_shots = 0
	var/next_rally_time = 0
	var/datum/weakref/prisoner_ref
	var/next_prisoner_search = 0
	var/prisoners = 0
	var/barricades_built = 0
	var/defenses_deployed = 0
	var/mines_laid = 0
	var/charges_planted = 0
	var/traps_rigged = 0
	var/panic_until = 0
	var/turf/shelter_goal
	var/next_shelter_search = 0
	var/sheltered = FALSE
	var/times_sheltered = 0
	var/followed_armed = 0
	var/hands_up_count = 0
	var/shocks_armed = 0
	var/shocks_lifted = 0
	var/warnings = 0
	var/escalations = 0
	/// The thing it is going to mend or clean and what kind of work it is, when it may look for the next one, what it could not manage until the time given and how much it has got done
	var/datum/weakref/maint_ref
	var/maint_kind
	var/next_maint_scan = 0
	var/list/maint_skips = list()
	var/maint_done = 0
	/// The stair it is walking to, where that comes out, the goal it was planned for, when to give up on it, when it got onto it, whether it is the stair itself being walked to,
	/// when it may search again, the stairs that failed until the time given and how many it has taken
	var/turf/stair_entry
	var/turf/stair_exit
	var/turf/stair_goal
	var/obj/structure/ladder/stair_ladder
	var/stair_direction
	var/stair_until = 0
	var/stair_on_entry_since = 0
	var/stair_inner = FALSE
	var/next_stair_plan = 0
	var/list/stair_skips = list()
	var/stairs_taken = 0
	/// Times it kept still for a broken bone
	var/holds_still = 0
	/// Wounded men it could not get to, by reference text to the time it tries them again
	var/list/patient_skips = list()
	/// The gear this body wore when it died, as list(slot, weakref to the item), and when it may next go for it
	var/list/regear_items
	var/next_regear_time = 0
	var/regeared = 0
	/// When a maintenance unit may next come out with a quip and next look over the people around it
	var/next_joe_quip = 0
	var/next_joe_watch = 0
	var/list/joe_noticed = list()

	/// Replaces the global action list when set
	var/list/action_pool
	/// Limbs claimed by the actions already run in the current think
	var/limbs_busy = NONE

	var/list/error_times = list()
	var/error_total = 0
	var/suppress_error_log = FALSE
	var/think_count = 0
	/// Rolling record of what the brain decided, newest last
	var/list/decision_log = list()

/datum/human_ai_brain/New(mob/living/carbon/human/new_body, personality_id = "neutral")
	. = ..()
	body = new_body
	personality = get_human_ai_personality(personality_id)
	role = get_human_ai_role("rifleman")

/datum/human_ai_brain/Destroy()
	SShuman_ai.unregister(src)
	// The claims on patients are kept in a global list that would hold the brain for ever
	for(var/key in GLOB.human_ai_patient_claims)
		var/list/claim = GLOB.human_ai_patient_claims[key]
		if(claim[1] == src)
			GLOB.human_ai_patient_claims -= key
	body = null
	personality = null
	action_pool = null
	target_ref = null
	cover_goal_turf = null
	cover_goal_object = null
	last_cover_object = null
	hazard_turf = null
	target_memo = null
	hive_cache = null
	cover_memo_here = null
	cover_memo_threat = null
	grenade_cache = null
	reload_gun_ref = null
	reload_item_ref = null
	reload_start_loc = null
	spare_check_gun_ref = null
	other_gun_ref = null
	other_gun_check_for_ref = null
	waypoint = null
	path = null
	path_goal = null
	move_goal = null
	last_progress_turf = null
	blocked_turfs = null
	follow_ref = null
	QDEL_NULL(current_order)
	QDEL_LIST_ASSOC_VAL(watching)
	disposition_override = null
	flee_goal = null
	home_turf = null
	idle_goal = null
	release_post()
	kite_goal_turf = null
	inject_times = null
	tolerance = null
	voice_heard = null
	surrender_accepted = null
	leash_center = null
	breach_door_ref = null
	breach_charge_ref = null
	breach_door_turf = null
	maint_ref = null
	maint_skips = null
	joe_noticed = null
	patient_skips = null
	main_gun_ref = null
	recover_ref = null
	recover_skips = null
	known_bodies = null
	vehicle_ref = null
	watch_turf = null
	GLOB.human_ai_lit_lamps -= src
	gear_job = null
	lamp_area = null
	vision_area = null
	stair_entry = null
	stair_exit = null
	stair_goal = null
	stair_ladder = null
	stair_skips = null
	regear_items = null
	captive_ref = null
	holding_turf = null
	loot_ref = null
	corpse_ref = null
	corpse_skips = null
	patient_ref = null
	utility_ref = null
	displace_goal = null
	avoid_nests = null
	prisoner_ref = null
	shelter_goal = null
	med_cache = null
	squad = null
	role = null
	QDEL_LIST_ASSOC_VAL(contacts)
	investigate_turf = null
	search_points = null
	last_attacker_ref = null
	return ..()

/datum/human_ai_brain/proc/start()
	stopped = FALSE
	SShuman_ai.register(src)

/// Switches the brain off and hands the body back
/datum/human_ai_brain/proc/stop(reason = HAI_STOP_DETACHED)
	if(body && body.ai_brain == src)
		detach_human_ai(body, reason)
		return
	wind_down(reason)

/datum/human_ai_brain/proc/wind_down(reason)
	if(stopped)
		return
	stopped = TRUE
	stop_reason = reason
	release_post()
	current_order?.finish(HAI_ORDER_CANCELLED)
	squad?.remove_member(src, reason)
	if(reason == HAI_STOP_DEAD)
		scare_allies()
	if(debug_text_shown && body)
		body.maptext = null
	log_decision("stopped: [reason]")
	SShuman_ai.unregister(src)

/datum/human_ai_brain/proc/log_decision(text)
	decision_log += "[world.time]: [text]"
	if(length(decision_log) > HAI_DECISION_LOG_SIZE)
		decision_log.Cut(1, 2)
	HAI_LOG("[body] ([intent]) [text]")

/datum/human_ai_brain/proc/set_intent(new_intent, reason)
	if(intent == new_intent)
		return
	intent = new_intent
	log_decision("intent [new_intent][reason ? " ([reason])" : ""]")

/datum/human_ai_brain/proc/get_target()
	if(target_memo_time == world.time && !QDELETED(target_memo))
		return target_memo
	target_memo = target_ref?.resolve()
	target_memo_time = world.time
	return target_memo

/datum/human_ai_brain/proc/get_follow_target()
	return follow_ref?.resolve()

/datum/human_ai_brain/proc/set_follow(atom/movable/leader, slot = 0)
	follow_ref = leader ? WEAKREF(leader) : null
	follow_slot = slot
	log_decision(leader ? "following [leader] in slot [slot]" : "stopped following")

/datum/human_ai_brain/proc/set_target(atom/movable/new_target)
	var/atom/movable/old_target = get_target()
	if(old_target == new_target)
		return
	target_ref = new_target ? WEAKREF(new_target) : null
	target_memo_time = -1
	target_seen_time = new_target ? world.time : 0
	if(new_target && world.time > last_shot_time + HAI_REACTION_FORGET)
		start_reaction()
	log_decision(new_target ? "target [new_target]" : "target lost")

/// Entry point for the subsystem, nothing a think does may escape this
/datum/human_ai_brain/proc/run_think()
	var/started_tier = tier
	next_think = world.time + SShuman_ai.interval_for(tier || HAI_TIER_IDLE)
	think_count++
	try
		think()
	catch(var/exception/error)
		on_error(error)
	if(tier && tier != started_tier)
		next_think = world.time + SShuman_ai.interval_for(tier)

/datum/human_ai_brain/proc/think()
	if(QDELETED(body))
		stop(HAI_STOP_DELETED)
		return
	if(body.stat == DEAD)
		stop(HAI_STOP_DEAD)
		return
	if(body.client)
		stop(HAI_STOP_CLAIMED)
		return
	if(iszombie(body))
		stop(HAI_STOP_SPECIES)
		return

	update_tier()
	update_debug_text()
	if(tier == HAI_TIER_DORMANT)
		return
	if(body.is_mob_incapacitated())
		return
	validate_target()
	check_order()
	tidy_hands()
	remember_gun()
	update_mood()
	check_break()
	refresh_intent()
	run_actions(action_pool || GLOB.human_ai_actions)

/// Scores every allowed action and runs the best ones whose limbs do not clash
/datum/human_ai_brain/proc/run_actions(list/pool)
	var/list/scored = list()
	for(var/datum/human_ai_action/action as anything in pool)
		if(!action.allowed_in(intent))
			continue
		var/weight = action.get_weight(src)
		if(weight <= 0)
			continue
		weight *= personality.mult(action.id)
		if(weight <= 0)
			continue
		var/index = length(scored) + 1
		while(index > 1 && scored[index - 1][2] < weight)
			index--
		scored.Insert(index, list(list(action, weight)))

	limbs_busy = NONE
	var/ran = 0
	for(var/list/entry in scored)
		var/datum/human_ai_action/action = entry[1]
		if(action.conflicts & limbs_busy)
			continue
		if(!action.trigger(src))
			continue
		limbs_busy |= action.conflicts
		ran++
		if(ran >= 3)
			break
	return ran

/datum/human_ai_brain/proc/update_tier()
	var/wanted = HAI_TIER_IDLE
	if(get_target() || waypoint || investigate_turf || (follow_ref && move_state == HAI_MOVE_WALKING) || (current_order && move_state == HAI_MOVE_WALKING) || hazard_turf)
		wanted = HAI_TIER_ENGAGED
	else if(follow_ref || current_order || alert_until > world.time)
		wanted = HAI_TIER_ALERT
	else if(intent == HAI_INTENT_ALERT || intent == HAI_INTENT_INVESTIGATE || intent == HAI_INTENT_ORDERED)
		wanted = HAI_TIER_ALERT
	else if(!keep_awake && !SSspatial_grid.has_player_near(get_turf(body)))
		wanted = HAI_TIER_DORMANT
	SShuman_ai.set_tier(src, wanted)

/datum/human_ai_brain/proc/on_error(error)
	var/message = istype(error, /exception) ? "[error:name] at [error:file]:[error:line]" : "[error]"
	error_total++
	error_times += world.time
	while(length(error_times) && error_times[1] < world.time - HAI_ERROR_WINDOW)
		error_times.Cut(1, 2)
	log_decision("error: [message]")
	if(!suppress_error_log)
		stack_trace("human_ai_brain error for [body] ([body?.type]): [message]")
	if(length(error_times) >= HAI_MAX_ERRORS)
		SShuman_ai.disabled_count++
		if(!suppress_error_log)
			message_admins("The AI of [body] was switched off after [HAI_MAX_ERRORS] errors.")
		stop(HAI_STOP_ERRORS)
