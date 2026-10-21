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
	// A synthetic is calm and collected unless somebody picked a nature for it
	if(personality_id == "neutral" && issynth(human))
		personality_id = "synthetic"
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
	// A corpsman is a medic whether or not whoever spawned it said so, whoever picked a role on purpose sets it again afterwards
	var/inferred_role = human_ai_role_for_job(human.job)
	if(!inferred_role && isworkingjoe(human))
		inferred_role = "working_joe"
	if(inferred_role)
		brain.set_role(inferred_role)
		brain.role.equip_kit(brain)
	brain.issue_hack_tools()
	brain.issue_repair_tools()
	brain.start()
	brain.log_decision("attached ([brain.personality.id])")
	return TRUE

/// Why a human cannot be given a brain, null when it can
/proc/human_ai_attach_refusal(mob/living/carbon/human/human)
	if(!istype(human) || QDELETED(human))
		return "there is nobody there"
	if(human.ai_brain)
		return "[human] is already AI controlled"
	if(human.client)
		return "[human] is played by [human.key], who has to leave the body first"
	if(human.stat == DEAD)
		return "[human] is dead"
	if(iszombie(human) || human.zombie_ai_controller)
		return "[human] is a zombie and has an AI of its own"
	if(!SShuman_ai.has_room())
		return "the population cap [SShuman_ai.max_total] is met"
	return null

/**
 * Hands a human that already exists a brain, which is what the assign tool does for whoever it is pointed at. The faction, when one is given, is set
 * first because it decides the rules of engagement the brain starts with, and the role, when one is given, brings its kit along with it.
 * Returns why it was refused, null when the human has a brain now.
 */
/proc/assign_human_ai(mob/living/carbon/human/human, personality_id = "neutral", role_id = null, faction = null)
	var/refusal = human_ai_attach_refusal(human)
	if(refusal)
		return refusal
	if(!human.hud_used)
		human.create_hud()
	if(faction)
		human.faction = faction
	if(!attach_human_ai(human, personality_id))
		return "the brain would not attach to [human]"
	if(role_id && (role_id in GLOB.human_ai_roles))
		human.ai_brain.set_role(role_id)
		human.ai_brain.role.equip_kit(human.ai_brain)
	return null

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
	var/refusal = assign_human_ai(target, personality)
	if(refusal)
		to_chat(usr, SPAN_WARNING("Attach failed: [refusal]."))
	else
		to_chat(usr, SPAN_NOTICE("AI attached to [target]."))

/// Tiles around the admin the assign tool looks for humans without a brain when asked for everybody close
#define HAI_ASSIGN_NEARBY 10

/**
 * The assign tool: gives a brain to humans that are already in the round instead of spawning new ones as AI. One human picked from a list, or
 * everybody close by without a brain, with the nature, role kit and faction chosen. The NPC command console has the same thing as a click tool.
 */
/client/proc/assign_human_ai_tool()
	set category = "Admin.Events"
	set name = "Assign Human AI"
	if(!check_rights(R_SPAWN))
		return

	var/choice = tgui_alert(usr, "Who gets an AI?", "Assign Human AI", list("Pick one", "Everyone close by", "Cancel"))
	if(!choice || choice == "Cancel")
		return
	var/list/candidates = list()
	if(choice == "Pick one")
		var/list/named = list()
		for(var/mob/living/carbon/human/candidate as anything in GLOB.alive_human_list)
			if(human_ai_attach_refusal(candidate))
				continue
			var/label = "[candidate.real_name] ([candidate.job || "no job"]) in [get_area(candidate)]"
			if(named[label])
				label = "[label] [REF(candidate)]"
			named[label] = candidate
		if(!length(named))
			to_chat(usr, SPAN_WARNING("There is nobody without an AI who could be given one."))
			return
		var/picked = tgui_input_list(usr, "Which human?", "Assign Human AI", named)
		if(!picked)
			return
		candidates += named[picked]
	else
		for(var/mob/living/carbon/human/candidate in range(HAI_ASSIGN_NEARBY, mob))
			if(!human_ai_attach_refusal(candidate))
				candidates += candidate
		if(!length(candidates))
			to_chat(usr, SPAN_WARNING("There is nobody close by who could be given an AI."))
			return

	var/personality = tgui_input_list(usr, "Which nature?", "Assign Human AI", GLOB.human_ai_personalities, default = "neutral")
	if(!personality)
		return
	var/list/role_choices = list("From their job")
	role_choices += GLOB.human_ai_roles
	var/role = tgui_input_list(usr, "Which role kit?", "Assign Human AI", role_choices, default = "From their job")
	if(!role)
		return
	var/list/faction_choices = list("Keep theirs")
	faction_choices += human_ai_known_factions()
	var/faction = tgui_input_list(usr, "Which faction?", "Assign Human AI", faction_choices, default = "Keep theirs")
	if(!faction)
		return
	var/squad = length(candidates) > 1 && tgui_alert(usr, "Put them in one squad?", "Assign Human AI", list("Yes", "No")) == "Yes"
	var/assigned = assign_humans_ai(candidates, personality, role == "From their job" ? null : role, faction == "Keep theirs" ? null : faction, squad)
	to_chat(usr, SPAN_NOTICE("[assigned] of [length(candidates)] humans were given an AI."))
	message_admins("[key_name_admin(usr)] gave an AI to [assigned] existing humans with the assign tool.")

/// Gives every human in the list a brain, optionally grouping the ones that took it into a squad, and returns how many took it
/proc/assign_humans_ai(list/humans, personality_id, role_id, faction, squad = FALSE)
	var/list/took = list()
	for(var/mob/living/carbon/human/human as anything in humans)
		if(!assign_human_ai(human, personality_id, role_id, faction))
			took += human
	if(squad && length(took) > 1)
		create_human_ai_squad(took, null, "Assigned squad")
	return length(took)

#undef HAI_ASSIGN_NEARBY
