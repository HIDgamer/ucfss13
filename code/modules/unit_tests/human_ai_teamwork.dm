/// A friend's stray shots are warned about and forgiven, one who keeps shooting is fought for a while and then forgiven too
/datum/unit_test/human_ai_friendly_tolerance

/datum/unit_test/human_ai_friendly_tolerance/Run()
	SShuman_ai.record_talk = TRUE
	SShuman_ai.talk_log = list()
	SShuman_ai.talk_window_end = 0
	var/turf/spot = run_loc_floor_bottom_left
	var/mob/living/carbon/human/guard = make_soldier(spot, FACTION_MARINE, FALSE)
	var/datum/human_ai_brain/brain = guard.ai_brain
	var/mob/living/carbon/human/friend = allocate(/mob/living/carbon/human, locate(spot.x + 3, spot.y, spot.z))
	friend.faction = FACTION_MARINE
	TEST_ASSERT_EQUAL(brain.get_disposition(friend), HAI_DISP_FRIEND, "A marine does not see a marine as a friend")

	brain.note_friendly_hit(friend)
	TEST_ASSERT_EQUAL(brain.get_disposition(friend), HAI_DISP_FRIEND, "One stray hit turned a friend into an enemy")
	TEST_ASSERT_EQUAL(length(brain.tolerance), 1, "The first hit was not counted")
	var/warned = FALSE
	for(var/list/entry in SShuman_ai.talk_log)
		if(entry[3] == HAI_EXPR_WATCH_FIRE)
			warned = TRUE
	TEST_ASSERT(warned, "The unit did not tell the friend to watch their fire")

	var/hits = 1
	while(brain.get_disposition(friend) < HAI_DISP_HOSTILE && hits < 10)
		brain.note_friendly_hit(friend)
		hits++
	TEST_ASSERT_EQUAL(brain.get_disposition(friend), HAI_DISP_HOSTILE, "A friend who kept shooting was never fought back")
	TEST_ASSERT(hits >= 2 && hits <= 6, "The unit put up with [hits] hits before it hit back")
	TEST_ASSERT(brain.holds_grudge_against(friend), "The unit does not hold a grudge")
	TEST_ASSERT(brain.is_valid_target(friend), "A friend who kept shooting is not a valid target")

	// The grudge runs out and the friend is a friend again, the more merciful forgive faster than the ruthless would
	brain.disposition_override[REF(friend)] = world.time - 1
	TEST_ASSERT_EQUAL(brain.get_disposition(friend), HAI_DISP_FRIEND, "The grudge never ran out")
	TEST_ASSERT(!brain.is_valid_target(friend), "A forgiven friend is still a valid target")

	// The enemy who shoots is not given any slack
	var/mob/living/carbon/human/enemy = allocate(/mob/living/carbon/human, locate(spot.x + 4, spot.y, spot.z))
	enemy.faction = FACTION_CLF
	TEST_ASSERT_EQUAL(brain.get_disposition(enemy), HAI_DISP_HOSTILE, "An enemy is not hostile")
	SShuman_ai.record_talk = FALSE
	TEST_ASSERT_EQUAL(brain.error_total, 0, "The brain threw errors")
	detach_human_ai(guard)

/// The first contact of a fight is a call for backup naming the area, over the radio with a headset, and the nearest free allies come to it
/datum/unit_test/human_ai_backup_call
	var/datum/human_ai_brain/helper

/datum/unit_test/human_ai_backup_call/proc/arrived()
	return get_dist(helper.body, helper.investigate_turf || helper.body) <= 3 && helper.backups_answered >= 1

