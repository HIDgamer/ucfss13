/// A clientless marine with a rifle and a brain, or without the rifle
/datum/unit_test/proc/make_soldier(turf/where, faction = FACTION_MARINE, armed = TRUE, personality = "neutral")
	var/mob/living/carbon/human/soldier = allocate(/mob/living/carbon/human, where)
	human_ai_test_skills(soldier)
	soldier.faction = faction
	if(armed)
		var/obj/item/weapon/gun/rifle/m41a/rifle = new(soldier)
		soldier.put_in_hands(rifle)
	if(!attach_human_ai(soldier, personality))
		return null
	soldier.ai_brain.keep_awake = TRUE
	return soldier

/**
 * Puts the item on the body in the slot. A bare test body has no inventory screen and the game refuses to equip anything into its slots, deleting the
 * item when asked to, so it is given one and when that is not enough the slot is filled by hand.
 */
/datum/unit_test/proc/dress(mob/living/carbon/human/human, obj/item/thing, slot)
	if(!human.hud_used)
		human.create_hud()
	if(human.equip_to_slot_if_possible(thing, slot))
		return TRUE
	thing.forceMove(human)
	switch(slot)
		if(WEAR_L_EAR)
			human.wear_l_ear = thing
		if(WEAR_JACKET)
			human.wear_suit = thing
		if(WEAR_BODY)
			human.w_uniform = thing
		if(WEAR_BACK)
			human.back = thing
	return TRUE

/// A xeno that stands where it is put and cannot be killed by a rifle
/datum/unit_test/proc/make_target_dummy(turf/where)
	var/mob/living/carbon/xenomorph/drone/dummy = allocate(/mob/living/carbon/xenomorph/drone, where)
	dummy.maxHealth = 100000
	dummy.health = 100000
	SSspatial_grid.track(dummy, SPATIAL_GRID_TRACK_NPC)
	return dummy

/// Polls the check until it is true or the seconds are up
/datum/unit_test/proc/ai_wait(datum/callback/check, seconds)
	for(var/waited in 1 to seconds * 4)
		if(check.Invoke())
			return TRUE
		sleep(2.5)
	return check.Invoke()

/datum/unit_test/proc/order_over(datum/npc_order/order)
	return order.status != HAI_ORDER_ACTIVE

/datum/unit_test/proc/near_turf(mob/living/carbon/human/body, turf/spot, distance)
	return get_dist(body, spot) <= distance

/datum/unit_test/proc/brain_in_cover(datum/human_ai_brain/brain, turf/threat)
	return brain.in_good_cover(threat)

/// Movement orders: move, hold, follow, patrol, fall back, take cover and clear room
/datum/unit_test/human_ai_orders_movement

