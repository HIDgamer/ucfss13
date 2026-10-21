/// What a brain has to remember to take a body back after it is revived: who it was and how it was set to behave
/datum/human_ai_brain/proc/revival_memory()
	var/datum/human_ai_personality/original = base_personality || personality
	return list(
		"personality" = original.id,
		"traits" = original.traits.Copy(),
		"role" = role?.id,
		"roe" = roe,
		"aggression" = aggression,
		"enemy_factions" = enemy_factions ? enemy_factions.Copy() : null,
		"posture" = posture,
		"move_cap" = move_cap,
		"keep_awake" = keep_awake,
		"cover_enabled" = cover_enabled,
		"home" = home_turf,
		"gear" = worn_gear(),
		"squad" = squad ? WEAKREF(squad) : null,
	)

/// A body that was driven by a brain and has died waits for its revival to take the brain back
/mob/living/carbon/human/proc/remember_human_ai(list/memory)
	human_ai_memory = memory
	UnregisterSignal(src, list(COMSIG_HUMAN_REVIVED, COMSIG_LIVING_REJUVENATED))
	RegisterSignal(src, list(COMSIG_HUMAN_REVIVED, COMSIG_LIVING_REJUVENATED), PROC_REF(on_revived_human_ai))

/// Forgets what the brain was like, because a new brain was put on the body or the AI came back
/mob/living/carbon/human/proc/forget_human_ai()
	human_ai_memory = null
	UnregisterSignal(src, list(COMSIG_HUMAN_REVIVED, COMSIG_LIVING_REJUVENATED))

/// A defibrillator signals before the heart is going again and a heal signals after, so the brain is only put back once the grace period has passed
/mob/living/carbon/human/proc/on_revived_human_ai(datum/source)
	SIGNAL_HANDLER
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(reattach_human_ai_after_revive), src), HAI_REVIVE_GRACE)

/**
 * Puts the AI back in a revived body, the way zombies and xenos take theirs back. A player who took the body in the meantime keeps it, and a body that
 * is still dead or could not get a brain, because the population cap is met, keeps its memory for the next revival.
 */
/proc/reattach_human_ai_after_revive(mob/living/carbon/human/human)
	if(!human || QDELETED(human) || !human.human_ai_memory || human.ai_brain)
		return FALSE
	if(human.client || human.stat == DEAD)
		return FALSE
	var/list/memory = human.human_ai_memory
	if(!attach_human_ai(human, memory["personality"]))
		return FALSE
	var/datum/human_ai_brain/brain = human.ai_brain
	brain.set_personality(memory["personality"], 0, memory["traits"])
	if(memory["role"])
		brain.set_role(memory["role"])
	brain.roe = memory["roe"]
	brain.aggression = memory["aggression"]
	brain.enemy_factions = memory["enemy_factions"]
	brain.posture = memory["posture"]
	brain.move_cap = memory["move_cap"]
	brain.keep_awake = memory["keep_awake"]
	brain.cover_enabled = memory["cover_enabled"]
	if(memory["home"])
		brain.home_turf = memory["home"]
	// What it wore when it died may be lying about and it goes back to its squad
	if(length(memory["gear"]))
		brain.regear_items = memory["gear"]
	var/datum/weakref/squad_ref = memory["squad"]
	var/datum/human_ai_squad/old_squad = squad_ref?.resolve()
	if(old_squad && !QDELETED(old_squad))
		old_squad.add_member(brain)
	brain.apply_posture()
	brain.log_decision("took the body back after it was revived")
	return TRUE
