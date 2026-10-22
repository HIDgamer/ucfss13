/// Console actions that only an admin may use: they reach beyond the units the panel's user commands
GLOBAL_LIST_INIT(npc_command_admin_actions, list(
	"jump", "observe", "claim", "delete", "inspect",
	"apply_personality", "set_relation", "set_faction_roe", "arm_spawn", "arm_template", "release_ai", "set_difficulty",
	"set_population_enabled", "set_group_enabled", "populate_group", "set_hook_enabled", "set_hook_forced", "clear_population", "check_population",
	"toggle_debug", "set_paused",
))

/// Tabs of the panel a faction commander may open, admins have all of them
GLOBAL_LIST_INIT(npc_command_commander_tabs, list("roster", "squads", "orders"))

/// Jobs on the command staff of the ship, who may command the AI humans of their side without being a whitelisted commander: the officers, the heads of the departments and the senior enlisted
GLOBAL_LIST_INIT(npc_command_staff_jobs, list(JOB_CO, JOB_XO, JOB_SO, JOB_AUXILIARY_OFFICER, JOB_SEA, JOB_CHIEF_POLICE, JOB_WARDEN, JOB_CMO, JOB_CHIEF_ENGINEER, JOB_CHIEF_REQUISITION))

/// The job with the title, null when there is none
/proc/human_ai_job_of_title(title)
	RETURN_TYPE(/datum/job)
	if(!title)
		return null
	return GLOB.RoleAuthority?.roles_by_name[title]

/// The job of a human, null when it has none or is not one that is known
/proc/human_ai_job_of(mob/living/carbon/human/human)
	RETURN_TYPE(/datum/job)
	if(!istype(human))
		return null
	return human_ai_job_of_title(human.job)

/// Whether the job is a whitelisted commander role, the Commanding Officer or what is the equivalent in another faction
/proc/human_ai_command_job(datum/job/job)
	if(!job)
		return FALSE
	if(job.title in GLOB.npc_command_staff_jobs)
		return TRUE
	return (job.flags_startup_parameters & ROLE_WHITELISTED) && (job.flags_whitelist & HAI_COMMAND_WHITELISTS)

/**
 * The faction whose AI humans the player may command from the panel, null when they may command none. Only a living player who holds a
 * commander whitelisted job and the whitelist itself counts, and what they command is their own faction and nobody else's.
 */
/proc/human_ai_command_faction(mob/user)
	var/mob/living/carbon/human/human = user
	if(!istype(human) || !human.client || human.stat == DEAD)
		return null
	var/datum/job/job = human_ai_job_of(human)
	if(!human_ai_command_job(job) || !job.check_whitelist_status(human))
		return null
	return human.faction

/// The verb senior staff open their panel with, handed out when they spawn into their job
/mob/living/carbon/human/proc/open_npc_command_panel()
	set name = "NPC Command Panel"
	set category = "IC"
	set desc = "Give orders to the NPCs of your faction."

	if(!human_ai_command_faction(src))
		to_chat(src, SPAN_WARNING("You do not command anyone."))
		return
	open_npc_panel_for(src, NPC_PANEL_HUMANS)

/// Gives the verb to a human whose job makes them senior staff and takes it from anyone else
/mob/living/carbon/human/proc/update_npc_command_verb()
	if(human_ai_command_job(human_ai_job_of(src)))
		add_verb(src, /mob/living/carbon/human/proc/open_npc_command_panel)
	else
		remove_verb(src, /mob/living/carbon/human/proc/open_npc_command_panel)
