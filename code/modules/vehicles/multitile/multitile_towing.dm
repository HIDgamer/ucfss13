// A hooked trailer is dragged along the trail its tower leaves, hanging back a few steps behind it.

//Number of tiles the vehicle covers
/obj/vehicle/multitile/proc/tow_size()
	return (bound_width / world.icon_size) * (bound_height / world.icon_size)

//Footprint centre relative to the vehicle's origin, in half tiles
/obj/vehicle/multitile/proc/get_center_offset2()
	return list(2 * bound_x / world.icon_size + bound_width / world.icon_size - 1, 2 * bound_y / world.icon_size + bound_height / world.icon_size - 1)

//Footprint centre in half tiles, so even sized vehicles stay on whole numbers
/obj/vehicle/multitile/proc/get_center2()
	var/list/offset = get_center_offset2()
	return list(2 * x + offset[1], 2 * y + offset[2])

//The turfs the vehicle covers when its origin is on the given turf
/obj/vehicle/multitile/proc/get_footprint(turf/origin)
	if(!origin)
		origin = get_turf(src)
	var/turf/corner = locate(origin.x + bound_x / world.icon_size, origin.y + bound_y / world.icon_size, origin.z)
	if(!corner)
		return list()
	return CORNER_BLOCK(corner, bound_width / world.icon_size, bound_height / world.icon_size)

//Whether driving the footprint onto the given origin is stopped by something, ignoring the given atom
/obj/vehicle/multitile/proc/tow_blocked_at(turf/new_origin, atom/ignored)
	if(!new_origin)
		return TRUE
	var/list/old_turfs = get_footprint()
	var/list/new_turfs = get_footprint(new_origin)
	if(length(new_turfs) != length(old_turfs))
		return TRUE
	for(var/turf/T as anything in new_turfs)
		if(T in old_turfs)
			continue
		if(!T.Enter(src, ignored))
			return TRUE
	return FALSE

//Sends the driver a tow message, no more than once in a while
/obj/vehicle/multitile/proc/tow_message(message, cooldown = 3 SECONDS)
	if(world.time < next_tow_message)
		return
	var/mob/driver = seats[VEHICLE_DRIVER]
	if(!driver)
		return
	next_tow_message = world.time + cooldown
	to_chat(driver, message)

//Tells the driver when something is lined up to be hooked while backing up
/obj/vehicle/multitile/proc/tow_hint()
	if(towing || towed_by || !tow_capable || world.time < next_tow_message)
		return
	var/obj/vehicle/multitile/trailer = find_trailer()
	if(trailer)
		tow_message(SPAN_NOTICE("\The [trailer] is lined up with your tow hitch. Use Hook Tow to attach it."), 8 SECONDS)

//Move delay multiplier from the trailer being hauled
/obj/vehicle/multitile/proc/get_tow_slowdown()
	if(towed_mob)
		return 1.1
	if(!towing)
		return 1
	return TOW_SLOWDOWN_BASE + TOW_SLOWDOWN_SCALE * towing.tow_size() / tow_size()

//Why the trailer can't be hooked to this vehicle, or null if it can
/obj/vehicle/multitile/proc/get_tow_block_reason(obj/vehicle/multitile/trailer)
	if(!tow_capable)
		return "\The [src] has no tow hitch."
	if(!trailer.tow_capable)
		return "\The [trailer] can't be towed."
	if(towing || towed_by)
		return "\The [src] is already hooked up."
	if(trailer.towing || trailer.towed_by)
		return "\The [trailer] is already hooked up."
	if(health <= 0)
		return "\The [src] is too damaged to tow anything."
	if(clamped)
		return "The wheel clamp on \the [src] locks it in place."
	if(trailer.clamped)
		return "The wheel clamp on \the [trailer] locks it in place."
	if(trailer.tow_size() > tow_size())
		return "\The [trailer] is too big for \the [src] to tow."
	return null

