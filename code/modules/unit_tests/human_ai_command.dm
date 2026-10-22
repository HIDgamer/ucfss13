/// A console owned by a plain human that the test treats as an admin
/datum/unit_test/proc/make_console(mob/living/carbon/human/admin)
	var/datum/npc_command_console/console = new(admin)
	console.access_override = TRUE
	return console

/// Selection keeps only commandable AI humans, a console without rights does nothing, a box selects what stands in it
/datum/unit_test/human_ai_command_selection
	var/datum/npc_command_console/console

/datum/unit_test/human_ai_command_selection/Destroy()
	QDEL_NULL(console)
	return ..()

/datum/unit_test/human_ai_command_selection/Run()
	var/datum/human_ai_arena/yard = new(list(
		"####################",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"####################",
	), run_loc_floor_bottom_left)
	var/mob/living/carbon/human/admin = allocate(/mob/living/carbon/human, pick(yard.floors))
	console = make_console(admin)
	var/list/crowd = list()
	for(var/index in 1 to 6)
		crowd += make_soldier(locate(yard.origin_x + 2 + index, yard.origin_y + 2, yard.z), FACTION_MARINE, FALSE)
	TEST_ASSERT_EQUAL(console.selection.select_list(crowd), 6, "Not every AI human could be selected")

	var/mob/living/carbon/human/dying = crowd[1]
	dying.stat = DEAD
	qdel(crowd[2])
	detach_human_ai(crowd[3])
	TEST_ASSERT_EQUAL(length(console.selection.get_selected()), 3, "The selection kept the dead, the deleted or a human with no brain")

	var/mob/living/carbon/human/bystander = allocate(/mob/living/carbon/human, pick(yard.floors))
	TEST_ASSERT(!console.selection.select(bystander), "A human with no brain was selected")

	console.selection.clear()
	var/turf/corner_a = locate(yard.origin_x + 3, yard.origin_y + 1, yard.z)
	var/turf/corner_b = locate(yard.origin_x + 12, yard.origin_y + 3, yard.z)
	TEST_ASSERT_EQUAL(console.select_box(corner_a, corner_b), 3, "The box did not select the three AI humans standing in it")

	console.selection.clear()
	TEST_ASSERT(console.handle_action(admin, "select_all", list()), "Select all did nothing")
	TEST_ASSERT_EQUAL(length(console.selection.selected), 3, "Select all missed someone")
	console.handle_action(admin, "select_none", list())
	TEST_ASSERT_EQUAL(length(console.selection.selected), 0, "Select none left a selection")

	var/datum/npc_command_console/locked = new(admin)
	TEST_ASSERT(!locked.handle_action(admin, "select_all", list()), "A console without rights took an action")
	TEST_ASSERT_EQUAL(length(locked.selection.selected), 0, "A console without rights selected someone")
	TEST_ASSERT(!locked.InterceptClickOn(admin, "right=1", pick(yard.floors)), "A console without rights took a click")
	TEST_ASSERT(isnull(locked.send_order(admin, "move", null, pick(yard.floors))), "A console without a selection sent an order")
	qdel(locked)

/// Six AI humans take every kind of order as a command, the stances and the right click work, delayed and armed orders go out
/datum/unit_test/human_ai_command_orders
	var/datum/npc_command_console/console

/datum/unit_test/human_ai_command_orders/Destroy()
	QDEL_NULL(console)
	return ..()

/datum/unit_test/human_ai_command_orders/proc/all_near(list/team, atom/where, range)
	for(var/mob/living/carbon/human/member as anything in team)
		if(get_dist(member, where) > range)
			return FALSE
	return TRUE

/datum/unit_test/human_ai_command_orders/proc/all_targeting(list/team, mob/living/victim)
	for(var/mob/living/carbon/human/member as anything in team)
		if(member.ai_brain.get_target() != victim)
			return FALSE
	return TRUE

/datum/unit_test/human_ai_command_orders/proc/all_ordered(list/team, order_id)
	for(var/mob/living/carbon/human/member as anything in team)
		if(member.ai_brain.current_order?.id != order_id)
			return FALSE
	return TRUE

