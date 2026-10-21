/**
 * Moving about unseen. How easy a man is to notice depends on how he moves, a run is seen sooner than a walk and a walk sooner than standing still, on how
 * he lies, in what light he stands and which way the watcher looks; running footsteps carry and a walk does not. A unit that has found something wrong, a shot,
 * a noise, a friend lying dead, stays on edge for a couple of minutes and notices everything faster for it, and it tells the rest of its squad. Over its head
 * a marker can show that something stirred it, which is for the players who are trying not to be seen.
 */

/// How much the way the subject moves and lies makes it easier or harder to notice, bigger is slower: a run is the quickest to give a man away and lying still the slowest
/datum/human_ai_brain/proc/stealth_pace(mob/living/candidate, moved)
	var/pace = moved ? 0.85 : 1.5
	if(moved && candidate.m_intent == MOVE_INTENT_RUN)
		pace = 0.55
	if(candidate.body_position == LYING_DOWN)
		pace *= 1.6
	return pace

/// How alarmed the unit is right now, from nothing to one, falling by itself the longer nothing happens
/datum/human_ai_brain/proc/vigilance()
	if(!vigilance_level)
		return 0
	var/left = vigilance_level - (world.time - vigilance_time) / HAI_VIGILANCE_FADE
	if(left <= 0)
		vigilance_level = 0
		return 0
	return left

/datum/human_ai_brain/proc/raise_vigilance(amount)
	vigilance_level = clamp(vigilance() + amount, 0, 1)
	vigilance_time = world.time

/// What one man has found puts the rest of his squad on edge too, if less so
/datum/human_ai_brain/proc/raise_squad_vigilance(amount)
	if(!squad)
		return
	for(var/datum/human_ai_brain/mate as anything in squad.members)
		if(mate != src)
			mate.raise_vigilance(amount * HAI_SQUAD_ALARM_SHARE)

/// Shows a marker over the head if markers are on: a question mark for something that stirred it, an exclamation mark for something it knows
/datum/human_ai_brain/proc/show_cue(cue)
	if(!SShuman_ai.stealth_cues || QDELETED(body) || world.time < next_cue_time)
		return
	next_cue_time = world.time + HAI_CUE_GAP
	if(cue == HAI_CUE_ALERT)
		body.balloon_alert_to_viewers("!", null, 9, text_color = "#ff5a4d")
	else
		body.balloon_alert_to_viewers("?", null, 9, text_color = "#ffd166")

/// A subject has just been made out for what it is
/datum/human_ai_brain/proc/note_spotted(datum/ai_contact/contact)
	contact.cue_stage = HAI_CUE_ALERT
	show_cue(HAI_CUE_ALERT)
	raise_vigilance(0.6)
	raise_squad_vigilance(0.6)

/// Something about a subject not yet made out has caught its eye
/datum/human_ai_brain/proc/note_suspect(datum/ai_contact/contact)
	if(contact.cue_stage >= HAI_CUE_SUSPECT)
		return
	contact.cue_stage = HAI_CUE_SUSPECT
	show_cue(HAI_CUE_SUSPECT)
	raise_vigilance(0.1)

/**
 * A man of its own side lying dead or knocked out where it can see him is not something that happens by itself: it calls it, it is on edge for a long while and
 * it goes to look round the body for whoever did it, unless it is busy with an enemy already. Each body is only found once.
 */
/datum/human_ai_brain/proc/notice_fallen_friend(mob/living/carbon/human/fallen, turf/here)
	if(is_civilian() || role?.maintains || !isturf(fallen.loc) || fallen.buckled)
		return
	var/key = REF(fallen)
	if(known_bodies?[key] > world.time)
		return
	var/turf/there = fallen.loc
	if(!clarity_of(fallen, there, get_dist(here, there)))
		return
	if(!known_bodies)
		known_bodies = list()
	if(length(known_bodies) >= 20)
		known_bodies.Cut(1, 2)
	known_bodies[key] = world.time + HAI_BODY_MEMORY
	bodies_found++
	raise_vigilance(0.8)
	raise_squad_vigilance(0.8)
	alert_until = max(alert_until, world.time + 10 SECONDS)
	body.face_atom(fallen)
	log_decision("found [fallen] [fallen.stat == DEAD ? "dead" : "down"]")
	if(get_target() || intent == HAI_INTENT_ENGAGE)
		return
	express(HAI_EXPR_MAN_DOWN)
	show_cue(HAI_CUE_ALERT)
	begin_investigation(open_turf_near(there) || there, 0.6)

/// A step was taken on the floor, heard by anyone of another side close enough, a man running carries and a man walking does not. The steps of the AI's own men are not listened for, they see each other
/proc/human_ai_footstep(mob/living/carbon/human/walker, turf/step_turf, noise_range)
	if(!length(GLOB.ai_human_list) || !step_turf || walker.ai_brain)
		return
	for(var/mob/living/carbon/human/listener as anything in SSspatial_grid.ai_humans_in_range(step_turf, noise_range))
		var/datum/human_ai_brain/brain = listener.ai_brain
		if(listener == walker || !brain || listener.stat != CONSCIOUS || listener.z != step_turf.z || listener.faction == walker.faction || brain.intent == HAI_INTENT_ENGAGE)
			continue
		var/distance = max(abs(listener.x - step_turf.x), abs(listener.y - step_turf.y))
		if(distance > noise_range)
			continue
		brain.hear_noise(step_turf, HAI_NOISE_STEP, distance, noise_range, walker)
