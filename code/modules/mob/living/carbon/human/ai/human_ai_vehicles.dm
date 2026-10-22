/**
 * Vehicles belong to the side that drives them, or to the one an admin gave them to, and a unit fires on the vehicles of the sides it fights when it has no man to shoot at.
 * Armor shrugs off rifle rounds, so only a gun made for it, or a vehicle that has no armor to speak of, is worth the ammunition.
 */

/// The side the vehicle belongs to, the last one that drove it or the one it was given, nothing for a vehicle nobody has used
/obj/vehicle/multitile/proc/owner_faction()
	return vehicle_faction

/// Whether the vehicle belongs to a side this brain fights
/datum/human_ai_brain/proc/vehicle_is_enemy(obj/vehicle/multitile/vehicle)
	var/owner = vehicle.owner_faction()
	if(!owner || owner == body.faction || LAZYISIN(body.faction_group, owner))
		return FALSE
	if(human_ai_faction_relation(body.faction, owner) == HAI_REL_FRIENDLY)
		return FALSE
	return faction_is_enemy(owner)

/// Whether the gun is worth firing at the vehicle
/datum/human_ai_brain/proc/vehicle_worth_shooting(obj/item/weapon/gun/gun, obj/vehicle/multitile/vehicle)
	var/datum/human_ai_gun_appraisal/appraisal = get_human_ai_gun_appraisal(gun)
	if(appraisal.family == HAI_GUN_LAUNCHER || appraisal.family == HAI_GUN_HEAVY)
		return TRUE
	return !(vehicle.vehicle_flags & (VEHICLE_CLASS_MEDIUM|VEHICLE_CLASS_HEAVY))

/// Whether the vehicle can be made out from here, not hidden by a wall and not lost in the dark
/datum/human_ai_brain/proc/vehicle_in_sight(obj/vehicle/multitile/vehicle)
	var/turf/there = get_turf(vehicle)
	var/distance = get_dist(body, there)
	if(distance > sight_range() || distance > eye_reach() || wall_in_line(vehicle))
		return FALSE
	var/reach = body.see_in_dark
	if(has_night_vision())
		reach = max(reach, HAI_NIGHT_VISION_REACH)
	return distance <= reach || light_at(there) >= HAI_DARK_LIGHT

/// The nearest vehicle of a side it fights that it can see and has a gun for, looked for every little while
/datum/human_ai_brain/proc/find_enemy_vehicle()
	RETURN_TYPE(/obj/vehicle/multitile)
	var/obj/vehicle/multitile/kept = vehicle_ref?.resolve()
	if(world.time < next_vehicle_scan)
		return (kept && !QDELETED(kept) && kept.health > 0) ? kept : null
	next_vehicle_scan = world.time + HAI_VEHICLE_SCAN_GAP
	vehicle_ref = null
	if(!length(GLOB.all_multi_vehicles))
		return null
	var/obj/item/weapon/gun/gun = peek_gun()
	if(!gun)
		return null
	var/turf/here = get_turf(body)
	var/obj/vehicle/multitile/best
	var/best_distance = INFINITY
	for(var/obj/vehicle/multitile/vehicle as anything in GLOB.all_multi_vehicles)
		if(QDELETED(vehicle) || vehicle.health <= 0 || vehicle.z != here.z)
			continue
		var/distance = get_dist(body, vehicle)
		if(distance >= best_distance || distance > shooting_range(gun))
			continue
		if(!vehicle_is_enemy(vehicle) || !vehicle_worth_shooting(gun, vehicle) || !vehicle_in_sight(vehicle))
			continue
		best = vehicle
		best_distance = distance
	vehicle_ref = best ? WEAKREF(best) : null
	return best

/// Fires on an enemy vehicle in sight when there is no man to fire on
/datum/human_ai_action/attack_vehicle
	id = "attack_vehicle"
	conflicts = HAI_LIMB_HANDS
	intents = list(HAI_INTENT_IDLE, HAI_INTENT_ALERT, HAI_INTENT_INVESTIGATE, HAI_INTENT_ENGAGE, HAI_INTENT_ADVANCE, HAI_INTENT_HOLD)

/datum/human_ai_action/attack_vehicle/get_weight(datum/human_ai_brain/brain)
	if(brain.is_civilian() || brain.role?.passive || brain.role?.maintains || brain.surrendered || brain.broken_kind || brain.current_order?.hard)
		return 0
	if(brain.roe == HAI_ROE_WEAPONS_HOLD && world.time > brain.last_shot_at_time + 100)
		return 0
	// A man in sight comes first
	if(brain.get_target() && world.time <= brain.target_seen_time + 20)
		return 0
	if(brain.is_acting() || world.time < brain.hands_busy_until || brain.reload_phase != HAI_RELOAD_NONE || world.time < brain.reaction_until)
		return 0
	var/obj/vehicle/multitile/vehicle = brain.find_enemy_vehicle()
	if(!vehicle)
		return 0
	var/obj/item/weapon/gun/gun = brain.peek_gun()
	if(!gun || brain.gun_unusable(gun) || !brain.gun_can_shoot_now(gun) || world.time < brain.volley_pause_until)
		return 0
	if(brain.lethal_forbidden() && !brain.gun_is_nonlethal(gun))
		return 0
	return 54

/datum/human_ai_action/attack_vehicle/trigger(datum/human_ai_brain/brain)
	var/obj/vehicle/multitile/vehicle = brain.find_enemy_vehicle()
	var/obj/item/weapon/gun/gun = brain.get_gun()
	if(!vehicle || !gun)
		return FALSE
	if(brain.shoot(gun, vehicle))
		brain.vehicle_shots++
		return TRUE
	return FALSE

/// Gives a vehicle to a side, the side it fights for and the one whose rounds do not harm it
/client/proc/assign_vehicle_faction()
	set category = "Admin.Events"
	set name = "Assign Vehicle Faction"
	if(!check_rights(R_SPAWN))
		return

	var/list/named = list()
	for(var/obj/vehicle/multitile/vehicle as anything in GLOB.all_multi_vehicles)
		if(QDELETED(vehicle))
			continue
		var/label = "[vehicle.name] at [vehicle.x],[vehicle.y],[vehicle.z] ([vehicle.vehicle_faction || "nobody's"])"
		if(named[label])
			label = "[label] [REF(vehicle)]"
		named[label] = vehicle
	if(!length(named))
		to_chat(usr, SPAN_WARNING("There are no vehicles."))
		return
	var/picked = tgui_input_list(usr, "Which vehicle?", "Assign Vehicle Faction", named)
	if(!picked)
		return
	var/obj/vehicle/multitile/vehicle = named[picked]
	var/list/choices = list("Nobody's")
	choices += human_ai_known_factions()
	var/faction = tgui_input_list(usr, "Whose is it?", "Assign Vehicle Faction", choices, default = "Nobody's")
	if(!faction || QDELETED(vehicle))
		return
	vehicle.vehicle_faction = (faction == "Nobody's") ? "" : faction
	message_admins("[key_name_admin(usr)] gave [vehicle] to [faction] with the vehicle faction tool.")