//Whether the trailer sits against this vehicle's rear, close enough to its centreline to hook up
/obj/vehicle/multitile/proc/is_hitch_aligned(obj/vehicle/multitile/trailer)
	if(trailer == src || trailer.z != z)
		return FALSE
	if(trailer.dir != dir && trailer.dir != REVERSE_DIR(dir))
		return FALSE
	var/list/mine = get_center2()
	var/list/theirs = trailer.get_center2()
	var/dx2 = theirs[1] - mine[1]
	var/dy2 = theirs[2] - mine[2]
	var/rear_x = ((dir & WEST) ? 1 : 0) - ((dir & EAST) ? 1 : 0)
	var/rear_y = ((dir & SOUTH) ? 1 : 0) - ((dir & NORTH) ? 1 : 0)
	var/along2 = dx2 * rear_x + dy2 * rear_y
	var/across2 = dx2 * rear_y - dy2 * rear_x
	var/gap2 = along2 - (bound_width + trailer.bound_width) / world.icon_size
	return gap2 >= 0 && gap2 <= 2 * TOW_MAX_GAP && abs(across2) <= TOW_MAX_OFFSET

//The vehicle hooked up or ready to hook up behind this one
/obj/vehicle/multitile/proc/find_trailer(list/reasons)
	for(var/obj/vehicle/multitile/other as anything in GLOB.all_multi_vehicles)
		if(other == src || other.z != z || get_dist(src, other) > TOW_SEARCH_RANGE)
			continue
		if(!is_hitch_aligned(other))
			continue
		var/reason = get_tow_block_reason(other)
		if(!reason)
			return other
		reasons?.Add(reason)
	return null

//The vehicle this one could be hooked up behind
/obj/vehicle/multitile/proc/find_tower(list/reasons)
	for(var/obj/vehicle/multitile/other as anything in GLOB.all_multi_vehicles)
		if(other == src || other.z != z || get_dist(src, other) > TOW_SEARCH_RANGE)
			continue
		if(!other.is_hitch_aligned(src))
			continue
		var/reason = other.get_tow_block_reason(src)
		if(!reason)
			return other
		reasons?.Add(reason)
	return null

//Seconds to hook up or release, longer for the untrained
/obj/vehicle/multitile/proc/get_tow_work_time(mob/user, base_time)
	if(skillcheck(user, SKILL_VEHICLE, SKILL_VEHICLE_SMALL))
		return base_time
	return base_time * 2

//How many of the tower's steps the trailer hangs back by, enough for it to clear the tower on a right angle turn
/obj/vehicle/multitile/proc/get_tow_lag(obj/vehicle/multitile/trailer)
	var/reach = ceil((bound_width + trailer.bound_width) / (2 * world.icon_size))
	return 2 * reach - 1

//Joins the trailer to this vehicle, laying down the trail it will be dragged along from where it sits now
/obj/vehicle/multitile/proc/tow_hook(obj/vehicle/multitile/trailer)
	var/list/mine = get_center2()
	var/list/theirs = trailer.get_center2()
	var/dx2 = theirs[1] - mine[1]
	var/dy2 = theirs[2] - mine[2]
	var/along_x = abs(dx2) >= abs(dy2)
	var/apart = max(ceil(max(abs(dx2), abs(dy2)) / 2), 1)
	var/sign = ((along_x ? dx2 : dy2) >= 0) ? 1 : -1
	tow_lag = get_tow_lag(trailer)
	trailer.tow_reversed = trailer.dir == REVERSE_DIR(dir)
	tow_trail = list(theirs.Copy())
	for(var/i = apart - 1, i >= 1, i--)
		tow_trail += list(along_x ? list(mine[1] + 2 * i * sign, mine[2]) : list(mine[1], mine[2] + 2 * i * sign))
	tow_trailer_turf = get_turf(trailer)
	towing = trailer
	trailer.towed_by = src
	trailer.move_momentum = 0
	tow_cord = beam(trailer, "wire", always_turn = FALSE)
	visible_message(SPAN_NOTICE("\The [src] is hooked up to \the [trailer]."))
	tow_refresh_nearby()

//Frees this vehicle from whatever it is towing and whatever is towing it
/obj/vehicle/multitile/proc/break_tow()
	var/obj/vehicle/multitile/other
	if(towed_mob)
		tow_release_mob()
		other = src
	if(towing)
		QDEL_NULL(tow_cord)
		other = towing
		towing.towed_by = null
		towing = null
	if(towed_by)
		other = towed_by
		QDEL_NULL(towed_by.tow_cord)
		towed_by.towing = null
		towed_by.tow_trail = null
		towed_by.tow_trailer_turf = null
		towed_by = null
	tow_trail = null
	tow_trailer_turf = null
	if(other)
		tow_refresh_nearby()
		other.tow_refresh_nearby()

