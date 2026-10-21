/// A Working Joe is told by its job and its body, carries the tools of its trade and has a voice line for everything it is meant to speak about
/datum/unit_test/human_ai_joe_kit

/datum/unit_test/human_ai_joe_kit/Run()
	TEST_ASSERT_NOTNULL(GLOB.human_ai_roles["working_joe"], "There is no Working Joe role")
	TEST_ASSERT_EQUAL(human_ai_role_for_job("Working Joe"), "working_joe", "A Working Joe is not recognized by its job")
	TEST_ASSERT_EQUAL(human_ai_role_for_job("Hazmat Joe"), "working_joe", "A Hazmat Joe is not recognized by its job")
	TEST_ASSERT_EQUAL(human_ai_role_for_job("Dzho Automaton"), "working_joe", "A Dzho Automaton is not recognized by its job")
	TEST_ASSERT_EQUAL(human_ai_role_for_job("Squad Engineer"), "engineer", "The engineer lost its role to the Joe")

	var/mob/living/carbon/human/joe = make_real_unit(run_loc_floor_bottom_left, /datum/equipment_preset/synth/working_joe)
	TEST_ASSERT_NOTNULL(joe, "The Working Joe preset took no brain")
	var/datum/human_ai_brain/brain = joe.ai_brain
	// Its own chatter is held off so that the lines counted here are the ones asked for
	brain.next_joe_quip = world.time + 10 MINUTES
	brain.next_joe_watch = world.time + 10 MINUTES
	TEST_ASSERT(isworkingjoe(joe), "The preset did not make a Working Joe")
	TEST_ASSERT_EQUAL(brain.role.id, "working_joe", "The Joe's role is [brain.role.id]")
	TEST_ASSERT_EQUAL(brain.personality.id, "synthetic", "The Joe's nature is [brain.personality.id] and not a calm one")
	TEST_ASSERT(brain.role.passive && brain.role.tolerant && brain.role.maintains && brain.role.joe_voice, "The Joe role is missing one of its traits")
	TEST_ASSERT_NOTNULL(brain.find_lightreplacer(), "The Joe has no light replacer")
	TEST_ASSERT_NOTNULL(brain.find_welder(), "The Joe has no welder")
	TEST_ASSERT_NOTNULL(brain.find_tool(TRAIT_TOOL_CROWBAR), "The Joe has no crowbar")
	TEST_ASSERT_NOTNULL(brain.find_tool(TRAIT_TOOL_SCREWDRIVER), "The Joe has no screwdriver")
	TEST_ASSERT_NOTNULL(brain.find_tool(TRAIT_TOOL_WIRECUTTERS), "The Joe has no wirecutters")
	TEST_ASSERT_NOTNULL(brain.find_item_of(/obj/item/stack/tile), "The Joe has no floor tiles")
	TEST_ASSERT_NOTNULL(brain.find_item_of(/obj/item/frame/apc), "The Joe has no spare APC frame")
	TEST_ASSERT_NOTNULL(brain.find_item_of(/obj/item/circuitboard/apc), "The Joe has no APC board")
	TEST_ASSERT_NOTNULL(brain.find_item_of(/obj/item/cell), "The Joe has no spare cell")
	TEST_ASSERT_NOTNULL(brain.find_item_of(/obj/item/stack/cable_coil), "The Joe has no cable")
	TEST_ASSERT_NOTNULL(brain.find_item_of(/obj/item/tool/mop), "The Joe has no mop")

	// It has a line for everything it talks about, and says them one at a time
	for(var/kind in GLOB.human_ai_joe_kinds)
		var/list/rule = GLOB.human_ai_joe_kinds[kind]
		TEST_ASSERT(length(brain.joe_lines(rule[2])), "A Working Joe has no voice line for [kind]")
	// Whatever it said when it was switched on does not count against it, nor does what the rest of the server has been saying
	sleep(4 SECONDS)
	brain.talk_times = list()
	brain.last_talk_time = 0
	SShuman_ai.talk_count = 0
	SShuman_ai.area_talk = list()
	var/emotes_before = brain.emotes_made
	TEST_ASSERT(brain.express(HAI_EXPR_QUIP), "The Joe would not quip")
	TEST_ASSERT_EQUAL(brain.emotes_made, emotes_before + 1, "The quip was not one of the Joe's own voice lines")
	TEST_ASSERT(!brain.express(HAI_EXPR_WARN), "The Joe spoke twice within the same breath")
	sleep(4 SECONDS)
	TEST_ASSERT(brain.express(HAI_EXPR_WARN), "The Joe would not warn")
	TEST_ASSERT(!brain.express(HAI_EXPR_COVER_ME), "The Joe shouted a call-out it has no line for")

	// The other makes of Joe have their own lines too
	for(var/preset in list(/datum/equipment_preset/synth/working_joe/engi, /datum/equipment_preset/synth/working_joe/upp))
		var/mob/living/carbon/human/other = make_real_unit(run_loc_floor_bottom_left, preset)
		TEST_ASSERT_NOTNULL(other, "[preset] took no brain")
		TEST_ASSERT_EQUAL(other.ai_brain.role.id, "working_joe", "[preset] is a [other.ai_brain.role.id] and not a Joe")
		for(var/kind in list(HAI_EXPR_QUIP, HAI_EXPR_WARN, HAI_EXPR_PAIN))
			var/list/rule = GLOB.human_ai_joe_kinds[kind]
			TEST_ASSERT(length(other.ai_brain.joe_lines(rule[2])), "[preset] has no voice line for [kind]")

	detach_human_ai(joe)

