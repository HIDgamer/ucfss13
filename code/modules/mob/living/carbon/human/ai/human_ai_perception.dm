/// Looks around once: updates what the body can see, fades what it cannot and picks the target
/datum/human_ai_brain/proc/perceive()
	var/turf/here = get_turf(body)
	if(!here)
		return
	var/seconds = clamp((world.time - last_perceive_time) * 0.1, 0.1, 3)
	last_perceive_time = world.time
	for(var/key in contacts)
		var/datum/ai_contact/contact = contacts[key]
		contact.visible = FALSE

	scan_count++
	if(length(contacts) || scan_count % HAI_FULL_SCAN_EVERY == 0 || SSspatial_grid.has_candidates_near(here, body))
		view_scans++
		var/list/unknown
		for(var/mob/living/candidate in view(sight_range(), body))
			if(candidate == body || candidate.stat == DEAD || (candidate.faction == body.faction && !isxeno(candidate) && !iszombie(candidate)))
				continue
			var/disposition = get_disposition(candidate)
			if(disposition < HAI_DISP_HOSTILE)
				if(disposition >= HAI_DISP_WARY && ishuman(candidate))
					note_watch(candidate, disposition)
				else if(disposition == HAI_DISP_NEUTRAL && ishuman(candidate))
					consider_greeting(candidate)
				continue
			var/datum/ai_contact/known = contacts[REF(candidate)]
			if(known)
				note_candidate(candidate, here, seconds, known)
			else
				LAZYADD(unknown, candidate)
		for(var/mob/living/candidate as anything in unknown)
			if(!note_candidate(candidate, here, seconds))
				break

	decay_contacts(seconds)
	prune_watch()
	select_target()

/// Updates what the body knows about a subject in view, false when it has no room to remember a new one
/datum/human_ai_brain/proc/note_candidate(mob/living/candidate, turf/here, seconds, datum/ai_contact/contact)
	var/turf/there = get_turf(candidate)
	if(!contact)
		contact = ensure_contact(candidate)
		if(!contact)
			return FALSE
	var/moved = there != contact.last_turf
	var/was_known = contact.identified()
	if(!contact.identified())
		contact.notice = min(1, contact.notice + seconds / notice_seconds(candidate, here, there, moved))
	contact.last_turf = there
	contact.last_time = world.time
	contact.confidence = 1
	contact.visible = TRUE
	contact.threat = assess_threat(candidate)
	report_to_squad(candidate, contact)
	if(!was_known && contact.identified())
		announce_contact(candidate)
	if(!contact.identified() && contact.notice >= HAI_SUSPECT_NOTICE)
		body.face_atom(candidate)
		alert_until = max(alert_until, world.time + 3 SECONDS)
	return TRUE

/// How long this subject must stay in view before it is made out
/datum/human_ai_brain/proc/notice_seconds(mob/living/candidate, turf/here, turf/there, moved)
	var/distance = get_dist(here, there)
	if(distance <= 1)
		return 0.1
	var/seconds = 0.5 + distance * 0.25
	var/off_axis = Get_Angle(body, candidate) - dir2angle(body.dir)
	if(off_axis > 180)
		off_axis -= 360
	else if(off_axis < -180)
		off_axis += 360
	off_axis = abs(off_axis)
	if(off_axis > 110)
		seconds *= (distance <= 2) ? 3 : 6
	else if(off_axis > 70)
		seconds *= 2
	seconds *= moved ? 0.6 : 1.4
	if(candidate.body_position == LYING_DOWN)
		seconds *= 1.6
	if(distance > 2 && body.see_in_dark < 6)
		var/light = there.get_lumcount()
		if(light < 0.2)
			seconds *= 2.5
		else if(light < 0.4)
			seconds *= 1.5
	return seconds / (0.5 + personality.trait("alertness") * 0.01)

/// How dangerous the subject looks right now
/datum/human_ai_brain/proc/assess_threat(mob/living/subject)
	var/threat = 20
	if(isxeno(subject))
		var/mob/living/carbon/xenomorph/xeno = subject
		threat = 30 + xeno.tier * 15
	else if(ishuman(subject))
		var/mob/living/carbon/human/other = subject
		threat = iszombie(other) ? 25 : (istype(other.get_active_hand(), /obj/item/weapon/gun) ? 45 : 15)
	var/distance = get_dist(body, subject)
	threat *= (distance <= 2) ? 1.5 : ((distance <= 6) ? 1 : 0.7)
	if(get_dir(subject, body) == subject.dir)
		threat *= 1.3
	if(subject == last_attacker_ref?.resolve() && world.time < last_hurt_time + 10 SECONDS)
		threat *= 1.5
	return threat

