/// Plays shoe or bare foot steps for a human running over the floor, walking is silent
/datum/element/human_footstep
	element_flags = ELEMENT_DETACH
	var/list/steps_taken = list()

/datum/element/human_footstep/Attach(datum/target)
	. = ..()
	if(!ishuman(target))
		return ELEMENT_INCOMPATIBLE
	RegisterSignal(target, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	steps_taken[target] = 0

/datum/element/human_footstep/Detach(datum/source, force)
	UnregisterSignal(source, COMSIG_MOVABLE_MOVED)
	steps_taken -= source
	return ..()

/datum/element/human_footstep/proc/on_moved(mob/living/carbon/human/source, atom/oldloc, direction, forced)
	SIGNAL_HANDLER
	if(SSlag_switch.measures[DISABLE_FOOTSTEPS])
		return
	if(forced || source.buckled || source.throwing || source.is_ventcrawling || source.stat == DEAD || isyautja(source))
		return
	var/turf/open/step_turf = get_turf(source)
	if(!istype(step_turf))
		return
	var/surface = step_turf.get_footstep_surface()
	if(surface == FOOTSTEP_NONE)
		return

	if(source.body_position == LYING_DOWN)
		playsound(step_turf, 'sound/effects/footstep/crawl1.ogg', FOOTSTEP_CRAWL_VOLUME, TRUE, FOOTSTEP_BASE_RANGE - 3, VOLUME_FOOTSTEPS, falloff = 1)
		human_ai_footstep(source, step_turf, HAI_FOOTSTEP_CRAWL_RANGE)
		return
	if(source.m_intent == MOVE_INTENT_WALK)
		return

	steps_taken[source]++
	if(steps_taken[source] % FOOTSTEP_STEP_INTERVAL)
		return
	human_ai_footstep(source, step_turf, HAI_FOOTSTEP_RANGE)

	var/list/sounds
	if(source.shoes)
		sounds = GLOB.shoe_footsteps[surface]
	else
		sounds = GLOB.barefoot_footsteps[surface] || GLOB.shoe_footsteps[surface]
	if(!sounds)
		return
	playsound(step_turf, pick(sounds[1]), sounds[2] * FOOTSTEP_VOLUME_SCALE, TRUE, FOOTSTEP_BASE_RANGE + sounds[3], VOLUME_FOOTSTEPS, falloff = 1)
