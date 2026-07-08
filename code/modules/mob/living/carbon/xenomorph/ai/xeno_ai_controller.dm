/**
 * Core decision-making datum for an NPC-piloted Xenomorph.
 *
 * One instance is composed onto a real xenomorph mob (see xeno_ai_lifecycle.dm's
 * attach_xeno_ai()) that has no client. It drives itself via its own INVOKE_ASYNC
 * coroutine (ai_loop()) rather than a shared subsystem tick, so idle mobs cost almost
 * nothing and busy mobs never stall the tick budget for player-piloted xenos on
 * SSxeno. The pilot's normal Life() ticking (health/plasma/status) is untouched -
 * this datum only adds a decision layer on top.
 */
/datum/xeno_ai_controller
	/// The xenomorph mob this controller pilots. Never changes for the lifetime of the datum.
	var/mob/living/carbon/xenomorph/pilot
	/// Current target being pursued/attacked, if any - either a living hostile or an attackable structure (e.g. a sentry turret).
	var/atom/movable/current_target
	/// Turf the pilot leashes to; wandering more than return_distance from this turf aborts the chase.
	var/turf/anchor_turf
	/// Cached bounded turf list from the last scan; reused across idle ticks until a target is found or the pilot moves on.
	var/list/turf_block
	/// Turf the pilot was standing on when turf_block was last computed - see process_target()'s staleness check.
	var/turf/turf_block_origin
	var/ai_state = AI_STATE_IDLE
	/// Ticks slept between loop iterations while actively engaged (chasing/attacking).
	var/ai_heartbeat = AI_XENO_DEFAULT_HEARTBEAT
	/// Ticks slept between loop iterations while idle and scanning - deliberately longer than ai_heartbeat.
	var/ai_idle_heartbeat = AI_XENO_DEFAULT_IDLE_HEARTBEAT
	/// Radius (tiles) of the bounded target scan.
	var/attack_distance = AI_XENO_DEFAULT_ATTACK_DISTANCE
	/// Leash radius (tiles) from anchor_turf before the pilot disengages and returns.
	var/return_distance = AI_XENO_DEFAULT_RETURN_DISTANCE
	/// Set TRUE the instant the pilot should stop being AI-driven (client attached, death, deletion). The coroutine checks this at the top of every loop and exits cleanly - no forced kill of an in-flight sleep().
	var/detached = FALSE
	/// Consecutive failed movement attempts against the current target; used to give up rather than loop forever against an unreachable target (this AI does not pathfind).
	var/blocked_attempts = 0
	/// Last known turf of a target that escaped rather than died - drives AI_STATE_SEARCHING instead of instantly forgetting about it.
	var/turf/last_seen_turf
	/// world.time the current search began, to bound how long SEARCHING lasts.
	var/search_started_at = 0
	/// Cached native-pathfinder route (remaining waypoint turfs, nearest first). Null whenever there's no live plan - the old greedy step_towards() handles movement whenever this is empty, so a host without the native pathfinding library behaves exactly as before.
	var/list/path_queue
	/// The turf path_queue was computed to reach; a route is only reused while the goal hasn't moved to a different tile.
	var/turf/path_goal
	/// TRUE if the last compute_path() attempt against path_goal came back empty (too big for the cell budget, or genuinely no route) - see next_path_attempt. Without this, a doomed hop (e.g. a target across an open LZ/Thunderdome pad) re-runs the full grid-build every single tick forever instead of just once per cooldown.
	var/path_failed = FALSE
	/// world.time advance_along_path() is next willing to retry a fresh compute_path() after a failed attempt against essentially the same goal.
	var/next_path_attempt = 0
	/// Obstacle (wall/structure) currently committed to smashing through - see attack_blocking_obstacle()/get_blocking_obstacle(). "Keeps pathfinding moving between smashing different walls instead of focusing on the original wall" - a target shifting a tile or two behind cover used to make a completely different wall segment line up as "the" blocking obstacle every tick, abandoning whatever damage was already dealt to the old one.
	var/atom/committed_obstacle
	/// world.time committed_obstacle can be abandoned for a different one even though it's still blocking - a generous minimum commitment window, not a hard lock, so a genuinely better route (a real door opening up) isn't ignored forever.
	var/committed_obstacle_until = 0
	/// Absolute direction of the last successful navigate_around() sidestep - tried again first next time, so the pilot commits to going around one side of an obstacle instead of flip-flopping as target_dir shifts tick to tick.
	var/last_sidestep_dir
	/// Direction a long obstacle-skirt (see attempt_skirt_obstacle()) is currently committed to, or null if not skirting - "long pathfinding around a building is not possible" fix: a single sidestep isn't enough distance to clear a whole building, so this keeps walking one direction for a while instead of re-aiming at the goal (and potentially flip-flopping) every tick.
	var/skirt_dir
	/// world.time the current skirt commitment ends.
	var/skirt_until = 0
	/// world.time this controller was attached - backs the hive status roster's "time lived" column (see event_tab.dm's admin panel).
	var/spawned_at = 0
	/// Cumulative damage dealt to living targets since attach - see record_damage_dealt() in xeno_ai_attack.dm.
	var/damage_dealt = 0
	/// world.time a caste ability last actually fired (use_caste_ability() returning TRUE, xeno_ai_attack.dm) - 0 if never. Purely observational (hive status roster).
	var/last_ability_time = 0
	/// Random flavor callsign, drawn from a pool matching the pilot's caste role (see get_codename_pool()) - assigned once at attach. Lets the hive status roster (event_tab.dm's admin panel) tell a screen full of same-caste xenos apart at a glance instead of just listing "Drone" over and over, and gives a boss-tier xeno a suitably grander name than a builder gets.
	var/codename
	/// Turf this xeno is traveling to (or already holding) for attempt_ambush_hide()'s "hide near the LZ" idle behavior - null whenever not mid-ambush.
	var/turf/ambush_turf
	/// TRUE once actually settled and xenohidden at ambush_turf, as opposed to still walking there - see attempt_ambush_hide().
	var/ambush_hiding = FALSE
	/// world.time attempt_ambush_hide() gives up the hide and resumes normal patrol.
	var/ambush_hide_until = 0
	/// Heading wander() is currently committed to - see wander()'s doc comment for why this exists instead of picking fresh every roll.
	var/wander_dir
	/// world.time wander() will pick a new heading even if the current one hasn't failed yet.
	var/next_wander_reroll = 0
	/// world.time a dormant phase (see AI_XENO_DORMANT_CHANCE) ends - while world.time is below this, wander() skips movement entirely and ai_loop() sleeps the much longer AI_XENO_DORMANT_HEARTBEAT instead of AI_XENO_DEFAULT_IDLE_HEARTBEAT. 0 means "not dormant."
	var/dormant_until = 0
	/// world.time this controller can next actually move a tile - see ai_step() in xeno_ai_movement.dm.
	var/next_step_time = 0
	/// Destination of an in-progress long patrol leg (start_long_patrol()/continue_long_patrol()) - null whenever not mid-trip.
	var/turf/patrol_turf
	/// world.time wander() forces her back up from resting regardless of health - a safety net so a heal that stalls short of full (permanent limb damage, etc.) doesn't leave her resting forever.
	var/rest_timeout = 0
	/// Named sub-state of AI_STATE_IDLE (see the IDLE_ACTIVITY_* defines) - what patrol() actually decided to do this tick, since "Idle" alone doesn't distinguish standing still from wandering/building/regrouping/patrolling. Purely observational (hive status roster) - doesn't drive any logic itself.
	var/idle_activity = IDLE_ACTIVITY_NONE
	/// world.time a hit-and-run caste stops actively retreating and resumes closing on current_target - see start_tactical_retreat()/is_tactical_retreating().
	var/tactical_retreat_until = 0
	/// The pilot's own last_damage_data (mob_defines.dm) as of the last check_retaliation() call - a fresh cause_data instance is created for every single hit, so comparing by reference tells "already reacted to this one" from "something new just hit her" without needing a separate signal.
	var/datum/cause_data/last_retaliation_data
	/// A nearer, defensible turf (find_defensible_turf()) picked when this flee started, if one was actually closer than anchor_turf - null means "just go to anchor_turf as normal." Cleared on arrival/give-up same as anchor_turf's own resolution.
	var/turf/flee_turf
	/// The turf current_target occupied at the exact moment a flee transition dropped it (tick()) - drop_target() nulls current_target/last_seen_turf immediately, so a per-caste escape-ability hook (e.g. crusher.dm's attempt_tumble_retreat()) called from return_to_anchor() has nothing else to aim away from. Not cleared on arrival - stale is harmless, it's only ever read while actually retreating.
	var/turf/last_threat_turf
	/// Perimeter turf currently committed to for attempt_build_defense() - picked once and walked to across multiple idle ticks instead of re-rolled (and therefore essentially never actually reached, since a Drone/Queen has max_build_dist == 0) on every single call. Null whenever not mid-walk to a build site.
	var/turf/build_target_turf
	/// resin_construction type queued for build_target_turf - see attempt_build_defense().
	var/build_target_wall_type
	/// Loose /obj/item/xeno_egg currently being carried to egg_plant_turf - see attempt_carry_egg(). Null whenever not mid-carry.
	var/obj/item/xeno_egg/carrying_egg
	/// Turf picked to plant carrying_egg at - see attempt_carry_egg().
	var/turf/egg_plant_turf
	/// world.time this controller is next willing to roll/be picked for attempt_social_interaction() - set on both participants so the same pair doesn't immediately vignette again next tick, and so a xeno that was just on the receiving end isn't instantly picked as someone else's target too.
	var/next_social_interaction = 0

/// Flavor callsigns for solo bosses (Queen, King) - purely cosmetic (hive status roster only), no gameplay meaning.
GLOBAL_LIST_INIT(ai_codenames_boss, list("Alpha Doom", "Doomsday", "Last Rites", "Omega Latch", "Final Curtain", "Iron Throne"))
/// Flavor callsigns for tanks/frontline holders (Crusher, Defender).
GLOBAL_LIST_INIT(ai_codenames_tank, list("Iron Lung", "Stone Ward", "Bone Orchard", "Blood Moon", "No Quarter", "Cold Comfort"))
/// Flavor callsigns for stealth/ambush castes (Lurker, Runner, Facehugger, Burrower).
GLOBAL_LIST_INIT(ai_codenames_stealth, list("Silent Reaper", "Night Terror", "Quiet Storm", "Static Ghost", "Empty Chair", "Pale Horse"))
/// Flavor callsigns for support/builder castes (Drone, Lesser Drone, Hivelord, Carrier, Larva).
GLOBAL_LIST_INIT(ai_codenames_support, list("Second Wind", "Long Shadow", "Dead Air", "Slow Burn", "Broken Vow", "False Dawn"))
/// Flavor callsigns for ranged/artillery castes (Spitter, Sentinel, Boiler, Praetorian).
GLOBAL_LIST_INIT(ai_codenames_ranged, list("Dead Reckoning", "Fever Dream", "Hollow Point", "Rust Prophet", "Sudden Frost", "Deep Cut"))
/// Flavor callsigns for heavy melee brawlers (Warrior, Ravager, Predalien) - also the fallback pool for anything uncategorized.
GLOBAL_LIST_INIT(ai_codenames_brawler, list("Red Death", "Hail Mary", "Grim Tally", "Widow's Kiss", "Dark Harvest", "Nine Lives"))

