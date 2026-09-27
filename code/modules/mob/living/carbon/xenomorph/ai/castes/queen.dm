/**
 * Queen AI. Default loop is hive economy (build, weed, sit the ovipositor), not chase-and-attack -
 * only drops into the shared combat state machine when a threat is actually visible. Not
 * population-budgeted like other castes (only one Queen per hive); gets a wider awareness radius
 * (AI_QUEEN_ATTACK_DISTANCE/RETURN_DISTANCE).
 *
 * Capabilities: builds the Hive Core, then mounts the ovipositor once it exists and nothing's
 * threatening her, laying eggs and periodically using expand_weeds from the throne. Broadcasts a
 * hive-wide alert whenever she has a live target, which idle same-hive xenos respond to
 * (xeno_ai_controller.dm's respond_to_hive_alert()). Opens engagements with Screech. Closes to
 * melee against a weakened or lone target, kites and spits a real cluster. Overrides should_flee()
 * to stand and fight when she's the hive's last defender or already escorted.
 */
/datum/xeno_ai_controller/queen
	/// Successful plant_weeds actions committed since spawning.
	var/initial_builds_done = 0
	/// world.time she's next willing to mount the ovipositor.
	var/next_mount_attempt = 0
	/// world.time she can next use expand_weeds from the throne.
	var/next_expand_weeds_attempt = 0
	/// world.time until which tick()'s distant-engagement gate is skipped once she's committed to a fight.
	var/distant_engage_committed_until = 0

/datum/xeno_ai_controller/queen/New(mob/living/carbon/xenomorph/new_pilot)
	. = ..()
	attack_distance = AI_QUEEN_ATTACK_DISTANCE
	return_distance = AI_QUEEN_RETURN_DISTANCE

// Overrides the base tick() directly instead of calling ..() at the top - only falls through to
// the shared state machine (via explicit ..() calls below) once she's committed to fighting.
/datum/xeno_ai_controller/queen/tick()
	var/mob/living/carbon/xenomorph/queen/queen_pilot = pilot
	if(!istype(queen_pilot))
		return

	// Keeps scanning for danger while mounted/immobilized so she can notice a threat to dismount for.
	if(!current_target)
		process_target()

	if(current_target)
		broadcast_hive_alert(queen_pilot)
	broadcast_escort_call(queen_pilot, FALSE)

	if(queen_pilot.ovipositor)
		if(current_target)
			queen_pilot.dismount_ovipositor(TRUE) // Instant, no confirmation dialog.
			next_mount_attempt = world.time + AI_QUEEN_REMOUNT_COOLDOWN
			return
		if(should_reinforce_frontline(queen_pilot))
			queen_pilot.dismount_ovipositor() // Graceful, normal dismount animation/announcement.
			next_mount_attempt = world.time + AI_QUEEN_REMOUNT_COOLDOWN
			if(GLOB.ai_debug_pathing)
				log_debug("XENO AI QUEEN REINFORCING: [queen_pilot] left the ovipositor to reinforce a struggling frontline - [get_ai_debug_snapshot()]")
			return // respond_to_hive_alert() (patrol(), next tick) carries her the rest of the way there.
		attempt_expand_weeds(queen_pilot)
		var/broadcasting = queen_pilot.hive && (world.time - queen_pilot.hive.queen_alert_time <= AI_XENO_HIVE_ALERT_WINDOW || world.time - queen_pilot.hive.queen_escort_time <= AI_XENO_HIVE_ALERT_WINDOW)
		idle_activity = broadcasting ? IDLE_ACTIVITY_COMMANDING : IDLE_ACTIVITY_BUILD
		return // TRAIT_IMMOBILIZED already prevents movement/melee; everything above is remote/passive.

	if(queen_pilot.is_mob_incapacitated() || HAS_TRAIT(queen_pilot, TRAIT_IMMOBILIZED))
		return

	if(current_target)
		// A distant fight is optional - she only marches out once the hive can spare her and has
		// an escort. Never gated once she's already been hit, or the threat is already close.
		var/being_hurt = queen_pilot.maxHealth && queen_pilot.health < queen_pilot.maxHealth * 0.95
		if(world.time < distant_engage_committed_until)
			return ..()
		if(!being_hurt && get_dist(queen_pilot, current_target) > AI_QUEEN_SELF_DEFENSE_RANGE && !hive_strong_enough_to_attack())
			drop_target()
		else
			distant_engage_committed_until = world.time + AI_QUEEN_DISTANT_ENGAGE_COMMIT_TIME
			return ..() // Hands off to the shared approach/attack/leash state machine.

	if(should_flee())
		return ..()

	// Won't mount the ovipositor until the Hive Core exists - build it first.
	if(queen_pilot.hive && !queen_pilot.hive.has_structure(XENO_STRUCTURE_CORE))
		idle_activity = IDLE_ACTIVITY_BUILD
		var/obj/effect/alien/weeds/own_weeds = locate(/obj/effect/alien/weeds) in get_turf(queen_pilot)
		if(!own_weeds || own_weeds.linked_hive.hivenumber != queen_pilot.hivenumber)
			attempt_plant_weeds()
			return
		attempt_build_hive_core(queen_pilot)
		return

	if(initial_builds_done < AI_QUEEN_MIN_INITIAL_BUILDS)
		if(attempt_plant_weeds())
			initial_builds_done++
		patrol()
		return

	if(should_mount_ovipositor(queen_pilot))
		var/datum/action/xeno_action/onclick/grow_ovipositor/mount_ability = get_ability(/datum/action/xeno_action/onclick/grow_ovipositor)
		mount_ability?.use_ability(queen_pilot)
		return

	patrol()

