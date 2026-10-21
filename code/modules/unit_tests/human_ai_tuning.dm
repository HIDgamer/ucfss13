/// A shooter holds fire for a friend on the line, past the target where a miss carries on, or beside it where the aim can wander, and a clear line is still taken
/datum/unit_test/human_ai_friendly_fire

/datum/unit_test/human_ai_friendly_fire/proc/ready_to_fire(datum/human_ai_brain/brain, obj/item/weapon/gun/gun)
	return brain.gun_can_shoot_now(gun)

/datum/unit_test/human_ai_friendly_fire/Run()
	var/datum/human_ai_arena/field = new(list(
		"####################",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"####################",
	), run_loc_floor_bottom_left)
	var/turf/start = locate(field.origin_x + 2, field.origin_y + 3, field.z)
	var/mob/living/carbon/human/shooter = make_soldier(start)
	var/datum/human_ai_brain/brain = shooter.ai_brain
	// The test pulls the trigger itself, so the brain is told to hold fire and the gun is made ready by hand
	brain.roe = HAI_ROE_WEAPONS_HOLD
	var/obj/item/weapon/gun/gun = brain.peek_gun()
	TEST_ASSERT_NOTNULL(gun, "The shooter has no gun")
	if(brain.weapon_state(gun) == HAI_WEAPON_SAFE)
		brain.release_safety(gun)
	var/mob/living/carbon/xenomorph/drone/dummy = make_target_dummy(locate(start.x + 8, start.y, start.z))
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(ready_to_fire), brain, gun), 8), "The gun never became ready to fire, state [brain.weapon_state(gun)]")

	TEST_ASSERT(!brain.friendly_in_lane(dummy), "An empty line was called unsafe")
	TEST_ASSERT(brain.safe_to_fire(gun, dummy), "An empty line was not safe to fire along")

	var/mob/living/carbon/human/friend = allocate(/mob/living/carbon/human, locate(start.x + 4, start.y, start.z))
	friend.faction = FACTION_MARINE
	TEST_ASSERT(brain.friendly_in_lane(dummy), "A friend standing on the line was not seen")
	TEST_ASSERT(!brain.safe_to_fire(gun, dummy), "The shooter would fire through a friend")
	TEST_ASSERT(brain.gun_can_shoot_now(gun), "The gun is not ready, the hold below would prove nothing")
	var/shots = brain.shots_fired
	TEST_ASSERT(!brain.shoot(gun, dummy), "The shooter fired with a friend in the way")
	TEST_ASSERT(brain.ff_holds >= 1, "The held shot was not counted")
	TEST_ASSERT_EQUAL(brain.shots_fired, shots, "A shot went out with a friend in the way")

	friend.forceMove(locate(start.x + 12, start.y, start.z))
	TEST_ASSERT(brain.friendly_in_lane(dummy), "A friend just behind the target, where a miss would land, was not seen")
	friend.forceMove(locate(start.x + 16, start.y, start.z))
	TEST_ASSERT(!brain.friendly_in_lane(dummy), "A friend far behind the target stopped the shot")

	friend.forceMove(locate(start.x + 8, start.y + 1, start.z))
	TEST_ASSERT(!brain.friendly_in_lane(dummy, 0), "A friend beside the target stopped a perfectly aimed shot")
	TEST_ASSERT(!brain.friendly_in_lane(dummy, HAI_FF_SPREAD * 0.5), "A tiny aim error made a friend beside the target a danger")
	TEST_ASSERT(brain.friendly_in_lane(dummy, 1), "A friend beside the target was not a danger to a wandering aim")

	friend.forceMove(locate(start.x + 4, start.y + 2, start.z))
	TEST_ASSERT(!brain.friendly_in_lane(dummy, 0), "A friend well off the line stopped the shot")
	var/mob/living/carbon/xenomorph/drone/second = allocate(/mob/living/carbon/xenomorph/drone, locate(start.x + 4, start.y, start.z))
	TEST_ASSERT(!brain.friendly_in_lane(dummy, 0), "An enemy on the line was counted as a friend")
	qdel(second)

	// A lethal grenade spares anyone who is not an enemy, neutrals too, and a soft one only friends
	var/mob/living/carbon/human/colonist = allocate(/mob/living/carbon/human, locate(start.x + 12, start.y + 1, start.z))
	colonist.faction = FACTION_COLONIST
	friend.forceMove(locate(start.x + 16, start.y + 4, start.z))
	var/turf/spot = locate(start.x + 10, start.y, start.z)
	TEST_ASSERT(!brain.grenade_spot_is_safe(spot, HAI_GRENADE_LETHAL), "A blast was thrown next to a neutral")
	TEST_ASSERT(brain.grenade_spot_is_safe(spot, HAI_GRENADE_FLASH), "A flash was refused for a neutral beside it")
	colonist.forceMove(locate(start.x + 16, start.y + 3, start.z))
	TEST_ASSERT(brain.grenade_spot_is_safe(spot, HAI_GRENADE_LETHAL), "A blast was refused on a clear spot")
	var/mob/living/carbon/human/in_path = allocate(/mob/living/carbon/human, locate(start.x + 5, start.y, start.z))
	in_path.faction = FACTION_MARINE
	TEST_ASSERT(!brain.grenade_spot_is_safe(spot, HAI_GRENADE_LETHAL), "A grenade was thrown through a friend in its path")
	TEST_ASSERT_EQUAL(brain.error_total, 0, "The shooter's brain threw errors")
	detach_human_ai(shooter)

/// A brain backs away from something that wins by getting close and shoots it while it comes, it does not walk up to it
/datum/unit_test/human_ai_keep_distance

