/// Every living human piloted by a brain
GLOBAL_LIST_EMPTY(ai_human_list)

/// Puts a brain in charge of a clientless human, false if it is not eligible or the population cap is met
/proc/attach_human_ai(mob/living/carbon/human/human, personality_id = "neutral")
	if(!human || QDELETED(human) || human.client || human.ai_brain || human.stat == DEAD)
		return FALSE
	if(iszombie(human) || human.zombie_ai_controller)
		return FALSE
	if(!SShuman_ai.has_room())
		return FALSE

	human.forget_human_ai()
	var/datum/human_ai_brain/brain = new(human, personality_id)
	human.ai_brain = brain
	human.is_human_ai_controlled = TRUE
	human.was_human_ai_spawned = TRUE
	GLOB.ai_human_list += human
	SSspatial_grid.track(human, SPATIAL_GRID_TRACK_HUMAN_AI)
	brain.roe = human_ai_default_roe(human.faction)
	brain.home_turf = get_turf(human)
	brain.RegisterSignal(human, COMSIG_HUMAN_BULLET_ACT, TYPE_PROC_REF(/datum/human_ai_brain, signal_bullet_act))
	brain.RegisterSignal(human, COMSIG_HUMAN_TAKE_DAMAGE, TYPE_PROC_REF(/datum/human_ai_brain, signal_take_damage))
	brain.issue_hack_tools()
	brain.start()
	brain.log_decision("attached ([brain.personality.id])")
	return TRUE

/// Takes the brain off a human, the body itself is left as it is
/proc/detach_human_ai(mob/living/carbon/human/human, reason = HAI_STOP_DETACHED)
	var/datum/human_ai_brain/brain = human?.ai_brain
	if(!brain)
		return FALSE
	if(reason == HAI_STOP_DEAD)
		human.remember_human_ai(brain.revival_memory())
	brain.wind_down(reason)
	human.ai_brain = null
	human.is_human_ai_controlled = FALSE
	GLOB.ai_human_list -= human
	SSspatial_grid.untrack(human, SPATIAL_GRID_TRACK_HUMAN_AI)
	brain.UnregisterSignal(human, list(COMSIG_HUMAN_BULLET_ACT, COMSIG_HUMAN_TAKE_DAMAGE))
	qdel(brain)
	return TRUE

/// Puts a brain back after the player who was piloting an AI spawned body leaves it
/proc/reattach_human_ai_on_disconnect(mob/living/carbon/human/human)
	if(!human || !human.was_human_ai_spawned || human.ai_brain)
		return FALSE
	if(human.client || human.stat == DEAD || QDELETED(human))
		return FALSE
	return attach_human_ai(human)

/client/proc/debug_attach_human_ai()
	set category = "Debug"
	set name = "Attach Human AI"

	var/mob/living/carbon/human/target = tgui_input_list(src, "Which human?", "Attach Human AI", GLOB.alive_human_list)
	if(!target)
		return
	var/personality = tgui_input_list(src, "Which personality?", "Attach Human AI", GLOB.human_ai_personalities)
	if(!personality)
		return
	if(attach_human_ai(target, personality))
		to_chat(usr, SPAN_NOTICE("AI attached to [target]."))
	else
		to_chat(usr, SPAN_WARNING("Attach failed: already AI controlled, has a client, dead, a zombie, or the population cap [SShuman_ai.max_total] is met."))
