/// Gives a human every skill a gun could ask for
/proc/human_ai_test_skills(mob/living/carbon/human/human)
	human.skills = new /datum/skills()
	human.skills.set_skill(SKILL_SPEC_WEAPONS, SKILL_SPEC_ALL)
	human.skills.set_skill(SKILL_FIREARMS, SKILL_FIREARMS_EXPERT)

/// A magazine, rocket, tank or handful that reloads the gun, made inside the pack
/proc/human_ai_test_spare_ammo(obj/item/weapon/gun/sample, obj/item/storage/pack)
	var/datum/human_ai_gun_appraisal/appraisal = get_human_ai_gun_appraisal(sample)
	switch(appraisal.feed)
		if(HAI_FEED_MAGAZINE, HAI_FEED_ROCKET, HAI_FEED_TANK)
			return new sample.current_mag.type(pack)
		if(HAI_FEED_INTERNAL)
			var/obj/item/ammo_magazine/handful/handful = new(pack)
			handful.generate_handful(sample.current_mag.default_ammo, sample.current_mag.caliber, sample.current_mag.max_rounds, sample.current_mag.max_rounds, sample.type)
			return handful
	return null

/// Every gun type is sorted into a family and a feed, has sane numbers and starts in a state the brain understands
/datum/unit_test/human_ai_gun_appraisal

/datum/unit_test/human_ai_gun_appraisal/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	var/datum/human_ai_brain/brain = new(human)
	var/list/problems = list()
	var/list/groups = list()
	var/count = 0
	for(var/gun_type in subtypesof(/obj/item/weapon/gun))
		var/obj/item/weapon/gun/gun = new gun_type(run_loc_floor_bottom_left)
		count++
		var/datum/human_ai_gun_appraisal/appraisal = get_human_ai_gun_appraisal(gun)
		groups["family [appraisal.family] feed [appraisal.feed]"]++
		if(appraisal.fire_delay < 1 || appraisal.ideal_range < 1 || appraisal.ideal_range > appraisal.max_range)
			problems += "[gun_type] has odd numbers: delay [appraisal.fire_delay], range [appraisal.ideal_range] to [appraisal.max_range]"
		if(!appraisal.can_semi && !appraisal.can_burst && !appraisal.can_auto)
			problems += "[gun_type] has no way to fire"
		if(appraisal.feed == HAI_FEED_NONE && (gun.flags_gun_features & GUN_INTERNAL_MAG))
			problems += "[gun_type] has an internal magazine but no feed"
		if(gun.current_mag && gun.current_mag.current_rounds > 0 && brain.weapon_state(gun) == HAI_WEAPON_EMPTY)
			problems += "[gun_type] starts loaded but reads as empty"
		if(brain.gun_capacity(gun) < 0)
			problems += "[gun_type] has a negative capacity"
		qdel(gun)
	qdel(brain)
	var/list/summary = list()
	for(var/group in groups)
		summary += "[group]: [groups[group]]"
	TEST_NOTICE(src, "[count] guns appraised, [summary.Join(", ")]")
	TEST_ASSERT(!length(problems), "[length(problems)] gun problems:\n[problems.Join("\n")]")

/// Every gun type can be shot once by a brain without a runtime, whatever the gun refuses for its own reasons
/datum/unit_test/human_ai_gun_sweep

/datum/unit_test/human_ai_gun_sweep/Run()
	var/datum/human_ai_arena/yard = new(list(
		"##########",
		"#........#",
		"#........#",
		"#........#",
		"##########",
	), run_loc_floor_bottom_left)
	var/turf/shooter_turf = locate(yard.origin_x + 2, yard.origin_y + 2, yard.z)
	var/turf/target_turf = locate(yard.origin_x + 7, yard.origin_y + 2, yard.z)
	var/mob/living/carbon/xenomorph/drone/dummy = allocate(/mob/living/carbon/xenomorph/drone, target_turf)
	dummy.maxHealth = 100000
	dummy.health = 100000
	var/list/problems = list()
	var/fired = 0
	var/count = 0
	for(var/gun_type in subtypesof(/obj/item/weapon/gun))
		// The plasma caster only exists as part of a bracer, one held by a plain human throws when it is dropped
		if(ispath(gun_type, /obj/item/weapon/gun/energy/yautja/plasma_caster))
			continue
		var/mob/living/carbon/human/human = new(shooter_turf)
		human_ai_test_skills(human)
		human.faction = FACTION_MARINE
		var/obj/item/weapon/gun/gun = new gun_type(human)
		human.put_in_hands(gun)
		var/datum/human_ai_brain/brain = new(human)
		count++
		gun.guaranteed_delay_time = 0
		gun.wield_time = 0
		gun.pull_time = 0
		try
			for(var/attempt in 1 to 3)
				gun.guaranteed_delay_time = 0
				gun.wield_time = 0
				gun.pull_time = 0
				if(brain.shoot(gun, dummy))
					fired++
					break
				brain.volley_pause_until = 0
				gun.last_fired = 0
			brain.weapon_state(gun)
			brain.find_spare_ammo(gun)
		catch(var/exception/error)
			problems += "[gun_type]: [error.name] at [error.file]:[error.line]"
		qdel(brain)
		qdel(human)
		qdel(gun)
		for(var/obj/projectile/bullet in world)
			qdel(bullet)
	TEST_NOTICE(src, "[fired] of [count] guns fired for the brain")
	TEST_ASSERT(fired >= count * 0.6, "Only [fired] of [count] guns fired")
	TEST_ASSERT(!length(problems), "[length(problems)] guns threw:\n[problems.Join("\n")]")

