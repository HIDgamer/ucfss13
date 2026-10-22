/// A brain that only looks around, so that nothing else it could do gets in the way of what a test is asking of it
/datum/unit_test/proc/lookout_pool(datum/human_ai_brain/brain, extra_id)
	var/list/pool = list()
	for(var/datum/human_ai_action/action as anything in GLOB.human_ai_actions)
		if(action.id == "scan" || (extra_id && action.id == extra_id))
			pool += action
	brain.action_pool = pool

/// What is worn over the eyes and the state of them decide how far a unit sees
/datum/unit_test/human_ai_eyes

/datum/unit_test/human_ai_eyes/Run()
	var/datum/human_ai_arena/field = new(list("############", "#..........#", "############"), run_loc_floor_bottom_left)
	var/mob/living/carbon/human/seer = make_soldier(locate(field.origin_x + 1, field.origin_y + 1, field.z), FACTION_MARINE, FALSE)
	var/datum/human_ai_brain/brain = seer.ai_brain
	lookout_pool(brain)
	brain.light_override = 1
	var/mob/living/carbon/xenomorph/drone/subject = make_target_dummy(locate(field.origin_x + 8, field.origin_y + 1, field.z))
	var/turf/far = get_turf(subject)
	TEST_ASSERT(brain.clarity_of(subject, far, 7) > 0.9, "A bare-eyed unit did not make out something in plain light 7 tiles off")

	// A welding mask pulled down leaves it seeing what is next to it and little more
	var/obj/item/clothing/head/welding/mask = new(seer)
	dress(seer, mask, WEAR_HEAD)
	TEST_ASSERT_EQUAL(seer.head, mask, "The welding mask did not go on")
	TEST_ASSERT(!mask.up, "The welding mask came flipped up")
	brain.eye_reach_time = -1
	TEST_ASSERT_EQUAL(brain.eye_tint(), VISION_IMPAIR_ULTRA, "The mask did not tint the sight")
	TEST_ASSERT_EQUAL(brain.eye_reach(), 1, "A unit under a welding mask sees [brain.eye_reach()] tiles")
	TEST_ASSERT_EQUAL(brain.clarity_of(subject, far, 7), 0, "Something 7 tiles off was made out through a welding mask")
	TEST_ASSERT_EQUAL(brain.clarity_of(subject, far, 2), 0, "Something 2 tiles off was made out through a welding mask")
	TEST_ASSERT_EQUAL(brain.clarity_of(subject, far, 1), 1, "Something at arm's length was not made out through a welding mask")
	TEST_ASSERT(brain.set_weld_gear(mask, FALSE), "The mask would not go up")
	TEST_ASSERT(mask.up, "The mask is still down")
	TEST_ASSERT_EQUAL(brain.eye_reach(), INFINITY, "A unit with the mask up still has its sight held in")
	TEST_ASSERT(brain.clarity_of(subject, far, 7) > 0.9, "A unit with the mask up did not make out something in plain light")

	// Blind eyes feel only what is beside them, blurred ones see a few tiles
	seer.eye_blind = 50
	brain.eye_reach_time = -1
	TEST_ASSERT_EQUAL(brain.clarity_of(subject, far, 7), 0, "A blind unit made out something 7 tiles off")
	TEST_ASSERT_EQUAL(brain.clarity_of(subject, far, 1), 1, "A blind unit did not feel what is beside it")
	seer.eye_blind = 0
	seer.eye_blurry = 50
	brain.eye_reach_time = -1
	TEST_ASSERT_EQUAL(brain.clarity_of(subject, far, 7), 0, "A unit with blurred eyes made out something 7 tiles off")
	TEST_ASSERT(brain.clarity_of(subject, far, HAI_BLURRY_REACH) > 0.9, "A unit with blurred eyes did not make out something close")
	seer.eye_blurry = 0
	brain.eye_reach_time = -1

	// Welding goggles of the better kind only take some of it away
	var/obj/item/clothing/head/welding/old_mask = seer.head
	seer.temp_drop_inv_item(old_mask)
	seer.head = null
	qdel(old_mask)
	var/obj/item/clothing/glasses/welding/superior/goggles = new(seer)
	dress(seer, goggles, WEAR_EYES)
	TEST_ASSERT_EQUAL(seer.glasses, goggles, "The goggles did not go on")
	brain.eye_reach_time = -1
	TEST_ASSERT_EQUAL(brain.eye_tint(), VISION_IMPAIR_WEAK, "The goggles tint [brain.eye_tint()]")
	TEST_ASSERT(brain.eye_reach() > 1 && brain.eye_reach() < HAI_SIGHT_RANGE, "The goggles left a reach of [brain.eye_reach()]")
	TEST_ASSERT_EQUAL(brain.clarity_of(subject, far, 8), 0, "Something past the reach of the goggles was made out")
	TEST_ASSERT(brain.clarity_of(subject, far, 4) > 0.9, "Something within the reach of the goggles was not made out")
	TEST_ASSERT_EQUAL(brain.error_total, 0, "The brain threw errors")
	detach_human_ai(seer)

