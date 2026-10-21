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
	TEST_ASSERT_EQUAL(human_ai_voice_command("hold this area"), "hold_area", "Hold this area was not understood")
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

/// Real loadouts the way the NPC panel hands them out: the HUD first, then the whole preset
/datum/unit_test/proc/make_real_unit(turf/where, preset_type, personality = "neutral")
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human, where)
	human.create_hud()
	arm_equipment(human, preset_type, TRUE, FALSE)
	if(!attach_human_ai(human, personality))
		return null
	human.ai_brain.keep_awake = TRUE
	return human

/// What a unit carries and is doing, for the messages of the tests that use real loadouts
/datum/unit_test/proc/describe_unit(mob/living/carbon/human/human)
	var/datum/human_ai_brain/brain = human.ai_brain
	var/obj/item/weapon/gun/gun = brain.peek_gun()
	var/list/mags = list()
	for(var/obj/item/ammo_magazine/mag in human.get_contents())
		mags += "[mag.type] [mag.current_rounds]"
	var/list/supplies = brain.medical_supplies()
	return "[human.real_name] ([brain.role?.id]) hands [human.get_active_hand()] and [human.get_inactive_hand()], gun [gun] mag [gun?.current_mag?.current_rounds] chamber [!!gun?.in_chamber], spare ammo [brain.has_spare_ammo(gun)] mags [english_list(mags)], bandages [length(supplies[HAI_MED_BANDAGE])] salves [length(supplies[HAI_MED_SALVE])] splints [length(supplies[HAI_MED_SPLINT])] injectors [length(supplies[HAI_MED_INJECTOR])], treatments [brain.treatments], reloads [brain.reload_count], shots [brain.shots_fired], roe [brain.roe], intent [brain.intent], need [json_encode(brain.patient_need(human) ? list("yes") : list("no"))], log: [brain.decision_log.Join(" | ")]"

/// Units armed with the loadouts the game hands out draw their gun, and reload it when it runs dry
/datum/unit_test/human_ai_real_loadouts
	var/datum/human_ai_brain/shooter
	var/reloads_before = 0

/datum/unit_test/human_ai_real_loadouts/proc/drew()
	return !!shooter.peek_gun()

/datum/unit_test/human_ai_real_loadouts/proc/reloaded()
	return shooter.reload_count > reloads_before

/datum/unit_test/human_ai_real_loadouts/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/list/problems = list()
	var/list/presets = list(
		/datum/equipment_preset/uscm/private_equipped,
		/datum/equipment_preset/uscm/smartgunner_equipped,
		/datum/equipment_preset/clf/soldier,
		/datum/equipment_preset/pmc/pmc_standard,
		/datum/equipment_preset/upp/soldier/dressed,
		/datum/equipment_preset/survivor/clf,
	)
	for(var/preset in presets)
		var/datum/human_ai_arena/yard = new(list(
			"##############################",
			"#............................#",
			"#............................#",
			"#............................#",
			"#............................#",
			"##############################",
		), run_loc_floor_bottom_left)
		var/turf/start = locate(yard.origin_x + 4, yard.origin_y + 2, yard.z)
		var/mob/living/carbon/human/unit = make_real_unit(start, preset)
		if(!unit)
			problems += "[preset]: took no brain"
			continue
		shooter = unit.ai_brain
		var/mob/living/carbon/xenomorph/drone/dummy = make_target_dummy(locate(start.x + 6, start.y, start.z))
		SSspatial_grid.track(dummy, SPATIAL_GRID_TRACK_NPC)
		var/drawn = ai_wait(CALLBACK(src, PROC_REF(drew)), 30)
		var/obj/item/weapon/gun/gun = shooter.peek_gun()
		if(!drawn || !gun)
			problems += "[preset]: never drew a gun: [describe_unit(unit)]"
		else if(!gun.current_mag)
			problems += "[preset]: [gun] has no magazine to run dry"
		else
			reloads_before = shooter.reload_count
			gun.current_mag.current_rounds = 1
			if(!ai_wait(CALLBACK(src, PROC_REF(reloaded)), 40))
				problems += "[preset]: never reloaded [gun]: [describe_unit(unit)]"
		detach_human_ai(unit)
		qdel(unit)
		qdel(dummy)
	TEST_ASSERT(!length(problems), "[length(problems)] loadouts failed:\n[problems.Join("\n")]")

/// Units armed as medics are medics, treat their own wounds and other people's, and bring the dead back
/datum/unit_test/human_ai_real_medics
	var/datum/human_ai_brain/doctor
	var/mob/living/carbon/human/patient

