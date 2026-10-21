/// Security keeps to its rules of engagement: rubber when only nonlethal is allowed, the baton at reach, cuffs on whoever is down, a finishing shot at the head when merciless
/datum/unit_test/human_ai_security_force
	var/datum/human_ai_brain/guard
	var/mob/living/carbon/human/suspect
	var/obj/item/weapon/baton/test_baton

/datum/unit_test/human_ai_security_force/proc/cuffed()
	return !!suspect.handcuffed

/datum/unit_test/human_ai_security_force/proc/dead()
	return suspect.stat == DEAD

/datum/unit_test/human_ai_security_force/proc/rubber_fired(shots)
	return guard.shots_fired >= shots

/datum/unit_test/human_ai_security_force/proc/baton_live()
	return !!test_baton?.status

/datum/unit_test/human_ai_security_force/proc/baton_spent(obj/item/weapon/baton/baton, charge_before)
	return baton.bcell.charge < charge_before

/datum/unit_test/human_ai_security_force/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/datum/human_ai_arena/ward = new(list(
		"##############################",
		"#............................#",
		"#............................#",
		"#............................#",
		"#............................#",
		"##############################",
	), run_loc_floor_bottom_left)
	var/turf/start = locate(ward.origin_x + 4, ward.origin_y + 2, ward.z)

	var/mob/living/carbon/human/officer = make_soldier(start, FACTION_MARSHAL, TRUE, "professional")
	TEST_ASSERT_NOTNULL(officer, "The officer took no brain")
	guard = officer.ai_brain
	guard.set_role("security")
	TEST_ASSERT_EQUAL(guard.roe, HAI_ROE_WEAPONS_TIGHT, "Marshals did not start tight")
	var/obj/item/weapon/gun/rifle/m41a/lethal = locate() in officer.contents
	TEST_ASSERT_NOTNULL(lethal, "The officer has no rifle")
	var/obj/item/weapon/gun/rifle/m41a/rubber = new(officer, TRUE)
	var/obj/item/ammo_magazine/rifle/rubber/rubber_mag = new(rubber)
	rubber.reload(null, rubber_mag)
	var/obj/item/storage/backpack/bag = new(officer)
	officer.equip_to_slot_if_possible(bag, WEAR_BACK)
	rubber.forceMove(bag)
	TEST_ASSERT(guard.gun_is_nonlethal(rubber), "A rubber loaded rifle is not seen as nonlethal")
	TEST_ASSERT(!guard.gun_is_nonlethal(lethal), "A ball loaded rifle is seen as nonlethal")
	guard.roe = HAI_ROE_NONLETHAL_ONLY
	var/lethal_rounds = lethal.current_mag.current_rounds
	suspect = allocate(/mob/living/carbon/human, locate(start.x + 7, start.y, start.z))
	suspect.faction = FACTION_CLF
	SSspatial_grid.track(suspect, SPATIAL_GRID_TRACK_NPC)
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(rubber_fired), 2), 20), "The officer never fired the rubber rifle, holding [officer.get_active_hand()]: [guard.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(lethal.current_mag.current_rounds, lethal_rounds, "The officer fired live rounds under nonlethal rules")
	guard.set_target(null)
	qdel(suspect)

	guard.roe = HAI_ROE_WEAPONS_TIGHT
	var/obj/item/weapon/baton/baton = new(officer)
	test_baton = baton
	var/obj/item/restraint/handcuffs/cuffs = new(bag)
	officer.forceMove(start)
	suspect = allocate(/mob/living/carbon/human, locate(start.x + 2, start.y, start.z))
	suspect.faction = FACTION_CLF
	SSspatial_grid.track(suspect, SPATIAL_GRID_TRACK_NPC)
	var/charge_before = baton.bcell.charge
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(baton_live)), 15), "The officer never armed its baton, police skill [officer.skills?.get_skill_level(SKILL_POLICE)], baton status [baton.status] charge [baton.bcell?.charge], hand [officer.get_active_hand()], intent [guard.intent], target [guard.get_target()], distance [get_dist(officer, suspect)], suspect stat [suspect.stat], hands [officer.get_active_hand()] and [officer.get_inactive_hand()]: [guard.decision_log.Join(" | ")]")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(baton_spent), baton, charge_before), 15), "The officer never struck with the baton: [guard.decision_log.Join(" | ")]")
	suspect.KnockOut(60)
	sleep(3 SECONDS)
	var/shots_then = guard.shots_fired
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(cuffed)), 40), "The officer did not cuff the man who was down, prisoners [guard.prisoners], cuffs at [cuffs.loc]: [guard.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(guard.shots_fired, shots_then, "The officer shot a man who was down")
	TEST_ASSERT(guard.prisoners >= 1, "The cuffing was not counted")
	TEST_ASSERT_EQUAL(guard.get_disposition(suspect), HAI_DISP_NEUTRAL, "A cuffed man is still seen as a threat")
	TEST_ASSERT_NOTNULL(cuffs, "The cuffs are gone")
	qdel(suspect)

	var/mob/living/carbon/human/giver_up = make_soldier(locate(start.x + 6, start.y + 1, start.z), FACTION_CLF, FALSE)
	giver_up.ai_brain.begin_break(HAI_BREAK_SURRENDER)
	suspect = giver_up
	guard.next_prisoner_search = 0
	new /obj/item/restraint/handcuffs(bag)
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(cuffed)), 40), "The officer did not take the surrender: [guard.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(guard.error_total, 0, "The officer's brain threw errors")
	detach_human_ai(officer)
	detach_human_ai(giver_up)

	var/mob/living/carbon/human/killer = make_soldier(locate(start.x + 12, start.y + 1, start.z), FACTION_PMC, TRUE, "ruthless")
	killer.ai_brain.set_role("security")
	killer.ai_brain.roe = HAI_ROE_WEAPONS_FREE
	suspect = allocate(/mob/living/carbon/human, locate(start.x + 17, start.y + 1, start.z))
	suspect.faction = FACTION_CLF
	SSspatial_grid.track(suspect, SPATIAL_GRID_TRACK_NPC)
	suspect.KnockOut(60)
	suspect.apply_damage(60, BRUTE, "chest")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(dead)), 40), "The ruthless guard did not finish the downed man, he has [suspect.health] health: [killer.ai_brain.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(killer.zone_selected, "head", "The finishing shot was not aimed at the head")
	detach_human_ai(killer)