/datum/unit_test/human_ai_keep_distance/proc/backed_off(mob/living/carbon/human/soldier, datum/human_ai_brain/brain, mob/living/threat)
	return brain.kites >= 1 && brain.shots_fired >= 1 && get_dist(soldier, threat) >= 5

/datum/unit_test/human_ai_keep_distance/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/list/rows = list("##############################")
	for(var/row in 1 to 5)
		rows += "#............................#"
	rows += "##############################"
	var/datum/human_ai_arena/hall = new(rows, run_loc_floor_bottom_left)
	var/turf/start = locate(hall.origin_x + 14, hall.origin_y + 3, hall.z)
	var/mob/living/carbon/human/soldier = make_soldier(start)
	var/datum/human_ai_brain/brain = soldier.ai_brain
	var/obj/item/weapon/gun/gun = brain.peek_gun()
	var/mob/living/carbon/xenomorph/drone/dummy = make_target_dummy(locate(start.x + 3, start.y, start.z))

	TEST_ASSERT(brain.melee_threat(dummy), "A xeno is not seen as something that wins by getting close")
	TEST_ASSERT(!brain.melee_threat(soldier), "A human was seen as something that wins by getting close")
	TEST_ASSERT_NULL(brain.nearest_melee_threat(), "A threat was found with none in sight")
	brain.set_target(dummy)
	brain.target_seen_time = world.time
	TEST_ASSERT_EQUAL(brain.nearest_melee_threat(), dummy, "The target xeno was not the nearest threat")
	TEST_ASSERT(brain.comfort_distance(dummy, gun) > 3, "The comfortable distance from a xeno is [brain.comfort_distance(dummy, gun)] tiles")
	SShuman_ai.cover_budget = HAI_COVER_SEARCHES_PER_FIRE
	var/turf/kite = brain.find_kite_turf(dummy)
	TEST_ASSERT_NOTNULL(kite, "There was no way to back off in an open hall")
	TEST_ASSERT(get_dist(kite, dummy) > get_dist(soldier, dummy), "The turf to back off to is not farther from the xeno")
	var/datum/human_ai_action/keep_distance/action = new
	brain.next_kite_time = 0
	SShuman_ai.cover_budget = HAI_COVER_SEARCHES_PER_FIRE
	TEST_ASSERT(action.get_weight(brain) > 0, "A xeno three tiles away did not make the brain want to back off")
	// Right next to the soldier the fight is on and backing away is no use
	dummy.forceMove(locate(start.x + 1, start.y, start.z))
	SShuman_ai.cover_budget = HAI_COVER_SEARCHES_PER_FIRE
	TEST_ASSERT_EQUAL(action.get_weight(brain), 0, "The brain tried to back away from a xeno that is already on it")
	dummy.forceMove(locate(start.x + 3, start.y, start.z))
	qdel(action)

	brain.set_target(null)
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(backed_off), soldier, brain, dummy), 25), "The soldier never backed away from the xeno while shooting it, distance [get_dist(soldier, dummy)], steps [brain.kites], shots [brain.shots_fired]: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(brain.error_total, 0, "The soldier's brain threw errors")
	detach_human_ai(soldier)

/datum/unit_test/human_ai_keep_distance/proc/wait_until(datum/callback/check, seconds)
	for(var/waited in 1 to seconds * 4)
		if(check.Invoke())
			return TRUE
		sleep(2.5)
	return check.Invoke()

/// Idle armed brains pick a spot with something solid at their back and a view, stand on it and stay there instead of strolling about
/datum/unit_test/human_ai_defensive_post
	var/list/datum/human_ai_brain/crew = list()

/datum/unit_test/human_ai_defensive_post/proc/all_posted()
	for(var/datum/human_ai_brain/brain as anything in crew)
		if(!brain.post_turf || get_turf(brain.body) != brain.post_turf)
			return FALSE
	return TRUE

/datum/unit_test/human_ai_defensive_post/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/datum/human_ai_arena/hall = new(list(
		"##################",
		"#................#",
		"#................#",
		"#................#",
		"#................#",
		"#................#",
		"#................#",
		"##################",
	), run_loc_floor_bottom_left)
	var/turf/middle = locate(hall.origin_x + 8, hall.origin_y + 3, hall.z)
	for(var/index in 0 to 2)
		var/mob/living/carbon/human/soldier = make_soldier(locate(middle.x + index - 1, middle.y, middle.z), FACTION_MARINE, FALSE)
		crew += soldier.ai_brain
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(all_posted)), 40), "Not everyone reached a post in forty seconds: [crew[1].post_turf] [crew[2].post_turf] [crew[3].post_turf]")

	var/list/spots = list()
	for(var/datum/human_ai_brain/brain as anything in crew)
		spots[brain] = get_turf(brain.body)
		TEST_ASSERT(get_dist(brain.post_turf, brain.home_turf) <= HAI_POST_RADIUS, "A post was [get_dist(brain.post_turf, brain.home_turf)] tiles from home")
		var/list/mid_rating = brain.post_value(middle, brain.home_turf)
		var/list/post_rating = brain.post_value(brain.post_turf, brain.home_turf)
		TEST_ASSERT_NOTNULL(post_rating, "A post has no value")
		TEST_ASSERT(!mid_rating || post_rating[1] > mid_rating[1], "A post in the open middle of the hall was as good as the one that was taken")
	TEST_ASSERT(crew[1].post_turf != crew[2].post_turf && crew[2].post_turf != crew[3].post_turf && crew[1].post_turf != crew[3].post_turf, "Two brains took the same post")

	sleep(45 SECONDS)
	for(var/datum/human_ai_brain/brain as anything in crew)
		TEST_ASSERT_EQUAL(get_turf(brain.body), spots[brain], "A brain left its post and ended up [get_dist(brain.body, spots[brain])] tiles away")
		TEST_ASSERT_EQUAL(brain.idle_wanders, 0, "A brain on watch strolled about")
		TEST_ASSERT_EQUAL(brain.intent, HAI_INTENT_IDLE, "A brain on watch left the idle intent")
		TEST_ASSERT_EQUAL(brain.error_total, 0, "A brain on watch threw errors")
	var/datum/human_ai_brain/civilian = crew[1]
	civilian.set_role("civilian")
	TEST_ASSERT(!civilian.holds_a_post(), "A civilian was given a post")
	for(var/datum/human_ai_brain/brain as anything in crew)
		detach_human_ai(brain.body)