/datum/xeno_ai_controller/New(mob/living/carbon/xenomorph/new_pilot)
	. = ..()
	pilot = new_pilot
	anchor_turf = get_turf(pilot)
	spawned_at = world.time
	codename = pick(get_codename_pool())

/// Picks which flavor-callsign pool this xeno draws from, based on its caste's actual combat role - see the GLOB.ai_codenames_* lists just above.
/datum/xeno_ai_controller/proc/get_codename_pool()
	if(!pilot)
		return GLOB.ai_codenames_brawler
	switch(pilot.caste_type)
		if(XENO_CASTE_QUEEN, XENO_CASTE_KING)
			return GLOB.ai_codenames_boss
		if(XENO_CASTE_CRUSHER, XENO_CASTE_DEFENDER)
			return GLOB.ai_codenames_tank
		if(XENO_CASTE_LURKER, XENO_CASTE_RUNNER, XENO_CASTE_FACEHUGGER, XENO_CASTE_BURROWER)
			return GLOB.ai_codenames_stealth
		if(XENO_CASTE_DRONE, XENO_CASTE_LESSER_DRONE, XENO_CASTE_HIVELORD, XENO_CASTE_CARRIER, XENO_CASTE_LARVA, XENO_CASTE_PREDALIEN_LARVA)
			return GLOB.ai_codenames_support
		if(XENO_CASTE_SPITTER, XENO_CASTE_SENTINEL, XENO_CASTE_BOILER, XENO_CASTE_PRAETORIAN)
			return GLOB.ai_codenames_ranged
	return GLOB.ai_codenames_brawler

/datum/xeno_ai_controller/Destroy()
	detached = TRUE
	pilot = null
	current_target = null
	anchor_turf = null
	turf_block = null
	path_queue = null
	path_goal = null
	return ..()

/// Starts the coroutine. Safe to call more than once; only ever spawns one loop per start() since the loop exits immediately if detached is already set.
/datum/xeno_ai_controller/proc/start()
	if(!pilot)
		return
	detached = FALSE
	INVOKE_ASYNC(src, PROC_REF(ai_loop))

/// Signals the coroutine to exit at its next check. Does not touch the pilot mob itself.
/datum/xeno_ai_controller/proc/stop()
	detached = TRUE

/**
 * Outer loop is intentionally just error containment + sleep timing - all
 * actual decision-making lives in tick(). A runtime error anywhere in that
 * call chain (movement, pathfinding, attack resolution, etc.) would otherwise
 * unwind all the way up through this proc and permanently kill the coroutine,
 * leaving the mob standing frozen forever with nothing further to fix it -
 * this is why "AI gets stuck for no reason" happened. Catching here means one
 * bad tick just gets logged and skipped; the mob keeps trying next tick.
 */
/datum/xeno_ai_controller/proc/ai_loop()
	while(!detached && pilot && !QDELETED(pilot) && pilot.stat != DEAD)
		try
			tick()
			update_movement_intent()
			// Idle mobs sleep much longer between ticks than engaged ones - there's
			// no urgency in scanning for a target 10x/sec when nothing's happening.
			// Engaged mobs (approaching/attacking/returning/searching) re-run at
			// the fastest interval sleep() grants (see AI_XENO_DEFAULT_HEARTBEAT) -
			// their actual pace is already capped for free by the pilot's own
			// movement/attack cooldowns, so tick() itself should never be the
			// bottleneck on top of that. Checked against the post-tick state so
			// this still matches whatever tick() just decided. Dormancy
			// (wander()'s dormant_until) deliberately does NOT slow this
			// heartbeat down further - "completely idle, not attacking" was
			// partly this making target-scanning itself sluggish on top of
			// skipping movement; dormancy only ever needed to cut the
			// movement/pathing cost, not responsiveness to an actual target.
		catch(var/exception/error)
			// "Cannot read null.type" - the very diagnostic logging meant to
			// keep one bad tick() from killing this coroutine was itself
			// throwing when pilot died/got QDELETED during that same tick()
			// call (e.g. the xeno was gibbed mid-tick), since pilot is null
			// by the time this catch block runs. pilot?.type instead of
			// pilot.type so the log call itself can never re-throw.
			//
			// "AI plagued with instances of stale or deleted AI" -
			// update_movement_intent() and the heartbeat pick used to run
			// AFTER this try/catch, unprotected - any exception there (not
			// just inside tick() itself) would unwind straight out of
			// ai_loop() and silently end the coroutine for good, leaving a
			// perfectly alive, non-deleted mob standing frozen forever with
			// nothing left to ever tick it again. Both are now inside the
			// same guarded block tick() already gets.
			stack_trace("xeno_ai_controller/tick() error for [pilot] ([pilot?.type]): [error]")
		sleep((ai_state == AI_STATE_IDLE) ? ai_idle_heartbeat : ai_heartbeat)

/**
 * Always MOVE_INTENT_RUN - the previous walk-while-idle/attacking,
 * run-while-approaching split ("stalk vs walk") is removed per explicit
 * direction: every AI xeno moves at the same pace regardless of state now.
 * Still its own proc (rather than just setting m_intent once at attach)
 * since set_movement_intent() only does anything when the intent actually
 * changes, and something else could in principle reset m_intent externally.
 */
/datum/xeno_ai_controller/proc/update_movement_intent()
	if(!pilot)
		return
	var/desired_intent = MOVE_INTENT_RUN
	if(pilot.m_intent != desired_intent)
		pilot.set_movement_intent(desired_intent)

/datum/xeno_ai_controller/proc/tick()
	check_retaliation() // Before the incapacitation check below - she should already be locked onto whoever just hit her by the time she's able to act again, not notice only once she recovers.

	// Evolution as the growth path for AI xenos is retired - see
	// hive_encounter.dm's pick_needed_hive_caste()/grow_hive_larva() for the
	// replacement: the Queen spawns whatever tier/role the hive currently
	// needs directly as population grows, instead of individual xenos
	// banking evolution_stored and evolving on their own timer.

	if(pilot.is_mob_incapacitated() || (HAS_TRAIT(pilot, TRAIT_IMMOBILIZED) && !can_act_while_immobilized()))
		// Stunned/knocked down/floored/etc - do nothing until it passes, same
		// as a player would be unable to act. TRAIT_IMMOBILIZED is checked
		// directly (not just is_mob_incapacitated()) because knockdown only
		// applies TRAIT_FLOORED/TRAIT_IMMOBILIZED, not TRAIT_INCAPACITATED -
		// relying on is_mob_incapacitated() alone missed that case entirely.
		// can_act_while_immobilized() carves out the one exception: a caste
		// that deliberately immobilized itself (Defender's Fortify) but can
		// still fight from where it's planted - without this, a fortified
		// Defender hit this same early-return every single tick forever,
		// unable to attack OR un-fortify to reposition once the fight moved
		// out of reach; the ability effectively bricked the AI that used it.
		// Deliberately does not touch ai_state so it resumes exactly where
		// it left off once the effect ends.
		return

	if(ai_state != AI_STATE_RETURNING && should_flee())
		pilot.emote("needshelp") // Fires exactly once on the transition into fleeing, not every tick spent retreating.
		last_threat_turf = current_target ? get_turf(current_target) : last_seen_turf
		drop_target()
		ai_state = AI_STATE_RETURNING
		// "They should also consider corners and walls as defensive
		// positions" - a nearby defensible turf beats a long, exposed walk
		// back to anchor_turf across open ground, if one's actually closer.
		var/turf/defensible = find_defensible_turf()
		var/turf/pilot_turf = get_turf(pilot)
		flee_turf = (defensible && pilot_turf && anchor_turf && get_dist(pilot_turf, defensible) < get_dist(pilot_turf, anchor_turf)) ? defensible : null

	switch(ai_state)
		if(AI_STATE_RETURNING)
			return_to_anchor()
			return
		if(AI_STATE_ATTACKING)
			process_attack()
			return
		if(AI_STATE_SEARCHING)
			process_search()
			return

	if(current_target && should_disengage())
		ai_state = AI_STATE_RETURNING
		return

	if(!current_target)
		process_target()

	if(!current_target)
		ai_state = AI_STATE_IDLE
		patrol()
		return

	process_movement()

/**
 * Idle xenos check for a live hive-wide alert from the Queen first (see
 * respond_to_hive_alert()) - "command" without a hard hierarchy - then
 * whether she's specifically calling for an escort (respond_to_queen_escort()),
 * and only fall back to aimless wander() if none apply. Concrete subtypes
 * that override patrol() (e.g. drone_worker, to roll build attempts) should
 * check respond_to_hive_alert() first too, before their own idle behavior,
 * so a Queen's call takes priority over routine tasks.
 */
/datum/xeno_ai_controller/proc/patrol()
	if(respond_to_hive_alert())
		idle_activity = IDLE_ACTIVITY_ALERT
		return
	if(attempt_help_burning_ally())
		idle_activity = IDLE_ACTIVITY_ALERT
		return
	if(respond_to_queen_escort())
		idle_activity = IDLE_ACTIVITY_ESCORT
		return
	// Already committed to a long patrol leg (see start_long_patrol()) - walk
	// it out in one straight shot before considering anything else, per
	// design: "a straight line before thinking about what to do next, idle
	// or patrol more," not a fresh roll against every other idle behavior
	// on every single tick. Still only just below the Queen's own hive-wide
	// calls, which can pull a xeno off a patrol leg same as they'd pull one
	// off plain wandering.
	if(patrol_turf)
		idle_activity = IDLE_ACTIVITY_LONG_PATROL
		continue_long_patrol()
		return
	if(respond_to_pack_cohesion())
		idle_activity = IDLE_ACTIVITY_PACK
		return
	if(attempt_ambush_hide())
		idle_activity = IDLE_ACTIVITY_AMBUSH
		return
	if(attempt_slash_infrastructure())
		idle_activity = IDLE_ACTIVITY_SABOTAGE
		return
	if(prob(AI_XENO_LONG_PATROL_CHANCE) && start_long_patrol())
		idle_activity = IDLE_ACTIVITY_LONG_PATROL
		return
	if(attempt_social_interaction())
		idle_activity = IDLE_ACTIVITY_SOCIAL
		return
	idle_activity = IDLE_ACTIVITY_WANDER
	wander()

/**
 * "Patrol should actually be a long path as the hive radius expands. It
 * should also allow leaving the hive completely to look for targets, so
 * xenomorphs can patrol as far as the Landing Zone" - a deliberate long-
 * range trek, distinct from wander()'s tight local drift around anchor_turf
 * (which stays exactly as bounded as before - this is an additional, lower-
 * priority idle option, not a replacement). Sometimes heads specifically
 * for the marine LZ if one's been chosen (get_lz_turf() - shared with
 * attempt_ambush_hide()/queen.dm's siege response), otherwise a random
 * point out at the current long-patrol radius, which grows over the course
 * of the round (current_patrol_radius()) rather than staying fixed - "as
 * the hive radius expands," approximated by round time the same way the
 * Queen's own scout_radius already does, since a real live weed-coverage
 * measurement isn't cheap to compute every roll.
 */