/// How a man moves and lies, which way the watcher looks and how alarmed it is decide how long he takes to give himself away
/datum/unit_test/human_ai_stealth_pace
	var/saved_detection = 1

/datum/unit_test/human_ai_stealth_pace/Destroy()
	SShuman_ai.detection_mult = saved_detection
	return ..()

/// Looks round again and again with half a second passing each time, and says how many looks it took to make the intruder out
/datum/unit_test/human_ai_stealth_pace/proc/looks_to_notice(datum/human_ai_brain/brain, mob/living/carbon/human/intruder, turf/spot_a, turf/spot_b, moving, m_intent)
	brain.remove_contact(intruder)
	brain.vigilance_level = 0
	intruder.m_intent = m_intent
	intruder.forceMove(spot_a)
	var/looks = 0
	var/at_b = FALSE
	for(var/attempt in 1 to 60)
		brain.last_perceive_time = world.time - 5
		if(moving)
			at_b = !at_b
			intruder.forceMove(at_b ? spot_b : spot_a)
		brain.perceive()
		looks++
		if(brain.get_contact(intruder)?.identified())
			break
	return looks

/datum/unit_test/human_ai_stealth_pace/Run()
	saved_detection = SShuman_ai.detection_mult
	SShuman_ai.detection_mult = 1
	var/datum/human_ai_arena/field = new(list("###############", "#.............#", "###############"), run_loc_floor_bottom_left)
	var/mob/living/carbon/human/watcher = make_soldier(locate(field.origin_x + 1, field.origin_y + 1, field.z), FACTION_MARINE, FALSE)
	var/datum/human_ai_brain/brain = watcher.ai_brain
	lookout_pool(brain)
	brain.light_override = 1
	watcher.setDir(EAST)
	var/mob/living/carbon/human/intruder = allocate(/mob/living/carbon/human, locate(field.origin_x + 7, field.origin_y + 1, field.z))
	intruder.faction = FACTION_CLF
	var/turf/here = get_turf(watcher)
	var/turf/there = get_turf(intruder)

	intruder.m_intent = MOVE_INTENT_WALK
	var/still = brain.notice_seconds(intruder, here, there, FALSE)
	var/walking = brain.notice_seconds(intruder, here, there, TRUE)
	intruder.m_intent = MOVE_INTENT_RUN
	var/running = brain.notice_seconds(intruder, here, there, TRUE)
	TEST_ASSERT(running < walking, "A run [running] seconds was no quicker to notice than a walk [walking]")
	TEST_ASSERT(walking < still, "A walk [walking] seconds was no quicker to notice than standing still [still]")

	intruder.m_intent = MOVE_INTENT_WALK
	intruder.body_position = LYING_DOWN
	var/lying = brain.notice_seconds(intruder, here, there, FALSE)
	TEST_ASSERT(lying > still, "Lying still [lying] seconds was no harder to notice than standing still [still]")
	intruder.body_position = STANDING_UP

	watcher.setDir(WEST)
	var/behind = brain.notice_seconds(intruder, here, there, FALSE)
	TEST_ASSERT(behind > 2 * still, "A man behind the watcher [behind] seconds was not much harder to notice than one in front [still]")
	watcher.setDir(EAST)

	// The difficulty setting is a plain factor on it
	SShuman_ai.detection_mult = 2
	var/sharp = brain.notice_seconds(intruder, here, there, FALSE)
	TEST_ASSERT(abs(sharp - still / 2) < 0.01, "Twice the detection made it [sharp] seconds and not half of [still]")
	SShuman_ai.detection_mult = 0.5
	var/dull = brain.notice_seconds(intruder, here, there, FALSE)
	TEST_ASSERT(abs(dull - still * 2) < 0.01, "Half the detection made it [dull] seconds and not twice [still]")
	SShuman_ai.detection_mult = 1

	// A unit that has been startled looks harder for a while and then relaxes
	TEST_ASSERT_EQUAL(brain.vigilance(), 0, "A calm unit was alarmed")
	brain.raise_vigilance(1)
	TEST_ASSERT(brain.vigilance() > 0.99, "The alarm did not take")
	var/alarmed = brain.notice_seconds(intruder, here, there, FALSE)
	TEST_ASSERT(abs(alarmed - still / 2) < 0.01, "An alarmed unit took [alarmed] seconds and not half of [still]")
	brain.vigilance_time -= HAI_VIGILANCE_FADE / 2
	TEST_ASSERT(brain.vigilance() > 0.4 && brain.vigilance() < 0.6, "Half the time on, the alarm is [brain.vigilance()]")
	brain.vigilance_time -= HAI_VIGILANCE_FADE
	TEST_ASSERT_EQUAL(brain.vigilance(), 0, "The alarm never died down")

	// Looking round for real, a runner is made out in fewer looks than a walker and a walker in fewer than a man standing still
	SSspatial_grid.track(intruder, SPATIAL_GRID_TRACK_NPC)
	var/turf/spot_a = locate(field.origin_x + 9, field.origin_y + 1, field.z)
	var/turf/spot_b = locate(field.origin_x + 8, field.origin_y + 1, field.z)
	var/ran_looks = looks_to_notice(brain, intruder, spot_a, spot_b, TRUE, MOVE_INTENT_RUN)
	var/walked_looks = looks_to_notice(brain, intruder, spot_a, spot_b, TRUE, MOVE_INTENT_WALK)
	var/stood_looks = looks_to_notice(brain, intruder, spot_a, spot_b, FALSE, MOVE_INTENT_WALK)
	TEST_ASSERT(stood_looks < 60, "A man standing in plain sight was never made out")
	TEST_ASSERT(ran_looks < walked_looks, "A runner took [ran_looks] looks to make out and a walker [walked_looks]")
	TEST_ASSERT(walked_looks < stood_looks, "A walker took [walked_looks] looks to make out and a man standing still [stood_looks]")
	var/datum/ai_contact/contact = brain.get_contact(intruder)
	TEST_ASSERT(contact?.identified(), "The man standing still was not made out")
	TEST_ASSERT_EQUAL(contact.cue_stage, HAI_CUE_ALERT, "The contact was not marked as made out")
	TEST_ASSERT(brain.vigilance() > 0.5, "Making a man out left the unit at an alarm of [brain.vigilance()]")
	brain.remove_contact(intruder)
	brain.vigilance_level = 0

	// The marker over the head is only there when asked for, and only once in a while
	var/cues_before = SShuman_ai.stealth_cues
	SShuman_ai.stealth_cues = FALSE
	brain.show_cue(HAI_CUE_ALERT)
	TEST_ASSERT_EQUAL(brain.next_cue_time, 0, "A marker was shown with markers off")
	SShuman_ai.stealth_cues = TRUE
	brain.show_cue(HAI_CUE_ALERT)
	TEST_ASSERT(brain.next_cue_time > world.time, "A marker was not shown with markers on")
	var/shown_at = brain.next_cue_time
	brain.show_cue(HAI_CUE_SUSPECT)
	TEST_ASSERT_EQUAL(brain.next_cue_time, shown_at, "Two markers went up at once")
	SShuman_ai.stealth_cues = cues_before
	TEST_ASSERT_EQUAL(brain.error_total, 0, "The brain threw errors")
	detach_human_ai(watcher)

