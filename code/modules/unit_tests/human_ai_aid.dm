/// A medic knows how every man of its squad is doing wherever he is, so nobody has to be dragged over to it, and a man of the game's squad it is assigned to counts too
/datum/unit_test/human_ai_squad_aid
	var/mob/living/carbon/human/subject
	var/datum/human_ai_brain/doctor

/datum/unit_test/human_ai_squad_aid/proc/healed()
	var/obj/limb/arm = subject.get_limb("l_arm")
	var/obj/limb/burnt = subject.get_limb("r_leg")
	var/obj/limb/broken = subject.get_limb("l_leg")
	return !doctor.limb_needs_bandage(arm) && !doctor.limb_needs_salve(burnt) && (broken.status & LIMB_SPLINTED)

/datum/unit_test/human_ai_squad_aid/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/datum/human_ai_arena/ship = new(list(
		"########################################",
		"#..................#...................#",
		"#..................#...................#",
		"#..................D...................#",
		"#..................#...................#",
		"#..................#...................#",
		"########################################",
	), run_loc_floor_bottom_left)
	var/mob/living/carbon/human/medic = make_medic(locate(ship.origin_x + 3, ship.origin_y + 3, ship.z))
	TEST_ASSERT_NOTNULL(medic, "The medic took no brain")
	doctor = medic.ai_brain

	// A wounded man of another squad in another room is not known to the medic
	subject = make_casualty(locate(ship.origin_x + 34, ship.origin_y + 3, ship.z))
	var/mob/living/carbon/human/stranger = subject
	TEST_ASSERT(attach_human_ai(stranger), "The casualty took no brain")
	stranger.ai_brain.keep_awake = TRUE
	TEST_ASSERT(get_dist(medic, stranger) > HAI_MEDIC_RANGE, "The casualty is within the medic's sight")
	doctor.next_patient_search = 0
	TEST_ASSERT_NULL(doctor.find_patient(), "The medic found a patient of another squad that it cannot see")

	// The same man in its own squad is known, and the medic goes to him and treats him where he lies
	var/datum/human_ai_squad/team = create_human_ai_squad(list(medic, stranger), medic, "Aid Test")
	TEST_ASSERT_NOTNULL(team, "The squad was not made")
	doctor.next_patient_search = 0
	TEST_ASSERT(doctor.find_patient() == stranger, "The medic did not know about the wounded man of its squad")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(healed)), 100), "The medic never reached and treated the wounded man of its squad, it is at [medic.x],[medic.y] and treated [doctor.treatments]: [doctor.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(doctor.error_total, 0, "The medic's brain threw errors")
	team.disband()
	detach_human_ai(stranger)

	// A marine of the game squad the medic is assigned to counts as well, a player among them
	var/datum/squad/marine/alpha/game_squad = new
	medic.assigned_squad = game_squad
	var/mob/living/carbon/human/player_marine = make_casualty(locate(ship.origin_x + 30, ship.origin_y + 2, ship.z))
	TEST_ASSERT(!(player_marine in doctor.squad_mates()), "A marine of no squad was among the squad mates")
	game_squad.marines_list += player_marine
	TEST_ASSERT(player_marine in doctor.squad_mates(), "A marine of the medic's game squad was not among the squad mates")
	subject = player_marine
	doctor.next_patient_search = 0
	doctor.patient_skips = list()
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(healed)), 100), "The medic never treated the marine of its game squad, it is at [medic.x],[medic.y] and treated [doctor.treatments]: [doctor.decision_log.Join(" | ")]")
	medic.assigned_squad = null
	game_squad.marines_list -= player_marine
	qdel(game_squad)

	// Nothing leads to a man behind a wall, so the medic leaves him be and does not try at every step
	var/datum/human_ai_arena/vault = new(list(
		"############",
		"#....#.....#",
		"#....#.....#",
		"############",
	), run_loc_floor_bottom_left, 20, 40)
	medic.forceMove(locate(vault.origin_x + 2, vault.origin_y + 2, vault.z))
	var/mob/living/carbon/human/walled = make_casualty(locate(vault.origin_x + 8, vault.origin_y + 2, vault.z))
	TEST_ASSERT(attach_human_ai(walled), "The walled in casualty took no brain")
	var/datum/human_ai_squad/shut = create_human_ai_squad(list(medic, walled), medic, "Shut Test")
	doctor.next_patient_search = 0
	sleep(15 SECONDS)
	TEST_ASSERT(doctor.patient_skips[REF(walled)] > world.time - 20 SECONDS || get_dist(medic, walled) > 1, "The medic neither reached the man behind the wall nor gave him up")
	shut.disband()
	detach_human_ai(walled)
	detach_human_ai(medic)

