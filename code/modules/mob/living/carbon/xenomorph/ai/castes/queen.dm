/**
 * Queen AI - fundamentally different from every other caste's controller:
 * her default loop is hive economy and command (grow/maintain an ovipositor
 * for larva production, direct the hive toward threats), not chase-and-attack.
 * She only drops into the shared combat loop (via ..() -> the base tick()'s
 * normal state machine) when a threat is actually visible or the hive needs
 * her, matching the user's design: "if the hive is under heavy attack she
 * would assist if all other conditions such as the hive not needing eggs or
 * anything else check out."
 *
 * There is only ever one living Queen per hive at a time, so unlike every
 * other controller in this file, her AI is deliberately NOT budgeted for
 * population scale - she gets a wider awareness radius
 * (AI_QUEEN_ATTACK_DISTANCE/RETURN_DISTANCE) and does real per-tick
 * hive-wide reasoning (scanning GLOB.ai_xeno_list for a siege - see
 * check_lz_siege()) that would be inappropriate to give every Drone.
 *
 * Capabilities:
 * - Economy: mounts a real ovipositor (the actual grow_ovipositor ability,
 *   so it correctly requires hive-owned weeds and costs plasma, same as a
 *   player) only when the hive doesn't already have a comfortable larva
 *   buffer (AI_QUEEN_LARVA_COMFORTABLE_THRESHOLD) - she won't reflexively
 *   mount just because it's safe to.
 * - Command: broadcasts a hive-wide alert (hive_status.dm's
 *   queen_alert_turf/queen_alert_time) whenever she has a live target -
 *   every other same-hive AI xeno checks this during idle patrol
 *   (xeno_ai_controller.dm's respond_to_hive_alert()) and heads there
 *   instead of wandering. This is how she "commands" the hive without a
 *   hard command hierarchy.
 * - LZ siege response: if enough same-hive AI xenos are actively fighting
 *   near the marine LZ at once (AI_QUEEN_LZ_SIEGE_THRESHOLD within
 *   AI_QUEEN_LZ_SIEGE_RADIUS), she personally dismounts/stops patrolling
 *   and joins the assault, per the user's explicit direction that she
 *   should join her children once the hive is heavily attacking the LZ.
 * - Last stand: overrides should_flee() so that when the base logic says
 *   she'd retreat (critically wounded/on fire) but she's the hive's only
 *   living member, she stands and fights instead - retreating would only
 *   delay the inevitable while abandoning the fight for nothing.
 *
 * Known interim simplification: threat assessment is still just "is there a
 * visible target," not a weighted evaluation of multiple simultaneous
 * threats, and there's no persistent "under sustained siege at home" memory
 * distinct from the momentary LZ-siege check - reasonable follow-ups once
 * this is proven in a real round.
 */
/datum/xeno_ai_controller/queen

/datum/xeno_ai_controller/queen/New(mob/living/carbon/xenomorph/new_pilot)
	. = ..()
	attack_distance = AI_QUEEN_ATTACK_DISTANCE
	return_distance = AI_QUEEN_RETURN_DISTANCE

// No /proc/ keyword - overriding the base tick(), which itself overrides
// /datum/proc/process(delta_time) (see xeno_ai_controller.dm's own note on
// this). Deliberately does not call ..() at the top the way a normal
// override might - the Queen's decision loop replaces the base one, only
// falling through to it (via explicit ..() calls below) once she's
// committed to fighting.
/datum/xeno_ai_controller/queen/tick()
	var/mob/living/carbon/xenomorph/queen/queen_pilot = pilot
	if(!istype(queen_pilot))
		return

	// Keep scanning for danger even while mounted (immobilized) - the one
	// exception to the base tick()'s "incapacitated means do nothing"
	// shortcut, since a mounted Queen still needs to notice a threat in
	// order to decide to dismount.
	if(!current_target)
		process_target()

	if(current_target)
		broadcast_hive_alert(queen_pilot)

	var/heavy_siege = check_lz_siege(queen_pilot)

	if(queen_pilot.ovipositor)
		if(current_target || heavy_siege)
			queen_pilot.dismount_ovipositor(TRUE) // TRUE = instant, no confirmation dialog, no player-facing channel - she needs to react immediately, not wait through the flavor animation a player would.
		return // Otherwise stay mounted and do nothing else this tick - TRAIT_IMMOBILIZED already prevents movement/attack.

	if(queen_pilot.is_mob_incapacitated() || HAS_TRAIT(queen_pilot, TRAIT_IMMOBILIZED))
		return

	if(current_target)
		return ..() // Hand off to the shared approach/attack/leash state machine - she defends herself and the hive normally once committed.

	if(should_flee())
		return ..() // Critically wounded/on fire and not the hive's last defender - let the base flee-and-resist logic run even though she's not mounted.

	if(heavy_siege)
		head_to_lz(queen_pilot)
		return

	attempt_mount_ovipositor(queen_pilot)
	if(!queen_pilot.ovipositor) // Mount attempt failed (not on hive weeds, on cooldown, hive doesn't need larva, etc.) or is still channeling - patrol/command instead of standing frozen.
		patrol()

