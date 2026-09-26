/datum/job/civilian/synthetic
	title = JOB_SYNTH
	total_positions = 2
	spawn_positions = 1
	allow_additional = 1
	scaled = 1
	supervisors = "the acting commanding officer"
	selection_class = "job_synth"
	flags_startup_parameters = ROLE_ADD_TO_DEFAULT|ROLE_ADMIN_NOTIFY|ROLE_WHITELISTED|ROLE_CUSTOM_SPAWN
	flags_whitelist = WHITELIST_SYNTHETIC
	gear_preset = /datum/equipment_preset/synth/uscm
	entry_message_body = "You are a <a href='"+WIKI_PLACEHOLDER+"'>Synthetic!</a> You are held to a higher standard and are required to obey not only the Server Rules but Marine Law and Synthetic Rules. Failure to do so may result in your White-list Removal. Your primary job is to support and assist all USCM Departments and Personnel on-board. In addition, being a Synthetic gives you knowledge in every field and specialization possible on-board the ship. As a Synthetic you answer to the acting commanding officer. Special circumstances may change this!"

/datum/job/civilian/synthetic/New()
	. = ..()
	gear_preset_whitelist = list(
		"[JOB_SYNTH][WHITELIST_NORMAL]" = /datum/equipment_preset/synth/uscm,
		"[JOB_SYNTH][WHITELIST_COUNCIL]" = /datum/equipment_preset/synth/uscm/councillor,
		"[JOB_SYNTH][WHITELIST_LEADER]" = /datum/equipment_preset/synth/uscm/councillor
	)

/datum/job/civilian/synthetic/get_whitelist_status(client/player)
	. = ..()
	if(!.)
		return

	if(player.check_whitelist_status(WHITELIST_SYNTHETIC_LEADER))
		return get_desired_status(player.prefs.synth_status, WHITELIST_LEADER)
	if(player.check_whitelist_status(WHITELIST_SYNTHETIC_COUNCIL|WHITELIST_SYNTHETIC_COUNCIL_LEGACY))
		return get_desired_status(player.prefs.synth_status, WHITELIST_COUNCIL)
	if(player.check_whitelist_status(WHITELIST_SYNTHETIC))
		return get_desired_status(player.prefs.synth_status, WHITELIST_NORMAL)

/datum/job/civilian/synthetic/set_spawn_positions(count)
	spawn_positions = synth_slot_formula(count)

/datum/job/civilian/synthetic/get_total_positions(latejoin = 0)
	var/positions = spawn_positions
	if(latejoin)
		positions = synth_slot_formula(get_total_marines())
		if(positions <= total_positions_so_far)
			positions = total_positions_so_far
		else
			total_positions_so_far = positions
	else
		total_positions_so_far = positions
	return positions

/datum/job/civilian/synthetic/generate_entry_conditions(mob/living/M, whitelist_status)
	. = ..()
	// Synthetics are command staff: register them the moment they spawn so command consoles
	// (e.g. the groundside operations console's Command roster) list them right away.
	if(!islist(GLOB.marine_leaders[JOB_SYNTH]))
		GLOB.marine_leaders[JOB_SYNTH] = list()
	GLOB.marine_leaders[JOB_SYNTH] += M
	RegisterSignal(M, COMSIG_PARENT_QDELETING, PROC_REF(cleanup_leader_candidate))

/datum/job/civilian/synthetic/proc/cleanup_leader_candidate(mob/M)
	SIGNAL_HANDLER
	GLOB.marine_leaders[JOB_SYNTH] -= M

/obj/effect/landmark/start/synthetic
	name = JOB_SYNTH
	icon_state = "syn_spawn"
	job = /datum/job/civilian/synthetic
