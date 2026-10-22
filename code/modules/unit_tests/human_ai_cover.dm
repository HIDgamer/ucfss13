/// Cover is only ever scored for a barricade that faces the threat, and the cover search never picks the wrong side
/datum/unit_test/human_ai_cover_geometry

/datum/unit_test/human_ai_cover_geometry/Run()
	var/datum/human_ai_arena/yard = new(list(
		"####################",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"####################",
	), run_loc_floor_bottom_left)
	var/turf/middle = locate(yard.origin_x + 10, yard.origin_y + 6, yard.z)
	var/mob/living/carbon/human/human = new(locate(middle.x - 4, middle.y, middle.z))
	var/datum/human_ai_brain/brain = new(human)
	var/list/problems = list()
	var/checked = 0
	var/found_cover = 0
	for(var/cade_dir in GLOB.cardinals)
		var/obj/structure/barricade/metal/cade = new(middle)
		cade.setDir(cade_dir)
		for(var/bearing in GLOB.alldirs)
			var/turf/threat = middle
			for(var/step in 1 to 6)
				threat = get_step(threat, bearing)
			for(var/dx in -3 to 3)
				for(var/dy in -3 to 3)
					var/turf/stand = locate(middle.x + dx, middle.y + dy, middle.z)
					if(!stand || stand == threat)
						continue
					var/value = brain.cover_against(stand, threat)
					checked++
					if(value >= HAI_COVER_MIN_SCORE)
						found_cover++
						var/obj/used = brain.last_cover_object
						if(used != cade || !(cade_dir & get_dir(middle, threat)))
							problems += "stand [dx],[dy] bearing [bearing] cade facing [cade_dir] scored [value] with [used] facing [used?.dir]"
					else if(value > 0 && !(cade_dir & get_dir(middle, threat)))
						problems += "stand [dx],[dy] bearing [bearing] cade facing [cade_dir] away from the threat still scored [value]"
		var/turf/east_threat = locate(middle.x + 6, middle.y, middle.z)
		var/turf/west_threat = locate(middle.x - 6, middle.y, middle.z)
		if(cade_dir == EAST)
			TEST_ASSERT(brain.cover_against(locate(middle.x - 1, middle.y, middle.z), east_threat) >= HAI_COVER_MIN_SCORE, "The tile behind an east facing barricade should be cover against the east")
			TEST_ASSERT_EQUAL(brain.cover_against(locate(middle.x + 1, middle.y, middle.z), east_threat), 0, "The tile in front of a barricade is not cover")
			TEST_ASSERT_EQUAL(brain.cover_against(locate(middle.x - 1, middle.y, middle.z), west_threat), 0, "A barricade facing away gives no cover")
		qdel(cade)
	TEST_ASSERT(found_cover > 0, "No stand tile ever scored as cover")

	for(var/cade_dir in GLOB.cardinals)
		var/obj/structure/barricade/metal/cade = new(middle)
		cade.setDir(cade_dir)
		for(var/bearing in GLOB.alldirs)
			var/turf/threat = middle
			for(var/step in 1 to 7)
				threat = get_step(threat, bearing)
			human.forceMove(locate(middle.x + rand(-3, 3), middle.y + rand(-3, 3), middle.z))
			if(human.loc == middle || threat == human.loc)
				continue
			var/turf/chosen = brain.find_cover(threat)
			if(!chosen)
				continue
			var/value = brain.cover_against(chosen, threat)
			if(value < HAI_COVER_MIN_SCORE || brain.last_cover_object != cade)
				problems += "search for bearing [bearing] cade facing [cade_dir] picked [chosen.x - middle.x],[chosen.y - middle.y] worth [value]"
			else if(!(cade_dir & get_dir(middle, threat)))
				problems += "search for bearing [bearing] picked cover behind a cade facing [cade_dir], away from the threat"
		qdel(cade)
	qdel(brain)
	TEST_NOTICE(src, "[checked] stand tiles scored, [found_cover] counted as cover")
	TEST_ASSERT(!length(problems), "[length(problems)] cover problems:\n[problems.Join("\n")]")

/// Shots at a target behind a barricade land far less often than shots at one in the open
/datum/unit_test/human_ai_cover_value
	var/hits = 0
	var/fired = 0

/datum/unit_test/human_ai_cover_value/proc/count_hit(datum/source, damage_result, ammo_flags, obj/projectile/bullet)
	SIGNAL_HANDLER
	hits++

