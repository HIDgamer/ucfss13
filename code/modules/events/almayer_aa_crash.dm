// Admin verb to trigger the USS Almayer AA crash event
/client/proc/cmd_admin_almayer_aa_crash()
	set name = "Almayer: Trigger AA Crash Event"
	set category = "Admin.Events"

	if(!check_rights(R_ADMIN))
		return

	message_admins("[key_name_admin(usr)] has triggered the Almayer AA crash event.")
	log_admin("[key_name(usr)] triggered the Almayer AA crash event.")
	INVOKE_ASYNC(null, GLOBAL_PROC_REF(almayer_aa_crash_event))

// Shake every client currently on the main ship
/proc/shake_mainship(steps, strength, time_per_step)
	for(var/mob/M in GLOB.mob_list)
		if(M.client && is_mainship_level(M.z))
			shake_camera(M, steps, strength, time_per_step)

// Scatter smoke objects across a random sample of Almayer floor tiles
/proc/almayer_spawn_smoke(list/floor_turfs, count, datum/cause_data/cause)
	var/list/candidates = shuffle(floor_turfs.Copy())
	for(var/i = 1 to min(count, candidates.len))
		new /obj/effect/particle_effect/smoke(candidates[i], null, cause)

/proc/almayer_aa_crash_event()
	var/datum/cause_data/cause = create_cause_data("AA Fire")

	// Pre-collect all Almayer floor tiles once so we don't iterate world repeatedly
	var/list/floor_turfs = list()
	for(var/turf/open/floor/almayer/T in world)
		if(is_mainship_level(T.z))
			floor_turfs += T

	// ---------------------------------------------------------------
	// PHASE 1 — First AA volleys, crew warned
	// ---------------------------------------------------------------
	shipwide_ai_announcement(
		"ANTI-AIRCRAFT FIRE DETECTED. MULTIPLE INBOUND PROJECTILES. ALL HANDS TO EMERGENCY STATIONS — BRACE FOR IMPACT.",
		MAIN_AI_SYSTEM,
		sound('sound/misc/interference.ogg')
	)
	shake_mainship(4, 2, 3)
	sleep(4 SECONDS)

	// ---------------------------------------------------------------
	// PHASE 2 — Sustained barrage, port hull breached
	// ---------------------------------------------------------------
	shipwide_ai_announcement(
		"PORT HULL SECTIONS 3 THROUGH 5 BREACHED. FIRES DETECTED ON MULTIPLE DECKS. DAMAGE CONTROL TEAMS RESPOND IMMEDIATELY.",
		MAIN_AI_SYSTEM,
		sound('sound/misc/interference.ogg')
	)
	shake_mainship(6, 3, 2)
	almayer_spawn_smoke(floor_turfs, 20, cause)
	sleep(5 SECONDS)

	// ---------------------------------------------------------------
	// PHASE 3 — Engine hit, structural integrity failing
	// ---------------------------------------------------------------
	shipwide_ai_announcement(
		"STARBOARD ENGINE NACELLE STRUCK. STRUCTURAL INTEGRITY AT 47%. EMERGENCY BULKHEADS OFFLINE. REACTOR OUTPUT CRITICAL.",
		MAIN_AI_SYSTEM,
		sound('sound/misc/interference.ogg')
	)
	shake_mainship(8, 4, 2)
	almayer_spawn_smoke(floor_turfs, 35, cause)
	sleep(5 SECONDS)

	// ---------------------------------------------------------------
	// PHASE 4 — ~20% of xenomorphs die from hull ruptures;
	//           Queen Mother speaks to all survivors
	// ---------------------------------------------------------------
	var/list/xenos = shuffle(GLOB.living_xeno_list.Copy())
	var/kill_count = max(1, round(xenos.len * 0.20))
	for(var/i = 1 to min(kill_count, xenos.len))
		var/mob/living/carbon/xenomorph/X = xenos[i]
		if(!QDELETED(X) && X.stat != DEAD)
			X.death(cause)

	sleep(1 SECONDS)

	xeno_announcement(
		SPAN_XENOANNOUNCE("Something has gone terribly wrong aboard the metal hive. I sense death... confusion... fire consuming the walls of steel. Those of you that survive — protect the nest. The hunt is over. Survival is all that remains. Do not let the deaths of your kin be in vain."),
		"everything",
		QUEEN_MOTHER_ANNOUNCE
	)

	sleep(3 SECONDS)

	// ---------------------------------------------------------------
	// PHASE 5 — Uncontrolled descent, crash impact
	// ---------------------------------------------------------------
	shipwide_ai_announcement(
		"STRUCTURAL INTEGRITY AT 12%. UNCONTROLLED DESCENT DETECTED. ALL PERSONNEL — BRACE FOR IMPACT.",
		MAIN_AI_SYSTEM,
		sound('sound/misc/interference.ogg')
	)
	shake_mainship(12, 6, 2)
	almayer_spawn_smoke(floor_turfs, 50, cause)

	sleep(2 SECONDS)

	// Crash message to everyone physically on the ship
	for(var/mob/M in GLOB.mob_list)
		if(is_mainship_level(M.z))
			to_chat(M, SPAN_DANGER("The Almayer shudders violently as it plunges toward the planet surface!"))