/datum/unit_test/human_ai_orders_movement/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/datum/human_ai_arena/yard = new(list(
		"##############################",
		"#............................#",
		"#............................#",
		"#............................#",
		"#............................#",
		"#............................#",
		"#............................#",
		"#............................#",
		"##############################",
	), run_loc_floor_bottom_left)
	var/turf/start = locate(yard.origin_x + 3, yard.origin_y + 3, yard.z)
	var/mob/living/carbon/human/soldier = make_soldier(start, armed = FALSE)
	TEST_ASSERT_NOTNULL(soldier, "The soldier took no brain")
	var/datum/human_ai_brain/brain = soldier.ai_brain

	var/turf/far = locate(start.x + 18, start.y + 1, start.z)
	var/datum/npc_order/move/go = new
	go.target_turf = far
	TEST_ASSERT(brain.give_order(go), "A move command was refused")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(order_over), go), 40), "The move order never ended, the soldier is at [soldier.x],[soldier.y]: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(go.status, HAI_ORDER_DONE, "The move order ended as [go.status] and not done")
	TEST_ASSERT(get_dist(soldier, far) <= 2, "The soldier stopped [get_dist(soldier, far)] tiles short of the move goal")
	TEST_ASSERT_EQUAL(brain.orders_completed, 1, "A finished order was not counted")
	TEST_ASSERT(!brain.current_order, "The finished order is still held")

	var/datum/npc_order/hold/stay = new
	TEST_ASSERT(brain.give_order(stay), "A hold command was refused")
	var/turf/held = get_turf(soldier)
	soldier.forceMove(locate(held.x - 5, held.y + 2, held.z))
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(near_turf), soldier, held, 1), 20), "The soldier did not go back to its held position, it is at [soldier.x],[soldier.y]")
	TEST_ASSERT_EQUAL(stay.status, HAI_ORDER_ACTIVE, "A hold order ended on its own")
	brain.cancel_order()
	TEST_ASSERT_EQUAL(stay.status, HAI_ORDER_CANCELLED, "A cancelled order was not marked cancelled")
	TEST_ASSERT(!brain.current_order, "A cancelled order is still held")

	var/mob/living/carbon/human/guide = make_soldier(locate(start.x + 2, start.y + 4, start.z), armed = FALSE)
	var/turf/guide_goal = locate(start.x + 22, start.y + 4, start.z)
	guide.ai_brain.waypoint = guide_goal
	soldier.forceMove(locate(guide.x - 2, guide.y, guide.z))
	var/datum/npc_order/follow/trail = new
	trail.set_target(guide)
	TEST_ASSERT(brain.give_order(trail), "A follow command was refused")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(near_turf), guide, guide_goal, 1), 40), "The guide never reached its goal")
	sleep(4 SECONDS)
	TEST_ASSERT(get_dist(soldier, guide) <= 5, "The follower is [get_dist(soldier, guide)] tiles from the one it follows")
	brain.cancel_order()
	qdel(guide)

	var/turf/post_a = locate(start.x + 4, start.y + 3, start.z)
	var/turf/post_b = locate(start.x + 12, start.y + 3, start.z)
	var/turf/post_c = locate(start.x + 12, start.y - 2, start.z)
	soldier.forceMove(post_c)
	var/datum/npc_order/patrol/round = new
	round.waypoints = list(post_a, post_b, post_c)
	TEST_ASSERT(brain.give_order(round), "A patrol command was refused")
	var/list/visited = list()
	for(var/watch_step in 1 to 200)
		for(var/turf/post in round.waypoints)
			if(get_dist(soldier, post) <= 1)
				visited[post] = TRUE
		if(length(visited) >= 3)
			break
		sleep(2.5)
	TEST_ASSERT(length(visited) >= 3, "The patrol visited [length(visited)] of its 3 posts: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(round.status, HAI_ORDER_ACTIVE, "A patrol ended on its own")
	brain.cancel_order()

	soldier.forceMove(locate(start.x + 10, start.y + 2, start.z))
	var/turf/threat_turf = locate(start.x + 20, start.y + 2, start.z)
	var/turf/safe = brain.retreat_turf(threat_turf)
	TEST_ASSERT_NOTNULL(safe, "No retreat turf was found")
	TEST_ASSERT(get_dist(safe, threat_turf) > get_dist(soldier, threat_turf), "The retreat turf is not away from the threat")
	var/datum/npc_order/fall_back/pull_out = new
	pull_out.target_turf = safe
	TEST_ASSERT(brain.give_order(pull_out), "A fall back command was refused")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(order_over), pull_out), 30), "The fall back never ended")
	TEST_ASSERT_EQUAL(pull_out.status, HAI_ORDER_DONE, "The fall back ended as [pull_out.status]")
	TEST_ASSERT(get_dist(soldier, threat_turf) > 10, "The soldier is still [get_dist(soldier, threat_turf)] tiles from the threat")

	var/turf/shooter_turf = locate(start.x + 22, start.y + 2, start.z)
	for(var/offset in -1 to 1)
		var/obj/structure/barricade/metal/cade = new(locate(start.x + 6, start.y + 2 + offset, start.z))
		cade.setDir(EAST)
	soldier.forceMove(locate(start.x + 4, start.y + 2, start.z))
	var/datum/npc_order/take_cover/duck = new
	duck.target_turf = shooter_turf
	duck.duration = 40 SECONDS
	TEST_ASSERT(brain.give_order(duck), "A take cover command was refused")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(brain_in_cover), brain, shooter_turf), 20), "The soldier never took cover, at [soldier.x],[soldier.y]: [brain.decision_log.Join(" | ")]")
	brain.cancel_order()

	soldier.forceMove(start)
	var/datum/npc_order/clear_room/sweep = new
	sweep.target_turf = start
	TEST_ASSERT(brain.give_order(sweep), "A clear room command was refused")
	TEST_ASSERT(length(sweep.waypoints) >= 3, "A room clearing planned only [length(sweep.waypoints)] stops")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(order_over), sweep), 90), "The room was never cleared, stop [sweep.waypoint_index] of [length(sweep.waypoints)]")
	TEST_ASSERT_EQUAL(sweep.status, HAI_ORDER_DONE, "The room clearing ended as [sweep.status]")
	TEST_ASSERT_EQUAL(brain.error_total, 0, "The brain threw errors under orders")
	detach_human_ai(soldier)

