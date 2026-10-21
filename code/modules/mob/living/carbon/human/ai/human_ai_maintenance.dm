/**
 * The rounds of a unit whose trade is keeping the place running: a dead light gets a new bulb, mess and litter are cleaned up, a damaged wall is
 * welded, a broken tile is pulled up and replaced and an APC with its cover hanging open or its cell missing or its board burnt out is put right.
 * Everything is done with the real tools on the real thing being mended, so it takes as long as it would for a person and needs the same kit.
 */

/// The lightbulb replacer the body carries, null when it has none
/datum/human_ai_brain/proc/find_lightreplacer()
	RETURN_TYPE(/obj/item/device/lightreplacer)
	for(var/obj/item/device/lightreplacer/replacer in body.get_contents())
		return replacer
	return null

/// A welder with fuel left in it, from anywhere on the body
/datum/human_ai_brain/proc/find_welder()
	RETURN_TYPE(/obj/item/tool/weldingtool)
	for(var/obj/item/tool/weldingtool/welder in body.get_contents())
		if(welder.get_fuel() >= 5)
			return welder
	return null

/// The first item of the type that is carried or in a bag, and not part of some other thing like the cell inside a defibrillator
/datum/human_ai_brain/proc/find_item_of(item_type)
	RETURN_TYPE(/obj/item)
	for(var/obj/item/candidate in body.get_contents())
		if(!istype(candidate, item_type) || QDELETED(candidate) || (candidate.flags_item & (NODROP|ITEM_ABSTRACT)))
			continue
		if(candidate.loc == body || istype(candidate.loc, /obj/item/storage))
			return candidate
	return null

/// A fixture holds its bulb's state as a number, 0 is a working bulb and anything else is an empty socket or a bulb that is broken or burnt out
/datum/human_ai_brain/proc/light_dead(obj/structure/machinery/light/light)
	return light.status != 0

/// Whether an APC wants hands on it: broken, its cover open, its cell gone or one of its wires cut
/datum/human_ai_brain/proc/apc_needs_work(obj/structure/machinery/power/apc/apc)
	if((apc.stat & BROKEN) || apc.opened || !apc.cell)
		return TRUE
	for(var/wire in 1 to length(apc.get_wire_descriptions()))
		if(apc.isWireCut(wire))
			return TRUE
	return FALSE

/// Whether the body carries what the work on the APC takes
/datum/human_ai_brain/proc/apc_supplies_ready(obj/structure/machinery/power/apc/apc)
	if(!find_tool(TRAIT_TOOL_CROWBAR) || !find_tool(TRAIT_TOOL_SCREWDRIVER))
		return FALSE
	if(apc.stat & BROKEN)
		// The wiring is redone with the hands bare of any danger or not at all
		if(!find_tool(TRAIT_TOOL_WIRECUTTERS) || !find_item_of(/obj/item/frame/apc) || !find_item_of(/obj/item/circuitboard/apc) || !find_item_of(/obj/item/stack/cable_coil) || !apc_wiring_safe())
			return FALSE
	if(!apc.cell && !find_item_of(/obj/item/cell))
		return FALSE
	for(var/wire in 1 to length(apc.get_wire_descriptions()))
		if(apc.isWireCut(wire) && !find_tool(TRAIT_TOOL_WIRECUTTERS))
			return FALSE
	return TRUE

/// Wiring and cutting live cable shocks whoever does it, unless the body is insulated against it
/datum/human_ai_brain/proc/apc_wiring_safe()
	if(body.species?.insulated)
		return TRUE
	var/obj/item/clothing/gloves/worn = body.gloves
	return worn && worn.siemens_coefficient == 0