/datum/unit_test/human_ai_command_orders/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/list/rows = list("##################################################")
	for(var/row in 1 to 8)
		rows += "#................................................#"
	rows += "##################################################"
	var/datum/human_ai_arena/field = new(rows, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/admin = allocate(/mob/living/carbon/human, locate(field.origin_x + 22, field.origin_y + 4, field.z))
	console = make_console(admin)
	var/list/mob/living/carbon/human/team = list()
	for(var/index in 1 to 6)
		var/mob/living/carbon/human/soldier = make_soldier(locate(field.origin_x + 3, field.origin_y + 1 + index, field.z), FACTION_MARINE, TRUE)
		team += soldier
	TEST_ASSERT_EQUAL(console.selection.select_list(team), 6, "The team was not selectable")

	var/turf/goal = locate(field.origin_x + 12, field.origin_y + 4, field.z)
	var/list/result = console.dispatch_order(admin, console.selection.get_selected(), "move", null, goal)
	TEST_ASSERT_EQUAL(result["accepted"], 6, "Not every unit took the move order: [console.last_report]")
	TEST_ASSERT(all_ordered(team, "move"), "A unit has another order than move")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(all_near), team, goal, 6), 30), "The team did not get to the move point")

	result = console.dispatch_order(admin, console.selection.get_selected(), "hold")
	TEST_ASSERT_EQUAL(result["accepted"], 6, "Not every unit took the hold order")
	TEST_ASSERT(all_ordered(team, "hold"), "A unit has another order than hold")
	var/list/spots = list()
	for(var/mob/living/carbon/human/member as anything in team)
		spots[member] = get_turf(member)
	sleep(3 SECONDS)
	for(var/mob/living/carbon/human/member as anything in team)
		TEST_ASSERT_EQUAL(get_turf(member), spots[member], "A unit moved while holding")

	result = console.dispatch_order(admin, console.selection.get_selected(), "follow", admin)
	TEST_ASSERT_EQUAL(result["accepted"], 6, "Not every unit took the follow order")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(all_near), team, admin, 7), 40), "The team did not follow the admin")

	var/mob/living/carbon/xenomorph/drone/dummy = make_target_dummy(locate(field.origin_x + 44, field.origin_y + 4, field.z))
	result = console.dispatch_order(admin, console.selection.get_selected(), "attack", dummy)
	TEST_ASSERT_EQUAL(result["accepted"], 6, "Not every unit took the attack order")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(all_targeting), team, dummy), 20), "The team did not turn on the target")

	var/turf/rear = locate(field.origin_x + 3, field.origin_y + 4, field.z)
	result = console.dispatch_order(admin, console.selection.get_selected(), "fall_back", null, rear)
	TEST_ASSERT_EQUAL(result["accepted"], 6, "Not every unit took the fall back order")
	TEST_ASSERT(all_ordered(team, "fall_back"), "A unit has another order than fall back")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(all_near), team, rear, 7), 40), "The team did not fall back")

	console.handle_action(admin, "cancel_orders", list())
	for(var/mob/living/carbon/human/member as anything in team)
		TEST_ASSERT_NULL(member.ai_brain.current_order, "An order survived the cancel")

	console.order_cooldowns.Cut()
	TEST_ASSERT(console.InterceptClickOn(admin, "right=1", goal), "The right click on a turf was not taken")
	TEST_ASSERT(all_ordered(team, "move"), "A right click on a turf did not send a move order")
	console.order_cooldowns.Cut()
	TEST_ASSERT(console.InterceptClickOn(admin, "right=1", dummy), "The right click on an enemy was not taken")
	TEST_ASSERT(all_ordered(team, "attack"), "A right click on an enemy did not send an attack order")
	console.order_cooldowns.Cut()
	var/mob/living/carbon/human/friend = make_soldier(locate(field.origin_x + 20, field.origin_y + 7, field.z), FACTION_MARINE, FALSE)
	TEST_ASSERT(console.InterceptClickOn(admin, "right=1", friend), "The right click on a friend was not taken")
	TEST_ASSERT(all_ordered(team, "follow"), "A right click on a friend did not send a follow order")
	TEST_ASSERT(isnull(console.send_order(admin, "follow", friend, get_turf(friend))), "Orders of one kind were not rate limited")
	TEST_ASSERT(!console.InterceptClickOn(admin, "left=1", goal), "A plain left click was taken")

	console.order_cooldowns.Cut()
	console.handle_action(admin, "cancel_orders", list())
	console.handle_action(admin, "order", list("order" = "patrol"))
	TEST_ASSERT_EQUAL(console.armed_order, "patrol", "The order was not armed")
	TEST_ASSERT(console.wants_intercept(), "An armed console would not take the click")
	TEST_ASSERT(console.InterceptClickOn(admin, "left=1", goal), "The armed order did not take the click")
	TEST_ASSERT_NULL(console.armed_order, "The armed order stayed armed")
	var/leader_orders = 0
	for(var/mob/living/carbon/human/member as anything in team)
		if(member.ai_brain.current_order?.id == "patrol")
			leader_orders++
	TEST_ASSERT_EQUAL(leader_orders, 6, "Not every unit got the patrol order")

	console.order_cooldowns.Cut()
	console.handle_action(admin, "cancel_orders", list())
	console.handle_action(admin, "order", list("order" = "hold", "delay" = 2))
	for(var/mob/living/carbon/human/member as anything in team)
		TEST_ASSERT_NULL(member.ai_brain.current_order, "A delayed order went out at once")
	sleep(4 SECONDS)
	TEST_ASSERT(all_ordered(team, "hold"), "The delayed order never went out")

	var/squad_size = 3
	var/list/trio = team.Copy(1, squad_size + 1)
	console.selection.clear()
	console.selection.select_list(trio)
	console.handle_action(admin, "create_squad", list("name" = "Panel Squad"))
	var/datum/human_ai_squad/made = team[1].ai_brain.squad
	TEST_ASSERT_NOTNULL(made, "The squad was not made")
	TEST_ASSERT_EQUAL(length(made.members), squad_size, "The squad has the wrong size")
	console.order_cooldowns.Cut()
	result = console.dispatch_order(admin, console.selection.get_selected(), "move", null, goal)
	TEST_ASSERT_EQUAL(result["accepted"], squad_size, "The squad did not take the order together")
	console.handle_action(admin, "set_formation", list("formation" = HAI_FORM_LINE))
	TEST_ASSERT_EQUAL(made.formation, HAI_FORM_LINE, "The formation was not set")
	TEST_ASSERT(made.formation_locked, "The formation was not locked")
	console.handle_action(admin, "leave_squad", list())
	TEST_ASSERT_NULL(team[1].ai_brain.squad, "The unit stayed in the squad")
	qdel(dummy)

/// A request to advance into fire is refused by the timid and accepted by the fanatic, a command is obeyed by both
/datum/unit_test/human_ai_command_requests
	var/datum/npc_command_console/console

/datum/unit_test/human_ai_command_requests/Destroy()
	QDEL_NULL(console)
	return ..()

/datum/unit_test/human_ai_command_requests/proc/tally(mob/living/carbon/human/unit, mob/living/victim, request, tries)
	var/obeyed = 0
	for(var/attempt in 1 to tries)
		var/list/result = console.dispatch_order(null, list(unit), "attack", victim, null, request)
		obeyed += result["accepted"]
	return obeyed

