/**
 * Keeps the body inside a circle. Anything it wants to walk to outside the circle is refused, so it fights from where it stands, and a body that
 * finds itself outside makes for the middle first.
 */
/datum/human_ai_brain/proc/set_leash(turf/center, radius)
	leash_center = center
	leash_radius = radius
	release_post()
	next_post_search = 0
	path = null
	log_decision("held to [radius] tiles around [center.x],[center.y]")

/datum/human_ai_brain/proc/clear_leash()
	if(!leash_center)
		return
	leash_center = null
	leash_radius = 0
	release_post()
	next_post_search = 0
	path = null
	log_decision("let off the leash")

/// Whether the body is inside the circle it is held to, always true without one
/datum/human_ai_brain/proc/inside_leash(turf/where)
	return !leash_center || where.z != leash_center.z || get_dist(where, leash_center) <= leash_radius

/// Stand in a place and hold it: every unit takes a post of its own inside the circle, faces the way it sees furthest and does not leave
/datum/npc_order/hold_area
	id = "hold_area"
	name = "Hold area"
	radius = HAI_HOLD_AREA_RADIUS

/datum/npc_order/hold_area/can_perform(datum/human_ai_brain/performer)
	return target_turf ? null : "no area to hold"

/datum/npc_order/hold_area/begin(datum/human_ai_brain/performer)
	..()
	performer.set_leash(target_turf, radius)

/datum/npc_order/hold_area/cleanup(datum/human_ai_brain/performer)
	performer.clear_leash()

/datum/npc_order/hold_area/tick(datum/human_ai_brain/performer)
	// A fight inside the circle is the unit's own business, the leash keeps it from being chased out of it
	if(performer.get_target())
		return FALSE
	if(!performer.inside_leash(get_turf(performer.body)))
		return performer.move_to(target_turf, 1, get_dist(performer.body, target_turf) > HAI_SPRINT_MIN_DISTANCE)
	var/turf/post = performer.choose_post()
	if(!post)
		return performer.move_to(target_turf, 1, FALSE)
	if(get_turf(performer.body) != post)
		return performer.move_to(post, 0, FALSE)
	if(performer.post_dir)
		performer.body.setDir(performer.post_dir)
	return FALSE
