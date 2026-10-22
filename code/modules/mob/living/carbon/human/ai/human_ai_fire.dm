/// Furthest the brain wants to be from a target while shooting
/datum/human_ai_brain/proc/preferred_range(obj/item/weapon/gun/gun)
	var/datum/human_ai_gun_appraisal/appraisal = get_human_ai_gun_appraisal(gun)
	var/range = appraisal.ideal_range + round(personality.scaled("aggression", 1.5, -1.5))
	return clamp(range, max(2, appraisal.min_range), appraisal.max_range)

/// Where the brain stops closing in: the edge of its range for the very cautious, the comfortable range for the rest
/datum/human_ai_brain/proc/engage_range(obj/item/weapon/gun/gun)
	if(personality.trait("caution") >= 70)
		return shooting_range(gun) - 1
	return preferred_range(gun)

/// Merciful brains do not fire at a human who is down
/datum/human_ai_brain/proc/spares_downed(mob/living/subject)
	return ishuman(subject) && subject.stat >= UNCONSCIOUS && personality.trait("mercy") >= 50

/// Furthest the brain will shoot from at all
/datum/human_ai_brain/proc/shooting_range(obj/item/weapon/gun/gun)
	return get_human_ai_gun_appraisal(gun).max_range + 1

/// False when someone who is not an enemy stands in the way
/datum/human_ai_brain/proc/has_clear_line(atom/target)
	var/turf/target_turf = get_turf(target)
	for(var/turf/line_turf in get_line(body, target, FALSE))
		if(line_turf == target_turf)
			break
		for(var/mob/living/blocker in line_turf)
			if(blocker.stat != DEAD && !is_valid_target(blocker))
				return FALSE
	return TRUE

/// Whether a wall or a shut door stands between the body and the point, so that a bullet fired at it ends there
/datum/human_ai_brain/proc/wall_in_line(atom/target)
	var/turf/here = get_turf(body)
	var/turf/there = get_turf(target)
	if(!here || !there || here == there || here.z != there.z)
		return FALSE
	for(var/turf/line_turf as anything in get_line(here, there))
		if(line_turf == here || line_turf == there)
			continue
		if(line_turf.density)
			return TRUE
		for(var/obj/structure/machinery/door/door in line_turf)
			if(door.density)
				return TRUE
	return FALSE

/// A living mob that a stray bullet must not reach: anyone who is not an enemy
/datum/human_ai_brain/proc/is_protected(mob/living/candidate)
	return candidate != body && candidate.stat != DEAD && !is_valid_target(candidate)

/**
 * Whether a bullet aimed at the point could hit someone who is not an enemy: on the line to it, past it where a shot that misses carries on,
 * or beside it where the aim can wander to. spread is how many tiles the aim may be off, nothing is looked for beside the point below the tolerated amount.
 */
/datum/human_ai_brain/proc/friendly_in_lane(atom/aim, spread = 0)
	var/turf/here = get_turf(body)
	var/turf/aim_turf = get_turf(aim)
	if(!here || !aim_turf || here == aim_turf)
		return FALSE
	var/offset_x = aim_turf.x - here.x
	var/offset_y = aim_turf.y - here.y
	var/steps = max(abs(offset_x), abs(offset_y))
	var/turf/far_turf = locate(clamp(here.x + round(offset_x * (steps + HAI_FF_OVERSHOOT) / steps), 1, world.maxx), clamp(here.y + round(offset_y * (steps + HAI_FF_OVERSHOOT) / steps), 1, world.maxy), here.z)
	for(var/turf/lane_turf as anything in get_line(here, far_turf || aim_turf))
		if(lane_turf == here)
			continue
		if(lane_turf.density)
			break
		for(var/mob/living/occupant in lane_turf)
			if(is_protected(occupant))
				return TRUE
	if(spread >= HAI_FF_SPREAD)
		for(var/mob/living/bystander in range(max(1, round(spread + 0.5)), aim_turf))
			if(is_protected(bystander))
				return TRUE
	return FALSE

/// Whether shooting at the target is safe for the body and for everyone who is not an enemy
/datum/human_ai_brain/proc/safe_to_fire(obj/item/weapon/gun/gun, atom/target)
	var/datum/human_ai_gun_appraisal/appraisal = get_human_ai_gun_appraisal(gun)
	var/distance = get_dist(body, target)
	if(distance < appraisal.min_range || distance > shooting_range(gun))
		return FALSE
	if(appraisal.area_effect)
		for(var/mob/living/bystander in view(HAI_AREA_SAFE_RADIUS, get_turf(target)))
			if(bystander != body && bystander.stat != DEAD && get_disposition(bystander) <= HAI_DISP_FRIEND)
				return FALSE
	return !friendly_in_lane(target, aim_error(target, gun))

