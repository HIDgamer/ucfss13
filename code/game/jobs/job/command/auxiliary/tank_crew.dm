/datum/job/command/tank_crew
	title = JOB_TANK_CREW
	total_positions = 2
	spawn_positions = 2
	allow_additional = TRUE
	scaled = TRUE
	supervisors = "the acting commanding officer"
	flags_startup_parameters = ROLE_ADD_TO_DEFAULT
	gear_preset = /datum/equipment_preset/uscm/tank
	entry_message_body = "Your job is to operate and maintain the ship's armored vehicles. You are in charge of representing the armored presence amongst the marines during the operation, as well as maintaining and repairing your own vehicles."

/obj/effect/landmark/start/tank_crew
	name = JOB_TANK_CREW
	job = /datum/job/command/tank_crew