/datum/unit_test/human_ai_backup_call/Run()
	SShuman_ai.record_talk = TRUE
	SShuman_ai.talk_log = list()
	SShuman_ai.talk_window_end = 0
	GLOB.human_ai_backup_radio = list()
	var/list/rows = list()
	var/wall = ""
	var/floor = "#"
	for(var/column in 1 to 60)
		wall += "#"
		if(column > 2)
			floor += "."
	floor += "#"
	rows += wall
	for(var/row in 1 to 3)
		rows += floor
	rows += wall
	var/datum/human_ai_arena/field = new(rows, run_loc_floor_bottom_left)
	var/turf/start = locate(field.origin_x + 3, field.origin_y + 2, field.z)
	var/mob/living/carbon/human/caller_body = make_soldier(start, FACTION_MARINE, FALSE)
	var/datum/human_ai_brain/caller_brain = caller_body.ai_brain
	var/mob/living/carbon/human/near_body = make_soldier(locate(field.origin_x + 12, field.origin_y + 2, field.z), FACTION_MARINE, FALSE)
	helper = near_body.ai_brain
	var/mob/living/carbon/human/far_body = make_soldier(locate(field.origin_x + 50, field.origin_y + 2, field.z), FACTION_MARINE, FALSE)
	var/mob/living/carbon/human/rival_body = make_soldier(locate(field.origin_x + 10, field.origin_y + 1, field.z), FACTION_CLF, FALSE)
	var/mob/living/carbon/xenomorph/drone/dummy = make_target_dummy(locate(field.origin_x + 8, field.origin_y + 2, field.z))
	TEST_ASSERT(get_dist(caller_body, far_body) > HAI_BACKUP_RANGE, "The far ally is within the range of the call")

	TEST_ASSERT(caller_brain.call_for_backup(dummy), "The call for backup was refused")
	TEST_ASSERT_EQUAL(caller_brain.backups_called, 1, "The call was not counted")
	var/said
	for(var/list/entry in SShuman_ai.talk_log)
		if(entry[3] == HAI_EXPR_BACKUP)
			said = entry[4]
	TEST_ASSERT_NOTNULL(said, "The call for backup was not said")
	var/area/here = get_area(caller_body)
	TEST_ASSERT(findtext(said, here.name), "The call [said] does not name the area [here.name]")
	TEST_ASSERT(!findtext(said, "%"), "A placeholder was left in [said]")
	TEST_ASSERT_EQUAL(helper.backups_answered, 1, "The nearby ally did not answer the call")
	TEST_ASSERT_EQUAL(helper.investigate_turf, get_turf(caller_body), "The nearby ally is not heading for the caller: [helper.decision_log.Join(" | ")]")
	TEST_ASSERT_NULL(far_body.ai_brain.investigate_turf, "An ally out of range came to the call")
	TEST_ASSERT_NULL(rival_body.ai_brain.investigate_turf, "The other side came to the call")
	TEST_ASSERT(!caller_brain.call_for_backup(dummy), "A second call came right after the first")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(arrived)), 25), "The ally never got to the caller, it is at [near_body.x],[near_body.y]: [helper.decision_log.Join(" | ")]")

	// A headset puts the call on the radio, once in a while per side
	dress(caller_body, new /obj/item/device/radio/headset(caller_body), WEAR_L_EAR)
	TEST_ASSERT(caller_brain.has_headset(), "The caller does not wear the headset, its ears hold [caller_body.wear_l_ear] and [caller_body.wear_r_ear]")
	caller_brain.next_backup_call = 0
	caller_brain.talk_times = list()
	caller_brain.last_talk_time = 0
	SShuman_ai.talk_window_end = 0
	TEST_ASSERT(caller_brain.call_for_backup(dummy), "The call with a headset was refused")
	for(var/list/entry in SShuman_ai.talk_log)
		if(entry[3] == HAI_EXPR_BACKUP)
			said = entry[4]
	TEST_ASSERT_EQUAL(copytext(said, 1, 2), ";", "The call with a headset did not go on the radio: [said], the log has [length(SShuman_ai.talk_log)] lines and the radio gap of the side is [GLOB.human_ai_backup_radio[FACTION_MARINE]] at [world.time]")
	SShuman_ai.record_talk = FALSE
	TEST_ASSERT_EQUAL(caller_brain.error_total + helper.error_total, 0, "A brain threw errors")
	detach_human_ai(caller_body)
	detach_human_ai(near_body)
	detach_human_ai(far_body)
	detach_human_ai(rival_body)

/// A unit short of a gun, ammunition, medical supplies or tools picks them up off the floor in sight, and leaves the rest alone
/datum/unit_test/human_ai_looting
	var/datum/human_ai_brain/scavenger