/// Running footsteps carry a few tiles and walking ones do not; how well they are heard follows the alarm and the difficulty
/datum/unit_test/human_ai_footsteps
	var/saved_detection = 1

/datum/unit_test/human_ai_footsteps/Destroy()
	SShuman_ai.detection_mult = saved_detection
	return ..()

/datum/unit_test/human_ai_footsteps/Run()
	saved_detection = SShuman_ai.detection_mult
	SShuman_ai.detection_mult = 1
	var/list/rows = list("##########################")
	for(var/row in 1 to 5)
		rows += "#........................#"
	rows += "##########################"
	var/datum/human_ai_arena/field = new(rows, run_loc_floor_bottom_left)
	var/turf/middle = locate(field.origin_x + 2, field.origin_y + 3, field.z)
	var/mob/living/carbon/human/listener = make_soldier(middle, FACTION_MARINE, FALSE)
	var/datum/human_ai_brain/brain = listener.ai_brain
	lookout_pool(brain)
	// In the dark it sees nothing past two tiles, so what it does is down to what it hears
	brain.light_override = 0
	var/mob/living/carbon/human/walker = allocate(/mob/living/carbon/human, locate(field.origin_x + 20, field.origin_y + 3, field.z))
	walker.faction = FACTION_CLF

	// Two tiles off a runner is gone to look for, three turns the head, five is not heard
	human_ai_footstep(walker, locate(middle.x + 2, middle.y, middle.z), HAI_FOOTSTEP_RANGE)
	TEST_ASSERT_EQUAL(brain.footsteps_heard, 1, "A run two tiles off was not heard")
	TEST_ASSERT_NOTNULL(brain.investigate_turf, "A unit did not go and look for a run two tiles off")
	brain.end_investigation()
	brain.alert_until = 0
	brain.vigilance_level = 0
	human_ai_footstep(walker, locate(middle.x + 3, middle.y, middle.z), HAI_FOOTSTEP_RANGE)
	TEST_ASSERT_EQUAL(brain.footsteps_heard, 2, "A run three tiles off was not heard")
	TEST_ASSERT_NULL(brain.investigate_turf, "A unit went to look for a run three tiles off")
	TEST_ASSERT(brain.alert_until > world.time, "A run three tiles off did not put the unit on the alert")
	human_ai_footstep(walker, locate(middle.x + 5, middle.y, middle.z), HAI_FOOTSTEP_RANGE)
	TEST_ASSERT_EQUAL(brain.footsteps_heard, 2, "A run five tiles off was heard")
	human_ai_footstep(walker, locate(middle.x + 8, middle.y, middle.z), HAI_FOOTSTEP_RANGE)
	TEST_ASSERT_EQUAL(brain.footsteps_heard, 2, "A run eight tiles off was heard")

	// A crawl carries two tiles at most
	human_ai_footstep(walker, locate(middle.x + 3, middle.y, middle.z), HAI_FOOTSTEP_CRAWL_RANGE)
	TEST_ASSERT_EQUAL(brain.footsteps_heard, 2, "A crawl three tiles off was heard")
	human_ai_footstep(walker, locate(middle.x + 1, middle.y, middle.z), HAI_FOOTSTEP_CRAWL_RANGE)
	TEST_ASSERT_EQUAL(brain.footsteps_heard, 3, "A crawl beside the unit was not heard")
	brain.end_investigation()
	brain.alert_until = 0
	brain.vigilance_level = 0

	// A step by a man of its own side is nothing
	var/mob/living/carbon/human/friend = allocate(/mob/living/carbon/human, locate(field.origin_x + 20, field.origin_y + 2, field.z))
	friend.faction = FACTION_MARINE
	human_ai_footstep(friend, locate(middle.x + 2, middle.y, middle.z), HAI_FOOTSTEP_RANGE)
	TEST_ASSERT_EQUAL(brain.footsteps_heard, 3, "A friend's step was heard as an enemy's")

	// Nobody goes to look for a prisoner being led off, a man out cold, or one it can see
	var/list/spots = list(locate(middle.x + 2, middle.y, middle.z))
	walker.pulledby = friend
	human_ai_footstep(walker, spots[1], HAI_FOOTSTEP_RANGE)
	walker.pulledby = null
	walker.handcuffed = new /obj/item/restraint/handcuffs(walker)
	human_ai_footstep(walker, spots[1], HAI_FOOTSTEP_RANGE)
	qdel(walker.handcuffed)
	walker.handcuffed = null
	walker.stat = UNCONSCIOUS
	human_ai_footstep(walker, spots[1], HAI_FOOTSTEP_RANGE)
	walker.stat = CONSCIOUS
	var/datum/ai_contact/seen = brain.ensure_contact(walker, TRUE)
	seen.visible = TRUE
	seen.notice = 1
	human_ai_footstep(walker, spots[1], HAI_FOOTSTEP_RANGE)
	brain.remove_contact(walker)
	TEST_ASSERT_EQUAL(brain.footsteps_heard, 3, "A step that nobody makes by himself, or that is made in plain sight, was heard: [brain.footsteps_heard]")
	TEST_ASSERT_NULL(brain.investigate_turf, "A unit went to look into a step that nobody made by himself")

	// The difficulty and the alarm change how well it is heard
	SShuman_ai.detection_mult = 0.25
	human_ai_footstep(walker, locate(middle.x + 2, middle.y, middle.z), HAI_FOOTSTEP_RANGE)
	TEST_ASSERT_EQUAL(brain.footsteps_heard, 3, "A dulled unit heard a run two tiles off")
	SShuman_ai.detection_mult = 1
	brain.vigilance_level = 0
	human_ai_footstep(walker, locate(middle.x + 3, middle.y, middle.z), HAI_FOOTSTEP_RANGE)
	TEST_ASSERT_NULL(brain.investigate_turf, "A calm unit went to look for a run three tiles off")
	brain.raise_vigilance(1)
	human_ai_footstep(walker, locate(middle.x + 3, middle.y, middle.z), HAI_FOOTSTEP_RANGE)
	TEST_ASSERT_NOTNULL(brain.investigate_turf, "An alarmed unit did not go to look for a run three tiles off")
	brain.end_investigation()
	brain.vigilance_level = 0

	// The real thing: a man running by makes the sound and a man walking by does not
	var/heard_before = brain.footsteps_heard
	walker.forceMove(locate(middle.x + 5, middle.y, middle.z))
	walker.m_intent = MOVE_INTENT_WALK
	for(var/step_count in 1 to 3)
		step(walker, WEST)
		sleep(1)
	TEST_ASSERT_EQUAL(brain.footsteps_heard, heard_before, "Walking footsteps were heard")
	walker.forceMove(locate(middle.x + 5, middle.y, middle.z))
	walker.m_intent = MOVE_INTENT_RUN
	for(var/step_count in 1 to 3)
		step(walker, WEST)
		sleep(1)
	TEST_ASSERT(brain.footsteps_heard > heard_before, "Running footsteps were never heard, the man ended at [walker.x] and the unit at [listener.x]")
	TEST_ASSERT_EQUAL(brain.error_total, 0, "The brain threw errors")
	detach_human_ai(listener)