//Breaks the tow if the trailer has been moved off its place, returns whether it is still hooked
/obj/vehicle/multitile/proc/tow_link_intact()
	if(!towing)
		return FALSE
	if(QDELETED(towing) || towing.z != z || get_turf(towing) != tow_trailer_turf)
		tow_message(SPAN_WARNING("The tow hitch snaps as \the [towing] is knocked out of line!"))
		break_tow()
		return FALSE
	return TRUE

//Whether the trailer can be dragged along as this vehicle steps, it may fall a little behind but not be stretched too far
/obj/vehicle/multitile/proc/can_tow_move(direction)
	if(towed_mob && tow_victim_overstretched())
		tow_message(SPAN_WARNING("[towed_mob] is caught on something behind you."))
		move_momentum = floor(move_momentum / 2)
		update_next_move()
		return FALSE
	if(!tow_link_intact())
		return TRUE
	if(towing.clamped)
		tow_message(SPAN_WARNING("The wheel clamp on \the [towing] holds it in place."))
		return FALSE
	var/list/behind = length(tow_trail) >= tow_lag ? towing.get_center2() : null
	if(behind && max(abs(tow_trail[1][1] - behind[1]), abs(tow_trail[1][2] - behind[2])) >= 2 * TOW_MAX_STRETCH)
		tow_message(SPAN_WARNING("\The [towing] is caught on something behind you."))
		move_momentum = floor(move_momentum / 2)
		update_next_move()
		return FALSE
	return TRUE

//Drags the trailer a tile towards the point of the tower's trail it hangs back at, given where the tower's centre was before it stepped
/obj/vehicle/multitile/proc/tow_advance(list/old_center, turf/old_origin)
	if(towed_mob && old_origin)
		tow_advance_mob(old_origin)
	if(!towing || !old_center)
		return
	tow_trail += list(old_center)
	var/index = length(tow_trail) - tow_lag + 1
	if(index < 1)
		return
	if(index > 1)
		tow_trail.Cut(1, index)
	towing.tow_drag_toward(tow_trail[1], src)
	tow_trailer_turf = get_turf(towing)

//Whether any of the footprint at the given origin is covered by the other vehicle
/obj/vehicle/multitile/proc/tow_overlaps(turf/new_origin, obj/vehicle/multitile/other)
	var/list/other_turfs = other.get_footprint()
	for(var/turf/T as anything in get_footprint(new_origin))
		if(T in other_turfs)
			return TRUE
	return FALSE

//Drags this trailer a tile towards the given centre, returns whether it is already there, moved or could not move
/obj/vehicle/multitile/proc/tow_drag_toward(list/target, obj/vehicle/multitile/tower)
	var/list/mine = get_center2()
	var/dx2 = target[1] - mine[1]
	var/dy2 = target[2] - mine[2]
	var/list/directions = list()
	if(abs(dx2) >= 2)
		directions += (dx2 > 0) ? EAST : WEST
	if(abs(dy2) >= 2)
		directions += (dy2 > 0) ? NORTH : SOUTH
	if(!length(directions))
		return TOW_DRAG_REACHED
	if(length(directions) == 2 && abs(dx2) > abs(dy2))
		directions.Swap(1, 2)
	for(var/step_dir in directions)
		var/turf/next = get_step(src, step_dir)
		if(tow_blocked_at(next, tower) || tow_overlaps(next, tower))
			continue
		tow_follow(step_dir)
		return TOW_DRAG_MOVED
	return TOW_DRAG_STUCK

//Turns to face the given direction then steps that way, dragged behind the tower
/obj/vehicle/multitile/proc/tow_follow(direction)
	var/facing = tow_reversed ? REVERSE_DIR(direction) : direction
	if(dir != facing && can_rotate(turning_angle(dir, facing)))
		do_rotate(turning_angle(dir, facing))
		update_icon()
	var/turf/old_turf = get_turf(src)
	forceMove(get_step(src, direction))
	var/turf/current_loc = get_turf(src)
	for(var/obj/item/hardpoint/H in hardpoints)
		H.on_move(old_turf, current_loc, direction)
	last_move_dir = direction
	l_move_time = world.time

//Whether another vehicle is lined up to be hooked to or from this one
/obj/vehicle/multitile/proc/tow_hookable()
	return !towing && !towed_by && (find_trailer() || find_tower())