/datum/unit_test/human_ai_looting/proc/armed()
	return !!scavenger.peek_gun()

/datum/unit_test/human_ai_looting/proc/packed(obj/item/thing)
	return !isturf(thing.loc)

/datum/unit_test/human_ai_looting/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/datum/human_ai_arena/yard = new(list(
		"##############################",
		"#............................#",
		"#............................#",
		"#............................#",
		"#............................#",
		"##############################",
	), run_loc_floor_bottom_left)
	var/turf/start = locate(yard.origin_x + 3, yard.origin_y + 2, yard.z)
	var/mob/living/carbon/human/soldier = make_soldier(start, FACTION_MARINE, FALSE)
	scavenger = soldier.ai_brain
	dress(soldier, new /obj/item/storage/backpack(soldier), WEAR_BACK)

	// Out of reach it is left alone
	var/obj/item/stack/medical/bruise_pack/far_bandage = new(locate(start.x + 15, start.y, start.z))
	sleep(8 SECONDS)
	TEST_ASSERT(isturf(far_bandage.loc), "A bandage far away was picked up")
	TEST_ASSERT_EQUAL(scavenger.loot_count, 0, "The unit looted something out of sight")
	qdel(far_bandage)

	var/obj/item/weapon/gun/rifle/m41a/rifle = new(locate(start.x + 3, start.y + 1, start.z))
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(armed)), 25), "The unarmed unit never picked up the rifle on the floor: [scavenger.decision_log.Join(" | ")]")
	TEST_ASSERT(soldier.get_active_hand() == rifle || soldier.get_inactive_hand() == rifle, "The rifle is not in a hand")
	TEST_ASSERT(scavenger.loot_count >= 1, "The pick-up was not counted")

	// Armed now, so another rifle on the floor is none of its business, but a bandage is
	var/obj/item/weapon/gun/rifle/m41a/spare_rifle = new(locate(start.x + 2, start.y - 1, start.z))
	var/obj/item/stack/medical/bruise_pack/bandage = new(locate(start.x + 1, start.y + 2, start.z))
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(packed), bandage), 25), "The unit did not pick up a bandage it was short of: [scavenger.decision_log.Join(" | ")]")
	TEST_ASSERT(isturf(spare_rifle.loc), "The unit picked up a second rifle with one in hand")
	TEST_ASSERT_EQUAL(scavenger.error_total, 0, "The unit's brain threw errors")
	detach_human_ai(soldier)

/// A friendly player's words near a unit are turned into orders, strangers and the other side are ignored, a name picks who is meant
/datum/unit_test/human_ai_voice_commands

/datum/unit_test/human_ai_voice_commands/proc/following(datum/human_ai_brain/brain)
	return istype(brain.current_order, /datum/npc_order/follow)

