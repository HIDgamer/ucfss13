/// Turfs held as posts and the brain that holds each, so two idlers do not take the same spot
GLOBAL_LIST_EMPTY(human_ai_posts)

/// Whether the brain is the kind that picks a place to stand watch while idle, civilians still stroll about
/datum/human_ai_brain/proc/holds_a_post()
	return !is_civilian() && !surrendered && !broken_kind

/datum/human_ai_brain/proc/release_post()
	if(post_turf && GLOB.human_ai_posts[post_turf] == src)
		GLOB.human_ai_posts -= post_turf
	post_turf = null

/// What blocks both sight and bullets on the turf: a wall, or something solid, fixed and tall enough to matter
/datum/human_ai_brain/proc/post_blocker(turf/beside)
	if(!beside || beside.density)
		return TRUE
	for(var/obj/thing in beside)
		if(thing.density && thing.anchored && thing.projectile_coverage >= PROJECTILE_COVERAGE_LOW)
			return TRUE
	return FALSE

/// How far a clear line runs from the turf in the direction, up to the view limit
/datum/human_ai_brain/proc/post_sight(turf/from, direction)
	var/turf/step_turf = from
	for(var/length in 1 to HAI_POST_VIEW)
		step_turf = get_step(step_turf, direction)
		if(!step_turf || step_turf.opacity || post_blocker(step_turf))
			return length - 1
	return HAI_POST_VIEW

/// The way the unit keeps watch standing where it is, the way it sees furthest, worked out once for each place it stands in
/datum/human_ai_brain/proc/watch_direction()
	var/turf/here = get_turf(body)
	if(watch_dir && watch_turf == here)
		return watch_dir
	watch_turf = here
	var/best_view = -1
	watch_dir = body.dir
	for(var/direction in GLOB.alldirs)
		var/view = post_sight(here, direction)
		if(view > best_view)
			best_view = view
			watch_dir = direction
	return watch_dir

/**
 * How good the turf is to stand watch from, as list(value, facing), null when it is no use at all. Something solid at its back and a long view
 * the other way is best, an open floor that is seen from everywhere is poor and a dead end that sees nothing is worse, and a spot far from home loses a little.
 */
/datum/human_ai_brain/proc/post_value(turf/candidate, turf/home)
	var/backed = 0
	var/best_view = 0
	var/open_ways = 0
	var/best_dir = body.dir
	for(var/direction in GLOB.alldirs)
		if(post_blocker(get_step(candidate, direction)))
			if(direction in GLOB.cardinals)
				backed++
			continue
		var/view = post_sight(candidate, direction)
		if(view >= 4)
			open_ways++
		if(view > best_view)
			best_view = view
			best_dir = direction
	if(backed >= 4 || !best_view)
		return null
	var/value = min(backed, 2) + (best_view / HAI_POST_VIEW) * 1.5 - max(0, open_ways - 4) * 0.4 - get_dist(candidate, home) * 0.08
	if(backed >= 3)
		value -= 1
	return list(value, best_dir)

/// Whether another brain already stands watch on, or right beside, the turf
/datum/human_ai_brain/proc/post_taken(turf/candidate)
	for(var/turf/claimed as anything in GLOB.human_ai_posts)
		if(get_dist(claimed, candidate) > 1)
			continue
		var/datum/human_ai_brain/holder = GLOB.human_ai_posts[claimed]
		if(holder != src && !QDELETED(holder))
			return TRUE
	return FALSE

/**
 * The turf this brain stands watch from, weighed again every few minutes and kept unless something clearly better turns up.
 * Only spots in plain sight of home are looked at, so a post never sits behind a wall or a door the brain cannot open.
 */
/datum/human_ai_brain/proc/choose_post()
	if(post_turf && world.time < next_post_search)
		return post_turf
	if(world.time < next_post_search || !SShuman_ai.take_cover_budget())
		return post_turf
	next_post_search = world.time + HAI_POST_RECHECK
	// A unit held to a circle keeps its post inside it, around the middle of it
	var/turf/home = leash_center || home_turf || get_turf(body)
	if(!home)
		return post_turf
	var/list/spots = list()
	for(var/turf/candidate in range(leash_center ? leash_radius : HAI_POST_RADIUS, home))
		spots += candidate
	spots = shuffle(spots)
	if(length(spots) > HAI_POST_CANDIDATES)
		spots.Cut(HAI_POST_CANDIDATES + 1)
	if(post_turf)
		spots += post_turf
	var/turf/best
	var/best_value = -INFINITY
	var/best_dir = body.dir
	for(var/turf/candidate as anything in spots)
		if(candidate != post_turf && (!cover_turf_usable(candidate) || post_taken(candidate) || is_blocked_turf(candidate) || !cover_has_line(candidate, home)))
			continue
		var/list/rated = post_value(candidate, home)
		if(!rated)
			continue
		var/value = rated[1] + (candidate == post_turf ? 0.5 : 0)
		if(value > best_value)
			best_value = value
			best = candidate
			best_dir = rated[2]
	if(!best)
		return post_turf
	if(best != post_turf)
		release_post()
		post_turf = best
		GLOB.human_ai_posts[best] = src
		posts_taken++
		log_decision("took a post at [best.x],[best.y]")
	post_dir = best_dir
	return post_turf

/// Settles on the post: walking there when it is not there yet and looking the way the post sees furthest once it is
/datum/human_ai_brain/proc/man_post()
	var/turf/post = choose_post()
	if(!post)
		return FALSE
	if(get_turf(body) != post)
		idle_goal = post
		return TRUE
	if(post_dir)
		body.setDir(post_dir)
	return FALSE
