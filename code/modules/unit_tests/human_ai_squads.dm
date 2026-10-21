/// Membership, leader succession, formations, shared contacts and squad wide orders
/datum/unit_test/human_ai_squad_basics

/datum/unit_test/human_ai_squad_basics/proc/leader_changed(datum/human_ai_squad/squad, datum/human_ai_brain/old_leader)
	return squad.leader && squad.leader != old_leader

/datum/unit_test/human_ai_squad_basics/proc/knows_about(datum/human_ai_brain/brain, mob/living/subject)
	var/datum/ai_contact/contact = brain.get_contact(subject)
	return contact && contact.identified()

/datum/unit_test/human_ai_squad_basics/proc/all_ordered(datum/human_ai_squad/squad, order_id)
	for(var/datum/human_ai_brain/brain as anything in squad.members)
		if(brain.current_order?.id != order_id)
			return FALSE
	return TRUE

/datum/unit_test/human_ai_squad_basics/proc/all_near(datum/human_ai_squad/squad, turf/spot, distance)
	for(var/datum/human_ai_brain/brain as anything in squad.members)
		if(get_dist(brain.body, spot) > distance)
			return FALSE
	return TRUE

/datum/unit_test/human_ai_squad_basics/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/list/rows = list("############################")
	for(var/row in 1 to 14)
		rows += "#..........................#"
	rows += "############################"
	var/datum/human_ai_arena/yard = new(rows, run_loc_floor_bottom_left)
	var/turf/start = locate(yard.origin_x + 3, yard.origin_y + 10, yard.z)
	var/list/bodies = list()
	for(var/index in 0 to 3)
		bodies += make_soldier(locate(start.x + index, start.y + index % 2, start.z), armed = FALSE)
	var/mob/living/carbon/human/chosen = bodies[3]
	var/datum/human_ai_squad/squad = create_human_ai_squad(bodies, chosen, "Test Squad")
	TEST_ASSERT_NOTNULL(squad, "No squad was made")
	TEST_ASSERT_EQUAL(length(squad.members), 4, "The squad has the wrong size")
	TEST_ASSERT_EQUAL(squad.leader, chosen.ai_brain, "The preferred body did not become the leader")
	TEST_ASSERT(!squad.add_member(chosen.ai_brain), "A member joined the same squad twice")

	var/datum/human_ai_brain/old_leader = squad.leader
	var/mob/living/carbon/human/old_body = old_leader.body
	old_body.death(create_cause_data("unit test"))
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(leader_changed), squad, old_leader), 8), "The squad did not pick a new leader after the old one died")
	TEST_ASSERT(squad.member_valid(squad.leader), "The new leader is not able")
	TEST_ASSERT_EQUAL(squad.casualties, 1, "The loss was not counted")
	TEST_ASSERT_EQUAL(length(squad.members), 3, "The dead member is still in the squad")

	var/mob/living/carbon/human/lead_body = squad.leader.body
	lead_body.setDir(NORTH)
	var/list/shapes = list()
	for(var/shape in list(HAI_FORM_WEDGE, HAI_FORM_COLUMN, HAI_FORM_LINE, HAI_FORM_SCATTER))
		squad.formation = shape
		var/list/spots = list()
		for(var/slot in 0 to 3)
			spots += squad.leader.formation_turf(lead_body, slot)
		// Numbers are indexes in a list, a key that is a number has to be text to stand for a shape
		shapes["[shape]"] = spots
		var/list/distinct = list()
		for(var/turf/spot as anything in spots)
			distinct[spot] = TRUE
		TEST_ASSERT(length(distinct) >= 3, "Formation [shape] gave only [length(distinct)] different spots for 4 slots")
	for(var/turf/spot as anything in shapes["[HAI_FORM_COLUMN]"])
		TEST_ASSERT_EQUAL(spot.x, lead_body.x, "A column slot is not behind the leader")
	var/list/line_spots = shapes["[HAI_FORM_LINE]"]
	var/turf/first_line = line_spots[1]
	for(var/turf/spot as anything in line_spots)
		TEST_ASSERT_EQUAL(spot.y, first_line.y, "A line slot is not abreast of the others")
	squad.formation = HAI_FORM_WEDGE

	var/datum/npc_order/move/shift = new
	shift.target_turf = locate(start.x + 18, start.y + 2, start.z)
	TEST_ASSERT(squad.issue_order(shift) >= 3, "The squad accepted only [squad.issue_order(shift)] of its move orders")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(all_near), squad, shift.target_turf, 6), 45), "The squad did not close up on the move goal")
	var/datum/npc_order/hold/dig_in = new
	dig_in.target_turf = locate(start.x + 18, start.y + 2, start.z)
	TEST_ASSERT(squad.issue_order(dig_in) >= 3, "The squad accepted too few hold orders")
	TEST_ASSERT(all_ordered(squad, "hold"), "Not every member holds")
	var/list/spots_held = list()
	for(var/datum/human_ai_brain/brain as anything in squad.members)
		spots_held[brain.current_order.dest] = TRUE
	TEST_ASSERT_EQUAL(length(spots_held), length(squad.members), "The members were sent to the same spot")
	var/datum/npc_order/fortify/dig = new
	TEST_ASSERT_EQUAL(squad.issue_order(dig), 0, "Riflemen accepted a fortify order")
	for(var/datum/human_ai_brain/brain as anything in squad.members)
		TEST_ASSERT_EQUAL(brain.error_total, 0, "A brain threw errors under squad orders")
	squad.disband()
	for(var/mob/living/carbon/human/body as anything in bodies)
		detach_human_ai(body)