/**
 * Only flees if the base logic would AND she isn't the hive's last living
 * member - if she's alone, retreating accomplishes nothing but delaying the
 * inevitable while abandoning the fight, so she makes her stand instead.
 */
/datum/xeno_ai_controller/queen/should_flee()
	if(!..())
		return FALSE
	var/mob/living/carbon/xenomorph/queen/queen_pilot = pilot
	if(!istype(queen_pilot))
		return TRUE
	if(is_last_defender(queen_pilot))
		return FALSE
	return TRUE

/datum/xeno_ai_controller/queen/proc/is_last_defender(mob/living/carbon/xenomorph/queen/queen_pilot)
	if(!queen_pilot.hive)
		return FALSE
	for(var/mob/living/carbon/xenomorph/hive_member as anything in queen_pilot.hive.totalXenos)
		if(hive_member == queen_pilot || hive_member.stat == DEAD)
			continue
		return FALSE
	return TRUE

/// Calls the real grow_ovipositor ability directly - reuses all of its existing validation (hive-owned weeds, plasma cost, cooldown, not-in-interior) rather than reimplementing any of it. Skips entirely if the hive already has a comfortable larva buffer.
/datum/xeno_ai_controller/queen/proc/attempt_mount_ovipositor(mob/living/carbon/xenomorph/queen/queen_pilot)
	if(queen_pilot.ovipositor)
		return
	if(queen_pilot.hive && queen_pilot.hive.stored_larva >= AI_QUEEN_LARVA_COMFORTABLE_THRESHOLD)
		return
	var/datum/action/xeno_action/onclick/grow_ovipositor/action = get_ability(/datum/action/xeno_action/onclick/grow_ovipositor)
	if(!action)
		return
	action.use_ability(queen_pilot)

/// Marks the hive-wide alert location so other same-hive AI xenos can respond during idle patrol (see xeno_ai_controller.dm's respond_to_hive_alert()). Called every tick she has a live target, so the alert stays fresh while the threat persists and goes stale naturally once it doesn't.
/datum/xeno_ai_controller/queen/proc/broadcast_hive_alert(mob/living/carbon/xenomorph/queen/queen_pilot)
	if(!queen_pilot.hive || !current_target)
		return
	queen_pilot.hive.queen_alert_turf = get_turf(current_target)
	queen_pilot.hive.queen_alert_time = world.time

/**
 * Counts same-hive AI xenos actively fighting (AI_STATE_APPROACHING/ATTACKING)
 * near the marine LZ - if enough are engaged at once, this counts as a heavy
 * siege worth the Queen personally joining, per explicit design direction.
 * Cheap only because there's a single Queen instance doing this scan, not
 * something every caste's controller could afford.
 */
/datum/xeno_ai_controller/queen/proc/check_lz_siege(mob/living/carbon/xenomorph/queen/queen_pilot)
	var/turf/lz_turf = get_lz_turf()
	if(!lz_turf)
		return FALSE

	var/attackers_at_lz = 0
	for(var/mob/living/carbon/xenomorph/hive_member as anything in GLOB.ai_xeno_list)
		if(hive_member == queen_pilot || hive_member.hivenumber != queen_pilot.hivenumber)
			continue
		var/datum/xeno_ai_controller/member_controller = hive_member.ai_controller
		if(!member_controller || (member_controller.ai_state != AI_STATE_APPROACHING && member_controller.ai_state != AI_STATE_ATTACKING))
			continue
		if(get_dist(hive_member, lz_turf) <= AI_QUEEN_LZ_SIEGE_RADIUS)
			attackers_at_lz++
			if(attackers_at_lz >= AI_QUEEN_LZ_SIEGE_THRESHOLD)
				return TRUE
	return FALSE

/datum/xeno_ai_controller/queen/proc/get_lz_turf()
	var/datum/game_mode/mode = SSticker.mode
	if(!mode || !mode.active_lz)
		return null
	return get_turf(mode.active_lz)

/datum/xeno_ai_controller/queen/proc/head_to_lz(mob/living/carbon/xenomorph/queen/queen_pilot)
	var/turf/lz_turf = get_lz_turf()
	if(!lz_turf)
		patrol()
		return
	if(!advance_along_path(lz_turf))
		step_towards(queen_pilot, lz_turf)
