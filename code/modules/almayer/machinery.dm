//-----USS Almayer Machinery file -----//
// Put any new machines in here before map is released and everything moved to their proper positions.

/obj/structure/machinery/prop/almayer
	name = "GENERIC USS ALMAYER PROP"
	desc = "THIS SHOULDN'T BE VISIBLE, AHELP 'ART-P01' IF SEEN IN ROUND WITH LOCATION"

/obj/structure/machinery/prop/almayer/hangar/dropship_part_fabricator

/obj/structure/machinery/prop/almayer/computer/PC
	name = "personal desktop"
	desc = "A small computer hooked up into the ship's computer network."
	icon_state = "terminal1"

/obj/structure/machinery/prop/almayer/computer
	name = "systems computer"
	desc = "A small computer hooked up into the ship's systems."

	density = FALSE
	anchored = TRUE
	use_power = USE_POWER_IDLE
	idle_power_usage = 20

	icon = 'icons/obj/structures/machinery/computer.dmi'
	icon_state = "terminal"

/obj/structure/machinery/prop/almayer/computer/ex_act(severity)
	switch(severity)
		if(0 to EXPLOSION_THRESHOLD_LOW)
			if (prob(25))
				set_broken()
		if(EXPLOSION_THRESHOLD_LOW to EXPLOSION_THRESHOLD_MEDIUM)
			if (prob(25))
				deconstruct(FALSE)
				return
			if (prob(50))
				set_broken()
		if(EXPLOSION_THRESHOLD_MEDIUM to INFINITY)
			deconstruct(FALSE)
			return
		else
			return

/obj/structure/machinery/prop/almayer/computer/proc/set_broken()
	stat |= BROKEN
	update_icon()

/obj/structure/machinery/prop/almayer/computer/update_icon()
	..()
	icon_state = initial(icon_state)
	if(stat & BROKEN)
		icon_state += "b"
	if(stat & NOPOWER)
		icon_state = initial(icon_state)
		icon_state += "0"

/obj/structure/machinery/prop/almayer/computer/NavCon
	name = "NavCon"
	desc = "Navigational console for plotting course and heading of the ship. Since the AI calculates all long-range navigation, this is only used for in-system course corrections and orbital maneuvers. Don't touch it!"

	icon_state = "retro"

/obj/structure/machinery/prop/almayer/computer/NavCon2
	name = "NavCon 2"
	desc = "Navigational console for plotting course and heading of the ship. Since the AI calculates all long-range navigation, this is only used for in-system course corrections and orbital maneuvers. Don't touch it!"

	icon = 'icons/obj/structures/machinery/computer.dmi'
	icon_state = "retro2"

/obj/structure/machinery/prop/almayer/CICmap
	name = "map table"
	desc = "A table that displays a map of the current operation location."
	icon = 'icons/obj/structures/machinery/computer.dmi'
	icon_state = "maptable"
	anchored = TRUE
	use_power = USE_POWER_IDLE
	density = TRUE
	idle_power_usage = 2
	var/minimap_flag = MINIMAP_FLAG_USCM
	var/drawing = TRUE

/obj/structure/machinery/prop/almayer/CICmap/Initialize(mapload, ...)
	. = ..()
	AddComponent(/datum/component/tacmap, has_drawing_tools=drawing, minimap_flag=minimap_flag, has_update=drawing, drawing=drawing)

/obj/structure/machinery/prop/almayer/CICmap/Destroy()
	return ..()

/obj/structure/machinery/prop/almayer/CICmap/attack_hand(mob/user)
	. = ..()
	if(.)
		return
	if(interact_checks(user))
		return TRUE

	if(locate(/atom/movable/screen/minimap) in user.client.screen) //This seems like the most effective way to do this without some wacky code
		to_chat(user, SPAN_WARNING("You already have a minimap open!"))
		return
	var/datum/component/tacmap/tacmap_component = GetComponent(/datum/component/tacmap)
	tacmap_component.show_tacmap(user)
	RegisterSignal(user, COMSIG_MOVABLE_MOVED, PROC_REF(on_move), user)

///Returns true if something prevents the user from interacting with this. used mainly with the drawtable
/obj/structure/machinery/prop/almayer/CICmap/proc/interact_checks(mob/user)
	if(!user.client)
		return TRUE

/obj/structure/machinery/prop/almayer/CICmap/on_unset_interaction(mob/user)
	. = ..()
	var/datum/component/tacmap/tacmap_component = GetComponent(/datum/component/tacmap)
	tacmap_component.on_unset_interaction(user)

//Bugfix to handle cases for ghosts/observers that dont automatically close uis on move.
/obj/structure/machinery/prop/almayer/CICmap/proc/on_move(mob/source, oldloc)
	SIGNAL_HANDLER
	if(Adjacent(source))
		return
	on_unset_interaction(source)
	UnregisterSignal(source, COMSIG_MOVABLE_MOVED)