//Shows the hook and release options only while there is something to hook or release
/obj/vehicle/multitile/proc/update_tow_verbs()
	if(!tow_capable)
		return
	var/can_release = !!(towing || towed_by || towed_mob)
	var/can_hook = !can_release && (tow_hookable() || tow_person_hookable())
	if(can_hook)
		verbs |= /obj/vehicle/multitile/verb/hook_tow_nearby
	else
		verbs -= /obj/vehicle/multitile/verb/hook_tow_nearby
	if(can_release)
		verbs |= /obj/vehicle/multitile/verb/release_tow_nearby
	else
		verbs -= /obj/vehicle/multitile/verb/release_tow_nearby
	var/mob/driver = seats[VEHICLE_DRIVER]
	if(!driver?.client)
		return
	if(can_hook)
		add_verb(driver.client, /obj/vehicle/multitile/proc/hook_tow)
	else
		remove_verb(driver.client, /obj/vehicle/multitile/proc/hook_tow)
	if(can_release)
		add_verb(driver.client, /obj/vehicle/multitile/proc/release_tow)
	else
		remove_verb(driver.client, /obj/vehicle/multitile/proc/release_tow)

//Refreshes the tow options of this vehicle and every vehicle near enough to be its partner
/obj/vehicle/multitile/proc/tow_refresh_nearby()
	update_tow_verbs()
	for(var/obj/vehicle/multitile/other as anything in GLOB.all_multi_vehicles)
		if(other != src && other.z == z && get_dist(src, other) <= TOW_SEARCH_RANGE + 2)
			other.update_tow_verbs()

//Hooks up a trailer for the user, with this vehicle as the tower
/obj/vehicle/multitile/proc/hook_up(mob/user, obj/vehicle/multitile/trailer)
	to_chat(user, SPAN_NOTICE("You start hooking \the [trailer] up to \the [src]."))
	if(!do_after(user, get_tow_work_time(user, 3 SECONDS), INTERRUPT_ALL, BUSY_ICON_BUILD))
		to_chat(user, SPAN_WARNING("You stop hooking \the [trailer] up to \the [src]."))
		return FALSE
	if(QDELETED(trailer) || !is_hitch_aligned(trailer) || get_tow_block_reason(trailer))
		to_chat(user, SPAN_WARNING("\The [trailer] and \the [src] are no longer lined up."))
		return FALSE
	tow_hook(trailer)
	return TRUE

//Releases the trailer from this vehicle for the user
/obj/vehicle/multitile/proc/release_up(mob/user)
	if(towed_mob)
		var/mob/living/victim = towed_mob
		to_chat(user, SPAN_NOTICE("You start cutting [victim] loose."))
		if(!do_after(user, get_tow_work_time(user, 2 SECONDS), INTERRUPT_ALL, BUSY_ICON_BUILD, victim))
			return FALSE
		if(towed_mob != victim)
			return FALSE
		break_tow()
		visible_message(SPAN_NOTICE("[victim] is cut loose from 	he [src]."))
		return TRUE
	var/obj/vehicle/multitile/trailer = towing
	if(!trailer)
		return FALSE
	to_chat(user, SPAN_NOTICE("You start unhooking \the [trailer] from \the [src]."))
	if(!do_after(user, get_tow_work_time(user, 2 SECONDS), INTERRUPT_ALL, BUSY_ICON_BUILD))
		to_chat(user, SPAN_WARNING("You stop unhooking \the [trailer] from \the [src]."))
		return FALSE
	if(towing != trailer)
		return FALSE
	break_tow()
	visible_message(SPAN_NOTICE("\The [trailer] is unhooked from \the [src]."))
	return TRUE

//Hooks up whatever is lined up behind this vehicle, for a driver
/obj/vehicle/multitile/proc/driver_hook(mob/user)
	if(towing || towed_by || towed_mob)
		to_chat(user, SPAN_WARNING("\The [src] is already hooked up."))
		return
	var/list/reasons = list()
	var/obj/vehicle/multitile/trailer = find_trailer(reasons)
	if(!trailer)
		var/mob/living/carbon/victim = find_tow_victim()
		if(victim && tow_person_hookable())
			hook_person(user, victim)
			return
		to_chat(user, SPAN_WARNING(length(reasons) ? reasons[1] : "Nothing is lined up behind \the [src]. Back its rear up to the front or rear of another vehicle first."))
		return
	hook_up(user, trailer)

//Releases the trailer or the tower, for a driver
/obj/vehicle/multitile/proc/driver_release(mob/user)
	var/obj/vehicle/multitile/tower = (towing || towed_mob) ? src : towed_by
	if(!tower)
		to_chat(user, SPAN_WARNING("\The [src] isn't hooked to anything."))
		return
	tower.release_up(user)