/datum/unit_test/human_ai_real_medics/proc/treated(count)
	return doctor.treatments >= count

/datum/unit_test/human_ai_real_medics/proc/patched()
	return !doctor.limb_needs_bandage(patient.get_limb("chest"))

/datum/unit_test/human_ai_real_medics/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	TEST_ASSERT_EQUAL(human_ai_role_for_job("Hospital Corpsman"), "medic", "A corpsman is not a medic")
	TEST_ASSERT_EQUAL(human_ai_role_for_job("PMC Corporate Medic"), "medic", "A PMC medic is not a medic")
	TEST_ASSERT_EQUAL(human_ai_role_for_job("CLF Field Medic"), "medic", "A CLF medic is not a medic")
	TEST_ASSERT_EQUAL(human_ai_role_for_job("Combat Technician"), "engineer", "A combat technician is not an engineer")
	TEST_ASSERT_EQUAL(human_ai_role_for_job("Military Police"), "security", "A military policeman is not security")
	TEST_ASSERT_NULL(human_ai_role_for_job("Squad Rifleman"), "A rifleman got a role")
	TEST_ASSERT_NULL(human_ai_role_for_job("Cargo Technician"), "A cargo technician got a role")
	TEST_ASSERT_NULL(human_ai_role_for_job(null), "No job got a role")
	var/datum/human_ai_arena/yard = new(list(
		"##############################",
		"#............................#",
		"#............................#",
		"#............................#",
		"#............................#",
		"##############################",
	), run_loc_floor_bottom_left)
	var/turf/start = locate(yard.origin_x + 4, yard.origin_y + 2, yard.z)
	var/mob/living/carbon/human/corpsman = make_real_unit(start, /datum/equipment_preset/uscm/medic_equipped)
	TEST_ASSERT_NOTNULL(corpsman, "The corpsman took no brain")
	doctor = corpsman.ai_brain
	TEST_ASSERT(doctor.is_medic(), "The corpsman was given the role [doctor.role?.id] and not medic: [describe_unit(corpsman)]")

	// Its own wounds
	var/obj/limb/arm = corpsman.get_limb("l_arm")
	arm.take_damage(25, 0)
	var/obj/limb/leg = corpsman.get_limb("r_leg")
	leg.take_damage(0, 20)
	corpsman.updatehealth()
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(treated), 1), 45), "The corpsman never treated its own wounds: [describe_unit(corpsman)]")

	// Somebody else's
	patient = make_real_unit(locate(start.x + 3, start.y + 1, start.z), /datum/equipment_preset/uscm/private_equipped)
	SSspatial_grid.track(patient, SPATIAL_GRID_TRACK_NPC)
	var/obj/limb/chest = patient.get_limb("chest")
	chest.take_damage(30, 0)
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(patched)), 60), "The corpsman never bandaged a wounded rifleman: [describe_unit(corpsman)] // patient [describe_unit(patient)]")

	// A rifleman with the same supplies is no medic but still tends its own wounds
	var/mob/living/carbon/human/rifleman = make_real_unit(locate(start.x + 8, start.y + 2, start.z), /datum/equipment_preset/uscm/private_equipped)
	var/datum/human_ai_brain/trooper = rifleman.ai_brain
	TEST_ASSERT(!trooper.is_medic(), "A rifleman was given the medic role")
	var/obj/limb/torso = rifleman.get_limb("chest")
	torso.take_damage(25, 0)
	rifleman.updatehealth()
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(self_treated), trooper), 60), "A wounded rifleman never tended its own wounds: [describe_unit(rifleman)]")

	// The dead are brought back
	var/mob/living/carbon/human/casualty = make_real_unit(locate(start.x + 6, start.y + 1, start.z), /datum/equipment_preset/uscm/private_equipped)
	casualty.death(create_cause_data("unit test"))
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(back_up), casualty), 90), "The corpsman never brought a dead rifleman back: [describe_unit(corpsman)]")
	TEST_ASSERT_EQUAL(doctor.error_total, 0, "The corpsman's brain threw errors")
	detach_human_ai(corpsman)
	detach_human_ai(patient)
	detach_human_ai(rifleman)
	detach_human_ai(casualty)

/datum/unit_test/human_ai_real_medics/proc/self_treated(datum/human_ai_brain/trooper)
	return trooper.treatments >= 1

/datum/unit_test/human_ai_real_medics/proc/back_up(mob/living/carbon/human/casualty)
	return casualty.stat != DEAD

