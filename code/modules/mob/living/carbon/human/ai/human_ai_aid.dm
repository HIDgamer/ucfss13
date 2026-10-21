/**
 * What a unit does about its own wounds and those of the men it fights beside: it sees to itself with what it carries before anything else, keeps
 * still while a broken bone is not in a splint because moving on it makes it bleed inside, finds cover when it is hurt and someone is shooting,
 * stays with its squad instead of drifting about, and a medic knows how every man of its squad is doing wherever he is.
 */

/// The places on the body a splint can go
GLOBAL_LIST_INIT(human_ai_splint_zones, list("l_arm", "r_arm", "l_leg", "r_leg", "l_hand", "r_hand", "l_foot", "r_foot", "chest", "groin", "head"))

/// The times each body was shocked back to life by an AI medic, by reference text to list(how many times, when it was last)
GLOBAL_LIST_EMPTY(human_ai_revive_log)

/// The limbs with a broken bone that has no splint on it
/datum/human_ai_brain/proc/broken_limbs()
	var/list/obj/limb/found = list()
	for(var/obj/limb/limb as anything in body.limbs)
		if(limb.is_broken() && !(limb.status & (LIMB_DESTROYED|LIMB_ROBOT|LIMB_SYNTHSKIN)))
			found += limb
	return found

/// How badly off the body is from 0 for sound to 1 for on the brink, a bone broken and not splinted counts for a good deal
/datum/human_ai_brain/proc/hurt_level()
	var/level = 1 - clamp(body.health / max(body.maxHealth, 1), 0, 1)
	if(length(broken_limbs()))
		level = max(level, 0.45)
	return level

/// Whether the body is wounded enough to see to before anything else
/datum/human_ai_brain/proc/is_hurt()
	return hurt_level() >= 1 - HAI_HURT_FRACTION

/**
 * Whether the body must keep still: any move on a broken bone that is not in a splint risks bleeding inside, so it waits for a splint, its own or a
 * medic's. Fire, a blast about to go off and being shot at where it stands are worse than that, and those it moves for.
 */
/datum/human_ai_brain/proc/must_hold_still()
	if(!length(broken_limbs()))
		return FALSE
	return !(body.on_fire || hazard_turf || suppressed())

/// Every other man of the squad this brain is in wherever he is, the AI squad's members, the ones it has lost if asked for and the marines of the squad the body is assigned to
/datum/human_ai_brain/proc/squad_mates(include_dead = FALSE)
	var/list/mob/living/carbon/human/mates = list()
	if(squad)
		for(var/datum/human_ai_brain/member as anything in squad.members)
			if(member != src && member.body && !QDELETED(member.body))
				mates |= member.body
		if(include_dead)
			for(var/datum/weakref/ref as anything in squad.fallen)
				var/mob/living/carbon/human/lost = ref.resolve()
				if(lost && !QDELETED(lost) && lost != body)
					mates |= lost
	var/datum/squad/assigned = body.assigned_squad
	if(assigned)
		for(var/mob/living/carbon/human/mate in assigned.marines_list)
			if(mate != body && !QDELETED(mate))
				mates |= mate
	return mates

/// Leaves the wounded man alone for a while, nothing leads to him
/datum/human_ai_brain/proc/skip_patient(mob/living/carbon/human/patient)
	if(length(patient_skips) >= 20)
		patient_skips.Cut(1, 2)
	patient_skips[REF(patient)] = world.time + HAI_PATIENT_SKIP
	next_patient_search = 0
	log_decision("cannot get to [patient]")

/// A soldier goes in with something to put on a wound, the way every marine has a first aid pouch, whatever it already carries is kept
/datum/human_ai_brain/proc/issue_first_aid()
	if(issynth(body) || is_civilian() || role?.maintains)
		return
	var/list/supplies = medical_supplies()
	if(!length(supplies[HAI_MED_BANDAGE]))
		give_kit_item(/obj/item/stack/medical/bruise_pack, 4)
	if(!length(supplies[HAI_MED_SALVE]))
		give_kit_item(/obj/item/stack/medical/ointment, 4)
	if(!length(supplies[HAI_MED_SPLINT]))
		give_kit_item(/obj/item/stack/medical/splint, 2)
	med_cache = null

/// Waits for a splint with a bone broken, putting one on itself when it can and lying down if not, and calling for a medic
/datum/human_ai_action/hold_still
	id = "hold_still"
	conflicts = HAI_LIMB_LEGS

/datum/human_ai_action/hold_still/get_weight(datum/human_ai_brain/brain)
	return brain.must_hold_still() ? 106 : 0

/datum/human_ai_action/hold_still/trigger(datum/human_ai_brain/brain)
	return brain.hold_still_step()

