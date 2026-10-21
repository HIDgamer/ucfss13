/// A row of step triggers in the turfs that carries whoever steps on it by the vector, as the fake stairs of the ship do
/datum/unit_test/proc/make_stair(list/turf/entries, vx, vy, vz = 0)
	for(var/turf/entry as anything in entries)
		var/obj/effect/step_trigger/teleporter_vector/trigger = allocate(/obj/effect/step_trigger/teleporter_vector, entry)
		trigger.vector_x = vx
		trigger.vector_y = vy
		trigger.vector_z = vz

/// Units find their way to somewhere there is no way on foot to, by the fake stairs that lead there, on the same level and between levels
/datum/unit_test/human_ai_stairs
	var/mob/living/carbon/human/walker

/datum/unit_test/human_ai_stairs/proc/at_goal(turf/goal)
	return walker.z == goal.z && get_dist(walker, goal) <= 2

/datum/unit_test/human_ai_stairs/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/list/rows = list(
		"####################",
		"#..................#",
		"#..................#",
		"#..................#",
		"####################",
	)
	var/turf/reference = run_loc_floor_bottom_left
	var/datum/human_ai_arena/near_deck = new(rows, reference, 20, 20)
	var/datum/human_ai_arena/far_deck = new(rows, reference, 20, 60)

	// Two flights, one each way, that carry whoever steps on them forty tiles away, and come out beside the other flight and not on it
	var/list/turf/going = list()
	var/list/turf/coming = list()
	for(var/row in 1 to 3)
		going += locate(near_deck.origin_x + 16, near_deck.origin_y + row, reference.z)
		coming += locate(far_deck.origin_x + 16, far_deck.origin_y + row, reference.z)
	make_stair(going, -4, 40)
	make_stair(coming, -4, -40)
	TEST_ASSERT(length(human_ai_stair_groups()) >= 2, "The stairs were not told apart as two flights")

	walker = make_soldier(locate(near_deck.origin_x + 3, near_deck.origin_y + 2, reference.z), FACTION_MARINE, FALSE)
	var/datum/human_ai_brain/brain = walker.ai_brain
	var/turf/goal = locate(far_deck.origin_x + 4, far_deck.origin_y + 2, reference.z)
	TEST_ASSERT(!human_ai_route_exists(get_turf(walker), goal), "The other deck can be walked to, so the test proves nothing")
	TEST_ASSERT(human_ai_route_exists(get_turf(walker), going[2]), "The stair cannot be walked to")
	var/datum/npc_order/move/go = new
	go.target_turf = goal
	TEST_ASSERT(brain.give_order(go), "A move command was refused")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(at_goal), goal), 60), "The unit never reached the other deck, it is at [walker.x],[walker.y],[walker.z]: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT(brain.stairs_taken >= 1, "The stair was not counted")
	TEST_ASSERT_EQUAL(brain.error_total, 0, "The unit's brain threw errors")

	// And back again
	var/turf/home = locate(near_deck.origin_x + 5, near_deck.origin_y + 2, reference.z)
	var/datum/npc_order/move/back = new
	back.target_turf = home
	TEST_ASSERT(brain.give_order(back), "The move command back was refused")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(at_goal), home), 60), "The unit never came back to the first deck, it is at [walker.x],[walker.y],[walker.z]: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT(brain.stairs_taken >= 2, "The way back was not counted")
	detach_human_ai(walker)

	// A goal nothing leads to is given up, the unit does not go round and round the stairs
	var/mob/living/carbon/human/stranded = make_soldier(locate(near_deck.origin_x + 3, near_deck.origin_y + 3, reference.z), FACTION_MARINE, FALSE)
	var/turf/sealed_spot = locate(far_deck.origin_x + 30, far_deck.origin_y + 30, reference.z)
	var/datum/npc_order/move/hopeless = new
	hopeless.target_turf = sealed_spot
	TEST_ASSERT(stranded.ai_brain.give_order(hopeless), "The move command to nowhere was refused")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(order_over), hopeless), 40), "The order to nowhere never ended: [stranded.ai_brain.decision_log.Join(" | ")]")
	TEST_ASSERT_NOTEQUAL(hopeless.status, HAI_ORDER_DONE, "An order to a place nothing leads to was done")
	TEST_ASSERT_EQUAL(stranded.ai_brain.error_total, 0, "The stranded unit's brain threw errors")
	detach_human_ai(stranded)