/// A friend lying dead or out cold where a unit can see him is not something that happens by itself
/datum/unit_test/human_ai_body_discovery
	var/mob/living/carbon/human/finder

/datum/unit_test/human_ai_body_discovery/proc/found_one()
	return finder.ai_brain.bodies_found > 0

/datum/unit_test/human_ai_body_discovery/Run()
	var/list/rows = list("####################")
	for(var/row in 1 to 3)
		rows += "#..................#"
	rows += "####################"
	var/datum/human_ai_arena/field = new(rows, run_loc_floor_bottom_left)
	finder = make_soldier(locate(field.origin_x + 2, field.origin_y + 2, field.z), FACTION_MARINE, FALSE)
	var/mob/living/carbon/human/mate = make_soldier(locate(field.origin_x + 3, field.origin_y + 1, field.z), FACTION_MARINE, FALSE)
	var/datum/human_ai_squad/squad = create_human_ai_squad(list(finder, mate), finder, "Finders")
	TEST_ASSERT_NOTNULL(squad, "No squad was made")
	var/datum/human_ai_brain/brain = finder.ai_brain
	lookout_pool(brain)
	lookout_pool(mate.ai_brain)
	finder.setDir(EAST)
	var/mob/living/carbon/human/dead_man = allocate(/mob/living/carbon/human, locate(field.origin_x + 7, field.origin_y + 2, field.z))
	dead_man.faction = FACTION_MARINE
	dead_man.death(create_cause_data("unit test"))
	TEST_ASSERT_EQUAL(dead_man.stat, DEAD, "The test body would not die")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(found_one)), 20), "A unit never found a friend lying dead in plain sight")
	TEST_ASSERT_EQUAL(brain.bodies_found, 1, "The body was found [brain.bodies_found] times")
	TEST_ASSERT(brain.vigilance() > 0.6, "Finding a body left the unit at an alarm of [brain.vigilance()]")
	TEST_ASSERT_NOTNULL(brain.investigate_turf, "A unit that found a body did not go to look around it")
	TEST_ASSERT(get_dist(brain.investigate_turf, get_turf(dead_man)) <= 3, "It went to look [get_dist(brain.investigate_turf, get_turf(dead_man))] tiles from the body")
	TEST_ASSERT(mate.ai_brain.vigilance() > 0.3, "The squad mate was not put on edge by it: [mate.ai_brain.vigilance()]")
	sleep(6 SECONDS)
	TEST_ASSERT_EQUAL(brain.bodies_found, 1, "The same body was found again")

	// An enemy lying dead is not a thing to be alarmed about, and neither is a body in the dark that cannot be seen
	var/mob/living/carbon/human/stranger = allocate(/mob/living/carbon/human, locate(field.origin_x + 8, field.origin_y + 1, field.z))
	stranger.faction = FACTION_CLF
	stranger.death(create_cause_data("unit test"))
	var/mob/living/carbon/human/dark_finder = make_soldier(locate(field.origin_x + 12, field.origin_y + 3, field.z), FACTION_MARINE, FALSE)
	lookout_pool(dark_finder.ai_brain)
	dark_finder.ai_brain.light_override = 0
	var/mob/living/carbon/human/far_body = allocate(/mob/living/carbon/human, locate(field.origin_x + 17, field.origin_y + 3, field.z))
	far_body.faction = FACTION_MARINE
	far_body.death(create_cause_data("unit test"))
	sleep(10 SECONDS)
	TEST_ASSERT_EQUAL(brain.bodies_found, 1, "A dead enemy was taken for a dead friend")
	TEST_ASSERT_EQUAL(dark_finder.ai_brain.bodies_found, 0, "A body five tiles off in the dark was found")
	TEST_ASSERT_EQUAL(brain.error_total + dark_finder.ai_brain.error_total + mate.ai_brain.error_total, 0, "A brain threw errors")
	squad.disband()
	detach_human_ai(finder)
	detach_human_ai(mate)
	detach_human_ai(dark_finder)