/// A goal on another level is reached by walking to the ladder that leads there and climbing it, and given up on when no ladder does
/datum/unit_test/human_ai_ladders

/datum/unit_test/human_ai_ladders/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/turf/lower_reference = run_loc_floor_bottom_left
	var/other_z = (lower_reference.z == world.maxz) ? lower_reference.z - 1 : lower_reference.z + 1
	TEST_ASSERT(other_z >= 1 && other_z <= world.maxz, "The test world has no second level")
	var/turf/upper_reference = locate(1, 1, other_z)
	var/list/rows = list(
		"####################",
		"#..................#",
		"#..................#",
		"#..................#",
		"####################",
	)
	var/datum/human_ai_arena/lower = new(rows, lower_reference, 20, 20)
	var/datum/human_ai_arena/upper = new(rows, upper_reference, 20, 20)
	var/obj/structure/ladder/lower_ladder = allocate(/obj/structure/ladder, locate(lower.origin_x + 14, lower.origin_y + 2, lower_reference.z))
	var/obj/structure/ladder/upper_ladder = allocate(/obj/structure/ladder, locate(upper.origin_x + 14, upper.origin_y + 2, other_z))
	lower_ladder.height = 0
	upper_ladder.height = 1
	lower_ladder.up = upper_ladder
	upper_ladder.down = lower_ladder

	var/mob/living/carbon/human/climber = make_soldier(locate(lower.origin_x + 3, lower.origin_y + 2, lower_reference.z), FACTION_MARINE, FALSE)
	var/datum/human_ai_brain/brain = climber.ai_brain
	var/turf/goal = locate(upper.origin_x + 4, upper.origin_y + 2, other_z)
	var/list/route = brain.find_ladder_toward(other_z)
	TEST_ASSERT_NOTNULL(route, "No ladder was found toward the other level")
	TEST_ASSERT(route[1] == lower_ladder && route[2] == "up", "The wrong ladder was chosen: [route[1]] [route[2]]")
	var/datum/npc_order/move/go = new
	go.target_turf = goal
	TEST_ASSERT(brain.give_order(go), "A move command was refused")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(order_over), go), 60), "The order to the other level never ended, the unit is at [climber.x],[climber.y],[climber.z]: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(climber.z, other_z, "The unit did not reach the other level: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT(get_dist(climber, goal) <= 2, "The unit stopped [get_dist(climber, goal)] tiles short of the goal: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT(brain.ladders_climbed >= 1, "The climb was not counted")
	TEST_ASSERT_EQUAL(go.status, HAI_ORDER_DONE, "The order ended as [go.status]")
	detach_human_ai(climber)

	// With the ladder gone there is no way up, so the order is given up and the unit stays where it is
	lower_ladder.up = null
	upper_ladder.down = null
	var/mob/living/carbon/human/stuck = make_soldier(locate(lower.origin_x + 3, lower.origin_y + 2, lower_reference.z), FACTION_MARINE, FALSE)
	var/datum/npc_order/move/hopeless = new
	hopeless.target_turf = goal
	TEST_ASSERT(stuck.ai_brain.give_order(hopeless), "The second move command was refused")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(order_over), hopeless), 30), "The order to a level with no way there never ended: [stuck.ai_brain.decision_log.Join(" | ")]")
	TEST_ASSERT_NOTEQUAL(hopeless.status, HAI_ORDER_DONE, "An order to a level with no way there was done")
	TEST_ASSERT_EQUAL(stuck.z, lower_reference.z, "The unit left its level with no ladder to take")
	TEST_ASSERT_EQUAL(stuck.ai_brain.error_total, 0, "The unit's brain threw errors")
	detach_human_ai(stuck)

/// Units told to hold an area spread over it, take posts of their own and never leave it, whatever they fight
/datum/unit_test/human_ai_hold_area
	var/list/watched = list()

/datum/unit_test/human_ai_hold_area/proc/all_posted(list/brains)
	for(var/datum/human_ai_brain/brain as anything in brains)
		if(!brain.post_turf || get_turf(brain.body) != brain.post_turf)
			return FALSE
	return TRUE