/// Combat orders: attack, suppress and stand down
/datum/unit_test/human_ai_orders_combat

/datum/unit_test/human_ai_orders_combat/proc/shot_fired(datum/human_ai_brain/brain, count)
	return brain.shots_fired >= count

/datum/unit_test/human_ai_orders_combat/proc/aims_at(datum/human_ai_brain/brain, mob/living/target)
	return brain.get_target() == target

/datum/unit_test/human_ai_orders_combat/Run()
	var/datum/human_ai_arena/yard = new(list(
		"##############################",
		"#............................#",
		"#............................#",
		"#............................#",
		"#............................#",
		"#............................#",
		"##############################",
	), run_loc_floor_bottom_left)
	var/turf/start = locate(yard.origin_x + 3, yard.origin_y + 3, yard.z)
	var/mob/living/carbon/human/soldier = make_soldier(start)
	TEST_ASSERT_NOTNULL(soldier, "The soldier took no brain")
	var/datum/human_ai_brain/brain = soldier.ai_brain

	var/mob/living/carbon/xenomorph/drone/near_dummy = make_target_dummy(locate(start.x + 6, start.y, start.z))
	var/mob/living/carbon/xenomorph/drone/far_dummy = make_target_dummy(locate(start.x + 12, start.y + 1, start.z))
	var/datum/npc_order/attack/strike = new
	strike.set_target(far_dummy)
	TEST_ASSERT(brain.give_order(strike), "An attack command was refused")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(aims_at), brain, far_dummy), 8), "The soldier did not turn on the ordered target, it is on [brain.get_target()]: [brain.decision_log.Join(" | ")]")
	sleep(4 SECONDS)
	TEST_ASSERT_EQUAL(brain.get_target(), far_dummy, "The soldier dropped the ordered target for the closer one")
	qdel(far_dummy)
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(order_over), strike), 8), "The attack order did not end when its target was gone")
	TEST_ASSERT_EQUAL(strike.status, HAI_ORDER_DONE, "The attack ended as [strike.status]")
	qdel(near_dummy)
	brain.set_target(null)

	var/turf/area_turf = locate(start.x + 14, start.y, start.z)
	var/shots_before = brain.shots_fired
	var/datum/npc_order/suppress/spray = new
	spray.target_turf = area_turf
	TEST_ASSERT(brain.give_order(spray), "A suppress command was refused")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(shot_fired), brain, shots_before + 3), 8), "The soldier fired only [brain.shots_fired - shots_before] shots at the area")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(order_over), spray), 12), "The suppress order did not run out")
	TEST_ASSERT_EQUAL(spray.status, HAI_ORDER_EXPIRED, "The suppress order ended as [spray.status] and not expired")

	var/mob/living/carbon/xenomorph/drone/intruder = make_target_dummy(locate(start.x + 8, start.y, start.z))
	var/datum/npc_order/stand_down/calm = new
	TEST_ASSERT(brain.give_order(calm), "A stand down command was refused")
	TEST_ASSERT_EQUAL(brain.roe, HAI_ROE_WEAPONS_HOLD, "Standing down did not hold fire")
	var/held_shots = brain.shots_fired
	sleep(6 SECONDS)
	TEST_ASSERT_EQUAL(brain.shots_fired, held_shots, "The soldier fired while standing down")
	brain.on_shot_at(intruder)
	TEST_ASSERT_EQUAL(brain.roe, HAI_ROE_WEAPONS_FREE, "Being shot at did not end the stand down")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(shot_fired), brain, held_shots + 1), 10), "The soldier never shot back after the stand down")
	TEST_ASSERT_EQUAL(brain.error_total, 0, "The brain threw errors under orders")
	detach_human_ai(soldier)

/// Refusals, expiry and the compliance roll
/datum/unit_test/human_ai_orders_rules

/datum/unit_test/human_ai_orders_rules/proc/personality_with(discipline, loyalty, courage)
	var/datum/human_ai_personality/custom = new
	custom.id = "test"
	custom.traits = list("discipline" = discipline, "loyalty" = loyalty, "courage" = courage)
	return custom

