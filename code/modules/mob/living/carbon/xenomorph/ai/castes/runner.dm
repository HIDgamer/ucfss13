/**
 * Runner AI - a fast, fragile harasser: dash in with Pounce, land a hit,
 * then keep moving instead of trading blows toe-to-toe like a Warrior
 * would. Patrol/search behavior is entirely inherited from the base
 * controller.
 *
 * - Fires Pounce to close distance the same way Crusher/Ravager use their
 *   own dashes - Runner's has a much shorter cooldown (3s vs their 14s) and
 *   shorter range (6 tiles, the pounce base default), matching its role as
 *   a constant, low-commitment opener rather than an occasional finisher.
 * - Flees at a much higher health fraction than the default - she's the
 *   hive's glass cannon (lowest HP, no armor - XENO_HEALTH_RUNNER/
 *   XENO_NO_ARMOR), meant to hit and run, not to trade hits and die trying.
 * - "Too insane, completely spinning around like a feral dog - they should
 *   circle the battlefield attacking and dodging, very fast but very weak
 *   and small." Stepping straight away after every attack (the old
 *   behavior) reads exactly like that: pounce in, back straight out, get
 *   pulled straight back in by the base approach chain, repeat every ~1-2
 *   ticks - a jittery in-out twitch, not motion. Now sidesteps to a
 *   flanking tile instead, same shape as Ravager's own circling
 *   (circle_dir below - one consistent rotational direction, not a
 *   re-rolled left-right wobble) but every attack rather than a
 *   probability roll, since her whole identity is staying in motion.
 */
/datum/xeno_ai_controller/runner
	/// Rotational direction (90 or -90) this Runner always circles toward - see Ravager's identical var for why this is picked once instead of re-rolled.
	var/circle_dir

/datum/xeno_ai_controller/runner/New(mob/living/carbon/xenomorph/new_pilot)
	. = ..()
	circle_dir = pick(90, -90)

/datum/xeno_ai_controller/runner/get_flee_threshold()
	return AI_RUNNER_FLEE_HEALTH_PERCENT

/**
 * Same duplication tradeoff as crusher.dm/ravager.dm - attempting the dash
 * before falling through to the inherited approach chain is different
 * enough from the base melee policy to warrant a full override rather than
 * a shared helper.
 */
/datum/xeno_ai_controller/runner/process_movement()
	if(!pilot || !current_target)
		return

	if(!is_valid_target(current_target))
		drop_target()
		return

	last_seen_turf = get_turf(current_target)

	if(get_dist(pilot, current_target) <= 1 && pilot.Adjacent(current_target))
		ai_state = AI_STATE_ATTACKING
		blocked_attempts = 0
		path_queue = null
		return

	if(attempt_pounce(current_target))
		return

	return ..()

/// Fires Pounce at target if it's off cooldown and within its reach; returns FALSE (and does nothing else) otherwise, so the caller falls back to the inherited approach/pathfinding chain.
/datum/xeno_ai_controller/runner/proc/attempt_pounce(atom/target)
	var/datum/action/xeno_action/activable/pounce/runner/pounce = get_ability(/datum/action/xeno_action/activable/pounce/runner)
	if(!pounce || !pounce.action_cooldown_check())
		return FALSE
	if(get_dist(pilot, target) > pounce.distance)
		return FALSE
	if(!has_line_of_sight(target, physical_path = TRUE)) // A pounce is a physical dash - tables/fences/barricades block it same as a wall would, not just line-of-sight.
		return FALSE
	pounce.use_ability(target)
	return TRUE

/**
 * Sidesteps to a flanking tile after landing an attack instead of either
 * standing adjacent or backing straight out - "circle the battlefield
 * attacking and dodging." Tries the preferred rotational side first, then
 * the opposite side if that's blocked, so a single obstruction doesn't
 * cancel the movement outright.
 */
/datum/xeno_ai_controller/runner/process_attack()
	. = ..()
	if(!pilot || !current_target || ai_state != AI_STATE_ATTACKING)
		return
	var/target_dir = get_dir(pilot, current_target)
	if(!ai_step(turn(target_dir, circle_dir)))
		ai_step(turn(target_dir, -circle_dir))
