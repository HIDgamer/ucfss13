// Ported from Neroid-Sector/LV-254-2.0's pallets.dm, adapted to this codebase's own
// /obj/structure/largecrate idioms (crowbar-dismantle-to-parts_type, wrench anchor toggle,
// AddElement debris) rather than the source file's own standalone implementation.

/obj/structure/pallet
	name = "pallet"
	desc = "A sturdy wooden pallet for bulk storage."
	icon = 'icons/obj/structures/crates.dmi'
	icon_state = "pallet_0"
	density = FALSE
	anchored = FALSE
	var/parts_type = /obj/item/stack/sheet/wood
	var/unpacking_sound = 'sound/effects/woodhit.ogg'
	/// Item type this pallet accepts. Subtypes narrow this to whatever they're meant to hold.
	var/fill_type = /obj/item/storage/box
	var/max_stored = 18
	/// Past this many stored items the pallet is too heavy to move without a powerloader.
	var/heavy_threshold = 9
	var/heavy = FALSE

/obj/structure/pallet/add_debris_element()
	AddElement(/datum/element/debris, DEBRIS_WOOD, -10, 5)

/obj/structure/pallet/initialize_pass_flags(datum/pass_flags_container/PF)
	..()
	if(PF)
		PF.flags_can_pass_all = PASS_OVER|PASS_AROUND

/obj/structure/pallet/update_icon()
	icon_state = "pallet_[min(contents.len, 18)]"
	density = (contents.len > 0)
	var/was_heavy = heavy
	heavy = (contents.len > heavy_threshold)
	if(heavy && !was_heavy)
		anchored = TRUE
	else if(!heavy && was_heavy)
		anchored = FALSE

/obj/structure/pallet/proc/unpack()
	var/turf/current_turf = get_turf(src)
	playsound(src, unpacking_sound, 35)
	for(var/atom/movable/moving_atom as anything in contents)
		moving_atom.forceMove(current_turf)
	if(parts_type)
		new parts_type(current_turf, 2)
	qdel(src)

/obj/structure/pallet/attackby(obj/item/W, mob/user)
	if(HAS_TRAIT(W, TRAIT_TOOL_CROWBAR))
		if(heavy)
			to_chat(user, SPAN_WARNING("[src] is too full to dismantle - unload it first."))
			return
		unpack()
		user.visible_message(SPAN_NOTICE("[user] pries [src] apart."), SPAN_NOTICE("You pry [src] apart."))
		return
	if(HAS_TRAIT(W, TRAIT_TOOL_WRENCH))
		if(heavy)
			to_chat(user, SPAN_WARNING("[src] is too full to move by hand - unload it or use a powerloader."))
			return
		playsound(loc, 'sound/items/Ratchet.ogg', 25, TRUE)
		anchored = !anchored
		to_chat(user, SPAN_NOTICE("You [anchored ? "anchor" : "unanchor"] [src]."))
		return
	if(HAS_TRAIT(W, TRAIT_TOOL_PEN))
		var/newname = stripped_input(user, "What would you like to label this pallet?")
		if(!newname)
			return
		name = "pallet ([strip_html(newname)])"
		playsound(src, "paper_writing", 15, TRUE)
		return
	if(istype(W, fill_type))
		if(contents.len >= max_stored)
			to_chat(user, SPAN_WARNING("[src] is already fully loaded."))
			return
		user.drop_inv_item_to_loc(W, src)
		update_icon()
		return

/obj/structure/pallet/attack_hand(mob/user)
	. = ..()
	if(.)
		return
	if(contents.len)
		var/obj/item/top_item = locate(/obj/item) in contents
		if(top_item)
			user.put_in_hands(top_item)
			update_icon()

/obj/structure/pallet/ex_act(power)
	if(power >= EXPLOSION_THRESHOLD_VLOW)
		unpack()

/obj/structure/pallet/standard
	name = "pallet of supplies"
	fill_type = /obj/item/storage/box/wood

/obj/structure/pallet/standard/Initialize(mapload)
	. = ..()
	for(var/i in 1 to 6)
		new fill_type(src)
	update_icon()

/obj/structure/pallet/med
	name = "pallet of medical supplies"
	fill_type = /obj/item/storage/box/wood/med

/obj/structure/pallet/med/Initialize(mapload)
	. = ..()
	for(var/i in 1 to 6)
		new fill_type(src)
	update_icon()

/obj/structure/pallet/engi
	name = "pallet of engineering supplies"
	fill_type = /obj/item/storage/box/wood/engi

/obj/structure/pallet/engi/Initialize(mapload)
	. = ..()
	for(var/i in 1 to 6)
		new fill_type(src)
	update_icon()

/obj/structure/pallet/food
	name = "pallet of food supplies"
	fill_type = /obj/item/storage/box/wood/food

/obj/structure/pallet/food/Initialize(mapload)
	. = ..()
	for(var/i in 1 to 6)
		new fill_type(src)
	update_icon()

/obj/structure/pallet/weapon
	name = "pallet of weapon crates"
	fill_type = /obj/item/storage/box/wood/weapon

/obj/structure/pallet/weapon/Initialize(mapload)
	. = ..()
	for(var/i in 1 to 6)
		new fill_type(src)
	update_icon()

/obj/structure/pallet/ammo_mk1
	name = "pallet of MK1 HEAP magazine boxes"
	fill_type = /obj/item/ammo_magazine/rifle/m41aMK1/heap

/obj/structure/pallet/ammo_mk1/Initialize(mapload)
	. = ..()
	for(var/i in 1 to 12)
		new fill_type(src)
	update_icon()