/// Something climbable is gone around when it can be, never climbed for fun, and not hopped over one after another
/datum/unit_test/human_ai_table_climbing

/datum/unit_test/human_ai_table_climbing/Run()
	var/datum/human_ai_arena/hall = new(list(
		"##############",
		"#............#",
		"#............#",
		"#............#",
		"##############",
	), run_loc_floor_bottom_left)
	var/turf/start = locate(hall.origin_x + 3, hall.origin_y + 2, hall.z)
	var/turf/table_turf = locate(start.x + 1, start.y, start.z)
	var/obj/structure/surface/table/table = allocate(/obj/structure/surface/table, table_turf)
	var/mob/living/carbon/human/soldier = make_soldier(start, FACTION_MARINE, FALSE)
	var/datum/human_ai_brain/brain = soldier.ai_brain
	var/list/obstacle = brain.find_obstacle(start, table_turf)
	TEST_ASSERT_NOTNULL(obstacle, "A table is not an obstacle at all")
	TEST_ASSERT_EQUAL(obstacle[1], HAI_OBS_CLIMB, "A table is not an obstacle that can be climbed")

	// Nothing pressing: the table is turned down, remembered and not climbed
	brain.set_intent(HAI_INTENT_IDLE)
	TEST_ASSERT(!brain.handle_climb(table, table_turf), "An idle brain agreed to climb a table")
	TEST_ASSERT(brain.is_blocked_turf(table_turf), "The table was not remembered as not worth climbing")
	TEST_ASSERT_EQUAL(brain.vaults, 0, "An idle brain climbed a table")

	// With a goal to reach it first looks for a way round, a couple of times, and only then climbs
	var/datum/npc_order/move/go = new
	go.target_turf = locate(start.x + 8, start.y, start.z)
	TEST_ASSERT(brain.give_order(go), "A move command was refused")
	brain.blocked_turfs = list()
	brain.climb_detours = 0
	for(var/detour in 1 to HAI_CLIMB_DETOURS)
		TEST_ASSERT(!brain.handle_climb(table, table_turf), "The brain climbed straight away instead of looking for a way round, detour [detour]")
		TEST_ASSERT_EQUAL(brain.climb_detours, detour, "The detour was not counted")
	TEST_ASSERT_EQUAL(brain.vaults, 0, "The brain climbed while it was still looking for a way round")
	brain.next_vault_time = 0
	brain.handle_climb(table, table_turf)
	TEST_ASSERT_EQUAL(brain.vaults, 1, "The brain never climbed after running out of ways round")
	var/climbed_at = brain.next_vault_time
	TEST_ASSERT(climbed_at > world.time, "A climb set no wait before the next one")
	TEST_ASSERT(brain.handle_climb(table, table_turf), "The brain did not wait out the pause between two climbs")
	TEST_ASSERT_EQUAL(brain.vaults, 1, "The brain hopped over a second table straight after the first")

	// Under fire there is no time to look for a way round
	sleep(1 SECONDS)
	brain.acting_until = 0
	brain.next_vault_time = 0
	brain.climb_detours = 0
	var/mob/living/carbon/xenomorph/drone/dummy = make_target_dummy(locate(start.x + 9, start.y, start.z))
	brain.set_target(dummy)
	brain.target_seen_time = world.time
	TEST_ASSERT(brain.climb_urgent(), "A brain with an enemy in sight was not in a hurry")
	brain.handle_climb(table, table_turf)
	TEST_ASSERT_EQUAL(brain.vaults, 2, "A brain under pressure did not climb at once")
	TEST_ASSERT_EQUAL(brain.error_total, 0, "The brain threw errors")
	detach_human_ai(soldier)

/// A medic treats with injectors without ever pushing a patient over the overdose limit, and anyone carrying one looks after themselves
/datum/unit_test/human_ai_injection_safety