/// Empty guns of each feed are refilled by the brain's reload and cycle steps and then shoot
/datum/unit_test/human_ai_weapon_handling
	var/list/problems = list()

/datum/unit_test/human_ai_weapon_handling/proc/exercise(gun_type, turf/shooter_turf, atom/target)
	var/obj/item/weapon/gun/sample = new gun_type(run_loc_floor_bottom_left)
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human, shooter_turf)
	human_ai_test_skills(human)
	human.faction = FACTION_MARINE
	var/obj/item/storage/backpack/pack = new(human)
	human.put_in_back(pack)
	var/obj/item/ammo_magazine/spare = human_ai_test_spare_ammo(sample, pack)
	var/obj/item/weapon/gun/gun = new gun_type(human, TRUE)
	human.put_in_hands(gun)
	if(istype(gun, /obj/item/weapon/gun/smartgun))
		var/obj/item/weapon/gun/smartgun/smartgun = gun
		smartgun.requires_harness = FALSE
	var/datum/human_ai_brain/brain = new(human)
	var/label = "[gun_type]"
	var/ok = TRUE
	if(!spare)
		problems += "[label]: no spare ammunition could be made"
		ok = FALSE
	else if(brain.weapon_state(gun) != HAI_WEAPON_EMPTY)
		problems += "[label]: the empty gun reads as state [brain.weapon_state(gun)]"
		ok = FALSE
	else if(!brain.has_spare_ammo(gun))
		problems += "[label]: the brain did not find the spare ammunition"
		ok = FALSE
	if(ok)
		var/steps = 0
		while(steps++ < 80)
			brain.reload_until = min(brain.reload_until, world.time)
			if(!brain.reload_step(gun) && brain.reload_phase == HAI_RELOAD_NONE)
				break
		if(brain.reload_phase != HAI_RELOAD_NONE)
			problems += "[label]: the reload never finished"
		for(var/wait in 1 to 40)
			var/state = brain.weapon_state(gun)
			if(state == HAI_WEAPON_READY)
				break
			if(state == HAI_WEAPON_CYCLE)
				brain.next_cycle_time = 0
				brain.cycle_step(gun)
			else if(state == HAI_WEAPON_OPEN)
				brain.close_after_loading(gun, get_human_ai_gun_appraisal(gun))
			else if(state == HAI_WEAPON_SAFE)
				brain.release_safety(gun)
			else
				break
			sleep(4)
		if(brain.weapon_state(gun) != HAI_WEAPON_READY)
			problems += "[label]: not ready after the reload, state [brain.weapon_state(gun)] with [brain.gun_rounds(gun)] rounds"
		else
			var/rounds_before = brain.gun_rounds(gun)
			gun.guaranteed_delay_time = 0
			gun.wield_time = 0
			gun.pull_time = 0
			var/shot = FALSE
			for(var/attempt in 1 to 20)
				if(brain.shoot(gun, target))
					shot = TRUE
					break
				gun.last_fired = 0
				sleep(2)
			if(!shot)
				problems += "[label]: the refilled gun would not fire, rounds [rounds_before]"
	qdel(brain)
	qdel(sample)
	for(var/obj/projectile/bullet in world)
		qdel(bullet)

