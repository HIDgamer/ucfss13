/**
 * Hivelord AI - a dedicated fast/cheap builder (build_time_mult = 0.5x per
 * Hivelord.dm), same build-duty pattern as Drone (see drone_worker.dm) just
 * at her own higher build chance to match how much more efficient she is
 * at it. Combat/searching/returning is entirely inherited from the base
 * controller, same reasoning as Drone - "aid and assist in attacking", not
 * a builder that ignores threats.
 *
 * Toggles Resin Walker (a continuous plasma-draining speed buff) on while
 * standing on her own hive's weeds and off the moment she isn't - the
 * ability's own life_tick() already auto-disables it outright the instant
 * plasma actually runs dry (xeno_action.dm's active_toggle/life_tick()), so
 * there was never really a "stranded out of plasma" risk to manage here;
 * left on during an approach once a target's spotted is a feature, not a
 * risk - getting into the fight faster.
 */
/datum/xeno_ai_controller/hivelord

/datum/xeno_ai_controller/hivelord/patrol()
	if(respond_to_hive_alert())
		idle_activity = IDLE_ACTIVITY_ALERT
		return
	manage_resin_walker()
	if(attempt_help_queen_build_core())
		idle_activity = IDLE_ACTIVITY_BUILD
		return
	if(prob(AI_DEFENSE_BUILD_CHANCE) && attempt_build_defense())
		idle_activity = IDLE_ACTIVITY_BUILD
		return
	if(prob(AI_HIVELORD_BUILD_CHANCE) && attempt_plant_weeds())
		idle_activity = IDLE_ACTIVITY_BUILD
		return
	return ..() // Falls through to the base patrol() (long patrol/pack cohesion/ambush hide/wander) instead of only ever plain wander().

/// Keeps Resin Walker on precisely while standing on own-hive weeds, off otherwise - see the caste doc comment above for why this doesn't need to worry about stranding her out of plasma.
/datum/xeno_ai_controller/hivelord/proc/manage_resin_walker()
	if(!pilot)
		return
	var/datum/action/xeno_action/active_toggle/toggle_speed/walker = get_ability(/datum/action/xeno_action/active_toggle/toggle_speed)
	if(!walker)
		return
	var/obj/effect/alien/weeds/weeds = locate(/obj/effect/alien/weeds) in get_turf(pilot)
	var/on_own_weeds = weeds && weeds.linked_hive.hivenumber == pilot.hivenumber
	if(on_own_weeds != walker.action_active)
		walker.action_activate()

/// A builder first, but "aid and assist in attacking" means an actual hit when it comes to that, not a bare claw.
/datum/xeno_ai_controller/hivelord/use_caste_ability(mob/living/target)
	return attempt_tail_stab(target)