/// A unit in the dark puts a light on, and puts it out in the place where it is not needed; one that works unseen keeps it off until it has something to look at
/datum/unit_test/human_ai_gear_lamps

/datum/unit_test/human_ai_gear_lamps/Run()
	var/datum/human_ai_arena/field = new(list("##########", "#........#", "#........#", "##########"), run_loc_floor_bottom_left)
	var/mob/living/carbon/human/soldier = make_soldier(locate(field.origin_x + 2, field.origin_y + 1, field.z), FACTION_MARINE, FALSE)
	var/datum/human_ai_brain/brain = soldier.ai_brain
	lookout_pool(brain)
	var/obj/item/clothing/suit/storage/marine/armor = new(soldier)
	dress(soldier, armor, WEAR_JACKET)
	TEST_ASSERT_EQUAL(soldier.wear_suit, armor, "The armor did not go on")
	TEST_ASSERT(armor in brain.lamp_sources(), "The armor lamp was not found")

	// Lit, nothing is done; dark, the lamp goes on
	brain.light_override = 1
	TEST_ASSERT_NULL(brain.plan_gear(), "A unit in the light wanted to do something about its gear")
	brain.light_override = 0
	var/list/job = brain.plan_gear()
	TEST_ASSERT_NOTNULL(job, "A unit in the dark did not want a lamp")
	TEST_ASSERT_EQUAL(job[1], "lamp", "It wanted [job[1]]")
	TEST_ASSERT(job[3], "It wanted the lamp out")
	TEST_ASSERT(brain.do_gear_job(job), "The lamp would not go on")
	TEST_ASSERT(armor.light_on, "The armor lamp is not lit")
	TEST_ASSERT_NOTNULL(brain.lamp_area, "The place where the lamp went on was not remembered")

	// The lamp lights its own tile, which must not be taken for a lit room
	brain.light_override = 1
	TEST_ASSERT_NULL(brain.plan_gear(), "A unit with its own lamp on put it out because its own tile was lit")

	// In another place, it goes out
	sleep(2 SECONDS)
	var/area/elsewhere
	for(var/area/candidate in world)
		if(candidate != get_area(soldier))
			elsewhere = candidate
			break
	TEST_ASSERT_NOTNULL(elsewhere, "There is no other area to go to")
	brain.lamp_area = elsewhere
	job = brain.plan_gear()
	TEST_ASSERT_NOTNULL(job, "The lamp was not put out in a lit place")
	TEST_ASSERT(!job[3], "It wanted the lamp on in a lit place")
	TEST_ASSERT(brain.do_gear_job(job), "The lamp would not go out")
	TEST_ASSERT(!armor.light_on, "The armor lamp is still lit")
	TEST_ASSERT_NULL(brain.lamp_area, "The place was not forgotten")

	// Told to keep the lights off, it does
	sleep(2 SECONDS)
	brain.light_override = 0
	brain.lights_out = TRUE
	TEST_ASSERT_NULL(brain.plan_gear(), "A unit told to keep its lights off wanted a lamp")
	brain.lights_out = FALSE

	// The server only lets so many lamps burn at once
	var/list/saved_lamps = GLOB.human_ai_lit_lamps.Copy()
	for(var/index in 1 to HAI_LAMP_CAP)
		GLOB.human_ai_lit_lamps += "stand-in [index]"
	var/list/capped = brain.plan_gear()
	GLOB.human_ai_lit_lamps = saved_lamps
	TEST_ASSERT_NULL(capped, "A unit lit a lamp with every lamp the server allows already burning")

	// A sniper keeps them off until it has something to look at, and puts them out again after
	brain.set_role("sniper")
	brain.set_intent(HAI_INTENT_IDLE)
	TEST_ASSERT_NULL(brain.plan_gear(), "A sniper at ease lit a lamp in the dark")
	brain.set_intent(HAI_INTENT_INVESTIGATE)
	job = brain.plan_gear()
	TEST_ASSERT(job && job[3], "A sniper on the hunt did not light a lamp")
	TEST_ASSERT(brain.do_gear_job(job), "The sniper's lamp would not go on")
	sleep(2 SECONDS)
	brain.set_intent(HAI_INTENT_IDLE)
	job = brain.plan_gear()
	TEST_ASSERT(job && !job[3], "A sniper at ease again kept its lamp lit")
	TEST_ASSERT(brain.do_gear_job(job), "The sniper's lamp would not go out")
	TEST_ASSERT(!armor.light_on, "The sniper's lamp is still lit")

	// A flashlight on the gun comes before the armor's lamp; one in the hand is used when nothing else is there
	sleep(2 SECONDS)
	brain.set_role("rifleman")
	var/obj/item/weapon/gun/rifle/m41a/rifle = new(soldier)
	soldier.put_in_hands(rifle)
	var/obj/item/attachable/flashlight/rail = new(soldier)
	rail.Attach(rifle)
	TEST_ASSERT_EQUAL(rifle.attachments["rail"], rail, "The flashlight did not go on the rail")
	var/list/lamps = brain.lamp_sources()
	TEST_ASSERT_EQUAL(lamps[1], rail, "The gun's flashlight did not come first, [lamps[1]] did")
	job = brain.plan_gear()
	TEST_ASSERT(job && job[2] == rail && job[3], "A unit in the dark did not light the lamp on its gun")
	TEST_ASSERT(brain.do_gear_job(job), "The lamp on the gun would not go on")
	TEST_ASSERT(rail.light_on, "The flashlight on the gun is not lit")
	TEST_ASSERT(rifle.light_on, "The gun gives no light")
	sleep(2 SECONDS)
	TEST_ASSERT(brain.switch_lamp(rail, FALSE), "The lamp on the gun would not go out")
	TEST_ASSERT(!rail.light_on, "The flashlight on the gun is still lit")
	var/obj/item/device/flashlight/torch = new(soldier)
	soldier.put_in_hands(torch)
	TEST_ASSERT_EQUAL(torch.loc, soldier, "The flashlight did not go in a hand")
	TEST_ASSERT(torch in brain.lamp_sources(), "The flashlight in the hand was not found")
	sleep(2 SECONDS)
	TEST_ASSERT(brain.switch_lamp(torch, TRUE), "The flashlight in the hand would not go on")
	TEST_ASSERT(torch.on && torch.light_on, "The flashlight in the hand gives no light")
	TEST_ASSERT(brain.switch_lamp(torch, FALSE), "The flashlight in the hand would not go out")
	TEST_ASSERT(!torch.on, "The flashlight in the hand is still on")

	// The action does it without being asked
	sleep(2 SECONDS)
	lookout_pool(brain, "use_gear")
	brain.next_gear_check = 0
	brain.set_intent(HAI_INTENT_IDLE)
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(any_light_on), brain), 12), "The unit never lit a lamp by itself in the dark: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT(brain.gear_toggles >= 1, "The toggles were not counted")
	TEST_ASSERT_EQUAL(brain.error_total, 0, "The brain threw errors: [brain.decision_log.Join(" | ")]")
	detach_human_ai(soldier)

