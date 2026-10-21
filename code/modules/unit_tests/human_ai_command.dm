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

/// The assign tool gives a brain to a human that is already in the round, from the panel's click tool and from the proc behind the admin verb
/datum/unit_test/human_ai_assign_tool
	var/datum/npc_command_console/console

/datum/unit_test/human_ai_assign_tool/Destroy()
	QDEL_NULL(console)
	return ..()

/datum/unit_test/human_ai_assign_tool/Run()
	var/datum/human_ai_arena/yard = new(list(
		"##############",
		"#............#",
		"#............#",
		"#............#",
		"#............#",
		"##############",
	), run_loc_floor_bottom_left)
	var/mob/living/carbon/human/admin = allocate(/mob/living/carbon/human, locate(yard.origin_x + 1, yard.origin_y + 1, yard.z))
	console = make_console(admin)
	TEST_ASSERT("arm_assign" in GLOB.npc_command_admin_actions, "A commander could arm the assign tool")
	TEST_ASSERT("release_ai" in GLOB.npc_command_admin_actions, "A commander could take the AI off a unit")

	// The proc behind the tool, and why it refuses
	var/mob/living/carbon/human/plain = allocate(/mob/living/carbon/human, locate(yard.origin_x + 3, yard.origin_y + 2, yard.z))
	TEST_ASSERT_NULL(plain.ai_brain, "The test human started with a brain")
	TEST_ASSERT_NULL(assign_human_ai(plain, "zealot", "medic", FACTION_PMC), "A plain human was refused a brain")
	TEST_ASSERT_NOTNULL(plain.ai_brain, "The human has no brain after it was assigned one")
	TEST_ASSERT_EQUAL(plain.ai_brain.personality.id, "zealot", "The nature was not applied")
	TEST_ASSERT_EQUAL(plain.ai_brain.role?.id, "medic", "The role was not applied")
	TEST_ASSERT_EQUAL(plain.faction, FACTION_PMC, "The faction was not applied")
	TEST_ASSERT_NOTNULL(assign_human_ai(plain), "A human that has a brain was given a second one")
	var/mob/living/carbon/human/corpse = allocate(/mob/living/carbon/human, locate(yard.origin_x + 4, yard.origin_y + 2, yard.z))
	corpse.stat = DEAD
	TEST_ASSERT_NOTNULL(human_ai_attach_refusal(corpse), "A dead human was not refused")
	TEST_ASSERT_NOTNULL(human_ai_attach_refusal(null), "Nobody was not refused")
	detach_human_ai(plain)

	// The click tool: one human at a time
	var/mob/living/carbon/human/first = allocate(/mob/living/carbon/human, locate(yard.origin_x + 3, yard.origin_y + 1, yard.z))
	var/mob/living/carbon/human/second = allocate(/mob/living/carbon/human, locate(yard.origin_x + 8, yard.origin_y + 3, yard.z))
	var/mob/living/carbon/human/third = allocate(/mob/living/carbon/human, locate(yard.origin_x + 9, yard.origin_y + 3, yard.z))
	var/mob/living/carbon/human/far = allocate(/mob/living/carbon/human, locate(yard.origin_x + 12, yard.origin_y + 1, yard.z))
	console.handle_action(admin, "arm_assign", list("personality" = "veteran", "role" = "engineer", "faction" = FACTION_CLF, "range" = 0))
	TEST_ASSERT_NOTNULL(console.pending_assign, "The assign tool was not armed")
	TEST_ASSERT(console.wants_intercept(), "The armed assign tool would not take the click")
	TEST_ASSERT(console.InterceptClickOn(admin, "left=1", first), "The armed assign tool did not take the click")
	TEST_ASSERT_NOTNULL(first.ai_brain, "The human that was clicked got no brain")
	TEST_ASSERT_EQUAL(first.ai_brain.personality.id, "veteran", "The clicked human has the wrong nature")
	TEST_ASSERT_EQUAL(first.ai_brain.role?.id, "engineer", "The clicked human has the wrong role")
	TEST_ASSERT_EQUAL(first.faction, FACTION_CLF, "The clicked human has the wrong faction")
	TEST_ASSERT_NULL(second.ai_brain, "A human that was not clicked got a brain")
	TEST_ASSERT(first in console.selection.get_selected(), "The human that was given an AI was not selected")
	console.InterceptClickOn(admin, "left=1", locate(yard.origin_x + 6, yard.origin_y + 4, yard.z))
	TEST_ASSERT_NULL(second.ai_brain, "A click on an empty tile gave somebody a brain")
	TEST_ASSERT_NOTNULL(console.pending_assign, "The tool disarmed itself after a click")
	console.InterceptClickOn(admin, "left=1", first)
	TEST_ASSERT_EQUAL(length(console.selection.get_selected()), 1, "Clicking a human that has a brain again changed the selection")

	// And with a reach, where what the panel sends is not trusted
	console.handle_action(admin, "arm_assign", list("personality" = "no such nature", "role" = "no such role", "faction" = "no such faction", "range" = 3, "squad" = TRUE))
	TEST_ASSERT_EQUAL(console.pending_assign["personality"], "neutral", "A bad nature got through")
	TEST_ASSERT_NULL(console.pending_assign["role"], "A bad role got through")
	TEST_ASSERT_NULL(console.pending_assign["faction"], "A bad faction got through")
	TEST_ASSERT(console.InterceptClickOn(admin, "left=1", second), "The tool with a reach did not take the click")
	TEST_ASSERT_NOTNULL(second.ai_brain, "The human that was clicked got no brain")
	TEST_ASSERT_NOTNULL(third.ai_brain, "The human next to the click got no brain")
	TEST_ASSERT_NULL(far.ai_brain, "A human out of reach got a brain")
	TEST_ASSERT(second.ai_brain.squad && second.ai_brain.squad == third.ai_brain.squad, "The two were not put in one squad")
	TEST_ASSERT(console.InterceptClickOn(admin, "right=1", second), "The right click did not stop the tool")
	TEST_ASSERT_NULL(console.pending_assign, "The tool stayed armed")

	// Letting go of the selected
	console.selection.clear()
	console.selection.select_list(list(first, second))
	console.handle_action(admin, "release_ai", list())
	TEST_ASSERT_NULL(first.ai_brain, "The AI was not taken off the first human")
	TEST_ASSERT_NULL(second.ai_brain, "The AI was not taken off the second human")
	TEST_ASSERT_NOTNULL(third.ai_brain, "The AI was taken off a human that was not selected")
	TEST_ASSERT(isnull(first.ai_brain) && !first.is_human_ai_controlled, "The human is still marked as AI controlled")
	detach_human_ai(third)

	// Closing the window disarms it
	console.pending_assign = list("range" = 0)
	console.ui_close(admin)
	TEST_ASSERT_NULL(console.pending_assign, "Closing the window left the assign tool armed")