/// A Working Joe goes round putting right what is wrong with the place: a dead light, a mess, litter, a dented wall and a broken tile
/datum/unit_test/human_ai_joe_maintenance
	var/obj/structure/machinery/light/lamp
	var/obj/effect/decal/cleanable/blood/splatter/mess
	var/obj/item/trash/candy/litter
	var/turf/closed/wall/dented
	var/floor_x
	var/floor_y
	var/floor_z

/datum/unit_test/human_ai_joe_maintenance/proc/lamp_fixed()
	return lamp.status == 0

/datum/unit_test/human_ai_joe_maintenance/proc/mess_gone()
	return QDELETED(mess)

/datum/unit_test/human_ai_joe_maintenance/proc/litter_gone()
	return QDELETED(litter)

/datum/unit_test/human_ai_joe_maintenance/proc/wall_fixed()
	return dented.damage <= 0

/datum/unit_test/human_ai_joe_maintenance/proc/floor_fixed()
	var/turf/open/floor/spot = locate(floor_x, floor_y, floor_z)
	return istype(spot) && !(spot.turf_flags & (TURF_BROKEN|TURF_BURNT)) && !spot.is_plating()

/datum/unit_test/human_ai_joe_maintenance/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/datum/human_ai_arena/hall = new(list(
		"##############",
		"#............#",
		"#............#",
		"#............#",
		"#............#",
		"##############",
	), run_loc_floor_bottom_left)
	lamp = new(locate(hall.origin_x + 3, hall.origin_y + 4, hall.z))
	lamp.broken(TRUE)
	TEST_ASSERT(lamp.status != 0, "The light would not break")
	mess = new(locate(hall.origin_x + 9, hall.origin_y + 3, hall.z))
	litter = new(locate(hall.origin_x + 10, hall.origin_y + 1, hall.z))
	dented = locate(hall.origin_x + 6, hall.origin_y + 5, hall.z)
	dented.take_damage(80)
	TEST_ASSERT(dented.damage > 0, "The wall took no damage")
	floor_x = hall.origin_x + 3
	floor_y = hall.origin_y + 1
	floor_z = hall.z
	var/turf/open/floor/cracked = locate(floor_x, floor_y, floor_z)
	cracked.turf_flags |= TURF_BROKEN

	var/mob/living/carbon/human/joe = make_real_unit(locate(hall.origin_x + 6, hall.origin_y + 2, hall.z), /datum/equipment_preset/synth/working_joe)
	TEST_ASSERT_NOTNULL(joe, "The Working Joe preset took no brain")
	var/datum/human_ai_brain/brain = joe.ai_brain
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(lamp_fixed)), 90), "The dead light was never replaced: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(mess_gone)), 90), "The mess on the floor was never cleaned: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(litter_gone)), 90), "The litter was never swept up: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(wall_fixed)), 90), "The dented wall was never welded, damage [dented.damage]: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(floor_fixed)), 90), "The broken tile was never replaced: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT(brain.maint_done >= 5, "Only [brain.maint_done] jobs were counted: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(brain.error_total, 0, "The Joe's brain threw errors")
	// Nothing is left lit or in the hands when the work is done
	sleep(3 SECONDS)
	for(var/obj/item/tool/weldingtool/welder in joe.get_contents())
		TEST_ASSERT(!welder.welding, "The Joe left its welder lit")
	detach_human_ai(joe)

/// A Working Joe puts an APC right whatever is wrong with it: a cover left open, no cell in it, a cut wire or a burnt out board and frame
/datum/unit_test/human_ai_joe_apc
	var/obj/structure/machinery/power/apc/panel
	var/panel_x
	var/panel_y
	var/panel_z

/datum/unit_test/human_ai_joe_apc/proc/closed_with_cell()
	return !QDELETED(panel) && !panel.opened && panel.cell && !(panel.stat & BROKEN)

