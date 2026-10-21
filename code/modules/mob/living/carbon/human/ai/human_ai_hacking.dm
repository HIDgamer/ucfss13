/// Whether this brain breaks into doors it has no access to, only the CLF do
/datum/human_ai_brain/proc/can_hack_doors()
	return body.faction == FACTION_CLF

/// A tool with the trait from anywhere on the body, null when it carries none
/datum/human_ai_brain/proc/find_tool(tool_trait)
	RETURN_TYPE(/obj/item)
	for(var/obj/item/candidate in body.get_contents())
		if(!(candidate.flags_item & (NODROP|ITEM_ABSTRACT)) && HAS_TRAIT(candidate, tool_trait))
			return candidate
	return null

/// A screwdriver and wirecutters, which is what it takes to get into an airlock's wiring, as list(screwdriver, wirecutters) and null when either is missing
/datum/human_ai_brain/proc/find_hack_tools()
	var/obj/item/screwdriver = find_tool(TRAIT_TOOL_SCREWDRIVER)
	var/obj/item/cutters = find_tool(TRAIT_TOOL_WIRECUTTERS)
	if(!screwdriver || !cutters)
		return null
	return list(screwdriver, cutters)

/// Units that break into doors go in carrying what it takes, whatever they already have on them is kept
/datum/human_ai_brain/proc/issue_hack_tools()
	if(!can_hack_doors())
		return
	if(!find_tool(TRAIT_TOOL_SCREWDRIVER))
		pack_tool(new /obj/item/tool/screwdriver(get_turf(body)))
	if(!find_tool(TRAIT_TOOL_WIRECUTTERS))
		pack_tool(new /obj/item/tool/wirecutters(get_turf(body)))

/// Puts the tool away in the body's storage, it is dropped for good when there is no room
/datum/human_ai_brain/proc/pack_tool(obj/item/tool)
	if(!stow_item(tool))
		qdel(tool)

/// Starts breaking into the door, true while the hack is under way
/datum/human_ai_brain/proc/start_hack(obj/structure/machinery/door/door, turf/next_turf)
	var/obj/structure/machinery/door/airlock/airlock = door
	if(!istype(airlock))
		remember_blocked(next_turf, "no access to [door] and nothing to bypass it with", HAI_DOOR_DENIED_MEMORY)
		return FALSE
	if(suppressed() || get_target())
		// Nobody works on a lock while being shot at, so the door counts as shut for now
		remember_blocked(next_turf, "no time to hack [door]", HAI_DETOUR_MEMORY)
		return FALSE
	var/list/tools = find_hack_tools()
	if(!tools)
		remember_blocked(next_turf, "no screwdriver and wirecutters to get past [door]", HAI_DOOR_DENIED_MEMORY)
		return FALSE
	acting_until = world.time + HAI_HACK_TIME + 5 SECONDS
	INVOKE_ASYNC(src, PROC_REF(hack_door), airlock, tools[1], tools[2])
	return TRUE

/**
 * Gets into the door the way anyone with the tools would: unscrew the access panel, cut the wire of the ID scanner so the door stops asking
 * for a card, and screw the panel back on so the door answers to a push again. Every stage is picked up where it was left, so a hack that was
 * broken off starts over from the stage it reached. Anything that moves the body, hurts it or turns up an enemy stops the work and the door is
 * left alone for a while.
 */
/datum/human_ai_brain/proc/hack_door(obj/structure/machinery/door/airlock/door, obj/item/screwdriver, obj/item/cutters)
	var/turf/start = get_turf(body)
	var/stage_time = HAI_HACK_TIME / 3
	var/finished = TRUE
	if(!door.panel_open)
		finished = hack_stage(door, start, screwdriver, "starts unscrewing the access panel of [door]", 'sound/items/Screwdriver.ogg', stage_time)
		if(finished)
			door.attackby(screwdriver, body)
			finished = door.panel_open
	if(finished && !door.isWireCut(AIRLOCK_WIRE_IDSCAN))
		finished = hack_stage(door, start, cutters, "starts snipping wires in [door]", 'sound/items/Wirecutter.ogg', stage_time)
		if(finished)
			door.cut(AIRLOCK_WIRE_IDSCAN)
			door.add_fingerprint(body)
			finished = door.isWireCut(AIRLOCK_WIRE_IDSCAN)
	if(finished && door.panel_open)
		finished = hack_stage(door, start, screwdriver, "screws the access panel of [door] back on", 'sound/items/Screwdriver2.ogg', stage_time)
		if(finished)
			door.attackby(screwdriver, body)
			finished = !door.panel_open
	acting_until = 0
	if(QDELETED(body) || QDELETED(door))
		return
	if(!finished)
		remember_blocked(get_turf(door), "the hack on [door] was interrupted", HAI_DETOUR_MEMORY)
		return
	var/datum/effect_system/spark_spread/sparks = new
	sparks.set_up(3, 1, door)
	sparks.start()
	hacks++
	log_decision("hacked [door] with a screwdriver and wirecutters")
	next_step_time = world.time + 2

/// One stage of a hack: takes the tool in hand and works with it for a while, false when something broke the work off
/datum/human_ai_brain/proc/hack_stage(obj/structure/machinery/door/airlock/door, turf/start, obj/item/tool, text, tool_sound, duration)
	if(QDELETED(tool) || !hand_item(tool))
		return FALSE
	body.face_atom(door)
	body.visible_message(SPAN_WARNING("[body] [text]."), SPAN_NOTICE("You work at [door] with [tool]."))
	playsound(door, tool_sound, 25, TRUE)
	var/finish = world.time + duration
	while(world.time < finish)
		sleep(10)
		if(hack_interrupted(door, start))
			return FALSE
	return !hack_interrupted(door, start)

/datum/human_ai_brain/proc/hack_interrupted(obj/structure/machinery/door/door, turf/start)
	if(QDELETED(body) || QDELETED(door) || stopped || body.stat != CONSCIOUS || body.is_mob_incapacitated())
		return TRUE
	return get_turf(body) != start || !body.Adjacent(door) || suppressed() || get_target()
