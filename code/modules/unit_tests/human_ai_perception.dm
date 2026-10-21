/// Sight cones, target choice, searching for a lost target, sound lures, being shot at and the grid cull
/datum/unit_test/human_ai_perception

/datum/unit_test/human_ai_perception/proc/make_dummy(turf/where, type = /mob/living/carbon/xenomorph/drone)
	var/mob/living/carbon/xenomorph/dummy = allocate(type, where)
	SSspatial_grid.track(dummy, SPATIAL_GRID_TRACK_NPC)
	return dummy

/datum/unit_test/human_ai_perception/proc/make_watcher(turf/where, facing = EAST, list/action_ids)
	var/mob/living/carbon/human/watcher = allocate(/mob/living/carbon/human, where)
	watcher.faction = FACTION_MARINE
	watcher.setDir(facing)
	attach_human_ai(watcher)
	watcher.ai_brain.keep_awake = TRUE
	if(action_ids)
		var/list/pool = list()
		for(var/datum/human_ai_action/action as anything in GLOB.human_ai_actions)
			if(action.id in action_ids)
				pool += action
		watcher.ai_brain.action_pool = pool
	return watcher

/datum/unit_test/human_ai_perception/proc/wait_until(datum/callback/check, seconds)
	for(var/waited in 1 to seconds * 4)
		if(check.Invoke())
			return TRUE
		sleep(2.5)
	return check.Invoke()

/datum/unit_test/human_ai_perception/proc/identified(mob/living/carbon/human/watcher, mob/living/subject)
	return watcher.ai_brain?.get_contact(subject)?.identified()

/datum/unit_test/human_ai_perception/proc/has_target(mob/living/carbon/human/watcher, mob/living/subject)
	return watcher.ai_brain?.get_target() == subject

/datum/unit_test/human_ai_perception/proc/has_intent(mob/living/carbon/human/watcher, intent)
	return watcher.ai_brain?.intent == intent

/datum/unit_test/human_ai_perception/proc/idle_without_target(mob/living/carbon/human/watcher)
	return !watcher.ai_brain.get_target() && !watcher.ai_brain.investigate_turf && watcher.ai_brain.intent != HAI_INTENT_INVESTIGATE

/datum/unit_test/human_ai_perception/proc/hurt(mob/living/carbon/xenomorph/dummy)
	return dummy.health < dummy.maxHealth