/// What one member sees the others hear about
/datum/unit_test/human_ai_squad_callouts

/datum/unit_test/human_ai_squad_callouts/proc/knows_about(datum/human_ai_brain/brain, mob/living/subject)
	var/datum/ai_contact/contact = brain.get_contact(subject)
	return contact && contact.identified()

/datum/unit_test/human_ai_squad_callouts/Run()
	var/datum/human_ai_arena/rooms = new(list(
		"###########",
		"#1.....#3.#",
		"#.....2#..#",
		"###########",
	), run_loc_floor_bottom_left)
	var/mob/living/carbon/human/spotter = make_soldier(rooms.mark("1"), armed = FALSE)
	var/mob/living/carbon/human/listener = make_soldier(rooms.mark("3"), armed = FALSE)
	var/mob/living/carbon/xenomorph/drone/dummy = make_target_dummy(rooms.mark("2"))
	var/datum/human_ai_squad/squad = create_human_ai_squad(list(spotter, listener), spotter, "Callout Squad")
	TEST_ASSERT_NOTNULL(squad, "No squad was made")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(knows_about), spotter.ai_brain, dummy), 8), "The spotter never made out the xeno")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(knows_about), listener.ai_brain, dummy), 8), "The listener never heard about the xeno, callouts sent [squad.callouts_sent] received [squad.callouts_received]")
	var/datum/ai_contact/heard = listener.ai_brain.get_contact(dummy)
	TEST_ASSERT(!heard.visible, "The listener sees through the wall")
	TEST_ASSERT(squad.callouts_sent >= 1 && squad.callouts_received >= 1, "The call-out counters did not move")
	TEST_ASSERT(get_dist(heard.last_turf, get_turf(dummy)) <= 2, "The reported position is [get_dist(heard.last_turf, get_turf(dummy))] tiles off")
	TEST_ASSERT(ai_wait(CALLBACK(listener.ai_brain, TYPE_PROC_REF(/datum/human_ai_brain, get_target)), 6), "The listener never acted on what it was told")
	TEST_ASSERT_EQUAL(spotter.ai_brain.error_total + listener.ai_brain.error_total, 0, "A brain threw errors")
	squad.disband()
	detach_human_ai(spotter)
	detach_human_ai(listener)

/// Four marines against one enemy that holds its ground: the squad pins it and sends someone round the side
/datum/unit_test/human_ai_squad_flank
	var/datum/human_ai_squad/squad
	var/mob/living/target
	var/turf/base_turf
	var/best_arc = 0
	var/list/datum/human_ai_brain/flankers = list()

/datum/unit_test/human_ai_squad_flank/proc/flanked()
	for(var/datum/human_ai_brain/brain as anything in squad.members)
		if(brain == squad.leader)
			continue
		var/arc = abs(Get_Angle(brain.body, target) - Get_Angle(base_turf, target))
		if(arc > 180)
			arc = 360 - arc
		best_arc = max(best_arc, arc)
		if(arc >= HAI_FLANK_MIN_ARC && brain.cover_has_line(get_turf(brain.body), get_turf(target)))
			flankers[brain] = brain.shots_fired
			return TRUE
	return FALSE