/datum/unit_test/human_ai_weapon_handling/Run()
	var/datum/human_ai_arena/yard = new(list(
		"##########",
		"#........#",
		"#........#",
		"#........#",
		"##########",
	), run_loc_floor_bottom_left)
	var/turf/shooter_turf = locate(yard.origin_x + 2, yard.origin_y + 2, yard.z)
	var/turf/target_turf = locate(yard.origin_x + 7, yard.origin_y + 2, yard.z)
	var/mob/living/carbon/xenomorph/drone/dummy = allocate(/mob/living/carbon/xenomorph/drone, target_turf)
	dummy.maxHealth = 100000
	dummy.health = 100000
	var/list/guns = list(
		/obj/item/weapon/gun/rifle/m41a,
		/obj/item/weapon/gun/pistol/m4a3,
		/obj/item/weapon/gun/pistol/highpower,
		/obj/item/weapon/gun/smg/m39,
		/obj/item/weapon/gun/shotgun/pump,
		/obj/item/weapon/gun/shotgun/combat,
		/obj/item/weapon/gun/shotgun/double,
		/obj/item/weapon/gun/revolver/m44,
		/obj/item/weapon/gun/lever_action/r4t,
		/obj/item/weapon/gun/boltaction,
		/obj/item/weapon/gun/launcher/rocket/m5,
		/obj/item/weapon/gun/flamer/m240,
		/obj/item/weapon/gun/m60,
		/obj/item/weapon/gun/smartgun,
	)
	for(var/gun_type in guns)
		exercise(gun_type, shooter_turf, dummy)
		for(var/mob/living/carbon/human/leftover in shooter_turf)
			qdel(leftover)
	TEST_ASSERT(!length(problems), "[length(problems)] weapon handling problems:\n[problems.Join("\n")]")

/// One armed brain per gun family shoots a tough dummy xeno and keeps its weapon working through reloads and cycling
/datum/unit_test/human_ai_gun_duels
	var/list/problems = list()
	var/list/results = list()

/datum/unit_test/human_ai_gun_duels/proc/duel(gun_type, datum/human_ai_arena/yard, seconds, distance = 6)
	var/turf/shooter_turf = locate(yard.origin_x + 2, yard.origin_y + 3, yard.z)
	var/turf/target_turf = locate(shooter_turf.x + distance, shooter_turf.y, yard.z)
	var/mob/living/carbon/xenomorph/drone/dummy = new(target_turf)
	dummy.maxHealth = 3000
	dummy.health = 3000
	SSspatial_grid.track(dummy, SPATIAL_GRID_TRACK_NPC)
	var/mob/living/carbon/human/shooter = new(shooter_turf)
	human_ai_test_skills(shooter)
	shooter.faction = FACTION_MARINE
	shooter.setDir(EAST)
	var/obj/item/storage/backpack/pack = new(shooter)
	shooter.put_in_back(pack)
	var/obj/item/weapon/gun/sample = new gun_type(run_loc_floor_bottom_left)
	human_ai_test_spare_ammo(sample, pack)
	human_ai_test_spare_ammo(sample, pack)
	qdel(sample)
	var/obj/item/weapon/gun/gun = new gun_type(shooter)
	shooter.put_in_hands(gun)
	if(istype(gun, /obj/item/weapon/gun/smartgun))
		var/obj/item/weapon/gun/smartgun/smartgun = gun
		smartgun.requires_harness = FALSE
	if(!attach_human_ai(shooter))
		problems += "[gun_type]: could not take a brain"
		return
	var/datum/human_ai_brain/brain = shooter.ai_brain
	brain.keep_awake = TRUE
	brain.suppress_error_log = TRUE
	sleep(seconds SECONDS)
	var/damage = dummy.maxHealth - dummy.health
	var/state = brain.weapon_state(gun)
	results += "[gun_type]: [round(damage)] damage in [seconds] s ([round(damage / seconds, 0.1)]/s), [brain.shots_fired] shots, [brain.reload_count] reloads, state [state]"
	if(brain.error_total)
		var/list/error_lines = list()
		for(var/entry in brain.decision_log)
			if(findtext(entry, "error:"))
				error_lines += entry
		problems += "[gun_type]: the brain threw [brain.error_total] errors: [error_lines.Join(" | ")]"
	if(!brain.shots_fired)
		problems += "[gun_type]: never fired, intent [brain.intent], state [state], target [brain.get_target()], blocked [brain.gun_blocked_until]"
	else if(damage <= 0)
		var/list/recent_decisions = brain.decision_log.Copy(max(1, length(brain.decision_log) - 8))
		problems += "[gun_type]: fired [brain.shots_fired] shots but did no damage, state [state], intent [brain.intent], reload phase [brain.reload_phase], last decisions [recent_decisions.Join(" | ")]"
	if(brain.shots_fired > 0 && state == HAI_WEAPON_EMPTY && brain.has_spare_ammo(gun) && brain.reload_phase == HAI_RELOAD_NONE)
		problems += "[gun_type]: sat empty beside spare ammunition"
	detach_human_ai(shooter)
	qdel(shooter)
	qdel(dummy)
	for(var/obj/projectile/bullet in world)
		qdel(bullet)