/datum/xeno_ai_controller/proc/start_long_patrol()
	if(!pilot || !anchor_turf)
		return FALSE

	var/turf/destination
	if(prob(AI_XENO_LONG_PATROL_LZ_CHANCE))
		destination = get_lz_turf()
	if(!destination)
		var/radius = current_patrol_radius()
		var/target_x = clamp(anchor_turf.x + rand(-radius, radius), 1, world.maxx)
		var/target_y = clamp(anchor_turf.y + rand(-radius, radius), 1, world.maxy)
		destination = locate(target_x, target_y, anchor_turf.z)
	if(!destination || get_dist(anchor_turf, destination) < AI_XENO_PATROL_RADIUS)
		return FALSE // Not actually a long trip - let plain wander() cover short-range movement instead.

	patrol_turf = destination
	continue_long_patrol()
	return TRUE

/// Walks one step of an already-started long patrol leg; drops it once arrived or genuinely stuck, letting the next idle tick's rolls decide what to do next.
/datum/xeno_ai_controller/proc/continue_long_patrol()
	if(!pilot || !patrol_turf)
		return
	if(get_dist(pilot, patrol_turf) <= 1)
		patrol_turf = null
		return
	if(!advance_along_path(patrol_turf) && !cardinal_step_towards(patrol_turf, avoid_mobs = TRUE))
		patrol_turf = null // Truly stuck - drop it rather than grinding against the same obstacle forever.

/// Current long-patrol radius from anchor_turf - grows with round time up to a cap, approximating "as the hive radius expands." Also used by start_long_patrol() as the minimum distance worth calling a "long" trip at all.
/datum/xeno_ai_controller/proc/current_patrol_radius()
	var/minutes_elapsed = (world.time - SSticker.round_start_time) / (1 MINUTES)
	return min(AI_XENO_PATROL_RADIUS + round(minutes_elapsed * AI_XENO_LONG_PATROL_RADIUS_GROWTH_PER_MINUTE), AI_XENO_LONG_PATROL_RADIUS_MAX)

/**
 * "Add in a group mechanic to allow xenos to stick together sometimes in a
 * group" - a loose, probabilistic pull toward a nearby same-hive ally who's
 * also just idling/patrolling (not one already off fighting/dragging/vent-
 * crawling - chasing a busy ally isn't cohesion, that's respond_to_hive_alert()'s
 * job), rather than a hard formation system. Queen/King are excluded as
 * buddies - they already have their own dedicated escort/command mechanics,
 * this is specifically the rank-and-file loosely clumping up.
 */
/datum/xeno_ai_controller/proc/respond_to_pack_cohesion()
	if(!pilot || pilot.resting)
		return FALSE
	if(!prob(AI_PACK_COHESION_CHANCE))
		return FALSE
	var/mob/living/carbon/xenomorph/buddy = find_pack_buddy()
	if(!buddy)
		return FALSE
	if(get_dist(pilot, buddy) <= AI_PACK_COHESION_HOLD_DISTANCE)
		return FALSE // Already close enough to read as "sticking together" - nothing more to do this tick.
	if(!advance_along_path(buddy))
		cardinal_step_towards(buddy, avoid_mobs = TRUE)
	return TRUE

/// Nearest other idle/patrolling same-hive xeno within pack range - see respond_to_pack_cohesion().
/datum/xeno_ai_controller/proc/find_pack_buddy()
	var/mob/living/carbon/xenomorph/best
	var/best_dist = INFINITY
	for(var/mob/living/carbon/xenomorph/ally as anything in GLOB.ai_xeno_list)
		if(ally == pilot || ally.stat == DEAD || ally.hivenumber != pilot.hivenumber)
			continue
		if(ally.caste_type == XENO_CASTE_QUEEN || ally.caste_type == XENO_CASTE_KING)
			continue
		var/datum/xeno_ai_controller/ally_controller = ally.ai_controller
		if(!ally_controller || ally_controller.ai_state != AI_STATE_IDLE)
			continue
		var/d = get_dist(pilot, ally)
		if(d < AI_PACK_COHESION_HOLD_DISTANCE || d > AI_XENO_PATROL_RADIUS * 2)
			continue
		if(d < best_dist)
			best_dist = d
			best = ally
	return best

/**
 * "Idle or AI to AI interactions should be a thing, bullying, playing, so
 * on" - purely cosmetic flavor so a hive of 30+ always-idling AI xenos reads
 * as alive instead of a room full of standing statues. Deliberately no
 * mechanical effect whatsoever - no damage, no plasma cost, nothing that
 * changes either xeno's actual state beyond the emote/flavor text and one
 * cosmetic step. Lowest priority in patrol() - only rolled once genuinely
 * nothing else is going on.
 *
 * Picks between two vignettes based on relative size: a clearly bigger/
 * higher-tier same-hive ally "bullies" a smaller one (a mock lunge that
 * shoves the smaller one back a step) - anything roughly matched in size
 * "plays" instead (a harmless mutual hiss/growl/tail-swipe exchange, nobody
 * moves). Both participants go on the same cooldown so the same pair can't
 * loop the same vignette back to back.
 */
/datum/xeno_ai_controller/proc/attempt_social_interaction()
	if(!pilot || world.time < next_social_interaction)
		return FALSE
	if(!prob(AI_XENO_SOCIAL_CHANCE))
		return FALSE

	var/mob/living/carbon/xenomorph/buddy = find_social_buddy()
	if(!buddy)
		return FALSE

	next_social_interaction = world.time + AI_XENO_SOCIAL_COOLDOWN
	var/datum/xeno_ai_controller/buddy_controller = buddy.ai_controller
	if(buddy_controller)
		buddy_controller.next_social_interaction = world.time + AI_XENO_SOCIAL_COOLDOWN

	pilot.setDir(get_dir(pilot, buddy))
	var/pilot_dominant = (pilot.tier > buddy.tier) || (pilot.tier == buddy.tier && pilot.mob_size > buddy.mob_size)
	if(pilot_dominant)
		pilot.emote("roar")
		pilot.visible_message(SPAN_XENODANGER("[pilot] lunges at [buddy], bullying [buddy.p_them()] back!"), null, null, 5)
		buddy_controller?.ai_step_avoiding_mobs(get_dir(pilot, buddy))
	else
		pilot.emote(pick("hiss", "growl", "tail"))
		pilot.visible_message(SPAN_XENONOTICE("[pilot] roughhouses playfully with [buddy]!"), null, null, 5)
	return TRUE

/// Nearest other truly-idle same-hive xeno within AI_XENO_SOCIAL_RANGE - see attempt_social_interaction(). Much tighter range than find_pack_buddy() - a "bumped into each other" vignette only reads right at point-blank range.
/datum/xeno_ai_controller/proc/find_social_buddy()
	var/mob/living/carbon/xenomorph/best
	var/best_dist = INFINITY
	for(var/mob/living/carbon/xenomorph/ally as anything in GLOB.ai_xeno_list)
		if(ally == pilot || ally.stat == DEAD || ally.hivenumber != pilot.hivenumber)
			continue
		if(ally.caste_type == XENO_CASTE_QUEEN || ally.caste_type == XENO_CASTE_KING)
			continue
		if(ally.resting || ally.layer == XENO_HIDING_LAYER)
			continue
		var/datum/xeno_ai_controller/ally_controller = ally.ai_controller
		if(!ally_controller || ally_controller.ai_state != AI_STATE_IDLE || world.time < ally_controller.next_social_interaction)
			continue
		var/d = get_dist(pilot, ally)
		if(d > AI_XENO_SOCIAL_RANGE)
			continue
		if(d < best_dist)
			best_dist = d
			best = ally
	return best

/**
 * "Gather intel on positions in the map for ambush or defense building" /
 * "hiding to ambush" - a low-probability idle detour that walks out toward
 * the marine LZ (get_lz_turf(), shared with queen.dm's own siege-response
 * use of it) and actually hides there via xenohide for a while, instead of
 * only ever aimlessly wandering near the hive. Interrupted for free the
 * moment a real target shows up - process_target() unhides and clears this
 * state as soon as she has something better to do (see the check there).
 */
/datum/xeno_ai_controller/proc/attempt_ambush_hide()
	if(!pilot)
		return FALSE

	if(ambush_turf)
		if(get_dist(pilot, ambush_turf) > 0)
			if(!advance_along_path(ambush_turf))
				cardinal_step_towards(ambush_turf, avoid_mobs = TRUE)
			return TRUE
		if(!ambush_hiding)
			ambush_hiding = TRUE
			ambush_hide_until = world.time + AI_XENO_AMBUSH_HIDE_DURATION
			var/datum/action/xeno_action/onclick/xenohide/hide = get_ability(/datum/action/xeno_action/onclick/xenohide)
			hide?.use_ability(pilot)
			return TRUE
		if(world.time >= ambush_hide_until)
			end_ambush_hide()
			return FALSE
		return TRUE

	if(!prob(AI_XENO_AMBUSH_CHANCE))
		return FALSE
	var/turf/lz_turf = get_lz_turf()
	if(!lz_turf)
		return FALSE

	var/list/candidates = list()
	for(var/turf/candidate in range(AI_XENO_AMBUSH_LZ_RADIUS, lz_turf))
		if(candidate.density || get_dist(candidate, lz_turf) < 3) // Not right on top of the LZ itself - "hiding nearby," not standing in the open on it.
			continue
		candidates += candidate
	if(!length(candidates))
		return FALSE

	ambush_turf = pick(candidates)
	if(!advance_along_path(ambush_turf))
		cardinal_step_towards(ambush_turf, avoid_mobs = TRUE)
	return TRUE

/// Un-hides (if actually hidden) and clears ambush state - shared by attempt_ambush_hide()'s timeout and process_target()'s interrupt-on-contact.
/datum/xeno_ai_controller/proc/end_ambush_hide()
	if(pilot && pilot.layer == XENO_HIDING_LAYER)
		var/datum/action/xeno_action/onclick/xenohide/hide = get_ability(/datum/action/xeno_action/onclick/xenohide)
		hide?.use_ability(pilot)
	ambush_turf = null
	ambush_hiding = FALSE
	ambush_hide_until = 0

/// Turf of the active marine LZ, if any - shared by queen.dm's LZ-siege response and attempt_ambush_hide().
/datum/xeno_ai_controller/proc/get_lz_turf()
	var/datum/game_mode/mode = SSticker.mode
	if(!mode || !mode.active_lz)
		return null
	return get_turf(mode.active_lz)

/**
 * "AI should slash lights and wall apc's" - darkening an area and killing
 * local power (cameras, turrets, and doors all lose power with it) is a real,
 * valuable tactic that nothing previously did outside of one happening to be
 * directly in the way of a chase. An idle-priority detour, same tier as
 * attempt_ambush_hide() - walks to and claws a still-standing
 * /obj/structure/machinery/light or /obj/structure/machinery/power/apc within
 * range, via the same direct attack_alien() call attack_blocking_obstacle()
 * (xeno_ai_movement.dm) already uses for obstacles.
 */
