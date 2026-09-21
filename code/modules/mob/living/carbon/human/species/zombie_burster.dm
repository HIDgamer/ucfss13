/**
 * The Burster - a zombie variant that ruptures into an infectious cloud of aerosolized black goo
 * on death instead of rising again on the usual timer. Anyone breathing the cloud in gets exposed
 * to the same black_goo disease a bite would give - CBRN filtration and a sealed mask+internals
 * setup both block it, same as any other airborne hazard (see
 * /mob/living/carbon/human/proc/is_gas_infection_protected() below).
 *
 * Spawned via the "Zombie Burster" entry in the admin Human tab's preset picker
 * (/datum/equipment_preset/other/zombie/burster, other.dm) - a plain subtype of the real "Zombie"
 * preset, so it goes through the exact same spawn/AI-attach path with no special-casing needed.
 */
/datum/species/zombie/burster
	name = SPECIES_ZOMBIE_BURSTER
	name_plural = "Burster Zombies"

	/// Radius of the initial burst - 1 = a 3x3 block centered on the death tile.
	var/gas_initial_radius = 1
	/// How many times the cloud grows outward after the initial burst.
	var/gas_spread_rings = 3
	/// Tiles added to the radius per ring - final radius is gas_initial_radius + (gas_spread_rings * gas_ring_width), 1 + (3*2) = 7 with the defaults below, same total reach as the instant-fill version this replaced.
	var/gas_ring_width = 2
	/// Delay between each ring expanding outward - the "slowly" part.
	var/gas_spread_delay = 2 SECONDS

/**
 * Ruptures into a gas cloud instead of the base zombie's revive-on-a-timer behavior - a Burster
 * consumes itself entirely in its own explosion (never rises again), the same "boomer" shape as
 * the Acider xeno strain's do_caboom() (runner/acid.dm) gibbing itself after its blast. Runs
 * instead of ..() (zombie/handle_death()) - deliberately doesn't call the parent, since that
 * schedules the normal revive timer this variant isn't meant to get.
 */
/datum/species/zombie/burster/handle_death(mob/living/carbon/human/zombie, gibbed)
	set waitfor = FALSE
	if(zombie.zombie_ai_controller)
		detach_zombie_ai(zombie)
	explode_into_gas(zombie, gibbed)

/datum/species/zombie/burster/proc/explode_into_gas(mob/living/carbon/human/zombie, already_gibbed)
	var/turf/burst_turf = get_turf(zombie)
	if(!burst_turf)
		return
	zombie.visible_message(SPAN_DANGER("[zombie] ruptures with a wet pop, spraying a thick black mist into the air!"))
	playsound(burst_turf, 'sound/effects/splat.ogg', 50, TRUE)

	spread_gas(burst_turf, 0, gas_initial_radius)

	if(!already_gibbed && !QDELETED(zombie))
		zombie.gib(create_cause_data("infectious rupture", zombie))

/**
 * Fills only the NEWLY-reached tiles between previous_radius and current_radius with gas (so
 * re-running this each ring doesn't stack a second smoke instance on ground already covered),
 * then - if there are rings left - schedules the next, wider ring after gas_spread_delay. Species
 * datums are shared singletons (one per species, not per-mob), but nothing here is stored on src
 * itself - center/previous_radius/current_radius are carried entirely through the call chain, so
 * multiple Bursters dying around the same time spread independently without stepping on each other.
 */
/datum/species/zombie/burster/proc/spread_gas(turf/center, previous_radius, current_radius)
	if(!center)
		return
	var/list/already_covered = list()
	if(previous_radius > 0)
		FOR_DVIEW(var/turf/T, previous_radius, center, HIDE_INVISIBLE_OBSERVER)
			already_covered += T
		FOR_DVIEW_END

	FOR_DVIEW(var/turf/T, current_radius, center, HIDE_INVISIBLE_OBSERVER)
		if(!(T in already_covered))
			new /obj/effect/particle_effect/smoke/blackgoo(T)
	FOR_DVIEW_END

	if(current_radius - gas_initial_radius >= gas_spread_rings * gas_ring_width)
		return
	addtimer(CALLBACK(src, PROC_REF(spread_gas), center, current_radius, current_radius + gas_ring_width), gas_spread_delay)

/**
 * The Burster's infectious cloud. A plain /particle_effect/smoke subtype (not /smoke/chem) since
 * this doesn't use the reagent-carrying machinery at all - just a direct contract_disease() call
 * per affected mob, gated on the same "is this mob currently breathing filtered/sealed air"
 * check breathe() itself uses (handle_breath.dm), not the reagent system's own (unrelated,
 * unguarded) reaction_mob() path.
 */
/obj/effect/particle_effect/smoke/blackgoo
	name = "black, viscous smoke"
	desc = "A thick, foul-smelling black smoke. It looks like it'd be very unwise to breathe this in."
	color = "#1a1a1a"
	time_to_live = 15
	smokeranking = SMOKE_RANK_HIGH

/obj/effect/particle_effect/smoke/blackgoo/affect(mob/living/carbon/affected_mob)
	. = ..()
	if(!.)
		return FALSE
	if(!ishuman_strict(affected_mob))
		return FALSE
	var/mob/living/carbon/human/H = affected_mob
	if(iszombie(H) || H.is_gas_infection_protected())
		return FALSE
	H.contract_disease(new /datum/disease/black_goo())
	return TRUE

/**
 * Whether this human is currently breathing filtered/sealed air rather than the ambient
 * atmosphere - mirrors breathe()'s own two independent protection checks exactly
 * (handle_breath.dm): a mask hooked up to an internal air tank (get_breath_from_internal()'s own
 * gate), or any of mask/glasses/head individually flagged BLOCKGASEFFECT (the same three slots
 * breathe() itself checks before letting ambient smoke reagents in). Used by the Burster's gas
 * cloud instead of inventing a new protection check - CBRN's own M3 MOPP mask
 * (clothing/head/helmet.dm's cbrn_hood) is given BLOCKGASEFFECT for exactly this reason, matching
 * its own flavor text ("filters out harmful particles in the air").
 */
/mob/living/carbon/human/proc/is_gas_infection_protected()
	if(internal && wear_mask && (wear_mask.flags_inventory & ALLOWINTERNALS))
		return TRUE
	if(wear_mask && (wear_mask.flags_inventory & BLOCKGASEFFECT))
		return TRUE
	if(glasses && (glasses.flags_inventory & BLOCKGASEFFECT))
		return TRUE
	if(head && (head.flags_inventory & BLOCKGASEFFECT))
		return TRUE
	return FALSE