/obj/structure/machinery/prop/almayer/CICmap/computer
	name = "map terminal"
	desc = "A terminal that displays a map of the current operation location."
	icon = 'icons/obj/vehicles/interiors/arc.dmi'
	icon_state = "cicmap_computer"
	density = FALSE

/obj/structure/machinery/prop/almayer/CICmap/upp
	minimap_flag = MINIMAP_FLAG_UPP

/obj/structure/machinery/prop/almayer/CICmap/clf
	minimap_flag = MINIMAP_FLAG_CLF

/obj/structure/machinery/prop/almayer/CICmap/pmc
	minimap_flag = MINIMAP_FLAG_PMC

/// A placeable surface (attackby()/auto_align()) that also shows the tacmap when interacted with, via the same tacmap component every other CICmap subtype uses.
/obj/structure/machinery/prop/almayer/CICmap/table
	name = "map table"
	desc = "A large flat map table used for planning operations. It's large enough it can even be used as a proper table."
	icon = 'icons/obj/structures/props/almayer/almayer_props96.dmi'
	icon_state = "maptable"
	layer = TABLE_LAYER
	light_system = STATIC_LIGHT
	light_color = "#DAE2FF"
	light_power = 1
	light_range = 2.5
	light_pixel_x = 16
	light_pixel_y = 32
	bound_width = 64
	bound_height = 96

/obj/structure/machinery/prop/almayer/CICmap/table/attackby(obj/item/attacking_item, mob/user, click_data)
	if(!user.drop_inv_item_to_loc(attacking_item, loc))
		return

	auto_align(attacking_item, click_data)
	user.next_move = world.time + 2
	return TRUE

/// Places a dropped item where it was actually clicked on the table's sprite, matching the same click-to-place idiom code/game/objects/structures/surface.dm already uses.
/obj/structure/machinery/prop/almayer/CICmap/table/proc/auto_align(obj/item/new_item, click_data)
	if(!new_item.center_of_mass) // Clothing, material stacks, generally items with large sprites where exact placement would be unhandy.
		new_item.pixel_x = rand(-new_item.randpixel, new_item.randpixel)
		new_item.pixel_y = rand(-new_item.randpixel, new_item.randpixel)
		new_item.pixel_z = 0
		return

	if(!click_data)
		return

	if(!click_data[ICON_X] || !click_data[ICON_Y])
		return

	// Calculation to apply new pixelshift.
	var/mouse_x = text2num(click_data[ICON_X])-1 // Ranging from 0 to 31
	var/mouse_y = text2num(click_data[ICON_Y])-1

	var/cell_x = clamp(floor(mouse_x/CELLSIZE), 0, CELLS-1) // Ranging from 0 to CELLS-1
	var/cell_y = clamp(floor(mouse_y/CELLSIZE), 0, CELLS-1)

	var/list/center = cached_key_number_decode(new_item.center_of_mass)

	new_item.pixel_x = (CELLSIZE * (cell_x + 0.5)) - center["x"]
	new_item.pixel_y = (CELLSIZE * (cell_y + 0.5)) - center["y"]
	new_item.pixel_z = 0

/obj/structure/machinery/prop/almayer/CICmap/table/update_icon()
	..()

	overlays.Cut()

	if(!(stat & NOPOWER))
		var/image/source_image = image(src.icon, icon_state = "[icon_state]_e")
		overlays += emissive_appearance(source_image.icon, source_image.icon_state)
		overlays += mutable_appearance(source_image.icon, source_image.icon_state)
		light_power = 1
	else return

/obj/structure/machinery/prop/almayer/CICmap/table/clf
	minimap_flag = MINIMAP_FLAG_CLF

/obj/structure/machinery/prop/almayer/CICmap/table/upp
	minimap_flag = MINIMAP_FLAG_UPP

/obj/structure/machinery/prop/almayer/CICmap/table/pmc
	minimap_flag = MINIMAP_FLAG_PMC

/// A 32x32 single-tile piece of the same table, for map spots where the full 64x96 bound-box footprint doesn't fit cleanly.
/obj/structure/machinery/prop/almayer/CICmap/table/segment
	icon = 'icons/obj/structures/props/maptable.dmi'
	icon_state = "v_maptable1"
	bound_width = 32
	bound_height = 32
	light_pixel_x = 0
	light_pixel_y = 0

/obj/structure/machinery/prop/almayer/CICmap/table/segment/one
	icon_state = "v_maptable1"

/obj/structure/machinery/prop/almayer/CICmap/table/segment/two
	icon_state = "v_maptable2"

/obj/structure/machinery/prop/almayer/CICmap/table/segment/three
	icon_state = "v_maptable3"

