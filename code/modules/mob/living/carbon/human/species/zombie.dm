// DEFINES
///Time until a zombie rises from the dead
#define ZOMBIE_REVIVE_TIME 1 MINUTES

/datum/species/zombie
	group = SPECIES_HUMAN
	name = SPECIES_ZOMBIE
	name_plural = "Zombies"
	slowdown = 0.75
	blood_color = BLOOD_COLOR_ZOMBIE
	icobase = 'icons/mob/humans/species/r_goo_zed.dmi'
	deform = 'icons/mob/humans/species/r_goo_zed.dmi'
	eyes = "blank_s"
	pain_type = /datum/pain/zombie
	stamina_type = /datum/stamina/none
	death_message = "seizes up and falls limp..."
	flags = NO_BREATHE|NO_CLONE_LOSS|NO_POISON|NO_NEURO|NO_SHRAPNEL
	mob_inherent_traits = list(TRAIT_FOREIGN_BIO)
	brute_mod = 0.6 //Minor bullet resistance
	burn_mod = 0.8 //Lowered burn damage since it would 1-shot zombies from 2 to 0.8.
	speech_chance  = 5
	cold_level_1 = -1  //zombies don't mind the cold
	cold_level_2 = -1
	cold_level_3 = -1
	has_fine_manipulation = FALSE
	can_emote = FALSE
	knock_down_reduction = 10
	stun_reduction = 10
	knock_out_reduction = 5
	has_organ = list()

	has_species_tab_items = TRUE

	var/list/to_revive = list()
	var/list/revive_times = list()

	var/basic_moan = 'sound/hallucinations/far_noise.ogg'
	var/basic_variance = TRUE
	var/rare_moan = 'sound/hallucinations/veryfar_noise.ogg'
	var/rare_variance = TRUE

/datum/species/zombie/handle_post_spawn(mob/living/carbon/human/zombie)
	zombie.set_languages(list("Zombie"))

	zombie.faction = FACTION_ZOMBIE
	zombie.faction_group = list(FACTION_ZOMBIE)

	var/datum/pass_flags_container/zombie_pass_flags = new()
	zombie_pass_flags.flags_pass = PASS_MOB_IS_HUMAN|PASS_MOB_IS_ZOMBIE
	zombie_pass_flags.flags_can_pass_all = PASS_MOB_THRU_HUMAN|PASS_MOB_THRU_ZOMBIE|PASS_AROUND|PASS_HIGH_OVER_ONLY
	zombie.pass_flags = zombie_pass_flags

	if(zombie.l_hand)
		zombie.drop_inv_item_on_ground(zombie.l_hand, FALSE, TRUE)
	if(zombie.r_hand)
		zombie.drop_inv_item_on_ground(zombie.r_hand, FALSE, TRUE)
	if(zombie.wear_id)
		qdel(zombie.wear_id)
	if(zombie.gloves)
		zombie.drop_inv_item_on_ground(zombie.gloves, FALSE, TRUE)
	if(zombie.head)
		zombie.drop_inv_item_on_ground(zombie.head, FALSE, TRUE)
	if(zombie.glasses)
		zombie.drop_inv_item_on_ground(zombie.glasses, FALSE, TRUE)
	if(zombie.wear_mask)
		zombie.drop_inv_item_on_ground(zombie.wear_mask, FALSE, TRUE)

	var/obj/item/weapon/zombie_claws/ZC = new(zombie)
	ZC.icon_state = "claw_r"
	zombie.equip_to_slot_or_del(ZC, WEAR_R_HAND, TRUE)
	zombie.equip_to_slot_or_del(new /obj/item/weapon/zombie_claws(zombie), WEAR_L_HAND, TRUE)
	zombie.equip_to_slot_or_del(new /obj/item/clothing/glasses/zombie_eyes(zombie), WEAR_EYES, TRUE)

	var/datum/disease/black_goo/zombie_infection = locate() in zombie.viruses
	if(!zombie_infection)
		zombie_infection = zombie.AddDisease(new /datum/disease/black_goo())
	zombie_infection.stage = 4

	var/datum/mob_hud/Hu = GLOB.huds[MOB_HUD_MEDICAL_OBSERVER]
	Hu.add_hud_to(zombie, zombie)

	return ..()