/datum/unit_test/human_ai_orders_rules/Run()
	var/datum/human_ai_arena/yard = new(list(
		"##############",
		"#............#",
		"#............#",
		"#............#",
		"##############",
	), run_loc_floor_bottom_left)
	var/turf/start = locate(yard.origin_x + 3, yard.origin_y + 2, yard.z)
	var/mob/living/carbon/human/soldier = make_soldier(start)
	TEST_ASSERT_NOTNULL(soldier, "The soldier took no brain")
	var/datum/human_ai_brain/brain = soldier.ai_brain

	var/datum/npc_order/hold/stay = new
	TEST_ASSERT(brain.give_order(stay), "A hold command was refused")
	var/datum/npc_order/fortify/dig = new
	TEST_ASSERT(!brain.give_order(dig), "A rifleman accepted an order for an engineer")
	TEST_ASSERT_EQUAL(dig.status, HAI_ORDER_REFUSED, "A refused order was not marked refused")
	TEST_ASSERT_EQUAL(dig.refuse_reason, "no engineer kit", "The refusal gave the wrong reason")
	var/datum/npc_order/triage/heal = new
	TEST_ASSERT(!brain.give_order(heal), "A rifleman accepted an order for a medic")
	TEST_ASSERT_EQUAL(brain.orders_refused, 2, "Refusals were not counted")
	TEST_ASSERT_EQUAL(brain.current_order, stay, "A refused order replaced the running one")
	TEST_ASSERT_EQUAL(stay.status, HAI_ORDER_ACTIVE, "A refused order cancelled the running one")

	var/datum/npc_order/hold/short = new
	short.duration = 3 SECONDS
	TEST_ASSERT(brain.give_order(short), "A timed hold command was refused")
	TEST_ASSERT_EQUAL(stay.status, HAI_ORDER_CANCELLED, "A new order did not replace the old one")
	sleep(5 SECONDS)
	TEST_ASSERT_EQUAL(short.status, HAI_ORDER_EXPIRED, "A timed order did not expire")
	TEST_ASSERT(!brain.current_order, "An expired order is still held")

	var/datum/npc_order/attack/danger_zone = new
	danger_zone.danger = 0.8
	danger_zone.set_target(soldier)
	danger_zone.delivery = HAI_DELIVERY_REQUEST
	var/datum/human_ai_personality/zealot = personality_with(95, 95, 100)
	var/datum/human_ai_personality/coward = personality_with(10, 40, 5)
	var/datum/human_ai_personality/steady = personality_with(50, 50, 50)
	brain.personality = zealot
	var/zealot_chance = brain.comply_chance(danger_zone)
	brain.personality = coward
	var/coward_chance = brain.comply_chance(danger_zone)
	brain.personality = steady
	var/steady_chance = brain.comply_chance(danger_zone)
	TEST_NOTICE(src, "A 0.8 danger request is obeyed with chance [round(zealot_chance, 0.01)] by a zealot, [round(steady_chance, 0.01)] by a steady type, [round(coward_chance, 0.01)] by a coward")
	TEST_ASSERT(zealot_chance > 0.85, "A zealot obeys a dangerous request only [zealot_chance] of the time")
	TEST_ASSERT(coward_chance < 0.4, "A coward obeys a dangerous request [coward_chance] of the time")
	TEST_ASSERT(zealot_chance > steady_chance && steady_chance > coward_chance, "Compliance does not follow the traits")
	brain.stress = 80
	TEST_ASSERT(brain.comply_chance(danger_zone) < steady_chance, "Stress did not lower compliance")
	brain.stress = 0
	danger_zone.delivery = HAI_DELIVERY_COMMAND
	TEST_ASSERT_EQUAL(brain.comply_chance(danger_zone), 1, "A command was not always obeyed")
	danger_zone.delivery = HAI_DELIVERY_REQUEST
	danger_zone.danger = 0
	brain.personality = coward
	TEST_ASSERT_EQUAL(brain.comply_chance(danger_zone), 1, "A harmless request was not always obeyed")

	brain.personality = coward
	var/refused_before = brain.orders_refused
	var/balked = 0
	for(var/trial in 1 to 100)
		var/datum/npc_order/hold/risky = new
		risky.danger = 0.9
		if(!brain.give_order(risky, HAI_DELIVERY_REQUEST))
			balked++
	TEST_ASSERT(balked >= 60, "A coward balked at only [balked] of 100 dangerous requests")
	TEST_ASSERT_EQUAL(brain.orders_refused, refused_before + balked, "Balking was not counted as refusing")
	brain.cancel_order()
	TEST_ASSERT_EQUAL(brain.error_total, 0, "The brain threw errors under orders")
	detach_human_ai(soldier)
