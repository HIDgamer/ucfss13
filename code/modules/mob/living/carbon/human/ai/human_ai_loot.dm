/// How many spare magazines for the gun in hand the body carries
/datum/human_ai_brain/proc/loot_spare_mags()
	var/obj/item/weapon/gun/held = peek_gun()
	if(!held)
		return 0
	var/datum/human_ai_gun_appraisal/appraisal = get_human_ai_gun_appraisal(held)
	var/count = 0
	for(var/obj/item/ammo_magazine/mag in body.get_contents())
		if(mag.current_rounds > 0 && ammo_fits_gun(mag, held, appraisal))
			count++
	return count

/// Whether the body has a gun in hand or on it that it can fire or reload
/datum/human_ai_brain/proc/has_usable_gun()
	if(peek_gun())
		return TRUE
	for(var/obj/item/weapon/gun/candidate in body.get_contents())
		if(get_human_ai_gun_appraisal(candidate).feed == HAI_FEED_NONE)
			continue
		if(weapon_state(candidate) != HAI_WEAPON_EMPTY || has_spare_ammo(candidate))
			return TRUE
	return FALSE

/// Whether the loose item is something this brain is short of: a gun when it has none, ammo for the gun in hand, a crowbar, the tools to hack a door, medical supplies or a grenade
/datum/human_ai_brain/proc/loot_wanted(obj/item/thing)
	if(QDELETED(thing) || thing.anchored || (thing.flags_item & (NODROP|ITEM_ABSTRACT|DELONDROP)))
		return FALSE
	if(istype(thing, /obj/item/weapon/gun))
		var/obj/item/weapon/gun/gun = thing
		if(has_usable_gun() || gun_rounds(gun) <= 0)
			return FALSE
		return get_human_ai_gun_appraisal(gun).feed != HAI_FEED_NONE && (!lethal_forbidden() || gun_is_nonlethal(gun))
	if(istype(thing, /obj/item/ammo_magazine))
		var/obj/item/ammo_magazine/mag = thing
		var/obj/item/weapon/gun/held = peek_gun()
		return held && mag.current_rounds > 0 && ammo_fits_gun(mag, held, get_human_ai_gun_appraisal(held)) && loot_spare_mags() < 4
	if(istype(thing, /obj/item/clothing/suit/armor) || istype(thing, /obj/item/clothing/suit/storage/marine))
		return !body.wear_suit
	if(istype(thing, /obj/item/restraint/handcuffs))
		return !find_cuffs()
	if(HAS_TRAIT(thing, TRAIT_TOOL_CROWBAR))
		return !find_crowbar()
	if(can_hack_doors())
		if(HAS_TRAIT(thing, TRAIT_TOOL_SCREWDRIVER))
			return !find_tool(TRAIT_TOOL_SCREWDRIVER)
		if(HAS_TRAIT(thing, TRAIT_TOOL_WIRECUTTERS))
			return !find_tool(TRAIT_TOOL_WIRECUTTERS)
	var/medical = human_ai_medical_kind(thing)
	if(medical)
		return length(medical_supplies()[medical]) < 3
	if(istype(thing, /obj/item/explosive/grenade))
		var/grenade_kind = human_ai_grenade_kind(thing)
		return grenade_kind != HAI_GRENADE_NONE && !find_grenade(grenade_kind)
	return FALSE

/// The closest loose item worth picking up that the brain can see, null when there is none. Looks only now and then.
/datum/human_ai_brain/proc/find_loot()
	var/obj/item/kept = loot_ref?.resolve()
	if(kept && !QDELETED(kept) && isturf(kept.loc) && get_dist(body, kept) <= HAI_LOOT_RANGE + 2 && loot_wanted(kept))
		return kept
	loot_ref = null
	var/obj/item/closest
	var/closest_distance = INFINITY
	for(var/obj/item/thing in view(HAI_LOOT_RANGE, body))
		if(!isturf(thing.loc))
			continue
		var/distance = get_dist(body, thing)
		if(distance < closest_distance && loot_wanted(thing))
			closest = thing
			closest_distance = distance
	if(!closest)
		next_loot_time = world.time + HAI_LOOT_GAP
		return null
	loot_ref = WEAKREF(closest)
	return closest

/// Picks the item up: guns stay in the hand, everything else is put away. True when it was picked up.
/datum/human_ai_brain/proc/pick_up(obj/item/thing)
	if(QDELETED(thing) || !isturf(thing.loc))
		return FALSE
	loot_ref = null
	next_loot_time = world.time + HAI_LOOT_GAP
	body.face_atom(thing)
	if(istype(thing, /obj/item/clothing/suit))
		// Armor is put on and not carried
		if(!body.equip_to_slot_if_possible(thing, WEAR_JACKET))
			loot_count += 3
			return FALSE
		loot_count++
		log_decision("put on [thing]")
		return TRUE
	var/is_gun = istype(thing, /obj/item/weapon/gun)
	if(!body.put_in_hands(thing, FALSE))
		// Both hands are busy, which counts against what it may still try
		loot_count += 3
		return FALSE
	loot_count++
	if(!is_gun)
		stow_item(thing)
	log_decision("picked up [thing]")
	return TRUE

/// An idle brain picks up what it is short of when it sees it lying about
/datum/human_ai_action/loot
	id = "loot"
	conflicts = HAI_LIMB_HANDS|HAI_LIMB_LEGS
	intents = list(HAI_INTENT_IDLE, HAI_INTENT_ALERT)

/datum/human_ai_action/loot/get_weight(datum/human_ai_brain/brain)
	if(brain.is_civilian() || brain.is_acting() || brain.get_target() || brain.current_order || brain.surrendered || brain.broken_kind)
		return 0
	if(brain.loot_count >= HAI_LOOT_LIMIT || world.time < brain.next_loot_time || brain.reload_phase != HAI_RELOAD_NONE)
		return 0
	return brain.find_loot() ? 24 : 0

/datum/human_ai_action/loot/trigger(datum/human_ai_brain/brain)
	var/obj/item/thing = brain.find_loot()
	if(!thing)
		return FALSE
	if(get_dist(brain.body, thing) > 1)
		return brain.move_to(thing, 1, FALSE)
	return brain.pick_up(thing)
