/// What a walker should do about this atom when it blocks a step, anything not classified is a wall
/atom/proc/human_ai_obstacle(mob/living/carbon/human/walker)
	return density ? HAI_OBS_BLOCKED : HAI_OBS_NONE

/obj/structure/human_ai_obstacle(mob/living/carbon/human/walker)
	if(!density)
		return HAI_OBS_NONE
	return climbable ? HAI_OBS_CLIMB : HAI_OBS_BLOCKED

/obj/structure/machinery/door/human_ai_obstacle(mob/living/carbon/human/walker)
	return density ? HAI_OBS_DOOR : HAI_OBS_NONE

/// A retractable railing can be climbed, no other blast door or shutter has a way through by hand
/obj/structure/machinery/door/poddoor/human_ai_obstacle(mob/living/carbon/human/walker)
	if(!density)
		return HAI_OBS_NONE
	return climbable ? HAI_OBS_CLIMB : HAI_OBS_DOOR

/mob/living/human_ai_obstacle(mob/living/carbon/human/walker)
	return density ? HAI_OBS_MOB : HAI_OBS_NONE

/// First thing that stops the body stepping from here to next_turf, as list(kind, atom), null when nothing does
/datum/human_ai_brain/proc/find_obstacle(turf/here, turf/next_turf)
	if(next_turf.density)
		return list(HAI_OBS_BLOCKED, next_turf)
	var/direction = get_dir(here, next_turf)
	var/list/found
	for(var/atom/movable/blocker as anything in next_turf)
		if(blocker == body || !blocker.density || !blocker.BlockedPassDirs(body, direction))
			continue
		var/kind = blocker.human_ai_obstacle(body)
		if(kind == HAI_OBS_NONE)
			continue
		if(!found || kind == HAI_OBS_DOOR || (kind == HAI_OBS_CLIMB && found[1] == HAI_OBS_BLOCKED))
			found = list(kind, blocker)
	for(var/obj/structure/edge in here)
		if(!(edge.flags_atom & ON_BORDER) || !edge.density || !edge.BlockedExitDirs(body, direction))
			continue
		var/kind = edge.human_ai_obstacle(body)
		if(kind != HAI_OBS_NONE && (!found || kind == HAI_OBS_DOOR))
			found = list(kind, edge)
	return found

/datum/human_ai_brain/proc/remember_blocked(turf/blocked, reason, memory = HAI_BLOCK_MEMORY)
	blocked_turfs[blocked] = world.time + memory
	path = null
	next_path_request = 0
	log_decision("blocked at [blocked.x],[blocked.y]: [reason]")
	if(SSxeno_pathfinding?.available && xeno_pathfind_profiles_available())
		rust_xeno_pathfind_danger("[blocked.z],[blocked.x],[blocked.y],[HAI_BLOCK_DANGER],0")

/**
 * Asks for a new route that keeps clear of the turf, without ruling the turf out: if nothing else leads on, the brain can still go over it.
 * remember_blocked() would stop the brain trying the step at all, and with no other way it would give the goal up before it ever climbed.
 */
/datum/human_ai_brain/proc/prefer_other_way(turf/avoided, reason)
	path = null
	next_path_request = 0
	log_decision("[reason] at [avoided.x],[avoided.y]")
	if(SSxeno_pathfinding?.available && xeno_pathfind_profiles_available())
		rust_xeno_pathfind_danger("[avoided.z],[avoided.x],[avoided.y],[HAI_BLOCK_DANGER],0")

/datum/human_ai_brain/proc/is_blocked_turf(turf/checked)
	var/until = blocked_turfs[checked]
	if(!until)
		return FALSE
	if(until < world.time)
		blocked_turfs -= checked
		return FALSE
	return TRUE

/// Does something about the obstacle, returns TRUE when the body is dealing with it and should keep waiting
/datum/human_ai_brain/proc/handle_obstacle(list/obstacle, turf/next_turf)
	var/atom/blocker = obstacle[2]
	switch(obstacle[1])
		if(HAI_OBS_DOOR)
			return handle_door(blocker, next_turf)
		if(HAI_OBS_CLIMB)
			return handle_climb(blocker, next_turf)
		if(HAI_OBS_MOB)
			next_step_time = world.time + 3
			return sidestep(get_dir(body, next_turf))
	remember_blocked(next_turf, "[blocker] in the way")
	return FALSE

/datum/human_ai_brain/proc/handle_door(obj/structure/machinery/door/door, turf/next_turf)
	if(!door.density)
		return TRUE
	if(door.operating)
		next_step_time = world.time + 4
		return TRUE
	if(istype(door, /obj/structure/machinery/door/poddoor))
		return handle_poddoor(door, next_turf)
	var/obj/structure/machinery/door/airlock/airlock = door
	if(istype(airlock))
		if(airlock.locked || airlock.welded || airlock.isElectrified())
			// Insurgents with a charge blow what they cannot open
			if(try_force_door(door, next_turf))
				return TRUE
			remember_blocked(next_turf, "[door] is shut for good", HAI_DOOR_DENIED_MEMORY)
			return FALSE
		if(!airlock.arePowerSystemsOn())
			return start_pry(door, next_turf)
	if(!door.allowed(body))
		if(can_hack_doors())
			return start_hack(door, next_turf)
		remember_blocked(next_turf, "no access to [door]", HAI_DOOR_DENIED_MEMORY)
		return FALSE
	door.open()
	next_step_time = world.time + door.openspeed + 2
	return TRUE