/datum/unit_test/human_ai_command_requests/Run()
	var/datum/human_ai_arena/yard = new(list(
		"####################",
		"#..................#",
		"#..................#",
		"#..................#",
		"####################",
	), run_loc_floor_bottom_left)
	var/mob/living/carbon/human/admin = allocate(/mob/living/carbon/human, pick(yard.floors))
	console = make_console(admin)
	var/mob/living/carbon/human/skittish = make_soldier(locate(yard.origin_x + 3, yard.origin_y + 1, yard.z), FACTION_MARINE, TRUE, "skittish")
	var/mob/living/carbon/human/zealot = make_soldier(locate(yard.origin_x + 3, yard.origin_y + 3, yard.z), FACTION_MARINE, TRUE, "zealot")
	var/mob/living/carbon/xenomorph/drone/dummy = make_target_dummy(locate(yard.origin_x + 16, yard.origin_y + 2, yard.z))
	skittish.ai_brain.stress = 50
	var/datum/npc_order/probe = console.build_order("attack", dummy, null)
	probe.delivery = HAI_DELIVERY_REQUEST
	TEST_ASSERT(skittish.ai_brain.comply_chance(probe) < 0.3, "A frightened skittish unit is not likely to refuse: [skittish.ai_brain.comply_chance(probe)]")
	TEST_ASSERT(zealot.ai_brain.comply_chance(probe) > 0.9, "A zealot is not near certain to comply: [zealot.ai_brain.comply_chance(probe)]")
	qdel(probe)

	TEST_ASSERT_EQUAL(tally(skittish, dummy, FALSE, 10), 10, "A command was refused")
	TEST_ASSERT_EQUAL(tally(zealot, dummy, FALSE, 10), 10, "A command was refused")
	var/skittish_yes = tally(skittish, dummy, TRUE, 30)
	var/zealot_yes = tally(zealot, dummy, TRUE, 30)
	TEST_ASSERT(skittish_yes <= 15, "The skittish unit went along with [skittish_yes] of 30 requests to attack")
	TEST_ASSERT(zealot_yes >= 24, "The zealot only went along with [zealot_yes] of 30 requests to attack")
	TEST_ASSERT(skittish.ai_brain.orders_refused > 0 && console.orders_refused > 0, "The refusals were not counted")
	qdel(dummy)

/// Squads, personalities, postures, relations, spawning, difficulty, pause and closing the window
/datum/unit_test/human_ai_command_panel
	var/datum/npc_command_console/console

/datum/unit_test/human_ai_command_panel/Destroy()
	QDEL_NULL(console)
	return ..()