/datum/xeno_ai_controller/proc/attempt_slash_infrastructure()
	if(!pilot || !prob(AI_XENO_INFRASTRUCTURE_SLASH_CHANCE))
		return FALSE

	var/obj/target = find_nearby_infrastructure_target()
	if(!target)
		return FALSE

	if(!pilot.Adjacent(target))
		if(!advance_along_path(target))
			cardinal_step_towards(target, avoid_mobs = TRUE)
		return TRUE

	if(world.time <= pilot.next_move)
		return TRUE
	pilot.setDir(get_dir(pilot, target))
	pilot.a_intent = INTENT_HARM
	target.attack_alien(pilot)
	if(pilot) // attack_alien() can in principle retaliate (an exploding structure) - don't write to a dead/deleted pilot.
		pilot.next_move = world.time + XENO_MELEE_ATTACK_DELAY
	return TRUE

/// Nearest still-standing light or APC within AI_XENO_INFRASTRUCTURE_SEARCH_RADIUS - see attempt_slash_infrastructure().
/datum/xeno_ai_controller/proc/find_nearby_infrastructure_target()
	if(!pilot)
		return null
	var/obj/best
	var/best_dist = INFINITY
	for(var/obj/structure/machinery/light/light in range(AI_XENO_INFRASTRUCTURE_SEARCH_RADIUS, pilot))
		if(light.unslashable || light.is_broken())
			continue
		var/d = get_dist(pilot, light)
		if(d < best_dist)
			best_dist = d
			best = light
	for(var/obj/structure/machinery/power/apc/apc in range(AI_XENO_INFRASTRUCTURE_SEARCH_RADIUS, pilot))
		if(apc.unslashable || apc.health <= 0)
			continue
		var/d = get_dist(pilot, apc)
		if(d < best_dist)
			best_dist = d
			best = apc
	return best

/**
 * Idle xenos actively range around their anchor instead of standing
 * perfectly still or jittering in place - makes an idle group look and
 * behave alive, doubling as a real patrol rather than a tight tether.
 * Bounded to AI_XENO_PATROL_RADIUS (well inside return_distance) so it
 * never turns into an unbounded wander; a mob that's drifted to the edge
 * heads back in instead of continuing outward.
 *
 * Also opportunistically rests to heal: not just when returning home
 * critically hurt (see return_to_anchor()), but any time it's idle,
 * standing on healing-eligible weeds, and not already at full health - a
 * low per-tick chance, so it reads as "resting when there's nothing better
 * to do" rather than stopping mid-patrol constantly. Stands back up on its
 * own once fully healed (process_target() already stands it up immediately
 * if a target shows up first) instead of lying there forever once healed.
 */
/datum/xeno_ai_controller/proc/wander()
	if(!pilot || !anchor_turf)
		return
	if(pilot.resting)
		// "Don't know how to stop resting once they start" - health-based
		// wakeup was the only exit condition; a rest_timeout safety net now
		// forces her back up regardless if healing ever stalls out short of
		// full (permanent limb damage, etc.) instead of resting forever.
		if(pilot.health >= pilot.maxHealth || world.time >= rest_timeout)
			pilot.set_resting(FALSE)
		return // Still healing up - don't get up and wander off mid-heal.
	if(pilot.health < pilot.maxHealth)
		// "Resting when there is no weed" - check_weeds_for_healing() sounds
		// like "am I on weeds" but actually means "can I heal decently
		// here," which is TRUE unconditionally for any caste with
		// need_weeds == FALSE regardless of whether any weeds are actually
		// present (life.dm) - exactly why she'd rest anywhere. Checking for
		// an actual owned weed tile directly instead.
		var/obj/effect/alien/weeds/own_weeds = locate(/obj/effect/alien/weeds) in get_turf(pilot)
		var/on_own_weeds = own_weeds && own_weeds.linked_hive.is_ally(pilot)
		if(on_own_weeds)
			if(prob(AI_XENO_OPPORTUNISTIC_REST_CHANCE))
				pilot.set_resting(TRUE)
				rest_timeout = world.time + AI_XENO_MAX_REST_DURATION
				return
		else if(prob(AI_XENO_PATROL_CHANCE))
			// "They never look for weeds to rest on" - seeks one out instead
			// of only ever being eligible to rest on whichever tile she
			// happened to already be standing on.
			var/turf/nearest_weed = find_nearest_hive_weed_turf()
			if(nearest_weed)
				if(!advance_along_path(nearest_weed))
					cardinal_step_towards(nearest_weed, avoid_mobs = TRUE)
				return
	if(pilot.on_fire && pilot.can_resist())
		pilot.resist() // Opportunistic while idle - see should_flee()'s doc comment for why this isn't a forced reflex mid-fight any more.

	// "They need to stop at some point and rest or stay dormant if they have
	// nothing to do" / "lag is an issue, moving as a player is painfully
	// slow" - continuous per-tile stepping (below) is only cheap in
	// aggregate if a good chunk of the idle population isn't doing it at any
	// given moment. Checked before the anchor-distance snap-back too, so a
	// dormant xeno standing a little outside AI_XENO_PATROL_RADIUS just
	// stays put rather than being forced to walk back while "resting."
	if(dormant_until && world.time < dormant_until)
		return
	dormant_until = 0

	if(get_dist(pilot, anchor_turf) >= AI_XENO_PATROL_RADIUS)
		wander_dir = null // Snap back to anchor - re-roll a fresh heading once back in range instead of resuming whatever direction led out of it.
		cardinal_step_towards(anchor_turf, avoid_mobs = TRUE)
		return

	// Commits to a heading for AI_XENO_WANDER_COMMIT_TIME instead of picking a
	// brand new random direction on every single successful roll - the latter
	// is what "moving one tile back and forth, not going anywhere" turned out
	// to be: a fresh coin-flip over 8 directions every ~1.5s has good odds of
	// picking near-opposite directions on consecutive rolls, which reads as
	// jittering in place rather than an actual patrol sweeping the area.
	// Re-rolls early if the committed direction becomes blocked, so it
	// doesn't sit there repeatedly failing into a wall for the rest of the
	// commit window either.
	if(!wander_dir || world.time >= next_wander_reroll)
		// Heading either never set or just expired - decide whether to keep
		// pacing or go dormant for a while instead of always picking a fresh
		// one. Jitter is fully handled by the heading-commitment itself, not
		// by this roll - this is purely a "how much of the population is
		// actively moving right now" throttle.
		if(prob(AI_XENO_DORMANT_CHANCE))
			wander_dir = null
			dormant_until = world.time + rand(AI_XENO_DORMANT_MIN_DURATION, AI_XENO_DORMANT_MAX_DURATION)
			return
		wander_dir = pick(GLOB.alldirs)
		next_wander_reroll = world.time + AI_XENO_WANDER_COMMIT_TIME

	if(!ai_step_avoiding_mobs(wander_dir))
		wander_dir = null // Blocked - force a fresh decision (walk or dormant) next tick instead of retrying the same blocked heading.

/**
 * "They don't try patting their allies who are on fire" - a xeno clawing
 * another xeno with INTENT_HELP while it's burning pats the fire out
 * (attack_alien() on the xenomorph-vs-xenomorph path, XenoAttacks.dm) -
 * this AI never triggered that interaction at all. Checked near the top of
 * patrol() (an ally on fire is an emergency, same priority tier as a hive
 * alert) - walks to the nearest burning same-hive ally and pats them out
 * once adjacent.
 */
/datum/xeno_ai_controller/proc/attempt_help_burning_ally()
	if(!pilot)
		return FALSE
	var/mob/living/carbon/xenomorph/burning_ally
	var/best_dist = INFINITY
	for(var/mob/living/carbon/xenomorph/ally as anything in GLOB.ai_xeno_list)
		if(ally == pilot || ally.stat == DEAD || ally.hivenumber != pilot.hivenumber || !ally.on_fire)
			continue
		var/d = get_dist(pilot, ally)
		if(d > AI_XENO_PATROL_RADIUS * 2)
			continue
		if(d < best_dist)
			best_dist = d
			burning_ally = ally
	if(!burning_ally)
		return FALSE

	if(!pilot.Adjacent(burning_ally))
		if(!advance_along_path(burning_ally))
			cardinal_step_towards(burning_ally, avoid_mobs = TRUE)
		return TRUE

	pilot.a_intent = INTENT_HELP
	burning_ally.attack_alien(pilot)
	return TRUE

/// Nearest turf with a same-hive weed within a bounded radius of anchor_turf - shared by wander()'s weed-seeking and (formerly) larva.dm's own copy of this. Cheap bounded scan, not something every population-scale caste calling it occasionally can't afford.
/datum/xeno_ai_controller/proc/find_nearest_hive_weed_turf()
	if(!pilot || !anchor_turf)
		return null
	var/turf/best
	var/best_dist = INFINITY
	for(var/obj/effect/alien/weeds/weed in range(AI_XENO_PATROL_RADIUS * 2, anchor_turf))
		if(weed.linked_hive.hivenumber != pilot.hivenumber)
			continue
		var/d = get_dist(pilot, weed)
		if(d < best_dist)
			best_dist = d
			best = get_turf(weed)
	return best

/**
 * "Drones, hivelords, and queens should use pheromones to assist in combat" -
 * fires once on first contact with a target (see process_target() above),
 * not every tick, since emit_pheromones() is a toggle (current_aura already
 * blocks re-triggering the same one). Passing the pheromone string directly
 * skips the whole tgui/radial menu prompt inside emit_pheromones() - that
 * branch only runs when called with none, so this is safe for a clientless
 * AI mob the same way the other direct ability calls in this file are.
 * Frenzy (run speed/damage) over Warding/Recovery - she's picking a fight,
 * not stabilizing one already going badly. Requires actual nearby support to
 * bother - alone, an aura buffing nobody but herself isn't worth the plasma.
 */
/datum/xeno_ai_controller/proc/attempt_combat_pheromones()
	if(!pilot || pilot.current_aura)
		return FALSE
	if(!(locate(/datum/action/xeno_action/onclick/emit_pheromones) in pilot.actions))
		return FALSE
	if(count_nearby_hive_allies(7) < 1)
		return FALSE
	if(!pilot.check_plasma(AI_XENO_PHEROMONE_COST))
		return FALSE
	pilot.emit_pheromones("frenzy", AI_XENO_PHEROMONE_COST)
	return TRUE

/// Shared by drone_worker.dm and queen.dm - calls the real plant_weeds ability directly. Its own internal checks (weedable ground, not already weeded enough, hive ownership) handle rejection silently if the current tile isn't suitable, same as a player clicking it somewhere bad, so this is safe to roll speculatively.
/datum/xeno_ai_controller/proc/attempt_plant_weeds()
	var/datum/action/xeno_action/onclick/plant_weeds/action = get_ability(/datum/action/xeno_action/onclick/plant_weeds)
	if(!action)
		return FALSE
	action.use_ability(pilot)
	return TRUE

