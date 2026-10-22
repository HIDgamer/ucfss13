/// The AI humans one admin session has selected in the NPC command panel
/datum/npc_command_selection
	var/list/mob/living/carbon/human/selected = list()
	/// The one faction the panel may command, null for every faction. Everything the panel lists, selects or orders goes through valid(), so this holds it all
	var/faction_scope

/// Whether the human is something the panel may command: alive, clientless, piloted by a running brain and of the faction the panel is held to
/datum/npc_command_selection/proc/valid(mob/living/carbon/human/human)
	if(!istype(human) || QDELETED(human) || human.stat == DEAD || human.client || !human.ai_brain || human.ai_brain.stopped)
		return FALSE
	return !faction_scope || human.faction == faction_scope

/// The only way to read the selection, anything that stopped being commandable is dropped first
/datum/npc_command_selection/proc/get_selected()
	for(var/mob/living/carbon/human/human as anything in selected)
		if(!valid(human))
			forget(human)
	return selected.Copy()

/// Takes the human out of the selection and stops listening for it being deleted
/datum/npc_command_selection/proc/forget(mob/living/carbon/human/human)
	if(!(human in selected))
		return
	selected -= human
	UnregisterSignal(human, COMSIG_PARENT_QDELETING)

/// A selected human that is deleted is let go at once, so that a selection nobody asks about again cannot keep it from being freed
/datum/npc_command_selection/proc/on_member_deleted(datum/source)
	SIGNAL_HANDLER
	selected -= source

/datum/npc_command_selection/proc/select(mob/living/carbon/human/human)
	if(!valid(human))
		return FALSE
	if(!(human in selected))
		selected += human
		RegisterSignal(human, COMSIG_PARENT_QDELETING, PROC_REF(on_member_deleted))
	return TRUE

/datum/npc_command_selection/proc/select_list(list/humans)
	var/count = 0
	for(var/mob/living/carbon/human/human as anything in humans)
		if(select(human))
			count++
	return count

/datum/npc_command_selection/proc/deselect(mob/living/carbon/human/human)
	forget(human)

/datum/npc_command_selection/proc/toggle(mob/living/carbon/human/human)
	if(human in selected)
		deselect(human)
		return FALSE
	return select(human)

/datum/npc_command_selection/proc/clear()
	for(var/mob/living/carbon/human/human as anything in selected.Copy())
		forget(human)

/datum/npc_command_selection/proc/is_selected(mob/living/carbon/human/human)
	return human in selected

/datum/npc_command_selection/Destroy()
	clear()
	selected = null
	return ..()