/datum/unit_test/human_ai_command_panel/Run()
	var/datum/human_ai_arena/yard = new(list(
		"########################",
		"#......................#",
		"#......................#",
		"#......................#",
		"#......................#",
		"#......................#",
		"########################",
	), run_loc_floor_bottom_left)
	var/mob/living/carbon/human/admin = allocate(/mob/living/carbon/human, pick(yard.floors))
	console = make_console(admin)
	var/mob/living/carbon/human/first = make_soldier(locate(yard.origin_x + 3, yard.origin_y + 1, yard.z), FACTION_MARINE, TRUE)
	var/mob/living/carbon/human/second = make_soldier(locate(yard.origin_x + 3, yard.origin_y + 3, yard.z), FACTION_PMC, TRUE)
	console.selection.select(first)

	console.handle_action(admin, "apply_personality", list("preset" = "reckless", "jitter" = 0, "traits" = list("courage" = 12)))
	TEST_ASSERT_EQUAL(first.ai_brain.personality.id, "reckless", "The personality preset was not applied")
	TEST_ASSERT_EQUAL(first.ai_brain.personality.trait("courage"), 12, "The trait slider was not applied")
	var/reckless_aggression = first.ai_brain.personality.trait("aggression")
	console.handle_action(admin, "set_posture", list("posture" = HAI_POSTURE_CAUTIOUS))
	TEST_ASSERT(first.ai_brain.personality.trait("aggression") < reckless_aggression, "A cautious posture did not lower aggression")
	TEST_ASSERT(first.ai_brain.personality.trait("caution") > get_human_ai_personality("reckless").trait("caution"), "A cautious posture did not raise caution")
	console.handle_action(admin, "set_posture", list("posture" = HAI_POSTURE_NORMAL))
	TEST_ASSERT_EQUAL(first.ai_brain.personality.trait("aggression"), reckless_aggression, "The personality did not come back after the posture")

	console.handle_action(admin, "set_roe", list("roe" = HAI_ROE_WEAPONS_HOLD))
	TEST_ASSERT_EQUAL(first.ai_brain.roe, HAI_ROE_WEAPONS_HOLD, "The rules of engagement were not set")
	console.handle_action(admin, "set_roe", list("roe" = 99))
	TEST_ASSERT_EQUAL(first.ai_brain.roe, HAI_ROE_WEAPONS_HOLD, "A bad rules of engagement value got through")
	console.handle_action(admin, "set_move_cap", list("cap" = HAI_MOVE_CAP_WALK))
	TEST_ASSERT_EQUAL(first.ai_brain.move_cap, HAI_MOVE_CAP_WALK, "The movement cap was not set")
	var/turf/far = locate(yard.origin_x + 20, yard.origin_y + 1, yard.z)
	first.ai_brain.move_to(far, 0, TRUE)
	TEST_ASSERT_EQUAL(first.m_intent, MOVE_INTENT_WALK, "A walk only unit was not walking")
	TEST_ASSERT(!first.sprinting, "A walk only unit sprinted")
	console.handle_action(admin, "set_move_cap", list("cap" = HAI_MOVE_CAP_SPRINT))
	console.handle_action(admin, "set_lights", list("dark" = 1))
	TEST_ASSERT(first.ai_brain.lights_out, "The selected were not told to run dark")
	console.handle_action(admin, "set_lights", list("dark" = 0))
	TEST_ASSERT(!first.ai_brain.lights_out, "The selected were not told to use their lights again")

	var/faction_before = human_ai_faction_relation(FACTION_MARINE, FACTION_PMC)
	var/datum/human_ai_brain/marine_brain = first.ai_brain
	TEST_ASSERT(marine_brain.get_disposition(second) < HAI_DISP_HOSTILE, "The two sides started hostile")
	console.handle_action(admin, "set_relation", list("faction" = FACTION_MARINE, "other" = FACTION_PMC, "relation" = HAI_REL_HOSTILE, "mirror" = TRUE))
	TEST_ASSERT_EQUAL(human_ai_faction_relation(FACTION_MARINE, FACTION_PMC), HAI_REL_HOSTILE, "The relation was not set")
	TEST_ASSERT_EQUAL(human_ai_faction_relation(FACTION_PMC, FACTION_MARINE), HAI_REL_HOSTILE, "The mirrored relation was not set")
	TEST_ASSERT_EQUAL(marine_brain.get_disposition(second), HAI_DISP_HOSTILE, "The relation did not change how a brain sees the other side")
	console.handle_action(admin, "set_relation", list("faction" = FACTION_MARINE, "other" = "not a faction", "relation" = HAI_REL_HOSTILE))
	console.handle_action(admin, "set_relation", list("faction" = FACTION_MARINE, "other" = FACTION_PMC, "relation" = faction_before, "mirror" = TRUE))
	TEST_ASSERT_EQUAL(human_ai_faction_relation(FACTION_MARINE, FACTION_PMC), faction_before, "The relation was not put back")
	var/roe_before = human_ai_default_roe(FACTION_PMC)
	console.handle_action(admin, "set_faction_roe", list("faction" = FACTION_PMC, "roe" = HAI_ROE_NONLETHAL_ONLY, "existing" = TRUE))
	TEST_ASSERT_EQUAL(second.ai_brain.roe, HAI_ROE_NONLETHAL_ONLY, "The faction rules did not reach its units")
	GLOB.human_ai_faction_roe -= FACTION_PMC
	if(roe_before != HAI_ROE_WEAPONS_FREE)
		GLOB.human_ai_faction_roe[FACTION_PMC] = roe_before

	var/aim_before = SShuman_ai.aim_error_mult
	var/reaction_before = SShuman_ai.reaction_mult
	var/full_before = SShuman_ai.max_full
	var/total_before = SShuman_ai.max_total
	var/detection_before = SShuman_ai.detection_mult
	var/markers_before = SShuman_ai.stealth_cues
	console.handle_action(admin, "set_difficulty", list("detection" = 9, "markers" = 1))
	TEST_ASSERT_EQUAL(SShuman_ai.detection_mult, 4, "Detection was not clamped")
	TEST_ASSERT(SShuman_ai.stealth_cues, "The panel could not switch the markers on")
	console.handle_action(admin, "set_difficulty", list("detection" = 0, "markers" = 0))
	TEST_ASSERT_EQUAL(SShuman_ai.detection_mult, 0.25, "Detection was not held to its lowest")
	TEST_ASSERT(!SShuman_ai.stealth_cues, "The panel could not switch the markers off")
	console.handle_action(admin, "set_difficulty", list("detection" = detection_before, "markers" = markers_before))
	console.handle_action(admin, "set_difficulty", list("aim_error" = 9, "reaction" = 0, "aggression" = 0.5, "max_full" = 9999, "max_total" = -5))
	TEST_ASSERT_EQUAL(SShuman_ai.aim_error_mult, 4, "Aim error was not clamped")
	TEST_ASSERT_EQUAL(SShuman_ai.reaction_mult, 0.25, "Reaction was not clamped")
	TEST_ASSERT_EQUAL(SShuman_ai.max_full, 9999, "The full fidelity cap was held to a limit that is not there any more")
	TEST_ASSERT_EQUAL(SShuman_ai.max_total, 0, "A negative total cap was not taken for no limit")
	console.handle_action(admin, "set_difficulty", list("max_full" = 0))
	TEST_ASSERT_EQUAL(SShuman_ai.max_full, 1, "The full fidelity cap went below one")
	TEST_ASSERT(first.ai_brain.personality.trait("aggression") > reckless_aggression, "The global aggression did not reach the units")
	console.handle_action(admin, "set_difficulty", list("aim_error" = aim_before, "reaction" = reaction_before, "aggression" = 0, "max_full" = full_before, "max_total" = total_before))
	TEST_ASSERT_EQUAL(first.ai_brain.personality.trait("aggression"), reckless_aggression, "The aggression did not come back")

	var/thinks = SShuman_ai.total_thinks
	console.handle_action(admin, "set_paused", list("paused" = TRUE))
	sleep(1 SECONDS)
	var/frozen = SShuman_ai.total_thinks
	sleep(2 SECONDS)
	TEST_ASSERT_EQUAL(SShuman_ai.total_thinks, frozen, "The brains thought while paused")
	console.handle_action(admin, "set_paused", list("paused" = FALSE))
	sleep(2 SECONDS)
	TEST_ASSERT(SShuman_ai.total_thinks > frozen, "The brains never woke after the pause (was [thinks])")

	console.armed_order = "move"
	console.selecting_mode = TRUE
	console.pending_spawn = list("job" = "x")
	console.ui_close(admin)
	TEST_ASSERT(isnull(console.armed_order) && !console.selecting_mode && isnull(console.pending_spawn), "Closing the window left the console armed")

	var/spawn_job = "USCM Squad Rifleman (Equipped)"
	TEST_ASSERT(spawn_job in GLOB.gear_name_presets_list, "The test equipment preset is gone")
	console.selection.clear()
	var/known_before = length(GLOB.ai_human_list)
	console.handle_action(admin, "arm_spawn", list("job" = spawn_job, "personality" = "veteran", "role" = "medic", "faction" = FACTION_PMC, "count" = 4, "range" = 2, "squad" = TRUE))
	TEST_ASSERT_NOTNULL(console.pending_spawn, "The spawn was not armed")
	TEST_ASSERT(console.wants_intercept(), "An armed spawn would not take the click")
	TEST_ASSERT(console.InterceptClickOn(admin, "left=1", locate(yard.origin_x + 12, yard.origin_y + 3, yard.z)), "The armed spawn did not take the click")
	var/list/spawned = console.selection.get_selected()
	TEST_ASSERT_EQUAL(length(spawned), 4, "The spawn made [length(spawned)] AI humans, not 4")
	TEST_ASSERT_EQUAL(length(GLOB.ai_human_list) - known_before, 4, "The spawn did not register the new AI humans")
	for(var/mob/living/carbon/human/recruit as anything in spawned)
		TEST_ASSERT_EQUAL(recruit.faction, FACTION_PMC, "A spawned unit has the wrong faction")
		TEST_ASSERT_EQUAL(recruit.ai_brain.personality.id, "veteran", "A spawned unit has the wrong personality")
		TEST_ASSERT_EQUAL(recruit.ai_brain.role?.id, "medic", "A spawned unit has the wrong role")
		TEST_ASSERT_NOTNULL(recruit.ai_brain.squad, "A spawned unit is in no squad")
	TEST_ASSERT(console.InterceptClickOn(admin, "right=1", locate(yard.origin_x + 12, yard.origin_y + 3, yard.z)), "The right click did not stop the spawn")
	TEST_ASSERT_NULL(console.pending_spawn, "The spawn stayed armed")
	console.handle_action(admin, "arm_spawn", list("job" = "no such preset"))
	TEST_ASSERT_NULL(console.pending_spawn, "A bad preset armed the spawn")
	for(var/mob/living/carbon/human/recruit as anything in spawned)
		qdel(recruit)