/datum/unit_test/human_ai_voice_commands/Run()
	// What counts as a command
	TEST_ASSERT_EQUAL(human_ai_voice_command("Follow me!"), "follow", "Follow me was not understood")
	TEST_ASSERT_EQUAL(human_ai_voice_command("HOLD FIRE, hold fire!"), "stand_down", "Hold fire was not understood")
	TEST_ASSERT_EQUAL(human_ai_voice_command("Don't shoot"), "stand_down", "Don't shoot was not understood")
	TEST_ASSERT_EQUAL(human_ai_voice_command("cover me"), "escort", "Cover me was not told from take cover")
	TEST_ASSERT_EQUAL(human_ai_voice_command("take cover!"), "cover", "Take cover was not understood")
	TEST_ASSERT_EQUAL(human_ai_voice_command("hold position"), "hold", "Hold position was not understood")
	TEST_ASSERT_EQUAL(human_ai_voice_command("Fall back, fall back!"), "fall_back", "Fall back was not understood")
	TEST_ASSERT_EQUAL(human_ai_voice_command("we need a medic over here"), "medic", "A call for a medic was not understood")
	TEST_ASSERT_EQUAL(human_ai_voice_command("I surrender!"), "surrender", "A surrender was not understood")
	TEST_ASSERT_EQUAL(human_ai_voice_command("fortify here"), "fortify", "Fortify was not understood")
	TEST_ASSERT_NULL(human_ai_voice_command("nice weather we are having today"), "Chatter was taken for a command")
	TEST_ASSERT_NULL(human_ai_voice_command("I will stay safe and stop by the shop"), "Words inside other words were taken for a command")
	TEST_ASSERT_NULL(human_ai_voice_command("the document is with the doctor"), "Parts of other words were taken for a command")

	var/datum/human_ai_arena/yard = new(list(
		"####################",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"####################",
	), run_loc_floor_bottom_left)
	var/turf/spot = locate(yard.origin_x + 4, yard.origin_y + 2, yard.z)
	var/mob/living/carbon/human/commander = allocate(/mob/living/carbon/human, spot)
	commander.faction = FACTION_MARINE
	var/mob/living/carbon/human/mate = make_soldier(locate(spot.x + 3, spot.y, spot.z), FACTION_MARINE, FALSE)
	var/mob/living/carbon/human/other = make_soldier(locate(spot.x + 3, spot.y + 1, spot.z), FACTION_MARINE, FALSE)
	mate.real_name = "Bob Reyes"
	other.real_name = "Alice Vance"
	var/datum/human_ai_brain/mate_brain = mate.ai_brain
	var/datum/human_ai_brain/other_brain = other.ai_brain

	TEST_ASSERT(mate_brain.overhear(commander, "Follow me!"), "A friend's command was not taken up")
	TEST_ASSERT(following(mate_brain), "The unit was told to follow and is doing [mate_brain.current_order?.id]")
	TEST_ASSERT(mate_brain.current_order.get_target() == commander, "The unit follows someone else")
	TEST_ASSERT_EQUAL(mate_brain.voice_orders, 1, "The command was not counted")
	TEST_ASSERT(!mate_brain.overhear(commander, "hold position"), "A second command came within the gap")
	TEST_ASSERT(following(mate_brain), "A command inside the gap changed the order")
	mate_brain.voice_heard = list()
	TEST_ASSERT(mate_brain.overhear(commander, "Hold position."), "A later command was refused")
	TEST_ASSERT(istype(mate_brain.current_order, /datum/npc_order/hold), "The unit was told to hold and is doing [mate_brain.current_order?.id]")

	// The other side, the far away and the chatter are not obeyed
	var/mob/living/carbon/human/enemy = allocate(/mob/living/carbon/human, locate(spot.x + 1, spot.y, spot.z))
	enemy.faction = FACTION_CLF
	mate_brain.voice_heard = list()
	TEST_ASSERT(!mate_brain.overhear(enemy, "follow me"), "The other side gave a command")
	var/mob/living/carbon/human/distant = allocate(/mob/living/carbon/human, locate(spot.x + 14, spot.y, spot.z))
	distant.faction = FACTION_MARINE
	TEST_ASSERT(!mate_brain.overhear(distant, "follow me"), "A voice from across the yard gave a command")
	TEST_ASSERT(!mate_brain.overhear(commander, "nice day for a walk"), "Chatter gave a command")
	TEST_ASSERT(!mate_brain.overhear(other, "follow me"), "Another unit gave a command")
	TEST_ASSERT(istype(mate_brain.current_order, /datum/npc_order/hold), "The order changed on a command nobody could give")

	// Naming one of them picks who answers
	mate_brain.voice_heard = list()
	other_brain.voice_heard = list()
	other_brain.cancel_order()
	TEST_ASSERT(other_brain.overhear(commander, "Alice, follow me"), "The unit that was named did not answer")
	TEST_ASSERT(following(other_brain), "The named unit is not following")
	mate_brain.cancel_order()
	other_brain.voice_heard = list()
	other_brain.cancel_order()
	TEST_ASSERT(!other_brain.overhear(commander, "Reyes, follow me"), "The unit that was not named answered")
	TEST_ASSERT(mate_brain.overhear(commander, "Reyes, follow me"), "The unit that was named did not answer")

	// A call for a medic is not an order
	GLOB.human_ai_medic_calls = list()
	mate_brain.voice_heard = list()
	TEST_ASSERT(mate_brain.overhear(commander, "medic!"), "The call for a medic was ignored")
	TEST_ASSERT_NOTNULL(GLOB.human_ai_medic_calls[REF(commander)], "The call for a medic was not recorded where medics look")

	// Holding fire and carrying on
	mate_brain.voice_heard = list()
	var/roe_before = mate_brain.roe
	TEST_ASSERT(mate_brain.overhear(commander, "cease fire"), "Cease fire was ignored")
	TEST_ASSERT_EQUAL(mate_brain.roe, HAI_ROE_WEAPONS_HOLD, "The unit did not hold fire")
	mate_brain.voice_heard = list()
	TEST_ASSERT(mate_brain.overhear(commander, "weapons free"), "Weapons free was ignored")
	TEST_ASSERT_EQUAL(mate_brain.roe, roe_before, "The unit did not go back to its rules of engagement")

	// One shout reaches only so many of them, what was said in the same moment before it counts toward that
	sleep(1)
	var/accepted = 0
	var/list/crowd = list()
	for(var/count in 1 to HAI_VOICE_ANSWERS + 3)
		var/mob/living/carbon/human/extra = make_soldier(locate(spot.x + 1 + (count % 4), spot.y - 1 + round(count / 4), spot.z), FACTION_MARINE, FALSE)
		crowd += extra
		extra.real_name = "Private Number[count]"
		if(extra.ai_brain.overhear(commander, "regroup"))
			accepted++
	TEST_ASSERT_EQUAL(accepted, HAI_VOICE_ANSWERS, "[accepted] units answered a shout that reaches [HAI_VOICE_ANSWERS]")

	// The words really do arrive when someone says them aloud
	sleep(1)
	mate_brain.voice_heard = list()
	mate_brain.cancel_order()
	commander.say("follow me")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(following), mate_brain), 5), "The command spoken aloud never reached the unit")

	TEST_ASSERT_EQUAL(mate_brain.error_total + other_brain.error_total, 0, "A brain threw errors")
	for(var/mob/living/carbon/human/extra in crowd)
		detach_human_ai(extra)
	detach_human_ai(mate)
	detach_human_ai(other)