/**
 * Blast doors and shutters have no handle and do not answer to a push, nobody opens them by hand. They are worked from a button, or forced
 * with a crowbar once their power is out. A brain without a crowbar leaves a powered one alone for a good while.
 */
/datum/human_ai_brain/proc/handle_poddoor(obj/structure/machinery/door/poddoor/shutter, turf/next_turf)
	if(!(shutter.stat & NOPOWER) || shutter.unacidable)
		remember_blocked(next_turf, "[shutter] is powered and shut, it has no handle", HAI_DOOR_DENIED_MEMORY)
		return FALSE
	return start_pry(shutter, next_turf)

/// Something to force a door with that the body carries anywhere, a proper crowbar by preference
/datum/human_ai_brain/proc/find_crowbar()
	var/obj/item/forcer
	for(var/obj/item/candidate in body.get_contents())
		if(candidate.flags_item & (NODROP|ITEM_ABSTRACT))
			continue
		if(HAS_TRAIT(candidate, TRAIT_TOOL_CROWBAR))
			return candidate
		if(!forcer && candidate.can_pry())
			forcer = candidate
	return forcer

/datum/human_ai_brain/proc/start_pry(obj/structure/machinery/door/door, turf/next_turf)
	var/obj/item/crowbar = find_crowbar()
	if(!crowbar)
		remember_blocked(next_turf, "[door] has no power and there is no crowbar", HAI_DOOR_DENIED_MEMORY)
		return FALSE
	acting_until = world.time + 15 SECONDS
	INVOKE_ASYNC(src, PROC_REF(pry_door), door, crowbar)
	return TRUE

/// Takes the crowbar in hand and heaves at the door with it, the door gives only if it really is dead
/datum/human_ai_brain/proc/pry_door(obj/structure/machinery/door/door, obj/item/crowbar)
	if(QDELETED(body) || QDELETED(door) || QDELETED(crowbar) || !hand_item(crowbar))
		acting_until = 0
		return
	body.face_atom(door)
	body.visible_message(SPAN_WARNING("[body] wedges [crowbar] into [door] and heaves!"), SPAN_NOTICE("You wedge [crowbar] into [door]."))
	playsound(door, 'sound/items/Crowbar.ogg', 25, TRUE)
	sleep(1.5 SECONDS)
	if(!QDELETED(body) && !QDELETED(door) && !QDELETED(crowbar) && !stopped && body.stat == CONSCIOUS && body.Adjacent(door) && crowbar.loc == body)
		door.attackby(crowbar, body)
		pries++
		log_decision("forced [door] with [crowbar]")
	acting_until = 0

/// Whether getting over something climbable is worth the time right now: the brain has an enemy in sight, is under fire, running or clear of a hazard. A hard order alone is not a hurry
/datum/human_ai_brain/proc/climb_urgent()
	if(get_target() && world.time <= target_seen_time + 40)
		return TRUE
	return suppressed() || broken_kind || hazard_turf || world.time < panic_until

/**
 * Climbing is the last resort. A brain with nothing pressing never climbs, it takes another way or gives the goal up. One that has a goal to
 * reach looks for a way round a couple of times first, and even when it does climb it will not hop one table after another.
 */
/datum/human_ai_brain/proc/handle_climb(obj/structure/structure, turf/next_turf)
	var/urgent = climb_urgent()
	if(!urgent && !current_order && !follow_ref && !(intent in list(HAI_INTENT_ENGAGE, HAI_INTENT_ADVANCE, HAI_INTENT_FALLBACK)))
		remember_blocked(next_turf, "no reason to climb [structure]", HAI_DETOUR_MEMORY)
		return FALSE
	if(world.time < next_vault_time)
		next_step_time = world.time + 5
		return TRUE
	if(!urgent && climb_detours < HAI_CLIMB_DETOURS)
		climb_detours++
		prefer_other_way(next_turf, "would rather go round [structure]")
		return FALSE
	next_vault_time = world.time + HAI_VAULT_COOLDOWN
	vaults++
	return start_vault(structure)

/datum/human_ai_brain/proc/start_vault(obj/structure/structure)
	if(!structure.can_climb(body))
		remember_blocked(get_turf(structure), "cannot climb [structure]")
		return FALSE
	acting_until = world.time + 10 SECONDS
	INVOKE_ASYNC(src, PROC_REF(vault), structure)
	return TRUE

/datum/human_ai_brain/proc/vault(obj/structure/structure)
	if(!QDELETED(structure) && body)
		structure.do_climb(body)
	acting_until = 0
	if(body)
		next_step_time = world.time + body.movement_delay()