/datum/unit_test/human_ai_gear_lamps/proc/any_light_on(datum/human_ai_brain/brain)
	return !!brain.lamp_lit(brain.lamp_sources())

/// Night vision goggles are used instead of a lamp, on in the dark and off in the light
/datum/unit_test/human_ai_gear_night_vision

/datum/unit_test/human_ai_gear_night_vision/Run()
	var/datum/human_ai_arena/field = new(list("##########", "#........#", "#........#", "##########"), run_loc_floor_bottom_left)
	var/mob/living/carbon/human/soldier = make_soldier(locate(field.origin_x + 2, field.origin_y + 1, field.z), FACTION_MARINE, FALSE)
	var/datum/human_ai_brain/brain = soldier.ai_brain
	lookout_pool(brain)
	var/obj/item/clothing/suit/storage/marine/armor = new(soldier)
	dress(soldier, armor, WEAR_JACKET)
	var/obj/item/clothing/glasses/night/goggles = new(soldier)
	dress(soldier, goggles, WEAR_EYES)
	TEST_ASSERT_EQUAL(soldier.glasses, goggles, "The goggles did not go on")
	TEST_ASSERT_EQUAL(brain.night_glasses(), goggles, "The goggles were not found")
	if(!goggles.active)
		goggles.attack_self(soldier)
	TEST_ASSERT(goggles.active, "The goggles would not switch on for the test")
	soldier.update_sight()
	TEST_ASSERT(brain.has_night_vision(), "A unit in working night vision goggles has no night vision")

	// In the light they are put away, so that a flash does not hurt
	brain.light_override = 1
	var/list/job = brain.plan_gear()
	TEST_ASSERT(job && job[1] == "nvg" && !job[3], "Goggles in the light were not switched off: [job ? job[1] : "no job"]")
	TEST_ASSERT(brain.do_gear_job(job), "The goggles would not switch off")
	TEST_ASSERT(!goggles.active, "The goggles are still on")
	soldier.update_sight()
	TEST_ASSERT(!brain.has_night_vision(), "A unit with its goggles off still has night vision")
	TEST_ASSERT_NULL(brain.plan_gear(), "A unit in the light had something to do")

	// In the dark they go on, and a lit lamp is put out because the goggles do the seeing
	brain.light_override = 0
	job = brain.plan_gear()
	TEST_ASSERT(job && job[1] == "nvg" && job[3], "Goggles in the dark were not switched on: [job ? job[1] : "no job"]")
	TEST_ASSERT(brain.do_gear_job(job), "The goggles would not switch on")
	TEST_ASSERT(goggles.active, "The goggles are still off")
	soldier.update_sight()
	TEST_ASSERT(brain.has_night_vision(), "A unit with its goggles on has no night vision")
	TEST_ASSERT_NULL(brain.plan_gear(), "A unit in goggles in the dark wanted a lamp")
	armor.turn_light(soldier, TRUE)
	TEST_ASSERT(armor.light_on, "The lamp would not light for the test")
	job = brain.plan_gear()
	TEST_ASSERT(job && job[1] == "lamp" && !job[3], "A lamp lit under night vision was not put out")
	TEST_ASSERT_EQUAL(brain.error_total, 0, "The brain threw errors")
	detach_human_ai(soldier)

