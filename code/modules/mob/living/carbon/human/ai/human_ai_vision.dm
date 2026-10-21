/**
 * What a unit can make out. Its eyes are no better than a person's: past the reach of its night vision a thing standing in the dark cannot be seen at
 * all and one in a dim place takes longer to make out, and a body that is cloaked or camouflaged is only made out from close by. Being shot at from
 * somewhere it cannot make out tells it which way the shot came from and not who fired it or where exactly.
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

/**
 * How clearly the unit makes out the subject from where it stands: 0 when it cannot be made out at all, 1 for plain sight, and the share of it that is
 * left when the subject is in a dim place or half hidden. Someone beside the unit is always made out, nothing hides from an arm's length.
 */
/datum/human_ai_brain/proc/clarity_of(mob/living/candidate, turf/there, distance)
	if(distance <= 1)
		return 1
	var/clarity = 1
	if(is_concealed(candidate))
		if(distance > HAI_CONCEAL_SIGHT)
			return 0
		clarity *= 0.35
	// Night vision goggles light the whole place up for whoever wears them
	var/reach = body.see_in_dark
	if(body.lighting_alpha < body.default_lighting_alpha)
		reach = max(reach, HAI_NIGHT_VISION_REACH)
	if(distance > reach)
		var/light = light_at(there)
		if(light < HAI_DARK_LIGHT)
			return 0
		if(light < HAI_DIM_LIGHT)
			clarity *= 0.4
	return clarity

/// Looks toward a shot that came from somewhere it cannot make out, and goes to see in the direction of it with the guess that far off being a little wrong
/datum/human_ai_brain/proc/look_toward_shot(mob/living/shooter, turf/there)
	var/error = max(1, round(get_dist(body, there) * HAI_NOISE_ERROR * 2))
	var/turf/guess = locate(clamp(there.x + rand(-error, error), 1, world.maxx), clamp(there.y + rand(-error, error), 1, world.maxy), there.z)
	begin_investigation(open_turf_near(guess) || open_turf_near(there) || there, 0.8)
	log_decision("shot at from where it cannot see")
