/// Nothing to do: armed brains stand watch from a defensive post, civilians stroll near home, and now and then one mutters something or chats with a neighbor
/datum/human_ai_action/idle_life
	id = "idle_life"
	conflicts = HAI_LIMB_LEGS
	intents = list(HAI_INTENT_IDLE)

/datum/human_ai_action/idle_life/get_weight(datum/human_ai_brain/brain)
	if(brain.current_order || brain.waypoint || brain.follow_ref || brain.surrendered || brain.broken_kind || brain.civilian_alarm())
		return 0
	if(brain.idle_goal)
		return 12
	return world.time >= brain.next_idle_time ? 9 : 0

/datum/human_ai_action/idle_life/trigger(datum/human_ai_brain/brain)
	return brain.idle_step()

/datum/human_ai_brain/proc/idle_step()
	if(idle_goal)
		if(move_to(idle_goal, 0, FALSE))
			return TRUE
		if(move_state == HAI_MOVE_BLOCKED)
			// Nothing leads there, so a goal that keeps being picked is dropped for good rather than walked at again and again
			remember_blocked(idle_goal, "cannot get to the idle goal", HAI_DOOR_DENIED_MEMORY)
			if(idle_goal == post_turf)
				release_post()
				next_post_search = 0
		idle_goal = null
		if(post_turf && get_turf(body) == post_turf && post_dir)
			body.setDir(post_dir)
		next_idle_time = world.time + rand(HAI_IDLE_GAP_MIN, HAI_IDLE_GAP_MAX)
		return FALSE
	next_idle_time = world.time + rand(HAI_IDLE_GAP_MIN, HAI_IDLE_GAP_MAX)
	var/has_post = holds_a_post()
	if(has_post && man_post())
		return TRUE
	var/list/choices = list(
		"look" = 40,
		"talk" = round(personality.trait("chattiness") * 0.1),
		"chat" = round(personality.trait("sociability") * 0.1),
	)
	if(!has_post)
		choices["wander"] = round(5 + personality.trait("initiative") * 0.15)
	switch(pick_weight(choices))
		if("look")
			// On watch the brain only glances either side of the way it faces, it does not turn its back on the approach
			body.setDir(has_post && post_dir ? turn(post_dir, pick(0, 0, 45, -45)) : turn(body.dir, pick(45, -45, 90, -90)))
		if("wander")
			return start_wander()
		if("talk")
			express(HAI_EXPR_IDLE)
		if("chat")
			start_conversation()
	return FALSE

/// Picks a spot near home to walk to
/datum/human_ai_brain/proc/start_wander()
	var/turf/home = home_turf || get_turf(body)
	if(!home)
		return FALSE
	var/turf/pick_spot = locate(clamp(home.x + rand(-HAI_IDLE_WANDER_RADIUS, HAI_IDLE_WANDER_RADIUS), 1, world.maxx), clamp(home.y + rand(-HAI_IDLE_WANDER_RADIUS, HAI_IDLE_WANDER_RADIUS), 1, world.maxy), home.z)
	var/turf/goal = pick_spot ? open_turf_near(pick_spot) : null
	if(!goal || get_dist(goal, home) > HAI_IDLE_WANDER_RADIUS + 1 || !cover_has_line(goal, home))
		return FALSE
	idle_goal = goal
	idle_wanders++
	return TRUE

/// A conscious idle AI human of the same side close by
/datum/human_ai_brain/proc/find_convo_partner()
	for(var/mob/living/carbon/human/other in range(3, body))
		var/datum/human_ai_brain/partner = other.ai_brain
		if(!partner || partner == src || other.faction != body.faction || partner.intent != HAI_INTENT_IDLE || partner.current_order)
			continue
		if(partner.surrendered || partner.broken_kind || partner.role?.joe_voice || world.time < partner.next_convo_time || !partner.can_express())
			continue
		return partner
	return null

/datum/human_ai_brain/proc/start_conversation()
	if(world.time < next_convo_time || role?.joe_voice)
		return FALSE
	var/datum/human_ai_brain/partner = find_convo_partner()
	if(!partner)
		return FALSE
	var/list/talk = get_human_ai_voice(body.faction).small_talk()
	if(!talk || !express_line(HAI_EXPR_CONVO, talk[1]))
		return FALSE
	next_convo_time = world.time + HAI_CONVO_GAP
	partner.next_convo_time = world.time + HAI_CONVO_GAP
	convos_started++
	body.face_atom(partner.body)
	partner.body.face_atom(body)
	addtimer(CALLBACK(partner, TYPE_PROC_REF(/datum/human_ai_brain, answer_conversation), talk[2]), rand(15, 30))
	return TRUE

/datum/human_ai_brain/proc/answer_conversation(line)
	if(stopped || QDELETED(body))
		return
	if(express_line(HAI_EXPR_CONVO, line))
		convo_answers++

/// Friendly types say hello to a stranger who comes close
/datum/human_ai_brain/proc/consider_greeting(mob/living/carbon/human/other)
	if(personality.trait("sociability") < 70 || get_dist(body, other) > 3)
		return
	var/key = REF(other)
	if(greeted[key] && world.time < greeted[key] + HAI_GREET_MEMORY)
		return
	if(express(HAI_EXPR_GREET))
		greeted[key] = world.time
		body.face_atom(other)