/datum/unit_test/human_ai_injection_safety/Run()
	var/turf/start = run_loc_floor_bottom_left
	var/mob/living/carbon/human/medic = make_soldier(start, FACTION_MARINE, FALSE)
	var/datum/human_ai_brain/brain = medic.ai_brain
	brain.set_role("medic")
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human, locate(start.x + 1, start.y, start.z))
	patient.faction = FACTION_MARINE
	var/obj/item/reagent_container/hypospray/autoinjector/bicaridine/skillless/injector = new(medic)
	var/obj/item/reagent_container/hypospray/autoinjector/tramadol/painkiller = new(medic)
	brain.med_cache = null

	TEST_ASSERT_EQUAL(human_ai_injector_chem(injector), "bicaridine", "A bicaridine injector was not recognised")
	TEST_ASSERT_NULL(human_ai_injector_chem(painkiller), "A painkiller injector was taken for medicine")
	TEST_ASSERT_NULL(brain.injector_need(patient), "A patient with no damage was offered an injection")
	patient.adjustBruteLoss(40)
	var/list/need = brain.injector_need(patient)
	TEST_ASSERT_NOTNULL(need, "A patient with 40 brute was not offered an injection")
	TEST_ASSERT_EQUAL(need[1], injector, "The wrong injector was chosen")
	var/list/decided = brain.patient_need(patient)
	TEST_ASSERT_NOTNULL(decided, "The medic decided on nothing for a patient with 40 brute")
	TEST_ASSERT_EQUAL(decided[1], HAI_MED_INJECTOR, "The injection was not what the medic decided on")

	var/dose = injector.amount_per_transfer_from_this
	var/datum/reagent/chem = GLOB.chemical_reagents_list["bicaridine"]
	TEST_ASSERT(chem.overdose > dose, "The injector dose [dose] is not below the overdose limit [chem.overdose]")
	TEST_ASSERT(brain.inject(patient, injector), "The injection was refused: [brain.decision_log.Join(" | ")]")
	sleep(2 SECONDS)
	var/given = patient.reagents.get_reagent_amount("bicaridine")
	TEST_ASSERT(given > 0, "Nothing was injected")
	TEST_ASSERT(given <= chem.overdose, "The first injection put [given] units in a patient with the limit at [chem.overdose]")
	TEST_ASSERT_EQUAL(brain.injections, 1, "The injection was not counted")
	TEST_ASSERT_NULL(brain.injector_need(patient), "A patient who was just injected was offered another")
	brain.inject_times = list()
	patient.reagents.clear_reagents()
	patient.reagents.add_reagent("bicaridine", chem.overdose * HAI_INJECT_OD_MARGIN - dose + 0.5)
	TEST_ASSERT_NULL(brain.injector_need(patient), "An injection that would take the patient over the safe margin was offered")
	patient.reagents.clear_reagents()
	patient.reagents.add_reagent("bicaridine", chem.overdose * HAI_INJECT_OD_MARGIN - dose - 0.5)
	TEST_ASSERT_NOTNULL(brain.injector_need(patient), "A safe injection was refused")

	// Treating over and over never takes the patient past the limit, whatever the time between the injections
	patient.reagents.clear_reagents()
	for(var/round in 1 to 6)
		brain.inject_times = list()
		brain.acting_until = 0
		brain.med_cache = null
		var/list/next_need = brain.injector_need(patient)
		if(next_need)
			var/obj/item/reagent_container/hypospray/autoinjector/next_injector = next_need[1]
			if(next_injector.uses_left <= 0)
				break
			brain.inject(patient, next_injector)
			sleep(1 SECONDS)
		TEST_ASSERT(patient.reagents.get_reagent_amount("bicaridine") <= chem.overdose, "Round [round] put the patient at [patient.reagents.get_reagent_amount("bicaridine")] units, over the limit of [chem.overdose]")

	// Anyone who carries a healing injector treats themselves when nothing else is going on
	var/mob/living/carbon/human/rifleman = make_soldier(locate(start.x + 3, start.y, start.z), FACTION_MARINE, FALSE)
	new /obj/item/reagent_container/hypospray/autoinjector/kelotane/skillless(rifleman)
	rifleman.ai_brain.med_cache = null
	var/datum/human_ai_action/self_care/care = new
	TEST_ASSERT_EQUAL(care.get_weight(rifleman.ai_brain), 0, "An unhurt brain wanted to treat itself")
	rifleman.adjustFireLoss(40)
	TEST_ASSERT(care.get_weight(rifleman.ai_brain) > 0, "A burnt brain with a burn injector did not want to treat itself")
	qdel(care)
	TEST_ASSERT_EQUAL(brain.error_total + rifleman.ai_brain.error_total, 0, "A brain threw errors")
	detach_human_ai(medic)
	detach_human_ai(rifleman)

/// A console held to one faction only lists, selects and orders that faction, and an admin only action is refused to anyone who is not an admin
/datum/npc_command_console/test_commander
	var/test_scope

/datum/npc_command_console/test_commander/is_admin(mob/user)
	return FALSE

/datum/npc_command_console/test_commander/has_access(mob/user)
	selection.faction_scope = test_scope
	return TRUE

/datum/unit_test/human_ai_command_scope

