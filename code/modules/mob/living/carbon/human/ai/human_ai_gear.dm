/**
 * What a unit does with the lights, the goggles and the welding gear it wears. A unit in the dark puts on a lamp, the one in its helmet, on its gun, in its armor
 * or a flashlight in a pocket, and switches it off again when it leaves the place; with night vision goggles it uses those and no lamp, and switches them
 * off where it is bright. A unit told to keep its lights off, and a sniper left to itself, stays dark until it has something to look at. A welding mask,
 * goggles or visor is pulled down for welding and pushed up again when the welding is done, since a unit sees next to nothing through one.
 */

/// The brains with a lamp lit, which the server only lets so many have
GLOBAL_LIST_EMPTY(human_ai_lit_lamps)

/// Whether a lamp is lit
/proc/human_ai_lamp_on(atom/lamp)
	if(istype(lamp, /obj/item/device/flashlight))
		var/obj/item/device/flashlight/handheld = lamp
		return handheld.on
	return lamp.light_on

/// Every lamp the body has to switch, the ones that give least away first
/datum/human_ai_brain/proc/lamp_sources()
	var/list/found = list()
	var/obj/item/clothing/head/hat = body.head
	if(istype(hat, /obj/item/clothing/head/helmet/marine))
		var/obj/item/clothing/head/helmet/marine/helmet = hat
		for(var/obj/item/attachable/flashlight/mounted in helmet.pockets)
			found += mounted
		if(istype(helmet, /obj/item/clothing/head/helmet/marine/veteran/pmc/enclosed))
			found += helmet
	else if(istype(hat, /obj/item/clothing/head/hardhat))
		var/obj/item/clothing/head/hardhat/hardhat = hat
		if(hardhat.toggleable)
			found += hardhat
	var/obj/item/weapon/gun/gun = peek_gun()
	if(gun)
		var/obj/item/attachable/flashlight/rail = gun.attachments["rail"]
		if(istype(rail))
			found += rail
	var/obj/item/clothing/suit/storage/marine/armor = body.wear_suit
	if(istype(armor) && (armor.flags_marine_armor & ARMOR_LAMP_OVERLAY))
		found += armor
	for(var/obj/item/device/flashlight/handheld in list(body.l_hand, body.r_hand, body.belt, body.l_store, body.r_store))
		if(handheld.toggleable)
			found += handheld
	return found

/// Switches a lamp on or off, true when it is as wanted afterwards
/datum/human_ai_brain/proc/switch_lamp(atom/lamp, on)
	if(QDELETED(lamp))
		return FALSE
	if(human_ai_lamp_on(lamp) == on)
		return TRUE
	if(istype(lamp, /obj/item/device/flashlight))
		var/obj/item/device/flashlight/handheld = lamp
		handheld.attack_self(body)
	else
		lamp.turn_light(body, on)
	if(human_ai_lamp_on(lamp) != on)
		return FALSE
	gear_toggles++
	if(on)
		lamp_area = get_area(body)
		GLOB.human_ai_lit_lamps |= src
	else if(!lamp_lit(lamp_sources()))
		lamp_area = null
		GLOB.human_ai_lit_lamps -= src
	log_decision("[on ? "lit" : "put out"] [lamp]")
	return TRUE

/// The first lamp of the list that is lit
/datum/human_ai_brain/proc/lamp_lit(list/lamps)
	for(var/atom/lamp as anything in lamps)
		if(human_ai_lamp_on(lamp))
			return lamp
	return null

/// Whether the place is too dark to see in, with the lamps all out
/datum/human_ai_brain/proc/ambient_dark()
	var/turf/here = get_turf(body)
	return here && light_at(here) < HAI_LAMP_LIGHT

/// Whether a lamp is wanted: in the dark, in the place where it was put on it stays on, the lights are not kept off and a unit that works unseen has something to look at
/datum/human_ai_brain/proc/lamp_wanted(atom/lit)
	if(lights_out)
		return FALSE
	var/area/here_area = get_area(body)
	var/dark
	if(lit)
		// It lights its own tile, which says nothing about the dark, so the place it went on in is the dark one
		if(!lamp_area)
			lamp_area = here_area
		dark = lamp_area == here_area
	else
		dark = ambient_dark()
		// A new lamp is only lit while the server has room for it
		if(dark && length(GLOB.human_ai_lit_lamps) >= HAI_LAMP_CAP)
			return FALSE
	if(!dark)
		return FALSE
	if(role?.covert && intent != HAI_INTENT_INVESTIGATE && intent != HAI_INTENT_ENGAGE)
		return FALSE
	return TRUE

