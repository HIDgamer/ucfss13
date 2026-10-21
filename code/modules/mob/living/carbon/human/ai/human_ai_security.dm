/// Whether the ammunition stuns or bruises rather than kills
/proc/human_ai_ammo_nonlethal(ammo)
	if(!ammo)
		return FALSE
	var/text = ispath(ammo) ? "[ammo]" : "[ammo:type]"
	return findtext(text, "taser") || findtext(text, "rubber") || findtext(text, "beanbag")

/// True when what the gun fires next will not kill
/datum/human_ai_brain/proc/gun_is_nonlethal(obj/item/weapon/gun/gun)
	if(gun.in_chamber)
		return human_ai_ammo_nonlethal(gun.in_chamber.ammo)
	if(gun.current_mag)
		return human_ai_ammo_nonlethal(gun.current_mag.default_ammo)
	return human_ai_ammo_nonlethal(gun.ammo)

/// A security brain that would rather club a man with empty hands than shoot him
/datum/human_ai_brain/proc/baton_pressing(mob/living/target)
	if(role?.id != "security" || !ishuman(target) || get_dist(body, target) > HAI_BATON_RANGE)
		return FALSE
	if(!lethal_forbidden() && personality.trait("mercy") < 40)
		return FALSE
	var/mob/living/carbon/human/man = target
	if(istype(man.get_active_hand(), /obj/item/weapon/gun) || istype(man.get_inactive_hand(), /obj/item/weapon/gun))
		return FALSE
	return !!find_baton()

/datum/human_ai_brain/proc/lethal_forbidden()
	return roe == HAI_ROE_NONLETHAL_ONLY

/// A stun baton on the body with charge left
/datum/human_ai_brain/proc/find_baton()
	for(var/obj/item/weapon/baton/candidate in body.get_contents())
		if(candidate.bcell && candidate.bcell.charge > candidate.hitcost)
			return candidate
	return null

/// Switches the baton on if it is off, true when it is live
/datum/human_ai_brain/proc/ready_baton(obj/item/weapon/baton/baton)
	if(baton.status)
		return TRUE
	baton.attack_self(body)
	log_decision("[baton.status ? "switched on" : "could not switch on"] [baton.name]")
	return baton.status

/// Draws and arms a baton as the target comes close
/datum/human_ai_action/ready_baton
	id = "ready_baton"
	conflicts = HAI_LIMB_HANDS
	intents = list(HAI_INTENT_ENGAGE)

/datum/human_ai_action/ready_baton/get_weight(datum/human_ai_brain/brain)
	if(brain.role?.id != "security" || brain.reload_phase != HAI_RELOAD_NONE || brain.is_acting())
		return 0
	var/mob/living/target = brain.get_target()
	if(!target || get_dist(brain.body, target) > 3 || !ishuman(target))
		return 0
	var/obj/item/weapon/baton/baton = brain.find_baton()
	if(!baton)
		return 0
	if(baton == brain.body.get_active_hand() && baton.status)
		return 0
	var/obj/item/weapon/gun/gun = brain.peek_gun()
	if(gun && !brain.lethal_forbidden() && brain.personality.trait("mercy") < 40 && !brain.gun_unusable(gun))
		return 0
	return 72

/datum/human_ai_action/ready_baton/trigger(datum/human_ai_brain/brain)
	var/obj/item/weapon/baton/baton = brain.find_baton()
	if(!baton)
		return FALSE
	if(baton != brain.body.get_active_hand() && !brain.draw_melee_weapon(baton))
		return FALSE
	return brain.ready_baton(baton)

/// A human who is out of the fight and can be put in cuffs
/datum/human_ai_brain/proc/restraint_candidate(mob/living/carbon/human/other)
	if(other == body || other.stat == DEAD || other.handcuffed)
		return FALSE
	if(!other.ai_brain?.surrendered && !accepts_surrender_of(other) && other.stat == CONSCIOUS && !other.is_mob_incapacitated())
		return FALSE
	return TRUE

