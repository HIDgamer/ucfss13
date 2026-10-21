/// Stack up beside a door, open it, flash the room, wait out the flash and go in
/datum/npc_order/breach
	id = "breach"
	name = "Breach and clear"
	danger = 0.6

/datum/npc_order/breach/can_perform(datum/human_ai_brain/performer)
	if(!target_turf)
		return "no door"
	return performer.role?.supports_order(id) ? null : "no breaching kit"

/datum/human_ai_squad/proc/breach_note(text)
	breach_log += "[world.time]: [text]"
	leader?.log_decision("breach: [text]")

/// A sorted list of usable tiles outside the door where the stack waits, the door's own side first
/datum/human_ai_squad/proc/stack_spots(turf/door_turf, approach)
	var/turf/front = get_step(door_turf, approach)
	var/lateral = turn(approach, 90)
	var/turf/base = get_step(get_step(front, approach), approach)
	var/list/wanted = list(
		get_step(base, lateral),
		base,
		get_step(base, turn(approach, -90)),
		get_step(get_step(base, approach), lateral),
		get_step(base, approach),
		get_step(get_step(base, approach), turn(approach, -90)),
		get_step(get_step(base, approach), approach),
	)
	var/list/usable = list()
	for(var/turf/spot as anything in wanted)
		if(spot && !spot.density && !(spot in usable))
			usable += spot
	return usable

/// Starts a breach on the door, true when the squad had what it takes
/datum/human_ai_squad/proc/start_breach(turf/door_turf)
	if(breach_state != HAI_BREACH_IDLE || !door_turf)
		return FALSE
	var/list/ready = list()
	for(var/datum/human_ai_brain/brain as anything in members)
		if(member_valid(brain) && !brain.current_order)
			ready += brain
	if(length(ready) < 2)
		return FALSE
	var/total_x = 0
	var/total_y = 0
	for(var/datum/human_ai_brain/brain as anything in ready)
		total_x += brain.body.x
		total_y += brain.body.y
	var/dx = total_x / length(ready) - door_turf.x
	var/dy = total_y / length(ready) - door_turf.y
	var/approach = (abs(dx) >= abs(dy)) ? ((dx > 0) ? EAST : WEST) : ((dy > 0) ? NORTH : SOUTH)
	var/inside = turn(approach, 180)
	var/turf/room_spot = door_turf
	for(var/step_count in 1 to HAI_BREACH_DEPTH)
		var/turf/deeper = get_step(room_spot, inside)
		if(!deeper || deeper.density)
			break
		room_spot = deeper
	if(room_spot == door_turf)
		return FALSE
	breach_door = locate(/obj/structure/machinery/door) in door_turf
	breach_room_spot = room_spot
	breach_log = list()
	var/list/spots = stack_spots(door_turf, approach)
	if(length(spots) < length(ready))
		ready.Cut(length(spots) + 1)
	breach_members = list()
	var/index = 0
	for(var/datum/human_ai_brain/brain as anything in ready)
		index++
		var/datum/npc_order/move/go = new
		go.internal = TRUE
		go.target_turf = spots[index]
		go.radius = 0
		if(brain.give_order(go))
			breach_members += brain
			breach_spots[brain] = spots[index]
	if(length(breach_members) < 2)
		return FALSE
	breach_opener = breach_members[1]
	breach_thrower = breach_members[min(2, length(breach_members))]
	breach_state = HAI_BREACH_STACK
	breach_started = world.time
	breach_note("stacking at [door_turf.x],[door_turf.y]")
	return TRUE

/datum/human_ai_squad/proc/end_breach(reason)
	breach_note(reason)
	for(var/datum/human_ai_brain/brain as anything in breach_members)
		if(brain.current_order?.internal && brain.current_order.id == "maneuver")
			brain.cancel_order("breach over")
	breach_state = HAI_BREACH_IDLE
	breach_door = null
	breach_opener = null
	breach_thrower = null
	breach_members = list()
	breach_spots = list()

/// Whether the brain is one of a team stacked at a door and not yet sent in, it stays where it stands instead of going back to its post
/datum/human_ai_brain/proc/holding_stack()
	return squad && squad.breach_state != HAI_BREACH_IDLE && (src in squad.breach_members)

/datum/human_ai_squad/proc/breach_stacked()
	for(var/datum/human_ai_brain/brain as anything in breach_members)
		if(!member_valid(brain))
			continue
		if(get_dist(brain.body, breach_spots[brain]) > 1)
			return FALSE
	return TRUE

/// A flashbang the thrower carries
/datum/human_ai_squad/proc/breach_flash(datum/human_ai_brain/thrower)
	for(var/obj/item/explosive/grenade/grenade in thrower.body.get_contents())
		if(human_ai_grenade_kind(grenade) == HAI_GRENADE_FLASH)
			return grenade
	return null