/datum/unit_test/human_ai_hold_area/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/list/rows = list()
	var/wall = ""
	var/floor = "#"
	for(var/column in 1 to 50)
		wall += "#"
		if(column > 2)
			floor += "."
	floor += "#"
	rows += wall
	for(var/row in 1 to 9)
		rows += floor
	rows += wall
	var/datum/human_ai_arena/field = new(rows, run_loc_floor_bottom_left)
	var/turf/center = locate(field.origin_x + 25, field.origin_y + 5, field.z)
	var/list/soldiers = list()
	var/list/brains = list()
	for(var/index in 0 to 2)
		var/mob/living/carbon/human/soldier = make_soldier(locate(field.origin_x + 5, field.origin_y + 3 + index * 2, field.z), FACTION_MARINE, TRUE)
		soldiers += soldier
		brains += soldier.ai_brain
		var/datum/npc_order/hold_area/hold = new
		hold.target_turf = center
		TEST_ASSERT(soldier.ai_brain.give_order(hold), "A hold area order was refused: [hold.refuse_reason]")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(all_posted), brains), 60), "The units never all took their posts in the area")
	var/list/posts = list()
	for(var/datum/human_ai_brain/brain as anything in brains)
		TEST_ASSERT(get_dist(brain.post_turf, center) <= HAI_HOLD_AREA_RADIUS, "A post lies outside the area it was told to hold")
		TEST_ASSERT(!(brain.post_turf in posts), "Two units took the same post")
		posts += brain.post_turf

	// Nothing takes them out of the area, not a goal outside it and not an enemy outside it
	var/datum/human_ai_brain/first = brains[1]
	var/turf/outside = locate(field.origin_x + 45, field.origin_y + 5, field.z)
	TEST_ASSERT(!first.move_to(outside, 0, FALSE), "A unit held to an area agreed to walk out of it")
	var/mob/living/carbon/xenomorph/drone/enemy = make_target_dummy(locate(field.origin_x + 40, field.origin_y + 5, field.z))
	SSspatial_grid.track(enemy, SPATIAL_GRID_TRACK_NPC)
	var/strays = 0
	for(var/tick in 1 to 4 * 25)
		for(var/mob/living/carbon/human/soldier as anything in soldiers)
			if(get_dist(soldier, center) > HAI_HOLD_AREA_RADIUS)
				strays++
		sleep(2.5)
	TEST_ASSERT_EQUAL(strays, 0, "Units left the area they were told to hold [strays] times: [first.decision_log.Join(" | ")]")

	// Letting them go lets them go
	for(var/datum/human_ai_brain/brain as anything in brains)
		brain.cancel_order()
		TEST_ASSERT_NULL(brain.leash_center, "A unit is still held to an area after the order ended")
		TEST_ASSERT_EQUAL(brain.error_total, 0, "A brain threw errors")
	for(var/mob/living/carbon/human/soldier as anything in soldiers)
		detach_human_ai(soldier)
	qdel(enemy)

/// A call-out says where the enemy is by the solid things next to it
/datum/unit_test/human_ai_callouts

/datum/unit_test/human_ai_callouts/Run()
	SShuman_ai.record_talk = TRUE
	SShuman_ai.talk_log = list()
	SShuman_ai.talk_window_end = 0
	GLOB.human_ai_backup_radio = list()
	var/datum/human_ai_arena/yard = new(list(
		"##############################",
		"#............................#",
		"#.................T..........#",
		"#............................#",
		"##############################",
	), run_loc_floor_bottom_left)
	var/turf/start = locate(yard.origin_x + 3, yard.origin_y + 2, yard.z)
	var/mob/living/carbon/human/soldier = make_soldier(start, FACTION_MARINE, FALSE)
	var/datum/human_ai_brain/brain = soldier.ai_brain
	var/mob/living/carbon/xenomorph/drone/hiding = make_target_dummy(locate(yard.origin_x + 19, yard.origin_y + 2, yard.z))
	var/mob/living/carbon/xenomorph/drone/open = make_target_dummy(locate(yard.origin_x + 12, yard.origin_y + 1, yard.z))
	TEST_ASSERT_NOTNULL(brain.describe_spot(hiding), "Nothing was named next to an enemy standing by a table")
	TEST_ASSERT(findtext(brain.describe_spot(hiding), "behind the") && findtext(brain.describe_spot(hiding), "table"), "The enemy past the table was placed as [brain.describe_spot(hiding)]")
	TEST_ASSERT_NULL(brain.describe_spot(open), "Something was named next to an enemy in the open: [brain.describe_spot(open)]")
	TEST_ASSERT_EQUAL(human_ai_add_callout("Contact east!", "by the crate"), "Contact east by the crate!", "A call-out was put together wrongly")
	TEST_ASSERT_EQUAL(human_ai_add_callout("Contact east", "by the crate"), "Contact east by the crate", "A call-out without a mark was put together wrongly")

	// What it says when it sees it
	brain.next_backup_call = 0
	brain.announce_contact(hiding)
	var/said
	for(var/list/entry in SShuman_ai.talk_log)
		said = entry[4]
	TEST_ASSERT_NOTNULL(said, "The contact was not called out")
	TEST_ASSERT(findtext(said, "table"), "The call-out does not say where the enemy is: [said]")
	SShuman_ai.record_talk = FALSE
	TEST_ASSERT_EQUAL(brain.error_total, 0, "The brain threw errors")
	detach_human_ai(soldier)