/// Picks the contact to deal with, the current target is only dropped for something clearly worse
/datum/human_ai_brain/proc/select_target()
	var/mob/living/current = get_target()
	if(current && spares_downed(current))
		set_target(null)
		current = null
	var/list/candidates = list()
	var/best_score = 0
	for(var/key in contacts)
		var/datum/ai_contact/contact = contacts[key]
		if(!contact.identified() || (!contact.visible && contact.confidence < 0.2))
			continue
		var/mob/living/subject = contact.get_subject()
		if(spares_downed(subject))
			continue
		var/score = contact.threat + (contact.visible ? 20 : 0)
		if(subject == current)
			score *= 1.15
		candidates[subject] = score
		best_score = max(best_score, score)
	if(!length(candidates))
		return
	var/list/contenders = list()
	for(var/mob/living/subject as anything in candidates)
		if(candidates[subject] >= best_score * 0.9)
			contenders += subject
	var/mob/living/chosen = (current in contenders) ? current : pick(contenders)
	var/mob/living/forced = current_order?.forced_target()
	if(forced && (forced in candidates))
		chosen = forced
	if(chosen != current)
		set_target(chosen)
	var/datum/ai_contact/chosen_contact = get_contact(chosen)
	if(chosen_contact?.visible)
		target_seen_time = world.time

/// Works out what the brain should be doing from what it knows, called every think
/datum/human_ai_brain/proc/refresh_intent()
	if(surrendered || (broken_kind && broken_kind != HAI_BREAK_BERSERK))
		set_intent(HAI_INTENT_BROKEN, "broken")
		return
	var/mob/living/target = get_target()
	if(target)
		var/unseen = world.time - target_seen_time
		if(unseen <= HAI_ENGAGE_MEMORY)
			end_investigation()
			set_intent(HAI_INTENT_ENGAGE, "target in sight")
			return
		var/datum/ai_contact/last_known = get_contact(target)
		if(!investigate_turf)
			begin_investigation(last_known?.last_turf || get_turf(target), 1)
		if(unseen > search_patience())
			set_target(null)
			remove_contact(target)
			end_investigation()
			alert_until = world.time + 8 SECONDS
			set_intent(HAI_INTENT_ALERT, "gave up the search")
			return
		set_intent(HAI_INTENT_INVESTIGATE, "lost sight")
		return
	if(current_order)
		end_investigation()
		set_intent(HAI_INTENT_ORDERED)
		return
	if(investigate_turf)
		if(investigate_until > world.time)
			set_intent(HAI_INTENT_INVESTIGATE, "checking something out")
			return
		end_investigation()
		alert_until = world.time + 6 SECONDS
	set_intent(alert_until > world.time ? HAI_INTENT_ALERT : HAI_INTENT_IDLE)

/datum/human_ai_brain/proc/search_patience()
	return HAI_SEARCH_PATIENCE * (0.7 + personality.trait("alertness") * 0.008)

/datum/human_ai_brain/proc/begin_investigation(turf/where, strength)
	if(current_order?.hard || role?.passive)
		return
	if(investigate_turf && investigate_strength >= strength && investigate_until > world.time)
		return
	investigate_turf = where
	investigate_strength = strength
	investigate_until = world.time + search_patience()
	search_points = null
	search_index = 0
	log_decision("investigating [where.x],[where.y]")

/datum/human_ai_brain/proc/end_investigation()
	investigate_turf = null
	investigate_strength = 0
	search_points = null

/// Walks to the place to check and then looks around a few spots near it
/datum/human_ai_brain/proc/investigate_step()
	if(!investigate_turf)
		return FALSE
	var/turf/goal = investigate_turf
	if(search_points)
		if(search_index > length(search_points))
			end_investigation()
			alert_until = world.time + 6 SECONDS
			return FALSE
		goal = search_points[search_index]
	if(move_to(goal, 1))
		return TRUE
	if(move_state == HAI_MOVE_BLOCKED && !search_points)
		end_investigation()
		return FALSE
	if(world.time < search_wait_until)
		body.setDir(turn(body.dir, 90))
		return TRUE
	if(!search_points)
		search_points = pick_search_points(investigate_turf)
		search_index = 0
	search_index++
	search_wait_until = world.time + 20
	return TRUE

/datum/human_ai_brain/proc/pick_search_points(turf/center)
	var/list/points = list()
	var/list/open = list()
	for(var/turf/open/candidate in view(HAI_SEARCH_RADIUS, center))
		if(!candidate.density && get_dist(candidate, center) >= 2)
			open += candidate
	for(var/pick_count in 1 to min(HAI_SEARCH_POINTS, length(open)))
		points += pick_n_take(open)
	return points