/// A medic with a defibrillator brings a dead friend back when the body would take a shock, mends it first when it would not, and leaves it when it cannot
/datum/unit_test/human_ai_defibrillation
	var/mob/living/carbon/human/body

/datum/unit_test/human_ai_defibrillation/proc/revived()
	return body.stat != DEAD

/datum/unit_test/human_ai_defibrillation/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/datum/human_ai_arena/ward = new(list(
		"##############################",
		"#............................#",
		"#............................#",
		"#............................#",
		"##############################",
	), run_loc_floor_bottom_left)
	var/turf/start = locate(ward.origin_x + 3, ward.origin_y + 2, ward.z)
	var/mob/living/carbon/human/medic = make_soldier(start, FACTION_MARINE, FALSE, "professional")
	medic.skills.set_skill(SKILL_MEDICAL, SKILL_MEDICAL_MEDIC)
	var/obj/item/storage/backpack/bag = new(medic)
	dress(medic, bag, WEAR_BACK)
	var/obj/item/device/defibrillator/defib = new(bag)
	var/datum/human_ai_brain/doctor = medic.ai_brain
	doctor.set_role("medic")
	TEST_ASSERT(doctor.find_defibrillator(), "The medic does not see the defibrillator it carries")

	body = make_soldier(locate(start.x + 4, start.y, start.z), FACTION_MARINE, FALSE, "veteran")
	var/datum/human_ai_brain/before = body.ai_brain
	before.set_role("rifleman")
	body.death(create_cause_data("unit test"))
	TEST_ASSERT_EQUAL(body.stat, DEAD, "The test body is not dead")
	var/charge_before = defib.dcell.charge
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(revived)), 60), "The medic never brought the body back, tries [doctor.defib_tries]: [doctor.decision_log.Join(" | ")]")
	TEST_ASSERT(doctor.revives >= 1, "The revival was not counted")
	TEST_ASSERT(defib.dcell.charge < charge_before, "The defibrillator was not used")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(has_brain), body), 15), "The revived body never got its AI back")
	sleep(5 SECONDS)
	TEST_ASSERT(!istype(medic.get_active_hand(), /obj/item/device/defibrillator) && !istype(medic.get_inactive_hand(), /obj/item/device/defibrillator), "The medic kept the defibrillator in hand")
	TEST_ASSERT(!defib.ready, "The medic left the paddles out")

	// A body too far gone is not worth a shock and with nothing to mend it with it is left alone
	var/mob/living/carbon/human/ruin = make_soldier(locate(start.x + 6, start.y + 1, start.z), FACTION_MARINE, FALSE)
	for(var/part in list("chest", "groin", "l_leg", "r_leg", "l_arm", "r_arm"))
		ruin.apply_damage(60, BRUTE, part)
	ruin.death(create_cause_data("unit test"))
	ruin.updatehealth()
	var/mob/living/carbon/human/spare_medic = make_soldier(locate(start.x + 8, start.y + 1, start.z), FACTION_MARINE, FALSE, "professional")
	spare_medic.skills.set_skill(SKILL_MEDICAL, SKILL_MEDICAL_MEDIC)
	var/obj/item/storage/backpack/spare_bag = new(spare_medic)
	dress(spare_medic, spare_bag, WEAR_BACK)
	var/obj/item/device/defibrillator/spare_defib = new(spare_bag)
	spare_medic.ai_brain.set_role("medic")
	var/datum/human_ai_brain/other_doctor = spare_medic.ai_brain
	TEST_ASSERT(other_doctor.defib_outlook(ruin, spare_defib) <= HEALTH_THRESHOLD_DEAD + HAI_DEFIB_MARGIN, "The setup body at [ruin.health] health is not past saving")
	var/spare_charge = spare_defib.dcell.charge
	sleep(10 SECONDS)
	TEST_ASSERT_EQUAL(ruin.stat, DEAD, "A body that could not take a shock came back")
	TEST_ASSERT_EQUAL(other_doctor.defib_tries, 0, "The medic shocked a body that could not be saved")
	TEST_ASSERT_EQUAL(spare_defib.dcell.charge, spare_charge, "The charge was spent on a body that could not be saved")
	TEST_ASSERT_EQUAL(doctor.error_total + other_doctor.error_total, 0, "A brain threw errors")
	detach_human_ai(medic)
	detach_human_ai(body)
	detach_human_ai(ruin)
	detach_human_ai(spare_medic)