/datum/species/zombie/post_species_loss(mob/living/carbon/human/zombie)
	..()
	remove_from_revive(zombie)
	var/datum/mob_hud/Hu = GLOB.huds[MOB_HUD_MEDICAL_OBSERVER]
	Hu.remove_hud_from(zombie, zombie)

	zombie.pass_flags = GLOB.pass_flags_cache[zombie.type] || zombie.pass_flags


/datum/species/zombie/handle_unique_behavior(mob/living/carbon/human/zombie)
	if(prob(5))
		playsound(zombie.loc, basic_moan, 15, basic_variance)
	else if(prob(5))
		playsound(zombie.loc, rare_moan, 15, rare_variance)

/**
 * Phase 5 zombie AI: mirrors xeno's Login()/Logout() hooks
 * (xenomorph/login.dm) exactly, just routed through the species-callback
 * hook /mob/living/carbon/human/Login()/Logout() already call
 * (human/login.dm, human/logout.dm) rather than a raw override on human
 * itself - a raw override there would run for every human regardless of
 * species.
 */
/datum/species/zombie/handle_login_special(mob/living/carbon/human/H)
	..()
	if(H.zombie_ai_controller)
		detach_zombie_ai(H) // A ghost just claimed this body - hand off cleanly before normal player setup runs.

/datum/species/zombie/handle_logout_special(mob/living/carbon/human/H)
	..()
	if(H.was_zombie_ai_spawned && !H.zombie_ai_controller)
		reattach_zombie_ai_on_disconnect(H) // Falls back to AI control so a body that never had (or already lost) a real player pilot doesn't go idle just because this particular ghost disconnected.

/datum/species/zombie/handle_death(mob/living/carbon/human/zombie, gibbed)
	set waitfor = FALSE

	// Phase 5 zombie AI: detach immediately at death rather than waiting for eventual Destroy()
	// (gibbing, or the round ending) - mirrors xeno's own death() override
	// (xenomorph/death.dm) and its doc comment's exact reasoning: otherwise the dead mob's
	// controller keeps ticking every heartbeat for nothing (tick() no-ops once stat reads DEAD,
	// but the coroutine itself still pays its per-heartbeat cost) and the corpse stays counted
	// against GLOB.ai_zombie_max_pop (zombie_ai_lifecycle.dm) despite doing nothing useful with
	// that slot. revive_from_death() below re-schedules a fresh grace period on its own if this
	// body comes back up later, so nothing about a later revive depends on the controller having
	// stayed attached through death.
	if(zombie.zombie_ai_controller)
		detach_zombie_ai(zombie)

	if(gibbed)
		remove_from_revive(zombie)
		return

	if(zombie)
		var/obj/limb/head/head = zombie.get_limb("head")
		if(!QDELETED(head) && !(head.status & LIMB_DESTROYED))
			if(zombie.client)
				zombie.play_screen_text("<span class='langchat' style=font-size:16pt;text-align:center valign='top'><u>You are dead...</u></span><br>You will rise again in one minute.", /atom/movable/screen/text/screen_text/command_order, rgb(155, 0, 200))
			to_chat(zombie, SPAN_XENOWARNING("You fall... but your body is slowly regenerating itself."))
			var/weak_ref = WEAKREF(zombie)
			to_revive[weak_ref] = addtimer(CALLBACK(src, PROC_REF(revive_from_death), zombie, "[REF(zombie)]"), ZOMBIE_REVIVE_TIME, TIMER_STOPPABLE|TIMER_OVERRIDE|TIMER_UNIQUE|TIMER_NO_HASH_WAIT)
			revive_times[weak_ref] = world.time + 1 MINUTES
		else
			if(zombie.client)
				zombie.play_screen_text("<span class='langchat' style=font-size:16pt;text-align:center valign='top'><u>You are dead...</u></span><br>You lost your head. No reviving for you.", /atom/movable/screen/text/screen_text/command_order, rgb(155, 0, 200))
			to_chat(zombie, SPAN_XENOWARNING("You fall... headless, you will no longer rise."))
			zombie.undefibbable = TRUE // really only for weed_food
			SEND_SIGNAL(zombie, COMSIG_HUMAN_SET_UNDEFIBBABLE)

