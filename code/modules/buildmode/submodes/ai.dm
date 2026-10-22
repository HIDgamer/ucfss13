/// What kind of AI a mob can be given: a human, a zombie or a xenomorph, null for a mob that has none to give
/proc/npc_ai_kind(mob/living/living)
	if(isxeno(living))
		return NPC_AI_XENO
	if(ishuman(living))
		return iszombie(living) ? NPC_AI_ZOMBIE : NPC_AI_HUMAN
	return null

/// Gives the mob the AI of its kind. Returns why it was refused, null when it has an AI now. The settings are for humans only, the others have one nature
/proc/npc_ai_give(mob/living/living, personality, role, faction)
	switch(npc_ai_kind(living))
		if(NPC_AI_HUMAN)
			var/mob/living/carbon/human/human = living
			return assign_human_ai(human, personality, role, faction)
		if(NPC_AI_ZOMBIE)
			var/mob/living/carbon/human/zombie = living
			if(zombie.client)
				return "[zombie] is played by [zombie.key], who has to leave the body first"
			if(zombie.zombie_ai_controller)
				return "[zombie] is already AI controlled"
			if(zombie.stat == DEAD)
				return "[zombie] is dead"
			return attach_zombie_ai(zombie) ? null : "the zombie population cap [GLOB.ai_zombie_max_pop] is met"
		if(NPC_AI_XENO)
			var/mob/living/carbon/xenomorph/xeno = living
			if(xeno.client)
				return "[xeno] is played by [xeno.key], who has to leave the body first"
			if(xeno.ai_controller)
				return "[xeno] is already AI controlled"
			if(xeno.stat == DEAD)
				return "[xeno] is dead"
			return attach_xeno_ai(xeno) ? null : "the cap for [xeno.caste_type] is met"
	return "[living] is not a kind of mob that has an AI"

/// Takes the AI off the mob and leaves it standing where it is. Returns whether it had one
/proc/npc_ai_take(mob/living/living)
	switch(npc_ai_kind(living))
		if(NPC_AI_HUMAN)
			return !!detach_human_ai(living)
		if(NPC_AI_ZOMBIE)
			return !!detach_zombie_ai(living)
		if(NPC_AI_XENO)
			return !!detach_xeno_ai(living)
	return FALSE

/**
 * The AI tool of build mode: it gives an AI to the mobs that are clicked, whatever kind they are as long as the kind has an AI, and takes it off again.
 * It is what the assign tool of the NPC command panel was, humans and also the zombies and the xenomorphs.
 */
/datum/buildmode_mode/ai
	key = "ai"
	icon_key = "outfit"
	help = "Left Mouse Button on a mob to give it an AI, humans, zombies and xenomorphs have one\n\
	Right Mouse Button on a mob to take its AI off and leave it standing there\n\
	Use the button of the mode to choose the nature, role kit and faction of the humans, the reach of a click and whether they are put in a squad. Zombies and xenomorphs have one nature."

	var/personality = "neutral"
	/// Null is the kit of their job
	var/role
	/// Null keeps theirs
	var/faction
	/// Tiles around the click that are given the AI too, 0 is only the mob that was clicked
	var/reach = 0
	var/squad = FALSE

/datum/buildmode_mode/ai/change_settings(client/c)
	var/chosen = tgui_input_list(c, "Which nature do the humans have?", "AI build mode", GLOB.human_ai_personalities, default = personality)
	if(!chosen)
		return
	personality = chosen
	var/list/role_choices = list("From their job")
	role_choices += GLOB.human_ai_roles
	chosen = tgui_input_list(c, "Which role kit?", "AI build mode", role_choices, default = role || "From their job")
	if(!chosen)
		return
	role = chosen == "From their job" ? null : chosen
	var/list/faction_choices = list("Keep theirs")
	faction_choices += human_ai_known_factions()
	chosen = tgui_input_list(c, "Which faction?", "AI build mode", faction_choices, default = faction || "Keep theirs")
	if(!chosen)
		return
	faction = chosen == "Keep theirs" ? null : chosen
	var/number = tgui_input_number(c, "How many tiles around the click are given an AI too? 0 is only the one clicked.", "AI build mode", reach, 10, 0)
	if(isnull(number))
		return
	reach = clamp(round(number), 0, 10)
	squad = tgui_alert(c, "Put the humans that are given an AI in one squad?", "AI build mode", list("Yes", "No")) == "Yes"
	to_chat(c, SPAN_NOTICE("AI build mode: [personality] humans, [role || "job kit"], [faction || "their own faction"], reach [reach][squad ? ", one squad" : ""]."))

/// The mobs a click is about: the mob that was clicked, or the one standing on the tile, or every mob close to it when the mode has a reach
/datum/buildmode_mode/ai/proc/targets(atom/clicked)
	var/list/found = list()
	var/turf/center = get_turf(clicked)
	if(!center)
		return found
	if(reach)
		for(var/mob/living/near in range(reach, center))
			if(npc_ai_kind(near))
				found += near
		return found
	if(npc_ai_kind(clicked))
		found += clicked
		return found
	for(var/mob/living/on_turf in center)
		if(npc_ai_kind(on_turf))
			found += on_turf
			break
	return found

/// Gives the AI to what was clicked, returns the mobs that took it
/datum/buildmode_mode/ai/proc/give(atom/clicked, client/reporter)
	var/list/found = targets(clicked)
	if(!length(found))
		to_chat(reporter, SPAN_WARNING("There is nothing there that has an AI to give."))
		return list()
	var/list/took = list()
	var/list/refusals = list()
	for(var/mob/living/living as anything in found)
		var/refusal = npc_ai_give(living, personality, role, faction)
		if(refusal)
			refusals += refusal
		else
			took += living
	// Humans of the lot go in one squad when asked
	if(squad)
		var/list/humans = list()
		for(var/mob/living/carbon/human/human in took)
			if(human.ai_brain)
				humans += human
		if(length(humans) > 1)
			create_human_ai_squad(humans, null, "Assigned squad")
	if(length(refusals) && !reach)
		to_chat(reporter, SPAN_WARNING("No AI for that one: [refusals[1]]."))
	else if(length(refusals))
		to_chat(reporter, SPAN_NOTICE("[length(refusals)] close to the click could not be given an AI, for instance because [refusals[1]]."))
	if(length(took) && reporter?.mob)
		message_admins("[key_name_admin(reporter.mob)] gave an AI to [length(took)] mobs at [get_area(get_turf(clicked))] with build mode.")
	return took

/// Takes the AI off what was clicked, returns the mobs that had one
/datum/buildmode_mode/ai/proc/take(atom/clicked, client/reporter)
	var/list/released = list()
	for(var/mob/living/living as anything in targets(clicked))
		if(npc_ai_take(living))
			released += living
	if(!length(released))
		to_chat(reporter, SPAN_WARNING("There is no AI there to take off."))
	else if(reporter?.mob)
		message_admins("[key_name_admin(reporter.mob)] took the AI off [length(released)] mobs at [get_area(get_turf(clicked))] with build mode.")
	return released

/datum/buildmode_mode/ai/when_clicked(client/c, params, object)
	var/list/modifiers = params2list(params)
	if(LAZYACCESS(modifiers, RIGHT_CLICK))
		take(object, c)
	else if(LAZYACCESS(modifiers, LEFT_CLICK))
		give(object, c)
