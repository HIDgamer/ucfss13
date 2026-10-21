/// A unit sees no farther in the dark than its eyes reach, and makes out something hiding under a cloak or camouflage only from close by
/datum/unit_test/human_ai_vision
	var/mob/living/carbon/human/watcher
	var/mob/living/carbon/xenomorph/drone/subject

/datum/unit_test/human_ai_vision/proc/spotted()
	return !!watcher.ai_brain.get_contact(subject)?.identified()

/datum/unit_test/human_ai_vision/proc/arena()
	var/list/rows = list()
	var/wall = ""
	var/floor = "#"
	for(var/column in 1 to 30)
		wall += "#"
		if(column > 2)
			floor += "."
	floor += "#"
	rows += wall
	for(var/row in 1 to 3)
		rows += floor
	rows += wall
	return new /datum/human_ai_arena(rows, run_loc_floor_bottom_left)

/// A watcher facing the subject at the distance, that only looks and does nothing else
/datum/unit_test/human_ai_vision/proc/set_up(datum/human_ai_arena/field, distance)
	watcher = make_soldier(locate(field.origin_x + 3, field.origin_y + 2, field.z), FACTION_MARINE, FALSE)
	watcher.setDir(EAST)
	var/list/pool = list()
	for(var/datum/human_ai_action/action as anything in GLOB.human_ai_actions)
		if(action.id == "scan")
			pool += action
	watcher.ai_brain.action_pool = pool
	subject = make_target_dummy(locate(field.origin_x + 3 + distance, field.origin_y + 2, field.z))
	SSspatial_grid.track(subject, SPATIAL_GRID_TRACK_NPC)

/datum/unit_test/human_ai_vision/proc/tear_down()
	detach_human_ai(watcher)
	qdel(watcher)
	qdel(subject)