/// No friend close enough to the landing point to be caught by the flash
/datum/human_ai_squad/proc/blast_clear()
	for(var/mob/living/bystander in range(HAI_GRENADE_SAFE_RADIUS, breach_room_spot))
		if(bystander.stat != DEAD && breach_opener.get_disposition(bystander) <= HAI_DISP_FRIEND && !(bystander in breach_members_bodies()))
			return FALSE
	return TRUE

/datum/human_ai_squad/proc/breach_members_bodies()
	var/list/bodies = list()
	for(var/datum/human_ai_brain/brain as anything in breach_members)
		bodies += brain.body
	return bodies

/// True when no member of the team would be caught by its own flash: far enough from the landing point or with eyes covered
/datum/human_ai_squad/proc/team_protected(obj/item/explosive/grenade/flash)
	for(var/datum/human_ai_brain/brain as anything in breach_members)
		if(!member_valid(brain))
			continue
		var/distance = get_dist(brain.body, breach_room_spot)
		if(brain == breach_thrower)
			distance = min(distance, flash.throw_range)
		if(distance <= HAI_FLASH_RANGE && brain.body.get_eye_protection() < EYE_PROTECTION_FLASH)
			return FALSE
	return TRUE

/datum/human_ai_squad/proc/breach_step()
	if(breach_state == HAI_BREACH_IDLE)
		return
	for(var/datum/human_ai_brain/brain as anything in breach_members.Copy())
		if(!member_valid(brain))
			breach_members -= brain
			if(brain == breach_opener || brain == breach_thrower)
				breach_opener = (brain == breach_opener) ? null : breach_opener
				breach_thrower = (brain == breach_thrower) ? null : breach_thrower
	if(length(breach_members) < 2 || world.time > breach_started + HAI_BREACH_TIMEOUT)
		end_breach("abandoned")
		return
	if(!breach_opener)
		breach_opener = breach_members[1]
	if(!breach_thrower)
		breach_thrower = breach_members[length(breach_members)]
	switch(breach_state)
		if(HAI_BREACH_STACK)
			if(breach_stacked() || world.time > breach_started + 20 SECONDS)
				breach_note("stacked")
				breach_state = HAI_BREACH_OPEN
				breach_wait_until = world.time + 40
		if(HAI_BREACH_OPEN)
			if(breach_door?.density)
				if(world.time >= breach_wait_until - 30)
					INVOKE_ASYNC(breach_door, TYPE_PROC_REF(/obj/structure/machinery/door, open))
					breach_wait_until = world.time + 40
				if(world.time > breach_wait_until)
					breach_note("door would not open")
					end_breach("failed")
				return
			breach_note("door open")
			breach_state = HAI_BREACH_THROW
			breach_wait_until = world.time + 30
		if(HAI_BREACH_THROW)
			var/obj/item/explosive/grenade/flash = breach_flash(breach_thrower)
			if(!flash)
				breach_note("no flash")
				breach_state = HAI_BREACH_ENTER
				return
			if(!blast_clear())
				breach_note("blocked, a friend is in the room")
				if(world.time > breach_wait_until)
					breach_state = HAI_BREACH_ENTER
				return
			if(!team_protected(flash))
				breach_note("exposed, the team would be caught by its own flash")
				breach_state = HAI_BREACH_ENTER
				return
			// The grenade is drawn before it is thrown and then goes off after its fuse
			breach_flash_wait = HAI_GRENADE_DRAW_TIME + flash.det_time + 7
			if(breach_thrower.throw_grenade(flash, breach_room_spot, FALSE))
				breach_note("flash thrown")
				flashes_thrown++
				breach_state = HAI_BREACH_WAIT
				breach_wait_until = world.time + breach_flash_wait
			else if(world.time > breach_wait_until)
				breach_note("flash would not go")
				breach_state = HAI_BREACH_ENTER
		if(HAI_BREACH_WAIT)
			if(world.time >= breach_wait_until)
				breach_state = HAI_BREACH_ENTER
		if(HAI_BREACH_ENTER)
			var/area/room = get_area(breach_room_spot)
			var/list/sectors = breach_opener.area_points(room, length(breach_members), breach_room_spot)
			var/index = 0
			for(var/datum/human_ai_brain/brain as anything in breach_members)
				index++
				var/datum/npc_order/maneuver/enter = new
				enter.waypoints = list(breach_room_spot)
				if(length(sectors) >= index)
					enter.waypoints += sectors[index]
				enter.sprint = FALSE
				brain.give_order(enter)
			breach_note("entering")
			breach_state = HAI_BREACH_CLEAR
			breach_wait_until = world.time + HAI_BREACH_CLEAR_TIME
		if(HAI_BREACH_CLEAR)
			var/running = 0
			for(var/datum/human_ai_brain/brain as anything in breach_members)
				if(brain.current_order?.id == "maneuver")
					running++
			if(!running || world.time > breach_wait_until)
				breaches_done++
				var/list/where = list()
				for(var/datum/human_ai_brain/brain as anything in breach_members)
					where += "[brain.body.x],[brain.body.y] ([brain.current_order?.id || "no order"], [brain.move_state])"
				end_breach("cleared with the team at [where.Join("; ")]")