/datum/unit_test/human_ai_defibrillation/proc/has_brain(mob/living/carbon/human/human)
	return !!human.ai_brain

/// A soldier who is no medic drags a downed friend out of the line of fire, when it is loyal enough
/datum/unit_test/human_ai_rescue
	var/datum/human_ai_brain/rescuer
	var/mob/living/carbon/human/casualty

/datum/unit_test/human_ai_rescue/proc/dragged_to_cover(turf/threat)
	return rescuer.cover_against(get_turf(casualty), threat) >= HAI_COVER_MIN_SCORE && rescuer.dragged >= 1

/datum/unit_test/human_ai_rescue/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/datum/human_ai_arena/fire = new(list(
		"####################################",
		"#..................................#",
		"#..................................#",
		"#..................................#",
		"#..................................#",
		"#..................................#",
		"#..................................#",
		"####################################",
	), run_loc_floor_bottom_left)
	var/turf/soldier_spot = locate(fire.origin_x + 6, fire.origin_y + 3, fire.z)
	var/turf/threat_turf = locate(fire.origin_x + 15, fire.origin_y + 3, fire.z)
	for(var/offset in -1 to 1)
		var/obj/structure/barricade/metal/cover = new(locate(fire.origin_x + 9, fire.origin_y + 3 + offset, fire.z))
		cover.setDir(EAST)
	var/mob/living/carbon/human/soldier = make_soldier(soldier_spot, FACTION_MARINE, FALSE, "professional")
	rescuer = soldier.ai_brain
	TEST_ASSERT(!rescuer.is_medic(), "The rescuer is a medic")
	var/mob/living/carbon/xenomorph/drone/shooter = make_target_dummy(threat_turf)
	casualty = allocate(/mob/living/carbon/human, locate(fire.origin_x + 7, fire.origin_y + 3, fire.z))
	casualty.faction = FACTION_MARINE
	SSspatial_grid.track(casualty, SPATIAL_GRID_TRACK_NPC)
	casualty.KnockOut(120)
	sleep(3 SECONDS)
	rescuer.set_target(shooter)
	for(var/tick in 1 to 4 * 40)
		rescuer.last_shot_at_time = world.time
		if(dragged_to_cover(threat_turf))
			break
		sleep(2.5)
	TEST_ASSERT(dragged_to_cover(threat_turf), "The soldier did not drag the casualty to cover, casualty at [casualty.x],[casualty.y] stat [casualty.stat], dragged [rescuer.dragged], soldier at [soldier.x],[soldier.y], goal [rescuer.drag_goal_turf]: [rescuer.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(rescuer.error_total, 0, "The soldier's brain threw errors")
	qdel(shooter)
	detach_human_ai(soldier)

/// A unit sees what is behind a window, a pane of glass does not hide an enemy from it
/datum/unit_test/human_ai_window_sight
	var/datum/human_ai_brain/watcher
	var/mob/living/carbon/xenomorph/drone/enemy

/datum/unit_test/human_ai_window_sight/proc/spotted()
	return watcher.get_target() == enemy

/datum/unit_test/human_ai_window_sight/Run()
	var/datum/human_ai_arena/gallery = new(list(
		"###########",
		"#1..W....2#",
		"###########",
	), run_loc_floor_bottom_left)
	var/obj/structure/window/pane = locate(/obj/structure/window) in locate(gallery.origin_x + 4, gallery.origin_y + 1, gallery.z)
	TEST_ASSERT_NOTNULL(pane, "The test arena built no window")
	var/mob/living/carbon/human/soldier = make_soldier(gallery.mark("1"), FACTION_MARINE, FALSE)
	watcher = soldier.ai_brain
	soldier.setDir(EAST)
	enemy = make_target_dummy(gallery.mark("2"))
	SSspatial_grid.track(enemy, SPATIAL_GRID_TRACK_NPC)
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(spotted)), 25), "The unit never made out the enemy behind the window: [watcher.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(watcher.error_total, 0, "The unit's brain threw errors")
	detach_human_ai(soldier)

