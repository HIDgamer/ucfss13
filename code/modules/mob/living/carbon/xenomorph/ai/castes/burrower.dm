/**
 * Burrower AI - a trap-setting builder-brawler hybrid: builds weeds during
 * downtime like Drone/Hivelord (she has plant_weeds in her own
 * base_actions), and uses Tremor (a self-centered AoE knockdown) as her
 * opener whenever it's off cooldown.
 *
 * "Burrower should be able to use its burrow ability to go from one turf to
 * another, this helps ambush marines. Once out of the burrowing state, use
 * stomp, slash the enemy a bit, and burrow back to safety again" - Burrow
 * is dual-purpose on a real click too (burrower_abilities.dm's
 * use_ability()): clicking it while surfaced goes underground in place;
 * clicking it again while burrowed tunnels to wherever was clicked, then
 * auto-surfaces on arrival and knocks down anything standing on that tile
 * (Burrower.dm's do_tunnel()/burrow_off()) - a real ambush payoff, not just
 * a hiding spot. process_movement() below chains the two: burrow in place
 * while still approaching, then tunnel the rest of the way onto the
 * target's own tile once burrowed. can_act_while_immobilized() keeps her AI
 * ticking through both the "waiting underground" and "mid-tunnel" phases -
 * TRAIT_IMMOBILIZED would otherwise freeze the whole state machine, same
 * as it does for an ordinary knockdown, leaving her to resurface wherever
 * she happened to start rather than actually choosing to close in.
 *
 * Once surfaced next to a live target, use_caste_ability() below fights
 * normally (Tremor, falling through to plain slashes - "slash the enemy a
 * bit") for as long as the target's actually down or she's still healthy;
 * once it's back up and she's taken real damage doing it, THAT's the
 * decision point where she queues a tactical retreat (start_tactical_
 * retreat(), the shared hit-and-run helper) so process_movement() ducks her
 * back underground once there's room - a real decision reacting to the
 * fight, not a reflex after every opener or a coin flip after every swing.
 */
/datum/xeno_ai_controller/burrower
	/// Rotational direction (90 or -90) this Burrower always sidesteps toward - same reasoning as ravager.dm's identical var.
	var/circle_dir
	/// pilot.health as of the last process_attack() call - see the reactive-dodge check there, same pattern as ravager.dm.
	var/last_known_health
	/// Site committed to for attempt_dig_tunnel() - picked once (pick_tunnel_site()) and walked to across multiple idle ticks instead of re-rolled every call, same shape as the base controller's build_target_turf. Null whenever not mid-walk to a tunnel site.
	var/turf/tunnel_build_turf

/datum/xeno_ai_controller/burrower/New(mob/living/carbon/xenomorph/new_pilot)
	. = ..()
	circle_dir = pick(90, -90)

/// See the caste doc comment above - lets her keep deciding what to do next while burrowed/tunneling instead of freezing entirely.
/datum/xeno_ai_controller/burrower/can_act_while_immobilized()
	if(..())
		return TRUE
	var/mob/living/carbon/xenomorph/burrower_pilot = pilot
	return istype(burrower_pilot) && HAS_TRAIT(burrower_pilot, TRAIT_ABILITY_BURROWED)

/datum/xeno_ai_controller/burrower/patrol()
	if(respond_to_hive_alert())
		idle_activity = IDLE_ACTIVITY_ALERT
		return
	if(attempt_help_queen_build_core())
		idle_activity = IDLE_ACTIVITY_BUILD
		return
	if(prob(AI_DEFENSE_BUILD_CHANCE) && attempt_build_defense())
		idle_activity = IDLE_ACTIVITY_BUILD
		return
	if(prob(AI_DRONE_BUILD_CHANCE) && attempt_plant_weeds())
		idle_activity = IDLE_ACTIVITY_BUILD
		return
	if(prob(AI_BURROWER_AMBUSH_CHANCE) && attempt_burrow_ambush())
		idle_activity = IDLE_ACTIVITY_AMBUSH
		return
	// Tunnels are a powerful tool - see attempt_dig_tunnel() for the site-selection logic.
	if((tunnel_build_turf || prob(AI_BURROWER_TUNNEL_DIG_CHANCE)) && attempt_dig_tunnel())
		idle_activity = IDLE_ACTIVITY_BUILD
		return
	// "A trap-setting builder-brawler" per her own caste doc comment, but
	// Place Trap (a resin trap hole) was granted and never used - same idle-
	// build-roll shape as attempt_plant_weeds() above.
	if(prob(AI_DEFENSE_BUILD_CHANCE) && attempt_place_trap())
		idle_activity = IDLE_ACTIVITY_BUILD
		return
	return ..() // Falls through to the base patrol() (long patrol/pack cohesion/ambush hide/wander) instead of only ever plain wander().