/datum/unit_test/human_ai_command_scope/Run()
	var/datum/job/commander = human_ai_job_of_title(JOB_CO)
	TEST_ASSERT(human_ai_command_job(commander), "The Commanding Officer is not senior staff")
	TEST_ASSERT(!human_ai_command_job(human_ai_job_of_title(JOB_SQUAD_MARINE)), "A rifleman is senior staff")
	// The officers and the heads of the departments are command staff too
	for(var/title in GLOB.npc_command_staff_jobs)
		var/datum/job/staff = human_ai_job_of_title(title)
		// Not every job on the list is in every build
		if(staff)
			TEST_ASSERT(human_ai_command_job(staff), "[title] is not command staff")
	for(var/title in list(JOB_XO))
		TEST_ASSERT_NOTNULL(human_ai_job_of_title(title), "There is no job called [title]")
		TEST_ASSERT(human_ai_command_job(human_ai_job_of_title(title)), "[title] is not command staff")
	TEST_ASSERT(!human_ai_command_job(human_ai_job_of_title(JOB_POLICE)), "A military police officer is command staff")
	TEST_ASSERT(!human_ai_command_job(human_ai_job_of_title(JOB_SQUAD_LEADER)), "A squad leader is command staff")
	TEST_ASSERT(!human_ai_command_job(null), "No job at all is senior staff")

	var/turf/start = run_loc_floor_bottom_left
	var/mob/living/carbon/human/marine_one = make_soldier(start, FACTION_MARINE, FALSE)
	var/mob/living/carbon/human/marine_two = make_soldier(locate(start.x + 1, start.y, start.z), FACTION_MARINE, FALSE)
	var/mob/living/carbon/human/raider = make_soldier(locate(start.x + 2, start.y, start.z), FACTION_CLF, FALSE)
	var/mob/living/carbon/human/guard = make_soldier(locate(start.x + 3, start.y, start.z), FACTION_UPP, FALSE)
	var/mob/living/carbon/human/commander_body = allocate(/mob/living/carbon/human, locate(start.x + 4, start.y, start.z))

	var/datum/npc_command_console/test_commander/console = new(commander_body)
	console.test_scope = FACTION_MARINE
	TEST_ASSERT(console.has_access(commander_body), "The test console refused its user")
	TEST_ASSERT(console.selection.valid(marine_one), "A unit of the commander's own faction was not commandable")
	TEST_ASSERT(!console.selection.valid(raider), "A unit of another faction was commandable")
	TEST_ASSERT(!console.selection.select(guard), "A unit of another faction was selected")
	TEST_ASSERT(console.selection.select(marine_two), "A unit of the commander's own faction was not selected")
	TEST_ASSERT_NULL(console.resolve_human(REF(raider)), "A unit of another faction was found by its reference")
	TEST_ASSERT_EQUAL(console.resolve_human(REF(marine_one)), marine_one, "A unit of the commander's own faction was not found by its reference")

	console.snapshot_time = -1000
	for(var/list/row as anything in console.get_snapshot())
		TEST_ASSERT_EQUAL(row["faction"], FACTION_MARINE, "The roster listed a unit of faction [row["faction"]]")
	TEST_ASSERT(length(console.get_snapshot()) >= 2, "The roster is missing the commander's own units")

	console.selection.clear()
	console.handle_action(commander_body, "select_all", list())
	var/list/chosen = console.selection.get_selected()
	TEST_ASSERT(length(chosen) >= 2, "Select all picked [length(chosen)] units")
	for(var/mob/living/carbon/human/human as anything in chosen)
		TEST_ASSERT_EQUAL(human.faction, FACTION_MARINE, "Select all picked up a unit of faction [human.faction]")

	var/datum/human_ai_squad/foreign_squad = create_human_ai_squad(list(raider, guard), raider, "Foreign")
	TEST_ASSERT_NOTNULL(foreign_squad, "The test squad was not made")
	TEST_ASSERT(!console.squad_in_scope(foreign_squad), "A squad of another faction was in scope")
	TEST_ASSERT_NULL(console.resolve_squad(REF(foreign_squad)), "A squad of another faction was found by its reference")
	var/datum/human_ai_squad/own_squad = create_human_ai_squad(list(marine_one, marine_two), marine_one, "Own")
	TEST_ASSERT(console.squad_in_scope(own_squad), "A squad of the commander's faction was out of scope")

	for(var/action in GLOB.npc_command_admin_actions)
		TEST_ASSERT(!console.handle_action(commander_body, action, list("ref" = REF(raider))), "The admin action [action] was allowed to a commander")
	console.tab = "roster"
	console.handle_action(commander_body, "set_tab", list("tab" = "debug"))
	TEST_ASSERT_EQUAL(console.tab, "roster", "A commander opened the debug tab")
	console.handle_action(commander_body, "set_tab", list("tab" = "squads"))
	TEST_ASSERT_EQUAL(console.tab, "squads", "A commander could not open the squads tab")
	var/list/data = console.ui_data(commander_body)
	TEST_ASSERT(data["restricted"], "The panel did not tell the interface it is restricted")
	TEST_ASSERT_EQUAL(data["faction_scope"], FACTION_MARINE, "The panel did not tell the interface which faction it is held to")

	qdel(foreign_squad)
	qdel(own_squad)
	qdel(console)
	for(var/mob/living/carbon/human/human in list(marine_one, marine_two, raider, guard))
		detach_human_ai(human)

/// A CLF unit breaks into a door it has no access to, anyone else gives up on it and does not keep walking back to it
/datum/unit_test/human_ai_door_hacking
	var/obj/structure/machinery/door/airlock/gate

/datum/unit_test/human_ai_door_hacking/proc/hacked_open(datum/human_ai_brain/brain)
	return brain.hacks >= 1