/// The time before which the gun will not fire again
/datum/human_ai_brain/proc/gun_ready_time(obj/item/weapon/gun/gun)
	var/ready = gun.last_fired + gun.get_fire_delay() + gun.extra_delay
	if(gun.gun_firemode == GUN_FIREMODE_SEMIAUTO)
		ready = max(ready, last_shot_time + HAI_SEMI_INTERVAL * personality.scaled("discipline", 0.8, 1.4))
	return ready

/// True when a trigger pull now would be answered by a shot
/datum/human_ai_brain/proc/gun_can_shoot_now(obj/item/weapon/gun/gun)
	if(world.time < gun_blocked_until || world.time < gun_ready_time(gun))
		return FALSE
	if(gun.flags_gun_features & GUN_BURST_FIRING)
		return FALSE
	if(weapon_state(gun) != HAI_WEAPON_READY)
		return FALSE
	if(gun.get_gun_user() != body)
		gun.set_gun_user(body)
	return !!gun.able_to_fire(body)

/// Starts the reaction delay before the first shot at something new
/datum/human_ai_brain/proc/start_reaction(speed = 1)
	var/mob/living/target = get_target()
	if(target && get_dist(body, target) <= HAI_REFLEX_RANGE)
		speed *= 2
	var/delay = HAI_REACTION_TIME * personality.scaled("alertness", 1.4, 0.6) * SShuman_ai.reaction_mult / speed
	reaction_until = world.time + delay

/// True while the brain is being shot at
/datum/human_ai_brain/proc/suppressed()
	return world.time < last_shot_at_time + HAI_SUPPRESSED_TIME

/// How many tiles a shot at the target may miss by
/datum/human_ai_brain/proc/aim_error(atom/target, obj/item/weapon/gun/gun)
	var/error = get_dist(body, target) * HAI_AIM_ERROR_PER_TILE * SShuman_ai.aim_error_mult
	error *= personality.scaled("composure", 1.3, 0.8)
	error *= 1 + stress * 0.012
	if(move_state == HAI_MOVE_WALKING)
		error *= 1.5
	if(suppressed())
		error *= 1.3
	if(gun && (gun.flags_item & TWOHANDED) && !(gun.flags_item & WIELDED))
		error *= 1.8
	if(body.on_fire)
		error *= 2
	if(berserk_until)
		error *= 1.4
	return error

/// A whole number of tiles for a fractional offset, rounding up with the chance of the fraction
/datum/human_ai_brain/proc/random_shift(error)
	var/amount = (rand() * 2 - 1) * error
	var/whole = trunc(amount)
	if(prob(abs(amount - whole) * 100))
		whole += (amount > 0) ? 1 : -1
	return whole

/// What to point the gun at, the target itself or a turf near it when the aim is off
/datum/human_ai_brain/proc/aim_point(atom/target, obj/item/weapon/gun/gun)
	var/error = aim_error(target, gun)
	if(error < 0.1)
		return target
	var/turf/at = get_turf(target)
	var/shift_x = random_shift(error)
	var/shift_y = random_shift(error)
	if(!shift_x && !shift_y)
		return target
	var/turf/aimed = locate(clamp(at.x + shift_x, 1, world.maxx), clamp(at.y + shift_y, 1, world.maxy), at.z)
	return aimed || target

/// Which fire mode suits the range and the gun, or null when the gun has only one
/datum/human_ai_brain/proc/pick_fire_mode(obj/item/weapon/gun/gun, datum/human_ai_gun_appraisal/appraisal, distance)
	var/list/preference
	if(appraisal.suppressive || distance <= 2)
		preference = list(GUN_FIREMODE_AUTOMATIC, GUN_FIREMODE_BURSTFIRE, GUN_FIREMODE_SEMIAUTO)
	else if(distance > appraisal.ideal_range + 1 || personality.trait("discipline") >= 65)
		preference = list(GUN_FIREMODE_SEMIAUTO, GUN_FIREMODE_BURSTFIRE, GUN_FIREMODE_AUTOMATIC)
	else
		preference = list(GUN_FIREMODE_BURSTFIRE, GUN_FIREMODE_AUTOMATIC, GUN_FIREMODE_SEMIAUTO)
	for(var/mode in preference)
		if(!(mode in gun.gun_firemode_list))
			continue
		if(mode == GUN_FIREMODE_BURSTFIRE && !appraisal.can_burst)
			continue
		return mode
	return null

