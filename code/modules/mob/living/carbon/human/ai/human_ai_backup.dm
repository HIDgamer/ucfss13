/**
 * The first contact of a fight: says it with the name of the area, over the radio when the body wears a headset, and draws the nearest few
 * allies who are not busy toward the body. True when the call went out, false when it was too soon or could not be said.
 */
/datum/human_ai_brain/proc/call_for_backup(mob/living/subject)
	if(world.time < next_backup_call || is_civilian() || surrendered || broken_kind)
		return FALSE
	var/turf/here = get_turf(body)
	if(!here || !express(HAI_EXPR_BACKUP, subject ? direction_to(subject) : null))
		return FALSE
	next_backup_call = world.time + HAI_BACKUP_GAP
	backups_called++
	var/list/near = list()
	for(var/datum/human_ai_brain/other as anything in SShuman_ai.brains)
		if(other.can_answer_backup(src, here))
			near[other] = get_dist(other.body, here)
	for(var/answer in 1 to HAI_BACKUP_ANSWERS)
		var/datum/human_ai_brain/closest
		var/closest_distance = INFINITY
		for(var/datum/human_ai_brain/other as anything in near)
			if(near[other] < closest_distance)
				closest = other
				closest_distance = near[other]
		if(!closest)
			break
		near -= closest
		closest.answer_backup(here)
	return TRUE

/// Whether this brain is free, close enough and on the requester's side, so it comes when the call goes out
/datum/human_ai_brain/proc/can_answer_backup(datum/human_ai_brain/requester, turf/where)
	if(src == requester || stopped || QDELETED(body) || body.z != where.z || get_dist(body, where) > HAI_BACKUP_RANGE)
		return FALSE
	if(get_target() || current_order || is_civilian() || surrendered || broken_kind || intent == HAI_INTENT_ENGAGE)
		return FALSE
	// A squad looks after its own members through its plan and call-outs, and a team in the middle of a breach cannot be pulled away from it
	if(squad && (squad == requester.squad || squad.breach_state != HAI_BREACH_IDLE))
		return FALSE
	return get_disposition(requester.body) <= HAI_DISP_FRIEND

/// Heads for the place the call came from and looks about when it gets there
/datum/human_ai_brain/proc/answer_backup(turf/where)
	begin_investigation(where, 2)
	alert_until = world.time + 10 SECONDS
	backups_answered++
	express(HAI_EXPR_MOVING)
	log_decision("answering a call for backup at [where.x],[where.y]")