/**
 * Shared by drone_worker.dm/hivelord.dm/burrower.dm - "resin wall/door
 * fortress pattern at hive perimeter" instead of only ever plant_weeds().
 * Bypasses the click/tgui resin-picker layer entirely (choose_resin.dm) the
 * same way every other AI ability call in this file does: sets selected_resin
 * directly to a plain wall type from the pilot's own resin_build_order, then
 * calls build_resin() (Powers.dm) directly - the same proc a player's
 * secrete_resin click ultimately reaches. can_build_here() is checked first
 * so this can be rolled speculatively same as attempt_plant_weeds() - a bad
 * tile (no owned weeds, already something built there, an unweedable area)
 * just silently no-ops instead of spamming a doomed build attempt.
 *
 * "Hivelords and drones aren't building resin structures manually" - the
 * original version picked a perimeter turf and immediately tried to build on
 * it with no regard for where the pilot actually was standing. build_resin()
 * (Powers.dm) hard-requires get_dist(pilot, target) <= caste.max_build_dist,
 * which is 0 for a Drone - meaning it only ever worked by pure chance that
 * the randomly-picked perimeter turf happened to already be the pilot's own
 * tile. Now walks to the committed build site first (re-rolling a fresh
 * candidate every call, like the old version did, would have the pilot
 * flip-flop between different perimeter turfs and never arrive at any of
 * them) and only actually builds once in range.
 */
/datum/xeno_ai_controller/proc/attempt_build_defense()
	if(!pilot || !anchor_turf)
		return FALSE

	if(build_target_turf)
		var/datum/resin_construction/committed_construction = GLOB.resin_constructions_list[build_target_wall_type]
		if(!committed_construction || !committed_construction.can_build_here(build_target_turf, pilot))
			build_target_turf = null
			build_target_wall_type = null
		else if(get_dist(pilot, build_target_turf) > pilot.caste.max_build_dist)
			if(!advance_along_path(build_target_turf))
				cardinal_step_towards(build_target_turf, avoid_mobs = TRUE)
			return TRUE
		else
			pilot.selected_resin = build_target_wall_type
			pilot.build_resin(build_target_turf)
			build_target_turf = null
			build_target_wall_type = null
			return TRUE

	var/wall_type = get_defense_wall_type()
	if(!wall_type)
		return FALSE
	var/datum/resin_construction/wall_construction = GLOB.resin_constructions_list[wall_type]
	if(!wall_construction)
		return FALSE

	var/turf/build_turf = pick_defense_perimeter_turf()
	if(!build_turf || !wall_construction.can_build_here(build_turf, pilot))
		return FALSE

	build_target_turf = build_turf
	build_target_wall_type = wall_type
	return TRUE

/// Wall or door option this pilot's caste can build, picked randomly between the two when both exist - "walls and doors," not only ever walls.
/datum/xeno_ai_controller/proc/get_defense_wall_type()
	if(!pilot?.resin_build_order)
		return null
	var/list/options = list()
	for(var/build_type in pilot.resin_build_order)
		if(findtext("[build_type]", "resin_turf/wall") || findtext("[build_type]", "resin_obj/door"))
			options += build_type
	if(!length(options))
		return null
	return pick(options)

/**
 * A turf in the perimeter band that's actually already weeded and owned by
 * the hive - can_build_here() hard-requires existing owned weeds on the
 * target tile, so picking a blind random turf in the band (the old
 * behavior) almost never actually landed on buildable ground, which is why
 * walls/doors essentially never got built at all. Falls back to any owned
 * weed tile regardless of distance band if nothing qualifies in the ideal
 * band, rather than giving up outright.
 *
 * "Building defenses all over the map" - centered on the pilot's own current
 * position rather than anchor_turf, so a Drone/Hivelord that's wandered or
 * long-patrolled out to newly-weeded territory as the hive's coverage grows
 * over a round builds defenses out there too, instead of every wall/door
 * getting placed within the same fixed ring around the original hive core
 * regardless of how far the hive itself has since spread. anchor_turf is
 * still required as the "does this xeno have a home hive at all" gate.
 */
/datum/xeno_ai_controller/proc/pick_defense_perimeter_turf()
	if(!pilot || !anchor_turf)
		return null
	var/turf/search_center = get_turf(pilot)
	if(!search_center)
		return null
	var/list/ideal_candidates = list()
	var/list/fallback_candidates = list()
	for(var/obj/effect/alien/weeds/weed in range(AI_XENO_DEFENSE_PERIMETER_MAX_RADIUS, search_center))
		if(weed.linked_hive.hivenumber != pilot.hivenumber)
			continue
		var/turf/weed_turf = get_turf(weed)
		if(!weed_turf)
			continue
		if(get_dist(weed_turf, search_center) >= AI_XENO_DEFENSE_PERIMETER_MIN_RADIUS)
			ideal_candidates += weed_turf
		else
			fallback_candidates += weed_turf
	if(length(ideal_candidates))
		return pick(ideal_candidates)
	if(length(fallback_candidates))
		return pick(fallback_candidates)
	return null

/**
 * "Drones and hivelords should plant eggs in the hive too" / "carrier will
 * restock on eggs as well" - the Queen already drops loose /obj/item/xeno_egg
 * items on her own tile automatically while on the ovipositor (Queen.dm's
 * Life(): "one egg approximately every 30 seconds"), exactly like a real
 * round; nothing ever picked any of them back up. Mirrors the real player
 * mechanics instead of inventing new ones: a Drone/Hivelord carries a loose
 * egg out to good weeded ground away from the Queen's own tile (so eggs
 * spread through the hive instead of piling up where they dropped - Queen.dm
 * caps her own tile at 25 objects before she stops laying entirely, so
 * clearing them is also what keeps her able to keep producing) and plants it
 * there (egg_item.dm's attack_self()/plant_egg(), the same entry point a
 * player's own click reaches). A Carrier instead stores it internally
 * (store_egg(), Carrier.dm) to restock her own eggs_cur/eggs_max supply for
 * later use, same as a player Carrier walking over and grabbing one.
 */
/// TRUE if the pilot is already mid-delivery with an egg in hand - see attempt_carry_egg()'s callers, which always let an in-progress carry finish regardless of their own priority roll for picking a fresh one up.
/datum/xeno_ai_controller/proc/is_carrying_egg()
	return pilot && (istype(pilot.r_hand, /obj/item/xeno_egg) || istype(pilot.l_hand, /obj/item/xeno_egg))

/datum/xeno_ai_controller/proc/attempt_carry_egg()
	if(!pilot || pilot.caste.can_hold_eggs == CANNOT_HOLD_EGGS)
		return FALSE

	var/mob/living/carbon/xenomorph/carrier/carrier_pilot
	if(iscarrier(pilot))
		carrier_pilot = pilot
		if(carrier_pilot.eggs_cur >= carrier_pilot.eggs_max)
			return FALSE // Already full - nothing more to restock.

	var/obj/item/xeno_egg/carried = istype(pilot.r_hand, /obj/item/xeno_egg) ? pilot.r_hand : (istype(pilot.l_hand, /obj/item/xeno_egg) ? pilot.l_hand : null)
	if(carried)
		if(!egg_plant_turf || !istype(egg_plant_turf))
			egg_plant_turf = pick_defense_perimeter_turf() // Reuses the same "owned weeds away from anchor" picker used for wall placement.
		if(!egg_plant_turf)
			return FALSE
		if(get_dist(pilot, egg_plant_turf) > 0)
			if(!advance_along_path(egg_plant_turf))
				cardinal_step_towards(egg_plant_turf, avoid_mobs = TRUE)
			return TRUE
		carried.attack_self(pilot) // Same entry point a player's own click reaches - handles the store_egg()/plant_egg() branch itself.
		egg_plant_turf = null
		return TRUE

	if(pilot.r_hand || pilot.l_hand)
		return FALSE // Hands full with something else already - not our business to drop it.

	var/obj/item/xeno_egg/nearest_egg
	var/best_dist = INFINITY
	for(var/obj/item/xeno_egg/egg in range(AI_XENO_EGG_SEARCH_RADIUS, pilot))
		if(egg.hivenumber != pilot.hivenumber)
			continue
		var/d = get_dist(pilot, egg)
		if(d < best_dist)
			best_dist = d
			nearest_egg = egg
	if(!nearest_egg)
		return FALSE

	if(!pilot.Adjacent(nearest_egg))
		if(!advance_along_path(nearest_egg))
			cardinal_step_towards(nearest_egg, avoid_mobs = TRUE)
		return TRUE

	if(carrier_pilot)
		carrier_pilot.store_egg(nearest_egg) // Direct to internal storage - a Carrier never plants eggs herself.
	else
		nearest_egg.attack_alien(pilot) // Picks it up into a free hand, same as a player's own unarmed click.
	return TRUE

/**
 * "They don't even help the queen build her core" - travels to and weeds
 * the Queen's own tile whenever the hive has no Hive Core yet, instead of
 * every builder independently weeding/building wherever it happens to be
 * standing with no regard for what she actually needs ground for right now.
 * Shared by drone_worker.dm/hivelord.dm/burrower.dm, checked before their
 * own independent build rolls.
 */
/datum/xeno_ai_controller/proc/attempt_help_queen_build_core()
	if(!pilot || !pilot.hive || pilot.hive.has_structure(XENO_STRUCTURE_CORE))
		return FALSE
	var/mob/living/carbon/xenomorph/queen/living_queen = pilot.hive.living_xeno_queen
	if(!living_queen || living_queen == pilot || living_queen.stat == DEAD)
		return FALSE
	if(get_dist(pilot, living_queen) > 1)
		if(!advance_along_path(living_queen))
			cardinal_step_towards(living_queen)
		return TRUE
	return attempt_plant_weeds() // Already at her side - weed the ground she needs to build the core on.

/**
 * "Queen escort and commanding thing isn't working at all" - shared by
 * respond_to_hive_alert()/respond_to_queen_escort() below, which used to be
 * a bare advance_along_path()/
 * cardinal_step_towards() with none of the obstacle handling the main chase
 * path (process_movement()) has - no skirt/climb-or-smash/navigate_around
 * fallback at all, so a table, wall, or long detour between here and the
 * broadcast point left her just walking at it and getting nowhere, same
 * root cause return_to_anchor() had. No blocked_attempts give-up needed
 * here the way the chase/flee paths need one - this only ever runs for one
 * idle patrol tick at a time, so a genuinely stuck pilot just tries
 * something else next tick instead of committing to one destination.
 */
/datum/xeno_ai_controller/proc/travel_to_broadcast_turf(turf/destination)
	if(!pilot || !destination)
		return
	if(attempt_skirt_obstacle())
		return
	if(advance_along_path(destination))
		return
	if(cardinal_step_towards(destination))
		return

	var/obj/structure/climbable_obstacle = get_climbable_obstacle(destination)
	if(climbable_obstacle)
		if(should_smash_instead_of_climb(climbable_obstacle))
			attack_blocking_obstacle(climbable_obstacle)
			return
		if(attempt_climb_obstacle(climbable_obstacle))
			return

	var/atom/blocking_obstacle = get_blocking_obstacle(destination)
	if(blocking_obstacle)
		attack_blocking_obstacle(blocking_obstacle)
		return

	navigate_around(destination)