/// A cell for the tests that take prisoners to one
/area/human_ai_test_cells
	name = "Test Holding Cells"

/// An officer who cuffs a man takes him away to the cells and lets go of him there
/datum/unit_test/human_ai_prisoner_escort
	var/mob/living/carbon/human/suspect
	var/area/cells

/datum/unit_test/human_ai_prisoner_escort/proc/in_cells()
	return get_area(suspect) == cells

/datum/unit_test/human_ai_prisoner_escort/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/datum/human_ai_arena/hall = new(list(
		"##############################",
		"#............................#",
		"#............................#",
		"#............................#",
		"#............................#",
		"##############################",
	), run_loc_floor_bottom_left)
	cells = new /area/human_ai_test_cells
	for(var/dx in 24 to 27)
		for(var/dy in 1 to 3)
			var/turf/cell_turf = locate(hall.origin_x + dx, hall.origin_y + dy, hall.z)
			cells.contents += cell_turf
	var/turf/start = locate(hall.origin_x + 4, hall.origin_y + 2, hall.z)
	var/mob/living/carbon/human/officer = make_soldier(start, FACTION_MARSHAL, TRUE, "professional")
	var/datum/human_ai_brain/guard = officer.ai_brain
	guard.set_role("security")
	var/obj/item/storage/backpack/bag = new(officer)
	dress(officer, bag, WEAR_BACK)
	new /obj/item/restraint/handcuffs(bag)
	suspect = allocate(/mob/living/carbon/human, locate(start.x + 3, start.y, start.z))
	suspect.faction = FACTION_CLF
	SSspatial_grid.track(suspect, SPATIAL_GRID_TRACK_NPC)
	suspect.KnockOut(60)
	TEST_ASSERT_NOTNULL(guard.find_holding_turf(), "The officer sees no cell to take anyone to")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(in_cells)), 90), "The prisoner was never taken to the cells, he is at [suspect.x],[suspect.y] cuffed [!!suspect.handcuffed]: [guard.decision_log.Join(" | ")]")
	TEST_ASSERT(suspect.handcuffed, "The man in the cells is not cuffed")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(let_go), guard), 20), "The officer never let go of the prisoner: [guard.decision_log.Join(" | ")]")
	TEST_ASSERT(guard.prisoners_delivered >= 1, "The delivery was not counted")
	TEST_ASSERT_EQUAL(guard.error_total, 0, "The officer's brain threw errors")
	detach_human_ai(officer)
	qdel(cells)

/datum/unit_test/human_ai_prisoner_escort/proc/let_go(datum/human_ai_brain/guard)
	return !guard.body.pulling && guard.prisoners_delivered >= 1

/// Classes fight in their own way: the rusher closes on the enemy where a rifleman stands off, the stealth unit waits until the enemy is close, the suicider arms a grenade and the flanker is picked for the side route
/datum/unit_test/human_ai_classes
	var/datum/human_ai_brain/subject
	var/mob/living/carbon/xenomorph/drone/enemy

/datum/unit_test/human_ai_classes/proc/saw_enemy()
	return subject.get_target() == enemy

/datum/unit_test/human_ai_classes/proc/fired()
	return subject.shots_fired >= 1

/datum/unit_test/human_ai_classes/proc/primed()
	return subject.charges_primed >= 1

/datum/unit_test/human_ai_classes/proc/arena()
	var/list/rows = list()
	var/wall = ""
	var/floor = "#"
	for(var/column in 1 to 40)
		wall += "#"
		if(column > 2)
			floor += "."
	floor += "#"
	rows += wall
	for(var/row in 1 to 3)
		rows += floor
	rows += wall
	return new /datum/human_ai_arena(rows, run_loc_floor_bottom_left)