/datum/unit_test/human_ai_door_hacking/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/datum/human_ai_arena/block = new(list(
		"####################",
		"#..........#.......#",
		"#..........#.......#",
		"#..........A.......#",
		"#..........#.......#",
		"#..........#.......#",
		"####################",
	), run_loc_floor_bottom_left)
	gate = block.first_door("A")
	TEST_ASSERT_NOTNULL(gate, "The test arena made no door")
	var/turf/door_turf = get_turf(gate)
	var/turf/inside = locate(block.origin_x + 3, block.origin_y + 3, block.z)
	var/turf/beyond = locate(block.origin_x + 15, block.origin_y + 3, block.z)

	var/mob/living/carbon/human/raider = make_soldier(inside, FACTION_CLF, FALSE)
	var/datum/human_ai_brain/hacker = raider.ai_brain
	TEST_ASSERT(hacker.can_hack_doors(), "A CLF unit cannot hack doors")
	TEST_ASSERT(!gate.allowed(raider), "The test door lets the CLF in without a hack")
	// The bare test body had nowhere to carry the tools it is issued, a pack gives it somewhere
	dress(raider, new /obj/item/storage/backpack/lightpack(raider), WEAR_BACK)
	hacker.issue_hack_tools()
	TEST_ASSERT(hacker.find_hack_tools(), "The raider was not issued a screwdriver and wirecutters, it wears [raider.back] and carries [english_list(raider.get_contents())]")
	var/datum/npc_order/move/go = new
	go.target_turf = beyond
	TEST_ASSERT(hacker.give_order(go), "A move command was refused")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(hacked_open), hacker), 25), "The raider never hacked the door open: [hacker.decision_log.Join(" | ")]")
	TEST_ASSERT(!gate.requiresID(), "The ID scanner wire of the hacked door was not cut")
	TEST_ASSERT(!gate.panel_open, "The raider left the access panel of the hacked door open")
	TEST_ASSERT(gate.allowed(raider), "The hacked door still asks the raider for access")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(order_over), go), 30), "The raider never got through the door, it is at [raider.x],[raider.y]: [hacker.decision_log.Join(" | ")]")
	TEST_ASSERT(get_dist(raider, beyond) <= 3, "The raider stopped [get_dist(raider, beyond)] tiles short of the goal")
	TEST_ASSERT_EQUAL(hacker.error_total, 0, "The raider's brain threw errors")
	detach_human_ai(raider)

	// A marine cannot hack it and the door is left alone for a good while, instead of being walked up to again and again.
	// The raider left its door with the scanner wire cut, which lets anyone through, so the marine gets a fresh door that wants a card.
	qdel(gate)
	sleep(1)
	gate = new /obj/structure/machinery/door/airlock/almayer/generic(door_turf)
	gate.req_access = list(ACCESS_MARINE_COMMAND)
	SSxeno_pathfinding.push_delta(door_turf)
	TEST_ASSERT(!gate.allowed(null) && gate.requiresID(), "The fresh door does not ask for a card")
	var/mob/living/carbon/human/marine = make_soldier(locate(block.origin_x + 4, block.origin_y + 3, block.z), FACTION_MARINE, FALSE)
	var/datum/human_ai_brain/stuck = marine.ai_brain
	TEST_ASSERT(!stuck.can_hack_doors(), "A marine can hack doors")
	var/datum/npc_order/move/also_go = new
	also_go.target_turf = beyond
	stuck.give_order(also_go)
	// Count how often the marine walks up to the door after having been away from it, a brain that keeps trying makes a habit of it
	var/approaches = 0
	var/was_away = FALSE
	for(var/second in 1 to 40)
		sleep(1 SECONDS)
		var/distance = get_dist(marine, door_turf)
		if(distance >= 4)
			was_away = TRUE
		else if(distance <= 1 && was_away)
			approaches++
			was_away = FALSE
	TEST_ASSERT(approaches <= 2, "The marine walked up to the door it cannot open [approaches] times in forty seconds: [stuck.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(stuck.hacks, 0, "A marine hacked a door")
	TEST_ASSERT(gate.density, "The door was opened for a marine without access")
	TEST_ASSERT(stuck.is_blocked_turf(door_turf), "The door a marine cannot open was not remembered")
	TEST_ASSERT(stuck.blocked_turfs[door_turf] > world.time + HAI_DOOR_DENIED_MEMORY * 0.5, "The door a marine cannot open was only remembered for a moment")
	TEST_ASSERT_EQUAL(stuck.error_total, 0, "The marine's brain threw errors")
	detach_human_ai(marine)

/// A CLF unit with no screwdriver and wirecutters cannot get past a door it has no access to and leaves it alone, until it is given them
/datum/unit_test/human_ai_door_hacking_tools
	var/obj/structure/machinery/door/airlock/gate

/datum/unit_test/human_ai_door_hacking_tools/proc/hacked_open(datum/human_ai_brain/brain)
	return brain.hacks >= 1

/datum/unit_test/human_ai_door_hacking_tools/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/datum/human_ai_arena/block = new(list(
		"####################",
		"#..........#.......#",
		"#..........#.......#",
		"#..........A.......#",
		"#..........#.......#",
		"#..........#.......#",
		"####################",
	), run_loc_floor_bottom_left)
	gate = block.first_door("A")
	var/turf/door_turf = get_turf(gate)
	var/turf/inside = locate(block.origin_x + 3, block.origin_y + 3, block.z)
	var/turf/beyond = locate(block.origin_x + 15, block.origin_y + 3, block.z)

	var/mob/living/carbon/human/raider = make_soldier(inside, FACTION_CLF, FALSE)
	var/datum/human_ai_brain/hacker = raider.ai_brain
	TEST_ASSERT(!hacker.find_hack_tools(), "A bare raider with nowhere to carry anything has tools")
	var/datum/npc_order/move/go = new
	go.target_turf = beyond
	TEST_ASSERT(hacker.give_order(go), "A move command was refused")
	sleep(15 SECONDS)
	TEST_ASSERT_EQUAL(hacker.hacks, 0, "The raider hacked a door with no tools: [hacker.decision_log.Join(" | ")]")
	TEST_ASSERT(gate.density, "The door was opened without a hack")
	TEST_ASSERT(!gate.panel_open, "The raider opened an access panel with no screwdriver")
	TEST_ASSERT(gate.requiresID(), "The raider cut a wire with no wirecutters")
	TEST_ASSERT(hacker.is_blocked_turf(door_turf), "The door it cannot get through was not remembered: [hacker.decision_log.Join(" | ")]")

	// A lone screwdriver is no use either, it takes both
	var/obj/item/storage/backpack/lightpack/pack = new(raider)
	dress(raider, pack, WEAR_BACK)
	new /obj/item/tool/screwdriver(pack)
	TEST_ASSERT(!hacker.find_hack_tools(), "A screwdriver alone counted as a hacking kit")

	hacker.issue_hack_tools()
	TEST_ASSERT(hacker.find_hack_tools(), "The raider was not given the missing wirecutters, it wears [raider.back] and carries [english_list(raider.get_contents())]")
	var/screwdrivers = 0
	for(var/obj/item/tool/screwdriver/spare in raider.get_contents())
		screwdrivers++
	TEST_ASSERT_EQUAL(screwdrivers, 1, "The raider was given a second screwdriver on top of its own")
	hacker.blocked_turfs.Cut()
	var/datum/npc_order/move/again = new
	again.target_turf = beyond
	TEST_ASSERT(hacker.give_order(again), "The second move command was refused")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(hacked_open), hacker), 25), "The raider never hacked the door once it had the tools: [hacker.decision_log.Join(" | ")]")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(order_over), again), 30), "The raider never got through the door: [hacker.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(hacker.error_total, 0, "The raider's brain threw errors")
	detach_human_ai(raider)