/datum/unit_test/human_ai_perception/Run()
	var/list/hall_rows = list(
		"##########################",
		"#........................#",
		"#........................#",
		"#........................#",
		"##########################",
	)

	var/datum/human_ai_arena/hall = new(hall_rows, run_loc_floor_bottom_left)
	var/turf/centre = locate(hall.origin_x + 12, hall.origin_y + 2, hall.z)
	var/mob/living/carbon/human/watcher = make_watcher(centre)
	var/mob/living/carbon/xenomorph/ahead = make_dummy(locate(centre.x + 6, centre.y, centre.z))
	var/mob/living/carbon/xenomorph/behind = make_dummy(locate(centre.x - 6, centre.y, centre.z))
	var/front_seconds = watcher.ai_brain.notice_seconds(ahead, centre, get_turf(ahead), FALSE)
	var/back_seconds = watcher.ai_brain.notice_seconds(behind, centre, get_turf(behind), FALSE)
	TEST_ASSERT(back_seconds >= front_seconds * 4, "Something behind took [back_seconds] s to notice against [front_seconds] s in front")
	detach_human_ai(watcher)
	qdel(behind)

	watcher = make_watcher(centre, EAST, list("scan"))
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(identified), watcher, ahead), 8), "A watcher never made out a xeno standing 6 tiles ahead of it")
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(has_target), watcher, ahead), 3), "The watcher made out the xeno but did not target it")
	TEST_ASSERT(watcher.ai_brain.intent == HAI_INTENT_ENGAGE, "The watcher did not engage what it targeted")
	detach_human_ai(watcher)
	qdel(ahead)

	var/mob/living/carbon/xenomorph/sneaker = make_dummy(locate(centre.x - 6, centre.y, centre.z))
	watcher = make_watcher(centre, EAST, list("scan"))
	sleep(4 SECONDS)
	TEST_ASSERT(!identified(watcher, sneaker), "A watcher made out a xeno standing still behind it within 4 s")
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(identified), watcher, sneaker), 20), "A watcher never turned and made out the xeno behind it")
	detach_human_ai(watcher)
	qdel(sneaker)

	var/mob/living/carbon/xenomorph/larva/small = make_dummy(locate(centre.x + 3, centre.y, centre.z), /mob/living/carbon/xenomorph/larva)
	var/mob/living/carbon/xenomorph/big = make_dummy(locate(centre.x + 3, centre.y + 1, centre.z))
	watcher = make_watcher(centre, EAST, list("scan"))
	watcher.ai_brain.identify_now(small)
	watcher.ai_brain.identify_now(big)
	watcher.ai_brain.select_target()
	TEST_ASSERT(watcher.ai_brain.get_target() == big, "The watcher picked [watcher.ai_brain.get_target()] over the bigger threat")
	detach_human_ai(watcher)
	qdel(small)
	qdel(big)

	var/mob/living/carbon/xenomorph/vanisher = make_dummy(locate(centre.x + 5, centre.y, centre.z))
	var/turf/last_seen = get_turf(vanisher)
	watcher = make_watcher(centre, EAST, list("scan", "investigate"))
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(has_target), watcher, vanisher), 10), "The watcher never targeted the xeno it was meant to lose")
	vanisher.forceMove(locate(hall.origin_x + 1, hall.origin_y + 1, hall.z))
	var/datum/human_ai_brain/seeker = watcher.ai_brain
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(has_intent), watcher, HAI_INTENT_INVESTIGATE), 8), "The watcher did not go looking after it lost the xeno, intent [seeker.intent]")
	var/closest = INFINITY
	for(var/waited in 1 to 80)
		closest = min(closest, get_dist(watcher, last_seen))
		sleep(2.5)
		if(seeker.intent != HAI_INTENT_INVESTIGATE)
			break
	TEST_ASSERT(closest <= 2, "The watcher never went to where it last saw the xeno, got within [closest]")
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(idle_without_target), watcher), 30), "The watcher never gave up the search, intent [seeker.intent]")
	TEST_ASSERT(!length(seeker.contacts), "The watcher still remembers the xeno it gave up on")
	detach_human_ai(watcher)
	qdel(vanisher)

	// A heard shot is guessed at to within a couple of tiles, so the rooms are tall enough for every guess to land inside them
	var/datum/human_ai_arena/rooms = new(list(
		"##############",
		"#......#.....#",
		"#......#.....#",
		"#1.....D....2#",
		"#......#.....#",
		"#......#.....#",
		"##############",
	), run_loc_floor_bottom_left)
	var/mob/living/carbon/xenomorph/hidden = make_dummy(rooms.mark("2"))
	watcher = make_watcher(rooms.mark("1"))
	var/obj/item/weapon/gun/rifle/m41a/lure_rifle = allocate(/obj/item/weapon/gun/rifle/m41a, watcher)
	watcher.put_in_hands(lure_rifle)
	sleep(3 SECONDS)
	TEST_ASSERT(!watcher.ai_brain.get_target(), "The watcher saw through a closed door")
	playsound(locate(rooms.mark("2").x - 1, rooms.mark("2").y, rooms.mark("2").z), 'sound/weapons/Gunshot.ogg', 100, FALSE)
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(has_intent), watcher, HAI_INTENT_INVESTIGATE), 3), "A gunshot did not send the watcher to look, intent [watcher.ai_brain.intent]")
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(hurt), hidden), 40), "The watcher never found and fought what the gunshot came from, it is at [watcher.x],[watcher.y] with intent [watcher.ai_brain.intent]: [watcher.ai_brain.decision_log.Join(" | ")]")
	detach_human_ai(watcher)

	hall = new(hall_rows, run_loc_floor_bottom_left)
	centre = locate(hall.origin_x + 12, hall.origin_y + 2, hall.z)
	watcher = make_watcher(centre, NORTH, list("scan"))
	var/mob/living/carbon/human/raider = allocate(/mob/living/carbon/human, locate(centre.x - 8, centre.y, centre.z))
	raider.faction = "raiders"
	var/obj/item/weapon/gun/rifle/m41a/raid_rifle = allocate(/obj/item/weapon/gun/rifle/m41a, raider)
	raider.put_in_hands(raid_rifle)
	raid_rifle.set_gun_user(raider)
	raid_rifle.Fire(locate(centre.x, centre.y + 1, centre.z), raider)
	sleep(1 SECONDS)
	raid_rifle.Fire(locate(centre.x, centre.y + 1, centre.z), raider)
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(identified), watcher, raider), 3), "Shots past a watcher did not tell it who was shooting")
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(has_target), watcher, raider), 3), "The watcher did not turn on the shooter")
	detach_human_ai(watcher)
	qdel(raider)

	watcher = make_watcher(centre, EAST, list("scan"))
	var/datum/human_ai_brain/idle_brain = watcher.ai_brain
	sleep(6 SECONDS)
	TEST_ASSERT(idle_brain.scan_count >= 4, "The idle watcher scanned only [idle_brain.scan_count] times")
	TEST_ASSERT(idle_brain.view_scans <= 2, "The idle watcher looked [idle_brain.view_scans] times with nobody around, the cull is not working")
	var/views_before = idle_brain.view_scans
	var/mob/living/carbon/xenomorph/arrival = make_dummy(locate(centre.x + 10, centre.y, centre.z))
	var/scans_before = idle_brain.scan_count
	sleep(5 SECONDS)
	TEST_ASSERT(idle_brain.view_scans - views_before >= (idle_brain.scan_count - scans_before) - 1, "A watcher with an enemy nearby skipped scans")
	detach_human_ai(watcher)
	qdel(arrival)
