/**
 * What the AI owns must be freed when it is let go of. A brain, the squad it was put in, the NPC command console that selected its body and that console's selection are
 * noted by reference, then given what create_and_destroy gives the garbage collector (10 seconds, and nothing is hard deleted), and looked for again: anything still there was held
 * by something. The bodies are not deleted: a human with equipment and a hud is not freed in this game with or without an AI, which would only fill the log with reference searches.
 * Brains are let go of the ways the game does it: taken off a live body, left on one that was killed, and released from the NPC command panel.
 */
/datum/unit_test/human_ai_garbage
	/// Phase name to the list of list(ref text, type) noted for it
	var/list/noted = list()
	var/saved_check
	var/saved_harddelete

/datum/unit_test/human_ai_garbage/Destroy()
	restore_collector()
	return ..()

/// The garbage collector is given the short time create_and_destroy gives it, and nothing is hard deleted so that what is left can still be looked at
/datum/unit_test/human_ai_garbage/proc/shorten_collector()
	if(isnull(saved_check))
		saved_check = SSgarbage.collection_timeout[GC_QUEUE_CHECK]
		saved_harddelete = SSgarbage.collection_timeout[GC_QUEUE_HARDDELETE]
	SSgarbage.collection_timeout[GC_QUEUE_CHECK] = 10 SECONDS
	SSgarbage.collection_timeout[GC_QUEUE_HARDDELETE] = 10000 HOURS

/datum/unit_test/human_ai_garbage/proc/restore_collector()
	if(isnull(saved_check))
		return
	SSgarbage.collection_timeout[GC_QUEUE_CHECK] = saved_check
	SSgarbage.collection_timeout[GC_QUEUE_HARDDELETE] = saved_harddelete
	saved_check = null

/// Notes what the AI of the body owns: its brain and the squad it is in
/datum/unit_test/human_ai_garbage/proc/note_ai(phase, mob/living/carbon/human/human)
	var/datum/human_ai_brain/brain = human.ai_brain
	if(!brain)
		return
	var/list/found = noted[phase] || list()
	found += list(list(text_ref(brain), brain.type))
	if(brain.squad)
		found += list(list(text_ref(brain.squad), brain.squad.type))
	noted[phase] = found

/datum/unit_test/human_ai_garbage/proc/note_thing(phase, datum/thing)
	var/list/found = noted[phase] || list()
	found += list(list(text_ref(thing), thing.type))
	noted[phase] = found

/// What is noted for the phase and still exists, by type
/datum/unit_test/human_ai_garbage/proc/still_there(phase)
	var/list/counts = list()
	for(var/list/entry in noted[phase])
		var/datum/thing = locate(entry[1])
		if(thing && "[thing.type]" == "[entry[2]]")
			counts["[entry[2]]"] = (counts["[entry[2]]"] || 0) + 1
	return counts

/datum/unit_test/human_ai_garbage/proc/describe(list/counts)
	var/list/lines = list()
	for(var/type_name in counts)
		lines += "[type_name] x[counts[type_name]]"
	return length(lines) ? lines.Join(", ") : "nothing"

/datum/unit_test/human_ai_garbage/proc/spawn_team(datum/human_ai_arena/field, list/presets, count)
	var/list/team = list()
	for(var/index in 1 to count)
		var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human, locate(field.origin_x + 2 + index, field.origin_y + 1 + index % 4, field.z))
		arm_equipment(human, presets[1 + (index % length(presets))], TRUE, FALSE)
		if(!attach_human_ai(human, "neutral"))
			continue
		human.ai_brain.keep_awake = TRUE
		team += human
	return team

/datum/unit_test/human_ai_garbage/Run()
	var/list/presets = list("UPP Soldier", "USCM Squad Rifleman (Equipped)", "CLF Soldier", "Colonist - Security", "Weyland-Yutani PMC (Standard)", "Survivor - Scientist")
	for(var/preset in presets)
		TEST_ASSERT((preset in GLOB.gear_name_presets_list), "The test equipment preset [preset] is gone")
	shorten_collector()
	var/datum/human_ai_arena/field = new(list("######################", "#....................#", "#....................#", "#....................#", "#....................#", "######################"), run_loc_floor_bottom_left)

	// Brains and a squad that ran for a while, half of the bodies killed, and the AI taken off the rest
	var/list/team = spawn_team(field, presets, 8)
	var/mob/living/carbon/human/enemy = allocate(/mob/living/carbon/human, locate(field.origin_x + 19, field.origin_y + 3, field.z))
	enemy.faction = FACTION_MARINE
	SSspatial_grid.track(enemy, SPATIAL_GRID_TRACK_NPC)
	create_human_ai_squad(team, null, "Garbage squad")
	sleep(2 SECONDS)
	for(var/mob/living/carbon/human/human as anything in team)
		note_ai("a squad that fought", human)
	sleep(5 SECONDS)
	var/killed = 0
	for(var/mob/living/carbon/human/human as anything in team)
		if(killed++ < length(team) / 2)
			human.death(create_cause_data("unit test"))
	sleep(2 SECONDS)
	for(var/mob/living/carbon/human/human as anything in team)
		detach_human_ai(human)
	SSspatial_grid.untrack(enemy, SPATIAL_GRID_TRACK_NPC)

	// The way the admin gets them: spawned by the NPC command panel, selected there, and released from there
	var/mob/living/carbon/human/admin = allocate(/mob/living/carbon/human, locate(field.origin_x + 1, field.origin_y + 1, field.z))
	var/datum/npc_command_console/console = new(admin)
	console.access_override = TRUE
	var/list/made = console.do_spawn(admin, locate(field.origin_x + 10, field.origin_y + 3, field.z), list("job" = "UPP Soldier", "personality" = "neutral", "role" = null, "faction" = null, "count" = 6, "range" = 1, "squad" = TRUE))
	TEST_ASSERT(length(made), "The panel spawned nobody")
	for(var/mob/living/carbon/human/human as anything in made)
		human.ai_brain.keep_awake = TRUE
	sleep(3 SECONDS)
	for(var/mob/living/carbon/human/human as anything in made)
		note_ai("the panel", human)
	note_thing("the panel", console.selection)
	console.selection.select_list(made)
	TEST_ASSERT_EQUAL(length(console.selection.selected), length(made), "The panel did not select the humans it spawned")
	console.handle_action(admin, "release_ai", list())
	TEST_ASSERT_EQUAL(length(console.selection.get_selected()), 0, "The panel kept humans selected whose AI it released")
	note_thing("the panel", console)
	qdel(console)
	console = null

	SSgarbage.next_fire = 1
	sleep(SSgarbage.collection_timeout[GC_QUEUE_CHECK] + 6 SECONDS)
	SSgarbage.next_fire = 1
	sleep(4 SECONDS)

	for(var/phase in noted)
		var/list/left = still_there(phase)
		log_world("GARBAGE: [phase] left [describe(left)] of [length(noted[phase])] noted")
		TEST_ASSERT(!length(left), "[phase]: [describe(left)] were not freed, something holds them")
	restore_collector()