/datum/unit_test/human_ai_classes/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	TEST_ASSERT_NOTNULL(GLOB.human_ai_roles["rusher"], "There is no rusher role")
	TEST_ASSERT_NOTNULL(GLOB.human_ai_roles["flanker"], "There is no flanker role")
	TEST_ASSERT_NOTNULL(GLOB.human_ai_roles["stealth"], "There is no stealth role")
	TEST_ASSERT_NOTNULL(GLOB.human_ai_roles["suicider"], "There is no suicider role")

	// The rusher goes right up to the enemy and the rifleman stops where it can shoot from
	for(var/role_id in list("rifleman", "rusher"))
		var/datum/human_ai_arena/field = arena()
		var/mob/living/carbon/human/soldier = make_soldier(locate(field.origin_x + 3, field.origin_y + 2, field.z), FACTION_MARINE, TRUE)
		subject = soldier.ai_brain
		subject.set_role(role_id)
		enemy = make_target_dummy(locate(field.origin_x + 9, field.origin_y + 2, field.z))
		SSspatial_grid.track(enemy, SPATIAL_GRID_TRACK_NPC)
		// The rifleman is looked at while it still has rounds to shoot, once its magazine is empty it walks up to the enemy like anyone else
		sleep(10 SECONDS)
		if(role_id == "rusher")
			TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(near_turf), soldier, get_turf(enemy), 3), 20), "The rusher stood off at [get_dist(soldier, enemy)] tiles: [subject.decision_log.Join(" | ")]")
		else
			TEST_ASSERT(get_dist(soldier, enemy) >= 4, "The rifleman walked right up to the enemy, [get_dist(soldier, enemy)] tiles: [subject.decision_log.Join(" | ")]")
		detach_human_ai(soldier)
		qdel(soldier)
		qdel(enemy)

	// The stealth unit sees the enemy and holds its fire until the enemy comes close
	var/datum/human_ai_arena/hide = arena()
	var/mob/living/carbon/human/ambusher = make_soldier(locate(hide.origin_x + 3, hide.origin_y + 2, hide.z), FACTION_MARINE, TRUE)
	subject = ambusher.ai_brain
	subject.set_role("stealth")
	enemy = make_target_dummy(locate(hide.origin_x + 3 + HAI_AMBUSH_RANGE + 1, hide.origin_y + 2, hide.z))
	SSspatial_grid.track(enemy, SPATIAL_GRID_TRACK_NPC)
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(saw_enemy)), 45), "The stealth unit never saw the enemy: [subject.decision_log.Join(" | ")]")
	sleep(8 SECONDS)
	TEST_ASSERT_EQUAL(subject.shots_fired, 0, "The stealth unit fired at an enemy that was still far off: [subject.decision_log.Join(" | ")]")
	enemy.forceMove(locate(ambusher.x + 4, ambusher.y, ambusher.z))
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(fired)), 25), "The stealth unit never fired once the enemy was close: [subject.decision_log.Join(" | ")]")
	detach_human_ai(ambusher)
	qdel(ambusher)
	qdel(enemy)

	// The suicider arms its grenade when the enemy is near enough, and not with a friend beside it
	var/datum/human_ai_arena/blast = arena()
	var/mob/living/carbon/human/bomber = make_soldier(locate(blast.origin_x + 3, blast.origin_y + 2, blast.z), FACTION_MARINE, FALSE)
	subject = bomber.ai_brain
	subject.set_role("suicider")
	var/obj/item/explosive/grenade/high_explosive/frag/charge = new(bomber)
	charge.det_time = 600
	var/mob/living/carbon/human/friend = make_soldier(locate(blast.origin_x + 4, blast.origin_y + 3, blast.z), FACTION_MARINE, FALSE)
	enemy = make_target_dummy(locate(blast.origin_x + 3 + HAI_BOMBER_RANGE - 1, blast.origin_y + 2, blast.z))
	SSspatial_grid.track(enemy, SPATIAL_GRID_TRACK_NPC)
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(saw_enemy)), 45), "The suicider never saw the enemy: [subject.decision_log.Join(" | ")]")
	sleep(5 SECONDS)
	TEST_ASSERT_EQUAL(subject.charges_primed, 0, "The suicider armed a grenade with a friend beside it")
	detach_human_ai(friend)
	qdel(friend)
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(primed)), 25), "The suicider never armed its grenade: [subject.decision_log.Join(" | ")]")
	TEST_ASSERT(charge.active, "The grenade is not armed")
	qdel(charge)
	detach_human_ai(bomber)
	qdel(bomber)
	qdel(enemy)

	// The flanker is the one a squad picks for the side route
	var/mob/living/carbon/human/plain = make_soldier(run_loc_floor_bottom_left, FACTION_MARINE, FALSE)
	var/mob/living/carbon/human/runner = make_soldier(run_loc_floor_bottom_left, FACTION_MARINE, FALSE)
	runner.ai_brain.set_role("flanker")
	TEST_ASSERT(runner.ai_brain.flank_willingness() >= plain.ai_brain.flank_willingness() + 0.5, "A flanker is hardly more willing to flank than anyone else")
	var/datum/human_ai_squad/team = create_human_ai_squad(list(plain, runner), plain, "Class Test")
	var/list/ordered = team.flankers_first(list(plain.ai_brain, runner.ai_brain))
	TEST_ASSERT(ordered[1] == runner.ai_brain, "The flanker was not put first")
	team.disband()
	detach_human_ai(plain)
	detach_human_ai(runner)