/// The work the thing is, null when it is none of what a maintenance unit does
/datum/human_ai_brain/proc/maintenance_kind_of(atom/thing)
	if(istype(thing, /obj/structure/machinery/power/apc))
		return HAI_MAINT_APC
	if(istype(thing, /obj/structure/machinery/light))
		return HAI_MAINT_LIGHT
	if(istype(thing, /turf/closed/wall))
		return HAI_MAINT_WALL
	if(istype(thing, /turf/open/floor))
		return HAI_MAINT_FLOOR
	if(istype(thing, /obj/effect/decal/cleanable) || istype(thing, /obj/item/trash) || istype(thing, /obj/item/light_bulb))
		return HAI_MAINT_CLEAN
	return null

/// Whether the thing still wants the work and the unit has what the work takes
/datum/human_ai_brain/proc/maintenance_needed(atom/thing, kind)
	if(QDELETED(thing))
		return FALSE
	switch(kind)
		if(HAI_MAINT_LIGHT)
			var/obj/structure/machinery/light/light = thing
			if(!light_dead(light))
				return FALSE
			var/obj/item/device/lightreplacer/replacer = find_lightreplacer()
			return replacer && (replacer.uses > 0 || find_item_of(/obj/item/stack/sheet/glass))
		if(HAI_MAINT_CLEAN)
			if(isitem(thing))
				var/obj/item/litter = thing
				return isturf(litter.loc) && !litter.anchored
			return TRUE
		if(HAI_MAINT_WALL)
			var/turf/closed/wall/wall = thing
			if(wall.damage < HAI_WALL_REPAIR_MIN || (wall.turf_flags & TURF_HULL))
				return FALSE
			return find_welder() ? TRUE : FALSE
		if(HAI_MAINT_FLOOR)
			var/turf/open/floor/floor = thing
			if(!(floor.turf_flags & (TURF_BROKEN|TURF_BURNT)) || (floor.turf_flags & TURF_HULL))
				return FALSE
			if(floor.is_plating())
				return find_welder() ? TRUE : FALSE
			return (floor.tool_flags & REMOVE_CROWBAR) && find_tool(TRAIT_TOOL_CROWBAR) && find_item_of(/obj/item/stack/tile)
		if(HAI_MAINT_APC)
			var/obj/structure/machinery/power/apc/apc = thing
			return apc_needs_work(apc) && apc_supplies_ready(apc)
	return FALSE

/// How much sooner a kind of work is taken up than the one next to it, the lower the better
/datum/human_ai_brain/proc/maintenance_priority(kind)
	switch(kind)
		if(HAI_MAINT_APC)
			return -4
		if(HAI_MAINT_LIGHT)
			return 0
		if(HAI_MAINT_WALL)
			return 1
		if(HAI_MAINT_FLOOR)
			return 2
	return 3

/// The work closest to the unit and most pressing, null when there is none. Looked for now and then and the answer kept in between.
/datum/human_ai_brain/proc/find_maintenance()
	var/atom/kept = maint_ref?.resolve()
	if(kept && maint_kind && maintenance_needed(kept, maint_kind) && get_dist(body, kept) <= HAI_MAINT_RANGE + 2 && !(maint_skips[REF(kept)] > world.time))
		return kept
	maint_ref = null
	maint_kind = null
	if(world.time < next_maint_scan)
		return null
	next_maint_scan = world.time + HAI_MAINT_SCAN_GAP
	if(length(maint_skips) > 40)
		for(var/key in maint_skips)
			if(maint_skips[key] < world.time)
				maint_skips -= key
	var/atom/best
	var/best_kind
	var/best_rank = INFINITY
	for(var/atom/candidate in view(HAI_MAINT_RANGE, body))
		var/kind = maintenance_kind_of(candidate)
		if(!kind)
			continue
		var/rank = get_dist(body, candidate) + maintenance_priority(kind)
		if(rank >= best_rank || maint_skips[REF(candidate)] > world.time || !maintenance_needed(candidate, kind))
			continue
		best = candidate
		best_kind = kind
		best_rank = rank
	if(!best)
		return null
	maint_ref = WEAKREF(best)
	maint_kind = best_kind
	return best