/obj/structure/machinery/prop/almayer/CICmap/table/segment/four
	icon_state = "v_maptable4"

/obj/structure/machinery/prop/almayer/CICmap/table/segment/five
	icon_state = "v_maptable5"

/obj/structure/machinery/prop/almayer/CICmap/table/segment/six
	icon_state = "v_maptable6"

/obj/structure/machinery/prop/almayer/CICmap/table/horizontal
	icon_state = "h_maptable"
	bound_width = 96
	bound_height = 64
	light_pixel_x = 32
	light_pixel_y = 16

/obj/structure/machinery/prop/almayer/CICmap/table/horizontal/clf
	minimap_flag = MINIMAP_FLAG_CLF

/obj/structure/machinery/prop/almayer/CICmap/table/horizontal/upp
	minimap_flag = MINIMAP_FLAG_UPP

/obj/structure/machinery/prop/almayer/CICmap/table/horizontal/pmc
	minimap_flag = MINIMAP_FLAG_PMC

/obj/structure/machinery/prop/almayer/CICmap/table/horizontal/segment
	icon = 'icons/obj/structures/props/maptable.dmi'
	icon_state = "h_maptable1"
	bound_width = 32
	bound_height = 32
	light_pixel_x = 0
	light_pixel_y = 0

/obj/structure/machinery/prop/almayer/CICmap/table/horizontal/segment/one
	icon_state = "h_maptable1"

/obj/structure/machinery/prop/almayer/CICmap/table/horizontal/segment/two
	icon_state = "h_maptable2"

/obj/structure/machinery/prop/almayer/CICmap/table/horizontal/segment/three
	icon_state = "h_maptable3"

/obj/structure/machinery/prop/almayer/CICmap/table/horizontal/segment/four
	icon_state = "h_maptable4"

/obj/structure/machinery/prop/almayer/CICmap/table/horizontal/segment/five
	icon_state = "h_maptable5"

/obj/structure/machinery/prop/almayer/CICmap/table/horizontal/segment/six
	icon_state = "h_maptable6"

//Nonpower using props

/obj/structure/prop/almayer
	name = "GENERIC USS ALMAYER PROP"
	desc = "THIS SHOULDN'T BE VISIBLE, AHELP 'ART-P02' IF SEEN IN ROUND WITH LOCATION"
	density = TRUE
	anchored = TRUE

/obj/structure/prop/almayer/minigun_crate
	name = "30mm ammo crate"
	desc = "A crate full of 30mm bullets used on one of the weapon pod types for the dropship. Moving this will require some sort of lifter."
	icon = 'icons/obj/structures/props/dropship/dropship_ammo.dmi'
	icon_state = "30mm_crate"

/obj/structure/prop/almayer/computers
	var/hacked = FALSE

/obj/structure/prop/almayer/computers/update_icon()
	. = ..()

	overlays.Cut()

	if(hacked)
		overlays += "+hacked"

/obj/structure/prop/almayer/computers/mission_planning_system
	name = "\improper MPS IV computer"
	desc = "The Mission Planning System IV (MPS IV), an enhancement in mission planning and charting for dropship pilots across the USCM. Fully capable of customizing their flight paths and loadouts to suit their combat needs."
	icon = 'icons/obj/structures/props/almayer/almayer_props.dmi'
	icon_state = "mps"

/obj/structure/prop/almayer/computers/mapping_computer
	name = "\improper CMPS II computer"
	desc = "The Common Mapping Production System version II allows for sensory input from satellites and ship systems to derive planetary maps in a standardized fashion for all USCM pilots."
	icon = 'icons/obj/structures/props/almayer/almayer_props.dmi'
	icon_state = "mapping_comp"

/obj/structure/prop/almayer/computers/sensor_computer1
	name = "sensor computer"
	desc = "The IBM series 10 computer retrofitted to work as a sensor computer for the ship. While somewhat dated it still serves its purpose."
	icon = 'icons/obj/structures/props/almayer/almayer_props.dmi'
	icon_state = "sensor_comp1"

/obj/structure/prop/almayer/computers/sensor_computer2
	name = "sensor computer"
	desc = "The IBM series 10 computer retrofitted to work as a sensor computer for the ship. While somewhat dated it still serves its purpose."
	icon = 'icons/obj/structures/props/almayer/almayer_props.dmi'
	icon_state = "sensor_comp2"

/obj/structure/prop/almayer/computers/sensor_computer3
	name = "sensor computer"
	desc = "The IBM series 10 computer retrofitted to work as a sensor computer for the ship. While somewhat dated it still serves its purpose."
	icon = 'icons/obj/structures/props/almayer/almayer_props.dmi'
	icon_state = "sensor_comp3"