/**
 * "Coordination with other AI xenos is very poor" / King never called
 * anything analogous to Queen's own alert/escort broadcasts, so other AI
 * xenos never rallied to a fight he was personally in. Promoted off the
 * Queen controller onto the base one - nothing in either proc actually used
 * anything Queen-specific (just generic hive/mob access), it was just typed
 * to her subtype - so both Queen (via her own tick() override, unchanged)
 * and King (see king.dm) can call the same two procs.
 */
/datum/xeno_ai_controller/proc/broadcast_hive_alert(mob/living/carbon/xenomorph/boss_pilot)
	if(!boss_pilot.hive || !current_target)
		return
	boss_pilot.hive.queen_alert_turf = get_turf(current_target)
	boss_pilot.hive.queen_alert_time = world.time

/// Living same-hive AI xenos within radius tiles of boss_pilot - backs broadcast_escort_call()'s decision on whether it already has enough of a bodyguard.
/datum/xeno_ai_controller/proc/count_nearby_escorts(mob/living/carbon/xenomorph/boss_pilot, radius)
	var/count = 0
	for(var/mob/living/carbon/xenomorph/hive_member as anything in GLOB.ai_xeno_list)
		if(hive_member == boss_pilot || hive_member.hivenumber != boss_pilot.hivenumber || hive_member.stat == DEAD)
			continue
		if(get_dist(boss_pilot, hive_member) <= radius)
			count++
	return count

/**
 * Calls nearby daughters to physically rally on boss_pilot, distinct from
 * broadcast_hive_alert() (which points at the threat, not at her/him) -
 * "the Queen must be escorted when in combat by no less than 5 and up to
 * 10 daughters," same standing-call-for-backup reasoning applied to King.
 */
/datum/xeno_ai_controller/proc/broadcast_escort_call(mob/living/carbon/xenomorph/boss_pilot, heavy_siege)
	if(!boss_pilot.hive)
		return
	if(!current_target && !heavy_siege)
		return
	if(count_nearby_escorts(boss_pilot, AI_QUEEN_ESCORT_RADIUS) >= AI_QUEEN_ESCORT_MAX)
		return
	boss_pilot.hive.queen_escort_turf = get_turf(boss_pilot)
	boss_pilot.hive.queen_escort_time = world.time

/// Same-hive living xenos already within radius of a point, regardless of state - a crude "how crowded is it there already" gauge, distinct from count_active_combatants_near() (which only counts APPROACHING/ATTACKING - a xeno walking toward a hive-alert never actually enters that state, since patrol()'s callers are all reached only while ai_state is still IDLE).
/datum/xeno_ai_controller/proc/count_nearby_hive_members(turf/center_turf, radius)
	if(!pilot || !center_turf)
		return 0
	var/count = 0
	for(var/mob/living/carbon/xenomorph/hive_member as anything in GLOB.ai_xeno_list)
		if(hive_member == pilot || hive_member.hivenumber != pilot.hivenumber || hive_member.stat == DEAD)
			continue
		if(get_dist(hive_member, center_turf) <= radius)
			count++
	return count

/**
 * Every other targeting primitive in this file is hostile-only - nothing before this let a
 * controller find a *friendly* xeno to heal or buff. Backs strain abilities that target an
 * ally instead of an enemy (Healer's Apply Salve/Sacrifice, Valkyrie's Rage/Prae Retrieve -
 * see Phase 2 plan §2.2). Picks among the most-hurt candidates rather than always the exact
 * nearest, same "don't always land on the same one" tie-break find_cover_turf() already uses.
 */
/datum/xeno_ai_controller/proc/find_nearby_ally_xeno(radius = AI_XENO_ALLY_SCAN_RADIUS, require_damaged = TRUE)
	if(!pilot)
		return null
	var/list/candidates = list()
	var/worst_health_fraction = 1
	// GLOB.xeno_mob_list already contains every xenomorph mob, AI-piloted or
	// not (Xenomorph.dm's New()) - GLOB.ai_xeno_list is a strict subset of
	// it, so "+ GLOB.ai_xeno_list" was allocating a fresh concatenated list
	// (with every AI xeno duplicated in it) on every single call for no
	// actual coverage gain. Real cost: this runs from patrol()/idle-tick
	// procs (Healer's Apply Salve/Sacrifice, Valkyrie's Rage/Fight or
	// Flight/Retrieve) for every Healer/Valkyrie in the hive, every idle
	// heartbeat - population-scaling waste, not correctness.
	for(var/mob/living/carbon/xenomorph/ally as anything in GLOB.xeno_mob_list)
		if(ally == pilot || ally.hivenumber != pilot.hivenumber || ally.stat == DEAD)
			continue
		if(get_dist(pilot, ally) > radius)
			continue
		if(!ally.maxHealth)
			continue
		var/health_fraction = ally.health / ally.maxHealth
		if(require_damaged && health_fraction >= 1)
			continue
		if(health_fraction < worst_health_fraction)
			worst_health_fraction = health_fraction
			candidates = list(ally)
		else if(health_fraction <= worst_health_fraction + 0.05)
			candidates += ally
	return length(candidates) ? pick(candidates) : null

/**
 * Checks for a live hive-wide alert (see hive_status.dm's queen_alert_turf/
 * queen_alert_time, set by the Queen controller) and heads there if one
 * exists and hasn't gone stale. Returns FALSE (meaning "nothing to respond
 * to, fall back to normal idle behavior") if the pilot has no hive, no alert
 * is active, the alert is too old, the pilot is already close enough that
 * normal target scanning should take over instead, or enough same-hive
 * xenos are already converging (AI_XENO_HIVE_ALERT_MAX_RESPONDERS - "the
 * queen ordering the other aliens shouldn't be the only way they behave,
 * ultimately they'd scout, weed, take over sections of the map on their
 * own"; unbounded participation also meant a Queen stuck on one bad target
 * could pull the whole hive toward the same dead end).
 */
/datum/xeno_ai_controller/proc/respond_to_hive_alert()
	if(!pilot || pilot.resting) // Healing up (see return_to_anchor()) - let other, healthy hive members answer the call instead.
		return FALSE
	if(!pilot.hive?.queen_alert_turf)
		return FALSE
	if(world.time - pilot.hive.queen_alert_time > AI_XENO_HIVE_ALERT_WINDOW)
		return FALSE
	var/turf/alert_turf = pilot.hive.queen_alert_turf
	if(get_dist(pilot, alert_turf) <= 3)
		return FALSE
	// "Drones refuse to weed at all when in combat" - the Queen refreshes
	// this alert every tick she has a live target anywhere on the map, so
	// without a range cap every idle builder in the hive would drop what
	// she's doing and beeline across the map for the entire fight, never
	// getting a chance to weed/build until it's over.
	if(get_dist(pilot, alert_turf) > AI_XENO_HIVE_ALERT_RESPONSE_RANGE)
		return FALSE
	if(count_nearby_hive_members(alert_turf, AI_XENO_HIVE_ALERT_RESPONDER_RADIUS) >= AI_XENO_HIVE_ALERT_MAX_RESPONDERS)
		return FALSE // Already enough backup converging - stay on your own business instead of the whole hive piling in.
	travel_to_broadcast_turf(alert_turf)
	return TRUE

/**
 * Checks for a live "come guard me" call from the Queen (hive_status.dm's
 * queen_escort_turf/queen_escort_time, set by queen.dm's
 * broadcast_escort_call()) - distinct from respond_to_hive_alert() (which
 * points at a threat, not at her), this points at her own position.
 * Stops once close enough to already be functioning as an escort, rather
 * than trying to stack directly on her tile.
 */
/datum/xeno_ai_controller/proc/respond_to_queen_escort()
	if(!pilot || pilot.resting)
		return FALSE
	if(!pilot.hive?.queen_escort_turf)
		return FALSE
	if(world.time - pilot.hive.queen_escort_time > AI_XENO_HIVE_ALERT_WINDOW)
		return FALSE
	var/turf/escort_turf = pilot.hive.queen_escort_turf
	if(get_dist(pilot, escort_turf) <= AI_QUEEN_ESCORT_HOLD_DISTANCE)
		return FALSE
	travel_to_broadcast_turf(escort_turf)
	return TRUE

/// Health fraction (0-1) below which this caste even considers fleeing - overridden per-caste (see crusher.dm) instead of duplicating should_flee()'s decision logic for a different constant.
/datum/xeno_ai_controller/proc/get_flee_threshold()
	return AI_XENO_FLEE_HEALTH_PERCENT

/// Health fraction (0-1) below which a fleeing xeno gives up on running and fights instead - see return_to_anchor()'s desperate-stand check. Overridden to 0 (never) by castes with nothing worth fighting with, e.g. larva.dm.
/datum/xeno_ai_controller/proc/get_desperate_threshold()
	return AI_XENO_DESPERATE_HEALTH_PERCENT

/**
 * TRUE if this xeno can still act (attack/use abilities) despite
 * TRAIT_IMMOBILIZED - the exception for a caste that voluntarily
 * immobilized itself but is still meant to fight from where it's planted
 * (see defender.dm's Fortify override). FALSE by default: an ordinary
 * stun/knockdown should freeze tick() entirely, same as it always has.
 *
 * "Attacking and moving, only to stop the other time and just get killed
 * for being idle" - Pounce (XenoProcs.dm's pounced_mob(), the shared base
 * behind Runner/Lurker/Crusher/Ravager/Facehugger/Vanguard's Prae Dash/base
 * Praetorian's Dash - virtually every caste's gap-closer) self-immobilizes
 * via ADD_TRAIT + a plain addtimer(), not a blocking do_after() - so the
 * pounce call itself returns instantly, but every tick() for the next
 * pounceAction.freeze_time (1-3+ seconds, ability-specific) hit this same
 * freeze check and skipped ALL AI logic - no attack, no movement, no
 * retreat - until the timer cleared, however many tick()s that spanned.
 * Handled here at the base level (not a per-caste override) since almost
 * any caste can end up using a pounce-family ability. HAS_TRAIT_FROM_ONLY
 * (not a bare HAS_TRAIT) matters - TRAIT_IMMOBILIZED isn't exclusively
 * self-inflicted (TRAIT_KNOCKEDOUT from a real marine-landed stun forces it
 * too, living.dm), so this only exempts her when Pounce is the *only*
 * thing holding the trait, never when a genuine hostile stun is stacked on
 * top of it. Per-caste overrides below chain through here via ..() so they
 * inherit this for free instead of re-declaring it.
 */
/datum/xeno_ai_controller/proc/can_act_while_immobilized()
	return HAS_TRAIT_FROM_ONLY(pilot, TRAIT_IMMOBILIZED, TRAIT_SOURCE_ABILITY("Pounce"))

/**
 * "My idea is to use retreating in combat instead of low health = retreat" -
 * a hit-and-run caste (Praetorian/Ravager/Burrower/Lurker) doesn't just
 * fight until should_flee()'s health/last-defender check finally trips; it
 * deliberately disengages after landing a hit and comes back in once it's
 * put some distance between itself and the target, same shape as a real
 * player kiting with a pounce. tactical_retreat_until is a plain world.time
 * deadline - concrete subtypes check is_tactical_retreating() from their own
 * process_movement()/process_attack() override and back away instead of
 * approaching/attacking while it's still in the future, then resume the
 * normal chase once it lapses. Purely a movement-policy flag - it doesn't
 * touch current_target or ai_state, so the moment it lapses she's still
 * tracking the same fight, not searching for a new one.
 */
