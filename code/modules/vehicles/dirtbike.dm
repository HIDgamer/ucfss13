/obj/vehicle/motorbike
	name = "\improper Dirtbike"
	icon_state = "motorbike"
	desc = "Almost, but not quite, the best ride in the universe."
	move_delay = 1 //The speed of a fed but shoeless pajamarine, or a bit slower than a heavy-armor marine.
	buckling_y = 4
	health = 200
	layer = ABOVE_LYING_MOB_LAYER //Allows it to drive over people, but is below the driver.
	//Sound to play when moving
	var/movement_sound = 'sound/vehicles/bike.ogg'
	//Cooldown for next sound to play
	var/move_next_sound_play = 0
	light_system = MOVABLE_LIGHT
	light_range = 5

/obj/vehicle/motorbike/Initialize()
	. = ..()
	var/image/I = new(icon = 'icons/obj/vehicles/vehicles.dmi', icon_state = "[icon_state]_overlay", layer = ABOVE_MOB_LAYER) //over mobs
	overlays += I

/obj/vehicle/motorbike/manual_unbuckle(mob/user)
	if(buckled_mob && buckled_mob != user)
		if(do_after(user, 20, INTERRUPT_ALL, BUSY_ICON_GENERIC))
			..()
	else ..()

/obj/vehicle/motorbike/relaymove(mob/user, direction)
	if(user.is_mob_incapacitated())
		return
	if(world.time > l_move_time + move_delay)
		. = step(src, direction)
		if(movement_sound && world.time > move_next_sound_play)
			playsound(src, movement_sound, vol = 20, sound_range = 30)
			move_next_sound_play = world.time + 15

/obj/vehicle/motorbike/green
	name = "\improper Dirtbike"
	icon_state = "motorbike_green"

/obj/vehicle/motorbike/red
	name = "\improper Dirtbike"
	icon_state = "motorbike_red"

/obj/vehicle/motorbike/grey
	name = "\improper Dirtbike"
	icon_state = "motorbike_grey"

/obj/vehicle/motorbike/black
	name = "\improper Dirtbike"
	icon_state = "motorbike_black"