//Hooks up this vehicle to or onto the one lined up against it, for someone on foot
/obj/vehicle/multitile/proc/hand_hook(mob/user)
	if(towing || towed_by || towed_mob)
		to_chat(user, SPAN_WARNING("\The [src] is already hooked up."))
		return
	var/list/reasons = list()
	var/obj/vehicle/multitile/tower = src
	var/obj/vehicle/multitile/trailer = find_trailer(reasons)
	if(!trailer)
		tower = find_tower(reasons)
		trailer = src
	if(!tower)
		var/mob/living/carbon/victim = find_tow_victim()
		if(victim && tow_person_hookable())
			hook_person(user, victim)
			return
		to_chat(user, SPAN_WARNING(length(reasons) ? reasons[1] : "Nothing is lined up with \the [src]'s tow hitch. Back the rear of one vehicle up to the front or rear of another first."))
		return
	tower.hook_up(user, trailer)

//Releases this vehicle from whatever it is hooked to, for someone on foot
/obj/vehicle/multitile/proc/hand_release(mob/user)
	var/obj/vehicle/multitile/tower = (towing || towed_mob) ? src : towed_by
	if(!tower)
		to_chat(user, SPAN_WARNING("\The [src] isn't hooked to anything."))
		return
	tower.release_up(user)

/obj/vehicle/multitile/proc/add_tow_verbs(mob/living/M, seat)
	if(!tow_capable || seat != VEHICLE_DRIVER || !M?.client)
		return
	addtimer(CALLBACK(src, PROC_REF(update_tow_verbs)), 0)

/obj/vehicle/multitile/proc/remove_tow_verbs(mob/living/M, seat)
	if(!tow_capable || seat != VEHICLE_DRIVER || !M?.client)
		return
	remove_verb(M.client, list(
		/obj/vehicle/multitile/proc/hook_tow,
		/obj/vehicle/multitile/proc/release_tow,
	))

//Driver verb: hooks up the vehicle lined up behind you
/obj/vehicle/multitile/proc/hook_tow()
	set name = "Hook Tow"
	set desc = "Hooks up the vehicle lined up against your rear so it follows you."
	set category = "Vehicle"

	var/mob/user = usr
	if(!istype(user))
		return

	var/obj/vehicle/multitile/V = user.interactee
	if(!istype(V) || V.get_mob_seat(user) != VEHICLE_DRIVER)
		return

	V.driver_hook(user)

//Driver verb: lets go of the vehicle you are towing or being towed by
/obj/vehicle/multitile/proc/release_tow()
	set name = "Release Tow"
	set desc = "Unhooks your vehicle from the one it is towing or being towed by."
	set category = "Vehicle"

	var/mob/user = usr
	if(!istype(user))
		return

	var/obj/vehicle/multitile/V = user.interactee
	if(!istype(V) || V.get_mob_seat(user) != VEHICLE_DRIVER)
		return

	V.driver_release(user)

//Right click verb: hooks up the vehicle lined up against this one
/obj/vehicle/multitile/verb/hook_tow_nearby()
	set name = "Hook Tow"
	set desc = "Hooks this vehicle up to the vehicle lined up against its front or rear."
	set category = "Object"
	set src in view(1)

	var/mob/living/carbon/human/user = usr
	if(!istype(user) || user.is_mob_incapacitated() || !Adjacent(user))
		return

	hand_hook(user)

//Right click verb: unhooks this vehicle
/obj/vehicle/multitile/verb/release_tow_nearby()
	set name = "Release Tow"
	set desc = "Unhooks this vehicle from the one it is towing or being towed by."
	set category = "Object"
	set src in view(1)

	var/mob/living/carbon/human/user = usr
	if(!istype(user) || user.is_mob_incapacitated() || !Adjacent(user))
		return

	hand_release(user)

//Someone being pulled close enough behind this vehicle to be hooked to it
/obj/vehicle/multitile/proc/find_tow_victim()
	var/list/footprint = get_footprint()
	for(var/mob/living/carbon/victim in range(TOW_PERSON_RANGE, src))
		if(!ishuman(victim) && !isxeno(victim))
			continue
		if(!victim.pulledby || (get_turf(victim) in footprint) || HAS_TRAIT_FROM(victim, TRAIT_IMMOBILIZED, TRAIT_SOURCE_TOW))
			continue
		return victim
	return null