/// Welding gear comes down for welding and goes up again, since a unit sees next to nothing through it
/datum/unit_test/human_ai_gear_welding

/datum/unit_test/human_ai_gear_welding/Run()
	var/datum/human_ai_arena/field = new(list("##########", "#........#", "#........#", "##########"), run_loc_floor_bottom_left)
	var/mob/living/carbon/human/worker = make_soldier(locate(field.origin_x + 2, field.origin_y + 1, field.z), FACTION_MARINE, FALSE)
	var/datum/human_ai_brain/brain = worker.ai_brain
	lookout_pool(brain)
	brain.light_override = 1

	// A mask on the head: up when there is no welding, down for it and for a while after
	var/obj/item/clothing/head/welding/mask = new(worker)
	dress(worker, mask, WEAR_HEAD)
	TEST_ASSERT_EQUAL(brain.weld_gear(), mask, "The mask was not found")
	TEST_ASSERT(brain.weld_gear_down(mask), "A fresh mask was not taken for down")
	var/list/job = brain.plan_gear()
	TEST_ASSERT(job && job[1] == "weld" && !job[3], "A unit with its mask down and no welding to do wanted [job ? "[job[1]] [job[3]]" : "nothing"]")
	TEST_ASSERT(brain.do_gear_job(job), "The mask would not go up")
	TEST_ASSERT(mask.up, "The mask is still down")
	TEST_ASSERT_NULL(brain.plan_gear(), "A unit with its mask up had something to do")
	brain.prepare_to_weld()
	TEST_ASSERT(!mask.up, "Getting ready to weld left the mask up")
	TEST_ASSERT(brain.weld_until > world.time, "The mask is not meant to stay down")
	TEST_ASSERT_NULL(brain.plan_gear(), "A unit welding wanted its mask up")
	brain.weld_until = world.time - 1
	job = brain.plan_gear()
	TEST_ASSERT(job && job[1] == "weld" && !job[3], "A unit done welding did not want its mask up")
	TEST_ASSERT(brain.do_gear_job(job), "The mask would not go up after the welding")
	TEST_ASSERT(mask.up, "The mask stayed down after the welding")

	// A welder lit in the hand counts as welding too
	var/obj/item/tool/weldingtool/welder = new(worker)
	worker.put_in_hands(welder)
	welder.toggle()
	TEST_ASSERT(welder.welding, "The welder would not light")
	TEST_ASSERT(brain.welding_now(), "A lit welder in the hand was not taken for welding")
	job = brain.plan_gear()
	TEST_ASSERT(job && job[1] == "weld" && job[3], "A unit with a lit welder did not want its mask down")
	TEST_ASSERT(brain.do_gear_job(job), "The mask would not go down")
	welder.toggle()
	TEST_ASSERT(!welder.welding, "The welder would not go out")
	brain.weld_until = 0
	job = brain.plan_gear()
	TEST_ASSERT(job && !job[3], "A unit whose welder went out did not want its mask up")
	brain.do_gear_job(job)
	TEST_ASSERT(mask.up, "The mask stayed down with the welder out")
	worker.drop_held_item(welder)

	// Goggles
	var/obj/item/clothing/head/welding/old_mask = worker.head
	worker.temp_drop_inv_item(old_mask)
	worker.head = null
	qdel(old_mask)
	var/obj/item/clothing/glasses/welding/goggles = new(worker)
	dress(worker, goggles, WEAR_EYES)
	TEST_ASSERT_EQUAL(brain.weld_gear(), goggles, "The goggles were not found")
	TEST_ASSERT(brain.weld_gear_down(goggles), "Fresh goggles were not taken for down")
	TEST_ASSERT(brain.set_weld_gear(goggles, FALSE), "The goggles would not go up")
	TEST_ASSERT(!goggles.active, "The goggles are still down")
	brain.prepare_to_weld()
	TEST_ASSERT(goggles.active, "Getting ready to weld left the goggles up")
	TEST_ASSERT(brain.set_weld_gear(goggles, FALSE), "The goggles would not go up again")
	worker.temp_drop_inv_item(goggles)
	worker.glasses = null
	qdel(goggles)

	// The visor of a technician's helmet
	var/obj/item/clothing/head/helmet/marine/tech/helmet = new(worker)
	dress(worker, helmet, WEAR_HEAD)
	TEST_ASSERT_EQUAL(worker.head, helmet, "The helmet did not go on")
	var/obj/item/device/helmet_visor/welding_visor/visor = brain.weld_gear()
	TEST_ASSERT(istype(visor), "The helmet's welding visor was not found")
	TEST_ASSERT(!brain.weld_gear_down(visor), "The visor was down in a fresh helmet")
	brain.prepare_to_weld()
	TEST_ASSERT(brain.weld_gear_down(visor), "Getting ready to weld left the visor up")
	brain.eye_reach_time = -1
	TEST_ASSERT_EQUAL(brain.eye_tint(), VISION_IMPAIR_ULTRA, "The visor did not tint the sight")
	TEST_ASSERT(brain.set_weld_gear(visor, FALSE), "The visor would not go up")
	TEST_ASSERT(!brain.weld_gear_down(visor), "The visor is still down")
	brain.eye_reach_time = -1
	TEST_ASSERT_EQUAL(brain.eye_tint(), VISION_IMPAIR_NONE, "The visor still tints the sight")
	TEST_ASSERT_EQUAL(brain.error_total, 0, "The brain threw errors")
	detach_human_ai(worker)