/// Whether the hive can afford its mother marching to a distant fight: population near the Spawner's target, plus a nearby ally escort.
/datum/xeno_ai_controller/queen/proc/hive_strong_enough_to_attack()
	if(count_nearby_hive_allies(AI_QUEEN_ATTACK_ESCORT_RADIUS) < AI_QUEEN_ATTACK_MIN_ESCORT)
		return FALSE
	var/target_pop = spawner_target_population(pilot?.hive)
	if(target_pop <= 0)
		return TRUE
	var/current = 0
	for(var/mob/living/carbon/xenomorph/hive_member as anything in GLOB.ai_xeno_list)
		if(hive_member.hivenumber == pilot.hivenumber && hive_member.counts_for_slots)
			current++
	return current >= target_pop * AI_QUEEN_ATTACK_STRENGTH_PERCENT

/// Gates mounting the ovipositor: Core built, standing on own hive weeds, remount cooldown passed, ability off cooldown.
/datum/xeno_ai_controller/queen/proc/should_mount_ovipositor(mob/living/carbon/xenomorph/queen/queen_pilot)
	if(queen_pilot.ovipositor || world.time < next_mount_attempt)
		return FALSE
	if(!queen_pilot.hive || !queen_pilot.hive.has_structure(XENO_STRUCTURE_CORE))
		return FALSE
	var/obj/effect/alien/weeds/own_weeds = locate(/obj/effect/alien/weeds) in get_turf(queen_pilot)
	if(!own_weeds || own_weeds.linked_hive.hivenumber != queen_pilot.hivenumber)
		return FALSE
	var/datum/action/xeno_action/onclick/grow_ovipositor/mount_ability = get_ability(/datum/action/xeno_action/onclick/grow_ovipositor)
	return mount_ability && mount_ability.action_cooldown_check()

/// Whether to leave the ovipositor and reinforce a struggling frontline: a live hive-wide push exists, the economy can spare her, and there aren't already enough responders.
/datum/xeno_ai_controller/queen/proc/should_reinforce_frontline(mob/living/carbon/xenomorph/queen/queen_pilot)
	if(!queen_pilot.hive)
		return FALSE
	if(!queen_pilot.hive.assault_alert_turf || world.time - queen_pilot.hive.assault_alert_time > AI_XENO_HIVE_ALERT_WINDOW)
		return FALSE
	if(queen_pilot.hive.stored_larva < AI_QUEEN_DEOVI_MIN_LARVA)
		return FALSE
	return count_nearby_hive_members(queen_pilot.hive.assault_alert_turf, AI_XENO_HIVE_ALERT_RESPONDER_RADIUS) < AI_QUEEN_DEOVI_RESPONDER_THRESHOLD