/// Shutters have no handle: a powered one stays shut for everyone, a dead one stays shut without a crowbar and gives to one
/datum/unit_test/human_ai_shutters
	var/obj/structure/machinery/door/poddoor/shutters/shutter

/datum/unit_test/human_ai_shutters/proc/shutter_open()
	return !shutter.density

/datum/unit_test/human_ai_shutters/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/datum/human_ai_arena/block = new(list(
		"####################",
		"#..........#.......#",
		"#..........#.......#",
		"#..........D.......#",
		"#..........#.......#",
		"#..........#.......#",
		"####################",
	), run_loc_floor_bottom_left)
	var/obj/structure/machinery/door/airlock/frame = block.first_door("D")
	var/turf/door_turf = get_turf(frame)
	qdel(frame)
	shutter = allocate(/obj/structure/machinery/door/poddoor/shutters, door_turf)
	shutter.stat &= ~NOPOWER
	SSxeno_pathfinding.push_delta(door_turf)
	var/turf/inside = locate(block.origin_x + 3, block.origin_y + 3, block.z)
	var/turf/beyond = locate(block.origin_x + 15, block.origin_y + 3, block.z)

	// Powered and nothing to force it with, the unit gives up on it and does not open it by hand
	var/mob/living/carbon/human/marine = make_soldier(inside, FACTION_MARINE, FALSE)
	var/datum/human_ai_brain/brain = marine.ai_brain
	var/datum/npc_order/move/go = new
	go.target_turf = beyond
	TEST_ASSERT(brain.give_order(go), "A move command was refused")
	sleep(12 SECONDS)
	TEST_ASSERT(shutter.density, "A powered shutter was opened by hand: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(brain.pries, 0, "A powered shutter was forced")
	TEST_ASSERT(brain.is_blocked_turf(door_turf), "The shutter it cannot open was not remembered: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT(brain.blocked_turfs[door_turf] > world.time + HAI_DOOR_DENIED_MEMORY * 0.5, "The shutter it cannot open was only remembered for a moment")

	// Dead, but still no crowbar
	shutter.stat |= NOPOWER
	brain.blocked_turfs.Cut()
	var/datum/npc_order/move/second = new
	second.target_turf = beyond
	TEST_ASSERT(brain.give_order(second), "The second move command was refused")
	sleep(12 SECONDS)
	TEST_ASSERT(shutter.density, "A dead shutter was opened with no crowbar: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(brain.pries, 0, "A dead shutter was forced with nothing to force it with")

	TEST_ASSERT_EQUAL(brain.error_total, 0, "The brain threw errors")
	detach_human_ai(marine)

	// Dead and a crowbar in the pack, in a block of its own so what the first unit learned about the first shutter is not in the way
	var/datum/human_ai_arena/second_block = new(list(
		"####################",
		"#..........#.......#",
		"#..........#.......#",
		"#..........D.......#",
		"#..........#.......#",
		"#..........#.......#",
		"####################",
	), run_loc_floor_bottom_left, 20, 40)
	var/obj/structure/machinery/door/airlock/second_frame = second_block.first_door("D")
	var/turf/second_door_turf = get_turf(second_frame)
	qdel(second_frame)
	shutter = allocate(/obj/structure/machinery/door/poddoor/shutters, second_door_turf)
	shutter.stat |= NOPOWER
	SSxeno_pathfinding.push_delta(second_door_turf)
	var/mob/living/carbon/human/engineer = make_soldier(locate(second_block.origin_x + 3, second_block.origin_y + 3, second_block.z), FACTION_MARINE, FALSE)
	var/datum/human_ai_brain/forcer = engineer.ai_brain
	var/obj/item/storage/backpack/lightpack/pack = new(engineer)
	dress(engineer, pack, WEAR_BACK)
	var/obj/item/tool/crowbar/bar = new(pack)
	TEST_ASSERT(forcer.find_crowbar() == bar, "The unit does not see the crowbar in its pack, it carries [english_list(engineer.get_contents())]")
	var/datum/npc_order/move/third = new
	third.target_turf = locate(second_block.origin_x + 15, second_block.origin_y + 3, second_block.z)
	TEST_ASSERT(forcer.give_order(third), "The third move command was refused")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(shutter_open)), 25), "The dead shutter was not forced with a crowbar: [forcer.decision_log.Join(" | ")]")
	TEST_ASSERT(forcer.pries >= 1, "The shutter opened without the crowbar being used")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(order_over), third), 30), "The unit never got through the forced shutter: [forcer.decision_log.Join(" | ")]")
	TEST_ASSERT(!QDELETED(bar), "The crowbar is gone")
	TEST_ASSERT_EQUAL(forcer.error_total, 0, "The brain threw errors")
	detach_human_ai(engineer)

/// A body that dies with a brain takes the AI back when it is revived, with the same nature and role, unless a player has it
/datum/unit_test/human_ai_revival

/datum/unit_test/human_ai_revival/proc/has_brain(mob/living/carbon/human/human)
	return !!human.ai_brain