/// A soldier with restraints takes a downed enemy prisoner, believes an unarmed enemy who calls out that they give up, and takes it back if they pick up a gun
/datum/unit_test/human_ai_captives
	var/mob/living/carbon/human/captive

/datum/unit_test/human_ai_captives/proc/cuffed()
	return !!captive.handcuffed

/datum/unit_test/human_ai_captives/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/datum/human_ai_arena/yard = new(list(
		"##############################",
		"#............................#",
		"#............................#",
		"#............................#",
		"#............................#",
		"##############################",
	), run_loc_floor_bottom_left)
	var/turf/start = locate(yard.origin_x + 4, yard.origin_y + 2, yard.z)
	var/mob/living/carbon/human/soldier = make_soldier(start, FACTION_MARINE, FALSE, "friendly")
	var/datum/human_ai_brain/jailer = soldier.ai_brain
	var/obj/item/storage/backpack/bag = new(soldier)
	dress(soldier, bag, WEAR_BACK)
	new /obj/item/restraint/handcuffs(bag)
	TEST_ASSERT(jailer.find_cuffs(), "The soldier does not see its restraints")
	TEST_ASSERT(jailer.role?.id != "security", "The soldier is a guard")

	captive = allocate(/mob/living/carbon/human, locate(start.x + 5, start.y, start.z))
	captive.faction = FACTION_CLF
	SSspatial_grid.track(captive, SPATIAL_GRID_TRACK_NPC)
	captive.KnockOut(60)
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(cuffed)), 40), "The soldier did not take the downed enemy prisoner, prisoners [jailer.prisoners]: [jailer.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(jailer.get_disposition(captive), HAI_DISP_NEUTRAL, "A prisoner is still seen as a threat")

	// A zealot does not care that an enemy calls out that they give up, and is gone again before it can get at anyone
	var/mob/living/carbon/human/zealot = make_soldier(locate(start.x + 3, start.y + 2, start.z), FACTION_MARINE, FALSE, "zealot")
	var/mob/living/carbon/human/doomed = allocate(/mob/living/carbon/human, locate(start.x + 4, start.y + 2, start.z))
	doomed.faction = FACTION_CLF
	TEST_ASSERT(!zealot.ai_brain.overhear(doomed, "I surrender!"), "A zealot took a surrender")
	TEST_ASSERT_EQUAL(zealot.ai_brain.get_disposition(doomed), HAI_DISP_HOSTILE, "A zealot stopped fighting an enemy who called out")
	detach_human_ai(zealot)
	qdel(zealot)
	qdel(doomed)

	// An unarmed enemy who calls out that they give up is believed by a unit with some mercy
	var/mob/living/carbon/human/giver = allocate(/mob/living/carbon/human, locate(start.x + 2, start.y + 1, start.z))
	giver.faction = FACTION_CLF
	TEST_ASSERT_EQUAL(jailer.get_disposition(giver), HAI_DISP_HOSTILE, "An enemy is not hostile")
	var/obj/item/weapon/gun/rifle/m41a/rifle = new(giver)
	giver.put_in_hands(rifle)
	TEST_ASSERT(!jailer.overhear(giver, "I surrender!"), "A surrender was taken from an enemy holding a gun")
	giver.drop_held_item(rifle)
	TEST_ASSERT(jailer.overhear(giver, "I surrender, don't shoot!"), "A surrender was not taken from an unarmed enemy")
	TEST_ASSERT_EQUAL(jailer.get_disposition(giver), HAI_DISP_NEUTRAL, "The soldier still sees someone who gave up as a threat")
	TEST_ASSERT_EQUAL(jailer.surrenders_taken, 1, "The surrender was not counted")
	giver.put_in_hands(rifle)
	TEST_ASSERT_EQUAL(jailer.get_disposition(giver), HAI_DISP_HOSTILE, "Picking up a gun did not break the surrender")
	giver.drop_held_item(rifle)
	captive = giver
	jailer.next_prisoner_search = 0
	new /obj/item/restraint/handcuffs(bag)
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(cuffed)), 40), "The soldier did not cuff the enemy who gave up, it is [get_dist(soldier, giver)] tiles away, sees the prisoner as [jailer.find_prisoner()], carries cuffs [jailer.find_cuffs()], takes the surrender [jailer.accepts_surrender_of(giver)], regards them as [jailer.get_disposition(giver)], the enemy holds [giver.l_hand] and [giver.r_hand], intent [jailer.intent]: [jailer.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(jailer.error_total, 0, "The soldier's brain threw errors")
	detach_human_ai(soldier)

