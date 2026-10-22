/// An armed unit fights with its gun at arm's length too: it does not punch while the gun is only waiting for its moment, and with an empty gun it takes up another instead
/datum/unit_test/human_ai_point_blank

/datum/unit_test/human_ai_point_blank/proc/action_of(action_id)
	for(var/datum/human_ai_action/action as anything in GLOB.human_ai_actions)
		if(action.id == action_id)
			return action
	return null

/datum/unit_test/human_ai_point_blank/Run()
	var/datum/human_ai_arena/field = new(list("############", "#..........#", "#..........#", "############"), run_loc_floor_bottom_left)
	var/mob/living/carbon/human/soldier = make_soldier(locate(field.origin_x + 3, field.origin_y + 1, field.z), FACTION_CLF, TRUE)
	var/datum/human_ai_brain/brain = soldier.ai_brain
	brain.action_pool = list()
	var/mob/living/carbon/human/enemy = allocate(/mob/living/carbon/human, locate(field.origin_x + 4, field.origin_y + 1, field.z))
	enemy.faction = FACTION_MARINE
	SSspatial_grid.track(enemy, SPATIAL_GRID_TRACK_NPC)
	var/datum/human_ai_action/melee = action_of("melee")
	var/datum/human_ai_action/switcher = action_of("switch_weapon")
	TEST_ASSERT_NOTNULL(melee, "There is no melee action")
	var/obj/item/weapon/gun/rifle = brain.peek_gun()
	TEST_ASSERT_NOTNULL(rifle, "The soldier has no gun in hand")
	brain.identify_now(enemy)
	brain.set_target(enemy)
	brain.set_intent(HAI_INTENT_ENGAGE)
	brain.target_seen_time = world.time
	TEST_ASSERT(brain.target_adjacent(), "The enemy is not at arm's length")

	// Taking stock of the enemy: nothing is shot and nothing is punched
	TEST_ASSERT(brain.reaction_until > world.time, "A new enemy drew no reaction time")
	TEST_ASSERT_EQUAL(melee.get_weight(brain), 0, "A unit with a rifle wanted to punch while it was taking stock of the enemy")

	// The reaction over, between two shots, still no punching
	brain.reaction_until = 0
	rifle.last_fired = world.time
	TEST_ASSERT_EQUAL(melee.get_weight(brain), 0, "A unit with a rifle wanted to punch between two shots")
	rifle.last_fired = 0
	TEST_ASSERT_EQUAL(melee.get_weight(brain), 0, "A unit with a rifle ready wanted to punch")

	// Close enemies are reacted to quicker
	brain.reaction_until = 0
	brain.start_reaction()
	var/near_delay = brain.reaction_until - world.time
	enemy.forceMove(locate(field.origin_x + 10, field.origin_y + 1, field.z))
	brain.reaction_until = 0
	brain.start_reaction()
	var/far_delay = brain.reaction_until - world.time
	TEST_ASSERT(near_delay < far_delay, "An enemy at arm's length drew a reaction of [near_delay] and one far away [far_delay]")
	enemy.forceMove(locate(field.origin_x + 4, field.origin_y + 1, field.z))
	brain.reaction_until = 0

	// An empty gun with the enemy on top of the unit: another gun is taken up, and without one it is fists
	var/obj/item/weapon/gun/pistol/m4a3/sidearm = new(soldier)
	TEST_ASSERT_NOTNULL(sidearm, "No sidearm")
	rifle.current_mag.current_rounds = 0
	rifle.in_chamber = null
	TEST_ASSERT_EQUAL(brain.weapon_state(rifle), HAI_WEAPON_EMPTY, "The rifle would not go empty for the test")
	brain.other_gun_check_time = 0
	TEST_ASSERT(brain.gun_unusable(rifle), "An empty gun with the enemy at arm's length was not given up")
	TEST_ASSERT(switcher.get_weight(brain) > melee.get_weight(brain), "An empty rifle with a loaded pistol to hand did not prefer the pistol to the fists: switch [switcher.get_weight(brain)] melee [melee.get_weight(brain)]")
	qdel(sidearm)
	brain.other_gun_check_time = 0
	brain.forget_spare_check()
	TEST_ASSERT_EQUAL(melee.get_weight(brain), 50, "A unit with nothing left to shoot did not fall back on its fists")
	TEST_ASSERT_EQUAL(brain.error_total, 0, "The brain threw errors")
	detach_human_ai(soldier)

/// A unit fires on the vehicles of the sides it fights, and on nobody else's, and does not waste a rifle on armor
/datum/unit_test/human_ai_vehicles