/// Whoever of the humans close by needs to be cuffed and can be reached
/datum/human_ai_brain/proc/find_prisoner()
	if(world.time < next_prisoner_search)
		var/mob/living/carbon/human/kept = prisoner_ref?.resolve()
		return (kept && !QDELETED(kept) && restraint_candidate(kept)) ? kept : null
	next_prisoner_search = world.time + HAI_PATIENT_SEARCH_INTERVAL
	var/mob/living/carbon/human/best
	var/best_distance = INFINITY
	for(var/mob/living/carbon/human/other in view(HAI_PRISONER_RANGE, body))
		if(!restraint_candidate(other) || (get_disposition(other) <= HAI_DISP_FRIEND && !other.ai_brain?.surrendered))
			continue
		var/list/datum/claim = GLOB.human_ai_patient_claims["cuff[REF(other)]"]
		if(claim && claim[1] != src && claim[2] > world.time && !QDELETED(claim[1]))
			continue
		var/distance = get_dist(body, other)
		if(distance < best_distance)
			best_distance = distance
			best = other
	prisoner_ref = best ? WEAKREF(best) : null
	if(best)
		GLOB.human_ai_patient_claims["cuff[REF(best)]"] = list(src, world.time + HAI_PATIENT_CLAIM_TIME)
	return best

/datum/human_ai_brain/proc/find_cuffs()
	for(var/obj/item/restraint/handcuffs/cuffs in body.get_contents())
		return cuffs
	return null

/// Puts a restraint on whoever has been put out of the fight
/datum/human_ai_action/restrain
	id = "restrain"
	conflicts = HAI_LIMB_HANDS|HAI_LIMB_LEGS
	intents = list(HAI_INTENT_IDLE, HAI_INTENT_ALERT, HAI_INTENT_ENGAGE, HAI_INTENT_ORDERED)

/datum/human_ai_action/restrain/get_weight(datum/human_ai_brain/brain)
	if(brain.is_civilian() || brain.reload_phase != HAI_RELOAD_NONE || !brain.find_cuffs())
		return 0
	// Guards take prisoners as a matter of course, anyone else carrying restraints does it only if they have the mercy for it
	var/guard = brain.role?.id == "security"
	if(!guard && brain.personality.trait("mercy") < HAI_CAPTIVE_MERCY)
		return 0
	if(brain.get_target() && !brain.spares_downed(brain.get_target()))
		return 0
	return brain.find_prisoner() ? (guard ? 78 : 56) : 0

/datum/human_ai_action/restrain/trigger(datum/human_ai_brain/brain)
	var/mob/living/carbon/human/prisoner = brain.find_prisoner()
	var/obj/item/restraint/handcuffs/cuffs = brain.find_cuffs()
	if(!prisoner || !cuffs)
		return FALSE
	if(get_dist(brain.body, prisoner) > 1)
		return brain.move_to(prisoner, 1, FALSE)
	if(brain.is_acting())
		return TRUE
	if(!brain.hand_item(cuffs))
		return FALSE
	if(!prisoner.hud_used)
		prisoner.create_hud()
	brain.body.face_atom(prisoner)
	brain.acting_until = world.time + cuffs.cuff_delay + 10
	brain.utility_ref = WEAKREF(cuffs)
	INVOKE_ASYNC(cuffs, TYPE_PROC_REF(/obj/item/restraint, attack), prisoner, brain.body)
	brain.prisoners++
	brain.captive_ref = WEAKREF(prisoner)
	brain.log_decision("cuffing [prisoner], hand [brain.body.get_active_hand()], adjacent [brain.body.Adjacent(prisoner)]")
	return TRUE

/// Skills a role needs to use its gear
/datum/human_ai_role/proc/equip_skills(mob/living/carbon/human/body)
	return

/datum/human_ai_role/security/equip_skills(mob/living/carbon/human/body)
	if(!body.skills)
		body.skills = new /datum/skills()
	if(body.skills.get_skill_level(SKILL_POLICE) < SKILL_POLICE_SKILLED)
		body.skills.set_skill(SKILL_POLICE, SKILL_POLICE_SKILLED)

/datum/human_ai_role/medic/equip_skills(mob/living/carbon/human/body)
	if(!body.skills)
		body.skills = new /datum/skills()
	if(body.skills.get_skill_level(SKILL_MEDICAL) < SKILL_MEDICAL_MEDIC)
		body.skills.set_skill(SKILL_MEDICAL, SKILL_MEDICAL_MEDIC)

/datum/human_ai_role/engineer/equip_skills(mob/living/carbon/human/body)
	if(!body.skills)
		body.skills = new /datum/skills()
	if(body.skills.get_skill_level(SKILL_ENGINEER) < SKILL_ENGINEER_ENGI)
		body.skills.set_skill(SKILL_ENGINEER, SKILL_ENGINEER_ENGI)
	if(body.skills.get_skill_level(SKILL_CONSTRUCTION) < SKILL_CONSTRUCTION_ENGI)
		body.skills.set_skill(SKILL_CONSTRUCTION, SKILL_CONSTRUCTION_ENGI)
