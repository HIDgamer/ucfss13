/**
 * Insurgents who meet a door they cannot hack, a bolted one or a welded one or one with live current in it, do not give up on the way if they
 * carry a plastic charge: they plant it, back off and walk through what is left. Only the sides that hack doors do it, nobody blows up their
 * own side's doors for want of a key.
 */
/datum/human_ai_brain/proc/try_force_door(obj/structure/machinery/door/door, turf/next_turf)
	if(breach_phase)
		return TRUE
	if(!can_hack_doors() || suppressed() || get_target())
		return FALSE
	var/obj/item/explosive/plastic/charge = find_charge()
	if(!charge || door.unacidable)
		return FALSE
	breach_door_ref = WEAKREF(door)
	breach_door_turf = get_turf(door)
	breach_charge_ref = WEAKREF(charge)
	breach_phase = HAI_FORCE_PLANT
	breach_started = world.time
	log_decision("forcing [door] with [charge]")
	return TRUE

/// A unit that carries a charge into a fight is taken to know how to set it, whatever its trade, which is the same as a role getting the skills its kit asks for
/datum/human_ai_brain/proc/ensure_charge_skill(obj/item/explosive/plastic/charge)
	if(!body.skills)
		body.skills = new /datum/skills()
	if(body.skills.get_skill_level(charge.req_skill) < charge.req_skill_level)
		body.skills.set_skill(charge.req_skill, charge.req_skill_level)

/// The forced entry is over, however it ended, and the door it was about is not remembered as shut if it is gone
/datum/human_ai_brain/proc/end_force(reason)
	var/obj/structure/machinery/door/door = breach_door_ref?.resolve()
	if(QDELETED(door))
		forced_doors++
		if(breach_door_turf)
			blocked_turfs -= breach_door_turf
	else if(breach_door_turf)
		remember_blocked(breach_door_turf, "[door] would not give: [reason]", HAI_DOOR_DENIED_MEMORY)
	log_decision("forcing the door is over: [reason]")
	breach_phase = HAI_FORCE_NONE
	breach_door_ref = null
	breach_charge_ref = null
	breach_door_turf = null
	path = null
	next_path_request = 0

/datum/human_ai_brain/proc/force_step()
	var/obj/structure/machinery/door/door = breach_door_ref?.resolve()
	var/obj/item/explosive/plastic/charge = breach_charge_ref?.resolve()
	if(world.time > breach_started + 45 SECONDS)
		end_force("it took too long")
		return FALSE
	if(breach_phase == HAI_FORCE_PLANT && (get_target() || suppressed()))
		end_force("under fire")
		return FALSE
	if(QDELETED(door))
		end_force("the door is gone")
		return FALSE
	switch(breach_phase)
		if(HAI_FORCE_PLANT)
			if(is_acting())
				return TRUE
			if(get_dist(body, door) > 1)
				return move_to(door, 1, FALSE)
			if(QDELETED(charge) || !hand_item(charge))
				end_force("no charge to plant")
				return FALSE
			body.face_atom(door)
			ensure_charge_skill(charge)
			acting_until = world.time + charge.deploying_time + 2 SECONDS
			INVOKE_ASYNC(charge, TYPE_PROC_REF(/obj/item/explosive/plastic, afterattack), door, body, TRUE)
			charges_planted++
			breach_phase = HAI_FORCE_RETREAT
			return TRUE
		if(HAI_FORCE_RETREAT)
			if(is_acting())
				return TRUE
			if(QDELETED(charge) || !charge.active)
				end_force("the charge was not planted")
				return FALSE
			var/turf/away = retreat_turf(get_turf(door), 8)
			if(away && get_dist(body, door) < 6 && move_to(away, 0, TRUE))
				return TRUE
			breach_phase = HAI_FORCE_WAIT
			breach_wait_until = world.time + charge.timer * 10 + 6 SECONDS
			return TRUE
		if(HAI_FORCE_WAIT)
			if(QDELETED(charge) || !charge.active || world.time > breach_wait_until)
				end_force("the charge went off")
				return FALSE
			return TRUE
	return FALSE

/datum/human_ai_action/force_door
	id = "force_door"
	conflicts = HAI_LIMB_HANDS|HAI_LIMB_LEGS
	intents = list(HAI_INTENT_IDLE, HAI_INTENT_ALERT, HAI_INTENT_ENGAGE, HAI_INTENT_ADVANCE, HAI_INTENT_ORDERED, HAI_INTENT_HOLD)

/datum/human_ai_action/force_door/get_weight(datum/human_ai_brain/brain)
	if(!brain.breach_phase)
		return 0
	// A hard order drives the legs at 105, and it is the very thing that order is waiting on
	return brain.current_order?.hard ? 108 : 96

/datum/human_ai_action/force_door/trigger(datum/human_ai_brain/brain)
	return brain.force_step()