/// A man with a bone broken and not splinted keeps still because moving on it makes him bleed inside, puts a splint on himself if he can and is splinted by a medic of his squad if not
/datum/unit_test/human_ai_fracture
	var/mob/living/carbon/human/subject
	var/obj/limb/bone

/datum/unit_test/human_ai_fracture/proc/splinted()
	return !!(bone.status & LIMB_SPLINTED)

/datum/unit_test/human_ai_fracture/proc/arrived(turf/goal)
	return get_dist(subject, goal) <= 2

/datum/unit_test/human_ai_fracture/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/datum/human_ai_arena/hall = new(list(
		"##############################",
		"#............................#",
		"#............................#",
		"#............................#",
		"##############################",
	), run_loc_floor_bottom_left)

	// With a splint in the bag: the leg is splinted before a step is taken, then the order is carried out
	subject = make_soldier(locate(hall.origin_x + 3, hall.origin_y + 2, hall.z), FACTION_MARINE, FALSE)
	var/obj/item/storage/backpack/bag = new(subject)
	dress(subject, bag, WEAR_BACK)
	new /obj/item/stack/medical/splint(bag)
	subject.ai_brain.med_cache = null
	bone = subject.get_limb("r_leg")
	bone.status |= LIMB_BROKEN
	TEST_ASSERT(subject.ai_brain.must_hold_still(), "A man with a broken leg may move")
	var/turf/start = get_turf(subject)
	var/turf/goal = locate(hall.origin_x + 25, hall.origin_y + 2, hall.z)
	var/datum/npc_order/move/go = new
	go.target_turf = goal
	TEST_ASSERT(subject.ai_brain.give_order(go), "A move command was refused")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(splinted)), 30), "The man never splinted his own leg: [subject.ai_brain.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(get_turf(subject), start, "The man walked on a broken leg before it was splinted")
	TEST_ASSERT(!subject.ai_brain.must_hold_still(), "The man still holds still with the leg splinted")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(arrived), goal), 60), "The man never went on after splinting his leg: [subject.ai_brain.decision_log.Join(" | ")]")
	detach_human_ai(subject)

	// A broken arm on the side of the active hand is splinted with the splint in the other
	subject = make_soldier(locate(hall.origin_x + 3, hall.origin_y + 3, hall.z), FACTION_MARINE, FALSE)
	var/obj/item/storage/backpack/arm_bag = new(subject)
	dress(subject, arm_bag, WEAR_BACK)
	new /obj/item/stack/medical/splint(arm_bag)
	subject.ai_brain.med_cache = null
	subject.hand = 0
	bone = subject.get_limb("r_arm")
	bone.status |= LIMB_BROKEN
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(splinted)), 30), "The man never splinted his own right arm: [subject.ai_brain.decision_log.Join(" | ")]")
	detach_human_ai(subject)

	// Without one he waits where he is, lying down, and a medic of his squad splints him and he goes on
	subject = make_soldier(locate(hall.origin_x + 3, hall.origin_y + 1, hall.z), FACTION_MARINE, FALSE)
	bone = subject.get_limb("l_leg")
	bone.status |= LIMB_BROKEN
	var/turf/waiting_at = get_turf(subject)
	var/datum/npc_order/move/leave = new
	leave.target_turf = goal
	TEST_ASSERT(subject.ai_brain.give_order(leave), "The second move command was refused")
	sleep(10 SECONDS)
	TEST_ASSERT_EQUAL(get_turf(subject), waiting_at, "The man with no splint walked on a broken leg")
	TEST_ASSERT(subject.ai_brain.holds_still > 0, "The man never held still for it")
	var/mob/living/carbon/human/medic = make_medic(locate(hall.origin_x + 20, hall.origin_y + 2, hall.z))
	var/datum/human_ai_squad/team = create_human_ai_squad(list(subject, medic), medic, "Splint Test")
	TEST_ASSERT_NOTNULL(team, "The squad was not made")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(splinted)), 60), "The medic never splinted the man: [medic.ai_brain.decision_log.Join(" | ")]")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(arrived), goal), 90), "The man never went on once he was splinted: [subject.ai_brain.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(subject.ai_brain.error_total, 0, "The man's brain threw errors")
	team.disband()
	detach_human_ai(subject)
	detach_human_ai(medic)