/// A spot to work from: the tile the thing is on if it can be stood on or one beside it, whichever is closest to the unit
/datum/human_ai_brain/proc/standing_spot(atom/work)
	RETURN_TYPE(/turf)
	var/turf/work_turf = get_turf(work)
	if(!work_turf)
		return null
	var/turf/best
	var/best_distance = INFINITY
	var/list/turf/spots = list(work_turf)
	for(var/turf/neighbour in orange(1, work_turf))
		spots += neighbour
	for(var/turf/candidate as anything in spots)
		if(!cover_turf_usable(candidate) || is_blocked_turf(candidate))
			continue
		var/distance = get_dist(body, candidate)
		if(distance < best_distance)
			best = candidate
			best_distance = distance
	return best

/// Leaves the work alone for a good while, it is either beyond this unit or cannot be reached
/datum/human_ai_brain/proc/skip_maintenance(atom/work, reason)
	if(work)
		maint_skips[REF(work)] = world.time + HAI_MAINT_SKIP
	maint_ref = null
	maint_kind = null
	log_decision("leaving [work] alone: [reason]")

/// Holds the body to the job for a while longer, so a job whose steps stop part way does not hold it for ever
/datum/human_ai_brain/proc/maint_busy()
	acting_until = world.time + 20 SECONDS

/// Walks to the work and sets about it, true while the unit is busy with it
/datum/human_ai_brain/proc/do_maintenance()
	var/atom/work = find_maintenance()
	if(!work)
		return FALSE
	if(is_acting())
		return TRUE
	var/turf/spot = standing_spot(work)
	if(!spot)
		skip_maintenance(work, "nowhere to stand")
		return FALSE
	if(get_turf(body) != spot)
		if(move_to(spot, 0, FALSE))
			return TRUE
		skip_maintenance(work, "cannot get to it")
		return FALSE
	var/kind = maint_kind
	maint_busy()
	body.face_atom(work)
	if(prob(HAI_MAINT_QUIP_CHANCE))
		express(HAI_EXPR_TASK)
	INVOKE_ASYNC(src, PROC_REF(run_maintenance), work, kind)
	return TRUE

/// The work itself, on the side because the tools wait on their own timers
/datum/human_ai_brain/proc/run_maintenance(atom/work, kind)
	var/done = FALSE
	switch(kind)
		if(HAI_MAINT_LIGHT)
			done = mend_light(work)
		if(HAI_MAINT_CLEAN)
			done = scrub(work)
		if(HAI_MAINT_WALL)
			done = mend_wall(work)
		if(HAI_MAINT_FLOOR)
			done = mend_floor(work)
		if(HAI_MAINT_APC)
			done = mend_apc(work)
	if(QDELETED(src) || QDELETED(body))
		return
	acting_until = 0
	put_tools_away()
	if(done)
		maint_done++
		maint_ref = null
		maint_kind = null
		log_decision("mended [kind]: [work]")
	else
		skip_maintenance(work, "could not finish the [kind]")

/// Whatever is in the hands goes back in the bags, a lit welder is put out first
/datum/human_ai_brain/proc/put_tools_away()
	for(var/obj/item/held in list(body.get_active_hand(), body.get_inactive_hand()))
		if(QDELETED(held) || (held.flags_item & (NODROP|ITEM_ABSTRACT)) || istype(held, /obj/item/weapon/gun))
			continue
		power_down_welder(held)
		power_down_defibrillator(held)
		stow_item(held)
	utility_ref = null

/// Whether the job has to stop: the unit is hurt, shot at, has an enemy in sight, or is not beside the work any more
/datum/human_ai_brain/proc/maint_interrupted(atom/work)
	if(QDELETED(src) || QDELETED(body) || QDELETED(work) || stopped || body.stat != CONSCIOUS || body.is_mob_incapacitated())
		return TRUE
	return suppressed() || get_target() || get_dist(body, work) > 2

/// Takes the tool in hand and says so, false when the hands could not be cleared
/datum/human_ai_brain/proc/take_tool(obj/item/tool)
	if(!tool || QDELETED(tool) || !hand_item(tool))
		return FALSE
	utility_ref = WEAKREF(tool)
	maint_busy()
	return TRUE