//Whether someone is being pulled up to this vehicle ready to be hooked on
/obj/vehicle/multitile/proc/tow_person_hookable()
	if(!tow_capable || towing || towed_by || towed_mob || health <= 0 || clamped)
		return FALSE
	return !!find_tow_victim()

//Hooks the person being pulled up to this vehicle on behalf of the user
/obj/vehicle/multitile/proc/hook_person(mob/user, mob/living/carbon/victim)
	if(!tow_capable || towing || towed_by || towed_mob)
		to_chat(user, SPAN_WARNING("\The [src] is already hooked up."))
		return FALSE
	if(clamped || health <= 0)
		to_chat(user, SPAN_WARNING("\The [src] can't tow anyone right now."))
		return FALSE
	to_chat(user, SPAN_NOTICE("You start hooking [victim] to \the [src]."))
	if(!do_after(user, get_tow_work_time(user, 4 SECONDS), INTERRUPT_ALL, BUSY_ICON_BUILD, victim))
		to_chat(user, SPAN_WARNING("You stop hooking [victim] to \the [src]."))
		return FALSE
	if(QDELETED(victim) || victim.pulledby != user || get_dist(src, victim) > TOW_PERSON_RANGE || towing || towed_by || towed_mob)
		to_chat(user, SPAN_WARNING("[victim] is no longer in position to be hooked."))
		return FALSE
	tow_person_hook(victim)
	return TRUE

//Ties the person to this vehicle, floored and unable to move, laying the trail they will be dragged along
/obj/vehicle/multitile/proc/tow_person_hook(mob/living/carbon/victim)
	victim.pulledby?.stop_pulling()
	var/turf/origin = get_turf(src)
	var/turf/start = get_turf(victim)
	var/dx = start.x - origin.x
	var/dy = start.y - origin.y
	var/along_x = abs(dx) >= abs(dy)
	var/apart = max(abs(along_x ? dx : dy), 1)
	var/sign = ((along_x ? dx : dy) >= 0) ? 1 : -1
	tow_mob_lag = ceil((bound_width / world.icon_size + 1) / 2) + 1
	tow_mob_trail = list(start)
	for(var/i = apart - 1, i >= 1, i--)
		var/turf/point = along_x ? locate(origin.x + i * sign, origin.y, origin.z) : locate(origin.x, origin.y + i * sign, origin.z)
		if(point)
			tow_mob_trail += point
	towed_mob = victim
	victim.add_traits(list(TRAIT_FLOORED, TRAIT_IMMOBILIZED), TRAIT_SOURCE_TOW)
	RegisterSignal(victim, COMSIG_MOB_RESISTED, PROC_REF(on_tow_victim_resisted))
	RegisterSignal(victim, COMSIG_PARENT_QDELETING, PROC_REF(on_tow_victim_deleted))
	victim.verbs += /mob/living/proc/unhook_from_tow
	tow_mob_cord = beam(victim, "wire", always_turn = FALSE)
	visible_message(SPAN_WARNING("[victim] is hooked to the back of \the [src]!"))
	tow_refresh_nearby()

//Lets the hooked person go
/obj/vehicle/multitile/proc/tow_release_mob()
	var/mob/living/victim = towed_mob
	towed_mob = null
	tow_mob_trail = null
	QDEL_NULL(tow_mob_cord)
	if(!victim)
		return
	victim.remove_traits(list(TRAIT_FLOORED, TRAIT_IMMOBILIZED), TRAIT_SOURCE_TOW)
	UnregisterSignal(victim, list(COMSIG_MOB_RESISTED, COMSIG_PARENT_QDELETING))
	victim.verbs -= /mob/living/proc/unhook_from_tow

/obj/vehicle/multitile/proc/on_tow_victim_deleted()
	SIGNAL_HANDLER
	break_tow()

/obj/vehicle/multitile/proc/on_tow_victim_resisted()
	SIGNAL_HANDLER
	if(towed_mob)
		INVOKE_ASYNC(src, PROC_REF(tow_victim_resist), towed_mob)

