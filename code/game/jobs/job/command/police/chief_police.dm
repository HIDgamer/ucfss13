/datum/job/command/cmp
	title = JOB_CHIEF_POLICE
	selection_class = "job_cmp"
	flags_startup_parameters = ROLE_ADD_TO_DEFAULT
	gear_preset = /datum/equipment_preset/uscm_ship/uscm_police/cmp
	var/mob/living/carbon/human/active_cmp
	entry_message_body = "You are held by a higher standard and are required to obey not only the server rules but the <a href='"+URL_WIKI_LAW+"'>Marine Law</a>. Failure to do so may result in a job ban or server ban. You lead the Military Police, ensure they keep the peace and stability aboard the ship. Marines can get rowdy after a few weeks of cryosleep! In addition, you are tasked with the security of high-ranking personnel, including the command staff. Keep them safe!"

/datum/job/command/cmp/generate_entry_conditions(mob/living/M, whitelist_status)
	. = ..()
	active_cmp = M
	RegisterSignal(M, COMSIG_PARENT_QDELETING, PROC_REF(cleanup_active_cmp))

/datum/job/command/cmp/proc/cleanup_active_cmp(mob/M)
	SIGNAL_HANDLER
	active_cmp = null

AddTimelock(/datum/job/command/cmp, list(
	JOB_POLICE_ROLES = 15 HOURS,
	JOB_COMMAND_ROLES = 5 HOURS
))

/obj/effect/landmark/start/warrant
	name = JOB_CHIEF_POLICE
	job = /datum/job/command/cmp