/datum/human_ai_brain/proc/mend_light(obj/structure/machinery/light/light)
	var/obj/item/device/lightreplacer/replacer = find_lightreplacer()
	if(!take_tool(replacer))
		return FALSE
	// Glass in the replacer makes more bulbs when it has run low
	if(replacer.uses <= 1)
		var/obj/item/stack/sheet/glass/glass = find_item_of(/obj/item/stack/sheet/glass)
		if(glass)
			replacer.attackby(glass, body)
	body.visible_message(SPAN_NOTICE("[body] reaches up with [replacer] to swap the bulb in [light]."), SPAN_NOTICE("You start swapping the bulb in [light]."))
	sleep(2 SECONDS)
	if(maint_interrupted(light) || !light_dead(light))
		return FALSE
	replacer.ReplaceLight(light, body)
	return !light_dead(light)

/datum/human_ai_brain/proc/scrub(atom/mess)
	var/obj/item/tool/mop/mop = find_item_of(/obj/item/tool/mop)
	var/mopped = take_tool(mop)
	body.visible_message(SPAN_NOTICE("[body] [mopped ? "mops" : "wipes"] up [mess]."), SPAN_NOTICE("You clean up [mess]."))
	playsound(body, 'sound/effects/slosh.ogg', 20, TRUE)
	sleep(2.5 SECONDS)
	if(maint_interrupted(mess))
		return FALSE
	qdel(mess)
	return TRUE

/datum/human_ai_brain/proc/mend_wall(turf/closed/wall/wall)
	var/obj/item/tool/weldingtool/welder = find_welder()
	if(!take_tool(welder))
		return FALSE
	if(!welder.welding)
		welder.toggle()
	if(!welder.welding)
		return FALSE
	if(body.a_intent != INTENT_HELP)
		body.a_intent_change(INTENT_HELP)
	body.face_atom(wall)
	var/before = wall.damage
	wall.try_weldingtool_usage(welder, body)
	return wall.damage < before

/// Breaks the broken tile up, lays a new one on the plating and, when it is only plating that is damaged, welds the dents out of it
/datum/human_ai_brain/proc/mend_floor(turf/open/floor/floor)
	var/x_spot = floor.x
	var/y_spot = floor.y
	var/z_spot = floor.z
	body.face_atom(floor)
	if(floor.is_plating())
		var/obj/item/tool/weldingtool/welder = find_welder()
		if(!take_tool(welder))
			return FALSE
		if(!welder.welding)
			welder.toggle()
		if(!welder.welding)
			return FALSE
		sleep(1.5 SECONDS)
		if(maint_interrupted(floor))
			return FALSE
		floor.attackby(welder, body)
		var/turf/open/floor/welded = locate(x_spot, y_spot, z_spot)
		return istype(welded) && !(welded.turf_flags & (TURF_BROKEN|TURF_BURNT))
	var/obj/item/crowbar = find_tool(TRAIT_TOOL_CROWBAR)
	if(!take_tool(crowbar))
		return FALSE
	body.visible_message(SPAN_NOTICE("[body] pries up the broken tile."), SPAN_NOTICE("You pry up the broken tile."))
	sleep(1.5 SECONDS)
	if(maint_interrupted(floor))
		return FALSE
	floor.attackby(crowbar, body)
	var/turf/open/floor/plating = locate(x_spot, y_spot, z_spot)
	return istype(plating) && lay_tile(plating)

/// Lays a floor tile from the stack carried onto the plating
/datum/human_ai_brain/proc/lay_tile(turf/open/floor/plating)
	var/obj/item/stack/tile/tiles = find_item_of(/obj/item/stack/tile)
	if(!plating.is_plating() || (plating.turf_flags & (TURF_BROKEN|TURF_BURNT)) || !take_tool(tiles))
		return FALSE
	sleep(1 SECONDS)
	var/x_spot = plating.x
	var/y_spot = plating.y
	var/z_spot = plating.z
	if(maint_interrupted(plating))
		return FALSE
	plating.attackby(tiles, body)
	var/turf/open/floor/laid = locate(x_spot, y_spot, z_spot)
	return istype(laid) && !laid.is_plating()