/datum/unit_test/human_ai_gun_duels/Run()
	var/datum/human_ai_arena/yard = new(list(
		"####################",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"####################",
	), run_loc_floor_bottom_left)
	var/list/guns = list(
		/obj/item/weapon/gun/pistol/m4a3,
		/obj/item/weapon/gun/pistol/highpower,
		/obj/item/weapon/gun/revolver/m44,
		/obj/item/weapon/gun/smg/m39,
		/obj/item/weapon/gun/rifle/m41a,
		/obj/item/weapon/gun/shotgun/pump,
		/obj/item/weapon/gun/shotgun/double,
		/obj/item/weapon/gun/lever_action/r4t,
		/obj/item/weapon/gun/boltaction,
		/obj/item/weapon/gun/m60,
		/obj/item/weapon/gun/smartgun,
		/obj/item/weapon/gun/launcher/rocket/m5,
		/obj/item/weapon/gun/flamer/m240,
	)
	for(var/gun_type in guns)
		duel(gun_type, yard, 16)
	TEST_NOTICE(src, "duels:\n[results.Join("\n")]")
	TEST_ASSERT(!length(problems), "[length(problems)] duel problems:\n[problems.Join("\n")]")

/// A brain with an empty primary and no spare ammunition draws the pistol it carries and fights with it
/datum/unit_test/human_ai_sidearm

/datum/unit_test/human_ai_sidearm/proc/hurt(mob/living/carbon/xenomorph/dummy)
	return dummy.health < dummy.maxHealth

/datum/unit_test/human_ai_sidearm/Run()
	var/datum/human_ai_arena/yard = new(list(
		"####################",
		"#..................#",
		"#..................#",
		"#..................#",
		"####################",
	), run_loc_floor_bottom_left)
	var/turf/shooter_turf = locate(yard.origin_x + 2, yard.origin_y + 2, yard.z)
	var/turf/target_turf = locate(shooter_turf.x + 5, shooter_turf.y, yard.z)
	var/mob/living/carbon/xenomorph/drone/dummy = allocate(/mob/living/carbon/xenomorph/drone, target_turf)
	dummy.maxHealth = 3000
	dummy.health = 3000
	SSspatial_grid.track(dummy, SPATIAL_GRID_TRACK_NPC)
	var/mob/living/carbon/human/shooter = allocate(/mob/living/carbon/human, shooter_turf)
	human_ai_test_skills(shooter)
	shooter.faction = FACTION_MARINE
	shooter.setDir(EAST)
	var/obj/item/storage/backpack/pack = new(shooter)
	shooter.put_in_back(pack)
	var/obj/item/weapon/gun/pistol/m4a3/pistol = new(pack)
	var/obj/item/weapon/gun/rifle/m41a/rifle = new(shooter, TRUE)
	shooter.put_in_hands(rifle)
	TEST_ASSERT(attach_human_ai(shooter), "The shooter took no brain")
	var/datum/human_ai_brain/brain = shooter.ai_brain
	brain.keep_awake = TRUE
	var/rounds_before = pistol.current_mag.current_rounds
	var/start_health = dummy.health
	var/start_max = dummy.maxHealth
	// Waits for the pistol to be fired, the dummy being scratched is checked once it has been
	var/waited = 0
	while(waited++ < 80 && pistol.current_mag.current_rounds >= rounds_before)
		sleep(2.5)
	sleep(2 SECONDS)
	TEST_ASSERT(brain.weapon_switches >= 1, "The brain never changed weapon, intent [brain.intent], rifle state [brain.weapon_state(rifle)], target [brain.get_target()], other [brain.find_other_gun(rifle)], errors [brain.error_total], log [brain.decision_log.Join(" | ")]")
	TEST_ASSERT(pistol.current_mag.current_rounds < rounds_before, "The pistol was never fired")
	TEST_ASSERT(dummy.health < dummy.maxHealth, "The pistol shots never hurt the dummy, health [dummy.health] of [dummy.maxHealth] and was [start_health] of [start_max] to begin with")
	TEST_ASSERT_EQUAL(brain.error_total, 0, "The brain threw errors")

/// Fire mode, aim error and reaction time follow the range, the stress and the movement of the shooter
/datum/unit_test/human_ai_fire_discipline