/// The same between two levels, where a flight of stairs takes the unit up a level and another takes it down
/datum/unit_test/human_ai_stairs_levels
	var/mob/living/carbon/human/walker

/datum/unit_test/human_ai_stairs_levels/proc/at_goal(turf/goal)
	return walker.z == goal.z && get_dist(walker, goal) <= 2

/datum/unit_test/human_ai_stairs_levels/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/turf/lower_reference = run_loc_floor_bottom_left
	var/other_z = (lower_reference.z == world.maxz) ? lower_reference.z - 1 : lower_reference.z + 1
	TEST_ASSERT(other_z >= 1 && other_z <= world.maxz, "The test world has no second level")
	var/turf/upper_reference = locate(1, 1, other_z)
	var/list/rows = list(
		"####################",
		"#..................#",
		"#..................#",
		"#..................#",
		"####################",
	)
	var/datum/human_ai_arena/lower = new(rows, lower_reference, 20, 20)
	var/datum/human_ai_arena/upper = new(rows, upper_reference, 20, 20)
	var/list/turf/up_flight = list()
	var/list/turf/down_flight = list()
	for(var/row in 1 to 3)
		up_flight += locate(lower.origin_x + 16, lower.origin_y + row, lower_reference.z)
		down_flight += locate(upper.origin_x + 16, upper.origin_y + row, other_z)
	make_stair(up_flight, -4, 0, other_z - lower_reference.z)
	make_stair(down_flight, -4, 0, lower_reference.z - other_z)

	walker = make_soldier(locate(lower.origin_x + 3, lower.origin_y + 2, lower_reference.z), FACTION_MARINE, FALSE)
	var/datum/human_ai_brain/brain = walker.ai_brain
	var/list/found = brain.find_stair_toward(other_z)
	TEST_ASSERT_NOTNULL(found, "No stair was found toward the other level")
	TEST_ASSERT(found[1] in up_flight, "The wrong stair was chosen: [found[1]]")
	var/turf/goal = locate(upper.origin_x + 4, upper.origin_y + 2, other_z)
	var/datum/npc_order/move/go = new
	go.target_turf = goal
	TEST_ASSERT(brain.give_order(go), "A move command was refused")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(at_goal), goal), 60), "The unit never reached the other level, it is at [walker.x],[walker.y],[walker.z]: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT(brain.stairs_taken >= 1, "The stair was not counted")
	var/turf/home = locate(lower.origin_x + 5, lower.origin_y + 2, lower_reference.z)
	var/datum/npc_order/move/back = new
	back.target_turf = home
	TEST_ASSERT(brain.give_order(back), "The move command back was refused")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(at_goal), home), 60), "The unit never came back down, it is at [walker.x],[walker.y],[walker.z]: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(brain.error_total, 0, "The unit's brain threw errors")
	detach_human_ai(walker)

/// On a map that has real fake stairs, the ship, units cross each flight to the far side of it and are not carried back at once by the flight they came out beside
/datum/unit_test/human_ai_stairs_real
	var/mob/living/carbon/human/walker

/datum/unit_test/human_ai_stairs_real/proc/at_goal(turf/goal)
	return walker.z == goal.z && get_dist(walker, goal) <= 3