/// The night vision goggles on the unit's face
/datum/human_ai_brain/proc/night_glasses()
	RETURN_TYPE(/obj/item/clothing/glasses)
	var/obj/item/clothing/glasses/goggles = body.glasses
	if(istype(goggles) && goggles.toggleable && goggles.lighting_alpha < LIGHTING_PLANE_ALPHA_VISIBLE)
		return goggles
	return null

/// The welding mask, goggles or visor the unit has, null when it has none
/datum/human_ai_brain/proc/weld_gear()
	RETURN_TYPE(/obj/item)
	if(istype(body.head, /obj/item/clothing/head/welding))
		return body.head
	if(istype(body.glasses, /obj/item/clothing/glasses/welding))
		return body.glasses
	if(istype(body.head, /obj/item/clothing/head/helmet/marine))
		var/obj/item/clothing/head/helmet/marine/helmet = body.head
		for(var/obj/item/device/helmet_visor/welding_visor/visor in helmet.built_in_visors + helmet.inserted_visors)
			return visor
	return null

/// Whether the welding gear is down over the face
/datum/human_ai_brain/proc/weld_gear_down(obj/item/gear)
	if(istype(gear, /obj/item/clothing/head/welding))
		var/obj/item/clothing/head/welding/mask = gear
		return !mask.up
	if(istype(gear, /obj/item/clothing/glasses/welding))
		var/obj/item/clothing/glasses/welding/goggles = gear
		return goggles.active
	if(istype(body.head, /obj/item/clothing/head/helmet/marine))
		var/obj/item/clothing/head/helmet/marine/helmet = body.head
		return helmet.active_visor == gear
	return FALSE

/// Pulls the welding gear down or pushes it up, true when it is as wanted afterwards
/datum/human_ai_brain/proc/set_weld_gear(obj/item/gear, down)
	if(QDELETED(gear))
		return FALSE
	if(weld_gear_down(gear) == down)
		return TRUE
	var/mob/old_usr = usr
	usr = body
	if(istype(gear, /obj/item/clothing/head/welding))
		var/obj/item/clothing/head/welding/mask = gear
		mask.toggle()
	else if(istype(gear, /obj/item/clothing/glasses/welding))
		var/obj/item/clothing/glasses/welding/goggles = gear
		goggles.toggle()
	else if(istype(body.head, /obj/item/clothing/head/helmet/marine))
		var/obj/item/clothing/head/helmet/marine/helmet = body.head
		if(down)
			var/obj/item/device/helmet_visor/old = helmet.active_visor
			helmet.active_visor = gear
			if(old && old != gear)
				helmet.toggle_visor(body, old, TRUE)
			helmet.toggle_visor(body, null, TRUE)
		else
			helmet.active_visor = null
			helmet.toggle_visor(body, gear, TRUE)
	usr = old_usr
	eye_reach_time = -1
	if(weld_gear_down(gear) != down)
		return FALSE
	gear_toggles++
	log_decision("[down ? "pulled down" : "pushed up"] [gear]")
	return TRUE

/// Whether a welder is lit in a hand
/datum/human_ai_brain/proc/welding_now()
	for(var/obj/item/tool/weldingtool/welder in list(body.l_hand, body.r_hand))
		if(welder.welding)
			return TRUE
	return FALSE

/// Called before a welder is lit: the mask comes down and stays down while the welding goes on
/datum/human_ai_brain/proc/prepare_to_weld()
	weld_until = world.time + HAI_WELD_HOLD
	var/obj/item/gear = weld_gear()
	if(gear)
		set_weld_gear(gear, TRUE)

/**
 * What to do about the gear right now, if anything, as list(kind, item, on): the welding gear first, then the goggles and the lamps.
 * Looked at every couple of seconds.
 */