/// A sniper in a ghillie suit who has been told to hold rigs the suit up and lies in wait
/datum/unit_test/human_ai_camouflage
	var/obj/item/clothing/suit/storage/marine/ghillie/suit

/datum/unit_test/human_ai_camouflage/proc/hidden()
	return suit.camo_active

/datum/unit_test/human_ai_camouflage/Run()
	var/mob/living/carbon/human/sniper = make_soldier(run_loc_floor_bottom_left, FACTION_MARINE, FALSE)
	var/datum/human_ai_brain/brain = sniper.ai_brain
	dress(sniper, new /obj/item/clothing/under/marine(sniper), WEAR_BODY)
	suit = new(sniper)
	dress(sniper, suit, WEAR_JACKET)
	TEST_ASSERT(brain.worn_ghillie() == suit, "The unit does not know it wears a ghillie suit, it wears [sniper.wear_suit] over [sniper.w_uniform]")
	TEST_ASSERT(brain.can_use_ghillie(), "The unit does not know how to use the ghillie suit")
	var/datum/npc_order/hold/stay = new
	TEST_ASSERT(brain.give_order(stay), "The hold order was refused")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(hidden)), 25), "The unit never rigged its ghillie suit: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT(brain.camo_uses >= 1, "The use of the suit was not counted")
	TEST_ASSERT_EQUAL(brain.error_total, 0, "The unit's brain threw errors")
	detach_human_ai(sniper)