/datum/species/zombie/handle_dead_death(mob/living/carbon/human/zombie, gibbed)
	if(gibbed)
		remove_from_revive(zombie)

/datum/species/zombie/proc/revive_from_death(mob/living/carbon/human/zombie)
	if(zombie && zombie.loc && zombie.stat == DEAD)
		zombie.revive(TRUE)
		zombie.apply_effect(4, STUN)

		zombie.make_jittery(500)
		zombie.visible_message(SPAN_WARNING("[zombie] rises from the ground!"))
		remove_from_revive(zombie)

		handle_alert_ghost(zombie)
		// A zombie coming back to life (as opposed to a fresh infection) has no live original
		// owner actively deciding whether to reclaim it right now - waiting out the same grace
		// period a first-time transform uses just leaves it standing idle for no reason. Attach
		// AI immediately whenever nobody's client is currently attached; a ghost that reenters
		// later still safely reclaims the body at any point regardless (handle_login_special()
		// detaches AI unconditionally on login), so this costs a returning player nothing.
		if(zombie.client)
			schedule_zombie_ai_grace_period(zombie) // Phase 5 zombie AI - see its own doc comment (zombie_ai_lifecycle.dm).
		else
			attach_zombie_ai(zombie)

		addtimer(CALLBACK(zombie, TYPE_PROC_REF(/mob, remove_jittery)), 3 SECONDS)

/datum/species/zombie/proc/handle_alert_ghost(mob/living/carbon/human/zombie)
	var/mob/dead/observer/ghost = zombie.get_ghost()
	if(ghost?.client)
		playsound_client(ghost.client, 'sound/effects/adminhelp_new.ogg')
		to_chat(ghost, SPAN_BOLDNOTICE(FONT_SIZE_LARGE("Your body has risen! (Verbs -> Ghost -> Re-enter corpse, or <a href='byond://?src=\ref[ghost];reentercorpse=1'>click here!</a>)")))

/datum/species/zombie/proc/remove_from_revive(mob/living/carbon/human/zombie)
	var/weak_ref = WEAKREF(zombie)
	if(weak_ref in to_revive)
		deltimer(to_revive[weak_ref])
		to_revive -= weak_ref
	revive_times -= weak_ref

/datum/species/zombie/get_status_tab_items(mob/living/carbon/human/zombie)
	var/list/static_tab_items = list()
	if(zombie.stat == DEAD)
		var/revive_time = revive_times[WEAKREF(zombie)]
		if(revive_time)
			var/revive_time_left = revive_time - world.time
			static_tab_items += ""
			static_tab_items += "Time Till Revive: [duration2text_sec(revive_time_left)]"
	return static_tab_items

/datum/species/zombie/handle_head_loss(mob/living/carbon/human/zombie)
	if(!zombie.undefibbable)
		zombie.undefibbable = TRUE // really only for weed_food
		SEND_SIGNAL(zombie, COMSIG_HUMAN_SET_UNDEFIBBABLE)
	if(WEAKREF(zombie) in to_revive)
		remove_from_revive(zombie)
		var/client/receiving_client = zombie.client
		if(!receiving_client)
			var/mob/dead/observer/ghost = zombie.get_ghost()
			if(ghost)
				receiving_client = ghost.client
		if(receiving_client)
			receiving_client.mob.play_screen_text("<span class='langchat' style=font-size:16pt;text-align:center valign='top'><u>Beheaded...</u></span><br>Your corpse will no longer rise.", /atom/movable/screen/text/screen_text/command_order, rgb(155, 0, 200))
			to_chat(receiving_client, SPAN_BOLDNOTICE(FONT_SIZE_LARGE("You've been beheaded! Your body will no longer rise.")))