/datum/unit_test/human_ai_vision/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/datum/human_ai_arena/field = arena()

	// In plain light a unit makes out what is 7 tiles ahead
	set_up(field, 7)
	var/datum/human_ai_brain/brain = watcher.ai_brain
	var/turf/far = get_turf(subject)
	TEST_ASSERT(brain.clarity_of(subject, far, 7) > 0.9, "Something in plain light was not made out clearly")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(spotted)), 14), "A unit never made out a xeno in plain light 7 tiles ahead")
	tear_down()

	// In the dark beyond its night vision it never does, and from within it, it does
	set_up(field, 7)
	brain = watcher.ai_brain
	brain.light_override = 0
	far = get_turf(subject)
	TEST_ASSERT(watcher.see_in_dark >= 1 && watcher.see_in_dark < 7, "The test body sees [watcher.see_in_dark] tiles in the dark, the scenario proves nothing")
	TEST_ASSERT_EQUAL(brain.clarity_of(subject, far, 7), 0, "Something in the dark past night vision was made out")
	sleep(12 SECONDS)
	TEST_ASSERT_NULL(brain.get_contact(subject), "A unit made out a xeno standing in the dark 7 tiles away")
	subject.forceMove(locate(watcher.x + watcher.see_in_dark, watcher.y, watcher.z))
	TEST_ASSERT(brain.clarity_of(subject, get_turf(subject), watcher.see_in_dark) > 0, "Something in the dark within night vision was not made out")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(spotted)), 12), "A unit never made out a xeno standing in the dark [watcher.see_in_dark] tiles away")
	TEST_ASSERT_EQUAL(brain.clarity_of(subject, get_turf(subject), watcher.see_in_dark + 1), 0, "Something in the dark one tile past night vision was made out")
	tear_down()

	// A dim place only takes longer
	set_up(field, 7)
	brain = watcher.ai_brain
	brain.light_override = (HAI_DARK_LIGHT + HAI_LIT_LIGHT) / 2
	far = get_turf(subject)
	var/clear_dim = brain.clarity_of(subject, far, 7)
	TEST_ASSERT(clear_dim > 0 && clear_dim < 1, "A dim place did not make something harder to make out: [clear_dim]")
	TEST_ASSERT(brain.notice_seconds(subject, get_turf(watcher), far, FALSE) > 2 * 1.4, "A dim place made no difference to how long it takes to notice")
	tear_down()

	// A cloaked body is made out from 2 tiles and not from 6, in full light
	set_up(field, 6)
	brain = watcher.ai_brain
	ADD_TRAIT(subject, TRAIT_CLOAKED, TRAIT_SOURCE_EQUIPMENT(WEAR_BACK))
	far = get_turf(subject)
	TEST_ASSERT(brain.is_concealed(subject), "A cloaked body was not taken for concealed")
	TEST_ASSERT_EQUAL(brain.clarity_of(subject, far, 6), 0, "A cloaked body was made out from 6 tiles")
	sleep(12 SECONDS)
	TEST_ASSERT_NULL(brain.get_contact(subject), "A unit made out a cloaked xeno 6 tiles away")
	subject.forceMove(locate(watcher.x + 2, watcher.y, watcher.z))
	TEST_ASSERT(brain.clarity_of(subject, get_turf(subject), 2) > 0, "A cloaked body was not made out from 2 tiles")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(spotted)), 14), "A unit never made out a cloaked xeno 2 tiles away")
	tear_down()

	// Camouflage that leaves almost nothing of the body does the same
	set_up(field, 6)
	brain = watcher.ai_brain
	subject.alpha = HAI_CONCEAL_ALPHA
	TEST_ASSERT(brain.is_concealed(subject), "A body camouflaged to nothing was not taken for concealed")
	TEST_ASSERT_EQUAL(brain.clarity_of(subject, get_turf(subject), 6), 0, "A camouflaged body was made out from 6 tiles")
	subject.alpha = 255
	TEST_ASSERT(!brain.is_concealed(subject), "A plain body was taken for concealed")
	tear_down()

	// Nothing hides from an arm's length, and shot at from where it cannot see, a unit goes to look and does not know who fired
	set_up(field, 1)
	brain = watcher.ai_brain
	ADD_TRAIT(subject, TRAIT_CLOAKED, TRAIT_SOURCE_EQUIPMENT(WEAR_BACK))
	brain.light_override = 0
	TEST_ASSERT(brain.clarity_of(subject, get_turf(subject), 1) == 1, "Something beside the unit was not made out")
	tear_down()

	set_up(field, 9)
	brain = watcher.ai_brain
	ADD_TRAIT(subject, TRAIT_CLOAKED, TRAIT_SOURCE_EQUIPMENT(WEAR_BACK))
	brain.on_shot_at(subject)
	TEST_ASSERT_NULL(brain.get_contact(subject), "A unit knew who shot it from a cloak nine tiles away")
	TEST_ASSERT_NOTNULL(brain.investigate_turf, "A unit shot at from where it cannot see did not go to look")
	TEST_ASSERT(get_dist(brain.investigate_turf, get_turf(subject)) <= 4, "It went to look [get_dist(brain.investigate_turf, get_turf(subject))] tiles from where the shot came from")
	TEST_ASSERT(brain.suppressed(), "A shot did not put the unit under fire")
	REMOVE_TRAIT(subject, TRAIT_CLOAKED, TRAIT_SOURCE_EQUIPMENT(WEAR_BACK))
	brain.end_investigation()
	brain.on_shot_at(subject)
	TEST_ASSERT_NOTNULL(brain.get_contact(subject), "A unit did not know who shot it from plain sight")
	TEST_ASSERT_EQUAL(brain.error_total, 0, "The unit's brain threw errors")
	tear_down()

/// A grenade is not pulled and thrown in the time it takes to fire a round: nothing is shot while it is drawn and the hands recover, and a throw that stopped being safe is not made
/datum/unit_test/human_ai_grenade_timing
	var/datum/human_ai_brain/thrower_brain

/datum/unit_test/human_ai_grenade_timing/proc/thrown()
	return thrower_brain.grenades_thrown > 0

