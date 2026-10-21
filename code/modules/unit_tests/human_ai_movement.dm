/// Walkers cross doors, tables and barricades, stay away from locked doors and windows, and give up on unreachable goals
/datum/unit_test/human_ai_movement
	/// Turfs a walker was seen on while a scenario ran
	var/list/seen = list()
	/// The order a walker was told to follow, null when it was only sent to a waypoint
	var/datum/npc_order/move/walk_order

/datum/unit_test/human_ai_movement/proc/build(list/rows)
	var/datum/human_ai_arena/arena = new(rows, run_loc_floor_bottom_left)
	return arena

/// A walker sent to a waypoint has nothing pressing and never climbs, one that is ordered to the goal does when there is no other way
/datum/unit_test/human_ai_movement/proc/spawn_walker(turf/start, turf/goal, ordered = FALSE)
	var/mob/living/carbon/human/walker = allocate(/mob/living/carbon/human, start)
	walker.faction = FACTION_MARINE
	attach_human_ai(walker)
	walker.ai_brain.keep_awake = TRUE
	walk_order = null
	if(ordered)
		walk_order = new
		walk_order.target_turf = goal
		walker.ai_brain.give_order(walk_order)
	else
		walker.ai_brain.waypoint = goal
	return walker

/// Whether the walker has finished its trip
/datum/unit_test/human_ai_movement/proc/trip_over(mob/living/carbon/human/walker)
	if(walk_order)
		return walk_order.status != HAI_ORDER_ACTIVE
	return !walker.ai_brain?.waypoint

/// Waits until the walker is done or the time runs out, noting every turf it stood on
/datum/unit_test/human_ai_movement/proc/watch(mob/living/carbon/human/walker, seconds)
	seen = list()
	for(var/step_count in 1 to seconds * 4)
		var/turf/here = get_turf(walker)
		if(here)
			seen[here] = TRUE
		if(trip_over(walker))
			return TRUE
		sleep(2.5)
	return trip_over(walker)

/datum/unit_test/human_ai_movement/proc/log_has(mob/living/carbon/human/walker, text)
	for(var/entry in walker.ai_brain?.decision_log)
		if(findtext(entry, text))
			return TRUE
	return FALSE