/// An insurgent with a charge blows the bolted door it cannot hack and goes through, a marine with the same charge leaves the door alone
/datum/unit_test/human_ai_forced_entry
	var/datum/human_ai_brain/raider
	var/obj/structure/machinery/door/airlock/gate

/datum/unit_test/human_ai_forced_entry/proc/gate_gone()
	return QDELETED(gate) || !gate.density

/datum/unit_test/human_ai_forced_entry/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	for(var/faction in list(FACTION_MARINE, FACTION_CLF))
		var/datum/human_ai_arena/block = new(list(
			"####################",
			"#..........#.......#",
			"#..........#.......#",
			"#..........L.......#",
			"#..........#.......#",
			"#..........#.......#",
			"####################",
		), run_loc_floor_bottom_left)
		gate = block.first_door("L")
		var/turf/beyond = locate(block.origin_x + 15, block.origin_y + 3, block.z)
		var/mob/living/carbon/human/unit = make_soldier(locate(block.origin_x + 3, block.origin_y + 3, block.z), faction, FALSE)
		raider = unit.ai_brain
		var/obj/item/storage/backpack/bag = new(unit)
		dress(unit, bag, WEAR_BACK)
		new /obj/item/explosive/plastic(bag)
		TEST_ASSERT(raider.find_charge(), "The unit does not see the charge it carries")
		var/datum/npc_order/move/go = new
		go.target_turf = beyond
		TEST_ASSERT(raider.give_order(go), "A move command was refused")
		if(faction == FACTION_CLF)
			TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(gate_gone)), 70), "The insurgent never brought the door down: [raider.decision_log.Join(" | ")]")
			TEST_ASSERT(raider.charges_planted >= 1, "No charge was planted")
			TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(order_over), go), 40), "The insurgent never went through what was left of the door: [raider.decision_log.Join(" | ")]")
			TEST_ASSERT(get_dist(unit, beyond) <= 3, "The insurgent stopped [get_dist(unit, beyond)] tiles short of the goal")
			TEST_ASSERT(raider.forced_doors >= 1, "The forced door was not counted")
		else
			sleep(25 SECONDS)
			TEST_ASSERT_EQUAL(raider.charges_planted, 0, "A marine blew up a door of its own side")
			TEST_ASSERT(!gate_gone(), "The marine got through a bolted door")
		TEST_ASSERT_EQUAL(raider.error_total, 0, "The unit's brain threw errors")
		detach_human_ai(unit)
		qdel(unit)

/// A unit with a breaching hammer takes a wall down with it when told to demolish it
/datum/unit_test/human_ai_hammer
	var/turf/wall_spot

/datum/unit_test/human_ai_hammer/proc/wall_gone()
	return !wall_spot.density

/datum/unit_test/human_ai_hammer/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/datum/human_ai_arena/vault = new(list(
		"####################",
		"#..................#",
		"#..................#",
		"#..................#",
		"####################",
	), run_loc_floor_bottom_left)
	wall_spot = locate(vault.origin_x + 10, vault.origin_y + 2, vault.z)
	wall_spot.ChangeTurf(/turf/closed/wall)
	var/mob/living/carbon/human/unit = make_soldier(locate(vault.origin_x + 5, vault.origin_y + 2, vault.z), FACTION_MARINE, FALSE)
	var/datum/human_ai_brain/brain = unit.ai_brain
	var/obj/item/weapon/twohanded/breacher/hammer = new(unit)
	var/datum/npc_order/demolish/knock = new
	knock.target_turf = wall_spot
	TEST_ASSERT(brain.find_breaching_hammer() == hammer, "The unit does not see its hammer")
	TEST_ASSERT(brain.give_order(knock), "The order to demolish a wall was refused: [knock.refuse_reason]")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(wall_gone)), 40), "The wall never came down, it is still [wall_spot.type]: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT(brain.walls_hammered >= 1, "The swing was not counted")
	TEST_ASSERT_EQUAL(brain.charges_planted, 0, "A charge was planted where a hammer was enough")
	TEST_ASSERT_EQUAL(brain.error_total, 0, "The unit's brain threw errors")
	detach_human_ai(unit)
	qdel(hammer)