/// A stack at a door opens it, flashes the room, waits out the flash and goes in; it will not flash a friend
/datum/unit_test/human_ai_breach
	var/datum/human_ai_squad/team
	var/mob/living/carbon/human/occupant

/datum/unit_test/human_ai_breach/proc/breach_over()
	return team.breach_state == HAI_BREACH_IDLE && length(team.breach_log) > 2

/datum/unit_test/human_ai_breach/proc/log_has(text)
	for(var/entry in team.breach_log)
		if(findtext(entry, text))
			return TRUE
	return FALSE

/datum/unit_test/human_ai_breach/proc/build(hostage = FALSE, protected = TRUE, shallow = FALSE)
	var/list/layout = shallow ? list(
		"################",
		"#..........#...#",
		"#..........#...#",
		"#..........D...#",
		"#..........#...#",
		"#..........#...#",
		"################",
	) : list(
		"####################",
		"#..........#.......#",
		"#..........#.......#",
		"#..........D.......#",
		"#..........#.......#",
		"#..........#.......#",
		"####################",
	)
	var/datum/human_ai_arena/block = new(layout, run_loc_floor_bottom_left)
	var/list/bodies = list()
	for(var/index in 0 to 2)
		var/mob/living/carbon/human/cop = make_soldier(locate(block.origin_x + 2 + index, block.origin_y + 2 + index % 2, block.z), FACTION_MARSHAL, TRUE, "professional")
		cop.ai_brain.set_role("security")
		if(protected)
			var/obj/item/clothing/glasses/sunglasses/sechud/shades = new(cop)
			shades.forceMove(cop)
			cop.glasses = shades
		var/obj/item/storage/backpack/bag = new(cop)
		cop.equip_to_slot_if_possible(bag, WEAR_BACK)
		if(index == 1)
			new /obj/item/explosive/grenade/flashbang(bag)
		bodies += cop
	team = create_human_ai_squad(bodies, bodies[1], "Breach Team")
	occupant = allocate(/mob/living/carbon/human, locate(block.origin_x + (shallow ? 13 : 16), block.origin_y + 2, block.z))
	occupant.faction = FACTION_CLF
	SSspatial_grid.track(occupant, SPATIAL_GRID_TRACK_NPC)
	if(hostage)
		var/mob/living/carbon/human/captive = make_soldier(locate(block.origin_x + 14, block.origin_y + 2, block.z), FACTION_MARSHAL, FALSE)
		captive.ai_brain.begin_break(HAI_BREAK_FREEZE)
		captive.ai_brain.broken_until = world.time + 60 SECONDS
	return block