/datum/unit_test/human_ai_cover_value/proc/damage_after_volley(mob/living/carbon/human/shooter, obj/item/weapon/gun/gun, mob/living/carbon/human/target, shots)
	hits = 0
	fired = 0
	if(gun.current_mag)
		gun.current_mag.current_rounds = gun.current_mag.max_rounds
	for(var/shot in 1 to shots)
		if(gun.current_mag && gun.current_mag.current_rounds < 5)
			gun.current_mag.current_rounds = gun.current_mag.max_rounds
		gun.guaranteed_delay_time = 0
		gun.wield_time = 0
		gun.last_fired = 0
		var/before = gun.last_fired
		gun.Fire(target, shooter)
		if(gun.last_fired != before)
			fired++
		sleep(1)
		if(target.stat == DEAD || target.health < 40)
			target.rejuvenate()
	sleep(3 SECONDS)
	return hits

/datum/unit_test/human_ai_cover_value/Run()
	var/datum/human_ai_arena/yard = new(list(
		"####################",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"####################",
	), run_loc_floor_bottom_left)
	var/turf/shooter_turf = locate(yard.origin_x + 2, yard.origin_y + 2, yard.z)
	var/turf/cover_turf = locate(shooter_turf.x + 8, shooter_turf.y, yard.z)
	var/turf/open_turf = locate(shooter_turf.x + 8, shooter_turf.y + 1, yard.z)
	var/mob/living/carbon/human/shooter = new(shooter_turf)
	human_ai_test_skills(shooter)
	shooter.faction = FACTION_CLF
	shooter.setDir(EAST)
	var/obj/item/weapon/gun/rifle/m41a/rifle = new(shooter)
	shooter.put_in_hands(rifle)
	rifle.wield(shooter)
	rifle.set_gun_user(shooter)
	var/mob/living/carbon/human/target = new(cover_turf)
	target.faction = FACTION_MARINE
	target.maxHealth = 100000
	target.health = 100000
	var/obj/structure/barricade/metal/cade = new(locate(cover_turf.x - 1, cover_turf.y, cover_turf.z))
	cade.setDir(WEST)
	RegisterSignal(target, COMSIG_HUMAN_BULLET_ACT, PROC_REF(count_hit))
	var/covered = damage_after_volley(shooter, rifle, target, 360)
	target.forceMove(open_turf)
	var/open = damage_after_volley(shooter, rifle, target, 360)
	TEST_NOTICE(src, "360 rifle shots: [covered] hits on a target behind a barricade, [open] on one in the open")
	TEST_ASSERT(open > 0, "No shot landed on the target in the open, gun fired [fired] of 360 times, rounds left [rifle.current_mag?.current_rounds], gun in [rifle.loc], gun user [rifle.get_gun_user()], active hand [shooter.get_active_hand()], shooter at [shooter.x],[shooter.y], target at [target.x],[target.y], stat [target.stat]")
	TEST_ASSERT(covered < open * 0.75, "Cover did not help: [covered] hits against [open]")
	for(var/obj/projectile/bullet in world)
		qdel(bullet)
	qdel(shooter)
	qdel(target)
	qdel(cade)

/// A brain with cover in reach walks to the tile behind it and fights from there
/datum/unit_test/human_ai_cover_choice

/datum/unit_test/human_ai_cover_choice/proc/behind_cover(datum/human_ai_brain/brain, turf/threat)
	return brain.cover_here(threat) >= HAI_COVER_MIN_SCORE

/datum/unit_test/human_ai_cover_choice/Run()
	var/datum/human_ai_arena/yard = new(list(
		"########################",
		"#......................#",
		"#......................#",
		"#......................#",
		"#......................#",
		"#......................#",
		"#......................#",
		"########################",
	), run_loc_floor_bottom_left)
	var/turf/start = locate(yard.origin_x + 2, yard.origin_y + 3, yard.z)
	var/turf/threat_turf = locate(start.x + 8, start.y, yard.z)
	var/mob/living/carbon/xenomorph/drone/dummy = allocate(/mob/living/carbon/xenomorph/drone, threat_turf)
	dummy.maxHealth = 100000
	dummy.health = 100000
	SSspatial_grid.track(dummy, SPATIAL_GRID_TRACK_NPC)
	for(var/offset in -1 to 1)
		var/obj/structure/barricade/metal/cade = new(locate(start.x + 3, start.y + offset, yard.z))
		cade.setDir(EAST)
	var/mob/living/carbon/human/soldier = allocate(/mob/living/carbon/human, start)
	human_ai_test_skills(soldier)
	soldier.faction = FACTION_MARINE
	soldier.setDir(EAST)
	var/obj/item/weapon/gun/rifle/m41a/rifle = new(soldier)
	soldier.put_in_hands(rifle)
	TEST_ASSERT(attach_human_ai(soldier), "The soldier took no brain")
	var/datum/human_ai_brain/brain = soldier.ai_brain
	brain.keep_awake = TRUE
	var/datum/callback/covered = CALLBACK(src, PROC_REF(behind_cover), brain, threat_turf)
	var/waited = 0
	while(waited++ < 100 && !covered.Invoke())
		sleep(2.5)
	TEST_ASSERT(covered.Invoke(), "The soldier never reached cover, at [soldier.x],[soldier.y], moves [brain.cover_moves], intent [brain.intent], log [brain.decision_log.Join(" | ")]")
	TEST_ASSERT(brain.cover_moves >= 1, "The soldier was already covered without moving")
	var/turf/held = get_turf(soldier)
	sleep(8 SECONDS)
	TEST_ASSERT(get_dist(held, soldier) <= 1, "The soldier left its cover to walk at the enemy, from [held.x],[held.y] to [soldier.x],[soldier.y]")
	TEST_ASSERT(brain.shots_fired > 0, "The soldier never shot from cover")
	TEST_ASSERT_EQUAL(brain.error_total, 0, "The soldier's brain threw errors")
	detach_human_ai(soldier)

