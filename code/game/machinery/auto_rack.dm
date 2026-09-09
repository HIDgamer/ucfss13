// Ported from Neroid-Sector/LV-254-2.0's /obj/structure/machinery/auto_rack - a physical
// grab-and-take weapon/ammo rack, distinct from the menu-driven cm_vending machines: one rack
// holds one stocked type, restocks itself automatically (up to a limited number of times before
// needing a budget card swipe), and can be locked to an access list.
//
// Each subtype's own icon_state (e.g. "mk1rack", "m39_magrack") is the base name only - never
// shown directly (that bare declared state is just what the map editor shows). update_icon()
// always overrides it at runtime to "[base]_[stocked count]" (0..max_stored) or "[base]_restock"
// while mid-restock, matching the real per-weapon states already present in
// icons/obj/structures/machinery/vending.dmi (confirmed directly in the DMI catalog - no new art
// needed). auto_rack_opening/closing/locked are separate shared overlay states, not per-weapon.

/obj/item/reqcard
	name = "military budget authorization card"
	desc = "A card authorizing an automated armaments rack to draw down its resupply budget and restock."
	icon = 'icons/obj/items/card.dmi'
	icon_state = "centcom_old"
	w_class = SIZE_TINY

/obj/structure/machinery/auto_rack
	name = "ColMarTech Automated Armaments Storage Carousel"
	desc = "The ARMAT brand weapons rack has deceptively small storage, but automatically cycles to a fully stocked shelf once the current one is depleted - until its resupply budget runs dry."
	icon = 'icons/obj/structures/machinery/vending.dmi'
	icon_state = "mk1rack" // overridden per-subtype; see update_icon()
	density = TRUE
	anchored = TRUE
	use_power = USE_POWER_IDLE
	req_access = list()
	req_one_access = list()
	var/locked = FALSE
	var/working = FALSE
	/// Type of weapon/ammo this specific rack stocks - set per subtype.
	var/stocked_weapon = null
	var/max_stored = 4
	var/initial_stored = 0
	var/max_restocks = 5
	var/remaining_restocks = 5
	var/restock_cost = 10000
	var/damage = 500
	var/penetration = 5000
	var/list/target_limbs = list("l_arm", "r_arm")

/obj/structure/machinery/auto_rack/Initialize(mapload)
	. = ..()
	update_icon()
	restock(initial_stored || max_stored)

/obj/structure/machinery/auto_rack/update_icon()
	var/base = initial(icon_state)
	icon_state = working ? "[base]_restock" : "[base]_[min(contents.len, max_stored)]"
	overlays.Cut()
	if(locked)
		overlays += "auto_rack_locked"

/obj/structure/machinery/auto_rack/proc/restock(amount = max_stored)
	var/to_add = min(amount, max_stored - contents.len)
	for(var/i in 1 to to_add)
		new stocked_weapon(src)
	update_icon()

/obj/structure/machinery/auto_rack/attackby(obj/item/W, mob/user)
	if(istype(W, /obj/item/card/id))
		if(!allowed(user))
			to_chat(user, SPAN_WARNING("Access denied."))
			return
		locked = !locked
		playsound(src, locked ? 'sound/machines/lockenable.ogg' : 'sound/machines/lockreset.ogg', 25, TRUE)
		to_chat(user, SPAN_NOTICE("You [locked ? "lock" : "unlock"] [src]."))
		update_icon()
		return
	if(istype(W, /obj/item/reqcard))
		if(remaining_restocks >= max_restocks)
			to_chat(user, SPAN_WARNING("[src]'s supply budget hasn't been depleted yet."))
			return
		remaining_restocks = max_restocks
		playsound(src, 'sound/machines/chime.ogg', 25)
		to_chat(user, SPAN_NOTICE("You re-authorize [src]'s supply budget."))
		return
	if(locked)
		to_chat(user, SPAN_WARNING("[src] is locked."))
		return
	if(!istype(W, stocked_weapon))
		return
	if(contents.len >= max_stored)
		to_chat(user, SPAN_WARNING("[src] is already fully stocked."))
		return
	user.drop_inv_item_to_loc(W, src)
	update_icon()

/obj/structure/machinery/auto_rack/attack_hand(mob/living/user)
	. = ..()
	if(.)
		return
	if(locked)
		to_chat(user, SPAN_WARNING("[src] is locked."))
		return
	if(working)
		// Caught mid-restock-cycle - a real, if rare, injury risk for grabbing at a moving rack.
		if(prob(60) && isliving(user))
			var/hit_zone = pick(target_limbs)
			user.apply_armoured_damage(damage, ARMOR_MELEE, BRUTE, hit_zone, penetration)
			user.visible_message(SPAN_HIGHDANGER("[user]'s arm is caught in [src]!"), SPAN_HIGHDANGER("Your arm is caught in [src]!"))
			user.emote("scream")
			playsound(src, 'sound/voice/human_male_pain_1.ogg', 50, TRUE)
			msg_admin_niche("[key_name(user)] caught their arm in [src] at [AREACOORD(src)].")
		return
	if(contents.len)
		var/obj/item/stocked_item = locate(stocked_weapon) in contents
		if(stocked_item)
			user.put_in_hands(stocked_item)
			playsound(src, "gunequip", 25, TRUE)
			update_icon()
		return
	if(remaining_restocks <= 0)
		to_chat(user, SPAN_WARNING("[src] requires supply budget re-allocation before it can restock."))
		return
	working = TRUE
	update_icon()
	playsound(src, 'sound/machines/weapon_rack_restock.mp3', 25, TRUE)
	addtimer(CALLBACK(src, PROC_REF(finish_restock)), 4 SECONDS)

/obj/structure/machinery/auto_rack/proc/finish_restock()
	working = FALSE
	remaining_restocks--
	restock()