/// Ovi-exclusive remote-targeted weed expansion, rolled periodically while mounted.
/datum/xeno_ai_controller/queen/proc/attempt_expand_weeds(mob/living/carbon/xenomorph/queen/queen_pilot)
	if(world.time < next_expand_weeds_attempt)
		return
	var/datum/action/xeno_action/activable/expand_weeds/expand_ability = get_ability(/datum/action/xeno_action/activable/expand_weeds)
	if(!expand_ability || !expand_ability.action_cooldown_check())
		return
	next_expand_weeds_attempt = world.time + AI_QUEEN_EXPAND_WEEDS_INTERVAL

	var/list/candidates = list()
	for(var/turf/candidate in range(AI_QUEEN_EXPAND_WEEDS_RADIUS, queen_pilot))
		if(candidate.density || candidate.is_weedable() < FULLY_WEEDABLE)
			continue
		if(locate(/obj/effect/alien/weeds) in candidate)
			continue
		candidates += candidate
	if(!length(candidates))
		return
	expand_ability.use_ability(pick(candidates))

/// Builds the Hive Core: feeds an in-progress node if one exists, otherwise orders one placed.
/datum/xeno_ai_controller/queen/proc/attempt_build_hive_core(mob/living/carbon/xenomorph/queen/queen_pilot)
	if(!queen_pilot.hive || queen_pilot.hive.has_structure(XENO_STRUCTURE_CORE))
		return

	var/obj/effect/alien/resin/construction/node = find_nearby_hive_node(XENO_STRUCTURE_CORE)
	if(node)
		attempt_feed_hive_node(node)
		return

	if(queen_pilot.hive.hivecore_cooldown)
		return
	var/datum/action/xeno_action/activable/place_construction/action = get_ability(/datum/action/xeno_action/activable/place_construction)
	if(!action)
		return
	// Only orders a Core - the ability's own structure picker (general_powers.dm) needs a client
	// to answer once other structure types are available, which an AI xeno doesn't have.
	action.use_ability(get_turf(queen_pilot))

/// Adds plant_weeds duty (same base_actions entry as a Drone) to the shared patrol().
/datum/xeno_ai_controller/queen/patrol()
	if(respond_to_hive_alert())
		idle_activity = IDLE_ACTIVITY_ALERT
		return
	attempt_queen_heal()
	attempt_queen_give_plasma()
	attempt_promote_leader()
	if(prob(AI_QUEEN_BUILD_CHANCE) && attempt_plant_weeds())
		idle_activity = IDLE_ACTIVITY_BUILD
		return
	return ..()

/// Higher than the population default - a costly, hard-to-replace unit breaks off earlier.
/datum/xeno_ai_controller/queen/get_flee_threshold()
	return AI_QUEEN_FLEE_HEALTH_PERCENT

/// Only flees if the base logic would, and she isn't the hive's last living member, and she isn't already backed by enough escorting daughters.
/datum/xeno_ai_controller/queen/should_flee()
	if(!..())
		return FALSE
	var/mob/living/carbon/xenomorph/queen/queen_pilot = pilot
	if(!istype(queen_pilot))
		return TRUE
	if(is_last_defender(queen_pilot))
		return FALSE
	if((queen_pilot.health / queen_pilot.maxHealth) > AI_XENO_FLEE_ALLY_SUPPRESS_FLOOR && current_target && count_engaged_allies(current_target) >= AI_QUEEN_ESCORT_STAND_THRESHOLD)
		return FALSE
	return TRUE

/datum/xeno_ai_controller/queen/get_combat_weed_chance()
	return AI_QUEEN_COMBAT_WEED_CHANCE

/datum/xeno_ai_controller/queen/proc/is_last_defender(mob/living/carbon/xenomorph/queen/queen_pilot)
	if(!queen_pilot.hive)
		return FALSE
	for(var/mob/living/carbon/xenomorph/hive_member as anything in queen_pilot.hive.totalXenos)
		if(hive_member == queen_pilot || hive_member.stat == DEAD)
			continue
		return FALSE
	return TRUE