/datum/xeno_ai_controller/proc/start_tactical_retreat(duration)
	tactical_retreat_until = world.time + duration

/datum/xeno_ai_controller/proc/is_tactical_retreating()
	return world.time < tactical_retreat_until

/**
 * Shared movement helper for a hit-and-run caste's retreat phase - backs
 * directly away from current_target, routing around obstacles same as any
 * other forced step. Returns whether she actually moved - "mid battle they
 * don't attack or know what to do and just sit there taking damage" was a
 * real bug here: this used to always return TRUE regardless of whether the
 * step succeeded, so a caste cornered against a wall/corner with nowhere to
 * actually retreat to would just stand completely still for the whole
 * retreat window (tactical_retreat_until forces AI_STATE_APPROACHING, which
 * blocks attacking, while this reported success and did nothing to move
 * her). Callers now check the return value and cancel the retreat outright
 * when it fails, so being cornered falls through to fighting instead of
 * freezing.
 */
/datum/xeno_ai_controller/proc/step_away_from_target()
	if(!pilot || !current_target)
		return FALSE
	var/away_dir = get_dir(current_target, pilot)
	if(ai_step(away_dir))
		return TRUE
	return navigate_around()

/**
 * "They immediately try putting themselves out when on fire, making them a
 * sitting duck" - on_fire no longer forces a flee by itself. resist() sets
 * next_move forward 2 seconds (living_verbs.dm), the same var this AI's own
 * melee attack pacing depends on (see execute_attack()) - stopping to resist
 * mid-fight cost a full attack window for nothing, and dropping the target
 * to retreat over a status effect that doesn't stop her from fighting was
 * worse than just tanking the damage. She now only resists opportunistically
 * while not actively swinging (return_to_anchor()/wander() already call
 * resist() for other reasons) - fire alone no longer overrides a fight
 * that's still worth having; a real health-based flee call still applies.
 * This is a real fight-or-flee decision, not a bare health check:
 * being hurt enough to consider fleeing doesn't mean fleeing is actually
 * the right call for a caste that's meant to be ruthless. Presses the
 * advantage instead of disengaging when the target is nearly finished too
 * (letting it go now just means fighting it, healthy again, later), or when
 * nearby hive members mean this isn't really a fight being fought alone.
 * Only actually flees when neither of those apply - hurt, alone, and the
 * fight isn't about to end in our favor anyway.
 */
/datum/xeno_ai_controller/proc/should_flee()
	if(!pilot)
		return FALSE
	if(!pilot.maxHealth)
		return FALSE

	var/flee_threshold = get_flee_threshold() * GLOB.ai_flee_multiplier
	if((pilot.health / pilot.maxHealth) >= flee_threshold)
		return FALSE

	if(current_target && isliving(current_target))
		var/mob/living/target_mob = current_target
		if(target_mob.stat != DEAD && target_mob.maxHealth && (target_mob.health / target_mob.maxHealth) < flee_threshold)
			return FALSE // Target's in the same rough shape we are - finish it, don't hand it a free reset.

	if(count_nearby_hive_allies(AI_XENO_FLEE_ALLY_RADIUS) >= AI_XENO_FLEE_ALLY_THRESHOLD)
		return FALSE // Not fighting alone - let the hive's numbers carry the fight instead of peeling off.

	return TRUE

/// Living, non-fleeing same-hive AI xenos within radius tiles - used by should_flee() to judge whether backup is close enough that disengaging isn't necessary.
/datum/xeno_ai_controller/proc/count_nearby_hive_allies(radius)
	if(!pilot)
		return 0
	var/count = 0
	for(var/mob/living/carbon/xenomorph/ally as anything in GLOB.ai_xeno_list)
		if(ally == pilot || ally.stat == DEAD || ally.hivenumber != pilot.hivenumber)
			continue
		if(ally.ai_controller?.ai_state == AI_STATE_RETURNING)
			continue // Already disengaging itself - doesn't count as backup.
		if(get_dist(pilot, ally) <= radius)
			count++
	return count

/**
 * Counts same-hive AI xenos actively fighting (AI_STATE_APPROACHING/ATTACKING) within
 * radius of center_turf - the same scan the Queen's own check_lz_siege()/check_home_siege()
 * used to do independently as momentary per-tick booleans. Promoted to the base controller
 * so it's a shared primitive that FEEDS the hive's persistent threat score
 * (hive_status.dm's add_threat(), driven from hive_director.dm's process_threat()) instead
 * of being the sole momentary decision by itself.
 */
/datum/xeno_ai_controller/proc/count_active_combatants_near(turf/center_turf, radius)
	if(!pilot || !center_turf)
		return 0
	var/count = 0
	for(var/mob/living/carbon/xenomorph/hive_member as anything in GLOB.ai_xeno_list)
		if(hive_member == pilot || hive_member.hivenumber != pilot.hivenumber)
			continue
		var/datum/xeno_ai_controller/member_controller = hive_member.ai_controller
		if(!member_controller || (member_controller.ai_state != AI_STATE_APPROACHING && member_controller.ai_state != AI_STATE_ATTACKING))
			continue
		if(get_dist(hive_member, center_turf) <= radius)
			count++
	return count

/**
 * Bounded, cached target scan. Only recomputes the block() rectangle when there is
 * no cached one to reuse, or the pilot has drifted far enough from where it was
 * last centered - deliberately avoids re-scanning the map every idle tick.
 * Picks the NEAREST valid candidate found in the block (marines or active
 * sentry turrets - see is_valid_target()), not just the first one encountered
 * in scan order, so targeting doesn't depend on incidental turf iteration
 * order.
 *
 * "Many times the AI is just not locking onto enemies for no reason at all" -
 * the staleness check against turf_block_origin is what actually makes that
 * "or the pilot moves on" true. Without it (the previous behavior), a scan
 * that found nobody left turf_block sitting there forever, centered on
 * wherever she happened to be at that one moment - as she patrolled/wandered
 * off, every later process_target() call kept re-scanning that same stale,
 * now-distant rectangle instead of the area she was actually standing in,
 * so a marine right next to her could go completely unnoticed until she
 * wandered back near the original scan point by coincidence.
 */
/datum/xeno_ai_controller/proc/process_target()
	if(!pilot)
		return
	var/turf/pilot_turf = get_turf(pilot)
	if(!pilot_turf)
		return
	if(!turf_block || !length(turf_block) || !turf_block_origin || get_dist(pilot_turf, turf_block_origin) > AI_XENO_TARGET_SCAN_REFRESH_DISTANCE)
		var/scaled_attack_distance = round(attack_distance * GLOB.ai_distance_multiplier)
		turf_block = block(
			locate(max(1, pilot_turf.x - scaled_attack_distance), max(1, pilot_turf.y - scaled_attack_distance), pilot_turf.z),
			locate(min(world.maxx, pilot_turf.x + scaled_attack_distance), min(world.maxy, pilot_turf.y + scaled_attack_distance), pilot_turf.z),
		)
		turf_block_origin = pilot_turf

	// Targeted scans (mobs, sentries, and - Tier 2+ only - vehicles) rather
	// than one broad atom/movable scan - keeps this to a cheap candidate
	// set instead of walking every item/decal/effect on every scanned turf.
	// "Vehicles or multitile entities should be attacked by larger T2 and
	// T3 aliens" - the vehicle scan is skipped outright for Tier 1 castes
	// (is_valid_target() would reject them anyway), so a Runner/Drone-scale
	// population doesn't pay for a scan that can never match anything.
	var/atom/movable/best_candidate
	var/best_dist = INFINITY
	for(var/turf/scanned_turf as anything in turf_block)
		for(var/mob/living/candidate in scanned_turf)
			if(!is_valid_target(candidate))
				continue
			var/dist = get_dist(pilot, candidate)
			if(dist < best_dist)
				best_dist = dist
				best_candidate = candidate
		for(var/obj/structure/machinery/defenses/sentry/candidate in scanned_turf)
			if(!is_valid_target(candidate))
				continue
			var/dist = get_dist(pilot, candidate)
			if(dist < best_dist)
				best_dist = dist
				best_candidate = candidate
		if(pilot.tier >= 2)
			for(var/obj/vehicle/candidate in scanned_turf)
				if(!is_valid_target(candidate))
					continue
				var/dist = get_dist(pilot, candidate)
				if(dist < best_dist)
					best_dist = dist
					best_candidate = candidate

	if(!best_candidate)
		return

	acquire_target(best_candidate)

/// Shared "found something worth fighting" tail - used by process_target()'s own scan and check_retaliation() alike, so noticing a target the normal way and getting jumped by one it wouldn't otherwise have scanned both settle into the exact same state.
/datum/xeno_ai_controller/proc/acquire_target(atom/movable/target)
	current_target = target
	last_seen_turf = get_turf(target)
	turf_block = null
	blocked_attempts = 0
	ai_state = AI_STATE_APPROACHING
	pilot.emote("hiss") // Fires exactly once on first contact, not every tick spent chasing - a quiet patrol suddenly noticing prey.
	if(pilot.resting)
		pilot.set_resting(FALSE) // Stand up to fight - see return_to_anchor() for why it might have been resting in the first place.
	if(ambush_turf)
		end_ambush_hide() // Real prey beats a staged ambush - un-hides for free if attempt_ambush_hide() had her tucked away, same reasoning as standing up from resting above.
	attempt_combat_pheromones()

/**
 * "Anything that attacks the AI should become an enemy too." last_damage_data
 * (mob_defines.dm) is set generically by every attack path in the game
 * (melee, ranged, thrown, etc. - see the many create_cause_data() call sites
 * across combat code) regardless of whether the attacker is a type
 * is_valid_target()'s own scan would ever pick up on its own (a predator, a
 * synthetic, wildlife, anything outside the plain human/sentry/vehicle set).
 * Polled here each tick rather than hooked off a signal - COMSIG_XENO_TAKE_
 * DAMAGE fires from inside apply_damage(), before some callers have actually
 * updated last_damage_data yet, so reading it synchronously off the signal
 * risks seeing the previous hit's attacker, not this one. Comparing the
 * cause_data reference itself (a fresh instance every single hit) tells
 * "new attacker since last check" cheaply, without needing to track a
 * separate timestamp. Only kicks in with no live current_target already -
 * doesn't rip focus off a fight already in progress onto every incidental
 * hit from a third party.
 */
/**
 * "It's the fleeing mechanic, it breaks the AI completely once they start
 * fleeing" - does not fire while AI_STATE_RETURNING. She's fleeing
 * *because* she's already hurt, which is exactly when she's most likely to
 * keep taking hits mid-flight - acquire_target() (below) unconditionally
 * sets ai_state = AI_STATE_APPROACHING, which flips her straight out of
 * AI_STATE_RETURNING. tick()'s very next line re-checks
 * `ai_state != AI_STATE_RETURNING && should_flee()` - now true again since
 * the state just changed - and re-triggers the entire flee transition
 * (drop_target(), back to RETURNING). Every single tick she took damage
 * while fleeing, this thrashed acquire-flee-drop-acquire forever, never
 * actually completing either a retreat or a fight. return_to_anchor()
 * already owns the real "hurt enough to turn and fight instead" decision
 * (its own desperate-stand branch, re-checking should_flee() every tick on
 * its own) - retaliation doesn't need to hijack ai_state to make that call
 * a second, conflicting way.
 */
