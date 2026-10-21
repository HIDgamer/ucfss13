/// A defibrillator on the body that has the charge for another shock and that the body is trained to work, null when it has none
/datum/human_ai_brain/proc/find_defibrillator()
	RETURN_TYPE(/obj/item/device/defibrillator)
	for(var/obj/item/device/defibrillator/defib in body.get_contents())
		if(istype(defib, /obj/item/device/defibrillator/synthetic) || !defib.dcell || defib.dcell.charge < defib.charge_cost)
			continue
		if(!defib.noskill && !skillcheck(body, defib.skill_to_check, defib.skill_level) && (!defib.skill_to_check_alt || !skillcheck(body, defib.skill_to_check_alt, defib.skill_level_alt)))
			continue
		return defib
	return null

/// How the dead body would be doing after a shock: the shock mends a set amount of each kind of damage and all the oxygen loss, and the heart only takes if the body ends up above the point of death
/datum/human_ai_brain/proc/defib_outlook(mob/living/carbon/human/corpse, obj/item/device/defibrillator/defib)
	return corpse.health + min(corpse.getBruteLoss(), defib.damage_heal_threshold) + min(corpse.getFireLoss(), defib.damage_heal_threshold) + min(corpse.getToxLoss(), defib.damage_heal_threshold) + min(corpse.getCloneLoss(), defib.damage_heal_threshold) + corpse.getOxyLoss()

/// Armor over the chest stops the paddles, most of the time, so it has to come off first
/datum/human_ai_brain/proc/suit_blocks_defib(mob/living/carbon/human/corpse, obj/item/device/defibrillator/defib)
	if(!defib.blocked_by_suit || MODE_HAS_MODIFIER(/datum/gamemode_modifier/defib_past_armor))
		return FALSE
	return corpse.wear_suit && (istype(corpse.wear_suit, /obj/item/clothing/suit/armor) || istype(corpse.wear_suit, /obj/item/clothing/suit/storage/marine))

/// Whether the dead body is one this medic would try to bring back: a friend that can still be revived, not one that already failed to take a shock
/datum/human_ai_brain/proc/will_revive(mob/living/carbon/human/other)
	if(QDELETED(other) || other.stat != DEAD || other == body || issynth(other) || isyautja(other))
		return FALSE
	if(world.time < corpse_skips[REF(other)] || get_disposition(other) > HAI_DISP_FRIEND)
		return FALSE
	return other.is_revivable() && other.check_tod()

/// The nearest dead friend in sight that nobody else is working on, null when there is none or the medic has no defibrillator to bring one back with
/datum/human_ai_brain/proc/find_corpse()
	RETURN_TYPE(/mob/living/carbon/human)
	var/mob/living/carbon/human/kept = corpse_ref?.resolve()
	if(world.time < next_corpse_search)
		return (kept && will_revive(kept)) ? kept : null
	next_corpse_search = world.time + HAI_PATIENT_SEARCH_INTERVAL
	corpse_ref = null
	if(!find_defibrillator())
		return null
	var/mob/living/carbon/human/best
	var/best_distance = INFINITY
	for(var/mob/living/carbon/human/other in view(HAI_MEDIC_RANGE, body))
		if(!will_revive(other))
			continue
		var/list/datum/claim = GLOB.human_ai_patient_claims[REF(other)]
		if(claim && claim[1] != src && claim[2] > world.time && !QDELETED(claim[1]))
			continue
		var/distance = get_dist(body, other)
		if(distance < best_distance)
			best = other
			best_distance = distance
	if(best)
		corpse_ref = WEAKREF(best)
	return best

/**
 * Works on a dead friend within reach: armor comes off, a body too far gone to take a shock is mended first with whatever the medic carries, and
 * once it would end up above the point of death the paddles come out and the shock is tried. True while the medic is busy with it.
 */