/// Puts the gun on the fire mode that suits the range
/datum/human_ai_brain/proc/set_fire_mode(obj/item/weapon/gun/gun, datum/human_ai_gun_appraisal/appraisal, distance)
	if(length(gun.gun_firemode_list) < 2 || world.time < next_mode_time || (gun.flags_gun_features & GUN_BURST_FIRING))
		return
	var/mode = pick_fire_mode(gun, appraisal, distance)
	if(!mode || gun.gun_firemode == mode)
		return
	next_mode_time = world.time + HAI_MODE_SWITCH_TIME
	gun.do_toggle_firemode(body, null, mode)

/// Shots in a row before the brain lets go of the trigger, shorter for the disciplined and longer for suppressing fire
/datum/human_ai_brain/proc/volley_length(datum/human_ai_gun_appraisal/appraisal)
	var/length = HAI_VOLLEY_SHOTS * personality.scaled("discipline", 1.8, 0.7)
	if(appraisal.suppressive)
		length *= 3
	if(suppressed())
		length *= 0.6
	return max(1, round(length))

/// Fires at the target with the right mode and an imperfect aim, true when a shot went out
/datum/human_ai_brain/proc/shoot(obj/item/weapon/gun/gun, atom/target)
	var/datum/human_ai_gun_appraisal/appraisal = get_human_ai_gun_appraisal(gun)
	// The gun is down while a grenade is drawn and thrown, and it does not come back up until the hands are free
	if(world.time < hands_busy_until)
		return FALSE
	// Nothing is fired into a wall, and a shot that wobbles into the wall beside the target is aimed at the target itself further down
	if(wall_in_line(target))
		wall_holds++
		return FALSE
	if(gun.get_gun_user() != body)
		gun.set_gun_user(body)
	if(appraisal.two_handed && !(gun.flags_item & WIELDED) && !body.get_inactive_hand())
		gun.wield(body)
	if(world.time < volley_pause_until || !gun_can_shoot_now(gun))
		return FALSE
	var/distance = get_dist(body, target)
	set_fire_mode(gun, appraisal, distance)
	var/mob/living/carbon/human/victim = target
	body.zone_selected = (istype(victim) && victim.stat >= UNCONSCIOUS) ? "head" : "chest"
	body.face_atom(target)
	if(body.a_intent != INTENT_HARM)
		body.a_intent_change(INTENT_HARM)

	// The aim wanders a little, so roll it a few times and take one that does not put a friend in the line or into a wall, holding fire when none is safe
	var/atom/aimed
	var/wall_only = FALSE
	for(var/attempt in 1 to HAI_FF_AIM_TRIES)
		var/atom/rolled = aim_point(target, gun)
		var/friend_in_way = friendly_in_lane(rolled)
		var/wall_in_way = wall_in_line(rolled)
		if(!friend_in_way && !wall_in_way)
			aimed = rolled
			break
		if(wall_in_way && !friend_in_way)
			wall_only = TRUE
	if(!aimed && wall_only && !friendly_in_lane(target))
		aimed = target
	if(!aimed)
		ff_holds++
		volley_pause_until = world.time + HAI_FF_HOLD
		return FALSE

	var/noise_before = SShuman_ai.noise_cost_ms
	var/started = TICK_USAGE
	var/shot_before = gun.last_fired
	gun.Fire(aimed, body)
	SShuman_ai.gun_cost_ms += max(0, TICK_USAGE_TO_MS(started) - (SShuman_ai.noise_cost_ms - noise_before))

	if(gun.last_fired == shot_before)
		note_fire_failure(gun)
		return FALSE
	fire_failures = 0
	last_shot_time = world.time
	shots_fired++
	if(cover_enabled && in_good_cover(get_turf(target)))
		if(++cover_shots >= HAI_PEEK_SHOTS)
			cover_shots = 0
			volley_pause_until = world.time + HAI_PEEK_DUCK * personality.scaled("caution", 0.6, 1.5)
			peeks++
	if(gun.gun_firemode == GUN_FIREMODE_AUTOMATIC)
		if(volley_left <= 0)
			volley_left = volley_length(appraisal)
		volley_left--
		if(volley_left <= 0)
			volley_pause_until = world.time + HAI_VOLLEY_PAUSE * personality.scaled("discipline", 0.6, 1.8)
	return TRUE

/// The trigger was pulled and nothing came out: rack it once, and give up on the gun for a moment if that does not help
/datum/human_ai_brain/proc/note_fire_failure(obj/item/weapon/gun/gun)
	fire_failures++
	if(fire_failures == 1)
		gun.unique_action(body)
	else if(fire_failures >= HAI_FIRE_FAIL_LIMIT)
		fire_failures = 0
		gun_blocked_until = world.time + HAI_GUN_BLOCK_TIME
		log_decision("[gun.name] will not fire")