/// Closes to melee and finishes a weakened or lone target; stays ranged and softens a real cluster.
/datum/xeno_ai_controller/queen/process_attack()
	var/mob/living/carbon/xenomorph/queen/queen_pilot = pilot
	if(!istype(queen_pilot) || !current_target)
		ai_state = AI_STATE_IDLE
		return
	if(!is_valid_target(current_target))
		drop_target()
		return

	attempt_screech()

	if(pilot.Adjacent(current_target))
		execute_attack(current_target)
		if(stale_attack_ticks >= AI_PRIORITY_STALE_ATTACK_GIVEUP)
			drop_target()
		return

	if(should_close_to_melee(current_target))
		ai_state = AI_STATE_APPROACHING
		return

	attempt_ranged_spit(current_target)
	ai_state = AI_STATE_APPROACHING

/// Melee-vs-ranged decision: closes on anything already weakened, or genuinely alone; stays ranged against a real cluster.
/datum/xeno_ai_controller/queen/proc/should_close_to_melee(mob/living/target)
	if(!istype(target))
		return FALSE
	if(target.maxHealth && target.health <= target.maxHealth * AI_QUEEN_MELEE_TARGET_HEALTH_PERCENT)
		return TRUE
	// An immature Queen has no ranged spit yet - staying at range would deal zero damage.
	if(!get_ability(/datum/action/xeno_action/activable/xeno_spit/queen_macro))
		return TRUE
	var/nearby_hostiles = 0
	for(var/mob/living/nearby in orange(AI_QUEEN_GROUP_SCREECH_RADIUS, target))
		if(nearby == target || !is_valid_target(nearby))
			continue
		nearby_hostiles++
		if(nearby_hostiles >= AI_QUEEN_GROUP_SCREECH_THRESHOLD)
			return FALSE
	return TRUE

/// Weeds mid-fight for the heal/slow/speed effect, not just as idle economy.
/datum/xeno_ai_controller/queen/process_movement()
	if(!pilot || !current_target)
		return
	if(!is_valid_target(current_target))
		drop_target()
		return

	if(prob(get_combat_weed_chance()))
		attempt_plant_weeds()
	attempt_periodic_combat_pheromones()

	note_last_seen(get_turf(current_target), current_target)
	if(should_close_to_melee(current_target))
		travel_to(current_target, TRAVEL_FLAG_FORCE_OBSTACLES|TRAVEL_FLAG_COVER_CHECK)
	else
		maintain_kiting_distance(current_target, AI_XENO_RANGED_PREFERRED_DISTANCE)

/// Switches spit ammo to match range - Acid Spatter up close, Neurotoxin at range.
/datum/xeno_ai_controller/queen/proc/select_spit_type(mob/living/target)
	var/mob/living/carbon/xenomorph/queen/queen_pilot = pilot
	if(!istype(queen_pilot) || !queen_pilot.caste)
		return
	var/desired_type = (get_dist(queen_pilot, target) <= AI_XENO_RANGED_MIN_DISTANCE + 1) ? /datum/ammo/xeno/acid/spatter : /datum/ammo/xeno/toxin/queen
	if(queen_pilot.ammo == GLOB.ammo_list[desired_type])
		return
	var/datum/action/xeno_action/onclick/shift_spits/shift = get_ability(/datum/action/xeno_action/onclick/shift_spits)
	shift?.use_ability(queen_pilot)

/datum/xeno_ai_controller/queen/proc/attempt_ranged_spit(mob/living/target)
	var/datum/action/xeno_action/activable/xeno_spit/queen_macro/spit = get_ability(/datum/action/xeno_action/activable/xeno_spit/queen_macro)
	if(!spit || !spit.action_cooldown_check())
		return
	select_spit_type(target)
	pilot.setDir(get_dir(pilot, target))
	spit.use_ability(target)

/// AoE fear/disorient, fired the moment it's off cooldown.
/datum/xeno_ai_controller/queen/proc/attempt_screech()
	var/datum/action/xeno_action/onclick/screech/screech = get_ability(/datum/action/xeno_action/onclick/screech)
	if(!screech || !screech.action_cooldown_check())
		return FALSE
	screech.use_ability(pilot)
	return TRUE