/obj/structure/prop/almayer/missile_tube
	name = "\improper Mk 33 ASAT launcher system"
	desc = "Cold launch tubes that can fire a few varieties of missiles out of them, the most common being the ASAT-21 Rapier IV missile used against satellites and other spacecraft and the BGM-227 Sledgehammer missile which is used for ground attack."
	icon = 'icons/obj/structures/props/almayer/almayer_props96.dmi'
	icon_state = "missiletubenorth"
	bound_width = 32
	bound_height = 96
	unslashable = TRUE
	unacidable = TRUE

/obj/structure/prop/almayer/particle_cannon
	name = "\improper 75cm/140 Mark 74 General Atomics railgun"
	desc = "The Mark 74 Railgun is top of the line for space-based weaponry. Capable of firing a round with a diameter of 3/4ths of a meter at 24 kilometers per second. It also is capable of using a variety of round types which can be interchanged at any time with its newly designed feed system."
	icon = 'icons/obj/structures/machinery/artillery.dmi'
	icon_state = "1"
	unslashable = TRUE
	unacidable = TRUE

/obj/structure/prop/almayer/particle_cannon/corsat
	name = "\improper CORSAT-PROTO-QUANTUM-CALCULATOR"
	desc = ""

/obj/structure/prop/almayer/name_stencil
	name = "USS Almayer"
	desc = "The name of the ship stenciled on the hull."
	icon = 'icons/obj/structures/props/almayer/almayer_props64.dmi'
	icon_state = "almayer0"
	density = FALSE //dunno who would walk on it, but you know.
	unslashable = TRUE
	unacidable = TRUE

/obj/structure/prop/almayer/hangar_stencil
	name = "floor"
	desc = "A large number stenciled on the hangar floor used to designate which dropship it is."
	icon = 'icons/obj/structures/props/almayer/almayer_props96.dmi'
	icon_state = "dropship1"
	density = FALSE
	layer = ABOVE_TURF_LAYER


/obj/structure/prop/almayer/cannon_cables
	name = "\improper Cannon cables"
	desc = "Some large cables."
	icon = 'icons/obj/structures/props/almayer/almayer_props.dmi'
	icon_state = "cannon_cables"
	density = FALSE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	layer = LADDER_LAYER
	unslashable = TRUE
	unacidable = TRUE

/obj/structure/prop/almayer/cannon_cables/ex_act()
	return

/obj/structure/prop/almayer/cannon_cables/bullet_act()
	return


/obj/structure/prop/almayer/cannon_cable_connector
	name = "\improper Cannon cable connector"
	desc = "A connector for the large cannon cables."
	icon = 'icons/obj/structures/props/almayer/almayer_props.dmi'
	icon_state = "cannon_cable_connector"
	density = TRUE
	unslashable = TRUE
	unacidable = TRUE

/obj/structure/prop/almayer/cannon_cable_connector/ex_act()
	return

/obj/structure/prop/almayer/cannon_cable_connector/bullet_act()
	return








//------- Cryobag Recycler -------//
// Wanted to put this in, but since we still have extra time until tomorrow and this is really simple thing. It just recycles opened cryobags to make it nice-r for medics.
// Also the lack of sleep makes me keep typing cyro instead of cryo. FFS ~Art

/obj/structure/machinery/cryobag_recycler
	name = "cryogenic bag recycler"
	desc = "A small tomb like structure. Capable of taking in used and opened cryobags and refill the liner and attach new sealants."
	icon = 'icons/obj/structures/props/almayer/almayer_props.dmi'
	icon_state = "recycler"

	density = TRUE
	anchored = TRUE
	use_power = USE_POWER_IDLE
	idle_power_usage = 20

//What is this even doing? Why is it making a new item?
/obj/structure/machinery/cryobag_recycler/attackby(obj/item/W, mob/user) //Hope this works. Don't see why not.
	. = ..()
	if (istype(W, /obj/item))
		if(W.name == "used stasis bag") //possiblity for abuse, but fairly low considering its near impossible to rename something without VV
			var/obj/item/bodybag/cryobag/R = new /obj/item/bodybag/cryobag //lets give them the bag considering having it unfolded would be a pain in the ass.
			R.add_fingerprint(user)
			user.temp_drop_inv_item(W)
			qdel(W)
			user.put_in_hands(R)
			return TRUE
	. = ..()

/obj/structure/closet/basketball
	name = "athletic wardrobe"
	desc = "It's a storage unit for athletic wear."
	icon_state = "purple"
	icon_closed = "purple"
	icon_opened = "purple_open"

/obj/structure/closet/basketball/Initialize()
	. = ..()
	new /obj/item/clothing/under/shorts/grey(src)
	new /obj/item/clothing/under/shorts/black(src)
	new /obj/item/clothing/under/shorts/red(src)
	new /obj/item/clothing/under/shorts/blue(src)
	new /obj/item/clothing/under/shorts/green(src)