/datum/xeno_ai_controller/proc/check_retaliation()
	if(!pilot || current_target || ai_state == AI_STATE_RETURNING)
		return
	if(!pilot.last_damage_data || pilot.last_damage_data == last_retaliation_data)
		return
	last_retaliation_data = pilot.last_damage_data
	var/mob/attacker = pilot.last_damage_data.resolve_mob()
	if(!istype(attacker) || attacker == pilot || QDELETED(attacker) || !isliving(attacker))
		return
	var/mob/living/living_attacker = attacker
	if(living_attacker.stat == DEAD)
		return
	if(pilot.hive?.is_ally(living_attacker))
		return // Don't turn on an ally over incidental/friendly-fire damage.
	acquire_target(living_attacker)

/**
 * Valid targets are living marines, active sentry turrets (xenos should
 * fight back against defenses shooting at them, not just claw through one
 * incidentally blocking a path to a marine), - for Tier 2+ castes only -
 * vehicles ("vehicles or multitile entities should be attacked by larger T2
 * and T3 aliens"; Tier 1 is left out since a Runner/Drone-scale caste has
 * nothing to gain from picking a fight with one on purpose, only something
 * to lose, same reasoning melee_vehicle_damage's own per-caste scaling
 * already applies in vehicle.dm's attack_alien()), and any living
 * xenomorph from a hive that isn't hers or explicitly allied to hers
 * ("different hive factions should be considered hostile... unless the
 * hive status is allied" - hive_status.dm's is_ally()/faction_is_ally()
 * already model this correctly; this proc just never consulted it for a
 * xeno candidate before). Broadening further to other hostile
 * factions/synths/etc. is future work.
 */
/datum/xeno_ai_controller/proc/is_valid_target(atom/movable/candidate)
	if(!pilot || !candidate || QDELETED(candidate))
		return FALSE
	if(candidate == pilot)
		return FALSE

	if(isliving(candidate))
		var/mob/living/living_candidate = candidate
		if(living_candidate.stat == DEAD)
			return FALSE
		if(should_block_game_interaction(living_candidate))
			return FALSE
		if(pilot.hive?.is_ally(living_candidate))
			return FALSE
		if(ishuman(living_candidate))
			return TRUE
		// "Different hive factions should be considered hostile, of course
		// unless the hive status is allied. Allying with a faction makes
		// them friendly, therefore not enemies to the AI." is_ally() above
		// already covers same-hive and explicitly-allied hives/factions
		// (hive_status.dm's is_ally()/faction_is_ally()) - anything
		// xenomorph that reaches here is a genuinely rival, non-allied
		// hive's member (e.g. Hive Wars).
		if(isxeno(living_candidate))
			return TRUE
		return FALSE

	if(istype(candidate, /obj/structure/machinery/defenses/sentry))
		var/obj/structure/machinery/defenses/sentry/turret = candidate
		if(turret.stat == DEFENSE_DESTROYED || !turret.turned_on)
			return FALSE
		return TRUE

	if(istype(candidate, /obj/vehicle))
		var/obj/vehicle/vehicle = candidate
		if(pilot.tier < 2 || vehicle.health <= 0)
			return FALSE
		return TRUE

	return FALSE

/**
 * Drops the current target. If should_search is set and we have a last-known
 * position, transitions to AI_STATE_SEARCHING to go investigate it instead of
 * instantly forgetting the target ever existed - used when a chase is broken off
 * by an obstacle (door/ladder/etc.) rather than the target actually dying or
 * becoming invalid, where there's nothing worth investigating.
 */
/datum/xeno_ai_controller/proc/drop_target(should_search = FALSE)
	current_target = null
	turf_block = null
	blocked_attempts = 0
	path_queue = null
	path_goal = null
	last_sidestep_dir = null
	skirt_dir = null
	skirt_until = 0
	if(should_search && last_seen_turf)
		ai_state = AI_STATE_SEARCHING
		search_started_at = world.time
	else
		last_seen_turf = null
		ai_state = AI_STATE_IDLE

/datum/xeno_ai_controller/proc/should_disengage()
	if(!pilot || !anchor_turf || !current_target)
		return FALSE
	return get_dist(pilot, anchor_turf) > round(return_distance * GLOB.ai_distance_multiplier)

/**
 * "Fleeing breaks their AI and makes them refuse to fight and get stuck in a
 * limbo" / "they rest on normal turf instead of weed covered turf to heal" -
 * this used to be a bare cardinal_step_towards(anchor_turf) with none of the
 * chase path's obstacle-handling (no navigate_around()/attempt_skirt_
 * obstacle()/climb-or-smash, no blocked_attempts give-up), and blindly set
 * pilot.resting = TRUE on arrival with no check that anchor_turf was
 * actually owned weeds. Now shares the same movement toolkit
 * process_movement() uses (an unreachable anchor is a real, reported
 * failure mode, not a hypothetical), re-checks should_flee() each tick
 * instead of treating fleeing as a one-way trip, and leaves the actual
 * rest-on-weeds decision to wander() (reached the moment ai_state flips to
 * IDLE below, via the normal patrol() fallthrough) instead of duplicating -
 * and getting wrong - that logic here.
 */
/datum/xeno_ai_controller/proc/return_to_anchor()
	if(!pilot)
		return
	if(pilot.on_fire && pilot.can_resist())
		pilot.resist() // Same rolling/stop-drop-and-roll a player would do to put themselves out.
	if(!anchor_turf)
		ai_state = AI_STATE_IDLE
		flee_turf = null
		return

	// Re-evaluate whether she still needs to flee at all before continuing
	// the trip - health recovered, backup arrived, or the threat's gone -
	// instead of a one-way latch that only ever resolves by physically
	// reaching anchor_turf.
	if(!should_flee())
		blocked_attempts = 0
		flee_turf = null
		ai_state = AI_STATE_IDLE
		return

	// "Unless they are very desperate and want to live" - too hurt for
	// running to actually be safer than standing and fighting, and there's
	// still something adjacent to turn on. Going down mid-flight with her
	// back turned isn't better than taking a real swing while she still can.
	if(current_target && is_valid_target(current_target) && pilot.maxHealth && (pilot.health / pilot.maxHealth) < get_desperate_threshold() && pilot.Adjacent(current_target))
		blocked_attempts = 0
		flee_turf = null
		ai_state = AI_STATE_ATTACKING
		return

	var/turf/destination = flee_turf || anchor_turf
	if(get_turf(pilot) == destination)
		blocked_attempts = 0
		flee_turf = null
		ai_state = AI_STATE_IDLE
		return

	if(attempt_skirt_obstacle())
		return
	if(advance_along_path(destination))
		blocked_attempts = 0
		return
	if(cardinal_step_towards(destination))
		blocked_attempts = 0
		return

	var/obj/structure/climbable_obstacle = get_climbable_obstacle(destination)
	if(climbable_obstacle)
		if(should_smash_instead_of_climb(climbable_obstacle))
			attack_blocking_obstacle(climbable_obstacle)
			blocked_attempts = 0
			return
		if(attempt_climb_obstacle(climbable_obstacle))
			blocked_attempts = 0
			return

	var/atom/blocking_obstacle = get_blocking_obstacle(destination)
	if(blocking_obstacle)
		attack_blocking_obstacle(blocking_obstacle)
		blocked_attempts = 0
		return

	if(navigate_around(destination))
		blocked_attempts = 0
		return

	blocked_attempts++
	if(blocked_attempts >= 2)
		// Genuinely unreachable (resin construction, rubble, geometry) - re-
		// anchor to wherever she actually got stuck instead of endlessly
		// retrying an impossible walk, so she can resume fighting/idling
		// from here instead of being stuck in AI_STATE_RETURNING forever.
		anchor_turf = get_turf(pilot)
		flee_turf = null
		blocked_attempts = 0
		ai_state = AI_STATE_IDLE

/**
 * Travels toward the last place a lost target was seen, crossing z-levels via a
 * connected ladder if needed (see code/game/objects/structures/ladders.dm's
 * ai_use()). Keeps re-scanning for a fresh target en route so a different
 * marine wandering past will interrupt the search. Gives up after
 * AI_XENO_SEARCH_TIMEOUT or if there's simply no ladder connecting toward the
 * target's z-level, rather than getting stuck forever.
 */
/datum/xeno_ai_controller/proc/process_search()
	if(!pilot || !last_seen_turf)
		ai_state = AI_STATE_IDLE
		return

	if(world.time - search_started_at > AI_XENO_SEARCH_TIMEOUT)
		last_seen_turf = null
		ai_state = AI_STATE_IDLE
		return

	var/turf/pilot_turf = get_turf(pilot)
	if(!pilot_turf)
		return

	if(pilot_turf.z != last_seen_turf.z)
		var/obj/structure/ladder/target_ladder = find_ladder_towards(last_seen_turf.z)
		if(!target_ladder)
			last_seen_turf = null
			ai_state = AI_STATE_IDLE
			return
		if(get_dist(pilot, target_ladder) <= 0)
			target_ladder.ai_use(pilot, (last_seen_turf.z > pilot_turf.z) ? "up" : "down")
		else if(!advance_along_path(target_ladder))
			cardinal_step_towards(target_ladder)
		return

	if(get_dist(pilot, last_seen_turf) <= 1)
		last_seen_turf = null
		ai_state = AI_STATE_IDLE
		return

	process_target()
	if(current_target)
		return

	if(!advance_along_path(last_seen_turf))
		cardinal_step_towards(last_seen_turf)

/// Nearest ladder on the pilot's current z-level that actually connects toward target_z, or null if none does.
/datum/xeno_ai_controller/proc/find_ladder_towards(target_z)
	if(!pilot)
		return null
	var/turf/pilot_turf = get_turf(pilot)
	if(!pilot_turf)
		return null

	var/obj/structure/ladder/best
	var/best_dist = INFINITY
	for(var/obj/structure/ladder/candidate as anything in GLOB.ladder_list)
		var/turf/ladder_turf = get_turf(candidate)
		if(!ladder_turf || ladder_turf.z != pilot_turf.z)
			continue
		if(target_z > pilot_turf.z && !candidate.up)
			continue
		if(target_z < pilot_turf.z && !candidate.down)
			continue
		var/d = get_dist(pilot, candidate)
		if(d < best_dist)
			best_dist = d
			best = candidate
	return best

/**
 * Finds a specific ability instance on the pilot's action bar, for
 * per-caste controller subtypes that call a caste ability's use_ability()
 * body directly (bypassing the click/mouse layer) rather than the generic
 * melee attack_alien() chain - see the per-caste ability audit in the plan
 * (section 2.6). Returns null if the pilot doesn't have that ability at all.
 */
/datum/xeno_ai_controller/proc/get_ability(action_type)
	if(!pilot)
		return null
	return locate(action_type) in pilot.actions
