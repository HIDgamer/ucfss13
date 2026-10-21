/**
 * What a unit can make out. Its eyes are no better than a person's: past the reach of its night vision a thing standing in the dark is hard to make out and
 * then not at all, a dim place takes longer, and a body that is cloaked or camouflaged is only made out from close by. What it wears over its eyes counts,
 * a welding mask pulled down leaves it seeing little more than what is at arm's length. Being shot at from somewhere it cannot make out tells it which way
 * the shot came from and not who fired it or where exactly.
 */

/// How much light there is on the tile: what the lamps give it and what the area gives all of it, the sun or a place that is lit up as a whole, which the lamp count leaves out
/proc/human_ai_turf_light(turf/there)
	var/light = there.get_lumcount()
	var/area/place = there.loc
	if(place?.area_has_base_lighting)
		light += place.base_lighting_alpha / 255
	return min(light, 1)

/// The light on the tile as the unit sees it
/datum/human_ai_brain/proc/light_at(turf/there)
	if(!isnull(light_override))
		return light_override
	return human_ai_turf_light(there)

/// Whether the body is hiding behind a cloak or camouflage so that nothing but a shimmer is left of it
/datum/human_ai_brain/proc/is_concealed(mob/living/candidate)
	if(HAS_TRAIT(candidate, TRAIT_CLOAKED))
		return TRUE
	return candidate.alpha <= HAI_CONCEAL_ALPHA

/// How much of the sight is taken away by what is worn over the eyes, as the game counts it for a player, from nothing to the most
/datum/human_ai_brain/proc/eye_tint()
	var/tint = 0
	if(body.head)
		tint += body.head.vision_impair
	if(body.glasses)
		tint += body.glasses.vision_impair
	if(body.wear_mask)
		tint += body.wear_mask.vision_impair
	return min(tint, VISION_IMPAIR_MAX)

/// The farthest the unit sees through what it wears and with the eyes it has, a blind one only feels what is next to it. Worked out once for every moment it is asked
/datum/human_ai_brain/proc/eye_reach()
	if(eye_reach_time == world.time)
		return eye_reach_value
	eye_reach_time = world.time
	var/reach = INFINITY
	if(body.eye_blind || body.stat != CONSCIOUS)
		reach = 0
	else
		var/tint = eye_tint()
		if(tint)
			reach = max(1, round(HAI_SIGHT_RANGE * (1 - tint / VISION_IMPAIR_MAX)))
		if(body.eye_blurry)
			reach = min(reach, HAI_BLURRY_REACH)
	eye_reach_value = reach
	return reach

/// Whether the unit sees in the dark, with goggles that turn night into day
/datum/human_ai_brain/proc/has_night_vision()
	return body.lighting_alpha < body.default_lighting_alpha

/**
 * How clearly the unit makes out the subject from where it stands: 0 when it cannot be made out at all, 1 for plain sight, and the share of it that is
 * left when the subject is in a dim place or half hidden. Someone beside the unit is always made out, nothing hides from an arm's length.
 */
/datum/human_ai_brain/proc/clarity_of(mob/living/candidate, turf/there, distance)
	if(distance <= 1)
		return 1
	if(distance > eye_reach())
		return 0
	var/clarity = 1
	if(is_concealed(candidate))
		if(distance > HAI_CONCEAL_SIGHT)
			return 0
		clarity *= 0.35
	// Night vision goggles light the whole place up for whoever wears them
	var/reach = body.see_in_dark
	if(has_night_vision())
		reach = max(reach, HAI_NIGHT_VISION_REACH)
	if(distance > reach)
		// Past what the eyes reach in the dark, it is the light on the subject that decides: none, and nothing is made out, daylight, and all of it is
		var/light = light_at(there)
		if(light < HAI_DARK_LIGHT)
			return 0
		if(light < HAI_LIT_LIGHT)
			clarity *= HAI_DIM_CLARITY + (1 - HAI_DIM_CLARITY) * (light - HAI_DARK_LIGHT) / (HAI_LIT_LIGHT - HAI_DARK_LIGHT)
	return clarity

/// Looks toward a shot that came from somewhere it cannot make out, and goes to see in the direction of it with the guess that far off being a little wrong
/datum/human_ai_brain/proc/look_toward_shot(mob/living/shooter, turf/there)
	var/error = max(1, round(get_dist(body, there) * HAI_NOISE_ERROR * 2))
	var/turf/guess = locate(clamp(there.x + rand(-error, error), 1, world.maxx), clamp(there.y + rand(-error, error), 1, world.maxy), there.z)
	begin_investigation(open_turf_near(guess) || open_turf_near(there) || there, 0.8)
	log_decision("shot at from where it cannot see")