/datum/unit_test/human_ai_revival/Run()
	var/mob/living/carbon/human/soldier = make_soldier(run_loc_floor_bottom_left, FACTION_MARINE, FALSE, "veteran")
	var/datum/human_ai_brain/before = soldier.ai_brain
	before.set_role("medic")
	before.roe = HAI_ROE_WEAPONS_HOLD
	before.keep_awake = TRUE
	soldier.death(create_cause_data("unit test"))
	TEST_ASSERT_NULL(soldier.ai_brain, "A dead body kept its brain")
	TEST_ASSERT_NOTNULL(soldier.human_ai_memory, "A body that died with a brain remembers nothing")

	soldier.rejuvenate()
	TEST_ASSERT_NULL(soldier.ai_brain, "The brain came back before the grace period was over")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(has_brain), soldier), 12), "A healed body never took its brain back")
	var/datum/human_ai_brain/after = soldier.ai_brain
	TEST_ASSERT_EQUAL(after.personality.id, "veteran", "The revived brain has the nature [after.personality.id]")
	TEST_ASSERT_EQUAL(after.role.id, "medic", "The revived brain has the role [after.role.id]")
	TEST_ASSERT_EQUAL(after.roe, HAI_ROE_WEAPONS_HOLD, "The revived brain lost its rules of engagement")
	TEST_ASSERT(after.keep_awake, "The revived brain lost what it was told about staying awake")
	TEST_ASSERT_NULL(soldier.human_ai_memory, "The memory was kept after it was used")
	TEST_ASSERT(soldier in GLOB.ai_human_list, "The revived body is not in the list of AI humans")

	// The defibrillator signals before the heart is going, so the brain is only put back once the body has really come round
	soldier.death(create_cause_data("unit test"))
	TEST_ASSERT_NULL(soldier.ai_brain, "A dead body kept its brain the second time")
	soldier.handle_revive()
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(has_brain), soldier), 12), "A defibrillated body never took its brain back")
	TEST_ASSERT_EQUAL(soldier.ai_brain.personality.id, "veteran", "The defibrillated brain has the wrong nature")
	TEST_ASSERT_EQUAL(soldier.ai_brain.error_total, 0, "The revived brain threw errors")

	// A body that never had a brain does not get one by being revived
	var/mob/living/carbon/human/stranger = allocate(/mob/living/carbon/human, locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z))
	stranger.death(create_cause_data("unit test"))
	stranger.rejuvenate()
	sleep(HAI_REVIVE_GRACE + 2 SECONDS)
	TEST_ASSERT_NULL(stranger.ai_brain, "A body that never had a brain got one by being healed")
	detach_human_ai(soldier)


/// A wall of tables with no gap still gets crossed by a brain with a goal beyond it, and a wall with a gap is gone through and not climbed
/datum/unit_test/human_ai_table_wall

/// Sends the soldier to the goal with a move order and waits for it to end
/datum/unit_test/human_ai_table_wall/proc/cross(mob/living/carbon/human/soldier, turf/goal)
	var/datum/human_ai_brain/brain = soldier.ai_brain
	var/datum/npc_order/move/go = new
	go.target_turf = goal
	TEST_ASSERT(brain.give_order(go), "A move command was refused")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(order_over), go), 60), "The move order across the tables never ended, the soldier is at [soldier.x],[soldier.y], vaults [brain.vaults], detours [brain.climb_detours]: [brain.decision_log.Join(" | ")]")
	return go

/datum/unit_test/human_ai_table_wall/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/datum/human_ai_arena/solid = new(list(
		"####################",
		"#.........T........#",
		"#.........T........#",
		"#.........T........#",
		"####################",
	), run_loc_floor_bottom_left)
	var/turf/start = locate(solid.origin_x + 3, solid.origin_y + 2, solid.z)
	var/turf/goal = locate(solid.origin_x + 16, solid.origin_y + 2, solid.z)
	var/mob/living/carbon/human/soldier = make_soldier(start, FACTION_MARINE, FALSE)
	var/datum/npc_order/move/crossing = cross(soldier, goal)
	TEST_ASSERT_EQUAL(crossing.status, HAI_ORDER_DONE, "The order across a solid wall of tables ended as [crossing.status] and not done: [soldier.ai_brain.decision_log.Join(" | ")]")
	TEST_ASSERT(soldier.ai_brain.vaults >= 1, "The soldier got across a solid wall of tables without climbing")
	TEST_ASSERT(get_dist(soldier, goal) <= 2, "The soldier stopped [get_dist(soldier, goal)] tiles short of the goal")
	TEST_ASSERT_EQUAL(soldier.ai_brain.error_total, 0, "The brain threw errors")
	detach_human_ai(soldier)

	var/datum/human_ai_arena/gapped = new(list(
		"####################",
		"#.........T........#",
		"#.........T........#",
		"#..................#",
		"#.........T........#",
		"####################",
	), run_loc_floor_bottom_left)
	var/turf/gap_start = locate(gapped.origin_x + 3, gapped.origin_y + 3, gapped.z)
	var/turf/gap_goal = locate(gapped.origin_x + 16, gapped.origin_y + 3, gapped.z)
	var/mob/living/carbon/human/walker = make_soldier(gap_start, FACTION_MARINE, FALSE)
	var/datum/npc_order/move/through = cross(walker, gap_goal)
	TEST_ASSERT_EQUAL(through.status, HAI_ORDER_DONE, "The order through a wall of tables with a gap ended as [through.status] and not done: [walker.ai_brain.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(walker.ai_brain.vaults, 0, "The soldier climbed a table with a gap right beside it: [walker.ai_brain.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(walker.ai_brain.error_total, 0, "The brain threw errors")
	detach_human_ai(walker)