/datum/unit_test/human_ai_grenade_timing/Run()
	var/datum/human_ai_arena/yard = new(list(
		"####################",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"####################",
	), run_loc_floor_bottom_left)
	var/turf/start = locate(yard.origin_x + 2, yard.origin_y + 3, yard.z)
	var/mob/living/carbon/human/thrower = make_soldier(start, FACTION_MARINE, TRUE)
	thrower_brain = thrower.ai_brain
	var/obj/item/storage/backpack/pack = new(thrower)
	dress(thrower, pack, WEAR_BACK)
	var/obj/item/explosive/grenade/smokebomb/smoke = new(pack)
	var/mob/living/carbon/xenomorph/drone/dummy = make_target_dummy(locate(start.x + 8, start.y, start.z))
	// Nothing but the throw itself is done by the brain, so that the moment can be looked at
	var/list/pool = list()
	for(var/datum/human_ai_action/action as anything in GLOB.human_ai_actions)
		if(action.id == "scan")
			pool += action
	thrower_brain.action_pool = pool
	var/obj/item/weapon/gun/gun = thrower_brain.peek_gun()
	TEST_ASSERT_NOTNULL(gun, "The thrower has no gun")
	thrower_brain.grenade_cache_time = 0
	TEST_ASSERT(thrower_brain.throw_grenade(smoke, dummy), "The grenade throw would not start")
	TEST_ASSERT(thrower_brain.hands_busy_until > world.time, "The hands were not busy with the grenade")
	TEST_ASSERT(!(gun.flags_item & WIELDED), "The gun was still at the shoulder while the grenade was drawn")
	var/shots = thrower_brain.shots_fired
	TEST_ASSERT(!thrower_brain.shoot(gun, dummy), "The unit fired a round while it was drawing a grenade")
	TEST_ASSERT_EQUAL(thrower_brain.shots_fired, shots, "A shot went out while the grenade was being drawn")
	TEST_ASSERT(!(gun.flags_item & WIELDED), "The gun came back up while the grenade was being drawn")
	TEST_ASSERT_EQUAL(thrower_brain.grenades_thrown, 0, "The grenade was thrown at the same instant it was drawn")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(thrown)), 5), "The grenade was never thrown: [thrower_brain.decision_log.Join(" | ")]")
	// The hands are still busy getting the gun back up, and nothing is shot until they are free
	TEST_ASSERT(thrower_brain.hands_busy_until > world.time, "The hands were free the moment the grenade left them")
	TEST_ASSERT(!thrower_brain.shoot(gun, dummy), "The unit fired while its hands were still busy after the throw")
	TEST_ASSERT_EQUAL(thrower_brain.shots_fired, shots, "A shot went out while the hands were busy")
	sleep(2 SECONDS)
	TEST_ASSERT(thrower_brain.hands_busy_until <= world.time, "The hands never became free again")
	TEST_ASSERT_EQUAL(thrower_brain.error_total, 0, "The thrower's brain threw errors")
	detach_human_ai(thrower)

/// A body that has no job of its own, as an NPC made from an equipment preset does, goes through a hypersleep chamber instead of failing in it on every tick
/datum/unit_test/human_ai_cryo_jobless

/datum/unit_test/human_ai_cryo_jobless/Run()
	var/obj/structure/machinery/cryopod/pod = allocate(/obj/structure/machinery/cryopod, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	body.job = "Intelligence Analyst"
	TEST_ASSERT_NULL(GET_MAPPED_ROLE(body.job), "The test job is a real one, the scenario proves nothing")
	body.forceMove(pod)
	pod.occupant = body
	pod.despawn_occupant()
	TEST_ASSERT(QDELETED(body), "A body with no job was never taken in by the hypersleep chamber")
	TEST_ASSERT_NULL(pod.occupant, "The chamber still holds an occupant that was despawned")

/// A unit that loses its gun in the middle of a fight goes and gets it, or another loaded one, and does not punch its way through
/datum/unit_test/human_ai_recover_weapon
	var/mob/living/carbon/human/soldier
	var/datum/human_ai_brain/brain

/datum/unit_test/human_ai_recover_weapon/proc/armed()
	return !!brain.peek_gun()

/datum/unit_test/human_ai_recover_weapon/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/datum/human_ai_arena/field = new(list(
		"##############################",
		"#............................#",
		"#............................#",
		"#............................#",
		"##############################",
	), run_loc_floor_bottom_left)
	soldier = make_soldier(locate(field.origin_x + 12, field.origin_y + 2, field.z), FACTION_MARINE, TRUE)
	brain = soldier.ai_brain
	var/obj/item/weapon/gun/own = brain.peek_gun()
	TEST_ASSERT_NOTNULL(own, "The soldier has no gun to lose")
	var/mob/living/carbon/xenomorph/drone/enemy = make_target_dummy(locate(field.origin_x + 24, field.origin_y + 2, field.z))
	SSspatial_grid.track(enemy, SPATIAL_GRID_TRACK_NPC)
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(armed)), 3), "The soldier was never armed")
	sleep(3 SECONDS)

	// A wound knocks the gun out of its hand in the middle of the fight, and it ends up a few tiles away
	soldier.drop_inv_item_on_ground(own)
	own.forceMove(locate(field.origin_x + 7, field.origin_y + 3, field.z))
	brain.remember_gun()
	TEST_ASSERT(!brain.peek_gun(), "The gun is still in a hand")
	TEST_ASSERT(brain.find_weapon_to_recover() == own, "The unit did not see the gun it dropped")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(armed)), 12), "The soldier never took its gun up again: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT(brain.recovered_weapons >= 1, "The recovery was not counted")
	TEST_ASSERT(brain.peek_gun() == own, "The soldier took up something other than its own gun")

	// Another loaded gun lying close by will do when its own is nowhere
	soldier.drop_inv_item_on_ground(own)
	qdel(own)
	var/obj/item/weapon/gun/rifle/m41a/spare = new(locate(soldier.x - 3, soldier.y, soldier.z))
	TEST_ASSERT(brain.find_weapon_to_recover() == spare || ai_wait(CALLBACK(src, PROC_REF(armed)), 12), "The unit paid no attention to a loaded gun lying beside it")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(armed)), 12), "The soldier never took up another gun: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(brain.error_total, 0, "The soldier's brain threw errors")
	detach_human_ai(soldier)

	// An empty gun with nothing to load it is not worth the trip
	var/mob/living/carbon/human/bare = make_soldier(locate(field.origin_x + 4, field.origin_y + 2, field.z), FACTION_MARINE, FALSE)
	var/obj/item/weapon/gun/rifle/m41a/dry = new(locate(bare.x + 3, bare.y, bare.z), TRUE)
	TEST_ASSERT_NULL(bare.ai_brain.find_weapon_to_recover(), "A gun with no rounds and nothing to load it was worth going for")
	qdel(dry)
	detach_human_ai(bare)