/datum/unit_test/human_ai_fire_discipline/Run()
	var/mob/living/carbon/human/shooter = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	var/obj/item/weapon/gun/rifle/m41a/rifle = new(shooter)
	shooter.put_in_hands(rifle)
	var/datum/human_ai_brain/brain = new(shooter)
	var/datum/human_ai_gun_appraisal/appraisal = get_human_ai_gun_appraisal(rifle)
	TEST_ASSERT_EQUAL(brain.pick_fire_mode(rifle, appraisal, 2), GUN_FIREMODE_AUTOMATIC, "A rifle should go automatic up close")
	TEST_ASSERT_EQUAL(brain.pick_fire_mode(rifle, appraisal, 5), GUN_FIREMODE_BURSTFIRE, "A rifle should burst at medium range")
	TEST_ASSERT_EQUAL(brain.pick_fire_mode(rifle, appraisal, 9), GUN_FIREMODE_SEMIAUTO, "A rifle should shoot single shots at long range")

	var/mob/living/carbon/xenomorph/drone/near = allocate(/mob/living/carbon/xenomorph/drone, locate(run_loc_floor_bottom_left.x + 1, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z))
	var/mob/living/carbon/xenomorph/drone/far = allocate(/mob/living/carbon/xenomorph/drone, locate(run_loc_floor_bottom_left.x + 4, run_loc_floor_bottom_left.y + 4, run_loc_floor_bottom_left.z))
	var/calm_near = brain.aim_error(near, rifle)
	var/calm_far = brain.aim_error(far, rifle)
	TEST_ASSERT(calm_far > calm_near, "Aim error should grow with distance, [calm_near] and [calm_far]")
	brain.stress = 80
	TEST_ASSERT(brain.aim_error(far, rifle) > calm_far, "Aim error should grow with stress")
	brain.stress = 0
	brain.last_shot_at_time = world.time
	TEST_ASSERT(brain.suppressed(), "A brain that was just shot at should count as suppressed")
	TEST_ASSERT(brain.aim_error(far, rifle) > calm_far, "Aim error should grow while being shot at")
	brain.last_shot_at_time = 0
	brain.move_state = HAI_MOVE_WALKING
	TEST_ASSERT(brain.aim_error(far, rifle) > calm_far, "Aim error should grow while walking")
	brain.move_state = HAI_MOVE_ARRIVED

	brain.last_shot_time = 0
	brain.set_target(far)
	TEST_ASSERT(brain.reaction_until > world.time, "A fresh target should cost the brain a reaction time")
	TEST_ASSERT(brain.reaction_until - world.time <= HAI_REACTION_TIME * 2, "The reaction time is far too long, [brain.reaction_until - world.time] ds")
	var/was = brain.reaction_until
	brain.last_shot_time = world.time
	brain.set_target(null)
	brain.set_target(near)
	TEST_ASSERT_EQUAL(brain.reaction_until, was, "A brain that is already shooting should not pause for a new target")
	qdel(brain)

/// Grenades are sorted by use, thrown at groups of enemies from a safe distance and never over friends
/datum/unit_test/human_ai_grenades

/datum/unit_test/human_ai_grenades/proc/thrown(datum/human_ai_brain/brain)
	return brain.grenades_thrown > 0

/datum/unit_test/human_ai_grenades/proc/make_scene(datum/human_ai_arena/yard, friendly_near)
	var/turf/shooter_turf = locate(yard.origin_x + 2, yard.origin_y + 3, yard.z)
	var/mob/living/carbon/human/shooter = new(shooter_turf)
	shooter.faction = FACTION_MARINE
	shooter.setDir(EAST)
	var/obj/item/storage/backpack/pack = new(shooter)
	shooter.put_in_back(pack)
	new /obj/item/explosive/grenade/high_explosive(pack)
	new /obj/item/explosive/grenade/high_explosive(pack)
	for(var/offset in list(0, 1, -1))
		var/mob/living/carbon/xenomorph/drone/dummy = new(locate(shooter_turf.x + 8, shooter_turf.y + offset, yard.z))
		dummy.maxHealth = 3000
		dummy.health = 3000
		SSspatial_grid.track(dummy, SPATIAL_GRID_TRACK_NPC)
	if(friendly_near)
		var/mob/living/carbon/human/friend = new(locate(shooter_turf.x + 7, shooter_turf.y, yard.z))
		friend.faction = FACTION_MARINE
	return shooter