/datum/unit_test/human_ai_stairs_real/Run()
	var/list/groups = human_ai_stair_groups()
	log_world("STAIRS_REAL: [length(GLOB.vector_triggers)] triggers in [length(groups)] flights")
	if(length(groups) < 3)
		// The test maps have no ship with decks to go between, there is nothing to find out
		return
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/tried = 0
	var/list/report = list()
	for(var/datum/human_ai_stair_group/group as anything in groups)
		if(tried >= HAI_REAL_STAIR_SAMPLES)
			break
		var/turf/entry = group.entries[1]
		var/turf/exit = group.exit_of(entry)
		if(!exit || exit.density)
			report += "[entry.x],[entry.y],[entry.z] comes out in a wall"
			continue
		// Somewhere to start close to the stair that is not on it, and somewhere to finish a little way from where it comes out
		var/turf/start
		for(var/turf/candidate in orange(4, entry))
			if(!candidate.density && !(locate(/obj/effect/step_trigger) in candidate) && human_ai_route_exists(candidate, entry))
				start = candidate
				break
		var/turf/goal
		for(var/turf/candidate in orange(6, exit))
			if(!candidate.density && !(locate(/obj/effect/step_trigger) in candidate) && get_dist(candidate, exit) >= 4 && human_ai_route_exists(exit, candidate))
				goal = candidate
				break
		if(!start || !goal || human_ai_route_exists(start, goal))
			continue
		tried++
		walker = make_soldier(start, FACTION_MARINE, FALSE)
		var/datum/npc_order/move/go = new
		go.target_turf = goal
		walker.ai_brain.give_order(go)
		if(!ai_wait(CALLBACK(src, PROC_REF(at_goal), goal), 120))
			report += "the stair at [entry.x],[entry.y],[entry.z] to [exit.x],[exit.y],[exit.z] was not crossed from [start.x],[start.y] to [goal.x],[goal.y], the unit is at [walker.x],[walker.y],[walker.z]: [walker.ai_brain.decision_log.Join(" | ")]"
		detach_human_ai(walker)
		qdel(walker)
	log_world("STAIRS_REAL: tried [tried] flights, [length(report)] problems")
	TEST_ASSERT(!length(report), "[length(report)] of [tried] stairs on the map could not be used: [report.Join("; ")]")

/// On a map that has real ladders between its levels, units climb the first few of them to the far side and reach a goal beside the ladder they come out at
/datum/unit_test/human_ai_ladders_real
	var/mob/living/carbon/human/walker

/datum/unit_test/human_ai_ladders_real/proc/at_goal(turf/goal)
	return walker.z == goal.z && get_dist(walker, goal) <= 3

