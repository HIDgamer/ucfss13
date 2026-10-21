/// How the brain regards a mob it sees
/datum/human_ai_brain/proc/get_disposition(mob/living/candidate)
	if(candidate == body)
		return HAI_DISP_FRIEND
	if(isxeno(candidate))
		var/mob/living/carbon/xenomorph/xeno = candidate
		var/datum/hive_status/hive = xeno.hive
		if(!hive)
			return HAI_DISP_HOSTILE
		if(world.time >= hive_cache_time)
			hive_cache = list()
			hive_cache_time = world.time + HAI_HIVE_CACHE_TIME
		var/cached = hive_cache[hive]
		if(isnull(cached))
			cached = hive.is_ally(body) ? HAI_DISP_FRIEND : HAI_DISP_HOSTILE
			hive_cache[hive] = cached
		return cached
	if(ishuman(candidate))
		var/mob/living/carbon/human/other = candidate
		if(iszombie(other))
			return HAI_DISP_HOSTILE
		// A grudge outranks being on the same side, that is how a friend who keeps shooting the brain becomes an enemy
		if(is_overridden_hostile(other))
			return HAI_DISP_HOSTILE
		if(other.faction == body.faction || LAZYISIN(body.faction_group, other.faction))
			return HAI_DISP_FRIEND
		if(aggression != HAI_AGGRO_OTHERS && human_ai_faction_relation(body.faction, other.faction) == HAI_REL_FRIENDLY)
			return HAI_DISP_FRIEND
		if(other.handcuffed)
			return HAI_DISP_NEUTRAL
		if(is_overridden_hostile(other))
			return HAI_DISP_HOSTILE
		if((other.ai_brain?.surrendered && personality.trait("mercy") >= 40) || accepts_surrender_of(other))
			return HAI_DISP_NEUTRAL
		if(faction_is_enemy(other.faction))
			return HAI_DISP_HOSTILE
		if(aggression != HAI_AGGRO_NONE && threatened_by(other))
			return HAI_DISP_WARY
		return HAI_DISP_NEUTRAL
	return HAI_DISP_NEUTRAL

/datum/human_ai_brain/proc/is_valid_target(mob/living/candidate)
	if(QDELETED(candidate) || candidate.stat == DEAD || candidate == body)
		return FALSE
	return get_disposition(candidate) >= HAI_DISP_HOSTILE

/// Drops the target when it is gone or dead
/datum/human_ai_brain/proc/validate_target()
	var/mob/living/target = get_target()
	if(!target)
		if(target_ref)
			set_target(null)
		return
	// A grudge that has run out leaves the target a friend again, and it is let go unless an order insists on it
	if(!QDELETED(target) && target.stat != DEAD && ishuman(target) && get_disposition(target) <= HAI_DISP_FRIEND && current_order?.forced_target() != target)
		set_target(null)
		return
	if(!QDELETED(target) && target.stat == DEAD)
		stress = max(0, stress - HAI_KILL_RELIEF)
		announce_kill()
	if(QDELETED(target) || target.stat == DEAD || target.z != body.z)
		remove_contact(target)
		set_target(null)

/// The gun in hand, swapping hands to reach one in the other hand
/datum/human_ai_brain/proc/get_gun()
	var/obj/item/weapon/gun/gun = body.get_active_hand()
	if(istype(gun))
		return gun
	gun = body.get_inactive_hand()
	if(istype(gun))
		body.swap_hand()
		return gun
	return null

/datum/human_ai_brain/proc/gun_has_ammo(obj/item/weapon/gun/gun)
	return gun_rounds(gun) > 0

/datum/human_ai_brain/proc/melee_attack(atom/target)
	if(world.time <= body.next_move)
		return FALSE
	body.face_atom(target)
	if(role?.maintains)
		ready_fists()
	var/wanted_intent = istype(body.get_active_hand(), /obj/item/weapon/baton) ? INTENT_DISARM : INTENT_HARM
	if(body.a_intent != wanted_intent)
		body.a_intent_change(wanted_intent)
	body.next_move = world.time
	body.istate = 0
	body.click_adjacent(target, body.get_active_hand(), list())
	return TRUE