/**
 * Puts an APC right the way a technician would, one real tool use after another, deciding each from how the APC stands: a broken one has its cover
 * knocked off, its cell, board and wiring taken out and its frame replaced, then comes the board again, the wiring, the cell and the cover shut.
 * Wires that were cut are mended with the panel open. A step that changes nothing ends the job.
 */
/datum/human_ai_brain/proc/mend_apc(obj/structure/machinery/power/apc/apc)
	// Some of what the APC checks reads the one acting and not the one it was handed, so the body is made that
	var/mob/previous = usr
	usr = body
	var/done = apc_work(apc)
	usr = previous
	return done

/datum/human_ai_brain/proc/apc_signature(obj/structure/machinery/power/apc/apc)
	var/turf/under = get_turf(apc)
	return "[apc.stat]/[apc.opened]/[apc.has_electronics]/[apc.cell ? 1 : 0]/[apc.terminal ? 1 : 0]/[apc.apcwires]/[apc.wiresexposed ? 1 : 0]/[apc.coverlocked]/[under?.type]"

/datum/human_ai_brain/proc/apc_work(obj/structure/machinery/power/apc/apc)
	var/pried_tile = FALSE
	for(var/step in 1 to HAI_APC_STEP_LIMIT)
		if(maint_interrupted(apc))
			return FALSE
		if(!apc_needs_work(apc))
			break
		var/before = apc_signature(apc)
		maint_busy()
		var/turf/before_spot = get_turf(apc)
		var/was_intact = before_spot.intact_tile
		apc_step(apc)
		var/turf/after_spot = get_turf(apc)
		if(was_intact && istype(after_spot, /turf/open/floor) && !after_spot.intact_tile)
			pried_tile = TRUE
		if(apc_signature(apc) == before)
			break
	// The tile that came up to get at the cable goes back down
	if(pried_tile)
		var/turf/open/floor/plating = get_turf(apc)
		if(istype(plating) && plating.is_plating())
			lay_tile(plating)
	return !apc_needs_work(apc)

/// Uses the item on the APC, true when there was an item to use
/datum/human_ai_brain/proc/apc_use(obj/item/tool, obj/structure/machinery/power/apc/apc)
	if(!take_tool(tool))
		return FALSE
	body.face_atom(apc)
	apc.attackby(tool, body)
	return TRUE

/// Takes the cell out of an APC with the cover open, which ends up in the hands
/datum/human_ai_brain/proc/apc_take_cell(obj/structure/machinery/power/apc/apc)
	if(!apc.opened || !apc.cell)
		return FALSE
	var/obj/item/cell/removed = apc.cell
	maint_busy()
	body.face_atom(apc)
	if(body.a_intent != INTENT_HELP)
		body.a_intent_change(INTENT_HELP)
	apc.attack_hand(body)
	if(apc.cell || QDELETED(removed))
		return FALSE
	// Back into the pack, it goes in again later
	stow_item(removed)
	return TRUE

/// The tile under an APC has to come up before its wiring can be touched, true when there was a tile to take up
/datum/human_ai_brain/proc/apc_expose_wiring(obj/structure/machinery/power/apc/apc, obj/item/crowbar)
	var/turf/open/floor/spot = get_turf(apc)
	if(!istype(spot) || !spot.intact_tile)
		return FALSE
	if(!(spot.tool_flags & REMOVE_CROWBAR) || (spot.turf_flags & TURF_HULL))
		return FALSE
	if(!take_tool(crowbar))
		return FALSE
	spot.attackby(crowbar, body)
	return TRUE