/datum/unit_test/human_ai_grenades/Run()
	var/obj/item/explosive/grenade/high_explosive/frag = allocate(/obj/item/explosive/grenade/high_explosive)
	var/obj/item/explosive/grenade/smokebomb/smoke = allocate(/obj/item/explosive/grenade/smokebomb)
	var/obj/item/explosive/grenade/flashbang/flash = allocate(/obj/item/explosive/grenade/flashbang)
	var/obj/item/explosive/grenade/incendiary/fire = allocate(/obj/item/explosive/grenade/incendiary)
	var/obj/item/explosive/grenade/high_explosive/frag/toy/toy = allocate(/obj/item/explosive/grenade/high_explosive/frag/toy)
	TEST_ASSERT_EQUAL(human_ai_grenade_kind(frag), HAI_GRENADE_LETHAL, "A high explosive grenade is lethal")
	TEST_ASSERT_EQUAL(human_ai_grenade_kind(fire), HAI_GRENADE_LETHAL, "An incendiary grenade is lethal")
	TEST_ASSERT_EQUAL(human_ai_grenade_kind(smoke), HAI_GRENADE_SMOKE, "A smoke grenade is smoke")
	TEST_ASSERT_EQUAL(human_ai_grenade_kind(flash), HAI_GRENADE_FLASH, "A flashbang is a flash")
	TEST_ASSERT_EQUAL(human_ai_grenade_kind(toy), HAI_GRENADE_NONE, "A toy grenade is never thrown")

	var/datum/human_ai_arena/yard = new(list(
		"####################",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"####################",
	), run_loc_floor_bottom_left)

	var/mob/living/carbon/human/careful = make_scene(yard, TRUE)
	TEST_ASSERT(attach_human_ai(careful), "The careful thrower took no brain")
	careful.ai_brain.keep_awake = TRUE
	sleep(12 SECONDS)
	TEST_ASSERT_EQUAL(careful.ai_brain.grenades_thrown, 0, "A grenade was thrown with a friend next to the enemies")
	detach_human_ai(careful)
	qdel(careful)
	for(var/mob/living/carbon/xenomorph/drone/leftover in world)
		qdel(leftover)
	for(var/mob/living/carbon/human/friend in range(yard.width, locate(yard.origin_x + 10, yard.origin_y + 3, yard.z)))
		qdel(friend)

	var/mob/living/carbon/human/thrower = make_scene(yard, FALSE)
	TEST_ASSERT(attach_human_ai(thrower), "The thrower took no brain")
	var/datum/human_ai_brain/brain = thrower.ai_brain
	brain.keep_awake = TRUE
	var/waited = 0
	while(waited++ < 80 && !thrown(brain))
		sleep(2.5)
	TEST_ASSERT(brain.grenades_thrown >= 1, "No grenade was thrown at three clustered enemies, intent [brain.intent], target [brain.get_target()], log [brain.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(brain.error_total, 0, "The thrower's brain threw errors")
	sleep(6 SECONDS)
	var/hurt_count = 0
	for(var/mob/living/carbon/xenomorph/drone/victim in world)
		if(victim.health < victim.maxHealth)
			hurt_count++
	TEST_ASSERT(hurt_count >= 1, "The grenade hurt none of the enemies")
	detach_human_ai(thrower)

/// A live grenade that lands at the unit's feet with fuse left is picked up and thrown back at the enemy, one with too little fuse left is run from
/datum/unit_test/human_ai_throw_back

/datum/unit_test/human_ai_throw_back/proc/returned(datum/human_ai_brain/brain)
	return brain.grenades_returned > 0

/datum/unit_test/human_ai_throw_back/Run()
	var/datum/human_ai_arena/yard = new(list(
		"####################",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"####################",
	), run_loc_floor_bottom_left)
	var/obj/item/explosive/grenade/high_explosive/unlit = allocate(/obj/item/explosive/grenade/high_explosive)
	TEST_ASSERT_NULL(human_ai_fuse_left(unlit), "A grenade that is not lit has a fuse")
	TEST_ASSERT(human_ai_grenade_hurts(unlit), "A high explosive grenade does not hurt")
	var/obj/item/explosive/grenade/smokebomb/smoke = allocate(/obj/item/explosive/grenade/smokebomb)
	TEST_ASSERT(!human_ai_grenade_hurts(smoke), "A smoke grenade was said to hurt")

	// A live grenade lands next to the soldier with the fuse still long
	var/mob/living/carbon/human/soldier = make_soldier(locate(yard.origin_x + 4, yard.origin_y + 3, yard.z), FACTION_MARINE, TRUE)
	var/datum/human_ai_brain/brain = soldier.ai_brain
	var/mob/living/carbon/xenomorph/drone/enemy = make_target_dummy(locate(yard.origin_x + 11, yard.origin_y + 3, yard.z))
	var/obj/item/explosive/grenade/high_explosive/live = new(locate(yard.origin_x + 5, yard.origin_y + 3, yard.z))
	live.activate()
	var/fuse = human_ai_fuse_left(live)
	TEST_ASSERT(fuse >= 30 && fuse <= 46, "A grenade that was just lit has a fuse of [fuse]")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(returned), brain), 3), "The grenade at the soldier's feet was not thrown back, intent [brain.intent], log [brain.decision_log.Join(" | ")]")
	sleep(0.5 SECONDS)
	TEST_ASSERT(live.loc != soldier, "The grenade is still in the soldier's hand")
	TEST_ASSERT(get_dist(soldier, live) >= 3, "The grenade did not leave the soldier, it is [get_dist(soldier, live)] tiles away")
	// It goes off where it was thrown and not where it was
	sleep(6 SECONDS)
	TEST_ASSERT(soldier.getBruteLoss() < 10, "The soldier was hurt by the grenade that was thrown back, [soldier.getBruteLoss()] brute")
	TEST_ASSERT(enemy.health < enemy.maxHealth, "The grenade that was thrown back did not hurt the enemy")
	TEST_ASSERT_EQUAL(brain.error_total, 0, "The brain threw errors")
	detach_human_ai(soldier)

	// With the fuse nearly gone there is no time for a pickup, so the soldier keeps the grenade where it is and gets away from it
	var/mob/living/carbon/human/runner = make_soldier(locate(yard.origin_x + 4, yard.origin_y + 2, yard.z), FACTION_MARINE, TRUE)
	var/obj/item/explosive/grenade/high_explosive/short = new(locate(yard.origin_x + 5, yard.origin_y + 2, yard.z))
	short.activate()
	short.primed_at = world.time - short.det_time + 3
	TEST_ASSERT_EQUAL(human_ai_fuse_left(short), 3, "The fuse of the test grenade is not the one that was set")
	sleep(1 SECONDS)
	TEST_ASSERT_EQUAL(runner.ai_brain.grenades_returned, 0, "A grenade with three decisecond of fuse was picked up")
	TEST_ASSERT(short.loc != runner, "The grenade with the short fuse is in the soldier's hand")
	detach_human_ai(runner)
	sleep(5 SECONDS)

