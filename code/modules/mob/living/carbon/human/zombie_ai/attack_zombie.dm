/**
 * Structure-side receivers for zombie AI obstacle-forcing
 * (zombie_ai_movement.dm's attack_blocking_obstacle()). Mirrors
 * code/modules/mob/living/carbon/xenomorph/attack_alien.dm's centralized-file
 * convention and attack_TYPE() dispatch pattern, scoped to only the structure
 * types the AI can actually reach this way: windows, fences, girders and grilles (smash through),
 * airlocks (force open), and barricades (smash - see should_smash_instead_of_climb()
 * in zombie_ai_movement.dm for why barricades never get climbed instead).
 * Climbable furniture (tables, crates) needs no entry here - do_climb()
 * (structures.dm) is already generic/ungated and the AI calls it directly.
 *
 * Only ever reached by an AI-piloted zombie. A player-piloted zombie's claws
 * never dispatch here through the normal click chain - zombie_claws has no
 * matching afterattack() override (see black_goo.dm), so a live player
 * currently can't force a door open with claws either; out of scope to fix
 * here, this file exists purely to give the AI controller a receiver.
 */

/// True root stub, exists purely so attack_zombie() compiles when called through the loosely (atom-)typed obstacle vars the AI's scan produces - mirrors /atom/proc/attack_alien()'s role (code/_onclick/xeno.dm).
/atom/proc/attack_zombie(mob/living/carbon/human/Z)
	return

/// Default fallback for any structure without a specific override below - silently immune rather than hard-erroring on an undefined proc, mirroring attack_alien.dm's own /obj/structure default.
/obj/structure/attack_zombie(mob/living/carbon/human/Z)
	return

/obj/structure/window/attack_zombie(mob/living/carbon/human/Z)
	attack_generic(Z, ZOMBIE_AI_STRUCTURE_DAMAGE)

/obj/structure/fence/attack_zombie(mob/living/carbon/human/Z)
	attack_generic(Z, ZOMBIE_AI_STRUCTURE_DAMAGE)

/**
 * Missing entirely until now - a zombie that picked a girder as its blocking obstacle
 * (get_blocking_obstacle() sees it exactly like a xeno would: dense, not climbable, not
 * unslashable) fell through to the base /obj/structure/attack_zombie() no-op above and stood
 * there clawing at nothing forever. Mirrors attack_alien.dm's own girder handler, minus the
 * claw-tier gate that proc uses - no equivalent exists on a human pilot, and "ruthless" means it
 * always grinds through given enough hits, same reasoning the airlock handler above already uses.
 */
/obj/structure/girder/attack_zombie(mob/living/carbon/human/Z)
	Z.animation_attack_on(src)
	health -= ZOMBIE_AI_STRUCTURE_DAMAGE
	if(health <= 0)
		Z.visible_message(SPAN_DANGER("[Z] smashes [src] apart!"))
		playsound(loc, 'sound/effects/metalhit.ogg', 25, TRUE)
		dismantle()
	else
		Z.visible_message(SPAN_DANGER("[Z] smashes [src]!"))
		playsound(loc, 'sound/effects/metalhit.ogg', 25, TRUE)

/// Missing entirely until now - same silent-stall bug as girder above. Mirrors attack_alien.dm's grille handler, including the same shock risk a player attacking it would take.
/obj/structure/grille/attack_zombie(mob/living/carbon/human/Z)
	Z.animation_attack_on(src)
	playsound(loc, 'sound/effects/grillehit.ogg', 25, 1)
	Z.visible_message(SPAN_DANGER("[Z] mangles [src]!"))
	if(shock(Z, 70))
		Z.visible_message(SPAN_DANGER("ZAP! [Z] spazzes wildly amongst a smell of burnt ozone."))
		return
	health -= ZOMBIE_AI_STRUCTURE_DAMAGE
	healthcheck()

/obj/structure/barricade/attack_zombie(mob/living/carbon/human/Z)
	if(unslashable)
		return
	Z.animation_attack_on(src)
	take_damage(ZOMBIE_AI_STRUCTURE_DAMAGE * brute_multiplier)
	if(barricade_hitsound)
		playsound(src, barricade_hitsound, 25, 1)
	if(health <= 0)
		Z.visible_message(SPAN_DANGER("[Z] tears [src] apart!"))
	else
		Z.visible_message(SPAN_DANGER("[Z] claws through [src]!"))
	if(is_wired)
		Z.visible_message(SPAN_DANGER("The barbed wire slices into [Z]!"))
		Z.apply_damage(10)

/**
 * Forcing an airlock open - copied from attack_alien.dm's own
 * /obj/structure/machinery/door/airlock/attack_alien() (the do_after+open(1)
 * pattern), minus the claw_type/CLAW_TYPE_SHARP gate that proc uses on welded/
 * locked doors - no equivalent var exists on a human pilot, and a zombie
 * always grinds through given enough hits, matching "ruthless."
 */
/obj/structure/machinery/door/airlock/attack_zombie(mob/living/carbon/human/Z)
	var/turf/cur_loc = Z.loc
	if(isElectrified())
		if(shock(Z, 100))
			return

	if(!density || heavy)
		return // Already open, or too heavy to force.

	if(welded)
		Z.animation_attack_on(src)
		playsound(src, 'sound/effects/metalhit.ogg', 25, 1)
		take_damage(damage_cap / XENO_HITS_TO_DESTROY_WELDED_DOOR)
		return

	if(locked)
		Z.animation_attack_on(src)
		playsound(src, 'sound/effects/metalhit.ogg', 25, 1)
		take_damage(HEALTH_DOOR / XENO_HITS_TO_DESTROY_BOLTED_DOOR)
		return

	if(!istype(cur_loc) || Z.action_busy || Z.is_mob_incapacitated() || Z.body_position != STANDING_UP)
		return

	var/delay = arePowerSystemsOn() ? 4 SECONDS : 1 SECONDS
	playsound(loc, "alien_doorpry", 25, TRUE)
	Z.visible_message(SPAN_WARNING("[Z] digs into [src] and begins to pry it open."))

	if(do_after(Z, delay, INTERRUPT_ALL, BUSY_ICON_HOSTILE))
		if(Z.loc != cur_loc || Z.is_mob_incapacitated() || Z.body_position != STANDING_UP || locked || welded || !density)
			return
		open(1)
		Z.visible_message(SPAN_DANGER("[Z] forces [src] open."))