/// Everyone carries something to put on a wound and uses it on themselves before anything else, and a soldier with nothing to do stays where it is
/datum/unit_test/human_ai_first_aid
	var/mob/living/carbon/human/subject
	var/datum/human_ai_brain/patient

/datum/unit_test/human_ai_first_aid/proc/tended()
	var/obj/limb/arm = subject.get_limb("l_arm")
	return !patient.limb_needs_bandage(arm) && patient.treatments >= 1

/datum/unit_test/human_ai_first_aid/Run()
	var/datum/human_ai_arena/yard = new(list(
		"####################",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"####################",
	), run_loc_floor_bottom_left)
	subject = make_soldier(locate(yard.origin_x + 10, yard.origin_y + 2, yard.z), FACTION_MARINE, FALSE)
	patient = subject.ai_brain
	var/obj/item/storage/backpack/bag = new(subject)
	dress(subject, bag, WEAR_BACK)
	TEST_ASSERT(!length(patient.medical_supplies()[HAI_MED_BANDAGE]), "The soldier started with bandages")
	patient.issue_first_aid()
	patient.med_cache = null
	TEST_ASSERT(length(patient.medical_supplies()[HAI_MED_BANDAGE]), "The soldier got no bandages")
	TEST_ASSERT(length(patient.medical_supplies()[HAI_MED_SALVE]), "The soldier got no ointment")
	TEST_ASSERT(length(patient.medical_supplies()[HAI_MED_SPLINT]), "The soldier got no splints")
	patient.issue_first_aid()
	patient.med_cache = null
	TEST_ASSERT_EQUAL(length(patient.medical_supplies()[HAI_MED_BANDAGE]), 1, "Issuing first aid twice made a second set")

	// A civilian and a machine are not given any
	var/mob/living/carbon/human/civilian = make_soldier(locate(yard.origin_x + 4, yard.origin_y + 3, yard.z), FACTION_MARINE, FALSE)
	civilian.ai_brain.set_role("civilian")
	var/obj/item/storage/backpack/civilian_bag = new(civilian)
	dress(civilian, civilian_bag, WEAR_BACK)
	civilian.ai_brain.issue_first_aid()
	civilian.ai_brain.med_cache = null
	TEST_ASSERT(!length(civilian.ai_brain.medical_supplies()[HAI_MED_BANDAGE]), "A civilian was given first aid")
	detach_human_ai(civilian)

	// Wounded, it sees to itself, and meanwhile it does not take a stroll
	var/obj/limb/arm = subject.get_limb("l_arm")
	arm.take_damage(25, 0)
	subject.updatehealth()
	TEST_ASSERT(patient.is_hurt() || patient.patient_need(subject), "The soldier is not hurt and sees nothing to treat")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(tended)), 40), "The soldier never saw to its own wound: [patient.decision_log.Join(" | ")]")
	sleep(40 SECONDS)
	TEST_ASSERT_EQUAL(patient.idle_wanders, 0, "A soldier with nothing to do wandered off")
	TEST_ASSERT_EQUAL(patient.error_total, 0, "The soldier's brain threw errors")
	detach_human_ai(subject)

/// Somebody who was dead and is brought back goes and gets the armor he wore back on, and goes back to his squad
/datum/unit_test/human_ai_regear
	var/mob/living/carbon/human/subject
	var/obj/item/armor

/datum/unit_test/human_ai_regear/proc/armored()
	return subject.wear_suit == armor