/datum/human_ai_brain/proc/hold_still_step()
	holds_still++
	if(is_acting())
		return TRUE
	if(!get_target() && treat(body, HAI_MED_SPLINT))
		return TRUE
	if(!get_target() && !body.buckled && body.body_position == STANDING_UP)
		body.set_resting(TRUE)
	express(HAI_EXPR_MEDIC)
	return TRUE

/// A wounded unit that is being shot at from somewhere it cannot see gets behind something before it does anything else
/datum/human_ai_action/shelter_wounded
	id = "shelter_wounded"
	conflicts = HAI_LIMB_LEGS
	intents = list(HAI_INTENT_IDLE, HAI_INTENT_ALERT)

/datum/human_ai_action/shelter_wounded/get_weight(datum/human_ai_brain/brain)
	if(!brain.cover_enabled || brain.get_target() || brain.is_acting() || brain.reload_phase != HAI_RELOAD_NONE || brain.current_order?.hard || brain.is_civilian())
		return 0
	if(!brain.is_hurt() || (world.time > brain.last_shot_at_time + 20 SECONDS && world.time > brain.alert_until))
		return 0
	var/turf/threat = brain.threat_turf()
	if(!threat || get_dist(brain.body, threat) <= 1 || brain.in_good_cover(threat))
		brain.clear_cover_goal()
		return 0
	return brain.cover_goal(threat) ? 44 : 0

/datum/human_ai_action/shelter_wounded/trigger(datum/human_ai_brain/brain)
	var/turf/goal = brain.cover_goal_turf
	if(!goal)
		return FALSE
	if(brain.body.loc == goal)
		brain.clear_cover_goal()
		return FALSE
	if(brain.move_to(goal, 0, get_dist(brain.body, goal) > HAI_SPRINT_MIN_DISTANCE))
		brain.cover_moves++
		return TRUE
	brain.clear_cover_goal()
	return FALSE

/**
 * Remembers what the body wears, for the time it is stripped of it: a medic takes the armor off to get the paddles at the chest and a looter takes
 * the rest, and the man who comes back to life wants it all back.
 */
/datum/human_ai_brain/proc/worn_gear()
	var/list/gear = list()
	for(var/list/entry in list(list(WEAR_JACKET, body.wear_suit), list(WEAR_HEAD, body.head), list(WEAR_BACK, body.back), list(WEAR_WAIST, body.belt), list(WEAR_HANDS, body.gloves), list(WEAR_FEET, body.shoes)))
		if(entry[2])
			gear += list(list(entry[1], WEAKREF(entry[2])))
	return gear

/// The next piece of the gear it wore that is lying where it can be fetched or is already on it, as list(slot, item), null when none is left to get
/datum/human_ai_brain/proc/regear_entry()
	for(var/list/entry as anything in regear_items.Copy())
		var/datum/weakref/ref = entry[2]
		var/obj/item/piece = ref.resolve()
		var/slot = entry[1]
		if(QDELETED(piece) || body.get_item_by_slot(slot))
			regear_items -= list(entry)
			continue
		if(piece.loc == body || (isturf(piece.loc) && piece.z == body.z && get_dist(body, piece) <= HAI_REGEAR_RANGE))
			return list(slot, piece)
	if(!length(regear_items))
		regear_items = null
	return null

/// Goes for a piece of what it used to wear and puts it on, true while it is at it
/datum/human_ai_brain/proc/regear_step()
	var/list/entry = regear_entry()
	if(!entry)
		return FALSE
	var/obj/item/piece = entry[2]
	if(isturf(piece.loc) && get_dist(body, piece) > 1)
		if(move_to(piece, 1, get_dist(body, piece) > HAI_SPRINT_MIN_DISTANCE))
			return TRUE
		if(move_state == HAI_MOVE_BLOCKED)
			next_regear_time = world.time + 20 SECONDS
		return FALSE
	body.face_atom(piece)
	if(body.equip_to_slot_if_possible(piece, entry[1]))
		regeared++
		log_decision("put [piece] back on")
		return TRUE
	next_regear_time = world.time + 20 SECONDS
	return FALSE

/// A man who was dead and is back goes and gets his armor and the rest of what he wore back on, before he does anything else that is not urgent
/datum/human_ai_action/regear
	id = "regear"
	conflicts = HAI_LIMB_HANDS|HAI_LIMB_LEGS
	intents = list(HAI_INTENT_IDLE, HAI_INTENT_ALERT, HAI_INTENT_HOLD)

/datum/human_ai_action/regear/get_weight(datum/human_ai_brain/brain)
	if(!length(brain.regear_items) || world.time < brain.next_regear_time || brain.get_target() || brain.suppressed() || brain.is_acting() || brain.surrendered || brain.broken_kind)
		return 0
	return brain.regear_entry() ? 66 : 0

/datum/human_ai_action/regear/trigger(datum/human_ai_brain/brain)
	return brain.regear_step()