/datum/unit_test/human_ai_ladders_real/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/tried = 0
	var/list/report = list()
	var/linked_up = 0
	var/linked_down = 0
	var/other_level = 0
	for(var/obj/structure/ladder/each as anything in GLOB.ladder_list)
		if(each.up)
			linked_up++
			var/turf/above = get_turf(each.up)
			if(above && above.z != each.z)
				other_level++
		if(each.down)
			linked_down++
	log_world("LADDERS_REAL: [length(GLOB.ladder_list)] ladders, [linked_up] with one above, [linked_down] with one below, [other_level] whose one above is on another level")
	for(var/obj/structure/ladder/lower as anything in GLOB.ladder_list)
		if(tried >= HAI_REAL_STAIR_SAMPLES)
			break
		var/obj/structure/ladder/upper = lower.up
		if(QDELETED(lower) || QDELETED(upper))
			continue
		var/turf/lower_turf = get_turf(lower)
		var/turf/upper_turf = get_turf(upper)
		if(!lower_turf || !upper_turf || (lower_turf.z == upper_turf.z && get_dist(lower_turf, upper_turf) < HAI_STAIR_MIN_VECTOR))
			continue
		var/turf/start
		for(var/turf/candidate in orange(3, lower_turf))
			if(!candidate.density && human_ai_route_exists(candidate, lower_turf))
				start = candidate
				break
		var/turf/goal
		for(var/turf/candidate in orange(5, upper_turf))
			if(!candidate.density && get_dist(candidate, upper_turf) >= 3 && human_ai_route_exists(upper_turf, candidate))
				goal = candidate
				break
		if(!start || !goal)
			report += "the ladder at [lower_turf.x],[lower_turf.y],[lower_turf.z] has no floor to start from or to finish on"
			continue
		// A ladder that only saves a walk proves nothing
		if(start.z == goal.z && human_ai_route_exists(start, goal))
			continue
		tried++
		walker = make_soldier(start, FACTION_MARINE, FALSE)
		var/datum/npc_order/move/go = new
		go.target_turf = goal
		walker.ai_brain.give_order(go)
		if(!ai_wait(CALLBACK(src, PROC_REF(at_goal), goal), 120))
			report += "the ladder at [lower_turf.x],[lower_turf.y],[lower_turf.z] to [upper_turf.x],[upper_turf.y],[upper_turf.z] was not climbed from [start.x],[start.y] to [goal.x],[goal.y], the unit is at [walker.x],[walker.y],[walker.z]: [walker.ai_brain.decision_log.Join(" | ")]"
		detach_human_ai(walker)
		qdel(walker)
	log_world("LADDERS_REAL: [length(GLOB.ladder_list)] ladders, tried [tried], [length(report)] problems")
	TEST_ASSERT(!length(report), "[length(report)] of [tried] ladders on the map could not be climbed: [report.Join("; ")]")

/// Ladders that join two places of the same level, as those of a ship do, are climbed to get to a place there is no way on foot to
/datum/unit_test/human_ai_ladders_same_level
	var/mob/living/carbon/human/walker

/datum/unit_test/human_ai_ladders_same_level/proc/at_goal(turf/goal)
	return walker.z == goal.z && get_dist(walker, goal) <= 2

/datum/unit_test/human_ai_ladders_same_level/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/list/rows = list(
		"####################",
		"#..................#",
		"#..................#",
		"#..................#",
		"####################",
	)
	var/turf/reference = run_loc_floor_bottom_left
	var/datum/human_ai_arena/near_deck = new(rows, reference, 20, 100)
	var/datum/human_ai_arena/far_deck = new(rows, reference, 20, 140)
	var/obj/structure/ladder/going = allocate(/obj/structure/ladder, locate(near_deck.origin_x + 14, near_deck.origin_y + 2, reference.z))
	var/obj/structure/ladder/arriving = allocate(/obj/structure/ladder, locate(far_deck.origin_x + 14, far_deck.origin_y + 2, reference.z))
	going.height = 0
	arriving.height = 1
	going.up = arriving
	arriving.down = going

	walker = make_soldier(locate(near_deck.origin_x + 3, near_deck.origin_y + 2, reference.z), FACTION_MARINE, FALSE)
	var/datum/human_ai_brain/brain = walker.ai_brain
	var/turf/goal = locate(far_deck.origin_x + 4, far_deck.origin_y + 2, reference.z)
	TEST_ASSERT(!human_ai_route_exists(get_turf(walker), goal), "The other deck can be walked to, so the test proves nothing")
	var/datum/npc_order/move/go = new
	go.target_turf = goal
	TEST_ASSERT(brain.give_order(go), "A move command was refused")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(at_goal), goal), 60), "The unit never climbed to the other deck, it is at [walker.x],[walker.y],[walker.z]: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT(brain.ladders_climbed >= 1, "The climb was not counted")
	var/turf/home = locate(near_deck.origin_x + 5, near_deck.origin_y + 2, reference.z)
	var/datum/npc_order/move/back = new
	back.target_turf = home
	TEST_ASSERT(brain.give_order(back), "The move command back was refused")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(at_goal), home), 60), "The unit never climbed back down, it is at [walker.x],[walker.y],[walker.z]: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(brain.error_total, 0, "The unit's brain threw errors")
	detach_human_ai(walker)