/// With the gun dry a brain draws a blade, shoves what stands in reach and rolls to put out flames
/datum/unit_test/human_ai_melee

/datum/unit_test/human_ai_melee/proc/hurt(mob/living/carbon/xenomorph/dummy)
	return dummy.health < dummy.maxHealth

/datum/unit_test/human_ai_melee/proc/make_fighter(datum/human_ai_arena/yard, with_knife)
	var/turf/shooter_turf = locate(yard.origin_x + 2, yard.origin_y + 2, yard.z)
	var/mob/living/carbon/xenomorph/drone/dummy = new(locate(shooter_turf.x + 1, shooter_turf.y, yard.z))
	dummy.maxHealth = 3000
	dummy.health = 3000
	SSspatial_grid.track(dummy, SPATIAL_GRID_TRACK_NPC)
	var/mob/living/carbon/human/fighter = new(shooter_turf)
	human_ai_test_skills(fighter)
	fighter.faction = FACTION_MARINE
	fighter.setDir(EAST)
	var/obj/item/storage/backpack/pack = new(fighter)
	fighter.put_in_back(pack)
	if(with_knife)
		new /obj/item/weapon/sword/machete(pack)
	var/obj/item/weapon/gun/rifle/m41a/rifle = new(fighter, TRUE)
	fighter.put_in_hands(rifle)
	return fighter