/datum/unit_test/human_ai_joe_apc/proc/wires_whole()
	return !QDELETED(panel) && !panel.isWireCut(1) && !panel.isWireCut(2)

/datum/unit_test/human_ai_joe_apc/proc/rebuilt()
	var/turf/under = locate(panel_x, panel_y, panel_z)
	return closed_with_cell() && panel.terminal && panel.has_electronics == 2 && under.intact_tile

/datum/unit_test/human_ai_joe_apc/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/datum/human_ai_arena/plant = new(list(
		"############",
		"#..........#",
		"#..........#",
		"#..........#",
		"############",
	), run_loc_floor_bottom_left)
	panel_x = plant.origin_x + 6
	panel_y = plant.origin_y + 3
	panel_z = plant.z
	panel = new(locate(panel_x, panel_y, panel_z))
	TEST_ASSERT(closed_with_cell() && panel.terminal && panel.has_electronics == 2, "The APC did not start out whole")
	var/mob/living/carbon/human/joe = make_real_unit(locate(plant.origin_x + 3, plant.origin_y + 2, plant.z), /datum/equipment_preset/synth/working_joe)
	TEST_ASSERT_NOTNULL(joe, "The Working Joe preset took no brain")
	var/datum/human_ai_brain/brain = joe.ai_brain

	// The cover is left open
	panel.opened = 1
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(closed_with_cell)), 60), "The open APC cover was never shut: [brain.decision_log.Join(" | ")]")

	// A cut wire
	panel.cut(1)
	TEST_ASSERT(panel.isWireCut(1), "The wire would not cut")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(wires_whole)), 60), "The cut wire was never mended: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT(!panel.wiresexposed, "The panel was left open after the wire was mended")

	// The cell is gone
	qdel(panel.cell)
	panel.cell = null
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(closed_with_cell)), 60), "The missing cell was never replaced: [brain.decision_log.Join(" | ")]")

	// Broken right through
	panel.do_set_broken()
	TEST_ASSERT(panel.stat & BROKEN, "The APC would not break")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(rebuilt)), 150), "The broken APC was never rebuilt, broken [!!(panel.stat & BROKEN)] open [panel.opened] board [panel.has_electronics] cell [!!panel.cell] terminal [!!panel.terminal]: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT(brain.maint_done >= 4, "Only [brain.maint_done] jobs were counted: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(brain.error_total, 0, "The Joe's brain threw errors")
	detach_human_ai(joe)

/// A Working Joe warns people and puts up with a good deal, and fights back once it has been bothered too much
/datum/unit_test/human_ai_joe_patience

/datum/unit_test/human_ai_joe_patience/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/datum/human_ai_arena/yard = new(list(
		"############",
		"#..........#",
		"#..........#",
		"#..........#",
		"############",
	), run_loc_floor_bottom_left)
	var/mob/living/carbon/human/joe = make_real_unit(locate(yard.origin_x + 4, yard.origin_y + 2, yard.z), /datum/equipment_preset/synth/working_joe)
	TEST_ASSERT_NOTNULL(joe, "The Working Joe preset took no brain")
	var/mob/living/carbon/human/pest = make_soldier(locate(yard.origin_x + 5, yard.origin_y + 2, yard.z), FACTION_MARINE, FALSE)
	detach_human_ai(pest)
	var/datum/human_ai_brain/brain = joe.ai_brain

	// It tells somebody who runs past to slow down
	pest.sprinting = TRUE
	brain.next_joe_watch = 0
	brain.watch_people()
	TEST_ASSERT(brain.joe_noticed[REF(pest)], "The Joe let somebody running past it go without a word")
	pest.sprinting = FALSE

	// Hits from somebody it is not at war with are warned about, a few in a row are too many
	pest.a_intent = INTENT_HARM
	var/hits = 0
	for(var/attempt in 1 to 8)
		sleep(1 SECONDS)
		brain.signal_take_damage(null, null, BRUTE)
		hits++
		if(brain.holds_grudge_against(pest))
			break
		TEST_ASSERT(brain.barks >= 1, "The Joe took a hit without a word of warning")
	TEST_ASSERT(brain.holds_grudge_against(pest), "The Joe never lost its patience, after [hits] hits")
	TEST_ASSERT(hits >= 2 && hits <= 5, "The Joe lost its patience after [hits] hits")
	TEST_ASSERT_EQUAL(brain.escalations, 1, "The Joe's change of heart was not counted")

	// And then it fights back, it does not have to be armed for it
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(pest_hurt), pest), 40), "The Joe never hit back: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(brain.error_total, 0, "The Joe's brain threw errors")
	detach_human_ai(joe)

/datum/unit_test/human_ai_joe_patience/proc/pest_hurt(mob/living/carbon/human/pest)
	return pest.getBruteLoss() > 0