/// Self-turf placement (place_trap/use_ability(), general_powers.dm) - the passed atom arg is unused, a plain self-target call is enough. Already refuses to fire while burrowed (the ability's own check), so no extra guard needed here.
/datum/xeno_ai_controller/burrower/proc/attempt_place_trap()
	if(!pilot)
		return FALSE
	var/datum/action/xeno_action/onclick/place_trap/trap = get_ability(/datum/action/xeno_action/onclick/place_trap)
	if(!trap || !trap.action_cooldown_check())
		return FALSE
	trap.use_ability(pilot)
	return TRUE

/// Fires Burrow if she's currently eligible (not already burrowed/tunneling/on cooldown) - see the caste doc comment above for why blocking tick() through the windup is safe here.
/datum/xeno_ai_controller/burrower/proc/attempt_burrow_ambush()
	var/mob/living/carbon/xenomorph/burrower_pilot = pilot
	if(!istype(burrower_pilot) || burrower_pilot.used_burrow || burrower_pilot.tunnel || HAS_TRAIT(burrower_pilot, TRAIT_ABILITY_BURROWED))
		return FALSE
	var/datum/action/xeno_action/activable/burrow/burrow_ability = get_ability(/datum/action/xeno_action/activable/burrow)
	if(!burrow_ability)
		return FALSE
	burrow_ability.use_ability(burrower_pilot)
	return TRUE

/**
 * Same commit-once-then-travel idle shape as
 * attempt_build_defense()/attempt_build_fort_line() (xeno_ai_controller.dm):
 * pick_tunnel_site() picks a site once, tunnel_build_turf holds the
 * commitment across however many idle ticks it takes to walk there, and the
 * ability only actually fires once close enough. Burrower-only, and sited
 * purely off stable hive-side signals (see pick_tunnel_site()) rather than
 * live marine positions, so placement doesn't "chase" a moving target.
 */
/datum/xeno_ai_controller/burrower/proc/attempt_dig_tunnel()
	var/mob/living/carbon/xenomorph/burrower_pilot = pilot
	if(!istype(burrower_pilot) || !burrower_pilot.hive)
		return FALSE
	var/datum/action/xeno_action/onclick/build_tunnel/dig = get_ability(/datum/action/xeno_action/onclick/build_tunnel)
	if(!dig || !dig.action_cooldown_check())
		return FALSE
	if(burrower_pilot.tunnel_delay || burrower_pilot.get_active_hand())
		return FALSE
	if(length(burrower_pilot.hive.tunnels) >= AI_TUNNEL_MAX_HIVE_TUNNELS)
		return FALSE // Hard cap (counts player-built tunnels too) - don't let idle rolls spam an unbounded network.
	if(!burrower_pilot.check_plasma(dig.plasma_cost))
		return FALSE

	if(tunnel_build_turf)
		if(!is_valid_tunnel_site(tunnel_build_turf))
			tunnel_build_turf = null
		else if(get_dist(pilot, tunnel_build_turf) > 0)
			travel_to(tunnel_build_turf, TRAVEL_FLAG_FORCE_OBSTACLES|TRAVEL_FLAG_AVOID_MOBS|TRAVEL_FLAG_STATIC_GOAL)
			return TRUE
		else
			dig.use_ability(burrower_pilot) // Re-validates turf/plasma/cooldown itself, same as every other AI direct-call site - safe to call speculatively.
			tunnel_build_turf = null
			return TRUE

	tunnel_build_turf = pick_tunnel_site()
	return tunnel_build_turf ? TRUE : FALSE

/// Mechanical placement gate shared by attempt_dig_tunnel()'s re-validation and pick_tunnel_site()'s candidate filtering - the same checks build_tunnel/use_ability() itself performs up front before it'll ever actually dig (Burrower.dm), duplicated here only so an unsuitable turf never gets committed to or walked toward in the first place.
/datum/xeno_ai_controller/burrower/proc/is_valid_tunnel_site(turf/candidate)
	if(!candidate || !candidate.can_dig_xeno_tunnel() || !is_ground_level(candidate.z))
		return FALSE
	if(locate(/obj/structure/tunnel) in candidate)
		return FALSE
	if(locate(/obj/structure/machinery/sentry_holder/landing_zone) in candidate)
		return FALSE
	return TRUE