/datum/unit_test/human_ai_vehicles/Run()
	var/datum/human_ai_arena/field = new(list("########################", "#......................#", "#......................#", "#......................#", "#......................#", "#......................#", "########################"), run_loc_floor_bottom_left)
	var/mob/living/carbon/human/soldier = make_soldier(locate(field.origin_x + 2, field.origin_y + 3, field.z), FACTION_CLF, TRUE)
	var/datum/human_ai_brain/brain = soldier.ai_brain
	lookout_pool(brain, "attack_vehicle")
	brain.light_override = 1
	soldier.setDir(EAST)
	var/obj/vehicle/multitile/van/truck = allocate(/obj/vehicle/multitile/van, locate(field.origin_x + 9, field.origin_y + 3, field.z))
	TEST_ASSERT_NOTNULL(truck, "No vehicle was made")
	truck.vehicle_flags = VEHICLE_CLASS_WEAK
	TEST_ASSERT(truck in GLOB.all_multi_vehicles, "The vehicle is not on the list of vehicles")

	// Nobody's vehicle, a friend's and an ally's are left alone
	brain.next_vehicle_scan = 0
	TEST_ASSERT_NULL(brain.find_enemy_vehicle(), "A vehicle that belongs to nobody was taken for an enemy")
	truck.vehicle_faction = FACTION_CLF
	brain.next_vehicle_scan = 0
	TEST_ASSERT_NULL(brain.find_enemy_vehicle(), "A vehicle of the unit's own side was taken for an enemy")

	// An enemy's is found, and fired on until it is in a bad way
	truck.vehicle_faction = FACTION_MARINE
	TEST_ASSERT(brain.vehicle_is_enemy(truck), "A marine vehicle was not taken for an enemy by a CLF unit")
	brain.next_vehicle_scan = 0
	TEST_ASSERT_EQUAL(brain.find_enemy_vehicle(), truck, "An enemy vehicle in plain sight was not found")
	var/health_before = truck.health
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(hit_by), truck, health_before), 15), "The unit never fired on an enemy vehicle in plain sight, it fired [brain.shots_fired] shots: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT(brain.vehicle_shots > 0, "No shot was counted against the vehicle")

	// Armor is not worth a rifle, a launcher is
	truck.vehicle_flags = VEHICLE_CLASS_MEDIUM
	brain.next_vehicle_scan = 0
	TEST_ASSERT_NULL(brain.find_enemy_vehicle(), "A unit with a rifle went for an armored vehicle")
	var/obj/item/weapon/gun/launcher/rocket/m5/tube = new(soldier)
	TEST_ASSERT(brain.vehicle_worth_shooting(tube, truck), "A rocket launcher was not taken for something to use on armor")
	qdel(tube)

	// A wall in the way hides it, and so does the dark
	truck.vehicle_flags = VEHICLE_CLASS_WEAK
	var/turf/wall_spot = locate(field.origin_x + 6, field.origin_y + 3, field.z)
	wall_spot.ChangeTurf(/turf/closed/wall/almayer)
	brain.next_vehicle_scan = 0
	TEST_ASSERT_NULL(brain.find_enemy_vehicle(), "A vehicle behind a wall was found")
	wall_spot.ChangeTurf(/turf/open/floor)
	brain.light_override = 0
	brain.next_vehicle_scan = 0
	TEST_ASSERT_NULL(brain.find_enemy_vehicle(), "A vehicle in the dark beyond the reach of the unit's eyes was found")
	brain.light_override = 1

	// A man to shoot at comes first
	var/mob/living/carbon/human/enemy = allocate(/mob/living/carbon/human, locate(field.origin_x + 6, field.origin_y + 4, field.z))
	enemy.faction = FACTION_MARINE
	SSspatial_grid.track(enemy, SPATIAL_GRID_TRACK_NPC)
	brain.identify_now(enemy)
	brain.set_target(enemy)
	brain.target_seen_time = world.time
	brain.reaction_until = 0
	brain.next_vehicle_scan = 0
	var/datum/human_ai_action/attack_vehicle/shooter = new
	TEST_ASSERT_EQUAL(shooter.get_weight(brain), 0, "A unit with a man to shoot at turned on a vehicle")
	qdel(shooter)
	TEST_ASSERT_EQUAL(brain.error_total, 0, "The brain threw errors: [brain.decision_log.Join(" | ")]")
	detach_human_ai(soldier)

/datum/unit_test/human_ai_vehicles/proc/hit_by(obj/vehicle/multitile/truck, health_before)
	return truck.health < health_before