/// One move on the APC, whichever the state it is in calls for
/datum/human_ai_brain/proc/apc_step(obj/structure/machinery/power/apc/apc)
	var/obj/item/crowbar = find_tool(TRAIT_TOOL_CROWBAR)
	var/obj/item/screwdriver = find_tool(TRAIT_TOOL_SCREWDRIVER)
	var/obj/item/cutters = find_tool(TRAIT_TOOL_WIRECUTTERS)
	var/turf/spot = get_turf(apc)
	if(apc.stat & BROKEN)
		if(!apc.opened)
			// A broken one has its cover knocked off with anything solid
			return apc_use(crowbar, apc)
		if(apc.cell)
			return apc_take_cell(apc)
		if(apc.has_electronics == 2)
			return apc_use(screwdriver, apc)
		if(apc.has_electronics == 1)
			if(apc.terminal)
				if(spot.intact_tile)
					return apc_expose_wiring(apc, crowbar)
				return apc_use(cutters, apc)
			return apc_use(crowbar, apc)
		return apc_use(find_item_of(/obj/item/frame/apc), apc)
	if(apc.opened)
		if(apc.has_electronics == 0)
			return apc_use(find_item_of(/obj/item/circuitboard/apc), apc)
		if(!apc.terminal && apc.has_electronics != 2)
			if(spot.intact_tile)
				return apc_expose_wiring(apc, crowbar)
			return apc_use(find_item_of(/obj/item/stack/cable_coil), apc)
		if(apc.has_electronics == 1)
			if(apc.cell)
				return apc_take_cell(apc)
			return apc_use(screwdriver, apc)
		if(!apc.cell)
			return apc_use(find_item_of(/obj/item/cell), apc)
		// Everything is in and secured, so the cover is shut
		return apc_use(crowbar, apc)
	// Closed, so what is wrong is a missing cell or a cut wire
	for(var/wire in 1 to length(apc.get_wire_descriptions()))
		if(apc.isWireCut(wire))
			return apc_mend_wires(apc, screwdriver, cutters)
	if(!apc.cell)
		// The cover is locked until the one with access unlocks it from the panel, which this unit has the access for
		if(apc.coverlocked && apc.allowed(body))
			apc.coverlocked = FALSE
		return apc_use(crowbar, apc)
	return FALSE

/// Opens the panel with a screwdriver, mends every cut wire with the cutters and closes it again
/datum/human_ai_brain/proc/apc_mend_wires(obj/structure/machinery/power/apc/apc, obj/item/screwdriver, obj/item/cutters)
	if(!cutters)
		return FALSE
	if(!apc.wiresexposed && !apc_use(screwdriver, apc))
		return FALSE
	if(!take_tool(cutters))
		return FALSE
	for(var/wire in 1 to length(apc.get_wire_descriptions()))
		if(apc.isWireCut(wire))
			body.visible_message(SPAN_NOTICE("[body] splices the cut wire in [apc]."), SPAN_NOTICE("You splice the cut wire in [apc]."))
			playsound(apc, 'sound/items/Wirecutter.ogg', 25, TRUE)
			sleep(1.5 SECONDS)
			if(maint_interrupted(apc))
				return FALSE
			apc.mend(wire)
	if(apc.wiresexposed)
		apc_use(screwdriver, apc)
	return TRUE

/// Goes round looking for work in the places it is, when nothing else is on
/datum/human_ai_action/maintain
	id = "maintain"
	conflicts = HAI_LIMB_HANDS|HAI_LIMB_LEGS
	intents = list(HAI_INTENT_IDLE, HAI_INTENT_ALERT)

/datum/human_ai_action/maintain/get_weight(datum/human_ai_brain/brain)
	if(!brain.role?.maintains || brain.get_target() || brain.current_order || brain.surrendered || brain.broken_kind || brain.suppressed() || brain.reload_phase != HAI_RELOAD_NONE)
		return 0
	if(brain.is_acting())
		return 40
	return brain.find_maintenance() ? 40 : 0

/datum/human_ai_action/maintain/trigger(datum/human_ai_brain/brain)
	return brain.do_maintenance()