/datum/unit_test/human_ai_regear/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/datum/human_ai_arena/ward = new(list(
		"####################",
		"#..................#",
		"#..................#",
		"#..................#",
		"####################",
	), run_loc_floor_bottom_left)
	subject = make_soldier(locate(ward.origin_x + 4, ward.origin_y + 2, ward.z), FACTION_MARINE, FALSE)
	subject.create_hud()
	dress(subject, new /obj/item/clothing/under/marine(subject), WEAR_BODY)
	armor = new /obj/item/clothing/suit/storage/marine(subject)
	dress(subject, armor, WEAR_JACKET)
	TEST_ASSERT_EQUAL(subject.wear_suit, armor, "The test marine did not put its armor on")
	var/mob/living/carbon/human/comrade = make_soldier(locate(ward.origin_x + 6, ward.origin_y + 2, ward.z), FACTION_MARINE, FALSE)
	var/datum/human_ai_squad/team = create_human_ai_squad(list(subject, comrade), comrade, "Regear Test")
	TEST_ASSERT_NOTNULL(team, "The squad was not made")
	var/datum/human_ai_squad/squad_before = team

	// It dies with its armor on, a medic takes the armor off and leaves it a few steps away, and it comes back
	detach_human_ai(subject, HAI_STOP_DEAD)
	var/list/memory = subject.human_ai_memory
	TEST_ASSERT_NOTNULL(memory, "Nothing was remembered of the dead man")
	TEST_ASSERT(length(memory["gear"]), "Nothing was remembered of what it wore")
	TEST_ASSERT(length(team.fallen), "The squad did not note the dead man")
	subject.drop_inv_item_on_ground(armor)
	armor.forceMove(locate(ward.origin_x + 9, ward.origin_y + 2, ward.z))
	TEST_ASSERT(!subject.wear_suit, "The armor is still on")
	TEST_ASSERT(reattach_human_ai_after_revive(subject), "The AI did not take the body back")
	TEST_ASSERT_NOTNULL(subject.ai_brain.regear_items, "The revived man did not remember what to put back on")
	TEST_ASSERT(subject.ai_brain.squad == squad_before, "The revived man did not rejoin his squad")
	subject.ai_brain.keep_awake = TRUE
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(armored)), 30), "The revived man never put his armor back on: [subject.ai_brain.decision_log.Join(" | ")]")
	TEST_ASSERT(subject.ai_brain.regeared >= 1, "The putting back on was not counted")
	TEST_ASSERT_EQUAL(subject.ai_brain.error_total, 0, "The revived man's brain threw errors")
	team.disband()
	detach_human_ai(subject)
	detach_human_ai(comrade)

/// A body that keeps dying again straight after it is shocked is left alone after a couple of tries, and a medic wants it mended further before every one
/datum/unit_test/human_ai_revive_limit