/datum/unit_test/human_ai_squad_flank/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/list/rows = list("##################################")
	for(var/row in 1 to 22)
		rows += "#................................#"
	rows += "##################################"
	var/datum/human_ai_arena/field = new(rows, run_loc_floor_bottom_left)
	var/turf/centre = locate(field.origin_x + 6, field.origin_y + 12, field.z)
	base_turf = centre
	target = make_target_dummy(locate(centre.x + 9, centre.y, centre.z))
	var/list/bodies = list()
	for(var/index in 0 to 3)
		bodies += make_soldier(locate(centre.x + (index % 2), centre.y + index - 1, centre.z))
	squad = create_human_ai_squad(bodies, bodies[1], "Flank Squad")
	TEST_ASSERT_NOTNULL(squad, "No squad was made")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(flanked)), 75), "Nobody flanked in time: flanks started [squad.flanks_started] done [squad.flanks_done] aborted [squad.flanks_aborted], best arc [round(best_arc)], play [squad.play], leader log [squad.leader?.decision_log.Join(" | ")]")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(flank_counted)), 4), "The squad never counted the flank as done: started [squad.flanks_started] done [squad.flanks_done] aborted [squad.flanks_aborted]")
	TEST_NOTICE(src, "Flank done after [squad.flanks_started] started, best angle [round(best_arc)], plays changed [squad.play_changes] times")
	var/datum/human_ai_brain/flanker
	for(var/datum/human_ai_brain/brain as anything in flankers)
		flanker = brain
	var/shots_then = flankers[flanker]
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(shot_since), flanker, shots_then), 10), "The flanker never fired from its new position")
	TEST_ASSERT_EQUAL(squad.flanks_aborted, 0, "A flank was aborted against a target that never moved or fired")
	TEST_ASSERT(squad.play_changes <= 6, "The squad changed plays [squad.play_changes] times")
	for(var/datum/human_ai_brain/brain as anything in squad.members)
		TEST_ASSERT_EQUAL(brain.error_total, 0, "A brain threw errors")
	var/list/to_detach = list()
	for(var/datum/human_ai_brain/brain as anything in squad.members)
		to_detach += brain.body
	squad.disband()
	for(var/mob/living/carbon/human/body as anything in to_detach)
		detach_human_ai(body)

/datum/unit_test/human_ai_squad_flank/proc/flank_counted()
	return squad.flanks_done >= 1

/datum/unit_test/human_ai_squad_flank/proc/shot_since(datum/human_ai_brain/brain, shots_then)
	return brain.shots_fired > shots_then

/// A squad under strain pulls back in bounds
/datum/unit_test/human_ai_squad_fallback
	var/datum/human_ai_squad/squad

/datum/unit_test/human_ai_squad_fallback/proc/fell_back()
	return squad.fallbacks_done >= 1

/datum/unit_test/human_ai_squad_fallback/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/list/rows = list("##################################")
	for(var/row in 1 to 10)
		rows += "#................................#"
	rows += "##################################"
	var/datum/human_ai_arena/field = new(rows, run_loc_floor_bottom_left)
	var/turf/centre = locate(field.origin_x + 12, field.origin_y + 6, field.z)
	var/mob/living/target = make_target_dummy(locate(centre.x + 8, centre.y, centre.z))
	var/list/bodies = list()
	for(var/index in 0 to 3)
		bodies += make_soldier(locate(centre.x - (index % 2), centre.y + index - 1, centre.z))
	squad = create_human_ai_squad(bodies, bodies[1], "Fallback Squad")
	TEST_ASSERT_NOTNULL(squad, "No squad was made")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(engaged_enough)), 12), "The squad never engaged the target")
	var/list/starts = list()
	for(var/datum/human_ai_brain/brain as anything in squad.members)
		starts[brain] = get_dist(brain.body, target)
		brain.stress = 80
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(fell_back)), 40), "The squad did not pull back, fallbacks started [squad.fallbacks_started] done [squad.fallbacks_done], play [squad.play], stage [squad.fallback_stage], leader log [squad.leader?.decision_log.Join(" | ")]")
	var/backed_off = 0
	for(var/datum/human_ai_brain/brain as anything in squad.members)
		if(get_dist(brain.body, target) >= starts[brain] + 3)
			backed_off++
		TEST_ASSERT_EQUAL(brain.error_total, 0, "A brain threw errors")
	TEST_ASSERT(backed_off * 2 >= length(squad.members), "Only [backed_off] of [length(squad.members)] members got back from the threat")
	TEST_ASSERT_EQUAL(squad.fallbacks_started, 1, "The squad fell back [squad.fallbacks_started] times")
	var/list/to_detach = list()
	for(var/datum/human_ai_brain/brain as anything in squad.members)
		to_detach += brain.body
	squad.disband()
	for(var/mob/living/carbon/human/body as anything in to_detach)
		detach_human_ai(body)

/datum/unit_test/human_ai_squad_fallback/proc/engaged_enough()
	var/engaged = 0
	for(var/datum/human_ai_brain/brain as anything in squad.members)
		if(brain.intent == HAI_INTENT_ENGAGE)
			engaged++
	return engaged >= 3