//The hooked person struggles in place until the rope gives
/obj/vehicle/multitile/proc/tow_victim_resist(mob/living/victim)
	to_chat(victim, SPAN_DANGER("You struggle against the rope. (This will take around [TOW_PERSON_RESIST_TIME / 10] seconds and you need to stay still.)"))
	if(!do_after(victim, TOW_PERSON_RESIST_TIME, INTERRUPT_NO_FLOORED^INTERRUPT_RESIST, BUSY_ICON_HOSTILE))
		return
	if(towed_mob != victim)
		return
	victim.visible_message(SPAN_DANGER("[victim] works free of the rope!"), SPAN_WARNING("You work free of the rope!"))
	break_tow()

//Whether the hooked person is being dragged too far behind to keep up
/obj/vehicle/multitile/proc/tow_victim_overstretched()
	if(length(tow_mob_trail) < tow_mob_lag)
		return FALSE
	var/turf/target = tow_mob_trail[1]
	return get_dist(target, get_turf(towed_mob)) >= TOW_MAX_STRETCH

//Drags the hooked person a tile towards the point of the trail they hang back at, given where the vehicle's origin was before it stepped
/obj/vehicle/multitile/proc/tow_advance_mob(turf/old_origin)
	var/mob/living/victim = towed_mob
	if(QDELETED(victim) || victim.z != z)
		break_tow()
		return
	tow_mob_trail += old_origin
	var/index = length(tow_mob_trail) - tow_mob_lag + 1
	if(index < 1)
		return
	if(index > 1)
		tow_mob_trail.Cut(1, index)
	var/turf/target = tow_mob_trail[1]
	var/turf/here = get_turf(victim)
	var/dx = target.x - here.x
	var/dy = target.y - here.y
	var/list/directions = list()
	if(dx)
		directions += (dx > 0) ? EAST : WEST
	if(dy)
		directions += (dy > 0) ? NORTH : SOUTH
	if(length(directions) == 2 && abs(dx) > abs(dy))
		directions.Swap(1, 2)
	var/list/footprint = get_footprint()
	for(var/step_dir in directions)
		var/turf/next = get_step(victim, step_dir)
		if(!next || next.density || (next in footprint) || !next.Enter(victim, here))
			continue
		victim.forceMove(next)
		tow_hurt_victim(victim)
		return

//Scrapes the dragged person, never past the point of killing them outright
/obj/vehicle/multitile/proc/tow_hurt_victim(mob/living/victim)
	if(victim.stat == DEAD || victim.health <= victim.maxHealth * TOW_DRAG_MIN_HEALTH)
		return
	var/zone = pick("chest", "groin", "l_leg", "r_leg", "l_arm", "r_arm")
	victim.apply_damage(TOW_DRAG_DAMAGE, BRUTE, zone)
	if(ishuman(victim) && abs(move_momentum) >= 2 && prob(TOW_DRAG_FRACTURE_CHANCE) && zone != "chest" && zone != "groin")
		var/mob/living/carbon/human/human_victim = victim
		var/obj/limb/limb = human_victim.get_limb(zone)
		limb?.fracture(100)

//Right click verb on a hooked person: unhooks them from the vehicle
/mob/living/proc/unhook_from_tow()
	set name = "Unhook Tow"
	set desc = "Cuts this person loose from the vehicle they are hooked to."
	set category = "Object"
	set src in view(1)

	var/mob/living/user = usr
	if(!istype(user) || user.is_mob_incapacitated() || user == src)
		return
	for(var/obj/vehicle/multitile/vehicle as anything in GLOB.all_multi_vehicles)
		if(vehicle.towed_mob != src)
			continue
		to_chat(user, SPAN_NOTICE("You start cutting [src] loose."))
		if(!do_after(user, 3 SECONDS, INTERRUPT_ALL, BUSY_ICON_BUILD, src))
			return
		if(vehicle.towed_mob == src)
			vehicle.break_tow()
			visible_message(SPAN_NOTICE("[user] cuts [src] loose from \the [vehicle]."))
		return

//Refreshes the tow options of every vehicle near someone who has just started pulling, so a person pulled up to one can be hooked on
/proc/vehicle_tow_refresh_near(atom/puller)
	for(var/obj/vehicle/multitile/vehicle as anything in GLOB.all_multi_vehicles)
		if(vehicle.z != puller.z || get_dist(vehicle, puller) > TOW_PERSON_RANGE + 3)
			continue
		vehicle.update_tow_verbs()
		addtimer(CALLBACK(vehicle, TYPE_PROC_REF(/obj/vehicle/multitile, update_tow_verbs)), 10 SECONDS, TIMER_UNIQUE|TIMER_OVERRIDE)