/// A synthetic is calm and collected unless told otherwise, and mends its dents with a welder and its burns with cable and never with bandages
/datum/unit_test/human_ai_synthetics
	var/datum/human_ai_brain/machine
	var/obj/limb/dented
	var/obj/limb/scorched

/datum/unit_test/human_ai_synthetics/proc/mended()
	return dented.brute_dam < 25 && scorched.burn_dam < 20

/datum/unit_test/human_ai_synthetics/Run()
	var/mob/living/carbon/human/synth = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	synth.set_species(SYNTH_GEN_THREE)
	TEST_ASSERT(issynth(synth), "The test body is not a synthetic")
	TEST_ASSERT(attach_human_ai(synth), "The synthetic took no brain")
	machine = synth.ai_brain
	machine.keep_awake = TRUE
	TEST_ASSERT_EQUAL(machine.personality.id, "synthetic", "A synthetic got the nature [machine.personality.id]")
	TEST_ASSERT(machine.personality.trait("composure") >= 95 && machine.personality.trait("aggression") <= 30 && machine.personality.trait("paranoia") <= 20, "The synthetic nature is not calm")

	// A synthetic someone picked a nature for keeps it
	var/mob/living/carbon/human/chosen = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	chosen.set_species(SYNTH_GEN_THREE)
	TEST_ASSERT(attach_human_ai(chosen, "zealot"), "The second synthetic took no brain")
	TEST_ASSERT_EQUAL(chosen.ai_brain.personality.id, "zealot", "A chosen nature was overridden")
	detach_human_ai(chosen)

	// It carries what it needs to mend itself once it has somewhere to carry it
	var/obj/item/storage/backpack/bag = new(synth)
	dress(synth, bag, WEAR_BACK)
	machine.issue_repair_tools()
	var/list/supplies = machine.medical_supplies()
	TEST_ASSERT(length(supplies[HAI_MED_WELD]), "The synthetic has no welder")
	TEST_ASSERT(length(supplies[HAI_MED_CABLE]), "The synthetic has no cable")
	new /obj/item/stack/medical/bruise_pack(bag)
	machine.med_cache = null

	dented = synth.get_limb("l_arm")
	scorched = synth.get_limb("r_leg")
	TEST_ASSERT(dented.status & (LIMB_ROBOT|LIMB_SYNTHSKIN), "The synthetic's arm is a plain organic one")
	dented.take_damage(25, 0)
	scorched.take_damage(0, 20)
	synth.updatehealth()
	var/list/need = machine.patient_need(synth)
	TEST_ASSERT_NOTNULL(need, "The synthetic sees nothing wrong with itself")
	TEST_ASSERT(need[1] == HAI_MED_WELD || need[1] == HAI_MED_CABLE, "The synthetic would treat itself with [need[1]] and not with engineering tools")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(mended)), 90), "The synthetic never mended itself, repairs [machine.repairs], dents [dented.brute_dam], burns [scorched.burn_dam]: [machine.decision_log.Join(" | ")]")
	TEST_ASSERT(machine.repairs >= 2, "The mending was not counted")
	TEST_ASSERT_EQUAL(machine.error_total, 0, "The synthetic's brain threw errors")

	// A medic with only bandages has nothing to do for a machine
	var/mob/living/carbon/human/medic = make_soldier(locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z), FACTION_MARINE, FALSE)
	var/obj/item/storage/backpack/medic_bag = new(medic)
	dress(medic, medic_bag, WEAR_BACK)
	new /obj/item/stack/medical/bruise_pack(medic_bag)
	new /obj/item/stack/medical/ointment(medic_bag)
	medic.ai_brain.med_cache = null
	dented.take_damage(20, 0)
	TEST_ASSERT_NULL(medic.ai_brain.patient_need(synth), "A medic with bandages found a use for them on a machine")
	detach_human_ai(synth)
	detach_human_ai(medic)