/// A noise reached the body, turns toward it and goes to look when it is loud enough
/datum/human_ai_brain/proc/hear_noise(turf/source_turf, kind, distance, noise_range, atom/emitter)
	var/mob/living/maker = ismob(emitter) ? emitter : null
	if(maker == body)
		return
	if(kind == HAI_NOISE_EXPLOSION)
		express(HAI_EXPR_EXPLOSION)
	if(maker && (maker.faction == body.faction || get_disposition(maker) <= HAI_DISP_FRIEND))
		alert_until = max(alert_until, world.time + 3 SECONDS)
		return
	var/strength = clamp(1 - distance / max(noise_range, 1), 0.1, 1) * noise_weight(kind)
	if(strength < HAI_NOISE_ALERT)
		return
	alert_until = max(alert_until, world.time + 5 SECONDS)
	if(kind == HAI_NOISE_GUNSHOT || kind == HAI_NOISE_EXPLOSION)
		panic()
	if(!get_target() || world.time > target_seen_time + HAI_ENGAGE_MEMORY)
		body.face_atom(source_turf)
	if(strength < HAI_NOISE_INVESTIGATE || intent == HAI_INTENT_ENGAGE)
		return
	var/error = round(distance * HAI_NOISE_ERROR)
	var/turf/guess = error ? locate(clamp(source_turf.x + rand(-error, error), 1, world.maxx), clamp(source_turf.y + rand(-error, error), 1, world.maxy), source_turf.z) : source_turf
	begin_investigation(open_turf_near(guess) || open_turf_near(source_turf) || source_turf, strength)

/// The turf itself when it can be stood on, otherwise the closest open turf within two tiles
/datum/human_ai_brain/proc/open_turf_near(turf/center)
	if(!center)
		return null
	if(!center.density)
		return center
	var/turf/closest
	var/closest_distance = INFINITY
	for(var/turf/candidate in range(2, center))
		if(candidate.density)
			continue
		var/distance = get_dist(candidate, center)
		if(distance < closest_distance)
			closest = candidate
			closest_distance = distance
	return closest

/datum/human_ai_brain/proc/noise_weight(kind)
	switch(kind)
		if(HAI_NOISE_EXPLOSION)
			return 1.3
		if(HAI_NOISE_GUNSHOT)
			return 1
		if(HAI_NOISE_ALARM)
			return 0.8
		if(HAI_NOISE_GLASS)
			return 0.7
		if(HAI_NOISE_DOOR, HAI_NOISE_MELEE)
			return 0.5
	return 0.35

/datum/human_ai_brain/proc/signal_bullet_act(datum/source, damage_result, ammo_flags, obj/projectile/bullet)
	SIGNAL_HANDLER
	var/mob/living/shooter = bullet?.firer
	if(!istype(shooter))
		return
	last_hurt_time = world.time
	// Someone on its own side is not an enemy, it is given a warning and a few chances before it is
	var/tolerated = shooter != body && tolerates_hits_from(shooter)
	if(!(tolerated && role?.tolerant))
		express(HAI_EXPR_PAIN)
	if(tolerated)
		note_friendly_hit(shooter)
		return
	last_attacker_ref = WEAKREF(shooter)
	on_shot_at(shooter)

/// Damage with no shooter behind it, so whoever stands next to the body takes the blame
/datum/human_ai_brain/proc/signal_take_damage(datum/source, list/damagedata, damagetype)
	SIGNAL_HANDLER
	last_hurt_time = world.time
	add_stress(2)
	if(surrendered)
		end_surrender("attacked")
	// A Joe puts up with a good deal from people who are not its enemies, and tells them about it
	if(role?.tolerant)
		for(var/mob/living/bother in range(1, body))
			if(bother != body && bother.stat != DEAD && bother.a_intent == INTENT_HARM && tolerates_hits_from(bother))
				note_friendly_hit(bother)
				return
	for(var/mob/living/attacker in range(1, body))
		if(attacker != body && is_valid_target(attacker))
			last_attacker_ref = WEAKREF(attacker)
			identify_now(attacker)
			alert_until = world.time + 8 SECONDS
			return

/// Someone fired along a line that passes close to the body, or hit it
/datum/human_ai_brain/proc/on_shot_at(mob/living/shooter)
	if(!shooter || shooter == body || get_disposition(shooter) <= HAI_DISP_FRIEND)
		return
	identify_now(shooter)
	body.face_atom(shooter)
	alert_until = world.time + 8 SECONDS
	last_shot_at_time = world.time
	end_stand_down()
	if(role?.nests)
		nest_hits++
	express(HAI_EXPR_TAKING_FIRE)
	panic()
	add_stress(4)
