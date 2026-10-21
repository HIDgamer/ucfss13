/// Whether the object is solid and plain enough to be named when saying where somebody is
/datum/human_ai_brain/proc/callout_object(obj/thing)
	if(QDELETED(thing) || thing.invisibility || !thing.density || !length(thing.name))
		return FALSE
	if(istype(thing, /obj/effect) || istype(thing, /obj/structure/stairs) || istype(thing, /obj/structure/machinery/light))
		return FALSE
	return istype(thing, /obj/structure) || istype(thing, /obj/vehicle)

/**
 * Where the subject is in terms of what stands next to it, "behind the table" when the thing is between the speaker and the subject and "by the
 * crate" otherwise, null when nothing nameable is close. This is what makes a call-out sound like somebody who is looking at the spot.
 */
/datum/human_ai_brain/proc/describe_spot(mob/living/subject)
	var/turf/there = get_turf(subject)
	if(!there)
		return null
	var/obj/best
	var/best_distance = INFINITY
	for(var/obj/thing in range(1, there))
		if(!callout_object(thing))
			continue
		var/distance = get_dist(thing, there)
		if(distance < best_distance)
			best = thing
			best_distance = distance
	if(!best)
		return null
	var/label = lowertext(trim(strip_improper("[best.name]")))
	if(!length(label))
		return null
	if(get_dist(body, best) < get_dist(body, there))
		return "behind the [label]"
	return "by the [label]"

/// A line with the place added before its last mark of punctuation, "Contact east!" becomes "Contact east behind the table!"
/proc/human_ai_add_callout(line, phrase)
	var/size = length(line)
	var/last = copytext(line, size, size + 1)
	if(last in list("!", ".", "?"))
		return "[copytext(line, 1, size)] [phrase][last]"
	return "[line] [phrase]"