/**
 * Autonomous "strategic position" siting for attempt_dig_tunnel() above.
 * Reuses the same candidate-pool/anti-cluster/variety-tolerance shape
 * pick_fort_line_start_turf() (xeno_ai_controller.dm) already established
 * for a different structure type, plus would_block_passage()'s existing
 * chokepoint BFS - used there to REJECT wall placement on a corridor tile,
 * inverted here to PREFER one, since a genuine chokepoint is exactly where a
 * reinforcement shortcut matters most.
 */
/datum/xeno_ai_controller/burrower/proc/pick_tunnel_site()
	if(!pilot || !pilot.hive)
		return null
	var/turf/search_center = get_turf(pilot)
	if(!search_center)
		return null

	var/list/candidates = list()
	for(var/obj/effect/alien/weeds/weed in range(AI_TUNNEL_SITE_SEARCH_RADIUS, search_center))
		if(weed.linked_hive.hivenumber != pilot.hivenumber)
			continue
		var/turf/weed_turf = get_turf(weed)
		if(weed_turf && is_valid_tunnel_site(weed_turf))
			candidates += weed_turf
	if(!length(candidates))
		return null

	// Anti-cluster, same shape as pick_fort_line_start_turf()'s against
	// fort_gates - against the hive's existing tunnel network instead.
	var/list/spread_candidates = list()
	for(var/turf/candidate in candidates)
		var/near_existing = FALSE
		for(var/obj/structure/tunnel/existing as anything in pilot.hive.tunnels)
			if(existing && get_dist(candidate, existing) < AI_TUNNEL_ANTI_CLUSTER_RADIUS)
				near_existing = TRUE
				break
		if(!near_existing)
			spread_candidates += candidate
	if(length(spread_candidates))
		candidates = spread_candidates

	// A genuine chokepoint is exactly where a reinforcement shortcut matters
	// most - prefer one outright when any survive the filters above, rather
	// than folding it into a numeric score.
	var/list/turf/chokepoints = list()
	for(var/turf/candidate in candidates)
		if(would_block_passage(candidate))
			chokepoints += candidate
	if(length(chokepoints))
		candidates = chokepoints

	// Among whatever's left, prefer whichever sits closest to ground the
	// hive has actually taken and held (frontier_turf) or, before any exists
	// yet, its current push target (assault_alert_turf) - the closest
	// available signal to "strategic position" that doesn't chase live
	// marine movement. Same near-tied variety-tolerance pattern
	// pick_fort_line_start_turf() already uses.
	var/turf/anchor = pilot.hive.frontier_turf || pilot.hive.assault_alert_turf
	if(!anchor)
		return pick(candidates)
	var/best_dist = INFINITY
	for(var/turf/candidate in candidates)
		var/d = get_dist(candidate, anchor)
		if(d < best_dist)
			best_dist = d
	var/list/turf/best_candidates = list()
	for(var/turf/candidate in candidates)
		if(get_dist(candidate, anchor) <= best_dist + AI_FORT_FRONTIER_TOLERANCE)
			best_candidates += candidate
	return pick(best_candidates)

/**
 * Combat movement: while burrowed, either tunnels the rest of the way onto
 * the target (ambush) or just waits out an already-in-progress tunnel;
 * while chasing on the surface, has a chance to burrow in place first
 * instead of always closing the distance on foot; while tactically
 * retreating, backs off and ducks underground once there's room instead of
 * only ever backing away in the open. Otherwise inherits the normal
 * approach/attack chain unchanged.
 */