/datum/unit_test/human_ai_breach/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/datum/human_ai_arena/block = build()
	var/turf/door_turf = locate(block.origin_x + 11, block.origin_y + 2, block.z)
	var/datum/npc_order/breach/go = new
	go.target_turf = door_turf
	TEST_ASSERT(team.issue_order(go) >= 2, "The breach did not start: [team.breach_log.Join(" | ")]")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(breach_over)), 80), "The breach never ended, state [team.breach_state]: [team.breach_log.Join(" | ")]")
	TEST_ASSERT(log_has("stacked") && log_has("door open") && log_has("flash thrown") && log_has("entering") && log_has("cleared"), "The breach skipped a step: [team.breach_log.Join(" | ")]")
	var/list/steps = list("stacked", "door open", "flash thrown", "entering", "cleared")
	var/last_position = 0
	for(var/step in steps)
		var/position = 0
		for(var/index in 1 to length(team.breach_log))
			if(findtext(team.breach_log[index], step))
				position = index
				break
		TEST_ASSERT(position > last_position, "The breach did [step] out of order: [team.breach_log.Join(" | ")]")
		last_position = position
	TEST_ASSERT_EQUAL(team.flashes_thrown, 1, "The team threw [team.flashes_thrown] flashes")
	var/inside = 0
	for(var/datum/human_ai_brain/brain as anything in team.members)
		if(brain.body.x > block.origin_x + 11)
			inside++
		TEST_ASSERT_EQUAL(brain.error_total, 0, "A brain threw errors during the breach: [brain.decision_log.Join(" | ")]")
	if(inside < 2)
		var/list/member_logs = list()
		for(var/datum/human_ai_brain/brain as anything in team.members)
			member_logs += "[brain.body.x],[brain.body.y]: [brain.decision_log.Join(" | ")]"
		TEST_FAIL("Only [inside] of the team went in: [team.breach_log.Join(" | ")] // [member_logs.Join(" // ")]")
		return
	TEST_ASSERT(occupant.stat != CONSCIOUS || occupant.health < occupant.maxHealth, "The man inside was not touched")
	var/list/to_detach = list()
	for(var/datum/human_ai_brain/brain as anything in team.members)
		to_detach += brain.body
	team.disband()
	for(var/mob/living/carbon/human/cop as anything in to_detach)
		detach_human_ai(cop)

	var/datum/human_ai_arena/hostage_block = build(TRUE, TRUE)
	var/turf/second_door = locate(hostage_block.origin_x + 11, hostage_block.origin_y + 2, hostage_block.z)
	var/datum/npc_order/breach/second = new
	second.target_turf = second_door
	TEST_ASSERT(team.issue_order(second) >= 2, "The second breach did not start")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(breach_over)), 80), "The second breach never ended: [team.breach_log.Join(" | ")]")
	TEST_ASSERT(log_has("blocked"), "The team did not notice the friend in the room: [team.breach_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(team.flashes_thrown, 0, "The team flashed a room with a friend in it")
	var/list/second_detach = list()
	for(var/datum/human_ai_brain/brain as anything in team.members)
		second_detach += brain.body
	team.disband()
	for(var/mob/living/carbon/human/cop as anything in second_detach)
		detach_human_ai(cop)

	var/datum/human_ai_arena/bare_block = build(FALSE, FALSE, TRUE)
	var/turf/third_door = locate(bare_block.origin_x + 11, bare_block.origin_y + 2, bare_block.z)
	var/datum/npc_order/breach/third = new
	third.target_turf = third_door
	TEST_ASSERT(team.issue_order(third) >= 2, "The third breach did not start")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(breach_over)), 80), "The third breach never ended: [team.breach_log.Join(" | ")]")
	TEST_ASSERT(log_has("exposed") || log_has("blocked"), "The team with bare eyes did not hold its flash back: [team.breach_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(team.flashes_thrown, 0, "The team flashed a room it was too close to with its eyes bare")
	var/list/third_detach = list()
	for(var/datum/human_ai_brain/brain as anything in team.members)
		third_detach += brain.body
	team.disband()
	for(var/mob/living/carbon/human/cop as anything in third_detach)
		detach_human_ai(cop)