/// A hundred and fifty AI humans must not make the panel expensive, pages hold their size, filters and sorts work
/datum/unit_test/human_ai_command_scale
	var/datum/npc_command_console/console

/datum/unit_test/human_ai_command_scale/Destroy()
	QDEL_NULL(console)
	return ..()

/datum/unit_test/human_ai_command_scale/Run()
	var/list/rows = list("##################################################")
	for(var/row in 1 to 20)
		rows += "#................................................#"
	rows += "##################################################"
	var/datum/human_ai_arena/yard = new(rows, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/admin = allocate(/mob/living/carbon/human, pick(yard.floors))
	console = make_console(admin)
	var/list/factions = list(FACTION_MARINE, FACTION_PMC, FACTION_CLF)
	var/list/crowd = list()
	// A crowd as big as the old limit on how many there could be, which is not there any more
	var/crowd_size = 150
	for(var/index in 1 to crowd_size)
		var/mob/living/carbon/human/member = allocate(/mob/living/carbon/human, pick(yard.floors))
		member.faction = factions[1 + index % 3]
		if(!attach_human_ai(member))
			break
		crowd += member
	TEST_ASSERT(length(crowd) >= crowd_size - 5, "Only [length(crowd)] AI humans attached")
	for(var/index in 1 to 12)
		var/mob/living/carbon/human/hurt = crowd[index * 7]
		hurt.adjustBruteLoss(10 * index)

	var/started = TICK_USAGE
	var/list/first_data = console.ui_data(admin)
	var/first_cost = max(0, TICK_USAGE_TO_MS(started))
	started = TICK_USAGE
	for(var/call_count in 1 to 20)
		console.ui_data(admin)
	var/cached_cost = max(0, TICK_USAGE_TO_MS(started)) / 20
	TEST_NOTICE(src, "ui_data for [length(crowd)] AI humans cost [first_cost] ms to build and [round(cached_cost, 0.01)] ms cached")
	TEST_ASSERT(first_cost <= 60, "Building the roster cost [first_cost] ms")
	TEST_ASSERT(cached_cost <= 3, "A cached roster cost [round(cached_cost, 0.01)] ms per call")
	TEST_ASSERT_EQUAL(length(first_data["roster"]), HAI_COMMAND_PAGE_SIZE, "A page holds the wrong number of rows")
	TEST_ASSERT_EQUAL(first_data["roster_total"], length(crowd), "The roster total is wrong")
	TEST_ASSERT(first_data["pages"] >= 5, "The roster is not paged")

	console.handle_action(admin, "set_filter", list("faction" = FACTION_PMC))
	var/list/filtered = console.ui_data(admin)
	var/pmc_count = 0
	for(var/mob/living/carbon/human/member as anything in crowd)
		if(member.faction == FACTION_PMC)
			pmc_count++
	TEST_ASSERT_EQUAL(filtered["roster_total"], pmc_count, "The faction filter counted wrong")
	for(var/list/row as anything in filtered["roster"])
		TEST_ASSERT_EQUAL(row["faction"], FACTION_PMC, "A row of another faction passed the filter")
	console.handle_action(admin, "set_filter", list())

	console.handle_action(admin, "set_sort", list("key" = "health"))
	var/list/ascending = console.ui_data(admin)["roster"]
	for(var/index in 2 to length(ascending))
		TEST_ASSERT(ascending[index - 1]["health"] <= ascending[index]["health"], "The roster is not sorted by health")
	console.handle_action(admin, "set_sort", list("key" = "health"))
	var/list/descending = console.ui_data(admin)["roster"]
	for(var/index in 2 to length(descending))
		TEST_ASSERT(descending[index - 1]["health"] >= descending[index]["health"], "The roster is not sorted by health, descending")
	console.handle_action(admin, "set_page", list("page" = 999))
	TEST_ASSERT_EQUAL(console.ui_data(admin)["page"], console.ui_data(admin)["pages"], "A page past the end was not clamped")

	TEST_ASSERT(console.handle_action(admin, "select_all", list()), "Select all did nothing")
	TEST_ASSERT_EQUAL(length(console.selection.selected), length(crowd), "Select all missed someone")

	console.handle_action(admin, "inspect", list("ref" = REF(crowd[3])))
	for(var/each_tab in list("roster", "squads", "orders", "personality", "relations", "difficulty", "debug"))
		console.handle_action(admin, "set_tab", list("tab" = each_tab))
		var/list/tab_data = console.ui_data(admin)
		TEST_ASSERT_EQUAL(tab_data["tab"], each_tab, "The tab did not switch to [each_tab]")
	var/list/static_data = console.ui_static_data(admin)
	TEST_ASSERT_EQUAL(length(static_data["orders"]), length(GLOB.npc_command_orders), "The order list is incomplete")
	TEST_ASSERT(length(static_data["jobs"]) > 10, "The equipment preset list is empty")
	for(var/mob/living/carbon/human/member as anything in crowd)
		TEST_ASSERT_EQUAL(member.ai_brain?.error_total || 0, 0, "A brain threw errors")

/// The AI tool of build mode gives an AI to a mob of any kind that has one and takes it off again, and the panel keeps only the release
/datum/unit_test/human_ai_buildmode_ai
	var/datum/buildmode_mode/ai/mode

/datum/unit_test/human_ai_buildmode_ai/Destroy()
	QDEL_NULL(mode)
	return ..()

/datum/unit_test/human_ai_buildmode_ai/Run()
	var/datum/human_ai_arena/yard = new(list(
		"##############",
		"#............#",
		"#............#",
		"#............#",
		"#............#",
		"##############",
	), run_loc_floor_bottom_left)
	TEST_ASSERT(!("arm_assign" in GLOB.npc_command_admin_actions), "The panel still has an assign tool")
	TEST_ASSERT("release_ai" in GLOB.npc_command_admin_actions, "A commander could take the AI off a unit")
	mode = new /datum/buildmode_mode/ai(null)

	// Every kind that has an AI is known, and the others are refused
	var/mob/living/carbon/human/plain = allocate(/mob/living/carbon/human, locate(yard.origin_x + 3, yard.origin_y + 2, yard.z))
	var/mob/living/carbon/human/zombie = allocate(/mob/living/carbon/human, locate(yard.origin_x + 5, yard.origin_y + 2, yard.z))
	zombie.set_species(SPECIES_ZOMBIE)
	var/mob/living/carbon/xenomorph/drone/xeno = allocate(/mob/living/carbon/xenomorph/drone, locate(yard.origin_x + 7, yard.origin_y + 2, yard.z))
	var/mob/living/simple_animal/cat/cat = allocate(/mob/living/simple_animal/cat, locate(yard.origin_x + 9, yard.origin_y + 2, yard.z))
	TEST_ASSERT_EQUAL(npc_ai_kind(plain), NPC_AI_HUMAN, "A human is not known as a human")
	TEST_ASSERT_EQUAL(npc_ai_kind(zombie), NPC_AI_ZOMBIE, "A zombie is not known as a zombie")
	TEST_ASSERT_EQUAL(npc_ai_kind(xeno), NPC_AI_XENO, "A xenomorph is not known as one")
	TEST_ASSERT_NULL(npc_ai_kind(cat), "A cat was said to have an AI")
	TEST_ASSERT_NOTNULL(npc_ai_give(cat), "A mob with no AI to give was not refused")
	TEST_ASSERT_EQUAL(length(mode.give(cat, null)), 0, "A click on a mob with no AI gave something")

	// A click gives the AI of the kind, the settings are the humans'
	mode.personality = "veteran"
	mode.role = "engineer"
	mode.faction = FACTION_CLF
	TEST_ASSERT_EQUAL(length(mode.give(plain, null)), 1, "The click did not give the human an AI")
	TEST_ASSERT_NOTNULL(plain.ai_brain, "The human has no brain after the click")
	TEST_ASSERT_EQUAL(plain.ai_brain.personality.id, "veteran", "The nature was not applied")
	TEST_ASSERT_EQUAL(plain.ai_brain.role?.id, "engineer", "The role was not applied")
	TEST_ASSERT_EQUAL(plain.faction, FACTION_CLF, "The faction was not applied")
	TEST_ASSERT_EQUAL(length(mode.give(zombie, null)), 1, "The click did not give the zombie an AI")
	TEST_ASSERT_NOTNULL(zombie.zombie_ai_controller, "The zombie has no controller after the click")
	TEST_ASSERT_EQUAL(length(mode.give(xeno, null)), 1, "The click did not give the xenomorph an AI")
	TEST_ASSERT_NOTNULL(xeno.ai_controller, "The xenomorph has no controller after the click")
	TEST_ASSERT(xeno in GLOB.ai_xeno_list, "The xenomorph is not in the list of AI xenomorphs")
	TEST_ASSERT_NOTNULL(npc_ai_give(plain), "A human that has a brain was given a second one")
	TEST_ASSERT_EQUAL(length(mode.give(plain, null)), 0, "A second click gave an AI again")

	// The same through the click of the mode, a tile with a mob on it counts, an empty one does not
	TEST_ASSERT_EQUAL(length(mode.take(plain, null)), 1, "The right click did not take the AI off the human")
	TEST_ASSERT_NULL(plain.ai_brain, "The human still has a brain")
	TEST_ASSERT_EQUAL(length(mode.take(plain, null)), 0, "A mob with no AI had one taken off")
	mode.when_clicked(null, "left=1", locate(yard.origin_x + 3, yard.origin_y + 2, yard.z))
	TEST_ASSERT_NOTNULL(plain.ai_brain, "A left click on the tile with the human did not give an AI")
	mode.when_clicked(null, "right=1", plain)
	TEST_ASSERT_NULL(plain.ai_brain, "A right click on the human did not take the AI off")
	mode.when_clicked(null, "left=1", locate(yard.origin_x + 11, yard.origin_y + 3, yard.z))
	TEST_ASSERT_NULL(plain.ai_brain, "A click on an empty tile gave somebody an AI")

	// Taking it off leaves the mobs standing there
	TEST_ASSERT(npc_ai_take(zombie), "The AI was not taken off the zombie")
	TEST_ASSERT_NULL(zombie.zombie_ai_controller, "The zombie still has a controller")
	TEST_ASSERT(npc_ai_take(xeno), "The AI was not taken off the xenomorph")
	TEST_ASSERT_NULL(xeno.ai_controller, "The xenomorph still has a controller")
	TEST_ASSERT(!(xeno in GLOB.ai_xeno_list), "The xenomorph stayed in the list of AI xenomorphs")
	TEST_ASSERT(!npc_ai_take(cat), "The AI of a cat was taken off")

	// A reach gives it to everyone close to the click and the humans can be put in a squad
	var/mob/living/carbon/human/first = allocate(/mob/living/carbon/human, locate(yard.origin_x + 3, yard.origin_y + 3, yard.z))
	var/mob/living/carbon/human/second = allocate(/mob/living/carbon/human, locate(yard.origin_x + 4, yard.origin_y + 3, yard.z))
	var/mob/living/carbon/human/far = allocate(/mob/living/carbon/human, locate(yard.origin_x + 12, yard.origin_y + 1, yard.z))
	mode.reach = 3
	mode.squad = TRUE
	TEST_ASSERT(length(mode.give(first, null)) >= 2, "The reach did not give an AI to the ones close to the click")
	TEST_ASSERT_NOTNULL(second.ai_brain, "The human next to the click got no AI")
	TEST_ASSERT_NULL(far.ai_brain, "A human out of reach got an AI")
	TEST_ASSERT(first.ai_brain.squad && first.ai_brain.squad == second.ai_brain.squad, "The humans were not put in one squad")
	TEST_ASSERT(length(mode.take(first, null)) >= 2, "The reach did not take the AI off the ones close to the click")
	TEST_ASSERT(isnull(first.ai_brain) && isnull(second.ai_brain) && !first.is_human_ai_controlled, "A human is still marked as AI controlled")
	mode.reach = 0
	mode.squad = FALSE
	for(var/mob/living/living as anything in list(plain, zombie, xeno, first, second))
		npc_ai_take(living)

/// The NPC command panel is one window for both sides, the human console and the hive console: a user is let into the sides they have the right to and no more, and what the panel made goes with it
/datum/unit_test/human_ai_npc_panel
	var/datum/npc_command_panel/panel
	var/datum/npc_command_panel/leader_panel

/datum/unit_test/human_ai_npc_panel/Destroy()
	QDEL_NULL(panel)
	QDEL_NULL(leader_panel)
	return ..()

/datum/unit_test/human_ai_npc_panel/Run()
	var/mob/living/carbon/human/admin = allocate(/mob/living/carbon/human)
	panel = new(admin)
	TEST_ASSERT_EQUAL(panel.mode, NPC_PANEL_HUMANS, "The panel did not start on the human side")
	TEST_ASSERT(!panel.can_humans(admin) && !panel.can_xenos(admin), "A user with no rights was let into a side")
	TEST_ASSERT(!panel.open(admin, NPC_PANEL_HUMANS), "The panel opened for a user with no rights")
	TEST_ASSERT(!panel.switch_mode(admin, NPC_PANEL_XENOS), "A user with no rights switched to the xeno side")
	TEST_ASSERT(!open_npc_panel_for(admin, NPC_PANEL_HUMANS), "A mob with no ckey was given a panel")

	// An admin has both sides, and the xeno side asks which hive until one is picked
	panel.humans.access_override = TRUE
	TEST_ASSERT(panel.can_humans(admin) && panel.can_xenos(admin), "An admin was not let into both sides")
	TEST_ASSERT(panel.open(admin, NPC_PANEL_XENOS), "The panel did not open for an admin")
	TEST_ASSERT_EQUAL(panel.mode, NPC_PANEL_XENOS, "The panel did not open on the side that was asked for")
	var/list/data = panel.ui_data(admin)
	TEST_ASSERT(data["needs_hive"], "An admin who has not picked a hive was not asked for one")
	TEST_ASSERT(data["panel_humans"] && data["panel_xenos"], "The panel did not offer both sides to an admin")
	TEST_ASSERT_EQUAL(length(panel.ui_static_data(admin)["available_hives"]), length(GLOB.hive_datum), "The admin was not offered every hive")
	TEST_ASSERT(!panel.handle_action(admin, "pick_hive", list("hive" = "no such hive")), "A hive that does not exist was picked")
	TEST_ASSERT(panel.handle_action(admin, "pick_hive", list("hive" = XENO_HIVE_NORMAL)), "Picking a hive did nothing")
	var/datum/xeno_command_console/made = panel.xenos
	TEST_ASSERT(made && panel.owns_xenos, "Picking a hive did not give the panel a hive console of its own")
	TEST_ASSERT(made.hive == GLOB.hive_datum[XENO_HIVE_NORMAL], "The hive console is for another hive than the one picked")
	TEST_ASSERT(made.panel_ref?.resolve() == panel, "The hive console does not know that the panel is its window")
	data = panel.ui_data(admin)
	TEST_ASSERT(!data["needs_hive"] && data["panel_mode"] == NPC_PANEL_XENOS, "The panel still asked for a hive after one was picked")

	// Switching sides, an unknown side changes nothing, and the human side takes its own controls again
	panel.handle_action(admin, "set_panel_mode", list("mode" = "bogus"))
	TEST_ASSERT_EQUAL(panel.mode, NPC_PANEL_XENOS, "An unknown side changed the panel")
	panel.handle_action(admin, "set_panel_mode", list("mode" = NPC_PANEL_HUMANS))
	TEST_ASSERT_EQUAL(panel.mode, NPC_PANEL_HUMANS, "The panel did not go back to the human side")
	TEST_ASSERT(panel.handle_action(admin, "select_all", list()), "A control of the human side was not passed on to it")
	panel.humans.access_override = FALSE
	TEST_ASSERT(!panel.handle_action(admin, "pick_hive", list("hive" = XENO_HIVE_NORMAL)), "A user who lost their rights picked a hive")
	panel.humans.access_override = TRUE

	// Deleting the panel deletes the consoles it made
	var/datum/npc_command_console/humans = panel.humans
	qdel(panel)
	panel = null
	TEST_ASSERT(QDELETED(made) && QDELETED(humans), "The consoles that the panel made outlived it")

	// A hive leader has the xeno side only, on the console that the leader keeps, which the panel leaves alone when it goes
	var/mob/living/carbon/xenomorph/drone/leader = allocate(/mob/living/carbon/xenomorph/drone)
	leader.hive_pos = 2
	leader_panel = new(leader)
	TEST_ASSERT(!leader_panel.can_humans(leader), "A hive leader was let into the human side")
	TEST_ASSERT(leader_panel.can_xenos(leader), "A hive leader was not let into the xeno side")
	TEST_ASSERT(leader_panel.open(leader, NPC_PANEL_HUMANS), "The panel did not open for a hive leader")
	TEST_ASSERT_EQUAL(leader_panel.mode, NPC_PANEL_XENOS, "A hive leader was left on a side they have no right to")
	var/datum/xeno_command_console/own = leader.hive_command_console
	TEST_ASSERT(own && leader_panel.xenos == own && !leader_panel.owns_xenos, "The hive console the leader keeps was not the one the panel used")
	TEST_ASSERT(leader_panel.handle_action(leader, "toggle_selecting_mode", list()), "A control of the xeno side was not passed on to it")
	TEST_ASSERT(own.selecting_mode, "The hive console did not get the control")
	TEST_ASSERT(!leader_panel.handle_action(leader, "pick_hive", list("hive" = XENO_HIVE_NORMAL)), "A hive leader picked a hive")
	qdel(leader_panel)
	leader_panel = null
	TEST_ASSERT(!QDELETED(own) && !own.panel_ref, "The panel took the leader's own hive console with it")

/// Squad templates are made of equipment presets that exist, spawn whole under one leader from the NPC command panel, and the panel does not trust what it is sent
/datum/unit_test/human_ai_squad_templates
	var/datum/npc_command_console/console

/datum/unit_test/human_ai_squad_templates/Destroy()
	QDEL_NULL(console)
	return ..()

/datum/unit_test/human_ai_squad_templates/Run()
	TEST_ASSERT(length(GLOB.human_ai_squad_templates) >= 5, "There are hardly any squad templates")
	for(var/template_id in GLOB.human_ai_squad_templates)
		var/list/template = GLOB.human_ai_squad_templates[template_id]
		TEST_ASSERT(human_ai_template_size(template) > 1, "The squad [template["name"]] is not a squad")
		for(var/list/entry in template["members"])
			TEST_ASSERT((entry["job"] in GLOB.gear_name_presets_list), "The squad [template["name"]] has [entry["job"]], which is not an equipment preset")
			TEST_ASSERT(entry["count"] >= 1, "The squad [template["name"]] has none of [entry["job"]]")

	var/datum/human_ai_arena/yard = new(list(
		"####################",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"####################",
	), run_loc_floor_bottom_left)
	var/mob/living/carbon/human/admin = allocate(/mob/living/carbon/human, locate(yard.origin_x + 1, yard.origin_y + 1, yard.z))
	console = make_console(admin)
	TEST_ASSERT("arm_template" in GLOB.npc_command_admin_actions, "A commander could spawn whole squads")
	var/list/static_data = console.ui_static_data(admin)
	TEST_ASSERT_EQUAL(length(static_data["squad_templates"]), length(GLOB.human_ai_squad_templates), "The panel was not told about every squad")

	console.handle_action(admin, "arm_template", list("template" = "no such squad"))
	TEST_ASSERT_NULL(console.pending_spawn, "A squad that does not exist armed the tool")
	console.handle_action(admin, "arm_template", list("template" = "uscm_fireteam", "personality" = "no such nature", "range" = 99))
	TEST_ASSERT_NOTNULL(console.pending_spawn, "The tool was not armed")
	TEST_ASSERT_EQUAL(console.pending_spawn["personality"], "neutral", "A bad nature got through")
	TEST_ASSERT_EQUAL(console.pending_spawn["range"], 6, "The spread was not held to what a spawn may have")
	console.handle_action(admin, "arm_template", list("template" = "uscm_fireteam", "personality" = "veteran", "range" = 2))
	TEST_ASSERT(console.InterceptClickOn(admin, "left=1", locate(yard.origin_x + 10, yard.origin_y + 3, yard.z)), "The armed tool did not take the click")

	var/list/spawned = console.selection.get_selected()
	var/list/template = GLOB.human_ai_squad_templates["uscm_fireteam"]
	TEST_ASSERT_EQUAL(length(spawned), human_ai_template_size(template), "The squad did not come out whole")
	var/mob/living/carbon/human/leader = spawned[1]
	TEST_ASSERT(leader.ai_brain.squad, "The squad leader is in no squad")
	TEST_ASSERT(leader.ai_brain.squad.leader == leader.ai_brain, "The first of the members is not the leader of the squad")
	TEST_ASSERT_EQUAL(leader.ai_brain.squad.name, template["name"], "The squad does not have the name of its template")
	for(var/mob/living/carbon/human/member as anything in spawned)
		TEST_ASSERT(member.ai_brain.squad == leader.ai_brain.squad, "A member of the squad is in another squad")
		TEST_ASSERT_EQUAL(member.ai_brain.personality.id, "veteran", "A member of the squad does not have the nature that was asked for")
	for(var/mob/living/carbon/human/member as anything in spawned)
		detach_human_ai(member)
		qdel(member)
