/**
 * Attach/detach lifecycle for NPC-piloted zombies, plus the real attachment
 * trigger (Phase 5): black_goo.dm's zombie_transform() and zombie.dm's
 * revive_from_death() both call schedule_zombie_ai_grace_period() right
 * after they ping any attached ghost (handle_alert_ghost()) - AI takes over
 * immediately if nobody's already piloting the body. zombie.dm's
 * handle_login_special()/handle_logout_special() then keep AI control and a
 * live ghost pilot mutually exclusive for the rest of the body's life,
 * mirroring xeno's Login()/Logout() hooks (xeno_ai_lifecycle.dm/login.dm)
 * exactly - a ghost claiming the body any time after cleanly displaces AI.
 */

/// All currently AI-piloted zombies - population bookkeeping, mirrors GLOB.ai_xeno_list.
GLOBAL_LIST_EMPTY(ai_zombie_list)
/**
 * Hard ceiling on concurrent AI-piloted zombies (Phase 4) - unlike xeno's per-caste cap
 * (GLOB.ai_xeno_max_per_caste), zombies have only the one baseline profile, so this is a single
 * flat number rather than a per-type table. A body that fails this cap just stays un-piloted
 * (still normally ghost-claimable) rather than erroring - same fail-safe shape as xeno's own
 * cap. Exists specifically so an infection outbreak turning a large chunk of the crew can't
 * spawn an unbounded number of concurrently-ticking AI controllers - each one is cheap on its
 * own (idle-heartbeat target scan, engaged-heartbeat movement/attack), but "cheap per mob" still
 * adds up without SOME ceiling once population is high enough, exactly the concern this cap
 * answers directly rather than leaving unbounded.
 */
GLOBAL_VAR_INIT(ai_zombie_max_pop, 40)

/**
 * Composes a fresh AI controller onto an existing, clientless zombie and
 * starts its decision loop. Returns FALSE (no-op) if the mob already has a
 * client, already has an AI controller, isn't actually a zombie, or the
 * population cap (GLOB.ai_zombie_max_pop) is already met.
 */
/proc/attach_zombie_ai(mob/living/carbon/human/zombie, turf/anchor_override)
	if(!zombie || zombie.client || zombie.zombie_ai_controller || !iszombie(zombie))
		return FALSE
	if(length(GLOB.ai_zombie_list) >= GLOB.ai_zombie_max_pop)
		return FALSE

	zombie.zombie_ai_controller = new /datum/zombie_ai_controller(zombie)
	if(anchor_override)
		zombie.zombie_ai_controller.anchor_turf = anchor_override
	zombie.is_zombie_ai_controlled = TRUE
	zombie.was_zombie_ai_spawned = TRUE

	GLOB.ai_zombie_list += zombie
	zombie.zombie_ai_controller.start()

	return TRUE

/**
 * Tears down AI control on a zombie, either because a client just attached
 * (ghost takeover) or because it's dying/being deleted. Leaves the mob itself
 * untouched.
 */
/proc/detach_zombie_ai(mob/living/carbon/human/zombie)
	if(!zombie || !zombie.zombie_ai_controller)
		return FALSE

	zombie.zombie_ai_controller.stop()
	QDEL_NULL(zombie.zombie_ai_controller)
	zombie.is_zombie_ai_controlled = FALSE

	GLOB.ai_zombie_list -= zombie

	return TRUE

/**
 * Real Phase 5 attachment trigger - called from black_goo.dm's
 * zombie_transform() and zombie.dm's revive_from_death(), immediately after
 * each pings any attached ghost via handle_alert_ghost(). Attaches AI right
 * away if nobody's already piloting the body. A ghost that reenters at ANY
 * point afterward is unaffected either way - reentering runs through
 * Login(), which detaches AI immediately (zombie.dm's
 * handle_login_special()) regardless of whether AI ever took over here.
 */
/proc/schedule_zombie_ai_grace_period(mob/living/carbon/human/zombie)
	if(!zombie || QDELETED(zombie) || zombie.client || zombie.stat == DEAD || !iszombie(zombie) || zombie.zombie_ai_controller)
		return
	attach_zombie_ai(zombie)

/**
 * Re-attaches AI control after a player who was piloting a formerly-AI-spawned
 * zombie disconnects, so the body doesn't go permanently idle just because its
 * ghost pilot left. Anchors to the mob's current position, not wherever it
 * originally turned/revived, so it doesn't unrealistically walk back across
 * the map. Only fires for bodies that were originally AI-spawned
 * (was_zombie_ai_spawned) - an ordinary player playing a zombie (e.g. an
 * antag round) disconnecting behaves exactly as today. Mirrors xeno's
 * reattach_xeno_ai_on_disconnect() (xeno_ai_lifecycle.dm) exactly.
 */
/proc/reattach_zombie_ai_on_disconnect(mob/living/carbon/human/zombie)
	if(!zombie || !zombie.was_zombie_ai_spawned)
		return FALSE
	if(zombie.client || zombie.stat == DEAD || !iszombie(zombie))
		return FALSE
	return attach_zombie_ai(zombie, get_turf(zombie))

/**
 * Admin-gated (GLOB.debug_verbs, admin_verbs.dm) manual override - force-attaches AI to a chosen
 * zombie mob directly. Originally the only way to test the controller before Phase 5 wired up the
 * real trigger above; kept afterward as a legitimate admin tool for forcing a specific body into
 * AI control (event/horde use, or testing) independent of the transform/revive call sites.
 */
/client/proc/debug_attach_zombie_ai()
	set category = "Debug"
	set name = "Attach Zombie AI"

	var/mob/living/carbon/human/target = tgui_input_list(src, "Which zombie?", "Attach Zombie AI", GLOB.alive_human_list)
	if(!target || !iszombie(target))
		to_chat(usr, SPAN_WARNING("Not a valid zombie."))
		return
	if(attach_zombie_ai(target))
		to_chat(usr, SPAN_NOTICE("AI attached to [target]."))
	else
		to_chat(usr, SPAN_WARNING("Attach failed (already AI-controlled, has a client, isn't a zombie, or the population cap [GLOB.ai_zombie_max_pop] is already met)."))