/datum/human_ai_brain/proc/revive(mob/living/carbon/human/corpse)
	if(is_acting())
		return TRUE
	var/obj/item/device/defibrillator/defib = find_defibrillator()
	if(!defib)
		return FALSE
	GLOB.human_ai_patient_claims[REF(corpse)] = list(src, world.time + HAI_PATIENT_CLAIM_TIME)
	if(body.pulling)
		body.stop_pulling()
	if(suit_blocks_defib(corpse, defib))
		acting_until = world.time + 6 SECONDS
		INVOKE_ASYNC(src, PROC_REF(pull_off_suit), corpse)
		return TRUE
	if(defib_outlook(corpse, defib) <= HEALTH_THRESHOLD_DEAD + HAI_DEFIB_MARGIN)
		// Nothing to mend it with means nothing can be done for it
		return treat(corpse)
	if(!hand_item(defib))
		return FALSE
	body.face_atom(corpse)
	if(!defib.ready)
		defib.attack_self(body)
	if(!defib.ready)
		return FALSE
	acting_until = world.time + HAI_DEFIB_TIME
	utility_ref = WEAKREF(defib)
	defib_tries++
	INVOKE_ASYNC(src, PROC_REF(shock_corpse), defib, corpse)
	return TRUE

/datum/human_ai_brain/proc/pull_off_suit(mob/living/carbon/human/corpse)
	var/obj/item/suit = corpse.wear_suit
	body.face_atom(corpse)
	body.visible_message(SPAN_NOTICE("[body] starts unfastening the armor of [corpse]."), SPAN_NOTICE("You start unfastening the armor of [corpse] so the paddles can reach."))
	sleep(4 SECONDS)
	if(!QDELETED(body) && !QDELETED(corpse) && suit && !QDELETED(suit) && corpse.wear_suit == suit && body.stat == CONSCIOUS && body.Adjacent(corpse))
		corpse.drop_inv_item_on_ground(suit)
	acting_until = 0

/// Sets the paddles on the body, the shock itself takes as long as it takes anyone, and says what came of it
/datum/human_ai_brain/proc/shock_corpse(obj/item/device/defibrillator/defib, mob/living/carbon/human/corpse)
	if(QDELETED(defib) || QDELETED(corpse) || QDELETED(body))
		acting_until = 0
		return
	defib.attack(corpse, body)
	if(QDELETED(corpse) || corpse.stat != DEAD)
		revives++
		log_decision("brought [corpse] back with [defib]")
	else
		if(length(corpse_skips) >= 10)
			corpse_skips.Cut(1, 2)
		corpse_skips[REF(corpse)] = world.time + HAI_DEFIB_RETRY
		log_decision("the shock did not take on [corpse]")
	next_corpse_search = 0
	acting_until = 0

/// A medic with a defibrillator goes to a dead friend and brings them back once they are mended enough, when nothing is shooting at them
/datum/human_ai_action/revive_casualty
	id = "revive_casualty"
	conflicts = HAI_LIMB_HANDS|HAI_LIMB_LEGS
	intents = list(HAI_INTENT_IDLE, HAI_INTENT_ALERT, HAI_INTENT_ORDERED, HAI_INTENT_HOLD)

/datum/human_ai_action/revive_casualty/get_weight(datum/human_ai_brain/brain)
	if(!brain.is_medic() || brain.suppressed() || brain.get_target() || brain.reload_phase != HAI_RELOAD_NONE)
		return 0
	return brain.find_corpse() ? 75 : 0

/datum/human_ai_action/revive_casualty/trigger(datum/human_ai_brain/brain)
	var/mob/living/carbon/human/corpse = brain.find_corpse()
	if(!corpse)
		return FALSE
	if(get_dist(brain.body, corpse) > 1)
		return brain.move_to(corpse, 1, get_dist(brain.body, corpse) > HAI_SPRINT_MIN_DISTANCE)
	if(brain.revive(corpse))
		return TRUE
	// Nothing to be done for it with what the medic has, so leave it for a while instead of standing over it
	if(length(brain.corpse_skips) >= 10)
		brain.corpse_skips.Cut(1, 2)
	brain.corpse_skips[REF(corpse)] = world.time + HAI_DEFIB_RETRY
	brain.next_corpse_search = 0
	return FALSE