/// Nothing is fired into a wall, and a clear line is fired along
/datum/unit_test/human_ai_wall_line

/datum/unit_test/human_ai_wall_line/Run()
	var/datum/human_ai_arena/field = new(list(
		"####################",
		"#.....#............#",
		"#.....#............#",
		"#.....D............#",
		"#.....#............#",
		"#.....#............#",
		"####################",
	), run_loc_floor_bottom_left)
	var/turf/start = locate(field.origin_x + 2, field.origin_y + 3, field.z)
	var/mob/living/carbon/human/shooter = make_soldier(start, FACTION_MARINE, TRUE)
	var/datum/human_ai_brain/brain = shooter.ai_brain
	brain.roe = HAI_ROE_WEAPONS_HOLD
	// It only looks, so that it stays where the test put it
	var/list/pool = list()
	for(var/datum/human_ai_action/action as anything in GLOB.human_ai_actions)
		if(action.id == "scan")
			pool += action
	brain.action_pool = pool
	var/obj/item/weapon/gun/gun = brain.peek_gun()
	if(brain.weapon_state(gun) == HAI_WEAPON_SAFE)
		brain.release_safety(gun)
	var/mob/living/carbon/xenomorph/drone/dummy = make_target_dummy(locate(start.x + 8, start.y, start.z))
	sleep(1 SECONDS)
	var/obj/structure/machinery/door/airlock/door = field.first_door("D")
	TEST_ASSERT(door.density, "The door is open")
	TEST_ASSERT(brain.wall_in_line(dummy), "A shut door between the unit and the target was not taken for a wall")
	var/shots = brain.shots_fired
	TEST_ASSERT(!brain.shoot(gun, dummy), "The unit fired at a target behind a shut door")
	TEST_ASSERT_EQUAL(brain.shots_fired, shots, "A shot went out into a shut door")
	TEST_ASSERT(brain.wall_holds >= 1, "The held shot was not counted")
	var/datum/human_ai_action/fire_gun/trigger = new
	brain.roe = HAI_ROE_WEAPONS_FREE
	TEST_ASSERT_EQUAL(trigger.get_weight(brain), 0, "The firing action wanted to shoot into a shut door")
	qdel(trigger)

	// Beside the wall the line is clear
	var/mob/living/carbon/xenomorph/drone/near_dummy = make_target_dummy(locate(start.x + 3, start.y, start.z))
	TEST_ASSERT(!brain.wall_in_line(near_dummy), "A clear line was taken for a wall")
	// With the door open there is nothing in the way
	door.open(TRUE)
	sleep(3 SECONDS)
	TEST_ASSERT(!door.density, "The door did not open")
	TEST_ASSERT(!brain.wall_in_line(dummy), "An open door was taken for a wall")
	qdel(near_dummy)
	detach_human_ai(shooter)
