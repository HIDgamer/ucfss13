/**
 * A hit from someone on the brain's own side. One or two are taken for a mistake and draw a warning, a few in a row and the brain stops giving
 * them the benefit of the doubt and hits back for a while, after which it goes back to treating them as a friend. Merciful brains forgive more.
 */
/datum/human_ai_brain/proc/note_friendly_hit(mob/living/shooter)
	if(QDELETED(shooter) || shooter == body || shooter.stat == DEAD)
		return
	var/key = REF(shooter)
	var/list/record = tolerance[key]
	if(!record || world.time > record[2] + HAI_TOLERANCE_WINDOW)
		if(length(tolerance) >= 10)
			tolerance.Cut(1, 2)
		record = list(0, world.time)
		tolerance[key] = record
	record[1]++
	record[2] = world.time
	var/allowed = max(2, HAI_TOLERANCE_HITS + round(personality.scaled("mercy", -1, 1.5)))
	if(record[1] < allowed)
		body.face_atom(shooter)
		express(HAI_EXPR_WATCH_FIRE)
		add_stress(2)
		log_decision("[shooter] hit me from my own side, [record[1]] of [allowed]")
		return
	tolerance -= key
	disposition_override[key] = world.time + HAI_TOLERANCE_GRUDGE
	last_attacker_ref = WEAKREF(shooter)
	identify_now(shooter)
	alert_until = world.time + 8 SECONDS
	end_stand_down()
	express(HAI_EXPR_HOSTILE)
	escalations++
	log_decision("[shooter] kept shooting me, hitting back")

/// Whether the brain is currently fighting someone it would otherwise call a friend, because they shot it too often
/datum/human_ai_brain/proc/holds_grudge_against(mob/living/other)
	return is_overridden_hostile(other)