/datum/unit_test/human_ai_movement/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	TEST_ASSERT(xeno_pathfind_profiles_available(), "The loaded rust-g predates route profiles")

	var/datum/human_ai_arena/maze = build(list(
		"###############",
		"#1.....L.....2#",
		"#D###########D#",
		"#.###########.#",
		"#.............#",
		"###############",
	))
	var/obj/structure/machinery/door/airlock/bolted = maze.first_door("L")
	TEST_ASSERT(bolted.locked, "The bolted door is not locked")
	var/mob/living/carbon/human/walker = spawn_walker(maze.mark("1"), maze.mark("2"))
	TEST_ASSERT(watch(walker, 40), "The walker never finished the door maze, it is at [walker.x],[walker.y] and says [walker.ai_brain.decision_log[length(walker.ai_brain.decision_log)]]")
	TEST_ASSERT(get_dist(walker, maze.mark("2")) <= 1, "The walker gave up the door maze at [walker.x],[walker.y]: [walker.ai_brain.decision_log.Join(" | ")]")
	TEST_ASSERT(!(get_turf(bolted) in seen), "The walker went through the bolted door")
	TEST_ASSERT(bolted.density && bolted.locked, "The bolted door was opened")
	detach_human_ai(walker)

	var/datum/human_ai_arena/tables = build(list(
		"###########",
		"#1.TTT...2#",
		"###########",
	))
	walker = spawn_walker(tables.mark("1"), tables.mark("2"), TRUE)
	TEST_ASSERT(watch(walker, 40), "The walker never crossed the tables, it is at [walker.x],[walker.y]")
	TEST_ASSERT(get_dist(walker, tables.mark("2")) <= 1, "The walker did not vault the tables: [walker.ai_brain.decision_log.Join(" | ")]")
	detach_human_ai(walker)

	// With nothing pressing and only a waypoint to reach the walker leaves the tables alone and gives the goal up
	var/datum/human_ai_arena/idle_tables = build(list(
		"###########",
		"#1.TTT...2#",
		"###########",
	))
	walker = spawn_walker(idle_tables.mark("1"), idle_tables.mark("2"))
	TEST_ASSERT(watch(walker, 40), "The walker never gave up on the tables, it is at [walker.x],[walker.y]")
	TEST_ASSERT(walker.x <= idle_tables.mark("1").x + 1, "The walker climbed the tables with no reason to, it is at [walker.x],[walker.y]: [walker.ai_brain.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(walker.ai_brain.vaults, 0, "The walker vaulted something with no reason to")
	detach_human_ai(walker)

	var/datum/human_ai_arena/barricades = build(list(
		"#########",
		"#1..B..2#",
		"#########",
	))
	walker = spawn_walker(barricades.mark("1"), barricades.mark("2"), TRUE)
	TEST_ASSERT(watch(walker, 40), "The walker never crossed the barricade, it is at [walker.x],[walker.y]")
	TEST_ASSERT(get_dist(walker, barricades.mark("2")) <= 1, "The walker did not vault the barricade: [walker.ai_brain.decision_log.Join(" | ")]")
	detach_human_ai(walker)

	var/datum/human_ai_arena/glass = build(list(
		"#########",
		"#1..W..2#",
		"#########",
	))
	walker = spawn_walker(glass.mark("1"), glass.mark("2"))
	TEST_ASSERT(watch(walker, 30), "The walker kept trying to reach a goal behind a window")
	TEST_ASSERT(walker.x < glass.mark("2").x - 1, "The walker got past the window")
	TEST_ASSERT(log_has(walker, "unreachable"), "The walker did not call the windowed goal unreachable: [walker.ai_brain.decision_log.Join(" | ")]")
	var/obj/structure/window/pane = locate(/obj/structure/window) in locate(glass.origin_x + 4, glass.origin_y + 1, glass.z)
	TEST_ASSERT(pane && !QDELETED(pane), "The window was broken")
	detach_human_ai(walker)

	var/datum/human_ai_arena/bolted_only = build(list(
		"#########",
		"#1..L..2#",
		"#########",
	))
	walker = spawn_walker(bolted_only.mark("1"), bolted_only.mark("2"))
	TEST_ASSERT(watch(walker, 40), "The walker kept trying to reach a goal behind a bolted door")
	TEST_ASSERT(log_has(walker, "unreachable"), "The walker did not call the bolted goal unreachable: [walker.ai_brain.decision_log.Join(" | ")]")
	TEST_ASSERT(bolted_only.first_door("L").density, "The bolted door was forced open")
	detach_human_ai(walker)

	var/datum/human_ai_arena/clearance = build(list(
		"###########",
		"#1..A....2#",
		"#D#######D#",
		"#.........#",
		"###########",
	))
	walker = spawn_walker(clearance.mark("1"), clearance.mark("2"))
	TEST_ASSERT(watch(walker, 50), "The walker never got around the door it has no access to, it is at [walker.x],[walker.y]")
	TEST_ASSERT(get_dist(walker, clearance.mark("2")) <= 1, "The walker did not detour around the restricted door: [walker.ai_brain.decision_log.Join(" | ")]")
	TEST_ASSERT(clearance.first_door("A").density, "The restricted door was opened without access")
	detach_human_ai(walker)

/// Followers keep formation slots, long walks sprint, lying bodies stand up and blocked corridors get given up on
/datum/unit_test/human_ai_following

/datum/unit_test/human_ai_following/proc/arrived(mob/living/carbon/human/walker)
	return !walker.ai_brain?.waypoint

/datum/unit_test/human_ai_following/proc/wait_until(datum/callback/check, seconds)
	for(var/waited in 1 to seconds * 4)
		if(check.Invoke())
			return TRUE
		sleep(2.5)
	return check.Invoke()

/datum/unit_test/human_ai_following/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")

	SShuman_ai.path_budget = 2
	TEST_ASSERT(SShuman_ai.take_path_budget() && SShuman_ai.take_path_budget(), "The route budget refused requests it still had")
	TEST_ASSERT(!SShuman_ai.take_path_budget(), "The route budget never ran out")
	SShuman_ai.path_budget = HAI_PATH_REQUESTS_PER_FIRE

	var/datum/human_ai_arena/hall = new(list(
		"##############",
		"#............#",
		"#.1..........#",
		"#............#",
		"##############",
	), run_loc_floor_bottom_left)
	var/mob/living/carbon/human/leader = allocate(/mob/living/carbon/human, hall.mark("1"))
	var/mob/living/carbon/human/near_follower = allocate(/mob/living/carbon/human, locate(hall.mark("1").x - 1, hall.mark("1").y, hall.mark("1").z))
	var/mob/living/carbon/human/far_follower = allocate(/mob/living/carbon/human, locate(hall.mark("1").x - 1, hall.mark("1").y + 1, hall.mark("1").z))
	for(var/mob/living/carbon/human/member as anything in list(leader, near_follower, far_follower))
		member.faction = FACTION_MARINE
		attach_human_ai(member)
		member.ai_brain.keep_awake = TRUE
	var/turf/hall_end = locate(hall.origin_x + 12, hall.mark("1").y, hall.mark("1").z)
	leader.ai_brain.waypoint = hall_end
	near_follower.ai_brain.set_follow(leader, 0)
	far_follower.ai_brain.set_follow(leader, 1)
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(arrived), leader), 25), "The leader never reached the end of the hall")
	detach_human_ai(leader)
	leader.forceMove(locate(hall_end.x - 2, hall.mark("1").y, hall.mark("1").z))
	leader.setDir(EAST)
	sleep(6 SECONDS)
	var/turf/slot_zero = near_follower.ai_brain.formation_turf(leader, 0)
	var/turf/slot_one = far_follower.ai_brain.formation_turf(leader, 1)
	TEST_ASSERT(slot_zero != slot_one, "Two formation slots collapsed onto one turf")
	TEST_ASSERT(get_dist(near_follower, slot_zero) <= 1, "The first follower is [get_dist(near_follower, slot_zero)] tiles from its slot")
	TEST_ASSERT(get_dist(far_follower, slot_one) <= 1, "The second follower is [get_dist(far_follower, slot_one)] tiles from its slot")
	TEST_ASSERT(get_dist(near_follower, leader) <= 4 && get_dist(far_follower, leader) <= 5, "The followers did not keep up with the leader")
	for(var/mob/living/carbon/human/member as anything in list(leader, near_follower, far_follower))
		detach_human_ai(member)

	var/datum/human_ai_arena/track = new(list(
		"###########################",
		"#1.......................2#",
		"###########################",
	), run_loc_floor_bottom_left)
	var/mob/living/carbon/human/runner = allocate(/mob/living/carbon/human, track.mark("1"))
	runner.faction = FACTION_MARINE
	attach_human_ai(runner)
	runner.ai_brain.keep_awake = TRUE
	runner.ai_brain.waypoint_sprint = TRUE
	runner.ai_brain.waypoint = track.mark("2")
	var/sprinted = FALSE
	for(var/waited in 1 to 160)
		sprinted ||= runner.sprinting
		if(!runner.ai_brain.waypoint)
			break
		sleep(2.5)
	TEST_ASSERT(sprinted, "The runner never sprinted along a 25 tile corridor, energy [runner.get_sprint_energy()]")
	TEST_ASSERT(get_dist(runner, track.mark("2")) <= 1, "The runner did not finish the corridor")
	TEST_ASSERT(!runner.sprinting, "The runner kept sprinting after it arrived")
	detach_human_ai(runner)

	var/datum/human_ai_arena/lane = new(list(
		"###########",
		"#1.......2#",
		"###########",
	), run_loc_floor_bottom_left)
	var/mob/living/carbon/human/sleeper = allocate(/mob/living/carbon/human, lane.mark("1"))
	sleeper.faction = FACTION_MARINE
	attach_human_ai(sleeper)
	sleeper.ai_brain.keep_awake = TRUE
	sleeper.set_resting(TRUE)
	TEST_ASSERT_EQUAL(sleeper.body_position, LYING_DOWN, "The test body did not lie down")
	sleeper.ai_brain.waypoint = lane.mark("2")
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(arrived), sleeper), 25), "The lying body never got going")
	TEST_ASSERT(get_dist(sleeper, lane.mark("2")) <= 1, "The lying body stood up but did not arrive: [sleeper.ai_brain.decision_log.Join(" | ")]")
	detach_human_ai(sleeper)

	var/datum/human_ai_arena/plugged = new(list(
		"###########",
		"#1.......2#",
		"###########",
	), run_loc_floor_bottom_left)
	var/turf/plug_turf = locate(plugged.origin_x + 4, plugged.mark("1").y, plugged.mark("1").z)
	var/mob/living/carbon/human/blocker = allocate(/mob/living/carbon/human, plug_turf)
	blocker.status_flags &= ~CANPUSH
	var/mob/living/carbon/human/stalled = allocate(/mob/living/carbon/human, plugged.mark("1"))
	stalled.faction = FACTION_MARINE
	attach_human_ai(stalled)
	stalled.ai_brain.keep_awake = TRUE
	stalled.ai_brain.waypoint = plugged.mark("2")
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(arrived), stalled), 45), "A body stuck behind a person kept trying for good")
	TEST_ASSERT(stalled.x < plug_turf.x, "The body somehow got past the person in the corridor")
	detach_human_ai(stalled)