/// Two squads fight for three minutes: nothing throws, plans do not flap and every commit window holds
/datum/unit_test/human_ai_squad_soak
	var/seconds = 180

/datum/unit_test/human_ai_squad_soak/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/list/rows = list("####################################")
	for(var/row in 1 to 18)
		var/line = "#"
		for(var/col in 1 to 34)
			line += (row % 6 == 3 && (col == 8 || col == 29)) ? "B" : "."
		rows += line + "#"
	rows += "####################################"
	var/datum/human_ai_arena/field = new(rows, run_loc_floor_bottom_left)
	var/list/blue = list()
	var/list/red = list()
	for(var/index in 0 to 3)
		blue += make_soldier(locate(field.origin_x + 3 + index % 2, field.origin_y + 6 + index * 2, field.z), FACTION_MARINE)
		red += make_soldier(locate(field.origin_x + 32 - index % 2, field.origin_y + 6 + index * 2, field.z), FACTION_CLF)
	var/datum/human_ai_squad/blue_squad = create_human_ai_squad(blue, blue[1], "Blue")
	var/datum/human_ai_squad/red_squad = create_human_ai_squad(red, red[1], "Red")
	TEST_ASSERT(blue_squad && red_squad, "The squads were not made")
	for(var/mob/living/carbon/human/soldier as anything in blue + red)
		var/obj/item/storage/backpack/pack = new(soldier)
		soldier.equip_to_slot_if_possible(pack, WEAR_BACK)
		for(var/spare in 1 to 6)
			new /obj/item/ammo_magazine/rifle(pack)
	var/datum/npc_order/move/advance_blue = new
	advance_blue.target_turf = locate(field.origin_x + 28, field.origin_y + 10, field.z)
	blue_squad.issue_order(advance_blue)
	var/datum/npc_order/move/advance_red = new
	advance_red.target_turf = locate(field.origin_x + 7, field.origin_y + 10, field.z)
	red_squad.issue_order(advance_red)
	SShuman_ai.reset_cost_meter()
	sleep(seconds SECONDS)
	TEST_NOTICE(src, "Blue: [length(blue_squad.members)] left, [blue_squad.casualties] lost, [blue_squad.flanks_started] flanks ([blue_squad.flanks_done] done, [blue_squad.flanks_aborted] aborted), [blue_squad.fallbacks_started] fall backs, [blue_squad.play_changes] play changes, [blue_squad.callouts_received] call-outs heard, leader changed [blue_squad.leader_changes] times")
	TEST_NOTICE(src, "Red: [length(red_squad.members)] left, [red_squad.casualties] lost, [red_squad.flanks_started] flanks ([red_squad.flanks_done] done, [red_squad.flanks_aborted] aborted), [red_squad.fallbacks_started] fall backs, [red_squad.play_changes] play changes, [red_squad.callouts_received] call-outs heard, leader changed [red_squad.leader_changes] times")
	TEST_NOTICE(src, "[round(SShuman_ai.total_cost_ms / seconds, 0.1)] ms/s of AI work with [round(SShuman_ai.squad_cost_ms / seconds, 0.1)] ms/s of it in squad plans")
	var/total_lost = (QDELETED(blue_squad) ? 4 : blue_squad.casualties) + (QDELETED(red_squad) ? 4 : red_squad.casualties)
	TEST_ASSERT(total_lost >= 1, "Nobody was hurt badly enough to fall in three minutes of a firefight")
	for(var/datum/human_ai_squad/squad as anything in list(blue_squad, red_squad))
		if(QDELETED(squad))
			continue
		TEST_ASSERT(squad.play_changes <= 14, "[squad.name] changed plays [squad.play_changes] times in [seconds] seconds")
		TEST_ASSERT(squad.flanks_started <= 1 + seconds / (HAI_FLANK_COOLDOWN / 10), "[squad.name] started [squad.flanks_started] flanks, more than the cooldown allows")
		TEST_ASSERT(squad.fallbacks_started <= 1 + seconds / (HAI_FALLBACK_COOLDOWN / 10), "[squad.name] fell back [squad.fallbacks_started] times, more than the cooldown allows")
		TEST_ASSERT_EQUAL(squad.plan_errors, 0, "[squad.name] threw errors while planning")
		for(var/datum/human_ai_brain/brain as anything in squad.members)
			TEST_ASSERT_EQUAL(brain.error_total, 0, "A brain of [squad.name] threw errors: [brain.decision_log.Join(" | ")]")
	for(var/mob/living/carbon/human/soldier as anything in blue + red)
		detach_human_ai(soldier)
	if(!QDELETED(blue_squad))
		blue_squad.disband()
	if(!QDELETED(red_squad))
		red_squad.disband()