/datum/human_ai_brain/proc/plan_gear()
	var/obj/item/weld = weld_gear()
	if(weld)
		var/should_be_down = world.time < weld_until || welding_now()
		if(weld_gear_down(weld) != should_be_down)
			return list("weld", weld, should_be_down)
	var/list/lamps = lamp_sources()
	var/atom/lit = lamp_lit(lamps)
	var/obj/item/clothing/glasses/goggles = night_glasses()
	if(goggles)
		// The goggles do the seeing, a lamp only gives the man away
		if(lit)
			return list("lamp", lit, FALSE)
		var/turf/here = get_turf(body)
		if(!here)
			return null
		var/light = light_at(here)
		var/wanted = goggles.active ? (light < HAI_LIT_LIGHT) : (light < HAI_LAMP_LIGHT)
		if(goggles.active != wanted)
			return list("nvg", goggles, wanted)
		return null
	if(!length(lamps))
		return plan_flare()
	var/wanted = lamp_wanted(lit)
	if(wanted && !lit)
		return list("lamp", lamps[1], TRUE)
	if(!wanted && lit)
		return list("lamp", lit, FALSE)
	return null

/// Does what the plan says, true when something was done
/datum/human_ai_brain/proc/do_gear_job(list/job)
	var/obj/item/thing = job[2]
	if(QDELETED(thing))
		return FALSE
	switch(job[1])
		if("weld")
			return set_weld_gear(thing, job[3])
		if("lamp")
			return switch_lamp(thing, job[3])
		if("flare")
			return light_flare(thing)
		if("nvg")
			var/obj/item/clothing/glasses/goggles = thing
			if(goggles.active == job[3])
				return FALSE
			goggles.attack_self(body)
			if(goggles.active != job[3])
				return FALSE
			gear_toggles++
			vision_area = job[3] ? get_area(body) : null
			log_decision("[job[3] ? "switched on" : "switched off"] [goggles]")
			return TRUE
	return FALSE

/**
 * A unit with no lamp and no goggles in a place that is too dark lights a flare it carries, once, and leaves it where it stands so the light stays with the place. It does
 * not light one with another burning close by, nor when told to keep its lights off, nor a covert unit that has nothing to hunt.
 */
/datum/human_ai_brain/proc/plan_flare()
	if(lights_out || !ambient_dark() || length(GLOB.human_ai_lit_lamps) >= HAI_LAMP_CAP)
		return null
	if(role?.covert && intent != HAI_INTENT_INVESTIGATE && intent != HAI_INTENT_ENGAGE)
		return null
	for(var/obj/item/device/flashlight/flare/burning in range(HAI_FLARE_SPACING, get_turf(body)))
		if(burning.on)
			return null
	for(var/obj/item/device/flashlight/flare/flare in body.get_contents())
		if(!flare.on && !flare.burnt_out && flare.fuel > 0)
			return list("flare", flare, TRUE)
	return null

/// Pulls the cord of the flare and sets it down at the unit's feet, true when it is burning afterwards
/datum/human_ai_brain/proc/light_flare(obj/item/device/flashlight/flare/flare)
	if(QDELETED(flare) || flare.on)
		return FALSE
	take_out_of_holder(flare)
	if(flare.loc != body.loc)
		flare.forceMove(body.loc)
	flare.attack_self(body)
	if(body.throw_mode)
		body.toggle_throw_mode(THROW_MODE_OFF)
	if(!flare.on)
		return FALSE
	gear_toggles++
	log_decision("lit [flare] and set it down")
	return TRUE

/datum/human_ai_action/use_gear
	id = "use_gear"

/datum/human_ai_action/use_gear/get_weight(datum/human_ai_brain/brain)
	if(brain.surrendered || brain.broken_kind)
		return 0
	if(world.time >= brain.next_gear_check)
		brain.next_gear_check = world.time + HAI_GEAR_GAP
		brain.gear_job = brain.plan_gear()
	return brain.gear_job ? 90 : 0

/datum/human_ai_action/use_gear/trigger(datum/human_ai_brain/brain)
	var/list/job = brain.gear_job
	brain.gear_job = null
	if(!job)
		return FALSE
	// Pulling a mask up or down takes a hand, which is not taken from a gun being fired
	if(job[1] == "weld" && (brain.is_acting() || world.time < brain.hands_busy_until))
		brain.gear_job = job
		return FALSE
	return brain.do_gear_job(job)