/datum/unit_test/human_ai_revive_limit/Run()
	var/mob/living/carbon/human/medic = make_medic(run_loc_floor_bottom_left)
	var/datum/human_ai_brain/doctor = medic.ai_brain
	var/mob/living/carbon/human/corpse = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(doctor.defib_margin(corpse), HAI_DEFIB_MARGIN, "A body never shocked has a bigger margin")
	GLOB.human_ai_revive_log[REF(corpse)] = list(1, world.time)
	TEST_ASSERT(doctor.defib_margin(corpse) > HAI_DEFIB_MARGIN, "A body that was just shocked back needs no more mending")
	GLOB.human_ai_revive_log[REF(corpse)] = list(HAI_REVIVE_LIMIT, world.time)
	corpse.stat = DEAD
	TEST_ASSERT(!doctor.will_revive(corpse), "A body that died again [HAI_REVIVE_LIMIT] times in a row was shocked again")
	GLOB.human_ai_revive_log[REF(corpse)] = list(HAI_REVIVE_LIMIT, world.time - HAI_REVIVE_WINDOW - 1)
	TEST_ASSERT_EQUAL(doctor.defib_margin(corpse), HAI_DEFIB_MARGIN, "An old revival still counts against a body")
	GLOB.human_ai_revive_log -= REF(corpse)
	// The claims on patients are kept in a global list, a brain that is gone must not be left in it
	GLOB.human_ai_patient_claims["aid test"] = list(doctor, world.time + 100)
	detach_human_ai(medic)
	TEST_ASSERT_NULL(GLOB.human_ai_patient_claims["aid test"], "A destroyed brain was left holding a claim")

	// What can no longer matter is taken out of the shared lists now and then, and what still can is left alone
	var/mob/living/carbon/human/other_medic = make_medic(run_loc_floor_bottom_left)
	var/datum/human_ai_brain/other_doctor = other_medic.ai_brain
	GLOB.human_ai_patient_claims["run out"] = list(other_doctor, world.time - 1)
	GLOB.human_ai_patient_claims["held"] = list(other_doctor, world.time + 100)
	GLOB.human_ai_revive_log["old"] = list(1, world.time - HAI_REVIVE_WINDOW - 1)
	GLOB.human_ai_revive_log["recent"] = list(1, world.time)
	human_ai_prune_globals()
	TEST_ASSERT_NULL(GLOB.human_ai_patient_claims["run out"], "A claim that ran out was kept")
	TEST_ASSERT_NOTNULL(GLOB.human_ai_patient_claims["held"], "A claim that still holds was dropped")
	TEST_ASSERT_NULL(GLOB.human_ai_revive_log["old"], "The shock count of a body past its window was kept")
	TEST_ASSERT_NOTNULL(GLOB.human_ai_revive_log["recent"], "The shock count of a body in its window was dropped")
	GLOB.human_ai_patient_claims -= "held"
	GLOB.human_ai_revive_log -= "recent"
	detach_human_ai(other_medic)

/// A hurt soldier that is being shot at from out of sight gets behind something, a sound one is not moved to, and neither of them takes a stroll
/datum/unit_test/human_ai_hurt_conduct
	var/mob/living/carbon/human/subject
	var/turf/threat_spot

/datum/unit_test/human_ai_hurt_conduct/proc/sheltered()
	return subject.ai_brain.in_good_cover(threat_spot) && get_dist(subject, threat_spot) > 1

/datum/unit_test/human_ai_hurt_conduct/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/datum/human_ai_arena/road = new(list(
		"####################",
		"#..................#",
		"#.....B............#",
		"#.....B............#",
		"#..................#",
		"####################",
	), run_loc_floor_bottom_left)
	threat_spot = locate(road.origin_x + 12, road.origin_y + 2, road.z)
	subject = make_soldier(locate(road.origin_x + 9, road.origin_y + 2, road.z), FACTION_MARINE, FALSE)
	var/datum/human_ai_brain/brain = subject.ai_brain
	// The shooter is somewhere it cannot be seen from, the unit only knows where he fired from
	var/mob/living/carbon/xenomorph/drone/shooter = make_target_dummy(locate(road.origin_x + 40, road.origin_y + 40, road.z))
	// It knows where the shots came from but cannot see him, and it is sound
	var/datum/ai_contact/contact = brain.ensure_contact(shooter, TRUE)
	contact.last_turf = threat_spot
	contact.last_time = world.time
	contact.notice = 1
	contact.confidence = 1
	brain.last_shot_at_time = world.time
	var/datum/human_ai_action/shelter_wounded/mover = new
	brain.set_intent(HAI_INTENT_ALERT, "test")
	TEST_ASSERT_EQUAL(mover.get_weight(brain), 0, "A sound unit was sent to cover")
	// Hurt, it goes
	subject.take_overall_damage(50)
	subject.updatehealth()
	TEST_ASSERT(brain.is_hurt(), "The unit is not hurt")
	TEST_ASSERT(mover.get_weight(brain) > 0, "A hurt unit being shot at was not sent to cover: cover [brain.cover_enabled], target [brain.get_target()], acting [brain.is_acting()], order [brain.current_order], threat [brain.threat_turf()], in cover [brain.in_good_cover(threat_spot)], goal [brain.cover_goal(threat_spot)], alert [brain.alert_until], shot [brain.last_shot_at_time], now [world.time]")
	qdel(mover)
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(sheltered)), 30), "The hurt unit never got behind cover: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(brain.idle_wanders, 0, "The hurt unit wandered")
	TEST_ASSERT_EQUAL(brain.error_total, 0, "The unit's brain threw errors")
	detach_human_ai(subject)