/// A brain with only a table nearby flips it toward the threat, and a live grenade makes a brain run
/datum/unit_test/human_ai_cover_improvised

/datum/unit_test/human_ai_cover_improvised/Run()
	var/datum/human_ai_arena/yard = new(list(
		"########################",
		"#......................#",
		"#......................#",
		"#......................#",
		"#......................#",
		"########################",
	), run_loc_floor_bottom_left)
	var/turf/start = locate(yard.origin_x + 3, yard.origin_y + 2, yard.z)
	var/turf/threat_turf = locate(start.x + 8, start.y, yard.z)
	var/mob/living/carbon/xenomorph/drone/dummy = allocate(/mob/living/carbon/xenomorph/drone, threat_turf)
	dummy.maxHealth = 100000
	dummy.health = 100000
	SSspatial_grid.track(dummy, SPATIAL_GRID_TRACK_NPC)
	var/obj/structure/surface/table/table = new(locate(start.x + 1, start.y, yard.z))
	var/mob/living/carbon/human/soldier = allocate(/mob/living/carbon/human, start)
	human_ai_test_skills(soldier)
	soldier.faction = FACTION_MARINE
	soldier.setDir(EAST)
	var/obj/item/weapon/gun/rifle/m41a/rifle = new(soldier)
	soldier.put_in_hands(rifle)
	TEST_ASSERT(attach_human_ai(soldier), "The soldier took no brain")
	var/datum/human_ai_brain/brain = soldier.ai_brain
	brain.keep_awake = TRUE
	var/waited = 0
	while(waited++ < 80 && !table.flipped)
		sleep(2.5)
	TEST_ASSERT(table.flipped, "The soldier never flipped the table in front of it, flips [brain.tables_flipped], intent [brain.intent], log [brain.decision_log.Join(" | ")]")
	TEST_ASSERT(table.dir == EAST, "The table was flipped to face [table.dir] and not the enemy")
	sleep(2 SECONDS)
	TEST_ASSERT(brain.cover_here(threat_turf) >= HAI_COVER_MIN_SCORE, "The flipped table gives no cover where the soldier stands: it is at [soldier.x],[soldier.y] from [start.x],[start.y], the table at [table.x],[table.y] facing [table.dir] coverage [table.projectile_coverage] flags [table.flags_atom & ON_BORDER], log [brain.decision_log.Join(" | ")]")
	detach_human_ai(soldier)
	qdel(soldier)

	var/mob/living/carbon/human/runner_man = allocate(/mob/living/carbon/human, locate(start.x + 6, start.y + 1, yard.z))
	runner_man.faction = FACTION_MARINE
	TEST_ASSERT(attach_human_ai(runner_man), "The runner took no brain")
	runner_man.ai_brain.keep_awake = TRUE
	var/obj/item/explosive/grenade/high_explosive/live = new(locate(runner_man.x + 1, runner_man.y, yard.z))
	live.det_time = 50
	live.activate(runner_man, FALSE)
	// A fuse the unit cannot read is not one to pick up and throw back, it gets clear of it; the throw back has its own test
	live.primed_at = null
	sleep(4 SECONDS)
	TEST_ASSERT(get_dist(runner_man, live) > HAI_HAZARD_RADIUS - 1 || QDELETED(live), "The brain stood next to a live grenade, [get_dist(runner_man, live)] tiles away")
	TEST_ASSERT(runner_man.ai_brain.hazard_dodges >= 1, "The brain never ran from the grenade")
	sleep(3 SECONDS)
	TEST_ASSERT(runner_man.health >= runner_man.maxHealth * 0.9, "The grenade hurt the brain that ran from it, health [runner_man.health]")
	detach_human_ai(runner_man)