/datum/xeno_ai_controller/burrower/process_movement()
	var/mob/living/carbon/xenomorph/burrower_pilot = pilot
	if(!istype(burrower_pilot) || !current_target)
		return
	if(!is_valid_target(current_target))
		drop_target()
		return

	if(HAS_TRAIT(burrower_pilot, TRAIT_ABILITY_BURROWED))
		if(burrower_pilot.tunnel)
			return // Already mid-tunnel - do_tunnel() surfaces her automatically on arrival.
		if(!burrower_pilot.used_tunnel)
			var/datum/action/xeno_action/activable/burrow/burrow_ability = get_ability(/datum/action/xeno_action/activable/burrow)
			burrow_ability?.use_ability(current_target) // Tunnels onto the target's own tile - do_tunnel()'s burrow_off() weakens anything standing there when she surfaces.
		return

	if(is_tactical_retreating())
		if(get_dist(burrower_pilot, current_target) >= AI_BURROWER_RETREAT_SAFE_DISTANCE)
			attempt_burrow_ambush() // Far enough out now - duck underground and let the retreat/cooldown run out safely instead of just standing in the open.
			return
		// Cornered with nowhere to actually back into cancels the retreat
		// outright instead of standing frozen for the rest of the window -
		// same fix as every other hit-and-run caste.
		if(step_away_from_target())
			return
		tactical_retreat_until = 0

	note_last_seen(get_turf(current_target), current_target)
	if(get_dist(pilot, current_target) <= 1 && pilot.Adjacent(current_target))
		ai_state = AI_STATE_ATTACKING
		blocked_attempts = 0
		path_queue = null
		return

	if(!burrower_pilot.used_burrow && prob(AI_BURROWER_AMBUSH_ENGAGE_CHANCE))
		var/datum/action/xeno_action/activable/burrow/burrow_ability = get_ability(/datum/action/xeno_action/activable/burrow)
		if(burrow_ability)
			burrow_ability.use_ability(burrower_pilot) // Sets up the tunnel-in above rather than trudging the rest of the way over on foot.
			return

	return ..()

/**
 * "Crusher, and burrower never use their stomping ability when near
 * enemies" - Tremor knocks down everything it hits, same as Crusher's
 * Stomp, so a single-target hit is still a real win; it was wrong to gate
 * it behind a headcount that rarely happened in an ordinary 1v1.
 *
 * "A good start, but they burrow a lot until they die - they should
 * consider slashing until the enemy is up, and then they get to decide to
 * flee or keep fighting." Used to queue a tactical retreat automatically
 * the instant Tremor landed, and separately roll a flat percent chance to
 * retreat after every single plain swing regardless of how the fight was
 * actually going - between the two she was ducking out almost immediately
 * and constantly, never actually committing to a fight. Now she just fights
 * (Tremor as an opener, falling through to plain slashes) while the target
 * is still down from it; once it's back up and still a real threat, THAT's
 * the actual decision point - retreat only if she's taken real damage
 * doing it, not a blind reflex or a coin flip.
 */
/datum/xeno_ai_controller/burrower/use_caste_ability(mob/living/target)
	if(!pilot)
		return FALSE

	// "Kidnapping a human for the hive at times before burrowing back to
	// safety" - the same drag-and-isolate tow Runner already uses
	// (attempt_start_drag()/process_drag(), driven generically by the base
	// controller regardless of which caste started it); tried before Tremor
	// so grabbing a target that's already down takes priority over an AoE
	// that would just knock them right back down anyway.
	if(ishuman(target))
		var/mob/living/carbon/human/downed = target
		if((downed.is_mob_incapacitated() || downed.body_position == LYING_DOWN) && prob(AI_BURROWER_DRAG_CHANCE) && attempt_start_drag(downed))
			drop_target()
			return TRUE

	var/datum/action/xeno_action/onclick/tremor/tremor = get_ability(/datum/action/xeno_action/onclick/tremor)
	if(tremor && tremor.action_cooldown_check())
		var/found_target = FALSE
		for(var/mob/living/carbon/nearby in orange(2, pilot))
			if(is_valid_target(nearby))
				found_target = TRUE
				break
		if(found_target)
			tremor.use_ability(pilot)
			return TRUE

	if(!HAS_TRAIT(target, TRAIT_FLOORED) && !target.is_mob_incapacitated() && pilot.health < pilot.maxHealth * AI_BURROWER_CAUTIOUS_HEALTH_PERCENT)
		start_tactical_retreat(AI_BURROWER_RETREAT_DURATION)
	return FALSE

/// Burrower had no post-attack repositioning at all - same damage-reactive-plus-baseline-roll shape as ravager.dm's own circle-step.
/datum/xeno_ai_controller/burrower/process_attack()
	. = ..()
	if(!pilot || !current_target || ai_state != AI_STATE_ATTACKING)
		last_known_health = pilot?.health
		return
	var/took_damage = (last_known_health != null) && (pilot.health < last_known_health)
	last_known_health = pilot.health
	if(!took_damage && !prob(AI_WARRIOR_REPOSITION_CHANCE))
		return
	var/target_dir = get_dir(pilot, current_target)
	if(!ai_step(turn(target_dir, circle_dir)))
		ai_step(turn(target_dir, -circle_dir))