/// Gut, an 8-second windup that instantly gibs on completion - only used to finish an already-helpless target, never as an opener.
/datum/xeno_ai_controller/queen/use_caste_ability(mob/living/target)
	var/mob/living/carbon/xenomorph/queen/queen_pilot = pilot
	if(!istype(queen_pilot))
		return FALSE

	attempt_screech()

	var/target_helpless = target.stat == DEAD || HAS_TRAIT(target, TRAIT_FLOORED) || target.is_mob_incapacitated()
	if(target_helpless)
		var/datum/action/xeno_action/activable/gut/gut_ability = get_ability(/datum/action/xeno_action/activable/gut)
		if(gut_ability && gut_ability.action_cooldown_check())
			for(var/mob/living/nearby in orange(3, queen_pilot))
				if(nearby == target)
					continue
				if(is_valid_target(nearby))
					return attempt_tail_stab(target) // Not a clean opportunity - could be interrupted mid-windup.
			gut_ability.use_ability(target)
			return TRUE

	return attempt_tail_stab(target)

/// Heals the most badly hurt nearby daughter within AI_QUEEN_SUPPORT_RADIUS.
/datum/xeno_ai_controller/queen/proc/attempt_queen_heal()
	if(!pilot)
		return FALSE
	var/datum/action/xeno_action/activable/queen_heal/heal = get_ability(/datum/action/xeno_action/activable/queen_heal)
	if(!heal || !heal.action_cooldown_check())
		return FALSE
	var/mob/living/carbon/xenomorph/hurt_ally
	var/lowest_fraction = 1
	for(var/mob/living/carbon/xenomorph/nearby in range(AI_QUEEN_SUPPORT_RADIUS, pilot))
		if(nearby == pilot || nearby.hivenumber != pilot.hivenumber || nearby.stat == DEAD || !nearby.maxHealth)
			continue
		var/fraction = nearby.health / nearby.maxHealth
		if(fraction < AI_QUEEN_HEAL_TRIGGER_PERCENT && fraction < lowest_fraction)
			lowest_fraction = fraction
			hurt_ally = nearby
	if(!hurt_ally)
		return FALSE
	heal.use_ability(hurt_ally)
	return TRUE

/// Gives plasma to the most plasma-starved nearby daughter within AI_QUEEN_SUPPORT_RADIUS.
/datum/xeno_ai_controller/queen/proc/attempt_queen_give_plasma()
	if(!pilot)
		return FALSE
	var/datum/action/xeno_action/activable/queen_give_plasma/give = get_ability(/datum/action/xeno_action/activable/queen_give_plasma)
	if(!give || !give.action_cooldown_check())
		return FALSE
	var/mob/living/carbon/xenomorph/needy_ally
	var/lowest_fraction = 1
	for(var/mob/living/carbon/xenomorph/nearby in range(AI_QUEEN_SUPPORT_RADIUS, pilot))
		if(nearby == pilot || nearby.hivenumber != pilot.hivenumber || nearby.stat == DEAD || !nearby.plasma_max)
			continue
		var/fraction = nearby.plasma_stored / nearby.plasma_max
		if(fraction < AI_QUEEN_PLASMA_GIVE_TRIGGER_PERCENT && fraction < lowest_fraction)
			lowest_fraction = fraction
			needy_ally = nearby
	if(!needy_ally)
		return FALSE
	give.use_ability(needy_ally)
	return TRUE

/// Promotes a worthy nearby combat-capable (T2+) daughter to Hive Leader if the hive has none.
/datum/xeno_ai_controller/queen/proc/attempt_promote_leader()
	if(!pilot?.hive)
		return FALSE
	if(length(pilot.hive.open_xeno_leader_positions) < pilot.hive.queen_leader_limit)
		return FALSE
	var/mob/living/carbon/xenomorph/best_candidate
	for(var/mob/living/carbon/xenomorph/nearby in range(AI_QUEEN_SUPPORT_RADIUS, pilot))
		if(nearby == pilot || nearby.hivenumber != pilot.hivenumber || nearby.stat == DEAD || nearby.hive_pos != NORMAL_XENO)
			continue
		if(!nearby.caste || nearby.caste.tier < 2)
			continue
		best_candidate = nearby
		break
	if(!best_candidate)
		return FALSE
	return pilot.hive.add_hive_leader(best_candidate)

// broadcast_hive_alert()/count_nearby_escorts()/broadcast_escort_call() live on the base
// controller (xeno_ai_controller.dm) - Queen inherits them, King shares them too.