/datum/unit_test/human_ai_melee/Run()
	var/datum/human_ai_arena/yard = new(list(
		"##########",
		"#........#",
		"#........#",
		"#........#",
		"##########",
	), run_loc_floor_bottom_left)

	var/mob/living/carbon/human/swordsman = make_fighter(yard, TRUE)
	TEST_ASSERT(attach_human_ai(swordsman), "The swordsman took no brain")
	swordsman.ai_brain.keep_awake = TRUE
	var/mob/living/carbon/xenomorph/drone/first_dummy = locate() in range(2, swordsman)
	var/datum/callback/first_hurt = CALLBACK(src, PROC_REF(hurt), first_dummy)
	var/waited = 0
	while(waited++ < 80 && !first_hurt.Invoke())
		sleep(2.5)
	TEST_ASSERT(swordsman.ai_brain.melee_draws >= 1, "The brain never drew its blade, intent [swordsman.ai_brain.intent], log [swordsman.ai_brain.decision_log.Join(" | ")]")
	TEST_ASSERT(first_hurt.Invoke(), "The blade never hurt the enemy")
	TEST_ASSERT_EQUAL(swordsman.ai_brain.error_total, 0, "The swordsman's brain threw errors")
	detach_human_ai(swordsman)
	qdel(swordsman)
	qdel(first_dummy)

	var/mob/living/carbon/human/brawler = make_fighter(yard, FALSE)
	TEST_ASSERT(attach_human_ai(brawler), "The brawler took no brain")
	brawler.ai_brain.keep_awake = TRUE
	var/mob/living/carbon/xenomorph/drone/second_dummy = locate() in range(2, brawler)
	waited = 0
	while(waited++ < 80 && brawler.ai_brain.shoves < 1)
		sleep(2.5)
	TEST_ASSERT(brawler.ai_brain.shoves >= 1, "The brain never shoved, intent [brawler.ai_brain.intent], log [brawler.ai_brain.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(brawler.ai_brain.error_total, 0, "The brawler's brain threw errors")
	detach_human_ai(brawler)
	qdel(brawler)
	qdel(second_dummy)

	var/mob/living/carbon/human/torch = new(locate(yard.origin_x + 4, yard.origin_y + 2, yard.z))
	torch.faction = FACTION_MARINE
	TEST_ASSERT(attach_human_ai(torch), "The burning man took no brain")
	torch.ai_brain.keep_awake = TRUE
	torch.adjust_fire_stacks(15)
	torch.IgniteMob(TRUE)
	TEST_ASSERT(torch.on_fire, "The test human did not catch fire")
	sleep(6 SECONDS)
	TEST_ASSERT(torch.ai_brain.fire_rolls >= 1, "The burning brain never rolled, intent [torch.ai_brain.intent]")
	waited = 0
	while(waited++ < 100 && torch.on_fire)
		sleep(2.5)
	TEST_ASSERT(!torch.on_fire, "The burning brain never put itself out, stacks [torch.fire_stacks]")
	detach_human_ai(torch)
	qdel(torch)

/// Humans of an enemy faction are fought on sight, others are left alone unless the hostility is forced
/datum/unit_test/human_ai_dispositions

/datum/unit_test/human_ai_dispositions/proc/spawn_human(faction, turf/where)
	var/mob/living/carbon/human/human = new(where)
	human.faction = faction
	return human

/datum/unit_test/human_ai_dispositions/proc/shot_at_prey(datum/human_ai_brain/brain)
	return brain.shots_fired > 0

/datum/unit_test/human_ai_dispositions/Run()
	var/mob/living/carbon/human/clf_man = spawn_human(FACTION_CLF, run_loc_floor_bottom_left)
	var/datum/human_ai_brain/brain = new(clf_man)
	var/mob/living/carbon/human/marine = spawn_human(FACTION_MARINE, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/upp_man = spawn_human(FACTION_UPP, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/colonist = spawn_human(FACTION_COLONIST, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/another_clf = spawn_human(FACTION_CLF, run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(brain.get_disposition(marine), HAI_DISP_HOSTILE, "CLF should fight marines")
	TEST_ASSERT_EQUAL(brain.get_disposition(upp_man), HAI_DISP_HOSTILE, "CLF should fight the UPP")
	TEST_ASSERT_EQUAL(brain.get_disposition(another_clf), HAI_DISP_FRIEND, "CLF should not fight CLF")
	TEST_ASSERT_EQUAL(brain.get_disposition(colonist), HAI_DISP_NEUTRAL, "CLF should leave colonists alone")
	brain.aggression = HAI_AGGRO_OTHERS
	TEST_ASSERT_EQUAL(brain.get_disposition(colonist), HAI_DISP_HOSTILE, "Forced hostility should include colonists")
	TEST_ASSERT_EQUAL(brain.get_disposition(another_clf), HAI_DISP_FRIEND, "Forced hostility should still spare the own faction")
	brain.aggression = HAI_AGGRO_NONE
	TEST_ASSERT_EQUAL(brain.get_disposition(marine), HAI_DISP_NEUTRAL, "A peaceful brain should not fight marines")
	qdel(brain)
	qdel(clf_man)

	var/datum/human_ai_arena/yard = new(list(
		"####################",
		"#..................#",
		"#..................#",
		"#..................#",
		"####################",
	), run_loc_floor_bottom_left)
	var/turf/shooter_turf = locate(yard.origin_x + 2, yard.origin_y + 2, yard.z)
	var/mob/living/carbon/human/raider = spawn_human(FACTION_CLF, shooter_turf)
	human_ai_test_skills(raider)
	raider.setDir(EAST)
	var/obj/item/weapon/gun/rifle/m41a/rifle = new(raider)
	raider.put_in_hands(rifle)
	var/mob/living/carbon/human/victim = spawn_human(FACTION_MARINE, locate(shooter_turf.x + 7, shooter_turf.y, yard.z))
	victim.setDir(WEST)
	TEST_ASSERT(attach_human_ai(raider), "The raider took no brain")
	var/datum/human_ai_brain/raider_brain = raider.ai_brain
	raider_brain.keep_awake = TRUE
	var/datum/callback/fired = CALLBACK(src, PROC_REF(shot_at_prey), raider_brain)
	var/waited = 0
	while(waited++ < 80 && !fired.Invoke())
		sleep(2.5)
	TEST_ASSERT(raider_brain.shots_fired > 0, "The raider never opened fire on a marine standing in the open, intent [raider_brain.intent], target [raider_brain.get_target()]")
	waited = 0
	while(waited++ < 40 && victim.health >= victim.maxHealth)
		sleep(2.5)
	TEST_ASSERT(victim.health < victim.maxHealth, "The shots never hit the marine, shots [raider_brain.shots_fired]")
	detach_human_ai(raider)
	qdel(raider)
	qdel(victim)
