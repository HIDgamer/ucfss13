/**
 * Attach/detach lifecycle for NPC-piloted xenomorphs, and the single canonical
 * spawn entry point. Both Stage 1's admin test spawn and Stage 2's wave/objective
 * spawners must funnel through spawn_ai_xeno() so the population cap is enforced
 * in exactly one place.
 *
 * Ghost takeover reuses the already-existing, unmodified /mob/proc/free_for_ghosts()
 * (code/modules/mob/mob_helpers.dm) and its claim_freed href handling
 * (code/modules/mob/dead/observer/observer.dm) - the same mechanism an unclaimed
 * King hatch already relies on. A ghost claiming the mob triggers a normal
 * mind.transfer_to(), which attaches a client and fires Login() exactly like any
 * other xeno join; the detach itself happens there (see login.dm).
 */

/**
 * Spawns a real, hive-linked xenomorph of the given caste and immediately attaches
 * AI control to it. Returns the new mob, or null if the spawn was refused (no room
 * under the population cap, unknown caste, no spawn turf).
 */
/proc/spawn_ai_xeno(caste_type = XENO_CASTE_DRONE, turf/spawn_turf, hivenumber = XENO_HIVE_NORMAL, turf/anchor_override)
	if(!spawn_turf)
		return null

	if(GLOB.ai_xeno_active_count >= GLOB.ai_xeno_max_active)
		return null

	var/mob_type = GLOB.RoleAuthority.get_caste_by_text(caste_type)
	if(!mob_type)
		return null

	var/mob/living/carbon/xenomorph/new_xeno = new mob_type(spawn_turf, null, hivenumber)
	if(!attach_xeno_ai(new_xeno, anchor_override || spawn_turf))
		return new_xeno // Mob exists but AI attach failed (e.g. already had a client); hand back the plain mob rather than leaking it.

	return new_xeno

/**
 * Composes a fresh AI controller onto an existing, clientless xenomorph and starts
 * its decision loop. Returns FALSE (no-op) if the mob already has a client or an
 * AI controller.
 */
/proc/attach_xeno_ai(mob/living/carbon/xenomorph/xeno, turf/anchor_override)
	if(!xeno || xeno.client || xeno.ai_controller)
		return FALSE

	if(GLOB.ai_xeno_active_count >= GLOB.ai_xeno_max_active)
		return FALSE

	var/controller_type = get_ai_controller_type_for_caste(xeno.caste_type)
	xeno.ai_controller = new controller_type(xeno)
	if(anchor_override)
		xeno.ai_controller.anchor_turf = anchor_override
	xeno.is_ai_controlled = TRUE
	xeno.was_ai_spawned = TRUE

	GLOB.ai_xeno_list += xeno
	GLOB.ai_xeno_active_count++

	xeno.ai_controller.start()
	xeno.free_for_ghosts(TRUE) // Lets a ghost claim the mob mid-fight at any time, same mechanism as an unclaimed King hatch.

	return TRUE

/**
 * Tears down AI control on a xenomorph, either because a client just attached
 * (ghost takeover - see login.dm's Login() hook) or because it's dying/being
 * deleted. Leaves the mob itself untouched.
 */
/proc/detach_xeno_ai(mob/living/carbon/xenomorph/xeno)
	if(!xeno || !xeno.ai_controller)
		return FALSE

	xeno.ai_controller.stop()
	QDEL_NULL(xeno.ai_controller)
	xeno.is_ai_controlled = FALSE

	GLOB.ai_xeno_list -= xeno
	GLOB.ai_xeno_active_count = max(0, GLOB.ai_xeno_active_count - 1)

	return TRUE

/**
 * Re-attaches AI control after a player who was piloting a formerly-AI-spawned
 * xeno disconnects, so waves/objectives don't go permanently quiet just because a
 * ghost left. Anchors to the mob's current position, not its original spawn point,
 * so it doesn't unrealistically walk back across the map. Only fires for mobs that
 * were originally AI-spawned (was_ai_spawned) - ordinary players disconnecting
 * behave exactly as today.
 */
/proc/reattach_xeno_ai_on_disconnect(mob/living/carbon/xenomorph/xeno)
	if(!xeno || !xeno.was_ai_spawned || xeno.client || xeno.stat == DEAD)
		return FALSE

	return attach_xeno_ai(xeno, get_turf(xeno))

/**
 * Per-caste controller dispatch table (see code/modules/mob/living/carbon/xenomorph/ai/castes/
 * for the concrete subtypes). Every caste not listed here still gets a
 * fully-functional xeno, just with the generic Stage 1 melee/patrol
 * controller rather than a specialized one - this list only needs entries
 * for castes whose behavior genuinely differs, not every caste in the game.
 */
/proc/get_ai_controller_type_for_caste(caste_type)
	switch(caste_type)
		if(XENO_CASTE_QUEEN)
			return /datum/xeno_ai_controller/queen
		if(XENO_CASTE_DRONE)
			return /datum/xeno_ai_controller/drone_worker
		if(XENO_CASTE_SPITTER)
			return /datum/xeno_ai_controller/ranged/spitter
	return /datum/xeno_ai_controller
